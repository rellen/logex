# Throwaway (never landed): cycle/3's cost on N instances of §4.3's motor on one 10 ms task.
Code.require_file("plant.exs", __DIR__)
programs = Spike.Plant.programs()
for n <- [1, 10, 100, 1000] do
  text =
    "task fast interval 10 priority 1\nvar_global estop bool at panel.i.0\nvar_global go bool at panel.i.1\n" <>
      Enum.map_join(1..n, "", fn i ->
        "program m#{i} motor with fast\n  m#{i}.start go\n  m#{i}.stop 0\n  m#{i}.overtemp 0\n  m#{i}.reset 0\n"
      end)
  {:ok, config} = Logex.Configuration.compile("big", text, Map.take(programs, ["motor"]))
  rt = Logex.Runtime.start(config)
  {rt, _, _} = Logex.Runtime.cycle(rt, 0, %{"go" => 1, "estop" => 0})
  {rt, times} = Enum.reduce(1..50, {rt, []}, fn k, {rt, ts} ->
    t0 = System.monotonic_time(:microsecond)
    {rt, _, _} = Logex.Runtime.cycle(rt, 10, %{"go" => rem(k, 2)})
    {rt, [System.monotonic_time(:microsecond) - t0 | ts]}
  end)
  s = Enum.sort(times)
  IO.puts("#{String.pad_leading("#{n}", 5)} motors: cycle/3 µs p50 #{Enum.at(s, 25)} max #{List.last(s)}; per motor p50 #{div(Enum.at(s, 25), n)}")
end
