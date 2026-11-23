{:ok, line} = Logex.Configuration.compile_file("event-tasks/line.logex")

# Each cycle: the time since the last cycle, and the inputs that change.
steps = [
  {0, %{"pb_start_1" => 1}},
  {10, %{"pb_start_1" => 0}},
  {10, %{"estop" => 1}},
  {10, %{}},
  {10, %{"estop" => 0, "pb_reset" => 1}},
  {10, %{"pb_reset" => 0, "pb_start_1" => 1}},
  {10, %{"estop" => 1, "pb_start_1" => 0}}
]

# The tags to show: 2 globals, then 4 members of each record.
records =
  for name <- ~w(event_rec fast_rec), member <- ~w(motor_was stops pressed held.acc) do
    "#{name}.#{member}"
  end

paths = ["estop", "k1" | records]

# One cycle. It gives 1 column of the table: 1 if on_estop ran, then each path.
cycle = fn {elapsed, inputs}, {rt, now} ->
  {rt, _outputs, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  ran = Enum.count(events, &match?({:ran, "on_estop", _instance, _now}, &1))
  values = Enum.map(paths, &Logex.Runtime.get!(rt, &1))
  {[now + elapsed, ran | values], {rt, now + elapsed}}
end

{columns, _state} = Enum.map_reduce(steps, {Logex.Runtime.start(line), 0}, cycle)

names = ["t", "on_estop ran" | paths]

for {name, values} <- Enum.zip(names, Enum.zip_with(columns, & &1)) do
  cells = Enum.map_join(values, "  ", &String.pad_leading("#{&1}", 2))
  IO.puts(String.pad_trailing(name, 20) <> cells)
end

Enum.each(line.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
