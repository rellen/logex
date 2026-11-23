{:ok, conveyors} = Logex.compile_file("write-a-function-block/conveyors.ld")
names = ~w(start_1 start_2 stop eye_2 c2.jam_t.acc belt_1 belt_2 jam_2 jam_lamp)

row = fn cells ->
  ["scan" | names]
  |> Enum.zip(cells)
  |> Enum.map_join("  ", fn {name, cell} ->
    String.pad_leading("#{cell}", String.length(name))
  end)
  |> IO.puts()
end

scan = fn inputs, {number, state} ->
  state = Logex.Runtime.put_inputs(conveyors, state, inputs)
  {_outputs, state} = Logex.Runtime.scan(conveyors, state, 1000)
  row.([number | Enum.map(names, &get_in(state.env, String.split(&1, ".")))])
  {number + 1, state}
end

row.(["scan" | names])

# An input keeps its value until a map of a later scan gives it a new value.
[
  %{"start_1" => 1},
  %{"start_1" => 0, "start_2" => 1},
  %{"start_2" => 0, "eye_2" => 1},
  %{},
  %{},
  %{"eye_2" => 0},
  %{"stop" => 1},
  %{"stop" => 0}
]
|> Enum.reduce({1, Logex.Runtime.instance(conveyors)}, scan)
