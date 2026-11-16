%{
  title: "ctd: hopper.cv goes down by 1 when portion comes on",
  program: "instructions-timers-and-counters/hopper.ld",
  step: 10,
  scans: 13,
  inputs: %{
    "portion" => [{4, 1}, {5, 0}, {6, 1}, {8, 0}, {9, 1}, {10, 0}, {11, 1}, {12, 0}],
    "refill_pb" => [{2, 1}, {3, 0}, {12, 1}, {13, 0}]
  },
  show: ["portion", "refill_pb", "hopper.cv", "hopper.q"]
}
