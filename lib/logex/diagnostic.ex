defmodule Logex.Diagnostic do
  @moduledoc """
  One problem found in a program: what it is, where it is, and which stage found it.

  `Logex.compile/2` and `Logex.compile_file/1` return a list of these rather than raising,
  and a compiled `%Logex.Program{}` carries its warnings as these too. A rung never spans
  lines, so the line alone names the rung.

  - `stage` is `:file` (reading the file, or its name), `:lex`, `:parse` or `:validate`
    (the declarations, instructions and tags, `Logex.Compiler.instructionize/2`).
  - `line` is nil only for a `:file` problem that no line holds, such as an unreadable file.
  - `column` is set by the front end, which alone still knows it; `file` by
    `Logex.compile_file/1`.
  - `severity` is `:error` or `:warning`.
  """

  @enforce_keys [:stage, :line, :message]
  defstruct [:stage, :line, :message, file: nil, column: nil, severity: :error]

  @type stage :: :file | :lex | :parse | :validate
  @type t :: %__MODULE__{
          stage: stage,
          line: pos_integer | nil,
          message: String.t(),
          file: String.t() | nil,
          column: pos_integer | nil,
          severity: :error | :warning
        }

  @doc ~S'''
  The form a person reads: where, then what. Each part that is not known is left out.

      iex> Logex.Diagnostic.format(%Logex.Diagnostic{stage: :validate, line: 3, message: "unknown instruction `zzz`"})
      "line 3: unknown instruction `zzz`"

      iex> Logex.Diagnostic.format(%Logex.Diagnostic{stage: :lex, line: 1, column: 5, file: "motor.ld", message: ~s(illegal character "@")})
      ~s(motor.ld: line 1, column 5: illegal character "@")

      iex> Logex.Diagnostic.format(%Logex.Diagnostic{stage: :file, line: nil, file: "motor.ld", message: "cannot be read: no such file or directory"})
      "motor.ld: cannot be read: no such file or directory"

      iex> Logex.Diagnostic.format(%Logex.Diagnostic{stage: :validate, line: 2, severity: :warning, message: "`spare` is declared but no rung uses it"})
      "line 2: warning: `spare` is declared but no rung uses it"
  '''
  def format(%__MODULE__{} = diagnostic),
    do: where(diagnostic) <> label(diagnostic.severity) <> diagnostic.message

  defp where(%__MODULE__{file: nil, line: nil}), do: ""
  defp where(%__MODULE__{file: file, line: nil}), do: "#{file}: "

  defp where(%__MODULE__{file: file, line: line, column: column}),
    do: in_file(file) <> "line #{line}" <> at_column(column) <> ": "

  defp in_file(nil), do: ""
  defp in_file(file), do: "#{file}: "

  defp at_column(nil), do: ""
  defp at_column(column), do: ", column #{column}"

  defp label(:error), do: ""
  defp label(:warning), do: "warning: "
end
