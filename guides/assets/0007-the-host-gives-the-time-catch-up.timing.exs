%{
  title: "jog.ld: jog_t catches up after the jump skips its rung",
  program: "jog.ld",
  step: 1000,
  scans: 12,
  inputs: %{"manual" => [{1, 1}, {3, 0}, {9, 1}], "jog_pb" => [{1, 1}]},
  show: ["manual", "jog_pb", "auto_lamp", "jog_t.acc", "jog_long"]
}
