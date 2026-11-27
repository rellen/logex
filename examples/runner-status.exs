alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Sim, sim: panel}},
    clock: {Manual, clock}
  )

# Prints each key of status/1, in a fixed sequence.
keys =
  ~w(status trip now rounds runs overlaps latest_wake refresh_gap unzeroed edit forces)a ++
    ~w(forces_unread forces_unknown forcing retain)a

status = Runner.status(runner)
for key <- keys, do: IO.puts("#{key}: #{inspect(status[key])}")

# Prints each event in the mailbox, and removes it.
events = fn ->
  {:messages, messages} = Process.info(self(), :messages)
  for {Runner, ^runner, event} <- messages, do: IO.puts("  event #{inspect(event)}")
  for {Runner, ^runner, _event} <- messages, do: receive(do: ({Runner, ^runner, _} -> :ok))
end

:ok = Runner.subscribe(runner, [:ran, :round])
Sim.set(panel, "panel.i.0", 1)
IO.puts("start pressed, then advance 1 ms")
Manual.advance(clock, 1)
events.()
IO.puts("unsubscribe, advance 8 ms, subscribe, advance 1 ms")
:ok = Runner.unsubscribe(runner)
Manual.advance(clock, 8)
:ok = Runner.subscribe(runner, [:ran, :round])
Manual.advance(clock, 1)
events.()

IO.puts("get: #{inspect(Runner.get(runner, "k1"))} #{inspect(Runner.get(runner, "k9"))}")
IO.puts("stop: #{inspect(Runner.stop(runner))}")
IO.puts("last 2 writes: #{inspect(Enum.take(Sim.writes(panel), -2))}")
IO.puts("closed: #{Sim.closed?(panel)}")
