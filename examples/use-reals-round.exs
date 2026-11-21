{:ok, round} = Logex.compile_file("use-reals/round.ld")

for x <- [2.3, 2.0, -2.3, 0.7, -0.7] do
  state = Logex.Runtime.put_inputs(round, Logex.Runtime.instance(round), %{"x" => x})
  {outputs, _state} = Logex.Runtime.scan(round, state)
  IO.puts("x #{x}  up #{outputs["up"]}  down #{outputs["down"]}")
end
