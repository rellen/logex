{:ok, step} = Logex.compile_file("step.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(step, state, inputs)
  {outputs, state} = Logex.Runtime.scan(step, state, 10)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

Logex.Runtime.instance(step)
|> scan.("start held at start", %{"start_pb" => 1})
|> scan.("start released     ", %{"start_pb" => 0})
|> scan.("start pressed      ", %{"start_pb" => 1})
|> scan.("still held         ", %{})
|> scan.("box on the eye     ", %{"eye" => 1})
|> scan.("start released     ", %{"start_pb" => 0})
|> scan.("box left the eye   ", %{"eye" => 0})
|> scan.("start pressed      ", %{"start_pb" => 1})
|> scan.("nothing new        ", %{})

{:error, [diagnostic]} =
  Logex.compile("var_input start_pb bool\nvar s1 bool\nxic start_pb osr s1 s1", name: "same")

IO.puts(Logex.Diagnostic.format(diagnostic))
