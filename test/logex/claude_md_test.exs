defmodule Logex.ClaudeMdTest do
  @moduledoc """
  Decision 358: CLAUDE.md, which every agent session loads whole, is a slim index of what
  is there now: the commands, the conventions and a line for each module and test file,
  each module's present rules in its own documentation, the reasons in
  `docs/organisation.md` and the history in `PLAN.md`. Its size is capped, every file of
  `lib/` and `test/` is named in it, and it holds no history.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @claude_md Path.join(@root, "CLAUDE.md")

  # Claude Code warns of a CLAUDE.md over 40,000 characters, as one that costs every session
  # it is loaded into (provisional: the figure is that guidance's, not a measure of ours).
  @cap 40_000

  test "CLAUDE.md is under its cap of 40,000 characters" do
    size = String.length(File.read!(@claude_md))
    assert size < @cap, "CLAUDE.md is #{size} characters, over its cap of #{@cap}"
  end

  test "CLAUDE.md names every file of lib/ and test/" do
    text = File.read!(@claude_md)

    files =
      for path <- Path.wildcard(Path.join(@root, "{lib,test}/**/*.{ex,exs,txt}")),
          do: Path.relative_to(path, @root)

    assert "lib/logex/runtime.ex" in files
    assert "test/logex/claude_md_test.exs" in files
    assert Enum.reject(files, &(text =~ "`#{&1}`")) == []
  end

  test "CLAUDE.md holds no history: no rule told by when it came" do
    text = String.replace(File.read!(@claude_md), ~r/\s+/, " ")

    since =
      Regex.scan(~r/\b[Ss]ince (?:M\d|OE-\d|B\d|decision|fix|the review|20\d\d)[^.;]*/, text)

    assert since == []
  end
end
