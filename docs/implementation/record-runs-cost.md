# Runs and tables of the records: cost

This page is for a contributor who reads the decision record about cost in reductions. It
holds the words, the measurements and the long tables of record 0019, so that the record
stays short. The record links to this section.
[Runs and tables of the records: the ceilings of cost](record-runs-cost-ceilings.md) holds
the ceilings, their figures and the run of the record's rules.

## 0019. Cost in reductions

These tables and this run support
[0019. Cost in reductions](../adr/0019-cost-in-reductions.md).

### The words of the record

| Word | Meaning on this page |
|---|---|
| Stage | 1 of the 4 kinds of work that a ceiling holds: a compile, a scan, a cycle or a round |
| Count | The reductions of 1 process from the start of some work to its end |
| Growth test | A test that does the same work at 2 sizes and holds the ratio of the 2 counts |
| Twin | A second program that makes the same calls as the first, as often, except on the path that the test guards |
| Bound | A test that holds the count of a program to the count of its twin, made in the same run of the suite |
| Allowance | What a bound adds to the difference that the twins measured, so that a small move of a count passes |
| Ceiling | A test that holds a stage under 2 times its figure |
| Figure | A count recorded in the test file, with the date and the toolchain |
| Item | 1 instruction or 1 [branch](../../guides/reference/glossary.md#branch) of a rung, as the evaluator runs it |
| Mutant | A copy of logex with 1 change, made to see which test fails |
| Test | An ExUnit test of the suite. This record does not use the word for the step of an online edit |

### Time changes with the computer

A run on 2026-11-23 counted 100 scans of `motor.ld` with its 5 rungs written 16 times
over. Each line gives 2 runs of 9 counts each, in a new process with a large heap:

| Computer | Reductions | Time |
|---|---|---|
| 4 cores, no other work | 277,966 in each count | 1.2 ms to 2.5 ms |
| 4 cores, 8 busy loops | 277,966 in each count | 1.0 ms to 159 ms |

Thus a bound in time fails on a busy computer with nothing wrong. In a heap where no
garbage collection runs, the count did not change.

### A count also moves

A count is not the same in each process. A garbage collection costs reductions, and the
collections depend on what ran before. The same run counted the same 100 scans 9 times in
each of 3 places:

| Where the script counts | The 9 counts |
|---|---|
| A new process with `min_heap_size: 8_000_000` | 277,956 each time |
| A new process with the default heap | 278,976 each time |
| The process of the script, 1 count after the other | 278,103 to 278,629 |

The count of the first table is 10 more, because that script also called
`System.monotonic_time/1` 2 times in the counted work.

A busy computer also moves a count, through its garbage collections. The growth test of
`logex_test.exs` gave these ratios in 4 counts alone, and in 12 counts with 8 busy loops:

| Heap | Alone | 8 busy loops |
|---|---|---|
| A large heap: 1 major collection | 4.06 to 4.07 | 4.07 to 4.16 |
| The default heap: many collections | 4.01 to 4.02 | 4.02 to 4.10 |

In earlier reviews, with 4 suites that ran at the same time, the ratio in the process
of the test got to 7.29. These 3 things also move a count:

- A change in the VM moves a count by a few reductions, for example when other modules
  compile.
- A large map can cost a different count each time that a function makes it. On
  2026-11-23, a map of 256 keys cost 147 to 166 reductions in 300 counts. A map of 64
  keys cost 39 each time.
- A trace pattern that 1 test sets changes the count of each other process that calls
  the traced function.

### The probe of RV-7 on the exact counts

Before decision 357, some tests held a count exactly, for example `== 27.0` reductions a
[rung](../../guides/reference/glossary.md#rung). Others held a count within a few
reductions of a figure recorded at a commit. The review after Milestone 6 counted about
27 such tests. The census of RV-7, the plan item that made decision 357, found 20: 9
exact and 11 within a few reductions. The review found 2 problems in them:

- A release of Elixir or OTP that changes the code that the compiler makes moves a count
  by 1 reduction a rung. The tests then fail with no change to logex.
- A change that makes logex cheaper also fails them.

A probe of RV-7 charged 2 reductions more for each
[instruction](../../guides/reference/glossary.md#instruction) that a scan runs. On the
exact counts, this probe failed 6 test files. The same probe for each instruction that
the compiler lowers failed 2 files. For each instruction that the walk of the
[warnings](../../guides/reference/glossary.md#warning) reads, it failed 4 files.

### A bound on a bit whose number is in a tag

`tag_bit_test.exs` is an example. It holds a
[contact](../../guides/reference/glossary.md#contact) on a
[bit](../../guides/reference/glossary.md#bit) whose number is in a tag. That bit needs a
catch in the evaluator. A run on 2026-11-23 gave these counts for each rung, the
difference of 200 rungs and 100 rungs over 100. The tag `off` is 0 and each
[input](../../guides/reference/glossary.md#input) is 1:

| Operand | After `xic off` | Alone |
|---|---|---|
| `w.[n]` | 30.0 | 35.0 |
| `w.3` | 29.0 | 27.0 |
| `a` | 29.0 | 24.0 |

For example, the first cell is the rung `xic off xic w.[n] ote q`. After `xic off`, the
rung is a [false rung](../../guides/reference/glossary.md#false-rung). No instruction
reads its [operand](../../guides/reference/glossary.md#operand). Thus the false rungs
differ by the catch alone, 1 reduction. The test asserts that each plain false rung costs
at least 0.5 less than the caught false rung. If the evaluator also catches on the rung
with `w.3`, the 2 costs are the same, and the test fails.

The [true rungs](../../guides/reference/glossary.md#true-rung) alone differ by 8: the read of `n`, the mask and the catch. A bound is the
count of the twin, plus the difference that the twins measured when a contributor wrote
the test, plus an allowance:

<!-- fragment: the bound of a bit whose number is in a tag, from tag_bit_test.exs -->
```elixir
assert tag_bit <= literal + 8 + 0.5
```

Here `literal` is 27, the count of `xic w.3 ote q`, and `tag_bit` is the count of
`xic w.[n] ote q`.

### The twin of each kind of path

The twin depends on what selects the guarded path:

- **The head of a clause.** Twin: the same rung made false, with an operand that does not
  take the clause. Example: `tag_bit_test.exs`.
- **The shape of an operand.** Twin: the same rungs with the other shape. Example: a tag
  against a [literal](../../guides/reference/glossary.md#literal) [subscript](../../guides/reference/glossary.md#subscript) of an element,
  in `array_test.exs`.
- **A field that is `nil` when the program has no such feature.** Twin: the same program
  beside the feature. Example: a `move` beside a `real`, in `real_test.exs`.
- **A clause that each program takes.** Twin: an instruction whose clause makes the same
  calls. Example: an `add` against a `div`, in `real_test.exs`.
- **A path of the compile.** Twin: the same rungs in a different order, or over plain
  tags. Example: `compile_total_test.exs`.

A twin beside the feature (the 3rd item) does the guarded work itself. The bound then
holds the whole difference, and it is a lower bound on that work. A change that makes the
feature cheaper fails the bound with nothing wrong. That commit restates the bound, so
that its diff shows the saving (decision 458).

For 1 bound, no mutant makes 1 twin dearer and not the other. `retain_edit_test.exs`
holds that the [switch](../../guides/reference/glossary.md#switch) of an
[online edit](../../guides/reference/glossary.md#online-edit) of programs marked
`non_retain` costs no more than the switch of an edit of unmarked programs. No change
found makes 1 side dearer and not the other. The test stays as a statement of the rule.
Its comment gives this reason (decision 463).

### Each option not taken

| Alternative | Why logex does not use it |
|---|---|
| A bound in time | 8 busy loops changed the time of the same work from 1 ms to 159 ms |
| Exact counts, `== 27.0` | A toolchain release or a saving fails them with nothing wrong |
| A count within a delta of a figure | The same problem, with a margin that a toolchain can pass |
| An allowance of half the guarded work | Regressions under that half passed. Decision 460 takes half a reduction a rung |
| Half the work as the margin of a lower bound, option (b) of decision 458 | It passes each regression under that half. Decision 458 holds the whole difference |
| A seam in `lib/` that skips the guarded clause, option (c) of decision 458 | It adds code to `lib/` for the tests only |
| No allowance, option (c) of decision 460 | The hundredths that a count moves fail the bound |
| A count of the calls, with `:erlang.trace_pattern/3`, option (c) of decision 459 | A trace pattern changes the counts of each other process |
| No ceiling, option (a) of decision 459 | A slowdown that both twins pay passes each bound, even a large one |
| The whole stage only, on the motor written 16 times over, option (c) of decision 481 | Then the work of each call and each tag is a small part of the figure. A slowdown there gets near to no ceiling |
| A ceiling for 1 rung only, option (b) of decision 481 | The work of each call and each tag, a large part of a stage, then has no ceiling |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [Runs and tables of the records: the ceilings of cost](record-runs-cost-ceilings.md):
  the ceilings, a failure's text and the run of the record's rules.
- [The cost of a stage in reductions](testing-cost.md): each cost test and its figures.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
