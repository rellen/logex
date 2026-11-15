report = fn
  {:ok, _program} -> "motor.ld compiles"
  {:error, diagnostics} -> Enum.map_join(diagnostics, "\n", &Logex.Diagnostic.format/1)
end

IO.puts(report.(Logex.compile_file("motor.ld")))
