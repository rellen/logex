{:ok, jog} = Logex.compile_file("jump-over-rungs/jog.ld")
names = ["manual", "jog_pb", "run_pb", "auto_lamp", "jog_lamp", "jog_t.acc", "jog_long", "motor"]

row = fn cells ->
  ["scan" | names]
  |> Enum.zip(cells)
  |> Enum.map_join("  ", fn {name, cell} -> String.pad_leading("#{cell}", String.length(name)) end)
  |> IO.puts()
end

scan = fn inputs, {number, state} ->
  state = Logex.Runtime.put_inputs(jog, state, inputs)
  {_outputs, state} = Logex.Runtime.scan(jog, state, 500)
  row.([number | Enum.map(names, &get_in(state.env, String.split(&1, ".")))])
  {number + 1, state}
end

row.(["scan" | names])

[
  %{"run_pb" => 1},
  %{"run_pb" => 0, "manual" => 1},
  %{"jog_pb" => 1},
  %{},
  %{"manual" => 0},
  %{"jog_pb" => 0},
  %{},
  %{},
  %{"manual" => 1, "jog_pb" => 1},
  %{"manual" => 0},
  %{"jog_pb" => 0},
  %{"manual" => 1}
]
|> Enum.reduce({1, Logex.Runtime.instance(jog)}, scan)
