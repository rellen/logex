# 6 diagnostics, written by hand. Each one has the same message and a different place.
base = %Logex.Diagnostic{stage: :validate, line: 11, message: "`lamp` is not declared"}
file = "wrong/conveyor.ld"

diagnostics = [
  base,
  %{base | file: file},
  %{base | stage: :lex, file: file, column: 5},
  %{base | severity: :warning},
  %{base | stage: :file, file: file, line: nil},
  %{base | stage: :configure, file: "", line: nil, column: 5}
]

Enum.each(diagnostics, &IO.puts(Logex.Diagnostic.format(&1)))

try do
  Logex.Diagnostic.format(%{base | severity: :info})
rescue
  error in ArgumentError -> IO.puts("ArgumentError: " <> Exception.message(error))
end
