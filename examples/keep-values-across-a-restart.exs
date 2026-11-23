alias Logex.Runtime

{:ok, shift} = Logex.compile_file("shift.ld")

show = fn state, label ->
  env = state.env
  boxes = env["boxes"]["cv"]
  lube = env["lube"]["acc"]
  IO.puts("#{label}  boxes=#{boxes}  total=#{env["total"]}  lube=#{lube}  last=#{env["last"]}")
  state
end

# Each scan is 10 ms after the last. The host gives that time.
scan = fn state, inputs ->
  state = Runtime.put_inputs(shift, state, inputs)
  {_outputs, state} = Runtime.scan(shift, state, 10)
  state
end

# The motor runs, and 2 boxes pass the eye. The second box stays at the eye.
state =
  Runtime.instance(shift)
  |> scan.(%{"motor" => 1})
  |> scan.(%{"eye" => 1, "weight" => 12})
  |> scan.(%{"eye" => 0})
  |> scan.(%{"eye" => 1, "weight" => 15})
  |> show.("2 boxes     ")

Runtime.restart(shift, state, :warm)
|> show.("warm restart")
|> scan.(%{})
|> show.("first scan  ")

Runtime.restart(shift, state, :cold)
|> show.("cold restart")
|> scan.(%{})
|> show.("first scan  ")
