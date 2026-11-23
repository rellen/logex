{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_input eye bool\nvar_output lamp bool\nvar cure ton_ltime\n" <>
    "xic eye ton cure 1500000\nxic cure.dn ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar cure ton_ltime\n" <>
    "xic eye ton cure 2000000\nge cure.acc 3000 ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar cure ton_ltime\n" <>
    "xic eye move 2500 cure.pre\nxic eye ton cure 2000000\nxic cure.dn ote lamp"
]

report.(11, programs, &Logex.compile(&1, name: "warned"))
