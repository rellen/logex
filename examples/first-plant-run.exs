alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

pad = fn number -> String.pad_leading("#{number}", 2) end

show = fn label ->
  %{now: now, rounds: rounds} = Runner.status(runner)
  %{"panel.q.0" => k1, "panel.q.4" => case_full} = Sim.outputs(panel)
  boxes = Runner.get!(runner, "b1.count")
  values = "k1=#{k1}  case_full=#{case_full}  boxes=#{boxes}"
  IO.puts("t=#{pad.(now)}  rounds=#{pad.(rounds)}  #{values}  #{label}")
end

show.("the runner started")

Sim.set(panel, "panel.i.0", 1)
Manual.advance(clock, 10)
show.("the start button is 1")
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 2)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 2)
end

show.("3 boxes went past the photo-eye")

Sim.set(panel, "panel.i.7", 1)
Manual.advance(clock, 7)
show.("estop is 1 from 22 ms")
Manual.advance(clock, 1)
show.("c1 read estop")

:ok = Runner.stop(runner)
IO.inspect(Sim.outputs(panel), label: "after the stop")
IO.inspect(Sim.closed?(panel), label: "closed")
