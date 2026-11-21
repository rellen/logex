%{
  title: "line.ld: the fan runs on, the horn sounds 1 pulse, lube adds up the running time",
  program: "line.ld",
  step: 10,
  scans: 14,
  inputs: %{
    "motor" => [{1, 1}, {3, 0}, {8, 1}],
    "fault" => [{1, 1}, {3, 0}, {5, 1}, {6, 0}, {7, 1}],
    "greased" => [{13, 1}, {14, 0}]
  },
  show: ["motor", "fan", "fault", "horn", "greased", "lube.acc", "grease_due"]
}
