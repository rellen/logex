alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("trips-and-watchdogs/line.logex")

# A runner on a manual clock. The operator presses start at 0 ms, and k1 comes on.
started = fn ->
  {:ok, clock} = Manual.start_link()
  # reports: true: the panel tells the runner of each change of an input.
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock}
    )

  Sim.set(panel, "panel.i.0", 1)
  Manual.advance(clock, 10)
  Sim.set(panel, "panel.i.0", 0)
  {runner, clock, panel}
end

panel_k1 = fn panel -> Sim.outputs(panel)["panel.q.0"] end

show = fn runner, panel ->
  %{trip: trip, unzeroed: unzeroed} = Runner.status(runner)
  IO.puts("  trip:            #{inspect(trip)}")
  IO.puts("  k1 in resource:  #{Runner.get!(runner, "k1")}")
  IO.puts("  k1 at the panel: #{panel_k1.(panel)}")
  IO.puts("  unzeroed:        #{inspect(unzeroed)}")
  :ok = Runner.stop(runner)
end

IO.puts("1. A read of the panel fails")
{runner, clock, panel} = started.()
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 15)
show.(runner, panel)

IO.puts("2. The runner is stuck between rounds from 10 ms")
{runner, clock, panel} = started.()
:sys.suspend(runner)
Manual.advance(clock, 509)
IO.puts("  at 519 ms, k1 at the panel: #{panel_k1.(panel)}")
Manual.advance(clock, 1)
IO.puts("  at 520 ms, k1 at the panel: #{panel_k1.(panel)}")
:sys.resume(runner)
show.(runner, panel)

IO.puts("3. The panel hangs in a read (on the real clock)")
{:ok, panel} = Sim.start_link(reports: true)
{:ok, runner} = Runner.start_link(configuration: plant, io: %{"panel" => {Sim, sim: panel}})
:ok = Runner.subscribe(runner, [:trip])
Sim.set(panel, "panel.i.0", 1)

on = fn
  _on, 1 ->
    :ok

  on, _k1 ->
    Process.sleep(10)
    on.(on, panel_k1.(panel))
end

on.(on, panel_k1.(panel))
Sim.set(panel, "panel.i.0", 0)
Sim.fail(panel, :read, :hang)

receive do
  {Runner, ^runner, {:trip, _reason}} -> :ok
end

show.(runner, panel)
