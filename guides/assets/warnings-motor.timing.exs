%{
  title: "2 ote instructions on motor: the second rung decides it",
  program: "warnings/motor.ld",
  step: 10,
  scans: 10,
  inputs: %{"start" => [{2, 1}, {8, 0}], "jog" => [{5, 1}, {10, 0}]},
  show: ["start", "jog", "motor"]
}
