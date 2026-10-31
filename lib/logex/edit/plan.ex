defmodule Logex.Edit.Plan do
  @moduledoc false
  # The per-instance half of an online edit (fix F5, docs/organisation.md §4.9): what each
  # program declares and drives, read once into a plan per direction, and a switch and a
  # prune that each read and write only one instance's state and the edit's record of it.
  # Logex.Edit, the edit of a lone instance, calls them; its moduledoc gives every rule
  # they apply. Internal: nothing here checks its arguments, which its callers have.

  alias Logex.{Declarations, Diagnostic, FbType, Instance, Program, Tag, Walk}
  alias Logex.FbType.Member
  import Logex.Declarations, only: [is_elementary: 1]
  import Logex.Array, only: [is_array: 1, is_instances: 1]

  # M5-14: a key that names an element, `lane_t[2]`, by its last byte.
  defguardp is_element_key(key)
            when is_binary(key) and byte_size(key) > 0 and
                   binary_part(key, byte_size(key) - 1, 1) == "]"

  # The edit's record of one instance (F5): `shown`, the value each held output's point
  # holds, as the edit has learnt it (F4); `pre`, for each timer, the `.pre` the last
  # switch left and the one it found (F1), and the `last` it found where it resumed the
  # timer, nil otherwise (F11), `{left, found, last}`; and `scanned`, nil until the edit's
  # first switch, then `{side, pending}`: which of its two programs, `:original` or
  # `:candidate`, left the storage bits, and the bits still blocked against it from an
  # earlier edit (F2, F3).
  @record %{shown: %{}, pre: %{}, scanned: nil}

  # M5-14's review: the mark of an array of instances opened for a switch or a prune.
  @opened :"Logex.Edit.Plan.opened"

  # The instructions that run a built-in instance (Logex.FbType.rules/1, M3-1).
  @runners FbType.runners()
  @one_shots Walk.one_shots()
  # M5-10: the reals, whose initial values start at their nearest values.
  @reals Declarations.reals()

  @doc false
  # The record an edit starts with, of each instance it moves.
  def record, do: @record

  # ---- accept: the two programs alone -----------------------------------------------------

  # §4.9: a tag's type, a function block's members included, changes only with a restart.
  # In line order, a tag declared from Elixir (line nil, after every number) last, by name,
  # and several members of one instance, on its one line, by path.
  # M2-5: an instance of a user block keeps its type while the block keeps its name and
  # every member both versions declare keeps its kind, at any depth: the block's body, and a
  # member it adds or drops, change with an edit, the state moving by member name (the
  # nested migration, §4.9; decision 31). A member whose kind changes is cited by its path,
  # at the line of the instance that holds it. Each is cited in the candidate's file, where
  # it has one (fix F15). Each program's tags are read with each instance's type itself, as
  # a block's compiled body, which runs as a program too, names the types it holds.
  def retyped(%Program{} = original, %Program{file: file} = edited) do
    running = Program.typed_tags(original)
    candidate = Program.typed_tags(edited)

    retyped =
      for {name, %Tag{type: type, line: line}} <- candidate,
          {:ok, %Tag{type: was}} <- [Map.fetch(running, name)],
          {path, from, to} <- changes(was, type, name),
          do: {{line, name, path}, retyped(path, {file, line}, from, to)}

    for {_at, diagnostic} <- Enum.sort_by(retyped, &elem(&1, 0)), do: diagnostic
  end

  defp changes(same, same, _path), do: []

  defp changes(
         %FbType{name: name, body: %Program{}} = was,
         %FbType{name: name, body: %Program{}} = type,
         path
       ) do
    before = by_name(was)

    for %Member{name: member} = to <- type.members,
        {:ok, from} <- [Map.fetch(before, member)],
        change <-
          changes(FbType.type_of(was, from), FbType.type_of(type, to), below(path, member)),
        do: change
  end

  # M5-14 (decision 154): an array of instances of a user block keeps its type where its
  # sizes stay and its block keeps its name and every member's kind. Since decision 254
  # each change of its elements is cited once, for the array, `{:every, "ws", "x"}`,
  # since decision 259 "`ws[*].x`", where until then it was cited by its first element's
  # path, `ws[0].x`.
  defp changes(
         {:array, %FbType{name: name, body: %Program{}} = was, dims},
         {:array, %FbType{name: name, body: %Program{}} = type, dims},
         path
       ),
       do:
         for({member, from, to} <- changes(was, type, ""), do: {{:every, path, member}, from, to})

  defp changes(was, type, path), do: [{path, was, type}]

  # A member's path below an instance's, or an element's own member, by its name alone.
  defp below("", member), do: member
  defp below(path, member), do: path <> "." <> member

  # A version's members by name, built once per type compared, so that matching the
  # members of two versions is linear in them, not quadratic.
  defp by_name(nil), do: %{}
  defp by_name(%FbType{members: members}), do: Map.new(members, &{&1.name, &1})
  defp by_name(members) when is_list(members), do: Map.new(members, &{&1.name, &1})

  # M5-14 (decision 154): a block's members with each array of instances it holds, a
  # block's own `var`, given as its elements, each a member of its own by its path,
  # `t[1]`, of its array's elements' type and with its own preset, so that every rule of a
  # member holding an instance is an element's; any other member as it is.
  defp expanded(nil), do: nil

  defp expanded(%FbType{members: members} = type),
    do: Enum.flat_map(members, &element_members(&1, FbType.type_of(type, &1)))

  defp element_members(
         %Member{name: name, initial: initial} = member,
         {:array, %FbType{} = type, dims}
       ),
       do:
         for(
           index <- Logex.Array.indexes(dims),
           do: %{
             member
             | name: Logex.Array.name(name, index),
               type: type,
               initial: Map.get(initial || %{}, index, %{})
           }
         )

  defp element_members(member, _type), do: [member]

  defp retyped(path, {file, line}, was, type),
    do: %Diagnostic{
      stage: :edit,
      file: file,
      line: line,
      message:
        "#{cited(path)} is #{word(was)} in the running program and #{word(type)} in the " <>
          "candidate#{every(path)}: #{whose(path)} type changes only with a restart"
    }

  # Decision 254: a member of every element of an array of user blocks, cited once for the
  # array; since decision 259 by one path, each array's subscripts `[*]`, `ws[*].x`, and
  # one of every element of an array its elements hold `hs[*].ws[*].x`, ", in every
  # element", where decision 254 cited "`x` of every element of `ws` of every element of
  # `hs`".
  defp cited(path), do: "`#{starred(path)}`"

  defp starred({:every, array, member}), do: "#{array}[*].#{starred(member)}"
  defp starred(path), do: path

  defp every({:every, _array, _member}), do: ", in every element"
  defp every(_path), do: ""

  defp whose({:every, _array, _member}), do: "a member's"
  defp whose(path), do: whose_path(String.contains?(path, "."))

  defp whose_path(false), do: "a tag's"
  defp whose_path(true), do: "a member's"

  # A user block's name is any name, so it takes no article of its own (M2-5).
  defp word(%FbType{} = type), do: Declarations.instance_of(type)
  defp word(type), do: Declarations.a_type(type)

  # The per-program half (F5): what each program declares and drives, read once, and a
  # plan for each direction. A switch then reads and writes only the state and the record,
  # so nothing a plan holds can go stale. Sets are maps to `true`, for `is_map_key/2`.
  #
  # OE-2: `externals` says what a program's var_externals are. For a lone instance,
  # `:tags`, each is a tag of its own at 0 (Logex.Runtime), which the start rules start as
  # any tag. In a resource, `:globals`, each is its global, the one copy, which the
  # configuration edit merges into the state around the switch and splits off after
  # (decision 45): no start rule starts one, and none is reported as a changed initial
  # value, since its value is the global's.
  def plans(original, candidate), do: plans(original, candidate, :tags)

  def plans(original, candidate, externals) do
    o = facts(original, externals)
    c = facts(candidate, externals)
    forward = held(o, c)
    back = held(c, o)
    watched = Map.new(forward ++ back, &{&1, true})
    {marked, unmarked} = requalified(o, c)

    %{
      test: Map.put(plan({:original, o}, c, forward, watched), :requalified, marked),
      untest: Map.put(plan({:candidate, c}, o, back, watched), :requalified, unmarked)
    }
  end

  # M6-7 (decisions 278 and 302): each path whose retention the edit changes, a kept path
  # retained by one program and not by the other, by decision 270's nearest mark as each
  # program's `retained` settles it (Logex.Program.retained/2), so that `non_retain` and no
  # qualifier are one and a mark moved between an instance and its members reports only the
  # paths whose retention it changes. Each program's leaves are read from its tags, a user
  # block's instance member by member at any depth and an array of them by `[*]`, as
  # `retained` names them: a tag, an array of an elementary type and a built-in instance
  # are each one leaf, kept whole. A leaf both programs declare whose retention differs is
  # in the change, one either alone declares is not, `:added` and `:pruned` its reports;
  # and the change is named as `retained` names a path, a node whole where every leaf of
  # either program under it is in it, `s1` for every member of `s1`, and otherwise each
  # node below that is, `s1.count`, `gates[*].count` for that member of every element
  # (decision 310's form). `{test, untest}`: the second the first's kinds swapped. A pair of
  # programs that retain nothing pays one clause.
  defp requalified(%{retained: nil}, %{retained: nil}), do: {[], []}

  defp requalified(from, to) do
    was = leaves(from)
    now = leaves(to)
    union = Map.keys(Map.merge(was, now))
    {added, removed} = Enum.reduce(now, {%{}, %{}}, &moved_mark(&1, was, &2))
    added = collapsed(union, added)
    removed = collapsed(union, removed)

    {marks(:retain_added, added) ++ marks(:retain_removed, removed),
     marks(:retain_removed, added) ++ marks(:retain_added, removed)}
  end

  defp moved_mark({leaf, kept?}, was, acc), do: mark_moved(Map.fetch(was, leaf), leaf, kept?, acc)

  defp mark_moved({:ok, kept?}, _leaf, kept?, acc), do: acc

  defp mark_moved({:ok, false}, leaf, true, {added, removed}),
    do: {Map.put(added, leaf, true), removed}

  defp mark_moved({:ok, true}, leaf, false, {added, removed}),
    do: {added, Map.put(removed, leaf, true)}

  defp mark_moved(:error, _leaf, _kept?, acc), do: acc

  # Each leaf of a program's state, as a list of its path's segments, `["gates", "[*]",
  # "count"]`, to whether the program retains it: whether `retained` names it or a node on
  # its way. A var_external that is a global holds no state of the instance (OE-2).
  defp leaves(%{tags: tags, shared: shared, retained: retained}) do
    marked = Map.new(retained || [], &{segments(&1), true})

    for {name, %Tag{type: type}} <- tags,
        not is_map_key(shared, name),
        leaf <- leaves_of([name], type),
        into: %{},
        do: {leaf, covered?(leaf, [], marked)}
  end

  defp leaves_of(path, %FbType{body: %Program{}, members: members} = type),
    do: Enum.flat_map(members, &leaves_of(path ++ [&1.name], FbType.type_of(type, &1)))

  defp leaves_of(path, {:array, %FbType{body: %Program{}} = type, _dims}),
    do: leaves_of(path ++ ["[*]"], type)

  defp leaves_of(path, _whole), do: [path]

  defp covered?([], _seen, _marked), do: false

  defp covered?([segment | rest], seen, marked) do
    path = seen ++ [segment]
    is_map_key(marked, path) or covered?(rest, path, marked)
  end

  defp segments(path),
    do: Enum.flat_map(String.split(path, "."), &segment(String.split(&1, "[*]")))

  defp segment([name, ""]), do: [name, "[*]"]
  defp segment([name]), do: [name]

  defp joined([first | rest]), do: Enum.reduce(rest, first, &join_segment/2)

  defp join_segment("[*]", path), do: path <> "[*]"
  defp join_segment(segment, path), do: path <> "." <> segment

  defp collapsed(_union, change) when map_size(change) == 0, do: []
  defp collapsed(union, change), do: nodes(union, [], change)

  defp nodes(leaves, prefix, change),
    do:
      Enum.flat_map(Enum.group_by(leaves, &hd/1, &tl/1), fn {segment, rests} ->
        node(prefix ++ [segment], rests, change)
      end)

  defp node(path, rests, change),
    do: node(Enum.all?(rests, &is_map_key(change, path ++ &1)), path, rests, change)

  defp node(true, path, _rests, _change), do: [path]
  defp node(false, path, rests, change), do: nodes(Enum.reject(rests, &(&1 == [])), path, change)

  defp marks(kind, paths), do: for(path <- paths, do: {kind, joined(path), path})

  # A program's tags with each instance's type itself (Logex.Program.typed_tags/1), as
  # every walk below reads them: a block's compiled body, which runs as a program too,
  # names each type it holds.
  defp facts(%Program{rungs: rungs} = program, externals) do
    tags = Program.typed_tags(program)
    {ons, called, bodies} = rungs(rungs, tags)
    presets = Walk.presets(program)

    %{
      tags: tags,
      table: program.blocks,
      initial: Program.initial_env(program),
      inputs: section(tags, :var_input),
      outputs: section(tags, :var_output),
      # M6-7: the paths the program retains, decision 270's nearest mark (Logex.Program).
      retained: program.retained,
      # M5-11: each array's sizes, by its name, so that a report gives a host an array as
      # a host is given one, a list (decision 151).
      arrays: for({name, %Tag{type: {:array, _, dims}}} <- tags, into: %{}, do: {name, dims}),
      shared: shared(externals, tags),
      writes: Map.new(Walk.writes(program), fn {name, lines} -> {name, length(lines)} end),
      # M5-8: each bit of a word written, by its path, and each word's writes through its
      # bits, so that a storage bit of a word is written alone where the word has no other.
      bit_writes: bit_writes(Walk.bit_writes(program)),
      # Decision 96: each member of an instance logic writes, by its path.
      member_writes: Map.new(Walk.member_writes(program), fn {path, _lines} -> {path, true} end),
      ons: ons,
      ons_rungs: Map.new(ons, fn {key, _bits} -> {key, true} end),
      ons_bits: for({_key, bits} <- ons, bit <- bits, into: %{}, do: {bit_name(bit), true}),
      # M3-1: every built-in instance, a timer or not, with the preset of the instruction
      # that runs it and its type's rules (Logex.FbType.rules/1): the preset rules are every
      # built-in's, and the forecast and the resume its type's.
      timers: Enum.reduce(tags, %{}, &built_in(&1, &2, presets)),
      # M2-5: each instance of a user block, with its type and whether a `cal` runs it; and
      # where each block type's body has its one-shots and what it runs, by the type's name.
      blocks: Enum.reduce(tags, %{}, &block(&1, &2, called)),
      bodies: bodies
    }
  end

  # M5-14 (decision 154): the instances a tag holds, each by its path: an instance's own
  # name, and each element of an array of instances by its, `lane_t[2]`, in the elements'
  # order, so that every rule of an instance is an element's.
  # (An instance's own is gathered as it was before M5-14, and the elements after it, into
  # the same map, so that a table of no array of instances costs what it did.)
  defp instances_of(name, {:array, %FbType{} = type, dims}),
    do: for(index <- Logex.Array.indexes(dims), do: {Logex.Array.name(name, index), type})

  defp built_in({name, %Tag{type: %FbType{body: nil} = type}}, acc, presets),
    do: Map.put(acc, name, {preset(Map.get(presets, name)), FbType.rules(type)})

  defp built_in({name, %Tag{type: {:array, %FbType{body: nil}, _dims} = type}}, acc, presets),
    do:
      for(
        {key, type} <- instances_of(name, type),
        into: acc,
        do: {key, {preset(Map.get(presets, key)), FbType.rules(type)}}
      )

  defp built_in(_other, acc, _presets), do: acc

  defp block({name, %Tag{type: %FbType{body: %Program{}} = type}}, acc, called),
    do: Map.put(acc, name, {type, is_map_key(called, name)})

  defp block({name, %Tag{type: {:array, %FbType{body: %Program{}}, _dims} = type}}, acc, called),
    do:
      for(
        {key, type} <- instances_of(name, type),
        into: acc,
        do: {key, {type, is_map_key(called, key)}}
      )

  defp block(_other, acc, _called), do: acc

  defp section(tags, wanted),
    do: for({name, %Tag{section: ^wanted}} <- tags, into: %{}, do: {name, true})

  # OE-2: the var_externals that are globals, held by no state (above).
  defp shared(:tags, _tags), do: %{}
  defp shared(:globals, tags), do: section(tags, :var_external)

  # The preset of the instruction that runs a built-in instance, Logex.Walk.presets/1's, or
  # nil where no instruction of the program runs it.
  defp preset({_line, preset}), do: preset
  defp preset(nil), do: nil

  # One direction, from the program a switch stops to the one it starts, or a prune keeps.
  # `left` is the watched outputs the program stopped shows: what a switch taken while it
  # is the program that last scanned learns from the state. `stops` names the program
  # stopped, `:original` or `:candidate`, and `blocks` is the one-shots of the program
  # started to block where the program stopped is the one that last scanned.
  defp plan({stops, from}, to, held, watched),
    do: %{
      stops: stops,
      blocks: blocks(from, to),
      ons: to.ons_bits,
      initial: to.initial,
      table: to.table,
      keep: Map.new(to.tags, fn {name, _tag} -> {name, true} end),
      starts:
        for(
          {name, tag} <- to.tags,
          not is_map_key(to.shared, name),
          do: {name, not is_map_key(from.tags, name), fit(tag)}
        ),
      inputs: to.inputs,
      lists: Map.merge(from.arrays, to.arrays),
      live: for(name <- Map.keys(to.inputs), not is_map_key(from.inputs, name), do: name),
      unread: for(name <- Map.keys(from.inputs), not is_map_key(to.inputs, name), do: name),
      held: held,
      unwritten: unwritten(from, to),
      shows: to.outputs,
      left: for(name <- Map.keys(watched), is_map_key(from.outputs, name), do: name),
      changed: changed(from, to),
      timers: timers(from, to),
      nested: nested(from, to),
      opens: opens(Map.merge(from.arrays, to.arrays), from.tags, to.tags)
    }

  # M5-14's review: the arrays of instances either program declares, which a switch and a
  # prune open, looked for only where either declares an array.
  defp opens(arrays, _from, _to) when map_size(arrays) == 0, do: []

  defp opens(arrays, from, to),
    do: for({name, _dims} <- arrays, instances?(Map.get(to, name, Map.get(from, name))), do: name)

  defp instances?(%Tag{type: type}) when is_instances(type), do: true
  defp instances?(_other), do: false

  # Each built-in instance either program declares, with the preset of the instruction
  # that runs it in the program stopped and in the one started, nil for none, and its
  # type's rules, which accept keeps one type a name: the `.pre` rules read no more.
  defp timers(from, to),
    do:
      for(
        {name, {_preset, rules}} <- Map.merge(from.timers, to.timers),
        do: {name, preset_in(from, name), preset_in(to, name), rules}
      )

  defp preset_in(facts, name), do: preset_of(Map.get(facts.timers, name))

  defp preset_of({preset, _rules}), do: preset
  defp preset_of(nil), do: nil

  # Decision 20: a var_output of either program that `from` drove and `to` does not drive
  # as a var_output.
  defp held(from, to),
    do:
      Enum.sort(
        for name <- Map.keys(Map.merge(from.outputs, to.outputs)),
            is_map_key(from.writes, name),
            not drives?(to, name),
            do: name
      )

  defp drives?(facts, name),
    do: is_map_key(facts.outputs, name) and is_map_key(facts.writes, name)

  # Decision 96: a member input that `from` writes and `to` does not, of a built-in instance
  # `to` declares, at any depth: a counter's `r`, `ld` or `pv`, an `rto`'s `r`, or a timer's
  # `.pre`, each an input logic may write (Logex.FbType). It keeps its value, as an output
  # no program drives any more does (decision 20), and a switch reports it, by its path. A
  # timer's `.acc`, which logic may write too, is its own output, set at every run.
  defp unwritten(from, to),
    do:
      Enum.sort(
        for path <- Map.keys(from.member_writes),
            not is_map_key(to.member_writes, path),
            input?(String.split(path, "."), to.tags),
            do: path
      )

  defp input?([name | members], tags) when is_element_key(name),
    do: input_in(of_elements(Map.get(tags, elem(element_key(name), 0))), members)

  defp input?([name | members], tags), do: input_in(Map.get(tags, name), members)

  defp input_in(%Tag{type: %FbType{} = type}, members), do: input_of(type, members)
  defp input_in(_not_an_instance, _members), do: false

  defp input_of(%FbType{body: nil, members: members}, [member]),
    do: Enum.any?(members, &match?(%Member{name: ^member, role: :input, write: true}, &1))

  defp input_of(%FbType{body: %Program{}, members: members} = type, [member | inner]),
    do: input_of(type_of(type, Enum.find(members, &(&1.name == member))), inner)

  defp input_of(_type, _path), do: false

  defp type_of(_type, nil), do: nil
  defp type_of(type, %Member{} = member), do: FbType.type_of(type, member)

  # Decision 29: an elementary tag both declare, of one type, a bool or any integer width
  # since M5-3 (decision 157), whose initial value differs, since M5-10 a real's too, its
  # declared values compared exactly, as decision 157 has it, `var x real 0` and `var x real
  # 0.0` two values, `{0, 0.0}`, though either starts a new instance at 0.0,
  # and that is no var_input of `to`, since a restart keeps a var_input's value. OE-2: nor
  # a var_external that is a global in either, whose value and initial value are the
  # global's.
  #
  # M5-11 (decision 157): an array both declare, of one type, its sizes included, is
  # compared element by element, each element whose declared value differs reported by its
  # name, `limits[2]`, an element a list does not give at its type's zero; `name` is the
  # tag's, which a switch starts whole where it starts it.
  defp changed(from, to),
    do:
      for(
        {name, %Tag{type: type}} <- to.tags,
        is_elementary(type) or (is_array(type) and not is_instances(type)),
        not is_map_key(to.inputs, name),
        not is_map_key(to.shared, name) and not is_map_key(from.shared, name),
        {:ok, %Tag{type: ^type}} <- [Map.fetch(from.tags, name)],
        {shown, old, new} <-
          initials(type, name, Map.fetch!(from.tags, name), Map.fetch!(to.tags, name)),
        old !== new,
        do: {name, shown, old, new}
      )

  defp initials({:array, type, dims}, name, from, to),
    do:
      Enum.zip([
        Enum.map(Logex.Array.indexes(dims), &Logex.Array.name(name, &1)),
        listed(from, type, dims),
        listed(to, type, dims)
      ])

  defp initials(_type, name, from, to), do: [{name, declared(from), declared(to)}]

  defp listed(%Tag{initial: nil}, type, dims),
    do: List.duplicate(Declarations.zero(type), Logex.Array.size(dims))

  defp listed(%Tag{initial: values}, _type, _dims), do: values

  # A tag's declared initial value, or its type's zero where it declares none, as a new
  # instance starts it but for a real's rounding.
  defp declared(%Tag{type: type, initial: nil}), do: Declarations.zero(type)
  defp declared(%Tag{initial: initial}), do: initial

  # M2-5: an instance of a user block fits by being a map: which members it holds is the
  # nested migration's to settle, member by member (below).
  defp fit(%Tag{type: %FbType{body: %Program{}}}), do: :block

  defp fit(%Tag{type: %FbType{} = type}),
    do: {:members, Enum.sort(Map.keys(FbType.initial(type)))}

  # M5-14: an array of instances fits by its shape, each element as an instance does.
  defp fit(%Tag{type: {:array, %FbType{} = type, dims}} = tag),
    do: {:instances, dims, fit(%{tag | type: type})}

  defp fit(%Tag{type: type}), do: type

  # Where a program's one-shots are, read from Logex.Walk's instructions of each rung,
  # every group however deep included: for each rung that holds an `ons`, the rung with its
  # line numbers taken out, beside the storage bits of its `ons`. A rung is stripped once
  # and compared once, however many `ons` it holds. How many times each name is written,
  # a storage bit among them, is Logex.Walk.writes/1's, which reaches into the blocks too
  # (M2-4).
  #
  # M2-5: an `ons` inside an instance a `cal` runs is a one-shot of the program's too, its
  # bit named by its path, `s1.edge`, and its rung the chain of rungs down to it, each with
  # its line numbers taken out: the body's rung that holds it, the rung of the body above
  # that `cal`s its instance, and so on up to the program's rung that `cal`s the outermost,
  # so a change to any of them, a `cal`'s operands included, makes it a changed one-shot
  # (decision 21, by path). Each block type's body is read once, however many instances run
  # it, and the walk down is linear in the instances.
  defp rungs(rungs, tags) do
    bodies = bodies(instances(tags), %{})

    Enum.reduce(rungs, {[], %{}, bodies}, fn {:rung, elements} = rung, {ons, called, _} ->
      {bits, cals} = oned_and_called(rung, tags)
      chain = chain(bits, cals, {elements, tags})
      ons = Enum.reduce(cals, oned(bits, chain, ons), &inside(&1, chain, &2, bodies))
      {ons, runs(cals, called), bodies}
    end)
  end

  defp chain([], [], _elements), do: nil
  defp chain(_bits, _cals, {elements, tags}), do: [stripped(elements, tags)]

  defp oned([], _key, ons), do: ons
  defp oned(bits, key, ons), do: [{key, bits} | ons]

  defp runs(cals, called),
    do: Enum.reduce(cals, called, fn {name, _type}, set -> Map.put(set, name, true) end)

  # Every user block type a program holds, at any depth, by name: the rungs of its body
  # that hold an `ons` or a `cal`, each stripped, with the bits and the instances, and the
  # instances it runs. Each type is read once, however many instances and paths reach it,
  # and its walk reads its tags with each instance's type itself, as it reads inside the
  # program's one table (decision 53).
  defp bodies(types, bodies),
    do:
      Enum.reduce(types, bodies, fn
        %FbType{name: name, body: %Program{} = body}, bodies when not is_map_key(bodies, name) ->
          tags = Program.typed_tags(body)
          bodies = bodies(instances(tags), Map.put(bodies, name, nil))
          Map.put(bodies, name, body(body, tags))

        _known, bodies ->
          bodies
      end)

  # The types of a table's instances of user blocks, as it gives them.
  defp instances(tags),
    do:
      for(
        {_, %Tag{type: type}} <- tags,
        type = element_type(type),
        match?(%FbType{body: %Program{}}, type),
        do: type
      )

  # An array of instances' elements' type, since M5-14, and any other type as it is.
  defp element_type({:array, type, _dims}), do: type
  defp element_type(type), do: type

  defp body(%Program{rungs: rungs}, tags) do
    {held, called} =
      Enum.reduce(rungs, {[], %{}}, fn {:rung, elements} = rung, {held, called} ->
        {bits, cals} = oned_and_called(rung, tags)
        {held(bits, cals, {elements, tags}, held), runs(cals, called)}
      end)

    %{rungs: Enum.reverse(held), called: called}
  end

  defp held([], [], _elements, held), do: held

  defp held(bits, cals, {elements, tags}, held),
    do: [{stripped(elements, tags), bits, cals} | held]

  # One instance a `cal` runs, `prefix` its path, under the chain of rungs that runs it.
  defp inside({instance, %FbType{name: type}}, chain, acc, bodies),
    do: inside(Map.fetch!(bodies, type), instance, chain, acc, bodies)

  defp inside(%{rungs: rungs}, prefix, chain, ons, bodies),
    do:
      Enum.reduce(rungs, ons, fn {stripped, bits, cals}, ons ->
        chain = [stripped | chain]
        ons = oned(Enum.map(bits, &prefixed(prefix, &1)), {prefix, chain}, ons)

        Enum.reduce(cals, ons, fn {name, type}, ons ->
          inside({prefix <> "." <> name, type}, chain, ons, bodies)
        end)
      end)

  # A rung's `ons` storage bits and the instances its `cal`s run, each newest first, from
  # Logex.Walk's instructions of the rung. M3-1 (decision 87): an instruction that runs a
  # built-in instance with an edge memory, a counter's `ctu` or `ctd`, has its memory among
  # the bits, `{:edge, "boxes.cu"}`, by its type's rules (Logex.FbType.rules/1). M3-4
  # (decision 80): a pulse coil's storage bit is a one-shot's, as an `ons`'s is, and its
  # pulse bit an ordinary bool.
  defp oned_and_called(rung, tags),
    do:
      Enum.reduce(Walk.instructions([rung]), {[], []}, fn
        {symbol, _line, [{:name, _, bit} | _]}, {bits, cals} when symbol in @one_shots ->
          {[bit | bits], cals}

        # M5-8 (decision 155): a bit of a word kept as a storage bit, by its path.
        {symbol, _line, [{:bit, _, [_], _, _, _} = bit | _]}, {bits, cals}
        when symbol in @one_shots ->
          {[Walk.bit_name(bit) | bits], cals}

        # Decision 221: a bit of an element kept as a storage bit, by its name.
        {symbol, _line, [{:bit, _, {:element, _, _, _, _}, _, _, _} = bit | _]}, {bits, cals}
        when symbol in @one_shots ->
          {[Walk.bit_name(bit) | bits], cals}

        # M5-11 (decision 154): an element kept as a storage bit, by its name, `edge[2]`.
        {symbol, _line, [{:element, _, _, _, _} = element | _]}, {bits, cals}
        when symbol in @one_shots ->
          {[Walk.bit_name(element) | bits], cals}

        instruction, {bits, cals} ->
          {edges(instruction, tags, bits), calling(instruction, tags, cals)}
      end)

  defp edges({symbol, _line, [{:name, _, instance} | _]}, tags, bits),
    do: edge(Map.get(tags, instance), symbol, instance, bits)

  # M5-14: an element of an array of counters or pulse timers, its memory by its path,
  # `lane_c[1].cu`.
  defp edges({symbol, _line, [{:element, _, array, _index, instance} | _]}, tags, bits)
       when symbol in @runners,
       do: edge(of_elements(Map.get(tags, array)), symbol, instance, bits)

  defp edges(_instruction, _tags, bits), do: bits

  defp of_elements(%Tag{type: {:array, type, _dims}} = tag), do: %{tag | type: type}
  defp of_elements(_no_array), do: nil

  defp edge(%Tag{type: %FbType{body: nil} = type}, symbol, instance, bits),
    do: edge_of(Map.get(FbType.rules(type).runs, symbol), instance, bits)

  defp edge(_not_a_builtin, _symbol, _instance, bits), do: bits

  defp edge_of({memory, _reads}, instance, bits) when is_binary(memory),
    do: [{:edge, instance <> "." <> memory} | bits]

  defp edge_of(_no_memory, _instance, bits), do: bits

  # A storage bit's name, or an edge memory's path; and either under a prefix, its path
  # inside an instance.
  defp bit_name({:edge, path}), do: path
  defp bit_name(bit), do: bit

  defp prefixed(prefix, {:edge, path}), do: {:edge, prefix <> "." <> path}
  defp prefixed(prefix, bit), do: prefix <> "." <> bit

  # M2-5: the instances a rung's `cal`s run, each with its type. A `cal` of an instance its
  # table does not hold as a user block's, which only a body built by hand can have, runs
  # nothing (Logex.Runtime), and so runs nothing here either; its signature/2 slots are none,
  # so it writes nothing (Logex.Walk).
  defp calling({:cal, _line, [{:name, _, instance} | _]}, tags, cals),
    do: block_call(Map.get(tags, instance), instance, cals)

  # M5-14: a `cal` of an element of an array of user blocks runs it, by its path.
  defp calling({:cal, _line, [{:element, _, array, _index, instance} | _]}, tags, cals),
    do: block_call(of_elements(Map.get(tags, array)), instance, cals)

  defp calling(_instruction, _tags, cals), do: cals

  defp block_call(%Tag{type: %FbType{body: %Program{}} = type}, instance, cals),
    do: [{instance, type} | cals]

  defp block_call(_not_a_block, _instance, cals), do: cals

  # A rung as the text says it, line numbers taken out: a rung moved or renumbered is the
  # same rung (decision 21).
  #
  # M2-5: a `cal` is stripped with the formals its operands fill, its block's members in
  # `cal`'s order, so an edit that reorders a block's inputs, which the text of the rung
  # does not show, changes the rung as an edit of its operands would (decision 21).
  defp stripped(elements, tags), do: Enum.map(elements, &bare(&1, tags))

  defp bare({:branches, legs}, tags), do: {:branches, Enum.map(legs, &stripped(&1, tags))}

  defp bare({:cal, _line, [{:name, _, instance} | _] = operands}, tags),
    do: {:cal, Enum.map(operands, &operand/1), formals(Map.get(tags, instance))}

  defp bare({:cal, _line, [{:element, _, array, _index, _name} | _] = operands}, tags),
    do: {:cal, Enum.map(operands, &operand/1), formals(of_elements(Map.get(tags, array)))}

  # M3-1 (decision 87): an instruction that runs a built-in instance is stripped of its
  # preset, which no power on the rung reads, so a preset changed alone is the same rung.
  defp bare({symbol, _line, [instance, _preset]}, _tags) when symbol in @runners,
    do: {symbol, [operand(instance)]}

  defp bare({symbol, _line, operands}, _tags), do: {symbol, Enum.map(operands, &operand/1)}

  defp formals(%Tag{type: %FbType{body: %Program{}} = type}),
    do: for({_slot, %Member{name: name}} <- tl(FbType.signature(type)), do: name)

  defp formals(_not_a_block), do: nil

  defp operand({kind, _line, value}), do: {kind, value}

  # M5-14: a member of an element by its element and its members, and a bit of one by it.
  defp operand({:member, _line, element, members}), do: {:member, operand(element), members}

  defp operand({:bit, _line, {:member, _, _, _} = member, n, _mask, _name}),
    do: {:bit, operand(member), n}

  defp operand({:bit_at, _line, {:member, _, _, _} = member, index, _width, _name}),
    do: {:bit_at, operand(member), operand(index)}

  # M5-8: a bit by its path and number; its mask follows from its word's type, which an
  # edit changes only with a restart.
  # Decision 221: a bit of an element by its element, as an element is compared.
  defp operand({:bit, _line, {:element, _, _, _, _} = element, n, _mask, _name}),
    do: {:bit, operand(element), n}

  defp operand({:bit, _line, {:element_at, _, _, _, _, _} = element, n, _mask, _name}),
    do: {:bit, operand(element), n}

  defp operand({:bit, _line, path, n, _mask, _name}), do: {:bit, path, n}
  # M5-9: a bit whose number a tag holds by its path and the tag.
  defp operand({:bit_at, _line, {:element, _, _, _, _} = element, index, _width, _name}),
    do: {:bit_at, operand(element), operand(index)}

  defp operand({:bit_at, _line, {:element_at, _, _, _, _, _} = element, index, _width, _name}),
    do: {:bit_at, operand(element), operand(index)}

  defp operand({:bit_at, _line, path, index, _width, _name}), do: {:bit_at, path, operand(index)}
  # Decision 202: a literal is compared by its value, as a preset is, so an edit that only
  # respells one, `16#ff` for `255`, leaves its rung the same rung.
  defp operand({:int_lit, _line, value, _spelling}), do: {:int_lit, value}
  # M5-10: so is a real literal, `1.5e3` the same rung as `1500.0`.
  defp operand({:real_lit, _line, value, _spelling}), do: {:real_lit, value}
  # M5-11: an element by its array and its subscripts' values, so that an edit that only
  # respells a subscript, `temps[16#3]` for `temps[3]`, leaves its rung the same rung.
  defp operand({:element, _line, array, index, _name}), do: {:element, array, index}

  # M5-12: an element a tag subscripts by its array and its subscripts, each a literal's
  # value or its tag's name, so a subscript's tag is a use of the rung as any operand is.
  defp operand({:element_at, _line, array, index, _dims, _name}),
    do: {:element_at, array, Enum.map(index, &subscript/1)}

  defp subscript({:name, _line, name}), do: {:name, name}
  defp subscript(n), do: n

  # ---- M2-5: the state inside a user block's instances, across a switch -----------------

  # For each instance of a user block the program started declares, a plan of its members,
  # from the two versions of its type: the nested migration of §4.9, copying the members
  # both declare and starting the rest. Built per type, not per instance: an instance's plan
  # depends on its type, the other program's version of it, and whether each program runs
  # it, so a program of many instances of one block plans that block once, and the plan is
  # linear in the types and their members.
  #
  # An instance only the program stopped declares is kept, unused, until a prune, and its
  # plan holds only the timers inside it, whose `.pre` and `last` the edit's last switch
  # may have moved, to give back (fixes F1 and F11), as `timers/2` holds a timer only one
  # program declares.
  defp nested(from, to) do
    {plans, memo} =
      Enum.map_reduce(to.blocks, %{}, fn {name, {type, run}}, memo ->
        {was, ran} = before(Map.get(from.blocks, name), type)
        {plan, memo} = member_plan(was, type, {ran, run}, {from.bodies, to.bodies}, memo)
        {{name, plan}, memo}
      end)

    {gone, _memo} =
      Enum.flat_map_reduce(from.blocks, memo, fn
        {name, _block}, memo when is_map_key(to.blocks, name) ->
          {[], memo}

        {name, {type, _ran}}, memo ->
          {plan, memo} = gone_plan(Map.fetch(memo, {:gone, type.name}), type, memo)
          {[{name, plan}], memo}
      end)

    plans ++ gone
  end

  # The other program's version of an instance's type, where it holds one of that name.
  defp before({%FbType{name: name} = was, ran}, %FbType{name: name}), do: {was, ran}
  defp before(_none, _type), do: {nil, false}

  defp member_plan(was, type, runs, bodies, memo) do
    key = {type.name, was != nil, runs}
    planned(Map.fetch(memo, key), key, {was, type, runs, bodies}, memo)
  end

  defp planned({:ok, plan}, _key, _types, memo), do: {plan, memo}

  defp planned(:error, key, {was, type, runs, bodies}, memo) do
    before = {was, by_name(expanded(was))}

    {members, memo} =
      Enum.map_reduce(
        expanded(type),
        memo,
        &member(%{&1 | type: FbType.type_of(type, &1)}, before, {type, runs, bodies}, &2)
      )

    names = Map.new(type.members, &{&1.name, true})
    {gone, memo} = gone(was, names, memo)
    members = members ++ gone
    plan = %{members: members, names: names, opens: opens(Enum.map(members, &elem(&1, 1)))}
    {plan, Map.put(memo, key, plan)}
  end

  # The timers only the stopped program's version of a block declares, at any depth, which
  # the program started does not run: their `.pre` and `last` are still this edit's to give
  # back (fix F1, F11), as `timers/2` covers a timer only one program declares at the top
  # level. Planned once per type.
  defp gone(nil, _names, memo), do: {[], memo}

  defp gone(%FbType{members: members} = type, names, memo),
    do:
      members
      |> Enum.reject(&is_map_key(names, &1.name))
      |> Enum.flat_map(&element_members(&1, FbType.type_of(type, &1)))
      |> Enum.flat_map_reduce(memo, &gone_member(&1, FbType.type_of(type, &1), &2))

  defp gone_member(%Member{name: name}, %FbType{body: nil} = type, memo),
    do: {[{:timer_gone, name, FbType.rules(type)}], memo}

  defp gone_member(%Member{name: name}, %FbType{} = type, memo) do
    {plan, memo} = gone_plan(Map.fetch(memo, {:gone, type.name}), type, memo)
    {[{:block_gone, name, plan}], memo}
  end

  defp gone_member(_leaf, _type, memo), do: {[], memo}

  defp gone_plan({:ok, plan}, _type, memo), do: {plan, memo}

  defp gone_plan(:error, type, memo) do
    {members, memo} = gone(type, %{}, memo)
    plan = %{members: members, opens: opens(Enum.map(members, &elem(&1, 1)))}
    {plan, Map.put(memo, {:gone, type.name}, plan)}
  end

  defp member(%Member{name: name} = member, {was, before}, context, memo),
    do: member(member, resolved(was, Map.get(before, name)), context, memo, name)

  # A member with its type itself, a user block's taken from the body (Logex.FbType).
  defp resolved(_type, nil), do: nil
  defp resolved(type, member), do: %{member | type: FbType.type_of(type, member)}

  defp member(%Member{type: type, initial: initial}, old, _context, memo, name)
       when is_elementary(type) or is_array(type),
       do: {{:leaf, name, type, initial, old_initial(old), old != nil}, memo}

  defp member(
         %Member{type: %FbType{body: nil} = type, initial: initial},
         old,
         context,
         memo,
         name
       ) do
    {_type, {ran, run}, _bodies} = context
    start = FbType.initial(type, initial)
    keys = Enum.sort(Map.keys(start))
    rules = FbType.rules(type)
    from = runs_ton(ran, old, rules)
    {{:timer, name, keys, start, {from, runs_ton(run, initial, rules)}, old != nil, rules}, memo}
  end

  defp member(%Member{type: %FbType{} = type, initial: initial}, old, context, memo, name) do
    {owner, {ran, run}, {before_bodies, bodies}} = context
    was = old_type(old)
    ran = ran and called?(before_bodies, owner.name, name)
    run = run and called?(bodies, owner.name, name)
    {plan, memo} = member_plan(was, type, {ran, run}, {before_bodies, bodies}, memo)
    {{:block, name, {FbType.held(type), initial}, old != nil, plan}, memo}
  end

  defp old_initial(nil), do: nil
  defp old_initial(%Member{initial: initial}), do: initial

  defp old_type(nil), do: nil
  defp old_type(%Member{type: type}), do: type

  # The preset of the instruction that runs a built-in instance inside a block, as the
  # compiler gives its preset member (Logex.Compiler), where the program runs the block; nil
  # where it does not, or no instruction of the body runs it.
  defp runs_ton(false, _member_or_initial, _rules), do: nil
  defp runs_ton(true, nil, _rules), do: nil
  defp runs_ton(true, %Member{initial: initial}, rules), do: runs_ton(true, initial, rules)
  defp runs_ton(true, %{} = initial, %{preset: preset}), do: Map.get(initial, preset)

  # Whether a block's body, in one program's version of it, has a `cal` of an instance it
  # holds. It is asked only of a version the program holds: of the program started's own,
  # and of the stopped program's where it runs the instance, and so holds a version of that
  # name, since accept refuses an instance or member whose block is renamed.
  defp called?(bodies, type, name), do: is_map_key(Map.fetch!(bodies, type).called, name)

  # Decision 21 and fix F7: the storage bits of the `ons` of `to` that a switch from `from`,
  # the program that last scanned, blocks until a scan runs each. Each is blocked unless
  # `from` has that `ons` in an identical rung, line numbers and presets ignored (M3-1,
  # decision 87, so a `ton`'s preset changed alone blocks none), and writes its bit
  # through nothing else: an `ons` that `to` adds, one whose rung it changes, and one whose
  # bit `from` also writes through another instruction, which may leave the bit at a value
  # that is not the power the `ons` last received.
  #
  # M3-1 (decision 87): a counter's edge memory, which no logic writes, is blocked where its
  # rung is not in `from`, with no test of the writes, which count every write of its
  # instance.
  defp blocks(from, to),
    do:
      for(
        {rung, bits} <- to.ons,
        same <- [is_map_key(from.ons_rungs, rung)],
        bit <- bits,
        not (same and written_alone?(bit, from)),
        do: bit_name(bit)
      )

  defp written_alone?({:edge, _path}, _from), do: true

  defp written_alone?(bit, %{writes: writes, bit_writes: {bits, words}}),
    do: alone(Map.fetch(bits, bit), bit, {writes, words, bits})

  # A bool written once; or since M5-8 a bit of a word written once, its word written
  # through its bits alone, never whole; and since decision 221 a bit of an element so,
  # its element never written whole, which the walk counts among the array's bit writes.
  defp alone(:error, bit, {writes, _words, _bits}), do: Map.get(writes, bit) == 1

  defp alone({:ok, 1}, bit, {writes, words, bits}),
    do:
      Map.get(writes, word_of(bit)) == Map.get(words, word_of(bit)) and
        not is_map_key(bits, element_of(:binary.split(bit, "]."), bit))

  defp alone({:ok, _more}, _bit, _writes), do: false

  # The element a bit of one is in, `e[1]` of `e[1].3`; any other bit is in none.
  defp element_of([element, _number], _bit), do: element <> "]"
  defp element_of([_none], _bit), do: nil

  defp bit_writes(written) do
    bits = Map.new(written, fn {path, lines} -> {path, length(lines)} end)

    words =
      Enum.reduce(bits, %{}, fn {path, n}, words ->
        Map.update(words, word_of(path), n, &(&1 + n))
      end)

    {bits, words}
  end

  # The word a bit's path is in, `s1.status` for `s1.status.3`; an element's, `edge[2]`, and
  # since decision 221 a bit of an element's, `faults[2].3`, its array, which the walk
  # counts their writes under.
  defp word_of(path), do: word_in(:binary.split(path, "["), path)

  defp word_in([array, _subscripts], _path), do: array

  defp word_in([_no_element], path),
    do: path |> String.split(".") |> Enum.drop(-1) |> Enum.join(".")

  # ---- the per-instance half: a switch, between two scans, and a prune --------------------

  def switch(plan, record, state, first_test?),
    do: switch(plan, record, state, first_test?, state.now)

  # OE-2 (decision 56): `at` is the clock a timer resumes from, which the switch then gives
  # the instance as its `now`: a lone instance's own `now`, so nothing moves, and in a
  # resource the resource's. Fix F11's undo reads the instance's own `now` before it moves,
  # which while `switched` is true is the time the last switch gave it, so a cycle between
  # a test and its untest that does not scan the instance cannot hide a resume from it.
  def switch(plan, record, %Instance{env: env, now: now} = state, first_test?, at) do
    shown = learnt(record.shown, plan.left, state)

    started =
      for {name, added?, fit} <- plan.starts,
          starts?(Map.fetch(env, name), added?, fit, first_test?),
          do: name

    fresh = Map.take(plan.initial, started)
    env = Map.merge(env, fresh)
    scanned = scanned(record.scanned, state, plan)
    clock = {{now, at}, state.switched, elem(scanned, 0) == plan.stops}

    {env, inside, pre} =
      Enum.reduce(
        plan.nested,
        {opened(env, plan.opens), [], %{}},
        &migrate(&1, fresh, {first_test?, record.pre, clock, plan.table}, &2)
      )

    env = closed(env, plan.opens)

    {inputs, added} = Enum.split_with(started, &is_map_key(plan.inputs, &1))
    blocked = blocked(scanned, plan)

    report =
      for(name <- added, do: {:added, name, host(plan, name, Map.fetch!(env, name))}) ++
        for(
          name <- Enum.uniq(plan.live ++ inputs),
          do: {:input, name, host(plan, name, Map.fetch!(env, name))}
        ) ++
        for(name <- plan.unread, do: {:unread, name, host(plan, name, Map.get(env, name, 0))}) ++
        for(
          {name, shown, old, new} <- plan.changed,
          not is_map_key(fresh, name),
          do: {:initial_changed, shown, {old, new}}
        ) ++
        for(bit <- blocked, do: {:ons_blocked, bit, bit_at(env, bit)}) ++
        holding(plan, shown, env)

    {env, timed, pre} =
      Enum.reduce(plan.timers, {opened(env, plan.opens), [], pre}, fn {name, from, to, rules},
                                                                      acc ->
        timed({name, name, from, to, rules}, record.pre, clock, acc)
      end)

    env = closed(env, plan.opens)

    # Decision 96: each member input no logic of the program started writes any more, with
    # the value it keeps, read once the timer rules have moved any `.pre`.
    unwritten = for path <- plan.unwritten, do: {:unwritten, path, bit_at(env, path)}

    {%{state | env: env, switched: true, ons_blocked: blocked, now: at},
     %{record | shown: shown, pre: pre, scanned: scanned},
     Enum.sort(requalified(plan.requalified, env, timed ++ inside ++ report ++ unwritten))}
  end

  # M6-7 (decisions 278 and 302): each path whose retention the edit changes, with the
  # value it holds, which the next warm restart now keeps or no longer keeps; nothing is
  # written. A plan of none pays one clause.
  defp requalified([], _env, report), do: report

  defp requalified(paths, env, report),
    do: for({kind, path, segments} <- paths, do: {kind, path, held_at(env, segments)}) ++ report

  # M6-7: the value at a retained path as a report gives it to a host, an array's as a
  # list (M5-11), an instance's as the state holds it, a map of its members, and one of
  # every element of an array of instances, `gates[*].count`, a list of each element's in
  # the elements' order, a list of lists for more dimensions.
  defp held_at(value, []), do: listed_held(value)
  defp held_at(elements, ["[*]" | path]) when is_tuple(elements), do: every_held(elements, path)
  defp held_at(%{} = map, [key | path]), do: held_at(Map.get(map, key, 0), path)
  defp held_at(_not_a_map, _path), do: 0

  defp every_held(elements, path) when is_tuple(elements),
    do: Enum.map(Tuple.to_list(elements), &every_held(&1, path))

  defp every_held(element, path), do: held_at(element, path)

  defp listed_held(value) when is_tuple(value), do: Enum.map(Tuple.to_list(value), &listed_held/1)
  defp listed_held(value), do: value

  # M5-11: a value as a report gives it to a host, an array's as a list, a list of lists for
  # more dimensions, as a host's input takes one, where the state holds it whole.
  defp host(%{lists: lists}, name, value), do: listed_value(Map.get(lists, name), value)

  defp listed_value(nil, value), do: value
  defp listed_value(dims, value) when is_tuple(value), do: Logex.Array.to_list(value, dims)
  defp listed_value(_dims, value), do: value

  # A storage bit's value, a bit inside an instance found by its path (M2-5); and since
  # decision 96 a member's, by its path, `lube.r`.
  defp bit_at(env, bit), do: path_at(env, String.split(bit, "."))

  defp path_at(value, []), do: value

  # M5-11: an element kept as a storage bit, `edge[2]` or `s1.edge[2]`, is its value.
  defp path_at(%{} = map, [key]) when binary_part(key, byte_size(key) - 1, 1) == "]",
    do: element_at(Logex.Array.split(key), map)

  # M5-14: an element of an array of instances on the way, `lane_c[1]` of `lane_c[1].r`.
  defp path_at(%{} = map, [key | path]) when is_element_key(key),
    do: path_at(element_at(Logex.Array.split(key), map), path)

  defp path_at(%{} = map, [key | path]), do: path_at(Map.get(map, key, 0), path)
  # M5-8: a storage bit that is a bit of a word, `status.3`, is that bit's value.
  defp path_at(word, [part]) when is_integer(word), do: bit_value(Integer.parse(part), word)
  defp path_at(_not_a_map, _path), do: 0

  defp element_at({array, subscripts}, map),
    do:
      element_value(
        Map.get(map, array),
        Enum.map(subscripts, &elem(Logex.Array.subscript(&1), 1))
      )

  defp element_value(value, index) when is_tuple(value), do: Logex.Array.fetch(value, index)
  defp element_value(_not_an_array, _index), do: 0

  defp bit_value({n, ""}, word), do: Bitwise.band(Bitwise.bsr(word, n), 1)
  defp bit_value(_no_bit, _word), do: 0

  # M2-5, the nested migration (§4.9): inside each instance of a user block both programs
  # declare, kept as a map and not started whole above, each member the program started
  # declares moves by the rules a tag does: one the state lacks starts at its initial value;
  # at the first test, one the candidate's version of the block adds, or whose value does
  # not fit its type, starts so too; a kept bool or integer whose initial value changed keeps
  # its value and is reported; a timer meets the timer rules; and an instance it holds is
  # migrated in turn. A member only the stopped program's version declares is kept, unused,
  # until assemble or cancel prunes it. Each is reported by its path, `s1.count`.
  defp migrate({name, plan}, fresh, rules, {env, reports, pre}) do
    migrate_in(
      key_get(env, name),
      is_map_key(fresh, held_under(name)),
      {name, plan},
      rules,
      {env, reports, pre}
    )
  end

  defp migrate_in(%{} = map, false, {name, plan}, rules, {env, reports, pre}) do
    {map, reports, pre} = members(plan, map, name, rules, {reports, pre})
    {key_put(env, name, map), reports, pre}
  end

  defp migrate_in(_started_or_not_a_map, _fresh?, _plan, _rules, acc), do: acc

  defp members(plan, map, prefix, rules, {reports, pre}) do
    {map, reports, pre} =
      Enum.reduce(
        plan.members,
        {opened(map, plan.opens), reports, pre},
        &moved_member(&1, prefix, rules, &2)
      )

    {closed(map, plan.opens), reports, pre}
  end

  defp moved_member({:leaf, name, type, initial, old, kept?}, prefix, {first?, _, _, _}, acc) do
    path = prefix <> "." <> name

    starts?(key_fetch(elem(acc, 0), name), not kept?, type, first?)
    |> started(name, path, start_of(type, initial), acc)
    |> initials_changed(type, {kept?, old, initial}, path)
  end

  defp moved_member({:timer, name, keys, initial, {from, to}, kept?, type}, prefix, rules, acc) do
    {first?, undo, clock, _table} = rules
    {map, reports, pre} = acc
    path = prefix <> "." <> name

    timer_moved(
      starts?(key_fetch(map, name), not kept?, {:members, keys}, first?),
      {name, path, initial, from, to, type},
      {undo, clock},
      {map, reports, pre}
    )
  end

  defp moved_member({:block, name, initial, kept?, plan}, prefix, rules, {map, reports, pre}) do
    {first?, _undo, _clock, _table} = rules
    path = prefix <> "." <> name

    block_moved(
      starts?(key_fetch(map, name), not kept?, :block, first?),
      {name, path, initial, plan},
      rules,
      {map, reports, pre}
    )
  end

  # A timer only the stopped program's version declares: kept, unused, and its `.pre` and
  # `last` given back where this edit's last switch moved them.
  defp moved_member({:timer_gone, name, type}, prefix, {_first?, undo, clock, _table}, acc),
    do: timed({name, prefix <> "." <> name, nil, nil, type}, undo, clock, acc)

  defp moved_member({:block_gone, name, plan}, prefix, rules, {map, reports, pre}),
    do:
      block_kept(
        key_get(map, name),
        {name, prefix <> "." <> name, plan},
        rules,
        {map, reports, pre}
      )

  # M5-10 (decision 150): a member that is a real starts at its declared value's nearest,
  # and since M5-11 one that is an array as an array tag does.
  defp start_of({:array, _, _} = type, initial), do: Logex.Array.started(type, initial)
  defp start_of(type, initial) when type in @reals, do: Logex.Real.nearest(type, initial)
  defp start_of(_type, initial), do: initial

  defp started(true, name, path, initial, {map, reports, pre}),
    do: {:started, {key_put(map, name, initial), [{:added, path, initial} | reports], pre}}

  defp started(false, _name, _path, _initial, acc), do: {:kept, acc}

  # M5-11 (decision 157): an array member's initial list compared element by element, each
  # element reported by its path, `s1.limits[2]`.
  defp initials_changed(moved, {:array, _, dims} = type, {kept?, old, new}, path),
    do:
      Enum.reduce(
        Enum.zip([
          Logex.Array.indexes(dims),
          Logex.Array.declared(type, old),
          Logex.Array.declared(type, new)
        ]),
        moved,
        fn {index, old, new}, moved ->
          initial_changed(moved, {kept?, old, new}, Logex.Array.name(path, index))
        end
      )
      |> unmoved()

  defp initials_changed(moved, _type, initials, path),
    do: unmoved(initial_changed(moved, initials, path))

  defp unmoved({:started, acc}), do: acc
  defp unmoved({:kept, acc}), do: acc
  defp unmoved(acc), do: acc

  defp initial_changed({:started, acc}, _initials, _path), do: {:started, acc}

  # Decision 157 (M5-10): compared exactly, so that 0 and 0.0 are two values.
  defp initial_changed({:kept, {map, reports, pre}}, {true, old, new}, path) when old !== new,
    do: {:kept, {map, [{:initial_changed, path, {old, new}} | reports], pre}}

  defp initial_changed({:kept, acc}, _initials, _path), do: {:kept, acc}

  defp timer_moved(true, {name, path, initial, _from, _to, _type}, _clocks, acc) do
    {map, reports, pre} = acc
    {key_put(map, name, initial), [{:added, path, initial} | reports], pre}
  end

  defp timer_moved(false, {name, path, _initial, from, to, type}, {undo, clock}, acc),
    do: timed({name, path, from, to, type}, undo, clock, acc)

  # A block's initial state is built only where one starts: built for every member it would
  # make the plan quadratic in the depth of nesting. The plan holds the block's type as the
  # program's table holds it, which it reads inside that table (decision 53): a type read
  # inside it carries the whole table, which a copy of the edit that keeps no sharing would
  # write out once per member planned.
  defp block_moved(true, {name, path, {type, overrides}, _plan}, rules, {map, reports, pre}) do
    {_first?, _undo, _clock, table} = rules
    initial = FbType.initial(FbType.within(type, table), overrides)
    {key_put(map, name, initial), [{:added, path, initial} | reports], pre}
  end

  defp block_moved(false, {name, path, _initial, plan}, rules, {map, reports, pre}),
    do: block_kept(key_get(map, name), {name, path, plan}, rules, {map, reports, pre})

  defp block_kept(%{} = inner, {name, path, plan}, rules, {map, reports, pre}) do
    {inner, reports, pre} = members(plan, inner, path, rules, {reports, pre})
    {key_put(map, name, inner), reports, pre}
  end

  defp block_kept(_not_a_map, _plan, _rules, acc), do: acc

  # Whether a switch starts a tag at its initial value: one the state lacks, always; and at
  # the first test, one the candidate adds, over what a plain swap left, or one whose value
  # does not fit its type (decision 26).
  defp starts?(:error, _added?, _fit, _first_test?), do: true
  defp starts?({:ok, _value}, _added?, _fit, false), do: false
  defp starts?({:ok, _value}, true, _fit, true), do: true
  defp starts?({:ok, value}, false, fit, true), do: not fits?(fit, value)

  # ---- one-shots across a switch (decision 21; fixes F2, F3 and F7) ----------------------

  # Which program left the storage bits, the one each `ons` would read them from, and the
  # bits still blocked against it. A scan since the last switch (`switched` false): the
  # program stopped, with what the scan left pending: a bit inside an instance whose body
  # no scan has run since it was listed (M2-5), and since M3-5 one on a rung a jump
  # skipped, at the top level too (decision 106), each bit still the one an older rung
  # wrote. No scan since, and that switch this edit's: what it recorded, so a test and an
  # untest with no scan between lose no real edge (F3). No scan since an earlier edit's
  # switch, whose program this edit cannot know: the program stopped is taken for it, with
  # the earlier edit's blocks still pending (F2).
  defp scanned(_known, %Instance{switched: false, ons_blocked: pending}, plan),
    do: {plan.stops, pending}

  defp scanned(nil, %Instance{ons_blocked: pending}, plan), do: {plan.stops, pending}
  defp scanned(known, _state, _plan), do: known

  # The block list a switch leaves: its plan's blocks where the program stopped left the
  # bits, none where the program started did, since its bits are then as it left them; and
  # every pending bit the program started still has an `ons` on. Sorted, each bit once.
  defp blocked({last, pending}, plan),
    do:
      Enum.sort(
        Enum.uniq(own(last, plan) ++ for(bit <- pending, is_map_key(plan.ons, bit), do: bit))
      )

  defp own(stops, %{stops: stops, blocks: blocks}), do: blocks
  defp own(_started, _plan), do: []

  # A timer fits by its member keys (decision 26): a map with none missing. A plain swap can
  # leave one that lacks some: where the program swapped out held a counter under the name,
  # a program that writes `t1.pre` and runs no `ton` on it leaves the counter's map with a
  # `pre`, which the timer rules, reading `.acc`, `.dn` and `.en`, could not take. A value
  # that is no map under an instance's tag is refused before any step since decision 184,
  # so the clauses for one are totality only.
  defp fits?(:block, value), do: is_map(value)

  defp fits?({:instances, dims, fit}, value),
    do: Logex.Array.held?(value, dims, &fits?(fit, &1))

  defp fits?({:members, keys}, %{} = timer), do: Enum.sort(Map.keys(timer)) == keys
  defp fits?({:members, _keys}, _not_a_timer), do: false
  # M5-11: an array fits where it is held whole, each element of its elements' type.
  defp fits?({:array, type, dims}, value),
    do: Logex.Array.held?(value, dims, &element_fits?(type, &1))

  defp fits?(type, value), do: Declarations.fits?(type, value)

  defp element_fits?(type, value) when type in @reals, do: Logex.Real.value?(type, value)
  defp element_fits?(type, value), do: Declarations.fits?(type, value)

  # ---- a timer across a switch (decision 23; fixes F1 and F6) -----------------------------

  # One timer either program declares, `from` and `to` the presets of the `ton`s that run
  # it in the program stopped and the one started, nil for none, taken after the start
  # rules, so one they started is at its initial value, where these rules move nothing.
  # A resume this edit's last switch made may be undone, its `.pre` moves, it may resume,
  # and the record keeps the `.pre` left, the one found, and the `last` a resume found.
  # A map a plain swap left with `.pre` but not every member is one no `ton` of either
  # program runs (below), so the rules that read the others never reach it.
  # `key` is the timer's name in the map it lives in, and `name` how the record and the
  # report name it: a top-level timer's name, or its path inside an instance (M2-5).
  # M3-1: `.pre` is the type's preset member, `pre` for a timer (Logex.FbType.rules/1).
  defp timed({key, name, _from, _to, %{preset: member}} = timer, undo, clock, {env, _, _} = acc),
    do:
      timer(Map.fetch(as_map(key_get(env, key)), member), timer, Map.get(undo, name), clock, acc)

  defp timer(
         {:ok, pre},
         {key, name, from, to, %{preset: member} = rules},
         undo,
         {{now, at}, switched, stopped_last?},
         {env, report, left}
       ) do
    {value, undone} = undone(key_get(env, key), undo, switched, now, name)
    target = target(undo, pre, from, to)

    {value, resumed, found} =
      resumed({from, to, stopped_last?}, Map.put(value, member, target), name, {at, rules})

    {key_put(env, key, value),
     moved(name, {pre, target, to}, value, rules) ++ undone ++ resumed ++ report,
     Map.put(left, name, {target, pre, found})}
  end

  # No `.pre`: what a plain swap left under the name of a timer the candidate does not
  # declare, since the first test starts again every one of its own that does not fit: a
  # value of another type, or a map of only the members logic wrote. No `ton` of either
  # program runs it, or that program's scan would have made it a timer's whole map, and no
  # rule reads it.
  defp timer(:error, _timer, _undo, _now, acc), do: acc

  defp as_map(%{} = map), do: map
  defp as_map(_not_a_map), do: %{}

  # M5-14 (decision 154): an element of an array of instances is moved by its path, as an
  # instance is by its name: a value in an env or an instance's map by its key, a tag's or
  # a member's name, or an element's, `lane_t[2]`, read from its array and written into it,
  # every other element kept. Told by the key's last byte, which each clause's guard reads.
  defp key_fetch(map, key) when is_element_key(key) do
    {array, index} = element_key(key)
    element_fetch(Map.fetch(map, array), index)
  end

  defp key_fetch(map, key), do: Map.fetch(map, key)

  defp key_get(map, key) when is_element_key(key), do: unfetched(key_fetch(map, key))
  defp key_get(map, key), do: Map.get(map, key)

  defp key_put(map, key, value) when is_element_key(key) do
    {array, index} = element_key(key)
    Map.put(map, array, put_element(Map.fetch!(map, array), index, value))
  end

  defp key_put(map, key, value), do: Map.put(map, key, value)

  defp element_key(key) do
    {array, subscripts} = Logex.Array.split(key)
    {array, Enum.map(subscripts, &elem(Logex.Array.subscript(&1), 1))}
  end

  defp element_fetch({:ok, {@opened, value, changes}}, index),
    do: opened_fetch(Map.fetch(changes, index), value, index)

  defp element_fetch({:ok, value}, index) when is_tuple(value),
    do: {:ok, Logex.Array.fetch(value, index)}

  defp element_fetch(_none, _index), do: :error

  defp opened_fetch({:ok, element}, _value, _index), do: {:ok, element}
  defp opened_fetch(:error, value, index), do: {:ok, Logex.Array.fetch(value, index)}

  defp put_element({@opened, value, changes}, index, element),
    do: {@opened, value, Map.put(changes, index, element)}

  defp put_element(value, index, element), do: Logex.Array.put(value, index, element)

  # M5-14's review: an array of instances a switch or a prune moves element by element is
  # opened for it, its elements' changes kept in a map beside the array as it was, and
  # closed after, the array built again once from its elements in their order where any
  # changed, so that moving each of n elements is linear in n, where a put into the tuple
  # for each copied the array each time, quadratic in wall time though linear in reductions,
  # which count a tuple's copy as about one. Only the plan's rules read an opened array,
  # through `key_fetch/2` and `key_put/3`, between `opened/2` and `closed/2`. A plan of no
  # array of instances opens none, and pays one empty list's match a step.
  defp opened(map, []), do: map
  defp opened(map, arrays), do: Enum.reduce(arrays, map, &open/2)

  defp open(array, map), do: open_in(Map.fetch(map, array), array, map)

  defp open_in({:ok, value}, array, map) when is_tuple(value),
    do: Map.put(map, array, {@opened, value, %{}})

  defp open_in(_none, _array, map), do: map

  defp closed(map, []), do: map
  defp closed(map, arrays), do: Enum.reduce(arrays, map, &close/2)

  defp close(array, map), do: close_in(Map.fetch(map, array), array, map)

  defp close_in({:ok, {@opened, value, changes}}, array, map),
    do: Map.put(map, array, rebuilt(value, changes))

  defp close_in(_not_opened, _array, map), do: map

  defp rebuilt(value, changes) when map_size(changes) == 0, do: value

  defp rebuilt(value, changes) do
    dims = dims_of(value)

    Logex.Array.indexes(dims)
    |> Enum.zip_with(Logex.Array.to_flat(value, dims), &Map.get(changes, &1, &2))
    |> Logex.Array.from_flat(dims)
  end

  # An array of instances' sizes, from its value: each element is a map, never a tuple.
  defp dims_of(value) when is_tuple(value), do: [tuple_size(value) | dims_of(elem(value, 0))]
  defp dims_of(_element), do: []

  # The arrays a plan's entries name an element of, each once, in the order first named.
  defp opens(names),
    do: Enum.uniq(for(name <- names, is_element_key(name), do: held_under(name)))

  defp unfetched({:ok, value}), do: value
  defp unfetched(:error), do: nil

  # The tag or member a key's value is held under, an element's its array's.
  defp held_under(key) when is_element_key(key), do: elem(element_key(key), 0)
  defp held_under(key), do: key

  # Where `.pre` goes. F1 first: still what this edit's last switch left, it goes back to
  # what that switch found. Otherwise, decision 23: a timer the program started runs no
  # `ton` on keeps its `.pre` frozen, and one it runs that the program stopped did not
  # takes its preset outright. And where both run one: a `.pre` still at the old preset
  # takes the new one, and one logic changed is kept, read when the switch is taken, not
  # at accept (decision 27).
  defp target({pre, found, _last}, pre, _from, _to), do: found
  defp target(_undo, pre, _from, nil), do: pre
  defp target(_undo, _pre, nil, to), do: to
  defp target(_undo, from, from, to), do: to
  defp target(_undo, pre, _from, _to), do: pre

  # What a switch reports of `.pre`: a move, with what it does to `.dn` where the program
  # started runs the timer; or, where `.pre` stays on a timer that program runs, a `.pre`
  # that is not its preset.
  defp moved(_name, {pre, pre, nil}, _value, _rules), do: []
  defp moved(_name, {pre, pre, pre}, _value, _rules), do: []
  defp moved(name, {pre, pre, to}, _value, _rules), do: [{:preset_kept, name, {pre, to}}]

  defp moved(name, {pre, target, to}, value, rules),
    do: [{:preset, name, {pre, target}} | done(to, value, name, rules)]

  # F6: `.dn` is `.acc` against `.pre`, with no latch (docs/naming.md, `ton`), so after a
  # move it drops at the next scan with its rung true, unless `.pre` - `.acc` ms pass by
  # then, or rises at that scan, where it is timing. Each counted as `ton` counts it, a
  # negative `.acc` as 0. A moved `.pre` is never negative where the program started runs
  # the timer: a switch moves it to a preset, or back from one.
  # M3-1: by the type's kind; M3-2, by the rule its forecast follows (Logex.FbType.rules/1).
  defp done(nil, _value, _name, _rules), do: []

  defp done(
         _to,
         %{"pre" => pre, "acc" => acc, "dn" => dn, "en" => en},
         name,
         %{forecast: :on_delay}
       ),
       do: done(dn, en, max(acc, 0), pre, name)

  # M3-1 (decision 88): a counter's done member, `q` or a ctud's `qu`, is `cv >= pv` at its
  # next run, whatever its rung, against the `cv` that run leaves, so the forecast holds
  # unless that run counts, resets or loads. A ctd's `q`, `cv <= 0`, moves with no preset.
  # M3-2: a `tof`'s `.dn` changes with its preset while its delay runs (`.tt` 1): there its
  # next run ends the delay where `.acc` is at or past the new `.pre`, dropping `.dn`, unless
  # that run finds its rung true, which keeps `.dn` set. And where its rung was true at its
  # last run (`.en` 1), a `.pre` moved to 0 ends the delay on the falling edge's own scan, so
  # `.dn` drops at its next run with its rung false, however many runs with its rung true
  # come first (decision 93), as a `ton`'s and an `rto`'s forecasts are for a run with its
  # rung true. `.en` is read with `Map.get/2`, as the runtime reads it.
  defp done(_to, %{"pre" => pre, "acc" => acc, "tt" => tt} = value, name, %{forecast: :off_delay}),
       do: off_delay({tt, Map.get(value, "en")}, max(acc, 0), pre, name)

  # M3-2: a `tp`'s `.pre` moves its pulse only while it runs (`.tt` 1): there its next run
  # ends the pulse where `.acc` is at or past the new `.pre`, `.dn` rising, unless that run
  # finds its rung false, when `.dn` stays 0 as the pulse ends (decision 94).
  defp done(_to, %{"pre" => pre, "acc" => acc, "tt" => tt}, name, %{forecast: :pulse}),
    do: pulse_ends(tt, max(acc, 0), pre, name)

  # M3-2: an `rto`'s `.dn` is set again only at a run with its rung true, since a false rung
  # keeps it, so its forecast is at its next run with its rung true: a drop where `.dn` is 1
  # and `.acc` below the new `.pre`, unless at least `.pre` - `.acc` ms of true rung pass by
  # then, and a rise where `.dn` is 0 and `.acc` at or past it, whatever `.en`, unless that
  # run finds `r` set (decision 95).
  defp done(_to, %{"pre" => pre, "acc" => acc, "dn" => dn}, name, %{forecast: :retentive}),
    do: retentive(dn, max(acc, 0), pre, name)

  defp done(_to, value, name, %{forecast: :count, done: member, preset: preset})
       when is_binary(member),
       do: counted(Map.get(value, member), Map.get(value, "cv"), Map.get(value, preset), name)

  defp done(_to, _value, _name, %{forecast: :count}), do: []

  defp off_delay({1, _en}, acc, pre, name) when acc >= pre, do: [{:dn_drops, name, {acc, pre}}]
  defp off_delay({0, 1}, acc, pre, name) when pre <= 0, do: [{:dn_drops, name, {acc, pre}}]
  defp off_delay(_timing, _acc, _pre, _name), do: []

  defp pulse_ends(1, acc, pre, name) when acc >= pre, do: [{:dn_rises, name, {acc, pre}}]
  defp pulse_ends(_tt, _acc, _pre, _name), do: []

  defp retentive(1, acc, pre, name) when acc < pre, do: [{:dn_drops, name, {acc, pre}}]
  defp retentive(0, acc, pre, name) when acc >= pre, do: [{:dn_rises, name, {acc, pre}}]
  defp retentive(_dn, _acc, _pre, _name), do: []

  defp counted(1, cv, pv, name) when is_integer(cv) and cv < pv, do: [{:dn_drops, name, {cv, pv}}]

  defp counted(0, cv, pv, name) when is_integer(cv) and cv >= pv,
    do: [{:dn_rises, name, {cv, pv}}]

  defp counted(_done, _cv, _pv, _name), do: []

  defp done(1, _en, acc, pre, name) when acc < pre, do: [{:dn_drops, name, {acc, pre}}]
  defp done(0, 1, acc, pre, name) when acc >= pre, do: [{:dn_rises, name, {acc, pre}}]
  defp done(_dn, _en, _acc, _pre, _name), do: []

  # A timer the program started runs and the program stopped does not, timing when it last
  # ran (`.en` 1, its `last` before `now`), resumes from the switch: its `last` becomes
  # `now`, so the time no `ton` ran it is not caught up (§4.9's Resume rule, decision 23).
  # The `last` it found is returned too, for the next switch to give back (F11). M2-5: a
  # timer both programs run is never resumed. Its `last` is `now` where the last scan ran
  # its instruction, which stamps it at every run; inside a block whose `cal` was false, or
  # since M3-5 on a rung a jump skipped, it is earlier, and the timer catches up when it
  # next runs, as decisions 8 and 82 want. And "the program stopped did not run it" is
  # asked of the program that last scanned, as the one-shots' rule asks it (F3): where
  # that is the program started, a test and an untest with no scan between, the program
  # started left the timer as it is, frozen or not, and no resume is due.
  #
  # M3-1: a timer's, by its kind (Logex.FbType.rules/1): a type that keeps no time has no
  # `last` to resume. M3-2: "timing" is the member the type's rules name, `times`, at 1.
  defp resumed({nil, to, true}, timer, name, {now, %{kind: :timer, times: times}})
       when to != nil,
       do: resume(Map.get(timer, times), timer, name, now)

  defp resumed(_presets, timer, _name, _at), do: {timer, [], nil}

  defp resume(1, %{"last" => last} = timer, name, now) when last < now,
    do: {%{timer | "last" => now}, [{:resumed, name, now - last}], last}

  defp resume(_timing, timer, _name, _now), do: {timer, [], nil}

  # A resume undone: where this edit's last switch resumed the timer and no scan has run
  # since (`switched`), its `last`, still that switch's `now`, goes back to the one it
  # found, so a test and an untest with no scan between leave the original's timers as
  # they were. The `last` found is in the edit's record, so an earlier edit's is unknown.
  defp undone(%{"last" => now} = timer, {_pre, _found, last}, true, now, name)
       when is_integer(last),
       do: {%{timer | "last" => last}, [{:resume_undone, name, now - last}]}

  defp undone(timer, _undo, _switched, _now, _name), do: {timer, []}

  # What the points of `outputs`, the watched outputs of the program the step stops, hold,
  # learnt from the state while that program is the one that last scanned (F4). A restart
  # since that scan cleared what it showed, so it is forgotten; with no scan since the last
  # switch, no point has changed.
  defp learnt(shown, outputs, %Instance{switched: false, first: false, env: env}),
    do: Map.merge(shown, Map.new(outputs, &{&1, Map.get(env, &1, 0)}))

  defp learnt(shown, outputs, %Instance{switched: false, first: true}),
    do: Map.drop(shown, outputs)

  defp learnt(shown, _outputs, %Instance{switched: true}), do: shown

  # Each held output with its value: for one the program that runs next still shows, the
  # state's, which that program's next scan gives the host, since no logic of it writes
  # the output, and which can differ from what the point holds until that scan; otherwise
  # what the point last received, if the edit has learnt it.
  defp holding(plan, shown, env),
    do:
      for(
        name <- plan.held,
        {:ok, value} <- [holds(name, plan.shows, shown, env)],
        do: {:held, name, host(plan, name, value)}
      )

  defp holds(name, shows, _shown, env) when is_map_key(shows, name),
    do: {:ok, Map.get(env, name, 0)}

  defp holds(name, _shows, shown, _env), do: Map.fetch(shown, name)

  # Assemble and cancel: the state pruned to the tags of the program kept, `to`, which ran
  # last, and its direction's held outputs. Nothing is learnt here: a held output the kept
  # program does not show is none of its outputs, so no scan since the switch changed its
  # point, and the record has the value.
  def prune(plan, record, %Instance{env: env} = state) do
    {kept, gone} = Map.split_with(env, fn {name, _value} -> is_map_key(plan.keep, name) end)
    pruned = for {name, value} <- gone, do: {:pruned, name, value}
    {kept, inside} = Enum.reduce(plan.nested, {opened(kept, plan.opens), []}, &prune_in/2)
    kept = closed(kept, plan.opens)
    {%{state | env: kept}, Enum.sort(holding(plan, record.shown, env) ++ pruned ++ inside)}
  end

  # M2-5: inside each instance of a user block the program kept declares, the members its
  # version of the block does not declare, at any depth, each reported by its path.
  defp prune_in({name, plan}, {env, reports}),
    do: pruned_in(key_get(env, name), {name, plan}, {env, reports})

  defp pruned_in(%{} = map, {name, plan}, {env, reports}) do
    {map, reports} = prune_members(plan, map, name, reports)
    {key_put(env, name, map), reports}
  end

  defp pruned_in(_not_a_map, _plan, acc), do: acc

  defp prune_members(plan, map, prefix, reports) do
    {kept, gone} = Map.split_with(map, fn {name, _value} -> is_map_key(plan.names, name) end)

    reports =
      Enum.reduce(gone, reports, fn {name, v}, acc ->
        [{:pruned, prefix <> "." <> name, v} | acc]
      end)

    {kept, reports} =
      Enum.reduce(plan.members, {opened(kept, plan.opens), reports}, fn
        {:block, name, _initial, _kept?, inner}, {kept, reports} ->
          nested_prune(key_get(kept, name), {name, prefix <> "." <> name, inner}, {kept, reports})

        _member, acc ->
          acc
      end)

    {closed(kept, plan.opens), reports}
  end

  defp nested_prune(%{} = inner, {name, path, plan}, {map, reports}) do
    {inner, reports} = prune_members(plan, inner, path, reports)
    {key_put(map, name, inner), reports}
  end

  defp nested_prune(_not_a_map, _plan, acc), do: acc
end
