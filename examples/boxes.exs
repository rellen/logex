{:ok, boxes} = Logex.compile_file("boxes.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(boxes, state, inputs)
  {outputs, state} = Logex.Runtime.scan(boxes, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(boxes)
|> scan.("box on the eye at start", %{"eye" => 1})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 1                  ", %{"eye" => 1})
|> scan.("still box 1            ", %{})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 2                  ", %{"eye" => 1})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 3                  ", %{"eye" => 1})
|> scan.("reset, box on the eye  ", %{"reset_pb" => 1})
|> scan.("reset let go           ", %{"reset_pb" => 0})
|> scan.("eye clear              ", %{"eye" => 0})
|> scan.("box 1 of the next case ", %{"eye" => 1})
