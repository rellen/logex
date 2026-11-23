{:ok, packer} = Logex.compile_file("port-a-program/packer.ld")

scan = fn state, label, ms, inputs ->
  state = Logex.Runtime.put_inputs(packer, state, inputs)
  {outputs, state} = Logex.Runtime.scan(packer, state, ms)
  IO.puts("#{label}  #{inspect(outputs)}  boxes.cv=#{state.env["boxes"]["cv"]}")
  state
end

Logex.Runtime.instance(packer)
|> scan.("start, no reset", 0, %{"start_pb" => 1})
|> scan.("reset pressed  ", 10, %{"start_pb" => 0, "reset_pb" => 1})
|> scan.("start          ", 10, %{"start_pb" => 1, "reset_pb" => 0})
|> scan.("box on the eye ", 10, %{"start_pb" => 0, "eye" => 1})
|> scan.("box stays 5 s  ", 5000, %{})
|> scan.("box gone       ", 10, %{"eye" => 0})
|> then(&Logex.Runtime.restart(packer, &1, :warm))
|> scan.("warm restart   ", 10, %{"start_pb" => 1})
