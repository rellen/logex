defmodule Logex.Declarations do
  @moduledoc """
  Declaration lines, resolved after parsing as mnemonics are (PLAN.md §6): to the parser
  `var_input start bool` is a rung of three names. A declaration is a rung whose first word
  is a section keyword, and every one comes before the first rung of logic.

      <section> <name> <type> [<initial>]     section: var | var_input | var_output
                                                       | var_external
                                              type:    bool | sint | int | dint | lint
                                                       | usint | uint | udint | ulint
                                                       | byte | word | dword | lword
                                                       | a word of
                                                       Logex.FbType.builtins/0, ton
                                                       among them | a block's name

  Since M5-11 (decision 151) a type word may carry an array's sizes, `real[8]`,
  `int[4,8]` or `bool[2,3,4]`, Logix's form, and an array's initial value is one literal
  for every element, `var limits int[3] 10 20 30`, in the elements' order, the rightmost
  subscript fastest: `check/1` refuses an array of no elementary type, of more than three
  dimensions, of a dimension of 0 or of more than 65,536 elements, an initial list of
  another length and an element's value that its type does not hold, each naming the tag
  or the element, `limits[2]`; a type word sized by a tag's name, or of an instance's type,
  `ton[4]`, which waits for arrays of instances (decision 154), is refused for its type
  word, its name's uses excused. No tag is named with brackets.

  The section and type words are data, in `@sections` and, since M5-1, the one table of
  elementary types, `table/0` (`docs/organisation.md` §4.12, "The types", decisions 144 and
  145): each type's word, kind, width, range, zero and article, which every range message,
  article, guard (`is_elementary/1`) and `fits?/2` in `lib/` reads, and the configuration
  file's type words and did-you-mean (`Logex.Configuration.Text`). Since M5-8 the table
  holds IEC's four bit strings too, `byte word dword lword` (decision 155), each a row of N
  bits whose values are 0 to 2^N - 1, of the kind `:bit_string`, with no arithmetic. A function block type's
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

  alias Logex.{Diagnostic, FbType, Parser, Tag}
  import Logex.Parser, only: [is_literal: 1]
  import Logex.Array, only: [is_array: 1]
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
  # into unsigned, nor unsigned into a signed type of its own width, nor narrowing. M5-8
  # adds IEC's four bit strings (Table 10 features 18 to 21, decision 155), each a row of N
  # bits, 0..2^N - 1, the unsigned integer IEC compares it as (§6.6.2.5.10), with no
  # arithmetic, and Figure 11's cells for them: a bool widens into each, and each into the
  # wider ones, never into an integer nor an integer into one. M5-10 adds IEC's two reals
  # (Table 10 features 10 and 11, decision 150), each of kind `:real` and no integer range,
  # its zero 0.0, and Figure 11's cells for them: `sint int usint uint` widen into both,
  # `dint` and `udint` into an `lreal` alone, and a `real` into an `lreal`.
  @table Enum.map(
           [
             {"bool", :boolean, 1, 0..1, "a", [:byte, :word, :dword, :lword]},
             {"sint", :signed, 8, -128..127, "an", [:int, :dint, :lint, :real, :lreal]},
             {"int", :signed, 16, -32_768..32_767, "an", [:dint, :lint, :real, :lreal]},
             {"dint", :signed, 32, -2_147_483_648..2_147_483_647, "a", [:lint, :lreal]},
             {"lint", :signed, 64, -9_223_372_036_854_775_808..9_223_372_036_854_775_807, "an",
              []},
             {"usint", :unsigned, 8, 0..255, "a",
              [:uint, :udint, :ulint, :int, :dint, :lint, :real, :lreal]},
             {"uint", :unsigned, 16, 0..65_535, "a",
              [:udint, :ulint, :dint, :lint, :real, :lreal]},
             {"udint", :unsigned, 32, 0..4_294_967_295, "a", [:ulint, :lint, :lreal]},
             {"ulint", :unsigned, 64, 0..18_446_744_073_709_551_615, "a", []},
             {"real", :real, 32, nil, "a", [:lreal]},
             {"lreal", :real, 64, nil, "an", []},
             {"byte", :bit_string, 8, 0..255, "a", [:word, :dword, :lword]},
             {"word", :bit_string, 16, 0..65_535, "a", [:dword, :lword]},
             {"dword", :bit_string, 32, 0..4_294_967_295, "a", [:lword]},
             {"lword", :bit_string, 64, 0..18_446_744_073_709_551_615, "an", []}
           ],
           fn {word, kind, width, range, article, widens} ->
             %{
               word: word,
               type: String.to_atom(word),
               kind: kind,
               width: width,
               range: range,
               zero: Map.get(%{real: 0.0}, kind, 0),
               article: article,
               widens: widens
             }
           end
         )

  @types Map.new(@table, &{&1.word, &1.type})
  # M5-10: the reals, `real` and `lreal`, of IEEE 754 single and double precision, held as
  # BEAM floats (Logex.Real), whose range is no integer range: a row of the table with no
  # `range`, which every guard and range message built from the table passes over.
  @reals for %{kind: :real, type: type} <- @table, do: type
  @ranged for %{range: range} = row <- @table, range != nil, do: row
  @rows Map.new(@table, &{&1.type, &1})
  @integers for %{kind: kind, type: type} <- @table, kind in [:signed, :unsigned], do: type
  @bit_strings for %{kind: :bit_string, type: type} <- @table, do: type
  # M5-8 (decision 148): the types a conversion runs between, the integers and the bit
  # strings, in the table's order.
  @convertible @integers ++ @bit_strings

  @section_atoms Map.values(@sections)
  @type_atoms Enum.map(@table, & &1.type)

  # M5-4 (decision 147): IEC's generic types that an instruction's slots take, as data, each
  # the kinds of the table's rows it holds and the words a message names it with (Ed 3
  # Figure 5): ANY_INT, the integers, and ANY_NUM, the integers and the reals, which hold
  # no row until M5-10. IEC's ANY_MAGNITUDE, which ADD's inputs are, adds TIME, which logex
  # defers (§4.12), so logex's arithmetic takes ANY_NUM. M5-8 adds two (decisions 147 and
  # 155): the bitwise instructions' slots, IEC's ANY_BIT, with the integers the
  # maintainer's "Logix-friendly" follow-up added, `:any_bitwise`, which holds a bool since
  # decision 206, as IEC's ANY_BIT holds BOOL (Ed 3 Figure 5); and the comparisons',
  # IEC's ANY_ELEMENTARY less its BOOL (Ed 3 Table 33), the numbers and the bit strings,
  # `:any_elementary`, a bit string compared as the unsigned integer IEC reads it as.
  @classes %{
    any_int: %{kinds: [:signed, :unsigned], word: "an integer"},
    any_num: %{kinds: [:signed, :unsigned, :real], word: "a number"},
    # M5-10: IEC's ANY_REAL, what `sqrt` writes (Ed 3 Figure 5, Table 28).
    any_real: %{kinds: [:real], word: "a real"},
    any_bitwise: %{
      kinds: [:boolean, :signed, :unsigned, :bit_string],
      word: "a bool, a bit string or an integer"
    },
    any_elementary: %{
      kinds: [:signed, :unsigned, :real, :bit_string],
      word: "a number or a bit string"
    }
  }
  @class_atoms Map.keys(@classes)

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
  # take `a`, and `ton` and `tof` are said as words. A word with no row takes `a`: since
  # M5-5 each typed counter and alias, said as its kind, letter by letter, then its integer
  # type's word, `a ctu_int` (decisions 158 and 163), so it needs none; since M5-6 a long
  # timer is said as its kind, so `rto_ltime` takes `an`, as `rto` does.
  # validation_test.exs holds every word of Logex.FbType.builtins/0 to its article.
  @articles Map.merge(Map.new(@table, &{&1.word, &1.article}), %{
              "ton" => "a",
              "tof" => "a",
              "tp" => "a",
              "rto" => "an",
              "rto_ltime" => "an",
              "ctu" => "a",
              "ctd" => "a",
              "ctud" => "a"
            })

  @doc """
  A type word with its indefinite article, by how the word is said (M3-2): `a ton`,
  `a tp`, `a ctud`, and `an rto`, said letter by letter. `shown` is the word as the message
  writes it, `` an `rto` `` where it quotes the mnemonic. Each of logex's own type words
  that takes `an`, and the elementary ones and the plain built-ins, has its row; any other,
  a typed counter, `a ctu_int`, or one only a type built by hand can name, takes `a`. A user block's name is never given
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

  @doc "The bit-string types, `byte word dword lword`, in the table's order (M5-8)."
  def bit_strings, do: @bit_strings

  @doc "The real types, `real` and `lreal`, in the table's order (M5-10)."
  def reals, do: @reals

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
  value a state holds costs a guard a value. A real, which has no integer range, never
  passes it: its value is checked by `Logex.Real.value?/2` (M5-10).
  """
  defmacro is_fitting(type, value) do
    @ranged
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

  @doc "An elementary type's kind: `:boolean`, `:signed`, `:unsigned` or, since M5-8, `:bit_string`."
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
  # M5-11 (decision 151): an array by its sizes and its elements' type, `an array of 8 ints`.
  def a_type(type) when is_array(type), do: Logex.Array.a_type(type)

  @doc """
  A global of `type` as a message names it, `a dint global`, and since M5-11 an array
  global by its sizes, `a global array of 8 ints`.
  """
  def a_global(type) when is_array(type),
    do: "a global " <> String.replace_prefix(a_type(type), "an ", "")

  def a_global(type), do: a_type(type) <> " global"

  @doc """
  Whether a value of the elementary type `from` widens into `to` with no word (M5-3,
  decision 147): the same type, or one of `from`'s `widens`, Ed 3 Figure 11's "i" cells, so
  that every value of `from` is one of `to`.
  """
  def widens?(type, type) when type in @type_atoms, do: true

  def widens?(from, to) when from in @type_atoms and to in @type_atoms,
    do: to in Map.fetch!(@rows, from).widens

  @doc "Whether `class` is one of IEC's generic types a slot takes, `:any_int` or `:any_num` (M5-4): a guard."
  defguard is_class(class) when class in @class_atoms

  @doc """
  Whether the elementary type `type` is one of the generic type `class`'s (M5-4, decision
  147), by its kind: an `int` is ANY_INT's and ANY_NUM's, a bool neither's.
  """
  def in_class?(type, class) when type in @type_atoms and class in @class_atoms,
    do: Map.fetch!(@rows, type).kind in Map.fetch!(@classes, class).kinds

  @doc "A generic type as a message names it, `an integer` for `:any_int` (M5-4)."
  def a_class(class) when class in @class_atoms, do: Map.fetch!(@classes, class).word

  @doc """
  The values of the generic type `class`'s integer types together, from the least of
  their ranges' firsts to the greatest of their lasts (M5-4): -2^63 to 2^64 - 1, what an
  integer literal must fit where no type is known for it, a comparison's of two literals.
  A class's bit strings hold no value its unsigned integers do not, so they add nothing.
  """
  def class_range(class) when class in @class_atoms do
    ranges = for type <- @integers, in_class?(type, class), do: range(type)
    Enum.min(Enum.map(ranges, & &1.first))..Enum.max(Enum.map(ranges, & &1.last))//1
  end

  @doc """
  The conversion that takes a value of `from` into `to`, its mnemonic, `dint_to_int`, or
  nil where logex has none (M5-3, decision 148): one for each ordered pair of two integer
  types, and none with a bool, whose conversions IEC's Tables 24 and 25 give and logex
  defers, a contact and a coil doing the work. Since M5-8 one for each ordered pair of two
  bit strings, and of a bit string and an integer type either way, `word_to_int` and
  `int_to_word`, the binary transfers of IEC's Tables 24 and 25.
  """
  def conversion(from, to) when from in @convertible and to in @convertible and from != to,
    do: "#{word(from)}_to_#{word(to)}"

  # M5-10 (decision 148): between a real and an integer type, either way, and between the
  # two reals, Ed 3 Table 23's 34; none with a bit string or a bool (§4.12, "Conversions").
  def conversion(from, to)
      when (from in @reals and to in @integers) or (from in @integers and to in @reals) or
             (from in @reals and to in @reals and from != to),
      do: "#{word(from)}_to_#{word(to)}"

  def conversion(_from, _to), do: nil

  @doc "The types a conversion runs between, the integers and then the bit strings (M5-8)."
  def convertible, do: @convertible

  # M5-8: each bit string's unsigned integer of its own width, the integer IEC compares it
  # as (Ed 3 §6.6.2.5.10), from the table: a byte's a usint.
  @unsigned_of for bits <- @bit_strings,
                   into: %{},
                   do:
                     {bits,
                      Enum.find(@integers, fn type ->
                        Map.fetch!(@rows, type).kind == :unsigned and
                          Map.fetch!(@rows, type).width == Map.fetch!(@rows, bits).width
                      end)}

  @doc """
  A bit string's unsigned integer type of its own width, `:uint` for a `:word` (M5-8): the
  integer a refusal names the conversion to, `word_to_uint`, where a bit string meets an
  instruction that takes no bit string, `add` among them.
  """
  def unsigned_of(bits) when bits in @bit_strings, do: Map.fetch!(@unsigned_of, bits)

  @doc """
  Whether a value fits a type, the rule for a value a host, a device or a force gives: an
  integer of the type's range, and since M5-10 for a real a number, integer or float, whose
  nearest value of the real is finite, its precision lost silently (decision 166).
  """
  for %{type: type, range: range} <- @ranged do
    def fits?(unquote(type), value), do: value in unquote(Macro.escape(range))
  end

  def fits?(type, value) when type in @reals, do: Logex.Real.in_range?(type, value)

  @doc """
  Whether a literal's value is one of a type's (M5-10, decision 147's literal rules): an
  integer type's, a bool's and a bit string's as `fits?/2` has it, an integer, so a real
  literal is never one; a real's an integer it holds exactly, 16777216 and never 16777217
  for a `real`, or a real literal whose nearest value is finite, which a write rounds, and
  since decision 216 not nearer 0.0 than the type's smallest normal value, so that a write
  would flush it to 0.0, `1.0e-40` in a `real`, 0.0 itself taken.
  """
  for %{type: type, range: range} <- @ranged do
    def holds?(unquote(type), value), do: value in unquote(Macro.escape(range))
  end

  def holds?(type, value) when type in @reals and is_integer(value),
    do: Logex.Real.exact?(type, value)

  def holds?(type, value) when type in @reals,
    do: Logex.Real.in_range?(type, value) and not Logex.Real.flushed?(type, value)

  @doc """
  What a message says of a literal's value that `holds?/2` refuses, after the type is
  named (M5-10): a real literal where an integer or a bit string is wanted, `` `1.5` is a
  real, and an int holds integers ``; an integer a real holds only to the nearest, ``
  `16777217` is no real's: the nearest is 16777216.0 ``; and otherwise `misfit/2`'s words.
  `shown` is the literal as written.
  """
  def literal_misfit(type, value, nil), do: literal_misfit(type, value, "it")

  def literal_misfit(type, value, shown) when type in @reals and is_integer(value),
    do: nearest_misfit(Logex.Real.in_range?(type, value), type, value, shown)

  def literal_misfit(type, value, shown) when is_float(value) and type not in @reals,
    do: "#{shown} is a real, and #{a_type(type)} #{integers_only(kind(type), type)}"

  def literal_misfit(type, value, shown) when is_float(value),
    do: real_misfit(Logex.Real.in_range?(type, value), type, shown)

  def literal_misfit(type, _value, "it"), do: misfit(type)
  def literal_misfit(type, _value, shown), do: misfit(type, shown)

  @doc """
  Whether a literal's value is one of the generic type `class`'s, where no type is known
  for it, a comparison's of two literals (M5-4): an integer within `class_range/1`, and
  since M5-10 a real literal where the class holds a real.
  """
  def class_holds?(class, value) when is_integer(value), do: value in class_range(class)

  def class_holds?(class, value) when is_float(value),
    do: :real in Map.fetch!(@classes, class).kinds

  # Decision 216: a real literal nearer 0.0 than the type's smallest normal value, which a
  # write would flush to 0.0, told so, as one past the range is told the range.
  defp real_misfit(true, type, shown),
    do:
      "#{shown} is too near 0.0 for #{a_type(type)}, whose smallest above 0.0 is " <>
        "#{Float.to_string(Logex.Real.min(type))}: it would be written as 0.0"

  defp real_misfit(false, type, "it"), do: misfit(type)
  defp real_misfit(false, type, shown), do: misfit(type, shown)

  defp nearest_misfit(true, type, value, shown),
    do:
      "#{shown} is no value of #{a_type(type)}, which holds integers exactly only to " <>
        "#{exact_to(type)}: the nearest it holds is #{trunc(Logex.Real.nearest(type, value))}.0"

  defp nearest_misfit(false, type, _value, shown), do: misfit(type, shown)

  defp exact_to(:real), do: "2^24"
  defp exact_to(:lreal), do: "2^53"

  defp integers_only(:boolean, type), do: "holds only #{values(type)}"
  defp integers_only(_integer_or_bits, _type), do: "holds only integers"

  @doc """
  What a message says of a value that does not fit a type, after the type is named, from
  the table (M5-1): `` only 0 or 1 fit, found `2` `` for a bool, and for every integer
  type its range, signed or unsigned (decision 177): `` `2147483648` is outside
  -2147483648 to 2147483647 `` for a dint, `` `-1` is outside 0 to 255 `` for a usint,
  `shown` being the value as the message shows it; with `shown` nil, the words where the
  value was named before them, `only 0 or 1 fit` and `it is outside 0 to 255`.
  """
  def misfit(type, shown \\ nil) when type in @type_atoms,
    do: misfit_of(Map.fetch!(@rows, type), shown)

  defp misfit_of(%{kind: :real} = row, nil), do: "it is #{range_words(row)}"
  defp misfit_of(%{kind: :real} = row, shown), do: "#{shown} is #{range_words(row)}"
  defp misfit_of(%{kind: :boolean} = row, nil), do: "only #{values(row)} fit"
  defp misfit_of(%{kind: :boolean} = row, shown), do: "only #{values(row)} fit, found #{shown}"
  defp misfit_of(%{range: first..last//1}, nil), do: "it is outside #{first} to #{last}"
  defp misfit_of(%{range: first..last//1}, shown), do: "#{shown} is outside #{first} to #{last}"

  # M5-10 (decision 166): a real's range, past which a number's nearest value is no finite
  # value of the type.
  defp range_words(%{type: type, article: article, word: word}),
    do:
      "beyond #{article} #{word}'s range, #{Float.to_string(-Logex.Real.max(type))} to " <>
        "#{Float.to_string(Logex.Real.max(type))}"

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

  def values(%{kind: :real, type: type}),
    do:
      "a number from #{Float.to_string(-Logex.Real.max(type))} to " <>
        "#{Float.to_string(Logex.Real.max(type))}"

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

  defp line_in([{kind, line, _value, _spelling} | _]) when kind in [:int_lit, :real_lit],
    do: line

  defp line_in([]), do: nil

  defp declare({:late, rung, late}, diagnostics, types),
    do: declare(rung, [late | diagnostics], types)

  defp declare({:rung, [{:name, line, keyword} | rest]}, diagnostics, types) do
    section = Map.fetch!(@sections, String.downcase(keyword))
    declared(shape(rest, keyword, types), section, line, diagnostics, types)
  end

  # A block's type came from `types`, which `Logex.compile/2` checked on entry, so it is
  # known by being the one given under its name, not checked again for every instance.
  # Decision 202: an initial value written other than as its plain decimal is quoted as
  # written, `16#ffff`, which the tag, a value, does not keep.
  defp declared({:ok, name, type, initial, shown}, section, line, diagnostics, types) do
    tag = %Tag{name: name, type: type, section: section, initial: initial, line: line}
    {messages, _checked} = check(tag, types, %{}, shown)
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

  # M5-11: an array whose type is one is declared with no initial list where its list is
  # refused, so its uses are checked; one whose type is none declares nothing, and its
  # uses are excused, as an unknown type's are (split/4).
  defp recovered(%Tag{type: type, name: name} = tag) when is_array(type),
    do: array_recovered(array_type(name, type), name(name), tag)

  defp recovered(_tag), do: []

  defp array_recovered([], [], tag), do: [%{tag | initial: nil}]
  defp array_recovered(_untyped, [], tag), do: [{:untyped, tag.name}]
  defp array_recovered(_typed, _bad_name, _tag), do: []

  defp recover([], tag), do: [tag]
  defp recover(_problems, _tag), do: []

  # The shape of a declaration line, before its meaning is checked.
  defp shape([], kw, _types),
    do: {:error, "`#{kw}` needs a tag name and a type, as in `#{kw} fault bool`"}

  defp shape([{:branches, _} | _], _kw, _types),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([literal | _], kw, _types) when is_literal(literal),
    do: {:error, "expected a tag name after `#{kw}`, found `#{Parser.spelling(literal)}`"}

  defp shape([{:name, _, name}], kw, types), do: {:error, short(one(name, types), name, nil, kw)}

  defp shape([{:name, _, name}, literal | _], kw, types) when is_literal(literal),
    do: {:error, short(one(name, types), name, Parser.spelling(literal), kw)}

  defp shape([{:name, _, _}, {:branches, _} | _], _kw, _types),
    do: {:error, "a declaration cannot hold a branch group"}

  defp shape([{:name, _, name}, {:name, _, word} | tail], kw, types) do
    type = declared_type(word, types)
    salvaged(typed(type, name, word, tail, {kw, types}), type, {name, kw})
  end

  # M5-11 (decision 151): a type word with sizes, `int[8]`, `real[4,8]` or `bool[2,3,4]`,
  # Logix's form (1756-PM004L pp.34-36), declares an array of that elementary type, each
  # size a literal number, judged by check/1 with every array's rule, from Elixir too; one
  # of an instance's type, `ton[4]`, waits for arrays of instances (decision 154), and one
  # sized by a tag's name, `int[n]`, is no array a program can declare. Either is refused
  # for its type word, its name's uses excused, as an unknown type's are.
  # Told from a scalar's type word by its last byte, which the clause's guard reads, so a
  # scalar's declaration costs what it did before arrays.
  defp declared_type(word, types) when binary_part(word, byte_size(word) - 1, 1) == "]",
    do: sized(Logex.Array.split(word), word, types)

  defp declared_type(word, types), do: type_of(String.downcase(word), word, types)

  defp sized(nil, word, types), do: type_word(word, types)

  defp sized({base, sizes}, word, types),
    do: array_of(type_word(base, types), Enum.map(sizes, &Logex.Array.subscript/1), {base, word})

  defp array_of(type, sizes, at) when is_elementary(type),
    do: literal_sizes(Enum.find(sizes, &match?({:tag, _}, &1)), type, sizes, at)

  defp array_of(nil, _sizes, {base, _word}), do: {:unknown, base}
  defp array_of(_instance_or_recursive, _sizes, {base, word}), do: {:of_instances, base, word}

  defp literal_sizes(nil, type, sizes, _at),
    do: {:array, type, Enum.map(sizes, fn {:literal, n} -> n end)}

  defp literal_sizes({:tag, size}, _type, _sizes, {_base, word}), do: {:sized_by_tag, word, size}

  # `var t1 ton 5 6`: the name and the type word came before the mistake (M1-6).
  defp salvaged({:error, message}, %FbType{} = type, {name, _kw}),
    do: {:error, message, %Tag{name: name, type: type, section: :var}}

  # M5-11: `var w int[2] 1 x`, an array whose initial list is broken, is still plainly an
  # array of its line's section, declared with no initial list, so its uses are checked.
  defp salvaged({:error, message}, {:array, _, _} = type, {name, kw}),
    do:
      {:error, message,
       %Tag{name: name, type: type, section: Map.fetch!(@sections, String.downcase(kw))}}

  defp salvaged(shaped, _type, _named), do: shaped

  defp typed(nil, name, type, tail, {kw, types}),
    do: untyped(String.downcase(name), name, type, tail, {kw, types})

  defp typed({:unknown, base}, name, _word, tail, {kw, types}),
    do: untyped(String.downcase(name), name, base, tail, {kw, types})

  defp typed({:of_instances, base, word}, name, _word, _tail, _kw),
    do:
      {:untyped, name,
       "`#{name}` is declared `#{word}`, an array of #{base}s: an array holds elements of an " <>
         "elementary type, a bool, an integer, a real or a bit string, and an array of " <>
         "timers, counters or function blocks is not supported yet"}

  defp typed({:sized_by_tag, word, size}, name, _word, _tail, _kw),
    do:
      {:untyped, name,
       "`#{name}` is declared `#{word}`, sized by `#{size}`: an array's sizes are literal " <>
         "numbers, as in `int[8]`, fixed when the program compiles"}

  # M5-11 (decision 151): an array's initial list, one literal for every element in the
  # elements' order, each quoted as written where it is spelled (decision 202).
  defp typed({:array, _, _} = type, name, _word, [_ | _] = tail, _kw) do
    listed(Enum.all?(tail, &is_literal/1), type, name, tail)
  end

  # M2-5: a function block never holds an instance of itself, at any depth (Ed 2 §2.5,
  # docs/organisation.md §4.3). Logex.Compiler marks the types that would. The line's name
  # is marked too, as an unknown type's is.
  defp typed({:recursive, chain}, name, _word, _tail, _kw),
    do: {:untyped, name, recursive(chain)}

  defp typed(type, name, _word, [], _kw), do: {:ok, name, type, nil, nil}
  defp typed(type, name, _word, [{:int_lit, _, v}], _kw), do: {:ok, name, type, v, nil}

  defp typed(type, name, _word, [{:int_lit, _, v, spelling}], _kw),
    do: {:ok, name, type, v, spelling}

  # M5-10: a real initial value, `var setpoint real 37.5`, quoted as written where its
  # spelling is kept.
  defp typed(type, name, _word, [{:real_lit, _, v} = literal], _kw),
    do: {:ok, name, type, v, Parser.spelling(literal)}

  defp typed(type, name, _word, [{:real_lit, _, v, spelling}], _kw),
    do: {:ok, name, type, v, spelling}

  defp typed(_type, _name, _word, [{:branches, _} | _], _kw),
    do: {:error, "a declaration cannot hold a branch group"}

  defp typed(_type, _name, _word, [literal, {:branches, _} | _], _kw) when is_literal(literal),
    do: {:error, "a declaration cannot hold a branch group"}

  defp typed(_type, name, _word, [literal, extra | _], _kw) when is_literal(literal),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  defp typed(_type, name, _word, [extra | _], _kw),
    do: {:error, "unexpected #{describe(extra)} after the declaration of `#{name}`"}

  defp listed(true, type, name, tail),
    do: {:ok, name, type, Enum.map(tail, &Parser.value/1), Enum.map(tail, &shown_literal/1)}

  defp listed(false, _type, name, tail),
    do: unlisted(Enum.find(tail, &(not is_literal(&1))), name)

  defp unlisted({:branches, _}, _name), do: {:error, "a declaration cannot hold a branch group"}

  defp unlisted(extra, name),
    do:
      {:error,
       "unexpected #{describe(extra)} in the initial list of `#{name}`: an array's initial " <>
         "list is one literal for every element"}

  defp shown_literal({:int_lit, _, _}), do: nil
  defp shown_literal(literal), do: Parser.spelling(literal)

  # The one word after a section: a type word first, since `ton` is a mnemonic too (M1-6).
  defp one(word, types), do: one_of(declared_type(word, types), word)
  defp one_of(nil, word), do: reserved(word)
  defp one_of({:recursive, _chain}, word), do: reserved(word)
  defp one_of({:unknown, _base}, word), do: reserved(word)
  defp one_of({kind, _, _}, word) when kind in [:of_instances, :sized_by_tag], do: reserved(word)
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

  # The same as the values that declare them from Elixir: an alias's is its plain word's
  # (decision 163), named once.
  defp own_type_values,
    do: own_type_words() |> Enum.map(&as_value/1) |> Enum.uniq()

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

  defp type_word?({:name, _, word}, types),
    do: declared_type(word, types) not in [nil, {:unknown, hd(String.split(word, "["))}]

  defp type_word?(_element, _types), do: false

  defp example(%FbType{name: name}), do: String.first(name) <> "1"
  defp example(type) when is_array(type), do: "temps"
  defp example(_elementary), do: "fault"

  defp describe({:name, _, word}), do: "`#{word}`"
  defp describe(literal) when is_literal(literal), do: "`#{Parser.spelling(literal)}`"

  @doc """
  M5-11 (decision 151): an array's type word, `int[8]`, as a configuration file's
  `var_global` line reads it, `{:ok, {:array, type, dims}}` for an elementary type and
  literal sizes, whatever their values, which `array_misfits/3` judges, or `:error` for
  any other: a type word with no sizes, an unknown base, sizes held in tags, or an
  instance's type.
  """
  def array_word(word) when is_binary(word), do: array_word_of(declared_type(word, %{}), word)

  defp array_word_of({:array, _, _} = type, _word), do: {:ok, type}
  defp array_word_of(_other, _word), do: :error

  @doc """
  M5-11 (decision 151): what an array named `name`, of `type` and the initial list
  `initial`, nil for none, breaks of the rules every array meets, as messages naming it: its
  dimensions and sizes, and its initial list, its length and each element's value. The
  rules a declaration line's array meets, which a configuration's global array meets too.
  """
  def array_misfits(name, {:array, _, _} = type, initial) do
    typed = array_type(name, type)

    typed ++
      judged_initial(typed, %Tag{name: name, type: type, section: :var, initial: initial}, nil)
  end

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

  # `shown` is the initial value as its declaration line wrote it, where that is not its
  # plain decimal (decision 202), and nil otherwise, and from Elixir.
  defp check(tag, types, checked, shown \\ nil)

  defp check(%Tag{type: %FbType{} = type} = tag, types, checked, _shown) do
    {known, checked} = fb_type(type, types, checked)
    {name(tag.name) ++ known ++ section(tag.section) ++ looked_into(known, tag), checked}
  end

  # M5-11 (decision 151): an array's initial list is judged once its type is one; told by
  # its clause's head, so that a scalar's check costs what it did before arrays.
  defp check(%Tag{type: {:array, _, _} = type} = tag, _types, checked, shown) do
    typed = array_type(tag.name, type)

    {name(tag.name) ++
       typed ++ section(tag.section) ++ judged_initial(typed, tag, shown) ++ external(tag),
     checked}
  end

  defp check(%Tag{} = tag, _types, checked, shown),
    do:
      {name(tag.name) ++
         type(tag.type) ++ section(tag.section) ++ initial(tag, shown) ++ external(tag), checked}

  defp name(name) when is_binary(name), do: name(reserved(name), name, Logex.Lexer.tokenize(name))
  defp name(name), do: ["#{inspect(name)} is not a tag name"]

  defp name(:mnemonic, name, _), do: ["`#{name}` is an instruction and cannot name a tag"]
  defp name(:type, name, _), do: ["`#{name}` is a type and cannot name a tag"]
  defp name(:section, name, _), do: ["`#{name}` is a keyword and cannot name a tag"]

  # M5-11: brackets name no tag either: they are kept for an element's subscripts (decision
  # 151), told by the name's last byte, which the clause's guard reads.
  defp name(nil, name, {:ok, [{:name, _, name}], _})
       when binary_part(name, byte_size(name) - 1, 1) == "]",
       do: [
         "`#{name}` cannot name a tag: brackets are kept for an element's subscripts, as in " <>
           "`temps[3]`"
       ]

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
        listed(own_type_values()) <> spelled_as(type)
    ]

  # M5-11 (decision 151): an array of an elementary type, of one to three dimensions, each
  # of 1 element or more, and of 65,536 elements in all at most (§4.12's proposal, which
  # M5-11's spike measured; provisional), each refusal naming the tag.
  defp array_type(name, {:array, type, dims}) when type in @type_atoms,
    do: dimensions(counts?(dims), name, dims)

  defp array_type(name, {:array, type, _dims}),
    do: [
      "#{label(name)} is an array whose elements are of an elementary type, as in " <>
        "{:array, :int, [8]}: logex has " <>
        listed(Enum.map(@type_atoms, &inspect/1)) <> ", found #{inspect(type)}"
    ]

  # A proper list of integers, one or more: Enum.all?/2 raises on an improper one.
  defp counts?([_ | _] = dims), do: integers?(dims)
  defp counts?(_dims), do: false

  defp integers?([n | rest]) when is_integer(n), do: integers?(rest)
  defp integers?([]), do: true
  defp integers?(_improper), do: false

  defp dimensions(false, name, dims),
    do: [
      "#{label(name)} is an array whose sizes are a list of one to three counts, as in " <>
        "{:array, :int, [4, 8]}, found #{inspect(dims)}"
    ]

  defp dimensions(true, name, dims) when length(dims) > 3,
    do: [
      "#{label(name)} is declared with #{length(dims)} dimensions, `[#{Enum.join(dims, ",")}]`: " <>
        "an array has one to three, as in `int[8]`, `int[4,8]` or `int[2,3,4]`"
    ]

  defp dimensions(true, name, dims), do: sizes(Enum.find(dims, &(&1 < 1)), name, dims)

  defp sizes(nil, name, dims), do: within_limit(Logex.Array.size(dims), name, dims)

  defp sizes(size, name, dims),
    do: [
      "#{label(name)} is declared with a dimension of #{size}, `[#{Enum.join(dims, ",")}]`: " <>
        "each dimension of an array holds 1 element or more"
    ]

  defp within_limit(size, name, dims) when size > 65_536,
    do: [
      "#{label(name)} would hold #{size} elements, `[#{Enum.join(dims, ",")}]`: an array " <>
        "holds 65536 at most"
    ]

  defp within_limit(_size, _name, _dims), do: []

  defp as_value(word) when is_map_key(@types, word), do: inspect(Map.fetch!(@types, word))
  defp as_value(word), do: "Logex.FbType.#{FbType.builtin(word).name}()"

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
  defp judged_initial([], tag, shown), do: initial(tag, shown)
  defp judged_initial(_untyped, _tag, _shown), do: []

  defp initial(%Tag{initial: nil}, _shown), do: []

  defp initial(%Tag{section: :var_input, name: name}, _shown),
    do: [
      "#{label(name)} is a var_input: its value comes from outside, so it takes no initial value"
    ]

  # M2-4: Ed 2 §2.4.3.2, p.43: "Initial values cannot be given in VAR_EXTERNAL
  # declarations." Its value is its global's, `Logex.Configuration.initial/1`'s at a start.
  defp initial(%Tag{section: :var_external, name: name}, _shown),
    do: [
      "#{label(name)} is a var_external: its value is the configuration's global of that " <>
        "name, so it takes no initial value"
    ]

  # M5-11 (decision 151): an array's initial list, one value for every element in the
  # elements' order, each judged as an initial value of its elements' type, by the
  # element's name, `limits[2]`; one of another length is refused, where IEC truncates or
  # fills with a warning (Ed 3 pp.39-40).
  defp initial(%Tag{type: {:array, _, _} = type, name: name, initial: values}, shown)
       when is_list(values),
       do: initial_list(proper_length(values), type, name, {values, shown})

  defp initial(%Tag{type: {:array, _, _} = type, name: name, initial: v}, _shown),
    do: [
      "#{label(name)} is #{a_type(type)}: its initial value is a list of its elements' " <>
        "values, found #{inspect(v, charlists: :as_lists)}"
    ]

  # M5-10: a real's initial value is a number, an integer or a float; any other type's an
  # integer, a real one refused as a real literal in its slot is (decision 147).
  defp initial(%Tag{type: type, name: name, initial: v}, _shown)
       when type in @reals and not is_number(v),
       do: ["the initial value of #{label(name)} must be a number, found #{inspect(v)}"]

  defp initial(%Tag{type: type, name: name, initial: v}, _shown)
       when type not in @reals and not is_integer(v),
       do: ["the initial value of #{label(name)} must be an integer, found #{inspect(v)}"]

  defp initial(%Tag{type: type, name: name, initial: v}, shown) when type in @type_atoms,
    do: fit(holds?(type, v), type, name, {quoted(shown, v), v})

  defp initial(_tag, _shown), do: []

  defp initial_list(-1, array, name, {values, _shown}),
    do: [
      "#{label(name)} is #{a_type(array)}: its initial value is a list of its elements' " <>
        "values, found #{inspect(values, charlists: :as_lists)}"
    ]

  defp initial_list(length, {:array, type, dims} = array, name, {values, shown}) do
    size = Logex.Array.size(dims)

    elements(
      length == size,
      {array, name, size, length},
      Enum.zip([Logex.Array.indexes(dims), values, shown_list(shown, length)]),
      type
    )
  end

  defp elements(true, {array, name, _size, _length}, elements, type),
    do:
      elements
      |> Enum.flat_map(fn {index, v, shown} ->
        tag = %Tag{type: type, name: element_name(name, index), section: :var, initial: v}
        initial(tag, shown)
      end)
      |> Logex.Array.capped(&more_misfits(array, name, &1))

  defp elements(false, {array, name, size, length}, _elements, _type),
    do: [
      "#{label(name)} is #{a_type(array)}: its initial list holds #{length} " <>
        "#{plural(length, "value")}, and an array's holds one for every element, #{size}, " <>
        "in the elements' order"
    ]

  defp more_misfits(array, name, count),
    do:
      "#{label(name)} is #{a_type(array)}: its initial list holds #{count} more " <>
        "#{plural(count, "value")} outside its type, not listed"

  defp element_name(name, index) when is_binary(name), do: Logex.Array.name(name, index)
  defp element_name(name, index), do: Logex.Array.name(inspect(name), index)

  defp shown_list(shown, _length) when is_list(shown), do: shown
  defp shown_list(_none, length), do: List.duplicate(nil, length)

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"

  defp proper_length([]), do: 0
  defp proper_length([_ | rest]), do: plus_one(proper_length(rest))
  defp proper_length(_improper), do: -1

  defp plus_one(-1), do: -1
  defp plus_one(n), do: n + 1

  defp quoted(nil, v) when is_float(v), do: "`#{Float.to_string(v)}`"
  defp quoted(nil, v), do: "`#{v}`"
  defp quoted(spelling, _v), do: "`#{spelling}`"

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

  defp fit(false, type, name, {shown, v}),
    do: ["#{label(name)} is #{a_type(type)}: #{initial_of_literal(type, v, shown)}"]

  defp initial_of_literal(type, v, shown) when is_float(v) or type in @reals,
    do: literal_misfit(type, v, shown)

  defp initial_of_literal(type, _v, shown), do: initial_misfit(type, shown)

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
