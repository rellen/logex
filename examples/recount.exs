{:ok, boxes} = Logex.compile_file("boxes.ld")
# A case of five, not three: boxes_v2.ld is boxes.ld with `ctu boxes 5`.
{:ok, v2} = Logex.compile(File.read!("boxes_v2.ld"), name: "boxes")

scan = fn state, program, label, inputs ->
  state = Logex.Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Logex.Runtime.scan(program, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

state =
  Logex.Runtime.instance(boxes)
  |> scan.(boxes, "start      ", %{})
  |> scan.(boxes, "box 1      ", %{"eye" => 1})
  |> scan.(boxes, "eye clear  ", %{"eye" => 0})
  |> scan.(boxes, "box 2      ", %{"eye" => 1})
  |> scan.(boxes, "eye clear  ", %{"eye" => 0})
  |> scan.(boxes, "box 3      ", %{"eye" => 1})

{:ok, edit, _forecast} = Logex.Edit.accept(boxes, v2, state)
{edit, state, report} = Logex.Edit.test(edit, state)
IO.puts("test, with box 3 still on the eye")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
{boxes, state, _report} = Logex.Edit.assemble(edit, state)

state
|> scan.(boxes, "still box 3", %{})
|> scan.(boxes, "eye clear  ", %{"eye" => 0})
|> scan.(boxes, "box 4      ", %{"eye" => 1})
|> scan.(boxes, "eye clear  ", %{"eye" => 0})
|> scan.(boxes, "box 5      ", %{"eye" => 1})
