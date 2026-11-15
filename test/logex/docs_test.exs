defmodule Logex.DocsTest do
  @moduledoc """
  The documentation's build (decisions 546 and 548). ExDoc is a dependency of the `docs`
  environment alone: in every other one `mix.exs` gives no dependency, so that `mix
  compile`, `mix format` and `mix test` read no entry, ask for no Hex and fetch nothing,
  which a `mix` started with an empty home, no Hex in it, shows; and `mix.lock` names
  ExDoc and what ExDoc needs, nothing else.

  The site: `docs/pages.exs`, the one list of pages, held to every Markdown file of the
  repository, each page's kind to its directory and its group; `mix.exs`'s site read from
  it, README first, the host contract's modules first and apart; `scripts/site.exs`, run
  as `mix docs` and `scripts/docs.sh` run it, over small trees of the test's own, each
  refusal of its `stage` and its `check`, and over the repository's pages; `scripts/docs.sh`
  over a stand-in `mix`; and `.github/workflows/docs.yml`, its keys, its toolchain, its
  permissions, and its question to GitHub run as written over a stand-in `gh`. The site
  itself is built by the workflow, a build too slow for the suite.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir
  @root Path.expand("../..", __DIR__)
  # The `elixir` beside the Elixir the suite runs on, or else the one on the path.
  @elixir Enum.find(
            [
              Path.expand(Path.join([:code.lib_dir(:elixir), "..", "..", "bin", "elixir"])),
              System.find_executable("elixir")
            ],
            &File.exists?(to_string(&1))
          )

  # `mix`, run in the project with a home that holds nothing, no Hex among it, and a build
  # path of the test's own: what it prints and its exit code.
  defp mix(dir, env, args) do
    home = Path.join(dir, "home")
    File.mkdir_p!(home)

    System.cmd(@elixir, [Path.join(Path.dirname(@elixir), "mix") | args],
      cd: @root,
      stderr_to_stdout: true,
      env: [
        {"MIX_ENV", env},
        {"MIX_HOME", home},
        {"HEX_HOME", Path.join(home, "hex")},
        {"MIX_BUILD_PATH", Path.join([dir, "build", env])}
      ]
    )
  end

  describe "ExDoc, a dependency of the docs environment alone" do
    # The trap a trial found: an entry `only: :docs` is still read in every environment,
    # and Mix needs Hex to read it, so that a bare toolchain's `mix compile` stops and
    # asks for Hex. Here Mix reads the project with no Hex to ask, in each environment a
    # gate or a host runs, and is given no entry.
    test "mix.exs gives no dependency in dev, test or prod, read by a mix with no Hex",
         %{tmp_dir: dir} do
      show = [
        "run",
        "--no-compile",
        "--no-start",
        "-e",
        "IO.inspect(Mix.Project.config()[:deps])"
      ]

      for env <- ["dev", "test", "prod"],
          do: assert({env, mix(dir, env, show)} == {env, {"[]\n", 0}})
    end

    test "the suite's own environment has none, and `mix docs` runs in docs" do
      assert Mix.Project.config()[:deps] == []
      assert Mix.Project.get!().cli() == [preferred_envs: [docs: :docs]]
    end

    test "mix.lock, committed, names ExDoc and what ExDoc needs, nothing else" do
      # Mix writes each package's name quoted, which the tokenizer warns of.
      {lock, _} =
        @root
        |> Path.join("mix.lock")
        |> File.read!()
        |> Code.string_to_quoted!(emit_warnings: false)
        |> Code.eval_quoted()

      assert {:hex, :ex_doc, _version, _, _, _, "hexpm", _} = lock[:ex_doc]
      assert Enum.sort(Map.keys(lock)) == Enum.sort(needed([:ex_doc], lock, []))
    end
  end

  # ---- the list of pages ----

  @kinds %{
    tutorial: {"guides/tutorials/", ["Tutorials"]},
    howto: {"guides/howto/", ["How-to guides"]},
    reference: {"guides/reference/", ["Reference"]},
    explanation: {"guides/explanation/", ["Explanation"]},
    adr: {"docs/adr/", ["Decision records"]},
    contributor: {"docs/", ["Architecture and implementation", "Project"]},
    legacy: {"", ["Project"]}
  }
  @groups [
    "Tutorials",
    "How-to guides",
    "Reference",
    "Explanation",
    "Architecture and implementation",
    "Decision records",
    "Project"
  ]

  defp pages do
    {pages, _} = Code.eval_file(Path.join(@root, "docs/pages.exs"))
    pages
  end

  # What is wrong with a list of pages, each a line: a page whose kind is none, whose
  # directory is not its kind's, or whose group is not one its kind may stand in.
  defp wrong(pages) do
    for {path, kind, group} <- pages,
        {under, groups} = Map.get(@kinds, kind, {"", []}),
        problem <- [
          not Map.has_key?(@kinds, kind) && "#{path}: #{inspect(kind)} is no kind",
          not String.starts_with?(path, under) && "#{path}: a #{kind} page lives under #{under}",
          (kind == :adr or not String.starts_with?(path, "docs/adr/")) ||
            "#{path}: a page under docs/adr/ is an :adr",
          group not in ([:github, :first] ++ groups) &&
            "#{path}: a #{kind} page stands under #{Enum.join(groups, " or ")}, or :github",
          (group == :first and path != "README.md") && "#{path}: README.md alone is :first"
        ],
        is_binary(problem),
        do: problem
  end

  describe "docs/pages.exs, the one list of pages" do
    test "it lists every Markdown file of the repository, each once, and no file that is " <>
           "not there" do
      {listed, 0} = System.cmd("git", ["ls-files", "*.md", "*.cheatmd", "*.livemd"], cd: @root)
      tracked = String.split(listed, "\n", trim: true)

      on_disk =
        for under <- ["*", "docs/**/*", "guides/**/*"],
            path <- Path.wildcard(Path.join(@root, under <> ".{md,cheatmd,livemd}")),
            do: Path.relative_to(path, @root)

      paths = for {path, _kind, _group} <- pages(), do: path
      assert "README.md" in paths
      assert paths -- Enum.uniq(paths) == [], "a page listed twice"
      assert Enum.sort(paths) == Enum.sort(Enum.uniq(tracked ++ on_disk))
    end

    test "each page's kind is one of the seven, its directory its kind's and its group one " <>
           "its kind stands in; README alone is the first page" do
      assert wrong(pages()) == []
      assert [{"README.md", _, :first}] = for({_, _, :first} = page <- pages(), do: page)
    end

    test "the check of the list finds a kind that is none, a page in another kind's " <>
           "directory, a group that is not its kind's and a second first page" do
      assert wrong([
               {"guides/tutorials/a.md", :tutorial, "Tutorials"},
               {"guides/howto/b.md", :lesson, "Tutorials"},
               {"guides/howto/c.md", :tutorial, "Tutorials"},
               {"guides/reference/d.md", :reference, "Explanation"},
               {"docs/adr/0001-e.md", :contributor, "Project"},
               {"docs/f.md", :contributor, :first},
               {"docs/g.md", :contributor, :github},
               {"PLAN.md", :legacy, :github}
             ]) == [
               "guides/howto/b.md: :lesson is no kind",
               "guides/howto/b.md: a lesson page stands under , or :github",
               "guides/howto/c.md: a tutorial page lives under guides/tutorials/",
               "guides/reference/d.md: a reference page stands under Reference, or :github",
               "docs/adr/0001-e.md: a page under docs/adr/ is an :adr",
               "docs/f.md: README.md alone is :first"
             ]
    end
  end

  describe "mix.exs's site" do
    test "its pages are the list's, in the list's order, README first, each read from its " <>
           "staged copy and linked to its own file; its groups are the seven, in order" do
      docs = Mix.Project.config()[:docs].()
      site = for {path, _kind, group} <- pages(), group != :github, do: {path, group}

      assert docs[:main] == "readme"
      assert docs[:formatters] == ["html"]
      assert docs[:source_ref] == "main"
      assert docs[:assets] == %{"guides/assets" => "assets"}
      assert Mix.Project.config()[:source_url] == "https://github.com/rellen/logex"

      assert docs[:extras] ==
               for({path, _} <- site, do: {"_build/docs/pages/" <> path, [source: path]})

      assert hd(docs[:extras]) == {"_build/docs/pages/README.md", [source: "README.md"]}

      assert docs[:groups_for_extras] ==
               for(
                 group <- @groups,
                 do: {group, for({path, ^group} <- site, do: "_build/docs/pages/" <> path)}
               )

      assert Keyword.keys(Mix.Project.config()[:aliases]) == [:docs]

      assert Mix.Project.config()[:aliases][:docs] ==
               ["cmd elixir scripts/site.exs stage", "docs"]
    end

    # Decisions 514 and 523, as `runtime_test.exs` lists them: the eight modules named the
    # way in, and with them the configuration's elements, a device's point, the simulated
    # device and the runner's clocks.
    @contract [
      Logex,
      Logex.Runtime,
      Logex.Edit,
      Logex.Configuration,
      Logex.Configuration.Edit,
      Logex.Runner,
      Logex.IO,
      Logex.Tag,
      Logex.Configuration.Task,
      Logex.Configuration.Global,
      Logex.Configuration.Instance,
      Logex.Configuration.Connection,
      Logex.IO.Point,
      Logex.IO.Sim,
      Logex.Runner.Clock,
      Logex.Runner.Clock.Manual,
      Logex.Runner.Clock.Monotonic
    ]

    test "the host contract's modules stand first and apart, and every other documented " <>
           "module in the second group, none left out of both" do
      {:ok, modules} = :application.get_key(:logex, :modules)

      documented =
        for module <- modules,
            {:docs_v1, _, :elixir, _, doc, _, _} <- [Code.fetch_docs(module)],
            doc != :hidden,
            do: module

      assert [{contract_name, contract}, {_other_name, other}] =
               Mix.Project.config()[:docs].()[:groups_for_modules]

      assert contract_name == :"Host contract"
      assert Enum.sort(contract) == Enum.sort(@contract)
      assert Enum.sort(other) == Enum.sort(documented -- @contract)
      assert contract -- documented == []
    end
  end

  # ---- scripts/site.exs ----

  # A small tree of the test's own, `files` a map of path to text, `scripts/site.exs` and
  # the script's arguments run in it: what it printed, and its exit code.
  defp site(dir, files, args) do
    for {path, text} <- files do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.write!(Path.join(dir, path), text)
    end

    System.cmd(@elixir, [Path.join(@root, "scripts/site.exs") | args],
      cd: dir,
      stderr_to_stdout: true
    )
  end

  defp manifest(pages), do: inspect(pages, limit: :infinity)

  @tree %{
    "docs/pages.exs" =>
      ~S|[{"README.md", :legacy, :first}, {"guides/tutorials/first.md", :tutorial, "Tutorials"}, | <>
        ~S|{"guides/reference/words.md", :reference, "Reference"}, {"PLAN.md", :legacy, :github}]|,
    "README.md" => """
    # A project

    See [the lesson](guides/tutorials/first.md), [the plan](PLAN.md#steps) and
    [the code](lib/a.ex). `[not a link](nowhere.md)`

    ```text
    [not a link](nowhere.md)
    ```
    """,
    "PLAN.md" => "# Plan\n",
    "lib/a.ex" => "",
    "guides/assets/rung.svg" => "<svg/>",
    "guides/tutorials/first.md" => """
    # A lesson

    ## What you need

    ![A rung](../assets/rung.svg) and [a word](../reference/words.md#tag),
    [`a word`](../reference/words.md), [here](#what-you-need),
    [the examples](../../lib) and [a site](https://example.com/a.md#b).
    """,
    "guides/reference/words.md" => "# Words\n\n## Tag\n\n### `xic`\n\n## Tag\n"
  }

  describe "scripts/site.exs stage" do
    test "it writes each page of the site with its links made right: a page's left, a " <>
           "picture's under assets/, any other file's on GitHub; code is not read",
         %{tmp_dir: dir} do
      assert {"site: 3 pages staged in out\n", 0} = site(dir, @tree, ["stage", "out"])
      refute File.exists?(Path.join(dir, "out/PLAN.md"))

      assert File.read!(Path.join(dir, "out/README.md")) == """
             # A project

             See [the lesson](guides/tutorials/first.md), [the plan](https://github.com/rellen/logex/blob/main/PLAN.md#steps) and
             [the code](https://github.com/rellen/logex/blob/main/lib/a.ex). `[not a link](nowhere.md)`

             ```text
             [not a link](nowhere.md)
             ```
             """

      assert File.read!(Path.join(dir, "out/guides/tutorials/first.md")) == """
             # A lesson

             ## What you need

             ![A rung](assets/rung.svg) and [a word](../reference/words.md#tag),
             [`a word`](../reference/words.md), [here](#what-you-need),
             [the examples](https://github.com/rellen/logex/tree/main/lib) and [a site](https://example.com/a.md#b).
             """
    end

    test "with no directory given it writes to _build/docs/pages, where mix.exs reads",
         %{tmp_dir: dir} do
      assert {"site: 3 pages staged in _build/docs/pages\n", 0} = site(dir, @tree, ["stage"])
      assert File.exists?(Path.join(dir, "_build/docs/pages/guides/reference/words.md"))
    end

    test "a heading given twice is numbered from its second, and a link names either",
         %{tmp_dir: dir} do
      page = "# A lesson\n\n[one](../reference/words.md#tag-1) [two](../reference/words.md#xic)\n"
      tree = Map.put(@tree, "guides/tutorials/first.md", page)
      assert {_, 0} = site(dir, tree, ["stage", "out"])
    end

    test "it refuses a link to a file that is not there, to an anchor no heading of level " <>
           "2 or 3 gives, out of the repository, and a picture outside guides/assets/, " <>
           "each with its page and line, and writes nothing",
         %{tmp_dir: dir} do
      page = """
      # A lesson

      [gone](../reference/gone.md) and [no anchor](../reference/words.md#rung)
      [the title](../reference/words.md#words) [out](../../../etc/passwd)
      ![A picture](../../lib/a.ex) [here](#nowhere)
      """

      tree = Map.put(@tree, "guides/tutorials/first.md", page)
      assert {out, 1} = site(dir, tree, ["stage", "out"])

      assert String.split(out, "\n", trim: true) == [
               "site: guides/tutorials/first.md:3: the link `../reference/gone.md` leads to " <>
                 "guides/reference/gone.md, which is not there",
               "site: guides/tutorials/first.md:3: the link `../reference/words.md#rung` names " <>
                 "the anchor #rung, which no heading of level 2 or 3 of " <>
                 "guides/reference/words.md gives",
               "site: guides/tutorials/first.md:4: the link `../reference/words.md#words` " <>
                 "names the anchor #words, which no heading of level 2 or 3 of " <>
                 "guides/reference/words.md gives",
               "site: guides/tutorials/first.md:4: the link `../../../etc/passwd` leads out " <>
                 "of the repository",
               "site: guides/tutorials/first.md:5: the picture `../../lib/a.ex` is outside " <>
                 "guides/assets/, where the site's pictures are",
               "site: guides/tutorials/first.md:5: the link `#nowhere` names the anchor " <>
                 "#nowhere, which no heading of level 2 or 3 of guides/tutorials/first.md gives"
             ]

      refute File.exists?(Path.join(dir, "out"))
    end

    test "it refuses two pages of the site with one file name", %{tmp_dir: dir} do
      pages = [{"README.md", :legacy, :first}, {"docs/README.md", :contributor, "Project"}]

      tree = %{
        "docs/pages.exs" => manifest(pages),
        "README.md" => "# A\n",
        "docs/README.md" => "# B\n"
      }

      assert {out, 1} = site(dir, tree, ["stage", "out"])

      assert out ==
               "site: README.md and docs/README.md: two pages of the site named README.md; " <>
                 "ExDoc tells pages apart by file name, so give one another name\n"
    end

    test "in a page under the writing rules it refuses a heading whose anchor on GitHub is " <>
           "not its anchor in the site; a legacy page's is left",
         %{tmp_dir: dir} do
      page = "# Words\n\n## Tag\n\n### Scan / cycle\n\n## What it is: a word\n"

      pages = [
        {"README.md", :legacy, :first},
        {"guides/reference/words.md", :reference, "Reference"}
      ]

      tree = %{
        "docs/pages.exs" => manifest(pages),
        "README.md" => page,
        "guides/reference/words.md" => page
      }

      assert {out, 1} = site(dir, tree, ["stage", "out"])

      assert out ==
               "site: guides/reference/words.md:5: the heading `Scan / cycle` is " <>
                 "#scan--cycle on GitHub and #scan-cycle in the site; write it with letters, " <>
                 "digits and single spaces alone, so that a link to it works in both\n"
    end

    test "the repository's own pages are staged with no refusal", %{tmp_dir: dir} do
      {out, code} =
        System.cmd(@elixir, ["scripts/site.exs", "stage", dir], cd: @root, stderr_to_stdout: true)

      site = for {path, _kind, group} <- pages(), group != :github, do: path
      assert {out, code} == {"site: #{length(site)} pages staged in #{dir}\n", 0}
      for path <- site, do: assert(File.exists?(Path.join(dir, path)))
    end
  end

  @warning """
       warning: documentation references module "Logex.Edit.Plan" but it is hidden
       │
   369 │   state. They are an internal module's, `Logex.Edit.Plan`, so that
       │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
       │
       └─ lib/logex/edit.ex:369: Logex.Edit (module)

      warning: documentation references module "Logex.Array" but it is hidden
      │
  509 │   of tuples in the elements' order as any array's (`Logex.Array`), each element a new
      │
      └─ (logex 0.1.0) lib/logex/fb_type.ex:509: Logex.FbType.started/2

  warning: documentation references file "docs/gone.md" but it does not exist
  └─ _build/docs/pages/guides/tutorials/first.md: (file)

  View html docs at "doc/index.html"
  """

  @listed """
  # What the module text gives today.
  Logex.Edit (module): documentation references module "Logex.Edit.Plan" but it is hidden
  Logex.FbType.started/2: documentation references module "Logex.Array" but it is hidden
  guides/tutorials/first.md: documentation references file "docs/gone.md" but it does not exist
  """

  @built %{
    "doc/readme.html" =>
      ~S|<a href="first.html#what-you-need">a</a> <a href="Logex.html#compile/2">b</a> | <>
        ~S|<a href="#top">c</a> <img src="assets/rung.svg"/> <script src="docs_config.js"></script> | <>
        ~S|<a href="https://example.com/gone.html#x">d</a> <h2 id="top">T</h2>|,
    "doc/first.html" => ~S|<h2 id="what-you-need">W</h2> <a href="readme.html">e</a>|,
    "doc/Logex.html" =>
      ~S|<section id="compile/2"></section> <a href="Logex.html#t:t/0">f</a> | <>
        ~S|<span id="t:t/0"></span>|,
    "doc/assets/rung.svg" => "<svg/>"
  }

  describe "scripts/site.exs check" do
    test "a build whose warnings are the list's, each as often, and whose links all lead " <>
           "somewhere passes, with its counts",
         %{tmp_dir: dir} do
      tree = Map.merge(@built, %{"log" => @warning, "docs/site-warnings.txt" => @listed})

      assert site(dir, tree, ["check", "log"]) ==
               {"site: 3 pages built, 8 links followed, 3 warnings and dead links, each " <>
                  "listed in docs/site-warnings.txt\n", 0}
    end

    test "a warning the list does not have is refused, a page's or a module's, and one it " <>
           "has once and the build gives twice",
         %{tmp_dir: dir} do
      listed = @listed |> String.split("\n") |> Enum.take(2) |> Enum.join("\n")
      log = @warning <> @warning
      tree = Map.merge(@built, %{"log" => log, "docs/site-warnings.txt" => listed})
      assert {out, 1} = site(dir, tree, ["check", "log"])

      assert String.split(out, "\n", trim: true) == [
               "site: not in docs/site-warnings.txt: Logex.FbType.started/2: documentation " <>
                 ~S|references module "Logex.Array" but it is hidden|,
               "site: not in docs/site-warnings.txt: guides/tutorials/first.md: documentation " <>
                 ~S|references file "docs/gone.md" but it does not exist|,
               "site: not in docs/site-warnings.txt: Logex.Edit (module): documentation " <>
                 ~S|references module "Logex.Edit.Plan" but it is hidden|,
               "site: not in docs/site-warnings.txt: Logex.FbType.started/2: documentation " <>
                 ~S|references module "Logex.Array" but it is hidden|,
               "site: not in docs/site-warnings.txt: guides/tutorials/first.md: documentation " <>
                 ~S|references file "docs/gone.md" but it does not exist|
             ]
    end

    test "a line of the list the build no longer gives is refused", %{tmp_dir: dir} do
      listed =
        @listed <>
          "Logex (module): documentation references module \"Logex.Gone\" but it is hidden\n"

      tree = Map.merge(@built, %{"log" => @warning, "docs/site-warnings.txt" => listed})

      assert site(dir, tree, ["check", "log"]) ==
               {"site: docs/site-warnings.txt lists what the build no longer gives; take its " <>
                  "line out: Logex (module): documentation references module \"Logex.Gone\" " <>
                  "but it is hidden\n", 1}
    end

    test "a link of a built page to a file that is not in the site, or to an anchor its " <>
           "page does not have, is refused, unless the list has it",
         %{tmp_dir: dir} do
      page =
        ~S|<a href="gone.html">a</a> <a href="first.html#gone">b</a> <a href="#gone">c</a> | <>
          ~S|<img src="assets/gone.svg"/> <a href="Logex.html#compile/3">d</a>|

      tree =
        @built
        |> Map.merge(%{"log" => @warning, "docs/site-warnings.txt" => @listed})
        |> Map.put("doc/readme.html", page)

      assert {out, 1} = site(dir, tree, ["check", "log"])

      dead = [
        "readme.html: the link `gone.html` leads to gone.html, which is not in the site",
        "readme.html: the link `first.html#gone` names an anchor that first.html does not have",
        "readme.html: the link `#gone` names an anchor that readme.html does not have",
        "readme.html: the link `assets/gone.svg` leads to assets/gone.svg, which is not in the site",
        "readme.html: the link `Logex.html#compile/3` names an anchor that Logex.html does not have"
      ]

      assert String.split(out, "\n", trim: true) ==
               Enum.map(dead, &("site: not in docs/site-warnings.txt: " <> &1))

      listed = @listed <> Enum.join(dead, "\n") <> "\n"

      assert {_, 0} =
               site(dir, %{"docs/site-warnings.txt" => listed}, ["check", "log"])
    end

    test "a build that left no page is refused", %{tmp_dir: dir} do
      assert site(dir, %{"log" => "", "docs/site-warnings.txt" => ""}, ["check", "log"]) ==
               {"site: no page in doc/: the site was not built\n", 1}
    end

    test "the repository's list names the six warnings and seven dead links of the module " <>
           "text, and nothing of a page" do
      listed =
        for line <- String.split(File.read!(Path.join(@root, "docs/site-warnings.txt")), "\n"),
            line != "" and not String.starts_with?(line, "#"),
            do: line

      {dead, warnings} = Enum.split_with(listed, &String.starts_with?(&1, "api-reference.html: "))
      assert {length(warnings), length(dead)} == {6, 7}
      assert Enum.all?(warnings, &String.starts_with?(&1, "Logex."))
    end

    test "anything else is refused with its usage", %{tmp_dir: dir} do
      assert site(dir, %{}, ["build"]) ==
               {"usage: elixir scripts/site.exs stage [<dir>] | check <log>\n", 2}
    end
  end

  # ---- scripts/docs.sh ----

  # Runs `scripts/docs.sh` in `dir` over a `mix` of the test's own, first on the path: it
  # notes each task and its `MIX_ENV`, exits `rcs[task]` where given, and for `docs` prints
  # `log` and leaves the built site of `@built`; `scripts/site.exs` is the repository's.
  defp run_docs(dir, rcs, log, listed \\ @listed) do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)
    File.mkdir_p!(Path.join(dir, "scripts"))
    File.mkdir_p!(Path.join(dir, "docs"))
    File.mkdir_p!(Path.join(dir, "doc"))
    File.write!(Path.join(dir, "doc/stale.html"), ~S|<a href="gone.html">stale</a>|)
    File.write!(Path.join(dir, "docs/site-warnings.txt"), listed)
    File.write!(Path.join(dir, "printed"), log)

    for script <- ["docs.sh", "site.exs"],
        do: File.cp!(Path.join(@root, "scripts/#{script}"), Path.join(dir, "scripts/#{script}"))

    for {path, text} <- @built do
      File.mkdir_p!(Path.dirname(Path.join([dir, "built", path])))
      File.write!(Path.join([dir, "built", path]), text)
    end

    File.write!(Path.join(bin, "mix"), """
    #!/usr/bin/env bash
    echo "$1 ${MIX_ENV:-unset} $([ -e doc/stale.html ] && echo stale || echo clean)" >> called
    case "$1" in
      local.hex) exit #{Map.get(rcs, "local.hex", 0)} ;;
      deps.get) exit #{Map.get(rcs, "deps.get", 0)} ;;
      docs)
        cat printed >&2
        [ #{Map.get(rcs, "docs", 0)} -eq 0 ] && cp -r built/doc .
        exit #{Map.get(rcs, "docs", 0)} ;;
    esac
    """)

    File.chmod!(Path.join(bin, "mix"), 0o755)

    {out, code} =
      System.cmd("bash", ["scripts/docs.sh", "docs.log"],
        cd: dir,
        env: [{"PATH", Enum.join([bin, Path.dirname(@elixir), System.get_env("PATH")], ":")}],
        stderr_to_stdout: true
      )

    {out, code, File.read!(Path.join(dir, "called"))}
  end

  describe "scripts/docs.sh" do
    test "a build whose warnings and dead links are the list's is DOCS-OK: Hex, ExDoc " <>
           "fetched in docs, the last build's site gone, then mix docs and the check",
         %{tmp_dir: dir} do
      assert {out, 0, called} = run_docs(dir, %{}, @warning)
      assert called == "local.hex unset stale\ndeps.get docs stale\ndocs unset clean\n"

      assert String.ends_with?(
               out,
               "site: 3 pages built, 8 links followed, 3 warnings and dead links, each " <>
                 "listed in docs/site-warnings.txt\nDOCS-OK\n"
             )

      assert File.read!(Path.join(dir, "docs.log")) == @warning
    end

    test "a warning the list does not have is DOCS-FAIL, the warning named", %{tmp_dir: dir} do
      extra =
        "warning: documentation references file \"x.md\" but it does not exist\n└─ a.md: (file)\n"

      assert {out, 1, _} = run_docs(dir, %{}, @warning <> extra)

      assert String.ends_with?(
               out,
               "site: not in docs/site-warnings.txt: a.md: documentation references file " <>
                 "\"x.md\" but it does not exist\nDOCS-FAIL rc=1\n"
             )
    end

    test "a build mix docs fails, a page's link refused for one, is DOCS-FAIL with mix's " <>
           "code, and nothing is checked",
         %{tmp_dir: dir} do
      refusal = "site: guides/a.md:3: the link `b.md` leads to guides/b.md, which is not there\n"
      assert {out, 7, called} = run_docs(dir, %{"docs" => 7}, refusal)
      assert out == refusal <> "DOCS-FAIL rc=7\n"
      assert called == "local.hex unset stale\ndeps.get docs stale\ndocs unset clean\n"
    end

    test "ExDoc not fetched stops the rest", %{tmp_dir: dir} do
      assert {"DOCS-FAIL rc=3\n", 3, "local.hex unset stale\ndeps.get docs stale\n"} =
               run_docs(dir, %{"deps.get" => 3}, "")
    end
  end

  # ---- .github/workflows/docs.yml ----

  # A workflow's lines that hold anything, comments and blank lines dropped.
  defp workflow(name) do
    @root
    |> Path.join(".github/workflows/#{name}")
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
  end

  # The keys among `lines` written at `indent`, a list item's first with its `- `.
  defp keys_at(lines, indent) do
    for line <- lines,
        [_, key] <- [Regex.run(~r/^ {#{indent}}((?:- )?[A-Za-z_-]+):/, line)],
        do: key
  end

  # The lines from the one `heading` to the next at its indentation or less.
  defp under(lines, heading) do
    [line | rest] = Enum.drop_while(lines, &(&1 != heading))
    indent = byte_size(line) - byte_size(String.trim_leading(line))
    Enum.take_while(rest, &(byte_size(&1) - byte_size(String.trim_leading(&1)) > indent))
  end

  # A job's steps, each its lines.
  defp steps(job) do
    job
    |> under("    steps:")
    |> Enum.chunk_while(
      [],
      fn
        "      - " <> _ = line, [] -> {:cont, [line]}
        "      - " <> _ = line, acc -> {:cont, Enum.reverse(acc), [line]}
        line, acc -> {:cont, [line | acc]}
      end,
      &{:cont, Enum.reverse(&1), []}
    )
  end

  defp step_keys(step) do
    ["- " <> first | keys] = keys_at(step, 6) ++ keys_at(step, 8)
    [first | keys]
  end

  # The text of a step's `run: |` block.
  defp script(step) do
    [line | block] = Enum.drop_while(step, &(not String.match?(&1, ~r/^\s*run: \|$/)))
    at = byte_size(line) - byte_size(String.trim_leading(line))
    Enum.map_join(block, "\n", &String.slice(&1, (at + 2)..-1//1)) <> "\n"
  end

  # Runs the workflow's question to GitHub as GitHub runs a `shell: bash` step, over a `gh`
  # of the test's own that answers `answer` and exits `rc`: what the step printed, its
  # exit code, what it wrote to GITHUB_OUTPUT and what it asked.
  defp ask(dir, ref, answer, rc) do
    [step] =
      Enum.filter(steps(under(workflow("docs.yml"), "  build:")), fn [name | _] ->
        name == "      - name: Ask GitHub whether Pages publishes from GitHub Actions"
      end)

    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    File.write!(Path.join(bin, "gh"), """
    #!/usr/bin/env bash
    echo "$*" > asked
    echo '#{answer}'
    exit #{rc}
    """)

    File.chmod!(Path.join(bin, "gh"), 0o755)
    File.write!(Path.join(dir, "step.sh"), script(step))
    File.write!(Path.join(dir, "output"), "")

    {out, code} =
      System.cmd("bash", ["--noprofile", "--norc", "-eo", "pipefail", "step.sh"],
        cd: dir,
        stderr_to_stdout: true,
        env: [
          {"PATH", Enum.join([bin, System.get_env("PATH")], ":")},
          {"GITHUB_REPOSITORY", "someone/logex"},
          {"GITHUB_REF", ref},
          {"GITHUB_OUTPUT", Path.join(dir, "output")}
        ]
      )

    {out, code, File.read!(Path.join(dir, "output")), File.read!(Path.join(dir, "asked"))}
  end

  describe ".github/workflows/docs.yml (decision 548)" do
    test "every push and pull request builds the site by scripts/docs.sh, the step no key " <>
           "but its name and run, no job or step that skips it or lets its failure pass" do
      lines = workflow("docs.yml")
      build = under(lines, "  build:")

      assert {keys_at(lines, 0), under(lines, "on:"), keys_at(lines, 2), keys_at(build, 4),
              Enum.map(steps(build), &step_keys/1)} ==
               {["name", "on", "permissions", "jobs"], ["  push:", "  pull_request:"],
                ["push", "pull_request", "contents", "build", "publish"],
                ["runs-on", "permissions", "env", "outputs", "steps"],
                [
                  ["uses"],
                  ["name", "id", "uses", "with"],
                  ["name", "uses", "with"],
                  ["name", "run"],
                  ["name", "id", "if", "shell", "env", "run"],
                  ["name", "if", "uses"],
                  ["name", "if", "uses", "with"]
                ]}

      assert Enum.at(steps(build), 3) == [
               "      - name: scripts/docs.sh",
               "        run: scripts/docs.sh"
             ]

      refute Enum.any?(lines, &(&1 =~ "continue-on-error"))
    end

    test "its toolchain is the pair CI pins, set up as CI sets it up" do
      [ci, docs] =
        for name <- ["ci.yml", "docs.yml"] do
          lines = workflow(name)
          setup = Enum.drop_while(lines, &(&1 != "      - name: Set up Erlang/OTP and Elixir"))
          {under(lines, "    env:"), Enum.take(setup, 6)}
        end

      assert docs == ci

      assert elem(docs, 0) == [
               ~S|      OTP_VERSION: "28"|,
               ~S|      ELIXIR_VERSION: "1.20.4"|
             ]
    end

    test "its permissions are the least: the contents read, Pages read by the build, and " <>
           "Pages written and an identity token by the publish alone" do
      lines = workflow("docs.yml")

      assert {under(lines, "permissions:"), under(under(lines, "  build:"), "    permissions:"),
              under(under(lines, "  publish:"), "    permissions:")} ==
               {["  contents: read"], ["      contents: read", "      pages: read"],
                ["      pages: write", "      id-token: write"]}
    end

    test "the publish is GitHub's three actions, each only where the build found Pages " <>
           "ready, the publish job after the build" do
      lines = workflow("docs.yml")
      build = steps(under(lines, "  build:"))
      publish = under(lines, "  publish:")
      ready = "        if: steps.pages.outputs.publish == 'true'"

      assert Enum.take(Enum.at(build, 5), 3) ==
               [
                 "      - name: Configure GitHub Pages",
                 ready,
                 "        uses: actions/configure-pages@v6"
               ]

      assert Enum.at(build, 6) == [
               "      - name: Upload the site",
               ready,
               "        uses: actions/upload-pages-artifact@v5",
               "        with:",
               "          path: doc"
             ]

      assert Enum.take(publish, 2) ==
               ["    needs: build", "    if: needs.build.outputs.publish == 'true'"]

      assert [["      - name: Publish to GitHub Pages", "        id: deployment", uses]] =
               steps(publish)

      assert uses == "        uses: actions/deploy-pages@v5"

      assert under(under(lines, "  build:"), "    outputs:") ==
               ["      publish: ${{ steps.pages.outputs.publish }}"]
    end

    test "a push to main where Pages publishes from GitHub Actions is published",
         %{tmp_dir: dir} do
      assert ask(dir, "refs/heads/main", "workflow", 0) ==
               {"GitHub Pages for someone/logex: workflow; this push is to refs/heads/main\n", 0,
                "publish=true\n", "api repos/someone/logex/pages --jq .build_type\n"}
    end

    test "a push to main where Pages is off, or its source is a branch, publishes nothing, " <>
           "says so in a notice and passes",
         %{tmp_dir: dir} do
      notice =
        "::notice title=The site was built and not published::GitHub Pages is off for " <>
          "someone/logex, or its source is not GitHub Actions. To publish: Settings, Pages, " <>
          "Build and deployment, Source: GitHub Actions.\n"

      assert {out, 0, "publish=false\n", _} = ask(dir, "refs/heads/main", "legacy", 0)

      assert out ==
               "GitHub Pages for someone/logex: legacy; this push is to refs/heads/main\n" <>
                 notice

      assert {out, 0, "publish=false\n", _} =
               ask(dir, "refs/heads/main", ~S|{"message":"Not Found"}|, 1)

      assert out ==
               "GitHub Pages for someone/logex: off; this push is to refs/heads/main\n" <> notice
    end

    test "a push to any other branch publishes nothing and gives no notice", %{tmp_dir: dir} do
      assert ask(dir, "refs/heads/backup/doc1", "workflow", 0) ==
               {"GitHub Pages for someone/logex: workflow; this push is to " <>
                  "refs/heads/backup/doc1\n", 0, "publish=false\n",
                "api repos/someone/logex/pages --jq .build_type\n"}
    end
  end

  # Each package the lock says `names` need, optional ones the lock does not hold left out.
  defp needed([], _lock, seen), do: seen

  defp needed([name | rest], lock, seen),
    do: needed(rest ++ (requires(lock[name]) -- [name | seen]), lock, Enum.uniq([name | seen]))

  defp requires(nil), do: []

  defp requires(entry),
    do: for({name, _requirement, options} <- elem(entry, 5), not options[:optional], do: name)
end
