defmodule Logex.FunctionBlockTest do
  @moduledoc """
  M2-5: user function blocks (PLAN.md §3, Milestone 2; docs/organisation.md §4.3 and
  §4.10). A file whose first rung is `function_block <name>` compiles to its type; a
  program declares instances of it, `var s1 seal`, given the type through
  `Logex.compile/2`'s `types:` or found beside it by `Logex.compile_file/1`, which hands
  back the blocks' warnings among the program's (decision 34); `cal` runs one, rung power
  its EN, nothing copied on a false EN (decision 12). Every diagnostic list here is
  asserted whole, from source. The Done-when is `end_to_end_test.exs`'s, through a
  configuration and `Logex.Runtime.get/2`, from text and from files on disk.
  An online edit of a program that holds blocks is here too (decisions 31 and 32): state
  moves member by member, by path, and the one-shots and timers inside an instance meet
  the rules of `Logex.Edit` by path (§4.9), a one-shot staying blocked until a scan runs
  it.
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

  # A type held in a body: a user block's named there, the built-in timer itself.
  defp held(%FbType{name: name, body: %Logex.Program{}}), do: {:block, name}
  defp held(type), do: type

  # The types a table holds for an instance of `type` (decision 53): the type itself, held,
  # and every type in its own table.
  defp holding(%FbType{name: name, body: %Logex.Program{blocks: blocks}} = type),
    do: Map.put(blocks, name, FbType.held(type))

  defp holding(_type), do: %{}

  # The one table of a body whose tags are `tags`, from the types `known` by name: every
  # type the tags reach at any depth, each once, as a compile builds it.
  defp table(tags, known), do: reach(named(tags), known, %{})

  defp named(tags), do: for({_, %Tag{type: {:block, name}}} <- tags, do: name)

  defp reach([], _known, table), do: table

  defp reach([name | names], known, table) when is_map_key(table, name),
    do: reach(names, known, table)

  defp reach([name | names], known, table) do
    type = Map.fetch!(known, name)
    reach(named(type.body.tags) ++ names, known, Map.put(table, name, type))
  end

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

  @holder """
  function_block holder
  var_input go bool
  var_output o bool
  var s seal
  var t seal

  cal s go go o
  cal t go go o
  """

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

      # A list that is not a proper one, whatever its elements, is no list of types.
      improper = opaque([seal | :seal])

      raises(
        "types must be a list of function block types from Logex.compile/2, got: " <>
          inspect(improper),
        fn -> Logex.compile("var s1 seal", name: "m", types: improper) end
      )

      # The options come in either order, and the message names both.
      assert {:ok, _} = Logex.compile("var s1 seal", types: [seal], name: "m")

      raises(
        "Logex.compile/2 takes a name and, where the source uses function blocks, their " <>
          ~s|types, as in Logex.compile(source, name: "motor", types: [seal]), | <>
          ~s|got: [types: [], name: "m", file: "x"]|,
        fn -> Logex.compile("var s1 seal", opaque(types: [], name: "m", file: "x")) end
      )
    end

    # The body of a type given is one a compile gives: a rung edited by hand into one no
    # compile gives over its table is refused where the type is given, never met by the
    # runtime or an edit, however it is shaped. Since decision 54 so is one a compile gives
    # for other text, the source text left as it was ("a type is the one its source text
    # compiles to").
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

      # An operand on another line than its instruction, which no text gives; warnings and
      # tags a compile never gives either, shaped so that a walk of them would raise: a
      # list that is not a proper one, a struct where a map goes.
      [group, {:xio, line, [{:name, line, "stop"}]}, coil] = rung

      for body <- [
            %{seal.body | rungs: [{:rung, [group, {:xio, line, [{:name, 1, "stop"}]}, coil]}]},
            %{seal.body | warnings: opaque([:junk | :tail])},
            %{seal.body | tags: opaque(%Tag{name: "start", type: :bool, section: :var})},
            %{seal.body | tags: opaque(MapSet.new())},
            %{seal.body | tags: opaque(nil)}
          ] do
        edited = %{seal | body: body}
        refute FbType.user?(edited)

        raises(
          "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
          fn -> Logex.compile("var s1 seal", name: "m", types: [edited]) end
        )

        assert_raise ArgumentError, ~r/unknown function block type "seal"/, fn ->
          Tag.new!("s1", edited)
        end
      end

      # A tag named as no declaration line could name it, every use of it renamed too, in
      # the source text as in the body, so that only the name refuses it (decision 54).
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

        source = String.replace(body.source, ~r/\b#{from}\b/, to)
        FbType.of(%{body | tags: tags, rungs: rungs, source: source})
      end

      pulse = block!(@pulse)
      assert FbType.user?(renamed.(pulse.body, "edge", "edge2"))
      refute FbType.user?(renamed.(pulse.body, "edge", "a b"))
      refute FbType.user?(renamed.(pulse.body, "edge", "xic"))
      refute FbType.user?(renamed.(pulse.body, "edge", "Function_Block"))

      # A type holding a block of its own name, or a timer that is not logex's, none of
      # which a compile gives; and one holding another version of a block for all its
      # instances, which a compile against that version gives.
      v2 = block!(String.replace(@seal, "xio stop", "xio stop xic start"))
      seal = block!(@seal)
      holder = block!(@holder, [seal])

      # A tag's type changed by hand as a compile holds it: a user block's in the one table,
      # under its name, with every type below it, which every tag of it names (decision
      # 53); the built-in timer in the tag.
      retyped = fn type, tag, to ->
        tags = Map.update!(type.body.tags, tag, &%{&1 | type: held(to)})
        blocks = table(tags, Map.merge(type.body.blocks, holding(to)))
        FbType.of(%{type.body | tags: tags, blocks: blocks})
      end

      assert FbType.user?(holder)
      assert retyped.(holder, "t", v2) == block!(@holder, [v2])
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

    # A body's tag table holds what declaration lines give: a line of 1 or more, a section
    # of `var`, `var_input` or `var_output`, an initial value a line could give, and an
    # instance in `var` with none, a timer's preset aside. Each edit but the `retain` one
    # rebuilds the type's members and warnings from the edited table, so that it is the
    # table that is refused; a section no line gives has no role, so that one keeps the
    # compile's members. A timer, idle or given its preset by a `ton`, is moved to
    # each section an instance is never in; Logex.Warnings.of/2 would print a var_output's
    # preset as its value, so the timed one there keeps the compile's warnings.
    test "a type whose tag table no declaration gives is refused where it is given" do
      held =
        block!(
          "function_block held\nvar_input go bool\nvar_output q bool\nvar k dint\nvar s seal\n" <>
            "cal s go go q\nxic go move 1 k",
          [block!(@seal)]
        )

      rebuilt = fn type, tag, edit ->
        body = %{type.body | tags: Map.update!(type.body.tags, tag, edit)}
        typed = Logex.Program.typed_tags(body)
        FbType.of(%{body | warnings: Logex.Warnings.of(body.rungs, typed)})
      end

      assert rebuilt.(held, "k", & &1) == held
      retain = Map.update!(held.body.tags, "k", &%{&1 | section: :retain})

      idle =
        block!(
          "function_block idle\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
            "xic go xic t1.dn ote q"
        )

      timed =
        block!(
          "function_block timed\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
            "xic go ton t1 100\nxic t1.dn ote q"
        )

      assert timed.body.tags["t1"].initial == %{"pre" => 100}
      output = Map.update!(timed.body.tags, "t1", &%{&1 | section: :var_output})

      for edited <- [
            rebuilt.(held, "k", &%{&1 | initial: -1}),
            rebuilt.(held, "go", &%{&1 | initial: 1}),
            rebuilt.(held, "k", &%{&1 | line: 0}),
            rebuilt.(held, "s", &%{&1 | section: :var_output}),
            rebuilt.(held, "s", &%{&1 | initial: %{"run" => 1}}),
            %{held | body: %{held.body | tags: retain}},
            rebuilt.(idle, "t1", &%{&1 | section: :var_input}),
            rebuilt.(idle, "t1", &%{&1 | section: :var_output}),
            rebuilt.(timed, "t1", &%{&1 | section: :var_input}),
            FbType.of(%{timed.body | tags: output})
          ] do
        refute FbType.user?(edited)

        raises(
          "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
          fn -> Logex.compile("var x #{edited.name}", name: "m", types: [edited]) end
        )

        assert_raise ArgumentError, ~r/unknown function block type "#{edited.name}"/, fn ->
          Tag.new!("x", edited)
        end
      end
    end

    # docs/organisation.md §4.10, "Held types", and decision 53: the outermost type holds
    # every block type its instances reach, at any depth, once, in one table, `blocks`,
    # each held with no table of its own, and every instance's tag, at any depth, names its
    # type; so does a program. A type holding them otherwise is refused where it is given:
    # a type in a tag itself, a type no tag reaches, a tag naming one the table lacks, at
    # the top or below it, one under another name than its own, the built-in timer, a held
    # type with a table of its own or with members no compile gives, a type that reaches
    # itself through the table, or no map.
    test "a type holds every block type below it once, in one table, which every instance " <>
           "names" do
      seal = block!(@seal)
      holder = block!(@holder, [seal])
      assert holder.body.blocks == %{"seal" => seal}

      assert for(name <- ["s", "t"], do: holder.body.tags[name].type) ==
               [{:block, "seal"}, {:block, "seal"}]

      [_go, _o, s, t] = holder.members
      assert s.type == {:block, "seal"}
      assert FbType.type_of(holder, t) == FbType.within(seal, holder.body.blocks)
      typed = Logex.Program.typed_tags(holder.body)
      assert typed["t"].type == FbType.type_of(holder, t)
      assert typed["go"] == holder.body.tags["go"]
      assert Logex.Program.typed_tags(%{holder.body | blocks: %{}})["t"].type == {:block, "seal"}

      # One level up, the outermost type holds both, `holder` with no table of its own, and
      # a type read inside it finds the types below it in the outermost's table.
      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_output o bool\nvar h holder\n" <>
            "cal h go o",
          [holder]
        )

      assert outer.body.blocks == %{"holder" => FbType.held(holder), "seal" => seal}
      assert FbType.held(holder).body.blocks == %{} and FbType.held(seal) == seal
      assert outer.body.tags["h"].type == {:block, "holder"}
      inner = FbType.type_of(outer, Enum.find(outer.members, &(&1.name == "h")))
      assert inner == FbType.within(FbType.held(holder), outer.body.blocks)
      assert FbType.type_of(inner, t) == FbType.within(seal, outer.body.blocks)

      # So does a program, its own instances' tags naming their types too.
      program = program!("var_input a bool\nvar_output y bool\nvar x outer\ncal x a y", [outer])
      assert program.tags["x"].type == {:block, "outer"}
      assert program.blocks == Map.put(outer.body.blocks, "outer", FbType.held(outer))

      other = block!(String.replace(@seal, "function_block seal", "function_block other"))
      idle = block!("function_block idle\nvar_output q bool\nvar t1 ton\nxic t1.dn ote q")
      body = holder.body
      timer = Map.update!(idle.body.tags, "t1", &%{&1 | type: {:block, "ton"}})
      top = outer.body

      # `seal` given an instance of `holder`, its warnings rebuilt: `holder` holds `seal`,
      # which holds `holder`.
      x = %Tag{name: "x", type: {:block, "holder"}, section: :var, line: 5}
      looped = %{seal.body | tags: Map.put(seal.body.tags, "x", x)}
      typed = Logex.Program.typed_tags(%{looped | blocks: top.blocks})
      looped = FbType.of(%{looped | warnings: Logex.Warnings.of(looped.rungs, typed)})
      junk = %{FbType.held(holder) | members: [:junk]}
      held_holder = FbType.held(holder)

      # Two types that hold each other, each the one its text compiles to over the other
      # (decision 54), so that only the walk down the table refuses them: `a` holds `b`,
      # which holds `a`, each compiled against a leaf of the other's name and members.
      leaf = &block!("function_block #{&1}\nvar_input go bool\nvar_output q bool\nxic go ote q")

      over =
        &"function_block #{&1}\nvar_input go bool\nvar_output q bool\nvar x #{&2}\ncal x go q"

      a = block!(over.("a", "b"), [leaf.("b")])
      b = block!(over.("b", "a"), [leaf.("a")])
      mutual = %{"a" => FbType.held(a), "b" => FbType.held(b)}

      for edited <- [
            FbType.of(%{body | tags: Map.update!(body.tags, "t", &%{&1 | type: seal})}),
            FbType.of(%{body | blocks: Map.put(body.blocks, "pulse", block!(@pulse))}),
            FbType.of(%{body | blocks: %{}}),
            FbType.of(%{body | blocks: %{"seal" => other}}),
            FbType.of(%{idle.body | tags: timer, blocks: %{"ton" => FbType.ton()}}),
            FbType.of(%{body | blocks: opaque(nil)}),
            FbType.of(%{top | blocks: %{top.blocks | "holder" => holder}}),
            FbType.of(%{top | blocks: Map.delete(top.blocks, "seal")}),
            FbType.of(%{top | blocks: %{top.blocks | "holder" => junk}}),
            FbType.of(%{top | blocks: %{top.blocks | "seal" => %{seal | members: [:junk]}}}),
            FbType.of(%{top | blocks: %{top.blocks | "seal" => looped}}),
            FbType.of(%{a.body | blocks: mutual}),
            FbType.of(%{
              top
              | blocks: %{top.blocks | "holder" => put_in(held_holder.body.tags, opaque(nil))}
            }),
            FbType.of(%{
              top
              | blocks: %{
                  top.blocks
                  | "holder" => put_in(held_holder.body.tags, opaque(x))
                }
            })
          ] do
        refute FbType.user?(edited)

        raises(
          "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
          fn -> Logex.compile("var x #{edited.name}", name: "m", types: [edited]) end
        )

        assert_raise ArgumentError, ~r/unknown function block type "#{edited.name}"/, fn ->
          Tag.new!("x", edited)
        end
      end
    end

    # Decision 53: a compile given several types checks a type their tables share once
    # (Logex.FbType.check/2), but only over the same types it names: a type held the same
    # in two tables whose `seal` differs is checked again over each, so a hand-edited table
    # whose `seal` the shared type does not lower against is refused as given, as it is
    # alone, and not passed over for another version of `seal`.
    test "a type two types given share is checked once, and again where what it names differs" do
      seal = block!(@seal)
      holder = block!(@holder, [seal])

      outer = fn name ->
        block!(
          "function_block #{name}\nvar_input go bool\nvar_output o bool\nvar h holder\n" <>
            "cal h go o",
          [holder]
        )
      end

      one = outer.("one")
      two = outer.("two")
      assert one.body.blocks == two.body.blocks
      assert {:ok, checked} = FbType.check(one, %{})
      assert {:ok, _} = FbType.check(two, checked)
      assert {:ok, _} = Logex.compile("var x one\nvar y two", name: "m", types: [one, two])

      narrow =
        block!(
          "function_block seal\nvar_input start bool\nvar_output run bool\nxic start ote run"
        )

      bad = FbType.of(%{two.body | blocks: %{two.body.blocks | "seal" => narrow}})
      refute FbType.user?(bad)
      assert FbType.check(bad, checked) == :error

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(bad)}",
        fn -> Logex.compile("var x one\nvar y two", name: "m", types: [one, bad]) end
      )
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

      # Two versions that differ only in their warnings are one (docs/organisation.md
      # §4.10); two whose text differs, if only in a comment, are two.
      commented = block!(@seal <> "// sealed in\n")
      assert commented.body.rungs == old.body.rungs and commented.members == old.members

      raises(message, fn -> Logex.compile("var o outer", name: "m", types: [commented, outer]) end)

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

      # The version a type given holds counts though no line declares the type that holds
      # it.
      raises(tagged, fn ->
        Logex.Compiler.instructionize(
          ast("var_input a bool\nvar_output q bool\ncal s0 a a q"),
          [Tag.new!("s0", new)],
          [outer]
        )
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

      # So same?/2 compares the types two versions hold, by name: one version where they
      # are, two where they are not, though the holders' own text is one.
      assert FbType.same?(outer, outer_from_file)
      new = block!(String.replace(warned, "xio stop", "xio stop xic start"))

      outer_new =
        block!(
          "function_block outer\nvar_input go bool\nvar_output o bool\nvar s seal\ncal s go go o",
          [new]
        )

      refute FbType.same?(outer, outer_new)

      # And their tag tables: two compiled from no text, which differ only in the line of a
      # declaration, are two.
      blk = fn text ->
        {:ok, type} = Logex.Compiler.instructionize(ast("function_block blk\n" <> text))
        type
      end

      one = blk.("var_input b bool\n// a comment\nvar_output q bool\nxic b ote q")
      other = blk.("var_input b bool\nvar_output q bool\n// a comment\nxic b ote q")
      assert one.body.rungs == other.body.rungs and one.members == other.members
      refute FbType.same?(one, other)

      assert {:ok, %Logex.Program{}} =
               Logex.compile("var o outer\nvar w wrap", name: "m", types: [outer_from_file, wrap])

      assert {:ok, %Logex.Program{}} =
               Logex.Compiler.instructionize(ast("var o outer"), [Tag.new!("s", from_file)], [
                 outer
               ])

      # A block given both versions, one inside a type it holds, is a type a compile gives,
      # which a second compile and Logex.Tag.new!/4 take.
      both = fn version, held ->
        pair =
          block!(
            "function_block pair\nvar_input go bool\nvar_output o bool\nvar s seal\n" <>
              "cal s go go o",
            [held]
          )

        block!(
          "function_block both\nvar_input go bool\nvar_output o bool\nvar p pair\n" <>
            "var s seal\ncal p go o\ncal s go go o",
          [pair, version]
        )
      end

      for {version, held} <- [{from_text, from_file}, {from_file, other_spelling}] do
        type = both.(version, held)
        assert FbType.user?(type)
        assert {:ok, _} = Logex.compile("var b both", name: "m", types: [type])
        assert %Tag{type: ^type} = Tag.new!("b", type)
      end

      # Each version is checked, the second as the first: here the `seal` the body holds for
      # `s`, its warnings edited by hand, after `pair`, which holds the other and is checked
      # first.
      type = both.(from_text, from_file)
      edited = %{from_text | body: %{from_text.body | warnings: []}}

      refute FbType.user?(
               FbType.of(%{type.body | blocks: %{type.body.blocks | "seal" => edited}})
             )

      # A version is its rungs too: `seal` with a rung edited by hand and its source text
      # left as it was is another version than the one `outer` holds. Since decision 54 it
      # is no type a compile takes, its body not the one its text gives, and is refused
      # where it is given, before any version is compared.
      [{:rung, [group, {:xio, l, stop}, coil]}] = from_text.body.rungs
      rung = [{:rung, [group, {:xic, l, stop}, coil]}]
      rung_edited = %{from_text | body: %{from_text.body | rungs: rung}}
      assert rung_edited.body.source == from_text.body.source
      refute FbType.same?(from_text, rung_edited)

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(rung_edited)}",
        fn -> Logex.compile("var o outer", name: "m", types: [rung_edited, outer]) end
      )

      # And every type two versions hold is compared, not only the first by name: two
      # holders of `pulse` and `seal` that differ only in the `seal` they hold, which sorts
      # after `pulse`, are two.
      holds = fn seal ->
        block!(
          "function_block holds\nvar_input go bool\nvar_output o bool\nvar_output r bool\n" <>
            "var p pulse\nvar s seal\ncal p go o\ncal s go go r",
          [block!(@pulse), seal]
        )
      end

      assert Map.keys(holds.(from_text).body.blocks) == ["pulse", "seal"]
      assert FbType.same?(holds.(from_text), holds.(from_file))
      refute FbType.same?(holds.(from_text), holds.(new))
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
      assert program.tags["s1"].type == {:block, "seal"} and program.blocks == %{"seal" => seal}

      # A block's member declared from Elixir has no line: it comes first in cal's order,
      # those from Elixir by name. Such a type, which instructionize/3 gives, has no source
      # text, so none to compile again, and since decision 54 it is no type a compile takes.
      ast = ast("function_block blk\nvar_output q bool\nxic a ote q")
      declared = [Tag.new!("b", :bool, :var_input), Tag.new!("a", :bool, :var_input)]
      assert {:ok, %FbType{} = blk} = Logex.Compiler.instructionize(ast, declared)
      assert Enum.map(blk.members, & &1.name) == ["a", "b", "q"]
      assert blk.body.source == nil
      refute FbType.user?(blk)

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(blk)}",
        fn -> Logex.compile("var k blk", name: "m", types: [blk]) end
      )

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

  # Decision 54: each type a compile is given, and each type its table holds, is compiled
  # again from its body's source text, over the types it names as the table holds them, and
  # must be what that compile gives, the file its body was read from aside. So a type edited
  # by hand into one a compile gives for other text is refused where it is given: a rung
  # edited into another that text could say, or a tag table into one declaration lines could
  # give, its source text left as it was; or its source text edited, its body left as it
  # was. Each edit is one Logex.Compiler.lowered?/1 takes, which until decision 54 was the
  # whole check of a body; each is refused as a type given, through Logex.Tag.new!/4 and
  # within a holder's table.
  describe "a type is the one its source text compiles to (decision 54)" do
    test "a rung edited into another that text could say, its source text left as it was, " <>
           "is refused where it is given" do
      seal = block!(@seal)
      [{:rung, [group, {:xio, l, stop}, coil]}] = seal.body.rungs
      said = String.replace(@seal, "xio stop", "xic stop")
      rung = %{seal.body | rungs: [{:rung, [group, {:xic, l, stop}, coil]}]}
      assert block!(said).body == %{rung | source: said}
      refused(FbType.of(rung))

      # And so inside the one table: the `seal` a holder holds, refused where the holder is
      # given.
      holder = block!(@holder, [seal])
      refused(FbType.of(%{holder.body | blocks: %{"seal" => FbType.of(rung)}}))
    end

    test "a tag table edited into one declaration lines could give is refused where it is " <>
           "given" do
      # The members and the warnings rebuilt from the edited table: an initial value, a
      # section, a line, and a key a tag never has.
      counter =
        block!(
          "function_block counter\nvar_input go bool\nvar_output n dint 3\n\n" <>
            "xic go move 7 n"
        )

      retagged = fn type, tag, edit ->
        body = %{type.body | tags: Map.update!(type.body.tags, tag, edit)}
        FbType.of(%{body | warnings: Logex.Warnings.of(body.rungs, body.tags)})
      end

      for edited <- [
            retagged.(counter, "n", &%{&1 | initial: 5}),
            retagged.(counter, "go", &%{&1 | section: :var}),
            retagged.(counter, "n", &%{&1 | line: 4}),
            retagged.(counter, "go", &Map.put(&1, :retain, true))
          ],
          do: refused(edited)

      holder =
        block!(
          "function_block holder\nvar_input go bool\nvar_output n dint\nvar c counter\n" <>
            "cal c go n",
          [counter]
        )

      edited = retagged.(counter, "n", &%{&1 | initial: 5})
      refused(FbType.of(%{holder.body | blocks: %{"counter" => edited}}))
    end

    # The source text edited, the body left as it was: a contact the body does not hold, a
    # blank line before the header that moves every line, a rung with a mistake whose words
    # lower to nothing, a line declaring a tag twice, which leaves the first, text that does
    # not lex or parse, another block's header, a program's text, text that is no block, no
    # text, and no binary; and a file that is no path, or a path to a file named after
    # another block. A source text that gives that very body, a comment more, is the type a
    # compile gives for it, and the file a body was read from is kept, a path to a file of
    # the block's name, which stamps each warning with it.
    test "a source text edited, its body left as it was, is refused where it is given" do
      seal = block!(@seal)

      for source <- [
            String.replace(@seal, "xio stop", "xic stop"),
            "\n" <> @seal,
            @seal <> "xyz run\n",
            String.replace(@seal, "run bool\n\n", "run bool\nvar_input start bool\n"),
            @seal <> "xic 1bst ote run\n",
            @seal <> "( xic start\n",
            String.replace(@seal, "function_block seal", "function_block other"),
            "var_input start bool\nvar_input stop bool\nvar_output run bool\nxic start ote run",
            "garbage",
            nil,
            42
          ],
          do: refused(%{seal | body: %{seal.body | source: source}})

      for file <- [[], "other.ld"], do: refused(%{seal | body: %{seal.body | file: file}})

      holder = block!(@holder, [seal])
      edited = %{seal | body: %{seal.body | source: "\n" <> @seal}}
      refused(FbType.of(%{holder.body | blocks: %{"seal" => edited}}))

      commented = %{seal | body: %{seal.body | source: @seal <> "// sealed in\n"}}
      assert FbType.user?(commented)
      assert commented == block!(@seal <> "// sealed in\n")
      assert FbType.user?(%{seal | body: %{seal.body | file: "/any/where/seal.ld"}})

      unused =
        block!(
          String.replace(@seal, "var_output run bool\n", "var_output run bool\nvar n bool\n")
        )

      [warning] = unused.body.warnings
      stamped = %{unused.body | file: "seal.ld", warnings: [%{warning | file: "seal.ld"}]}
      assert FbType.user?(%{unused | body: stamped})
      refute FbType.user?(%{unused | body: %{stamped | warnings: [warning]}})
      refute FbType.user?(%{unused | body: %{stamped | file: nil}})
    end

    test "the check and the compile again are total" do
      seal = block!(@seal)
      assert FbType.check(seal, opaque(:checked)) == :error
      assert Logex.Compiler.recompiled(@seal, "seal", opaque(:held)) == :error
      assert {:ok, body} = Logex.Compiler.recompiled(@seal, "seal", %{})
      assert FbType.of(%{body | source: @seal}) == seal
    end

    # Each edit, one the shape check took, refused as a type given to a compile and to
    # Logex.Tag.new!/4.
    defp refused(%FbType{name: name} = edited) do
      assert Logex.Compiler.lowered?(FbType.within(edited, edited.body.blocks).body)
      refute FbType.user?(edited)

      raises(
        "types must be function block types from Logex.compile/2, got: #{inspect(edited)}",
        fn -> Logex.compile("var x #{name}", name: "m", types: [edited]) end
      )

      assert_raise ArgumentError, ~r/unknown function block type "#{name}"/, fn ->
        Tag.new!("x", edited)
      end
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

    # The same rule for a block name no compile knows (docs/organisation.md §4.10
    # "Declarations"): misspelled, or not given, its instance's `cal` and members are not
    # each reported as undeclared, in a program or in a block's file.
    test "a misspelled block name gives one message, its instance's uses none" do
      program =
        "var_input a bool\nvar_output q bool\nvar s1 sael\nxic a ote q\n" <>
          "cal s1 a a q\nxic s1.run ote q"

      assert errors(program, [block!(@seal)]) == [
               "line 3: unknown type `sael`: logex has `bool`, `dint` and `ton`, " <>
                 "and the function block `seal` — did you mean `seal`?"
             ]

      assert errors(String.replace(program, "sael", "seal")) == [
               "line 3: unknown type `seal`: logex has `bool`, `dint` and `ton`"
             ]

      # A block's name is matched exactly, as a tag's is.
      assert errors(String.replace(program, "sael", "Seal"), [block!(@seal)]) == [
               "line 3: unknown type `Seal`: logex has `bool`, `dint` and `ton`, " <>
                 "and the function block `seal` — did you mean `seal`? " <>
                 "(type names are case-sensitive)"
             ]

      assert errors("function_block m\n" <> program, [block!(@seal)], "m") == [
               "line 4: unknown type `sael`: logex has `bool`, `dint` and `ton`, " <>
                 "and the function block `seal` — did you mean `seal`?"
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

      for held <- [b, c] do
        raises(
          "`y` holds an instance of `a`, the function block being compiled: " <>
            "a function block never holds an instance of itself, at any depth",
          fn -> Logex.Compiler.instructionize(ast, [Tag.new!("y", held)], []) end
        )
      end
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

      # One too many is read as the next instruction, as after any instruction.
      assert errors(@decl <> "cal s1 a b q r\nxic a ton t1 5", [seal]) == [
               "line 7: unknown instruction `r`"
             ]

      assert errors(@decl <> "cal s1 a b q 5\nxic a ton t1 5", [seal]) == [
               "line 7: expected an instruction, found `5`"
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
            "xio en otu q\nxic en cal s1 a 0 q",
          [seal]
        )

      {outputs, state} = step(program, Runtime.instance(program), %{"a" => 1, "en" => 1}, 0)
      frozen = state.env["s1"]
      assert frozen == %{"start" => 1, "stop" => 0, "run" => 1}
      assert outputs == %{"q" => 1}

      # Its EN false, a changed input is not read in, the body does not run, and nothing is
      # written out: `q`, which the rung above clears, stays cleared, where a copy out of
      # the frozen `run` would set it again.
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
      hand = %{motor | blocks: %{motor.blocks | "seal" => edited}}

      {outputs, state} = step(hand, Runtime.instance(hand), %{"a1" => 1, "en3" => 1}, 0)
      assert outputs["k1"] == 1

      # Its body is no part of the block's type for the edit (decision 31), so an edit to the
      # program the compiler gives, and back, takes every step.
      for candidate <- [hand, motor] do
        assert {:ok, edit, _forecast} = Edit.accept(hand, candidate, state)
        {edit, tested, _report} = Edit.test(edit, state)
        assert {_edit, %Instance{}, _report} = Edit.untest(edit, tested)
      end
    end

    # An instance names its type, which the program's one table holds (decision 53); a
    # program built by hand may name one its table lacks, hold something that is no type
    # under its name, or hold no map of them.
    test "a program built by hand whose instance names a type it does not hold runs nothing " <>
           "there: nothing escapes" do
      seal = block!(@seal)
      motor = program!(@three, [seal])
      {outputs, _} = step(motor, Runtime.instance(motor), %{"a1" => 1}, 0)
      assert outputs["k1"] == 1 and motor.tags["s1"].type == {:block, "seal"}

      for blocks <- [%{}, nil, %{"seal" => :junk}] do
        hand = %{motor | blocks: blocks}
        {outputs, state} = step(hand, Runtime.instance(hand), %{"a1" => 1}, 0)
        assert outputs["k1"] == 0 and state.env["s1"] == 0
      end
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

    test "the scan's tag table, and the block types it holds, are the runtime's" do
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

      raises(
        "scan.blocks is the runtime's, taken from the program: a host leaves it out, got: %{}",
        fn ->
          Runtime.call(program, Runtime.instance(program), %{}, %Scan{
            now: 0,
            first: true,
            blocks: %{}
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

    test "the bits of instances no scan ran stay blocked, sorted by path" do
      program =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output y bool\nvar_output z bool\n" <>
            "var p1 pulse\nvar p2 pulse\nxic en cal p1 a y\nxic en cal p2 a z",
          [block!(@pulse)]
        )

      state = blocked(program, ["p1.edge", "p2.edge"])
      {_, state} = step(program, state, %{"a" => 1, "en" => 0})
      assert state.ons_blocked == ["p1.edge", "p2.edge"]
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

      # Shapes a walk of them would raise on: warnings that are no proper list, and a
      # struct, which is a map, for the tags.
      for junk <- [
            %{body(@two) | warnings: opaque([:junk | :tail])},
            %{body(@two) | tags: opaque(%Tag{name: "go", type: :bool, section: :var})},
            %{body(@two) | tags: opaque(MapSet.new())}
          ],
          do: refute(Logex.Compiler.lowered?(junk))

      # Its tags each a tag of a type a compile knows, once each type its blocks hold is
      # given: a tag naming a type its blocks lack, blocks that are no map, and an entry that
      # is no tag would each be lowered against nothing a compile gives.
      holder = body(@holder, [block!(@seal)])
      assert Logex.Compiler.lowered?(holder)

      for junk <- [
            %{holder | blocks: %{}},
            %{holder | blocks: opaque(nil)},
            %{body(@two) | tags: Map.put(body(@two).tags, "go", :junk)}
          ],
          do: refute(Logex.Compiler.lowered?(junk))
    end

    test "its rungs are on rising lines" do
      two = body(@two)
      [{:rung, q}, {:rung, r}] = two.rungs
      assert Logex.Compiler.lowered?(relined(two, [{:rung, line(q, 5)}, {:rung, line(r, 6)}]))
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(r, 5)}, {:rung, line(q, 5)}]))
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(r, 6)}, {:rung, line(q, 5)}]))
    end

    test "each rung is on one line, its operands too" do
      two = body(@two)
      [{:rung, [contact, coil]}, r] = two.rungs
      over_two = [{:rung, [contact, at_line(coil, 6)]}, at_rung(r, 7)]
      assert Logex.Compiler.lowered?(relined(two, [{:rung, [contact, coil]}, at_rung(r, 7)]))
      refute Logex.Compiler.lowered?(relined(two, over_two))

      {:xic, line, [{:name, line, go}]} = contact
      operand = [{:rung, [{:xic, line, [{:name, 1, go}]}, coil]}, r]
      refute Logex.Compiler.lowered?(relined(two, operand))

      # An operand past an instruction's first, and one inside a group and inside a group
      # nested in another, each moved to line 1: the walk reaches every one
      # (CONTRIBUTING.md, a walk over a rung).
      nested =
        body(
          "function_block nested\nvar_input go bool\nvar_output q bool\nvar n dint\n" <>
            "xic go move 1 n\n( xic go | ( xic go | xio go ) ) ote q"
        )

      [
        {:rung, [contact, {:move, l, [one, n]}]} = moves,
        {:rung, [{:branches, [[outer], [{:branches, [[inner], low]}]]}, coil]} = group
      ] = nested.rungs

      first = fn {symbol, at, [operand | rest]} ->
        {symbol, at, [put_elem(operand, 1, 1) | rest]}
      end

      assert Logex.Compiler.lowered?(nested)

      for rungs <- [
            [{:rung, [contact, {:move, l, [one, put_elem(n, 1, 1)]}]}, group],
            [
              moves,
              {:rung, [{:branches, [[first.(outer)], [{:branches, [[inner], low]}]]}, coil]}
            ],
            [
              moves,
              {:rung, [{:branches, [[outer], [{:branches, [[first.(inner)], low]}]]}, coil]}
            ]
          ],
          do: refute(Logex.Compiler.lowered?(relined(nested, rungs)))
    end

    test "its rungs come after its declarations, each on a line of its own" do
      two = body(@two)
      [{:rung, q}, {:rung, r}] = two.rungs
      refute Logex.Compiler.lowered?(relined(two, [{:rung, line(q, 3)}, {:rung, line(r, 6)}]))

      # `q` moved to `go`'s line, 2, or to the header's, 1, which no declaration holds.
      assert Logex.Compiler.lowered?(%{two | tags: Map.update!(two.tags, "q", &%{&1 | line: 1})})
      refute Logex.Compiler.lowered?(%{two | tags: Map.update!(two.tags, "q", &%{&1 | line: 2})})
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

  describe "an online edit of a program that holds blocks (decisions 31 and 32)" do
    defp pulse(extra \\ "", decl \\ ""),
      do:
        block!("""
        function_block pulse
        var_input go bool
        var_output q bool
        var edge bool
        var t1 ton
        #{decl}
        xic go ons edge ote q
        xic go ton t1 100
        #{extra}
        """)

    defp runs(pulse, rungs \\ "xic en cal p a y"),
      do: program!(String.replace(@runs_pulse, "xic en cal p a y", rungs), [pulse])

    defp running(program, steps), do: drive(program, Runtime.instance(program), steps)

    defp accept!(running, candidate, state) do
      {:ok, edit, _forecast} = Edit.accept(running, candidate, state)
      edit
    end

    test "an instance of a block both programs hold unchanged moves whole" do
      pulse = pulse()
      v1 = runs(pulse)

      v2 =
        program!(String.replace(@runs_pulse, "var p pulse", "var p pulse\nvar k bool"), [pulse])

      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {30, %{}}])
      assert {:ok, edit, [{:added, "k", 0}]} = Edit.accept(v1, v2, state)
      {edit, tested, [{:added, "k", 0}]} = Edit.test(edit, state)
      assert tested.env["p"] == state.env["p"]
      assert {^v2, _state, []} = Edit.assemble(edit, tested)
    end

    test "the block's body is not its type: an edit may change it" do
      v1 = runs(pulse())
      v2 = runs(pulse("xic q otl edge"))
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}])
      assert {:ok, _edit, []} = Edit.accept(v1, v2, state)
    end

    test "a member whose kind changes is refused, by its path; a block renamed is a type change" do
      v1 = runs(pulse())
      v2 = runs(pulse("xic go move 1 n", "var n dint"))

      changed =
        runs(
          block!("""
          function_block pulse
          var_input go bool
          var_output q bool
          var edge dint
          var e bool
          var t1 ton

          xic go ons e ote q
          xic go ton t1 100
          xic go move 1 edge
          """)
        )

      {_, state} = running(v1, [{0, %{}}])
      assert {:ok, _, _} = Edit.accept(v1, v2, state)

      assert {:error, [diagnostic]} = Edit.accept(v1, changed, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p.edge` is a bool in the running program and a dint in the candidate: " <>
                 "a member's type changes only with a restart"

      # A member holding an instance of one block in the running program and of another in
      # the candidate: a block's name takes no article.
      inner = block!("function_block inner\nvar_input go bool\nvar_output q bool\nxic go ote q")
      other = block!("function_block other\nvar_input go bool\nvar_output q bool\nxic go ote q")

      mid = fn type ->
        block!(
          "function_block mid\nvar_input go bool\nvar_output q bool\nvar k #{type}\n" <>
            "cal k go q",
          [type |> then(&%{"inner" => inner, "other" => other}[&1])]
        )
      end

      holds = fn type ->
        program!("var_input go bool\nvar_output q bool\nvar w mid\ncal w go q", [mid.(type)])
      end

      {_, held} = running(holds.("inner"), [{0, %{}}])
      assert {:error, [diagnostic]} = Edit.accept(holds.("inner"), holds.("other"), held)

      assert Diagnostic.format(diagnostic) ==
               "line 3: `w.k` is an instance of `inner` in the running program and an " <>
                 "instance of `other` in the candidate: a member's type changes only with a restart"

      # Several in one instance, on its one line, by path.
      pair = fn type ->
        block =
          block!(
            "function_block pair\nvar_input go bool\nvar_output q bool\nvar zz #{type}\n" <>
              "var aa #{type}\nxic go ote q"
          )

        program!("var_input go bool\nvar_output q bool\nvar p pair\ncal p go q", [block])
      end

      {_, pairs} = running(pair.("bool"), [{0, %{}}])
      assert {:error, diagnostics} = Edit.accept(pair.("bool"), pair.("dint"), pairs)

      assert Enum.map(diagnostics, &Diagnostic.format/1) ==
               for(
                 member <- ["p.aa", "p.zz"],
                 do:
                   "line 3: `#{member}` is a bool in the running program and a dint in the " <>
                     "candidate: a member's type changes only with a restart"
               )

      latch = block!(String.replace(@pulse, "function_block pulse", "function_block latch"))
      renamed = program!(String.replace(@runs_pulse, "var p pulse", "var p latch"), [latch])
      assert {:error, [diagnostic]} = Edit.accept(v1, renamed, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p` is an instance of `pulse` in the running program and an instance " <>
                 "of `latch` in the candidate: a tag's type changes only with a restart"

      timer =
        program!(
          "var_input a bool\nvar_input en bool\nvar_output y bool\nvar p ton\nxic en ton p 5",
          []
        )

      assert {:error, [diagnostic]} = Edit.accept(v1, timer, state)

      assert Diagnostic.format(diagnostic) ==
               "line 4: `p` is an instance of `pulse` in the running program and a ton in the " <>
                 "candidate: a tag's type changes only with a restart"
    end

    test "a member the block adds starts at its initial value in the instance, and one it " <>
           "drops is kept until assemble prunes it, each by its path" do
      v1 = runs(pulse("", "var old dint 4"))
      v2 = runs(pulse("", "var count dint 7"))
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}])

      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "p.count", 7}]
      assert %{"old" => 4, "count" => 7} = state.env["p"]

      # The test pruned nothing, so the original finds its member again.
      {edit, state, report} = Edit.untest(edit, state)
      assert report == []
      assert state.env["p"]["old"] == 4
      {edit, state, _} = Edit.test(edit, state)
      {_, state, report} = Edit.assemble(edit, state)
      assert report == [{:pruned, "p.old", 4}]
      refute Map.has_key?(state.env["p"], "old")
    end

    test "a kept member whose initial value changed keeps its value, and is reported" do
      v1 = runs(pulse("", "var n dint 5"))
      v2 = runs(pulse("", "var n dint 6"))
      {_, state} = running(v1, [{0, %{}}])

      assert {_, state, [{:initial_changed, "p.n", {5, 6}}]} =
               Edit.test(accept!(v1, v2, state), state)

      assert state.env["p"]["n"] == 5
    end

    test "an ons in a block's rung the edit changes is blocked by its path, in every " <>
           "instance, and a top-level bit of the same name is not" do
      body = fn condition ->
        block!(
          "function_block pulse\nvar_input go bool\nvar_output q bool\nvar edge bool\n" <>
            "#{condition} ons edge ote q"
        )
      end

      program = fn pulse ->
        program!(
          "var_input a bool\nvar_output y1 bool\nvar_output y2 bool\nvar_output z bool\n" <>
            "var edge bool\nvar p1 pulse\nvar p2 pulse\n" <>
            "cal p1 a y1\ncal p2 a y2\nxic a ons edge ote z",
          [pulse]
        )
      end

      v1 = program.(body.("xic go"))
      v2 = program.(body.("xic go xic go"))
      {_, state} = running(v1, [{0, %{"a" => 0}}])

      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:ons_blocked, "p1.edge", 0}, {:ons_blocked, "p2.edge", 0}]
      assert state.ons_blocked == ["p1.edge", "p2.edge"]

      # The rising edge on the switch scan passes in neither block, and does at the top.
      {outputs, state} = step(v2, state, %{"a" => 1})
      assert outputs == %{"y1" => 0, "y2" => 0, "z" => 1}
      assert state.ons_blocked == []
      assert get_in(state.env, ["p1", "edge"]) == 1
    end

    test "a nested block an earlier edit left pending survives a second edit before any " <>
           "scan (F2)" do
      v1 = runs(pulse())
      v2 = runs(block!(String.replace(@pulse, "xic go ons edge", "xic go xic go ons edge")))

      v3 =
        program!(
          String.replace(@runs_pulse, "var_output y bool", "var_output y bool\nvar k bool"),
          [v2.blocks["pulse"]]
        )

      {_, state} = running(v1, [{0, %{"a" => 0, "en" => 1}}])
      {edit, state, [{:ons_blocked, "p.edge", 0}]} = Edit.test(accept!(v1, v2, state), state)
      {^v2, state, _} = Edit.assemble(edit, state)

      {_edit, state, report} = Edit.test(accept!(v2, v3, state), state)
      assert report == [{:added, "k", 0}, {:ons_blocked, "p.edge", 0}]
      {outputs, _state} = step(v3, state, %{"a" => 1})
      assert outputs == %{"y" => 0}
    end

    # A block on a one-shot inside an instance whose `cal` is false on the switch scan is
    # not used up unseen: it holds until a scan runs the instance's body, or the `ons` would
    # compare its changed rung against the bit the old rung wrote, and pulse (decision 21).
    defp frozen_edit do
      blk = fn condition ->
        block!(
          "function_block blk\nvar_input a bool\nvar_output q bool\nvar e bool\n" <>
            "#{condition} a ons e ote q"
        )
      end

      source =
        "var_input a bool\nvar_input en bool\nvar_output q bool\nvar x blk\nxic en cal x a q"

      {program!(source, [blk.("xio")]), program!(source, [blk.("xic")]), source}
    end

    test "a one-shot blocked inside an instance whose cal is false stays blocked until a " <>
           "scan runs the instance's body" do
      {v1, v2, _source} = frozen_edit()
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {10, %{}}, {10, %{"en" => 0}}])

      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:ons_blocked, "x.e", 0}]

      {outputs, state} = step(v2, state, %{}, 10)
      assert outputs == %{"q" => 0}
      assert state.ons_blocked == ["x.e"]

      {outputs, state} = step(v2, state, %{"en" => 1}, 10)
      assert outputs == %{"q" => 0}
      assert state.ons_blocked == []

      # The candidate alone, from the same inputs, never sees an edge on `a` either.
      {outputs, _state} =
        running(v2, [
          {0, %{"a" => 1, "en" => 1}},
          {10, %{}},
          {10, %{"en" => 0}},
          {10, %{"en" => 1}}
        ])

      assert outputs == %{"q" => 0}
    end

    test "a one-shot still blocked after a scan stays blocked through the next edit's switch" do
      {v1, v2, source} = frozen_edit()

      v3 =
        program!(String.replace(source, "var x blk", "var x blk\nvar k bool"), [v2.blocks["blk"]])

      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {10, %{}}, {10, %{"en" => 0}}])
      {edit, state, _report} = Edit.test(accept!(v1, v2, state), state)
      {^v2, state, _report} = Edit.assemble(edit, state)
      {_outputs, state} = step(v2, state, %{}, 10)
      assert state.ons_blocked == ["x.e"]

      # v3 runs `x` from the rung v2 does, so only what is still pending blocks it.
      {_edit, state, report} = Edit.test(accept!(v2, v3, state), state)
      assert report == [{:added, "k", 0}, {:ons_blocked, "x.e", 0}]
      {outputs, _state} = step(v3, state, %{"en" => 1}, 10)
      assert outputs == %{"q" => 0}
    end

    # A block's inputs reordered: `cal x i1 i2 q` reads the same, but now fills `a` from
    # `i2`, so the `ons` that reads `a` is under a changed rung, as an edit of the operands
    # would make it.
    test "an edit that reorders a block's inputs blocks the one-shots it runs, as an edit " <>
           "of the cal's operands does" do
      blk = fn first, second ->
        block!(
          "function_block blk\nvar_input #{first} bool\nvar_input #{second} bool\n" <>
            "var_output q bool\nvar e bool\nxic a ons e ote q"
        )
      end

      source = "var_input i1 bool\nvar_input i2 bool\nvar_output q bool\nvar x blk\ncal x i1 i2 q"
      v1 = program!(source, [blk.("a", "b")])
      v2 = program!(source, [blk.("b", "a")])

      swapped =
        program!(String.replace(source, "cal x i1 i2 q", "cal x i2 i1 q"), [blk.("a", "b")])

      {_, state} = running(v1, [{0, %{"i1" => 0, "i2" => 1}}, {10, %{}}])

      for candidate <- [v2, swapped] do
        {_edit, later, report} = Edit.test(accept!(v1, candidate, state), state)
        assert report == [{:ons_blocked, "x.e", 0}]
        assert {%{"q" => 0}, _} = step(candidate, later, %{}, 10)
      end
    end

    test "an ons in a block run from a rung the edit changes is blocked; one under " <>
           "unchanged rungs keeps its real edge" do
      pulse = pulse()
      v1 = runs(pulse)
      v2 = runs(pulse, "xic en xic en cal p a y")
      v3 = runs(pulse, "xic en cal p a y\nxic a ote y")
      {_, state} = running(v1, [{0, %{"a" => 0, "en" => 1}}])

      {_edit, _state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:ons_blocked, "p.edge", 0}]

      {_edit, state, report} = Edit.test(accept!(v1, v3, state), state)
      assert report == []
      {outputs, _state} = step(v3, state, %{"a" => 1})
      assert outputs == %{"y" => 1}
    end

    test "an instance the edit adds starts whole, its one-shots blocked for the switch scan" do
      pulse = pulse()
      v1 = runs(pulse)

      v2 =
        program!(
          """
          var_input a bool
          var_input en bool
          var_output y bool
          var_output y2 bool
          var p pulse
          var p2 pulse

          xic en cal p a y
          cal p2 a y2
          """,
          [pulse]
        )

      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}])
      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)

      assert [{:added, "p2", added}, {:added, "y2", 0}, {:ons_blocked, "p2.edge", 0}] = report
      assert added == FbType.initial(pulse)
      {outputs, _state} = step(v2, state, %{})
      assert outputs["y2"] == 0
    end

    test "a timer in a frozen block is not resumed by a switch, and catches up (decision 8); " <>
           "one whose cal the candidate restores resumes from the switch (decision 23)" do
      pulse = pulse()
      v1 = runs(pulse)
      v2 = runs(pulse, "xic en cal p a y\nxic a ote y")

      {_, state} =
        running(v1, [{0, %{"a" => 1, "en" => 1}}, {30, %{}}, {10, %{"en" => 0}}, {100, %{}}])

      assert %{"acc" => 30, "en" => 1, "last" => 30} = state.env["p"]["t1"]

      # Both programs run the timer, frozen by its EN: no resume.
      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == []
      {_, state} = step(v2, state, %{"en" => 1})
      assert %{"acc" => 100, "dn" => 1} = state.env["p"]["t1"]

      # The candidate drops the cal, so no program runs the timer; a later one restores it.
      dropped = runs(pulse, "xic a ote y")
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {30, %{}}])
      {edit, state, _} = Edit.test(accept!(v1, dropped, state), state)
      {_, state, _} = Edit.assemble(edit, state)
      {_, state} = drive(dropped, state, [{100, %{}}])
      # The cal's rung is added again, so the one-shot under it is blocked too.
      {_edit, state, report} = Edit.test(accept!(dropped, v1, state), state)
      assert report == [{:ons_blocked, "p.edge", 1}, {:resumed, "p.t1", 100}]
      {_, state} = step(v1, state, %{}, 10)
      assert %{"acc" => 40} = state.env["p"]["t1"]
    end

    test "a timer inside a block meets the preset rules by its path" do
      v1 = runs(pulse())
      v2 = runs(block!(String.replace(@pulse, "ton t1 100", "ton t1 250")))
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {120, %{}}])
      assert %{"pre" => 100, "dn" => 1} = state.env["p"]["t1"]

      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:dn_drops, "p.t1", {100, 250}}, {:preset, "p.t1", {100, 250}}]
      assert state.env["p"]["t1"]["pre"] == 250
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:preset, "p.t1", {250, 100}}]
      assert state.env["p"]["t1"]["pre"] == 100
    end

    # Logic moved its `.pre`, so a switch keeps it rather than the candidate's preset, and
    # says so by its path, in the forecast and in the report.
    test "a timer inside a block whose .pre logic moved keeps it, reported by its path" do
      timed = fn preset ->
        block!(
          String.replace(@pulse, "ton t1 100", "ton t1 #{preset}") <> "xic go move 7 t1.pre\n"
        )
      end

      v1 = runs(timed.(100))
      v2 = runs(timed.(200))
      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}])
      assert state.env["p"]["t1"]["pre"] == 7

      kept = [{:preset_kept, "p.t1", {7, 200}}]
      assert {:ok, edit, ^kept} = Edit.accept(v1, v2, state)
      assert {_edit, state, ^kept} = Edit.test(edit, state)
      assert state.env["p"]["t1"]["pre"] == 7
    end

    test "at the first test a member whose value does not fit its type starts again " <>
           "(decision 26), by its path" do
      seal = block!(@seal)

      holder = fn decl, rungs ->
        block!(
          "function_block pulse\nvar_input go bool\nvar_output q bool\n#{decl}\n" <>
            "xic go ote q\n#{rungs}",
          [seal]
        )
      end

      with_dints =
        runs(
          holder.(
            "var n dint\nvar k dint\nvar s dint",
            "xic go move 7 n\nxic go move 3 k\nxic go move 2 s"
          )
        )

      with_kinds =
        runs(
          holder.(
            "var n bool\nvar k ton\nvar s seal\nvar r bool",
            "xic go otl n\nxic go ton k 40\ncal s go go r"
          )
        )

      {_, state} = running(with_dints, [{0, %{"a" => 1, "en" => 1}}])
      assert %{"n" => 7, "k" => 3, "s" => 2} = state.env["p"]

      # A plain swap keeps the 7, the 3 and the 2 under a bool, a timer and an instance of
      # a block its program declares, while no cal runs the body.
      {_, state} = step(with_kinds, state, %{"en" => 0})
      assert %{"n" => 7, "k" => 3, "s" => 2} = state.env["p"]

      {_edit, state, report} = Edit.test(accept!(with_kinds, with_kinds, state), state)
      timer = FbType.initial(FbType.ton(), %{"pre" => 40})
      held = FbType.initial(seal)

      assert report == [
               {:added, "p.k", timer},
               {:added, "p.n", 0},
               {:added, "p.r", 0},
               {:added, "p.s", held}
             ]

      assert %{"n" => 0, "k" => ^timer, "s" => ^held} = state.env["p"]
    end

    test "at the first test a member the candidate's version adds starts at its initial " <>
           "value over what a plain swap left, by its path" do
      with_c = runs(pulse("xic go move 9 c", "var c dint"))
      without = runs(pulse())
      added = runs(pulse("xic go move 3 c", "var c dint 7"))
      {_, state} = running(with_c, [{0, %{"a" => 1, "en" => 1}}])

      # A plain swap to a version that declares no `c` keeps the 9 under it.
      {_, state} = step(without, state, %{})
      assert state.env["p"]["c"] == 9

      {edit, state, report} = Edit.test(accept!(without, added, state), state)
      assert report == [{:added, "p.c", 7}]
      assert state.env["p"]["c"] == 7

      # A later test keeps it, as logic left it.
      {_, state} = step(added, state, %{})
      {edit, state, []} = Edit.untest(edit, state)
      assert {_edit, %Instance{env: %{"p" => %{"c" => 3}}}, []} = Edit.test(edit, state)
    end

    test "an ons inside a block whose body also writes its storage bit another way is " <>
           "blocked, though its chain is unchanged (fix F7, by path)" do
      pulse = block!(@pulse <> "xio go otu edge\n")
      v1 = runs(pulse)

      v2 =
        program!(String.replace(@runs_pulse, "var p pulse", "var p pulse\nvar k bool"), [pulse])

      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {10, %{}}])
      assert state.env["p"]["edge"] == 1

      {_edit, _state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "k", 0}, {:ons_blocked, "p.edge", 1}]

      # Written by its ons alone, the same bit is not blocked.
      v1 = runs(block!(@pulse))

      v2 =
        program!(String.replace(@runs_pulse, "var p pulse", "var p pulse\nvar k bool"), [
          block!(@pulse)
        ])

      {_, state} = running(v1, [{0, %{"a" => 1, "en" => 1}}, {10, %{}}])
      assert {_edit, _state, [{:added, "k", 0}]} = Edit.test(accept!(v1, v2, state), state)
    end

    test "an output only a cal drove is held where the candidate drives it no more" do
      seal = block!(@seal)
      v1 = program!("var_input a bool\nvar_output q bool\nvar s1 seal\ncal s1 a 0 q", [seal])

      v2 =
        program!("var_input a bool\nvar_output q bool\nvar s1 seal\nvar k bool\ncal s1 a 0 k", [
          seal
        ])

      {_, state} = running(v1, [{0, %{"a" => 1}}])
      assert {:ok, _edit, [{:added, "k", 0}, {:held, "q", 1}]} = Edit.accept(v1, v2, state)
    end
  end

  describe "an online edit, at depth and across a round trip" do
    # One scan at an absolute time, `now`, so a test can freeze a block and come back to it.
    defp at(program, state, now, inputs \\ %{}),
      do: Runtime.call(program, state, inputs, %Scan{now: now, first: state.first})

    @blk_timed """
    function_block blk
    var_input go bool
    var_output p bool
    var t1 ton
    xic go ton t1 50
    xic t1.dn ote p
    """

    @blk_plain """
    function_block blk
    var_input go bool
    var_output p bool
    xic go ote p
    """

    @runs_blk "var_input en bool\nvar_input g bool\nvar_output p bool\nvar x blk\nxic en cal x g p\n"

    @pulse_go """
    function_block pulse
    var_input go bool
    var_output fired bool
    var edge bool
    xic go ons edge ote fired
    """

    defp wrap(pulse),
      do:
        block!(
          "function_block wrap\nvar_input go bool\nvar_output q bool\nvar p pulse\ncal p go q",
          [pulse]
        )

    test "a test and an untest with no scan between leave a timer a false EN froze as it " <>
           "was: the program that last scanned ran it, so no resume is due" do
      timed = program!(@runs_blk, [block!(@blk_timed)])
      plain = program!(@runs_blk, [block!(@blk_plain)])
      {_, state} = at(timed, Runtime.instance(timed), 0, %{"en" => 1, "g" => 1})
      {_, state} = at(timed, state, 10)
      {_, state} = at(timed, state, 20, %{"en" => 0})
      {_, state} = at(timed, state, 30)
      assert %{"acc" => 10, "en" => 1, "last" => 10} = state.env["x"]["t1"]

      {edit, tested, report} = Edit.test(accept!(timed, plain, state), state)
      assert report == []
      {_edit, untested, report} = Edit.untest(edit, tested)
      assert report == []
      assert untested.env["x"]["t1"] == state.env["x"]["t1"]

      # Its EN back, it catches up as if no edit had been made (decision 8).
      {_, untested} = at(timed, untested, 40, %{"en" => 1})
      {_, unedited} = at(timed, state, 40, %{"en" => 1})
      assert %{"acc" => 40} = untested.env["x"]["t1"]
      assert untested.env["x"]["t1"] == unedited.env["x"]["t1"]
    end

    test "an untest gives back a resume its test made of a timer only the candidate's " <>
           "version of a block declares (fix F11, by path)" do
      timed = program!(@runs_blk, [block!(@blk_timed)])
      plain = program!(@runs_blk, [block!(@blk_plain)])
      {_, state} = at(plain, Runtime.instance(plain), 0, %{"en" => 1, "g" => 1})
      edit = accept!(plain, timed, state)
      {edit, state, _} = Edit.test(edit, state)
      {_, state} = at(timed, state, 10)
      {edit, state, []} = Edit.untest(edit, state)
      {_, state} = at(plain, state, 40)
      assert %{"en" => 1, "last" => 10} = state.env["x"]["t1"]

      {edit, state, report} = Edit.test(edit, state)
      assert report == [{:resumed, "x.t1", 30}]
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:resume_undone, "x.t1", 30}]
      assert state.env["x"]["t1"]["last"] == 10
    end

    test "an untest gives back a resume its test made inside an instance only the candidate " <>
           "declares (fix F11, by path)" do
      timed = block!(@blk_timed)
      head = "var_input en bool\nvar_input g bool\nvar_output p bool\n"
      plain = program!(head <> "xic g ote p", [timed])
      added = program!(head <> "var y blk\ncal y g p", [timed])
      {_, state} = at(plain, Runtime.instance(plain), 0, %{"g" => 1})
      edit = accept!(plain, added, state)
      {edit, state, _} = Edit.test(edit, state)
      {_, state} = at(added, state, 10)
      {edit, state, []} = Edit.untest(edit, state)
      {_, state} = at(plain, state, 40)
      assert %{"en" => 1, "last" => 10} = state.env["y"]["t1"]

      {edit, state, report} = Edit.test(edit, state)
      assert report == [{:resumed, "y.t1", 30}]
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:resume_undone, "y.t1", 30}]
      assert state.env["y"]["t1"]["last"] == 10
    end

    test "a blocked bit inside an instance is reported with its value, by its path" do
      pulse = block!(@pulse_go)
      src = "var_input go bool\nvar_input en bool\nvar_output fired bool\nvar p pulse\n"
      a = program!(src <> "cal p go fired", [pulse])
      b = program!(src <> "xic en cal p go fired", [pulse])
      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1, "en" => 1})
      assert state.env["p"]["edge"] == 1
      {_edit, _state, report} = Edit.test(accept!(a, b, state), state)
      assert report == [{:ons_blocked, "p.edge", 1}]
    end

    test "an instance of a block that holds a block, added with its cal, blocks the one-shot " <>
           "two levels down for the switch scan (decision 21)" do
      wrap = wrap(block!(@pulse_go))
      a = program!("var_input go bool\nvar_output q bool\nvar w1 wrap\nxic go ote q", [wrap])
      b = program!("var_input go bool\nvar_output q bool\nvar w1 wrap\ncal w1 go q", [wrap])
      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1})
      {_, state} = at(a, state, 20)
      {edit, state, report} = Edit.test(accept!(a, b, state), state)
      assert report == [{:ons_blocked, "w1.p.edge", 0}]
      {outputs, _state} = at(Edit.running(edit), state, 30)
      assert outputs == %{"q" => 0}
    end

    test "at the first test an instance a plain swap left as no map starts again whole " <>
           "(decision 26)" do
      seal = block!(@seal)

      a =
        program!(
          "var_input go bool\nvar_output q bool\nvar z bool\nxic go ote z\nxic z ote q",
          []
        )

      b = program!("var_input go bool\nvar_output q bool\nvar z seal\nxic go ote q", [seal])

      c =
        program!(
          "var_input go bool\nvar_input st bool\nvar_output q bool\nvar z seal\ncal z go st q",
          [seal]
        )

      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1})
      {_, state} = at(b, state, 20)
      assert state.env["z"] == 1
      {_edit, state, report} = Edit.test(accept!(b, c, state), state)
      assert report == [{:added, "z", FbType.initial(seal)}, {:input, "st", 0}]
      assert state.env["z"] == FbType.initial(seal)
    end

    test "assemble prunes a member at any depth, inside an instance an instance holds" do
      old_pulse =
        block!(String.replace(@pulse_go, "var edge bool", "var edge bool\nvar old dint 4"))

      src = "var_input go bool\nvar_output q bool\nvar w1 wrap\ncal w1 go q"
      a = program!(src, [wrap(old_pulse)])
      b = program!(src, [wrap(block!(@pulse_go))])
      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1})
      {edit, state, _} = Edit.test(accept!(a, b, state), state)
      assert state.env["w1"]["p"]["old"] == 4
      {_program, state, report} = Edit.assemble(edit, state)
      assert report == [{:pruned, "w1.p.old", 4}]
      refute is_map_key(state.env["w1"]["p"], "old")
    end

    # A state built by hand is outside the contract (Logex.Instance): a switch and a prune
    # of one that holds no map where an instance goes, at the top or inside one, and one
    # whose block list names a bit under such a value, raise nothing.
    test "a state built by hand with no map where an instance goes takes every step: " <>
           "nothing escapes" do
      old_pulse =
        block!(String.replace(@pulse_go, "var edge bool", "var edge bool\nvar old dint 4"))

      a =
        program!("var_input go bool\nvar_output q bool\nvar w1 wrap\ncal w1 go q", [
          wrap(old_pulse)
        ])

      b =
        program!(
          "var_input go bool\nvar_output q bool\nvar k bool\nvar w1 wrap\ncal w1 go q",
          [wrap(block!(@pulse_go))]
        )

      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1})
      {edit, tested, _report} = Edit.test(accept!(a, b, state), state)

      for hand <- [
            %{tested | env: put_in(tested.env, ["w1", "p"], 5)},
            %{tested | env: Map.put(tested.env, "w1", 5)},
            %{
              tested
              | env: put_in(tested.env, ["w1", "p"], 5),
                switched: false,
                ons_blocked: ["w1.p.edge"]
            }
          ] do
        {edit, untested, _report} = Edit.untest(edit, hand)
        {edit, retested, _report} = Edit.test(edit, untested)
        assert {^b, %Instance{}, _report} = Edit.assemble(edit, retested)
      end
    end

    test "a timer whose cal a block's body drops and a later edit restores resumes from the " <>
           "switch, by its path (decision 23)" do
      delay =
        block!(
          "function_block delay\nvar_input go bool\nvar_output done bool\nvar t1 ton\n" <>
            "xic go ton t1 50\nxic t1.dn ote done"
        )

      pair = fn rungs ->
        block!(
          "function_block pair\nvar_input go bool\nvar_output q bool\nvar_output r bool\n" <>
            "var db delay\n#{rungs}",
          [delay]
        )
      end

      src = "var_input go bool\nvar_output q bool\nvar_output r bool\nvar w pair\ncal w go q r"
      runs = program!(src, [pair.("xic go ote q\ncal db go r")])
      drops = program!(src, [pair.("xic go ote q\nxic go ote r")])
      {_, state} = at(runs, Runtime.instance(runs), 10, %{"go" => 1})
      {_, state} = at(runs, state, 20)
      {edit, state, _report} = Edit.test(accept!(runs, drops, state), state)
      {^drops, state, _report} = Edit.assemble(edit, state)
      {_, state} = at(drops, state, 50)
      assert %{"acc" => 10, "en" => 1, "last" => 20} = state.env["w"]["db"]["t1"]

      # The body that drops the cal ran the timer no more: it resumes, and is not caught up.
      {edit, state, report} = Edit.test(accept!(drops, runs, state), state)
      assert report == [{:resumed, "w.db.t1", 30}]
      {_, state} = at(Edit.running(edit), state, 60)
      assert state.env["w"]["db"]["t1"]["acc"] == 20
    end

    test "a timer in an instance no cal runs keeps its .pre frozen, beside one of the same " <>
           "block that a cal runs, in a program or in a block's body (decision 23)" do
      delay = fn preset ->
        block!(
          "function_block delay\nvar_input go bool\nvar_output done bool\nvar t1 ton\n" <>
            "xic go ton t1 #{preset}\nxic t1.dn ote done"
        )
      end

      pair = fn delay ->
        block!(
          "function_block pair\nvar_input go bool\nvar_output q bool\nvar da delay\n" <>
            "var db delay\ncal da go q",
          [delay]
        )
      end

      src =
        "var_input go bool\nvar_output q bool\nvar_output r bool\nvar da delay\nvar db delay\n" <>
          "var w pair\ncal da go q\ncal w go r"

      a = program!(src, [delay.(30), pair.(delay.(30))])
      b = program!(src, [delay.(50), pair.(delay.(50))])
      {_, state} = at(a, Runtime.instance(a), 10, %{"go" => 1})
      {_edit, state, report} = Edit.test(accept!(a, b, state), state)
      assert report == [{:preset, "da.t1", {30, 50}}, {:preset, "w.da.t1", {30, 50}}]
      assert {state.env["da"]["t1"]["pre"], state.env["db"]["t1"]["pre"]} == {50, 30}
      assert {state.env["w"]["da"]["t1"]["pre"], state.env["w"]["db"]["t1"]["pre"]} == {50, 30}
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

  # Decision 34: compile_file/1 loads `<word>.ld` beside the file that names a type word,
  # compiling each once a call, and hands back each loaded block's warnings among the
  # program's; compile/2 gives only the program's.
  describe "a block's file found beside the file that names it (decision 34)" do
    @describetag :tmp_dir

    defp write!(dir, name, source) do
      path = Path.join(dir, name)
      File.write!(path, source)
      path
    end

    defp formatted({:error, diagnostics}), do: Enum.map(diagnostics, &Diagnostic.format/1)

    # `seal` with a `var` no rung uses, `outer` holding one, each warned of in its file.
    @warned_seal String.replace(
                   @seal,
                   "var_output run bool\n",
                   "var_output run bool\nvar n bool\n"
                 )

    @outer """
    function_block outer
    var_input go bool
    var_output o bool
    var spare dint
    var s seal

    cal s go go o
    """

    @holds_both """
    var_input a bool
    var_output k bool
    var_output k2 bool
    var unused bool
    var o outer
    var s seal

    cal o a k
    cal s a a k2
    """

    # Its first rung read as the compiler reads it, in any case.
    test "compile_file/1 compiles it first, and the program holds its type and runs it",
         %{tmp_dir: dir} do
      seal = write!(dir, "seal.ld", String.replace(@seal, "function_block", "Function_Block"))
      path = write!(dir, "motor.ld", @three)
      assert {:ok, motor} = Logex.compile_file(path)
      assert {:ok, type} = Logex.compile_file(seal)
      assert motor.tags["s1"].type == {:block, "seal"} and motor.blocks == %{"seal" => type}
      assert type.body.file == seal
      assert motor.file == path

      {outputs, _} = step(motor, Runtime.instance(motor), %{"a2" => 1})
      assert outputs == %{"k1" => 0, "k2" => 1, "k3" => 0, "lamp" => 1}
    end

    test "each block's warnings are handed back among the program's, once a call, each " <>
           "with its block's file, a block after those it holds",
         %{tmp_dir: dir} do
      seal = write!(dir, "seal.ld", @warned_seal)
      outer = write!(dir, "outer.ld", @outer)
      path = write!(dir, "motor.ld", @holds_both)

      assert {:ok, motor} = Logex.compile_file(path)

      assert warnings(motor) == [
               "#{path}: line 4: warning: `unused` is declared but no rung uses it",
               "#{seal}: line 5: warning: `n` is declared but no rung uses it",
               "#{outer}: line 4: warning: `spare` is declared but no rung uses it"
             ]

      # One version of `seal`, compiled once, whichever file names it: the program's one
      # table holds it, and both its own instance's tag and the one in `outer`'s body name
      # it (decision 53).
      assert Map.keys(motor.blocks) == ["outer", "seal"]
      assert motor.blocks["outer"].body.tags["s"].type == {:block, "seal"}

      assert motor.tags["o"].type == {:block, "outer"} and
               motor.tags["s"].type == {:block, "seal"}

      assert motor.blocks["outer"].body.blocks == %{} and motor.blocks["seal"].body.file == seal
    end

    test "compile/2 gives only the program's warnings, and a block's file only its own",
         %{tmp_dir: dir} do
      write!(dir, "seal.ld", @warned_seal)
      outer = write!(dir, "outer.ld", @outer)
      {:ok, outer_type} = Logex.compile_file(outer)

      assert warnings(outer_type.body) == [
               "#{outer}: line 4: warning: `spare` is declared but no rung uses it"
             ]

      # The block's own type keeps its warnings, and is one a compile gives.
      assert FbType.user?(outer_type)
      seal_type = outer_type.body.blocks["seal"]

      assert [%Diagnostic{message: "`n` is declared but no rung uses it"}] =
               seal_type.body.warnings

      motor = program!(@holds_both, [outer_type, seal_type])

      assert warnings(motor) == [
               "line 4: warning: `unused` is declared but no rung uses it"
             ]
    end

    test "a mistake in it is reported with its file, once, and stops the file that names it",
         %{tmp_dir: dir} do
      seal = write!(dir, "seal.ld", String.replace(@seal, "xio stop", "xio stp"))
      path = write!(dir, "motor.ld", @three)

      assert formatted(Logex.compile_file(path)) == [
               "#{seal}: line 6: `stp` is not declared — did you mean `stop`?"
             ]

      # Named by the program and by a block it holds: the block's mistake once, and the
      # program's own mistakes not at all, since it is compiled no further.
      write!(dir, "outer.ld", @outer)
      both = write!(dir, "both.ld", @holds_both <> "xyz a\n")

      assert formatted(Logex.compile_file(both)) == [
               "#{seal}: line 6: `stp` is not declared — did you mean `stop`?"
             ]

      # Two broken blocks: every mistake, each block's in line order, the blocks in the
      # order the file names them.
      write!(
        dir,
        "latch.ld",
        "function_block latch\nvar_input a bool\nvar q bool\nxyz a\nxic b ote q\n"
      )

      two = write!(dir, "two.ld", "var l latch\nvar s seal\nvar_input a bool\ncal l a\n")

      assert formatted(Logex.compile_file(two)) == [
               "#{dir}/latch.ld: line 4: unknown instruction `xyz`",
               "#{dir}/latch.ld: line 5: `b` is not declared",
               "#{seal}: line 6: `stp` is not declared — did you mean `stop`?"
             ]

      # A block's file that does not lex is loaded, to be reported, with its column.
      write!(dir, "seal.ld", String.replace(@seal, "ote run", "ote $run"))

      assert formatted(Logex.compile_file(path)) == [
               ~s(#{seal}: line 6, column 38: illegal character "$")
             ]

      # Something of that name that is no file is reported as one that cannot be read.
      File.rm!(seal)
      File.mkdir!(seal)

      assert formatted(Logex.compile_file(path)) == [
               "#{seal}: cannot be read: illegal operation on a directory"
             ]
    end

    # A loader that missed the chain would recurse until the default minute ran out,
    # gigabytes later: a chain is found in a few milliseconds.
    @tag timeout: 10_000
    test "a chain of files that holds itself is located in the file that closes it",
         %{tmp_dir: dir} do
      write!(dir, "a.ld", "function_block a\nvar_output q bool\nvar x b\ncal x q\n")
      b = write!(dir, "b.ld", "function_block b\nvar_input go bool\nvar y a\ncal y go\n")

      assert formatted(Logex.compile_file(Path.join(dir, "a.ld"))) == [
               "#{b}: line 3: `b` cannot hold an instance of `a` (b → a → b): " <>
                 "a function block never holds an instance of itself, at any depth"
             ]

      c = write!(dir, "c.ld", "function_block c\nvar_input go bool\nvar z a\ncal z go\n")
      write!(dir, "b.ld", "function_block b\nvar_input go bool\nvar y c\ncal y go\n")

      assert formatted(Logex.compile_file(Path.join(dir, "a.ld"))) == [
               "#{c}: line 3: `c` cannot hold an instance of `a` (c → a → b → c): " <>
                 "a function block never holds an instance of itself, at any depth"
             ]
    end

    test "a program's file is no type, before any chain is looked for", %{tmp_dir: dir} do
      write!(dir, "pump.ld", "var_output q bool\nxic q ote q\n")
      path = write!(dir, "m.ld", "var p pump\nvar_output q bool\nxic q ote q\n")

      assert formatted(Logex.compile_file(path)) == [
               "#{path}: line 1: `pump` is a program (pump.ld), not a function block: " <>
                 "only a function block's file gives a type for `var`"
             ]

      # A block that names a program which holds the block: the block's own line, not a
      # chain reported in the program's file.
      blk =
        write!(
          dir,
          "blk.ld",
          "function_block blk\nvar_input a bool\nvar_output q bool\n" <>
            "var p prog\ncal p a q\n"
        )

      prog = write!(dir, "prog.ld", "var_input a bool\nvar_output q bool\nvar b blk\ncal b a q\n")

      message =
        "line 4: `prog` is a program (prog.ld), not a function block: " <>
          "only a function block's file gives a type for `var`"

      assert formatted(Logex.compile_file(blk)) == ["#{blk}: #{message}"]
      assert formatted(Logex.compile_file(prog)) == ["#{blk}: #{message}"]
    end

    # Only a word a block's first rung could give is looked for: a dotted word, or the word
    # that heads a block's file, is an unknown type where it is written, whatever is beside.
    test "a word no block can be named is looked for in no file", %{tmp_dir: dir} do
      write!(dir, "a.b.ld", @seal)
      dotted = write!(dir, "dotted.ld", "var s a.b\nvar_output q bool\nxic q ote q\n")

      assert formatted(Logex.compile_file(dotted)) == [
               "#{dotted}: line 1: unknown type `a.b`: logex has `bool`, `dint` and `ton`"
             ]

      write!(dir, "Function_Block.ld", "function_block Function_Block\nvar_input a bool\n")
      header = write!(dir, "header.ld", "var s Function_Block\nvar_output q bool\nxic q ote q\n")

      assert formatted(Logex.compile_file(header)) == [
               "#{header}: line 1: unknown type `Function_Block`: logex has `bool`, `dint` " <>
                 "and `ton`"
             ]
    end

    # Looked for as written: a block whose name has capitals is in a file of that name.
    test "a type word is looked for as `<word>.ld`, in its own case", %{tmp_dir: dir} do
      write!(dir, "Seal.ld", String.replace(@seal, "function_block seal", "function_block Seal"))
      path = write!(dir, "m.ld", String.replace(@three, " seal\n", " Seal\n"))
      assert {:ok, %Logex.Program{} = program} = Logex.compile_file(path)
      assert program.tags["s1"].type == {:block, "Seal"} and program.blocks["Seal"].name == "Seal"
    end

    # Any section line's type word is looked for, so an instance declared in the wrong
    # section is told what compile/2 with `types:` tells it, not that its type is unknown.
    test "a section line of any kind finds its block beside it", %{tmp_dir: dir} do
      write!(dir, "seal.ld", @seal)

      for section <- ["var_input", "var_output"] do
        path = write!(dir, "in_#{section}.ld", "var_input a bool\n#{section} s1 seal\n")

        assert formatted(Logex.compile_file(path)) == [
                 "#{path}: line 2: `s1` is an instance of `seal`: an instance is the " <>
                   "program's own, declared with `var`, as in `var s1 seal`, not with " <>
                   "`#{section}`"
               ]
      end
    end

    # A file whose name cannot name a program is still compiled with the blocks beside it,
    # so the one mistake is its name: a block it names is no unknown type.
    test "a file with a refused name finds its blocks beside it all the same",
         %{tmp_dir: dir} do
      write!(dir, "seal.ld", @seal)
      path = write!(dir, "1motor.ld", @three)

      assert formatted(Logex.compile_file(path)) == [
               "#{path}: \"1motor\" cannot name a program: a name is a letter or `_`, then " <>
                 "letters, digits or `_` (rename the file)"
             ]

      broken =
        write!(dir, "2motor.ld", String.replace(@three, "cal s2 a2 stop k2", "cal s2 a2 k2"))

      assert formatted(Logex.compile_file(broken)) == [
               "#{broken}: \"2motor\" cannot name a program: a name is a letter or `_`, then " <>
                 "letters, digits or `_` (rename the file)",
               "#{broken}: line 15: `cal s2` expects 3 operands after its instance, " <>
                 "`start` (var_input bool), then `stop` (var_input bool), then `run` " <>
                 "(var_output bool): found 2"
             ]
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

  # A block's compiled body is a %Logex.Program{} named after the block (docs/organisation.md
  # §4.10), which the runtime, a configuration and an edit take as they take any program.
  # Each instance its body declares names a type its one table, `blocks`, holds, and every
  # reader of its tag table there reads that type, as a compile does
  # (Logex.Program.typed_tags/1).
  describe "a block's compiled body, run as a program" do
    @timed_seal """
    function_block seal
    var_input start bool
    var_output run bool
    var_output n dint 3
    var t ton

    xic start ton t 100
    xic t.dn ote run
    """

    @pair """
    function_block pair
    var_input a bool
    var_output r bool
    var_output m dint
    var s seal
    var x bool

    cal s a x m
    xic x ote r
    """

    defp pair(source \\ @pair, seal \\ @timed_seal), do: block!(source, [block!(seal)]).body

    test "starts each instance it holds as its type says, and runs it" do
      body = pair()
      assert body.tags["s"].type == {:block, "seal"}
      in_a_program = program!("var s seal", [block!(@timed_seal)])
      state = Runtime.instance(body)
      assert state.env["s"] == Runtime.instance(in_a_program).env["s"]
      assert state.env["s"]["n"] == 3 and state.env["s"]["t"]["pre"] == 100

      # The timer's preset is the 100 its `ton` gives it: done 100 ms after `a` rises.
      {outputs, state} = drive(body, state, [{0, %{"a" => 0}}, {50, %{"a" => 1}}, {60, %{}}])
      assert outputs == %{"m" => 3, "r" => 0} and state.env["s"]["t"]["acc"] == 60
      assert {%{"m" => 3, "r" => 1}, _} = step(body, state, %{}, 50)
    end

    test "a key inside an instance it holds is told what it names" do
      body = pair()

      raises(
        "input `s.run` names a member of `s`, an instance of `seal`: only a var_input is set " <>
          "from outside",
        fn -> Runtime.put_inputs(body, Runtime.instance(body), %{"s.run" => 1}) end
      )
    end

    test "a configuration reads the instances it holds by path" do
      body = pair()

      config =
        Configuration.new!(
          name: "plant",
          programs: [body],
          globals: [],
          instances: [%Configuration.Instance{name: "m1", type: "pair"}],
          connections: [%Configuration.Connection{instance: "m1", member: "a", to: 1}]
        )

      {rt, _outputs, _events} = Runtime.cycle(Runtime.start(config), 10, %{})
      assert Runtime.get(rt, "m1.s.run") == {:ok, 0}
      assert Runtime.get!(rt, "m1.s.n") == 3

      assert Runtime.get(rt, "m1.s") ==
               {:error,
                "`m1.s` is an instance of `seal`: an access path names one of its members, " <>
                  "as in `m1.s.run`"}
    end

    test "an edit takes it, each instance it holds moving whole" do
      body = pair()
      state = Runtime.instance(body)
      added = pair(String.replace(@pair, "var x bool\n", "var x bool\nvar k dint 4\n"))
      assert {:ok, edit, [{:added, "k", 4}]} = Edit.accept(body, added, state)
      {_edit, tested, _report} = Edit.test(edit, state)
      assert tested.env["k"] == 4 and tested.env["s"] == state.env["s"]
    end

    test "an edit refuses a change of a held instance's member kind, by its path" do
      body = pair()
      state = Runtime.instance(body)

      retyped =
        pair(
          String.replace(@pair, "var x bool\n", "var x bool\nvar y bool\n")
          |> String.replace("cal s a x m", "cal s a x y"),
          String.replace(@timed_seal, "var_output n dint 3", "var_output n bool")
        )

      assert {:error, [diagnostic]} = Edit.accept(body, retyped, state)

      assert Diagnostic.format(diagnostic) ==
               "line 5: `s.n` is a dint in the running program and a bool in the candidate: " <>
                 "a member's type changes only with a restart"
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

    # Decision 53: a type holds every type below it in one table, which a compile's
    # one-version check walks once, however many instances hold the type, so the cost of
    # each instance does not grow with the types its type holds. 255 more instances of a
    # chain 200 deep cost 1.00x what 255 more of one 50 deep cost, in each of 25 runs of the
    # suite; with the table walked again for each instance, 1.74x. The bound is a fifth
    # above.
    test "a compile walks a type's table once, however many instances hold it" do
      extra = fn depth ->
        top = chain(depth)

        compile = fn n ->
          source =
            "var_input a bool\nvar_output y bool\n" <>
              Enum.map_join(1..n, "\n", &"var p#{&1} b1") <>
              "\n" <> Enum.map_join(1..n, "\n", &"cal p#{&1} a y")

          reductions(fn -> {:ok, _} = Logex.compile(source, name: "m", types: [top]) end)
        end

        compile.(256) - compile.(1)
      end

      ratio = extra.(200) / extra.(50)

      assert ratio < 1.21,
             "255 more instances took #{Float.round(ratio, 2)}x the reductions at 4x the depth"
    end

    # So too for instances declared from Elixir, through instructionize/3: a type is
    # checked once a compile, the first tag that holds it checking it and the rest known
    # by being that one, and a type given is known by being the one given, as a
    # declaration line's is. 16 instances cost 1.04 times one, and one declared from Elixir
    # 1.0 times one declared by a line; checked again for each, 15.5 times, and for the one
    # given, 2.0 times.
    test "a compile checks a type held by instances declared from Elixir once" do
      top = chain(200)

      declared = fn n, types ->
        routine =
          ast(
            "var_input a bool\nvar_output y bool\n" <>
              Enum.map_join(1..n, "\n", &"cal p#{&1} a y")
          )

        tags = for k <- 1..n, do: Tag.new!("p#{k}", top)
        reductions(fn -> {:ok, _} = Logex.Compiler.instructionize(routine, tags, types) end)
      end

      ratio = declared.(16, []) / declared.(1, [])
      assert ratio < 3, "16 instances took #{Float.round(ratio, 1)}x the reductions of one"

      line = ast("var_input a bool\nvar_output y bool\nvar p1 b1\ncal p1 a y")

      ratio =
        declared.(1, [top]) /
          reductions(fn -> {:ok, _} = Logex.Compiler.instructionize(line, [], [top]) end)

      assert ratio < 1.5,
             "an instance from Elixir took #{Float.round(ratio, 1)}x the reductions of a line's"
    end
  end

  describe "growth in the paths to a type" do
    # A diamond `depth` levels deep: two types at each level, `l<k>` and `r<k>`, each
    # holding one instance of each of the two below and running both, so a type k levels
    # down is reached through 2^k paths, though each body holds each type it names once.
    defp diamond(depth) do
      leaf = fn side ->
        block!("function_block #{side}0\nvar_input a bool\nvar_output q bool\nxic a ote q")
      end

      {top, _right} =
        Enum.reduce(1..depth, {leaf.("l"), leaf.("r")}, fn k, {l, r} ->
          level = fn side ->
            block!(
              "function_block #{side}#{k}\nvar_input a bool\nvar_output q bool\n" <>
                "var u l#{k - 1}\nvar v r#{k - 1}\nvar x bool\ncal u a x\ncal v x q",
              [l, r]
            )
          end

          {level.("l"), level.("r")}
        end)

      top
    end

    # Logex.FbType.user?/1 checks each type once a call, however many paths reach it, since
    # the one table holds it once (decision 53), so it, and a compile given the type, stay
    # linear in the types. At 6 and 12 levels, twice the depth took 2.01x and 1.94x the
    # reductions in each of 25 runs of the suite; since decision 54, which compiles each
    # type's text again, 2.00x and 1.96x. Each bound is a fifth above.
    test "a type reached through many paths is checked once" do
      measured =
        for d <- [6, 12], into: %{} do
          type = diamond(d)
          source = "var_input a bool\nvar_output y bool\nvar p l#{d}\ncal p a y"

          {d,
           {reductions(fn -> true = FbType.user?(type) end),
            reductions(fn -> {:ok, _} = Logex.compile(source, name: "m", types: [type]) end)}}
        end

      for {what, index, bound} <- [{"user?/1", 0, 2.41}, {"a compile given it", 1, 2.35}] do
        ratio = elem(measured[12], index) / elem(measured[6], index)

        assert ratio < bound,
               "twice the depth took #{Float.round(ratio, 2)}x the reductions for #{what}"
      end
    end

    # Decision 53: the outermost type holds each type below it once, in one table, so a
    # copy that keeps no sharing (a message to another process, term_to_binary/1) writes
    # each type out once, however many paths of holders reach it, and the type, and a
    # program given it, grow with the types they hold: 2(d + 1), 14 and 26 at 6 and 12
    # levels. Twice the depth took 2.01x the type's words, 2.00x its bytes, and 1.97x the
    # program's words and bytes, in each of 25 runs of the suite. Held once per body, each
    # type was written out once per path: twice the depth took 64.7x the words and 64.7x
    # the bytes, 2,354,805 words at 12 levels. Each bound is a fifth above.
    test "a type reached through many paths is held once: copied flat, it grows with its " <>
           "types" do
      measured =
        for d <- [6, 12], into: %{} do
          type = diamond(d)

          program =
            program!("var_input a bool\nvar_output y bool\nvar p l#{d}\ncal p a y", [type])

          {d,
           for(
             term <- [type, program],
             size <- [:erts_debug.flat_size(term), byte_size(:erlang.term_to_binary(term))],
             do: size
           )}
        end

      for {what, index, bound} <- [
            {"the type's words", 0, 2.41},
            {"the type's bytes", 1, 2.41},
            {"the program's words", 2, 2.37},
            {"the program's bytes", 3, 2.37}
          ] do
        ratio = Enum.at(measured[12], index) / Enum.at(measured[6], index)
        assert ratio < bound, "twice the depth took #{Float.round(ratio, 2)}x #{what}"
      end
    end
  end

  describe "growth in the types at a level" do
    # `w` types at one level, `t1` to `tw`, each holding one instance of the head of one
    # chain of 16 below them, `c1` to `c16`, which they all share; and `f`, holding one
    # instance of each of the `w`.
    defp shared_chain do
      deepest = block!("function_block c16\nvar_input a bool\nvar_output q bool\nxic a ote q")

      Enum.reduce(15..1//-1, deepest, fn k, inner ->
        block!(
          "function_block c#{k}\nvar_input a bool\nvar_output q bool\nvar inner c#{k + 1}\n" <>
            "cal inner a q",
          [inner]
        )
      end)
    end

    defp level(w, chain),
      do:
        for(
          i <- 1..w,
          do:
            block!(
              "function_block t#{i}\nvar_input a bool\nvar_output q bool\nvar inner c1\n" <>
                "cal inner a q",
              [chain]
            )
        )

    defp fan(w, level),
      do:
        block!(
          "function_block f\nvar_input a bool\nvar_output q bool\n" <>
            Enum.map_join(1..w, "", &"var i#{&1} t#{&1}\n") <>
            Enum.map_join(1..w, "", &"cal i#{&1} a q\n"),
          level
        )

    # Decision 53: one table holds the chain once, so `f`, copied flat, and a program given
    # the `w` types, grow with the distinct types, w + 16, and their own declarations, not
    # as w times the chain; a compile given `f` checks each type once, and so does a
    # compile given the `w` types, each type their tables share checked once
    # (Logex.FbType.check/2). At w = 4 and 16, 4x the width, 20 and 32 types below `f`,
    # `f` took 1.77x the words, the program 1.72x, a compile given `f` 1.78x the
    # reductions and one given the `w` types 2.41x, in each of 25 runs of the suite; since
    # decision 54, which compiles each type's text again, the two compiles took 1.75x and
    # 2.11x. Held once per body, each of the `w` held its own copy of the chain: `f` took
    # 3.97x the words, the program 3.98x, and the compile given the `w` types, each checked
    # whole, 3.97x the reductions. Each bound is a fifth above.
    test "types at a level that share the types below them: copied flat, and compiled, " <>
           "they grow with the distinct types" do
      chain = shared_chain()

      measured =
        for w <- [4, 16], into: %{} do
          level = level(w, chain)
          f = fan(w, level)

          given =
            "var_input a bool\nvar_output y bool\n" <>
              Enum.map_join(1..w, "", &"var p#{&1} t#{&1}\n") <>
              Enum.map_join(1..w, "", &"cal p#{&1} a y\n")

          one = "var_input a bool\nvar_output y bool\nvar p f\ncal p a y"

          {w,
           [
             :erts_debug.flat_size(f),
             :erts_debug.flat_size(program!(given, level)),
             reductions(fn -> {:ok, _} = Logex.compile(one, name: "m", types: [f]) end),
             reductions(fn -> {:ok, _} = Logex.compile(given, name: "m", types: level) end)
           ]}
        end

      for {what, index, bound} <- [
            {"the words of `f`", 0, 2.12},
            {"the words of a program given the types", 1, 2.07},
            {"the reductions of a compile given `f`", 2, 2.11},
            {"the reductions of a compile given the types", 3, 2.53}
          ] do
        ratio = Enum.at(measured[16], index) / Enum.at(measured[4], index)
        assert ratio < bound, "4x the width took #{Float.round(ratio, 2)}x #{what}"
      end
    end
  end

  describe "growth in a block's members" do
    # `wide`, a block of m var_inputs and m var_outputs, each output driven by its input
    # through `contact`.
    defp wide(m, contact) do
      block!(
        "function_block wide\n" <>
          Enum.map_join(1..m, "", &"var_input i#{&1} bool\n") <>
          Enum.map_join(1..m, "", &"var_output o#{&1} bool\n") <>
          Enum.map_join(1..m, "\n", &"#{contact} i#{&1} ote o#{&1}")
      )
    end

    # Each member a program names is found in a table of its type's members built once a
    # compile, so a compile reading every output of a block of m stays linear in m, and so
    # does a compile given a block whose body reads them, which checks that body again. At
    # 250 and 1,000 members, 4x, both took 4.0x; with each member found by a walk of the
    # type's members, 11.2x and 11.4x.
    test "a compile stays linear in the members a program reads" do
      reads = fn m, section ->
        Enum.map_join(1..m, "", &"#{section} x#{&1} bool\n") <>
          "var s wide\n" <> Enum.map_join(1..m, "\n", &"xic s.o#{&1} ote x#{&1}")
      end

      program = fn m ->
        type = wide(m, "xic")
        source = reads.(m, "var_output")
        reductions(fn -> {:ok, _} = Logex.compile(source, name: "m", types: [type]) end)
      end

      given = fn m ->
        outer =
          block!(
            "function_block outer\nvar_input go bool\n" <> reads.(m, "var"),
            [wide(m, "xic")]
          )

        source = "var_input a bool\nvar_output y bool\nvar k outer\ncal k a"

        reductions(fn -> {:ok, _} = Logex.compile(source, name: "m", types: [outer]) end)
      end

      for {what, fun} <- [program: program, given: given] do
        ratio = fun.(1000) / fun.(250)

        assert ratio < 6,
               "4x the members took #{Float.round(ratio, 1)}x the reductions for #{what}"
      end
    end

    # Accept matches the members of a block's two versions by name, through a table built
    # once per version, in the type check and in the plan. At 250 and 1,000 members, 4x,
    # accept took 4.0x; with each found by a walk of the other version's members, 11.6x
    # where the type check walked and 13.4x where the plan did.
    test "accept stays linear in a block's members" do
      accept = fn m ->
        head =
          Enum.map_join(1..m, "", &"var_input a#{&1} bool\n") <>
            Enum.map_join(1..m, "", &"var_output q#{&1} bool\n") <>
            "var s wide\ncal s " <>
            Enum.map_join(1..m, " ", &"a#{&1}") <> " " <> Enum.map_join(1..m, " ", &"q#{&1}")

        v1 = program!(head, [wide(m, "xic")])
        v2 = program!(head, [wide(m, "xio")])
        {_, state} = step(v1, Runtime.instance(v1), %{}, 0)
        reductions(fn -> {:ok, _, _} = Edit.accept(v1, v2, state) end)
      end

      ratio = accept.(1000) / accept.(250)
      assert ratio < 6, "4x the members took #{Float.round(ratio, 1)}x the reductions"
    end
  end

  describe "growth in a block's body" do
    # Accept reads each block type's body once, however many instances run it, so at 100
    # instances, 4x the rungs of the block's body cost little more: 50 and 200 rungs took
    # 1.12x the reductions in every run; with the body read again for each instance,
    # 3.34x. The bound is a fifth above.
    test "accept reads a block's body once, however many instances run it" do
      accept = fn r ->
        big =
          block!(
            "function_block big\nvar_input go bool\nvar_output q bool\nvar n dint\n" <>
              String.duplicate("xic go move 1 n\n", r) <> "xic go ote q"
          )

        head =
          "var_input a bool\nvar_output y bool\nvar_output z bool\n" <>
            Enum.map_join(1..100, "", &"var p#{&1} big\n") <>
            Enum.map_join(1..100, "\n", &"cal p#{&1} a y")

        v1 = program!(head, [big])
        v2 = program!(head <> "\nxic a ote z", [big])
        {_, state} = step(v1, Runtime.instance(v1), %{}, 0)
        reductions(fn -> {:ok, _, _} = Edit.accept(v1, v2, state) end)
      end

      ratio = accept.(200) / accept.(50)
      assert ratio < 1.35, "4x the body's rungs took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  describe "growth in a type's source text" do
    # Decision 54: a compile given a type compiles each type it holds again from its source
    # text, once, over the types it names as the one table holds them, and compares the
    # result with the body given, so it stays linear in the text and in the types: `wide`,
    # one block of n inputs and n outputs and a rung for each output, and a chain of n
    # types, each holding the next. At n = 50 and 200, 4x, a compile given `wide` took
    # 3.91x the reductions and one given the chain 3.92x, the highest of 25 runs of the
    # suite, every run alike: 70,113 and 275,398 given `wide`, 113,959 and 446,194 given the
    # chain, where before decision 54 they took 58,806 and 231,598, and 87,334 and 340,188.
    # Each bound is a fifth above.
    test "a compile given a type compiles each type's text again once: linear in the text " <>
           "and in the types" do
      measured =
        for n <- [50, 200], into: %{} do
          wide = wide(n, "xic")
          chain = chain(n)
          one = "var_input a bool\nvar_output y bool\nvar w wide\nxic a ote y"
          held = "var_input a bool\nvar_output y bool\nvar p b1\ncal p a y"

          {n,
           [
             reductions(fn -> {:ok, _} = Logex.compile(one, name: "m", types: [wide]) end),
             reductions(fn -> {:ok, _} = Logex.compile(held, name: "m", types: [chain]) end)
           ]}
        end

      for {what, index, bound} <- [
            {"a compile given `wide`", 0, 4.69},
            {"a compile given the chain", 1, 4.70}
          ] do
        ratio = Enum.at(measured[200], index) / Enum.at(measured[50], index)

        assert ratio < bound,
               "4x the size took #{Float.round(ratio, 2)}x the reductions for #{what}"
      end
    end
  end

  describe "growth in the size of a term" do
    # Each nested block type is held once, in the one table (decision 53), its member naming
    # it: held twice, as a member's type and a tag's, a copy that keeps no sharing (a message to
    # another process, term_to_binary/1, phash2/1) doubled at every level. At 6 and 12
    # levels, a program grows 1.7x in words copied flat; held twice, it grew 64x.
    test "a program copied flat stays linear in the depth of nesting" do
      flat = fn n -> :erts_debug.flat_size(program!(@top <> "xic a ote z", [chain(n)])) end
      ratio = flat.(12) / flat.(6)
      assert ratio < 2.5, "twice the depth took #{Float.round(ratio, 1)}x the words"
    end

    # A chain `depth` levels deep, each level holding `width` instances of the level below
    # and running each.
    defp fanned(width, depth),
      do:
        Enum.reduce(
          1..depth,
          block!("function_block w0\nvar_input a bool\nvar_output q bool\nxic a ote q"),
          fn k, below ->
            block!(
              "function_block w#{k}\nvar_input a bool\nvar_output q bool\n" <>
                Enum.map_join(1..width, "", &"var i#{&1} w#{k - 1}\nvar x#{&1} bool\n") <>
                Enum.map_join(1..width, "", &"cal i#{&1} a x#{&1}\n") <> "xic x1 ote q",
              [below]
            )
          end
        )

    # docs/organisation.md §4.10, "Held types", and decision 53: the outermost type holds
    # each block type below it once, in one table, each instance's tag naming it, so a type
    # copied flat grows with its width and its depth, not as the width to the power of the
    # depth (and "growth in the paths to a type" has two holders a level). At width 1 and 2 and depth 6 and 12, twice the depth took
    # 1.92x and 1.94x the words, at width 1 and 2, and twice the width 1.40x and 1.42x, at
    # depth 6 and 12; held in each instance's tag, twice the depth took 64.7x at width 2,
    # and twice the width 19.3x and 654x. A compile given the type checks each type once
    # (Logex.FbType.user?/1), and took 1.81x and 1.86x the reductions for twice the depth,
    # 1.36x and 1.40x for twice the width, as it did with the type held in each tag, whose
    # copies shared it; since decision 54, which compiles each type's text again, 1.82x and
    # 1.89x, and 1.35x and 1.40x. Each bound is a fifth above the highest of 25 runs of the
    # suite, every run alike.
    test "a type copied flat, and a compile given it, stay linear in the width and the depth" do
      measured =
        for w <- [1, 2], d <- [6, 12], into: %{} do
          type = fanned(w, d)
          source = "var_input a bool\nvar_output y bool\nvar p w#{d}\ncal p a y"
          compile = fn -> {:ok, _} = Logex.compile(source, name: "m", types: [type]) end
          {{w, d}, {:erts_debug.flat_size(type), reductions(compile)}}
        end

      for {what, index, depth_bound, width_bound} <- [
            {"words", 0, 2.33, 1.71},
            {"reductions of a compile", 1, 2.27, 1.68}
          ] do
        at = fn w, d -> elem(measured[{w, d}], index) end

        for w <- [1, 2] do
          ratio = at.(w, 12) / at.(w, 6)

          assert ratio < depth_bound,
                 "twice the depth took #{Float.round(ratio, 2)}x the #{what} at width #{w}"
        end

        for d <- [6, 12] do
          ratio = at.(2, d) / at.(1, d)

          assert ratio < width_bound,
                 "twice the width took #{Float.round(ratio, 2)}x the #{what} at depth #{d}"
        end
      end
    end

    # A one-shot at every level of a chain n deep, each blocked by an edit of the program's
    # `cal` rung, which is on every one's chain: n paths of up to n parts, so the block list
    # grows as the square of the depth, and so do the edit's reports and the keys its plan
    # compares (decision 32). The switch, accept and test, and the scan right after it stay
    # linear in the length of the list, its names' bytes: 4x the depth, 16x the bytes, about
    # 16x the reductions each. In the depth they are quadratic, as the list is; at the top
    # level, where a bit's name is one name, linear in the one-shots (edit_test.exs).
    defp blocked_chain(n) do
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

      head = "var_input a bool\nvar_input g bool\nvar_output y bool\nvar p c1\n"
      v1 = program!(head <> "cal p a y", [top])
      v2 = program!(head <> "xic g cal p a y", [top])
      {_, state} = step(v1, Runtime.instance(v1), %{"a" => 0, "g" => 1}, 0)

      switch = fn ->
        {:ok, edit, _forecast} = Edit.accept(v1, v2, state)
        Edit.test(edit, state)
      end

      {_edit, switched, report} = switch.()
      assert length(switched.ons_blocked) == n and length(report) == n
      bytes = switched.ons_blocked |> Enum.map(&byte_size/1) |> Enum.sum()
      switched = Runtime.put_inputs(v2, switched, %{"a" => 1})
      {{%{"y" => 0}, %Instance{ons_blocked: []}}, _} = {Runtime.scan(v2, switched, 10), nil}

      {bytes, reductions(switch), reductions(fn -> Runtime.scan(v2, switched, 10) end)}
    end

    test "a switch, and the scan after it, stay linear in the length of the block list" do
      {small, switch_s, scan_s} = blocked_chain(50)
      {large, switch_l, scan_l} = blocked_chain(200)
      bytes = large / small

      for {what, ratio} <- [switch: switch_l / switch_s, scan: scan_l / scan_s] do
        assert ratio < bytes * 1.3,
               "#{Float.round(bytes, 1)}x the bytes took #{Float.round(ratio, 1)}x for #{what}"
      end
    end
  end

  describe "growth in the instances" do
    # n instances of one block, each run by a rung of its own, and an edit of the block's
    # one-shot rung, which blocks the one-shot in every instance: the scan right after the
    # switch looks each bit up in a tree built once.
    defp pulses(n, condition, extra \\ "") do
      pulse =
        block!(
          "function_block pulse\nvar_input go bool\nvar_output q bool\nvar edge bool\n" <>
            "#{condition} ons edge ote q"
        )

      program!(
        "var_input a bool\nvar_output y bool\n#{extra}" <>
          Enum.map_join(1..n, "\n", &"var p#{&1} pulse") <>
          "\n" <> Enum.map_join(1..n, "\n", &"cal p#{&1} a y"),
        [pulse]
      )
    end

    defp blocked_scan(n) do
      v1 = pulses(n, "xic go")
      v2 = pulses(n, "xic go xic go")
      {_, state} = step(v1, Runtime.instance(v1), %{"a" => 0}, 0)
      {_edit, state, _report} = Edit.test(accept!(v1, v2, state), state)
      assert length(state.ons_blocked) == n
      state = Runtime.put_inputs(v2, state, %{"a" => 1})
      reductions(fn -> {%{"y" => 0}, _} = Runtime.scan(v2, state, 10) end)
    end

    # At 250 and 4,000 instances, 16x; the bound is the one the top-level test has, a
    # third above.
    test "the scan after a switch stays linear in the nested one-shots it blocks" do
      ratio = blocked_scan(4000) / blocked_scan(250)
      assert ratio < 24, "16x the one-shots took #{Float.round(ratio, 1)}x the reductions"
    end

    # The first edit changes every instance's one-shot rung and is kept with no scan after,
    # so its n blocks are still pending; the second changes only a rung no chain holds, so
    # only the pending path keeps the blocks (fix F2), each bit a path.
    defp reductions_to_second_edit(n) do
      v1 = pulses(n, "xic go")
      v2 = pulses(n, "xic go xic go")
      v3 = pulses(n, "xic go xic go", "var k bool\n")
      {_, state} = step(v1, Runtime.instance(v1), %{"a" => 0}, 0)
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {^v2, state, _} = Edit.assemble(edit, state)
      assert length(state.ons_blocked) == n

      reductions(fn ->
        {:ok, edit, _} = Edit.accept(v2, v3, state)
        {edit, s, report} = Edit.test(edit, state)
        {edit, s, _} = Edit.untest(edit, s)
        {edit, s, _} = Edit.test(edit, s)
        {_, _, _} = Edit.assemble(edit, s)
        assert for({:ons_blocked, bit, _} <- report, do: bit) == state.ons_blocked
      end)
    end

    # The top-level test's bound, at its sizes.
    test "a second edit before any scan stays linear in the nested bits still pending (F2)" do
      ratio = reductions_to_second_edit(4000) / reductions_to_second_edit(250)
      assert ratio < 24, "16x the pending bits took #{Float.round(ratio, 1)}x the reductions"
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
