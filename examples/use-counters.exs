{:ok, buffer} = Logex.compile_file("use-counters/buffer.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(buffer, state, inputs)
  {outputs, state} = Logex.Runtime.scan(buffer, state, 10)
  counts = "buffer.cv #{state.env["buffer"]["cv"]}  order.cv #{state.env["order"]["cv"]}"
  IO.puts("#{label}  #{counts}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(buffer)
|> scan.("start                ", %{})
|> scan.("new order of 2 boxes ", %{"new_order" => 1})
|> scan.("box 1 in             ", %{"new_order" => 0, "infeed" => 1})
|> scan.("infeed eye clear     ", %{"infeed" => 0})
|> scan.("box 2 in             ", %{"infeed" => 1})
|> scan.("box 2 stays on eye   ", %{})
|> scan.("infeed eye clear     ", %{"infeed" => 0})
|> scan.("box 3 in: full       ", %{"infeed" => 1})
|> scan.("box 1 out            ", %{"infeed" => 0, "outfeed" => 1})
|> scan.("outfeed eye clear    ", %{"outfeed" => 0})
|> scan.("box 2 out: order done", %{"outfeed" => 1})
