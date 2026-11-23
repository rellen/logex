{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("conversions/tags.txt")

rungs = [
  "dint_to_int a_lint d_int",
  "dint_to_int a_word d_int",
  "dint_to_int a_real d_int",
  "dint_to_int a_bool d_int",
  "word_to_int a_dword d_int",
  "word_to_int a_int d_int",
  "int_to_real a_word d_real",
  "real_to_int a_dint d_int",
  "real_to_int a_lreal d_int",
  "real_trunc_int a_dint d_int",
  "real_trunc_int a_lreal d_int",
  "dint_to_int a_dint d_dint",
  "dint_to_int a_dint d_word",
  "dint_to_int a_dint parts.pv",
  "dint_to_sint a_dint d_real",
  "real_to_int a_real d_dint",
  "real_to_int a_real d_real",
  "real_to_int a_real d_word",
  "real_trunc_int a_real d_dint",
  "real_trunc_int a_real d_real",
  "lreal_trunc_int a_lreal d_real"
]

report.(30, rungs, &Logex.compile(tags <> &1, name: "wrong"))
