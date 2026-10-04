defmodule Logex.FunctionBlockTest do
  @moduledoc """
  M2-5: user function blocks (PLAN.md §3, Milestone 2; docs/organisation.md §4.3 and
  §4.10). A file whose first rung is `function_block <name>` compiles to its type; a
  program declares instances of it, `var s1 seal`, given the type through
  `Logex.compile/2`'s `types:`; `cal` runs one, rung power its EN, nothing copied on a
  false EN (decision 12). Every diagnostic list here is asserted whole, from source. The
  Done-when is `end_to_end_test.exs`'s, through a configuration and `Logex.Runtime.get/2`.
  An online edit of a program that holds blocks is here too: an instance moves whole, and
  any change to its block is refused.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Diagnostic, Edit, FbType, Instance, Runtime, Scan, Tag}

  @seal """
  function_block seal
  var_input start bool
  var_input stop bool
  var_output run bool

  ( xic start | xic run ) xio stop ote run
  """

  defp block!(source, types \\ []) do
    [_, name] = Regex.run(~r/\Afunction_block (\w+)/, source)
    {:ok, %FbType{} = type} = Logex.compile(source, name: name, types: types)
    type
  end

  defp program!(source, types, name \\ "m") do
    {:ok, program} = Logex.compile(source, name: name, types: types)
    program
  end

  defp errors(source, types \\ [], name \\ "m") do
    {:error, diagnostics} = Logex.compile(source, name: name, types: types)
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  defp warnings(%Logex.Program{warnings: warnings}), do: Enum.map(warnings, &Diagnostic.format/1)

  # One scan with these inputs set first, `ms` after the last.
  defp step(program, state, inputs, ms \\ 10),
    do: Runtime.scan(program, Runtime.put_inputs(program, state, inputs), ms)

  defp drive(program, state, steps),
    do:
      Enum.reduce(steps, {%{}, state}, fn {ms, inputs}, {_, state} ->
        step(program, state, inputs, ms)
      end)

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # A host mistake the type checker can see is a warning on every run; this hides it.
  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  defp ast(source) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(source)
    {:ok, ast} = Logex.Compiler.parse(tokens)
    ast
  end

  @three """
  var_input a1 bool
  var_input a2 bool
  var_input a3 bool
  var_input stop bool
  var_input en3 bool
  var_output k1 bool
  var_output k2 bool
  var_output k3 bool
  var_output lamp bool
  var s1 seal
  var s2 seal
  var s3 seal

  cal s1 a1 stop k1
  cal s2 a2 stop k2
  xic en3 cal s3 a3 stop k3
  xic s2.run ote lamp
  """

  @pulse """
  function_block pulse
  var_input go bool
  var_output q bool
  var edge bool
  var t1 ton

  xic go ons edge ote q
  xic go ton t1 100
  """

  @runs_pulse """
  var_input a bool
  var_input en bool
  var_output y bool
  var p pulse

  xic en cal p a y
  """

  describe "a function block's file" do
    test "compiles to its type: its members in declaration order, its body a program" do
      seal = block!(@seal)
      assert %FbType{name: "seal", body: %Logex.Program{name: "seal", source: @seal}} = seal

      assert for(m <- seal.members, do: {m.name, m.type, m.role, m.write, m.initial}) == [
               {"start", :bool, :input, false, 0},
               {"stop", :bool, :input, false, 0},
               {"run", :bool, :output, false, 0}
             ]

      assert FbType.user?(seal)
      assert FbType.public(seal) == seal.members
      assert FbType.writable(seal) == []
    end

    test "a var is local: in the state, named only inside the block" do
      latch =
        block!("""
        function_block latch
        var_input set bool
        var_output q bool
        var held bool 1
        var t1 ton

        xic set otl held
        xic held ote q
        xic held ton t1 250
        """)

      assert for(m <- latch.members, do: {m.name, m.role, m.initial}) == [
               {"set", :input, 0},
               {"q", :output, 0},
               {"held", :local, 1},
               {"t1", :local, %{"pre" => 250}}
             ]

      assert Enum.map(FbType.public(latch), & &1.name) == ["set", "q"]

      assert errors("var l1 latch\nvar_output y bool\nxic l1.held ote y", [latch]) == [
               "line 3: `l1.held` is not a member of `l1`, an instance of `latch`: its members " <>
                 "are `set` and `q`"
             ]
    end

    test "its first line names it as it is compiled, and as its file is named" do
      assert errors(@seal, [], "latch") == [
               "line 1: this function block is `seal`, but it is compiled as `latch`: " <>
                 "a block is named after its file"
             ]

      # With the source's own mistakes, in line order.
      assert errors(@seal <> "xic zz ote run\n", [], "latch") == [
               "line 1: this function block is `seal`, but it is compiled as `latch`: " <>
                 "a block is named after its file",
               "line 7: `zz` is not declared"
             ]

      assert errors("function_block\nvar_output q bool\nxic q ote q", [], "x") == [
               "line 1: `function_block` takes the block's name, as in `function_block seal`"
             ]

      assert errors("function_block x y\nvar_output q bool\nxic q ote q", [], "x") == [
               "line 1: `function_block` takes the block's name, as in `function_block seal`"
             ]

      assert errors("function_block move\nvar_output q bool\nxic q ote q", [], "move") == [
               "line 1: `move` is an instruction and cannot name a function block"
             ]

      assert errors("function_block Var_Input\nvar_output q bool\nxic q ote q", [], "Var_Input") ==
               ["line 1: `Var_Input` is a keyword and cannot name a function block"]

      # A name no compile/2 call takes, through instructionize/3, which names nothing.
      assert {:error, [diagnostic]} =
               Logex.Compiler.instructionize(
                 ast("function_block a.b\nvar_output q bool\nxic q ote q")
               )

      assert Diagnostic.format(diagnostic) ==
               "line 1: `a.b` cannot name a function block: a name is a letter or `_`, then " <>
                 "letters, digits or `_`"

      # The word that heads a block's file is reserved in one (docs/organisation.md §4.8),
      # where a block's name is spelled as a type word.
      assert errors(
               "function_block Function_Block\nvar_output q bool\nxic q ote q",
               [],
               "Function_Block"
             ) == [
               "line 1: `Function_Block` is a keyword and cannot name a function block"
             ]

      named = block!("function_block fb\nvar_output q bool\nxic q ote q")
      body = %{named.body | name: "function_block"}
      refute FbType.user?(%{named | name: "function_block", body: body})
      refute FbType.user?(%{named | name: "ton", body: %{body | name: "ton"}})
    end

    test "function_block is reserved in a block's file only, and heads it" do
      assert errors(
               "function_block b\nvar function_block bool\nxic function_block ote function_block",
               [],
               "b"
             ) == [
               "line 2: `function_block` heads a function block's file and cannot name a tag in one"
             ]

      assert {:ok, _} =
               Logex.compile("var function_block bool\nxic function_block ote function_block",
                 name: "p"
               )

      assert errors("var_output q bool\nfunction_block seal") == [
               "line 2: `function_block` heads a function block's file, as its first line"
             ]

      # A block's own name is not reserved (docs/organisation.md §4.10): `var seal seal`.
      assert {:ok, _} =
               Logex.compile("var seal seal\nvar_input a bool\nvar_output q bool\ncal seal a a q",
                 name: "p",
                 types: [block!(@seal)]
               )
    end

    # One message at every entry point that takes a program (docs/organisation.md §4.10),
    # naming the instruction that runs the type: `cal` for a user block, `ton` for a timer.
    test "a block is not a program: the runtime and the edit refuse its type" do
      seal = block!(@seal)

      message =
        "`seal` is a function block type, which runs inside a program through `cal`: " <>
          "an instance is of a %Logex.Program{}"

      motor = program!(@three, [seal])
      state = Runtime.instance(motor)
      raises(message, fn -> Runtime.instance(opaque(seal)) end)
      raises(message, fn -> Runtime.scan(opaque(seal), state) end)
      raises(message, fn -> Runtime.put_inputs(opaque(seal), state, %{}) end)
      raises(message, fn -> Runtime.restart(opaque(seal), state, :cold) end)

      raises(message, fn ->
        Runtime.call(opaque(seal), state, %{}, %Scan{now: 0, first: true})
      end)

      raises(message, fn -> Edit.accept(motor, opaque(seal), state) end)
      raises(message, fn -> Edit.accept(opaque(seal), motor, state) end)

      raises(
        "`ton` is a function block type, which runs inside a program through `ton`: " <>
          "an instance is of a %Logex.Program{}",
        fn -> Runtime.instance(opaque(FbType.ton())) end
      )
    end

    test "its header is its first rung: comments and blank lines may come before it" do
      source = "// a seal-in, run by cal\n\n" <> @seal

      assert {:ok, %FbType{name: "seal", body: %{source: ^source}}} =
               Logex.compile(source, name: "seal")

      # And the word is recognised in any case, as every keyword is.
      upper = String.replace(@seal, "function_block", "FUNCTION_BLOCK")
      assert {:ok, %FbType{name: "seal"}} = Logex.compile(upper, name: "seal")
    end
  end

  describe "the types a compile is given" do
    test "each must be one Logex.compile/2 gave, no two of one name" do
      seal = block!(@seal)

      raises(
        "types must be a list of function block types from Logex.compile/2, got: :seal",
        fn ->
          Logex.compile("var s1 seal", name: "m", types: opaque(:seal))
        end
      )

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(FbType.ton())}",
        fn ->
          Logex.compile("var s1 seal", name: "m", types: [FbType.ton()])
        end
      )

      edited = %{seal | members: Enum.drop(seal.members, 1)}

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
        fn ->
          Logex.compile("var s1 seal", name: "m", types: [edited])
        end
      )

      raises("types holds two function blocks named `seal`: one name, one type", fn ->
        Logex.compile("var s1 seal", name: "m", types: [seal, seal])
      end)

      # The options come in either order, and the message names both.
      assert {:ok, _} = Logex.compile("var s1 seal", types: [seal], name: "m")

      raises(
        "Logex.compile/2 takes a name and, where the source uses function blocks, their " <>
          ~s|types, as in Logex.compile(source, name: "motor", types: [seal]), | <>
          ~s|got: [types: [], name: "m", file: "x"]|,
        fn -> Logex.compile("var s1 seal", opaque(types: [], name: "m", file: "x")) end
      )
    end

    # The body of a type given is one a compile gives (Logex.Compiler.lowered?/1): a rung
    # edited by hand is refused where the type is given, never met by the runtime or an
    # edit, however it is shaped, and whether the text could say it or not.
    test "a type whose body was edited by hand is refused where it is given" do
      seal = block!(@seal)
      [{:rung, rung}] = seal.body.rungs

      edits = [
        [{:rung, [{:bogus, 6, []}]}],
        :garbage,
        ["hello"],
        [{:rung, []}],
        [{:rung, [{:xic, 6, [{:name, 6, "nope"}]}, {:ote, 6, [{:name, 6, "run"}]}]}],
        [{:rung, [{:xic, 0, [{:name, 0, "start"}]}, {:ote, 0, [{:name, 0, "run"}]}]}],
        [{:rung, [{:move, 6, [{:int_lit, 6, 5}, {:member, 6, ["run", "x"]}]}]}],
        [{:rung, [{:xic, 6, [{:name, 6, "run"}]}, {:ote, 6, [{:name, 6, "start"}]}]}],
        [{:rung, [{:xic, 6, [{:name, 6, "start"}]}, {:ote, 7, [{:name, 7, "run"}]}]}],
        [{:rung, rung}, {:rung, rung}],
        [{:rung, rung ++ [{:cal, 6, [{:name, 6, "zz"}]}]}],
        [{:rung, [{:xic, 6, [{:name, 6, "start"}]} | :tail]}]
      ]

      for rungs <- edits do
        edited = %{seal | body: %{seal.body | rungs: rungs}}
        refute FbType.user?(edited)

        raises(
          "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
          fn ->
            Logex.compile("var s1 seal", name: "m", types: [edited])
          end
        )

        assert_raise ArgumentError, ~r/unknown function block type "seal"/, fn ->
          Tag.new!("s1", edited)
        end
      end

      # And its warnings are the ones its rungs give, a file aside.
      refute FbType.user?(%{seal | body: %{seal.body | warnings: [:junk]}})
      assert FbType.user?(seal)

      # A tag named as no declaration line could name it, every use of it renamed too.
      renamed = fn body, from, to ->
        tags =
          Map.new(body.tags, fn
            {^from, tag} -> {to, %{tag | name: to}}
            entry -> entry
          end)

        rungs =
          Enum.map(body.rungs, fn {:rung, elements} ->
            {:rung,
             Enum.map(elements, fn
               {symbol, line, operands} ->
                 {symbol, line,
                  Enum.map(operands, fn
                    {:name, l, ^from} -> {:name, l, to}
                    operand -> operand
                  end)}

               group ->
                 group
             end)}
          end)

        FbType.of(%{body | tags: tags, rungs: rungs})
      end

      pulse = block!(@pulse)
      assert FbType.user?(renamed.(pulse.body, "edge", "edge2"))
      refute FbType.user?(renamed.(pulse.body, "edge", "a b"))
      refute FbType.user?(renamed.(pulse.body, "edge", "xic"))
      refute FbType.user?(renamed.(pulse.body, "edge", "Function_Block"))

      # A type holding two versions of one block, or a block of its own name, or a timer
      # that is not logex's, none of which a compile gives.
      v2 = block!(String.replace(@seal, "xio stop", "xio stop xic start"))
      seal = block!(@seal)

      holder =
        block!(
          "function_block holder\nvar_input go bool\nvar_output o bool\nvar s seal\n" <>
            "var t seal\ncal s go go o\ncal t go go o",
          [seal]
        )

      retyped = fn type, tag, to ->
        tags = Map.update!(type.body.tags, tag, &%{&1 | type: to})
        FbType.of(%{type.body | tags: tags})
      end

      assert FbType.user?(holder)
      refute FbType.user?(retyped.(holder, "t", v2))
      refute FbType.user?(retyped.(holder, "t", %{holder | name: "seal"}))

      # `b` holding an instance of `b`, whose inputs and outputs are `a`'s, so that its rung
      # still lowers: a type of its own name at depth.
      a = block!("function_block a\nvar_input go bool\nvar_output q bool\nxic go ote q")

      b =
        block!("function_block b\nvar_input go bool\nvar_output q bool\nvar x a\ncal x go q", [a])

      assert FbType.user?(b)
      refute FbType.user?(retyped.(b, "x", b))

      refute FbType.user?(
               retyped.(pulse, "t1", %{FbType.ton() | members: tl(FbType.ton().members)})
             )

      # A timer's preset is the number on the `ton` that runs it.
      [ons_rung, {:rung, [contact, {:ton, line, [timer, {:int_lit, at, 100}]}]}] =
        pulse.body.rungs

      represet = [ons_rung, {:rung, [contact, {:ton, line, [timer, {:int_lit, at, 200}]}]}]
      refute FbType.user?(%{pulse | body: %{pulse.body | rungs: represet}})
    end

    test "a type holds one version of each block, the one given under its name" do
      old = block!(@seal)

      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_output o bool\nvar s seal\ncal s go go o",
          [old]
        )

      new = block!(String.replace(@seal, "xio stop", "xio stop xic start"))

      message =
        "types holds two different function blocks named `seal`, one inside another type " <>
          "given: compile each block against the same types"

      raises(message, fn -> Logex.compile("var o outer", name: "m", types: [new, outer]) end)

      # The types are checked as given, whether or not the source uses them all.
      raises(message, fn -> Logex.compile("var s seal", name: "m", types: [new, outer]) end)

      # And a tag declared from Elixir is one type of its name with those given, or with
      # another tag's, the message naming the tag, not the types, where the second version
      # is found: with no types given at all, too.
      tagged =
        "a tag declared from Elixir holds a function block named `seal` other than the one " <>
          "of that name in the types given or in another tag: give every instance of a " <>
          "block the same version, compiled against the same types"

      raises(tagged, fn ->
        Logex.Compiler.instructionize(ast("var o outer"), [Tag.new!("s0", new)], [outer])
      end)

      raises(tagged, fn ->
        Logex.Compiler.instructionize(ast("var_input i bool"), [
          Tag.new!("w", outer),
          Tag.new!("s", new)
        ])
      end)
    end

    # Two copies of one block differ only in their warnings, and in the file its body
    # keeps, where one was compiled from its file, which stamps each warning with the path,
    # under whichever spelling: one version.
    @tag :tmp_dir
    test "a block compiled from its file, and from its text, is one version", %{tmp_dir: dir} do
      warned = String.replace(@seal, "var_output run bool\n", "var_output run bool\nvar n bool\n")
      File.write!(Path.join(dir, "seal.ld"), warned)
      File.mkdir_p!(Path.join(dir, "sub"))

      {:ok, from_file} = Logex.compile_file(Path.join(dir, "seal.ld"))
      {:ok, other_spelling} = Logex.compile_file(Path.join([dir, "sub", "..", "seal.ld"]))
      from_text = block!(warned)
      assert [%Diagnostic{file: file}] = from_file.body.warnings
      assert file == Path.join(dir, "seal.ld")
      assert from_file.body.file == file
      assert from_text != from_file and other_spelling != from_file

      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_output o bool\nvar s seal\ncal s go go o",
          [from_text]
        )

      for seal <- [from_file, other_spelling] do
        assert {:ok, %Logex.Program{}} =
                 Logex.compile("var o outer\nvar s seal", name: "m", types: [seal, outer])
      end

      # At any depth: two versions of `outer`, each holding its own copy of `seal`.
      wrap =
        block!(
          "function_block wrap\nvar_input go bool\nvar_output o bool\nvar w outer\ncal w go o",
          [outer]
        )

      outer_from_file =
        block!(
          "function_block outer\nvar_input go bool\nvar_output o bool\nvar s seal\ncal s go go o",
          [from_file]
        )

      assert outer_from_file != outer

      assert {:ok, %Logex.Program{}} =
               Logex.compile("var o outer\nvar w wrap", name: "m", types: [outer_from_file, wrap])

      assert {:ok, %Logex.Program{}} =
               Logex.Compiler.instructionize(ast("var o outer"), [Tag.new!("s", from_file)], [
                 outer
               ])
    end

    test "from Elixir, an instance of a user block is a tag whose type is the block's" do
      seal = block!(@seal)
      assert %Tag{type: ^seal} = Tag.new!("s1", seal)

      raises(
        "`s1` is an instance of `seal`, which takes no initial value: its members start " <>
          "where its type says",
        fn -> Tag.new!("s1", seal, :var, 1) end
      )

      raises(
        "`s1` is an instance of `seal`: an instance is the program's own, declared with " <>
          "`var`, as in `var s1 seal`, not with `var_input`",
        fn -> Tag.new!("s1", seal, :var_input) end
      )

      raises(
        ~s|unknown function block type "seal": logex has Logex.FbType.ton() and the types | <>
          "Logex.compile/2 gives for a function block's file",
        fn -> Tag.new!("s1", %{seal | body: %{seal.body | name: "other"}}) end
      )

      ast = ast("var_input a bool\nvar_output q bool\ncal s1 a a q")
      assert {:ok, program} = Logex.Compiler.instructionize(ast, [Tag.new!("s1", seal)])
      assert program.tags["s1"].type == seal

      # A block's member declared from Elixir has no line: it comes first in cal's order,
      # those from Elixir by name, and the type is one a compile takes.
      ast = ast("function_block blk\nvar_output q bool\nxic a ote q")
      declared = [Tag.new!("b", :bool, :var_input), Tag.new!("a", :bool, :var_input)]
      assert {:ok, %FbType{} = blk} = Logex.Compiler.instructionize(ast, declared)
      assert Enum.map(blk.members, & &1.name) == ["a", "b", "q"]
      assert FbType.user?(blk)

      user = program!("var_input x bool\nvar_output y bool\nvar k blk\ncal k x 0 y", [blk])
      {outputs, _} = step(user, Runtime.instance(user), %{"x" => 1}, 0)
      assert outputs == %{"y" => 1}

      raises(
        "`Function_Block` heads a function block's file and cannot name a tag in one",
        fn ->
          Logex.Compiler.instructionize(ast, [Tag.new!("Function_Block", :bool, :var_input)])
        end
      )
    end

    test "a section line for an instance of a block names its declaration" do
      assert errors("var_input s1 seal\nvar_input a bool", [block!(@seal)]) == [
               "line 1: `s1` is an instance of `seal`: an instance is the program's own, " <>
                 "declared with `var`, as in `var s1 seal`, not with `var_input`"
             ]

      assert errors("var_output seal\nvar_input a bool", [block!(@seal)]) == [
               "line 1: `var_output` needs a tag name before the type `seal`; an instance of " <>
                 "`seal` is declared with `var`, as in `var s1 seal`"
             ]

      assert errors("var s1 seal 1\nvar_input a bool", [block!(@seal)]) == [
               "line 1: `s1` is an instance of `seal`, which takes no initial value: its " <>
                 "members start where its type says"
             ]
    end
  end

  describe "recursion" do
    test "a block never holds an instance of itself, and its uses add no message" do
      assert errors(@seal <> "var inner seal\n", [], "seal") == [
               "line 7: `var` after the first rung (line 6): declarations come first",
               "line 7: `seal` cannot hold an instance of `seal`: " <>
                 "a function block never holds an instance of itself"
             ]

      # One mistake, one message: the uses of a declaration refused as recursive are not
      # each reported as undeclared.
      assert errors(
               "function_block seal\nvar_output q bool\nvar again seal\n" <>
                 "xic again.run ote q\ncal again q q q",
               [],
               "seal"
             ) == [
               "line 3: `seal` cannot hold an instance of `seal`: " <>
                 "a function block never holds an instance of itself"
             ]
    end

    # A type given can hold the block being compiled only when it was compiled against an
    # older version of it: refused at the declaration, naming the chain.
    test "a type given that holds the block's own name, at any depth" do
      old_a = block!("function_block a\nvar_output q bool\nxic q ote q")

      b =
        block!("function_block b\nvar_input go bool\nvar_output o bool\nvar x a\ncal x o", [old_a])

      c =
        block!("function_block c\nvar_input go bool\nvar_output o bool\nvar y b\ncal y go o", [b])

      assert errors("function_block a\nvar_output q bool\nvar z c\nxic q ote q", [c], "a") == [
               "line 3: `a` cannot hold an instance of `c` (a → c → b → a): " <>
                 "a function block never holds an instance of itself, at any depth"
             ]

      # Through a tag declared from Elixir, which no line can cite: a host mistake.
      ast = ast("function_block a\nvar_output q bool\nvar_input i bool\ncal y i q")

      raises(
        "`y` holds an instance of `a`, the function block being compiled: " <>
          "a function block never holds an instance of itself, at any depth",
        fn -> Logex.Compiler.instructionize(ast, [Tag.new!("y", b)], []) end
      )
    end
  end

  describe "cal" do
    setup do
      %{seal: block!(@seal)}
    end

    @decl "var_input a bool\nvar_input b bool\nvar_output q bool\nvar n dint\nvar t1 ton\nvar s1 seal\n"

    # IL's non-formal CAL: the var_inputs, then the var_outputs, each in declaration order,
    # wherever the block declares them.
    test "its operands are the block's inputs, then its outputs" do
      flip =
        block!(
          "function_block flip\nvar_output q bool\nvar_input go bool\nvar_output r bool\n" <>
            "xic go ote q\nxio go ote r"
        )

      program =
        program!(
          "var_input a bool\nvar_output y bool\nvar_output z bool\nvar f flip\ncal f a y z",
          [
            flip
          ]
        )

      {outputs, _} = step(program, Runtime.instance(program), %{"a" => 1}, 0)
      assert outputs == %{"y" => 1, "z" => 0}

      assert errors("var_input a bool\nvar_output y bool\nvar f flip\ncal f a", [flip]) == [
               "line 4: `cal f` expects 3 operands after its instance, `go` (var_input bool), " <>
                 "then `q` (var_output bool), then `r` (var_output bool): found 1"
             ]
    end

    test "an arity error names every formal, in order", %{seal: seal} do
      assert errors(@decl <> "cal s1 a b\nxic a ton t1 5", [seal]) == [
               "line 7: `cal s1` expects 3 operands after its instance, `start` (var_input " <>
                 "bool), then `stop` (var_input bool), then `run` (var_output bool): found 2"
             ]

      assert errors(@decl <> "cal s1 a ote q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal s1` expects 3 operands after its instance, `start` (var_input " <>
                 "bool), then `stop` (var_input bool), then `run` (var_output bool): found 1 " <>
                 "before the instruction `ote`"
             ]
    end

    test "a type error names the formal the operand fills", %{seal: seal} do
      assert errors(@decl <> "cal s1 a n q\nxic a ton t1 5", [seal]) == [
               "line 7: operand 2 of `cal s1` is `stop` (var_input bool), but `n` is a dint"
             ]

      assert errors(@decl <> "cal s1 a 7 q\nxic a ton t1 5", [seal]) == [
               "line 7: operand 2 of `cal s1` is `stop` (var_input bool): only 0 or 1 fit, found `7`"
             ]

      assert errors(@decl <> "cal s1 a b 1\nxic a ton t1 5", [seal]) == [
               "line 7: operand 3 of `cal s1` is `run` (var_output bool), which it writes: found `1`"
             ]

      assert errors(@decl <> "cal s1 a b b\nxic a ton t1 5", [seal]) == [
               "line 7: operand 3 of `cal s1` is `run` (var_output bool), which it writes: `b` " <>
                 "is a var_input (declared on line 2), and logic must not write an input"
             ]

      assert errors(@decl <> "cal s1 t1 b q\nxic a ton t1 5", [seal]) == [
               "line 7: operand 1 of `cal s1` is `start` (var_input bool), but `t1` is a ton " <>
                 "(declared on line 5): name one of its members"
             ]

      assert errors("var s2 seal\n" <> @decl <> "cal s1 s2 b q\nxic a ton t1 5", [seal]) == [
               "line 8: operand 1 of `cal s1` is `start` (var_input bool), but `s2` is an " <>
                 "instance of `seal` (declared on line 1): name one of its members"
             ]

      assert errors(@decl <> "cal s1 bool b q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` expects a tag, found the type `bool`"
             ]

      assert errors(@decl <> "cal s1 t1.dn b t1.dn\nxic a ton t1 5", [seal]) == [
               "line 7: operand 3 of `cal s1` is `run` (var_output bool), which it writes: " <>
                 "logic may write only `.pre` and `.acc` of a ton"
             ]

      # A dint input's literal must fit in 32 bits.
      dint = block!("function_block d\nvar_input sp dint\nvar_output q bool\ngt sp 0 ote q")

      assert errors("var_output q bool\nvar d1 d\ncal d1 2147483648 q", [dint]) == [
               "line 3: operand 1 of `cal d1` is `sp` (var_input dint): `2147483648` does not " <>
                 "fit in 32 bits"
             ]

      # Two swapped bools still compile: the price of the positional form (§4.3).
      assert {:ok, _} =
               Logex.compile(@decl <> "cal s1 b a q\nxic a ton t1 5", name: "m", types: [seal])
    end

    test "runs only an instance of a user block, and one cal runs it", %{seal: seal} do
      assert errors(@decl <> "cal t1 a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` runs an instance of a user function block, but `t1` is a ton " <>
                 "(declared on line 5), which `ton t1` and its preset run"
             ]

      assert errors(@decl <> "cal s1.run a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` runs an instance of a function block, named whole: found `s1.run`"
             ]

      assert errors(@decl <> "cal 5 a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` expects an instance of a function block, found `5`"
             ]

      assert errors(@decl <> "cal\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` expects an instance of a function block, found none"
             ]

      assert errors(@decl <> "cal bool a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `cal` expects an instance of a function block, found the type `bool`"
             ]

      assert errors(@decl <> "cal s9 a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `s9` is not declared"
             ]

      assert errors(@decl <> "cal zz.q a b q\nxic a ton t1 5", [seal]) == [
               "line 7: `zz` is not declared"
             ]

      assert errors(@decl <> "cal s1 a b q\nxic b cal s1 a b q\nxic a ton t1 5", [seal]) == [
               "line 8: `s1` is already run by the `cal` on line 7: one `cal` runs an instance"
             ]

      assert errors(@decl <> "cal s1 a b q\nxic a ton s1 5\nxic a ton t1 5", [seal]) == [
               "line 8: `ton` runs a ton, but `s1` is an instance of `seal` (declared on line 6)"
             ]
    end

    test "is reserved, a mnemonic: no tag may be named cal, in any case" do
      assert errors("var cal bool\nxic cal ote cal") == [
               "line 1: `cal` is an instruction and cannot name a tag",
               "line 2: `xic` expects 1 operand (a tag), found none before the instruction `cal`",
               "line 2: `cal` expects an instance of a function block, found none " <>
                 "before the instruction `ote`",
               "line 2: `ote` expects 1 operand (a tag), found none before the instruction `cal`",
               "line 2: `cal` expects an instance of a function block, found none"
             ]

      assert errors("var Cal bool\nvar_output q bool\nxic q ote q") == [
               "line 1: `Cal` is an instruction and cannot name a tag"
             ]
    end
  end

  describe "members" do
    setup do
      %{seal: block!(@seal)}
    end

    test "a block's inputs and outputs are read anywhere, and written by no logic outside it",
         %{seal: seal} do
      decl = "var_input a bool\nvar_output q bool\nvar s1 seal\ncal s1 a a q\n"

      assert {:ok, _} =
               Logex.compile(decl <> "xic s1.start xic s1.run ote q", name: "m", types: [seal])

      assert errors(decl <> "xic a ote s1.run", [seal]) == [
               "line 5: `ote` writes `s1.run`, but `s1` is an instance of `seal`, whose members " <>
                 "only its body writes"
             ]

      assert errors("var s2 seal\n" <> decl <> "cal s2 a a s1.start", [seal]) == [
               "line 6: operand 3 of `cal s2` is `run` (var_output bool), which it writes: " <>
                 "`s1` is an instance of `seal`, whose members only its body writes"
             ]

      assert errors("var_input a bool\nvar x bool\nxic x.run ote x") == [
               "line 3: `x.run` names a member of `x`, but `x` is a bool (declared on line 2): " <>
                 "only an instance of a function block has members"
             ]
    end

    # A block's name is any name, so a message names its instance's type without an
    # article of its own: `an instance of `outer``, never `a outer`.
    test "an instance's type is named with no article of the block's own" do
      outer =
        block!("function_block outer\nvar_input in bool\nvar_output out bool\nxic in ote out")

      decl = "var_input a bool\nvar_output q bool\nvar o outer\ncal o a q\n"

      assert errors(decl <> "xic o.s ote q\nxic o ote q", [outer]) == [
               "line 5: `o.s` is not a member of `o`, an instance of `outer`: its members are " <>
                 "`in` and `out`",
               "line 6: `xic` reads a bool, but `o` is an instance of `outer` (declared on " <>
                 "line 3): name one of its members, as in `o.out`"
             ]

      program = program!(decl, [outer])

      raises(
        "input `o.in` names a member of `o`, an instance of `outer`: only a var_input is " <>
          "set from outside",
        fn -> Runtime.put_inputs(program, Runtime.instance(program), %{"o.in" => 1}) end
      )

      assert warnings(program!("var_output q bool\nvar o outer\nxic o.out ote q", [outer])) == [
               "line 2: warning: `o` is an instance of `outer`, but no `cal` runs it: it never " <>
                 "runs, and its members stay at their initial values"
             ]
    end

    # A block may show nothing outside it: no input, no output.
    test "an instance of a block with no inputs or outputs is named as one" do
      hidden = block!("function_block hidden\nvar a bool\nxic a ote a")

      assert errors("var_output q bool\nvar h hidden\ncal h\nxic h.a ote q", [hidden]) == [
               "line 4: `h.a` is not a member of `h`, an instance of `hidden`: it has none that " <>
                 "logic outside it may name"
             ]

      assert {:ok, program} = Logex.compile("var h hidden\ncal h", name: "m", types: [hidden])

      assert {%{}, %Instance{env: %{"h" => %{"a" => 0}}}} =
               step(program, Runtime.instance(program), %{}, 0)
    end
  end

  describe "warnings" do
    setup do
      %{seal: block!(@seal)}
    end

    test "an instance no cal runs, saying cal", %{seal: seal} do
      program = program!("var_output q bool\nvar s2 seal\nxic s2.run ote q", [seal])

      assert warnings(program) == [
               "line 2: warning: `s2` is an instance of `seal`, but no `cal` runs it: it never " <>
                 "runs, and its members stay at their initial values"
             ]
    end

    test "a cal's outputs are written: a var_output only a cal drives is driven", %{seal: seal} do
      program = program!("var_input a bool\nvar_output q bool\nvar s1 seal\ncal s1 a a q", [seal])
      assert warnings(program) == []

      program =
        program!(
          "var_input a bool\nvar_output q bool\nvar e bool\nvar s1 seal\nxic a ons e ote q\ncal s1 a a e",
          [seal]
        )

      assert warnings(program) == [
               "line 6: warning: `cal` writes `e`, the storage bit of the `ons` on line 5: " <>
                 "the one-shot then fires on the wrong scans"
             ]
    end

    test "a block's body is warned about as a program is, in its own type" do
      block =
        block!(
          "function_block b\nvar_input go bool\nvar_output q bool\nvar spare bool\nxic go ote q"
        )

      assert Enum.map(block.body.warnings, &Diagnostic.format/1) == [
               "line 4: warning: `spare` is declared but no rung uses it"
             ]
    end
  end

  describe "running a block" do
    test "ENO is the power out: what follows a cal sees its EN" do
      seal = block!(@seal)

      program =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output q bool\nvar_output eno bool\n" <>
            "var s1 seal\nxic en cal s1 a a q ote eno",
          [seal]
        )

      {outputs, state} = step(program, Runtime.instance(program), %{"en" => 1}, 0)
      assert outputs["eno"] == 1
      {outputs, _state} = step(program, state, %{"en" => 0})
      assert outputs["eno"] == 0
    end

    test "energised, it copies its inputs in, runs the body, and copies its outputs out" do
      seal = block!(@seal)

      program =
        program!(
          "var_input a bool\nvar_input b bool\nvar_output q bool\nvar s1 seal\ncal s1 a b q",
          [seal]
        )

      {outputs, state} = step(program, Runtime.instance(program), %{"a" => 1}, 0)
      assert outputs == %{"q" => 1}
      assert state.env["s1"] == %{"start" => 1, "stop" => 0, "run" => 1}
      {outputs, state} = step(program, state, %{"a" => 0})
      assert outputs == %{"q" => 1}
      {outputs, state} = step(program, state, %{"b" => 1})
      assert outputs == %{"q" => 0}
      assert state.env["s1"] == %{"start" => 0, "stop" => 1, "run" => 0}
    end

    test "de-energised, nothing: no copy in, no body, no copy out" do
      seal = block!(@seal)

      program =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output q bool\nvar s1 seal\n" <>
            "xic en cal s1 a 0 q\nxio en otu q",
          [seal]
        )

      {_, state} = step(program, Runtime.instance(program), %{"a" => 1, "en" => 1}, 0)
      frozen = state.env["s1"]
      assert frozen == %{"start" => 1, "stop" => 0, "run" => 1}

      # Its EN false, a changed input is not read in, the body does not run, and nothing is
      # written out: `q`, which a rung clears, stays cleared.
      {outputs, state} = step(program, state, %{"a" => 0, "en" => 0})
      assert outputs == %{"q" => 0}
      assert state.env["s1"] == frozen
    end

    test "blocks nest: an instance inside an instance is a map inside a map" do
      seal = block!(@seal)

      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_input halt bool\nvar_output on bool\n" <>
            "var inner seal\ncal inner go halt on",
          [seal]
        )

      program =
        program!("var_input go bool\nvar_output on bool\nvar o outer\ncal o go 0 on", [outer])

      state = Runtime.instance(program)

      assert state.env["o"] == %{
               "go" => 0,
               "halt" => 0,
               "on" => 0,
               "inner" => %{"start" => 0, "stop" => 0, "run" => 0}
             }

      {outputs, state} = step(program, state, %{"go" => 1}, 0)
      {outputs2, state} = step(program, state, %{"go" => 0})
      assert {outputs, outputs2} == {%{"on" => 1}, %{"on" => 1}}
      assert get_in(state.env, ["o", "inner", "run"]) == 1
    end

    test "a timer inside a frozen block keeps .en and its last run, and catches up" do
      program = program!(@runs_pulse, [block!(@pulse)])
      {_, state} = step(program, Runtime.instance(program), %{"a" => 1, "en" => 1}, 0)
      {_, state} = step(program, state, %{}, 30)
      timer = state.env["p"]["t1"]
      assert %{"acc" => 30, "en" => 1, "last" => 30} = timer

      {_, state} = drive(program, state, [{10, %{"en" => 0}}, {200, %{}}])
      assert state.env["p"]["t1"] == timer

      {_, state} = step(program, state, %{"en" => 1}, 10)
      assert %{"acc" => 100, "dn" => 1, "last" => 250} = state.env["p"]["t1"]
    end

    test "first is the program instance's: an ons in a block frozen on the first scan " <>
           "fires when the block first runs" do
      program = program!(@runs_pulse, [block!(@pulse)])
      {outputs, state} = step(program, Runtime.instance(program), %{"a" => 1, "en" => 0}, 0)
      assert outputs["y"] == 0
      {outputs, _state} = step(program, state, %{"en" => 1})
      assert outputs["y"] == 1

      # Run on the first scan, it passes no power, as every ons does then.
      {outputs, _state} = step(program, Runtime.instance(program), %{"a" => 1, "en" => 1}, 0)
      assert outputs["y"] == 0
    end

    # A type whose body was edited by hand is refused where it is given (`types:`,
    # `Logex.Tag.new!/4`); a program edited by hand to hold one is outside the contract, and
    # still runs and takes an edit without raising: a `cal` of an instance its table lacks
    # runs nothing, and writes nothing in the edit's walk.
    test "a program built by hand whose block runs an instance its table lacks runs nothing, " <>
           "and an edit takes it: nothing escapes" do
      seal = block!(@seal)
      [{:rung, rung}] = seal.body.rungs
      body = %{seal.body | rungs: [{:rung, rung ++ [{:cal, 6, [{:name, 6, "zz"}]}]}]}
      edited = %{seal | body: body}
      refute FbType.user?(edited)

      motor = program!(@three, [seal])

      hand = %{
        motor
        | tags:
            Map.new(motor.tags, fn
              {name, %Tag{type: ^seal} = tag} -> {name, %{tag | type: edited}}
              entry -> entry
            end)
      }

      {outputs, state} = step(hand, Runtime.instance(hand), %{"a1" => 1, "en3" => 1}, 0)
      assert outputs["k1"] == 1
      assert {:ok, _edit, _forecast} = Edit.accept(hand, hand, state)
      assert {:error, [_, _, _]} = Edit.accept(hand, motor, state)
    end

    test "an instance a plain swap left as no map runs from an empty one: nothing escapes" do
      seal = block!(@seal)
      a = program!("var_input go bool\nvar_output q bool\nvar z bool\nxic go ote z", [])
      b = program!("var_input go bool\nvar_output q bool\nvar z seal\ncal z go 0 q", [seal])
      {_, state} = step(a, Runtime.instance(a), %{"go" => 1}, 0)
      assert state.env["z"] == 1
      {outputs, state} = step(b, state, %{})
      assert outputs == %{"q" => 1}
      assert state.env["z"] == %{"start" => 1, "stop" => 0, "run" => 1}
    end

    test "the scan's tag table is the runtime's" do
      program = program!(@runs_pulse, [block!(@pulse)])

      raises(
        "scan.tags is the runtime's, taken from the program: a host leaves it out, got: %{}",
        fn ->
          Runtime.call(program, Runtime.instance(program), %{}, %Scan{
            now: 0,
            first: true,
            tags: %{}
          })
        end
      )
    end
  end

  # A bit inside an instance is named in the block list by its path (decision 32), as only
  # an edit's switch lists one; here the list is set by hand, as a test sets an env.
  describe "a one-shot blocked inside an instance" do
    defp blocked(program, bits) do
      {_, state} = step(program, Runtime.instance(program), %{"a" => 0, "en" => 1}, 0)
      %{state | ons_blocked: bits}
    end

    test "is blocked on the scan that runs its body, and the list is then empty" do
      program = program!(@runs_pulse, [block!(@pulse)])
      state = blocked(program, ["p.edge"])
      {outputs, state} = step(program, state, %{"a" => 1})
      assert outputs == %{"y" => 0}
      assert state.ons_blocked == []
      assert state.env["p"]["edge"] == 1
    end

    test "stays blocked while no scan runs the instance's body, its cal false" do
      program = program!(@runs_pulse, [block!(@pulse)])
      state = blocked(program, ["p.edge"])
      {outputs, state} = step(program, state, %{"a" => 1, "en" => 0})
      assert outputs == %{"y" => 0}
      assert state.ons_blocked == ["p.edge"]
      assert state.env["p"]["edge"] == 0

      # The scan that runs it at last blocks it, and only then is it used up.
      {outputs, state} = step(program, state, %{"en" => 1})
      assert outputs == %{"y" => 0}
      assert state.ons_blocked == []
    end

    test "a body sees its own instance's blocked bits, and no other's of one name" do
      pulse = block!(@pulse)

      program =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output y bool\nvar_output z bool\n" <>
            "var edge bool\nvar p pulse\nvar r pulse\nxic a ons edge ote z\n" <>
            "xic en cal p a y\nxic en cal r a y",
          [pulse]
        )

      {_, state} = step(program, Runtime.instance(program), %{"a" => 0, "en" => 1}, 0)

      # The program's own `edge`, and `p`'s: `r`'s fires.
      {outputs, state} = step(program, %{state | ons_blocked: ["edge", "p.edge"]}, %{"a" => 1})
      assert outputs == %{"y" => 1, "z" => 0}
      assert state.ons_blocked == []

      # `r`'s alone: the program's `edge` and `p`'s fire, and `r`'s writes `y` last.
      {_, state} = step(program, state, %{"a" => 0})
      {outputs, _state} = step(program, %{state | ons_blocked: ["r.edge"]}, %{"a" => 1})
      assert outputs == %{"y" => 0, "z" => 1}
    end

    test "inside an instance an instance holds, by its path, kept while the outer one is frozen" do
      pulse = block!(@pulse)

      wrap =
        block!(
          "function_block wrap\nvar_input go bool\nvar_input on bool\nvar_output q bool\n" <>
            "var inner pulse\nxic on cal inner go q",
          [pulse]
        )

      program =
        program!(
          "var_input a bool\nvar_input en bool\nvar_input on bool\nvar_output y bool\n" <>
            "var w wrap\nxic en cal w a on y",
          [wrap]
        )

      {_, state} =
        step(program, Runtime.instance(program), %{"a" => 0, "en" => 1, "on" => 1}, 0)

      # The outer instance runs, but not the inner one's body: still listed.
      {_, state} =
        step(program, %{state | ons_blocked: ["w.inner.edge"]}, %{"a" => 1, "on" => 0})

      assert state.ons_blocked == ["w.inner.edge"]

      # Neither runs: still listed.
      {_, state} = step(program, state, %{"en" => 0, "on" => 1})
      assert state.ons_blocked == ["w.inner.edge"]

      # Both run: blocked on this scan, and then used up.
      {outputs, state} = step(program, state, %{"en" => 1})
      assert outputs == %{"y" => 0}
      assert state.ons_blocked == []
    end

    # A list built by hand may name a bit and a path below it, in either order, which no
    # switch gives: the scan raises nothing.
    test "a list built by hand that names a path below a bit runs: nothing escapes" do
      program = program!(@runs_pulse, [block!(@pulse)])
      state = blocked(program, [])

      for bits <- [["p", "p.edge"], ["p.edge", "p"]] do
        assert {%{"y" => _}, %Instance{}} =
                 step(program, %{state | ons_blocked: bits}, %{"a" => 1})
      end
    end

    # A scan records which instances holding a blocked bit ran under an atom key of the
    # env, which it takes out again; one an env built by hand already holds raises nothing.
    test "an env built by hand under the scan's own key runs: nothing escapes" do
      program = program!(@runs_pulse, [block!(@pulse)])
      state = Runtime.instance(program)

      for {junk, en, left} <- [{5, 1, []}, {%{"p" => 7}, 1, []}, {5, 0, ["p.edge"]}] do
        hand = %{state | env: Map.put(state.env, :ran, junk), ons_blocked: ["p.edge"]}
        {outputs, later} = step(program, hand, %{"a" => 1, "en" => en}, 0)
        assert outputs == %{"y" => 0}
        assert later.ons_blocked == left and not Map.has_key?(later.env, :ran)
      end
    end
  end

  # Logex.Compiler.lowered?/1 is the definition of a compiled body: each of its checks
  # refuses a body edited by hand to break that check alone, its warnings recomputed so
  # that no other check sees the edit.
  describe "a compiled body (Logex.Compiler.lowered?/1)" do
    defp body(source, types \\ []), do: block!(source, types).body

    defp relined(body, rungs),
      do: %{body | rungs: rungs, warnings: Logex.Warnings.of(rungs, body.tags)}

    defp line(elements, line), do: Enum.map(elements, &at_line(&1, line))

    defp at_line({:branches, legs}, line), do: {:branches, Enum.map(legs, &line(&1, line))}

    defp at_line({symbol, _, operands}, line),
      do: {symbol, line, Enum.map(operands, &put_elem(&1, 1, line))}

    defp at_rung({:rung, elements}, line), do: {:rung, line(elements, line)}

    @two "function_block two\nvar_input go bool\nvar_output q bool\nvar_output r bool\n" <>
           "xic go ote q\nxio go ote r"

    test "a compiled body is one, and anything else is not" do
      assert Logex.Compiler.lowered?(body(@two))
      assert Logex.Compiler.lowered?(body(@pulse))

      for junk <- [nil, :x, %{}, %{body(@two) | rungs: :x}, %{body(@two) | tags: []}],
          do: refute(Logex.Compiler.lowered?(junk))
    end

    test "its rungs are on rising lines" do
      two = body(@two)
      [{:rung, q}, {:rung, r}] = two.rungs
      assert Logex.Compiler.lowered?(relined(two, [{:rung, line(q, 5)}, {:rung, line(r, 6)}]))
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(r, 5)}, {:rung, line(q, 5)}]))
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(r, 6)}, {:rung, line(q, 5)}]))
    end

    test "each rung is on one line" do
      two = body(@two)
      [{:rung, [contact, coil]}, r] = two.rungs
      over_two = [{:rung, [contact, at_line(coil, 6)]}, at_rung(r, 7)]
      assert Logex.Compiler.lowered?(relined(two, [{:rung, [contact, coil]}, at_rung(r, 7)]))
      refute Logex.Compiler.lowered?(relined(two, over_two))
    end

    test "its rungs come after its declarations" do
      two = body(@two)
      [{:rung, q}, {:rung, r}] = two.rungs
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(q, 3)}, {:rung, line(r, 6)}]))
    end

    test "one ons uses a storage bit" do
      edges =
        body(
          "function_block edges\nvar_input go bool\nvar_output q bool\nvar_output r bool\n" <>
            "var e bool\nvar f bool\nxic go ons e ote q\nxio go ons f ote r"
        )

      [{:rung, one}, {:rung, [contact, {:ons, l, [{:name, l, "f"}]}, coil]}] = edges.rungs
      shared = [{:rung, one}, {:rung, [contact, {:ons, l, [{:name, l, "e"}]}, coil]}]
      assert Logex.Compiler.lowered?(edges)
      refute Logex.Compiler.lowered?(relined(edges, shared))
    end

    test "one cal runs an instance" do
      inner = block!("function_block inner\nvar_input go bool\nvar_output q bool\nxic go ote q")

      twice =
        body(
          "function_block twice\nvar_input go bool\nvar_output q bool\nvar_output r bool\n" <>
            "var i inner\nvar j inner\ncal i go q\ncal j go r",
          [inner]
        )

      [{:rung, one}, {:rung, [{:cal, l, [{:name, l, "j"} | rest]}]}] = twice.rungs
      same = [{:rung, one}, {:rung, [{:cal, l, [{:name, l, "i"} | rest]}]}]
      assert Logex.Compiler.lowered?(twice)
      refute Logex.Compiler.lowered?(relined(twice, same))
    end

    test "nothing follows a ton on its path" do
      timed =
        body(
          "function_block timed\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
            "xic go ton t1 100\nxic t1.dn ote q"
        )

      [{:rung, timing}, {:rung, [_contact, coil]}] = timed.rungs
      after_ton = [{:rung, timing ++ [at_line(coil, 5)]}]
      assert Logex.Compiler.lowered?(timed)
      refute Logex.Compiler.lowered?(relined(timed, after_ton))
    end

    test "its rungs are a compiled body's shape, whatever a hand made of them" do
      counter =
        body(
          "function_block counter\nvar_input go bool\nvar_output q bool\nvar n dint\n" <>
            "xic go move 1 n\n( xic go | xio go ) ote q"
        )

      [{:rung, [contact, {:move, l, [_one, n]}]}, {:rung, [group, coil]}] = counter.rungs
      assert Logex.Compiler.lowered?(counter)

      for rungs <- [
            [{:rung, [contact, {:move, l, [{:int_lit, l, -1}, n]}]}, {:rung, [group, coil]}],
            [
              {:rung, [contact, {:move, l, [{:int_lit, l, 1}, n]}]},
              {:rung, [{:branches, []}, coil]}
            ],
            [
              {:rung, [contact, {:move, l, [{:int_lit, l, 1}, n]}]},
              {:rung, [{:branches, [[]]}, coil]}
            ],
            [
              {:rung, [contact, {:move, l, [{:int_lit, l, 1}, {:name, l, :n}]}]},
              {:rung, [group, coil]}
            ],
            [
              {:rung, [contact, {:move, l, [{:int_lit, l, 1}, {:member, l, ["n"]}]}]},
              {:rung, [group, coil]}
            ]
          ],
          do: refute(Logex.Compiler.lowered?(relined(counter, rungs)))
    end

    # Two tags of one name but for case, which no declaration line gives, the second from
    # Elixir so that no line rule sees it.
    test "no two of its tags differ only in case" do
      two = body(@two)
      twin = %Tag{name: "Go", type: :bool, section: :var}
      refute Logex.Compiler.lowered?(%{two | tags: Map.put(two.tags, "Go", twin)})

      assert Logex.Compiler.lowered?(%{
               two
               | tags: Map.put(two.tags, "gone", %{twin | name: "gone"})
             })
    end

    test "one ton runs a timer" do
      timed =
        body(
          "function_block timed\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
            "xic go ton t1 100\nxic t1.dn ote q"
        )

      [{:rung, [contact, {:ton, _, operands}]} = timing, rest] = timed.rungs

      twice = [
        timing,
        {:rung, [at_line(contact, 6), {:ton, 6, Enum.map(operands, &put_elem(&1, 1, 6))}]},
        rest
      ]

      refute Logex.Compiler.lowered?(relined(timed, Enum.take(twice, 2) ++ [at_rung(rest, 7)]))
    end

    test "its warnings are the ones its rungs give, a file aside" do
      two = body(@two)
      file = %Diagnostic{stage: :validate, line: 2, message: "x", severity: :warning, file: "f"}

      unused =
        body(
          "function_block u\nvar_input go bool\nvar spare bool\nvar_output q bool\nxic go ote q"
        )

      [warning] = unused.warnings
      assert Logex.Compiler.lowered?(%{unused | warnings: [%{warning | file: "u.ld"}]})
      refute Logex.Compiler.lowered?(%{unused | warnings: []})
      refute Logex.Compiler.lowered?(%{two | warnings: [file]})
    end
  end

  describe "an online edit of a program that holds blocks" do
    defp accepted(running, candidate, state),
      do: Edit.accept(running, candidate, state)

    test "an instance of a block both programs hold unchanged moves whole" do
      pulse = block!(@pulse)
      v1 = program!(@runs_pulse, [pulse])
      v2 = program!(String.replace(@runs_pulse, "xic en cal p a y", "xio en cal p a y"), [pulse])
      {_, state} = drive(v1, Runtime.instance(v1), [{0, %{"a" => 1, "en" => 1}}, {30, %{}}])
      assert {:ok, edit, []} = accepted(v1, v2, state)
      {edit, tested, []} = Edit.test(edit, state)
      assert tested.env["p"] == state.env["p"]
      assert {^v2, _state, []} = Edit.assemble(edit, tested)
    end

    test "any change to a block an instance holds is refused, and a block renamed is a " <>
           "type change" do
      v1 = program!(@runs_pulse, [block!(@pulse)])
      changed = block!(String.replace(@pulse, "xic go ons edge ote q", "xio go ons edge ote q"))
      v2 = program!(@runs_pulse, [changed])
      state = Runtime.instance(v1)

      assert {:error, [diagnostic]} = accepted(v1, v2, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p` is an instance of `pulse`, which the candidate changes: a function " <>
                 "block changes only with a restart"

      latch = block!(String.replace(@pulse, "function_block pulse", "function_block latch"))
      v3 = program!(String.replace(@runs_pulse, "var p pulse", "var p latch"), [latch])

      assert {:error, [diagnostic]} = accepted(v1, v3, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p` is an instance of `pulse` in the running program and an instance " <>
                 "of `latch` in the candidate: a tag's type changes only with a restart"

      v4 =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output y bool\nvar p ton\nxic en ton p 5",
          []
        )

      assert {:error, [diagnostic]} = accepted(v1, v4, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p` is an instance of `pulse` in the running program and a ton in the " <>
                 "candidate: a tag's type changes only with a restart"
    end

    test "an output only a cal drove is held where the candidate drives it no more" do
      seal = block!(@seal)
      v1 = program!("var_input a bool\nvar_output q bool\nvar s1 seal\ncal s1 a 0 q", [seal])

      v2 =
        program!("var_input a bool\nvar_output q bool\nvar s1 seal\nvar k bool\ncal s1 a 0 k", [
          seal
        ])

      {_, state} = step(v1, Runtime.instance(v1), %{"a" => 1}, 0)
      assert {:ok, _edit, [{:added, "k", 0}, {:held, "q", 1}]} = accepted(v1, v2, state)
    end
  end

  # Fix F15: a program read from a file keeps it, and an edit's diagnostic cites it.
  describe "a program's file" do
    @describetag :tmp_dir

    test "compile_file/1 sets it, on a program and on a block's body, and compile/2 none",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "seal.ld"), @seal)
      File.write!(Path.join(dir, "m.ld"), "var_input a bool\nvar_output q bool\nxic a ote q")
      assert {:ok, %Logex.Program{file: file}} = Logex.compile_file(Path.join(dir, "m.ld"))
      assert file == Path.join(dir, "m.ld")
      assert {:ok, %FbType{body: body} = seal} = Logex.compile_file(Path.join(dir, "seal.ld"))
      assert body.file == Path.join(dir, "seal.ld")
      assert FbType.user?(seal)
      assert {:ok, %Logex.Program{file: nil}} = Logex.compile("var_input a bool", name: "m")
      assert block!(@seal).body.file == nil
    end

    test "a block's file is named as its first rung says", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "latch.ld"), @seal)
      path = Path.join(dir, "latch.ld")

      assert {:error, [diagnostic]} = Logex.compile_file(path)

      assert Diagnostic.format(diagnostic) ==
               "#{path}: line 1: this function block is `seal`, but it is compiled as `latch`: " <>
                 "a block is named after its file"
    end

    # A refused name is the file's one diagnostic beyond the source's own: the block is
    # compiled under no name, so its first rung is held to none.
    test "a block's file with a refused name is told only that", %{tmp_dir: dir} do
      path = Path.join(dir, "1seal.ld")
      File.write!(path, @seal)

      assert {:error, [diagnostic]} = Logex.compile_file(path)

      assert Diagnostic.format(diagnostic) ==
               "#{path}: \"1seal\" cannot name a program: a name is a letter or `_`, then " <>
                 "letters, digits or `_` (rename the file)"
    end

    test "an edit's diagnostic cites the candidate's file", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "m.ld"), "var_input a bool\nvar_output q dint\nmove 1 q")

      {:ok, running} =
        Logex.compile("var_input a bool\nvar_output q bool\nxic a ote q", name: "m")

      {:ok, candidate} = Logex.compile_file(Path.join(dir, "m.ld"))

      assert {:error, [diagnostic]} = Edit.accept(running, candidate, Runtime.instance(running))

      assert Diagnostic.format(diagnostic) ==
               "#{Path.join(dir, "m.ld")}: line 2: `q` is a bool in the running program and a " <>
                 "dint in the candidate: a tag's type changes only with a restart"
    end
  end

  # M2-1's `get/2` reads a block instance's public members by path (decision 33).
  describe "reading a block through a configuration" do
    @latch """
    function_block latch
    var_input set bool
    var_input reset bool
    var_output q bool
    var held bool
    var t1 ton
    xic set otl held
    xic reset otu held
    xic held ote q
    xic held ton t1 100
    """

    defp latched do
      latch = block!(@latch)
      hidden = block!("function_block hidden\nvar a bool\nxic a ote a")

      motor =
        program!(
          "var_input s bool\nvar_output k bool\nvar l1 latch\nvar h hidden\ncal l1 s 0 k\ncal h",
          [latch, hidden],
          "motor"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [motor],
          globals: [
            %Configuration.Global{name: "pb", type: :bool, at: "panel.i.0"},
            %Configuration.Global{name: "lamp", type: :bool, at: "panel.q.0"}
          ],
          instances: [%Configuration.Instance{name: "m1", type: "motor"}],
          connections: [
            %Configuration.Connection{instance: "m1", member: "s", to: "pb"},
            %Configuration.Connection{instance: "m1", member: "k", to: "lamp"}
          ]
        )

      {rt, %{"lamp" => 1}, _} = Runtime.cycle(Runtime.start(config), 0, %{"pb" => 1})
      rt
    end

    test "its inputs and outputs, by path" do
      rt = latched()
      assert Runtime.get(rt, "m1.l1.q") == {:ok, 1}
      assert Runtime.get(rt, "m1.l1.set") == {:ok, 1}
      assert Runtime.get!(rt, "m1.l1.reset") == 0
    end

    test "never its own vars, nor the instance whole" do
      rt = latched()

      assert Runtime.get(rt, "m1.l1.held") ==
               {:error,
                "`m1.l1.held` is a `var` of `latch`, hidden outside it: an access path reads " <>
                  "only its public members, `set`, `reset` and `q`"}

      assert Runtime.get(rt, "m1.l1.t1.acc") ==
               {:error,
                "`m1.l1.t1` is a `var` of `latch`, hidden outside it: an access path reads " <>
                  "only its public members, `set`, `reset` and `q`"}

      assert Runtime.get(rt, "m1.l1") ==
               {:error,
                "`m1.l1` is an instance of `latch`: an access path names one of its members, " <>
                  "as in `m1.l1.q`"}

      assert Runtime.get(rt, "m1.l1.zz") ==
               {:error,
                "`m1.l1.zz` is not a member of `m1.l1`, an instance of `latch`: its members " <>
                  "are `set`, `reset` and `q`"}

      assert Runtime.get(rt, "m1.h") ==
               {:error,
                "`m1.h` is an instance of `hidden`: an access path names one of its members, " <>
                  "and it has none an access path reads"}

      assert Runtime.get(rt, "m1.h.a") ==
               {:error,
                "`m1.h.a` is a `var` of `hidden`, hidden outside it: an access path reads only " <>
                  "its public members, and it has none"}

      assert Runtime.get(rt, "m1.h.b") ==
               {:error,
                "`m1.h.b` is not a member of `m1.h`, an instance of `hidden`: it has none an " <>
                  "access path reads"}
    end

    # The member a read of the instance whole would mean: an output, else an input.
    test "an instance named whole is shown a member to read" do
      only_in = block!("function_block sink\nvar_input go bool\nvar a bool\nxic go ote a")

      program = program!("var_input x bool\nvar k sink\ncal k x", [only_in], "p")

      config =
        Configuration.new!(
          name: "c",
          programs: [program],
          globals: [%Configuration.Global{name: "g", type: :bool}],
          instances: [%Configuration.Instance{name: "m1", type: "p"}],
          connections: [%Configuration.Connection{instance: "m1", member: "x", to: "g"}]
        )

      assert Runtime.get(Runtime.start(config), "m1.k") ==
               {:error,
                "`m1.k` is an instance of `sink`: an access path names one of its members, " <>
                  "as in `m1.k.go`"}
    end
  end

  describe "growth in the depth of nesting" do
    # A chain of n block types, each holding the next and running it, the deepest holding
    # a one-shot and a timer.
    defp chain(n) do
      deepest =
        "function_block b#{n}\nvar_input go bool\nvar_output q bool\nvar edge bool\nvar t1 ton\n" <>
          "xic go ons edge ote q\nxic go ton t1 100"

      Enum.reduce((n - 1)..1//-1, block!(deepest), fn k, inner ->
        block!(
          "function_block b#{k}\nvar_input go bool\nvar_output q bool\nvar inner b#{k + 1}\n" <>
            "cal inner go q",
          [inner]
        )
      end)
    end

    @top "var_input a bool\nvar_output y bool\nvar_output z bool\nvar p b1\ncal p a y\n"

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

    defp at_depth(n) do
      top = chain(n)
      v1 = program!(@top <> "xic a ote z", [top])
      v2 = program!(@top <> "xio a ote z", [top])
      {_, state} = step(v1, Runtime.instance(v1), %{"a" => 1}, 0)
      %{top: top, v1: v1, v2: v2, state: state}
    end

    # At 50 and 800 levels, 16x the depth. The bound is a fifth above the highest the
    # design pass measured; an edit whose plan built each nested block's whole initial
    # state at every level grew about 160x.
    test "a scan, a compile and an edit each stay linear" do
      s = at_depth(50)
      d = at_depth(800)

      compile = fn %{top: top} ->
        Logex.compile(@top <> "xic a ote z", name: "m", types: [top])
      end

      edit = fn %{v1: v1, v2: v2, state: state} ->
        {:ok, edit, _} = Edit.accept(v1, v2, state)
        {edit, state, _} = Edit.test(edit, state)
        {edit, state, _} = Edit.untest(edit, state)
        {edit, state, _} = Edit.test(edit, state)
        Edit.assemble(edit, state)
      end

      for {what, fun} <- [
            scan: fn %{v1: v1, state: state} -> Runtime.scan(v1, state, 10) end,
            compile: compile,
            edit: edit
          ] do
        ratio = reductions(fn -> fun.(d) end) / reductions(fn -> fun.(s) end)

        assert ratio < 20.5,
               "16x the depth took #{Float.round(ratio, 1)}x the reductions for #{what}"
      end
    end
  end

  describe "growth in the instances of a type" do
    # A type given is checked once, at full depth, where it is given: an instance declared
    # of it is known by being the one given under its name, not checked again. 16
    # instances of a block 200 levels deep cost 1.05 times one; checked again for each,
    # 8.3 times.
    test "a compile checks a type given once, however many instances hold it" do
      top = chain(200)

      compile = fn n ->
        source =
          "var_input a bool\nvar_output y bool\n" <>
            Enum.map_join(1..n, "\n", &"var p#{&1} b1") <>
            "\n" <> Enum.map_join(1..n, "\n", &"cal p#{&1} a y")

        reductions(fn -> {:ok, _} = Logex.compile(source, name: "m", types: [top]) end)
      end

      ratio = compile.(16) / compile.(1)
      assert ratio < 3, "16 instances took #{Float.round(ratio, 1)}x the reductions of one"
    end
  end

  describe "growth in the size of a term" do
    # Each nested block type is held once, in its holder's tag table, its member naming it:
    # held twice, as a member's type and a tag's, a copy that keeps no sharing (a message to
    # another process, term_to_binary/1, phash2/1) doubled at every level. At 6 and 12
    # levels, a program grows 1.7x in words copied flat; held twice, it grew 64x.
    test "a program copied flat stays linear in the depth of nesting" do
      flat = fn n -> :erts_debug.flat_size(program!(@top <> "xic a ote z", [chain(n)])) end
      ratio = flat.(12) / flat.(6)
      assert ratio < 2.5, "twice the depth took #{Float.round(ratio, 1)}x the words"
    end

    # A one-shot at every level of a chain n deep, each listed: n paths of up to n parts,
    # so the list itself grows as the square of the depth (decision 32). The scan that runs
    # them stays linear in the length of the list, its names' bytes: 4x the depth, 16x the
    # bytes, about 16x the reductions.
    test "the scan of a blocked chain stays linear in the length of the block list" do
      at = fn n ->
        deepest =
          "function_block c#{n}\nvar_input go bool\nvar_output q bool\nvar e bool\n" <>
            "xic go ons e ote q"

        top =
          Enum.reduce((n - 1)..1//-1, block!(deepest), fn k, inner ->
            block!(
              "function_block c#{k}\nvar_input go bool\nvar_output q bool\nvar e bool\n" <>
                "var inner c#{k + 1}\nxic go ons e ote q\ncal inner go q",
              [inner]
            )
          end)

        v = program!("var_input a bool\nvar_output y bool\nvar p c1\ncal p a y", [top])
        {_, state} = step(v, Runtime.instance(v), %{"a" => 0}, 0)
        bits = for k <- 1..n, do: Enum.join(["p" | List.duplicate("inner", k - 1)] ++ ["e"], ".")
        state = Runtime.put_inputs(v, %{state | ons_blocked: bits}, %{"a" => 1})
        {{%{"y" => 0}, %Instance{ons_blocked: []}}, _} = {Runtime.scan(v, state, 10), nil}
        bytes = bits |> Enum.map(&byte_size/1) |> Enum.sum()
        {bytes, reductions(fn -> Runtime.scan(v, state, 10) end)}
      end

      {small, s} = at.(50)
      {large, l} = at.(200)
      bytes = large / small
      ratio = l / s

      assert ratio < bytes * 1.3,
             "#{Float.round(bytes, 1)}x the bytes took #{Float.round(ratio, 1)}x"
    end
  end

  describe "growth in the instances" do
    # n instances of one block, each run by a rung of its own, the one-shot in every one
    # listed: the scan looks each bit up in a tree built once.
    defp blocked_scan(n) do
      pulse =
        block!(
          "function_block pulse\nvar_input go bool\nvar_output q bool\nvar edge bool\n" <>
            "xic go ons edge ote q"
        )

      v =
        program!(
          "var_input a bool\nvar_output y bool\n" <>
            Enum.map_join(1..n, "\n", &"var p#{&1} pulse") <>
            "\n" <> Enum.map_join(1..n, "\n", &"cal p#{&1} a y"),
          [pulse]
        )

      {_, state} = step(v, Runtime.instance(v), %{"a" => 0}, 0)
      bits = for k <- 1..n, do: "p#{k}.edge"
      state = Runtime.put_inputs(v, %{state | ons_blocked: bits}, %{"a" => 1})
      reductions(fn -> {%{"y" => 0}, _} = Runtime.scan(v, state, 10) end)
    end

    # At 250 and 4,000 instances, 16x; the bound is the one the top-level test has, a
    # third above.
    test "the scan stays linear in the nested one-shots it blocks" do
      ratio = blocked_scan(4000) / blocked_scan(250)
      assert ratio < 24, "16x the one-shots took #{Float.round(ratio, 1)}x the reductions"
    end
  end

  describe "the host contract, over sources that use blocks" do
    @words ~w(var var_input var_output bool dint seal pulse ton xic xio ote otl ons cal) ++
             ~w(s1 s2 p1 t1 a b q s1.run s1.start s1.edge p1.q p1.t1.dn 0 1 7) ++
             ["(", "|", ")", "\n", "\n"]

    @declarations ~w(a b) |> Enum.map(&"var_input #{&1} bool")
    @optional ["var_output q bool", "var s1 seal", "var s2 seal", "var p1 pulse", "var t1 ton"]

    # One or more for each M2-5 diagnostic, which a soup of words rarely assembles.
    @mistakes [
      "cal s1 a b",
      "cal s1 a b 1",
      "cal s1 a 7 q",
      "cal t1 a b q",
      "cal a",
      "cal s1 a b q\ncal s1 a b q",
      "xic a ote s1.run",
      "xic s1.edge ote q",
      "var s3 sael",
      "function_block x",
      "cal 5",
      "cal",
      "cal s1.run a b q",
      "var y m",
      "var function_block bool",
      "xic s2.run ote q",
      "xic s2.run ote q",
      "xic a cal s1 a b q ote q",
      "cal p1 b q",
      "",
      "",
      "",
      ""
    ]

    @fragments [
      "expects 3 operands after its instance",
      "which it writes: found",
      "only 0 or 1 fit",
      "runs an instance of a user function block",
      "runs an instance of a function block, but",
      "is already run by the `cal`",
      "whose members only its body writes",
      "is not a member of",
      "unknown type `sael`",
      "heads a function block's file, as its first line",
      "found `5`",
      "found none",
      "named whole",
      "cannot hold an instance of",
      "cannot name a tag in one",
      "warning: `s2` is an instance of `seal`, but no `cal` runs it"
    ]

    defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

    # A program, or now and then a block named `m`, of a few declarations, a soup of words
    # and a mistake.
    defp soup do
      head = Enum.at([["function_block m"], [], [], []], :rand.uniform(4) - 1)
      optional = Enum.filter(@optional, fn _ -> :rand.uniform(2) == 1 end)
      words = for _ <- 1..:rand.uniform(12), :rand.uniform(2) == 1, do: pick(@words)

      Enum.join(
        head ++ @declarations ++ optional ++ [Enum.join(words, " "), pick(@mistakes)],
        "\n"
      )
    end

    test "compile/2 never raises, its diagnostics are in line order and it reaches every " <>
           "M2-5 diagnostic; every program it gives scans without raising" do
      # The seed is fixed, so a failure reproduces, as in api_contract_test.exs.
      :rand.seed(:exsss, {2026, 10, 2})
      types = [block!(@seal), block!(@pulse)]
      sources = for _ <- 1..3000, do: soup()
      results = Enum.map(sources, &Logex.compile(&1, name: "m", types: types))

      for {:error, diagnostics} <- results do
        assert diagnostics == Enum.sort_by(diagnostics, & &1.line)
        assert Enum.all?(diagnostics, &(is_integer(&1.line) and &1.line > 0))
      end

      messages =
        for result <- results,
            diagnostic <- diagnostics(result),
            do: Diagnostic.format(diagnostic)

      for fragment <- @fragments do
        assert Enum.any?(messages, &String.contains?(&1, fragment)),
               "no source reached the message containing #{inspect(fragment)}"
      end

      programs = for {:ok, %Logex.Program{} = program} <- results, do: program
      assert length(programs) > 40

      for program <- programs do
        inputs = for {name, %Tag{section: :var_input}} <- program.tags, into: %{}, do: {name, 0}

        Enum.reduce(1..4, Runtime.instance(program), fn _, state ->
          inputs = Map.new(inputs, fn {name, _} -> {name, :rand.uniform(2) - 1} end)
          {_outputs, state} = step(program, state, inputs, :rand.uniform(50))
          state
        end)
      end
    end

    defp diagnostics({:error, diagnostics}), do: diagnostics
    defp diagnostics({:ok, %Logex.Program{warnings: warnings}}), do: warnings
    defp diagnostics({:ok, %FbType{body: body}}), do: body.warnings
  end

  test "an instance's state is a %Logex.Instance{} whose env nests by path" do
    program = program!(@runs_pulse, [block!(@pulse)])

    assert %Instance{env: %{"p" => %{"edge" => 0, "t1" => %{"pre" => 100}}}} =
             Runtime.instance(program)
  end
end
