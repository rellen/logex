alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
File.rm("tally.retain")

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "tally.retain"
]

show = fn runner, label ->
  IO.puts("#{label}  total_boxes=#{Runner.get!(runner, "total_boxes")} " <>
            "t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} " <>
            "case_full=#{Runner.get!(runner, "case_full")}")
end

{:ok, runner} = Runner.start_link(opts)

for eye <- [1, 0, 1, 0, 1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

show.(runner, "four boxes  ")
IO.inspect(Runner.stop(runner), label: "stop")
IO.write(File.read!("tally.retain"))

{:ok, runner} = Runner.start_link(opts)
show.(runner, "fresh start ")
IO.inspect(Runner.status(runner).retain.written_at, label: "written_at")
:ok = Runner.stop(runner)

{:ok, runner} = Runner.start_link(opts ++ [start: :cold])
show.(runner, "start: :cold")
:ok = Runner.stop(runner)

# An edit made online and assembled, never written to tally.ld.
{:ok, coil} = Logex.compile(String.replace(File.read!("tally.ld"), "otl full", "ote full"), name: "tally")
{:ok, edited} = Logex.Configuration.compile("tally", File.read!("tally.logex"), %{"tally" => coil})
{:ok, runner} = Runner.start_link(opts)
{:ok, _forecast} = Runner.accept(runner, edited)
{:ok, _report} = Runner.test(runner)
{:ok, _report} = Runner.assemble(runner)
:ok = Runner.stop(runner)

{:ok, runner} = Runner.start_link(opts)
IO.puts(Runner.status(runner).retain.warning)
:ok = Runner.stop(runner)

File.write!("tally.retain", String.replace(File.read!("tally.retain"), "configuration tally", "configuration line_2"))

try do
  Runner.start_link(opts)
rescue
  error in ArgumentError -> IO.puts(error.message)
end
