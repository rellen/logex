defmodule Logex.ElementBitTest do
  @moduledoc """
  Decision 221, the maintainer's answer of 2026-10-23 to M5-11's second question: a bit of
  an array element, a literal one, `faults[2].3`, and one a tag numbers, `faults[2].[n]`,
  wherever the same bit of a plain tag is, by every rule a tag's bit has, from source
  through `Logex.compile/2`, `Logex.Runtime.call/4`, `Logex.Walk`, `Logex.Edit` and
  `Logex.Configuration`: read and written at every integer type and bit string, in one
  dimension and two; the refusals at their lines; a one-shot's storage bit and a pulse
  coil's bits, literal only (decision 154); the warnings, keyed by value and quoted as
  written; the walk's uses and writes; an edit's rung and block list; the major fault of a
  number out of range (decision 160); a configuration's writers element by element
  (decision 223); and its cost in reductions against a tag's bit.

  Bit n of a word in two's complement is restated here, never read from logex.
  """
  use ExUnit.Case, async: true

  alias Logex.{Edit, Fault, Runtime, Scan, Walk}

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

  defp samples_of(:signed, n),
    do: [-Integer.pow(2, n - 1), -1, 0, 1, -91, Integer.pow(2, n - 1) - 1]

  defp samples_of(:unsigned, n), do: [0, 1, 0xA5, Integer.pow(2, n) - 1]

  defp program(source, types \\ [], name \\ "p") do
    {:ok, program} = Logex.compile(source, name: name, types: types)
    program
  end

  defp messages(source) do
    {:error, diagnostics} = Logex.compile(source, name: "p")
    Enum.map(diagnostics, &{&1.line, &1.message})
  end

  defp warnings(source), do: Enum.map(program(source).warnings, &{&1.line, &1.message})

  defp scan(program, inputs, state \\ nil) do
    state = state || Runtime.instance(program)
    {outputs, state} = Runtime.call(program, state, inputs, %Scan{now: 0, first: true})
    {outputs, state}
  end

  defp fault(instruction, line, read),
    do: %Fault{
      severity: :major,
      kind: :bit_out_of_range,
      instruction: instruction,
      path: nil,
      file: nil,
      line: line,
      read: read
    }

  describe "read and written as a tag's bit is (decision 221)" do
    test "every bit of an element of every integer type and bit string, literal and numbered" do
      for {type, _} <- @widths, value <- samples(type), n <- Enum.uniq([0, 3, width(type) - 1]) do
        p =
          program(
            "var_input w #{type}[3]\nvar_input k int\nvar_output a bool\nvar_output b bool\n" <>
              "var_output s #{type}[3]\nvar_output t #{type}[2,2]\nvar_input on bool\n" <>
              "move w[1] s[1]\nmove w[1] t[1,0]\n" <>
              "xic w[1].#{n} ote a\nxic w[1].[k] ote b\nxic on ote s[1].#{n}\nxio on ote t[1,0].[k]"
          )

        for on <- [0, 1] do
          {outputs, _state} =
            scan(p, %{"w" => [0, value, 0], "k" => n, "on" => on})

          assert outputs["a"] == bit_of(type, value, n), "#{type} #{value} bit #{n}"
          assert outputs["b"] == bit_of(type, value, n), "#{type} #{value} bit [#{n}]"
          assert outputs["s"] == [0, with_bit(type, value, n, on), 0], "#{type} #{value}"

          assert outputs["t"] == [[0, 0], [with_bit(type, value, n, 1 - on), 0]],
                 "#{type} #{value}"
        end
      end
    end

    test "every other element and bit is kept" do
      p =
        program(
          "var_input on bool\nvar_output f word[4] 1 2 3 4\nvar_output g sint[2,2]\n" <>
            "xic on ote f[2].15\nxic on otl g[1,1].7"
        )

      {outputs, _} = scan(p, %{"on" => 1})
      assert outputs == %{"f" => [1, 2, 3 + 0x8000, 4], "g" => [[0, 0], [0, -128]]}
      {outputs, _} = scan(p, %{"on" => 0})
      assert outputs == %{"f" => [1, 2, 3, 4], "g" => [[0, 0], [0, 0]]}
    end

    test "a bit of an element is a bool where a bool goes: a move, a bitwise instruction, a cal" do
      {:ok, seal} =
        Logex.compile("function_block seal\nvar_input s bool\nvar_output q bool\nxic s ote q",
          name: "seal"
        )

      p =
        program(
          "var_input f word[2]\nvar_output m bool\nvar_output x bool\nvar_output c word[2]\n" <>
            "var s1 seal\nmove f[1].4 m\nand f[1].4 f[0].0 x\ncal s1 f[1].4 c[0].9",
          [seal]
        )

      assert elem(scan(p, %{"f" => [1, 16]}), 0) == %{"m" => 1, "x" => 1, "c" => [512, 0]}
      assert elem(scan(p, %{"f" => [0, 16]}), 0) == %{"m" => 1, "x" => 0, "c" => [512, 0]}
      assert elem(scan(p, %{"f" => [1, 0]}), 0) == %{"m" => 0, "x" => 0, "c" => [0, 0]}
    end

    test "in a block's body, which compiles again to itself" do
      {:ok, mask} =
        Logex.compile(
          "function_block mask\nvar_input w word\nvar_input n int\nvar_output q bool\n" <>
            "var f word[2]\nmove w f[1]\nxic f[1].2 ote q\nxic q ote f[0].[n]",
          name: "mask"
        )

      assert Logex.Compiler.lowered?(mask.body)
      assert Logex.FbType.user?(mask)

      p =
        program("var_input w word\nvar_input n int\nvar_output q bool\nvar m mask\ncal m w n q", [
          mask
        ])

      assert elem(scan(p, %{"w" => 4, "n" => 1}), 0) == %{"q" => 1}
      assert elem(scan(p, %{"w" => 3, "n" => 1}), 0) == %{"q" => 0}
    end
  end

  describe "what is refused when the program compiles" do
    test "each at its line, quoted as written" do
      head = "var f word[4]\nvar b bool[2]\nvar r real[2]\nvar n int\nvar x bool\n"

      assert messages(head <> "xic f[2].16 ote x") == [
               {6,
                "`f[2].16` names bit 16 of `f[2]`, a word (declared on line 1), which has bits " <>
                  "0 to 15"}
             ]

      assert messages(head <> "xic f[02].[16#10] ote x") == [
               {6,
                "`f[02].[16#10]` names bit 16 of `f[02]`, a word (declared on line 1), which has " <>
                  "bits 0 to 15"}
             ]

      assert messages(head <> "xic f[4].3 ote x") == [
               {6,
                "`f[4].3`'s subscript `4` is outside the elements of `f`, 0 to 3: `f` is an array " <>
                  "of 4 words (declared on line 1)"}
             ]

      assert messages(head <> "xic b[1].0 ote x") == [
               {6, "`b[1].0` names a bit of `b[1]`, a bool, which has no bits"}
             ]

      assert [{6, message}] = messages(head <> "xic r[1].0 ote x")
      assert message =~ "`r[1]`"
      assert [{6, message}] = messages(head <> "xic f[1].3.2 ote x")
      assert message == "`f[1].3.2` goes too deep: `f[1]` is a word, which has no members"
      assert [{6, message}] = messages(head <> "xic f[1].[x] ote x")
      assert message =~ "takes its bit number from `x`, a bool"
    end

    test "a one-shot's storage bit and a pulse coil's bit take a literal number (decision 154)" do
      head = "var e word[2]\nvar p word[2]\nvar n int\nvar x bool\n"

      assert messages(head <> "ons e[1].[n] ote x") == [
               {5,
                "`ons` keeps its storage bit in `e[1].[n]`, whose number `n` holds: a one-shot's " <>
                  "storage bit is a bool or a bit with a literal number, as in `e[1].0`, so that " <>
                  "it is one bit whatever the program does"}
             ]

      assert [{5, message}] = messages(head <> "osr e[1].0 p[0].[n]")
      assert message =~ "sets its pulse bit in `p[0].[n]`"

      # One one-shot to a bit, keyed by value, quoted as written.
      assert [{6, message}] = messages(head <> "ons e[1].0 ote x\nosf e[01].0 p[0].1")
      assert message =~ "`e[01].0`"
      assert message =~ "line 5"

      assert [{5, message}] = messages(head <> "osr e[1].0 e[1].0")
      assert message =~ "is both the storage bit and the pulse bit"
    end
  end

  describe "a one-shot and a pulse coil on a bit of an element" do
    test "fires once on a rising edge, the rest of its word kept" do
      p =
        program(
          "var_input go bool\nvar_output e word[2] 0 240\nvar_output once bool\n" <>
            "var_output pulse word[2]\nxic go ons e[1].0 ote once\nxic go osr e[0].1 pulse[1].2"
        )

      state = Runtime.instance(p)
      {outputs, state} = Runtime.call(p, state, %{"go" => 0}, %Scan{now: 0, first: true})
      assert outputs["once"] == 0
      {outputs, state} = Runtime.call(p, state, %{"go" => 1}, %Scan{now: 10, first: false})
      assert outputs == %{"once" => 1, "e" => [2, 241], "pulse" => [0, 4]}
      {outputs, _} = Runtime.call(p, state, %{"go" => 1}, %Scan{now: 20, first: false})
      assert outputs == %{"once" => 0, "e" => [2, 241], "pulse" => [0, 0]}
    end
  end

  describe "a storage bit of an element on the block list" do
    # Decision 106 for a bit of an element: blocked, its one-shot passes no power on the
    # scan that runs it, and on a rung a jump skips it stays listed until that scan.
    test "is blocked once, and stays listed while a jump skips its rung" do
      p =
        program(
          "var_input skip bool\nvar_input go bool\nvar_output pulse bool\nvar s word[2]\n" <>
            "xic skip jmp done\nxic go ons s[1].3 ote pulse\nlbl done"
        )

      state = %{Runtime.instance(p) | first: false, ons_blocked: ["s[1].3"]}
      {_out, state} = Runtime.scan(p, Runtime.put_inputs(p, state, %{"skip" => 1, "go" => 1}))
      assert state.ons_blocked == ["s[1].3"]
      {out, state} = Runtime.scan(p, Runtime.put_inputs(p, state, %{"skip" => 0, "go" => 1}))
      assert out == %{"pulse" => 0}
      assert state.ons_blocked == []

      # Unblocked, the same rise pulses.
      fresh = %{Runtime.instance(p) | first: false}
      {out, _state} = Runtime.scan(p, Runtime.put_inputs(p, fresh, %{"skip" => 0, "go" => 1}))
      assert out == %{"pulse" => 1}
    end
  end

  describe "a number out of range at run time: the major fault (decision 160)" do
    test "the instruction does nothing, its fault the number read, and a skipped rung checks none" do
      p =
        program(
          "var_input f word[2]\nvar_input n dint\nvar_input go bool\nvar_input skip bool\n" <>
            "var_output a bool\nvar_output o word[2]\nvar_output c bool\n" <>
            "xic f[1].[n] ote a\nxic go ote o[1].[n]\nxic skip jmp past\nxic go otl o[0].[n]\n" <>
            "lbl past xic go ote c"
        )

      {outputs, state} = scan(p, %{"f" => [0, 0xFFFF], "n" => 16, "go" => 1, "skip" => 1})
      assert outputs == %{"a" => 0, "o" => [0, 0], "c" => 1}
      assert state.faults == [fault(:xic, 8, 16), fault(:ote, 9, 16)]

      {outputs, state} = scan(p, %{"f" => [0, 0xFFFF], "n" => -1, "go" => 1, "skip" => 0})
      assert outputs == %{"a" => 0, "o" => [0, 0], "c" => 1}
      assert state.faults == [fault(:xic, 8, -1), fault(:ote, 9, -1), fault(:otl, 11, -1)]

      {outputs, state} = scan(p, %{"f" => [0, 0xFFFF], "n" => 15, "go" => 1, "skip" => 0})
      assert outputs == %{"a" => 1, "o" => [32768, 32768], "c" => 1}
      assert state.faults == []
    end
  end

  describe "the warnings, keyed by value and quoted as written" do
    @later "the last one in the scan decides it"

    defp decides(source), do: Enum.filter(warnings(source), &(elem(&1, 1) =~ @later))

    test "two coils on one bit of an element, and a coil beside a write of the element whole" do
      head = "var f word[2]\nvar_input a bool\nvar_input n int\nvar_input k word\n"

      assert decides(head <> "xic a ote f[1].3\nxic a ote f[01].3") == [
               {6, "`f[01].3` already has an `ote` on line 5: #{@later}"}
             ]

      assert decides(head <> "xic a ote f[1].3\nxic a ote f[0].3") == []

      assert decides(head <> "xic a ote f[1].3\nmove k f[1]") == [
               {6, "`f[1].3` already has an `ote` on line 5: #{@later}"}
             ]

      assert decides(head <> "move k f[1]\nxic a ote f[1].3") == [
               {6,
                "`f[1].3` is a bit of `f[1]`, which the `move` on line 5 writes whole: #{@later}"}
             ]

      assert decides(head <> "move k f[0]\nxic a ote f[1].3") == []

      assert decides(head <> "xic a ote f[1].[n]\nxic a ote f[1].3") == [
               {6,
                "`f[1].3` is a bit of `f[1]`, which the `ote` on line 5 writes whole: #{@later}"}
             ]

      assert decides(head <> "xic a ote f[1].[n]\nxic a ote f[0].3") == []
    end

    test "a write of an element whole writes each storage bit in it" do
      head = "var e word[2]\nvar_input a bool\nvar_input k word\nvar_output p bool\n"

      assert warnings(head <> "xic a ons e[1].3 ote p\nmove k e[1]") == [
               {6,
                "`move` writes `e[1].3`, the storage bit of the `ons` on line 5: the one-shot " <>
                  "then fires on the wrong scans"}
             ]

      assert warnings(head <> "xic a ons e[1].3 ote p\nmove k e[0]") == []
    end
  end

  describe "the walk" do
    test "a bit of an element is a use of its array, its bit and its element written by name" do
      p =
        program(
          "var_input f word[2]\nvar_input n int\nvar o word[2]\nvar_output q bool\n" <>
            "xic f[1].3 ote q\nxic f[0].[n] ote o[1].2\nxic q ote o[01].[n]"
        )

      assert Enum.sort(Walk.uses(p.rungs, Logex.Program.typed_tags(p))) ==
               Enum.sort([
                 {:read, "f", 5, :xic},
                 {:write, "q", 5, :ote},
                 {:read, "f", 6, :xic},
                 {:read, "n", 6, :xic},
                 {:write, "o", 6, :ote},
                 {:read, "q", 7, :xic},
                 {:write, "o", 7, :ote},
                 {:read, "n", 7, :ote}
               ])

      assert Walk.writes(p) == %{"q" => [5], "o" => [6, 7]}
      assert Walk.bit_writes(p) == %{"o[1].2" => [6]}
      assert Walk.element_writes(p) == %{"o[1]" => [6, 7]}
    end
  end

  describe "an online edit" do
    test "a respelt bit changes no rung, and a storage bit is blocked by its name" do
      head = "var_input go bool\nvar_input k word\nvar e word[2]\nvar_output p bool\n"
      v1 = program(head <> "xic go ons e[1].3 ote p")
      v2 = program(head <> "xic go ons e[01].[3] ote p")
      v3 = program(head <> "xic go xic go ons e[1].3 ote p")
      v4 = program(head <> "xic go ons e[1].3 ote p\nxic go move k e[1]")
      v5 = program(head <> "xic go ons e[1].3 ote p\nxic go move k e[0]")

      {_out, ran} = Runtime.scan(v1, Runtime.instance(v1))
      {:ok, _edit, forecast} = Edit.accept(v1, v2, ran)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))

      {:ok, _edit, forecast} = Edit.accept(v1, v3, ran)
      assert Enum.any?(forecast, &match?({:ons_blocked, "e[1].3", _}, &1))

      # The program that last scanned writes the element whole: the bit is blocked.
      {_out, ran4} = Runtime.scan(v4, Runtime.instance(v4))
      {:ok, _edit, forecast} = Edit.accept(v4, v4, ran4)
      assert Enum.any?(forecast, &match?({:ons_blocked, "e[1].3", _}, &1))

      {_out, ran5} = Runtime.scan(v5, Runtime.instance(v5))
      {:ok, _edit, forecast} = Edit.accept(v5, v5, ran5)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))
    end

    test "a rung's bit is compared by its element and number, a numbered one by its tag" do
      head =
        "var_input go bool\nvar_input n int\nvar_input m int\nvar s word[2]\nvar e bool\n" <>
          "var_output p bool\n"

      v1 = program(head <> "xic go xic s[1].[n] ons e ote p")
      v2 = program(head <> "xic go xic s[1].[m] ons e ote p")
      v3 = program(head <> "xic go xic s[0].[n] ons e ote p")
      v4 = program(head <> "xic go xic s[01].[n] ons e ote p")
      {_out, ran} = Runtime.scan(v1, Runtime.instance(v1))

      for {v, blocked} <- [{v2, true}, {v3, true}, {v4, false}] do
        {:ok, _edit, forecast} = Edit.accept(v1, v, ran)
        assert Enum.any?(forecast, &match?({:ons_blocked, "e", _}, &1)) == blocked
      end
    end
  end

  describe "in a configuration (decisions 48 and 223)" do
    defp writer(name, bit),
      do: program("var_external g word[2]\nvar_input go bool\nxic go ote g#{bit}", [], name)

    test "two instances writing one element's bits are told so, different elements nothing" do
      programs = %{
        "wa" => writer("wa", "[0].3"),
        "wb" => writer("wb", "[0].4"),
        "wc" => writer("wc", "[1].4")
      }

      compiled = fn text ->
        {:ok, c} = Logex.Configuration.compile("c", text, programs)
        Enum.map(c.warnings, & &1.message)
      end

      base = "var_global g word[2]\n"

      assert compiled.(base <> "program a wa\nprogram b wb\na.go 1\nb.go 1\n") == [
               "`b` writes `g[0]` through its var_external, as `a` does (line 2): each scan " <>
                 "reads what the other last wrote, and the later write in a cycle stands"
             ]

      assert compiled.(base <> "program a wa\nprogram c wc\na.go 1\nc.go 1\n") == []
    end
  end

  describe "growth, in reductions" do
    defp per_rung(head, rung) do
      cost = fn n ->
        {:ok, p} = Logex.compile(head <> Enum.map_join(1..n, "\n", fn _ -> rung end), name: "p")
        state = Runtime.instance(p)
        parent = self()

        {_pid, ref} =
          :erlang.spawn_opt(
            fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
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

    # Measured: a bit of an element reads in what a tag's bit does, 27 reductions a rung,
    # and is written in one more, 31 against 30; a two-dimension element's bit two and
    # eight more, its element's own copy; and a bit an element's tag numbers as a tag's.
    test "a bit of an element costs what a tag's bit does, give or take its element's copy" do
      tag = per_rung("var w word\nvar a bool\n", "xic w.3 ote a")
      element = per_rung("var w word[4]\nvar a bool\n", "xic w[2].3 ote a")
      grid = per_rung("var w word[2,4]\nvar a bool\n", "xic w[1,2].3 ote a")
      assert tag == 27.0
      assert element == tag
      assert grid <= tag + 2

      tag = per_rung("var w word\nvar a bool\n", "xic a ote w.3")
      element = per_rung("var w word[4]\nvar a bool\n", "xic a ote w[2].3")
      grid = per_rung("var w word[2,4]\nvar a bool\n", "xic a ote w[1,2].3")
      assert element <= tag + 1.5
      assert grid <= tag + 8.5

      tag = per_rung("var w word\nvar n int\nvar a bool\n", "xic w.[n] ote a")
      element = per_rung("var w word[4]\nvar n int\nvar a bool\n", "xic w[2].[n] ote a")
      assert element == tag

      tag = per_rung("var w word\nvar n int\nvar a bool\n", "xic a ote w.[n]")
      element = per_rung("var w word[4]\nvar n int\nvar a bool\n", "xic a ote w[2].[n]")
      assert element <= tag + 1.5
    end
  end
end
