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

  Since M5-11 (decision 151) an operand may be an element of an array, `temps[3]`, each
  subscript a literal within its dimension, refused at its line otherwise, read and written
  as a tag of its elements' type and lowered to `{:element, line, array, index, name}`,
  its subscripts' values and its name as written; an array whole is no operand. Since
  M5-12 (decision 152) a subscript may be an integer tag of any width, `weights[slot]` or
  `grid[1,c]`, declared and of an integer type, a literal beside it judged as before,
  lowered to `{:element_at, line, array, index, dims, name}`, each subscript a literal's
  value or the tag's `{:name, line, tag}`, which a scan checks against `dims` (decision
  153); one is refused as a one-shot's storage bit or a pulse coil's pulse bit, as a bit
  whose number a tag holds is (decision 154). Since decision 221 a bit of an
  element, `faults[2].3` or `faults[2].[n]`, is a bit as a tag's is, by every rule of a
  tag's bit, its container the element's own operand, `{:bit, line, {:element, ...}, n,
  mask, name}`. Since decision 227 a routine of real tags is warned of each real initial
  value its declaration lines write with more digits than its real keeps
  (`Logex.Warnings.initials/2`), read from the parse tree, which keeps each spelling.

  A host compiles through `Logex.compile/2` and `Logex.compile_file/1`. The stage
  functions stay public for the front end's golden record, the Elixir-side declarer and
  the naming test; `signature/2` for the walks (`Logex.Walk`), which look an instruction's
  slots up here; and `lowered?/1` and `recompiled/4` for the check of a type given
  (`Logex.FbType.user?/1`, decision 54).
  """

  alias Logex.{Declarations, Diagnostic, FbType, Parser, Program, Tag, Walk}
  alias Logex.FbType.Member
  import Logex.Declarations, only: [is_elementary: 1, is_class: 1]
  import Logex.Array, only: [is_array: 1]
  import Logex.Parser, only: [is_int_lit: 1, is_literal: 1, is_real_lit: 1]

  # M5-10: a real literal whose value is 0.0, `0.0` or `-0.0`, which lexes as 0.0.
  defguardp is_real_zero(term)
            when is_tuple(term) and tuple_size(term) in 3..4 and elem(term, 0) == :real_lit and
                   elem(term, 2) == 0

  defdelegate tokenize(source), to: Logex.Lexer
  defdelegate parse(tokens), to: Logex.Parser

  # Each mnemonic's operand signature, in order, one `{access, type}` per operand. Access:
  # `:read` and `:write` must be a tag, and `:value` may be a tag or an integer literal.
  # M1-6 adds two: `{:instance, type}` is an instance of that function block type, which
  # the instruction runs, the only slot where an instance is named whole; `:preset` is a
  # literal number, 0 to 2147483647, of milliseconds for a timer and a count for a counter;
  # since M3-1 an instance slot names a list where it runs instances of several types, and
  # since M5-5 and M5-6 each a kind, every type of that `family`; a preset is judged in its
  # instance's type and unit (judged/3), a `ton_ltime`'s 0 to 2^63-1 ns. M3-5
  # adds `{:label, nil}`, a label of the routine's own, a namespace that holds no tag, which
  # the IR keeps as `{:label, line, name}`.
  # Type: an elementary type of `Logex.Declarations.table/0`, `:bool`, `:dint` or since M5-3
  # any integer type, or `:any`, which IEC's MOVE takes (`IN : ANY` -> `OUT : ANY`,
  # docs/naming.md), its source widening into its destination's type (decision 147), or
  # since M5-4 one of IEC's generic types, `:any_int` or `:any_num`
  # (`Logex.Declarations.is_class/1`), whose operands classed/3 holds together: the
  # instruction computes in its destination's type, each source widening into it. A tag
  # here may be a member of an instance, `t1.acc`, which has the type its schema gives it
  # (M1-6).
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
    # Since M5-8 a comparison's slots take IEC's ANY_ELEMENTARY less its BOOL (Ed 3 Table
    # 33), the numbers and the bit strings, a bit string compared with a bit string as the
    # unsigned integer IEC reads it as (§6.6.2.5.10) and with an integer only through a
    # conversion (decision 147's note).
    "eq" => {:eq, [{:value, :any_elementary}, {:value, :any_elementary}]},
    "ne" => {:ne, [{:value, :any_elementary}, {:value, :any_elementary}]},
    "lt" => {:lt, [{:value, :any_elementary}, {:value, :any_elementary}]},
    "gt" => {:gt, [{:value, :any_elementary}, {:value, :any_elementary}]},
    "le" => {:le, [{:value, :any_elementary}, {:value, :any_elementary}]},
    "ge" => {:ge, [{:value, :any_elementary}, {:value, :any_elementary}]},
    # M5-6 (decision 158): each timer's slot names its kind, so the one `ton` runs a `ton`
    # and a `ton_ltime`, its preset in its instance's unit, ms or ns.
    "ton" => {:ton, [{:instance, ["ton"]}, {:preset, :dint}]},
    # M3-2: the off-delay timer, rung power its IN, the preset its starting `.pre`.
    "tof" => {:tof, [{:instance, ["tof"]}, {:preset, :dint}]},
    # M3-2: the pulse timer, rung power its IN, the preset its starting `.pre`.
    "tp" => {:tp, [{:instance, ["tp"]}, {:preset, :dint}]},
    # M3-2: the retentive timer, rung power its IN, the preset its starting `.pre`.
    "rto" => {:rto, [{:instance, ["rto"]}, {:preset, :dint}]},
    # M3-1: IEC's counters (decision 67). Rung power is the count input of the counter's
    # side the mnemonic names, `cu` or `cd`, and the preset is its starting `pv`, a count.
    # An instance slot may take several types, a list: a `ctud` is run by one of each
    # (decision 85). Since M5-5 a slot names kinds, each type's `family`
    # (Logex.FbType.family/1), so a `ctu` runs every up counter, `ctu_int` among them, its
    # preset judged in its instance's type (decision 158).
    "ctu" => {:ctu, [{:instance, ["ctu", "ctud"]}, {:preset, :dint}]},
    "ctd" => {:ctd, [{:instance, ["ctd", "ctud"]}, {:preset, :dint}]},
    # M3-3: IEC's arithmetic (decision 79), two sources, each a tag, a member or a literal,
    # then the destination it writes: `add total flow total`, `sub a b d` being a - b. Rung
    # power is IEC's EN and the power out its ENO (decision 98): false where the result
    # leaves its type, which wraps, its low bits kept (decision 146, M5-2). Since M5-4
    # every integer width, IEC's ANY_NUM, computed in the destination's type, each source
    # widening into it by Ed 3 Figure 11 (decision 147).
    "add" => {:add, [{:value, :any_num}, {:value, :any_num}, {:write, :any_num}]},
    "sub" => {:sub, [{:value, :any_num}, {:value, :any_num}, {:write, :any_num}]},
    "mul" => {:mul, [{:value, :any_num}, {:value, :any_num}, {:write, :any_num}]},
    # M3-3: `div a b d` is a / b truncated toward zero, and `mod a b d` its remainder, the
    # dividend's sign. A zero divisor gives 0 and no power (decision 78); a literal one is
    # refused. IEC's MOD is ANY_INT (Ed 3 Table 29), so `mod` stays an integer's when the
    # reals land (M5-10).
    "div" => {:div, [{:value, :any_num}, {:value, :any_num}, {:write, :any_num}]},
    "mod" => {:mod, [{:value, :any_int}, {:value, :any_int}, {:write, :any_int}]},
    # M3-3: `neg a d` is 0 - a, the vendors' NEG, and `abs a d` IEC's ABS: one source, then
    # the destination. A signed type's most negative value has no positive twin, so it alone
    # overflows; `neg` into an unsigned type is refused (decision 145).
    "neg" => {:neg, [{:value, :any_num}, {:write, :any_num}]},
    "abs" => {:abs, [{:value, :any_num}, {:write, :any_num}]},
    # M5-10: IEC's SQRT (Ed 3 Table 28 feature 2; decisions 79 and 164), computed in its
    # destination's type as `add`'s is, its source a number of a type Figure 11 widens into
    # it, an `int` into a `real`, which classed/3 holds together; its destination a real,
    # IEC's ANY_REAL, a class of its own. A negative source writes 0.0
    # and passes no power, so what it passes on is settled; a literal negative one is
    # refused (decision 167).
    "sqrt" => {:sqrt, [{:value, :any_num}, {:write, :any_real}]},
    # M5-8: IEC's bitwise Boolean functions (Ed 3 Table 31; decision 155), on the bit strings
    # and the integers alike, each computing in its destination's type as `add` does, its
    # sources all of the destination's kind, widening into it by Figure 11 (decision 147):
    # `and a b dst`, `or`, `xor` and `not src dst`. A bitwise instruction cannot fail, so its
    # power out is its power in, settled (§4.12's routine choice). Since decision 206 a bool
    # too, IEC's ANY_BIT holding BOOL: `and a b c` of three bools is IEC's AND of bools, and a
    # bool widens into a bit string by Figure 11, never into an integer.
    "and" => {:and, [{:value, :any_bitwise}, {:value, :any_bitwise}, {:write, :any_bitwise}]},
    "or" => {:or, [{:value, :any_bitwise}, {:value, :any_bitwise}, {:write, :any_bitwise}]},
    "xor" => {:xor, [{:value, :any_bitwise}, {:value, :any_bitwise}, {:write, :any_bitwise}]},
    "not" => {:not, [{:value, :any_bitwise}, {:write, :any_bitwise}]},
    # M5-8: IEC's bit shift functions (Table 30): `shl src n dst`, `shr`, `rol` and `ror`, the
    # source and destination as `and`'s, and `n`, the count, IEC's ANY_INT, an integer of any
    # width held to no other operand, a negative literal refused. A count negative at run
    # time passes no power (decision 165), so the power out is settled too. Since decision
    # 206 the source and destination may be bools, one bit wide, as IEC's ANY_BIT IN is.
    "shl" => {:shl, [{:value, :any_bitwise}, {:value, :any_int}, {:write, :any_bitwise}]},
    "shr" => {:shr, [{:value, :any_bitwise}, {:value, :any_int}, {:write, :any_bitwise}]},
    "rol" => {:rol, [{:value, :any_bitwise}, {:value, :any_int}, {:write, :any_bitwise}]},
    "ror" => {:ror, [{:value, :any_bitwise}, {:value, :any_int}, {:write, :any_bitwise}]},
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

  # M5-3 (decision 148): IEC's typed conversions between two integer types, `<from>_to_<to>`
  # lowercased (Ed 3 Table 22 feature 1a), every ordered pair of the integer types of
  # `Logex.Declarations.table/0`, 56: a source of the `from` type, a tag, a member or a
  # literal, then the destination of the `to` type it writes, `dint_to_int day_total
  # small_count`. Rung power is IEC's EN and the power out its ENO, false on the scan its
  # value did not fit and wrapped (decision 146), so what it passes on is settled.
  # M5-8 (decisions 148 and 155): so the 76 bit-string conversions, `byte_to_word` and
  # `word_to_int`, each a binary transfer whose power out is its power in, settled too.
  @conversions for from <- Declarations.convertible(),
                   to <- Declarations.convertible(),
                   word = Declarations.conversion(from, to),
                   into: %{},
                   do: {word, {String.to_atom(word), [{:value, from}, {:write, to}]}}

  # M5-10 (decisions 148 and 162): the 34 real conversions, between a real and an integer
  # type either way and between the two reals, `real_to_int fan_pct drive_sp` (Ed 3 Table
  # 23), and the 16 truncations, `real_trunc_int` (Table 22 feature 2b), each its source of
  # the `from` type and its destination of the `to` type. A real into an integer rounds, a
  # tie to the even neighbour, and passes no power where the rounded value wraps (decision
  # 161); a truncation truncates; and an integer into a real always fits.
  @reals Declarations.reals()

  @real_conversions for from <- Declarations.integers() ++ @reals,
                        to <- Declarations.integers() ++ @reals,
                        from in @reals or to in @reals,
                        word = Declarations.conversion(from, to),
                        into: %{},
                        do: {word, {String.to_atom(word), [{:value, from}, {:write, to}]}}

  @truncations for from <- @reals,
                   to <- Declarations.integers(),
                   word = "#{from}_trunc_#{to}",
                   into: %{},
                   do: {word, {String.to_atom(word), [{:value, from}, {:write, to}]}}

  @conversions @conversions |> Map.merge(@real_conversions) |> Map.merge(@truncations)

  @instructions Map.merge(@instructions, @conversions)

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

    rebuilt(kind, name, {rungs, tags, routine}, diagnostics)
  rescue
    # A tag declared from Elixir that no host could have given: no such body.
    ArgumentError -> :error
  end

  defp reparsed(_error, _name, _given), do: :error

  defp rebuilt({:block, name}, name, {rungs, tags, routine}, []) do
    {named, _reached} = Enum.map_reduce(tags, [], &naming/2)
    {units, reals, arrays} = Program.settled(tags)

    {:ok,
     %Program{
       name: name,
       rungs: rungs,
       tags: Map.new(named),
       units: units,
       reals: reals,
       arrays: arrays,
       warnings: warned(rungs, tags, reals, routine)
     }}
  end

  defp rebuilt(_kind, _name, _lowered, _diagnostics), do: :error

  @doc """
  Whether `body`'s rungs, tags and warnings are exactly what `instructionize/3` gives for
  some text over that tag table (M2-5): every rung lowers again, through the checks a
  compile makes, to itself, with no diagnostic; the one-per-bit, one-per-timer and
  one-per-instance rules and the path after a `ton` hold; each timer's preset is the
  number on the `ton` that runs it; the rungs are on rising lines, each on one line, after
  the declarations; the warnings are the ones its rungs give, a file aside; and since
  decision 197 its `units` are the ones its tags give (`Logex.Program.units/1`). Its tag
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
  def lowered?(
        %Program{
          rungs: rungs,
          tags: tags,
          blocks: blocks,
          warnings: warnings,
          units: units,
          reals: reals,
          arrays: arrays
        } = body
      )
      when is_list(rungs) and is_map(tags) and not is_struct(tags) and is_map(blocks) and
             is_list(warnings) do
    typed = Program.typed_tags(body)

    relowered(
      proper?(rungs, &ir_rung?/1) and proper?(warnings, &any?/1) and
        Enum.all?(typed, &typed?/1) and {units, reals, arrays} == Program.settled(typed),
      rungs,
      typed,
      {warnings, reals, body.source}
    )
  end

  def lowered?(_body), do: false

  defp relowered(false, _rungs, _tags, _warnings), do: false

  defp relowered(true, rungs, tags, {warnings, reals, source}) do
    known = {scope(tags), folded(tags)}
    instructions = Walk.instructions(rungs)
    {timed, timing} = presets(instructions, unpreset(tags))

    map_size(elem(known, 1)) == map_size(tags) and
      Enum.all?(rungs, &lowers_to_itself?(&1, known)) and
      shared_bits(instructions, tags) == [] and calls(instructions) == [] and timing == [] and
      jumps(rungs, {:block, nil}) == [] and timed == tags and
      Enum.flat_map(rungs, fn {:rung, elements} -> path(elements, known) end) == [] and
      lines?(rungs, tags) and
      Enum.map(warnings, &fileless/1) == rewarned(rungs, tags, {reals, source})
  end

  # A body's warnings, its declarations' among them since decision 227, read again from its
  # source, the text it was compiled from, which alone keeps an initial value's spelling; a
  # body of no real tag, or none whose source is held, has none of those.
  defp rewarned(rungs, tags, {reals, source}),
    do: warned(rungs, tags, reals, reparsed_source(reals, source))

  defp reparsed_source(nil, _source), do: nil
  defp reparsed_source(_reals, source) when is_binary(source), do: parsed_source(tokenize(source))
  defp reparsed_source(_reals, _source), do: {:routine, {:rungs, []}}

  defp parsed_source({:ok, tokens, _end_line}), do: parsed_routine(parse(tokens))
  defp parsed_source(_error), do: {:routine, {:rungs, []}}

  defp parsed_routine({:ok, routine}), do: routine
  defp parsed_routine(_error), do: {:routine, {:rungs, []}}

  # Each IR symbol back to its mnemonic.
  @mnemonics Map.new(@instructions, fn {word, {symbol, _signature}} -> {symbol, word} end)

  # A proper list, each element passing `test`: Enum.all?/2 raises on an improper one.
  defp proper?([], _test), do: true
  defp proper?([element | rest], test), do: test.(element) and proper?(rest, test)
  defp proper?(_not_a_list, _test), do: false

  defp any?(_element), do: true

  # A tag of a type the lowering knows, once each held type is given (M2-5).
  defp typed?({_name, %Tag{type: type}}) when is_elementary(type), do: true
  defp typed?({_name, %Tag{type: {:array, type, _dims}}}) when is_elementary(type), do: true
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

  # Decision 202: a literal keeps its spelling in the IR, by the parse tree's rule.
  defp ir_operand?({:int_lit, line, value, spelling}) when is_integer(line) and line > 0,
    do: is_integer(value) and Parser.spelled?(value, spelling)

  # M5-10: a real literal so, plain or spelled, by the parse tree's rules.
  defp ir_operand?({:real_lit, line, value}) when is_integer(line) and line > 0,
    do: Parser.plain_real?(value)

  defp ir_operand?({:real_lit, line, value, spelling}) when is_integer(line) and line > 0,
    do: is_float(value) and is_binary(spelling) and real_spelling(spelling) != nil

  defp ir_operand?({:member, line, path}) when is_integer(line) and line > 0,
    do: proper?(path, &is_binary/1)

  defp ir_operand?({:label, line, name}) when is_integer(line) and line > 0, do: is_binary(name)

  # M5-8: a bit, its container's path, its number, its mask and its name as written, which the rung's lowering
  # again must give exactly (lowers_to_itself?/2).
  defp ir_operand?({:bit, line, path, n, mask, name}) when is_integer(line) and line > 0,
    do: container?(path) and is_integer(n) and n >= 0 and is_integer(mask) and is_binary(name)

  # M5-9: a bit whose number a tag holds, its container's path, the tag, the width and top
  # bit, and its name as written.
  defp ir_operand?({:bit_at, line, path, {:name, at, index}, {width, top}, name})
       when is_integer(line) and line > 0 and is_integer(at) and at > 0,
       do:
         container?(path) and is_binary(index) and is_integer(width) and width > 0 and
           is_integer(top) and is_binary(name)

  # M5-11: an element, its array's name, its subscripts' values and its name as written.
  defp ir_operand?({:element, line, array, index, name}) when is_integer(line) and line > 0,
    do:
      is_binary(array) and index != [] and proper?(index, &(is_integer(&1) and &1 >= 0)) and
        is_binary(name)

  # M5-12: an element some of whose subscripts tags hold, each subscript a literal's value
  # or a tag's operand, its array's dimensions and its name as written, which the rung's
  # lowering again must give exactly (lowers_to_itself?/2).
  defp ir_operand?({:element_at, line, array, index, dims, name})
       when is_integer(line) and line > 0 and is_list(index) and is_list(dims),
       do:
         is_binary(array) and is_binary(name) and proper?(dims, &(is_integer(&1) and &1 > 0)) and
           length(index) == length(dims) and proper?(index, &subscript?/1)

  defp ir_operand?(_operand), do: false

  defp subscript?({:name, line, name}) when is_integer(line) and line > 0, do: is_binary(name)
  defp subscript?(n), do: is_integer(n) and n >= 0

  # A bit's container: a tag's or a member's path, or since decision 221 an element, and
  # since M5-12 one a tag subscripts.
  defp container?({:element, _, _, _, _} = element), do: ir_operand?(element)
  defp container?({:element_at, _, _, _, _, _} = element), do: ir_operand?(element)
  defp container?(path), do: proper?(path, &is_binary/1) and path != []

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

  defp unlowered_operand({:bit, line, _path, _n, _mask, name}), do: {:name, line, name}
  defp unlowered_operand({:bit_at, line, _path, _index, _width, name}), do: {:name, line, name}
  defp unlowered_operand({:element, line, _array, _index, name}), do: {:name, line, name}

  defp unlowered_operand({:element_at, line, _array, _index, _dims, name}),
    do: {:name, line, name}

  # M5-10's review: a real literal back to the leaf its spelling lexes to, its slot's
  # rounding undone, so that lowering it again must give the very value its slot computes
  # in and no other.
  defp unlowered_operand({:real_lit, line, _value, spelling}),
    do: real_leaf(real_spelling(spelling), line)

  defp unlowered_operand(operand), do: operand

  defp real_spelling(spelling), do: real_token(Logex.Lexer.tokenize(spelling))

  defp real_token({:ok, [{:real_lit, _at, _value} = token], _end}), do: token
  defp real_token({:ok, [{:real_lit, _at, _value, _spelling} = token], _end}), do: token
  defp real_token(_other), do: nil

  defp real_leaf({:real_lit, _at, value}, line), do: {:real_lit, line, value}
  defp real_leaf({:real_lit, _at, value, spelling}, line), do: {:real_lit, line, value, spelling}

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
  #
  # M5-11 (provisional): nor does it take an array var_input or var_output, which is one
  # value its `cal` fills with one operand, so an array is a block's own `var`: a `cal`
  # operand that is an array whole, and its copy, wait with whole-array copy (§4.12,
  # "Deferred"). Read in the same pass over the block's tags, its filter a comparison.
  defp externals({:block, _name}, tags),
    do:
      for(
        {name, %Tag{section: section, type: type, line: line}} <- tags,
        section == :var_external or
          (is_array(type) and (section == :var_input or section == :var_output)),
        do: block_section(section, line, name)
      )

  defp externals(:program, _tags), do: []

  defp block_section(:var_external, line, name), do: external(line, name)
  defp block_section(section, line, name), do: array_formal(line, name, section)

  defp external(nil, name), do: raise(ArgumentError, external_message(name))
  defp external(line, name), do: diagnostic(line, external_message(name))

  defp external_message(name),
    do:
      "`#{name}` cannot be a var_external in a function block's file: a block reaches no " <>
        "global of a configuration, so it takes one through a var_input, which the `cal` " <>
        "that runs it fills"

  # A tag declared from Elixir is refused as a host mistake, as an external's is.
  defp array_formal(nil, name, section),
    do: raise(ArgumentError, array_formal_message(name, section))

  defp array_formal(line, name, section),
    do: diagnostic(line, array_formal_message(name, section))

  defp array_formal_message(name, section),
    do:
      "`#{name}` cannot be an array #{section} of a function block: a `cal` fills each " <>
        "var_input and var_output with one value, so an array is the block's own `var`"

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
    coil = {bit, line, symbol, bit}
    {first, diagnostics} = storage_bit(Map.fetch(first, bit), tag, coil, acc)
    {first, own_pulse(Enum.map(pulse, &Walk.bit_name/1), tag, coil, diagnostics)}
  end

  # M5-8 (decision 155): a one-shot's storage bit may be a bit of a tag, `status.3`, named
  # by its path, under every rule a bool storage bit has; a bit of a member, as a member,
  # is the instance's, and is refused. A bit is keyed by its number's value and quoted as
  # written, `status.03`.
  defp shared_bit(
         {symbol, line, [{:bit, _, [_], _, _, written} = bit | pulse]},
         acc,
         _tags
       )
       when symbol in @one_shots,
       do: bit_storage(bit, {line, symbol, written}, pulse, acc)

  # Decision 221: so may a bit of an element, `faults[2].3`, its number literal, named by
  # its element's subscripts' values and its number's, `faults[2].3`.
  defp shared_bit(
         {symbol, line, [{:bit, _, {:element, _, _, _, _}, _, _, written} = bit | pulse]},
         acc,
         _tags
       )
       when symbol in @one_shots,
       do: bit_storage(bit, {line, symbol, written}, pulse, acc)

  # M5-11 (decision 154): a storage bit may be an element of a bool array, `edge[2]`, its
  # subscripts literal, named by its subscripts' values, `edge[2]`, under every rule a bool
  # storage bit has, and so may a pulse coil's pulse bit.
  defp shared_bit(
         {symbol, line, [{:element, _, array, _, written} = element | pulse]},
         {first, _} = acc,
         tags
       )
       when symbol in @one_shots do
    name = Walk.bit_name(element)
    tag = %Tag{name: name, type: element_type(Map.get(tags, array)), section: :var}
    coil = {name, line, symbol, written}
    {first, diagnostics} = storage_bit(Map.fetch(first, name), tag, coil, acc)
    {first, own_pulse(Enum.map(pulse, &Walk.bit_name/1), tag, coil, diagnostics)}
  end

  # M5-9 (decisions 154 and 160): a storage bit is named by its path, which a bit whose
  # number a tag holds has none of: the bit it names moves as the tag does, so no rule of
  # one one-shot to a bit could hold, nor an edit's block list name it.
  defp shared_bit(
         {symbol, line, [{:bit_at, _, _, {:name, _, index}, _, written} | _]},
         {first, d},
         _tags
       )
       when symbol in @one_shots,
       do: {first, [diagnostic(line, numbered_storage(symbol, written, index)) | d]}

  # M5-12 (decisions 152 and 154): so is an element a tag subscripts, `edge[slot]`, and a
  # bit of one, `faults[i].3`: the element it names moves as the tag does.
  defp shared_bit(
         {symbol, line, [{:element_at, _, _, index, _, written} | _]},
         {first, d},
         _tags
       )
       when symbol in @one_shots,
       do: {first, [diagnostic(line, subscripted_storage(symbol, written, index)) | d]}

  defp shared_bit(
         {symbol, line, [{:bit, _, {:element_at, _, _, index, _, _}, _, _, written} | _]},
         {first, d},
         _tags
       )
       when symbol in @one_shots,
       do: {first, [diagnostic(line, subscripted_storage(symbol, written, index)) | d]}

  defp shared_bit(
         {symbol, line, [{:bit, _, [instance, member], _, _, bit} | _]},
         {first, d},
         tags
       )
       when symbol in @one_shots,
       do:
         {first, member_bits(Map.get(tags, instance), {line, symbol}, {instance, member, bit}, d)}

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

  defp bit_storage(bit, {line, symbol, written}, pulse, {first, _} = acc) do
    name = Walk.bit_name(bit)
    tag = %Tag{name: name, type: :bool, section: :var}
    coil = {name, line, symbol, written}
    {first, diagnostics} = storage_bit(Map.fetch(first, name), tag, coil, acc)
    {first, own_pulse(Enum.map(pulse, &Walk.bit_name/1), tag, coil, diagnostics)}
  end

  # M3-4 (decision 101): a coil's pulse bit is not its storage bit. Each run writes both, the
  # pulse and then the power received, so one tag would hold only the power and never pulse.
  # A storage bit that is no declared bool was reported already.
  defp own_pulse([bit], %Tag{type: :bool}, {bit, line, symbol, written}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{written}` is both the storage bit and the pulse bit of this `#{symbol}`: its pulse " <>
          "bit is another tag, which it sets for one scan on an edge"
      )
      | diagnostics
    ]

  # M5-9 (decisions 154 and 160): so for a pulse coil's pulse bit.
  defp own_pulse(
         [{:bit_at, _, _, {:name, _, index}, _, written}],
         _tag,
         {_bit, line, symbol, _storage},
         diagnostics
       ),
       do: [diagnostic(line, numbered_pulse(symbol, written, index)) | diagnostics]

  # M5-12 (decision 154): so for a pulse bit an element a tag subscripts holds.
  defp own_pulse(
         [{:element_at, _, _, index, _, written}],
         _tag,
         {_bit, line, symbol, _storage},
         diagnostics
       ),
       do: [diagnostic(line, subscripted_pulse(symbol, written, index)) | diagnostics]

  defp own_pulse(
         [{:bit, _, {:element_at, _, _, index, _, _}, _, _, written}],
         _tag,
         {_bit, line, symbol, _storage},
         diagnostics
       ),
       do: [diagnostic(line, subscripted_pulse(symbol, written, index)) | diagnostics]

  defp own_pulse(_pulse, _tag, _coil, diagnostics), do: diagnostics

  defp subscripted_storage(symbol, written, index),
    do:
      "`#{symbol}` keeps its storage bit in `#{written}`, whose #{held_subscripts(index)}: " <>
        "a one-shot's storage bit is a bool, a bit with a literal number or an element with " <>
        "literal subscripts, as in `#{subscripted_example(written)}`, so that it is one bit " <>
        "whatever the program does"

  defp subscripted_pulse(symbol, written, index),
    do:
      "`#{symbol}` sets its pulse bit in `#{written}`, whose #{held_subscripts(index)}: a " <>
        "pulse coil's pulse bit is a bool, a bit with a literal number or an element with " <>
        "literal subscripts, as in `#{subscripted_example(written)}`, so that it is one bit " <>
        "whatever the program does"

  defp held_subscripts(index), do: held_by_tags(for({:name, _, text} <- index, do: "`#{text}`"))

  defp held_by_tags([one]), do: "subscript #{one} holds"
  defp held_by_tags(many), do: "subscripts #{Enum.join(many, " and ")} hold"

  # `edge[slot]` as `edge[0]`, `grid[r,2].3` as `grid[0,2].3`: each tag's name a 0.
  defp subscripted_example(written) do
    {element, rest} = split_element(:binary.split(written, "]"))
    {array, subscripts} = Logex.Array.split(element <> "]")

    zeroed =
      for text <- subscripts, do: zero_tag(Logex.Array.subscript(text), text)

    "#{array}[#{Enum.join(zeroed, ",")}]#{rest}"
  end

  defp split_element([element, rest]), do: {element, rest}

  defp zero_tag({:tag, _name}, _text), do: "0"
  defp zero_tag({:literal, _n}, text), do: text

  defp numbered_storage(symbol, written, index),
    do:
      "`#{symbol}` keeps its storage bit in `#{written}`, whose number `#{index}` holds: " <>
        "a one-shot's storage bit is a bool or a bit with a literal number, as in " <>
        "`#{numbered_example(written)}`, so that it is one bit whatever the program does"

  defp numbered_pulse(symbol, written, index),
    do:
      "`#{symbol}` sets its pulse bit in `#{written}`, whose number `#{index}` holds: a " <>
        "pulse coil's pulse bit is a bool or a bit with a literal number, as in " <>
        "`#{numbered_example(written)}`, so that it is one bit whatever the program does"

  defp numbered_example(written), do: hd(String.split(written, ".[")) <> ".0"

  defp element_type(%Tag{type: {:array, type, _dims}}), do: type
  defp element_type(_no_array), do: nil

  defp writable?(%Tag{type: %FbType{} = type}, member),
    do: match?({:ok, %Member{write: true, type: :bool}}, FbType.member(type, member))

  defp writable?(_tag, _member), do: false

  defp member_bit(true, {line, symbol, instance, member}, {first, diagnostics}),
    do:
      {first,
       [
         diagnostic(
           line,
           "`#{symbol}` keeps its storage bit in #{Declarations.a_type(:bool)} of its own, not in " <>
             "`#{instance}.#{member}`, a member of `#{instance}`, which its instance reads"
         )
         | diagnostics
       ]}

  defp member_bit(false, _one_shot, acc), do: acc

  # A bit of a member logic may write, a timer's `.pre`, is the instance's to keep; one it
  # may not write, or of a member that has no such bit, was reported already.
  defp member_bits(%Tag{type: %FbType{} = type}, at, {instance, member, n}, diagnostics),
    do: member_bits_of(FbType.member(type, member), at, {instance, member, n}, diagnostics)

  defp member_bits(_not_an_instance, _at, _bit, diagnostics), do: diagnostics

  defp member_bits_of({:ok, %Member{write: true}}, {line, symbol}, {instance, _member, bit}, d),
    do: [
      diagnostic(
        line,
        "`#{symbol}` keeps its storage bit in #{Declarations.a_type(:bool)} or a bit of a tag " <>
          "of its own, not in `#{bit}`, a bit of a member of `#{instance}`, " <>
          "which its instance reads"
      )
      | d
    ]

  defp member_bits_of(_unwritable, _at, _bit, diagnostics), do: diagnostics

  defp storage_bit(
         :error,
         %Tag{type: :bool},
         {bit, line, symbol, _written},
         {first, diagnostics}
       ),
       do: {Map.put(first, bit, {line, symbol}), diagnostics}

  defp storage_bit(
         {:ok, {first_line, other}},
         %Tag{},
         {_bit, line, symbol, written},
         {first, diagnostics}
       ) do
    message =
      "`#{written}` is already the storage bit of the `#{other}` #{where(first_line, line)}: " <>
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
  defp preset_of([{:int_lit, _, preset, _spelling}]), do: preset
  defp preset_of(_reported), do: nil

  defp preset({instance, _line, symbol, _pre} = runs, {run, first, diagnostics}, tags),
    do:
      run_by(
        Map.fetch(run, {instance, symbol}),
        Map.get(tags, instance),
        runs,
        {run, first, diagnostics}
      )

  defp run_by(:error, %Tag{type: %FbType{} = type}, {instance, line, symbol, pre}, acc) do
    {run, first, diagnostics} = acc
    run = Map.put(run, {instance, symbol}, line)

    agreed(
      Map.fetch(first, instance),
      {instance, line, symbol, pre},
      type,
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
  defp agreed({:ok, {first_line, other, pre}}, {instance, line, symbol, given}, type, acc)
       when pre != given and is_integer(pre) and is_integer(given) do
    {run, first, diagnostics} = acc

    message =
      "`#{instance}` already has the preset #{pre} from the `#{other}` " <>
        "#{where(first_line, line)}: the `ctu` and the `ctd` of " <>
        "#{Declarations.a_or_an(ctud_of(type))} give it one preset, " <>
        "so this `#{symbol}` takes #{pre} too"

    {run, first, [diagnostic(line, message) | diagnostics]}
  end

  defp agreed(_first, _runs, _type, acc), do: acc

  # The up-down counter a counter's two sides make, by its own word since M5-5's review,
  # a `ctud_int`'s own and a `ctu_int`'s `ctud_int`, as a counter of the other kind is told
  # to declare; any other type, which its own diagnostic refuses, a plain `ctud`.
  defp ctud_of(%FbType{name: name} = type), do: ctud_word(FbType.family(type), name)

  defp ctud_word(kind, name) when kind in ["ctu", "ctd", "ctud"],
    do: String.replace_prefix(name, kind, "ctud")

  defp ctud_word(_kind, _name), do: "ctud"

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
  defp text(literal) when is_literal(literal), do: Parser.spelling(literal)
  defp text({:member, _, path}), do: Enum.join(path, ".")
  defp text({:label, _, name}), do: name
  defp text({:bit, _, _path, _n, _mask, name}), do: name
  defp text({:bit_at, _, _path, _index, _width, name}), do: name
  defp text({:element, _, _array, _index, name}), do: name
  defp text({:element_at, _, _array, _index, _dims, name}), do: name

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
  defp lowered(:program, rungs, {tags, held}, [], routine) do
    {named, blocks} = hold(tags, held)
    {units, reals, arrays} = Program.settled(tags)

    {:ok,
     %Program{
       rungs: rungs,
       tags: named,
       blocks: blocks,
       units: units,
       reals: reals,
       arrays: arrays,
       warnings: warned(rungs, tags, reals, routine)
     }}
  end

  defp lowered({:block, name}, rungs, {tags, held}, [], routine) do
    {named, blocks} = hold(tags, held)
    {units, reals, arrays} = Program.settled(tags)

    body = %Program{
      name: name,
      source: printed(routine),
      rungs: rungs,
      tags: named,
      blocks: blocks,
      units: units,
      reals: reals,
      arrays: arrays,
      warnings: warned(rungs, tags, reals, routine)
    }

    {:ok, FbType.of(body)}
  end

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_kind, _rungs, _tags, diagnostics, _routine),
    do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  # The warnings of the lowered rungs and, since decision 227, of the declaration lines'
  # real initial values, read from the parse tree, where each keeps its spelling, merged by
  # line as the warnings are.
  defp warned(rungs, tags, nil, _routine), do: Logex.Warnings.of(rungs, tags)

  defp warned(rungs, tags, reals, {:routine, {:rungs, parsed}}),
    do:
      Enum.sort_by(
        Logex.Warnings.initials(parsed, reals) ++ Logex.Warnings.of(rungs, tags),
        & &1.line
      )

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
  defp element_line([{_literal, line, _value, _spelling} | _elements]), do: line

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
  # name no label can be, is passed over, so one mistake gives one message. In a function
  # block's body the word that heads its file names no label, in any case, as it names no
  # tag there (docs/organisation.md §4.8), each `lbl` and `jmp` that names it an error at
  # its line. Two walks of the rungs, with maps that are only looked up, so it stays linear.
  defp jumps(rungs, kind) do
    indexed = Enum.with_index(rungs)
    {labels, _folded, diagnostics} = Enum.reduce(indexed, {%{}, %{}, []}, &labelled(&1, &2, kind))
    Enum.reverse(Enum.reduce(indexed, diagnostics, &jumps_in(&1, &2, {labels, kind})))
  end

  # Each `lbl` in turn, the one that heads its rung, if one does, first, as the walk gives
  # them: a misplaced one is refused, and each labels its rung.
  defp labelled({{:rung, elements} = rung, index}, acc, kind) do
    lbls = for {:lbl, _, _} = lbl <- Walk.instructions([rung]), do: lbl
    {heads, others} = Enum.split(lbls, heads(elements))
    acc = Enum.reduce(heads, acc, &label(&1, {index, kind}, &2))
    Enum.reduce(others, acc, &label(&1, {index, kind}, misplaced(&1, &2)))
  end

  # How many of a rung's `lbl`s head it: its first element's, if that is one.
  defp heads([{:lbl, _, _} | _]), do: 1
  defp heads(_elements), do: 0

  defp label({:lbl, line, [{:label, _, name}]}, {index, kind}, acc),
    do: label_named(label_in(name, kind), {name, line, index}, acc)

  defp label(_reported, _at, acc), do: acc

  defp label_named(:label, {name, line, index}, {labels, folded, diagnostics}) do
    key = String.downcase(name)

    twin(
      Map.fetch(labels, name),
      Map.fetch(folded, key),
      {name, line, index, key},
      {labels, folded, diagnostics}
    )
  end

  defp label_named(:header, {name, line, _index}, {labels, folded, diagnostics}),
    do: {labels, folded, [header_label(name, line) | diagnostics]}

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
        label_in(name, kind),
        Map.fetch(labels, name),
        {name, line, index},
        {labels, kind},
        diagnostics
      )

  defp target(_reported, _index, diagnostics, _context), do: diagnostics

  # The nearest label is suggested among those on a later rung alone, since one on an
  # earlier rung or this one would be refused as a jump back.
  defp targeted(:label, :error, {name, line, from}, {labels, kind}, diagnostics) do
    later = for {label, {_at, to}} <- labels, to > from, do: label

    message =
      "`jmp #{name}` names no label: no rung of this #{routine(kind)} begins `lbl #{name}`" <>
        Declarations.suggest(name, later, & &1, "labels")

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

  defp targeted(:header, _found, {name, line, _from}, _context, diagnostics),
    do: [header_label(name, line) | diagnostics]

  defp targeted(_reported, _found, _jmp, _context, diagnostics), do: diagnostics

  defp header_label(name, line),
    do: diagnostic(line, "`#{name}` heads a function block's file and cannot name a label in one")

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
  defp lower([literal | rest], ir, diagnostics, known) when is_literal(literal),
    do: stray(elem(literal, 1), literal, rest, {ir, diagnostics, known})

  defp stray(line, literal, rest, {ir, diagnostics, known}) do
    found = diagnostic(line, "expected an instruction, found `#{Parser.spelling(literal)}`")
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
    diagnostics = check_literals(symbol, operands, {at, scope}, diagnostics)
    diagnostics = check_shift(symbol, operands, at, diagnostics)
    lowered = {symbol, line, slot_operands(signature, operands, scope, {signature, operands})}
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

  defp cal([literal], {line, word}, {rest, ir, diagnostics, known}) when is_literal(literal) do
    message =
      "`#{word}` expects an instance of a function block, found `#{Parser.spelling(literal)}`"

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
    lowered = {:cal, line, [instance | Enum.map(operands, &bit_operand(&1, scope))]}
    lower(rest, [lowered | ir], diagnostics, known)
  end

  # Anything else is not run by `cal`, and its would-be operands are passed over: a timer,
  # which its `ton` runs; a bool or an integer; a member; a reserved word; or a name no
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

  defp not_run(nil, {:ok, %Tag{type: type} = tag}, line, name, word) when is_array(type),
    do: [
      diagnostic(
        line,
        "`#{word}` runs an instance of a function block, but `#{name}` is " <>
          "#{a_type(type)}#{declared(tag)}"
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

  defp cal_operand(formal, literal, at, _scope, diagnostics) when is_literal(literal),
    do: cal_literal(formal, literal, {elem(literal, 1), at}, diagnostics)

  defp cal_operand({slot, _} = formal, {:name, line, name} = operand, at, scope, diagnostics),
    do:
      by_formal(
        Declarations.reserved(name),
        lookup(name, scope),
        {formal, slot, operand},
        {line, at},
        {scope, diagnostics}
      )

  defp cal_literal({{:value, type}, _} = formal, literal, at, diagnostics),
    do:
      fits_formal(
        Declarations.holds?(type, Parser.value(literal)),
        formal,
        literal,
        at,
        diagnostics
      )

  defp cal_literal({{:write, _}, _} = formal, literal, {line, at}, diagnostics),
    do: [
      diagnostic(
        line,
        of_formal(formal, at) <> ", which it writes: found `#{Parser.spelling(literal)}`"
      )
      | diagnostics
    ]

  defp fits_formal(true, _formal, _literal, _at, diagnostics), do: diagnostics

  defp fits_formal(false, {{_, type}, _} = formal, literal, {line, at}, diagnostics),
    do: [
      diagnostic(
        line,
        of_formal(formal, at) <>
          ": " <>
          Declarations.literal_misfit(
            type,
            Parser.value(literal),
            "`#{Parser.spelling(literal)}`"
          )
      )
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

  defp by_formal(
         nil,
         {:ok, %Tag{type: type}} = found,
         {_formal, slot, operand},
         {line, _at},
         {_, d}
       )
       when is_array(type),
       do: resolve(nil, found, slot, operand, {line, "cal"}, d)

  defp by_formal(nil, {:ok, %Tag{} = tag}, {formal, {access, type}, _}, {line, at}, {_, d}),
    do:
      d
      |> typed_formal({access, type}, tag.type, tag.name, {formal, line, at})
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
         |> typed_formal({access, type}, member.type, name, {formal, line, at})
         |> member_formal(access, tag, member, name, {formal, line, at})

  defp by_formal(nil, {:tag_element, element, found}, formal, {line, at}, {scope, d}) do
    {:name, _, name} = elem(formal, 2)
    by_formal(nil, element, formal, {line, at}, {scope, subscripted_by(found, {line, name}, d)})
  end

  defp by_formal(nil, {:tag_bit, bit, index, found}, formal, {line, at}, {scope, d}) do
    {:name, _, name} = elem(formal, 2)
    by_formal(nil, bit, formal, {line, at}, {scope, numbered(found, index, {line, name}, d)})
  end

  defp by_formal(
         reserved,
         found,
         {_formal, slot, operand},
         {line, {_n, {_at, _instance}}},
         {_scope, d}
       ),
       do: resolve(reserved, found, slot, operand, {line, "cal"}, d)

  # M5-3 (decision 159): a `cal`'s operand meets its formal as an instruction's does: one
  # the block reads, a var_input, takes a tag of a type Ed 3 Figure 11 widens into the
  # formal's, and one it writes, a var_output, a tag of a type the formal's widens into, as
  # a destination takes a value (IEC's rules 4 and 5, p.66). Anything else is told the
  # conversion that would bridge them, where logex has one.
  defp typed_formal(diagnostics, {_access, type}, type, _name, _at), do: diagnostics

  defp typed_formal(diagnostics, {access, type}, found, name, at)
       when is_elementary(type) and is_elementary(found),
       do:
         formal_widens(widened(access, type, found), {access, type}, found, name, at, diagnostics)

  defp typed_formal(diagnostics, _slot, found, name, {formal, line, at}),
    do: [
      diagnostic(line, of_formal(formal, at) <> ", but `#{name}` is #{a_type(found)}")
      | diagnostics
    ]

  defp widened(:write, type, found), do: {Declarations.widens?(type, found), type, found}
  defp widened(_read, type, found), do: {Declarations.widens?(found, type), found, type}

  defp formal_widens({true, _from, _to}, _slot, _found, _name, _at, diagnostics), do: diagnostics

  defp formal_widens({false, from, to}, _slot, found, name, {formal, line, at}, diagnostics),
    do: [
      diagnostic(
        line,
        of_formal(formal, at) <>
          ", but `#{name}` is #{a_type(found)}" <>
          formal_conversion(Declarations.conversion(from, to), from, to)
      )
      | diagnostics
    ]

  # A bool and an integer have no conversion: the message stays M2-5's.
  defp formal_conversion(nil, _from, _to), do: ""

  defp formal_conversion(conversion, from, to),
    do: ": #{a_type(from)} does not widen into #{a_type(to)}, so convert it with `#{conversion}`"

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
  # Since M5-8 bit_operand/2 below lowers every operand.

  # M3-5: in a label slot a name is a label, `{:label, line, name}`, never a tag or a member,
  # whatever it holds; anything else lowers as any operand does.
  defp slot_operand({:label, _}, {:name, line, name}, _scope), do: {:label, line, name}
  defp slot_operand(_slot, operand, scope), do: bit_operand(operand, scope)

  # Each operand lowered in its slot, the instruction whole carried along for a real
  # literal's, which alone needs the others; operands past the slots were reported by
  # check_count/5. A recursion of its own, as M5-9's walk has, so an instruction of no real
  # literal lowers in fewer reductions than a zip did.
  defp slot_operands([slot | slots], [operand | operands], scope, whole)
       when is_real_lit(operand),
       do: [
         real_operand(slot, operand, whole, scope) | slot_operands(slots, operands, scope, whole)
       ]

  defp slot_operands([slot | slots], [operand | operands], scope, whole),
    do: [slot_operand(slot, operand, scope) | slot_operands(slots, operands, scope, whole)]

  defp slot_operands(_slots, _operands, _scope, _whole), do: []

  # M5-10's review (provisional): a real literal is a value of the real its slot computes
  # in, as Logix stores an unsuffixed floating-point immediate as a REAL (1756-RM018A
  # p.870), IEC's rule for an untyped literal's type unverified: a conversion's source its
  # `from` type, `real_to_int 0.1 i` a `real`'s 0.1; `move`, the arithmetic and `sqrt`
  # their destination's, `add a 0.1 r` a `real`'s; a comparison the other operand's, `eq r
  # 0.1` a `real`'s; and anything else, two literals among them, as it lexed, a double.
  # In a `real` it is the nearest single, rounded once, so that `move 0.1 r` then `eq r 0.1`
  # is true; its spelling kept, `{:real_lit, line, 0.10000000149011612, "0.1"}`, so every
  # message quotes it as written. A literal past its slot's range was refused, and is left.
  defp real_operand(slot, literal, {signature, operands}, scope),
    do: in_real(literal_real(slot, signature, operands, &parsed_real(&1, &2, scope)), literal)

  @doc false
  # The real a real literal's slot computes in, nil where none is, the one rule, which the
  # lowering above reads over a rung's operands and `Logex.Warnings` over the IR's
  # (decision 219): a slot of a real type its own, a conversion's source or a `cal`'s real
  # formal; otherwise the first operand a slot writes, `move`'s, the arithmetic's and
  # `sqrt`'s destination; and with none, the first tag among the operands, a comparison's
  # other. `type_of` gives an operand's real, `{:tag, type}` for a tag or member, `type`
  # nil where it is no real, and `:literal` for a literal.
  def literal_real({_access, type}, _slots, _operands, _type_of) when type in @reals, do: type

  def literal_real(_slot, slots, operands, type_of),
    do: written_real(slots, operands, operands, type_of)

  defp written_real([{:write, _} | _], [operand | _], _all, type_of),
    do: tag_real(type_of.(:write, operand))

  defp written_real([_ | slots], [_ | operands], all, type_of),
    do: written_real(slots, operands, all, type_of)

  defp written_real(_slots, _operands, all, type_of), do: compared_with(all, type_of)

  defp compared_with([operand | operands], type_of),
    do: compared(type_of.(:value, operand), operands, type_of)

  defp compared_with([], _type_of), do: nil

  defp compared({:tag, type}, _operands, _type_of), do: type
  defp compared(:literal, operands, type_of), do: compared_with(operands, type_of)

  defp tag_real({:tag, type}), do: type
  defp tag_real(:literal), do: nil

  # An operand of a rung, as the lowering reads it.
  defp parsed_real(_access, literal, _scope) when is_literal(literal), do: :literal

  defp parsed_real(access, {:name, _, _} = operand, scope),
    do: {:tag, real_type(typed(access, operand, scope))}

  defp real_type(%Tag{type: type}) when type in @reals, do: type
  defp real_type(_other), do: nil

  defp in_real(nil, literal), do: literal

  defp in_real(type, literal),
    do: nearer(Logex.Real.in_range?(type, Parser.value(literal)), type, literal)

  defp nearer(false, _type, literal), do: literal

  defp nearer(true, type, literal),
    do: kept(Logex.Real.nearest(type, Parser.value(literal)), literal)

  defp kept(value, literal) when value === elem(literal, 2), do: literal
  defp kept(value, literal), do: {:real_lit, elem(literal, 1), value, Parser.spelling(literal)}

  # M5-8 (decision 155): a bit, `status.3` or `t1.acc.3`, is lowered to its container's path
  # and its number, `{:bit, line, ["status"], 3, mask, "status.3"}`, with the mask a scan reads and
  # writes it through: 2^n, or for a signed type's top bit, its sign, every bit from n up,
  # -(2^n), so that the bit is read and written in two's complement with no type looked
  # up. A dotted name whose container has no bits lowers as a member, and is reported.
  # The name is split once: a name with no `.` is a tag, and one with a last part that is no
  # number a member, each with no table looked up, so that a program of bools and integers
  # lowers its operands in what it did before bits.
  defp bit_operand({:name, line, name}, scope),
    do: parted(String.split(name, "."), {line, name}, scope)

  defp bit_operand(literal, _scope), do: literal

  # M5-11 (decision 151): an element, `temps[3]` or `grid[1,7]`, its subscripts literal, is
  # lowered to its array's name and its subscripts' values, `{:element, line, "grid", [1,
  # 7], "grid[1,7]"}`, with its name as written, which a message quotes, so that a scan
  # reads and writes it with no name split. Told from a tag by its name's last byte, which
  # the clause's guard reads, so a tag lowers in what it did.
  defp parted([one], {line, name}, scope) when binary_part(name, byte_size(name) - 1, 1) == "]",
    do: element_ir(lookup_parts([one], scope), {line, name}, scope)

  defp parted([_one], {line, name}, _scope), do: {:name, line, name}

  defp parted(path, at, scope),
    do: as_bit(Integer.parse(List.last(path)), path, at, scope)

  defp as_bit({n, ""}, path, at, scope) do
    container = Enum.drop(path, -1)
    found = lookup(Enum.join(container, "."), scope)
    type = container_type(found)
    bit_ir_of(bits(type), {n, type, container, found}, path, {at, scope})
  end

  # M5-9 (decision 160): a bit whose number a tag holds, `status.[n]`, its last part
  # bracketed, is lowered to its container's path, the tag, and its container's width and
  # top bit, `{:bit_at, line, ["status"], {:name, line, "n"}, {16, 32768}, "status.[n]"}`, so
  # that a scan computes the mask from the number it reads, the top bit's a signed type's
  # sign, as `status.15` is lowered, with no type looked up. Told from a member by its
  # name's last byte, which the clause's guard reads, so a member costs what it did.
  defp as_bit(:error, path, {_line, name} = at, scope)
       when binary_part(name, byte_size(name) - 1, 1) == "]" do
    {container, [part]} = Enum.split(path, -1)
    bracketed_bit(part, container, path, at, scope)
  end

  defp as_bit(_no_number, path, {line, _name}, _scope), do: {:member, line, path}

  # Decision 213: a literal in the brackets, `status.[4]`, lowers as `status.4` does, its
  # name as written.
  defp bracketed_bit(<<?[, d, _::binary>> = part, _container, path, at, scope)
       when d in ?0..?9 or d == ?-,
       do: as_bit({literal_number(part), ""}, path, at, scope)

  defp bracketed_bit("[" <> bracketed, container, path, at, scope) do
    found = lookup(Enum.join(container, "."), scope)
    type = container_type(found)
    tag_bit_ir(bits(type), {type, container, numbered_by(bracketed)}, path, {at, {found, scope}})
  end

  defp bracketed_bit(_element, _container, path, {line, _name}, _scope),
    do: {:member, line, path}

  defp tag_bit_ir(nil, _bit, path, {{line, _name}, _scope}), do: {:member, line, path}

  defp tag_bit_ir(width, {type, container, index}, _path, {{line, name}, found}),
    do:
      {:bit_at, line, held_in(container, line, found), {:name, line, index},
       {width, mask(Declarations.kind(type), width - 1, width)}, name}

  # Decision 221: a bit of an element, `faults[2].3`, is held in the element, its container
  # the element's own operand, `{:element, line, "faults", [2], "faults[2]"}`, in place of a
  # path, so that a scan reads and writes the element and then its bit; a tag's or a
  # member's container is its path, as before.
  defp held_in([one], line, {found, scope}) when binary_part(one, byte_size(one) - 1, 1) == "]",
    do: element_at(found, line, one, scope)

  defp held_in(path, _line, _found), do: path

  defp element_ir({:ok, %Tag{}}, {line, name}, _scope) do
    {array, subscripts} = Logex.Array.split(name)
    index = for text <- subscripts, do: elem(Logex.Array.subscript(text), 1)
    {:element, line, array, index, name}
  end

  # M5-12 (decision 152): an element some of whose subscripts tags hold, `weights[slot]`, is
  # lowered to its array's name, each subscript a literal's value or the tag's operand, its
  # array's dimensions, which a scan checks each subscript it reads against, and its name
  # as written, `{:element_at, line, "weights", [{:name, line, "slot"}], [8],
  # "weights[slot]"}`; an element of literal subscripts lowers as it did.
  defp element_ir({:tag_element, {:ok, %Tag{}}, _found}, {line, name}, {tags, _members}),
    do: tag_element_ir(Logex.Array.split(name), {line, name}, tags)

  # One that is refused lowers as a name, which no scan runs.
  defp element_ir(_refused, {line, name}, _scope), do: {:name, line, name}

  defp tag_element_ir({array, subscripts}, {line, name}, tags) do
    index = for text <- subscripts, do: subscript_operand(Logex.Array.subscript(text), line)
    %Tag{type: {:array, _type, dims}} = Map.fetch!(tags, array)
    {:element_at, line, array, index, dims, name}
  end

  defp subscript_operand({:literal, n}, _line), do: n
  defp subscript_operand({:tag, text}, line), do: {:name, line, text}

  # A bit's element: one a tag subscripts as element_ir/3 lowers it, and one of literal
  # subscripts as it did.
  defp element_at({:tag_element, _element, _found} = found, line, name, scope),
    do: element_ir(found, {line, name}, scope)

  defp element_at(_found, line, name, _scope) do
    {array, subscripts} = Logex.Array.split(name)
    index = for text <- subscripts, do: elem(Logex.Array.subscript(text), 1)
    {:element, line, array, index, name}
  end

  defp container_type({:ok, %Tag{type: type}}), do: type
  defp container_type({:tag_element, found, _subscripts}), do: container_type(found)
  defp container_type({:member, _tag, %Member{type: type}}), do: type
  defp container_type(_nothing), do: nil

  # A bit carries its name as written, `status.03`, which a message quotes (decision 202's
  # rule for a literal, provisional for a bit's number); its number is its value.
  defp bit_ir_of(nil, _n, path, {{line, _name}, _scope}), do: {:member, line, path}
  # A negative number, `status.[-1]`, which is refused, lowers as nothing a scan runs.
  defp bit_ir_of(_width, {n, _type, _container, _found}, path, {{line, _name}, _scope})
       when n < 0,
       do: {:member, line, path}

  # Decision 221: a bit of an element is held in the element (held_in/2), told by its
  # container's last byte in the clause's head, so a tag's or a member's bit lowers in
  # what it did.
  defp bit_ir_of(width, {n, type, [one], found}, _path, {{line, name}, scope})
       when binary_part(one, byte_size(one) - 1, 1) == "]",
       do:
         {:bit, line, element_at(found, line, one, scope), n,
          mask(Declarations.kind(type), n, width), name}

  defp bit_ir_of(width, {n, type, container, _found}, _path, {{line, name}, _scope}),
    do: {:bit, line, container, n, mask(Declarations.kind(type), n, width), name}

  defp mask(:signed, n, width) when n == width - 1, do: -Integer.pow(2, n)
  defp mask(_kind, n, _width), do: Integer.pow(2, n)

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

  defp take_operands([literal | rest], n, taken) when is_literal(literal),
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

  defp check_kind({:value, _type}, literal, _at, diagnostics) when is_literal(literal),
    do: diagnostics

  defp check_kind({:instance, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  defp check_kind({:preset, _type}, literal, _at, diagnostics) when is_literal(literal),
    do: diagnostics

  defp check_kind({:label, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  # A preset from a tag is not a preset: check_preset/4 names the `move` that is meant.
  defp check_kind({:preset, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics

  defp check_kind(kind, literal, {line, word}, diagnostics) when is_literal(literal),
    do: [
      diagnostic(line, "`#{word}` expects #{kind(kind)}, found `#{Parser.spelling(literal)}`")
      | diagnostics
    ]

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
      "`#{word}` takes its preset as #{unit(symbol, runnable_of(first, symbol, known))}, " <>
        "found `#{name}`" <> moved(first, name, symbol, known)

    [diagnostic(line, message) | diagnostics]
  end

  defp check_preset(_signature, _operands, _at, _known, diagnostics), do: diagnostics

  # M3-3 (decision 78): a zero divisor gives 0 and passes no power, so a literal one could
  # never divide, and is refused where it stands, `-0` among them, which lexes as 0. A tag
  # that is 0 for a while is the run's to report (Logex.Runtime). Since M5-10 so is a
  # literal negative source of `sqrt`, whose destination must be a real (decisions 164 and
  # 167): one call an instruction, as before reals.
  defp check_literals(symbol, [_dividend, {:int_lit, line, 0} = zero | _], {at, _scope}, d)
       when symbol in [:div, :mod],
       do: zero_divisor(line, zero, at, d)

  # Decision 202: `16#0`, `0_0`, `00` and `-0` are zero too, each quoted as written.
  defp check_literals(symbol, [_dividend, {:int_lit, line, 0, _} = zero | _], {at, _scope}, d)
       when symbol in [:div, :mod],
       do: zero_divisor(line, zero, at, d)

  # M5-10 (decision 150): a real literal zero, `0.0` or `-0.0`, which lexes as 0.0, as an
  # integer's is refused.
  defp check_literals(symbol, [_dividend, zero | _], {at, _scope}, d)
       when symbol in [:div, :mod] and is_real_zero(zero),
       do: zero_divisor(elem(zero, 1), zero, at, d)

  # M5-10 (decision 167): a literal negative source of `sqrt`, `sqrt -4.0 root`, would raise
  # `:negative_sqrt` on every scan, so it is refused where it stands, as decision 78
  # refuses a literal zero divisor; `-0.0`, whose value is 0.0, is no negative number.
  defp check_literals(:sqrt, [source, _destination], {at, _scope}, d),
    do: root_source(source, at, d)

  defp check_literals(_symbol, _operands, _at, diagnostics), do: diagnostics

  defp root_source(source, at, diagnostics) when is_literal(source),
    do: negative_root(Parser.value(source) < 0, source, at, diagnostics)

  defp root_source(_source, _at, diagnostics), do: diagnostics

  defp negative_root(false, _source, _at, diagnostics), do: diagnostics

  defp negative_root(true, source, {_line, word}, diagnostics),
    do: [
      diagnostic(
        elem(source, 1),
        "`#{word}` takes the root of the literal `#{Parser.spelling(source)}`: a negative " <>
          "source gives 0.0, passes no power and raises a minor fault on every scan, so a " <>
          "literal one is refused"
      )
      | diagnostics
    ]

  # M5-8 (decision 165): a negative literal count is refused, IEC's "It is an error if the
  # value of the N input is less than zero" (Ed 3 Table 30 footnote a) where a program can
  # show it; a tag count negative at run time shifts nothing and passes no power.
  @shifts [:shl, :shr, :rol, :ror]

  defp check_shift(symbol, [_source, count | _], at, diagnostics)
       when symbol in @shifts and is_int_lit(count),
       do: negative_count(Parser.value(count) < 0, count, at, diagnostics)

  defp check_shift(_symbol, _operands, _at, diagnostics), do: diagnostics

  defp negative_count(false, _count, _at, diagnostics), do: diagnostics

  defp negative_count(true, count, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` shifts by the literal `#{Parser.spelling(count)}`: a count is never " <>
          "negative, so a negative literal one is refused"
      )
      | diagnostics
    ]

  defp zero_divisor(line, zero, {_, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` divides by the literal `#{Parser.spelling(zero)}`: a zero divisor gives " <>
          "#{zero_of(zero)} and passes no power on every scan, so a literal one is refused"
      )
      | diagnostics
    ]

  defp zero_of(literal) when is_int_lit(literal), do: "0"
  defp zero_of(_real), do: "0.0"

  # Since M5-6 a timer's unit is its instance's, a long timer's nanoseconds (decision 158).
  defp unit(symbol, type), do: unit_of(kind_of(symbol), per_ms(type), type)

  defp unit_of(:timer, 1, _type), do: "a number of milliseconds"

  defp unit_of(:timer, _per_ms, %FbType{name: name}),
    do: "a number of nanoseconds for #{Declarations.a_or_an(name)}"

  defp unit_of(:counter, _per_ms, _type), do: "a number, a count"

  # The type of the instance the instruction runs, where its first operand names one, or
  # nil.
  defp runnable_of({:name, _, instance}, symbol, known), do: runnable(symbol, instance, known)
  defp runnable_of(_literal, _symbol, _known), do: nil

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
    do: move(runnable(symbol, instance, known), instance, name, known)

  # Into a type the instruction runs, a name not declared yet read as the instruction's
  # own, and from a source `move` widens into its preset member's type, since M5-5 its
  # instance's, a `ctu_int`'s `pv` an int; into nothing the instruction runs, no hint.
  defp move(%FbType{} = type, instance, name, known),
    do: move_from(widens_into?(name, known, preset_type(type)), type, instance, name)

  defp move(nil, _instance, _name, _known), do: ""

  defp move_from(true, type, instance, name),
    do:
      ": to preset `#{instance}` from a tag, `move #{name} #{instance}." <>
        "#{FbType.rules(type).preset}` on a rung above"

  defp move_from(false, _type, _instance, _name), do: ""

  defp widens_into?(name, known, into),
    do: widens_value?(Declarations.reserved(name), hinted(name, known), into)

  # M5-3: a source `move` widens into the preset's type (decision 147), an `int` into a
  # dint among them; since M5-5 the preset's type is its instance's, a `ctu_int`'s an int.
  defp widens_value?(nil, {:ok, %Tag{type: type}}, into) when is_elementary(type),
    do: Declarations.widens?(type, into)

  defp widens_value?(nil, {:member, _tag, %Member{type: type}}, into) when is_elementary(type),
    do: Declarations.widens?(type, into)

  defp widens_value?(nil, :error, _into), do: true
  defp widens_value?(_reserved, _found, _into), do: false

  # M1-3: each operand against the tag table -- declared, of the type its slot reads or
  # writes, and not a var_input where the slot writes. A literal where a tag must go was
  # reported by check_kind/4 and is not looked at again. Then the `:any` operands must agree.
  defp check_tags(signature, operands, at, scope, diagnostics) do
    slots = judged(Enum.zip(signature, operands), at, scope)
    diagnostics = Enum.reduce(slots, diagnostics, &check_tag(&1, at, scope, &2))

    diagnostics =
      unify(
        for({{access, :any}, operand} <- slots, typed = typed(access, operand, scope), do: typed),
        at,
        diagnostics
      )

    classed(
      for(
        {{access, class}, operand} <- slots,
        is_class(class),
        do: {access, class, typed(access, operand, scope)}
      ),
      at,
      diagnostics
    )
  end

  # M5-5 (decision 158): a preset is judged in its instance's type, the type of the member
  # it starts, a `ctu_int`'s `pv` an int, where the instruction runs the instance; a dint
  # for every other, the timers' and a name that is no such instance, which has its own
  # diagnostic.
  defp judged(
         [{{:instance, _} = slot, {:name, _, name} = operand}, {{:preset, _}, preset}],
         at,
         scope
       ),
       do: [{slot, operand}, {{:preset, counts_in(lookup(name, scope), at)}, preset}]

  defp judged(slots, _at, _scope), do: slots

  # Since M5-6 the slot carries the instance's type too, whose rules give its unit: a
  # `ton_ltime`'s preset is a lint of nanoseconds (decision 158).
  defp counts_in({:ok, %Tag{type: %FbType{} = type}}, {_, word}),
    do: judged_in(FbType.runs?(type, symbol_of(word)), type)

  defp counts_in(_not_an_instance, _at), do: {:dint, nil}

  defp judged_in(true, type), do: {preset_type(type), type}
  defp judged_in(false, _type), do: {:dint, nil}

  defp preset_type(type) do
    {:ok, %Member{type: counts}} = FbType.member(type, FbType.rules(type).preset)
    counts
  end

  # A literal in a slot of an elementary type must fit it, as a declared initial value must
  # (M1-6: the comparisons, whose slots were dints; since M5-4 a conversion's source). An
  # `:any` slot's literal is checked against the tag beside it, by unify/3, and a generic
  # slot's against the type its instruction computes in, by classed/3. Since M3-3 a literal may be negative (decision
  # 97), so each meets one too small too.
  # Since M5-10 by the literal rules, `Logex.Declarations.holds?/2` (decision 147): a real
  # literal is no integer slot's, and an integer literal a real slot's only exactly.
  defp check_tag({{:value, type}, {:int_lit, line, value} = lit}, {_, word}, _scope, d)
       when is_elementary(type),
       do: literal(Declarations.holds?(type, value), {type, lit}, {line, word}, d)

  defp check_tag({{:value, type}, {:int_lit, line, value, _} = lit}, {_, word}, _scope, d)
       when is_elementary(type),
       do: literal(Declarations.holds?(type, value), {type, lit}, {line, word}, d)

  defp check_tag({{:value, type}, {:real_lit, line, value} = lit}, {_, word}, _scope, d)
       when is_elementary(type),
       do: literal(Declarations.holds?(type, value), {type, lit}, {line, word}, d)

  defp check_tag({{:value, type}, {:real_lit, line, value, _} = lit}, {_, word}, _scope, d)
       when is_elementary(type),
       do: literal(Declarations.holds?(type, value), {type, lit}, {line, word}, d)

  # A preset is a dint, a number of milliseconds for a timer or a count for a counter, and
  # never negative (docs/naming.md, `ton`): a negative literal lexes since M3-3, and is
  # refused here (decision 97).
  # Since M5-5 it is judged in its instance's type (judged/3), a timer's 0 to 2147483647,
  # where Logex.Declarations.preset?/1 held it until then.
  # Since decision 191 a counter's preset is any value of its `pv`'s type, as IEC's PV is,
  # a signed counter's negatives among them, `ctu offset -10` on a `ctu_int`, an unsigned
  # one's 0 to its top; a timer's is still 0 to 2147483647 ms.
  # Since M5-6 a long timer's is 0 to 2^63-1 ns, the lint's top (decision 158).
  defp check_tag({{:preset, {type, of}}, {:int_lit, line, v} = lit}, at, _scope, diagnostics),
    do: preset_in(type, of, {line, v, lit}, at, diagnostics)

  defp check_tag({{:preset, {type, of}}, {:int_lit, line, v, _} = lit}, at, _scope, diagnostics),
    do: preset_in(type, of, {line, v, lit}, at, diagnostics)

  # M5-10: a real literal is no preset, a number of milliseconds or a count.
  defp check_tag({{:preset, {type, of}}, lit}, at, _scope, diagnostics) when is_real_lit(lit),
    do: preset_in(type, of, {elem(lit, 1), Parser.value(lit), lit}, at, diagnostics)

  # A preset no instance judges, its instance slot a literal or missing, is the
  # mnemonic's own: a dint, in ms for a timer.
  defp check_tag({{:preset, type}, preset}, at, scope, diagnostics)
       when is_atom(type) and is_literal(preset),
       do: check_tag({{:preset, {type, nil}}, preset}, at, scope, diagnostics)

  defp check_tag({_slot, literal}, _at, _scope, diagnostics) when is_literal(literal),
    do: diagnostics

  # Reported by check_preset/4, and never looked up.
  defp check_tag({{:preset, _}, {:name, _, _}}, _at, _scope, diagnostics), do: diagnostics

  # M3-5 (decision 105): a label is a name of its routine's own, never looked up as a tag: a
  # name with no `.`, and no reserved word, of which take_operands/3 leaves a section or type
  # word to reach here.
  defp check_tag({{:label, _}, {:name, line, name}}, {_, word}, _scope, diagnostics),
    do: label_shape(label_word(name), {line, word, name}, diagnostics)

  defp check_tag({slot, {:name, _, name} = operand}, at, scope, diagnostics),
    do: resolve(Declarations.reserved(name), lookup(name, scope), slot, operand, at, diagnostics)

  defp preset_in(type, of, {line, value, literal}, {_, word}, diagnostics) do
    kind = kind_of(symbol_of(word))
    first = preset_first(kind, type)

    preset(
      is_integer(value) and value >= first and Declarations.fits?(type, value),
      {type, literal, first, in_words(kind, type, of)},
      {line, word},
      diagnostics
    )
  end

  defp preset_first(:timer, _type), do: 0
  defp preset_first(:counter, type), do: Declarations.range(type).first

  defp preset(true, _value, _at, diagnostics), do: diagnostics

  defp preset(false, {type, literal, first, words}, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` takes a preset of #{first} to #{Declarations.range(type).last}" <>
          "#{words}, found `#{Parser.spelling(literal)}`"
      )
      | diagnostics
    ]

  # M5-5: a preset of a type other than the dint says the type it is judged in; since M5-6
  # a timer's says its unit, a long timer's its type too, "ns for a ton_ltime".
  defp in_words(:counter, :dint, _of), do: ""
  defp in_words(:counter, type, _of), do: " for a counter of #{Declarations.word(type)}s"
  defp in_words(:timer, _type, of), do: timer_unit(per_ms(of), of)

  defp per_ms(%FbType{} = type), do: FbType.rules(type).per_ms
  defp per_ms(nil), do: 1

  defp timer_unit(1, _of), do: " ms"
  defp timer_unit(_per_ms, %FbType{name: name}), do: " ns for #{Declarations.a_or_an(name)}"

  defp symbol_of(word), do: elem(Map.fetch!(@instructions, String.downcase(word)), 0)

  defp literal(true, _value, _at, diagnostics), do: diagnostics

  defp literal(false, {type, literal}, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` reads #{Declarations.a_type(type)}: " <>
          Declarations.literal_misfit(
            type,
            Parser.value(literal),
            "`#{Parser.spelling(literal)}`"
          )
      )
      | diagnostics
    ]

  defp label_shape(:label, _at, diagnostics), do: diagnostics

  defp label_shape(:dotted, {line, word, name}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a label, a name with no `.`, found `#{name}`")
      | diagnostics
    ]

  defp label_shape(:subscripted, {line, word, name}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a label, a name with no subscript, found `#{name}`")
      | diagnostics
    ]

  defp label_shape(reserved, {line, word, name}, diagnostics),
    do: [
      diagnostic(line, "`#{word}` takes a label, found #{reserved_word(reserved)} `#{name}`")
      | diagnostics
    ]

  # What a name in a label slot is: `:label`, `:dotted`, or the reserved word it is; and in
  # a function block's body, `:header` for a label spelled as the word that heads its file,
  # in any case, which the jumps pass refuses (§4.8).
  defp label_in(name, {:block, _name}),
    do: header_word?(String.downcase(name) in Declarations.kinds(), label_word(name))

  defp label_in(name, :program), do: label_word(name)

  defp header_word?(true, :label), do: :header
  defp header_word?(_heads, word), do: word

  defp label_word(name), do: label_word(String.contains?(name, "."), name)

  defp label_word(true, _name), do: :dotted

  # M5-11: a label is a name, never an element's, `a[0]`, which the lexer reads as one
  # name token.
  defp label_word(false, name), do: label_subscripted(String.contains?(name, "["), name)

  defp label_subscripted(true, _name), do: :subscripted
  defp label_subscripted(false, name), do: label_or(Declarations.reserved(name))

  defp label_or(nil), do: :label
  defp label_or(reserved), do: reserved

  # A name is a tag, or with `.` parts a member of an instance (M1-6), its part looked up
  # among the members its type lets a program name. A dotted name that is not a declared
  # member is a diagnostic, never a reach into another instance (docs/organisation.md
  # §4.7). An internal member, such as a ton's last-scanned time, is not there to find.
  defp lookup(name, scope), do: lookup_parts(String.split(name, "."), scope)

  # M5-11 (decision 151): an element, `temps[3]`, is read and written as a tag of its
  # elements' type and its own name, as written, wherever a tag of that type goes, by its
  # array's section and line: each subscript a literal within its dimension, one for every
  # dimension. Told from a tag by its name's last byte, which the clause's guard reads.
  defp lookup_parts([name], {tags, _members})
       when binary_part(name, byte_size(name) - 1, 1) == "]",
       do: element(Logex.Array.split(name), name, tags)

  defp lookup_parts([name], {tags, _members}), do: Map.fetch(tags, name)

  # Decision 221: a name that goes on past an element, `faults[2].3` or `faults[2].[n]`, is
  # a bit of the element, read and written as a bit of a tag of the element's type is, by
  # every rule a tag's bit has, the element's name as written its container's; an element
  # refused is refused as it is alone.
  defp lookup_parts([head | parts], scope)
       when binary_part(head, byte_size(head) - 1, 1) == "]",
       do: past_element(lookup_parts([head], scope), head, parts, scope)

  defp lookup_parts([head | parts], {tags, _members} = scope),
    do: owned(Map.fetch(tags, head), head, parts, scope)

  defp past_element({:ok, %Tag{}} = element, head, parts, scope),
    do: owned(element, head, parts, scope)

  # M5-12: a bit of an element a tag subscripts, `faults[i].3`, is a bit of the element, its
  # subscripts' tags checked as the element's are.
  defp past_element({:tag_element, element, found}, head, parts, scope),
    do: {:tag_element, owned(element, head, parts, scope), found}

  defp past_element(refused, _head, _parts, _scope), do: refused

  defp element({array, subscripts}, name, tags),
    do:
      element_of(
        Map.fetch(tags, array),
        {array, Enum.map(subscripts, &{&1, Logex.Array.subscript(&1)})},
        {name, tags}
      )

  defp element_of(:error, {array, _subscripts}, _name),
    do: undeclared_array(Declarations.reserved(array), array)

  defp element_of({:ok, %Tag{type: {:array, type, dims}} = tag}, {_array, subscripts}, named),
    do: counted(length(subscripts) == length(dims), {tag, type, dims}, subscripts, named)

  defp element_of({:ok, tag}, _subscripts, _named), do: {:not_an_array, tag}

  defp undeclared_array(nil, array), do: {:undeclared_array, array}
  defp undeclared_array(reserved, array), do: {:reserved, reserved, array}

  defp counted(false, {tag, _type, _dims}, subscripts, _named),
    do: {:dimensions, tag, length(subscripts)}

  # A literal subscript outside its dimension is refused when the program compiles, the
  # first in order; a tag subscript is checked by a scan, where the element is read or
  # written (M5-12), each tag's name gathered in the one pass.
  defp counted(true, {tag, type, dims}, subscripts, named),
    do: in_range(outside(subscripts, dims, 1, []), {tag, type}, named)

  defp outside([], [], _at, texts), do: {:inside, Enum.reverse(texts)}

  defp outside([{_text, {:literal, n}} | rest], [dim | dims], at, texts)
       when n >= 0 and n < dim,
       do: outside(rest, dims, at + 1, texts)

  defp outside([{text, {:literal, _n}} | _rest], [dim | _dims], at, _texts),
    do: {:outside, {text, dim, at}}

  defp outside([{text, {:tag, _name}} | rest], [_dim | dims], at, texts),
    do: outside(rest, dims, at + 1, [text | texts])

  defp in_range({:inside, []}, {%Tag{} = tag, type}, {name, _tags}),
    do: {:ok, %Tag{tag | name: name, type: type}}

  # M5-12 (decision 152): an element some of whose subscripts are tags' names, `weights[slot]`
  # or `grid[1,c]`, is read and written as an element is, each such tag a subscript a scan
  # reads, looked up beside it: an integer tag, of any width.
  defp in_range({:inside, texts}, {%Tag{} = tag, type}, {name, tags}),
    do:
      {:tag_element, {:ok, %Tag{tag | name: name, type: type}},
       for(text <- texts, do: {text, Map.fetch(tags, text)})}

  defp in_range({:outside, at}, {tag, _type}, _named), do: {:subscript_range, tag, at}

  defp owned(:error, head, _parts, _scope), do: unowned(Declarations.reserved(head), head)

  # M5-9 (decision 160): `status.[n]` is the bit of `status` whose number `n` holds, read
  # and written as a bool wherever a bool goes, as `status.3` is: its container is an
  # integer or a bit string, and its number is an integer tag, looked up beside it, whose
  # value a scan reads (a number past the width a major fault then). A bit of a bool or of
  # an instance has none.
  # Decision 213: a literal in the brackets, `status.[4]`, is the very bit `status.4`, its
  # number the literal's value and its name as written.
  defp owned({:ok, %Tag{} = tag}, _head, [<<?[, d, _::binary>> = part], _scope)
       when d in ?0..?9 or d == ?-,
       do: bit_of({literal_number(part), ""}, bits(tag.type), tag, part)

  defp owned({:ok, %Tag{} = tag}, _head, ["[" <> bracketed], {tags, _members}),
    do: tag_bit(bits(tag.type), tag, numbered_by(bracketed), tags)

  defp owned({:ok, %Tag{type: %FbType{name: type}} = tag}, _head, [part | deeper], scope),
    do: in_type(Map.fetch(Map.fetch!(elem(scope, 1), type), part), tag, part, deeper, scope)

  # M5-8 (decision 155): `status.3` is bit 3 of `status`, an integer or a bit string, read
  # and written as a bool tag of its own name wherever a bool goes, by its container's
  # section and line; a number past the width is refused when the program compiles, and a
  # bit of a bool, which is one bit, has none.
  defp owned({:ok, %Tag{type: type} = tag}, _head, [part], _scope),
    do: bit_of(Integer.parse(part), bits(type), tag, part)

  # Past a bit, as past a member, a path goes too deep: `d.3.x`, as `t1.acc.3.x`.
  defp owned({:ok, tag}, _head, [part | _deeper], _scope),
    do: beyond(Integer.parse(part), tag, part)

  # The tag a bit number in brackets names, `n` of `status.[n]`.
  defp numbered_by(bracketed), do: binary_part(bracketed, 0, byte_size(bracketed) - 1)

  # A part's bit number, a literal one in brackets among them (decision 213).
  defp bit_number(<<?[, d, _::binary>> = part) when d in ?0..?9 or d == ?-,
    do: {literal_number(part), ""}

  defp bit_number(part), do: Integer.parse(part)

  # Decision 213: the value of a literal in brackets, `16#4` of `status.[16#4]`, read by the
  # lexer, which took the name only where its brackets hold one number.
  defp literal_number(part) do
    {:ok, [literal], _line} = Logex.Lexer.tokenize(binary_part(part, 1, byte_size(part) - 2))
    elem(literal, 2)
  end

  defp tag_bit(nil, tag, _index, _tags), do: {:no_bits, tag.name, tag.type, tag}

  defp tag_bit(_width, %Tag{} = tag, index, tags),
    do:
      {:tag_bit, {:ok, %Tag{tag | name: "#{tag.name}.[#{index}]", type: :bool}}, index,
       Map.fetch(tags, index)}

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

  defp in_type({:ok, member}, tag, _part, [], _scope), do: {:member, tag, member}

  # M5-9: `t1.acc.[n]`, a member's bit whose number a tag holds, as `t1.acc.3` is a member's
  # bit, logic writing it where it may write the member.
  defp in_type({:ok, member}, tag, _part, ["[" <> <<d, _::binary>> = bracketed], _scope)
       when d in ?0..?9 or d == ?-,
       do:
         past({literal_number(bracketed), ""}, bits(member.type), {tag, member}, "[" <> bracketed)

  defp in_type({:ok, member}, tag, _part, ["[" <> bracketed], {tags, _members}),
    do: member_tag_bit(bits(member.type), {tag, member}, numbered_by(bracketed), tags)

  defp in_type({:ok, member}, tag, _part, [next], _scope),
    do: past(Integer.parse(next), bits(member.type), {tag, member}, next)

  defp in_type({:ok, member}, tag, _part, _deeper, _scope), do: {:too_deep, tag, member}
  defp in_type(:error, tag, part, _deeper, _scope), do: {:unknown_member, tag, part}

  defp member_tag_bit(nil, {tag, member}, _index, _tags), do: {:member_bit, tag, member}

  defp member_tag_bit(_width, {tag, %Member{} = member}, index, tags),
    do:
      {:tag_bit, {:member, tag, %Member{member | name: "#{member.name}.[#{index}]", type: :bool}},
       index, Map.fetch(tags, index)}

  # `t1.acc.3` is bit access of a member, as `d.3` is of a tag, since M5-8 a bool member of
  # that name, logic writing it where it may write the member; `t1.acc.3.x` goes too deep.
  defp past({n, ""}, width, {tag, member}, part) when is_integer(width),
    do: member_in_width(n >= 0 and n < width, {tag, member}, {n, width}, part)

  defp past({_bit, ""}, nil, {tag, member}, _part), do: {:member_bit, tag, member}
  defp past(_not_a_bit, _width, {tag, member}, _part), do: {:too_deep, tag, member}

  defp member_in_width(true, {tag, %Member{} = member}, _n, part),
    do: {:member, tag, %Member{member | name: "#{member.name}.#{part}", type: :bool}}

  defp member_in_width(false, {tag, member}, {n, width}, _part),
    do: {:past_width, "#{tag.name}.#{member.name}", member.type, {n, width, nil}}

  defp bit_of({n, ""}, width, tag, part) when is_integer(width),
    do: in_width(n >= 0 and n < width, tag, {n, width}, part)

  defp bit_of(_no_bit, _width, tag, part), do: {:no_members, tag, part}

  defp in_width(true, %Tag{} = tag, _n, part),
    do: {:ok, %Tag{tag | name: "#{tag.name}.#{part}", type: :bool}}

  defp in_width(false, tag, {n, width}, _part),
    do: {:past_width, tag.name, tag.type, {n, width, tag}}

  # The width of a type whose bits a program may name, an integer's or a bit string's, or
  # nil: a bool is one bit, and an instance has members.
  defp bits(type) when is_elementary(type), do: of_bits(Declarations.kind(type), type)
  defp bits(_type), do: nil

  defp of_bits(:boolean, _type), do: nil
  # M5-10 (decision 155): a real has no bits a program may name.
  defp of_bits(:real, _type), do: nil
  defp of_bits(_integer_or_bits, type), do: Declarations.width(type)

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

  # M5-11 (decision 151): an array is read and written by element, never whole: whole-array
  # copy and fill are deferred (§4.12, "Deferred").
  defp resolve(
         nil,
         {:ok, %Tag{type: type} = tag},
         {access, _slot_type},
         {:name, line, _},
         {_, word},
         d
       )
       when is_array(type),
       do: [
         diagnostic(
           line,
           "`#{word}` #{verb(access)} one tag, but `#{tag.name}` is #{a_type(type)}" <>
             "#{declared(tag)}: an instruction takes one of its elements, as in " <>
             "`#{tag.name}[#{Enum.map_join(elem(type, 2), ",", fn _ -> 0 end)}]`"
         )
         | d
       ]

  defp resolve(nil, {:undeclared_array, array}, _slot, {:name, line, _name}, _at, diagnostics),
    do: [{:undeclared, line, array, :element} | diagnostics]

  defp resolve(nil, {:not_an_array, tag}, _slot, {:name, line, name}, _at, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{name}` names an element of `#{tag.name}`, but `#{tag.name}` is " <>
          "#{named_type(tag.type)}#{declared(tag)}, no array"
      )
      | diagnostics
    ]

  defp resolve(nil, {:dimensions, tag, count}, _slot, {:name, line, name}, _at, diagnostics) do
    dims = elem(tag.type, 2)

    [
      diagnostic(
        line,
        "`#{name}` names an element of `#{tag.name}`, #{a_type(tag.type)}#{declared(tag)}, " <>
          "by #{count} #{subscripts(count)}, where it takes #{length(dims)}, one a " <>
          "dimension, as in `#{tag.name}[#{Enum.map_join(dims, ",", fn _ -> 0 end)}]`"
      )
      | diagnostics
    ]
  end

  defp resolve(nil, {:subscript_range, tag, {text, dim, at}}, _slot, {:name, line, name}, _at, d),
    do: [
      diagnostic(
        line,
        "`#{name}`'s subscript `#{text}` is outside #{dimension(length(elem(tag.type, 2)), at)} " <>
          "of `#{tag.name}`, 0 to #{dim - 1}: `#{tag.name}` is #{a_type(tag.type)}#{declared(tag)}"
      )
      | d
    ]

  # M5-12 (decision 152): an element a tag subscripts is checked as the element it reads and
  # writes, and each subscript's tag as an integer that a scan reads.
  defp resolve(nil, {:tag_element, element, found}, slot, {:name, line, name} = operand, at, d),
    do: resolve(nil, element, slot, operand, at, subscripted_by(found, {line, name}, d))

  # An instance is named whole only where an instruction runs it; anywhere else, by one of
  # its members, which the message suggests when one would fit the slot.
  defp resolve(nil, {:ok, %Tag{type: %FbType{name: type}}}, {:instance, type}, _, _, diagnostics),
    do: diagnostics

  # M3-1: a slot of several types, a counter's, each the kind of instance it takes: since
  # M5-5 a typed counter is of its kind's, `ctu_int` a `ctu`'s (Logex.FbType.family/1).
  defp resolve(
         nil,
         {:ok, %Tag{type: %FbType{} = fb} = tag},
         {:instance, [_ | _] = types} = slot,
         operand,
         at,
         diagnostics
       ),
       do: of_kind(FbType.family(fb) in types, {tag, fb}, slot, {operand, at}, diagnostics)

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
    do: [diagnostic(line, no_members(bit_number(part), name, tag)) | diagnostics]

  # M5-9 (decision 160): a bit whose number a tag holds is checked as the bool it reads and
  # writes, and its number's tag as an integer that a scan reads.
  defp resolve(nil, {:tag_bit, bit, index, found}, slot, {:name, line, name} = operand, at, d),
    do: resolve(nil, bit, slot, operand, at, numbered(found, index, {line, name}, d))

  defp resolve(nil, {:no_bits, word, type, tag}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, no_bits(name, word, type, tag)) | diagnostics]

  defp resolve(
         nil,
         {:past_width, word, type, {n, width, tag}},
         _slot,
         {:name, line, name},
         _at,
         d
       ),
       do: [
         diagnostic(
           line,
           "`#{name}` names bit #{n} of `#{word}`, #{a_type(type)}#{declared_of(tag)}, " <>
             "which has bits 0 to #{width - 1}"
         )
         | d
       ]

  defp resolve(nil, {:past_bit, tag}, _slot, {:name, line, name}, _at, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{name}` goes too deep: `#{tag.name}` is #{a_type(tag.type)}, which has no members"
      )
      | diagnostics
    ]

  defp resolve(nil, {:member_bit, tag, member}, _slot, {:name, line, name}, _at, diagnostics),
    do: [diagnostic(line, bit(name, "#{tag.name}.#{member.name}", member.type)) | diagnostics]

  defp resolve(nil, {:too_deep, tag, member}, _slot, {:name, line, name}, _at, diagnostics) do
    message =
      "`#{name}` goes too deep: `#{tag.name}.#{member.name}` is #{a_type(member.type)}, " <>
        "which has no members"

    [diagnostic(line, message) | diagnostics]
  end

  defp named_type(%FbType{} = type), do: Declarations.instance_of(type)
  defp named_type(type), do: a_type(type)

  defp subscripts(1), do: "subscript"
  defp subscripts(_count), do: "subscripts"

  defp dimension(1, _at), do: "the elements"
  defp dimension(_dims, 1), do: "the first dimension"
  defp dimension(_dims, 2), do: "the second dimension"
  defp dimension(_dims, 3), do: "the third dimension"

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
             "#{Declarations.instance_of(type)}#{declared(tag)}" <>
             both_ways("ctud" in types, type, tag)
         )
         | diagnostics
       ]

  # Decision 192: a slot that runs several kinds, a counter's, names every type word it
  # runs wherever a message names the slot, in a fixed order: the plain words first, then
  # each width in the type table's order, each width's kinds in the slot's order, `ctu`'s
  # "a ctu, ctud, ctu_int, ctud_int, …"; an alias, which names a plain word's very type, is
  # left out. Since M5-6 a timer's slot, of one kind, `["ton"]`, names its kind's two types
  # so, the plain timer's word first and then the long timer's, of a lint: "a ton or
  # ton_ltime".
  defp run_words(kinds) do
    words =
      for {word, type} <- FbType.builtins(),
          type.name == word,
          FbType.family(type) in kinds,
          do: {run_order(FbType.rules(type).counts, FbType.family(type), kinds), word}

    [first | rest] = for {_order, word} <- Enum.sort(words), do: word
    listed_or([Declarations.a_or_an(first) | rest])
  end

  @counts Enum.with_index(Declarations.integers())

  defp run_order(:dint, family, kinds), do: {0, 0, Enum.find_index(kinds, &(&1 == family))}

  defp run_order(counts, family, kinds),
    do: {1, Keyword.fetch!(@counts, counts), Enum.find_index(kinds, &(&1 == family))}

  defp listed_or([one]), do: one

  defp listed_or(words),
    do: Enum.join(Enum.drop(words, -1), ", ") <> " or " <> List.last(words)

  # A counter of the other kind is one declaration from one that counts both ways, of its
  # own type since M5-5: a `ctd_int` from a `ctud_int`. Since M5-6 a timer's slot runs a
  # list too, and a counter given to it is told no such thing.
  defp both_ways(true, %FbType{name: name, body: nil} = type, tag),
    do: one_way(FbType.family(type), name, tag)

  defp both_ways(_counter_slot, _type, _tag), do: ""

  defp one_way(kind, name, tag) when kind in ["ctu", "ctd"],
    do:
      ": #{Declarations.a_or_an(name)} only counts #{way(kind)}; declare it " <>
        "`var #{tag.name} #{String.replace_prefix(name, kind, "ctud")}` to count both ways"

  defp one_way(_kind, _name, _tag), do: ""

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

  # `word.3` is PLAN.md §5's bit access, landed with M5-8: here a bit of a bool.
  defp no_members({_bit, ""}, name, tag), do: bit(name, tag.name, tag.type)

  defp no_members(_not_a_bit, name, tag),
    do:
      "`#{name}` names a member of `#{tag.name}`, but `#{tag.name}` is #{a_type(tag.type)}" <>
        "#{declared(tag)}: only an instance of a function block has members"

  # Bit access reaches a bit of an integer or a bit string (M5-8); a bool is one bit, and
  # has none.
  defp bit(name, word, type),
    do: "`#{name}` names a bit of `#{word}`, #{a_type(type)}, which has no bits"

  defp no_bits(name, word, %FbType{} = type, tag),
    do:
      "`#{name}` names a bit of `#{word}`, but `#{word}` is " <>
        "#{Declarations.instance_of(type)}#{declared(tag)}: only an integer or a bit string " <>
        "has bits"

  defp no_bits(name, word, type, _tag), do: bit(name, word, type)

  # M5-9 (decision 160): the tag a bit number is held in is declared, and of an integer
  # type, any width, which a scan reads as the bit's number; never an expression, which the
  # lexer has no form for.
  defp numbered({:ok, %Tag{type: type} = tag}, _index, at, diagnostics)
       when is_elementary(type),
       do: numbered_class(Declarations.in_class?(type, :any_int), tag, at, diagnostics)

  defp numbered({:ok, %Tag{} = tag}, _index, {line, name}, diagnostics),
    do: [diagnostic(line, not_a_number(name, tag)) | diagnostics]

  defp numbered(:error, index, {line, name}, diagnostics),
    do: unnumbered(Declarations.reserved(index), index, {line, name}, diagnostics)

  defp numbered_class(true, _tag, _at, diagnostics), do: diagnostics

  defp numbered_class(false, tag, {line, name}, diagnostics),
    do: [diagnostic(line, not_a_number(name, tag)) | diagnostics]

  defp unnumbered(nil, index, {line, _name}, diagnostics),
    do: [{:undeclared, line, index, :bit_number} | diagnostics]

  defp unnumbered(reserved, index, {line, name}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{name}` takes its bit number from `#{index}`, #{reserved_as(reserved)}, which " <>
          "cannot name a tag"
      )
      | diagnostics
    ]

  # M5-12 (decision 152): each subscript a tag holds, declared and of an integer type, of
  # any width; a bit string's value is a number once converted, as a bit number's is.
  defp subscripted_by(found, at, diagnostics),
    do: Enum.reduce(found, diagnostics, &subscript_by(&1, at, &2))

  defp subscript_by({_text, {:ok, %Tag{type: type} = tag}}, at, diagnostics)
       when is_elementary(type),
       do: subscript_class(Declarations.in_class?(type, :any_int), tag, at, diagnostics)

  defp subscript_by({_text, {:ok, %Tag{} = tag}}, {line, name}, diagnostics),
    do: [diagnostic(line, not_a_subscript(name, tag)) | diagnostics]

  defp subscript_by({text, :error}, at, diagnostics),
    do: unsubscripted(Declarations.reserved(text), text, at, diagnostics)

  defp subscript_class(true, _tag, _at, diagnostics), do: diagnostics

  defp subscript_class(false, tag, {line, name}, diagnostics),
    do: [diagnostic(line, not_a_subscript(name, tag)) | diagnostics]

  defp unsubscripted(nil, text, {line, _name}, diagnostics),
    do: [{:undeclared, line, text, :subscript} | diagnostics]

  defp unsubscripted(reserved, text, {line, name}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{name}` takes a subscript from `#{text}`, #{reserved_as(reserved)}, which cannot " <>
          "name a tag"
      )
      | diagnostics
    ]

  defp not_a_subscript(name, %Tag{type: %FbType{} = type} = tag),
    do:
      "`#{name}` takes a subscript from `#{tag.name}`, but `#{tag.name}` is " <>
        "#{Declarations.instance_of(type)}#{declared(tag)}: a subscript is a literal or a tag " <>
        "of an integer type"

  defp not_a_subscript(name, %Tag{type: type} = tag) when is_array(type),
    do:
      "`#{name}` takes a subscript from `#{tag.name}`, #{a_type(type)}#{declared(tag)}, " <>
        "which is no integer: a subscript is a literal or a tag of an integer type, never an " <>
        "array or one of its elements"

  defp not_a_subscript(name, %Tag{type: type} = tag),
    do:
      "`#{name}` takes a subscript from `#{tag.name}`, #{a_type(type)}#{declared(tag)}, " <>
        "which is no integer: a subscript is a literal or a tag of an integer type" <>
        number_conversion(Declarations.kind(type), type)

  defp not_a_number(name, %Tag{type: %FbType{} = type} = tag),
    do:
      "`#{name}` takes its bit number from `#{tag.name}`, but `#{tag.name}` is " <>
        "#{Declarations.instance_of(type)}#{declared(tag)}: a bit number is held in a tag " <>
        "of an integer type"

  defp not_a_number(name, %Tag{type: type} = tag),
    do:
      "`#{name}` takes its bit number from `#{tag.name}`, #{a_type(type)}#{declared(tag)}, " <>
        "which is no integer: a bit number is held in a tag of an integer type" <>
        number_conversion(Declarations.kind(type), type)

  # A bit string's value is a number once converted, by its own width's unsigned integer.
  defp number_conversion(:bit_string, type),
    do:
      ", so convert it first, with `#{Declarations.conversion(type, Declarations.unsigned_of(type))}`"

  defp number_conversion(_kind, _type), do: ""

  # The member to suggest for an instance named whole: one of the slot's type that the slot
  # may use, a value the block sets for a read, one logic may write for a write.
  defp fitting(:write, slot_type, type), do: of_type(FbType.writable(type), slot_type)

  defp fitting(_access, slot_type, type),
    do: of_type(Enum.filter(FbType.public(type), &(&1.role == :output)), slot_type)

  defp of_type(members, :any), do: List.first(members)

  defp of_type(members, class) when is_class(class),
    do: Enum.find(members, &(is_elementary(&1.type) and Declarations.in_class?(&1.type, class)))

  defp of_type(members, slot_type), do: Enum.find(members, &(&1.type == slot_type))

  defp example(nil, _tag), do: ""
  defp example(member, tag), do: ": name one of its members, as in `#{tag.name}.#{member.name}`"

  defp a_type(:any), do: "a value"
  defp a_type(class) when is_class(class), do: Declarations.a_class(class)
  defp a_type([_ | _] = kinds), do: run_words(kinds)
  defp a_type(type) when is_array(type), do: Declarations.a_type(type)
  defp a_type(type), do: Declarations.a_or_an(to_string(type))

  defp check_member_type(diagnostics, {_access, :any}, _name, _member, _at), do: diagnostics

  # M5-4: a slot of a generic type takes a member of any of its types, which classed/3 then
  # holds to the instruction's other operands.
  defp check_member_type(diagnostics, {access, class}, name, member, at) when is_class(class),
    do:
      member_widened(
        of_class?(member.type, class),
        diagnostics,
        {access, class},
        {name, member},
        at
      )

  defp check_member_type(diagnostics, {_access, type}, _name, %Member{type: type}, _at),
    do: diagnostics

  defp check_member_type(diagnostics, {access, type}, name, member, {_line, word} = at),
    do:
      member_widened(
        widened?(Map.get(@conversions, String.downcase(word)), access, member.type, type),
        diagnostics,
        {access, type},
        {name, member},
        at
      )

  defp member_widened(true, diagnostics, _slot, _member, _at), do: diagnostics

  defp member_widened(false, diagnostics, {access, type}, {name, member}, {line, word}),
    do: [
      diagnostic(
        line,
        "`#{word}` #{verb(access)} #{a_type(type)}, but `#{name}` is #{a_type(member.type)}" <>
          converted(word, access, member.type, type)
      )
      | diagnostics
    ]

  defp of_class?(type, class) when is_elementary(type), do: Declarations.in_class?(type, class)
  defp of_class?(_type, _class), do: false

  # Decision 176: a conversion's source widens as an input of IEC's typed functions does,
  # `ADD_REAL` taking an INT (Ed 3 Table 21, Example 2): `dint_to_int` takes an sint, an
  # int or a usint, any type Figure 11 widens into a dint, as it takes a dint; its
  # destination stays exact, and every other fixed slot takes its own type.
  defp widened?({_symbol, _signature}, :value, found, type) when is_elementary(found),
    do: Declarations.widens?(found, type)

  defp widened?(_not_a_conversion, _access, _found, _type), do: false

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

  defp check_type(diagnostics, access, class, tag, at) when is_class(class),
    do: tag_widened(of_class?(tag.type, class), diagnostics, {access, class}, tag, at)

  defp check_type(diagnostics, _access, type, %Tag{type: type}, _at), do: diagnostics

  defp check_type(diagnostics, access, type, tag, {_line, word} = at),
    do:
      tag_widened(
        widened?(Map.get(@conversions, String.downcase(word)), access, tag.type, type),
        diagnostics,
        {access, type},
        tag,
        at
      )

  defp tag_widened(true, diagnostics, _slot, _tag, _at), do: diagnostics

  defp tag_widened(false, diagnostics, {access, type}, tag, {line, word}) do
    message =
      "`#{word}` #{verb(access)} #{a_type(type)}, but `#{tag.name}` is " <>
        "#{a_type(tag.type)}#{declared(tag)}" <> converted(word, access, tag.type, type)

    [diagnostic(line, message) | diagnostics]
  end

  # M5-3 (decision 148): a conversion's own slot is told the conversion that does the whole
  # job, from the type found or into it, or `move` where the two are one type. Since M5-4
  # every other slot that takes an integer takes a generic type, which classed/3 holds to
  # the instruction's other operands, so a fixed slot given another type, a bool's given an
  # integer, has no conversion to name.
  # M5-8 (decision 155): a bit string where a class that holds none is wanted, `add`'s
  # number, is told the conversion through its own width's unsigned integer, the integer
  # IEC compares it as, `word_to_uint` before a read and `uint_to_word` after a write
  # (provisional); any other type outside the class, a bool, has none to name.
  defp converted(_word, access, found, class) when is_class(class) and is_elementary(found),
    do: classless(Declarations.kind(found), access, found, class)

  defp converted(_word, _access, _found, class) when is_class(class), do: ""

  defp converted(word, access, found, type),
    do: converting(Map.get(@conversions, String.downcase(word)), access, found, type)

  defp classless(_kind, :write, _found, :any_real),
    do: ": a square root is a real's, so declare it a real or an lreal"

  defp classless(:bit_string, :write, found, class),
    do:
      ": #{a_type(found)} is a bit string, not #{a_type(class)}: compute in an integer and " <>
        "convert the result, with `#{Declarations.conversion(Declarations.unsigned_of(found), found)}`"

  defp classless(:bit_string, _read, found, class),
    do:
      ": #{a_type(found)} is a bit string, not #{a_type(class)}: convert it first, with " <>
        "`#{Declarations.conversion(found, Declarations.unsigned_of(found))}`"

  defp classless(_kind, _access, _found, _class), do: ""

  defp converting({_symbol, [{:value, from}, {:write, to}]}, access, found, _type),
    do: instead(conversion_of(access, found, {from, to}))

  defp converting(nil, _access, _found, _type), do: ""

  defp conversion_of(:write, found, {from, _to}),
    do: {Declarations.conversion(from, found), found, from}

  defp conversion_of(_read, found, {_from, to}),
    do: {Declarations.conversion(found, to), found, to}

  defp instead({nil, same, same}), do: ": use `move`"
  defp instead({nil, _found, _type}), do: ""
  defp instead({conversion, _found, _type}), do: ": use `#{conversion}`"

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

  defp declared_of(nil), do: ""
  defp declared_of(tag), do: declared(tag)

  # A literal by its value, which every rule judges, and as written, which every message
  # quotes (decision 202).
  defp typed(_access, {:int_lit, _, value} = literal, _scope), do: {:literal, value, literal}
  defp typed(_access, {:int_lit, _, value, _} = literal, _scope), do: {:literal, value, literal}
  # M5-10: a real literal so, by its float.
  defp typed(_access, {:real_lit, _, value} = literal, _scope), do: {:literal, value, literal}
  defp typed(_access, {:real_lit, _, value, _} = literal, _scope), do: {:literal, value, literal}

  defp typed(access, {:name, _, name}, scope), do: typed_ref(access, lookup(name, scope))

  # A member stands in as a tag of its type. An instance named whole, and a member written
  # that logic may not write, were reported by resolve/6 and are not looked at again.
  defp typed_ref(access, {:tag_bit, bit, _index, _found}), do: typed_ref(access, bit)
  defp typed_ref(access, {:tag_element, element, _found}), do: typed_ref(access, element)
  defp typed_ref(_access, {:ok, %Tag{type: %FbType{}}}), do: nil
  # M5-11: an array named whole, reported by resolve/6.
  defp typed_ref(_access, {:ok, %Tag{type: type}}) when is_array(type), do: nil
  defp typed_ref(_access, {:ok, %Tag{} = tag}), do: tag
  defp typed_ref(:write, {:member, _tag, %Member{write: false}}), do: nil

  defp typed_ref(_access, {:member, tag, member}),
    do: %Tag{name: "#{tag.name}.#{member.name}", type: member.type, section: :var}

  defp typed_ref(_access, _unresolved), do: nil

  # The `:any` operands of one instruction, `move`'s source and then its destination: the
  # instruction computes in its destination's type, so the source must be of a type Ed 3
  # Figure 11 widens into it (M5-3, decision 147), and a literal must fit the tag it goes
  # into. Anything else was reported already, or is not a tag.
  defp unify([%Tag{type: from} = source, %Tag{type: to} = destination], at, diagnostics)
       when is_elementary(from) and is_elementary(to),
       do: widens(Declarations.widens?(from, to), source, destination, at, diagnostics)

  defp unify([{:literal, value, literal}, %Tag{type: type} = tag], at, diagnostics),
    do: fits(Declarations.holds?(type, value), literal, tag, at, diagnostics)

  defp unify(_typed, _at, diagnostics), do: diagnostics

  defp widens(true, _source, _destination, _at, diagnostics), do: diagnostics

  defp widens(false, source, destination, {line, word}, diagnostics) do
    message =
      "`#{word}` writes `#{source.name}`, #{a_type(source.type)}, into `#{destination.name}`, " <>
        "#{a_type(destination.type)}: #{a_type(source.type)} does not widen into " <>
        "#{a_type(destination.type)}" <>
        conversion_of(Declarations.conversion(source.type, destination.type))

    [diagnostic(line, message) | diagnostics]
  end

  defp conversion_of(nil), do: ", and logex has no conversion between them"
  defp conversion_of(conversion), do: ", so convert it with `#{conversion}`"

  # M5-4 (decisions 145, 146 and 147): the operands of an instruction whose slots take a
  # generic type, ANY_NUM or ANY_INT, held together, so that a three-operand `add` is
  # checked whole. Where it writes a destination of the class, it computes in that type,
  # as IEC's typed `ADD_<type>`: each source tag must be of a type Ed 3 Figure 11 widens
  # into it, told the conversion that bridges them where it is not, and a literal must fit
  # it. A comparison writes nothing: two integers compare by value whatever their types, so
  # a tag needs nothing of the other operand; a literal beside a tag must fit the tag's
  # type (decision 183), and one beside a literal some integer type, the class's whole
  # range, as must one whose destination is not of the class or is not resolved, reported
  # already. `neg` into an unsigned destination is refused (decision
  # 145): such a type holds no negative value, so its only results would be 0 and a wrap.
  # Since M5-8 the operands of each class are held together apart from the others', in
  # the order their classes first come, so a shift's count, ANY_INT, is no source of the
  # type its bit string computes in.
  # Every instruction but a shift holds one class, held with no grouping, so that it
  # checks in what it did before M5-8.
  defp classed([], _at, diagnostics), do: diagnostics

  # M5-10: `sqrt` writes a real, IEC's ANY_REAL, its slot told so by check_type/5, and
  # reads any number, which computes in its destination's real as `add`'s sources do; a
  # destination of no real type has been reported, and its source is held to the class
  # alone.
  defp classed(
         [{:value, :any_num, _} = source, {:write, :any_real, %Tag{type: type} = tag}],
         at,
         diagnostics
       )
       when type in @reals,
       do: class_held(:any_num, [source, {:write, :any_num, tag}], at, diagnostics)

  defp classed([{:value, :any_num, _} = source, {:write, :any_real, _}], at, diagnostics),
    do: class_held(:any_num, [source], at, diagnostics)

  defp classed([{_access, class, _typed} | _] = operands, at, diagnostics),
    do: of_classes(one_class?(operands, class), class, operands, {at, diagnostics})

  defp one_class?([{_access, class, _typed} | rest], class), do: one_class?(rest, class)
  defp one_class?([], _class), do: true
  defp one_class?(_other, _class), do: false

  defp of_classes(true, class, operands, {at, diagnostics}),
    do: class_held(class, operands, at, diagnostics)

  defp of_classes(false, _class, operands, {at, diagnostics}) do
    classes = operands |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    Enum.reduce(classes, diagnostics, fn class, diagnostics ->
      class_held(class, Enum.filter(operands, &(elem(&1, 1) == class)), at, diagnostics)
    end)
  end

  defp class_held(class, operands, at, diagnostics) do
    {writes, reads} = Enum.split_with(operands, &match?({:write, _class, _typed}, &1))
    compared(writes, reads, class, at, diagnostics)
  end

  # Decision 183: a comparison, which writes nothing, holds a literal to the type of the
  # tag it is compared with, as IEC's typed `LT_SINT` types its literal: `lt s 200` with an
  # sint `s` can never be false, and is refused. Two literals, or a literal and a tag not
  # resolved, are held to every integer type's values, as M5-4 has it.
  defp compared(
         [],
         [{:value, _, {:literal, _, _} = lit}, {:value, _, %Tag{} = tag}],
         class,
         at,
         d
       ),
       do: against(lit, tag, class, at, d)

  defp compared(
         [],
         [{:value, _, %Tag{} = tag}, {:value, _, {:literal, _, _} = lit}],
         class,
         at,
         d
       ),
       do: against(lit, tag, class, at, d)

  # M5-8 (decision 147's note, §4.12's ninth question): a bit string compares with a bit
  # string, and with an integer tag only through a conversion, the refusal naming both ways,
  # into the bit string's type and out of it, `int_to_word` and `word_to_int`.
  defp compared(
         [],
         [{:value, _, %Tag{type: a} = one}, {:value, _, %Tag{type: b} = other}],
         _class,
         at,
         d
       )
       when is_elementary(a) and is_elementary(b),
       do:
         kinds_met(compared_kinds(Declarations.kind(a), Declarations.kind(b)), one, other, at, d)

  defp compared(writes, reads, class, {_line, word} = at, diagnostics) do
    {diagnostics, computed} =
      negated(symbol_of(word), computed_in(writes, class), reads, at, diagnostics)

    Enum.reduce(reads, diagnostics, &source(&1, computed, at, &2))
  end

  defp compared_kinds(:bit_string, kind) when kind in [:signed, :unsigned], do: :mixed
  defp compared_kinds(kind, :bit_string) when kind in [:signed, :unsigned], do: :mixed
  # M5-10 (decision 147): an integer compares with a real only where Figure 11 widens it
  # into the real's type, and a real with a bit string never, logex having no conversion
  # between them (§4.12, "Conversions").
  defp compared_kinds(:real, kind) when kind in [:signed, :unsigned], do: :real_first
  defp compared_kinds(kind, :real) when kind in [:signed, :unsigned], do: :real_second
  defp compared_kinds(:real, :bit_string), do: :unconverted
  defp compared_kinds(:bit_string, :real), do: :unconverted
  defp compared_kinds(_one, _other), do: :met

  defp kinds_met(:met, _one, _other, _at, diagnostics), do: diagnostics

  defp kinds_met(:real_first, real, integer, at, diagnostics),
    do: real_met(Declarations.widens?(integer.type, real.type), {real, integer}, at, diagnostics)

  defp kinds_met(:real_second, integer, real, at, diagnostics),
    do: real_met(Declarations.widens?(integer.type, real.type), {real, integer}, at, diagnostics)

  defp kinds_met(:unconverted, one, other, {line, word}, diagnostics) do
    message =
      "`#{word}` compares `#{one.name}`, #{a_type(one.type)}#{declared(one)}, with " <>
        "`#{other.name}`, #{a_type(other.type)}#{declared(other)}: a real compares only with " <>
        "a number, and logex has no conversion between a real and a bit string"

    [diagnostic(line, message) | diagnostics]
  end

  defp kinds_met(:mixed, one, other, {line, word}, diagnostics) do
    {bits, integer} = bits_first(Declarations.kind(one.type), one, other)

    message =
      "`#{word}` compares `#{one.name}`, #{a_type(one.type)}#{declared(one)}, with " <>
        "`#{other.name}`, #{a_type(other.type)}#{declared(other)}: a bit string compares " <>
        "only with a bit string, so convert one of them first, with " <>
        "`#{Declarations.conversion(integer.type, bits.type)}` or " <>
        "`#{Declarations.conversion(bits.type, integer.type)}`"

    [diagnostic(line, message) | diagnostics]
  end

  defp real_met(true, _compared, _at, diagnostics), do: diagnostics

  defp real_met(false, {real, integer}, {line, word}, diagnostics) do
    message =
      "`#{word}` compares `#{real.name}`, #{a_type(real.type)}#{declared(real)}, with " <>
        "`#{integer.name}`, #{a_type(integer.type)}#{declared(integer)}: " <>
        "#{a_type(integer.type)} does not widen into #{a_type(real.type)}, so convert it " <>
        "first, with `#{Declarations.conversion(integer.type, real.type)}`"

    [diagnostic(line, message) | diagnostics]
  end

  defp bits_first(:bit_string, bits, integer), do: {bits, integer}
  defp bits_first(_integer, integer, bits), do: {bits, integer}

  defp against(literal, %Tag{type: type} = tag, class, at, diagnostics)
       when is_elementary(type),
       do: held(Declarations.in_class?(type, class), literal, tag, class, at, diagnostics)

  defp against(literal, _tag, class, at, diagnostics),
    do: source({:value, class, literal}, {:class, class}, at, diagnostics)

  # A tag outside the class, a bool, was reported by its slot; its literal is held to the
  # class alone.
  defp held(true, {:literal, value, _} = literal, %Tag{type: type} = tag, _class, at, d),
    do: holds(Declarations.holds?(type, value), literal, tag, at, d)

  defp held(false, literal, _tag, class, at, diagnostics),
    do: source({:value, class, literal}, {:class, class}, at, diagnostics)

  defp holds(true, _literal, _tag, _at, diagnostics), do: diagnostics

  defp holds(false, {:literal, _, literal}, %Tag{type: type} = tag, {line, word}, diagnostics) do
    shown = Parser.spelling(literal)

    message =
      "`#{word}` compares `#{shown}` with `#{tag.name}`, #{a_type(type)}#{declared(tag)}, " <>
        "which never holds it: " <>
        Declarations.literal_misfit(type, Parser.value(literal), "`#{shown}`")

    [diagnostic(line, message) | diagnostics]
  end

  defp computed_in([{:write, class, %Tag{type: type} = tag}], class) when is_elementary(type),
    do: of_class(Declarations.in_class?(type, class), tag, class)

  defp computed_in(_none_or_unresolved, class), do: {:class, class}

  defp of_class(true, tag, _class), do: tag
  defp of_class(false, _tag, class), do: {:class, class}

  defp source(
         {:value, class, %Tag{type: from} = tag},
         %Tag{type: to} = destination,
         at,
         diagnostics
       )
       when is_elementary(from),
       do:
         computes(
           Declarations.in_class?(from, class) and not Declarations.widens?(from, to),
           tag,
           destination,
           at,
           diagnostics
         )

  defp source(
         {:value, _class, {:literal, value, literal}},
         %Tag{type: type} = destination,
         at,
         diagnostics
       ),
       do: literal_in(Declarations.holds?(type, value), literal, destination, at, diagnostics)

  defp source({:value, _class, {:literal, value, literal}}, {:class, class}, at, diagnostics)
       when is_integer(value),
       do:
         class_literal(value in Declarations.class_range(class), literal, class, at, diagnostics)

  # M5-10: a real literal where no type is known for it, a comparison's beside a literal,
  # held to the class, which takes it where it holds a real.
  defp source({:value, _class, {:literal, value, literal}}, {:class, class}, at, diagnostics),
    do: class_literal(Declarations.class_holds?(class, value), literal, class, at, diagnostics)

  defp source(_operand, _computed, _at, diagnostics), do: diagnostics

  defp computes(false, _source, _destination, _at, diagnostics), do: diagnostics

  defp computes(true, source, destination, {line, word}, diagnostics) do
    message =
      "`#{word}` computes in `#{destination.name}`'s type, #{a_type(destination.type)}, " <>
        "but `#{source.name}` is #{a_type(source.type)}#{declared(source)}: " <>
        "#{a_type(source.type)} does not widen into #{a_type(destination.type)}" <>
        first_with(Declarations.conversion(source.type, destination.type))

    [diagnostic(line, message) | diagnostics]
  end

  # Decision 206: a bool and an integer, or a bit string into a bool, have no conversion
  # between them, as `move`'s refusal says.
  defp first_with(nil), do: ", and logex has no conversion between them"
  defp first_with(conversion), do: ", so convert it first, with `#{conversion}`"

  defp literal_in(true, _literal, _destination, _at, diagnostics), do: diagnostics

  defp literal_in(false, literal, destination, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` computes in `#{destination.name}`'s type, " <>
          "#{a_type(destination.type)}: " <>
          Declarations.literal_misfit(
            destination.type,
            Parser.value(literal),
            "`#{Parser.spelling(literal)}`"
          )
      )
      | diagnostics
    ]

  defp class_literal(true, _literal, _class, _at, diagnostics), do: diagnostics

  # M5-10: a real literal where the class holds no real, `mod`'s ANY_INT.
  defp class_literal(false, {:real_lit, _, _} = literal, class, at, diagnostics),
    do: real_literal(literal, class, at, diagnostics)

  defp class_literal(false, {:real_lit, _, _, _} = literal, class, at, diagnostics),
    do: real_literal(literal, class, at, diagnostics)

  defp class_literal(false, literal, class, {line, word}, diagnostics) do
    first..last//1 = Declarations.class_range(class)

    message =
      "`#{word}` reads #{a_type(class)}: `#{Parser.spelling(literal)}` is outside #{first} " <>
        "to #{last}, " <>
        "every integer type's values"

    [diagnostic(line, message) | diagnostics]
  end

  defp real_literal(literal, class, {line, word}, diagnostics),
    do: [
      diagnostic(
        line,
        "`#{word}` reads #{a_type(class)}: `#{Parser.spelling(literal)}` is a real, which " <>
          "#{a_type(class)} never is"
      )
      | diagnostics
    ]

  # A `neg` refused for its unsigned destination is told that, and since decision 181 the
  # narrowest signed type its source widens into, or a literal source fits, to declare the
  # destination; its sources are then held to the class only, since no conversion into
  # that destination would make it compile.
  defp negated(:neg, %Tag{type: type} = destination, reads, at, diagnostics),
    do: unsigned(Declarations.kind(type), destination, reads, at, diagnostics)

  defp negated(_symbol, computed, _reads, _at, diagnostics), do: {diagnostics, computed}

  defp unsigned(:unsigned, destination, reads, {line, word}, diagnostics),
    do: {
      [
        diagnostic(
          line,
          "`#{word}` writes `#{destination.name}`, #{a_type(destination.type)}" <>
            "#{declared(destination)}, which holds no negative value: `#{word}` writes a " <>
            "signed type" <> signed_suggested(reads, destination)
        )
        | diagnostics
      ],
      {:class, :any_num}
    }

  defp unsigned(_kind, destination, _reads, _at, diagnostics), do: {diagnostics, destination}

  # The signed integer types, narrowest first, from the one table.
  @signed Enum.sort_by(
            for(type <- Declarations.integers(), Declarations.kind(type) == :signed, do: type),
            &Declarations.width/1
          )

  defp signed_suggested([{:value, _class, %Tag{type: from} = source}], destination)
       when is_elementary(from),
       do: integer_suggested(Declarations.in_class?(from, :any_int), source, destination)

  # Decision 189: a literal source names the narrowest signed type its negation fits, the
  # value `neg` writes, `neg -128 count` an int; and, since the literal is judged in the
  # destination's type, one the literal fits too (provisional), `neg 128 count` an int.
  defp signed_suggested([{:value, _class, {:literal, value, literal}}], destination),
    do: literal_into(Enum.find(@signed, &both_fit?(&1, value)), {value, literal}, destination)

  defp signed_suggested(_unresolved, _destination), do: ""

  # A source of no integer type, a bool, adds nothing (decision 181): its own diagnostic,
  # that `neg` reads a number, is given.
  defp integer_suggested(true, %Tag{type: from} = source, destination),
    do: widened_into(Enum.find(@signed, &Declarations.widens?(from, &1)), source, destination)

  defp integer_suggested(false, _source, _destination), do: ""

  defp widened_into(nil, %Tag{type: from} = source, destination) do
    widest = List.last(@signed)

    ", and #{a_type(from)} widens into none, so convert `#{source.name}` first, with " <>
      "`#{Declarations.conversion(from, widest)}`, and #{declare(destination, widest)}"
  end

  defp widened_into(type, _source, destination), do: ", so #{declare(destination, type)}"

  defp both_fit?(type, value),
    do: Declarations.fits?(type, value) and Declarations.fits?(type, -value)

  defp literal_into(nil, {value, _literal} = literal, _destination),
    do: none_holds(Enum.any?(@signed, &Declarations.fits?(&1, value)), literal)

  defp literal_into(type, _literal, destination), do: ", so #{declare(destination, type)}"

  # The literal as written, and its negation, which no one wrote, as a value.
  defp none_holds(false, {_value, literal}), do: ", and none holds `#{Parser.spelling(literal)}`"
  defp none_holds(true, {value, _literal}), do: ", and none holds `#{-value}`, its negation"

  defp declare(destination, type), do: "declare `#{destination.name}` #{a_type(type)}"

  defp fits(true, _literal, _tag, _at, diagnostics), do: diagnostics

  defp fits(false, literal, %Tag{type: type} = tag, {line, word}, diagnostics) do
    message =
      "`#{word}` writes `#{Parser.spelling(literal)}` into `#{tag.name}`, " <>
        "#{Declarations.a_type(type)}: " <>
        Declarations.literal_misfit(type, Parser.value(literal), nil)

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
  defp how(true, :element, name), do: note("`var #{name} dint[8]`")
  defp how(true, _slot, name), do: note("in `var #{name} bool` or `var #{name} dint`")

  defp note(declaration),
    do:
      " (this program declares no tags: each is now declared before the first rung, " <>
        "as #{declaration})"

  # After a word that is not an instruction there is no signature to go by, so everything
  # up to the next instruction or branch group is taken to belong to it.
  defp skip_operands([literal | rest]) when is_literal(literal), do: skip_operands(rest)

  defp skip_operands([{:name, _, word} | rest] = elements),
    do: skip_name(mnemonic?(word), rest, elements)

  defp skip_operands(elements), do: elements

  defp skip_name(true, _rest, elements), do: elements
  defp skip_name(false, rest, _elements), do: skip_operands(rest)

  defp mnemonic?(word), do: Map.has_key?(@instructions, String.downcase(word))

  defp diagnostic(line, message), do: %Diagnostic{stage: :validate, line: line, message: message}
end
