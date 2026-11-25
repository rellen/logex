# Oracles and walks

This page is for a contributor. It gives 2 tools of the suite that check a result
against the text of a program. An oracle gives the expected result. A walk draws its cases
at random. Read it before you add an oracle, a walk or a condition of a walk.

[The test strategy](testing-strategy.md) gives the kinds of test and a small walk with
its oracle. [The words of the contributor pages](../contributing/words.md) gives the
words oracle, walk, seed, family of seeds and reach.

## What the part does

An oracle gives the expected result of a run from the text of the program and the rules
of the language. A walk draws programs, inputs and host calls, and runs logex. It compares
each result with an oracle, or with a fact that is true for each correct rule. A seed
makes each walk occur again, and the reach of the walk shows which cases it met.

## How it is built

### Oracles

An oracle knows only the text of the [program](../../guides/reference/glossary.md#program)
and the rules of the language. It does not read the IR, the
[instance](../../guides/reference/glossary.md#instance) or the evaluator. A test of
`end_to_end_test.exs` passes only when the lexer, the parser, the compiler and the
runtime agree. Its assertions name no IR tag. The file has only 1 shape of the parse
tree: the helper `rung_count/1` matches the wrapper `{:routine, {:rungs, _}}`.

`PLAN.md` gives each milestone 1 sentence that says when the milestone is done. The tests
of Milestones 5 and 6 run that sentence in `end_to_end_test.exs`. Each runs 1 plant from
files on disk, for example `Milestone 6's done sentence in one plant`.

A stage test types the input of 1 stage by hand. It does not see a change in the form
that the stage before it gives.

A walk has 2 kinds of check:

| Check | What it does | What it cannot find |
|---|---|---|
| Restatement | It restates a rule of `docs/organisation.md` from the text of the programs, and compares | A misreading of the rule that the code shares |
| Independent check | It checks a fact that is true for each correct rule | A rule that the fact does not touch |

In an [online edit](../../guides/reference/glossary.md#online-edit), each step returns a
[report](../architecture/online-edit.md#the-report). An output that the old program
drives and the new program does not drive is a held output. The independent checks of
the walk of the online edit are these:

- Apply the writes that a report lists to the
  [state](../../guides/reference/glossary.md#state) before the step. The result must be
  the state after the step.
- A held output has the value that the walk saw the host get last. If the new program
  still has the output, the value is the value of its next scan.
- A [one-shot](../../guides/reference/glossary.md#one-shot) pulses only if the scan
  before ran the same `ons` rung with its condition 0.
- A test and then an [untest](../../guides/reference/glossary.md#untest), with no scan
  between them, give back the original state.
- No scan lets a [timer](../../guides/reference/glossary.md#timer) gain more than the
  time of that scan.

A walk has both kinds of check. A rule that the independent checks cannot see has a
separate test in `edit_test.exs`, with its values written by hand. An independent check
uses no value from the code that it checks. It does not use the reports of an edit.

The oracles follow the rule of `lib/`: clauses, not conditionals. In
`api_contract_test.exs`, a function that draws a program, an input or a step at random
can hold a conditional. Its module names the function in `@draws`.
`end_to_end_test.exs`, `readme_test.exs` and the scripts under `examples/` hold no
conditional. `clauses_test.exs` reads the syntax trees and refuses each other
conditional.

### Walks and their reach

The contract walks are in `api_contract_test.exs`. They cover these parts:

- the host contract, the online edit and the resource
- the runner and the reach across types
- the life of the [store](../../guides/reference/glossary.md#store)
- the held points of the edit of a configuration

Other files have seeded walks also, for example `end_to_end_test.exs`, `printer_test.exs`
and the mutation walk of `compile_total_test.exs`.

Each walk sets a fixed seed, for example `:rand.seed(:exsss, {2026, 10, 2})`. Thus a
failure occurs again on the next run. Each contract walk checks the
[host contract](../../guides/reference/glossary.md#host-contract) on each call:

- An error in the source text is a returned
  [diagnostic](../../guides/reference/glossary.md#diagnostic).
- A wrong argument of the host is an `ArgumentError` with a documented message.
- logex raises no other error.

A walk tests only what its draws reach. Thus each walk asserts its reach: each stage of
the compile, each kind of refusal, each kind of report and each oracle. In a copy of the
repository, the compile walk drew 20 sources in place of 2,000. It failed with this
message:

<!-- unchecked: the message of the failed assertion, from a run of the compile walk with 20 sources, in a copy of the repository -->
```text
no source reached the message containing "a declaration takes `retain` or `non_retain`, not both"
```

Each condition of a restated rule has an atom of the reach for the case that it decides.
Each walk draws enough cases that its rarest atom occurs 15 times or more in a run. The
3 families of `api_contract_test.exs` are `{n, 77, 7}`, `{n, 1, 1}` and `{7, n, 2026}`.
[How to change it](#how-to-change-it) gives the steps to size a walk.

| Walk | Draws in a run |
|---|---|
| The compile walk | 2,000 sources |
| The runtime walk | 150 programs |
| The walk of the online edit | 400 edits |
| The walk of the resource | 1,000 [configurations](../../guides/reference/glossary.md#configuration) |

## Why it is built this way

- A restatement is written from the same design as the code. A misreading of the design
  goes into both, and they agree. Thus a walk also has independent checks, which use no
  value from the code that they check.
- A walk finds cases that no person writes. A seed makes each failure occur again, and
  its reach shows what it does not test.
- The rule of `lib/`, clauses and not conditionals, applies to the oracles also.
  Decision 264 extends the rule to the walks and the end-to-end tests, and the draws are
  exempt.

## How to change it

To add a condition to a walk:

1. Add an atom of the reach for the case that the condition decides.
2. Measure the rate of the atom over 1 family of seeds.
3. Size the draws so that the atom occurs 15 times or more in a run.
4. Run the walk under 60 seeds or more, from families other than the one that you
   measured the rate on. The reach assertion must pass at each seed.

To add an oracle:

1. Write the oracle from the text of the program and the rules of the language. Use no
   module of logex.
2. Write each rule as 1 clause. Give each clause an atom of the reach.
3. Change 1 rule of `lib/` that the oracle covers. Run the test and see it fail. Then
   put the rule back.

## See also

- [The test strategy](testing-strategy.md): the kinds of test and a small walk.
- [The checks of a change](testing-checks.md): the mutation tables that show if a walk
  finds a wrong rule.
- [The architecture of an online edit](../architecture/online-edit.md): the steps, the
  reports and the held outputs that the edit walk checks.
- [The words of the contributor pages](../contributing/words.md): the words of the suite.
