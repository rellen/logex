alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

# A manual clock on a computer that stalls. The next reading of the time by the runner
# passes the milliseconds that the agent holds, and no device gets a wake meanwhile.
defmodule Stalled do
  @behaviour Logex.Runner.Clock

  def now_ms({clock, agent}) do
    me = self()
    Manual.pass(clock, Agent.get_and_update(agent, &stall(&1, me)))
    Manual.now_ms(clock)
  end

  def wake_at({clock, _agent}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)
  def cancel({clock, _agent}, timer), do: Manual.cancel(clock, timer)

  defp stall({runner, ms}, runner), do: {ms, {runner, 0}}
  defp stall(stalls, _reader), do: {0, stalls}
end

programs =
  Map.new(~w(conveyor fan), fn name ->
    {:ok, program} = Logex.compile_file(name <> ".ld")
    {name, program}
  end)

text = File.read!("0014-devices-are-processes/plant.logex")
{:ok, plant} = Logex.Configuration.compile("plant", text, programs)

# Starts the plant at 0 ms with an idle watchdog of 50 ms. The operator starts the
# conveyor at 9 ms, and the drive reads 25 Hz. At 10 ms, k1 is 1. At 500 ms the task of
# the fan runs, and fan_rpm is 1500.
started = fn ->
  {:ok, clock} = Manual.start_link()
  {:ok, stalls} = Agent.start_link(fn -> {nil, 0} end)
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)
  {:ok, drive} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
      clock: {Stalled, {clock, stalls}},
      idle: 50
    )

  Agent.update(stalls, fn _stalls -> {runner, 0} end)
  Manual.advance(clock, 9)
  Sim.set(panel, "panel.i.0", 1)
  Sim.set(drive, "drive.i.0", 25.0)
  Manual.advance(clock, 1)
  Sim.set(panel, "panel.i.0", 0)
  %{runner: runner, clock: clock, stalls: stalls, panel: panel, drive: drive}
end

# Prints the time, k1 at the panel and fan_rpm at the drive.
outputs = fn %{clock: clock, panel: panel, drive: drive} ->
  IO.puts(
    "  at #{Manual.now_ms(clock)} ms: k1 at the panel #{Sim.outputs(panel)["panel.q.0"]}, " <>
      "fan_rpm at the drive #{Sim.outputs(drive)["drive.q.0"]}"
  )
end

# Prints the fields of status/1 that the list names, in its order, from 1 call.
status = fn %{runner: runner}, keys ->
  status = Runner.status(runner)
  IO.puts("  " <> inspect(for(key <- keys, do: {key, Map.fetch!(status, key)})))
end

IO.puts("1. No output changes for 100 ms")
plant_1 = started.()
Manual.advance(plant_1.clock, 990)

{panel_writes, drive_writes} =
  {length(Sim.writes(plant_1.panel)), length(Sim.writes(plant_1.drive))}

Manual.advance(plant_1.clock, 100)

IO.puts(
  "  writes: panel #{length(Sim.writes(plant_1.panel)) - panel_writes}, " <>
    "drive #{length(Sim.writes(plant_1.drive)) - drive_writes}"
)

IO.puts("2. The runner is stuck between 2 rounds from 1000 ms")
plant_2 = started.()
Manual.advance(plant_2.clock, 990)
:sys.suspend(plant_2.runner)
Manual.advance(plant_2.clock, 59)
outputs.(plant_2)
Manual.advance(plant_2.clock, 1)
outputs.(plant_2)
:sys.resume(plant_2.runner)
status.(plant_2, [:status, :trip])

IO.puts("3. In the round at 1000 ms, the drive and the panel each take 59 ms to write")
plant_3 = started.()
Manual.advance(plant_3.clock, 980)
# The first delay of each device goes to its write at the poll of 1000 ms.
for sim <- [plant_3.drive, plant_3.panel],
    delay <- [0, 59],
    do: Sim.fail(sim, :write, {:delay, delay})

Sim.set(plant_3.drive, "drive.i.0", 30.0)
Sim.set(plant_3.panel, "panel.i.7", 1)
Manual.advance(plant_3.clock, 10)
outputs.(plant_3)
status.(plant_3, [:status, :trip])

IO.puts("4. In the round at 1000 ms, the drive takes 60 ms to write, and k1 stays 1")
plant_4 = started.()
Manual.advance(plant_4.clock, 980)
for delay <- [0, 60], do: Sim.fail(plant_4.drive, :write, {:delay, delay})
Sim.set(plant_4.drive, "drive.i.0", 30.0)
Manual.advance(plant_4.clock, 10)
status.(plant_4, [:status, :trip])
IO.puts("  the last 2 writes to the drive: #{inspect(Enum.take(Sim.writes(plant_4.drive), -2))}")
IO.puts("  the last write to the panel: #{inspect(List.last(Sim.writes(plant_4.panel)))}")

IO.puts("5. The drive refuses 3 writes: the write at its poll of 1000 ms, then 2 times its 0")
plant_5 = started.()
Manual.advance(plant_5.clock, 980)
for _write <- 1..3, do: Sim.fail(plant_5.drive, :write, {:error, :eio})

for _poll <- 1..3 do
  Manual.advance(plant_5.clock, 10)
  outputs.(plant_5)
  status.(plant_5, [:trip, :unzeroed])
end

IO.puts("6. At 1010 ms the computer stalls the runner and the devices: 210 ms, then 211 ms")

for stall <- [210, 211] do
  plant_6 = started.()
  Manual.advance(plant_6.clock, 990)
  Agent.update(plant_6.stalls, fn {runner, 0} -> {runner, stall} end)
  Manual.advance(plant_6.clock, 10)
  status.(plant_6, [:status, :trip, :latest_wake])
end
