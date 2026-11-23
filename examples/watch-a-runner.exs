alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

defmodule Watcher do
  # A process that follows a runner. It prints the events, the status and the end of the runner.
  use GenServer

  # The kinds that subscribe/1 takes, and :ran.
  @kinds [:overlap, :fault, :trip, :restart, :edit, :retain, :forces, :ran]

  def start_link(runner), do: GenServer.start_link(__MODULE__, runner)

  @impl true
  def init(runner) do
    :ok = Runner.subscribe(runner, @kinds)
    ref = Process.monitor(runner)
    show(runner)
    {:ok, %{runner: runner, ref: ref}}
  end

  @impl true
  def handle_info({Runner, runner, {:ran, "fast", instance, now}}, %{runner: runner} = state) do
    IO.puts("t=#{now}  the task fast ran #{instance}")
    {:noreply, state}
  end

  def handle_info({Runner, runner, {:ran, _task, _instance, _now}}, %{runner: runner} = state),
    do: {:noreply, state}

  def handle_info({Runner, runner, event}, %{runner: runner} = state) do
    IO.puts("event  #{inspect(event)}")
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{ref: ref} = state) do
    IO.puts("the runner ended: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(:tick, state) do
    show(state.runner)
    {:noreply, state}
  end

  defp show(runner) do
    %{status: status, trip: trip, now: now, rounds: rounds} = Runner.status(runner)
    k1 = Runner.get!(runner, "k1")
    boxes = Runner.get!(runner, "b1.count")
    IO.puts("t=#{now}  status=#{status} trip=#{inspect(trip)} rounds=#{rounds} k1=#{k1} boxes=#{boxes}")
  end

  # Returns when the watcher has handled each message that came before this call.
  def sync(watcher), do: GenServer.call(watcher, :sync)

  @impl true
  def handle_call(:sync, _from, state), do: {:reply, :ok, state}
end

{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
{:ok, clock} = Manual.start_link()
{:ok, panel} = Sim.start_link(reports: true, clock: clock)

{:ok, runner} =
  Runner.start_link(configuration: plant, io: %{"panel" => {Sim, sim: panel}}, clock: {Manual, clock})

{:ok, watcher} = Watcher.start_link(runner)

# On a plant, :timer.send_interval/2 sends :tick. Here the script sends it and waits for the line.
tick = fn ->
  send(watcher, :tick)
  :ok = Watcher.sync(watcher)
end

Sim.set(panel, "panel.i.0", 1)              # start pressed
Manual.advance(clock, 10)
Sim.set(panel, "panel.i.0", 0)

for _box <- 1..3 do
  Sim.set(panel, "panel.i.8", 1)            # a box on the eye, then past it
  Manual.advance(clock, 2)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 2)
end

tick.()
Sim.fail(panel, :read, {:error, :eio})      # the next read of the panel fails
Manual.advance(clock, 10)
tick.()
:ok = Runner.restart(runner, :cold)
tick.()

ref = Process.monitor(watcher)
:ok = Runner.stop(runner)
receive do: ({:DOWN, ^ref, :process, ^watcher, :normal} -> :ok)
