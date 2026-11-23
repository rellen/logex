{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

rungs = [
  "xic go ton delay 100 add a_dint b_dint d_dint",
  "xic go ctu boxes 5 eq a_dint b_dint ote ok"
]

report.(67, rungs, &Logex.compile(tags <> &1, name: "wrong"))
