{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_output total dint\nadd 2 3 total",
  "var_output total dint\nneg 5 total",
  "var_output root real\nsqrt 4.0 root",
  "var_output lamp bool\neq 5 5.0 ote lamp",
  "var_input boxes uint\nvar_output lamp bool\nge boxes 0 ote lamp",
  "var_input boxes uint\nvar_output lamp bool\nle boxes 65535 ote lamp",
  "var_input step sint\nvar_output lamp bool\nlt step -128 ote lamp",
  "var_input status word\nvar_output lamp bool\nle status 16#ffff ote lamp",
  "var_input speed real\nvar_output lamp bool\nge speed -3.4028235e38 ote lamp",
  "var_output speed real\nmove 16777217.0 speed",
  "var_input speed real\nvar_output lamp bool\neq speed 16777217.0 ote lamp",
  "var_input eye bool\nvar_input status word\nvar_output out word\n" <>
    "move status out\nxic eye ote out.3"
]

report.(1, programs, &Logex.compile(&1, name: "warned"))
