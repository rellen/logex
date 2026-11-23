{:ok, line} = Logex.Configuration.compile_file("line.logex")

start = %{"pb_start_1" => 1, "pb_start_2" => 1}
release = %{"pb_start_1" => 0, "pb_start_2" => 0}

# Each entry gives the ms since the last cycle, and the globals at input points that
# change before the cycle. After the last cycle, print estop and the tags of each instance.
run = fn title, entries ->
  IO.puts(title)
  IO.puts("  time  k1  k2  ran")

  {resource, _time} =
    Enum.reduce(entries, {Logex.Runtime.start(line), 0}, fn {ms, changes}, {resource, time} ->
      {resource, out, events} = Logex.Runtime.cycle(resource, ms, changes)
      ran = for {:ran, _task, instance, _time} <- events, do: instance
      cells = Enum.map_join([time + ms, out["k1"], out["k2"]], &String.pad_leading("#{&1}", 4))
      IO.puts("  #{cells}  #{Enum.join(ran, " ")}")
      {resource, time + ms}
    end)

  paths = ~w(estop c1.estop c2.estop c1.fault c2.fault)
  IO.puts("  " <> Enum.map_join(paths, "  ", &"#{&1}=#{Logex.Runtime.get!(resource, &1)}"))
end

run.("estop is 1 from 50 ms:", [
  {0, start},
  {10, release},
  {10, %{}},
  {10, %{}},
  {10, %{}},
  {10, %{"estop" => 1}},
  {10, %{}}
])

run.("estop is 1 from 20 ms to 30 ms:", [
  {0, start},
  {10, release},
  {10, %{"estop" => 1}},
  {10, %{"estop" => 0}},
  {10, %{}},
  {10, %{}}
])
