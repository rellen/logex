{:ok, line} = Logex.compile_file("line.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(line, state, inputs)
  {outputs, state} = Logex.Runtime.scan(line, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(line)
|> scan.("fault at start, motor on", %{"fault" => 1, "motor" => 1})
|> scan.("motor runs              ", %{})
|> scan.("motor stops, fault clear", %{"motor" => 0, "fault" => 0})
|> scan.("run-on                  ", %{})
|> scan.("fault                   ", %{"fault" => 1})
|> scan.("run-on over, fault clear", %{"fault" => 0})
|> scan.("fault again, ignored    ", %{"fault" => 1})
|> scan.("pulse over, motor on    ", %{"motor" => 1})
|> scan.("motor runs              ", %{})
|> scan.("motor runs              ", %{})
|> scan.("motor runs              ", %{})
|> scan.("motor runs: greasing due", %{})
|> scan.("greased                 ", %{"greased" => 1})
|> scan.("greased let go          ", %{"greased" => 0})
