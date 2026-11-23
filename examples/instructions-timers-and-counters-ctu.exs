{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{
  "eye" => [1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1],
  "reset_pb" => [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
}

names = ["eye", "reset_pb", "boxes.cu", "boxes.r", "boxes.cv", "boxes.q", "full_lamp"]
scans.("boxes.ld", 10, inputs, names)
