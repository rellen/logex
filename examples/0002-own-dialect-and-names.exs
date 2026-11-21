# Print "compiles", or each diagnostic of the compile.
report = fn
  {:ok, _program} -> IO.puts("  compiles")
  {:error, diagnostics} -> Enum.each(diagnostics, &IO.puts("  " <> Logex.Diagnostic.format(&1)))
end

# The declarations of the motor, and of the box counter.
motor = "var_input start bool\nvar_input stop bool\nvar_output motor bool\n"
boxes = "var_input eye bool\n"

texts = [
  {"1. A mnemonic in uppercase", motor <> "XIC start XIO stop OTE motor\n"},
  {"2. A mnemonic as the name of a tag", motor <> "var Ote bool\nxic start ote motor\n"},
  {"3. A tag in the wrong case", motor <> "xic Start xio stop ote motor\n"},
  {"4. The old name of move", motor <> "var speed dint\nmov 600 speed\n"},
  {"5. A new word for ton", motor <> "var t1 ton\nxic start on_delay t1 3000\n"},
  {"6. A master control zone", motor <> "xic start mcr\n"},
  {"7. A branch in words", motor <> "bst xic start nxb xic motor bnd xio stop ote motor\n"},
  {"8. A rung on 2 lines", motor <> "xic start xio stop\note motor\n"},
  {"9. ctu_dint, and a ctd on it", boxes <> "var boxes ctu_dint\nxic eye ctd boxes 3\n"}
]

Enum.each(texts, fn {title, text} ->
  IO.puts(title)
  report.(Logex.compile(text, name: "dialect"))
end)

# The case of a mnemonic, a section and a type word changes nothing in the program.
{:ok, lower} = Logex.compile(motor <> "xic start xio stop ote motor\n", name: "motor")
declarations = "VAR_INPUT start BOOL\nVAR_INPUT stop BOOL\nVAR_OUTPUT motor BOOL\n"
{:ok, upper} = Logex.compile(declarations <> "XIC start XIO stop OTE motor\n", name: "motor")
same = {lower.rungs, lower.tags} == {upper.rungs, upper.tags}
IO.puts("The same rungs and tags in uppercase: #{same}")
