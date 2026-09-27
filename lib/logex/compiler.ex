defmodule Logex.Compiler do
  defdelegate tokenize(source), to: Logex.Lexer
  defdelegate parse(tokens), to: Logex.Parser

  # Each mnemonic's operand signature, in order: `:tag` must be a tag name, and `:value`
  # may be a tag or an integer literal. Mnemonics are matched case-insensitively and are
  # reserved: no tag may be named after one, in any case.
  @instructions %{
    "xic" => {:xic, [:tag]},
    "xio" => {:xio, [:tag]},
    "ote" => {:ote, [:tag]},
    "otl" => {:otl, [:tag]},
    "otu" => {:otu, [:tag]},
    "move" => {:move, [:value, :tag]}
  }

  @doc """
  The mnemonic table: each lowercase mnemonic to its IR symbol and operand signature.

  Every key must have a `### \\`mnemonic\\`` stanza in `docs/naming.md`;
  `Logex.NamingTest` enforces it.
  """
  def instructions, do: @instructions

  @doc """
  Lowers a parse AST to the IR, checking every instruction against its operand signature.

  Returns `{:ok, ir}`, where an instruction is `{symbol, line, operands}`, or
  `{:error, diagnostics}`: every `%Logex.Diagnostic{}` in the routine, in source order.
  After a word that is not an instruction, the words that follow it are skipped up to the
  next instruction or branch group, so one mistake is reported once.
  """
  def instructionize({:routine, {:rungs, rungs}}) do
    {rungs, diagnostics} = Enum.map_reduce(rungs, [], &lower_rung/2)
    lowered(rungs, Enum.reverse(diagnostics))
  end

  defp lowered(rungs, []), do: {:ok, {:routine, {:rungs, rungs}}}
  defp lowered(_rungs, diagnostics), do: {:error, diagnostics}

  defp lower_rung({:rung, elements}, diagnostics) do
    {ir, diagnostics} = lower(elements, [], diagnostics)
    {{:rung, ir}, diagnostics}
  end

  # Diagnostics are accumulated newest first and reversed once, in instructionize/1.
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
    diagnostics = check_kinds(signature, operands, word, diagnostics)
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

  defp unknown(_key, word), do: "unknown instruction `#{word}`"

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
    do: "#{operands(length(signature))} (#{Enum.map_join(signature, ", then ", &kind/1)})"

  defp operands(1), do: "1 operand"
  defp operands(count), do: "#{count} operands"

  defp kind(:tag), do: "a tag"
  defp kind(:value), do: "a value"

  defp found(0), do: "none"
  defp found(count), do: "#{count}"

  # Operands stop early only at a mnemonic, a branch group or the end of the leg. Only a
  # mnemonic needs saying: the person meant it as a tag.
  defp stopped_at([{:name, _, word} | _]), do: " — `#{word}` is an instruction, not a tag"
  defp stopped_at(_rest), do: ""

  defp check_kinds([:tag | kinds], [{:int_lit, line, value} | operands], word, diagnostics) do
    wrong = diagnostic(line, "`#{word}` expects a tag, found `#{value}`")
    check_kinds(kinds, operands, word, [wrong | diagnostics])
  end

  defp check_kinds([_kind | kinds], [_operand | operands], word, diagnostics),
    do: check_kinds(kinds, operands, word, diagnostics)

  defp check_kinds(_kinds, [], _word, diagnostics), do: diagnostics

  # After a word that is not an instruction there is no signature to go by, so everything
  # up to the next instruction or branch group is taken to belong to it.
  defp skip_operands([{:int_lit, _, _} | rest]), do: skip_operands(rest)

  defp skip_operands([{:name, _, word} | rest] = elements),
    do: skip_name(mnemonic?(word), rest, elements)

  defp skip_operands(elements), do: elements

  defp skip_name(true, _rest, elements), do: elements
  defp skip_name(false, rest, _elements), do: skip_operands(rest)

  defp mnemonic?(word), do: Map.has_key?(@instructions, String.downcase(word))

  defp diagnostic(line, message), do: %Logex.Diagnostic{line: line, message: message}

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
