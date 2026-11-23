alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("trip.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)
File.rm("trip.forces")

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock},
    forces: "trip.forces"
  )

:ok = Runner.subscribe(runner, [:ran, :round])

# Prints the rounds and the runs of the task trip since the last call, and removes them.
event = fn
  {:round, _now, _outputs} -> "round"
  {:ran, task, _instance, _now} -> "#{task} ran"
end

# Waits until the runner served the calls before, then reads the events in the mailbox.
events = fn label ->
  :sys.get_state(runner)
  {:messages, messages} = Process.info(self(), :messages)
  seen = for {Runner, ^runner, message} <- messages, do: event.(message)
  for {Runner, ^runner, _} <- messages, do: receive(do: ({Runner, ^runner, _} -> :ok))
  IO.puts("#{label}: #{inspect(seen)}")
end

:ok = Runner.force(runner, "estop", 1)
events.("force estop 1")
:ok = Runner.force(runner, "estop", 1)
events.("force estop 1 again")
:ok = Runner.force(runner, "estop", 0)
events.("force estop 0")
Sim.set(panel, "panel.i.7", 1)
events.("the device gives 1")
:ok = Runner.unforce(runner, "estop")
events.("unforce estop")
:ok = Runner.stop(runner)
File.rm("trip.forces")
