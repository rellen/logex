alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")

# Starts a runner on a manual clock, presses start, and runs to 10 ms: k1 is 1.
start = fn ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock}
    )

  :ok = Runner.subscribe(runner)
  Sim.set(panel, "panel.i.0", 1)
  Manual.advance(clock, 10)
  Sim.set(panel, "panel.i.0", 0)
  {runner, clock, panel}
end

# Part 1: 1 failure of the panel at its poll at 20 ms, and the reason of the trip.
for {callback, how} <- [
      read: {:error, :eio},
      read: :raise,
      read: :throw,
      read: {:value, [0], 2},
      read: {:value, [40], 1},
      write: {:error, :eio}
    ] do
  {runner, clock, panel} = start.()
  Sim.fail(panel, callback, how)
  Manual.advance(clock, 15)
  how = inspect(how, charlists: :as_lists)
  IO.puts("#{callback} #{how}\n  #{inspect(Runner.status(runner).trip)}")
  :ok = Runner.stop(runner)
end

# Part 2: the read at 20 ms fails, and the write of 0 of the trip also fails.
{runner, clock, panel} = start.()
Sim.fail(panel, :read, {:error, :eio})
Sim.fail(panel, :write, {:error, :eio})
Manual.advance(clock, 15)

show = fn label ->
  status = Runner.status(runner)
  IO.puts("#{label}")

  for key <- [:status, :trip, :now, :rounds, :unzeroed] do
    IO.puts("  #{key}: #{inspect(status[key])}")
  end

  IO.puts("  k1 in the resource: #{Runner.get!(runner, "k1")}")
  IO.puts("  last write: #{inspect(List.last(Sim.writes(panel)))}")
end

show.("the trip")
writes = length(Sim.writes(panel))
Manual.advance(clock, 50)
show.("50 ms later")
IO.puts("  writes in the 50 ms: #{length(Sim.writes(panel)) - writes}")

Sim.fail(panel, :read, {:error, :eio})
IO.puts("restart: #{inspect(Runner.restart(runner, :warm))}")
IO.puts("restart: #{inspect(Runner.restart(runner, :warm))}")
show.("after the restart")

try do
  Runner.restart(runner, :cold)
rescue
  error in ArgumentError -> IO.puts("restart: #{Exception.message(error)}")
end

{:messages, messages} = Process.info(self(), :messages)
for {Runner, ^runner, event} <- messages, do: IO.puts("event #{inspect(event)}")
:ok = Runner.stop(runner)
