{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{"motor" => [0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0]}

names = ["motor", "run_on.acc", "run_on.tt", "run_on.en", "run_on.dn", "fan"]
scans.("line.ld", 10, inputs, names)
