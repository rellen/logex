{:ok, belts} = Logex.compile_file("check-a-ported-program/belts.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(belts, state, inputs)
  {outputs, state} = Logex.Runtime.scan(belts, state)
  IO.puts(label)
  IO.puts("    #{inspect(outputs)}")

  for fault <- state.faults do
    IO.puts("    #{fault.severity} fault #{fault.kind}: line #{fault.line}, #{fault.instruction}")
  end

  state
end

Logex.Runtime.instance(belts)
|> scan.("1000 + 2000 boxes, slot 2", %{"belt_1" => 1000, "belt_2" => 2000, "slot" => 2})
|> scan.("30000 + 30000 boxes, slot 2", %{"belt_1" => 30000, "belt_2" => 30000})
|> scan.("slot 8", %{"slot" => 8})
