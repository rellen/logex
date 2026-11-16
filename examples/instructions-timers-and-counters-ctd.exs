{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{
  "portion" => [0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0],
  "refill_pb" => [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
}

names = ["portion", "refill_pb", "hopper.cd", "hopper.ld", "hopper.cv", "hopper.q", "empty_lamp"]
scans.("instructions-timers-and-counters/hopper.ld", 10, inputs, names)
