# The test strategy

This page is for a contributor. It tells how the tests of logex find a defect by a run of
the code. Read it before you add a test or change a rule in `lib/`. 3 other pages
complete it:

- [The checks of a change](testing-checks.md) gives the mutation tables and the gate.
- [The cost of a stage in reductions](testing-cost.md) gives the tests of cost.
- [Tests of time](testing-time.md) gives the tests of the clock.

> #### Caution {: .error}
>
> Judge each run of `mix test` by its exit code. Do not read its output for a count.
> Elixir 1.20 prints `Result: 139/140 passed` for a run with 1 failure. A search for
> `[0-9]+ passed` reads that line as a pass.

## What the suite does

The rule of [`CONTRIBUTING.md`](../../CONTRIBUTING.md) is "Verify by executing, not by
reasoning." A claim about logex is true only when a run shows it. The suite turns each
claim of the code and of the pages into a run. A change to `lib/` comes with a run that
fails when the change is wrong.

This page uses these words:

| Word | Meaning |
|---|---|
| Test | A test of the suite. On this page it is not the [test](../../guides/reference/glossary.md#test) step of an online edit |
| Stage | 1 part of the path from source text to a result: the lexer, the parser, the compiler or the runtime |
| Seam | The place where 1 stage gives its result to the next stage |
| IR | The instructions that the compiler gives and the runtime runs |
| Oracle | A function that gives the expected result from the text of a program alone. It calls no module of logex |
| Harness | The code of a test that runs logex and gives its results to an oracle |
| Walk | A test that draws programs, inputs and host calls at random, and checks each result. It is a property test |
| Seed | The start value of the random draws of a walk. The same seed gives the same walk |
| Family of seeds | A set of seeds that differ in 1 element, for example `{n, 77, 7}` for each `n` from 1 to 100 |
| Reach | The cases that a walk meets. A walk asserts its reach |
| Mutant | A copy of `lib/` with 1 rule changed or removed |
| Mutation table | 1 row for each mutant: the tests that fail on it, or `SURVIVED` |
| Reduction | The unit of work of the BEAM. `Process.info(pid, :reductions)` gives the count of a process |
| Twin | A second program that makes each call of the first program as often. [The cost of a stage](testing-cost.md) uses it |

### The kinds of test

Each kind of test finds a different class of defect. Each kind also has a class of defect
that it cannot find. A stage test starts from input typed by hand. The other kinds start
from source text, from a seed or from the files of the repository.

| Kind, and its files | Finds | Cannot find |
|---|---|---|
| Stage test: `instructionize_test.exs`, `evaluation_test.exs` | A wrong rule of that stage | A defect at a seam |
| End-to-end test: `end_to_end_test.exs` | A wrong value after scans, which an oracle gives | A rule that no program of the file reaches |
| Contract walk: `api_contract_test.exs` | A call that raises, a wrong refusal, a result that an oracle does not give | A case that the draws do not reach |
| Round trip and golden record: `printer_test.exs`, `frontend_golden_test.exs` | A change of what the language accepts | An ambiguity of the grammar |
| Cost test: [The cost of a stage](testing-cost.md) | A pass that is not linear, or a path that costs more than its twin | A pass that its program does not reach |
| Real-clock test: [Tests of time](testing-time.md) | A [runner](../../guides/reference/glossary.md#runner) that does not run, stop or [trip](../../guides/reference/glossary.md#trip) | The time of each [round](../../guides/reference/glossary.md#round) |
| Source reading: `clauses_test.exs`, `naming_test.exs`, `claude_md_test.exs` | A broken convention, from the text or the syntax trees of files | A convention that it does not read |
| Examples: `readme_test.exs` | An example whose output is not the output on its page | A wrong sentence of prose |
| Spec test: `typespec_test.exs` | A value outside its spec, and a function with a spec that no test calls | A spec that is wider than the values that the function gives |

### An oracle and a walk, in a small example

The script `testing-strategy.exs` is a small walk. It needs
[`motor.ld`](../../guides/tutorials/first-program.md), the program of the tutorial "Your
first program", which shows the file. The oracle restates rung 1 of `motor.ld`, the
[seal-in](../../guides/reference/glossary.md#seal-in) of the motor:

<!-- rung: motor.ld 1 -->
![Rung 1 of motor.ld as a ladder drawing: a branch with the contacts start and motor, then a closed contact stop, then the coil motor.](../../guides/assets/what-logex-is-rung.svg)

The walk does 200 [scans](../../guides/reference/glossary.md#scan) of `motor.ld` with
random inputs. It then does the same 200 scans of a changed program, in which the
[contact](../../guides/reference/glossary.md#contact) on `stop` is `xic` and not `xio`.
This example changes the program and not `lib/`. A mutant changes a rule of `lib/`, and
a walk finds it in the same way. Run the script from `examples/`:

```elixir
# A walk with an oracle: 200 scans of motor.ld, each with random inputs. The oracle
# restates rung 1 from its text alone. It knows nothing of how logex runs the rung.
#
#   ( xic start | xic motor ) xio stop ote motor
defmodule Oracle do
  # The next value of motor, and the case of the rung that gives it.
  def motor(_start, _motor, 1), do: {0, :stop_pressed}
  def motor(1, _motor, 0), do: {1, :start_pressed}
  def motor(0, 1, 0), do: {1, :sealed_in}
  def motor(0, 0, 0), do: {0, :idle}
end

defmodule Walk do
  @cases [:start_pressed, :sealed_in, :stop_pressed, :idle]

  # The same seed gives the same 200 inputs to each program.
  def run(program, seed) do
    :rand.seed(:exsss, seed)
    first = {Logex.Runtime.instance(program), 0, 0, Map.new(@cases, &{&1, 0})}
    {_state, _motor, differences, reach} = Enum.reduce(1..200, first, &step(program, &1, &2))
    {differences, Enum.map_join(@cases, ", ", &"#{&1} #{reach[&1]}")}
  end

  # 1 scan. The oracle starts from the value of motor that logex gave at the scan before.
  defp step(program, _n, {state, motor, differences, reach}) do
    inputs = %{"start" => :rand.uniform(2) - 1, "stop" => :rand.uniform(2) - 1}
    state = Logex.Runtime.put_inputs(program, state, inputs)
    {outputs, state} = Logex.Runtime.scan(program, state)
    {expected, rung_case} = Oracle.motor(inputs["start"], motor, inputs["stop"])
    difference = abs(outputs["motor"] - expected)
    {state, outputs["motor"], differences + difference, Map.update!(reach, rung_case, &(&1 + 1))}
  end
end

{:ok, motor} = Logex.compile_file("motor.ld")

# A changed program: the contact on stop is open where motor.ld has it closed.
text = String.replace(File.read!("motor.ld"), "xio stop", "xic stop")
{:ok, changed} = Logex.compile(text, name: "changed")

for {name, program} <- [{"motor.ld", motor}, {"changed", changed}] do
  {differences, reach} = Walk.run(program, {1, 2, 3})
  IO.puts("#{name}: #{differences} differences in 200 scans")
  IO.puts("  reach: #{reach}")
end
```

```console
$ mix run testing-strategy.exs
motor.ld: 0 differences in 200 scans
  reach: start_pressed 52, sealed_in 23, stop_pressed 94, idle 31
changed: 130 differences in 200 scans
  reach: start_pressed 52, sealed_in 16, stop_pressed 94, idle 38
```

- `motor.ld` and the oracle agree on each scan. The changed program differs on 130 scans.
- Each clause of the oracle has a case of the reach. Each case occurs, so the walk tests
  each clause. A case with 0 is a clause that the walk does not test.
- The reach of the changed program is not the reach of `motor.ld`. The oracle starts
  from the value of `motor` that the changed program gave.
- The oracle has no `if` and no `case`. Each of its rules is 1 clause.

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

### Tests of time

Each timing rule of the runner has a test on `Logex.Runner.Clock.Manual`, a clock that
the test moves. The tests on the machine's clock are few and short. A new one runs 50
times on a loaded machine before it goes into `main`. [Tests of
time](testing-time.md) gives these tests and the load runs.

### Mutation tables and the gate

A test is useful only if it fails on a wrong rule. A fix comes with a test that fails
when you revert the fix. New code comes with a mutation table: 1 mutant for each
rule of the diff. Each mutant must fail the full suite.
[The checks of a change](testing-checks.md) gives the steps, the examples of the pages,
the tests that read the source and the gate.

## Why it is built this way

- A stage test is fast and names the stage, but it cannot see a seam. The suite stayed
  green for 6 commits with the integer literal broken from end to end. The parser gave
  `:int_lit`, the evaluator read `:lit_int`, and the stage tests typed `:lit_int`. The
  end-to-end tests and the walks start from text, so a seam between 2 stages fails them.
- A restatement is written from the same design as the code. A misreading of the design
  goes into both, and they agree. With the restatement switched off, the independent
  checks still failed 10 of 14 timer mutants and 14 of 18 one-shot mutants.
  [`CONTRIBUTING.md`, "Beware of a green suite"](../../CONTRIBUTING.md#beware-of-a-green-suite)
  gives the tables.
- The [review of the whole codebase](../review-2026-11-01.md) found most defects in
  4 places:
  - code that reads a name again after the lexer cut it
  - 2 features that a test did not use together
  - the work of the runner against a deadline
  - the held outputs of an edit of a configuration

  The review found few defects in 4 other parts. These are the evaluator, the round
  trip of the front end, the online edit of 1 instance and the schedule of the runner.
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

For a fix, a new rule, a change of the language or a new pass, follow
[The checks of a change](testing-checks.md). For a new real-clock or runner test, follow
[Tests of time](testing-time.md).

## See also

- [The cost of a stage in reductions](testing-cost.md): growth tests, twins and ceilings.
- [Tests of time](testing-time.md): the manual clock, the real clock and the load runs.
- [The checks of a change](testing-checks.md): mutation tables, the examples of the
  pages, the tests that read the source and the gate.
- [The toolchain and the gates](../contributing/toolchain.md): the gates and CI.
- [Add an instruction](adding-an-instruction.md): the tests that an instruction needs.
- [The architecture of the runner](../architecture/runner.md): the clock and the devices
  that the real-clock tests use.
- [The architecture of an online edit](../architecture/online-edit.md): the steps, the
  reports and the held outputs that the edit walk checks.
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md): each practice with what broke it.
