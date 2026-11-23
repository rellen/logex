{:ok, fan} = Logex.compile_file("diagnostics/fan.ld")

declarations = "var_input fan_on bool\nvar_input hot bool\nvar_output fan bool\n"

configuration = """
task fast intervl 10 priority 1
var_global hot_1 bool at panel.i.0
var_global fan_1 bool at panel.q.0
program f1 fan with fsat
  f1.fan_on 1
  f1.hot    hot_1
  f1.fan    fan_1
"""

candidate = String.replace(fan.source, "speed int 900", "speed dint 900")
{:ok, candidate} = Logex.compile(candidate, name: "fan")

{:ok, unused} =
  Logex.compile(declarations <> "var spare bool\nxic fan_on xic hot ote fan", name: "fan")

results = [
  {"a file that is not there", Logex.compile_file("diagnostics/pump.ld")},
  {"a character that logex cannot read",
   Logex.compile(declarations <> "xic fan_on @ ote fan", name: "fan")},
  {"a branch with no )",
   Logex.compile(declarations <> "( xic fan_on xic hot ote fan", name: "fan")},
  {"a name that is not declared",
   Logex.compile(declarations <> "xic fan_on ote fna", name: "fan")},
  {"a configuration", Logex.Configuration.compile("line", configuration, %{"fan" => fan})},
  {"an online edit that changes a type",
   Logex.Edit.accept(fan, candidate, Logex.Runtime.instance(fan))},
  {"a warning", {:warnings, unused.warnings}}
]

fields = [:stage, :line, :column, :file, :severity]

for {label, {_result, diagnostics}} <- results do
  IO.puts(label)

  for diagnostic <- diagnostics do
    IO.puts("  " <> Enum.map_join(fields, "  ", &"#{&1}: #{inspect(Map.get(diagnostic, &1))}"))
    IO.puts("  " <> Logex.Diagnostic.format(diagnostic))
  end
end
