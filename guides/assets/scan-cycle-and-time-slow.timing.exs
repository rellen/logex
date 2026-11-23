%{
  title: "6 scans, 1 s apart: lamp comes on 3 s after go",
  program: "delay.ld",
  step: 1000,
  scans: 6,
  inputs: %{"go" => [{2, 1}]},
  show: ["go", "t1.acc", "lamp"]
}
