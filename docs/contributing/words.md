# The words of the contributor pages

This page is for a contributor. It gives the words that the contributor pages use for the
suite, the checks and the toolchain. The
[glossary](../../guides/reference/glossary.md) gives the words of logex itself, such as
rung, scan and runner, for each page.

A user page does not use the words of this page. On a user page, "test" is only the
[test](../../guides/reference/glossary.md#test) step of an online edit, and a test of the
suite is an "ExUnit test". The [style guide](../style-guide.md#words) gives that rule.

## The suite

| Word | Meaning |
|---|---|
| ExUnit test | A test of the suite, in a file under `test/`. A contributor page calls it a test. A user page always writes "ExUnit test" |
| Test step | The step `Logex.Edit.test/2` of an online edit. A contributor page writes "the test step", so that the reader does not take it for an ExUnit test |
| Suite | Each ExUnit test of the repository. `mix test --warnings-as-errors` runs it |
| Stage | 1 part of the path from source text to a result: the lexer, the parser, the compiler or the runtime |
| Seam | The place where 1 stage gives its result to the next stage |
| IR | The instructions that the compiler gives and the runtime runs. [The IR and the program type](../architecture/ir-and-program-type.md) gives each form |
| Stage test | A test that types the input of 1 stage by hand, for example `instructionize_test.exs` |
| End-to-end test | A test that starts from source text and checks the values after scans, in `end_to_end_test.exs` |
| Oracle | A function that gives the expected result from the text of a program alone. It calls no module of logex |
| Harness | The code of a test that runs logex and gives its results to an oracle |
| Walk | A test that draws programs, inputs and host calls at random, and checks each result. It is a property test |
| Seed | The start value of the random draws of a walk. The same seed gives the same walk |
| Family of seeds | A set of seeds that differ in 1 element, for example `{n, 77, 7}` for each `n` from 1 to 100 |
| Reach | The cases that a walk meets. A walk asserts its reach |
| Golden record | The file `test/fixtures/frontend_golden.txt`: for each of its 1,590 sources, the parse tree and the last line, or the line of the error. `frontend_golden_test.exs` compares the lexer and the parser with it |
| Round trip | A test that parses a text, prints the parse tree and compares the result with the text, in `printer_test.exs` |
| Fragment | An `elixir` block of a page that is not a script. The suite parses it, and runs it where `readme_test.exs` gives it a setup |
| Done sentence | The sentence of `PLAN.md` that says when a milestone is complete. `end_to_end_test.exs` runs the sentences of Milestones 5 and 6 |

## The checks of a change

| Word | Meaning |
|---|---|
| Mutant | A copy of `lib/` with 1 rule changed or removed |
| Mutation table | 1 row for each mutant: the tests that fail on it, or `SURVIVED`. `scripts/mutate.sh` makes it |
| Gate | 1 command that must exit with 0 before you commit. `scripts/gate.sh` runs the 5 gates |
| Load run | A run of tests while a busy loop runs on each core. `scripts/load.sh` does it |
| Red, green | A run that exits with a code that is not 0 is red. A run that exits with 0 is green |
| Failures manifest | The file of ExUnit that names the tests that failed: `_build/test/lib/logex/.mix/.mix_test_failures` |

## Cost and time

| Word | Meaning |
|---|---|
| Reduction | The unit of work of the BEAM. `Process.info(pid, :reductions)` gives the count of a process |
| Growth test | A test that does the same work at 2 sizes and compares the 2 counts of reductions |
| Twin | A second program that makes each call of the first program as often. It differs only in the path that a bound guards |
| Bound against a twin | A limit on the count of a program, from the count of its twin in the same run |
| Ceiling | A limit of 2 times a figure that the test records, for 1 stage of a standard program |
| Manual clock | `Logex.Runner.Clock.Manual`, a clock that a test moves |
| Real clock | `Logex.Runner.Clock.Monotonic`, the clock of the computer |

## The toolchain and CI

| Word | Meaning |
|---|---|
| Toolchain | Erlang/OTP and Elixir, which build and run logex |
| Pin | A version that a file of the repository names |
| CI | The 2 workflows, `ci.yml` and `docs.yml`, that GitHub Actions runs on each push and each pull request |
| PLT | The file of Dialyzer that holds the types of the functions of the applications that logex calls |

## Why the pages have this list

Decision 590 keeps the word "test" for the step of an online edit on the user pages. The
words of the suite are not words of logex, so they are not in the glossary. A
contributor finds them on this page.

## How to change it

1. Find a new word of the suite, the checks or the toolchain on a contributor page. Add
   its row to the table of its group.
2. Put a word of logex itself into the glossary, not on this page.
3. Run `elixir scripts/prose.exs docs/contributing/words.md`. It prints no failure.

## See also

- [The test strategy](../implementation/testing-strategy.md): the kinds of test, oracles
  and walks.
- [The toolchain and the gates](toolchain.md): the gates and CI.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
- [A map of the documents](../README.md): each document, and who reads it.
