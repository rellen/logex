{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("instructions-bitwise/tags.txt")

rungs = [
  "and a_word 65536 d_word",
  "and a_word -1 d_word",
  "and a_word 2#1_0000_0000_0000_0000 d_word",
  "and a_sint 16#ff d_sint",
  "and a_bool 2 d_bool",
  "and a_word 1.5 d_word",
  "shl a_word -1 d_word",
  "shl a_word 1.0 d_word",
  "shl a_word 18446744073709551616 d_word"
]

report.(28, rungs, &Logex.compile(tags <> &1, name: "wrong"))
