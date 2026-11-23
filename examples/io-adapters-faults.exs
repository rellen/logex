# The script tells the simulated device to fail 1 time in each way of fail/3, and prints
# the reason of each trip. After each trip, a cold restart opens the device again. Each
# failure acts on the next call of its callback: a read or a write at the next poll, a
# report at the next change of an input.
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

Logger.configure(level: :none)
{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

failures = [
  {:read, {:error, :closed}},
  {:read, :raise},
  {:read, :throw},
  {:read, :exit},
  {:read, {:value, [8], 2}},
  {:read, {:value, [9], 1}},
  {:write, {:error, :closed}},
  {:write, :raise}
]

for {callback, how} <- failures do
  :ok = Sim.fail(panel, callback, how)
  Manual.advance(clock, 10)
  %{trip: trip} = Runner.status(runner)
  IO.puts("#{callback} #{inspect(how, charlists: :as_lists)}")
  IO.puts("  trip: #{inspect(trip)}")
  :ok = Runner.restart(runner, :cold)
end

:ok = Sim.fail(panel, :report, {:error, :closed})
:ok = Sim.set(panel, "panel.i.2", 1)
IO.puts("report {:error, :closed}")
IO.puts("  trip: #{inspect(Runner.status(runner).trip)}")

:ok = Sim.fail(panel, :close, :raise)
IO.puts("close :raise")
IO.puts("  stop: #{inspect(Runner.stop(runner))}, closed: #{Sim.closed?(panel)}")

:ok = Sim.fail(panel, :init, {:error, :econnrefused})
start = Runner.start_link(configuration: plant, io: %{"panel" => {Sim, sim: panel}})
IO.puts("init {:error, :econnrefused}")
IO.puts("  start: #{inspect(start)}")
