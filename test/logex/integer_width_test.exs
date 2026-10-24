defmodule Logex.IntegerWidthTest do
  @moduledoc """
  PLAN M5-3: IEC's eight integer widths (`docs/organisation.md` §4.12, decisions 144, 145,
  147, 148, 156, 157 and 159), every rule from source through `Logex.compile/2`,
  `Logex.Runtime.call/4`, `Logex.Configuration`, `Logex.Edit` and `Logex.Runner`: each
  width declared everywhere a dint is, its limits taken and one past them refused in its
  type's words; `move` and every literal by Ed 3 Figure 11, a refusal naming its
  conversion; the 56 conversions, each wrapping where its value does not fit, with no
  power; a `cal` formal and a connection widening and a `var_external` binding exactly; an
  edit of a width refused and a changed initial value of each width reported; and the
  seven type words and 56 mnemonics reserved.

  The ranges, Figure 11 and the wrap are restated here from IEC's text, Table 10's
  footnotes c and d and Figure 11's "i" cells, never read from `Logex.Declarations`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Runtime, Tag}
  alias Logex.Configuration.{Global, Instance, Text}

  # IEC 61131-3 Ed 3 Table 10: each integer type's kind and N, in the record's order.
  @widths [
    sint: {:signed, 8},
    int: {:signed, 16},
    dint: {:signed, 32},
    lint: {:signed, 64},
    usint: {:unsigned, 8},
    uint: {:unsigned, 16},
    udint: {:unsigned, 32},
    ulint: {:unsigned, 64}
  ]
  @types Keyword.keys(@widths)

  # Ed 3 Figure 11 (p.67), the "i" cells among the integer types.
  @figure_11 %{
    sint: [:int, :dint, :lint],
    int: [:dint, :lint],
    dint: [:lint],
    lint: [],
    usint: [:uint, :udint, :ulint, :int, :dint, :lint],
    uint: [:udint, :ulint, :dint, :lint],
    udint: [:ulint, :lint],
    ulint: []
  }

  @articles %{sint: "an", int: "an", lint: "an"}

  defp limits(type), do: limits_of(Keyword.fetch!(@widths, type))
  defp limits_of({:signed, n}), do: {-Integer.pow(2, n - 1), Integer.pow(2, n - 1) - 1}
  defp limits_of({:unsigned, n}), do: {0, Integer.pow(2, n) - 1}

  defp fits?(type, value) do
    {low, high} = limits(type)
    value >= low and value <= high
  end

  # The wrap, restated: the value modulo 2^N, read back as two's complement where signed.
  defp wrap(type, value), do: wrap_of(Keyword.fetch!(@widths, type), value)

  defp wrap_of({:unsigned, n}, value), do: Integer.mod(value, Integer.pow(2, n))

  defp wrap_of({:signed, n}, value),
    do: signed(Integer.mod(value, Integer.pow(2, n)), Integer.pow(2, n - 1))

  defp signed(low, half) when low >= half, do: low - 2 * half
  defp signed(low, _half), do: low

  defp bit(true), do: 1
  defp bit(false), do: 0

  defp widens?(type, type), do: true
  defp widens?(from, to), do: to in Map.fetch!(@figure_11, from)

  defp a(type), do: "#{Map.get(@articles, type, "a")} #{type}"

  # What a message says of a value that does not fit: its type's range, signed or unsigned
  # (decision 177).
  defp misfit(type, shown),
    do: "#{shown} is outside #{elem(limits(type), 0)} to #{elem(limits(type), 1)}"

  defp widened(true, {source, _from, to}, text) do
    p = program(text)
    {low, high} = limits(source)

    for value <- [low, high, 0] do
      assert scan(p, %{"v" => value}) == %{"d" => wrap(to, value), "ok" => bit(fits?(to, value))},
             inspect({source, to, value})
    end
  end

  defp widened(false, {source, from, to}, text),
    do:
      assert(
        messages(text) == [
          "`#{from}_to_#{to}` reads #{a(from)}, but `v` is #{a(source)} (declared on line 1): " <>
            "use `#{told(source, to)}`"
        ]
      )

  defp told(type, type), do: "move"
  defp told(source, to), do: "#{source}_to_#{to}"

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

  describe "a width is declared everywhere a dint is" do
    test "a tag of each width, in each section, takes its limits and is told one past them" do
      for type <- @types do
        {low, high} = limits(type)

        p =
          program(
            "var a #{type} #{low}\nvar b #{type} #{high}\nvar_input i #{type}\n" <>
              "var_output o #{type}\nvar_external e #{type}\nvar f bool\n" <>
              "xic f move i o\nxic f move a b\nxic f move e a"
          )

        assert Logex.Program.initial_env(p) == %{
                 "a" => low,
                 "b" => high,
                 "i" => 0,
                 "o" => 0,
                 "e" => 0,
                 "f" => 0
               }

        assert Enum.map(Map.values(p.tags), & &1.type) -- [:bool] == List.duplicate(type, 5)

        assert messages("var c #{type} #{low - 1}\nvar d #{type} #{high + 1}\nxic c ote d") ==
                 [
                   "`c` is #{a(type)}: #{misfit(type, "`#{low - 1}`")}",
                   "`d` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}",
                   # Since M5-13's review each is declared with no initial value, its uses checked.
                   "`xic` reads a bool, but `c` is #{a(type)} (declared on line 1)",
                   "`ote` writes a bool, but `d` is #{a(type)} (declared on line 2)"
                 ]

        assert messages("var c #{type}\nvar d #{type}\nxic c ote d") == [
                 "`xic` reads a bool, but `c` is #{a(type)} (declared on line 1)",
                 "`ote` writes a bool, but `d` is #{a(type)} (declared on line 2)"
               ]
      end
    end

    test "from Elixir, a tag of each width is checked as a line is" do
      for type <- @types do
        {low, high} = limits(type)
        assert %Tag{type: ^type, initial: ^high} = Tag.new!("x", type, :var, high)
        assert %Tag{initial: ^low} = Tag.new!("x", type, :var, low)

        assert raised(fn -> Tag.new!("x", type, :var, high + 1) end) ==
                 "`x` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}"

        assert %Tag{section: :var_external} = Tag.new!("x", type, :var_external)
      end
    end

    test "a host's input of each width fits at its limits, and is refused past them" do
      for type <- @types do
        {low, high} = limits(type)
        p = program("var_input i #{type}\nvar_output o #{type}\nvar f bool\nxio f move i o")

        assert scan(p, %{"i" => high}) == %{"o" => high}
        assert scan(p, %{"i" => low}) == %{"o" => low}

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => high + 1}) end) ==
                 "input `i` is #{a(type)}: #{misfit(type, "#{high + 1}")}"

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => low - 1}) end) ==
                 "input `i` is #{a(type)}: #{misfit(type, "#{low - 1}")}"

        assert raised(fn -> Runtime.put_inputs(p, Runtime.instance(p), %{"i" => 1.5}) end) ==
                 "input `i` is #{a(type)}: its value must be an integer, found 1.5"
      end
    end

    # Decision 171 by width: a state the host hands in holds nothing outside its tag's type.
    test "a state that holds a value outside its width is the host's mistake" do
      for type <- @types do
        {_low, high} = limits(type)
        p = program("var a #{type}\nvar f bool\nxic f move a a")
        state = %{Runtime.instance(p) | env: %{"a" => high + 1, "f" => 0}}

        assert raised(fn -> Runtime.scan(p, state) end) ==
                 "state.env holds `a` outside its type: it is #{a(type)}, and " <>
                   misfit(type, "#{high + 1}")
      end
    end

    test "a block's member of each width: a `cal` literal fits it or is told so" do
      for type <- @types do
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
        assert state.env["s1"]["sp"] == high

        assert messages("var s1 seal\nvar o #{type}\ncal s1 #{high + 1} o", [seal]) == [
                 "operand 1 of `cal s1` is `sp` (var_input #{type}): " <>
                   misfit(type, "`#{high + 1}`")
               ]
      end
    end
  end

  describe "move and literals by Figure 11 (decision 147)" do
    test "move takes a source its destination's width holds, and names the conversion for every other pair" do
      for from <- @types, to <- @types do
        moves(
          widens?(from, to),
          from,
          to,
          "var s #{from}\nvar d #{to}\nvar f bool\nxio f move s d"
        )
      end
    end

    defp moves(true, from, to, source) do
      {_low, high} = limits(from)
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
              "widen into #{a(to)}, so convert it with `#{from}_to_#{to}`"
          ]
        )

    test "a bool and an integer have no conversion between them" do
      for type <- @types do
        assert messages("var b bool\nvar d #{type}\nmove b d\nmove d b") == [
                 "`move` writes `b`, a bool, into `d`, #{a(type)}: a bool does not widen into " <>
                   "#{a(type)}, and logex has no conversion between them",
                 "`move` writes `d`, #{a(type)}, into `b`, a bool: #{a(type)} does not widen " <>
                   "into a bool, and logex has no conversion between them"
               ]
      end
    end

    test "a literal moved into each width fits it at its limits, and is told one past them" do
      for type <- @types do
        {low, high} = limits(type)
        p = program("var d #{type}\nvar e #{type}\nmove #{low} d\nmove #{high} e")
        {_outputs, state} = Runtime.scan(p, Runtime.instance(p))
        assert {state.env["d"], state.env["e"]} == {low, high}

        assert messages("var d #{type}\nmove #{low - 1} d\nmove #{high + 1} d") == [
                 "`move` writes `#{low - 1}` into `d`, #{a(type)}: #{misfit(type, "it")}",
                 "`move` writes `#{high + 1}` into `d`, #{a(type)}: #{misfit(type, "it")}"
               ]
      end
    end

    test "a timer's preset member takes a source Figure 11 widens into a dint" do
      for type <- @types, do: presets(widens?(type, :dint), type)
    end

    defp presets(true, type) do
      assert {:ok, _} =
               Logex.compile(
                 "var t1 ton\nvar x #{type}\nvar f bool\nxio f move x t1.pre\nxic f ton t1 5",
                 name: "p"
               )

      assert messages("var t1 ton\nvar x #{type}\nvar f bool\nxic f ton t1 x") == [
               "`ton` takes its preset as a number of milliseconds, found `x`: to preset " <>
                 "`t1` from a tag, `move x t1.pre` on a rung above"
             ]
    end

    defp presets(false, type) do
      assert messages(
               "var t1 ton\nvar x #{type}\nvar f bool\nxio f move x t1.pre\nxic f ton t1 5"
             ) == [
               "`move` writes `x`, #{a(type)}, into `t1.pre`, a dint: #{a(type)} does " <>
                 "not widen into a dint, so convert it with `#{type}_to_dint`"
             ]

      assert messages("var t1 ton\nvar x #{type}\nvar f bool\nxic f ton t1 x") == [
               "`ton` takes its preset as a number of milliseconds, found `x`"
             ]
    end

    # Since PLAN M5-4 (decision 147) arithmetic computes in its destination's type, each
    # source widening into it by Figure 11, and a comparison reads two integers of any
    # types by value; `arithmetic_test.exs` holds every rule at every width.
    test "an arithmetic or comparison slot takes every width, a source widening into the " <>
           "destination's type" do
      for type <- @types -- [:dint] do
        assert messages(
                 "var i #{type}\nvar d dint\nvar b bool\nadd i 1 d\nadd d 1 i\neq i 5 ote b"
               ) ==
                 for(
                   true <- [type in [:lint, :udint, :ulint]],
                   do:
                     "`add` computes in `d`'s type, a dint, but `i` is #{a(type)} (declared " <>
                       "on line 1): #{a(type)} does not widen into a dint, so convert it " <>
                       "first, with `#{type}_to_dint`"
                 ) ++
                   for(
                     true <- [type != :lint],
                     do:
                       "`add` computes in `i`'s type, #{a(type)}, but `d` is a dint (declared " <>
                         "on line 2): a dint does not widen into #{a(type)}, so convert it " <>
                         "first, with `dint_to_#{type}`"
                   )
      end
    end
  end

  # PLAN M5-7's Done-when (decision 149): a based literal is the number it spells, judged by
  # its slot as any literal is, so `16#ffff` is 65,535, which a `uint` holds and an `int`
  # does not, where Logix would store -1 (RM018A p.869).
  describe "based literals and `_` separators (M5-7, decision 149)" do
    test "`16#ffff` is 65,535 in a `uint` and refused in an `int`" do
      p = program("var_output u uint\nvar f bool\nxio f move 16#ffff u")
      assert scan(p, %{})["u"] == 65_535

      assert Runtime.instance(program("var u uint 16#ffff\nvar f bool\nxio f move u u")).env["u"] ==
               65_535

      # Since decision 202 each is quoted as written.
      assert messages("var i int\nvar f bool\nxio f move 16#ffff i") == [
               "`move` writes `16#ffff` into `i`, an int: #{misfit(:int, "it")}"
             ]

      assert messages("var i int 16#ffff\nvar f bool\nxic f ote f") == [
               "`i` is an int: #{misfit(:int, "`16#ffff`")}"
             ]
    end

    test "every width takes its top as a based literal, in base 16 and in base 2" do
      for type <- @types do
        {_low, high} = limits(type)
        hex = "16#" <> Integer.to_string(high, 16)
        binary = "2#" <> Integer.to_string(high, 2)

        for literal <- [hex, binary] do
          p = program("var_output d #{type}\nvar f bool\nxio f move #{literal} d")
          assert scan(p, %{})["d"] == high, inspect({type, literal})
        end
      end
    end

    test "a program spelled with `_` or a base compiles to the one its decimal spelling gives" do
      spelled =
        "var_input go bool\nvar_output done bool\nvar t ton\nvar n udint 1_000_000\n" <>
          "xic go ton t 1_000\nxic t.dn eq n 16#f_42_40 ote done\nxic go move 2#1010_0000 n"

      decimal =
        "var_input go bool\nvar_output done bool\nvar t ton\nvar n udint 1000000\n" <>
          "xic go ton t 1000\nxic t.dn eq n 1000000 ote done\nxic go move 160 n"

      a = program(spelled)
      b = program(decimal)
      # Since decision 202 the rungs keep each spelling, and hold the decimal program's
      # values: with the spellings dropped they are its rungs.
      assert {values(a.rungs), a.tags, a.warnings} == {b.rungs, b.tags, b.warnings}
      refute a.rungs == b.rungs

      for go <- [0, 1] do
        assert scan(a, %{"go" => go}) == scan(b, %{"go" => go})
      end
    end
  end

  # Decision 202: a rung keeps a literal's spelling, so every message that quotes a literal
  # quotes it as written, and the value is still what every rule judges.
  describe "a literal's spelling (decision 202)" do
    test "every diagnostic that quotes a literal quotes it as written" do
      for {source, message} <- [
            {"var i int\nvar f bool\nxio f move 16#ffff i",
             "`move` writes `16#ffff` into `i`, an int: it is outside -32768 to 32767"},
            {"var i int 16#ffff\nvar f bool\nxic f ote f",
             "`i` is an int: `16#ffff` is outside -32768 to 32767"},
            {"var x bool 0_2\nvar f bool\nxic f ote f",
             "`x` is a bool: its initial value must be 0 or 1, found `0_2`"},
            {"var s sint\nvar f bool\nxic f lt s 16#ff ote f",
             "`lt` compares `16#ff` with `s`, an sint (declared on line 1), which never holds " <>
               "it: `16#ff` is outside -128 to 127"},
            {"var s sint\nvar f bool\nxic f add s 2#1000_0000 s",
             "`add` computes in `s`'s type, an sint: `2#1000_0000` is outside -128 to 127"},
            {"var d dint\nvar f bool\nxic f add 16#1_0000_0000_0000_0000 d d",
             "`add` computes in `d`'s type, a dint: `16#1_0000_0000_0000_0000` is outside " <>
               "-2147483648 to 2147483647"},
            {"var t ton\nvar f bool\nxic f ton t -0_1",
             "`ton` takes a preset of 0 to 2147483647 ms, found `-0_1`"},
            {"var f bool\nxic 16#1 ote f", "`xic` expects a tag, found `16#1`"},
            {"var f bool\n16#ff f", "expected an instruction, found `16#ff`"},
            {"var d dint\nvar f bool\nxic f div d 00 d",
             "`div` divides by the literal `00`: a zero divisor gives 0 and passes no power on " <>
               "every scan, so a literal one is refused"},
            {"var s sint\nvar f bool\nxic f dint_to_sint 16#1_0000_0000 s",
             "`dint_to_sint` reads a dint: `16#1_0000_0000` is outside -2147483648 to 2147483647"},
            {"var 16#1 bool", "expected a tag name after `var`, found `16#1`"},
            {"var x 16#1", "`x` needs a type before its initial value `16#1`"},
            {"var x bool 1 16#2", "unexpected `16#2` after the declaration of `x`"}
          ] do
        assert messages(source) == [message], source
      end

      # A number the message computes is a value: the negation `neg` would write.
      assert messages("var u usint\nvar f bool\nxic f neg 2#1000_0000 u") == [
               "`neg` writes `u`, a usint (declared on line 1), which holds no negative " <>
                 "value: `neg` writes a signed type, so declare `u` an int"
             ]

      assert messages("var u usint\nvar f bool\nxic f neg -9_223_372_036_854_775_808 u") == [
               "`neg` writes `u`, a usint (declared on line 1), which holds no negative " <>
                 "value: `neg` writes a signed type, and none holds `9223372036854775808`, " <>
                 "its negation"
             ]

      assert messages("var u usint\nvar f bool\nxic f neg 16#1_0000_0000_0000_0000 u") ==
               [
                 "`neg` writes `u`, a usint (declared on line 1), which holds no negative " <>
                   "value: `neg` writes a signed type, and none holds " <>
                   "`16#1_0000_0000_0000_0000`",
                 "`neg` reads a number: `16#1_0000_0000_0000_0000` is outside " <>
                   "-9223372036854775808 to 18446744073709551615, every integer type's values"
               ]
    end

    test "every warning that quotes a literal quotes it as written, a quantity as a value" do
      for {source, message} <- [
            {"var f bool\nxic f eq 16#ff 2#1 ote f",
             "`eq` compares two literals, `16#ff` and `2#1`: its result never changes"},
            {"var d dint\nvar f bool\nxic f add 16#ff 1_0 d",
             "`add` reads two literals, `16#ff` and `1_0`: its result never changes"},
            {"var d dint\nvar f bool\nxic f neg 0_5 d",
             "`neg` reads a literal, `0_5`: its result never changes"},
            {"var d sint\nvar f bool\nxic f dint_to_sint 16#81 d",
             "`dint_to_sint` reads a literal, `16#81`: its result never changes"},
            {"var u usint\nvar f bool\nxic f ge u 16#0 ote f",
             "`ge` compares `u` with `16#0`, and a usint holds nothing below `16#0`: its " <>
               "result never changes"},
            {"var u usint\nvar f bool\nxic f lt 2#1111_1111 u ote f",
             "`lt` compares `2#1111_1111` with `u`, and a usint holds nothing above " <>
               "`2#1111_1111`: its result never changes"},
            {"var cure ton_ltime\nvar f bool\nxic f ton cure 1_500_000",
             "`ton` gives `cure` a preset of 1500000 ns, which is no whole number of " <>
               "milliseconds: a ton_ltime counts whole milliseconds, so it times as the next " <>
               "whole millisecond, 2 ms"},
            {"var cure ton_ltime\nvar f bool\nxic f ton cure 2_000_000\n" <>
               "xic f ge cure.acc 3_000 ote f",
             "`ge` compares `cure.acc` with `3_000`, where `cure.acc` is a ton_ltime's time in " <>
               "nanoseconds: 3000 ns is no whole number of milliseconds, and a ton_ltime counts " <>
               "whole milliseconds"}
          ] do
        assert for(w <- program(source).warnings, do: w.message) == [message], source
      end
    end

    test "a configuration file's reader quotes a number as written, and keeps its value" do
      for {text, message} <- [
            {"task 16#1 interval 10", "expected a task's name after `task`, found `16#1`"},
            {"var_global 2#1 bool", "expected a global's name after `var_global`, found `2#1`"},
            {"program 0_1 motor", "expected an instance name after `program`, found `0_1`"},
            {"program m1 16#1", "expected a program type after `program m1`, found `16#1`"},
            {"var_global x 007", "`x` needs a type before its initial value `007`"}
          ] do
        assert {:error, [%Logex.Diagnostic{message: ^message}], _} =
                 Logex.Configuration.Text.read(text),
               text
      end

      assert {:error, [%Logex.Diagnostic{message: "unknown configuration line `16#ff`" <> _}], _} =
               Logex.Configuration.Text.read("16#ff")

      assert {:ok,
              [
                %Logex.Configuration.Task{interval: 10, priority: 1},
                %Logex.Configuration.Global{initial: 255},
                %Logex.Configuration.Connection{to: 16}
              ]} =
               Logex.Configuration.Text.read(
                 "task t interval 1_0 priority 16#1\nvar_global g uint 16#ff\nm1.x 2#1_0000"
               )
    end

    # The value decides, as presets are compared: a literal respelled leaves its rung the
    # same rung, so an edit reports nothing, and a one-shot on the rung is not blocked.
    test "an edit that only respells a literal changes no rung" do
      was =
        program(
          "var_input go bool\nvar_output q bool\nvar n uint 255\nvar s bool\nvar t ton\n" <>
            "xic go eq n 255 ons s ote q\nxic go ton t 1000"
        )

      now =
        program(
          "var_input go bool\nvar_output q bool\nvar n uint 16#ff\nvar s bool\nvar t ton\n" <>
            "xic go eq n 16#00ff ons s ote q\nxic go ton t 1_000"
        )

      state = Runtime.instance(was)
      assert {:ok, edit, []} = Edit.accept(was, now, state)
      assert {_edit, tested, []} = Edit.test(edit, state)
      assert tested.ons_blocked == []

      # The one-shot fires on the first rising scan after the switch, never blocked.
      {%{"q" => 0}, state} = Runtime.scan(now, Runtime.put_inputs(now, tested, %{"go" => 0}))

      assert {%{"q" => 1}, _state} =
               Runtime.scan(now, Runtime.put_inputs(now, state, %{"go" => 1}))
    end

    # Decision 202 where a literal is no slot's own: an instruction a message shows whole,
    # the operands passed over after an unknown word, and a preset the walk reads.
    test "an instruction shown whole, an unknown word's operands and a walked preset keep the spelling" do
      assert messages("var t1 ton\nvar d dint\nvar a bool\nxic a ton t1 5 move 16#ff d") == [
               "`move 16#ff d` follows `ton t1` on its path: what passes on after a `ton` is " <>
                 "not settled, so a `ton` ends its path; read the timer with `xic t1.dn` on a " <>
                 "rung below"
             ]

      assert messages("var a bool\nfoo 16#ff 1_0 ote a") == ["unknown instruction `foo`"]

      p = program("var t1 ton\nvar a bool\nxic a ton t1 1_000")
      assert Logex.Walk.timers(p) == %{"t1" => {3, 1000}}
      assert Logex.Walk.presets(p) == %{"t1" => {3, 1000}}
    end
  end

  describe "growth: a literal's spelling (decision 202)" do
    # A plain decimal compiles at the cost it did, its leaf the three-element one; a spelled
    # literal costs its spelling's one lex more, in Logex.Parser.well_formed!/1, linear in
    # the literals. Counted where the collector never runs, after a warm-up compile, so each
    # count is the same on every run.
    test "a spelled literal costs a bounded amount more than a plain one, linearly" do
      program = fn word, n ->
        "var hh dint\nvar aa dint\nvar bb bool\n" <>
          String.duplicate("xic bb add aa #{word} hh\nxic bb move #{word} aa\n", n)
      end

      cost = fn word, n -> compiled(program.(word, n)) end
      cost.("16#04d2", 10)

      for word <- ["1234", "16#04d2", "1_234", "01234"] do
        assert cost.(word, 400) <= 2 * cost.(word, 200) + 200, word
      end

      for word <- ["16#04d2", "1_234", "01234"] do
        assert (cost.(word, 200) - cost.("1234", 200)) / 400 <= 80, word
      end
    end
  end

  defp compiled(source) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, _} = Logex.compile(source, name: "p")
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 8_000_000]
      )

    assert_receive {:reductions, n}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    n
  end

  # A spelled tree with every spelling dropped: the tree of the values it spells.
  defp values(rungs) when is_list(rungs), do: Enum.map(rungs, &values/1)
  defp values({:rung, elements}), do: {:rung, values(elements)}
  defp values({:branches, legs}), do: {:branches, Enum.map(legs, &values/1)}
  defp values({:int_lit, line, n, _spelling}), do: {:int_lit, line, n}

  defp values({symbol, line, operands}) when is_list(operands),
    do: {symbol, line, values(operands)}

  defp values(leaf), do: leaf

  describe "the 56 integer conversions (decision 148)" do
    # Each pair, over its source's limits, 0, 1, -1 where it fits, and its target's limits
    # and one past each where the source holds them.
    test "each writes the value where it fits, with power, and its low bits with none" do
      pairs = for from <- @types, to <- @types, from != to, do: {from, to}
      assert length(pairs) == 56

      for {from, to} <- pairs do
        {low, high} = limits(from)
        {to_low, to_high} = limits(to)

        values =
          Enum.filter(
            Enum.uniq([low, high, 0, 1, -1, to_low, to_high, to_low - 1, to_high + 1]),
            &fits?(from, &1)
          )

        p =
          program(
            "var_input go bool\nvar_input v #{from}\nvar_output d #{to}\nvar_output ok bool\n" <>
              "xic go #{from}_to_#{to} v d ote ok"
          )

        for value <- values do
          expected = %{"d" => wrap(to, value), "ok" => bit(fits?(to, value))}
          assert scan(p, %{"go" => 1, "v" => value}) == expected, inspect({from, to, value})
        end

        # De-energised, it writes nothing and passes no power.
        assert scan(p, %{"go" => 0, "v" => high}) == %{"d" => 0, "ok" => 0}
      end
    end

    # RM018A p.872: DINT 65,665 to INT 129 to SINT -127.
    test "dint_to_sint of 129 gives -127 with no power, as Logix's truncation does" do
      p =
        program(
          "var_input v dint\nvar_output s sint\nvar_output i int\nvar_output ok bool\n" <>
            "var_output ok2 bool\ndint_to_sint v s ote ok\ndint_to_int v i ote ok2"
        )

      assert scan(p, %{"v" => 129}) == %{"s" => -127, "i" => 129, "ok" => 0, "ok2" => 1}
      assert scan(p, %{"v" => 65_665}) == %{"s" => -127, "i" => 129, "ok" => 0, "ok2" => 0}
      assert scan(p, %{"v" => -1}) == %{"s" => -1, "i" => -1, "ok" => 1, "ok2" => 1}
    end

    test "a sign change wraps: -1 into each unsigned width is its top, its top into a signed one -1" do
      p =
        program(
          "var_input v dint\nvar_input w udint\nvar_output u usint\nvar_output x uint\n" <>
            "var_output n int\nvar_output m dint\ndint_to_usint v u\ndint_to_uint v x\n" <>
            "udint_to_int w n\nudint_to_dint w m"
        )

      assert scan(p, %{"v" => -1, "w" => 4_294_967_295}) == %{
               "u" => 255,
               "x" => 65_535,
               "n" => -1,
               "m" => -1
             }
    end

    test "its source is a literal of the type it reads, and each slot is told the one that does the job" do
      p = program("var s sint\nvar ok bool\ndint_to_sint 129 s ote ok")
      {_outputs, state} = Runtime.scan(p, Runtime.instance(p))
      assert {state.env["s"], state.env["ok"]} == {-127, 0}

      # A source of a type that does not widen into the one it reads is told the
      # conversion from its own type, or `move` where that is the destination's (decision
      # 176); a destination of another type, the conversion into its own.
      assert messages(
               "var u udint\nvar i int\nvar d dint\nvar b bool\nsint_to_dint 200 d\n" <>
                 "dint_to_int u i\ndint_to_int d d\ndint_to_int b i\nint_to_dint 5 5\n" <>
                 "sint_to_int i i"
             ) == [
               "`sint_to_dint` reads an sint: `200` is outside -128 to 127",
               "`dint_to_int` reads a dint, but `u` is a udint (declared on line 1): use " <>
                 "`udint_to_int`",
               "`dint_to_int` writes an int, but `d` is a dint (declared on line 3): use `move`",
               "`dint_to_int` reads a dint, but `b` is a bool (declared on line 4)",
               "`int_to_dint` expects a tag, found `5`",
               "`sint_to_int` reads an sint, but `i` is an int (declared on line 2): use `move`"
             ]
    end

    # Decision 178: a conversion of a literal compiles, as `neg 5 x` does, with the warning
    # an all-literal arithmetic instruction draws: its result never changes. One of a tag,
    # or of a member, draws none. Every one of the 56, in any case.
    test "a conversion of a literal warns that its result never changes (decision 178)" do
      for from <- @types, to <- @types, from != to do
        {:ok, p} =
          Logex.compile(
            "var v #{from}\nvar d #{to}\nvar t1 ton\nvar e #{to}\n" <>
              "#{String.upcase("#{from}_to_#{to}")} 0 d\n#{from}_to_#{to} v d\n" <>
              "xic t1.dn #{from}_to_#{to} 1 e",
            name: "p"
          )

        assert Enum.map(p.warnings, &{&1.line, &1.message}) == [
                 {3, "`t1` is a ton, but no `ton` runs it: it never times"},
                 {5, "`#{from}_to_#{to}` reads a literal, `0`: its result never changes"},
                 {7, "`#{from}_to_#{to}` reads a literal, `1`: its result never changes"}
               ]
      end

      {:ok, p} = Logex.compile("var s sint\ndint_to_sint 129 s", name: "p")

      assert Enum.map(p.warnings, & &1.message) == [
               "`dint_to_sint` reads a literal, `129`: its result never changes"
             ]
    end

    # Decision 176: a conversion's source widens as IEC's typed functions' inputs do, so
    # `dint_to_int` takes an sint, an int or a usint as it takes a dint, and writes what
    # the dint's would; its destination stays exact. Over every conversion and every
    # source type, each at its limits, against Figure 11 and the wrap restated.
    test "its source may be of any type that widens into the one it reads (decision 176)" do
      for from <- @types, to <- @types, from != to, source <- @types, source != from do
        text =
          "var_input v #{source}\nvar_output d #{to}\nvar_output ok bool\n" <>
            "#{from}_to_#{to} v d ote ok"

        widened(widens?(source, from), {source, from, to}, text)
      end

      # The destination stays exact, narrower or wider, each told the conversion that does
      # the whole job, though every value of the wider one's would fit.
      assert messages("var v dint\nvar s sint\nvar l lint\ndint_to_int v s\ndint_to_int v l") == [
               "`dint_to_int` writes an int, but `s` is an sint (declared on line 2): use " <>
                 "`dint_to_sint`",
               "`dint_to_int` writes an int, but `l` is an lint (declared on line 3): use " <>
                 "`dint_to_lint`"
             ]

      # A member widens as a tag does: a timer's `.acc` is a dint.
      p =
        program(
          "var_input go bool\nvar t1 ton\nvar_output i int\nxic go ton t1 5\nlint_to_int t1.acc i"
        )

      assert scan(p, %{"go" => 1}) == %{"i" => 0}

      assert messages("var t1 ton\nvar i int\nsint_to_int t1.acc i") == [
               "`sint_to_int` reads an sint, but `t1.acc` is a dint: use `dint_to_int`"
             ]
    end

    test "what it passes on is settled, so anything may follow it on its path" do
      p =
        program(
          "var_input v dint\nvar_output s sint\nvar_output u usint\nvar_output ok bool\n" <>
            "dint_to_sint v s dint_to_usint v u ote ok"
        )

      assert scan(p, %{"v" => 5}) == %{"s" => 5, "u" => 5, "ok" => 1}
      assert scan(p, %{"v" => -1}) == %{"s" => -1, "u" => 255, "ok" => 0}
      # 200 leaves the sint, so no power reaches the second, which writes nothing.
      assert scan(p, %{"v" => 200}) == %{"s" => -56, "u" => 0, "ok" => 0}
    end

    # The 56 mnemonics are looked up in one map, so a program of 4x the conversions compiles
    # and scans in about 4x the reductions.
    test "a program's conversions cost linear reductions to compile and to scan" do
      rungs = fn n ->
        "var_input v dint\nvar s sint\nvar u usint\nvar l lint\n" <>
          String.duplicate("dint_to_sint v s\ndint_to_usint v u\nsint_to_lint s l\n", n)
      end

      cost = fn n ->
        source = rungs.(n)

        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            {:ok, p} = Logex.compile(source, name: "p")
            Runtime.scan(p, Runtime.put_inputs(p, Runtime.instance(p), %{"v" => 300}))
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      ratio = cost.(400) / cost.(100)
      assert ratio < 4.8, "4x the conversions took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  describe "a cal formal and a connection widen, a var_external binds exactly (decision 159)" do
    test "a `cal` operand widens into the var_input it fills, and the var_output into its tag" do
      seal =
        program(
          "function_block seal\nvar_input sp uint\nvar_output q uint\nmove sp q",
          "seal"
        )

      {:ok, outer} =
        Logex.compile(
          "var_input b usint\nvar s1 seal\nvar_output o udint\ncal s1 b o",
          name: "p",
          types: [seal]
        )

      assert scan(outer, %{"b" => 255}) == %{"o" => 255}

      assert messages(
               "var s1 seal\nvar d dint\nvar i int\nvar u usint\ncal s1 d i\ncal s1 u u",
               [seal]
             ) == [
               "operand 1 of `cal s1` is `sp` (var_input uint), but `d` is a dint: a dint " <>
                 "does not widen into a uint, so convert it with `dint_to_uint`",
               "operand 2 of `cal s1` is `q` (var_output uint), but `i` is an int: a uint " <>
                 "does not widen into an int, so convert it with `uint_to_int`",
               "operand 2 of `cal s1` is `q` (var_output uint), but `u` is a usint: a uint " <>
                 "does not widen into a usint, so convert it with `uint_to_usint`",
               "`s1` is already run by the `cal` on line 5: one `cal` runs an instance"
             ]
    end

    defp fan do
      program(
        "var_input hz uint\nvar_output speed uint\nvar_external count uint\nvar f bool\n" <>
          "xio f move hz speed\nxio f move hz count",
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
                 "var_global hz usint at drive.i.0\nvar_global speed udint\n" <>
                   "var_global count uint\nprogram f1 fan\nf1.hz hz\nf1.speed speed"
               )

      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(config), 0, %{"hz" => 255})
      assert Runtime.get(runtime, "speed") == {:ok, 255}
      assert Runtime.get(runtime, "count") == {:ok, 255}

      assert configured(
               "var_global hz udint\nvar_global speed int\nvar_global count udint\n" <>
                 "program f1 fan\nf1.hz hz\nf1.speed speed"
             ) == [
               "`fan` declares `var_external count uint` on its line 3, but `count` is a " <>
                 "udint (line 3): a var_external is its global, so its type is exactly the " <>
                 "global's, never widened",
               "`f1.hz` is a uint, but `hz` is a udint (line 1): a udint does not widen into a " <>
                 "uint, and a connection converts nothing: convert it inside the program, with " <>
                 "`udint_to_uint`",
               "`f1.speed` is a uint, but `speed` is an int (line 2): a uint does not widen " <>
                 "into an int, and a connection converts nothing: convert it inside the " <>
                 "program, with `uint_to_int`"
             ]

      # A var_external of a narrower width is no binding either: one copy, one type.
      assert [message] =
               configured(
                 "var_global hz uint\nvar_global speed uint\nvar_global count usint\n" <>
                   "program f1 fan\nf1.hz hz\nf1.speed speed"
               )

      assert message =~ "but `count` is a usint (line 3): a var_external is its global"
    end

    test "a constant connected to each width fits it at its limits, and is told one past them" do
      for type <- @types do
        {low, high} = limits(type)

        motor =
          program("var_input sp #{type}\nvar_output o #{type}\nvar f bool\nxio f move sp o", "m")

        text = fn value -> "var_global g #{type}\nprogram m1 m\nm1.sp #{value}\nm1.o g" end

        assert {:ok, _} = Configuration.compile("plant", text.(high), %{"m" => motor})
        assert {:ok, _} = Configuration.compile("plant", text.(low), %{"m" => motor})

        assert {:error, [%{message: message}]} =
                 Configuration.compile("plant", text.(high + 1), %{"m" => motor})

        assert message == "`m1.sp` is #{a(type)}: #{misfit(type, "`#{high + 1}`")}"
      end
    end

    test "a global of each width, its initial value at its limits, located, printed back" do
      for type <- @types do
        {low, high} = limits(type)

        sink =
          program("var_input a #{type}\nvar_output o #{type}\nvar f bool\nxio f move a o", "m")

        text =
          "var_global lo #{type} #{low}\nvar_global hi #{type} #{high}\n" <>
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

        # From Elixir, the same global, and an input of each width's limits into a cycle.
        assert %Configuration{} =
                 Configuration.new!(
                   name: "plant",
                   programs: [sink],
                   globals: [
                     %Global{name: "pt", type: type, at: "card.i.0"},
                     %Global{name: "lo", type: type, initial: low}
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
      end
    end
  end

  describe "an online edit (decision 157)" do
    test "a width changed is refused at its line, and a changed initial value of each width reported" do
      was = program("var b usint 3\nvar q bool\nxic q ote q")
      now = program("var q bool\nvar b uint 3\nxic q ote q")

      assert {:error, [%{line: 2, message: message}]} =
               Edit.accept(was, now, Runtime.instance(was))

      assert message ==
               "`b` is a usint in the running program and a uint in the candidate: a tag's " <>
                 "type changes only with a restart"

      for type <- @types do
        {_low, high} = limits(type)
        was = program("var b #{type} 0\nvar q bool\nxic q ote q")
        now = program("var b #{type} #{high}\nvar q bool\nxic q ote q")
        assert {:ok, _edit, report} = Edit.accept(was, now, Runtime.instance(was))
        assert {:initial_changed, "b", {0, high}} in report
      end
    end

    test "a global's width changed is refused, and its changed initial value reported" do
      sink = program("var_input a uint\nvar_output o uint\nvar f bool\nxio f move a o", "m")

      config = fn text ->
        {:ok, c} =
          Configuration.compile(
            "plant",
            text <> "\nvar_global pt uint\nprogram m1 m\nm1.a pt\nm1.o pt",
            %{"m" => sink}
          )

        c
      end

      runtime = Runtime.start(config.("var_global x uint 5"))

      assert {:error, [%{message: message}]} =
               Configuration.Edit.accept(runtime, config.("var_global x udint 5"))

      assert message ==
               "`x` is a uint global in the running configuration and a udint in the " <>
                 "candidate: a global's type changes only with a restart"

      assert {:ok, _runtime, report} =
               Configuration.Edit.accept(runtime, config.("var_global x uint 65535"))

      assert {:initial_changed, "x", {5, 65_535}} in report
    end
  end

  describe "the reserved words" do
    # A conversion is reserved in a `.ld` file only, as every mnemonic is, so it may name a
    # global: this test does not look for one (M5-3's review).
    test "each of the seven type words names no tag or global, and the 56 conversions no tag or label, in any case" do
      conversions = for from <- @types, to <- @types, from != to, do: "#{from}_to_#{to}"

      for word <- ~w(sint int lint usint uint udint ulint) do
        for shown <- [word, String.upcase(word)] do
          assert messages("var #{shown} bool\nxic #{shown} ote #{shown}") |> hd() ==
                   "`#{shown}` is a type and cannot name a tag"

          assert {:error, [%{message: global} | _]} =
                   Configuration.compile("plant", "var_global #{shown} bool\n", %{})

          assert global =~ "`#{shown}`"
        end
      end

      for conversion <- conversions, word <- [conversion, String.upcase(conversion)] do
        assert hd(messages("var #{word} bool\nxic #{word} ote #{word}")) ==
                 "`#{word}` is an instruction and cannot name a tag"

        assert hd(messages("var b bool\nxic b jmp #{word}\nlbl #{word} ote b")) =~
                 "`#{word}`"
      end
    end
  end

  describe "a point of each width through the runner (decision 156)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    # One input point of each width on the card, at `card.i.0` to `card.i.7` in the
    # record's order, each moved into a global of its own width on a 10 ms task.
    defp card do
      inputs = Enum.map_join(@types, &"var_input i_#{&1} #{&1}\n")
      outputs = Enum.map_join(@types, &"var_output o_#{&1} #{&1}\n")
      moves = Enum.map_join(@types, &"move i_#{&1} o_#{&1}\n")
      copy = program(inputs <> outputs <> moves, "copy")

      globals =
        @types
        |> Enum.with_index()
        |> Enum.map_join(fn {type, n} ->
          "var_global p_#{type} #{type} at card.i.#{n}\nvar_global g_#{type} #{type}\n"
        end)

      wires = Enum.map_join(@types, &"  c.i_#{&1} p_#{&1}\n  c.o_#{&1} g_#{&1}\n")

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

    test "each width's limits are read from the device, and one past them trips the runner",
         %{tmp_dir: dir} do
      for {type, n} <- Enum.with_index(@types), at <- [0, 1] do
        {{:ok, runner}, clock, sim} = run_card(Path.join(dir, "forces"))
        {low, high} = limits(type)
        limit = elem({low, high}, at)
        Sim.set(sim, [n], limit)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "g_#{type}") == limit

        past = elem({low - 1, high + 1}, at)
        Sim.set(sim, [n], past)
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == {:io, "card", {:bad_value, [n], past}}
        Runner.stop(runner)
      end
    end

    test "a force of each width is held to its range, and the forces file reads back exactly",
         %{tmp_dir: dir} do
      file = Path.join(dir, "forces")
      {{:ok, runner}, clock, _sim} = run_card(file)

      for type <- @types do
        {low, high} = limits(type)

        assert raised(fn -> Runner.force(runner, "p_#{type}", high + 1) end) ==
                 "`p_#{type}` is #{a(type)}, forced to an integer from #{low} to #{high}, " <>
                   "got: #{high + 1}"

        assert :ok = Runner.force(runner, "p_#{type}", high)
      end

      Manual.advance(clock, 10)
      for type <- @types, do: assert(Runner.get!(runner, "g_#{type}") == elem(limits(type), 1))

      written = File.read!(file)
      Runner.stop(runner)

      assert written ==
               @types
               |> Enum.map(&"p_#{&1} #{elem(limits(&1), 1)}\n")
               |> Enum.sort()
               |> Enum.join()

      # A fresh start reads every force back, each its width's top.
      {{:ok, runner}, clock, _sim} = run_card(file)
      Manual.advance(clock, 10)
      for type <- @types, do: assert(Runner.get!(runner, "g_#{type}") == elem(limits(type), 1))
      Runner.stop(runner)

      # A file whose force does not fit its point's width refuses the start, in its words.
      File.write!(file, "p_usint 256\np_lint -9223372036854775809\n")

      assert raised(fn -> run_card(file) end) ==
               "#{file}: line 1: `p_usint` is a usint, forced to an integer from 0 to 255, " <>
                 "got: 256\n" <>
                 "#{file}: line 2: `p_lint` is an lint, forced to an integer from " <>
                 "-9223372036854775808 to 9223372036854775807, got: -9223372036854775809"

      # Every width one past each of its limits, a file for each end, every force a line
      # of the one refusal, in the file's order (M5-3's review: the ulint's among them).
      for at <- [0, 1] do
        File.write!(
          file,
          Enum.map_join(@types, fn type ->
            "p_#{type} #{elem(limits(type), at) + elem({-1, 1}, at)}\n"
          end)
        )

        assert raised(fn -> run_card(file) end) ==
                 @types
                 |> Enum.with_index(1)
                 |> Enum.map_join("\n", fn {type, line} ->
                   {low, high} = limits(type)

                   "#{file}: line #{line}: `p_#{type}` is #{a(type)}, forced to an integer " <>
                     "from #{low} to #{high}, got: #{elem({low - 1, high + 1}, at)}"
                 end)
      end
    end
  end
end
