defmodule Logex.Lexer do
  @moduledoc """
  Source text to tokens, by hand: binary pattern matching, no generated code.

  Every token carries its position as `{line, column}`, both counted from 1 and the
  column counted in characters, not bytes:

      {:bst, loc}  {:nxb, loc}  {:bnd, loc}  {:rnd, loc}
      {:name, loc, binary}  {:int_lit, loc, integer}

  `Logex.Parser` keeps only the line in the AST, whose shape the suite pins; the column
  is there for diagnostics.

  This replaced `src/ladder_lexer.xrl`, and `test/fixtures/frontend_golden.txt` is the
  record that one wrote. Two things differ on purpose: locations carry a column, and a
  source that is not valid UTF-8 is a located error rather than the
  `UnicodeConversionError` that `String.to_charlist/1` raised before leex ever ran.
  """

  @type loc :: {pos_integer, pos_integer}

  @doc """
  Returns `{:ok, tokens, end_line}` or `{:error, {loc, Logex.Lexer, reason}, line}`: the
  three shapes leex returned, with a `{line, column}` location.
  """
  def tokenize(source) when is_binary(source), do: lex(source, 1, 1, [])

  def format_error({:illegal, text}), do: "illegal character #{inspect(text)}"

  # `(`, `|` and `)` are punctuation, outside the NAME character set, so a missing space
  # cannot fuse a delimiter into a neighbouring tag (PLAN.md §4·B1).
  defp lex(<<?(, rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:bst, {l, c}} | acc])
  defp lex(<<?|, rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:nxb, {l, c}} | acc])
  defp lex(<<?), rest::binary>>, l, c, acc), do: lex(rest, l, c + 1, [{:bnd, {l, c}} | acc])

  # A run of newlines and the whitespace between them is one rung delimiter, so blank
  # lines and indentation never reach the parser. Whitespace is never emitted, so an
  # `rnd` on top of the accumulator means only blanks lie between.
  defp lex(<<?\n, rest::binary>>, l, _c, [{:rnd, _} | _] = acc), do: lex(rest, l + 1, 1, acc)
  defp lex(<<?\n, rest::binary>>, l, c, acc), do: lex(rest, l + 1, 1, [{:rnd, {l, c}} | acc])

  # `\r` is whitespace, so CRLF works and a lone `\r` never ends a rung — which is B8,
  # kept here on purpose so that this lexer changes nothing leex did not.
  defp lex(<<ws, rest::binary>>, l, c, acc) when ws in [?\s, ?\t, ?\r],
    do: lex(rest, l, c + 1, acc)

  defp lex(<<d, _::binary>> = src, l, c, acc) when d in ?0..?9 do
    {digits, rest} = digits(src, "")
    lex(rest, l, c + byte_size(digits), [{:int_lit, {l, c}, String.to_integer(digits)} | acc])
  end

  defp lex(<<h, _::binary>> = src, l, c, acc) when h in ?a..?z or h in ?A..?Z or h == ?_ do
    {name, rest} = word(src, "")
    lex(rest, l, c + byte_size(name), [{:name, {l, c}, name} | acc])
  end

  defp lex(<<>>, l, _c, acc), do: {:ok, Enum.reverse(acc), l}

  defp lex(<<ch::utf8, _::binary>>, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, {:illegal, <<ch::utf8>>}}, l}

  defp lex(<<byte, _::binary>>, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, {:illegal, <<byte>>}}, l}

  # Both lexemes are ASCII, so their byte size is their width in characters.
  defp digits(<<d, rest::binary>>, acc) when d in ?0..?9, do: digits(rest, <<acc::binary, d>>)
  defp digits(rest, acc), do: {acc, rest}

  defp word(<<ch, rest::binary>>, acc)
       when ch in ?a..?z or ch in ?A..?Z or ch in ?0..?9 or ch == ?_,
       do: word(rest, <<acc::binary, ch>>)

  defp word(rest, acc), do: {acc, rest}
end
