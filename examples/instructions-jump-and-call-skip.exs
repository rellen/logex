{scans, _} = Code.eval_file("instructions-jump-and-call/scans.exs")
{:ok, program} = Logex.compile_file("instructions-jump-and-call/skip.ld")

inputs = %{
  "hold" => [0, 0, 1, 1, 1, 0, 0, 0],
  "eye" => [0, 1, 0, 1, 0, 1, 0, 1],
  "rate" => [4, 4, 0, 0, 0, 5, 0, 5]
}

names = ["hold", "eye", "rate", "lamp", "boxes.cv", "dwell.acc", "dwell.dn", "kick", "share"]
scans.(program, 100, inputs, names)
