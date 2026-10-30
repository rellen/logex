defmodule Logex.Runner.Clock.Monotonic do
  @moduledoc """
  The machine's monotonic clock, the runner's unless a test gives it another
  (`Logex.Runner.Clock`): `System.monotonic_time/1` in milliseconds, and
  `Process.send_after/4` to an absolute time on it, so that a deadline never drifts by
  the time a wake takes (`docs/organisation.md` §4.11). Its clock term is not read; `nil`
  by convention. A time already past is sent at once; one later than the VM can time,
  measured on OTP 28 as some 292 years after it starts, is the host's mistake.

  It counts what `erlang:system_info(:os_monotonic_time_source)` counts, `CLOCK_MONOTONIC`
  on Linux, which does not count a time the machine was suspended: what a sleep does to a
  runner is **unverified** (§4.11, "Risks").
  """

  @behaviour Logex.Runner.Clock

  alias Logex.Runner.Clock

  @impl Clock
  def now_ms(_clock), do: System.monotonic_time(:millisecond)

  @impl Clock
  def wake_at(_clock, pid, message, at_ms),
    do: timed(Clock.receiver!(pid), message, Clock.time!(at_ms))

  # A time already past is now, so that one from before the VM started, which
  # Process.send_after/4 refuses, is sent at once too; one later than the VM can time is
  # the host's mistake.
  defp timed(pid, message, at) do
    Process.send_after(pid, message, max(at, now_ms(nil)), abs: true)
  rescue
    ArgumentError ->
      reraise ArgumentError,
              "the monotonic clock cannot wait until #{at}, later than the VM can time",
              __STACKTRACE__
  end

  # M6-5 (decision 276): the machine's wall clock, for a store's header alone.
  @impl Clock
  def wall_ms(_clock), do: System.os_time(:millisecond)

  @impl Clock
  def cancel(_clock, timer) do
    Process.cancel_timer(Clock.timer!(timer))
    :ok
  end
end
