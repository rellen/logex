# Checks the writing rules a script can measure (decision 546 (d); docs/style-guide.md),
# on the pages of docs/pages.exs that are under the rules, every kind but `:legacy`. Run
# from the project's root:
#
#     elixir scripts/prose.exs                     # every page under the rules: the suite runs this
#     elixir scripts/prose.exs <page>...           # those pages, each by its kind in docs/pages.exs
#     elixir scripts/prose.exs --kind <kind> <file>...   # files the list does not have, a draft's
#     elixir scripts/prose.exs --review <page>...  # and each place a reviewer must read
#
# A failure is a line on stderr, `<file>:<line>: [<rule>] <what> Write: <fix>`, and the exit
# code is 1. For each page it prints one line on stdout: its failures, its words and
# sentences, and the counts a reviewer reads. The rules, each by its name:
#
#   sentence      a sentence of more than 25 words; in a step, an item of a numbered list,
#                 of more than 20
#   paragraph     a paragraph of more than 6 sentences
#   word          a word docs/style-guide.md replaces with a plainer one, with the plain word
#   modal         should, may, might, could, would, shall, ought to
#   latin         e.g., i.e., etc., viz., cf., N.B., with or without their dots
#   contraction   don't, it's, they're and their like
#   semicolon     a semicolon in prose
#   dash          an em dash, an en dash, a double hyphen, a hyphen between spaces or an
#                 arrow in prose
#   perfect       a perfect tense: has written the tag, have been, had run
#   progressive   the -ing form of a verb as a verb: is running
#   need          "need to": "need" is a noun only
#   manner        a form of the house manner the pages must not have, with the plain form
#   easy          simply, just, obviously, easy, easily, of course
#   history       now, no longer, currently, today, not yet, so far: the present rule only
#   pointer       above, below, the following, the next section: a link to the section by
#                 its name, or "more than", "less than"
#   number        a number written as a word, twice and once among them: digits
#   label         in a user page, a plan label or a decision's number: M5-9, RV-21, decision 514
#   heading       a heading deeper than level 3, but a callout's
#   language      a code block with no language
#   block         what scripts/page.exs cannot read as the page means it: a code block
#                 not closed, a fence that says more than a language, a block fenced with
#                 tildes or shown by indentation, an HTML tag, a comment left open
#   alt           a picture with no alt text
#   callout       a callout whose class is not warning, error, info, tip or neutral
#   see-also      a tutorial, a how-to guide, a reference or an explanation whose last
#                 section is not "See also"
#   length        a page that is not a reference of more than 2,000 words, counted as the
#                 page's line counts them (decision 589)
#
# What is not prose, and so is not read: a fenced code block; a code span, which counts as
# one word of its sentence; a link's or a picture's target, its text being prose; an HTML
# comment; a table's row of dashes; an attribute list, `{: .warning}`. A table's cell is
# read as a paragraph of its own. In a contributor page and a decision record, which
# quote the older documents, text between double quotation marks is a quotation: the word
# rules do not read it, its words count in its sentence, and the page's line counts the
# quotations. A user page has no such leave: what it quotes is a message, and a message
# is written as code. A word that is a term of guides/reference/glossary.md, a heading of
# level 3 there, is never refused by the word rules, in any of its forms, `enables` for
# `enable`: the glossary is the one list of the technical words a page may use. A word of
# the `word` rule straight after an article, "the display", is a noun and is left.
#
# What it cannot see, it counts for a reviewer and never fails (`--review` gives each
# place): a passive verb, which a script cannot tell from a state ("the rung is true");
# a term of the glossary a page other than the glossary uses with no link to the glossary,
# which the page perhaps defines itself; a block marked `unchecked`; and a block the suite
# compares with nothing, a diagram, data or a command line. It reads no dictionary: it
# does not certify a page as Simplified Technical English, and a wrong sense of a word, a
# group of four nouns, a missing article or a new form of the house manner passes it. The
# forms it refuses are the literal ones of its lists, examples of the manner and not its
# limit. There is no way to switch it off inside a page. A script, not a test: it uses
# `case`, and function clauses for the rest.
Code.require_file("page.exs", __DIR__)

defmodule Prose do
  @moduledoc false

  @glossary "guides/reference/glossary.md"
  # The user pages a reader goes on from: each ends with "See also".
  @onward [:tutorial, :howto, :reference, :explanation]
  @classes ~w(warning error info tip neutral)
  # The most words a page that is not a reference has (decision 589).
  @most 2000

  # A word of the `word` rule that stands straight after one of these is a noun, "the
  # display", "a power supply", and is left: the rule is of verbs.
  @noun "(?<!\\bthe )(?<!\\ba )(?<!\\ban )(?<!\\bits )(?<!\\btheir )(?<!\\beach )" <>
          "(?<!\\bevery )(?<!\\bpower )"

  # A word the style guide replaces, with what to write: each a stem and the endings it
  # is read with.
  @plain [
    {"utili[sz]e[sd]?|utili[sz]ing|employ(?:s|ed|ing)?", ~s("use")},
    {"commenc(?:e|es|ed|ing)|initiat(?:e|es|ed|ing)", ~s("start")},
    {"ceas(?:e|es|ed|ing)|halt(?:s|ed|ing)?|terminat(?:e|es|ed|ing)", ~s("stop")},
    {"display(?:s|ed|ing)?|indicat(?:e|es|ed|ing)|demonstrat(?:e|es|ed|ing)", ~s("show")},
    {"ensur(?:e|es|ed|ing)|verif(?:y|ies|ied) that", ~s("make sure")},
    {"prior to", ~s("before")},
    {"approximately|regarding", ~s("about")},
    {"however", ~s("but")},
    {"additionally|furthermore|moreover", ~s("also")},
    {"whether|in the event that", ~s("if")},
    {"due to the fact that", ~s("because")},
    {"subsequently", ~s("then")},
    {"perform(?:s|ed|ing)?|carr(?:y|ies|ied|ying) out", ~s("do")},
    {"execut(?:e|es|ed|ing)", ~s("do", or "run" for a program or a task)},
    {"obtain(?:s|ed|ing)?|retriev(?:e|es|ed|ing)", ~s("get")},
    {"provid(?:e|es|ed|ing)|suppl(?:y|ies|ied|ying)", ~s("give")},
    {"inform(?:s|ed|ing)?|notif(?:y|ies|ied|ying)", ~s("tell")},
    {"allow(?:s|ed|ing)?|permit(?:s|ted|ting)?|enabl(?:e|es|ed|ing)", ~s("let")},
    {"in order to", ~s("to")}
  ]

  # "since" for a reason stands first in its clause: at the start of a sentence, or after
  # a comma. "The time since the last scan" is of time, and is left.
  @since {"word", "(?:\\A|(?<=[.!?:] )|(?<=, ))since\\b",
          ~s("because" for a reason; for a time, "after" or "from", after the main clause)}

  # The forms of the house manner, by the plain form the style guide gives: the literal
  # forms, examples of the manner.
  @manner [
    {"\\bof (?:its|their|your|his|her) own\\b|\\ball (?:its|their) own\\b",
     ~s("a separate process", "a separate file")},
    {"\\btold\\b", ~s("logex reports ...", "the message says ...")},
    {"\\bheld to\\b|\\bholds? (?:each|every) [^.;:]{1,30}? to (?:its|their)\\b|" <>
       "\\bpinned (?:whole|by|to|in)\\b|\\bpins (?:the|its|each|every|a|an)\\b",
     ~s("the test compares ... with ...", "must be the same as")},
    {"\\bas (?:built|written|shipped|given)\\b|\\bas it stands\\b|\\bas \\w+['’]s is\\b",
     "what the thing is"},
    {"\\bthe one (?:table|walk|place|list|rule|reading|check|way|file|test|record)\\b",
     ~s("one table", "the only place")},
    {"\\bsa(?:ys?|id) so\\b", ~s("its documentation states this")},
    {"\\b\\w+['’]s \\w+['’]s", "each thing in a separate sentence"},
    {"\\bgone\\b|\\bwent (?:late|wrong)\\b",
     ~s("a late write", "a clock that gives a wrong value")},
    {"\\bland(?:s|ed|ing)\\b",
     ~s("is available", or nothing: history goes to the contributor pages)},
    {"\\bnothing (?:else )?(?:\\w+ ){0,3}?escapes?\\b|\\bnothing of\\b",
     ~s("logex returns no other error", "no part of logex runs")},
    {"\\bmistakes?\\b", ~s("an error in the source text", "a wrong argument")},
    {"\\bhonest about\\b|\\bto be honest\\b|\\bsaid plainly\\b|\\bplainly\\b|\\bin short\\b|" <>
       "\\bnote that\\b|\\bas you can see\\b|\\bit is worth\\b|\\bin other words\\b|" <>
       "\\bthat said\\b|\\bin summary\\b|\\bin conclusion\\b|\\bkeep in mind\\b|" <>
       "\\bwhich is to say\\b", "nothing: delete it"},
    {", each (?:a|an|with|its|by|in|of|on|one)\\b|, every one\\b|, all of them\\b|" <>
       "\\bone \\w+ a \\w+\\b|\\bone a \\w+\\b",
     ~s(a full sentence: "Each step returns a report.")}
  ]

  @participles "written|given|taken|made|done|gone|seen|known|shown|run|set|put|read|" <>
                 "sent|built|kept|held|left|lost|found|got|become|begun|chosen|come|drawn|" <>
                 "fallen|grown|hidden|risen|spoken|told|met|had|\\w+ed"

  # What follows the participle of a perfect tense: its object's article or a pronoun, a
  # preposition, code, a number, or the end of the clause. A noun straight after it makes
  # the participle an adjective, "has retained tags", "has read access", and is left.
  @object "(?=\\s+(?:the|a|an|its|their|his|her|this|that|these|those|each|every|all|no|it|" <>
            "them|to|by|in|on|at|from|with|for|of|into|up|out|off|over|CODE|\\d+)\\b|" <>
            "\\s*[.,;:!?)]|\\s*$)"

  # An -ing form after "is" that is an adjective or a noun, and no verb.
  @states "nothing|something|anything|everything|thing|string|during|missing|rising|" <>
            "falling|ascending|descending|leading|trailing|remaining|misleading|" <>
            "surprising|pending|matching|existing|outstanding"

  @rules [
           {"modal", "\\b(?:should|may|might|could|would|shall|ought to)\\b",
            ~s("must" for a rule, "can" for an ability, "possibly" for a doubt)},
           {"latin",
            "\\b(?:e\\.?g\\b\\.?|i\\.?e\\b\\.?|etc\\b\\.?|viz\\b\\.?|vs\\b\\.?|cf\\.|N\\.B\\.)",
            ~s("for example", "that is", "and so on", "and not")},
           {"contraction",
            "\\b(?:\\w+n['’]t|(?:it|that|there|here|what|who|he|she|let)['’]s|\\w+['’](?:re|ve|ll|d)|I['’]m)\\b",
            "the two words in full"},
           {"semicolon", ";", "two sentences"},
           {"dash", "—|–|(?<=\\s)--(?=\\s)|(?<=\\S) - (?=\\S)|->|=>|→|⇒|←",
            "a full stop and a new sentence, or \"to\""},
           {"perfect",
            "\\b(?:has|have|had|having)\\s+(?:\\w+ly\\s+|not\\s+|never\\s+)?(?:been\\b|(?:#{@participles})\\b#{@object})",
            "the simple past or the simple present"},
           {"progressive",
            "\\b(?:is|are|was|were|am|be|been)\\s+(?:\\w+ly\\s+|not\\s+)?(?!(?:#{@states})\\b)\\w+ing\\b",
            ~s(the simple tense: "the task runs")},
           {"need", "\\bneed(?:s|ed)? to\\b", ~s("must", or "it is necessary to")},
           {"easy", "\\b(?:simply|just|obviously|easy|easily|of course)\\b",
            "nothing: delete it"},
           {"history",
            "\\b(?:now|no longer|currently|at present|previously|formerly|so far|as of|" <>
              "until recently|until now|today|any ?more|at the moment|not yet|for now)\\b|" <>
              "(?<!\\bis )(?<!\\bare )(?<!\\bwas )(?<!\\bwere )(?<!\\bbe )(?<!\\bbeen )" <>
              "(?<!\\bnot )\\bused to\\b", "the present rule only"},
           {"pointer",
            "\\b(?:above|below)\\b|\\bthe following\\b|\\bfurther (?:down|up)\\b|" <>
              "\\bthe (?:next|previous|earlier|later) (?:section|page|table|paragraph)\\b",
            ~s(a link to the section by its name, or "more than", "less than")},
           {"number",
            "\\b(?:zero|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|" <>
              "thirty|forty|fifty|sixty|hundred|thousand|dozen|twice|once)\\b",
            ~s(the number in digits: "2 scans", "1 time")}
         ] ++
           for({pattern, fix} <- @plain, do: {"word", "#{@noun}\\b(?:#{pattern})\\b", fix}) ++
           [@since] ++ for({pattern, fix} <- @manner, do: {"manner", pattern, fix})

  @label {"label",
          "\\bM\\d+-\\d+\\b|\\b(?:RV|OE|DOC)-\\d+\\b|\\bdecisions? \\d+|\\bfix F\\d+\\b|§\\s*\\d|\\bMilestone \\d+|" <>
            "\\((?:[A-Z]{1,2}\\d+(?:-\\d+)?)(?:, [A-Z]{1,2}\\d+(?:-\\d+)?)*\\)",
          "nothing: a user page holds the present rule, and no label of the plan"}

  @passive "\\b(?:is|are|was|were|be|been|being)\\s+(?:\\w+ly\\s+|not\\s+)?(?:written|given|taken|made|done|seen|known|shown|run|set|put|read|sent|built|kept|held|left|lost|found|\\w+ed)\\b"

  def main(args) do
    {review, args} = flag(args, "--review")
    pages = pages(args)
    terms = terms()

    # Each rule's pattern is compiled once, for every page.
    tools = %{
      terms: terms,
      mentions: for(term <- terms, do: {term, mention(term)}),
      user: compiled([@label | @rules]),
      other: compiled(@rules),
      passive: Regex.compile!(@passive, "iu")
    }

    results = for {file, kind} <- pages, do: page(file, kind, tools)
    for %{failures: failures} <- results, failure <- failures, do: IO.puts(:stderr, failure)
    for result <- results, do: report(result, review)
    exit_with(Enum.count(results, &(&1.failures != [])))
  end

  defp exit_with(0), do: :ok
  defp exit_with(_failed), do: System.halt(1)

  defp compiled(rules),
    do: for({rule, pattern, fix} <- rules, do: {rule, Regex.compile!(pattern, "iu"), fix})

  defp flag(args, flag), do: {flag in args, args -- [flag]}

  defp pages(["--kind", kind | [_ | _] = files]), do: for(file <- files, do: {file, kind(kind)})
  defp pages([]), do: for({path, kind} <- listed(), Page.ruled?(kind), do: {path, kind})

  defp pages(files) do
    listed = Map.new(listed())
    for file <- files, do: {file, Map.get(listed, file) || unlisted(file)}
  end

  defp listed, do: for({path, kind, _group} <- Page.listed(), do: {path, kind})

  defp kind(name), do: known(Enum.find(Page.ruled(), &(Atom.to_string(&1) == name)), name)

  defp known(nil, name), do: usage("#{name} is no kind of page under the rules")
  defp known(kind, _name), do: kind

  defp unlisted(file),
    do: usage("#{file} is not in docs/pages.exs: add its line, or give its kind with --kind")

  defp usage(why) do
    IO.puts(:stderr, "prose: #{why}")

    IO.puts(
      :stderr,
      "usage: elixir scripts/prose.exs [--review] [<page>... | --kind <kind> <file>...]\n" <>
        "kinds: #{Enum.join(Page.ruled(), ", ")}"
    )

    System.halt(2)
  end

  # The glossary's terms, each a heading of level 3, lowercased.
  def terms, do: terms(File.read(@glossary))

  defp terms({:error, _}), do: MapSet.new()

  defp terms({:ok, text}) do
    for line <- String.split(text, "\n"),
        [_, term] <- [Regex.run(~r/^###\s+(.+?)\s*$/, line)],
        into: MapSet.new(),
        do: term |> String.replace("`", "") |> String.downcase()
  end

  # ---- a page ----

  def page(file, kind, %{terms: terms, passive: passive} = tools) do
    text = File.read!(file)
    read = Page.read(text)
    {units, structure} = units(read)
    units = Enum.map(units, &unit(&1, quotes?(kind)))
    blocks = Page.blocks(read)
    words = units |> Enum.map(&count(&1.plain)) |> Enum.sum()

    failures =
      structure ++
        for({n, message} <- Page.problems(read, true), do: {n, "#{n}: [block] #{message}"}) ++
        Enum.flat_map(units, &lengths/1) ++
        Enum.flat_map(units, &words(&1, rules(tools, kind in Page.user()), terms)) ++
        see_also(kind in @onward, read) ++
        long_page(kind, words)

    used =
      for unit <- units,
          {term, regex} <- tools.mentions,
          Regex.match?(regex, unit.plain),
          uniq: true,
          do: term

    %{
      file: file,
      failures: failures |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&"#{file}:#{elem(&1, 1)}"),
      words: words,
      sentences: units |> Enum.map(&length(&1.sentences)) |> Enum.sum(),
      quotations: units |> Enum.map(& &1.quotations) |> Enum.sum(),
      unchecked: for(%{above: above} = block <- blocks, unchecked?(above), do: block),
      uncompared:
        for(
          %{lang: lang, body: body, above: above} = block <- blocks,
          lang in Page.shown() and Page.run(body) == nil and Page.mark(above) == nil,
          do: block
        ),
      passive: for(unit <- units, hit <- hits(unit.read, passive, unit), do: hit),
      unlinked: unlinked(file, used, linked(text, terms))
    }
  end

  defp rules(tools, true), do: tools.user
  defp rules(tools, false), do: tools.other

  # A contributor page and a decision record quote the older documents; a user page
  # quotes a message, and writes it as code.
  defp quotes?(kind), do: kind not in Page.user()

  defp unchecked?(above), do: match?({"unchecked", _}, Page.mark(above))

  defp unlinked(@glossary, _used, _linked), do: []
  defp unlinked(_file, used, linked), do: Enum.sort(used -- linked)

  defp report(result, review) do
    IO.puts(
      "#{result.file}: #{length(result.failures)} failures; #{result.words} words, " <>
        "#{result.sentences} sentences; to review: #{length(result.passive)} passive, " <>
        "#{length(result.unlinked)} glossary terms with no link, #{result.quotations} " <>
        "quotations, #{length(result.unchecked)} blocks unchecked, " <>
        "#{length(result.uncompared)} blocks compared with nothing"
    )

    review(review, result)
  end

  defp review(false, _result), do: :ok

  defp review(true, result) do
    for {line, text} <- result.passive,
        do: IO.puts("  #{result.file}:#{line}: passive? \"#{text}\": say who or what does it")

    for %{line: line, lang: lang} <- result.unchecked,
        do: IO.puts("  #{result.file}:#{line}: a `#{lang}` block marked unchecked: read it")

    for %{line: line, lang: lang} <- result.uncompared,
        do: IO.puts("  #{result.file}:#{line}: a `#{lang}` block the suite compares with nothing")

    named(result.unlinked, result.file)
  end

  defp named([], _file), do: :ok

  defp named(unlinked, file),
    do: IO.puts("  #{file}: no link to the glossary for: #{Enum.join(unlinked, ", ")}")

  # ---- the units of a page: paragraphs, items, cells, headings ----

  # Each unit `%{kind, lines: [{n, text}]}`, and the failures of the page's structure,
  # each `{line, "line: [rule] ..."}`.
  def units(read) do
    state = %{unit: nil, units: [], failures: []}
    state = flush(Enum.reduce(read.items, state, &item/2))
    {Enum.reverse(state.units), Enum.reverse(state.failures)}
  end

  defp item({:block, %{info: "", line: n}}, state) do
    fail(
      flush(state),
      n,
      "language",
      "a code block with no language.",
      "its language after the fence: elixir, text, console"
    )
  end

  defp item({:block, _block}, state), do: flush(state)
  defp item({:line, _n, _line, :comment}, state), do: flush(state)
  defp item({:line, _n, _line, :blank}, state), do: flush(state)

  defp item({:line, n, line, :prose}, state) do
    quoted? = String.match?(line, ~r/^\s*>/)
    body = String.replace(line, ~r/^\s*(?:>\s?)+/, "")
    prose(shape(body), body, n, quoted?, state)
  end

  # What a line of prose is: a heading, a table's row, a list's item, or text.
  defp shape(body) do
    heading(Regex.run(~r/^(\#{1,6})\s+(.*)$/, body)) ||
      row(String.match?(body, ~r/^\s*\|/), String.match?(body, ~r/^\s*\|?\s*:?-{3,}/)) ||
      listed(Regex.run(~r/^\s*(?:([-*+])|(\d+[.)]))\s+(.*)$/, body)) || :text
  end

  defp heading(nil), do: nil
  defp heading([_, marks, title]), do: {:heading, byte_size(marks), title}

  defp row(false, _dashes), do: nil
  defp row(true, true), do: :dashes
  defp row(true, false), do: :row

  defp listed(nil), do: nil
  defp listed([_, "", _number, text]), do: {:step, text}
  defp listed([_, _bullet, _, text]), do: {:item, text}

  defp prose({:heading, depth, title}, _body, n, quoted?, state) do
    callout = Regex.run(~r/\{:\s*\.([\w-]+)\s*\}\s*$/, title)
    state = headed(flush(state), n, depth, quoted? and callout != nil, callout)
    %{state | units: [%{kind: :heading, lines: [{n, title}]} | state.units]}
  end

  defp prose(:dashes, _body, _n, _quoted?, state), do: flush(state)

  defp prose(:row, body, n, _quoted?, state) do
    state = flush(state)
    cells = for cell <- String.split(Page.masked(body), "|"), String.trim(cell) != "", do: cell
    cells = for cell <- unmask(cells, body), do: %{kind: :cell, lines: [{n, cell}]}
    %{state | units: Enum.reverse(cells) ++ state.units}
  end

  defp prose({kind, text}, _body, n, _quoted?, state),
    do: %{flush(state) | unit: %{kind: kind, lines: [{n, text}]}}

  defp prose(:text, body, n, _quoted?, %{unit: nil} = state),
    do: %{state | unit: %{kind: :paragraph, lines: [{n, body}]}}

  defp prose(:text, body, n, _quoted?, %{unit: unit} = state),
    do: %{state | unit: %{unit | lines: [{n, body} | unit.lines]}}

  defp flush(%{unit: nil} = state), do: state

  defp flush(%{unit: unit} = state),
    do: %{state | unit: nil, units: [%{unit | lines: Enum.reverse(unit.lines)} | state.units]}

  defp fail(state, n, rule, what, fix),
    do: %{state | failures: [{n, "#{n}: [#{rule}] #{what} Write: #{fix}"} | state.failures]}

  # A callout's heading is of any level, and its class one of the five; any other
  # heading is of level 3 at the deepest.
  defp headed(state, n, _depth, true, [_, class]), do: classed(class in @classes, state, n, class)
  defp headed(state, n, depth, false, _callout) when depth > 3, do: deep(state, n, depth)
  defp headed(state, _n, _depth, false, _callout), do: state

  defp classed(true, state, _n, _class), do: state

  defp classed(false, state, n, class) do
    fail(
      state,
      n,
      "callout",
      "a callout of the class .#{class}.",
      "one of .#{Enum.join(@classes, ", .")}"
    )
  end

  defp deep(state, n, depth) do
    fail(
      state,
      n,
      "heading",
      "a heading of level #{depth}.",
      "level 3 at the deepest, or a new page"
    )
  end

  # A row's cells cut where the masked row has its bars, so that a bar in a code span cuts
  # nothing.
  defp unmask(cells, body) do
    masked = Page.masked(body)

    {cells, _} =
      Enum.map_reduce(cells, masked, fn cell, rest ->
        [before, after_cell] = String.split(rest, cell, parts: 2)
        at = byte_size(masked) - byte_size(rest) + byte_size(before)
        {binary_part(body, at, byte_size(cell)), after_cell}
      end)

    cells
  end

  # ---- a unit read: its plain text, its sentences, the place of each of its bytes ----

  defp unit(%{kind: kind, lines: lines}, quotes?) do
    cleaned = for {n, text} <- lines, do: {n, clean(text)}
    plain = Enum.map_join(cleaned, " ", &elem(&1, 1))

    {starts, _} =
      Enum.map_reduce(cleaned, 0, fn {n, text}, at -> {{at, n}, at + byte_size(text) + 1} end)

    %{
      kind: kind,
      line: elem(hd(lines), 0),
      plain: plain,
      starts: starts,
      read: unquoted(quotes?, plain),
      quotations: quotations(quotes?, plain),
      sentences: sentences(plain),
      alts: for({n, text} <- lines, alt <- alts(text), do: {n, alt})
    }
  end

  # A line's prose: a code span one word, a picture its alt text, a link its text, no
  # attribute list, tag, character entity or emphasis mark.
  defp clean(text) do
    text
    |> then(&Regex.replace(~r/(`+)(.+?)\1(?!`)/, &1, " CODE "))
    |> then(&Regex.replace(~r/!\[([^\]]*)\]\([^)]*\)/, &1, "\\1"))
    |> then(&Regex.replace(~r/\[([^\]]*)\]\([^)]*\)/, &1, "\\1"))
    |> then(&Regex.replace(~r/<https?:[^>]*>|https?:\/\/\S+/, &1, " LINK "))
    |> then(&Regex.replace(~r/\{:[^}]*\}/, &1, ""))
    |> then(&Regex.replace(~r/<\/?[A-Za-z][^>]*>/, &1, ""))
    |> then(&Regex.replace(~r/&#?\w+;/, &1, " "))
    |> then(&Regex.replace(~r/\*+|(?<![\p{L}\p{N}])_+|_+(?![\p{L}\p{N}])/u, &1, ""))
    |> then(&Regex.replace(~r/\s+/, &1, " "))
    |> String.trim()
  end

  defp alts(text) do
    for [_, alt] <- Regex.scan(~r/!\[([^\]]*)\]\(/, Page.masked(text)), do: String.trim(alt)
  end

  @quotation ~r/"[^"]*"|“[^”]*”/u

  # A quotation's words made blanks of the same length: the word rules do not read them.
  defp unquoted(false, plain), do: plain

  defp unquoted(true, plain),
    do: Regex.replace(@quotation, plain, &String.duplicate(" ", byte_size(&1)))

  defp quotations(false, _plain), do: 0
  defp quotations(true, plain), do: length(Regex.scan(@quotation, plain))

  defp sentences(plain) do
    plain
    |> String.split(~r/(?<=[.!?])["”')\]]*\s+(?=["“'(\[]*[\p{L}\p{N}])|(?<=:)\s*$/u, trim: true)
    |> Enum.reject(&(count(&1) == 0))
  end

  defp count(text), do: length(Regex.scan(~r/[\p{L}\p{N}][\p{L}\p{N}'’\/.-]*/u, text))

  defp line_at(unit, at) do
    unit.starts |> Enum.take_while(fn {start, _n} -> start <= at end) |> List.last() |> elem(1)
  end

  # ---- the rules ----

  defp lengths(%{kind: :heading}), do: []

  defp lengths(unit) do
    {long, _} =
      Enum.flat_map_reduce(unit.sentences, 0, fn sentence, from ->
        {at, _} = :binary.match(unit.plain, sentence, scope: {from, byte_size(unit.plain) - from})

        {long(count(sentence), limit(unit.kind), line_at(unit, at), unit.kind),
         at + byte_size(sentence)}
      end)

    pictures =
      for {n, ""} <- unit.alts do
        {n,
         "#{n}: [alt] a picture with no alt text. Write: what the picture shows, between the brackets of `![...](...)`"}
      end

    long ++ paragraph(unit, length(unit.sentences)) ++ pictures
  end

  defp limit(:step), do: 20
  defp limit(_kind), do: 25

  defp long(words, limit, _n, _kind) when words <= limit, do: []

  defp long(words, limit, n, kind) do
    [
      {n,
       "#{n}: [sentence] #{sentence(kind)} of #{words} words: #{limit} is the limit. Write: two sentences, or a list"}
    ]
  end

  defp sentence(:step), do: "a step's sentence"
  defp sentence(_kind), do: "a sentence"

  defp paragraph(%{kind: kind, line: line}, sentences)
       when kind in [:paragraph, :step, :item] and sentences > 6 do
    [
      {line,
       "#{line}: [paragraph] a paragraph of #{sentences} sentences: 6 is the limit. Write: two paragraphs, one topic each"}
    ]
  end

  defp paragraph(_unit, _sentences), do: []

  defp words(unit, rules, terms) do
    for {rule, regex, fix} <- rules,
        {line, text} <- hits(unit.read, regex, unit),
        not term?(String.downcase(text), terms),
        do: {line, "#{line}: [#{rule}] \"#{text}\". Write: #{fix}"}
  end

  # A word is a term of the glossary in any of its forms: `enables`, `enabled` and
  # `enabling` for `enable`.
  defp term?(word, terms) do
    forms =
      [word, String.trim_trailing(word, "s"), String.trim_trailing(word, "d")] ++
        [String.replace_suffix(word, "ed", ""), String.replace_suffix(word, "ing", "")] ++
        [String.replace_suffix(word, "ing", "e")]

    Enum.any?(forms, &(&1 in terms))
  end

  # Each match of a rule in a unit's prose: its line and text.
  defp hits(text, regex, unit) do
    for [{at, length}] <- Regex.scan(regex, text, return: :index, capture: :first),
        do: {line_at(unit, at), binary_part(text, at, length)}
  end

  # A page that is not a reference has 2,000 words at most: a reference page is read for
  # one rule at a time, and has more (the style guide's "Format").
  defp long_page(:reference, _words), do: []
  defp long_page(_kind, words) when words <= @most, do: []

  defp long_page(_kind, words) do
    [
      {1,
       "1: [length] a page of #{words} words: #{@most} is the limit. Write: cut it, or make " <>
         "2 pages that each have 1 job"}
    ]
  end

  defp see_also(false, _read), do: []

  defp see_also(true, read) do
    lines = Page.lines(read)

    headings =
      for {_n, line, :prose} <- lines,
          [_, title] <- [Regex.run(~r/^##\s+(.+?)\s*$/, line)],
          do: title

    ends(List.last(headings), length(lines))
  end

  defp ends("See also", _last), do: []

  defp ends(_heading, last) do
    [
      {last,
       "#{last}: [see-also] the page's last section is not \"See also\". Write: `## See also`, with the pages a reader goes to next"}
    ]
  end

  defp mention(term),
    do: Regex.compile!("(?<![\\p{L}\\p{N}_-])#{Regex.escape(term)}s?(?![\\p{L}\\p{N}_-])", "iu")

  # The glossary's terms a page links to, `glossary.md#warm-restart`, as the terms are
  # written, `warm restart`.
  defp linked(text, terms) do
    anchors =
      for [_, anchor] <- Regex.scan(~r/glossary\.md#([\w-]+)/, text), uniq: true, do: anchor

    for term <- terms, String.replace(term, " ", "-") in anchors, do: term
  end
end

Prose.main(System.argv())
