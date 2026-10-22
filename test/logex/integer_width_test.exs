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

  # What a message says of a value that does not fit, in its type's words.
  defp misfit(type, shown), do: misfit_of(Keyword.fetch!(@widths, type), type, shown)
  defp misfit_of({:signed, n}, _type, shown), do: "#{shown} does not fit in #{n} bits"

  defp misfit_of({:unsigned, _n}, type, shown),
    do: "#{shown} is outside 0 to #{elem(limits(type), 1)}"

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
                   "`c` is not declared",
                   "`d` is not declared"
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

    # Arithmetic and comparison read and write dints alone until PLAN M5-4, so another
    # width in one of their slots is told the conversion that bridges it.
    test "an arithmetic or comparison slot is a dint's, another width told its conversion" do
      for type <- @types -- [:dint] do
        assert messages(
                 "var i #{type}\nvar d dint\nvar b bool\nadd i 1 d\nadd d 1 i\neq i 5 ote b"
               ) == [
                 "`add` reads a dint, but `i` is #{a(type)} (declared on line 1): convert it " <>
                   "first, with `#{type}_to_dint`",
                 "`add` writes a dint, but `i` is #{a(type)} (declared on line 1): write a " <>
                   "dint and convert it, with `dint_to_#{type}`",
                 "`eq` reads a dint, but `i` is #{a(type)} (declared on line 1): convert it " <>
                   "first, with `#{type}_to_dint`"
               ]
      end
    end
  end

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

      assert messages(
               "var s sint\nvar i int\nvar d dint\nvar b bool\nsint_to_dint 200 d\n" <>
                 "dint_to_int s i\ndint_to_int d d\ndint_to_int b i\nint_to_dint 5 5"
             ) == [
               "`sint_to_dint` reads an sint: `200` does not fit in 8 bits",
               "`dint_to_int` reads a dint, but `s` is an sint (declared on line 1): use " <>
                 "`sint_to_int`",
               "`dint_to_int` writes an int, but `d` is a dint (declared on line 3): use `move`",
               "`dint_to_int` reads a dint, but `b` is a bool (declared on line 4)",
               "`int_to_dint` expects a tag, found `5`"
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
