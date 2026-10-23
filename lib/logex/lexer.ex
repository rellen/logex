defmodule Logex.Lexer do
  @moduledoc """
  Source text to tokens, by hand: binary pattern matching, no generated code.

  Every token carries its position as `{line, column}`, both counted from 1 and the
  column counted in characters, not bytes:

      {:bst, loc}  {:nxb, loc}  {:bnd, loc}  {:rnd, loc}
      {:name, loc, binary}  {:int_lit, loc, integer}  {:int_lit, loc, integer, spelling}

  A name may have `.` parts, `t1.dn` or `word.3`, and is still one `name` token, and since
  M5-9 (decision 160) a last part that is a tag's name in brackets, `status.[n]`, a bit
  whose number the tag holds, and since decision 213 a literal in brackets, `status.[4]`,
  Logix's spelling of `status.4`, kept as written. Since M5-11 (decision 151) a name part
  may be followed by an element's subscripts in one pair of brackets, `temps[3]` or
  `grid[1,7]`, each a tag's name or one number, `temps[16#3]`, split by `,` with no space,
  and a declaration's type word by its sizes, `int[8]`, still one name token, which may go
  on in `.` parts after the `]`; brackets that hold no subscripts, `a[]` or `a[1, 2]`, are
  `{:subscripts, run}`, and anything glued after the `]` but a `.` part, `a[1][2]` or
  `a[1]x`, `{:after_subscripts, run}`, each named whole. An
  integer may have a sign, `-5`, glued to its digits (M3-3): one `int_lit` token, located
  at the `-`. Since M5-7 (decision 149) it may be based, `16#ff`, `16#FF` or `2#1010`,
  with no sign, and any number may hold a single `_` between two digits, `1_000_000` or
  `2#1010_0000`; the token holds the value it spells, `16#ffff` 65,535, which its slot
  judges as it judges any literal. Since decision 202 a literal's token also holds its
  spelling, the text as written, wherever that is not the plain decimal of its value,
  `Integer.to_string/1`'s: `{:int_lit, loc, 255, "16#ff"}`, `{:int_lit, loc, 7, "007"}`
  and `{:int_lit, loc, 0, "-0"}`, where `255` and `-5` keep the three-element token. Octal and every other base, a signed based number, a
  `_` anywhere but between two digits, a based number with a digit outside its base and
  one with a second `#`, `16#ff#`, are each a located error naming the number whole, and Logix's suffixes, `5U` and `5L`,
  B2's mistyped lexeme.

  `Logex.Parser` keeps only the line in the AST, whose shape the suite pins; the column
  is there for diagnostics. Whitespace and `//` comments are never emitted.

  This replaced `src/ladder_lexer.xrl`. `test/fixtures/frontend_golden.txt` is the record
  that one first wrote, which this matched before B2, B8, PLAN.md §5's comment, `.` and
  negative-literal rules, decision 149's based literals and separators and decision 160's
  tag bit numbers changed it on purpose. Nine things differ on purpose: locations
  carry a column; a source that is not valid UTF-8 is a located error rather than the
  `UnicodeConversionError` that `String.to_charlist/1` raised before leex ever ran; a
  number running straight into a tag, `1bst`, is an error rather than two tokens (B2); a
  lone `\r` is a newline, not whitespace (B8); `//` starts a comment; a name may have `.`
  parts; a `-` glued to digits is a negative literal's sign (M3-3, decision 97); and a
  number may be based or hold `_` (M5-7, decision 149); and a name's last part may be a
  tag's name in brackets, `status.[n]` (M5-9, decision 160). leex made the last five
  illegal characters, or `1_000` a mistyped lexeme.
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
    do:
      "missing separator after #{after_what(text)}: #{inspect(text)} is neither a number nor a tag"

  def format_error({:separator, text}),
    do: "#{inspect(text)} is no number: a `_` in a number stands only between two digits"

  def format_error({:base, text}),
    do:
      "#{inspect(text)} is no number: a based number is written in base 16, `16#ff`, or " <>
        "base 2, `2#1010`, and logex reads no other base"

  def format_error({:signed_based, text}),
    do: "#{inspect(text)} is no number: a based number takes no sign"

  def format_error({:digits, 16, text}),
    do:
      "#{inspect(text)} is no number: a number in base 16 is written with the digits 0 to 9 " <>
        "and a to f, in either case, after its `16#`"

  def format_error({:digits, 2, text}),
    do:
      "#{inspect(text)} is no number: a number in base 2 is written with the digits 0 and 1 " <>
        "after its `2#`"

  def format_error({:hash, text}),
    do:
      "#{inspect(text)} is no number: a based number holds one `#`, between its base and " <>
        "its digits, `16#ff`"

  def format_error({:after_bracket, text}),
    do:
      "#{inspect(text)} is no name: a bit number in brackets, `status.[n]`, ends its name, " <>
        "and nothing may follow its `]` but a space"

  def format_error({:bracketed, text}),
    do:
      "#{inspect(text)} is no name: a bit number in brackets is a tag's name, `status.[n]`, " <>
        "or one number closed by its `]`, `status.[4]` or `status.[16#4]`"

  def format_error({:bracket, text}),
    do:
      "#{inspect(text)} is no name: a bit number in brackets is one tag's name between `[` " <>
        "and `]`, with no space, `status.[n]`"

  def format_error({:detached, text}),
    do:
      "#{inspect(text)} is no name: a bit number in brackets is written straight after its " <>
        "name's `.`, with no space, `status.[n]`"

  def format_error({:subscripts, text}),
    do:
      "#{inspect(text)} is no name: an element's subscripts are one pair of brackets " <>
        "straight after its array's name, each a number or a tag's name, split by `,` " <>
        "with no space, as in `grid[1,7]`"

  def format_error({:after_subscripts, text}),
    do:
      "#{inspect(text)} is no name: an element's subscripts end at their `]`, after which " <>
        "only a `.` part may follow, so every subscript goes inside the one pair of " <>
        "brackets, as in `grid[1,7]`"

  def format_error({:point, text}),
    do:
      "#{inspect(text)} is no number: a real has digits on both sides of its `.`, " <>
        "`1.0` or `0.5`"

  def format_error({:no_point, text}),
    do:
      "#{inspect(text)} is no number: a real has a `.` with digits on both sides before its " <>
        "exponent, `1.0e5`"

  def format_error({:plus, text}),
    do: "#{inspect(text)} is no number: logex takes no `+`, so an exponent is `e3` or `e-3`"

  def format_error({:exponent, text}),
    do: "#{inspect(text)} is no number: an exponent is `e` and its digits, `1.5e3` or `1.5e-3`"

  def format_error({:real_range, text}),
    do:
      "#{inspect(text)} is no number logex holds: an lreal's largest is " <>
        "1.7976931348623157e308"

  def format_error({:real_small, text}),
    do:
      "#{inspect(text)} is no number logex holds: an lreal's smallest above 0.0 is " <>
        "2.2250738585072014e-308"

  def format_error({:signed_inside, text}),
    do:
      "missing separator before `-`: #{inspect(text)} is neither a tag nor a number, " <>
        "and a sign begins a number"

  # M5-10: B2's lexeme after a real, `1.5L`, is told so, and after an integer as it was.
  defp after_what(text),
    do: if_real(String.match?(text, ~r/\A-?[0-9][0-9_]*\.[0-9]/), "a real", "integer")

  defp if_real(true, real, _integer), do: real
  defp if_real(false, _real, integer), do: integer

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
  # lexer_binaries_test.exs fails if they come back. A number's value is read from the cut
  # text, its `_`s left out, so only a number that holds one builds a binary, a heap one
  # for any up to 64 digits.
  defp lex(<<d, _::binary>> = src, l, c, acc) when d in ?0..?9,
    do: number(src, numeral(src, 0), l, c, acc)

  # PLAN.md §5, M3-3 (decision 97): a `-` glued to digits is a negative literal's sign, and
  # the two are one token, located at the `-`: `-5`, and `-0`, which is 0. logex has no
  # infix operator, so a `-` can only be a sign; when infix arithmetic arrives, this moves
  # to the grammar. A `-` with no digit straight after it stays illegal, `- 5` and `--5`
  # among them, and there is no leading `+`. B2's rule holds for the signed run too: `-5a`
  # is one mistyped lexeme.
  defp lex(<<?-, d, _::binary>> = src, l, c, acc) when d in ?0..?9 do
    <<?-, unsigned::binary>> = src
    number(src, numeral(unsigned, 1), l, c, acc)
  end

  defp lex(<<h, _::binary>> = src, l, c, acc) when is_name_start(h),
    do: name(src, name_part(src, 0), l, c, acc)

  # M5-10 (decision 149): a `.` that begins a lexeme before a digit, `.5`, is a real with no
  # digit before its point, named whole.
  defp lex(<<?., d, _::binary>> = src, l, c, _acc) when d in ?0..?9 do
    <<?., rest::binary>> = src
    n = 1 + word(rest, 0)
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {:point, run}}, l}
  end

  # M5-9's review: a `.[` that begins a lexeme, `w .[n]` or `xic .[n]`, is a bit number
  # held apart from its name, named whole through its `]`.
  defp lex(<<?., ?[, _::binary>> = src, l, c, _acc) do
    n = closing(src, 0)
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {:detached, run}}, l}
  end

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

  # A number's lexeme, measured: its sign and decimal digits, and any `_` among them; then
  # either a `#` and the rest of a based numeral, which may hold a sign so that `16#-1` is
  # named whole and refused, and a later `#`, so that Ada's `16#ff#` is too (M5-7's
  # review), or B2's mistyped run, or nothing more. B2: digits running
  # straight on into a letter are one mistyped lexeme, not a number and then a tag — `mov
  # 1bst aa` used to lex as `1` and `bst` and fail much later, unlocated. The error names
  # the whole run (`1bst`, not `1b`). `mov 123 hh`, a bare `1`, a tag ending in digits and
  # `1(` are unaffected. Logix's suffixes, `5U` and `5L` (RM018A p.870), are B2's lexeme
  # too, being no IEC form (decision 149).
  #
  # Plain digits, the commonest number by far, are read by `String.to_integer/1`, as before
  # decision 149; a number with a `_` in it, `separated/2`'s, or a `#` is checked digit by
  # digit first.
  defp numeral(<<d, rest::binary>>, n) when d in ?0..?9, do: numeral(rest, n + 1)
  defp numeral(<<?_, rest::binary>>, n), do: separated(rest, n + 1)
  defp numeral(<<?#, _::binary>> = rest, n), do: based(rest, n)
  defp numeral(<<?., _::binary>> = rest, n), do: point(rest, n)
  defp numeral(<<e, _::binary>> = rest, n) when e in [?e, ?E], do: exponent_only(rest, n)
  defp numeral(<<h, _::binary>> = rest, n) when is_name_start(h), do: {:mistyped, word(rest, n)}
  defp numeral(_rest, n), do: {:decimal, n}

  defp separated(<<ch, rest::binary>>, n) when ch in ?0..?9 or ch == ?_,
    do: separated(rest, n + 1)

  defp separated(<<?#, _::binary>> = rest, n), do: based(rest, n)
  defp separated(<<?., _::binary>> = rest, n), do: point(rest, n)
  defp separated(<<e, _::binary>> = rest, n) when e in [?e, ?E], do: exponent_only(rest, n)

  defp separated(<<h, _::binary>> = rest, n) when is_name_start(h),
    do: {:mistyped, word(rest, n)}

  defp separated(_rest, n), do: {:separated, n}

  # M5-10 (decision 149): a real is digits, a `.`, digits and an optional exponent, an `e`
  # or `E`, a `-` if negative, and digits, `37.5`, `1.5e3` or `1.5E-3`, as IEC's grammar
  # has it (Ed 3 Annex A p.222, Table 5 features 2 and 3), a single `_` between two digits
  # as in an integer. Its forms decision 149 refuses are each named whole: digits and a `.`
  # with no digit after it, `1.`, `{:point, run}`; an exponent with no `.` before it, `1e5`,
  # `{:no_point, run}`; a `+`, which logex keeps out (decision 97), `1.5e+3`, `{:plus, run}`;
  # an `e` with no digits, `1.5e`, `{:exponent, run}`; and, as B2's mistyped lexeme, a run
  # glued on after it, Logix's `1.5L` among them (RM018A p.870). A `.` that begins a lexeme
  # before a digit, `.5`, is `{:point, run}` too (lex/4).
  defp point(<<?., d, rest::binary>>, n) when d in ?0..?9, do: fraction(rest, n + 2)
  defp point(<<?., rest::binary>>, n), do: {:point, n + 1 + word(rest, 0)}

  defp fraction(<<ch, rest::binary>>, n) when ch in ?0..?9 or ch == ?_, do: fraction(rest, n + 1)
  defp fraction(<<e, ?+, rest::binary>>, n) when e in [?e, ?E], do: {:plus, n + 2 + word(rest, 0)}

  defp fraction(<<e, ?-, d, rest::binary>>, n) when e in [?e, ?E] and d in ?0..?9,
    do: exponent(rest, n + 3)

  defp fraction(<<e, d, rest::binary>>, n) when e in [?e, ?E] and d in ?0..?9,
    do: exponent(rest, n + 2)

  defp fraction(<<e, rest::binary>>, n) when e in [?e, ?E],
    do: {:exponent, n + 1 + dangling(rest)}

  defp fraction(rest, n), do: real_end(rest, n)

  defp exponent(<<ch, rest::binary>>, n) when ch in ?0..?9 or ch == ?_, do: exponent(rest, n + 1)
  defp exponent(rest, n), do: real_end(rest, n)

  # B2's rule after a real: a letter or a `.` part glued on makes the run one mistyped
  # lexeme, `1.5L`, `1.5x` or `1.5.2`.
  defp real_end(<<ch, _::binary>> = rest, n) when is_name_char(ch),
    do: {:mistyped, word(rest, n)}

  defp real_end(<<?., ch, _::binary>> = rest, n) when is_name_char(ch),
    do: {:mistyped, word(rest, n)}

  defp real_end(_rest, n), do: {:real, n}

  defp exponent_only(<<_e, sign, d, _::binary>> = rest, n)
       when sign in [?-, ?+] and d in ?0..?9,
       do: {:no_point, n + 2 + word(binary_part(rest, 2, byte_size(rest) - 2), 0)}

  defp exponent_only(<<_e, d, _::binary>> = rest, n) when d in ?0..?9,
    do: {:no_point, word(rest, n)}

  defp exponent_only(rest, n), do: {:mistyped, word(rest, n)}

  defp dangling(<<?-, rest::binary>>), do: 1 + word(rest, 0)
  defp dangling(rest), do: word(rest, 0)

  defp based(<<?#, ?-, rest::binary>>, n), do: {:based, based_run(rest, n + 2)}
  defp based(<<?#, rest::binary>>, n), do: {:based, based_run(rest, n + 1)}

  defp based_run(<<ch, rest::binary>>, n) when is_name_char(ch) or ch == ?#,
    do: based_run(rest, n + 1)

  # M5-10: a based number has no fraction, so `16#ff.3` is named whole, a digit outside its
  # base, where a `.` would end it and leave `.3` for the next lexeme.
  defp based_run(<<?., ch, rest::binary>>, n) when is_name_char(ch), do: based_run(rest, n + 2)

  defp based_run(_rest, n), do: n

  # Decision 202: a token keeps a literal's spelling wherever it is not the plain decimal of
  # its value, `Integer.to_string/1`'s, as a fourth element: a decimal with a leading zero,
  # `007`, or `-0`, which is 0, and every number with a `_` or a base. A plain decimal, the
  # commonest by far, keeps the three-element token, told apart by its first two bytes in
  # the clause head, so it costs what it did.
  defp number(<<?0, d, _::binary>> = src, {:decimal, n}, l, c, acc) when d in ?0..?9,
    do: spelled(src, n, l, c, acc)

  defp number(<<?-, ?0, _::binary>> = src, {:decimal, n}, l, c, acc),
    do: spelled(src, n, l, c, acc)

  defp number(src, {:decimal, n}, l, c, acc) do
    <<text::binary-size(^n), rest::binary>> = src
    lexeme(rest, text, {:int_lit, {l, c}, String.to_integer(text)}, {l, c}, acc)
  end

  defp number(src, {:real, n}, l, c, acc) do
    <<text::binary-size(^n), rest::binary>> = src
    real(real_value(text), text, rest, {l, c}, acc)
  end

  defp number(src, {kind, n}, l, c, acc) do
    <<text::binary-size(^n), rest::binary>> = src
    literal(value(kind, text), text, rest, l, c, acc)
  end

  defp spelled(src, n, l, c, acc) do
    <<text::binary-size(^n), rest::binary>> = src
    literal({:ok, String.to_integer(text)}, text, rest, l, c, acc)
  end

  defp literal({:ok, value}, text, rest, l, c, acc),
    do: lexeme(rest, text, {:int_lit, {l, c}, value, text}, {l, c}, acc)

  defp literal({:error, reason}, _text, _rest, l, c, _acc),
    do: {:error, {{l, c}, __MODULE__, reason}, l}

  # M5-10: a real's token, `{:real_lit, loc, 37.5}`, keeps its spelling as decision 202
  # keeps an integer's, wherever it is not the plain text of its value, the shortest that
  # reads back to it, `Float.to_string/1`'s: `1.5e3`, which is 1500.0, `37.50` and `-0.0`,
  # whose value is 0.0, since no value logex holds is −0.0 (decision 150).
  defp real({:ok, value}, text, rest, at, acc),
    do: lexeme(rest, text, real_token(Float.to_string(value) == text, at, value, text), at, acc)

  defp real({:error, reason}, _text, _rest, {l, _c} = at, _acc),
    do: {:error, {at, __MODULE__, reason}, l}

  defp real_token(true, at, value, _text), do: {:real_lit, at, value}
  defp real_token(false, at, value, text), do: {:real_lit, at, value, text}

  # A real's value: each of its digit runs held to the `_` rule an integer's is, then read
  # with its `_`s left out, and −0.0 kept as 0.0. One past an lreal's largest value,
  # `1.0e400`, which no float holds, is named whole, and so, since decision 228, is one no
  # float holds but 0.0, `1.0e-400`, a subnormal double, `1.0e-310`, read as itself, and the
  # zero itself, `0.0e-400` among its spellings, taken.
  defp real_value(text) do
    {unsigned, _negative} = unsigned(text)
    [whole, rest] = :binary.split(unsigned, ".")
    {fraction, power} = exponent_split(rest)
    runs = [whole, fraction | power]
    real_read(Enum.all?(runs, &(digits(&1, 10) == :ok)), text)
  end

  defp unsigned(<<?-, unsigned::binary>>), do: {unsigned, true}
  defp unsigned(text), do: {text, false}

  defp exponent_split(rest), do: split_exponent(:binary.split(rest, ["e", "E"]))

  defp split_exponent([fraction, <<?-, power::binary>>]), do: {fraction, [power]}
  defp split_exponent([fraction, power]), do: {fraction, [power]}
  defp split_exponent([fraction]), do: {fraction, []}

  defp real_read(false, text), do: {:error, {:separator, text}}

  defp real_read(true, text) do
    float = IO.iodata_to_binary(:binary.split(text, "_", [:global]))
    held(:erlang.binary_to_float(float), text)
  rescue
    ArgumentError -> {:error, {:real_range, text}}
  end

  # Decision 228: a literal whose double is subnormal, nearer 0.0 than an lreal's smallest
  # normal value, `1.0e-310`, is read as that double, which its slot refuses when the
  # program compiles, told it is too near 0.0 for its real (decision 216's rule, through
  # `Logex.Real.flushed?/2`); one no double holds but 0.0, `1.0e-400`, its digits not all
  # 0, is still no number logex holds (provisional), and 0.0 written any way is 0.0.
  defp held(value, text) when value == 0.0, do: zero(written_zero?(text), text)

  defp held(value, _text), do: {:ok, value}

  defp zero(true, _text), do: {:ok, 0.0}
  defp zero(false, text), do: {:error, {:real_small, text}}

  # Whether a real's digits before its exponent are all 0, `-0.0e-400` and `0_0.0`.
  defp written_zero?(<<ch, rest::binary>>) when ch in [?0, ?., ?_, ?-], do: written_zero?(rest)
  defp written_zero?(<<e, _::binary>>) when e in [?e, ?E], do: true
  defp written_zero?(<<>>), do: true
  defp written_zero?(_nonzero), do: false

  # Decision 149: a number is decimal, or based in 16 or 2 (IEC Ed 3 Table 5 features 4 and
  # 6), with no sign, which IEC gives a based number none of; octal, `8#`, which Ed 3
  # deprecates (NOTE 2), is deferred, and refused as any other base. A single `_` may stand
  # between two digits, `1_000_000` (Ed 3 p.26), and not after a `#`, `16#_ff`, which IEC's
  # grammar allows and its prose does not. A based literal is the number it spells,
  # `16#ffff` 65,535, judged by its slot as any literal is: a bit-string literal, read as
  # IEC reads one (p.26), and as Logix reads it (RM018A p.869).
  defp value(:mistyped, text), do: {:error, {:missing_separator, text}}

  defp value(kind, text) when kind in [:point, :no_point, :plus, :exponent],
    do: {:error, {kind, text}}

  defp value(:separated, <<?-, numeral::binary>> = text), do: negated(read(numeral, 10, text))
  defp value(:separated, text), do: read(text, 10, text)
  # A based number's base is judged before its sign, so `-8#17` is told that logex reads no
  # octal, and `-16#1` that a based number takes no sign (M5-7's review).
  defp value(:based, <<"-16#", _::binary>> = text), do: {:error, {:signed_based, text}}
  defp value(:based, <<"-2#", _::binary>> = text), do: {:error, {:signed_based, text}}
  defp value(:based, <<"16#", numeral::binary>> = text), do: read(numeral, 16, text)
  defp value(:based, <<"2#", numeral::binary>> = text), do: read(numeral, 2, text)
  defp value(:based, text), do: {:error, {:base, text}}

  defp negated({:ok, value}), do: {:ok, -value}
  defp negated(refused), do: refused

  # A numeral is checked digit by digit and then read whole, its `_`s left out, by
  # `String.to_integer/2`, so its cost is linear in its length, as a decimal's is.
  defp read(numeral, base, text), do: checked(digits(numeral, base), numeral, base, text)

  defp checked(:ok, numeral, base, _text) do
    parts = :binary.split(numeral, "_", [:global])
    {:ok, String.to_integer(IO.iodata_to_binary(parts), base)}
  end

  defp checked(:separator, _numeral, _base, text), do: {:error, {:separator, text}}
  defp checked(:signed, _numeral, _base, text), do: {:error, {:signed_based, text}}
  defp checked(:digits, _numeral, base, text), do: {:error, {:digits, base, text}}
  defp checked(:hash, _numeral, _base, text), do: {:error, {:hash, text}}

  defguardp is_digit(ch, base)
            when (ch in ?0..?9 and (base != 2 or ch in ?0..?1)) or
                   (base == 16 and (ch in ?a..?f or ch in ?A..?F))

  # A numeral's digits, a `_` only between two of them: `:ok`, or what is wrong with it, in
  # the order a reader meets it. `digits/2` takes the first digit, straight after a `#` or
  # at the start, and `digit_run/2` the rest.
  defp digits(<<ch, rest::binary>>, base) when is_digit(ch, base), do: digit_run(rest, base)
  defp digits(<<?_, _::binary>>, _base), do: :separator
  defp digits(<<?-, _::binary>>, _base), do: :signed
  defp digits(<<?#, _::binary>>, _base), do: :hash
  defp digits(_numeral, _base), do: :digits

  defp digit_run(<<ch, rest::binary>>, base) when is_digit(ch, base), do: digit_run(rest, base)

  defp digit_run(<<?_, ch, rest::binary>>, base) when is_digit(ch, base),
    do: digit_run(rest, base)

  defp digit_run(<<?_, _::binary>>, _base), do: :separator
  defp digit_run(<<?#, _::binary>>, _base), do: :hash
  defp digit_run(<<>>, _base), do: :ok
  defp digit_run(_rest, _base), do: :digits

  defp name(src, {:ok, n}, l, c, acc) do
    <<name::binary-size(^n), rest::binary>> = src
    lexeme(rest, name, {:name, {l, c}, name}, {l, c}, acc)
  end

  defp name(src, {:mistyped, n}, l, c, _acc) do
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {:missing_separator, run}}, l}
  end

  defp name(src, {kind, n}, l, c, _acc)
       when kind in [:after_bracket, :bracketed, :bracket, :detached, :after_subscripts] do
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {kind, run}}, l}
  end

  # M5-11: brackets that hold no subscripts a name may take are named whole, from the
  # name's start through the first `]` on the line.
  defp name(src, {:subscripts, _n}, l, c, _acc) do
    n = closing(src, 0)
    <<run::binary-size(^n), _::binary>> = src
    {:error, {{l, c}, __MODULE__, {:subscripts, run}}, l}
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
  defp name_part(<<?[, rest::binary>>, n), do: subscript(rest, n + 1)
  defp name_part(rest, n), do: dot(rest, n)

  # M5-11 (decision 151, §4.12's routine choice): a name part may be followed by an
  # element's subscripts, `temps[3]` or `grid[1,7]`, Logix's form (1756-PM004L pp.34-35),
  # and a declaration's type word by its sizes, `int[8]`, the name still one token: one to
  # any number of subscripts in one pair of brackets, split by `,` with no space, each a
  # tag's name or one number the lexer reads, `temps[16#3]`, `temps[-1]`, which the
  # compiler judges, so that `int[2,2,2,2]` lexes and is refused at its line. After the
  # `]` the name may go on in `.` parts, `t[2].dn`, and ends at anything else but a letter,
  # a digit or a bracket glued on, which makes the run one mistyped lexeme, `a[1][2]` or
  # `a[1]x`. Brackets that hold no subscript, a space or anything that is no name or
  # number, `a[]`, `a[1, 2]` or `a[1.5]`, are named whole through their `]`.
  defp subscript(<<h, rest::binary>>, n) when is_name_start(h), do: subscript_name(rest, n + 1)

  defp subscript(<<?-, d, _::binary>> = rest, n) when d in ?0..?9 do
    <<?-, digits::binary>> = rest
    subscript_number(rest, numeral(digits, 1), n)
  end

  defp subscript(<<d, _::binary>> = rest, n) when d in ?0..?9,
    do: subscript_number(rest, numeral(rest, 0), n)

  defp subscript(_rest, n), do: subscripts_refused(n)

  defp subscript_name(<<ch, rest::binary>>, n) when is_name_char(ch),
    do: subscript_name(rest, n + 1)

  defp subscript_name(rest, n), do: subscript_end(rest, n)

  defp subscript_number(rest, {kind, m}, n) when kind in [:decimal, :separated, :based] do
    <<text::binary-size(^m), tail::binary>> = rest
    one_number(number?(kind, text), tail, n + m)
  end

  defp subscript_number(_rest, _not_a_number, n), do: subscripts_refused(n)

  defp one_number(true, tail, n), do: subscript_end(tail, n)
  defp one_number(false, _tail, n), do: subscripts_refused(n)

  defp subscript_end(<<?,, rest::binary>>, n), do: subscript(rest, n + 1)
  defp subscript_end(<<?], rest::binary>>, n), do: subscripted(rest, n + 1)
  defp subscript_end(_rest, n), do: subscripts_refused(n)

  defp subscripted(<<?., _::binary>> = rest, n), do: dot(rest, n)

  defp subscripted(<<ch, _::binary>> = rest, n) when is_name_char(ch) or ch in [?[, ?]],
    do: {:after_subscripts, n + glued(rest, 0)}

  defp subscripted(_rest, n), do: {:ok, n}

  # A refusal is measured from the name's start, `n` bytes back from where it stopped: the
  # caller cuts the run, which closing/2 takes through the first `]` on its line.
  defp subscripts_refused(n), do: {:subscripts, n}

  defp integer_part(<<d, rest::binary>>, n) when d in ?0..?9, do: integer_part(rest, n + 1)

  defp integer_part(<<h, _::binary>> = rest, n) when is_name_start(h),
    do: {:mistyped, n + word(rest, 0)}

  defp integer_part(rest, n), do: dot(rest, n)

  defp dot(<<?., h, rest::binary>>, n) when is_name_start(h), do: name_part(rest, n + 2)
  defp dot(<<?., d, rest::binary>>, n) when d in ?0..?9, do: integer_part(rest, n + 2)

  # M5-9 (decision 160, §4.12's routine choice): a name's last part may be a tag's name in
  # brackets, `status.[n]` or `t1.acc.[n]`, a bit whose number the tag holds, Logix's form
  # (RM018A p.885, `variable3.[4]`); the name is still one token, and ends at its `]`.
  # Anything glued after the `]`, a letter, a digit, a `.` or a `[`, makes the run one
  # mistyped lexeme, `s.[n]x`, named whole.
  defp dot(<<?., ?[, h, rest::binary>>, n) when is_name_start(h), do: bracket(rest, n + 3)

  # Decision 213: a literal in the brackets, `s.[4]`, Logix's spelling of a literal bit
  # (RM018A p.885, `variable3.[4]`), is the name's last part too, one token kept as written,
  # which the compiler reads as the bit the literal's value numbers, `s.4`: any literal the
  # lexer reads as one number, `s.[16#4]`, `s.[1_0]` or `s.[-1]`, the last refused there as
  # outside the word's bits. Brackets that begin as a number and hold no one number closed
  # by its `]`, `s.[3x]`, `s.[8#3]` or `s.[3`, are named whole through their `]`.
  defp dot(<<?., ?[, ?-, d, _::binary>> = rest, n) when d in ?0..?9 do
    <<_::binary-size(3), unsigned::binary>> = rest
    in_brackets(rest, numeral(unsigned, 1), n)
  end

  defp dot(<<?., ?[, d, _::binary>> = rest, n) when d in ?0..?9 do
    <<_::binary-size(2), digits::binary>> = rest
    in_brackets(rest, numeral(digits, 0), n)
  end

  defp dot(<<?., ?[, ?-, _::binary>> = rest, n), do: {:bracketed, closing(rest, n)}

  # Since M5-9's review, brackets that no one name fills and closes, `s.[]`, `s.[n`,
  # `s.[n.m]` or `s.[ n ]`, are named whole through their `]`, and so is a bracket held
  # apart from its name's `.`, `s. [n]`, where until then each ended the name before its
  # `.`, an illegal character (provisional).
  defp dot(<<?., ?[, _::binary>> = rest, n), do: {:bracket, closing(rest, n)}

  defp dot(<<?., ws, _::binary>> = rest, n) when ws in [?\s, ?\t], do: spaced(rest, n)
  defp dot(_rest, n), do: {:ok, n}

  # A number in brackets: its lexeme `m` long after the `.[`, read as a number is, and
  # then its `]`, after which the name ends as one whose bracket holds a tag's name does.
  defp in_brackets(rest, {kind, m}, n) when kind in [:decimal, :separated, :based] do
    <<_::binary-size(2), text::binary-size(^m), tail::binary>> = rest
    numbered_bit(number?(kind, text), tail, {rest, n}, n + 2 + m)
  end

  defp in_brackets(rest, _mistyped, n), do: {:bracketed, closing(rest, n)}

  defp number?(:decimal, _text), do: true
  defp number?(kind, text), do: match?({:ok, _}, value(kind, text))

  defp numbered_bit(true, <<?], tail::binary>>, _at, m), do: closed(tail, m + 1)
  defp numbered_bit(_not_one, _tail, {rest, n}, _m), do: {:bracketed, closing(rest, n)}

  defp bracket(<<ch, rest::binary>>, n) when is_name_char(ch), do: bracket(rest, n + 1)

  defp bracket(<<?], rest::binary>>, n), do: closed(rest, n + 1)
  defp bracket(rest, n), do: {:bracket, closing(rest, n)}

  # A `.` and then spaces: a bracket after them is held apart from its name, and anything
  # else ends the name before the `.`, as it did.
  defp spaced(<<?., rest::binary>> = dotted, n), do: spaced(rest, dotted, n, 1)

  defp spaced(<<ws, rest::binary>>, dotted, n, gap) when ws in [?\s, ?\t],
    do: spaced(rest, dotted, n, gap + 1)

  defp spaced(<<?[, _::binary>> = rest, _dotted, n, gap), do: {:detached, closing(rest, n + gap)}
  defp spaced(_rest, _dotted, n, _gap), do: {:ok, n}

  # `n` plus the length of the run up to and through the first `]` on its line, and
  # anything glued after it, or, with none before a newline, a delimiter or the end, up to
  # the first space.
  defp closing(rest, n), do: closing(rest, n, through(rest, 0))

  defp closing(rest, n, {:closed, m}) do
    <<_::binary-size(^m), after_bracket::binary>> = rest
    n + m + glued(after_bracket, 0)
  end

  defp closing(rest, n, :open), do: n + unspaced(rest, 0)

  defp through(<<?], _::binary>>, m), do: {:closed, m + 1}

  defp through(<<ch, _::binary>>, _m) when ch in [?\n, ?\r, ?(, ?|, ?)] or ch > 127,
    do: :open

  defp through(<<_ch, rest::binary>>, m), do: through(rest, m + 1)
  defp through(<<>>, _m), do: :open

  defp unspaced(<<ch, rest::binary>>, m)
       when ch not in [?\s, ?\t, ?\n, ?\r, ?(, ?|, ?)] and ch < 128,
       do: unspaced(rest, m + 1)

  defp unspaced(_rest, m), do: m

  defp closed(<<ch, _::binary>> = rest, n) when is_name_char(ch) or ch in [?., ?[, ?]],
    do: {:after_bracket, n + glued(rest, 0)}

  defp closed(_rest, n), do: {:ok, n}

  defp glued(<<ch, rest::binary>>, n) when is_name_char(ch) or ch in [?., ?[, ?]],
    do: glued(rest, n + 1)

  defp glued(_rest, n), do: n

  # Each returns `n` plus the length of the run it starts on. Every lexeme is ASCII, so
  # its byte size is its width in characters. A mistyped run goes on through `.` parts, so
  # `1b.c` and `a.1b.c` are named whole, since `b.c` alone would be one name.
  defp word(<<ch, rest::binary>>, n) when is_name_char(ch), do: word(rest, n + 1)
  defp word(<<?., ch, rest::binary>>, n) when is_name_char(ch), do: word(rest, n + 2)
  defp word(_, n), do: n
end
