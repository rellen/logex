%{
  title: "jog.ld, 12 scans",
  program: "jump-over-rungs/jog.ld",
  step: 500,
  scans: 12,
  inputs: %{
    "run_pb" => [{1, 1}, {2, 0}],
    "manual" => [{2, 1}, {5, 0}, {9, 1}, {10, 0}, {12, 1}],
    "jog_pb" => [{3, 1}, {6, 0}, {9, 1}, {11, 0}]
  },
  show: ["manual", "jog_pb", "auto_lamp", "jog_lamp", "jog_t.acc", "jog_long", "motor"]
}
