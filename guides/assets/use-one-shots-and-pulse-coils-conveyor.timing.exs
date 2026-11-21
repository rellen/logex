%{
  title: "conveyor.ld: no pulse in scan 1, then 1 pulse for each edge",
  program: "use-one-shots-and-pulse-coils/conveyor.ld",
  step: 10,
  scans: 9,
  inputs: %{
    "index_pb" => [{1, 1}, {2, 0}, {3, 1}, {8, 0}, {9, 1}],
    "eye" => [{1, 1}, {5, 0}, {6, 1}, {8, 0}]
  },
  show: ["index_pb", "index", "held_lamp", "position", "eye", "boxes", "box_left"]
}
