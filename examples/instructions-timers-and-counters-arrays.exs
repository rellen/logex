{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye ton lanes 100",
  "xic eye ton lanes[slot] 100",
  "xic eye ton lanes[4] 100",
  "xic eye ton lanes[1] 100\nxio eye ton lanes[01] 100",
  "xic eye ctd bins[1] 3"
]

report.(55, rungs, &Logex.compile(tags <> &1, name: "wrong"))
