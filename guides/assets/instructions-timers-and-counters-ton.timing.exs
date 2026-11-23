%{
  title: "ton: t1.dn comes on when go stays on for 3 s",
  program: "delay.ld",
  step: 500,
  scans: 14,
  inputs: %{"go" => [{2, 1}, {5, 0}, {6, 1}, {13, 0}]},
  show: ["go", "t1.acc", "t1.tt", "t1.dn"]
}
