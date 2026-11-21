alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

# Starts a runner of the configuration on a manual clock, with 1 simulated panel.
start = fn file ->
  {:ok, plant} = Logex.Configuration.compile_file(file)
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock}
    )

  {runner, clock, panel}
end

show = fn runner, label ->
  %{now: now, rounds: rounds} = Runner.status(runner)
  boxes = Runner.get!(runner, "b1.boxes.cv")
  IO.puts("#{String.pad_trailing(label, 22)}  now=#{now}  rounds=#{rounds}  boxes=#{boxes}")
end

IO.puts("line.logex: b1 is in the continuous task")
{runner, clock, panel} = start.("execution-model/line.logex")
show.(runner, "start")
Manual.advance(clock, 10)
show.(runner, "advance 10 ms")
Sim.set(panel, "panel.i.2", 1)
show.(runner, "eye 1")
Sim.set(panel, "panel.i.0", 1)
show.(runner, "estop 1")
:ok = Runner.stop(runner)

IO.puts("timed.logex: each program has a timed task")
{runner, clock, panel} = start.("execution-model/timed.logex")
show.(runner, "start")
Manual.advance(clock, 3)
show.(runner, "advance 3 ms")
Sim.set(panel, "panel.i.2", 1)
Sim.set(panel, "panel.i.2", 0)
show.(runner, "eye 1, then eye 0")
Manual.advance(clock, 7)
show.(runner, "advance 7 ms")
Sim.set(panel, "panel.i.2", 1)
show.(runner, "eye 1")
Manual.advance(clock, 10)
show.(runner, "advance 10 ms")
Sim.set(panel, "panel.i.0", 1)
show.(runner, "estop 1")
Sim.set(panel, "panel.i.0", 0)
show.(runner, "estop 0")
:ok = Runner.stop(runner)
