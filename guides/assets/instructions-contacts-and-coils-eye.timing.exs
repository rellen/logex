%{
  title: "xic, xio, ote, otl and otu: 2 lamps and a latch on the eye of a conveyor",
  program: "instructions-contacts-and-coils/eye.ld",
  step: 10,
  scans: 8,
  inputs: %{"eye" => [{2, 1}, {3, 0}, {7, 1}], "reset_pb" => [{5, 1}, {6, 0}, {8, 1}]},
  show: ["eye", "reset_pb", "box_lamp", "clear_lamp", "box_seen"]
}
