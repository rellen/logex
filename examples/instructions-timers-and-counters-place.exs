{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-timers-and-counters/tags.txt")

rungs = [
  "xic eye ton delay 100 ote lamp",
  "xic eye tof run_on 100 ote lamp",
  "xic eye tp horn_pulse 100 ote lamp",
  "xic eye rto lube 100 ote lamp",
  "xic eye ctu boxes 3 ote lamp",
  "xic eye ctd hopper 3 ote lamp",
  "( xic eye ton delay 100 | xic eye ) ote lamp",
  "( xic eye ton delay 100 | xic eye ) ( ote lamp | ote speed.0 )"
]

report.(30, rungs, &Logex.compile(tags <> &1, name: "wrong"))
