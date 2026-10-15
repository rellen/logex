defmodule Logex.Compiler do
  @moduledoc """
  The stages from a routine's text to a program type (M1-2, M1-3, M1-6, M2-5).

  `tokenize/1` and `parse/1` are `Logex.Lexer`'s and `Logex.Parser`'s. `instructionize/3`
  takes the parse tree, first checking it against `Logex.Parser.well_formed!/1` and
  raising `ArgumentError` on a tree no text could say (OE-1); takes the declaration lines
  off into a tag table, with any tags declared from Elixir (`Logex.Tag.new!/4`); checks
  every instruction against its operand signature, `instructions/0`, and every operand
  against the table, members included; and returns `{:ok, %Logex.Program{}}`, its
  warnings included, `{:ok, %Logex.FbType{}}` for a routine headed `function_block
  <name>`, or `{:error, [%Logex.Diagnostic{}]}`, every mistake in the routine, in line
  order. The function block types a routine may hold are given as its third argument,
  each checked at full depth. Since M3-5 it checks a routine's labels and jumps too: each
  `lbl` first on its rung, one label to a rung, and each `jmp` naming a label of its own
  routine on a later rung, one to a rung (decisions 81, 104 and 105).

  A host compiles through `Logex.compile/2` and `Logex.compile_file/1`. The stage
  functions stay public for the front end's golden record, the Elixir-side declarer and
  the naming test; `signature/2` for the walks (`Logex.Walk`), which look an instruction's
  slots up here; and `lowered?/1` and `recompiled/4` for the check of a type given
  (`Logex.FbType.user?/1`, decision 54).
  """

  alias Logex.{Declarations, Diagnostic, FbType, Program, Tag, Walk}
  alias Logex.FbType.Member

  defdelegate tokenize(source), to: Logex.Lexer
  defdelegate parse(tokens), to: Logex.Parser

  # Each mnemonic's operand signature, in order, one `{access, type}` per operand. Access:
  # `:read` and `:write` must be a tag, and `:value` may be a tag or an integer literal.
  # M1-6 adds two: `{:instance, type}` is an instance of that function block type, which
  # the instruction runs, the only slot where an instance is named whole; `:preset` is a
  # literal number, 0 to 2147483647, of milliseconds for a timer and a count for a counter;
  # since M3-1 an instance slot names a list where it runs instances of several types. M3-5
  # adds `{:label, nil}`, a label of the routine's own, a namespace that holds no tag, which
  # the IR keeps as `{:label, line, name}`.
  # Type: `:bool`, `:dint`, or `:any`,
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
    # M3-4: IEC's transition-sensing coils in the conventional set's form (decision 80):
    # the storage bit, which an `ons` would keep, then the pulse bit, two bools each run
    # writes, `osr` pulsing on the rising edge of the power it receives and `osf` on the
    # falling, and passing that power on (decision 100).
    "osr" => {:osr, [{:write, :bool}, {:write, :bool}]},
    "osf" => {:osf, [{:write, :bool}, {:write, :bool}]},
    "eq" => {:eq, [{:value, :dint}, {:value, :dint}]},
    "ne" => {:ne, [{:value, :dint}, {:value, :dint}]},
    "lt" => {:lt, [{:value, :dint}, {:value, :dint}]},
    "gt" => {:gt, [{:value, :dint}, {:value, :dint}]},
    "le" => {:le, [{:value, :dint}, {:value, :dint}]},
    "ge" => {:ge, [{:value, :dint}, {:value, :dint}]},
    "ton" => {:ton, [{:instance, "ton"}, {:preset, :dint}]},
    # M3-2: the off-delay timer, rung power its IN, the preset its starting `.pre` in ms.
    "tof" => {:tof, [{:instance, "tof"}, {:preset, :dint}]},
    # M3-2: the pulse timer, rung power its IN, the preset its starting `.pre` in ms.
    "tp" => {:tp, [{:instance, "tp"}, {:preset, :dint}]},
    # M3-2: the retentive timer, rung power its IN, the preset its starting `.pre` in ms.
    "rto" => {:rto, [{:instance, "rto"}, {:preset, :dint}]},
    # M3-1: IEC's counters (decision 67). Rung power is the count input of the counter's
    # side the mnemonic names, `cu` or `cd`, and the preset is its starting `pv`, a count.
    # An instance slot may take several types, a list: a `ctud` is run by one of each
    # (decision 85).
    "ctu" => {:ctu, [{:instance, ["ctu", "ctud"]}, {:preset, :dint}]},
    "ctd" => {:ctd, [{:instance, ["ctd", "ctud"]}, {:preset, :dint}]},
    # M3-3: IEC's arithmetic on dints (decision 79), two sources, each a tag, a member or a
    # literal, then the destination it writes: `add total flow total`, `sub a b d` being
    # a - b. Rung power is IEC's EN and the power out its ENO (decision 98): false where the
    # result leaves the dint, which stops at the nearer limit (decision 77).
    "add" => {:add, [{:value, :dint}, {:value, :dint}, {:write, :dint}]},
    "sub" => {:sub, [{:value, :dint}, {:value, :dint}, {:write, :dint}]},
    "mul" => {:mul, [{:value, :dint}, {:value, :dint}, {:write, :dint}]},
    # M3-3: `div a b d` is a / b truncated toward zero, and `mod a b d` its remainder, the
    # dividend's sign. A zero divisor gives 0 and no power (decision 78); a literal one is
    # refused.
    "div" => {:div, [{:value, :dint}, {:value, :dint}, {:write, :dint}]},
    "mod" => {:mod, [{:value, :dint}, {:value, :dint}, {:write, :dint}]},
    # M3-3: `neg a d` is 0 - a, the vendors' NEG, and `abs a d` IEC's ABS: one source, then
    # the destination. The most negative dint has no positive twin, so it alone overflows.
    "neg" => {:neg, [{:value, :dint}, {:write, :dint}]},
    "abs" => {:abs, [{:value, :dint}, {:write, :dint}]},
    # M3-5: the forward jump (decisions 81 and 104): `jmp done` names the label that a later
    # rung of its routine begins with, `lbl done`, and passes on the power it receives. A
    # label is a name of the routine's own, never a tag (decision 105).
    "jmp" => {:jmp, [{:label, nil}]},
    "lbl" => {:lbl, [{:label, nil}]},
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
  per operand, in order, its mnemonic's signature in `instructions/0`. The one walk that
  reads a program's IR for what each operand does, `Logex.Walk`, which `Logex.Warnings`
  and `Logex.Edit` read, looks every instruction's slots up here, never in a table of its
  own (M2-5, M2-4).

  The slots are per instruction, given `tags`, the tag table of the program that holds it,
  so that an instruction's slots may depend on what its operands name: a `cal`'s are its
  instance's type's, `Logex.FbType.signature/1`'s, the instance first and then a slot per
  formal, so a var_output it fills is written. In a compiled program or body, whose
  instances name their types (decision 53), the table is `Logex.Program.typed_tags/1`'s,
  each instance's type itself.
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
  `Logex.Parser.parse/1` could not have produced, such as an empty group, a literal that
  is no integer or a rung over two lines, raises `ArgumentError`, a host mistake, since no
  source text says it and no diagnostic could cite it (OE-1). Then `declared`.
  """
  def instructionize(routine, declared \\ [], types \\ []) do
    {:routine, {:rungs, rungs}} = Logex.Parser.well_formed!(routine)
    {library, held, checked} = library!(types)
    {kind, rungs, heading} = file_kind(rungs)
    marks = marked(kind, library, held)

    {tags, _logic, _declaring, _untyped} =
      split = Declarations.split(rungs, declared, marks, checked)

    holds_itself!(kind, declared)
    {held, _walked, :tags} = Enum.reduce(blocks(tags), {held, %{}, :tags}, &one_version!/2)
    {rungs, tags, diagnostics} = lowering(routine, {kind, heading}, split)
    lowered(kind, rungs, {tags, held}, diagnostics, routine)
  end

  # The rungs lowered over the tag table, each timer given its preset, and every
  # diagnostic, a compile's and a recompile's alike (recompiled/4).
  defp lowering(routine, {kind, heading}, {tags, logic, declaring, untyped}) do
    known = {scope(tags), folded(tags)}
    {rungs, lowering} = Enum.map_reduce(logic, [], &lower_rung(&1, &2, known))
    note? = map_size(tags) == 0 and declares_nothing?(routine, logic)
    instructions = Walk.instructions(rungs)
    shared = shared_bits(instructions, tags)
    {tags, timing} = presets(instructions, tags)
    calls = calls(instructions)
    paths = Enum.flat_map(rungs, fn {:rung, elements} -> path(elements, known) end)
    found = Enum.reject(Enum.reverse(lowering), &excused?(&1, untyped))
    errors = declaring ++ undeclared(found, tags, note?) ++ shared ++ timing

    {rungs, tags,
     heading ++
       header_tags(kind, tags) ++
       externals(kind, tags) ++ errors ++ calls ++ paths ++ jumps(rungs, kind)}
  end

  @doc """
  The body a function block's source text compiles to (decision 54): `{:ok, body}`, the
  `%Logex.Program{}` `Logex.compile/2` gives as the type's `body` for `source` under the
  name `name`, as an outermost type's table holds it (`Logex.FbType.held/1`), or `:error`
  where the text is no such block's, does not lex or parse, or gives any diagnostic.
  `held` are the user block types its declaration lines may name, by name, each as it
  reads inside the table that holds it (`Logex.FbType.within/2`).

  Those types are trusted, as checked already: none is checked, marked for recursion or
  compared with another version, and no table is built, so each instance's tag names its
  type and `blocks` is empty. A type whose text names one `held` lacks, its own name among
  them, gives the diagnostic a compile gives for an unknown type. `declared` are the
  block's members declared from Elixir, which a block `instructionize/3` built keeps no
  text for; a tag among them no host could give is `:error`. `source` and `file` are nil,
  and so is each warning's file: they are the caller's to give. It is how
  `Logex.FbType.check/2` asks that each type a compile is given be the one its source
  gives, once a type, in time linear in the source and the members of the types it names.
  """
  def recompiled(source, name, held, declared \\ [])

  def recompiled(source, name, held, declared)
      when is_binary(source) and is_map(held) and is_list(declared),
      do: retokenized(tokenize(source), name, {held, declared})

  def recompiled(_source, _name, _held, _declared), do: :error

  defp retokenized({:ok, tokens, _end_line}, name, given),
    do: reparsed(parse(tokens), name, given)

  defp retokenized(_error, _name, _given), do: :error

  defp reparsed({:ok, {:routine, {:rungs, rungs}} = routine}, name, {held, declared}) do
    {kind, rungs, heading} = file_kind(rungs)

    {rungs, tags, diagnostics} =
      lowering(routine, {kind, heading}, Declarations.split(rungs, declared, held))

    rebuilt(kind, name, {rungs, tags}, diagnostics)
  rescue
    # A tag declared from Elixir that no host could have given: no such body.
    ArgumentError -> :error
  end

  defp reparsed(_error, _name, _given), do: :error

  defp rebuilt({:block, name}, name, {rungs, tags}, []) do
    {named, _reached} = Enum.map_reduce(tags, [], &naming/2)

    {:ok,
     %Program{
       name: name,
       rungs: rungs,
       tags: Map.new(named),
       warnings: Logex.Warnings.of(rungs, tags)
     }}
  end

  defp rebuilt(_kind, _name, _lowered, _diagnostics), do: :error

  @doc """
  Whether `body`'s rungs, tags and warnings are exactly what `instructionize/3` gives for
  some text over that tag table (M2-5): every rung lowers again, through the checks a
  compile makes, to itself, with no diagnostic; the one-per-bit, one-per-timer and
  one-per-instance rules and the path after a `ton` hold; each timer's preset is the
  number on the `ton` that runs it; the rungs are on rising lines, each on one line, after
  the declarations; and the warnings are the ones its rungs give, a file aside. Its tag
  table is its tags with each instance's type itself (`Logex.Program.typed_tags/1`): a
  tag naming a type its `blocks` does not hold, or an entry that is no `%Logex.Tag{}`,
  makes it no compiled body.

  It is the definition of a compiled body, as `Logex.Parser.well_formed!/1` is of a parse
  tree, which every type given to a compile or to `Logex.Tag.new!/4` has. Until decision
  54 it was the check `Logex.FbType.user?/1` made of a type's body; that check now asks
  more, that the body be the one its own source text compiles to (`recompiled/4`), which
  implies this, so nothing calls it on the way in. It expects its tag table checked
  already, every tag under its own name and every instance's type, once each held type is
  given, the built-in `ton` or a type the table of a type `Logex.FbType.user?/1` takes
  holds, its members what `Logex.FbType.of/1` gives. Over such a table it is total, `true`
  or `false` and never an exception, and so it is for a value that is no
  `%Logex.Program{}`, or whose rungs, tags, blocks or warnings are no list, map, map and
  list, or whose tags are a struct. A direct call given another table, such as a tag under
  a key that is no string or an instance whose type's members are no list of members, may
  raise.
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
    instructions = Walk.instructions(rungs)
    {timed, timing} = presets(instructions, unpreset(tags))

    map_size(elem(known, 1)) == map_size(tags) and
      Enum.all?(rungs, &lowers_to_itself?(&1, known)) and
      shared_bits(instructions, tags) == [] and calls(instructions) == [] and timing == [] and
      jumps(rungs, :program) == [] and timed == tags and
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
    do: is_integer(value)

  defp ir_operand?({:member, line, path}) when is_integer(line) and line > 0,
    do: proper?(path, &is_binary/1)

  defp ir_operand?({:label, line, name}) when is_integer(line) and line > 0, do: is_binary(name)

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
  defp unlowered_operand({:label, line, name}), do: {:name, line, name}
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

  defp rung_lines({:rung, _elements} = rung),
    do: [rung] |> Walk.instructions() |> Enum.flat_map(&lines_of/1) |> Enum.uniq()

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

  # M2-4: a block's file refuses `var_external`, though IEC allows it (docs/naming.md,
  # `var_external`), deliberately and reversibly: a block's body runs over its instance's
  # own state, which holds no global, so a block takes a global through a var_input its
  # `cal` fills. Refused before the block's type is built, whose members are its var_inputs,
  # var_outputs and vars (Logex.FbType.of/1). A tag declared from Elixir, which no line can
  # cite, is refused as a host mistake, as header_tags/2's is.
  defp externals({:block, _name}, tags),
    do: for({name, %Tag{section: :var_external, line: line}} <- tags, do: external(line, name))

  defp externals(:program, _tags), do: []

  defp external(nil, name), do: raise(ArgumentError, external_message(name))
  defp external(line, name), do: diagnostic(line, external_message(name))

  defp external_message(name),
    do:
      "`#{name}` cannot be a var_external in a function block's file: a block reaches no " <>
        "global of a configuration, so it takes one through a var_input, which the `cal` " <>
        "that runs it fills"

  # Recursion through a tag declared from Elixir, which no line can cite: a host mistake.
  # A type holds every type below it in its one table (decision 53), so whether it holds
  # the block being compiled, at any depth, is one lookup.
  defp holds_itself!({:block, name}, declared) when is_binary(name),
    do: Enum.each(declared, &itself!(&1, name))

  defp holds_itself!(_kind, _declared), do: :ok

  defp itself!(%Tag{name: tag, type: %FbType{} = type}, name),
    do: held_by!(holds?(type, name), tag, name)

  defp itself!(_tag, _name), do: :ok

  defp held_by!(true, tag, name),
    do:
      raise(
        ArgumentError,
        "`#{tag}` holds an instance of `#{name}`, the function block being compiled: " <>
          "a function block never holds an instance of itself, at any depth"
      )

  defp held_by!(false, _tag, _name), do: :ok

  # Whether `type` is, or holds at any depth, a type named `name`.
  defp holds?(%FbType{name: name}, name), do: true
  defp holds?(%FbType{body: %Program{blocks: blocks}}, name), do: is_map_key(blocks, name)
  defp holds?(%FbType{body: nil}, _name), do: false

  # One mistake, one message: a declaration refused for its type word, one no compile knows
  # or one that would hold the block being compiled, declares nothing, and its uses are
  # excused rather than each reported as undeclared (Logex.Declarations.split/3), so a
  # misspelled block name gives one message (M2-5).
  defp excused?({:undeclared, _line, name, _slot}, untyped), do: MapSet.member?(untyped, name)
  defp excused?(_diagnostic, _untyped), do: false

  # The blocks a compile is given: a proper list of user types, each one Logex.compile/2
  # gave, and no two of one name, each type their tables share checked once
  # (Logex.FbType.check/2). A host mistake otherwise. `{library, held, checked}`: the types
  # by name, for the declaration lines; every block they are or hold at any depth by name,
  # in its held form, the one version of each, which the tags declared from Elixir are then
  # checked against, and from which a compiled program or body takes its table; and what
  # the check compiled again, so that the tags declared from Elixir compile again no type
  # it did (Logex.Declarations.split/4).
  defp library!(types) when is_list(types), do: listed!(proper?(types, &any?/1), types)
  defp library!(types), do: listed!(false, types)

  defp listed!(true, types) do
    {library, checked} =
      Enum.reduce(types, {%{}, %{}}, fn type, {library, checked} ->
        given!(FbType.check(type, checked), type, library)
      end)

    seen = Map.new(library, fn {name, type} -> {name, FbType.held(type)} end)

    {held, _walked, :types} =
      Enum.reduce(Map.values(library), {seen, %{}, :types}, &one_version!/2)

    {library, held, checked}
  end

  defp listed!(false, types),
    do:
      raise(
        ArgumentError,
        "types must be a list of function block types from Logex.compile/2, got: " <>
          inspect(types)
      )

  defp given!({:ok, checked}, %FbType{name: name} = type, library)
       when not is_map_key(library, name),
       do: {Map.put(library, name, type), checked}

  defp given!({:ok, _checked}, %FbType{name: name}, _library),
    do:
      raise(ArgumentError, "types holds two function blocks named `#{name}`: one name, one type")

  defp given!(:error, type, _library),
    do:
      raise(
        ArgumentError,
        "types must be function block types from Logex.compile/2, got: #{inspect(type)}"
      )

  defp blocks(tags), do: for({_, %Tag{type: %FbType{body: %Program{}} = type}} <- tags, do: type)

  # Every block a given type holds, at any depth, is the one given under its name where one
  # is, and one version with every other of its name: a program holds one type of each
  # name, in its one table (decision 53), which the edit's rules (Logex.Edit) and the
  # runtime's lookups by name rely on. A type and each type its table holds are compared in
  # their held forms, one name at a time, and a type walked once is not walked again,
  # however many tags hold it. `from` says where the types walked came from, `:types` or
  # `:tags`, for the message.
  defp one_version!(%FbType{name: name} = type, {_seen, walked, _from} = acc)
       when is_map_key(walked, name) and :erlang.map_get(name, walked) === type,
       do: acc

  defp one_version!(
         %FbType{name: name, body: %Program{blocks: blocks}} = type,
         {seen, walked, from}
       ),
       do:
         Enum.reduce(
           [FbType.held(type) | Map.values(blocks)],
           {seen, Map.put(walked, name, type), from},
           &held_version!/2
         )

  defp held_version!(%FbType{name: name} = type, {seen, walked, from})
       when is_map_key(seen, name),
       do: {versions!(FbType.same?(Map.fetch!(seen, name), type), name, seen, from), walked, from}

  defp held_version!(%FbType{name: name} = type, {seen, walked, from}),
    do: {Map.put(seen, name, type), walked, from}

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
  defp marked(:program, library, _held), do: library

  defp marked({:block, name}, library, held) do
    {chains, _seen} =
      Enum.reduce(library, {%{}, %{}}, fn {_, t}, acc -> chain(t, name, held, acc) end)

    marks =
      for {held, [_ | _] = chain} <- chains, into: %{}, do: {held, {:recursive, [name | chain]}}

    library |> Map.merge(marks) |> Map.put(name, {:recursive, [name, name]})
  end

  # The chain from `type` down to a type named `name`, `[type.name, …, name]`, or nil.
  defp chain(%FbType{name: name}, name, _held, {chains, seen}),
    do: {Map.put(chains, name, [name]), Map.put(seen, name, true)}

  defp chain(%FbType{name: own} = type, name, held, {chains, seen})
       when not is_map_key(seen, own) do
    inner = nested(type, held)

    {chains, seen} =
      Enum.reduce(inner, {chains, Map.put(seen, own, true)}, &chain(&1, name, held, &2))

    {Map.put(chains, own, down(own, Enum.find_value(inner, &Map.get(chains, &1.name)))), seen}
  end

  defp chain(_seen, _name, _held, acc), do: acc

  # The user block types a type's instances are of, each once, by name, from the one
  # version of each the compile holds (decision 53).
  defp nested(%FbType{body: %Program{tags: tags}}, held),
    do: Map.values(for {_, %Tag{type: {:block, type}}} <- tags, into: %{}, do: {type, held[type]})

  defp nested(%FbType{body: nil}, _held), do: []

  defp down(_held, nil), do: nil
  defp down(held, chain), do: [held | chain]

  # M1-6: one `ons` uses a storage bit. A second `ons` on one bit is an error at its own
  # line, citing the first: the false one clears the bit every scan, so the true one fires
  # on every scan its rung is true, and no arrangement of two works. Any other writer of
  # the bit is only a warning (Logex.Warnings), since it may be a deliberate re-arm. An
  # `ons` on anything but a declared bool was reported already and is passed over. One walk
  # in rung order, so it stays linear.
  #
  # M3-4: so for every one-shot, the pulse coils `osr` and `osf` beside `ons`
  # (Logex.Walk.one_shots/0), whose storage bit is under every rule an `ons` bit has
  # (decision 80): one one-shot of any of the three to a bit. A coil's pulse bit is its
  # second operand, which must be another tag than its storage bit (decision 101).
  @one_shots Walk.one_shots()

  defp shared_bits(instructions, tags) do
    {_first, diagnostics} = Enum.reduce(instructions, {%{}, []}, &shared_bit(&1, &2, tags))

    Enum.reverse(diagnostics)
  end

  defp shared_bit({symbol, line, [{:name, _, bit} | pulse]}, {first, _} = acc, tags)
       when symbol in @one_shots do
    tag = Map.get(tags, bit)
    {first, diagnostics} = storage_bit(Map.fetch(first, bit), tag, {bit, line, symbol}, acc)
    {first, own_pulse(pulse, tag, {bit, line, symbol}, diagnostics)}
  end

  # M3-1: a counter's `r` and `ld` are the first bool members logic may write, and neither
  # is a storage bit: the counter reads it as its input, and an online edit's block list
  # names a storage bit as a tag of the routine (decision 21).
  # A member logic may not write, or that is no bool, was reported already.
  defp shared_bit({symbol, line, [{:member, _, [instance, member]} | _]}, acc, tags)
       when symbol in @one_shots,
       do:
         member_bit(
           writable?(Map.get(tags, instance), member),
           {line, symbol, instance, member},
           acc
         )

  defp shared_bit(_instruction, acc, _tags), do: acc

  # M3-4 (decision 101): a coil's pulse bit is not its storage bit. Each run writes both, the
  # pulse and then the power received, so one tag would hold only the power and never pulse.
  # A storage bit that is no declared bool was reported already.
  defp own_pulse([{:name, _, bit}], %Tag{type: :bool}, {bit, line, symbol}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{bit}` is both the storage bit and the pulse bit of this `#{symbol}`: its pulse " <>
          "bit is another tag, which it sets for one scan on an edge"
      )
      | diagnostics
    ]

  defp own_pulse(_pulse, _tag, _coil, diagnostics), do: diagnostics

  defp writable?(%Tag{type: %FbType{} = type}, member),
    do: match?({:ok, %Member{write: true, type: :bool}}, FbType.member(type, member))

  defp writable?(_tag, _member), do: false

  defp member_bit(true, {line, symbol, instance, member}, {first, diagnostics}),
    do:
      {first,
       [
         diagnostic(
           line,
           "`#{symbol}` keeps its storage bit in a bool of its own, not in " <>
             "`#{instance}.#{member}`, a member of `#{instance}`, which its instance reads"
         )
         | diagnostics
       ]}

  defp member_bit(false, _one_shot, acc), do: acc

  defp storage_bit(:error, %Tag{type: :bool}, {bit, line, symbol}, {first, diagnostics}),
    do: {Map.put(first, bit, {line, symbol}), diagnostics}

  defp storage_bit({:ok, {first_line, other}}, %Tag{}, {bit, line, symbol}, {first, diagnostics}) do
    message =
      "`#{bit}` is already the storage bit of the `#{other}` #{where(first_line, line)}: " <>
        "each #{one_shot(other, symbol)} needs a storage bit of its own"

    {first, [diagnostic(line, message) | diagnostics]}
  end

  defp storage_bit(:error, _not_a_bool, _one_shot, acc), do: acc

  # In the words of the two one-shots, one mnemonic where they are one.
  defp one_shot(symbol, symbol), do: "`#{symbol}`"
  defp one_shot(_first, _second), do: "`ons`, `osr` or `osf`"

  # M1-6: one `ton` runs a timer, and the number on it is the timer's preset, its `.pre`
  # when an instance starts or restarts, which logic may then change (decision 4). So the
  # compiled tag carries it, as the initial value of its preset member, the one its type
  # names (Logex.FbType.rules/1, M3-1). A second instruction of one mnemonic on one
  # instance is an error at its own line, citing the first, as a second `ons` on a storage
  # bit is: two would give it two presets, and a false one resets a timer under a true one
  # every scan. One walk in rung order, so it stays linear.
  #
  # M3-1: a `ctud` is run by a `ctu` and a `ctd` (decision 85), so the rule is one
  # instruction of each mnemonic an instance, and the two must give it one preset: the
  # second to run it is an error at its own line where its preset differs from the first's,
  # which starts the instance.
  defp presets(instructions, tags) do
    {_run, first, diagnostics} =
      instructions
      |> Enum.flat_map(&run/1)
      |> Enum.reduce({%{}, %{}, []}, &preset(&1, &2, tags))

    {Enum.reduce(first, tags, fn {instance, {_line, symbol, pre}}, tags ->
       starts(tags, instance, symbol, pre)
     end), Enum.reverse(diagnostics)}
  end

  # The instructions that run a built-in instance, `ton` among them (Logex.FbType.rules/1).
  @runners FbType.runners()

  # Every instruction that names an instance runs it, whatever its preset: `ton t1 sp` and
  # a second `ton t1 5000` are two mistakes. A preset that is not a literal was reported
  # already, and a program with a diagnostic never runs, so its nil is never a `.pre`.
  defp run({symbol, line, [{:name, _, instance} | preset]}) when symbol in @runners,
    do: [{instance, line, symbol, preset_of(preset)}]

  defp run(_instruction), do: []

  defp preset_of([{:int_lit, _, preset}]), do: preset
  defp preset_of(_reported), do: nil

  defp preset({instance, _line, symbol, _pre} = runs, {run, first, diagnostics}, tags),
    do:
      run_by(
        Map.fetch(run, {instance, symbol}),
        Map.get(tags, instance),
        runs,
        {run, first, diagnostics}
      )

  defp run_by(:error, %Tag{type: %FbType{}}, {instance, line, symbol, pre}, acc) do
    {run, first, diagnostics} = acc
    run = Map.put(run, {instance, symbol}, line)

    agreed(
      Map.fetch(first, instance),
      {instance, line, symbol, pre},
      {run, Map.put_new(first, instance, {line, symbol, pre}), diagnostics}
    )
  end

  defp run_by({:ok, first_line}, %Tag{}, {instance, line, symbol, _pre}, acc) do
    {run, first, diagnostics} = acc

    message =
      "`#{instance}` is already run by the `#{symbol}` #{where(first_line, line)}: " <>
        "one `#{symbol}` runs #{a_runs(symbol)}"

    {run, first, [diagnostic(line, message) | diagnostics]}
  end

  defp run_by(:error, _not_an_instance, _run, acc), do: acc

  # The second instruction to run an instance, of the other mnemonic, gives the preset the
  # first gave. A preset that is no literal was reported already.
  defp agreed({:ok, {first_line, other, pre}}, {instance, line, symbol, given}, acc)
       when pre != given and is_integer(pre) and is_integer(given) do
    {run, first, diagnostics} = acc

    message =
      "`#{instance}` already has the preset #{pre} from the `#{other}` " <>
        "#{where(first_line, line)}: the `ctu` and the `ctd` of a ctud give it one preset, " <>
        "so this `#{symbol}` takes #{pre} too"

    {run, first, [diagnostic(line, message) | diagnostics]}
  end

  defp agreed(_first, _runs, acc), do: acc

  # In the words of the kind of type the instruction is named after (Logex.FbType.rules/1,
  # M3-2): every timer's, one; a counter's, its side.
  defp a_runs(symbol), do: a_runs(kind_of(symbol), symbol)

  defp a_runs(:timer, _symbol), do: "a timer"
  defp a_runs(:counter, :ctu), do: "a counter's count up"
  defp a_runs(:counter, :ctd), do: "a counter's count down"

  # The kind of the built-in type an instruction is named after, `:timer` or `:counter`.
  defp kind_of(symbol), do: FbType.rules(own_type(symbol)).kind

  # The preset starts the member the type names, on a type the instruction runs; on any
  # other, which was reported already, there is nothing to start.
  defp starts(tags, instance, symbol, pre),
    do: Map.update!(tags, instance, &started(&1, FbType.runs?(&1.type, symbol), pre))

  defp started(%Tag{type: type} = tag, true, pre),
    do: %{tag | initial: %{FbType.rules(type).preset => pre}}

  defp started(tag, false, _pre), do: tag

  # M1-6: nothing may follow a `ton` on its path, nor, since M3-1, any instruction that
  # runs a built-in instance (decision 73). Whether the power after one is the rung's, as
  # after `ote`, or the instance's done member, IEC's Q, is not settled, and refusing both
  # is the reversible way to leave it open. An element bears such an instruction if it is
  # one, or if it is a group one of whose legs holds one, and in every series, a rung or a
  # leg, each element after one that bears one is an error at its own line, once, citing
  # the first. Legs beside a `ton` are not on its path, and are fine. One walk of
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

  defp bears({symbol, _, _} = runner, diagnostics, _known) when symbol in @runners,
    do: {diagnostics, runner}

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

  defp follows({symbol, line, operands}, element, known) do
    message =
      "#{shown(element)} follows #{shown({symbol, line, Enum.take(operands, 1)})} on its " <>
        "path: what passes on after #{quoted(symbol)} is not settled, so #{quoted(symbol)} " <>
        "ends its path; " <> read_instance(symbol, operands, known)

    [diagnostic(line_of(element, line), message)]
  end

  # M3-2: a mnemonic quoted with its article, by how it is said, `an `rto``.
  defp quoted(symbol), do: Declarations.a_or_an(Atom.to_string(symbol), "`#{symbol}`")

  defp shown({:branches, _legs}), do: "a branch group"
  defp shown({symbol, _line, []}), do: "`#{symbol}`"

  defp shown({symbol, _line, operands}),
    do: "`#{symbol} #{Enum.map_join(operands, " ", &text/1)}`"

  defp text({:name, _, name}), do: name
  defp text({:int_lit, _, value}), do: "#{value}"
  defp text({:member, _, path}), do: Enum.join(path, ".")
  defp text({:label, _, name}), do: name

  # The member a rung below reads, the one the instance's type gives the instruction
  # (Logex.FbType.rules/1), or for a name not declared yet, the one the type the
  # instruction is named after gives it.
  defp read_instance(symbol, [{:name, _, instance} | _], known),
    do: read(runnable(symbol, instance, known), symbol, instance)

  defp read_instance(symbol, _no_instance, _known), do: read(nil, symbol, nil)

  defp read(nil, symbol, _instance),
    do: "read the #{noun(symbol)}'s `.#{reads(own_type(symbol), symbol)}` on a rung below"

  defp read(type, symbol, instance),
    do: "read the #{noun(symbol)} with `xic #{instance}.#{reads(type, symbol)}` on a rung below"

  defp reads(type, symbol), do: elem(Map.fetch!(FbType.rules(type).runs, symbol), 1)

  defp noun(symbol), do: Atom.to_string(kind_of(symbol))

  # The built-in type an instruction is named after.
  defp own_type(symbol), do: FbType.builtin(Atom.to_string(symbol))

  # Whether a hint may name `name` as an instance the instruction runs: a declared one, or
  # a name not declared yet, which the hint fits once it is declared as one. Anything else,
  # a bool, a member or a reserved word, has a diagnostic of its own, which a hint beside
  # it would contradict. The type it is read as, or nil.
  defp runnable(symbol, name, known),
    do: runnable_as(Declarations.reserved(name), hinted(name, known), symbol)

  defp runnable_as(nil, {:ok, %Tag{type: %FbType{} = type}}, symbol),
    do: if_runs(FbType.runs?(type, symbol), type)

  defp runnable_as(nil, :error, symbol), do: own_type(symbol)
  defp runnable_as(_reserved, _found, _symbol), do: nil

  defp if_runs(true, type), do: type
  defp if_runs(false, _type), do: nil

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

  defp where(line, line), do: "in this rung"
  defp where(first, _line), do: "on line #{first}"

  # No declaration line at all, as opposed to declarations that were all wrong.
  defp declares_nothing?({:routine, {:rungs, rungs}}, logic), do: length(rungs) == length(logic)

  # A compiled program, and a block's file's type, whose body is the program of its rungs,
  # hold the user block types their instances are of in one table, `blocks`, each type
  # once at any depth, and each instance's tag, at any depth, names its type (decision 53;
  # docs/organisation.md §4.10, "Held types"): a type held in every instance's tag would
  # grow, copied flat, as the width to the power of the depth, and one table per body as
  # the paths to a type. The warnings are of the table with each type itself.
  defp lowered(:program, rungs, {tags, held}, [], _routine) do
    {named, blocks} = hold(tags, held)

    {:ok,
     %Program{rungs: rungs, tags: named, blocks: blocks, warnings: Logex.Warnings.of(rungs, tags)}}
  end

  defp lowered({:block, name}, rungs, {tags, held}, [], routine) do
    {named, blocks} = hold(tags, held)

    body = %Program{
      name: name,
      source: printed(routine),
      rungs: rungs,
      tags: named,
      blocks: blocks,
      warnings: Logex.Warnings.of(rungs, tags)
    }

    {:ok, FbType.of(body)}
  end

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_kind, _rungs, _tags, diagnostics, _routine),
    do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  # A block built here from a parse tree, its members perhaps declared from Elixir, keeps a
  # source text that compiles again to its body (decision 54): each rung printed on the
  # line it was parsed from, so every line the body carries is the text's. Logex.compile/2
  # puts the text it was given in its place. The members declared from Elixir are not
  # printed, which would give them lines: a recompile is handed them again (recompiled/4).
  defp printed({:routine, {:rungs, rungs}}) do
    {lines, _line} =
      Enum.map_reduce(rungs, 1, fn rung, at ->
        line = rung_line(rung)
        {String.duplicate("\n", line - at) <> Logex.Printer.print(rung), line}
      end)

    Enum.join(lines)
  end

  defp rung_line({:rung, elements}), do: element_line(elements)

  defp element_line([{:branches, [leg | _legs]} | _elements]), do: element_line(leg)
  defp element_line([{_kind, line, _value} | _elements]), do: line

  # The tags, each instance of a user block naming its type, and the table: every type the
  # instances reach, at any depth, once, by name, the one version of it the compile holds,
  # in its held form. A walk down from the tags, each type entered once, however many paths
  # reach it, so it is linear in the types and their tags.
  defp hold(tags, held) do
    {named, reached} = Enum.map_reduce(tags, [], &naming/2)
    {Map.new(named), table(reached, held, %{})}
  end

  defp naming({name, %Tag{type: %FbType{name: type, body: %Program{}}} = tag}, reached),
    do: {{name, %{tag | type: {:block, type}}}, [type | reached]}

  defp naming(entry, reached), do: {entry, reached}

  defp table([], _held, table), do: table

  defp table([name | names], held, table) when is_map_key(table, name),
    do: table(names, held, table)

  defp table([name | names], held, table) do
    %FbType{body: %Program{tags: tags}} = type = Map.fetch!(held, name)

    table(
      for({_, %Tag{type: {:block, inner}}} <- tags, do: inner) ++ names,
      held,
      Map.put(table, name, type)
    )
  end

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

  # M3-5 (decisions 81, 104 and 105): a routine's labels and jumps, over its lowered rungs in
  # order. Each `lbl` labels its rung, and one that is not its rung's first element is an
  # error at its line; a label used twice, or two that differ only in case, is an error at
  # the second. Then each rung holds one `jmp`, a second an error at its line, and that one
  # names a label of this routine, exactly, on a later rung: a jump back, or to its own rung,
  # could loop for ever. A label or jump whose operand was reported already, a literal or a
  # name no label can be, is passed over, so one mistake gives one message. Two walks of
  # the rungs, with maps that are only looked up, so it stays linear.
  defp jumps(rungs, kind) do
    indexed = Enum.with_index(rungs)
    {labels, _folded, diagnostics} = Enum.reduce(indexed, {%{}, %{}, []}, &labelled/2)
    Enum.reverse(Enum.reduce(indexed, diagnostics, &jumps_in(&1, &2, {labels, kind})))
  end

  # Each `lbl` in turn, the one that heads its rung, if one does, first, as the walk gives
  # them: a misplaced one is refused, and each labels its rung.
  defp labelled({{:rung, elements} = rung, index}, acc) do
    lbls = for {:lbl, _, _} = lbl <- Walk.instructions([rung]), do: lbl
    {heads, others} = Enum.split(lbls, heads(elements))
    acc = Enum.reduce(heads, acc, &label(&1, index, &2))
    Enum.reduce(others, acc, &label(&1, index, misplaced(&1, &2)))
  end

  # How many of a rung's `lbl`s head it: its first element's, if that is one.
  defp heads([{:lbl, _, _} | _]), do: 1
  defp heads(_elements), do: 0

  defp label({:lbl, line, [{:label, _, name}]}, index, acc),
    do: label_named(label_word(name), {name, line, index}, acc)

  defp label(_reported, _index, acc), do: acc

  defp label_named(:label, {name, line, index}, {labels, folded, diagnostics}) do
    key = String.downcase(name)

    twin(
      Map.fetch(labels, name),
      Map.fetch(folded, key),
      {name, line, index, key},
      {labels, folded, diagnostics}
    )
  end

  defp label_named(_reported, _label, acc), do: acc

  defp twin({:ok, {first, _index}}, _folded, {name, line, _, _}, {labels, folded, diagnostics}) do
    message = "`#{name}` already labels #{the_rung(first, line)}: a label names one rung"
    {labels, folded, [diagnostic(line, message) | diagnostics]}
  end

  defp twin(:error, {:ok, other}, {name, line, _, _}, {labels, folded, diagnostics}) do
    {first, _index} = Map.fetch!(labels, other)

    message =
      "the labels `#{name}` and `#{other}` (line #{first}) differ only in case: labels are " <>
        "case-sensitive, so these would be two labels"

    {labels, folded, [diagnostic(line, message) | diagnostics]}
  end

  defp twin(:error, :error, {name, line, index, key}, {labels, folded, diagnostics}),
    do: {Map.put(labels, name, {line, index}), Map.put(folded, key, name), diagnostics}

  defp the_rung(line, line), do: "this rung"
  defp the_rung(first, _line), do: "the rung on line #{first}"

  defp misplaced({:lbl, line, operands}, {labels, folded, diagnostics}) do
    message =
      "#{shown({:lbl, line, operands})} is not first on its rung: a label stands at the " <>
        "head of the rung it names, before any other instruction or branch group"

    {labels, folded, [diagnostic(line, message) | diagnostics]}
  end

  defp jumps_in({rung, index}, diagnostics, context),
    do:
      one_jmp(
        for({:jmp, _, _} = jmp <- Walk.instructions([rung]), do: jmp),
        index,
        diagnostics,
        context
      )

  defp one_jmp([], _index, diagnostics, _context), do: diagnostics

  defp one_jmp([first | seconds], index, diagnostics, context) do
    diagnostics = target(first, index, diagnostics, context)
    Enum.reduce(seconds, diagnostics, &second_jmp(&1, first, &2))
  end

  defp target({:jmp, line, [{:label, _, name}]}, index, diagnostics, {labels, kind}),
    do:
      targeted(
        label_word(name),
        Map.fetch(labels, name),
        {name, line, index},
        {labels, kind},
        diagnostics
      )

  defp target(_reported, _index, diagnostics, _context), do: diagnostics

  defp targeted(:label, :error, {name, line, _index}, {labels, kind}, diagnostics) do
    message =
      "`jmp #{name}` names no label: no rung of this #{routine(kind)} begins `lbl #{name}`" <>
        Declarations.suggest(name, Map.keys(labels), & &1, "labels")

    [diagnostic(line, message) | diagnostics]
  end

  defp targeted(:label, {:ok, {_at, to}}, {_name, _line, from}, _context, diagnostics)
       when to > from,
       do: diagnostics

  defp targeted(:label, {:ok, {at, to}}, {name, line, from}, _context, diagnostics) do
    message =
      "`jmp #{name}` jumps #{backwards(to == from, at)}: a jump goes forward only, to a " <>
        "label on a later rung, since one back could loop for ever"

    [diagnostic(line, message) | diagnostics]
  end

  defp targeted(_reported, _found, _jmp, _context, diagnostics), do: diagnostics

  defp backwards(true, _at), do: "to its own rung"
  defp backwards(false, at), do: "back, to the rung on line #{at}"

  # A jump in a block's body goes to a label in that body (decision 105).
  defp routine(:program), do: "program"
  defp routine({:block, _name}), do: "function block's body"

  defp second_jmp({:jmp, line, _operands} = jmp, first, diagnostics) do
    message =
      "#{shown(jmp)} is a second `jmp` in this rung, after #{shown(first)}: a rung holds " <>
        "one, since which of two would win is not settled"

    [diagnostic(line, message) | diagnostics]
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
    diagnostics = check_preset(signature, operands, {symbol, at}, known, diagnostics)
    diagnostics = check_divisor(symbol, operands, at, diagnostics)
    lowered = {symbol, line, Enum.zip_with(signature, operands, &slot_operand/2)}
    lower(rest, [lowered | ir], diagnostics, known)
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

  defp not_run(nil, {:ok, %Tag{type: %FbType{name: type} = fb} = tag}, line, name, word),
    do: [
      diagnostic(
        line,
        "`#{word}` runs an instance of a user function block, but `#{name}` is a " <>
          "#{type}#{declared(tag)}, " <>
          run_by_own(Enum.sort(Map.keys(FbType.rules(fb).runs), :desc), name)
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

  # M3-1: what runs a built-in instance, each instruction with its preset.
  defp run_by_own([symbol], name), do: "which `#{symbol} #{name}` and its preset run"

  defp run_by_own(symbols, name),
    do: "which #{Enum.map_join(symbols, " and ", &"`#{&1} #{name}`")}, each with its preset, run"

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

  # M3-5: in a label slot a name is a label, `{:label, line, name}`, never a tag or a member,
  # whatever it holds; anything else lowers as any operand does.
  defp slot_operand({:label, _}, {:name, line, name}), do: {:label, line, name}
  defp slot_operand(_slot, operand), do: operand(operand)

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
  defp kind({:instance, type}), do: a_type(type)
  defp kind({:preset, _type}), do: "a preset"
  defp kind({:label, _type}), do: "a label"

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
  defp check_kind({:label, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  # A preset from a tag is not a preset: check_preset/4 names the `move` that is meant.
  defp check_kind({:preset, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  defp check_kind(kind, {:int_lit, _, value}, {line, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects #{kind(kind)}, found `#{value}`") | diagnostics]

  # M1-6: `ton t1 sp`. The preset is the instance's starting preset member, a number on
  # the rung; a value from a tag is moved into that member instead, which logic may write
  # (decision 4), `.pre` for a timer.
  defp check_preset(
         [_, {:preset, _}],
         [first, {:name, line, name}],
         {symbol, {_, word}},
         known,
         diagnostics
       ) do
    message =
      "`#{word}` takes its preset as #{unit(symbol)}, found `#{name}`" <>
        moved(first, name, symbol, known)

    [diagnostic(line, message) | diagnostics]
  end

  defp check_preset(_signature, _operands, _at, _known, diagnostics), do: diagnostics

  # M3-3 (decision 78): a zero divisor gives 0 and passes no power, so a literal one could
  # never divide, and is refused where it stands, `-0` among them, which lexes as 0. A tag
  # that is 0 for a while is the run's to report (Logex.Runtime).
  defp check_divisor(symbol, [_dividend, {:int_lit, line, 0} | _], {_, word}, diagnostics)
       when symbol in [:div, :mod],
       do: [
         diagnostic(
           line,
           "`#{word}` divides by the literal `0`: a zero divisor gives 0 and passes no power " <>
             "on every scan, so a literal one is refused"
         )
         | diagnostics
       ]

  defp check_divisor(_symbol, _operands, _at, diagnostics), do: diagnostics

  defp unit(symbol), do: unit_of(kind_of(symbol))

  defp unit_of(:timer), do: "a number of milliseconds"
  defp unit_of(:counter), do: "a number, a count"

  # The `move` is named only where it would compile, once a name in it not declared yet is
  # declared: into an instance's preset member, from a dint. One name is never both, nor
  # are two that differ only in case (Logex.Declarations), so `ton b b` and `ton b B` have
  # none.
  defp moved({:name, _, instance}, name, symbol, known),
    do:
      moved_into(
        String.downcase(instance) == String.downcase(name),
        {instance, symbol},
        name,
        known
      )

  defp moved(_literal, _name, _symbol, _known), do: ""

  defp moved_into(true, _instance, _name, _known), do: ""

  defp moved_into(false, {instance, symbol}, name, known),
    do: move(runnable(symbol, instance, known), dint?(name, known), instance, name)

  defp move(%FbType{} = type, true, instance, name),
    do:
      ": to preset `#{instance}` from a tag, `move #{name} #{instance}." <>
        "#{FbType.rules(type).preset}` on a rung above"

  defp move(_type, _dint?, _instance, _name), do: ""

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
  # Since M3-3 a literal may be negative (decision 97), so each meets one too small too.
  defp check_tag({{:value, :dint}, {:int_lit, line, value}}, {_, word}, _scope, diagnostics),
    do: literal(Declarations.fits?(:dint, value), value, {line, word}, diagnostics)

  # A preset is a dint, a number of milliseconds for a timer or a count for a counter, and
  # never negative (docs/naming.md, `ton`): a negative literal lexes since M3-3, and is
  # refused here (decision 97).
  defp check_tag({{:preset, _}, {:int_lit, line, value}}, {_, word}, _scope, diagnostics),
    do: preset(Declarations.preset?(value), value, {line, word}, diagnostics)

  defp check_tag({_slot, {:int_lit, _, _}}, _at, _scope, diagnostics), do: diagnostics

  # Reported by check_preset/4, and never looked up.
  defp check_tag({{:preset, _}, {:name, _, _}}, _at, _scope, diagnostics), do: diagnostics

  # M3-5 (decision 105): a label is a name of its routine's own, never looked up as a tag: a
  # name with no `.`, and no reserved word, of which take_operands/3 leaves a section or type
  # word to reach here.
  defp check_tag({{:label, _}, {:name, line, name}}, {_, word}, _scope, diagnostics),
    do: label_shape(label_word(name), {line, word, name}, diagnostics)

  defp check_tag({slot, {:name, _, name} = operand}, at, scope, diagnostics),
    do: resolve(Declarations.reserved(name), lookup(name, scope), slot, operand, at, diagnostics)

  defp preset(true, _value, _at, diagnostics), do: diagnostics

  defp preset(false, value, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` takes a preset of 0 to 2147483647#{suffix(symbol_of(word))}, " <>
          "found `#{value}`"
      )
      | diagnostics
    ]

  defp suffix(symbol), do: suffix_of(kind_of(symbol))

  defp suffix_of(:timer), do: " ms"
  defp suffix_of(:counter), do: ""

  defp symbol_of(word), do: elem(Map.fetch!(@instructions, String.downcase(word)), 0)

  defp literal(true, _value, _at, diagnostics), do: diagnostics

  defp literal(false, value, {line, word}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` reads a dint: `#{value}` does not fit in 32 bits") | diagnostics
    ]

  defp label_shape(:label, _at, diagnostics), do: diagnostics

  defp label_shape(:dotted, {line, word, name}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a label, a name with no `.`, found `#{name}`")
      | diagnostics
    ]

  defp label_shape(reserved, {line, word, name}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a label, found #{reserved_word(reserved)} `#{name}`")
      | diagnostics
    ]

  # What a name in a label slot is: `:label`, `:dotted`, or the reserved word it is.
  defp label_word(name), do: label_word(String.contains?(name, "."), name)

  defp label_word(true, _name), do: :dotted
  defp label_word(false, name), do: label_or(Declarations.reserved(name))

  defp label_or(nil), do: :label
  defp label_or(reserved), do: reserved

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

  # A device, `i` or `q`, then one whole-number field or more: the shape of a location
  # (decision 6), which only a configuration's `var_global ... at` line names, since a
  # location in a program type would tie the type to one plant (docs/organisation.md
  # §4.5). It is read in any spelling, `panel.Q.03` too, as a configuration file reads a
  # location where it names one; only after `at` is a location held to its one spelling.
  defp located([_device, io | [_ | _] = address], name) when io in ["i", "q", "I", "Q"],
    do: location_slot(Enum.all?(address, &String.match?(&1, ~r/\A[0-9]+\z/)), name)

  defp located(_parts, _name), do: :member

  defp location_slot(true, name), do: {:location, name}
  defp location_slot(false, _name), do: :member

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
  # A name shaped like a location, `panel.i.0`, is named as one (docs/organisation.md §4.7:
  # each wrong reading of `.` gets a diagnostic that names it), once a device.
  defp resolve(nil, {:undeclared, head}, _slot, {:name, line, name}, _at, diagnostics),
    do: [{:undeclared, line, head, located(String.split(name, "."), name)} | diagnostics]

  defp resolve(nil, {:reserved, reserved, head}, _slot, {:name, line, name}, _at, diagnostics) do
    message =
      "`#{name}` begins with `#{head}`, #{reserved_as(reserved)}, which cannot name a tag"

    [diagnostic(line, message) | diagnostics]
  end

  # An instance is named whole only where an instruction runs it; anywhere else, by one of
  # its members, which the message suggests when one would fit the slot.
  defp resolve(nil, {:ok, %Tag{type: %FbType{name: type}}}, {:instance, type}, _, _, diagnostics),
    do: diagnostics

  # M3-1: a slot of several types, a counter's.
  defp resolve(
         nil,
         {:ok, %Tag{type: %FbType{name: type} = fb} = tag},
         {:instance, [_ | _] = types} = slot,
         operand,
         at,
         diagnostics
       ),
       do: of_kind(type in types, {tag, fb}, slot, {operand, at}, diagnostics)

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

  defp of_kind(true, _tag, _slot, _at, diagnostics), do: diagnostics

  defp of_kind(
         false,
         {tag, type},
         {:instance, types},
         {{:name, line, _}, {_, word}},
         diagnostics
       ),
       do: [
         diagnostic(
           line,
           "`#{word}` runs #{a_type(types)}, but `#{tag.name}` is " <>
             "#{Declarations.instance_of(type)}#{declared(tag)}" <> both_ways(type, tag)
         )
         | diagnostics
       ]

  # A counter of the other kind is one declaration from one that counts both ways.
  defp both_ways(%FbType{name: kind, body: nil}, tag) when kind in ["ctu", "ctd"],
    do:
      ": a #{kind} only counts #{way(kind)}; declare it `var #{tag.name} ctud` to count both " <>
        "ways"

  defp both_ways(_type, _tag), do: ""

  defp way("ctu"), do: "up"
  defp way("ctd"), do: "down"

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
  defp a_type([_ | _] = types), do: Enum.map_join(types, " or ", &Declarations.a_or_an/1)
  defp a_type(type), do: Declarations.a_or_an(to_string(type))

  defp check_member_type(diagnostics, {_access, :any}, _name, _member, _at), do: diagnostics

  defp check_member_type(diagnostics, {_access, type}, _name, %Member{type: type}, _at),
    do: diagnostics

  defp check_member_type(diagnostics, {access, type}, name, member, {line, word}),
    do: [
      diagnostic(
        line,
        "`#{word}` #{verb(access)} #{a_type(type)}, but `#{name}` is a #{member.type}"
      )
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
    do:
      "logic may write only #{listed(Enum.map(writable, &"`.#{&1.name}`"))} of " <>
        Declarations.a_or_an(type.name)

  defp check_type(diagnostics, _access, :any, _tag, _at), do: diagnostics
  defp check_type(diagnostics, _access, type, %Tag{type: type}, _at), do: diagnostics

  defp check_type(diagnostics, access, type, tag, {line, word}) do
    message =
      "`#{word}` #{verb(access)} #{a_type(type)}, but `#{tag.name}` is a " <>
        "#{tag.type}#{declared(tag)}"

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

  # A program never names a point: a configuration connects one to a var_input or a
  # var_output through the global at it (§4.5). Nothing here advises a declaration, so a
  # program that declares nothing is told how at the next undeclared name reported.
  defp first_use(false, line, {name, {:location, location}}, _tags, {seen, note?}) do
    message =
      "`#{location}` is a location, written only after `at` on a configuration's " <>
        "`var_global` line: a program reaches a point through a var_input or var_output " <>
        "that the configuration connects to the global at it"

    {[diagnostic(line, message)], {MapSet.put(seen, name), note?}}
  end

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
  defp how(true, {:instance, [type | _]}, name), do: note("`var #{name} #{type}`")
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
