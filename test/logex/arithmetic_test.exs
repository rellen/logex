defmodule Logex.ArithmeticTest do
  @moduledoc """
  M3-3: IEC's arithmetic on dints, `add`, `sub` and `mul` (docs/organisation.md decisions
  77, 79 and 98; docs/naming.md, each mnemonic's stanza), each rule of a scan pinned from
  source through `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted.
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

    test "a sum past the top stops there and passes no power on that scan (decision 77)" do
      assert two("add", @max, 1) == {@max, 0}
      assert two("add", @max, @max) == {@max, 0}
    end

    test "a sum past the bottom stops there and passes no power on that scan" do
      assert two("add", @min, -1) == {@min, 0}
      assert two("add", @min, @min) == {@min, 0}
      assert two("add", @min, 0) == {@min, 1}
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
    test "a destination that is a source accumulates, and stops at the top with no power" do
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

      assert trace(p, [%{"flow" => 2}, %{}, %{"flow" => -1}], state) == [
               %{"total" => @max - 1, "ok" => 1},
               %{"total" => @max, "ok" => 0},
               %{"total" => @max - 1, "ok" => 1}
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

    test "past either limit, the nearer one and no power on that scan" do
      assert two("sub", @min, 1) == {@min, 0}
      assert two("sub", 0, @min) == {@max, 0}
      assert two("sub", @max, -1) == {@max, 0}
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

    # The product is exact before it is brought into the dint, so one far past a limit
    # stops at the limit of its true sign, never wrapping to the other.
    test "a product past a limit stops at the limit of its sign, with no power" do
      assert two("mul", 46_341, 46_341) == {@max, 0}
      assert two("mul", @max, @max) == {@max, 0}
      assert two("mul", @min, @min) == {@max, 0}
      assert two("mul", @min, -1) == {@max, 0}
      assert two("mul", @max, -2) == {@min, 0}
      assert two("mul", 65_536, -65_536) == {@min, 0}
    end

    test "de-energised, writes nothing and passes no power" do
      assert two("mul", 6, 7, 0) == {0, 0}
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
               %{"b" => @max, "c" => 10, "ok" => 0},
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
               %{"b" => @max, "c" => -@max, "ok" => 1},
               %{"b" => @min, "c" => @max, "ok" => 0}
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
               %{"t" => @max, "f" => 0},
               %{"t" => @max, "f" => 1}
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
      end
    end
  end
end
