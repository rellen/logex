%{
  title: "fill.ld: the total wraps in scan 4",
  program: "do-arithmetic/fill.ld",
  step: 100,
  scans: 7,
  inputs: %{
    "flow" => [{1, 400}, {4, 2_147_483_000}, {6, -5}, {7, 0}],
    "setpoint" => [{1, 1000}],
    "minutes" => [{2, 1}, {3, 2}],
    "reset" => [{7, 1}]
  },
  show: ["total_ok", "overflow", "full", "valve", "reset"]
}
