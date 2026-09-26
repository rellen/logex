defmodule Logex.Parser do
  @moduledoc """
  Tokens to the parse AST, by recursive descent: one function per production of the
  grammar yecc used to generate from, which this replaced.

      routine  -> rungs                       (empty rungs filtered out)
      rungs    -> rung | rung rnd rungs
      rung     -> branch
      branch   -> elems | '$empty'            (an empty leg is a jumper)
      elems    -> elem | elem elems
      elem     -> int_lit | name | bst branches bnd
      branches -> branch | branch nxb branches

  The grammar is LL(1): every decision is made on the next token alone, and `branch` is
  the only nullable production, ending at whatever cannot start an `elem`. yecc used to
  report a conflict if that stopped being true; nothing does now. What stands in for it
  is `test/fixtures/frontend_golden.txt`, which records what the yecc grammar accepted
  and produced, `printer_test.exs`'s round-trip properties over every production, and the
  jumper and unbalanced-delimiter tests in `end_to_end_test.exs`. A new production goes
  into the printer test's generator and its `@required_shapes` before it lands.
  """

  @doc """
  Returns `{:ok, {:routine, {:rungs, rungs}}}` or `{:error, {loc, Logex.Parser, reason}}`,
  the shapes yecc returned, with a `{line, column}` location.

  AST leaves keep only the line, `{:name, line, value}`, because the suite pins that
  shape; the column is used for diagnostics only.
  """
  def parse(tokens), do: rungs(tokens, [])

  def format_error({:unexpected, text, expected}),
    do: "expected #{Enum.join(expected, " or ")}, found #{text}"

  # Located at the innermost `(` still open when the input ends — the one to close.
  def format_error(:unclosed), do: "this `(` is never closed: the input ends before its `)`"

  defp rungs(tokens, acc) do
    case branch(tokens, []) do
      {:ok, elems, rest} -> line_end(rest, elems, acc)
      error -> error
    end
  end

  defp line_end([{:rnd, _} | rest], elems, acc), do: rungs(rest, keep(elems, acc))
  defp line_end([], elems, acc), do: {:ok, {:routine, {:rungs, Enum.reverse(keep(elems, acc))}}}
  defp line_end([token | _], _elems, _acc), do: unexpected(token, ["a newline", "end of input"])

  # `branch -> '$empty'` makes an empty rung derivable, so leading, trailing and repeated
  # newlines would otherwise become phantom `{:rung, []}` — drop them here. Empty branch
  # *legs* are kept: they are jumpers and pass power.
  defp keep([], acc), do: acc
  defp keep(elems, acc), do: [{:rung, elems} | acc]

  defp branch([{:name, {line, _}, value} | rest], acc),
    do: branch(rest, [{:name, line, value} | acc])

  defp branch([{:int_lit, {line, _}, value} | rest], acc),
    do: branch(rest, [{:int_lit, line, value} | acc])

  defp branch([{:bst, open} | rest], acc) do
    case legs(rest, open, []) do
      {:ok, legs, rest} -> branch(rest, [{:branches, legs} | acc])
      error -> error
    end
  end

  defp branch(rest, acc), do: {:ok, Enum.reverse(acc), rest}

  defp legs(tokens, open, acc) do
    case branch(tokens, []) do
      {:ok, leg, [{:nxb, _} | rest]} -> legs(rest, open, [leg | acc])
      {:ok, leg, [{:bnd, _} | rest]} -> {:ok, Enum.reverse([leg | acc]), rest}
      {:ok, _, []} -> {:error, {open, __MODULE__, :unclosed}}
      {:ok, _, [token | _]} -> unexpected(token, ["`|`", "`)`"])
      error -> error
    end
  end

  defp unexpected(token, expected),
    do: {:error, {elem(token, 1), __MODULE__, {:unexpected, describe(token), expected}}}

  defp describe({:rnd, _}), do: "a newline"
  defp describe({:nxb, _}), do: "`|`"
  defp describe({:bnd, _}), do: "`)`"
end
