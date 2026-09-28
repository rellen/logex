defmodule Logex.Declarations do
  @moduledoc """
  Declaration lines, resolved after parsing as mnemonics are (PLAN.md §6): to the parser
  `var_input start bool` is a rung of three names. A declaration is a rung whose first word
  is a section keyword, and every one comes before the first rung of logic.

      <section> <name> <type> [<initial>]     section: var | var_input | var_output
                                              type:    bool | dint

  The section and type words are data, in `@sections` and `@types`: a new section or type
  is a row there and a stanza in `docs/naming.md`, not a second declaration parser.
  """

  alias Logex.{Diagnostic, Tag}

  @sections %{"var" => :var, "var_input" => :var_input, "var_output" => :var_output}
  @types %{"bool" => :bool, "dint" => :dint}

  @section_atoms Map.values(@sections)
  @type_atoms Map.values(@types)

  # IEC 61131-3 Ed 2 Table 10: a BOOL is 0 or 1, and a DINT is 32 bits, -(2^31)..2^31 - 1.
  @dint -2_147_483_648..2_147_483_647

  @doc "The section and type words, lowercase. Each is reserved, in any case."
  def keywords, do: Map.keys(@sections) ++ Map.keys(@types)

  @doc "What a word is reserved as, in any case: `:mnemonic`, `:section`, `:type` or nil."
  def reserved(word) do
    key = String.downcase(word)
    reserved_as(key, Map.has_key?(Logex.Compiler.instructions(), key))
  end

  defp reserved_as(_key, true), do: :mnemonic
  defp reserved_as(key, false) when is_map_key(@sections, key), do: :section
  defp reserved_as(key, false) when is_map_key(@types, key), do: :type
  defp reserved_as(_key, false), do: nil

  @doc "Whether an integer fits a type."
  def fits?(:bool, value), do: value in [0, 1]
  def fits?(:dint, value), do: value in @dint

  @doc """
  Splits parsed rungs into a tag table and the rungs of logic:
  `{tags, logic_rungs, diagnostics}`, the diagnostics in source order.

  `declared` are tags built in Elixir with `Logex.Tag.new!/4`; they enter the table first,
  and a clash among them raises. A declaration after the first rung is reported and still
  declared, so its tag is not also reported as undeclared wherever it is used.
  """
  def split(rungs, declared \\ []) do
    {leading, rest} = Enum.split_while(rungs, &declaration?/1)
    {late, logic} = Enum.split_with(rest, &declaration?/1)
    late = Enum.map(late, &late(&1, first_line(logic)))
    {tags, diagnostics} = Enum.flat_map_reduce(leading ++ late, [], &declare/2)
    {table, diagnostics} = table(declared, tags, diagnostics)
    {table, logic, Enum.reverse(diagnostics)}
  end

  defp declaration?({:rung, [{:name, _, word} | _]}), do: reserved(word) == :section
  defp declaration?(_rung), do: false

  defp late({:rung, [{:name, line, word} | _]} = rung, first),
    do:
      {:late, rung,
       diagnostic(
         line,
         "`#{word}` after the first rung#{at(first)}: " <>
           "declarations come first"
       )}

  defp at(nil), do: ""
  defp at(line), do: " (line #{line})"

  defp first_line([{:rung, elements} | rest]), do: line_in(elements) || first_line(rest)
  defp first_line([]), do: nil

  defp line_in([{:branches, legs} | rest]), do: Enum.find_value(legs, &line_in/1) || line_in(rest)
  defp line_in([{_, line, _} | _]), do: line
  defp line_in([]), do: nil

  defp declare({:late, rung, late}, diagnostics), do: declare(rung, [late | diagnostics])

  defp declare({:rung, [{:name, line, keyword} | rest]}, diagnostics) do
    section = Map.fetch!(@sections, String.downcase(keyword))
    declared(shape(rest, keyword), section, line, diagnostics)
  end

  defp declared({:ok, name, type, initial}, section, line, diagnostics) do
    tag = %Tag{name: name, type: type, section: section, initial: initial, line: line}
    checked(check(tag), tag, line, diagnostics)
  end

  defp declared({:error, message}, _section, line, diagnostics),
    do: {[], [diagnostic(line, message) | diagnostics]}

  defp checked([], tag, _line, diagnostics),
    do: {[%{tag | initial: tag.initial || 0}], diagnostics}

  defp checked(messages, _tag, line, diagnostics),
    do: {[], Enum.reverse(Enum.map(messages, &diagnostic(line, &1)), diagnostics)}

  # The shape of a declaration line, before its meaning is checked.
  defp shape([], kw),
    do: {:error, "`#{kw}` needs a tag name and a type, as in `#{kw} fault bool`"}

  defp shape([{:branches, _} | _], _kw), do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:int_lit, _, v} | _], kw),
    do: {:error, "expected a tag name after `#{kw}`, found `#{v}`"}

  defp shape([{:name, _, name}], kw),
    do: {:error, "`#{name}` needs a type: `#{kw} #{name} bool` or `#{kw} #{name} dint`"}

  defp shape([{:name, _, name}, {:int_lit, _, v} | _], _kw),
    do: {:error, "`#{name}` needs a type before its initial value `#{v}`"}

  defp shape([{:name, _, _}, {:branches, _} | _], _kw),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:name, _, name}, {:name, _, type} | tail], kw),
    do: typed(Map.get(@types, String.downcase(type)), name, type, tail, kw)

  defp typed(nil, name, type, tail, kw),
    do: {:error, untyped(String.downcase(name), name, type, tail, kw)}

  defp typed(type, name, _word, [], _kw), do: {:ok, name, type, nil}
  defp typed(type, name, _word, [{:int_lit, _, v}], _kw), do: {:ok, name, type, v}

  defp typed(_type, name, _word, [{:int_lit, _, _}, extra | _], _kw),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  defp typed(_type, name, _word, [extra | _], _kw),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  # IEC's RETAIN qualifier (docs/instruction-sets.md §3.2, Table 33 f3a) is not a tag name
  # here, because a tag name is never followed by a second name.
  defp untyped("retain", _name, _type, _tail, _kw),
    do:
      "`retain` is not supported yet: nothing restarts a logex program, " <>
        "so there is nothing for a tag to survive (PLAN.md M1-5)"

  defp untyped(_key, name, type, tail, kw),
    do: unknown_type(Enum.any?(tail, &type_word?/1), name, type, kw)

  defp unknown_type(true, name, type, kw),
    do: "`#{kw}` declares one tag: found `#{name}` and `#{type}` before the type"

  defp unknown_type(false, _name, type, _kw),
    do: "unknown type `#{type}`: logex has `bool` and `dint`"

  defp type_word?({:name, _, word}), do: reserved(word) == :type
  defp type_word?(_element), do: false

  defp describe({:name, _, word}), do: "`#{word}`"
  defp describe({:int_lit, _, v}), do: "`#{v}`"
  defp describe({:branches, _}), do: "a branch group"

  @doc """
  The rules a tag must meet however it is declared, as messages: the one validator for a
  declaration line and for `Logex.Tag.new!/4`.
  """
  def check(%Tag{} = tag) do
    name(tag.name) ++ type(tag.type) ++ section(tag.section) ++ initial(tag)
  end

  defp name(name) when is_binary(name), do: name(reserved(name), name, Logex.Lexer.tokenize(name))
  defp name(name), do: ["#{inspect(name)} is not a tag name"]

  defp name(:mnemonic, name, _), do: ["`#{name}` is an instruction and cannot name a tag"]
  defp name(:type, name, _), do: ["`#{name}` is a type and cannot name a tag"]
  defp name(:section, name, _), do: ["`#{name}` is a keyword and cannot name a tag"]
  defp name(nil, name, {:ok, [{:name, _, name}], _}), do: []
  defp name(nil, name, _), do: ["#{inspect(name)} is not a tag name"]

  defp type(type) when type in @type_atoms, do: []
  defp type(type), do: ["unknown type #{inspect(type)}: logex has `bool` and `dint`"]

  defp section(section) when section in @section_atoms, do: []
  defp section(section), do: ["unknown section #{inspect(section)}"]

  defp initial(%Tag{initial: nil}), do: []

  defp initial(%Tag{section: :var_input, name: name}),
    do: ["`#{name}` is a var_input: its value comes from outside, so it takes no initial value"]

  defp initial(%Tag{type: type, name: name, initial: v}) when type in @type_atoms,
    do: fit(fits?(type, v), type, name, v)

  defp initial(_tag), do: []

  defp fit(true, _type, _name, _v), do: []

  defp fit(false, :bool, name, v),
    do: ["`#{name}` is a bool: its initial value must be 0 or 1, found `#{v}`"]

  defp fit(false, :dint, name, v), do: ["`#{name}` is a dint: `#{v}` does not fit in 32 bits"]

  # Tags from Elixir first, then the source's own, each checked against those before it.
  # `folded` indexes the table by lowercased name, so a case-only twin is one lookup.
  defp table(declared, tags, diagnostics) do
    {tables, []} = Enum.reduce(declared, {{%{}, %{}}, []}, &enter(&1, &2, :raise))

    {{table, _folded}, diagnostics} =
      Enum.reduce(tags, {tables, diagnostics}, &enter(&1, &2, :report))

    {table, diagnostics}
  end

  defp enter(tag, {{table, folded}, diagnostics}, mode) do
    key = String.downcase(tag.name)
    clash(Map.get(folded, key), tag, key, {table, folded}, diagnostics, mode)
  end

  defp clash(nil, tag, key, {table, folded}, diagnostics, _mode),
    do: {{Map.put(table, tag.name, tag), Map.put(folded, key, tag)}, diagnostics}

  defp clash(%Tag{name: name} = first, %Tag{name: name} = tag, _key, tables, diagnostics, mode),
    do: {tables, report(mode, tag, "`#{name}` is declared twice: #{first(first)}", diagnostics)}

  defp clash(first, tag, _key, tables, diagnostics, mode) do
    message =
      "`#{tag.name}` and `#{first.name}`#{where(first)} differ only in case: " <>
        "tags are case-sensitive, so these would be two tags"

    {tables, report(mode, tag, message, diagnostics)}
  end

  defp first(%Tag{line: nil}), do: "the caller's table already has it"
  defp first(%Tag{line: line}), do: "first on line #{line}"

  defp where(%Tag{line: nil}), do: " (the caller's table)"
  defp where(%Tag{line: line}), do: " (line #{line})"

  defp report(:raise, _tag, message, _diagnostics), do: raise(ArgumentError, message)

  defp report(:report, tag, message, diagnostics),
    do: [diagnostic(tag.line, message) | diagnostics]

  defp diagnostic(line, message), do: %Diagnostic{line: line, message: message}
end
