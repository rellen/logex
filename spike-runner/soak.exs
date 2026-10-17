# Throwaway soak (never landed): §4.4's plant through Spike.Runner on the real clock for N
# seconds, the watchdog off so every gap between two output writes is counted, not tripped
# on. A button is pressed and released every 500 ms so the program does some work.
#   mix run spike-runner/soak.exs [seconds] [period]
Code.require_file("plant.exs", __DIR__)
Code.require_file("runner.exs", __DIR__)
alias Spike.{Runner, Plant}
alias Spike.IO.Sim
[secs, period] = Enum.map(System.argv() ++ ["20", "10"], &String.to_integer/1) |> Enum.take(2)
panel = Sim.new(); drive = Sim.new()
for a <- 0..7, do: Sim.set(panel, [a], 0)
{:ok, r} = Runner.start_link(configuration: Plant.config(), io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}}, period: period, watchdog: :off)
Runner.subscribe(r, [:overlap])
for k <- 1..(secs * 2) do
  Sim.set(panel, [0], rem(k, 2)); Sim.set(panel, [1], 1 - rem(k, 2))
  Process.sleep(500)
end
st = Runner.status(r)
overlaps = (fn f -> receive do {Runner, _, {:overlap, t, n}} -> [{t, n} | f.(f)] after 0 -> [] end end).(fn f -> receive do {Runner, _, {:overlap, t, n}} -> [{t, n} | f.(f)] after 0 -> [] end end)
costs = Enum.sort(st.costs); n = length(costs)
at = fn p -> Enum.at(costs, min(n - 1, trunc(p * n))) end
IO.puts("soak #{secs} s at #{period} ms: cycles #{st.cycles}, now #{st.now} ms, max late #{st.max_late_ms} ms, max wake-to-written #{st.max_cycle_ms} ms")
IO.puts("  gaps between output writes (ms): #{inspect(Enum.sort(st.gaps))}")
IO.puts("  runner cost per cycle µs (read+cycle+write): p50 #{at.(0.5)} p99 #{at.(0.99)} p99.9 #{at.(0.999)} max #{List.last(costs)}")
IO.puts("  overlaps: #{inspect(st.overlaps)} events: #{length(overlaps)}")
Runner.stop(r)
