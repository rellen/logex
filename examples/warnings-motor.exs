{:ok, motor} = Logex.compile_file("warnings/motor.ld")
Enum.each(motor.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
