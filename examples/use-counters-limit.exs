{:ok, limit} = Logex.compile_file("use-counters/limit.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(limit, state, inputs)
  {outputs, state} = Logex.Runtime.scan(limit, state, 10)
  IO.puts("#{label}  stock.cv #{state.env["stock"]["cv"]}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(limit)
|> scan.("load        ", %{"refill" => 1})
|> scan.("box in      ", %{"refill" => 0, "infeed" => 1})
|> scan.("eye clear   ", %{"infeed" => 0})
|> scan.("box in      ", %{"infeed" => 1})
|> scan.("eye clear   ", %{"infeed" => 0})
|> scan.("box out     ", %{"outfeed" => 1})
|> scan.("load again  ", %{"outfeed" => 0, "refill" => 1})
