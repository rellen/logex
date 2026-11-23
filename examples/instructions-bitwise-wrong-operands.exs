{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-bitwise/tags.txt")

rungs = [
  "and a_word b_word",
  "not a_word",
  "shl a_word 1",
  "and a_word 1 5",
  "and a_word 1 a_word",
  "and a_word 1 d_array",
  "and d_array 1 d_word",
  "and delay 1 d_word",
  "not a_word boxes",
  "and a_bool 1 delay.dn",
  "and a_dint 1 boxes.cv",
  "xnor a_word b_word d_word",
  "xic go ton delay 5 and a_word 1 d_word"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong"))
