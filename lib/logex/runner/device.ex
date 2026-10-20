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
  # - It passes what changed since the runner last took a change of it on to the runner
  #   by a call, one at a time and in the order it saw them, which the runner answers once
  #   it has merged the change and run the round it causes (decision 124), or refuses, for
  #   a value that does not fit or an address that is no input point's (decision 114): a
  #   change refused is not taken, so the next read passes it on again. While it waits it
  #   answers the runner's own requests to it, so that neither waits on the other.
  # - `write/2` writes the outputs a round gave, answered once the adapter has written them;
  #   `refresh/2` tells it the deadline by which it will hear from the runner again, without
  #   a wait (decision 125); `close/1` writes 0 to every output once, closes the adapter,
  #   and stops (decision 116).
  # - `zero/1` is a trip's (M4-4, decision 113): every output written 0 once, and the device
  #   latched, writing nothing more, a round's write and a poll's write again among it,
  #   until `release/2`, a restart's, which forgets what it last wrote, so that nothing is
  #   written again before the restart's first round writes; a close of a latched device
  #   writes no 0 again, so that every output is written 0 exactly once whatever comes
  #   after the trip. A release gives it the runner's count of restarts, 0 from its
  #   opening, which every notice it sends the runner carries as `restarts`, so that the
  #   runner passes over a latch or a fault raised before the restart it released for.
  # - `reread/1` is a restart's read, after its release (decision 142): the adapter read
  #   once, as an opening reads it, `{:ok, values}`, or `{:fault, cause}`, the device left
  #   released for the runner to latch again. What it read is not what the device last
  #   passed on until the runner has checked it and says so, `taken/2`, a cast that comes
  #   before anything else the runner sends it: a read the runner refuses, an address
  #   that is no input point's or a value that does not fit, leaves nothing behind, so
  #   that the device passes it on again whenever it reads it again.
  # - A change it passes on carries the count of restarts it had heard as it read it, as
  #   its notices do: one read before the runner's last restart, which the restart's own
  #   read has overtaken, the runner answers `:stale`, taking nothing, and the device keeps
  #   what the restart's read gave.
  # - Its heartbeat (decision 125): a refresh carries the deadline by which it will hear
  #   from the runner again, and the time it was sent. A device that hears nothing by the
  #   deadline its last refresh carried, a wake on the runner's clock at it, latches as a
  #   trip's zero does and tells the runner, `{Logex.Runner.Device, pid, restarts, at,
  #   {:latched, name, ms}}`, `at` the time on the runner's clock it latched and `ms` the
  #   time from that refresh to its deadline, which the runner trips on when it next runs,
  #   a latched one too, which the runner, tripped already or restarted since, passes
  #   over. One wake is kept, set again only where a refresh brings the deadline sooner,
  #   and moved on to the last deadline where it comes before it; and a device waiting on
  #   the runner for its own change takes its wake there too, so that a runner stuck while
  #   it takes the change is seen.
  # - Back from its adapter (decision 114): after each read and each report, whatever its
  #   result, and at each poll while it waits on the runner, the device tells the runner,
  #   `{Logex.Runner.Device, pid, restarts, at, {:back, name, nil}}`, so that the runner
  #   sees one hung inside its own read or report, which no request of the runner's
  #   reaches while its outputs do not change.
  # - Its faults (decision 114): every callback is called guarded, so that an error given
  #   back, `{:error, reason, state}`, a raise, a throw, an exit, or a value of a shape the
  #   behaviour does not give, is a cause, `{:error, reason}`, `{:raised, message}`,
  #   `{:thrown, term}` or `{:exited, term}`, a shape the behaviour does not give being
  #   `{:raised, message}` with a message that says so. A read's, a report's or a poll's
  #   write again tells the runner, `{Logex.Runner.Device, pid, restarts, at, {:fault,
  #   name, cause}}`, `at` the time on the runner's clock it failed, and latches, its 0 written once where
  #   its adapter still takes it; a round's write answers `{:error, cause}`, and the
  #   runner's trip latches it, as every device. An open that fails is `{:error,
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

  def release(device, restarts, timeout \\ :infinity),
    do: GenServer.call(device, {:release, restarts}, timeout)

  def reread(device, timeout \\ :infinity), do: GenServer.call(device, :reread, timeout)

  def taken(device, values), do: GenServer.cast(device, {:taken, values})

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
       restarts: args.restarts,
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

  # A release forgets what the device last wrote, so that a poll's write again writes
  # nothing until the restart's first round has written its own outputs: a restart is
  # never a resume (decision 113). It takes the runner's count of restarts, which every
  # notice after it carries, so that the runner passes over one raised before it.
  def handle_call({:release, restarts}, _from, state),
    do: {:reply, :ok, %{disarmed(state) | latched: false, written: nil, restarts: restarts}}

  # A restart's read (decision 142): the adapter read once, as an opening reads it, or the
  # read's fault, which the runner answers the restart with; its poll grid is kept. What
  # it read is what the device last passed on only once the runner has taken it.
  def handle_call(:reread, _from, state),
    do: read_again(adapted(:read, [state.adapter], state), state)

  @impl GenServer
  def handle_cast({:taken, values}, state),
    do: {:noreply, %{state | image: Map.merge(state.image, values)}}

  def handle_cast({:refresh, _deadline, _at}, %{latched: true} = state), do: {:noreply, state}

  def handle_cast({:refresh, deadline, at}, state),
    do: {:noreply, armed(%{state | deadline: deadline, heard: at})}

  @impl GenServer
  def handle_info({__MODULE__, :poll, at}, %{next: at} = state),
    do: waited(fn -> polled(read(back(adapted(:read, [state.adapter], state), state), state)) end)

  def handle_info({__MODULE__, :poll, _stale}, state), do: {:noreply, state}

  def handle_info({__MODULE__, :deadline, at}, %{timer: {_timer, at}} = state),
    do: {:noreply, expired(%{state | timer: nil})}

  def handle_info({__MODULE__, :deadline, _stale}, state), do: {:noreply, state}

  def handle_info(message, %{module: module} = state),
    do: waited(fn -> reported(function_exported?(module, :report, 2), message, state) end)

  # A poll or a report, which may wait on the runner for the change it passes on: a close
  # answered while it waits stops the device with the state the close left, closed, so
  # that terminate/2 zeroes and closes nothing again (decisions 115 and 116).
  defp waited(handled) do
    {:noreply, handled.()}
  catch
    :throw, {__MODULE__, :stop, reason, state} -> {:stop, reason, state}
  end

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

  defp read_again({:ok, values, adapter}, state),
    do: {:reply, {:ok, values}, %{state | adapter: adapter}}

  defp read_again({:fault, cause, adapter}, state),
    do: {:reply, {:fault, cause}, %{state | adapter: adapter}}

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

  defp faulted(cause, %{runner: runner, name: name, clock: {mod, clock}} = state) do
    send(
      runner,
      {__MODULE__, self(), state.restarts, clocked(fn -> mod.now_ms(clock) end),
       {:fault, name, cause}}
    )

    latched(state)
  end

  # A round's write: answered :ok, or with its cause, which trips the runner, whose zero
  # latches the device.
  defp written({:ok, state}), do: {:reply, :ok, state}
  defp written({:fault, cause, state}), do: {:reply, {:error, cause}, state}

  # The next poll, a period on from the last on its grid, past now: a poll that came late
  # skips the reads it missed rather than make up for them.
  defp polled(%{clock: {mod, clock}, next: last, poll: poll} = state) do
    now = clocked(fn -> mod.now_ms(clock) end)
    next = last + poll * (div(max(now - last, 0), poll) + 1)
    clocked(fn -> mod.wake_at(clock, self(), {__MODULE__, :poll, next}, next) end)
    %{state | next: next}
  end

  # Back from its adapter, a read or a report given back whatever its result: the runner
  # told, `{Logex.Runner.Device, pid, restarts, at, {:back, name, nil}}`, at the time on its clock,
  # so that it sees a device hung inside its own read or report (decision 114), which no
  # request of the runner's reaches while its outputs do not change; the cost, a message
  # a device a poll period, and one a report.
  defp back(result, state) do
    told_back(state)
    result
  end

  defp told_back(%{clock: {mod, clock}, runner: runner, name: name} = state) do
    send(
      runner,
      {__MODULE__, self(), state.restarts, clocked(fn -> mod.now_ms(clock) end),
       {:back, name, nil}}
    )

    state
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
    do: report(back(adapted(:report, [message, state.adapter], state), state), state)

  defp report({:ok, values, adapter}, state), do: passed(values, %{state | adapter: adapter})
  defp report({:fault, cause, adapter}, state), do: faulted(cause, %{state | adapter: adapter})

  # What changed since the runner last took a change of the device, passed on to it.
  defp passed(values, %{image: image} = state),
    do:
      changed(
        for({address, value} <- values, image[address] != value, into: %{}, do: {address, value}),
        state
      )

  defp changed(changes, state) when map_size(changes) == 0, do: state

  defp changed(changes, %{runner: runner, name: name} = state) do
    ref = Process.monitor(runner)
    send(runner, {:"$gen_call", {self(), ref}, {:changes, name, state.restarts, changes}})
    awaiting(ref, changes, state)
  end

  # Waiting for the runner's answer, the runner's own requests answered meanwhile, so that
  # neither waits on the other (decision 124). A change the runner took is what the device
  # last passed on; one it refused, a value that does not fit or an address that is no
  # input point's (decision 114), is not, so that the next read passes it on again; and
  # one read before the runner's last restart, `:stale`, is not either, the restart's own
  # read having overtaken it (decision 142).
  defp awaiting(ref, changes, state) do
    receive do
      {^ref, :ok} ->
        Process.demonitor(ref, [:flush])
        %{state | image: Map.merge(state.image, changes)}

      {^ref, {:error, _cause}} ->
        Process.demonitor(ref, [:flush])
        state

      {^ref, :stale} ->
        Process.demonitor(ref, [:flush])
        state

      {:DOWN, ^ref, :process, _runner, _reason} ->
        state

      {__MODULE__, :deadline, _at} = deadline ->
        {:noreply, state} = handle_info(deadline, state)
        awaiting(ref, changes, state)

      # A poll while it waits reads nothing, its read waiting for the next, but tells the
      # runner the device is not inside its adapter, as every read does.
      {__MODULE__, :poll, at} when at == :erlang.map_get(:next, state) ->
        awaiting(ref, changes, polled(told_back(state)))

      {:"$gen_call", from, request} ->
        answered(handle_call(request, from, state), from, ref, changes)

      {:"$gen_cast", request} ->
        {:noreply, state} = handle_cast(request, state)
        awaiting(ref, changes, state)
    end
  end

  defp answered({:reply, reply, state}, from, ref, changes) do
    GenServer.reply(from, reply)
    awaiting(ref, changes, state)
  end

  defp answered({:stop, reason, reply, state}, from, _ref, _changes) do
    GenServer.reply(from, reply)
    throw({__MODULE__, :stop, reason, state})
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
  defp expired(%{clock: {mod, clock}, deadline: deadline} = state) do
    now = clocked(fn -> mod.now_ms(clock) end)
    expire(now >= deadline, now, state)
  end

  defp expire(false, _now, state), do: armed(state)

  # A device latched already, by a trip's zero or its own fault, latches no more; it tells
  # the runner all the same, and a notice raised before a restart's release is one the
  # restarted runner passes over, by the count of restarts it carries.
  defp expire(true, now, %{runner: runner, name: name} = state) do
    send(
      runner,
      {__MODULE__, self(), state.restarts, now, {:latched, name, state.deadline - state.heard}}
    )

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
