alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
File.rm_rf!("disk")
File.mkdir_p!("disk")

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "disk/tally.retain"
]

# No store file: the start writes the store before it opens a device.
{:ok, runner} = Runner.start_link(opts)
IO.inspect(Runner.status(runner).retain.written_at, label: "written_at")
IO.puts(hd(String.split(File.read!("disk/tally.retain"), "\n")))

# The directory of the store goes away: the write of the stop fails.
File.rm_rf!("disk")
IO.inspect(Runner.stop(runner), label: "stop")

# The directory does not exist: the start cannot write its first store.
IO.inspect(Runner.start_link(opts), label: "start")
