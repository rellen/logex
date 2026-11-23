{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt")

rungs = [
  "xic 1 ote lamp",
  "xic door ote lamp",
  "xic speed ote lamp",
  "xic delay ote lamp",
  "xic delay.DN ote lamp",
  "xic lamps ote lamp",
  "xic lamps[4] ote lamp",
  "xic status.16 ote lamp",
  "xic eye.0 ote lamp",
  "xic ote lamp",
  "xic eye ote",
  "xic eye ote lamp box_in"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong"))
