defmodule Logex.ReadmeTest.Examples do
  @moduledoc false

  # The pages' examples as data (decision 546 (e)): README.md and every page of
  # docs/pages.exs that is not a legacy document, each read on its own and judged on what
  # it shows. An example is an `elixir` block followed at once by a block that begins
  # `$ mix run <script>`, the rest of which is what the script prints. A block a script
  # reads from the disk is marked by the line straight above its fence,
  # `<!-- file: <path> -->`, which GitHub does not show: from there on it is that file of
  # every later example of its page. A file another page shows is given to a page's later
  # examples by a link the reader sees, its text the file's name in a code span and its
  # target the page that shows it, ``[`conveyor.ld`](first-plant.md)``: the reader is told
  # which file to have and where it is. A file may be shown on more than one page, each
  # block held to the file, and marked once on a page.
  #
  # Three more marks say what a block is. `<!-- part of: <path> -->`: a run of whole lines
  # of that file under examples/, held to it, and given to no example. `<!-- fragment:
  # <why> -->`: an `elixir` block no `$ mix run` follows, which must parse. `<!--
  # unchecked: <why> -->`: a block no test holds, a message or a form of the syntax. On a
  # page under the writing rules every block is an example's, carries a mark, or is of a
  # language of `@shown`, which the suite does not hold: so no block is shown unheld by
  # accident.

  @root Path.expand("../..", __DIR__)
  # Decision 517 (b): where the pages' examples are shipped, each a file a host can copy.
  @examples Path.expand("../../examples", __DIR__)
  @mark ~r/^\s*<!-- (file|part of|fragment|unchecked): (\S.*?) -->\s*$/
  @fence ~r/^(\s*)(`{3,})(\w*)\s*$/
  @run ~r/\A\$ mix run (\S+)\n/
  @needs ~r/\[`([^`\]]+)`\]\(([^)#\s]+\.(?:md|cheatmd))(?:#[^)\s]*)?\)/
  # The languages of a block the suite does not hold: a command line, a diagram, Markdown
  # shown as Markdown, and data of another tool.
  @shown ["console", "mermaid", "markdown", "yaml", "json", "diff"]

  # The files a page describes in its prose rather than shows, each made from a file it
  # shows, by replacing text, beside the words of the page that describe it, which the test
  # finds there: a page that shows the file and says the words is given the file made.
  # Since decision 363 `wired.logex` is no longer one: README shows it, its warning citing
  # a line README shows.
  @derived [
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

  # A script a page shows as the continuation of another of the same page, its setup up
  # to a line.
  @continues %{
    "a_trip.exs" => {"on_the_clock.exs", "show = fn label", "`a_trip.exs` runs the same plant"}
  }

  # "Running a plant on the clock": the state its fragment's prose describes, a runner on
  # the manual clock with a round owed after a slow drive's write, the first round's, and
  # a count, kept by a process of its own, of the fragment's advances of the clock.
  @owed ~S"""
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual
  alias Logex.IO.Sim

  {:ok, plant} = Logex.Configuration.compile_file("packing.logex")
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)
  Sim.fail(panel, :write, {:delay, 2})

  {:ok, runner} =
    Runner.start_link(
      configuration: plant,
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock}
    )

  counted = fn counted, n ->
    receive do
      {:trace, _pid, :call, {Manual, :advance, [_clock, 0]}} -> counted.(counted, n + 1)
      {:count, from} -> send(from, {:advances, n})
    end
  end

  counter = spawn(fn -> counted.(counted, 0) end)
  1 = :erlang.trace_pattern({Manual, :advance, 2}, true, [:global])
  1 = :erlang.trace(self(), true, [:call, {:tracer, counter}])
  """

  # Held to the prose: the call waited for an owed round, so the fragment moved the clock
  # on at least once, and at most four times ("at most 4 bring the slot"), and then it was
  # answered, with the count.
  @answered ~S"""
  :erlang.trace(self(), false, [:call])
  send(counter, {:count, self()})
  advances = receive(do: ({:advances, n} -> n))
  held = fn n when n in 1..4 -> "after 1 to 4 owed rounds"; n -> "after #{n} owed rounds" end
  IO.puts("b1.count waited, then answered #{inspect(value)} #{held.(advances)}")
  """

  # The `elixir` blocks a page shows that no `$ mix run` follows, each by its page and its
  # first line: fragments of prose, each parsed, and since decision 365 run where the test
  # makes the state its prose describes, `{example, setup, check, prints, words}`: the
  # setup the test writes, then the fragment, its last value bound to `value`, then the
  # check, run beside the files of the example of its page it continues, as an example
  # is, the check printing `prints` where the fragment does what the prose says, which
  # the page still says, `words`. A fragment the test gives no setup is named in its page,
  # by a `fragment` mark, and parsed. Every other `elixir` block is an example's script.
  @fragments [
    {"README.md", ~S|task = Task.async(fn -> Runner.get!(runner, "b1.count") end)|,
     {"on_the_clock.exs", @owed, @answered,
      "b1.count waited, then answered 0 after 1 to 4 owed rounds\n",
      "One made while a round is owed, after a round\n  that passed time, a slow drive's " <>
        "write, waits for its slot"}}
  ]

  # The lines of a script's output that its page says are this run's alone, compared by
  # their beginning: "The keyword list is the same on every run; the figures are this
  # run's" (decision 364: no figure is held to a range).
  @varies %{"on_the_real_clock.exs" => "this run's figures: "}

  # An example on the machine's clock runs alone, after every async module of the suite,
  # so that no other example's VM and no other test runs beside its rounds (RV-9's
  # review: CI's red run of `on_the_real_clock.exs` beside the fragment's VM); every other
  # example runs beside the rest.
  def async?("on_the_real_clock.exs"), do: false
  def async?(_name), do: true

  def dir, do: @examples
  def derived, do: @derived
  def continues, do: @continues
  def fragments(path), do: for({^path, first, _run} <- @fragments, do: first)
  def shown, do: @shown

  # The pages the test reads: README.md, and every page docs/pages.exs lists that is not
  # a legacy document.
  def pages do
    {listed, _} = Code.eval_file(Path.join(@root, "docs/pages.exs"))

    for {path, kind, _group} <- listed,
        read?(path, kind),
        do: page(path, kind, File.read!(Path.join(@root, path)))
  end

  # A page as the test reads it: its path, its kind, its text and its blocks.
  def page(path, kind, text),
    do: %{
      path: path,
      kind: kind,
      text: text,
      blocks: read(String.split(text, "\n"), 1, nil, [], path)
    }

  defp read?("README.md", _kind), do: true
  defp read?(_path, kind), do: kind != :legacy

  # A page's name as a module's, `GuidesTutorialsFirstProgram`, and as a directory's.
  def module(path),
    do: path |> Path.rootname() |> String.split(~r/[^A-Za-z0-9]+/, trim: true) |> module_name()

  defp module_name(words), do: Enum.map_join(words, &Macro.camelize(String.downcase(&1)))

  def slug(path), do: String.replace(path, ~r/[^A-Za-z0-9.]+/, "_")

  # An example's or a fragment's test module under `Logex.ReadmeTest`, its page's name
  # and its own: `Readme.OnTheClock`, `Readme.OnTheClockFragment3790`.
  def named(%{page: page, name: name}),
    do: module(page) <> "." <> Macro.camelize(String.replace(Path.rootname(name), ".", "_"))

  # Decision 365: each fragment the suite runs, as an example, named after the example it
  # continues, `on_the_clock.fragment_3790.exs` for the one at its page's line 3790.
  def run_fragments(pages \\ pages()) do
    examples = all(pages)

    for page <- pages,
        {n, first, body} <- unrun(page),
        {from, setup, check, prints, words} <- setups(page.path, first),
        do: %{
          page: page.path,
          name: "#{Path.rootname(from)}.fragment_#{n}.exs",
          line: n,
          run: :made,
          script: setup <> "\nvalue = (\n" <> body <> ")\n\n" <> check,
          files: Enum.find(examples, &(&1.page == page.path and &1.name == from)).files,
          expected: prints,
          words: words
        }
  end

  defp setups(path, first), do: for({^path, ^first, run} <- @fragments, do: run)

  # Each `elixir` block of a page no `$ mix run` follows and no `file` or `part of` mark
  # holds, `{line, first line, body}`.
  def unrun(page) do
    blocks = fenced(page.blocks)

    for {{n, "elixir", body, mark}, next} <- Enum.zip(blocks, tl(blocks) ++ [nil]),
        mark == nil or match?({"fragment", _}, mark),
        not runs?(next),
        do: {n, hd(String.split(body, "\n")), body}
  end

  # The `elixir` blocks of a page that carry a `fragment` mark, by their first line.
  def marked(page) do
    for {_n, "elixir", body, {"fragment", _why}} <- page.blocks,
        do: hd(String.split(body, "\n"))
  end

  defp runs?({_n, lang, body, nil}) when lang in ["", "console"], do: Regex.match?(@run, body)
  defp runs?(_block), do: false

  # A page's fenced blocks alone, its links to other pages' files left out.
  defp fenced(blocks),
    do: for({_n, lang, _body, _mark} = block <- blocks, is_binary(lang), do: block)

  # Every example of every page, in the pages' order and each page's own.
  def all(pages \\ pages()) do
    shown = Map.new(pages, &{&1.path, files(&1)})
    Enum.flat_map(pages, &of(&1, shown))
  end

  # A page's examples.
  def of(page, shown) do
    {_files, _previous, examples} =
      Enum.reduce(page.blocks, {%{}, nil, []}, &step(&1, &2, page, shown))

    examples = Enum.reverse(examples)
    by_name = Map.new(examples, &{&1.name, &1})
    for example <- examples, do: continued(Map.get(@continues, example.name), example, by_name)
  end

  # The files a page shows, each block a `file` mark names, by path.
  def files(page),
    do: for({_n, _lang, body, {"file", path}} <- page.blocks, into: %{}, do: {path, body})

  # The files a page has by its end: those it shows, those it links to on the pages that
  # show them, and those its prose describes, made.
  def held(page, pages) do
    shown = Map.new(pages, &{&1.path, files(&1)})

    {files, _previous, _examples} =
      Enum.reduce(page.blocks, {%{}, nil, []}, &step(&1, &2, page, shown))

    with_derived(files, page.text)
  end

  # Each fenced block of a page in order, `{line, lang, body, mark}`, `mark` what the line
  # above it says of it, `{"file", path}` for one, or nil; and among them each link to a
  # file another page shows, `{line, :needs, file, page}`. A fence of four backticks or
  # more closes at its like, so that a block of Markdown that shows a fence is one block.
  defp read([], _n, _mark, acc, _path), do: Enum.reverse(acc)

  defp read([line | rest], n, mark, acc, path),
    do:
      block(kind(Regex.run(@mark, line), Regex.run(@fence, line)), line, rest, n, mark, acc, path)

  defp kind([_, what, value], _), do: {:mark, {what, value}}
  defp kind(nil, [_, indent, ticks, lang]), do: {:fence, indent, ticks, lang}
  defp kind(nil, nil), do: :text

  defp block({:mark, mark}, _line, rest, n, _mark, acc, path),
    do: read(rest, n + 1, mark, acc, path)

  defp block(:text, line, rest, n, _mark, acc, path),
    do: read(rest, n + 1, nil, needs(line, n, path) ++ acc, path)

  defp block({:fence, indent, ticks, lang}, _line, rest, n, mark, acc, path) do
    {body, [_closing | after_block]} = Enum.split_while(rest, &(String.trim(&1) != ticks))
    text = Enum.map_join(body, "\n", &String.replace_prefix(&1, indent, "")) <> "\n"
    read(after_block, n + length(body) + 2, nil, [{n, lang, text, mark} | acc], path)
  end

  # The links of a line whose text is a shipped file's name, in a code span, and whose
  # target is a page: the file, and the page as the repository names it.
  defp needs(line, n, path) do
    for [_, file, target] <- Enum.reverse(Regex.scan(@needs, line)),
        File.regular?(Path.join(@examples, file)),
        do: {n, :needs, file, resolved(path, target)}
  end

  defp resolved(path, target),
    do: Path.relative_to(Path.expand(Path.join(Path.dirname(path), target), "/"), "/")

  defp step(
         {_n, _lang, body, {"file", path}} = block,
         {files, _previous, examples},
         _page,
         _shown
       ),
       do: {Map.put(files, path, body), block, examples}

  defp step({_n, :needs, file, from}, {files, previous, examples}, _page, shown),
    do: {needed(files, file, get_in(shown, [from, file])), previous, examples}

  defp step({n, lang, body, nil} = block, {files, previous, examples}, page, _shown)
       when lang in ["", "console"],
       do: run(Regex.run(@run, body), block, {files, previous, examples}, n, page)

  defp step(block, {files, _previous, examples}, _page, _shown), do: {files, block, examples}

  # A file its page shows is given; one it does not show is not, and `problems/1` says so.
  defp needed(files, _file, nil), do: files
  defp needed(files, file, text), do: Map.put(files, file, text)

  defp run(nil, block, {files, _previous, examples}, _n, _page), do: {files, block, examples}

  defp run([shown, name], {_, _, body, _} = block, {files, previous, examples}, n, page),
    do: {files, block, example(script(previous), shown, name, body, files, n, page) ++ examples}

  # The script a `$ mix run` follows, or none: `problems/1` says so.
  defp script({_n, "elixir", body, nil}), do: body
  defp script(_previous), do: nil

  defp example(nil, _shown, _name, _body, _files, _n, _page), do: []

  defp example(script, shown, name, body, files, n, page) do
    [
      %{
        page: page.path,
        name: name,
        line: n,
        run: :shipped,
        script: script,
        files: with_derived(files, page.text),
        expected: String.replace_prefix(body, shown, "")
      }
    ]
  end

  defp with_derived(files, text) do
    made =
      for {path, from, how, edits, words} <- @derived,
          Map.has_key?(files, from),
          text =~ words,
          into: %{},
          do: {path, Enum.reduce(edits, kept(how, files[from]), &edited/2)}

    Map.merge(files, made)
  end

  defp kept(:as_is, text), do: text

  defp edited({old, new}, text), do: String.replace(text, old, new, global: false)

  defp continued(nil, example, _by_name), do: example

  defp continued({from, cut, _words}, example, by_name) do
    [setup | _] = String.split(Map.fetch!(by_name, from).script, cut)
    %{example | script: setup <> example.script}
  end

  # What is wrong with the pages' marks and blocks, each `<page>:<line>: ...`: what a set
  # of pages can get wrong that one file could not, and what a writer can forget.
  def problems(pages \\ pages()) do
    shown = Map.new(pages, &{&1.path, files(&1)})
    Enum.flat_map(pages, &problems(&1, shown))
  end

  defp problems(page, shown) do
    blocks = page.blocks

    Enum.flat_map(blocks, &problem(&1, page, shown)) ++
      twice(page, blocks) ++ unscripted(page, blocks) ++ unheld(page.kind, page, blocks)
  end

  defp problem({n, :needs, file, from}, page, shown),
    do: unshown(Map.has_key?(shown, from), get_in(shown, [from, file]), n, file, from, page)

  defp problem({n, _lang, body, {"part of", path}}, page, _shown),
    do: part(File.read(Path.join(@examples, path)), body, n, path, page)

  defp problem({n, lang, _body, {"fragment", _why}}, page, _shown) when lang != "elixir",
    do: [
      "#{page.path}:#{n}: a `fragment` mark is for an `elixir` block, and this one is `#{lang}`"
    ]

  defp problem(_block, _page, _shown), do: []

  defp unshown(false, _text, n, file, from, page),
    do: ["#{page.path}:#{n}: `#{file}` is linked to #{from}, which is no page the suite reads"]

  defp unshown(true, nil, n, file, from, page) do
    [
      "#{page.path}:#{n}: `#{file}` is linked to #{from}, which does not show it: link it to " <>
        "the page that shows it under `<!-- file: #{file} -->`, or show it here"
    ]
  end

  defp unshown(true, _text, _n, _file, _from, _page), do: []

  defp part({:ok, file}, body, n, path, page),
    do: apart(String.contains?("\n" <> file, "\n" <> body), n, path, page)

  defp part({:error, _}, _body, n, path, page),
    do: ["#{page.path}:#{n}: a part of `#{path}`, which is not under examples/"]

  defp apart(true, _n, _path, _page), do: []

  defp apart(false, n, path, page),
    do: ["#{page.path}:#{n}: this block is not a run of whole lines of examples/#{path}"]

  # A path a page marks twice: one directory holds a page's files.
  defp twice(page, blocks) do
    marks = for {n, _lang, _body, {"file", path}} <- blocks, do: {path, n}

    for {path, n} <- marks -- Enum.uniq_by(marks, &elem(&1, 0)),
        do: "#{page.path}:#{n}: `#{path}` is marked twice on this page"
  end

  # A `$ mix run` that does not follow its script.
  defp unscripted(page, blocks) do
    for {previous, {n, lang, body, nil}} <- Enum.zip([nil | fenced(blocks)], fenced(blocks)),
        lang in ["", "console"],
        [_, name] <- [Regex.run(@run, body)],
        script(previous) == nil,
        do: "#{page.path}:#{n}: `$ mix run #{name}` does not follow its script, an `elixir` block"
  end

  # On a page under the writing rules, a block that no test holds and that does not say so.
  defp unheld(:legacy, _page, _blocks), do: []

  defp unheld(_kind, page, blocks) do
    for {n, lang, body, nil} <- blocks,
        is_binary(lang),
        lang not in ["elixir" | @shown],
        not Regex.match?(@run, body),
        do:
          "#{page.path}:#{n}: a `#{lang}` block with no mark: mark it `<!-- file: <path> -->`, " <>
            "`<!-- part of: <path> -->` or `<!-- unchecked: <why> -->` on the line above " <>
            "it, or write its language as one of #{Enum.join(@shown, ", ")}"
  end

  # A page's text with each block of Markdown shown as Markdown taken out: what a `$ mix
  # run` or a mark there says is the page's subject, not the page's own.
  def own(page) do
    shown =
      for {n, "markdown", body, _mark} <- page.blocks,
          do: n..(n + length(String.split(body, "\n")))

    page.text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {_line, n} -> Enum.any?(shown, &(n in &1)) end)
    |> Enum.map_join("\n", &elem(&1, 0))
  end

  # What a script prints, its lines its page says are this run's cut to their beginning.
  def comparable(output, name), do: varies(Map.get(@varies, name), output)

  defp varies(nil, output), do: output

  defp varies(prefix, output),
    do: Regex.replace(~r/^#{Regex.escape(prefix)}.*$/m, output, prefix)
end

defmodule Logex.ReadmeTest do
  @moduledoc """
  The pages' examples (decision 546 (e)), README's and every page's that is not a legacy
  document, each run as its page runs it and its output compared with what the page
  prints (decision 359), from its files under `examples/`, which the pages' blocks are
  held to (decision 517 (b)). Each example's files are copied from there to a directory
  of its own under `tmp/readme/`, so that examples that write a store or a forces file run
  side by side, its script beside them, and the script run in a fresh VM by the `elixir`
  the suite runs on, with this build's code on its path, as `mix run` runs it; what it
  prints on standard output must be the page's text exactly, but for the lines the page
  says are this run's alone, compared by their beginning, and it must exit 0. Each example
  is a test module of its own, `Logex.ReadmeTest.Readme.OnTheClock` for README's
  `on_the_clock.exs`, so that the examples run side by side, a script two pages run is run
  for each, and a failure is named by its page and its example, and shows what the script
  printed beside what the page shows; the one on the machine's clock,
  `on_the_real_clock.exs`, runs alone, after the suite's async modules
  (`Examples.async?/1`).

  Each page's blocks and marks are read by a module of its own too,
  `Logex.ReadmeTest.Reading.Readme`, which runs no script. One page is checked alone by
  its tags:

      mix test test/logex/readme_test.exs --only reading:guides/tutorials/first-program.md
      mix test test/logex/readme_test.exs --only page:guides/tutorials/first-program.md

  the first its blocks against their files, its marks and its fragments, in seconds, the
  second those and its examples, run.
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
    dir = Path.join([@root, "tmp", "readme", Examples.slug(example.page), example.name])
    File.rm_rf!(dir)

    for path <- Map.keys(example.files) do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.cp!(Path.join(Examples.dir(), path), Path.join(dir, path))
    end

    File.write!(Path.join(dir, example.name), script(example))

    {output, status} =
      System.cmd(@elixir, ["-pa", Mix.Project.compile_path(), example.name], cd: dir)

    at = "#{example.page} line #{example.line}: #{example.name}"
    assert status == 0, "#{at} exited #{status}, printing:\n#{output}"

    # Held as a pair with its place, so that a failure shows what the script printed beside
    # what the page shows, and where they differ, which a message of the test's own hid
    # (RV-9's review, CI's run 41358731876).
    assert {at, Examples.comparable(output, example.name)} ==
             {at, Examples.comparable(example.expected, example.name)}
  end

  # Decision 517 (b): an example runs its script as shipped under `examples/`, which the
  # hold below keeps its page's; a fragment the script the test makes of it.
  defp script(%{run: :shipped, name: name}), do: File.read!(Path.join(Examples.dir(), name))
  defp script(%{run: :made, script: script}), do: script

  def elixir, do: @elixir
end

for example <- Logex.ReadmeTest.Examples.all() do
  defmodule Module.concat(Logex.ReadmeTest, Logex.ReadmeTest.Examples.named(example)) do
    @moduledoc false
    use ExUnit.Case, async: Logex.ReadmeTest.Examples.async?(example.name)
    @moduletag page: example.page
    @example example

    test "#{@example.page}'s #{@example.name} prints what the page shows" do
      Logex.ReadmeTest.check(@example)
    end
  end
end

# Decision 365: each fragment the suite runs, in the setup its test makes, a module of its
# own, `Logex.ReadmeTest.Readme.OnTheClockFragment3790`.
for fragment <- Logex.ReadmeTest.Examples.run_fragments() do
  defmodule Module.concat(Logex.ReadmeTest, Logex.ReadmeTest.Examples.named(fragment)) do
    @moduledoc false
    use ExUnit.Case, async: true
    @moduletag page: fragment.page
    @fragment fragment

    test "#{@fragment.page}'s fragment at line #{@fragment.line} does what the page's prose says" do
      Logex.ReadmeTest.check(@fragment)
    end
  end
end

# Decision 517 (b): `examples/` is a project a host runs an example in, as the pages say,
# `mix run scan.exs` from there, logex the directory above; its build is kept under `tmp/`,
# so that the run leaves nothing beside the examples.
defmodule Logex.ReadmeTest.Project do
  @moduledoc false
  alias Logex.ReadmeTest.Examples
  use ExUnit.Case, async: true

  @build Path.expand("../../tmp/readme/_examples_build/dev", __DIR__)

  test "`mix run scan.exs` from examples/ prints what its page shows, logex its dependency" do
    mix = Path.join(Path.dirname(Logex.ReadmeTest.elixir()), "mix")
    env = [{"MIX_ENV", "dev"}, {"MIX_BUILD_PATH", @build}]
    File.rm_rf!(@build)

    {compiled, status} =
      System.cmd(Logex.ReadmeTest.elixir(), [mix, "compile"], cd: Examples.dir(), env: env)

    assert status == 0, compiled

    {output, status} =
      System.cmd(Logex.ReadmeTest.elixir(), [mix, "run", "scan.exs"],
        cd: Examples.dir(),
        env: env
      )

    assert status == 0, output
    assert output == Enum.find(Examples.all(), &(&1.name == "scan.exs")).expected
  end
end

# Each page's blocks and marks, read with no script run, a module a page:
# `mix test test/logex/readme_test.exs --only reading:<page>` checks one page in seconds.
for page <- Logex.ReadmeTest.Examples.pages() do
  defmodule Module.concat(Logex.ReadmeTest.Reading, Logex.ReadmeTest.Examples.module(page.path)) do
    @moduledoc false
    alias Logex.ReadmeTest.Examples
    use ExUnit.Case, async: true
    @moduletag page: page.path
    @moduletag reading: page.path
    @path page.path

    defp page, do: Enum.find(Examples.pages(), &(&1.path == @path))
    defp examples, do: Enum.filter(Examples.all(), &(&1.page == @path))

    # What the examples are made of is the page's own: each file the page's examples are
    # given that its prose describes is still described there, and each script that
    # continues another still says so.
    test "#{@path} still describes each file and script the examples make of its prose" do
      text = page().text
      held = Examples.held(page(), Examples.pages())

      for {path, _from, _how, _edits, words} <- Examples.derived(),
          Map.has_key?(held, path),
          do: assert(text =~ words, "#{@path} no longer says #{inspect(words)} of #{path}")

      for %{name: name} <- examples(),
          {_from, _cut, words} <- [Map.get(Examples.continues(), name)],
          do: assert(text =~ words, "#{@path} no longer says #{inspect(words)} of #{name}")

      for %{page: @path, name: name, words: words} <- Examples.run_fragments(),
          do: assert(text =~ words, "#{@path} no longer says #{inspect(words)} of #{name}")
    end

    # An `elixir` block a page shows with no `$ mix run` after it is never run as an
    # example, so each is a fragment, named in `@fragments` with its setup or by a
    # `fragment` mark in its page, which must still parse, or the test says which.
    test "every `elixir` block #{@path} shows is an example's script or a named fragment" do
      unrun = Examples.unrun(page())
      named = Examples.fragments(@path) ++ Examples.marked(page())

      for {n, first, _body} <- unrun,
          do:
            assert(
              first in named,
              "#{@path} line #{n}: an `elixir` block no `$ mix run` follows, so the suite " <>
                "never runs it: show what it prints, name it in @fragments with its " <>
                "setup, or mark it `<!-- fragment: <why> -->`"
            )

      assert Examples.fragments(@path) -- Enum.map(unrun, &elem(&1, 1)) == [],
             "a fragment @fragments names is no longer in #{@path}"

      for {n, _first, body} <- unrun,
          do: assert(match?({:ok, _}, Code.string_to_quoted(body)), "#{@path} line #{n}")
    end

    # Decision 517 (b): the pages' examples are shipped as files under `examples/`, each
    # block a page shows its file there, each file a page describes made as the test makes
    # it, and each script a page shows as the rest of another there whole.
    test "each file and script #{@path} shows is its file under examples/" do
      shown =
        Map.merge(
          Examples.held(page(), Examples.pages()),
          Map.new(examples(), &{&1.name, &1.script})
        )

      for {path, text} <- shown,
          at = "#{@path}: #{path}",
          do: assert({at, File.read(Path.join(Examples.dir(), path))} == {at, {:ok, text}})
    end

    test "every `$ mix run` #{@path} shows is an example, and every file a mark names is one" do
      own = Examples.own(page())
      shown = for [_, name] <- Regex.scan(~r/^\s*\$ mix run (\S+)$/m, own), do: name
      assert Enum.map(examples(), & &1.name) == shown

      marked = for [_, path] <- Regex.scan(~r/^\s*<!-- file: (\S+) -->$/m, own), do: path
      assert Enum.uniq(marked) -- Map.keys(Examples.files(page())) == []
    end

    # What a set of pages can get wrong that one file could not, and what a writer can
    # forget: a link to a file on a page that does not show it, a path marked twice, a
    # part that is not its file's, a `$ mix run` with no script, and on a page under the
    # writing rules a block no test holds that does not say so.
    test "#{@path}'s marks and blocks are sound, each block held or said not to be" do
      assert Enum.filter(Examples.problems(), &String.starts_with?(&1, @path <> ":")) == []
    end
  end
end

defmodule Logex.ReadmeTest.Extraction do
  @moduledoc false
  alias Logex.ReadmeTest.Examples
  use ExUnit.Case, async: true

  test "README is read, and with it every page of docs/pages.exs that is not a legacy document" do
    {listed, _} = Code.eval_file(Path.expand("../../docs/pages.exs", __DIR__))
    read = Enum.map(Examples.pages(), & &1.path)
    assert "README.md" in read

    assert read ==
             for({path, kind, _} <- listed, path == "README.md" or kind != :legacy, do: path)

    refute Examples.all() == []
  end

  # What the examples are made of is some page's own: each file the test makes of a
  # page's prose, each script it continues and each fragment it runs is still a page's.
  test "each file, script and fragment the test makes of prose is still some page's" do
    pages = Examples.pages()
    examples = Examples.all()
    held = Enum.flat_map(pages, &Map.keys(Examples.held(&1, pages)))

    for {path, _from, _how, _edits, _words} <- Examples.derived(),
        do: assert(path in held, "no page describes #{path} any longer")

    for {name, {from, _cut, _words}} <- Examples.continues(),
        do:
          assert(
            Enum.any?(examples, &(&1.name == name)) and Enum.any?(examples, &(&1.name == from)),
            "no page runs #{name} as the rest of #{from} any longer"
          )
  end

  # Decision 365: every fragment `@fragments` gives a setup is found in its page and run.
  test "README's fragment of a call that waits for an owed round is run, not parsed alone" do
    assert [%{page: "README.md", name: "on_the_clock.fragment_" <> _, script: script}] =
             Examples.run_fragments()

    assert script =~ ~S|task = Task.async(fn -> Runner.get!(runner, "b1.count") end)|
  end

  # Decision 517 (b): `examples/` holds each file and script some page shows or describes,
  # and nothing else but the project they run in: a file no page shows is refused.
  test "examples/ holds the files and scripts the pages show, and no other" do
    pages = Examples.pages()

    shown =
      Enum.flat_map(pages, &Map.keys(Examples.held(&1, pages))) ++
        Enum.map(Examples.all(), & &1.name)

    on_disk =
      for path <- Path.wildcard(Path.join(Examples.dir(), "**"), match_dot: true),
          File.regular?(path),
          relative <- [Path.relative_to(path, Examples.dir())],
          not String.starts_with?(relative, ["_build/", "deps/"]),
          do: relative

    assert Enum.sort(on_disk) == Enum.sort(Enum.uniq(shown) ++ [".gitignore", "mix.exs"])
  end

  # The rules of `Examples.problems/1`, each on pages of the test's own, their files the
  # ones examples/ ships.
  @first {"guides/a.md", :tutorial}
  @second {"guides/b.md", :howto}

  defp page({path, kind}, lines), do: Examples.page(path, kind, Enum.join(lines, "\n") <> "\n")
  defp file(path), do: File.read!(Path.join(Examples.dir(), path))

  defp shows(path, lang \\ "text"),
    do: ["<!-- file: #{path} -->", "```#{lang}", String.trim_trailing(file(path), "\n"), "```"]

  defp runs(name),
    do: ["```elixir", "IO.puts(1)", "```", "", "```console", "$ mix run #{name}", "1", "```"]

  test "a page's example is given the files its page shows before it, and the files it " <>
         "links to on the page that shows them, and no other page's" do
    first = page(@first, shows("motor.ld") ++ runs("scan.exs") ++ shows("delay.ld"))
    second = page(@second, runs("early.exs") ++ ["Get [`motor.ld`](a.md#x)."] ++ runs("scan.exs"))
    between = ["```elixir", "IO.puts(1)", "```", "Get [`motor.ld`](a.md).", "```console"]
    third = page({"guides/c.md", :howto}, between ++ ["$ mix run scan.exs", "1", "```"])

    assert [
             %{page: "guides/a.md", name: "scan.exs", line: 22, files: one},
             %{page: "guides/b.md", name: "early.exs", line: 5, files: none},
             %{page: "guides/b.md", name: "scan.exs", line: 14, files: linked}
           ] = Examples.all([first, second])

    assert {one, none, linked} ==
             {%{"motor.ld" => file("motor.ld")}, %{}, %{"motor.ld" => file("motor.ld")}}

    assert Examples.problems([first, second]) == []

    # A link between a script and its `$ mix run` leaves the script the run's.
    assert [_, %{page: "guides/c.md", name: "scan.exs", files: ^linked}] =
             Examples.all([first, third])

    assert {Examples.problems([first, third]), Examples.unrun(third)} == {[], []}
  end

  test "a link to a file on a page that does not show it, or on no page the suite reads, " <>
         "is a problem, and gives the file to no example" do
    first = page(@first, ["# A"])

    second =
      page(
        @second,
        ["[`motor.ld`](a.md) and [`delay.ld`](../README.md)", "[`a word`](a.md)"] ++
          runs("scan.exs")
      )

    assert Examples.problems([first, second]) == [
             "guides/b.md:1: `motor.ld` is linked to guides/a.md, which does not show it: link " <>
               "it to the page that shows it under `<!-- file: motor.ld -->`, or show it here",
             "guides/b.md:1: `delay.ld` is linked to README.md, which is no page the suite reads"
           ]

    assert [%{files: files}] = Examples.all([first, second])
    assert files == %{}
  end

  test "a file may be shown on two pages; a path marked twice on one page is a problem" do
    first = page(@first, shows("motor.ld"))
    second = page(@second, shows("motor.ld") ++ shows("motor.ld"))

    assert Examples.problems([first, second]) ==
             ["guides/b.md:19: `motor.ld` is marked twice on this page"]
  end

  test "a part is a run of whole lines of its file, or a problem" do
    rung = "xic motor ote run_lamp"

    page =
      page(@first, [
        "<!-- part of: motor.ld -->",
        "```text",
        rung,
        "xic overtemp otl fault",
        "```",
        "<!-- part of: motor.ld -->",
        "```text",
        "xic motor ote run_lam",
        "```",
        "<!-- part of: gone.ld -->",
        "```text",
        rung,
        "```"
      ])

    assert file("motor.ld") =~ rung

    assert Examples.problems([page]) == [
             "guides/a.md:7: this block is not a run of whole lines of examples/motor.ld",
             "guides/a.md:11: a part of `gone.ld`, which is not under examples/"
           ]

    assert Examples.files(page) == %{}
  end

  test "a `$ mix run` that does not follow its script is a problem, and no example" do
    page = page(@first, shows("motor.ld") ++ ["```console", "$ mix run scan.exs", "1", "```"])

    assert Examples.problems([page]) ==
             [
               "guides/a.md:18: `$ mix run scan.exs` does not follow its script, an `elixir` block"
             ]

    assert Examples.all([page]) == []
  end

  test "on a page under the writing rules a block with no mark is a problem, unless its " <>
         "language is one the suite does not hold; a legacy page's is left" do
    lines =
      ["```text", "xic a ote b", "```", "```", "xic a ote b", "```"] ++
        ["<!-- unchecked: a form of the syntax -->", "```text", "xic a ote b", "```"] ++
        Enum.flat_map(Examples.shown(), &["```#{&1}", "x", "```"]) ++
        ["````markdown", "```text", "xic a ote b", "```", "$ mix run scan.exs", "````"] ++
        ["<!-- fragment: its form -->", "```text", "x", "```", "```erlang", "x.", "```"]

    told = fn n, lang ->
      "guides/a.md:#{n}: a `#{lang}` block with no mark: mark it `<!-- file: <path> -->`, " <>
        "`<!-- part of: <path> -->` or `<!-- unchecked: <why> -->` on the line above it, or " <>
        "write its language as one of console, mermaid, markdown, yaml, json, diff"
    end

    assert Examples.problems([page(@first, lines)]) == [
             "guides/a.md:36: a `fragment` mark is for an `elixir` block, and this one is `text`",
             told.(1, "text"),
             told.(4, ""),
             told.(39, "erlang")
           ]

    assert Examples.problems([page({"guides/a.md", :legacy}, lines)]) ==
             [
               "guides/a.md:36: a `fragment` mark is for an `elixir` block, and this one is `text`"
             ]

    assert Examples.own(page(@first, lines)) =~ "xic a ote b"
    refute Examples.own(page(@first, lines)) =~ "$ mix run scan.exs"
  end

  test "an `elixir` block with a `fragment` mark is named by its page; one with a `file` " <>
         "or `part of` mark is held to its file and is no fragment" do
    page =
      page(@first, [
        "<!-- fragment: the call's form -->",
        "```elixir",
        "Logex.compile(source)",
        "```",
        "```elixir",
        "Logex.compile(other)",
        "```",
        "<!-- part of: scan.exs -->",
        "```elixir",
        ~S|{:ok, motor} = Logex.compile_file("motor.ld")|,
        "```"
      ])

    assert Examples.marked(page) == ["Logex.compile(source)"]

    assert Examples.unrun(page) == [
             {2, "Logex.compile(source)", "Logex.compile(source)\n"},
             {5, "Logex.compile(other)", "Logex.compile(other)\n"}
           ]

    assert Examples.problems([page]) == []
  end

  test "a script two pages run is an example of each, a module of its own for each" do
    first = page(@first, runs("scan.exs"))
    second = page(@second, runs("scan.exs"))
    assert [%{page: "guides/a.md"}, %{page: "guides/b.md"}] = Examples.all([first, second])

    assert {Examples.module("guides/a.md"), Examples.module("README.md"),
            Examples.module("guides/tutorials/first-program.md")} ==
             {"GuidesA", "Readme", "GuidesTutorialsFirstProgram"}

    assert Enum.map(Examples.all([first, second]), &Examples.named/1) ==
             ["GuidesA.Scan", "GuidesB.Scan"]

    assert Examples.named(%{page: "README.md", name: "on_the_clock.fragment_3790.exs"}) ==
             "Readme.OnTheClockFragment3790"

    assert Examples.slug("guides/tutorials/first-program.md") ==
             "guides_tutorials_first_program.md"
  end

  test "a file a page describes in its prose is made for it only where the page says the words" do
    {path, from, _how, _edits, words} = hd(Examples.derived())
    says = page(@first, shows(from) ++ [words])
    silent = page(@second, shows(from))

    assert Map.has_key?(Examples.held(says, [says, silent]), path)
    refute Map.has_key?(Examples.held(silent, [says, silent]), path)
  end
end
