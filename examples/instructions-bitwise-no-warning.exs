{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
out = "var_input eye bool\nvar_output out word\n"
sel = out <> "var_input sel int\n"
w = "var_input eye bool\nvar_output w word[4]\n"
wi = w <> "var_input i int\n"

programs = [
  "var_input n int\nvar_output m byte\nshl 1 n m",
  "var_input k word\nvar_output out word\nand k 16#00ff out",
  out <> "xic eye ote out.3\nxio eye ote out.4",
  out <> "xic eye ote out.3\nxio eye otl out.3",
  sel <> "xic eye ote out.[sel]\nxio eye otu out.[sel]",
  out <> "var_input k word\nmove k out\nxic eye otl out.15",
  out <> "var_output p bool\nxic eye ons out.3 ote p\nxic eye ote out.4",
  sel <> "var_output lamp bool\nxic eye ote out.0\nxic out.[sel] ote lamp",
  sel <> "xic eye ote out.[sel]\nxic eye otl out.3",
  wi <> "var_input j int\nxic eye ote w[i].3\nxic eye ote w[j].4",
  w <> "xic eye ote w[1].3\nxic eye ote w[2].3",
  wi <> "var_output p bool\nxic eye ons w[1].3 ote p\nxic eye ote w[i].4"
]

report.(21, programs, &Logex.compile(&1, name: "quiet"))
