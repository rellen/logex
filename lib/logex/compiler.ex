defmodule Logex.Compiler do
  alias Logex.{Declarations, Diagnostic, Program, Tag}

  defdelegate tokenize(source), to: Logex.Lexer
  defdelegate parse(tokens), to: Logex.Parser

  # Each mnemonic's operand signature, in order, one `{access, type}` per operand. Access:
  # `:read` and `:write` must be a tag, and `:value` may be a tag or an integer literal.
  # Type: `:bool`, `:dint`, or `:any`, which IEC's MOVE takes (`IN : ANY` -> `OUT : ANY`,
  # docs/naming.md). Mnemonics are matched case-insensitively and are reserved: no tag may
  # be named after one, in any case.
  @instructions %{
    "xic" => {:xic, [{:read, :bool}]},
    "xio" => {:xio, [{:read, :bool}]},
    "ote" => {:ote, [{:write, :bool}]},
    "otl" => {:otl, [{:write, :bool}]},
    "otu" => {:otu, [{:write, :bool}]},
    "move" => {:move, [{:value, :any}, {:write, :any}]}
  }

  @doc """
  The mnemonic table: each lowercase mnemonic to its IR symbol and operand signature.

  Every key must have a `### \\`mnemonic\\`` stanza in `docs/naming.md`;
  `Logex.NamingTest` enforces it.
  """
  def instructions, do: @instructions

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
  """
  def instructionize({:routine, {:rungs, rungs}} = routine, declared \\ []) do
    {tags, logic, declaring} = Declarations.split(rungs, declared)
    {rungs, lowering} = Enum.map_reduce(logic, [], &lower_rung(&1, &2, tags))
    note? = map_size(tags) == 0 and declares_nothing?(routine, logic)
    lowered(rungs, tags, declaring ++ undeclared(Enum.reverse(lowering), tags, note?))
  end

  # No declaration line at all, as opposed to declarations that were all wrong.
  defp declares_nothing?({:routine, {:rungs, rungs}}, logic), do: length(rungs) == length(logic)

  defp lowered(rungs, tags, []), do: {:ok, %Program{rungs: rungs, tags: tags}}

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_rungs, _tags, diagnostics), do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  defp lower_rung({:rung, elements}, diagnostics, tags) do
    {ir, diagnostics} = lower(elements, [], diagnostics, tags)
    {{:rung, ir}, diagnostics}
  end

  # Diagnostics are accumulated newest first and reversed once, in instructionize/2. An
  # undeclared tag is accumulated as `{:undeclared, line, name}` and reported by
  # undeclared/3, at its first use only.
  defp lower([], ir, diagnostics, _tags), do: {Enum.reverse(ir), diagnostics}

  defp lower([{:branches, legs} | rest], ir, diagnostics, tags) do
    {legs, diagnostics} = Enum.map_reduce(legs, diagnostics, &lower(&1, [], &2, tags))
    lower(rest, [{:branches, legs} | ir], diagnostics, tags)
  end

  defp lower([{:name, line, word} | rest], ir, diagnostics, tags) do
    key = String.downcase(word)
    lower_word(Map.fetch(@instructions, key), key, {line, word}, {rest, ir, diagnostics, tags})
  end

  # The grammar allows a literal anywhere an element can go, including where an
  # instruction must start: `123 aa`, or an extra operand as in `xic aa 7 ote bb`.
  defp lower([{:int_lit, line, value} | rest], ir, diagnostics, tags) do
    found = diagnostic(line, "expected an instruction, found `#{value}`")
    lower(skip_operands(rest), ir, [found | diagnostics], tags)
  end

  defp lower_word({:ok, {symbol, signature}}, _key, {line, _} = at, {rest, ir, diagnostics, tags}) do
    {operands, rest} = take_operands(rest, length(signature), [])
    diagnostics = check_count(signature, operands, rest, at, diagnostics)
    diagnostics = check_kinds(signature, operands, at, diagnostics)
    diagnostics = check_tags(signature, operands, at, tags, diagnostics)
    lower(rest, [{symbol, line, operands} | ir], diagnostics, tags)
  end

  defp lower_word(:error, key, {line, word}, {rest, ir, diagnostics, tags}) do
    unknown = diagnostic(line, unknown(key, word))
    lower(skip_operands(rest), ir, [unknown | diagnostics], tags)
  end

  @migrated ~w(bst nxb bnd)

  # B1 made the branch delimiters punctuation, and the migration is otherwise silent: an
  # old `bst …` program is no longer a syntax error, so it arrives here. Only instruction
  # position is claimed -- `bst` remains a perfectly good tag name.
  defp unknown(key, word) when key in @migrated,
    do: "`#{word}` is no longer a keyword — branches are written `( … | … )`"

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
  # pairing raises here rather than reaching evaluate/2 unchecked.
  defp check_kind({:read, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:write, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:value, _type}, {:name, _, _}, _at, diagnostics), do: diagnostics
  defp check_kind({:value, _type}, {:int_lit, _, _}, _at, diagnostics), do: diagnostics

  defp check_kind(kind, {:int_lit, _, value}, {line, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects #{kind(kind)}, found `#{value}`") | diagnostics]

  # M1-3: each operand against the tag table -- declared, of the type its slot reads or
  # writes, and not a var_input where the slot writes. A literal where a tag must go was
  # reported by check_kind/4 and is not looked at again. Then the `:any` operands must agree.
  defp check_tags(signature, operands, at, tags, diagnostics) do
    slots = Enum.zip(signature, operands)
    diagnostics = Enum.reduce(slots, diagnostics, &check_tag(&1, at, tags, &2))

    unify(
      for({{_, :any}, operand} <- slots, typed = typed(operand, tags), do: typed),
      at,
      diagnostics
    )
  end

  defp check_tag({_slot, {:int_lit, _, _}}, _at, _tags, diagnostics), do: diagnostics

  defp check_tag({slot, {:name, _, name} = operand}, at, tags, diagnostics),
    do:
      resolve(Declarations.reserved(name), Map.fetch(tags, name), slot, operand, at, diagnostics)

  # take_operands/3 never takes a mnemonic, so a reserved operand is a section or type word.
  defp resolve(:type, _, _slot, {:name, line, name}, {_, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects a tag, found the type `#{name}`") | diagnostics]

  defp resolve(:section, _, _slot, {:name, line, name}, {_, word}, diagnostics),
    do: [diagnostic(line, "`#{word}` expects a tag, found the keyword `#{name}`") | diagnostics]

  defp resolve(nil, :error, _slot, {:name, line, name}, _at, diagnostics),
    do: [{:undeclared, line, name} | diagnostics]

  defp resolve(nil, {:ok, tag}, {access, type}, {:name, line, _}, {_, word}, diagnostics),
    do:
      diagnostics
      |> check_type(access, type, tag, {line, word})
      |> check_access(access, tag, {line, word})

  defp check_type(diagnostics, _access, :any, _tag, _at), do: diagnostics
  defp check_type(diagnostics, _access, type, %Tag{type: type}, _at), do: diagnostics

  defp check_type(diagnostics, access, type, tag, {line, word}) do
    message =
      "`#{word}` #{verb(access)} a #{type}, but `#{tag.name}` is a #{tag.type}#{declared(tag)}"

    [diagnostic(line, message) | diagnostics]
  end

  defp verb(:write), do: "writes"
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

  defp typed({:int_lit, _, value}, _tags), do: {:literal, value}
  defp typed({:name, _, name}, tags), do: Map.get(tags, name)

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
    {diagnostics, _} = Enum.flat_map_reduce(found, {MapSet.new(), note?}, &report(&1, &2, tags))
    diagnostics
  end

  defp report({:undeclared, line, name}, {seen, _} = acc, tags),
    do: first_use(MapSet.member?(seen, name), line, name, tags, acc)

  defp report(%Diagnostic{} = diagnostic, acc, _tags), do: {[diagnostic], acc}

  defp first_use(true, _line, _name, _tags, acc), do: {[], acc}

  defp first_use(false, line, name, tags, {seen, note?}) do
    message = "`#{name}` is not declared" <> suggest(name, Map.keys(tags)) <> how(note?, name)
    {[diagnostic(line, message)], {MapSet.put(seen, name), false}}
  end

  defp how(false, _name), do: ""

  defp how(true, name),
    do:
      " (this program declares no tags: each is now declared before the first rung, " <>
        "as `var #{name} bool` or `var #{name} dint`)"

  # A declared name differing only in case is always the suggestion; otherwise the nearest
  # by Jaro distance, if it is near enough.
  defp suggest(name, names) do
    folded = String.downcase(name)
    same_but_case(Enum.find(names, &(String.downcase(&1) == folded)), name, names)
  end

  defp same_but_case(nil, name, names),
    do: nearest(Enum.max_by(names, &String.jaro_distance(&1, name), fn -> nil end), name)

  defp same_but_case(same, _name, _names),
    do: " — did you mean `#{same}`? (tags are case-sensitive)"

  defp nearest(nil, _name), do: ""
  defp nearest(best, name), do: near(String.jaro_distance(best, name) >= 0.8, best)

  defp near(true, best), do: " — did you mean `#{best}`?"
  defp near(false, _best), do: ""

  # After a word that is not an instruction there is no signature to go by, so everything
  # up to the next instruction or branch group is taken to belong to it.
  defp skip_operands([{:int_lit, _, _} | rest]), do: skip_operands(rest)

  defp skip_operands([{:name, _, word} | rest] = elements),
    do: skip_name(mnemonic?(word), rest, elements)

  defp skip_operands(elements), do: elements

  defp skip_name(true, _rest, elements), do: elements
  defp skip_name(false, rest, _elements), do: skip_operands(rest)

  defp mnemonic?(word), do: Map.has_key?(@instructions, String.downcase(word))

  defp diagnostic(line, message), do: %Diagnostic{line: line, message: message}

  def evaluate(%Program{rungs: rungs}, acc), do: evaluate({:routine, {:rungs, rungs}}, acc)

  def evaluate({:routine, {:rungs, rungs}}, {_, env}) do
    new_env =
      Enum.reduce(rungs, env, fn rung, env ->
        {_, new_env} = evaluate(rung, {true, env})
        new_env
      end)

    {true, new_env}
  end

  def evaluate({:rung, branch}, env), do: evaluate(branch, env)

  def evaluate({:branches, branches}, {input, env}) do
    {outputs, new_env} =
      Enum.reduce(branches, {[], env}, fn branch, {outputs, env} ->
        {output, new_env} = evaluate(branch, {input, env})
        {[output | outputs], new_env}
      end)

    output = Enum.any?(outputs, fn output -> output == true end)
    {output, new_env}
  end

  def evaluate(branch, {input, env}) when is_list(branch) do
    Enum.reduce(branch, {input, env}, fn elem, {input, env} ->
      evaluate(elem, {input, env})
    end)
  end

  def evaluate({:xic, _, [{:name, _, arg}]}, {true, env}) do
    {bit(env, arg), env}
  end

  def evaluate({:xic, _, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:xio, _, [{:name, _, arg}]}, {true, env}) do
    {not bit(env, arg), env}
  end

  def evaluate({:xio, _, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:ote, _, [{:name, _, arg}]}, {true, env}) do
    {true, Map.put(env, arg, 1)}
  end

  def evaluate({:ote, _, [{:name, _, arg}]}, {false, env}) do
    {false, Map.put(env, arg, 0)}
  end

  def evaluate({:otl, _, [{:name, _, arg}]}, {true, env}) do
    {true, Map.put(env, arg, 1)}
  end

  def evaluate({:otl, _, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:otu, _, [{:name, _, arg}]}, {true, env}) do
    {true, Map.put(env, arg, 0)}
  end

  def evaluate({:otu, _, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:move, _, [arg1, {:name, _, arg2}]}, {true, env}) do
    {true, Map.put(env, arg2, get_arg(env, arg1))}
  end

  def evaluate({:move, _, _}, {false, env}) do
    {false, env}
  end

  defp get_arg(_env, {:int_lit, _, val}), do: val
  defp get_arg(env, {:name, _, name}), do: Map.get(env, name, 0)

  # M1-4: `xic` reads this and `xio` its negation, so the two are complementary by
  # construction, whatever the env holds. The compiler lets only a bool reach a contact,
  # but an env the host builds by hand can hold a 5, a 0.0, a `false`, a nil, or leave a
  # tag out. A number is read by value, nonzero closed (PLAN.md §5), and a boolean as
  # itself; nil and a missing tag are open; anything else is closed. A missing tag reads
  # as 0 in get_arg/2 too, so `move` copies a 0 rather than a nil.
  defp bit(env, name), do: closed?(Map.get(env, name))

  defp closed?(value) when is_number(value), do: value != 0
  defp closed?(value) when value in [nil, false], do: false
  defp closed?(_value), do: true
end
