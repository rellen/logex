alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("map-io-points/sorter.logex")
for warning <- plant.warnings, do: IO.puts(Logex.Diagnostic.format(warning))

# The I/O list: the points of each device.
for {device, points} <- Enum.sort(Logex.IO.points(plant)), point <- points do
  row = [device, point.name, point.type, point.direction]
  address = inspect(point.address, charlists: :as_lists)
  IO.puts(Enum.map_join(row, &String.pad_trailing("#{&1}", 14)) <> address)
end

# A simulated device for each device of the configuration.
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link()
{:ok, card} = Sim.start_link(inputs: 4, outputs: 4)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}, "card" => {Sim, sim: card}},
    clock: {Manual, clock}
  )

# The start button, and a box at the photo-eye of lane 2.
Sim.set(panel, "panel.i.0", 1)
Sim.set(card, "card.i.2", 1)

# 10 ms on the manual clock: the task fast runs.
Manual.advance(clock, 10)

# The last value of each output point, and the global lane_lamp.
IO.inspect(Sim.outputs(panel), label: "panel")
IO.inspect(Sim.outputs(card), label: "card ")
IO.inspect(Runner.get!(runner, "lane_lamp"), label: "lane_lamp")
:ok = Runner.stop(runner)
