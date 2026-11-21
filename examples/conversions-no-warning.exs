{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

programs = [
  "var_input boxes dint\nvar_output shown sint\ndint_to_sint boxes shown",
  "var_input hz lreal\nvar_output small real\nlreal_to_real hz small",
  "var_input a dint\nvar_input b int\nvar_output shown sint\n" <>
    "dint_to_sint a shown\nint_to_sint b shown",
  "var_input status word\nvar_output code int\nvar_output out word\n" <>
    "word_to_int status code\nint_to_word code out",
  "var_input eye bool\nvar_input code int\nvar_output out word\n" <>
    "int_to_word code out\nxic eye otl out.3\nxio eye otu out.3"
]

report.(8, programs, &Logex.compile(&1, name: "quiet"))
