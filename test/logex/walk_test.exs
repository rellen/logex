defmodule Logex.WalkTest do
  @moduledoc """
  B5's one walk of a program's IR (M2-4): every instruction, every use, which tags a
  program writes and which timers it runs, from source, `cal` and the blocks it runs
  included.
  """
  use ExUnit.Case, async: true

  alias Logex.{FbType, Program, Walk}

  defp program!(source, types \\ []) do
    {:ok, %Program{} = program} = Logex.compile(source, name: "m", types: types)
    program
  end

  defp block!(source, types \\ []) do
    [_, name] = Regex.run(~r/\Afunction_block (\w+)/, source)
    {:ok, %FbType{} = type} = Logex.compile(source, name: name, types: types)
    type
  end

  defp symbols(instructions),
    do: Enum.map(instructions, fn {symbol, line, _} -> {symbol, line} end)

  @seal """
  function_block seal
  var_input start bool
  var_input stop bool
  var_output run bool
  var edge bool
  var t1 ton
  xic start ons edge otl run
  xic stop otu run
  xic run ton t1 250
  """

  # A block that holds a seal and runs it, so the walk goes two levels down.
  @pair """
  function_block pair
  var_input a bool
  var_output q bool
  var n dint
  var s seal
  cal s a a q
  move 4 n
  move 5 n
  """

  describe "instructions/1" do
    test "every instruction in rung order, each group's legs in turn where they stand, at any depth" do
      p =
        program!("""
        var a bool
        var b bool
        var c bool
        xic a ( xio b | xic c ( ote b | ote c ) ) ote a
        xic b otl c
        """)

      assert symbols(Walk.instructions(p.rungs)) ==
               [xic: 4, xio: 4, xic: 4, ote: 4, ote: 4, ote: 4, xic: 5, otl: 5]
    end
  end

  describe "uses/2" do
    test "each tag operand with its slot's access, a member as its instance, a literal no use" do
      p =
        program!("""
        var a bool
        var n dint
        var t1 ton
        xic a ton t1 100
        xic t1.dn move 7 t1.pre
        eq n 3 ote a
        """)

      assert Walk.uses(p.rungs, Program.typed_tags(p)) == [
               {:read, "a", 4, :xic},
               {:instance, "t1", 4, :ton},
               {:read, "t1", 5, :xic},
               {:write, "t1", 5, :move},
               {:value, "n", 6, :eq},
               {:write, "a", 6, :ote}
             ]
    end

    test "a `cal`'s slots are its block's: the instance, then each var_input read, each var_output written" do
      seal = block!(@seal)

      p =
        program!(
          "var x bool\nvar y bool\nvar z bool\nvar s1 seal\ncal s1 x y z\n",
          [seal]
        )

      assert Walk.uses(p.rungs, Program.typed_tags(p)) == [
               {:instance, "s1", 5, :cal},
               {:value, "x", 5, :cal},
               {:value, "y", 5, :cal},
               {:write, "z", 5, :cal}
             ]
    end
  end

  describe "writes/1" do
    test "a write slot, a storage bit and an instance run are writes, each line a write, in rung order" do
      p =
        program!("""
        var a bool
        var b bool
        var n dint
        var e bool
        var t1 ton
        xic a ons e ote b
        xic b ton t1 100
        xic t1.dn move 7 t1.pre
        xic a move n n move 1 n
        xic e otl b
        """)

      assert Walk.writes(p) == %{
               "b" => [6, 10],
               "e" => [6],
               "t1" => [7, 8],
               "n" => [9, 9]
             }
    end

    test "a `cal` writes its instance and each tag its var_outputs fill, and none it reads" do
      seal = block!(@seal)

      p =
        program!(
          "var x bool\nvar y bool\nvar z bool\nvar s1 seal\ncal s1 x y z\nxic z ote x\n",
          [seal]
        )

      assert Map.take(Walk.writes(p), ["s1", "x", "y", "z"]) ==
               %{"s1" => [5], "z" => [5], "x" => [6]}
    end

    test "it reaches into each block a `cal` runs, at any depth, by path, with the body's own lines" do
      seal = block!(@seal)
      pair = block!(@pair, [seal])

      p =
        program!(
          "var_input go bool\nvar_output out bool\nvar p pair\nvar idle pair\ncal p go out\n",
          [pair]
        )

      assert Walk.writes(p) == %{
               "p" => [5],
               "out" => [5],
               "p.s" => [6],
               "p.q" => [6],
               "p.n" => [7, 8],
               "p.s.edge" => [7],
               "p.s.run" => [7, 8],
               "p.s.t1" => [9]
             }
    end

    test "a `cal` of what its table holds as no block's instance writes nothing and reaches nothing" do
      seal = block!(@seal)
      p = program!("var x bool\nvar s1 seal\ncal s1 x x x\n", [seal])
      # A program built by hand: its table lacks the type its instance names.
      bare = %{p | blocks: %{}}
      assert Walk.writes(bare) == %{}
      assert Walk.timers(bare) == %{}
    end
  end

  describe "timers/1" do
    test "each timer a `ton` runs, to the line and preset of the first, and none a `ton` does not run" do
      p =
        program!("""
        var a bool
        var t1 ton
        var t2 ton
        var t3 ton
        xic a ton t1 100
        xic t1.dn ton t2 2500
        """)

      assert Walk.timers(p) == %{"t1" => {5, 100}, "t2" => {6, 2500}}
    end

    test "the first `ton` in rung order, where a program built by hand has two" do
      p = program!("var a bool\nvar t1 ton\nxic a ton t1 100\n")
      [{:rung, [xic, ton]}] = p.rungs
      {:ton, 3, [timer, {:int_lit, 3, 100}]} = ton
      second = {:ton, 4, [timer, {:int_lit, 4, 900}]}
      twice = %{p | rungs: p.rungs ++ [{:rung, [xic, second]}]}
      assert Walk.timers(twice) == %{"t1" => {3, 100}}
    end

    test "it reaches into each block a `cal` runs, at any depth, by path, at the body's `ton`" do
      seal = block!(@seal)
      pair = block!(@pair, [seal])

      p =
        program!(
          "var_input go bool\nvar t9 ton\nvar p pair\nvar out bool\ncal p go out\nxic go ton t9 40\n",
          [pair]
        )

      assert Walk.timers(p) == %{"t9" => {6, 40}, "p.s.t1" => {9, 250}}
    end
  end

  describe "growth" do
    defp reductions(fun),
      do:
        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            fun.()
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )

    # Each block type's own writes and timers are read once a call, however many instances
    # run it: at 100 instances, 4x the rungs of the block's body cost little more, 1.49x to
    # 1.50x over 37 runs on Elixir 1.20.4, 21 alone and 16 beside three full suites; with
    # the body read again for each instance, about 4x. The bound is a fifth above the
    # highest.
    test "a block's body is read once a call, however many instances run it" do
      walk = fn r ->
        big =
          block!(
            "function_block big\nvar_input go bool\nvar_output q bool\nvar n dint\nvar t1 ton\n" <>
              String.duplicate("xic go move 1 n\n", r) <> "xic go ton t1 5\nxic go ote q"
          )

        p =
          program!(
            "var_input a bool\nvar_output y bool\n" <>
              Enum.map_join(1..100, "", &"var p#{&1} big\n") <>
              Enum.map_join(1..100, "\n", &"cal p#{&1} a y"),
            [big]
          )

        reductions(fn ->
          Walk.writes(p)
          Walk.timers(p)
        end)
      end

      ratio = walk.(200) / walk.(50)
      assert ratio < 1.8, "4x the body's rungs took #{Float.round(ratio, 2)}x the reductions"
    end

    # A chain of n block types, each holding the next and running it: each level's facts
    # are put once, from the top down, so 16x the depth cost 16.7x to 17.2x over the same
    # 37 runs. The bound is a fifth above the highest; with each level's facts put by path
    # as each level returned them, the walk was cubic in the depth, and 800 levels did not
    # finish in a minute.
    test "the walk stays linear in the depth of nesting" do
      chain = fn n ->
        deepest =
          block!(
            "function_block b#{n}\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
              "xic go ote q\nxic go ton t1 100"
          )

        Enum.reduce((n - 1)..1//-1, deepest, fn k, inner ->
          block!(
            "function_block b#{k}\nvar_input go bool\nvar_output q bool\nvar inner b#{k + 1}\n" <>
              "cal inner go q",
            [inner]
          )
        end)
      end

      walk = fn n ->
        p = program!("var_input a bool\nvar_output y bool\nvar p b1\ncal p a y", [chain.(n)])

        reductions(fn ->
          Walk.writes(p)
          Walk.timers(p)
        end)
      end

      ratio = walk.(800) / walk.(50)
      assert ratio < 20.6, "16x the depth took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
