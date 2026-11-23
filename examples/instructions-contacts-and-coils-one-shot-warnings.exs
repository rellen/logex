{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_input eye bool\nvar_output lamp bool\nvar s1 bool\n" <>
    "xic eye ons s1 ote lamp\nxio eye otu s1",
  "var_input eye bool\nvar_output status word\nvar_output lamp bool\n" <>
    "xic eye ons status.3 ote lamp\nxio eye move 0 status",
  "var_input eye bool\nvar_output box_in bool\nvar s1 bool\n" <>
    "xic eye osr s1 box_in\nxio eye ote box_in"
]

report.(5, programs, &Logex.compile(&1, name: "warned"))
