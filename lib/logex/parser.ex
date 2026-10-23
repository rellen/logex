defmodule Logex.Parser do
  @moduledoc """
  Tokens to the parse AST, by recursive descent over the grammar yecc used to generate
  from, which this replaced.

      routine  -> rungs                       (empty rungs filtered out)
      rungs    -> rung | rung rnd rungs
      rung     -> branch
      branch   -> elems | '$empty'            (an empty leg is a jumper)
      elems    -> elem | elem elems
      elem     -> int_lit | real_lit | name | bst branches bnd
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
               | {:int_lit, line, n}                   n an integer, negative too,
                                                       written as its plain decimal
               | {:int_lit, line, n, spelling}         spelling lexes as one literal
                                                       token of n, and is not n's
                                                       plain decimal
               | {:real_lit, line, x}                  x a float, written as its plain
                                                       text, Float.to_string(x)
               | {:real_lit, line, x, spelling}        spelling lexes as one real
                                                       token of x, and is not x's
                                                       plain text
               | {:branches, [leg, ...]}               one leg or more
      leg      = [element, ...]                        possibly empty: a jumper

  Every line is a positive integer. Every name and literal of one rung, inside its groups
  too, is on one line, the rung's, and each rung is on a line after the rung before it.
  A rung of nothing but empty groups, `( )`, carries no line, but stands on a line of its
  own, so the next rung's line is past that one too. It widened when `PLAN.md` §5's
  negative literals landed (M3-3, decision 97), as `-5` lexes, and widens when its line
  continuations land, and not before. Decision 149's based literals and `_` separators
  (M5-7) did not widen it, a literal's leaf holding the value it spells; decision 202 did,
  a rung keeping a literal's spelling: a literal written other than as the plain decimal
  of its value, `16#ff`, `1_000`, `007` or `-0`, is the four-element leaf, its spelling
  last, and one written so, `255` or `-5`, the three-element leaf it always was, so a
  spelling is held exactly where the text differs from what the value prints as. M5-10
  (decision 149) widened it by the real literal, `37.5` or `1.5e3`, its leaf
  `{:real_lit, line, x}` where it is written as the plain text of its float,
  `Float.to_string/1`'s, the shortest that reads back to it, and `{:real_lit, line, x,
  spelling}` otherwise, `37.50`, `1.5E3` or `-0.0`, whose value is 0.0, so no leaf holds
  −0.0 (decision 150). Until then what the compiler does with one, an
  element cited at a line of its own, is kept for it, but nothing reaches it.
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

  @doc """
  Whether a term is an integer literal, a lexer token, a parse tree's leaf or an IR
  operand, plain, `{:int_lit, _, value}`, or spelled, `{:int_lit, _, value, spelling}`
  (decision 202). A guard.
  """
  defguard is_int_lit(term)
           when is_tuple(term) and tuple_size(term) in 3..4 and elem(term, 0) == :int_lit

  @doc """
  Whether a term is a real literal (M5-10), a lexer token, a parse tree's leaf or an IR
  operand, plain, `{:real_lit, _, value}`, or spelled, `{:real_lit, _, value, spelling}`.
  A guard.
  """
  defguard is_real_lit(term)
           when is_tuple(term) and tuple_size(term) in 3..4 and elem(term, 0) == :real_lit

  @doc """
  Whether a term is a literal of either kind, an integer's or, since M5-10, a real's. A
  guard.
  """
  defguard is_literal(term) when is_int_lit(term) or is_real_lit(term)

  @doc """
  A literal's value, whichever its shape: `255` for `16#ff`, and since M5-10 a real's
  float, `1500.0` for `1.5e3`.
  """
  def value({:int_lit, _at, value}), do: value
  def value({:int_lit, _at, value, _spelling}), do: value
  def value({:real_lit, _at, value}), do: value
  def value({:real_lit, _at, value, _spelling}), do: value

  @doc """
  An integer literal as it was written, whichever its shape (decision 202): its spelling,
  `16#ff`, `1_000` or `007`, or for a plain literal the decimal of its value, so that every
  message that quotes a literal quotes it as written.

      iex> Logex.Parser.spelling({:int_lit, 3, 255, "16#ff"})
      "16#ff"
      iex> Logex.Parser.spelling({:int_lit, 3, -5})
      "-5"
  """
  def spelling({:int_lit, _at, value}), do: Integer.to_string(value)
  def spelling({:int_lit, _at, _value, spelling}), do: spelling
  def spelling({:real_lit, _at, value}), do: Float.to_string(value)
  def spelling({:real_lit, _at, _value, spelling}), do: spelling

  @doc """
  Whether `spelling` is a spelling a literal of value `n` keeps (decision 202): a text the
  lexer reads as one literal token of `n` that holds it, so one other than `n`'s plain
  decimal. The one rule for a spelled leaf, of a parse tree (`well_formed!/1`) and of a
  compiled body (`Logex.Compiler.lowered?/1`).
  """
  def spelled?(n, spelling) when is_integer(n) and is_binary(spelling),
    do:
      match?(
        {:ok, [{:int_lit, _location, ^n, ^spelling}], _end_line},
        Logex.Lexer.tokenize(spelling)
      )

  # M5-10: a real's spelling so, one real token of its float that holds it, `1.5E3` of
  # 1500.0 or `-0.0` of 0.0, matched exactly, so −0.0 is no value any spelling holds.
  def spelled?(x, spelling) when is_float(x) and is_binary(spelling),
    do:
      match?(
        {:ok, [{:real_lit, _location, ^x, ^spelling}], _end_line},
        Logex.Lexer.tokenize(spelling)
      )

  def spelled?(_n, _spelling), do: false

  @doc """
  Whether a float is a real literal written as its plain text (M5-10): the text
  `Float.to_string/1` gives, the shortest that reads back to it, lexes as the plain token
  of that very float. −0.0 never is, its text `-0.0` the spelling of 0.0. The one rule for
  a plain real leaf, of a parse tree and of a compiled body.
  """
  def plain_real?(x) when is_float(x),
    do:
      match?(
        {:ok, [{:real_lit, _location, ^x}], _end_line},
        Logex.Lexer.tokenize(Float.to_string(x))
      )

  def plain_real?(_x), do: false

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

  defp branch([{:int_lit, {line, _}, value, spelling} | rest], acc),
    do: branch(rest, [{:int_lit, line, value, spelling} | acc])

  # M5-10 (decision 149): a real literal, plain or spelled, as an integer is.
  defp branch([{:real_lit, {line, _}, value} | rest], acc),
    do: branch(rest, [{:real_lit, line, value} | acc])

  defp branch([{:real_lit, {line, _}, value, spelling} | rest], acc),
    do: branch(rest, [{:real_lit, line, value, spelling} | acc])

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

  defp element!({:int_lit, line, n} = literal, at) when is_integer(n),
    do: line!(line, literal, at)

  defp element!({:int_lit, _line, _n} = literal, _at),
    do: refuse!("a literal is an integer", literal)

  # Decision 202: a spelled literal, its spelling the one text that lexes as it, so a tree
  # holds a spelling only where `parse/1` would: never the plain decimal of its value,
  # which the three-element leaf says, and never one of another value.
  defp element!({:int_lit, line, n, spelling} = literal, at) when is_integer(n) do
    one_literal!(spelling, n, literal)
    line!(line, literal, at)
  end

  defp element!({:int_lit, _line, _n, _spelling} = literal, _at),
    do: refuse!("a literal is an integer", literal)

  # M5-10: a real leaf, its float written as its plain text, or spelled, its spelling the
  # one text that lexes as it, so a tree holds what `parse/1` would, never −0.0.
  defp element!({:real_lit, line, x} = literal, at) when is_float(x) do
    plain_real!(plain_real?(x), literal)
    line!(line, literal, at)
  end

  defp element!({:real_lit, _line, _x} = literal, _at),
    do: refuse!("a real literal is a float", literal)

  defp element!({:real_lit, line, x, spelling} = literal, at) when is_float(x) do
    one_real!(spelled?(x, spelling), literal)
    line!(line, literal, at)
  end

  defp element!({:real_lit, _line, _x, _spelling} = literal, _at),
    do: refuse!("a real literal is a float", literal)

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
        "an element is {:name, line, word}, {:int_lit, line, n}, " <>
          "{:int_lit, line, n, spelling}, {:real_lit, line, x}, " <>
          "{:real_lit, line, x, spelling} or {:branches, legs}",
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

  @one_literal "a literal's spelling lexes as one literal token of its value, " <>
                 "other than the value's plain decimal"

  defp one_literal!(spelling, n, literal), do: one_literal!(spelled?(n, spelling), literal)

  defp one_literal!(true, _literal), do: :ok
  defp one_literal!(false, literal), do: refuse!(@one_literal, literal)

  defp plain_real!(true, _literal), do: :ok

  defp plain_real!(false, literal),
    do:
      refuse!(
        "a plain real literal's float is written as its plain text, which lexes as it",
        literal
      )

  defp one_real!(true, _literal), do: :ok

  defp one_real!(false, literal),
    do:
      refuse!(
        "a real literal's spelling lexes as one real token of its float, other than the " <>
          "float's plain text",
        literal
      )

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
