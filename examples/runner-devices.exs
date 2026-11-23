alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)
File.rm("packing.retain")

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock},
    retain: "packing.retain",
    retain_period: 100
  )

# The processes linked to the runner, by the module that runs each.
linked = fn ->
  {:links, pids} = Process.info(runner, :links)
  for pid <- pids, pid != self(), do: elem(:proc_lib.translate_initial_call(pid), 0)
end

IO.inspect(linked.(), label: "at 0")
Sim.set(panel, "panel.i.0", 1)              # start pressed: k1 comes on
Manual.advance(clock, 110)                  # the first period of the store is at 100
Sim.set(panel, "panel.i.0", 0)
IO.inspect(linked.(), label: "at 110")

:ok = Runner.subscribe(runner, [:trip])
writes = length(Sim.writes(panel))
:ok = :sys.suspend(runner)                  # the runner is stuck: no round, no refresh
Manual.advance(clock, 509)
IO.inspect(Sim.outputs(panel), label: "stuck, at 619")
IO.inspect(length(Sim.writes(panel)) - writes, label: "writes while stuck")
Manual.advance(clock, 2)
IO.inspect(Sim.outputs(panel), label: "stuck, at 621")

:ok = :sys.resume(runner)
IO.inspect(Map.take(Runner.status(runner), [:status, :trip, :unzeroed]))
{:messages, messages} = Process.info(self(), :messages)
events = for {Runner, ^runner, event} <- messages, do: event
IO.inspect(events, label: "events")

writes = length(Sim.writes(panel))
Manual.advance(clock, 200)
IO.inspect(length(Sim.writes(panel)) - writes, label: "writes in 200 ms after the trip")
:ok = Runner.stop(runner)
File.rm("packing.retain")
