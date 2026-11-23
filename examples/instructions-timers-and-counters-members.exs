{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic delay ote lamp",
  "xic delay.done ote lamp",
  "xic delay.DN ote lamp",
  "xic delay.r ote lamp",
  "xic boxes.cv ote lamp",
  "xic stock.q ote lamp",
  "xic delay.dn.0 ote lamp",
  "xic eye ote delay.dn",
  "xic eye ote lube.dn",
  "xic eye ote boxes.q",
  "xic eye move 0 boxes.cv",
  "xic eye ote boxes.cv.3",
  "xic eye ote hopper.r",
  "xic eye ote stock.qu",
  "xic eye move 5.5 delay.pre",
  "xic eye move 40000 cases.pv",
  "move cure.acc speed"
]

report.(38, rungs, &Logex.compile(tags <> &1, name: "wrong"))
