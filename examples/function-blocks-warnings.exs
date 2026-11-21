{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
{:ok, gate} = Logex.compile_file("gate.ld")

programs = [
  "var_output belt bool\nvar s1 seal\nxic s1.run ote belt",
  "var_input eye bool\nvar_output kick bool\nvar gates gate[4]\ncal gates[0] eye kick",
  "var_output done bool\nvar delay ton\nvar boxes ctu\nxic delay.dn xic boxes.q ote done"
]

report.(1, programs, &Logex.compile(&1, name: "panel", types: [seal, gate]))
