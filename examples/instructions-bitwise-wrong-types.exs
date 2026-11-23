{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-bitwise/tags.txt")

rungs = [
  "and a_word 16#00ff d_int",
  "or a_int 1 d_word",
  "xor a_dword 1 d_word",
  "not a_int d_word",
  "and a_dint 1 d_int",
  "and a_bool a_int d_int",
  "xor a_int 1 d_bool",
  "and a_word 1 d_bool",
  "and a_word.3 1 d_int",
  "and a_real 1 d_dint",
  "and a_word 1 d_real",
  "shl a_word n_word d_word",
  "shl a_word a_bool d_word",
  "shl a_word a_real d_word"
]

report.(14, rungs, &Logex.compile(tags <> &1, name: "wrong"))
