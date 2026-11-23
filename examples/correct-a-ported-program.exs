report = fn
  file, {:ok, _program} -> "#{file} compiles"
  _file, {:error, diagnostics} -> Enum.map_join(diagnostics, "\n", &Logex.Diagnostic.format/1)
end

file = "port-a-program/packer.ld"
IO.puts(report.(file, Logex.compile_file(file)))
