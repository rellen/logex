# The review after Milestone 6

This page is for a contributor who wants to know how agents reviewed the code and what
the review changed. It gives the review of the whole code after Milestone 6, its close and
the items after it. [Project history](project-history.md) gives the milestones before
it and the work that waits.

The full record of the review is
[`docs/review-2026-11-01.md`](../review-2026-11-01.md): each finding with its repro, and
the close. [`PLAN.md`](../../PLAN.md) gives each item, under "The review after
Milestone 6".

## How the review ran

The maintainer asked for a review of the whole code when Milestone 6 closed. On
2026-11-01, 27 reviewer agents attacked the commit `d422608`. 36 more agents tried to
refute their findings. That makes 63 agents in 4 workflows. Each finding went through
these 4 stages:

1. Find: a reviewer attacked its part of the code by running code. It used fuzzers,
   metamorphic relations, independent IEC [oracles](../implementation/testing-strategy.md#oracles),
   random walks, real-clock probes and mutation.
2. Refute: a second agent, in its own clone, tried to refute the finding.
3. Counter: a third agent tried to refute that verdict.
4. Tiebreak: a fourth agent was ready for a contested finding of high rating. No finding
   needed it.

The review also has a PMI of the whole code and 2 pre-mortems, which the close traced
like the findings.

## What the review found

The review gave 203 findings. The agents refuted 13, each against a recorded decision. 190
stayed: 12 high, 35 medium and 143 low. They were about 60 different defects, because 2
to 4 reviewers found some of the same defects.

The table gives each rating, and what became of its findings at
[the close of the review](#the-close-of-the-review) on 2026-11-12.

| Rating | Findings | Closed | Kept | Open |
|---|---|---|---|---|
| High | 12 | 12 | 0 | 0 |
| Medium | 35 | 35 | 0 | 0 |
| Low | 143 | 130 | 5 | 8 |
| Refuted | 13 | 0 | 13 | 0 |
| All | 203 | 177 | 18 | 8 |

- A closed finding has a fix that a test holds, or a change that made a document true.
- A kept finding has a decision or a recorded reason.
- An open finding has neither.

The defects were of 4 kinds:

- code that parsed a name again after the lexer cut it into its parts
- features that came late and that a program combines, for example a bit of a member of
  an array element
- the work of the runner against a real-time deadline
- the held outputs of a configuration edit

These parts held under the attack:

| Part | What it held |
|---|---|
| The evaluator | 1,200 fuzzed programs, 3 metamorphic relations over about 1,300 more programs, and IEC oracles of each timer and counter at each width |
| The front end | About 100,000 mutated sources through parse, print and parse again |
| The edit of 1 instance | About 380,000 steps of random walks |
| The schedule of the runner | 10,000 calls from 400 processes, and a jump of the clock of 10^9 ms |

## The items that fixed the findings

The maintainer answered the 14 questions of the review on 2026-11-01, decisions 347 to
360. RV-1 to RV-7 built them. RV-9 to RV-19 built the answers to the questions of the
earlier items, decisions 361 to 512. Item RV-8 closed the review: see
[The close of the review](#the-close-of-the-review).

The last column gives the decisions of each item, then the day that the item merged into
`main`, in 2026, from `git log`.

| Item | Subject | Decisions |
|---|---|---|
| RV-1 | The documents and the toolchain | 358, 359. Merged 11-01 |
| RV-2 | The compiler: each source text compiles or gets a diagnostic | 351. Merged 11-01 |
| RV-3 | The core and the edits: a held output holds | 347, 349, 350. Merged 11-01 |
| RV-4 | The runner and its devices: a limit for each write | 348, 350, 353, 354, 356. Merged 11-02 |
| RV-5 | The store: an end line, and a copy of a store that a start drops | 355, 360. Merged 11-02 |
| RV-6 | The long work of the runner, cheaper and with a bound | 352. Merged 11-08 |
| RV-7 | Cost bounds measured in the same run | 357. Merged 11-04 |
| RV-9 | A rung that is only a label, where a jump names it. A declaration refused past 65,536 elements | 363, 365, 367, 370 to 372. Merged 11-01 to 11-02 |
| RV-10 | A warm restart counts its timers from the restart. In an online edit, a point wired again to a `var_output` that no rung wrote is held | 378, 381, 382, 384 to 389. Merged 11-02 |
| RV-11 | A limit of real time on each open of a device and on each file write and read. A wrong clock trips the runner | 390, 391, 394, 396, 398 to 400. Merged 11-03 |
| RV-12 | A declaration counts each tag, element and instance that its first state holds | 403 to 405. Merged 11-02 |
| RV-13 | The store and the forces file read CRLF as LF. Each copy of a store has a number, and no copy replaces another | 410, 412, 414, 417, 418. Merged 11-04 |
| RV-14 | The provisional marks of RV-10 replaced by decision numbers, with no change of a rule | 420 to 428. Merged 11-03 |
| RV-15 | A bit of a member through a tag subscript gets the warning "may share". The trusted compile of the loader is private | 431, 432. Merged 11-03 |
| RV-16 | The rounds run on while the runner writes the forces file. The status of a runner always gives its keys of forcing | 437, 439 to 442, 445. Merged 11-08 |
| RV-17 | A ceiling for each stage. `Logex.IO.Sim` holds on its next reread. logex reads a source file raw | 459, 462, 464. Merged 11-08 |
| RV-18 | Requests to force that wait behind a write go into the next write. A request to force with a wrong argument raises an error immediately | 465, 466, 468, 472 to 475, 477, 478, 480, 484, 486, 488. Merged 11-09 |
| RV-19 | A trip that the lateness of the runner causes gives `{:watchdog, {:late, ms}}`. A stop gives each write of its end that failed | 490, 493, 500, 502. Merged 11-10 |

## The close of the review

Item RV-8 closed the review on 2026-11-12. It traced each of the 203 findings, each item
of the PMI and of the 2 pre-mortems. It also ran 276 probes of the reviewers again on the
newest commit. [What the review found](#what-the-review-found) gives the result for each
rating.

The maintainer answered the questions of the close on 2026-11-12, decisions 513 to 521.
The answers settled the 8 open findings. Thus 177 findings are closed, and a decision or
a recorded reason settles the other 26. In decision 521, the maintainer accepted the
review as done.

## The items after the review

Decisions 513 to 521 started items RV-20 to RV-25. The answers to their questions, and
to the questions of the items after them, started RV-26 to RV-31. The table gives the
items in the sequence that they merged into `main`. The last column gives the decisions
that the entry of the item in `PLAN.md` names, then the day that the item merged, in
2026.

| Item | What it gives | Decisions |
|---|---|---|
| RV-20 | A refusal of many unknown names costs about its count. A compile runs in a separate process. The documentation of each module outside the [host contract](../../guides/reference/glossary.md#host-contract) states this | 513, 514, 518, 520. Merged 11-12 |
| RV-21 | A fresh start warns if the [store](../../guides/reference/glossary.md#store) is of a different program. The simulated device takes the addresses of the configuration when a runner opens it. The examples are files under `examples/`, with an example of an adapter | 517. Merged 11-13 |
| RV-26 | The store compares the canonical text of a program. The warning of a stale store names its 2 causes and goes to the subscribers. The runner writes the store as `logex retain 3` | 522 to 531. Merged 11-14 |
| RV-27 | The store compares keywords in any case and a bit in brackets as logex reads them. logex refuses a version 3 store that names no program | 532 to 536. Merged 11-14 |
| RV-22 | CI names each test that failed. A script makes the tag of a release | 515. Merged 11-15 |
| RV-28 | logex refuses a version 3 store that names its resource and no program. Each refusal of the lines that name the program gives the way to start cold | 537 to 540. Merged 11-15 |
| RV-24 | Typespecs on the host contract, and Dialyzer in CI | 515. Merged 11-15 |
| DOC-1, step 1 | The site of the documentation, its checks, the tutorial and the glossary | 546 to 548. Merged 11-15 |
| RV-29 | A store with no resource line and a count that does not read gets the refusal of its count first. The refusal of a renamed configuration gives the full way out | 541 to 545. Merged 11-16 |
| RV-30 | `scripts/dialyzer.sh` is the fifth step of `scripts/gate.sh`, with `-Wunmatched_returns`. `Logex.Configuration.Global.new!/3` refuses a wrong initial value when it is called | 549 to 555. Merged 11-16 (565f057) |
| RV-31 | `Logex.Configuration.Global.new!/3` refuses each error of 1 global when it is called: its name, its type, its location and its value. A refusal of the host cuts a long number that it quotes. The comments of CI on its caches | 576, 577, 580 and 583. Merged 11-23 (cd9601a) |

The answers to the questions of these items are in 4 groups:

- 549 to 555: the answers to RV-24, which RV-30 built.
- 556 to 572: the answers to DOC-1 step 1.
- 573 and 574: the answers to RV-29.
- 575 to 583: the answers to RV-30. RV-31 built 576, 577, 580 and 583.

## Why the review ran this way

- Each finding came from a run, not from a reading of the code. A finding stayed only
  if a second and a third agent did not refute it.
- Each fix has a test that fails when you revert the fix. [The test
  strategy](../implementation/testing-strategy.md) gives the checks.
- The done sentence of the review needs each finding closed, kept or answered by the
  maintainer (decision 521). Thus no finding stays without an answer.

## How to change it

The review is closed. Do not change its figures. When an item of the review merges into
`main`, do the steps of [Project history](project-history.md#how-to-change-it).

## See also

- [Project history](project-history.md)
- [The test strategy](../implementation/testing-strategy.md)
- [Verify by a run](../adr/0020-verify-by-executing.md)
- [The toolchain and the gates](toolchain.md)
