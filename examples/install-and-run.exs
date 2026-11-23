run = fn
  {:ok, program} ->
    Enum.each(program.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
    state = Logex.Runtime.instance(program)
    state = Logex.Runtime.put_inputs(program, state, %{"start" => 1})
    {outputs, _state} = Logex.Runtime.scan(program, state)
    IO.puts("#{program.name} compiles")
    IO.inspect(outputs, label: "outputs of scan 1")

  {:error, diagnostics} ->
    Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
end

run.(Logex.compile_file("motor.ld"))
