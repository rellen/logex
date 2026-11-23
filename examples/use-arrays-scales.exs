{:ok, scales} = Logex.compile_file("use-arrays/scales.ld")

scan = fn state, number, inputs ->
  state = Logex.Runtime.put_inputs(scales, state, inputs)
  {outputs, state} = Logex.Runtime.scan(scales, state)
  values = Enum.map_join(["slot_ok", "last", "full"], "  ", &"#{&1} #{inspect(outputs[&1])}")
  IO.puts("#{number}  #{values}  faults #{length(state.faults)}")
  state
end

Logex.Runtime.instance(scales)
|> scan.(1, %{"eye" => 0, "weight" => 0, "slot" => 2, "clear" => 0})
|> scan.(2, %{"eye" => 1, "weight" => 620})
|> scan.(3, %{"eye" => 0, "slot" => 5})
|> scan.(4, %{"eye" => 1, "weight" => 410})
|> scan.(5, %{"eye" => 0, "slot" => 2})
|> scan.(6, %{"clear" => 1})
|> scan.(7, %{"clear" => 0, "slot" => 8, "eye" => 1, "weight" => 700})
