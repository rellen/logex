{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("function-blocks/fan_panel.ld")

inputs = %{
  "motor_1" => [1, 1, 0, 0, 0, 0, 0, 0, 0],
  "motor_2" => [0, 0, 0, 0, 0, 0, 0, 0, 0]
}

names = ["motor_1", "fan_1", "f1.motor", "f1.fan", "f1.run_on.tt", "f1.run_on.acc", "fan_2"]
scans.(program, 1000, inputs, names)
