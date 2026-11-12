{:ok, shift} = Logex.compile_file("shift.ld")

show = fn state, label ->
  env = state.env
  IO.puts("#{label}  boxes=#{env["boxes"]["cv"]} total=#{env["total"]} lube=#{env["lube"]["acc"]} last=#{env["last"]}")
  state
end

scan = fn state, label, inputs, ms ->
  state = Logex.Runtime.put_inputs(shift, state, inputs)
  {_outputs, state} = Logex.Runtime.scan(shift, state, ms)
  show.(state, label)
end

state =
  Logex.Runtime.instance(shift)
  |> scan.("motor on          ", %{"motor" => 1}, 0)
  |> scan.("box of 12 kg      ", %{"eye" => 1, "weight" => 12}, 10)
  |> scan.("eye clear         ", %{"eye" => 0}, 10)
  |> scan.("box of 15 kg      ", %{"eye" => 1, "weight" => 15}, 10)

state =
  Logex.Runtime.restart(shift, state, :warm)
  |> show.("warm restart      ")
  |> scan.("first scan, 10 ms ", %{}, 10)
  |> scan.("10 ms on          ", %{}, 10)
  |> scan.("eye clear         ", %{"eye" => 0}, 10)
  |> scan.("box of 9 kg       ", %{"eye" => 1, "weight" => 9}, 10)

image = Logex.Runtime.retained(shift, state)
IO.inspect(image)
Logex.Runtime.restart(shift, state, :cold) |> show.("cold restart      ")

{:ok, v2} = Logex.compile(String.replace(File.read!("shift.ld"), "total dint", "total lint"), name: "shift")
{fresh, dropped} = Logex.Runtime.instance(v2, image)
show.(fresh, "total made a lint ")
IO.inspect(dropped)
