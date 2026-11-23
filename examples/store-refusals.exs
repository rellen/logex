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

# A good store: the start writes it, and the stop writes it again.
{:ok, runner} = Runner.start_link(opts)
:ok = Runner.stop(runner)
good = File.read!("tally.retain")

start = fn label, text ->
  File.write!("tally.retain", text)
  IO.puts("-- #{label}")

  try do
    {:ok, runner} = Runner.start_link(opts)
    retain = Runner.status(runner).retain

    IO.puts(
      "started, count #{Runner.get!(runner, "t1.boxes.cv")}, dropped #{inspect(retain.dropped)}"
    )

    :ok = Runner.stop(runner)
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

# A line added or removed, with the count of the end line changed to match.
counted = fn text, lines -> String.replace(text, "end 15 lines", "end #{lines} lines") end

start.("1. the end line taken away", String.replace(good, "end 15 lines\n", ""))
start.("2. the file cut inside the end line", String.replace(good, "end 15 lines\n", "end 1"))

start.(
  "3. a line doubled, the count kept",
  String.replace(good, "t1.full bool 0\n", "t1.full bool 0\nt1.full bool 0\n")
)

start.(
  "4. a comment",
  String.replace(good, "instance t1 tally\n", "# counted by hand\ninstance t1 tally\n")
)

start.("5. an empty line after the end line", good <> "\n")
start.("6. a byte-order mark", "﻿" <> good)
start.("7. a tab", String.replace(good, "t1.boxes ctu", "t1.boxes\tctu"))
start.("8. a byte that is not ASCII", String.replace(good, "t1.full bool 0", "t1.fullé bool 0"))
start.("9. an empty file", "")
start.("10. version 4", String.replace(good, "logex retain 3", "logex retain 4"))

start.(
  "11. an end line under logex retain 1",
  good
  |> String.replace("logex retain 3", "logex retain 1")
  |> String.replace(~r/^(resource|program) .*\n/m, "")
  |> counted.(13)
)

start.(
  "12. no configuration line",
  good |> String.replace(~r/^configuration .*\n/m, "") |> counted.(14)
)

start.(
  "13. no resource line and no program line",
  good |> String.replace(~r/^(resource|program) .*\n/m, "") |> counted.(13)
)

start.(
  "14. a resource line and no program line",
  good |> String.replace(~r/^program .*\n/m, "") |> counted.(14)
)

start.(
  "15. a digest with a wrong character",
  String.replace(good, "resource 013cc", "resource 013cZ")
)

start.(
  "16. a line before the first instance line",
  good |> String.replace("instance t1 tally\n", "junk here\ninstance t1 tally\n") |> counted.(16)
)

start.("17. a word that is no type", String.replace(good, "cv dint 0", "cv dnt 0"))
start.("18. a word that is no number", String.replace(good, "cv dint 0", "cv dint +5"))
start.("19. a based number", String.replace(good, "cv dint 0", "cv dint 16#5"))
start.("20. a value that does not fit its type", String.replace(good, "cv dint 0", "cv dint 5.0"))

start.(
  "21. CRLF line ends, a count of 7",
  good |> String.replace("cv dint 0", "cv dint 7") |> String.replace("\n", "\r\n")
)
