defmodule Logex.BitStringTest do
  @moduledoc """
  PLAN M5-8: IEC's four bit strings, `byte word dword lword` (`docs/organisation.md`
  §4.12, decisions 147, 148, 155, 156 and 165), every rule from source through
  `Logex.compile/2`, `Logex.Runtime.call/4`, `Logex.Configuration`, `Logex.Edit` and
  `Logex.Runner`: each declared everywhere an integer is, its values 0 to 2^N - 1 and one
  past them refused in its type's words; no arithmetic, a refusal naming the conversion;
  `move` by Ed 3 Figure 11; a comparison with a bit string by value and with an integer
  tag refused naming both conversions; the 76 conversions, each a binary transfer; a `cal`
  formal and a connection widening and a `var_external` binding exactly; an edit of a
  type refused; the four type words and 76 mnemonics reserved; and a located point
  through the runner, its forces file among it.

  The ranges, Figure 11 and the binary transfer are restated here from IEC's text, Table
  10's footnote j, Figure 11's "i" cells and Tables 24 and 25's rules, never read from
  `Logex.Declarations`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Runtime, Tag}
  alias Logex.Configuration.{Global, Instance, Text}

  # IEC 61131-3 Ed 3 Table 10 features 18 to 21: each bit string's N.
  @bits [byte: 8, word: 16, dword: 32, lword: 64]
  @strings Keyword.keys(@bits)

  # The integer types, with their kind and N, for the 64 conversions between the two.
  @integers [
    sint: {:signed, 8},
    int: {:signed, 16},
    dint: {:signed, 32},
    lint: {:signed, 64},
    usint: {:unsigned, 8},
    uint: {:unsigned, 16},
    udint: {:unsigned, 32},
    ulint: {:unsigned, 64}
  ]

  # Ed 3 Figure 11 (p.67), the "i" cells into and out of the bit strings: a bool widens into
  # each, and each into the wider ones; nothing crosses to an integer.
  @figure_11 %{
    bool: [:byte, :word, :dword, :lword],
    byte: [:word, :dword, :lword],
    word: [:dword, :lword],
    dword: [:lword],
    lword: []
  }

  @articles %{lword: "an", int: "an", sint: "an", lint: "an"}

  defp width(type), do: Keyword.get(@bits, type) || elem(Keyword.fetch!(@integers, type), 1)
  defp kind(type), do: kind_of(Keyword.fetch(@integers, type))
  defp kind_of({:ok, {kind, _n}}), do: kind
  defp kind_of(:error), do: :unsigned

  defp limits(type), do: limits_of(kind(type), width(type))
  defp limits_of(:signed, n), do: {-Integer.pow(2, n - 1), Integer.pow(2, n - 1) - 1}
  defp limits_of(:unsigned, n), do: {0, Integer.pow(2, n) - 1}

  # A binary transfer, restated from Tables 24 and 25: the source's bits in its own width,
  # then the target's rightmost bits of them, a signed target reading its top bit as the
  # sign, and never a sign extension.
  defp transfer(from, to, value) do
    pattern = Integer.mod(value, Integer.pow(2, width(from)))
    low = Integer.mod(pattern, Integer.pow(2, width(to)))
    signed(kind(to), low, Integer.pow(2, width(to) - 1))
  end

  defp signed(:signed, low, half) when low >= half, do: low - 2 * half
  defp signed(_kind, low, _half), do: low

  defp widens?(type, type), do: true
  defp widens?(from, to), do: to in Map.get(@figure_11, from, [])

  defp a(type), do: "#{Map.get(@articles, type, "a")} #{type}"

  defp misfit(type, shown),
    do: "#{shown} is outside #{elem(limits(type), 0)} to #{elem(limits(type), 1)}"

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "p", types: types)
    Enum.map(diagnostics, & &1.message)
  end

  defp program(source, name \\ "p") do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  defp scan(program, inputs) do
    state = Runtime.put_inputs(program, Runtime.instance(program), inputs)
    {outputs, _state} = Runtime.scan(program, state)
    outputs
  end

  defp raised(fun) do
    error = assert_raise ArgumentError, fun
    Exception.message(error)
  end

  describe "a bit string is declared everywhere an integer is (decisions 155 and 156)" do
    test "a tag of each, in each section, takes 0 and its top and is told one past them" do
      for type <- @strings do
        {low, high} = limits(type)

        p =
          program(
            "var a #{type} #{low}\nvar b #{type} #{high}\nvar_input i #{type}\n" <>
              "var_output o #{type}\nvar_external e #{type}\nvar f bool\n" <>
              "xic f move i o\nxic f move a b\nxic f move e a"
          )

        assert Logex.Program.initial_env(p) == %{
                 "a" => 0,
                 "b" => high,
                 "i" => 0,
                 "o" => 0,
                 "e" => 0,
                 "f" => 0
               }

        assert Enum.map(Map.values(p.tags), & &1.type) -- [:bool] == List.duplicate(type, 5)

        assert messages("var c #{type} -1\nvar d #{type} #{high + 1}\nxic c ote d") == [
                 "`c` is #{a(type)}: #{misfit(type, "`-1`")}",
                 "`d` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}",
                 "`c` is not declared",
                 "`d` is not declared"
               ]

        assert messages("var c #{type}\nvar d #{type}\nxic c ote d") == [
                 "`xic` reads a bool, but `c` is #{a(type)} (declared on line 1)",
                 "`ote` writes a bool, but `d` is #{a(type)} (declared on line 2)"
               ]
      end
    end

    test "a based literal is the bit pattern it spells, quoted as written" do
      p = program("var w word 16#00ff\nvar b byte 2#1001_0001\nvar f bool\nxic f ote f")
      assert Logex.Program.initial_env(p) == %{"w" => 255, "b" => 145, "f" => 0}

      assert messages("var w word 16#1_0000\nxic w.0 ote w.1") |> hd() ==
               "`w` is a word: `16#1_0000` is outside 0 to 65535"
    end

    test "from Elixir, a tag of each is checked as a line is" do
      for type <- @strings do
        {_low, high} = limits(type)
        assert %Tag{type: ^type, initial: ^high} = Tag.new!("x", type, :var, high)

        assert raised(fn -> Tag.new!("x", type, :var, high + 1) end) ==
                 "`x` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}"

        assert raised(fn -> Tag.new!("x", type, :var, -1) end) ==
                 "`x` is #{a(type)}: #{misfit(type, "`-1`")}"

        assert %Tag{section: :var_external} = Tag.new!("x", type, :var_external)
      end
    end

    test "a host's input of each takes 0 and its top, and is refused past them or as a float" do
      for type <- @strings do
        {_low, high} = limits(type)
        p = program("var_input i #{type}\nvar_output o #{type}\nvar f bool\nxio f move i o")

        assert scan(p, %{"i" => high}) == %{"o" => high}
        assert scan(p, %{"i" => 0}) == %{"o" => 0}

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => high + 1}) end) ==
                 "input `i` is #{a(type)}: #{misfit(type, "#{high + 1}")}"

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => -1}) end) ==
                 "input `i` is #{a(type)}: #{misfit(type, "-1")}"

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => 37.5}) end) ==
                 "input `i` is #{a(type)}: its value must be an integer, found 37.5"
      end
    end

    test "a state that holds a value outside its type is the host's mistake" do
      for type <- @strings do
        {_low, high} = limits(type)
        p = program("var a #{type}\nvar f bool\nxic f move a a")

        for value <- [high + 1, -1] do
          state = %{Runtime.instance(p) | env: %{"a" => value, "f" => 0}}

          assert raised(fn -> Runtime.scan(p, state) end) ==
                   "state.env holds `a` outside its type: it is #{a(type)}, and " <>
                     misfit(type, "#{value}")
        end
      end
    end

    test "a block's member of each: a `cal` literal fits it or is told so" do
      for type <- @strings do
        {_low, high} = limits(type)

        seal =
          program(
            "function_block seal\nvar_input sp #{type}\nvar_output q #{type}\nmove sp q",
            "seal"
          )

        {:ok, outer} =
          Logex.compile("var s1 seal\nvar o #{type}\ncal s1 #{high} o", name: "p", types: [seal])

        {_outputs, state} = Runtime.scan(outer, Runtime.instance(outer))
        assert state.env["o"] == high

        assert messages("var s1 seal\nvar o #{type}\ncal s1 #{high + 1} o", [seal]) == [
                 "operand 1 of `cal s1` is `sp` (var_input #{type}): " <>
                   misfit(type, "`#{high + 1}`")
               ]
      end
    end
  end

  describe "move by Figure 11 (decision 147)" do
    test "a bool and a narrower bit string widen into a bit string, and nothing else does" do
      types = [:bool | @strings] ++ Keyword.keys(@integers)

      for from <- types, to <- types, from in [:bool | @strings] or to in @strings do
        moves(
          widens?(from, to),
          from,
          to,
          "var s #{from}\nvar d #{to}\nvar f bool\nxio f move s d"
        )
      end
    end

    defp moves(true, from, to, source) do
      {_low, high} = limits_or_bool(from)
      p = program(source)
      state = %{Runtime.instance(p) | env: %{"s" => high, "d" => 0, "f" => 0}}
      {_outputs, state} = Runtime.scan(p, state)
      assert state.env["d"] == high, inspect({from, to})
    end

    defp moves(false, from, to, source),
      do:
        assert(
          messages(source) == [
            "`move` writes `s`, #{a(from)}, into `d`, #{a(to)}: #{a(from)} does not " <>
              "widen into #{a(to)}" <> conversion(from, to)
          ],
          inspect({from, to})
        )

    defp limits_or_bool(:bool), do: {0, 1}
    defp limits_or_bool(type), do: limits(type)

    defp conversion(:bool, _to), do: ", and logex has no conversion between them"
    defp conversion(_from, :bool), do: ", and logex has no conversion between them"
    defp conversion(from, to), do: ", so convert it with `#{from}_to_#{to}`"

    test "a literal moved into each is one of its values, and told one past them" do
      for type <- @strings do
        {_low, high} = limits(type)
        p = program("var d #{type}\nvar e #{type}\nmove 0 d\nmove #{high} e")
        {_outputs, state} = Runtime.scan(p, Runtime.instance(p))
        assert {state.env["d"], state.env["e"]} == {0, high}

        assert messages("var d #{type}\nmove -1 d\nmove #{high + 1} d") == [
                 "`move` writes `-1` into `d`, #{a(type)}: #{misfit(type, "it")}",
                 "`move` writes `#{high + 1}` into `d`, #{a(type)}: #{misfit(type, "it")}"
               ]
      end
    end
  end

  describe "no arithmetic on a bit string (decision 155)" do
    # PLAN M5-8's Done-when: `add` of a `word` is a pinned refusal naming what to use, the
    # conversion through the word's own width's unsigned integer, before a read and after
    # a write.
    test "an arithmetic instruction refuses a bit string, told the conversion to use" do
      assert messages("var w word\nvar u uint\nadd w 1 u\nadd u 1 w") == [
               "`add` reads a number, but `w` is a word (declared on line 1): a word is a bit " <>
                 "string, not a number: convert it first, with `word_to_uint`",
               "`add` writes a number, but `w` is a word (declared on line 1): a word is a bit " <>
                 "string, not a number: compute in an integer and convert the result, with " <>
                 "`uint_to_word`"
             ]

      unsigned = %{byte: :usint, word: :uint, dword: :udint, lword: :ulint}

      for type <- @strings, op <- ~w(add sub mul div mod) do
        number = (op == "mod" && "an integer") || "a number"

        assert messages("var b #{type}\nvar d dint\n#{op} b 1 d") == [
                 "`#{op}` reads #{number}, but `b` is #{a(type)} (declared on line 1): " <>
                   "#{a(type)} is a bit string, not #{number}: convert it first, with " <>
                   "`#{type}_to_#{unsigned[type]}`"
               ]
      end

      for type <- @strings, op <- ~w(neg abs) do
        assert messages("var b #{type}\nvar d dint\n#{op} d b") == [
                 "`#{op}` writes a number, but `b` is #{a(type)} (declared on line 1): " <>
                   "#{a(type)} is a bit string, not a number: compute in an integer and " <>
                   "convert the result, with `#{unsigned[type]}_to_#{type}`"
               ]
      end
    end
  end

  describe "a comparison of bit strings (decision 147's note)" do
    test "a bit string compares with a bit string by value, as an unsigned integer" do
      for one <- @strings, other <- @strings do
        p =
          program(
            "var_input a #{one}\nvar_input b #{other}\nvar_output less bool\n" <>
              "var_output same bool\nlt a b ote less\neq a b ote same"
          )

        {_low, top} = limits(one)
        assert scan(p, %{"a" => top, "b" => 0}) == %{"less" => 0, "same" => 0}
        assert scan(p, %{"a" => 0, "b" => 1}) == %{"less" => 1, "same" => 0}
        assert scan(p, %{"a" => 200, "b" => 200}) == %{"less" => 0, "same" => 1}
      end
    end

    # PLAN M5-8's Done-when: `eq` of a `word` with an `int` tag is a pinned refusal naming
    # both conversions; a literal is judged in the bit string's type, so `eq drive_status
    # 16#0004` is taken.
    test "a bit string with an integer tag is refused, told both conversions" do
      assert messages(
               "var drive_status word\nvar fault_code int\nvar l bool\n" <>
                 "eq drive_status fault_code ote l\nlt fault_code drive_status ote l"
             ) == [
               "`eq` compares `drive_status`, a word (declared on line 1), with `fault_code`, " <>
                 "an int (declared on line 2): a bit string compares only with a bit string, so " <>
                 "convert one of them first, with `int_to_word` or `word_to_int`",
               "`lt` compares `fault_code`, an int (declared on line 2), with `drive_status`, " <>
                 "a word (declared on line 1): a bit string compares only with a bit string, so " <>
                 "convert one of them first, with `int_to_word` or `word_to_int`"
             ]

      for type <- @strings, {integer, _} <- @integers do
        assert [message] = messages("var b #{type}\nvar i #{integer}\nvar l bool\nge b i ote l")

        assert message =~
                 "convert one of them first, with `#{integer}_to_#{type}` or `#{type}_to_#{integer}`"
      end

      p = program("var_input drive_status word\nvar_output l bool\neq drive_status 16#0004 ote l")
      assert scan(p, %{"drive_status" => 4}) == %{"l" => 1}
      assert scan(p, %{"drive_status" => 5}) == %{"l" => 0}

      assert messages("var w word\nvar l bool\neq w 65536 ote l\neq -1 w ote l") == [
               "`eq` compares `65536` with `w`, a word (declared on line 1), which never holds " <>
                 "it: `65536` is outside 0 to 65535",
               "`eq` compares `-1` with `w`, a word (declared on line 1), which never holds " <>
                 "it: `-1` is outside 0 to 65535"
             ]

      assert messages("var b bool\nvar l bool\neq b 1 ote l") == [
               "`eq` reads a number or a bit string, but `b` is a bool (declared on line 1)"
             ]
    end
  end

  describe "the 76 bit-string conversions (decision 148)" do
    defp pairs do
      ints = Keyword.keys(@integers)

      for(from <- @strings, to <- @strings, from != to, do: {from, to}) ++
        for(from <- @strings, to <- ints, do: {from, to}) ++
        for from <- ints, to <- @strings, do: {from, to}
    end

    # Each pair over its source's limits, 0, 1, -1 where it fits, and its target's limits
    # and one past each where the source holds them, against the transfer restated.
    test "each is a binary transfer, never a sign extension, and passes its power" do
      assert length(pairs()) == 76

      for {from, to} <- pairs() do
        {low, high} = limits(from)
        {to_low, to_high} = limits(to)

        values =
          [low, high, 0, 1, -1, to_low, to_high, to_low - 1, to_high + 1, 0x1234, -0x1234]
          |> Enum.uniq()
          |> Enum.filter(&(&1 >= low and &1 <= high))

        p =
          program(
            "var_input go bool\nvar_input v #{from}\nvar_output d #{to}\nvar_output ok bool\n" <>
              "xic go #{from}_to_#{to} v d ote ok"
          )

        for value <- values do
          assert scan(p, %{"go" => 1, "v" => value}) ==
                   %{"d" => transfer(from, to, value), "ok" => 1},
                 inspect({from, to, value})
        end

        # De-energised, it writes nothing and passes no power.
        assert scan(p, %{"go" => 0, "v" => high}) == %{"d" => 0, "ok" => 0}
      end
    end

    # IEC's own cases: Table 25's Examples 1 and 2 (whose 54 is a misprint of 52, 16#34),
    # and decision 148's `int` -1 into a `dword`, 16#0000ffff.
    test "IEC's examples, and an int -1 into a dword is 16#0000ffff" do
      p =
        program(
          "var_input x sint\nvar_input w word\nvar_input i int\nvar_output wx word\n" <>
            "var_output xs sint\nvar_output d dword\nvar_output back int\nvar_output wide dint\n" <>
            "sint_to_word x wx\nword_to_sint w xs\nint_to_dword i d\nword_to_int w back\n" <>
            "word_to_dint w wide"
        )

      assert scan(p, %{"x" => 18, "w" => 0x1234, "i" => -1}) == %{
               "wx" => 0x0012,
               "xs" => 0x34,
               "d" => 0x0000_FFFF,
               "back" => 0x1234,
               "wide" => 0x1234
             }

      assert scan(p, %{"x" => -1, "w" => 0xFFFF, "i" => -32_768}) == %{
               "wx" => 0x00FF,
               "xs" => -1,
               "d" => 0x8000,
               "back" => -1,
               "wide" => 65_535
             }
    end

    # Decision 176 over the bit strings: a source of a type Figure 11 widens into `from`, a
    # bool or a narrower bit string, is taken; any other is told the conversion from its
    # own type, or `move` where that is the destination's; the destination stays exact.
    test "its source may be of a type that widens into the one it reads" do
      p =
        program(
          "var_input b bool\nvar_input y byte\nvar_output i int\nvar_output u uint\n" <>
            "word_to_int b i\ndword_to_uint y u"
        )

      assert scan(p, %{"b" => 1, "y" => 255}) == %{"i" => 1, "u" => 255}

      assert messages(
               "var w word\nvar d dword\nvar i int\nvar s sint\nbyte_to_int w i\n" <>
                 "word_to_int i i\nword_to_int w s\nint_to_word s d\nsint_to_word i w"
             ) == [
               "`byte_to_int` reads a byte, but `w` is a word (declared on line 1): use " <>
                 "`word_to_int`",
               "`word_to_int` reads a word, but `i` is an int (declared on line 3): use `move`",
               "`word_to_int` writes an int, but `s` is an sint (declared on line 4): use " <>
                 "`word_to_sint`",
               "`int_to_word` writes a word, but `d` is a dword (declared on line 2): use " <>
                 "`int_to_dword`",
               "`sint_to_word` reads an sint, but `i` is an int (declared on line 3): use " <>
                 "`int_to_word`"
             ]
    end

    test "a conversion of a literal warns that its result never changes (decision 178)" do
      for {from, to} <- pairs() do
        {:ok, p} =
          Logex.compile("var d #{to}\n#{String.upcase("#{from}_to_#{to}")} 1 d", name: "p")

        assert Enum.map(p.warnings, & &1.message) == [
                 "`#{from}_to_#{to}` reads a literal, `1`: its result never changes"
               ]
      end
    end

    test "what it passes on is settled, so anything may follow it on its path" do
      p =
        program(
          "var_input v int\nvar_output w word\nvar_output b byte\nvar_output ok bool\n" <>
            "int_to_word v w word_to_byte w b ote ok"
        )

      assert scan(p, %{"v" => -2}) == %{"w" => 65_534, "b" => 254, "ok" => 1}
    end

    # The 76 mnemonics are looked up in one map, so a program of 4x the conversions compiles
    # and scans in about 4x the reductions.
    test "a program's conversions cost linear reductions to compile and to scan" do
      rungs = fn n ->
        "var_input v int\nvar w word\nvar b byte\nvar l lint\n" <>
          String.duplicate("int_to_word v w\nword_to_byte w b\nbyte_to_lint b l\n", n)
      end

      cost = fn n ->
        source = rungs.(n)

        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            {:ok, p} = Logex.compile(source, name: "p")
            Runtime.scan(p, Runtime.put_inputs(p, Runtime.instance(p), %{"v" => -300}))
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      ratio = cost.(400) / cost.(100)
      assert ratio < 4.8, "4x the conversions took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  describe "the bitwise instructions (decisions 147, 155 and 165)" do
    # The four bit strings and the eight integer types, each a destination.
    defp computing, do: @strings ++ Keyword.keys(@integers)

    # Restated with arithmetic, not Bitwise: a value's pattern in a type's N bits, and the
    # value that pattern is in the type, two's complement where signed.
    defp pattern(type, value), do: Integer.mod(value, Integer.pow(2, width(type)))
    defp valued(type, p), do: signed(kind(type), p, Integer.pow(2, width(type) - 1))

    defp bits_of(p, n), do: for(i <- 0..(n - 1), do: rem(div(p, Integer.pow(2, i)), 2))

    defp of_bits(bits),
      do:
        bits
        |> Enum.with_index()
        |> Enum.map(fn {b, i} -> b * Integer.pow(2, i) end)
        |> Enum.sum()

    defp both(:and, a, b), do: a * b
    defp both(:or, a, b), do: max(a, b)
    defp both(:xor, a, b), do: rem(a + b, 2)

    defp combined(op, type, a, b) do
      n = width(type)

      valued(
        type,
        of_bits(
          Enum.zip_with(
            bits_of(pattern(type, a), n),
            bits_of(pattern(type, b), n),
            &both(op, &1, &2)
          )
        )
      )
    end

    defp inverted(type, a),
      do: valued(type, of_bits(Enum.map(bits_of(pattern(type, a), width(type)), &(1 - &1))))

    # Decision 165 restated: a negative count leaves the source with no power; a shift of
    # the width or more, 0; a rotate by its count modulo the width.
    defp moved(_op, _type, a, n) when n < 0, do: {a, 0}

    defp moved(op, type, a, n) do
      w = width(type)
      p = pattern(type, a)
      {valued(type, moved_pattern(op, p, n, w)), 1}
    end

    defp moved_pattern(op, _p, n, w) when op in [:shl, :shr] and n >= w, do: 0
    defp moved_pattern(:shl, p, n, w), do: Integer.mod(p * Integer.pow(2, n), Integer.pow(2, w))
    defp moved_pattern(:shr, p, n, _w), do: div(p, Integer.pow(2, n))

    defp moved_pattern(:rol, p, n, w) do
      r = Integer.mod(n, w)
      Integer.mod(p * Integer.pow(2, r) + div(p, Integer.pow(2, w - r)), Integer.pow(2, w))
    end

    defp moved_pattern(:ror, p, n, w) do
      r = Integer.mod(n, w)
      div(p, Integer.pow(2, r)) + Integer.mod(p, Integer.pow(2, r)) * Integer.pow(2, w - r)
    end

    defp samples(type) do
      {low, high} = limits(type)
      Enum.uniq([low, high, 0, 1, -1 |> max(low), div(high, 3), low + 5, high - 2])
    end

    test "and, or and xor compute each bit in the destination's type, and pass their power" do
      for type <- computing(), op <- [:and, :or, :xor] do
        p =
          program(
            "var_input go bool\nvar_input a #{type}\nvar_input b #{type}\n" <>
              "var_output d #{type}\nvar_output ok bool\nxic go #{op} a b d ote ok"
          )

        for a <- samples(type), b <- samples(type) do
          assert scan(p, %{"go" => 1, "a" => a, "b" => b}) ==
                   %{"d" => combined(op, type, a, b), "ok" => 1},
                 inspect({op, type, a, b})
        end

        assert scan(p, %{"go" => 0, "a" => 1, "b" => 1}) == %{"d" => 0, "ok" => 0}
      end
    end

    test "not inverts each bit in the destination's type" do
      for type <- computing() do
        p =
          program(
            "var_input go bool\nvar_input a #{type}\nvar_output d #{type}\n" <>
              "var_output ok bool\nxic go not a d ote ok"
          )

        for a <- samples(type),
            do: assert(scan(p, %{"go" => 1, "a" => a}) == %{"d" => inverted(type, a), "ok" => 1})

        assert scan(p, %{"go" => 0, "a" => 1}) == %{"d" => 0, "ok" => 0}
      end

      p =
        program(
          "var_input a byte\nvar_input i int\nvar_output b byte\nvar_output j int\nnot a b\nnot i j"
        )

      assert scan(p, %{"a" => 0b0000_1111, "i" => 0}) == %{"b" => 0b1111_0000, "j" => -1}
    end

    test "a shift or rotate moves the destination's bits by its count, decision 165's rules at every count" do
      for type <- computing(), op <- [:shl, :shr, :rol, :ror] do
        p =
          program(
            "var_input go bool\nvar_input a #{type}\nvar_input n lint\n" <>
              "var_output d #{type}\nvar_output ok bool\nxic go #{op} a n d ote ok"
          )

        w = width(type)

        for a <- samples(type), n <- Enum.uniq([-1, -w, 0, 1, 3, w - 1, w, w + 1, 2 * w + 3]) do
          {d, ok} = moved(op, type, a, n)

          assert scan(p, %{"go" => 1, "a" => a, "n" => n}) == %{"d" => d, "ok" => ok},
                 inspect({op, type, a, n})
        end

        assert scan(p, %{"go" => 0, "a" => 1, "n" => 1}) == %{"d" => 0, "ok" => 0}
      end
    end

    # PLAN M5-8's Done-when, each a rule a test fails without: the count read as its
    # value, the power passed or not, and no fault.
    test "the Done-when's shifts and rotates" do
      run = fn text, inputs ->
        {:ok, p} = Logex.compile(text, name: "p")
        state = Runtime.put_inputs(p, Runtime.instance(p), inputs)
        {outputs, state} = Runtime.scan(p, state)
        {outputs, state.faults}
      end

      # `shr` of an int -2 by 1 gives 32767: zero fill, not a sign extension.
      assert run.("var_input i int\nvar_output o int\nvar_output ok bool\nshr i 1 o ote ok", %{
               "i" => -2
             }) ==
               {%{"o" => 32_767, "ok" => 1}, []}

      # `rol` of a byte 2#1001_0001 by 1 gives 2#0010_0011, and by 9 the same.
      assert run.(
               "var_input b byte\nvar_output o byte\nvar_output p byte\nrol b 1 o\nrol b 9 p",
               %{"b" => 0b1001_0001}
             ) == {%{"o" => 0b0010_0011, "p" => 0b0010_0011}, []}

      # A shift by the width gives 0.
      assert run.(
               "var_input b byte\nvar_output o byte\nvar_output p byte\nshl b 8 o\nshr b 8 p",
               %{"b" => 255}
             ) ==
               {%{"o" => 0, "p" => 0}, []}

      shl =
        "var_input w word\nvar_input n int\nvar_output o word\nvar_output ok bool\nshl w n o ote ok"

      # `shl` of a word 16#00ff by an int tag at -1 writes 16#00ff with no power and no
      # fault; by 16 and by 40, 0 with its power in.
      assert run.(shl, %{"w" => 0x00FF, "n" => -1}) == {%{"o" => 0x00FF, "ok" => 0}, []}
      assert run.(shl, %{"w" => 0x00FF, "n" => 16}) == {%{"o" => 0, "ok" => 1}, []}
      assert run.(shl, %{"w" => 0x00FF, "n" => 40}) == {%{"o" => 0, "ok" => 1}, []}

      # `ror` by an int tag at -3 writes its source with no power.
      assert run.(
               "var_input w word\nvar_input n int\nvar_output o word\nvar_output ok bool\nror w n o ote ok",
               %{"w" => 0x0019, "n" => -3}
             ) == {%{"o" => 0x0019, "ok" => 0}, []}

      # A count far past the width shifts everything out and rotates by its remainder,
      # without shifting by the count itself.
      top = Integer.pow(2, 63) - 1

      assert run.(
               "var_input b byte\nvar_input n lint\nvar_output o byte\nvar_output p byte\n" <>
                 "shl b n o\nrol b n p",
               %{"b" => 1, "n" => top}
             ) == {%{"o" => 0, "p" => 0b1000_0000}, []}

      # A member is a destination too, in its own type: a timer's `.pre`, a dint.
      assert run.(
               "var_input v dint\nvar t1 ton\nvar_input go bool\nvar_output p dint\n" <>
                 "xic go or v 16#0f00 t1.pre\nxic go ton t1 5\nmove t1.pre p",
               %{"v" => 1, "go" => 1}
             ) == {%{"p" => 0x0F01}, []}

      # IEC's own examples, Table 30, of a byte 2#0001_1001 by 3.
      assert run.(
               "var_input b byte\nvar_output l byte\nvar_output r byte\nvar_output x byte\n" <>
                 "var_output y byte\nshl b 3 l\nshr b 3 r\nrol b 3 x\nror b 3 y",
               %{"b" => 0b0001_1001}
             ) ==
               {%{"l" => 0b1100_1000, "r" => 0b0000_0011, "x" => 0b1100_1000, "y" => 0b0010_0011},
                []}

      # A negative literal count is refused when the program compiles, as written.
      assert messages("var w word\nshl w -1 w\nrol w -1_0 w") == [
               "`shl` shifts by the literal `-1`: a count is never negative, so a negative " <>
                 "literal one is refused",
               "`rol` shifts by the literal `-1_0`: a count is never negative, so a negative " <>
                 "literal one is refused"
             ]
    end

    test "every width's top bit is read and written in two's complement" do
      for {type, {:signed, n}} <- @integers do
        {low, high} = limits(type)

        p =
          program(
            "var_input a #{type}\nvar_output top #{type}\nvar_output down #{type}\n" <>
              "var_output flipped #{type}\nvar_output masked #{type}\nshl a #{n - 1} top\n" <>
              "shr a #{n - 1} down\nnot a flipped\nand a #{high} masked"
          )

        assert scan(p, %{"a" => 1}) == %{
                 "top" => low,
                 "down" => 0,
                 "flipped" => -2,
                 "masked" => 1
               }

        assert scan(p, %{"a" => -1}) == %{
                 "top" => low,
                 "down" => 1,
                 "flipped" => 0,
                 "masked" => high
               }

        assert scan(p, %{"a" => low}) == %{
                 "top" => 0,
                 "down" => 1,
                 "flipped" => high,
                 "masked" => 0
               }
      end
    end

    # PLAN M5-8's Done-when: `and` of a word with an int destination is a pinned refusal
    # naming what to use. Every source is of the destination's kind, widening into its type
    # by Figure 11; a literal must be one of its values.
    test "a source of the other kind, or one that does not widen, is refused naming its conversion" do
      assert messages("var drive_status word\nvar speed int\nand drive_status 16#00ff speed") == [
               "`and` computes in `speed`'s type, an int, but `drive_status` is a word " <>
                 "(declared on line 1): a word does not widen into an int, so convert it " <>
                 "first, with `word_to_int`"
             ]

      assert messages("var w word\nvar i int\nvar d dword\nor i 1 w\nxor d 1 w\nnot i w") == [
               "`or` computes in `w`'s type, a word, but `i` is an int (declared on line 2): an " <>
                 "int does not widen into a word, so convert it first, with `int_to_word`",
               "`xor` computes in `w`'s type, a word, but `d` is a dword (declared on line 3): " <>
                 "a dword does not widen into a word, so convert it first, with `dword_to_word`",
               "`not` computes in `w`'s type, a word, but `i` is an int (declared on line 2): " <>
                 "an int does not widen into a word, so convert it first, with `int_to_word`"
             ]

      assert messages("var w word\nvar b bool\nand w 65536 w\nand w b w\nand w w b") == [
               "`and` computes in `w`'s type, a word: `65536` is outside 0 to 65535",
               "`and` reads a bit string or an integer, but `b` is a bool (declared on line 2)",
               "`and` writes a bit string or an integer, but `b` is a bool (declared on line 2)"
             ]

      # The count is an integer of any width, held to no other operand; a bit string is
      # told its conversion.
      p = program("var_input w byte\nvar_input n ulint\nvar_output o byte\nshl w n o")
      assert scan(p, %{"w" => 1, "n" => 3}) == %{"o" => 8}

      assert messages("var w word\nvar n word\nshl w n w") == [
               "`shl` reads an integer, but `n` is a word (declared on line 2): a word is a " <>
                 "bit string, not an integer: convert it first, with `word_to_uint`"
             ]

      p =
        program(
          "var_input y byte\nvar_input s sint\nvar_output w word\nvar_output i int\n" <>
            "or y 16#0100 w\nand s -1 i"
        )

      assert scan(p, %{"y" => 0xFF, "s" => -128}) == %{"w" => 0x01FF, "i" => -128}
    end

    test "anything may follow one on its path, and a literal source is warned of" do
      p =
        program(
          "var_input a word\nvar_output b word\nvar_output c word\nvar_output ok bool\n" <>
            "and a 16#00ff b shr b 4 c ote ok"
        )

      assert scan(p, %{"a" => 0x1234}) == %{"b" => 0x34, "c" => 0x3, "ok" => 1}

      {:ok, p} =
        Logex.compile(
          "var m byte\nand 16#0f 3 m\nor 1 2 m\nxor 1 1 m\nnot 0 m\nshl 1 3 m\nshr 8 1 m\n" <>
            "rol 1 1 m\nror 1 1 m\nand m 1 m",
          name: "p"
        )

      assert Enum.map(p.warnings, &{&1.line, &1.message}) == [
               {2, "`and` reads two literals, `16#0f` and `3`: its result never changes"},
               {3, "`or` reads two literals, `1` and `2`: its result never changes"},
               {4, "`xor` reads two literals, `1` and `1`: its result never changes"},
               {5, "`not` reads a literal, `0`: its result never changes"},
               {6, "`shl` reads two literals, `1` and `3`: its result never changes"},
               {7, "`shr` reads two literals, `8` and `1`: its result never changes"},
               {8, "`rol` reads two literals, `1` and `1`: its result never changes"},
               {9, "`ror` reads two literals, `1` and `1`: its result never changes"}
             ]
    end

    # Decision 182 for a bitwise destination: a program edited by hand whose destination
    # has no integer or bit-string type is refused where it is handed in, a line each.
    test "a program edited by hand whose bitwise destination is no integer nor bit string is refused" do
      {:ok, p} = Logex.compile("var w word\nvar b bool\nxic b and w 1 w", name: "p")
      broken = %{p | tags: Map.put(p.tags, "w", %{p.tags["w"] | type: :bool})}

      assert raised(fn -> Runtime.instance(broken) end) ==
               "`p`'s `and` on line 3 computes in the type of `w`, a bool, which is no integer or " <>
                 "bit-string type: `p` was edited by hand after it compiled"
    end

    test "each of the eight words names no tag, label or global's tag, in any case" do
      for word <- ~w(and or xor not shl shr rol ror), shown <- [word, String.upcase(word)] do
        assert hd(messages("var #{shown} bool\nxic #{shown} ote #{shown}")) ==
                 "`#{shown}` is an instruction and cannot name a tag"
      end
    end

    # The destination's type is found in the routine's table with one guard for a bit
    # string as for an integer, so an `and` into a word costs what one into a uint does.
    test "a bitwise instruction into a bit string costs what one into an integer does" do
      cost = fn type ->
        {:ok, p} =
          Logex.compile(
            "var_input v #{type}\nvar d #{type}\n" <> String.duplicate("and v 3 d\n", 400),
            name: "p"
          )

        state = Runtime.put_inputs(p, Runtime.instance(p), %{"v" => 5})

        Enum.min(
          for _ <- 1..5 do
            {:reductions, before} = Process.info(self(), :reductions)
            Runtime.scan(p, state)
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      ratio = cost.(:word) / cost.(:uint)
      assert ratio < 1.05, "a word destination took #{Float.round(ratio, 2)}x a uint's reductions"
    end

    # One map lookup an instruction and one clause, so a program of 4x the bitwise
    # instructions compiles and scans in about 4x the reductions.
    test "a program's bitwise instructions cost linear reductions to compile and to scan" do
      rungs = fn n ->
        "var_input v word\nvar_input k int\nvar w word\nvar i int\n" <>
          String.duplicate("and v 16#0f0f w\nshl w k w\nnot w w\nror k 3 i\n", n)
      end

      cost = fn n ->
        source = rungs.(n)

        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            {:ok, p} = Logex.compile(source, name: "p")

            Runtime.scan(
              p,
              Runtime.put_inputs(p, Runtime.instance(p), %{"v" => 0x1234, "k" => 3})
            )

            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      ratio = cost.(400) / cost.(100)
      assert ratio < 4.8, "4x the instructions took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  describe "a cal formal and a connection widen, a var_external binds exactly (decision 159)" do
    test "a `cal` operand widens into the var_input it fills, and the var_output into its tag" do
      seal =
        program("function_block seal\nvar_input sp word\nvar_output q word\nmove sp q", "seal")

      {:ok, outer} =
        Logex.compile(
          "var_input b byte\nvar s1 seal\nvar_output o dword\ncal s1 b o",
          name: "p",
          types: [seal]
        )

      assert scan(outer, %{"b" => 255}) == %{"o" => 255}

      assert messages("var s1 seal\nvar i uint\nvar y byte\ncal s1 i y", [seal]) == [
               "operand 1 of `cal s1` is `sp` (var_input word), but `i` is a uint: a uint " <>
                 "does not widen into a word, so convert it with `uint_to_word`",
               "operand 2 of `cal s1` is `q` (var_output word), but `y` is a byte: a word " <>
                 "does not widen into a byte, so convert it with `word_to_byte`"
             ]
    end

    defp fan do
      program(
        "var_input status word\nvar_output shown word\nvar_external flags word\nvar f bool\n" <>
          "xio f move status shown\nxio f move status flags",
        "fan"
      )
    end

    defp configured(text) do
      case Configuration.compile("plant", text, %{"fan" => fan()}) do
        {:ok, configuration} -> {:ok, configuration}
        {:error, diagnostics} -> Enum.map(diagnostics, & &1.message)
      end
    end

    test "a connection's copy-in and copy-out widen, and a var_external is exactly its global" do
      assert {:ok, config} =
               configured(
                 "var_global status byte at drive.i.0\nvar_global shown dword\n" <>
                   "var_global flags word\nprogram f1 fan\nf1.status status\nf1.shown shown"
               )

      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(config), 0, %{"status" => 255})
      assert Runtime.get(runtime, "shown") == {:ok, 255}
      assert Runtime.get(runtime, "flags") == {:ok, 255}

      assert configured(
               "var_global status uint\nvar_global shown byte\nvar_global flags uint\n" <>
                 "program f1 fan\nf1.status status\nf1.shown shown"
             ) == [
               "`fan` declares `var_external flags word` on its line 3, but `flags` is a " <>
                 "uint (line 3): a var_external is its global, so its type is exactly the " <>
                 "global's, never widened",
               "`f1.status` is a word, but `status` is a uint (line 1): a uint does not widen " <>
                 "into a word, and a connection converts nothing: convert it inside the " <>
                 "program, with `uint_to_word`",
               "`f1.shown` is a word, but `shown` is a byte (line 2): a word does not widen " <>
                 "into a byte, and a connection converts nothing: convert it inside the " <>
                 "program, with `word_to_byte`"
             ]
    end

    test "a global of each, its initial value at its limits, located, printed back" do
      for type <- @strings do
        {_low, high} = limits(type)

        sink =
          program("var_input a #{type}\nvar_output o #{type}\nvar f bool\nxio f move a o", "m")

        text =
          "var_global lo #{type} 0\nvar_global hi #{type} #{high}\n" <>
            "var_global pt #{type} at card.i.0\nprogram m1 m\nm1.a pt\nm1.o lo\n"

        assert {:ok, config} = Configuration.compile("plant", text, %{"m" => sink})
        assert Text.print(config) == text
        runtime = Runtime.start(config)
        assert Runtime.get(runtime, "hi") == {:ok, high}

        assert {:error, diagnostics} =
                 Configuration.compile(
                   "plant",
                   "var_global x #{type} #{high + 1}\nprogram m1 m\nm1.a x\nm1.o x\n",
                   %{"m" => sink}
                 )

        assert hd(diagnostics).message == "`x` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}"

        assert %Configuration{} =
                 Configuration.new!(
                   name: "plant",
                   programs: [sink],
                   globals: [
                     %Global{name: "pt", type: type, at: "card.i.0"},
                     %Global{name: "lo", type: type, initial: high}
                   ],
                   instances: [%Instance{name: "m1", type: "m"}],
                   connections: [
                     %Configuration.Connection{instance: "m1", member: "a", to: "pt"},
                     %Configuration.Connection{instance: "m1", member: "o", to: "lo"}
                   ]
                 )

        {runtime, _outputs, _events} = Runtime.cycle(runtime, 0, %{"pt" => high})
        assert Runtime.get(runtime, "lo") == {:ok, high}

        assert raised(fn -> Runtime.cycle(runtime, 0, %{"pt" => high + 1}) end) ==
                 "input `pt` is #{a(type)}: #{misfit(type, "#{high + 1}")}"

        assert raised(fn -> Runtime.cycle(runtime, 0, %{"pt" => -1}) end) ==
                 "input `pt` is #{a(type)}: #{misfit(type, "-1")}"
      end
    end
  end

  describe "an online edit (decision 157)" do
    test "a bit string's type changed is refused at its line, and a changed initial value reported" do
      was = program("var b word 3\nvar q bool\nxic q ote q")
      now = program("var q bool\nvar b uint 3\nxic q ote q")

      assert {:error, [%{line: 2, message: message}]} =
               Edit.accept(was, now, Runtime.instance(was))

      assert message ==
               "`b` is a word in the running program and a uint in the candidate: a tag's " <>
                 "type changes only with a restart"

      for type <- @strings do
        {_low, high} = limits(type)
        was = program("var b #{type} 0\nvar q bool\nxic q ote q")
        now = program("var b #{type} #{high}\nvar q bool\nxic q ote q")
        assert {:ok, _edit, report} = Edit.accept(was, now, Runtime.instance(was))
        assert {:initial_changed, "b", {0, high}} in report
      end
    end
  end

  describe "the reserved words" do
    # PLAN M5-8: the commit names what `byte` and `word` break: a program with a tag of
    # either name stops compiling, told it is a type.
    test "each of the four type words names no tag or global, and the 76 conversions no tag or label, in any case" do
      for word <- ~w(byte word dword lword), shown <- [word, String.upcase(word)] do
        assert messages("var #{shown} bool\nxic #{shown} ote #{shown}") |> hd() ==
                 "`#{shown}` is a type and cannot name a tag"

        assert {:error, [%{message: global} | _]} =
                 Configuration.compile("plant", "var_global #{shown} bool\n", %{})

        assert global =~ "`#{shown}`"
      end

      for {from, to} <- pairs(),
          word = "#{from}_to_#{to}",
          shown <- [word, String.upcase(word)] do
        assert hd(messages("var #{shown} bool\nxic #{shown} ote #{shown}")) ==
                 "`#{shown}` is an instruction and cannot name a tag"

        assert hd(messages("var b bool\nxic b jmp #{shown}\nlbl #{shown} ote b")) =~
                 "`#{shown}`"
      end
    end
  end

  describe "a word point through the runner (decision 156)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    # One input point of each bit string on the card, `card.i.0` to `card.i.3`, each moved
    # into a global of its own type on a 10 ms task.
    defp card do
      inputs = Enum.map_join(@strings, &"var_input i_#{&1} #{&1}\n")
      outputs = Enum.map_join(@strings, &"var_output o_#{&1} #{&1}\n")
      moves = Enum.map_join(@strings, &"move i_#{&1} o_#{&1}\n")
      copy = program(inputs <> outputs <> moves, "copy")

      globals =
        @strings
        |> Enum.with_index()
        |> Enum.map_join(fn {type, n} ->
          "var_global p_#{type} #{type} at card.i.#{n}\nvar_global g_#{type} #{type}\n"
        end)

      wires = Enum.map_join(@strings, &"  c.i_#{&1} p_#{&1}\n  c.o_#{&1} g_#{&1}\n")

      {:ok, config} =
        Configuration.compile(
          "plant",
          "task fast interval 10 priority 1\n" <> globals <> "program c copy with fast\n" <> wires,
          %{"copy" => copy}
        )

      config
    end

    defp run_card(file) do
      {:ok, clock} = Manual.start_link()
      {:ok, sim} = Sim.start_link(clock: clock)

      started =
        Runner.start_link(
          configuration: card(),
          io: %{"card" => {Sim, sim: sim}},
          clock: {Manual, clock},
          forces: file
        )

      {started, clock, sim}
    end

    # PLAN M5-8's Done-when: 65,536, -1 and a float for a word point are bad values from
    # the device, each tripping the runner (decision 114).
    test "each one's values are read from the device, and one past them, -1 or a float trips the runner",
         %{tmp_dir: dir} do
      for {type, n} <- Enum.with_index(@strings), bad <- [:past, :negative, :float] do
        {{:ok, runner}, clock, sim} = run_card(Path.join(dir, "forces"))
        {_low, high} = limits(type)
        Sim.set(sim, [n], high)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "g_#{type}") == high

        value = bad_value(bad, high)
        bad_read(bad, sim, n, value)
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == {:io, "card", {:bad_value, [n], value}}
        Runner.stop(runner)
      end
    end

    defp bad_value(:past, high), do: high + 1
    defp bad_value(:negative, _high), do: -1
    defp bad_value(:float, _high), do: 37.5

    defp bad_read(:float, sim, n, value), do: Sim.fail(sim, :read, {:value, [n], value})
    defp bad_read(_integer, sim, n, value), do: Sim.set(sim, [n], value)

    test "a force of each is held to its values, and the forces file reads back exactly",
         %{tmp_dir: dir} do
      file = Path.join(dir, "forces")
      {{:ok, runner}, clock, sim} = run_card(file)

      for type <- @strings do
        {_low, high} = limits(type)

        for value <- [high + 1, -1, 1.5] do
          assert raised(fn -> Runner.force(runner, "p_#{type}", value) end) ==
                   "`p_#{type}` is #{a(type)}, forced to an integer from 0 to #{high}, " <>
                     "got: #{value}"
        end

        assert :ok = Runner.force(runner, "p_#{type}", high)
      end

      Manual.advance(clock, 10)
      for type <- @strings, do: assert(Runner.get!(runner, "g_#{type}") == elem(limits(type), 1))

      written = File.read!(file)

      assert written ==
               @strings
               |> Enum.map(&"p_#{&1} #{elem(limits(&1), 1)}\n")
               |> Enum.sort()
               |> Enum.join()

      assert written =~ "p_word 65535\n"

      # Across a restart: a bad value trips the runner, which restarts with every force on.
      Sim.set(sim, [0], 256)
      Manual.advance(clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      Sim.set(sim, [0], 0)
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "g_word") == 65_535
      assert Runner.status(runner).forces["p_word"] == 65_535
      Runner.stop(runner)

      # A fresh start reads every force back, each its type's top.
      {{:ok, runner}, clock, _sim} = run_card(file)
      Manual.advance(clock, 10)
      for type <- @strings, do: assert(Runner.get!(runner, "g_#{type}") == elem(limits(type), 1))
      Runner.stop(runner)

      # A file whose force does not fit its point refuses the start, in its words.
      File.write!(file, "p_byte 256\np_word -1\n")

      assert raised(fn -> run_card(file) end) ==
               "#{file}: line 1: `p_byte` is a byte, forced to an integer from 0 to 255, " <>
                 "got: 256\n" <>
                 "#{file}: line 2: `p_word` is a word, forced to an integer from 0 to 65535, " <>
                 "got: -1"
    end
  end
end
