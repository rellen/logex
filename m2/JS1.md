# JS1 · Judging M2-1's three designs: correctness and fit

Label JS1, track S (`PLAN.md` M2-1, the scheduler from Elixir data). Written 2026-10-02
against `/home/user/logex` at `47319f7`, which this pass did not modify (`git status
--short` is empty, HEAD `47319f7`). The lens: does each design obey every decided rule
(`docs/organisation.md` §4.4–4.9 and §7, `PLAN.md` M2-1 and its OE-2 constraints,
`CLAUDE.md`'s conventions)? Can its scheduler be broken?

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, both at `47319f7`.
`S1.md`, `S2.md` and `S3.md` are the design documents in `scratchpad/m2/`. A design's code
is cited by function name, because its line numbers move. Every probe and its output is in
`scratchpad/m2/JS1-probe/`. "Unverified" marks what I could not check.

**How to rerun a probe.** Apply the design's patch to a fresh copy of `47319f7`. Then, in
that copy, after `source scratchpad/toolchain/env.sh`, run `DESIGN=S2 mix run
scratchpad/m2/JS1-probe/<probe>.exs`. `JS1-probe/adapters.exs` maps one generic
configuration onto each design's `new!/1`. I deleted the three copies I judged in, as the
brief asked.

---

## 0. The verdict

| Design | Score | In one line |
|---|---|---|
| **S2** | **8.5** | **Winner.** Its validator is total and its checks are tested with lines and a file. It keeps the decided overlap count. Its one decided-rule gap, shared with S1, is that there is no restart that keeps the input image. |
| S3 | 7.0 | It has the best host contract: `restart/2` keeps `scan/2` and a one-instance configuration in agreement across a restart. But `new!/1` lets `FunctionClauseError` escape, and `start/1`'s re-check misses cases. It builds an initial value on an output point, which the text cannot say, and its OE-2 table allows located I/O to change while running. |
| S1 | 6.5 | The core is small and correct. But `new!/1` lets `FunctionClauseError` escape, it builds a departure (no overlap count), and its only restart contradicts its own restart rule. |

**The schedulers are equally correct.** All three agree exactly with an independent
oracle, cycle by cycle (§1.2). So the decision rests on the constructor, the host contract
and fit with the decided rules. On those, S2 has one shared gap. S1 and S3 each have a hard
defect that breaks the rule "Nothing else may escape the public API" (`CLAUDE.md:135`).

---

## 1. What I ran

### 1.1 Each design's gate, on my own copy

I applied each patch to a fresh copy of `47319f7`. `git apply --check` passed for each,
then `git apply`. I ran the four gate commands on Elixir 1.20.4 / OTP 28 and judged each by
its exit code. Receipts: `scratchpad/m2/JS1-S{1,2,3}-gate.log`.

| Design | format | compile | test compile | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| S1 | 0 | 0 | 0 | 0, `Result: 484 passed (6 doctests, 478 tests)` |
| S2 | 0 | 0 | 0 | 0, `Result: 486 passed (7 doctests, 479 tests)` |
| S3 | 0 | 0 | 0 | 0, `Result: 491 passed (6 doctests, 485 tests)` |

Each design's count matches its own claim. Each suite also passed under `--seed 1`, `2`
and `3`, every run exit 0, so I saw no flakiness.

### 1.2 The scheduler, fuzzed against a closed-form oracle (`sched_fuzz.exs`, `sched_many.exs`)

**What the oracle is.** I wrote it from org §4.6 alone. It shares no bookkeeping with any
design:
- A task's pending due time is `anchor + P·(div(last_run − anchor, P) + 1)`, or `anchor`
  before its first run.
- `missed` is `div(now − anchor, P) − div(due − anchor, P)`.
- Due tasks run in the order (priority, due time, place). Within a task, instances run in
  declaration order. Task-less instances run last, every cycle.

**What it compared.** Every cycle's `:ran` events, in order, and its `:overlap` events, in
run order. Also `next_due_in/1`, and `overlaps/1` where a design has it.

**What it drew.** Configurations of 0–6 tasks, with intervals from {1, 2, 3, 5, 7, 10, 30}
and priorities 0–2, so ties are common. Task and instance names are shuffled, so
declaration order is not name order. Each configuration has 1–6 instances, on a random
task or none. Each step has an elapsed time from {0, 0, 1, 2, 3, 4, 5, 9, 10, 11, 25, 30,
31, 47, 100}.

**Does it detect anything?** I reverted S1's due-time tie-break (`{priority, place}` for
`{priority, next[name], place}`). The oracle reported 1,827 mismatching cycles, so it
detects a real defect. I then restored the file and checked it with `cmp`.

| Run | S1 | S2 | S3 |
|---|---|---|---|
| seeds 1 (400), 2, 3, 4 (600 each) configurations × 60 cycles | 0 mismatches | 0 | 0 |
| seed 7: 20 configurations of about 300 tasks and 400 instances × 60 cycles | 0 | 0 | 0 |

That is about 132,000 cycles per design, each matched exactly.

### 1.3 Targeted probes (`targeted.exs`, output `targeted.out`)

The three schedulers gave the same answers to every probe below. The one difference is
where an overlap event sits in the event list:

| Probe | Every design |
|---|---|
| `next_due_in/1` right after `start/1` | 0 |
| `cycle(0)`, then `cycle(0)` again | the second runs only the task-less instance; `next_due_in` 10 |
| 10 ms and 30 ms tasks, a cycle at 35 | `{:overlap, "fast", 2}`; `next_due_in` 5; at 40 the 10 ms task runs with no overlap (phase kept) |
| the first cycle at 25 ms | `{:overlap, "fast", 2}`: the decided anchoring, org:556-557 |
| task-less instances only | `next_due_in` is `:infinity`; elapsed-0 cycles run them every time |
| a task with no instance, late | its `{:overlap, "idle", 3}` is reported; nothing runs |
| `cycle(rt, 10^12, %{})` | runs, `{:overlap, "fast", 99999999999}` |
| the same call made twice | equal results (purity) |
| a chain `x → g → y` across priorities | `y` is 1 in the same cycle: visibility follows the order |

**Where the overlap event sits.** S1 and S2 put each overlap just before its task's scans.
S3 puts all overlaps first. Nothing decided fixes the order: org:679 gives only the event
type (S3's Q-19).

### 1.4 The README program through `scan/2` and a one-instance configuration (`readme.exs`)

The walk is 3,000 seeded steps of input changes and elapsed times from {0, 1, 7, 10, 30,
130, 999, 5000}. In 1 step in 30, both sides take a cold restart: `restart/3` on the lone
side. On the configuration side, S3 takes `restart/2`; S1 and S2 take `start/1` again,
because they have no restart. At every step I compared the outputs and every tag through
`get/2`.

| Walk | S1 | S2 | S3 |
|---|---|---|---|
| README motor; the host resends nothing after a restart | **708 output mismatches**, 1,045 mismatching steps | **708**, 1,045 | 0 |
| README motor; the host resends its whole image after a restart | 0 | 0 | 0 |
| M2-3's timed motor; time passing; resend | 0 | 0 | 0 |

The minimal repro is `restart_min.exs`: press start, take a cold restart on each side,
then cycle with no inputs.

```
S1 after a cold restart, no input resent: scan/2 %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}  configuration %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 1200}
S2 after a cold restart, no input resent: scan/2 %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}  configuration %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 1200}
S3 after a cold restart, no input resent: scan/2 %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}  configuration %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
```

### 1.5 Host mistakes through `new!/1` (`newjunk.exs`)

This probe sends 19 kinds of bad data to `new!/1`, among them an improper list in each part
and an improper keyword list. The rule is `CLAUDE.md:135`: "Nothing else may escape the
public API".
- **S2:** every case raises `ArgumentError`.
- **S1:** 4 escape as `FunctionClauseError`.
- **S3:** 6 escape as `FunctionClauseError`.

The cases are §2 and §4.

### 1.6 A configuration edited by hand, given to `start/1` and cycled (`handbuilt.exs`)

The probe takes a valid configuration from `new!/1` and applies two random edits to the
struct. An edit puts junk in a field, puts junk in one field of one element, appends a junk
element, or drops elements. Then it calls `start/1`, two cycles and `next_due_in/1`.
3,000 draws per design.

| Outcome | S1 | S2 | S3 |
|---|---|---|---|
| refused with `ArgumentError` | 84 | 2,999 | 2,931 |
| accepted and ran | 552 | 1 | 20 |
| **another exception escaped** | **2,364** (`Protocol.UndefinedError`, `BadMapError`, …) | **0** | **49** (`FunctionClauseError` 40, `Protocol.UndefinedError` 9) |

S1 declares this outside its contract. S3 claims it is refused (§4).

### 1.7 Fourteen extra one-rule mutants (`mutate.py`, output `mutants.jsonl`)

These are rules the designs' own mutation tables do not revert alone. Each mutant was
applied alone, compiled with no warning, and the full suite run. The runtime file was
restored after each and checked with `cmp` against the design's own spike.

| Mutant | S1 | S2 | S3 |
|---|---|---|---|
| a task's instances in reverse declaration order | red: runtime_test + walk | red: **walk only** | red: scheduler_test + walk |
| task-less instances in reverse order | red: **walk only** | red: scheduler_test + walk | red: scheduler_test + walk |
| a constant copied in as 0 | red | red | red |
| `missed` capped at 1 | red | red | (S3's SC-8 already) |
| `next_due_in` takes the latest task, not the soonest | red | red | red |

All 14 are red. Two rules are caught only by the seeded walk, which restates the order it
checks. `CONTRIBUTING.md:183-197` says a property that restates a rule cannot catch that
rule's defect. So each of those two rules lacks a worked test (§2, §3).

---

## 2. S1 · the smallest correct core — 6.5

### Strengths, reproduced

- **The public surface is the decided one, with nothing added.** It is `start/1`,
  `cycle/3`, `next_due_in/1` and `get/2` with org:675-678's signatures, plus
  `Configuration.new!/1`.
- **Every scan is `call/4`, and `start/1` builds each instance with `instance/1`** (fix
  F14).
- **The scheduler is exact** (§1.2).
- **The Done-when tests are sound.** They show the order through a chain of outputs, with
  no event read. The README equality runs over the README's steps plus a 300-step seeded
  walk, and again with time passing (`end_to_end_test.exs`, "the scheduler, from Elixir
  data (M2-1)").
- **The state table handles located I/O correctly.** S1.md §6, line 340, refuses an input
  point added while running and cites org:860-863.
- **My extra mutants found no unpinned rule** in `runtime_test.exs` beyond the task-less
  order (§1.7).

### Defects

1. **`new!/1` lets `FunctionClauseError` escape for an improper list.**
   - Repro, `newjunk-S1.out`:
     ```
     S1 tasks improper: ESCAPE FunctionClauseError: no function clause matching in Enum."-map_reduce/3-lists^mapfoldl/2-0-"/3
     ```
     The same holds for `instances`, `connections` and `globals`.
   - Against: `CLAUDE.md:135`. OE-1 already set the precedent of checking a host's list as
     a proper list (org §7 F8, org:1608).
2. **It builds a departure from a decided rule.**
   - org:596 says a late task "adds `missed` … to its overlap count".
   - Decision 11 (org:1484) and PLAN:1361 say missed periods are "coalesced, counted and
     reported".
   - S1 keeps no count (S1.md §12 item 1, Q-B). The departure is stated and argued, but the
     spike builds the departure rather than the decided rule. S2 and S3 show that the
     count costs one function and one test.
3. **Its only restart contradicts its own restart rule.**
   - S1.md §6, line 340, says a resource restart keeps an input point's value: "kept, the
     host's image, as `restart/3` keeps var_inputs".
   - But S1.md §7.7, line 425, makes `start/1` again "a cold restart", and `start/1` puts
     every input point at 0.
   - Repro: `restart_min-S1.out` (§1.4). After a cold restart with no input resent,
     `scan/2` gives `"motor" => 1` and the configuration gives `"motor" => 0`.
   - This is against org:686-688: `restart/3` keeps the var_inputs "because they are the
     host's input image, which a configuration's copy-in refreshes every scan anyway: that
     is what keeps `scan/2` and the one-line configuration in agreement across a restart."
4. **`start/1` trusts the struct.** Of 3,000 edited structs, 2,364 escaped as another
   exception (§1.6).
   - S1 declares this outside the contract (S1.md Q-L).
   - The precedent points the other way. In decision 28 (org:1559-1572) the maintainer
     chose the full entry check over declaring the rest of a hand-built value outside the
     contract.
   - A `%Logex.Configuration{}` is the data API's own value. S2 shows the check costs one
     linear pass.
   - I score this as a fit weakness, not a hard defect.
5. **The path that gives a check its line is private and untested.**
   - `new!/1` refuses a `line:` key, and its checks are private. So no test reaches a
     `{line, message}` with a line, which M2-2's located diagnostics depend on.
   - `configuration_test.exs:238` only shows the key refused.
   - The brief asks the checks to serve M2-2's parser with file and line. S1 claims this
     but does not show it.
6. **The order of task-less instances is pinned only by the walk** (§1.7).
7. **Some messages are misleading.** From `targeted.out`:
   - `get(rt, "start.x")`, where `start` is a global, says `` `start.x`: no instance `start`:
     the instances are `m` ``.
   - `get(rt, "m.")` says `` `m` is a `motor`, which declares no "" ``.
   - The input `"m"`, an instance, is reported as `` input `m` is not declared ``.

---

## 3. S2 · the configuration from the whole milestone's view — 8.5 (winner)

### Strengths, reproduced

- **The validator is total.**
  - All 19 bad `new!/1` inputs raise `ArgumentError` (`newjunk-S2.out`).
  - Of 3,000 hand-edited structs, `start/1` refused 2,999 with `ArgumentError`, accepted 1,
    and let no other exception escape (`handbuilt-S2.out`).
  - `start/1` re-checks the configuration (RT-1), which fits decision 28's precedent.
- **The checks are tested with lines and a file, as M2-2 needs.**
  - `configuration_test.exs`, around line 495, gives a hand-built configuration
    `file: "plant.lcf"` and asserts `stage: :configure` diagnostics in line order.
  - The cross-reference carries the other element's line, as org:457's receipt form does.
    From `lines-S2.out`:
    ```
    line: 4, message: "global `k` is at `panel.i.0`, the address of global `pb` (line 3): one address holds one global"
    ```
    S3's `check/1` gives `{4, "… where `pb` already is …"}`, with no line for `pb`.
- **The decided overlap count is kept**, by `overlaps/1` (org:596), and pinned:
  `end_to_end_test.exs` asserts `%{"fast" => 1, "slow" => 0}`.
- **A location must lex as one name token** (`Configuration.location/1` calls
  `Logex.Lexer.tokenize/1`). That is org:502-503's own rule.
- **The §4.4 plant runs on the spike and reproduces org §4.6's receipt exactly.** I reran
  `S2-probe/plant.exs` on my copy and got the six lines of S2.md §7.7 verbatim. `t=110 tt_1
  trips k1=1 k2=1 sp_1=0 sp_2=1200 m1.fault=1` matches org:699-704.
- **The scheduler is exact** (§1.2). Its 62-mutant table is all red (S2.md §13). My 5 extra
  mutants are all red too.
- **Its state table handles located I/O correctly.** S2.md §6 says "a **located** one is
  refused (located I/O, org:860-863)".
- **Its extension plan is the most concrete.** The element structs have defaults, so M2-6's
  `single:` is a new field, not a reshape (S2.md §7).

### Defects

1. **It has no restart that keeps the input image, so `scan/2` and a one-instance
   configuration disagree after a restart unless the host resends.**
   - Repro: `restart_min-S2.out` and `readme-S2.out`. 708 of 3,000 steps give different
     outputs when the host resends nothing.
   - Against org:686-688, quoted in §2 item 3.
   - S2 says "the host resends its image" (S2.md §6, S2-Q7). That is consistent, but it
     moves the decided agreement onto a host duty.
2. **`new!/1` accepts a `line:` from Elixir.**
   - Repro, `newjunk-S2.out`: `S2 task line given: accepted`.
   - The house rule for data from Elixir is `Logex.Declarations.validate!/1`
     (`lib/logex/declarations.ex:125-134`): "Such a tag has no `line`: a line is what marks
     a tag declared in source", and it raises `a tag declared from Elixir has no line`.
   - S2's own edit to `Logex.Diagnostic`'s moduledoc says `line` is nil "for a
     `:configure` problem with an element built from Elixir". An element built from Elixir
     can now carry a line, and its diagnostic will cite a line no file has.
3. **The order of a task's instances is pinned only by the walk** (§1.7,
   `inst-order-in-task`: only `api_contract_test.exs` fails). The rule is "within a task,
   instances run in declaration order" (org:574-575). This is the gap `CONTRIBUTING.md:183`
   describes: no worked test in `scheduler_test.exs` declares two instances on one task.
4. **Minor points:**
   - The `warnings: []` field is landed, but nothing in M2-1 fills it, so no test can pin
     it.
   - `Logex.Configuration.Task` shadows Elixir's `Task` inside `configuration.ex`. S2 lists
     this itself (S2.md §12).
   - `configuration.ex` is 1,101 lines long.

---

## 4. S3 · from the host's side — 7.0

### Strengths, reproduced

- **`restart/2` keeps the clock and the input image.** So the README motor agrees with
  `scan/2` across restarts with no resend: 0 of 3,000 steps differ (`readme-S3.out`,
  `restart_min-S3.out`). This is the agreement org:686-688 describes. S3 also states each
  piece of state's restart rule (S3.md §6).
- **`overlaps/1` keeps the decided count.**
- **The host contract is the most explicit of the three.** The moduledoc gives the host's
  loop, the first cycle running at once, inputs as a delta, outputs as a snapshot, and
  events as an open set.
- **The scheduler is exact** (§1.2). The 63-mutant table is all red. The mutants show that
  the 16x growth step catches an appended event list that a 4x step missed (S3.md §10).
- **The oracle walk shuffles task names**, so declaration order differs from name order.
  That is what made S3's SC-3 red.
- **Q-20** rewords the Done-when's clock as cycles at 0, 10, …, 990 ms. That reading is
  what all three designs' tests use.

### Defects

1. **`new!/1` lets `FunctionClauseError` escape.**
   - Repro, `newjunk-S3.out`:
     ```
     S3 tasks improper: ESCAPE FunctionClauseError: no function clause matching in Enum."-map/2-lists^map/1-1-"/2
     S3 keyword improper: ESCAPE FunctionClauseError: no function clause matching in Enum.predicate_list/3
     ```
     The same holds for `instances`, `connections`, `globals` and `programs`: 6 of 19 cases.
   - Against `CLAUDE.md:135`, and the precedent of org §7 F8.
   - S3's constructor walk feeds 1,500 broken configurations but never an improper list.
2. **`start/1`'s re-check is not total, which contradicts S3's own claim.**
   - S3.md Q-17, line 988, says: "a configuration edited by hand is refused with a message
     instead of crashing a cycle". The moduledoc says `start/1` "checks a configuration
     again, as `Logex.Configuration.new!/1` does".
   - Repro, `s3_escape-S3.out` and `handbuilt-S3.out`. 49 of 3,000 hand edits escaped:
     - an improper list in a part gives `FunctionClauseError`;
     - a `line` of `%{}`, `{1}` or a program on an element gives `Protocol.UndefinedError`,
       because `start/1` formats `"line #{line}: …"`.
   - S2 refuses all of these.
3. **It builds an initial value on an output point, which the decided text cannot say.**
   - Repro, `outinit-S3.out`:
     ```
     S3 output point with initial 1: accepted, outputs %{"k" => 1}
     ```
     S1 and S2 refuse it.
   - Against org:414, whose line shape `var_global <n> <type> at <dev>.q.<k>` takes no
     initial value, and org:779-780: "the data API refuses anything the text cannot say".
   - S3 presents this as Q-10 and recommends allowing it, but it is missing from S3's list
     of departures (S3.md §12). Its reason, that the check at org:428 names only input
     points, does not address the line shape.
4. **Its state table for OE-2 changes located I/O while running.**
   - S3.md §6, line 535, says an input point "added: 0, reported so the host sends it …;
     removed: reported so the host stops sending it".
   - Line 534 lets a global that is not an input point be added (output points included).
   - Against org:858-863: "**Refused while running.** … located I/O and devices".
     org:869 allows only adding and removing "globals" in general.
   - This is not built, but it is the rule S3 hands to OE-2, and it is not listed as a
     departure. S1 (line 340) and S2 (§6) refuse it.
5. **The line path is untested.**
   - `check/1` is public and returns `{line, message}`. But `new!/1` refuses a line, and no
     test calls `check/1` with lines set.
   - My probe shows the path works (`lines-S3.out`). Cross-references carry no line.

---

## 5. Against the brief's list ("What Milestone 2 must keep", org:873-887)

| Constraint | S1 | S2 | S3 |
|---|---|---|---|
| plain data only | yes | yes | yes |
| state keyed by name; instances flat; execution order a list | yes | yes | yes |
| one rule per new piece of state, shared by `start/1` and an edit, with the edit's exceptions | §6 table; but its restart column contradicts its restart (§2 item 3) | §6 table, consistent | §6 table; but it lets located I/O change while running (§4 item 4) |
| one checked constructor, which M2-2's parser feeds | private checks; line path untested | public `check/1`, tested with line and file | public `check/1`; line path untested; not total |
| `start/1` builds each instance through `instance/1` (F14) | yes | yes | yes |
| `%Logex.Runtime{}` opaque | `@opaque` | `@opaque` | `@opaque` |
| one copy of each global | yes: the input image is the input points' entries | yes | yes |
| events an open set | documented | documented | documented |
| nothing but `ArgumentError` escapes (`CLAUDE.md:135`) | **no** (§2 item 1) | yes | **no** (§4 items 1–2) |
| the data API refuses what the text cannot say (org:779-780) | yes | yes, except a line from Elixir (§3 item 2) | **no**: an initial value on an output point (§4 item 3) |
| decided overlap count (org:596) | **not kept** (a departure it states) | kept | kept |
| `scan/2` and a one-instance configuration agree across a restart (org:686-688) | **no** | **no**, unless the host resends | yes |

All three land the §4.4 checks in M2-1 rather than M2-2 (org:1377), and each says so as a
departure. I agree with them: copy-in needs globals and connections. Without the checks,
M2-2 would later tighten what M2-1 accepted, which decision 7's reasoning forbids.

---

## 6. The winner, and what to graft onto it

**Winner: S2.** Its scheduler is as correct as the others'. Its constructor and validator
are the only ones that keep `CLAUDE.md:135` under every probe. Its checks already serve
M2-2 with lines, a file and cross-referenced lines. It keeps the decided overlap count.
Its state table respects org §4.9's refusals.

Grafts, each with its reason:
1. **S3's `restart/2`** (S3.md SC-21 to SC-25):
   - What it does: the resource as `start/1` left it, but it keeps the clock and the input
     image; every task falls due at the next cycle; every overlap count goes to 0; each
     instance restarts through `restart/3`; every other global goes back to its initial
     value.
   - Why: it restores org:686-688's agreement without a host duty (§1.4), and it gives
     decision 14's "explicit restart" (org:1493-1495) its function.
   - Keep S3's test, "again after a restart of each", in the Done-when.
2. **S1's seeded README walk** (300 steps of inputs, plus a timed walk with random elapsed
   times). S2's README Done-when has only 7 steps, so S1's walk is a much stronger guard
   against the two runtimes drifting apart. Add restarts to it once graft 1 lands.
3. **S3's refusal of a line from Elixir**, with its message form `a <kind> from Elixir has
   no line, got: …`, matching `Declarations.validate!/1`. This fixes §3 item 2.
4. **S3's 16x growth step on the instances axis.** A 4x step missed an appended list in
   S3's mutants (S3.md §10, GR-3). Apply it to S2's `cycle/3` growth test.
5. **S3's shuffled task names in the walk, and its worked test of declaration order
   against name order.** Then neither order can pass for the other.
6. **S3's host-loop paragraph** in `Logex.Runtime`'s moduledoc: sleep on `next_due_in/1`,
   first cycle at once, inputs a delta, outputs a snapshot. It is the clearest statement of
   the contract a runner will build on.
7. **S3's Q-20.** Reword PLAN M2-1's Done-when, and M2-3's, to say that the clock cycles
   every 10 ms from 0 to 990 ms.

Do not graft:
- S3's initial value on an output point (§4 item 3).
- S3's OE-2 rules for adding or removing an input point (§4 item 4).
- S1's dropping of the overlap count (§2 item 2).

---

## 7. Defects the synthesis must fix, with repro

| # | Defect (in S2, the base, unless marked) | Repro | Fix |
|---|---|---|---|
| D1 | No restart that keeps the input image: a one-instance configuration disagrees with `scan/2` + `restart/3` | `restart_min.exs`: S2 gives `scan/2 %{"motor" => 1, …}  configuration %{"motor" => 0, …}`; `readme.exs`: 708 of 3,000 output mismatches | graft S3's `restart/2`, with its message `restart takes :cold or :warm, got: …`, a test that fails when the image is not kept (S3's SC-23), and the restart column of S2.md §6 rewritten to match |
| D2 | `new!/1` accepts `line:` from Elixir | `newjunk.exs`: `S2 task line given: accepted` | refuse it, as `Declarations.validate!/1` does; pin the message; revert to check it is red |
| D3 | A task's instances in declaration order is pinned only by the walk | `mutate.py S2`, mutant `inst-order-in-task`: only `api_contract_test.exs` fails | a worked test with two or more instances on one task, declared out of name order |
| D4 (guard, from S1 and S3) | An improper list given to `new!/1` or `start/1` must raise `ArgumentError` | `newjunk.exs` on S1 and S3: `FunctionClauseError` | S2 already passes; keep a test of an improper list in each part, and of the keyword list itself, so a later refactor cannot regress |
| D5 (guard, from S3) | A junk `line` on a hand-edited element must not crash the formatting | `s3_escape.exs` / `handbuilt.exs` on S3: `Protocol.UndefinedError` | S2's CF-4 already refuses it; keep its test |

---

## 8. Open questions my lens adds or sharpens

- **The restart (S2-Q7, S1's Q-I, S3's Q-3).** In my reading this is not a free choice.
  org:686-688 already says why `restart/3` keeps the var_inputs: so that `scan/2` and the
  one-line configuration agree across a restart. A design with no configuration restart
  needs either S3's `restart/2` or an explicit decision that moves this agreement onto the
  host. I recommend S3's `restart/2`.
- **Where an overlap event goes** (S3's Q-19). It can sit before its task's scans (S1 and
  S2) or with all the overlaps first (S3). All three are consistent with org:679. Decide
  it before commit 3, because the walks and the Done-when tests pin it.
- **The overlap count.** S2 and S3 add `overlaps/1`. S1 drops the count. Taking S1's B1 is
  a departure from org:596 and decision 11; taking `overlaps/1` is an extension. Recommend
  `overlaps/1`.
- **`start/1` re-checking** (S1's Q-L, S2-Q14, S3's Q-17). Decision 28's choice of the full
  entry check is the closest precedent. Recommend re-checking, as S2 builds it.

---

## 9. Unverified

- That `get/2` reads M2-5's `m1.s2.run` unchanged. All three walk `FbType.member/2` at any
  depth, but no nested user block type exists at `47319f7`, so nothing nested could be
  run. Unverified.
- The wall-clock cost of `call/4`'s per-scan re-check inside a cycle. All three designs
  inherit it; I did not measure it.
- The growth tests. I did not rerun them beyond the suite passing under three seeds. Each
  design's reduction ratios are its own receipts.
- Whether any design's scheduler is wrong in a way my oracle shares. The oracle states the
  order (priority, due time, place) again, so a misreading of that order common to the
  designs and to me would pass. The worked tests and the Done-when chains guard it. For
  each design, I found one chain whose outputs fix the order (§1.3, probe 8).
