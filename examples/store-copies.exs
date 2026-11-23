alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, good} = Logex.Configuration.compile_file("tally.logex")

# No store and no copy from an earlier run.
for file <- File.ls!(), String.starts_with?(file, "tally.retain"), do: File.rm!(file)

# A mistaken deploy: the counter of tally.ld made a ctu_int.
{:ok, recount} =
  Logex.compile(String.replace(File.read!("tally.ld"), "boxes ctu", "boxes ctu_int"),
    name: "tally"
  )

{:ok, mistaken} =
  Logex.Configuration.compile("tally", File.read!("tally.logex"), %{"tally" => recount})

{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

start = fn configuration, more ->
  opts = [
    configuration: configuration,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock},
    retain: "tally.retain"
  ]

  {:ok, runner} = Runner.start_link(opts ++ more)
  retain = Runner.status(runner).retain

  IO.puts(
    "count=#{Runner.get!(runner, "t1.boxes.cv")} dropped=#{inspect(retain.dropped)} copy=#{inspect(retain.copy)}"
  )

  runner
end

# 2 boxes, then a stop: the store holds the count 2.
runner = start.(good, [])

for eye <- [1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

:ok = Runner.stop(runner)

IO.puts("-- the mistaken deploy")
:ok = Runner.stop(start.(mistaken, []))
IO.puts("-- the good configuration again")
:ok = Runner.stop(start.(good, []))
IO.puts("-- the copy put back")
File.cp!("tally.retain.dropped.1", "tally.retain")
:ok = Runner.stop(start.(good, []))

IO.puts("-- a store cut short, started cold")
File.write!("tally.retain", String.replace(File.read!("tally.retain"), ~r/end \d+ lines\n/, ""))
:ok = Runner.stop(start.(good, start: :cold))

File.ls!()
|> Enum.filter(&String.starts_with?(&1, "tally.retain"))
|> Enum.sort()
|> Enum.each(&IO.puts/1)
