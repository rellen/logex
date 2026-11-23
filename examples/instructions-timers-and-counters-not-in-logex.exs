{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye res boxes",
  "xic eye ctud stock 3",
  "xic eye ton delay T#5s"
]

report.(60, rungs, &Logex.compile(tags <> &1, name: "wrong"))
