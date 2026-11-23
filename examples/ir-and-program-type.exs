{:ok, fan} = Logex.compile_file("ir-and-program-type/fan.ld")

# Each instruction of the IR: its symbol and line, then each operand.
for {symbol, line, operands} <- Logex.Walk.instructions(fan.rungs) do
  IO.puts("line #{line}: #{symbol}")
  Enum.each(operands, fn operand -> IO.puts("  " <> inspect(operand)) end)
end

# The facts that the compiler settles once for the scan.
IO.puts("t1 initial: " <> inspect(fan.tags["t1"].initial))
IO.puts("reals:      " <> inspect(fan.reals))
IO.puts("arrays:     " <> inspect(fan.arrays))
IO.puts("units:      " <> inspect(fan.units))
