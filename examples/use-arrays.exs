{:ok, weigh} = Logex.compile_file("use-arrays/weigh.ld")

scan = fn state, inputs ->
  state = Logex.Runtime.put_inputs(weigh, state, inputs)
  Logex.Runtime.scan(weigh, state)
end

{_outputs, state} = scan.(Logex.Runtime.instance(weigh), %{"eye" => 0, "weight" => 0})

Enum.reduce([620, 80, 300, 450, 510], state, fn weight, state ->
  {outputs, state} = scan.(state, %{"eye" => 1, "weight" => weight})
  IO.puts("box #{weight}  weights #{inspect(outputs["weights"])}  good #{outputs["good"]}  heavy #{outputs["heavy"]}")
  {_outputs, state} = scan.(state, %{"eye" => 0})
  state
end)
