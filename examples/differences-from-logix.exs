{:ok, scales} = Logex.compile_file("scales.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(scales, state, inputs)
  {outputs, state} = Logex.Runtime.scan(scales, state)
  IO.puts("#{label}  #{inspect(outputs)}")

  for fault <- state.faults do
    IO.puts("    #{fault.severity} fault #{fault.kind}: line #{fault.line}, #{fault.instruction}")
  end

  state
end

Logex.Runtime.instance(scales)
|> scan.("no box, slot 2    ", %{"slot" => 2})
|> scan.("box of 620, slot 2", %{"eye" => 1, "weight" => 620})
|> scan.("slot 8            ", %{"slot" => 8})
|> scan.("slot 2            ", %{"slot" => 2})
