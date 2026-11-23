{scans, _} = Code.eval_file("instructions-arithmetic-and-comparison/scans.exs")

inputs = %{
  "flow" => [400, 400, 400, 2_147_483_000, 2_147_483_000, -5],
  "setpoint" => [1000, 1000, 1000, 1000, 1000, 1000],
  "minutes" => [0, 1, 2, 2, 2, 2]
}

names = ["flow", "minutes", "total", "total_ok", "overflow", "full", "valve", "per_minute"]
scans.("fill.ld", inputs, names)
