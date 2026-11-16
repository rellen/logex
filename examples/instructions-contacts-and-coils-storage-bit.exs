{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt")

rungs = [
  "xic eye ons eye ote lamp",
  "xic eye ons status.[slot] ote lamp",
  "xic eye ons lamps[slot] ote lamp",
  "xic eye ons boxes.r ote lamp",
  "xic eye ons delay.acc.1 ote lamp",
  "xic eye ons s1 ote lamp\nxio eye ons s1 ote box_in",
  "xic eye ons s1 ons s1 ote lamp",
  "xic eye ons s1 ote lamp\nxio eye osf s1 box_in"
]

report.(26, rungs, &Logex.compile(tags <> &1, name: "wrong"))
