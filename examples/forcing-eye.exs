alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
File.rm("packing.forces")

# Starts a runner with a manual clock, a simulated panel and a forces file.
start = fn ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      forces: "packing.forces"
    )

  {runner, clock, panel}
end

show = fn runner, label ->
  %{now: now, forces: forces} = Runner.status(runner)
  eye = Runner.get!(runner, "eye")
  boxes = Runner.get!(runner, "b1.count")
  IO.puts("t=#{now} #{label}: eye=#{eye} boxes=#{boxes} forces=#{inspect(forces)}")
end

{runner, clock, panel} = start.()
show.(runner, "start")

# The photo-eye forced to 1. The counter counts 1 box.
:ok = Runner.force(runner, "eye", 1)
Manual.advance(clock, 2)
show.(runner, "eye forced")

# The real eye goes to 1 and back to 0. The program reads the force.
Sim.set(panel, "panel.i.8", 1)
Sim.set(panel, "panel.i.8", 0)
Manual.advance(clock, 2)
show.(runner, "eye moved")
IO.inspect(File.read!("packing.forces"), label: "packing.forces")

# A crash. A fresh runner reads the forces file.
Logger.configure(level: :none)
Process.flag(:trap_exit, true)
Process.exit(runner, :kill)
receive do: ({:EXIT, ^runner, :killed} -> :ok)
{runner, clock, _panel} = start.()
show.(runner, "fresh start")

:ok = Runner.unforce(runner, "eye")
Manual.advance(clock, 1)
show.(runner, "eye unforced")
IO.inspect(Runner.unforce(runner, "eye"), label: "unforce again")
IO.inspect(File.read!("packing.forces"), label: "packing.forces")

# Wrong arguments: each raises an ArgumentError in the caller.
for {point, value} <- [{"k1", 1}, {"eye", 2}, {"eye", 1.0}, {"eyes", 1}, {:eye, 1}] do
  try do
    Runner.force(runner, point, value)
  rescue
    error in ArgumentError -> IO.puts(error.message)
  end
end

:ok = Runner.stop(runner)
File.rm("packing.forces")
