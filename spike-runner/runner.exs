# Throwaway runner spike (never landed): a wall-clock runner over Logex.Runtime, with an
# injectable clock, a Logex.IO-style adapter behaviour, one process per device, a two-layer
# watchdog (the runner's gap check and each output device's heartbeat), subscriptions,
# get, forcing, an online edit stepped through the runner, and explicit restart.

defmodule Spike.Clock do
  @moduledoc "What the runner and the devices read time from, so a test can fake it."
  @callback now_ms(ref :: term) :: integer
  @callback wake_at(ref :: term, pid, msg :: term, at_ms :: integer) :: reference
  @callback cancel(ref :: term, reference) :: :ok
end

defmodule Spike.Clock.Real do
  @behaviour Spike.Clock
  @impl true
  def now_ms(_ref), do: System.monotonic_time(:millisecond)
  @impl true
  def wake_at(_ref, pid, msg, at_ms), do: Process.send_after(pid, msg, at_ms, abs: true)
  @impl true
  def cancel(_ref, timer) do
    Process.cancel_timer(timer)
    :ok
  end
end

defmodule Spike.Clock.Fake do
  @moduledoc """
  A clock a test moves. `advance/2` delivers each timer due on the way, in time order, and
  waits until its process and every other process that set a timer has handled what it
  was sent, so a run is deterministic. `sleep/2` is time passing inside a call, as a slow
  device's: its due timers wait for the next `advance/2`.
  """
  use GenServer
  @behaviour Spike.Clock

  def start_link(start_ms \\ 1_000_000), do: GenServer.start_link(__MODULE__, start_ms)

  @impl Spike.Clock
  def now_ms(fake), do: GenServer.call(fake, :now)
  @impl Spike.Clock
  def wake_at(fake, pid, msg, at_ms), do: GenServer.call(fake, {:wake_at, pid, msg, at_ms})
  @impl Spike.Clock
  def cancel(fake, ref), do: GenServer.call(fake, {:cancel, ref})

  def sleep(fake, ms), do: GenServer.call(fake, {:bump, ms})

  def advance(fake, ms) do
    target = now_ms(fake) + ms
    deliver(fake, target)
  end

  defp deliver(fake, target) do
    case GenServer.call(fake, {:pop_due, target}) do
      {:ok, pid, msg, known} ->
        send(pid, msg)
        Enum.each([pid | known], &sync/1)
        deliver(fake, target)

      :none ->
        GenServer.call(fake, {:set, target})
    end
  end

  defp sync(pid) do
    if Process.alive?(pid), do: :sys.get_state(pid, 5_000)
  catch
    :exit, _ -> :ok
  end

  @impl GenServer
  def init(start_ms), do: {:ok, %{now: start_ms, timers: [], seq: 0, known: []}}

  @impl GenServer
  def handle_call(:now, _from, s), do: {:reply, s.now, s}

  def handle_call({:wake_at, pid, msg, at}, _from, s) do
    ref = make_ref()
    known = if pid in s.known, do: s.known, else: s.known ++ [pid]
    {:reply, ref, %{s | timers: [{at, s.seq, ref, pid, msg} | s.timers], seq: s.seq + 1, known: known}}
  end

  def handle_call({:cancel, ref}, _from, s),
    do: {:reply, :ok, %{s | timers: Enum.reject(s.timers, &(elem(&1, 2) == ref))}}

  def handle_call({:bump, ms}, _from, s), do: {:reply, :ok, %{s | now: s.now + ms}}

  def handle_call({:pop_due, target}, _from, s) do
    case s.timers |> Enum.filter(&(elem(&1, 0) <= target)) |> Enum.min_by(&{elem(&1, 0), elem(&1, 1)}, fn -> nil end) do
      nil ->
        {:reply, :none, s}

      {at, _seq, ref, pid, msg} = timer ->
        s = %{s | now: max(s.now, at), timers: List.delete(s.timers, timer)}
        _ = ref
        {:reply, {:ok, pid, msg, List.delete(s.known, pid)}, s}
    end
  end

  def handle_call({:set, target}, _from, s), do: {:reply, :ok, %{s | now: max(s.now, target)}}
end

defmodule Spike.IO do
  @moduledoc """
  The adapter behaviour (docs/organisation.md §4.5, revised). A point is
  `%{name: "pb_start_1", direction: :input | :output, address: [0], type: :bool | :dint}`.
  `read/1` gives values by address for some or all of the device's input points; `write/2`
  is given every output point of the device, by address, each cycle.
  """
  @callback init(device :: String.t(), points :: [map], opts :: keyword) ::
              {:ok, term} | {:error, term}
  @callback read(state :: term) :: {:ok, %{[non_neg_integer] => integer}, term} | {:error, term, term}
  @callback write(%{[non_neg_integer] => integer}, state :: term) :: {:ok, term} | {:error, term, term}
  @callback close(state :: term) :: :ok
  @optional_callbacks close: 1
end

defmodule Spike.IO.Sim do
  @moduledoc """
  An in-memory device for tests and demos: an Agent holds its input values, the last value
  written to each output, every write in order, and a failure to act out on the next read.
  """
  @behaviour Spike.IO

  def new, do: elem(Agent.start(fn -> %{inputs: %{}, outputs: %{}, writes: [], fail: nil, closed: false} end), 1)
  def set(sim, address, value), do: Agent.update(sim, &put_in(&1, [:inputs, address], value))
  def outputs(sim), do: Agent.get(sim, & &1.outputs)
  def writes(sim), do: Agent.get(sim, &Enum.reverse(&1.writes))
  def closed?(sim), do: Agent.get(sim, & &1.closed)
  # :raise, {:error, reason}, {:delay, ms} on the fake clock, :hang, {:bad, address, value}
  def fail(sim, how), do: Agent.update(sim, &%{&1 | fail: how})

  @impl true
  def init(device, points, opts) do
    {:ok, %{device: device, sim: Keyword.fetch!(opts, :sim), clock: Keyword.get(opts, :clock),
            inputs: for(%{direction: :input, address: a} <- points, do: a)}}
  end

  @impl true
  def read(state) do
    case Agent.get_and_update(state.sim, &{&1.fail, %{&1 | fail: nil}}) do
      nil -> {:ok, Agent.get(state.sim, &Map.take(&1.inputs, state.inputs)), state}
      :raise -> raise "sim #{state.device}: read raised"
      {:error, reason} -> {:error, reason, state}
      :hang -> receive do: (:never -> :ok)
      {:bad, address, value} -> {:ok, %{address => value}, state}
      {:delay, ms} ->
        Spike.Clock.Fake.sleep(state.clock, ms)
        {:ok, Agent.get(state.sim, &Map.take(&1.inputs, state.inputs)), state}
    end
  end

  @impl true
  def write(outputs, state) do
    Agent.update(state.sim, &%{&1 | outputs: Map.merge(&1.outputs, outputs), writes: [outputs | &1.writes]})
    {:ok, state}
  end

  @impl true
  def close(state) do
    Agent.update(state.sim, &%{&1 | closed: true})
    :ok
  end
end

defmodule Spike.Device do
  @moduledoc """
  One device's process: holds its adapter's state, reads and writes it for the runner,
  zeroes its outputs once and latches on a trip, on its own heartbeat (no write for the
  watchdog's time), and when the runner dies, however it dies.
  """
  use GenServer

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init(%{adapter: adapter, device: device, points: points, opts: opts} = a) do
    Process.flag(:trap_exit, true)

    case guarded(fn -> adapter.init(device, points, opts) end) do
      {:ok, {:ok, st}} ->
        zeros = Map.new(for %{direction: :output, address: ad} <- points, do: {ad, 0})
        {:ok, Map.merge(a, %{st: st, zeros: zeros, latched: false, beat: nil, beats: 0})}

      {:ok, {:error, reason}} -> {:stop, {:init, reason}}
      {:error, what} -> {:stop, {:init, what}}
    end
  end

  # A raise, throw or exit inside an adapter callback is the device's fault, never the runner's.
  defp guarded(fun) do
    {:ok, fun.()}
  rescue
    e -> {:error, {:raised, Exception.message(e)}}
  catch
    kind, value -> {:error, {kind, value}}
  end

  @impl true
  def handle_call(:read, _from, s) do
    case guarded(fn -> s.adapter.read(s.st) end) do
      {:ok, {:ok, values, st}} -> {:reply, {:ok, values}, %{s | st: st}}
      {:ok, {:error, reason, st}} -> {:reply, {:error, reason}, %{s | st: st}}
      {:error, what} -> {:reply, {:error, what}, s}
    end
  end

  def handle_call({:write, _outputs}, _from, %{latched: latched} = s) when latched != false,
    do: {:reply, {:error, {:latched, latched}}, s}

  def handle_call({:write, outputs}, _from, s) do
    case guarded(fn -> s.adapter.write(outputs, s.st) end) do
      {:ok, {:ok, st}} -> {:reply, :ok, beat(%{s | st: st})}
      {:ok, {:error, reason, st}} -> {:reply, {:error, reason}, %{s | st: st}}
      {:error, what} -> {:reply, {:error, what}, s}
    end
  end

  def handle_call(:trip, _from, s), do: {:reply, :ok, zeroed(s, :trip)}
  def handle_call(:reset, _from, s), do: {:reply, :ok, %{unbeat(s) | latched: false}}
  def handle_call(:close, _from, s), do: {:stop, :normal, :ok, zeroed(s, :closed)}

  # The heartbeat: armed by each write, on a device with outputs, while the watchdog is on.
  defp beat(%{watchdog: :off} = s), do: s
  defp beat(%{zeros: z} = s) when map_size(z) == 0, do: s

  defp beat(s) do
    s = unbeat(s)
    {mod, ref} = s.clock
    n = s.beats + 1
    timer = mod.wake_at(ref, self(), {:beat, n}, mod.now_ms(ref) + s.watchdog)
    %{s | beat: {n, timer}, beats: n}
  end

  defp unbeat(%{beat: nil} = s), do: s

  defp unbeat(%{beat: {_n, timer}, clock: {mod, ref}} = s) do
    mod.cancel(ref, timer)
    %{s | beat: nil}
  end

  # Zero once: a latched device writes nothing more until a reset. `latched` says why.
  defp zeroed(%{latched: latched} = s, _why) when latched != false, do: s

  defp zeroed(s, why) do
    s = unbeat(s)
    st = case guarded(fn -> s.adapter.write(s.zeros, s.st) end) do
      {:ok, {:ok, st}} -> st
      _ -> s.st
    end
    %{s | st: st, latched: why}
  end

  @impl true
  def handle_info({:beat, n}, %{beat: {n, _}} = s) do
    send(s.runner, {:device_watchdog, s.device, s.watchdog})
    {:noreply, zeroed(%{s | beat: nil}, {:watchdog, s.watchdog})}
  end

  def handle_info({:beat, _stale}, s), do: {:noreply, s}

  def handle_info({:EXIT, runner, reason}, %{runner: runner} = s) do
    {:stop, {:runner_down, reason}, zeroed(s, :runner_down)}
  end

  def handle_info(_other, s), do: {:noreply, s}

  @impl true
  def terminate(_reason, s) do
    s = zeroed(s, :closed)
    if function_exported?(s.adapter, :close, 1), do: guarded(fn -> s.adapter.close(s.st) end)
    :ok
  end
end

defmodule Spike.Runner do
  @moduledoc """
  The wall-clock runner: one GenServer per resource, under the host's supervisor. It sleeps
  to the earlier of the next periodic due time and the next period tick, reads every device,
  cycles the resource with the time that really passed, writes every device, and checks the
  watchdog. A host mistake raises ArgumentError in the caller and never crashes the runner.
  """
  use GenServer
  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.Edit

  # ---- client ----

  def child_spec(opts),
    do: %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}, restart: :temporary}

  def start_link(opts) do
    args = options!(opts)
    GenServer.start_link(__MODULE__, args, Keyword.take(opts, [:name]))
  end

  # Unlinked, for a scenario that kills the runner.
  def start(opts), do: GenServer.start(__MODULE__, options!(opts), Keyword.take(opts, [:name]))

  def stop(runner), do: GenServer.stop(runner, :normal)
  def get(runner, path), do: call(runner, {:get, path})
  def get!(runner, path), do: unwrap(call(runner, {:get, path}))
  def status(runner), do: call(runner, :status)
  def subscribe(runner, kinds \\ [:overlap, :fault, :trip, :restart, :edit]), do: call(runner, {:subscribe, self(), kinds})
  def force(runner, point, value), do: call(runner, {:force, point, value})
  def unforce(runner, point), do: call(runner, {:unforce, point})
  def restart(runner, mode), do: call(runner, {:restart, mode})
  def accept(runner, candidate), do: call(runner, {:edit, :accept, candidate})
  def test(runner), do: call(runner, {:edit, :test, nil})
  def untest(runner), do: call(runner, {:edit, :untest, nil})
  def assemble(runner), do: call(runner, {:edit, :assemble, nil})
  def cancel(runner), do: call(runner, {:edit, :cancel, nil})

  defp call(runner, msg) do
    case GenServer.call(runner, msg) do
      {:raise, exception} -> raise exception
      reply -> reply
    end
  end

  defp unwrap({:ok, v}), do: v
  defp unwrap({:error, reason}), do: raise(ArgumentError, reason)

  # Host mistakes, raised in the host's own process before anything starts.
  defp options!(opts) do
    config = Keyword.fetch!(opts, :configuration)
    rt = Runtime.start(config)
    period = Keyword.get(opts, :period, 10)
    watchdog = Keyword.get(opts, :watchdog, 100)
    io = Keyword.fetch!(opts, :io)
    unless is_integer(period) and period >= 1, do: raise(ArgumentError, "period must be a positive integer of milliseconds, got: #{inspect(period)}")
    unless watchdog == :off or (is_integer(watchdog) and watchdog > period),
      do: raise(ArgumentError, "watchdog must be :off or more milliseconds than the period (#{period}), got: #{inspect(watchdog)}")

    points = points(config)
    unbound = Map.keys(points) -- Map.keys(io)
    unused = Map.keys(io) -- Map.keys(points)
    if unbound != [], do: raise(ArgumentError, "no adapter is bound to device(s) #{inspect(unbound)}, which the configuration's points name")
    if unused != [], do: raise(ArgumentError, "device(s) #{inspect(unused)} are bound but no point is at them")

    %{config: config, rt: rt, period: period, watchdog: watchdog, points: points,
      io: Map.new(io, fn {d, {m, o}} -> {d, {m, o}}; {d, m} -> {d, {m, []}} end),
      clock: Keyword.get(opts, :clock, {Spike.Clock.Real, nil}),
      call_timeout: Keyword.get(opts, :call_timeout, if(watchdog == :off, do: 5_000, else: watchdog))}
  end

  # Every located point, by device.
  defp points(%Configuration{globals: globals}) do
    for %{name: name, type: type, at: at} <- globals, at != nil, {:ok, {dev, io, address}} = Configuration.location(at), reduce: %{} do
      acc -> Map.update(acc, dev, [point(name, type, io, address)], &(&1 ++ [point(name, type, io, address)]))
    end
  end

  defp point(name, type, "i", address), do: %{name: name, type: type, direction: :input, address: address}
  defp point(name, type, "q", address), do: %{name: name, type: type, direction: :output, address: address}

  # ---- server ----

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)
    {mod, ref} = args.clock
    now = mod.now_ms(ref)

    case open_devices(args) do
      {:ok, devices} ->
        s = Map.merge(args, %{devices: devices, status: :running, logical: 0, anchor: now, tick0: 0,
              last_done: now, wake: nil, token: 0, subscribers: %{}, forces: %{}, edit: nil,
              cycles: 0, max_late: 0, max_cycle: 0, trip: nil, due_wall: now, gaps: %{}, costs: []})
        send(self(), {:wake, 0})
        {:ok, %{s | token: 0}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp open_devices(args) do
    Enum.reduce_while(Enum.sort(args.points), {:ok, %{}}, fn {dev, points}, {:ok, acc} ->
      case open_device(args, dev, points) do
        {:ok, pid} -> {:cont, {:ok, Map.put(acc, dev, pid)}}
        {:error, reason} ->
          Enum.each(acc, fn {_, pid} -> Process.unlink(pid); GenServer.stop(pid) end)
          {:halt, {:error, {:io_init, dev, reason}}}
      end
    end)
  end

  defp open_device(args, dev, points) do
    {adapter, opts} = Map.fetch!(args.io, dev)
    Spike.Device.start_link(%{adapter: adapter, device: dev, points: points, opts: opts, runner: self(),
                              clock: args.clock, watchdog: args.watchdog})
  catch
    :exit, reason -> {:error, reason}
  end

  @impl true
  def handle_info({:wake, token}, %{token: token, status: :running} = s), do: {:noreply, cycle(s)}
  def handle_info({:wake, _stale}, s), do: {:noreply, s}

  def handle_info({:device_watchdog, dev, ms}, %{status: :running} = s),
    do: {:noreply, trip(s, {:watchdog, {:device, dev, ms}})}

  def handle_info({:EXIT, pid, reason}, s) do
    case Enum.find(s.devices, fn {_, p} -> p == pid end) do
      {dev, _} ->
        s = %{s | devices: Map.put(s.devices, dev, nil)}
        {:noreply, if(s.status == :running, do: trip(s, {:io, dev, {:down, reason}}), else: s)}

      nil ->
        {:noreply, s}
    end
  end

  def handle_info({:DOWN, mref, :process, pid, _}, s) do
    {:noreply, %{s | subscribers: Map.reject(s.subscribers, fn {p, {r, _}} -> p == pid and r == mref end)}}
  end

  def handle_info(_other, s), do: {:noreply, s}

  # A stop zeroes every output once and closes every device before it returns, as OpenPLC's
  # shutdown disables its outputs.
  @impl true
  def terminate(_reason, s) do
    Enum.each(s.devices, fn {_dev, pid} -> pid && safe_call(pid, :close, s.call_timeout) end)
  end

  # One cycle: read every device, cycle the resource by the time that passed, write every
  # device, check the watchdog, and sleep to the next due time or period tick.
  defp cycle(s) do
    {mod, ref} = s.clock
    wake = mod.now_ms(ref)
    wake_us = System.monotonic_time(:microsecond)
    target = wake - s.anchor
    elapsed = max(0, target - s.logical)

    with {:ok, inputs} <- read_all(s),
         {:ok, rt, outputs, events} <- cycled(s.rt, elapsed, Map.merge(inputs, s.forces)) do
      s = %{s | rt: rt, logical: s.logical + elapsed, cycles: s.cycles + 1}
      publish(s, events)
      # The watchdog is checked before the write: outputs that would reach the devices more
      # than its time after the last cycle's did are never written; the cycle trips instead.
      gap = mod.now_ms(ref) - s.last_done

      with :ok <- in_time(s, gap), :ok <- write_all(s, outputs) do
        done = mod.now_ms(ref)
        cost = System.monotonic_time(:microsecond) - wake_us
        s = %{s | last_done: done, max_late: max(s.max_late, wake - s.due_wall),
                  max_cycle: max(s.max_cycle, done - wake),
                  gaps: Map.update(s.gaps, bucket(gap), 1, &(&1 + 1)),
                  costs: Enum.take([cost | s.costs], 20_000)}
        schedule(s)
      else
        {:error, reason} -> trip(s, reason)
      end
    else
      {:error, reason} -> trip(s, reason)
    end
  end

  defp bucket(gap) when gap <= 10, do: "0-10"
  defp bucket(gap) when gap <= 20, do: "11-20"
  defp bucket(gap) when gap <= 50, do: "21-50"
  defp bucket(gap) when gap <= 100, do: "51-100"
  defp bucket(gap) when gap <= 250, do: "101-250"
  defp bucket(gap) when gap <= 500, do: "251-500"
  defp bucket(_gap), do: ">500"

  defp in_time(%{watchdog: :off}, _gap), do: :ok
  defp in_time(%{watchdog: ms}, gap) when gap <= ms, do: :ok
  defp in_time(%{watchdog: ms}, gap), do: {:error, {:watchdog, {:cycle, gap, ms}}}

  defp cycled(rt, elapsed, inputs) do
    {rt, outputs, events} = Runtime.cycle(rt, elapsed, inputs)
    {:ok, rt, outputs, events}
  rescue
    e in ArgumentError -> {:error, {:io, :bad_input, Exception.message(e)}}
  end

  defp read_all(s) do
    Enum.reduce_while(Enum.sort(s.points), {:ok, %{}}, fn {dev, points}, {:ok, acc} ->
      by_address = Map.new(for %{direction: :input, address: a} = point <- points, do: {a, point})

      case device_call(s, dev, :read) do
        {:ok, values} when is_map(values) ->
          # Each value checked against its point here, so a bad one names its device.
          case Enum.find(Enum.sort(values), &(not fits?(Map.get(by_address, elem(&1, 0)), elem(&1, 1)))) do
            nil -> {:cont, {:ok, Enum.into(values, acc, fn {a, v} -> {Map.fetch!(by_address, a).name, v} end)}}
            {a, v} -> {:halt, {:error, {:io, dev, {:bad_value, a, v}}}}
          end

        {:ok, other} -> {:halt, {:error, {:io, dev, {:bad_read, other}}}}

        {:error, reason} -> {:halt, {:error, {:io, dev, reason}}}
      end
    end)
  end

  defp fits?(nil, _value), do: false
  defp fits?(%{type: :bool}, v), do: v in [0, 1]
  defp fits?(%{type: :dint}, v), do: is_integer(v) and v >= -2_147_483_648 and v <= 2_147_483_647

  defp write_all(s, outputs) do
    Enum.reduce_while(Enum.sort(s.points), :ok, fn {dev, points}, :ok ->
      out = Map.new(for %{direction: :output, address: a, name: n} <- points, do: {a, Map.fetch!(outputs, n)})

      case device_call(s, dev, {:write, out}) do
        :ok -> {:cont, :ok}
        {:error, {:latched, {:watchdog, ms}}} -> {:halt, {:error, {:watchdog, {:device, dev, ms}}}}
        {:error, reason} -> {:halt, {:error, {:io, dev, reason}}}
      end
    end)
  end

  defp device_call(s, dev, msg) do
    case Map.fetch!(s.devices, dev) do
      nil -> {:error, :down}
      pid -> GenServer.call(pid, msg, s.call_timeout)
    end
  catch
    :exit, {:timeout, _} -> {:error, {:timeout, s.call_timeout}}
    :exit, reason -> {:error, {:exit, reason}}
  end

  # Sleep to the earlier of the next periodic due time and the next period tick.
  defp schedule(s) do
    {mod, ref} = s.clock
    tick = s.tick0 + (div(s.logical - s.tick0, s.period) + 1) * s.period

    next =
      case Runtime.next_due_in(s.rt) do
        :infinity -> tick
        n -> min(s.logical + n, tick)
      end

    token = s.token + 1
    due_wall = s.anchor + next
    %{s | token: token, due_wall: due_wall, wake: mod.wake_at(ref, self(), {:wake, token}, due_wall)}
  end

  # Decision 14: stop scheduling, zero every output once, report, wait for a restart.
  defp trip(s, reason) do
    {mod, ref} = s.clock
    if s.wake, do: mod.cancel(ref, s.wake)
    s = hung(s, reason)
    Enum.each(s.devices, fn {_dev, pid} -> pid && safe_call(pid, :trip, s.call_timeout) end)
    s = %{s | status: :tripped, trip: reason, wake: nil, token: s.token + 1}
    publish(s, [{:trip, reason}])
    s
  end

  # A device that did not answer in time is stuck in its adapter: it is killed, its outputs
  # left to the device itself, and opened again at a restart.
  defp hung(s, {:io, dev, {:timeout, _}}) do
    pid = Map.fetch!(s.devices, dev)
    Process.unlink(pid)
    Process.exit(pid, :kill)
    %{s | devices: Map.put(s.devices, dev, nil)}
  end

  defp hung(s, _reason), do: s

  defp safe_call(pid, msg, timeout) do
    GenServer.call(pid, msg, timeout)
  catch
    :exit, _ -> :error
  end

  defp publish(s, events) do
    for {pid, {_ref, kinds}} <- s.subscribers, event <- events, elem(event, 0) in kinds,
        do: send(pid, {__MODULE__, self(), event})
  end

  @impl true
  def handle_call({:get, path}, _from, s), do: {:reply, guarded(fn -> Runtime.get(s.rt, path) end), s}

  def handle_call(:status, _from, s) do
    {:reply, %{status: s.status, now: s.logical, cycles: s.cycles, trip: s.trip, max_late_ms: s.max_late,
               max_cycle_ms: s.max_cycle, overlaps: Runtime.overlaps(s.rt), forces: s.forces,
               edit: s.edit && Edit.stage(s.edit), gaps: s.gaps, costs: s.costs}, s}
  end

  def handle_call({:subscribe, pid, kinds}, _from, s),
    do: {:reply, :ok, %{s | subscribers: Map.put(s.subscribers, pid, {Process.monitor(pid), kinds})}}

  def handle_call({:force, point, value}, _from, s) do
    case Enum.find(Enum.flat_map(s.points, &elem(&1, 1)), &(&1.name == point and &1.direction == :input)) do
      nil -> {:reply, {:raise, ArgumentError.exception("`#{point}` is not an input point: only an input point is forced")}, s}
      %{type: :bool} when value not in [0, 1] -> {:reply, {:raise, ArgumentError.exception("`#{point}` is a bool, forced to 0 or 1, got: #{inspect(value)}")}, s}
      _ -> {:reply, :ok, %{s | forces: Map.put(s.forces, point, value)}}
    end
  end

  def handle_call({:unforce, point}, _from, s), do: {:reply, :ok, %{s | forces: Map.delete(s.forces, point)}}

  def handle_call({:restart, mode}, _from, s) do
    case guarded(fn -> Runtime.restart(s.rt, mode) end) do
      {:raise, _} = raised -> {:reply, raised, s}
      rt ->
        case reopen(s) do
          {:ok, s} ->
            {mod, ref} = s.clock
            Enum.each(s.devices, fn {_, pid} -> safe_call(pid, :reset, s.call_timeout) end)
            now = mod.now_ms(ref)
            # The clock does not count the time the runner was stopped: logical time goes on
            # from where it stopped, and the first cycle after a restart runs at once with
            # elapsed 0 (decision 50).
            s = %{s | rt: rt, status: :running, trip: nil, anchor: now - s.logical, tick0: s.logical,
                      last_done: now, token: s.token + 1, due_wall: now}
            if s.wake, do: mod.cancel(ref, s.wake)
            publish(s, [{:restart, mode}])
            # The first cycle runs inside the call, so the caller sees it done.
            {:reply, :ok, cycle(%{s | wake: nil})}

          {:error, reason, s} ->
            {:reply, {:error, reason}, s}
        end
    end
  end

  def handle_call({:edit, step, candidate}, _from, s) do
    case guarded(fn -> edit_step(step, s.edit, s.rt, candidate) end) do
      {:raise, _} = raised -> {:reply, raised, s}
      {:error, diagnostics} -> {:reply, {:error, diagnostics}, s}
      {:ok, edit, rt, config, report} ->
        s = %{s | edit: edit, rt: rt, config: config || s.config}
        publish(s, [{:edit, step, report}])
        {:reply, {:ok, report}, s}
    end
  end

  defp edit_step(:accept, _edit, rt, candidate) do
    case Edit.accept(rt, candidate) do
      {:ok, edit, forecast} -> {:ok, edit, rt, nil, forecast}
      {:error, diagnostics} -> {:error, diagnostics}
    end
  end

  defp edit_step(_step, nil, _rt, _), do: raise(ArgumentError, "no edit is accepted on this runner")

  defp edit_step(step, edit, rt, _) when step in [:test, :untest] do
    {edit, rt, report} = apply(Edit, step, [edit, rt])
    {:ok, edit, rt, nil, report}
  end

  defp edit_step(step, edit, rt, _) when step in [:assemble, :cancel] do
    {config, rt, report} = apply(Edit, step, [edit, rt])
    {:ok, nil, rt, config, report}
  end

  # A device that went down is opened again at a restart.
  defp reopen(s) do
    Enum.reduce_while(s.devices, {:ok, s}, fn
      {dev, nil}, {:ok, s} ->
        case open_device(s, dev, Map.fetch!(s.points, dev)) do
          {:ok, pid} -> {:cont, {:ok, %{s | devices: Map.put(s.devices, dev, pid)}}}
          {:error, reason} -> {:halt, {:error, {:io_init, dev, reason}, s}}
        end

      _, acc -> {:cont, acc}
    end)
  end

  defp guarded(fun) do
    fun.()
  rescue
    e in ArgumentError -> {:raise, e}
  end
end
