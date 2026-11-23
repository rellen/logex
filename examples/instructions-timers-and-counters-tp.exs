{scans, _} = Code.eval_file("instructions-timers-and-counters/scans.exs")

inputs = %{"fault" => [1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]}

names = ["fault", "horn_pulse.acc", "horn_pulse.tt", "horn_pulse.en", "horn_pulse.dn", "horn"]
scans.("line.ld", 10, inputs, names)
