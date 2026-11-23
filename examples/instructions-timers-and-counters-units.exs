text = fn type ->
  "var_input eye bool\nvar_output lamp bool\nvar t #{type}\n" <>
    "xic eye ton t 2000000\nxic t.dn ote lamp"
end

run = fn {type, unit} ->
  {:ok, program} = Logex.compile(text.(type), name: "units")
  state = Logex.Runtime.put_inputs(program, Logex.Runtime.instance(program), %{"eye" => 1})
  {_outputs, state} = Logex.Runtime.scan(program, state, 0)
  {early, state} = Logex.Runtime.scan(program, state, 2)
  {late, state} = Logex.Runtime.scan(program, state, 1_999_998)
  IO.puts("var t #{type}: t.pre is #{state.env["t"]["pre"]}, a time in #{unit}")
  IO.puts("  lamp is #{early["lamp"]} after 2 ms, and #{late["lamp"]} after 2000000 ms")
end

Enum.each([{"ton", "ms"}, {"ton_ltime", "ns"}], run)
