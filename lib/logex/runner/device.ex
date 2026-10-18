defmodule Logex.Runner.Device do
  @moduledoc false
  # One bound device's process (M4-3, docs/organisation.md §4.11), started by and linked
  # to its runner, internal: it holds the adapter's state and calls its callbacks, so that
  # an adapter runs in a process of its own (Logex.IO).
  #
  # - The runner opens it, `open/1`, which calls the adapter's init/3 and reads it once,
  #   giving every input it read; `{:error, reason}` for a device that cannot be opened.
  # - It reads its adapter every poll period on the runner's clock, from the time it was
  #   opened, each read on a grid that never drifts (decision 120); and it gives each
  #   message it is sent that is not the runner's to the adapter's report/2, where the
  #   adapter has one (decision 112).
  # - At each poll, after the read, it writes the outputs it last wrote again where
  #   nothing was written within a poll period and its last refresh's deadline has not
  #   passed, so that a device whose outputs never change still hears from its master
  #   once a poll period while the runner is well (decision 130); one never written, and
  #   one with no output point, writes nothing. A poll that finds a round due, come due
  #   less than a poll period before it and not yet run, leaves its write to that round:
  #   at the round's end, which `due/2` tells it, it writes again only where the round
  #   wrote nothing, the write counted from its poll, so that a round never follows a
  #   write of the outputs it is about to replace (decision 132).
  # - It passes what changed since it last passed anything on to the runner by a call,
  #   one at a time and in the order it saw them, which the runner answers once it has
  #   merged the change and run the round it causes (decision 124). While it waits it
  #   answers the runner's own requests to it, so that neither waits on the other.
  # - `write/2` writes the outputs a round gave, answered once the adapter has written them;
  #   `refresh/2` tells it the deadline by which it will hear from the runner again, without
  #   a wait (decision 125); `due/2`, after each round, when the next is due, nil for
  #   none, which also tells it that the round is done; `close/1` writes 0 to every output once, closes the adapter,
  #   and stops (decision 116).

  use GenServer

  alias Logex.IO.Point

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def open(device), do: GenServer.call(device, :open, :infinity)
  def write(device, values), do: GenServer.call(device, {:write, values}, :infinity)
  def refresh(device, deadline), do: GenServer.cast(device, {:refresh, deadline})
  def due(device, at), do: GenServer.cast(device, {:due, at})
  def close(device), do: GenServer.call(device, :close, :infinity)

  @impl GenServer
  def init(%{name: name, module: module, opts: opts, points: points, runner: runner} = args),
    do:
      {:ok,
       %{
         name: name,
         module: module,
         opts: opts,
         points: points,
         runner: runner,
         clock: args.clock,
         poll: args.poll,
         adapter: nil,
         image: %{},
         next: nil,
         deadline: nil,
         due: nil,
         owed: nil,
         written: nil,
         written_at: nil,
         zeros:
           Map.new(for(%Point{direction: :output, address: address} <- points, do: {address, 0}))
       }}

  @impl GenServer
  def handle_call(:open, _from, state), do: opened(init_adapter(state), state)

  def handle_call({:write, values}, _from, state), do: {:reply, :ok, wrote(values, state)}

  def handle_call(:close, _from, state), do: {:stop, :normal, :ok, closed(zeroed(state))}

  @impl GenServer
  def handle_cast({:refresh, deadline}, state), do: {:noreply, %{state | deadline: deadline}}

  def handle_cast({:due, at}, state), do: {:noreply, settled(%{state | due: at})}

  @impl GenServer
  def handle_info({__MODULE__, :poll, at}, %{next: at} = state) do
    {:ok, values, adapter} = state.module.read(state.adapter)
    {:noreply, polled(rewritten(passed(values, %{state | adapter: adapter}), at))}
  end

  def handle_info({__MODULE__, :poll, _stale}, state), do: {:noreply, state}

  # A poll's write left to a round: a wake at the same millisecond, set after the round's,
  # so that on the manual clock the round's end, which comes before it, has been taken
  # when it is delivered. It writes nothing itself.
  def handle_info({__MODULE__, :settled, _at}, state), do: {:noreply, state}

  def handle_info(message, %{module: module} = state),
    do: {:noreply, reported(function_exported?(module, :report, 2), message, state)}

  defp init_adapter(%{module: module, name: name, points: points, opts: opts}),
    do: module.init(name, points, opts)

  # Opened, the adapter is read once, all it gives taken as changed, and its first poll is
  # one period on.
  defp opened({:ok, adapter}, %{module: module} = state) do
    {:ok, values, adapter} = module.read(adapter)
    {mod, clock} = state.clock

    {:reply, {:ok, values},
     polled(%{state | adapter: adapter, image: values, next: mod.now_ms(clock)})}
  end

  defp opened({:error, reason}, state), do: {:stop, :normal, {:error, reason}, state}

  # The next poll, a period on from the last on its grid, past now: a poll that came late
  # skips the reads it missed rather than make up for them.
  defp polled(%{clock: {mod, clock}, next: last, poll: poll} = state) do
    now = mod.now_ms(clock)
    next = last + poll * (div(max(now - last, 0), poll) + 1)
    mod.wake_at(clock, self(), {__MODULE__, :poll, next}, next)
    %{state | next: next}
  end

  # The outputs written, and when, on the runner's clock.
  defp wrote(values, %{module: module, adapter: adapter, clock: {mod, clock}} = state) do
    {:ok, adapter} = module.write(values, adapter)
    %{state | adapter: adapter, written: values, written_at: mod.now_ms(clock)}
  end

  # The outputs last written, written again at the poll at `at` where nothing was written
  # within a poll period, while the last refresh's deadline has not passed (decision 130);
  # or, where a round is due that has not yet run, left to that round's end (decision 132).
  defp rewritten(%{written: nil} = state, _at), do: state

  defp rewritten(%{clock: {mod, clock}} = state, at), do: rewrite(mod.now_ms(clock), at, state)

  defp rewrite(now, at, %{written_at: written_at, poll: poll, deadline: deadline} = state)
       when now - written_at >= poll and now < deadline,
       do: again(round_due?(state.due, now, poll), now, at, state)

  defp rewrite(_now, _at, state), do: state

  defp again(false, _now, _at, state), do: wrote(state.written, state)

  defp again(true, now, at, %{clock: {mod, clock}} = state) do
    mod.wake_at(clock, self(), {__MODULE__, :settled, at}, now)
    %{state | owed: at}
  end

  # A round due by now, come due less than a poll period ago, that has not run: once it
  # runs, the runner tells the next due time, later than the round's.
  defp round_due?(due, now, poll) when is_integer(due) and due <= now and now - due < poll,
    do: true

  defp round_due?(_due, _now, _poll), do: false

  # A round's end: a poll's write left to it is made where the round wrote nothing since
  # that poll and the deadline has not passed, counted from the poll, so the next comes a
  # poll period after it, on the grid.
  defp settled(%{owed: nil} = state), do: state

  defp settled(%{owed: at, written_at: written_at} = state) when written_at >= at,
    do: %{state | owed: nil}

  defp settled(%{owed: at, clock: {mod, clock}, deadline: deadline} = state),
    do: settle(mod.now_ms(clock) < deadline, at, %{state | owed: nil})

  defp settle(false, _at, state), do: state
  defp settle(true, at, state), do: %{wrote(state.written, state) | written_at: at}

  defp reported(false, _message, state), do: state

  defp reported(true, message, %{module: module, adapter: adapter} = state) do
    {:ok, values, adapter} = module.report(message, adapter)
    passed(values, %{state | adapter: adapter})
  end

  # What changed since the device last passed anything on, passed on to the runner.
  defp passed(values, %{image: image} = state),
    do:
      changed(
        for({address, value} <- values, image[address] != value, into: %{}, do: {address, value}),
        state
      )

  defp changed(changes, state) when map_size(changes) == 0, do: state

  defp changed(changes, %{runner: runner, name: name, image: image} = state) do
    state = %{state | image: Map.merge(image, changes)}
    ref = Process.monitor(runner)
    send(runner, {:"$gen_call", {self(), ref}, {:changes, name, changes}})
    awaiting(ref, state)
  end

  # Waiting for the runner's answer, the runner's own requests answered meanwhile, so that
  # neither waits on the other (decision 124).
  defp awaiting(ref, state) do
    receive do
      {^ref, :ok} ->
        Process.demonitor(ref, [:flush])
        state

      {:DOWN, ^ref, :process, _runner, _reason} ->
        state

      {:"$gen_call", from, request} ->
        answered(handle_call(request, from, state), from, ref)

      {:"$gen_cast", request} ->
        {:noreply, state} = handle_cast(request, state)
        awaiting(ref, state)
    end
  end

  defp answered({:reply, reply, state}, from, ref) do
    GenServer.reply(from, reply)
    awaiting(ref, state)
  end

  defp answered({:stop, reason, reply, _state}, from, _ref) do
    GenServer.reply(from, reply)
    exit(reason)
  end

  # Every output written 0, once; a device with none is written nothing.
  defp zeroed(%{zeros: zeros} = state) when map_size(zeros) == 0, do: state

  defp zeroed(%{module: module, adapter: adapter, zeros: zeros} = state) do
    {:ok, adapter} = module.write(zeros, adapter)
    %{state | adapter: adapter}
  end

  defp closed(%{module: module, adapter: adapter} = state) do
    closing(function_exported?(module, :close, 1), module, adapter)
    state
  end

  defp closing(true, module, adapter), do: module.close(adapter)
  defp closing(false, _module, _adapter), do: :ok
end
