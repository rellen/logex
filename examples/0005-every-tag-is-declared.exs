# Print "compiles", or each diagnostic of the compile.
report = fn
  {:ok, _program_or_type} -> IO.puts("  compiles")
  {:error, diagnostics} -> Enum.each(diagnostics, &IO.puts("  " <> Logex.Diagnostic.format(&1)))
end

# The declarations of the motor: lines 1 to 4 of each program.
motor = """
var_input start bool
var_input stop bool
var_output motor bool
var_output speed_sp dint 1200
"""

programs = [
  {"1. A typing error in a name", motor <> "( xic strat | xic motor ) xio stop ote motor\n"},
  {"2. A program that declares nothing", "xic start ote motor\n"},
  {"3. A dint read as a bool", motor <> "xic speed_sp ote motor\n"},
  {"4. A rung that writes a var_input", motor <> "xic stop ote start\n"},
  {"5. A move with 1 operand", motor <> "var src dint\nmove src ote motor\n"},
  {"6. A mnemonic as the name of a tag", motor <> "var Ote bool\nxic start ote motor\n"},
  {"7. A timer that is not declared", motor <> "xic start ton t1 3000\n"},
  {"8. A preset on the declaration of a timer",
   motor <> "var t1 ton 3000\nxic start ton t1 3000\n"},
  {"9. An initial value that does not fit", motor <> "var r int 40000\nxic r ote motor\n"},
  {"10. A qualifier after the name", motor <> "var count retain dint\nxic start move 1 count\n"},
  {"11. A declaration after the first rung",
   motor <> "xic start ote motor\nvar late dint\nxic late ote motor\n"},
  {"12. A word after the initial value", motor <> "var r int 5 7\nxic r ote motor\n"},
  {"13. A configuration word as a tag", motor <> "var task bool\nxic start xio task ote motor\n"},
  {"14. A configuration word as a var_external",
   motor <> "var_external task bool\nxic start xio task ote motor\n"}
]

Enum.each(programs, fn {title, text} ->
  IO.puts(title)
  report.(Logex.compile(text, name: "motor"))
end)

# The same word in a program and in the file of a function block.
seal = "function_block seal\nvar_input start bool\nvar_input stop bool\nvar_output run bool\n"
IO.puts("15. function_block as a tag, in a program, then in a block")

report.(
  Logex.compile(motor <> "var function_block bool\nxic start xio function_block ote motor\n",
    name: "motor"
  )
)

report.(
  Logex.compile(seal <> "var function_block bool\n( xic start | xic run ) xio stop ote run\n",
    name: "seal"
  )
)

# The words in a configuration file: a global, a device and an instance.
{:ok, fan} =
  Logex.compile("var_input hot bool\nvar_output fan bool\nxic hot ote fan\n", name: "fan")

plant = fn global, device, instance ->
  """
  task fast interval 10 priority 1
  var_global #{global} bool at #{device}.i.0
  var_global fan_q bool at panel.q.0
  program #{instance} fan with fast
  #{instance}.hot #{global}
  #{instance}.fan fan_q
  """
end

IO.puts("16. A mnemonic, then 3 configuration words, in a configuration file")
report.(Logex.Configuration.compile("plant", plant.("xic", "panel", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("task", "panel", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("hot_i", "program", "f1"), %{"fan" => fan}))
report.(Logex.Configuration.compile("plant", plant.("hot_i", "panel", "retain"), %{"fan" => fan}))

# A tag declared from Elixir gets the checks of a declaration line.
declare = fn call ->
  try do
    tag = call.()
    IO.puts("  `#{tag.name}` is declared, qualifier: #{inspect(tag.retain)}")
  rescue
    error in ArgumentError -> IO.puts("  ArgumentError: " <> Exception.message(error))
  end
end

IO.puts("17. Tags declared from Elixir")
declare.(fn -> Logex.Tag.new!("count", :dint, :var, nil, retain: true) end)
declare.(fn -> Logex.Tag.new!("count", :dint, :var, nil, :retain) end)
declare.(fn -> Logex.Tag.new!("t1", Logex.FbType.ton(), :var, %{"pre" => 3000}) end)
declare.(fn -> Logex.Tag.new!("Ote", :bool) end)
