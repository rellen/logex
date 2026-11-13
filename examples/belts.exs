{:ok, belts} = Logex.compile_file("belts.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(belts, state, inputs)
  {outputs, state} = Logex.Runtime.scan(belts, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}  s3=#{inspect(state.env["s3"])}")
  state
end

Logex.Runtime.instance(belts)
|> scan.("start 1, auto  ", %{"start_1" => 1, "auto" => 1})
|> scan.("start 2 and 3  ", %{"start_1" => 0, "start_2" => 1, "start_3" => 1})
|> scan.("released       ", %{"start_2" => 0, "start_3" => 0})
|> scan.("auto off, stop ", %{"auto" => 0, "stop" => 1})
|> scan.("auto on        ", %{"auto" => 1})
