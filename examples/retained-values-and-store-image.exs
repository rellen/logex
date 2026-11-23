{:ok, shift} = Logex.compile_file("shift.ld")

# 2 boxes, 12 kg and 15 kg, while the motor runs.
state =
  Enum.reduce(
    [
      %{"motor" => 1},
      %{"eye" => 1, "weight" => 12},
      %{"eye" => 0},
      %{"eye" => 1, "weight" => 15}
    ],
    Logex.Runtime.instance(shift),
    fn inputs, state ->
      state = Logex.Runtime.put_inputs(shift, state, inputs)
      {_outputs, state} = Logex.Runtime.scan(shift, state, 10)
      state
    end
  )

image = Logex.Runtime.retained(shift, state)

# A new version: total is a lint, the counter counts to 500, lube keeps no time.
text =
  File.read!("shift.ld")
  |> String.replace("total dint", "total lint")
  |> String.replace("ctu boxes 1000", "ctu boxes 500")
  |> String.replace("var retain lube rto", "var lube rto")

{:ok, v2} = Logex.compile(text, name: "shift")
{fresh, dropped} = Logex.Runtime.instance(v2, image)
Enum.each(dropped, &IO.inspect/1)
env = fresh.env

IO.puts(
  "boxes.cv=#{env["boxes"]["cv"]} boxes.pv=#{env["boxes"]["pv"]} total=#{env["total"]} lube.acc=#{env["lube"]["acc"]}"
)
