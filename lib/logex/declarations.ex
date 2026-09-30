defmodule Logex.Declarations do
  @moduledoc """
  Declaration lines, resolved after parsing as mnemonics are (PLAN.md §6): to the parser
  `var_input start bool` is a rung of three names. A declaration is a rung whose first word
  is a section keyword, and every one comes before the first rung of logic.

      <section> <name> <type> [<initial>]     section: var | var_input | var_output
                                              type:    bool | dint | ton

  The section and type words are data, in `@sections` and `@types`, and a function block
  type's word is `Logex.FbType.builtins/0`'s: a new section or type is a row there and a
  stanza in `docs/naming.md`, not a second declaration parser. An instance of a function
  block, `var t1 ton` (M1-6), is declared with `var` and takes no initial value.
  """

  alias Logex.{Diagnostic, FbType, Tag}

  @sections %{"var" => :var, "var_input" => :var_input, "var_output" => :var_output}
  @types %{"bool" => :bool, "dint" => :dint}

  @section_atoms Map.values(@sections)
  @type_atoms Map.values(@types)

  # IEC 61131-3 Ed 2 Table 10: a BOOL is 0 or 1, and a DINT is 32 bits, -(2^31)..2^31 - 1.
  @dint -2_147_483_648..2_147_483_647

  @doc "The section and type words, lowercase. Each is reserved, in any case."
  def keywords, do: Map.keys(@sections) ++ Map.keys(@types) ++ Map.keys(FbType.builtins())

  # A type word names an elementary type or a function block type, in any case.
  defp type_word(word), do: type_of(String.downcase(word))

  defp type_of(key) when is_map_key(@types, key), do: Map.fetch!(@types, key)
  defp type_of(key), do: FbType.builtin(key)

  @doc "What a word is reserved as, in any case: `:mnemonic`, `:section`, `:type` or nil."
  def reserved(word) do
    key = String.downcase(word)
    reserved_as(key, Map.has_key?(Logex.Compiler.instructions(), key))
  end

  defp reserved_as(_key, true), do: :mnemonic
  defp reserved_as(key, false) when is_map_key(@sections, key), do: :section
  defp reserved_as(key, false) when is_map_key(@types, key), do: :type
  defp reserved_as(key, false), do: fb_word(FbType.builtin(key))

  defp fb_word(nil), do: nil
  defp fb_word(%FbType{}), do: :type

  @doc """
  Whether `word` is shaped like a name: a letter or `_`, then letters, digits or `_`. The
  one rule for a program's name, and the lexer's for a tag.
  """
  def name?(word) when is_binary(word), do: String.match?(word, ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/)
  def name?(_word), do: false

  @doc """
  A did-you-mean for `name` among `names`, as a suffix for a message, or "". A name
  differing only in case is always the suggestion; otherwise the nearest by Jaro distance,
  if it is near enough. A `name` that is not valid UTF-8 gets none. `shown` renders the
  name chosen, so a member is matched on its own name and shown whole, as `t1.dn`, and
  `kind` says what is case-sensitive: `"tags"`, or `"members"`.
  """
  def suggest(name, names, shown \\ & &1, kind \\ "tags"),
    do: suggested(String.valid?(name), name, names, {shown, kind})

  defp suggested(false, _name, _names, _how), do: ""

  defp suggested(true, name, names, how) do
    folded = String.downcase(name)
    same_but_case(Enum.find(names, &(String.downcase(&1) == folded)), name, names, how)
  end

  defp same_but_case(nil, name, names, how),
    do: nearest(Enum.max_by(names, &String.jaro_distance(&1, name), fn -> nil end), name, how)

  defp same_but_case(same, _name, _names, {shown, kind}),
    do: " — did you mean `#{shown.(same)}`? (#{kind} are case-sensitive)"

  defp nearest(nil, _name, _how), do: ""

  defp nearest(best, name, {shown, _kind}),
    do: near(String.jaro_distance(best, name) >= 0.8, shown.(best))

  defp near(true, best), do: " — did you mean `#{best}`?"
  defp near(false, _best), do: ""

  @doc "Whether an integer fits a type."
  def fits?(:bool, value), do: value in [0, 1]
  def fits?(:dint, value), do: value in @dint

  @doc """
  Splits parsed rungs into a tag table and the rungs of logic:
  `{tags, logic_rungs, diagnostics}`, the diagnostics in line order.

  `declared` are tags built in Elixir with `Logex.Tag.new!/4`. Each is checked again by
  `validate!/1` and they enter the table first; anything invalid among them, a clash
  included, raises `ArgumentError`. A declaration after the first rung is reported and
  still declared, so its tag is not also reported as undeclared wherever it is used.
  """
  def split(rungs, declared \\ [])

  def split(rungs, declared) when is_list(declared) do
    {leading, rest} = Enum.split_while(rungs, &declaration?/1)
    {late, logic} = Enum.split_with(rest, &declaration?/1)
    late = Enum.map(late, &late(&1, first_line(logic)))
    {tags, diagnostics} = Enum.flat_map_reduce(leading ++ late, [], &declare/2)
    {table, diagnostics} = table(Enum.map(declared, &validate!/1), tags, diagnostics)
    {table, logic, Enum.sort_by(Enum.reverse(diagnostics), & &1.line)}
  end

  def split(_rungs, declared),
    do: raise(ArgumentError, "declared must be a list of %Logex.Tag{}, got: #{inspect(declared)}")

  @doc """
  A tag declared from Elixir, checked by `check/1`: the tag itself, or `ArgumentError`
  with the first rule it breaks. It can be applied twice, as `Logex.Tag.new!/4` and
  `split/2` both do. Such a tag has no `line`: a line is what marks a tag declared in
  source, which the warnings and every "declared on line" message rely on.
  """
  def validate!(%Tag{line: nil} = tag), do: validated(check(tag), tag)

  def validate!(%Tag{line: line}),
    do: raise(ArgumentError, "a tag declared from Elixir has no line, got: #{inspect(line)}")

  def validate!(other),
    do: raise(ArgumentError, "expected a %Logex.Tag{}, got: #{inspect(other)}")

  defp validated([], tag), do: tag
  defp validated([message | _], _tag), do: raise(ArgumentError, message)

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

  # The first rung's own line. A rung of empty groups, such as `( )`, has none, and then no
  # line is cited rather than a later rung's.
  defp first_line([{:rung, elements} | _]), do: line_in(elements)
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

  defp checked([], tag, _line, diagnostics), do: {[tag], diagnostics}

  defp checked(messages, tag, line, diagnostics),
    do: {recovered(tag), Enum.reverse(Enum.map(messages, &diagnostic(line, &1)), diagnostics)}

  # M1-6: an instance declared in the wrong section, or with an initial value, is still
  # plainly an instance, so it is declared as `var t1 ton` too, and its uses are not each
  # reported as undeclared: one mistake, one message. A bad name is not recovered, and
  # any other broken declaration declares nothing, as M1-3 decided.
  defp recovered(%Tag{type: %FbType{}, name: name} = tag),
    do: recover(name(name), %{tag | section: :var, initial: nil})

  defp recovered(_tag), do: []

  defp recover([], tag), do: [tag]
  defp recover(_problems, _tag), do: []

  # The shape of a declaration line, before its meaning is checked.
  defp shape([], kw),
    do: {:error, "`#{kw}` needs a tag name and a type, as in `#{kw} fault bool`"}

  defp shape([{:branches, _} | _], _kw), do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:int_lit, _, v} | _], kw),
    do: {:error, "expected a tag name after `#{kw}`, found `#{v}`"}

  defp shape([{:name, _, name}], kw), do: {:error, short(one(name), name, nil, kw)}

  defp shape([{:name, _, name}, {:int_lit, _, v} | _], kw),
    do: {:error, short(one(name), name, v, kw)}

  defp shape([{:name, _, _}, {:branches, _} | _], _kw),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:name, _, name}, {:name, _, type} | tail], kw),
    do: typed(type_word(type), name, type, tail, kw)

  defp typed(nil, name, type, tail, kw),
    do: {:error, untyped(String.downcase(name), name, type, tail, kw)}

  defp typed(type, name, _word, [], _kw), do: {:ok, name, type, nil}
  defp typed(type, name, _word, [{:int_lit, _, v}], _kw), do: {:ok, name, type, v}

  defp typed(_type, _name, _word, [{:branches, _} | _], _kw),
    do: {:error, "a declaration cannot hold a branch group"}

  defp typed(_type, _name, _word, [{:int_lit, _, _}, {:branches, _} | _], _kw),
    do: {:error, "a declaration cannot hold a branch group"}

  defp typed(_type, name, _word, [{:int_lit, _, _}, extra | _], _kw),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  defp typed(_type, name, _word, [extra | _], _kw),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  # The one word after a section: a type word first, since `ton` is a mnemonic too (M1-6).
  defp one(word), do: one(type_word(word), word)
  defp one(nil, word), do: reserved(word)
  defp one(type, _word), do: {:type, type}

  # A line with one word after its section: a tag with no type, or a type with no tag.
  defp short({:type, type}, word, _v, kw),
    do:
      "`#{kw}` needs a tag name before the type `#{word}`" <>
        as_in(type, Map.fetch!(@sections, String.downcase(kw)), word, kw)

  # A name that can never be declared says so first, rather than ask for a type.
  defp short(nil, name, v, kw),
    do: typeless(dotted(String.contains?(name, "."), name), name, v, kw)

  defp short(reserved, name, _v, _kw), do: hd(name(reserved, name, :reserved))

  # An instance is declared only with `var` (M1-6), so its example is the declaration that
  # works, whatever section the line was written with.
  defp as_in(%FbType{name: name} = type, section, word, _kw) when section != :var,
    do: "; a #{name} is declared with `var`, as in `var #{example(type)} #{word}`"

  defp as_in(type, _section, word, kw), do: ", as in `#{kw} #{example(type)} #{word}`"

  defp typeless([message], _name, _v, _kw), do: message

  defp typeless([], name, nil, kw),
    do: "`#{name}` needs a type: `#{kw} #{name} bool` or `#{kw} #{name} dint`"

  defp typeless([], name, v, _kw), do: "`#{name}` needs a type before its initial value `#{v}`"

  # IEC's RETAIN qualifier (docs/instruction-sets.md §3.2, Table 33 f3a) is not a tag name
  # here, because a tag name is never followed by a second name.
  defp untyped("retain", _name, _type, _tail, _kw),
    do:
      "`retain` is not supported yet: a warm restart, like a cold one, " <>
        "starts every tag but the var_inputs at its initial value"

  defp untyped(_key, name, type, tail, kw),
    do: unknown_type(Enum.any?(tail, &type_word?/1), name, type, kw)

  defp unknown_type(true, name, type, kw),
    do: "`#{kw}` declares one tag: found `#{name}` and `#{type}` before the type"

  defp unknown_type(false, _name, type, _kw),
    do: "unknown type `#{type}`: logex has `bool`, `dint` and `ton`"

  defp type_word?({:name, _, word}), do: type_word(word) != nil
  defp type_word?(_element), do: false

  defp example(%FbType{name: name}), do: String.first(name) <> "1"
  defp example(_elementary), do: "fault"

  defp describe({:name, _, word}), do: "`#{word}`"
  defp describe({:int_lit, _, v}), do: "`#{v}`"

  @doc """
  The rules a tag must meet however it is declared, as messages: the one validator for a
  declaration line and for `Logex.Tag.new!/4`.
  """
  def check(%Tag{type: %FbType{} = type} = tag) do
    known = fb_type(type)
    name(tag.name) ++ known ++ section(tag.section) ++ looked_into(known, tag)
  end

  def check(%Tag{} = tag) do
    name(tag.name) ++ type(tag.type) ++ section(tag.section) ++ initial(tag)
  end

  defp name(name) when is_binary(name), do: name(reserved(name), name, Logex.Lexer.tokenize(name))
  defp name(name), do: ["#{inspect(name)} is not a tag name"]

  defp name(:mnemonic, name, _), do: ["`#{name}` is an instruction and cannot name a tag"]
  defp name(:type, name, _), do: ["`#{name}` is a type and cannot name a tag"]
  defp name(:section, name, _), do: ["`#{name}` is a keyword and cannot name a tag"]

  defp name(nil, name, {:ok, [{:name, _, name}], _}),
    do: dotted(String.contains?(name, "."), name)

  defp name(nil, name, _), do: ["#{inspect(name)} is not a tag name"]

  # A name with `.` parts lexes as one token (PLAN.md §5), but the `.` reaches into an
  # instance, so it never names a tag of its own.
  defp dotted(false, _name), do: []

  defp dotted(true, name),
    do: ["`#{name}` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`"]

  defp type(type) when type in @type_atoms, do: []

  defp type(type),
    do: ["unknown type #{inspect(type)}: logex has :bool, :dint and Logex.FbType.ton()"]

  # Only a built-in function block type, exactly as Logex.FbType gives it, until M2-5. A
  # hand-built one may hold anything, and is refused, never looked up by a name that is not
  # a string.
  defp fb_type(%FbType{name: name} = type) when is_binary(name),
    do: known(FbType.builtin(name) == type, type)

  defp fb_type(type), do: known(false, type)

  # An instance of a type that is not logex's is not looked into: its members may be junk.
  defp looked_into([], tag), do: instance(tag)
  defp looked_into(_unknown, _tag), do: []

  defp known(true, _type), do: []

  defp known(false, type),
    do: ["unknown function block type #{inspect(type.name)}: logex has Logex.FbType.ton()"]

  # M1-6: an instance is the program's own state. It is not supplied from outside, and the
  # host reads none as an output, so a scan's outputs stay integers (docs/organisation.md
  # §4.6). Its preset is the operand of the instruction that runs it.
  defp instance(%Tag{section: section, name: name} = tag)
       when section in [:var_input, :var_output],
       do: [
         "#{label(name)} is a #{tag.type.name}: an instance is the program's own, declared " <>
           "with `var`, as in `var #{display(name)} #{tag.type.name}`, not with `#{section}`"
       ]

  defp instance(%Tag{initial: nil}), do: []

  defp instance(%Tag{name: name} = tag),
    do: [
      "#{label(name)} is a #{tag.type.name}: its preset is the number on its `ton` " <>
        "instruction, as in `ton #{display(name)} 5000`, so its declaration takes no initial value"
    ]

  defp display(name) when is_binary(name), do: name
  defp display(_name), do: "t1"

  defp section(section) when section in @section_atoms, do: []
  defp section(section), do: ["unknown section #{inspect(section)}"]

  # Messages name the tag with label/1, because from Elixir the name itself may be the
  # thing that is wrong.
  defp initial(%Tag{initial: nil}), do: []

  defp initial(%Tag{section: :var_input, name: name}),
    do: [
      "#{label(name)} is a var_input: its value comes from outside, so it takes no initial value"
    ]

  defp initial(%Tag{name: name, initial: v}) when not is_integer(v),
    do: ["the initial value of #{label(name)} must be an integer, found #{inspect(v)}"]

  defp initial(%Tag{type: type, name: name, initial: v}) when type in @type_atoms,
    do: fit(fits?(type, v), type, name, v)

  defp initial(_tag), do: []

  defp fit(true, _type, _name, _v), do: []

  defp fit(false, :bool, name, v),
    do: ["#{label(name)} is a bool: its initial value must be 0 or 1, found `#{v}`"]

  defp fit(false, :dint, name, v),
    do: ["#{label(name)} is a dint: `#{v}` does not fit in 32 bits"]

  defp label(name) when is_binary(name), do: "`#{name}`"
  defp label(name), do: inspect(name)

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

  defp diagnostic(line, message), do: %Diagnostic{stage: :validate, line: line, message: message}
end
