{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("belts.ld")

inputs = %{
  "start_1" => [1, 0, 0, 0, 0, 0],
  "start_2" => [0, 1, 0, 0, 0, 0],
  "start_3" => [0, 1, 0, 0, 0, 0],
  "stop" => [0, 0, 0, 1, 1, 0],
  "auto" => [1, 1, 1, 0, 1, 1]
}

names = ["start_3", "stop", "auto", "belt_1", "belt_2", "belt_3", "s3.start", "s3.stop", "s3.run"]
scans.(program, 10, inputs, names)
