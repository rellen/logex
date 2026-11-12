{:ok, plant} = Logex.Configuration.compile_file("packing.logex")
IO.puts(Enum.map_join(plant.tasks, ", ", &"#{&1.name} #{Logex.Configuration.watchdog(&1)} ms"))

steps = [
  {"started      ", 0, %{"pb_start_1" => 1}},
  {"a box        ", 5, %{"pb_start_1" => 0, "eye" => 1}},
  {"gone         ", 5, %{"eye" => 0}},
  {"a box        ", 5, %{"eye" => 1}},
  {"gone         ", 5, %{"eye" => 0}},
  {"the third box", 5, %{"eye" => 1}}
]

Enum.reduce(steps, {Logex.Runtime.start(plant), 0}, fn {label, elapsed, inputs}, {rt, now} ->
  {rt, out, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
  IO.puts("t=#{String.pad_leading("#{now + elapsed}", 2)}  #{label}  k1=#{out["k1"]} case_full=#{out["case_full"]}  ran #{Enum.join(ran, ", ")}")
  {rt, now + elapsed}
end)

IO.inspect(Logex.Runtime.next_due_in(Logex.Runtime.start(plant)), label: "next_due_in after start")
IO.inspect(Logex.Runtime.overlaps(Logex.Runtime.start(plant)), label: "overlaps")

{:error, diagnostics} = Logex.Configuration.compile_file("wrong_packing.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
