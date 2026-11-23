{:ok, plant} = Logex.Configuration.compile_file("packing.logex")

for task <- plant.tasks do
  IO.puts("#{task.name}: watchdog #{Logex.Configuration.watchdog(task)} ms")
end

# 3 cycles, 5 ms apart. Each :ran event names the task and the instance.
Enum.reduce([0, 5, 5], {Logex.Runtime.start(plant), 0}, fn ms, {resource, time} ->
  {resource, _outputs, events} = Logex.Runtime.cycle(resource, ms, %{})
  ran = for {:ran, task, instance, _time} <- events, do: "#{instance} in #{task}"
  IO.puts("t=#{time + ms} ms: #{Enum.join(ran, ", ")}")
  {resource, time + ms}
end)
