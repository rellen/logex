{:ok, panel} = Logex.compile_file("use-bit-strings/lamps.ld")

scan = fn state, inputs ->
  state = Logex.Runtime.put_inputs(panel, state, inputs)
  {outputs, state} = Logex.Runtime.scan(panel, state)
  lamps = String.pad_leading(Integer.to_string(outputs["lamps"], 2), 16, "0")
  IO.puts("sel #{inputs["sel"]}  go #{inputs["go"]}  lamps 2##{lamps}  faults #{length(state.faults)}")
  state
end

Logex.Runtime.instance(panel)
|> scan.(%{"sel" => 3, "go" => 1})
|> scan.(%{"sel" => 5, "go" => 1})
|> scan.(%{"sel" => 5, "go" => 0})
|> scan.(%{"sel" => 16, "go" => 1})
