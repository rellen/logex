{:ok, edges} = Logex.compile_file("instructions-contacts-and-coils/edges.ld")

names = ["scan", "eye", "new_box", "box_in", "eye_lamp", "box_out", "s1", "s2", "s3"]

row = fn cells ->
  names
  |> Enum.zip(cells)
  |> Enum.map_join("  ", fn {name, cell} -> String.pad_leading("#{cell}", String.length(name)) end)
  |> IO.puts()
end

scan = fn inputs, {number, state} ->
  state = Logex.Runtime.put_inputs(edges, state, inputs)
  {_outputs, state} = Logex.Runtime.scan(edges, state, 10)
  row.([number | Enum.map(tl(names), &state.env[&1])])
  {number + 1, state}
end

row.(names)

[%{"eye" => 1}, %{}, %{"eye" => 0}, %{}, %{"eye" => 1}, %{}, %{"eye" => 0}, %{}]
|> Enum.reduce({1, Logex.Runtime.instance(edges)}, scan)
