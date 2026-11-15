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
#   modal         should, may, might, could, would, shall
#   latin         e.g., i.e., etc., viz., cf., N.B.
#   contraction   don't, it's, they're and their like
#   semicolon     a semicolon in prose
#   dash          an em dash, an en dash, a double hyphen or an arrow in prose
#   perfect       a perfect tense: has written, have been, had run
#   progressive   the -ing form of a verb as a verb: is running
#   need          "need to": "need" is a noun only
#   manner        a form of the house manner the pages must not have, with the plain form
#   easy          simply, just, obviously, easy, easily, of course
#   history       now, no longer, currently, previously, so far: the present rule only
#   pointer       above, below: a link to the section by its name, or "more than", "less than"
#   number        a number written as a word: digits
#   label         in a user page, a plan label or a decision's number: M5-9, RV-21, decision 514
#   heading       a heading deeper than level 3, but a callout's
#   language      a code block with no language
#   alt           a picture with no alt text, or one written as an HTML tag
#   callout       a callout whose class is not warning, error, info, tip or neutral
#   see-also      a user page whose last section is not "See also"
#
# What is not prose, and so is not read: a fenced code block; a code span, which counts as
# one word of its sentence; a link's or a picture's target, its text being prose; an HTML
# comment; a table's row of dashes; an attribute list, `{: .warning}`. Text between double
# quotation marks is a quotation: the word rules do not read it, its words count in its
# sentence, and the page's line counts the quotations. A table's cell is read as a
# paragraph of its own. A word that is a term of guides/reference/glossary.md, a heading of
# level 3 there, is never refused by the word rules: the glossary is the one list of the
# technical words a page may use.
#
# What it cannot see, it counts for a reviewer and never fails (`--review` gives each
# place): a passive verb, which a script cannot tell from a state ("the rung is true");
# and a term of the glossary a page other than the glossary uses with no link to the
# glossary, which the page perhaps defines itself. It reads no dictionary: it does not certify a page as
# Simplified Technical English, and a wrong sense of a word, a noun cluster or a
# missing article passes it. There is no way to switch it off inside a page. A script,
# not a test: it uses `case` freely.
defmodule Prose do
  @moduledoc false

  @manifest "docs/pages.exs"
  @glossary "guides/reference/glossary.md"
  @user [:tutorial, :howto, :reference, :explanation]
  @kinds @user ++ [:contributor, :adr]
  @classes ~w(warning error info tip neutral)

  # A word the style guide replaces, by the plain word it gives: each a stem and the
  # endings it is read with.
  @plain [
    {"utili[sz]e[sd]?|utili[sz]ing|employ(?:s|ed|ing)?", "use"},
    {"commenc(?:e|es|ed|ing)|initiat(?:e|es|ed|ing)", "start"},
    {"ceas(?:e|es|ed|ing)|halt(?:s|ed|ing)?|terminat(?:e|es|ed|ing)", "stop"},
    {"display(?:s|ed|ing)?|indicat(?:e|es|ed|ing)|demonstrat(?:e|es|ed|ing)", "show"},
    {"ensur(?:e|es|ed|ing)|verif(?:y|ies|ied) that", "make sure"},
    {"prior to", "before"},
    {"approximately|regarding", "about"},
    {"however", "but"},
    {"additionally|furthermore|moreover", "also"},
    {"whether|in the event that", "if"},
    {"since|due to the fact that", "because"},
    {"subsequently", "then"},
    {"perform(?:s|ed|ing)?|carr(?:y|ies|ied|ying) out|execut(?:e|es|ed|ing)", "do"},
    {"obtain(?:s|ed|ing)?|retriev(?:e|es|ed|ing)", "get"},
    {"provid(?:e|es|ed|ing)|suppl(?:y|ies|ied|ying)", "give"},
    {"inform(?:s|ed|ing)?|notif(?:y|ies|ied|ying)", "tell"},
    {"allow(?:s|ed|ing)?|permit(?:s|ted|ting)?|enabl(?:e|es|ed|ing)", "let"}
  ]

  # The forms of the house manner, by the plain form the style guide gives.
  @manner [
    {"\\bof (?:its|their|your|his|her) own\\b", ~s("a separate process", "a separate file")},
    {"\\btold\\b", ~s("logex reports ...", "the message says ...")},
    {"\\bheld to\\b|\\bpinned\\b|\\bpins\\b",
     ~s("the test compares ... with ...", "must be the same as")},
    {"\\bas built\\b|\\bas written\\b|\\bas it stands\\b", "what the thing is"},
    {"\\bthe one (?!of\\b)[a-z]+", ~s("one table", "the only place")},
    {"\\bsays? so\\b", ~s("its documentation states this")},
    {"\\b\\w+['’]s \\w+['’]s", "each thing in a separate sentence"},
    {"\\bgone\\b", ~s("a late write", "a clock that gives a wrong value")},
    {"\\blanded\\b", ~s("is available", or nothing: history goes to the contributor pages)},
    {"\\bescapes?\\b", ~s("logex returns no other error")},
    {"\\bmistakes?\\b", ~s("an error in the source text", "a wrong argument")},
    {"\\bhonest about\\b|\\bsaid plainly\\b|\\bplainly\\b", "nothing: delete it"},
    {", each (?:a|an|with|its|by|in|of|on|one)\\b|, every one\\b",
     ~s(a full sentence: "Each step returns a report.")}
  ]

  @participles "been|written|given|taken|made|done|gone|seen|known|shown|run|set|put|read|" <>
                 "sent|built|kept|held|left|lost|found|got|become|begun|chosen|come|drawn|" <>
                 "fallen|grown|hidden|risen|spoken|told|met|had|\\w+ed"

  @rules [
           {"modal", "\\b(?:should|may|might|could|would|shall)\\b",
            ~s("must" for a rule, "can" for an ability, "possibly" for a doubt)},
           {"latin", "\\b(?:e\\.g\\.|i\\.e\\.|etc\\b\\.?|viz\\.|cf\\.|N\\.B\\.)",
            ~s("for example", "that is", "and so on")},
           {"contraction",
            "\\b(?:\\w+n['’]t|(?:it|that|there|here|what|who|he|she|let)['’]s|\\w+['’](?:re|ve|ll|d)|I['’]m)\\b",
            "the two words in full"},
           {"semicolon", ";", "two sentences"},
           {"dash", "—|–|(?<=\\s)--(?=\\s)|->|=>|→|⇒|←",
            "a full stop and a new sentence, or \"to\""},
           {"perfect",
            "\\b(?:has|have|had|having)\\s+(?:\\w+ly\\s+|not\\s+|never\\s+)?(?:#{@participles})\\b",
            "the simple past or the simple present"},
           {"progressive",
            "\\b(?:is|are|was|were|am|be|been)\\s+(?:\\w+ly\\s+|not\\s+)?(?!(?:nothing|something|anything|everything|thing|string|during|missing)\\b)\\w+ing\\b",
            ~s(the simple tense: "the task runs")},
           {"need", "\\bneed(?:s|ed)? to\\b", ~s("must", or "it is necessary to")},
           {"easy", "\\b(?:simply|just|obviously|easy|easily|of course)\\b",
            "nothing: delete it"},
           {"history",
            "\\b(?:now|no longer|currently|at present|previously|formerly|so far|used to|as of|until recently)\\b",
            "the present rule only"},
           {"pointer", "\\b(?:above|below)\\b",
            ~s(a link to the section by its name, or "more than", "less than")},
           {"number",
            "\\b(?:two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|forty|fifty|sixty|hundred|thousand)\\b",
            "the number in digits"}
         ] ++
           for({pattern, fix} <- @plain, do: {"word", "\\b(?:#{pattern})\\b", ~s("#{fix}")}) ++
           for({pattern, fix} <- @manner, do: {"manner", pattern, fix})

  @label {"label",
          "\\bM\\d+-\\d+\\b|\\b(?:RV|OE|DOC)-\\d+\\b|\\bdecisions? \\d+|\\bfix F\\d+\\b|§\\s*\\d|\\bMilestone \\d+",
          "nothing: a user page holds the present rule, and no label of the plan"}

  @passive "\\b(?:is|are|was|were|be|been|being)\\s+(?:\\w+ly\\s+|not\\s+)?(?:written|given|taken|made|done|seen|known|shown|run|set|put|read|sent|built|kept|held|left|lost|found|\\w+ed)\\b"

  def main(args) do
    {review, args} = flag(args, "--review")

    pages =
      case args do
        ["--kind", kind | files] when files != [] ->
          for file <- files, do: {file, kind(kind)}

        [] ->
          for {path, kind} <- listed(), kind in @kinds, do: {path, kind}

        files ->
          listed = Map.new(listed())
          for file <- files, do: {file, Map.get(listed, file) || unlisted(file)}
      end

    terms = terms()
    results = for {file, kind} <- pages, do: page(file, kind, terms)
    for %{failures: failures} <- results, failure <- failures, do: IO.puts(:stderr, failure)
    for result <- results, do: report(result, review)

    failed = Enum.count(results, &(&1.failures != []))
    if failed > 0, do: System.halt(1)
  end

  defp flag(args, flag), do: {flag in args, args -- [flag]}

  defp listed do
    {pages, _} = Code.eval_file(@manifest)
    for {path, kind, _group} <- pages, do: {path, kind}
  end

  defp kind(name) do
    kind = String.to_atom(name)
    if kind in @kinds, do: kind, else: usage("#{name} is no kind of page under the rules")
  end

  defp unlisted(file),
    do: usage("#{file} is not in #{@manifest}: add its line, or give its kind with --kind")

  defp usage(why) do
    IO.puts(:stderr, "prose: #{why}")

    IO.puts(
      :stderr,
      "usage: elixir scripts/prose.exs [--review] [<page>... | --kind <kind> <file>...]\n" <>
        "kinds: #{Enum.join(@kinds, ", ")}"
    )

    System.halt(2)
  end

  # The glossary's terms, each a heading of level 3, lowercased.
  def terms do
    case File.read(@glossary) do
      {:ok, text} ->
        for line <- String.split(text, "\n"),
            [_, term] <- [Regex.run(~r/^###\s+(.+?)\s*$/, line)],
            into: MapSet.new(),
            do: term |> String.replace("`", "") |> String.downcase()

      {:error, _} ->
        MapSet.new()
    end
  end

  # ---- a page ----

  def page(file, kind, terms) do
    text = File.read!(file)
    {units, structure, marks} = units(text)
    read = Enum.map(units, &read(&1))
    rules = if kind in @user, do: [@label | @rules], else: @rules

    failures =
      structure ++
        Enum.flat_map(read, &lengths/1) ++
        Enum.flat_map(read, &words(&1, rules, terms)) ++ see_also(kind, text)

    used = for unit <- read, term <- terms, mentions?(unit.plain, term), uniq: true, do: term
    linked = linked(text, terms)

    %{
      file: file,
      failures: failures |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&"#{file}:#{elem(&1, 1)}"),
      words: read |> Enum.map(&count(&1.plain)) |> Enum.sum(),
      sentences: read |> Enum.map(&length(&1.sentences)) |> Enum.sum(),
      quotations: read |> Enum.map(& &1.quotations) |> Enum.sum(),
      unchecked: marks,
      passive: for(unit <- read, hit <- hits(unit, @passive), do: hit),
      unlinked: if(file == @glossary, do: [], else: Enum.sort(used -- linked))
    }
  end

  defp report(result, review) do
    IO.puts(
      "#{result.file}: #{length(result.failures)} failures; #{result.words} words, " <>
        "#{result.sentences} sentences; to review: #{length(result.passive)} passive, " <>
        "#{length(result.unlinked)} glossary terms with no link, #{result.quotations} " <>
        "quotations, #{result.unchecked} blocks unchecked"
    )

    if review do
      for {line, text} <- result.passive,
          do: IO.puts("  #{result.file}:#{line}: passive? \"#{text}\": say who or what does it")

      if result.unlinked != [],
        do:
          IO.puts(
            "  #{result.file}: no link to the glossary for: #{Enum.join(result.unlinked, ", ")}"
          )
    end
  end

  # ---- the units of a page: paragraphs, items, cells, headings ----

  # Each unit `%{kind, lines: [{n, text}]}`, the failures of the page's structure, each
  # `{line, "line: [rule] ..."}`, and the count of blocks marked unchecked.
  def units(text) do
    lines = text |> String.split("\n") |> Enum.with_index(1)
    state = %{fence: nil, unit: nil, units: [], failures: [], marks: 0}
    state = Enum.reduce(lines, state, &line/2)
    state = flush(state)
    {Enum.reverse(state.units), Enum.reverse(state.failures), state.marks}
  end

  defp line({line, n}, %{fence: nil} = state) do
    quoted? = String.match?(line, ~r/^\s*>/)
    body = String.replace(line, ~r/^\s*(?:>\s?)+/, "")

    cond do
      match = Regex.run(~r/^\s*(`{3,}|~{3,})\s*(\S*)/, body) ->
        [_, marker, language] = match
        state = flush(state)
        state = %{state | fence: marker}

        if language == "",
          do:
            fail(
              state,
              n,
              "language",
              "a code block with no language.",
              "its language after the fence: elixir, text, console"
            ),
          else: state

      String.match?(body, ~r/^\s*<!--.*-->\s*$/) ->
        marks = if String.match?(body, ~r/^\s*<!-- unchecked:/), do: 1, else: 0
        %{flush(state) | marks: state.marks + marks}

      String.trim(body) == "" ->
        flush(state)

      match = Regex.run(~r/^(\#{1,6})\s+(.*)$/, body) ->
        [_, marks, title] = match
        state = flush(state)
        callout = Regex.run(~r/\{:\s*\.([\w-]+)\s*\}\s*$/, title)
        state = heading(state, n, byte_size(marks), quoted?, callout)
        %{state | units: [%{kind: :heading, lines: [{n, title}]} | state.units]}

      String.match?(body, ~r/^\s*\|/) ->
        state = flush(state)

        if String.match?(body, ~r/^\s*\|?\s*:?-{3,}/) do
          state
        else
          cells = for cell <- String.split(mask(body), "|"), String.trim(cell) != "", do: cell
          cells = unmask(cells, body)

          %{
            state
            | units:
                Enum.reverse(for(c <- cells, do: %{kind: :cell, lines: [{n, c}]})) ++ state.units
          }
        end

      match = Regex.run(~r/^\s*(?:([-*+])|(\d+[.)]))\s+(.*)$/, body) ->
        kind = if Enum.at(match, 1) == "", do: :step, else: :item
        state = flush(state)
        %{state | unit: %{kind: kind, lines: [{n, List.last(match)}]}}

      state.unit == nil ->
        %{state | unit: %{kind: :paragraph, lines: [{n, body}]}}

      true ->
        %{state | unit: %{state.unit | lines: [{n, body} | state.unit.lines]}}
    end
  end

  defp line({line, _n}, %{fence: marker} = state) do
    body = String.replace(line, ~r/^\s*(?:>\s?)+/, "")
    if String.trim(body) == marker, do: %{state | fence: nil}, else: state
  end

  defp flush(%{unit: nil} = state), do: state

  defp flush(%{unit: unit} = state),
    do: %{state | unit: nil, units: [%{unit | lines: Enum.reverse(unit.lines)} | state.units]}

  defp fail(state, n, rule, what, fix),
    do: %{state | failures: [{n, "#{n}: [#{rule}] #{what} Write: #{fix}"} | state.failures]}

  defp heading(state, n, depth, quoted?, callout) do
    cond do
      quoted? and callout != nil ->
        [_, class] = callout

        if class in @classes,
          do: state,
          else:
            fail(
              state,
              n,
              "callout",
              "a callout of the class .#{class}.",
              "one of .#{Enum.join(@classes, ", .")}"
            )

      depth > 3 ->
        fail(
          state,
          n,
          "heading",
          "a heading of level #{depth}.",
          "level 3 at the deepest, or a new page"
        )

      true ->
        state
    end
  end

  # A row's cells cut where the masked row has its bars, so that a bar in a code span cuts
  # nothing.
  defp unmask(cells, body) do
    {cells, _} =
      Enum.map_reduce(cells, mask(body), fn cell, rest ->
        [before, after_cell] = String.split(rest, cell, parts: 2)
        at = byte_size(mask(body)) - byte_size(rest) + byte_size(before)
        {binary_part(body, at, byte_size(cell)), after_cell}
      end)

    cells
  end

  defp mask(text) do
    Regex.replace(~r/(`+)(.+?)\1(?!`)/, text, fn whole, _, _ ->
      String.duplicate("x", byte_size(whole))
    end)
  end

  # ---- a unit read: its plain text, its sentences, the place of each of its bytes ----

  defp read(%{kind: kind, lines: lines}) do
    cleaned = for {n, text} <- lines, do: {n, clean(text)}
    plain = Enum.map_join(cleaned, " ", &elem(&1, 1))

    {starts, _} =
      Enum.map_reduce(cleaned, 0, fn {n, text}, at -> {{at, n}, at + byte_size(text) + 1} end)

    %{
      kind: kind,
      line: elem(hd(lines), 0),
      plain: plain,
      starts: starts,
      unquoted: unquote_text(plain),
      quotations: length(Regex.scan(~r/"[^"]*"|“[^”]*”/u, plain)),
      sentences: sentences(plain),
      alts: for({n, text} <- lines, alt <- alts(text), do: {n, alt})
    }
  end

  # A line's prose: a code span one word, a picture its alt text, a link its text, no
  # attribute list, tag or emphasis mark.
  defp clean(text) do
    text
    |> then(&Regex.replace(~r/(`+)(.+?)\1(?!`)/, &1, " CODE "))
    |> then(&Regex.replace(~r/!\[([^\]]*)\]\([^)]*\)/, &1, "\\1"))
    |> then(&Regex.replace(~r/\[([^\]]*)\]\([^)]*\)/, &1, "\\1"))
    |> then(&Regex.replace(~r/<https?:[^>]*>|https?:\/\/\S+/, &1, " LINK "))
    |> then(&Regex.replace(~r/\{:[^}]*\}/, &1, ""))
    |> then(&Regex.replace(~r/<\/?[A-Za-z][^>]*>/, &1, ""))
    |> then(&Regex.replace(~r/\*+|(?<![\p{L}\p{N}])_+|_+(?![\p{L}\p{N}])/u, &1, ""))
    |> then(&Regex.replace(~r/\s+/, &1, " "))
    |> String.trim()
  end

  defp alts(text) do
    text = mask(text)

    for([_, alt] <- Regex.scan(~r/!\[([^\]]*)\]\(/, text), do: {:alt, String.trim(alt)}) ++
      for(_ <- Regex.scan(~r/<img\b/i, text), do: {:tag, ""})
  end

  # A quotation's words made blanks of the same length: the word rules do not read them.
  defp unquote_text(plain) do
    Regex.replace(~r/"[^"]*"|“[^”]*”/u, plain, fn quote ->
      String.duplicate(" ", byte_size(quote))
    end)
  end

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
    limit = if unit.kind == :step, do: 20, else: 25
    what = if unit.kind == :step, do: "a step's sentence", else: "a sentence"

    {long, _} =
      Enum.flat_map_reduce(unit.sentences, 0, fn sentence, from ->
        {at, _} = :binary.match(unit.plain, sentence, scope: {from, byte_size(unit.plain) - from})
        n = line_at(unit, at)
        words = count(sentence)

        found =
          if words > limit do
            [
              {n,
               "#{n}: [sentence] #{what} of #{words} words: #{limit} is the limit. Write: two sentences, or a list"}
            ]
          else
            []
          end

        {found, at + byte_size(sentence)}
      end)

    paragraph =
      if unit.kind in [:paragraph, :step, :item] and length(unit.sentences) > 6 do
        [
          {unit.line,
           "#{unit.line}: [paragraph] a paragraph of #{length(unit.sentences)} sentences: 6 is the limit. Write: two paragraphs, one topic each"}
        ]
      else
        []
      end

    pictures =
      for {n, alt} <- unit.alts, alt in [{:alt, ""}, {:tag, ""}] do
        {n,
         "#{n}: [alt] a picture with no alt text. Write: what the picture shows, between the brackets of `![...](...)`"}
      end

    long ++ paragraph ++ pictures
  end

  defp words(unit, rules, terms) do
    for {rule, pattern, fix} <- rules,
        {line, text} <- hits(unit, pattern),
        String.downcase(text) not in terms,
        do: {line, "#{line}: [#{rule}] \"#{text}\". Write: #{fix}"}
  end

  # Each match of a pattern in a unit's prose outside its quotations: its line and text.
  defp hits(unit, pattern) do
    regex = Regex.compile!(pattern, "iu")

    for [{at, length}] <- Regex.scan(regex, unit.unquoted, return: :index, capture: :first),
        do: {line_at(unit, at), binary_part(unit.unquoted, at, length)}
  end

  defp see_also(kind, text) when kind in @user do
    headings = for [_, title] <- Regex.scan(~r/^##\s+(.+?)\s*$/m, strip_fences(text)), do: title

    if List.last(headings) == "See also" do
      []
    else
      last = length(String.split(text, "\n"))

      [
        {last,
         "#{last}: [see-also] the page's last section is not \"See also\". Write: `## See also`, with the pages a reader goes to next"}
      ]
    end
  end

  defp see_also(_kind, _text), do: []

  defp strip_fences(text), do: Regex.replace(~r/^\s*(`{3,}|~{3,}).*?^\s*\1\s*$/ms, text, "")

  defp mentions?(plain, term),
    do: Regex.match?(~r/(?<![\p{L}\p{N}_-])#{Regex.escape(term)}s?(?![\p{L}\p{N}_-])/iu, plain)

  # The glossary's terms a page links to, `glossary.md#warm-restart`, as the terms are
  # written, `warm restart`.
  defp linked(text, terms) do
    anchors =
      for [_, anchor] <- Regex.scan(~r/glossary\.md#([\w-]+)/, text), uniq: true, do: anchor

    for term <- terms, String.replace(term, " ", "-") in anchors, do: term
  end
end

Prose.main(System.argv())
