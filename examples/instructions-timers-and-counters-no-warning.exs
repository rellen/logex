{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_output lamp bool\nvar delay ton\nton delay 100\nxic delay.dn ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar delay ton\n" <>
    "xic eye ton delay 0\nxic delay.dn ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar lube rto\n" <>
    "xic eye rto lube 100\nxic lube.dn ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar hopper ctd\n" <>
    "xic eye ctd hopper 3\nxic hopper.q ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar stock ctud\n" <>
    "xic eye ctu stock 3\nxic stock.qu ote lamp",
  "var_input eye bool\nvar_input reset_pb bool\nvar_output lamp bool\nvar boxes ctu\n" <>
    "xic reset_pb otl boxes.r\nxic boxes.q otu boxes.r\nxic eye ctu boxes 3\n" <>
    "xic boxes.q ote lamp",
  "var_input infeed bool\nvar_input outfeed bool\nvar_output lamp bool\nvar stock ctud\n" <>
    "( xic infeed ctu stock 3 | xic outfeed ctd stock 3 )\nxic stock.qu ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar delay ton\n" <>
    "xic eye ton delay 100\nxic eye ote delay.acc.3\nxic delay.dn ote lamp"
]

report.(15, programs, &Logex.compile(&1, name: "quiet"))
