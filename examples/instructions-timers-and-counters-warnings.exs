{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_output lamp bool\nvar delay ton\nxic delay.dn ote lamp",
  "var_input reset_pb bool\nvar_output lamp bool\nvar boxes ctu\n" <>
    "xic reset_pb ote boxes.r\nxic boxes.q ote lamp",
  "var_output lamp bool\nvar stock ctud\nxic stock.qu ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar horn_pulse tp\nxic eye ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar lanes ton[4]\n" <>
    "xic eye ton lanes[1] 100\nxic lanes[1].dn ote lamp",
  "var_output lamp bool\nvar lanes ton[4]\nxic lanes[1].dn ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar lanes ton[12]\n" <>
    "xic eye ton lanes[0] 100\nxic lanes[0].dn ote lamp",
  "var_input eye bool\nvar_input reset_pb bool\nvar boxes ctu\n" <>
    "xic reset_pb ote boxes.r\nxic boxes.q ote boxes.r\nxic eye ctu boxes 3",
  "var_input eye bool\nvar_input reset_pb bool\nvar_input slot dint\nvar bins ctu[2]\n" <>
    "xic reset_pb ote bins[slot].r\nxic bins[1].q ote bins[1].r\n" <>
    "xic eye ctu bins[0] 3\nxic eye ctu bins[1] 3",
  "var_input eye bool\nvar_input reset_pb bool\nvar_input slot dint\nvar bins ctu[2]\n" <>
    "xic bins[1].q ote bins[1].r\nxic reset_pb ote bins[slot].r\n" <>
    "xic eye ctu bins[0] 3\nxic eye ctu bins[1] 3"
]

report.(1, programs, &Logex.compile(&1, name: "warned"))
