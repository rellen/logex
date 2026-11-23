%{
  title: "ctu: the eye counts 3 boxes, and reset_pb sets the count to 0",
  program: "boxes.ld",
  step: 10,
  scans: 12,
  inputs: %{
    "eye" => [{1, 1}, {2, 0}, {3, 1}, {5, 0}, {6, 1}, {7, 0}, {8, 1}, {11, 0}, {12, 1}],
    "reset_pb" => [{9, 1}, {10, 0}]
  },
  show: ["eye", "reset_pb", "count", "full_lamp"]
}
