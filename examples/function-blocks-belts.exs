{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("belts.ld")

inputs = %{
  "start_1" => [1, 0, 0, 0, 0, 0, 0, 0],
  "start_3" => [0, 1, 0, 0, 0, 0, 0, 0],
  "auto" => [1, 1, 1, 0, 0, 0, 1, 1],
  "stop" => [0, 0, 0, 0, 1, 0, 0, 0]
}

scans.(program, 10, inputs, ["auto", "stop", "belt_1", "s3.stop", "s3.run", "belt_3"])
