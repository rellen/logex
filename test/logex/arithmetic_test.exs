defmodule Logex.ArithmeticTest do
  @moduledoc """
  M3-3: IEC's arithmetic on dints, `add`, `sub`, `mul`, `div` and `mod`, and `neg` and
  `abs` (docs/organisation.md decisions 78, 79 and 98; docs/naming.md, each mnemonic's
  stanza), each rule of a scan pinned from
  source through `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted.
  Since M5-2 a result outside the dint wraps, its low 32 bits kept in two's complement,
  and passes no power on that scan, with no fault (decision 146, superseding decision 77's
  saturation on purpose): every test of a limit below pins the wrap.
  The compiler's refusals and warnings are `validation_test.exs`'s, the writes of the walk
  `walk_test.exs`'s, and an edit's rules `edit_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Runtime, Scan}

  @max 2_147_483_647
  @min -2_147_483_648

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  # Scans `program` from `state` once per entry of `inputs`, 10 ms apart: each scan's
  # outputs.
  defp trace(program, inputs, state \\ nil) do
    state = state || Runtime.instance(program)

    {outputs, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
      end)

    outputs
  end

  # One scan of a program with sources `a` and `b`, the result `r` and its power `ok`.
  @two """
  var_input go bool
  var_input a dint
  var_input b dint
  var_output r dint
  var_output ok bool
  xic go OP a b r ote ok
  """

  defp two(op, a, b, go \\ 1) do
    p = c!(String.replace(@two, "OP", op))
    [out] = trace(p, [%{"go" => go, "a" => a, "b" => b}])
    {out["r"], out["ok"]}
  end

  describe "add" do
    test "energised, writes the sum and passes power" do
      assert two("add", 2, 3) == {5, 1}
      assert two("add", -7, 3) == {-4, 1}
      assert two("add", @max, 0) == {@max, 1}
      assert two("add", @max, @min) == {-1, 1}
    end

    test "a sum past the top wraps to the bottom and passes no power on that scan " <>
           "(decision 146)" do
      assert two("add", @max, 1) == {@min, 0}
      assert two("add", @max, 5) == {@min + 4, 0}
      assert two("add", @max, @max) == {-2, 0}
    end

    test "a sum past the bottom wraps to the top and passes no power on that scan" do
      assert two("add", @min, -1) == {@max, 0}
      assert two("add", @min, @min) == {0, 0}
      assert two("add", @min, 0) == {@min, 1}
    end

    # The power out says the stored value is not the exact one, even where the low bits
    # happen to be a value a sum inside the dint could give.
    test "a sum that wraps to 0 passes no power, though 0 is a dint's" do
      assert two("add", @min, @min) == {0, 0}
      assert two("add", 0, 0) == {0, 1}
    end

    # Decision 146's follow-up: a wrap shows only as no power out, never as a fault.
    test "a wrap raises no fault: the scan's faults stay empty" do
      for {op, a, b} <- [{"add", @max, 1}, {"sub", @min, 1}, {"mul", @max, 2}] do
        p = c!(String.replace(@two, "OP", op))
        inputs = %{"go" => 1, "a" => a, "b" => b}

        assert {%{"ok" => 0}, %Instance{faults: []}} =
                 Runtime.call(p, Runtime.instance(p), inputs, %Scan{now: 0, first: true})
      end
    end

    test "de-energised, writes nothing and passes no power" do
      p = c!(String.replace(@two, "OP", "add"))

      assert [%{"r" => 5, "ok" => 1}, %{"r" => 5, "ok" => 0}, %{"r" => 9, "ok" => 1}] =
               trace(p, [
                 %{"go" => 1, "a" => 2, "b" => 3},
                 %{"go" => 0, "a" => 40, "b" => 3},
                 %{"go" => 1, "a" => 6, "b" => 3}
               ])
    end

    # The sources are read before the write, so the destination may be one of them, and a
    # total runs on across scans.
    test "a destination that is a source accumulates, and wraps past the top with no power " <>
           "on that scan alone" do
      p =
        c!("""
        var_input flow dint
        var_output total dint
        var_output ok bool
        add total flow total ote ok
        """)

      assert Enum.map(trace(p, [%{"flow" => 5}, %{}, %{"flow" => -12}, %{}]), & &1["total"]) ==
               [5, 10, -2, -14]

      state = %{Runtime.instance(p) | env: %{"flow" => 0, "total" => @max - 3, "ok" => 0}}

      assert trace(p, [%{"flow" => 2}, %{}, %{}, %{"flow" => -1}], state) == [
               %{"total" => @max - 1, "ok" => 1},
               %{"total" => @min, "ok" => 0},
               %{"total" => @min + 2, "ok" => 1},
               %{"total" => @min + 1, "ok" => 1}
             ]
    end
  end

  describe "sub" do
    test "is the first source less the second, IEC's IN1 - IN2" do
      assert two("sub", 10, 3) == {7, 1}
      assert two("sub", 3, 10) == {-7, 1}
      assert two("sub", 0, @max) == {-@max, 1}
      assert two("sub", -1, @max) == {@min, 1}
    end

    test "past either limit, wraps to the other and passes no power on that scan" do
      assert two("sub", @min, 1) == {@max, 0}
      assert two("sub", 0, @min) == {@min, 0}
      assert two("sub", @max, -1) == {@min, 0}
      assert two("sub", @max, @min) == {-1, 0}
      assert two("sub", @min, @max) == {1, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert two("sub", 10, 3, 0) == {0, 0}
    end
  end

  describe "mul" do
    test "writes the product and passes power" do
      assert two("mul", 6, 7) == {42, 1}
      assert two("mul", -6, 7) == {-42, 1}
      assert two("mul", -6, -7) == {42, 1}
      assert two("mul", @min, 1) == {@min, 1}
      assert two("mul", 46_341, 46_340) == {2_147_441_940, 1}
    end

    # The product is exact before it is brought into the dint, and keeps its low 32 bits
    # however far it passed, its sign that of bit 31, not the true product's.
    test "a product past a limit keeps its low 32 bits, with no power" do
      assert two("mul", 46_341, 46_341) == {-2_147_479_015, 0}
      assert two("mul", @max, @max) == {1, 0}
      assert two("mul", @min, @min) == {0, 0}
      assert two("mul", @min, -1) == {@min, 0}
      assert two("mul", @max, -2) == {2, 0}
      assert two("mul", @max, 3) == {@max - 2, 0}
      assert two("mul", 65_536, -65_536) == {0, 0}
      assert two("mul", 65_536, 65_536) == {0, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert two("mul", 6, 7, 0) == {0, 0}
    end
  end

  describe "div" do
    test "writes the quotient truncated toward zero, IEC's 7/3 = 2 and (-7)/3 = -2" do
      assert two("div", 7, 3) == {2, 1}
      assert two("div", -7, 3) == {-2, 1}
      assert two("div", 7, -3) == {-2, 1}
      assert two("div", -7, -3) == {2, 1}
      assert two("div", 7, 2) == {3, 1}
      assert two("div", -7, 2) == {-3, 1}
      assert two("div", 0, 5) == {0, 1}
      assert two("div", @min, 1) == {@min, 1}
      assert two("div", @max, -1) == {-@max, 1}
    end

    # Decision 78: 0 and no power on that scan; the scan's report of it is the fault's.
    test "a zero divisor writes 0 and passes no power on that scan, the plant running on" do
      assert two("div", 7, 0) == {0, 0}
      assert two("div", 0, 0) == {0, 0}
      assert two("div", @min, 0) == {0, 0}

      p = c!(String.replace(@two, "OP", "div"))

      assert trace(p, [
               %{"go" => 1, "a" => 600, "b" => 60},
               %{"b" => 0},
               %{"b" => 3}
             ]) == [%{"r" => 10, "ok" => 1}, %{"r" => 0, "ok" => 0}, %{"r" => 200, "ok" => 1}]
    end

    # Decision 146: the one quotient outside a dint, which is no zero divisor, wraps to the
    # minimum, with no power and no fault.
    test "the minimum divided by -1 wraps to the minimum, with no power and no fault" do
      assert two("div", @min, -1) == {@min, 0}

      p = c!(String.replace(@two, "OP", "div"))
      state = Runtime.instance(p)

      assert {%{"r" => @min, "ok" => 0}, %Instance{faults: []}} =
               Runtime.call(p, state, %{"go" => 1, "a" => @min, "b" => -1}, %Scan{
                 now: 0,
                 first: true
               })
    end

    test "de-energised, writes nothing and passes no power, a zero divisor too" do
      assert two("div", 7, 3, 0) == {0, 0}
      p = c!(String.replace(@two, "OP", "div"))

      assert trace(p, [%{"go" => 1, "a" => 9, "b" => 3}, %{"go" => 0, "b" => 0}]) ==
               [%{"r" => 3, "ok" => 1}, %{"r" => 3, "ok" => 0}]
    end
  end

  describe "mod" do
    # IEC's IN1 - (IN1/IN2)*IN2 with DIV's truncation, Elixir's rem/2: the dividend's sign,
    # never the divisor's, as Integer.mod/2 would give.
    test "writes the remainder, its sign the dividend's" do
      assert two("mod", 7, 3) == {1, 1}
      assert two("mod", -7, 3) == {-1, 1}
      assert two("mod", 7, -3) == {1, 1}
      assert two("mod", -7, -3) == {-1, 1}
      assert two("mod", 6, 3) == {0, 1}
      assert two("mod", -6, 3) == {0, 1}
      assert two("mod", 5, 7) == {5, 1}
    end

    test "a remainder always fits, the minimum's by -1 among them" do
      assert two("mod", @min, -1) == {0, 1}
      assert two("mod", @min, @max) == {-1, 1}
      assert two("mod", @max, @min) == {@max, 1}
    end

    test "a zero divisor writes 0 and passes no power on that scan, as `div`'s does" do
      assert two("mod", 7, 0) == {0, 0}
      assert two("mod", -7, 0) == {0, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert two("mod", 7, 3, 0) == {0, 0}
    end
  end

  # One scan of a program with the source `a`, the result `r` and its power `ok`.
  @one """
  var_input go bool
  var_input a dint
  var_output r dint
  var_output ok bool
  xic go OP a r ote ok
  """

  defp one(op, a, go \\ 1) do
    p = c!(String.replace(@one, "OP", op))
    [out] = trace(p, [%{"go" => go, "a" => a}])
    {out["r"], out["ok"]}
  end

  describe "neg" do
    test "writes 0 - a and passes power" do
      assert one("neg", 5) == {-5, 1}
      assert one("neg", -5) == {5, 1}
      assert one("neg", 0) == {0, 1}
      assert one("neg", @max) == {-@max, 1}
      assert one("neg", -@max) == {@max, 1}
    end

    # The most negative dint has no positive twin: its negation, 2147483648, wraps to the
    # minimum itself, with no power (decision 146).
    test "the minimum alone overflows: itself, and no power on that scan" do
      assert one("neg", @min) == {@min, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert one("neg", 5, 0) == {0, 0}
      p = c!(String.replace(@one, "OP", "neg"))

      assert trace(p, [%{"go" => 1, "a" => 4}, %{"go" => 0, "a" => 9}]) ==
               [%{"r" => -4, "ok" => 1}, %{"r" => -4, "ok" => 0}]
    end
  end

  describe "abs" do
    test "writes a where a >= 0 and -a otherwise, and passes power" do
      assert one("abs", 5) == {5, 1}
      assert one("abs", -5) == {5, 1}
      assert one("abs", 0) == {0, 1}
      assert one("abs", @max) == {@max, 1}
      assert one("abs", -@max) == {@max, 1}
    end

    # So an `abs` of the minimum is negative, the power out the one sign of it.
    test "the minimum alone overflows: itself, a negative, and no power" do
      assert one("abs", @min) == {@min, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert one("abs", -5, 0) == {0, 0}
      p = c!(String.replace(@one, "OP", "abs"))

      assert trace(p, [%{"go" => 1, "a" => -4}, %{"go" => 0, "a" => -9}]) ==
               [%{"r" => 4, "ok" => 1}, %{"r" => 4, "ok" => 0}]
    end

    test "its destination may be its source, and a member is read and written" do
      p =
        c!("""
        var_input a dint
        var_output r dint
        var t1 ton
        move a r
        abs r r neg r t1.acc
        move t1.acc r
        """)

      assert Enum.map(trace(p, [%{"a" => -7}, %{"a" => 3}]), & &1["r"]) == [-7, -3]
    end

    test "a source a hand-built env holds as no integer reads 0" do
      p = c!(String.replace(@one, "OP", "neg"))

      for junk <- [nil, 1.5, %{}, :x] do
        state = %Instance{type: "m", env: %{"go" => 1, "a" => junk}, now: 0, first: true}

        assert {%{"r" => 0, "ok" => 1}, _} =
                 Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
      end
    end
  end

  describe "on the rung" do
    # Decision 98: the power out is IEC's ENO, settled, so anything may follow, a second
    # arithmetic instruction among them, which runs only where the first succeeded.
    test "what follows reads its power out, a second one running only where the first passed" do
      p =
        c!("""
        var_input a dint
        var_output b dint
        var_output c dint
        var_output ok bool
        add a 1 b mul b 2 c ote ok
        """)

      assert trace(p, [%{"a" => 4}, %{"a" => @max}, %{"a" => 9}]) == [
               %{"b" => 5, "c" => 10, "ok" => 1},
               %{"b" => @min, "c" => 10, "ok" => 0},
               %{"b" => 10, "c" => 20, "ok" => 1}
             ]
    end

    test "in a branch group, each leg its own, the group passing power if either does" do
      p =
        c!("""
        var_input a dint
        var_output b dint
        var_output c dint
        var_output ok bool
        ( add a a b | sub 0 a c ) ote ok
        """)

      assert trace(p, [%{"a" => 3}, %{"a" => @max}, %{"a" => @min}]) == [
               %{"b" => 6, "c" => -3, "ok" => 1},
               %{"b" => -2, "c" => -@max, "ok" => 1},
               %{"b" => 0, "c" => @min, "ok" => 0}
             ]
    end

    test "literals, negative ones among them, and members are sources, and a member is written" do
      p =
        c!("""
        var_input go bool
        var_output r dint
        var t1 ton
        xic go ton t1 1000
        add t1.pre -250 t1.pre
        mul t1.pre -2 r
        """)

      assert Enum.map(trace(p, [%{"go" => 0}, %{}, %{}]), & &1["r"]) == [-1500, -1000, -500]
    end

    test "a block's body runs them over its instance, and its outputs show their results" do
      {:ok, tally} =
        Logex.compile(
          "function_block tally\nvar_input n dint\nvar_output total dint\n" <>
            "var_output full bool\nadd total n total ote full",
          name: "tally"
        )

      p =
        c!(
          "var_input n dint\nvar_output t dint\nvar_output f bool\nvar s1 tally\ncal s1 n t f",
          [tally]
        )

      assert trace(p, [%{"n" => 7}, %{"n" => @max}, %{"n" => 0}]) == [
               %{"t" => 7, "f" => 1},
               %{"t" => @min + 6, "f" => 0},
               %{"t" => @min + 6, "f" => 1}
             ]
    end

    # A state built by hand is outside the contract, but a scan of one never raises: a
    # source that is no integer reads 0.
    test "a source a hand-built env holds as no integer reads 0" do
      p = c!(String.replace(@two, "OP", "add"))

      for junk <- [nil, 1.5, %{"x" => 1}, :x, "7"] do
        state = %Instance{
          type: "m",
          env: %{"go" => 1, "a" => junk, "b" => 4},
          now: 0,
          first: true
        }

        {outputs, _} = Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
        assert outputs == %{"r" => 4, "ok" => 1}

        # A divisor that is no integer reads 0 too, and is then a zero one.
        d = c!(String.replace(@two, "OP", "div"))
        state = %{state | env: %{"go" => 1, "a" => 7, "b" => junk}}

        assert {%{"r" => 0, "ok" => 0}, _} =
                 Runtime.call(d, state, %{}, %Scan{now: 0, first: true})
      end
    end
  end
end
