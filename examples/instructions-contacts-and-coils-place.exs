{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-contacts-and-coils/tags.txt")

rungs = [
  "xic eye xio lamp",
  "xic eye ton delay 100 ote lamp",
  "( xic eye ton delay 100 | xic eye ) ote lamp",
  "xic eye ctu boxes 5 ons s1 ote lamp"
]

report.(13, rungs, &Logex.compile(tags <> &1, name: "wrong"))
