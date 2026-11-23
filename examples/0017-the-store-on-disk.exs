alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
Enum.each(Path.wildcard("tally.retain*"), &File.rm/1)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "tally.retain"
]

show = fn runner, title ->
  %{dropped: dropped, copy: copy, warning: warning} = Runner.status(runner).retain
  IO.puts(title)
  IO.puts("  t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} copy=#{inspect(copy)}")
  IO.puts("  dropped=#{inspect(dropped)}")
  IO.puts("  warning=#{inspect(warning)}")
end

refused = fn title ->
  IO.puts(title)

  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

edit = fn from, to ->
  File.write!("tally.retain", String.replace(File.read!("tally.retain"), from, to))
end

files = fn ->
  IO.puts("  files: " <> Enum.join(Enum.sort(Path.wildcard("tally.retain*")), " "))
end

{:ok, runner} = Runner.start_link(opts)

for eye <- [1, 0, 1, 0, 1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

:ok = Runner.stop(runner)
IO.puts("1. Four boxes, then a stop. The store:")
IO.write(File.read!("tally.retain"))

# A deploy: boxes made a ctu_int, and full not retained.
source =
  File.read!("tally.ld")
  |> String.replace("var retain boxes ctu", "var retain boxes ctu_int")
  |> String.replace("var_output retain full bool", "var_output full bool")

{:ok, changed} = Logex.compile(source, name: "tally")

{:ok, deploy} =
  Logex.Configuration.compile("tally", File.read!("tally.logex"), %{"tally" => changed})

{:ok, runner} = Runner.start_link(Keyword.put(opts, :configuration, deploy))
show.(runner, "2. A fresh start of the deploy")
:ok = Runner.stop(runner)

File.cp!("tally.retain.dropped.1", "tally.retain")
{:ok, runner} = Runner.start_link(opts)
show.(runner, "3. The copy put back, and a fresh start of the program before the deploy")
:ok = Runner.stop(runner)

text = File.read!("tally.retain")
File.write!("tally.retain", binary_part(text, 0, byte_size(text) - 40))
refused.("4. The store cut short by 40 bytes")

{:ok, runner} = Runner.start_link(opts ++ [start: :cold])
show.(runner, "5. A start with start: :cold")
:ok = Runner.stop(runner)
files.()

edit.("configuration tally", "configuration line_2")
refused.("6. The configuration line edited by hand")

edit.("configuration line_2", "configuration tally")
edit.("t1.boxes.cv dint 0\n", "t1.boxes.cv dint 0\nt1.boxes.cv dint 2\n")
refused.("7. A line added by hand, and the count not changed")

edit.("t1.boxes.cv dint 0\n", "")
edit.("\n", "\r\n")
{:ok, runner} = Runner.start_link(opts)
show.(runner, "8. The old line taken out, the store saved with CRLF line ends")
:ok = Runner.stop(runner)
