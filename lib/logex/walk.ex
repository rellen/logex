defmodule Logex.Walk do
  @moduledoc """
  The one walk of a program's IR (`PLAN.md` B5, M2-4; `docs/organisation.md` §4.10): what
  a compiled program's rungs do, read from the rungs alone, as public functions rather
  than a field of `%Logex.Program{}` that a program built by hand could get wrong.
  `Logex.Compiler`, `Logex.Warnings` and `Logex.Edit` read their instructions, uses,
  writes and timers here, and `Logex.Configuration.check/1` what each program type writes
  through its var_externals (M2-4), each instruction's slots through
  `Logex.Compiler.signature/2`, the one lookup (M2-5).

  - `instructions/1`: every instruction of a routine's rungs, in rung order;
  - `uses/2`: every tag operand, with what its slot does to it, and `uses_of/2` one
    instruction's;
  - `storage_bits/1`: each one-shot's storage bit, an `ons`'s, an `osr`'s or an `osf`'s
    (M3-4), and `one_shots/0`, the instructions that keep one;
  - `writes/1`: which tags a program writes, and where;
  - `member_writes/1`: which members of its instances it writes, and where (decision 96);
  - `presets/1`: which built-in instances a program runs, and at what preset (M3-1);
  - `timers/1`: which of them are timers;
  - `counters/1`: which of them are counters.

  `writes/1`, `member_writes/1`, `presets/1`, `timers/1` and `counters/1` know `cal`: a `cal` writes the instance it runs and each tag
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
  of `t1`, with its slot's access (M1-6), and a literal is no use. `tags` is the tag table
  of the routine that holds the rungs, each instance's type itself
  (`Logex.Program.typed_tags/1`), from which a `cal`'s slots are its block's.
  """
  def uses(rungs, tags), do: Enum.flat_map(instructions(rungs), &uses_of(&1, tags))

  @doc """
  The uses of one instruction, as `uses/2` gives them, in its operands' order: a
  one-shot's first is its storage bit's write (`one_shots/0`).
  """
  def uses_of({symbol, line, operands} = instruction, tags),
    do:
      for(
        {{access, _type}, operand} <- Enum.zip(Compiler.signature(instruction, tags), operands),
        name = tag_of(operand),
        do: {access, name, line, symbol}
      )

  defp tag_of({:name, _, name}), do: name
  defp tag_of({:member, _, [instance | _]}), do: instance
  defp tag_of({:int_lit, _, _}), do: nil

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
  Each one-shot of `rungs` whose storage bit is a tag, in rung order, as `{bit, line,
  symbol}`: the bit it names, and its instruction's line and symbol (`one_shots/0`). A
  one-shot on a member, which the compiler refuses, is none.
  """
  def storage_bits(rungs),
    do:
      for(
        {symbol, line, [{:name, _, bit} | _]} <- instructions(rungs),
        symbol in @one_shots,
        do: {bit, line, symbol}
      )

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

  defp calling(_instruction, _tags), do: []

  defp block(%Tag{type: %FbType{body: %Program{}} = type}, instance), do: [{instance, type}]
  defp block(_not_a_block, _instance), do: []

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

  # Each member an instruction's `:write` slots name, by its path, with the instruction's
  # line.
  defp member_operands({_symbol, line, operands} = instruction, tags),
    do:
      for(
        {{:write, _type}, {:member, _, path}} <-
          Enum.zip(Compiler.signature(instruction, tags), operands),
        do: {Enum.join(path, "."), line}
      )

  # The timers among the built-in instances a routine runs, those whose type keeps time,
  # and the counters.
  defp timed(instructions, tags), do: of_kind(instructions, tags, :timer)
  defp counted(instructions, tags), do: of_kind(instructions, tags, :counter)

  defp of_kind(instructions, tags, wanted),
    do:
      instructions
      |> preset_runs(tags)
      |> Map.filter(fn {name, _run} -> kind(Map.get(tags, name)) == wanted end)

  defp kind(%Tag{type: %FbType{} = type}), do: kind_of(FbType.rules(type))
  defp kind(_not_a_builtin), do: nil

  defp kind_of(%{kind: kind}), do: kind
  defp kind_of(nil), do: nil

  @runners FbType.runners()

  defp preset_runs(instructions, _tags), do: Enum.reduce(instructions, %{}, &run/2)

  defp run({symbol, line, [{:name, _, instance} | preset]}, runs) when symbol in @runners,
    do: Map.put_new(runs, instance, {line, preset_of(preset)})

  defp run(_instruction, runs), do: runs

  defp preset_of([{:int_lit, _, preset}]), do: preset
  defp preset_of(_no_literal), do: nil
end
