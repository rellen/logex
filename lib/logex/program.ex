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
  - `units` (decision 197) is what each millisecond of the clock adds to the `acc` of
    each timer whose unit is not the millisecond, by the timer's name: 1,000,000 for a
    long timer, `ton_ltime` and its kind, counted in nanoseconds, and nothing for a plain
    timer, counted in ms; nil, the default, where the routine holds no such timer. The
    compiler settles it once from the tag table, `units/1`, the one rule, so that a scan
    reads it with the routine it runs, and a timer of a routine whose `units` are nil, every
    routine of plain timers, runs with no look-up, as it did before long timers; a
    block's body holds its own.
  - `reals` (M5-10) is the type of each tag of the routine that is a real, `real` or
    `lreal`, by its name, nil, the default, where it holds none, as `units` is: settled
    once from the tag table, `reals/1`, the one rule, so that a `move` or a `cal`'s
    copy-out into a real, which writes the real's nearest value (decision 150), finds its
    type with the routine it runs, and a routine of no real runs them as it did before
    reals; a block's body holds its own.
  - `arrays` (M5-11, decision 151) is the type of each tag of the routine that is an array,
    `{:array, type, dims}`, by its name, nil, the default, where it holds none, as `reals`
    is: settled once from the tag table with `units` and `reals`, so that the runtime,
    which holds an array's value as a tuple and a host's as a list, takes a host's inputs
    and gives its outputs as it did before arrays where a program holds none. An array of
    reals is among the `reals` too, by its name, so that a write into one of its elements
    writes the real's nearest value.
  - `retained` (M6-1, `docs/organisation.md` §4.13, decisions 269 and 270) is each path a
    warm restart keeps, in order, nil, the default, where there is none: a tag whole, `count`
    or `weights`, an instance whole, `boxes`, where every member of it is retained, and
    otherwise each retained member's path, `s1.count`, an array of a user block's instances
    `gates[*].count` for that member of every element. A member is retained by the nearest
    qualifier on its path, from the member outward through each enclosing instance's
    declaration line to the program's own tag, none meaning not retained (decision 270); a
    built-in's members follow their instance. The compiler settles it once from the tag
    table, `retained/1`, the one rule, so that a program that marks nothing pays nothing; a
    block's body holds its own.
  - `warnings` are `%Logex.Diagnostic{severity: :warning}`, in line order. From
    `Logex.compile_file/1` the warnings of each block it loaded beside the file follow,
    each with its block's file (decision 34); a block's body holds only its own.
  """

  import Logex.Declarations, only: [is_elementary: 1]
  import Logex.Array, only: [is_array: 1]

  @reals Logex.Declarations.reals()

  @enforce_keys [:rungs, :tags]
  defstruct [
    :rungs,
    :tags,
    name: nil,
    source: nil,
    file: nil,
    warnings: [],
    blocks: %{},
    units: nil,
    reals: nil,
    arrays: nil,
    retained: nil
  ]

  @type t :: %__MODULE__{
          rungs: [{:rung, list}],
          tags: %{String.t() => Logex.Tag.t()},
          blocks: %{String.t() => Logex.FbType.t()},
          units: nil | %{String.t() => pos_integer},
          reals: nil | %{String.t() => :real | :lreal},
          arrays: nil | %{String.t() => {:array, atom, [pos_integer]}},
          retained: nil | [String.t()],
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

  **The rule beside it for a retained path** (M6-2, `docs/organisation.md` §4.13,
  decisions 266, 270, 271 and 273): at a warm restart, `Logex.Runtime.restart/3` and
  `restart/2` with `:warm`, a path the program retains (`retained`) keeps its value, which
  the state handed in holds and fits, a retained timer's `last` set to the instance's
  `now`, its last scan's (decision 188); every other path starts by this rule, as at a cold restart, the var_inputs kept
  as ever. A path nothing marks is not retained, so a program that marks nothing restarts
  warm exactly as cold. Since M6-4 (decisions 273, 277 and 282) the same rule starts an
  instance from a retained image, `Logex.Runtime.instance/2` and `start/2`: a retained
  path keeps the image's value where it fits, of exactly its type under instances of the
  stored kinds, an integer for a real at its nearest real (decision 311), and otherwise
  starts by this rule, a retained timer's `last` at the start's `now`; and since decision
  308 a timer's or counter's preset starts by this rule whatever the image holds, the
  number on the instruction that runs it, as an edit's switch moves it. An online edit's switch writes no value for a qualifier (decision
  278, M6-7).
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

  # M5-11 (decision 151): an array is a tuple, a tuple of tuples for more dimensions, each
  # element at its type's zero or at its initial list's value, in the elements' order, a
  # real's held at its nearest.
  # M5-14 (decision 154): an array of instances, each element an instance at its type's
  # start, its preset the one the compiler gave it by its index (`Logex.FbType.started/2`).
  defp start(%Logex.Tag{type: {:array, %Logex.FbType{}, _} = type, initial: initial}),
    do: Logex.FbType.started(type, initial)

  defp start(%Logex.Tag{type: {:array, _, _} = type, initial: initial}),
    do: Logex.Array.started(type, initial)

  defp start(%Logex.Tag{initial: nil}), do: 0

  # M5-10 (decision 150): a real's initial value is held as its nearest value, a `real`'s
  # rounded to a single, `var x real 0.1` starting at 0.10000000149011612, and an integer
  # one as the real it is, `var x real 0` at 0.0.
  defp start(%Logex.Tag{type: type, initial: initial}) when type in @reals,
    do: Logex.Real.nearest(type, initial)

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

  # M5-14 (decision 154): an array of instances of a user block names its type so too,
  # `{:array, {:block, name}, dims}`, given its elements' type itself.
  defp typed(%Logex.Tag{type: {:array, {:block, name}, dims}} = tag, blocks) when is_map(blocks),
    do: held_array(Map.fetch(blocks, name), tag, {blocks, dims})

  defp typed(tag, _blocks), do: tag

  defp held({:ok, %Logex.FbType{body: %__MODULE__{}} = type}, tag, blocks),
    do: %{tag | type: Logex.FbType.within(type, blocks)}

  defp held(_not_held, tag, _blocks), do: tag

  defp held_array({:ok, %Logex.FbType{body: %__MODULE__{}} = type}, tag, {blocks, dims}),
    do: %{tag | type: {:array, Logex.FbType.within(type, blocks), dims}}

  defp held_array(_not_held, tag, _at), do: tag

  # Decision 182: the instructions that compute in their destination's type (M5-4,
  # decision 147), each writing its last operand.
  @doc false
  # The name of the user block type a compiled table's tag holds instances of, `{:block,
  # name}` or since M5-14 an array of them, `{:array, {:block, name}, dims}`, or nil for any
  # other type (decision 53).
  def held_name({:block, name}), do: name
  def held_name({:array, {:block, name}, _dims}), do: name
  def held_name(_type), do: nil

  @computing [:add, :sub, :mul, :div, :mod, :neg, :abs]
  # M5-10: `sqrt`, which computes in its destination's type, always a real.
  @rooting [:sqrt]

  # M5-8 (decisions 147 and 155): the bitwise instructions, which compute in their
  # destination's type too, an integer's or a bit string's, each writing its last operand.
  @bitwise [:and, :or, :xor, :not, :shl, :shr, :rol, :ror]

  @doc """
  The type an arithmetic instruction computes in, its destination's, in the tag table of
  the routine that holds it: a tag's, or a member's of the built-in instance that holds
  it, the one kind of member logic outside a block writes (M5-4, decision 147). `{:ok,
  type}` where that type is an integer, as every compile gives; otherwise `{:error, what}`,
  what the destination is, which only a program edited by hand after it compiled gives,
  and which `edited_by_hand/1` refuses where the program is handed in (decision 182). It is
  the one rule the runtime's scan and that check read.
  """
  def destination(destination, tags), do: destination(destination, tags, :arithmetic)

  @doc """
  The type an instruction of `kind` computes in, its destination's, by the rule of
  `destination/2`: `:arithmetic`, an integer type, and since M5-8 `:bitwise`, the type of
  a bitwise instruction's destination, an integer or a bit string (decision 155), and since
  decision 206 a bool, a bit `status.3` among them, `{:error, {:bits, type}}` for any other.
  """
  def destination({:name, _, name}, tags, kind),
    do: tag_destination(Map.fetch(tags, name), kind)

  def destination({:member, _, [instance, member]}, tags, kind),
    do: instance_destination(Map.fetch(tags, instance), {instance, member}, kind)

  # Decision 206: a bit of a tag or member, `status.3`, is a bool, which a bitwise
  # instruction computes in and an arithmetic one never does.
  # M5-14 (decision 154): a member of an element of an array of built-in instances, the
  # member's type, `lane_c[1].pv` an int's for a `ctu_int`.
  def destination({:member, _, element, [member]}, tags, kind),
    do:
      instance_destination(
        element_instance(Map.fetch(tags, elem(element, 2))),
        {elem(element, tuple_size(element) - 1), member},
        kind
      )

  def destination({:bit, _, _path, _n, _mask, _name}, _tags, kind), do: computing(:bool, kind)

  # M5-9: so is a bit whose number a tag holds, `status.[n]` (decision 160).
  def destination({:bit_at, _, _path, _index, _width, _name}, _tags, kind),
    do: computing(:bool, kind)

  # M5-11 (decision 151): an element computes in its array's elements' type.
  def destination({:element, _, array, _index, _name}, tags, kind),
    do: element_destination(Map.fetch(tags, array), kind)

  # M5-12: so does an element a tag subscripts.
  def destination({:element_at, _, array, _index, _dims, _name}, tags, kind),
    do: element_destination(Map.fetch(tags, array), kind)

  def destination(_no_tag, _tags, _kind), do: {:error, :no_tag}

  defp element_instance({:ok, %Logex.Tag{type: {:array, type, _dims}} = tag}),
    do: {:ok, %{tag | type: type}}

  defp element_instance(_no_array), do: :error

  defp element_destination({:ok, %Logex.Tag{type: {:array, type, _dims}}}, kind),
    do: computing(type, kind)

  defp element_destination({:ok, %Logex.Tag{type: type}}, _kind),
    do: {:error, {:not_an_array, type}}

  defp element_destination(:error, _kind), do: {:error, :undeclared}

  defp tag_destination({:ok, %Logex.Tag{type: type}}, kind), do: computing(type, kind)
  defp tag_destination(:error, _kind), do: {:error, :undeclared}

  defp instance_destination(
         {:ok, %Logex.Tag{type: %Logex.FbType{body: nil} = type}},
         {_instance, member},
         kind
       ),
       do: member_destination(Logex.FbType.member(type, member), type, kind)

  defp instance_destination({:ok, %Logex.Tag{type: type}}, {instance, _member}, _kind),
    do: {:error, {:instance, instance, type}}

  defp instance_destination(:error, {instance, _member}, _kind),
    do: {:error, {:no_instance, instance}}

  defp member_destination({:ok, %Logex.FbType.Member{type: type}}, _owner, kind),
    do: computing(type, kind)

  defp member_destination(:error, owner, _kind), do: {:error, {:no_member, owner}}

  # The integer types, the one table's (Logex.Declarations.integers/0), read once here,
  # and since M5-8 the bit strings, which a bitwise instruction computes in too.
  @integers Logex.Declarations.integers()
  @bit_strings Logex.Declarations.bit_strings()

  defp computing(type, _kind) when type in @integers, do: {:ok, type}
  # M5-10: a real, which the arithmetic computes in, and `sqrt`'s destination always.
  defp computing(type, kind) when type in @reals and kind in [:arithmetic, :real], do: {:ok, type}
  defp computing(type, :real), do: {:error, {:real, type}}
  defp computing(type, :bitwise) when type in @bit_strings, do: {:ok, type}
  defp computing(:bool, :bitwise), do: {:ok, :bool}
  defp computing(type, :arithmetic), do: {:error, {:type, type}}
  defp computing(type, :bitwise), do: {:error, {:bits, type}}

  @doc """
  Decision 197: a timer's unit, what each millisecond of the clock adds to its `acc`, for
  each timer of `tags` whose unit is not the millisecond, by its name: its type's
  `per_ms` (`Logex.FbType.rules/1`), 1,000,000 for a long timer, or nil where there is
  none. A plain timer, counted in ms, and every other tag are left out. The one rule for a program's `units`, which the
  compiler gives every program and body it builds, and the check below holds a program
  handed in to.
  """
  def units(tags) when is_map(tags), do: elem(settled(tags), 0)

  @doc """
  M5-11: the type of each tag of `tags` that is an array, by its name, or nil where there is
  none. The one rule for a program's `arrays`, which the compiler gives every program and
  body it builds, and the check below holds a program handed in to.
  """
  def arrays(tags) when is_map(tags), do: elem(settled(tags), 2)

  @doc """
  A routine's `units` and, since M5-10, its `reals`, and since M5-11 its `arrays`, `{units,
  reals, arrays}`, settled in one walk of its tags, the one rule for all three (`units/1`,
  `reals/1`, `arrays/1`), which the compiler gives every program and body it builds: an
  elementary tag is a real or nothing, an array an array and, of reals, a real, and an
  instance a timer of another unit or nothing.
  """
  def settled(tags) when is_map(tags) do
    {units, reals, arrays, _retained} = settled(tags, %{})
    {units, reals, arrays}
  end

  @doc """
  `settled/1` with, since M6-1, the routine's `retained` too, `{units, reals, arrays,
  retained}`, in the same one walk of its tags (`retained/2`), `blocks` the table a
  compiled tag's `{:block, name}` is read inside.
  """
  def settled(tags, blocks) when is_map(tags), do: settled_in(tags, held_in(blocks))

  # `at` is the table with its quiet names (quiet/1), made once a check (edited_by_hand/1).
  defp settled_in(tags, at) do
    {units, reals, arrays, retained, _at} = Enum.reduce(tags, {[], [], [], [], at}, &settle/2)
    {some(units), some(reals), some(arrays), listed(retained)}
  end

  defp held_in(blocks), do: {blocks, quiet(blocks)}

  # The common tag, elementary and unqualified, first, and passed over as before M6-1.
  defp settle({_name, %Logex.Tag{type: type, retain: nil}}, acc)
       when is_atom(type) and type not in @reals,
       do: acc

  defp settle({name, %Logex.Tag{type: type} = tag}, {units, reals, arrays, kept, blocks})
       when type in @reals,
       do: {units, [{name, type} | reals], arrays, own(tag.retain, name, kept), blocks}

  defp settle(
         {name, %Logex.Tag{type: {:array, element, _dims} = type} = tag},
         {units, reals, arrays, kept, blocks}
       )
       when element in @reals,
       do:
         {units, [{name, element} | reals], [{name, type} | arrays], own(tag.retain, name, kept),
          blocks}

  # M6-1: an instance nothing marks, of a built-in or of a block whose body keeps nothing,
  # keeps nothing, and is settled as before M6-1.
  defp settle({name, %Logex.Tag{type: %Logex.FbType{body: nil} = type, retain: nil}}, acc),
    do: unit(per_ms(Logex.FbType.rules(type)), name, acc)

  defp settle(
         {_name, %Logex.Tag{type: %Logex.FbType{body: %__MODULE__{retained: nil}}, retain: nil}},
         acc
       ),
       do: acc

  # M5-14 (decision 154): an array of instances is no host's value, so no array of
  # `arrays`, and its timers' unit, a long timer's, is its own under its name, each
  # element timing in it.
  # M6-2's review: one nothing marks, of a built-in or of a block whose body keeps
  # nothing, keeps nothing, and is settled as before M6-1.
  defp settle(
         {name, %Logex.Tag{type: {:array, %Logex.FbType{body: nil} = type, _}, retain: nil}},
         acc
       ),
       do: unit(per_ms(Logex.FbType.rules(type)), name, acc)

  defp settle(
         {name,
          %Logex.Tag{
            type: {:array, %Logex.FbType{body: %__MODULE__{retained: nil}} = type, _},
            retain: nil
          }},
         acc
       ),
       do: unit(per_ms(Logex.FbType.rules(type)), name, acc)

  defp settle({name, %Logex.Tag{type: {:array, %Logex.FbType{} = type, _dims}} = tag}, acc),
    do: instances_kept(tag, unit(per_ms(Logex.FbType.rules(type)), name, acc))

  # M6-2's review: so is a compiled program's instance of a block, `{:block, name}`, which
  # the check of a program handed in walks, passed over by a guard where its body retains
  # nothing, the held blocks that do not named once a routine (quiet/1), and walked
  # further only where it or the tag keeps anything, so that a program of unmarked blocks
  # is checked in no more than it was before M6-1.
  defp settle(
         {_name, %Logex.Tag{type: {:array, {:block, name}, _dims}, retain: nil}},
         {_, _, _, _, {_blocks, quiet}} = acc
       )
       when is_map_key(quiet, name),
       do: acc

  defp settle({_name, %Logex.Tag{type: {:array, {:block, _}, _dims}} = tag}, acc),
    do: instances_kept(tag, acc)

  defp settle({name, %Logex.Tag{type: type} = tag}, {units, reals, arrays, kept, blocks})
       when is_array(type),
       do: {units, reals, [{name, type} | arrays], own(tag.retain, name, kept), blocks}

  defp settle({name, %Logex.Tag{type: type} = tag}, {units, reals, arrays, kept, blocks})
       when is_atom(type),
       do: {units, reals, arrays, own(tag.retain, name, kept), blocks}

  defp settle(
         {_name, %Logex.Tag{type: {:block, name}, retain: nil}},
         {_, _, _, _, {_blocks, quiet}} = acc
       )
       when is_map_key(quiet, name),
       do: acc

  defp settle({_name, %Logex.Tag{type: {:block, _}} = tag}, acc), do: instances_kept(tag, acc)

  defp settle({name, %Logex.Tag{type: type} = tag}, acc),
    do: instances_kept(tag, unit(per_ms(Logex.FbType.rules(type)), name, acc))

  defp settle(_not_a_tag, acc), do: acc

  # The held blocks whose bodies retain nothing, by name, once a routine's settling.
  defp quiet(blocks) when map_size(blocks) == 0, do: blocks

  defp quiet(blocks),
    do:
      for(
        {name, %Logex.FbType{body: %__MODULE__{retained: nil}}} <- blocks,
        into: %{},
        do: {name, true}
      )

  defp unit(nil, _name, acc), do: acc

  defp unit(per_ms, name, {units, reals, arrays, kept, blocks}),
    do: {[{name, per_ms} | units], reals, arrays, kept, blocks}

  # M6-1: a tag of no instance is retained whole by its own qualifier alone.
  defp own(:retain, name, kept), do: [name | kept]
  defp own(_none, _name, kept), do: kept

  defp instances_kept(
         %Logex.Tag{name: name, type: type, retain: retain},
         {u, r, a, kept, {blocks, _quiet} = at}
       ),
       do: {u, r, a, kept(name, held_type(type, blocks), marked(retain, false)) ++ kept, at}

  defp some([]), do: nil
  defp some(units), do: Map.new(units)

  defp per_ms(%{per_ms: per_ms}) when is_integer(per_ms) and per_ms != 1, do: per_ms
  defp per_ms(_plain_or_no_timer), do: nil

  @doc """
  M6-1 (decisions 269 and 270): each path of `tags` a warm restart keeps, sorted, or nil
  where there is none, the one rule for a routine's `retained`, which the compiler gives
  every program and body it builds and the check below holds a program handed in to.
  `tags` is a typed tag table (`typed_tags/1`), each instance's type itself, so that a
  user block's members, and the types they hold, are read inside its table
  (`Logex.FbType.type_of/2`).

  The nearest qualifier on a path wins: a tag's own `retain`, else its enclosing
  instance's, else that one's, and so out to the program's tag, none meaning not
  retained. A path is listed whole where everything under it is retained, a tag, an
  array, a built-in instance, or a user block's instance or array of them none of whose
  members at any depth is kept out, and otherwise each retained member is listed, an
  element of an array of user block instances by `[*]`, `gates[*].count`.
  """
  def retained(tags, blocks \\ %{}) when is_map(tags), do: elem(settled(tags, blocks), 3)

  # `blocks` reads a compiled table's `{:block, name}` inside the table that holds it, as
  # typed_tags/1 does, for the check below, which walks a program's tags as they are.
  defp held_type({:block, name} = type, blocks),
    do: in_table(Map.fetch(blocks, name), type, blocks)

  defp held_type({:array, {:block, name}, dims} = type, blocks),
    do: in_array(in_table(Map.fetch(blocks, name), type, blocks), dims)

  defp held_type(type, _blocks), do: type

  defp in_table({:ok, %Logex.FbType{body: %__MODULE__{}} = type}, _named, blocks),
    do: Logex.FbType.within(type, blocks)

  defp in_table(_not_held, named, _blocks), do: named

  defp in_array(%Logex.FbType{} = type, dims), do: {:array, type, dims}
  defp in_array(named, _dims), do: named

  defp listed([]), do: nil
  defp listed(paths), do: Enum.sort(paths)

  defp marked(:retain, _held), do: true
  defp marked(:non_retain, _held), do: false
  defp marked(_none, held), do: held

  # An instance nothing outside marks keeps what its own body marks, the body's
  # `retained`, which its compile settled once and the check of the body holds it to, so
  # that a program of unmarked instances pays nothing for their depth; one an outer
  # qualifier retains is walked member by member, its own marks deciding.
  defp kept(path, %Logex.FbType{body: %__MODULE__{retained: retained}}, false),
    do: prefixed(retained, path <> ".")

  defp kept(path, {:array, %Logex.FbType{body: %__MODULE__{retained: retained}}, _dims}, false),
    do: prefixed(retained, path <> "[*].")

  defp kept(path, %Logex.FbType{body: %__MODULE__{}} = type, true),
    do: whole(members_kept(path <> ".", type, true), path)

  defp kept(path, {:array, %Logex.FbType{body: %__MODULE__{}} = type, _dims}, true),
    do: whole(members_kept(path <> "[*].", type, true), path)

  defp kept(path, _whole, true), do: [path]
  defp kept(_path, _whole, false), do: []

  defp prefixed(paths, prefix) when is_list(paths), do: Enum.map(paths, &(prefix <> &1))
  defp prefixed(_none, _prefix), do: []

  defp members_kept(prefix, type, held),
    do:
      Enum.map(type.members, fn member ->
        path = prefix <> member.name
        {path, kept(path, Logex.FbType.type_of(type, member), marked(member.retain, held))}
      end)

  # Everything under it retained, it is one path; otherwise each member's own.
  defp whole(members, path) do
    every = Enum.all?(members, fn {member, kept} -> kept == [member] end)
    whole_or(every, path, members)
  end

  defp whole_or(true, path, _members), do: [path]
  defp whole_or(false, _path, members), do: Enum.flat_map(members, &elem(&1, 1))

  @doc """
  M5-10: the type of each tag of `tags` that is a real, `real` or `lreal`, by its name, or
  nil where there is none. The one rule for a program's `reals`, which the compiler gives
  every program and body it builds, and the check below holds a program handed in to.
  """
  def reals(tags) when is_map(tags), do: elem(settled(tags), 1)

  @doc """
  What only a program edited by hand after it compiled holds, a line each: decision 182's
  arithmetic instruction whose destination has no integer type (`destination/2`), its
  destination's tag retyped or taken out of the table, and since decision 197 a routine
  whose `units` are not the ones its tags give (`units/1`), a long timer's left out, a
  plain timer's or another tag's given one, or one that differs, each routine's units
  first and then its rungs in order, the program's routine first and then each body's, by
  the block's name. `[]` for every program a compile gives. One walk of the program's
  rungs and of each body once: a body in the program's one table of block types (decision
  53), and one a tag of a routine walked holds as its type itself, which only a program
  built by hand does. Every entry point that takes a program first checks it so, where it
  is first handed in (decision 190).
  """
  def edited_by_hand(%__MODULE__{name: name} = program) do
    {lines, _seen} =
      routine(program, {name, nil}, {[], MapSet.new()}, held_in(table(program.blocks)))

    Enum.reverse(lines)
  end

  defp routine(
         %__MODULE__{
           rungs: rungs,
           tags: tags,
           blocks: blocks,
           units: units,
           reals: reals,
           arrays: arrays,
           retained: retained
         },
         where,
         {lines, seen},
         table
       )
       when is_list(rungs) and is_map(tags) do
    {program, _block} = where
    # The tags settled once for all three (M5-11's review), and nothing compared where a
    # routine holds none and gives none, the common case.
    {wanted_units, wanted_reals, wanted_arrays, wanted_retained} = settled_in(tags, table)
    lines = Enum.reverse(unit_lines(units, {tags, wanted_units}, where), lines)
    lines = Enum.reverse(real_lines(reals, {tags, wanted_reals}, where), lines)
    lines = Enum.reverse(array_lines(arrays, {tags, wanted_arrays}, where), lines)
    lines = Enum.reverse(retained_lines(retained, wanted_retained, where), lines)
    {lines, called} = rungs(rungs, {tags, where}, {lines, []})
    acc = Enum.reduce(Enum.reverse(called), {lines, seen}, &once(&1, {program, table}, &2))
    held_bodies(blocks, {program, table}, acc)
  end

  defp routine(_not_a_routine, _where, acc, _table), do: acc

  # Only a program's own table is walked: a held body's table is the program's (decision
  # 53), so a body names no table of its own to walk. Since M6-1 a body's instances are read
  # inside that table, `table`, for its `retained`.
  defp held_bodies(%{} = blocks, at, acc),
    do: Enum.reduce(Enum.sort(blocks), acc, fn {_name, type}, acc -> once(type, at, acc) end)

  defp held_bodies(_no_table, _at, acc), do: acc

  defp once(
         %Logex.FbType{name: name, body: %__MODULE__{} = body},
         {program, table},
         {lines, seen} = acc
       ),
       do:
         unseen(
           MapSet.member?(seen, body),
           body,
           {program, name},
           acc,
           {{lines, MapSet.put(seen, body)}, merged(table, body.blocks)}
         )

  defp once(_no_body, _at, acc), do: acc

  # A body's own table, where it has one, read with the one it is held in; the quiet names
  # made again only then (M6-2's review), so a check of held bodies makes them once.
  defp merged(at, nil), do: at
  defp merged(at, blocks) when map_size(blocks) == 0, do: at
  defp merged({table, _quiet}, blocks), do: held_in(Map.merge(table, blocks))

  defp unseen(true, _body, _where, acc, _put), do: acc

  defp unseen(false, body, where, _acc, {put, table}),
    do: routine(%{body | blocks: nil}, where, put, table)

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
              destination(List.last(operands), tags, :arithmetic),
              symbol,
              line,
              operands,
              where,
              lines
            ), called}
         )

  defp elements([{symbol, line, [_ | _] = operands} | rest], {tags, where} = at, {lines, called})
       when symbol in @bitwise,
       do:
         elements(
           rest,
           at,
           {computes(
              destination(List.last(operands), tags, :bitwise),
              symbol,
              line,
              operands,
              where,
              lines
            ), called}
         )

  defp elements([{symbol, line, [_ | _] = operands} | rest], {tags, where} = at, {lines, called})
       when symbol in @rooting,
       do:
         elements(
           rest,
           at,
           {computes(
              destination(List.last(operands), tags, :real),
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

  # M5-14: an element of an array of instances, of its array's elements' type.
  defp elements([{:cal, _, [{:element, _, array, _, _} | _]} | rest], {tags, _where} = at, acc),
    do: elements(rest, at, called(of_elements(Map.get(tags, array)), acc))

  defp elements([_other | rest], at, lines), do: elements(rest, at, lines)
  defp elements(_end, _at, lines), do: lines

  defp legs([leg | rest], at, lines), do: legs(rest, at, elements(leg, at, lines))
  defp legs(_end, _at, lines), do: lines

  defp called(%Logex.Tag{type: %Logex.FbType{body: %__MODULE__{}} = type}, {lines, called}),
    do: {lines, [type | called]}

  defp called(_named_or_none, acc), do: acc

  defp of_elements(%Logex.Tag{type: {:array, type, _dims}} = tag), do: %{tag | type: type}
  defp of_elements(_no_array), do: nil

  defp computes({:ok, _type}, _symbol, _line, _operands, _where, lines), do: lines

  defp computes({:error, what}, symbol, line, operands, {program, _block} = where, lines),
    do: [
      "#{located(where)}`#{symbol}` on line #{line}#{within(where)} computes in the type of " <>
        "#{written(List.last(operands), what, where)}: #{named(program)} was edited by " <>
        "hand after it compiled"
      | lines
    ]

  # Decision 197: a routine's units against the ones its tags give, by name in order.
  defp unit_lines(nil, {_tags, nil}, _where), do: []

  defp unit_lines(units, {tags, wanted}, where) when is_map(units) or units == nil do
    given = table(units)
    wanted = table(wanted)

    for name <- Enum.sort(Enum.uniq(Map.keys(wanted) ++ Map.keys(given))),
        Map.fetch(given, name) != Map.fetch(wanted, name),
        do:
          "#{owner(where)} units give #{shown_name(name)} #{unit_given(Map.fetch(given, name))}, " <>
            "where #{unit_wanted(Map.fetch(tags, name), where)}: " <>
            "#{named(elem(where, 0))} was edited by hand after it compiled"
  end

  defp unit_lines(units, _tags, where),
    do: [
      "#{owner(where)} units are neither nil nor a map of timer names to units, got: #{inspect(units)}: " <>
        "#{named(elem(where, 0))} was edited by hand after it compiled"
    ]

  # M6-1: a routine's retained paths against the ones its tags give, each that differs a
  # line, in order, as its units.
  defp retained_lines(nil, nil, _where), do: []

  defp retained_lines(retained, wanted, where) when is_list(retained) or retained == nil do
    given = MapSet.new(retained || [])
    wanted = MapSet.new(wanted || [])

    for path <- Enum.sort(MapSet.to_list(MapSet.union(given, wanted))),
        MapSet.member?(given, path) != MapSet.member?(wanted, path),
        do:
          "#{owner(where)} retained paths #{retained_given(MapSet.member?(given, path))} " <>
            "`#{path}`, where its tags #{retained_given(MapSet.member?(wanted, path))} it: " <>
            "#{named(elem(where, 0))} was edited by hand after it compiled"
  end

  defp retained_lines(retained, _wanted, where),
    do: [
      "#{owner(where)} retained paths are neither nil nor a list of paths, got: " <>
        "#{inspect(retained)}: #{named(elem(where, 0))} was edited by hand after it compiled"
    ]

  defp retained_given(true), do: "hold"
  defp retained_given(false), do: "do not hold"

  # M5-10: a routine's reals against the ones its tags give, by name in order, as its units.
  defp real_lines(nil, {_tags, nil}, _where), do: []

  defp real_lines(reals, {tags, wanted}, where) when is_map(reals) or reals == nil do
    given = table(reals)
    wanted = table(wanted)

    for name <- Enum.sort(Enum.uniq(Map.keys(wanted) ++ Map.keys(given))),
        Map.fetch(given, name) != Map.fetch(wanted, name),
        do:
          "#{owner(where)} reals give #{shown_name(name)} #{real_given(Map.fetch(given, name))}, " <>
            "where #{real_wanted(Map.fetch(tags, name), where)}: " <>
            "#{named(elem(where, 0))} was edited by hand after it compiled"
  end

  defp real_lines(reals, _tags, where),
    do: [
      "#{owner(where)} reals are neither nil nor a map of tag names to real types, got: " <>
        "#{inspect(reals)}: #{named(elem(where, 0))} was edited by hand after it compiled"
    ]

  # M5-11: a routine's arrays against the ones its tags give, by name in order, as its reals.
  defp array_lines(nil, {_tags, nil}, _where), do: []

  defp array_lines(arrays, {tags, wanted}, where) when is_map(arrays) or arrays == nil do
    given = table(arrays)
    wanted = table(wanted)

    for name <- Enum.sort(Enum.uniq(Map.keys(wanted) ++ Map.keys(given))),
        Map.fetch(given, name) != Map.fetch(wanted, name),
        do:
          "#{owner(where)} arrays give #{shown_name(name)} #{array_given(Map.fetch(given, name))}, " <>
            "where #{real_wanted(Map.fetch(tags, name), where)}: " <>
            "#{named(elem(where, 0))} was edited by hand after it compiled"
  end

  defp array_lines(arrays, _tags, where),
    do: [
      "#{owner(where)} arrays are neither nil nor a map of tag names to array types, got: " <>
        "#{inspect(arrays)}: #{named(elem(where, 0))} was edited by hand after it compiled"
    ]

  defp array_given(:error), do: "no array type"

  defp array_given({:ok, {:array, type, [_ | _]} = array}) when is_elementary(type),
    do: shown_array(Enum.all?(elem(array, 2), &(is_integer(&1) and &1 > 0)), array)

  defp array_given({:ok, type}), do: "the type #{inspect(type, charlists: :as_lists)}"

  defp shown_array(true, array), do: a(array)
  defp shown_array(false, array), do: "the type #{inspect(array, charlists: :as_lists)}"

  defp real_given(:error), do: "no real type"
  defp real_given({:ok, type}), do: "the type #{inspect(type)}"

  defp real_wanted({:ok, %Logex.Tag{type: type}}, _where), do: "it is #{a(type)}"
  defp real_wanted(_undeclared, where), do: "#{declarer(where)} declares no such tag"

  # No units, nil, are an empty table: a routine of plain timers.
  defp table(nil), do: %{}
  defp table(units), do: units

  defp owner({nil, nil}), do: "an unnamed program's"
  defp owner({program, nil}), do: "`#{program}`'s"
  defp owner({_program, block}), do: "`#{block}`'s body's"

  defp shown_name(name) when is_binary(name), do: "`#{name}`"
  defp shown_name(name), do: inspect(name)

  defp unit_given(:error), do: "no unit"
  defp unit_given({:ok, per_ms}), do: "#{inspect(per_ms)} a millisecond"

  # M5-14: an array of timers times in its elements' unit, each element its own timer.
  defp unit_wanted({:ok, %Logex.Tag{type: {:array, %Logex.FbType{} = type, _} = array}}, _where),
    do: "each element of " <> of_unit(per_ms_of(Logex.FbType.rules(type)), array)

  defp unit_wanted({:ok, %Logex.Tag{type: type}}, _where),
    do: of_unit(per_ms_of(Logex.FbType.rules(type)), type)

  defp unit_wanted(_undeclared, where), do: "#{declarer(where)} declares no such tag"

  defp per_ms_of(%{per_ms: per_ms}) when is_integer(per_ms), do: per_ms
  defp per_ms_of(_no_timer), do: nil

  defp of_unit(nil, type), do: "#{a(type)} keeps no time"

  defp of_unit(1, type),
    do: "#{a(type)} adds 1 to its `acc` each millisecond, which takes no unit"

  defp of_unit(per_ms, type), do: "#{a(type)} adds #{per_ms} to its `acc` each millisecond"

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

  defp written(destination, {:real, type}, _where),
    do: "#{shown(destination)}, #{a(type)}, which is no real type"

  defp written(destination, {:bits, type}, _where),
    do: "#{shown(destination)}, #{a(type)}, which is no bool, integer or bit-string type"

  defp written(destination, {:not_an_array, type}, _where),
    do: "#{shown(destination)}, whose array is #{a(type)}, no array"

  defp written(destination, {:no_instance, instance}, where),
    do: "#{shown(destination)}, and #{declarer(where)} declares no `#{instance}`"

  defp written(destination, {:instance, instance, type}, _where),
    do: "#{shown(destination)}, and `#{instance}` is #{a(type)}, not a built-in's instance"

  defp written({:member, _, [_, member]} = destination, {:no_member, type}, _where),
    do: "#{shown(destination)}, and #{a(type)} has no `#{member}`"

  # M5-14: a member of an element of an array of instances so.
  defp written({:member, _, _element, [member]} = destination, {:no_member, type}, _where),
    do: "#{shown(destination)}, and #{a(type)} has no `#{member}`"

  # Decision 190: what a scan of a program edited by hand after its check is told of a
  # destination it reaches, in the words above.
  @doc false
  def met(destination, what), do: written(destination, what, {nil, nil})

  defp declarer({program, nil}), do: named(program)
  defp declarer({_program, _block}), do: "the body"

  defp shown({:name, _, name}), do: "`#{name}`"
  defp shown({:member, _, path}), do: "`#{Enum.join(path, ".")}`"

  defp shown({:member, _, element, members}),
    do: "`#{Enum.join([elem(element, tuple_size(element) - 1) | members], ".")}`"

  defp shown({:bit, _, _path, _n, _mask, name}), do: "`#{name}`"
  defp shown({:bit_at, _, _path, _index, _width, name}), do: "`#{name}`"
  defp shown({:element, _, _array, _index, name}), do: "`#{name}`"
  defp shown({:element_at, _, _array, _index, _dims, name}), do: "`#{name}`"
  defp shown(other), do: "`#{inspect(other)}`"

  defp a(%Logex.FbType{} = type), do: Logex.Declarations.instance_of(type)
  defp a({:block, name}) when is_binary(name), do: "an instance of `#{name}`"
  defp a(type) when is_atom(type), do: Logex.Declarations.a_type(type)
  defp a(type) when is_array(type), do: Logex.Declarations.a_type(type)
  defp a(other), do: inspect(other)
end
