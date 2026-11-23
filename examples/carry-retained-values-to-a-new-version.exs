alias Logex.Runtime

{:ok, shift} = Logex.compile_file("shift.ld")
{:ok, new_shift} = Logex.compile_file("carry-retained-values-to-a-new-version/shift.ld")

scan = fn state, inputs ->
  state = Runtime.put_inputs(shift, state, inputs)
  {_outputs, state} = Runtime.scan(shift, state, 10)
  state
end

# The motor runs, and 2 boxes pass the eye.
state =
  Runtime.instance(shift)
  |> scan.(%{"motor" => 1})
  |> scan.(%{"eye" => 1, "weight" => 12})
  |> scan.(%{"eye" => 0})
  |> scan.(%{"eye" => 1, "weight" => 15})

image = Runtime.retained(shift, state)
IO.inspect(image)

{fresh, dropped} = Runtime.instance(new_shift, image)
IO.inspect(dropped)
env = fresh.env
counter = env["boxes"]
lube = env["lube"]["acc"]
IO.puts("boxes=#{counter["cv"]}  pv=#{counter["pv"]}  total=#{env["total"]}  lube=#{lube}")
