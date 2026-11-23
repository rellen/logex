{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_input eye bool\nvar_output lamp bool\nxic eye ote lamp\nxio eye otl lamp",
  "var_input eye bool\nvar_output lamp bool\nxic eye otl lamp\nxio eye otu lamp",
  "var_input eye bool\nvar_output lamp bool\nxic eye otl lamp\nxio eye otl lamp",
  "var_input eye bool\nvar_input slot dint\nvar_output lamps bool[4]\n" <>
    "xic eye otl lamps[slot]\nxio eye otu lamps[2]",
  "var_input eye bool\nvar_output status word\nxic eye move 0 status\nxic eye otl status.3",
  "var_input eye bool\nvar_output lamp bool\nvar_output horn bool\nvar s1 bool\n" <>
    "xic eye ons s1 ote lamp\nxic s1 ote horn",
  "var_input eye bool\nvar_output box_in bool\nvar s1 bool\n" <>
    "xic eye osr s1 box_in\nxio eye otu box_in"
]

report.(10, programs, &Logex.compile(&1, name: "quiet"))
