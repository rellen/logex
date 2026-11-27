# One reading of a page's Markdown (decision 546 (d); docs/style-guide.md), for every
# script and test that reads a page: scripts/prose.exs, scripts/site.exs,
# scripts/pictures.exs and test/logex/readme_test.exs. A library, with no command of its
# own. Before it each of the four cut a page into prose and code blocks by its own rule,
# and the four differed: a fence one of them did not take turned the rest of the page
# inside out for that one alone. Here a fence is read once, as GitHub reads it:
#
#   - a line of three or more backticks, or tildes, after any indentation, opens a code
#     block; what follows the fence on its line is the block's info string, its language;
#   - the block ends at the next line that holds the same character alone, as many times
#     or more, or at the end of the page;
#   - a fence in a quotation, `> ```text`, a callout's, opens a block too, marked as quoted;
#   - every other line is prose, a comment (a line that is one HTML comment) or blank.
#
# What is wrong with a page's blocks is never raised: it is a problem, `{line, message}`,
# which a script or a test prints as `<page>:<line>: <message>`. Of any page read: a block
# that is not closed, an info string that is not one word, a block closed by a longer
# fence than opened it. Of a page under the writing rules besides: a block fenced with
# tildes, a line Markdown shows as an indented code block, an HTML tag, and a comment that
# does not end on its line; a block of one of those forms would be shown to a reader and
# read by no check.
#
# It also holds what the readers agree on: the kinds of page, the marks a block carries,
# what a `$ mix run` of an example is, the languages of a block the suite does not hold,
# and a page's name in the site. Function clauses alone, no `case`: the examples' harness
# reads through it, and is held to that rule (test/logex/clauses_test.exs).
defmodule Page do
  @moduledoc false

  @manifest "docs/pages.exs"
  # The kinds of page under the writing rules; the first five are a user's, which cite no
  # label of the plan.
  @user [:tutorial, :howto, :reference, :explanation, :readme]
  @ruled @user ++ [:contributor, :adr]
  # The marks a block carries, on the line straight above its fence.
  @mark ~r/^\s*<!-- (file|part of|fragment|unchecked): (\S.*?) -->\s*$/
  # A script's run, `$ mix run scan.exs`; a command that runs one of the repository's own
  # scripts, `$ mix run scripts/draw.exs`, is no example.
  @run ~r/\A\$ mix run (?!scripts\/)(\S+)\n/
  # The languages of a block the suite compares with nothing: a command line, a diagram,
  # Markdown shown as Markdown, and data of another tool.
  @shown ["console", "mermaid", "markdown", "yaml", "json", "diff"]

  @quote ~r/^\s*(?:>\s?)+/
  @fence ~r/^(\s*)(`{3,}|~{3,})(.*)$/
  @comment ~r/^\s*<!--.*-->\s*$/
  @item ~r/^(\s*)(?:[-*+]|\d+[.)])\s+(?=\S)/
  @span ~r/(`+)(.+?)\1(?!`)/
  # A picture, `![alt](path)`, its alternative text holding brackets in pairs, as GitHub
  # reads it, `![The rung of `t[1]`.](../assets/t.svg)`, where `[^\]]*` stopped at the
  # first `]` and read no picture (decision 596, DOC-1's close; RV-34): the one reading of
  # a picture, which scripts/pictures.exs and scripts/prose.exs take from here.
  @picture "!\\[((?:[^\\[\\]]|\\[(?:[^\\[\\]]|\\[[^\\[\\]]*\\])*\\])*)\\]\\(([^)]*)\\)"
  @tag ~r/<\/?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>]*)?\/?>/

  def user, do: @user
  def ruled, do: @ruled
  def ruled?(kind), do: kind in @ruled
  def shown, do: @shown

  # The list of pages, `{path, kind, group}` a page, read from `root`.
  def listed(root \\ ".") do
    {pages, _} = Code.eval_file(Path.join(root, @manifest))
    pages
  end

  # A mark's kind and value, `{"file", "motor.ld"}`, or nil.
  def mark(nil), do: nil
  def mark(line), do: marked(Regex.run(@mark, line))

  defp marked(nil), do: nil
  defp marked([_, what, value]), do: {what, value}

  # The script a block runs, `[shown, name]`, where it begins `$ mix run <script>`, or nil.
  def run(body), do: Regex.run(@run, body)

  # The pictures of a text, `{alt, path}` each, in the order they come, and the one that
  # starts a line, the line's leading spaces before it, or nil.
  def pictures(text),
    do: for([_, alt, path] <- Regex.scan(Regex.compile!(@picture), text), do: {alt, path})

  def picture(line), do: pictured(Regex.run(Regex.compile!("^\\s*" <> @picture), line))

  defp pictured(nil), do: nil
  defp pictured([_, alt, path]), do: {alt, path}

  # A text with each picture made its alternative text alone.
  def unpictured(text), do: Regex.replace(Regex.compile!(@picture), text, "\\1")

  # A page's name in the site, the file ExDoc is given and, its extension apart, the page
  # it builds: README is `readme`; a user's page, under guides/, is named by its file
  # alone, `first-program`; any other page by its whole path, `docs-style-guide`, so that
  # `docs/architecture/runner.md` and `guides/reference/runner.md` are two pages. mix.exs
  # has the same rule, and test/logex/docs_test.exs holds the two together.
  def name("README.md"), do: "readme.md"
  def name("guides/" <> _ = path), do: Path.basename(path)
  def name(path), do: String.replace(path, "/", "-")

  # A line with each code span made a run of `x` of the same length, so that what is
  # inside one is not read as a link, a tag or a table's bar.
  def masked(line),
    do: Regex.replace(@span, line, fn whole, _, _ -> String.duplicate("x", byte_size(whole)) end)

  # ---- the reading ----

  # A page's text read: its items in order, `{:line, n, text, kind}` for a line outside
  # every block, `kind` one of `:prose`, `:comment` and `:blank`, and `{:block, block}`
  # for a code block; and its problems, `{n, :any | :ruled, message}`.
  def read(text) do
    state = %{items: [], problems: [], above: nil, list: 0, blank: true}
    state = walk(String.split(text, "\n"), 1, state)
    %{items: Enum.reverse(state.items), problems: Enum.reverse(state.problems)}
  end

  # A page's blocks, each `%{line, fence, info, lang, body, above, quoted, closed}`:
  # `above` the line straight above the fence, where a mark stands, `lang` the first word
  # of the info string, `body` the block's text, its fence's indentation and its
  # quotation's marks taken off each line.
  def blocks(%{items: items}), do: for({:block, block} <- items, do: block)

  # Each line of a page, `{n, text, kind}`: `:prose`, `:comment` and `:blank` outside a
  # block, `:code` for a block's fences and body.
  def lines(%{items: items}), do: Enum.flat_map(items, &flat/1)

  defp flat({:line, n, text, kind}), do: [{n, text, kind}]

  defp flat({:block, %{line: n, raw: raw}}),
    do: for({text, at} <- Enum.with_index(raw), do: {n + at, text, :code})

  # What is wrong with a page's blocks, `{n, message}`: of any page, and of a page under
  # the writing rules.
  def problems(%{problems: problems}, ruled?),
    do: for({n, scope, message} <- problems, scope == :any or ruled?, do: {n, message})

  defp walk([], _n, state), do: state

  defp walk([line | rest], n, state) do
    {quoted, body} = unquoted(Regex.run(@quote, line), line)
    step(kind(body), {line, body, quoted}, rest, n, state)
  end

  defp unquoted(nil, line), do: {false, line}
  defp unquoted(false, line), do: {false, line}
  defp unquoted([prefix], line), do: {true, String.replace_prefix(line, prefix, "")}

  defp kind(body), do: kind(Regex.run(@fence, body), body)

  defp kind([_, indent, marker, info], body),
    do:
      fence(
        String.starts_with?(marker, "`") and String.contains?(info, "`"),
        indent,
        marker,
        info,
        body
      )

  defp kind(nil, body), do: plain(String.trim(body) == "", Regex.match?(@comment, body))

  # A line of backticks with a backtick after them is a code span's, not a fence.
  defp fence(true, _indent, _marker, _info, body), do: kind(nil, body)
  defp fence(false, indent, marker, info, _body), do: {:fence, indent, marker, String.trim(info)}

  defp plain(true, _comment), do: :blank
  defp plain(false, true), do: :comment
  defp plain(false, false), do: :prose

  defp step({:fence, indent, marker, info}, {line, _body, quoted}, rest, n, state) do
    {inside, after_block} = Enum.split_while(rest, &(not closes?(&1, marker)))
    {closing, after_block} = Enum.split(after_block, 1)

    block = %{
      line: n,
      fence: marker,
      info: info,
      lang: lang(info),
      body: Enum.map_join(inside, "\n", &inner(&1, quoted, indent)) <> "\n",
      above: state.above,
      quoted: quoted,
      closed: closing != [],
      raw: [line | inside] ++ closing
    }

    state =
      state
      |> problem(closing == [], n, :any, unclosed(marker))
      |> problem(longer?(closing, marker), n + length(inside) + 1, :any, longer(marker))
      |> problem(not word?(info), n, :any, info_string(info))
      |> problem(String.starts_with?(marker, "~"), n, :ruled, tildes())

    state = %{state | items: [{:block, block} | state.items], above: nil, blank: false}
    walk(after_block, n + length(block.raw), state)
  end

  defp step(:blank, {line, _body, _quoted}, rest, n, state) do
    state = %{state | items: [{:line, n, line, :blank} | state.items], above: nil, blank: true}
    walk(rest, n + 1, state)
  end

  # A comment is what a block's mark is: the next line's block reads it, its quotation's
  # marks taken off.
  defp step(:comment, {line, body, _quoted}, rest, n, state) do
    state = %{
      state
      | items: [{:line, n, line, :comment} | state.items],
        above: body,
        blank: false
    }

    walk(rest, n + 1, state)
  end

  defp step(:prose, {line, _body, quoted}, rest, n, state) do
    visible = masked(line)

    state =
      state
      |> indented(Regex.run(@item, line), quoted, line, n)
      |> problem(Regex.run(@tag, visible), n)
      |> problem(open_comment?(visible), n, :ruled, open_comment())

    state = %{state | items: [{:line, n, line, :prose} | state.items], above: nil, blank: false}
    walk(rest, n + 1, state)
  end

  defp closes?(line, marker) do
    {_quoted, body} = unquoted(Regex.run(@quote, line), line)
    closing = String.trim(body)

    String.starts_with?(closing, marker) and
      String.trim_leading(closing, String.first(marker)) == ""
  end

  defp longer?([], _marker), do: false

  defp longer?([line], marker) do
    {_quoted, body} = unquoted(Regex.run(@quote, line), line)
    String.trim(body) != marker
  end

  defp inner(line, quoted, indent) do
    {_quoted, body} = unquoted(quoted && Regex.run(@quote, line), line)
    String.replace_prefix(body, indent, "")
  end

  defp lang(info), do: info |> String.split(~r/\s+/, parts: 2) |> hd()
  defp word?(info), do: Regex.match?(~r/^[A-Za-z0-9_+-]*$/, info)

  # A list's item sets where its text starts; a line 4 spaces or more past that, after an
  # empty line, is what Markdown shows as an indented code block; a line at the margin
  # that is no item ends the list.
  defp indented(state, [prefix | _], _quoted, _line, _n), do: %{state | list: byte_size(prefix)}
  defp indented(state, nil, true, _line, _n), do: %{state | list: 0}

  defp indented(state, nil, false, line, n) do
    indent = line |> String.replace("\t", "    ") |> leading()
    margin(indent, state, n)
  end

  defp leading(line), do: byte_size(line) - byte_size(String.trim_leading(line, " "))

  defp margin(0, state, _n), do: %{state | list: 0}

  defp margin(indent, %{list: list, blank: true} = state, n) when indent >= list + 4,
    do: problem(state, true, n, :ruled, indented())

  defp margin(_indent, state, _n), do: state

  defp open_comment?(line), do: Regex.match?(~r/<!--(?!.*-->)/, line)

  defp problem(state, nil, _n), do: state
  defp problem(state, [tag | _], n), do: problem(state, true, n, :ruled, html(tag))

  defp problem(state, false, _n, _scope, _message), do: state

  defp problem(state, true, n, scope, message),
    do: %{state | problems: [{n, scope, message} | state.problems]}

  defp unclosed(marker),
    do: "a code block that is not closed: close it with #{marker} on a line of its own"

  defp longer(marker),
    do:
      "a code block closed by a longer fence than opened it: close it with #{marker}, as " <>
        "it is opened"

  defp info_string(info),
    do:
      "a code block whose fence says `#{info}`: write its language alone after the fence, " <>
        "one word, as in ```elixir"

  defp tildes,
    do: "a code block fenced with tildes: fence it with three backticks, as every other block"

  defp indented,
    do:
      "a line indented by 4 spaces or more after an empty line, which Markdown shows as a " <>
        "code block no check reads: fence the block with three backticks and give it a " <>
        "language, or indent the line less"

  defp html(tag),
    do:
      "the HTML tag `#{tag}`: the site shows a tag as text and no check reads into it. " <>
        "Write Markdown, or write the words as code"

  defp open_comment,
    do:
      "an HTML comment that does not end on its line: a mark is one line, as `<!-- file: motor.ld -->`"
end
