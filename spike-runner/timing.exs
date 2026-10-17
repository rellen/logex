# Throwaway timing spike (never landed). How closely do BEAM timers pace a 10 ms cycle of
# §4.4's plant on this machine? Each variant runs N cycles in its own process and prints
# the wake lateness (µs past the deadline), the elapsed_ms values cycle/3 was given, the
# cost of each cycle/3 call, and the overlap events the runtime reported.
#
#   mix run spike-runner/timing.exs [variant] [cycles]
#
# variants: abs (absolute timers on a 10 ms grid), rel (send_after 10 after each cycle),
# abs_gc (abs, 2 MB of garbage made each cycle), abs_high (abs at process priority high).
Code.require_file("plant.exs", __DIR__)

defmodule Spike.Timing do
  @period 10

  def run(variant, cycles) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        if variant == "abs_high", do: Process.flag(:priority, :high)
        send(parent, {:result, loop(variant, cycles)})
      end)

    receive do
      {:result, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, ^pid, reason} ->
        raise "spike process died: #{inspect(reason)}"
    end
  end

  defp loop(variant, cycles) do
    config = Spike.Plant.config()
    rt = Logex.Runtime.start(config)
    t0_ms = System.monotonic_time(:millisecond)

    # Cycle 1 at once (decision 50), then one cycle per 10 ms deadline.
    {rt, _out, _ev} = Logex.Runtime.cycle(rt, 0, %{"pb_start_1" => 1, "pb_start_2" => 1})
    state = %{rt: rt, logical: 0, t0: t0_ms, late: [], elapsed: [], cost: [], overlaps: 0,
              last_wake_us: System.monotonic_time(:microsecond), periods: []}
    arm(variant, state, 1)
    collect(variant, state, 1, cycles)
  end

  defp arm(v, state, k) when v in ["abs", "abs_gc", "abs_high"],
    do: Process.send_after(self(), {:tick, k}, state.t0 + k * @period, abs: true)

  defp arm("rel", _state, k), do: Process.send_after(self(), {:tick, k}, @period)

  defp collect(_variant, state, k, cycles) when k > cycles, do: state

  defp collect(variant, state, k, cycles) do
    receive do
      {:tick, ^k} ->
        wake_us = System.monotonic_time(:microsecond)
        deadline_us = (state.t0 + k * @period) * 1000
        wall_ms = System.convert_time_unit(wake_us, :microsecond, :millisecond) - state.t0
        elapsed = wall_ms - state.logical
        inputs = if rem(k, 50) == 0, do: %{"pb_stop_2" => rem(div(k, 50), 2)}, else: %{}
        c0 = System.monotonic_time(:microsecond)
        {rt, _out, events} = Logex.Runtime.cycle(state.rt, elapsed, inputs)
        c1 = System.monotonic_time(:microsecond)
        if variant == "abs_gc", do: garbage()
        overlaps = Enum.sum(for {:overlap, _t, n} <- events, do: n)

        state = %{
          state
          | rt: rt,
            logical: wall_ms,
            late: [wake_us - deadline_us | state.late],
            elapsed: [elapsed | state.elapsed],
            cost: [c1 - c0 | state.cost],
            overlaps: state.overlaps + overlaps,
            periods: [wake_us - state.last_wake_us | state.periods],
            last_wake_us: wake_us
        }

        arm(variant, state, k + 1)
        collect(variant, state, k + 1, cycles)
    end
  end

  # About 2 MB of short-lived terms, so the loop's own heap is collected now and then.
  defp garbage, do: Enum.reduce(1..20, 0, fn _, acc -> acc + length(Enum.to_list(1..12_500)) end)

  def report(variant, s, cycles) do
    late = Enum.sort(s.late)
    cost = Enum.sort(s.cost)
    periods = Enum.sort(s.periods)
    hist = s.elapsed |> Enum.frequencies() |> Enum.sort()

    IO.puts("""
    == #{variant}: #{cycles} cycles at #{@period} ms ==
      wake lateness µs  #{pct(late)}
      early wakes (before deadline): #{Enum.count(late, &(&1 < 0))}
      late > 1 ms: #{Enum.count(late, &(&1 > 1000))}, > 2 ms: #{Enum.count(late, &(&1 > 2000))}, > 5 ms: #{Enum.count(late, &(&1 > 5000))}
      wake-to-wake µs   #{pct(periods)}
      elapsed_ms given  #{inspect(hist)}
      cycle/3 cost µs   #{pct(cost)}
      overlap periods reported: #{s.overlaps}
      logical clock at end: #{s.logical} ms, wall: #{System.monotonic_time(:millisecond) - s.t0} ms
    """)
  end

  defp pct(sorted) do
    n = length(sorted)
    at = fn p -> Enum.at(sorted, min(n - 1, trunc(p * n))) end
    "min #{hd(sorted)}  p50 #{at.(0.5)}  p90 #{at.(0.9)}  p99 #{at.(0.99)}  p99.9 #{at.(0.999)}  max #{List.last(sorted)}"
  end
end

[variant | rest] = System.argv() ++ ["abs"]
cycles = case rest do [n | _] when n != "abs" -> String.to_integer(n); _ -> 1000 end
result = Spike.Timing.run(variant, cycles)
Spike.Timing.report(variant, result, cycles)
