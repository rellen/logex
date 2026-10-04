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
    "ton" => {:ton, [{:instance, "ton"}, {:preset, :dint}]},
    # M2-5: `cal` runs an instance of a user function block. Its entry is a marker, not a
    # signature: the signature is the block's, built per compile from the instance's type
    # (Logex.FbType.signature/1), the instance, then the block's var_inputs and var_outputs
    # in declaration order. The entry still reserves the word and names its stanza.
    "cal" => {:cal, :block}
  }

  @doc """
  The mnemonic table: each lowercase mnemonic to its IR symbol and operand signature, or
  for `cal` the marker `:block`, since its signature is the block's (M2-5; `signature/2`).

  Every key must have a `### \\`mnemonic\\`` stanza in `docs/naming.md`;
  `Logex.NamingTest` enforces it.
  """
  def instructions, do: @instructions

  # Each IR symbol to its mnemonic's operand signature, where the mnemonic has one: `cal`'s
  # is its block's, per instruction.
  @signatures for {_word, {symbol, signature}} when is_list(signature) <- @instructions,
                  into: %{},
                  do: {symbol, signature}

  @doc """
  The slots of an instruction of the IR, `{symbol, line, operands}`: one `{access, type}`
  per operand, in order, its mnemonic's signature in `instructions/0`. The walks that read
  a program's IR for what each operand does, `Logex.Warnings` and `Logex.Edit`, look every
  instruction's slots up here, never in a table of their own (M2-5).

  The slots are per instruction, given `tags`, the tag table of the program that holds it,
  so that an instruction's slots may depend on what its operands name: a `cal`'s are its
  instance's type's, `Logex.FbType.signature/1`'s, the instance first and then a slot per
  formal, so a var_output it fills is written. In a block's body, whose instances name
  their types, the table is `Logex.Program.typed_tags/1`'s, each instance's type itself.
  Total: an instruction no mnemonic gives, a `cal` of anything that is no user block's
  instance in `tags`, or anything else that is not an instruction, which only a program
  built by hand can hold, has none.
  """
  def signature({:cal, _line, [{:name, _, instance} | _]}, tags) when is_map(tags),
    do: block_slots(Map.get(tags, instance))

  def signature({symbol, _line, _operands}, _tags), do: Map.get(@signatures, symbol, [])
  def signature(_not_an_instruction, _tags), do: []

  defp block_slots(%Tag{type: %FbType{body: %Program{}} = type}),
    do: for({slot, _formal} <- FbType.signature(type), do: slot)

  defp block_slots(_not_a_block), do: []

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
  So too a declaration line refused for its type word, one no compile knows or a block
  that would hold the block being compiled, declares nothing, and its name's uses are not
  each reported as undeclared (M2-5): a misspelled block name is one message.

  The routine is checked first, against `Logex.Parser.well_formed!/1`: a tree that
  `Logex.Parser.parse/1` could not have produced, such as an empty group, a negative
  literal or a rung over two lines, raises `ArgumentError`, a host mistake, since no
  source text says it and no diagnostic could cite it (OE-1). Then `declared`.
  """
  def instructionize(routine, declared \\ [], types \\ []) do
    {:routine, {:rungs, rungs}} = Logex.Parser.well_formed!(routine)
    {library, held} = library!(types)
    {kind, rungs, heading} = file_kind(rungs)
    marks = marked(kind, library)
    {tags, logic, declaring, untyped} = Declarations.split(rungs, declared, marks)
    holds_itself!(kind, declared)
    Enum.reduce(blocks(tags), {held, :tags}, &one_version!/2)
    known = {scope(tags), folded(tags)}
    {rungs, lowering} = Enum.map_reduce(logic, [], &lower_rung(&1, &2, known))
    note? = map_size(tags) == 0 and declares_nothing?(routine, logic)
    instructions = instructions(rungs)
    shared = shared_bits(instructions, tags)
    {tags, timing} = presets(instructions, tags)
    calls = calls(instructions)
    paths = Enum.flat_map(rungs, fn {:rung, elements} -> path(elements, known) end)
    found = Enum.reject(Enum.reverse(lowering), &excused?(&1, untyped))
    errors = declaring ++ undeclared(found, tags, note?) ++ shared ++ timing
    lowered(kind, rungs, tags, heading ++ header_tags(kind, tags) ++ errors ++ calls ++ paths)
  end

  @doc """
  Whether `body`'s rungs, tags and warnings are exactly what `instructionize/3` gives for
  some text over that tag table (M2-5): every rung lowers again, through the checks a
  compile makes, to itself, with no diagnostic; the one-per-bit, one-per-timer and
  one-per-instance rules and the path after a `ton` hold; each timer's preset is the
  number on the `ton` that runs it; the rungs are on rising lines, each on one line, after
  the declarations; and the warnings are the ones its rungs give, a file aside. Its tag
  table is its tags with each instance's type itself (`Logex.Program.typed_tags/1`): a
  tag naming a type its `blocks` does not hold, or anything else that is not a tag of a
  type a compile knows, makes it no compiled body. Total: any other value is `false`,
  never an exception.

  It is the definition of a compiled body, which `Logex.FbType.user?/1` checks for a type
  given to a compile or to `Logex.Tag.new!/4`, as `Logex.Parser.well_formed!/1` is of a
  parse tree: what a type given cannot hold, no runtime or edit step meets. It expects
  the tag table checked already, every entry a `%Logex.Tag{}` under its name and every
  instance's type a valid one (`Logex.FbType.user?/1` checks those first).
  """
  def lowered?(%Program{rungs: rungs, tags: tags, blocks: blocks, warnings: warnings} = body)
      when is_list(rungs) and is_map(tags) and not is_struct(tags) and is_map(blocks) and
             is_list(warnings) do
    typed = Program.typed_tags(body)

    relowered(
      proper?(rungs, &ir_rung?/1) and proper?(warnings, &any?/1) and Enum.all?(typed, &typed?/1),
      rungs,
      typed,
      warnings
    )
  end

  def lowered?(_body), do: false

  defp relowered(false, _rungs, _tags, _warnings), do: false

  defp relowered(true, rungs, tags, warnings) do
    known = {scope(tags), folded(tags)}
    instructions = instructions(rungs)
    {timed, timing} = presets(instructions, unpreset(tags))

    map_size(elem(known, 1)) == map_size(tags) and
      Enum.all?(rungs, &lowers_to_itself?(&1, known)) and
      shared_bits(instructions, tags) == [] and calls(instructions) == [] and timing == [] and
      timed == tags and
      Enum.flat_map(rungs, fn {:rung, elements} -> path(elements, known) end) == [] and
      lines?(rungs, tags) and Enum.map(warnings, &fileless/1) == Logex.Warnings.of(rungs, tags)
  end

  # Each IR symbol back to its mnemonic.
  @mnemonics Map.new(@instructions, fn {word, {symbol, _signature}} -> {symbol, word} end)

  # A proper list, each element passing `test`: Enum.all?/2 raises on an improper one.
  defp proper?([], _test), do: true
  defp proper?([element | rest], test), do: test.(element) and proper?(rest, test)
  defp proper?(_not_a_list, _test), do: false

  defp any?(_element), do: true

  # A tag of a type the lowering knows, once each held type is given (M2-5).
  defp typed?({_name, %Tag{type: type}}) when type in [:bool, :dint], do: true
  defp typed?({_name, %Tag{type: %FbType{}}}), do: true
  defp typed?(_entry), do: false

  defp ir_rung?({:rung, [_ | _] = elements}), do: proper?(elements, &ir_element?/1)
  defp ir_rung?(_rung), do: false

  defp ir_element?({:branches, [_ | _] = legs}), do: proper?(legs, &ir_leg?/1)

  defp ir_element?({symbol, line, operands}) when is_integer(line) and line > 0,
    do: is_map_key(@mnemonics, symbol) and proper?(operands, &ir_operand?/1)

  defp ir_element?(_element), do: false

  defp ir_leg?([_ | _] = elements), do: proper?(elements, &ir_element?/1)
  defp ir_leg?(_leg), do: false

  defp ir_operand?({:name, line, name}) when is_integer(line) and line > 0, do: is_binary(name)

  defp ir_operand?({:int_lit, line, value}) when is_integer(line) and line > 0,
    do: is_integer(value) and value >= 0

  defp ir_operand?({:member, line, path}) when is_integer(line) and line > 0,
    do: proper?(path, &is_binary/1)

  defp ir_operand?(_operand), do: false

  # A rung back to the elements its text parses to, lowered again: the same IR, and no
  # diagnostic.
  defp lowers_to_itself?({:rung, elements} = rung, known),
    do: lower_rung({:rung, Enum.flat_map(elements, &unlowered/1)}, [], known) == {rung, []}

  defp unlowered({:branches, legs}),
    do: [{:branches, Enum.map(legs, &Enum.flat_map(&1, fn e -> unlowered(e) end))}]

  defp unlowered({symbol, line, operands}),
    do: [{:name, line, Map.fetch!(@mnemonics, symbol)} | Enum.map(operands, &unlowered_operand/1)]

  defp unlowered_operand({:member, line, path}), do: {:name, line, Enum.join(path, ".")}
  defp unlowered_operand(operand), do: operand

  # A timer's preset is the compiler's to give, from the `ton` that runs it.
  defp unpreset(tags),
    do:
      Map.new(tags, fn
        {name, %Tag{type: %FbType{}} = tag} -> {name, %{tag | initial: nil}}
        entry -> entry
      end)

  # Each rung on one line, every operand on its instruction's, after the last; and every
  # declaration on a line of its own, before the first. The sorted declaration lines rising
  # refuses two on one line.
  defp lines?(rungs, tags) do
    lines = Enum.map(rungs, &rung_lines/1)
    declared = for {_, %Tag{line: line}} <- tags, line != nil, do: line

    Enum.all?(lines, &match?([_], &1)) and rising?(Enum.sort(declared) ++ Enum.map(lines, &hd/1))
  end

  defp rung_lines({:rung, elements}),
    do: elements |> gather([]) |> Enum.flat_map(&lines_of/1) |> Enum.uniq()

  defp lines_of({_symbol, line, operands}), do: [line | Enum.map(operands, &elem(&1, 1))]

  defp rising?([one, two | rest]), do: one < two and rising?([two | rest])
  defp rising?(_short), do: true

  defp fileless(%Diagnostic{} = warning), do: %{warning | file: nil}
  defp fileless(other), do: other

  # ---- M2-5: a function block's file, and the blocks a compile is given ------------------

  # A file is a function block when its first rung is `function_block <name>`, and a
  # program otherwise (decision 4). The line comes off before the declarations, as they do
  # before the rungs. `{kind, rungs, diagnostics}`, the kind `:program` or `{:block, name}`.
  defp file_kind([{:rung, [{:name, line, word} | rest]} | rungs] = all),
    do: heads(String.downcase(word) == "function_block", rest, line, rungs, all)

  defp file_kind(rungs), do: {:program, rungs, []}

  defp heads(false, _rest, _line, _rungs, all), do: {:program, all, []}
  defp heads(true, [{:name, _, name}], line, rungs, _all), do: block_named(name, line, rungs)

  defp heads(true, _rest, line, rungs, _all),
    do:
      {{:block, nil}, rungs,
       [diagnostic(line, "`function_block` takes the block's name, as in `function_block seal`")]}

  # A block's name is spelled in the files that use it, `var s1 seal`, so it is a name, and
  # no word that is reserved: `var s1 move` would read as a mnemonic.
  defp block_named(name, line, rungs),
    do: {{:block, name}, rungs, block_name(Declarations.name?(name), name, line)}

  defp block_name(false, name, line),
    do: [
      diagnostic(
        line,
        "`#{name}` cannot name a function block: a name is a letter or `_`, " <>
          "then letters, digits or `_`"
      )
    ]

  defp block_name(true, name, line), do: reserved_block(Declarations.reserved(name), name, line)

  # docs/organisation.md §4.8: the word that heads a block's file is reserved in one, so it
  # names no block, which would be spelled as a type word in a block's file.
  defp reserved_block(nil, name, line),
    do: header_word(String.downcase(name) in Declarations.kinds(), name, line)

  defp reserved_block(reserved, name, line),
    do: [
      diagnostic(line, "`#{name}` is #{reserved_as(reserved)} and cannot name a function block")
    ]

  defp header_word(false, _name, _line), do: []

  defp header_word(true, name, line),
    do: [diagnostic(line, "`#{name}` is a keyword and cannot name a function block")]

  # docs/organisation.md §4.8: `function_block` is reserved in a block's file only. A tag
  # declared from Elixir, which no line can cite, is refused as a host mistake.
  defp header_tags({:block, _name}, tags),
    do:
      for(
        {name, %Tag{line: line}} <- tags,
        String.downcase(name) in Declarations.kinds(),
        do: header_tag(line, name)
      )

  defp header_tags(:program, _tags), do: []

  defp header_tag(nil, name),
    do:
      raise(
        ArgumentError,
        "`#{name}` heads a function block's file and cannot name a tag in one"
      )

  defp header_tag(line, name),
    do: diagnostic(line, "`#{name}` heads a function block's file and cannot name a tag in one")

  # Recursion through a tag declared from Elixir, which no line can cite: a host mistake.
  # Each type is searched once, however many instances hold it.
  defp holds_itself!({:block, name}, declared) when is_binary(name) do
    Enum.reduce(declared, %{}, fn
      %Tag{name: tag, type: %FbType{} = type}, seen -> itself!(holds(type, name, seen), tag, name)
      _tag, seen -> seen
    end)

    :ok
  end

  defp holds_itself!(_kind, _declared), do: :ok

  defp itself!({true, _seen}, tag, name),
    do:
      raise(
        ArgumentError,
        "`#{tag}` holds an instance of `#{name}`, the function block being compiled: " <>
          "a function block never holds an instance of itself, at any depth"
      )

  defp itself!({false, seen}, _tag, _name), do: seen

  # Whether `type`, or a type it holds at any depth, is named `name`: `{held?, seen}`, the
  # types searched so far each to whether it does.
  defp holds(%FbType{name: name}, name, seen), do: {true, seen}
  defp holds(%FbType{name: held}, _name, seen) when is_map_key(seen, held), do: {seen[held], seen}

  defp holds(%FbType{name: held} = type, name, seen) do
    {found, seen} =
      Enum.reduce(nested(type), {false, Map.put(seen, held, false)}, fn
        _inner, {true, seen} -> {true, seen}
        inner, {false, seen} -> holds(inner, name, seen)
      end)

    {found, Map.put(seen, held, found)}
  end

  # One mistake, one message: a declaration refused for its type word, one no compile knows
  # or one that would hold the block being compiled, declares nothing, and its uses are
  # excused rather than each reported as undeclared (Logex.Declarations.split/3), so a
  # misspelled block name gives one message (M2-5).
  defp excused?({:undeclared, _line, name, _slot}, untyped), do: MapSet.member?(untyped, name)
  defp excused?(_diagnostic, _untyped), do: false

  # The blocks a compile is given: a proper list of user types, each one Logex.compile/2
  # gave, and no two of one name. A host mistake otherwise. `{library, held}`: the types by
  # name, for the declaration lines, and every block they hold at any depth by name, the
  # one version of each, which the tags declared from Elixir are then checked against.
  defp library!(types) when is_list(types), do: listed!(proper?(types, &any?/1), types)
  defp library!(types), do: listed!(false, types)

  defp listed!(true, types) do
    library =
      Enum.reduce(types, %{}, fn type, library -> given!(FbType.user?(type), type, library) end)

    {held, :types} = Enum.reduce(Map.values(library), {library, :types}, &one_version!/2)
    {library, held}
  end

  defp listed!(false, types),
    do:
      raise(
        ArgumentError,
        "types must be a list of function block types from Logex.compile/2, got: " <>
          inspect(types)
      )

  defp given!(true, %FbType{name: name} = type, library) when not is_map_key(library, name),
    do: Map.put(library, name, type)

  defp given!(true, %FbType{name: name}, _library),
    do:
      raise(ArgumentError, "types holds two function blocks named `#{name}`: one name, one type")

  defp given!(false, type, _library),
    do:
      raise(
        ArgumentError,
        "types must be function block types from Logex.compile/2, got: #{inspect(type)}"
      )

  defp blocks(tags), do: for({_, %Tag{type: %FbType{body: %Program{}} = type}} <- tags, do: type)

  # Every block a given type holds, at any depth, is the one given under its name where one
  # is: a program holds one type of each name, which the edit's rules (Logex.Edit) and the
  # runtime's lookups by name rely on. Each type is walked once.
  # `from` says where the types walked came from, `:types` or `:tags`, for the message.
  defp one_version!(%FbType{name: name} = type, {seen, from}) do
    same = FbType.same?(Map.get(seen, name, type), type)
    seen = versions!(same, name, Map.put(seen, name, type), from)
    Enum.reduce(nested(type), {seen, from}, &held_version!/2)
  end

  defp held_version!(%FbType{name: name} = type, {seen, from}) when is_map_key(seen, name),
    do: {versions!(FbType.same?(Map.fetch!(seen, name), type), name, seen, from), from}

  defp held_version!(type, acc), do: one_version!(type, acc)

  defp versions!(true, _name, seen, _from), do: seen

  # The tags are walked after the types, so a second version found there is in a tag
  # declared from Elixir: a tag a declaration line declares has a type given.
  defp versions!(false, name, _seen, :tags),
    do:
      raise(
        ArgumentError,
        "a tag declared from Elixir holds a function block named `#{name}` other than the " <>
          "one of that name in the types given or in another tag: give every instance of a " <>
          "block the same version, compiled against the same types"
      )

  defp versions!(false, name, _seen, :types),
    do:
      raise(
        ArgumentError,
        "types holds two different function blocks named `#{name}`, one inside another type " <>
          "given: compile each block against the same types"
      )

  # Recursion (Ed 2 §2.5; docs/organisation.md §4.3). In a block's own file, its own name,
  # and every type given that holds an instance of a type of that name at any depth, is
  # marked `{:recursive, chain}`, and a declaration of one is refused at its line. Each type
  # is searched once, however many hold it, so the marking is linear in the types.
  defp marked(:program, library), do: library

  defp marked({:block, name}, library) do
    {chains, _seen} = Enum.reduce(library, {%{}, %{}}, fn {_, t}, acc -> chain(t, name, acc) end)

    marks =
      for {held, [_ | _] = chain} <- chains, into: %{}, do: {held, {:recursive, [name | chain]}}

    library |> Map.merge(marks) |> Map.put(name, {:recursive, [name, name]})
  end

  # The chain from `type` down to a type named `name`, `[type.name, …, name]`, or nil.
  defp chain(%FbType{name: name}, name, {chains, seen}),
    do: {Map.put(chains, name, [name]), Map.put(seen, name, true)}

  defp chain(%FbType{name: held} = type, name, {chains, seen}) when not is_map_key(seen, held) do
    {chains, seen} =
      Enum.reduce(nested(type), {chains, Map.put(seen, held, true)}, &chain(&1, name, &2))

    {Map.put(chains, held, down(held, Enum.find_value(nested(type), &Map.get(chains, &1.name)))),
     seen}
  end

  defp chain(_seen, _name, acc), do: acc

  # The user block types a type holds, each once, from its body (Logex.FbType).
  defp nested(%FbType{body: %Program{blocks: blocks}}), do: Map.values(blocks)

  defp nested(%FbType{body: nil}), do: []

  defp down(_held, nil), do: nil
  defp down(held, chain), do: [held | chain]

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
  defp path(elements, known) do
    {diagnostics, _borne} = series(elements, nil, [], known)
    Enum.reverse(diagnostics)
  end

  # A series, a rung or a leg: its diagnostics onto `diagnostics`, and the first `ton` on it.
  defp series([], before, diagnostics, _known), do: {diagnostics, before}

  defp series([element | rest], before, diagnostics, known) do
    {diagnostics, borne} = bears(element, follows(before, element, known) ++ diagnostics, known)
    series(rest, earliest(before, borne), diagnostics, known)
  end

  defp bears({:ton, _, _} = ton, diagnostics, _known), do: {diagnostics, ton}

  defp bears({:branches, legs}, diagnostics, known),
    do: Enum.reduce(legs, {diagnostics, nil}, &leg(&1, &2, known))

  defp bears(_instruction, diagnostics, _known), do: {diagnostics, nil}

  defp leg(elements, {diagnostics, before}, known) do
    {diagnostics, borne} = series(elements, nil, diagnostics, known)
    {diagnostics, earliest(before, borne)}
  end

  defp earliest(nil, bears), do: bears
  defp earliest(before, _bears), do: before

  defp follows(nil, _element, _known), do: []

  defp follows({:ton, line, operands}, element, known) do
    message =
      "#{shown(element)} follows #{shown({:ton, line, Enum.take(operands, 1)})} on its path: " <>
        "what passes on after a `ton` is not settled, so a `ton` ends its path; " <>
        read_timer(operands, known)

    [diagnostic(line_of(element, line), message)]
  end

  defp shown({:branches, _legs}), do: "a branch group"
  defp shown({symbol, _line, []}), do: "`#{symbol}`"

  defp shown({symbol, _line, operands}),
    do: "`#{symbol} #{Enum.map_join(operands, " ", &text/1)}`"

  defp text({:name, _, name}), do: name
  defp text({:int_lit, _, value}), do: "#{value}"
  defp text({:member, _, path}), do: Enum.join(path, ".")

  defp read_timer([{:name, _, timer} | _], known), do: read(timer?(timer, known), timer)
  defp read_timer(_no_timer, _known), do: read(false, nil)

  defp read(true, timer), do: "read the timer with `xic #{timer}.dn` on a rung below"
  defp read(false, _timer), do: "read the timer's `.dn` on a rung below"

  # Whether a hint may name `name` as a timer: a declared one, or a name not declared yet,
  # which the hint fits once it is declared as one. Anything else, a bool, a member or a
  # reserved word, has a diagnostic of its own, which a hint beside it would contradict.
  defp timer?(name, known), do: runnable?(Declarations.reserved(name), hinted(name, known))

  defp runnable?(nil, {:ok, %Tag{type: %FbType{name: "ton"}}}), do: true
  defp runnable?(nil, :error), do: true
  defp runnable?(_reserved, _found), do: false

  # A name not declared yet is one that can be: a name differing from a declared tag only
  # in case never can be (Logex.Declarations), so a hint naming it would never compile.
  defp hinted(name, {scope, folded}),
    do: declarable(lookup(name, scope), Map.fetch(folded, String.downcase(name)))

  defp declarable(:error, {:ok, twin}), do: {:twin, twin}
  defp declarable(found, _twin), do: found

  # Each declared name by its lowercase form, unique since the table refuses a case-only
  # twin, so finding one is a lookup, not a walk of the table.
  defp folded(tags), do: Map.new(tags, fn {name, _tag} -> {String.downcase(name), name} end)

  # What a name is looked up in: the tag table, and the members a program may name of each
  # instance's type, by name, built once per type (a compile holds one version of each
  # name), so that finding a member is a lookup too, however many the type has (M2-5).
  defp scope(tags), do: {tags, Enum.reduce(tags, %{}, &named_members/2)}

  defp named_members({_, %Tag{type: %FbType{name: type} = fb}}, members)
       when not is_map_key(members, type),
       do: Map.put(members, type, Map.new(FbType.public(fb), &{&1.name, &1}))

  defp named_members(_tag, members), do: members

  # A group carries no line of its own, so it is cited at the `ton`'s: a rung is one line.
  # An element is cited at its own, which is the `ton`'s too until PLAN.md §5's line
  # continuations land: Logex.Parser.well_formed!/1 keeps every rung to one line (OE-1).
  # Kept for them, as the test of a rung over two lines can no longer reach it.
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

  defp lowered(:program, rungs, tags, []),
    do: {:ok, %Program{rungs: rungs, tags: tags, warnings: Logex.Warnings.of(rungs, tags)}}

  # M2-5: a block's file compiles to its type, whose body is the program of its rungs. The
  # body holds each user block type its instances are of once, in `blocks`, and each
  # instance's tag names it (docs/organisation.md §4.10, "Held types"): a type held in every
  # instance's tag would grow, copied flat, as the width to the power of the depth.
  defp lowered({:block, name}, rungs, tags, []) do
    {held, blocks} = Enum.reduce(tags, {%{}, %{}}, &hold/2)

    body = %Program{
      name: name,
      rungs: rungs,
      tags: held,
      blocks: blocks,
      warnings: Logex.Warnings.of(rungs, tags)
    }

    {:ok, FbType.of(body)}
  end

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_kind, _rungs, _tags, diagnostics),
    do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  # A tag of an instance of a user block names its type, which the body holds by name: one
  # version of each name, as the compile's one-version check holds.
  defp hold(
         {name, %Tag{type: %FbType{name: type, body: %Program{}} = held} = tag},
         {tags, blocks}
       ),
       do: {Map.put(tags, name, %{tag | type: {:block, type}}), Map.put(blocks, type, held)}

  defp hold({name, tag}, {tags, blocks}), do: {Map.put(tags, name, tag), blocks}

  # M2-5: one `cal` runs an instance, as one `ton` runs a timer: a second is an error at its
  # own line, citing the first. Two would run the body twice a scan, and the edit's rules
  # for the one-shots and timers inside it (Logex.Edit) name the one rung that runs it.
  defp calls(instructions) do
    {_first, diagnostics} =
      Enum.reduce(instructions, {%{}, []}, fn
        {:cal, line, [{:name, _, instance} | _]}, {first, diagnostics} ->
          called(Map.fetch(first, instance), instance, line, {first, diagnostics})

        _instruction, acc ->
          acc
      end)

    Enum.reverse(diagnostics)
  end

  defp called(:error, instance, line, {first, diagnostics}),
    do: {Map.put(first, instance, line), diagnostics}

  defp called({:ok, first_line}, instance, line, {first, diagnostics}) do
    message =
      "`#{instance}` is already run by the `cal` #{where(first_line, line)}: " <>
        "one `cal` runs an instance"

    {first, [diagnostic(line, message) | diagnostics]}
  end

  defp lower_rung({:rung, elements}, diagnostics, known) do
    {ir, diagnostics} = lower(elements, [], diagnostics, known)
    {{:rung, ir}, diagnostics}
  end

  # Diagnostics are accumulated newest first and reversed once, in instructionize/2. An
  # undeclared tag is accumulated as `{:undeclared, line, name, slot}`, with the slot it is
  # used in or `:member`, and reported by undeclared/3, at its first use only.
  defp lower([], ir, diagnostics, _known), do: {Enum.reverse(ir), diagnostics}

  defp lower([{:branches, legs} | rest], ir, diagnostics, known) do
    {legs, diagnostics} = Enum.map_reduce(legs, diagnostics, &lower(&1, [], &2, known))
    lower(rest, [{:branches, legs} | ir], diagnostics, known)
  end

  defp lower([{:name, line, word} | rest], ir, diagnostics, known) do
    key = String.downcase(word)
    lower_word(Map.fetch(@instructions, key), key, {line, word}, {rest, ir, diagnostics, known})
  end

  # The grammar allows a literal anywhere an element can go, including where an
  # instruction must start: `123 aa`, or an extra operand as in `xic aa 7 ote bb`.
  defp lower([{:int_lit, line, value} | rest], ir, diagnostics, known) do
    found = diagnostic(line, "expected an instruction, found `#{value}`")
    lower(skip_operands(rest), ir, [found | diagnostics], known)
  end

  # M2-5: `cal`, whose signature is its instance's type's, looked up before its other
  # operands are taken.
  defp lower_word({:ok, {:cal, :block}}, _key, at, {rest, ir, diagnostics, known}) do
    {instance, after_instance} = take_operands(rest, 1, [])
    cal(instance, at, {after_instance, ir, diagnostics, known})
  end

  defp lower_word(
         {:ok, {symbol, signature}},
         _key,
         {line, _} = at,
         {rest, ir, diagnostics, known}
       ) do
    {scope, _folded} = known
    {operands, rest} = take_operands(rest, length(signature), [])
    diagnostics = check_count(signature, operands, rest, at, diagnostics)
    diagnostics = check_kinds(signature, operands, at, diagnostics)
    diagnostics = check_tags(signature, operands, at, scope, diagnostics)
    diagnostics = check_preset(signature, operands, at, known, diagnostics)
    lower(rest, [{symbol, line, Enum.map(operands, &operand/1)} | ir], diagnostics, known)
  end

  defp lower_word(:error, key, {line, word}, {rest, ir, diagnostics, known}) do
    unknown = diagnostic(line, unknown(key, word))
    lower(skip_operands(rest), ir, [unknown | diagnostics], known)
  end

  # `cal` with no instance before the next instruction, a group or the end of its leg.
  defp cal([], {line, word}, {rest, ir, diagnostics, known}) do
    message = "`#{word}` expects an instance of a function block, found none" <> stopped_at(rest)
    lower(rest, ir, [diagnostic(line, message) | diagnostics], known)
  end

  defp cal([{:int_lit, _, value}], {line, word}, {rest, ir, diagnostics, known}) do
    message = "`#{word}` expects an instance of a function block, found `#{value}`"
    lower(skip_operands(rest), ir, [diagnostic(line, message) | diagnostics], known)
  end

  defp cal([{:name, _, name} = instance], at, {rest, ir, diagnostics, known}) do
    {scope, _folded} = known

    runs(
      Declarations.reserved(name),
      lookup(name, scope),
      instance,
      at,
      {rest, ir, diagnostics, known}
    )
  end

  # The instance of a user block: its operands taken, each checked against the formal it
  # fills, and lowered as any instruction is.
  defp runs(nil, {:ok, %Tag{type: %FbType{body: %Program{}} = type}}, instance, at, state) do
    {rest, ir, diagnostics, known} = state
    {line, _word} = at
    {scope, _folded} = known
    [_instance | formals] = FbType.signature(type)
    {operands, rest} = take_operands(rest, length(formals), [])
    diagnostics = cal_count(formals, operands, rest, instance, diagnostics)
    diagnostics = cal_operands(formals, operands, {at, instance}, scope, diagnostics)
    lowered = {:cal, line, [instance | Enum.map(operands, &operand/1)]}
    lower(rest, [lowered | ir], diagnostics, known)
  end

  # Anything else is not run by `cal`, and its would-be operands are passed over: a timer,
  # which its `ton` runs; a bool or a dint; a member; a reserved word; or a name no
  # declaration gives, reported once as undeclared.
  defp runs(reserved, found, {:name, line, name}, {_, word}, {rest, ir, diagnostics, known}) do
    lower(
      skip_operands(rest),
      ir,
      not_run(reserved, found, line, name, word) ++ diagnostics,
      known
    )
  end

  defp not_run(nil, :error, line, name, _word), do: [{:undeclared, line, name, :block}]

  defp not_run(nil, {:undeclared, head}, line, _name, _word),
    do: [{:undeclared, line, head, :member}]

  defp not_run(nil, {:ok, %Tag{type: %FbType{name: type}} = tag}, line, name, word),
    do: [
      diagnostic(
        line,
        "`#{word}` runs an instance of a user function block, but `#{name}` is a " <>
          "#{type}#{declared(tag)}, which `#{type} #{name}` and its preset run"
      )
    ]

  defp not_run(nil, {:ok, tag}, line, name, word),
    do: [
      diagnostic(
        line,
        "`#{word}` runs an instance of a function block, but `#{name}` is a " <>
          "#{tag.type}#{declared(tag)}"
      )
    ]

  defp not_run(nil, _member, line, name, word),
    do: [
      diagnostic(
        line,
        "`#{word}` runs an instance of a function block, named whole: found `#{name}`"
      )
    ]

  defp not_run(reserved, _found, line, name, word),
    do: [
      diagnostic(
        line,
        "`#{word}` expects an instance of a function block, found #{reserved_word(reserved)} " <>
          "`#{name}`"
      )
    ]

  defp reserved_word(:mnemonic), do: "the instruction"
  defp reserved_word(:type), do: "the type"
  defp reserved_word(:section), do: "the keyword"

  # docs/organisation.md §4.3: an arity error names every formal, in order.
  defp cal_count(formals, operands, _rest, _instance, diagnostics)
       when length(operands) == length(formals),
       do: diagnostics

  defp cal_count(formals, operands, rest, {:name, line, instance}, diagnostics) do
    message =
      "`cal #{instance}` expects #{operand_count(length(formals))} after its instance, " <>
        "#{Enum.map_join(formals, ", then ", &formal/1)}: found #{found(length(operands))}" <>
        stopped_at(rest)

    [diagnostic(line, message) | diagnostics]
  end

  defp formal({_slot, %Member{name: name, role: role, type: type}}),
    do: "`#{name}` (#{section(role)} #{type})"

  defp section(:input), do: "var_input"
  defp section(:output), do: "var_output"

  # Each operand against the formal it fills, which an error names: ``operand 2 of `cal s1`
  # is `stop` (var_input bool)`` (docs/organisation.md §4.3). A tag or member of the wrong
  # type, a literal where the block writes, a var_input or a member logic may not write
  # where it writes, and an instance named whole. A reserved word, an undeclared name and a
  # dotted name that is no member are reported as any instruction's are.
  defp cal_operands(formals, operands, at, scope, diagnostics),
    do:
      formals
      |> Enum.zip(operands)
      |> Enum.with_index(1)
      |> Enum.reduce(diagnostics, fn {{formal, operand}, n}, acc ->
        cal_operand(formal, operand, {n, at}, scope, acc)
      end)

  defp cal_operand(
         {{:value, type}, _} = formal,
         {:int_lit, line, value},
         at,
         _scope,
         diagnostics
       ),
       do: fits_formal(Declarations.fits?(type, value), formal, value, {line, at}, diagnostics)

  defp cal_operand({{:write, _}, _} = formal, {:int_lit, line, value}, at, _scope, diagnostics),
    do: [
      diagnostic(line, of_formal(formal, at) <> ", which it writes: found `#{value}`")
      | diagnostics
    ]

  defp cal_operand({slot, _} = formal, {:name, line, name} = operand, at, scope, diagnostics),
    do:
      by_formal(
        Declarations.reserved(name),
        lookup(name, scope),
        {formal, slot, operand},
        {line, at},
        {scope, diagnostics}
      )

  defp fits_formal(true, _formal, _value, _at, diagnostics), do: diagnostics

  defp fits_formal(false, {{_, :bool}, _} = formal, value, {line, at}, diagnostics),
    do: [
      diagnostic(line, of_formal(formal, at) <> ": only 0 or 1 fit, found `#{value}`")
      | diagnostics
    ]

  defp fits_formal(false, formal, value, {line, at}, diagnostics),
    do: [
      diagnostic(line, of_formal(formal, at) <> ": `#{value}` does not fit in 32 bits")
      | diagnostics
    ]

  defp by_formal(
         nil,
         {:ok, %Tag{type: %FbType{} = type} = tag},
         {formal, _, _},
         {line, at},
         {_, d}
       ),
       do: [
         diagnostic(
           line,
           of_formal(formal, at) <>
             ", but `#{tag.name}` is #{Declarations.instance_of(type)}#{declared(tag)}: " <>
             "name one of its members"
         )
         | d
       ]

  defp by_formal(nil, {:ok, %Tag{} = tag}, {formal, {access, type}, _}, {line, at}, {_, d}),
    do:
      d
      |> typed_formal(type, tag.type, tag.name, {formal, line, at})
      |> input_formal(access, tag, {formal, line, at})

  defp by_formal(
         nil,
         {:member, tag, member},
         {formal, {access, type}, {:name, _, name}},
         {line, at},
         {_, d}
       ),
       do:
         d
         |> typed_formal(type, member.type, name, {formal, line, at})
         |> member_formal(access, tag, member, name, {formal, line, at})

  defp by_formal(
         reserved,
         found,
         {_formal, slot, operand},
         {line, {_n, {_at, _instance}}},
         {_scope, d}
       ),
       do: resolve(reserved, found, slot, operand, {line, "cal"}, d)

  defp typed_formal(diagnostics, type, type, _name, _at), do: diagnostics

  defp typed_formal(diagnostics, _type, found, name, {formal, line, at}),
    do: [diagnostic(line, of_formal(formal, at) <> ", but `#{name}` is a #{found}") | diagnostics]

  defp input_formal(diagnostics, :write, %Tag{section: :var_input} = tag, {formal, line, at}),
    do: [
      diagnostic(
        line,
        of_formal(formal, at) <>
          ", which it writes: `#{tag.name}` is a var_input#{declared(tag)}, and logic must not " <>
          "write an input"
      )
      | diagnostics
    ]

  defp input_formal(diagnostics, _access, _tag, _at), do: diagnostics

  defp member_formal(diagnostics, :write, tag, %Member{write: false}, name, {formal, line, at}),
    do: [
      diagnostic(line, of_formal(formal, at) <> ", which it writes: " <> unwritable(tag, name))
      | diagnostics
    ]

  defp member_formal(diagnostics, _access, _tag, _member, _name, _at), do: diagnostics

  defp of_formal({_slot, %Member{} = member}, {n, {_at, {:name, _, instance}}}),
    do: "operand #{n} of `cal #{instance}` is #{formal({nil, member})}"

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

  # M2-5: the word that heads a function block's file is a line of its own, its first.
  defp unknown("function_block", word),
    do: "`#{word}` heads a function block's file, as its first line"

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
  defp check_preset(
         [_, {:preset, _}],
         [first, {:name, line, name}],
         {_, word},
         known,
         diagnostics
       ) do
    message =
      "`#{word}` takes its preset as a number of milliseconds, found `#{name}`" <>
        moved(first, name, known)

    [diagnostic(line, message) | diagnostics]
  end

  defp check_preset(_signature, _operands, _at, _known, diagnostics), do: diagnostics

  # The `move` is named only where it would compile, once a name in it not declared yet is
  # declared: into a timer's `.pre`, from a dint. One name is never both, nor are two that
  # differ only in case (Logex.Declarations), so `ton b b` and `ton b B` have none.
  defp moved({:name, _, timer}, name, known),
    do: moved(String.downcase(timer) == String.downcase(name), timer, name, known)

  defp moved(_literal, _name, _known), do: ""

  defp moved(true, _timer, _name, _known), do: ""

  defp moved(false, timer, name, known),
    do: move(timer?(timer, known) and dint?(name, known), timer, name)

  defp move(true, timer, name),
    do: ": to preset `#{timer}` from a tag, `move #{name} #{timer}.pre` on a rung above"

  defp move(false, _timer, _name), do: ""

  defp dint?(name, known), do: dint_value?(Declarations.reserved(name), hinted(name, known))

  defp dint_value?(nil, {:ok, %Tag{type: :dint}}), do: true
  defp dint_value?(nil, {:member, _tag, %Member{type: :dint}}), do: true
  defp dint_value?(nil, :error), do: true
  defp dint_value?(_reserved, _found), do: false

  # M1-3: each operand against the tag table -- declared, of the type its slot reads or
  # writes, and not a var_input where the slot writes. A literal where a tag must go was
  # reported by check_kind/4 and is not looked at again. Then the `:any` operands must agree.
  defp check_tags(signature, operands, at, scope, diagnostics) do
    slots = Enum.zip(signature, operands)
    diagnostics = Enum.reduce(slots, diagnostics, &check_tag(&1, at, scope, &2))

    unify(
      for({{access, :any}, operand} <- slots, typed = typed(access, operand, scope), do: typed),
      at,
      diagnostics
    )
  end

  # A literal in a dint slot must fit 32 bits, as a declared initial value must (M1-6: the
  # comparisons). An `:any` slot's literal is checked against the tag beside it, by unify/3.
  # Until PLAN.md §5's negative literals lex, Logex.Parser.well_formed!/1 refuses one on
  # entry (OE-1), so this and unify/3 meet only a literal too large, never one too small;
  # the lower ends are kept for them.
  defp check_tag({{:value, :dint}, {:int_lit, line, value}}, {_, word}, _scope, diagnostics),
    do: literal(Declarations.fits?(:dint, value), value, {line, word}, diagnostics)

  # A preset is a dint number of milliseconds, and never negative (docs/naming.md, `ton`).
  # Only a preset too large reaches this until a negative literal lexes, as above.
  defp check_tag({{:preset, _}, {:int_lit, line, value}}, {_, word}, _scope, diagnostics),
    do: preset(Declarations.preset?(value), value, {line, word}, diagnostics)

  defp check_tag({_slot, {:int_lit, _, _}}, _at, _scope, diagnostics), do: diagnostics

  # Reported by check_preset/4, and never looked up.
  defp check_tag({{:preset, _}, {:name, _, _}}, _at, _scope, diagnostics), do: diagnostics

  defp check_tag({slot, {:name, _, name} = operand}, at, scope, diagnostics),
    do: resolve(Declarations.reserved(name), lookup(name, scope), slot, operand, at, diagnostics)

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
  defp lookup(name, scope), do: lookup_parts(String.split(name, "."), scope)

  defp lookup_parts([name], {tags, _members}), do: Map.fetch(tags, name)

  defp lookup_parts([head | parts], {tags, members}),
    do: owned(Map.fetch(tags, head), head, parts, members)

  defp owned(:error, head, _parts, _members), do: unowned(Declarations.reserved(head), head)

  defp owned({:ok, %Tag{type: %FbType{name: type}} = tag}, _head, [part | deeper], members),
    do: in_type(Map.fetch(Map.fetch!(members, type), part), tag, part, deeper)

  defp owned({:ok, tag}, _head, [part], _members), do: {:no_members, tag, part}

  # Past a bit, as past a member, a path goes too deep: `d.3.x`, as `t1.acc.3.x`.
  defp owned({:ok, tag}, _head, [part | _deeper], _members),
    do: beyond(Integer.parse(part), tag, part)

  # A word that can never be declared is not reported as undeclared: `ton.dn`, `bool.3`.
  defp unowned(nil, head), do: {:undeclared, head}
  defp unowned(reserved, head), do: {:reserved, reserved, head}

  defp in_type({:ok, member}, tag, _part, []), do: {:member, tag, member}
  defp in_type({:ok, member}, tag, _part, [next]), do: past(Integer.parse(next), tag, member)
  defp in_type({:ok, member}, tag, _part, _deeper), do: {:too_deep, tag, member}
  defp in_type(:error, tag, part, _deeper), do: {:unknown_member, tag, part}

  # `t1.acc.3` is bit access of a member, as `d.3` is of a tag; `t1.acc.3.x` goes too deep,
  # as it will when bit access lands.
  defp past({_bit, ""}, tag, member), do: {:member_bit, tag, member}
  defp past(_not_a_bit, tag, member), do: {:too_deep, tag, member}

  defp beyond({_bit, ""}, tag, _part), do: {:past_bit, tag}
  defp beyond(_not_a_bit, tag, part), do: {:no_members, tag, part}

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
      "`#{name}` begins with `#{head}`, #{reserved_as(reserved)}, which cannot name a tag"

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
      "`#{word}` #{verb(access)} #{a_type(slot_type)}, but `#{tag.name}` is " <>
        "#{Declarations.instance_of(type)}#{declared(tag)}" <>
        example(fitting(access, slot_type, type), tag)

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
      "`#{name}` is not a member of `#{tag.name}`, #{Declarations.instance_of(tag.type)}" <>
        members(suggestion, names)

    [diagnostic(line, message) | diagnostics]
  end

  defp resolve(nil, {:no_members, tag, part}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, no_members(Integer.parse(part), name, tag)) | diagnostics]

  defp resolve(nil, {:past_bit, tag}, _slot, {:name, line, name}, _at, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{name}` goes too deep: `#{tag.name}` is a #{tag.type}, which has no members"
      )
      | diagnostics
    ]

  defp resolve(nil, {:member_bit, tag, member}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, bit(name, "#{tag.name}.#{member.name}", member.type)) | diagnostics]

  defp resolve(nil, {:too_deep, tag, member}, _slot, {:name, line, name}, _at, diagnostics) do
    message =
      "`#{name}` goes too deep: `#{tag.name}.#{member.name}` is a #{member.type}, " <>
        "which has no members"

    [diagnostic(line, message) | diagnostics]
  end

  # A user block may show no member outside it (M2-5).
  defp members("", []), do: ": it has none that logic outside it may name"
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
        "#{declared(tag)}: only an instance of a function block has members"

  # Bit access, when it lands, reaches a bit of a word; a bool is one bit, and has none.
  defp bit(name, word, :bool), do: "`#{name}` names a bit of `#{word}`, a bool, which has no bits"

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
    [diagnostic(line, "`#{word}` writes `#{name}`, but " <> unwritable(tag, name)) | diagnostics]
  end

  defp check_member_write(diagnostics, _slot, _tag, _name, _member, _at), do: diagnostics

  # Decision 9 for a ton; decision 33 for a user block: logic outside it writes none of its
  # members, which only its body writes.
  defp unwritable(%Tag{type: type} = tag, _name),
    do: unwritable(FbType.writable(type), type, tag)

  defp unwritable([], type, tag),
    do: "`#{tag.name}` is #{Declarations.instance_of(type)}, whose members only its body writes"

  defp unwritable(writable, type, _tag),
    do: "logic may write only #{listed(Enum.map(writable, &"`.#{&1.name}`"))} of a #{type.name}"

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

  defp typed(_access, {:int_lit, _, value}, _scope), do: {:literal, value}
  defp typed(access, {:name, _, name}, scope), do: typed_ref(access, lookup(name, scope))

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
    runs = Map.new(for {:undeclared, _, name, {:instance, _} = slot} <- found, do: {name, slot})
    acc = {MapSet.new(), note?}
    {diagnostics, _} = Enum.flat_map_reduce(found, acc, &report(&1, &2, {tags, runs}))
    diagnostics
  end

  # A name an instruction runs anywhere, as `ton` runs a timer, is shown the declaration
  # that fits it, whatever its first use.
  defp report({:undeclared, line, name, slot}, {seen, _} = acc, {tags, runs}),
    do: first_use(MapSet.member?(seen, name), line, {name, Map.get(runs, name, slot)}, tags, acc)

  defp report(%Diagnostic{} = diagnostic, acc, _context), do: {[diagnostic], acc}

  defp first_use(true, _line, _name, _tags, acc), do: {[], acc}

  # A member of an undeclared name reports the name (M1-6), but unless an instruction runs
  # it, is not told how to declare it, since the name is likely an instance's and not a
  # bool's or a dint's: the note waits for the next undeclared name reported.
  defp first_use(false, line, {name, slot}, tags, {seen, note?}) do
    message =
      "`#{name}` is not declared" <>
        Declarations.suggest(name, Map.keys(tags)) <> how(note?, slot, name)

    {[diagnostic(line, message)], {MapSet.put(seen, name), note? and slot == :member}}
  end

  defp how(false, _slot, _name), do: ""
  defp how(true, :member, _name), do: ""
  defp how(true, {:instance, type}, name), do: note("`var #{name} #{type}`")
  defp how(true, :block, _name), do: ""
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
