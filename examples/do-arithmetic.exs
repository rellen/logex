{:ok, fill} = Logex.compile_file("do-arithmetic/fill.ld")
names = ["total", "total_ok", "overflow", "valve", "per_minute"]

scan = fn state, number, inputs ->
  state = Logex.Runtime.put_inputs(fill, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fill, state, 100)
  IO.puts("#{number}  " <> Enum.map_join(names, "  ", &"#{&1} #{outputs[&1]}"))
  for fault <- state.faults, do: IO.puts("   fault #{inspect(fault.kind)} at line #{fault.line}")
  state
end

Logex.Runtime.instance(fill)
|> scan.(1, %{"flow" => 400, "setpoint" => 1000})
|> scan.(2, %{"minutes" => 1})
|> scan.(3, %{"minutes" => 2})
|> scan.(4, %{"flow" => 2_147_483_000})
|> scan.(5, %{})
|> scan.(6, %{"flow" => -5})
|> scan.(7, %{"flow" => 0, "reset" => 1})
