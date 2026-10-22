defmodule Logex.PrinterTest do
  use ExUnit.Case, async: true

  alias Logex.Compiler
  alias Logex.Printer

  @corpus_size 200
  @seed {1, 2, 3}

  # Every production in Logex.Parser's grammar that a printed AST can exercise. The
  # round-trip properties below are only worth as much as the corpus they run on: a
  # generator that emits only what the printer already handles proves nothing but its
  # own consistency. `generates every shape the grammar can hold` fails if the
  # generator stops reaching one of these, so the properties cannot quietly narrow.
  @required_shapes MapSet.new([
                     # elem -> name
                     :name,
                     # elem -> int_lit
                     :int_lit,
                     # elem -> bst branches bnd
                     :group,
                     # branches -> branch nxb branches
                     :many_legs,
                     # branch -> '$empty'
                     :empty_leg,
                     # a group inside a leg
                     :nested,
                     # elems -> elem elems
                     :many_elems,
                     # rungs -> rung rnd rungs
                     :many_rungs,
                     # a name with `.` parts: a lexer rule, not a production, but printed
                     :dotted_name,
                     # a literal below 0, its sign glued to its digits (M3-3, decision 97):
                     # a lexer rule too, but printed
                     :negative_int_lit,
                     # M5-7 (decision 149): the spellings of a literal, lexer rules that the
                     # AST keeps no trace of, so reached by the spelled corpus below, each
                     # read back as the value it spells and printed in decimal
                     # `_` between decimal digits, `1_000`, signed too, `-1_000`
                     :separated_int_lit,
                     # `16#ff`, `16#FF`, `16#f_f`
                     :hex_int_lit,
                     # `2#1010_0000`
                     :binary_int_lit
                   ])

  describe "round trip" do
    test "generates every shape the grammar can hold" do
      spellings = for {_ast, _source, spelt} <- spelled_corpus(), shape <- spelt, do: shape

      assert @required_shapes ==
               corpus()
               |> Enum.map(&shapes/1)
               |> Enum.reduce(MapSet.new(spellings), &MapSet.union/2)
    end

    # M5-7 (decision 149): a literal may be written in decimal, with `_` between its digits,
    # or, at 0 or more, in base 16 or 2, and every spelling is the number it spells, so the
    # AST is the one its decimal spelling gives, and the printer gives that spelling back.
    test "every spelling of a literal reads back as the AST, and prints in decimal" do
      for {ast, source, _spelt} <- spelled_corpus() do
        assert strip_lines(parse!(source)) == strip_lines(ast), source
        assert Printer.print(parse!(source)) == Printer.print(ast)
      end
    end

    test "parse . print restores the AST, modulo line numbers" do
      for ast <- corpus() do
        assert strip_lines(parse!(Printer.print(ast))) == strip_lines(ast)
      end
    end

    test "print . parse reaches a fixed point" do
      for ast <- corpus() do
        once = Printer.print(ast)
        assert Printer.print(parse!(once)) == once
      end
    end

    test "a real program survives the trip and evaluates identically" do
      source = """
      var_input start bool
      var_input stop bool
      var_input overtemp bool
      var_output motor bool
      var_output run_lamp bool
      var fault bool
      var speed_sp dint 1200
      ( xic start | xic motor ) xio stop ote motor
      xic motor ote run_lamp
      xic overtemp otl fault
      xic fault move 0 speed_sp
      """

      env = %{"start" => 1, "stop" => 0, "overtemp" => 1}

      assert run(source, env) == run(Printer.print(parse!(source)), env)
      assert %{"motor" => 1, "run_lamp" => 1, "fault" => 1} = run(source, env)
    end
  end

  describe "canonical form" do
    # print/1 emits one spelling rather than reproducing the input. Every loss is pinned
    # here so that none can change without a test going red — in an editing box that
    # shows a rung back, every render rewrites what the user typed.
    test "runs of whitespace collapse to one space and a rung to one line" do
      assert Printer.print(parse!("  xic   aa \t   ote   bb   ")) == "xic aa ote bb"
    end

    test "integer literals print in their shortest form" do
      assert Printer.print(parse!("mov 007 hh")) == "mov 7 hh"
    end

    # M5-7 (decision 149): the AST keeps a literal's value, not its spelling, so a based
    # literal or one with `_` prints as its decimal value.
    test "a based literal or one with `_` separators prints as its decimal value" do
      assert Printer.print(parse!("move 16#00FF hh\nand 2#1010_0000 x\nmove -1_000_000 y")) ==
               "move 255 hh\nand 160 x\nmove -1000000 y"
    end

    # M3-3 (decision 97): a sign is glued to its digits, and `-0` is 0.
    test "a negative literal prints with its sign glued on, and `-0` as 0" do
      assert Printer.print(parse!("move -007 hh\neq -0 x")) == "move -7 hh\neq 0 x"
      assert Printer.print(parse!("( move -5 a | ) ote b")) == "( move -5 a | ) ote b"
    end

    test "a branch group prints with single spaces around every delimiter" do
      assert Printer.print(parse!("(  xic aa  |  ) ote xx")) == "( xic aa | ) ote xx"
    end

    # The parse AST has nowhere to keep a comment. PLAN.md §5 has one kept later, above a
    # rung; until then printing drops them.
    test "comments are dropped" do
      assert Printer.print(parse!("// seal-in\nxic aa ote bb // latch\nxic cc")) ==
               "xic aa ote bb\nxic cc"
    end
  end

  describe "shapes parse/1 cannot produce are refused, not mangled" do
    test "a tag may now be named after an old branch keyword" do
      # B1 turned the delimiters into punctuation, so `bst`, `nxb` and `bnd` are
      # ordinary names again and the printer is total over them. While they were
      # keywords this had to raise, or the printed text read back as structure.
      assert Printer.print(parse!("xic bst ote nxb")) == "xic bst ote nxb"
      assert %{"nxb" => 1} = run("var bst bool\nvar nxb bool\nxic bst ote nxb", %{"bst" => 1})
    end

    test "a group with no legs differs in meaning from a group with one empty leg" do
      # The two would print alike, so printing the first is refused. Nor does it compile
      # (OE-1, decision 28): a tree no text could say is a host mistake on entry. It
      # evaluated differently, Enum.any? being false over zero legs, where one empty leg
      # is a jumper and passes power, which the `ote xx` here shows.
      no_legs = {:rung, [{:branches, []}, {:name, 1, "ote"}, {:name, 1, "xx"}]}
      {:routine, {:rungs, [one_empty]}} = parse!("( ) ote xx")

      assert_raise ArgumentError,
                   "not a tree Logex.Parser.parse/1 can produce: a branch group is " <>
                     "{:branches, legs}, with one leg or more: `( )` is one empty leg, " <>
                     "got: {:branches, []}",
                   fn -> lower!(no_legs) end

      assert %{"xx" => 1} = env_after(lower!(one_empty), %{"xx" => 0})

      assert_raise ArgumentError, ~r/no legs/, fn -> Printer.print(no_legs) end
      assert Printer.print(one_empty) == "( ) ote xx"
    end

    test "an empty rung is refused: the grammar filters it out" do
      assert_raise ArgumentError, ~r/empty rung/, fn ->
        Printer.print({:routine, {:rungs, [{:rung, []}]}})
      end

      assert_raise ArgumentError,
                   "not a tree Logex.Parser.parse/1 can produce: a rung is {:rung, elements}, " <>
                     "with one element or more, got: {:rung, []}",
                   fn -> lower!({:rung, []}) end
    end
  end

  describe "the entry check (OE-1): Logex.Parser.well_formed!/1" do
    test "takes every tree the generator makes, as parse/1 could produce each" do
      for ast <- corpus() do
        assert Logex.Parser.well_formed!(ast) == ast
      end
    end

    # Each way of breaking a node, by its kind, into one that no tree parse/1 produces
    # can hold, whatever the node's place: so a tree broken at any one node is refused.
    @breaks %{
      name: [:junk, :line_zero, :two_words, :not_a_word],
      int_lit: [:not_an_integer, :line_nil],
      branches: [:no_legs, :leg_not_a_list, :improper]
    }

    test "refuses a generated tree broken at any one node, with nothing but ArgumentError" do
      broken =
        for ast <- corpus(), {kind, count} <- counts(ast), how <- @breaks[kind] do
          tree = break_nth(ast, kind, :rand.uniform(count), how)

          assert_raise ArgumentError, ~r/^not a tree Logex.Parser.parse\/1 can produce: /, fn ->
            Compiler.instructionize(tree)
          end

          how
        end

      # Its reach: every way of breaking a node was tried.
      assert MapSet.new(broken) == MapSet.new(Enum.concat(Map.values(@breaks)))
    end
  end

  defp parse!(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    {:ok, ast} = Compiler.parse(tokens)
    ast
  end

  defp run(source, env) do
    {:ok, program} = Compiler.instructionize(parse!(source))
    env_after(program, env)
  end

  # One scan through the public API, from an env the test chooses: an instance built by
  # hand, which Logex.Runtime runs without checking its values (outside its contract).
  defp env_after(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: true}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 0, first: true})
    state.env
  end

  # One rung, lowered alone into a program of its own.
  defp lower!(rung) do
    declared = [Logex.Tag.new!("xx", :bool)]
    {:ok, program} = Compiler.instructionize({:routine, {:rungs, [rung]}}, declared)
    program
  end

  # Printing drops line numbers and re-parsing assigns fresh ones from the printed
  # layout, so the round trip is over structure. Nothing else may differ.
  defp strip_lines({:routine, {:rungs, rungs}}),
    do: {:routine, {:rungs, Enum.map(rungs, &strip_lines/1)}}

  defp strip_lines({:rung, elements}), do: {:rung, strip_lines(elements)}
  defp strip_lines({:branches, legs}), do: {:branches, Enum.map(legs, &strip_lines/1)}
  defp strip_lines({kind, _line, value}), do: {kind, 0, value}
  defp strip_lines(elements) when is_list(elements), do: Enum.map(elements, &strip_lines/1)

  # A seeded generator rather than a dependency: the repository has none and takes
  # none. :rand is seeded per test process, so the corpus is the same every run.
  defp corpus do
    :rand.seed(:exsss, @seed)
    for _ <- 1..@corpus_size, do: routine()
  end

  @names ~w(aa bb start motor stop overtemp fault x1 speed_sp t1.dn word.3)

  # Each rung on a line of its own, the next below it, as parse/1 gives them, so every
  # tree is one Logex.Parser.well_formed!/1 takes. The lines draw nothing from :rand, so
  # the corpus is the shapes it was before they were added.
  defp routine, do: {:routine, {:rungs, for(line <- 1..:rand.uniform(3), do: rung(line))}}

  # `routine`'s own filter drops empty rungs, so the generator never makes one.
  defp rung(line), do: {:rung, elements(:rand.uniform(3), 2, line)}

  defp elements(count, depth, line), do: for(_ <- 1..count, do: element(depth, line))

  defp element(0, line), do: leaf(line)
  defp element(depth, line), do: element(depth, :rand.uniform(4), line)

  defp element(depth, 1, line), do: group(depth - 1, line)
  defp element(_depth, _, line), do: leaf(line)

  defp leaf(line), do: leaf(:rand.uniform(4), line)
  # A literal from -299 to 300, negative ones since M3-3 (decision 97): the one draw it
  # always made, so the corpus keeps its shapes.
  defp leaf(1, line), do: {:int_lit, line, :rand.uniform(600) - 300}
  defp leaf(_, line), do: {:name, line, Enum.random(@names)}

  defp group(depth, line),
    do: {:branches, for(_ <- 1..(1 + :rand.uniform(2)), do: leg(depth, line))}

  defp leg(depth, line), do: leg(depth, :rand.uniform(4), line)
  defp leg(_depth, 1, _line), do: []
  defp leg(depth, _, line), do: elements(:rand.uniform(2), depth, line)

  # How many nodes of each kind a tree holds, in reading order, a group before its legs.
  defp counts({:routine, {:rungs, rungs}}),
    do: Enum.frequencies(Enum.flat_map(rungs, fn {:rung, elements} -> kinds(elements) end))

  defp kinds(elements) when is_list(elements), do: Enum.flat_map(elements, &kinds/1)
  defp kinds({:branches, legs}), do: [:branches | kinds(Enum.concat(legs))]
  defp kinds({kind, _line, _value}), do: [kind]

  # The tree with the nth node of a kind, counted as counts/1 counts, broken `how`.
  defp break_nth({:routine, {:rungs, rungs}}, kind, n, how) do
    {rungs, _} = Enum.map_reduce(rungs, n, &broken(&1, kind, &2, how))
    {:routine, {:rungs, rungs}}
  end

  defp broken({:rung, elements}, kind, n, how) do
    {elements, n} = broken(elements, kind, n, how)
    {{:rung, elements}, n}
  end

  defp broken(elements, kind, n, how) when is_list(elements),
    do: Enum.map_reduce(elements, n, &broken(&1, kind, &2, how))

  defp broken({:branches, _} = group, :branches, 1, how), do: {break(how, group), 0}

  defp broken({:branches, legs}, kind, n, how) do
    {legs, n} = Enum.map_reduce(legs, n - here(:branches, kind), &broken(&1, kind, &2, how))
    {{:branches, legs}, n}
  end

  defp broken({kind, _, _} = node, kind, 1, how), do: {break(how, node), 0}
  defp broken({node_kind, _, _} = node, kind, n, _how), do: {node, n - here(node_kind, kind)}

  defp here(kind, kind), do: 1
  defp here(_node_kind, _kind), do: 0

  defp break(:junk, _name), do: :junk
  defp break(:line_zero, {:name, _, word}), do: {:name, 0, word}
  defp break(:two_words, {:name, line, _}), do: {:name, line, "a b"}
  defp break(:not_a_word, {:name, line, _}), do: {:name, line, :aa}
  defp break(:not_an_integer, {:int_lit, line, n}), do: {:int_lit, line, n + 0.5}
  defp break(:line_nil, {:int_lit, _, n}), do: {:int_lit, nil, n}
  defp break(:no_legs, {:branches, _}), do: {:branches, []}
  defp break(:leg_not_a_list, {:branches, [_ | legs]}), do: {:branches, [:leg | legs]}
  defp break(:improper, {:branches, legs}), do: {:branches, legs ++ [[] | :x]}

  # The corpus again, each tree written as source with every literal spelled in a way drawn
  # for it, and the spellings it took. The draws come after the corpus's own, so the corpus
  # is the one the other properties run on.
  defp spelled_corpus do
    trees = corpus()

    for ast <- trees do
      {source, spelt} = spell(ast)
      {ast, source, spelt}
    end
  end

  defp spell({:routine, {:rungs, rungs}}) do
    {lines, spelt} = Enum.map_reduce(rungs, [], &spell/2)
    {Enum.join(lines, "\n"), spelt}
  end

  defp spell({:rung, elements}, spelt) do
    {words, spelt} = spell_all(elements, spelt)
    {Enum.join(words, " "), spelt}
  end

  defp spell_all(elements, spelt) do
    {words, spelt} = Enum.map_reduce(elements, spelt, &spell_one/2)
    {Enum.concat(words), spelt}
  end

  defp spell_one({:name, _, name}, spelt), do: {[name], spelt}

  defp spell_one({:int_lit, _, n}, spelt) do
    word = spelling(n, :rand.uniform(4))
    {[word], [spelt(word) | spelt]}
  end

  defp spell_one({:branches, legs}, spelt) do
    {legs, spelt} = Enum.map_reduce(legs, spelt, &spell_all/2)
    {["("] ++ Enum.concat(Enum.intersperse(legs, ["|"])) ++ [")"], spelt}
  end

  defp spelling(n, 1), do: Integer.to_string(n)
  defp spelling(n, 2), do: separated(Integer.to_string(n))
  defp spelling(n, 3) when n >= 0, do: "16#" <> separated(cased(Integer.to_string(n, 16)))
  defp spelling(n, 4) when n >= 0, do: "2#" <> separated(Integer.to_string(n, 2))
  defp spelling(n, _), do: spelling(n, 1)

  # The shape a spelling reaches, read from the word itself.
  defp spelt("16#" <> _), do: :hex_int_lit
  defp spelt("2#" <> _), do: :binary_int_lit
  defp spelt(word), do: separated_shape(String.contains?(word, "_"))

  defp separated_shape(true), do: :separated_int_lit
  defp separated_shape(false), do: :int_lit

  # A `_` drawn after each digit but the last, never two together nor after a sign.
  defp separated(<<?-, digits::binary>>), do: "-" <> separated(digits)

  defp separated(digits) do
    digits
    |> String.graphemes()
    |> Enum.map_join(fn digit -> digit <> Enum.random(["", "", "_"]) end)
    |> String.trim_trailing("_")
  end

  defp cased(hex), do: Enum.random([hex, String.downcase(hex)])

  # Which grammar productions a generated AST actually reaches.
  defp shapes({:routine, {:rungs, rungs}}) do
    rungs
    |> Enum.map(&shapes(&1, 0))
    |> Enum.reduce(MapSet.new(rung_count_shape(length(rungs))), &MapSet.union/2)
  end

  defp shapes({:rung, elements}, depth), do: shapes_of(elements, depth)

  defp shapes({:name, _, name}, _depth),
    do: MapSet.new([:name | dotted_shape(String.contains?(name, "."))])

  defp shapes({:int_lit, _, n}, _depth), do: MapSet.new([:int_lit | negative_shape(n < 0)])

  defp shapes({:branches, legs}, depth) do
    flags =
      [:group] ++
        leg_count_shape(length(legs)) ++
        empty_leg_shape(Enum.any?(legs, &(&1 == []))) ++
        depth_shape(depth)

    legs
    |> Enum.map(&shapes_of(&1, depth + 1))
    |> Enum.reduce(MapSet.new(flags), &MapSet.union/2)
  end

  defp shapes_of(elements, depth) do
    elements
    |> Enum.map(&shapes(&1, depth))
    |> Enum.reduce(MapSet.new(element_count_shape(length(elements))), &MapSet.union/2)
  end

  defp rung_count_shape(count) when count > 1, do: [:many_rungs]
  defp rung_count_shape(_), do: []
  defp element_count_shape(count) when count > 1, do: [:many_elems]
  defp element_count_shape(_), do: []
  defp leg_count_shape(count) when count > 1, do: [:many_legs]
  defp leg_count_shape(_), do: []
  defp empty_leg_shape(true), do: [:empty_leg]
  defp empty_leg_shape(false), do: []
  defp depth_shape(depth) when depth > 0, do: [:nested]
  defp depth_shape(_), do: []
  defp dotted_shape(true), do: [:dotted_name]
  defp dotted_shape(false), do: []
  defp negative_shape(true), do: [:negative_int_lit]
  defp negative_shape(false), do: []
end
