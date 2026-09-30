defmodule Logex.FrontendGoldenTest do
  @moduledoc """
  Holds the front end to a record of what it did before.

  `test/fixtures/frontend_golden.txt` lists, for about 1,400 sources, what `tokenize/1`
  and `parse/1` produce: the parse AST and the lexer's end line, or the line a lex or
  parse error is reported on. The leex/yecc front end wrote the first record (`19f461a`)
  and its hand-written replacement matched it unchanged. It has changed since only on
  purpose: B2 rewrote 139 entries (`157393c`), B8 165 (every one an input with a lone CR),
  and the header's wording changed once. It exercises the front end far more widely than
  the rest of the suite — CRLF, lone CRs, blank and whitespace-only lines, token
  boundaries, every unbalanced delimiter.

  It keeps the AST and error lines, not the tokens. Newline coalescing is invisible to it
  (one `rnd` or three parse alike), and where a run of newlines reports an error would
  show only if one of its sources put an error there, which none does.
  `frontend_test.exs` pins both directly, and columns and messages too.

  The record changes only in a commit that changes the language or the generator on
  purpose, by regenerating it (`test/fixtures/generate_frontend_golden.exs`) and reading
  the diff.
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
