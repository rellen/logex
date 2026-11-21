{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

rungs = [
  "eq a_word a_int ote ok",
  "eq a_real a_dint ote ok",
  "eq a_real a_word ote ok",
  "eq a_ulint a_real ote ok",
  "eq a_bool 1 ote ok",
  "eq delay.dn 1 ote ok",
  "eq delay 1 ote ok",
  "lt a_uint 70000 ote ok",
  "eq a_word -1 ote ok",
  "eq a_int 1.0 ote ok",
  "eq a_real 16777217 ote ok",
  "gt a_real 3.5e38 ote ok",
  "gt 1.0e-310 0.0 ote ok",
  "eq a_dint b_dint"
]

report.(53, rungs, &Logex.compile(tags <> &1, name: "wrong"))
