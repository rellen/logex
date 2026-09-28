defmodule Logex.Compiler do
  alias Logex.{Declarations, Diagnostic, Program}

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
  def instructionize({:routine, {:rungs, rungs}}, declared \\ []) do
    {tags, logic, declaring} = Declarations.split(rungs, declared)
    {rungs, lowering} = Enum.map_reduce(logic, [], &lower_rung/2)
    lowered(rungs, tags, declaring ++ Enum.reverse(lowering))
  end

  defp lowered(rungs, tags, []), do: {:ok, %Program{rungs: rungs, tags: tags}}

  # A declaration after the first rung is reported where it stands, so the two lists are
  # merged by line. The sort is stable: within a line, the order each list gave is kept.
  defp lowered(_rungs, _tags, diagnostics), do: {:error, Enum.sort_by(diagnostics, & &1.line)}

  defp lower_rung({:rung, elements}, diagnostics) do
    {ir, diagnostics} = lower(elements, [], diagnostics)
    {{:rung, ir}, diagnostics}
  end

  # Diagnostics are accumulated newest first and reversed once, in instructionize/2.
  defp lower([], ir, diagnostics), do: {Enum.reverse(ir), diagnostics}

  defp lower([{:branches, legs} | rest], ir, diagnostics) do
    {legs, diagnostics} = Enum.map_reduce(legs, diagnostics, &lower(&1, [], &2))
    lower(rest, [{:branches, legs} | ir], diagnostics)
  end

  defp lower([{:name, line, word} | rest], ir, diagnostics) do
    key = String.downcase(word)
    lower_word(Map.fetch(@instructions, key), key, {line, word}, rest, ir, diagnostics)
  end

  # The grammar allows a literal anywhere an element can go, including where an
  # instruction must start: `123 aa`, or an extra operand as in `xic aa 7 ote bb`.
  defp lower([{:int_lit, line, value} | rest], ir, diagnostics) do
    found = diagnostic(line, "expected an instruction, found `#{value}`")
    lower(skip_operands(rest), ir, [found | diagnostics])
  end

  defp lower_word({:ok, {symbol, signature}}, _key, {line, word}, rest, ir, diagnostics) do
    {operands, rest} = take_operands(rest, length(signature), [])
    diagnostics = check_count(signature, operands, rest, {line, word}, diagnostics)
    diagnostics = check_kinds(signature, operands, {line, word}, diagnostics)
    lower(rest, [{symbol, line, operands} | ir], diagnostics)
  end

  defp lower_word(:error, key, {line, word}, rest, ir, diagnostics) do
    unknown = diagnostic(line, unknown(key, word))
    lower(skip_operands(rest), ir, [unknown | diagnostics])
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
    {Map.get(env, arg) == 1, env}
  end

  def evaluate({:xic, _, _}, {false, env}) do
    {false, env}
  end

  def evaluate({:xio, _, [{:name, _, arg}]}, {true, env}) do
    {Map.get(env, arg) == 0, env}
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
  defp get_arg(env, {:name, _, name}), do: Map.get(env, name)
end
