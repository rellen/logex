# The cost of a stage in reductions

This page is for a contributor. It describes the tests that hold the cost of logex: the
growth tests, the bounds against a twin and the ceilings. Read it before you add a pass
over a [program](../../guides/reference/glossary.md#program), change a clause of the evaluator or change a bound.
[The test strategy](testing-strategy.md) gives the other tests of the suite and the words
of this page.

> #### Caution {: .error}
>
> Do not make a bound wider to make a test pass. A bound moves only for a change that
> makes its stage dearer on purpose. Measure the figure again as this page says, and give
> the cause and the size of the change in the commit.

## What the cost tests do

A cost test counts [reductions](testing-strategy.md#what-the-suite-does), the unit of
work of the BEAM. It does not measure time. A count of reductions is the same on a fast
machine and on a slow one, and a busy machine changes it only a little. A bound in time
fails on a CI runner that shares its cores.

The suite has 3 kinds of cost test. Each kind catches a regression that the others miss:

| Kind | Compares | Catches | Misses |
|---|---|---|---|
| Growth test | 1 program at 2 sizes, as a ratio | A pass that is not linear, for example quadratic | A pass that its program does not reach |
| Bound against a twin | A program and its twin, counted in the same run | A guarded path that costs a call more | A cost that both twins pay |
| Ceiling | A standard program, and a figure recorded with the test | A stage that costs 2 times its figure or more | A slowdown of less than 2 times |

A twin is a second program that makes each call of the first program as often. It differs
only in the path that the bound guards.

## How it is built

### How a test counts

A test reads `Process.info(self(), :reductions)` before and after the work. The rules of
a count:

| Rule | Reason |
|---|---|
| Count in a separate process with a large heap, for example `min_heap_size: 8_000_000` | A garbage collection costs reductions, and a busy machine charges a collection more |
| Take the least of 3 counts or more | A busy VM raises a count by a few percent |
| Count 2 figures in pairs, 1 after the other, and keep the least difference | The state of the VM moves a count by a few reductions, and 2 counts that follow each other share that state |
| Take the least of 5 counts or more where the work builds a map of more than 32 keys | The cost to build a large map moves from 1 call to the next |
| For the cost of a [round](../../guides/reference/glossary.md#round), count with 1 scheduler online, as `retain_period_test.exs` does | The order of the messages between the [runner](../../guides/reference/glossary.md#runner), its clock and its devices adds to the count |

A trace pattern of `:erlang.trace_pattern/3` changes the count of each process that calls
the traced function. Put a test that traces a module in a separate test module with
`async: false`. ExUnit runs that module after each async module.

### Growth tests

A growth test does the same work at 2 sizes and compares the 2 counts. A linear pass
grows by the factor of the size. A pass that walks each use for each tag grows by the
square of it.

`logex_test.exs` compiles 1 program at 500 [tags](../../guides/reference/glossary.md#tag) and at 2,000 tags, and 1 [rung](../../guides/reference/glossary.md#rung) nested
500 and 8,000 groups deep:

| Test | Bound | A run on 2026-11-23 |
|---|---|---|
| 4 times the tags, in a large heap | less than 5.40 | 4.07 to 4.08 |
| 4 times the tags, in the default heap of the VM | less than 7.43 | 4.01 to 4.02 |
| 16 times the depth | less than 19.7 | 15.55 to 15.58 |

The large heap hides a copy. A walk that appends each rung with `++` is quadratic. It
grew 5.27 to 6.42 times in the large heap, and 12.4 to 12.9 times in the default heap. Thus the test
counts in both heaps. Depth is a second axis: the test of size never nests a group. The
comments of the test give these figures.

To set the bound of a new growth test:

1. Copy the test into a script that prints the ratio.
2. Run it 30 times or more, alone and with 4 suites at the same time.
3. Set the bound 20 % or more over the highest ratio.

A growth test checks only the passes that its program reaches. List each pass that your
change adds. Make sure that a growth test gives each pass a large input. A pass that is
not a compile has a separate growth test. An example is `growth (F16)` in
`edit_test.exs`, for each step of an online edit.

### Bounds against a twin

A bound against a twin holds a guarded path to the cost of its twin (decision 357). The
test counts both in the same run and the same VM. A change of the toolchain moves both counts, and the
bound stays green. Only a change to the guarded path moves the difference.

`tag_bit_test.exs` holds a [contact](../../guides/reference/glossary.md#contact) on a bit
that a tag numbers against contacts on a literal bit and on a bool. Each rung is
de-energised, so no rung reads its operand. The only difference is the catch that the
bit numbered by a tag needs. A run gave these counts for each rung:

| Rung | Reductions for each rung |
|---|---|
| `xic off xic w.[n] ote q` | 30.0 |
| `xic off xic a ote q` | 29.0 |
| `xic off xic w.3 ote q` | 29.0 |

The test asserts that each plain rung costs at least 0.5 less than the caught rung. A
catch where none is necessary makes the 2 costs the same, and the test fails.

The bound is the figure of the twin, plus the difference that the test measured, plus an
allowance. The allowance is half a reduction for each rung, key, point or instance
(decision 460). It is never half of the guarded work: such a bound passes each
regression of less than that half.

Choose the twin by what selects the guarded path:

| The guarded path is selected by | The twin |
|---|---|
| The head of a clause | The same rung, de-energised, beside 1 that the clause catches |
| The shape of an operand | The same rungs with the other shape: a tag against a literal element |
| A field that is `nil` when the program has no such feature | The same program beside the feature: a `move` beside a `real` |
| A clause that each program takes | An instruction whose clause makes the same calls: an `add` against a `div` |
| A path of the compile | The same rungs in a different order, or over plain tags |

A twin that does the guarded work itself gives a lower bound on that work. A change that
makes the work cheaper breaks the bound. Restate the bound in that commit, so that its
diff shows the saving (decision 458).

### Ceilings

A bound against a twin cannot see a cost that both twins pay. If each [instruction](../../guides/reference/glossary.md#instruction) costs
1 call more, each such bound stays green. `ceiling_test.exs` holds each stage under
2 times a figure recorded with the test (decision 459). It measures the motor of the
examples, `examples/motor.ld`, and their plant, `examples/plant.logex`, each stage whole
and for 1 rung (decision 481):

| Stage | Figure | Figure for 1 rung | A run on 2026-11-23 |
|---|---|---|---|
| Compile of `motor.ld` | 8,649 | 999.2 | 8,712 |
| 100 [scans](../../guides/reference/glossary.md#scan) of the motor | 44,606 | 3,110.0 | 44,706 |
| 100 [cycles](../../guides/reference/glossary.md#cycle) of the [plant](../../guides/reference/glossary.md#plant) | 83,262 | 3,762.9 | 83,386 |
| 1 round of the plant on the runner | 1,662 | 37.5 | 1,714.0 |

The cost for 1 rung is the difference between the motor with its 5 rungs written 16
times and written 8 times, divided by 40. The tags are the same at both sizes, so that
cost holds the work of a rung alone.

A ceiling catches a stage or a rung that costs more than 2 times its figure. It does not
catch 1 call more. The bounds against a twin catch that.

## Why it is built this way

- About 27 tests held an exact count of reductions. A new toolchain that moved code
  generation by 1 reduction turned them red, and so did a cheaper logex. Thus each
  count became a bound against a twin in the same run (decision 357).
- A bound against a twin cancels a cost that both twins pay. A ceiling for each stage
  catches a gross slowdown of that kind (decision 459).
- A whole stage costs mostly what it pays for each call and each tag. Each instruction
  evaluated 4 times read 1.44 times the figure of the whole scan, under its ceiling.
  Thus each stage also has a ceiling for 1 rung (decision 481).
- An allowance of half a reduction is less than the least regression, 1 call a rung
  (decision 460).

## How to change it

To add a pass over a program:

1. Make the pass quadratic in a copy, as a mutant.
2. Add a growth test, or give an existing growth test a program that reaches the pass.
3. See the test fail on the mutant and pass on your code.

To add a guarded path:

1. Make the regression first, as a mutant of the least size: 1 call more for each rung.
2. Choose a twin that the mutant cannot reach.
3. See the bound fail on the mutant in the full suite.
4. Add `:erlang.bump_reductions(2)` to a call that both twins make as often. See the
   bound stay green.

If a ceiling fails:

1. Find the change that made the stage dearer.
2. If the change was not on purpose, make the stage cheaper again.
3. If it was on purpose, measure the figure again as the comment of `ceiling_test.exs`
   says. Replace the figure, never the factor 2.
4. Give the cause and the size of the change in the commit.

## See also

- [The test strategy](testing-strategy.md): the other tests and the checks of a change.
- [The runtime and the evaluator](../architecture/runtime-and-evaluator.md): the clauses
  that the twins compare.
- [The compile pipeline](../architecture/compile-pipeline.md): the passes that the growth
  tests reach.
- `CONTRIBUTING.md`: the history of each rule of cost, with the figures of each review.
