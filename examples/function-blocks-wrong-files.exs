{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{:ok, seal} = Logex.compile_file("seal.ld")
ports = "\nvar_input  open bool\nvar_output kick bool\n"
rung = "xic open ote kick"

texts = [
  "function_block kicker" <> ports <> rung,
  "function_block Gate" <> ports <> rung,
  "function_block" <> ports <> rung,
  "function_block gate kick" <> ports <> rung,
  "var_input open bool\nfunction_block gate\nvar_output kick bool\n" <> rung,
  "function_block gate\nfunction_block gate" <> ports <> rung,
  "function_block gate\nvar_input function_block bool\nvar_output kick bool\nxic function_block ote kick",
  "function_block gate" <> ports <> "var self gate\n" <> rung,
  "function_block gate" <> ports <> "var s1 sael\n" <> rung,
  "function_block gate\nvar_in_out open bool\nvar_output kick bool\n" <> rung
]

report.(1, texts, &Logex.compile(&1, name: "gate", types: [seal]))

# Texts 11 to 13 name the function block with a reserved word. The option `name:` is the
# second word of the first line.
names = ["ton", "var", "dint"]
reserved = for name <- names, do: "function_block " <> name <> ports <> rung
report.(11, reserved, fn text -> Logex.compile(text, name: Enum.at(String.split(text), 1)) end)
