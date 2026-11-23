{:ok, line} = Logex.Configuration.compile_file("faults/line.logex")

# Runs 1 cycle, elapsed ms after the last, then prints the outputs and each event.
cycle = fn resource, label, elapsed, inputs ->
  {resource, outputs, events} = Logex.Runtime.cycle(resource, elapsed, inputs)
  IO.puts("#{label}: #{inspect(outputs)}")
  for event <- events, do: IO.inspect(event)
  resource
end

Logex.Runtime.start(line)
|> cycle.("cycle 1", 0, %{"run" => 1, "boxes" => 120, "minutes" => 0})
|> cycle.("cycle 2", 10, %{"minutes" => 2, "sel" => 4, "set" => 1})
|> cycle.("cycle 3", 10, %{"sel" => 2})
