alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
Enum.each(Path.wildcard("box.retain*"), &File.rm!/1)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)
io = %{"panel" => {Sim, sim: panel}}
opts = [configuration: plant, io: io, clock: {Manual, clock}, retain: "box.retain"]
wrap = fn text -> Regex.replace(~r/(.{1,56})( |$)/, text, "\\1\n") end

# Count 2 boxes, then stop: the stop writes the store.
{:ok, runner} = Runner.start_link(opts)

for eye <- [1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

:ok = Runner.stop(runner)
text = File.read!("box.retain")
IO.write(text)

# Cut the last 40 bytes off the store, as a lost tail of a file does.
File.write!("box.retain", binary_part(text, 0, byte_size(text) - 40))

try do
  Runner.start_link(opts)
rescue
  error in ArgumentError -> IO.write(wrap.(error.message))
end

# A cold start copies the refused store, then writes a new store.
{:ok, runner} = Runner.start_link(opts ++ [start: :cold])
IO.inspect(Runner.status(runner).retain.copy, label: "copy")
:ok = Runner.stop(runner)
IO.inspect(Enum.sort(Path.wildcard("box.retain*")), label: "files")
