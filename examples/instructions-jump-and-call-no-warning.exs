{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")

programs = [
  "var_input eye bool\nvar_output lamp bool\njmp done\nlbl done xic eye ote lamp",
  "var_input lamp bool\nvar_output belt bool\nxic lamp jmp lamp\nlbl lamp xic lamp ote belt",
  "var_input skip bool\nvar_input eye bool\nvar_output lamp bool\nvar s1 seal\n" <>
    "xic skip jmp done\ncal s1 eye 0 lamp\nlbl done",
  "var_input speed int\nvar_input rate real\nvar_output total lreal\nvar g gain\n" <>
    "cal g speed rate total"
]

report.(13, programs, &Logex.compile(&1, name: "quiet", types: [seal, gain]))
