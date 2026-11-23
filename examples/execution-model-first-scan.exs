{:ok, boxes} = Logex.compile_file("execution-model/boxes.ld")

# One scan: the inputs that change, then the scan. The line shows the field
# `first` of the state before the scan, the input eye and the outputs.
scan = fn state, label, changed ->
  state = Logex.Runtime.put_inputs(boxes, state, changed)
  first = String.pad_trailing("#{state.first}", 5)
  {out, state} = Logex.Runtime.scan(boxes, state, 10)

  IO.puts(
    "#{String.pad_trailing(label, 21)}  first=#{first}  eye=#{state.env["eye"]}  count=#{out["count"]}" <>
      "  pulse=#{out["pulse"]}  first_out=#{out["first_out"]}"
  )

  state
end

state =
  Logex.Runtime.instance(boxes)
  |> scan.("start, box on the eye", %{"eye" => 1})
  |> scan.("box stays           ", %{})
  |> scan.("box goes            ", %{"eye" => 0})
  |> scan.("next box            ", %{"eye" => 1})

state =
  Logex.Runtime.restart(boxes, state, :warm)
  |> scan.("warm restart        ", %{})
  |> scan.("box goes            ", %{"eye" => 0})
  |> scan.("next box            ", %{"eye" => 1})

Logex.Runtime.restart(boxes, state, :cold)
|> scan.("cold restart        ", %{})
