{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gain} = Logex.compile_file("instructions-jump-and-call/gain.ld")

programs = [
  "var_input eye bool\nvar_output lamp bool\nlbl here xic eye ote lamp",
  "var_input manual bool\nvar_input eye bool\nvar_output motor bool\n" <>
    "xio manual jmp auto\nxic eye ote motor\njmp done\nlbl auto xic eye ote motor\nlbl done",
  "var_input skip bool\nvar_input eye bool\nvar_output lamp bool\n" <>
    "xic skip jmp done\nxic eye ote lamp\nlbl done\nxio eye ote lamp",
  "var_output lamp bool\nvar s1 seal\nxic s1.run ote lamp",
  "var_output lamp bool\nvar s1 seal\nvar s2 seal\ncal s1 s2.run 0 lamp",
  "var_input eye bool\nvar_output lamp bool\nvar lanes seal[3]\ncal lanes[1] eye 0 lamp",
  "var_input eye bool\nvar_output lamp bool\nvar s1 seal\nxic eye jmp done\nlbl done ote lamp",
  "var_input eye bool\nvar_output lamp bool\nvar seen bool\nvar s1 seal\n" <>
    "xic eye ons seen ote lamp\ncal s1 eye 0 seen",
  "var_output total lreal\nvar g gain\ncal g 2 9007199254740993.0 total",
  "var_input eye bool\nvar_input skip bool\nvar_output lamp bool\nvar s1 seal\n" <>
    "cal s1 eye skip lamp\nxic skip ote lamp",
  "var_input eye bool\nvar_input skip bool\nvar_output lamp bool\nvar s1 seal\nvar s2 seal\n" <>
    "cal s1 eye skip lamp\ncal s2 skip eye lamp",
  "var_input eye bool\nvar_input skip bool\nvar_output lamp bool\nvar s1 seal\n" <>
    "xic eye cal s1 eye skip lamp ote lamp"
]

report.(1, programs, &Logex.compile(&1, name: "warned", types: [seal, gain]))
