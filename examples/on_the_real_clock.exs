alias Logex.Runner
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, panel} = Sim.start_link(reports: true)

# No clock: the machine's, Logex.Runner.Clock.Monotonic.
{:ok, runner} = Runner.start_link(configuration: plant, io: %{"panel" => {Sim, sim: panel}})

Sim.set(panel, "panel.i.0", 1)              # start pressed for 100 ms
Process.sleep(100)
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)            # a box on the eye for 20 ms, then 20 ms clear
  Process.sleep(20)
  Sim.set(panel, "panel.i.8", 0)
  Process.sleep(20)
end

Process.sleep(1_000)
status = Runner.status(runner)

IO.inspect(
  status: status.status,
  trip: status.trip,
  k1: Runner.get!(runner, "k1"),
  boxes: Runner.get!(runner, "b1.count"),
  case_full: Runner.get!(runner, "case_full"),
  no_more_rounds_than_milliseconds: status.rounds <= status.now + 1
)

IO.puts("this run's figures: now=#{status.now} rounds=#{status.rounds} " <>
  "runs=#{inspect(status.runs)} overlaps=#{inspect(status.overlaps)} latest_wake=#{status.latest_wake}")

:ok = Runner.stop(runner)
IO.inspect(List.last(Sim.writes(panel)), label: "the last write")
IO.inspect(Sim.closed?(panel), label: "closed")
