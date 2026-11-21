%{
  title: "boxes wraps from 255 to 0 at the third box, and overflow latches",
  program: "types-and-overflow/boxes.ld",
  step: 100,
  scans: 9,
  inputs: %{
    "eye" => [{2, 1}, {3, 0}, {4, 1}, {5, 0}, {6, 1}, {7, 0}, {8, 1}, {9, 0}],
    "reset_pb" => [{9, 1}]
  },
  show: ["eye", "boxes", "count_ok", "overflow"]
}
