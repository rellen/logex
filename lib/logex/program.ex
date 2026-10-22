defmodule Logex.Program do
  @moduledoc """
  A compiled program: a program *type* in IEC's terms, named and stateless. Every instance
  of it keeps its own state (`Logex.Runtime`), so one program can run as many instances.

  - `name` is set by `Logex.compile/2` and `Logex.compile_file/1`; it is nil only for a
    program built by `Logex.Compiler.instructionize/2` directly, or by hand.
  - `source` is the text it was compiled from, when it came through `Logex.compile*`. A
    block's body must be the one its text compiles to, wherever the block's type is given
    (decision 54; `Logex.FbType.user?/1`), so it is compiled again from this text.
  - `file` is the path `Logex.compile_file/1` read it from, and nil for a program from
    text (fix F15): a diagnostic about it that cites a line, such as an online edit's
    (`Logex.Edit`), cites that file too. A block's body read from a file keeps the path,
    a file named after the block, and each of its warnings carries it.
  - `rungs` are the lowered rungs. Declaration lines are rungs in the parse AST, but never
    here.
  - `tags` is the tag table, keyed by tag name.
  - `blocks` is the one table of the user block types the program holds (decision 53):
    every type its instances are of, at any depth, once, by name, each held with no table
    of its own (`Logex.FbType.held/1`), and every instance's tag, at any depth, names its
    type, `{:block, name}` (`docs/organisation.md` §4.10, "Held types"). A block's compiled
    body, the outermost type's, holds the table of that type so. So a program or a type
    copied flat grows with the number of distinct types it holds, whatever the shape of
    its nesting, and `typed_tags/1` gives the tag table with each type itself. The
    built-in `ton` is in no table: each timer's tag holds it.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`, in line order. From
    `Logex.compile_file/1` the warnings of each block it loaded beside the file follow,
    each with its block's file (decision 34); a block's body holds only its own.
  """

  import Logex.Declarations, only: [is_elementary: 1]

  @enforce_keys [:rungs, :tags]
  defstruct [:rungs, :tags, name: nil, source: nil, file: nil, warnings: [], blocks: %{}]

  @type t :: %__MODULE__{
          rungs: [{:rung, list}],
          tags: %{String.t() => Logex.Tag.t()},
          blocks: %{String.t() => Logex.FbType.t()},
          name: String.t() | nil,
          source: String.t() | nil,
          file: String.t() | nil,
          warnings: [Logex.Diagnostic.t()]
        }

  @doc """
  The first env: every declared tag at its initial value, 0 when none was declared, and
  every instance of a function block a map of its members at theirs (M1-6).

  An instance of a user function block (M2-5) starts as its type says, every member at its
  initial value and every instance it holds at its own, at any depth (`Logex.FbType`). The
  tags are read through `typed_tags/1`, since each instance's tag names its type, which
  the program's `blocks` holds (decision 53), and so are a block's compiled body's, which
  runs as a program too.

  The one rule for a new piece of state (`docs/organisation.md` §4.9):
  `Logex.Runtime.instance/1` and `restart/3` start every tag by it, an online edit's
  switch (`Logex.Edit`) starts each tag it adds by it, and `Logex.Runtime.start/1` and
  `restart/2` start every program instance of a configuration by it, through `instance/1`
  and `restart/3`. The edit's exceptions, for state an instance already holds around the
  new piece: `first` stays false; an `ons` the edit adds or changes is blocked for one
  scan by the instance's `ons_blocked`, where a new instance relies on `first`, and so is
  a counter's edge memory, `cu` or `cd`, whose instruction the edit adds or whose rung it
  changes, by its path, so its next run counts no edge (M3-1), and a `tp`'s, `.en`, so its
  next run starts no pulse (M3-2), and an `osr`'s or an `osf`'s storage bit, whose coil the
  edit adds or whose rung it changes, as an `ons`'s is, so its next run sets no pulse
  (M3-4); a var_input a switch
  starts or makes live is reported, since its value is the host's; at
  the first test, a tag the candidate adds, or one whose value does not fit its type,
  starts here over what a plain swap left; and a kept bool or integer whose initial value
  changed keeps its value until a restart, and is reported as `:initial_changed`, except
  one the switch starts here, at its new initial value, and a var_input of the program
  started, whose value a restart keeps: neither is so reported. An event task's trigger, its
  last sample, is a resource's state, not a tag's, its rule in `Logex.Runtime`'s (M2-6).
  """
  def initial_env(%__MODULE__{} = program),
    do: Map.new(typed_tags(program), fn {name, tag} -> {name, start(tag)} end)

  defp start(%Logex.Tag{type: %Logex.FbType{} = type, initial: nil}),
    do: Logex.FbType.initial(type)

  # A timer's preset, from the `ton` that runs it (Logex.Compiler), is its `pre` to start.
  defp start(%Logex.Tag{type: %Logex.FbType{} = type, initial: inputs}),
    do: Logex.FbType.initial(type, inputs)

  defp start(%Logex.Tag{type: type, initial: nil}) when is_elementary(type),
    do: Logex.Declarations.zero(type)

  defp start(%Logex.Tag{initial: nil}), do: 0
  defp start(%Logex.Tag{initial: initial}), do: initial

  @doc """
  The tag table with each instance's type itself: every tag that names a type the table
  `blocks` holds, `{:block, name}`, given that type as it reads inside the program
  (`Logex.FbType.within/2`), and every other tag as it is (M2-5, decision 53). It is the
  table a compile works over, which the walks that read an instruction's slots
  (`Logex.Compiler.signature/2`, `Logex.Warnings.of/2`), the runtime and an edit take.
  Its tags share each type and the one table, so it costs one entry per tag, and no copy of
  a type. A name `blocks` lacks, or `blocks` that are no map, which only a program built
  by hand can give, is left as it is.
  """
  def typed_tags(%__MODULE__{tags: tags, blocks: blocks}),
    do: Map.new(tags, fn {name, tag} -> {name, typed(tag, blocks)} end)

  defp typed(%Logex.Tag{type: {:block, name}} = tag, blocks) when is_map(blocks),
    do: held(Map.fetch(blocks, name), tag, blocks)

  defp typed(tag, _blocks), do: tag

  defp held({:ok, %Logex.FbType{body: %__MODULE__{}} = type}, tag, blocks),
    do: %{tag | type: Logex.FbType.within(type, blocks)}

  defp held(_not_held, tag, _blocks), do: tag

  # Decision 182: the instructions that compute in their destination's type (M5-4,
  # decision 147), each writing its last operand.
  @computing [:add, :sub, :mul, :div, :mod, :neg, :abs]

  @doc """
  The type an arithmetic instruction computes in, its destination's, in the tag table of
  the routine that holds it: a tag's, or a member's of the built-in instance that holds
  it, the one kind of member logic outside a block writes (M5-4, decision 147). `{:ok,
  type}` where that type is an integer, as every compile gives; otherwise `{:error, what}`,
  what the destination is, which only a program edited by hand after it compiled gives,
  and which `unwritable/1` refuses where the program is handed in (decision 182). It is
  the one rule the runtime's scan and that check read.
  """
  def destination({:name, _, name}, tags), do: tag_destination(Map.fetch(tags, name), name)

  def destination({:member, _, [instance, member]}, tags),
    do: instance_destination(Map.fetch(tags, instance), instance, member)

  def destination(_no_tag, _tags), do: {:error, :no_tag}

  defp tag_destination({:ok, %Logex.Tag{type: type}}, name), do: integer(type, name)
  defp tag_destination(:error, _name), do: {:error, :undeclared}

  defp instance_destination({:ok, %Logex.Tag{type: %Logex.FbType{body: nil} = type}}, i, m),
    do: member_destination(Logex.FbType.member(type, m), type, "#{i}.#{m}")

  defp instance_destination({:ok, %Logex.Tag{type: type}}, instance, _member),
    do: {:error, {:instance, instance, type}}

  defp instance_destination(:error, instance, _member), do: {:error, {:no_instance, instance}}

  defp member_destination({:ok, %Logex.FbType.Member{type: type}}, _owner, path),
    do: integer(type, path)

  defp member_destination(:error, owner, _path), do: {:error, {:no_member, owner}}

  # The integer types, the one table's (Logex.Declarations.integers/0), read once here.
  @integers Logex.Declarations.integers()

  defp integer(type, _name) when type in @integers, do: {:ok, type}
  defp integer(type, _name), do: {:error, {:type, type}}

  @doc """
  Decision 182: a line for each arithmetic instruction of `program`, or of a block's body
  it holds, whose destination has no integer type (`destination/2`), in rung order, the
  program's first and then each body's, by the block's name: what no compile gives, so a
  program edited by hand after it compiled, its destination's tag retyped or taken out of
  the table. `[]` for every program a compile gives. One walk of the program's rungs and
  of each body once: a body in the program's one table of block types (decision 53), and
  one a tag of a routine walked holds as its type itself, which only a program built by
  hand does.
  """
  def unwritable(%__MODULE__{name: name} = program) do
    {lines, _seen} = routine(program, {name, nil}, {[], MapSet.new()})
    Enum.reverse(lines)
  end

  defp routine(%__MODULE__{rungs: rungs, tags: tags, blocks: blocks}, where, {lines, seen})
       when is_list(rungs) and is_map(tags) do
    {program, _block} = where
    {lines, called} = rungs(rungs, {tags, where}, {lines, []})
    acc = Enum.reduce(Enum.reverse(called), {lines, seen}, &once(&1, program, &2))
    held_bodies(blocks, program, acc)
  end

  defp routine(_not_a_routine, _where, acc), do: acc

  # Only a program's own table is walked: a held body's table is the program's (decision
  # 53), so a body names no table of its own to walk.
  defp held_bodies(%{} = blocks, program, acc),
    do: Enum.reduce(Enum.sort(blocks), acc, fn {_name, type}, acc -> once(type, program, acc) end)

  defp held_bodies(_no_table, _program, acc), do: acc

  defp once(%Logex.FbType{name: name, body: %__MODULE__{} = body}, program, {lines, seen} = acc),
    do:
      unseen(
        MapSet.member?(seen, body),
        body,
        {program, name},
        acc,
        {lines, MapSet.put(seen, body)}
      )

  defp once(_no_body, _program, acc), do: acc

  defp unseen(true, _body, _where, acc, _put), do: acc
  defp unseen(false, body, where, _acc, put), do: routine(%{body | blocks: nil}, where, put)

  # The walk itself, a clause an element, with no closure: a few reductions an
  # instruction, paid once a program since decision 190, where it is first handed in.
  defp rungs([{:rung, elements} | rest], at, lines),
    do: rungs(rest, at, elements(elements, at, lines))

  defp rungs([_not_a_rung | rest], at, lines), do: rungs(rest, at, lines)
  defp rungs(_end, _at, lines), do: lines

  defp elements([{:branches, legs} | rest], at, lines),
    do: elements(rest, at, legs(legs, at, lines))

  defp elements([{symbol, line, [_ | _] = operands} | rest], {tags, where} = at, {lines, called})
       when symbol in @computing,
       do:
         elements(
           rest,
           at,
           {computes(
              destination(List.last(operands), tags),
              symbol,
              line,
              operands,
              where,
              lines
            ), called}
         )

  # A `cal` runs the body of the type its instance's tag holds: one named in the program's
  # table is walked with the table, and one a tag holds as itself, which only a program
  # built by hand gives, is walked where a `cal` runs it.
  defp elements([{:cal, _, [{:name, _, instance} | _]} | rest], {tags, _where} = at, acc),
    do: elements(rest, at, called(Map.get(tags, instance), acc))

  defp elements([_other | rest], at, lines), do: elements(rest, at, lines)
  defp elements(_end, _at, lines), do: lines

  defp legs([leg | rest], at, lines), do: legs(rest, at, elements(leg, at, lines))
  defp legs(_end, _at, lines), do: lines

  defp called(%Logex.Tag{type: %Logex.FbType{body: %__MODULE__{}} = type}, {lines, called}),
    do: {lines, [type | called]}

  defp called(_named_or_none, acc), do: acc

  defp computes({:ok, _type}, _symbol, _line, _operands, _where, lines), do: lines

  defp computes({:error, what}, symbol, line, operands, {program, _block} = where, lines),
    do: [
      "#{located(where)}`#{symbol}` on line #{line}#{within(where)} computes in the type of " <>
        "#{written(List.last(operands), what, where)}: #{named(program)} was edited by " <>
        "hand after it compiled"
      | lines
    ]

  defp located({nil, nil}), do: "an unnamed program's "
  defp located({program, nil}), do: "`#{program}`'s "
  defp located({_program, _block}), do: ""

  defp within({_program, nil}), do: ""
  defp within({_program, block}), do: " of `#{block}`'s body"

  defp named(nil), do: "the program"
  defp named(program), do: "`#{program}`"

  defp written(destination, :undeclared, where),
    do: "#{shown(destination)}, which #{declarer(where)} does not declare"

  defp written(destination, :no_tag, _where), do: "#{shown(destination)}, which is no tag"

  defp written(destination, {:type, type}, _where),
    do: "#{shown(destination)}, #{a(type)}, which is no integer type"

  defp written(destination, {:no_instance, instance}, where),
    do: "#{shown(destination)}, and #{declarer(where)} declares no `#{instance}`"

  defp written(destination, {:instance, instance, type}, _where),
    do: "#{shown(destination)}, and `#{instance}` is #{a(type)}, not a built-in's instance"

  defp written({:member, _, [_, member]} = destination, {:no_member, type}, _where),
    do: "#{shown(destination)}, and #{a(type)} has no `#{member}`"

  # Decision 190: what a scan of a program edited by hand after its check is told of a
  # destination it reaches, in the words above.
  @doc false
  def met(destination, what), do: written(destination, what, {nil, nil})

  defp declarer({program, nil}), do: named(program)
  defp declarer({_program, _block}), do: "the body"

  defp shown({:name, _, name}), do: "`#{name}`"
  defp shown({:member, _, path}), do: "`#{Enum.join(path, ".")}`"
  defp shown(other), do: "`#{inspect(other)}`"

  defp a(%Logex.FbType{} = type), do: Logex.Declarations.instance_of(type)
  defp a({:block, name}) when is_binary(name), do: "an instance of `#{name}`"
  defp a(type) when is_atom(type), do: Logex.Declarations.a_type(type)
  defp a(other), do: inspect(other)
end
