# The project README's examples run in: from this directory, `mix run scan.exs` runs
# README's `scan.exs` against logex, the directory above, as README runs it (decision 517
# (b)). Its Elixir is logex's own.
defmodule LogexExamples.MixProject do
  use Mix.Project

  def project do
    [app: :logex_examples, version: "0.1.0", elixir: "~> 1.20", deps: [{:logex, path: ".."}]]
  end
end
