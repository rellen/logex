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

  alias Logex.{Configuration, Edit, Fault, Runner, Runtime, Scan}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

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

      # A real literal past its slot's range is refused, and since decision 216 one a write
      # would flush to 0.0 too.
      assert messages("var x real\nmove 1.0e39 x") == [
               {2,
                "`move` writes `1.0e39` into `x`, a real: it is beyond a real's range, " <>
                  "-3.4028234663852886e38 to 3.4028234663852886e38"}
             ]

      assert messages("var x real\nmove 1.0e-40 x") == [
               {2,
                "`move` writes `1.0e-40` into `x`, a real: it is too near 0.0 for a real, " <>
                  "whose smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0"}
             ]
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

      # M5-10's review: an lreal's difference past its range, which the BEAM raises on,
      # saturates at the sign of the difference, the minuend's, whatever the subtrahend's.
      assert outputs(
               "var_input l lreal\nvar_input m lreal\nvar_output y lreal\nvar_output z lreal\n" <>
                 "var_output p bool\nvar_output q bool\nsub l m y ote p\nsub m l z ote q",
               %{"l" => -1.7e308, "m" => 1.7e308}
             ) == %{"y" => -@double_max, "z" => @double_max, "p" => 0, "q" => 0}

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

    # PLAN M5-10's Done-when: 3.5e38, past a single's largest value, is what the BEAM's
    # 32-bit encoding would turn silently into an infinity's bits, so it is saturated before
    # it is stored.
    test "an lreal of 3.5e38 into a real is the single's largest value, with no power" do
      {outputs, env, []} =
        scan(
          "var_input l lreal\nvar_output x real\nvar_output q bool\nlreal_to_real l x ote q",
          %{"l" => 3.5e38}
        )

      assert outputs == %{"x" => @single_max, "q" => 0}
      assert env["x"] === @single_max
      assert <<0x7F7FFFFF::32>> == <<env["x"]::float-32>>
      assert <<0x7F800000::32>> == <<3.5e38::float-32>>
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

      # M5-10's review: an integer and a real of one value are equal, by value (decision
      # 147), an `int` 3 and a `real` 3.0, either side.
      assert outputs(
               "var_input a real\nvar_input i int\nvar_output p bool\nvar_output q bool\n" <>
                 "var_output r bool\nvar_output s bool\n" <>
                 "eq i a ote p\neq a i ote q\nne i a ote r\nge i a ote s",
               %{"a" => 3.0, "i" => 3}
             ) == %{"p" => 1, "q" => 1, "r" => 0, "s" => 1}

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

  # M5-10's review (provisional): a real literal is a value of the real its slot computes
  # in, as Logix stores an unsuffixed floating-point immediate as a REAL (1756-RM018A
  # p.870), IEC's rule for an untyped literal's type unverified, so a setpoint moved into a
  # `real` and compared with the very literal is reached. Each is restated through the
  # BEAM's 32-bit encoding, `single/1`.
  describe "a real literal is its slot's real (M5-10's review)" do
    test "`move 37.1 sp` then `ge sp 37.1` and `eq sp 37.1` are true, in a real and an lreal" do
      source =
        "var sp real\nvar lp lreal\nvar_output lamp bool\nvar_output same bool\n" <>
          "var_output under bool\nvar_output l bool\nvar_output m bool\n" <>
          "move 37.1 sp\nmove 0.1 lp\nge sp 37.1 ote lamp\neq sp 37.1 ote same\n" <>
          "gt 37.1 sp ote under\neq lp 0.1 ote l\neq 0.1 lp ote m"

      program = program(source)
      state = Runtime.instance(program)
      scan = %Scan{now: 0, first: true}
      {outputs, state} = Runtime.call(program, state, %{}, scan)

      assert outputs == %{"lamp" => 1, "same" => 1, "under" => 0, "l" => 1, "m" => 1}
      assert state.env["sp"] === single(37.1)
      assert state.env["lp"] === 0.1
      assert {^outputs, _state} = Runtime.call(program, state, %{}, %{scan | first: false})
    end

    test "a comparison's literal is the other operand's real, either side" do
      assert outputs(
               "var_input r real\nvar_output p bool\nvar_output q bool\nvar_output s bool\n" <>
                 "var_output t bool\neq r 0.1 ote p\neq 0.1 r ote q\ngt r 0.1 ote s\n" <>
                 "lt 0.1 r ote t",
               %{"r" => single(0.1)}
             ) == %{"p" => 1, "q" => 1, "s" => 0, "t" => 0}

      # An lreal's literal is the double, which the single 0.1 is not.
      assert outputs(
               "var_input l lreal\nvar_output p bool\nvar_output q bool\neq l 0.1 ote p\n" <>
                 "gt l 0.1 ote q",
               %{"l" => single(0.1)}
             ) == %{"p" => 0, "q" => 1}

      # A subnormal literal beside an lreal is one it never holds (decisions 216 and 228).
      assert messages("var_input l lreal\nvar_output p bool\neq l 1.0e-310 ote p") == [
               {3,
                "`eq` compares `1.0e-310` with `l`, an lreal (declared on line 1), which never " <>
                  "holds it: `1.0e-310` is too near 0.0 for an lreal, whose smallest above 0.0 " <>
                  "is 2.2250738585072014e-308: it would be written as 0.0"}
             ]

      # 16777217.0 in a `real`'s slot is the single 16777216.0.
      assert outputs("var_input r real\nvar_output p bool\neq r 16777217.0 ote p", %{
               "r" => 16_777_216.0
             }) == %{"p" => 1}
    end

    # The review's cases: `mul` and `div` by a literal computed on the double differ from
    # the single's in 10% to 57% of draws; here, one of each, in a `real` and an `lreal`.
    test "an arithmetic literal is its destination's real, rounded once" do
      {outputs, env, []} =
        scan(
          "var_input a real\nvar_output q real\nvar_output m real\nvar_output s real\n" <>
            "var_output l lreal\nvar_output n lreal\n" <>
            "div a 0.1 q\nmul a 1.1 m\nadd a 0.3 s\ndiv a 0.1 l\nmul a 1.1 n",
          %{"a" => 37.1}
        )

      a = single(37.1)
      assert env["a"] === a
      assert outputs["q"] === single(a / single(0.1))
      assert outputs["q"] === 370.9999694824219
      assert single(a / 0.1) === 371.0
      assert outputs["m"] === single(a * single(1.1))
      assert outputs["s"] === single(a + single(0.3))
      assert outputs["l"] === a / 0.1
      assert outputs["n"] === a * 1.1
    end

    test "a conversion's literal is its source type's real, and sqrt's its destination's" do
      {outputs, _env, []} =
        scan(
          "var_output l lreal\nvar_output r real\nvar_output k lreal\nvar_output z real\n" <>
            "var_output y real\n" <>
            "real_to_lreal 0.1 l\nlreal_to_real 0.1 r\nsqrt 0.1 k\nsqrt 1.0e-30 z\n" <>
            "lreal_to_real 1.0e-40 y"
        )

      assert outputs["l"] === 0.10000000149011612
      assert outputs["r"] === single(0.1)
      assert outputs["k"] === :math.sqrt(0.1)
      assert outputs["z"] === single(:math.sqrt(single(1.0e-30)))
      # 1.0e-40 is an lreal's, and the conversion flushes it into the real.
      assert outputs["y"] === 0.0

      # In a `real`'s slot 1.0e-40 is refused (decision 216), sqrt's and a conversion's
      # source alike.
      assert messages("var z real\nvar y lreal\nsqrt 1.0e-40 z\nreal_to_lreal 1.0e-40 y") == [
               {3,
                "`sqrt` computes in `z`'s type, a real: `1.0e-40` is too near 0.0 for a real, " <>
                  "whose smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0"},
               {4,
                "`real_to_lreal` reads a real: `1.0e-40` is too near 0.0 for a real, whose " <>
                  "smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0"}
             ]
    end

    # The rounded literal keeps its spelling, so every message quotes it as written, and an
    # edit that only respells it changes no rung.
    test "a rounded literal is quoted as written, and lowers to its single" do
      program = program("var_output x real\nvar_output y lreal\nmove 0.1 x move 0.1 y")

      assert [
               rung: [
                 {:move, 3, [{:real_lit, 3, 0.10000000149011612, "0.1"}, {:name, 3, "x"}]},
                 {:move, 3, [{:real_lit, 3, 0.1}, {:name, 3, "y"}]}
               ]
             ] = program.rungs

      assert warnings("var_output x real\nadd 0.1 1.0e-1 x") == [
               {2, "`add` reads two literals, `0.1` and `1.0e-1`: its result never changes"}
             ]

      running = program("var_output x real\nvar r real\nmove r x\nmove 0.1 r")
      state = Runtime.instance(running)
      {_outputs, state} = Runtime.call(running, state, %{}, %Scan{now: 0, first: true})

      assert {:ok, _edit, []} =
               Edit.accept(
                 running,
                 program("var_output x real\nvar r real\nmove r x\nmove 1.0e-1 r"),
                 state
               )
    end

    # A compiled body holds each real literal at its slot's value, which lowering its
    # spelling again gives, and no other: a hand edit of the value, a single in an lreal's
    # slot or a double in a real's, is no compiled body.
    test "a compiled body's real literal is its slot's value, and no other" do
      {:ok, keep} =
        Logex.compile(
          "function_block keep\nvar_output x real\nvar_output y lreal\nmove 0.1 x\nmove 0.1 y",
          name: "keep"
        )

      body = keep.body
      assert Logex.Compiler.lowered?(body)

      [
        rung: [{:move, 4, [rounded, x]}],
        rung: [{:move, 5, [plain, y]}]
      ] = body.rungs

      assert rounded == {:real_lit, 4, 0.10000000149011612, "0.1"}
      assert plain == {:real_lit, 5, 0.1}

      for {real, lreal} <- [
            {{:real_lit, 4, 0.1, "0.1"}, plain},
            {{:real_lit, 4, 0.1}, plain},
            {rounded, {:real_lit, 5, 0.10000000149011612, "0.1"}},
            {rounded, {:real_lit, 5, 0.2, "0.1"}},
            {rounded, {:real_lit, 5, 0.1, "0.1"}},
            {rounded, {:real_lit, 5, 0.1, "zero"}}
          ] do
        rungs = [rung: [{:move, 4, [real, x]}], rung: [{:move, 5, [lreal, y]}]]

        refute Logex.Compiler.lowered?(%{
                 body
                 | rungs: rungs,
                   warnings: Logex.Warnings.of(rungs, body.tags)
               }),
               inspect({real, lreal})
      end
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
      # A tie between two singles goes to the even one: 16777219 lies halfway between
      # 16777218 and 16777220, whose last bit is 0, and 16777221 between 16777220 and
      # 16777222, the even one 16777220 again.
      assert converted("dint_to_real", "dint", 16_777_219) == {single(16_777_219.0), 1}
      assert single(16_777_219.0) === 16_777_220.0
      assert converted("dint_to_real", "dint", 16_777_221) == {16_777_220.0, 1}
      assert converted("dint_to_real", "dint", -16_777_219) == {-16_777_220.0, 1}

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

      # M5-10's review: 2^128 − 2^103, half a step past the single's largest value, is the
      # least magnitude whose nearest single is infinite, IEEE 754's tie to even rounding it
      # up, so it is refused, as a float, either sign, and the double just below it taken.
      past = 3.4028235677973366e38
      assert past == Integer.pow(2, 128) - Integer.pow(2, 103)
      <<below::float-64>> = <<(<<past::float-64>> |> :binary.decode_unsigned()) - 1::64>>

      for value <- [past, -past] do
        assert_raise ArgumentError,
                     "input `r` is a real: #{inspect(value)} is beyond a real's range, " <>
                       "-3.4028234663852886e38 to 3.4028234663852886e38",
                     fn -> Runtime.put_inputs(program, state, %{"r" => value}) end
      end

      assert %{env: %{"r" => @single_max}} = Runtime.put_inputs(program, state, %{"r" => below})
      assert %{env: %{"r" => -@single_max}} = Runtime.put_inputs(program, state, %{"r" => -below})
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

      {outputs, state} =
        Runtime.call(program, Runtime.instance(program), %{"i" => 7}, %Scan{now: 0, first: true})

      assert outputs == %{"x" => 3.5, "y" => 3.0}

      # M5-10's review: compared exactly, since `==` takes 7 for 7.0. The formal holds the
      # float its operand widens to, and the tag the float its formal widens to, so the state
      # a scan leaves is one the next scan takes.
      assert state.env["s"]["a"] === 7.0
      assert state.env["y"] === 3.0
      assert outputs["y"] === 3.0

      {outputs, state} = Runtime.call(program, state, %{"i" => 8}, %Scan{now: 10, first: false})
      assert outputs["x"] === 4.0 and outputs["y"] === 3.0
      assert state.env["s"]["a"] === 8.0
    end

    # M5-10's review: a literal operand of a real formal is the formal's nearest value, a
    # single's in a `real`, as `move 0.1 x` writes it, and the scan after takes it.
    test "a real literal into a real formal is the formal's nearest value" do
      {:ok, keep} =
        Logex.compile(
          "function_block keep\nvar_input a real\nvar_input b lreal\nvar_output h real\n" <>
            "move a h",
          name: "keep"
        )

      {:ok, program} =
        Logex.compile("var_output x real\nvar s keep\ncal s 0.1 0.1 x", name: "p", types: [keep])

      {outputs, state} =
        Runtime.call(program, Runtime.instance(program), %{}, %Scan{now: 0, first: true})

      assert outputs["x"] === 0.10000000149011612
      assert state.env["s"]["a"] === 0.10000000149011612
      assert state.env["s"]["b"] === 0.1
      assert {_outputs, _state} = Runtime.call(program, state, %{}, %Scan{now: 10, first: false})
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

      # M5-10's review: a single whose shortest spelling takes nine significant digits, the
      # most any single needs, 104.696724 for 104.69672393798828, which no eight-digit text
      # reads back to.
      nine = "var_global sp real 104.696724\n"
      {:ok, [sp]} = Configuration.Text.read(nine)
      assert sp.initial === 104.69672393798828
      assert single(1.0469672e2) !== sp.initial and single(1.0469673e2) !== sp.initial
      assert Configuration.Text.print([sp]) == nine
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

  describe "points and forces through the runner (decisions 156 and 166)" do
    defp fan_plant do
      {:ok, fan} =
        Logex.compile(
          "var_input hz real\nvar_input big lreal\nvar_output speed real\nmul hz 2.0 speed",
          name: "fan"
        )

      {:ok, config} =
        Configuration.compile(
          "plant",
          "task fast interval 10 priority 1\n" <>
            "var_global hz real at drive.i.0\nvar_global big lreal at drive.i.1\n" <>
            "var_global speed real at drive.q.0\n" <>
            "program f fan with fast\nf.hz hz\nf.big big\nf.speed speed\n",
          %{"fan" => fan}
        )

      config
    end

    defp run_fan(file) do
      {:ok, clock} = Manual.start_link()
      {:ok, sim} = Sim.start_link(clock: clock)

      started =
        Runner.start_link(
          configuration: fan_plant(),
          io: %{"drive" => {Sim, sim: sim}},
          clock: {Manual, clock},
          forces: file
        )

      {started, clock, sim}
    end

    defp raised(fun) do
      fun.()
      flunk("no raise")
    rescue
      error in ArgumentError -> error.message
    end

    @tag :tmp_dir
    test "a device's reading is stored as its nearest real, and one past the range trips",
         %{tmp_dir: dir} do
      {{:ok, runner}, clock, sim} = run_fan(Path.join(dir, "forces"))

      for {reading, stored} <- [
            {37.5, 37.5},
            {0.1, single(0.1)},
            {16_777_217, 16_777_216.0},
            {-0.0, 0.0},
            {1.0e-40, 0.0},
            {3.4028235e38, @single_max}
          ] do
        Sim.set(sim, [0], reading)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "hz") === stored, inspect(reading)
      end

      Sim.set(sim, [0], 37.5)
      Sim.set(sim, [1], Integer.pow(2, 53) + 1)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "big") === Integer.pow(2, 53) * 1.0
      Sim.set(sim, [1], 0.1)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "big") === 0.1
      assert Sim.outputs(sim) == %{[0] => 75.0}

      Sim.set(sim, [0], Integer.pow(2, 128))
      Manual.advance(clock, 10)

      assert Runner.status(runner).trip ==
               {:io, "drive", {:bad_value, [0], Integer.pow(2, 128)}}

      Runner.stop(runner)
    end

    @tag :tmp_dir
    test "a force is held to its type's nearest value, and the forces file reads back exactly",
         %{tmp_dir: dir} do
      file = Path.join(dir, "forces")
      {{:ok, runner}, clock, _sim} = run_fan(file)

      assert raised(fn -> Runner.force(runner, "hz", Integer.pow(2, 128)) end) ==
               "`hz` is a real, forced to a number from -3.4028234663852886e38 to " <>
                 "3.4028234663852886e38, got: 340282366920938463463374607431768211456"

      assert raised(fn -> Runner.force(runner, "hz", :fast) end) =~ "got: :fast"

      assert Runner.force(runner, "hz", 16_777_217) == :ok
      assert Runner.status(runner).forces == %{"hz" => 16_777_216.0}
      assert Runner.force(runner, "hz", 0.1) == :ok
      assert Runner.force(runner, "big", 0.1) == :ok
      assert Runner.status(runner).forces == %{"hz" => single(0.1), "big" => 0.1}
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "hz") === single(0.1)

      # The shortest text that reads back to each value, a single's for a `real`.
      assert File.read!(file) == "big 0.1\nhz 0.1\n"
      Runner.stop(runner)

      {{:ok, runner}, clock, _sim} = run_fan(file)
      assert Runner.status(runner).forces == %{"hz" => single(0.1), "big" => 0.1}
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "hz") === single(0.1)
      assert Runner.get!(runner, "big") === 0.1
      Runner.stop(runner)

      for value <- [@single_max, -@single_min, 37.5, 1.0e10, 16_777_216.0] do
        {{:ok, runner}, _clock, _sim} = run_fan(file)
        assert Runner.force(runner, "hz", value) == :ok
        Runner.stop(runner)
        {{:ok, runner}, _clock, _sim} = run_fan(file)
        assert Runner.status(runner).forces["hz"] === value
        Runner.stop(runner)
      end

      # Since decision 218 a real point's line is any number that is a value of its type,
      # held at its nearest, and the next force writes the file in the runner's spelling.
      File.write!(file, "hz 0.10000000149011612\nbig 3\n")
      {{:ok, runner}, _clock, _sim} = run_fan(file)
      assert Runner.status(runner).forces === %{"hz" => single(0.1), "big" => 3.0}
      assert File.read!(file) == "hz 0.10000000149011612\nbig 3\n"
      assert Runner.unforce(runner, "big") == :ok
      assert File.read!(file) == "hz 0.1\n"
      Runner.stop(runner)

      File.write!(file, "hz 1.0\nhz 2.0\n")

      assert raised(fn -> run_fan(file) end) ==
               "#{file}: line 2: `hz` is forced on line 1 already"

      File.write!(file, "hz 1.0e39\nbig 0.5x\n")

      assert raised(fn -> run_fan(file) end) ==
               "#{file}: line 1: `hz` is a real, forced to a number from " <>
                 "-3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0e39\n" <>
                 "#{file}: line 2: `big 0.5x` is no force: a line holds an input point's name " <>
                 "and its value, as `eye_1 1`"
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

  # The maintainer's answers to M5-10's five questions, 2026-10-23 (docs/organisation.md §7).
  # Decision 215, sqrt's source any number that widens into its destination's real and its
  # destination a real, is pinned in "sqrt (decisions 164 and 167)" above, and decision 217,
  # a flushed result passing power, in "−0.0 and a subnormal are written as 0.0".
  describe "a real literal nearer 0.0 than its slot's real holds (decision 216)" do
    @flushed "it would be written as 0.0"

    test "is refused in every slot of a real, and 0.0 is taken however it is written" do
      assert messages(
               "var_input a real\nvar r real\nvar i int\nvar_output q bool\n" <>
                 "move 1.0e-40 r\nadd a -1.0e-40 r\nlt a 1.0e-40 ote q\nreal_to_int 1.0e-40 i"
             ) == [
               {5,
                "`move` writes `1.0e-40` into `r`, a real: it is too near 0.0 for a real, " <>
                  "whose smallest above 0.0 is 1.1754943508222875e-38: " <> @flushed},
               {6,
                "`add` computes in `r`'s type, a real: `-1.0e-40` is too near 0.0 for a real, " <>
                  "whose smallest above 0.0 is 1.1754943508222875e-38: " <> @flushed},
               {7,
                "`lt` compares `1.0e-40` with `a`, a real (declared on line 1), which never " <>
                  "holds it: `1.0e-40` is too near 0.0 for a real, whose smallest above 0.0 is " <>
                  "1.1754943508222875e-38: " <> @flushed},
               {8,
                "`real_to_int` reads a real: `1.0e-40` is too near 0.0 for a real, whose " <>
                  "smallest above 0.0 is 1.1754943508222875e-38: " <> @flushed}
             ]

      for zero <- ["0.0", "-0.0", "0.0e-400", "-0_0.0e-9_99"] do
        assert outputs("var_output r real\nvar_output l lreal\nmove #{zero} r\nmove #{zero} l") ===
                 %{"r" => 0.0, "l" => 0.0},
               zero
      end
    end

    # The edge is the literal's nearest single: one that rounds up to the smallest normal is
    # a single's, and one that rounds to the largest subnormal is not.
    test "is judged by the value a write gives it, at the smallest normal's edge" do
      assert outputs("var_output r real\nmove 1.1754943e-38 r") === %{"r" => @single_min}

      assert outputs("var_output r real\nmove -1.1754943508222875e-38 r") === %{
               "r" => -@single_min
             }

      assert single(1.1754942e-38) < @single_min
      assert [{2, message}] = messages("var r real\nmove 1.1754942e-38 r")
      assert message =~ "it is too near 0.0 for a real"
    end

    # Since decision 228 a literal whose double is subnormal is that double, refused by its
    # slot (below); and since decision 231 one no double holds but 0.0 is 0.0 spelled,
    # refused by its slot in the same words, where until then the lexer refused it as no
    # number logex holds; 1.0e-40 is an lreal's.
    test "below every double but 0.0, it is 0.0 spelled, refused by its slot" do
      for source <- [
            "move 1.0e-400 x",
            "move 1_0.0e-4_00 x",
            "move -2.0e-324 x"
          ] do
        [_move, run, _x] = String.split(source, " ")

        assert {:ok, [_, {:real_lit, {1, 6}, zero, ^run}, _], 1} = lexed(source), source
        assert zero === 0.0

        assert messages("var x lreal\n" <> source) == [
                 {2,
                  "`move` writes `#{run}` into `x`, an lreal: it is too near 0.0 for an lreal, " <>
                    "whose smallest above 0.0 is 2.2250738585072014e-308: it would be written as 0.0"}
               ],
               source
      end

      assert {:ok, _, 1} = lexed("move 2.2250738585072014e-308 x")
      assert outputs("var_output l lreal\nmove 1.0e-40 l") === %{"l" => 1.0e-40}

      assert outputs("var_output l lreal\nmove 2.2250738585072014e-308 l") ===
               %{"l" => 2.2250738585072014e-308}
    end

    test "is refused as a block's real formal" do
      {:ok, keep} =
        Logex.compile(
          "function_block keep\nvar_input a real\nvar_output b real\nmove a b",
          name: "keep"
        )

      assert {:error, [%Logex.Diagnostic{line: 3, message: message}]} =
               Logex.compile("var k keep\nvar_output r real\ncal k 1.0e-40 r",
                 name: "p",
                 types: [keep]
               )

      assert message ==
               "operand 1 of `cal k` is `a` (var_input real): `1.0e-40` is too near 0.0 for a " <>
                 "real, whose smallest above 0.0 is 1.1754943508222875e-38: " <> @flushed
    end

    test "is refused as a declaration's, a global's and an Elixir tag's initial value" do
      assert messages("var r real 1.0e-40\nxic r") |> hd() ==
               {1,
                "`r` is a real: `1.0e-40` is too near 0.0 for a real, whose smallest above 0.0 " <>
                  "is 1.1754943508222875e-38: " <> @flushed}

      assert {:error, [%Logex.Diagnostic{line: 1, message: message} | _]} =
               Configuration.compile("c", "var_global sp real 1.0e-40\n", %{})

      assert message ==
               "`sp` is a real: `1.0e-40` is too near 0.0 for a real, whose smallest above 0.0 " <>
                 "is 1.1754943508222875e-38: " <> @flushed

      assert_raise ArgumentError,
                   "`x` is an lreal: `1.0e-310` is too near 0.0 for an lreal, whose smallest " <>
                     "above 0.0 is 2.2250738585072014e-308: " <> @flushed,
                   fn -> Logex.Tag.new!("x", :lreal, :var, 1.0e-310) end

      assert %Logex.Tag{initial: +0.0} = Logex.Tag.new!("x", :real, :var, 0.0)
    end

    # A device's, a host's and a force's value is no literal: it is written as 0.0, as
    # decision 166 has it.
    test "a host's value so small is still written as 0.0" do
      assert outputs("var_input a real\nvar_output r real\nmove a r", %{"a" => 1.0e-40}) ===
               %{"r" => 0.0}
    end
  end

  describe "a forces file's real point (decision 218)" do
    @tag :tmp_dir
    test "takes any number that is a value of its type, held at its nearest", %{tmp_dir: dir} do
      file = Path.join(dir, "forces")

      for {text, hz} <- [
            {"37.50", 37.5},
            {"3.75e1", 37.5},
            {"375.0E-1", 37.5},
            {"37", 37.0},
            {"16#25", 37.0},
            {"3_7.5", 37.5},
            {"-37.5", -37.5},
            {"16777217", 16_777_216.0},
            {"0.10000000149011612", single(0.1)},
            {"1.0e-40", 0.0},
            # A force is no literal: a value a float holds nearer 0.0 than an lreal's
            # smallest normal, which the lexer refuses as a literal (decision 216), is held
            # as 0.0 at either real, as `1.0e-40` is at a `real` (M5-11's review).
            {"1.0e-310", 0.0},
            {"-4.9e-324", 0.0},
            # Decision 237: and one no float holds, `1.0e-400`, as `1.0e-310` is.
            {"1.0e-400", 0.0},
            {"-1_0.0e-4_00", 0.0},
            {"-0.0", 0.0}
          ] do
        File.write!(file, "big #{text}\nhz #{text}\n")
        {{:ok, runner}, clock, _sim} = run_fan(file)
        forces = Runner.status(runner).forces
        assert forces["hz"] === hz, text

        assert forces["big"] === 0.0 or
                 text not in ["1.0e-310", "-4.9e-324", "1.0e-400", "-1_0.0e-4_00"],
               text

        assert forces["big"] === elem(Float.parse(String.replace(text, "_", "")), 0) * 1.0 or
                 text in [
                   "16#25",
                   "-0.0",
                   "37",
                   "1.0e-310",
                   "-4.9e-324",
                   "1.0e-400",
                   "-1_0.0e-4_00"
                 ],
               text

        Manual.advance(clock, 10)
        assert Runner.get!(runner, "hz") === hz, text
        # The file stays as written until the next force, which writes it whole in the
        # runner's spelling.
        assert File.read!(file) == "big #{text}\nhz #{text}\n"
        assert Runner.force(runner, "big", 1.5) == :ok
        assert File.read!(file) == "big 1.5\nhz #{Logex.Real.spelled(:real, hz)}\n"
        Runner.stop(runner)
      end
    end

    @tag :tmp_dir
    test "refuses a number outside its type, and anything that is no one number",
         %{tmp_dir: dir} do
      file = Path.join(dir, "forces")
      File.write!(file, "hz 1.0e39\nbig 1.0e-400 1.0\n")

      assert raised(fn -> run_fan(file) end) ==
               "#{file}: line 1: `hz` is a real, forced to a number from " <>
                 "-3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0e39\n" <>
                 "#{file}: line 2: `big 1.0e-400 1.0` is no force: a line holds an input " <>
                 "point's name and its value, as `eye_1 1`"

      # Nor is a comment, a tab or a return after the number, which the lexer would pass
      # over (M5-11's review); a number no float holds, `1.0e-400`, is 0.0 since decision
      # 237.
      for text <-
            ["1.", "1e5", "+3", "0x10", "8#7", "1.5L", "3 4", "x"] ++
              ["1.5//c", "1.5 //c", "1.5\t", "1.5\r", "1.0e-400 x", "1_0.0e-400//c"] do
        File.write!(file, "hz #{text}\n")

        assert raised(fn -> run_fan(file) end) ==
                 "#{file}: line 1: `hz #{text}` is no force: a line holds an input point's " <>
                   "name and its value, as `eye_1 1`",
               text
      end
    end
  end

  describe "a real literal with more digits than its slot's real keeps (decision 219)" do
    test "is warned of, told what it is held as, and 0.1 and 37.1 are not" do
      assert warnings(
               "var_input a real\nvar_input l lreal\nvar_output r real\nvar_output m lreal\n" <>
                 "var_output q bool\nvar_output i int\n" <>
                 "move 16777217.0 r\nmove 0.1 r\nge a 37.1 ote q\neq 3.14159265358979 a ote q\n" <>
                 "add a 1.000000001 r\nreal_to_int 0.10000000149011612 i\n" <>
                 "move 9007199254740993.0 m\nmove 0.10000000149011612 m\nmove 16777217.0 m\n" <>
                 "lreal_to_int 3.14159265358979 i\nmove 0.100000001490116119384765625 r\n" <>
                 "move 1.6777216e7 r\nmove 37.50 r\nmove -0.100000001490116119384765625 r\n" <>
                 "move -16777217.0 r"
             ) == [
               {2, "`l` is declared but no rung uses it"},
               {7, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {10, "`q` already has an `ote` on line 9: the last one in the scan decides it"},
               {10,
                "`3.14159265358979` is more precise than a real keeps: it is held as 3.1415927"},
               {11, "`1.000000001` is more precise than a real keeps: it is held as 1.0"},
               {12,
                "`real_to_int` reads a literal, `0.10000000149011612`: its result never changes"},
               {12, "`0.10000000149011612` is more precise than a real keeps: it is held as 0.1"},
               {13,
                "`9007199254740993.0` is more precise than an lreal keeps: it is held as " <>
                  "9.007199254740992e15"},
               {16,
                "`lreal_to_int` reads a literal, `3.14159265358979`: its result never changes"},
               {21, "`-16777217.0` is more precise than a real keeps: it is held as -16777216.0"}
             ]
    end

    test "is warned of in a block's real formal and beside its real member, not beside a literal" do
      {:ok, keep} =
        Logex.compile(
          "function_block keep\nvar_input a real\nvar_output b real\nmove a b",
          name: "keep"
        )

      {:ok, program} =
        Logex.compile(
          "var k keep\nvar_output r real\nvar_output q bool\nvar_output p bool\n" <>
            "cal k 16777217.0 r\neq 16777217.0 1.0 ote q\ngt k.b 16777217.0 ote p",
          name: "p",
          types: [keep]
        )

      assert Enum.map(program.warnings, &{&1.line, &1.message}) == [
               {5, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {6,
                "`eq` compares two literals, `16777217.0` and `1.0`: its result never changes"},
               {7, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]
    end

    test "is warned of in a block's formal at its third operand and past it" do
      {:ok, mix} =
        Logex.compile(
          "function_block mix\nvar_input a real\nvar_input b real\nvar_input c real\n" <>
            "var_output d real\nadd a b d\nadd d c d",
          name: "mix"
        )

      # The literal alone among the tags, so that it is the only real literal the
      # instruction holds, at the cal's second, third and fourth operands.
      for operands <- ["16777217.0 x y", "x 16777217.0 y", "x y 16777217.0"] do
        {:ok, program} =
          Logex.compile(
            "var m mix\nvar_output r real\nvar x real\nvar y real\n" <>
              "cal m #{operands} r",
            name: "p",
            types: [mix]
          )

        assert Enum.map(program.warnings, &{&1.line, &1.message}) == [
                 {5, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
               ],
               operands
      end

      # A block of two inputs and no output, its literal its last operand, the third.
      {:ok, sum} =
        Logex.compile(
          "function_block sum\nvar_input a real\nvar_input b real\nvar c real\nadd a b c",
          name: "sum"
        )

      {:ok, program} =
        Logex.compile("var k sum\nvar x real\ncal k x 16777217.0", name: "p", types: [sum])

      assert Enum.map(program.warnings, &{&1.line, &1.message}) == [
               {3, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]
    end

    # The pass is told an instruction that holds a real literal by its clause's guard, so a
    # program of none costs what it did at a8a4f8f, rung for rung, measured on its warnings
    # alone.
    test "a program of no real literal pays nothing for it" do
      for {head, rung, cost} <- [
            {"var_input a dint\nvar_output d dint\n", "add a 1234 d", 113.09},
            {"var_input a bool\nvar_output q bool\n", "xic a ote q", 187.34},
            {"var_input a int\nvar_output q bool\n", "gt a 5 ote q", 221.34},
            {"var_input a real\nvar_output d real\n", "move a d", 104.09}
          ] do
        warned = fn n ->
          p = program(head <> Enum.map_join(1..n, "\n", fn _ -> rung end))
          tags = Logex.Program.typed_tags(p)
          reductions(fn -> Logex.Warnings.of(p.rungs, tags) end)
        end

        assert (warned.(200) - warned.(100)) / 100 == cost, rung
      end
    end

    # Since decision 227 a declaration's initial value is warned of, read from the parse
    # tree's literal, which keeps its spelling, where the tag table keeps its value.
    test "a declaration's initial value is warned of (decision 227)" do
      assert warnings("var_output r real 16777217.0\nvar_input a bool\nxic a move 1.0 r") == [
               {1, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]
    end

    # The rule restated: the number the text writes, as a fraction, is warned of where it is
    # neither the value held nor the number of the shortest decimal whose nearest value of
    # the type is the value held, each judged exactly, over a seeded draw of texts.
    test "is warned of exactly where the restated rule says so" do
      :rand.seed(:exsss, {21, 9, 2})

      reached =
        for _ <- 1..1500 do
          text = drawn_real()
          {type, value} = drawn_type(text)

          expected = restated(type, value, text)

          source =
            "var_output x #{type}\nvar_input g bool\nxic g move #{text} x"

          assert {:ok, program} = Logex.compile(source, name: "p"), text

          assert Enum.map(program.warnings, & &1.message) ==
                   Enum.map(
                     expected,
                     &"`#{text}` is more precise than #{article(type)} keeps: it is held as #{&1}"
                   ),
                 text

          {type, expected == []}
        end

      # Its reach: in each real, a hundred literals warned of and a hundred not.
      for type <- [:real, :lreal], kept <- [true, false] do
        assert Enum.count(reached, &(&1 == {type, kept})) >= 100, inspect({type, kept})
      end
    end

    # A real only where the text is within a single's normal range, which decision 216 and
    # the range refuse otherwise.
    defp types_of(x) when x == 0 or (x >= 1.2e-38 and x <= 3.0e38), do: [:real, :lreal]
    defp types_of(_x), do: [:lreal]

    defp article(:real), do: "a real"
    defp article(:lreal), do: "an lreal"

    defp drawn_real do
      digits = Enum.random([1, 2, 3, 6, 7, 8, 9, 10, 12, 16, 17, 18, 25])
      mantissa = for _ <- 1..digits, into: "", do: Integer.to_string(:rand.uniform(10) - 1)
      point = :rand.uniform(digits)
      whole = binary_part(mantissa, 0, point)
      fraction = binary_part(mantissa, point, digits - point)
      fraction = if fraction == "", do: "0", else: fraction
      exponent = Enum.random(["", "", "e3", "e-5", "e20", "e-30", "E7"])
      sign = Enum.random(["", "-"])
      "#{sign}#{whole}.#{fraction}#{exponent}"
    end

    defp drawn_type(text) do
      {double, ""} = Float.parse(text)
      {Enum.random(types_of(abs(double))), double}
    end

    # The value held, the BEAM's nearest single or the double, and its shortest decimal
    # found by trying 1 to 17 significant digits; a text whose double is 0.0 is 0.0 itself.
    defp restated(type, double, text) do
      held = held(type, double)
      shortest = shortest(type, held, 1)
      written = fraction(text)
      lost = written != binary_fraction(held) and written != fraction(shortest)
      if lost, do: [Float.to_string(elem(Float.parse(shortest), 0))], else: []
    end

    defp held(:real, x), do: single(x)
    defp held(:lreal, x), do: x

    defp shortest(type, held, digits) do
      text = :erlang.float_to_binary(held, [{:scientific, digits - 1}])
      {read, ""} = Float.parse(text)
      if held(type, read) === held, do: text, else: shortest(type, held, digits + 1)
    end

    defp fraction(text) do
      [mantissa | power] = String.split(text, ["e", "E"])

      {sign, mantissa} =
        if String.starts_with?(mantissa, "-"),
          do: {-1, String.slice(mantissa, 1..-1//1)},
          else: {1, mantissa}

      [whole, part] =
        if String.contains?(mantissa, "."), do: String.split(mantissa, "."), else: [mantissa, ""]

      power = if power == [], do: 0, else: String.to_integer(hd(power))
      n = sign * String.to_integer(whole <> part)
      e = power - String.length(part)
      if e >= 0, do: reduce(n * Integer.pow(10, e), 1), else: reduce(n, Integer.pow(10, -e))
    end

    defp binary_fraction(x) do
      <<s::1, e::11, f::52>> = <<x::float>>
      {m, p} = if e == 0, do: {f, -1074}, else: {f + Integer.pow(2, 52), e - 1075}
      m = if s == 1, do: -m, else: m
      if p >= 0, do: reduce(m * Integer.pow(2, p), 1), else: reduce(m, Integer.pow(2, -p))
    end

    defp reduce(0, _d), do: {0, 1}
    defp reduce(n, d), do: {div(n, Integer.gcd(n, d)), div(d, Integer.gcd(n, d))}
  end

  # Decision 227: a declaration's real initial value with more digits than its tag's real
  # keeps is warned of in decision 219's words, read from the literal's spelling, which the
  # parse tree keeps and the tag table does not; a configuration's global too.
  describe "a rounded initial value (decision 227)" do
    test "a declaration's, at its line, an array's list element by element" do
      assert warnings(
               "var_input a bool\nvar_output r real 16777217.0\nvar_output l lreal 9007199254740993.0\n" <>
                 "var_output s real[4] 0.1 16777217.0 0.10000000149011612 37.50\n" <>
                 "var_output k real 0.1\nvar_output m real 0.100000001490116119384765625\n" <>
                 "var_output n real 16777216\nxic a move 1.0 r\nxic a move 1.0 l\n" <>
                 "xic a move 1.0 s[0]\nxic a move 1.0 k\nxic a move 1.0 m\nxic a move 1.0 n"
             ) == [
               {2, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {3,
                "`9007199254740993.0` is more precise than an lreal keeps: it is held as " <>
                  "9.007199254740992e15"},
               {4, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {4, "`0.10000000149011612` is more precise than a real keeps: it is held as 0.1"}
             ]

      # Only a declaration's literals are an initial value: a rung naming a real tag second
      # is told of its literal once, by decision 219's pass.
      assert warnings("var_output r real\nadd r r r move 16777217.0 r") == [
               {2, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]

      # Late, after the first rung, it is still a declaration, reported and warned.
      assert {:error, [late]} =
               Logex.compile("var a bool\nxic a ote a\nvar r real 16777217.0", name: "p")

      assert late.message =~ "declarations come first"
    end

    test "a block's, among its body's warnings, which its body compiles again to" do
      {:ok, block} =
        Logex.compile(
          "function_block blk\nvar_input i bool\nvar_output o bool\nvar s real 16777217.0\n" <>
            "xic i ote o\nxic i move 1.0 s",
          name: "blk"
        )

      assert Enum.map(block.body.warnings, &{&1.line, &1.message}) == [
               {4, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]

      assert Logex.Compiler.lowered?(block.body)
      assert Logex.FbType.user?(block)
      refute Logex.Compiler.lowered?(%{block.body | warnings: []})
    end

    test "a configuration's global, at its line, an array's element by element" do
      {:ok, m} = Logex.compile("var_input x real\nvar_output y real\nmove x y", name: "m")

      {:ok, configuration} =
        Configuration.compile(
          "c",
          "var_global sp real 16777217.0\nvar_global ok real 0.1\n" <>
            "var_global rs lreal[2] 1.0 9007199254740993.0\nprogram m1 m\nm1.x sp\nm1.y ok\n",
          %{"m" => m}
        )

      assert Enum.map(configuration.warnings, &{&1.line, &1.message}) == [
               {1, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {3,
                "`9007199254740993.0` is more precise than an lreal keeps: it is held as " <>
                  "9.007199254740992e15"},
               {3, "`rs` is declared but nothing uses it"}
             ]

      # Printed, a real is the shortest text of its value, which reads back unwarned.
      printed = Configuration.Text.print(configuration)
      assert printed =~ "var_global sp real 16777216.0"
      {:ok, again} = Configuration.compile("c", printed, %{"m" => m})
      assert Enum.map(again.warnings, & &1.message) == ["`rs` is declared but nothing uses it"]
    end

    test "from Elixir there is no spelling and nothing is warned" do
      tag = Logex.Tag.new!("r", :real, :var_output, 16_777_216.0)
      {:ok, tokens, _} = Logex.Compiler.tokenize("var_input a bool\nxic a move 1.0 r")
      {:ok, tree} = Logex.Compiler.parse(tokens)
      {:ok, program} = Logex.Compiler.instructionize(tree, [tag])
      assert program.warnings == []
    end
  end

  # Decision 228: a literal whose double is subnormal is read as that double by the lexer
  # and refused by its slot, naming the instruction and the tag, as a `real`'s is.
  describe "a literal nearer 0.0 than an lreal holds (decision 228)" do
    @too_near "is too near 0.0 for an lreal, whose smallest above 0.0 is " <>
                "2.2250738585072014e-308: it would be written as 0.0"

    test "is the double the lexer reads, refused in every slot that judges a literal" do
      assert {:ok, [{:real_lit, {1, 6}, 1.0e-310}, _], 1} =
               lexed("move 1.0e-310 l")
               |> then(fn {:ok, [_ | t], e} -> {:ok, Enum.take(t, 2), e} end)

      head = "var_input a lreal\nvar_output l lreal\nvar_output r real\nvar_output q bool\n"

      for {rung, message} <- [
            {"move 1.0e-310 l", "`move` writes `1.0e-310` into `l`, an lreal: it #{@too_near}"},
            {"move -4.9e-324 l", "`move` writes `-4.9e-324` into `l`, an lreal: it #{@too_near}"},
            {"add a 1.0e-310 l",
             "`add` computes in `l`'s type, an lreal: `1.0e-310` #{@too_near}"},
            {"sqrt 1.0e-310 l",
             "`sqrt` computes in `l`'s type, an lreal: `1.0e-310` #{@too_near}"},
            {"gt a 1.0e-310 ote q",
             "`gt` compares `1.0e-310` with `a`, an lreal (declared on line 1), which never " <>
               "holds it: `1.0e-310` #{@too_near}"},
            {"lreal_to_real 1.0e-310 r",
             "`lreal_to_real` reads an lreal: `1.0e-310` #{@too_near}"}
          ] do
        assert messages(head <> rung) == [{5, message}], rung
      end

      assert messages("var l lreal 1.0e-310\nxic l") |> hd() ==
               {1, "`l` is an lreal: `1.0e-310` #{@too_near}"}

      {:ok, keep} =
        Logex.compile("function_block keep\nvar_input a lreal\nvar_output b lreal\nmove a b",
          name: "keep"
        )

      assert {:error, [%Logex.Diagnostic{line: 3, message: message}]} =
               Logex.compile("var k keep\nvar_output r lreal\ncal k 1.0e-310 r",
                 name: "p",
                 types: [keep]
               )

      assert message == "operand 1 of `cal k` is `a` (var_input lreal): `1.0e-310` #{@too_near}"

      assert {:error, [%Logex.Diagnostic{line: 1, message: message} | _]} =
               Configuration.compile("c", "var_global sp lreal 1.0e-310\n", %{})

      assert message == "`sp` is an lreal: `1.0e-310` #{@too_near}"
    end

    test "an lreal's smallest normal is taken, two literals compared are the doubles" do
      assert outputs("var_output l lreal\nmove 2.2250738585072014e-308 l") ===
               %{"l" => 2.2250738585072014e-308}

      assert warnings("var_output q bool\nlt 1.0e-310 0.0 ote q") == [
               {2, "`lt` compares two literals, `1.0e-310` and `0.0`: its result never changes"}
             ]

      assert outputs("var_output q bool\ngt 1.0e-310 0.0 ote q") == %{"q" => 1}
    end
  end

  # Decision 231: a literal no double holds but 0.0, `1.0e-400`, is the spelled leaf of 0.0,
  # `{:real_lit, line, 0.0, "1.0e-400"}`, which every slot that judges a literal refuses,
  # naming the instruction and the tag, in decision 228's words; a zero written any way is
  # 0.0; and a configuration file and a forces file, which have no instruction, refuse it
  # as the lexer did until then (provisional).
  describe "a literal no double holds but 0.0 (decision 231)" do
    @too_near "is too near 0.0 for an lreal, whose smallest above 0.0 is " <>
                "2.2250738585072014e-308: it would be written as 0.0"

    test "is 0.0 spelled, a well-formed leaf the printer gives back" do
      assert {:ok, [_, {:real_lit, {1, 6}, zero, "1.0e-400"}, _], 1} = lexed("move 1.0e-400 l")
      assert zero === 0.0
      assert Logex.Parser.underflowed?({:real_lit, 1, 0.0, "1.0e-400"})
      assert Logex.Parser.underflowed?({:real_lit, 1, 0.0, "-9.9e-999"})

      for zero <- ["0.0e-400", "-0.0", "0_0.0", "00.000E-9", "0.0"] do
        refute Logex.Parser.underflowed?({:real_lit, 1, 0.0, zero}), zero
      end

      refute Logex.Parser.underflowed?({:real_lit, 1, 1.0e-310, "1.0e-310"})
      refute Logex.Parser.underflowed?({:real_lit, 1, 0.0})

      {:ok, tree} = Logex.Compiler.parse(elem(lexed("move 1.0e-400 l"), 1))
      assert Logex.Parser.well_formed!(tree) == tree
      assert Logex.Printer.print(tree) == "move 1.0e-400 l"
    end

    test "is refused in every slot that judges a literal, naming the instruction and the tag" do
      head = "var_input a lreal\nvar_output l lreal\nvar_output r real\nvar_output q bool\n"

      for {rung, message} <- [
            {"move 1.0e-400 l", "`move` writes `1.0e-400` into `l`, an lreal: it #{@too_near}"},
            {"move -1.0e-400 r",
             "`move` writes `-1.0e-400` into `r`, a real: it is too near 0.0 for a real, whose " <>
               "smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0"},
            {"add a 1.0e-400 l",
             "`add` computes in `l`'s type, an lreal: `1.0e-400` #{@too_near}"},
            {"sqrt 1.0e-400 l",
             "`sqrt` computes in `l`'s type, an lreal: `1.0e-400` #{@too_near}"},
            {"gt a 1.0e-400 ote q",
             "`gt` compares `1.0e-400` with `a`, an lreal (declared on line 1), which never " <>
               "holds it: `1.0e-400` #{@too_near}"},
            {"lreal_to_real 1.0e-400 r",
             "`lreal_to_real` reads an lreal: `1.0e-400` #{@too_near}"}
          ] do
        assert messages(head <> rung) == [{5, message}], rung
      end

      assert messages("var l lreal 1.0e-400\nxic l") |> hd() ==
               {1, "`l` is an lreal: `1.0e-400` #{@too_near}"}

      assert messages("var l lreal[2] 1.0 1.0e-400\nxic l[0]") |> hd() ==
               {1, "`l[1]` is an lreal: `1.0e-400` #{@too_near}"}

      {:ok, keep} =
        Logex.compile("function_block keep\nvar_input a lreal\nvar_output b lreal\nmove a b",
          name: "keep"
        )

      assert {:error, [%Logex.Diagnostic{line: 3, message: message}]} =
               Logex.compile("var k keep\nvar_output r lreal\ncal k 1.0e-400 r",
                 name: "p",
                 types: [keep]
               )

      assert message == "operand 1 of `cal k` is `a` (var_input lreal): `1.0e-400` #{@too_near}"

      # Into an integer, it is a real, as any real literal is.
      assert messages("var_output n dint\nmove 1.0e-400 n") == [
               {2,
                "`move` writes `1.0e-400` into `n`, a dint: it is a real, and a dint holds only integers"}
             ]
    end

    test "a zero written any way is 0.0, and two literals compared refuse it" do
      for zero <- ["0.0e-400", "-0.0e-400", "0_0.0E-999"] do
        assert outputs("var_output l lreal 1.0\nmove #{zero} l") === %{"l" => 0.0}, zero
      end

      assert warnings("var_output q bool\nlt 0.0e-400 0.0 ote q") == [
               {2, "`lt` compares two literals, `0.0e-400` and `0.0`: its result never changes"}
             ]

      # Decision 240, superseding decision 231's provisional reading: beside another literal
      # it is refused as in every other slot, where until then `eq 1.0e-400 0.0` was true on
      # every scan and `lt 0.0 1.0e-400` false.
      for {rung, shown, word} <- [
            {"eq 1.0e-400 0.0", "1.0e-400", "eq"},
            {"lt 0.0 1.0e-400", "1.0e-400", "lt"},
            {"ne -1_0.0e-4_00 2.5", "-1_0.0e-4_00", "ne"},
            {"ge 5 1.0e-400", "1.0e-400", "ge"}
          ] do
        assert messages("var_output q bool\n#{rung} ote q") == [
                 {2,
                  "`#{word}` reads a number or a bit string, and compares two literals as " <>
                    "lreals: `#{shown}` #{@too_near}"}
               ],
               rung
      end

      # A subnormal one beside a literal is still the double it lexes as (decision 228).
      assert outputs("var_output q bool\ngt 1.0e-310 0.0 ote q") == %{"q" => 1}
    end

    # Decision 237, superseding decision 231's provisional reading: a configuration file's
    # literal no double holds is refused in its global's or member's words, as `1.0e-310`
    # is, and read by `Logex.Configuration.Text.read/1` alone as the lexer refused it.
    test "a configuration file refuses it in its global's or member's words" do
      {:ok, m} =
        Logex.compile(
          "var_input x lreal\nvar_input y real\nvar_input a lreal[2]\nvar_input d dint\n" <>
            "var_input b bool\nvar_output q bool\ngt x y ote q\nxic b ote q\nlt a[0] d ote q",
          name: "m"
        )

      real =
        "is too near 0.0 for a real, whose smallest above 0.0 is 1.1754943508222875e-38: " <>
          "it would be written as 0.0"

      for {text, expected} <- [
            {"var_global sp lreal 1.0e-400\n",
             [{1, "`sp` is an lreal: `1.0e-400` #{@too_near}"}]},
            {"var_global sp real -1_0.0e-4_00\n",
             [{1, "`sp` is a real: `-1_0.0e-4_00` #{real}"}]},
            {"var_global sp lreal[3] 1.0 1.0e-400 1.0e-401\n",
             [
               {1, "`sp[1]` is an lreal: `1.0e-400` #{@too_near}"},
               {1, "`sp[2]` is an lreal: `1.0e-401` #{@too_near}"}
             ]},
            {"var_global g dint 1.0e-400\nvar_global h bool 1.0e-400\nvar_global k int 1.5\n" <>
               "var_global j int[2] 2.5 1\n",
             [
               {1, "`g` is a dint: `1.0e-400` is a real, and a dint holds only integers"},
               {2, "`h` is a bool: `1.0e-400` is a real, and a bool holds only 0 or 1"},
               # Found on the way: a real initial value of an integer global, which a line
               # can say, was raised as the host's mistake.
               {3, "`k` is an int: `1.5` is a real, and an int holds only integers"},
               {4, "the initial value of `j[0]` must be an integer, found 2.5"}
             ]},
            {"program m1 m\nm1.x -1.0e-400\nm1.y 1.0e-400\nm1.a[0] 1.0\nm1.a[1] 1.0e-400\n" <>
               "m1.d 1.0e-400\nm1.b 0\n",
             [
               {2, "`m1.x` is an lreal: `-1.0e-400` #{@too_near}"},
               {3, "`m1.y` is a real: `1.0e-400` #{real}"},
               {5, "`m1.a[1]` is an lreal: `1.0e-400` #{@too_near}"},
               {6, "`m1.d` is a dint: `1.0e-400` is a real, and a dint holds only integers"}
             ]},
            {"program m1 m\nm1.a 1.0e-400\nm1.a[1] 0.0\nm1.x 0.0\nm1.y 0.0\nm1.d 0\nm1.b 0\n",
             [
               {2,
                "`m1.a` is an array of 2 lreals, and the constant `1.0e-400` is one value: " <>
                  "connect it to a global array of its sizes, or each element to a constant, as " <>
                  "in `m1.a[0] 1.0e-400`"},
               {3,
                "`m1.a[1]` is already connected, by `m1.a` to `1.0e-400` (line 2): a var_input " <>
                  "has one source, an array whole or each of its elements"}
             ]},
            {"task t interval 1.0e-400 priority 1\nprogram m1 m with t\nm1.x 0.0\nm1.y 0.0\n" <>
               "m1.a[0] 0.0\nm1.a[1] 0.0\nm1.d 0\nm1.b 0\n",
             [
               {1,
                "`interval` takes a number of milliseconds, as in `interval 10`, found `1.0e-400`"}
             ]}
          ] do
        assert {:error, diagnostics} = Configuration.compile("c", text, %{"m" => m}), text

        assert {text,
                for(
                  %Logex.Diagnostic{stage: :configure, line: line, message: message} <-
                    diagnostics,
                  line != nil,
                  do: {line, message}
                )} == {text, expected}
      end

      # A literal elsewhere in the text with the stand-in's value keeps its own spelling.
      stand_in = Float.to_string(7919 * 5.0e-324)

      assert {:error, diagnostics} =
               Configuration.compile(
                 "c",
                 "var_global a lreal #{stand_in}\nvar_global b lreal 1.0e-400\n",
                 %{}
               )

      assert for(%{line: line, message: m} <- diagnostics, line != nil, do: {line, m}) == [
               {1, "`a` is an lreal: `#{stand_in}` #{@too_near}"},
               {2, "`b` is an lreal: `1.0e-400` #{@too_near}"}
             ]

      # From a file too.
      dir = Path.join(System.tmp_dir!(), "logex-237-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "plant.logex")
      File.write!(path, "var_global sp lreal 1.0e-400\n")

      assert {:error, [%Logex.Diagnostic{line: 1, file: ^path, message: message} | _]} =
               Configuration.compile_file(path)

      assert message == "`sp` is an lreal: `1.0e-400` #{@too_near}"
      File.rm_rf!(dir)

      # `Text.read/1`, which gives values, still refuses it at its column.
      assert {:error, [%Logex.Diagnostic{stage: :lex, line: 1, column: 21} = d], []} =
               Configuration.Text.read("var_global sp lreal 1.0e-400\n")

      assert d.message ==
               "\"1.0e-400\" is no number logex holds: an lreal's smallest above 0.0 is " <>
                 "2.2250738585072014e-308"
    end
  end
end
