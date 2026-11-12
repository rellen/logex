{:ok, stock} = Logex.compile_file("stock.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(stock, state, inputs)
  {outputs, state} = Logex.Runtime.scan(stock, state, 10)
  IO.puts("#{label}  cv #{state.env["stock"]["cv"]}  #{inspect(outputs)}")
  state
end

state = Logex.Runtime.instance(stock)
{_, state} = Logex.Runtime.scan(stock, state, 10)
# A stock of 32766, one short of an int's top, as a run of boxes leaves it.
state = put_in(state.env["stock"]["cv"], 32_766)

state
|> scan.("box in          ", %{"infeed" => 1})
|> scan.("eye clear       ", %{"infeed" => 0})
|> scan.("box in, at 32767", %{"infeed" => 1})
|> scan.("eye clear       ", %{"infeed" => 0})
|> scan.("box out         ", %{"outfeed" => 1})

IO.puts(inspect(stock.tags["cases"].type == Logex.FbType.ctu()))

{:error, [mistake]} =
  Logex.compile("var e bool\nvar stock ctud_int\nxic e ctu stock 40000\n", name: "m")

IO.puts(Logex.Diagnostic.format(mistake))
