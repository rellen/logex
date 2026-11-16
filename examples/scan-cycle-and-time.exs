{:ok, lamps} = Logex.compile_file("scan-cycle-and-time/lamps.ld")

# The inputs that change before each scan.
changes = [
  %{},
  %{"start" => 1},
  %{"start" => 0},
  %{"start" => 1},
  %{"start" => 0, "stop" => 1},
  %{}
]

# One scan. The state holds the inputs.
scan = fn changed, state ->
  state = Logex.Runtime.put_inputs(lamps, state, changed)
  {outputs, state} = Logex.Runtime.scan(lamps, state)
  inputs = Map.take(state.env, ["start", "stop"])
  {Map.merge(inputs, outputs), state}
end

state = Logex.Runtime.instance(lamps)
{scans, _state} = Enum.map_reduce(changes, state, scan)

row = fn name, values ->
  IO.puts(String.pad_trailing(name, 12) <> Enum.join(values, "  "))
end

row.("scan", 1..6)

for tag <- ~w(start stop ready_lamp start_lamp motor run_lamp) do
  row.(tag, Enum.map(scans, & &1[tag]))
end
