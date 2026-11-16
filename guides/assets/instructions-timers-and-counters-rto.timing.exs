%{
  title: "rto: lube.acc adds the time that motor is on, until greased resets it",
  program: "line.ld",
  step: 10,
  scans: 16,
  inputs: %{"motor" => [{2, 1}, {4, 0}, {6, 1}, {15, 0}], "greased" => [{11, 1}, {13, 0}]},
  show: ["motor", "greased", "lube.acc", "lube.tt", "lube.dn"]
}
