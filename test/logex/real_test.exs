defmodule Logex.RealTest do
  @moduledoc """
  PLAN M5-10: the reals, `real` and `lreal` (`docs/organisation.md` §4.12, decisions 147 to
  150, 155 to 157, 161, 162, 164, 166 and 167), every rule of a program's from source
  through `Logex.compile/2`, `Logex.Runtime.call/4`, `Logex.Edit` and a configuration's
  `Logex.Runtime.cycle/3` and `get/2`: the literal and its refusals at their columns; the
  types declared and their one zero, 0.0; `move`, the arithmetic, the comparisons, the 34
  conversions, the 16 truncations and `sqrt`; decision 150's zero divisor, saturation,
  −0.0, subnormals and single rounding; decision 161's round then wrap; decision 164's
  negative root and 167's literal one; a real's bit refused (decision 155); an integer
  input stored as its nearest real (decision 166); the host contract for a real's value; a
  changed real initial value reported exactly (decision 157); and a seeded walk of values
  near each real's limits, at zero divisors and at subnormals, from which no float
  exception escapes and after which no state holds −0.0 or a subnormal.

  A single's rounding, IEC's rounding of a tie to even and the wrap are restated here, from
  IEEE 754 and IEC's text, through the BEAM's own 32-bit float encoding and integer
  arithmetic, never read from `Logex.Real` or `Logex.Declarations`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Fault, Runtime, Scan}

  # Restated: a single's largest finite value and smallest normal one.
  @single_max 3.4028234663852886e38
  @single_min 1.1754943508222875e-38
  @double_max 1.7976931348623157e308

  # The single nearest a double, by the BEAM's own 32-bit encoding, which rounds to even.
  defp single(x) do
    <<y::float-32>> = <<x::float-32>>
    y
  end

  defp program(source, types \\ []) do
    {:ok, program} = Logex.compile(source, name: "p", types: types)
    program
  end

  defp messages(source) do
    {:error, diagnostics} = Logex.compile(source, name: "p")
    Enum.map(diagnostics, &{&1.line, &1.message})
  end

  defp warnings(source), do: Enum.map(program(source).warnings, &{&1.line, &1.message})

  # One scan of a new instance: the outputs, the env and the scan's faults.
  defp scan(source, inputs \\ %{}) do
    program = program(source)
    state = Runtime.instance(program)
    {outputs, state} = Runtime.call(program, state, inputs, %Scan{now: 0, first: true})
    {outputs, state.env, state.faults}
  end

  defp outputs(source, inputs \\ %{}), do: elem(scan(source, inputs), 0)

  defp lexed(source), do: Logex.Lexer.tokenize(source)

  describe "the literal (decision 149)" do
    test "digits, a `.`, digits and an optional exponent, a sign glued to it" do
      assert {:ok, [{:real_lit, {1, 1}, 37.5}], 1} = lexed("37.5")
      assert {:ok, [{:real_lit, {1, 1}, -0.25}], 1} = lexed("-0.25")
      assert {:ok, [{:real_lit, {1, 1}, 1500.0}], 1} = lexed("1.5e3")
      assert {:ok, [{:real_lit, {1, 1}, 0.0015, "1.5E-3"}], 1} = lexed("1.5E-3")
      assert {:ok, [{:real_lit, {1, 1}, 1000.5, "1_000.5"}], 1} = lexed("1_000.5")
      assert {:ok, [{:real_lit, {1, 1}, 37.5, "37.50"}], 1} = lexed("37.50")
    end

    # Decision 150: no value logex holds is −0.0, so `-0.0` is the spelling of 0.0.
    test "`-0.0` is 0.0, spelled" do
      assert {:ok, [{:real_lit, {1, 1}, zero, "-0.0"}], 1} = lexed("-0.0")
      assert zero === 0.0
    end

    # PLAN M5-10's Done-when: `1.`, `.5`, `1e5`, `1.5e+3` and Logix's `1.5L` are pinned
    # refusals at their columns, each its lexer clause's.
    test "`1.`, `.5`, `1e5`, `1.5e+3` and `1.5L` are refused at their columns" do
      for {source, column, reason, message} <- [
            {"move 1. x", 6, {:point, "1."},
             ~s("1." is no number: a real has digits on both sides of its `.`, `1.0` or `0.5`)},
            {"move .5 x", 6, {:point, ".5"},
             ~s(".5" is no number: a real has digits on both sides of its `.`, `1.0` or `0.5`)},
            {"move 1e5 x", 6, {:no_point, "1e5"},
             ~s("1e5" is no number: a real has a `.` with digits on both sides before its ) <>
               "exponent, `1.0e5`"},
            {"move 1.5e+3 x", 6, {:plus, "1.5e+3"},
             ~s("1.5e+3" is no number: logex takes no `+`, so an exponent is `e3` or `e-3`)},
            {"move 1.5L x", 6, {:missing_separator, "1.5L"},
             ~s(missing separator after a real: "1.5L" is neither a number nor a tag)}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, ^reason}, 1} = lexed(source), source
        assert Logex.Lexer.format_error(reason) == message

        assert {:error, [%Logex.Diagnostic{stage: :lex, line: 1, column: ^column}]} =
                 Logex.compile(source, name: "m")
      end
    end

    test "an exponent with no digits, a `_` out of place and one past an lreal are refused" do
      for {source, column, reason} <- [
            {"move 1.5e x", 6, {:exponent, "1.5e"}},
            {"move 1.5e- x", 6, {:exponent, "1.5e-"}},
            {"move 1.5_ x", 6, {:separator, "1.5_"}},
            {"move 1_.5 x", 6, {:separator, "1_.5"}},
            {"move 1._5 x", 6, {:point, "1._5"}},
            {"move 1.0e400 x", 6, {:real_range, "1.0e400"}},
            {"move 16#ff.3 x", 6, {:digits, 16, "16#ff.3"}},
            {"move 1.5.2 x", 6, {:missing_separator, "1.5.2"}}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, ^reason}, 1} = lexed(source), source
      end

      assert Logex.Lexer.format_error({:real_range, "1.0e400"}) ==
               ~s("1.0e400" is no number logex holds: an lreal's largest is ) <>
                 "1.7976931348623157e308"

      assert Logex.Lexer.format_error({:exponent, "1.5e"}) ==
               ~s("1.5e" is no number: an exponent is `e` and its digits, `1.5e3` or `1.5e-3`)
    end

    test "a real literal prints as written and its value is what every rule judges" do
      for source <- ["move 1.5E3 x", "move 37.50 y", "move -0.0 z", "gt a 1_000.5 ote q"] do
        {:ok, tokens, _} = lexed(source)
        {:ok, tree} = Logex.Parser.parse(tokens)
        assert Logex.Printer.print(tree) == source
      end
    end
  end

  describe "the types (decisions 144 and 150)" do
    test "a real and an lreal start at 0.0, never 0, and at an initial value's nearest" do
      {_outputs, env, []} =
        scan(
          "var a real\nvar b lreal\nvar c real 0\nvar d real 0.1\nvar e lreal 0.1\n" <>
            "var f real 37.5\nvar_output q real\nmove a q"
        )

      assert env["a"] === 0.0
      assert env["b"] === 0.0
      assert env["c"] === 0.0
      assert env["d"] === 0.10000000149011612
      assert env["e"] === 0.1
      assert env["f"] === 37.5
    end

    test "a declaration's initial value is judged by the literal rules" do
      assert messages("var a real 16777217\nvar b dint 1.5\nvar c lreal 9007199254740993\nxic x") ==
               [
                 {1,
                  "`a` is a real: `16777217` is no value of a real, which holds integers " <>
                    "exactly only to 2^24: the nearest it holds is 16777216.0"},
                 {2, "the initial value of `b` must be an integer, found 1.5"},
                 {3,
                  "`c` is an lreal: `9007199254740993` is no value of an lreal, which holds " <>
                    "integers exactly only to 2^53: the nearest it holds is 9007199254740992.0"},
                 {4, "`x` is not declared"}
               ]
    end

    # Decision 155: a real has no bits a program may name.
    test "`fan_speed.3` and `fan_speed.[sel]` on a real and an lreal are refused at their lines" do
      for type <- ["real", "lreal"] do
        source =
          "var fan_speed #{type}\nvar sel int\nvar_output q bool\n" <>
            "xic fan_speed.3 ote q\nxic fan_speed.[sel] ote q"

        a = if type == "real", do: "a real", else: "an lreal"

        assert messages(source) == [
                 {4, "`fan_speed.3` names a bit of `fan_speed`, #{a}, which has no bits"},
                 {5, "`fan_speed.[sel]` names a bit of `fan_speed`, #{a}, which has no bits"}
               ]
      end
    end
  end

  describe "move and single rounding (decisions 147 and 150)" do
    # PLAN M5-10's Done-when: every write to a `real` rounds to the nearest single.
    test "`move 0.1 x` is 0.10000000149011612 in a real and 0.1 in an lreal" do
      assert outputs("var_output x real\nvar_output y lreal\nmove 0.1 x\nmove 0.1 y") ==
               %{"x" => single(0.1), "y" => 0.1}

      assert single(0.1) === 0.10000000149011612
    end

    test "an integer widens into a real, a real into an lreal, as Figure 11 has it" do
      assert outputs(
               "var_input i int\nvar_input u usint\nvar_input d dint\nvar_input r real\n" <>
                 "var_output x real\nvar_output y real\nvar_output z lreal\nvar_output w lreal\n" <>
                 "move i x move u y move d z move r w",
               %{"i" => -7, "u" => 200, "d" => 2_147_483_647, "r" => 0.1}
             ) == %{"x" => -7.0, "y" => 200.0, "z" => 2_147_483_647.0, "w" => single(0.1)}
    end

    test "a type Figure 11 does not widen is told its conversion" do
      assert messages(
               "var d dint\nvar r real\nvar l lreal\nvar i int\nvar w word\n" <>
                 "move d r\nmove l r\nmove r i\nmove w r"
             ) == [
               {6,
                "`move` writes `d`, a dint, into `r`, a real: a dint does not widen into a " <>
                  "real, so convert it with `dint_to_real`"},
               {7,
                "`move` writes `l`, an lreal, into `r`, a real: an lreal does not widen into " <>
                  "a real, so convert it with `lreal_to_real`"},
               {8,
                "`move` writes `r`, a real, into `i`, an int: a real does not widen into an " <>
                  "int, so convert it with `real_to_int`"},
               {9,
                "`move` writes `w`, a word, into `r`, a real: a word does not widen into a " <>
                  "real, and logex has no conversion between them"}
             ]
    end

    # Decision 147: an integer literal in a real slot is the value it spells, refused where
    # the real cannot hold it exactly, the nearest named; a real literal is no integer's.
    test "a literal is judged by its slot" do
      assert messages(
               "var r real\nvar l lreal\nvar i int\nmove 16777217 r\nmove 1.5 i\nmove 16777217 l"
             ) == [
               {4,
                "`move` writes `16777217` into `r`, a real: it is no value of a real, which " <>
                  "holds integers exactly only to 2^24: the nearest it holds is 16777216.0"},
               {5,
                "`move` writes `1.5` into `i`, an int: it is a real, and an int holds only integers"}
             ]

      assert outputs("var_output r real\nmove 16777216 r") == %{"r" => 16_777_216.0}
    end
  end

  describe "arithmetic (decisions 147 and 150)" do
    # PLAN M5-10's Done-when.
    test "`add 16777216 1.0 x` is 16777216.0 in a real and 16777217.0 in an lreal" do
      assert outputs(
               "var_output x real\nvar_output y lreal\nadd 16777216 1.0 x\nadd 16777216 1.0 y"
             ) ==
               %{"x" => 16_777_216.0, "y" => 16_777_217.0}
    end

    test "each instruction computes in its destination's real, its sources widened into it" do
      assert outputs(
               "var_input a real\nvar_input i int\nvar_output s real\nvar_output d real\n" <>
                 "var_output m lreal\nvar_output n real\nvar_output b real\n" <>
                 "add a i s div i 2 d mul a a m neg a n abs n b",
               %{"a" => 1.5, "i" => 7}
             ) == %{"s" => 8.5, "d" => 3.5, "m" => 2.25, "n" => -1.5, "b" => 1.5}
    end

    test "a source no Figure 11 cell widens into the destination is told its conversion" do
      assert messages("var d dint\nvar r real\nvar w word\nadd d 1.0 r\nadd w 1.0 r\nmod r 2 d") ==
               [
                 {4,
                  "`add` computes in `r`'s type, a real, but `d` is a dint (declared on line 1): " <>
                    "a dint does not widen into a real, so convert it first, with `dint_to_real`"},
                 {5,
                  "`add` reads a number, but `w` is a word (declared on line 3): a word is a bit " <>
                    "string, not a number: convert it first, with `word_to_uint`"},
                 {6, "`mod` reads an integer, but `r` is a real (declared on line 2)"}
               ]
    end

    # Decision 150: a result past the type's largest finite value saturates there, the sign
    # kept, with no power; one the BEAM cannot hold, an lreal's, does too.
    test "a result past a real's range saturates with no power" do
      source =
        "var_input a real\nvar_input b real\nvar_input l lreal\nvar_output x real\n" <>
          "var_output y lreal\nvar_output z real\nvar_output p bool\nvar_output q bool\n" <>
          "var_output r bool\nmul a b x ote p\nmul l l y ote q\nsub 0.0 x z ote r"

      assert outputs(source, %{"a" => 2.0e38, "b" => 2.0, "l" => 1.0e308}) ==
               %{
                 "x" => @single_max,
                 "y" => @double_max,
                 "z" => -@single_max,
                 "p" => 0,
                 "q" => 0,
                 "r" => 1
               }

      # One that rounds, at the single's largest value itself, passes power.
      assert outputs(source, %{"a" => @single_max, "b" => 1.0, "l" => 1.0}) ==
               %{
                 "x" => @single_max,
                 "y" => 1.0,
                 "z" => -@single_max,
                 "p" => 1,
                 "q" => 1,
                 "r" => 1
               }
    end

    # Decision 150: −0.0 is written as 0.0, and a subnormal flushed to 0.0, with power.
    test "−0.0 and a subnormal are written as 0.0" do
      {outputs, _env, []} =
        scan(
          "var_input a real\nvar_input l lreal\nvar_output x real\nvar_output y real\n" <>
            "var_output z lreal\nvar_output p bool\nneg 0.0 x\nmul a a y ote p\nmul l l z",
          %{"a" => 1.0e-30, "l" => 1.0e-160}
        )

      assert outputs["x"] === 0.0
      assert outputs["y"] === 0.0
      assert outputs["z"] === 0.0
      assert outputs["p"] == 1
    end

    # Decision 150 and 78: a zero divisor gives 0.0, no power and the minor fault.
    test "a zero divisor gives 0.0 with no power and `:divide_by_zero`" do
      {outputs, _env, faults} =
        scan(
          "var_input a real\nvar_input z int\nvar_output x real\nvar_output q bool\n" <>
            "div a z x ote q",
          %{"a" => 1.5, "z" => 0}
        )

      assert outputs["x"] === 0.0
      assert outputs["q"] == 0

      assert [%Fault{severity: :minor, kind: :divide_by_zero, instruction: :div, line: 5}] =
               faults
    end

    test "a literal `0.0` or `-0.0` divisor and a `mod` of a real are refused at their lines" do
      assert messages("var r real\nvar d dint\ndiv r 0.0 r\ndiv r -0.0 r\nmod r 2 d") == [
               {3,
                "`div` divides by the literal `0.0`: a zero divisor gives 0.0 and passes no " <>
                  "power on every scan, so a literal one is refused"},
               {4,
                "`div` divides by the literal `-0.0`: a zero divisor gives 0.0 and passes no " <>
                  "power on every scan, so a literal one is refused"},
               {5, "`mod` reads an integer, but `r` is a real (declared on line 1)"}
             ]
    end

    test "an instruction of real literals is warned of, its literals quoted as written" do
      assert warnings(
               "var_output x real\nvar_output y lreal\nvar_output i int\nvar_output q bool\n" <>
                 "add 1.5 2.5e0 x\nsqrt 4.0 x\nreal_to_lreal 1.5 y\nreal_trunc_int 1.5 i\n" <>
                 "gt 1.5 2.5 ote q"
             ) == [
               {5, "`add` reads two literals, `1.5` and `2.5e0`: its result never changes"},
               {6, "`sqrt` reads a literal, `4.0`: its result never changes"},
               {7, "`real_to_lreal` reads a literal, `1.5`: its result never changes"},
               {8, "`real_trunc_int` reads a literal, `1.5`: its result never changes"},
               {9, "`gt` compares two literals, `1.5` and `2.5`: its result never changes"}
             ]
    end
  end

  describe "comparisons (decision 147)" do
    test "an integer with a real only where Figure 11 widens it, and two reals by value" do
      assert outputs(
               "var_input a real\nvar_input i int\nvar_input l lreal\nvar_input d dint\n" <>
                 "var_output p bool\nvar_output q bool\nvar_output r bool\n" <>
                 "gt a i ote p\nlt l d ote q\neq a l ote r",
               %{"a" => 1.5, "i" => 1, "l" => 1.5, "d" => 2}
             ) == %{"p" => 1, "q" => 1, "r" => 1}

      assert messages(
               "var a real\nvar d dint\nvar w word\nvar_output q bool\ngt a d ote q\ngt a w ote q"
             ) == [
               {5,
                "`gt` compares `a`, a real (declared on line 1), with `d`, a dint (declared on " <>
                  "line 2): a dint does not widen into a real, so convert it first, with " <>
                  "`dint_to_real`"},
               {6,
                "`gt` compares `a`, a real (declared on line 1), with `w`, a word (declared on " <>
                  "line 3): a real compares only with a number, and logex has no conversion " <>
                  "between a real and a bit string"}
             ]
    end

    test "a literal beside a tag is one of the tag's type" do
      assert messages(
               "var a real\nvar i int\nvar_output q bool\ngt i 1.5 ote q\ngt a 16777217 ote q"
             ) ==
               [
                 {4,
                  "`gt` compares `1.5` with `i`, an int (declared on line 2), which never holds " <>
                    "it: `1.5` is a real, and an int holds only integers"},
                 {5,
                  "`gt` compares `16777217` with `a`, a real (declared on line 1), which never " <>
                    "holds it: `16777217` is no value of a real, which holds integers exactly " <>
                    "only to 2^24: the nearest it holds is 16777216.0"}
               ]

      assert outputs("var_input a real\nvar_output q bool\ngt a 37.5 ote q", %{"a" => 40.0}) ==
               %{"q" => 1}
    end
  end

  describe "the 34 real conversions (decisions 148 and 161)" do
    defp converted(word, from, value) do
      to = word |> String.split(["_to_", "_trunc_"]) |> List.last()

      {outputs, _env, []} =
        scan(
          "var_input a #{from}\nvar_output x #{to}\n" <>
            "var_output q bool\n#{word} a x ote q",
          %{"a" => value}
        )

      {outputs["x"], outputs["q"]}
    end

    # IEC's examples (Ed 3 Table 22 footnote b; 1756-RM018A pp.872-875): a tie to the even
    # neighbour, which Elixir's round/1, ties away from zero, would not give.
    test "a real into an integer rounds to the nearest, a tie to the even neighbour" do
      for {value, rounded} <- [
            {1.5, 2},
            {2.5, 2},
            {-1.5, -2},
            {-2.5, -2},
            {1.6, 2},
            {1.4, 1},
            {0.5, 0},
            {3.5, 4},
            {-0.5, 0}
          ],
          from <- ["real", "lreal"],
          do: assert(converted("#{from}_to_int", from, value) == {rounded, 1}, inspect(value))

      refute round(2.5) == 2
    end

    # Decision 161: round, then wrap, with no power, as IEC and Logix do.
    test "a rounded value outside its target is wrapped, with no power" do
      for {value, wrapped, power} <- [
            {32767.6, -32768, 0},
            {32768.4, -32768, 0},
            {40000.7, -25535, 0},
            {70000.4, 4464, 0},
            {32767.4, 32767, 1},
            {-32768.4, -32768, 1},
            {-32769.0, 32767, 0}
          ],
          from <- ["real", "lreal"],
          do: assert(converted("#{from}_to_int", from, value) == {wrapped, power}, inspect(value))

      # Truncated before it wraps, as the record first read it, 32767.6 would give 32767
      # and 40000.7 -25536.
      refute converted("real_to_int", "real", 32767.6) == {32767, 0}
      assert converted("lreal_to_usint", "lreal", 255.5) == {0, 0}
      assert converted("lreal_to_ulint", "lreal", -1.0) == {18_446_744_073_709_551_615, 0}
    end

    test "an integer into a real is its nearest, rounded once, and always fits" do
      assert converted("dint_to_real", "dint", 16_777_217) == {16_777_216.0, 1}

      assert converted("lint_to_lreal", "lint", 9_007_199_254_740_993) ==
               {9_007_199_254_740_992.0, 1}

      # Through a double it would round twice: 2^60 + 2^36 + 1 has the single 2^60 + 2^37.
      n = Integer.pow(2, 60) + Integer.pow(2, 36) + 1

      assert converted("lint_to_real", "lint", n) ==
               {(Integer.pow(2, 60) + Integer.pow(2, 37)) * 1.0, 1}

      assert converted("ulint_to_real", "ulint", 18_446_744_073_709_551_615) ==
               {1.8446744073709552e19, 1}
    end

    test "between the two reals" do
      assert converted("real_to_lreal", "real", 0.1) == {single(0.1), 1}
      assert converted("lreal_to_real", "lreal", 0.1) == {single(0.1), 1}
      assert converted("lreal_to_real", "lreal", 1.0e39) == {@single_max, 0}
      assert converted("lreal_to_real", "lreal", -1.0e39) == {-@single_max, 0}
      assert converted("lreal_to_real", "lreal", 1.0e-40) == {0.0, 1}
    end
  end

  describe "the 16 truncations (decision 162)" do
    test "toward zero, and wrapped where it does not fit, with no power" do
      for from <- ["real", "lreal"] do
        assert converted("#{from}_trunc_int", from, -1.6) == {-1, 1}
        assert converted("#{from}_trunc_int", from, 37.9) == {37, 1}
        assert converted("#{from}_trunc_int", from, 40000.7) == {-25536, 0}
        assert converted("#{from}_trunc_usint", from, -0.9) == {0, 1}
      end
    end

    test "`trunc_int` is no mnemonic" do
      assert messages("var a real\nvar i int\ntrunc_int a i") == [
               {3, "unknown instruction `trunc_int`"}
             ]
    end
  end

  describe "sqrt (decisions 164 and 167)" do
    test "the root of a number, computed in its destination's real" do
      assert outputs(
               "var_input a real\nvar_input i int\nvar_output x real\nvar_output y lreal\n" <>
                 "var_output q bool\nsqrt a x ote q\nsqrt i y",
               %{"a" => 2.0, "i" => 9}
             ) == %{"x" => single(:math.sqrt(2.0)), "y" => 3.0, "q" => 1}
    end

    # PLAN M5-10's Done-when.
    test "a negative source writes 0.0 with no power and the minor fault `:negative_sqrt`" do
      {outputs, _env, faults} =
        scan(
          "var_input a real\nvar_output x real\nvar_output q bool\nsqrt a x ote q",
          %{"a" => -0.25}
        )

      assert outputs["x"] === 0.0
      assert outputs["q"] == 0

      assert faults == [
               %Fault{
                 severity: :minor,
                 kind: :negative_sqrt,
                 instruction: :sqrt,
                 path: nil,
                 file: nil,
                 line: 4,
                 read: -0.25
               }
             ]
    end

    test "a literal negative source is refused, `-0.0` taken, and an integer destination refused" do
      assert messages("var x real\nvar d dint\nsqrt -4.0 x\nsqrt 4.0 d") == [
               {3,
                "`sqrt` takes the root of the literal `-4.0`: a negative source gives 0.0, " <>
                  "passes no power and raises a minor fault on every scan, so a literal one is " <>
                  "refused"},
               {4,
                "`sqrt` writes a real, but `d` is a dint (declared on line 2): a square root is " <>
                  "a real's, so declare it a real or an lreal"}
             ]

      assert outputs("var_output x real\nsqrt -0.0 x") == %{"x" => 0.0}
    end
  end

  describe "a real's value from a host (decision 166) and in a state (decision 150)" do
    test "an integer input is stored as the nearest real, only one past the range refused" do
      program =
        program(
          "var_input r real\nvar_input l lreal\nvar_output x real\nvar_output y lreal\nmove r x move l y"
        )

      state = Runtime.instance(program)

      {outputs, state} =
        Runtime.call(program, state, %{"r" => 16_777_217, "l" => Integer.pow(2, 53) + 1}, %Scan{
          now: 0,
          first: true
        })

      assert outputs == %{"x" => 16_777_216.0, "y" => 9_007_199_254_740_992.0}
      assert state.env["r"] === 16_777_216.0

      assert_raise ArgumentError,
                   "input `r` is a real: 340282366920938463463374607431768211456 is beyond a " <>
                     "real's range, -3.4028234663852886e38 to 3.4028234663852886e38",
                   fn -> Runtime.put_inputs(program, state, %{"r" => Integer.pow(2, 128)}) end

      assert_raise ArgumentError,
                   "input `r` is a real: its value must be a number, found nil",
                   fn -> Runtime.put_inputs(program, state, %{"r" => nil}) end

      # 3.4028235e38, which rounds to the single's largest value, is taken.
      assert %{env: %{"r" => @single_max}} =
               Runtime.put_inputs(program, state, %{"r" => 3.4028235e38})
    end

    test "a state's real holds one of its type's values: a float, never −0.0, no subnormal" do
      program = program("var r real\nvar l lreal\nvar_output q real\nmove r q")
      state = Runtime.instance(program)

      for {value, told} <- [
            {0, "its value must be a float, found 0"},
            {0.1, "0.1 is no value of a real, whose nearest is 0.10000000149011612"},
            {-0.0, "-0.0 is no value of a real, whose nearest is 0.0"},
            {1.0e-40, "1.0e-40 is no value of a real, whose nearest is 0.0"},
            {1.0e39,
             "1.0e39 is beyond a real's range, -3.4028234663852886e38 to 3.4028234663852886e38"}
          ] do
        assert_raise ArgumentError,
                     "state.env holds `r` outside its type: it is a real, and #{told}",
                     fn ->
                       Runtime.call(
                         program,
                         %{state | env: %{state.env | "r" => value}},
                         %{},
                         %Scan{
                           now: 0,
                           first: true
                         }
                       )
                     end
      end

      assert_raise ArgumentError,
                   "state.env holds `l` outside its type: it is an lreal, and -0.0 is no value " <>
                     "of an lreal, whose nearest is 0.0",
                   fn ->
                     Runtime.call(program, %{state | env: %{state.env | "l" => -0.0}}, %{}, %Scan{
                       now: 0,
                       first: true
                     })
                   end
    end

    test "scan.reals is the runtime's" do
      program = program("var_output q real\nmove 1.5 q")

      assert_raise ArgumentError,
                   "scan.reals is the runtime's, taken from the program: a host leaves it out, " <>
                     ~s|got: %{"q" => :real}|,
                   fn ->
                     Runtime.call(program, Runtime.instance(program), %{}, %Scan{
                       now: 0,
                       first: true,
                       reals: %{"q" => :real}
                     })
                   end
    end

    # The reals a program carries are the ones its tags give, which only a program edited by
    # hand departs from, refused where it is handed in, as its units are (decision 197).
    test "a program whose reals its tags do not give is refused where it is handed in" do
      program = program("var_output q real\nvar_output d dint\nmove 1.5 q")
      assert program.reals == %{"q" => :real}

      assert_raise ArgumentError,
                   "`p`'s reals give `d` the type :real, where it is a dint: `p` was edited by " <>
                     "hand after it compiled\n" <>
                     "`p`'s reals give `q` no real type, where it is a real: `p` was edited by " <>
                     "hand after it compiled",
                   fn -> Runtime.instance(%{program | reals: %{"d" => :real}}) end

      assert_raise ArgumentError,
                   "`p`'s reals are neither nil nor a map of tag names to real types, got: :x: " <>
                     "`p` was edited by hand after it compiled",
                   fn -> Runtime.instance(%{program | reals: :x}) end
    end
  end

  describe "a block's formals (decision 159)" do
    test "an integer into a real formal, and an integer formal into a real tag" do
      {:ok, half} =
        Logex.compile(
          "function_block half\nvar_input a real\nvar_output h real\nvar_output n int\n" <>
            "div a 2 h move 3 n",
          name: "half"
        )

      {:ok, program} =
        Logex.compile(
          "var_input i int\nvar_output x real\nvar_output y lreal\nvar s half\ncal s i x y",
          name: "p",
          types: [half]
        )

      {outputs, _state} =
        Runtime.call(program, Runtime.instance(program), %{"i" => 7}, %Scan{now: 0, first: true})

      assert outputs == %{"x" => 3.5, "y" => 3.0}
    end
  end

  describe "an online edit (decision 157)" do
    defp edited(from, to) do
      running = program(from)
      state = Runtime.instance(running)
      {_outputs, state} = Runtime.call(running, state, %{}, %Scan{now: 0, first: true})
      {:ok, edit, forecast} = Edit.accept(running, program(to), state)
      {_edit, state, report} = Edit.test(edit, state)
      assert report == forecast
      {state, report}
    end

    # PLAN M5-10's Done-when: `{0, 0.0}`, the running 0.0 kept, compared exactly, where an
    # `==` would read 0 and 0.0 as one value and report nothing.
    test "`var x real 0` edited to `var x real 0.0` is a changed initial value" do
      {state, report} =
        edited(
          "var x real 0\nvar_output q real\nmove x q",
          "var x real 0.0\nvar_output q real\nmove x q"
        )

      assert report == [{:initial_changed, "x", {0, 0.0}}]
      assert state.env["x"] === 0.0
    end

    test "an initial value respelled, `0.5` as `5.0e-1`, is no change" do
      assert {_state, []} =
               edited(
                 "var x real 0.5\nvar_output q real\nmove x q",
                 "var x real 5.0e-1\nvar_output q real\nmove x q"
               )
    end

    test "a type change between the reals is refused" do
      running = program("var x real\nvar_output q real\nmove x q")

      assert {:error, [%Logex.Diagnostic{stage: :edit, line: 1}]} =
               Edit.accept(
                 running,
                 program("var x lreal\nvar_output q real\nlreal_to_real x q"),
                 Runtime.instance(running)
               )
    end

    test "an edit that only respells a real literal changes no rung" do
      assert {_state, []} =
               edited("var_output q real\nmove 1500.0 q", "var_output q real\nmove 1.5e3 q")
    end
  end

  describe "a configuration (decisions 150, 156 and 166)" do
    defp resource(text, programs) do
      {:ok, config} = Configuration.compile("plant", text, programs)
      Runtime.start(config)
    end

    test "a real global's initial value, an input point's integer, and a copy-out widened" do
      {:ok, fan} =
        Logex.compile(
          "var_input hz real\nvar_input count int\nvar_output speed real\nvar_output whole int\n" <>
            "move hz speed move count whole",
          name: "fan"
        )

      runtime =
        resource(
          "var_global sp real 0.1\nvar_global hz real at drive.i.0\nvar_global n int at drive.i.1\n" <>
            "var_global out real\nvar_global w lreal\nprogram f fan\nf.hz hz\nf.count n\n" <>
            "f.speed out\nf.whole w\n",
          %{"fan" => fan}
        )

      assert Runtime.get!(runtime, "sp") === 0.10000000149011612

      {runtime, _outputs, _events} = Runtime.cycle(runtime, 0, %{"hz" => 16_777_217, "n" => 3})
      assert Runtime.get!(runtime, "hz") === 16_777_216.0
      assert Runtime.get!(runtime, "f.speed") === 16_777_216.0
      assert Runtime.get!(runtime, "out") === 16_777_216.0
      assert Runtime.get!(runtime, "w") === 3.0

      assert_raise ArgumentError, ~r/beyond a real's range/, fn ->
        Runtime.cycle(runtime, 0, %{"hz" => Integer.pow(2, 128)})
      end
    end

    # Decision 156: a real global's initial value prints in the shortest text that reads
    # back to it, a single's for a `real`, and the round trip is exact.
    test "a real global prints as the shortest text that reads back to it" do
      text = "var_global sp real 0.1\nvar_global big lreal 0.1\nvar_global z real 0\n"
      {:ok, entries} = Configuration.Text.read(text)
      [sp, big, z] = entries
      assert sp.initial === 0.10000000149011612
      assert big.initial === 0.1
      assert z.initial === 0
      assert Configuration.Text.print(entries) == text
      assert Configuration.Text.read(Configuration.Text.print(entries)) == {:ok, entries}
    end

    test "a real constant connects, judged by the literal rules" do
      {:ok, fan} =
        Logex.compile("var_input hz real\nvar_output speed real\nmove hz speed", name: "fan")

      runtime = resource("program f fan\nf.hz 37.5\n", %{"fan" => fan})
      {runtime, _outputs, _events} = Runtime.cycle(runtime, 0, %{})
      assert Runtime.get!(runtime, "f.speed") === 37.5

      assert {:error, [diagnostic]} =
               Configuration.compile("plant", "program f fan\nf.hz 16777217\n", %{"fan" => fan})

      assert diagnostic.message =~ "the nearest it holds is 16777216.0"
    end

    test "a negative root is a cycle's event, just after its scan's run" do
      {:ok, fan} =
        Logex.compile("var_input hz real\nvar_output s real\nsqrt hz s", name: "fan")

      runtime =
        resource("var_global hz real at drive.i.0\nprogram f fan\nf.hz hz\n", %{"fan" => fan})

      {_runtime, _outputs, events} = Runtime.cycle(runtime, 0, %{"hz" => -4})

      assert [
               {:ran, :none, "f", _},
               {:fault, :none, "f",
                %Fault{severity: :minor, kind: :negative_sqrt, line: 3, read: -4.0}}
             ] = events
    end

    test "a changed real global's initial value is reported exactly" do
      {:ok, fan} = Logex.compile("var_input hz real\nvar_output s real\nmove hz s", name: "fan")

      {:ok, a} =
        Configuration.compile("plant", "var_global x real 0\nprogram f fan\nf.hz x\n", %{
          "fan" => fan
        })

      {:ok, b} =
        Configuration.compile("plant", "var_global x real 0.0\nprogram f fan\nf.hz x\n", %{
          "fan" => fan
        })

      runtime = Runtime.start(a)
      {:ok, edit, forecast} = Configuration.Edit.accept(runtime, b)
      assert forecast == [{:initial_changed, "x", {0, 0.0}}]
      {_edit, _runtime, report} = Configuration.Edit.test(edit, runtime)
      assert report == forecast
    end
  end

  describe "a seeded walk near each real's limits (PLAN M5-10's Done-when)" do
    @limits [
      0.0,
      1.0,
      -1.0,
      0.1,
      @single_max,
      -@single_max,
      3.4028235e38,
      @single_min,
      -@single_min,
      1.0e-40,
      1.0e-310,
      @double_max,
      -@double_max,
      2.2250738585072014e-308,
      1.0e300,
      -1.0e300,
      16_777_217,
      0,
      -32768
    ]

    # Every arithmetic instruction, conversion and root over values drawn near the limits,
    # zero divisors and subnormals: no float exception leaves a scan, and every real the
    # state holds is a value of its type, never −0.0, an infinity or a subnormal.
    test "no float exception leaves a scan, and no state holds −0.0 or a subnormal" do
      source =
        "var_input a real\nvar_input b real\nvar_input c lreal\nvar_input d lreal\n" <>
          "var x real\nvar y lreal\nvar i int\nvar j lint\nvar_output q bool\n" <>
          "add a b x add c d y sub a b x sub c d y mul a b x mul c d y\n" <>
          "div a b x div c d y neg a x abs c y sqrt a x sqrt c y\n" <>
          "real_to_lreal a y lreal_to_real c x real_to_int a i lreal_to_lint c j\n" <>
          "real_trunc_int a i lreal_trunc_lint d j mul x x x mul y y y ote q"

      program = program(source)
      :rand.seed(:exsss, {10, 20, 30})

      for _ <- 1..2000 do
        inputs = %{
          "a" => single_input(Enum.random(@limits)),
          "b" => single_input(Enum.random(@limits)),
          "c" => Enum.random(@limits) * 1.0,
          "d" => Enum.random(@limits) * 1.0
        }

        {_outputs, state} =
          Runtime.call(program, Runtime.instance(program), inputs, %Scan{now: 0, first: true})

        for {name, type} <- [{"x", :real}, {"y", :lreal}, {"a", :real}, {"c", :lreal}] do
          value = state.env[name]
          assert is_float(value), inspect({name, value})
          refute value === -0.0, inspect({name, inputs})
          assert value === 0.0 or abs(value) >= min_of(type), inspect({name, value, inputs})
          assert abs(value) <= max_of(type), inspect({name, value})
          assert type == :lreal or single(value) === value, inspect({name, value})
        end
      end
    end

    defp single_input(x) when is_float(x) and abs(x) > 3.4e38, do: x / 1.0e300
    defp single_input(x), do: x * 1.0

    defp min_of(:real), do: @single_min
    defp min_of(:lreal), do: 2.2250738585072014e-308
    defp max_of(:real), do: @single_max
    defp max_of(:lreal), do: @double_max
  end

  describe "cost (PLAN M5-10)" do
    defp reductions(fun) do
      parent = self()

      {_pid, ref} =
        :erlang.spawn_opt(
          fn ->
            {:reductions, before} = Process.info(self(), :reductions)
            fun.()
            {:reductions, later} = Process.info(self(), :reductions)
            send(parent, {:reductions, later - before})
          end,
          [:monitor, min_heap_size: 8_000_000]
        )

      assert_receive {:reductions, r}, 10_000
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
      r
    end

    defp per_rung(head, rung) do
      cost = fn n ->
        p = program(head <> Enum.map_join(1..n, "\n", fn _ -> rung end))
        state = Runtime.instance(p)

        inputs =
          for {k, %{section: :var_input, type: t}} <- p.tags,
              into: %{},
              do: {k, if(t in [:real, :lreal], do: 1.5, else: 1)}

        reductions(fn -> Runtime.call(p, state, inputs, %Scan{now: 0, first: true}) end)
      end

      (cost.(200) - cost.(100)) / 100
    end

    # A program of no reals carries `reals: nil`, which `move`'s first clause and a scan's
    # copy-out match in their heads, so it scans rung for rung in exactly what it did
    # before M5-10, at 5eac41f.
    test "a program of no reals scans as it did before M5-10" do
      assert per_rung("var_input a dint\nvar_output d dint\n", "move a d") == 17.0
      assert per_rung("var_input a dint\nvar_output d dint\n", "add a a d") == 34.0

      assert per_rung("var_input a dint\nvar_input b dint\nvar_output q bool\n", "gt a b ote q") ==
               27.0
    end

    test "a real's instruction costs within a small factor of a dint's" do
      dint = per_rung("var_input a dint\nvar_output d dint\n", "move a d")

      for type <- ["real", "lreal"] do
        assert per_rung("var_input a #{type}\nvar_output d #{type}\n", "move a d") <= 2.5 * dint
        assert per_rung("var_input a #{type}\nvar_output d #{type}\n", "add a a d") <= 1.5 * 34
        assert per_rung("var_input a #{type}\nvar_output d #{type}\n", "sqrt a d") <= 1.5 * 34
      end

      # A dint's `move` beside a real looks its destination up in the program's reals.
      assert per_rung("var_input r real\nvar_input a dint\nvar_output d dint\n", "move a d") <=
               dint + 4
    end

    test "a program of reals costs linear reductions to compile and to scan" do
      source = fn n ->
        "var_input a real\nvar_input b lreal\nvar_output x real\nvar_output y lreal\n" <>
          "var_output i int\n" <>
          Enum.map_join(1..n, "\n", fn _ ->
            "add a 1.5 x div b 0.5e1 y real_to_int x i sqrt a y gt a 37.5 move -2.5 x"
          end)
      end

      compile = fn n -> reductions(fn -> Logex.compile(source.(n), name: "p") end) end

      scan = fn n ->
        p = program(source.(n))
        state = Runtime.instance(p)
        inputs = %{"a" => 1.5, "b" => 2.0}
        reductions(fn -> Runtime.call(p, state, inputs, %Scan{now: 0, first: true}) end)
      end

      assert compile.(400) / compile.(200) < 2.2
      assert scan.(400) / scan.(200) < 2.2
    end
  end
end
