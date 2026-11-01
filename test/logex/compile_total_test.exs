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
            {"xic nowhere_declared", "line 11: `nowhere_declared` is not declared"}
          ] do
        assert {:error, [found]} = compiled(@io <> rung)
        assert found =~ message, rung
      end
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
      assert Name.base("gate[4]") == "gate"
      assert Name.base("ton") == "ton"
      assert Name.base("gate[2].x") == "gate[2].x"
      assert Name.base("a.b") == "a.b"
      assert Name.word("temps[2") == "temps"
      assert Name.word("temps") == nil
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

    # Provisional: a number is at most 10,000 characters, an exponent at most 9,999.
    test "a literal of more than 10,000 characters is a located lex error, quoted by its start" do
      assert Logex.Lexer.longest_number() == 10_000

      long = String.duplicate("9", 10_001)

      assert compiled("var x lint\nmove #{long} x") ==
               {:error,
                [
                  "line 2, column 6: `999999999999999999999999…` is no number logex reads: " <>
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

        assert message =~ "line 2, column #{column}: `#{String.slice(name, 0, 24)}…` is no name",
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
