{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-arithmetic-and-comparison/tags.txt")

rungs = [
  "move 70000 d_uint",
  "add 70000 1 d_uint",
  "move -1 d_word",
  "move 1.5 d_dint",
  "move 2 d_bool",
  "move 16777217 d_real",
  "move 3.5e38 d_real",
  "move 1.0e-40 d_real",
  "div a_dint 0 d_dint",
  "mod a_dint 16#0 d_dint",
  "div a_real 0.0 d_real",
  "sqrt -4.0 d_real",
  "sqrt -4 d_real",
  "move 5-3 d_dint",
  "move 16#ffff d_int"
]

report.(38, rungs, &Logex.compile(tags <> &1, name: "wrong"))
