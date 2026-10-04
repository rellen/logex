defmodule Logex.DiagnosticTest do
  @moduledoc """
  M1-5 widened `%Logex.Diagnostic{}` once, with the stage that found a problem, its file,
  its column and its severity. `format/1` is pinned by its doctests; these pin what the
  stages stamp.
  """
  use ExUnit.Case, async: true

  doctest Logex.Diagnostic

  alias Logex.Compiler

  test "every diagnostic from lowering is stamped :validate, as an error with no file or column" do
    {:ok, tokens, _} = Compiler.tokenize("var a int\nzzz\nxic b ote a")
    {:ok, ast} = Compiler.parse(tokens)
    {:error, diagnostics} = Compiler.instructionize(ast)

    # the unknown type, the unknown instruction, and `b` undeclared: `a`'s use is excused,
    # as the use of a line refused for its type (M2-5)
    assert length(diagnostics) == 3

    for diagnostic <- diagnostics do
      assert %Logex.Diagnostic{stage: :validate, severity: :error, file: nil, column: nil} =
               diagnostic
    end
  end

  test "a file with no line is named alone, and a column without a file still reads well" do
    assert Logex.Diagnostic.format(%Logex.Diagnostic{
             stage: :parse,
             line: 2,
             column: 7,
             message: "this `(` is never closed"
           }) == "line 2, column 7: this `(` is never closed"

    assert Logex.Diagnostic.format(%Logex.Diagnostic{
             stage: :validate,
             line: 4,
             file: "seal.ld",
             severity: :warning,
             message: "m"
           }) == "seal.ld: line 4: warning: m"
  end
end
