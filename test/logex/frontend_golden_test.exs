defmodule Logex.FrontendGoldenTest do
  @moduledoc """
  Holds the front end to a record of what it did before.

  `test/fixtures/frontend_golden.txt` lists, for about 1,400 sources, what `tokenize/1`
  and `parse/1` produce: the parse AST and the lexer's end line, or the line a lex or
  parse error is reported on. The leex/yecc front end wrote the first record (`19f461a`)
  and its hand-written replacement matched it unchanged. It has changed since only on
  purpose: B2 rewrote 139 entries (`157393c`), B8 165 (every one an input with a lone CR,
  `713b2d2`), `//` comments one (`"ote aa // note"`, `1fab52c`) and `.` name parts one
  (`"ote a.b"`, `46f17f0`), and the header's wording changed once. It exercises the front end far more widely than
  the rest of the suite — CRLF, lone CRs, blank and whitespace-only lines, token
  boundaries, every unbalanced delimiter.

  It keeps the AST and error lines, not the tokens. Newline coalescing is invisible to it
  (one `rnd` or three parse alike), and where a run of newlines reports an error would
  show only if one of its sources put an error there, which none does.
  `frontend_test.exs` pins both directly, and columns and messages too.

  The record changes only in a commit that changes the language or the generator on
  purpose, by regenerating it (`test/fixtures/generate_frontend_golden.exs`) and reading
  the diff.

  Since OE-1 it also holds `Logex.Parser.well_formed!/1`, the definition of a tree
  `parse/1` can produce, to every tree in the record: a check that refused one would
  make `Logex.compile/2` raise on that source.
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

  test "every tree in the record is one Logex.Parser.well_formed!/1 takes, unchanged" do
    trees = for {_source, {:ok, tree, _end_line}} <- entries(), do: tree

    for tree <- trees do
      assert Logex.Parser.well_formed!(tree) == tree
    end

    # Its reach: what each rule of the check meets in a tree parse/1 gives.
    assert trees |> Enum.flat_map(&reach/1) |> MapSet.new() ==
             MapSet.new([:many_rungs, :later_line, :int_lit, :dotted, :nested, :no_line])
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

  # What a tree holds that a rule of the check meets.
  defp reach({:routine, {:rungs, rungs}}),
    do: rung_count(length(rungs)) ++ Enum.flat_map(rungs, &rung_reach/1)

  defp rung_count(count) when count > 1, do: [:many_rungs]
  defp rung_count(_count), do: []

  defp rung_reach({:rung, elements}) do
    found = Enum.flat_map(elements, &element_reach(&1, 0))
    lined(Enum.member?(found, :leaf)) ++ Enum.reject(found, &(&1 == :leaf))
  end

  # A rung with no name or literal, such as `( )`, carries no line.
  defp lined(true), do: []
  defp lined(false), do: [:no_line]

  defp element_reach({:branches, legs}, depth),
    do: nested(depth) ++ Enum.flat_map(Enum.concat(legs), &element_reach(&1, depth + 1))

  defp element_reach({:name, line, word}, _depth),
    do: [:leaf | later(line)] ++ dotted(String.contains?(word, "."))

  defp element_reach({:int_lit, line, _n}, _depth), do: [:leaf, :int_lit | later(line)]

  defp nested(0), do: []
  defp nested(_depth), do: [:nested]

  defp later(1), do: []
  defp later(_line), do: [:later_line]

  defp dotted(true), do: [:dotted]
  defp dotted(false), do: []

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
