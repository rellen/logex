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
      deps: deps(Mix.env())
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
