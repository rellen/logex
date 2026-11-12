alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("oven.logex")

for point <- Logex.IO.points(plant)["card"],
    do:
      IO.puts(
        "#{point.name} #{point.type} #{point.direction} at #{inspect(point.address, charlists: :as_lists)}"
      )

{:ok, clock} = Manual.start_link()
{:ok, card} = Sim.start_link(reports: true, inputs: 8, outputs: 8)
File.rm("oven.forces")

start = fn ->
  Runner.start_link(
    configuration: plant,
    io: %{"card" => {Sim, sim: card}},
    clock: {Manual, clock},
    forces: "oven.forces"
  )
end

{:ok, runner} = start.()

lamps = fn -> Enum.map(0..7, &Sim.outputs(card)["card.q.#{&1}"]) end

Sim.set(card, %{"card.i.0" => 175.5, "card.i.1" => 182, "card.i.2" => 179.9, "card.i.3" => 201.25, "card.i.5" => 190})
Manual.advance(clock, 10)
IO.inspect(Runner.get!(runner, "zone_t"), label: "zone_t  ")
IO.inspect(lamps.(), label: "lamps   ")

:ok = Runner.force(runner, "zone_t[3]", 150)
Sim.set(card, "card.i.3", 205.0)
Manual.advance(clock, 10)
IO.inspect(Runner.get!(runner, "zone_t[3]"), label: "forced  ")
IO.inspect(lamps.(), label: "lamps   ")
IO.write("oven.forces: " <> File.read!("oven.forces"))

for {name, value} <- [{"zone_t", 1.0}, {"zone_hot[3]", 1}, {"zone_t[8]", 1.0}] do
  try do
    Runner.force(runner, name, value)
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end

# Killed: a fresh runner reads its forces file.
Logger.configure(level: :none)
Process.flag(:trap_exit, true)
Process.exit(runner, :kill)

receive do
  {:EXIT, ^runner, :killed} -> :ok
end

{:ok, runner} = start.()
IO.inspect(Runner.status(runner).forces, label: "forces  ")
:ok = Runner.unforce(runner, "zone_t[3]")
Manual.advance(clock, 10)
IO.inspect(Runner.get!(runner, "zone_t[3]"), label: "unforced")

:ok = Runner.force(runner, "zone_t", [170, 170, 170, 170, 190, 190, 190, 190])
Manual.advance(clock, 10)
IO.inspect(lamps.(), label: "whole   ")
IO.write("oven.forces:\n" <> File.read!("oven.forces"))
:ok = Runner.unforce(runner, "zone_t")
Manual.advance(clock, 10)
IO.inspect(lamps.(), label: "unforced")
:ok = Runner.stop(runner)

{:ok, short} = Sim.start_link(inputs: 6)

try do
  Runner.start_link(
    configuration: plant,
    io: %{"card" => {Sim, sim: short}},
    clock: {Manual, clock}
  )
rescue
  error in ArgumentError -> IO.puts(Exception.message(error))
end

{:error, diagnostics} =
  Logex.Configuration.compile(
    "oven",
    File.read!("oven.logex") <>
      "var_global door bool at card.i.5\nvar_global extra real[4] at card.i.6\n",
    plant.programs
  )

for diagnostic <- diagnostics, do: IO.puts(Logex.Diagnostic.format(diagnostic))
