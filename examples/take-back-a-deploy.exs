alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, release_1} = Logex.Configuration.compile_file("tally.logex")
{:ok, release_2} = Logex.Configuration.compile_file("take-back-a-deploy/release-2/tally.logex")

# No store and no copy from an earlier run.
for file <- File.ls!(), String.starts_with?(file, "tally.retain"), do: File.rm!(file)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

start = fn configuration ->
  {:ok, runner} =
    Runner.start_link(
      configuration: configuration,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      retain: "tally.retain"
    )

  runner
end

# Prints the count of the case, the total and what the start dropped.
show = fn label, runner ->
  retain = Runner.status(runner).retain

  IO.puts(
    "#{label}: t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} " <>
      "total_boxes=#{Runner.get!(runner, "total_boxes")} " <>
      "dropped=#{inspect(retain.dropped)} copy=#{inspect(retain.copy)}"
  )
end

# The eye sees n boxes, 1 box each 2 s.
boxes = fn n ->
  for _box <- 1..n, eye <- [1, 0] do
    Sim.set(panel, "panel.i.0", eye)
    Manual.advance(clock, 1000)
  end
end

# Release 1 counts 2 boxes. The stop writes the store.
runner = start.(release_1)
boxes.(2)
show.("release 1", runner)
:ok = Runner.stop(runner)

# The deploy: release 2 starts from the store and counts 1 box.
runner = start.(release_2)
show.("release 2 starts", runner)
boxes.(1)
show.("release 2 runs", runner)

# Step 1: read the status before the stop.
%{copy: copy, warning: warning} = Runner.status(runner).retain
IO.puts(warning)

# Step 2: stop the runner. The stop writes the store.
:ok = Runner.stop(runner)

# Step 4: copy the store of release 2 aside, and put the copy in place of the store.
File.cp!("tally.retain", "tally.retain.release-2")
File.cp!(copy, "tally.retain")

# Step 5: start release 1 again.
runner = start.(release_1)
show.("release 1 again", runner)
IO.puts("warning: #{inspect(Runner.status(runner).retain.warning)}")
:ok = Runner.stop(runner)

# The copies stay beside the store.
files = File.ls!() |> Enum.filter(&String.starts_with?(&1, "tally.retain")) |> Enum.sort()
IO.puts(Enum.join(files, " "))
