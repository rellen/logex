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

      # Decision 405: a bit's literal number is one more place, so two bits whose numbers
      # differ never meet, through the very tag too; two of one number may.
      assert warnings(head <> "xic a ote w[i].3\nxic a ote w[i].4") == []

      assert warnings(head <> "xic a ote w[i].3\nxic a ote w[n].3") == [
               {8,
                "`w[n].3` is in `w`, which the `ote` on line 7 may write through a tag subscript: " <>
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
            {"xic a ote w[2].1\nmove a w[i].1",
             as.("w[i].1", "w[2].1", "already has an `ote` on line 8", 9)},
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

      # Decision 405: a write of a bit through a tag subscript, beside a coil on a bit of
      # another number, never meets it.
      assert Enum.filter(
               warnings(head <> "xic a ote w[2].1\nmove a w[i].3"),
               &(elem(&1, 1) =~ "is in `w`")
             ) ==
               []
    end

    # Decision 235: a write through a tag subscript other than a coil's, any instruction's
    # through its write slot, beside a coil on an element of a bool array, in either order,
    # is the second-`ote` warning, as it is for a word array's bit (M5-12's review), and so
    # is a write of an element beside a coil through a tag subscript; a write of the
    # element itself beside its coil is still none, as `move a b` beside `ote b` is not.
    test "a write through a tag subscript beside a coil on an element of a bool array is warned" do
      head =
        "var_input a bool\nvar_input i int\nvar_input j int\nvar l bool[4]\nvar_output o bool\n"

      later = fn shown, first ->
        {7,
         "`#{shown}` is in `l`, which the `#{first}` on line 6 may write through a tag " <>
           "subscript: #{@later}"}
      end

      as = fn shown, other, what ->
        {7, "`#{shown}` is in `l`, as `#{other}` is, which #{what}: #{@later}"}
      end

      for {rungs, warning} <- [
            {"xic a ote l[2]\nmove a l[i]",
             as.("l[i]", "l[2]", "already has an `ote` on line 6")},
            {"move a l[i]\nxic a ote l[2]", later.("l[2]", "move")},
            {"xic a otl l[i]\nxic a ote l[2]", later.("l[2]", "otl")},
            {"xic a otu l[i]\nxic a ote l[2]", later.("l[2]", "otu")},
            {"and a a l[i]\nxic a ote l[2]", later.("l[2]", "and")},
            {"xic a ote l[2]\nnot a l[i]", as.("l[i]", "l[2]", "already has an `ote` on line 6")},
            {"xic a ote l[i]\nmove a l[2]", later.("l[2]", "ote")},
            {"move a l[2]\nxic a ote l[i]", as.("l[i]", "l[2]", "the `move` on line 6 writes")},
            # Decision 246: through another tag, `l[j]`, it is still warned.
            {"xic a ote l[i]\nmove a l[j]", later.("l[j]", "ote")},
            {"xic a otl l[j]\nxic a ote l[i]", later.("l[i]", "otl")},
            {"xic a osf o l[2]\nmove a l[i]",
             as.("l[i]", "l[2]", "is already the pulse bit of the `osf` on line 6")}
          ] do
        assert {rungs,
                Enum.filter(
                  warnings(head <> rungs <> "\nxic l[0] ote o"),
                  &(elem(&1, 1) =~ "is in `l`")
                )} ==
                 {rungs, [warning]}
      end

      # Two coils through the very tag are two coils, as `ote l[2]` twice is, and since
      # M5-14's review (provisional) told so in its words, as `ote w.[n]` twice is: the
      # element already has an `ote`, never that its array "may" be written.
      for {rungs, warning} <- [
            {"xic a ote l[i]\nxic a ote l[i]",
             {7, "`l[i]` already has an `ote` on line 6: #{@later}"}}
          ] do
        assert {rungs,
                Enum.filter(warnings(head <> rungs <> "\nxic l[0] ote o"), &(elem(&1, 0) == 7))} ==
                 {rungs, [warning]}
      end

      words =
        "var w word[4]\nvar_input i int\nvar_input n int\nvar_input a bool\n" <>
          "var_output o bool\nxic w[0].[n] ote o\n"

      assert warnings(words <> "xic a ote w[i].3\nxic a ote w[i].3") == [
               {8, "`w[i].3` already has an `ote` on line 7: #{@later}"}
             ]

      assert warnings(words <> "xic a ote w[i].[n]\nxic a ote w[i].[n]") == [
               {8, "`w[i].[n]` already has an `ote` on line 7: #{@later}"}
             ]

      # The element itself, and another element, beside a coil on it: none; and since
      # decision 246 the very element through the very tag, `l[i]` beside `l[i]`, any write
      # but a coil's, in either order, as `l[2]` beside `l[2]` is not, where M5-13's review
      # warned it.
      for rungs <- [
            "xic a ote l[2]\nmove a l[2]",
            "move a l[2]\nxic a ote l[2]",
            "xic a ote l[2]\nmove a l[3]",
            "xic a otl l[2]\nxic a ote l[2]",
            "xic a ote l[i]\nmove a l[i]",
            "move a l[i]\nxic a ote l[i]",
            "xic a ote l[i]\nxic a otl l[i]",
            "xic a otu l[i]\nxic a ote l[i]"
          ] do
        assert {rungs,
                Enum.filter(
                  warnings(head <> rungs <> "\nxic l[0] ote o"),
                  &(elem(&1, 1) =~ @later)
                )} ==
                 {rungs, []}
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

    # Decision 405: of each storage bit in its array it may meet, a bit's literal number
    # one more place, so a coil on a bit of another number writes none.
    test "a coil on a bit of an element a tag subscripts is a write of each storage bit in its array it may meet" do
      assert warnings(
               "var w word[2]\nvar_input i int\nvar_input a bool\nvar_output p bool\n" <>
                 "xic a ons w[1].3 ote p\nxic a ote w[i].3"
             ) == [
               {6,
                "`ote` writes `w[1].3`, the storage bit of the `ons` on line 5: the one-shot " <>
                  "then fires on the wrong scans"}
             ]

      assert warnings(
               "var w word[2]\nvar_input i int\nvar_input a bool\nvar_output p bool\n" <>
                 "xic a ons w[1].3 ote p\nxic a ote w[i].4"
             ) == []
    end

    test "an element a tag subscripts compared with a literal at its type's limit is warned" do
      assert warnings("var w sint[4]\nvar_input i int\nvar_output q bool\nle w[i] 127 ote q") == [
               {4,
                "`le` compares `w[i]` with `127`, and an sint holds nothing above `127`: its " <>
                  "result never changes"}
             ]
    end
  end

  # Decision 372: two writes of one array whose literal subscripts differ in any place,
  # the rows of a lamp panel, never share an element and are not warned; two that may
  # meet are warned as before, each told the earliest write that may meet it.
  describe "two writes whose literal subscripts differ (decision 372)" do
    @later "the last one in the scan decides it"
    @panel "var_input a bool\nvar_input i int\nvar_input j int\nvar_input k int\n" <>
             "var_input c int\nvar ee bool[2,4]\nvar cube bool[2,3,3]\nvar g word[2,3]\n" <>
             "var lc ctu[2,2]\nvar e bool[4]\nvar_output o bool\n" <>
             "xic ee[i,j] xic cube[i,j,k] xic g[i,j].[k] xic lc[i,j].q xic e[i] ote o\n"

    defp told(rungs),
      do:
        for(
          {line, message} <- warnings(@panel <> rungs),
          String.ends_with?(message, @later),
          do: {line, message}
        )

    defp may(line, write, first),
      do:
        {line,
         "`#{write}` is in `#{array_of(write)}`, which the `ote` on line #{first} may write " <>
           "through a tag subscript: " <> @later}

    defp as_in(line, write, other, first),
      do:
        {line,
         "`#{write}` is in `#{array_of(write)}`, as `#{other}` is, which already has an `ote` " <>
           "on line #{first}: " <> @later}

    defp array_of(write), do: hd(String.split(write, "["))

    test "in one dimension a tag subscript may meet every element, as before" do
      assert told("xic a ote e[i]\nxic a ote e[1]") == [may(14, "e[1]", 13)]
      assert told("xic a ote e[1]\nxic a ote e[i]") == [as_in(14, "e[i]", "e[1]", 13)]
      assert told("xic a ote e[i]\nxic a ote e[j]") == [may(14, "e[j]", 13)]
    end

    test "in two dimensions, rows that differ are not warned, and rows that may meet are" do
      for rungs <- [
            "xic a ote ee[1,i]\nxic a ote ee[0,i]",
            "xic a ote ee[0,i]\nxic a ote ee[1,3]",
            "xic a ote ee[i,0]\nxic a ote ee[1,1]",
            "xic a ote ee[1,1]\nxic a ote ee[i,0]",
            "xic a ote ee[0,i]\nxic a otl ee[1,i]",
            "xic a otl ee[1,i]\nxic a ote ee[0,i]"
          ] do
        assert {rungs, told(rungs)} == {rungs, []}
      end

      assert told("xic a ote ee[i,0]\nxic a ote ee[j,0]") == [may(14, "ee[j,0]", 13)]
      assert told("xic a ote ee[i,0]\nxic a ote ee[1,0]") == [may(14, "ee[1,0]", 13)]
      assert told("xic a ote ee[1,1]\nxic a ote ee[i,1]") == [as_in(14, "ee[i,1]", "ee[1,1]", 13)]
      assert told("xic a ote ee[0,i]\nxic a otl ee[0,j]") == [may(14, "ee[0,j]", 13)]
    end

    # The earliest write that may meet a write, past one that never can.
    test "a write is told the earliest write that may meet it" do
      assert told("xic a ote ee[0,i]\nxic a ote ee[1,2]\nxic a ote ee[1,i]") == [
               as_in(15, "ee[1,i]", "ee[1,2]", 14)
             ]

      assert told("xic a ote ee[0,i]\nxic a ote ee[1,j]\nxic a ote ee[i,1]") == [
               may(15, "ee[i,1]", 13)
             ]

      # Two that may meet it, kept under two projections, `ee[i,j]`'s and `ee[1,k]`'s: the
      # earlier is told, by the order each came in.
      assert told("xic a ote ee[i,j]\nxic a ote ee[1,k]\nxic a ote ee[1,1]") == [
               may(14, "ee[1,k]", 13),
               may(15, "ee[1,1]", 13)
             ]
    end

    # A write through a tag subscript that is no coil, `otl ee[i,1]`, in an array whose
    # coils are of literal subscripts alone, finds each that may meet it as a coil through
    # a tag subscript does.
    test "a latch through a tag subscript beside coils of literal subscripts alone" do
      assert told("xic a ote ee[1,1]\nxic a otl ee[i,1]") == [as_in(14, "ee[i,1]", "ee[1,1]", 13)]
      assert told("xic a ote ee[1,1]\nxic a otl ee[i,0]") == []

      assert told("xic a ote lc[1,1].r\nxic a otl lc[i,1].r") == [
               as_in(14, "lc[i,1].r", "lc[1,1].r", 13)
             ]

      assert told("xic a ote lc[1,1].r\nxic a otl lc[i,0].r") == []
    end

    test "in three dimensions, any place that differs" do
      assert told("xic a ote cube[0,i,1]\nxic a ote cube[0,j,2]") == []
      assert told("xic a ote cube[1,1,1]\nxic a ote cube[i,1,0]") == []

      assert told("xic a ote cube[0,i,1]\nxic a ote cube[k,j,1]") == [
               may(14, "cube[k,j,1]", 13)
             ]

      assert told("xic a ote cube[1,1,1]\nxic a ote cube[i,1,1]") == [
               as_in(14, "cube[i,1,1]", "cube[1,1,1]", 13)
             ]
    end

    test "an element's members and bits, and a whole write of an element" do
      for rungs <- [
            "xic a ote lc[0,i].r\nxic a ote lc[1,i].r",
            "xic a ote lc[1,0].r\nxic a ote lc[0,i].r",
            "xic a ote lc[0,i].r\nxic a otl lc[1,j].r",
            "xic a ote g[1,c].3\nxic a ote g[0,c].3",
            "xic a ote g[1,2].3\nxic a ote g[0,c].3",
            "xic a ote g[0,c].3\nmove 5 g[1,j]",
            "xic a ote g[0,c].3\nmove 5 g[1,2]",
            "xic a ote lc[0,i].pv.3\nxic a ote lc[1,i].pv.3",
            "xic a ote lc[0,i].pv.3\nmove 5 lc[1,j].pv",
            "xic a ote lc[0,i].pv.3\nmove 5 lc[1,1].pv",
            "xic a ote lc[1,1].pv.3\nxic a ote lc[0,i].pv.3"
          ] do
        assert {rungs, told(rungs)} == {rungs, []}
      end

      assert told("xic a ote lc[0,i].r\nxic a ote lc[j,i].r") == [may(14, "lc[j,i].r", 13)]

      assert told("xic a ote lc[1,0].r\nxic a ote lc[i,0].r") == [
               as_in(14, "lc[i,0].r", "lc[1,0].r", 13)
             ]

      assert told("xic a ote lc[0,i].r\nxic a otl lc[0,j].r") == [may(14, "lc[0,j].r", 13)]
      assert told("xic a ote g[1,c].3\nxic a ote g[j,c].3") == [may(14, "g[j,c].3", 13)]

      assert told("xic a ote g[1,2].3\nxic a ote g[1,c].3") == [
               as_in(14, "g[1,c].3", "g[1,2].3", 13)
             ]

      assert told("xic a ote g[0,c].3\nmove 5 g[0,j]") == [may(14, "g[0,j]", 13)]
      assert told("xic a ote g[0,c].3\nmove 5 g[0,2]") == [may(14, "g[0,2]", 13)]
      assert told("xic a ote lc[0,i].pv.3\nmove 5 lc[0,j].pv") == [may(14, "lc[0,j].pv", 13)]
      assert told("xic a ote lc[0,i].pv.3\nmove 5 lc[0,1].pv") == [may(14, "lc[0,1].pv", 13)]

      assert told("xic a ote lc[1,1].pv.3\nxic a ote lc[1,i].pv.3") == [
               as_in(14, "lc[1,i].pv.3", "lc[1,1].pv.3", 13)
             ]
    end

    defp may_by(line, write, symbol, first),
      do:
        {line,
         "`#{write}` is in `#{array_of(write)}`, which the `#{symbol}` on line #{first} may " <>
           "write through a tag subscript: " <> @later}

    defp as_written(line, write, other, {symbol, first}, writes),
      do:
        {line,
         "`#{write}` is in `#{array_of(write)}`, as `#{other}` is, which the `#{symbol}` on " <>
           "line #{first} #{writes}: " <> @later}

    # RV-9's review: each kind of write looks up, under its projections, each earlier kind
    # that may meet it, and each lookup is held here, by the pair that reaches it: a later
    # write that may meet the first is told it, and its twin, one literal place apart, is
    # not. Each look-up by its plain key in place of its projections loses the first.
    test "each kind of write after each that may meet it, and its twin that never can" do
      for {met, twin, told} <- [
            # a literal element's coil after a latch through a tag subscript
            {"xic a otl ee[j,0]\nxic a ote ee[1,0]", "xic a otl ee[j,0]\nxic a ote ee[1,1]",
             [may_by(14, "ee[1,0]", "otl", 13)]},
            # a literal element's bit after a whole write through a tag subscript
            {"move 5 g[0,j]\nxic a ote g[0,0].0", "move 5 g[1,j]\nxic a ote g[0,0].0",
             [may_by(14, "g[0,0].0", "move", 13)]},
            # a bit a tag numbers, of a literal element, after a whole write through one
            {"move 5 g[i,j]\nxic a ote g[0,1].[k]", "move 5 g[i,1]\nxic a ote g[0,2].[k]",
             [may_by(14, "g[0,1].[k]", "move", 13)]},
            # a literal element's member after a coil, and after a latch, through one
            {"xic a ote lc[i,0].r\nxic a ote lc[1,0].r",
             "xic a ote lc[i,0].r\nxic a ote lc[1,1].r", [may_by(14, "lc[1,0].r", "ote", 13)]},
            {"xic a otl lc[i,1].r\nxic a ote lc[1,1].r",
             "xic a otl lc[i,1].r\nxic a ote lc[1,0].r", [may_by(14, "lc[1,1].r", "otl", 13)]},
            # a bit of a literal element's member after a coil on one through a tag subscript
            {"xic a ote lc[i,j].pv.0\nxic a ote lc[1,0].pv.0",
             "xic a ote lc[i,0].pv.0\nxic a ote lc[1,1].pv.0",
             [may_by(14, "lc[1,0].pv.0", "ote", 13)]},
            # a member through a tag subscript after a latch of a literal element's
            {"xic a otl lc[1,1].r\nxic a ote lc[j,1].r",
             "xic a otl lc[1,1].r\nxic a ote lc[j,0].r",
             [as_written(14, "lc[j,1].r", "lc[1,1].r", {"otl", 13}, "writes")]},
            # a bit of a member through a tag subscript after a literal element's member
            # written whole
            {"move 5 lc[0,0].pv\nxic a ote lc[j,0].pv.0",
             "move 5 lc[0,1].pv\nxic a ote lc[j,0].pv.0",
             [as_written(14, "lc[j,0].pv.0", "lc[0,0].pv", {"move", 13}, "writes whole")]},
            # a latch of a literal element's member after a coil through a tag subscript
            {"xic a ote lc[i,j].r\nxic a otl lc[1,0].r",
             "xic a ote lc[i,0].r\nxic a otl lc[1,1].r", [may_by(14, "lc[1,0].r", "ote", 13)]},
            # a coil through a tag subscript after a latch of a literal element
            {"xic a otl ee[0,0]\nxic a ote ee[i,0]", "xic a otl ee[0,0]\nxic a ote ee[i,1]",
             [as_written(14, "ee[i,0]", "ee[0,0]", {"otl", 13}, "writes")]},
            # and after a latch through a tag subscript
            {"xic a otl ee[i,0]\nxic a ote ee[0,i]", "xic a otl ee[i,0]\nxic a ote ee[j,1]",
             [may_by(14, "ee[0,i]", "otl", 13)]},
            # a bit through a tag subscript after a coil on a literal element's bit, and
            # after one on a bit a tag numbers of a literal element
            {"xic a ote g[0,1].1\nxic a otu g[i,1].[k]",
             "xic a ote g[0,1].1\nxic a otu g[i,2].[k]",
             [as_in(14, "g[i,1].[k]", "g[0,1].1", 13)]},
            {"xic a ote g[1,0].[k]\nxic a otl g[i,j].1",
             "xic a ote g[1,0].[k]\nxic a otl g[i,1].1",
             [as_in(14, "g[i,j].1", "g[1,0].[k]", 13)]},
            # a member through a tag subscript after an unlatch through another
            {"xic a otu lc[j,1].r\nxic a ote lc[1,j].r",
             "xic a otu lc[j,1].r\nxic a ote lc[i,0].r", [may_by(14, "lc[1,j].r", "otu", 13)]},
            # a bit of a literal element's member after an unlatch of it through a tag
            # subscript, and one through a tag subscript after a latch of a literal one's
            {"xic a otu lc[i,0].pv.0\nxic a ote lc[1,0].pv.0",
             "xic a otu lc[i,0].pv.0\nxic a ote lc[1,1].pv.0",
             [may_by(14, "lc[1,0].pv.0", "otu", 13)]},
            {"xic a otl lc[0,0].pv.1\nxic a ote lc[i,0].pv.1",
             "xic a otl lc[0,0].pv.1\nxic a ote lc[i,1].pv.1",
             [as_written(14, "lc[i,0].pv.1", "lc[0,0].pv.1", {"otl", 13}, "writes")]},
            # a bit of a member through a tag subscript after an unlatch of it through
            # another, after a coil on it through another, and after the member written
            # whole through another
            {"xic a otu lc[0,j].pv.0\nxic a ote lc[j,0].pv.0",
             "xic a otu lc[0,j].pv.0\nxic a ote lc[1,i].pv.0",
             [may_by(14, "lc[j,0].pv.0", "otu", 13)]},
            {"xic a ote lc[i,1].pv.1\nxic a ote lc[1,i].pv.1",
             "xic a ote lc[i,1].pv.1\nxic a ote lc[j,0].pv.1",
             [may_by(14, "lc[1,i].pv.1", "ote", 13)]},
            {"move 5 lc[0,i].pv\nxic a ote lc[j,j].pv.1",
             "move 5 lc[0,i].pv\nxic a ote lc[1,j].pv.1",
             [may_by(14, "lc[j,j].pv.1", "move", 13)]}
          ] do
        assert {met, told(met)} == {met, told}
        assert {twin, told(twin)} == {twin, []}
      end
    end

    # The review's own programs, a write of another array between, `ee`, `g` or `cube`.
    test "the review's programs, each a write between" do
      assert told("move 5 g[0,j]\nxic a otl ee[0,i]\nxic a ote g[0,0].0") == [
               may_by(15, "g[0,0].0", "move", 13)
             ]

      assert told("move 5 g[i,j]\nxic a ote cube[j,j,i]\nxic a ote g[0,1].[k]\nxic a ote e[1]") ==
               [may_by(15, "g[0,1].[k]", "move", 13)]

      assert told("xic a ote g[0,1].1\nxic a otl lc[i,1].r\nxic a ote lc[1,1].r") == [
               may_by(15, "lc[1,1].r", "otl", 14)
             ]

      assert told("xic a ote g[j,1].[k]\nxic a otl lc[1,1].r\nxic a ote lc[j,1].r") == [
               as_written(15, "lc[j,1].r", "lc[1,1].r", {"otl", 14}, "writes")
             ]

      assert told(
               "xic a ote g[i,1].[k]\nmove 5 g[i,1]\nmove 5 lc[0,0].pv\nxic a ote lc[j,0].pv.0"
             ) == [
               may_by(14, "g[i,1]", "ote", 13),
               as_written(16, "lc[j,0].pv.0", "lc[0,0].pv", {"move", 15}, "writes whole")
             ]

      assert told("xic a otl ee[0,0]\nxic a ote g[i,i].1\nxic a ote ee[i,0]") == [
               as_written(15, "ee[i,0]", "ee[0,0]", {"otl", 13}, "writes")
             ]
    end

    # Each first an array keeps is kept under its projections, at most 8, and each write
    # looks up those that may meet it, so the warnings stay linear in the writes: rows of
    # 2x the writes cost 2x, where comparing each write with every earlier one would cost 4x.
    # Counted in a process of its own with a heap the collector never visits, the least of
    # three runs.
    test "the warnings stay linear in the writes of an array" do
      cost = fn n ->
        source =
          "var_input a bool\nvar_input i int\nvar_input j int\nvar ee bool[#{n},4]\n" <>
            Enum.map_join(0..(n - 1), "\n", fn row ->
              "xic a ote ee[#{row},i]\nxic a ote ee[#{row},j]\nxic a ote ee[i,#{rem(row, 4)}]"
            end)

        p = program(source)
        tags = Logex.Program.typed_tags(p)
        parent = self()

        Enum.min(
          for _run <- 1..3 do
            {_pid, ref} =
              :erlang.spawn_opt(
                fn ->
                  {:reductions, before} = Process.info(self(), :reductions)
                  Logex.Warnings.of(p.rungs, tags)
                  {:reductions, later} = Process.info(self(), :reductions)
                  send(parent, {:warned, later - before})
                end,
                [:monitor, min_heap_size: 8_000_000]
              )

            assert_receive {:warned, reductions}, 10_000
            assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
            reductions
          end
        )
      end

      ratio = cost.(200) / cost.(100)
      assert ratio < 2.3, "2x the writes took #{Float.round(ratio, 2)}x the reductions"
    end

    # An array no write names through a tag subscript has nothing to compare, so its
    # literal writes keep their plain keys: 200 coils on a row of a two-dimensional array
    # cost the warnings 30 reductions a coil more than 200 on a one-dimensional one, 24 at
    # `d7a1290`, the longer name's, and 6 the look for a write through a tag subscript
    # among the routine's writes, where keeping each under its projections would cost some
    # 150 more. The least of three runs each; the bound is a fifth above the figure.
    test "an array of two dimensions no tag subscript writes costs what one of one does" do
      warned = fn source ->
        p = program(source)
        tags = Logex.Program.typed_tags(p)
        parent = self()

        Enum.min(
          for _run <- 1..3 do
            {_pid, ref} =
              :erlang.spawn_opt(
                fn ->
                  {:reductions, before} = Process.info(self(), :reductions)
                  Logex.Warnings.of(p.rungs, tags)
                  {:reductions, later} = Process.info(self(), :reductions)
                  send(parent, {:warned, later - before})
                end,
                [:monitor, min_heap_size: 8_000_000]
              )

            assert_receive {:warned, reductions}, 10_000
            assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
            reductions
          end
        )
      end

      rows = Enum.to_list(0..199)

      one =
        warned.(
          "var_input a bool\nvar e bool[200]\n" <>
            Enum.map_join(rows, "\n", &"xic a ote e[#{&1}]")
        )

      two =
        warned.(
          "var_input a bool\nvar ee bool[200,4]\n" <>
            Enum.map_join(rows, "\n", &"xic a ote ee[#{&1},1]")
        )

      assert (two - one) / 200 <= 36, "one dimension #{one}, two #{two}"
    end
  end

  # Decision 405: a bit's literal number is one more place, so two writes of bits of one
  # word array whose literal numbers differ never meet and are not warned, in one, two and
  # three dimensions, in either order, through tags or beside a literal element's, as a
  # member's bits of two numbers are not (decision 257); and a one-shot's storage bit is
  # judged as a write is, so a write whose literal places differ from it, a subscript or a
  # bit's number, does not write it. Each beside its twin, which may meet, warned as before.
  describe "a bit's number and a storage bit told apart (decision 405)" do
    @later "the last one in the scan decides it"
    @wrong "the one-shot then fires on the wrong scans"
    @words "var_input a bool\nvar_input i int\nvar_input j int\nvar_input k int\n" <>
             "var_input n int\nvar_input m int\nvar w word[4]\nvar e bool[2,4]\n" <>
             "var e1 bool[4]\nvar cube bool[2,3,3]\nvar g word[2,3]\nvar g3 word[2,2,2]\n" <>
             "var lc ctu[2,2]\nvar l1 ctu[3]\nvar_output o bool\nvar_output p bool\n" <>
             "xic w[i].[k] xic e[i,j] xic e1[i] xic cube[i,j,k] xic g[i,j].[k] " <>
             "xic g3[i,j,k].[n] xic lc[i,j].q xic l1[i].q ote o\n"

    defp said(rungs),
      do:
        for(
          {line, message} <- warnings(@words <> rungs),
          String.ends_with?(message, @later) or String.ends_with?(message, @wrong),
          do: {line, message}
        )

    defp array_in(write), do: hd(String.split(write, "["))

    defp may_write(write, symbol \\ "ote"),
      do: [
        {19,
         "`#{write}` is in `#{array_in(write)}`, which the `#{symbol}` on line 18 may write " <>
           "through a tag subscript: " <> @later}
      ]

    defp as_had(write, other),
      do: [
        {19,
         "`#{write}` is in `#{array_in(write)}`, as `#{other}` is, which already has an " <>
           "`ote` on line 18: " <> @later}
      ]

    defp stored(line, symbol, bit, one_shot, at),
      do: [
        {line,
         "`#{symbol}` writes `#{bit}`, the storage bit of the `#{one_shot}` on line #{at}: " <>
           @wrong}
      ]

    test "two bits whose literal numbers differ never meet, in one, two and three dimensions" do
      for {apart, twin, told} <- [
            {"xic a ote w[i].3\nxic a ote w[j].4", "xic a ote w[i].3\nxic a ote w[j].3",
             may_write("w[j].3")},
            {"xic a ote w[i].3\nxic a ote w[1].4", "xic a ote w[i].3\nxic a ote w[1].3",
             may_write("w[1].3")},
            {"xic a ote w[1].4\nxic a ote w[i].3", "xic a ote w[1].3\nxic a ote w[i].3",
             as_had("w[i].3", "w[1].3")},
            {"xic a ote w[i].3\nxic a otl w[j].4", "xic a ote w[i].3\nxic a otl w[j].3",
             may_write("w[j].3")},
            {"xic a otl w[i].3\nxic a ote w[j].4", "xic a otl w[i].3\nxic a ote w[j].3",
             may_write("w[j].3", "otl")},
            {"xic a ote w[i].3\nxic a ote w[j].04", "xic a ote w[i].3\nxic a ote w[j].03",
             may_write("w[j].03")},
            {"xic a ote g[i,j].3\nxic a ote g[k,n].4", "xic a ote g[i,j].3\nxic a ote g[k,n].3",
             may_write("g[k,n].3")},
            {"xic a ote g[1,j].3\nxic a ote g[1,2].4", "xic a ote g[1,j].3\nxic a ote g[1,2].3",
             may_write("g[1,2].3")},
            {"xic a ote g[1,2].4\nxic a ote g[1,j].3", "xic a ote g[1,2].3\nxic a ote g[1,j].3",
             as_had("g[1,j].3", "g[1,2].3")},
            {"xic a ote g3[i,j,k].3\nxic a ote g3[i,j,k].4",
             "xic a ote g3[i,j,k].3\nxic a ote g3[n,m,1].3", may_write("g3[n,m,1].3")},
            {"xic a ote g3[1,j,k].3\nxic a ote g3[1,1,1].4",
             "xic a ote g3[1,j,k].3\nxic a ote g3[1,1,1].3", may_write("g3[1,1,1].3")},
            {"xic a ote g3[1,1,1].4\nxic a ote g3[1,j,k].3",
             "xic a ote g3[1,1,1].3\nxic a ote g3[1,j,k].3",
             as_had("g3[1,j,k].3", "g3[1,1,1].3")},
            {"xic a ote lc[i,j].pv.3\nxic a ote lc[k,n].pv.4",
             "xic a ote lc[i,j].pv.3\nxic a ote lc[k,n].pv.3", may_write("lc[k,n].pv.3")},
            {"xic a ote l1[i].pv.3\nxic a ote l1[j].pv.4",
             "xic a ote l1[i].pv.3\nxic a ote l1[j].pv.3", may_write("l1[j].pv.3")},
            {"xic a ote lc[1,1].pv.4\nxic a ote lc[1,j].pv.3",
             "xic a ote lc[1,1].pv.3\nxic a ote lc[1,j].pv.3",
             as_had("lc[1,j].pv.3", "lc[1,1].pv.3")}
          ] do
        assert {apart, said(apart)} == {apart, []}
        assert {twin, said(twin)} == {twin, told}
      end
    end

    # A bit a tag numbers, and an element written whole, may be any bit of it: each meets a
    # bit of any number, as before.
    test "a bit a tag numbers and an element written whole meet every bit" do
      for {rungs, told} <- [
            {"xic a ote w[i].3\nxic a ote w[j].[n]", may_write("w[j].[n]")},
            {"xic a ote w[i].[n]\nxic a ote w[j].3", may_write("w[j].3")},
            {"xic a ote w[i].3\nmove 5 w[j]", may_write("w[j]")},
            {"xic a ote w[i].3\nmove 5 w[1]", may_write("w[1]")},
            {"xic a ote w[i].[n]\nmove 5 w[1]", may_write("w[1]")},
            {"move 5 w[j]\nxic a ote w[i].3", may_write("w[i].3", "move")},
            {"xic a ote g[i,j].3\nxic a ote g[k,n].[m]", may_write("g[k,n].[m]")},
            {"xic a ote g[i,j].3\nmove 5 g[k,n]", may_write("g[k,n]")},
            {"xic a ote g[1,j].3\nmove 5 g[1,2]", may_write("g[1,2]")}
          ] do
        assert {rungs, said(rungs)} == {rungs, told}
      end

      assert said("xic a ote g[1,j].3\nmove 5 g[0,2]") == []
    end

    test "a storage bit is judged as a write is, a bit's number among its places" do
      for {apart, twin, told} <- [
            {"xic a ons e[1,1] ote p\nxic a ote e[i,0]",
             "xic a ons e[1,1] ote p\nxic a ote e[i,1]", stored(19, "ote", "e[1,1]", "ons", 18)},
            {"xic a ote e[i,0]\nxic a ons e[1,1] ote p",
             "xic a ote e[i,1]\nxic a ons e[1,1] ote p", stored(18, "ote", "e[1,1]", "ons", 19)},
            {"xic a ons e[1,1] ote p\nxic a ote e[0,i]",
             "xic a ons e[1,1] ote p\nxic a ote e[1,i]", stored(19, "ote", "e[1,1]", "ons", 18)},
            {"xic a ons e[1,1] ote p\nxic a otu e[i,0]",
             "xic a ons e[1,1] ote p\nxic a otl e[i,1]", stored(19, "otl", "e[1,1]", "ons", 18)},
            {"xic a osr e[1,1] p\nxic a ote e[i,0]", "xic a osf e[1,1] p\nxic a ote e[i,1]",
             stored(19, "ote", "e[1,1]", "osf", 18)},
            {"xic a ons cube[1,1,1] ote p\nxic a ote cube[i,1,0]",
             "xic a ons cube[1,1,1] ote p\nxic a ote cube[i,1,1]",
             stored(19, "ote", "cube[1,1,1]", "ons", 18)},
            {"xic a ons cube[1,1,1] ote p\nxic a ote cube[0,j,k]",
             "xic a ons cube[1,1,1] ote p\nxic a ote cube[i,j,k]",
             stored(19, "ote", "cube[1,1,1]", "ons", 18)},
            {"xic a ons w[1].3 ote p\nxic a ote w[i].4",
             "xic a ons w[1].3 ote p\nxic a ote w[i].3", stored(19, "ote", "w[1].3", "ons", 18)},
            {"xic a ons w[1].3 ote p\nxic a ote w[i].04",
             "xic a ons w[1].3 ote p\nxic a ote w[i].[n]",
             stored(19, "ote", "w[1].3", "ons", 18)},
            {"xic a ons g[1,1].3 ote p\nxic a ote g[i,1].4",
             "xic a ons g[1,1].3 ote p\nxic a ote g[i,1].3",
             stored(19, "ote", "g[1,1].3", "ons", 18)},
            {"xic a ons g[1,1].3 ote p\nxic a ote g[i,0].3",
             "xic a ons g[1,1].3 ote p\nxic a ote g[i,j].3",
             stored(19, "ote", "g[1,1].3", "ons", 18)},
            {"xic a ons g[1,1].3 ote p\nmove 5 g[i,0]", "xic a ons g[1,1].3 ote p\nmove 5 g[i,1]",
             stored(19, "move", "g[1,1].3", "ons", 18)},
            {"xic a ons g3[1,1,1].3 ote p\nxic a ote g3[i,1,1].4",
             "xic a ons g3[1,1,1].3 ote p\nxic a ote g3[i,1,1].3",
             stored(19, "ote", "g3[1,1,1].3", "ons", 18)},
            {"xic a ons g3[1,1,1].3 ote p\nxic a ote g3[i,0,1].3",
             "xic a ons g3[1,1,1].3 ote p\nmove 5 g3[i,j,1]",
             stored(19, "move", "g3[1,1,1].3", "ons", 18)}
          ] do
        assert {apart, said(apart)} == {apart, []}
        assert {twin, said(twin)} == {twin, told}
      end

      # In one dimension a tag subscript meets every element, and an element written whole
      # every bit of it, as before.
      for {rungs, told} <- [
            {"xic a ons e1[1] ote p\nxic a ote e1[i]", stored(19, "ote", "e1[1]", "ons", 18)},
            {"xic a ons w[1].3 ote p\nmove 5 w[i]", stored(19, "move", "w[1].3", "ons", 18)}
          ] do
        assert {rungs, said(rungs)} == {rungs, told}
      end
    end

    # RV-12's review: a write through a tag subscript that meets several storage bits is
    # told of each in name order, whatever order their one-shots come in, as before
    # decision 405 (RV-2, a4-warnings-walk-3).
    test "a write that meets several storage bits is told of each in name order" do
      for {rungs, bits, line, at} <- [
            {"xic a ons e[1,0] ote p\nxic a ons e[0,0]\nxic a ote e[i,0]", ["e[0,0]", "e[1,0]"],
             20, %{"e[0,0]" => 19, "e[1,0]" => 18}},
            {"xic a ote e[i,0]\nxic a ons e[1,0] ote p\nxic a ons e[0,0]", ["e[0,0]", "e[1,0]"],
             18, %{"e[0,0]" => 20, "e[1,0]" => 19}},
            {"xic a ons w[2].3 ote p\nxic a ons w[1].3\nxic a ote w[i].3", ["w[1].3", "w[2].3"],
             20, %{"w[1].3" => 19, "w[2].3" => 18}},
            {"xic a ons e1[3] ote p\nxic a ons e1[0]\nxic a ons e1[2]\nxic a ote e1[i]",
             ["e1[0]", "e1[2]", "e1[3]"], 21, %{"e1[0]" => 19, "e1[2]" => 20, "e1[3]" => 18}}
          ] do
        told = Enum.flat_map(bits, &stored(line, "ote", &1, "ons", Map.fetch!(at, &1)))
        assert {rungs, said(rungs)} == {rungs, told}
      end
    end
  end

  describe "a member's bit through a tag subscript or numbered by a tag (decision 431)" do
    @members "var_input a bool\nvar_input i int\nvar_input j int\nvar_input k int\n" <>
               "var_input n int\nvar_input m int\nvar l1 ctu[3]\nvar lc ctu[2,2]\n" <>
               "var l3 ctu[2,2,2]\nvar t ton[3]\nvar w word[3]\nvar g word[2,2]\n" <>
               "var h word[2,2,2]\nvar p bool\nvar q bool\nvar_output o bool\n" <>
               "xic l1[i].q xic lc[i,j].q xic l3[i,j,k].q xic t[i].dn xic w[i].[n] " <>
               "xic g[i,j].[n] xic h[i,j,k].[n] xic p xic q ote o\n"
    @may_share "the last one in the scan decides it"

    # The may-share warnings of two rungs after the head, at lines 18 and 19.
    defp shared(rungs, head \\ @members),
      do:
        for(
          {line, message} <- warnings(head <> rungs),
          String.ends_with?(message, @may_share),
          do: {line, message}
        )

    defp member_array(write),
      do: write |> String.split(" ") |> List.last() |> String.split("[") |> hd()

    defp written(write), do: write |> String.split(" ") |> List.last()

    defp tagged(write, first),
      do: [
        {19,
         "`#{written(write)}` is in `#{member_array(write)}`, which the `#{symbol(first)}` on line 18 " <>
           "may write through a tag subscript: " <> @may_share}
      ]

    defp beside(write, first),
      do: [
        {19,
         "`#{written(write)}` is in `#{member_array(write)}`, as `#{written(first)}` is, " <>
           what(first) <> " on line 18: " <> @may_share}
      ]

    defp symbol(write), do: write |> String.split(" ") |> hd()

    defp what("move" <> _ = _first), do: "which the `move`"
    defp what(_coil), do: "which already has an `ote`"

    # `what/1` names a coil's first as having an `ote`, a move's as writing whole.
    defp beside_whole(write, first),
      do: [
        {19,
         "`#{written(write)}` is in `#{member_array(write)}`, as `#{written(first)}` is, which the " <>
           "`move` on line 18 writes whole: " <> @may_share}
      ]

    # A literal bit's latch first, which writes the bit, as decision 257 tells it.
    defp beside_latch(write, first),
      do: [
        {19,
         "`#{written(write)}` is in `#{member_array(write)}`, as `#{written(first)}` is, which the " <>
           "`#{symbol(first)}` on line 18 writes: " <> @may_share}
      ]

    # Each pair `{first, then}`: the second write told as a word array's is, where the pair
    # may meet. RV-12's question 3's forms first, in one dimension, each both ways; then two
    # dimensions and three, a timer's members, the coil through the very tags, another
    # write through a tag subscript, a literal bit's latch, which decision 257 compares
    # with a coil through a tag subscript (provisional, beside a bit a tag numbers), and a
    # literal bit beside a word written whole through a tag subscript, the one pair beyond
    # question 3's list a tag subscript reaches.
    test "every form a tag reaches is warned where the pair may meet, either way" do
      for {first, then, told} <- [
            {"ote l1[i].pv.3", "ote l1[j].pv.[n]", &tagged/2},
            {"ote l1[j].pv.[n]", "ote l1[i].pv.3", &tagged/2},
            {"ote l1[1].pv.[n]", "ote l1[i].pv.3", &beside/2},
            {"ote l1[i].pv.3", "ote l1[1].pv.[n]", &tagged/2},
            {"ote l1[1].pv.[n]", "move 5 l1[i].pv", &beside/2},
            {"move 5 l1[i].pv", "ote l1[1].pv.[n]", &tagged/2},
            {"ote l1[i].pv.[n]", "ote l1[1].pv.[n]", &tagged/2},
            {"ote l1[1].pv.[n]", "ote l1[i].pv.[n]", &beside/2},
            {"ote l1[i].pv.[n]", "ote l1[j].pv.[n]", &tagged/2},
            {"ote l1[i].pv.[n]", "ote l1[1].pv.3", &tagged/2},
            {"ote l1[1].pv.3", "ote l1[i].pv.[n]", &beside/2},
            {"ote l1[i].pv.[n]", "move 5 l1[1].pv", &tagged/2},
            {"move 5 l1[1].pv", "ote l1[i].pv.[n]", &beside_whole/2},
            {"ote l1[i].pv.[n]", "move 5 l1[j].pv", &tagged/2},
            {"move 5 l1[j].pv", "ote l1[i].pv.[n]", &tagged/2},
            {"ote l1[1].pv.3", "move 5 l1[i].pv", &beside/2},
            {"move 5 l1[i].pv", "ote l1[1].pv.3", &tagged/2},
            {"ote lc[i,0].pv.3", "ote lc[j,0].pv.[n]", &tagged/2},
            {"ote lc[1,0].pv.[n]", "ote lc[i,0].pv.3", &beside/2},
            {"ote lc[i,0].pv.[n]", "ote lc[1,0].pv.3", &tagged/2},
            {"ote lc[i,0].pv.[n]", "move 5 lc[j,0].pv", &tagged/2},
            {"ote lc[1,j].pv.[n]", "ote lc[i,1].pv.[m]", &tagged/2},
            {"ote lc[1,1].pv.[n]", "ote lc[i,1].pv.[m]", &beside/2},
            {"ote l3[i,0,1].pv.[n]", "ote l3[1,0,1].pv.3", &tagged/2},
            {"ote l3[1,0,1].pv.[n]", "ote l3[i,0,k].pv.4", &beside/2},
            {"ote l3[1,j,1].pv.[n]", "ote l3[i,0,k].pv.4", &tagged/2},
            {"ote l3[i,j,k].pv.[n]", "move 5 l3[0,1,1].pv", &tagged/2},
            {"ote t[i].pre.[n]", "ote t[1].pre.3", &tagged/2},
            {"ote t[1].acc.[n]", "ote t[i].acc.2", &beside/2},
            {"otl l1[i].pv.[n]", "ote l1[1].pv.3", &tagged/2},
            {"ote l1[i].pv.[n]", "otl l1[1].pv.3", &tagged/2},
            {"otl l1[1].pv.3", "ote l1[i].pv.[n]", &beside_latch/2},
            {"ote l1[1].pv.[n]", "otu l1[i].pv.[m]", &beside/2}
          ] do
        rungs = "xic a #{first}\nxic a #{then}"
        assert {rungs, shared(rungs)} == {rungs, told.(then, first)}
      end

      assert shared("xic a ote l1[i].pv.[n]\nxic a ote l1[i].pv.[n]") == [
               {19, "`l1[i].pv.[n]` already has an `ote` on line 18: " <> @may_share}
             ]
    end

    # Each pair whose literal places differ, an element's or a bit's, and each pair of
    # another member's word, never meets and is not warned; nor is a coil beside another
    # write through the very tags (decision 246).
    test "a pair whose literal places differ stays quiet" do
      for rungs <- [
            "xic a ote l1[1].pv.[n]\nxic a ote l1[2].pv.3",
            "xic a ote l1[2].pv.3\nxic a ote l1[1].pv.[n]",
            "xic a ote l1[1].pv.[n]\nxic a ote l1[0].pv.[m]",
            "xic a ote l1[1].pv.[n]\nmove 5 l1[2].pv",
            "move 5 l1[2].pv\nxic a ote l1[1].pv.[n]",
            "xic a ote l1[i].pv.3\nxic a ote l1[1].pv.4",
            "xic a ote lc[i,0].pv.[n]\nxic a ote lc[j,1].pv.3",
            "xic a ote lc[1,0].pv.[n]\nxic a ote lc[i,1].pv.3",
            "xic a ote lc[i,0].pv.[n]\nmove 5 lc[j,1].pv",
            "xic a ote lc[1,j].pv.[n]\nxic a ote lc[0,i].pv.[m]",
            "xic a ote l3[i,0,1].pv.[n]\nxic a ote l3[j,1,1].pv.3",
            "xic a ote l3[1,j,k].pv.[n]\nxic a ote l3[0,i,k].pv.[m]",
            "xic a ote t[i].pre.[n]\nxic a ote t[j].acc.3",
            "xic a ote t[i].pre.[n]\nxic a ote t[j].acc.[n]",
            "xic a ote l1[i].pv.[n]\nxic a otl l1[i].pv.[n]",
            "xic a otl l1[i].pv.[n]\nxic a ote l1[i].pv.[n]"
          ] do
        assert {rungs, shared(rungs)} == {rungs, []}
      end
    end

    # Decision 431's words, "judged as a word array's bit is", restated as an oracle: every
    # pair of a coil, a pulse coil on a literal bit, a word written whole and a latch of a
    # bit a tag numbers, over a member's word of an array of counters and over a word
    # array of its shape, in one dimension and two, is told the same, names mapped, but for
    # the two the member rules held before: a literal bit's latch, which decision 257
    # compares with a coil through a tag subscript and a word array's rules do not, and a
    # literal bit's coil and the word written whole through the very tags, which decision
    # 288 leaves quiet.
    test "a member's word is judged as a word array of its shape is, every pair" do
      reached =
        for {member, word, subscripts} <- [
              {"l1", "w", ["1", "0", "i", "j"]},
              {"lc", "g", ["1,0", "0,1", "i,0", "j,1", "1,j"]}
            ],
            first <- writes(subscripts),
            then <- writes(subscripts),
            reduce: %{} do
          reached ->
            on_word = shared(pair(first, then, word, ""))
            on_member = shared(pair(first, then, member, ".pv"))

            mapped = Enum.map(on_member, &named_as(&1, member, word))
            Map.update(reached, judged(first, then, on_word, mapped), 1, &(&1 + 1))
        end

      assert Map.keys(reached) -- [:same, :latch_257, :very_288] == []
      assert reached[:same] > 1500 and reached[:latch_257] > 0 and reached[:very_288] > 0
    end

    defp writes(subscripts),
      do:
        for(s <- subscripts, b <- ["3", "4", "[n]", "[m]"], do: {"ote", s, b}) ++
          for(s <- subscripts, do: {"move 5", s, nil}) ++
          for(s <- subscripts, b <- ["[n]", "3"], do: {"otl", s, b}) ++
          for(
            s <- Enum.filter(subscripts, &(not String.contains?(&1, ["i", "j"]))),
            do: {"osr p", s, "3"}
          )

    # Two rungs, the second's pulse coil keeping its storage bit in `q`, the first's in `p`.
    defp pair(first, then, array, suffix),
      do:
        "xic a #{written(first, array, suffix)}\nxic a " <>
          String.replace(written(then, array, suffix), "osr p ", "osr q ")

    defp written({symbol, s, nil}, array, suffix), do: "#{symbol} #{array}[#{s}]#{suffix}"
    defp written({symbol, s, bit}, array, suffix), do: "#{symbol} #{array}[#{s}]#{suffix}.#{bit}"

    defp named_as({line, message}, member, word),
      do:
        {line,
         message
         |> String.replace(~r/#{member}\[([^\]]*)\]\.pv/, "#{word}[\\1]")
         |> String.replace("`#{member}`", "`#{word}`")}

    defp judged(_first, _then, same, same), do: :same

    defp judged({"otl", first, "3"}, {"ote", _then, _bits}, [], [_told]),
      do: literal_latch(String.contains?(first, ["i", "j"]))

    defp judged({"ote", _first, _bits}, {"otl", then, "3"}, [], [_told]),
      do: literal_latch(String.contains?(then, ["i", "j"]))

    defp judged({"ote", first, bit}, {"move 5", first, nil}, [_told], [])
         when bit in ["3", "4"],
         do: very_tags(String.contains?(first, ["i", "j"]))

    defp judged({"move 5", then, nil}, {"ote", then, bit}, [_told], [])
         when bit in ["3", "4"],
         do: very_tags(String.contains?(then, ["i", "j"]))

    defp judged(first, then, on_word, on_member), do: {:differs, first, then, on_word, on_member}

    defp literal_latch(false), do: :latch_257
    defp literal_latch(true), do: :differs_latch

    defp very_tags(true), do: :very_288
    defp very_tags(false), do: :differs_very

    # Where several writes may meet a later one, it is told of one, in a word array's
    # order: a coil through a tag subscript before a coil on a literal element, which comes
    # before another write through a tag subscript, which comes before another write of a
    # literal element, each kind's earliest.
    test "of several writes a later one may meet, it is told the one a word array's would be" do
      for writes <- [
            ["ote X[1].[n]", "ote X[j].[m]", "ote X[i].[n]"],
            ["ote X[j].[m]", "ote X[1].[n]", "ote X[i].[n]"],
            ["ote X[1].[n]", "otl X[j].[m]", "ote X[i].[n]"],
            ["move 5 X[1]", "otl X[j].[m]", "ote X[i].[n]"],
            ["otl X[j].[m]", "move 5 X[1]", "ote X[i].[n]"],
            ["ote X[1].3", "ote X[j].[m]", "move 5 X[i]"]
          ] do
        on_word = shared(Enum.map_join(writes, "\n", &("xic a " <> String.replace(&1, "X", "w"))))

        on_member =
          writes
          |> Enum.map_join(
            "\n",
            &("xic a " <> Regex.replace(~r/X\[([^\]]*)\]/, &1, "l1[\\1].pv"))
          )
          |> shared()
          |> Enum.map(&named_as(&1, "l1", "w"))

        assert {writes, on_member} == {writes, on_word}
        assert [_told] = for({20, _message} = told <- on_word, do: told)
      end
    end

    # A bit a tag numbers beside its word written whole through the very tags is warned,
    # either first, as a word array's is (provisional), where a literal bit beside it stays
    # quiet, as decision 288 has it and a word array's does not.
    test "a bit a tag numbers beside its word written whole through the very tags is warned (provisional)" do
      assert shared("xic a ote l1[i].pv.[n]\nmove 5 l1[i].pv") == [
               {19,
                "`l1[i].pv` is in `l1`, which the `ote` on line 18 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]

      assert shared("move 5 l1[i].pv\nxic a ote l1[i].pv.[n]") == [
               {19,
                "`l1[i].pv.[n]` is in `l1`, which the `move` on line 18 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]

      assert shared("xic a ote l1[i].pv.3\nmove 5 l1[i].pv") == []

      assert shared("xic a ote w[i].3\nmove 5 w[i]") == [
               {19,
                "`w[i]` is in `w`, which the `ote` on line 18 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]
    end

    # Each pair is told on its own (provisional): a write a member rule warns of a literal
    # element's bit is told too of a write through a tag subscript that numbers a bit, two
    # warnings on its line, where a word array's write is told of one.
    test "a write a member rule warns is told too of a pair a tag reaches (provisional)" do
      assert shared("xic a ote l1[1].pv.3\nxic a ote l1[i].pv.[n]\nxic a ote l1[i].pv.3") == [
               {19,
                "`l1[i].pv.[n]` is in `l1`, as `l1[1].pv.3` is, which already has an `ote` on " <>
                  "line 18: " <> @may_share},
               {20,
                "`l1[i].pv.3` is in `l1`, as `l1[1].pv.3` is, which already has an `ote` on " <>
                  "line 18: " <> @may_share},
               {20,
                "`l1[i].pv.3` is in `l1`, which the `ote` on line 19 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]

      assert shared("xic a ote w[1].3\nxic a ote w[i].[n]\nxic a ote w[i].3") == [
               {19,
                "`w[i].[n]` is in `w`, as `w[1].3` is, which already has an `ote` on line 18: " <>
                  @may_share},
               {20,
                "`w[i].3` is in `w`, which the `ote` on line 19 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]
    end

    # A one-shot keeps no storage bit in a member's word, so no write of one meets a
    # one-shot's storage bit: beside every form a tag reaches, a word array's storage bit
    # is told only where a write of the word array meets it (decision 405).
    test "no write of a member's word meets a one-shot's storage bit" do
      rungs =
        "xic a ons w[1].3 ote p\nxic a ote l1[i].pv.[n]\nxic a ote l1[1].pv.[n]\n" <>
          "move 5 l1[i].pv\nxic a ote lc[i,0].pv.3\nxic a ote w[i].3"

      assert for(
               {line, message} <- warnings(@members <> rungs),
               message =~ "storage bit",
               do: {line, message}
             ) == [
               {23,
                "`ote` writes `w[1].3`, the storage bit of the `ons` on line 18: the one-shot " <>
                  "then fires on the wrong scans"}
             ]

      for operand <- ["l1[1].pv.3", "l1[i].pv.3", "l1[i].pv.[n]", "lc[1,0].pv.[n]"] do
        assert [{18, message}] = messages(@members <> "xic a ons #{operand} ote p")
        assert message =~ "`ons` keeps its storage bit in "
      end
    end

    # Members at depth: a block's own array of counters is judged in its body as a
    # program's is, and so in each block an array of blocks holds.
    test "in a block's body, as in a program" do
      block =
        "function_block lane\nvar_input a bool\nvar_input i int\nvar_input n int\n" <>
          "var l1 ctu[3]\nvar_output o bool\nxic l1[i].q ote o\n" <>
          "xic a ote l1[i].pv.[n]\nxic a ote l1[1].pv.3\nxic a ote l1[2].pv.[n]"

      assert {:ok, %Logex.FbType{} = lane} = Logex.compile(block, name: "lane")

      assert for(
               %{line: line, message: message} <- lane.body.warnings,
               String.ends_with?(message, @may_share),
               do: {line, message}
             ) == [
               {9,
                "`l1[1].pv.3` is in `l1`, which the `ote` on line 8 may write through a tag " <>
                  "subscript: " <> @may_share},
               {10,
                "`l1[2].pv.[n]` is in `l1`, which the `ote` on line 8 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]

      held =
        "var_input a bool\nvar_input i int\nvar_input n int\nvar lanes lane[4]\n" <>
          "var_output o bool\ncal lanes[0] a i n o"

      assert {:ok, program} = Logex.compile(held, name: "p", types: [lane])
      assert program.blocks["lane"].body.warnings == lane.body.warnings
    end

    # RV-15's review: a member's write of several firsts was told fewer than a word array's
    # write, or a later first, its own lookups stopping at the first that found one. Each
    # is now told every first a word array's write would be told: a coil on a literal
    # element both of a coil through a tag subscript and of another write through one, as
    # a word array's is, in programs of decision 253's forms alone too, each kind's
    # earliest; and where a member rule tells a pair too, its own beside them (question 2).
    test "of several writes, a member's write is told every first a word array's is" do
      for writes <- [
            ["ote X[i].3", "otl X[j].4", "ote X[0].[n]"],
            ["ote X[0].4", "ote X[i].3", "otl X[i].3", "ote X[1].3"],
            ["ote X[i].3", "ote X[j].[m]", "ote X[1].[n]"],
            ["ote X[i].[n]", "move 5 X[j]", "otl X[j].[m]", "ote X[1].[n]"]
          ] do
        assert {writes, several(writes, "l1", ".pv")} == {writes, several(writes, "w", "")}
      end

      assert shared(
               Enum.map_join(
                 ["ote w[i].3", "otl w[j].4", "ote w[0].[n]"],
                 "\n",
                 &("xic a " <> &1)
               )
             ) ==
               [
                 {20,
                  "`w[0].[n]` is in `w`, which the `ote` on line 18 may write through a tag " <>
                    "subscript: " <> @may_share},
                 {20,
                  "`w[0].[n]` is in `w`, which the `otl` on line 19 may write through a tag " <>
                    "subscript: " <> @may_share}
               ]

      writes = ["ote X[i,i].[n]", "move 5 X[j,i]", "otu X[j,i].3", "ote X[1,0].3"]
      on_word = several(writes, "g", "")
      on_member = several(writes, "lc", ".pv")

      assert on_member -- on_word == [
               {21,
                "`g[1,0].3` is in `g`, which the `otu` on line 20 may write through a tag " <>
                  "subscript: " <> @may_share}
             ]

      assert on_word -- on_member == []
    end

    # The writes on rungs from line 18, `X` an array's name, each told as on `array`,
    # its member's words named as a word array's.
    defp several(writes, array, suffix),
      do:
        writes
        |> Enum.map_join(
          "\n",
          &("xic a " <> Regex.replace(~r/X\[([^\]]*)\]/, &1, "#{array}[\\1]#{suffix}"))
        )
        |> shared()
        |> Enum.map(&named_as(&1, array, word_of(array)))

    defp word_of("l1"), do: "w"
    defp word_of("lc"), do: "g"
    defp word_of(word), do: word

    # RV-15's review, restated as an oracle over programs drawn at random, of three to six
    # writes of a member's word, a coil, a latch or an unlatch of a literal bit or one a
    # tag numbers, or the word written whole, each element's subscripts literal or tags, in
    # one dimension and two: each warning a word array of the member's shape is told, the
    # member's write is told, names mapped, but where decision 288 leaves a literal bit
    # beside its word written whole through the very tags quiet, and every warning the
    # member's write is told cites a write that may meet it. Those it is told beyond a word
    # array's are a member rule's own (question 2).
    test "of programs of several writes, every warning a word array's is told, each of writes that may meet" do
      :rand.seed(:exsss, {431, 15, 2026})

      tally =
        for _program <- 1..400, reduce: %{} do
          tally ->
            {array, writes} = drawn()
            Process.put(:dbg, writes)
            source = Enum.map_join(writes, "\n", &"xic a #{text(&1, array, ".pv")}")
            word = Enum.map_join(writes, "\n", &"xic a #{text(&1, word_of(array), "")}")
            on_member = Enum.map(shared(source), &named_as(&1, array, word_of(array)))
            on_word = shared(word)

            assert {source, Enum.reject(on_member, &cites_a_meeting?(&1, writes))} == {source, []}

            Map.update(
              tally,
              told(on_word -- on_member, on_member -- on_word, writes),
              1,
              &(&1 + 1)
            )
        end

      assert Map.keys(tally) -- [:same, :more, :very_288] == []
      assert tally[:same] > 200 and tally[:more] > 0 and tally[:very_288] > 0
    end

    defp drawn,
      do:
        {Enum.random(["l1", "lc"]), for(_write <- 1..Enum.random(3..6), do: write())}
        |> dimensioned()

    defp dimensioned({"l1", writes}), do: {"l1", Enum.map(writes, &at([&1]))}

    defp dimensioned({"lc", writes}),
      do: {"lc", Enum.map(writes, &at([&1, Enum.random(["0", "1", "i"])]))}

    defp write,
      do: {Enum.random(["0", "1", "i", "j"]), Enum.random(["3", "4", "[n]", "[m]", nil])}

    defp at([{first, bit} | rest]), do: {drawn_symbol(bit), [first | rest], bit}

    defp drawn_symbol(nil), do: "move 5"
    defp drawn_symbol(_bit), do: Enum.random(["ote", "ote", "otl", "otu"])

    defp text({symbol, subscripts, nil}, array, suffix),
      do: "#{symbol} #{array}[#{Enum.join(subscripts, ",")}]#{suffix}"

    defp text({symbol, subscripts, bit}, array, suffix),
      do: "#{symbol} #{array}[#{Enum.join(subscripts, ",")}]#{suffix}.#{bit}"

    defp told([], [], _writes), do: :same
    defp told([], [_ | _], _writes), do: :more

    defp told(missing, _more, writes),
      do: very(Enum.any?(writes, &very_288?(&1, writes)), missing)

    defp very(true, _missing), do: :very_288
    defp very(false, missing), do: {:missing, missing, Process.get(:dbg)}

    # A coil on a literal bit through tag subscripts, and its word written whole through
    # the very tags.
    defp very_288?({"ote", subscripts, bit}, writes) when bit in ["3", "4"],
      do: Enum.any?(subscripts, &tag?/1) and {"move 5", subscripts, nil} in writes

    defp very_288?(_write, _writes), do: false

    defp tag?(subscript), do: subscript in ["i", "j", "[n]", "[m]"]

    defp cites_a_meeting?({line, message}, writes),
      do:
        meeting?(
          Enum.at(writes, line - 18),
          Enum.at(writes, cited(Regex.run(~r/on line (\d+)/, message)) - 18)
        )

    defp cited([_, line]), do: String.to_integer(line)

    defp meeting?({_, subscripts, bit}, {_, others, other}),
      do: Enum.all?(Enum.zip([bit | subscripts], [other | others]), &meets?/1)

    defp meets?({same, same}), do: true
    defp meets?({nil, _other}), do: true
    defp meets?({_bit, nil}), do: true
    defp meets?({one, other}), do: tag?(one) or tag?(other)

    # Decision 431: a member's word is judged as a word array of its shape is only where
    # its array is declared in source; one declared from Elixir is warned of nothing, as no
    # tag declared from Elixir is (RV-15's review).
    test "an array of counters declared from Elixir is warned of nothing" do
      declared = [Logex.Tag.new!("l1", {:array, Logex.FbType.builtin("ctu"), [3]}, :var)]
      head = "var_input a bool\nvar_input i int\nvar_input j int\nvar_input n int\n"

      for rungs <- [
            "xic a ote l1[i].pv.[n]\nxic a ote l1[1].pv.3\nxic a ote l1[j].pv.4",
            "xic a ote l1[i].pv.3\nxic a ote l1[j].pv.3\nmove 5 l1[i].pv\nxic a ote l1[1].pv.[n]",
            "xic a ote l1[1].pv.[n]\nmove 5 l1[i].pv\nxic a otl l1[j].pv.[n]"
          ] do
        assert [_ | _] = warnings("var l1 ctu[3]\n" <> head <> rungs)
        {:ok, tokens, _end} = Logex.Lexer.tokenize(head <> rungs)
        {:ok, tree} = Logex.Parser.parse(tokens)
        assert {:ok, program} = Logex.Compiler.instructionize(tree, declared)

        assert for(%{message: message} <- program.warnings, message =~ "decides it", do: message) ==
                 []
      end
    end

    # RV-15's review, finding 4: a literal bit's latch beside a coil a tag numbers of its
    # own literal element, `otl l1[1].pv.3` beside `ote l1[1].pv.[n]`, either first, is
    # quiet, as a word array's is, where beside one through a tag subscript, `ote
    # l1[i].pv.[n]`, it is warned, as decision 257 warns it beside `ote l1[i].pv.3`
    # (provisional, question 1).
    test "a literal bit's latch beside a coil a tag numbers of its own element is quiet (provisional)" do
      for rungs <- [
            "xic a otl l1[1].pv.3\nxic a ote l1[1].pv.[n]",
            "xic a ote l1[1].pv.[n]\nxic a otl l1[1].pv.3",
            "xic a otl w[1].3\nxic a ote w[1].[n]",
            "xic a ote w[1].[n]\nxic a otl w[1].3",
            "xic a otl w[1].3\nxic a ote w[i].[n]"
          ] do
        assert {rungs, shared(rungs)} == {rungs, []}
      end

      assert shared("xic a otl l1[1].pv.3\nxic a ote l1[i].pv.[n]") ==
               beside_latch("ote l1[i].pv.[n]", "otl l1[1].pv.3")

      # So where the member's word is judged as a word array, a write through a tag
      # subscript beside them: the latch is told nothing of the coil, as a word array's is.
      for writes <- [
            ["move 5 X[j]", "ote X[1].[n]", "otl X[1].3"],
            ["move 5 X[j]", "otl X[1].3", "ote X[1].[n]"]
          ] do
        assert {writes, several(writes, "l1", ".pv")} == {writes, several(writes, "w", "")}
        assert [{_line, _move}] = several(writes, "w", "")
      end
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

    # Decision 239, superseding decision 236's provisional reading: an instance that writes
    # several elements beside one other writer is told once, the elements named together in
    # the elements' order, ten and then a count.
    test "an instance writing several elements beside a write through a tag subscript is told once" do
      writes = fn elements ->
        {:ok, program} =
          Logex.compile(
            "var_external speeds int[16]\nvar_input s int\n" <>
              Enum.map_join(elements, "\n", &"move s speeds[#{&1}]"),
            name: "many"
          )

        program
      end

      {:ok, feeder} =
        Logex.compile(
          "var_external speeds int[16]\nvar_external slot int\nvar_input s int\nmove s speeds[slot]",
          name: "feeder"
        )

      told = fn elements ->
        {:ok, config} =
          Logex.Configuration.compile(
            "plant",
            "var_global speeds int[16]\nvar_global slot int\nvar_global s int\n" <>
              "program f1 feeder\nf1.s s\nprogram t1 many\nt1.s s",
            %{"feeder" => feeder, "many" => writes.(elements)}
          )

        Enum.map(config.warnings, &{&1.line, &1.message})
      end

      as_f1 = " through its var_external, as `f1` may (line 4): #{@stands}"

      assert told.([2, 1]) == [{6, "`t1` writes `speeds[1]` and `speeds[2]`" <> as_f1}]

      assert told.([3, 1, 2]) == [
               {6, "`t1` writes `speeds[1]`, `speeds[2]` and `speeds[3]`" <> as_f1}
             ]

      assert told.([5]) == [{6, "`t1` writes `speeds[5]`" <> as_f1}]

      ten = Enum.map_join(0..8, ", ", &"`speeds[#{&1}]`") <> " and `speeds[9]`"
      assert told.(Enum.to_list(0..9)) == [{6, "`t1` writes " <> ten <> as_f1}]

      # In the elements' order, `speeds[10]` after `speeds[9]`, and past ten a count.
      first_ten = Enum.map_join(0..9, ", ", &"`speeds[#{&1}]`")

      assert told.(Enum.to_list(11..0//-1)) == [
               {6, "`t1` writes " <> first_ten <> " and 2 more" <> as_f1}
             ]

      assert told.(Enum.to_list(0..10)) == [
               {6, "`t1` writes " <> first_ten <> " and 1 more" <> as_f1}
             ]
    end

    # Decision 239 (provisional for this case, which the question did not ask): two
    # instances that write the same elements, neither through a tag subscript, are told
    # once too, the later naming them together.
    test "an instance writing the elements another writes is told once, naming them" do
      {:ok, two} =
        Logex.compile(
          "var_external speeds int[4]\nvar_input s int\nmove s speeds[1]\nmove s speeds[3]",
          name: "two"
        )

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          "var_global speeds int[4]\nvar_global s int\nprogram t1 two\nt1.s s\n" <>
            "program t2 two\nt2.s s",
          %{"two" => two}
        )

      assert Enum.map(config.warnings, &{&1.line, &1.message}) == [
               {5,
                "`t2` writes `speeds[1]` and `speeds[3]` through its var_external, as `t1` does " <>
                  "(line 3): #{@stands}"}
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
        # Pinned as exactly 5 more until decision 357; a bound since, with half a reduction
        # for the hundredths a rung's count moves, so that the subscript's read made cheaper
        # holds it too.
        assert t <= l + 5.5, "#{tagged} took #{t} a rung, #{literal} #{l}"
      end
    end

    # A program with no tag subscript runs no catch, as before M5-12 (`e00ae03`): an
    # instruction is caught only where its clause's head sees an element a tag subscripts
    # among its operands, a bit of one among them, and one on a bit a tag numbers, or a
    # `cal`, is caught once, as it was. A catch costs a reduction. Since decision 357 each
    # rung is held against one measured in the same run that differs from it in that catch
    # alone, where the exact figures it took at `e00ae03` were pinned (34, 16, 17, 18, 23,
    # 27 and 35 a rung, a `cal` 178.01): on a de-energised rung no operand is read, so an
    # element a tag subscripts costs one reduction more than a literal one or a bool, and a
    # bit a tag numbers, or a `cal` in a contact's place, what it does. A catch where none
    # is due makes a pair cost the same; a reduction more for a call both rungs of a pair
    # make moves both. Each bound leaves half a reduction a rung for the hundredths by which
    # a rung's count moves as the bigger program's maps grow, under the one a catch costs.
    test "a program of none is caught nowhere, as before M5-12, a tag's bit and a `cal` once" do
      head =
        fixed(
          "var off bool\nvar_input a bool\nvar_input i int\nvar_input k int\n" <>
            "var_input w word\nvar_input n int\nvar e bool[8]\nvar v int[8]\nvar g int[4,8]\n" <>
            "var h word[8]\nvar_output q bool\nvar_output d int\n"
        )

      caught = per_rung(head, fixed("xic off xic e[i] ote q"))

      for {plain, tagged} <- [
            {"xic off xic a ote q", "xic off xic e[i] ote q"},
            {"xic off xic e[3] ote q", "xic off xic e[i] ote q"},
            {"xic off move v[3] d", "xic off move v[i] d"},
            {"xic off move k v[3]", "xic off move k v[i]"},
            {"xic off move g[1,3] d", "xic off move g[1,i] d"},
            {"xic off xic h[1].3 ote q", "xic off xic h[i].3 ote q"}
          ] do
        {p, t} = {per_rung(head, fixed(plain)), per_rung(head, fixed(tagged))}
        assert p <= t - 0.5, "`#{plain}` took #{p} a rung, as caught as `#{tagged}`, #{t}"
      end

      tag_bit = per_rung(head, fixed("xic off xic w.[n] ote q"))

      assert tag_bit <= caught + 0.5,
             "a tag's bit took #{tag_bit} a rung, a caught element #{caught}"

      cals = fn n ->
        "var off bool\nvar_input a bool\nvar_input i int\nvar e bool[8]\nvar_output q bool\n" <>
          Enum.map_join(1..n, "\n", &"var s#{&1} seal\nvar t#{&1} seal") <> "\n"
      end

      # A `cal` in a caught contact's place: the two rungs differ in that instruction alone.
      contact = per_rung(cals, &"xic off xic e[i] cal s#{&1} a q")
      cal = per_rung(cals, &"xic off cal t#{&1} a q cal s#{&1} a q")
      assert cal <= contact + 0.5, "a `cal` took #{cal - contact} more than a caught contact"
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

    # Decision 405: each storage bit an array keeps is kept under every projection of its
    # places, so a write through a tag subscript looks up the ones it may meet once, and
    # the warnings stay linear in the writes and the storage bits beside them, here none
    # meeting; searching every storage bit of the array at each write costs 2.43x at 2x.
    # Counted in a process of its own with a heap the collector never visits, the least of
    # three runs.
    test "a write through a tag subscript beside the storage bits it never meets costs linear reductions" do
      source = fn n ->
        "var_input a bool\nvar_input i int\nvar e bool[33,32]\nvar_output q bool\n" <>
          "xic e[0,0] ote q\n" <>
          Enum.map_join(
            0..(n - 1),
            "\n",
            &"xic a ons e[#{1 + div(&1, 32)},#{rem(&1, 32)}] xic e[0,0]"
          ) <>
          "\n" <> Enum.map_join(1..n, "\n", fn _ -> "xic a ote e[0,i]" end)
      end

      compile = fn n ->
        text = source.(n)
        parent = self()

        Enum.min(
          for _run <- 1..3 do
            {_pid, ref} =
              :erlang.spawn_opt(
                fn ->
                  {:reductions, before} = Process.info(self(), :reductions)
                  {:ok, p} = Logex.compile(text, name: "p")
                  {:reductions, later} = Process.info(self(), :reductions)
                  send(parent, {:compiled, later - before, p.warnings})
                end,
                [:monitor, min_heap_size: 50_000_000]
              )

            assert_receive {:compiled, reductions, warnings}, 30_000
            assert_receive {:DOWN, ^ref, :process, _, :normal}, 30_000
            refute Enum.any?(warnings, &(&1.message =~ "the storage bit"))
            reductions
          end
        )
      end

      small = compile.(200)
      large = compile.(400)
      assert large / small < 2.2, "#{small} at 200, #{large} at 400"
    end

    # Decision 431: each write of a member's word looks up only the projections of its places
    # that may meet it, at most 16 for three dimensions and a bit, as decision 405's do, so
    # coils on the members' bits of literal elements beside as many through tag subscripts
    # and numbered by tags compile in linear reductions; the least of three runs.
    test "a member's bits through tags beside literal ones cost linear reductions (decision 431)" do
      source = fn n ->
        "var_input a bool\nvar_input i int\nvar_input n int\nvar lc ctu[40,40]\n" <>
          "var_output q bool\nxic lc[0,0].q ote q\n" <>
          Enum.map_join(
            0..(n - 1),
            "\n",
            &"xic a ote lc[#{div(&1, 40)},#{rem(&1, 40)}].pv.#{rem(&1, 16)}"
          ) <>
          "\n" <>
          Enum.map_join(0..(n - 1), "\n", &"xic a ote lc[i,#{rem(&1, 40)}].pv.[n]")
      end

      compile = fn n ->
        text = source.(n)
        parent = self()

        Enum.min(
          for _run <- 1..3 do
            {_pid, ref} =
              :erlang.spawn_opt(
                fn ->
                  {:reductions, before} = Process.info(self(), :reductions)
                  {:ok, p} = Logex.compile(text, name: "p")
                  {:reductions, later} = Process.info(self(), :reductions)
                  send(parent, {:compiled, later - before, p.warnings})
                end,
                [:monitor, min_heap_size: 50_000_000]
              )

            assert_receive {:compiled, reductions, warnings}, 30_000
            assert_receive {:DOWN, ^ref, :process, _, :normal}, 30_000

            assert Enum.count(warnings, &(&1.message =~ "the last one in the scan decides it")) >=
                     n

            reductions
          end
        )
      end

      small = compile.(200)
      large = compile.(400)
      assert large / small < 2.2, "#{small} at 200, #{large} at 400"
    end

    # The least of three compiles in a process of its own with a heap the collector never
    # visits, so that a figure moves by a few reductions of hundreds of thousands at most.
    defp least_compile(source) do
      cost = fn ->
        parent = self()

        {_pid, ref} =
          :erlang.spawn_opt(
            fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              Logex.compile(source, name: "p")
              {:reductions, later} = Process.info(self(), :reductions)
              send(parent, {:reductions, later - before})
            end,
            [:monitor, min_heap_size: 8_000_000]
          )

        assert_receive {:reductions, n}, 10_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
        n
      end

      Enum.min(for _ <- 1..3, do: cost.())
    end

    # RV-15's review: decision 431's own decisions were made for every member's word a coil
    # names a bit of, though only a pair with a tag subscript on one side is judged beyond
    # the member rules, so that 200 coils on members' bits of literal elements numbered by a
    # tag, and no tag subscript, compiled 9.0% dearer than at `9a9a48c`, 11.6% in two
    # dimensions. A member's word is judged as a word array only where some write reaches
    # it through a tag subscript (`Logex.Warnings`' covered/2); any other keeps a mark of
    # each coil, one look over the decisions more. Each program here was held within 8
    # reductions a rung of what it did at `9a9a48c`, a word array's within 1, restated from
    # the parent's compile and parse. Since decision 357 each is held against a twin
    # compiled in the same run: members' bits against the same coils on bits of a word
    # array's elements, which decision 431 never reaches, and a word array's against the
    # same coils on bits of scalar words, the two programs declaring and reading the same
    # tags. Each twin costs what it measured apart at RV-7, `apart` a rung, and the bound
    # allows 8 a rung more, a word array's half of one: every member's word judged as a word
    # array costs 150 to 257 a rung more, and a word array's coils kept as a member's word's
    # one more, each past its bound, while a call both twins make moves both.
    test "coils on members' bits no write reaches through a tag subscript cost what they did before decision 431" do
      head =
        "var_input a bool\nvar_input n int\nvar l1 ctu[200]\nvar lc ctu[20,20]\n" <>
          "var w dint[200]\nvar wg dint[20,20]\nvar_output q bool\n" <>
          "xic l1[0].q xic lc[0,0].q ote q\n"

      rungs = fn rung -> Enum.map_join(0..199, "\n", rung) end
      two = &"lc[#{div(&1, 20)},#{rem(&1, 20)}]"
      words = &"wg[#{div(&1, 20)},#{rem(&1, 20)}]"

      scalars =
        "var_input a bool\nvar_input n int\nvar l1 ctu[200]\nvar lc ctu[20,20]\n" <>
          "var w dint[200]\n" <>
          Enum.map_join(0..199, "", &"var v#{&1} dint\n") <>
          "var_output q bool\nxic l1[0].q xic lc[0,0].q ote q\nxic w[0].0 " <>
          Enum.map_join(0..199, " ", &"xic v#{&1}.0") <> " ote q\n"

      # {label, the rungs' count, the program, its twin, `apart`, the bound a rung over it}
      for {label, n, source, twin, apart, per_rung} <- [
            {"members' literal bits", 200,
             head <> rungs.(&"xic a ote l1[#{&1}].pv.#{rem(&1, 16)}"),
             head <> rungs.(&"xic a ote w[#{&1}].#{rem(&1, 16)}"), 105, 8},
            {"members' literal bits in two dimensions", 200,
             head <> rungs.(&"xic a ote #{two.(&1)}.pv.#{rem(&1, 16)}"),
             head <> rungs.(&"xic a ote #{words.(&1)}.#{rem(&1, 16)}"), 108, 8},
            {"members' bits a tag numbers", 200, head <> rungs.(&"xic a ote l1[#{&1}].pv.[n]"),
             head <> rungs.(&"xic a ote w[#{&1}].[n]"), 105, 8},
            {"members' bits a tag numbers in two dimensions", 200,
             head <> rungs.(&"xic a ote #{two.(&1)}.pv.[n]"),
             head <> rungs.(&"xic a ote #{words.(&1)}.[n]"), 126, 8},
            {"members' bits a tag numbers beside their words written whole", 400,
             head <> rungs.(&"xic a ote l1[#{&1}].pv.[n]\nxic a move 5 l1[#{&1}].pv"),
             head <> rungs.(&"xic a ote w[#{&1}].[n]\nxic a move 5 w[#{&1}]"), 77, 8},
            {"members' literal bits beside latches of them", 400,
             head <>
               rungs.(
                 &"xic a ote l1[#{&1}].pv.#{rem(&1, 16)}\nxic a otl l1[#{&1}].pv.#{rem(&1 + 1, 16)}"
               ),
             head <>
               rungs.(&"xic a ote w[#{&1}].#{rem(&1, 16)}\nxic a otl w[#{&1}].#{rem(&1 + 1, 16)}"),
             113, 8},
            {"a word array's bits", 200, scalars <> rungs.(&"xic a ote w[#{&1}].#{rem(&1, 16)}"),
             scalars <> rungs.(&"xic a ote v#{&1}.#{rem(&1, 16)}"), 201.5, 0.5}
          ] do
        assert {:ok, %Logex.Program{}} = Logex.compile(source, name: "p"), label
        assert {:ok, %Logex.Program{}} = Logex.compile(twin, name: "p"), label
        {compiled, twinned} = {least_compile(source), least_compile(twin)}

        assert compiled - twinned <= (apart + per_rung) * n,
               "#{label} compiled in #{compiled} reductions, #{compiled - twinned} more than " <>
                 "its twin, #{Float.round((compiled - twinned) / n, 1)} a rung against " <>
                 "#{apart} measured apart"
      end
    end

    # RV-12's review: decision 405's index of the storage bits was built for every array a
    # one-shot keeps one in, up to 16 projections a bit, though only a write through a tag
    # subscript looks it up, so a routine of one-shots on elements and no such write
    # compiled up to 16% dearer than at `f31bf70`, 357 reductions a rung for bits of a word
    # array of three dimensions, 210 for elements of a bool array of three, 117 and 70 for
    # one dimension's, and so beside a write through a tag subscript of another array. It
    # is built only for the arrays a write names through a tag subscript. Each program here,
    # alone and beside `ote z[i]`, was held within 16 reductions a rung of what it did at
    # `f31bf70`, restated from the parent's compile and parse. Since decision 357 each is
    # held against a twin compiled in the same run, the same one-shots keeping their
    # storage bits in scalar words' bits or in scalar bools, which no index reaches. Each
    # twin costs what it measured apart at RV-7, `apart` a rung, its 200 or 64 scalars
    # declared where the program declares one array, and the bound allows 16 a rung more:
    # the index built for every array costs 81 to 369 a rung more, past its bound, while a
    # call both twins make moves both.
    test "one-shots on elements of arrays no write names through a tag subscript cost what they did before decision 405" do
      head = fn n, array ->
        "var_input a bool\nvar #{array}\n" <> Enum.map_join(0..(n - 1), "", &"var p#{&1} bool\n")
      end

      bools = fn n ->
        "var_input a bool\n" <>
          Enum.map_join(0..(n - 1), "", &"var p#{&1} bool\nvar b#{&1} bool\n")
      end

      words = fn n ->
        "var_input a bool\n" <>
          Enum.map_join(0..(n - 1), "", &"var p#{&1} bool\n") <>
          Enum.map_join(0..(n - 1), "", &"var ww#{&1} word\n")
      end

      three = &"h[#{rem(&1, 4)},#{rem(div(&1, 4), 4)},#{rem(div(&1, 16), 4)}].#{div(&1, 64)}"
      cube = &"f[#{rem(&1, 4)},#{rem(div(&1, 4), 4)},#{div(&1, 16)}]"
      beside = "\nvar_input i int\nvar z bool[4]"
      scalar_word = &"ww#{&1}.#{div(&1, 64)}"
      scalar_bool = &"b#{&1}"

      shots = fn n, storage, last ->
        Enum.map_join(0..(n - 1), "\n", &"xic a ons #{storage.(&1)} ote p#{&1}") <> last
      end

      # {label, rungs, the program's head, its storage bit, its twin's head, the twin's
      # storage bit, the rung after them, `apart`}
      for {label, n, array, storage, twin_head, twin_storage, last, apart} <- [
            {"bits of a word array of three dimensions", 200, "h word[4,4,4]", three, words.(200),
             scalar_word, "", 49},
            {"elements of a bool array of three dimensions", 64, "f bool[4,4,4]", cube,
             bools.(64), scalar_bool, "", 57},
            {"bits of a word array of one dimension", 200, "w word[64]",
             &"w[#{rem(&1, 64)}].#{div(&1, 64)}", words.(200), scalar_word, "", -204},
            {"elements of a bool array of one dimension", 64, "e bool[64]", &"e[#{&1}]",
             bools.(64), scalar_bool, "", -175},
            {"bits of a word array of three dimensions beside z[i]", 200,
             "h word[4,4,4]" <> beside, three, words.(200) <> "var_input i int\nvar z bool[4]\n",
             scalar_word, "\nxic a ote z[i]", 49},
            {"elements of a bool array of three dimensions beside z[i]", 64,
             "f bool[4,4,4]" <> beside, cube, bools.(64) <> "var_input i int\nvar z bool[4]\n",
             scalar_bool, "\nxic a ote z[i]", 57},
            {"bits of a word array of one dimension beside z[i]", 200, "w word[64]" <> beside,
             &"w[#{rem(&1, 64)}].#{div(&1, 64)}",
             words.(200) <> "var_input i int\nvar z bool[4]\n", scalar_word, "\nxic a ote z[i]",
             -204},
            {"elements of a bool array of one dimension beside z[i]", 64, "e bool[64]" <> beside,
             &"e[#{&1}]", bools.(64) <> "var_input i int\nvar z bool[4]\n", scalar_bool,
             "\nxic a ote z[i]", -175}
          ] do
        source = head.(n, array) <> shots.(n, storage, last)
        twin = twin_head <> shots.(n, twin_storage, last)
        assert {:ok, %Logex.Program{warnings: []}} = Logex.compile(source, name: "p"), label
        assert {:ok, %Logex.Program{warnings: []}} = Logex.compile(twin, name: "p"), label
        {compiled, twinned} = {least_compile(source), least_compile(twin)}

        assert compiled - twinned <= (apart + 16) * n,
               "#{label} compiled in #{compiled} reductions, #{compiled - twinned} more than " <>
                 "its twin, #{Float.round((compiled - twinned) / n, 1)} a rung against " <>
                 "#{apart} measured apart"
      end
    end

    # RV-12's review: an element of a bool array written whole has no bit, so decision
    # 405 gives it no bit's place, where a word array's element has a tag's. Given one, it
    # would meet the same writes, a tag's place meeting every value and no write of a bool
    # array naming a bit, so the warnings would be the same, but each such write would be
    # kept under twice the projections: 164 reductions a write more for an array of three
    # dimensions, 90 for one of two. Each program here, 64 such writes beside a coil
    # through a tag subscript, was held within 16 reductions a write of what it did at
    # `f31bf70`. Since decision 357 each is held against a twin compiled in the same run,
    # the same 64 writes into scalar ints beside the same coil, `apart` a write more as
    # measured at RV-7, the bound 16 a write more: a bool element given a bit's place costs
    # 84 and 158 a write more, past its bound.
    test "an element of a bool array written whole keeps no bit's place, and costs what it did" do
      # {label, the array, the coil through a tag subscript, a write's subscripts, the
      # warnings, `apart`}
      for {label, array, tagged, subscripts, warned, apart} <- [
            {"three dimensions", "f bool[4,4,4]", "f[i,0,0]",
             &"#{rem(&1, 4)},#{rem(div(&1, 4), 4)},#{rem(div(&1, 16), 4)}", 4, 535},
            {"two dimensions", "f bool[16,4]", "f[i,0]", &"#{rem(&1, 16)},#{rem(div(&1, 16), 4)}",
             16, 217}
          ] do
        head = "var_input a bool\nvar_input i int\nvar #{array}\n"

        source =
          head <>
            "xic a ote #{tagged}\n" <>
            Enum.map_join(0..63, "\n", &"xic a move 1 f[#{subscripts.(&1)}]")

        twin =
          head <>
            Enum.map_join(0..63, "", &"var s#{&1} int\n") <>
            "xic a ote #{tagged}\n" <> Enum.map_join(0..63, "\n", &"xic a move 1 s#{&1}")

        assert {:ok, %Logex.Program{warnings: warnings}} = Logex.compile(source, name: "p")
        assert {label, length(warnings)} == {label, warned}
        assert {:ok, %Logex.Program{}} = Logex.compile(twin, name: "p")
        {compiled, twinned} = {least_compile(source), least_compile(twin)}

        assert compiled - twinned <= (apart + 16) * 64,
               "#{label} compiled in #{compiled} reductions, #{compiled - twinned} more than " <>
                 "its twin, #{Float.round((compiled - twinned) / 64, 1)} a write against " <>
                 "#{apart} measured apart"
      end
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

      head = fixed("var_input i int\nvar_input j int\nvar g int[4,8]\nvar_output q int\n")
      scan_cost = per_rung(head, fn _ -> "move g[i,j] q" end)
      # Held under 60 reductions a rung, 39 measured, until decision 357; since then under
      # the same share of a literal element's, 18 in the same run.
      literal = per_rung(head, fn _ -> "move g[1,3] q" end)
      assert scan_cost < 60 / 18 * literal, "#{scan_cost} a rung, a literal one #{literal}"
    end
  end
end
