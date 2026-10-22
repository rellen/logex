defmodule Logex.Declarations do
  @moduledoc """
  Declaration lines, resolved after parsing as mnemonics are (PLAN.md §6): to the parser
  `var_input start bool` is a rung of three names. A declaration is a rung whose first word
  is a section keyword, and every one comes before the first rung of logic.

      <section> <name> <type> [<initial>]     section: var | var_input | var_output
                                                       | var_external
                                              type:    bool | sint | int | dint | lint
                                                       | usint | uint | udint | ulint
                                                       | a word of
                                                       Logex.FbType.builtins/0, ton
                                                       among them | a block's name

  The section and type words are data, in `@sections` and, since M5-1, the one table of
  elementary types, `table/0` (`docs/organisation.md` §4.12, "The types", decisions 144 and
  145): each type's word, kind, width, range, zero and article, which every range message,
  article, guard (`is_elementary/1`) and `fits?/2` in `lib/` reads, and the configuration
  file's type words and did-you-mean (`Logex.Configuration.Text`). A function block type's
  word is `Logex.FbType.builtins/0`'s: a new section or type is a row there and a stanza
  in `docs/naming.md`, not a second declaration parser. An instance of a function
  block, `var t1 ton` (M1-6) or `var s1 seal` (M2-5), is declared with `var` and takes no
  initial value. A user function block's name is a type word only where the compile is
  given that block (`Logex.compile/2`'s `types:`), and is not reserved: it is built per
  compile, not a row (PLAN.md M1-3).

  A `var_external` (M2-4) names a configuration's global, declared there again with
  `var_global` (Ed 2 §2.4.3): of an elementary type, exactly its global's (decision 159),
  with no initial value (Ed 2 §2.4.3.2) and
  no instance, and named by no configuration file's keyword
  (`Logex.Configuration.Text.keywords/0`), since its name is a global's too
  (`docs/organisation.md` §4.8). Logic reads and writes it. A function block's file
  refuses it (`Logex.Compiler`), and a program run alone keeps it as a tag of its own, at
  0, which its host cannot set (`Logex.Runtime`).
  """

  alias Logex.{Diagnostic, FbType, Tag}
  alias Logex.Configuration.Text

  @sections %{
    "var" => :var,
    "var_input" => :var_input,
    "var_output" => :var_output,
    "var_external" => :var_external
  }
  # M5-1 (docs/organisation.md §4.12, "The types", decisions 144 and 145): the one table of
  # elementary types, a row each, in the record's order: its word, its value in a tag
  # (`type`), its kind, its width in bits, its range, its zero and the article a message
  # says it with. Every range message, article, guard and fits?/2 reads it, and so do the
  # configuration file's type words. IEC 61131-3 Ed 3 Table 10: a BOOL is 0 or 1, a signed
  # integer of N bits is two's complement, -(2^(N-1))..2^(N-1) - 1 (footnote c), and an
  # unsigned one 0..2^N - 1 (footnote d). M5-3 adds IEC's seven other integer widths, and
  # since it each row's `widens`, the types Ed 3 Figure 11 (p.67) converts it into
  # implicitly, its "i" cells among the types the table holds (decision 147): never signed
  # into unsigned, nor unsigned into a signed type of its own width, nor narrowing.
  @table Enum.map(
           [
             {"bool", :boolean, 1, 0..1, "a", []},
             {"sint", :signed, 8, -128..127, "an", [:int, :dint, :lint]},
             {"int", :signed, 16, -32_768..32_767, "an", [:dint, :lint]},
             {"dint", :signed, 32, -2_147_483_648..2_147_483_647, "a", [:lint]},
             {"lint", :signed, 64, -9_223_372_036_854_775_808..9_223_372_036_854_775_807, "an",
              []},
             {"usint", :unsigned, 8, 0..255, "a", [:uint, :udint, :ulint, :int, :dint, :lint]},
             {"uint", :unsigned, 16, 0..65_535, "a", [:udint, :ulint, :dint, :lint]},
             {"udint", :unsigned, 32, 0..4_294_967_295, "a", [:ulint, :lint]},
             {"ulint", :unsigned, 64, 0..18_446_744_073_709_551_615, "a", []}
           ],
           fn {word, kind, width, range, article, widens} ->
             %{
               word: word,
               type: String.to_atom(word),
               kind: kind,
               width: width,
               range: range,
               zero: 0,
               article: article,
               widens: widens
             }
           end
         )

  @types Map.new(@table, &{&1.word, &1.type})
  @rows Map.new(@table, &{&1.type, &1})
  @integers for %{kind: kind, type: type} <- @table, kind in [:signed, :unsigned], do: type

  @section_atoms Map.values(@sections)
  @type_atoms Enum.map(@table, & &1.type)

  # A preset is a dint number of milliseconds, and never negative (docs/naming.md, `ton`).
  @preset 0..2_147_483_647

  @doc "The section and type words, lowercase. Each is reserved, in any case."
  def keywords, do: Map.keys(@sections) ++ Map.keys(@types) ++ Map.keys(FbType.builtins())

  @doc """
  The words that head a file of a kind other than a program, lowercase (M2-5), each
  surveyed like a keyword. Each is reserved in its kind of file only, in any case
  (`docs/organisation.md` §4.8): `Logex.Compiler` refuses `function_block` as a tag's name
  in a block's file and as a block's name, and takes it anywhere else as a name. A user
  block's own name is no row here, and is not reserved: it is built per compile.
  """
  def kinds, do: ["function_block"]

  @doc """
  The words a message names an instance's type with (M2-5): `a ton` for a built-in type,
  its article by `a_or_an/2` (`an rto`, M3-2), and `` an instance of `seal` `` for a user
  function block, whose name is any name, so it takes no article of its own, as `an outer`
  or `a user` would want.
  """
  def instance_of(%FbType{name: name, body: nil}), do: a_or_an(name)
  def instance_of(%FbType{name: name}), do: "an instance of `#{name}`"

  # M3-2: the article each of logex's own type words takes, by how the word is said. An
  # elementary type's is said as a word, `a bool`; a built-in function block type's is said
  # letter by letter where it is no word, so `rto`, "R-T-O", takes `an`, as `tp` and `ctud`
  # take `a`, and `ton` and `tof` are said as words. Every word of
  # Logex.FbType.builtins/0 has its row, which validation_test.exs holds it to.
  @articles Map.merge(Map.new(@table, &{&1.word, &1.article}), %{
              "ton" => "a",
              "tof" => "a",
              "tp" => "a",
              "rto" => "an",
              "ctu" => "a",
              "ctd" => "a",
              "ctud" => "a"
            })

  @doc """
  A type word with its indefinite article, by how the word is said (M3-2): `a ton`,
  `a tp`, `a ctud`, and `an rto`, said letter by letter. `shown` is the word as the message
  writes it, `` an `rto` `` where it quotes the mnemonic. Each of logex's own type words,
  the elementary ones and every word of `Logex.FbType.builtins/0`, has its row; any other,
  which only a type built by hand can name, takes `a`. A user block's name is never given
  one: `instance_of/1` names its instance's type `` an instance of `seal` ``, whatever its
  sound.
  """
  def a_or_an(word, shown \\ nil)
  def a_or_an(word, nil), do: a_or_an(word, word)
  def a_or_an(word, shown), do: "#{Map.get(@articles, word, "a")} #{shown}"

  @doc """
  What a function block type given where a program goes is told, after its name (M2-5):
  the one message of every entry point that takes a program, `Logex.Runtime`,
  `Logex.Edit.accept/3` and `Logex.Configuration`, which runs inside a program through the
  instruction that runs it, `cal` for a user block and a built-in's own mnemonic.
  """
  def not_a_program(type),
    do:
      "a function block type, which runs inside a program through `#{runner(type)}`: " <>
        "an instance is of a %Logex.Program{}"

  # M3-1: a built-in's instructions (Logex.FbType.rules/1), a ctud's two, or for a type
  # built by hand that names none, its own word.
  defp runner(%FbType{name: name, body: nil} = type) when is_binary(name),
    do: own_runners(FbType.rules(type), name)

  defp runner(_user_block), do: "cal"

  defp own_runners(%{runs: runs}, _name),
    do: runs |> Map.keys() |> Enum.sort(:desc) |> Enum.join("` and `")

  defp own_runners(nil, name), do: String.downcase(name)

  # A type word names an elementary type or a built-in function block type, in any case,
  # or a function block the compile is given, by its exact name: an entry of `types`, a
  # `%Logex.FbType{}`, or `{:recursive, chain}` for one that would hold the block being
  # compiled (Logex.Compiler).
  defp type_word(word, types), do: type_of(String.downcase(word), word, types)

  defp type_of(key, _word, _types) when is_map_key(@types, key), do: Map.fetch!(@types, key)
  defp type_of(key, word, types), do: builtin_or(FbType.builtin(key), word, types)

  defp builtin_or(nil, word, types), do: Map.get(types, word)
  defp builtin_or(builtin, _word, _types), do: builtin

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
  Whether `word` may name a user function block (M2-5): a name, spelled as a type word in
  the files that hold the block, so no reserved word, in any case, and not the word that
  heads a block's file, which is reserved in one (`docs/organisation.md` §4.8).
  """
  def block_name?(word),
    do:
      name?(word) and reserved(word) == nil and
        String.downcase(word) not in kinds()

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

  @doc """
  The elementary types, one row each of the table in `docs/organisation.md` §4.12 ("The
  types", M5-1), in its order: `word`, `type`, `kind` (`:boolean`, `:signed` or
  `:unsigned`, M5-3), `width` in bits, `range`, `zero`, `article`, and since M5-3 `widens`,
  the types Ed 3 Figure 11 converts it into implicitly (decision 147).
  """
  def table, do: @table

  @doc "The elementary types' values in a tag, `:bool`, `:sint` and the rest, in the table's order."
  def elementary, do: @type_atoms

  @doc "The elementary types' words, `bool`, `sint` and the rest, in the table's order."
  def type_words, do: Enum.map(@table, & &1.word)

  @doc "The integer types, signed and unsigned, in the table's order (M5-3)."
  def integers, do: @integers

  @typedoc "An elementary type, a row of `table/0`."
  @type elementary ::
          unquote(
            @type_atoms
            |> Enum.reverse()
            |> Enum.reduce(fn type, union -> quote(do: unquote(type) | unquote(union)) end)
          )

  @doc "Whether `type` is an elementary type, a row of `table/0`: a guard."
  defguard is_elementary(type) when type in @type_atoms

  @doc """
  A guard: whether `value` is an integer that fits the elementary type `type`, as
  `fits?/2` says, built from the table's ranges (decision 171), so that a check of every
  value a state holds costs a guard a value.
  """
  defmacro is_fitting(type, value) do
    @table
    |> Enum.map(fn %{type: atom, range: first..last//1} ->
      quote do
        unquote(type) === unquote(atom) and is_integer(unquote(value)) and
          unquote(value) >= unquote(first) and unquote(value) <= unquote(last)
      end
    end)
    |> Enum.reduce(&quote(do: unquote(&2) or unquote(&1)))
  end

  @doc "An elementary type's word, `dint` for `:dint`."
  def word(type) when type in @type_atoms, do: Map.fetch!(@rows, type).word

  @doc "An elementary type's kind: `:boolean`, `:signed` or `:unsigned`."
  def kind(type) when type in @type_atoms, do: Map.fetch!(@rows, type).kind

  @doc "An elementary type's range of values."
  def range(type) when type in @type_atoms, do: Map.fetch!(@rows, type).range

  @doc "An elementary type's width in bits, 32 for a dint: the bits a wrap keeps (M5-2)."
  def width(type) when type in @type_atoms, do: Map.fetch!(@rows, type).width

  @doc "An elementary type's value before anything sets it."
  def zero(type) when type in @type_atoms, do: Map.fetch!(@rows, type).zero

  @doc """
  A type's word with its article, as a message names it: `a dint`, the elementary types'
  from the table, and any other atom's, a member's `:clock` among them, by `a_or_an/2`.
  """
  def a_type(type) when type in @type_atoms, do: a_or_an(word(type))
  def a_type(type) when is_atom(type), do: a_or_an(to_string(type))

  @doc """
  Whether a value of the elementary type `from` widens into `to` with no word (M5-3,
  decision 147): the same type, or one of `from`'s `widens`, Ed 3 Figure 11's "i" cells, so
  that every value of `from` is one of `to`.
  """
  def widens?(type, type) when type in @type_atoms, do: true

  def widens?(from, to) when from in @type_atoms and to in @type_atoms,
    do: to in Map.fetch!(@rows, from).widens

  @doc """
  The conversion that takes a value of `from` into `to`, its mnemonic, `dint_to_int`, or
  nil where logex has none (M5-3, decision 148): one for each ordered pair of two integer
  types, and none with a bool, whose conversions IEC's Tables 24 and 25 give and logex
  defers, a contact and a coil doing the work.
  """
  def conversion(from, to) when from in @integers and to in @integers and from != to,
    do: "#{word(from)}_to_#{word(to)}"

  def conversion(_from, _to), do: nil

  @doc "Whether an integer fits a type."
  for %{type: type, range: range} <- @table do
    def fits?(unquote(type), value), do: value in unquote(Macro.escape(range))
  end

  @doc """
  What a message says of a value that does not fit a type, after the type is named, from
  the table (M5-1): `` only 0 or 1 fit, found `2` `` for a bool, `` `2147483648` does
  not fit in 32 bits `` for a signed integer, a dint's, and since M5-3 `` `-1` is outside 0
  to 255 `` for an unsigned one, a usint's, `shown` being the value as the message shows
  it; with `shown` nil, the words where the value was named before them, `only 0 or 1
  fit`, `it does not fit in 32 bits` and `it is outside 0 to 255`.
  """
  def misfit(type, shown \\ nil) when type in @type_atoms,
    do: misfit_of(Map.fetch!(@rows, type), shown)

  defp misfit_of(%{kind: :boolean} = row, nil), do: "only #{values(row)} fit"
  defp misfit_of(%{kind: :boolean} = row, shown), do: "only #{values(row)} fit, found #{shown}"
  defp misfit_of(%{kind: :signed, width: width}, nil), do: "it does not fit in #{width} bits"

  defp misfit_of(%{kind: :signed, width: width}, shown),
    do: "#{shown} does not fit in #{width} bits"

  defp misfit_of(%{kind: :unsigned, range: first..last//1}, nil),
    do: "it is outside #{first} to #{last}"

  defp misfit_of(%{kind: :unsigned, range: first..last//1}, shown),
    do: "#{shown} is outside #{first} to #{last}"

  @doc """
  What a message says of a declared initial value that does not fit a type, after the type
  is named (M5-1): `` its initial value must be 0 or 1, found `2` `` for a bool, and for an
  integer type `misfit/2`'s words.
  """
  def initial_misfit(type, shown) when type in @type_atoms,
    do: initial_of(Map.fetch!(@rows, type), type, shown)

  defp initial_of(%{kind: :boolean} = row, _type, shown),
    do: "its initial value must be #{values(row)}, found #{shown}"

  defp initial_of(_row, type, shown), do: misfit(type, shown)

  @doc """
  A type's values in words (M5-1): `0 or 1` for a bool, `an integer from -2147483648 to
  2147483647` for a dint, and so for every integer type.
  """
  def values(type) when type in @type_atoms, do: values(Map.fetch!(@rows, type))
  def values(%{kind: :boolean, range: first..last//1}), do: "#{first} or #{last}"
  def values(%{range: first..last//1}), do: "an integer from #{first} to #{last}"

  @doc """
  The elementary types each shown by `shown`, joined by commas and an `or` before the last
  (M5-1): `` :bool, :sint, … or :ulint `` with `&inspect/1`.
  """
  def either(shown), do: either_of(Enum.map(@type_atoms, shown))

  defp either_of([one]), do: one
  defp either_of(words), do: Enum.join(Enum.drop(words, -1), ", ") <> " or " <> List.last(words)

  @doc """
  Whether an integer is a preset, 0 to 2147483647 ms (M1-6): what a `ton`'s preset slot
  takes, and so where a timer's `.pre` starts. The slot is the one place a preset is
  given: `Logex.Tag.new!/4` took one too, as `%{"pre" => ms}`, until OE-1 withdrew it.
  """
  def preset?(value), do: value in @preset

  @doc """
  Splits parsed rungs into a tag table and the rungs of logic:
  `{tags, logic_rungs, diagnostics, untyped}`, the diagnostics in line order.

  `declared` are tags built in Elixir with `Logex.Tag.new!/4`. Each is checked again by
  `validate!/1` and they enter the table first; anything invalid among them, a clash
  included, raises `ArgumentError`. A function block type is checked once a call, however
  many of them hold it: one given in `types` is known by being the one given, and another
  is known once a tag before it held that very type, by value. Another is the one its
  source text compiles to (`Logex.FbType.check/2`, decision 54), and each type its table
  shares with the types checked before it is compiled again no more: `checked` is what
  `Logex.FbType.check/2` checked of the types this compile was given, `%{}` for none, and
  each tag's check adds to it. A declaration after the first rung is
  reported and still declared, so its tag is not also reported as undeclared wherever it
  is used.

  `untyped` is the `MapSet` of the names declared by a line refused for its type word
  alone (M2-5): a word that names no type this compile knows, or a function block that
  would hold the block being compiled. Such a line declares nothing, and
  `Logex.Compiler` excuses its name's uses rather than report each as undeclared: one
  mistake, one message, so a misspelled block name gives the unknown type alone. A line
  refused for anything else, such as two names before its type, `retain` or a bad
  initial value, excuses nothing.
  """
  def split(rungs, declared \\ [], types \\ %{}, checked \\ %{})

  def split(rungs, declared, types, checked) when is_list(declared) do
    {leading, rest} = Enum.split_while(rungs, &declaration?/1)
    {late, logic} = Enum.split_with(rest, &declaration?/1)
    first = first_line(logic)
    late = Enum.map(late, &late(&1, first))
    {entries, diagnostics} = Enum.flat_map_reduce(leading ++ late, [], &declare(&1, &2, types))
    {untyped, tags} = Enum.split_with(entries, &match?({:untyped, _name}, &1))
    {declared, _known} = Enum.map_reduce(declared, {types, checked}, &validate!/2)
    {table, diagnostics} = table(declared, tags, diagnostics)
    sorted = Enum.sort_by(Enum.reverse(diagnostics), & &1.line)
    {table, logic, sorted, MapSet.new(untyped, fn {:untyped, name} -> name end)}
  end

  def split(_rungs, declared, _types, _checked),
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

  # validate!/1 for split/4, given the types known and what this compile has checked: a
  # type given, or one a tag before held, is not checked again for each instance of it, and
  # a type the table of another holds, given or a tag's, is not compiled again (M2-5,
  # decision 54).
  defp validate!(%Tag{line: nil, type: %FbType{name: name} = type} = tag, {types, checked})
       when is_binary(name) do
    {messages, checked} = check(tag, types, checked)
    {validated(messages, tag), {Map.put(types, name, type), checked}}
  end

  defp validate!(tag, known), do: {validate!(tag), known}

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

  defp declare({:late, rung, late}, diagnostics, types),
    do: declare(rung, [late | diagnostics], types)

  defp declare({:rung, [{:name, line, keyword} | rest]}, diagnostics, types) do
    section = Map.fetch!(@sections, String.downcase(keyword))
    declared(shape(rest, keyword, types), section, line, diagnostics, types)
  end

  # A block's type came from `types`, which `Logex.compile/2` checked on entry, so it is
  # known by being the one given under its name, not checked again for every instance.
  defp declared({:ok, name, type, initial}, section, line, diagnostics, types) do
    tag = %Tag{name: name, type: type, section: section, initial: initial, line: line}
    {messages, _checked} = check(tag, types, %{})
    checked(messages, tag, line, diagnostics)
  end

  defp declared({:error, message}, _section, line, diagnostics, _types),
    do: {[], [diagnostic(line, message) | diagnostics]}

  # M2-5: a line whose type word names no type declares nothing, and its name is marked so
  # that its uses are excused (split/3).
  defp declared({:untyped, name, message}, _section, line, diagnostics, _types),
    do: {[{:untyped, name}], [diagnostic(line, message) | diagnostics]}

  defp declared({:error, message, tag}, _section, line, diagnostics, _types),
    do: {recovered(%{tag | line: line}), [diagnostic(line, message) | diagnostics]}

  defp checked([], tag, _line, diagnostics), do: {[tag], diagnostics}

  defp checked(messages, tag, line, diagnostics),
    do: {recovered(tag), Enum.reverse(Enum.map(messages, &diagnostic(line, &1)), diagnostics)}

  # M1-6: an instance declared in the wrong section, with an initial value, or with its
  # line broken after its type word, is still plainly an instance, so it is declared as
  # `var t1 ton` too, and its uses are not each reported as undeclared: one mistake, one
  # message. A bad name is not recovered, and any other broken line declares nothing, as a
  # broken line for a bool or a dint does, whose initial value could be any of its words.
  defp recovered(%Tag{type: %FbType{}, name: name} = tag),
    do: recover(name(name), %{tag | section: :var, initial: nil})

  defp recovered(_tag), do: []

  defp recover([], tag), do: [tag]
  defp recover(_problems, _tag), do: []

  # The shape of a declaration line, before its meaning is checked.
  defp shape([], kw, _types),
    do: {:error, "`#{kw}` needs a tag name and a type, as in `#{kw} fault bool`"}

  defp shape([{:branches, _} | _], _kw, _types),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:int_lit, _, v} | _], kw, _types),
    do: {:error, "expected a tag name after `#{kw}`, found `#{v}`"}

  defp shape([{:name, _, name}], kw, types), do: {:error, short(one(name, types), name, nil, kw)}

  defp shape([{:name, _, name}, {:int_lit, _, v} | _], kw, types),
    do: {:error, short(one(name, types), name, v, kw)}

  defp shape([{:name, _, _}, {:branches, _} | _], _kw, _types),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:name, _, name}, {:name, _, word} | tail], kw, types) do
    type = type_word(word, types)
    salvaged(typed(type, name, word, tail, {kw, types}), type, name)
  end

  # `var t1 ton 5 6`: the name and the type word came before the mistake (M1-6).
  defp salvaged({:error, message}, %FbType{} = type, name),
    do: {:error, message, %Tag{name: name, type: type, section: :var}}

  defp salvaged(shaped, _type, _name), do: shaped

  defp typed(nil, name, type, tail, {kw, types}),
    do: untyped(String.downcase(name), name, type, tail, {kw, types})

  # M2-5: a function block never holds an instance of itself, at any depth (Ed 2 §2.5,
  # docs/organisation.md §4.3). Logex.Compiler marks the types that would. The line's name
  # is marked too, as an unknown type's is.
  defp typed({:recursive, chain}, name, _word, _tail, _kw),
    do: {:untyped, name, recursive(chain)}

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
  defp one(word, types), do: one_of(type_word(word, types), word)
  defp one_of(nil, word), do: reserved(word)
  defp one_of({:recursive, _chain}, word), do: reserved(word)
  defp one_of(type, _word), do: {:type, type}

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
  defp as_in(%FbType{} = type, section, word, _kw) when section != :var,
    do: "; #{instance_of(type)} is declared with `var`, as in `var #{example(type)} #{word}`"

  defp as_in(type, _section, word, kw), do: ", as in `#{kw} #{example(type)} #{word}`"

  defp typeless([message], _name, _v, _kw), do: message

  defp typeless([], name, nil, kw),
    do: "`#{name}` needs a type, as in `#{kw} #{name} bool` or `#{kw} #{name} dint`"

  defp typeless([], name, v, _kw), do: "`#{name}` needs a type before its initial value `#{v}`"

  # IEC's RETAIN qualifier (docs/instruction-sets.md §3.2, Table 33 f3a) is not a tag name
  # here, because a tag name is never followed by a second name.
  defp untyped("retain", _name, _type, _tail, _kw),
    do:
      {:error,
       "`retain` is not supported yet: a warm restart, like a cold one, starts every tag " <>
         "at its initial value but the var_inputs whose values fit their types"}

  defp untyped(_key, name, type, tail, {kw, types}),
    do: unknown_type(Enum.any?(tail, &type_word?(&1, types)), name, type, {kw, types})

  defp unknown_type(true, name, type, {kw, _types}),
    do: {:error, "`#{kw}` declares one tag: found `#{name}` and `#{type}` before the type"}

  # M2-5: the function blocks this compile was given are named too, where it was given any,
  # with a did-you-mean among them, since a block's name is matched exactly; and the line's
  # name is marked, so that its uses are excused (split/3). M3-2: the type words are
  # logex's own, the elementary ones and each of Logex.FbType.builtins/0, and the
  # did-you-mean is among them too, `tpp` told of `tp`. None of them differs from `type`
  # only in case, since a type word is read in any case, so a case-sensitive one is a
  # block's.
  defp unknown_type(false, name, type, {_kw, types}) do
    blocks = Enum.sort(for {block, %FbType{}} <- types, do: block)

    {:untyped, name,
     "unknown type `#{type}`: logex has " <>
       listed(Enum.map(own_type_words(), &"`#{&1}`")) <>
       given(Enum.map(blocks, &"`#{&1}`")) <>
       suggest(type, own_type_words() ++ blocks, & &1, "type names")}
  end

  # logex's own type words: the elementary types in the table's order, `bool`, then the
  # signed integers and the unsigned by width (M5-3), then the built-in function block
  # types in order, so a new built-in is named where it lands.
  defp own_type_words,
    do: type_words() ++ Enum.sort(Map.keys(FbType.builtins()))

  defp listed([one]), do: one
  defp listed(words), do: Enum.join(Enum.drop(words, -1), ", ") <> " and " <> List.last(words)

  defp given([]), do: ""
  defp given([one]), do: ", and the function block #{one}"

  defp given(names), do: ", and the function blocks " <> listed(names)

  defp recursive([block, block]),
    do:
      "`#{block}` cannot hold an instance of `#{block}`: " <>
        "a function block never holds an instance of itself"

  defp recursive([block, held | _] = chain),
    do:
      "`#{block}` cannot hold an instance of `#{held}` (#{Enum.join(chain, " → ")}): " <>
        "a function block never holds an instance of itself, at any depth"

  defp type_word?({:name, _, word}, types), do: type_word(word, types) != nil
  defp type_word?(_element, _types), do: false

  defp example(%FbType{name: name}), do: String.first(name) <> "1"
  defp example(_elementary), do: "fault"

  defp describe({:name, _, word}), do: "`#{word}`"
  defp describe({:int_lit, _, v}), do: "`#{v}`"

  @doc """
  The rules a tag must meet however it is declared, as messages: the one validator for a
  declaration line and for `Logex.Tag.new!/4`.

  So it refuses, from Elixir too, what no declaration line can say (OE-1;
  `docs/organisation.md` §4.9, decisions 24 and 28): any initial value on an instance,
  whose preset is the number on the `ton` that runs it, with the message `var t1 ton 5`
  gets. A negative initial value it refused too, until a negative literal lexed (M3-3,
  decision 97): a dint's may now be negative, as `var offset dint -5` says.
  A compiled timer carries its preset as an initial value (`Logex.Compiler`), which no
  declaration may give, so this refuses it too.
  """
  def check(%Tag{} = tag) do
    {messages, _checked} = check(tag, %{}, %{})
    messages
  end

  defp check(%Tag{type: %FbType{} = type} = tag, types, checked) do
    {known, checked} = fb_type(type, types, checked)
    {name(tag.name) ++ known ++ section(tag.section) ++ looked_into(known, tag), checked}
  end

  defp check(%Tag{} = tag, _types, checked),
    do:
      {name(tag.name) ++
         type(tag.type) ++ section(tag.section) ++ initial(tag) ++ external(tag), checked}

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

  # M3-2: from Elixir, a type is an atom or a function block type's value, so each of
  # logex's type words is named as the value that declares it, and a type spelled like one,
  # `:tof` or `:Dint`, is told of it.
  defp type(type),
    do: [
      "unknown type #{inspect(type)}: logex has " <>
        listed(Enum.map(own_type_words(), &as_value/1)) <> spelled_as(type)
    ]

  defp as_value(word) when is_map_key(@types, word), do: inspect(Map.fetch!(@types, word))
  defp as_value(word), do: "Logex.FbType.#{word}()"

  defp spelled_as(type) when is_atom(type), do: spelled(Atom.to_string(type))
  defp spelled_as(type) when is_binary(type), do: spelled(type)
  defp spelled_as(_type), do: ""

  # A word that is one of logex's type words, in any case, is told of it outright, as a
  # declaration line reads it; any other, of the nearest, as suggest/4 finds it.
  defp spelled(word) do
    folded = String.downcase(word)
    word_of(Enum.find(own_type_words(), &(&1 == folded)), word)
  end

  defp word_of(nil, word), do: suggest(word, own_type_words(), &as_value/1)
  defp word_of(found, _word), do: " — did you mean `#{as_value(found)}`?"

  # A built-in function block type, exactly as Logex.FbType gives it; one this compile was
  # given, or a tag before held, by being that one, by value; or since M2-5 any user type
  # `Logex.compile/2` could have given, the one its source text compiles to
  # (`Logex.FbType.check/2`, decision 54), each type its table shares with the types this
  # compile checked before it compiled again no more. A hand-built one may hold anything,
  # and is refused, never looked up by a name that is not a string.
  defp fb_type(%FbType{name: name, body: nil} = type, _types, checked) when is_binary(name),
    do: {known(FbType.builtin(name) == type, type), checked}

  defp fb_type(%FbType{name: name} = type, types, checked) when is_binary(name),
    do: given(Map.get(types, name) == type, type, checked)

  defp fb_type(type, _types, checked), do: {known(false, type), checked}

  defp given(true, type, checked), do: {known(true, type), checked}
  defp given(false, type, checked), do: user(FbType.check(type, checked), type, checked)

  defp user({:ok, checked}, type, _checked), do: {known(true, type), checked}
  defp user(:error, type, checked), do: {known(false, type), checked}

  # An instance of a type that is not logex's is not looked into: its members may be junk.
  defp looked_into([], tag), do: instance(tag)
  defp looked_into(_unknown, _tag), do: []

  defp known(true, _type), do: []

  defp known(false, type),
    do: [
      "unknown function block type #{inspect(type.name)}: logex has the built-in types of " <>
        "Logex.FbType.builtins/0 and the types Logex.compile/2 gives for a function block's file"
    ]

  # M1-6: an instance is the program's own state. It is not supplied from outside, and the
  # host reads none as an output, so the outputs of a scan of the program's own state stay
  # integers (docs/organisation.md §4.6; Logex.Runtime says what a state kept across a
  # recompile carries). Its preset is the operand of the instruction that runs it, and
  # nothing else: OE-1 withdrew the `%{"pre" => ms}` a tag from Elixir could carry, since a
  # `ton` silently replaced it and, with none, no text could give that `.pre`.
  defp instance(%Tag{section: section, name: name} = tag)
       when section in [:var_input, :var_output, :var_external],
       do: [
         "#{label(name)} is #{instance_of(tag.type)}: an instance is the program's own, " <>
           "declared with `var`, as in `var #{display(name)} #{tag.type.name}`, not with " <>
           "`#{section}`"
       ]

  defp instance(%Tag{initial: nil}), do: []

  defp instance(%Tag{name: name, type: %FbType{body: %Logex.Program{}}} = tag),
    do: [
      "#{label(name)} is #{instance_of(tag.type)}, which takes no initial value: its " <>
        "members start where its type says"
    ]

  # M3-1: on the instruction its type's rules name, a ctud's `ctu` first.
  defp instance(%Tag{name: name, type: type} = tag) do
    {symbol, example} = preset_example(FbType.rules(type))

    [
      "#{label(name)} is #{a_or_an(tag.type.name)}: its preset is the number on its " <>
        "`#{symbol}` " <>
        "instruction, as in `#{symbol} #{display(name)} #{example}`, not an initial value on " <>
        "its declaration"
    ]
  end

  defp preset_example(%{kind: kind, runs: runs}),
    do: {runs |> Map.keys() |> Enum.max(), preset_number(kind)}

  defp preset_number(:timer), do: 5000
  defp preset_number(:counter), do: 10

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

  # M2-4: Ed 2 §2.4.3.2, p.43: "Initial values cannot be given in VAR_EXTERNAL
  # declarations." Its value is its global's, `Logex.Configuration.initial/1`'s at a start.
  defp initial(%Tag{section: :var_external, name: name}),
    do: [
      "#{label(name)} is a var_external: its value is the configuration's global of that " <>
        "name, so it takes no initial value"
    ]

  defp initial(%Tag{name: name, initial: v}) when not is_integer(v),
    do: ["the initial value of #{label(name)} must be an integer, found #{inspect(v)}"]

  defp initial(%Tag{type: type, name: name, initial: v}) when type in @type_atoms,
    do: fit(fits?(type, v), type, name, v)

  defp initial(_tag), do: []

  # M2-4: a var_external's name is a global's too, declared with `var_global` in a
  # configuration file, so a word that file reserves names none, in any case
  # (docs/organisation.md §4.8). A word reserved here too is refused by name/1 already.
  defp external(%Tag{section: :var_external, name: name}) when is_binary(name),
    do: keyword(reserved(name) == nil and String.downcase(name) in Text.keywords(), name)

  defp external(_tag), do: []

  defp keyword(false, _name), do: []

  defp keyword(true, name),
    do: [
      "`#{name}` is a keyword of a configuration file, where a var_external's global is " <>
        "declared, so it cannot name a var_external"
    ]

  defp fit(true, _type, _name, _v), do: []

  defp fit(false, type, name, v),
    do: ["#{label(name)} is #{a_type(type)}: #{initial_misfit(type, "`#{v}`")}"]

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
