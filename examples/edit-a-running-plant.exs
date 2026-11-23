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

:ok = Runner.subscribe(runner, [:ran])

show = fn label ->
  %{now: now, edit: stage, runs: %{"fast" => {_longest, watchdog}}} = Runner.status(runner)
  %{"panel.q.4" => case_full} = Sim.outputs(panel)
  boxes = Runner.get!(runner, "b1.count")
  values = "boxes=#{boxes}  case_full=#{case_full}  watchdog=#{watchdog}"
  IO.puts("t=#{now}  #{values}  stage=#{inspect(stage)}  #{label}")
end

print = fn report, label ->
  IO.puts(label)
  Enum.each(report, &IO.puts("        #{inspect(&1)}"))
end

box = fn ->
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 1)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 1)
end

# The old plant runs, and 2 boxes go past the photo-eye.
Manual.advance(clock, 10)
box.()
box.()
show.("the old plant, box 2")

# The edit: the new plant goes in the place of the old plant.
{:ok, new_plant} = Logex.Configuration.compile_file("edit-a-running-plant/packing.logex")
{:ok, forecast} = Runner.accept(runner, new_plant)
print.(forecast, "forecast")
show.("accepted")
{:ok, report} = Runner.test(runner)
print.(report, "test")
box.()
show.("under test, box 3")
{:ok, report} = Runner.assemble(runner)
print.(report, "assemble")
box.()
box.()
Manual.advance(clock, 10)
show.("the new plant, box 5")

{:messages, messages} = Process.info(self(), :messages)
IO.inspect(for({Runner, _, {:ran, "fast", "c1", at}} <- messages, do: at), label: "c1 ran at")
:ok = Runner.stop(runner)
