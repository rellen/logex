{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_output total dint\nmove 5 total",
  "var_input step sint\nvar_output lamp bool\nle step -128 ote lamp",
  "var_input step sint\nvar_output lamp bool\nne step 127 ote lamp",
  "var_input boxes uint\nvar_output lamp bool\neq boxes 0 ote lamp",
  "var_output speed real\nmove 0.1 speed",
  "var_input flow dint\nvar_output total dint\nadd total flow total",
  "var_input flow dint\nvar_output total dint\nmove flow total\nadd total flow total"
]

report.(13, programs, &Logex.compile(&1, name: "quiet"))
