defmodule Logex.ScratchTest do
  @moduledoc """
  Two suites on one machine share no scratch directory (RV-30): every name a test file
  makes in the machine's temporary directory, `System.tmp_dir!/0`, holds the VM's OS pid,
  `System.pid/0`, beside whatever else names it. A name made of the VM's own count alone,
  `logex-rv2-<n>` from `System.unique_integer/1`, is the same in every VM, each counting
  from 1, so two suites run at once, two clones gated side by side, made, read and
  removed each other's directories; `prose_test.exs` met it first (DOC-1's step 1).

  The rule is read from the syntax tree of every test file, as `clauses_test.exs` reads
  `lib/`: each call of `Path.join` that takes the temporary directory names the pid among
  its arguments, and a use of the temporary directory outside a `Path.join` is one of
  those listed here, which name nothing in it. A test's own directory, ExUnit's
  `:tmp_dir`, is under the checkout and is no such name.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  # The uses of the temporary directory outside a `Path.join`, by file: the forces file's
  # refusal of a directory given as its path, which makes nothing in it.
  @bare %{"test/logex/force_test.exs" => 1}

  # A source's uses of the temporary directory: `{:joined, line, pid?}` for each
  # `Path.join` that takes it, `pid?` whether its arguments name `System.pid/0`, and
  # `{:bare, count}` for the uses outside any.
  defp uses(source) do
    tree = Code.string_to_quoted!(source)
    {_tree, joins} = Macro.prewalk(tree, [], &joined/2)
    inside = Enum.sum(for {:joined, _line, _pid?, count} <- joins, do: count)

    for({:joined, line, pid?, _count} <- Enum.reverse(joins), do: {:joined, line, pid?}) ++
      bare(calls(tree, [:tmp_dir!, :tmp_dir]) - inside)
  end

  defp bare(0), do: []
  defp bare(count), do: [{:bare, count}]

  defp joined({{:., _, [{:__aliases__, _, [:Path]}, :join]}, meta, arguments} = node, found),
    do: {node, taking(calls(arguments, [:tmp_dir!, :tmp_dir]), meta, arguments, found)}

  defp joined(node, found), do: {node, found}

  defp taking(0, _meta, _arguments, found), do: found

  defp taking(count, meta, arguments, found),
    do: [{:joined, meta[:line], calls(arguments, [:pid]) > 0, count} | found]

  # How many calls of `System`'s `functions` a tree holds.
  defp calls(tree, functions) do
    {_tree, count} =
      Macro.prewalk(tree, 0, fn
        {{:., _, [{:__aliases__, _, [:System]}, function]}, _, []} = node, count ->
          {node, count + counted(function in functions)}

        node, count ->
          {node, count}
      end)

    count
  end

  defp counted(true), do: 1
  defp counted(false), do: 0

  test "every name a test file makes in the machine's temporary directory holds the " <>
         "VM's OS pid" do
    found =
      for path <- Enum.sort(Path.wildcard(Path.join(@root, "test/**/*.exs"))),
          use <- uses(File.read!(path)),
          do: {Path.relative_to(path, @root), use}

    assert for({file, {:joined, line, false}} <- found, do: "#{file}:#{line}") == []
    assert Map.new(for {file, {:bare, count}} <- found, do: {file, count}) == @bare

    # Its reach: the directories the older tests name, and the checker's file.
    named = for {file, {:joined, _line, true}} <- found, do: file
    assert length(named) >= 15

    assert Enum.all?(
             ~w(compile_total_test fault_test loading_test prose_test real_test) ++
               ~w(review_lows_test runner_test tag_bit_test tag_subscript_test) ++
               ~w(array_configuration_test),
             &("test/logex/#{&1}.exs" in named)
           )
  end

  test "the rule reads a name by the count alone as shared, on one line or several, and " <>
         "a use outside a Path.join as bare" do
    alone =
      ~S|dir = Path.join(System.tmp_dir!(), "logex-rv2-#{System.unique_integer([:positive])}")|

    several = ~S"""
    dir =
      Path.join(
        System.tmp_dir(),
        "logex_fault_#{System.unique_integer([:positive])}"
      )
    """

    own = ~S|Path.join(System.tmp_dir!(), "logex-#{System.pid()}-#{System.unique_integer()}")|
    nested = ~S|Path.join([System.tmp_dir!(), "logex", "#{System.pid()}", "a.ld"])|
    bare = ~S|started(System.tmp_dir!(), forces: Path.join(dir, "#{System.pid()}"))|

    assert uses(alone) == [{:joined, 1, false}]
    assert uses(several) == [{:joined, 2, false}]
    assert uses(own) == [{:joined, 1, true}]
    assert uses(nested) == [{:joined, 1, true}]
    assert uses(bare) == [{:bare, 1}]

    assert uses(alone <> "\n" <> own <> "\n" <> bare) ==
             [{:joined, 1, false}, {:joined, 2, true}, {:bare, 1}]

    assert uses(~S|Path.join(dir, "plant.ld")|) == []
  end
end
