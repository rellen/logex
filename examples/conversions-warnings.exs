{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_output shown sint\ndint_to_sint 129 shown",
  "var_output code int\nword_to_int 16#ffff code",
  "var_output whole int\nreal_trunc_int -1.6 whole",
  "var_output rpm int\nreal_to_int 16777217.0 rpm",
  "var_input eye bool\nvar_input code int\nvar_output out word\n" <>
    "int_to_word code out\nxic eye ote out.3",
  "var_input eye bool\nvar_input code int\nvar_output out word\n" <>
    "xic eye ote out.3\nint_to_word code out",
  "var_input go bool\nvar t ton_ltime\nvar_output done bool\n" <>
    "xic go ton t 3000000000\nxic t.dn ote done\ndint_to_lint 1500000 t.pre"
]

report.(1, programs, &Logex.compile(&1, name: "warned"))
