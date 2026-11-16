{:ok, boxes} = Logex.compile_file("boxes.ld")
{:ok, v2} = Logex.compile(File.read!("boxes_v2.ld"), name: "boxes")

scan = fn inputs, state ->
  state = Logex.Runtime.put_inputs(boxes, state, inputs)
  {outputs, state} = Logex.Runtime.scan(boxes, state, 10)
  IO.puts("scan    #{inspect(outputs)}")
  state
end

# The host does an accept and prints the forecast.
accept = fn state, label ->
  {:ok, edit, forecast} = Logex.Edit.accept(boxes, v2, state)
  IO.puts(label)
  Enum.each(forecast, &IO.puts("        #{inspect(&1)}"))
  edit
end

# 3 boxes go past the photo-eye. The lamp comes on.
state =
  [0, 1, 0, 1, 0, 1]
  |> Enum.map(&%{"eye" => &1})
  |> Enum.reduce(Logex.Runtime.instance(boxes), scan)

edit = accept.(state, "forecast, with the lamp on")

# The lamp must stay on. The cancel returns the old program.
{_boxes, state, report} = Logex.Edit.cancel(edit, state)
IO.puts("cancel  #{inspect(report)}")

# The operator takes the case away and pushes the reset button.
state = Enum.reduce([%{"eye" => 0, "reset_pb" => 1}, %{"reset_pb" => 0}], state, scan)

edit = accept.(state, "forecast, after the reset")
{_edit, _state, report} = Logex.Edit.test(edit, state)
IO.puts("test")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
