defmodule Logex.ProseTest do
  @moduledoc """
  `scripts/prose.exs` (decision 546 (d)), the check of the writing rules a script can
  measure, run as a writer runs it: on `test/fixtures/prose/every_rule.md`, a page that
  breaks each rule once, each failure with its line, its rule and its fix; on each word and
  form the style guide replaces, with the plain one; on what is not prose, which it does
  not read; on a sentence, a step and a paragraph at their limits; on a page's kind, a
  user page's rules and a contributor page's; on the glossary's terms, never refused; on
  what it counts for a reviewer and does not fail; and on every page of `docs/pages.exs`
  that is under the rules, which must pass.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir
  @root Path.expand("../..", __DIR__)
  # The `elixir` beside the Elixir the suite runs on, or else the one on the path.
  @elixir Enum.find(
            [
              Path.expand(Path.join([:code.lib_dir(:elixir), "..", "..", "bin", "elixir"])),
              System.find_executable("elixir")
            ],
            &File.exists?(to_string(&1))
          )

  # The script run in `dir` over the files given, a map of path to text: its failures, the
  # lines of its stderr, its reports, the lines of its stdout, and its exit code.
  defp prose(dir, files, args) do
    for {path, text} <- files do
      File.mkdir_p!(Path.dirname(Path.join(dir, path)))
      File.write!(Path.join(dir, path), text)
    end

    run(dir, args)
  end

  defp run(dir, args) do
    out = Path.join(System.tmp_dir!(), "prose-#{System.unique_integer([:positive])}.out")
    script = Path.join(@root, "scripts/prose.exs")
    quoted = Enum.map_join([script | args], " ", &"'#{&1}'")

    {failures, code} =
      System.cmd("sh", ["-c", "'#{@elixir}' #{quoted} 2>&1 >'#{out}'"], cd: dir)

    reports = File.read!(out)
    File.rm!(out)
    {String.split(failures, "\n", trim: true), String.split(reports, "\n", trim: true), code}
  end

  # A page of one paragraph a line, as a tutorial, with the section a user page ends by.
  defp page(paragraphs), do: Enum.join(paragraphs, "\n\n") <> "\n\n## See also\n"

  defp tutorial(dir, paragraphs),
    do: prose(dir, %{"page.md" => page(paragraphs)}, ["--kind", "tutorial", "page.md"])

  # The lines of a page's failures, each `{line, rule, text}`.
  defp found(failures) do
    for failure <- failures,
        [_, line, rule, text] <- [Regex.run(~r/^page\.md:(\d+): \[([\w-]+)\] (.*)$/, failure)],
        do: {String.to_integer(line), rule, text}
  end

  test "the page that breaks each rule once is refused once by each rule, with its line " <>
         "and its fix",
       %{tmp_dir: dir} do
    file = "every_rule.md"
    page = File.read!(Path.join(@root, "test/fixtures/prose/every_rule.md"))
    assert {failures, [report], 1} = prose(dir, %{file => page}, ["--kind", "tutorial", file])

    assert failures ==
             Enum.map(
               [
                 "5: [sentence] a sentence of 34 words: 25 is the limit. Write: two sentences, or a list",
                 "7: [sentence] a step's sentence of 22 words: 20 is the limit. Write: two sentences, or a list",
                 "9: [paragraph] a paragraph of 7 sentences: 6 is the limit. Write: two paragraphs, one topic each",
                 ~s(11: [word] "utilize". Write: "use"),
                 ~s(13: [modal] "should". Write: "must" for a rule, "can" for an ability, "possibly" for a doubt),
                 ~s(15: [latin] "e.g.". Write: "for example", "that is", "and so on"),
                 ~s(17: [contraction] "doesn't". Write: the two words in full),
                 ~s(19: [semicolon] ";". Write: two sentences),
                 ~s(21: [dash] "—". Write: a full stop and a new sentence, or "to"),
                 ~s(23: [perfect] "has written". Write: the simple past or the simple present),
                 ~s(25: [progressive] "is running". Write: the simple tense: "the task runs"),
                 ~s(27: [need] "need to". Write: "must", or "it is necessary to"),
                 ~s(29: [manner] "of its own". Write: "a separate process", "a separate file"),
                 ~s(31: [easy] "Simply". Write: nothing: delete it),
                 ~s(33: [history] "now". Write: the present rule only),
                 ~s(35: [pointer] "below". Write: a link to the section by its name, or "more than", "less than"),
                 ~s(37: [number] "two". Write: the number in digits),
                 ~s(39: [label] "M5-5". Write: nothing: a user page holds the present rule, and no label of the plan),
                 "41: [heading] a heading of level 4. Write: level 3 at the deepest, or a new page",
                 "43: [language] a code block with no language. Write: its language after the fence: elixir, text, console",
                 "47: [alt] a picture with no alt text. Write: what the picture shows, between the brackets of `![...](...)`",
                 "49: [callout] a callout of the class .caution. Write: one of .warning, .error, .info, .tip, .neutral",
                 ~s(52: [see-also] the page's last section is not "See also". Write: `## See also`, with the pages a reader goes to next)
               ],
               &"#{file}:#{&1}"
             )

    assert report ==
             "#{file}: 23 failures; 204 words, 31 sentences; to review: 0 passive, 0 glossary " <>
               "terms with no link, 0 quotations, 0 blocks unchecked"

    rules = for failure <- failures, [_, rule] <- [Regex.run(~r/\[([\w-]+)\]/, failure)], do: rule
    assert Enum.frequencies(rules) |> Map.delete("sentence") |> Map.values() |> Enum.uniq() == [1]
    assert length(Enum.uniq(rules)) == 22
  end

  # The style guide's table of plain words, restated: each word it replaces, in each form
  # a page could write it, and the word it gives.
  @plain %{
    "use" => ~w(utilize utilizes utilized utilizing utilise employ employs employed employing),
    "start" =>
      ~w(commence commences commenced commencing initiate initiates initiated initiating),
    "stop" =>
      ~w(cease ceases ceased ceasing halt halts halted halting terminate terminates terminated),
    "show" =>
      ~w(display displays displayed displaying indicate indicates indicated demonstrate demonstrates),
    "make sure" => ["ensure", "ensures", "ensured", "ensuring", "verify that", "verifies that"],
    "before" => ["prior to"],
    "about" => ~w(approximately regarding),
    "but" => ~w(however),
    "also" => ~w(additionally furthermore moreover),
    "if" => ["whether", "in the event that"],
    "because" => ["since", "due to the fact that"],
    "then" => ~w(subsequently),
    "do" =>
      ["perform", "performs", "performed", "carry out", "carries out", "carried out"] ++
        ~w(execute executes executed executing),
    "get" => ~w(obtain obtains obtained retrieve retrieves retrieved),
    "give" => ~w(provide provides provided providing supply supplies supplied),
    "tell" => ~w(inform informs informed notify notifies notified),
    "let" => ~w(allow allows allowed permit permits permitted enable enables enabled enabling)
  }

  test "each word the style guide replaces is refused, in each of its forms, with the plain " <>
         "word",
       %{tmp_dir: dir} do
    words = for {plain, words} <- @plain, word <- words, do: {word, plain}
    assert length(words) == 94
    paragraphs = for {word, _plain} <- words, do: "The runner can #{word} the tag."
    assert {failures, _, 1} = tutorial(dir, paragraphs)

    assert found(failures) ==
             for(
               {{word, plain}, n} <- Enum.with_index(words),
               do: {2 * n + 1, "word", ~s("#{word}". Write: "#{plain}")}
             )
  end

  # Each form of the other word rules, a paragraph each, with the rule that refuses it.
  @forms [
    {"modal", ~w(should may might could would shall)},
    {"latin", ["e.g.", "i.e.", "etc.", "viz.", "cf.", "N.B."]},
    {"contraction",
     ~w(doesn't isn't can't won't it's that's there's they're we've you'll I'm let's)},
    {"dash", ["—", "–", "--", "->", "=>", "→"]},
    {"perfect",
     ["has written", "have been", "had run", "has not stopped", "have never seen", "having set"]},
    {"progressive",
     ["is running", "are waiting", "was writing", "were reading", "is not running"]},
    {"need", ["need to", "needs to", "needed to"]},
    {"easy", ["simply", "just", "obviously", "easy", "easily", "of course"]},
    {"history",
     [
       "now",
       "no longer",
       "currently",
       "at present",
       "previously",
       "formerly",
       "so far",
       "used to"
     ]},
    {"pointer", ~w(above below)},
    {"number",
     ~w(two three four five six seven eight nine ten eleven twelve twenty hundred thousand)},
    {"label",
     [
       "M5-9",
       "RV-21",
       "OE-2",
       "DOC-1",
       "decision 514",
       "decisions 546",
       "fix F11",
       "§7",
       "Milestone 5"
     ]},
    {"manner",
     ["of its own", "of their own", "told", "held to", "pinned", "pins", "as built", "as written"] ++
       [
         "as it stands",
         "the one table",
         "says so",
         "say so",
         "runner's store's",
         "gone",
         "landed"
       ] ++
       ["escapes", "mistake", "mistakes", "honest about", "said plainly", "plainly", ", each a"] ++
       [", each with", ", every one"]}
  ]

  test "each form of the modal verbs, Latin short forms, contractions, dashes, perfect and " <>
         "progressive tenses, history, pointers, numbers, labels and the house manner is " <>
         "refused by its rule",
       %{tmp_dir: dir} do
    forms = for {rule, forms} <- @forms, form <- forms, do: {rule, form}
    paragraphs = for {_rule, form} <- forms, do: "The task #{form} the tag."
    assert {failures, _, 1} = tutorial(dir, paragraphs)
    found = found(failures)

    for {{rule, form}, n} <- Enum.with_index(forms),
        at = 2 * n + 1,
        do:
          assert(
            {at, rule, form} in for({line, rule, text} <- found, do: {line, rule, quoted(text)})
          )
  end

  defp quoted(text),
    do: hd(Regex.run(~r/^"(.*?)"\. Write:/, text, capture: :all_but_first) || [text])

  test "a clean page passes: plain words, short sentences, a callout, a table, a list",
       %{tmp_dir: dir} do
    page = """
    # How to declare a tag

    This page is for an Elixir developer. It shows how to declare a tag.

    > #### Warning {: .warning}
    >
    > Do not use logex for a safety function. logex can stop at any time.

    1. Declare the tag before the first rung.
    2. Compile the program.

    | Section | Who gives the value |
    |---|---|
    | `var_input` | The host |

    - A tag with no initial value starts at 0.
    - The host gives the value of an input.

    ### The result

    The program compiles.

    ## See also

    - [The glossary](glossary.md)
    """

    assert {[], [report], 0} = prose(dir, %{"page.md" => page}, ["--kind", "howto", "page.md"])

    assert report ==
             "page.md: 0 failures; 78 words, 18 sentences; to review: 0 passive, 0 glossary " <>
               "terms with no link, 0 quotations, 0 blocks unchecked"
  end

  test "what is not prose is not read: a code block, a code span, a link's target, a " <>
         "comment, an attribute list, a table's row of dashes; a quotation's words are not " <>
         "refused, and it is counted",
       %{tmp_dir: dir} do
    page = """
    # A page

    ```text
    The host should utilize the tag; it doesn't, etc.
    ```

    ````markdown
    ```
    However, a block with no language, shown as Markdown.
    ```
    ````

    Write `should`, `e.g.` and `a -> b` as code. See [the page](however/should.md#below).

    <!-- unchecked: the host should utilize the tag -->

    The message says "the store should be gone" and “it doesn't”.

    | Word | Plain word |
    |---|---|
    | `utilize` | use |
    | `a | b` | `however` |

    ![A rung with a contact and a coil](../assets/should.svg)

    > #### Tip {: .tip}
    >
    > Use a link.

    ## See also
    """

    assert {[], [report], 0} =
             prose(dir, %{"page.md" => page}, ["--kind", "reference", "page.md"])

    assert report ==
             "page.md: 0 failures; 44 words, 14 sentences; to review: 0 passive, 0 glossary " <>
               "terms with no link, 2 quotations, 1 blocks unchecked"
  end

  test "a link's text, a picture's alt text, a heading, a table's cell and a callout are " <>
         "prose, and are read",
       %{tmp_dir: dir} do
    page = """
    # A page

    See [the page below](a.md).

    ![A rung that should close](../assets/a.svg)

    ### However it starts

    | Word | Plain word |
    |---|---|
    | `use` | It can utilize a tag. |

    > #### Tip {: .tip}
    >
    > Simply use a link.

    ## See also
    """

    assert {failures, _, 1} = prose(dir, %{"page.md" => page}, ["--kind", "reference", "page.md"])

    assert for({line, rule, _} <- found(failures), do: {line, rule}) == [
             {3, "pointer"},
             {5, "modal"},
             {7, "word"},
             {11, "word"},
             {15, "easy"}
           ]
  end

  describe "the limits" do
    defp words(n), do: Enum.map_join(1..n, " ", fn _ -> "tag" end)

    test "a sentence of 25 words passes and one of 26 is refused; a code span is one word",
         %{tmp_dir: dir} do
      assert {[], _, 0} = tutorial(dir, ["The #{words(24)}.", "The `a b c d e` #{words(23)}."])
      assert {failures, _, 1} = tutorial(dir, ["The tag.", "The #{words(25)}. The tag."])

      assert found(failures) ==
               [
                 {3, "sentence",
                  "a sentence of 26 words: 25 is the limit. Write: two sentences, or a list"}
               ]
    end

    test "a step's sentence of 20 words passes and one of 21 is refused; an item of a list " <>
           "with no numbers is no step",
         %{tmp_dir: dir} do
      assert {[], _, 0} =
               tutorial(dir, ["1. The #{words(19)}.\n2. Run it.", "- The #{words(24)}."])

      assert {failures, _, 1} = tutorial(dir, ["1. Run it.\n2. The #{words(20)}.\n3. Stop it."])

      assert found(failures) ==
               [
                 {2, "sentence",
                  "a step's sentence of 21 words: 20 is the limit. Write: two sentences, or a list"}
               ]
    end

    test "a sentence that runs over lines is counted whole, and named by the line it " <>
           "starts on",
         %{tmp_dir: dir} do
      assert {failures, _, 1} =
               tutorial(dir, ["The tag.\nThe tag. The #{words(12)}\n#{words(13)}\ntag."])

      assert [{2, "sentence", "a sentence of 27 words" <> _}] = found(failures)
    end

    test "a paragraph of 6 sentences passes and one of 7 is refused; a list's items and a " <>
           "table's cells are each their own",
         %{tmp_dir: dir} do
      six = Enum.map_join(1..6, " ", fn _ -> "The tag is on." end)
      items = Enum.map_join(1..8, "\n", fn _ -> "- The tag is on." end)
      assert {[], _, 0} = tutorial(dir, [six, items, "| The tag is on. | #{six} |\n|---|---|"])
      assert {failures, _, 1} = tutorial(dir, [six <> " The tag is off."])

      assert found(failures) == [
               {1, "paragraph",
                "a paragraph of 7 sentences: 6 is the limit. Write: two paragraphs, one topic each"}
             ]
    end
  end

  describe "a page's kind" do
    test "a label of the plan and a decision's number are refused in a user page, and pass " <>
           "in a contributor page and a decision record",
         %{tmp_dir: dir} do
      text = page(["The store is refused (decision 360, RV-5)."])

      for kind <- ~w(tutorial howto reference explanation) do
        assert {failures, _, 1} = prose(dir, %{"page.md" => text}, ["--kind", kind, "page.md"])
        assert for({1, rule, _} <- found(failures), do: rule) == ["label", "label"]
      end

      for kind <- ~w(contributor adr),
          do: assert({[], _, 0} = prose(dir, %{"page.md" => text}, ["--kind", kind, "page.md"]))
    end

    test "a user page ends with See also; a contributor page and a decision record are " <>
           "not held to it; a heading in a code block is none",
         %{tmp_dir: dir} do
      text =
        "# A page\n\nThe tag is on.\n\n```text\n## See also\n```\n\n## See also\n\n## The end\n"

      for kind <- ~w(tutorial howto reference explanation) do
        assert {[failure], _, 1} = prose(dir, %{"page.md" => text}, ["--kind", kind, "page.md"])
        assert failure =~ ~r/^page\.md:12: \[see-also\]/
      end

      for kind <- ~w(contributor adr),
          do: assert({[], _, 0} = prose(dir, %{"page.md" => text}, ["--kind", kind, "page.md"]))
    end

    test "a page is read by its kind in docs/pages.exs; with no page named, every page of " <>
           "the list under the rules is read, and no legacy page",
         %{tmp_dir: dir} do
      files = %{
        "docs/pages.exs" =>
          ~S|[{"README.md", :legacy, :first}, {"guides/a.md", :tutorial, "Tutorials"}, | <>
            ~S|{"docs/b.md", :contributor, "Project"}]|,
        "README.md" => "# A project\n\nThe host should utilize it; etc.\n",
        "guides/a.md" => page(["The store is refused (decision 360)."]),
        "docs/b.md" => "# How it is built\n\nThe store is refused (decision 360).\n"
      }

      assert {[failure], reports, 1} = prose(dir, files, [])
      assert failure =~ ~r/^guides\/a\.md:1: \[label\] "decision 360"/

      assert for(report <- reports, do: hd(String.split(report, ":"))) == [
               "guides/a.md",
               "docs/b.md"
             ]

      assert {[], ["docs/b.md: 0 failures" <> _], 0} = run(dir, ["docs/b.md"])
    end

    test "a file the list does not have, a kind that is none and a legacy kind are refused " <>
           "with the usage",
         %{tmp_dir: dir} do
      files = %{"docs/pages.exs" => "[]", "a.md" => "# A\n"}
      usage = "usage: elixir scripts/prose.exs [--review] [<page>... | --kind <kind> <file>...]"
      kinds = "kinds: tutorial, howto, reference, explanation, contributor, adr"

      assert prose(dir, files, ["a.md"]) ==
               {[
                  "prose: a.md is not in docs/pages.exs: add its line, or give its kind with --kind",
                  usage,
                  kinds
                ], [], 2}

      for kind <- ["lesson", "legacy"] do
        assert run(dir, ["--kind", kind, "a.md"]) ==
                 {["prose: #{kind} is no kind of page under the rules", usage, kinds], [], 2}
      end
    end
  end

  describe "the glossary" do
    @glossary """
    # Glossary

    ## Words

    ### display

    A screen.

    ### tag

    A named value.

    ### `xic`

    A contact.

    ### warm restart

    A restart that keeps the retained values.

    ### seal-in

    A rung that keeps its output on.
    """

    test "a term of the glossary, a heading of level 3 there, is never refused by a word " <>
           "rule; any other word still is",
         %{tmp_dir: dir} do
      files = %{
        "guides/reference/glossary.md" => @glossary,
        "page.md" => page(["Read the display. The runner can display the tag and utilize it."])
      }

      assert {failures, _, 1} = prose(dir, files, ["--kind", "howto", "page.md"])
      assert found(failures) == [{1, "word", ~s("utilize". Write: "use")}]
    end

    test "a term a page uses with no link to the glossary is counted for the reviewer, and " <>
           "named with --review; one it links is not",
         %{tmp_dir: dir} do
      files = %{
        "guides/reference/glossary.md" => @glossary,
        "page.md" =>
          page([
            "Each tag has a type. A [warm restart](guides/reference/glossary.md#warm-restart) " <>
              "keeps 2 tags. Read the display. A [seal-in](guides/reference/glossary.md#seal-in)."
          ])
      }

      assert {[], [report], 0} = prose(dir, files, ["--kind", "howto", "page.md"])
      assert report =~ "to review: 0 passive, 2 glossary terms with no link, 0 quotations"

      assert {[], [^report, named], 0} = run(dir, ["--review", "--kind", "howto", "page.md"])
      assert named == "  page.md: no link to the glossary for: display, tag"
    end

    test "the glossary uses its own terms with no link to itself, and none is counted",
         %{tmp_dir: dir} do
      files = %{"guides/reference/glossary.md" => @glossary <> "\n### rung\n\nIt reads a tag.\n"}

      assert {_, [report], _} =
               prose(dir, files, ["--kind", "reference", "guides/reference/glossary.md"])

      assert report =~ "to review: 0 passive, 0 glossary terms with no link"
    end
  end

  test "a passive verb is counted for the reviewer and never fails; --review names each " <>
         "place; a state is counted too, which is why it does not fail",
       %{tmp_dir: dir} do
    paragraphs = [
      "The outputs are written by the runner.",
      "The rung is true. The tag is declared."
    ]

    assert {[], [report], 0} = tutorial(dir, paragraphs)
    assert report =~ "to review: 2 passive, 0 glossary terms"

    assert {[], [^report, first, second], 0} =
             run(dir, ["--review", "--kind", "tutorial", "page.md"])

    assert first == ~s(  page.md:1: passive? "are written": say who or what does it)
    assert second == ~s(  page.md:3: passive? "is declared": say who or what does it)
  end

  test "every page of docs/pages.exs that is under the rules passes" do
    assert {[], reports, 0} = run(@root, [])
    {pages, _} = Code.eval_file(Path.join(@root, "docs/pages.exs"))
    ruled = for {path, kind, _group} <- pages, kind != :legacy, do: path
    assert for(report <- reports, do: hd(String.split(report, ": "))) == ruled
  end
end
