declarations = """
var_input fan_on bool
var_input hot bool
var_output fan bool
var run_t ton
"""

program = fn rungs -> Logex.compile(declarations <> rungs, name: "fan") end

# The function block `seal`, given to the compile of item L.
{:ok, seal} =
  Logex.compile(
    "function_block seal\nvar_input start bool\nvar_output run bool\nxic start ote run",
    name: "seal"
  )

# The program type `fan` of the configurations of items O, P and R.
{:ok, fan} = Logex.compile_file("diagnostics/fan.ld")
configure = fn text -> Logex.Configuration.compile("line", text, %{"fan" => fan}) end

configuration = """
task fast interval 10 priority 1
var_global hot_1 bool at panel.i.0
program f1 Fan with Fast
program f2 fan with fsat
  f2.fan_on 1
  f2.hot    Hot_1
"""

# 100 names that are not declared, fan_1 to fan_100, then `Fan`, then 2 members that
# `run_t` does not have.
hundred =
  Enum.map_join(1..100, "\n", &"xic hot ote fan_#{&1}") <>
    "\nxic hot ote Fan\nxic run_t.et ote fan\nxic run_t.xx ote fan"

# 101 globals with the type `dnt`, in a configuration that runs `fan`.
globals =
  Enum.map_join(1..101, "\n", &"var_global g#{&1} dnt") <>
    "\ntask fast interval 10 priority 1\nprogram f1 fan with fast\n  f1.fan_on 1\n  f1.hot 0"

items = [
  {"Only the case is different", program.("xic Fan_on ote fan")},
  {"A near name", program.("xic fan_onn ote fan")},
  {"No near name", program.("xic fan_on ote blower")},
  {"A member: only the case is different", program.("xic run_t.DN ote fan")},
  {"A member: a near name", program.("xic run_t.dnn ote fan")},
  {"A member: no near name", program.("xic run_t.et ote fan")},
  {"A label", program.("xic hot jmp skp\nxic fan_on ote fan\nlbl skip xic hot ote fan")},
  {"A label: only the case is different",
   program.("xic hot jmp Skip\nxic fan_on ote fan\nlbl skip xic hot ote fan")},
  {"A label before the jmp",
   program.("lbl skip xic hot ote fan\nxic hot jmp skp\nxic fan_on ote fan")},
  {"A type", program.("var count dnt\nxic hot ote fan")},
  {"A type with an uppercase letter", program.("var count Dnt\nxic hot ote fan")},
  {"A function block: only the case is different",
   Logex.compile(declarations <> "var s1 Seal\nxic hot ote fan", name: "fan", types: [seal])},
  {"Instructions", program.("xic fan_on otee fan\nxic hot mov 1 fan")},
  {"A program that declares no tags", Logex.compile("xic a ote b", name: "p")},
  {"A configuration", configure.(configuration)},
  {"A configuration with 2 program types that the host does not give",
   configure.(
     "task fast interval 10 priority 1\nprogram f1 pmp with fast\nprogram f2 blwr with fast"
   )},
  {"101 names that are not declared, then 2 members", program.(hundred)},
  {"A configuration with 101 globals of the type dnt", configure.(globals)}
]

count = fn
  1 -> "1 diagnostic"
  n -> "#{n} diagnostics"
end

letters = Enum.map(?A..?Z, &<<&1>>)

for {{label, {:error, diagnostics}}, letter} <- Enum.zip(items, letters) do
  IO.puts(letter <> "  #{label}: " <> count.(length(diagnostics)))

  diagnostics
  |> Enum.with_index(1)
  |> Enum.filter(fn {_diagnostic, index} ->
    length(diagnostics) < 100 or index <= 2 or index >= 100
  end)
  |> Enum.each(fn {diagnostic, _index} ->
    IO.puts("   " <> Logex.Diagnostic.format(diagnostic))
  end)
end
