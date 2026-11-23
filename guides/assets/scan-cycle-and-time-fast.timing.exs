%{
  title: "12 scans, 500 ms apart: lamp comes on 3 s after go",
  program: "delay.ld",
  step: 500,
  scans: 12,
  inputs: %{"go" => [{4, 1}]},
  show: ["go", "t1.acc", "lamp"]
}
