defmodule Logex.WalkTest do
  @moduledoc """
  B5's one walk of a program's IR (M2-4): every instruction, every use, which tags a
  program writes, which members it writes (decision 96), which timers it runs and which
  one-shots (M3-4), from source, `cal` and the blocks it runs included.
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

  # M3-4: the one-shots, `ons` and the pulse coils, each keeping its storage bit first.
  describe "storage_bits/1 and uses_of/2" do
    test "each one-shot's storage bit, in rung order, a group's legs where they stand, with " <>
           "its line and symbol; a coil's pulse bit is none" do
      p =
        program!("""
        var a bool
        var s1 bool
        var s2 bool
        var s3 bool
        var q bool
        var r bool
        xic a osf s2 q ( ons s1 | osr s3 r )
        xic s1 osr r s1
        """)

      assert Walk.storage_bits(p.rungs) ==
               [{"s2", 7, :osf}, {"s1", 7, :ons}, {"s3", 7, :osr}, {"r", 8, :osr}]
    end

    test "a coil writes its storage bit, then its pulse bit, and uses/2 is each " <>
           "instruction's uses_of/2 in turn" do
      p =
        program!("""
        var a bool
        var s bool
        var c ctu
        xic a osr s c.r
        xic a ctu c 4
        """)

      tags = Program.typed_tags(p)
      [_xic, osr | _] = Walk.instructions(p.rungs)
      assert Walk.uses_of(osr, tags) == [{:write, "s", 4, :osr}, {:write, "c", 4, :osr}]

      assert Walk.uses(p.rungs, tags) ==
               Enum.flat_map(Walk.instructions(p.rungs), &Walk.uses_of(&1, tags))

      assert Walk.writes(p) == %{"s" => [4], "c" => [4, 5]}
      assert Walk.member_writes(p) == %{"c.r" => [4]}
    end
  end

  # M3-5 (decisions 105 and 107): a label names no tag, so a `jmp` and a `lbl` use none, and a
  # rung a jump may skip is walked as any rung is.
  describe "a jump's rungs" do
    test "a label is no use, though a tag shares its name, and a jmp and a lbl use no tag" do
      p =
        program!("""
        var a bool
        var done bool
        xic a jmp done
        lbl done xic a ote done
        """)

      assert Walk.uses(p.rungs, Program.typed_tags(p)) == [
               {:read, "a", 3, :xic},
               {:read, "a", 4, :xic},
               {:write, "done", 4, :ote}
             ]

      assert symbols(Walk.instructions(p.rungs)) == [xic: 3, jmp: 3, lbl: 4, xic: 4, ote: 4]
    end

    test "what a rung a jump may skip writes or runs is written and run" do
      p =
        program!("""
        var a bool
        var b bool
        var e bool
        var t1 ton
        var k ctu
        xic a jmp done
        xic a ons e ote b
        xic a ton t1 100
        xic a ctu k 3
        lbl done
        """)

      assert Walk.writes(p) == %{"b" => [7], "e" => [7], "t1" => [8], "k" => [9]}
      assert Walk.timers(p) == %{"t1" => {8, 100}}
      assert Walk.counters(p) == %{"k" => {9, 3}}
      assert Walk.one_shots(p) == %{"e" => {7, :ons}}
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

    # M3-3: an arithmetic instruction reads its sources and writes its destination, by its
    # slots, so a total that is its own source is read and written on one line.
    test "an arithmetic instruction writes its destination, a member by its path, and reads " <>
           "its sources" do
      p =
        program!("""
        var_input flow dint
        var total dint
        var t1 ton
        add total flow total
        xic t1.dn ton t1 100
        mul flow -2 t1.pre sub 0 t1.acc total
        """)

      assert Walk.writes(p) == %{"total" => [4, 6], "t1" => [5, 6]}
      assert Walk.member_writes(p) == %{"t1.pre" => [6]}

      assert for({access, name, 4, :add} <- Walk.uses(p.rungs, p.tags), do: {access, name}) ==
               [value: "total", value: "flow", write: "total"]
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

  # Decision 96: which members a program writes, each by its path, which an edit reads for
  # a member input it leaves unwritten.
  describe "member_writes/1" do
    test "each member a write slot names, by its path, each line a write, in rung order, a " <>
           "`cal`'s var_output filling one among them" do
      seal = block!(@seal)

      p =
        program!(
          """
          var a bool
          var n dint
          var t1 ton
          var c ctu
          var l rto
          var s1 seal
          xic a ton t1 100
          xic t1.dn move 7 t1.pre
          xic a ote c.r move n c.pv
          xic a ctu c 5
          xic c.q otl l.r
          xic a rto l 50
          move 0 t1.acc
          cal s1 a a l.r
          xic t1.dn ote a
          """,
          [seal]
        )

      assert Walk.member_writes(p) == %{
               "t1.pre" => [8],
               "c.r" => [9],
               "c.pv" => [9],
               "l.r" => [11, 14],
               "t1.acc" => [13]
             }

      # A read is no write, nor is an instance run.
      assert Walk.member_writes(
               program!("var a bool\nvar t1 ton\nxic a ton t1 5\nxic t1.dn ote a")
             ) ==
               %{}
    end

    test "it reaches into each block a `cal` runs, at any depth, by path, with the body's own " <>
           "lines, and into none it does not run" do
      hold =
        block!("""
        function_block hold
        var_input clr bool
        var_input go bool
        var_output q bool
        var c ctu
        xic clr ote c.r
        xic go ctu c 3
        xic c.q ote q
        """)

      outer =
        block!(
          """
          function_block outer
          var_input go bool
          var_output q bool
          var h hold
          var t ton
          cal h go go q
          xic go move 9 t.pre
          xic go ton t 20
          """,
          [hold]
        )

      p =
        program!(
          "var_input go bool\nvar_output y bool\nvar o outer\nvar idle outer\ncal o go y\n",
          [outer]
        )

      assert Walk.member_writes(p) == %{"o.h.c.r" => [6], "o.t.pre" => [7]}
    end
  end

  # M3-4: the one-shots a program runs, at any depth, which a configuration's event-task
  # warning reads (decision 103).
  describe "one_shots/1" do
    test "each storage bit of an `ons`, `osr` or `osf`, to the line and symbol of its " <>
           "one-shot, a coil's pulse bit none" do
      p =
        program!("""
        var a bool
        var s1 bool
        var s2 bool
        var s3 bool
        var q bool
        xic a osf s2 q ( ons s1 | xic q )
        xic s1 osr s3 q
        """)

      assert Walk.one_shots(p) == %{"s1" => {6, :ons}, "s2" => {6, :osf}, "s3" => {7, :osr}}
    end

    test "the first one-shot in rung order, where a program built by hand has two" do
      p = program!("var a bool\nvar s bool\nvar q bool\nxic a osr s q\n")
      [{:rung, [xic, _osr]}] = p.rungs
      second = {:ons, 5, [{:name, 5, "s"}]}
      twice = %{p | rungs: p.rungs ++ [{:rung, [xic, second]}]}
      assert Walk.one_shots(twice) == %{"s" => {4, :osr}}
    end

    test "it reaches into each block a `cal` runs, at any depth, by path, at the body's " <>
           "one-shot" do
      seal = block!(@seal)
      pair = block!(@pair, [seal])

      p =
        program!(
          "var_input go bool\nvar s9 bool\nvar p pair\nvar out bool\ncal p go out\n" <>
            "xic go osf s9 out\n",
          [pair]
        )

      assert Walk.one_shots(p) == %{"s9" => {6, :osf}, "p.s.edge" => {7, :ons}}
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

    # Each block type's own writes, timers and one-shots are read once a call, however many
    # instances run it: at 100 instances, 4x the rungs of the block's body cost little more,
    # 1.49x to 1.50x over 37 runs on Elixir 1.20.4, 21 alone and 16 beside three full
    # suites, and with one_shots/1 walked too since M3-4's review, 1.505x to 1.511x over 48,
    # 16 alone, 16 beside two full suites and 16 beside three; with the body read again for
    # each instance, about 4x. The bound is a fifth above the highest.
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
          Walk.member_writes(p)
          Walk.timers(p)
          Walk.one_shots(p)
        end)
      end

      ratio = walk.(200) / walk.(50)
      assert ratio < 1.82, "4x the body's rungs took #{Float.round(ratio, 2)}x the reductions"
    end

    # A chain of n block types, each holding the next and running it: each level's facts
    # are put once, from the top down, so 16x the depth, 20 levels to 320, cost 15.74x in
    # each of 32 runs on Elixir 1.20.4, 16 alone and 16 beside three full suites, and with
    # one_shots/1 walked too since M3-4's review, 15.79x to 15.83x over 48, 16 alone, 16
    # beside two full suites and 16 beside three. The bound is a fifth above the highest;
    # with each level's facts put by path as each level returned them, 129.7x. The walk itself takes milliseconds: nearly all the test's time
    # is building the chain, each level's compile checking every type below it again
    # (decision 54), quadratic in the depth: 800 levels took 11 s alone, up to 36 s beside
    # three full suites, and ran out ExUnit's minute four suites at once; 320 take 2 s.
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
          Walk.member_writes(p)
          Walk.timers(p)
          Walk.one_shots(p)
        end)
      end

      ratio = walk.(320) / walk.(20)
      assert ratio < 19.0, "16x the depth took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
