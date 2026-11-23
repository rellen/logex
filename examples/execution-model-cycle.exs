{:ok, line} = Logex.Configuration.compile_file("execution-model/line.logex")

# Each cycle: the time since the last cycle, and the input points that change.
steps = [
  {0, %{"pb_start" => 1}},
  {10, %{"pb_start" => 0}},
  {10, %{"estop" => 1}},
  {10, %{"eye" => 1}},
  {10, %{"estop" => 0, "eye" => 0}},
  {35, %{}}
]

cycle = fn {elapsed, inputs}, {resource, now} ->
  {resource, outputs, events} = Logex.Runtime.cycle(resource, elapsed, inputs)
  IO.puts("t=#{now + elapsed}  inputs #{inspect(inputs)}  outputs #{inspect(outputs)}")

  for event <- events do
    text = inspect(event, pretty: true, width: 76)
    IO.puts("  " <> String.replace(text, "\n", "\n  "))
  end

  {resource, now + elapsed}
end

{resource, _now} = Enum.reduce(steps, {Logex.Runtime.start(line), 0}, cycle)

IO.puts("overlaps/1: #{inspect(Logex.Runtime.overlaps(resource))}")
IO.puts("next_due_in/1: #{inspect(Logex.Runtime.next_due_in(resource))}")

# get/2 gives {:ok, value}, or {:error, message} for a path that names no value.
print = fn
  {:ok, value} -> "{:ok, #{inspect(value)}}"
  {:error, message} -> "{:error, message}\n  " <> message
end

for path <- ~w(motor_at_stop c1.estop b1.boxes.cv b1.boxes fans) do
  IO.puts("get/2 #{path}: " <> print.(Logex.Runtime.get(resource, path)))
end

# Each of these cycles raises an ArgumentError. The script prints its message.
calls = [
  fn -> Logex.Runtime.cycle(resource, -10, %{}) end,
  fn -> Logex.Runtime.cycle(resource, 10, %{"eye" => 2, "eyes" => 1, "motor_k" => 1}) end
]

for call <- calls do
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end
