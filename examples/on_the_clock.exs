alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

show = fn label ->
  %{now: now, rounds: rounds} = Runner.status(runner)
  out = Sim.outputs(panel)
  IO.puts("t=#{String.pad_leading("#{now}", 2)}  #{label}  rounds=#{String.pad_leading("#{rounds}", 2)}  k1=#{out["panel.q.0"]} case_full=#{out["panel.q.4"]}  boxes=#{Runner.get!(runner, "b1.count")}")
end

show.("started        ")
Sim.set(panel, "panel.i.0", 1)              # pb_start_1, reported and merged at once
Manual.advance(clock, 10)                   # a round each millisecond, the conveyor's at 10
show.("start pressed  ")
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)            # a box on the eye...
  Manual.advance(clock, 2)
  Sim.set(panel, "panel.i.8", 0)            # ...and past it
  Manual.advance(clock, 2)
end

show.("three boxes    ")
:ok = Runner.subscribe(runner, [:ran])
Sim.set(panel, "panel.i.7", 1)              # the e-stop, which the conveyor reads at 30
Manual.advance(clock, 10)
show.("e-stop at 22   ")
IO.inspect(for({Runner, ^runner, {:ran, "fast", i, at}} <- Process.info(self(), :messages) |> elem(1), do: {i, at}), label: "the conveyor ran")
IO.inspect(for(key <- [:runs, :overlaps, :latest_wake], do: {key, Map.fetch!(Runner.status(runner), key)}))

:ok = Runner.stop(runner)
IO.inspect(Enum.take(Sim.writes(panel), -2), label: "the last two writes")
IO.inspect(Sim.closed?(panel), label: "closed")
