defmodule Logex.PrinterTest do
  use ExUnit.Case, async: true

  alias Logex.Compiler
  alias Logex.Printer

  @corpus_size 200
  @seed {1, 2, 3}

  # Every production in src/ladder_parser.yrl that a printed AST can exercise. The
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
                     :many_rungs
                   ])

  describe "round trip" do
    test "generates every shape the grammar can hold" do
      assert @required_shapes == corpus() |> Enum.map(&shapes/1) |> Enum.reduce(&MapSet.union/2)
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
      bst xic start nxb xic motor bnd xio stop ote motor
      xic motor ote run_lamp
      xic overtemp otl fault
      xic fault mov 0 speed_sp
      """

      env = %{"start" => 1, "stop" => 0, "overtemp" => 1}

      assert run(source, env) == run(Printer.print(parse!(source)), env)
      assert %{"motor" => 1, "run_lamp" => 1, "fault" => 1} = run(source, env)
    end
  end

  describe "canonical form" do
    # print/1 emits one spelling rather than reproducing the input. Both losses are
    # pinned here so that neither can change without a test going red — in an editing
    # box that shows a rung back, every render rewrites what the user typed.
    test "runs of whitespace collapse to one space and a rung to one line" do
      assert Printer.print(parse!("  xic   aa \t   ote   bb   ")) == "xic aa ote bb"
    end

    test "integer literals print in their shortest form" do
      assert Printer.print(parse!("mov 007 hh")) == "mov 7 hh"
    end

    test "a branch group prints with single spaces around every delimiter" do
      assert Printer.print(parse!("bst  xic aa  nxb  bnd ote xx")) == "bst xic aa nxb bnd ote xx"
    end
  end

  describe "shapes parse/1 cannot produce are refused, not mangled" do
    test "a tag named after a branch keyword would read back as structure" do
      assert_raise ArgumentError, ~r/tag named "nxb"/, fn ->
        Printer.print({:rung, [{:name, 1, "xic"}, {:name, 1, "nxb"}]})
      end
    end

    test "a group with no legs differs in meaning from a group with one empty leg" do
      # The two would print alike, so printing the first is refused. They evaluate
      # differently: Enum.any? is false over zero legs, while one empty leg is a
      # jumper and passes power. Evaluated as rungs rather than as routines, because
      # the `{:routine, _}` clause reports {true, env} whatever the last rung did.
      no_legs = {:rung, [{:branches, []}, {:name, 1, "ote"}, {:name, 1, "xx"}]}
      {:routine, {:rungs, [one_empty]}} = parse!("bst bnd ote xx")

      assert {false, %{"xx" => 0}} =
               Compiler.evaluate(Compiler.instructionize(no_legs), {true, %{}})

      assert {true, %{"xx" => 1}} =
               Compiler.evaluate(Compiler.instructionize(one_empty), {true, %{}})

      assert_raise ArgumentError, ~r/no legs/, fn -> Printer.print(no_legs) end
      assert Printer.print(one_empty) == "bst bnd ote xx"
    end

    test "an empty rung is refused: the grammar filters it out" do
      assert_raise ArgumentError, ~r/empty rung/, fn ->
        Printer.print({:routine, {:rungs, [{:rung, []}]}})
      end
    end
  end

  defp parse!(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    {:ok, ast} = Compiler.parse(tokens)
    ast
  end

  defp run(source, env) do
    {_, new_env} = Compiler.evaluate(Compiler.instructionize(parse!(source)), {true, env})
    new_env
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

  @names ~w(aa bb start motor stop overtemp fault x1 speed_sp)

  defp routine, do: {:routine, {:rungs, for(_ <- 1..:rand.uniform(3), do: rung())}}

  # `routine`'s own filter drops empty rungs, so the generator never makes one.
  defp rung, do: {:rung, elements(:rand.uniform(3), 2)}

  defp elements(count, depth), do: for(_ <- 1..count, do: element(depth))

  defp element(0), do: leaf()
  defp element(depth), do: element(depth, :rand.uniform(4))

  defp element(depth, 1), do: group(depth - 1)
  defp element(_depth, _), do: leaf()

  defp leaf, do: leaf(:rand.uniform(4))
  defp leaf(1), do: {:int_lit, 1, :rand.uniform(300) - 1}
  defp leaf(_), do: {:name, 1, Enum.random(@names)}

  defp group(depth), do: {:branches, for(_ <- 1..(1 + :rand.uniform(2)), do: leg(depth))}

  defp leg(depth), do: leg(depth, :rand.uniform(4))
  defp leg(_depth, 1), do: []
  defp leg(depth, _), do: elements(:rand.uniform(2), depth)

  # Which grammar productions a generated AST actually reaches.
  defp shapes({:routine, {:rungs, rungs}}) do
    rungs
    |> Enum.map(&shapes(&1, 0))
    |> Enum.reduce(MapSet.new(rung_count_shape(length(rungs))), &MapSet.union/2)
  end

  defp shapes({:rung, elements}, depth), do: shapes_of(elements, depth)
  defp shapes({:name, _, _}, _depth), do: MapSet.new([:name])
  defp shapes({:int_lit, _, _}, _depth), do: MapSet.new([:int_lit])

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
end
