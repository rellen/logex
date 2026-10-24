defmodule Logex.TagSubscriptTest do
  @moduledoc """
  PLAN M5-12: a subscript held in a tag, `weights[slot]` or `grid[1,c]` (`docs/organisation.md`
  §4.12, decision 152), and the index fault, a subscript outside its dimension when an
  instruction reads or writes the element, a major fault (decision 153, on M5-9's path,
  decision 160's), every rule from source through `Logex.compile/2`, `Logex.Runtime.call/4`
  and `Logex.Edit`: a subscript tag of any integer width, beside literal subscripts, on
  arrays of one to three dimensions, a bit of such an element among them; the refusals at
  their lines; each instruction that may hold such an element doing nothing on a subscript
  out of range, passing no power, the scan running on, its major fault in `state.faults`
  with every subscript read; a de-energised instruction that reads and writes nothing, a
  rung a jump skips and a block whose `cal` is false checking nothing (decision 82); the
  warnings, an edit's rung and a configuration's writers; and the cost in reductions
  against a literal subscript's, with a program of none scanning as it did before M5-12.

  The elements' order, the rightmost subscript fastest, is restated here from Logix's text
  (1756-PM004L p.35), never read from `Logex.Array`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Edit, Fault, Runtime, Scan, Walk}

  @indexes [:sint, :int, :dint, :lint, :usint, :uint, :udint, :ulint]

  defp program(source, types \\ [], name \\ "p") do
    {:ok, program} = Logex.compile(source, name: name, types: types)
    program
  end

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "p", types: types)
    Enum.map(diagnostics, &{&1.line, &1.message})
  end

  defp warnings(source), do: Enum.map(program(source).warnings, &{&1.line, &1.message})

  # One scan through call/4, from a new instance or the state given: the outputs and the
  # scan's faults.
  defp scan(program, inputs, state \\ nil) do
    state = state || Runtime.instance(program)
    {outputs, state} = Runtime.call(program, state, inputs, %Scan{now: 0, first: true})
    {outputs, state.faults}
  end

  # `read` is given as the subscripts' list, and the fault holds it as a tuple, `{8}`
  # (decision 233).
  defp fault(instruction, line, read, path \\ nil, file \\ nil),
    do: %Fault{
      severity: :major,
      kind: :index_out_of_range,
      instruction: instruction,
      path: path,
      file: file,
      line: line,
      read: List.to_tuple(read)
    }

  # Restated: every index of an array of `dims`, the rightmost subscript fastest.
  defp indexes([n]), do: for(i <- 0..(n - 1), do: [i])
  defp indexes([n | dims]), do: for(i <- 0..(n - 1), rest <- indexes(dims), do: [i | rest])

  # A host's list of lists from a map of elements by index.
  defp listed(elements, [_n]), do: elements |> Enum.sort() |> Enum.map(&elem(&1, 1))

  defp listed(elements, [n | dims]),
    do:
      for(
        row <- 0..(n - 1),
        do: listed(for({[^row | rest], v} <- elements, into: %{}, do: {rest, v}), dims)
      )

  describe "the element a tag subscripts (decision 152)" do
    test "every element of arrays of one, two and three dimensions is read and written through tags of every width" do
      for dims <- [[5], [2, 3], [2, 2, 3]], index <- @indexes do
        names = Enum.take(~w(i j k), length(dims))
        subscripted = "a[#{Enum.join(names, ",")}]"
        declared = Enum.map_join(names, "", &"var_input #{&1} #{index}\n")
        word = "int[#{Enum.join(dims, ",")}]"

        p =
          program(
            declared <>
              "var_input src #{word}\nvar_input v int\nvar_output seen int\n" <>
              "var_output out #{word}\nvar a #{word}\n" <>
              Enum.map_join(indexes(dims), "\n", fn at ->
                "move src[#{Enum.join(at, ",")}] a[#{Enum.join(at, ",")}]"
              end) <>
              "\nmove #{subscripted} seen\nmove v #{subscripted}\n" <>
              Enum.map_join(indexes(dims), "\n", fn at ->
                "move a[#{Enum.join(at, ",")}] out[#{Enum.join(at, ",")}]"
              end)
          )

        source = Map.new(Enum.with_index(indexes(dims)), fn {at, n} -> {at, 100 + n} end)

        for at <- indexes(dims) do
          inputs =
            Map.merge(
              Map.new(Enum.zip(names, at)),
              %{"src" => listed(source, dims), "v" => -7}
            )

          assert scan(p, inputs) ==
                   {%{"seen" => source[at], "out" => listed(Map.put(source, at, -7), dims)}, []},
                 inspect({dims, index, at})
        end
      end
    end

    test "a literal subscript beside a tag one, in any position and spelling" do
      p =
        program(
          "var_input r usint\nvar_input c lint\nvar_input v dint\nvar g dint[3,4]\n" <>
            "var_output q dint\nvar_output out dint[3,4]\n" <>
            "move v g[r,16#2]\nmove v g[2,c]\nmove g[r,c] q\n" <>
            Enum.map_join(indexes([3, 4]), "\n", fn [x, y] ->
              "move g[#{x},#{y}] out[#{x},#{y}]"
            end)
        )

      {outputs, []} = scan(p, %{"r" => 1, "c" => 2, "v" => 9})
      assert outputs["q"] == 9
      written = Map.new(indexes([3, 4]), &{&1, 0}) |> Map.put([1, 2], 9) |> Map.put([2, 2], 9)
      assert outputs["out"] == listed(written, [3, 4])

      {outputs, []} = scan(p, %{"r" => 0, "c" => 3, "v" => 9})
      assert outputs["q"] == 0
      written = Map.new(indexes([3, 4]), &{&1, 0}) |> Map.put([0, 2], 9) |> Map.put([2, 3], 9)
      assert outputs["out"] == listed(written, [3, 4])
    end

    test "a bit of an element a tag subscripts, its number literal or a tag's" do
      p =
        program(
          "var_input i int\nvar_input n int\nvar_input k bool\nvar_input src word[4]\n" <>
            "var w word[4]\nvar_output a bool\nvar_output b bool\nvar_output out word[4]\n" <>
            Enum.map_join(0..3, "\n", &"move src[#{&1}] w[#{&1}]") <>
            "\nxic w[i].3 ote a\nxic w[i].[n] ote b\nxic k otl w[i].[n]\nxic k otu w[i].0\n" <>
            Enum.map_join(0..3, "\n", &"move w[#{&1}] out[#{&1}]")
        )

      src = [0x0008, 0x0001, 0x8000, 0x00FF]

      for i <- 0..3, n <- [0, 3, 15], k <- [0, 1] do
        word = Enum.at(src, i)
        set = Bitwise.bor(word, Bitwise.bsl(1, n)) |> Bitwise.band(Bitwise.bnot(1))
        expected = if k == 1, do: List.replace_at(src, i, set), else: src

        assert scan(p, %{"i" => i, "n" => n, "k" => k, "src" => src}) ==
                 {%{
                    "a" => Bitwise.band(Bitwise.bsr(word, 3), 1),
                    "b" => Bitwise.band(Bitwise.bsr(word, n), 1),
                    "out" => expected
                  }, []},
               inspect({i, n, k})
      end
    end

    test "an element a tag subscripts is a use of its array with its slot's access, and of each subscript's tag read" do
      p =
        program(
          "var_input r int\nvar_input c int\nvar_input n int\nvar g word[2,2]\n" <>
            "var_output q bool\nmove 5 g[r,c]\nxic g[r,1].[n] ote q"
        )

      assert Walk.uses(p.rungs, Logex.Program.typed_tags(p)) == [
               {:write, "g", 6, :move},
               {:read, "r", 6, :move},
               {:read, "c", 6, :move},
               {:read, "g", 7, :xic},
               {:read, "r", 7, :xic},
               {:read, "n", 7, :xic},
               {:write, "q", 7, :ote}
             ]

      # A write through a tag subscript is a write of the array whole (§4.12's routine
      # choice), and of no element.
      assert Walk.writes(p) == %{"g" => [6], "q" => [7]}
      assert Walk.element_writes(p) == %{"g" => [6]}
      assert Walk.bit_writes(p) == %{}
    end
  end

  describe "an element a tag subscripts, in every type an element has" do
    test "a real element is written as its nearest real, an integer widened into it" do
      p =
        program(
          "var_input i int\nvar_input j int\nvar_input a int\nvar_input x real\n" <>
            "var r real[2]\nmul x 3.0 r[i]\nmove a r[j]"
        )

      state = Runtime.instance(p)

      {_outputs, state} =
        Runtime.call(p, state, %{"i" => 0, "j" => 1, "a" => 7, "x" => 0.1}, %Scan{
          now: 0,
          first: true
        })

      # Restated: the single nearest 0.1, times 3 in a double, held as its nearest single.
      <<x::float-32>> = <<0.1::float-32>>
      <<product::float-32>> = <<x * 3.0::float-32>>
      assert product != x * 3.0
      assert state.env["r"] === {product, 7.0}
    end

    test "a real literal its element's real cannot keep is warned, as a tag's is" do
      assert [{4, message}] =
               warnings(
                 "var_input i int\nvar r real[2]\nvar_output o real\n" <>
                   "move 16777217.0 r[i]\nmove r[0] o"
               )

      assert message =~ "`16777217.0`"
    end

    test "`not` of an element computes in its element's type, IEC's typing (decision 214)" do
      p =
        program(
          "var_input i int\nvar_input s byte[2]\nvar b byte[2]\nvar_output w word\n" <>
            "move s[0] b[0]\nmove s[1] b[1]\nnot b[i] w"
        )

      assert scan(p, %{"i" => 1, "s" => [0, 0x0F]}) == {%{"w" => 0x00F0}, []}
    end

    test "a bit a tag numbers of an element a tag subscripts, written: the index is checked first" do
      p =
        program(
          "var_input i int\nvar_input n int\nvar_input k bool\nvar w word[2]\n" <>
            "var_output o word\nxic k ote w[i].[n]\nmove w[0] o"
        )

      assert scan(p, %{"i" => 2, "n" => 16, "k" => 1}) == {%{"o" => 0}, [fault(:ote, 6, [2])]}
    end
  end

  describe "what is refused when the program compiles (decisions 152 and 154)" do
    test "a subscript tag that is no integer, or names no tag, each at its line" do
      head = "var w int[8]\nvar q int\n"

      for {declared, message} <- [
            {"var s bool",
             "`w[s]` takes a subscript from `s`, a bool (declared on line 3), which is no integer: a subscript is a literal or a tag of an integer type"},
            {"var s word",
             "`w[s]` takes a subscript from `s`, a word (declared on line 3), which is no integer: a subscript is a literal or a tag of an integer type, so convert it first, with `word_to_uint`"},
            {"var s real",
             "`w[s]` takes a subscript from `s`, a real (declared on line 3), which is no integer: a subscript is a literal or a tag of an integer type"},
            {"var s int[2]",
             "`w[s]` takes a subscript from `s`, an array of 2 ints (declared on line 3), which is no integer: a subscript is a literal or a tag of an integer type, never an array or one of its elements"},
            {"var s ton",
             "`w[s]` takes a subscript from `s`, but `s` is a ton (declared on line 3): a subscript is a literal or a tag of an integer type"}
          ] do
        assert messages(head <> declared <> "\nmove w[s] q") == [{4, message}], declared
      end

      assert messages(head <> "move w[xic] q") == [
               {3,
                "`w[xic]` takes a subscript from `xic`, an instruction, which cannot name a tag"}
             ]

      # Every subscript's tag is checked, after the element's own count and literals.
      assert messages(
               "var g int[4,8]\nvar q int\nvar a bool\nvar b bool\nmove g[a,b] q\n" <>
                 "move g[a] q\nmove g[a,8] q"
             ) == [
               {5,
                "`g[a,b]` takes a subscript from `a`, a bool (declared on line 3), which is no " <>
                  "integer: a subscript is a literal or a tag of an integer type"},
               {5,
                "`g[a,b]` takes a subscript from `b`, a bool (declared on line 4), which is no " <>
                  "integer: a subscript is a literal or a tag of an integer type"},
               {6,
                "`g[a]` names an element of `g`, an array of 4 by 8 ints (declared on line 1), " <>
                  "by 1 subscript, where it takes 2, one a dimension, as in `g[0,0]`"},
               {7,
                "`g[a,8]`'s subscript `8` is outside the second dimension of `g`, 0 to 7: `g` " <>
                  "is an array of 4 by 8 ints (declared on line 1)"}
             ]
    end

    test "an undeclared subscript tag is reported once, as any undeclared tag, and told how to declare" do
      assert messages("move w[slot] q") == [
               {1,
                "`w` is not declared" <>
                  " (this program declares no tags: each is now declared before the first " <>
                  "rung, as `var w dint[8]`)"},
               {1, "`q` is not declared"}
             ]

      assert messages("var w int[8]\nvar q int\nmove w[slot] q\nmove q w[slot]") == [
               {3, "`slot` is not declared"}
             ]
    end

    test "a `cal` operand's subscript is checked as any instruction's" do
      {:ok, seal} =
        Logex.compile("function_block seal\nvar_input s bool\nvar_output q bool\nxic s ote q",
          name: "seal"
        )

      assert messages(
               "var e bool[4]\nvar f bool\nvar s1 seal\nvar q bool\ncal s1 e[f] q",
               [seal]
             ) == [
               {5,
                "`e[f]` takes a subscript from `f`, a bool (declared on line 2), which is no " <>
                  "integer: a subscript is a literal or a tag of an integer type"}
             ]
    end

    # Decision 154: a one-shot's storage bit, and a pulse coil's pulse bit, names one bit
    # whatever the program does, for M1-6's rule of one one-shot to a bit and an edit's block
    # list; an element a tag subscripts moves as the tag does.
    test "a one-shot's storage bit and a pulse coil's pulse bit take literal subscripts" do
      head = "var e bool[4]\nvar w word[4]\nvar_input i int\nvar_input j int\nvar q bool\n"

      assert messages(head <> "xic q ons e[i] ote q") == [
               {6,
                "`ons` keeps its storage bit in `e[i]`, whose subscript `i` holds: a one-shot's " <>
                  "storage bit is a bool, a bit with a literal number or an element with literal " <>
                  "subscripts, as in `e[0]`, so that it is one bit whatever the program does"}
             ]

      assert messages(head <> "xic q osf w[i].3 q") == [
               {6,
                "`osf` keeps its storage bit in `w[i].3`, whose subscript `i` holds: a one-shot's " <>
                  "storage bit is a bool, a bit with a literal number or an element with literal " <>
                  "subscripts, as in `w[0].3`, so that it is one bit whatever the program does"}
             ]

      assert messages(head <> "xic q osr q e[j]") == [
               {6,
                "`osr` sets its pulse bit in `e[j]`, whose subscript `j` holds: a pulse coil's " <>
                  "pulse bit is a bool, a bit with a literal number or an element with literal " <>
                  "subscripts, as in `e[0]`, so that it is one bit whatever the program does"}
             ]

      # M5-12's review: a pulse bit in a bit of such an element, `w[i].3`, is refused too,
      # whatever the storage bit, where its name raised.
      for storage <- ["q", "e[1]", "w[1].2"] do
        for symbol <- ["osr", "osf"] do
          assert {storage,
                  Enum.filter(
                    messages(head <> "xic q #{symbol} #{storage} w[i].3"),
                    &(elem(&1, 1) =~ "pulse bit in")
                  )} ==
                   {storage,
                    [
                      {6,
                       "`#{symbol}` sets its pulse bit in `w[i].3`, whose subscript `i` holds: a " <>
                         "pulse coil's pulse bit is a bool, a bit with a literal number or an " <>
                         "element with literal subscripts, as in `w[0].3`, so that it is one bit " <>
                         "whatever the program does"}
                    ]}
        end
      end

      assert messages(
               "var g bool[4,4]\nvar_input i int\nvar_input j int\nvar q bool\nxic q ons g[i,j] ote q"
             ) ==
               [
                 {5,
                  "`ons` keeps its storage bit in `g[i,j]`, whose subscripts `i` and `j` hold: a " <>
                    "one-shot's storage bit is a bool, a bit with a literal number or an element " <>
                    "with literal subscripts, as in `g[0,0]`, so that it is one bit whatever the " <>
                    "program does"}
               ]

      assert {:ok, _} = Logex.compile(head <> "xic q ons e[2] ote q\nxic q osr e[3] q", name: "p")
    end
  end

  describe "a subscript out of range at run time: the major fault (decision 153)" do
    @slot "var_input slot dint\nvar_input go bool\nvar w int[8]\nvar e bool[8]\n"

    test "a contact passes no power, the rest of its rung running on that, and the scan finishes" do
      p =
        program(
          @slot <>
            "var_output a bool\nvar_output b bool\nvar_output c bool\n" <>
            "xic e[slot] ote a\nxio e[slot] ote b\nxic go ote c"
        )

      for slot <- [8, 9, -1, 1000] do
        assert scan(p, %{"slot" => slot, "go" => 1}) ==
                 {%{"a" => 0, "b" => 0, "c" => 1},
                  [fault(:xic, 8, [slot]), fault(:xio, 9, [slot])]}
      end

      assert scan(p, %{"slot" => 7, "go" => 1}) == {%{"a" => 0, "b" => 1, "c" => 1}, []}
    end

    # PLAN M5-12's Done-when: a false `otl weights_bits[slot]` raises nothing.
    test "a coil writes nothing and passes no power, energised or, for `ote`, not" do
      p =
        program(
          "var_input slot int\nvar_input on bool\nvar weights_bits bool[8]\n" <>
            "var_output after bool\nvar_output lit bool[8]\n" <>
            "xic on ote weights_bits[slot] ote after\nxic on otl weights_bits[slot]\n" <>
            "xic on otu weights_bits[slot]\n" <>
            Enum.map_join(0..7, "\n", &"move weights_bits[#{&1}] lit[#{&1}]")
        )

      for on <- [0, 1] do
        # A de-energised `otl` or `otu` reads and writes nothing, so checks nothing (RM018A
        # pp.86-87); a de-energised `ote` writes its 0, and so checks.
        faults =
          [fault(:ote, 6, [8])] ++
            if(on == 1, do: [fault(:otl, 7, [8]), fault(:otu, 8, [8])], else: [])

        assert scan(p, %{"slot" => 8, "on" => on}) ==
                 {%{"after" => 0, "lit" => List.duplicate(0, 8)}, faults}
      end

      assert scan(p, %{"slot" => 2, "on" => 1}) ==
               {%{"after" => 1, "lit" => [0, 0, 0, 0, 0, 0, 0, 0]}, []}
    end

    test "a `move` of an element, or into one, writes nothing and passes no power" do
      p =
        program(
          @slot <>
            "var_output from int\nvar_output ran bool\nvar_output next bool\n" <>
            "var_output out int[8]\nmove 1 from\n" <>
            "xic go move w[slot] from ote ran\nxic go move 5 w[slot] ote next\n" <>
            Enum.map_join(0..7, "\n", &"move w[#{&1}] out[#{&1}]")
        )

      assert scan(p, %{"slot" => 8, "go" => 1}) ==
               {%{"from" => 1, "ran" => 0, "next" => 0, "out" => List.duplicate(0, 8)},
                [fault(:move, 10, [8]), fault(:move, 11, [8])]}

      assert scan(p, %{"slot" => 3, "go" => 1}) ==
               {%{"from" => 0, "ran" => 1, "next" => 1, "out" => [0, 0, 0, 5, 0, 0, 0, 0]}, []}
    end

    test "arithmetic, a comparison, a conversion and a bitwise instruction write nothing and pass no power" do
      p =
        program(
          @slot <>
            "var_output d int\nvar_output l lint\nvar_output ran bool\nvar u word[2]\n" <>
            "move 1 d\nmove 1 l\n" <>
            "add w[slot] 1 d ote ran\nsub 1 2 w[slot] ote ran\neq w[slot] 0 ote ran\n" <>
            "int_to_lint w[slot] l ote ran\nand u[slot] 1 u[0] ote ran\nneg w[slot] d ote ran"
        )

      assert scan(p, %{"slot" => 2}) |> elem(0) |> Map.get("ran") == 1

      assert scan(p, %{"slot" => -3}) ==
               {%{"d" => 1, "l" => 1, "ran" => 0},
                [
                  fault(:add, 11, [-3]),
                  fault(:sub, 12, [-3]),
                  fault(:eq, 13, [-3]),
                  fault(:int_to_lint, 14, [-3]),
                  fault(:and, 15, [-3]),
                  fault(:neg, 16, [-3])
                ]}
    end

    test "every subscript is read, literal ones too, and any one outside its dimension faults" do
      p =
        program(
          "var_input r int\nvar_input c int\nvar g int[2,3,4]\nvar_output q bool\n" <>
            "move 5 g[r,1,c]\nmove 1 q"
        )

      assert scan(p, %{"r" => 1, "c" => 3}) == {%{"q" => 1}, []}

      for {r, c} <- [{2, 0}, {0, 4}, {-1, 3}, {5, 9}] do
        assert scan(p, %{"r" => r, "c" => c}) == {%{"q" => 1}, [fault(:move, 5, [r, 1, c])]}
      end
    end

    # The element is read before its bit, so an element outside its array is an index
    # fault, whatever the bit's number.
    test "a bit of an element: the index is checked first, and then the bit's number" do
      p =
        program(
          "var_input i int\nvar_input n int\nvar w word[2]\nvar_output a bool\n" <>
            "xic w[i].[n] ote a\nxic w[i].3 ote a"
        )

      assert scan(p, %{"i" => 2, "n" => 16}) ==
               {%{"a" => 0}, [fault(:xic, 5, [2]), fault(:xic, 6, [2])]}

      assert scan(p, %{"i" => 1, "n" => 16}) ==
               {%{"a" => 0},
                [
                  %Fault{
                    severity: :major,
                    kind: :bit_out_of_range,
                    instruction: :xic,
                    path: nil,
                    file: nil,
                    line: 5,
                    read: 16
                  }
                ]}
    end

    # Decision 210's rule for a bit holds for an index: a `cal` whose operand is out of
    # range runs no body, whether its copy-in or its copy-out met it.
    test "a `cal` whose operand's subscript is out of range does nothing, its body not run" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input s bool\nvar_output q bool\nvar_output runs dint\n" <>
            "add runs 1 runs\nxic s ote q",
          name: "seal"
        )

      p =
        program(
          @slot <>
            "var s1 seal\nvar_output q bool\nvar_output runs dint\nvar_output passed bool\n" <>
            "var s2 seal\nvar_output runs2 dint\nvar_output lit bool[8]\n" <>
            "xic go cal s1 e[slot] q runs ote passed\nxic go cal s2 go e[slot] runs2\n" <>
            Enum.map_join(0..7, "\n", &"move e[#{&1}] lit[#{&1}]"),
          [seal]
        )

      assert scan(p, %{"slot" => 8, "go" => 1}) ==
               {%{
                  "runs" => 0,
                  "runs2" => 0,
                  "passed" => 0,
                  "q" => 0,
                  "lit" => List.duplicate(0, 8)
                }, [fault(:cal, 12, [8]), fault(:cal, 13, [8])]}

      assert scan(p, %{"slot" => 4, "go" => 1}) ==
               {%{
                  "runs" => 1,
                  "runs2" => 1,
                  "passed" => 1,
                  "q" => 0,
                  "lit" => [0, 0, 0, 0, 1, 0, 0, 0]
                }, []}
    end

    test "a fault in a block's body is named by the instance's path, in the body's file" do
      dir =
        Path.join(System.tmp_dir!(), "logex_tag_subscript_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(
        Path.join(dir, "pick.ld"),
        "function_block pick\nvar_input slot int\nvar_output w int\nvar weights int[8]\n" <>
          "// the weight in the slot\nmove weights[slot] w\n"
      )

      File.write!(
        Path.join(dir, "line.ld"),
        "var_input slot int\nvar_output w int\nvar_output after bool\n" <>
          "var p1 pick\ncal p1 slot w\nmove 1 after\n"
      )

      assert {:ok, p} = Logex.compile_file(Path.join(dir, "line.ld"))

      assert scan(p, %{"slot" => 8}) ==
               {%{"w" => 0, "after" => 1},
                [fault(:move, 6, [8], "p1", Path.join(dir, "pick.ld"))]}
    end

    # A block's body holding such an element is a compiled body like any other, which a
    # type given must be (Logex.Compiler.lowered?/1): it relowers to itself, its subscripts,
    # dimensions and name as its type gives them.
    test "a block's body holding an element a tag subscripts is taken as given, and a forged one is not" do
      {:ok, pick} =
        Logex.compile(
          "function_block pick\nvar_input r int\nvar_output w int\nvar g int[2,8]\n" <>
            "move g[r,3] w",
          name: "pick"
        )

      assert Logex.FbType.user?(pick)
      assert Logex.Compiler.lowered?(pick.body)

      [{:rung, [{:move, line, [{:element_at, l, array, index, dims, name}, w]}]}] =
        pick.body.rungs

      assert {array, index, dims, name} == {"g", [{:name, l, "r"}, 3], [2, 8], "g[r,3]"}

      for forged <- [
            {:element_at, l, array, index, [2, 9], name},
            {:element_at, l, array, index, [2], name},
            {:element_at, l, array, [{:name, l, "w"}, 3], dims, name},
            {:element_at, l, array, [{:name, l, "r"}, 4], dims, name},
            {:element_at, l, array, [{:name, l, "r"}, -1], dims, name},
            {:element_at, l, array, index, dims, "g[r,4]"},
            {:element_at, -l, array, index, dims, name},
            {:element_at, l, array, index, dims, :name},
            {:element, l, array, [0, 3], name}
          ] do
        body = put_in(pick.body.rungs, [{:rung, [{:move, line, [forged, w]}]}])
        refute Logex.Compiler.lowered?(body), inspect(forged)
      end
    end

    test "a block's body holding a bit of an element a tag subscripts is taken as given" do
      {:ok, lamp} =
        Logex.compile(
          "function_block lamp\nvar_input i int\nvar_input n int\nvar_output q bool\n" <>
            "var w word[2]\nxic w[i].3 ote q\nxic w[i].[n] ote q",
          name: "lamp"
        )

      assert Logex.FbType.user?(lamp)
      assert Logex.Compiler.lowered?(lamp.body)

      assert {:ok, _} =
               Logex.compile(
                 "var_input i int\nvar_input n int\nvar_output q bool\nvar l1 lamp\ncal l1 i n q",
                 name: "p",
                 types: [lamp]
               )
    end

    test "every fault of one scan, in the order they happened, beside a zero divisor's and a bit's" do
      p =
        program(
          @slot <>
            "var_input z dint\nvar_input n int\nvar s word\nvar_output q dint\nvar_output a bool\n" <>
            "xic e[slot] ote a\ndiv 1 z q\nxic s.[n] ote a\nxio e[slot] ote a"
        )

      assert {_, [first, divided, bit, last]} =
               scan(p, %{"slot" => 8, "z" => 0, "n" => 16})

      assert first == fault(:xic, 10, [8])
      assert %Fault{severity: :minor, kind: :divide_by_zero, line: 11} = divided
      assert %Fault{severity: :major, kind: :bit_out_of_range, line: 12, read: 16} = bit
      assert last == fault(:xio, 13, [8])
    end

    test "the next scan's faults are its own, and a subscript back in range raises none" do
      p = program(@slot <> "var_output a bool\nxic e[slot] ote a")
      state = Runtime.instance(p)

      {_out, state} = Runtime.call(p, state, %{"slot" => 8}, %Scan{now: 0, first: true})
      assert state.faults == [fault(:xic, 6, [8])]
      {out, state} = Runtime.call(p, state, %{"slot" => 0}, %Scan{now: 10, first: false})
      assert {out, state.faults} == {%{"a" => 0}, []}
    end
  end

  # PLAN M5-12's Done-when: a skipped rung and a frozen block with `slot` at 8 raise
  # nothing.
  describe "what runs nothing checks nothing (decision 82)" do
    test "a rung a jump skips raises nothing, and runs on the next scan it is not skipped" do
      p =
        program(
          "var_input slot int\nvar_input skip bool\nvar weights int[8]\nvar_output a int\n" <>
            "var_output b bool\nxic skip jmp done\nmove weights[slot] a\nlbl done move 1 b"
        )

      assert scan(p, %{"slot" => 8, "skip" => 1}) == {%{"a" => 0, "b" => 1}, []}

      assert scan(p, %{"slot" => 8, "skip" => 0}) ==
               {%{"a" => 0, "b" => 1}, [fault(:move, 7, [8])]}
    end

    test "a block whose `cal` is false raises nothing" do
      {:ok, pick} =
        Logex.compile(
          "function_block pick\nvar_input slot int\nvar_output w int\nvar weights int[8]\n" <>
            "move weights[slot] w",
          name: "pick"
        )

      p =
        program(
          "var_input slot int\nvar_input run bool\nvar_output w int\nvar p1 pick\n" <>
            "xic run cal p1 slot w",
          [pick]
        )

      assert scan(p, %{"slot" => 8, "run" => 0}) == {%{"w" => 0}, []}

      assert scan(p, %{"slot" => 8, "run" => 1}) ==
               {%{"w" => 0}, [fault(:move, 5, [8], "p1")]}
    end
  end

  describe "the warnings (provisional)" do
    @later "the last one in the scan decides it"

    test "a coil on an element a tag subscripts is a coil in its array whole" do
      head =
        "var e bool[8]\nvar_input i int\nvar_input j int\nvar_input a bool\nvar s bool\n" <>
          "var_output o bool\nxic e[j] xio s ote o\n"

      # M5-12's review: each told the array, `e[j]` never told it is `e[i]`, which it may
      # not be, and a coil through a subscript after a literal one told both are in it.
      assert warnings(head <> "xic a ote e[i]\nxic a ote e[j]") == [
               {9,
                "`e[j]` is in `e`, which the `ote` on line 8 may write through a tag subscript: " <>
                  @later}
             ]

      assert warnings(head <> "xic a ote e[0]\nxic a ote e[i]") == [
               {9,
                "`e[i]` is in `e`, as `e[0]` is, which already has an `ote` on line 8: #{@later}"}
             ]

      assert warnings(head <> "xic a ote e[i]\nxic a ote e[0]") == [
               {9,
                "`e[0]` is in `e`, which the `ote` on line 8 may write through a tag subscript: " <>
                  @later}
             ]

      # A pulse coil's pulse bit is a coil too (decision 101).
      assert warnings(head <> "xic a osr s e[3]\nxic a ote e[i]") == [
               {9,
                "`e[i]` is in `e`, as `e[3]` is, which is already the pulse bit of the `osr` on " <>
                  "line 8: #{@later}"}
             ]

      # Two coils on literal elements of one array, beside none through a tag, are two
      # elements, as before.
      assert warnings(head <> "xic a ote e[0]\nxic a ote e[1]") == [
               {2, "`i` is declared but no rung uses it"}
             ]
    end

    test "a coil on a bit of an element a tag subscripts is a coil in its array whole" do
      head =
        "var w word[4]\nvar_input i int\nvar_input n int\nvar_input a bool\n" <>
          "var_output o bool\nxic w[0].[n] ote o\n"

      assert warnings(head <> "xic a ote w[i].3\nxic a ote w[1].3") == [
               {8,
                "`w[1].3` is in `w`, which the `ote` on line 7 may write through a tag subscript: " <>
                  @later}
             ]

      assert warnings(head <> "xic a ote w[1].[n]\nxic a ote w[i].[n]") == [
               {8,
                "`w[i].[n]` is in `w`, as `w[1].[n]` is, which already has an `ote` on line 7: " <>
                  @later}
             ]

      assert warnings(head <> "xic a ote w[i].3\nxic a ote w[i].4") == [
               {8,
                "`w[i].4` is in `w`, which the `ote` on line 7 may write through a tag subscript: " <>
                  @later}
             ]
    end

    # M5-12's review: a write through a tag subscript writes its array whole (§4.12's
    # routine choice), so beside a coil on a bit of an element of it, in either order, it
    # is the second-`ote` warning, as a write of the element whole is (decisions 207 and
    # 221); and a coil on a bit through a tag subscript beside a write of an element whole.
    test "a write through a tag subscript beside a coil on a bit of an element is warned" do
      head =
        "var w word[4]\nvar_input i int\nvar_input n int\nvar_input a bool\nvar_input x word\n" <>
          "var_output o bool\nxic w[0].[n] ote o\n"

      later = fn shown, first, line ->
        {line,
         "`#{shown}` is in `w`, which the `#{first}` on line #{line - 1} may write through " <>
           "a tag subscript: #{@later}"}
      end

      as = fn shown, other, what, line ->
        {line, "`#{shown}` is in `w`, as `#{other}` is, which #{what}: #{@later}"}
      end

      for {rungs, warning} <- [
            {"xic a ote w[2].1\nmove x w[i]",
             as.("w[i]", "w[2].1", "already has an `ote` on line 8", 9)},
            {"move x w[i]\nxic a ote w[2].1", later.("w[2].1", "move", 9)},
            {"xic a ote w[i].1\nmove x w[2]", later.("w[2]", "ote", 9)},
            {"move x w[2]\nxic a ote w[i].1",
             as.("w[i].1", "w[2]", "the `move` on line 8 writes whole", 9)},
            {"xic a ote w[i].1\nmove x w[i]", later.("w[i]", "ote", 9)},
            {"move x w[i]\nxic a ote w[i].1", later.("w[i].1", "move", 9)},
            {"xic a ote w[2].[n]\nmove x w[i]",
             as.("w[i]", "w[2].[n]", "already has an `ote` on line 8", 9)},
            {"move x w[i]\nxic a ote w[2].[n]", later.("w[2].[n]", "move", 9)},
            {"xic a ote w[i].1\nmove a w[2].[n]", later.("w[2].[n]", "ote", 9)},
            {"xic a ote w[2].1\nmove a w[i].[n]",
             as.("w[i].[n]", "w[2].1", "already has an `ote` on line 8", 9)},
            {"xic a ote w[2].1\nmove a w[i].3",
             as.("w[i].3", "w[2].1", "already has an `ote` on line 8", 9)},
            {"xic a osr o w[2].1\nmove x w[i]",
             as.("w[i]", "w[2].1", "is already the pulse bit of the `osr` on line 8", 9)}
          ] do
        assert {rungs, Enum.filter(warnings(head <> rungs), &(elem(&1, 1) =~ "is in `w`"))} ==
                 {rungs, [warning]}
      end

      # A write of another element whole, beside a coil on a bit of one, is two words, as
      # before.
      assert warnings(head <> "xic a ote w[2].1\nmove x w[3]") == [
               {2, "`i` is declared but no rung uses it"}
             ]
    end

    # Decision 235: a write through a tag subscript other than a coil's, any instruction's
    # through its write slot, beside a coil on an element of a bool array, in either order,
    # is the second-`ote` warning, as it is for a word array's bit (M5-12's review), and so
    # is a write of an element beside a coil through a tag subscript; a write of the
    # element itself beside its coil is still none, as `move a b` beside `ote b` is not.
    test "a write through a tag subscript beside a coil on an element of a bool array is warned" do
      head = "var_input a bool\nvar_input i int\nvar l bool[4]\nvar_output o bool\n"

      later = fn shown, first ->
        {6,
         "`#{shown}` is in `l`, which the `#{first}` on line 5 may write through a tag " <>
           "subscript: #{@later}"}
      end

      as = fn shown, other, what ->
        {6, "`#{shown}` is in `l`, as `#{other}` is, which #{what}: #{@later}"}
      end

      for {rungs, warning} <- [
            {"xic a ote l[2]\nmove a l[i]",
             as.("l[i]", "l[2]", "already has an `ote` on line 5")},
            {"move a l[i]\nxic a ote l[2]", later.("l[2]", "move")},
            {"xic a otl l[i]\nxic a ote l[2]", later.("l[2]", "otl")},
            {"xic a otu l[i]\nxic a ote l[2]", later.("l[2]", "otu")},
            {"and a a l[i]\nxic a ote l[2]", later.("l[2]", "and")},
            {"xic a ote l[2]\nnot a l[i]", as.("l[i]", "l[2]", "already has an `ote` on line 5")},
            {"xic a ote l[i]\nmove a l[2]", later.("l[2]", "ote")},
            {"move a l[2]\nxic a ote l[i]", as.("l[i]", "l[2]", "the `move` on line 5 writes")},
            {"xic a ote l[i]\nmove a l[i]", later.("l[i]", "ote")},
            {"move a l[i]\nxic a ote l[i]", later.("l[i]", "move")},
            {"xic a osf o l[2]\nmove a l[i]",
             as.("l[i]", "l[2]", "is already the pulse bit of the `osf` on line 5")}
          ] do
        assert {rungs,
                Enum.filter(
                  warnings(head <> rungs <> "\nxic l[0] ote o"),
                  &(elem(&1, 1) =~ "is in `l`")
                )} ==
                 {rungs, [warning]}
      end

      # The element itself, and another element, beside a coil on it: none.
      for rungs <- [
            "xic a ote l[2]\nmove a l[2]",
            "move a l[2]\nxic a ote l[2]",
            "xic a ote l[2]\nmove a l[3]",
            "xic a otl l[2]\nxic a ote l[2]"
          ] do
        assert {rungs, warnings(head <> rungs <> "\nxic l[0] ote o")} ==
                 {rungs, [{2, "`i` is declared but no rung uses it"}]}
      end
    end

    test "a write through a tag subscript is a write of each storage bit in its array" do
      assert warnings(
               "var e bool[4]\nvar w word[2]\nvar_input i int\nvar_input a bool\n" <>
                 "var_output p bool\nxic a ons e[2] ote p\nxic a ons w[01].3 xic p\n" <>
                 "xic a ote e[i]\nmove 0 w[i]"
             ) == [
               {8,
                "`ote` writes `e[2]`, the storage bit of the `ons` on line 6: the one-shot then " <>
                  "fires on the wrong scans"},
               {9,
                "`move` writes `w[01].3`, the storage bit of the `ons` on line 7: the one-shot " <>
                  "then fires on the wrong scans"}
             ]
    end

    test "a coil on a bit of an element a tag subscripts is a write of each storage bit in its array" do
      assert warnings(
               "var w word[2]\nvar_input i int\nvar_input a bool\nvar_output p bool\n" <>
                 "xic a ons w[1].3 ote p\nxic a ote w[i].4"
             ) == [
               {6,
                "`ote` writes `w[1].3`, the storage bit of the `ons` on line 5: the one-shot " <>
                  "then fires on the wrong scans"}
             ]
    end

    test "an element a tag subscripts compared with a literal at its type's limit is warned" do
      assert warnings("var w sint[4]\nvar_input i int\nvar_output q bool\nle w[i] 127 ote q") == [
               {4,
                "`le` compares `w[i]` with `127`, and an sint holds nothing above `127`: its " <>
                  "result never changes"}
             ]
    end
  end

  describe "an online edit" do
    test "a one-shot's rung is changed by an element's subscript tag, a use of the rung" do
      head =
        "var_input go bool\nvar_input i int\nvar_input j int\nvar e bool[4]\nvar x bool\n" <>
          "var_output p bool\n"

      v1 = program(head <> "xic go xic e[i] ons x ote p")
      {_out, ran} = Runtime.scan(v1, Runtime.instance(v1))

      {:ok, _edit, forecast} =
        Edit.accept(v1, program(head <> "xic go xic e[j] ons x ote p"), ran)

      assert Enum.any?(forecast, &match?({:ons_blocked, "x", _}, &1))

      {:ok, _edit, forecast} =
        Edit.accept(v1, program(head <> "xic go xic e[1] ons x ote p"), ran)

      assert Enum.any?(forecast, &match?({:ons_blocked, "x", _}, &1))

      {:ok, _edit, forecast} = Edit.accept(v1, v1, ran)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))

      # Moved to another line, the rung is the same rung (decision 21).
      moved = program(head <> "xic go ote p\nxic go xic e[i] ons x ote p")
      {:ok, _edit, forecast} = Edit.accept(v1, moved, ran)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))
    end

    test "a one-shot on an element whose array the program also writes through a tag subscript is blocked" do
      head = "var_input go bool\nvar_input i int\nvar e bool[4]\nvar_output p bool\n"
      v1 = program(head <> "xic go ons e[2] ote p\nxic go ote e[i]")
      {_out, ran} = Runtime.scan(v1, Runtime.instance(v1))
      {:ok, _edit, forecast} = Edit.accept(v1, v1, ran)
      assert Enum.any?(forecast, &match?({:ons_blocked, "e[2]", _}, &1))

      v2 = program(head <> "xic go ons e[2] ote p\nxic go ote e[3]")
      {_out, ran} = Runtime.scan(v2, Runtime.instance(v2))
      {:ok, _edit, forecast} = Edit.accept(v2, v2, ran)
      refute Enum.any?(forecast, &match?({:ons_blocked, _, _}, &1))
    end
  end

  describe "in a configuration" do
    defp feeder do
      program(
        "var_external speeds int[4]\nvar_external slot int\nvar_input s int\n" <>
          "move s speeds[slot]",
        [],
        "feeder"
      )
    end

    defp fixed_feeder do
      program("var_external speeds int[4]\nvar_input s int\nmove s speeds[1]", [], "fixed")
    end

    defp configured(text) do
      case Logex.Configuration.compile("plant", text, %{
             "feeder" => feeder(),
             "fixed" => fixed_feeder()
           }) do
        {:ok, configuration} -> {:ok, configuration}
        {:error, diagnostics} -> Enum.map(diagnostics, & &1.message)
      end
    end

    @globals "var_global speeds int[4]\nvar_global slot int\nvar_global s int\n"

    test "a var_external read only as a subscript is used, and an array written through one is driven" do
      assert {:ok, config} = configured(@globals <> "program f1 feeder\nf1.s s")
      assert config.warnings == []
    end

    @stands "each scan reads what the other last wrote, and the later write in a cycle stands"

    # §4.12's routine choice: a write through a tag subscript may write any element, so it
    # is a write of the array whole, beside another instance's write of one element; since
    # decision 236 the warning names the element they may share, `speeds[1]`, the writer
    # through a tag subscript one that "may", either way round, and two such writers the
    # array, both "may".
    test "a write through a tag subscript beside a write of one element names the element" do
      assert {:ok, config} =
               configured(@globals <> "program f1 feeder\nf1.s s\nprogram f2 fixed\nf2.s s")

      assert Enum.map(config.warnings, & &1.message) == [
               "`f2` writes `speeds[1]` through its var_external, as `f1` may (line 4): #{@stands}"
             ]

      assert {:ok, config} =
               configured(@globals <> "program f1 fixed\nf1.s s\nprogram f2 feeder\nf2.s s")

      assert Enum.map(config.warnings, & &1.message) == [
               "`f2` may write `speeds[1]` through its var_external, as `f1` does (line 4): " <>
                 @stands
             ]

      assert {:ok, config} =
               configured(@globals <> "program f1 feeder\nf1.s s\nprogram f2 feeder\nf2.s s")

      assert Enum.map(config.warnings, & &1.message) == [
               "`f2` may write `speeds` through its var_external, as `f1` may (line 4): #{@stands}"
             ]

      # Two writers through a tag subscript and one of an element: the second is told at the
      # array, and the third at its element, once each, citing the first.
      assert {:ok, config} =
               configured(
                 @globals <>
                   "program f1 feeder\nf1.s s\nprogram f2 feeder\nf2.s s\nprogram f3 fixed\nf3.s s"
               )

      assert Enum.map(config.warnings, &{&1.line, &1.message}) == [
               {6,
                "`f2` may write `speeds` through its var_external, as `f1` may (line 4): " <>
                  @stands},
               {8,
                "`f3` writes `speeds[1]` through its var_external, as `f1` may (line 4): " <>
                  @stands}
             ]

      assert {:ok, config} =
               configured(
                 "var_global speeds int[4]\nvar_global s int\nprogram f2 fixed\nf2.s s\n" <>
                   "program f3 fixed\nf3.s s"
               )

      assert Enum.map(config.warnings, & &1.message) == [
               "`f3` writes `speeds[1]` through its var_external, as `f2` does (line 3): each " <>
                 "scan reads what the other last wrote, and the later write in a cycle stands"
             ]
    end

    test "an instance writing two elements beside a write through a tag subscript is told each" do
      {:ok, two} =
        Logex.compile(
          "var_external speeds int[4]\nvar_input s int\nmove s speeds[1]\nmove s speeds[2]",
          name: "two"
        )

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          @globals <> "program f1 feeder\nf1.s s\nprogram t1 two\nt1.s s",
          %{"feeder" => feeder(), "two" => two}
        )

      assert Enum.map(config.warnings, & &1.message) == [
               "`t1` writes `speeds[1]` through its var_external, as `f1` may (line 4): #{@stands}",
               "`t1` writes `speeds[2]` through its var_external, as `f1` may (line 4): #{@stands}"
             ]
    end

    test "an element written through a tag subscript a connection drives an element of is told it" do
      {:ok, source} =
        Logex.compile("var_output o int\nmove 7 o", name: "source")

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          @globals <> "program f1 feeder\nf1.s s\nprogram c1 source\nc1.o speeds[2]",
          %{"feeder" => feeder(), "source" => source}
        )

      assert [message] = Enum.map(config.warnings, & &1.message)
      # M5-12's review: told the element it drives, where "it" read as the array.
      assert message ==
               "`f1` writes `speeds` through its var_external, and `c1.o` drives `speeds[2]` " <>
                 "(line 7): each scan reads what the other last wrote, and the later write in a " <>
                 "cycle stands"

      # Decision 236: an instance that writes another element, beside the writer through a
      # tag subscript, is told of that writer at its element, and not of the connection,
      # which drives an element it does not write.
      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          @globals <>
            "program f1 feeder\nf1.s s\nprogram c1 source\nc1.o speeds[2]\nprogram f2 fixed\nf2.s s",
          %{"feeder" => feeder(), "source" => source, "fixed" => fixed_feeder()}
        )

      assert Enum.map(config.warnings, & &1.message) == [
               "`f1` writes `speeds` through its var_external, and `c1.o` drives `speeds[2]` " <>
                 "(line 7): #{@stands}",
               "`f2` writes `speeds[1]` through its var_external, as `f1` may (line 4): #{@stands}"
             ]
    end

    # M5-12's review: a member or bit of an element at a far end is told the element is a
    # global's, as `wd.3` is told `wd` is a global, and an element out of range its range.
    test "a bit of an element at a far end is told the element is a global's" do
      {:ok, m} = Logex.compile("var_input speed int\nvar q bool\nxic speed.3 ote q", name: "m")

      for {far, message} <- [
            {"speeds[1].3",
             "`speeds[1].3` names a member of `speeds[1]`, but `speeds[1]` is an element of " <>
               "the global `speeds` (line 2), not an instance"},
            {"speeds[4].3",
             "`speeds[4]`'s subscript `4` is outside 0 to 3: `speeds` is a global array of 4 ints " <>
               "(line 2)"}
          ] do
        assert {:error, [%Logex.Diagnostic{line: 4, message: ^message}]} =
                 Logex.Configuration.compile(
                   "plant",
                   "task t interval 10 priority 1\nvar_global speeds int[4]\nprogram m1 m with t\n" <>
                     "m1.speed #{far}",
                   %{"m" => m}
                 )
      end
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

    # Measured: a read through one tag of a one-dimensional array 21 reductions a rung
    # against a literal subscript's 16, a write 22 against 17, the tag's read, its check and
    # the instruction's catch; two dimensions, one a tag, 35 against 18.
    test "an element read or written through a tag costs a bounded few reductions more than a literal one" do
      head =
        fixed(
          "var_input i int\nvar_input a int\nvar w int[8]\nvar g int[4,8]\nvar_output d int\n"
        )

      read = per_rung(head, fn _ -> "move w[i] d" end)
      literal = per_rung(head, fn _ -> "move w[3] d" end)
      write = per_rung(head, fn _ -> "move a w[i]" end)
      literal_write = per_rung(head, fn _ -> "move a w[3]" end)
      grid = per_rung(head, fn _ -> "move g[1,i] d" end)
      literal_grid = per_rung(head, fn _ -> "move g[1,3] d" end)

      assert read <= literal + 6,
             "a tag subscript's read took #{read} a rung, a literal's #{literal}"

      assert write <= literal_write + 6
      assert grid <= literal_grid + 18, "#{grid} against #{literal_grid}"
    end

    # A program with no tag subscript scans, rung for rung, in exactly the reductions it
    # took at e00ae03, before M5-12: an instruction is caught only where its clause's head
    # sees such an element among its operands. A `cal` is caught as it was.
    # The type an arithmetic, bitwise or root instruction computes in is read from an
    # element's array in the scan's table, with no rule asked (`Logex.Program.destination/3`).
    test "an element a tag subscripts as a destination costs what a literal one does, and its read" do
      for {head, tagged, literal} <- [
            {"var_input i int\nvar_input a int\nvar w int[8]\n", "add a 1 w[i]", "add a 1 w[3]"},
            {"var_input i int\nvar_input k word\nvar u word[8]\n", "and k 1 u[i]",
             "and k 1 u[3]"},
            {"var_input i int\nvar_input x real\nvar r real[8]\n", "sqrt x r[i]", "sqrt x r[3]"}
          ] do
        # Measured once to warm what the first scan of each loads, and then counted.
        _warm = per_rung(fixed(head), fn _ -> tagged end)
        t = per_rung(fixed(head), fn _ -> tagged end)
        l = per_rung(fixed(head), fn _ -> literal end)
        # Measured: 5 reductions a rung more, the subscript's read, its check and the
        # instruction's catch, and no more: a type asked of the one rule would cost one.
        assert t == l + 5, "#{tagged} took #{t} a rung, #{literal} #{l}"
      end
    end

    test "a program of none scans as it did before M5-12" do
      assert per_rung(
               fixed("var_input a bool\nvar_input b bool\nvar_output q bool\n"),
               fn _ -> "xic a xio b ote q" end
             ) == 34.0

      assert per_rung(fixed("var_input a int\nvar w int[8]\nvar_output d int\n"), fn _ ->
               "move w[3] d"
             end) == 16.0

      assert per_rung(fixed("var_input a int\nvar w int[8]\nvar_output d int\n"), fn _ ->
               "move a w[3]"
             end) == 17.0

      assert per_rung(fixed("var g int[4,8]\nvar_output d int\n"), fn _ -> "move g[1,3] d" end) ==
               18.0

      assert per_rung(fixed("var e bool[8]\nvar_output q bool\n"), fn _ -> "xic e[3] ote q" end) ==
               23.0

      assert per_rung(fixed("var g word[8]\nvar_output q bool\n"), fn _ -> "xic g[1].3 ote q" end) ==
               27.0

      assert per_rung(
               fixed("var_input w word\nvar_input n int\nvar_output q bool\n"),
               fn _ -> "xic w.[n] ote q" end
             ) == 35.0

      cals = fn n ->
        "var_input a bool\nvar_output q bool\n" <>
          Enum.map_join(1..n, "\n", &"var s#{&1} seal") <> "\n"
      end

      assert_in_delta per_rung(cals, &"cal s#{&1} a q"), 178.01, 0.001
    end

    # Decision 235: a coil on an element of a bool array makes the warnings look for writes
    # through a tag subscript, one look an instruction, so the compile stays linear in the
    # coils and the writes, each warned.
    test "the warnings of coils on elements beside writes through a subscript cost linear reductions" do
      source = fn n ->
        "var_input a bool\nvar_input i int\nvar l bool[8]\nvar_output q bool\n" <>
          Enum.map_join(1..n, "\n", fn _ -> "xic a ote l[2]\nmove a l[i]\nxic l[1] ote q" end)
      end

      compile = fn n ->
        text = source.(n)
        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, p} = Logex.compile(text, name: "p")
        {:reductions, later} = Process.info(self(), :reductions)
        {later - before, p}
      end

      _warm = compile.(10)
      {small, _} = compile.(200)
      {large, p} = compile.(400)
      assert large / small < 2.4
      # Each write told once, after the first coil, and each later coil the plain second
      # `ote`, on `l[2]` and on `q`.
      assert Enum.count(p.warnings, &(&1.message =~ "is in `l`")) == 400
      assert length(p.warnings) == 400 + 399 + 399
    end

    test "a program's tag subscripts cost linear reductions to compile and to scan" do
      source = fn n ->
        "var_input i int\nvar_input j int\nvar g int[4,8]\nvar_output q int\n" <>
          Enum.map_join(1..n, "\n", fn _ -> "move g[i,j] q\nmove q g[j,3]" end)
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

      scan_cost =
        per_rung(
          fixed("var_input i int\nvar_input j int\nvar g int[4,8]\nvar_output q int\n"),
          fn _ -> "move g[i,j] q" end
        )

      assert scan_cost < 60
    end
  end
end
