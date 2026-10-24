defmodule Logex.Walk do
  @moduledoc """
  The one walk of a program's IR (`PLAN.md` B5, M2-4; `docs/organisation.md` §4.10): what
  a compiled program's rungs do, read from the rungs alone, as public functions rather
  than a field of `%Logex.Program{}` that a program built by hand could get wrong.
  Since M5-11 an element, `temps[3]`, is a use and a write of its array, `temps`, as a bit
  is of its word, and is named by its subscripts' values, `temps[3]`, where a one-shot or a
  coil keeps it (`bit_name/1`, `storage_bits/1`) and in `bit_writes/1`, so that the
  warnings and an edit read an element as a bool or a bit is read. Since decision 221 a bit
  of an element, `faults[2].3`, is a use and a write of its array too, named so by
  `bit_name/1`, and `element_writes/1` gives each element a program writes, a write of a bit
  of one among them.

  `Logex.Compiler`, `Logex.Warnings` and `Logex.Edit` read their instructions, uses,
  writes and timers here, and `Logex.Configuration.check/1` what each program type writes
  through its var_externals (M2-4), each instruction's slots through
  `Logex.Compiler.signature/2`, the one lookup (M2-5).

  - `instructions/1`: every instruction of a routine's rungs, in rung order;
  - `uses/2`: every tag operand, with what its slot does to it, and `uses_of/2` one
    instruction's;
  - `storage_bits/1`: each one-shot's storage bit, an `ons`'s, an `osr`'s or an `osf`'s
    (M3-4), and `one_shots/0`, the instructions that keep one;
  - `one_shots/1`: which one-shots a program runs, at any depth (M3-4);
  - `writes/1`: which tags a program writes, and where;
  - `member_writes/1`: which members of its instances it writes, and where (decision 96);
  - `bit_writes/1` and `element_writes/1`: which bits of its tags, and which elements of
    its arrays, it writes, and where (M5-8, decision 221);
  - `presets/1`: which built-in instances a program runs, and at what preset (M3-1);
  - `timers/1`: which of them are timers;
  - `counters/1`: which of them are counters.

  `writes/1`, `member_writes/1`, `presets/1`, `timers/1`, `counters/1` and `one_shots/1` know `cal`: a `cal` writes the instance it runs and each tag
  its block's var_outputs fill, as its slots say, and they reach into each block a `cal`
  runs, at any depth, naming what its body writes or runs by its path, `s1.t1`, as an
  access path does (§4.7). Each block type's body is read once a call, however many
  instances run it, so the walk is linear in the program's text and its instances. A
  `cal` of what its table holds as no user block's instance, which only a program built by
  hand can hold, has no slots and reaches nothing, as it runs nothing (`Logex.Runtime`).
  """

  alias Logex.{Compiler, FbType, Program, Tag}

  @one_shots [:ons, :osr, :osf]

  @doc """
  Every instruction of `rungs`, in order: each rung's left to right, the legs of a group,
  however deeply nested, in turn, where they stand. Gathered newest first and reversed
  once, so it stays linear in the depth of nesting too.
  """
  def instructions(rungs) do
    rungs
    |> Enum.reduce([], fn {:rung, elements}, gathered -> gather(elements, gathered) end)
    |> Enum.reverse()
  end

  defp gather(elements, gathered), do: Enum.reduce(elements, gathered, &gathered/2)

  defp gathered({:branches, legs}, gathered), do: Enum.reduce(legs, gathered, &gather/2)
  defp gathered(instruction, gathered), do: [instruction | gathered]

  @doc """
  Each tag operand of each instruction of `rungs`, in order, as `{access, name, line,
  symbol}`: its slot's access (`:read`, `:write`, `:value` or `:instance`), the tag it
  names, and its instruction's line and symbol. A member is a use of its instance, `t1.dn`
  of `t1`, with its slot's access (M1-6), and a literal is no use, nor since M3-5 a label,
  `jmp done`'s, which names no tag. `tags` is the tag table
  of the routine that holds the rungs, each instance's type itself
  (`Logex.Program.typed_tags/1`), from which a `cal`'s slots are its block's.
  """
  def uses(rungs, tags), do: Enum.flat_map(instructions(rungs), &uses_of(&1, tags))

  @doc """
  The uses of one instruction, as `uses/2` gives them, in its operands' order: a
  one-shot's first is its storage bit's write (`one_shots/0`).
  """
  def uses_of({symbol, line, operands} = instruction, tags),
    do: used(Compiler.signature(instruction, tags), operands, {line, symbol})

  # Each slot with its operand, in order, as far as both go. Since M5-9 a bit whose number
  # a tag holds is two uses, its word's with its slot's access and its number's tag read
  # (decision 160).
  defp used([{access, _type} | slots], [operand | operands], at),
    do: use(tag_of(operand), access, at, used(slots, operands, at))

  defp used(_slots, _operands, _at), do: []

  defp use(nil, _access, _at, uses), do: uses

  defp use({:numbered, word, index}, access, {line, symbol}, uses),
    do: [{access, word, line, symbol}, {:read, index, line, symbol} | uses]

  # M5-12 (decision 152): an element a tag subscripts is a use of its array with its slot's
  # access, and of each subscript's tag read, in its subscripts' order, and a bit of one
  # whose number a tag holds of that tag after them.
  defp use({:subscripted, word, reads}, access, {line, symbol}, uses),
    do:
      [{access, word, line, symbol} | for(read <- reads, do: {:read, read, line, symbol})] ++ uses

  defp use(name, access, {line, symbol}, uses), do: [{access, name, line, symbol} | uses]

  defp tag_of({:name, _, name}), do: name
  defp tag_of({:member, _, [instance | _]}), do: instance
  # M5-8: a bit is a use of its container, `status.3` of `status`, with its slot's access,
  # so a coil on a bit is a write of the word (decision 155).
  defp tag_of({:bit, _, [container | _], _n, _mask, _name}), do: container
  # Decision 221: a bit of an element is a use of the element's array, as the element is.
  defp tag_of({:bit, _, {:element, _, array, _, _}, _n, _mask, _name}), do: array

  defp tag_of({:bit_at, _, [container | _], {:name, _, index}, _width, _name}),
    do: {:numbered, container, index}

  defp tag_of({:bit_at, _, {:element, _, array, _, _}, {:name, _, index}, _width, _name}),
    do: {:numbered, array, index}

  defp tag_of({:bit_at, _, {:element_at, _, array, at, _, _}, {:name, _, index}, _width, _name}),
    do: {:subscripted, array, subscript_tags(at) ++ [index]}

  # M5-11 (decision 151): an element is a use of its array, `temps[3]` of `temps`, with its
  # slot's access, as a bit is of its word, so a write of an element is a write of its
  # array in `writes/1`; the element itself is named by `bit_name/1`, `temps[3]`, where a
  # one-shot or a coil keeps it, and in `bit_writes/1`.
  defp tag_of({:element, _, array, _index, _name}), do: array

  defp tag_of({:element_at, _, array, index, _dims, _name}),
    do: {:subscripted, array, subscript_tags(index)}

  defp tag_of({:bit, _, {:element_at, _, array, index, _, _}, _n, _mask, _name}),
    do: {:subscripted, array, subscript_tags(index)}

  # M5-14 (decision 154): a member of an element of an array of instances is a use of the
  # array, `lane_t[2].dn` of `lane_t`, with its slot's access, as an element is, and one a
  # tag subscripts of each subscript's tag read too; a bit of one is a use of its member's,
  # and of its number's tag where a tag holds it.
  defp tag_of({:member, _, {:element, _, array, _index, _name}, _members}), do: array

  defp tag_of({:member, _, {:element_at, _, array, index, _dims, _name}, _members}),
    do: {:subscripted, array, subscript_tags(index)}

  defp tag_of({:bit, _, {:member, _, _, _} = member, _n, _mask, _name}), do: tag_of(member)

  defp tag_of({:bit_at, _, {:member, _, _, _} = member, {:name, _, index}, _width, _name}),
    do: numbered_in(tag_of(member), index)

  defp tag_of({:int_lit, _, _}), do: nil
  defp tag_of({:int_lit, _, _, _spelling}), do: nil
  # M5-10: a real literal, plain or spelled, is no tag either.
  defp tag_of({:real_lit, _, _}), do: nil
  defp tag_of({:real_lit, _, _, _spelling}), do: nil
  # M3-5: a label is a name of the routine's own, never a tag (decision 105).
  defp tag_of({:label, _, _}), do: nil

  defp subscript_tags(index), do: for({:name, _, name} <- index, do: name)

  defp numbered_in({:subscripted, array, reads}, index),
    do: {:subscripted, array, reads ++ [index]}

  defp numbered_in(array, index), do: {:numbered, array, index}

  @doc """
  The instructions that keep an edge in a storage bit, a bool of the routine they stand in,
  each naming it as its first operand: `ons`, the one-shot on the rung condition (M1-6),
  and the pulse coils `osr` and `osf` (M3-4), whose second operand is the pulse bit. A
  storage bit is under one rule whichever of the three keeps it: one one-shot to a bit
  (`Logex.Compiler`), any other write a warning (`Logex.Warnings`), and on an online
  edit's block list by name (`Logex.Edit`, decisions 21 and 80).
  """
  def one_shots, do: @one_shots

  @doc """
  The name of a bool an operand names, as a storage bit, a pulse bit or a coil's target is
  named: a tag's own, `edge`, and since M5-8 a bit's path, `status.3` or `t1.pre.3`
  (decision 155); any other operand is itself, equal to no name.
  """
  def bit_name({:name, _, name}), do: name

  # Decision 221: a bit of an element by its element's name and its number, `faults[2].3`.
  def bit_name({:bit, _, {:element, _, _, _, _} = element, n, _mask, _name}),
    do: bit_name(element) <> "." <> Integer.to_string(n)

  # M5-12 (decision 154): a bit of an element a tag subscripts, `w[i].3`, names no one bit,
  # since the element moves as the tag does: it is itself, as the element `w[i]` is.
  def bit_name({:bit, _, {:element_at, _, _, _, _, _}, _n, _mask, _name} = bit), do: bit

  def bit_name({:bit, _, path, n, _mask, _name}),
    do: Enum.join(path, ".") <> "." <> Integer.to_string(n)

  # M5-11 (decision 154): an element by its array and its subscripts' values, `edge[2]`, as
  # a bit is named by its number's.
  def bit_name({:element, _, array, index, _name}), do: Logex.Array.name(array, index)

  def bit_name(operand), do: operand

  @doc """
  Each one-shot of `rungs` whose storage bit is a tag, in rung order, as `{bit, line,
  symbol}`: the bit it names, and its instruction's line and symbol (`one_shots/0`). A
  one-shot on a member, which the compiler refuses, is none. Since M5-8 a storage bit may
  be a bit of a tag, named by its path, `status.3` (decision 155).
  """
  def storage_bits(rungs), do: bits_of(instructions(rungs))

  defp bits_of(instructions),
    do:
      for(
        {symbol, line, [storage | _]} <- instructions,
        symbol in @one_shots,
        bit = own_bit(storage),
        do: {bit, line, symbol}
      )

  defp own_bit({:name, _, bit}), do: bit
  defp own_bit({:bit, _, [_container], _n, _mask, _name} = bit), do: bit_name(bit)
  defp own_bit({:bit, _, {:element, _, _, _, _}, _n, _mask, _name} = bit), do: bit_name(bit)
  defp own_bit({:element, _, _array, _index, _name} = element), do: bit_name(element)
  defp own_bit(_member), do: nil

  @doc """
  Which tags `program` writes: each to the lines of its writes, in rung order, one line a
  write, so a tag written twice on one line has that line twice. A tag is written by an
  operand in a `:write` slot, a one-shot's storage bit, a pulse coil's pulse bit and a tag
  a `cal`'s var_output fills among them, a member written counting as its instance's (`uses/2`), and by an
  `:instance` slot, whose instruction runs it: `ton t1` writes `t1`, `cal s1` writes `s1`.

  It reaches into each block a `cal` runs, at any depth: what the block's body writes is
  written too, by its path from the program, `s1.q` for the body's `q`, `s1.inner.q` a
  level down, with the lines of the body's writes, in the block's own text.
  """
  def writes(%Program{} = program), do: reach(program, &written/2)

  @doc """
  Which members of its instances `program` writes (decision 96): each member an operand in
  a `:write` slot names, by its path, `lube.r` for `ote lube.r`, to the lines of its writes,
  in rung order, one line a write, as `writes/1` gives a tag's, where `writes/1` counts the
  write as its instance's. The compiler lets logic write a member only where its type does
  (`Logex.FbType`), so each is a built-in's: a counter's `r`, `ld` or `pv`, an `rto`'s `r`,
  or a timer's `.pre` or `.acc`. A `cal`'s var_output filling a member writes it too.

  It reaches into each block a `cal` runs, at any depth, as `writes/1` does: a member the
  body writes is written by its path from the program, `s1.c.r` for the body's `c.r`.
  `Logex.Edit` reads it, for a member input an edit leaves unwritten.
  """
  def member_writes(%Program{} = program), do: reach(program, &members_written/2)

  @doc """
  Which bits of its tags `program` writes (M5-8, decision 155): each bit an operand in a
  `:write` slot names, by its path, `status.3`, to the lines of its writes, in rung order,
  one line a write, where `writes/1` counts the write as its word's, `status`. It reaches
  into each block a `cal` runs, as `writes/1` does, `s1.status.3` for the body's
  `status.3`. `Logex.Edit` reads it, for a storage bit of a word written by its one-shot
  alone.
  """
  def bit_writes(%Program{} = program), do: reach(program, &bits_written/2)

  @doc """
  Which elements of its arrays `program` writes (decision 221): each element an operand in
  a `:write` slot names, by its subscripts' values, `g[1]`, a bit of one, `g[1].3` or
  `g[1].[n]`, a write of its element, to the lines of its writes, in rung order, as
  `bit_writes/1` gives a bit's. `Logex.Configuration.check/1` reads it, for the writers of
  a global array element by element (decision 48).
  """
  def element_writes(%Program{} = program), do: reach(program, &elements_written/2)

  @doc """
  Which timers `program` runs: each timer a `ton` runs, or since M3-2 a `tof`, a `tp` or an `rto`, to
  `{line, preset}`, the instruction's line and its preset in milliseconds, nil where the preset is no literal, which a program
  that compiles never has. A timer is run by one `ton` in a program that compiles; where
  several name it, the first in rung order is given. It reaches into each block a `cal`
  runs, as `writes/1` does: a timer the body runs is run too, by its path, `s1.t1`, at the
  line of the body's `ton`, in the block's own text, and its preset.
  """
  def timers(%Program{} = program), do: reach(program, &timed/2)

  @doc """
  Which built-in instances `program` runs (M3-1): each instance an instruction that runs a
  built-in type runs (`Logex.FbType.rules/1`), a timer a `ton` runs among them, to
  `{line, preset}`, as `timers/1` gives a timer's: the first such instruction in rung order,
  its line and its preset, nil where it is no literal. It reaches into each block a `cal`
  runs, as `timers/1` does. `Logex.Edit` reads it, whose preset rules are every built-in's,
  and `timers/1` is the part of it that keeps time, which M2-6's event-task warning reads.
  """
  def presets(%Program{} = program), do: reach(program, &preset_runs/2)

  @doc """
  Which counters `program` runs (M3-1): the part of `presets/1` whose type is a counter
  (`Logex.FbType.rules/1`), each to `{line, preset}`, the first `ctu` or `ctd` that runs
  it, a block's by its path. `Logex.Configuration.check/1`'s event-task warning reads it
  (decision 72).
  """
  def counters(%Program{} = program), do: reach(program, &counted/2)

  @doc """
  Which one-shots `program` runs (M3-4): each storage bit `storage_bits/1` gives, to
  `{line, symbol}`, its instruction's line and symbol, `:ons`, `:osr` or `:osf`. A storage
  bit has one one-shot in a program that compiles; where several name it, the first in
  rung order is given. It reaches into each block a `cal` runs, as `timers/1` does: a
  one-shot the body runs is run too, by its storage bit's path, `s1.edge`, at the line of
  the body's instruction, in the block's own text. `Logex.Configuration.check/1`'s
  event-task warning reads it beside `timers/1` and `counters/1`.
  """
  def one_shots(%Program{} = program), do: reach(program, &oned/2)

  # A routine's own facts, `own.(instructions, tags)`, a map of names to a list of lines
  # (writes) or a first run (timers); then, from the top down, each block its `cal`s run,
  # at any depth, its body's own facts by their paths. Each block type's own facts and
  # `cal`s are read once a call, by its name, and each path holds its body's fact as it is,
  # so the walk is linear in the text and in the paths it gives.
  defp reach(%Program{rungs: rungs} = program, own) do
    {facts, cals} = routine(rungs, Program.typed_tags(program), own)

    {facts, _memo} =
      Enum.reduce(cals, {facts, %{}}, fn {instance, type}, acc ->
        descend(type, instance, own, acc)
      end)

    facts
  end

  defp routine(rungs, tags, own) do
    instructions = instructions(rungs)
    {own.(instructions, tags), Enum.flat_map(instructions, &calling(&1, tags))}
  end

  # The instances a routine's `cal`s run, each with its type: a `cal` of what its table
  # holds as no user block's instance reaches nothing.
  defp calling({:cal, _line, [{:name, _, instance} | _]}, tags),
    do: block(Map.get(tags, instance), instance)

  # M5-14 (decision 154): a `cal` of an element of an array of instances runs that element,
  # by its path, `lanes[2]`.
  defp calling({:cal, _line, [{:element, _, array, _index, name} | _]}, tags),
    do: block(element_tag(Map.get(tags, array)), name)

  defp calling(_instruction, _tags), do: []

  defp block(%Tag{type: %FbType{body: %Program{}} = type}, instance), do: [{instance, type}]
  defp block(_not_a_block, _instance), do: []

  # An element of an array of instances as a tag of its elements' type, or nil.
  defp element_tag(%Tag{type: {:array, %FbType{} = type, _dims}} = tag), do: %{tag | type: type}
  defp element_tag(_no_array), do: nil

  defp descend(%FbType{name: name} = type, path, own, {facts, memo}) do
    {{inner, cals}, memo} = own_facts(Map.fetch(memo, name), type, own, memo)

    facts =
      Enum.reduce(inner, facts, fn {at, fact}, facts ->
        Map.put(facts, path <> "." <> at, fact)
      end)

    Enum.reduce(cals, {facts, memo}, fn {instance, type}, acc ->
      descend(type, path <> "." <> instance, own, acc)
    end)
  end

  defp own_facts({:ok, known}, _type, _own, memo), do: {known, memo}

  defp own_facts(:error, %FbType{name: name, body: body}, own, memo) do
    known = routine(body.rungs, Program.typed_tags(body), own)
    {known, Map.put(memo, name, known)}
  end

  defp written(instructions, tags) do
    instructions
    |> Enum.flat_map(&uses_of(&1, tags))
    |> Enum.reduce(%{}, fn
      {access, name, line, _symbol}, writes when access in [:write, :instance] ->
        Map.update(writes, name, [line], &[line | &1])

      _use, writes ->
        writes
    end)
    |> Map.new(fn {name, lines} -> {name, Enum.reverse(lines)} end)
  end

  defp members_written(instructions, tags) do
    instructions
    |> Enum.flat_map(&member_operands(&1, tags))
    |> Enum.reduce(%{}, fn {path, line}, writes ->
      Map.update(writes, path, [line], &[line | &1])
    end)
    |> Map.new(fn {path, lines} -> {path, Enum.reverse(lines)} end)
  end

  defp bits_written(instructions, tags) do
    instructions
    |> Enum.flat_map(fn {_symbol, line, operands} = instruction ->
      for {{:write, _type}, bit} <- Enum.zip(Compiler.signature(instruction, tags), operands),
          own_bit?(bit),
          do: {bit_name(bit), line}
    end)
    |> Enum.reduce(%{}, fn {path, line}, writes ->
      Map.update(writes, path, [line], &[line | &1])
    end)
    |> Map.new(fn {path, lines} -> {path, Enum.reverse(lines)} end)
  end

  defp elements_written(instructions, tags) do
    instructions
    |> Enum.flat_map(fn {_symbol, line, operands} = instruction ->
      for {{:write, _type}, operand} <- Enum.zip(Compiler.signature(instruction, tags), operands),
          element = element_of(operand),
          do: {element_name(element), line}
    end)
    |> Enum.reduce(%{}, fn {path, line}, writes ->
      Map.update(writes, path, [line], &[line | &1])
    end)
    |> Map.new(fn {path, lines} -> {path, Enum.reverse(lines)} end)
  end

  # M5-14: a write of a member of an element is a write of the element.
  defp element_of({:member, _, element, _members}), do: element
  defp element_of({:bit, _, {:member, _, element, _}, _, _, _}), do: element
  defp element_of({:bit_at, _, {:member, _, element, _}, _, _, _}), do: element
  defp element_of({:element, _, _, _, _} = element), do: element
  defp element_of({:bit, _, {:element, _, _, _, _} = element, _, _, _}), do: element
  defp element_of({:bit_at, _, {:element, _, _, _, _} = element, _, _, _}), do: element
  # M5-12 (§4.12's routine choice): a write through a tag subscript is a write of the whole
  # array, named by the array's name, since it may write any of its elements.
  defp element_of({:element_at, _, _, _, _, _} = element), do: element
  defp element_of({:bit, _, {:element_at, _, _, _, _, _} = element, _, _, _}), do: element
  defp element_of({:bit_at, _, {:element_at, _, _, _, _, _} = element, _, _, _}), do: element
  defp element_of(_other), do: nil

  defp element_name({:element_at, _, array, _index, _dims, _name}), do: array
  defp element_name(element), do: bit_name(element)

  defp own_bit?({:bit, _, [_], _, _, _}), do: true
  defp own_bit?({:bit, _, {:element, _, _, _, _}, _, _, _}), do: true
  defp own_bit?({:element, _, _, _, _}), do: true
  defp own_bit?(_other), do: false

  # Each member an instruction's `:write` slots name, by its path, with the instruction's
  # line.
  defp member_operands({_symbol, line, operands} = instruction, tags),
    do:
      for(
        {{:write, _type}, operand} <- Enum.zip(Compiler.signature(instruction, tags), operands),
        path <- member_paths(operand),
        do: {path, line}
      )

  # M5-14 (decision 154): a member of an element of an array of instances by the element's
  # path, `lane_c[1].pv`, and one a tag subscripts, which may write that member of any
  # element, as that member of each element, `lane_c[0].pv` to `lane_c[3].pv`
  # (provisional); a bit of one is a write of its member.
  defp member_paths({:member, _, {:element, _, array, index, _name}, members}),
    do: [Enum.join([Logex.Array.name(array, index) | members], ".")]

  defp member_paths({:member, _, {:element_at, _, array, _index, dims, _name}, members}),
    do:
      for(
        index <- Logex.Array.indexes(dims),
        do: Enum.join([Logex.Array.name(array, index) | members], ".")
      )

  defp member_paths({:bit, _, {:member, _, _, _} = member, _n, _mask, _name}),
    do: member_paths(member)

  defp member_paths({:bit_at, _, {:member, _, _, _} = member, _index, _width, _name}),
    do: member_paths(member)

  # A member's path, `lube.r`, and since M5-8 a bit of one, a write of its member, `t1.pre`
  # for `t1.pre.3`; a tag or a tag's bit is none.
  defp member_paths({:member, _, path}), do: [Enum.join(path, ".")]
  defp member_paths({:bit, _, [_, _ | _] = path, _n, _mask, _name}), do: [Enum.join(path, ".")]

  defp member_paths({:bit_at, _, [_, _ | _] = path, _index, _width, _name}),
    do: [Enum.join(path, ".")]

  defp member_paths(_tag), do: []

  # A routine's one-shots, each storage bit to its first one-shot's line and symbol.
  defp oned(instructions, _tags),
    do:
      Enum.reduce(bits_of(instructions), %{}, fn {bit, line, symbol}, oned ->
        Map.put_new(oned, bit, {line, symbol})
      end)

  # The timers among the built-in instances a routine runs, those whose type keeps time,
  # and the counters.
  defp timed(instructions, tags), do: of_kind(instructions, tags, :timer)
  defp counted(instructions, tags), do: of_kind(instructions, tags, :counter)

  defp of_kind(instructions, tags, wanted),
    do:
      instructions
      |> preset_runs(tags)
      |> Map.filter(fn {name, _run} -> kind(instance(tags, name)) == wanted end)

  # An instance's tag by the name it is run by, a tag's or since M5-14 an element's,
  # `lane_t[2]`, its array's elements' type.
  defp instance(tags, name) when binary_part(name, byte_size(name) - 1, 1) == "]",
    do: element_tag(Map.get(tags, elem(Logex.Array.split(name), 0)))

  defp instance(tags, name), do: Map.get(tags, name)

  defp kind(%Tag{type: %FbType{} = type}), do: kind_of(FbType.rules(type))
  defp kind(_not_a_builtin), do: nil

  defp kind_of(%{kind: kind}), do: kind
  defp kind_of(nil), do: nil

  @runners FbType.runners()

  defp preset_runs(instructions, _tags), do: Enum.reduce(instructions, %{}, &run/2)

  defp run({symbol, line, [{:name, _, instance} | preset]}, runs) when symbol in @runners,
    do: Map.put_new(runs, instance, {line, preset_of(preset)})

  # M5-14 (decision 154): an element of an array of instances, run by its path, `lane_t[2]`.
  defp run({symbol, line, [{:element, _, _array, _index, instance} | preset]}, runs)
       when symbol in @runners,
       do: Map.put_new(runs, instance, {line, preset_of(preset)})

  defp run(_instruction, runs), do: runs

  defp preset_of([{:int_lit, _, preset}]), do: preset
  defp preset_of([{:int_lit, _, preset, _spelling}]), do: preset
  defp preset_of(_no_literal), do: nil
end
