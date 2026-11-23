Code.require_file("../../scripts/page.exs", __DIR__)

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
  # language `Page.shown/0` lists, which the suite compares with nothing: a diagram, data,
  # Markdown shown as Markdown, and a command line, whose lines are commands alone, each
  # after `$ `, since what a command prints is an example's to show or is marked
  # `unchecked`. `scripts/prose.exs` counts both for a reviewer.
  #
  # A page's fences are read by `scripts/page.exs`, the one reading of a page every script
  # shares: a fence it cannot take, one not closed or whose info string is not one word,
  # is a problem with the page's name and the line, never a raise, so that one page's
  # fence does not stop the suite of every other page.

  @root Path.expand("../..", __DIR__)
  # Decision 517 (b): where the pages' examples are shipped, each a file a host can copy.
  @examples Path.expand("../../examples", __DIR__)
  @needs ~r/\[`([^`\]]+)`\]\(([^)#\s]+\.(?:md|cheatmd))(?:#[^)\s]*)?\)/
  # The files a page describes in its prose rather than shows, each by its page, made from
  # a file the page shows or links to, by replacing text, beside the words of the page
  # that describe it, which the test finds there: the page a row names is given the file
  # made, and is held to the words. A passage that moves to another page takes its rows
  # with it: the row's page is changed in the same commit.
  # Since decision 363 `wired.logex` is no longer one: a page shows it, its warning citing
  # a line the page shows. The files of `warm/`, `moved/` and `boxes_v2.ld` are none since
  # README was made short: the pages that run them show each.
  @derived [
    {"guides/reference/forcing.md", "faster/packing.logex", "packing.logex", :as_is,
     [{"interval 10", "interval 5"}],
     "`faster/packing.logex`, which is `packing.logex` with `interval 5`"},
    {"guides/reference/forcing.md", "faster/conveyor.ld", "conveyor.ld", :as_is, [],
     "`faster/packing.logex`"},
    {"guides/reference/forcing.md", "faster/boxes.ld", "boxes.ld", :as_is, [],
     "`faster/packing.logex`"}
  ]

  # A script a page shows as the continuation of another of the same page, its setup up
  # to a line.
  @continues %{
    "a_trip.exs" => {"on_the_clock.exs", "show = fn label", "`a_trip.exs` runs the same plant"}
  }

  # The runner's reference, "Example: a plant on the manual clock": the state its fragment's prose describes, a runner on
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
    {"guides/reference/runner.md",
     ~S|task = Task.async(fn -> Runner.get!(runner, "b1.count") end)|,
     {"on_the_clock.exs", @owed, @answered,
      "b1.count waited, then answered 0 after 1 to 4 owed rounds\n",
      "A call that comes while a round is owed waits for its slot"}}
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
  def shown, do: Page.shown()

  # The pages the test reads: README.md, and every page docs/pages.exs lists that is not
  # a legacy document.
  def pages do
    for {path, kind, _group} <- Page.listed(@root),
        read?(path, kind),
        do: page(path, kind, File.read!(Path.join(@root, path)))
  end

  # A page as the test reads it: its path, its kind, its text, its blocks, and what is
  # wrong with its fences, which `scripts/page.exs` reads.
  def page(path, kind, text) do
    read = Page.read(text)

    %{
      path: path,
      kind: kind,
      text: text,
      blocks: Enum.flat_map(read.items, &item(&1, path)),
      faults: Page.problems(read, Page.ruled?(kind))
    }
  end

  defp read?("README.md", _kind), do: true
  defp read?(_path, kind), do: kind != :legacy

  # The pages whose modules a run needs: every page's, or, where the run is of one
  # page's tests alone, `--only reading:<page>` or `--only page:<page>`, that page's.
  # Every other page's tests would be excluded, and to define their modules is most of
  # the time such a run takes once the pages are many.
  def wanted(configuration) do
    include = configuration[:include]
    named = for {key, page} <- include, key in [:reading, :page], do: page
    only(:test in configuration[:exclude] and length(named) == length(include), named)
  end

  defp only(true, [_ | _] = pages), do: pages
  defp only(_only, _pages), do: :all

  def wanted?(:all, _page), do: true
  def wanted?(pages, page), do: page in pages

  # A page's name as a module's, `GuidesTutorialsFirstProgram`, and as a directory's.
  def module(path),
    do: path |> Path.rootname() |> String.split(~r/[^A-Za-z0-9]+/, trim: true) |> module_name()

  defp module_name(words), do: Enum.map_join(words, &Macro.camelize(String.downcase(&1)))

  def slug(path), do: String.replace(path, ~r/[^A-Za-z0-9.]+/, "_")

  # An example's or a fragment's test module under `Logex.ReadmeTest`, its page's name
  # and its own: `GuidesReferenceRunner.OnTheClock`,
  # `GuidesReferenceRunner.OnTheClockFragment598`.
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

    for {{n, "elixir", body, mark}, next} <- Enum.zip(blocks, Enum.drop(blocks, 1) ++ [nil]),
        mark == nil or match?({"fragment", _}, mark),
        not runs?(next),
        do: {n, hd(String.split(body, "\n")), body}
  end

  # The `elixir` blocks of a page that carry a `fragment` mark, by their first line.
  def marked(page) do
    for {_n, "elixir", body, {"fragment", _why}} <- page.blocks,
        do: hd(String.split(body, "\n"))
  end

  defp runs?({_n, lang, body, nil}) when lang in ["", "console"], do: Page.run(body) != nil
  defp runs?(_block), do: false

  # A page's fenced blocks alone, its links to other pages' files left out.
  defp fenced(blocks),
    do: for({_n, lang, _body, _mark} = block <- blocks, is_binary(lang), do: block)

  # Every example of every page, in the pages' order and each page's own.
  def all(pages \\ pages()) do
    shown = files_of(pages)
    Enum.flat_map(pages, &of(&1, shown))
  end

  # The files each page shows, by the page's path: what a link to a page can give.
  def files_of(pages), do: Map.new(pages, &{&1.path, files(&1)})

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

  # The files a page has by its end, among the files `shown/1` gives: those it shows,
  # those it links to on the pages that show them, and those its prose describes, made.
  def held(page, shown) do
    {files, _previous, _examples} =
      Enum.reduce(page.blocks, {%{}, nil, []}, &step(&1, &2, page, shown))

    with_derived(files, page.path)
  end

  # The files a page's own test holds to examples/: those it shows and those made of its
  # prose. A file it links to is held by the page that shows it, once.
  def own_held(page, shown) do
    linked = for {_n, :needs, file, _from} <- page.blocks, do: file
    Map.drop(held(page, shown), linked -- Map.keys(files(page)))
  end

  # Where a page shows each of its files, by the file's path: the line of its block, a
  # file made of the page's prose at the block of the file it is made of.
  def lines(page) do
    linked = for {n, :needs, file, _from} <- page.blocks, into: %{}, do: {file, n}
    marked = for {n, _lang, _body, {"file", path}} <- page.blocks, into: %{}, do: {path, n}
    shown = Map.merge(linked, marked)

    made =
      for {page_path, path, from, _how, _edits, _words} <- @derived,
          page_path == page.path,
          Map.has_key?(shown, from),
          into: %{},
          do: {path, shown[from]}

    Map.merge(made, shown)
  end

  # Each fenced block of a page in order, `{line, lang, body, mark}`, `mark` what the line
  # above it says of it, `{"file", path}` for one, or nil; among them each link to a file
  # another page shows, `{line, :needs, file, page}`; and each block or mark in a
  # quotation, a callout's, `{line, :quoted}`, where the suite reads no block. The fences
  # are `scripts/page.exs`'s to read: a fence of four backticks or more closes at its
  # like, so that a block of Markdown that shows a fence is one block.
  # A mark in a quotation, a callout's: the suite reads no block there.
  @quoted ~r/^\s*>\s*<!-- (?:file|part of|fragment|unchecked):/

  defp item({:block, %{quoted: true, line: n}}, _path), do: [{n, :quoted}]

  defp item({:block, %{line: n, lang: lang, body: body, above: above}}, _path),
    do: [{n, lang, body, Page.mark(above)}]

  defp item({:line, n, line, :prose}, path), do: needs(line, n, path)
  defp item({:line, n, line, :comment}, _path), do: quoted(Regex.match?(@quoted, line), n)
  defp item({:line, _n, _line, :blank}, _path), do: []

  defp quoted(true, n), do: [{n, :quoted}]
  defp quoted(false, _n), do: []

  # The links of a line whose text is a shipped file's name, in a code span, and whose
  # target is a page: the file, and the page as the repository names it.
  defp needs(line, n, path) do
    for [_, file, target] <- Regex.scan(@needs, line),
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
       do: run(Page.run(body), block, {files, previous, examples}, n, page)

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
        files: with_derived(files, page.path),
        expected: String.replace_prefix(body, shown, "")
      }
    ]
  end

  # The files made of a page's prose, for the page their rows name, where it has the file
  # each is made of.
  defp with_derived(files, page) do
    made =
      for {^page, path, from, how, edits, _words} <- @derived,
          Map.has_key?(files, from),
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
    shown = files_of(pages)
    shipped = shipped()
    Enum.flat_map(pages, &problems(&1, shown, shipped))
  end

  defp problems(page, shown, shipped) do
    blocks = page.blocks

    for({n, message} <- page.faults, do: "#{page.path}:#{n}: #{message}") ++
      Enum.flat_map(blocks, &problem(&1, page, shown)) ++
      twice(page, blocks) ++
      unscripted(page, blocks) ++
      unheld(page.kind, page, blocks) ++ ungiven(page, shown, shipped)
  end

  # Each file examples/ ships, by its path there, but the project's own two.
  def shipped do
    for path <- Path.wildcard(Path.join(@examples, "**"), match_dot: true),
        File.regular?(path),
        relative <- [Path.relative_to(path, @examples)],
        not String.starts_with?(relative, ["_build/", "deps/"]),
        relative not in [".gitignore", "mix.exs"],
        do: relative
  end

  defp problem({n, :needs, file, from}, page, shown),
    do: unshown(Map.has_key?(shown, from), get_in(shown, [from, file]), n, file, from, page)

  defp problem({n, _lang, body, {"part of", path}}, page, _shown),
    do: part(File.read(Path.join(@examples, path)), body, n, path, page)

  defp problem({n, lang, _body, {"fragment", _why}}, page, _shown) when lang != "elixir",
    do: [
      "#{page.path}:#{n}: a `fragment` mark is for an `elixir` block, and this one is `#{lang}`"
    ]

  defp problem({n, "elixir", _body, {"unchecked", _why}}, page, _shown) do
    [
      "#{page.path}:#{n}: an `elixir` block marked `unchecked`: an `elixir` block is an " <>
        "example's script, or a `fragment`, which the suite parses"
    ]
  end

  defp problem({n, :quoted}, page, _shown) do
    [
      "#{page.path}:#{n}: a code block or a mark in a callout, which the suite does not " <>
        "read: put the block after the callout"
    ]
  end

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
        [_, name] <- [Page.run(body)],
        script(previous) == nil,
        do: "#{page.path}:#{n}: `$ mix run #{name}` does not follow its script, an `elixir` block"
  end

  # On a page under the writing rules, a block that no test holds and that does not say so.
  defp unheld(:legacy, _page, _blocks), do: []

  defp unheld(_kind, page, blocks) do
    for {n, lang, body, nil} <- blocks,
        is_binary(lang),
        lang != "elixir",
        Page.run(body) == nil,
        told <- untold(lang in Page.shown(), lang, commands?(body)),
        do: "#{page.path}:#{n}: #{told}"
  end

  # A block with no mark: of a language the suite compares with nothing it passes, but a
  # command line that shows what a command printed; of any other language it does not.
  defp untold(true, "console", false) do
    [
      "a `console` block that shows what a command prints, which no test compares: show " <>
        "the commands alone, each after `$ `, or show a script's run, `$ mix run " <>
        "<script>` straight after its `elixir` block, or mark it `<!-- unchecked: <why> -->`"
    ]
  end

  defp untold(true, _lang, _commands), do: []

  defp untold(false, lang, _commands) do
    [
      "a `#{lang}` block with no mark: mark it `<!-- file: <path> -->`, " <>
        "`<!-- part of: <path> -->` or `<!-- unchecked: <why> -->` on the line above " <>
        "it, or write its language as one of #{Enum.join(Page.shown(), ", ")}"
    ]
  end

  defp commands?(body),
    do: body |> String.split("\n", trim: true) |> Enum.all?(&String.starts_with?(&1, "$ "))

  # A file examples/ ships that an example's script names, in a string, or that a
  # configuration file it names loads as a program, and the example is not given: its
  # page neither shows it before the example nor links to the page that shows it, and
  # the script would stop where it reads the file.
  defp ungiven(page, shown, shipped) do
    for %{run: :shipped} = example <- of(page, shown),
        {path, through} <- reads(example, shipped),
        not Map.has_key?(example.files, path),
        do:
          "#{page.path}:#{example.line}: `#{example.name}` reads `#{path}`#{through}, which " <>
            "the page neither shows before it, under `<!-- file: #{path} -->`, nor links " <>
            "to on the page that shows it, as [`#{path}`](<that page>)"
  end

  defp reads(example, shipped) do
    named = for path <- shipped, String.contains?(example.script, ~s("#{path}")), do: path

    loaded =
      for path <- named,
          Path.extname(path) == ".logex",
          [_, type] <-
            Regex.scan(~r/^\s*program\s+\S+\s+(\w+)/m, Map.get(example.files, path, "")),
          program = beside(path, type <> ".ld"),
          program in shipped,
          uniq: true,
          do: {program, ", a program of `#{path}`"}

    Enum.map(named, &{&1, ""}) ++ loaded
  end

  defp beside(path, name),
    do: Path.relative_to(Path.expand(Path.join(Path.dirname(path), name), "/"), "/")

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
  says are this run's alone, compared by their beginning, and it must exit 0; where it
  does not, the failure shows what it printed on standard error too, the exception that
  stopped it. Each example
  is a test module of its own, `Logex.ReadmeTest.GuidesReferenceRunner.OnTheClock` for the
  runner's reference's `on_the_clock.exs`, so that the examples run side by side, a script two pages run is run
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
    # An example that reads no file still has its directory.
    File.mkdir_p!(dir)

    for path <- Map.keys(example.files) do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.cp!(Path.join(Examples.dir(), path), Path.join(dir, path))
    end

    File.write!(Path.join(dir, example.name), script(example))

    # Standard error is kept apart, in a file beside the directory: the page's text is
    # held to standard output alone, and a script that stops says why on standard error.
    errors = dir <> ".stderr"

    {output, status} =
      System.cmd(
        "sh",
        [
          "-c",
          ~S(exec "$0" "$@" 2>"$ERRORS"),
          to_string(@elixir),
          "-pa",
          Mix.Project.compile_path(),
          example.name
        ],
        cd: dir,
        env: [{"ERRORS", errors}]
      )

    at = "#{example.page} line #{example.line}: #{example.name}"

    assert status == 0,
           "#{at} exited #{status}, printing:\n#{output}" <> said(File.read!(errors))

    # Held as a pair with its place, so that a failure shows what the script printed beside
    # what the page shows, and where they differ, which a message of the test's own hid
    # (RV-9's review, CI's run 41358731876).
    assert {at, Examples.comparable(output, example.name)} ==
             {at, Examples.comparable(example.expected, example.name)}
  end

  # A block a page shows is its file under `examples/`, byte for byte: a failure names
  # the page, the line of the block and the file, and shows the two texts.
  def same(page, line, path, text) do
    at = "#{page} line #{line}: #{path}"
    assert {at, File.read(Path.join(Examples.dir(), path))} == {at, {:ok, text}}
  end

  defp said(""), do: ""
  defp said(errors), do: "and on standard error:\n" <> errors

  # Decision 517 (b): an example runs its script as shipped under `examples/`, which the
  # hold below keeps its page's; a fragment the script the test makes of it.
  defp script(%{run: :shipped, name: name}), do: File.read!(Path.join(Examples.dir(), name))
  defp script(%{run: :made, script: script}), do: script

  def elixir, do: @elixir
end

# The pages are read once, here, for every module below: a page's own tests read what
# is the page's, so that a page more is a page's work more and not every page's.
pages = Logex.ReadmeTest.Examples.pages()
shown = Logex.ReadmeTest.Examples.files_of(pages)
examples = Logex.ReadmeTest.Examples.all(pages)
fragments = Logex.ReadmeTest.Examples.run_fragments(pages)
problems = Logex.ReadmeTest.Examples.problems(pages)
wanted = Logex.ReadmeTest.Examples.wanted(ExUnit.configuration())

for example <- examples, Logex.ReadmeTest.Examples.wanted?(wanted, example.page) do
  defmodule Module.concat(Logex.ReadmeTest, Logex.ReadmeTest.Examples.named(example)) do
    @moduledoc false
    use ExUnit.Case, async: Logex.ReadmeTest.Examples.async?(example.name)
    @moduletag page: example.page
    # A fresh VM's start alone can take a minute where every core is busy.
    @moduletag timeout: 180_000
    @example example

    test "#{@example.page}'s #{@example.name} prints what the page shows" do
      Logex.ReadmeTest.check(@example)
    end
  end
end

# Decision 365: each fragment the suite runs, in the setup its test makes, a module of its
# own, `Logex.ReadmeTest.GuidesReferenceRunner.OnTheClockFragment598`.
for fragment <- fragments, Logex.ReadmeTest.Examples.wanted?(wanted, fragment.page) do
  defmodule Module.concat(Logex.ReadmeTest, Logex.ReadmeTest.Examples.named(fragment)) do
    @moduledoc false
    use ExUnit.Case, async: true
    @moduletag page: fragment.page
    @moduletag timeout: 180_000
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
for page <- pages, Logex.ReadmeTest.Examples.wanted?(wanted, page.path) do
  defmodule Module.concat(Logex.ReadmeTest.Reading, Logex.ReadmeTest.Examples.module(page.path)) do
    @moduledoc false
    alias Logex.ReadmeTest.Examples
    use ExUnit.Case, async: true
    @moduletag page: page.path
    @moduletag reading: page.path
    @path page.path
    @page page
    @examples Enum.filter(examples, &(&1.page == page.path))
    @fragments Enum.filter(fragments, &(&1.page == page.path))
    @held Examples.own_held(page, shown)
    @given Examples.held(page, shown)
    @problems Enum.filter(problems, &String.starts_with?(&1, page.path <> ":"))

    defp page, do: @page
    defp examples, do: @examples
    defp fragments, do: @fragments
    defp held, do: @held
    defp given, do: @given
    defp problems, do: @problems

    # What the examples are made of is the page's own: each file its row names this page
    # for is made of a file the page still has, and is still described there, and each
    # script that continues another still says so.
    test "#{@path} still describes each file and script the examples make of its prose" do
      text = page().text

      for {@path, path, from, _how, _edits, words} <- Examples.derived() do
        assert Map.has_key?(given(), from),
               "#{@path} no longer shows #{from}, nor links to the page that shows it, " <>
                 "which #{path} is made of"

        assert text =~ words, "#{@path} no longer says #{inspect(words)} of #{path}"
      end

      for %{name: name} <- examples(),
          {_from, _cut, words} <- [Map.get(Examples.continues(), name)],
          do: assert(text =~ words, "#{@path} no longer says #{inspect(words)} of #{name}")

      for %{name: name, words: words} <- fragments(),
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
          do:
            assert(
              match?({:ok, _}, Code.string_to_quoted(body)),
              "#{@path} line #{n}: an `elixir` block that does not parse"
            )
    end

    # Decision 517 (b): the pages' examples are shipped as files under `examples/`, each
    # block a page shows its file there, each file a page describes made as the test makes
    # it, and each script a page shows as the rest of another there whole. A failure
    # names the page, the line of the block and the file.
    test "each file and script #{@path} shows is its file under examples/" do
      lines =
        Map.merge(Examples.lines(page()), Map.new(examples(), &{&1.name, &1.line}))

      shown = Map.merge(held(), Map.new(examples(), &{&1.name, &1.script}))

      for {path, text} <- shown, do: Logex.ReadmeTest.same(@path, lines[path], path, text)
    end

    test "every `$ mix run` #{@path} shows is an example, and every file a mark names is one" do
      own = Examples.own(page())
      shown = for [_, name] <- Regex.scan(~r/^\s*\$ mix run (?!scripts\/)(\S+)$/m, own), do: name
      assert Enum.map(examples(), & &1.name) == shown

      marked = for [_, path] <- Regex.scan(~r/^\s*<!-- file: (\S+) -->$/m, own), do: path
      assert Enum.uniq(marked) -- Map.keys(Examples.files(page())) == []
    end

    # What a set of pages can get wrong that one file could not, and what a writer can
    # forget: a fence that is not closed or says more than its language, a link to a file
    # on a page that does not show it, a path marked twice, a part that is not its
    # file's, a `$ mix run` with no script, a script that reads a file its page does not
    # give it, and on a page under the writing rules a block no test holds that does not
    # say so.
    test "#{@path}'s marks and blocks are sound, each block held or said not to be" do
      assert Enum.join(problems(), "\n") == ""
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
    shown = Examples.files_of(pages)
    held = Enum.flat_map(pages, &Map.keys(Examples.held(&1, shown)))
    read = Enum.map(pages, & &1.path)

    for {page, path, _from, _how, _edits, _words} <- Examples.derived() do
      assert page in read,
             "@derived names #{page} for #{path}, and it is no page the suite reads"

      assert path in held, "no page describes #{path} any longer"
    end

    for {name, {from, _cut, _words}} <- Examples.continues(),
        do:
          assert(
            Enum.any?(examples, &(&1.name == name)) and Enum.any?(examples, &(&1.name == from)),
            "no page runs #{name} as the rest of #{from} any longer"
          )
  end

  # Decision 365: every fragment `@fragments` gives a setup is found in its page and run.
  test "the runner's fragment of a call that waits for an owed round is run, not parsed alone" do
    assert [
             %{
               page: "guides/reference/runner.md",
               name: "on_the_clock.fragment_" <> _,
               script: script
             }
           ] =
             Examples.run_fragments()

    assert script =~ ~S|task = Task.async(fn -> Runner.get!(runner, "b1.count") end)|
  end

  # Decision 517 (b): `examples/` holds each file and script some page shows or describes,
  # and nothing else but the project they run in: a file no page shows is refused.
  test "examples/ holds the files and scripts the pages show, and no other" do
    pages = Examples.pages()
    files = Examples.files_of(pages)

    shown =
      Enum.flat_map(pages, &Map.keys(Examples.held(&1, files))) ++
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

    # A page of any kind of file gives a file: a cheatsheet as a page of Markdown.
    sheet = page({"guides/sheet.cheatmd", :reference}, shows("motor.ld"))
    reads = page(@second, ["Get [`motor.ld`](sheet.cheatmd#motor)."] ++ runs("scan.exs"))
    assert [%{files: ^linked}] = Examples.all([sheet, reads])
    assert Examples.problems([sheet, reads]) == []

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

  test "a `$ mix run` that does not follow its script is a problem, and no example; a " <>
         "command that runs one of the repository's own scripts is neither" do
    own = [
      "```console",
      "$ mix run scripts/draw.exs guides/a.md",
      "```",
      "<!-- unchecked: what the repository's script prints -->",
      "```console",
      "$ mix run scripts/draw.exs",
      "same guides/assets/a.svg",
      "```"
    ]

    page =
      page(@first, shows("motor.ld") ++ ["```console", "$ mix run scan.exs", "1", "```"] ++ own)

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
        Enum.flat_map(Examples.shown(), &["```#{&1}", "$ x", "```"]) ++
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

  test "a code block or a mark in a callout is a problem: the suite reads no block there" do
    page =
      page(@first, [
        "> #### Note {: .info}",
        ">",
        "> The message:",
        "> <!-- unchecked: a message -->",
        "> ```text",
        "> not declared",
        "> ```",
        "",
        "> <!-- file: motor.ld -->",
        "> The file.",
        "",
        "After the callout."
      ])

    told =
      "a code block or a mark in a callout, which the suite does not read: put the block after the callout"

    assert Examples.problems([page]) ==
             ["guides/a.md:4: #{told}", "guides/a.md:5: #{told}", "guides/a.md:9: #{told}"]

    assert Examples.files(page) == %{}
  end

  # One page's fence stops no other page's suite: what `scripts/page.exs` cannot take is
  # a problem of that page, with its line, and the page's other blocks are still read.
  test "a fence that says more than its language, a fence that is not closed and a block " <>
         "closed by a longer fence are problems of their page, with the line, and no raise" do
    said = ["```elixir title=\"scan.exs\"", "IO.puts(1)", "```", "", "```console"]
    page = page(@first, said ++ ["$ mix run scan.exs", "1", "```", "", "```text", "xic a"])

    assert Examples.problems([page]) == [
             "guides/a.md:1: a code block whose fence says `elixir title=\"scan.exs\"`: write " <>
               "its language alone after the fence, one word, as in ```elixir",
             "guides/a.md:10: a code block that is not closed: close it with ``` on a line " <>
               "of its own",
             "guides/a.md:10: a `text` block with no mark: mark it `<!-- file: <path> -->`, " <>
               "`<!-- part of: <path> -->` or `<!-- unchecked: <why> -->` on the line above " <>
               "it, or write its language as one of console, mermaid, markdown, yaml, json, diff"
           ]

    # The block is read by its language, and the example after it is still one.
    assert [%{name: "scan.exs", line: 5, script: "IO.puts(1)\n"}] = Examples.all([page])

    longer = page(@second, ["```console", "$ ls", "````", "", "The end."])

    assert Examples.problems([longer]) == [
             "guides/b.md:3: a code block closed by a longer fence than opened it: close it " <>
               "with ```, as it is opened"
           ]

    # A language the examples do not know is a block with no mark, at its own fence.
    session = page(@second, ["```shell-session", "$ ls", "```", ""] ++ runs("scan.exs"))

    assert ["guides/b.md:1: a `shell-session` block with no mark" <> _] =
             Examples.problems([session])

    assert [%{name: "scan.exs"}] = Examples.all([session])
  end

  test "on a page under the writing rules a block fenced with tildes, an indented code " <>
         "block, an HTML tag and a comment left open are problems; a legacy page's are left" do
    lines = [
      "~~~text",
      "xic a ote b",
      "~~~",
      "",
      "    xic a ote b",
      "",
      "1. A step.",
      "",
      "   Its result, in the step.",
      "",
      "       xic a ote b",
      "",
      "A list of <kind> pages and `<kind>` as code, <https://example.com>.",
      "<pre>xic a ote b</pre>",
      "<!-- a comment",
      "left open -->"
    ]

    assert Examples.problems([page(@first, lines)]) == [
             "guides/a.md:1: a code block fenced with tildes: fence it with three backticks, " <>
               "as every other block",
             "guides/a.md:5: a line indented by 4 spaces or more after an empty line, which " <>
               "Markdown shows as a code block no check reads: fence the block with three " <>
               "backticks and give it a language, or indent the line less",
             "guides/a.md:11: a line indented by 4 spaces or more after an empty line, which " <>
               "Markdown shows as a code block no check reads: fence the block with three " <>
               "backticks and give it a language, or indent the line less",
             "guides/a.md:13: the HTML tag `<kind>`: the site shows a tag as text and no " <>
               "check reads into it. Write Markdown, or write the words as code",
             "guides/a.md:14: the HTML tag `<pre>`: the site shows a tag as text and no " <>
               "check reads into it. Write Markdown, or write the words as code",
             "guides/a.md:15: an HTML comment that does not end on its line: a mark is one " <>
               "line, as `<!-- file: motor.ld -->`",
             "guides/a.md:1: a `text` block with no mark: mark it `<!-- file: <path> -->`, " <>
               "`<!-- part of: <path> -->` or `<!-- unchecked: <why> -->` on the line above " <>
               "it, or write its language as one of console, mermaid, markdown, yaml, json, diff"
           ]

    assert Examples.problems([page({"guides/a.md", :legacy}, lines)]) == []
  end

  test "a command line shows commands alone, each after `$ `: what a command prints is an " <>
         "example's run or is marked unchecked; an `elixir` block is never unchecked" do
    page =
      page(@first, [
        "```console",
        "$ mix deps.get",
        "$ mix compile",
        "```",
        "```console",
        "$ elixir scan.exs",
        "start pressed",
        "```",
        "<!-- unchecked: what the command prints differs by machine -->",
        "```console",
        "$ elixir --version",
        "Elixir 1.20.4",
        "```",
        "<!-- unchecked: a script -->",
        "```elixir",
        "IO.puts(1)",
        "```"
      ])

    assert Examples.problems([page]) == [
             "guides/a.md:15: an `elixir` block marked `unchecked`: an `elixir` block is an " <>
               "example's script, or a `fragment`, which the suite parses",
             "guides/a.md:5: a `console` block that shows what a command prints, which no " <>
               "test compares: show the commands alone, each after `$ `, or show a script's " <>
               "run, `$ mix run <script>` straight after its `elixir` block, or mark it " <>
               "`<!-- unchecked: <why> -->`"
           ]
  end

  test "a script that names a file examples/ ships, which its page neither shows before " <>
         "it nor links to, is a problem at the script's run; one given the file is none" do
    script = ["```elixir", ~S|{:ok, motor} = Logex.compile_file("motor.ld")|, "```", ""]
    run = ["```console", "$ mix run scan.exs", "1", "```"]
    late = page(@first, script ++ run ++ shows("motor.ld") ++ shows("delay.ld"))
    given = page(@second, ["Get [`motor.ld`](a.md)."] ++ script ++ run)

    assert Examples.problems([late, given]) == [
             "guides/a.md:5: `scan.exs` reads `motor.ld`, which the page neither shows " <>
               "before it, under `<!-- file: motor.ld -->`, nor links to on the page that " <>
               "shows it, as [`motor.ld`](<that page>)"
           ]

    # A configuration file the script names loads each of its programs from beside it.
    loads = ["```elixir", ~S|Logex.Configuration.compile_file("plant.logex")|, "```", ""]
    through = page(@first, shows("plant.logex") ++ loads ++ run)
    assert file("plant.logex") =~ ~r/^program \S+ motor/m

    assert ["guides/a.md:" <> told] = Examples.problems([through])

    assert told =~
             ~r/^\d+: `scan.exs` reads `motor.ld`, a program of `plant.logex`, which the page neither shows/

    whole = page(@first, shows("plant.logex") ++ shows("motor.ld") ++ loads ++ run)
    assert Examples.problems([whole]) == []
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

    # A page with no block has no fragment, no example and no problem.
    bare = page(@second, ["# A page", "", "No block."])
    assert {Examples.unrun(bare), Examples.all([bare]), Examples.problems([bare])} == {[], [], []}

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

  test "a failure names the page, its line and the example or the file, for a script that " <>
         "prints another thing, for one that exits with a failure and for a block that is " <>
         "not its file" do
    example = %{page: "guides/a.md", name: "wrong.exs", line: 5, run: :made, files: %{}}
    printed = Map.merge(example, %{script: ~S|IO.puts("b")|, expected: "a\n"})
    error = assert_raise ExUnit.AssertionError, fn -> Logex.ReadmeTest.check(printed) end

    assert {error.left, error.right} ==
             {{"guides/a.md line 5: wrong.exs", "b\n"}, {"guides/a.md line 5: wrong.exs", "a\n"}}

    exited = Map.merge(example, %{script: ~S|IO.puts("b"); System.halt(3)|, expected: "b\n"})
    error = assert_raise ExUnit.AssertionError, fn -> Logex.ReadmeTest.check(exited) end
    assert error.message == "guides/a.md line 5: wrong.exs exited 3, printing:\nb\n"

    # A block that is not its file: the page, the line of the block and the file.
    assert Logex.ReadmeTest.same("guides/a.md", 7, "motor.ld", file("motor.ld"))

    error =
      assert_raise ExUnit.AssertionError, fn ->
        Logex.ReadmeTest.same("guides/a.md", 7, "motor.ld", "xic a\n")
      end

    assert error.left == {"guides/a.md line 7: motor.ld", {:ok, file("motor.ld")}}
    assert error.right == {"guides/a.md line 7: motor.ld", {:ok, "xic a\n"}}

    # A script that stops says why on standard error, which the failure shows.
    stopped = Map.merge(example, %{script: ~S|IO.puts("b"); File.read!("gone.ld")|})
    error = assert_raise ExUnit.AssertionError, fn -> Logex.ReadmeTest.check(stopped) end

    assert error.message =~
             ~r/\Aguides\/a\.md line 5: wrong\.exs exited 1, printing:\nb\nand on standard error:\n.*could not read file "gone\.ld": no such file or directory/s
  end

  test "a file a page describes in its prose is made for the page its row names, where " <>
         "the page has the file it is made of, and for no other page" do
    {named, path, from, _how, _edits, _words} = hd(Examples.derived())
    names = page({named, :legacy}, shows(from))
    other = page(@second, shows(from))
    without = page({named, :legacy}, ["# A page"])
    shown = Examples.files_of([names, other])

    assert Map.has_key?(Examples.held(names, shown), path)
    assert Examples.lines(names)[path] == 2
    refute Map.has_key?(Examples.held(other, shown), path)
    refute Map.has_key?(Examples.held(without, Examples.files_of([without])), path)
  end

  test "a page's own test holds the files it shows and the files made of its prose; a " <>
         "file it links to is held by the page that shows it" do
    first = page(@first, shows("motor.ld"))
    second = page(@second, ["Get [`motor.ld`](a.md)."] ++ shows("delay.ld"))
    shown = Examples.files_of([first, second])

    assert Map.keys(Examples.held(second, shown)) == ["delay.ld", "motor.ld"]
    assert Map.keys(Examples.own_held(second, shown)) == ["delay.ld"]
    assert Examples.lines(second) == %{"delay.ld" => 3, "motor.ld" => 1}
  end

  # The pages are read once for all their tests (the file's top level): a page's module
  # reads what is the page's, and calls nothing that reads every page again, which made
  # the reading tests grow with the square of the pages.
  test "a page's reading tests call nothing that reads every page" do
    {:ok, ast} = Code.string_to_quoted(File.read!(__ENV__.file))

    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:for, _,
         [{:<-, _, [{:page, _, _}, {:pages, _, _}]}, _wanted, [do: {:defmodule, _, _} = body]]} =
            node,
        found ->
          {node, [body | found]}

        node, found ->
          {node, found}
      end)

    assert [body] = modules

    {_body, called} =
      Macro.prewalk(body, [], fn
        {{:., _, [{:__aliases__, _, [:Examples]}, name]}, _, arguments} = node, found ->
          {node, [{name, length(arguments)} | found]}

        node, found ->
          {node, found}
      end)

    assert Enum.sort(Enum.uniq(called)) == [
             continues: 0,
             derived: 0,
             files: 1,
             fragments: 1,
             held: 2,
             lines: 1,
             marked: 1,
             own: 1,
             own_held: 2,
             unrun: 1
           ]
  end

  test "a run of one page's tests alone defines that page's modules alone; any other " <>
         "run defines every page's" do
    one = "guides/tutorials/first-program.md"
    only = fn include -> Examples.wanted(include: include, exclude: [:test]) end

    assert only.(reading: one) == [one]
    assert only.(page: one, reading: "README.md") == [one, "README.md"]
    assert {Examples.wanted?([one], one), Examples.wanted?([one], "README.md")} == {true, false}

    # A filter of another kind beside it, or no `--only`, and every module is needed.
    assert only.(reading: one, slow: true) == :all
    assert only.([]) == :all
    assert Examples.wanted(include: [reading: one], exclude: []) == :all
    assert Examples.wanted(include: [], exclude: []) == :all
    assert Examples.wanted?(:all, "README.md")
  end

  # A growth test compares reductions at two sizes, never time.
  test "reading twice the pages is about twice the work" do
    one = shows("motor.ld") ++ runs("scan.exs") ++ ["Get [`delay.ld`](a0.md)."]

    pages = fn count ->
      for at <- 1..count, do: page({"guides/a#{at}.md", :howto}, one)
    end

    # Each part by itself: a part that reads every page again for each page is lost in the
    # sum, where the parts that grow as they should are the most of it.
    parts = [
      files: fn pages -> Examples.files_of(pages) end,
      examples: fn pages -> Examples.all(pages) end,
      problems: fn pages -> Examples.problems(pages) end,
      held: fn pages ->
        shown = Examples.files_of(pages)
        for page <- pages, do: {Examples.held(page, shown), Examples.own_held(page, shown)}
      end
    ]

    work = fn part, pages ->
      {:reductions, before} = Process.info(self(), :reductions)
      part.(pages)
      {:reductions, after_work} = Process.info(self(), :reductions)
      after_work - before
    end

    {few, many} = {pages.(40), pages.(80)}

    grown =
      for {name, part} <- parts do
        work.(part, few)
        {name, work.(part, many) / work.(part, few) < 2.6}
      end

    assert grown == [files: true, examples: true, problems: true, held: true]
  end
end
