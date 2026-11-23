# The rows of 2 mnemonics in the table of the compiler.
IO.puts("ote  " <> inspect(Logex.Compiler.instructions()["ote"]))
IO.puts("abs  " <> inspect(Logex.Compiler.instructions()["abs"]))

{:ok, fan} = Logex.compile_file("adding-an-instruction/fan.ld")

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(fan, state, inputs)
  {outputs, state} = Logex.Runtime.scan(fan, state)
  IO.puts("#{label}  #{inspect(outputs)}")
  state
end

# A true rung, then a false rung.
Logex.Runtime.instance(fan)
|> scan.("run on ", %{"run" => 1, "error" => -40})
|> scan.("run off", %{"run" => 0, "error" => -75})

# A mnemonic is a reserved word, in each case of its letters.
{:error, [diagnostic]} = Logex.compile("var Abs dint\n", name: "fan")
IO.puts(Logex.Diagnostic.format(diagnostic))
