# Names the tests ExUnit's failures manifest holds, one a line, `file:line: Module: test
# name`, so that a failed run says which tests failed (`mix test` prints `Result: 39/40
# passed` and, under a busy log, the failures can be hard to find). Run from the project's
# root:
#
#     elixir scripts/failed.exs             # by hand: the failures the manifest holds
#     elixir scripts/failed.exs --exit N    # after a run: N, mix test's exit code
#
# It reads the manifest of the test build, `_build/test/lib/logex/.mix/.mix_test_failures`
# (MIX_BUILD_PATH or MIX_BUILD_ROOT, where set, moves it), and by hand prints nothing for a
# manifest that holds no failure, or for none. The manifest is ExUnit's own, kept across
# runs: a test's failure stays in it until a run passes that test, so after a run of one
# file by hand it may still name a failure of another file's earlier run. A suite whose
# test files fail to compile or load runs no test, and ExUnit marks it failed whole, which
# is told in one line beginning `suite:`.
#
# `--exit N` is for a run made with the manifest deleted before it, as `scripts/gate.sh`
# and CI's test step make theirs (decision 515 (e)): it judges the run and exits with the
# run's verdict. ExUnit writes the manifest as the suite finishes, `{1, %{}}` for a run
# that passed, so a run that wrote none did not finish. After a red run, N not 0, it
# prints `mix test exited N; the tests that failed:` and the tests, or, where it names
# none, why: no manifest, the suite did not finish (a test halted the VM, or mix test
# stopped before the suite ran); or a manifest of no failure, every test that ran passed
# and mix test exited N for another reason, a warning under `--warnings-as-errors` for
# one; and it exits N. After a run that exited 0 it prints nothing and exits 0 where the
# manifest is there and names no failure; where there is none, the suite did not finish,
# a test having halted the VM with code 0, and it says so and exits 1, as it does for a
# manifest that names a failure.
#
# The manifest gives a test's module, name and file but not its line, so the line is read
# from the file's syntax tree: the `test` or `doctest` call in that module whose name, its
# `describe`'s before it, gives the test's, as ExUnit builds it, a part interpolated or
# not a string matching any text, a module whose name the compile makes, as
# `Module.concat/2` in a comprehension does, any module, and a name ExUnit cut to 255
# bytes cut alike. Where more than one call could name a test, the surest is taken: a call
# in the test's own module before one in a module the compile names, and in each a call
# whose name is all literal text, exactly the test's, before one whose name the compile
# makes; and where the surest are more than one, as two comprehensions' tests whose names
# both match are, the file alone is given, never a line that may be another test's. A
# test no call names so, one a helper or macro of the file's own defines, is printed with
# its file alone, `file: Module: test name`, as is one whose file is gone or does not
# parse. The line is the call's, the line `mix test file:line` runs and ExUnit's report
# gives. A script, not a test: it uses `case` freely.
defmodule Failed.Lines do
  @moduledoc false

  # Each test a file's syntax tree defines, `{module, match, line}`, `match` the name
  # exactly where every part of it is a literal, or else a regex.
  def tests(file) do
    with {:ok, text} <- File.read(file),
         {:ok, tree} <- Code.string_to_quoted(text, file: file) do
      collect(tree, nil, nil, [])
    else
      _ -> []
    end
  end

  # Where the test `{module, name}` among a file's `tests` is: `file:line` where one call
  # alone is the surest that could name it, else the file alone.
  def at(file, tests, module, name) do
    text = Atom.to_string(name)
    module = inspect(module)

    for {in_module, match, line} <- tests,
        in_module in [module, :any],
        matches?(match, name, text) do
      {{sureness(in_module), sureness(match)}, line}
    end
    |> surest()
    |> located(file)
  end

  # A call in the test's own module before one in a module the compile names; a name of
  # literal text alone before one the compile makes.
  defp sureness(:any), do: 1
  defp sureness({:exact, _}), do: 0
  defp sureness({:regex, _}), do: 1
  defp sureness(_module), do: 0

  defp surest([]), do: nil

  defp surest(found) do
    best = found |> Enum.map(&elem(&1, 0)) |> Enum.min()

    case for({^best, line} <- found, uniq: true, do: line) do
      [line] -> line
      _ -> nil
    end
  end

  defp located(nil, file), do: file
  defp located(line, file), do: "#{file}:#{line}"

  defp matches?({:exact, atom}, name, _text), do: atom == name
  defp matches?({:regex, regex}, _name, text), do: Regex.match?(regex, text)

  defp collect({:defmodule, _, [{:__aliases__, _, parts}, [do: body]]}, module, _, acc) do
    collect(body, nested(module, parts), nil, acc)
  end

  # A module whose name the compile makes, `Module.concat/2`'s in a comprehension: its
  # tests are found by their names alone.
  defp collect({:defmodule, _, [_, [do: body]]}, _, _, acc), do: collect(body, :any, nil, acc)

  defp collect({:describe, _, [name, [do: body]]}, module, nil, acc) do
    collect(body, module, parts(name), acc)
  end

  defp collect({:test, meta, [name | _]}, module, describe, acc) when module != nil do
    described = described(describe, parts(name))
    [{module, match(["test " | described]), meta[:line]} | acc]
  end

  defp collect({:doctest, meta, [documented | _]}, module, _, acc) when module != nil do
    documented = Macro.to_string(documented)

    # ExUnit's names, `doctest module M (n)` and `doctest M.fun/arity (n)`, a function's
    # name never beginning as a module's does, so that `M.Sub`'s are not `M`'s.
    regex =
      Regex.compile!(
        "^doctest (module #{Regex.escape(documented)}|#{Regex.escape(documented)}\\.[^A-Z].*" <>
          "/\\d+) \\(\\d+\\)$",
        "s"
      )

    [{module, {:regex, regex}, meta[:line]} | acc]
  end

  defp collect({_, _, args}, module, describe, acc) when is_list(args) do
    collect(args, module, describe, acc)
  end

  defp collect({left, right}, module, describe, acc) do
    collect(right, module, describe, collect(left, module, describe, acc))
  end

  defp collect(list, module, describe, acc) when is_list(list) do
    Enum.reduce(list, acc, &collect(&1, module, describe, &2))
  end

  defp collect(_, _, _, acc), do: acc

  defp nested(nil, parts), do: Enum.map_join(parts, ".", &Atom.to_string/1)
  defp nested(:any, _parts), do: :any
  defp nested(module, parts), do: module <> "." <> nested(nil, parts)

  defp described(nil, name), do: name
  defp described(describe, name), do: describe ++ [" " | name]

  # A name's parts: its literal text, and `:any` for each part only the compile knows.
  defp parts(text) when is_binary(text), do: [text]
  defp parts({:<>, _, [left, right]}), do: parts(left) ++ parts(right)
  defp parts({:<<>>, _, pieces}), do: Enum.flat_map(pieces, &piece/1)
  defp parts(_), do: [:any]

  defp piece(text) when is_binary(text), do: [text]
  defp piece(_), do: [:any]

  defp match(parts) do
    case Enum.all?(parts, &is_binary/1) do
      true -> {:exact, exunit_name(IO.iodata_to_binary(parts))}
      false -> {:regex, Regex.compile!("^" <> Enum.map_join(parts, &pattern/1) <> "$", "s")}
    end
  end

  defp pattern(:any), do: ".*"
  defp pattern(text), do: Regex.escape(text)

  # ExUnit.Case's own: a name longer than 255 bytes is cut to 246 and given a hash.
  defp exunit_name(name) when byte_size(name) > 255 do
    hash = :erlang.md5(name) |> binary_slice(0, 3) |> Base.encode64()
    exunit_name(String.byte_slice(name, 0, 246) <> "... " <> hash)
  end

  defp exunit_name(name), do: String.to_atom(name)
end

build =
  System.get_env("MIX_BUILD_PATH") ||
    Path.join(System.get_env("MIX_BUILD_ROOT", "_build"), "test")

path = Path.join([build, "lib", "logex", ".mix", ".mix_test_failures"])

manifest =
  case File.read(path) do
    {:ok, binary} -> :erlang.binary_to_term(binary)
    {:error, :enoent} -> :none
  end

named =
  case manifest do
    :none ->
      []

    {_version, :all} ->
      [
        "suite: no test ran: a test file failed to compile or load, so ExUnit marked " <>
          "the whole suite failed; mix test's output names the file"
      ]

    {_version, failures} ->
      tests =
        failures
        |> Map.values()
        |> Enum.uniq()
        |> Map.new(&{&1, Failed.Lines.tests(&1)})

      for {{module, name}, file} <- Enum.sort(failures) do
        at = Failed.Lines.at(Path.relative_to_cwd(file), tests[file], module, name)
        "#{at}: #{inspect(module)}: #{name}"
      end
  end

# After a run of the suite, `code` its exit code: what to print, and the run's verdict.
judged = fn
  0, :none, [] ->
    {[
       "mix test exited 0, and ExUnit wrote no failures manifest: the suite did not " <>
         "finish, a test having halted the VM, so the run is red; the output above names " <>
         "any test that failed before it stopped"
     ], 1}

  0, _manifest, [] ->
    {[], 0}

  code, _manifest, [_ | _] = named ->
    {["mix test exited #{code}; the tests that failed:" | named], max(code, 1)}

  code, :none, [] ->
    {[
       "mix test exited #{code}; the tests that failed:",
       "none named: ExUnit wrote no failures manifest, so the suite did not finish: a " <>
         "test halted the VM, or mix test stopped before the suite ran; the output above " <>
         "names any test that failed before it stopped"
     ], code}

  code, _manifest, [] ->
    {[
       "mix test exited #{code}; the tests that failed:",
       "none named: every test that ran passed, and mix test exited #{code} for another " <>
         "reason, above: a warning under --warnings-as-errors, for one"
     ], code}
end

case {System.argv(), Integer.parse(Enum.at(System.argv(), 1, ""))} do
  {[], _} ->
    Enum.each(named, &IO.puts/1)

  {["--exit", _], {code, ""}} when code >= 0 ->
    {lines, verdict} = judged.(code, manifest, named)
    Enum.each(lines, &IO.puts/1)
    System.halt(verdict)

  _ ->
    IO.puts(:stderr, "usage: elixir scripts/failed.exs [--exit N]")
    System.halt(2)
end
