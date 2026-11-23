{:ok, motor} = Logex.compile_file("motor.ld")

# Rung 1 of the program type.
[{:rung, rung_1} | _] = motor.rungs
IO.puts("rung 1 of #{motor.name}:")
IO.inspect(rung_1, width: 70)
