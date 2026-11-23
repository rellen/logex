alias Logex.Runner
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, panel} = Sim.start_link(reports: true)
options = [configuration: plant, io: %{"panel" => {Sim, sim: panel}}, name: Packing]

spec = Runner.child_spec(options)
IO.inspect(Map.take(spec, [:restart, :shutdown]), label: "the child spec")

{:ok, supervisor} = Supervisor.start_link([spec], strategy: :one_for_one)

# Press start, then wait for the round that writes 1 to k1.
:ok = Runner.subscribe(Packing, [:round])
Sim.set(panel, "panel.i.0", 1)

receive do
  {Runner, _runner, {:round, _now, %{"k1" => 1}}} -> IO.puts("k1 is 1")
after
  5_000 -> IO.puts("no round wrote 1 to k1 in 5 s")
end

:ok = Runner.unsubscribe(Packing)

# Stop the supervisor. It stops the runner as Runner.stop/1 does.
:ok = Supervisor.stop(supervisor)
IO.inspect(List.last(Sim.writes(panel)), label: "the last write")
IO.inspect(Sim.closed?(panel), label: "closed")
