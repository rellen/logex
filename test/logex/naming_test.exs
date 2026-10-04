defmodule Logex.NamingTest do
  @moduledoc """
  The naming survey is a step in the recipe, not a good intention.

  `docs/naming.md` records what IEC 61131-3 and the major vendors call each
  operation, and why logex chose the name it did. This test fails if a mnemonic
  reaches `@instructions`, or a section or type word reaches `Logex.Declarations`,
  or a word that heads a file of another kind reaches `Logex.Declarations.kinds/0`,
  without a stanza there.

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

  test "every section and type word of a declaration line has been surveyed" do
    words = Logex.Declarations.keywords() |> MapSet.new()
    unsurveyed = MapSet.difference(words, surveyed_mnemonics())

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These declaration words are in Logex.Declarations but have no stanza in docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}

    A section or type word is reserved like a mnemonic, and is surveyed like one.
    """
  end

  test "every word that heads a file of another kind has been surveyed (M2-5)" do
    words = Logex.Declarations.kinds() |> MapSet.new()
    unsurveyed = MapSet.difference(words, surveyed_mnemonics())

    # A guard over no words guards nothing: a function block's file is headed by
    # `function_block` (docs/organisation.md §4.3).
    assert "function_block" in words

    assert MapSet.equal?(unsurveyed, MapSet.new()), """
    These words head a file in Logex.Declarations.kinds/0 but have no stanza in
    docs/naming.md:

        #{unsurveyed |> Enum.sort() |> Enum.join(", ")}
    """
  end

  test "the check is one-way: a surveyed but unimplemented mnemonic is allowed" do
    # Surveying an instruction long before building it is the point, so this
    # direction must never fail. Asserted against a synthetic survey rather than
    # the real one: `assert MapSet.subset?(implemented, surveyed)` would restate
    # the test above, and an unsurveyed instruction would then fail twice — the
    # second time under a name pointing at the opposite mistake.
    implemented = Logex.Compiler.instructions() |> Map.keys() |> MapSet.new()
    surveyed_ahead = MapSet.put(implemented, "ton_surveyed_but_not_built")

    assert MapSet.equal?(
             MapSet.difference(implemented, surveyed_ahead),
             MapSet.new()
           ),
           "the guard must ignore stanzas that have no implementation yet"
  end
end
