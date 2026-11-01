defmodule Logex.ClaudeMdTest do
  @moduledoc """
  Decision 358: CLAUDE.md, which every agent session loads whole, is a slim index of what
  is there now: the commands, the conventions and a line for each module and test file,
  each module's present rules in its own documentation, the reasons in
  `docs/organisation.md` and the history in `PLAN.md`. Its size is capped, every file of
  `lib/` and `test/` is named in it, every file, module and function it names is there,
  and it holds no history.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @claude_md Path.join(@root, "CLAUDE.md")

  # Claude Code warns of a CLAUDE.md over 40,000 characters, as one that costs every session
  # it is loaded into (provisional: the figure is that guidance's, not a measure of ours).
  @cap 40_000

  # What marks history: a numbered decision or fix, the review, the maintainer, a year, a
  # milestone, a work item's label (`M5-14`, `OE-2`, `RV-2`, `B9`) or a commit, seven hex
  # digits or more holding a letter and a digit (`23a5136`), backticked or not.
  @commit ~S"`?(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b`?"
  @item ~S"(?:M\d+-\d+|OE-\d+|RV-\d+|B\d{1,2})\b"
  @mark ~S"(?:decision|fix|the review|the maintainer|20\d\d|Milestone \d|M\d|OE-\d|RV-\d|B\d|" <>
          @commit <> ")"

  # A rule told by when it came: a time word before a mark, "since M5-14", "until decision
  # 228", "as of RV-2", "after `23a5136`"; a word of change tied to one, "added in M5-14";
  # and a work item's label or a commit anywhere, "(M5-14)", which an index of what is there
  # now has no use for (provisional: a label as a pointer into `PLAN.md` is refused too).
  @path ~r{^(?:(?:lib|test|scripts|docs|\.github)/(?!\d+(?:,\d+)*$)|\.\w+-[\w-]+$|[\w.-]+\.(?:ex|exs|md|nix|yml|sh|txt)$)}

  @history [
    ~r/\b(?i:since|until|till|as of|after|before|from|up to)\s+#{@mark}[^.;]*/,
    ~r/\b(?i:added|landed|introduced|changed|built|fixed|removed|dropped|superseded|retired|renamed|new)\s+(?i:in|by|with|at|since|on)\s+#{@mark}[^.;]*/,
    ~r/\b#{@item}/,
    ~r/(?<![\w\/.#-])#{@commit}/
  ]

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

  test "every file, module and function CLAUDE.md names is there" do
    text = File.read!(@claude_md)
    assert "lib/logex/runtime.ex" in paths(text)
    assert {Logex.Runtime, :call, 4} in functions(text)
    assert missing(text) == []
  end

  test "the names check finds a file, a module or a function that is not there" do
    text = """
    - `lib/logex/ghost.ex` — `Logex.Ghost`, `Logex.Runtime.call/5`, `Logex.Tag.new!/4,9`
      and `ghost_test.exs`, beside `lib/logex/runtime.ex`, `Logex.Runtime.call/4`,
      `Logex.Declarations.is_class/1`, a guard, `mix.exs`, `.tool-versions`,
      `edit_test.exs`, `scripts/gate.sh [log]`, `Logex.Edit`'s `test/2` and `<word>.ld`;
      and after a span that holds a backtick, ``### `mnemonic` ``, `docs/ghost.md`.
    """

    assert missing(text) == [
             "lib/logex/ghost.ex",
             "ghost_test.exs",
             "docs/ghost.md",
             "Logex.Ghost",
             "Logex.Runtime.call/5",
             "Logex.Tag.new!/9"
           ]
  end

  test "CLAUDE.md holds no history: no rule told by when it came" do
    assert history(File.read!(@claude_md)) == []
  end

  # The history check's own cases: each way a rule is told by when it came, found, and
  # the present tense an index needs, a word "before" or "after" among it, passed.
  test "the history check finds a rule told by when it came, however it is phrased" do
    told = [
      "Since M5-14 an array of instances is a tuple.",
      "Until decision 228 a subnormal was a lex error.",
      "As of RV-2 a rung that writes nothing is refused.",
      "since RV-2 too.",
      "an array of instances (M5-14) was added in M5-14.",
      "the scan costs what it did after `23a5136`.",
      "changed again after the maintainer's answers of 2026-10-30.",
      "a plain timer scans as it did at a8af419, before long timers.",
      "the dint wrapped since Milestone 5.",
      "landed with OE-2."
    ]

    assert Enum.reject(told, &(history(&1) != [])) == []

    present = [
      "Every tag is declared, `var aa bool` before the first rung.",
      "The compiler refuses anything after it on its path, as after `ton`.",
      "Milestones 5 and 6's done sentences, from text and files on disk.",
      "Cite them as `decision 271` and `fix F11`.",
      "The review of the whole codebase is `docs/review-2026-11-01.md`.",
      "On anything older `mix` aborts before it runs.",
      "A `dint` holds 2147483647 and a `ulint` 18446744073709551615."
    ]

    assert Enum.filter(present, &(history(&1) != [])) == []
  end

  defp history(text) do
    flat = String.replace(text, ~r/\s+/, " ")
    for pattern <- @history, [found | _] <- Regex.scan(pattern, flat), do: found
  end

  # What CLAUDE.md names that is not there: a path, a file named alone, which `lib/`,
  # `test/`, `scripts/` or `docs/` holds, a module and a function by its arity.
  defp missing(text) do
    files = for path <- paths(text), not there?(path), do: path
    modules = for module <- modules(text), not Code.ensure_loaded?(module), do: inspect(module)

    functions =
      for {module, name, arity} <- functions(text),
          Code.ensure_loaded?(module),
          not function_exported?(module, name, arity),
          not macro_exported?(module, name, arity),
          do: "#{inspect(module)}.#{name}/#{arity}"

    files ++ modules ++ functions
  end

  # Each word of a code span shaped as a file: a path under one of the checkout's
  # directories, a dotfile such as `.tool-versions`, or a name with an extension, `mix.exs`
  # or `edit_test.exs`; a word with a placeholder, `<word>.ld`, is none. A span is
  # Markdown's, closed by a run of backticks as long as the one that opens it, so that one
  # that holds a backtick, ``### `mnemonic` ``, leaves the spans after it paired.
  defp paths(text) do
    for [_, _run, token] <- Regex.scan(~r/(`+)(.+?)(?<!`)\1(?!`)/s, text),
        word <- String.split(token),
        not String.contains?(word, ["<", ">"]),
        Regex.match?(@path, word),
        uniq: true,
        do: word
  end

  defp there?(path),
    do:
      File.exists?(Path.join(@root, path)) or
        Path.wildcard(Path.join(@root, "{lib,test,scripts,docs}/**/#{path}")) != []

  defp modules(text) do
    for [name] <- Regex.scan(~r/\bLogex(?:\.[A-Z]\w*)*/, text),
        not String.contains?(name, "Test"),
        uniq: true,
        do: Module.concat([name])
  end

  # A function by its module, `Logex.Runtime.call/4`, each arity of `Logex.Tag.new!/4,5`.
  defp functions(text) do
    for [_, module, name, arities] <-
          Regex.scan(~r/\b(Logex(?:\.[A-Z]\w*)+)\.([a-z_]\w*[!?]?)\/(\d+(?:,\d+)*)/, text),
        arity <- String.split(arities, ","),
        uniq: true,
        do: {Module.concat([module]), String.to_atom(name), String.to_integer(arity)}
  end
end
