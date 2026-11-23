{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_input eye bool\nvar_output lamp bool\nxic eye ote lamp\nxio eye ote lamp",
  "var_input eye bool\nvar_input slot dint\nvar_output lamps bool[4]\n" <>
    "xic eye ote lamps[slot]\nxio eye otl lamps[2]",
  "var_input eye bool\nvar_output status word\nxic eye move 0 status\nxic eye ote status.3",
  "var_output lamp bool\nvar_output horn bool\nxic lamp ote horn"
]

report.(1, programs, &Logex.compile(&1, name: "warned"))
