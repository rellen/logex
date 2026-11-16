%{
  title: "ctud: infeed counts stock.cv up, and outfeed counts it down",
  program: "instructions-timers-and-counters/buffer.ld",
  step: 10,
  scans: 13,
  inputs: %{
    "infeed" => [
      {2, 1},
      {3, 0},
      {4, 1},
      {5, 0},
      {7, 1},
      {8, 0},
      {9, 1},
      {10, 0},
      {11, 1},
      {12, 0}
    ],
    "outfeed" => [{5, 1}, {6, 0}, {7, 1}, {8, 0}],
    "clear_pb" => [{12, 1}, {13, 0}]
  },
  show: ["infeed", "outfeed", "clear_pb", "stock.cv", "stock.qu", "stock.qd"]
}
