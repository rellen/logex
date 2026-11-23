{scans, _} = Code.eval_file("instructions-arithmetic-and-comparison/scans.exs")

inputs = %{"boxes" => [25, 25, 25, 25, 25, 25, 25, 25, -40, -40]}

names = ["boxes", "total", "fits", "wrapped"]
scans.("instructions-arithmetic-and-comparison/belt_total.ld", inputs, names)
