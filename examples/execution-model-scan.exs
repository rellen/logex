{:ok, belt} = Logex.compile_file("execution-model/belt.ld")

# The inputs that change before each scan. A scan keeps each other input.
changes = [
  %{"start" => 1},
  %{},
  %{"start" => 0},
  %{"eye" => 1},
  %{"stop" => 1, "eye" => 0},
  %{"stop" => 0}
]

scan = fn changed, state ->
  state = Logex.Runtime.put_inputs(belt, state, changed)
  {outputs, state} = Logex.Runtime.scan(belt, state)
  inputs = Map.take(state.env, ["start", "stop", "eye"])
  {Map.merge(inputs, outputs), state}
end

{scans, _state} = Enum.map_reduce(changes, Logex.Runtime.instance(belt), scan)

row = fn name, values ->
  IO.puts(String.pad_trailing(name, 12) <> Enum.join(values, "  "))
end

row.("scan", 1..6)

for tag <- ~w(start stop eye ready_lamp belt held box_seen box_lamp) do
  row.(tag, Enum.map(scans, & &1[tag]))
end
