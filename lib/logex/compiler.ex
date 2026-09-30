defmodule Logex.Compiler do
  alias Logex.{Declarations, Diagnostic, FbType, Program, Tag}
  alias Logex.FbType.Member

  defdelegate tokenize(source), to: Logex.Lexer
  defdelegate parse(tokens), to: Logex.Parser

  # Each mnemonic's operand signature, in order, one `{access, type}` per operand. Access:
  # `:read` and `:write` must be a tag, and `:value` may be a tag or an integer literal.
  # M1-6 adds two: `{:instance, type}` is an instance of that function block type, which
  # the instruction runs, the only slot where an instance is named whole; `:preset` is a
  # literal number of milliseconds, 0 to 2147483647. Type: `:bool`, `:dint`, or `:any`,
  # which IEC's MOVE takes (`IN : ANY` -> `OUT : ANY`, docs/naming.md). A tag here may be
  # a member of an instance, `t1.acc`, which has the type its schema gives it (M1-6).
  # Mnemonics are matched case-insensitively and are reserved: no tag may be named after
  # one, in any case.
  @instructions %{
    "xic" => {:xic, [{:read, :bool}]},
    "xio" => {:xio, [{:read, :bool}]},
    "ote" => {:ote, [{:write, :bool}]},
    "otl" => {:otl, [{:write, :bool}]},
    "otu" => {:otu, [{:write, :bool}]},
    "move" => {:move, [{:value, :any}, {:write, :any}]},
    "ons" => {:ons, [{:write, :bool}]},
    "eq" => {:eq, [{:value, :dint}, {:value, :dint}]},
    "ne" => {:ne, [{:value, :dint}, {:value, :dint}]},
    "lt" => {:lt, [{:value, :dint}, {:value, :dint}]},
    "gt" => {:gt, [{:value, :dint}, {:value, :dint}]},
    "le" => {:le, [{:value, :dint}, {:value, :dint}]},
    "ge" => {:ge, [{:value, :dint}, {:value, :dint}]},
    "ton" => {:ton, [{:instance, "ton"}, {:preset, :dint}]}
  }

  @doc """
  The mnemonic table: each lowercase mnemonic to its IR symbol and operand signature.

  Every key must have a `### \\`mnemonic\\`` stanza in `docs/naming.md`;
  `Logex.NamingTest` enforces it.
  """
  def instructions, do: @instructions

  @doc """
  Lowers a parse AST to a `%Logex.Program{}`: its leading declaration lines become the tag
  table (`Logex.Declarations`), and every other rung is lowered to the IR, each instruction
  checked against its operand signature.

  Returns `{:ok, %Logex.Program{}}`, where an instruction in `rungs` is
  `{symbol, line, operands}`, or `{:error, diagnostics}`: every `%Logex.Diagnostic{}` in
  the routine, in line order. `declared` is a list of `%Logex.Tag{}` built in Elixir with
  `Logex.Tag.new!/4`, entered in the table before the source's own.

  After a word that cannot start an instruction (an unknown word, an old branch keyword, or
  a number), the words after it are skipped up to the next instruction or branch group, so
  its would-be operands are not each reported as unknown instructions too. An instruction's
  operands stop early at an instruction or a branch group, which is then lowered as usual.
  """
  def instructionize({:routine, {:rungs, rungs}} = routine, declared \\ []) do
    {tags, logic, declaring} = Declarations.split(rungs, declared)
    {rungs, lowering} = Enum.map_reduce(logic, [], &lower_rung(&1, &2, tags))
    note? = map_size(tags) == 0 and declares_nothing?(routine, logic)
    instructions = instructions(rungs)
    shared = shared_bits(instructions, tags)
    {tags, timing} = presets(instructions, tags)
    paths = Enum.flat_map(rungs, fn {:rung, elements} -> path(elements, tags) end)
    errors = declaring ++ undeclared(Enum.reverse(lowering), tags, note?) ++ shared ++ timing
    lowered(rungs, tags, errors ++ paths)
  end

  # M1-6: one `ons` uses a storage bit. A second `ons` on one bit is an error at its own
  # line, citing the first: the false one clears the bit every scan, so the true one fires
  # on every scan its rung is true, and no arrangement of two works. Any other writer of
  # the bit is only a warning (Logex.Warnings), since it may be a deliberate re-arm. An
  # `ons` on anything but a declared bool was reported already and is passed over. One walk
  # in rung order, so it stays linear.
  defp shared_bits(instructions, tags) do
    {_first, diagnostics} = Enum.reduce(instructions, {%{}, []}, &shared_bit(&1, &2, tags))

    Enum.reverse(diagnostics)
  end

  defp shared_bit({:ons, line, [{:name, _, bit}]}, {first, diagnostics}, tags),
    do: storage_bit(Map.fetch(first, bit), Map.get(tags, bit), {bit, line}, {first, diagnostics})

  defp shared_bit(_instruction, acc, _tags), do: acc

  defp storage_bit(:error, %Tag{type: :bool}, {bit, line}, {first, diagnostics}),
    do: {Map.put(first, bit, line), diagnostics}

  defp storage_bit({:ok, first_line}, %Tag{}, {bit, line}, {first, diagnostics}) do
    message =
      "`#{bit}` is already the storage bit of the `ons` #{where(first_line, line)}: " <>
        "each `ons` needs a storage bit of its own"

    {first, [diagnostic(line, message) | diagnostics]}
  end

  defp storage_bit(:error, _not_a_bool, _ons, acc), do: acc

  # M1-6: one `ton` runs a timer, and the number on it is the timer's preset, its `.pre`
  # when an instance starts or restarts, which logic may then change (decision 4). So the
  # compiled tag carries it, as the initial value of its `pre`. A second `ton` on a timer
  # is an error at its own line, citing the first, as a second `ons` on a storage bit is:
  # two would give a timer two presets, and a false one resets the timer under a true one
  # every scan. One walk in rung order, so it stays linear.
  defp presets(instructions, tags) do
    {run, diagnostics} =
      instructions
      |> Enum.flat_map(&ton/1)
      |> Enum.reduce({%{}, []}, &preset(&1, &2, tags))

    {Enum.reduce(run, tags, fn {timer, {_line, pre}}, tags -> starts(tags, timer, pre) end),
     Enum.reverse(diagnostics)}
  end

  # Every `ton` that names a timer runs it, whatever its preset: `ton t1 sp` and a second
  # `ton t1 5000` are two mistakes. A preset that is not a literal was reported already, and
  # a program with a diagnostic never runs, so its nil is never a timer's `.pre`.
  defp ton({:ton, line, [{:name, _, timer} | preset]}), do: [{timer, line, preset_of(preset)}]
  defp ton(_instruction), do: []

  defp preset_of([{:int_lit, _, preset}]), do: preset
  defp preset_of(_reported), do: nil

  defp preset({timer, line, pre}, {run, diagnostics}, tags),
    do:
      run_by(Map.fetch(run, timer), Map.get(tags, timer), {timer, line, pre}, {run, diagnostics})

  defp run_by(:error, %Tag{type: %FbType{}}, {timer, line, pre}, {run, diagnostics}),
    do: {Map.put(run, timer, {line, pre}), diagnostics}

  defp run_by({:ok, {first, _}}, %Tag{}, {timer, line, _pre}, {run, diagnostics}) do
    message =
      "`#{timer}` is already run by the `ton` #{where(first, line)}: one `ton` runs a timer"

    {run, [diagnostic(line, message) | diagnostics]}
  end

  defp run_by(:error, _not_an_instance, _ton, acc), do: acc

  defp starts(tags, timer, pre), do: Map.update!(tags, timer, &%{&1 | initial: %{"pre" => pre}})

  # M1-6: nothing may follow a `ton` on its path. Whether the power after a `ton` is the
  # rung's, as after `ote`, or the timer's `.dn`, IEC's Q, is not settled, and refusing
  # both is the reversible way to leave it open. An element bears a `ton` if it is one, or
  # if it is a group one of whose legs holds one, and in every series, a rung or a leg,
  # each element after one that bears a `ton` is an error at its own line, once, citing
  # the first such `ton`. Legs beside a `ton` are not on its path, and are fine. One walk of
  # a rung, whose diagnostics are gathered newest first and reversed once, so a group
  # nested deep is not copied at every level.
  defp path(elements, tags) do
    {diagnostics, _borne} = series(elements, nil, [], tags)
    Enum.reverse(diagnostics)
  end

  # A series, a rung or a leg: its diagnostics onto `diagnostics`, and the first `ton` on it.
  defp series([], before, diagnostics, _tags), do: {diagnostics, before}

  defp series([element | rest], before, diagnostics, tags) do
    {diagnostics, borne} = bears(element, follows(before, element, tags) ++ diagnostics, tags)
    series(rest, earliest(before, borne), diagnostics, tags)
  end

  defp bears({:ton, _, _} = ton, diagnostics, _tags), do: {diagnostics, ton}

  defp bears({:branches, legs}, diagnostics, tags),
    do: Enum.reduce(legs, {diagnostics, nil}, &leg(&1, &2, tags))

  defp bears(_instruction, diagnostics, _tags), do: {diagnostics, nil}

  defp leg(elements, {diagnostics, before}, tags) do
    {diagnostics, borne} = series(elements, nil, diagnostics, tags)
    {diagnostics, earliest(before, borne)}
  end

  defp earliest(nil, bears), do: bears
  defp earliest(before, _bears), do: before

  defp follows(nil, _element, _tags), do: []

  defp follows({:ton, line, operands}, element, tags) do
    message =
      "#{shown(element)} follows #{shown({:ton, line, Enum.take(operands, 1)})} on its path: " <>
        "what passes on after a `ton` is not settled, so a `ton` ends its path; " <>
        read_timer(operands, tags)

    [diagnostic(line_of(element, line), message)]
  end

  defp shown({:branches, _legs}), do: "a branch group"
  defp shown({symbol, _line, []}), do: "`#{symbol}`"

  defp shown({symbol, _line, operands}),
    do: "`#{symbol} #{Enum.map_join(operands, " ", &text/1)}`"

  defp text({:name, _, name}), do: name
  defp text({:int_lit, _, value}), do: "#{value}"
  defp text({:member, _, path}), do: Enum.join(path, ".")

  defp read_timer([{:name, _, timer} | _], tags), do: read(timer?(timer, tags), timer)
  defp read_timer(_no_timer, _tags), do: read(false, nil)

  defp read(true, timer), do: "read the timer with `xic #{timer}.dn` on a rung below"
  defp read(false, _timer), do: "read the timer's `.dn` on a rung below"

  # Whether a hint may name `name` as a timer: a declared one, or a name not declared yet,
  # which the hint fits once it is declared as one. Anything else, a bool, a member or a
  # reserved word, has a diagnostic of its own, which a hint beside it would contradict.
  defp timer?(name, tags), do: runnable?(Declarations.reserved(name), lookup(name, tags))

  defp runnable?(nil, {:ok, %Tag{type: %FbType{name: "ton"}}}), do: true
  defp runnable?(nil, :error), do: true
  defp runnable?(_reserved, _found), do: false

  # A group carries no line of its own, so it is cited at the `ton`'s: a rung is one line.
  defp line_of({:branches, _legs}, ton_line), do: ton_line
  defp line_of({_symbol, line, _operands}, _ton_line), do: line

  # Every instruction of every rung, in order, the legs of a group, however deeply nested,
  # included. Gathered newest first and reversed once, so it stays linear in the depth of
  # nesting too.
  defp instructions(rungs) do
    rungs
    |> Enum.reduce([], fn {:rung, elements}, gathered -> gather(elements, gathered) end)
    |> Enum.reverse()
  end

  defp gather(elements, gathered), do: Enum.reduce(elements, gathered, &gathered/2)

  defp gathered({:branches, legs}, gathered), do: Enum.reduce(legs, gathered, &gather/2)
  defp gathered(instruction, gathered), do: [instruction | gathered]

  defp where(line, line), do: "in this rung"
  defp where(first, _line), do: "on line #{first}"

  # No declaration line at all, as opposed to declarations that were all wrong.
  defp declares_nothing?({:routine, {:rungs, rungs}}, logic), do: length(rungs) == length(logic)

  defp lowered(rungs, tags, []),
    do: {:ok, %Program{rungs: rungs, tags: tags, warnings: Logex.Warnings.of(rungs, tags)}}

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_rungs, _tags, diagnostics), do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  defp lower_rung({:rung, elements}, diagnostics, tags) do
    {ir, diagnostics} = lower(elements, [], diagnostics, tags)
    {{:rung, ir}, diagnostics}
  end

  # Diagnostics are accumulated newest first and reversed once, in instructionize/2. An
  # undeclared tag is accumulated as `{:undeclared, line, name, slot}`, with the slot it is
  # used in or `:member`, and reported by undeclared/3, at its first use only.
  defp lower([], ir, diagnostics, _tags), do: {Enum.reverse(ir), diagnostics}

  defp lower([{:branches, legs} | rest], ir, diagnostics, tags) do
    {legs, diagnostics} = Enum.map_reduce(legs, diagnostics, &lower(&1, [], &2, tags))
    lower(rest, [{:branches, legs} | ir], diagnostics, tags)
  end

  defp lower([{:name, line, word} | rest], ir, diagnostics, tags) do
    key = String.downcase(word)
    lower_word(Map.fetch(@instructions, key), key, {line, word}, {rest, ir, diagnostics, tags})
  end

  # The grammar allows a literal anywhere an element can go, including where an
  # instruction must start: `123 aa`, or an extra operand as in `xic aa 7 ote bb`.
  defp lower([{:int_lit, line, value} | rest], ir, diagnostics, tags) do
    found = diagnostic(line, "expected an instruction, found `#{value}`")
    lower(skip_operands(rest), ir, [found | diagnostics], tags)
  end

  defp lower_word({:ok, {symbol, signature}}, _key, {line, _} = at, {rest, ir, diagnostics, tags}) do
    {operands, rest} = take_operands(rest, length(signature), [])
    diagnostics = check_count(signature, operands, rest, at, diagnostics)
    diagnostics = check_kinds(signature, operands, at, diagnostics)
    diagnostics = check_tags(signature, operands, at, tags, diagnostics)
    diagnostics = check_preset(signature, operands, at, tags, diagnostics)
    lower(rest, [{symbol, line, Enum.map(operands, &operand/1)} | ir], diagnostics, tags)
  end

  defp lower_word(:error, key, {line, word}, {rest, ir, diagnostics, tags}) do
    unknown = diagnostic(line, unknown(key, word))
    lower(skip_operands(rest), ir, [unknown | diagnostics], tags)
  end

  # M1-6: a member is lowered to its path, so the runtime reads and writes it without
  # splitting its name again: `t1.acc` becomes `{:member, line, ["t1", "acc"]}`. A dotted
  # name that resolves to nothing has a diagnostic, and a program with one never runs.
  defp operand({:name, line, name}), do: dotted(String.split(name, "."), line, name)
  defp operand(literal), do: literal

  defp dotted([_one], line, name), do: {:name, line, name}
  defp dotted(path, line, _name), do: {:member, line, path}

  @migrated ~w(bst nxb bnd)

  # B1 made the branch delimiters punctuation, and the migration is otherwise silent: an
  # old `bst …` program is no longer a syntax error, so it arrives here. Only instruction
  # position is claimed -- `bst` remains a perfectly good tag name.
  defp unknown(key, word) when key in @migrated,
    do: "`#{word}` is no longer a keyword — branches are written `( … | … )`"

  # PLAN.md §5: renamed to its IEC 61131-3 name, with no alias.
  defp unknown("mov", word),
    do: "unknown instruction `#{word}` — did you mean `move`? (renamed to its IEC name)"

  defp unknown(key, word), do: unknown_word(Declarations.reserved(key), word)

  # A declaration is a line of its own, recognised only as a rung's first word.
  defp unknown_word(:section, word),
    do: "`#{word}` starts a declaration, which is a line of its own before the first rung"

  defp unknown_word(_reserved, word), do: "unknown instruction `#{word}`"

  # Takes up to `n` operands, stopping early at a branch group, at the end of the leg, or
  # at a mnemonic: that is the next instruction, so `move src ote bb` leaves `ote bb` intact.
  defp take_operands(rest, 0, taken), do: {Enum.reverse(taken), rest}

  defp take_operands([{:int_lit, _, _} = literal | rest], n, taken),
    do: take_operands(rest, n - 1, [literal | taken])

  defp take_operands([{:name, _, word} = name | rest] = elements, n, taken),
    do: take_name(mnemonic?(word), name, rest, elements, n, taken)

  defp take_operands(elements, _n, taken), do: {Enum.reverse(taken), elements}

  defp take_name(true, _name, _rest, elements, _n, taken), do: {Enum.reverse(taken), elements}

  defp take_name(false, name, rest, _elements, n, taken),
    do: take_operands(rest, n - 1, [name | taken])

  defp check_count(signature, operands, _rest, _at, diagnostics)
       when length(operands) == length(signature),
       do: diagnostics

  defp check_count(signature, operands, rest, {line, word}, diagnostics) do
    message =
      "`#{word}` expects #{describe(signature)}, found #{found(length(operands))}" <>
        stopped_at(rest)

    [diagnostic(line, message) | diagnostics]
  end

  defp describe(signature),
    do: "#{operand_count(length(signature))} (#{Enum.map_join(signature, ", then ", &kind/1)})"

  defp operand_count(1), do: "1 operand"
  defp operand_count(count), do: "#{count} operands"

  # A new access needs a clause here and in check_kind/4; without them, the first program
  # that uses it raises FunctionClauseError rather than passing unchecked.
  defp kind({:read, _type}), do: "a tag"
  defp kind({:write, _type}), do: "a tag"
  defp kind({:value, _type}), do: "a value"
  defp kind({:instance, type}), do: "a #{type}"
  defp kind({:preset, _type}), do: "a preset"

  defp found(0), do: "none"
  defp found(count), do: "#{count}"

  # Operands stop early only at an instruction, a branch group or the end of the leg. Which
  # of the two the writer got wrong -- a forgotten operand, or an instruction's name used as
  # a tag -- cannot be told from here, so the message says where the operands stopped.
  defp stopped_at([{:name, _, word} | _]), do: " before the instruction `#{word}`"
  defp stopped_at([{:branches, _} | _]), do: " before a branch group"
  defp stopped_at([]), do: ""

  defp check_kinds([kind | kinds], [operand | operands], at, diagnostics),
    do: check_kinds(kinds, operands, at, check_kind(kind, operand, at, diagnostics))

  defp check_kinds(_kinds, [], _at, diagnostics), do: diagnostics

  # What each kind accepts, as an allowlist. take_operands/3 only ever takes names and
  # literals, so a literal where a tag must go is the one thing left to report; any other
  # pairing raises here rather than reaching evaluate/3 unchecked.
  defp check_kind({:read, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:write, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:value, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:value, _type}, {:int_lit, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:instance, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:preset, _type}, {:int_lit, _, _}, _at, diagnostics), do: diagnostics

  # A preset from a tag is not a preset: check_preset/4 names the `move` that is meant.
  defp check_kind({:preset, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  defp check_kind(kind, {:int_lit, _, value}, {line, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects #{kind(kind)}, found `#{value}`") | diagnostics]

  # M1-6: `ton t1 sp`. The preset is the timer's starting `.pre`, a number on the rung; a
  # value from a tag is moved into `.pre` instead, which logic may write (decision 4).
  defp check_preset([_, {:preset, _}], [first, {:name, line, name}], {_, word}, tags, diagnostics) do
    message =
      "`#{word}` takes its preset as a number of milliseconds, found `#{name}`" <>
        moved(first, name, tags)

    [diagnostic(line, message) | diagnostics]
  end

  defp check_preset(_signature, _operands, _at, _tags, diagnostics), do: diagnostics

  # The `move` is named only where it would compile, once a name in it not declared yet is
  # declared: into a timer's `.pre`, from a dint.
  defp moved({:name, _, timer}, name, tags),
    do: move(timer?(timer, tags) and dint?(name, tags), timer, name)

  defp moved(_literal, _name, _tags), do: ""

  defp move(true, timer, name),
    do: ": to preset `#{timer}` from a tag, `move #{name} #{timer}.pre` on a rung above"

  defp move(false, _timer, _name), do: ""

  defp dint?(name, tags), do: dint_value?(Declarations.reserved(name), lookup(name, tags))

  defp dint_value?(nil, {:ok, %Tag{type: :dint}}), do: true
  defp dint_value?(nil, {:member, _tag, %Member{type: :dint}}), do: true
  defp dint_value?(nil, :error), do: true
  defp dint_value?(_reserved, _found), do: false

  # M1-3: each operand against the tag table -- declared, of the type its slot reads or
  # writes, and not a var_input where the slot writes. A literal where a tag must go was
  # reported by check_kind/4 and is not looked at again. Then the `:any` operands must agree.
  defp check_tags(signature, operands, at, tags, diagnostics) do
    slots = Enum.zip(signature, operands)
    diagnostics = Enum.reduce(slots, diagnostics, &check_tag(&1, at, tags, &2))

    unify(
      for({{access, :any}, operand} <- slots, typed = typed(access, operand, tags), do: typed),
      at,
      diagnostics
    )
  end

  # A literal in a dint slot must fit 32 bits, as a declared initial value must (M1-6: the
  # comparisons). An `:any` slot's literal is checked against the tag beside it, by unify/3.
  defp check_tag({{:value, :dint}, {:int_lit, line, value}}, {_, word}, _tags, diagnostics),
    do: literal(Declarations.fits?(:dint, value), value, {line, word}, diagnostics)

  # A preset is a dint number of milliseconds, and never negative (docs/naming.md, `ton`).
  defp check_tag({{:preset, _}, {:int_lit, line, value}}, {_, word}, _tags, diagnostics),
    do: preset(Declarations.preset?(value), value, {line, word}, diagnostics)

  defp check_tag({_slot, {:int_lit, _, _}}, _at, _tags, diagnostics), do: diagnostics

  # Reported by check_preset/4, and never looked up.
  defp check_tag({{:preset, _}, {:name, _, _}}, _at, _tags, diagnostics), do: diagnostics

  defp check_tag({slot, {:name, _, name} = operand}, at, tags, diagnostics),
    do: resolve(Declarations.reserved(name), lookup(name, tags), slot, operand, at, diagnostics)

  defp preset(true, _value, _at, diagnostics), do: diagnostics

  defp preset(false, value, {line, word}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a preset of 0 to 2147483647 ms, found `#{value}`")
      | diagnostics
    ]

  defp literal(true, _value, _at, diagnostics), do: diagnostics

  defp literal(false, value, {line, word}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` reads a dint: `#{value}` does not fit in 32 bits") | diagnostics
    ]

  # A name is a tag, or with `.` parts a member of an instance (M1-6), its part looked up
  # among the members its type lets a program name. A dotted name that is not a declared
  # member is a diagnostic, never a reach into another instance (docs/organisation.md
  # §4.7). An internal member, such as a ton's last-scanned time, is not there to find.
  defp lookup(name, tags), do: lookup_parts(String.split(name, "."), tags)

  defp lookup_parts([name], tags), do: Map.fetch(tags, name)
  defp lookup_parts([head | parts], tags), do: owned(Map.fetch(tags, head), head, parts)

  defp owned(:error, head, _parts), do: unowned(Declarations.reserved(head), head)

  defp owned({:ok, %Tag{type: %FbType{} = type} = tag}, _head, [part | deeper]),
    do: in_type(FbType.member(type, part), tag, part, deeper)

  defp owned({:ok, tag}, _head, [part | _]), do: {:no_members, tag, part}

  # A word that can never be declared is not reported as undeclared: `ton.dn`.
  defp unowned(nil, head), do: {:undeclared, head}
  defp unowned(reserved, head), do: {:reserved, reserved, head}

  defp in_type({:ok, member}, tag, _part, []), do: {:member, tag, member}
  defp in_type({:ok, member}, tag, _part, [next | _]), do: past(Integer.parse(next), tag, member)
  defp in_type(:error, tag, part, _deeper), do: {:unknown_member, tag, part}

  # `t1.acc.3` is bit access of a member, as `d.3` is of a tag.
  defp past({_bit, ""}, tag, member), do: {:member_bit, tag, member}
  defp past(_not_a_bit, tag, member), do: {:too_deep, tag, member}

  # take_operands/3 never takes a mnemonic, so a reserved operand is a section or type word.
  defp resolve(:type, _, _slot, {:name, line, name}, {_, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects a tag, found the type `#{name}`") | diagnostics]

  defp resolve(:section, _, _slot, {:name, line, name}, {_, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects a tag, found the keyword `#{name}`") | diagnostics]

  # The slot an undeclared name is first used in says how the note offers to declare it.
  defp resolve(nil, :error, slot, {:name, line, name}, _at, diagnostics),
    do: [{:undeclared, line, name, slot} | diagnostics]

  # A member of an undeclared name reports the name, once, however many members are used.
  defp resolve(nil, {:undeclared, head}, _slot, {:name, line, _}, _at, diagnostics),
    do: [{:undeclared, line, head, :member} | diagnostics]

  defp resolve(nil, {:reserved, reserved, head}, _slot, {:name, line, name}, _at, diagnostics) do
    message =
      "`#{name}` names a member of `#{head}`, but `#{head}` is #{reserved_as(reserved)}: " <>
        "only a timer has members"

    [diagnostic(line, message) | diagnostics]
  end

  # An instance is named whole only where an instruction runs it; anywhere else, by one of
  # its members, which the message suggests when one would fit the slot.
  defp resolve(nil, {:ok, %Tag{type: %FbType{name: type}}}, {:instance, type}, _, _, diagnostics),
    do: diagnostics

  defp resolve(
         nil,
         {:ok, %Tag{type: %FbType{} = type} = tag},
         {access, slot_type},
         {:name, line, _},
         {_, word},
         diagnostics
       ) do
    message =
      "`#{word}` #{verb(access)} #{a_type(slot_type)}, but `#{tag.name}` is a " <>
        "#{type.name}#{declared(tag)}" <> example(fitting(access, slot_type, type), tag)

    [diagnostic(line, message) | diagnostics]
  end

  defp resolve(nil, {:ok, tag}, {access, type}, {:name, line, _}, {_, word}, diagnostics),
    do:
      diagnostics
      |> check_type(access, type, tag, {line, word})
      |> check_access(access, tag, {line, word})

  defp resolve(nil, {:member, tag, member}, slot, {:name, line, name}, {_, word}, diagnostics),
    do:
      diagnostics
      |> check_member_type(slot, name, member, {line, word})
      |> check_member_write(slot, tag, name, member, {line, word})

  # Matched on the member's own name: on the whole name, every member of `t1` shares `t1.`,
  # and IEC's `t1.et` would come out nearest to `t1.tt`.
  defp resolve(nil, {:unknown_member, tag, part}, _slot, {:name, line, name}, _at, diagnostics) do
    names = Enum.map(FbType.public(tag.type), & &1.name)
    suggestion = Declarations.suggest(part, names, &"#{tag.name}.#{&1}", "members")

    message =
      "`#{name}` is not a member of `#{tag.name}`, a #{tag.type.name}" <>
        members(suggestion, names)

    [diagnostic(line, message) | diagnostics]
  end

  defp resolve(nil, {:no_members, tag, part}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, no_members(Integer.parse(part), name, tag)) | diagnostics]

  defp resolve(nil, {:member_bit, tag, member}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, bit(name, "#{tag.name}.#{member.name}", member.type)) | diagnostics]

  defp resolve(nil, {:too_deep, tag, member}, _slot, {:name, line, name}, _at, diagnostics) do
    message =
      "`#{name}` goes too deep: `#{tag.name}.#{member.name}` is a #{member.type}, " <>
        "which has no members"

    [diagnostic(line, message) | diagnostics]
  end

  defp members("", names), do: ": its members are " <> listed(Enum.map(names, &"`#{&1}`"))
  defp members(suggestion, _names), do: suggestion

  defp listed([one]), do: one
  defp listed(names), do: Enum.join(Enum.drop(names, -1), ", ") <> " and " <> List.last(names)

  defp reserved_as(:mnemonic), do: "an instruction"
  defp reserved_as(:type), do: "a type"
  defp reserved_as(:section), do: "a keyword"

  # `word.3` is PLAN.md §5's bit access, settled and not landed.
  defp no_members({_bit, ""}, name, tag), do: bit(name, tag.name, tag.type)

  defp no_members(_not_a_bit, name, tag),
    do:
      "`#{name}` names a member of `#{tag.name}`, but `#{tag.name}` is a #{tag.type}" <>
        "#{declared(tag)}: only a timer has members"

  defp bit(name, word, type),
    do: "`#{name}` names a bit of `#{word}`, a #{type}: bit access is not supported yet"

  # The member to suggest for an instance named whole: one of the slot's type that the slot
  # may use, a value the block sets for a read, one logic may write for a write.
  defp fitting(:write, slot_type, type), do: of_type(FbType.writable(type), slot_type)

  defp fitting(_access, slot_type, type),
    do: of_type(Enum.filter(FbType.public(type), &(&1.role == :output)), slot_type)

  defp of_type(members, :any), do: List.first(members)
  defp of_type(members, slot_type), do: Enum.find(members, &(&1.type == slot_type))

  defp example(nil, _tag), do: ""
  defp example(member, tag), do: ": name one of its members, as in `#{tag.name}.#{member.name}`"

  defp a_type(:any), do: "a value"
  defp a_type(type), do: "a #{type}"

  defp check_member_type(diagnostics, {_access, :any}, _name, _member, _at), do: diagnostics

  defp check_member_type(diagnostics, {_access, type}, _name, %Member{type: type}, _at),
    do: diagnostics

  defp check_member_type(diagnostics, {access, type}, name, member, {line, word}),
    do: [
      diagnostic(line, "`#{word}` #{verb(access)} a #{type}, but `#{name}` is a #{member.type}")
      | diagnostics
    ]

  # Decision 4: members are read anywhere, and logic writes only those its type allows.
  defp check_member_write(
         diagnostics,
         {:write, _},
         tag,
         name,
         %Member{write: false},
         {line, word}
       ) do
    writable = listed(Enum.map(FbType.writable(tag.type), &"`.#{&1.name}`"))

    message =
      "`#{word}` writes `#{name}`, but logic may write only #{writable} of a #{tag.type.name}"

    [diagnostic(line, message) | diagnostics]
  end

  defp check_member_write(diagnostics, _slot, _tag, _name, _member, _at), do: diagnostics

  defp check_type(diagnostics, _access, :any, _tag, _at), do: diagnostics
  defp check_type(diagnostics, _access, type, %Tag{type: type}, _at), do: diagnostics

  defp check_type(diagnostics, access, type, tag, {line, word}) do
    message =
      "`#{word}` #{verb(access)} a #{type}, but `#{tag.name}` is a #{tag.type}#{declared(tag)}"

    [diagnostic(line, message) | diagnostics]
  end

  defp verb(:write), do: "writes"
  defp verb(:instance), do: "runs"
  defp verb(_access), do: "reads"

  # IEC's rule for VAR_INPUT: "not modifiable within organization unit" (docs/naming.md).
  defp check_access(diagnostics, :write, %Tag{section: :var_input} = tag, {line, word}) do
    message =
      "`#{word}` writes `#{tag.name}`, a var_input#{declared(tag)}: logic must not write an input"

    [diagnostic(line, message) | diagnostics]
  end

  defp check_access(diagnostics, _access, _tag, _at), do: diagnostics

  defp declared(%Tag{line: nil}), do: ""
  defp declared(%Tag{line: line}), do: " (declared on line #{line})"

  defp typed(_access, {:int_lit, _, value}, _tags), do: {:literal, value}
  defp typed(access, {:name, _, name}, tags), do: typed_ref(access, lookup(name, tags))

  # A member stands in as a tag of its type. An instance named whole, and a member written
  # that logic may not write, were reported by resolve/6 and are not looked at again.
  defp typed_ref(_access, {:ok, %Tag{type: %FbType{}}}), do: nil
  defp typed_ref(_access, {:ok, %Tag{} = tag}), do: tag
  defp typed_ref(:write, {:member, _tag, %Member{write: false}}), do: nil

  defp typed_ref(_access, {:member, tag, member}),
    do: %Tag{name: "#{tag.name}.#{member.name}", type: member.type, section: :var}

  defp typed_ref(_access, _unresolved), do: nil

  # Every `:any` operand of one instruction has one type: two tags must agree, and a literal
  # must fit the tag it goes into. Anything else was reported already, or is not a tag.
  defp unify([%Tag{type: type}, %Tag{type: type}], _at, diagnostics), do: diagnostics

  defp unify([%Tag{} = a, %Tag{} = b], {line, word}, diagnostics) do
    message =
      "`#{word}` takes operands of one type: `#{a.name}` is a #{a.type}, `#{b.name}` is a #{b.type}"

    [diagnostic(line, message) | diagnostics]
  end

  defp unify([{:literal, value}, %Tag{type: type} = tag], at, diagnostics),
    do: fits(Declarations.fits?(type, value), value, tag, at, diagnostics)

  defp unify(_typed, _at, diagnostics), do: diagnostics

  defp fits(true, _value, _tag, _at, diagnostics), do: diagnostics

  defp fits(false, value, %Tag{type: :bool} = tag, {line, word}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` writes `#{value}` into `#{tag.name}`, a bool: only 0 or 1 fit")
      | diagnostics
    ]

  defp fits(false, value, %Tag{type: :dint} = tag, {line, word}, diagnostics) do
    message = "`#{word}` writes `#{value}` into `#{tag.name}`, a dint: it does not fit in 32 bits"
    [diagnostic(line, message) | diagnostics]
  end

  # An undeclared tag is reported once, at its first use, with the nearest declared name. A
  # program with no declaration line -- one written before M1-3 -- is told how to declare,
  # in its first report only.
  defp undeclared(found, tags, note?) do
    {diagnostics, _} = Enum.flat_map_reduce(found, {MapSet.new(), note?}, &report(&1, &2, tags))
    diagnostics
  end

  defp report({:undeclared, line, name, slot}, {seen, _} = acc, tags),
    do: first_use(MapSet.member?(seen, name), line, {name, slot}, tags, acc)

  defp report(%Diagnostic{} = diagnostic, acc, _tags), do: {[diagnostic], acc}

  defp first_use(true, _line, _name, _tags, acc), do: {[], acc}

  # A member of an undeclared name reports the name (M1-6), but is not told how to declare
  # it, since the name is likely an instance's and not a bool's or a dint's: the note waits
  # for the next undeclared name that is used whole. A name an instruction runs, as `ton`
  # runs a timer, is shown the one declaration that fits it.
  defp first_use(false, line, {name, slot}, tags, {seen, note?}) do
    message =
      "`#{name}` is not declared" <>
        Declarations.suggest(name, Map.keys(tags)) <> how(note?, slot, name)

    {[diagnostic(line, message)], {MapSet.put(seen, name), note? and slot == :member}}
  end

  defp how(false, _slot, _name), do: ""
  defp how(true, :member, _name), do: ""
  defp how(true, {:instance, type}, name), do: note("`var #{name} #{type}`")
  defp how(true, _slot, name), do: note("`var #{name} bool` or `var #{name} dint`")

  defp note(declaration),
    do:
      " (this program declares no tags: each is now declared before the first rung, " <>
        "as #{declaration})"

  # After a word that is not an instruction there is no signature to go by, so everything
  # up to the next instruction or branch group is taken to belong to it.
  defp skip_operands([{:int_lit, _, _} | rest]), do: skip_operands(rest)

  defp skip_operands([{:name, _, word} | rest] = elements),
    do: skip_name(mnemonic?(word), rest, elements)

  defp skip_operands(elements), do: elements

  defp skip_name(true, _rest, elements), do: elements
  defp skip_name(false, rest, _elements), do: skip_operands(rest)

  defp mnemonic?(word), do: Map.has_key?(@instructions, String.downcase(word))

  defp diagnostic(line, message), do: %Diagnostic{stage: :validate, line: line, message: message}
end
