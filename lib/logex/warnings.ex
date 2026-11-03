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
  - a label no `jmp` names (M3-5): nothing jumps to its rung;
  - since decision 219, a real literal with more digits than the real its slot computes
    in keeps, `move 16777217.0 r` into a `real`: it is held as 16777216.0, where `0.1` and
    `37.1`, each the shortest text of the single nearest it, are not warned of; and since
    decision 227 a declaration's real initial value so, `var sp real 16777217.0`
    (`initials/2`, which the compiler calls with the parse tree's declaration lines).

  Since decision 221 a bit of an element, `faults[2].3`, is a bit of the element's word
  for each of them, keyed by its subscripts' and number's values, a write of the element
  whole, `move x faults[2]`, a whole write of that word.

  Since M5-11 an element, `lamps[2]`, is a tag of its own for each of them, keyed by its
  subscripts' values and quoted as written, so a second `ote` on `lamps[2]` and `lamps[02]`
  is the second-`ote` warning, and an array is used where any of its elements is.

  A write through a tag subscript, `ote lamps[slot]`, may write any element of its array,
  so beside another write of the array it is the second-`ote` warning, told the array it
  may write through a tag subscript (M5-12). Since RV-9 (decision 372) two writes of one
  array whose literal subscripts differ in any place never share an element and are not
  warned, the rows of a lamp panel `ote ee[1,i]` and `ote ee[0,i]`, or `ote ee[0,i]` and
  `ote ee[1,3]`; two that may meet, `ee[i,0]` and `ee[j,0]`, or `ee[i]` and `ee[1]`, are
  warned as before, a write told the earliest that may meet it. So for an element's bit,
  `g[1,c].3` and `g[0,c].3`, and an element's member, `lc[0,i].r` and `lc[1,i].r`. Since
  RV-12 (decision 405) a bit's literal number is one more place, a bit a tag numbers and
  an element written whole a tag's, so two bits of one word array whose numbers differ,
  `w[i].3` and `w[j].4`, or `g[1,j].3` and `g[1,2].4`, never meet, in an array of one
  dimension too, and `w[i].3` and `w[j].[n]`, or `move x w[j]`, may; a member's bits are
  told apart by its path, the bit's number one more part of it (decision 257). And a
  one-shot's storage bit is judged as a write is: a write through a tag subscript writes
  only the storage bits its places may meet, so `ote e[i,0]` beside `ons e[1,1]`, or
  `ote w[i].4` beside `ons w[1].3`, is not warned, and `ote e[i,1]` or `ote w[i].3` is.

  Since RV-15 (decision 431) a member's word of an element, of an array of timers or
  counters, `l1[1].pv`, that some write reaches through a tag subscript is judged as a
  word array of its shape is, the member's word an element of the word array and its bits
  the element's bits: each write of the word, of a literal element or through a tag
  subscript, is told every first a word array's write of its shape would be told, in a
  word array's words, either first. So `ote l1[i].pv.3` beside `ote l1[j].pv.[n]`, `ote
  l1[1].pv.[n]` beside `ote l1[i].pv.3` or `move 5 l1[i].pv`, and `ote l1[1].pv.3` beside
  `move 5 l1[i].pv` are warned, and `ote l1[1].pv.[n]` beside `ote l1[2].pv.3`, whose
  literal places differ, is not. The member rules (decisions 253, 257 and 288) judge the
  member's writes as before, and a warning both give in the same words is told once;
  where a member rule cites another first than the word array's would, the write is told
  both, so a write may be told of three firsts where a word array's is told of two at
  most (provisional). Two coils through the very tags are told the bit already has one,
  and a coil beside another write through them is not warned (decision 246); a bit a tag
  numbers beside its word written whole through the very tags is warned, as a word
  array's is (provisional), where a literal bit beside it stays quiet (decision 288). A
  latch of a literal element's literal bit, which a word array's rules compare with
  nothing, is warned beside a coil through a tag subscript on that bit (decision 257) and
  beside one on a bit a tag numbers (provisional), and is quiet beside a coil a tag
  numbers of its own literal element, as a word array's is. A member's word no write
  reaches through a tag subscript has only literal elements' writes, which the member
  rules judge as a word array's are, and costs what it did. A one-shot keeps no storage
  bit in a member, so no write of one meets a storage bit.

  A write on a rung a jump may skip is still a write (decision 107): two `ote`s on one tag,
  one in a section a `jmp` skips and one outside it, are still two, the warning saying the
  last one in the scan decides it, which is the one that ran last. The maintainer
  confirmed it after M3-5's review, for sections that jump over each other too: the
  warnings read the program's text, not which rungs run.

  A tag declared from Elixir (`Logex.Tag.new!/4`) has no line and is never warned about.
  """

  alias Logex.{Compiler, Declarations, Diagnostic, FbType, Parser, Tag, Walk}

  # An element's name of its array, `w[2]` of `w`, as a coil on a bit of one names its word.
  defguardp is_element(word, tag)
            when is_binary(word) and byte_size(word) > byte_size(tag) and
                   binary_part(word, byte_size(tag), 1) == "["

  import Logex.Parser, only: [is_int_lit: 1, is_literal: 1, is_real_lit: 1]

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

    run = elements_run(Enum.any?(Map.values(tags), &instances?/1), instructions)

    tags
    |> Map.values()
    |> Enum.filter(& &1.line)
    |> Enum.flat_map(&about(&1, Map.get(accesses, &1.name, []), run))
    |> Kernel.++(second_otes(instructions, tags, owners))
    |> Kernel.++(storage_writes(instructions, tags, owners))
    |> Kernel.++(Enum.flat_map(instructions, &constant/1))
    |> Kernel.++(Enum.flat_map(instructions, &by_literal(&1, tags)))
    |> Kernel.++(unjumped(instructions))
    |> Kernel.++(Enum.flat_map(instructions, &between_milliseconds(&1, tags)))
    |> Kernel.++(Enum.flat_map(instructions, &timed_literals(&1, tags)))
    |> Enum.sort_by(& &1.line)
  end

  @doc """
  Decision 227: the warnings of a routine's declaration lines, a real initial value with
  more digits than its tag's real keeps, `var sp real 16777217.0`, told as decision 219
  tells a literal in a rung, "`16777217.0` is more precise than a real keeps: it is held
  as 16777216.0", at its declaration's line, an array's initial list element by element.
  `rungs` are the routine's rungs as `Logex.Parser.parse/1` gives them, whose literal
  leaves keep each value's spelling, which the tag table does not (decision 202); `reals`
  is the routine's real tags, by name, `Logex.Program`'s `reals`, nil for none, so a
  routine of no real looks at nothing.
  """
  def initials(_rungs, nil), do: []

  def initials(rungs, reals),
    do: Enum.flat_map(rungs, &initial_of(&1, reals)) |> Enum.sort_by(& &1.line)

  # M6-1: a line with a qualifier after its section word, `var retain sp real 37.1`
  # (decision 267), told by the qualifier's length and then by the word itself.
  defp initial_of(
         {:rung, [{:name, line, section}, {:name, _, word}, {:name, _, name}, _type | values]},
         reals
       )
       when is_map_key(reals, name) and byte_size(word) in [6, 10],
       do:
         qualified_initial(
           Declarations.reserved(word),
           {line, section},
           Map.fetch!(reals, name),
           values
         )

  defp initial_of({:rung, [{:name, line, section}, {:name, _, name}, _type | values]}, reals)
       when is_map_key(reals, name),
       do: initial_in(Declarations.reserved(section), line, Map.fetch!(reals, name), values)

  defp initial_of(_rung, _reals), do: []

  defp qualified_initial(:qualifier, {line, section}, type, values),
    do: initial_in(Declarations.reserved(section), line, type, values)

  defp qualified_initial(_not_a_qualifier, _at, _type, _values), do: []

  # RV-2 (the review after Milestone 6, a3-compiler2-7): an array's initial list is warned
  # of to ten literals, the rest counted in one warning, as its misfits are listed
  # (`Logex.Array.capped/2`), where each of 65,536 was a warning of its own.
  defp initial_in(:section, line, type, values),
    do:
      for(
        literal <- values,
        is_real_lit(literal),
        {:rounded, held} <- [Logex.Real.held_as(type, Parser.value(literal), text(literal))],
        do: rounded_warning(line, literal, type, held)
      )
      |> Logex.Array.capped(&rounded_more(line, type, &1))

  defp initial_in(_not_a_declaration, _line, _type, _values), do: []

  defp rounded_more(line, type, count),
    do:
      warning(
        line,
        "#{count} more #{plural(count, "literal")} of this initial list #{plural(count, "is", "are")} " <>
          "more precise than #{Declarations.a_type(type)} keeps, not listed"
      )

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"
  defp plural(1, one, _many), do: one
  defp plural(_count, _one, many), do: many

  defp rounded_warning(line, literal, type, held),
    do:
      warning(
        line,
        "#{shown(literal)} is more precise than #{Declarations.a_type(type)} keeps: it is " <>
          "held as #{held}"
      )

  # Decision 219: a real literal with more digits than the real its slot computes in
  # keeps, `move 16777217.0 r` into a `real`, held as 16777216.0, which compiles, as every
  # real literal its slot rounds does (M5-10's review), and is told what it is held as.
  # The slot's real is `Logex.Compiler.literal_real/4`'s, the one rule the lowering reads;
  # a literal in no real's slot, a comparison of two, is passed over. Only an instruction
  # that holds a real literal is looked at, told by its clause's guard, so a program of none
  # pays nothing; a `cal`'s operands past its third, any number of them, are looked through.
  @reals Declarations.reals()

  defp rounded_literals({:cal, _line, operands} = instruction, tags),
    do: rounding(real_literal?(operands), instruction, tags)

  defp rounded_literals(instruction, tags), do: rounding(true, instruction, tags)

  defp real_literal?([operand | _]) when is_real_lit(operand), do: true
  defp real_literal?([_ | operands]), do: real_literal?(operands)
  defp real_literal?([]), do: false

  defp rounding(false, _instruction, _tags), do: []

  defp rounding(true, {_symbol, line, operands} = instruction, tags) do
    slots = Compiler.signature(instruction, tags)
    type_of = &ir_real(&1, &2, tags)

    for {slot, literal} <- Enum.zip(slots, operands),
        is_real_lit(literal),
        type = Compiler.literal_real(slot, slots, operands, type_of),
        type != nil,
        {:rounded, held} <- [Logex.Real.held_as(type, Parser.value(literal), text(literal))],
        do: rounded_warning(line, literal, type, held)
  end

  # The text a literal was written as: its spelling, or a plain one's float's own text.
  defp text(literal), do: Parser.spelling(literal)

  # An IR operand's real, as Logex.Compiler.literal_real/4 reads one.
  defp ir_real(_access, literal, _tags) when is_literal(literal), do: :literal
  defp ir_real(_access, {:name, _, name}, tags), do: {:tag, tag_real(Map.get(tags, name))}

  defp ir_real(_access, {:member, _, [instance, member]}, tags),
    do: {:tag, member_real(Map.get(tags, instance), member)}

  defp ir_real(_access, {:member, _, element, [member]}, tags),
    do: {:tag, element_member_real(Map.get(tags, elem(element, 2)), member)}

  # M5-11: an element is its array's elements' real.
  defp ir_real(_access, {:element, _, array, _index, _name}, tags),
    do: {:tag, element_real(Map.get(tags, array))}

  # M5-12: so is an element a tag subscripts.
  defp ir_real(_access, {:element_at, _, array, _index, _dims, _name}, tags),
    do: {:tag, element_real(Map.get(tags, array))}

  defp ir_real(_access, _bit_or_deeper, _tags), do: {:tag, nil}

  defp element_real(%Tag{type: {:array, type, _dims}}) when type in @reals, do: type
  defp element_real(_other), do: nil

  defp tag_real(%Tag{type: type}) when type in @reals, do: type
  defp tag_real(_other), do: nil

  defp member_real(%Tag{type: %FbType{} = type}, member),
    do: member_type_real(FbType.member(type, member))

  defp member_real(_other, _member), do: nil

  # RV-2 (the review after Milestone 6, a4-warnings-walk-6): a member of an element of an
  # array of instances is its member's real, `gs[1].r`'s.
  defp element_member_real(%Tag{type: {:array, %FbType{}, _dims}} = tag, member),
    do: member_real(of_elements(tag), member)

  defp element_member_real(_other, _member), do: nil

  defp member_type_real({:ok, %FbType.Member{type: type}}) when type in @reals, do: type
  defp member_type_real(_other), do: nil

  # M5-6 (§4.12's routine choice, decision 158): a long timer counts nanoseconds on a clock
  # of whole milliseconds, so a preset that is no whole number of them is reached at the
  # next whole millisecond, `ton t 1500000` on a `ton_ltime` at 2 ms. A timer counted in
  # ms, and a counter, have no such preset; a program with a diagnostic gets no warning, so
  # the instance here is one the instruction runs.
  @runners FbType.runners()

  defp between_milliseconds({symbol, line, [{:name, _, name}, preset]}, tags)
       when symbol in @runners and is_int_lit(preset),
       do: between(per_ms(Map.get(tags, name)), {symbol, line, name, Parser.value(preset)})

  # M5-14: an element of an array of long timers so, by its path.
  defp between_milliseconds({symbol, line, [{:element, _, array, _, name}, preset]}, tags)
       when symbol in @runners and is_int_lit(preset),
       do:
         between(
           per_ms(of_elements(Map.get(tags, array))),
           {symbol, line, name, Parser.value(preset)}
         )

  defp between_milliseconds(_instruction, _tags), do: []

  defp of_elements(%Tag{type: {:array, type, _dims}} = tag), do: %{tag | type: type}
  defp of_elements(_no_array), do: nil

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

  defp about(%Tag{} = tag, [], _run),
    do: [warning(tag.line, "`#{tag.name}` is declared but no rung uses it")]

  defp about(%Tag{section: :var_output} = tag, accesses, _run),
    do: unwritten(:write in accesses, tag)

  defp about(%Tag{type: %FbType{body: nil}} = tag, accesses, _run),
    do: unrun(:instance in accesses, tag)

  defp about(%Tag{type: %FbType{}} = tag, accesses, _run),
    do: uncalled(:instance in accesses, tag)

  # M5-14 (decision 154): an array of instances, each element an instance of its own, is
  # told the elements no instruction runs, in the elements' order, the first ten and then a
  # count, in one warning at its line.
  defp about(%Tag{type: {:array, %FbType{}, _dims}} = tag, _accesses, run),
    do: elements_unrun(unrun_elements(tag, run), tag)

  defp about(_tag, _accesses, _run), do: []

  # RV-2 (the review after Milestone 6, a4-warnings-walk-7): every element an instruction
  # runs, by its name, gathered in one pass where a routine holds an array of instances,
  # where each array walked every instruction again; a routine of none walks nothing.
  defp instances?(%Tag{type: {:array, %FbType{}, _dims}}), do: true
  defp instances?(_tag), do: false

  defp elements_run(false, _instructions), do: %{}

  defp elements_run(true, instructions),
    do:
      for(
        {_symbol, _, [{:element, _, _array, _, name} | _]} <- instructions,
        into: %{},
        do: {name, true}
      )

  defp unrun_elements(%Tag{name: array, type: {:array, _type, dims}}, run) do
    for index <- Logex.Array.indexes(dims),
        name = Logex.Array.name(array, index),
        not is_map_key(run, name),
        do: name
  end

  defp elements_unrun([], _tag), do: []

  defp elements_unrun(names, %Tag{type: {:array, type, dims} = array} = tag) do
    shown =
      names
      |> Enum.map(&"`#{&1}`")
      |> Logex.Array.capped(&"#{&1} more")
      |> listed_or()

    {who, what} = element_runs(type, length(names))

    [
      warning(
        tag.line,
        "`#{tag.name}` is #{Logex.Array.a_type(array)}, but no #{who} runs " <>
          "#{every(length(names), Logex.Array.size(dims), shown)}: #{what}"
      )
    ]
  end

  defp every(count, count, _shown), do: "any of its elements"
  defp every(_some, _all, shown), do: shown

  defp listed_or([one]), do: one
  defp listed_or(items), do: Enum.join(Enum.drop(items, -1), ", ") <> " or " <> List.last(items)

  defp element_runs(%FbType{body: nil} = type, count) do
    %{kind: kind, runs: runs} = FbType.rules(type)
    {runners(Map.keys(runs)), "#{it(count)} never #{do_s(count, does(kind))}"}
  end

  defp element_runs(_block, count),
    do:
      {"`cal`",
       "#{it(count)} never #{do_s(count, "runs")}, and #{its(count)} members stay at their " <>
         "initial values"}

  defp it(1), do: "it"
  defp it(_many), do: "they"

  defp its(1), do: "its"
  defp its(_many), do: "their"

  defp do_s(1, verb), do: verb
  defp do_s(_many, verb), do: String.trim_trailing(verb, "s")

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
        "`#{tag.name}` is a var_output, but no rung writes it: it stays at " <>
          start(tag.initial, tag.type)
      )
    ]

  # RV-2 (the review after Milestone 6, a4-warnings-walk-9): a real stays at 0.0, its zero,
  # where it was told 0, and since RV-2's review each element of an array of reals too.
  defp start(nil, type) when type in @reals, do: "0.0"
  defp start(nil, {:array, type, _dims}) when type in @reals, do: "0.0"
  defp start(nil, _type), do: "0"
  # M5-11: an array's initial list, which no one value says.
  defp start(initial, _type) when is_list(initial), do: "its initial values"
  defp start(initial, _type), do: "#{initial}"

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

    words = Enum.reduce(coils, %{}, &coiled/2)
    {decisions, words} = decisions(instructions, coils, words, tags)
    decisions = Enum.filter(decisions, &decides?(&1, tags, owners))

    {warnings, _firsts} =
      Enum.flat_map_reduce(decisions, {tagged(decisions, words), %{}, %{}}, &decided/2)

    once(warnings, words)
  end

  # Decision 431 (RV-15): a routine some member's word of which is judged as a word array
  # is (virtual/4) is told each warning once, a member rule's and the word array's alike
  # where both tell one pair in the same words.
  defp once(warnings, words) when is_map_key(words, :virtual), do: Enum.uniq(warnings)
  defp once(warnings, _words), do: warnings

  # The words a coil names a bit of, a literal one's or one a tag numbers, and since
  # M5-12's review each array an element of which holds such a bit, `{:coiled_in, "w"}` for
  # `ote w[2].1`, whose write through a tag subscript, `move x w[i]`, may write it whole;
  # and since decision 235 each array a coil names an element of, `ote lamps[2]`, whose
  # write through a tag subscript, `move 0 lamps[slot]`, may write it.
  #
  # Decision 431 (RV-15): so a coil of a member's word judged as a word array (virtual/4),
  # on a bit of a literal element, `ote l1[2].pv.1` as `ote w[2].1` and `ote l1[2].pv.[n]`
  # as `ote w[2].[n]`, its word and its array the word array's.
  defp coiled({:coil, {:mword_bit, _word, _n}, word, tag, _at, _shown, places}, words),
    do: words |> Map.put(word, true) |> Map.put({:coiled_in, tag}, true) |> in_arrays(places)

  defp coiled({:coil_at, {:mword_el, _, _, _} = word, tag, _at, _shown, id}, words),
    do: words |> Map.put(word, true) |> Map.put({:coiled_in, tag}, true) |> in_arrays(id)

  defp coiled({:coil, key, nil, tag, _at, _shown, places}, words) when is_element(key, tag),
    do: words |> Map.put({:coiled_in, tag}, true) |> in_arrays(places)

  defp coiled({:coil, _key, nil, _tag, _at, _shown, _places}, words), do: words

  defp coiled({:coil, _key, word, tag, _at, _shown, places}, words)
       when is_element(word, tag),
       do: words |> Map.put(word, true) |> Map.put({:coiled_in, tag}, true) |> in_arrays(places)

  defp coiled({:coil, _key, word, _tag, _at, _shown, _places}, words),
    do: Map.put(words, word, true)

  defp coiled({:coil_at, word, tag, _at, _shown, id}, words) when is_element(word, tag),
    do: words |> Map.put(word, true) |> Map.put({:coiled_in, tag}, true) |> in_arrays(id)

  defp coiled({:coil_at, {:array, _array} = word, _tag, _at, _shown, id}, words),
    do: words |> Map.put(word, true) |> in_arrays(id)

  defp coiled({:coil_at, word, _tag, _at, _shown, _id}, words), do: Map.put(words, word, true)

  # Decision 253: a member some coil names, of a literal element or through a tag subscript,
  # whose other writes are compared with it.
  defp coiled({:member_coil, _key, group, _at, _shown, places}, words),
    do: words |> Map.put({:member_coiled, group}, true) |> in_arrays(places)

  defp coiled({:member_coil_at, group, _at, _shown, id}, words),
    do: words |> Map.put({:member_coiled, group}, true) |> in_arrays(id)

  defp coiled({:member_bit, group, _at, _shown, places}, words),
    do: words |> Map.put({:member_coiled, group}, true) |> in_arrays(places)

  # Decision 288: a bit of a member through a tag subscript, `ote lane_c[i].pv.3`, whose
  # member's whole writes, `move 5 lane_c[1].pv` or `move 5 lane_c[j].pv`, are compared with
  # it.
  defp coiled({:member_bit_at, group, word, _at, _shown, id}, words),
    do:
      words
      |> Map.put({:member_coiled, group}, true)
      |> Map.put({:member_bits_coiled, word}, true)
      |> in_arrays(id)

  # Decision 431 (RV-15): a coil on a bit of a member of an element, of any form, marks
  # its member's word, whose other writes mword_writes/3 then reads, and `:mwords`; one
  # through a tag subscript keeps the word among `:mtagged`, those covered/2 gives.
  # Decision 431: a coil's first of its own (decided/2), which marks nothing.
  defp coiled({:numbered_at, _tag, _at, _shown, _places}, words), do: words

  defp coiled({:mword, word, false}, words),
    do: words |> Map.put(:mwords, true) |> Map.put({:mword, word}, true)

  defp coiled({:mword, word, true}, words),
    do:
      words
      |> Map.put(:mwords, true)
      |> Map.put({:mword, word}, true)
      |> Map.update(:mtagged, [word], &[word | &1])

  # One on a bit a tag numbers through a tag subscript too, `{:mnumbered, word}`, which a
  # latch of a literal element's literal bit is compared with (decided/2).
  defp coiled({:mword, word, :numbered}, words),
    do: {:mword, word, true} |> coiled(words) |> Map.put({:mnumbered, word}, true)

  # Decision 372: a coil in an array of two or three dimensions, by its places or by the
  # tags and literals it is written through, marks `:in_arrays`, whose arrays tagged/2
  # then reads; one of one dimension, whose places are nil, marks nothing.
  defp in_arrays(words, [_ | _]), do: Map.put(words, :in_arrays, true)
  defp in_arrays(words, {:element_at, _array, [_, _ | _]}), do: Map.put(words, :in_arrays, true)
  # Decision 405: a bit of an element has its number's place, two at least.
  defp in_arrays(words, {:bit, _element, _n}), do: Map.put(words, :in_arrays, true)

  defp in_arrays(words, {:bit_at, {:element_at, _, _}, _n}),
    do: Map.put(words, :in_arrays, true)

  defp in_arrays(words, {:bit_at, {:element, _, _}, _n}), do: Map.put(words, :in_arrays, true)
  defp in_arrays(words, {:bit_at, element, _n}), do: in_arrays(words, element)
  # Decision 431: so a bit of a member's word through a tag subscript (virtual_coil/3).
  defp in_arrays(words, {:vel, _element, _n}), do: Map.put(words, :in_arrays, true)
  defp in_arrays(words, {:element, _array, [_, _ | _]}), do: Map.put(words, :in_arrays, true)

  defp in_arrays(words, {:member, _array, [_, _ | _], _members}),
    do: Map.put(words, :in_arrays, true)

  defp in_arrays(words, _one_dimension), do: words

  defp decisions(_instructions, coils, words, _tags) when map_size(words) == 0,
    do: {coils, words}

  # Decision 431: a routine whose coils name a bit of a member's word of an element keeps,
  # among its decisions, a mark of each other write of such a word through a tag
  # subscript (mword_writes/3), by which covered/2 finds the words to judge as a word
  # array is (virtual/4). Where a coil through a tag subscript covers a word already
  # (coiled/2), each instruction's decisions are kept apart, for told/4 to follow.
  defp decisions(instructions, _coils, words, tags) when is_map_key(words, :mtagged) do
    told =
      Enum.map(instructions, &(probed(coil_target(&1), words) ++ mword_writes(&1, tags, words)))

    told(
      covered(Enum.reduce(told, {words.mtagged, []}, &tagged_too/2)),
      told,
      instructions,
      {words, tags}
    )
  end

  defp decisions(instructions, _coils, words, tags) when is_map_key(words, :mwords) do
    decisions =
      Enum.flat_map(
        instructions,
        &(probed(coil_target(&1), words) ++ mword_writes(&1, tags, words))
      )

    virtual(covered(tagged_too(decisions, {[], []})), decisions, instructions, {words, tags})
  end

  defp decisions(instructions, _coils, words, tags),
    do:
      {Enum.flat_map(
         instructions,
         &(probed(coil_target(&1), words) ++ whole_writes(&1, tags, words))
       ), words}

  # M5-12 (§4.12's routine choice): a coil on an element of an array some coil names
  # through a tag subscript, `ote lamps[2]` beside `ote lamps[slot]`, or on a bit of one,
  # `ote faults[2].3` beside `ote faults[i].3`, is first a coil in the array, which comes
  # after such a coil, or before it, as the second-`ote` warning; then the coil it is.
  defp probed([{:coil, key, _word, tag, at, shown, places} = coil], words)
       when is_map_key(words, {:array, tag}),
       do: [{:element_coil, {:array, tag}, key, tag, at, shown, places}, coil]

  defp probed([{:coil_at, word, tag, at, shown, id} = coil], words)
       when is_binary(word) and is_map_key(words, {:array, tag}),
       do: [{:element_coil, {:array, tag}, word, tag, at, shown, places(id)}, coil]

  defp probed([{:coil_at, {:mword_el, _, _, _} = word, tag, at, shown, id} = coil], words)
       when is_map_key(words, {:array, tag}),
       do: [{:element_coil, {:array, tag}, word, tag, at, shown, places(id)}, coil]

  # Decision 431: a coil's mark of its member's word (coiled/2) decides nothing itself.
  defp probed([coil, member_bit, {:mword, _word, _tagged}], _words), do: [coil, member_bit]
  defp probed([coil, {:mword, _word, _tagged}], words), do: probed([coil], words)
  defp probed([{:mword, _word, _tagged}], _words), do: []

  defp probed(coils, _words), do: coils

  defp decides?({:coil, key, _word, tag, _at, _shown, _places}, tags, owners),
    do: from_source?(tags, tag) and not Map.has_key?(owners, key)

  defp decides?({:coil_at, word, tag, _at, _shown, _id}, tags, owners),
    do: from_source?(tags, tag) and not Map.has_key?(owners, word)

  defp decides?({:whole, _word, tag, _at, _id}, tags, _owners), do: from_source?(tags, tag)

  defp decides?({:element_coil, _word, key, tag, _at, _shown, _places}, tags, owners),
    do: from_source?(tags, tag) and not Map.has_key?(owners, key)

  defp decides?({:element_whole, array, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:whole_at, array, _at, _shown, _id, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_coil, _key, {array, _members}, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_coil_at, {array, _members}, _at, _shown, _id}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_bit, {array, _members}, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_bit_at, {array, _}, _word, _at, _shown, _id}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_word_whole, {array, _members}, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_word_whole_at, {array, _members}, _at, _shown, _id}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_whole, {array, _members}, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:member_whole_at, {array, _members}, _at, _shown, _id}, tags, _owners),
    do: from_source?(tags, array)

  defp decides?({:literal_latch, tag, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, tag)

  defp decides?({:numbered_at, tag, _at, _shown, _places}, tags, _owners),
    do: from_source?(tags, tag)

  # Decision 431: a mark of a write through a tag subscript, or of a literal bit's
  # (mword_writes/3), decides nothing itself.
  defp decides?({:mword_write, _word}, _tags, _owners), do: false
  defp decides?({:mword_latch, _word}, _tags, _owners), do: false

  # Decision 372 (RV-9): the arrays some write names through a tag subscript, each
  # `{:tagged, array}`, kept beside the coils' firsts, which no key of theirs can be. A
  # write of literal subscripts in an array of two or three dimensions no write through a
  # tag subscript names keeps and looks up its plain key, as before, since nothing compares
  # it with another write of the array, so that such an array costs what it did. A routine
  # whose coils name no element, of an array or an array of instances, `:in_arrays` among
  # the coiled words unmarked, writes none through a tag subscript a coil compares, and is
  # not walked for them.
  defp tagged(_decisions, words) when not is_map_key(words, :in_arrays), do: %{}

  defp tagged(decisions, _words),
    do:
      for(
        decision <- decisions,
        array = tagged_in(decision),
        into: %{},
        do: {{:tagged, array}, true}
      )

  defp tagged_in({:coil_at, {:array, array}, _tag, _at, _shown, _id}), do: array
  defp tagged_in({:whole_at, array, _at, _shown, _id, _places}), do: array
  defp tagged_in({:member_coil_at, {array, _}, _at, _shown, _id}), do: array
  defp tagged_in({:member_bit_at, {array, _}, _word, _at, _shown, _id}), do: array
  defp tagged_in({:member_word_whole_at, {array, _}, _at, _shown, _id}), do: array
  defp tagged_in({:member_whole_at, {array, _}, _at, _shown, _id}), do: array
  defp tagged_in(_literal), do: nil

  defp decided({:coil, key, word, tag, at, shown, [_ | _]}, {coils, _, _} = firsts)
       when not is_map_key(coils, {:tagged, tag}),
       do: decided({:coil, key, word, tag, at, shown, nil}, firsts)

  defp decided({:element_coil, word, key, tag, at, shown, [_ | _]}, {coils, _, _} = firsts)
       when not is_map_key(coils, {:tagged, tag}),
       do: decided({:element_coil, word, key, tag, at, shown, nil}, firsts)

  defp decided({:element_whole, array, at, shown, [_ | _]}, {coils, _, _} = firsts)
       when not is_map_key(coils, {:tagged, array}),
       do: decided({:element_whole, array, at, shown, nil}, firsts)

  defp decided(
         {:member_coil, key, {array, _} = group, at, shown, [_ | _]},
         {coils, _, _} = firsts
       )
       when not is_map_key(coils, {:tagged, array}),
       do: decided({:member_coil, key, group, at, shown, nil}, firsts)

  defp decided({:member_bit, {array, _} = group, at, shown, [_ | _]}, {coils, _, _} = firsts)
       when not is_map_key(coils, {:tagged, array}),
       do: decided({:member_bit, group, at, shown, nil}, firsts)

  defp decided(
         {:member_word_whole, {array, _} = word, at, shown, [_ | _]},
         {coils, _, _} = firsts
       )
       when not is_map_key(coils, {:tagged, array}),
       do: decided({:member_word_whole, word, at, shown, nil}, firsts)

  defp decided({:member_whole, {array, _} = group, at, shown, [_ | _]}, {coils, _, _} = firsts)
       when not is_map_key(coils, {:tagged, array}),
       do: decided({:member_whole, group, at, shown, nil}, firsts)

  # A coil on a tag or member, keyed by its name, on no word; a coil on a bit, `status.3` on
  # the word `status`, or `c.pv.3` on the member `c.pv`; a whole write of a word or member.
  # `firsts` holds each coil's first, each word's first whole write, and each word's first
  # coiled bit.
  #
  # Decision 235: a coil on an element, `ote lamps[2]`, after a write of its array through a
  # tag subscript, `move 0 lamps[slot]`, any instruction's but a coil's, is the second-`ote`
  # warning, as a coil on a bit of an element is after one (M5-12's review), and is for what
  # comes later a coil in its array, which such a write after it is told; a write of the
  # element itself, `move 0 lamps[2]`, is still no coil's, as `move x b` beside `ote b` is
  # not.
  defp decided({:coil, key, nil, tag, at, shown, nil}, {coils, wholes, bitted})
       when is_element(key, tag),
       do:
         {element_after(
            Map.fetch(coils, key),
            Map.fetch(wholes, {:written, tag}),
            tag,
            at,
            shown
          ), {first(coils, key, at, nil), wholes, first(bitted, {:array, tag}, {shown, at}, nil)}}

  # Decision 372: so in an array some write names through a tag subscript, its firsts by
  # their projections (first_at/5), and an array of one dimension's, or one no write names
  # so, by their plain keys, above, at what they cost before.
  defp decided({:coil, key, nil, tag, at, shown, places}, {coils, wholes, bitted})
       when is_element(key, tag),
       do:
         {element_after(
            Map.fetch(coils, key),
            meeting(wholes, {:written, tag}, places),
            tag,
            at,
            shown
          ),
          {first(coils, key, at, nil), wholes,
           first_at(bitted, {:array, tag}, places, {shown, at}, nil)}}

  defp decided({:coil, key, nil, _tag, at, shown, _places}, {coils, wholes, bitted}) do
    {warnings, coils} = later_ote(Map.fetch(coils, key), {key, shown}, at, coils)
    {warnings, {coils, wholes, bitted}}
  end

  #
  # Since M5-12's review a coil on a bit of a literal element, `ote w[2].1`, comes after a
  # write through a tag subscript of its array, `move x w[i]`, as after a write of its
  # element whole, the second-`ote` warning (§4.12's routine choice and decision 207), and
  # is for what comes later a coil in its array, `{:array, "w"}`.
  defp decided({:coil, key, word, tag, at, shown, nil}, {coils, wholes, bitted}),
    do:
      {bit_after(
         Map.fetch(coils, key),
         Map.fetch(wholes, word),
         Map.fetch(wholes, {:written, tag}),
         {word, tag, at, shown}
       ),
       {first(coils, key, at, nil), wholes,
        bitted |> first(word, {shown, at}, nil) |> first({:array, tag}, {shown, at}, nil)}}

  defp decided({:coil, key, word, tag, at, shown, places}, {coils, wholes, bitted}),
    do:
      {bit_after(
         Map.fetch(coils, key),
         Map.fetch(wholes, word),
         meeting(wholes, {:written, tag}, places),
         {word, tag, at, shown}
       ),
       {first(coils, key, at, nil), wholes,
        bitted
        |> first(word, {shown, at}, nil)
        |> first_at({:array, tag}, places, {shown, at}, nil)}}

  # A coil on a bit a tag numbers, `ote w.[n]`, keyed by its word: after another such coil
  # on the word, after a coil on a bit of it, `ote w.3`, or after a whole write of it,
  # `move x w`, the second-`ote` warning; and itself a coil on a bit of the word and a whole
  # write of it for what comes later.
  #
  # A coil on an element a tag subscripts, or on a bit of one, `ote w[i].1`, keyed by its
  # array, `{:array, "w"}`, comes after any coil in the array, a coil on another element
  # among them, and since M5-12's review after any write of the array whole through a tag
  # subscript, `move x w[i]`, or of one of its elements whole, `move x w[2]`, each the
  # second-`ote` warning, naming the array.
  defp decided({:coil_at, {:array, _array}, _tag, _at, _shown, id} = coil, firsts),
    do: coil_in_array(places(id), coil, firsts)

  defp decided({:coil_at, word, tag, {line, _symbol} = at, shown, id}, {coils, wholes, bitted}) do
    places = literal(coils, tag, places(id))

    warnings =
      word_after(
        Map.fetch(coils, word),
        Map.fetch(bitted, word),
        unlike(wholes, word, id),
        meeting(wholes, {:written, tag}, places),
        {word, tag, line, at, shown}
      )

    {warnings,
     {first(coils, word, at, id), first(wholes, word, at, id),
      bitted
      |> first(word, {shown, at}, id)
      |> first_at({:array, tag}, places, {shown, at}, id)}}
  end

  # M5-12: a coil on an element, or a bit of one, of an array a coil names through a tag
  # subscript: after such a coil, `ote lamps[slot]`, the second-`ote` warning, and for what
  # comes later a coil in the array, which such a coil after it is told.
  defp decided({:element_coil, word, _key, _tag, at, shown, places}, {coils, wholes, bitted}),
    do:
      {in_array(meeting(wholes, word, places), word, at, shown),
       {coils, wholes, first_at(bitted, word, places, {shown, at}, nil)}}

  defp decided({:whole, word, _tag, at, id}, {coils, wholes, bitted}),
    do: whole_after(unlike(bitted, word, id), at, {coils, first(wholes, word, at, id), bitted})

  # M5-12's review: a write of an element whole, `move x w[2]`, in an array a coil names
  # through a tag subscript, `ote w[i].1`, comes after that coil as the second-`ote`
  # warning, and is for what comes later a write of an element of the array whole.
  defp decided({:element_whole, array, at, shown, places}, {coils, wholes, bitted}),
    do:
      {in_array(meeting(coils, {:array, array}, places), {:array, array}, at, shown),
       {coils, first_at(wholes, {:some, array}, places, {shown, at}, nil), bitted}}

  # M5-12's review (§4.12's routine choice): a write through a tag subscript, `move x
  # w[i]`, writes its array whole, so it comes after any coil on a bit of an element of
  # it, a literal one's or one through a tag subscript, as the second-`ote` warning, and is
  # for what comes later a write of the array whole.
  defp decided({:whole_at, array, at, shown, id, places}, {coils, wholes, bitted}) do
    {array_after(
       unlike_meeting(coils, {:array, array}, places, id),
       unlike_meeting(bitted, {:array, array}, places, id),
       {array, at, shown}
     ), {coils, first_at(wholes, {:written, array}, places, at, id), bitted}}
  end

  # Decision 253: a member of an array of instances is compared as decision 235 compares a
  # bool array's element. A coil on a literal element's member, `ote lane_c[1].r`, after a
  # second coil on it is the second-`ote` warning, as before; after a coil on that member
  # through a tag subscript, `ote lane_c[i].r`, or another write of it through one, `otl
  # lane_c[i].r`, it is told the array the first may write; and it is for what comes later
  # that member of a literal element coiled, `{:member_lit, group}`.
  defp decided(
         {:member_coil, key, {array, _} = group, at, shown, places},
         {coils, wholes, bitted}
       ),
       do:
         {member_after(
            Map.fetch(coils, key),
            meeting(coils, {:member_at, group}, places),
            meeting(wholes, {:member_written, group}, places),
            {array, at, shown}
          ),
          {coils
           |> first(key, at, nil)
           |> first_at({:member_lit, group}, places, {shown, at}, nil), wholes, bitted}}

  # Decision 257: a coil on a bit of a literal element's member, after its coil as a bit
  # (above), is that bit of a literal element coiled, after a coil or another write of the
  # bit through a tag subscript told the array the first may write, as a member is.
  defp decided({:member_bit, {array, _} = group, at, shown, places}, {coils, wholes, bitted}),
    do:
      {member_after(
         :error,
         meeting(coils, {:member_at, group}, places),
         meeting(wholes, {:member_written, group}, places),
         {array, at, shown}
       ), {first_at(coils, {:member_lit, group}, places, {shown, at}, nil), wholes, bitted}}

  # A coil on a member through a tag subscript, `ote lane_c[i].r`: after one through the
  # very tags told the member already has one (decision 256), after one through other tags,
  # or a write through a tag subscript, `otl lane_c[j].r`, told the array the first may
  # write; after a coil on that member of a literal element, `ote lane_c[1].r`, or a write
  # of one, `otl lane_c[1].r`, told that element's member; and a write through the very
  # tags, `otl lane_c[i].r`, beside it warned of nothing (decision 246).
  defp decided({:member_coil_at, {array, _} = group, at, shown, id}, {coils, wholes, bitted}) do
    places = places(id)

    {array_coil(
       very_meeting(coils, {:member_at, group}, places, id),
       meeting(coils, {:member_lit, group}, places),
       unlike_meeting(wholes, {:member_written, group}, places, id),
       meeting(wholes, {:member_some, group}, places),
       {array, at, shown}
     ), {first_at(coils, {:member_at, group}, places, at, id), wholes, bitted}}
  end

  # Decision 288: a coil on a bit of a member through a tag subscript, `ote lane_c[i].pv.3`,
  # compared as a member through one is (above), and then, where nothing of the bit itself
  # came first, beside a whole write of the member: through other tags, `move 5
  # lane_c[j].pv`, told the array the first may write; of a literal element's, `move 5
  # lane_c[1].pv`, told that element's member, which the `move` writes whole; through the
  # very tags, `move 5 lane_c[i].pv`, nothing (decision 246). It is for what comes later a
  # coil on a bit of the member through a tag subscript, `{:member_word_at, word}`.
  defp decided(
         {:member_bit_at, {array, _} = group, word, at, shown, id},
         {coils, wholes, bitted}
       ) do
    places = places(id)

    {array_coil(
       very_meeting(coils, {:member_at, group}, places, id),
       meeting(coils, {:member_lit, group}, places),
       either(
         unlike_meeting(wholes, {:member_written, group}, places, id),
         unlike_meeting(wholes, {:member_word_written, word}, places, id)
       ),
       either(
         meeting(wholes, {:member_some, group}, places),
         meeting(wholes, {:member_word_some, word}, places)
       ),
       {array, at, shown}
     ),
     {coils
      |> first_at({:member_at, group}, places, at, id)
      |> first_at({:member_word_at, word}, places, at, id), wholes, bitted}}
  end

  # Decision 288: a whole write of a member of an element, `move 5 lane_c[1].pv`, after a
  # coil on a bit of it through a tag subscript, told the array that coil may write; and
  # one through a tag subscript, `move 5 lane_c[j].pv`, so after one through other tags,
  # the very tags warned of nothing (decision 246). Each is for what comes later a whole
  # write of the member, of a literal element's or through a tag subscript.
  defp decided(
         {:member_word_whole, {array, _} = word, at, shown, places},
         {coils, wholes, bitted}
       ),
       do:
         {in_array(meeting(coils, {:member_word_at, word}, places), {:array, array}, at, shown),
          {coils, first_at(wholes, {:member_word_some, word}, places, {shown, at}, nil), bitted}}

  defp decided(
         {:member_word_whole_at, {array, _} = word, at, shown, id},
         {coils, wholes, bitted}
       ),
       do:
         {in_array(
            unlike_meeting(coils, {:member_word_at, word}, places(id), id),
            {:array, array},
            at,
            shown
          ), {coils, first_at(wholes, {:member_word_written, word}, places(id), at, id), bitted}}

  # Any other write of a member through a tag subscript, `otl lane_c[i].r`, after a coil on
  # it through other tags or on that member of a literal element; and a write of a literal
  # element's member, `otl lane_c[1].r`, after a coil on it through a tag subscript.
  defp decided({:member_whole_at, {array, _} = group, at, shown, id}, {coils, wholes, bitted}) do
    places = places(id)

    {array_after(
       unlike_meeting(coils, {:member_at, group}, places, id),
       meeting(coils, {:member_lit, group}, places),
       {array, at, shown}
     ), {coils, first_at(wholes, {:member_written, group}, places, at, id), bitted}}
  end

  defp decided({:member_whole, {array, _} = group, at, shown, places}, {coils, wholes, bitted}),
    do:
      {in_array(meeting(coils, {:member_at, group}, places), {:array, array}, at, shown),
       {coils, first_at(wholes, {:member_some, group}, places, {shown, at}, nil), bitted}}

  # Decision 431 (provisional): a literal bit of a literal element's member, written by an
  # instruction other than a coil, `otl l1[1].pv.3`, and a coil on a bit a tag numbers of
  # the member through a tag subscript, `ote l1[i].pv.[n]`, are warned where they may
  # meet, either first, as decision 257 warns that latch beside `ote l1[i].pv.3`: the
  # latch told the array the coil may write through a tag subscript, the coil told the
  # latch's bit, which the latch writes. Each keeps a first of its own, `{:latched, tag}`
  # and `{:numbered_at, tag}`, which nothing else reads, so that the word array's own
  # judgement of either (virtual/4) is as a word array's.
  defp decided({:literal_latch, tag, at, shown, places}, {coils, wholes, bitted}),
    do:
      {in_array(meeting(coils, {:numbered_at, tag}, places), {:array, tag}, at, shown),
       {coils, first_at(wholes, {:latched, tag}, places, {shown, at}, nil), bitted}}

  defp decided({:numbered_at, tag, at, shown, places}, {coils, wholes, bitted}),
    do:
      {as_found(meeting(wholes, {:latched, tag}, places), {tag, at, shown}),
       {first_at(coils, {:numbered_at, tag}, places, at, nil), wholes, bitted}}

  # Decision 431 (RV-15): a member's word of an element, `l1[1].pv`, judged as a word
  # array's element is, its bits as the word array's bits are (decision 405), in a word
  # array's words. A routine's member words some write reaches through a tag subscript of
  # its element, a coil's (coiled/2) or another write's (mword_writes/3), are each a word
  # array of their own, `{:mword_of, array, members}`, quoted as their array, whose
  # elements are `{:mword_el, array, index, members}`, quoted as the member's words, and
  # each write of such a word, of a literal element or through a tag subscript, is also
  # the decision a write of that word array's would be, judged by the clauses above as a
  # word array's is: so a write is told every first a word array's write would be told.
  # The member rules (decisions 253, 257 and 288) judge the member's writes as before, and
  # a warning both tell in the same words is told once (once/2). A word no write reaches
  # through a tag subscript keeps no such decision: its writes are all of literal
  # elements, which the clauses above judge as a word array's, so that it costs what it
  # did, its marks and their look the one walk's more (RV-15's review). A literal bit
  # through a tag subscript and its element written whole through the very tags are
  # through the very tags, `{:vel, element, bit}` (other/3), as decision 288 has them.
  defp covered({[], _latched}), do: %{}
  defp covered({tagged, latched}), do: Map.new(tagged ++ latched, &{&1, true})

  # Each word some write reaches through a tag subscript, and `{:latched, word}` for each
  # whose literal bit of a literal element another write writes (decided/2).
  defp tagged_too([{:mword_write, word} | decisions], {tagged, latched}),
    do: tagged_too(decisions, {[word | tagged], latched})

  defp tagged_too([{:mword_latch, word} | decisions], {tagged, latched}),
    do: tagged_too(decisions, {tagged, [{:latched, word} | latched]})

  defp tagged_too([_decision | decisions], marked), do: tagged_too(decisions, marked)
  defp tagged_too([], marked), do: marked

  defp virtual(covered, decisions, _instructions, {words, _tags}) when map_size(covered) == 0,
    do: {decisions, words}

  defp virtual(covered, _decisions, instructions, {words, tags}),
    do:
      told(
        covered,
        Enum.map(
          instructions,
          &(probed(coil_target(&1), words) ++ whole_writes(&1, tags, words))
        ),
        instructions,
        {words, tags}
      )

  # Each instruction's decisions, then those of its writes of a covered word as a word
  # array's, so that one line's warnings come in rung order (B10); the coils first, which
  # a write of the word array before them reads (coiled/2).
  defp told(covered, told, instructions, {words, tags}) do
    coils = Enum.map(instructions, &virtual_coils(&1, covered))
    virtual = coils |> Enum.concat() |> Enum.reduce(Map.put(words, :virtual, true), &coiled/2)

    {[told, coils, instructions]
     |> Enum.zip_with(fn [real, coil, instruction] ->
       real ++ probed(coil, virtual) ++ virtual_writes(instruction, tags, virtual, covered)
     end)
     |> Enum.concat(), virtual}
  end

  defp virtual_coils({:ote, line, [target]}, covered),
    do: virtual_coil(target, {line, :ote}, covered)

  defp virtual_coils({symbol, line, [_storage, pulse]}, covered) when symbol in [:osr, :osf],
    do: virtual_coil(pulse, {line, symbol}, covered)

  defp virtual_coils(_instruction, _covered), do: []

  # A coil of a member's word judged as a word array: on a literal element's literal bit,
  # `ote l1[1].pv.3`, as `ote w[1].3`; on a bit a tag numbers, `ote l1[1].pv.[n]`, as `ote
  # w[1].[n]`; through a tag subscript, `ote l1[i].pv.3` or `ote l1[i].pv.[n]`, as `ote
  # w[i].3` or `ote w[i].[n]`, a coil in the word array. A literal bit through a tag
  # subscript is told apart from its element written whole through the very tags by its
  # `:vel` alone, so that the two are through the very tags, as decision 288 has them.
  defp virtual_coil(
         {:bit, _, {:member, _, {:element, _, array, index, _}, members}, n, _, shown},
         at,
         covered
       )
       when is_map_key(covered, {array, members}),
       do: [
         {:coil, {:mword_bit, {array, index, members}, n}, {:mword_el, array, index, members},
          {:mword_of, array, members}, at, shown, index ++ [n]}
       ]

  defp virtual_coil(
         {:bit_at, _, {:member, _, {:element, _, array, index, _}, members}, {:name, _, n}, _,
          shown},
         at,
         covered
       )
       when is_map_key(covered, {array, members}),
       do: [
         {:coil_at, {:mword_el, array, index, members}, {:mword_of, array, members}, at, shown,
          {:bit_at, {:element, {:mword_of, array, members}, index}, n}}
       ]

  defp virtual_coil(
         {:bit, _, {:member, _, {:element_at, _, array, _, _, _} = element, members}, n, _,
          shown},
         at,
         covered
       )
       when is_map_key(covered, {array, members}),
       do: [
         {:coil_at, {:array, {:mword_of, array, members}}, {:mword_of, array, members}, at, shown,
          {:vel, same(element), n}}
       ]

  defp virtual_coil(
         {:bit_at, _, {:member, _, {:element_at, _, array, _, _, _} = element, members},
          {:name, _, n}, _, shown},
         at,
         covered
       )
       when is_map_key(covered, {:latched, {array, members}}),
       do: [
         {:coil_at, {:array, {:mword_of, array, members}}, {:mword_of, array, members}, at, shown,
          {:bit_at, same(element), n}},
         {:numbered_at, {:mword_of, array, members}, at, shown,
          subscripts(same(element)) ++ [:tag]}
       ]

  defp virtual_coil(
         {:bit_at, _, {:member, _, {:element_at, _, array, _, _, _} = element, members},
          {:name, _, n}, _, shown},
         at,
         covered
       )
       when is_map_key(covered, {array, members}),
       do: [
         {:coil_at, {:array, {:mword_of, array, members}}, {:mword_of, array, members}, at, shown,
          {:bit_at, same(element), n}}
       ]

  defp virtual_coil(_operand, _at, _covered), do: []

  defp virtual_writes({symbol, _line, _operands}, _tags, _words, _covered)
       when symbol in [:ote, :osr, :osf, :ons],
       do: []

  defp virtual_writes({symbol, line, operands} = instruction, tags, words, covered),
    do:
      for(
        {{:write, _type}, operand} <-
          Enum.zip(Logex.Compiler.signature(instruction, tags), operands),
        decision <- virtual_write(operand, words, covered, {line, symbol}),
        do: decision
      )

  # Any other write of a member's word judged as a word array: a literal element's word
  # whole, `move 5 l1[1].pv`, as `move 5 w[1]`, or a bit a tag numbers of it, `otl
  # l1[1].pv.[n]`, as `otl w[1].[n]`, each the element's word written whole; through a tag
  # subscript, `move 5 l1[i].pv`, `otl l1[i].pv.3` or `otl l1[i].pv.[n]`, as `move 5 w[i]`,
  # `otl w[i].3` or `otl w[i].[n]`, the word array written through one. A literal
  # element's literal bit, `otl l1[1].pv.3`, which a word array's rules compare with
  # nothing, is compared with a coil on a bit a tag numbers through a tag subscript, `ote
  # l1[i].pv.[n]`, alone, as decision 257 has a latch of it beside `ote l1[i].pv.3`
  # (provisional, decided/2), a pair of its own beside the word array's.
  defp virtual_write(
         {:member, _, {:element, _, array, index, element}, members},
         words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do:
         virtual_whole(
           {:mword_el, array, index, members},
           {{:mword_of, array, members}, at, nil},
           words
         ) ++
           virtual_some(
             {{:mword_of, array, members}, at, Enum.join([element | members], ".")},
             index ++ [:tag],
             words
           )

  defp virtual_write(
         {:bit_at, _, {:member, _, {:element, _, array, index, _}, members}, {:name, _, n}, _,
          shown},
         words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do:
         virtual_whole(
           {:mword_el, array, index, members},
           {{:mword_of, array, members}, at,
            {:bit_at, {:element, {:mword_of, array, members}, index}, n}},
           words
         ) ++ virtual_some({{:mword_of, array, members}, at, shown}, index ++ [:tag], words)

  defp virtual_write(
         {:bit, _, {:member, _, {:element, _, array, index, _}, members}, n, _, shown},
         _words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do: [{:literal_latch, {:mword_of, array, members}, member_write(at), shown, index ++ [n]}]

  defp virtual_write(
         {:member, _, {:element_at, _, array, _, _, written} = element, members},
         words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do:
         virtual_at(
           {{:mword_of, array, members}, at, Enum.join([written | members], ".")},
           {{:vel, same(element), :whole}, subscripts(same(element)) ++ [:tag]},
           words
         )

  defp virtual_write(
         {:bit, _, {:member, _, {:element_at, _, array, _, _, _} = element, members}, n, _,
          shown},
         words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do:
         virtual_at(
           {{:mword_of, array, members}, at, shown},
           {{:vel, same(element), n}, subscripts(same(element)) ++ [n]},
           words
         )

  defp virtual_write(
         {:bit_at, _, {:member, _, {:element_at, _, array, _, _, _} = element, members},
          {:name, _, n}, _, shown},
         words,
         covered,
         at
       )
       when is_map_key(covered, {array, members}),
       do:
         virtual_at(
           {{:mword_of, array, members}, at, shown},
           {{:bit_at, same(element), n}, subscripts(same(element)) ++ [:tag]},
           words
         )

  defp virtual_write(_operand, _words, _covered, _at), do: []

  # As whole/1 and wholes/4 give a word array's element written whole, where a coil names
  # a bit of it; as element_whole/3, where a coil through a tag subscript is in its array;
  # and as whole_at/3, a write through a tag subscript, where a coil is in its array.
  defp virtual_whole(word, {tag, at, id}, words) when is_map_key(words, word),
    do: [{:whole, word, tag, at, id}]

  defp virtual_whole(_word, _write, _words), do: []

  defp virtual_some({tag, at, shown}, places, words) when is_map_key(words, {:array, tag}),
    do: [{:element_whole, tag, at, shown, places}]

  defp virtual_some(_write, _places, _words), do: []

  defp virtual_at({tag, at, shown}, {id, places}, words)
       when is_map_key(words, {:array, tag}) or is_map_key(words, {:coiled_in, tag}),
       do: [{:whole_at, tag, at, shown, id, places}]

  defp virtual_at(_write, _id, _words), do: []

  defp mword_name({:mword_el, array, index, members}),
    do: Enum.join([Logex.Array.name(array, index) | members], ".")

  # Decision 246: a coil and another write of the very element or bit through the very tags,
  # `ote lamps[slot]` beside `otl lamps[slot]` or `move 0 lamps[slot]`, and `ote w.[n]` beside
  # `otl w.[n]`, are warned of nothing, as `ote lamps[2]` beside `otl lamps[2]` is not, where
  # since M5-9 and M5-12 each was the second-`ote` warning; through other tags, `lamps[i]`
  # beside `lamps[j]`, they still are. So each first a key holds keeps, beside it, the first
  # after it through other tags or none (`first/4`), which `unlike/3` gives where a write's
  # tags are the first's. `same/1` is an operand's tags and what they reach, its lines left
  # out, and nil for one no tag subscripts or numbers.
  defp first(map, key, value, id) when is_map_key(map, key),
    do: Map.update!(map, {:same, key}, &other(&1, value, id))

  defp first(map, key, value, id),
    do: map |> Map.put(key, value) |> Map.put({:same, key}, {id, :error})

  # Decision 431: a member's word judged as a word array (virtual/4) is through the very
  # tags at a literal bit and at the word whole, as decision 288 has a member's, `ote
  # lane_c[i].pv.3` beside `move 5 lane_c[i].pv`.
  defp other({{:vel, element, _first}, :error} = kept, _value, {:vel, element, _bit}), do: kept
  defp other({first_id, :error}, value, id) when id != first_id, do: {first_id, {:ok, value}}
  defp other(kept, _value, _id), do: kept

  defp unlike(map, key, id), do: unlike_first(Map.fetch(map, key), Map.get(map, {:same, key}), id)

  # The first a key holds, marked `:very` where it came through the very tags as `id`.
  defp very(map, key, id), do: very_first(Map.fetch(map, key), Map.get(map, {:same, key}), id)

  # The first of two finds, the second where the first finds nothing.
  defp either(:error, second), do: second
  defp either(first, _second), do: first

  defp very_first({:ok, first}, {id, _other}, id) when id != nil, do: {:very, first}
  defp very_first(found, _same, _id), do: found

  defp unlike_first({:ok, _first}, {{:vel, element, _first_bit}, other}, {:vel, element, _bit}),
    do: other

  defp unlike_first({:ok, _first}, {id, other}, id) when id != nil, do: other
  defp unlike_first(found, _same, _id), do: found

  defp same({:element_at, _, array, index, _dims, _name}),
    do: {:element_at, array, Enum.map(index, &subscript_of/1)}

  defp same({:bit_at, _, container, {:name, _, n}, _width, _name}),
    do: {:bit_at, container_of_bit(container), n}

  defp same({:bit, _, {:element_at, _, _, _, _, _} = element, n, _mask, _name}),
    do: {:bit, same(element), n}

  defp same(_literal), do: nil

  defp container_of_bit({:element, _, array, index, _name}), do: {:element, array, index}
  defp container_of_bit({:element_at, _, _, _, _, _} = element), do: same(element)

  defp container_of_bit({:member, _, {:element, _, array, index, _}, members}),
    do: {:member, array, index, members}

  defp container_of_bit(path), do: path

  defp subscript_of({:name, _, tag}), do: {:tag, tag}
  defp subscript_of(value), do: value

  # Decision 372 (RV-9): two writes of one array whose literal subscripts differ in any
  # place, `ee[1,i]` and `ee[0,i]`, never share an element, and are not compared; two that
  # may meet, `ee[i,0]` and `ee[j,0]`, or `ee[i]` and `ee[1]`, are, as before. A write's
  # places are its subscripts, each a literal's value or `:tag`, an element's, a bit's of
  # one or a member's of one, nil for no element. Each first an array keeps is kept under
  # every projection of its places, `{:at, key, positions, places there}`, at most 8 for
  # 3 dimensions, with the order it came in (`map_size/1`, which every first adds to), and
  # a write looks up the 2^n projections that may meet it, n its literal places, taking the
  # earliest found: constant in the writes, so the warnings stay linear. A write of no
  # element keeps and looks up its key as before, and so does one of an array of one
  # dimension, where a tag subscript meets every element and two literal ones are no
  # array's to compare, so that it costs what it did before.
  #
  # Decision 405 (RV-12): a bit's literal number is one more place, `w[i].3` at `[:tag, 3]`,
  # a bit a tag numbers and an element written whole a tag's, so two bits of one word array
  # whose literal numbers differ, `w[i].3` and `w[j].4`, never meet, in an array of one
  # dimension too, whose bits then have two places, and at most 16 projections are kept for
  # a bit of three dimensions. A member's bit is told apart by its member's path, its
  # number one more part of it (decision 257), so a member's places are its element's.
  defp places({:element_at, _array, [_one]}), do: nil
  defp places({:element_at, _array, subscripts}), do: Enum.map(subscripts, &place/1)
  defp places({:bit, element, n}), do: subscripts(element) ++ [n]
  defp places({:bit_at, {:element_at, _, _} = element, _n}), do: subscripts(element) ++ [:tag]
  defp places({:bit_at, {:element, _, _} = element, _n}), do: subscripts(element) ++ [:tag]
  defp places({:bit_at, container, _n}), do: places(container)
  # Decision 431: a literal bit through a tag subscript of a member's word (virtual_coil/3).
  defp places({:vel, element, n}), do: subscripts(element) ++ [n]
  defp places({:element, _array, index}), do: placed(index)
  defp places({:member, _array, index, _members}), do: placed(index)
  defp places(_scalar), do: nil

  defp placed([_one]), do: nil
  defp placed(index), do: index

  defp subscripts({:element_at, _array, subscripts}), do: Enum.map(subscripts, &place/1)
  defp subscripts({:element, _array, index}), do: index

  # An element written whole through a tag subscript: a word array's at every bit.
  defp whole_places(id, %Tag{type: {:array, :bool, _dims}}), do: places(id)
  defp whole_places(id, _words), do: subscripts(id) ++ [:tag]

  # The bit's place of an element written whole: none for a bool array's, which has no
  # bits, and a tag's, which meets every bit, for a word array's. A tag's for a bool
  # array's would meet the same writes, since no write of a bool array names a bit, but
  # keep each under twice the projections (RV-12's review).
  defp bit_place(%Tag{type: {:array, :bool, _dims}}), do: []
  defp bit_place(_words), do: [:tag]

  defp place({:tag, _tag}), do: :tag
  defp place(value), do: value

  defp literal(coils, array, places) when is_map_key(coils, {:tagged, array}), do: places
  defp literal(_coils, _array, _places), do: nil

  defp first_at(map, key, nil, value, id), do: first(map, key, value, id)

  defp first_at(map, key, places, value, id) do
    order = map_size(map)

    Enum.reduce(projections(Enum.with_index(places)), map, fn projection, map ->
      first(map, {:at, key, projection}, {order, value}, id)
    end)
  end

  defp meeting(map, key, nil), do: Map.fetch(map, key)

  defp meeting(map, key, places),
    do: earliest(for at <- meets(key, places), {:ok, found} <- [Map.fetch(map, at)], do: found)

  defp unlike_meeting(map, key, nil, id), do: unlike(map, key, id)

  defp unlike_meeting(map, key, places, id),
    do: earliest(for at <- meets(key, places), {:ok, found} <- [unlike(map, at, id)], do: found)

  defp very_meeting(map, key, nil, id), do: very(map, key, id)

  defp very_meeting(map, key, places, id),
    do:
      earliest_very(
        for at <- meets(key, places),
            {kind, {order, value}} <- [very(map, at, id)],
            do: {order, kind, value}
      )

  defp earliest([]), do: :error
  defp earliest(found), do: {:ok, elem(Enum.min_by(found, &elem(&1, 0)), 1)}

  defp earliest_very([]), do: :error

  defp earliest_very(found) do
    {_order, kind, value} = Enum.min_by(found, &elem(&1, 0))
    {kind, value}
  end

  # Every projection of a write's places, each `{positions, places there}`.
  defp projections([]), do: [{[], []}]

  defp projections([{place, at} | rest]),
    do:
      for(
        {positions, there} <- projections(rest),
        projection <- [{positions, there}, {[at | positions], [place | there]}],
        do: projection
      )

  # The projections a write meets: on its literal places, each the literal's value or a tag.
  defp meets(key, places),
    do: for(projection <- met(Enum.with_index(places)), do: {:at, key, projection})

  defp met([]), do: [{[], []}]
  defp met([{:tag, _at} | rest]), do: met(rest)

  defp met([{value, at} | rest]),
    do:
      for(
        {positions, there} <- met(rest),
        place <- [value, :tag],
        do: {[at | positions], [place | there]}
      )

  defp bit_after({:ok, first}, _whole, _written, {_word, _tag, {line, _symbol}, shown}),
    do: [second_ote(shown, first, line)]

  # Decision 431: a member's word judged as a word array (virtual/4) quoted as the member's.
  defp bit_after(
         :error,
         {:ok, _first} = whole,
         written,
         {{:mword_el, _, _, _} = word, tag, at, shown}
       ),
       do: bit_after(:error, whole, written, {mword_name(word), tag, at, shown})

  defp bit_after(:error, {:ok, {first, symbol}}, _written, {word, _tag, {line, _}, shown}),
    do: [
      warning(
        line,
        "`#{shown}` is a bit of `#{word}`, which the `#{symbol}` #{where(first, line)} " <>
          "writes whole: #{last()}"
      )
    ]

  defp bit_after(:error, :error, {:ok, _first} = written, {_word, tag, at, shown}),
    do: in_array(written, {:array, tag}, at, shown)

  defp bit_after(:error, :error, :error, _coil), do: []

  defp member_after({:ok, first}, _at_tag, _written, {_array, {line, _symbol}, shown}),
    do: [second_ote(shown, first, line)]

  defp member_after(:error, {:ok, _} = first, _written, {array, at, shown}),
    do: in_array(first, {:array, array}, at, shown)

  defp member_after(:error, :error, written, {array, at, shown}),
    do: in_array(written, {:array, array}, at, shown)

  defp element_after({:ok, first}, _written, _tag, {line, _symbol}, shown),
    do: [second_ote(shown, first, line)]

  defp element_after(:error, written, tag, at, shown),
    do: in_array(written, {:array, tag}, at, shown)

  defp word_after({:ok, first}, _bitted, _whole, _written, {_word, _tag, line, _at, shown}),
    do: [second_ote(shown, first, line)]

  defp word_after(:error, {:ok, {bit, first}}, _whole, _written, {_word, _tag, line, _at, _}),
    do: [second_ote(bit, first, line)]

  defp word_after(
         :error,
         :error,
         {:ok, _} = whole,
         written,
         {{:mword_el, _, _, _} = word, tag, l, at, s}
       ),
       do: word_after(:error, :error, whole, written, {mword_name(word), tag, l, at, s})

  defp word_after(:error, :error, {:ok, {first, symbol}}, _written, {word, _tag, line, _, shown}),
    do: [
      warning(
        line,
        "`#{shown}` is a bit of `#{word}`, which the `#{symbol}` #{where(first, line)} " <>
          "writes whole: #{last()}"
      )
    ]

  defp word_after(:error, :error, :error, {:ok, _} = written, {_word, tag, _line, at, shown}),
    do: in_array(written, {:array, tag}, at, shown)

  defp word_after(:error, :error, :error, :error, _coil), do: []

  # Decision 372: a coil through a tag subscript in an array of one dimension, which meets
  # every element, by its plain keys, at what it cost before; in one of two or three, by
  # the projections that may meet it.
  defp coil_in_array(nil, {:coil_at, {:array, array} = word, _, at, shown, id}, firsts) do
    {coils, wholes, bitted} = firsts

    warnings =
      array_coil(
        very(coils, word, id),
        Map.fetch(bitted, word),
        unlike(wholes, {:written, array}, id),
        Map.fetch(wholes, {:some, array}),
        {array, at, shown}
      )

    {warnings,
     {first(coils, word, at, id), first(wholes, word, at, id),
      first(bitted, word, {shown, at}, id)}}
  end

  defp coil_in_array(places, {:coil_at, {:array, array} = word, _, at, shown, id}, firsts) do
    {coils, wholes, bitted} = firsts

    warnings =
      array_coil(
        very_meeting(coils, word, places, id),
        meeting(bitted, word, places),
        unlike_meeting(wholes, {:written, array}, places, id),
        meeting(wholes, {:some, array}, places),
        {array, at, shown}
      )

    {warnings,
     {first_at(coils, word, places, at, id), first_at(wholes, word, places, at, id),
      first_at(bitted, word, places, {shown, at}, id)}}
  end

  # A coil through a tag subscript after a coil through one in its array, or after a write
  # of the array whole through one, is told the array the first may write; after a coil
  # on a literal element or a bit of one, or a write of an element whole, it is told that
  # element too, `w[1].3`, which it may not name, both being in the array.
  # M5-14's review (provisional): after a coil through the very tags, `ote lamps[slot]`
  # twice, it is told the element already has one, as `ote lamps[2]` twice and `ote w.[n]`
  # twice are, two coils through the very tag being two coils (decision 246).
  defp array_coil({:very, first}, _bitted, _written, _some, {_array, {line, _}, shown}),
    do: [second_ote(shown, first, line)]

  defp array_coil({:ok, first}, _bitted, _written, _some, {array, at, shown}),
    do: in_array({:ok, first}, {:array, array}, at, shown)

  defp array_coil(:error, {:ok, first}, _written, _some, coil), do: [as_in(first, coil)]

  defp array_coil(:error, :error, {:ok, first}, _some, {array, at, shown}),
    do: in_array({:ok, first}, {:array, array}, at, shown)

  defp array_coil(:error, :error, :error, {:ok, first}, coil), do: [as_in(first, coil)]
  defp array_coil(:error, :error, :error, :error, _coil), do: []

  defp array_after({:ok, first}, _bitted, {array, at, shown}),
    do: in_array({:ok, first}, {:array, array}, at, shown)

  defp array_after(:error, {:ok, first}, write), do: [as_in(first, write)]
  defp array_after(:error, :error, _write), do: []

  # Decision 431: a member's word judged as a word array (virtual/4) quoted as its array.
  defp as_in(first, {{:mword_of, array, _members}, at, shown}),
    do: as_in(first, {array, at, shown})

  defp as_in({other, {first, :ote}}, {array, {line, _symbol}, shown}),
    do:
      warning(
        line,
        "`#{shown}` is in `#{array}`, as `#{other}` is, which already has an `ote` " <>
          "#{where(first, line)}: #{last()}"
      )

  defp as_in({other, {first, coil}}, {array, {line, _symbol}, shown})
       when coil in [:osr, :osf],
       do:
         warning(
           line,
           "`#{shown}` is in `#{array}`, as `#{other}` is, which is already the pulse bit of " <>
             "the `#{coil}` #{where(first, line)}: #{last()}"
         )

  defp as_in({other, {first, {:writes, symbol}}}, {array, {line, _symbol}, shown}),
    do:
      warning(
        line,
        "`#{shown}` is in `#{array}`, as `#{other}` is, which the `#{symbol}` " <>
          "#{where(first, line)} writes: #{last()}"
      )

  defp as_in({other, {first, symbol}}, {array, {line, _symbol}, shown}),
    do:
      warning(
        line,
        "`#{shown}` is in `#{array}`, as `#{other}` is, which the `#{symbol}` " <>
          "#{where(first, line)} writes whole: #{last()}"
      )

  defp in_array(:error, _word, _at, _shown), do: []

  defp in_array(first, {:array, {:mword_of, array, _members}}, at, shown),
    do: in_array(first, {:array, array}, at, shown)

  defp in_array({:ok, {first, symbol}}, {:array, array}, {line, _symbol}, shown),
    do: [
      warning(
        line,
        "`#{shown}` is in `#{array}`, which the `#{symbol}` #{where(first, line)} may write " <>
          "through a tag subscript: #{last()}"
      )
    ]

  defp as_found(:error, _write), do: []
  defp as_found({:ok, first}, write), do: [as_in(first, write)]

  defp whole_after(:error, _at, firsts), do: {[], firsts}

  defp whole_after({:ok, {bit, first}}, {line, _symbol}, firsts),
    do: {[second_ote(bit, first, line)], firsts}

  # Decision 431: whole_writes/3, and a mark of each write a tag reaches of a member's word
  # of an element a coil names a bit of, by an instruction other than a coil, read in the
  # one walk of the instruction's write slots: whether a tag subscripts its element, and
  # whether a tag numbers its bit or it writes the word whole through a tag subscript
  # (covered/2). A literal element's word written whole or its literal bit marks nothing.
  defp mword_writes({symbol, _line, _operands}, _tags, _words)
       when symbol in [:ote, :osr, :osf, :ons],
       do: []

  defp mword_writes({symbol, line, operands} = instruction, tags, words),
    do:
      for(
        {{:write, _type}, operand} <-
          Enum.zip(Logex.Compiler.signature(instruction, tags), operands),
        decision <- wholes(operand, tags, words, {line, symbol}) ++ mword_write(operand, words),
        do: decision
      )

  defp mword_write({:member, _, {:element_at, _, array, _, _, _}, members}, words)
       when is_map_key(words, {:mword, {array, members}}),
       do: [{:mword_write, {array, members}}]

  # A literal element's literal bit, which only a coil through a tag subscript on a bit
  # a tag numbers is compared with (decided/2), where one is.
  defp mword_write({:bit, _, {:member, _, {:element, _, array, _, _}, members}, _, _, _}, words)
       when is_map_key(words, {:mnumbered, {array, members}}),
       do: [{:mword_latch, {array, members}}]

  defp mword_write(
         {:bit, _, {:member, _, {:element_at, _, array, _, _, _}, members}, _, _, _},
         words
       )
       when is_map_key(words, {:mword, {array, members}}),
       do: [{:mword_write, {array, members}}]

  defp mword_write(
         {:bit_at, _, {:member, _, {:element_at, _, array, _, _, _}, members}, _, _, _},
         words
       )
       when is_map_key(words, {:mword, {array, members}}),
       do: [{:mword_write, {array, members}}]

  defp mword_write(_operand, _words), do: []

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
        decision <- wholes(operand, tags, words, {line, symbol}),
        do: decision
      )

  defp wholes(operand, tags, words, at),
    do:
      for(
        {word, tag} <- whole(operand),
        is_map_key(words, word),
        do: {:whole, word, tag, at, same(operand)}
      ) ++
        in_arrays(operand, tags, words, at)

  # M5-12's review: a write of an element of a word array whole, `move x w[2]`, beside a
  # coil through a tag subscript, and any write through a tag subscript, `move x w[i]`,
  # `move x w[i].[n]`, beside a coil on a bit of an element of the array; and since
  # decision 235 so for a bool array, `move 0 lamps[slot]` beside `ote lamps[2]` and `move
  # 0 lamps[2]` beside `ote lamps[slot]`, each the write of any instruction but a coil
  # through its write slot, where a tag subscript stands on either side.
  # Decision 405 (RV-12): an element of a word array written whole writes every bit of it,
  # its bit's place a tag's; a bool array's element has no bits.
  defp in_arrays({:element, _, array, index, shown}, tags, words, at),
    do:
      element_whole(
        {array, shown, index ++ bit_place(Map.get(tags, array))},
        words,
        written_at(Map.get(tags, array), at)
      )

  defp in_arrays(
         {:bit_at, _, {:element, _, array, index, _}, _n, _width, shown},
         _tags,
         words,
         at
       ),
       do: element_whole({array, shown, index ++ [:tag]}, words, at)

  # Decision 405 (RV-12): an element of a word array written whole through a tag subscript
  # writes every bit of it, its bit's place a tag's.
  defp in_arrays({:element_at, _, array, _index, _dims, shown} = at_tag, tags, words, at),
    do:
      whole_at(
        {array, shown, same(at_tag), whole_places(same(at_tag), Map.get(tags, array))},
        words,
        at
      )

  defp in_arrays(
         {:bit, _, {:element_at, _, array, _, _, _}, _n, _mask, shown} = at_tag,
         _tags,
         words,
         at
       ),
       do: whole_at({array, shown, same(at_tag), places(same(at_tag))}, words, at)

  defp in_arrays(
         {:bit_at, _, {:element_at, _, array, _, _, _}, _index, _width, shown} = at_tag,
         _tags,
         words,
         at
       ),
       do: whole_at({array, shown, same(at_tag), places(same(at_tag))}, words, at)

  # Decision 253: a write of a member of an element, `otl lane_c[1].r` or `otl
  # lane_c[i].r`, any instruction's but a coil's, where a coil names that member.
  defp in_arrays({:member, _, {:element, _, array, index, element}, members}, _tags, words, at)
       when is_map_key(words, {:member_coiled, {array, members}}),
       do: [
         {:member_whole, {array, members}, member_write(at), Enum.join([element | members], "."),
          placed(index)}
       ]

  defp in_arrays(
         {:member, _, {:element_at, _, array, _, _, element} = at_tag, members},
         _tags,
         words,
         at
       )
       when is_map_key(words, {:member_coiled, {array, members}}),
       do: [
         {:member_whole_at, {array, members}, at, Enum.join([element | members], "."),
          same(at_tag)}
       ]

  # Decision 288: a whole write of a member of an element, of a literal one's or through a
  # tag subscript, `move 5 lane_c[1].pv` or `move 5 lane_c[j].pv`, where a coil names a bit
  # of that member through a tag subscript, `ote lane_c[i].pv.3`.
  defp in_arrays({:member, _, {:element, _, array, index, element}, members}, _tags, words, at)
       when is_map_key(words, {:member_bits_coiled, {array, members}}),
       do: [
         {:member_word_whole, {array, members}, at, Enum.join([element | members], "."),
          placed(index)}
       ]

  defp in_arrays(
         {:member, _, {:element_at, _, array, _, _, element} = at_tag, members},
         _tags,
         words,
         at
       )
       when is_map_key(words, {:member_bits_coiled, {array, members}}),
       do: [
         {:member_word_whole_at, {array, members}, at, Enum.join([element | members], "."),
          same(at_tag)}
       ]

  # Decision 257: so for a write of a bit of a member of an element, `otl lane_c[1].pv.3`
  # or `otl lane_c[i].pv.3`, where a coil names that bit, the bit's number one more part of
  # the member's path.
  defp in_arrays({:bit, l, {:member, _, element, members}, n, _mask, shown}, tags, words, at),
    do:
      in_arrays({:member, l, element, members ++ [Integer.to_string(n)]}, shown, tags, words, at)

  defp in_arrays(_operand, _tags, _words, _at), do: []

  defp in_arrays({:member, _, {:element, _, array, index, _}, members}, shown, _tags, words, at)
       when is_map_key(words, {:member_coiled, {array, members}}),
       do: [{:member_whole, {array, members}, member_write(at), shown, placed(index)}]

  defp in_arrays(
         {:member, _, {:element_at, _, array, _, _, _} = at_tag, members},
         shown,
         _,
         words,
         at
       )
       when is_map_key(words, {:member_coiled, {array, members}}),
       do: [{:member_whole_at, {array, members}, at, shown, same(at_tag)}]

  defp in_arrays(_member, _shown, _tags, _words, _at), do: []

  # A member a coil names is a bool, so its write is told as a write, not a whole one.
  defp member_write({line, symbol}), do: {line, {:writes, symbol}}

  defp element_whole({array, shown, index}, words, at) when is_map_key(words, {:array, array}),
    do: [{:element_whole, array, at, shown, placed(index)}]

  defp element_whole(_element, _words, _at), do: []

  # A bool array's element is no word, so its write is told as a write, not a whole one.
  defp written_at(%Tag{type: {:array, :bool, _dims}}, {line, symbol}),
    do: {line, {:writes, symbol}}

  defp written_at(_tag, at), do: at

  defp whole_at({array, shown, id, places}, words, at)
       when is_map_key(words, {:array, array}) or is_map_key(words, {:coiled_in, array}),
       do: [{:whole_at, array, at, shown, id, places}]

  defp whole_at(_element, _words, _at), do: []

  defp whole({:name, _, name}), do: [{name, name}]
  defp whole({:member, _, [instance | _] = path}), do: [{Enum.join(path, "."), instance}]

  # M5-14: a member of an element by its path, `lane_c[1].pv`, its tag its array.
  defp whole({:member, _, {:element, _, array, index, _element}, members}),
    do: [{Enum.join([Logex.Array.name(array, index) | members], "."), array}]

  # M5-9 (decision 160, provisional): a write of a bit whose number a tag holds may reach
  # any bit of its word, so it is a write of the word whole, as a write through a tag
  # subscript is of its array (§4.12's routine choice).
  defp whole({:bit_at, _, [container | _] = path, _index, _width, _name}),
    do: [{Enum.join(path, "."), container}]

  # Decision 221: a word is an element too, `faults[2]`, keyed by its subscripts' values, a
  # write of the element whole, `move x faults[2]`, or of a bit a tag numbers in it, a write
  # of that word whole, its tag its array.
  defp whole({:bit_at, _, {:element, _, array, _, _} = element, _index, _width, _name}),
    do: [{Walk.bit_name(element), array}]

  # Decision 257: a bit a tag numbers of a literal element's member, a write of the member.
  defp whole({:bit_at, _, {:member, _, {:element, _, array, index, _}, members}, _, _, _}),
    do: [{Enum.join([Logex.Array.name(array, index) | members], "."), array}]

  defp whole({:element, _, array, _index, _name} = element),
    do: [{Walk.bit_name(element), array}]

  defp whole(_bit_or_literal), do: []

  defp coil_target({:ote, line, [target]}), do: target(target, line, :ote)

  defp coil_target({symbol, line, [_storage, pulse]}) when symbol in [:osr, :osf],
    do: target(pulse, line, symbol)

  defp coil_target(_instruction), do: []

  defp target({:name, _, name}, line, symbol),
    do: [{:coil, name, nil, name, {line, symbol}, name, nil}]

  defp target({:member, _, [instance | _] = path}, line, symbol) do
    name = Enum.join(path, ".")
    [{:coil, name, nil, instance, {line, symbol}, name, nil}]
  end

  # Decision 221: a coil on a bit of an element, `ote faults[2].3`, decides that bit of the
  # element's word, keyed by its subscripts' values, its tag its array; since decision 405
  # its places its subscripts and its bit's number.
  defp target(
         {:bit, _, {:element, _, array, index, _} = element, n, _mask, shown} = bit,
         line,
         at
       ),
       do: [
         {:coil, Walk.bit_name(bit), Walk.bit_name(element), array, {line, at}, shown,
          index ++ [n]}
       ]

  defp target({:bit, _, [container | _] = path, _n, _mask, shown} = bit, line, symbol),
    do: [
      {:coil, Walk.bit_name(bit), Enum.join(path, "."), container, {line, symbol}, shown, nil}
    ]

  # M5-11 (decision 151): a coil on an element decides that element, keyed by its
  # subscripts' values, `lamps[2]`, and quoted as written, its tag its array's.
  defp target({:element, _, array, index, shown} = element, line, symbol),
    do: [{:coil, Walk.bit_name(element), nil, array, {line, symbol}, shown, placed(index)}]

  # M5-9 (provisional): a coil on a bit whose number a tag holds decides whichever bit the
  # number names, so it is a coil on its word whole, keyed by the word: a second one on the
  # word, `ote s.[n]` beside `ote s.[m]`, is the second-`ote` warning, and so is a coil on
  # a bit of the word, `ote s.3`, and, since M5-9's review, any write of the word whole,
  # `move x s`, either first, as decision 207 has it for a coil on `s.3`.
  defp target(
         {:bit_at, _, {:element, _, array, _, _} = element, _index, _width, shown} = bit,
         line,
         at
       ),
       do: [{:coil_at, Walk.bit_name(element), array, {line, at}, shown, same(bit)}]

  # Decision 257: so for a bit a tag numbers of a literal element's member, `ote
  # lane_c[1].pv.[n]`, keyed by the member's path, as `ote c.pv.[n]` is by `c.pv`; and
  # since decision 431 the member's word marked, a tag numbering its bit (coiled/2).
  defp target(
         {:bit_at, _, {:member, _, {:element, _, array, index, _}, members}, _, _, shown} = bit,
         line,
         symbol
       ),
       do: [
         {:coil_at, Enum.join([Logex.Array.name(array, index) | members], "."), array,
          {line, symbol}, shown, same(bit)},
         {:mword, {array, members}, false}
       ]

  # Decision 431 (RV-15): a coil on a bit a tag numbers of a member of an element a tag
  # subscripts, `ote lane_c[i].pv.[n]`, decides whichever bit of whichever element's member
  # they name, which only its member's word judged as a word array decides (virtual/4):
  # the word marked, a tag subscripting its element and numbering its bit (coiled/2).
  defp target(
         {:bit_at, _, {:member, _, {:element_at, _, array, _, _, _}, members}, _, _, _},
         _line,
         _symbol
       ),
       do: [{:mword, {array, members}, :numbered}]

  defp target({:bit_at, _, [container | _] = path, _index, _width, shown} = bit, line, symbol),
    do: [{:coil_at, Enum.join(path, "."), container, {line, symbol}, shown, same(bit)}]

  # M5-12 (§4.12's routine choice): a coil on an element a tag subscripts, `ote
  # lamps[slot]`, decides whichever element the subscript names, so it is a coil in the
  # array whole, keyed by the array, `{:array, "lamps"}`; and so is a coil on a bit of one,
  # `ote faults[i].3` or `ote faults[i].[n]`.
  defp target({:element_at, _, array, _index, _dims, shown} = element, line, symbol),
    do: [{:coil_at, {:array, array}, array, {line, symbol}, shown, same(element)}]

  defp target(
         {:bit, _, {:element_at, _, array, _, _, _}, _n, _mask, shown} = element,
         line,
         symbol
       ),
       do: [{:coil_at, {:array, array}, array, {line, symbol}, shown, same(element)}]

  defp target(
         {:bit_at, _, {:element_at, _, array, _, _, _}, _index, _width, shown} = element,
         line,
         symbol
       ),
       do: [{:coil_at, {:array, array}, array, {line, symbol}, shown, same(element)}]

  # M5-14 (decision 154): a coil on a member of an element, `ote lane_c[1].r`, decides that
  # member, keyed by its path, its tag its array; one through a tag subscript, `ote
  # lane_c[slot].r`, decides that member of whichever element the subscript names, so it is
  # a coil on that member of every element, keyed by the array and the member, `{"lane_c",
  # ["r"]}`, as a coil through a tag subscript is a coil in its array (M5-12). Since
  # decision 253 the two are compared as decision 235 compares a bool array's elements.
  # Decision 257: a coil on a bit of a member of an element, `ote lane_c[1].pv.3`, decides
  # that bit of the member's word, keyed by its path, `lane_c[1].pv.3`, as a coil on a bit
  # of a scalar instance's member, `ote c.pv.3`, is (M5-8's review), so that a second coil
  # on it and a write of the member whole, `move x lane_c[1].pv`, are the second-`ote`
  # warning; and it is that bit of a literal element, `{:member_bit, group}`, the bit's
  # number one more part of the member's path, for a coil or another write of the bit
  # through a tag subscript, `ote lane_c[i].pv.3`, which decision 253's rules compare as a
  # member's, a bit through the very tags warned of nothing beside another write and told
  # "already has an `ote`" beside a coil (decision 256).
  defp target(
         {:bit, _, {:member, _, {:element, _, array, index, _element}, members}, n, _, shown},
         line,
         symbol
       ) do
    word = Enum.join([Logex.Array.name(array, index) | members], ".")
    bit = Integer.to_string(n)

    [
      {:coil, word <> "." <> bit, word, array, {line, symbol}, shown, placed(index)},
      {:member_bit, {array, members ++ [bit]}, {line, symbol}, shown, placed(index)},
      {:mword, {array, members}, false}
    ]
  end

  defp target(
         {:bit, _, {:member, _, {:element_at, _, array, _, _, _} = at, members}, n, _, shown},
         line,
         symbol
       ),
       do: [
         {:member_bit_at, {array, members ++ [Integer.to_string(n)]}, {array, members},
          {line, symbol}, shown, same(at)},
         {:mword, {array, members}, true}
       ]

  defp target({:member, _, {:element, _, array, index, element}, members}, line, symbol),
    do: [
      {:member_coil, Enum.join([Logex.Array.name(array, index) | members], "."), {array, members},
       {line, symbol}, Enum.join([element | members], "."), placed(index)}
    ]

  defp target({:member, _, {:element_at, _, array, _, _, element} = at, members}, line, symbol),
    do: [
      {:member_coil_at, {array, members}, {line, symbol}, Enum.join([element | members], "."),
       same(at)}
    ]

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
      owners
      |> Map.keys()
      |> Enum.filter(&String.contains?(&1, "."))
      |> Enum.group_by(&container_of/1)

    uses = Enum.flat_map(instructions, &others(&1, written(&1, tags)))
    arrays = storage_arrays(subscripted(uses), instructions, owners)

    for {operand, line, symbol} <- uses,
        {name, shown} <- storage_names(operand, {words, arrays}),
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

        {symbol, _line, [{:bit, _, {:element, _, _, _, _}, _, _, shown} = bit | _]}, owners
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
  defp storage_names({:name, _, name}, {words, _owners}),
    do: [{name, name} | Enum.map(Enum.sort(Map.get(words, name, [])), &{&1, nil})]

  defp storage_names({:bit, _, [_], _, _, shown} = bit, _known), do: [{Walk.bit_name(bit), shown}]

  # Decision 221: a bit of an element, `faults[2].3`, by its name.
  defp storage_names({:bit, _, {:element, _, _, _, _}, _, _, shown} = bit, _known),
    do: [{Walk.bit_name(bit), shown}]

  # M5-11 (decision 154): an element kept as a storage bit, `edge[2]`, by its name, and
  # since decision 221 every storage bit kept in a bit of it, a write of the element whole.
  defp storage_names({:element, _, _, _, shown} = element, {words, _owners}) do
    name = Walk.bit_name(element)
    [{name, shown} | Enum.map(Enum.sort(Map.get(words, name, [])), &{&1, nil})]
  end

  # M5-9: a bit whose number a tag holds may be any bit of its word, a storage bit's among
  # them, as a write of the word whole is, and since decision 221 so in an element.
  defp storage_names({:bit_at, _, [word], _index, _width, _shown}, {words, _owners}),
    do: Enum.map(Enum.sort(Map.get(words, word, [])), &{&1, nil})

  defp storage_names({:bit_at, _, {:element, _, _, _, _} = element, _, _, _}, {words, _owners}),
    do: Enum.map(Enum.sort(Map.get(words, Walk.bit_name(element), [])), &{&1, nil})

  # M5-12 (§4.12's routine choice): a write through a tag subscript, of an element or of a
  # bit of one, may reach any element of its array, so every storage bit kept in the
  # array, an element's or a bit of one's, in name order. Since RV-12 (decision 405) a
  # storage bit is judged as decision 372 judges two writes: only those its places may
  # meet, a tag subscript meeting every value and a literal its own, a bit's literal
  # number one more place and a bit a tag numbers a tag's, so `ote e[i,0]` reaches no
  # `ons e[1,1]` and `ote w[i].4` no `ons w[1].3`, and an element written whole meets
  # every bit of it.
  defp storage_names({:element_at, _, array, index, _, _}, {_words, arrays}),
    do: storage_meeting(arrays, array, Enum.map(index, &subscript_place/1))

  defp storage_names({:bit, _, {:element_at, _, array, index, _, _}, n, _, _}, {_words, arrays}),
    do: storage_meeting(arrays, array, Enum.map(index, &subscript_place/1) ++ [n])

  defp storage_names(
         {:bit_at, _, {:element_at, _, array, index, _, _}, _, _, _},
         {_words, arrays}
       ),
       do: storage_meeting(arrays, array, Enum.map(index, &subscript_place/1) ++ [:tag])

  defp storage_names(_member, _known), do: []

  # A storage bit kept under every projection of its places, `{array, positions, places
  # there}`, at most 16, in name order; a write meets those its literal places' projection
  # holds, a tag's place meeting every value, and an element written whole, which has no
  # bit's place, every bit of it: one lookup, so the warnings stay linear in the writes.
  defp kept(arrays, array, places, bit),
    do:
      Enum.reduce(projections(Enum.with_index(places)), arrays, fn {positions, there}, arrays ->
        Map.update(arrays, {array, positions, there}, [bit], &[bit | &1])
      end)

  defp storage_meeting(arrays, array, places),
    do: Map.get(arrays, {array, literal_positions(places), literal_places(places)}, [])

  defp literal_positions(places),
    do: for({place, at} <- Enum.with_index(places), place != :tag, do: at)

  defp literal_places(places), do: for(place <- places, place != :tag, do: place)

  defp subscript_place({:name, _, _tag}), do: :tag
  defp subscript_place(value), do: value

  # RV-2 (the review after Milestone 6, a4-warnings-walk-3): the storage bits kept in each
  # array, in name order, gathered once, where each write through a tag subscript sorted
  # and searched every one-shot of the routine; since decision 405 by every projection of
  # its places, its subscripts' values and a bit's number, so that a write looks up the
  # one its literal places make (storage_meeting/3). RV-12's review: only those in the
  # arrays some write names through a tag subscript, the only writes that look them up,
  # each named only then, so a routine whose one-shots keep their storage bits in elements
  # of arrays no write names so keeps none, and costs no more than it did before decision
  # 405.
  defp storage_arrays(subscripted, instructions, owners) do
    instructions
    |> storage_places(subscripted)
    |> Enum.sort(:desc)
    |> Enum.reduce(%{}, fn {name, {array, places}}, arrays ->
      kept(arrays, array, places, {name, own_shown(Map.fetch!(owners, name), name)})
    end)
  end

  # The arrays some write names through a tag subscript, an element's or a bit of one's.
  defp subscripted(uses),
    do:
      for(
        {operand, _line, _symbol} <- uses,
        array = subscripted_in(operand),
        array != nil,
        into: %{},
        do: {array, true}
      )

  defp subscripted_in({:element_at, _, array, _index, _dims, _shown}), do: array
  defp subscripted_in({:bit, _, {:element_at, _, array, _, _, _}, _n, _mask, _shown}), do: array
  defp subscripted_in({:bit_at, _, {:element_at, _, array, _, _, _}, _, _, _}), do: array
  defp subscripted_in(_operand), do: nil

  # Decision 405: each storage bit an element or a bit of one keeps in an array a write
  # names through a tag subscript, by its name, its array and its places, its subscripts'
  # values and a bit's number.
  defp storage_places(instructions, subscripted),
    do:
      for(
        {symbol, _line, [storage | _]} <- instructions,
        symbol in @one_shots,
        {name, array, places} <- storage_place(storage, subscripted),
        into: %{},
        do: {name, {array, places}}
      )

  defp storage_place({:element, _, array, index, _name} = element, subscripted)
       when is_map_key(subscripted, array),
       do: [{Walk.bit_name(element), array, index}]

  defp storage_place(
         {:bit, _, {:element, _, array, index, _}, n, _mask, _name} = bit,
         subscripted
       )
       when is_map_key(subscripted, array),
       do: [{Walk.bit_name(bit), array, index ++ [n]}]

  defp storage_place(_tag_bit_or_unsubscripted, _subscripted), do: []

  # Each quoted as its one-shot writes it, an element's by its subscripts' values, `e[2]`,
  # a bit of one as written (written_bits/2).

  defp own_shown({_line, _owner}, name), do: name
  defp own_shown({_line, _owner, _shown}, _name), do: nil

  # A storage bit's tag: a bool's own name, the word a bit of one is in, or since M5-11 the
  # array an element is of.
  defp word_of(name), do: hd(String.split(name, [".", "["]))

  # A storage bit's word, the name before its last `.`: a tag's, `status` of `status.3`, or
  # since decision 221 an element's, `faults[2]` of `faults[2].3`, whose whole write reaches
  # it.
  defp container_of(name),
    do: binary_part(name, 0, elem(List.last(:binary.matches(name, ".")), 0))

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
       when symbol in @comparisons and is_literal(a) and is_literal(b),
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
       when symbol in @arithmetic and is_literal(a) and is_literal(b),
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
  # Since M5-10 the 34 real conversions and the 16 truncations too, and `sqrt` among the
  # instructions of one source.
  @numbers Declarations.convertible() ++ Declarations.reals()

  @conversions for(
                 from <- @numbers,
                 to <- @numbers,
                 word = Declarations.conversion(from, to),
                 do: String.to_atom(word)
               ) ++
                 for(
                   from <- Declarations.reals(),
                   to <- Declarations.integers(),
                   do: String.to_atom("#{from}_trunc_#{to}")
                 )

  @one_source [:neg, :abs, :not, :sqrt] ++ @conversions

  defp constant({symbol, line, [a, _destination]}) when symbol in @one_source and is_literal(a),
    do: [warning(line, "`#{symbol}` reads a literal, #{shown(a)}: its result never changes")]

  defp constant(_instruction), do: []

  # Decision 187: a comparison of a tag with a literal at its type's own limit, which
  # decision 183 compiles, is warned of in the all-literal warning's words wherever its
  # result never changes. With the tag of type lo..hi on the left, `ge x lo` always passes
  # power and `lt x lo` never does, `le x hi` always and `gt x hi` never; with the literal
  # on the left the mirror, `le lo x` and `ge hi x` always, `gt lo x` and `lt hi x` never.
  # `eq` and `ne` at a limit, and every comparison inside the range, can go either way, and
  # a literal outside the range is decision 183's refusal.
  # One pass over the instructions for the warnings a literal raises, decision 187's and,
  # since decision 219, a real literal's, each told by its clause's guard.
  defp by_literal({symbol, line, [operand, literal]}, tags)
       when symbol in @comparisons and is_int_lit(literal),
       do: limited(integer_type(operand, tags), {symbol, :right}, {operand, literal}, line)

  defp by_literal({symbol, line, [literal, operand]}, tags)
       when symbol in @comparisons and is_int_lit(literal),
       do: limited(integer_type(operand, tags), {symbol, :left}, {operand, literal}, line)

  defp by_literal({_, _, [a | _]} = instruction, tags) when is_real_lit(a),
    do: rounded_literals(instruction, tags)

  defp by_literal({_, _, [_, b | _]} = instruction, tags) when is_real_lit(b),
    do: rounded_literals(instruction, tags)

  defp by_literal({_, _, [_, _, c | _]} = instruction, tags) when is_real_lit(c),
    do: rounded_literals(instruction, tags)

  defp by_literal({:cal, _, [_, _, _, _ | _]} = instruction, tags),
    do: rounded_literals(instruction, tags)

  defp by_literal(_instruction, _tags), do: []

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

  defp shown({:member, _, element, members}),
    do: "`#{Enum.join([elem(element, tuple_size(element) - 1) | members], ".")}`"

  defp shown({:element, _, _array, _index, name}), do: "`#{name}`"
  defp shown({:element_at, _, _array, _index, _dims, name}), do: "`#{name}`"
  defp shown(literal) when is_literal(literal), do: "`#{Parser.spelling(literal)}`"

  # An operand's integer type, a tag's or a member's of the built-in instance that holds
  # it; anything else, a bool or a member of a user block's instance, which no comparison
  # takes, is passed over. Since M5-8's review a bit string too, which compares as unsigned
  # (decision 155), so `ge status 0` on a `word` is warned as on a `uint` (provisional).
  @integers Declarations.integers() ++ Declarations.bit_strings()

  defp integer_type({:name, _, name}, tags), do: of_integer(Map.get(tags, name))

  defp integer_type({:member, _, [instance, member]}, tags),
    do: member_integer(Map.get(tags, instance), member)

  # M5-11: an element is of its array's elements' type.
  defp integer_type({:element, _, array, _index, _name}, tags),
    do: element_integer(Map.get(tags, array))

  defp integer_type({:element_at, _, array, _index, _dims, _name}, tags),
    do: element_integer(Map.get(tags, array))

  # M5-14: a member of an element of an array of built-in instances, its member's type.
  defp integer_type({:member, _, element, [member]}, tags),
    do: member_integer(of_elements(Map.get(tags, elem(element, 2))), member)

  defp integer_type(_other, _tags), do: :error

  defp element_integer(%Tag{type: {:array, type, _dims}}) when type in @integers, do: {:ok, type}
  defp element_integer(_other), do: :error

  defp of_integer(%Tag{type: type}) when type in @integers, do: {:ok, type}
  defp of_integer(_other), do: :error

  # RV-2 (the review after Milestone 6, a4-warnings-walk-4): a user block's member too,
  # which decision 183 types, scalar or of an element.
  defp member_integer(%Tag{type: %FbType{} = type}, member),
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

  # M5-14: a member of an element of an array of long timers, `cure[1].acc`.
  defp long_member({:member, _, element, [member]} = operand, tags)
       when member in ["pre", "acc"],
       do: long(per_ms(of_elements(Map.get(tags, elem(element, 2)))), operand)

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

  # Decision 431: a member's word judged as a word array (virtual/4) is its array's.
  defp from_source?(tags, {:mword_of, array, _members}), do: from_source?(tags, array)

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
