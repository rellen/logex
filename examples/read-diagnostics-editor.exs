{:error, diagnostics} = Logex.Configuration.compile_file("broken.logex")

editor = fn d ->
  place = Enum.join(Enum.reject([d.file, d.line, d.column], &is_nil/1), ":")
  IO.puts("#{place}: #{d.severity}: #{d.message}")
end

Enum.each(diagnostics, editor)
