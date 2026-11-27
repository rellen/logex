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
counted = fn text, lines -> String.replace(text, "end 16 lines", "end #{lines} lines") end

# A value line edited, with the digest mended to match: the MD5 of every line after the
# configuration's line, but the naming lines, the digest and the end line, each with LF.
sealed = fn text ->
  [_header, _configuration | lines] = String.split(text, "\n", trim: true)
  naming = ["resource ", "program ", "digest ", "end "]
  values = for line <- lines, not String.starts_with?(line, naming), do: [line, ?\n]
  digest = Base.encode16(:erlang.md5(values), case: :lower)
  String.replace(text, ~r/^digest \w+$/m, "digest #{digest}")
end

start.("1. the end line taken away", String.replace(good, "end 16 lines\n", ""))
start.("2. the file cut inside the end line", String.replace(good, "end 16 lines\n", "end 1"))

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
start.("10. version 5", String.replace(good, "logex retain 4", "logex retain 5"))

start.(
  "11. an end line under logex retain 1",
  good
  |> String.replace("logex retain 4", "logex retain 1")
  |> String.replace(~r/^(resource|program|digest) .*\n/m, "")
  |> counted.(13)
)

start.(
  "12. no configuration line",
  good |> String.replace(~r/^configuration .*\n/m, "") |> counted.(15)
)

start.(
  "13. no resource line and no program line",
  good |> String.replace(~r/^(resource|program) .*\n/m, "") |> counted.(14)
)

start.(
  "14. a resource line and no program line",
  good |> String.replace(~r/^program .*\n/m, "") |> counted.(15)
)

start.(
  "15. a digest with a wrong character",
  String.replace(good, "resource 013cc", "resource 013cZ")
)

start.(
  "16. a line before the first instance line",
  good |> String.replace("instance t1 tally\n", "junk here\ninstance t1 tally\n") |> counted.(17)
)

start.("17. a word that is no type", String.replace(good, "cv dint 0", "cv dnt 0"))
start.("18. a word that is no number", String.replace(good, "cv dint 0", "cv dint +5"))
start.("19. a based number", good |> String.replace("cv dint 0", "cv dint 16#5") |> sealed.())

start.(
  "20. a value that does not fit its type",
  good |> String.replace("cv dint 0", "cv dint 5.0") |> sealed.()
)

start.(
  "21. CRLF line ends, a count of 7",
  good |> String.replace("cv dint 0", "cv dint 7") |> sealed.() |> String.replace("\n", "\r\n")
)

start.("22. a value changed, the digest kept", String.replace(good, "cv dint 0", "cv dint 7"))

start.(
  "23. a line removed, its count mended, the digest kept",
  good |> String.replace("t1.full bool 0\n", "") |> counted.(15)
)

start.(
  "24. no digest line, its count mended",
  good |> String.replace(~r/^digest .*\n/m, "") |> counted.(15)
)

start.(
  "25. a store of version 3, which holds no digest",
  good
  |> String.replace("logex retain 4", "logex retain 3")
  |> String.replace(~r/^digest .*\n/m, "")
  |> String.replace("cv dint 0", "cv dint 3")
  |> counted.(15)
)

start.(
  "26. a digest line with a digit lost",
  String.replace(good, ~r/^digest (\w{31})\w$/m, "digest \\1")
)
