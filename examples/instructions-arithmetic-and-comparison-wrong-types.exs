{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

rungs = [
  "move a_dint d_uint",
  "move a_lreal d_real",
  "move a_bool d_dint",
  "move a_word d_dint",
  "move a_dint d_word",
  "add a_dint 1 d_uint",
  "add a_sint a_usint d_sint",
  "add a_dint a_real d_real",
  "add a_word 1 d_uint",
  "add a_uint 1 d_word",
  "add a_bool 1 d_dint",
  "add a_dint 1 d_bool",
  "mod a_real 2 d_dint",
  "mod a_dint 2 d_real",
  "neg a_dint d_uint",
  "neg a_ulint d_ulint",
  "neg a_word d_dint",
  "sqrt a_real d_dint",
  "sqrt a_lreal d_real",
  "sqrt a_dint d_real"
]

report.(18, rungs, &Logex.compile(tags <> &1, name: "wrong"))
