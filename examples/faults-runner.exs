alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, line} = Logex.Configuration.compile_file("faults/line.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: line,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

:ok = Runner.subscribe(runner)

# Gives an event or a trip with the kind of its fault in place of the fault.
short = fn
  {:fault, task, instance, fault} -> {:fault, task, instance, fault.kind}
  {:trip, {:fault, task, instance, fault}} -> {:trip, {:fault, task, instance, fault.kind}}
  other -> other
end

# Prints the status, 2 tags, the outputs of the panel, the trip and each new event.
show = fn label ->
  %{status: status, rounds: rounds, trip: trip} = Runner.status(runner)
  zone = Runner.get!(runner, "c1.zone")
  runs = Runner.get!(runner, "f1.runs")
  IO.puts("#{label}: #{status}, rounds=#{rounds}, zone=#{zone}, runs=#{runs}")
  IO.puts("  outputs #{inspect(Sim.outputs(panel))}")
  IO.puts("  trip #{inspect(short.(trip))}")

  {:messages, messages} = Process.info(self(), :messages)
  for {Runner, ^runner, event} <- messages, do: IO.puts("  event #{inspect(short.(event))}")
  for {Runner, ^runner, _event} <- messages, do: receive(do: ({Runner, ^runner, _} -> :ok))
end

Sim.set(panel, "panel.i.0", 1)
Sim.set(panel, "panel.i.3", 120)
Manual.advance(clock, 10)
show.("1 run, minutes 0")

Sim.set(panel, "panel.i.4", 2)
Manual.advance(clock, 10)
show.("2 minutes 2")

Sim.set(panel, "panel.i.1", 4)
Sim.set(panel, "panel.i.2", 1)
Manual.advance(clock, 10)
show.("3 zone 4")
IO.puts("  last write #{inspect(List.last(Sim.writes(panel)))}")
IO.inspect(Runner.status(runner).trip)

writes = length(Sim.writes(panel))
Manual.advance(clock, 100)
show.("4 100 ms later")
IO.puts("  writes since step 3: #{length(Sim.writes(panel)) - writes}")

Sim.set(panel, "panel.i.2", 0)
:ok = Runner.restart(runner, :warm)
show.("5 warm restart")

:ok = Runner.restart(runner, :cold)
show.("6 cold restart")
:ok = Runner.stop(runner)
