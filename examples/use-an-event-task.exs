{:ok, plant} = Logex.Configuration.compile_file("trip.logex")

# Each entry gives the ms since the last cycle, and the globals at input points that
# change before the cycle.
entries = [
  {0, %{"pb_start_1" => 1}},
  {10, %{"pb_start_1" => 0}},
  {10, %{"estop" => 1}},
  {10, %{}},
  {10, %{"estop" => 0}},
  {10, %{"estop" => 1}}
]

IO.puts("time  estop  k1  k1_at_trip  ran")

Enum.reduce(entries, {Logex.Runtime.start(plant), 0}, fn {ms, changes}, {resource, time} ->
  {resource, out, events} = Logex.Runtime.cycle(resource, ms, changes)
  ran = for {:ran, _task, instance, _time} <- events, do: instance
  values = [time + ms, Logex.Runtime.get!(resource, "estop"), out["k1"]]
  cells = Enum.zip_with(values, [4, 7, 4], &String.pad_leading("#{&1}", &2))
  at_trip = String.pad_leading("#{Logex.Runtime.get!(resource, "k1_at_trip")}", 12)
  IO.puts("#{cells}#{at_trip}  #{Enum.join(ran, " ")}")
  {resource, time + ms}
end)
