defmodule Logex.MixProject do
  use Mix.Project

  @source_url "https://github.com/rellen/logex"

  def project do
    [
      app: :logex,
      version: "0.1.0",
      elixir: "~> 1.20",
      description:
        "A Ladder Logic compiler and interpreter: a ladder program written as text, " <>
          "compiled to data and run one scan at a time, with configurations, tasks " <>
          "and online edit.",
      package: package(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      # The golden record's generator lives beside its fixture; it is run by hand, not
      # loaded by `mix test`, which would otherwise warn that it looks like a misnamed test.
      test_ignore_filters: [&String.starts_with?(&1, "test/fixtures/")],
      deps: deps(Mix.env()),
      aliases: aliases(),
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications. Nothing uses Logger, so no
  # extra application is started (PLAN.md B6).
  def application do
    []
  end

  # `mix docs` runs in the `docs` environment, the only one with a dependency.
  def cli do
    [preferred_envs: [docs: :docs]]
  end

  # `mix docs` first makes the pages ready for ExDoc (scripts/site.exs), which refuses a
  # page's link that leads nowhere, then builds the site.
  defp aliases do
    [docs: ["cmd elixir scripts/site.exs stage", "docs"]]
  end

  # The site (decisions 546 and 548). Its pages are the lines of docs/pages.exs, the one
  # list of them, each page read from the copy `scripts/site.exs stage` makes of it under
  # `_build/docs/pages/` and linked to its own file on GitHub; README is the first page.
  # The modules stand in two groups, the host contract first (decisions 514 and 523).
  @pages "_build/docs/pages"
  @groups [
    "Tutorials",
    "How-to guides",
    "Reference",
    "Explanation",
    "Architecture and implementation",
    "Decision records",
    "Project"
  ]
  @contract [
    Logex,
    Logex.Runtime,
    Logex.Edit,
    Logex.Configuration,
    Logex.Configuration.Task,
    Logex.Configuration.Global,
    Logex.Configuration.Instance,
    Logex.Configuration.Connection,
    Logex.Configuration.Edit,
    Logex.Runner,
    Logex.Runner.Clock,
    Logex.Runner.Clock.Manual,
    Logex.Runner.Clock.Monotonic,
    Logex.IO,
    Logex.IO.Point,
    Logex.IO.Sim,
    Logex.Tag
  ]
  @unguarded [
    Logex.Compiler,
    Logex.Configuration.Text,
    Logex.Declarations,
    Logex.Diagnostic,
    Logex.Fault,
    Logex.FbType,
    Logex.FbType.Member,
    Logex.Instance,
    Logex.Lexer,
    Logex.Parser,
    Logex.Printer,
    Logex.Program,
    Logex.Scan,
    Logex.Walk,
    Logex.Warnings
  ]

  defp docs do
    {pages, _} = Code.eval_file("docs/pages.exs", __DIR__)
    site = for {path, _kind, group} <- pages, group != :github, do: {path, group}

    [
      main: "readme",
      formatters: ["html"],
      source_ref: "main",
      extras: for({path, _group} <- site, do: {Path.join(@pages, path), [source: path]}),
      groups_for_extras:
        for(
          heading <- @groups,
          do: {heading, for({path, ^heading} <- site, do: Path.join(@pages, path))}
        ),
      groups_for_modules: [
        "Host contract": @contract,
        "Other modules, which do not check their arguments": @unguarded
      ],
      assets: %{"guides/assets" => "assets"},
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  # A `mermaid` block of a page, drawn in the reader's browser by Mermaid, in the theme the
  # page is shown in and again when the reader changes it (ExDoc's own recipe, and its
  # event). Mermaid is fetched at one version, held to its hash. GitHub draws the same
  # block itself.
  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js" integrity="sha384-rbtjAdnIQE/aQJGEgXrVUlMibdfTSa4PQju4HDhN3sR2PmaKFzhEafuePsl9H/9I" crossorigin="anonymous"></script>
    <script>
      (() => {
        const sources = new Map();
        const dark = () => document.body.classList.contains("dark");
        const draw = () => {
          mermaid.initialize({startOnLoad: false, theme: dark() ? "dark" : "default"});
          let id = 0;
          for (const code of document.querySelectorAll("pre code.mermaid")) {
            const figure = document.createElement("div");
            figure.className = "mermaid-figure";
            sources.set(figure, code.textContent);
            code.parentElement.replaceWith(figure);
          }
          for (const [figure, source] of sources) {
            if (!figure.isConnected) { sources.delete(figure); continue; }
            mermaid.render("mermaid-figure-" + id++, source).then(({svg, bindFunctions}) => {
              figure.innerHTML = svg;
              bindFunctions?.(figure);
            });
          }
        };
        let shown = null;
        const redraw = () => { if (shown !== dark()) { shown = dark(); draw(); } };
        window.addEventListener("exdoc:loaded", () => { shown = null; redraw(); });
        new MutationObserver(redraw).observe(document.body, {attributes: true, attributeFilter: ["class"]});
      })();
    </script>
    """
  end

  defp before_closing_body_tag(_format), do: ""

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # ExDoc builds the documentation and nothing else needs it, so it is a dependency of the
  # `docs` environment alone, the one `mix docs` runs in (`cli/0`). In every other
  # environment logex has no dependency, at run time, at compile time or under test: Mix
  # reads no entry, asks for no Hex and fetches nothing, and `mix.lock` names ExDoc's
  # packages alone. An entry marked `only: :docs` would not do: Mix needs Hex to read any
  # Hex entry, whatever its environment (test/logex/docs_test.exs).
  defp deps(:docs), do: [{:ex_doc, "~> 0.40", runtime: false}]
  defp deps(_env), do: []
end
