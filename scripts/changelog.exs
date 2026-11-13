# Holds CHANGELOG.md to the decisions of docs/organisation.md §7 and to mix.exs's version
# (decision 515 (b)): the release step's checks of the documents. Run from the project's
# root:
#
#     elixir scripts/changelog.exs             # at any commit: the suite runs this
#     elixir scripts/changelog.exs --release   # before a tag: scripts/release.sh runs this
#
# It reads CHANGELOG.md as its head says: each `## ` heading an entry, a release
# `## X.Y.Z — YYYY-MM-DD` or `## Unreleased` above the newest release; each entry's first
# line `Decisions: ` and the numbers and ranges it carries, `1–14, 30, 41–54.`, or `none.`.
# It refuses a heading of another form, an `Unreleased` below the newest entry, a version
# named twice, an entry whose first line is no such list, a range that does not rise, a
# decision named twice, a decision §7 records that no entry names, and one an entry names
# that §7 does not record (§7 is the section of docs/organisation.md headed `## 7.`, each
# decision a line `N. **`). With `--release` it refuses too a newest entry that is
# `Unreleased`, and one whose version is not the one mix.exs gives, as Mix reads it.
#
# Each refusal is a line on stderr, `changelog: ...`, and the exit code is 1. With none, it
# prints `changelog: every decision of §7, 1–531, named once`, or with `--release` the
# version alone, which scripts/release.sh tags. A script, not a test: it uses `case`
# freely.
defmodule Changelog do
  @moduledoc false

  @heading ~r/^## (.*)$/u
  @release ~r/^(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?) — (\d{4}-\d{2}-\d{2})$/u
  @decisions ~r/^Decisions: (.*?)\.?$/u
  @item ~r/^(\d+)(?:[–-](\d+))?$/u

  def main(args) do
    entries = entries(File.read!("CHANGELOG.md"))
    recorded = recorded(File.read!("docs/organisation.md"))

    refusals =
      Enum.flat_map(entries, & &1.refusals) ++
        unreleased(entries) ++ twice(entries) ++ named(entries, recorded)

    refusals = refusals ++ release(args, entries)
    report(refusals, args, entries, recorded)
  end

  # Each entry: its heading's line, the release it names or `:unreleased`, the decisions
  # its first line names, and what is wrong with either.
  defp entries(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.chunk_while(nil, &chunk/2, &after_chunks/1)
    |> Enum.map(&entry/1)
  end

  defp chunk({line, n}, acc) do
    case {Regex.run(@heading, line), acc} do
      {[_, title], nil} -> {:cont, {n, title, []}}
      {[_, title], {at, was, lines}} -> {:cont, {at, was, Enum.reverse(lines)}, {n, title, []}}
      {nil, nil} -> {:cont, nil}
      {nil, {at, title, lines}} -> {:cont, {at, title, [{line, n} | lines]}}
    end
  end

  defp after_chunks(nil), do: {:cont, nil}
  defp after_chunks({at, title, lines}), do: {:cont, {at, title, Enum.reverse(lines)}, nil}

  # An entry's first line that is not blank, and its number; an entry of none, its heading's.
  defp entry({at, title, lines}) do
    {release, wrong} = release_of(at, title)
    {first, line} = Enum.find(lines, {"", at}, fn {text, _} -> String.trim(text) != "" end)
    {numbers, wrong_list} = decisions(line, first)

    %{at: at, line: line, title: title, release: release, numbers: numbers}
    |> Map.put(:refusals, wrong ++ wrong_list)
  end

  defp release_of(_at, "Unreleased"), do: {:unreleased, []}

  defp release_of(at, title) do
    case Regex.run(@release, title) do
      [_, version, date] ->
        case Date.from_iso8601(date) do
          {:ok, _} -> {version, []}
          _ -> {version, ["line #{at}: `#{date}` is no date, in `## #{title}`"]}
        end

      nil ->
        {nil,
         [
           "line #{at}: an entry's heading is `## X.Y.Z — YYYY-MM-DD` or `## Unreleased`, " <>
             "not `## #{title}`"
         ]}
    end
  end

  defp decisions(at, first) do
    case Regex.run(@decisions, first) do
      [_, "none"] ->
        {[], []}

      [_, list] ->
        list |> String.split(", ") |> Enum.map(&item(at, &1)) |> Enum.unzip() |> flat()

      nil ->
        {[],
         [
           "line #{at}: the entry's first line is not `Decisions: ` and the decisions it " <>
             "carries, `1–14, 30.`, or `none.`: #{inspect(first)}"
         ]}
    end
  end

  defp flat({numbers, wrong}), do: {Enum.concat(numbers), Enum.concat(wrong)}

  defp item(at, text) do
    case Regex.run(@item, text) do
      [_, n] ->
        {[String.to_integer(n)], []}

      [_, from, to] ->
        {from, to} = {String.to_integer(from), String.to_integer(to)}

        case from < to do
          true -> {Enum.to_list(from..to), []}
          false -> {[], ["line #{at}: the range `#{text}` does not rise"]}
        end

      nil ->
        {[], ["line #{at}: `#{text}` is neither a decision's number nor a range `N–M`"]}
    end
  end

  # §7's decisions: each line `N. **` from its heading to the next `## ` heading.
  defp recorded(text) do
    text
    |> String.split("\n")
    |> Enum.drop_while(&(not String.starts_with?(&1, "## 7. ")))
    |> Enum.drop(1)
    |> Enum.take_while(&(not String.starts_with?(&1, "## ")))
    |> Enum.flat_map(&(Regex.run(~r/^(\d+)\. \*\*/, &1, capture: :all_but_first) || []))
    |> Enum.map(&String.to_integer/1)
  end

  defp unreleased([_ | older]) do
    for %{at: at, release: :unreleased} <- older do
      "line #{at}: `## Unreleased` stands above the newest release, not below it"
    end
  end

  defp unreleased([]), do: ["CHANGELOG.md has no entry"]

  defp twice(entries) do
    versions =
      for %{release: version, at: at} <- entries, is_binary(version), do: {version, at}

    decisions = for %{numbers: numbers, line: line} <- entries, n <- numbers, do: {n, line}

    dup(versions, &"version #{&1} heads two entries, at lines #{&2}") ++
      dup(decisions, &"decision #{&1} is named twice, by the entries at lines #{&2}")
  end

  defp dup(pairs, message) do
    pairs
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_, ats} -> length(ats) > 1 end)
    |> Enum.sort()
    |> Enum.map(fn {key, ats} -> message.(key, Enum.join(ats, " and ")) end)
  end

  defp named(entries, recorded) do
    named = entries |> Enum.flat_map(& &1.numbers) |> MapSet.new()
    recorded = MapSet.new(recorded)
    missing = recorded |> MapSet.difference(named) |> ranges()
    unknown = named |> MapSet.difference(recorded) |> ranges()

    Enum.map(missing, &"decision #{&1} is recorded in §7 and named by no entry") ++
      Enum.map(unknown, &"decision #{&1} is named by an entry and recorded nowhere in §7")
  end

  # Numbers as runs, `[1, 2, 3, 7]` as `["1–3", "7"]`.
  defp ranges(set) do
    set
    |> Enum.sort()
    |> Enum.chunk_while([], &run/2, &{:cont, Enum.reverse(&1), []})
    |> Enum.reject(&(&1 == []))
    |> Enum.map(&spell/1)
  end

  defp run(n, [last | _] = acc) when n == last + 1, do: {:cont, [n | acc]}
  defp run(n, []), do: {:cont, [n]}
  defp run(n, acc), do: {:cont, Enum.reverse(acc), [n]}

  defp spell([n]), do: "#{n}"
  defp spell([first | rest]), do: "#{first}–#{List.last(rest)}"

  defp release(["--release"], [%{release: :unreleased, at: at} | _]) do
    [
      "line #{at}: the newest entry is `## Unreleased`; a release names its version and " <>
        "date, `## X.Y.Z — YYYY-MM-DD`, the version mix.exs's"
    ]
  end

  defp release(["--release"], [%{release: version, at: at} | _]) when is_binary(version) do
    case mix_version() do
      ^version ->
        []

      other ->
        ["line #{at}: the newest entry is #{version}, and mix.exs's version is #{other}"]
    end
  end

  defp release(_, _), do: []

  defp mix_version do
    Mix.start()
    Mix.Project.in_project(:logex, ".", fn _ -> Mix.Project.config()[:version] end)
  end

  defp report([], ["--release"], [%{release: version} | _], _), do: IO.puts(version)

  defp report([], [], _, recorded) do
    IO.puts("changelog: every decision of §7, #{Enum.join(ranges(recorded), ", ")}, named once")
  end

  defp report(refusals, _, _, _) do
    Enum.each(refusals, &IO.puts(:stderr, "changelog: " <> &1))
    System.halt(1)
  end
end

case System.argv() do
  args when args in [[], ["--release"]] ->
    Changelog.main(args)

  _ ->
    IO.puts(:stderr, "usage: elixir scripts/changelog.exs [--release]")
    System.halt(2)
end
