{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{
  "motor" => [0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
  "greased" => [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0]
}

names = ["motor", "greased", "lube.r", "lube.acc", "lube.tt", "lube.en", "lube.dn", "grease_due"]
scans.("line.ld", 10, inputs, names)
