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
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications. Nothing uses Logger, so no
  # extra application is started (PLAN.md B6).
  def application do
    []
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
