alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
File.rm("tally.retain")                           # start with no store

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "tally.retain",                         # the path of the store
  retain_period: 1000                             # a write each 1000 ms
]

show = fn runner, label ->
  IO.puts(
    "#{label}  total_boxes=#{Runner.get!(runner, "total_boxes")} " <>
      "t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} " <>
      "case_full=#{Runner.get!(runner, "case_full")}"
  )
end

# 1 box: the eye is on for half_ms, then off for half_ms.
box = fn half_ms ->
  Sim.set(panel, "panel.i.0", 1)
  Manual.advance(clock, half_ms)
  Sim.set(panel, "panel.i.0", 0)
  Manual.advance(clock, half_ms)
end

# Waits until the last write of the store is at the time time_of_write.
# After 5 s with no such write, it gives nil.
written = fn runner, time_of_write ->
  Stream.repeatedly(fn ->
    Process.sleep(10)
    Runner.status(runner).retain.written_at
  end)
  |> Stream.take(500)
  |> Enum.find(&(&1 == time_of_write))
end

{:ok, runner} = Runner.start_link(opts)
IO.inspect(Runner.status(runner).retain.written_at, label: "first write")

# 2 boxes in 4 s. The runner writes the store each second.
box.(1000)
box.(1000)
show.(runner, "2 boxes     ")

# A third box, in 400 ms, after the write at 14:00:04.
box.(200)
show.(runner, "3 boxes     ")
IO.inspect(written.(runner, ~U[2026-10-30 14:00:04Z]), label: "last write")

# A crash: kill the runner. It writes nothing. The kill also stops the
# process of the device panel. This line hides the report of the logger.
Logger.configure(level: :none)
# The runner is linked to this script. Unlink it, so that the script runs on.
Process.unlink(runner)
ref = Process.monitor(runner)
Process.exit(runner, :kill)

receive do
  {:DOWN, ^ref, :process, _pid, reason} -> IO.inspect(reason, label: "runner")
end

IO.write(File.read!("tally.retain"))

# A fresh start reads the store: it is warm.
{:ok, runner} = Runner.start_link(opts)
show.(runner, "fresh start ")
IO.inspect(Runner.stop(runner), label: "stop")

# A cold start writes the initial values over the store.
{:ok, runner} = Runner.start_link(Keyword.put(opts, :start, :cold))
show.(runner, "start: :cold")
:ok = Runner.stop(runner)
