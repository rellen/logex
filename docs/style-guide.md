# Style guide for the documentation

This page is for a person who writes or changes a page of the logex documentation. It
gives the rules for the words, the sentences and the format of a page.

3 more pages complete it:

- [Forms that the pages do not have](house-manner.md) gives the manner of the older
  documents, which a page does not have.
- [Examples and pictures](examples-and-pictures.md) gives the marks of a code block and
  of a picture.
- [Add and check a page](check-a-page.md) gives the kinds of page and the commands that
  check a page.

The rules apply to each page that `docs/pages.exs` lists with a kind that is not
`:legacy`. A legacy document keeps its manner until a writer makes it a page of a kind.

## The readers

Write each page for 1 of these 3 readers. Say in the first lines of the page who the
reader is and what the page gives.

| Reader | Knows | Does not know | Wants |
|---|---|---|---|
| The Elixir developer | Elixir, Mix, processes | Ladder logic and the words of controllers | To run ladder programs from an Elixir application |
| The controls engineer | Ladder logic, IEC 61131-3 or Logix, plant practice | Elixir and the BEAM | To know exactly what a rung does in logex |
| The contributor | Elixir | How logex is built, and why | To change logex and not break it |

Rules that help the reader:

- Say first what the page gives and what the reader must have. Link to the page that
  gives it.
- Define a word before you use it, or link its first use to the
  [glossary](../guides/reference/glossary.md).
- Show the result of each step. The reader must know if the step worked.
- Give a danger or a surprise before the step, not after it.
- State the rule of the present. Do not tell the history of the rule.
- Give a page 1 job. If a page has 2 jobs, make 2 pages.

## Simplified Technical English

The pages follow the writing rules of ASD-STE100, Simplified Technical English. They
follow its principle for words: 1 word for 1 thing, and 1 meaning for 1 word.

> #### The pages are not certified {: .info}
>
> ASD-STE100 has 53 writing rules and a dictionary of about 900 approved words. The
> dictionary is the property of ASD and is not in this repository. No tool here compares
> a page with the dictionary. Do not write that a page conforms to ASD-STE100.

### Words

- Use 1 word for 1 thing on each page. If the page says "tag", it does not say
  "variable" for the same thing.
- Use a word in 1 meaning and as 1 part of speech. Write "do a test", not `test` as a
  verb.
- Use the plain word of this table.

| Do not write | Write |
|---|---|
| `utilize`, `employ` | use |
| `commence`, `initiate` | start |
| `cease`, `halt`, `terminate` | stop |
| `display`, `indicate`, `demonstrate` | show |
| `ensure`, `verify that` | make sure |
| `prior to` | before |
| `approximately`, `regarding` | about |
| `however` | but |
| `additionally`, `furthermore`, `moreover` | also |
| `whether`, `in the event that` | if |
| `since` for a reason, `due to the fact that` | because |
| `subsequently` | then |
| `perform`, `carry out` | do |
| `execute` | do, or run for a program or a task |
| `obtain`, `retrieve` | get |
| `provide`, `supply` | give |
| `inform`, `notify` | tell |
| `allow`, `permit`, `enable` | let |
| `in order to` | to |
| `need to` | must, or "it is necessary to" |
| `should`, `shall`, `ought to` | must |
| `may`, `might`, `could`, `would` | can for an ability, possibly for a doubt |

- A technical word is a word of the [glossary](../guides/reference/glossary.md). Each
  heading of level 3 there is 1 technical word, and the checker does not refuse it. Put a
  new technical word into the glossary before you use it. "Enable" is such a word: a
  rung enables an instruction.
- Write a mnemonic, a tag, a file name and a message as code. On a user page, do not
  put a message between quotation marks: the checker reads those words as your words.
- Do not use an idiom, a metaphor or humour.
- Do not use a Latin short form. Write "for example", "that is" and "and so on".
- Do not use a contraction.
- Write a number as digits, with its unit: 10 ms, 3 scans, 16 bits, 1 time, 2 times.
- Do not write `simply`, `just`, `obviously`, `easy` or `of course`.

### Sentences

- A sentence in a step of a procedure has 20 words or fewer. A sentence that describes
  has 25 words or fewer.
- Give 1 idea in 1 sentence. Give 1 instruction in 1 sentence, unless 2 actions occur
  together.
- Use the active voice. Say who or what does the action: "The runner writes 0 to each
  output."
- Use the simple tenses. Do not use a perfect tense or the `-ing` form of a verb as a
  verb. Write "the task runs".
- Write an instruction as a command: "Declare the tag." Put a condition first: "If the
  rung is false, the timer stops."
- Keep the articles. Do not remove words to make a sentence shorter.
- Use 3 nouns or fewer in a group of nouns. Write "the limit of the write time".
- Do not join clauses with a semicolon. Make 2 sentences. Use a colon only before a list
  or an example.
- Use a vertical list for more than 3 items, and for steps.

### Paragraphs

- A paragraph has 6 sentences or fewer and 1 topic. The first sentence gives the topic.
- A procedure is a numbered list. Each step has 1 action and its result.
- A safety message is a callout with a fixed form. It starts with the command, then
  gives the reason.

| Callout | Class | Use |
|---|---|---|
| Warning | `.warning` | A risk of injury or of damage to a machine |
| Caution | `.error` | A risk of lost data or a stopped plant, or a thing that does not work |
| Note | `.info` | Information that helps |
| Tip | `.tip` | A better way |

```markdown
> #### Warning {: .warning}
>
> Do not use logex for a safety function. logex can stop at any time.
```

## Truth

The pages define the behaviour of the engine. A wrong sentence is a defect.

- Compare each claim with the code in `lib/` and with a test. The README has old
  sentences. If the README and the code are different, the code is correct.
- Run the claim if you can. A small script settles a claim faster than a long read.
- Quote a message exactly, in a code block.
- Do not invent a feature, an option, a default or a limit.
- Write "the [conventional set](../guides/reference/glossary.md#conventional-set)" for
  the vocabulary that logex takes its mnemonics from. Do not name the vendor of this
  vocabulary. You can name Logix when you compare the behaviour of logex with the
  behaviour of a Logix controller.
- Do not make a limit weaker. "logex is not a safety controller" stays as strong as it
  is.

## Format

The pages must read well on the site that ExDoc builds and in the Markdown view of
GitHub.

- Use a table for each thing that a reader looks up or compares.
- Use numbered steps for each procedure. Put the result straight after the step.
- Give each code block a language: `elixir`, `text` for a ladder program and for output,
  `console` for a command line. Write 3 backticks and the language, and nothing more.
- Write Markdown only. The site shows an HTML tag as text, and no check reads it.
- Use headings of level 2 and 3 only. A heading can hold a name as code, such as a
  function or a mnemonic.
- Keep a page short. If a page that is not a reference has more than about 1,500 words,
  make 2 pages.
- Link to a module or a function with its name in a code span: ExDoc makes the link.
- Do not put a hidden module or function in a code span as `Module.fun/arity`: one with
  `@moduledoc false` or `@doc false`. ExDoc warns, and `scripts/docs.sh` fails. Name its
  file instead, for example `lib/logex/compiler/worker.ex`.
- Link to a page with a relative link from the file of the page, as GitHub reads it. The
  build makes the link correct for the site.
- Link to a file that is not a page with a relative link also. The build changes it to
  the address of the file on GitHub.
- Give each picture alt text, and put the facts of the picture in the text or in a table
  also.
- Use a Mermaid diagram for a flow, a sequence or a state. Keep it to 12 nodes or fewer.
  Give it a caption of 1 line, and 1 sentence that says what to see in it.
- Put the instruction set on 1 page as a cheatsheet: a file of the type `.cheatmd` in
  `guides/reference/`. ExDoc shows it in columns.
