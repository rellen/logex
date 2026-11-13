# Names the tests ExUnit's failures manifest holds, one a line, `file:line: Module: test
# name`, so that a failed run says which tests failed (`mix test` prints `Result: 39/40
# passed` and, under a busy log, the failures can be hard to find). Run from the project's
# root:
#
#     elixir scripts/failed.exs
#
# It reads the manifest of the test build, `_build/test/lib/logex/.mix/.mix_test_failures`
# (MIX_BUILD_PATH or MIX_BUILD_ROOT, where set, moves it), and prints nothing for a
# manifest that holds no failure. The manifest is ExUnit's own, kept across runs: a test's
# failure stays in it until a run passes that test, so after a run of one file by hand it
# may still name a failure of another file's earlier run. `scripts/gate.sh`,
# `scripts/mutate.sh` and `scripts/load.sh` delete it before each run, and so does CI's
# test step, which runs this after a red `mix test` (decision 515 (e)), so after them it
# names that run's failures alone. A suite whose test files fail to compile or load runs
# no test, and ExUnit marks it failed whole, which is told in one line beginning `suite:`.
#
# The manifest gives a test's module, name and file but not its line, so the line is read
# from the file's syntax tree: the `test` or `doctest` call in that module whose name, its
# `describe`'s before it, gives the test's, as ExUnit builds it, a part interpolated or
# not a string matching any text, a module whose name the compile makes, as
# `Module.concat/2` in a comprehension does, any module, and a name ExUnit cut to 255
# bytes cut alike. A test
# no call names so, one a helper or macro of the file's own defines, is printed with its
# file alone, `file: Module: test name`, as is one whose file is gone or does not parse.
# The line is the call's, the line `mix test file:line` runs and ExUnit's report gives.
# A script, not a test: it uses `case` freely.
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

  # Where the test `{module, name}` among a file's `tests` is: `file:line`, or the file
  # alone where no call names it.
  def at(file, tests, module, name) do
    text = Atom.to_string(name)
    module = inspect(module)

    tests
    |> Enum.find_value(fn {in_module, match, line} ->
      in_module in [module, :any] and matches?(match, name, text) and line
    end)
    |> located(file)
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

    regex =
      Regex.compile!("^doctest (module )?" <> Regex.escape(documented) <> "[ .]")

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

case File.read(path) do
  {:ok, binary} ->
    case :erlang.binary_to_term(binary) do
      {_version, :all} ->
        IO.puts(
          "suite: no test ran: a test file failed to compile or load, so ExUnit marked " <>
            "the whole suite failed; mix test's output names the file"
        )

      {_version, failures} ->
        tests =
          failures
          |> Map.values()
          |> Enum.uniq()
          |> Map.new(&{&1, Failed.Lines.tests(&1)})

        for {{module, name}, file} <- Enum.sort(failures) do
          at = Failed.Lines.at(Path.relative_to_cwd(file), tests[file], module, name)
          IO.puts("#{at}: #{inspect(module)}: #{name}")
        end
    end

  {:error, :enoent} ->
    :ok
end
