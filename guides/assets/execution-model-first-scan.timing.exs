%{
  title: "The first scan: the box on the eye at the start is not counted",
  program: "execution-model/boxes.ld",
  step: 10,
  scans: 8,
  inputs: %{"eye" => [{1, 1}, {3, 0}, {4, 1}, {6, 0}, {7, 1}]},
  show: ["eye", "boxes.cv", "pulse", "first_out"]
}
