{:ok, fans} = Logex.compile_file("faults/fans.ld")

# Runs 1 scan, then prints the outputs and each fault of the scan.
scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(fans, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fans, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  for fault <- state.faults, do: IO.inspect(fault)
  state
end

Logex.Runtime.instance(fans)
|> scan.("1 in range ", %{"p_1" => 9.0, "auto" => 1, "fan" => 1, "ps" => [4.0, 16.0]})
|> scan.("2 p_1 -1.0 ", %{"p_1" => -1.0})
|> scan.("3 fan 2    ", %{"p_1" => 9.0, "fan" => 2})
|> scan.("4 auto 0   ", %{"auto" => 0})
