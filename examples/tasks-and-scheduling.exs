{:ok, line} = Logex.Configuration.compile_file("tasks-and-scheduling/line.logex")

# Each cycle: the time since the last cycle, and the inputs that change.
steps = [
  {0, %{}},
  {10, %{}},
  {10, %{"estop" => 1}},
  {10, %{}},
  {10, %{"estop" => 0}},
  {10, %{}},
  {35, %{}}
]

tasks = ["fast", "slow", "on_estop", "main"]
IO.puts("time  estop  " <> Enum.join(tasks, "  "))

# A cell gives the place of the task's run in the cycle: 1 runs first. "." is no run.
place = fn
  nil -> "."
  index -> "#{index + 1}"
end

cycle = fn {elapsed, inputs}, {rt, now, estop} ->
  {rt, _outputs, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = for {:ran, task, _instance, _now} <- events, do: task
  estop = Map.get(inputs, "estop", estop)

  cells =
    for task <- tasks do
      cell = ran |> Enum.find_index(&(&1 == task)) |> place.()
      String.pad_leading(cell, byte_size(task))
    end

  time = String.pad_leading("#{now + elapsed}", 4)
  IO.puts("#{time}      #{estop}  " <> Enum.join(cells, "  "))
  {rt, now + elapsed, estop}
end

{rt, _now, _estop} = Enum.reduce(steps, {Logex.Runtime.start(line), 0, 0}, cycle)

IO.puts("missed periods: #{inspect(Logex.Runtime.overlaps(rt))}")
IO.puts("next due in: #{Logex.Runtime.next_due_in(rt)} ms")

for name <- ~w(conveyor fan alarm sorter) do
  IO.puts("#{name}.runs = #{Logex.Runtime.get!(rt, name <> ".runs")}")
end
