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
  - `uses/2`: every tag operand, with what its slot does to it;
  - `writes/1`: which tags a program writes, and where;
  - `timers/1`: which timers a program runs, and at what preset.

  `writes/1` and `timers/1` know `cal`: a `cal` writes the instance it runs and each tag
  its block's var_outputs fill, as its slots say, and they reach into each block a `cal`
  runs, at any depth, naming what its body writes or runs by its path, `s1.t1`, as an
  access path does (§4.7). Each block type's body is read once a call, however many
  instances run it, so the walk is linear in the program's text and its instances. A
  `cal` of what its table holds as no user block's instance, which only a program built by
  hand can hold, has no slots and reaches nothing, as it runs nothing (`Logex.Runtime`).
  """

  alias Logex.{Compiler, FbType, Program, Tag}

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
  def uses(rungs, tags), do: Enum.flat_map(instructions(rungs), &used(&1, tags))

  defp used({symbol, line, operands} = instruction, tags),
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
  Which tags `program` writes: each to the lines of its writes, in rung order, one line a
  write, so a tag written twice on one line has that line twice. A tag is written by an
  operand in a `:write` slot, an `ons` storage bit and a tag a `cal`'s var_output fills
  among them, a member written counting as its instance's (`uses/2`), and by an
  `:instance` slot, whose instruction runs it: `ton t1` writes `t1`, `cal s1` writes `s1`.

  It reaches into each block a `cal` runs, at any depth: what the block's body writes is
  written too, by its path from the program, `s1.q` for the body's `q`, `s1.inner.q` a
  level down, with the lines of the body's writes, in the block's own text.
  """
  def writes(%Program{} = program), do: reach(program, &written/2)

  @doc """
  Which timers `program` runs: each timer a `ton` runs, to `{line, preset}`, the `ton`'s
  line and its preset in milliseconds, nil where the preset is no literal, which a program
  that compiles never has. A timer is run by one `ton` in a program that compiles; where
  several name it, the first in rung order is given. It reaches into each block a `cal`
  runs, as `writes/1` does: a timer the body runs is run too, by its path, `s1.t1`, at the
  line of the body's `ton`, in the block's own text, and its preset.
  """
  def timers(%Program{} = program), do: reach(program, &timed/2)

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
    |> Enum.flat_map(&used(&1, tags))
    |> Enum.reduce(%{}, fn
      {access, name, line, _symbol}, writes when access in [:write, :instance] ->
        Map.update(writes, name, [line], &[line | &1])

      _use, writes ->
        writes
    end)
    |> Map.new(fn {name, lines} -> {name, Enum.reverse(lines)} end)
  end

  defp timed(instructions, _tags),
    do: Enum.reduce(instructions, %{}, &ton/2)

  defp ton({symbol, line, [{:name, _, timer} | preset]}, timers) when symbol in [:ton, :ctu],
    do: Map.put_new(timers, timer, {line, preset_of(preset)})

  defp ton(_instruction, timers), do: timers

  defp preset_of([{:int_lit, _, preset}]), do: preset
  defp preset_of(_no_literal), do: nil
end
