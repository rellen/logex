alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("edit-the-store-by-hand/packer.logex")

# No store and no backup from an earlier run.
for file <- File.ls!(), String.starts_with?(file, "packer.retain"), do: File.rm!(file)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "packer.retain"
]

{:ok, runner} = Runner.start_link(opts)

# 8 boxes: the scale weighs each box, then the eye sees it leave.
for weight <- [410, 520, 380, 600, 450, 470, 390, 505] do
  Sim.set(panel, "panel.i.0", weight)
  Manual.advance(clock, 10)
  Sim.set(panel, "panel.i.1", 1)
  Manual.advance(clock, 10)
  Sim.set(panel, %{"panel.i.0" => 0, "panel.i.1" => 0})
  Manual.advance(clock, 10)
end

# Step 1: find the tag and the store.
%{trip: {:fault, _task, instance, fault}, retain: %{path: store}} = Runner.status(runner)
IO.puts("trip: #{instance}, #{fault.file}, line #{fault.line}, read #{inspect(fault.read)}")
IO.puts("store: #{store}")

# Step 2: stop the runner. Step 3: copy the store to a backup.
:ok = Runner.stop(runner)
File.cp!("packer.retain", "packer.retain.bak")
IO.write(File.read!("packer.retain"))

# Steps 4 to 6: the hand edit, as a person makes it in a text editor: 8 becomes 0.
text = File.read!("packer.retain")
File.write!("packer.retain", String.replace(text, "s1.place dint 8\n", "s1.place dint 0\n"))

# Step 7: start the runner from the store. The start refuses it and tells the digest of
# its lines now: write that digest on the digest line, as a person does, and start again.
refused =
  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError -> error.message
  end

IO.puts(refused)
[_all, old, new] = Regex.run(~r/`digest (\w+)` is not .*, which is `(\w+)`/U, refused)
text = File.read!("packer.retain")
File.write!("packer.retain", String.replace(text, "digest #{old}\n", "digest #{new}\n"))
{:ok, runner} = Runner.start_link(opts)

# Step 8: check the value and dropped.
IO.inspect(Runner.get!(runner, "s1.place"), label: "s1.place")
IO.inspect(Runner.status(runner).retain.dropped, label: "dropped")
Manual.advance(clock, 10)
IO.inspect(Runner.status(runner).status, label: "status")
:ok = Runner.stop(runner)
