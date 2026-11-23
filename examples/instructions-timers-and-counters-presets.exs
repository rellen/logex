{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye ton delay wait_ms",
  "xic eye ctu boxes slot",
  "xic eye ton delay run_on",
  "xic eye ton delay -1",
  "xic eye ton delay 2147483648",
  "xic eye ton delay 1.5",
  "xic eye ton cure 9223372036854775808",
  "xic eye ctu boxes 2147483648",
  "xic eye ctu cases 40000",
  "xic eye ctd parts -1"
]

report.(14, rungs, &Logex.compile(tags <> &1, name: "wrong"))
