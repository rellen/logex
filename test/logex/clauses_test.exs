defmodule Logex.ClausesTest do
  @moduledoc """
  Decision 264: CLAUDE.md's rule, multiple function clauses and not conditionals, held on
  the walks' and the end-to-end tests' oracles. Each module of `api_contract_test.exs`
  names its draws, the functions that draw a program, an input, a step or a fault at
  random or write a drawn program as text, in `@draws`; a `case`, `cond`, `if` or
  `unless` lies only in one of them, and every other function, macro and test, each
  oracle and the harness that compares it with logex, and every other form of a module's
  body, a `setup`, a module attribute's anonymous function or the body's own code, is
  clauses. `end_to_end_test.exs` holds none. The files are read as syntax trees, so that a
  conditional in a string, a comment or a heredoc is none and one written inline,
  `if(x, do: 1, else: 0)`, or through its module, `Kernel.if(x, do: 1)`, is one.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @kinds [:case, :cond, :if, :unless]
  @defs [:def, :defp, :defmacro, :defmacrop]
  @kernel [[:Kernel], [:Kernel, :SpecialForms]]

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

  # Wherever a module's body holds code, not only in a `def`, `defp` or `test`: a `setup`,
  # a macro, a module attribute's anonymous function, a `describe`'s tests and a
  # conditional written through its module, each a conditional outside the draws unless a
  # draw holds it.
  test "the reading finds a conditional in a setup, a macro, an attribute, a describe or " <>
         "written through Kernel" do
    source = ~S'''
    defmodule M do
      @draws ~w(d)a
      @pick fn x -> case x do _ -> x end end
      setup do
        if true, do: :ok
      end
      defmacrop m(x), do: quote(do: unless(unquote(x), do: 1))
      def d(x), do: Kernel.if(x, do: 1)
      defp o(x), do: Kernel.SpecialForms.cond(do: (x -> 1))
      describe "a" do
        test "t", do: Kernel.unless(true, do: :ok)
      end
      if Mix.env() == :test, do: :ok
    end
    '''

    assert %{M => %{draws: [:d], conditionals: found, functions: functions}} = read(source)
    assert Enum.sort(functions) == [:d, :m, :o]

    assert Enum.map(found, fn {name, _line, kind} -> {name, kind} end) == [
             {"@pick", :case},
             {"setup", :if},
             {:m, :unless},
             {:d, :if},
             {:o, :cond},
             {"test t", :unless},
             {"the module's body", :if}
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
    found = Enum.reduce(forms(body), %{draws: [], functions: [], conditionals: []}, &form/2)
    modules = Map.put(modules, name, %{found | conditionals: Enum.reverse(found.conditionals)})
    # A module inside it is read as its own.
    {{:__block__, [], []}, Map.merge(read_nested(body), modules)}
  end

  defp module(node, modules), do: {node, modules}

  defp read_nested(body) do
    {_body, nested} = Macro.prewalk(body, %{}, &module/2)
    nested
  end

  defp forms({:__block__, _, forms}), do: forms
  defp forms(form), do: [form]

  # Each form of a module's body is read whole, a conditional anywhere in it found under
  # the function, macro or test that holds it, or else under the form itself: a `setup`,
  # a `describe`'s, a module attribute's anonymous function or the body's own code, none
  # of which is a draw.
  defp form({:@, _, [{:draws, _, [{:sigil_w, _, [{:<<>>, _, [words]}, ~c"a"]}]}]}, found),
    do: %{found | draws: Enum.map(String.split(words), &String.to_atom/1)}

  defp form({:@, _, [{attribute, _, _}]} = node, found),
    do: walk(node, "@#{attribute}", found)

  defp form({name, _, _} = node, found) when is_atom(name) and name not in @kinds,
    do: walk(node, "#{name}", found)

  defp form(node, found), do: walk(node, "the module's body", found)

  defp walk({:defmodule, _, _}, _owner, found), do: found

  defp walk({kind, _, [head | body]}, _owner, found) when kind in @defs do
    name = name(head)
    walk(body, name, %{found | functions: Enum.uniq([name | found.functions])})
  end

  defp walk({:test, _, [title | body]}, _owner, found) when is_binary(title),
    do: walk(body, "test #{title}", found)

  defp walk({:test, _, [_title | body]}, _owner, found), do: walk(body, "test", found)

  defp walk({kind, meta, args}, owner, found) when kind in @kinds and is_list(args),
    do: walk(args, owner, conditional(owner, meta, kind, found))

  # A conditional written through its module, `Kernel.if(x, do: 1)`.
  defp walk({{:., _, [{:__aliases__, _, parts}, kind]}, meta, args}, owner, found)
       when parts in @kernel and kind in @kinds,
       do: walk(args, owner, conditional(owner, meta, kind, found))

  defp walk({left, _meta, right}, owner, found), do: walk(right, owner, walk(left, owner, found))
  defp walk({left, right}, owner, found), do: walk(right, owner, walk(left, owner, found))
  defp walk([node | rest], owner, found), do: walk(rest, owner, walk(node, owner, found))
  defp walk(_leaf, _owner, found), do: found

  defp conditional(owner, meta, kind, found),
    do: %{found | conditionals: [{owner, meta[:line], kind} | found.conditionals]}

  defp name({:when, _, [head | _]}), do: name(head)
  defp name({name, _, _}) when is_atom(name), do: name
end
