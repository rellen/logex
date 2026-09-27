defmodule Logex.Diagnostic do
  @moduledoc """
  One problem found in a routine, and the line it is on.

  `Logex.Compiler.instructionize/1` returns a list of these, in source order, rather than
  raising at the first. A rung never spans lines, so the line alone names the rung.
  """

  @enforce_keys [:line, :message]
  defstruct [:line, :message]

  @type t :: %__MODULE__{line: pos_integer, message: String.t()}

  @doc ~S(The form a person reads: "line 3: unknown instruction `zzz`".)
  def format(%__MODULE__{line: line, message: message}), do: "line #{line}: #{message}"
end
