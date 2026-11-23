%{
  title: "tp: horn_pulse.tt is a pulse of 30 ms when fault comes on",
  program: "line.ld",
  step: 10,
  scans: 14,
  inputs: %{"fault" => [{1, 1}, {3, 0}, {4, 1}, {5, 0}, {6, 1}, {9, 0}, {10, 1}, {11, 0}]},
  show: ["fault", "horn_pulse.acc", "horn_pulse.tt", "horn_pulse.dn"]
}
