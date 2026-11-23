# Part 1: compile plant.logex. Print each warning, each global and its point, and the
# task of each instance. If the files have an error, print each diagnostic and stop.
check = fn
  {:ok, plant} ->
    Enum.each(plant.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
    for global <- plant.globals, do: IO.puts("#{global.at}  #{global.name}")
    for instance <- plant.instances, do: IO.puts("#{instance.name} on task #{instance.task}")
    plant

  {:error, diagnostics} ->
    Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
    System.halt(1)
end

plant = check.(Logex.Configuration.compile_file("plant.logex"))

# Part 2: run 7 cycles. Each line gives the ms since the last cycle, and the input
# points that change before the cycle. An input point keeps its value until it changes.
steps = [
  {0, %{}},
  {10, %{"pb_start_1" => 1, "pb_start_2" => 1}},
  {10, %{"pb_start_1" => 0, "pb_start_2" => 0}},
  {10, %{"tt_1" => 1}},
  {10, %{}},
  {10, %{"pb_start_2" => 1}},
  {10, %{"pb_start_2" => 0}}
]

row = fn cells, ran ->
  IO.puts(Enum.map_join(cells, &String.pad_leading("#{&1}", 6)) <> "  " <> ran)
end

row.(["time", "k1", "k2", "sp_1", "sp_2"], "ran")

Enum.reduce(steps, {Logex.Runtime.start(plant), 0}, fn {ms, changes}, {resource, time} ->
  {resource, out, events} = Logex.Runtime.cycle(resource, ms, changes)
  ran = for {:ran, _task, instance, _time} <- events, do: instance
  row.([time + ms, out["k1"], out["k2"], out["sp_1"], out["sp_2"]], Enum.join(ran, " "))
  {resource, time + ms}
end)
