{:ok, conveyor} = Logex.compile_file("use-one-shots-and-pulse-coils/conveyor.ld")
shown = ["index", "position", "held_lamp", "boxes", "box_left"]

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(conveyor, state, inputs)
  {outputs, state} = Logex.Runtime.scan(conveyor, state, 10)
  values = Enum.map_join(shown, " ", fn tag -> "#{tag}=#{outputs[tag]}" end)
  IO.puts(String.pad_trailing(label, 25) <> values)
  state
end

Logex.Runtime.instance(conveyor)
|> scan.("button held, box at eye", %{"index_pb" => 1, "eye" => 1})
|> scan.("button released", %{"index_pb" => 0})
|> scan.("button pressed", %{"index_pb" => 1})
|> scan.("button held", %{})
|> scan.("box leaves the eye", %{"eye" => 0})
|> scan.("new box at the eye", %{"eye" => 1})
|> scan.("box stays", %{})
|> scan.("box leaves, released", %{"eye" => 0, "index_pb" => 0})
|> scan.("button pressed", %{"index_pb" => 1})
