defmodule Logex.Lexer do
  @moduledoc """
  Source text to tokens, by hand: binary pattern matching, no generated code.

  Every token carries its position as `{line, column}`, both counted from 1 and the
  column counted in characters, not bytes:

      {:bst, loc}  {:nxb, loc}  {:bnd, loc}  {:rnd, loc}
      {:name, loc, binary}  {:int_lit, loc, integer}

  A name may have `.` parts, `t1.dn` or `word.3`, and is still one `name` token. An
  integer may have a sign, `-5`, glued to its digits (M3-3): one `int_lit` token, located
  at the `-`.

  `Logex.Parser` keeps only the line in the AST, whose shape the suite pins; the column
  is there for diagnostics. Whitespace and `//` comments are never emitted.

  This replaced `src/ladder_lexer.xrl`. `test/fixtures/frontend_golden.txt` is the record
  that one first wrote, which this matched before B2, B8 and PLAN.md §5's comment, `.` and
  negative-literal rules changed it on purpose. Seven things differ on purpose: locations
  carry a column; a source that is not valid UTF-8 is a located error rather than the
  `UnicodeConversionError` that `String.to_charlist/1` raised before leex ever ran; a
  number running straight into a tag, `1bst`, is an error rather than two tokens (B2); a
  lone `\r` is a newline, not whitespace (B8); `//` starts a comment; a name may have `.`
  parts; and a `-` glued to digits is a negative literal's sign (M3-3, decision 97). leex
  made the last three illegal characters.
  """

  defguardp is_name_start(ch) when ch in ?a..?z or ch in ?A..?Z or ch == ?_
  defguardp is_name_char(ch) when is_name_start(ch) or ch in ?0..?9

  @doc """
  Returns `{:ok, tokens, end_line}` or `{:error, {loc, Logex.Lexer, reason}, line}`: the
  three shapes leex returned, with a `{line, column}` location.
  """
  def tokenize(source) when is_binary(source), do: lex(source, 1, 1, [])

  def format_error({:illegal, text}), do: "illegal character #{inspect(text)}"

  def format_error({:missing_separator, text}),
    do: "missing separator after integer: #{inspect(text)} is neither a number nor a tag"

  def format_error({:signed_inside, text}),
    do:
      "missing separator before `-`: #{inspect(text)} is neither a tag nor a number, " <>
        "and a sign begins a number"

  # `(`, `|` and `)` are punctuation, outside the NAME character set, so a missing space
  # cannot fuse a delimiter into a neighbouring tag (PLAN.md §4·B1).
  defp lex(<<?(, rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:bst, {l, c}} | acc])
  defp lex(<<?|, rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:nxb, {l, c}} | acc])
  defp lex(<<?), rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:bnd, {l, c}} | acc])

  # A newline is `\n`, `\r\n` or a lone `\r` (B8: a lone `\r` was whitespace, so a file
  # with classic-Mac line endings was one rung and meant something else than in LF). A
  # CRLF is located at its `\n`, as it was while `\r` was whitespace.
  defp lex(<<?\r, ?\n, rest::binary>>, l, c, acc), do: newline(rest, l, c + 1, acc)
  defp lex(<<nl, rest::binary>>, l, c, acc) when nl in [?\n, ?\r], do: newline(rest, l, c, acc)

  defp lex(<<ws, rest::binary>>, l, c, acc) when ws in [?\s, ?\t],
    do: lex(rest, l, c + 1, acc)

  # `//` to the end of the line is a comment (PLAN.md §5). It stops before the newline, or
  # `ote a // note` and `ote b` on the next line would silently be one rung.
  defp lex(<<?/, ?/, rest::binary>>, l, c, acc), do: comment(rest, l, c + 2, acc)

  # A lexeme is measured first and then cut from the source in one match. Cut, a lexeme of
  # up to 64 bytes is a heap binary, and a longer one a sub-binary of the source. Grown with
  # `<<acc::binary, ch>>`, each was an off-heap, 256-byte writable binary, and allocating
  # and collecting those made token-dense sources lex up to 2.2x slower than leex did.
  # lexer_binaries_test.exs fails if they come back.
  defp lex(<<d, _::binary>> = src, l, c, acc) when d in ?0..?9 do
    n = digits(src, 0)
    <<digits::binary-size(^n), rest::binary>> = src
    number(rest, digits, l, c, acc)
  end

  # PLAN.md §5, M3-3 (decision 97): a `-` glued to digits is a negative literal's sign, and
  # the two are one token, located at the `-`: `-5`, and `-0`, which is 0. logex has no
  # infix operator, so a `-` can only be a sign; when infix arithmetic arrives, this moves
  # to the grammar. A `-` with no digit straight after it stays illegal, `- 5` and `--5`
  # among them, and there is no leading `+`. B2's rule holds for the signed run too: `-5a`
  # is one mistyped lexeme.
  defp lex(<<?-, d, _::binary>> = src, l, c, acc) when d in ?0..?9 do
    <<?-, unsigned::binary>> = src
    n = digits(unsigned, 0) + 1
    <<digits::binary-size(^n), rest::binary>> = src
    number(rest, digits, l, c, acc)
  end

  defp lex(<<h, _::binary>> = src, l, c, acc) when is_name_start(h),
    do: name(src, name_part(src, 0), l, c, acc)

  defp lex(<<>>, l, _c, acc), do: {:ok, Enum.reverse(acc), l}

  defp lex(<<ch::utf8, _::binary>>, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, {:illegal, <<ch::utf8>>}}, l}

  defp lex(<<byte, _::binary>>, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, {:illegal, <<byte>>}}, l}

  # Any character may be in a comment, counted as one column, but a source that is not
  # valid UTF-8 is still a located error there.
  defp comment(<<nl, _::binary>> = rest, l, c, acc) when nl in [?\n, ?\r],
    do: lex(rest, l, c, acc)

  defp comment(<<_::utf8, rest::binary>>, l, c, acc), do: comment(rest, l, c + 1, acc)
  defp comment(<<>>, l, c, acc), do: lex(<<>>, l, c, acc)

  defp comment(<<byte, _::binary>>, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, {:illegal, <<byte>>}}, l}

  # A run of newlines and the whitespace between them is one rung delimiter, so blank
  # lines and indentation never reach the parser. Whitespace is never emitted, so an
  # `rnd` on top of the accumulator means only blanks lie between.
  defp newline(rest, l, _c, [{:rnd, _} | _] = acc), do: lex(rest, l + 1, 1, acc)
  defp newline(rest, l, c, acc), do: lex(rest, l + 1, 1, [{:rnd, {l, c}} | acc])

  # B2: digits running straight on into a letter or `_` are one mistyped lexeme, not a
  # number and then a tag — `mov 1bst aa` used to lex as `1` and `bst` and fail much
  # later, unlocated. The error names the whole run (`1bst`, not `1b`). `mov 123 hh`, a
  # bare `1`, a tag ending in digits and `1(` are unaffected.
  defp number(<<h, _::binary>> = rest, digits, l, c, _acc) when is_name_start(h) do
    n = word(rest, 0)
    <<tail::binary-size(^n), _::binary>> = rest
    {:error, {{l, c}, __MODULE__, {:missing_separator, digits <> tail}}, l}
  end

  defp number(rest, digits, l, c, acc),
    do: lexeme(rest, digits, {:int_lit, {l, c}, String.to_integer(digits)}, {l, c}, acc)

  defp name(src, {:ok, n}, l, c, acc) do
    <<name::binary-size(^n), rest::binary>> = src
    lexeme(rest, name, {:name, {l, c}, name}, {l, c}, acc)
  end

  defp name(src, {:mistyped, n}, l, c, _acc) do
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {:missing_separator, run}}, l}
  end

  # M3-3 (decision 97): a sign begins a number, so it needs a separator before it, as B2's
  # number needs one after it. A name or a number running straight on into a signed number,
  # `a-5`, `t1.dn-5` or `5-3`, is one mistyped lexeme, named whole from its start through
  # the word after the `-`, never a name and then a literal: the writer meant a tag, or a
  # subtraction, which is `sub`. A `-` with no digit after it is the next lexeme's, illegal.
  defp lexeme(<<?-, d, _::binary>> = rest, text, _token, {l, c}, _acc) when d in ?0..?9 do
    <<?-, signed::binary>> = rest
    n = word(signed, 0)
    <<tail::binary-size(^n), _::binary>> = signed
    {:error, {{l, c}, __MODULE__, {:signed_inside, text <> "-" <> tail}}, l}
  end

  defp lexeme(rest, text, token, {l, c}, acc),
    do: lex(rest, l, c + byte_size(text), [token | acc])

  # PLAN.md §5: a name goes on in `.` parts, each a name or an integer, and stays one
  # token: `t1.dn`, `word.3`, `m1.t1.acc`. Each returns `{:ok, n}` for a name `n` long, or
  # `{:mistyped, n}` when an integer part runs straight into a letter or `_`, which is B2's
  # mistyped lexeme: `a.1b` is an error naming `a.1b`, not the name `a.1` and a tag `b`. A
  # `.` not followed by a name or an integer ends the name and is itself illegal.
  defp name_part(<<ch, rest::binary>>, n) when is_name_char(ch), do: name_part(rest, n + 1)
  defp name_part(rest, n), do: dot(rest, n)

  defp integer_part(<<d, rest::binary>>, n) when d in ?0..?9, do: integer_part(rest, n + 1)

  defp integer_part(<<h, _::binary>> = rest, n) when is_name_start(h),
    do: {:mistyped, n + word(rest, 0)}

  defp integer_part(rest, n), do: dot(rest, n)

  defp dot(<<?., h, rest::binary>>, n) when is_name_start(h), do: name_part(rest, n + 2)
  defp dot(<<?., d, rest::binary>>, n) when d in ?0..?9, do: integer_part(rest, n + 2)
  defp dot(_rest, n), do: {:ok, n}

  # Each returns `n` plus the length of the run it starts on. Every lexeme is ASCII, so
  # its byte size is its width in characters. A mistyped run goes on through `.` parts, so
  # `1b.c` and `a.1b.c` are named whole, since `b.c` alone would be one name.
  defp digits(<<d, rest::binary>>, n) when d in ?0..?9, do: digits(rest, n + 1)
  defp digits(_, n), do: n

  defp word(<<ch, rest::binary>>, n) when is_name_char(ch), do: word(rest, n + 1)
  defp word(<<?., ch, rest::binary>>, n) when is_name_char(ch), do: word(rest, n + 2)
  defp word(_, n), do: n
end
