{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

head = "function_block hop\nvar_input go bool\nvar_output q bool\n"

bodies = [
  "xic go jmp done\nxic go ote q",
  "xic go jmp function_block\nlbl function_block ote q",
  "xic go jmp FUNCTION_BLOCK\nlbl FUNCTION_BLOCK ote q",
  "var me hop\ncal me go q",
  "var_input more bool[2]\nxic more[0] ote q"
]

report.(23, Enum.map(bodies, &(head <> &1)), &Logex.compile(&1, name: "hop"))
