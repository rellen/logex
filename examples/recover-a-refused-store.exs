alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")

# No store and no copy from an earlier run. This deletes tally.retain.bak also.
for file <- File.ls!(), String.starts_with?(file, "tally.retain"), do: File.rm!(file)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "tally.retain"
]

# Starts a runner, prints 2 values and the status of the store, and stops
# the runner. If the start refuses the store, it prints the message.
start = fn label, more ->
  IO.puts("-- #{label}")

  try do
    {:ok, runner} = Runner.start_link(opts ++ more)
    retain = Runner.status(runner).retain

    IO.puts(
      "t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} " <>
        "total_boxes=#{Runner.get!(runner, "total_boxes")} " <>
        "dropped=#{inspect(retain.dropped)} copy=#{inspect(retain.copy)}"
    )

    :ok = Runner.stop(runner)
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

# 3 boxes fill the case. The stop writes the store.
{:ok, runner} = Runner.start_link(opts)

for eye <- [1, 0, 1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

:ok = Runner.stop(runner)
good = File.read!("tally.retain")

# Case 1: a person adds a comment to the store.
File.write!("tally.retain", String.replace(good, "instance t1", "# 3 boxes\ninstance t1"))
start.("a comment", [])

# The mend: remove the comment. The count of lines is correct again.
File.write!("tally.retain", String.replace(File.read!("tally.retain"), "# 3 boxes\n", ""))
start.("the comment removed", [])

# Case 2: the store loses its last 7 lines.
cut = good |> String.split("\n") |> Enum.take(8) |> Enum.join("\n")
File.write!("tally.retain", cut <> "\n")
start.("cut short", [])

# A wrong mend: an end line for the 8 lines that are left.
File.write!("tally.retain", cut <> "\nend 9 lines\n")
start.("an end line added", [])

# Or a cold start over the store that is cut short.
File.write!("tally.retain", cut <> "\n")
start.("start: :cold", start: :cold)
IO.puts("the copy holds the cut store: #{File.read!("tally.retain.dropped.1") == cut <> "\n"}")
