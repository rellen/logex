{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye ton",
  "xic eye ton delay",
  "xic eye ton 100",
  "xic eye ton delay 100 200",
  "xic eye ton oven 100",
  "xic eye ton speed 100",
  "xic eye ton delay.pre 100",
  "xic eye ton run_on 100",
  "xic eye tof cure 100",
  "xic eye ctu delay 3",
  "xic eye ctd boxes 3",
  "xic eye ctu hopper 3",
  "xic eye ctd cases 3"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong"))
