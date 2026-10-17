defmodule Logex.Runner.Clock do
  @moduledoc """
  What the wall-clock runner reads time from (M4-1, `docs/organisation.md` §4.11), so that
  a test can move time. `Logex.Runtime` reads no clock: the runner does, through this
  behaviour, and nothing else in logex does.

  A clock is a module and a term the module's callbacks take, `{module, clock}`:
  `Logex.Runner.Clock.Monotonic`, the machine's monotonic clock, whose term is not read;
  or `Logex.Runner.Clock.Manual`, a process a test moves, whose term is its pid. Time is
  whole milliseconds, an integer that never goes back.

  - `now_ms/1` is the clock's time.
  - `wake_at/4` sends a message to a process once, at a time on the clock, absolute, and
    no sooner; a time already past sends it at the first moment the clock can, which for
    the manual clock is its next `advance/2`. It gives a reference for `cancel/2`.
  - `cancel/2` stops a timer not yet delivered, and is `:ok` whether or not one was
    pending. A message already sent stays in its receiver's mailbox, so a receiver that
    cancels a timer ignores a stale message of it.

  A receiver is a process given by its pid; a time an integer; a timer the reference
  `wake_at/4` gave. Anything else is the host's mistake, an `ArgumentError`, whose
  message is one for both clocks.
  """

  @typedoc "What a clock's callbacks take: a manual clock's pid, or any term for the monotonic one."
  @type clock :: term

  @doc "The clock's time, in whole milliseconds, never less than a time it gave before."
  @callback now_ms(clock) :: integer

  @doc "Sends `message` to `pid` once, at `at_ms` on the clock and no sooner."
  @callback wake_at(clock, pid, message :: term, at_ms :: integer) :: reference

  @doc "Stops a timer `wake_at/4` set, if it has not been delivered."
  @callback cancel(clock, timer :: reference) :: :ok

  @doc false
  # The checks both clocks make of what a host hands them, one message a rule.
  def receiver!(pid) when is_pid(pid), do: pid

  def receiver!(other),
    do: raise(ArgumentError, "a timer wakes a process, given by its pid, got: #{inspect(other)}")

  @doc false
  def time!(at) when is_integer(at), do: at

  def time!(other),
    do:
      raise(
        ArgumentError,
        "a timer's time is a whole number of milliseconds on its clock, got: #{inspect(other)}"
      )

  @doc false
  def timer!(timer) when is_reference(timer), do: timer

  def timer!(other),
    do:
      raise(
        ArgumentError,
        "a timer is cancelled by the reference wake_at/4 gave it, got: #{inspect(other)}"
      )
end
