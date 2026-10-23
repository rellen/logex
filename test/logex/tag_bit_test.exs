defmodule Logex.TagBitTest do
  @moduledoc """
  PLAN M5-9: a bit number held in a tag, `status.[n]` (`docs/organisation.md` §4.12,
  decision 160), and the first major fault, a bit number outside its word's bits when an
  instruction reads or writes the bit (decisions 153 and 160, amending decisions 99 and
  113), every rule from source through `Logex.compile/2`, `Logex.Runtime.call/4` and
  `Logex.Edit`: the tag of any integer width, on every integer type and bit string and a
  member's; the refusals at their lines; each instruction that may hold such a bit doing
  nothing on a number out of range, passing no power, the scan running on, its major fault
  in `state.faults` with the number read; a de-energised instruction that reads and writes
  nothing, a rung a jump skips and a block whose `cal` is false checking nothing (decision
  82); the warnings and an edit's rung; and the read's cost in reductions against a
  literal bit's and a bool's, with a program of none scanning as it did before M5-9.

  Bit n of a word, the widths and two's complement are restated here from IEC's text and
  Logix's (RM018A pp.884–885), never read from `Logex.Declarations`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Edit, Fault, Runtime, Scan}

  @widths [
    sint: {:signed, 8},
    int: {:signed, 16},
    dint: {:signed, 32},
    lint: {:signed, 64},
    usint: {:unsigned, 8},
    uint: {:unsigned, 16},
    udint: {:unsigned, 32},
    ulint: {:unsigned, 64},
    byte: {:unsigned, 8},
    word: {:unsigned, 16},
    dword: {:unsigned, 32},
    lword: {:unsigned, 64}
  ]

  defp width(type), do: elem(Keyword.fetch!(@widths, type), 1)
  defp kind(type), do: elem(Keyword.fetch!(@widths, type), 0)

  # Restated: bit n of a value in its type's N bits, two's complement where signed.
  defp bit_of(type, value, n),
    do: rem(div(Integer.mod(value, Integer.pow(2, width(type))), Integer.pow(2, n)), 2)

  defp with_bit(type, value, n, b) do
    p = Integer.mod(value, Integer.pow(2, width(type)))
    raised = p - bit_of(type, value, n) * Integer.pow(2, n) + b * Integer.pow(2, n)
    signed(kind(type), raised, Integer.pow(2, width(type) - 1))
  end

  defp signed(:signed, low, half) when low >= half, do: low - 2 * half
  defp signed(_kind, low, _half), do: low

  defp samples(type), do: samples_of(kind(type), width(type))

  defp max_of(type), do: max_of(kind(type), width(type))
  defp max_of(:signed, n), do: Integer.pow(2, n - 1) - 1
  defp max_of(:unsigned, n), do: Integer.pow(2, n) - 1

  defp samples_of(:signed, n),
    do: [-Integer.pow(2, n - 1), -1, 0, 1, -91, Integer.pow(2, n - 1) - 1]

  defp samples_of(:unsigned, n), do: [0, 1, 0xA5, Integer.pow(2, n) - 1]

  defp program(source, types \\ [], name \\ "p") do
    {:ok, program} = Logex.compile(source, name: name, types: types)
    program
  end

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "p", types: types)
    Enum.map(diagnostics, &{&1.line, &1.message})
  end

  defp warnings(source), do: Enum.map(program(source).warnings, &{&1.line, &1.message})

  # One scan through call/4, from a new instance: the outputs and the scan's faults.
  defp scan(program, inputs, state \\ nil) do
    state = state || Runtime.instance(program)
    {outputs, state} = Runtime.call(program, state, inputs, %Scan{now: 0, first: true})
    {outputs, state.faults}
  end

  defp fault(instruction, line, read, path \\ nil, file \\ nil),
    do: %Fault{
      severity: :major,
      kind: :bit_out_of_range,
      instruction: instruction,
      path: path,
      file: file,
      line: line,
      read: read
    }

  describe "the bit a tag numbers (decision 160)" do
    test "every bit of every integer type and bit string is read and written through any integer tag" do
      for type <- Keyword.keys(@widths), index <- [:sint, :usint, :dint, :ulint] do
        p =
          program(
            "var_input w #{type}\nvar_input n #{index}\nvar_input set bool\n" <>
              "var_output seen bool\nvar_output on #{type}\nvar_output off #{type}\n" <>
              "var_output kept #{type}\nxic w.[n] ote seen\nmove w on\nmove w off\nmove w kept\n" <>
              "xic set otl on.[n]\nxic set otu off.[n]\nxio set ote kept.[n]"
          )

        for n <- Enum.uniq([0, 1, 3, width(type) - 2, width(type) - 1]),
            n <= max_of(index),
            value <- samples(type),
            set <- [0, 1] do
          assert scan(p, %{"w" => value, "n" => n, "set" => set}) ==
                   {%{
                      "seen" => bit_of(type, value, n),
                      "on" => (set == 1 && with_bit(type, value, n, 1)) || value,
                      "off" => (set == 1 && with_bit(type, value, n, 0)) || value,
                      "kept" => with_bit(type, value, n, 1 - set)
                    }, []},
                 inspect({type, index, n, value, set})
        end
      end
    end

    test "a member's bit is read through a tag, and written where the member may be" do
      p =
        program(
          "var_input k bool\nvar_input n int\nvar c ctu\nvar_output v dint\nvar_output s bool\n" <>
            "xic k ote c.pv.[n]\nxic c.pv.[n] ote s\nmove c.pv v\nctu c 100"
        )

      assert scan(p, %{"k" => 1, "n" => 3}) == {%{"v" => 100 + 8, "s" => 1}, []}
      # 100 is 2#110_0100: its bit 2 is set already.
      assert scan(p, %{"k" => 1, "n" => 2}) == {%{"v" => 100, "s" => 1}, []}
      assert scan(p, %{"k" => 0, "n" => 2}) == {%{"v" => 100 - 4, "s" => 0}, []}

      assert messages("var t ton\nvar_input n int\nvar_input a bool\nxic a ote t.dn.[n]") == [
               {4, "`t.dn.[n]` names a bit of `t.dn`, a bool, which has no bits"}
             ]
    end

    test "a bit's number tag is a use of it, read, and its word written by a coil" do
      p =
        program(
          "var w word\nvar_input n int\nvar_input go bool\nvar_output q bool\n" <>
            "xic go ote w.[n]\nxic w.0 ote q"
        )

      assert p.warnings == []

      assert Logex.Walk.uses(p.rungs, Logex.Program.typed_tags(p)) == [
               {:read, "go", 5, :xic},
               {:write, "w", 5, :ote},
               {:read, "n", 5, :ote},
               {:read, "w", 6, :xic},
               {:write, "q", 6, :ote}
             ]

      assert Logex.Walk.writes(p) == %{"w" => [5], "q" => [6]}
      assert Logex.Walk.bit_writes(p) == %{}

      # Read only through its bit, a var_output is still one no rung writes.
      assert warnings("var_output w word\nvar_input n int\nvar_output q bool\nxic w.[n] ote q") ==
               [{1, "`w` is a var_output, but no rung writes it: it stays at 0"}]
    end
  end

  describe "what is refused when the program compiles (decisions 154 and 160)" do
    test "a bit of a bool or an instance, and a number tag that is no integer, each at its line" do
      assert messages(
               "var b bool\nvar w word\nvar t1 ton\nvar n int\nvar m word\nvar f bool\n" <>
                 "var c ctu\nvar_output q bool\n" <>
                 "xic b.[n] ote q\nxic t1.[n] ote q\nxic w.[m] ote q\nxic w.[f] ote q\n" <>
                 "xic w.[c] ote q\nxic w.[nope] ote q\nxic w.[and] ote q\nxic none.[n] ote q"
             ) == [
               {9, "`b.[n]` names a bit of `b`, a bool, which has no bits"},
               {10,
                "`t1.[n]` names a bit of `t1`, but `t1` is a ton (declared on line 3): only an " <>
                  "integer or a bit string has bits"},
               {11,
                "`w.[m]` takes its bit number from `m`, a word (declared on line 5), which is no " <>
                  "integer: a bit number is held in a tag of an integer type, so convert it " <>
                  "first, with `word_to_uint`"},
               {12,
                "`w.[f]` takes its bit number from `f`, a bool (declared on line 6), which is no " <>
                  "integer: a bit number is held in a tag of an integer type"},
               {13,
                "`w.[c]` takes its bit number from `c`, but `c` is a ctu (declared on line 7): a " <>
                  "bit number is held in a tag of an integer type"},
               {14, "`nope` is not declared"},
               {15,
                "`w.[and]` takes its bit number from `and`, an instruction, which cannot name a tag"},
               {16, "`none` is not declared"}
             ]
    end

    # M5-9's review: a `cal`'s operand is checked as any instruction's, its number's tag
    # declared and of an integer type, whether the block reads it or writes it.
    test "a `cal` operand's bit number is checked as any instruction's" do
      {:ok, b} =
        Logex.compile("function_block b\nvar_input s bool\nvar_output q bool\nxic s ote q",
          name: "b"
        )

      assert messages("var w word\nvar b1 b\nvar_output y bool\ncal b1 w.[x] y", [b]) ==
               [{4, "`x` is not declared"}]

      assert messages("var w word\nvar f bool\nvar b1 b\nvar_output y bool\ncal b1 w.[f] y", [b]) ==
               [
                 {5,
                  "`w.[f]` takes its bit number from `f`, a bool (declared on line 2), which is " <>
                    "no integer: a bit number is held in a tag of an integer type"}
               ]

      assert messages("var_input go bool\nvar r word\nvar f bool\nvar b1 b\ncal b1 go r.[f]", [b]) ==
               [
                 {5,
                  "`r.[f]` takes its bit number from `f`, a bool (declared on line 3), which is " <>
                    "no integer: a bit number is held in a tag of an integer type"}
               ]
    end

    test "an undeclared number's tag is reported once, as any undeclared tag" do
      assert messages("var w word\nvar_output q bool\nxic w.[sel] ote q") ==
               [{3, "`sel` is not declared"}]

      assert [{1, "`w` is not declared"}, _q] = messages("xic w.[sel] ote q")
    end

    test "a one-shot's storage bit and a pulse coil's pulse bit take a literal number" do
      assert messages(
               "var w word\nvar s bool\nvar_input n int\nvar_input a bool\nxic a ons w.[n]\n" <>
                 "xic a osr w.[n] s\nxic a osf s w.[n]"
             ) == [
               {5,
                "`ons` keeps its storage bit in `w.[n]`, whose number `n` holds: a one-shot's " <>
                  "storage bit is a bool or a bit with a literal number, as in `w.0`, so that it " <>
                  "is one bit whatever the program does"},
               {6,
                "`osr` keeps its storage bit in `w.[n]`, whose number `n` holds: a one-shot's " <>
                  "storage bit is a bool or a bit with a literal number, as in `w.0`, so that it " <>
                  "is one bit whatever the program does"},
               {7,
                "`osf` sets its pulse bit in `w.[n]`, whose number `n` holds: a pulse coil's " <>
                  "pulse bit is a bool or a bit with a literal number, as in `w.0`, so that it " <>
                  "is one bit whatever the program does"}
             ]
    end

    test "a bit is a bool: where no bool goes, it is refused as a bool" do
      assert messages("var_input w word\nvar_input n int\nvar_output q dint\nmove w.[n] q") == [
               {4,
                "`move` writes `w.[n]`, a bool, into `q`, a dint: a bool does not widen into a " <>
                  "dint, and logex has no conversion between them"}
             ]
    end
  end

  describe "a number out of range at run time: the major fault (decisions 153 and 160)" do
    @word "var_input w word\nvar_input n dint\nvar_input go bool\n"

    test "a contact passes no power, the rest of its rung running on that, and the scan finishes" do
      p =
        program(
          @word <>
            "var_output a bool\nvar_output b bool\nvar_output c bool\n" <>
            "xic w.[n] ote a\nxio w.[n] ote b\nxic go ote c"
        )

      for n <- [16, 17, -1, 1000] do
        assert scan(p, %{"w" => 0xFFFF, "n" => n, "go" => 1}) ==
                 {%{"a" => 0, "b" => 0, "c" => 1}, [fault(:xic, 7, n), fault(:xio, 8, n)]}
      end

      assert scan(p, %{"w" => 0xFFFF, "n" => 15, "go" => 1}) ==
               {%{"a" => 1, "b" => 0, "c" => 1}, []}
    end

    test "a coil writes nothing and passes no power, energised or, for `ote`, not" do
      p =
        program(
          @word <>
            "var_input on bool\nvar_output o word\nvar_output l word\nvar_output u word\n" <>
            "var_output after bool\nmove w o\nmove w l\nmove w u\n" <>
            "xic on ote o.[n] ote after\nxic on otl l.[n]\nxic on otu u.[n]"
        )

      for on <- [0, 1] do
        # A de-energised `otl` or `otu` reads and writes nothing, so checks nothing (RM018A
        # pp.86-87); a de-energised `ote` writes its 0, and so checks.
        faults =
          [fault(:ote, 12, 16)] ++
            if(on == 1, do: [fault(:otl, 13, 16), fault(:otu, 14, 16)], else: [])

        assert scan(p, %{"w" => 0x00F0, "n" => 16, "on" => on}) ==
                 {%{"o" => 0x00F0, "l" => 0x00F0, "u" => 0x00F0, "after" => 0}, faults}
      end
    end

    test "a `move` of a bit, or into one, writes nothing and passes no power" do
      p =
        program(
          @word <>
            "var_input b bool\nvar_output from bool\nvar_output into word\nvar_output ran bool\n" <>
            "var_output next bool\nmove 1 from\nmove w into\n" <>
            "xic go move w.[n] from ote ran\nxic go move b into.[n] ote next"
        )

      assert scan(p, %{"w" => 1, "n" => 16, "go" => 1, "b" => 1}) ==
               {%{"from" => 1, "into" => 1, "ran" => 0, "next" => 0},
                [fault(:move, 11, 16), fault(:move, 12, 16)]}

      assert scan(p, %{"w" => 1, "n" => 0, "go" => 1, "b" => 0}) ==
               {%{"from" => 1, "into" => 0, "ran" => 1, "next" => 1}, []}
    end

    test "a bitwise instruction or a shift of a bit, or into one, writes nothing and passes no power" do
      p =
        program(
          @word <>
            "var_input b bool\nvar_output d bool\nvar_output e word\nvar_output f bool\n" <>
            "var_output g bool\nvar_output ran bool\nmove 1 d\nmove 1 e\nmove 1 f\nmove 1 g\n" <>
            "and w.[n] b d ote ran\nxor b b e.[n] ote ran\nnot w.[n] f ote ran\n" <>
            "shl w.[n] 0 g ote ran\nror b 1 e.[n] ote ran"
        )

      assert scan(p, %{"w" => 0, "n" => 99, "b" => 0}) ==
               {%{"d" => 1, "e" => 1, "f" => 1, "g" => 1, "ran" => 0},
                [
                  fault(:and, 14, 99),
                  fault(:xor, 15, 99),
                  fault(:not, 16, 99),
                  fault(:shl, 17, 99),
                  fault(:ror, 18, 99)
                ]}
    end

    test "a `cal` whose operand's number is out of range does nothing, its body not run" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input s bool\nvar_output q bool\nvar_output runs dint\n" <>
            "add runs 1 runs\nxic s ote q",
          name: "seal"
        )

      p =
        program(
          @word <>
            "var s1 seal\nvar_output q bool\nvar_output out word\nvar_output runs dint\n" <>
            "var_output passed bool\n" <>
            "var s2 seal\nvar_output runs2 dint\n" <>
            "xic go cal s1 w.[n] q runs ote passed\nxic go cal s2 go out.[n] runs2",
          [seal]
        )

      assert scan(p, %{"w" => 0xFFFF, "n" => 16, "go" => 1}) ==
               {%{"runs" => 0, "runs2" => 0, "passed" => 0, "q" => 0, "out" => 0},
                [fault(:cal, 11, 16), fault(:cal, 12, 16)]}

      assert scan(p, %{"w" => 0xFFFF, "n" => 15, "go" => 1}) ==
               {%{"runs" => 1, "runs2" => 1, "passed" => 1, "q" => 1, "out" => 0x8000}, []}
    end

    # M5-9's review (provisional reading 2): a copy-out that meets a number out of range
    # drops the body's run whole, its minor faults among it, so the scan gives the `cal`'s
    # major fault alone.
    test "a `cal` whose copy-out is out of range drops its body's minor faults with its run" do
      {:ok, ratio} =
        Logex.compile(
          "function_block ratio\nvar_input z dint\nvar_output q bool\nvar_output r dint\n" <>
            "var on bool 1\ndiv 10 z r\nxic on ote q",
          name: "ratio"
        )

      p =
        program(
          @word <> "var r1 ratio\nvar_output out word\nvar_output r dint\ncal r1 0 out.[n] r",
          [ratio]
        )

      assert scan(p, %{"n" => 16}) == {%{"out" => 0, "r" => 0}, [fault(:cal, 7, 16)]}

      assert scan(p, %{"n" => 2}) ==
               {%{"out" => 4, "r" => 0},
                [
                  %Fault{
                    severity: :minor,
                    kind: :divide_by_zero,
                    instruction: :div,
                    path: "r1",
                    file: nil,
                    line: 6,
                    read: nil
                  }
                ]}
    end

    # A `cal`'s formals are any number, so its catch is its own, wherever the bit stands.
    test "a `cal` whose fourth operand or later is out of range does nothing" do
      {:ok, all3} =
        Logex.compile(
          "function_block all3\nvar_input a bool\nvar_input b bool\nvar_input c bool\n" <>
            "var_output q bool\nxic a xic b xic c ote q",
          name: "all3"
        )

      p =
        program(
          @word <>
            "var a1 all3\nvar_output q bool\nvar_output passed bool\n" <>
            "xic go cal a1 go go w.[n] q ote passed",
          [all3]
        )

      assert scan(p, %{"w" => 0xFFFF, "n" => 16, "go" => 1}) ==
               {%{"q" => 0, "passed" => 0}, [fault(:cal, 7, 16)]}

      assert scan(p, %{"w" => 0xFFFF, "n" => 3, "go" => 1}) == {%{"q" => 1, "passed" => 1}, []}
    end

    test "a fault in a block's body is named by the instance's path, in the body's file" do
      dir = Path.join(System.tmp_dir!(), "logex_tag_bit_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(
        Path.join(dir, "lamp.ld"),
        "function_block lamp\nvar_input w word\nvar_input n int\nvar_output q bool\n" <>
          "// the selected bit\nxic w.[n] ote q\n"
      )

      File.write!(
        Path.join(dir, "panel.ld"),
        "var_input w word\nvar_input n int\nvar_output q bool\nvar_output after bool\n" <>
          "var l1 lamp\ncal l1 w n q\nxic w.0 ote after\n"
      )

      assert {:ok, p} = Logex.compile_file(Path.join(dir, "panel.ld"))

      assert scan(p, %{"w" => 1, "n" => 16}) ==
               {%{"q" => 0, "after" => 1}, [fault(:xic, 6, 16, "l1", Path.join(dir, "lamp.ld"))]}
    end

    # A block's body holding such a bit is a compiled body like any other, which a type
    # given must be (Logex.Compiler.lowered?/1): its bit relowers to itself, its width, top
    # bit, tag and name as its type gives them.
    test "a block's body holding a bit a tag numbers is taken as given, and a forged one is not" do
      {:ok, lamp} =
        Logex.compile(
          "function_block lamp\nvar_input w int\nvar_input n int\nvar_output q bool\n" <>
            "xic w.[n] ote q",
          name: "lamp"
        )

      assert Logex.FbType.user?(lamp)
      assert Logex.Compiler.lowered?(lamp.body)

      [{:rung, [{:xic, line, [{:bit_at, l, path, index, {16, top}, name}]} | rest]}] =
        lamp.body.rungs

      assert {path, index, top, name} == {["w"], {:name, l, "n"}, -32_768, "w.[n]"}

      for forged <- [
            {:bit_at, l, path, index, {16, 32_768}, name},
            {:bit_at, l, path, index, {8, top}, name},
            {:bit_at, l, path, {:name, l, "w"}, {16, top}, name},
            {:bit_at, l, path, index, {16, top}, "w.[m]"},
            {:bit_at, -l, path, index, {16, top}, name},
            {:bit_at, l, path, index, {16, top}, :name}
          ] do
        body = put_in(lamp.body.rungs, [{:rung, [{:xic, line, [forged]} | rest]}])
        refute Logex.Compiler.lowered?(body), inspect(forged)
      end
    end

    test "every fault of one scan, in the order they happened, beside a zero divisor's" do
      p =
        program(
          @word <>
            "var_input z dint\nvar_output q dint\nvar_output a bool\n" <>
            "xic w.[n] ote a\ndiv 1 z q\nxio w.[n] ote a"
        )

      assert {_, [first, divided, last]} = scan(p, %{"w" => 0, "n" => 32, "z" => 0})
      assert first == fault(:xic, 7, 32)
      assert %Fault{severity: :minor, kind: :divide_by_zero, line: 8} = divided
      assert last == fault(:xio, 9, 32)
    end

    test "the next scan's faults are its own, and a number back in range raises none" do
      p = program(@word <> "var_output a bool\nxic w.[n] ote a")
      state = Runtime.instance(p)

      {_out, state} =
        Runtime.call(p, state, %{"w" => 1, "n" => 16}, %Scan{now: 0, first: true})

      assert state.faults == [fault(:xic, 5, 16)]
      {out, state} = Runtime.call(p, state, %{"n" => 0}, %Scan{now: 10, first: false})
      assert {out, state.faults} == {%{"a" => 1}, []}
    end
  end

  describe "what runs nothing checks nothing (decision 82)" do
    @word_skip "var_input w word\nvar_input n dint\nvar_input skip bool\nvar_output a bool\n" <>
                 "var_output b bool\n"

    test "a rung a jump skips raises nothing, and runs on the next scan it is not skipped" do
      p =
        program(
          @word_skip <>
            "xic skip jmp done\nxic w.[n] ote a\nlbl done xic w.0 ote b"
        )

      assert scan(p, %{"w" => 1, "n" => 16, "skip" => 1}) == {%{"a" => 0, "b" => 1}, []}

      assert scan(p, %{"w" => 1, "n" => 16, "skip" => 0}) ==
               {%{"a" => 0, "b" => 1}, [fault(:xic, 7, 16)]}
    end

    test "a block whose `cal` is false raises nothing" do
      {:ok, lamp} =
        Logex.compile(
          "function_block lamp\nvar_input w word\nvar_input n int\nvar_output q bool\n" <>
            "xic w.[n] ote q",
          name: "lamp"
        )

      p =
        program(
          "var_input w word\nvar_input n int\nvar_input run bool\nvar_output q bool\n" <>
            "var l1 lamp\nxic run cal l1 w n q",
          [lamp]
        )

      assert scan(p, %{"w" => 1, "n" => 16, "run" => 0}) == {%{"q" => 0}, []}

      assert scan(p, %{"w" => 1, "n" => 16, "run" => 1}) ==
               {%{"q" => 0}, [fault(:xic, 5, 16, "l1")]}
    end
  end

  describe "the warnings (provisional)" do
    test "a coil on a bit a tag numbers is a coil on its word whole" do
      head = "var w word\nvar_input n int\nvar_input m int\nvar_input a bool\n"

      assert warnings(head <> "xic a ote w.[n]\nxic a ote w.[m]") == [
               {6, "`w.[m]` already has an `ote` on line 5: the last one in the scan decides it"}
             ]

      head = "var w word\nvar_input n int\nvar_input a bool\n"

      assert warnings(head <> "xic a ote w.3\nxic a ote w.[n]") == [
               {5, "`w.3` already has an `ote` on line 4: the last one in the scan decides it"}
             ]

      assert warnings(head <> "xic a ote w.[n]\nxic a ote w.3") == [
               {5,
                "`w.3` is a bit of `w`, which the `ote` on line 4 writes whole: the last one in " <>
                  "the scan decides it"}
             ]
    end

    test "a write into a bit a tag numbers, beside a coil on a bit of its word, is a whole write" do
      assert warnings(
               "var w word\nvar_input n int\nvar_input a bool\nxic a ote w.3\nmove a w.[n]"
             ) == [
               {5, "`w.3` already has an `ote` on line 4: the last one in the scan decides it"}
             ]
    end

    test "a write of a bit a tag numbers is a write of each storage bit in its word" do
      assert warnings(
               "var w word\nvar_input n int\nvar_input a bool\nvar_output p bool\n" <>
                 "xic a ons w.3 ote p\nxic a ote w.[n]"
             ) == [
               {6,
                "`ote` writes `w.3`, the storage bit of the `ons` on line 5: the one-shot then " <>
                  "fires on the wrong scans"}
             ]
    end
  end

  describe "an online edit" do
    test "a one-shot's rung is changed by its bit's tag, and blocked where its word is written through one" do
      head =
        "var_input go bool\nvar_input n int\nvar_input m int\nvar s word\nvar_output p bool\n"

      v1 = program(head <> "xic go xic s.[n] ons s.3 ote p")
      v2 = program(head <> "xic go xic s.[m] ons s.3 ote p")

      {_out, ran} = Runtime.scan(v1, Runtime.instance(v1))
      {:ok, _edit, forecast} = Edit.accept(v1, v2, ran)
      assert Enum.any?(forecast, &match?({:ons_blocked, "s.3", _}, &1))

      {:ok, _edit, forecast} = Edit.accept(v1, v1, ran)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))

      # M5-9's review: the rung is changed by its bit's word too, the number's tag kept.
      worded = head <> "var t word\n"
      w1 = program(worded <> "xic go xic s.[n] ons s.3 ote p\nxic go ote t.0")
      w2 = program(worded <> "xic go xic t.[n] ons s.3 ote p\nxic go ote t.0")
      {_out, ran} = Runtime.scan(w1, Runtime.instance(w1))
      {:ok, _edit, forecast} = Edit.accept(w1, w2, ran)
      assert Enum.any?(forecast, &match?({:ons_blocked, "s.3", _}, &1))

      # A member's bit written through a tag is a write of the member, which an edit does
      # not report unwritten (decision 96).
      counted = "var_input k bool\nvar_input x dint\nvar_input n int\nvar c ctu\n"
      was = program(counted <> "move x c.pv\nctu c 100")
      now = program(counted <> "xic k ote c.pv.[n]\nctu c 100")
      {_out, ran} = Runtime.scan(was, Runtime.instance(was))
      {:ok, _edit, forecast} = Edit.accept(was, now, ran)
      refute Enum.any?(forecast, &match?({:unwritten, _, _}, &1))
      {:ok, _edit, forecast} = Edit.accept(was, program(counted <> "ctu c 100"), ran)
      assert Enum.any?(forecast, &match?({:unwritten, "c.pv", _}, &1))

      v3 = program(head <> "xic go ons s.3 ote p\nxic go ote s.[n]")
      {_out, ran} = Runtime.scan(v3, Runtime.instance(v3))
      {:ok, _edit, forecast} = Edit.accept(v3, v3, ran)
      assert Enum.any?(forecast, &match?({:ons_blocked, "s.3", _}, &1))
    end
  end

  describe "in a configuration" do
    defp lamp do
      program(
        "var_external status word\nvar_external sel int\nvar_output lamp bool\n" <>
          "var_input clear bool\nxic status.[sel] ote lamp\nxic clear otu status.[sel]",
        [],
        "lamp"
      )
    end

    defp configured(text) do
      case Logex.Configuration.compile("plant", text, %{"lamp" => lamp()}) do
        {:ok, configuration} -> {:ok, configuration}
        {:error, diagnostics} -> Enum.map(diagnostics, & &1.message)
      end
    end

    test "a var_external read only as a bit's number is used, and one written through a bit is driven" do
      assert {:ok, config} =
               configured(
                 "var_global status word\nvar_global sel int\nvar_global lamp_q bool\n" <>
                   "var_global clr bool\nprogram m1 lamp\nm1.lamp lamp_q\nm1.clear clr"
               )

      assert config.warnings == []
    end

    test "a bit of an input point written through a tag is refused as a write to the point" do
      assert [message] =
               configured(
                 "var_global status word at drive.i.0\nvar_global sel int\n" <>
                   "var_global lamp_q bool\nvar_global clr bool\nprogram m1 lamp\n" <>
                   "m1.lamp lamp_q\nm1.clear clr"
               )

      assert message =~ "`status`"
      assert message =~ "input point"
    end
  end

  describe "growth, in reductions" do
    # Counted in a process of its own with a heap the collector never visits, so each count
    # is the same on every run: a scan's reductions for each rung, the difference of 200
    # rungs and 100 over 100.
    defp per_rung(head, rung) do
      cost = fn n ->
        source = head.(n) <> Enum.map_join(1..n, "\n", rung)
        {:ok, p} = Logex.compile(source, name: "p", types: [seal()])
        state = Runtime.instance(p)
        inputs = for {k, %{section: :var_input}} <- p.tags, into: %{}, do: {k, 1}
        parent = self()

        {_pid, ref} =
          :erlang.spawn_opt(
            fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              Runtime.call(p, state, inputs, %Scan{now: 0, first: true})
              {:reductions, later} = Process.info(self(), :reductions)
              send(parent, {:reductions, later - before})
            end,
            [:monitor, min_heap_size: 8_000_000]
          )

        assert_receive {:reductions, r}, 10_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
        r
      end

      (cost.(200) - cost.(100)) / 100
    end

    defp seal do
      {:ok, seal} =
        Logex.compile("function_block seal\nvar_input s bool\nvar_output q bool\nxic s ote q",
          name: "seal"
        )

      seal
    end

    defp fixed(text), do: fn _n -> text end

    # PLAN M5-9's Done-when: a bit read through a tag stays within a measured bound of a
    # literal bit's and a bool's. Measured: 35 reductions a rung against a literal bit's 27
    # and a bool's 24, the number's read, its mask and the instruction's catch.
    test "a bit read through a tag costs a bounded few reductions more than a literal bit" do
      tag_bit =
        per_rung(fixed("var_input w word\nvar_input n int\nvar_output q bool\n"), fn _ ->
          "xic w.[n] ote q"
        end)

      literal =
        per_rung(fixed("var_input w word\nvar_output q bool\n"), fn _ -> "xic w.3 ote q" end)

      bool = per_rung(fixed("var_input a bool\nvar_output q bool\n"), fn _ -> "xic a ote q" end)

      assert tag_bit <= literal + 8,
             "a tag's bit took #{tag_bit} a rung, a literal one #{literal}"

      assert tag_bit / bool < 1.5, "a tag's bit took #{Float.round(tag_bit / bool, 2)}x a bool's"
    end

    # A program with no bit numbered by a tag scans, rung for rung, in exactly the reductions
    # it took at 1ee676b, before M5-9: an instruction is caught only where its clause's head
    # sees such a bit among its operands. A `cal` is always caught, its formals any number,
    # one reduction more a run.
    test "a program of none scans as it did before M5-9, a `cal` one reduction more" do
      assert per_rung(
               fixed("var_input a bool\nvar_input b bool\nvar_output q bool\n"),
               fn _ -> "xic a xio b ote q" end
             ) == 34.0

      assert per_rung(fixed("var_input w word\nvar_output q bool\n"), fn _ -> "xic w.3 ote q" end) ==
               27.0

      assert per_rung(fixed("var_input a uint\nvar_output d dint\n"), fn _ -> "move a d" end) ==
               17.0

      cals = fn n ->
        "var_input a bool\nvar_output q bool\n" <>
          Enum.map_join(1..n, "\n", &"var s#{&1} seal") <> "\n"
      end

      assert_in_delta per_rung(cals, &"cal s#{&1} a q"), 177.01 + 1, 0.001
    end

    test "a program's tag bits cost linear reductions to compile and to scan" do
      source = fn n ->
        "var_input w word\nvar_input n int\nvar_output q word\n" <>
          Enum.map_join(1..n, "\n", fn _ -> "xic w.[n] ote q.[n]" end)
      end

      compile = fn n ->
        text = source.(n)
        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, _} = Logex.compile(text, name: "p")
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end

      _warm = compile.(10)
      assert compile.(400) / compile.(200) < 2.4
    end
  end
end
