%{
  title: "cal s3 on a false rung: s3 and belt_3 keep their values",
  program: "belts.ld",
  step: 10,
  scans: 8,
  inputs: %{
    "start_1" => [{1, 1}, {2, 0}],
    "start_3" => [{2, 1}, {3, 0}],
    "auto" => [{1, 1}, {4, 0}, {7, 1}],
    "stop" => [{5, 1}, {6, 0}]
  },
  show: ["auto", "stop", "belt_1", "s3.stop", "s3.run", "belt_3"]
}
