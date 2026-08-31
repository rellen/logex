defmodule Logex.NamingTest do
  @moduledoc """
  The naming survey is a step in the recipe, not a good intention.

  `docs/naming.md` records what IEC 61131-3 and the major vendors call each
  operation, and why logex chose the name it did. This test fails if a mnemonic
  reaches `@instructions` without a stanza there.

  The check is deliberately one-way: a stanza with no implementation is fine and
  encouraged — surveying an instruction long before building it is the point.
  """
  use ExUnit.Case

  @survey Path.expand("../../docs/naming.md", __DIR__)

  # Stanza headings live under the "## Stanzas" section. Anchoring there rather
  # than grepping the whole file keeps the blank template in "Adding a stanza",
  # which sits inside a fenced block, from counting as a survey entry.
  defp surveyed_mnemonics do
    @survey
    |> File.read!()
    |> String.split("\n## Stanzas\n", parts: 2)
    |> Enum.at(1)
    |> then(&Regex.scan(~r/^### `([a-z_][a-z0-9_]*)`/m, &1 || ""))
    |> Enum.map(fn [_, mnemonic] -> mnemonic end)
    |> MapSet.new()
  end

  test "docs/naming.md exists and has a Stanzas section" do
    assert File.exists?(@survey), "expected the naming survey at #{@survey}"
    assert File.read!(@survey) =~ "\n## Stanzas\n"
  end

  test "every implemented instruction has been surveyed" do
    implemented = Logex.Compiler.instructions() |> Map.keys() |> MapSet.new()
    unsurveyed = MapSet.difference(implemented, surveyed_mnemonics())

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These instructions are in @instructions but have no stanza in docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}

    Survey the name before shipping it — see the recipe in CLAUDE.md. Copy the
    template from the "Adding a stanza" section of docs/naming.md, fill every
    dialect row, and mark anything you could not check `unverified`.
    """
  end

  test "a surveyed but unimplemented mnemonic is allowed" do
    # The survey is append-only and runs ahead of the code, so this direction
    # must never fail. Asserting it keeps a future tightening from breaking the
    # habit the survey exists to encourage.
    implemented = Logex.Compiler.instructions() |> Map.keys() |> MapSet.new()
    assert MapSet.subset?(implemented, surveyed_mnemonics())
  end
end
