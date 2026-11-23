{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("jog.ld")

inputs = %{
  "manual" => [1, 1, 1, 0, 0, 0, 1, 1, 1, 1],
  "jog_pb" => [0, 1, 1, 1, 0, 0, 1, 1, 0, 0],
  "run_pb" => [0, 0, 0, 1, 1, 0, 0, 0, 0, 0]
}

names = ["manual", "jog_pb", "run_pb", "auto_lamp", "jog_lamp", "jog_t.acc", "jog_long", "motor"]
scans.(program, 500, inputs, names)
