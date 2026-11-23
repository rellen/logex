%{
  title: "conveyors.ld, 8 scans of 1 s",
  program: "write-a-function-block/conveyors.ld",
  step: 1000,
  scans: 8,
  inputs: %{
    "start_1" => [{1, 1}, {2, 0}],
    "start_2" => [{2, 1}, {3, 0}],
    "eye_2" => [{3, 1}, {6, 0}],
    "stop" => [{7, 1}, {8, 0}]
  },
  show: ["start_1", "start_2", "stop", "eye_2", "c2.jam_t.acc", "belt_1", "belt_2", "jam_lamp"]
}
