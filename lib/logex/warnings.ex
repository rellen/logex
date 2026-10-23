defmodule Logex.Warnings do
  @moduledoc """
  What compiles but is probably a mistake (M1-5), as `%Logex.Diagnostic{severity:
  :warning}` in line order. A program that does not compile gets none.

  - a tag declared but used by no rung;
  - a `var_output` a rung reads but none writes: it stays at its initial value;
  - a second `ote` on one tag: only the last one in the scan decides it;
  - an `ons` storage bit that another instruction writes (M1-6): the one-shot then fires
    on the wrong scans. A second `ons` on it is an error (`Logex.Compiler`). Since M3-4 so
    is an `osr`'s or an `osf`'s storage bit, and a coil's pulse bit is written as an
    `ote` writes its tag, so a second coil on it is the second-`ote` warning;
  - a comparison of two literals (M1-6): its result never changes; since M3-3 so is an
    arithmetic instruction whose every source is a literal, `add 2 3 x` or `neg 5 x`, and
    since M5-8 a bitwise one, `and 16#0f 3 x`, `not 0 x` or `shl 1 3 x`,
    and since decision 178 a conversion of a literal, `dint_to_sint 129 trim`; and since
    decision 187 a comparison of a tag with a literal at its type's limit whose result
    never changes, `ge count 0` with a `usint` `count`;
  - a timer no `ton` runs (M1-6): it never times; since M3-1 any built-in instance no
    instruction of its type runs, in its type's words, a counter no `ctu` or `ctd` runs:
    it never counts;
  - an instance of a user function block no `cal` runs (M2-5): it never runs;
  - a long timer's preset that is no whole number of milliseconds (M5-6, §4.12's routine
    choice), `ton t 1500000` on a `ton_ltime`: it times as the next whole millisecond; and
    since decision 196 a literal that is no whole number of them taken beside a long
    timer's `.pre` or `.acc` by `move`, a conversion, a comparison, `add` or `sub`, `ge
    cure.acc 3000`;
  - a label no `jmp` names (M3-5): nothing jumps to its rung.

  A write on a rung a jump may skip is still a write (decision 107): two `ote`s on one tag,
  one in a section a `jmp` skips and one outside it, are still two, the warning saying the
  last one in the scan decides it, which is the one that ran last. The maintainer
  confirmed it after M3-5's review, for sections that jump over each other too: the
  warnings read the program's text, not which rungs run.

  A tag declared from Elixir (`Logex.Tag.new!/4`) has no line and is never warned about.
  """

  alias Logex.{Declarations, Diagnostic, FbType, Parser, Tag, Walk}
  import Logex.Parser, only: [is_int_lit: 1]

  @one_shots Walk.one_shots()

  @doc """
  The warnings for lowered `rungs` checked against the tag table `tags`, each instance's
  type itself: for a block's body, `Logex.Program.typed_tags/1`'s table (M2-5).
  """
  def of(rungs, tags) do
    instructions = Walk.instructions(rungs)
    uses = Walk.uses(rungs, tags)
    # Grouped once, so the pass stays linear in the program's size.
    accesses =
      Enum.group_by(uses, fn {_, name, _, _} -> name end, fn {access, _, _, _} -> access end)

    # M1-6: each `ons` storage bit, to the line of the one `ons` that writes it. The
    # compiler refuses a second `ons` on one bit, so a program that compiles has one. M3-4:
    # each one-shot's, an `ons`, an `osr` or an `osf`, to its line and symbol.
    # Since M5-8's review each with its bit as written, `status.03`, which a message quotes.
    owners =
      Map.new(Walk.storage_bits(rungs), fn {bit, line, symbol} -> {bit, {line, symbol}} end)
      |> written_bits(instructions)

    tags
    |> Map.values()
    |> Enum.filter(& &1.line)
    |> Enum.flat_map(&about(&1, Map.get(accesses, &1.name, [])))
    |> Kernel.++(second_otes(instructions, tags, owners))
    |> Kernel.++(storage_writes(instructions, tags, owners))
    |> Kernel.++(Enum.flat_map(instructions, &constant/1))
    |> Kernel.++(Enum.flat_map(instructions, &at_limit(&1, tags)))
    |> Kernel.++(unjumped(instructions))
    |> Kernel.++(Enum.flat_map(instructions, &between_milliseconds(&1, tags)))
    |> Kernel.++(Enum.flat_map(instructions, &timed_literals(&1, tags)))
    |> Enum.sort_by(& &1.line)
  end

  # M5-6 (§4.12's routine choice, decision 158): a long timer counts nanoseconds on a clock
  # of whole milliseconds, so a preset that is no whole number of them is reached at the
  # next whole millisecond, `ton t 1500000` on a `ton_ltime` at 2 ms. A timer counted in
  # ms, and a counter, have no such preset; a program with a diagnostic gets no warning, so
  # the instance here is one the instruction runs.
  @runners FbType.runners()

  defp between_milliseconds({symbol, line, [{:name, _, name}, preset]}, tags)
       when symbol in @runners and is_int_lit(preset),
       do: between(per_ms(Map.get(tags, name)), {symbol, line, name, Parser.value(preset)})

  defp between_milliseconds(_instruction, _tags), do: []

  defp per_ms(%Tag{type: %FbType{body: nil} = type}), do: {FbType.rules(type).per_ms, type}
  defp per_ms(_no_built_in), do: {nil, nil}

  defp between({per_ms, type}, {symbol, line, name, preset})
       when is_integer(per_ms) and rem(preset, per_ms) != 0,
       do: [
         warning(
           line,
           "`#{symbol}` gives `#{name}` a preset of #{preset} ns, which is no whole number " <>
             "of milliseconds: #{Declarations.a_or_an(type.name)} counts whole milliseconds, " <>
             "so it times as the next whole millisecond, #{div(preset, per_ms) + 1} ms"
         )
       ]

  defp between(_whole, _run), do: []

  # M3-5 (decision 105): a label no `jmp` of its routine names. Its rung runs as any rung
  # does, so the label does nothing, and is likely left from a jump removed or misspelled
  # into another label. The labels a `jmp` names are gathered once.
  defp unjumped(instructions) do
    named = for {:jmp, _, [{:label, _, name}]} <- instructions, into: %{}, do: {name, true}

    for {:lbl, line, [{:label, _, name}]} <- instructions,
        not is_map_key(named, name),
        do: warning(line, "`#{name}` labels this rung, but no `jmp` names it: nothing jumps here")
  end

  defp about(%Tag{} = tag, []),
    do: [warning(tag.line, "`#{tag.name}` is declared but no rung uses it")]

  defp about(%Tag{section: :var_output} = tag, accesses), do: unwritten(:write in accesses, tag)

  defp about(%Tag{type: %FbType{body: nil}} = tag, accesses),
    do: unrun(:instance in accesses, tag)

  defp about(%Tag{type: %FbType{}} = tag, accesses), do: uncalled(:instance in accesses, tag)

  defp about(_tag, _accesses), do: []

  defp unrun(true, _tag), do: []

  # M3-1: in the type's words, from its rules (Logex.FbType.rules/1): what runs it, and
  # what it then never does.
  defp unrun(false, %Tag{type: type} = tag) do
    %{kind: kind, runs: runs} = FbType.rules(type)

    [
      warning(
        tag.line,
        "`#{tag.name}` is #{Logex.Declarations.instance_of(type)}, but no " <>
          "#{runners(Map.keys(runs))} runs it: it never #{does(kind)}"
      )
    ]
  end

  # A ctud's `ctu`, then its `ctd`.
  defp runners(symbols), do: Enum.map_join(Enum.sort(symbols, :desc), " or ", &"`#{&1}`")

  defp does(:timer), do: "times"
  defp does(:counter), do: "counts"

  # M2-5: as the timer's, saying `cal` (PLAN.md M2-5).
  defp uncalled(true, _tag), do: []

  defp uncalled(false, tag),
    do: [
      warning(
        tag.line,
        "`#{tag.name}` is #{Logex.Declarations.instance_of(tag.type)}, but no `cal` runs " <>
          "it: it never runs, and its members stay at their initial values"
      )
    ]

  defp unwritten(true, _tag), do: []

  defp unwritten(false, tag),
    do: [
      warning(
        tag.line,
        "`#{tag.name}` is a var_output, but no rung writes it: it stays at #{start(tag.initial)}"
      )
    ]

  defp start(nil), do: 0
  defp start(initial), do: initial

  # Each `ote` after the first on a tag declared in source cites the first. An `ons`
  # storage bit is left to storage_writes/3, which warns about every `ote` on it: the `ons`
  # writes it too, so the last `ote` need not be what decides it, and one instruction gets
  # one warning. The uses are walked in rung order, each tag's first `ote` kept in a map
  # that is only looked up, so the warnings on one line come in rung order, as
  # storage_writes/3's do (B10).
  #
  # M3-1: an `ote` names its target whole, a member by its path, `stock.r`, since a ctud's
  # `r` and `ld` are two bits logic writes; `Logex.Walk.uses/2` gives a member as its
  # instance.
  #
  # M3-4 (decision 101): a pulse coil writes its pulse bit on every run, as an `ote` writes
  # its tag, so `ote`, `osr` and `osf` are one set of coils here, each later one citing the
  # first in that one's words.
  #
  # M5-8 (decision 155): a coil on a bit, `ote status.3`, decides that bit as an `ote` on a
  # bool decides it, and so does any instruction that writes its word whole, `move x
  # status`: either after the other is the second-`ote` warning, at its own line, citing
  # the first in its words. Since M5-8's review so for a bit of a member and a write of the
  # member whole, `ote c.pv.3` and `move x c.pv` (provisional reading 9). A bit is keyed by
  # its number's value and quoted as written, `status.03`. A program with no coil on a bit
  # has no whole write to compare, and none is looked for.
  defp second_otes(instructions, tags, owners) do
    coils = Enum.flat_map(instructions, &coil_target/1)

    words =
      for {:coil, _key, word, _tag, _at, _shown} <- coils,
          word != nil,
          into: %{},
          do: {word, true}

    {warnings, _firsts} =
      instructions
      |> decisions(coils, words, tags)
      |> Enum.filter(&decides?(&1, tags, owners))
      |> Enum.flat_map_reduce({%{}, %{}, %{}}, &decided/2)

    warnings
  end

  defp decisions(_instructions, coils, words, _tags) when map_size(words) == 0, do: coils

  defp decisions(instructions, _coils, words, tags),
    do: Enum.flat_map(instructions, &(coil_target(&1) ++ whole_writes(&1, tags, words)))

  defp decides?({:coil, key, _word, tag, _at, _shown}, tags, owners),
    do: from_source?(tags, tag) and not Map.has_key?(owners, key)

  defp decides?({:whole, _word, tag, _at}, tags, _owners), do: from_source?(tags, tag)

  # A coil on a tag or member, keyed by its name, on no word; a coil on a bit, `status.3` on
  # the word `status`, or `c.pv.3` on the member `c.pv`; a whole write of a word or member.
  # `firsts` holds each coil's first, each word's first whole write, and each word's first
  # coiled bit.
  defp decided({:coil, key, nil, _tag, at, shown}, {coils, wholes, bitted}) do
    {warnings, coils} = later_ote(Map.fetch(coils, key), {key, shown}, at, coils)
    {warnings, {coils, wholes, bitted}}
  end

  defp decided({:coil, key, word, _tag, at, shown}, {coils, wholes, bitted}),
    do:
      bit_after(
        Map.fetch(coils, key),
        Map.fetch(wholes, word),
        {key, word, at, shown},
        {coils, wholes, bitted}
      )

  defp decided({:whole, word, _tag, at}, {coils, wholes, bitted}),
    do: whole_after(Map.fetch(bitted, word), at, {coils, Map.put_new(wholes, word, at), bitted})

  defp bit_after({:ok, first}, _whole, {_key, _word, {line, _symbol}, shown}, firsts),
    do: {[second_ote(shown, first, line)], firsts}

  defp bit_after(
         :error,
         {:ok, {first, symbol}},
         {key, word, {line, _} = at, shown},
         {coils, wholes, bitted}
       ),
       do:
         {[
            warning(
              line,
              "`#{shown}` is a bit of `#{word}`, which the `#{symbol}` #{where(first, line)} " <>
                "writes whole: #{last()}"
            )
          ], {Map.put(coils, key, at), wholes, Map.put_new(bitted, word, {shown, at})}}

  defp bit_after(:error, :error, {key, word, at, shown}, {coils, wholes, bitted}),
    do: {[], {Map.put(coils, key, at), wholes, Map.put_new(bitted, word, {shown, at})}}

  defp whole_after(:error, _at, firsts), do: {[], firsts}

  defp whole_after({:ok, {bit, first}}, {line, _symbol}, firsts),
    do: {[second_ote(bit, first, line)], firsts}

  # Every tag or member an instruction other than a coil writes whole, by its write slots,
  # among the words whose bits a coil names.
  defp whole_writes({symbol, _line, _operands}, _tags, _words)
       when symbol in [:ote, :osr, :osf, :ons],
       do: []

  defp whole_writes({symbol, line, operands} = instruction, tags, words),
    do:
      for(
        {{:write, _type}, operand} <-
          Enum.zip(Logex.Compiler.signature(instruction, tags), operands),
        {word, tag} <- whole(operand),
        is_map_key(words, word),
        do: {:whole, word, tag, {line, symbol}}
      )

  defp whole({:name, _, name}), do: [{name, name}]
  defp whole({:member, _, [instance | _] = path}), do: [{Enum.join(path, "."), instance}]
  defp whole(_bit_or_literal), do: []

  defp coil_target({:ote, line, [target]}), do: target(target, line, :ote)

  defp coil_target({symbol, line, [_storage, pulse]}) when symbol in [:osr, :osf],
    do: target(pulse, line, symbol)

  defp coil_target(_instruction), do: []

  defp target({:name, _, name}, line, symbol),
    do: [{:coil, name, nil, name, {line, symbol}, name}]

  defp target({:member, _, [instance | _] = path}, line, symbol) do
    name = Enum.join(path, ".")
    [{:coil, name, nil, instance, {line, symbol}, name}]
  end

  defp target({:bit, _, [container | _] = path, _n, _mask, shown} = bit, line, symbol),
    do: [{:coil, Walk.bit_name(bit), Enum.join(path, "."), container, {line, symbol}, shown}]

  defp target(_literal, _line, _symbol), do: []

  defp later_ote(:error, {key, _shown}, first, firsts), do: {[], Map.put(firsts, key, first)}

  defp later_ote({:ok, first}, {_key, shown}, {line, _symbol}, firsts),
    do: {[second_ote(shown, first, line)], firsts}

  # M1-6: every other write to an `ons` storage bit declared in source, before or after
  # the `ons` in the scan, is warned about at its own line, citing the `ons`. The uses are
  # walked in rung order, not grouped into a map, whose order stops being sorted past 32
  # keys. M3-4: so for every one-shot's storage bit (decision 80), every write but the
  # one-shot's own, its first operand, a coil's pulse bit among them.
  #
  # M5-8 (decision 155): a storage bit may be a bit of a word, `status.3`, written by a coil
  # on it and by any write of the word whole, `move x status`, each warned of, a bit quoted
  # as written. A program with no one-shot has no storage bit to write, and none is looked
  # for.
  defp storage_writes(_instructions, _tags, owners) when map_size(owners) == 0, do: []

  defp storage_writes(instructions, tags, owners) do
    words =
      owners |> Map.keys() |> Enum.filter(&String.contains?(&1, ".")) |> Enum.group_by(&word_of/1)

    for instruction <- instructions,
        {operand, line, symbol} <- others(instruction, written(instruction, tags)),
        {name, shown} <- storage_names(operand, words),
        {:ok, first} <- [Map.fetch(owners, name)],
        from_source?(tags, word_of(name)),
        do: storage_write(symbol, shown(shown, first), first, line)
  end

  # Each storage bit that is a bit of a word, with its spelling as its one-shot writes it.
  defp written_bits(owners, instructions),
    do:
      Enum.reduce(instructions, owners, fn
        {symbol, _line, [{:bit, _, [_], _, _, shown} = bit | _]}, owners
        when symbol in @one_shots ->
          Map.update!(owners, Walk.bit_name(bit), &with_shown(&1, shown))

        _instruction, owners ->
          owners
      end)

  defp with_shown({line, owner}, shown), do: {line, owner, shown}
  defp with_shown(shown_already, _shown), do: shown_already

  # A bit as the write names it, or, where a whole write reaches it, as its one-shot does.
  defp shown(nil, {_first, _owner, shown}), do: shown
  defp shown(shown, _owner), do: shown

  defp others({symbol, _line, _operands}, [_storage | uses]) when symbol in @one_shots, do: uses
  defp others(_instruction, uses), do: uses

  # Each operand an instruction writes, by its slots, `cal`'s var_outputs among them.
  defp written({symbol, line, operands} = instruction, tags),
    do:
      for(
        {{:write, _type}, operand} <-
          Enum.zip(Logex.Compiler.signature(instruction, tags), operands),
        do: {operand, line, symbol}
      )

  # The storage bits a write reaches: a bool's or a bit's own name, and every bit of a word
  # written whole, in name order.
  defp storage_names({:name, _, name}, words),
    do: [{name, name} | Enum.map(Enum.sort(Map.get(words, name, [])), &{&1, nil})]

  defp storage_names({:bit, _, [_], _, _, shown} = bit, _words), do: [{Walk.bit_name(bit), shown}]
  defp storage_names(_member, _words), do: []

  # A storage bit's tag: a bool's own name, or the word a bit of one is in.
  defp word_of(name), do: hd(String.split(name, "."))

  defp storage_write(symbol, name, {first, owner, _shown}, line),
    do: storage_write(symbol, name, {first, owner}, line)

  defp storage_write(symbol, name, {first, owner}, line),
    do:
      warning(
        line,
        "`#{symbol}` writes `#{name}`, the storage bit of the `#{owner}` " <>
          "#{where(first, line)}: the one-shot then fires on the wrong scans"
      )

  defp where(line, line), do: "in this rung"
  defp where(first, _line), do: "on line #{first}"

  # M1-6: a comparison of two literals compiles, as IEC's EQ(1, 1) does, but its result
  # never changes.
  @comparisons [:eq, :ne, :lt, :gt, :le, :ge]

  # Each literal is quoted as written (decision 202).
  defp constant({symbol, line, [a, b]})
       when symbol in @comparisons and is_int_lit(a) and is_int_lit(b),
       do: [
         warning(
           line,
           "`#{symbol}` compares two literals, #{shown(a)} and #{shown(b)}: its result never " <>
             "changes"
         )
       ]

  # M3-3: an arithmetic instruction whose every source is a literal compiles, as IEC's
  # ADD(2, 3) does, but its result never changes. Since M5-8 so does a bitwise one, a
  # shift's count among its sources, `shl 1 3 mask` (provisional, decisions 98 and 178).
  @arithmetic [:add, :sub, :mul, :div, :mod, :and, :or, :xor, :shl, :shr, :rol, :ror]

  defp constant({symbol, line, [a, b, _destination]})
       when symbol in @arithmetic and is_int_lit(a) and is_int_lit(b),
       do: [
         warning(
           line,
           "`#{symbol}` reads two literals, #{shown(a)} and #{shown(b)}: its result never " <>
             "changes"
         )
       ]

  # Decision 178: a conversion of a literal compiles, as `neg 5 x` does, and is told so in
  # the same words: `dint_to_sint 129 trim` always writes -127 with no power. Its symbols
  # are the type table's, as `Logex.Compiler` generates them, every ordered pair of two
  # integer types, and since M5-8 of the bit strings too (decision 148).
  @conversions for(
                 from <- Declarations.convertible(),
                 to <- Declarations.convertible(),
                 word = Declarations.conversion(from, to),
                 do: String.to_atom(word)
               )

  @one_source [:neg, :abs, :not] ++ @conversions

  defp constant({symbol, line, [a, _destination]}) when symbol in @one_source and is_int_lit(a),
    do: [warning(line, "`#{symbol}` reads a literal, #{shown(a)}: its result never changes")]

  defp constant(_instruction), do: []

  # Decision 187: a comparison of a tag with a literal at its type's own limit, which
  # decision 183 compiles, is warned of in the all-literal warning's words wherever its
  # result never changes. With the tag of type lo..hi on the left, `ge x lo` always passes
  # power and `lt x lo` never does, `le x hi` always and `gt x hi` never; with the literal
  # on the left the mirror, `le lo x` and `ge hi x` always, `gt lo x` and `lt hi x` never.
  # `eq` and `ne` at a limit, and every comparison inside the range, can go either way, and
  # a literal outside the range is decision 183's refusal.
  defp at_limit({symbol, line, [operand, literal]}, tags)
       when symbol in @comparisons and is_int_lit(literal),
       do: limited(integer_type(operand, tags), {symbol, :right}, {operand, literal}, line)

  defp at_limit({symbol, line, [literal, operand]}, tags)
       when symbol in @comparisons and is_int_lit(literal),
       do: limited(integer_type(operand, tags), {symbol, :left}, {operand, literal}, line)

  defp at_limit(_instruction, _tags), do: []

  defp limited({:ok, type}, at, {operand, literal}, line) do
    lo..hi//_ = Declarations.range(type)
    fixed(fixed?(at, limit(Parser.value(literal), lo, hi)), at, {operand, literal, type}, line)
  end

  defp limited(:error, _at, _compared, _line), do: []

  defp limit(lo, lo, _hi), do: :lowest
  defp limit(hi, _lo, hi), do: :highest
  defp limit(_value, _lo, _hi), do: :inside

  # The pairs whose result never changes, and the side of the type the literal is at.
  defp fixed?({symbol, :right}, :lowest) when symbol in [:ge, :lt], do: {true, "below"}
  defp fixed?({symbol, :right}, :highest) when symbol in [:le, :gt], do: {true, "above"}
  defp fixed?({symbol, :left}, :lowest) when symbol in [:le, :gt], do: {true, "below"}
  defp fixed?({symbol, :left}, :highest) when symbol in [:ge, :lt], do: {true, "above"}
  defp fixed?(_at, _limit), do: false

  defp fixed({true, side}, {symbol, order}, {operand, literal, type}, line),
    do: [
      warning(
        line,
        "`#{symbol}` compares #{in_order(order, shown(operand), shown(literal))}, and " <>
          "#{Declarations.a_type(type)} holds nothing #{side} #{shown(literal)}: its result " <>
          "never changes"
      )
    ]

  defp fixed(false, _at, _compared, _line), do: []

  defp in_order(:right, tag, literal), do: "#{tag} with #{literal}"
  defp in_order(:left, tag, literal), do: "#{literal} with #{tag}"

  defp shown({:name, _, name}), do: "`#{name}`"
  defp shown({:member, _, path}), do: "`#{Enum.join(path, ".")}`"
  defp shown(literal) when is_int_lit(literal), do: "`#{Parser.spelling(literal)}`"

  # An operand's integer type, a tag's or a member's of the built-in instance that holds
  # it; anything else, a bool or a member of a user block's instance, which no comparison
  # takes, is passed over. Since M5-8's review a bit string too, which compares as unsigned
  # (decision 155), so `ge status 0` on a `word` is warned as on a `uint` (provisional).
  @integers Declarations.integers() ++ Declarations.bit_strings()

  defp integer_type({:name, _, name}, tags), do: of_integer(Map.get(tags, name))

  defp integer_type({:member, _, [instance, member]}, tags),
    do: member_integer(Map.get(tags, instance), member)

  defp integer_type(_other, _tags), do: :error

  defp of_integer(%Tag{type: type}) when type in @integers, do: {:ok, type}
  defp of_integer(_other), do: :error

  defp member_integer(%Tag{type: %FbType{body: nil} = type}, member),
    do: member_type(FbType.member(type, member))

  defp member_integer(_other, _member), do: :error

  defp member_type({:ok, %FbType.Member{type: type}}) when type in @integers, do: {:ok, type}
  defp member_type(_other), do: :error

  # Decision 196: a literal an instruction takes beside a long timer's `.pre` or `.acc`,
  # its time in ns, is a time in ns too, and one that is no whole number of milliseconds
  # is warned of as a preset is: `ge cure.acc 3000` on a `ton_ltime` reads 3000 ns, where a
  # rung ported from a `ton` meant 3 s. The instructions whose literal is such a time:
  # `move` and the conversions, which write it into the member; the six comparisons, which
  # compare it with the member; and `add` and `sub`, which add it to the member or take it
  # away, or write their sum into it. A factor or a divisor, `mul`, `div` and `mod`, and a
  # negation, `neg` and `abs`, are no time, and are not looked at. The first long timer's
  # member among the operands is the one named; each literal that is no whole number of
  # its milliseconds is a warning.
  @timed [:move, :add, :sub] ++ @comparisons ++ @conversions

  defp timed_literals({symbol, line, operands}, tags) when symbol in @timed,
    do: timed(Enum.find_value(operands, &long_member(&1, tags)), {symbol, line, operands})

  defp timed_literals(_instruction, _tags), do: []

  defp long_member({:member, _, [instance, member]} = operand, tags)
       when member in ["pre", "acc"],
       do: long(per_ms(Map.get(tags, instance)), operand)

  defp long_member(_operand, _tags), do: nil

  defp long({per_ms, type}, operand) when is_integer(per_ms) and per_ms != 1,
    do: {operand, type, per_ms}

  defp long(_plain_or_none, _operand), do: nil

  defp timed(nil, _instruction), do: []

  defp timed({member, type, per_ms}, {symbol, line, operands}),
    do:
      for(
        literal <- operands,
        is_int_lit(literal),
        value = Parser.value(literal),
        rem(value, per_ms) != 0,
        do:
          warning(
            line,
            "#{taking(symbol, operands)}, where #{shown(member)} is " <>
              "#{Declarations.a_or_an(type.name)}'s time in nanoseconds: #{value} ns is no " <>
              "whole number of milliseconds, and #{Declarations.a_or_an(type.name)} counts " <>
              "whole milliseconds"
          )
      )

  # What the instruction does with its operands, in its own words.
  defp taking(symbol, [a, b]) when symbol in @comparisons,
    do: "`#{symbol}` compares #{shown(a)} with #{shown(b)}"

  defp taking(symbol, [source, destination]),
    do: "`#{symbol}` writes #{shown(source)} into #{shown(destination)}"

  defp taking(:add, [a, b, destination]),
    do: "`add` adds #{shown(a)} and #{shown(b)} into #{shown(destination)}"

  defp taking(:sub, [a, b, destination]),
    do: "`sub` takes #{shown(b)} from #{shown(a)} into #{shown(destination)}"

  defp from_source?(tags, name),
    do: match?(%Tag{line: line} when line != nil, Map.get(tags, name))

  defp second_ote(name, {first, :ote}, line),
    do: warning(line, "`#{name}` already has an `ote` #{where(first, line)}: #{last()}")

  defp second_ote(name, {first, coil}, line),
    do:
      warning(
        line,
        "`#{name}` is already the pulse bit of the `#{coil}` #{where(first, line)}: #{last()}"
      )

  defp last, do: "the last one in the scan decides it"

  defp warning(line, message),
    do: %Diagnostic{stage: :validate, severity: :warning, line: line, message: message}
end
