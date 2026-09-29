defmodule Logex.ApiContractTest do
  @moduledoc """
  M1-5's contract, over seeded random programs and random host calls. A mistake in the
  source is a returned diagnostic; a mistake by the host is an `ArgumentError` whose
  message is one of the documented kinds; and nothing else ever escapes. The seed is fixed,
  so a failure reproduces.
  """
  use ExUnit.Case, async: true

  alias Logex.{Diagnostic, Instance, Program, Runtime, Scan}

  @words ~w(var var_input var_output bool dint xic xio ote otl otu move a b c start stop Motor) ++
           ["(", "|", ")", "0", "1", "7", "1200", "3000000000", "@", "1bst", "retain", "\n", "\n"]

  @junk [
    0,
    1,
    2,
    -1,
    1.0,
    nil,
    true,
    :x,
    "s",
    [],
    %{},
    {1},
    <<255>>,
    2_147_483_648,
    %Scan{now: 0, first: true}
  ]

  # The documented kinds of refusal, by their first words.
  @refusals [
    "input ",
    "inputs must be",
    "scan.",
    "state.",
    "time went backwards",
    "expected a %Logex.",
    "elapsed_ms must be",
    "restart takes",
    "this state is an instance"
  ]

  setup do
    :rand.seed(:exsss, {2026, 9, 29})
    :ok
  end

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  # Half the time a well-formed program, so the success path and its warnings are reached;
  # otherwise a soup of words, so every kind of mistake is.
  defp source, do: source(:rand.uniform(2))

  defp source(1) do
    inputs = Enum.filter(~w(start stop), fn _ -> :rand.uniform(2) == 1 end)
    bools = inputs ++ ~w(a b c)

    declarations =
      Enum.map(inputs, &"var_input #{&1} bool") ++
        Enum.map(~w(a b c), &"#{pick(~w(var var_output))} #{&1} bool") ++ ["var_output n dint 7"]

    rungs =
      for _ <- 1..:rand.uniform(5) do
        contacts =
          Enum.map_join(1..:rand.uniform(3), " ", fn _ ->
            "#{pick(~w(xic xio))} #{pick(bools)}"
          end)

        "#{contacts} #{pick(["ote #{pick(~w(a b c))}", "otl #{pick(~w(a b c))}", "otu a", "move 5 n", "move 1 b", "( xic a | ) ote c"])}"
      end

    Enum.join(declarations ++ rungs, "\n")
  end

  defp source(2) do
    lines =
      for _ <- 1..:rand.uniform(6) do
        Enum.map_join(1..:rand.uniform(7), " ", fn _ -> pick(@words) end)
      end

    declarations =
      for name <- ~w(a b c start stop), :rand.uniform(3) > 1 do
        "#{pick(~w(var var_input var_output))} #{name} #{pick(~w(bool bool dint))}"
      end

    Enum.join(declarations ++ lines, "\n")
  end

  test "compile/2 never raises for any source, and its diagnostics are in line order" do
    for _ <- 1..600 do
      case Logex.compile(source(), name: "p") do
        {:ok, %Program{name: "p", warnings: warnings}} ->
          assert warnings == Enum.sort_by(warnings, & &1.line)

        {:error, [_ | _] = diagnostics} ->
          assert Enum.all?(
                   diagnostics,
                   &match?(%Diagnostic{line: line} when is_integer(line) and line > 0, &1)
                 )

          assert diagnostics == Enum.sort_by(diagnostics, & &1.line)
      end
    end
  end

  test "the runtime refuses every host mistake with a documented ArgumentError, and nothing else" do
    programs =
      Stream.repeatedly(fn -> Logex.compile(source(), name: "p") end)
      |> Stream.flat_map(fn
        {:ok, program} -> [program]
        {:error, _} -> []
      end)
      |> Enum.take(40)

    assert length(programs) == 40

    for program <- programs, reduce: 0 do
      refused -> refused + walk(program, Runtime.instance(program), 30)
    end
    |> then(&assert(&1 > 0))
  end

  # Random operations on one instance; returns how many were refused.
  defp walk(_program, _state, 0), do: 0

  defp walk(program, state, n) do
    case attempt(fn -> operation(program, state) end) do
      {:ok, %Instance{} = next} ->
        assert next.now >= state.now
        walk(program, next, n - 1)

      :refused ->
        1 + walk(program, state, n - 1)
    end
  end

  defp operation(program, state) do
    case :rand.uniform(5) do
      1 ->
        Runtime.put_inputs(program, state, inputs(program))

      2 ->
        scanned(program, Runtime.scan(program, state, pick([0, 0, 5, 10, -1, 1.5, nil])))

      3 ->
        scanned(
          program,
          Runtime.call(program, state, inputs(program), %Scan{
            now: state.now + pick([0, 3, -1]),
            first: pick([state.first, state.first, not state.first])
          })
        )

      4 ->
        Runtime.restart(program, state, pick([:cold, :warm, :hot]))

      5 ->
        scanned(
          program,
          Runtime.call(
            pick([program, :x, %{}]),
            pick([state, %{}, nil]),
            pick([%{}, [], nil]),
            pick([%Scan{now: state.now, first: state.first}, 0, nil])
          )
        )
    end
  end

  defp scanned(program, {outputs, %Instance{} = state}) do
    var_outputs = for {name, %{section: :var_output}} <- program.tags, do: name
    assert Enum.sort(Map.keys(outputs)) == Enum.sort(var_outputs)
    assert Enum.all?(Map.values(outputs), &is_integer/1)
    state
  end

  defp inputs(program) do
    names = Map.keys(program.tags) ++ ["zz", "Start", <<255>>, :start, 7]

    Map.new(1..:rand.uniform(3), fn _ ->
      {pick(names), pick([0, 1, 1, 0, 2_147_483_647] ++ @junk)}
    end)
  end

  defp attempt(fun) do
    {:ok, fun.()}
  rescue
    error in ArgumentError ->
      assert Enum.any?(@refusals, &String.starts_with?(error.message, &1)),
             "undocumented refusal: #{error.message}"

      :refused
  end
end
