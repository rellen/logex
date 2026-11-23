alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
forces_file = Path.expand("packing.forces")      # a full path
File.rm(forces_file)

start = fn ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      forces: forces_file                         # the runner keeps its forces here
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

:ok = Runner.force(runner, "eye", 1)              # the photo-eye forced to 1
Manual.advance(clock, 2)
show.(runner, "eye forced")

Sim.set(panel, "panel.i.8", 1)                    # the real eye: 1 for 1 round
Manual.advance(clock, 1)
Sim.set(panel, "panel.i.8", 0)                    # then 0
Manual.advance(clock, 2)
show.(runner, "eye moved")
IO.inspect(File.read!(forces_file), label: "packing.forces")

:ok = Runner.stop(runner)                         # a fresh runner on the same file
{runner, clock, _panel} = start.()
show.(runner, "fresh start")

:ok = Runner.unforce(runner, "eye")               # the last value of the device, 0
Manual.advance(clock, 1)
show.(runner, "eye unforced")

:ok = Runner.force(runner, "eye", 1)
:ok = Runner.force(runner, "pb_reset", 0)         # the reset button held at 0
Manual.advance(clock, 1)
show.(runner, "2 forces")
:ok = Runner.unforce_all(runner)                  # each force removed
Manual.advance(clock, 1)
show.(runner, "unforce_all")
IO.inspect(File.read!(forces_file), label: "packing.forces")

:ok = Runner.stop(runner)
File.rm(forces_file)
