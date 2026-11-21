{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

rungs = [
  "add a_dint b_dint",
  "move a_dint",
  "sqrt a_real",
  "eq a_dint ote ok",
  "add a_dint b_dint d_dint 2",
  "add a_dint b_dint c_dint",
  "mov a_dint d_dint",
  "add a_dint 1 5",
  "add a_dint 1 a_dint",
  "move a_dint d_array",
  "add d_array 1 d_dint",
  "add delay 1 d_dint",
  "move a_dint delay",
  "move a_dint delay.dn",
  "move a_dint boxes.cv",
  "add a_dint.3 1 d_dint",
  "add a_dint 1 d_word.3"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong"))
