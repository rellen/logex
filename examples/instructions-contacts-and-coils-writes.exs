{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt")

rungs = [
  "xic eye ote eye",
  "xic eye otl speed",
  "xic eye ote delay.dn",
  "xic eye otu boxes.q"
]

report.(17, rungs, &Logex.compile(tags <> &1, name: "wrong"))
