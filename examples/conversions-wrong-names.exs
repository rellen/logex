{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("conversions/tags.txt")

rungs = [
  "dint_to_dint a_dint d_dint",
  "real_to_real a_real d_real",
  "bool_to_int a_bool d_int",
  "int_to_bool a_int d_bool",
  "bool_to_word a_bool d_word",
  "word_to_bool a_word d_bool",
  "dword_to_real a_dword d_real",
  "real_to_dword a_real d_dword",
  "int_to_bcd a_int d_word",
  "bcd_to_int a_word d_int",
  "real_trunc_real a_real d_real",
  "real_trunc_word a_real d_word",
  "trunc_int a_real d_int",
  "round a_real d_int"
]

report.(16, rungs, &Logex.compile(tags <> &1, name: "wrong"))
