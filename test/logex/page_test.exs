Code.require_file("../../scripts/page.exs", __DIR__)

defmodule Logex.PageTest do
  @moduledoc """
  `scripts/page.exs` (decision 546 (d)), the one reading of a page's Markdown that the
  prose checker, the site's stage, the pictures and the examples' test share: a page cut
  into prose, comments and code blocks as GitHub cuts it, each block with its fence, its
  language, its text and the line above it; what it cannot take as the page means it
  given as a problem with its line, never raised; a page's name in the site; and what a
  mark and an example's run are. A page read by two of the readers is read the same.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  defp read(lines), do: Page.read(Enum.join(lines, "\n") <> "\n")
  defp kinds(read), do: for({n, _text, kind} <- Page.lines(read), do: {n, kind})

  describe "a page's blocks" do
    test "a fence of backticks opens a block, its info string its language; the block " <>
           "ends at the same fence alone; the line above it is kept, where a mark stands" do
      read =
        read([
          "# A page",
          "",
          "<!-- file: motor.ld -->",
          "```text",
          "xic a ote b",
          "",
          "```",
          "After it."
        ])

      assert [block] = Page.blocks(read)

      assert Map.take(block, [:line, :fence, :info, :lang, :body, :above, :quoted, :closed]) ==
               %{
                 line: 4,
                 fence: "```",
                 info: "text",
                 lang: "text",
                 body: "xic a ote b\n\n",
                 above: "<!-- file: motor.ld -->",
                 quoted: false,
                 closed: true
               }

      assert kinds(read) == [
               {1, :prose},
               {2, :blank},
               {3, :comment},
               {4, :code},
               {5, :code},
               {6, :code},
               {7, :code},
               {8, :prose},
               {9, :blank}
             ]

      assert Page.problems(read, true) == []
    end

    test "a fence of four backticks closes at four, so that a block can show a fence; a " <>
           "fence of three with a language after it closes nothing" do
      read =
        read([
          "````markdown",
          "```text",
          "xic a",
          "```",
          "```elixir",
          "````",
          "",
          "```text",
          "b",
          "```"
        ])

      assert [%{line: 1, lang: "markdown", body: body}, %{line: 8, body: "b\n"}] =
               Page.blocks(read)

      assert body == "```text\nxic a\n```\n```elixir\n"
      assert Page.problems(read, true) == []
    end

    test "a block in a list's item and in a callout is read, its indentation and its " <>
           "quotation's marks taken off each line; a callout's is marked quoted" do
      read =
        read([
          "1. A step:",
          "",
          "   ```console",
          "   $ mix test",
          "     indented",
          "   ```",
          "",
          "> #### Note {: .info}",
          ">",
          "> <!-- unchecked: a message -->",
          "> ```text",
          "> not declared",
          "> ```"
        ])

      assert [
               %{line: 3, body: "$ mix test\n  indented\n", quoted: false, above: nil},
               %{line: 11, body: "not declared\n", quoted: true, above: above}
             ] = Page.blocks(read)

      assert above == "<!-- unchecked: a message -->"
      assert Page.problems(read, true) == []
    end

    test "a line of backticks with a code span after it is prose, and a mark with an " <>
           "empty line under it is no block's" do
      read = read(["``` `a` and `b` ```", "", "<!-- file: a.ld -->", "", "```text", "x", "```"])
      assert [%{line: 5, above: nil}] = Page.blocks(read)
      assert hd(Page.lines(read)) == {1, "``` `a` and `b` ```", :prose}
    end
  end

  describe "what is wrong with a page's blocks" do
    test "of any page: a block not closed, a fence that says more than a language, a " <>
           "block closed by a longer fence; each with its line, none raised, the rest read" do
      read =
        read([
          "```elixir title=\"a.exs\"",
          "IO.puts(1)",
          "```",
          "```console",
          "$ ls",
          "`````",
          "```text",
          "open to the end"
        ])

      assert Page.problems(read, false) == [
               {1,
                "a code block whose fence says `elixir title=\"a.exs\"`: write its language " <>
                  "alone after the fence, one word, as in ```elixir"},
               {6,
                "a code block closed by a longer fence than opened it: close it with ```, as it is opened"},
               {7, "a code block that is not closed: close it with ``` on a line of its own"}
             ]

      assert [
               %{lang: "elixir", body: "IO.puts(1)\n", closed: true},
               %{lang: "console", closed: true},
               %{lang: "text", body: "open to the end\n\n", closed: false}
             ] = Page.blocks(read)

      # Every line is given once, in order, whatever is wrong.
      assert Enum.map(Page.lines(read), &elem(&1, 0)) == Enum.to_list(1..9)
    end

    test "of a page under the rules: a block fenced with tildes, an indented code block, " <>
           "an HTML tag, a comment left open; a legacy page's are left" do
      read =
        read([
          "~~~text",
          "x",
          "~~~",
          "",
          "    shown as code",
          "",
          "- An item.",
          "",
          "  Its second paragraph.",
          "",
          "      shown as code in the item",
          "",
          "The lamp is <b>on</b>, `<b>` is code, <https://example.com> is a link.",
          "A comment <!-- that opens",
          "and ends --> here.",
          "\tA tab after a paragraph is its next line."
        ])

      indented =
        "a line indented by 4 spaces or more after an empty line, which Markdown shows as a " <>
          "code block no check reads: fence the block with three backticks and give it a " <>
          "language, or indent the line less"

      assert Page.problems(read, true) == [
               {1,
                "a code block fenced with tildes: fence it with three backticks, as every other block"},
               {5, indented},
               {11, indented},
               {13,
                "the HTML tag `<b>`: the site shows a tag as text and no check reads into it. " <>
                  "Write Markdown, or write the words as code"},
               {14,
                "an HTML comment that does not end on its line: a mark is one line, as " <>
                  "`<!-- file: motor.ld -->`"}
             ]

      assert Page.problems(read, false) == []
      # A block fenced with tildes is still one block, for every reader alike.
      assert [%{lang: "text", fence: "~~~", body: "x\n"}] = Page.blocks(read)
    end

    test "a list's item sets the margin: its own text, a nested item and its paragraph " <>
           "are no code; text at the margin ends the list" do
      read =
        read([
          "1. A step.",
          "",
          "   Its result.",
          "",
          "   - A nested item.",
          "",
          "     Its paragraph.",
          "",
          "Text at the margin.",
          "",
          "     Five spaces, and no list: code."
        ])

      assert [{11, _}] = Page.problems(read, true)
    end
  end

  describe "what the readers agree on" do
    test "a mark is a comment that names what its block is; a run is a block that begins " <>
           "`$ mix run <script>`, but one of the repository's own scripts" do
      assert Page.mark("<!-- file: plant/packing.logex -->") == {"file", "plant/packing.logex"}
      assert Page.mark("  <!-- part of: motor.ld -->  ") == {"part of", "motor.ld"}
      assert Page.mark("<!-- fragment: the call's form -->") == {"fragment", "the call's form"}
      assert Page.mark("<!-- unchecked: a message -->") == {"unchecked", "a message"}

      assert {Page.mark("<!-- rung: motor.ld -->"), Page.mark("text"), Page.mark(nil)} ==
               {nil, nil, nil}

      assert Page.run("$ mix run scan.exs\n1\n") == ["$ mix run scan.exs\n", "scan.exs"]
      assert Page.run("$ mix run scripts/draw.exs\n") == nil
      assert Page.run("$ mix run -e 'IO.puts(1)'\n") == nil
      assert Page.run("1\n$ mix run scan.exs\n") == nil
    end

    test "the kinds under the writing rules are seven, five of them a user's; the " <>
           "languages of a block the suite compares with nothing are six" do
      assert Page.ruled() == [
               :tutorial,
               :howto,
               :reference,
               :explanation,
               :readme,
               :contributor,
               :adr
             ]

      assert Page.user() == [:tutorial, :howto, :reference, :explanation, :readme]
      assert {Page.ruled?(:howto), Page.ruled?(:legacy)} == {true, false}
      assert Page.shown() == ["console", "mermaid", "markdown", "yaml", "json", "diff"]
    end

    test "a page's name in the site: README's is readme, a user's page its file's name, " <>
           "any other page its whole path" do
      assert Enum.map(
               [
                 "README.md",
                 "guides/tutorials/first-program.md",
                 "guides/reference/cheatsheet.cheatmd",
                 "docs/style-guide.md",
                 "docs/README.md",
                 "docs/architecture/runner.md",
                 "docs/adr/0001-programs-as-data.md"
               ],
               &Page.name/1
             ) == [
               "readme.md",
               "first-program.md",
               "cheatsheet.cheatmd",
               "docs-style-guide.md",
               "docs-README.md",
               "docs-architecture-runner.md",
               "docs-adr-0001-programs-as-data.md"
             ]
    end

    test "a line's code spans are masked at their length, so that a link, a tag or a bar " <>
           "inside one is none" do
      assert Page.masked("a `[b](c)` and ``<d> | e`` f") == "a xxxxxxxx and xxxxxxxxxxx f"
    end

    test "the list of pages is read from the root given" do
      assert {"README.md", _kind, :first} = hd(Page.listed(@root))
    end
  end

  test "every page of the repository is read with every line once, and a page under the " <>
         "rules with no problem" do
    for {path, kind, _group} <- Page.listed(@root) do
      text = File.read!(Path.join(@root, path))
      read = Page.read(text)

      assert Enum.map(Page.lines(read), &elem(&1, 1)) == String.split(text, "\n"), path
      assert Page.problems(read, false) == [], path
      assert Page.problems(read, Page.ruled?(kind)) == [], path
    end
  end
end
