{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt")

rungs = [
  "xic eye osr s1",
  "xic eye osr s1 s1",
  "xic eye osr s1 eye",
  "xic eye osf s1 delay.dn",
  "xic eye osr s1 status.[slot]",
  "xic eye osf s1 lamps[slot]"
]

report.(34, rungs, &Logex.compile(tags <> &1, name: "wrong"))
