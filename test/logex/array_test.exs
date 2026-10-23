defmodule Logex.ArrayTest do
  @moduledoc """
  PLAN M5-11: arrays of elementary types, one to three dimensions, literal subscripts
  (`docs/organisation.md` §4.12, "Arrays", decisions 151, 154, 157 and 159), every rule
  from source through `Logex.compile/2`, `Logex.Runtime.call/4` and `Logex.Edit`: the
  syntax and its refusals at their columns; the declaration, its sizes and its initial list
  in the elements' order, the rightmost subscript fastest; each element read and written as
  a tag of its elements' type, of every elementary type; the compile-time bound check and
  every other refusal at its line; one-shots and pulse coils on elements; the warnings with
  an element by its name; the host contract, a host's list of the declared shape, the
  outputs given as lists and a state's tuple checked; an online edit's refusal of a type,
  dimension or size changed, a changed initial list reported element by element and a rung
  with `ons edge[2]` blocked once; and an element's read and write in reductions against a
  tag's.

  An array's order and shape are restated here from Logix's text (1756-PM004L pp.34-35,
  "the rightmost subscript varies fastest"), never read from `Logex.Array`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Edit, Runtime, Scan, Tag}

  defp compile(source), do: Logex.compile(source, name: "p")

  defp compiled!(source) do
    {:ok, program} = compile(source)
    program
  end

  defp messages(source) do
    {:error, diagnostics} = compile(source)
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp warnings(source), do: Enum.map(compiled!(source).warnings, &Logex.Diagnostic.format/1)

  defp scan(program, state, inputs, now),
    do: Runtime.call(program, state, inputs, %Scan{now: now, first: state.first})

  # An array's elements as nested lists, restated: the rightmost subscript fastest.
  defp nested(values, [_count]), do: values

  defp nested(values, [count | dims]) do
    size = div(length(values), count)
    values |> Enum.chunk_every(size) |> Enum.map(&nested(&1, dims))
  end

  defp tupled(values) when is_list(values), do: values |> Enum.map(&tupled/1) |> List.to_tuple()
  defp tupled(value), do: value

  describe "the syntax" do
    test "an element and a sized type word lex as one name token, and parse as names" do
      assert {:ok,
              [
                {:name, {1, 1}, "var"},
                {:name, {1, 5}, "grid"},
                {:name, {1, 10}, "int[4,8]"},
                {:rnd, {1, 18}},
                {:name, {2, 1}, "move"},
                {:name, {2, 6}, "grid[1,7]"},
                {:name, {2, 16}, "x"}
              ], 2} = Logex.Lexer.tokenize("var grid int[4,8]\nmove grid[1,7] x")

      for name <- ~w(t[3] cube[0,1,2] w[16#a] w[1_0] w[-1] w[007] flags[slot] g[i,7] m1.t[3]
                     w[2].3 w[2].[n] t[2].dn int[2,2,2,2]) do
        assert {:ok, [{:name, {1, 1}, ^name}], 1} = Logex.Lexer.tokenize(name), name
      end
    end

    test "brackets a name cannot take are named whole, at the name's column" do
      for {source, reason} <- [
            {"xic a[]", {:subscripts, "a[]"}},
            {"xic a[1", {:subscripts, "a[1"}},
            {"xic a[1,]", {:subscripts, "a[1,]"}},
            {"xic a[,1]", {:subscripts, "a[,1]"}},
            {"xic a[ 1]", {:subscripts, "a[ 1]"}},
            {"xic a[1 ]", {:subscripts, "a[1 ]"}},
            {"xic a[1, 2] ote b", {:subscripts, "a[1, 2]"}},
            {"xic a[1.5]", {:subscripts, "a[1.5]"}},
            {"xic a[x.y]", {:subscripts, "a[x.y]"}},
            {"xic a[3x]", {:subscripts, "a[3x]"}},
            {"xic a[8#3]", {:subscripts, "a[8#3]"}},
            {"xic a[-]", {:subscripts, "a[-]"}},
            {"xic a[1][2]", {:after_subscripts, "a[1][2]"}},
            {"xic a[1]x", {:after_subscripts, "a[1]x"}},
            {"xic a[1]]", {:after_subscripts, "a[1]]"}},
            {"xic a[1]3", {:after_subscripts, "a[1]3"}}
          ] do
        assert {:error, {{1, 5}, Logex.Lexer, ^reason}, 1} = Logex.Lexer.tokenize(source),
               source
      end

      assert Logex.Lexer.format_error({:subscripts, "a[1, 2]"}) ==
               "\"a[1, 2]\" is no name: an element's subscripts are one pair of brackets " <>
                 "straight after its array's name, each a number or a tag's name, split by " <>
                 "`,` with no space, as in `grid[1,7]`"

      assert Logex.Lexer.format_error({:after_subscripts, "a[1][2]"}) ==
               "\"a[1][2]\" is no name: an element's subscripts end at their `]`, after which " <>
                 "only a `.` part may follow, so every subscript goes inside the one pair of " <>
                 "brackets, as in `grid[1,7]`"

      # A bracket held apart from its name, a `.` after an element with nothing named after
      # it, and a sign glued after the `]`, are what they were for any name.
      assert {:error, {{1, 7}, Logex.Lexer, {:illegal, "["}}, 1} =
               Logex.Lexer.tokenize("xic a [1]")

      assert {:error, {{1, 9}, Logex.Lexer, {:illegal, "."}}, 1} =
               Logex.Lexer.tokenize("xic a[1].")

      assert {:error, {{1, 5}, Logex.Lexer, {:signed_inside, "a[1]-5"}}, 1} =
               Logex.Lexer.tokenize("xic a[1]-5")
    end

    test "a rung of elements prints back as written" do
      for source <- ["move grid[01,7] cube[0,1,16#2]", "( xic e[0] | xio e[1] ) ote l[2]"] do
        {:ok, tokens, _} = Logex.Lexer.tokenize(source)
        {:ok, ast} = Logex.Parser.parse(tokens)
        assert Logex.Printer.print(ast) == source
      end
    end
  end

  describe "the declaration" do
    test "a sized type word declares an array of its type, of one to three dimensions" do
      program =
        compiled!(
          "var t real[8]\nvar g int[4,8]\nvar c bool[2,3,4]\nvar_input i int[2]\n" <>
            "var_output o word[3]\nvar_external e lreal[2,2]\nmove i[0] g[1,7]\n" <>
            "xic c[1,2,3] ote c[0,0,0]\nmove t[7] e[1,1]\nmove 16#ff o[2]"
        )

      assert %{
               "t" => %Tag{type: {:array, :real, [8]}, section: :var},
               "g" => %Tag{type: {:array, :int, [4, 8]}},
               "c" => %Tag{type: {:array, :bool, [2, 3, 4]}},
               "i" => %Tag{type: {:array, :int, [2]}, section: :var_input},
               "o" => %Tag{type: {:array, :word, [3]}, section: :var_output},
               "e" => %Tag{type: {:array, :lreal, [2, 2]}, section: :var_external}
             } = program.tags

      assert program.arrays == Map.new(program.tags, fn {name, tag} -> {name, tag.type} end)
      assert program.reals == %{"t" => :real, "e" => :lreal}
    end

    test "an array starts at its elements' zero, or at its initial list in the elements' order" do
      program =
        compiled!(
          "var limits int[3] 10 20 30\nvar grid int[2,3] 1 2 3 4 5 6\n" <>
            "var cube usint[2,2,2] 0 1 2 3 4 5 6 7\nvar r real[2] 0.1 2\nvar z lreal[2]\n" <>
            "var b bool[2,2]\nmove limits[0] grid[0,0]\nmove cube[1,1,1] limits[2]\n" <>
            "move r[0] z[1]\nxic b[0,0] ote b[1,1]"
        )

      env = Runtime.instance(program).env
      assert env["limits"] == {10, 20, 30}
      assert env["grid"] == tupled(nested([1, 2, 3, 4, 5, 6], [2, 3]))
      assert env["grid"] == {{1, 2, 3}, {4, 5, 6}}
      assert env["cube"] == {{{0, 1}, {2, 3}}, {{4, 5}, {6, 7}}}
      # A `real`'s element is the single nearest its value, an integer's the real it is.
      assert env["r"] === {0.10000000149011612, 2.0}
      assert env["z"] === {0.0, 0.0}
      assert env["b"] == {{0, 0}, {0, 0}}
    end

    # PLAN M5-11's Done-when: a declaration of four dimensions and an initial list of the
    # wrong length are refused at their lines; and so is every other array a program
    # cannot declare, each told once, its uses excused where its type is none.
    test "an array a program cannot declare is refused at its line" do
      assert messages("var cells int[2,2,2,2]\nvar x dint\nmove cells[0,0,0,0] x") == [
               "line 1: `cells` is declared with 4 dimensions, `[2,2,2,2]`: an array has one " <>
                 "to three, as in `int[8]`, `int[4,8]` or `int[2,3,4]`"
             ]

      assert messages("var limits int[3] 10 20\nvar x dint\nmove limits[0] x") == [
               "line 1: `limits` is an array of 3 ints: its initial list holds 2 values, and " <>
                 "an array's holds one for every element, 3, in the elements' order"
             ]

      assert messages("var w int[2] 1 2 3\nvar x dint\nmove w[1] x") == [
               "line 1: `w` is an array of 2 ints: its initial list holds 3 values, and an " <>
                 "array's holds one for every element, 2, in the elements' order"
             ]

      assert messages("var a int[0]\nvar x dint\nmove a[0] x") == [
               "line 1: `a` is declared with a dimension of 0, `[0]`: each dimension of an " <>
                 "array holds 1 element or more"
             ]

      assert messages("var a bool[300,300]\nvar x bool\nxic a[0,0] ote x") == [
               "line 1: `a` would hold 90000 elements, `[300,300]`: an array holds 65536 at most"
             ]

      assert {:ok, _} = compile("var a bool[256,256]\nvar x bool\nxic a[255,255] ote x")

      assert messages("var a int[n]\nvar x dint\nmove a[0] x") == [
               "line 1: `a` is declared `int[n]`, sized by `n`: an array's sizes are literal " <>
                 "numbers, as in `int[8]`, fixed when the program compiles"
             ]

      assert messages("var lane_t ton[4]\nvar a bool\nxic a ton lane_t[2] 500") == [
               "line 1: `lane_t` is declared `ton[4]`, an array of tons: an array holds " <>
                 "elements of an elementary type, a bool, an integer, a real or a bit string, " <>
                 "and an array of timers, counters or function blocks is not supported yet"
             ]

      assert [
               "line 1: unknown type `foo`: logex has `bool`, " <> _
             ] = messages("var a foo[2]\nvar x dint\nmove a[0] x")

      assert messages("var w bool[2] 1 2\nxic w[0] ote w[1]") == [
               "line 1: `w[1]` is a bool: its initial value must be 0 or 1, found `2`"
             ]

      assert messages("var w int[2] 16#0 16#8000\nmove w[0] w[1]") == [
               "line 1: `w[1]` is an int: `16#8000` is outside -32768 to 32767"
             ]

      assert messages("var w real[2] 1.0e40 0\nmove w[0] w[1]") == [
               "line 1: `w[0]` is a real: `1.0e40` is beyond a real's range, " <>
                 "-3.4028234663852886e38 to 3.4028234663852886e38"
             ]

      assert messages("var w int[2] 1 x\nmove w[0] w[1]") == [
               "line 1: unexpected `x` in the initial list of `w`: an array's initial list " <>
                 "is one literal for every element"
             ]

      assert messages("var w int[2] 1 ( 2 )\nmove w[0] w[1]") == [
               "line 1: a declaration cannot hold a branch group"
             ]

      assert messages("var_input w int[2] 1 2\nvar x dint\nmove w[0] x") == [
               "line 1: `w` is a var_input: its value comes from outside, so it takes no " <>
                 "initial value"
             ]

      assert messages("var_external w int[2] 1 2\nvar x dint\nmove w[0] x") == [
               "line 1: `w` is a var_external: its value is the configuration's global of " <>
                 "that name, so it takes no initial value"
             ]

      assert messages("var int[2]") == [
               "line 1: `var` needs a tag name before the type `int[2]`, as in " <>
                 "`var temps int[2]`"
             ]

      assert messages("var a b int[2]") == [
               "line 1: `var` declares one tag: found `a` and `b` before the type"
             ]

      assert [
               "line 1: `a[2]` cannot name a tag: brackets are kept for an element's " <>
                 "subscripts, as in `temps[3]`"
             ] = messages("var a[2] bool\nvar b bool\nxic b ote b")
    end

    test "from Elixir, an array tag meets every rule a declaration line does" do
      assert %Tag{type: {:array, :int, [4, 8]}, initial: nil} =
               Tag.new!("grid", {:array, :int, [4, 8]})

      assert %Tag{initial: [0.1, 2]} = Tag.new!("r", {:array, :real, [2]}, :var, [0.1, 2])

      for {type, initial, message} <- [
            {{:array, :int, []}, nil,
             "`a` is an array whose sizes are a list of one to three counts, as in " <>
               "{:array, :int, [4, 8]}, found []"},
            {{:array, :int, 8}, nil,
             "`a` is an array whose sizes are a list of one to three counts, as in " <>
               "{:array, :int, [4, 8]}, found 8"},
            {{:array, :int, [2, :x]}, nil,
             "`a` is an array whose sizes are a list of one to three counts, as in " <>
               "{:array, :int, [4, 8]}, found [2, :x]"},
            {{:array, :int, [1, 2, 3, 4]}, nil,
             "`a` is declared with 4 dimensions, `[1,2,3,4]`: an array has one to three, as " <>
               "in `int[8]`, `int[4,8]` or `int[2,3,4]`"},
            {{:array, :int, [0]}, nil,
             "`a` is declared with a dimension of 0, `[0]`: each dimension of an array holds " <>
               "1 element or more"},
            {{:array, :int, [65_537]}, nil,
             "`a` would hold 65537 elements, `[65537]`: an array holds 65536 at most"},
            {{:array, :ton, [2]}, nil,
             "`a` is an array whose elements are of an elementary type, as in " <>
               "{:array, :int, [8]}: logex has :bool, :sint, :int, :dint, :lint, :usint, " <>
               ":uint, :udint, :ulint, :real, :lreal, :byte, :word, :dword and :lword, " <>
               "found :ton"},
            {{:array, :int, [2]}, [1],
             "`a` is an array of 2 ints: its initial list holds 1 value, and an array's " <>
               "holds one for every element, 2, in the elements' order"},
            {{:array, :int, [2]}, 5,
             "`a` is an array of 2 ints: its initial value is a list of its elements' " <>
               "values, found 5"},
            {{:array, :int, [2]}, [1 | 2],
             "`a` is an array of 2 ints: its initial value is a list of its elements' " <>
               "values, found [1 | 2]"},
            {{:array, :int, [2]}, [1, 1.5],
             "the initial value of `a[1]` must be an integer, found 1.5"},
            {{:array, :sint, [2]}, [1, 128], "`a[1]` is an sint: `128` is outside -128 to 127"}
          ] do
        assert_raise ArgumentError, message, fn -> Tag.new!("a", type, :var, initial) end
      end
    end
  end

  describe "an element" do
    @types ~w(bool sint int dint lint usint uint udint ulint real lreal byte word dword lword)

    # Restated: a value of each type that is no zero, at the top of its range.
    defp top("bool"), do: 1
    defp top("sint"), do: 127
    defp top("int"), do: 32_767
    defp top("dint"), do: 2_147_483_647
    defp top("lint"), do: 9_223_372_036_854_775_807
    defp top("usint"), do: 255
    defp top("uint"), do: 65_535
    defp top("udint"), do: 4_294_967_295
    defp top("ulint"), do: 18_446_744_073_709_551_615
    defp top("real"), do: 1.5
    defp top("lreal"), do: 1.0e300
    defp top("byte"), do: 255
    defp top("word"), do: 65_535
    defp top("dword"), do: 4_294_967_295
    defp top("lword"), do: 18_446_744_073_709_551_615

    defp zero(type) when type in ~w(real lreal), do: 0.0
    defp zero(_type), do: 0

    test "of every elementary type is read and written as a tag of that type" do
      for type <- @types do
        program =
          compiled!(
            "var_input i #{type}\nvar_output o #{type}\nvar a #{type}[3]\nvar g #{type}[2,2]\n" <>
              "move i a[2]\nmove a[2] g[1,0]\nmove g[1,0] o"
          )

        state = Runtime.instance(program)
        {outputs, state} = scan(program, state, %{"i" => top(type)}, 0)
        assert outputs["o"] === top(type), type
        zero = zero(type)
        assert state.env["a"] === {zero, zero, top(type)}, type
        assert state.env["g"] === {{zero, zero}, {top(type), zero}}, type
      end
    end

    test "of two and three dimensions is the one its subscripts name, the rightmost fastest" do
      program =
        compiled!(
          "var g int[2,3] 1 2 3 4 5 6\nvar c int[2,2,2] 0 1 2 3 4 5 6 7\nvar_output o int[4]\n" <>
            "move g[0,2] o[0]\nmove g[1,0] o[1]\nmove c[1,0,1] o[2]\nmove c[0,1,0] o[3]"
        )

      {outputs, _} = scan(program, Runtime.instance(program), %{}, 0)
      # Restated: element [i, j] of a 2 by 3 array is value 3i + j of the list.
      assert outputs["o"] == [Enum.at(1..6, 0 * 3 + 2), Enum.at(1..6, 1 * 3 + 0), 5, 2]
    end

    test "is quoted as written and keyed by its subscripts' values" do
      program = compiled!("var w int[8] 0 1 2 3 4 5 6 7\nvar_output o int\nmove w[16#3] o")
      assert {%{"o" => 3}, _} = scan(program, Runtime.instance(program), %{}, 0)

      assert messages("var w int[8]\nvar x dint\nmove w[16#8] x") == [
               "line 3: `w[16#8]`'s subscript `16#8` is outside the elements of `w`, 0 to 7: " <>
                 "`w` is an array of 8 ints (declared on line 1)"
             ]
    end

    test "computes in its elements' type wherever a tag of it would" do
      program =
        compiled!(
          "var s sint[2] 127 0\nvar u usint[2]\nvar w word[2] 16#00ff 0\nvar r real[2]\n" <>
            "var_output q bool[3]\nvar_output i int[2]\nadd s[0] 1 s[1]\nsub u[0] 1 u[1]\n" <>
            "not w[0] w[1]\nadd r[0] 0.1 r[1]\ngt s[0] s[1] ote q[0]\neq r[1] 0.1 ote q[1]\n" <>
            "real_to_int r[1] i[0]\nsint_to_int s[1] i[1]\nxic q[0] xic q[1] ote q[2]"
        )

      {outputs, state} = scan(program, Runtime.instance(program), %{}, 0)
      # Restated: 127 + 1 wraps to -128 in 8 signed bits, 0 - 1 to 255 in 8 unsigned bits,
      # and `not` of 16#00ff in 16 bits is 16#ff00.
      assert state.env["s"] == {127, -128}
      assert state.env["u"] == {0, 255}
      assert state.env["w"] == {0x00FF, 0xFF00}
      assert state.env["r"] === {0.0, 0.10000000149011612}

      # An integer moved into an element of a `real` is the real it is.
      widened = compiled!("var_input x int\nvar r real[2]\nmove x r[1]")
      {_, state} = scan(widened, Runtime.instance(widened), %{"x" => 7}, 0)
      assert state.env["r"] === {0.0, 7.0}
      assert outputs["q"] == [1, 1, 1]
      assert outputs["i"] == [0, -128]
    end

    test "is refused where its subscripts name none, at its line" do
      for {source, message} <- [
            {"var weights int[8]\nvar x dint\nmove weights[8] x",
             "line 3: `weights[8]`'s subscript `8` is outside the elements of `weights`, 0 to " <>
               "7: `weights` is an array of 8 ints (declared on line 1)"},
            {"var w int[8]\nvar x dint\nmove w[-1] x",
             "line 3: `w[-1]`'s subscript `-1` is outside the elements of `w`, 0 to 7: `w` is " <>
               "an array of 8 ints (declared on line 1)"},
            {"var grid int[4,8]\nvar x dint\nmove grid[4,0] x",
             "line 3: `grid[4,0]`'s subscript `4` is outside the first dimension of `grid`, 0 " <>
               "to 3: `grid` is an array of 4 by 8 ints (declared on line 1)"},
            {"var grid int[4,8]\nvar x dint\nmove grid[0,8] x",
             "line 3: `grid[0,8]`'s subscript `8` is outside the second dimension of `grid`, 0 " <>
               "to 7: `grid` is an array of 4 by 8 ints (declared on line 1)"},
            {"var cube int[2,3,4]\nvar x dint\nmove cube[0,0,4] x",
             "line 3: `cube[0,0,4]`'s subscript `4` is outside the third dimension of `cube`, 0 " <>
               "to 3: `cube` is an array of 2 by 3 by 4 ints (declared on line 1)"},
            {"var grid int[4,8]\nvar x dint\nmove grid[1] x",
             "line 3: `grid[1]` names an element of `grid`, an array of 4 by 8 ints (declared " <>
               "on line 1), by 1 subscript, where it takes 2, one a dimension, as in `grid[0,0]`"},
            {"var w int[8]\nvar x dint\nmove w[1,1] x",
             "line 3: `w[1,1]` names an element of `w`, an array of 8 ints (declared on line " <>
               "1), by 2 subscripts, where it takes 1, one a dimension, as in `w[0]`"},
            {"var a dint\nvar x dint\nmove a[1] x",
             "line 3: `a[1]` names an element of `a`, but `a` is a dint (declared on line 1), " <>
               "no array"},
            {"var t ton\nvar x dint\nmove t[1] x",
             "line 3: `t[1]` names an element of `t`, but `t` is a ton (declared on line 1), " <>
               "no array"},
            # A subscript held in a tag waits for M5-12 (decision 152).
            {"var w int[8]\nvar slot dint\nvar x dint\nmove w[slot] x",
             "line 4: `w[slot]`'s subscript `slot` is a tag's name: an element's subscript is " <>
               "a literal number, as in `w[0]`, until a subscript held in a tag is supported"},
            {"var w int[8]\nvar x dint\nmove w x",
             "line 3: `move` reads one tag, but `w` is an array of 8 ints (declared on line 1): " <>
               "an instruction takes one of its elements, as in `w[0]`"},
            {"var g bool[2,2]\nxic g ote g[0,0]",
             "line 2: `xic` reads one tag, but `g` is an array of 2 by 2 bools (declared on line " <>
               "1): an instruction takes one of its elements, as in `g[0,0]`"},
            {"var w word[4]\nvar x bool\nxic w[1].3 ote x",
             "line 3: `w[1].3` goes past `w[1]`, an element of `w`, an array of 4 words " <>
               "(declared on line 1): an element is read and written whole, so move it into a " <>
               "tag of its own to reach its bits"},
            {"var_input w int[8]\nmove 1 w[2]",
             "line 2: `move` writes `w[2]`, a var_input (declared on line 1): logic must not " <>
               "write an input"},
            {"var w sint[2]\nvar x bool\nlt w[1] 200 ote x",
             "line 3: `lt` compares `200` with `w[1]`, an sint (declared on line 1), which never " <>
               "holds it: `200` is outside -128 to 127"},
            {"var w int[2]\nton w[0] 5",
             "line 2: `ton` runs a ton or ton_ltime, but `w[0]` is an int (declared on line 1)"},
            {"var w int[2]\nmove w[1] int[2]",
             "line 2: `int[2]` begins with `int`, a type, which cannot name a tag"}
          ] do
        assert messages(source) == [message], source
      end

      # An undeclared array is reported once, by its name, and a program that declares no
      # tags is told how to declare one.
      assert messages("move w[1] w[2]") == [
               "line 1: `w` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var w dint[8]`)"
             ]
    end

    test "fills a `cal`'s formal, which widens into it as a tag would, and never an array whole" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input s int\nvar_output q dint\nmove s q",
          name: "seal"
        )

      {:ok, program} =
        Logex.compile(
          "var a sint[2] 5 0\nvar out dint[2]\nvar s1 seal\ncal s1 a[0] out[1]",
          name: "p",
          types: [seal]
        )

      assert {%{}, %{env: %{"out" => {0, 5}}}} = scan(program, Runtime.instance(program), %{}, 0)

      assert {:error, [_count, %{message: message}]} =
               Logex.compile("var a int[8]\nvar s1 seal\ncal s1 a", name: "p", types: [seal])

      assert message ==
               "`cal` reads one tag, but `a` is an array of 8 ints (declared on line 1): an " <>
                 "instruction takes one of its elements, as in `a[0]`"
    end

    test "is a block's own `var`, never its var_input nor its var_output" do
      {:ok, shift} =
        Logex.compile(
          "function_block shift\nvar_input s bool\nvar_input v int\nvar_output q int\n" <>
            "var buf int[3] 1 2 3\nvar e bool[1]\n" <>
            "xic s ons e[0] move buf[1] buf[2] move buf[0] buf[1] move v buf[0]\nmove buf[2] q",
          name: "shift"
        )

      assert Logex.FbType.user?(shift)
      assert Logex.Compiler.lowered?(shift.body)

      {:ok, program} =
        Logex.compile(
          "var_input go bool\nvar_input val int\nvar_output out int\nvar sh shift\n" <>
            "cal sh go val out",
          name: "p",
          types: [shift]
        )

      state = Runtime.instance(program)
      assert state.env["sh"]["buf"] == {1, 2, 3}
      {%{"out" => 3}, state} = scan(program, state, %{"go" => 0, "val" => 5}, 0)
      {%{"out" => 2}, state} = scan(program, state, %{"go" => 1, "val" => 5}, 1)
      assert state.env["sh"]["buf"] == {5, 1, 2}

      for section <- ~w(var_input var_output) do
        assert {:error, [%{line: 2, message: message}]} =
                 Logex.compile("function_block fb\n#{section} x int[2]\nvar y bool\nxic y ote y",
                   name: "fb"
                 )

        assert message ==
                 "`x` cannot be an array #{section} of a function block: a `cal` fills each " <>
                   "var_input and var_output with one value, so an array is the block's own `var`"
      end

      assert_raise ArgumentError,
                   "`x` cannot be an array var_input of a function block: a `cal` fills each " <>
                     "var_input and var_output with one value, so an array is the block's own " <>
                     "`var`",
                   fn ->
                     {:ok, tokens, _} = Logex.Lexer.tokenize("function_block fb\nxic y ote y")
                     {:ok, ast} = Logex.Parser.parse(tokens)

                     Logex.Compiler.instructionize(ast, [
                       Tag.new!("x", {:array, :int, [2]}, :var_input),
                       Tag.new!("y", :bool)
                     ])
                   end
    end
  end

  describe "one-shots and pulse coils on elements (decision 154)" do
    test "an element of a bool array keeps a one-shot's storage bit, under every rule a bool does" do
      program =
        compiled!(
          "var_input a bool\nvar e bool[3]\nvar_output p bool[2]\nxic a ons e[1] ote p[0]\n" <>
            "xic a osr e[2] p[1]"
        )

      state = Runtime.instance(program)
      {%{"p" => [0, 0]}, state} = scan(program, state, %{"a" => 1}, 0)
      {%{"p" => [0, 0]}, state} = scan(program, state, %{"a" => 0}, 1)
      {%{"p" => [1, 1]}, state} = scan(program, state, %{"a" => 1}, 2)
      {%{"p" => [0, 0]}, _} = scan(program, state, %{"a" => 1}, 3)

      assert messages(
               "var e bool[3]\nvar a bool\nvar p bool[2]\nxic a ons e[1]\nxic a ons e[1]\n" <>
                 "xic a osr e[2] e[2]"
             ) == [
               "line 5: `e[1]` is already the storage bit of the `ons` on line 4: each `ons` " <>
                 "needs a storage bit of its own",
               "line 6: `e[2]` is both the storage bit and the pulse bit of this `osr`: its " <>
                 "pulse bit is another tag, which it sets for one scan on an edge"
             ]

      # One keyed by its subscripts' values, `e[01]` the very `e[1]`.
      assert messages("var e bool[3]\nvar a bool\nxic a ons e[1]\nxic a osf e[01] a") == [
               "line 4: `e[01]` is already the storage bit of the `ons` on line 3: each `ons`, " <>
                 "`osr` or `osf` needs a storage bit of its own"
             ]
    end

    # PLAN M5-11's Done-when: an edit of a rung with `ons edge[2]` blocks it once.
    test "an edit of a rung with `ons edge[2]` blocks it once" do
      original =
        compiled!(
          "var_input go bool\nvar edge bool[4]\nvar_output lamp bool\nxic go ons edge[2] ote lamp"
        )

      candidate =
        compiled!(
          "var_input go bool\nvar_input ok bool\nvar edge bool[4]\nvar_output lamp bool\n" <>
            "xic go xic ok ons edge[2] ote lamp"
        )

      state = Runtime.instance(original)
      {_, state} = scan(original, state, %{"go" => 1}, 0)
      # The forecast gives the storage bit's value, 1 while `go` is held.
      {:ok, _edit, forecast} = Edit.accept(original, candidate, state)
      assert {:ons_blocked, "edge[2]", 1} in forecast
      {_, state} = scan(original, state, %{"go" => 0}, 1)
      {:ok, edit, forecast} = Edit.accept(original, candidate, state)
      assert {:ons_blocked, "edge[2]", 0} in forecast
      {edit, state, report} = Edit.test(edit, state)
      assert {:ons_blocked, "edge[2]", 0} in report
      assert state.ons_blocked == ["edge[2]"]
      program = Edit.running(edit)
      # The press that comes with the switch fires nothing, the next one does.
      {%{"lamp" => 0}, state} = scan(program, state, %{"go" => 1, "ok" => 1}, 4)
      assert state.ons_blocked == []
      {%{"lamp" => 0}, state} = scan(program, state, %{"go" => 0}, 5)
      {%{"lamp" => 1}, _} = scan(program, state, %{"go" => 1}, 6)

      # A rung that only respells a subscript is the same rung, and blocks nothing.
      respelled =
        compiled!(
          "var_input go bool\nvar edge bool[4]\nvar_output lamp bool\nxic go ons edge[16#2] ote lamp"
        )

      {:ok, _edit, forecast} = Edit.accept(original, respelled, state)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))
    end

    test "a rung a jump skips keeps an element's storage bit blocked until its one-shot runs" do
      original =
        compiled!("var_input go bool\nvar e bool[2]\nvar_output q bool\nxic go ons e[1] ote q")

      candidate =
        compiled!(
          "var_input go bool\nvar_input skip bool\nvar e bool[2]\nvar_output q bool\n" <>
            "xic skip jmp over\nxic go xio skip ons e[1] ote q\nlbl over"
        )

      state = Runtime.instance(original)
      {_, state} = scan(original, state, %{"go" => 1}, 0)
      {:ok, edit, _} = Edit.accept(original, candidate, state)
      {edit, state, _} = Edit.test(edit, state)
      program = Edit.running(edit)
      {_, state} = scan(program, state, %{"skip" => 1}, 1)
      assert state.ons_blocked == ["e[1]"]
      {_, state} = scan(program, state, %{"skip" => 0}, 2)
      assert state.ons_blocked == []
    end
  end

  describe "the warnings" do
    test "a var_output array no rung writes stays at its initial values, or at 0" do
      assert warnings(
               "var_output w int[2] 5 6\nvar_output v int[2]\nvar x int\nmove w[0] x\nmove v[1] x"
             ) == [
               "line 1: warning: `w` is a var_output, but no rung writes it: it stays at its initial values",
               "line 2: warning: `v` is a var_output, but no rung writes it: it stays at 0"
             ]
    end

    test "name an element by its name, its array by its own" do
      assert warnings(
               "var l bool[3]\nvar a bool\nxic a ote l[1]\nxic a ote l[01]\nxic a ote l[2]"
             ) ==
               [
                 "line 4: warning: `l[01]` already has an `ote` on line 3: the last one in the " <>
                   "scan decides it"
               ]

      assert warnings("var e bool[3]\nvar a bool\nxic a ons e[1]\nxic a ote e[1]") == [
               "line 4: warning: `ote` writes `e[1]`, the storage bit of the `ons` on line 3: " <>
                 "the one-shot then fires on the wrong scans"
             ]

      assert warnings("var u int[2]\nvar a bool\nxic a ote a") == [
               "line 1: warning: `u` is declared but no rung uses it"
             ]

      assert warnings("var_output o int[2] \nvar_input a int\nvar x int\nmove o[0] x\nmove a x") ==
               [
                 "line 1: warning: `o` is a var_output, but no rung writes it: it stays at 0"
               ]

      assert warnings("var u usint[2]\nvar a bool\nge u[1] 0 ote a") == [
               "line 3: warning: `ge` compares `u[1]` with `0`, and a usint holds nothing below " <>
                 "`0`: its result never changes"
             ]

      assert warnings("var r real[2]\nmove 16777217.0 r[1]\nmove r[1] r[0]") == [
               "line 2: warning: `16777217.0` is more precise than a real keeps: it is held as " <>
                 "16777216.0"
             ]
    end
  end

  describe "the host contract" do
    setup do
      program =
        compiled!(
          "var_input w int[2,3]\nvar_input r real[2]\nvar_output o int[3]\nvar_output s real\n" <>
            "move w[1,2] o[0]\nmove w[0,0] o[2]\nmove r[1] s"
        )

      {:ok, program: program}
    end

    test "an array var_input is a list of the declared shape, an output a list", %{program: p} do
      state = Runtime.put_inputs(p, Runtime.instance(p), %{"w" => [[1, 2, 3], [4, 5, 6]]})
      assert state.env["w"] == {{1, 2, 3}, {4, 5, 6}}
      {outputs, state} = Runtime.scan(p, state)
      assert outputs == %{"o" => [6, 0, 1], "s" => 0.0}
      # A real's element is held at its nearest single, an integer's as the real it is.
      {outputs, _} = scan(p, state, %{"r" => [7, 0.1]}, 1)
      assert outputs["s"] === 0.10000000149011612
      # A restart keeps an array var_input whose value fits, as any var_input's.
      assert Runtime.restart(p, state, :cold).env["w"] == {{1, 2, 3}, {4, 5, 6}}
    end

    test "a host's array of another shape, or an element, is refused, a line each", %{program: p} do
      state = Runtime.instance(p)

      for {inputs, message} <- [
            {%{"w" => [[1, 2, 3]]},
             "input `w` is an array of 2 by 3 ints: its value must be a list of 2 lists of 3 " <>
               "elements, found [[1, 2, 3]]"},
            {%{"w" => [[1, 2], [3, 4]]},
             "input `w` is an array of 2 by 3 ints: its value must be a list of 2 lists of 3 " <>
               "elements, found [[1, 2], [3, 4]]"},
            {%{"w" => {{1, 2, 3}, {4, 5, 6}}},
             "input `w` is an array of 2 by 3 ints: its value must be a list of 2 lists of 3 " <>
               "elements, found {{1, 2, 3}, {4, 5, 6}}"},
            {%{"w" => [1, 2, 3, 4, 5, 6]},
             "input `w` is an array of 2 by 3 ints: its value must be a list of 2 lists of 3 " <>
               "elements, found [1, 2, 3, 4, 5, 6]"},
            {%{"w" => [[1, 2, 3], [4, 70_000, 6.5]]},
             "input `w[1,1]` is an int: 70000 is outside -32768 to 32767\n" <>
               "input `w[1,2]` is an int: its value must be an integer, found 6.5"},
            {%{"r" => [0.0, 1.0e40]},
             "input `r[1]` is a real: 1.0e40 is beyond a real's range, " <>
               "-3.4028234663852886e38 to 3.4028234663852886e38"},
            {%{"w[1,2]" => 5},
             "input \"w[1,2]\" names an element of `w`, an array of 2 by 3 ints: a host sets " <>
               "an array var_input whole, as a list of 2 lists of 3 elements"}
          ] do
        assert_raise ArgumentError, message, fn -> Runtime.put_inputs(p, state, inputs) end
      end
    end

    test "a state's array is a tuple of its shape, every element of its type", %{program: p} do
      %{env: env} = state = Runtime.instance(p)

      for {broken, message} <- [
            {Map.delete(env, "w"),
             "state.env lacks `w`: it is an array of 2 by 3 ints, which a state holds whole, " <>
               "as `Logex.Runtime.instance/1` makes it"},
            {Map.put(env, "w", [[0, 0, 0], [0, 0, 0]]),
             "state.env holds `w` outside its type: it is an array of 2 by 3 ints, and its " <>
               "value must be a tuple of 2 tuples of 3 elements, found [[0, 0, 0], [0, 0, 0]]"},
            {Map.put(env, "w", {{0, 0, 0}, {0, 0}}),
             "state.env holds `w` outside its type: it is an array of 2 by 3 ints, and its " <>
               "value must be a tuple of 2 tuples of 3 elements, found {{0, 0, 0}, {0, 0}}"},
            {Map.put(env, "w", {{0, 0, 40_000}, {0, nil, 0}}),
             "state.env holds `w[0,2]` outside its type: it is an int, and 40000 is outside " <>
               "-32768 to 32767\n" <>
               "state.env holds `w[1,1]` outside its type: it is an int, and its value must be " <>
               "an integer, found nil"},
            {Map.put(env, "r", {0.1, 0}),
             "state.env holds `r[0]` outside its type: it is a real, and 0.1 is no value of a " <>
               "real, whose nearest is 0.10000000149011612\n" <>
               "state.env holds `r[1]` outside its type: it is a real, and its value must be a " <>
               "float, found 0"}
          ] do
        assert_raise ArgumentError, message, fn -> Runtime.scan(p, %{state | env: broken}) end
      end
    end
  end

  describe "a real array's input" do
    test "each element a host gives is stored as its real's nearest value, an integer too" do
      program =
        compiled!("var_input hz real[2]\nvar_input big lreal[1]\nvar_output s real\nmove hz[0] s")

      <<single::float-32>> = <<0.1::float-32>>

      state =
        Runtime.put_inputs(program, Runtime.instance(program), %{"hz" => [0.1, 3], "big" => [7]})

      # Compared exactly: a real holds a float, never an integer, so `3` is held as 3.0.
      assert state.env["hz"] === {single, 3.0}
      assert state.env["big"] === {7.0}
    end
  end

  describe "an online edit (decision 157)" do
    defp accepted(original, candidate) do
      original = compiled!(original)
      Edit.accept(original, compiled!(candidate), Runtime.instance(original))
    end

    test "an array's type, its dimensions or its sizes change only with a restart" do
      for {was, now, words} <- [
            {"int[8]", "int[10]",
             "an array of 8 ints in the running program and an array of 10 ints"},
            {"int[8]", "dint[8]",
             "an array of 8 ints in the running program and an array of 8 dints"},
            {"int[2,4]", "int[8]",
             "an array of 2 by 4 ints in the running program and an array of 8 ints"},
            {"int[8]", "int", "an array of 8 ints in the running program and an int"},
            {"int", "int[8]", "an int in the running program and an array of 8 ints"}
          ] do
        assert {:error, [%{line: 1, message: message}]} =
                 accepted(
                   "var temps #{was}\nvar a bool\nxic a ote a",
                   "var temps #{now}\nvar a bool\nxic a ote a"
                 )

        assert message ==
                 "`temps` is #{words} in the candidate: a tag's type changes only with a restart"
      end
    end

    test "a changed initial list is reported element by element, the running values kept" do
      original =
        compiled!(
          "var lim int[3] 10 20 30\nvar g bool[2,2]\nvar a bool\nmove lim[0] lim[1]\nxic g[0,0] ote a"
        )

      candidate =
        compiled!(
          "var lim int[3] 10 25 31\nvar g bool[2,2] 0 0 1 0\nvar a bool\nmove lim[0] lim[1]\nxic g[0,0] ote a"
        )

      state = Runtime.instance(original)
      {_, state} = scan(original, state, %{}, 0)
      {:ok, edit, forecast} = Edit.accept(original, candidate, state)

      assert forecast == [
               {:initial_changed, "g[1,0]", {0, 1}},
               {:initial_changed, "lim[1]", {20, 25}},
               {:initial_changed, "lim[2]", {30, 31}}
             ]

      {_edit, state, _report} = Edit.test(edit, state)
      assert state.env["lim"] == {10, 10, 30}
      assert state.env["g"] == {{0, 0}, {0, 0}}
    end

    test "an array added starts, and a var_input array is reported to the host as a list" do
      original = compiled!("var_input go bool\nvar_output q bool\nxic go ote q")

      candidate =
        compiled!(
          "var_input go bool\nvar_input w int[2]\nvar_output q bool\nvar buf dint[2] 4 5\n" <>
            "xic go ote q\nmove w[1] buf[0]"
        )

      state = Runtime.instance(original)
      {:ok, edit, _} = Edit.accept(original, candidate, state)
      {_edit, state, report} = Edit.test(edit, state)
      assert {:added, "buf", [4, 5]} in report
      assert {:input, "w", [0, 0]} in report
      assert state.env["buf"] == {4, 5}
    end
  end

  describe "the walk, and a program edited by hand" do
    test "an element is a use and a write of its array, and named by its subscripts' values" do
      program =
        compiled!(
          "var_input a bool\nvar e bool[3]\nvar w int[2]\nvar_output l bool[2]\n" <>
            "xic a ons e[1] ote l[0]\nmove 5 w[01]\nadd w[0] 1 w[1]"
        )

      assert Logex.Walk.uses(program.rungs, Logex.Program.typed_tags(program)) == [
               {:read, "a", 5, :xic},
               {:write, "e", 5, :ons},
               {:write, "l", 5, :ote},
               {:write, "w", 6, :move},
               {:value, "w", 7, :add},
               {:write, "w", 7, :add}
             ]

      assert Logex.Walk.writes(program) == %{"e" => [5], "l" => [5], "w" => [6, 7]}
      assert Logex.Walk.bit_writes(program) == %{"e[1]" => [5], "l[0]" => [5], "w[1]" => [6, 7]}
      assert Logex.Walk.storage_bits(program.rungs) == [{"e[1]", 5, :ons}]
      assert Logex.Walk.one_shots(program) == %{"e[1]" => {5, :ons}}
    end

    test "a program whose arrays its tags do not give is refused where it is handed in" do
      program = compiled!("var w int[2]\nvar x int\nadd w[0] 1 w[1]\nmove w[1] x")

      assert_raise ArgumentError,
                   "`p`'s arrays give `w` no array type, where it is an array of 2 ints: `p` " <>
                     "was edited by hand after it compiled",
                   fn -> Runtime.instance(%{program | arrays: nil}) end

      retyped = %{program | tags: Map.put(program.tags, "w", %{program.tags["w"] | type: :int})}

      assert_raise ArgumentError,
                   "`p`'s arrays give `w` an array of 2 ints, where it is an int: `p` was " <>
                     "edited by hand after it compiled\n" <>
                     "`p`'s `add` on line 3 computes in the type of `w[1]`, whose array is an " <>
                     "int, no array: `p` was edited by hand after it compiled",
                   fn -> Runtime.instance(retyped) end

      # One swapped in after its check is trusted, and a scan that reaches such a
      # destination raises there (decision 194).
      state = Runtime.instance(program)

      assert_raise ArgumentError,
                   "a scan's `add` on line 3 computes in the type of `w[1]`, whose array is an " <>
                     "int, no array: the program was edited by hand after it was handed in and " <>
                     "checked",
                   fn ->
                     Runtime.call(
                       %{retyped | arrays: nil},
                       %{state | env: %{state.env | "w" => 0}},
                       %{},
                       %Scan{now: 0, first: true}
                     )
                   end
    end

    test "a block's own array is moved by an edit by its path, its initial list compared element by element" do
      block = fn initial ->
        {:ok, shift} =
          Logex.compile(
            "function_block shift\nvar_input s bool\nvar_output q int\nvar buf int[3] #{initial}\n" <>
              "xic s move buf[1] q",
            name: "shift"
          )

        shift
      end

      program = fn shift ->
        {:ok, program} =
          Logex.compile(
            "var_input go bool\nvar_output out int\nvar sh shift\ncal sh go out",
            name: "p",
            types: [shift]
          )

        program
      end

      original = program.(block.("1 2 3"))
      state = Runtime.instance(original)
      {:ok, edit, forecast} = Edit.accept(original, program.(block.("1 9 3")), state)
      assert forecast == [{:initial_changed, "sh.buf[1]", {2, 9}}]
      {_edit, state, _report} = Edit.test(edit, state)
      assert state.env["sh"]["buf"] == {1, 2, 3}
    end
  end

  # PLAN M5-11's Done-when: `weights[3]` and `grid[1,7]` run in a program from source
  # against an oracle that knows nothing of logex. A shift register of eight weights, a new
  # weight shifted in on each rising edge of `load`, and a grid of totals, `w` added into
  # `grid[1,7]` on every scan `en` holds, the oracle a list and a map in Elixir.
  describe "against an oracle" do
    @source """
    var_input load bool
    var_input en bool
    var_input w int
    var_output third int
    var_output total dint
    var_output corner dint
    var weights int[8]
    var grid dint[2,8]
    var edge bool[1]
    xic load ons edge[0] move weights[6] weights[7] move weights[5] weights[6] move weights[4] weights[5] move weights[3] weights[4] move weights[2] weights[3] move weights[1] weights[2] move weights[0] weights[1] move w weights[0]
    xic en add grid[1,7] w grid[1,7]
    xic en add grid[0,0] 1 grid[0,0]
    move weights[3] third
    move grid[1,7] total
    move grid[0,0] corner
    """

    test "a seeded run of presses and weights" do
      program = compiled!(@source)
      :rand.seed(:exsss, {11, 5, 1})

      {_, _} =
        Enum.reduce(0..400, {Runtime.instance(program), {List.duplicate(0, 8), 0, 0, 0, true}}, fn
          now, {state, oracle} ->
            inputs = %{
              "load" => :rand.uniform(2) - 1,
              "en" => :rand.uniform(2) - 1,
              "w" => :rand.uniform(2000) - 1000
            }

            {outputs, state} = scan(program, state, inputs, now)
            {expected, oracle} = step(oracle, inputs)
            assert outputs == expected, "scan #{now}"
            {state, oracle}
        end)
    end

    # The oracle: a one-shot that passes no power on the first scan, then on a rising edge.
    defp step({weights, last, total, corner, first}, %{"load" => load, "en" => en, "w" => w}) do
      weights = shifted(not first and load == 1 and last == 0, weights, w)
      {total, corner} = added(en, {total, corner}, w)

      {%{"third" => Enum.at(weights, 3), "total" => total, "corner" => corner},
       {weights, load, total, corner, false}}
    end

    defp shifted(true, weights, w), do: [w | Enum.take(weights, 7)]
    defp shifted(false, weights, _w), do: weights

    defp added(1, {total, corner}, w), do: {total + w, corner + 1}
    defp added(0, sums, _w), do: sums
  end

  describe "M5-11's review" do
    # Each a crash outside the public API before the review, now a pinned diagnostic.
    test "a dotted name with a subscript is a diagnostic at its line, never a raise" do
      {:ok, block} =
        Logex.compile(
          "function_block k\nvar_input x bool\nvar e bool[3]\nvar_output q bool\n" <>
            "xic x ote e[1]\nxic e[1] ote q",
          name: "k"
        )

      block_messages = fn source ->
        {:error, diagnostics} = Logex.compile(source, name: "p", types: [block])
        Enum.map(diagnostics, &Logex.Diagnostic.format/1)
      end

      assert messages("var t ton\nvar x dint\nmove t.acc[0] x") ==
               ["line 3: `t.acc[0]` is not a member of `t`, a ton — did you mean `t.acc`?"]

      assert messages("var t ton\nvar x bool\nxic t.dn[0] ote x") == [
               "line 3: `t.dn[0]` is not a member of `t`, a ton: its members are `pre`, " <>
                 "`acc`, `dn`, `tt` and `en`"
             ]

      assert messages("var x dint\nmove x.y[0] x") == [
               "line 2: `x.y[0]` names a member of `x`, but `x` is a dint (declared on line 1): " <>
                 "only an instance of a function block has members"
             ]

      assert messages("var x dint\nmove y.z[0] x") == ["line 2: `y` is not declared"]

      assert messages("var a int[2]\nvar x int\nmove 1 a.b[0]\nmove a[0] x") == [
               "line 3: `a.b[0]` names a member of `a`, but `a` is an array of 2 ints " <>
                 "(declared on line 1): only an instance of a function block has members"
             ]

      assert messages("var w word\nvar n int\nvar q bool\nxic w.n[0] ote q\nmove n n") == [
               "line 4: `w.n[0]` names a member of `w`, but `w` is a word (declared on line 1): " <>
                 "only an instance of a function block has members"
             ]

      # A block's own array is no member a program reaches, nor is a bool output an array.
      assert block_messages.("var i bool\nvar s k\nvar o bool\ncal s i o\nxic s.e[1] ote o") ==
               [
                 "line 5: `s.e[1]` is not a member of `s`, an instance of `k`: its members are " <>
                   "`x` and `q`"
               ]

      assert block_messages.("var i bool\nvar s k\nvar o bool\ncal s i o\nxic s.q[0] ote o") ==
               [
                 "line 5: `s.q[0]` is not a member of `s`, an instance of `k`: its members are " <>
                   "`x` and `q`"
               ]
    end

    test "an array named whole where an instance or one tag goes is a diagnostic" do
      assert messages("var e int[8]\ncal e") == [
               "line 2: `cal` runs an instance of a function block, but `e` is an array of 8 " <>
                 "ints (declared on line 1)"
             ]

      assert messages("var e bool[2]\nvar x bool\ncal e x") == [
               "line 3: `cal` runs an instance of a function block, but `e` is an array of 2 " <>
                 "bools (declared on line 1)"
             ]

      # A literal written into an array whole is told so, as a tag is, and never judged
      # as a value of the array's type.
      for {source, written} <- [
            {"var w bool[2]\nmove 1 w", "an array of 2 bools"},
            {"var w real[2]\nmove 1.5 w", "an array of 2 reals"},
            {"var w lint[2]\nmove 16#ff w", "an array of 2 lints"},
            {"var w int[2]\nadd 1 2 w", "an array of 2 ints"}
          ] do
        word = source |> String.split("\n") |> List.last() |> String.split(" ") |> hd()

        assert messages(source) == [
                 "line 2: `#{word}` writes one tag, but `w` is #{written} (declared on line 1): " <>
                   "an instruction takes one of its elements, as in `w[0]`"
               ],
               source
      end
    end

    test "a label is a name with no subscript" do
      assert messages("var a int[2]\nvar x int\njmp a[0]\nlbl a[0]\nmove x x") == [
               "line 3: `jmp` takes a label, a name with no subscript, found `a[0]`",
               "line 4: `lbl` takes a label, a name with no subscript, found `a[0]`"
             ]

      assert messages("var x int\njmp done[1]\nmove x x\nlbl done[1]\nmove x x") == [
               "line 2: `jmp` takes a label, a name with no subscript, found `done[1]`",
               "line 4: `lbl` takes a label, a name with no subscript, found `done[1]`"
             ]
    end

    test "sizes from Elixir that are no proper list of counts are refused" do
      for dims <- [[2 | 3], [2, 3 | 4], [2 | :x]] do
        assert_raise ArgumentError,
                     "`a` is an array whose sizes are a list of one to three counts, as in " <>
                       "{:array, :int, [4, 8]}, found #{inspect(dims)}",
                     fn -> Tag.new!("a", {:array, :int, dims}, :var, nil) end
      end
    end

    test "a host's list is shown as a list, never as a charlist" do
      p =
        compiled!(
          "var_input w int[3]\nvar_input g int[2,3]\nvar x int\nmove w[1] x\nmove g[0,0] x"
        )

      state = Runtime.instance(p)

      assert_raise ArgumentError,
                   "input `w` is an array of 3 ints: its value must be a list of 3 elements, " <>
                     "found [72, 105]",
                   fn -> Runtime.put_inputs(p, state, %{"w" => [72, 105]}) end

      assert_raise ArgumentError,
                   "input `g` is an array of 2 by 3 ints: its value must be a list of 2 lists " <>
                     "of 3 elements, found [[7, 8, 9]]",
                   fn -> Runtime.put_inputs(p, state, %{"g" => [[7, 8, 9]]}) end

      assert_raise ArgumentError,
                   "input `w[0]` is an int: its value must be an integer, found [72, 105]",
                   fn -> Runtime.put_inputs(p, state, %{"w" => [[72, 105], 1, 2]}) end

      assert_raise ArgumentError,
                   "state.env holds `w` outside its type: it is an array of 3 ints, and its " <>
                     "value must be a tuple of 3 elements, found [7, 8, 9]",
                   fn -> Runtime.scan(p, %{state | env: Map.put(state.env, "w", [7, 8, 9])}) end
    end

    test "a host's list or a state's tuple with an extra row, or of one element, is refused" do
      p =
        compiled!(
          "var_input g int[2,3]\nvar_input o int[1]\nvar x int\nmove g[0,0] x\nmove o[0] x"
        )

      state = Runtime.instance(p)

      assert_raise ArgumentError,
                   "input `g` is an array of 2 by 3 ints: its value must be a list of 2 lists " <>
                     "of 3 elements, found [[1, 2, 3], [4, 5, 6], [7, 8, 9]]",
                   fn ->
                     Runtime.put_inputs(p, state, %{"g" => [[1, 2, 3], [4, 5, 6], [7, 8, 9]]})
                   end

      assert_raise ArgumentError,
                   "input `o` is an array of 1 int: its value must be a list of 1 element, " <>
                     "found [1, 2]",
                   fn -> Runtime.put_inputs(p, state, %{"o" => [1, 2]}) end

      assert_raise ArgumentError,
                   "state.env holds `g` outside its type: it is an array of 2 by 3 ints, and " <>
                     "its value must be a tuple of 2 tuples of 3 elements, found " <>
                     "{{1, 2, 3}, {4, 5, 6}, {7, 8, 9}}",
                   fn ->
                     Runtime.scan(p, %{
                       state
                       | env: Map.put(state.env, "g", {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}})
                     })
                   end

      assert_raise ArgumentError,
                   "state.env holds `o` outside its type: it is an array of 1 int, and its " <>
                     "value must be a tuple of 1 element, found {0, 0}",
                   fn -> Runtime.scan(p, %{state | env: Map.put(state.env, "o", {0, 0})}) end
    end

    test "an array's elements outside their type are listed to ten, the rest counted" do
      p = compiled!("var_input w sint[12]\nvar x int\nmove w[0] x")
      state = Runtime.instance(p)
      named = for i <- 0..9, do: "w[#{i}]"

      assert_raise ArgumentError,
                   Enum.map_join(
                     named,
                     "\n",
                     &"input `#{&1}` is an sint: 500 is outside -128 to 127"
                   ) <>
                     "\ninput `w` is an array of 12 sints, with 2 more elements outside its " <>
                     "type, not listed",
                   fn -> Runtime.put_inputs(p, state, %{"w" => List.duplicate(500, 12)}) end

      # Ten and no more are each listed, with no count.
      assert_raise ArgumentError,
                   Enum.map_join(
                     named,
                     "\n",
                     &"input `#{&1}` is an sint: 500 is outside -128 to 127"
                   ),
                   fn ->
                     Runtime.put_inputs(p, state, %{"w" => List.duplicate(500, 10) ++ [0, 0]})
                   end

      assert_raise ArgumentError,
                   Enum.map_join(
                     named,
                     "\n",
                     &"state.env holds `#{&1}` outside its type: it is an sint, and 500 is outside -128 to 127"
                   ) <>
                     "\nstate.env holds `w`, an array of 12 sints, with 1 more element outside " <>
                     "its type, not listed",
                   fn ->
                     env = Map.put(state.env, "w", List.to_tuple(List.duplicate(500, 11) ++ [0]))
                     Runtime.scan(p, %{state | env: env})
                   end

      initial = "var a sint[12] " <> Enum.join(List.duplicate("900", 12), " ")

      assert messages(initial <> "\nvar x int\nmove a[0] x") ==
               Enum.map(0..9, &"line 1: `a[#{&1}]` is an sint: `900` is outside -128 to 127") ++
                 [
                   "line 1: `a` is an array of 12 sints: its initial list holds 2 more values " <>
                     "outside its type, not listed"
                 ]
    end
  end

  describe "growth, in reductions" do
    # Counted in a process of its own with a heap the collector never visits, so each count
    # is the same on every run: a scan's reductions for each rung, the difference of 200
    # rungs and 100 over 100.
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

    # PLAN M5-11's Done-when: an element's read and write stay within a measured bound of a
    # tag's. Measured: `move a[3] d` 16 reductions a rung against `move a d`'s 17, a read of
    # an element one `elem/2` of its array where a tag's read takes its default through
    # `Map.get/3`; `move d a[3]` 17, one `put_elem/3`; of a two-dimensional array 18 and 22,
    # and a write into a three-dimensional one 25, a dimension's tuple copied each; and
    # `xic a[3] ote q[4]` 23 against two bools' 24.
    test "an element's read and write cost a bounded few reductions more than a tag's" do
      tag = per_rung("var a int\nvar d int\n", "move a d")
      read = per_rung("var a int[8]\nvar d int\n", "move a[3] d")
      write = per_rung("var a int[8]\nvar d int\n", "move d a[3]")
      read2 = per_rung("var a int[4,8]\nvar d int\n", "move a[1,7] d")
      write2 = per_rung("var a int[4,8]\nvar d int\n", "move d a[1,7]")
      write3 = per_rung("var a int[2,2,2]\nvar d int\n", "move d a[1,1,1]")
      contact = per_rung("var a bool\nvar q bool\n", "xic a ote q")
      contact1 = per_rung("var a bool[8]\nvar q bool[8]\n", "xic a[3] ote q[4]")

      assert read <= tag, "an element's read took #{read} a rung, a tag's #{tag}"
      assert write <= tag + 1, "an element's write took #{write} a rung, a tag's #{tag}"
      assert read2 <= tag + 2, "a 2-D element's read took #{read2} a rung, a tag's #{tag}"
      assert write2 <= tag + 6, "a 2-D element's write took #{write2} a rung, a tag's #{tag}"
      assert write3 <= tag + 9, "a 3-D element's write took #{write3} a rung, a tag's #{tag}"
      assert contact1 <= contact, "elements took #{contact1} a rung, bools #{contact}"
    end

    # M5-11's review: `instance/1` settles a program's tags once for its units, reals and
    # arrays, where it settled them once for each, and compares nothing where a routine
    # holds none: beyond the instance's first env, its check costs less than one more walk.
    test "instance/1 walks a program's tags once to check its units, reals and arrays" do
      {:ok, p} =
        Logex.compile(
          Enum.map_join(1..200, "\n", &"var t#{&1} dint") <> "\nvar x bool\nxic x ote x",
          name: "p"
        )

      cost = fn f ->
        parent = self()

        {_pid, ref} =
          :erlang.spawn_opt(
            fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              f.()
              {:reductions, later} = Process.info(self(), :reductions)
              send(parent, {:reductions, later - before})
            end,
            [:monitor, min_heap_size: 8_000_000]
          )

        assert_receive {:reductions, r}, 10_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
        r
      end

      instance = cost.(fn -> Runtime.instance(p) end)
      env = cost.(fn -> Logex.Program.initial_env(p) end)
      walk = cost.(fn -> Logex.Program.settled(p.tags) end)

      assert instance - env < 1.5 * walk,
             "instance/1 took #{instance}, env #{env}, a walk #{walk}"
    end

    # A program of no arrays scans, rung for rung, in exactly what it took at f43d82a,
    # before M5-11: an element is told from a tag by its operand's shape in the clause head.
    test "a program of none scans as it did before M5-11" do
      assert per_rung("var a bool\nvar b bool\nvar q bool\n", "xic a xio b ote q") == 29.0
      assert per_rung("var a uint\nvar d dint\n", "move a d") == 17.0
      assert per_rung("var w word\nvar q bool\n", "xic w.3 ote q") == 27.0
      assert per_rung("var a int\nvar b int\nvar d int\n", "add a b d") == 34.0
      assert per_rung("var a word\nvar d word\n", "not a d") == 32.0
    end

    test "an array's state check is linear in its elements, and its compile in its uses" do
      check = fn n ->
        {:ok, p} = Logex.compile("var a int[#{n}]\nvar d int\nmove a[0] d", name: "p")
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

      assert check.(16_000) / check.(8_000) < 2.1

      # M5-11's review: each element of an integer array costs about one reduction a scan,
      # one guard with no function called, where it cost fourteen, every element checked
      # twice through a function; a real's about eight.
      per_element = (check.(16_000) - check.(8_000)) / 8_000
      assert per_element < 1.5, "an int element's check took #{per_element} reductions"

      real = fn n ->
        {:ok, p} = Logex.compile("var a real[#{n}]\nvar d real\nmove a[0] d", name: "p")
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

      per_real = (real.(16_000) - real.(8_000)) / 8_000
      assert per_real < 12, "a real element's check took #{per_real} reductions"

      compile = fn n ->
        text =
          "var a int[64]\nvar d int\n" <> Enum.map_join(1..n, "\n", &"move a[#{rem(&1, 64)}] d")

        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, _} = Logex.compile(text, name: "p")
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end

      _warm = compile.(10)
      assert compile.(400) / compile.(200) < 2.3
    end
  end
end
