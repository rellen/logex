{:ok, plant} = Logex.Configuration.compile_file("plant.logex")

print = fn
  nil, _now, _outputs, _events -> :ok
  label, now, out, events -> IO.puts("t=#{String.pad_leading("#{now}", 2)}  #{label}  k1=#{out["k1"]} k2=#{out["k2"]}  #{inspect(events)}")
end

cycle = fn {rt, now}, elapsed, inputs, label ->
  {rt, outputs, events} = Logex.Runtime.cycle(rt, elapsed, inputs)
  print.(label, now + elapsed, outputs, events)
  {rt, now + elapsed}
end

{Logex.Runtime.start(plant), 0}
|> cycle.(0, %{}, "idle         ")
|> cycle.(10, %{"pb_start_1" => 1, "pb_start_2" => 1}, "both started ")
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, nil)
|> cycle.(10, %{}, "held to 50 ms")
|> cycle.(10, %{"pb_start_1" => 0, "pb_start_2" => 0}, "released     ")

{:error, diagnostics} = Logex.Configuration.compile_file("broken.logex")
Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))
