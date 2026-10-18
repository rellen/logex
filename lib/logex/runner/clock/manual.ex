defmodule Logex.Runner.Clock.Manual do
  @moduledoc """
  A clock a test moves (M4-1, `docs/organisation.md` §4.11): a process holding a time
  and the timers set on it, which nothing delivers until the test says how much time
  passes. With it and `Logex.IO.Sim` a run of the wall-clock runner is deterministic, and
  repeats exactly from fresh processes. Its clock term, for `Logex.Runner.Clock`'s
  callbacks, is its pid.

      {:ok, clock} = Logex.Runner.Clock.Manual.start_link()
      Logex.Runner.Clock.Manual.wake_at(clock, pid, :tick, 10)
      :ok = Logex.Runner.Clock.Manual.advance(clock, 10)   # pid has handled :tick

  - `start_link/1` starts it at time 0, or at `now:`; `wait:` is how long `advance/2`
    waits for a receiver, 5000 ms unless set, from 1 ms to 4294967295, the longest the VM
    waits for an answer.
  - `advance/2` moves time on by a number of milliseconds and delivers each timer due on
    the way, the earliest first and timers due at one time in the order they were set,
    the clock reading each one's time while it is handled. It runs in the caller's
    process, which sends each message and then calls its receiver through `:sys`, so it
    goes on only once the receiver has handled it: the order holds by construction, one
    sender to one receiver, never by the order in which messages from two senders
    arrive. A timer set while one is handled is delivered by the same `advance/2` where
    its time falls inside it, and by a later one otherwise. What a receiver sends others
    while it handles a message is its own to finish, as a call finishes, before it
    returns.
  - `pass/2` is time that passes inside a step, as a slow device's: the clock moves on and
    delivers nothing, and the timers it passes wait for the next `advance/2`, which
    delivers them in their order, `advance(clock, 0)` among them, the clock never going
    back.
  - `pending/1` gives the timers not yet delivered, in the order `advance/2` would deliver
    them.

  A receiver is an OTP process, a GenServer as the runner's and each device's are, which
  answers `:sys` once it has handled what it was sent; one that does not answer within
  `wait:` is the host's mistake, an `ArgumentError`, and one that is down, or goes down
  while it handles its message, with whatever reason, `:timeout` among them, is passed
  over, as a real timer's message to a dead process is lost. The process that advances may be a receiver too: its message is then
  in its own mailbox when `advance/2` goes on. One process advances a clock at a time, but
  for one case: a receiver may advance it while it handles a message an advance delivered,
  time passing inside a step with the timers on the way delivered, where `pass/2` delivers
  none. Its advance delivers from its own process, every other receiver's timer handled as
  ever and its own left in its mailbox, and the advance that delivered to it goes on from
  there once it has handled its message (M4-4: a runner stuck in a task's run, its devices
  hearing their deadlines meanwhile).
  """

  use GenServer

  @behaviour Logex.Runner.Clock

  alias Logex.Runner.Clock

  @options [:now, :wait]

  # The longest a process waits for an answer, 2^32 - 1 ms: a call refuses a longer one.
  @longest 4_294_967_295

  @doc """
  Starts a manual clock linked to the caller, at time 0 or `now:`, waiting `wait:` ms,
  5000 unless set, 1 to 4294967295, for each receiver `advance/2` delivers to.
  """
  def start_link(opts \\ []) do
    %{now: now, wait: wait} = options!(opts)
    GenServer.start_link(__MODULE__, {now, wait})
  end

  @doc """
  Moves the clock on by `ms`, 0 or more, delivering each timer due on the way in time
  order, ties in the order they were set, and returns once each receiver has handled its
  message.
  """
  def advance(clock, ms) do
    clock = clock!(clock)
    {target, wait} = GenServer.call(clock, {:span, span!(ms, "advance/2")})
    delivered(clock, target, wait)
  end

  @doc "Moves the clock on by `ms`, 0 or more, delivering nothing: time passing inside a step."
  def pass(clock, ms), do: GenServer.call(clock!(clock), {:pass, span!(ms, "pass/2")})

  @doc "The timers not yet delivered, `{at_ms, pid, message}`, in the order `advance/2` would deliver them."
  def pending(clock), do: GenServer.call(clock!(clock), :pending)

  @impl Clock
  def now_ms(clock), do: GenServer.call(clock!(clock), :now)

  @impl Clock
  def wake_at(clock, pid, message, at_ms),
    do:
      GenServer.call(
        clock!(clock),
        {:wake_at, Clock.receiver!(pid), message, Clock.time!(at_ms)}
      )

  @impl Clock
  def cancel(clock, timer), do: GenServer.call(clock!(clock), {:cancel, Clock.timer!(timer)})

  # Each timer due by `target`, taken from the clock one at a time, so that one a receiver
  # sets while it handles its own is taken in its order.
  defp delivered(clock, target, wait),
    do: deliver(GenServer.call(clock, {:take, target}), clock, target, wait)

  defp deliver({:timer, pid, message}, clock, target, wait) do
    send(pid, message)
    handled(pid, message, wait)
    delivered(clock, target, wait)
  end

  defp deliver(:none, clock, target, _wait), do: GenServer.call(clock, {:reach, target})

  # The caller sent the message, so a call from it through `:sys` is answered only once the
  # receiver has handled it. A receiver that is down, or the caller itself, needs no wait.
  # One that stops with the reason :timeout exits the call as a wait does, so only a
  # receiver still alive has not answered.
  defp handled(pid, message, wait) do
    :sys.get_state(pid, wait)
    :ok
  catch
    :exit, {:timeout, _} -> unanswered!(Process.alive?(pid), pid, message, wait)
    :exit, _down -> :ok
  end

  defp unanswered!(true, pid, message, wait),
    do: raise(ArgumentError, unanswered(pid, message, wait))

  defp unanswered!(false, _pid, _message, _wait), do: :ok

  defp unanswered(pid, message, wait),
    do:
      "the manual clock waited #{wait} ms for #{inspect(pid)} to handle #{inspect(message)}: " <>
        "a receiver of its timers is an OTP process, as a GenServer is, which answers " <>
        ":sys once it has handled what it was sent"

  @impl GenServer
  def init({now, wait}),
    do: {:ok, %{now: now, wait: wait, seq: 0, timers: :gb_trees.empty(), refs: %{}}}

  @impl GenServer
  def handle_call(:now, _from, state), do: {:reply, state.now, state}

  def handle_call({:wake_at, pid, message, at}, _from, %{seq: seq} = state) do
    ref = make_ref()
    key = {at, seq}

    {:reply, ref,
     %{
       state
       | seq: seq + 1,
         timers: :gb_trees.insert(key, {ref, pid, message}, state.timers),
         refs: Map.put(state.refs, ref, key)
     }}
  end

  def handle_call({:cancel, ref}, _from, state),
    do: {:reply, :ok, cancelled(Map.fetch(state.refs, ref), ref, state)}

  def handle_call({:span, ms}, _from, state), do: {:reply, {state.now + ms, state.wait}, state}

  def handle_call({:take, target}, _from, state),
    do: taken(earliest(state.timers), target, state)

  def handle_call({:reach, target}, _from, state),
    do: {:reply, :ok, %{state | now: max(state.now, target)}}

  def handle_call({:pass, ms}, _from, state), do: {:reply, :ok, %{state | now: state.now + ms}}

  def handle_call(:pending, _from, state),
    do:
      {:reply,
       for(
         {{at, _seq}, {_ref, pid, message}} <- :gb_trees.to_list(state.timers),
         do: {at, pid, message}
       ), state}

  defp cancelled({:ok, key}, ref, state),
    do: %{state | timers: :gb_trees.delete(key, state.timers), refs: Map.delete(state.refs, ref)}

  defp cancelled(:error, _ref, state), do: state

  defp earliest(timers), do: earliest(:gb_trees.is_empty(timers), timers)

  defp earliest(true, _timers), do: :none
  defp earliest(false, timers), do: :gb_trees.smallest(timers)

  # The earliest timer, where its time is within the span, taken: the clock reads its time,
  # never going back.
  defp taken({{at, _seq} = key, {ref, pid, message}}, target, state) when at <= target,
    do:
      {:reply, {:timer, pid, message},
       %{
         state
         | now: max(state.now, at),
           timers: :gb_trees.delete(key, state.timers),
           refs: Map.delete(state.refs, ref)
       }}

  defp taken(_not_due, _target, state), do: {:reply, :none, state}

  # The options, checked in order: the list, each key, then each value.
  defp options!(opts) when is_list(opts), do: listed!(Keyword.keyword?(opts), opts)
  defp options!(opts), do: raise(ArgumentError, takes(opts))

  defp listed!(false, opts), do: raise(ArgumentError, takes(opts))

  defp listed!(true, opts) do
    known!(Keyword.keys(opts) -- @options)
    %{now: now!(Keyword.get(opts, :now, 0)), wait: wait!(Keyword.get(opts, :wait, 5000))}
  end

  defp takes(opts),
    do: "the manual clock takes a keyword list of options, now: and wait:, got: #{inspect(opts)}"

  defp known!([]), do: :ok

  defp known!([key | _]),
    do: raise(ArgumentError, "the manual clock takes now: and wait:, got: #{inspect(key)}")

  defp now!(now) when is_integer(now), do: now

  defp now!(other),
    do:
      raise(
        ArgumentError,
        "the manual clock's now: is a whole number of milliseconds, got: #{inspect(other)}"
      )

  defp wait!(wait) when wait in 1..@longest, do: wait

  defp wait!(other),
    do:
      raise(
        ArgumentError,
        "the manual clock's wait: is a whole number of milliseconds, 1 to #{@longest}, the " <>
          "longest the VM waits, got: " <> inspect(other)
      )

  defp span!(ms, _function) when is_integer(ms) and ms >= 0, do: ms

  defp span!(other, function),
    do:
      raise(
        ArgumentError,
        "#{function} moves the clock on by a whole number of milliseconds, 0 or more, got: " <>
          inspect(other)
      )

  # A manual clock is a process this module started, by its pid: one that is down, or is
  # another kind of process, is the host's mistake.
  defp clock!(clock) when is_pid(clock), do: started!(Process.info(clock, :dictionary), clock)
  defp clock!(other), do: raise(ArgumentError, expected(other))

  defp started!({:dictionary, dictionary}, clock),
    do: ours!(List.keyfind(dictionary, :"$initial_call", 0), clock)

  defp started!(nil, clock),
    do: raise(ArgumentError, "the manual clock #{inspect(clock)} is not running")

  defp ours!({_key, {__MODULE__, :init, 1}}, clock), do: clock
  defp ours!(_other, clock), do: raise(ArgumentError, expected(clock) <> ", another process")

  defp expected(other),
    do:
      "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, got: #{inspect(other)}"
end
