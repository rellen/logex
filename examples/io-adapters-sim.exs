# The script runs packing.logex on a simulated device, panel, on a manual clock. It sets
# inputs before and after the runner opens the sim, and reads what the sim recorded.
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

# No runner opened the sim: an address is a list. [0] is pb_start_1.
:ok = Sim.set(panel, [0], 1)
IO.inspect(Sim.outputs(panel), label: "outputs before the open")

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

IO.inspect(Sim.reads(panel), label: "reads after the open")
IO.inspect(Sim.outputs(panel), label: "outputs after the first round")

# The runner opened the sim: an address is the text of the configuration.
:ok = Sim.set(panel, %{"panel.i.0" => 0, "panel.i.8" => 1})
Manual.advance(clock, 10)
IO.inspect(Sim.reads(panel), label: "reads at 10 ms")
IO.inspect(Runner.get!(runner, "eye"), label: "eye")

:ok = Runner.stop(runner)
IO.inspect(Sim.writes(panel), label: "writes")
IO.inspect(Sim.closed?(panel), label: "closed")

# After the stop, the sim keeps the name of the device.
IO.inspect(Sim.set(panel, "panel.i.0", 1), label: "set after the stop")
