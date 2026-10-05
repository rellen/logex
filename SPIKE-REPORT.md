# m26-spike · Event tasks at run time (M2-6), a throwaway spike

Spike copy: `scratchpad/m2-6/spike`, branch `m2-6-spike`, on `025199a` (M2-1 landed, get/2
tagged). Built from Elixir data only, no text. Not for landing. Diff:
`scratchpad/m2-6/spike.patch` (`git add -A; git diff --cached HEAD`, 1,408 lines, 6 files).
`/home/user/logex` was not modified. While the spike ran, main moved to `293b3e8` (decision
45, documents only, about `var_external` across an edit); nothing in it touches event tasks.

**Gate**, by exit code, Elixir 1.20.4 / OTP 28: `mix format --check-formatted` 0;
`mix compile --force --warnings-as-errors` 0; `MIX_ENV=test mix compile --force
--warnings-as-errors` 0; `mix test --warnings-as-errors` 0, three runs, each `556 passed (8
doctests, 548 tests)`. The baseline was 529, so the spike adds 27 tests and changes 3 existing
pins (`scratchpad/m2-6/gate.log`).

## 0. Summary

Every run-time rule the record gives for event tasks is buildable as written, on M2-1's
scheduler, in about 150 lines of `runtime.ex` and 115 of `configuration.ex`. Each rule has a
test that fails when that rule alone is reverted: 19 mutants, all red (§6). A seeded walk of
300 random configurations of periodic, event and combined tasks, 40 steps each, matches a model
written from the record's text, plus oracles that know only the trigger samples. It passes on
20 seeds and reaches every case listed in §2.

The record is right on every rule it states. It is silent or wrong in eight places that
matter (§4). Three of them need a decision before landing:

- **The commit split.** PLAN lands `single` on the struct in commit 1 and the edges in commit
  2. Between the two, `cycle/3` raises `ArithmeticError` on any event task (probe `gap.exs`).
  Q6.
- **`next_due_in/1`.** The record says it counts periodic tasks only. Then rule 1 of the
  host's loop ("`next_due_in/1` is 0 after `start/1` and after `restart/2`") is false for an
  event-only configuration. It is already false for a configuration of task-less instances
  alone, which M2-1 pins as `:infinity`. The tempting alternative, 0 on a pending edge, can be
  held at 0 forever by a task-less writer, which makes a zero-time livelock (probe
  `next_due.exs`). Q1.
- **The owed tie-break test**, as worded ("both writing one global"), needs M2-4's
  `var_external`, because one driver per sink lets only one connection write a global. Q5.

## 1. What the spike built

- `Logex.Configuration.Task` gains `single` (a bool global's name, or nil), between `name` and
  `interval` in IEC's order. `@enforce_keys` is now `[:name, :priority]`, and `interval` and
  `single` default to nil.
- `check/1` gains these rules:
  - a task needs an interval or a single (C5);
  - an event task's interval of 0 is told to leave it out (C6b's sense);
  - a single names a bool global: a dint, an unknown name (with a did-you-mean, or the list of
    bool globals given once), and a task's or instance's name each get their own message;
  - a single no line can say (not one name token, or not a string) is the host's mistake, a
    line of the one `ArgumentError` (decision 36).
- In `Logex.Runtime`, each task's state now depends on its kind:
  - periodic: `%{next_due:, overlaps:}`, as before;
  - event only: `%{next_due: nil, overlaps: 0, last: 0}`;
  - both: `%{next_due:, overlaps:, last: 0}`.
- `cycle/3` gains step 3, `sampled/1`. It samples each trigger once from the globals, after
  the input image is merged and before any scan. It plans each task: due with a due time, or
  not. It moves a combined task's skipped due time past `now`. It sorts by `{priority, due
  time, declaration index}`.
- `run_task/2` counts missed periods only for a periodic run.
- `restart/2` rebuilds each task's state at the kept `now`, so `last` goes back to 0.
- `next_due_in/1` skips a `nil` next due time.
- The docs: the moduledoc's step 3, host-loop rule 1, `start/1`'s and `restart/2`'s "every
  task due" wording, the one-rule section's new trigger item, and `Program.initial_env/1`'s
  "M2-6 will add an event task's trigger", which moves to the runtime.
- The tests are in `test/logex/event_task_test.exs`. The existing pins that change: the
  `Task` keys in `runtime_test.exs`'s surface pin, and two `configuration_test.exs`
  assertions where `interval: nil, single: nil` now gives C5 instead of "found nil".

## 2. The rules settled, and what shows each

Mutant ids refer to §6. The "walk" is the seeded walk in `event_task_test.exs`.

| # | Rule (record) | As built | Shown by |
|---|---|---|---|
| R1 | `single` sampled once per cycle (§4.6 step 3), after the input merge and before any scan (T-rev §5.1) | `sampled/1` runs after `image!/2`, before the first `run_task/2` | "a sample is taken once a cycle: elapsed 0 cycles sample again"; Done-when; S1 (15 tests red) |
| R2 | due on a 0→1 change since the last cycle | `edge(0, 1, now)` | "a pulse inside one host step is not seen"; Done-when; S4 (a level: 9 red) |
| R3 | a trigger already 1 in the first cycle counts as an edge (decision 11, MatIEC's reading) | `last: 0` at `start/1` | an input point set by the host's first cycle (Done-when, "runs in cycle 1"); an unlocated global with initial 1 ("an initial value too"); S2 (9 red) |
| R4 | a trigger written by logic takes effect in the next cycle | sampled before any scan | the writer on a higher-priority periodic task that runs before the event task in the same cycle, through a connection to an unlocated global and to an output point: the event task runs in the next cycle, even at elapsed 0 (two tests); walk reach `:logic_trigger` |
| R5 | a 1→0→1 pulse inside one host step is not seen | one sample a cycle | the "pulse" test; and its remedy: elapsed-0 cycles sample again, so a host that cycles once per change loses nothing |
| R6 | an event task's due time, for the tie-break, is the cycle's `now` (§4.10 M2-6, Q-22 (a)) | its plan's due time is `now` | the owed tie-break in its visibility form (§4, Q5): a late periodic task of one priority runs first, whichever is declared first; one due exactly at `now` ties and falls to declaration order; priority still comes first. T1 (event first) and T2 (event last) are both red |
| R7 | decision 39: with `interval`, at most one run a cycle; due on an edge, or while the trigger samples 0 and a due time has come; a due time that comes while it samples 1 is skipped, not counted, the next on the same phase; an edge run does not move the phase | `both/6` and `skipped/3` | four hand tests: held high across several periods, edge runs, the phase kept, an edge and a due time in one cycle, a late cycle; D1–D6 red; N1 red. Walk reach `:held_skip`, `:overlap_under_zero` |
| R8 | a periodic run of a combined task is due at its due time | its plan's due time is `next_due` | "a periodic run is due at its due time, not at now"; T3 red |
| R9 | a task with `single` alone never overlaps (§4.10) | `periods(nil, …)` | "never overlaps, and has no periodic due time"; `overlaps/1` lists it at 0 |
| R10 | `next_due_in/1` counts periodic tasks only (§4.10 M2-1, T-rev §5.1) | a nil `next_due` is skipped; a combined task's `next_due` counts, even while its trigger is held 1 | N1 red; Q1 for the alternatives |
| R11 | `restart/2` sets the last sample to 0, so a trigger already 1 fires again (§4.9 table) | `task_state(task, now)` | an input point held 1 through the restart (the image is kept), an unlocated global back at initial 1, and a combined task: each fires once in the next cycle; S3 red |
| R12 | a `ton` in an event-task program times across events (§4.6 caveat) | unchanged `ton` | events at 0 and 60 ms give `.acc` 60. 500 ms with no event, then one event: done at once, `.acc` 100 |
| R13 | events: `{:ran, …}` and `{:overlap, …}` only | no new kind | "an event task's run is its `{:ran, …}` events alone; one with no instance leaves none" |
| R14 | §4.4 checks: a task needs `interval` or `single`; a `single` is a bool global | §1 | five tests; C1–C5 red. M2-1's spoil property (`spoil_struct/2`) reaches the new key with no change: C3 and C5 also turn its two start/1 tests red |
| R15 | Done-when: from an input point, once per rising edge, before lower-priority tasks due in the same cycle, cycle 1 if already true | — | two tests. The edges come from the trace alone, ten cycles, and the edge runs before the 10 ms priority-2 task in every cycle it runs |
| R16 | cost: linear in the tasks declared (§4.10 M2-1 "Cost") | one pass to sample and plan, one sort of the due | growth test (4x the combined tasks < 6x, quiet and firing); probe `cost.exs` (§3) |

**The walk** (`event_task_test.exs`, "a seeded walk"):
- **Configurations:** 300 random ones, each with 0 to 4 tasks of random kinds, triggers on
  input points, output points and unlocated globals (one with initial 1), random priorities,
  and 1 to 5 instances of a relay, an inverter, a one-shot and a `ton`, randomly wired; 40
  steps each.
- **The model** is written from the record's text in phase-point form (`anchor + k ·
  interval`), not from the code. Each step it checks events, outputs, `overlaps/1`,
  `next_due_in/1`, every global and every integer tag. Each instance is scanned by `call/4`.
- **The samples oracle** knows only each trigger's value going into a cycle, read through
  `get!/2` and the inputs sent. It checks four things:
  - an event-only task runs exactly on an edge;
  - a combined task runs on every edge, never while its trigger stays 1, and at most once a
    cycle;
  - consecutive task runs never go down in priority.
- **Reach:** it asserts it reached each of `restart`, `{:edge, true}`, `{:edge, false}`,
  `held_skip`, `first_cycle_edge`, `restart_refire`, `logic_trigger`, `overlap_under_zero`
  and `tie_event_periodic`.
- **Seeds:** `WALK_SEED` 1–20 all pass (`probe/walk-seeds.log`).

## 3. Probe receipts (`scratchpad/m2-6/probe/`, each with its `.log`)

**`next_due.exs`** compares two `next_due_in/1` readings, each driving a runner that sleeps on
it: (a) periodic due times only, as built; (c) also 0 on a pending edge (a trigger that reads 1
now against a last sample of 0). Each tuple is {slept ms, events}.

```
1. an event chain, e1 writing e2's trigger
  (a) periodic only: 1 cycles; first: [1]
  (c) pending edges too: 2 cycles; first: [1, {0, 1}]
2. a task-less instance writing two triggers in turn
  (a) periodic only: 1 cycles; first: [1]
  (c) pending edges too: 51 cycles; first: [1, {0, 2}, {0, 2}, {0, 2}, {0, 2}, {0, 2}, {0, 2}, {0, 2}]
3. after start/1: (a) :infinity, (c) 0
   after restart/2: (a) :infinity, (c) 0
```

Under (a), e2 never fires until something else makes a cycle. Under (c), a task-less
oscillator driving `x = s` and `y = not s` keeps a pending edge after every cycle: 50 cycles at
elapsed 0, and `now` never moves.

**`plant.exs`** is §4.4's plant with `trip single estop priority 0`, the motors replaced by a
relay, since `var_external` is M2-4's. `snap` runs first in each cycle the e-stop rises. It
reads the output points as the last cycle left them, which is §4.4's "reading the output
points back":

```
t=100 estop rises         k1=1 k2=1 k1_at_trip=1 k2_at_trip=1  ran: trip:snap fast:m1 slow:m2
t=110 held                k1=1 k2=1 k1_at_trip=1 k2_at_trip=1  ran: fast:m1
t=120 released, pb_1 off  k1=0 k2=1 k1_at_trip=1 k2_at_trip=1  ran: fast:m1
t=130 rises again         k1=0 k2=1 k1_at_trip=0 k2_at_trip=1  ran: trip:snap fast:m1
```

**`cost.exs`** measures reductions per cycle (least of 5) with n tasks of one kind and no
instance, so it is the scheduler's own cost. "fire" sends a rising edge on the one shared
trigger.

```
n      kind      quiet    fire   next_due_in
100    periodic     1411    1430     425
1600   periodic    19413   19432    6550
100    event        1611    4944     327
1600   event       22613   83258    4927
100    both         1711    5244     425
1600   both        24213   87584    6550
```

Linear when quiet. A firing cycle sorts n due tasks: 16x the tasks cost 16.8x.

**`gap.exs`** runs on M2-1's runtime with only the spike's `configuration.ex`, which is PLAN's
commit 1 without commit 2:

```
start/1 accepted it; next_due_in/1: 0
cycle/3 raised ArithmeticError: bad argument in arithmetic expression
```

## 4. Where the record is silent, ambiguous or wrong

**Q1 · `next_due_in/1` with event tasks, and the host loop's rule 1.** *Wrong and silent.*
§4.10 M2-1 and T-rev §5.1 say it counts periodic tasks only. The moduledoc's rule 1 says "The
first cycle runs at once: `next_due_in/1` is 0 after `start/1` and after `restart/2`". That is
false for an event-only configuration, and already false on main for a configuration of
task-less instances alone (`scheduler_test.exs` pins `:infinity` after `start/1`). The record
is also silent on a trigger written by logic, which needs a next cycle to be seen.
- (a) **Periodic due times only** (built). Rule 1 is restated: a runner cycles at once after
  `start/1` and `restart/2`, whatever `next_due_in/1` says. A combined task's due time counts
  even while its trigger is held 1, which costs one idle wake a period. The documented caveat:
  a trigger written by logic fires at the next cycle the runner makes. In a configuration of
  event tasks alone, a write by one event task to another's trigger waits for the next input
  change (probe 1).
- (b) **(a), plus 0 after `start/1` and `restart/2` for an event-only task.** Its `next_due`
  would be `now` until its first sample. Rule 1 keeps its words for any configuration with a
  task, at the cost of a marker that means nothing to a runner obeying (a)'s rule 1.
- (c) **0 whenever an edge is pending.** Event chains are prompt, but a task-less writer that
  raises two triggers in turn holds it at 0 for ever: a zero-time livelock (probe 2). A lone
  trigger cannot do this, because the cycle that sees the pending edge consumes it. Two
  triggers can.

*Recommend (a)*, with rule 1 restated as the spike words it. (c)'s hazard is a runner's
concern, and the runner is not designed yet.

**Q2 · A combined task's edge run when a due time has also come: its due time for the
tie-break.** *Silent.* §4.6 gives an event task `now`, and adds that with `interval` "decision
39 applies". Decision 39 gives no due time.
- (a) `now` (built).
- (b) the due time that came, the earlier of the two.

*Recommend (a).* Decision 39 skips that due time and does not run it, so it has waited for
nothing. (A periodic run of a combined task is due at its due time: R8.)

**Q3 · A late host's edge cycle: the due times that came since the last cycle.** *Ambiguous.*
Decision 39 reads by the sample, which is 1 on an edge cycle. But the trigger sampled 0 at the
cycle before, and a periodic task in the same gap would count them as missed.
- (a) Skipped and not counted (built, D6 red). This reading follows decision 39's words.
- (b) Counted as missed, `div(now - next, interval)`.

*Recommend (a).* It hides a host's lateness only while the trigger is 1, which is when rule 2
owes no periodic runs anyway.

**Q4 · A late host's falling cycle: a due time that came while the image still held 1.**
*Ambiguous* (T-rev §5.1: "when the sample falls to 0, the task is next due at its next phase
point").
- (a) It runs, because the sample decides (built).
- (b) It is skipped, because the input image held 1 until this cycle's merge.

*Recommend (a).* There is then one rule for every source of trigger. For a trigger written by
logic, the value during the gap is this cycle's sample. For an input point, it is the last
sample. Only the sample is known to both. Reword T-rev §5.1's sentence when it is adopted.

**Q5 · The owed tie-break test.** *Wrong as worded for M2-1 data.* "An event task and a late
periodic task of one priority, both writing one global, asserting which write lands" needs two
writers of one global. One driver per sink lets only one connection drive it. M2-4's
`var_external` allows two, with a warning (W4/W5), and M2-4 lands before M2-6.
- (a) As worded, through `var_external`.
- (b) The visibility form (built): one instance writes `g`, the other copies `g` to an output
  point, and the output shows which ran first.
- (c) Both.

*Recommend (c)*: the worded form in `end_to_end_test.exs`, as owed, and (b) beside the rule
tests, since it needs only connections and no warning.

**Q6 · PLAN M2-6's commit split.** *Wrong.* PLAN's commit 1 holds the stanza, the task lines,
the warning from the walk and `single` on `Logex.Configuration.Task`. Commit 2 holds the edges
at run time, the Done-when and the documents. After commit 1, `check/1` accepts an event task
and `cycle/3` raises `ArithmeticError` on it (`gap.exs`), against "nothing else may escape".
The contract walk would not see it, because it generates no event task.
- (a) Data first, as M2-1 did:
  - commit 1: the field, `check/1`'s rows, the edges, the Done-when from data and the contract
    walk;
  - commit 2: the text, meaning the stanza, `single` on task lines and reserved, W6 from M2-4's
    walk, the Done-when from source, and the documents.
- (b) PLAN's order with an interim refusal in `start/1`. That would be a message about a word
  before its rule lands.
- (c) One commit.

*Recommend (a).*

**Q7 · `Logex.Configuration.Task`'s enforced keys.** *Silent.* With `interval` optional, the
spike enforces `[:name, :priority]`. A struct literal with neither `interval` nor `single`
then compiles, and is a C5 diagnostic, not a compile error. The surface pin builds structs with
`struct/1`, which ignores `@enforce_keys`, so nothing pins them.
*Recommend*: enforce `[:name, :priority]`, and pin the enforced keys too, through
`Logex.Configuration.Task.__info__(:struct)`'s `required` flags.

**Q8 · The words of the new checks.** *Silent.*
- The did-you-mean for an unknown `single`: among bool globals (built), or among all globals
  (T-rev C21). *Recommend* bool globals, since a dint is never the fix.
- C5's and C6b's examples repeat the task's name. M2-1 checks a refused element's other fields,
  so an example can print a name no line can hold: "task `u.v` needs an interval, as in `task
  u.v interval 10 priority 1`" (`configuration_test.exs`, the refused-name test). *Recommend*:
  the name in an example only when it is a name, and `t` otherwise.
- A dotted `single` (`m1.out`, a program output that IEC allows, or a location) gets "is not a
  global" from data. *Recommend* that M2-2's port of the §4.7 readings (T-rev C44–C48, N1/N2)
  covers `single` too, as T-rev already planned for the text.

**Q9 · `overlaps/1` and the events.** *Silent.*
- `overlaps/1` lists an event-only task at 0 (built), rather than leaving it out. "Each task's
  overlap count" stays true.
- No new event kind (built). Neither an edge nor a skipped due time is reported. The set is
  open, so one can be added later.

*Recommend both as built.*

**Q10 · A trigger nothing can raise.** *Silent.* `single g` on an unlocated global that nothing
writes fires once a start if its initial value is 1, and never otherwise. W1 ("nothing uses
it") cannot fire, because the `single` is a use. T-rev Q-12's W7 ("read and written by
nothing") would catch it, and is deferred to `var_config`. *Recommend*: say so in M2-6's
documents, and take it up with W7.

**Q11 · Words on main that M2-6 makes false.** The spike fixes all but the last two
(`runtime.ex`, `program.ex`, `configuration.ex`):
- the moduledoc's host-loop rule 1 (Q1). It is already false on main for task-less-only
  configurations, a pre-existing contradiction with `scheduler_test.exs`;
- `start/1`'s and the moduledoc's "every task due at once";
- `restart/2`'s "every task due at the next cycle";
- step 3's "A periodic task is due…";
- the one-rule section, which lacks the trigger;
- `Program.initial_env/1`'s "M2-6 will add an event task's trigger". The trigger is the
  resource's state, not a tag's;
- `Logex.Configuration.Task`'s "A periodic task";
- CLAUDE.md's Key Files entry for `cycle/3`'s steps, which gains "each trigger sampled";
- README's "A configuration", since a cycle's rules change (CLAUDE.md: "nothing tests this").

**Q12 · The one contract walk.** *Owed.* `api_contract_test.exs` generates no event task. Its
oracle, "runs + overlaps == periods + 1", is false for a combined task, whose skipped periods
are neither. *Recommend*: extend that walk, not a second one as the spike has:
- a task kind drawn at random;
- the oracle restated with skipped periods;
- the samples oracle (R15's walk);
- reach for the new cases.

## 5. What M2-6's landing commits must contain (order as Q6 (a) recommends)

**Commit 1 · event tasks from Elixir data, at run time.**
- `Logex.Configuration.Task`:
  - `single`, in IEC's order;
  - enforced keys `[:name, :priority]` (Q7);
  - its doc.
- `check/1`'s rows, pinned as whole lists in `configuration_test.exs`:
  - a task needs an interval or a single;
  - an event task's interval 0 is told to leave it out;
  - a single is a bool global (dint; unknown, with a did-you-mean among bool globals; a task's
    or instance's name);
  - a single no line can say is the host's mistake.
- Pins it changes:
  - "task `c` … found nil", which becomes C5;
  - the refused-name file test;
  - the surface pin's `Task` keys.
- `Logex.Runtime`:
  - task state by kind;
  - step 3: sample after the merge and before any scan, plan, skip, sort;
  - an event task's due time is `now`, and a combined task's periodic run is due at its due
    time;
  - decision 39;
  - `restart/2` sets `last` to 0;
  - `next_due_in/1` skips an event-only task.
- Documents for the same commit:
  - the moduledoc's step 3, host-loop rule 1 restated (Q1), the "every task due" wordings, and
    the one-rule section's trigger item (start 0, sampled once a cycle, restart 0, kept by an
    edit, a changed `single` or an added or removed `interval` refused);
  - `Program.initial_env/1`'s sentence moved;
  - CLAUDE.md's `cycle/3` steps;
  - README's "A configuration": an event task in the example, with re-run output.
- Tests:
  - `scheduler_test.exs`: a test per rule, R1–R14 above;
  - `end_to_end_test.exs`: PLAN M2-6's Done-when from data, and the owed tie-break in its
    worded `var_external` form (Q5);
  - `api_contract_test.exs`: the walk extended (Q12);
  - a growth test with combined tasks, quiet and firing.
- The commit message's mutation rows: the 19 of §6, each red alone.

**Commit 2 · `single` in the text** (on M2-3's task lines and M2-4's walk):
- the `single` stanza in `docs/naming.md` (none on main; T-rev has one);
- `single` reserved in `.logex`;
- the task line `task <n> single <g> [interval <ms>] priority <p>` and its reading messages;
- every commit-1 check asserted again from source;
- the §4.7 readings for a dotted `single` (Q8);
- W6a and W6b from M2-4's IR walk, reaching a `ton` inside a block through `cal`;
- the Done-when from source;
- §4.4's plant runnable with its `trip` task;
- `docs/organisation.md` §4.6, §4.9 and §4.10 annotated as landed, and PLAN's M2-6 status.

## 6. The mutation table (each rule reverted alone, full suite, final test set)

Every row is red. The fewest tests a revert turns red is 1 (C2 and C4, each by its own hand
test). Every row is caught by at least one hand test, not by the walk alone: T3 and D5 were
caught only by the walk until the spike added a hand test for each.

| id | rule (revert) | suite |
|---|---|---|
| S1 | sampled after the input merge (before it) | 541/556 |
| S2 | last sample 0 at start (1: no first-cycle edge) | 547/556 |
| S3 | `restart/2` sets the last sample to 0 (kept) | 553/556 |
| S4 | an edge, not a level | 547/556 |
| T1 | an event task's due time is `now` (first in its priority) | 552/556 |
| T2 | an event task's due time is `now` (last in its priority) | 554/556 |
| T3 | a combined task's periodic run due at its due time (at `now`) | 554/556 |
| D1 | periods under a high trigger not counted (counted) | 553/556 |
| D2 | no periodic run while the trigger is 1 (runs) | 553/556 |
| D3 | an edge run keeps the phase (moves it) | 551/556 |
| D4 | one run a cycle (an edge and a due time run twice) | 552/556 |
| D5 | the phase kept when the trigger falls (re-anchored at the fall) | 552/556 |
| D6 | an edge cycle counts no missed period (counts them) | 554/556 |
| N1 | `next_due_in/1` counts a combined task's due time (ignores it) | 551/556 |
| C1 | a task needs an interval or a single (neither accepted) | 553/556 |
| C2 | a single is a bool global (a dint accepted) | 555/556 |
| C3 | a single names a global (an unknown accepted) | 553/556 |
| C4 | an event task's interval 0 told to leave it out (generic message) | 555/556 |
| C5 | a single no line can say is the host's (accepted) | 553/556 |

Driver and per-test detail: `scratchpad/m2-6/mut/driver.py`, `mutation.json`, `table.md`. The
first D5 mutant re-anchored only that cycle's decision, not the stored due time, and so was
weaker than the rule. It was rewritten and rerun.

Not built as a mutant: lazy sampling, where a trigger is read at its task's turn, so that a
write earlier in the cycle is seen in the same cycle. The two "written by logic" tests assert
exactly that it is not seen: the writer runs first in the cycle, and the event task waits for
the next one.

## 7. Files

- `scratchpad/m2-6/spike-report.md`: this report.
- `scratchpad/m2-6/spike.patch`: the diff.
- `scratchpad/m2-6/spike/`: the copy, branch `m2-6-spike`, with the change staged and not
  committed.
- `scratchpad/m2-6/spike/test/logex/event_task_test.exs`: the 27 tests and the walk.
- `scratchpad/m2-6/probe/`: `next_due.exs`, `plant.exs`, `cost.exs` and `gap.exs` (`gap.exs`
  runs in `scratchpad/m2-6/gap/`, main with only the spike's `configuration.ex`), with
  `*.log` and `walk-seeds.log`.
- `scratchpad/m2-6/mut/`: the driver, `mutation.json` and `table.md`.
- `scratchpad/m2-6/gate.log`, `gate-test*.log`: the gate.
