{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
tags = File.read!("conversions/tags.txt")

rungs = [
  "dint_to_int a_dint",
  "real_trunc_int a_real",
  "dint_to_int a_dint 5",
  "dint_to_int a_dint a_int",
  "dint_to_int d_array d_int",
  "dint_to_int a_dint d_array",
  "dint_to_int delay d_int",
  "dint_to_int a_dint delay.dn",
  "lint_to_dint a_lint parts.cv",
  "dint_to_int a_dint.3 d_int",
  "dint_to_int a_dint d_int.3",
  "real_to_int a_real.3 d_int",
  "ton delay 100 dint_to_int a_dint d_int",
  "var dint_to_int bool",
  "var Word_To_Int bool"
]

report.(1, rungs, &Logex.compile(tags <> &1, name: "wrong"))
