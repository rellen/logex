{:ok, jog} = Logex.compile_file("jog.ld")

scan = fn state, elapsed, label, inputs ->
  state = Logex.Runtime.put_inputs(jog, state, inputs)
  {outputs, state} = Logex.Runtime.scan(jog, state, elapsed)
  acc = state.env["jog_t"]["acc"]
  IO.puts("t=#{String.pad_leading("#{state.now}", 4)}  #{label}  #{inspect(outputs)}  acc=#{acc}")
  state
end

Logex.Runtime.instance(jog)
|> scan.(0, "auto, run on       ", %{"run_pb" => 1})
|> scan.(100, "manual             ", %{"manual" => 1})
|> scan.(100, "jog pressed        ", %{"jog_pb" => 1})
|> scan.(1000, "jog held           ", %{})
|> scan.(100, "auto, jog held     ", %{"manual" => 0})
|> scan.(100, "jog let go in auto ", %{"jog_pb" => 0})
|> scan.(2000, "auto               ", %{})
|> scan.(100, "manual, jog pressed", %{"manual" => 1, "jog_pb" => 1})
|> scan.(100, "jog let go         ", %{"jog_pb" => 0})

{:error, [diagnostic]} =
  Logex.compile("var_input a bool\nvar_output b bool\nlbl top xic a ote b\nxic a jmp top",
    name: "loop"
  )

IO.puts(Logex.Diagnostic.format(diagnostic))
