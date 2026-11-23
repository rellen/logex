report = fn
  {:ok, plant} -> Enum.map_join(plant.globals, "\n", &"#{&1.at}  #{&1.name}")
  {:error, diagnostics} -> Enum.map_join(diagnostics, "\n", &Logex.Diagnostic.format/1)
end

IO.puts(report.(Logex.Configuration.compile_file("packing.logex")))
