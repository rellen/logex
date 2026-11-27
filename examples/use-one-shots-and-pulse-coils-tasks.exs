{:ok, plant} = Logex.Configuration.compile_file("use-one-shots-and-pulse-coils/lamp.logex")
Enum.each(plant.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

# Each entry gives the ms since the last cycle, the globals at input points that change
# before the cycle, and what the operator or the machine does.
entries = [
  {0, %{}, "start"},
  {10, %{"pb" => 1}, "press"},
  {10, %{"pb" => 0}, "release"},
  {10, %{"tick" => 1}, "tick"},
  {10, %{"tick" => 0, "pb" => 1}, "press"},
  {10, %{"tick" => 1}, "tick, held"},
  {10, %{"pb" => 0, "tick" => 0}, "release"},
  {5, %{"pb" => 1}, "short press"},
  {3, %{"pb" => 0}, "release"},
  {12, %{"tick" => 1}, "tick"}
]

IO.puts("time  pb  tick  by_event  by_period  ran")

Enum.reduce(entries, {Logex.Runtime.start(plant), 0}, fn {ms, changes, what}, {plant, time} ->
  {plant, _outputs, events} = Logex.Runtime.cycle(plant, ms, changes)
  ran = for {:ran, task, _instance, _time} <- events, do: task
  values = [time + ms] ++ Enum.map(~w(pb tick by_event by_period), &Logex.Runtime.get!(plant, &1))
  cells = Enum.zip_with(values, [4, 4, 6, 10, 11], &String.pad_leading("#{&1}", &2))
  IO.puts("#{cells}  #{String.pad_trailing(Enum.join(ran, " "), 13)} #{what}")
  {plant, time + ms}
end)
