alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

# A manual clock on a busy machine: each reading of the time passes the milliseconds
# that the agent `cost` holds.
defmodule Busy do
  @behaviour Logex.Runner.Clock

  def now_ms({clock, cost}) do
    Manual.pass(clock, Agent.get(cost, & &1))
    Manual.now_ms(clock)
  end

  def wake_at({clock, _cost}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)
  def cancel({clock, _cost}, timer), do: Manual.cancel(clock, timer)
end

programs =
  Map.new(~w(conveyor boxes), fn name ->
    {:ok, program} = Logex.compile_file(name <> ".ld")
    {name, program}
  end)

text = File.read!("0013-watchdogs-and-the-trip/plant.logex")
{:ok, plant} = Logex.Configuration.compile("plant", text, programs)

{:ok, clock} = Manual.start_link()
{:ok, cost} = Agent.start_link(fn -> 0 end)
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Busy, {clock, cost}}
  )

# Prints the fields of status/1 that the list names, in its order.
status = fn keys ->
  IO.puts("  " <> inspect(for(key <- keys, do: {key, Map.fetch!(Runner.status(runner), key)})))
end

# Prints k1 in the resource, k1 at the panel and the number of writes to the panel.
k1 = fn ->
  IO.puts(
    "  k1 in the resource #{Runner.get!(runner, "k1")}, k1 at the panel " <>
      "#{Sim.outputs(panel)["panel.q.0"]}, writes to the panel #{length(Sim.writes(panel))}"
  )
end

# Runs the clock to 10 ms with each reading at `ms`, then sets the cost back to 0.
busy = fn ms ->
  Agent.update(cost, fn _ -> ms end)
  Manual.advance(clock, 10)
  Agent.update(cost, fn _ -> 0 end)
end

IO.puts("1. The conveyor's scan takes 120 ms, and its watchdog is 100 ms")
Manual.advance(clock, 9)
Sim.set(panel, "panel.i.0", 1)
busy.(60)
status.([:status, :trip, :rounds, :now])
k1.()

IO.puts("2. Tripped: 1000 ms pass")
Sim.set(panel, "panel.i.0", 0)
Manual.advance(clock, 1000)
status.([:status, :rounds, :now])
k1.()

IO.puts("3. A restart while a read of the panel fails")
Sim.fail(panel, :read, {:error, :eio})
IO.puts("  " <> inspect(Runner.restart(runner, :cold)))
status.([:status, :trip])
k1.()

IO.puts("4. A cold restart")
IO.puts("  " <> inspect(Runner.restart(runner, :cold)))
status.([:status, :trip, :rounds, :now])
k1.()

IO.puts("5. A round takes 210 ms, and the watchdog of main is 200 ms")
Sim.set(panel, "panel.i.0", 1)
Manual.advance(clock, 10)
Sim.set(panel, "panel.i.0", 0)
k1.()
busy.(30)
status.([:status, :trip])
k1.()
