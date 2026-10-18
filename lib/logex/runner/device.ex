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
  # - Its heartbeat (decision 125): a refresh carries the deadline by which it will hear
  #   from the runner again, and the time it was sent. A device that hears nothing by the
  #   deadline its last refresh carried, a wake on the runner's clock at it, latches as a
  #   trip's zero does and tells the runner, `{Logex.Runner.Device, pid, {:latched, name,
  #   ms}}`, `ms` the time from that refresh to its deadline, which the runner trips on when
  #   it next runs. One wake is kept, set again only where a refresh brings the deadline
  #   sooner, and moved on to the last deadline where it comes before it; and a device
  #   waiting on the runner for its own change takes its wake there too, so that a runner
  #   stuck while it takes the change is seen.
  # - Its faults (decision 114): every callback is called guarded, so that an error given
  #   back, `{:error, reason, state}`, a raise, a throw, an exit, or a value of a shape the
  #   behaviour does not give, is a cause, `{:error, reason}`, `{:raised, message}`,
  #   `{:thrown, term}` or `{:exited, term}`, a shape the behaviour does not give being
  #   `{:raised, message}` with a message that says so. A read's, a report's or a poll's
  #   write again tells the runner, `{Logex.Runner.Device, pid, {:fault, name, cause}}`; a
  #   round's write answers `{:error, cause}`; and either way the device latches, its 0
  #   written once where its adapter still takes it. An open that fails is `{:error,
  #   reason}`, init/3's own reason or the cause, and the process stops; a zero or a close
  #   that fails is passed over, the last the device can do. Each call of the runner's
  #   takes a timeout, the runner's to keep (decision 125).
  # - Its runner's death (decision 115): it traps exits, so that its runner going down, a
  #   crash or a kill, stops it through terminate/2, which writes every output 0 once,
  #   where it is not latched already, and closes the adapter, as a close does; one closed
  #   already does neither again.

  use GenServer

  alias Logex.IO.Point

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def open(device, timeout \\ :infinity), do: GenServer.call(device, :open, timeout)

  def write(device, values, timeout \\ :infinity),
    do: GenServer.call(device, {:write, values}, timeout)

  def refresh(device, deadline, at), do: GenServer.cast(device, {:refresh, deadline, at})
  def close(device, timeout \\ :infinity), do: GenServer.call(device, :close, timeout)
  def zero(device, timeout \\ :infinity), do: GenServer.call(device, :zero, timeout)
  def release(device, timeout \\ :infinity), do: GenServer.call(device, :release, timeout)

  @impl GenServer
  def init(%{name: name, module: module, opts: opts, points: points, runner: runner} = args) do
    Process.flag(:trap_exit, true)

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
       heard: nil,
       timer: nil,
       written: nil,
       latched: false,
       open: false,
       closed: false,
       zeros:
         Map.new(for(%Point{direction: :output, address: address} <- points, do: {address, 0}))
     }}
  end

  @impl GenServer
  def handle_call(:open, _from, state), do: opened(init_adapter(state), state)

  def handle_call({:write, _values}, _from, %{latched: true} = state), do: {:reply, :ok, state}
  def handle_call({:write, values}, _from, state), do: written(wrote(values, state))

  def handle_call(:close, _from, state), do: {:stop, :normal, :ok, closed(zeroed(state))}
  def handle_call(:zero, _from, state), do: {:reply, :ok, latched(state)}

  def handle_call(:release, _from, state),
    do: {:reply, :ok, %{disarmed(state) | latched: false, deadline: nil}}

  @impl GenServer
  def handle_cast({:refresh, _deadline, _at}, %{latched: true} = state), do: {:noreply, state}

  def handle_cast({:refresh, deadline, at}, state),
    do: {:noreply, armed(%{state | deadline: deadline, heard: at})}

  @impl GenServer
  def handle_info({__MODULE__, :poll, at}, %{next: at} = state),
    do: {:noreply, polled(read(adapted(:read, [state.adapter], state), state))}

  def handle_info({__MODULE__, :poll, _stale}, state), do: {:noreply, state}

  def handle_info({__MODULE__, :deadline, at}, %{timer: {_timer, at}} = state),
    do: {:noreply, expired(%{state | timer: nil})}

  def handle_info({__MODULE__, :deadline, _stale}, state), do: {:noreply, state}

  def handle_info(message, %{module: module} = state),
    do: {:noreply, reported(function_exported?(module, :report, 2), message, state)}

  defp init_adapter(%{name: name, points: points, opts: opts} = state),
    do: adapted(:init, [name, points, opts], state)

  # Opened, the adapter is read once, all it gives taken as changed, and its first poll is
  # one period on; an init/3 or a first read that fails stops the device.
  defp opened({:ok, adapter}, state), do: first_read(adapted(:read, [adapter], state), state)

  defp opened({:fault, {:init, reason}, _adapter}, state),
    do: {:stop, :normal, {:error, reason}, state}

  defp opened({:fault, cause, _adapter}, state), do: {:stop, :normal, {:error, cause}, state}

  defp first_read({:ok, values, adapter}, state) do
    {mod, clock} = state.clock

    {:reply, {:ok, values},
     polled(%{
       state
       | adapter: adapter,
         open: true,
         image: values,
         next: clocked(fn -> mod.now_ms(clock) end)
     })}
  end

  defp first_read({:fault, cause, _adapter}, state), do: {:stop, :normal, {:error, cause}, state}

  # A poll's read: what changed passed on and the outputs written again, or the fault.
  defp read({:ok, values, adapter}, state),
    do: rewritten(passed(values, %{state | adapter: adapter}))

  defp read({:fault, cause, adapter}, state), do: faulted(cause, %{state | adapter: adapter})

  # A callback called guarded (decision 114): its result in the behaviour's shape, or the
  # cause of its failure, with the adapter's state it gave back or, where it gave none,
  # the state it was called with.
  defp adapted(callback, args, %{module: module, adapter: adapter}) do
    shaped(callback, apply(module, callback, args), module, adapter)
  rescue
    exception -> {:fault, {:raised, Exception.message(exception)}, adapter}
  catch
    :throw, thrown -> {:fault, {:thrown, thrown}, adapter}
    :exit, reason -> {:fault, {:exited, reason}, adapter}
  end

  defp shaped(:init, {:ok, adapter}, _module, _old), do: {:ok, adapter}
  defp shaped(:init, {:error, reason}, _module, old), do: {:fault, {:init, reason}, old}

  defp shaped(callback, {:ok, values, adapter}, _module, _old)
       when callback in [:read, :report] and is_map(values),
       do: {:ok, values, adapter}

  defp shaped(:write, {:ok, adapter}, _module, _old), do: {:ok, adapter}

  defp shaped(callback, {:error, reason, adapter}, _module, _old) when callback != :init,
    do: {:fault, {:error, reason}, adapter}

  defp shaped(callback, other, module, old),
    do: {:fault, {:raised, misshaped(callback, other, module)}, old}

  defp misshaped(callback, other, module),
    do:
      "#{inspect(module)}.#{callback}/#{arity(callback)} gave #{inspect(other)}, which is " <>
        "none of Logex.IO's results"

  defp arity(:init), do: 3
  defp arity(:write), do: 2
  defp arity(:report), do: 2
  defp arity(:read), do: 1

  # A fault of the device's own, a read's, a report's or a write again's: the runner told,
  # which trips, and the device latched, its 0 written once where its adapter takes it. A
  # latched device has told it already, or was latched by a trip.
  defp faulted(_cause, %{latched: true} = state), do: state

  defp faulted(cause, %{runner: runner, name: name} = state) do
    send(runner, {__MODULE__, self(), {:fault, name, cause}})
    latched(state)
  end

  # A round's write: answered :ok, or with its cause, the device latched.
  defp written({:ok, state}), do: {:reply, :ok, state}
  defp written({:fault, cause, state}), do: {:reply, {:error, cause}, latched(state)}

  # The next poll, a period on from the last on its grid, past now: a poll that came late
  # skips the reads it missed rather than make up for them.
  defp polled(%{clock: {mod, clock}, next: last, poll: poll} = state) do
    now = clocked(fn -> mod.now_ms(clock) end)
    next = last + poll * (div(max(now - last, 0), poll) + 1)
    clocked(fn -> mod.wake_at(clock, self(), {__MODULE__, :poll, next}, next) end)
    %{state | next: next}
  end

  # The outputs written, or the write's fault.
  defp wrote(values, state),
    do: wrote(adapted(:write, [values, state.adapter], state), values, state)

  defp wrote({:ok, adapter}, values, state),
    do: {:ok, %{state | adapter: adapter, written: values}}

  defp wrote({:fault, cause, adapter}, _values, state),
    do: {:fault, cause, %{state | adapter: adapter}}

  # The outputs last written, written again at every poll, whatever a round wrote within
  # the period, while the last refresh's deadline has not passed (decision 130); a device
  # never refreshed has heard no deadline, so writes nothing again.
  defp rewritten(%{latched: true} = state), do: state
  defp rewritten(%{written: nil} = state), do: state
  defp rewritten(%{deadline: nil} = state), do: state

  defp rewritten(%{clock: {mod, clock}, deadline: deadline} = state),
    do: rewrite(clocked(fn -> mod.now_ms(clock) end) < deadline, state)

  defp rewrite(true, state), do: again(wrote(state.written, state))
  defp rewrite(false, state), do: state

  defp again({:ok, state}), do: state
  defp again({:fault, cause, state}), do: faulted(cause, state)

  defp reported(false, _message, state), do: state

  defp reported(true, message, state),
    do: report(adapted(:report, [message, state.adapter], state), state)

  defp report({:ok, values, adapter}, state), do: passed(values, %{state | adapter: adapter})
  defp report({:fault, cause, adapter}, state), do: faulted(cause, %{state | adapter: adapter})

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

      {__MODULE__, :deadline, _at} = deadline ->
        {:noreply, state} = handle_info(deadline, state)
        awaiting(ref, state)

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

  # The one wake on the deadline: set where none is, or where a refresh brings the
  # deadline sooner than it; a later deadline keeps it, and it moves on when it comes.
  defp armed(%{timer: nil, deadline: deadline} = state), do: arm(deadline, state)

  defp armed(%{timer: {timer, at}, deadline: deadline} = state) when deadline < at do
    {mod, clock} = state.clock
    clocked(fn -> mod.cancel(clock, timer) end)
    arm(deadline, state)
  end

  defp armed(state), do: state

  # A release's: no deadline is heard until the next refresh.
  defp disarmed(%{timer: nil} = state), do: state

  defp disarmed(%{timer: {timer, _at}, clock: {mod, clock}} = state) do
    clocked(fn -> mod.cancel(clock, timer) end)
    %{state | timer: nil}
  end

  defp arm(at, %{clock: {mod, clock}} = state),
    do: %{
      state
      | timer:
          {clocked(fn -> mod.wake_at(clock, self(), {__MODULE__, :deadline, at}, at) end), at}
    }

  # The wake came: a deadline later than now moves it on; one reached, with no refresh
  # since that brought a later one, latches the device, which tells the runner.
  defp expired(%{clock: {mod, clock}, deadline: deadline} = state),
    do: expire(clocked(fn -> mod.now_ms(clock) end) >= deadline, state)

  defp expire(false, state), do: armed(state)
  defp expire(true, %{latched: true} = state), do: state

  defp expire(true, %{runner: runner, name: name} = state) do
    send(runner, {__MODULE__, self(), {:latched, name, state.deadline - state.heard}})
    latched(state)
  end

  # A trip's latch: every output written 0 once, and nothing more until a release.
  defp latched(%{latched: true} = state), do: state
  defp latched(state), do: %{zeroed(state) | latched: true}

  # Every output written 0, once; a device with none is written nothing, and a latched
  # one was written its 0 when it latched.
  defp zeroed(%{latched: true} = state), do: state
  defp zeroed(%{zeros: zeros} = state) when map_size(zeros) == 0, do: state

  defp zeroed(%{zeros: zeros} = state),
    do: zero_written(adapted(:write, [zeros, state.adapter], state), state)

  # A zero that fails is passed over: the device has nothing more it can do.
  defp zero_written({:ok, adapter}, state), do: %{state | adapter: adapter}
  defp zero_written({:fault, _cause, adapter}, state), do: %{state | adapter: adapter}

  defp closed(%{module: module} = state) do
    closing(function_exported?(module, :close, 1), state)
    %{state | closed: true}
  end

  # Its runner gone down, or any stop: every output 0 once and the adapter closed, where a
  # close has not done both already (decision 115).
  @impl GenServer
  def terminate(_reason, %{open: false}), do: :ok
  def terminate(_reason, %{closed: true}), do: :ok

  def terminate(_reason, state) do
    closed(zeroed(state))
    :ok
  end

  # A close that fails is passed over, the last call an adapter is given.
  defp closing(true, %{module: module, adapter: adapter}) do
    module.close(adapter)
  rescue
    _exception -> :ok
  catch
    _kind, _reason -> :ok
  end

  defp closing(false, _state), do: :ok

  # The runner's clock gone down, or failing, stops the device, a shutdown, as it stops
  # the runner.
  defp clocked(call) do
    call.()
  rescue
    exception -> exit({:shutdown, {:clock, Exception.message(exception)}})
  catch
    :exit, reason -> exit({:shutdown, {:clock, reason}})
  end
end
