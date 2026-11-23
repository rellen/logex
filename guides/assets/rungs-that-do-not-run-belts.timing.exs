%{
  title: "The cal of belt 3 has no power from scan 4 to scan 6",
  program: "belts.ld",
  step: 100,
  scans: 8,
  inputs: %{
    "start_1" => [{1, 1}, {2, 0}],
    "start_3" => [{1, 1}, {2, 0}],
    "auto" => [{1, 1}, {4, 0}, {7, 1}],
    "stop" => [{4, 1}]
  },
  show: ["auto", "stop", "belt_1", "belt_3"]
}
