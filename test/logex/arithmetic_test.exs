defmodule Logex.ArithmeticTest do
  @moduledoc """
  M3-3: IEC's arithmetic on dints, `add`, `sub`, `mul`, `div` and `mod`, and `neg` and
  `abs` (docs/organisation.md decisions 78, 79 and 98; docs/naming.md, each mnemonic's
  stanza), each rule of a scan pinned from
  source through `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted.
  Since M5-2 a result outside the dint wraps, its low 32 bits kept in two's complement,
  and passes no power on that scan, with no fault (decision 146, superseding decision 77's
  saturation on purpose): every test of a limit below pins the wrap. Since M5-4 every rule
  holds at every integer width, computed in the destination's type, each source widening
  into it by Ed 3 Figure 11, and the comparisons read two integers of any types by value
  (decisions 145, 146 and 147): the last three groups below, which restate each width's
  range, Figure 11 and the wrap from IEC's tables rather than read them from `lib/`.
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

    # Until decision 173 each of these read 0, `neg` writing 0 with power.
    test "a source a hand-built env holds as no integer is refused before the scan" do
      p = c!(String.replace(@one, "OP", "neg"))

      for junk <- [nil, 1.5, %{}, :x] do
        state = %Instance{type: "m", env: %{"go" => 1, "a" => junk}, now: 0, first: true}

        assert_raise ArgumentError,
                     "state.env holds `a` outside its type: it is a dint, and its value must " <>
                       "be an integer, found #{inspect(junk)}",
                     fn -> Runtime.call(p, state, %{}, %Scan{now: 0, first: true}) end
      end
    end
  end

  describe "a source a hand-built env holds outside the dint" do
    # Decision 171, superseding M5-2's provisional reading (computed exactly, then wrapped):
    # a value outside its tag's type is the host's mistake, refused before the scan, so no
    # such source ever reaches `add`.
    @outside """
    var v dint
    var r dint
    var k bool
    add v 0 r ote k
    """

    defp outside(v) do
      p = c!(@outside)
      state = %Instance{type: "m", env: %{"v" => v, "r" => 0, "k" => 1}, now: 0, first: true}

      try do
        Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
      rescue
        e in ArgumentError -> e.message
      end
    end

    test "is refused before the scan, as the host's mistake" do
      for v <- [5_000_000_000, -5_000_000_000, Integer.pow(2, 70)] do
        assert outside(v) ==
                 "state.env holds `v` outside its type: it is a dint, and #{v} is outside " <>
                   "-2147483648 to 2147483647"
      end

      assert {%{}, %Instance{env: %{"r" => 2_147_483_647, "k" => 1}}} =
               outside_ok(2_147_483_647)
    end

    defp outside_ok(v) do
      p = c!(@outside)
      state = %Instance{type: "m", env: %{"v" => v, "r" => 0, "k" => 1}, now: 0, first: true}
      Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
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

    # Until decision 173 a source that is no integer read 0, `add` giving 4 with power and
    # a divisor that is no integer a zero one; now no such source reaches a scan.
    test "a source a hand-built env holds as no integer is refused before the scan" do
      p = c!(String.replace(@two, "OP", "add"))
      d = c!(String.replace(@two, "OP", "div"))

      for junk <- [nil, 1.5, %{"x" => 1}, :x, "7"] do
        message =
          &("state.env holds `#{&1}` outside its type: it is a dint, and its value must be " <>
              "an integer, found #{inspect(junk)}")

        state = %Instance{
          type: "m",
          env: %{"go" => 1, "a" => junk, "b" => 4},
          now: 0,
          first: true
        }

        assert_raise ArgumentError, message.("a"), fn ->
          Runtime.call(p, state, %{}, %Scan{now: 0, first: true})
        end

        state = %{state | env: %{"go" => 1, "a" => 7, "b" => junk}}

        assert_raise ArgumentError, message.("b"), fn ->
          Runtime.call(d, state, %{}, %Scan{now: 0, first: true})
        end
      end
    end
  end

  # M5-4 (decisions 145, 146 and 147): every rule above at every integer width. Each width's
  # range, Ed 3 Figure 11's "i" cells and the wrap are restated here, from IEC's Table 10
  # and Figure 11, never read from `Logex.Declarations`, so that a wrong row of its table
  # is seen.
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

  defp bounds(type), do: bounds_of(Keyword.fetch!(@widths, type))
  defp bounds_of({:signed, n}), do: {-Integer.pow(2, n - 1), Integer.pow(2, n - 1) - 1}
  defp bounds_of({:unsigned, n}), do: {0, Integer.pow(2, n) - 1}

  # The low N bits of an exact result, read in two's complement for a signed type: a
  # remainder by 2^N, shifted to the type's least value.
  defp wrap(type, value) do
    {low, _high} = bounds(type)
    {_kind, n} = Keyword.fetch!(@widths, type)
    Integer.mod(value - low, Integer.pow(2, n)) + low
  end

  defp exact(type, value), do: {wrap(type, value), power(wrap(type, value) == value)}
  defp power(true), do: 1
  defp power(false), do: 0

  defp signed?(type), do: elem(Keyword.fetch!(@widths, type), 0) == :signed

  # The values a width's tests meet: its two limits, one inside each, and 0, 1 and -1
  # where it holds them.
  defp samples(type) do
    {low, high} = bounds(type)
    Enum.uniq(Enum.filter([low, low + 1, -1, 0, 1, high - 1, high], &(&1 >= low)))
  end

  defp typed(op, a, b, r) do
    c!("""
    var_input go bool
    var_input a #{a}
    var_input b #{b}
    var_output r #{r}
    var_output ok bool
    xic go #{op} a b r ote ok
    """)
  end

  defp scan(program, input) do
    Runtime.call(program, Runtime.instance(program), input, %Scan{now: 0, first: true})
  end

  defp run(program, input) do
    {out, _state} = scan(program, input)
    {out["r"], out["ok"]}
  end

  defp exact_of(:add, a, b), do: a + b
  defp exact_of(:sub, a, b), do: a - b
  defp exact_of(:mul, a, b), do: a * b
  # IEC's truncation toward zero, and its remainder IN1 - (IN1/IN2)*IN2, restated.
  defp exact_of(:div, a, b), do: sign(a * b) * Kernel.div(abs(a), abs(b))
  defp exact_of(:mod, a, b), do: a - exact_of(:div, a, b) * b

  defp sign(product) when product < 0, do: -1
  defp sign(_product), do: 1

  describe "every integer width (M5-4)" do
    test "127 + 1 in an sint gives -128 and 0 - 1 in a usint 255, each with no power" do
      assert run(typed("add", :sint, :sint, :sint), %{"go" => 1, "a" => 127, "b" => 1}) ==
               {-128, 0}

      assert run(typed("sub", :usint, :usint, :usint), %{"go" => 1, "a" => 0, "b" => 1}) ==
               {255, 0}

      assert run(typed("add", :ulint, :ulint, :ulint), %{
               "go" => 1,
               "a" => Integer.pow(2, 64) - 1,
               "b" => 1
             }) == {0, 0}

      assert run(typed("sub", :lint, :lint, :lint), %{
               "go" => 1,
               "a" => -Integer.pow(2, 63),
               "b" => 1
             }) == {Integer.pow(2, 63) - 1, 0}
    end

    test "`add`, `sub`, `mul`, `div` and `mod` at each width's limits, in its own type" do
      for {type, _kind} <- @widths, op <- [:add, :sub, :mul, :div, :mod] do
        program = typed(op, type, type, type)

        for a <- samples(type), b <- samples(type), b != 0 do
          assert run(program, %{"go" => 1, "a" => a, "b" => b}) ==
                   exact(type, exact_of(op, a, b)),
                 "#{op} #{a} #{b} in #{type}"
        end
      end
    end

    test "`neg` and `abs` at each width's limits, the minimum alone wrapping to itself" do
      for {type, _kind} <- @widths, signed?(type), op <- ["neg", "abs"] do
        program =
          c!(
            "var_input go bool\nvar_input a #{type}\nvar_output r #{type}\n" <>
              "var_output ok bool\nxic go #{op} a r ote ok"
          )

        for a <- samples(type) do
          {out, _state} = scan(program, %{"go" => 1, "a" => a})
          expected = exact(type, (op == "neg" && -a) || abs(a))
          assert {out["r"], out["ok"]} == expected, "#{op} #{a} in #{type}"
        end

        {low, _high} = bounds(type)
        {out, _state} = scan(program, %{"go" => 1, "a" => low})
        assert {out["r"], out["ok"]} == {low, 0}
      end

      # An unsigned source negated into a signed type it widens into is exact.
      program =
        c!("var_input a usint\nvar_output r int\nvar_output ok bool\nneg a r ote ok")

      assert run(program, %{"a" => 255}) == {-255, 1}

      program =
        c!("var_input a uint\nvar_output r uint\nvar_output ok bool\nabs a r ote ok")

      assert run(program, %{"a" => 65_535}) == {65_535, 1}
    end

    # Decision 147: the instruction computes in its destination's type, each source
    # widened into it, so two ints into a dint cannot overflow, where IEC's overloaded
    # INT + INT computes in INT (Ed 3 p.70, Example 3).
    test "sources of every type Figure 11 widens into the destination's, computed there" do
      for {from, intos} <- @figure_11, into <- intos, op <- [:add, :sub, :mul, :div, :mod] do
        program = typed(op, from, into, into)

        for a <- samples(from),
            b <- [elem(bounds(into), 0), elem(bounds(into), 1), -1, 1],
            b >= elem(bounds(into), 0),
            b != 0 do
          assert run(program, %{"go" => 1, "a" => a, "b" => b}) ==
                   exact(into, exact_of(op, a, b)),
                 "#{op} #{from} #{a} #{into} #{b}"
        end
      end

      assert run(typed("add", :int, :int, :dint), %{"go" => 1, "a" => 32_767, "b" => 32_767}) ==
               {65_534, 1}

      assert run(typed("mul", :usint, :sint, :int), %{"go" => 1, "a" => 255, "b" => -128}) ==
               {-32_640, 1}
    end

    test "a source no Figure 11 cell widens into the destination's type is refused, " <>
           "naming its conversion" do
      for {from, _} <- @widths,
          {into, _} <- @widths,
          from != into,
          into not in Map.fetch!(@figure_11, from) do
        assert messages("var a #{from}\nvar r #{into}\nadd a r r\nadd r a r") ==
                 for(
                   _ <- 1..2,
                   do:
                     "`add` computes in `r`'s type, #{article(into)}, but `a` is " <>
                       "#{article(from)} (declared on line 1): #{article(from)} does not " <>
                       "widen into #{article(into)}, so convert it first, with " <>
                       "`#{from}_to_#{into}`"
                 ),
               "#{from} into #{into}"
      end
    end

    # The Done-when's three-operand mismatch: each source alone is an integer, as each slot
    # takes, and only the instruction held whole sees that a dint does not widen into the
    # sint it writes.
    test "a three-operand mismatch is refused, the instruction checked whole" do
      assert messages("var d dint\nvar i int\nvar s sint\nadd d i s") == [
               "`add` computes in `s`'s type, an sint, but `d` is a dint (declared on line 1): " <>
                 "a dint does not widen into an sint, so convert it first, with `dint_to_sint`",
               "`add` computes in `s`'s type, an sint, but `i` is an int (declared on line 2): " <>
                 "an int does not widen into an sint, so convert it first, with `int_to_sint`"
             ]

      assert messages("var d dint\nvar s sint\nvar ok bool\nadd s s d ote ok\nmod s d d") == []
    end

    test "a literal source must fit the destination's type" do
      for {type, _kind} <- @widths do
        {low, high} = bounds(type)

        assert messages("var r #{type}\nadd r #{high} r\nsub #{low} r r") == []

        assert messages("var r #{type}\nadd r #{high + 1} r\nsub #{low - 1} r r") == [
                 "`add` computes in `r`'s type, #{article(type)}: `#{high + 1}` is outside " <>
                   "#{low} to #{high}",
                 "`sub` computes in `r`'s type, #{article(type)}: `#{low - 1}` is outside " <>
                   "#{low} to #{high}"
               ]
      end
    end

    # Decision 145: an unsigned type holds no negative value, so a `neg` into one could
    # only give 0 or a wrap; and since decision 181 it is told the narrowest signed type its
    # source widens into by Ed 3 Figure 11, or a literal source fits, to declare it.
    @signed_for %{
      sint: "an sint",
      int: "an int",
      dint: "a dint",
      lint: "an lint",
      usint: "an int",
      uint: "a dint",
      udint: "an lint"
    }

    test "`neg` into an unsigned destination is refused, told a signed type to declare it" do
      refused = fn type ->
        "`neg` writes `r`, #{article(type)} (declared on line 2), which holds no negative " <>
          "value: `neg` writes a signed type"
      end

      for {type, {:unsigned, _}} <- @widths do
        assert messages("var a #{type}\nvar r #{type}\nneg a r\nneg 5 r\nneg -1 r\nneg 200 r") ==
                 [
                   refused.(type) <> source_told(type),
                   refused.(type) <> ", so declare `r` an sint",
                   refused.(type) <> ", so declare `r` an sint",
                   refused.(type) <> ", so declare `r` an int"
                 ]
      end

      for {source, _} <- @widths, source != :ulint do
        assert messages("var a #{source}\nvar r usint\nneg a r") == [
                 refused.(:usint) <> ", so declare `r` #{Map.fetch!(@signed_for, source)}"
               ]
      end

      assert messages("var t ton\nvar r usint\nneg 9223372036854775808 r") == [
               refused.(:usint) <> ", and none holds `9223372036854775808`"
             ]

      assert messages("var t ton\nvar r usint\nneg t.acc r") == [
               refused.(:usint) <> ", so declare `r` a dint"
             ]

      assert messages("var a usint\nvar r usint\nabs a r") == []
    end

    test "a zero divisor writes 0, passes no power and is a fault, at every width" do
      for {type, _kind} <- @widths, op <- ["div", "mod"] do
        program = typed(op, type, type, type)
        {_low, high} = bounds(type)
        {out, state} = scan(program, %{"go" => 1, "a" => high, "b" => 0})
        assert {out["r"], out["ok"]} == {0, 0}
        assert [%Logex.Fault{kind: :divide_by_zero, line: 6}] = state.faults

        assert [%Logex.Diagnostic{message: "`" <> _}] =
                 diagnostics("var r #{type}\n#{op} r 0 r")
      end
    end

    test "the minimum divided by -1 wraps to itself, and a remainder takes the dividend's " <>
           "sign, at every signed width" do
      for {type, {:signed, _}} <- @widths do
        {low, high} = bounds(type)

        assert run(typed("div", type, type, type), %{"go" => 1, "a" => low, "b" => -1}) ==
                 {low, 0}

        modulo = typed("mod", type, type, type)
        assert run(modulo, %{"go" => 1, "a" => low, "b" => -1}) == {0, 1}
        assert run(modulo, %{"go" => 1, "a" => -7, "b" => 3}) == {-1, 1}
        assert run(modulo, %{"go" => 1, "a" => 7, "b" => -3}) == {1, 1}
        assert run(modulo, %{"go" => 1, "a" => low, "b" => high}) == {-1, 1}
      end
    end

    test "a member's destination computes in the member's type" do
      p = c!("var c ctu\nvar ok bool\nadd c.pv 2147483647 c.pv ote ok")
      {out, state} = scan(p, %{})
      assert out == %{}
      assert state.env["c"]["pv"] == 2_147_483_647
      {_out, state} = Runtime.call(p, state, %{}, %Scan{now: 10, first: false})
      assert {state.env["c"]["pv"], state.env["ok"]} == {-2, 0}
    end

    test "a block's body computes in its own tags' types" do
      {:ok, small} =
        Logex.compile(
          "function_block small\nvar_input n sint\nvar_output total sint\n" <>
            "var_output fits bool\nadd total n total ote fits",
          name: "small"
        )

      p =
        c!(
          "var_input n sint\nvar_output t sint\nvar_output f bool\nvar s1 small\ncal s1 n t f",
          [small]
        )

      assert trace(p, [%{"n" => 100}, %{"n" => 27}, %{"n" => 1}]) == [
               %{"t" => 100, "f" => 1},
               %{"t" => 127, "f" => 1},
               %{"t" => -128, "f" => 0}
             ]
    end
  end

  describe "a division computed in its destination's type (M5-4's review)" do
    # `div` and `mod` wrap their result into the destination's type, never a source's: a
    # divisor narrower than the destination, or of another kind, changes nothing.
    defp quotient_in(decl, rung, inputs, tag) do
      p = c!("var_input go bool\n#{decl}\nvar_output ok bool\nxic go #{rung} ote ok")

      {outputs, state} =
        Runtime.call(p, Runtime.instance(p), Map.put(inputs, "go", 1), %Scan{now: 0, first: true})

      {state.env[tag], outputs["ok"]}
    end

    test "an int quotient by an sint divisor wraps in the int" do
      decl = "var_input a int\nvar_input b sint\nvar q int"

      assert quotient_in(decl, "div a b q", %{"a" => -32_768, "b" => -1}, "q") ==
               {-32_768, 0}

      assert quotient_in(decl, "div a b q", %{"a" => 300, "b" => 1}, "q") == {300, 1}
    end

    test "an int remainder by a usint divisor keeps the dividend's sign in the int" do
      decl = "var_input a int\nvar_input b usint\nvar q int"
      assert quotient_in(decl, "mod a b q", %{"a" => -7, "b" => 3}, "q") == {-1, 1}
      assert quotient_in(decl, "mod a b q", %{"a" => -300, "b" => 255}, "q") == {-45, 1}
    end
  end

  describe "the worked examples of docs/naming.md's M5-4 amendments" do
    # Each example the arithmetic and comparison stanzas give, as they give it, so that a
    # stanza and the scan cannot differ (M5-4's review found one that did).
    defp example(decl, rung, inputs) do
      source = "var_input go bool\n#{decl}\nvar_output ok bool\nxic go #{rung} ote ok"

      case Logex.compile(source, name: "m") do
        {:ok, p} ->
          {_outputs, state} =
            Runtime.call(p, Runtime.instance(p), Map.put(inputs, "go", 1), %Scan{
              now: 0,
              first: true
            })

          Map.drop(state.env, ["go" | Map.keys(inputs)])

        {:error, diagnostics} ->
          Enum.map(diagnostics, & &1.message)
      end
    end

    test "add, sub and mul" do
      assert example("var s sint", "add 127 1 s", %{}) == %{"s" => -128, "ok" => 0}

      assert example("var_input day_total dint\nvar small int", "add day_total 1 small", %{}) ==
               [
                 "`add` computes in `small`'s type, an int, but `day_total` is a dint " <>
                   "(declared on line 2): a dint does not widen into an int, so convert it " <>
                   "first, with `dint_to_int`"
               ]

      assert example("var_input i1 int\nvar_input i2 int\nvar d dint", "add i1 i2 d", %{
               "i1" => 32_767,
               "i2" => 32_767
             }) == %{"d" => 65_534, "ok" => 1}

      assert example("var u usint", "sub 0 1 u", %{}) == %{"u" => 255, "ok" => 0}
      assert example("var s sint", "mul 16 16 s", %{}) == %{"s" => 0, "ok" => 0}

      assert example("var_input w usint\nvar d dint", "mul w w d", %{"w" => 255}) ==
               %{"d" => 65_025, "ok" => 1}

      assert example("var_input w usint\nvar d int", "mul w w d", %{"w" => 255}) ==
               %{"d" => -511, "ok" => 0}
    end

    test "div, mod, neg and the comparisons" do
      assert example("var s sint", "div -128 -1 s", %{}) == %{"s" => -128, "ok" => 0}
      assert example("var s sint", "mod -7 3 s", %{}) == %{"s" => -1, "ok" => 1}
      assert example("var s sint", "neg -128 s", %{}) == %{"s" => -128, "ok" => 0}

      assert example("var u usint", "neg 1 u", %{}) == [
               "`neg` writes `u`, a usint (declared on line 2), which holds no negative " <>
                 "value: `neg` writes a signed type, so declare `u` an sint"
             ]

      assert example("var_input level dint\nvar count usint", "neg level count", %{}) == [
               "`neg` writes `count`, a usint (declared on line 3), which holds no negative " <>
                 "value: `neg` writes a signed type, so declare `count` a dint"
             ]

      assert example("var_input level ulint\nvar count usint", "neg level count", %{}) == [
               "`neg` writes `count`, a usint (declared on line 3), which holds no negative " <>
                 "value: `neg` writes a signed type, and a ulint widens into none, so convert " <>
                 "`level` first, with `ulint_to_lint`, and declare `count` an lint"
             ]

      assert example("var_input w usint\nvar i int", "neg w i", %{"w" => 255}) ==
               %{"i" => -255, "ok" => 1}

      assert example("var_input s sint\nvar_input u udint", "lt s u", %{"s" => -1, "u" => 0}) ==
               %{"ok" => 1}

      assert example("var_input s sint", "lt s 200", %{"s" => 127}) == [
               "`lt` compares `200` with `s`, an sint (declared on line 2), which never holds " <>
                 "it: `200` is outside -128 to 127"
             ]

      assert example("var_input s sint", "lt s 127", %{"s" => 126}) == %{"ok" => 1}
      assert example("var_input u usint", "ge u 0", %{"u" => 0}) == %{"ok" => 1}
    end
  end

  describe "the cost over every integer width (M5-4)" do
    # Each instruction is held whole once at its compile, and each scan finds its
    # destination's type in the routine's one table, so a program of 4x the instructions and
    # 4x the tags compiles and scans in about 4x the reductions. The compile and the scan
    # are measured apart, since a scan is a few percent of a compile's reductions and a
    # quadratic scan would hide inside the sum (M5-4's review).
    defp mixed(n) do
      "var_input v sint\nvar_input w usint\nvar c ctu\n" <>
        Enum.map_join(1..n, fn i -> "var r#{i} int\nvar q#{i} udint\n" end) <>
        Enum.map_join(1..n, fn i ->
          "add v w r#{i}\nmul w w q#{i}\nsub r#{i} 1 r#{i}\nadd c.pv v c.pv\n" <>
            "div q#{i} w q#{i}\nneg v r#{i}\n"
        end)
    end

    defp least(fun) do
      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    defp to_compile(n) do
      text = mixed(n)
      least(fn -> {:ok, _} = Logex.compile(text, name: "p") end)
    end

    defp to_scan(n) do
      {:ok, p} = Logex.compile(mixed(n), name: "p")
      state = Runtime.put_inputs(p, Runtime.instance(p), %{"v" => -128, "w" => 255})
      least(fn -> Runtime.scan(p, state) end)
    end

    test "arithmetic over mixed widths costs linear reductions to compile" do
      ratio = to_compile(400) / to_compile(100)
      assert ratio < 4.8, "4x the instructions took #{Float.round(ratio, 2)}x the reductions"
    end

    test "arithmetic over mixed widths costs linear reductions to scan" do
      ratio = to_scan(400) / to_scan(100)
      assert ratio < 4.8, "4x the instructions took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  describe "comparisons over every integer width (M5-4)" do
    # Decision 147: two integers compare by value whatever their types, exact at their
    # limits, a signed -1 less than an unsigned 0 and a ulint's top greater than a lint's.
    test "a signed with an unsigned operand, each at its limits, by value" do
      for {left, _} <- @widths, {right, _} <- @widths do
        program =
          c!(
            "var_input a #{left}\nvar_input b #{right}\n" <>
              Enum.map_join(~w(eq ne lt gt le ge), fn op ->
                "var_output #{op}_ok bool\n"
              end) <>
              Enum.map_join(~w(eq ne lt gt le ge), "\n", &"#{&1} a b ote #{&1}_ok")
          )

        for a <- samples(left), b <- samples(right) do
          {out, _state} = scan(program, %{"a" => a, "b" => b})

          assert out == %{
                   "eq_ok" => power(a == b),
                   "ne_ok" => power(a != b),
                   "lt_ok" => power(a < b),
                   "gt_ok" => power(a > b),
                   "le_ok" => power(a <= b),
                   "ge_ok" => power(a >= b)
                 },
                 "#{left} #{a} against #{right} #{b}"
        end
      end
    end

    # Decision 183: a literal compared with a tag is a value of the tag's type, as IEC's
    # typed comparison types its literal, for each of the six comparisons, on either side:
    # one outside it would make the comparison's result never change. Two literals are each
    # within every integer type's values, as M5-4 has it.
    test "a literal compared with a tag must be a value of the tag's type, at every width, " <>
           "and two literals within every integer type's values" do
      for {type, _kind} <- @widths, op <- ~w(eq ne lt gt le ge) do
        {low, high} = bounds(type)

        assert messages("var s #{type}\nvar b bool\n#{op} s #{low} ote b\n#{op} #{high} s ote b") ==
                 []

        assert messages(
                 "var s #{type}\nvar b bool\n#{op} s #{high + 1} ote b\n#{op} #{low - 1} s ote b"
               ) ==
                 for(
                   value <- [high + 1, low - 1],
                   do:
                     "`#{op}` compares `#{value}` with `s`, #{article(type)} (declared on line " <>
                       "1), which never holds it: `#{value}` is outside #{low} to #{high}"
                 )
      end

      assert messages("var t ton\nvar b bool\nlt t.acc 2147483648 ote b") == [
               "`lt` compares `2147483648` with `t.acc`, a dint, which never holds it: " <>
                 "`2147483648` is outside -2147483648 to 2147483647"
             ]

      assert messages("var b bool\neq 18446744073709551615 -9223372036854775808 ote b") == []

      # A literal beside a tag outside the class, a bool, told so by its slot, is held to
      # every integer type's values, on either side.
      bool = "`lt` reads a number, but `b` is a bool (declared on line 1)"

      past =
        "`lt` reads a number: `18446744073709551616` is outside -9223372036854775808 to " <>
          "18446744073709551615, every integer type's values"

      assert messages(
               "var b bool\nvar q bool\nlt b 18446744073709551616 ote q\n" <>
                 "lt 18446744073709551616 b ote q\nlt b 300 ote q"
             ) == [bool, past, bool, past, bool]

      assert messages("var b bool\nlt 18446744073709551616 0 ote b") == [
               "`lt` reads a number: `18446744073709551616` is outside -9223372036854775808 " <>
                 "to 18446744073709551615, every integer type's values"
             ]

      p = c!("var_input s sint\nvar_output b bool\nlt s 127 ote b")
      {out, _state} = scan(p, %{"s" => 126})
      assert out == %{"b" => 1}
    end
  end

  defp diagnostics(source) do
    {:error, diagnostics} = Logex.compile(source, name: "m")
    diagnostics
  end

  defp messages(source) do
    case Logex.compile(source, name: "m") do
      {:ok, _program} -> []
      {:error, diagnostics} -> Enum.map(diagnostics, & &1.message)
    end
  end

  defp source_told(:ulint),
    do:
      ", and a ulint widens into none, so convert `a` first, with `ulint_to_lint`, and " <>
        "declare `r` an lint"

  defp source_told(type), do: ", so declare `r` #{Map.fetch!(@signed_for, type)}"

  defp article(type) when type in [:int, :lint, :usint, :uint, :udint, :ulint, :sint],
    do: "#{article_of(type)} #{type}"

  defp article(type), do: "a #{type}"

  defp article_of(type) when type in [:int, :lint, :sint], do: "an"
  defp article_of(_type), do: "a"
end
