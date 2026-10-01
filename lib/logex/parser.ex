defmodule Logex.Parser do
  @moduledoc """
  Tokens to the parse AST, by recursive descent over the grammar yecc used to generate
  from, which this replaced.

      routine  -> rungs                       (empty rungs filtered out)
      rungs    -> rung | rung rnd rungs
      rung     -> branch
      branch   -> elems | '$empty'            (an empty leg is a jumper)
      elems    -> elem | elem elems
      elem     -> int_lit | name | bst branches bnd
      branches -> branch | branch nxb branches

  `rungs/2` and `line_end/3` parse `routine`, `rungs` and `rung`; `branch/2` parses
  `branch`, `elems` and `elem`, and hands a group's legs to `legs/3`, which parses
  `branches` and the `bnd` that closes the group.

  As written the grammar is not left-factored; the parser implements its left-factored
  form, which is LL(1): every decision is made on the next token alone. `branch` is the
  only production with an empty alternative, and it ends at whatever cannot start an
  `elem`. yecc used to report a conflict if that stopped being true; nothing does now.
  What stands in for it is `test/fixtures/frontend_golden.txt`, first written by the yecc
  front end and matched exactly by this one; `printer_test.exs`'s round-trip properties
  over every production; and the jumper and unbalanced-delimiter tests in
  `end_to_end_test.exs`. A new production goes into the printer test's generator and its
  `@required_shapes` before it lands.

  **A well-formed tree.** `well_formed!/1` is the definition of a well-formed parse tree:
  exactly the trees `parse/1` can produce, stated once, as data rather than as tokens.
  `Logex.Compiler.instructionize/2` checks its routine with it on entry, so a tree built
  as data that no text could have said is a host mistake, an `ArgumentError`, before any
  stage reads it (OE-1; `docs/organisation.md` §4.9, decision 28):

      routine  = {:routine, {:rungs, [rung, ...]}}     the list may be empty
      rung     = {:rung, [element, ...]}               one element or more
      element  = {:name, line, word}                   word lexes as one name token
               | {:int_lit, line, n}                   n an integer, 0 or more
               | {:branches, [leg, ...]}               one leg or more
      leg      = [element, ...]                        possibly empty: a jumper

  Every line is a positive integer. Every name and literal of one rung, inside its groups
  too, is on one line, the rung's, and each rung is on a line after the rung before it.
  A rung of nothing but empty groups, `( )`, carries no line, but stands on a line of its
  own, so the next rung's line is past that one too. The check widens when `PLAN.md`
  §5's negative literals and line continuations land, and not before. Until then what the
  compiler does with either, a negative preset's message and an element cited at a line
  of its own, is kept for them, but nothing reaches it.
  """

  @doc """
  Returns `{:ok, {:routine, {:rungs, rungs}}}` or `{:error, {loc, Logex.Parser, reason}}`,
  the shapes yecc returned, with a `{line, column}` location.

  AST leaves keep only the line, `{:name, line, value}`, because the suite pins that
  shape; the column is used for diagnostics only.
  """
  def parse(tokens), do: rungs(tokens, [])

  @doc """
  The tree, if `parse/1` could have produced it; otherwise an `ArgumentError` that names
  the first node, in reading order, that it could not have. The moduledoc gives the
  shape. One walk of the tree, which lexes each name once, so it is linear in the tree's
  size and in its depth of nesting.
  """
  def well_formed!({:routine, {:rungs, rungs}} = tree) when is_list(rungs) do
    rungs!(rungs, 0)
    tree
  end

  def well_formed!(tree), do: refuse!("a tree is {:routine, {:rungs, rungs}}", tree)

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

  # `last` is the last line a rung stood on, 0 before the first. A rung of nothing but
  # empty groups has no line of its own to give, and still takes one.
  defp rungs!([{:rung, [_ | _] = elements} | rest], last),
    do: rungs!(rest, stood(series!(elements, {:before, last})))

  defp rungs!([], _last), do: :ok

  defp rungs!([rung | _rest], _last),
    do: refuse!("a rung is {:rung, elements}, with one element or more", rung)

  defp rungs!(tail, _last), do: improper!(tail)

  defp stood({:on, line}), do: line
  defp stood({:before, last}), do: last + 1

  # A series, a rung or a leg. `at` is `{:before, last}` until the rung's first name or
  # literal, and `{:on, line}` after it.
  defp series!([element | rest], at), do: series!(rest, element!(element, at))
  defp series!([], at), do: at
  defp series!(tail, _at), do: improper!(tail)

  defp element!({:name, line, word} = name, at) do
    one_name!(word, name)
    line!(line, name, at)
  end

  defp element!({:int_lit, line, n} = literal, at) when is_integer(n) and n >= 0,
    do: line!(line, literal, at)

  defp element!({:int_lit, _line, _n} = literal, _at),
    do:
      refuse!(
        "a literal is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)",
        literal
      )

  defp element!({:branches, [_ | _] = legs}, at), do: legs!(legs, at)

  defp element!({:branches, _legs} = group, _at),
    do:
      refuse!(
        "a branch group is {:branches, legs}, with one leg or more: `( )` is one empty leg",
        group
      )

  defp element!(element, _at),
    do:
      refuse!(
        "an element is {:name, line, word}, {:int_lit, line, n} or {:branches, legs}",
        element
      )

  defp legs!([leg | rest], at) when is_list(leg), do: legs!(rest, series!(leg, at))
  defp legs!([], at), do: at
  defp legs!([leg | _rest], _at), do: refuse!("a leg is a list of elements", leg)
  defp legs!(tail, _at), do: improper!(tail)

  # The lexer is the one rule for a name, so what it reads as one name token is a name:
  # `t1.dn` is one, and `a b`, `7`, `t1.` and `a//b` are not.
  @one_name "a name's word lexes as one name token"

  defp one_name!(word, name) when is_binary(word),
    do: one_name!(Logex.Lexer.tokenize(word), word, name)

  defp one_name!(_word, name), do: refuse!(@one_name, name)

  defp one_name!({:ok, [{:name, _location, word}], _end_line}, word, _name), do: :ok
  defp one_name!(_lexed, _word, name), do: refuse!(@one_name, name)

  defp line!(line, node, _at) when not is_integer(line) or line < 1,
    do: refuse!("a line is a positive integer", node)

  defp line!(line, _node, {:on, line}), do: {:on, line}

  defp line!(_line, node, {:on, rung}),
    do: refuse!("a rung is one line, and this one began on line #{rung}", node)

  defp line!(line, _node, {:before, last}) when line > last, do: {:on, line}

  defp line!(_line, node, {:before, last}),
    do: refuse!("each rung starts on a line of its own, after line #{last}", node)

  defp improper!(tail), do: refuse!("every list in it ends in []", tail, "got a list ending in")

  defp refuse!(rule, node, got \\ "got"),
    do:
      raise(
        ArgumentError,
        "not a tree Logex.Parser.parse/1 can produce: #{rule}, #{got}: #{inspect(node)}"
      )

  defp unexpected(token, expected),
    do: {:error, {elem(token, 1), __MODULE__, {:unexpected, describe(token), expected}}}

  defp describe({:rnd, _}), do: "a newline"
  defp describe({:nxb, _}), do: "`|`"
  defp describe({:bnd, _}), do: "`)`"

  # Logex.Lexer never makes any other token here, but parse/1 is public and yecc answered
  # a token it did not know with an error, not a crash.
  defp describe(token), do: inspect(token)
end
