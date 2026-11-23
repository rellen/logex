alias Logex.Configuration

declarations = "var_input fan_on bool\nvar_input hot bool\nvar_output fan bool\n"
program = fn rungs -> Logex.compile(declarations <> rungs, name: "fan") end

# Items 12 to 16 are configurations that run the program type `fan` of
# diagnostics/fan.ld.
{:ok, fan} = Logex.compile_file("diagnostics/fan.ld")
configure = fn text -> Configuration.compile("line", text, %{"fan" => fan}) end

# Item 14: the configuration of item 13, as Elixir data.
data = %Configuration{
  name: "line",
  programs: %{"fan" => fan},
  tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 1}],
  instances: [%Configuration.Instance{name: "f1", type: "fan", task: "fast"}]
}

running = """
task fast interval 10 priority 1
var_global hot_1 bool at panel.i.0
var_global lamp_1 bool at panel.q.1
program f1 fan with fast
  f1.fan_on 1
  f1.hot    hot_1
"""

# Item 16: an online edit puts a task in place of the line of `lamp_1`, and its `fan`
# declares `speed` as a dint.
candidate =
  String.replace(
    running,
    "var_global lamp_1 bool at panel.q.1",
    "task slow interval 100 priority 2"
  )

{:ok, fan_dint} =
  Logex.compile(String.replace(fan.source, "speed int", "speed dint"), name: "fan")

{:ok, running} = configure.(running)
{:ok, candidate} = Configuration.compile("line", candidate, %{"fan" => fan_dint})

# Items 8 to 11 compile the wrong files that diagnostics/wrong.exs copies. Item 9 adds a
# line with `@` to a copy of belts.ld.
{dir, _binding} = Code.eval_file("diagnostics/wrong.exs")
belts = File.read!(Path.join(dir, "wrong/belts.ld"))
File.write!(Path.join(dir, "wrong/belts_2.ld"), belts <> "xic stop @ ote belt_1\n")

items = [
  {"2 characters that logex cannot read, and a name that is not declared",
   program.("xic fan_on @ ote fan\nxic fan_on $ ote fan\nxic hot ote fna")},
  {"a name that is not declared, then a branch with no )",
   program.("xic hot ote fna\n( xic fan_on ote fan")},
  {"2 errors on 1 line", program.("var src dint\nxic hot move src ote")},
  {"1 name that is not declared, on 3 lines",
   program.("xic fan_on ote fna\nxic hot ote fna\nxio hot ote fna")},
  {"a type that logex does not know, and 2 uses of the tag",
   program.("var run_t tonn\nxic fan_on ton run_t 500\nxic run_t.dn ote fan")},
  {"2 lines with errors, and 2 tags that no rung uses",
   Logex.compile(
     "var spare_1 bool\nvar spare_2 bool\n" <>
       declarations <> "xic fan_on ote fna\nxic hott ote fan",
     name: "fan"
   )},
  {"an unknown instruction, then a name that is not declared, on 2 lines",
   program.("xic hot otee fan fna\nxic hot ote fna")},
  {"a file whose function block has an error", {:file, "wrong/belts.ld"}},
  {"the same file, with a character that logex cannot read", {:file, "wrong/belts_2.ld"}},
  {"a file whose name cannot name a program", {:file, "wrong/fan-2.ld"}},
  {"a configuration file whose program type does not compile",
   {:configuration, "wrong/line.logex"}},
  {"a task line that logex cannot read",
   configure.(
     "task fast intervl 10 priority 1\nprogram f1 fan with fast\n  f1.fan_on 1\n  f1.hot 0"
   )},
  {"an instance with 2 var_inputs that no line connects",
   configure.("task fast interval 10 priority 1\nprogram f1 fan with fast")},
  {"the configuration of item 13, as Elixir data", {:error, Configuration.check(data)}},
  {"a character that logex cannot read, and 2 more errors",
   configure.("task fast intervl 10 priority 1\nprogram f1 fan with fsat @")},
  {"an online edit of a configuration",
   Configuration.Edit.accept(Logex.Runtime.start(running), candidate)}
]

compile = fn
  {:file, name} -> File.cd!(dir, fn -> Logex.compile_file(name) end)
  {:configuration, name} -> File.cd!(dir, fn -> Configuration.compile_file(name) end)
  result -> result
end

for {{label, result}, number} <- Enum.with_index(items, 1) do
  {:error, diagnostics} = compile.(result)
  IO.puts(String.pad_leading("#{number}", 2) <> "  #{label}")
  Enum.each(diagnostics, &IO.puts("    " <> Logex.Diagnostic.format(&1)))
end

File.rm_rf!(dir)
