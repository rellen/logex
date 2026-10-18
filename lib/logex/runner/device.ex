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
  # - At each poll, after the read, it writes the outputs it last wrote again, whether or
  #   not a round wrote to it within the poll period, while its last refresh's deadline
  #   has not passed: a fixed timer, as Logix re-sends a module's outputs at its RPI, so
  #   that a device hears from its master once a poll period while the runner is well
  #   (decision 130); one never written, which is one with no output point too, since a
  #   round never writes it, writes nothing, and so does one never refreshed, which has
  #   heard no deadline.
  # - It passes what changed since it last passed anything on to the runner by a call,
  #   one at a time and in the order it saw them, which the runner answers once it has
  #   merged the change and run the round it causes (decision 124). While it waits it
  #   answers the runner's own requests to it, so that neither waits on the other.
  # - `write/2` writes the outputs a round gave, answered once the adapter has written them;
  #   `refresh/2` tells it the deadline by which it will hear from the runner again, without
  #   a wait (decision 125); `close/1` writes 0 to every output once, closes the adapter,
  #   and stops (decision 116).
  # - `zero/1` is a trip's (M4-4, decision 113): every output written 0 once, and the device
  #   latched, writing nothing more, a round's write and a poll's write again among it,
  #   until `release/1`, a restart's; a close of a latched device writes no 0 again, so
  #   that every output is written 0 exactly once whatever comes after the trip.

  use GenServer

  alias Logex.IO.Point

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def open(device), do: GenServer.call(device, :open, :infinity)
  def write(device, values), do: GenServer.call(device, {:write, values}, :infinity)
  def refresh(device, deadline), do: GenServer.cast(device, {:refresh, deadline})
  def close(device), do: GenServer.call(device, :close, :infinity)
  def zero(device), do: GenServer.call(device, :zero, :infinity)
  def release(device), do: GenServer.call(device, :release, :infinity)

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
         written: nil,
         latched: false,
         zeros:
           Map.new(for(%Point{direction: :output, address: address} <- points, do: {address, 0}))
       }}

  @impl GenServer
  def handle_call(:open, _from, state), do: opened(init_adapter(state), state)

  def handle_call({:write, _values}, _from, %{latched: true} = state), do: {:reply, :ok, state}
  def handle_call({:write, values}, _from, state), do: {:reply, :ok, wrote(values, state)}

  def handle_call(:close, _from, state), do: {:stop, :normal, :ok, closed(zeroed(state))}
  def handle_call(:zero, _from, state), do: {:reply, :ok, latched(state)}

  def handle_call(:release, _from, state),
    do: {:reply, :ok, %{state | latched: false}}

  @impl GenServer
  def handle_cast({:refresh, deadline}, state), do: {:noreply, %{state | deadline: deadline}}

  @impl GenServer
  def handle_info({__MODULE__, :poll, at}, %{next: at} = state) do
    {:ok, values, adapter} = state.module.read(state.adapter)
    {:noreply, polled(rewritten(passed(values, %{state | adapter: adapter})))}
  end

  def handle_info({__MODULE__, :poll, _stale}, state), do: {:noreply, state}

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

  # The outputs written.
  defp wrote(values, %{module: module, adapter: adapter} = state) do
    {:ok, adapter} = module.write(values, adapter)
    %{state | adapter: adapter, written: values}
  end

  # The outputs last written, written again at every poll, whatever a round wrote within
  # the period, while the last refresh's deadline has not passed (decision 130); a device
  # never refreshed has heard no deadline, so writes nothing again.
  defp rewritten(%{latched: true} = state), do: state
  defp rewritten(%{written: nil} = state), do: state
  defp rewritten(%{deadline: nil} = state), do: state

  defp rewritten(%{clock: {mod, clock}, deadline: deadline} = state),
    do: rewrite(mod.now_ms(clock) < deadline, state)

  defp rewrite(true, state), do: wrote(state.written, state)
  defp rewrite(false, state), do: state

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

  # A trip's latch: every output written 0 once, and nothing more until a release.
  defp latched(%{latched: true} = state), do: state
  defp latched(state), do: %{zeroed(state) | latched: true}

  # Every output written 0, once; a device with none is written nothing, and a latched
  # one was written its 0 when it latched.
  defp zeroed(%{latched: true} = state), do: state
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
