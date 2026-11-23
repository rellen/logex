alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

# A killed runner's device logs its end. The results do not need that log.
Logger.configure(level: :none)
Process.flag(:trap_exit, true)

{:ok, plant} = Logex.Configuration.compile_file("0016-retained-values-and-starts/plant.logex")
Enum.each(plant.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
File.rm("line.retain")

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "line.retain",
  retain_period: 3_600_000
]

show = fn runner, title ->
  %{status: status, now: now, retain: %{written_at: written}} = Runner.status(runner)

  [boxes, lube, run_on] =
    Enum.map(["l1.boxes.cv", "l1.lube.acc", "l1.run_on.acc"], &Runner.get!(runner, &1))

  out = Sim.outputs(panel)
  IO.puts(title)
  IO.puts("  #{status}, now #{now} ms, store written #{DateTime.to_time(written)}")
  IO.puts("  boxes=#{boxes} lube=#{lube} run_on=#{run_on}")

  IO.puts(
    "  panel: k1=#{out["panel.q.0"]} fan_q=#{out["panel.q.1"]} full_lamp=#{out["panel.q.2"]}"
  )
end

press = fn address ->
  Sim.set(panel, address, 1)
  Manual.advance(clock, 100)
  Sim.set(panel, address, 0)
  Manual.advance(clock, 100)
end

box = fn ->
  Sim.set(panel, "panel.i.2", 1)
  Manual.advance(clock, 500)
  Sim.set(panel, "panel.i.2", 0)
  Manual.advance(clock, 500)
end

crash = fn runner ->
  Process.exit(runner, :kill)
  receive do: ({:EXIT, ^runner, :killed} -> :ok)
end

{:ok, runner} = Runner.start_link(opts)
show.(runner, "1. A start with no store file")

press.("panel.i.0")
box.()
box.()
show.(runner, "2. The motor runs, and 2 boxes pass the eye")

Sim.set(panel, "panel.i.2", 1)
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 100)
Manual.advance(clock, 10_000)
show.(runner, "3. A read fails, the runner trips, and 10 s pass. A box is at the eye")

:ok = Runner.restart(runner, :warm)
show.(runner, "4. A warm restart")

Sim.set(panel, "panel.i.2", 0)
press.("panel.i.0")
box.()
show.(runner, "5. The motor runs, and box 3 passes the eye")

crash.(runner)
{:ok, runner} = Runner.start_link(opts)
show.(runner, "6. A crash, then a fresh start")

press.("panel.i.0")
press.("panel.i.1")
Manual.advance(clock, 1_800)
:ok = Runner.stop(runner)
Manual.advance(clock, 60_000)
{:ok, runner} = Runner.start_link(opts)
show.(runner, "7. The stop button, Runner.stop/2 2 s later, a fresh start 60 s later")

Manual.advance(clock, 3_100)
show.(runner, "8. 3.1 s later")

:ok = Runner.stop(runner)
{:ok, runner} = Runner.start_link(opts ++ [start: :cold])
crash.(runner)
{:ok, runner} = Runner.start_link(opts)
show.(runner, "9. A start with start: :cold, a crash, then a fresh start")
:ok = Runner.stop(runner)
