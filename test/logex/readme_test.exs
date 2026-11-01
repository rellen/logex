defmodule Logex.ReadmeTest.Examples do
  @moduledoc false

  # README's examples as data. An example is an `elixir` block followed at once by a block
  # that begins `$ mix run <script>`, the rest of which is what the script prints. A block
  # a script reads from the disk is marked by the line straight above its fence,
  # `<!-- file: <path> -->`, which GitHub does not show: from there on it is that file of
  # every later example, until a later block marked with the same path replaces it.

  @readme Path.expand("../../README.md", __DIR__)
  @mark ~r/^\s*<!-- file: (\S+) -->\s*$/
  @fence ~r/^(\s*)```(\w*)\s*$/
  @run ~r/\A\$ mix run (\S+)\n/

  # The files README describes in its prose rather than shows, each made from a file it
  # shows, by replacing text, beside the words of README that describe it, which the test
  # finds there. `wired.logex` is `tally.logex` without its comment line, which puts the
  # connection its warning cites on line 7, as README prints it (provisional: README does
  # not say the comment goes).
  @derived [
    {"wired.logex", "tally.logex", :uncommented,
     [
       {"var_global case_full          bool", "var_global case_lamp          bool at panel.q.0"},
       {"t1.full case_full", "t1.full case_lamp"}
     ], "loads `wired.logex`, the same plant with\n`full` wired to an output point"},
    {"faster/packing.logex", "packing.logex", :as_is, [{"interval 10", "interval 5"}],
     "`faster/packing.logex`\nbeing `packing.logex` with `interval 5`"},
    {"faster/conveyor.ld", "conveyor.ld", :as_is, [], "`faster/packing.logex`"},
    {"faster/boxes.ld", "boxes.ld", :as_is, [], "`faster/packing.logex`"},
    {"warm/packing.logex", "packing.logex", :as_is, [],
     "runs the same plant from `warm/packing.logex`"},
    {"warm/conveyor.ld", "conveyor.ld", :as_is, [], "`warm/packing.logex`"},
    {"warm/boxes.ld", "boxes.ld", :as_is, [{"var boxes ctu", "var retain boxes ctu"}],
     "beside `warm/boxes.ld`,\nwhich is `boxes.ld` with its counter declared `var retain boxes ctu`"},
    {"boxes_v2.ld", "boxes.ld", :as_is, [{"ctu boxes 3", "ctu boxes 5"}],
     "boxes_v2.ld is boxes.ld with `ctu boxes 5`"},
    {"moved/trip.logex", "v2/trip.logex", :as_is,
     [{"program c1 conveyor with fast", "program c1 conveyor with trip"}],
     "`moved/trip.logex`, that is `v2/trip.logex` with `c1` moved to `trip`"},
    {"moved/conveyor.ld", "v2/conveyor.ld", :as_is, [], "`moved/trip.logex`"}
  ]

  # A script README shows as the continuation of another, its setup up to a line.
  @continues %{
    "a_trip.exs" => {"on_the_clock.exs", "show = fn label", "`a_trip.exs` runs the same plant"}
  }

  # The `elixir` blocks README shows that no `$ mix run` follows, each by its first line:
  # fragments of prose, which the suite parses and does not run (provisional: README shows
  # no output to compare). Every other `elixir` block is an example's script.
  @fragments [
    # "Running a plant on the clock": a call made from another process while the clock is
    # moved on, which needs a round owed after a slow write to show its wait.
    ~S|task = Task.async(fn -> Runner.get!(runner, "b1.count") end)|
  ]

  # The lines of a script's output that README says are this run's alone, compared by
  # their beginning: "The keyword list is the same on every run; the figures are this
  # run's" (decision 364: no figure is held to a range).
  @varies %{"on_the_real_clock.exs" => "this run's figures: "}

  def readme, do: File.read!(@readme)
  def derived, do: @derived
  def continues, do: @continues
  def fragments, do: @fragments

  # Each `elixir` block no `$ mix run` follows, `{line, first line, body}`.
  def unrun do
    blocks = readme() |> String.split("\n") |> blocks(1, nil, [])

    for {{n, "elixir", body, nil}, next} <- Enum.zip(blocks, tl(blocks) ++ [nil]),
        not runs?(next),
        do: {n, hd(String.split(body, "\n")), body}
  end

  defp runs?({_n, "", body, nil}), do: Regex.match?(@run, body)
  defp runs?(_block), do: false

  def all do
    text = readme()
    examples = text |> String.split("\n") |> blocks(1, nil, []) |> examples()
    by_name = Map.new(examples, &{&1.name, &1})
    for example <- examples, do: continued(Map.get(@continues, example.name), example, by_name)
  end

  # Each fenced block in order, `{line, lang, body, mark}`, `mark` the path the line
  # above it names, or nil.
  defp blocks([], _n, _mark, acc), do: Enum.reverse(acc)

  defp blocks([line | rest], n, mark, acc),
    do: block(kind(Regex.run(@mark, line), Regex.run(@fence, line)), rest, n, mark, acc)

  defp kind([_, path], _), do: {:mark, path}
  defp kind(nil, [_, indent, lang]), do: {:fence, indent, lang}
  defp kind(nil, nil), do: :text

  defp block({:mark, path}, rest, n, _mark, acc), do: blocks(rest, n + 1, path, acc)
  defp block(:text, rest, n, _mark, acc), do: blocks(rest, n + 1, nil, acc)

  defp block({:fence, indent, lang}, rest, n, mark, acc) do
    {body, [_closing | after_block]} = Enum.split_while(rest, &(String.trim(&1) != "```"))
    text = Enum.map_join(body, "\n", &String.replace_prefix(&1, indent, "")) <> "\n"
    blocks(after_block, n + length(body) + 2, nil, [{n, lang, text, mark} | acc])
  end

  defp examples(blocks) do
    {_files, _previous, examples} = Enum.reduce(blocks, {%{}, nil, []}, &step/2)
    Enum.reverse(examples)
  end

  defp step({_n, _lang, body, path} = block, {files, _previous, examples})
       when is_binary(path),
       do: {Map.put(files, path, body), block, examples}

  defp step({n, "", body, nil} = block, {files, previous, examples}),
    do: run(Regex.run(@run, body), block, {files, previous, examples}, n)

  defp step(block, {files, _previous, examples}), do: {files, block, examples}

  defp run(nil, block, {files, _previous, examples}, _n), do: {files, block, examples}

  defp run([shown, name], {_, _, body, _} = block, {files, previous, examples}, n) do
    example = %{
      name: name,
      line: n,
      script: script(previous, name),
      files: with_derived(files),
      expected: String.replace_prefix(body, shown, "")
    }

    {files, block, [example | examples]}
  end

  defp script({_n, "elixir", body, nil}, _name), do: body

  defp script(previous, name),
    do: raise("README: `$ mix run #{name}` follows #{inspect(previous)}, not its script")

  defp with_derived(files) do
    made =
      for {path, from, how, edits, _words} <- @derived,
          Map.has_key?(files, from),
          into: %{},
          do: {path, Enum.reduce(edits, kept(how, files[from]), &edited/2)}

    Map.merge(files, made)
  end

  defp kept(:as_is, text), do: text

  defp kept(:uncommented, text),
    do:
      text |> String.split("\n") |> Enum.reject(&String.starts_with?(&1, "//")) |> Enum.join("\n")

  defp edited({old, new}, text), do: String.replace(text, old, new, global: false)

  defp continued(nil, example, _by_name), do: example

  defp continued({from, cut, _words}, example, by_name) do
    [setup | _] = String.split(Map.fetch!(by_name, from).script, cut)
    %{example | script: setup <> example.script}
  end

  # What a script prints, its lines README says are this run's cut to their beginning.
  def comparable(output, name), do: varies(Map.get(@varies, name), output)

  defp varies(nil, output), do: output

  defp varies(prefix, output),
    do: Regex.replace(~r/^#{Regex.escape(prefix)}.*$/m, output, prefix)
end

defmodule Logex.ReadmeTest do
  @moduledoc """
  README's examples, each run as README runs it and its output compared with what README
  prints (decision 359). Each example's files are written to a directory of its own under
  `tmp/readme/`, its script beside them, and the script run in a fresh VM by the `elixir`
  the suite runs on, with this build's code on its path, as `mix run` runs it; what it
  prints on standard output must be README's text exactly, but for the lines README says
  are this run's alone, compared by their beginning, and it must exit 0. Each example is a
  test module of its own, `Logex.ReadmeTest.Scan` for `scan.exs`, so that the examples
  run side by side and a failure is named by its example.
  """
  import ExUnit.Assertions
  alias Logex.ReadmeTest.Examples

  @root Path.expand("../..", __DIR__)
  # The `elixir` beside the Elixir the suite runs on, or else the one on the path.
  @elixir Enum.find(
            [
              Path.expand(Path.join([:code.lib_dir(:elixir), "..", "..", "bin", "elixir"])),
              System.find_executable("elixir")
            ],
            &File.exists?(to_string(&1))
          )

  def check(example) do
    dir = Path.join([@root, "tmp", "readme", example.name])
    File.rm_rf!(dir)

    for {path, text} <- example.files do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.write!(Path.join(dir, path), text)
    end

    File.write!(Path.join(dir, example.name), example.script)

    {output, status} =
      System.cmd(@elixir, ["-pa", Mix.Project.compile_path(), example.name], cd: dir)

    assert status == 0, "README.md line #{example.line}: #{example.name} exited #{status}"

    assert Examples.comparable(output, example.name) ==
             Examples.comparable(example.expected, example.name),
           "README.md line #{example.line}: #{example.name} printed otherwise"
  end
end

for example <- Logex.ReadmeTest.Examples.all() do
  defmodule Module.concat(Logex.ReadmeTest, Macro.camelize(Path.rootname(example.name))) do
    @moduledoc false
    use ExUnit.Case, async: true
    @example example

    test "README's #{@example.name} prints what README shows" do
      Logex.ReadmeTest.check(@example)
    end
  end
end

defmodule Logex.ReadmeTest.Extraction do
  @moduledoc false
  alias Logex.ReadmeTest.Examples
  use ExUnit.Case, async: true

  # What the examples are made of is README's own: each file README describes in its
  # prose is still described there, each script that continues another still says so,
  # and every example README runs is found.
  test "README still describes each file and script the examples make of its prose" do
    readme = Examples.readme()

    for {path, _from, _how, _edits, words} <- Examples.derived(),
        do: assert(readme =~ words, "README no longer says #{inspect(words)} of #{path}")

    for {name, {_from, _cut, words}} <- Examples.continues(),
        do: assert(readme =~ words, "README no longer says #{inspect(words)} of #{name}")
  end

  # An `elixir` block README shows with no `$ mix run` after it is never run, so each is
  # a fragment named in `@fragments`, which must still parse, or the test says which.
  test "every `elixir` block README shows is an example's script or a named fragment" do
    unrun = Examples.unrun()

    for {n, first, _body} <- unrun,
        do:
          assert(
            first in Examples.fragments(),
            "README.md line #{n}: an `elixir` block no `$ mix run` follows, so the suite " <>
              "never runs it: show what it prints, or name it in @fragments"
          )

    assert Examples.fragments() -- Enum.map(unrun, &elem(&1, 1)) == [],
           "a fragment @fragments names is no longer in README"

    for {n, _first, body} <- unrun,
        do: assert(match?({:ok, _}, Code.string_to_quoted(body)), "README.md line #{n}")
  end

  test "every `$ mix run` README shows is an example, and every file a mark names is one" do
    readme = Examples.readme()
    shown = for [_, name] <- Regex.scan(~r/^\s*\$ mix run (\S+)$/m, readme), do: name
    assert Enum.map(Examples.all(), & &1.name) == shown
    refute shown == []

    marked = for [_, path] <- Regex.scan(~r/^\s*<!-- file: (\S+) -->$/m, readme), do: path
    last = List.last(Examples.all())
    assert Enum.uniq(marked) -- Map.keys(last.files) == []
  end
end
