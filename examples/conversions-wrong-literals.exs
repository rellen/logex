{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("conversions/tags.txt")

rungs = [
  "dint_to_int 5000000000 d_int",
  "dint_to_int 1.5 d_int",
  "word_to_int -1 d_int",
  "word_to_int 70000 d_int",
  "int_to_word 16#ffff d_word",
  "real_to_int 16777217 d_int",
  "real_to_int 1.0e39 d_int",
  "real_to_int 1.0e-40 d_int",
  "lreal_to_real 1.0e-310 d_real",
  "dint_to_int 5-3 d_int"
]

report.(51, rungs, &Logex.compile(tags <> &1, name: "wrong"))
