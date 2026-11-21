{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
out = "var_input eye bool\nvar_output out word\n"
sel = out <> "var_input sel int\n"
w = "var_input eye bool\nvar_output w word[4]\nvar_input i int\n"
wj = w <> "var_input j int\n"

programs = [
  "var_output m byte\nand 16#0f 3 m",
  "var_output m byte\nnot 0 m",
  "var_output m byte\nshl 1 3 m",
  out <> "var_input k word\nmove k out\nxic eye ote out.3",
  out <> "var_input k word\nxic eye ote out.3\nmove k out",
  out <> "var_input k word\nnot k out\nxic eye ote out.15",
  out <> "xic eye ote out.3\nxio eye ote out.3",
  sel <> "var_input other int\nxic eye ote out.[sel]\nxic eye ote out.[other]",
  sel <> "xic eye ote out.3\nxic eye ote out.[sel]",
  sel <> "xic eye ote out.[sel]\nxic eye ote out.3",
  sel <> "var_input k word\nmove k out\nxic eye ote out.[sel]",
  sel <> "var_input other int\nxic eye ote out.[sel]\nxic eye otl out.[other]",
  sel <> "var_output p bool\nxic eye ons out.3 ote p\nxic eye ote out.[sel]",
  out <> "var_input k word\nvar_output p bool\nxic eye ons out.3 ote p\nmove k out",
  "var_input go bool\nvar_input x dint\nvar t1 ton\nmove x t1.pre\nxic go ote t1.pre.3\n" <>
    "xic go ton t1 5",
  sel <> "xic eye ote out.3\nxic eye otl out.[sel]",
  wj <> "xic eye ote w[i].3\nxic eye ote w[j].3",
  wj <> "var_input n int\nxic eye ote w[i].3\nxic eye ote w[j].[n]",
  wj <> "var_input x word\nxic eye ote w[i].3\nmove x w[j]",
  w <> "var_output p bool\nxic eye ons w[1].3 ote p\nxic eye ote w[i].3"
]

report.(1, programs, &Logex.compile(&1, name: "warned"))
