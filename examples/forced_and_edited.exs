alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
File.rm("packing.forces")

start = fn ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      forces: "packing.forces"                # where the forces are kept, across a crash
    )

  {runner, clock, panel}
end

{runner, clock, panel} = start.()

show = fn runner, label ->
  %{now: now, forces: forces} = Runner.status(runner)
  IO.puts("t=#{String.pad_leading("#{now}", 2)}  #{label}  eye=#{Runner.get!(runner, "eye")} boxes=#{Runner.get!(runner, "b1.count")}  forces=#{inspect(forces)}")
end

:ok = Runner.force(runner, "eye", 1)           # the photo-eye forced blocked
Manual.advance(clock, 2)
show.(runner, "eye forced     ")
Sim.set(panel, "panel.i.8", 1)                 # the real eye: blocked, then clear
Sim.set(panel, "panel.i.8", 0)
Manual.advance(clock, 2)
show.(runner, "eye moved      ")
IO.inspect(File.read!("packing.forces"), label: "packing.forces")

:ok = Runner.stop(runner)                      # a fresh runner from the same file
{runner, clock, _panel} = start.()
show.(runner, "a fresh start  ")

:ok = Runner.unforce(runner, "eye")            # the device's last value, 0, read again
Manual.advance(clock, 1)
show.(runner, "eye unforced   ")

try do
  Runner.force(runner, "k1", 1)
rescue
  error in ArgumentError -> IO.puts("force k1: " <> error.message)
end

# An edit, stepped through the runner between rounds: the conveyor's task cut to 5 ms.
{:ok, faster} = Logex.Configuration.compile_file("faster/packing.logex")
:ok = Runner.subscribe(runner, [:edit])
{:ok, forecast} = Runner.accept(runner, faster)
IO.inspect(forecast, label: "forecast")
{:ok, report} = Runner.test(runner)
IO.inspect(report, label: "test")
IO.inspect(Runner.status(runner).edit, label: "stage")
:ok = Runner.subscribe(runner, [:ran])
Manual.advance(clock, 12)
IO.inspect(for({Runner, ^runner, {:ran, "fast", _, at}} <- Process.info(self(), :messages) |> elem(1), do: at), label: "the conveyor ran at")
{:ok, report} = Runner.assemble(runner)
IO.inspect(report, label: "assemble")
IO.inspect(Runner.status(runner).edit, label: "stage")
:ok = Runner.stop(runner)
File.rm("packing.forces")
