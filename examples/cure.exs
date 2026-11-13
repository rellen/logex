{:ok, cure} = Logex.compile_file("cure.ld")

scan = fn state, label, ms, inputs ->
  state = Logex.Runtime.put_inputs(cure, state, inputs)
  {outputs, state} = Logex.Runtime.scan(cure, state, ms)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

hour = 3_600_000

Logex.Runtime.instance(cure)
|> scan.("door shut          ", 0, %{"door_shut" => 1})
|> scan.("1 h on             ", hour, %{})
|> scan.("36 h less 1 ms on  ", 35 * hour - 1, %{})
|> scan.("36 h on: cured     ", 1, %{})
|> scan.("door opened        ", 10, %{"door_shut" => 0})
|> scan.("60 s later         ", 60_000, %{})
|> scan.("90 s later: fan off", 30_000, %{})

{:ok, short} =
  Logex.compile(
    File.read!("cure.ld")
    |> String.replace("90000000000", "1500000")
    |> String.replace("xic cure.dn ote cured", "ge cure.acc 3000 ote cured"),
    name: "short"
  )

Enum.each(short.warnings, &IO.puts(Logex.Diagnostic.format(&1)))
