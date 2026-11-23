{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye ton delay 100\nxio eye ton delay 100",
  "xic eye ( ton delay 100 | ton delay 100 )",
  "xic eye ctu boxes 3\nxio eye ctu boxes 3",
  "xic eye ctu stock 3\nxio eye ctd stock 4",
  "xic eye ctu stock 3\nxio eye ctd stock 3\nxic eye ctu stock 3",
  "xic eye cal delay"
]

report.(24, rungs, &Logex.compile(tags <> &1, name: "wrong"))
