defmodule Logex.Name do
  @moduledoc false
  # RV-2 (the review after Milestone 6, H5): the one reading of a name the lexer cut,
  # which every reader of a lexed name shares, where until then several re-split names
  # with weaker rules of their own and raised on names the lexer gives.
  #
  # A name is its parts, split at each `.`: exact, since the lexer puts no `.` inside
  # brackets, `lines[1].gates[0]` the parts `lines[1]` and `gates[0]` and `w.[n]` the parts
  # `w` and `[n]`. Each part is one of four shapes, by the lexer's grammar
  # (`Logex.Lexer`'s moduledoc): a word, `w`; a word with one pair of brackets closing
  # it, an element's subscripts or a type word's sizes, `grid[1,7]` or `int[8]`, each
  # subscript a tag's name or one number; an integer, a bit's number, `3` of `w.3`; and,
  # last, a bit number in brackets, `[n]` or `[16#4]`. The readers here read a part, or a
  # whole name where they say so, and each is total: a text of no shape it reads is said
  # so, never raised on, since a host's key, an image's path and a store's line reach
  # some of them unlexed.
  #
  # The compiler splits an operand's name once into its parts and tells each part's
  # shape by its last byte in a clause's guard, as it did, so that a program of plain tags
  # compiles in what it did; only a part with brackets reaches a reader here.

  @doc false
  # A part with subscripts split into its word and each subscript as written,
  # `{"grid", ["1", "7"]}` for `grid[1,7]`, or nil for any text that is not one word and
  # one pair of brackets closing it, each subscript one or more characters and none a
  # bracket: `grid`, `int[2].[n]`, `lines[1].gates[0]`, `temps[`, `[n]` and `a[]` among
  # them. A dotted word before the brackets, `x.y[0]`, is read as its word, `x.y`, so that
  # a caller that looks the word up is told it is none.
  def element(name) when is_binary(name),
    do: element_at(:binary.split(name, ["[", "]"], [:global]), name)

  # Exactly two brackets, the first a `[` straight after the word and the second the `]`
  # that ends the name, read in one split: an element's name costs what `Logex.Array`'s
  # cut at the first `[` did but a reduction or two (RV-2's review), however its brackets
  # are written.
  defp element_at([word, inside, ""], name)
       when word != "" and binary_part(name, byte_size(word), 1) == "[" and
              binary_part(name, byte_size(name) - 1, 1) == "]",
       do: filled(:binary.split(inside, ",", [:global]), word)

  defp element_at(_parts, _name), do: nil

  defp filled([text] = texts, word) when text != "", do: {word, texts}
  defp filled([one, two] = texts, word) when one != "" and two != "", do: {word, texts}
  defp filled(texts, word), do: every_filled(:lists.member("", texts), texts, word)

  defp every_filled(false, texts, word), do: {word, texts}
  defp every_filled(true, _texts, _word), do: nil

  @doc false
  # A subscript as written: `{:literal, n}`, the number one integer literal spells, `16#a`
  # 10, or `{:tag, name}`, a tag's name, whose value a scan reads (M5-12, decision 152). A
  # text that begins as a number and is no one integer literal, which the lexer never gives
  # in a name, is read as no number, `{:tag, text}`, for the caller to refuse.
  def subscript(<<d, _::binary>> = text) when d in ?0..?9 or d == ?-,
    do: one_literal(Logex.Lexer.tokenize(text), text)

  def subscript(text), do: {:tag, text}

  defp one_literal({:ok, [{:int_lit, _, value}], _line}, _text), do: {:literal, value}
  defp one_literal({:ok, [{:int_lit, _, value, _spelling}], _line}, _text), do: {:literal, value}
  defp one_literal(_no_one_literal, text), do: {:tag, text}

  @doc false
  # A last part's bit number in brackets, `[n]` or `[16#4]`: `{:tag, "n"}`, the tag that
  # holds it (M5-9, decision 160), or `{:literal, 4}`, the number a literal spells
  # (decision 213), read as a subscript is; nil for a text of no such shape.
  def bracketed(<<?[, _::binary>> = part)
      when byte_size(part) > 2 and binary_part(part, byte_size(part) - 1, 1) == "]",
      do: subscript(binary_part(part, 1, byte_size(part) - 2))

  # RV-2's review: any other text, `x`, `[`, `[1` or `[]`, is no bit number in brackets, nil,
  # so that this reader is total as the others are.
  def bracketed(part) when is_binary(part), do: nil

  @doc false
  # Decision 384 (the maintainer, 2026-11-01): an element a host or the forces file names
  # by numbers, each subscript one integer literal, is the element of their values, so
  # `temps[03]` and `temps[16#3]` name `temps[3]`, a based literal by its value too
  # (decision 426), and `w[01,2]` `w[1,2]`, as `put_inputs/3`
  # and `get/2` read a subscript (decisions 222 and 312): the name by its values, or the
  # text as it is where it is no element named by numbers, `temps[i]`, `temps` or `x.y`.
  # Since the review of RV-10 each subscript is the literal and nothing else, as the lexer
  # cuts a name, so that `temps[3 ]` and `temps[3//x]`, which `get/2` and the forces file
  # take as no name, are none here either, where until the review the lexer's skipping of
  # a space or a comment after the number read them as `temps[3]`.
  def by_value(name) when is_binary(name), do: valued(element(name), name)

  defp valued({word, subscripts}, name),
    do: literals(Enum.map(subscripts, &exact/1), word, name)

  defp valued(nil, name), do: name

  defp exact(text), do: exact_literal(Logex.Lexer.tokenize(text), text)

  defp exact_literal({:ok, [{:int_lit, _, value}], _line}, text),
    do: plain_literal(Integer.to_string(value) == text, value)

  defp exact_literal({:ok, [{:int_lit, _, value, text}], _line}, text), do: {:literal, value}
  defp exact_literal(_other, text), do: {:tag, text}

  defp plain_literal(true, value), do: {:literal, value}
  defp plain_literal(false, value), do: {:tag, value}

  defp literals(subscripts, word, name),
    do: literal_name(Enum.all?(subscripts, &match?({:literal, _}, &1)), {word, subscripts}, name)

  defp literal_name(true, {word, subscripts}, _name),
    do:
      word <>
        "[" <> Enum.map_join(subscripts, ",", fn {:literal, n} -> Integer.to_string(n) end) <> "]"

  defp literal_name(false, _element, name), do: name

  @doc false
  # Decision 527 (RV-26's review): a lexed name with each number in it by its value, as a
  # store's digest reads a program's text: each subscript or size that is one integer
  # literal and nothing else, `arr[2]` of `arr[16#2]`, `arr[02]` or `arr[0_2]`, `g[1,i]` of
  # `g[01,i]` and `int[4]` of `int[004]`, and a bit's number, `w.3` of `w.03`, each by its
  # plain decimal, as a literal outside a name is; and since decision 532 (RV-27) a literal
  # bit number in brackets as the plain bit it names, `w.4` of `w.[4]`, `w.[16#4]` or
  # `w.[04]`, read by bracketed/1 as the compiler reads it, the very bit (decision 213). A
  # tag's name in brackets, `w.[n]` or `arr[i]`, and every word as written, its case among
  # them, which a store's digest reads past this (`Logex.Retain`). Total on a text: a part
  # of no shape it reads is kept as written. A name with no `.` and no `[`, most of a
  # program's, is looked at once and given back.
  def each_by_value(name) when is_binary(name),
    do: parted_by_value(:binary.match(name, [".", "["]), name)

  defp parted_by_value(:nomatch, name), do: name

  defp parted_by_value(_found, name),
    do: Enum.map_join(:binary.split(name, ".", [:global]), ".", &part_by_value/1)

  defp part_by_value(<<?[, _::binary>> = part), do: plain_bit(bracketed(part), part)

  defp part_by_value(<<d, _::binary>> = part) when d in ?0..?9,
    do: bit_by_value(Integer.parse(part), part)

  defp part_by_value(part)
       when byte_size(part) > 0 and binary_part(part, byte_size(part) - 1, 1) == "]",
       do: subscripted_by_value(element(part), part)

  defp part_by_value(part), do: part

  defp plain_bit({:literal, n}, _part), do: Integer.to_string(n)
  defp plain_bit(_tag_or_none, part), do: part

  defp bit_by_value({n, ""}, _part), do: Integer.to_string(n)
  defp bit_by_value(_other, part), do: part

  defp subscripted_by_value({word, subscripts}, _part),
    do: word <> "[" <> Enum.map_join(subscripts, ",", &subscript_by_value/1) <> "]"

  defp subscripted_by_value(nil, part), do: part

  defp subscript_by_value(text), do: subscript_text(exact(text), text)

  defp subscript_text({:literal, n}, _text), do: Integer.to_string(n)
  defp subscript_text(_tag, text), do: text

  @doc false
  # RV-6 (decision 352): an element's name as logex spells it, `Logex.Array.name/2`'s,
  # `lane_t[2]` or `grid[1,7]`, its word and each subscript's value, `{"grid", [1, 7]}`,
  # read with no lexer, each subscript plain decimal digits, at most 18 of them, which the
  # lexer would read as the same integer; nil for any other text, `temps[03]` among them,
  # whose reader is element/1 and subscript/1. An online edit's switch reads each element
  # it moves by its name, and read through the lexer each took some 70 reductions a
  # subscript where this takes a few.
  def spelled(name) when is_binary(name), do: spelled_of(element(name))

  defp spelled_of({word, texts}), do: decimals(texts, word, [])
  defp spelled_of(nil), do: nil

  defp decimals([], word, values), do: {word, :lists.reverse(values)}

  defp decimals([<<d, _::binary>> = text | texts], word, values)
       when d in ?1..?9 and byte_size(text) <= 18,
       do: decimal(digits?(text), text, {texts, word, values})

  defp decimals(["0" | texts], word, values), do: decimals(texts, word, [0 | values])
  defp decimals(_texts, _word, _values), do: nil

  defp decimal(true, text, {texts, word, values}),
    do: decimals(texts, word, [:erlang.binary_to_integer(text) | values])

  defp decimal(false, _text, _rest), do: nil

  defp digits?(<<>>), do: true
  defp digits?(<<d, rest::binary>>) when d in ?0..?9, do: digits?(rest)
  defp digits?(_text), do: false

  @doc false
  # The word before a text's first bracket, however its brackets are written, `temps` of
  # `temps[2` or `temps[1, 2]`, or nil where it has none: how a host's key that names no
  # element is told which array it reached for.
  def word(text) when is_binary(text), do: word_of(:binary.split(text, "["))

  defp word_of([_text]), do: nil
  defp word_of([word, _bracketed]), do: word

  @doc false
  # A declaration's type word's base, `gate` of `gate[4]`, or the word itself where it has
  # no sizes or is no word with sizes, `ton`, `a.b` or `int[2].[n]`: how the loader finds
  # the block a word names and a message names an array's type.
  def base(word), do: base_of(element(word), word)

  defp base_of({base, _sizes}, _word), do: base
  defp base_of(nil, word), do: word
end
