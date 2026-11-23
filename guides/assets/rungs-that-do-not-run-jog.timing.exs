%{
  title: "A jump passes the manual rungs from scan 5 to scan 8",
  program: "jog.ld",
  step: 500,
  scans: 12,
  inputs: %{
    "manual" => [{1, 1}, {5, 0}, {9, 1}],
    "jog_pb" => [{2, 1}, {6, 0}, {9, 1}, {11, 0}]
  },
  show: ["manual", "jog_pb", "jog_lamp", "jog_t.acc", "jog_long"]
}
