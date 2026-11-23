# What the milestones changed for a program. Each text is a short program.
report = fn
  {:ok, _program} -> "compiles"
  {:error, [diagnostic | _]} -> Logex.Diagnostic.format(diagnostic)
end

compile = fn text -> report.(Logex.compile(text, name: "boxes")) end

# Milestones 1, 3, 5 and 6: words that a program can no longer use.
IO.puts("mov        " <> compile.("var_input a dint\nvar_output b dint\nmov a b\n"))
IO.puts("add        " <> compile.("var add bool\n"))
IO.puts("real       " <> compile.("var real bool\n"))
IO.puts("retain     " <> compile.("var retain bool\n"))
IO.puts("retain     " <> compile.("var_output lamp bool\nxic retain ote lamp\n"))

# Milestone 5: a result past the limit of its type wraps, and the add passes no power.
counter_text = """
var_input eye bool
var_output count dint 2147483646
var_output added bool
xic eye add count 1 count ote added
"""

{:ok, counter} = Logex.compile(counter_text, name: "counter")
state = Logex.Runtime.instance(counter)
state = Logex.Runtime.put_inputs(counter, state, %{"eye" => 1})
{outputs, state} = Logex.Runtime.scan(counter, state)
IO.puts("scan 1     #{inspect(outputs)}")
{outputs, _state} = Logex.Runtime.scan(counter, state)
IO.puts("scan 2     #{inspect(outputs)}")

# What the milestones did not add.
IO.puts("res        " <> compile.("var boxes ctu\nvar_input pb bool\nxic pb res boxes\n"))
IO.puts("mcr        " <> compile.("var_input stop bool\nxio stop mcr\n"))
IO.puts("persistent " <> compile.("var persistent dint\n"))
IO.puts("watchdog   " <> compile.("var watchdog bool\n"))
