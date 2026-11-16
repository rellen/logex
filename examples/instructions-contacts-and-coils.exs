{:ok, eye} = Logex.compile_file("instructions-contacts-and-coils/eye.ld")

names = ["scan", "eye", "reset_pb", "box_lamp", "clear_lamp", "box_seen"]

row = fn cells ->
  names
  |> Enum.zip(cells)
  |> Enum.map_join("  ", fn {name, cell} -> String.pad_leading("#{cell}", String.length(name)) end)
  |> IO.puts()
end

scan = fn inputs, {number, state} ->
  state = Logex.Runtime.put_inputs(eye, state, inputs)
  {_outputs, state} = Logex.Runtime.scan(eye, state, 10)
  row.([number | Enum.map(tl(names), &state.env[&1])])
  {number + 1, state}
end

row.(names)

[
  %{},
  %{"eye" => 1},
  %{"eye" => 0},
  %{},
  %{"reset_pb" => 1},
  %{"reset_pb" => 0},
  %{"eye" => 1},
  %{"reset_pb" => 1}
]
|> Enum.reduce({1, Logex.Runtime.instance(eye)}, scan)
