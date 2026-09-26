defmodule Logex.FrontendGoldenTest do
  @moduledoc """
  Holds the front end to a record it did not write.

  `test/fixtures/frontend_golden.txt` lists, for about 1,400 sources, what `tokenize/1`
  and `parse/1` produce: the parse AST and the lexer's end line, or the line a lex or
  parse error is reported on. The record was generated from the leex/yecc front end, so
  a front end that replaces it is checked against the one it replaced, including on the
  behaviours the rest of the suite does not exercise: newline coalescing, CRLF and lone
  CR, blank and whitespace-only lines, token boundaries, and every unbalanced delimiter.

  The record changes only in a commit that changes the language on purpose, by
  regenerating it (`test/fixtures/generate_frontend_golden.exs`) and reading the diff.
  """
  use ExUnit.Case, async: true

  @fixture "test/fixtures/frontend_golden.txt"
  @external_resource @fixture

  test "the front end matches the golden record" do
    entries = entries()
    assert length(entries) > 1_000

    mismatches =
      for {source, expected} <- entries, (actual = result(source)) != expected do
        {source, expected, actual}
      end

    assert mismatches == [],
           "#{length(mismatches)} of #{length(entries)} sources differ from the record; " <>
             "first 5:\n" <>
             Enum.map_join(Enum.take(mismatches, 5), "\n", fn {s, e, a} ->
               "  #{inspect(s)}\n    expected #{inspect(e)}\n    actual   #{inspect(a)}"
             end)
  end

  test "the record covers every outcome the front end can have" do
    kinds = entries() |> Enum.map(fn {_, expected} -> elem(expected, 0) end) |> MapSet.new()
    assert kinds == MapSet.new([:ok, :lex_error, :parse_error])
  end

  # Kept identical to the normaliser in generate_frontend_golden.exs. Locations are
  # reduced to their line, so a front end may carry columns without disturbing the record.
  defp result(source) do
    case Logex.Compiler.tokenize(source) do
      {:error, {loc, _module, _reason}, _} ->
        {:lex_error, line(loc)}

      {:ok, tokens, end_line} ->
        case Logex.Compiler.parse(tokens) do
          {:ok, ast} -> {:ok, ast, end_line}
          {:error, {loc, _module, _reason}} -> {:parse_error, line(loc), end_line}
        end
    end
  end

  defp line({line, _column}), do: line
  defp line(line) when is_integer(line), do: line

  defp entries do
    @fixture
    |> File.stream!()
    |> Stream.reject(&(String.starts_with?(&1, "#") or String.trim(&1) == ""))
    |> Enum.map(fn line ->
      {entry, _} = Code.eval_string(line)
      entry
    end)
  end
end
