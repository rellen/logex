{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{"go" => [0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0]}

scans.("delay.ld", 500, inputs, ["go", "t1.acc", "t1.tt", "t1.en", "t1.dn", "lamp"])
