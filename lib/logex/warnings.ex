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
    arithmetic instruction whose every source is a literal, `add 2 3 x` or `neg 5 x`;
  - a timer no `ton` runs (M1-6): it never times; since M3-1 any built-in instance no
    instruction of its type runs, in its type's words, a counter no `ctu` or `ctd` runs:
    it never counts;
  - an instance of a user function block no `cal` runs (M2-5): it never runs;
  - a label no `jmp` names (M3-5): nothing jumps to its rung.

  A write on a rung a jump may skip is still a write (decision 107): two `ote`s on one tag,
  one in a section a `jmp` skips and one outside it, are still two, the warning saying the
  last one in the scan decides it, which is the one that ran last. The maintainer
  confirmed it after M3-5's review, for sections that jump over each other too: the
  warnings read the program's text, not which rungs run.

  A tag declared from Elixir (`Logex.Tag.new!/4`) has no line and is never warned about.
  """

  alias Logex.{Diagnostic, FbType, Tag, Walk}

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
    owners =
      Map.new(Walk.storage_bits(rungs), fn {bit, line, symbol} -> {bit, {line, symbol}} end)

    tags
    |> Map.values()
    |> Enum.filter(& &1.line)
    |> Enum.flat_map(&about(&1, Map.get(accesses, &1.name, [])))
    |> Kernel.++(second_otes(instructions, tags, owners))
    |> Kernel.++(storage_writes(instructions, tags, owners))
    |> Kernel.++(Enum.flat_map(instructions, &constant/1))
    |> Kernel.++(unjumped(instructions))
    |> Enum.sort_by(& &1.line)
  end

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
  defp second_otes(instructions, tags, owners) do
    {warnings, _firsts} =
      instructions
      |> Enum.flat_map(&coil_target/1)
      |> Enum.filter(fn {name, instance, _line, _symbol} ->
        from_source?(tags, instance) and not Map.has_key?(owners, name)
      end)
      |> Enum.flat_map_reduce(%{}, fn {name, _instance, line, symbol}, firsts ->
        later_ote(Map.fetch(firsts, name), name, {line, symbol}, firsts)
      end)

    warnings
  end

  defp coil_target({:ote, line, [target]}), do: target(target, line, :ote)

  defp coil_target({symbol, line, [_storage, pulse]}) when symbol in [:osr, :osf],
    do: target(pulse, line, symbol)

  defp coil_target(_instruction), do: []

  defp target({:name, _, name}, line, symbol), do: [{name, name, line, symbol}]

  defp target({:member, _, [instance | _] = path}, line, symbol),
    do: [{Enum.join(path, "."), instance, line, symbol}]

  defp target(_literal, _line, _symbol), do: []

  defp later_ote(:error, name, first, firsts), do: {[], Map.put(firsts, name, first)}

  defp later_ote({:ok, first}, name, {line, _symbol}, firsts),
    do: {[second_ote(name, first, line)], firsts}

  # M1-6: every other write to an `ons` storage bit declared in source, before or after
  # the `ons` in the scan, is warned about at its own line, citing the `ons`. The uses are
  # walked in rung order, not grouped into a map, whose order stops being sorted past 32
  # keys. M3-4: so for every one-shot's storage bit (decision 80), every write but the
  # one-shot's own, its first operand, a coil's pulse bit among them.
  defp storage_writes(instructions, tags, owners) do
    for instruction <- instructions,
        {:write, name, line, symbol} <- others(instruction, Walk.uses_of(instruction, tags)),
        {:ok, first} <- [Map.fetch(owners, name)],
        from_source?(tags, name),
        do: storage_write(symbol, name, first, line)
  end

  @one_shots Walk.one_shots()

  defp others({symbol, _line, _operands}, [_storage | uses]) when symbol in @one_shots, do: uses
  defp others(_instruction, uses), do: uses

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

  defp constant({symbol, line, [{:int_lit, _, a}, {:int_lit, _, b}]})
       when symbol in @comparisons,
       do: [
         warning(
           line,
           "`#{symbol}` compares two literals, `#{a}` and `#{b}`: its result never changes"
         )
       ]

  # M3-3: an arithmetic instruction whose every source is a literal compiles, as IEC's
  # ADD(2, 3) does, but its result never changes.
  @arithmetic [:add, :sub, :mul, :div, :mod]

  defp constant({symbol, line, [{:int_lit, _, a}, {:int_lit, _, b}, _destination]})
       when symbol in @arithmetic,
       do: [
         warning(
           line,
           "`#{symbol}` reads two literals, `#{a}` and `#{b}`: its result never changes"
         )
       ]

  defp constant({symbol, line, [{:int_lit, _, a}, _destination]}) when symbol in [:neg, :abs],
    do: [warning(line, "`#{symbol}` reads a literal, `#{a}`: its result never changes")]

  defp constant(_instruction), do: []

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
