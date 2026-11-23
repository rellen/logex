%{
  title: "tof: run_on.dn stays on for 30 ms after motor goes off",
  program: "line.ld",
  step: 10,
  scans: 17,
  inputs: %{"motor" => [{2, 1}, {4, 0}, {9, 1}, {10, 0}, {12, 1}, {13, 0}]},
  show: ["motor", "run_on.acc", "run_on.tt", "run_on.dn"]
}
