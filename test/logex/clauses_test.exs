defmodule Logex.ClausesTest do
  @moduledoc """
  Decision 264: CLAUDE.md's rule, multiple function clauses and not conditionals, held on
  the walks' and the end-to-end tests' oracles. Each module of `api_contract_test.exs`
  names its draws, the functions that draw a program, an input, a step or a fault at
  random or write a drawn program as text, in `@draws`; a `case`, `cond`, `if` or
  `unless` lies only in one of them, and every other function and test, each oracle and
  the harness that compares it with logex, is clauses. `end_to_end_test.exs` holds none.
  The files are read as syntax trees, so that a conditional in a string, a comment or a
  heredoc is none and one written inline, `if(x, do: 1, else: 0)`, is one.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @kinds [:case, :cond, :if, :unless]

  test "a walk's conditional lies only in a draw its module names, and each draw named is one of its functions" do
    path = Path.join(@root, "test/logex/api_contract_test.exs")
    modules = modules(path)

    # The three walks name their draws; a module inside one, a seam's stand-in, holds none.
    for walk <- [
          Logex.ApiContractTest,
          Logex.ApiContractTest.CrossTypeWalk,
          Logex.ApiContractTest.RunnerWalk
        ],
        do: assert(modules[walk].draws != [], inspect(walk))

    for {module, %{draws: draws, functions: functions, conditionals: conditionals}} <- modules do
      assert draws -- functions == [], "#{inspect(module)} names draws it does not define"

      outside = for {name, line, kind} <- conditionals, name not in draws, do: {name, line, kind}
      assert outside == [], "#{inspect(module)}: a conditional outside the draws"
    end
  end

  test "an end-to-end test's oracle, and every function and test beside it, holds no conditional" do
    path = Path.join(@root, "test/logex/end_to_end_test.exs")

    for {module, %{conditionals: conditionals}} <- modules(path),
        do: assert(conditionals == [], inspect(module))
  end

  # The check itself: each kind found, inline and in a block, where it is, and nothing in
  # a string, a comment or a heredoc.
  test "the reading finds every conditional, inline or in a block, and none in a string" do
    source = ~S'''
    defmodule M do
      @draws ~w(d)a
      # if this were code
      @doc "if x, do: y"
      def d(x), do: if(x, do: 1, else: 0)
      defp o(x) do
        case x do
          _ -> cond do
            true -> unless(x, do: "case")
          end
        end
      end
      test "t" do
        if true, do: :ok
      end
    end
    '''

    assert %{M => %{draws: [:d], conditionals: found, functions: functions}} = read(source)
    assert Enum.sort(functions) == [:d, :o]

    assert Enum.map(found, fn {name, _line, kind} -> {name, kind} end) == [
             {:d, :if},
             {:o, :case},
             {:o, :cond},
             {:o, :unless},
             {"test t", :if}
           ]
  end

  defp modules(path), do: read(File.read!(path))

  defp read(text) do
    {:ok, ast} = Code.string_to_quoted(text)
    {_ast, modules} = Macro.prewalk(ast, %{}, &module/2)
    modules
  end

  defp module({:defmodule, _, [{:__aliases__, _, parts}, [do: body]]}, modules) do
    name = Module.concat(parts)
    {_body, found} = Macro.prewalk(body, %{draws: [], functions: [], conditionals: []}, &part/2)
    modules = Map.put(modules, name, %{found | conditionals: Enum.reverse(found.conditionals)})
    # A module inside it is read as its own.
    {{:__block__, [], []}, Map.merge(read_nested(body), modules)}
  end

  defp module(node, modules), do: {node, modules}

  defp read_nested(body) do
    {_body, nested} = Macro.prewalk(body, %{}, &module/2)
    nested
  end

  defp part({:defmodule, _, _}, found), do: {nil, found}

  defp part({:@, _, [{:draws, _, [{:sigil_w, _, [{:<<>>, _, [words]}, ~c"a"]}]}]} = node, found),
    do: {node, %{found | draws: Enum.map(String.split(words), &String.to_atom/1)}}

  defp part({kind, _, [head | body]}, found) when kind in [:def, :defp] do
    name = name(head)
    found = %{found | functions: Enum.uniq([name | found.functions])}
    {nil, conditionals(body, name, found)}
  end

  defp part({:test, _, [title | body]}, found) when is_binary(title),
    do: {nil, conditionals(body, "test #{title}", found)}

  defp part({:test, _, [_title | body]}, found), do: {nil, conditionals(body, "test", found)}
  defp part(node, found), do: {node, found}

  defp conditionals(body, name, found) do
    {_body, found} =
      Macro.prewalk(body, found, fn
        {kind, meta, args} = node, found when kind in @kinds and is_list(args) ->
          {node, %{found | conditionals: [{name, meta[:line], kind} | found.conditionals]}}

        node, found ->
          {node, found}
      end)

    found
  end

  defp name({:when, _, [head | _]}), do: name(head)
  defp name({name, _, _}) when is_atom(name), do: name
end
