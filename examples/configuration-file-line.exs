# The script loads line_1.logex and prints what logex reads from each line: each field
# that has a value. Then it runs the plant 2 times. For each cycle, it prints the instances
# that the cycle runs, as task:instance.
{:ok, plant} = Logex.Configuration.compile_file("configuration-file/line_1.logex")

fields = fn item, keys ->
  pairs = for key <- keys, value = Map.get(item, key), do: "#{key} #{inspect(value)}"
  Enum.join(pairs, ", ")
end

types = Enum.join(Map.keys(plant.programs), ", ")
IO.puts("configuration #{plant.name}: program types #{types}")

task_keys = [:continuous, :single, :interval, :priority, :watchdog]
for t <- plant.tasks, do: IO.puts("line #{t.line}: task #{t.name}: #{fields.(t, task_keys)}")

global_keys = [:retain, :type, :initial, :at]

for g <- plant.globals,
    do: IO.puts("line #{g.line}: global #{g.name}: #{fields.(g, global_keys)}")

for i <- plant.instances,
    do: IO.puts("line #{i.line}: instance #{i.name}: #{fields.(i, [:type, :task])}")

for c <- plant.connections,
    do: IO.puts("line #{c.line}: #{c.instance}.#{c.member} to #{inspect(c.to)}")

IO.puts("warnings: #{length(plant.warnings)}")

run = fn label, steps ->
  IO.puts(label)

  Enum.reduce(steps, {Logex.Runtime.start(plant), 0}, fn {step, ms, inputs}, {rt, now} ->
    {rt, out, events} = Logex.Runtime.cycle(rt, ms, inputs)
    ran = for {:ran, task, instance, _now} <- events, do: "#{task}:#{instance}"
    values = "motor_k=#{out["motor_k"]} total=#{Logex.Runtime.get!(rt, "total")}"

    IO.puts(
      "  t=#{String.pad_leading("#{now + ms}", 2)} #{step} #{values}  ran #{Enum.join(ran, " ")}"
    )

    {rt, now + ms}
  end)
end

run.("estop rises at 15 ms:", [
  {"start      ", 0, %{"pb_start" => 1, "temps" => [41.5, 41.5]}},
  {"           ", 5, %{"pb_start" => 0}},
  {"a box      ", 5, %{"eye" => 1}},
  {"estop rises", 5, %{"estop" => 1}},
  {"           ", 5, %{}}
])

run.("estop is 1 from 12 ms to 15 ms:", [
  {"start      ", 0, %{"pb_start" => 1}},
  {"           ", 5, %{"pb_start" => 0}},
  {"           ", 5, %{}},
  {"estop rises", 2, %{"estop" => 1}},
  {"estop falls", 3, %{"estop" => 0}},
  {"           ", 5, %{}}
])
