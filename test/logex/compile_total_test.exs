defmodule Logex.CompileTotalTest do
  @moduledoc """
  RV-2 (the review after Milestone 6, H5 and M13): every source text `Logex.compile/2`,
  `Logex.compile_file/1` or `Logex.Configuration.compile/3` is given compiles to a program,
  a block or located diagnostics, and raises on none, nor do the readers of a host's key,
  an image's path, the store and the forces file on a name or a number the lexer gives. H5's
  six roots, each its own test that fails when its fix is reverted, M13's bounds on a
  number, and a seeded mutation walk over the shapes the review met, which holds that
  nothing escapes.
  """
  use ExUnit.Case, async: true

  alias Logex.{Diagnostic, Name}

  defp compiled(source, types \\ []) do
    source |> Logex.compile(name: "m", types: types) |> outcome()
  end

  defp outcome({:ok, %Logex.Program{warnings: warnings}}),
    do: {:ok, Enum.map(warnings, & &1.message)}

  defp outcome({:ok, %Logex.FbType{} = block}), do: {:block, block}
  defp outcome({:error, diagnostics}), do: {:error, Enum.map(diagnostics, &Diagnostic.format/1)}

  defp block(source, name), do: Logex.compile(source, name: name)

  # One scan with `inputs`, its outputs and the state after it.
  defp scanned(program, state, inputs),
    do:
      Logex.Runtime.call(program, state, inputs, %Logex.Scan{now: state.now, first: state.first})

  defp seal do
    {:ok, seal} =
      block("function_block seal\nvar_input x bool\nvar_output y bool\nxic x ote y\n", "seal")

    seal
  end

  describe "H5's first root: a block rung led by a group whose first leg is empty" do
    # Compiler.printed/1 places each rung of a block on its line, which element_line/1 read
    # from its first element, and a group's first leg, `[]`, had none.
    test "compiles at any depth, and its body compiles again from the text it carries" do
      for rung <- [
            "( | xic a ) ote b",
            "( ( | xic a ) | xic a ) ote b",
            "( ) ote b",
            "( ( ) | ( | xic a ) ) ote b",
            "xic a ( | xic a ) ote b"
          ] do
        # The rung on line 6, after a blank line and a comment, so that its body's text
        # places it there and nowhere else.
        source =
          "function_block fb\nvar_input a bool\nvar_output b bool\n\n// the rung\n" <>
            rung <> "\nxic a ote b\n"

        assert {:ok, %Logex.FbType{body: body} = type} = block(source, "fb"), rung
        assert Logex.FbType.user?(type), rung
        assert [6, 7] = Enum.map(body.rungs, &first_line/1), rung

        # Built by instructionize/3 from the parse tree, the block's text is its rungs
        # printed, each on the line it was parsed from (decision 54).
        {:ok, tokens, _} = Logex.Compiler.tokenize(source)
        {:ok, tree} = Logex.Compiler.parse(tokens)
        assert {:ok, %Logex.FbType{body: built} = printed} = Logex.Compiler.instructionize(tree)
        assert Logex.FbType.user?(printed), rung
        assert [_, _, _, "", "", ^rung, "xic a ote b"] = String.split(built.source, "\n"), rung

        assert {:ok, _program} =
                 Logex.compile("var a bool\nvar b bool\nvar f fb\ncal f a b\n",
                   name: "p",
                   types: [type]
                 )
      end
    end

    # RV-2's review: a group alone whose first leg is empty, its output on a later leg, at
    # any depth, so that each leg past the empty one is read for the rung's line: a reading
    # that stopped at the first leg read none, and printed/1 raised ArithmeticError.
    test "a group alone whose first leg is empty compiles and runs, its output on a later leg" do
      for {rung, b} <- [
            {"( | xic a ote b )", & &1},
            {"( | ote b )", fn _a -> 1 end},
            {"( | ( | xic a ote b ) )", & &1},
            {"( ( | ) | ( ) | xio a ote b )", &(1 - &1)}
          ] do
        source =
          "function_block fb\nvar_input a bool\nvar_output b bool\n\n// the rung\n" <>
            rung <> "\n"

        assert {:ok, %Logex.FbType{body: body} = type} = block(source, "fb"), rung
        assert Logex.FbType.user?(type), rung
        assert [6] = Enum.map(body.rungs, &first_line/1), rung

        {:ok, tokens, _} = Logex.Compiler.tokenize(source)
        {:ok, tree} = Logex.Compiler.parse(tokens)
        assert {:ok, %Logex.FbType{body: built} = printed} = Logex.Compiler.instructionize(tree)
        assert Logex.FbType.user?(printed), rung
        assert [_, _, _, "", "", ^rung] = String.split(built.source, "\n"), rung

        assert {:ok, program} =
                 Logex.compile("var_input a bool\nvar_output b bool\nvar f fb\ncal f a b\n",
                   name: "p",
                   types: [type]
                 )

        # The coil is on its own leg, which the empty legs beside it do not power.
        for a <- [0, 1] do
          {outputs, _state} = scanned(program, Logex.Runtime.instance(program), %{"a" => a})
          assert outputs == %{"b" => b.(a)}, rung
        end
      end
    end

    # A rung of empty groups alone holds no line, and is printed on a line of its own.
    # A rung of empty groups alone holds no line; since decision 351 it is refused, in a
    # block's file as in a program's, so no block printed holds one.
    test "a rung of empty groups alone is refused in a block, at the first line it can stand on" do
      source =
        "function_block fb\nvar_input a bool\nvar_output b bool\nxic a ote b\n( )\n( | )\n"

      assert {:error, [%Diagnostic{line: 5} = d5, %Diagnostic{line: 6} = d6]} =
               block(source, "fb")

      assert d5.message =~ "a rung of empty groups alone, after line 4, writes nothing"
      assert d6.message =~ "a rung of empty groups alone, after line 4, writes nothing"
    end

    test "and through the loader, from a file beside the program that holds it" do
      dir = Path.join(System.tmp_dir!(), "logex-rv2-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(
        Path.join(dir, "gate.ld"),
        "function_block gate\nvar_input a bool\nvar_output b bool\n( | xic a ) ote b\n"
      )

      File.write!(
        Path.join(dir, "main.ld"),
        "var_input x bool\nvar_output y bool\nvar g gate\ncal g x y\n"
      )

      assert {:ok, %Logex.Program{} = program} = Logex.compile_file(Path.join(dir, "main.ld"))

      # The empty leg passes power, whatever `x` is.
      for x <- [0, 1] do
        assert {%{"y" => 1}, _state} =
                 scanned(program, Logex.Runtime.instance(program), %{"x" => x})
      end
    end
  end

  defp first_line(rung), do: rung |> List.wrap() |> Logex.Walk.instructions() |> hd() |> elem(1)

  describe "H5's second root: a literal bit number in brackets on a tag of no bits" do
    # A literal in brackets reached a message that names an elementary type alone, with
    # the instance's type, Protocol.UndefinedError; it is told it has no bits as the bit
    # number a tag holds, `t.[n]`, always was.
    test "an instance, an element of instances and a block's instance are told they have none" do
      assert compiled("var a bool\nvar t ton\nxic t.[3] ote a") ==
               {:error,
                [
                  "line 3: `t.[3]` names a bit of `t`, but `t` is a ton (declared on line 2): " <>
                    "only an integer or a bit string has bits"
                ]}

      assert compiled("var a bool\nvar t ton[2]\nxic t[1].[0] ote a") ==
               {:error,
                [
                  "line 3: `t[1].[0]` names a bit of `t[1]`, but `t[1]` is a ton (declared " <>
                    "on line 2): only an integer or a bit string has bits"
                ]}

      assert compiled("var a bool\nvar s seal\nxic a ote s.[16#0]", [seal()]) ==
               {:error,
                [
                  "line 3: `s.[16#0]` names a bit of `s`, but `s` is an instance of `seal` " <>
                    "(declared on line 2): only an integer or a bit string has bits"
                ]}

      assert compiled("var a bool\nvar t ton\nxic t.[-1] ote a") ==
               {:error,
                [
                  "line 3: `t.[-1]` names a bit of `t`, but `t` is a ton (declared on line 2): " <>
                    "only an integer or a bit string has bits"
                ]}
    end

    test "a bool, a real and an array are told so as before" do
      assert compiled("var a bool\nvar b bool\nxic b.[3] ote a") ==
               {:error, ["line 3: `b.[3]` names a bit of `b`, a bool, which has no bits"]}

      assert compiled("var a bool\nvar r real\nxic r.[3] ote a") ==
               {:error, ["line 3: `r.[3]` names a bit of `r`, a real, which has no bits"]}

      assert compiled("var a bool\nvar w word[2]\nxic w.[3] ote a") ==
               {:error,
                ["line 3: `w.[3]` names a bit of `w`, an array of 2 words, which has no bits"]}
    end
  end

  describe "H5's third root: a pulse bit in a bit of a member of an element" do
    # Walk.bit_name/1 joined the container as a path, and a member of an element holds an
    # element: Protocol.UndefinedError, for the very bit the compiler's refusal of
    # `lc[1].pv.[n]` offers.
    test "compiles, the coil pulsing the bit, and is named by its element's name" do
      source =
        "var_input a bool\nvar s bool\nvar lc ctu[2]\nvar_output p bool\n" <>
          "xic a osr s lc[1].pv.0\nxic lc[1].pv.0 ote p\nxic a ctu lc[0] 4\nxic a ctu lc[1] 4"

      assert {:ok, program} = Logex.compile(source, name: "m")
      {%{"p" => 0}, state} = scanned(program, Logex.Runtime.instance(program), %{"a" => 0})
      {%{"p" => 1}, state} = scanned(program, state, %{"a" => 1})
      assert {%{"p" => 0}, _state} = scanned(program, state, %{"a" => 1})

      assert [{:osr, 5, [_storage, bit]}] =
               for(
                 {:osr, _, _} = instruction <- Logex.Walk.instructions(program.rungs),
                 do: instruction
               )

      assert Logex.Walk.bit_name(bit) == "lc[1].pv.0"
    end

    test "in a block's body, and of a timer's member" do
      for {source, name} <- [
            {"function_block fb\nvar_input a bool\nvar s bool\nvar_output y bool\n" <>
               "var ta ton[3]\nxic a osf s ta[2].pre.1\nxic a ton ta[2] 5\nxic ta[2].dn ote y",
             "fb"},
            {"var_input a bool\nvar s bool\nvar tt ton[2]\nxic a osr s tt[1].acc.3\n" <>
               "xic a ton tt[1] 5\nxic a ton tt[0] 5", "m"}
          ] do
        assert {:ok, _} = Logex.compile(source, name: name), source
      end
    end
  end

  describe "H5's fourth root: a bit number held in an array" do
    # An array reached a bit string's conversion message, Declarations.kind/1 of an array:
    # FunctionClauseError. It is told an array holds no one number, as a subscript is.
    test "is told a bit number is held in a tag of an integer type" do
      for {source, quoted, of} <- [
            {"var w word\nvar a int[2]\nvar o bool\nxic w.[a] ote o", "w.[a]",
             "`a`, an array of 2 ints (declared on line 2)"},
            {"var w word\nvar a ton[2]\nvar o bool\nxic w.[a] ote o", "w.[a]",
             "`a`, an array of 2 tons (declared on line 2)"},
            {"var t ton\nvar a int[2]\nvar o bool\nxic t.acc.[a] ote o", "t.acc.[a]",
             "`a`, an array of 2 ints (declared on line 2)"},
            {"var w word[2]\nvar a int[2]\nvar o bool\nxic w[1].[a] ote o", "w[1].[a]",
             "`a`, an array of 2 ints (declared on line 2)"}
          ] do
        assert compiled(source) ==
                 {:error,
                  [
                    "line 4: `#{quoted}` takes its bit number from #{of}, which is no " <>
                      "integer: a bit number is held in a tag of an integer type, never an " <>
                      "array or one of its elements"
                  ]},
               source
      end
    end
  end

  describe "H5's fifth root: `cal` of a name that goes on past an element" do
    # cal/3 lowered the element before it knew the name was one, splitting the whole name
    # at its first `[`: FunctionClauseError in its subscripts' read.
    test "a nested element, a bit of an element and an element's member are told what they are" do
      {:ok, gate} =
        block("function_block gate\nvar_input x bool\nvar_output y bool\nxic x ote y\n", "gate")

      {:ok, line} =
        Logex.compile(
          "function_block line\nvar_input a bool\nvar_output q bool\nvar gates gate[2]\n" <>
            "cal gates[0] a q\ncal gates[1] a q\n",
          name: "line",
          types: [gate]
        )

      types = [seal(), gate, line]

      for {source, message} <- [
            {"var a bool\nvar q bool\nvar lines line[2]\ncal lines[1].gates[0] a q",
             "line 4: `cal` runs an instance of a function block, named whole: found " <>
               "`lines[1].gates[0]`"},
            {"var n int\nvar e word[2]\ncal e[0].[n]",
             "line 3: `cal` runs an instance of a function block, named whole: found `e[0].[n]`"},
            {"var a bool\nvar arr dint[3]\nxic a cal arr[1].[2]",
             "line 3: `cal` runs an instance of a function block, but `arr[1].[2]` is a bool " <>
               "(declared on line 2)"},
            {"var a bool\nvar b bool\nvar g seal[2]\ncal g[1].[0] a b",
             "line 4: `cal` runs an instance of a function block, named whole: found `g[1].[0]`"},
            {"var a bool\nvar b bool\nvar g seal[2]\ncal g[1].x a b",
             "line 4: `cal` runs an instance of a function block, named whole: found `g[1].x`"},
            {"var n int\ncal zz[1].x.[0]", "line 2: `zz` is not declared"}
          ] do
        assert compiled(source, types) == {:error, [message]}, source
      end
    end

    test "an element of an array of a block's instances is still run" do
      source =
        "var_input a bool\nvar_output b bool\nvar g seal[2]\ncal g[1] a b\ncal g[0] a b"

      assert {:ok, program} = Logex.compile(source, name: "m", types: [seal()])

      assert {%{"b" => 1}, _state} =
               scanned(program, Logex.Runtime.instance(program), %{"a" => 1})
    end
  end

  describe "H5's sixth root: a name the lexer gives that is no element" do
    # Logex.Array.split/1 cut at the first `[` and took the text to the last `]`, so a name
    # that goes on past its brackets, or a type word with a `.` part after its sizes, was
    # read as an element of nonsense subscripts, and one ending in `[` raised binary_part's
    # error. Logex.Name.element/1 reads only one word and one pair of brackets closing it.
    test "a type word with a part after its sizes is an unknown type, in a program" do
      for word <- ~w(int[2].[n] int[1].x[2] int[1].[2] ton[1].[2] int[1,2].[3]) do
        assert {:error, [message]} = compiled("var p #{word}"), word
        assert message =~ "line 1: unknown type `#{word}`: logex has `bool`", word
      end

      assert {:error, [message]} = compiled("var p seal[2].[n]", [seal()])
      assert message =~ "line 1: unknown type `seal[2].[n]`"
    end

    # The loader reads a block's name from a type word's base, `gate` of `gate[4]`, and
    # from no word that is not one word and its sizes, so a broken `gate.ld` beside the
    # program is not loaded for `gate[2].x`, which the compiler reports alone.
    test "and the loader loads no block for it" do
      dir = Path.join(System.tmp_dir!(), "logex-rv2-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      File.write!(Path.join(dir, "gate.ld"), "function_block gate\nxic\n")

      File.write!(
        Path.join(dir, "main.ld"),
        "var g gate[2].x\nvar_input a bool\nvar_output y bool\nxic a ote y\n"
      )

      assert {:error, [%Diagnostic{line: 1, message: message} = d]} =
               Logex.compile_file(Path.join(dir, "main.ld"))

      assert message =~ "unknown type `gate[2].x`"
      assert d.file == Path.join(dir, "main.ld")
    end

    test "and in a configuration's global" do
      for word <- ~w(int[1].[2] int[1].x[2] ton[2].[1]) do
        assert {:error, [%Diagnostic{stage: :configure, line: 1, column: 14} = d | _]} =
                 Logex.Configuration.compile("c", "var_global g #{word}\n", %{}),
               word

        assert d.message =~ "unknown type `#{word}`: a global array's type is `bool`", word
      end
    end

    # RV-2's review: a connection's member read through Logex.Name.element/1, which gives
    # nil for a member that is no one word and one pair of brackets, raised
    # FunctionClauseError in Logex.Configuration's element_tag/3, from a configuration's
    # text and from Elixir alike. Such a member is told as one its program does not
    # declare, too deep where it has a `.` part, as `k1.a.3` is.
    test "a connection's member that ends in a bracket and is no element, in text and from Elixir" do
      {:ok, keep} =
        Logex.compile("var_input a bool\nvar_output o int\nxic a move 1 o", name: "keep")

      head =
        "var_global x bool\nvar_global y int\ntask t interval 10 priority 1\n" <>
          "program k1 keep with t\n  k1.a x\n  k1.o y\n"

      none =
        &"`k1` runs `keep`, which declares no `#{&1}`: its var_inputs and var_outputs are `a` and `o`"

      deep =
        &"`#{&1}` goes too deep: a connection names an instance's var_input or var_output, as in `k1.start`"

      for {line, message} <- [
            {"k1.[0] x", none.("[0]")},
            {"k1.[n] x", none.("[n]")},
            {"k1.[01] x", none.("[01]")},
            {"k1.o[1].[2] y", deep.("k1.o[1].[2]")},
            {"k1.a[1].[x] x", deep.("k1.a[1].[x]")},
            {"k1.a.[0] x", deep.("k1.a.[0]")},
            {"k1.a.x[0] x", deep.("k1.a.x[0]")}
          ] do
        assert {:error, [%Diagnostic{stage: :configure, line: 7, message: ^message}]} =
                 Logex.Configuration.compile("plant", head <> "  " <> line <> "\n", %{
                   "keep" => keep
                 }),
               line
      end

      config =
        Logex.Configuration.new!(
          name: "plant",
          programs: [keep],
          globals: [
            %Logex.Configuration.Global{name: "x", type: :bool},
            %Logex.Configuration.Global{name: "y", type: :int}
          ],
          instances: [%Logex.Configuration.Instance{name: "k1", type: "keep"}],
          connections: [%Logex.Configuration.Connection{instance: "k1", member: "a", to: "x"}]
        )

      for {member, message} <- [{"[1]", none.("[1]")}, {"o[1].[2]", deep.("k1.o[1].[2]")}] do
        connection = %Logex.Configuration.Connection{instance: "k1", member: member, to: "y"}

        assert [%Diagnostic{message: ^message}] =
                 Logex.Configuration.check(%{
                   config
                   | connections: config.connections ++ [connection]
                 }),
               member
      end
    end

    # RV-2's review: a connection's path is split at its first `.`, so `k1[1].a`, which the
    # lexer reads as one name, gave the instance `k1[1]`, which check/1 refused as the
    # host's mistake: from a configuration's text it is a broken line, told so, and it still
    # connects `k1`'s `a`, so that nothing else is told.
    test "a connection whose instance has brackets is a broken line" do
      {:ok, keep} =
        Logex.compile("var_input a bool\nvar_output o int\nxic a move 1 o", name: "keep")

      text =
        "var_global x bool\nvar_global y int\ntask t interval 10 priority 1\n" <>
          "program k1 keep with t\n  k1.o y\n  k1[1].a x\n"

      assert {:error, [%Diagnostic{stage: :configure, line: 6, column: 3, message: message}]} =
               Logex.Configuration.compile("plant", text, %{"keep" => keep})

      assert message ==
               "`k1[1].a` names an element of `k1`: a connection's instance is named whole, " <>
                 "never by one of its elements, as in `k1.a`"

      assert {:error, [%Diagnostic{line: 2, message: "`k1[i].o[0]` names an element of " <> _}]} =
               Logex.Configuration.compile(
                 "plant",
                 "program k1 keep\n  k1[i].o[0] y\n  k1.a x\nvar_global x bool\nvar_global y int\n",
                 %{"keep" => keep}
               )
    end

    test "a host's key that is no element is told it is not declared" do
      {:ok, program} =
        Logex.compile("var_input a int[3]\nvar_output q int\nmove a[1] q", name: "m")

      state = Logex.Runtime.instance(program)

      for key <- ["a[1].[2]", "a[1].x[0]", "a[", "a[1,]"] do
        message = ~s(input #{inspect(key)} is not declared)

        assert_raise ArgumentError, ~r/\A#{Regex.escape(message)}/, fn ->
          Logex.Runtime.put_inputs(program, state, %{key => 1})
        end

        assert_raise ArgumentError, ~r/\A#{Regex.escape(message)}/, fn ->
          Logex.Runtime.call(program, state, %{key => 1}, %Logex.Scan{now: 0, first: true})
        end
      end
    end

    test "an image's path ending in a bracket is no path, where binary_part/3 raised" do
      {:ok, program} =
        Logex.compile("var retain k dint\nvar_input a dint\nmove a k", name: "m")

      image = %{program: "m", kinds: %{}, values: %{"k[" => {:dint, 1}, "zz" => {:bool, 7}}}

      error = assert_raise ArgumentError, fn -> Logex.Runtime.instance(program, image) end
      assert error.message == ~s(`values` holds "k[", which is no path)
    end
  end

  # Decision 351: a newline ends a rung, so a rung wrapped onto two lines is a rung that
  # does nothing and one that runs the motor whatever stop does: a rung that writes nothing
  # and jumps nowhere is refused at its line, told that a newline ends a rung.
  describe "a rung that writes nothing (decision 351)" do
    @idle "this rung writes nothing and jumps nowhere: none of its instructions writes a " <>
            "tag, a member or a bit, runs an instance or keeps a one-shot's storage bit. A " <>
            "newline ends a rung, so a rung's conditions and its outputs go on one line, as " <>
            "in `xic start xio stop ote motor`"

    @io "var_input start bool\nvar_input stop bool\nvar d dint\nvar_output motor bool\n" <>
          "var w word\nvar t ton\nvar c ctu\nvar s bool\nvar e bool[2]\nvar cl ctu[2]\n"

    test "the review's wrapped rung is refused at its first line" do
      source =
        "var_input start bool\nvar_input stop bool\nvar_output motor bool\n\n" <>
          "xic start xio stop\note motor\n"

      assert compiled(source) == {:error, ["line 5: " <> @idle]}
    end

    test "contacts, comparisons, a label and groups of them alone are refused, each at its line" do
      for rung <- [
            "xic start",
            "xic start xio stop",
            "eq d 5",
            "xic start ge d 5 lt d 9",
            "lbl here",
            "lbl here xic start",
            "xic start ( xic stop | xio stop )",
            "( xic start | ( xio stop | eq d 1 ) )",
            "xic start ( | )"
          ] do
        assert compiled(@io <> rung <> "\nxic start ote motor") ==
                 {:error, ["line 11: " <> @idle]},
               rung
      end
    end

    test "a rung that writes a tag, a member, a bit or a storage bit, runs an instance or jumps is taken" do
      for rung <- [
            "xic start ote motor",
            "xic start otl motor",
            "xic start otu motor",
            "xic start move d d",
            "xic start add d 1 d",
            "xic start ote w.3",
            "xic start ote e[1]",
            "xic start move 5 t.pre",
            "xic start ons s",
            "xic start osr s motor",
            "xic start ton t 5",
            "xic start ctu c 5",
            "xic start ctu cl[1] 5",
            "xic start ( xic stop | xio stop ote motor )",
            "( ( xic stop ote motor ) | xio stop )",
            "xic start jmp over\nlbl over xic start ote motor",
            "lbl here xic start ote motor"
          ] do
        assert {:ok, _warnings} = compiled(@io <> rung), rung
      end

      seal = seal()

      assert {:ok, _} =
               compiled(
                 "var_input start bool\nvar_output motor bool\nvar s1 seal\ncal s1 start motor",
                 [seal]
               )
    end

    test "every rung that writes nothing is refused, in a program and in a block, in line order" do
      assert compiled("var_input a bool\nvar_output q bool\nxic a\nxic a ote q\nxio a\nlbl x") ==
               {:error, ["line 3: " <> @idle, "line 5: " <> @idle, "line 6: " <> @idle]}

      assert {:error, [%Diagnostic{line: 4, message: @idle}]} =
               block(
                 "function_block fb\nvar_input a bool\nvar_output q bool\nxic a\nxic a ote q",
                 "fb"
               )
    end

    # A rung refused already, for an unknown instruction, a `cal` that runs nothing or an
    # operand missing, is not told this too.
    test "a rung refused for another reason is not told it writes nothing" do
      for {rung, message} <- [
            {"xic start zzz q", "line 11: unknown instruction `zzz`"},
            {"xic start cal nothing", "line 11: `nothing` is not declared"},
            {"xic start ote", "line 11: `ote` expects 1 operand (a tag), found none"},
            {"xic nowhere_declared", "line 11: `nowhere_declared` is not declared"},
            {"lbl here zzz", "line 11: unknown instruction `zzz`"}
          ] do
        assert {:error, [found]} = compiled(@io <> rung)
        assert found =~ message, rung
      end
    end

    # RV-2's review: the jump checks run over the lowered rungs, after this check, and find
    # a mistake no write mends, so a rung they refuse is told both, as decision 373 has it:
    # a misplaced label, a second label and a label used twice. Since decision 367 a label
    # alone that a `jmp` names is a landing and writes nothing that needs telling, so the
    # label a jump names used twice is told once, as used twice; used twice with no `jmp`,
    # each label alone is told both still.
    test "a rung a jump check refuses is told it writes nothing too" do
      for {source, lines} <- [
            {"var a bool\nxic a lbl x\nxic a ote a", [{2, @idle}, {2, "`lbl x` is not first"}]},
            {"var a bool\nlbl x lbl y\nxic a ote a", [{2, @idle}, {2, "`lbl y` is not first"}]},
            {"var a bool\nxic a jmp done\nlbl done\nlbl done\nxic a ote a",
             [{4, "`done` already labels the rung on line 3"}]},
            {"var a bool\nlbl done\nlbl done\nxic a ote a",
             [{2, @idle}, {3, @idle}, {3, "`done` already labels the rung on line 2"}]},
            # RV-9's review: a label a `jmp` names, last on a rung that writes nothing, is
            # no label alone, and is told both; so is a second label so.
            {"var a bool\nxic a jmp done\nxic a lbl done\nxic a ote a",
             [{3, @idle}, {3, "`lbl done` is not first"}]},
            {"var a bool\nxic a jmp done\nlbl x lbl done\nxic a ote a",
             [{3, @idle}, {3, "`lbl done` is not first"}]}
          ] do
        assert {:error, diagnostics} = Logex.compile(source, name: "m"), source
        assert length(diagnostics) == length(lines), source

        for {%Diagnostic{line: line, message: message}, {at, start}} <-
              Enum.zip(diagnostics, lines) do
          assert line == at, source
          assert String.starts_with?(message, start), "#{source}: #{message}"
        end
      end
    end

    # Decision 367: a rung that is a label alone is a jump's landing where a `jmp` of its
    # routine names the label, and is refused as a rung that writes nothing where none does.
    test "a label alone is taken where a jmp of its routine names it, in a program and in a block" do
      program =
        "var_input a bool\nvar_input b bool\nvar_output q bool\nxic a jmp done\n" <>
          "xic b ote q\nlbl done"

      assert compiled(program) == {:ok, []}

      two =
        "var_input a bool\nvar_input b bool\nvar_output q bool\nxic a jmp done\n" <>
          "xic b jmp done\nxic b ote q\nlbl done"

      assert compiled(two) == {:ok, []}

      middle =
        "var_input a bool\nvar_output q bool\nxic a jmp mid\nxic a ote q\nlbl mid\n" <>
          "xio a ote q"

      assert {:ok, _warnings} = compiled(middle)

      body =
        "function_block fb\nvar_input a bool\nvar_output q bool\nxic a jmp done\n" <>
          "xic a ote q\nlbl done"

      assert {:ok, %Logex.FbType{} = fb} = block(body, "fb")
      assert Logex.Compiler.lowered?(fb.body)

      assert {:ok, []} =
               compiled("var_input a bool\nvar_output q bool\nvar f fb\ncal f a q", [fb])
    end

    test "a label alone no jmp names is refused at its line, in a program and in a block" do
      assert compiled("var_input a bool\nvar_output q bool\nxic a ote q\n\nlbl done") ==
               {:error, ["line 5: " <> @idle]}

      assert {:error, [%Diagnostic{line: 5, message: @idle}]} =
               block(
                 "function_block fb\nvar_input a bool\nvar_output q bool\nxic a ote q\nlbl done",
                 "fb"
               )

      # A label is matched exactly, so a `jmp` of another case names no label, and the label
      # alone is refused too, each at its line.
      assert compiled("var a bool\nxic a jmp Done\nxic a ote a\nlbl done") ==
               {:error,
                [
                  "line 2: `jmp Done` names no label: no rung of this program begins " <>
                    "`lbl Done` — did you mean `done`? (labels are case-sensitive)",
                  "line 4: " <> @idle
                ]}
    end

    # RV-9's review: a compiled body holds a label alone only where a `jmp` of its rungs
    # names it, so a block's body with its `jmp` rung cut out by hand, its label alone and
    # the warning a label no `jmp` names carries kept, is no compiled body, and a compile
    # given it is refused as a host's mistake.
    test "a body whose label alone no jmp names is no compiled body" do
      {:ok, fb} =
        block(
          "function_block fb\nvar_input a bool\nvar_output q bool\nxic a jmp done\n" <>
            "xic a ote q\nlbl done",
          "fb"
        )

      assert Logex.Compiler.lowered?(fb.body)
      [{:rung, [{:xic, 4, _}, {:jmp, 4, _}]} | rest] = fb.body.rungs

      unnamed = %Diagnostic{
        stage: :validate,
        line: 6,
        message: "`done` labels this rung, but no `jmp` names it: nothing jumps here",
        severity: :warning
      }

      for warnings <- [[], [unnamed]] do
        edited = %{fb | body: %{fb.body | rungs: rest, warnings: warnings}}
        refute Logex.Compiler.lowered?(edited.body), inspect(warnings)

        assert_raise ArgumentError,
                     "types must be function block types from Logex.compile/2, got: " <>
                       inspect(edited),
                     fn ->
                       Logex.compile("var_input a bool\nvar_output q bool\nvar f fb\ncal f a q",
                         name: "m",
                         types: [edited]
                       )
                     end
      end
    end

    # RV-9's review, as decision 408 has it: a label and empty groups, `lbl done ( )`, are
    # no label alone, and write nothing, as a label and a contact do.
    test "a label and a contact still write nothing, a jmp naming the label or not" do
      for rung <- [
            "lbl done xic start",
            "lbl done ( xic start | xio stop )",
            "lbl done eq d 5",
            "lbl done ( )",
            "lbl done ( | )"
          ] do
        assert compiled(@io <> "xic start jmp done\n" <> rung) ==
                 {:error, ["line 12: " <> @idle]},
               rung
      end
    end

    # A label no `jmp` names is a warning on a rung that does something (M3-5), and on a
    # label alone the refusal instead: a refused compile gives its diagnostics and no
    # warning, and the rung does nothing at all, which the refusal says.
    test "a label no jmp names is warned of where its rung writes, and a label alone is refused instead" do
      assert compiled("var a bool\nlbl done xic a ote a") ==
               {:ok, ["`done` labels this rung, but no `jmp` names it: nothing jumps here"]}

      assert compiled("var a bool\nxic a ote a\nlbl done") == {:error, ["line 3: " <> @idle]}
    end

    test "a rung of empty groups alone is cited at the first line it can stand on, after the last rung of a line" do
      assert compiled("( )") ==
               {:error,
                [
                  "line 1: a rung of empty groups alone, at the start, writes nothing and jumps " <>
                    "nowhere: a group holds no instruction until a leg has one. A newline ends a " <>
                    "rung, so a rung's conditions and its outputs go on one line, as in " <>
                    "`xic start ( xio stop | xic jog ) ote motor`"
                ]}

      assert {:error, [two, three]} =
               compiled("var b bool\n\n\n( )\n( | ( ) )\nxic b ote b")

      assert two =~ "line 2: a rung of empty groups alone, after line 1, writes nothing"
      assert three =~ "line 3: a rung of empty groups alone, after line 1, writes nothing"
    end

    # RV-2's review: a group whose first leg is empty holds the line of the first leg past
    # it that has one, so it is neither a rung of empty groups alone nor uncited, beside one
    # that is: each rung is cited by its own line, where a reading of the first leg alone
    # raised MatchError.
    test "a group led by an empty leg beside a rung of empty groups alone is cited by its own line" do
      head = "var_input a bool\nvar_output b bool\n"

      assert {:error, [two]} = compiled(head <> "( )\n( | xic a ote b )\nxic a ote b")
      assert two =~ "line 3: a rung of empty groups alone, after line 2, writes nothing"

      assert {:error, [three, four]} = compiled(head <> "( | xic a )\n( )\nxic a ote b")
      assert three == "line 3: " <> @idle
      assert four =~ "line 4: a rung of empty groups alone, after line 3, writes nothing"

      assert {:error, [five, six]} =
               compiled(head <> "xic a ote b\n( ( | ) | ( | eq 1 1 ) )\n\n( | )\n( | ote b )")

      assert five == "line 4: " <> @idle
      assert six =~ "line 5: a rung of empty groups alone, after line 4, writes nothing"

      assert {:error, [%Diagnostic{line: 4, message: @idle}, %Diagnostic{line: 5}]} =
               block("function_block fb\n" <> head <> "( | xic a )\n( )\n( | ote b )", "fb")
    end
  end

  # RV-2's review: decision 351's check walked a rung's instructions from its first until
  # one did something, 12 reductions a rung of ten contacts, and Logex.Name.element/1 cost
  # an element's name 15 to 18 reductions where Logex.Array.split/1 had cost 4, so that a
  # program of arrays compiled up to 7.6% dearer than at `e365fa4`. A rung's last
  # instruction is now looked at first, and an element's name read in one split. Each
  # program here was held within 8 reductions a rung of its compile at `e365fa4`, 16 for one
  # of arrays, restated from the parent's compile and parse. Since decision 357 each is held
  # against a twin compiled in the same run, measured in a process of its own with a heap
  # the collector never visits, the least of three runs: a program of no arrays against
  # the same rungs with the instruction that does something first, the order whose look
  # costs the same however the look is made (a `cal` alone against a `cal` of a literal
  # element, its scalar's look made apart), and a program of arrays against the same rungs
  # over plain tags, whose names are never split. Each twin costs what it measured apart at
  # RV-7, `apart` a rung, and the bound allows the parent's 8 or 16 a rung more: a look
  # from the first instruction costs ten contacts 11 a rung more and a group 23, and the
  # old reading an element's name 60 to 134 a rung, each past its bound, while a reduction
  # more for a call both twins make moves both.
  describe "the cost of RV-2's checks against a twin" do
    test "a program compiles within a few reductions a rung of its twin" do
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

        assert_receive {:reductions, n}, 10_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
        n
      end

      least = fn f -> Enum.min(for _ <- 1..3, do: cost.(f)) end
      rungs = fn rung -> Enum.map_join(1..200, "\n", fn _ -> rung end) end
      seal = seal()
      bools = "var_input a bool\nvar_input b bool\nvar_output q bool\n"
      jumps = &Enum.map_join(1..100, "\n", &1)
      instances = Enum.map_join(1..200, "\n", &"var s#{&1} seal") <> "\nvar sa seal[200]\n"
      elements = "var_input a bool\nvar e bool[8]\nvar i int\nvar_output q bool\n"
      grid = "var_input a bool\nvar e bool[8]\nvar g int[4,4]\nvar_output q bool\n"
      tagged = "var e bool[8]\nvar i int\nvar j int\nvar g int[4,4]\nvar_output q bool\n"
      timers = Enum.map_join(0..199, "\n", &"xic a ton t[#{&1}] 5")
      scalars = Enum.map_join(0..199, "\n", &"xic a ton t#{&1} 5")

      # {label, source, its twin, `apart`, the bound a rung over the twin and `apart`}
      for {label, source, twin, apart, per_rung} <- [
            {"ten contacts",
             bools <> rungs.("xic a xio b xic a xio b xic a xio b xic a xio b xic a xio b ote q"),
             bools <> rungs.("ote q xic a xio b xic a xio b xic a xio b xic a xio b xic a xio b"),
             -1, 8},
            {"groups", bools <> rungs.("( xic a | xio b | xic a xio b ) ote q"),
             bools <> rungs.("( ote q xic a | xio b | xic a xio b )"), -5, 8},
            {"jumps",
             "var_input a bool\nvar_output q bool\n" <>
               jumps.(&"xic a jmp l#{&1}\nlbl l#{&1} xic a ote q"),
             "var_input a bool\nvar_output q bool\n" <>
               jumps.(&"jmp l#{&1} xic a\nlbl l#{&1} ote q xic a"), -2, 8},
            {"blocks",
             "var_input a bool\nvar_output q bool\n" <>
               instances <> Enum.map_join(1..200, "\n", &"cal s#{&1} a q"),
             "var_input a bool\nvar_output q bool\n" <>
               instances <> Enum.map_join(0..199, "\n", &"cal sa[#{&1}] a q"), -159, 8},
            {"bits",
             "var_input a bool\nvar w word\nvar n int\nvar_output q bool\n" <>
               rungs.("xic w.3 xio w.[n] ote w.4"),
             "var_input a bool\nvar w word\nvar n int\nvar_output q bool\n" <>
               rungs.("ote w.4 xic w.3 xio w.[n]"), -1, 8},
            {"elements", elements <> rungs.("xic e[1] xio e[i] ote q"),
             "var e1 bool\nvar ei bool\n" <> elements <> rungs.("xic e1 xio ei ote q"), 272, 16},
            {"literal subscripts", grid <> rungs.("xic e[1] move g[1,2] g[3,3] ote q"),
             "var e1 bool\nvar g12 int\nvar g33 int\n" <>
               grid <> rungs.("xic e1 move g12 g33 ote q"), 690, 16},
            {"tag subscripts",
             "var_input a bool\n" <> tagged <> rungs.("xic e[i] move g[i,j] g[j,i] ote q"),
             "var_input a bool\nvar ei bool\nvar gij int\nvar gji int\n" <>
               tagged <> rungs.("xic ei move gij gji ote q"), 615, 16},
            {"an array of timers",
             "var_input a bool\nvar t ton[200]\nvar_output q bool\n" <>
               timers <> "\n" <> rungs.("xic t[3].dn ote q"),
             "var_input a bool\n" <>
               Enum.map_join(0..199, "\n", &"var t#{&1} ton") <>
               "\nvar_output q bool\n" <> scalars <> "\n" <> rungs.("xic t3.dn ote q"), 11, 16}
          ] do
        assert {:ok, %Logex.Program{}} = Logex.compile(source, name: "p", types: [seal]), label
        assert {:ok, %Logex.Program{}} = Logex.compile(twin, name: "p", types: [seal]), label
        compiled = least.(fn -> Logex.compile(source, name: "p", types: [seal]) end)
        twinned = least.(fn -> Logex.compile(twin, name: "p", types: [seal]) end)

        assert compiled - twinned <= (apart + per_rung) * 200,
               "#{label} compiled in #{compiled} reductions, #{compiled - twinned} more than " <>
                 "its twin, #{Float.round((compiled - twinned) / 200, 1)} a rung against " <>
                 "#{apart} measured apart"
      end
    end
  end

  # Decision 520 (c, RV-20): a refusal of many names gone costs near their count. Each name
  # a compile cannot find was matched against every name the program declares for a
  # did-you-mean, so a box counter's 4,000 tags and 2,000 rungs naming a renamed tag took
  # 50 s; now the first hundred alone are offered the nearest name. A box counter of `n`
  # buttons and coils whose `n` rungs each name a button renamed, compiled at 4x the names
  # and the rungs, counted in a process of its own whose heap no collection visits, the
  # least of three.
  describe "a refusal of many names gone (decision 520)" do
    test "costs near the count of the names, not the names times those declared" do
      counter = fn n ->
        IO.iodata_to_binary([
          for(i <- 1..n, do: "var lane_#{i} bool\nvar pushbutton_start_#{i} bool\n"),
          for(i <- 1..n, do: "xic pushbuton_start_#{i} ote lane_#{i}\n")
        ])
      end

      cost = fn n ->
        source = counter.(n)
        parent = self()

        Enum.min(
          for _ <- 1..3 do
            {_pid, ref} =
              :erlang.spawn_opt(
                fn ->
                  {:reductions, before} = Process.info(self(), :reductions)
                  {:error, diagnostics} = Logex.compile(source, name: "counter")
                  {:reductions, later} = Process.info(self(), :reductions)
                  send(parent, {:reductions, later - before, diagnostics})
                end,
                [:monitor, min_heap_size: 8_000_000]
              )

            assert_receive {:reductions, r, diagnostics}, 60_000
            assert_receive {:DOWN, ^ref, :process, _, :normal}, 60_000

            assert Enum.map(diagnostics, &(&1.message =~ "did you mean")) ==
                     List.duplicate(true, min(n, 100)) ++ List.duplicate(false, n - min(n, 100))

            r
          end
        )
      end

      # 1.25x at the tip, the hundred names offered a suggestion at both sizes costing the
      # same; a refusal linear in its names would read 4x, and the match of every name
      # against every name declared, as before decision 520, 16x. The bound lets the
      # linear pass and turns the quadratic red.
      ratio = cost.(400) / cost.(100)
      assert ratio < 6.0, "4x the names gone took #{Float.round(ratio, 2)}x the reductions"
    end

    # The first hundred in line order, whatever check finds them: a jump's label, which the
    # jump checks find after every tag, is offered one on its line before a hundred names
    # gone, and the hundredth name none.
    test "the first hundred names gone in line order are offered one, a label's among them" do
      source =
        IO.iodata_to_binary([
          "var a bool\n",
          for(i <- 1..100, do: "var pushbutton_start_#{i} bool\n"),
          "xic a jmp donee\n",
          for(i <- 1..100, do: "xic pushbuton_start_#{i} ote a\n"),
          "lbl done xic a ote a\n"
        ])

      assert {:error, [jump | names]} = Logex.compile(source, name: "p")
      assert jump.line == 102
      assert jump.message =~ "— did you mean `done`?"
      assert length(names) == 100

      assert Enum.map(names, &(&1.message =~ "did you mean")) ==
               List.duplicate(true, 99) ++ [false]
    end
  end

  # RV-20's review (findings 2 and 4): a message that ends with a list, a type's members
  # or the blocks a compile was given, gave it whole after the hundred too, so 16,000
  # unknown members of a block of 1,000 made 174.5 MB of messages, and 4,000 lines naming
  # a misspelt type among 500 blocks given 49.7 MB, the second matched against all 500 at
  # every line. Each of the hundred gives its list as ever, and after them a list is given
  # once, by the first message that would give it, none where one before gave it.
  describe "a list past the hundred (decision 520)" do
    defp section(name) do
      {:ok, type} =
        Logex.compile(
          "function_block #{name}\nvar_input go bool\nvar_output run bool\nxic go ote run\n",
          name: name
        )

      type
    end

    test "is given once, by the first message that would give it, none where one before did" do
      source =
        IO.iodata_to_binary([
          "var a bool\nvar q bool\nvar t ton\nvar b big\nxic a ton t 10\nxic a cal b a q\n",
          List.duplicate("xic t.zz ote a\n", 100),
          "xic t.yy ote a\nxic b.zz ote a\nxic b.yy ote a\nvar s1 sectoin\nvar s2 sectoin\n"
        ])

      assert {:error, diagnostics} =
               Logex.compile(source, name: "p", types: [section("big"), section("section")])

      {hundred, past} = Enum.split(diagnostics, 100)

      assert Enum.uniq(Enum.map(hundred, & &1.message)) == [
               "`t.zz` is not a member of `t`, a ton: its members are `pre`, `acc`, `dn`, " <>
                 "`tt` and `en`"
             ]

      after_first = "`var` after the first rung (line 5): declarations come first"

      logex_has =
        "logex has `bool`, `sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, " <>
          "`ulint`, `real`, `lreal`, `byte`, `word`, `dword`, `lword`, `ctd`, `ctd_dint`, " <>
          "`ctd_int`, `ctd_lint`, `ctd_udint`, `ctd_ulint`, `ctu`, `ctu_dint`, `ctu_int`, " <>
          "`ctu_lint`, `ctu_udint`, `ctu_ulint`, `ctud`, `ctud_dint`, `ctud_int`, " <>
          "`ctud_lint`, `ctud_udint`, `ctud_ulint`, `rto`, `rto_ltime`, `tof`, `tof_ltime`, " <>
          "`ton`, `ton_ltime`, `tp` and `tp_ltime`"

      assert Enum.map(past, &{&1.line, &1.message}) == [
               {107, "`t.yy` is not a member of `t`, a ton"},
               {108,
                "`b.zz` is not a member of `b`, an instance of `big`: its members are `go` " <>
                  "and `run`"},
               {109, "`b.yy` is not a member of `b`, an instance of `big`"},
               {110, after_first},
               {110,
                "unknown type `sectoin`: " <>
                  logex_has <> ", and the function blocks `big` and `section`"},
               {111, after_first},
               {111, "unknown type `sectoin`: " <> logex_has}
             ]
    end

    # Each of the hundred lists the block's members or the blocks given, and the names
    # after them once: their text grows with the lists and the names, 4x at 4x each, where
    # every name giving its list made it grow as their product, 16x.
    test "keeps the refusal's text near the count of its names and its lists" do
      members = fn n, gone ->
        {:ok, big} =
          Logex.compile(
            IO.iodata_to_binary([
              "function_block big\nvar_input go bool\n",
              for(i <- 1..n, do: "var_output out_#{i} bool\n"),
              "xic go ote out_1\n"
            ]),
            name: "big"
          )

        lines = for i <- 1..gone, do: "xic b.zz_#{i} ote a\n"

        {IO.iodata_to_binary(["var a bool\nvar q bool\nvar b big\nxic a cal b a q\n", lines]),
         [big]}
      end

      types = fn n, gone ->
        given = for b <- 1..n, do: section("section_#{b}")
        lines = for i <- 1..gone, do: "var s#{i} sectoin_#{i}\n"
        {IO.iodata_to_binary([lines, "var a bool\nxic a ote a\n"]), given}
      end

      for {kind, shape} <- [members: members, types: types] do
        bytes = fn n, gone ->
          {source, given} = shape.(n, gone)
          assert {:error, diagnostics} = Logex.compile(source, name: "p", types: given)
          Enum.sum(Enum.map(diagnostics, &byte_size(&1.message)))
        end

        ratio = bytes.(200, 1600) / bytes.(50, 400)

        assert ratio < 6.0,
               "4x the #{kind} and 4x the names gone made #{Float.round(ratio, 2)}x the text"
      end
    end
  end

  # RV-20's review (finding 3): a name past the hundredth is offered nothing, so its look-up
  # is never made: the tags' names, the later labels, a type's members and the blocks given
  # are each gathered in a function `Logex.Declarations.offered/1` calls only for the
  # hundred, and a list after them once. Built eagerly, each a BIF's work or a list's, the
  # reductions barely move, while the words grow as the names gone times those declared,
  # 0.59 s against 8.5 s for 16,000 names gone among a box counter's 4,000 tags. So the
  # words a compile allocates are counted, in a process whose heap no collection visits
  # during it, which a trace of its collections checks: two twins, a hundred unknown
  # members of a ton first, then `m` lines naming a tag, a label, a member or a type that
  # is not there, or one that is, compiled by `Logex.Compiler.compile/2` in that process,
  # the twins' difference the cost of `m` names past the hundred, at `n` and 4n names
  # declared. Measured at the tip: 0.97x, 1.00x, 1.31x and 1.03x; each built eagerly 3.42x,
  # 3.76x, 3.73x and 3.34x.
  describe "a name past the hundredth (decision 520)" do
    defp allocated(source, types) do
      parent = self()

      {pid, ref} =
        :erlang.spawn_opt(
          fn ->
            :erlang.garbage_collect()
            send(parent, {:ready, self()})
            assert_receive :go, 60_000
            result = Logex.Compiler.compile(source, name: "p", types: types)
            send(parent, {:done, self()})
            assert_receive :stop, 60_000
            exit({:ok, result})
          end,
          [:monitor, min_heap_size: 10_000_000, min_bin_vheap_size: 50_000_000]
        )

      assert_receive {:ready, ^pid}, 60_000
      {:garbage_collection_info, before} = Process.info(pid, :garbage_collection_info)
      :erlang.trace(pid, true, [:garbage_collection])
      send(pid, :go)
      assert_receive {:done, ^pid}, 60_000
      {:garbage_collection_info, later} = Process.info(pid, :garbage_collection_info)
      traced = :erlang.trace_delivered(pid)
      assert_receive {:trace_delivered, ^pid, ^traced}, 60_000
      send(pid, :stop)
      assert_receive {:DOWN, ^ref, :process, ^pid, {:ok, {:error, [_ | _]}}}, 60_000
      refute_received {:trace, ^pid, _collection, _info}, "collected during the compile"
      later[:heap_size] - before[:heap_size]
    end

    # A hundred unknown members of a ton, each matched against its five members.
    defp past(head, lines),
      do:
        IO.iodata_to_binary([
          head,
          "xic a ton t 10\n",
          List.duplicate("xic t.zz ote a\n", 100),
          lines
        ])

    defp twin(:tags, n, m, gone) do
      declared = for i <- 1..n, do: "var pushbutton_start_#{i} bool\n"

      lines =
        for i <- 1..m,
            do:
              "xic #{named(gone, "pushbuton_start_#{i}", "pushbutton_start_#{rem(i - 1, n) + 1}")} ote a\n"

      {past(["var a bool\nvar t ton\n" | declared], lines), []}
    end

    defp twin(:labels, n, m, gone) do
      lines = [
        for(i <- 1..m, do: "xic a #{named(gone, "jmp gone_#{i}", "ote a")}\n"),
        for(i <- 1..n, do: "lbl station_#{i} xic a ote a\n")
      ]

      {past("var a bool\nvar t ton\n", lines), []}
    end

    defp twin(:members, n, m, gone) do
      {:ok, big} =
        Logex.compile(
          IO.iodata_to_binary([
            "function_block big\nvar_input go bool\n",
            for(i <- 1..n, do: "var_output out_#{i} bool\n"),
            "xic go ote out_1\n"
          ]),
          name: "big"
        )

      lines =
        for i <- 1..m, do: "xic b.#{named(gone, "ot_#{i}", "out_#{rem(i - 1, n) + 1}")} ote a\n"

      {past("var a bool\nvar t ton\nvar b big\nxic a cal b\n", lines), [big]}
    end

    # A declaration after the first rung is refused for its place in both twins alike.
    defp twin(:types, n, m, gone) do
      types =
        for b <- 1..n do
          {:ok, type} =
            Logex.compile(
              "function_block section_#{b}\nvar_input go bool\nvar_output run bool\nxic go ote run\n",
              name: "section_#{b}"
            )

          type
        end

      lines = for i <- 1..m, do: "var s#{i} #{named(gone, "sectoin_1", "bool")}\n"
      {past("var a bool\nvar t ton\n", lines), types}
    end

    defp named(true, gone, _there), do: gone
    defp named(false, _gone, there), do: there

    defp past_hundred(kind, n, m) do
      {there, types} = twin(kind, n, m, false)
      {gone, types_gone} = twin(kind, n, m, true)
      allocated(gone, types_gone) - allocated(there, types)
    end

    test "costs the same whatever the text declares, a tag's, a label's, a member's and a type's" do
      # Every module the compile calls loaded before any count, here, since a process that
      # loads one is collected as it does.
      for kind <- [:tags, :labels, :members, :types], gone <- [true, false] do
        {source, types} = twin(kind, 5, 5, gone)
        assert {:error, [_ | _]} = Logex.Compiler.compile(source, name: "p", types: types)
      end

      for {kind, n} <- [tags: 250, labels: 250, members: 250, types: 100] do
        ratio = past_hundred(kind, 4 * n, 400) / past_hundred(kind, n, 400)

        assert ratio < 2.0,
               "400 #{kind} past the hundred took #{Float.round(ratio, 2)}x the words " <>
                 "among 4x the names declared"
      end
    end
  end

  describe "Logex.Name, the one reading of a lexed name's parts" do
    test "element/1 reads one word and one pair of brackets closing it, and nothing else" do
      assert Name.element("grid[1,7]") == {"grid", ["1", "7"]}
      assert Name.element("temps[16#3]") == {"temps", ["16#3"]}
      assert Name.element("w[slot]") == {"w", ["slot"]}
      assert Name.element("x.y[0]") == {"x.y", ["0"]}

      for text <-
            ["grid", "int[2].[n]", "lines[1].gates[0]", "temps[", "[n]", "a[]", "a[1,]"] ++
              ["a[1", "a]", "a[1]]", "a[[1]", "a[1][2]", "a[1]x", ""] do
        assert Name.element(text) == nil, inspect(text)
      end
    end

    test "subscript/1 reads one integer literal or a tag's name" do
      assert Name.subscript("16#a") == {:literal, 10}
      assert Name.subscript("-1") == {:literal, -1}
      assert Name.subscript("007") == {:literal, 7}
      assert Name.subscript("slot") == {:tag, "slot"}
      # No one integer literal, which the lexer never gives in a name: no number.
      assert Name.subscript("1x") == {:tag, "1x"}
      assert Name.subscript("1.5") == {:tag, "1.5"}
      assert Name.subscript("1 2") == {:tag, "1 2"}
    end

    test "bracketed/1, base/1 and word/1" do
      assert Name.bracketed("[16#4]") == {:literal, 4}
      assert Name.bracketed("[n]") == {:tag, "n"}

      # RV-2's review: each reader is total on a text, so a text of no bit number in
      # brackets is nil, where `x`, `[` and `[1` raised FunctionClauseError.
      for text <- ["x", "[", "[1", "[]", "n]", ""] do
        assert Name.bracketed(text) == nil, text
      end

      assert Name.base("gate[4]") == "gate"
      assert Name.base("ton") == "ton"
      assert Name.base("gate[2].x") == "gate[2].x"
      assert Name.base("a.b") == "a.b"
      assert Name.word("temps[2") == "temps"
      assert Name.word("temps") == nil
    end

    # RV-26's review (decision 527): a name as a store's digest reads it, each number in
    # it by its value, a tag's name and a word as written; total on a text, as the other
    # readers are.
    test "each_by_value/1 reads each number in a name by its value, and is total" do
      for {text, valued} <- [
            {"arr[16#2]", "arr[2]"},
            {"arr[0_2]", "arr[2]"},
            {"a[-0]", "a[0]"},
            {"g[01,i]", "g[1,i]"},
            {"int[004]", "int[4]"},
            {"w.03", "w.3"},
            {"w.[16#4]", "w.[4]"},
            {"w.[n]", "w.[n]"},
            {"lines[01].gates[0_0].q", "lines[1].gates[0].q"},
            {"Tl[1].DN", "Tl[1].DN"},
            {"x", "x"},
            {"x.y", "x.y"}
          ],
          do: assert(Name.each_by_value(text) == valued, text)

      for text <-
            ["", ".", "a.", "a..b", "[", "[]", "a[", "a[]", "a[1,,2]", "t.[", "w.3x"] ++
              ["x[1]y", "a[1 ]", "a[3//x]"],
          do: assert(Name.each_by_value(text) == text, inspect(text))
    end
  end

  describe "M13: a number past what logex reads" do
    # The mask 2^n was made before the bit's range was judged: `w.10000000` raised
    # SystemLimitError, and `x.99999999` took some 7 s first.
    test "a bit number past its word's bits is told so before its mask is made" do
      for {name, n, of} <- [
            {"w.10000000", "10000000",
             "`w`, a word (declared on line 1), which has bits 0 to 15"},
            {"w.[99999999999999999999]", "99999999999999999999",
             "`w`, a word (declared on line 1), which has bits 0 to 15"},
            {"t.acc.2147483648", "2147483648", "`t.acc`, a dint, which has bits 0 to 31"}
          ] do
        source = "var w word\nvar t ton\nvar b bool\nxic #{name} ote b"

        {micros, result} = :timer.tc(fn -> compiled(source) end)
        assert result == {:error, ["line 4: `#{name}` names bit #{n} of #{of}"]}, name
        assert micros < 2_000_000, name
      end

      digits = String.duplicate("9", 9_000)
      assert {:error, [message]} = compiled("var w word\nvar b bool\nxic w.#{digits} ote b")
      assert message =~ "names bit #{digits} of `w`"
    end

    # Decision 369: a number is at most 10,000 characters, an exponent at most 9,999.
    test "a literal of more than 10,000 characters is a located lex error, quoted by its start" do
      assert Logex.Lexer.longest_number() == 10_000

      long = String.duplicate("9", 10_001)

      assert compiled("var x lint\nmove #{long} x") ==
               {:error,
                [
                  "line 2, column 6: \"999999999999999999999999…\" is no number logex reads: " <>
                    "a number is written in at most 10000 characters, and this one has 10001"
                ]}

      assert {:error, [message]} = compiled("var x lint\nmove #{String.duplicate("9", 10_000)} x")
      assert message =~ "line 2: `move` writes `999"

      for text <- [
            "16#" <> String.duplicate("f", 4_000_000),
            "1_" <> String.duplicate("1", 10_000),
            "-" <> String.duplicate("1", 10_000),
            String.duplicate("1", 1_262_593),
            String.duplicate("1", 6_000) <> "." <> String.duplicate("1", 6_000)
          ] do
        assert {:error, [message]} = compiled("var x lint\nmove #{text} x")
        assert message =~ "is no number logex reads: a number is written in at most 10000 ", text
      end
    end

    test "a subscript or a bit's number past it makes the name a located lex error" do
      for {name, column} <- [
            {"a[#{String.duplicate("1", 10_001)}]", 6},
            {"w.#{String.duplicate("1", 10_001)}", 6},
            {"w.[#{String.duplicate("1", 10_001)}]", 6},
            {"w.[-#{String.duplicate("1", 10_001)}]", 6}
          ] do
        assert {:error, [message]} = compiled("var w word\nmove #{name} w")

        assert message =~ ~s(line 2, column #{column}: "#{String.slice(name, 0, 24)}…" is no name),
               name

        assert message =~
                 "a number in a name, a subscript or a bit's number, is written in at most 10000 characters"
      end
    end

    test "an exponent past 9,999 is a located lex error, `0.0e10000000` among them" do
      for text <- ["0.0e10000000", "0.0e-4000000", "1.0e10000", "0.0e99999999999", "1.0e1_0000"] do
        assert compiled("var r lreal\nmove #{text} r") ==
                 {:error,
                  [
                    "line 2, column 6: #{inspect(text)} is no number logex reads: a real's " <>
                      "exponent is at most 9999, `e9999` or `e-9999`"
                  ]},
               text
      end

      assert {:ok, _warnings} = compiled("var_output r lreal\nmove 0.0e9999 r")

      assert {:error, [message]} = compiled("var r lreal\nmove 1.0e-9999 r")
      assert message =~ "it is too near 0.0 for an lreal"

      assert {:error, [message]} = compiled("var x real 0.0e4000000")
      assert message =~ "line 1, column 12: \"0.0e4000000\" is no number logex reads"

      assert {:error, [%Diagnostic{stage: :lex, line: 1, column: 20} = d]} =
               Logex.Configuration.compile("c", "var_global g lreal 0.0e4000000\n", %{})

      assert d.message =~ "is no number logex reads: a real's exponent is at most 9999"
    end

    test "an initial list of reals of large exponents compiles in bounded time" do
      literals = Enum.map_join(1..2_000, " ", fn _ -> "0.0e9999" end)
      {micros, result} = :timer.tc(fn -> compiled("var a lreal[2000] " <> literals) end)
      assert {:ok, _warnings} = result
      assert micros < 5_000_000
    end

    test "a block type whose text holds either number is no type, and nothing raises" do
      {:ok, b} =
        block("function_block b\nvar_input x word\nvar_output y bool\nxic x.3 ote y\n", "b")

      for text <- [
            "function_block b\nvar_input x word\nvar_output y bool\nxic x.99999999 ote y\n",
            "function_block b\nvar_input x word\nvar_output y real\nxic x.3 move 0.0e10000000 y\n",
            "function_block b\nvar_input x word\nvar_output y lint\nxic x.3 move " <>
              String.duplicate("9", 2_000_000) <> " y\n"
          ] do
        type = %{b | body: %{b.body | source: text}}
        refute Logex.FbType.user?(type)
        assert_raise ArgumentError, fn -> Logex.compile("var q b\n", name: "p", types: [type]) end
        assert_raise ArgumentError, fn -> Logex.Tag.new!("q", type) end
      end
    end

    test "the store's and the forces file's number reader refuses one past it" do
      assert Logex.Retain.number(String.duplicate("9", 10_000)) ==
               {:ok, String.to_integer(String.duplicate("9", 10_000))}

      assert Logex.Retain.number(String.duplicate("9", 2_000_000)) == :error
      assert Logex.Retain.number("16#" <> String.duplicate("f", 2_000_000)) == :error
      assert Logex.Retain.number("0.0e10000000") == :error
    end
  end

  # A seeded mutation walk of the shapes the review met: every mutant compiles to a
  # program, a block or diagnostics, and none raises.
  @corpus [
    "var_input a bool\nvar_output b bool\n( | xic a ) ote b",
    "var a bool\nvar t ton\nvar n int\nxic t.[3] ote a\nxic t.[n] ote a",
    "var_input a bool\nvar s bool\nvar lc ctu[2]\nvar i int\nxic a osr s lc[1].pv.0\nxic a osr s lc[i].pv.0",
    "var w word\nvar a int[2]\nvar o bool\nxic w.[a] ote o\nxic w[1].[a] ote o",
    "var a bool\nvar q bool\nvar g seal[2]\nvar n int\ncal g[1].[0] a q\ncal g[n].x a q\ncal g[1] a q",
    "var p int[2].[n]\nvar q ton[2].[1]\nvar_input r int[2]\nmove r[1] q",
    "var w word\nvar r lreal\nmove 0.0e999 r\nxic w.99 ote w.3\nmove 16#ffff w",
    "var_input b bool\nvar_output o bool\nvar cl ctu[2]\nxic b ons cl[1].pv.3 ote o\nxic b ctu cl[1] 5"
  ]

  @alphabet ~c"abcxyz019_.[],-#eE() |\t\n" ++ [?r, ?s, ?t, ?p, ?v]

  test "a seeded mutation walk of the review's shapes raises nowhere, in a program and a block" do
    :rand.seed(:exsss, {2026, 11, 351})
    types = [seal()]

    raised =
      for _ <- 1..3_000,
          source = mutate(Enum.random(@corpus)),
          {text, name} <- [{source, "m"}, {"function_block fz\n" <> source, "fz"}],
          problem = escaped(text, name, types),
          do: problem

    assert raised == []
  end

  defp escaped(text, name, types) do
    Logex.compile(text, name: name, types: types)
    nil
  rescue
    error -> {text, Exception.message(error)}
  end

  defp mutate(source) do
    bytes = :binary.bin_to_list(source)

    Enum.reduce(1..:rand.uniform(4), bytes, fn _, b -> mutated(:rand.uniform(5), b) end)
    |> :binary.list_to_bin()
  end

  defp mutated(_kind, []), do: [Enum.random(@alphabet)]
  defp mutated(1, b), do: List.delete_at(b, :rand.uniform(length(b)) - 1)
  defp mutated(2, b), do: List.insert_at(b, :rand.uniform(length(b)) - 1, Enum.random(@alphabet))
  defp mutated(3, b), do: List.replace_at(b, :rand.uniform(length(b)) - 1, Enum.random(@alphabet))

  defp mutated(4, b),
    do: List.insert_at(b, :rand.uniform(length(b)) - 1, Enum.at(b, :rand.uniform(length(b)) - 1))

  defp mutated(5, b) do
    i = :rand.uniform(length(b)) - 1
    Enum.take(b, i) ++ Enum.slice(b, i, 3) ++ Enum.drop(b, i)
  end
end
