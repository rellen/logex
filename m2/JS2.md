# JS2 · Judging track S (PLAN M2-1): readiness and contract

Label JS2. Written 2026-10-02 against `/home/user/logex` at `47319f7`, which this pass did
not modify (`git -C /home/user/logex status` is clean at `47319f7`). Lens: which design
lets M2-2 to M2-6 and OE-2 land with the least rework, which has the clearest host
contract, and which has the strongest tests.

Each design's patch was applied to a fresh copy of `47319f7`
(`scratchpad/m2/JS2-S1-work`, `JS2-S2-work`, `JS2-S3-work`; `git apply --check` clean for
all three). Every `mix` run used the scratchpad toolchain (Elixir 1.20.4 / OTP 28) and is
judged by its exit code. The work copies were deleted when this report was done; the
probes, drivers and every result are kept in `scratchpad/m2/JS2-probe/`.

Citations: `org` is `docs/organisation.md` and `PLAN` is `PLAN.md` at `47319f7`. A spike's
file is cited as `S2 lib/logex/runtime.ex:793`, the line in the patched copy. Labels here
(M1 to M15, P1 to P6) are this report's own and must never be cited in `lib/`, `test/` or
`CLAUDE.md`.

---

## 0. The verdict

| Design | Score | In one line |
|---|---|---|
| **S2** | **8** | The most ready for M2-2 to M2-6 and OE-2, and the tightest host contract: 0 escapes in 6,000 junk calls; 11 of my 15 reverted rules red |
| S3 | 7 | The clearest host contract in prose, with `restart/2` and the best growth test; but improper lists escape, an output point takes an initial value the text cannot say, and the line path M2-2 relies on has no test |
| S1 | 5 | The smallest surface and the strongest README-clause test; but `new!/1` lets a `FunctionClauseError` out, execution order is not pinned against name order, the line path is unreachable, and the overlap count is dropped |

**Winner: S2.** Graft from S3: the 16x growth step, the host-loop text, the >32-key order
test, and `restart/2`'s rules as written (built only if the maintainer takes it). Graft
from S1: the README clause as a 300-step seeded walk. Add to all: a plain-data test, which
no spike has. Fix in S2: the namespace's line order (no test), the plain-data gap, the
growth step, and `example_member/1`'s crash that M2-5 will hit. Details in §8 and §9.

---

## 1. What I ran

1. **The gate**, on each copy (`JS2-probe/gate.sh`, logs `gate-S1.log`, `gate-S2.log`,
   `gate-S3.log`): `mix format --check-formatted`, `mix compile --force
   --warnings-as-errors`, `MIX_ENV=test mix compile --force --warnings-as-errors`, `mix
   test --warnings-as-errors`.
2. **Mutation** (`JS2-probe/mutate.py`): each mutant reverts one rule alone by exact text
   replacement, then `mix compile --warnings-as-errors` and the whole suite with `mix test
   --warnings-as-errors`, each judged by exit code; the file is restored after each. Every
   mutant reported below compiled with exit 0 (one first form of S1's M8 drew an unused
   variable warning, was rewritten with `_line`, and only the clean form is counted).
   Results: `JS2-probe/mutants-*.json`.
3. **A contract probe** (`JS2-probe/contract_probe.exs`, run as `mix run … S1|S2|S3`,
   output `probe-S*.log`): one neutral description adapted to each spike's input shape;
   4,000 seeded junk configurations through `new!/1`, `start/1`, `cycle/3` and
   `next_due_in/1`; 2,000 hand-built `%Logex.Configuration{}` structs (a valid one with
   fields replaced by junk) through `start/1` and `cycle/3`; junk paths to `get/2`; junk
   inputs to `cycle/3`; and readiness questions asked the same way of all three.
4. **Minimal reproductions** of every escape (`JS2-probe/repro.exs`, `repro.log`) and of
   what M2-2's reader would get back for a configuration with lines (`lines-S2.exs`,
   `lines-S3.exs`, logs beside them).

---

## 2. Gates, reproduced

| | format | compile | test compile | `mix test` | Result line |
|---|---|---|---|---|---|
| S1 | 0 | 0 | 0 | 0 | `Result: 484 passed (6 doctests, 478 tests)` |
| S2 | 0 | 0 | 0 | 0 | `Result: 486 passed (7 doctests, 479 tests)` |
| S3 | 0 | 0 | 0 | 0 | `Result: 491 passed (6 doctests, 485 tests)` |

Each matches the design's own claim. Each Done-when test passes as written (S1
`end_to_end_test.exs` "the scheduler, from Elixir data (M2-1)"; S2 "a configuration, run
by the scheduler (M2-1)"; S3 "a configuration from Elixir data (M2-1)").

---

## 3. Rules reverted, one at a time

Twelve rules were reverted in all three spikes with the same edit shape, so the columns
compare directly; three more are design-specific. "red" is `mix test` exit 2, "GREEN"
exit 0.

| # | Rule reverted alone | Decided where | S1 | S2 | S3 |
|---|---|---|---|---|---|
| M1 | a constant tie-off copies its value in (mutant: copies 0) | org:416 | red | red | red |
| M2 | a var_output drives every global it is connected to (mutant: the first only) | org:417 | red | red | red |
| M3 | names differing only in case clash across tasks, globals and instances (mutant: no case fold) | all three designs' one-namespace rule | red | red | red |
| M4 | `get/2` refuses a path past a bool or dint (mutant: returns 0) | org:678; each design's `get/2` | red | red | red |
| M5 | a var_input may read an output point back (mutant: refused) | org:402-404 | red | red | red |
| M6 | a task with no instance keeps its schedule (mutant: dropped from the plan) | S2 CY-10; S3's scheduler test "a task with no instance keeps its phase"; OE-2 may remove a task's last instance (org:869) | red (contract walk only) | red | red |
| M7 | design-specific: S1 decision-7 problems in declaration order; S2 a cross-reference ` (line N)`; S3 the "is a task" input message | each design | red | red | red |
| M8 | a check's problem carries its element's line (mutant: the interval problem's line set to nil) | each design's M2-2 hook | **GREEN** | red | **GREEN** |
| M9 | instances run in declaration order, within a task and task-less (mutant: name order) | org:574-576; org:876-877 "execution order is a list in the configuration" | **GREEN** | red | red |
| M10 | tasks tied on priority and due time run in declaration order (mutant: name order) | org:570-571; decision 11 (org:1482-1483) | **GREEN** | red | red |
| M11 | design-specific: `get/2` refuses a path that is not one name token (S2) or not names joined by `.` (S3) | each design | — | red | red |
| M12 | S2 only: the first to take a name keeps it **in line order** (mutant: part order) | S2 CF-2 (S2.md:164-166) | — | **GREEN** | — |
| M13 | `%Logex.Runtime{}` holds plain data only (mutant: a function capture in the derived plan) | org:874; PLAN:1305 | **GREEN** | **GREEN** | **GREEN** |
| M14 | events built once, not appended per scan (mutant: `events ++ [event]` per scan) | each design's growth rule | **GREEN** | **GREEN** | **GREEN** |
| M15 | the same, in S3's own GR-3 form (`Enum.reverse(Enum.reverse(events) ++ [event])` per scan) | S3 GR-3 (S3.md:368-369) | **GREEN** | **GREEN** | red |

Totals: **S1 7 red of 13**, **S2 11 red of 15**, **S3 11 red of 14**. On the twelve
common rows (M1-M6, M8-M10, M13-M15): S1 6 red, S2 9 red, S3 9 red.

What the green ones mean:

- **S1 M9 and M10.** S1's tests declare every pair of tasks and every pair of
  instances in name order (`S1 test/logex/runtime_test.exs`, "due tasks run by priority,
  then the earlier due time, then declaration order; a task's instances in declaration
  order": tasks `a`, `b`, instances `i1`, `i3`). S1's own mutant for this rule reversed
  the order (S1.md:505, red), which is not the mistake a map-keyed plan makes; name order
  is. This is the defect S3 found in its own first form and fixed (S3.md:840-844), and S2
  avoided by declaring the earlier-due task last (S2.md:1005-1006). §4.9 lists
  "execution order is a list in the configuration" among what Milestone 2 must keep for
  OE-2 (org:876-877), so an unpinned order is a readiness gap, not a nicety.
- **S1 M8.** Unreachable by construction: `new!/1` overwrites every part's line with nil
  (`S1 lib/logex/configuration.ex:250`) and the checks are private
  (`S1 lib/logex/configuration.ex:288`), so no public call can see a line. S1's claim that
  "its checks return `{line, message}` pairs, so M2-2 turns them into located diagnostics"
  (S1.md:31-32) is code no test reaches.
- **S3 M8.** `check/1` is public and takes elements with lines, but no test passes one a
  line (`S3 test/logex/configuration_test.exs` builds every element with `line: nil`, and
  the one test with a line checks that `new!/1` refuses it). The hook S3 offers M2-2
  (S3.md:35-39) is untested.
- **S2 M12.** S2 sorts the namespace by line before taking names
  (`S2 lib/logex/configuration.ex:474-481`) so that, in a file, the later declaration is
  the one refused. It works (P6 below shows it), but reverting it leaves the suite green,
  because no test has a clash whose lines run against the part order.
- **M13, all three.** No test checks that the runtime holds no function, pid, reference
  or port. A capture added to the derived plan passes every suite.
- **M14, all three.** A plain `++` per scan is invisible to a growth test counted in
  reductions, as CONTRIBUTING.md:302-306 records for `++`. Not a spike's defect; a limit
  to record.
- **M15.** S3's 16x instances step (100 against 1,600, bound 19.5) catches the per-scan
  rebuild S3 itself found (S3.md:845-849); S1's and S2's 4x steps (bounds 5 and 6) do not.

---

## 4. The host contract, probed

### 4.1 Anything but `ArgumentError` escaping (reproduced)

| Probe | S1 | S2 | S3 |
|---|---|---|---|
| P1: 4,000 seeded junk configurations through `new!/1`, `start/1`, `cycle/3`, `next_due_in/1` | **113 escapes**: 67 `FunctionClauseError` in `String.downcase/2`, 46 in `Enum.map_reduce` | **0** | **48 escapes**, all `FunctionClauseError` on an improper list |
| P2: 2,000 hand-built structs through `start/1` and `cycle/3` | 1,798 escapes (`BadMapError`, `Protocol.UndefinedError`, `KeyError`) | **0** | 78 escapes, all on an improper list |
| P3: junk paths to `get/2` (29 paths: `""`, `"."`, `"m1."`, `"m1..fault"`, `"m1.t1.last"`, `"m1.fault.x"`, `<<255>>`, `5`, `nil`, …) | 0 | 0 | 0 |
| P4: junk inputs to `cycle/3` (17 maps and non-maps) | 0 | 0 | 0 |

The escapes reduce to these minimal cases (`repro.exs`, `repro.log`):

- **S1, inside its own contract.** A non-string name meeting a did-you-mean:
  `new!/1` with an instance named `:r1` while a connection names `r1.a` gives
  `FunctionClauseError` from `String.downcase(:r1, :default)`; a global named `[]` while a
  connection names `x`, from `String.downcase([], :default)`. The unknown name is offered
  to `Declarations.suggest/4` with every name of the part, junk included
  (`S1 lib/logex/configuration.ex:476-477`). A lone `:r2` is refused properly; the crash
  needs the did-you-mean. S2 and S3 refuse both with an `ArgumentError`. This breaks
  CLAUDE.md:135 ("Nothing else may escape the public API") at the one checked
  constructor.
- **S1 and S3: an improper list.** `tasks: [t | :tail]` or `connections: [c | :tail]` to
  `new!/1`, and (S3) `programs: [p | :tail]`, give `FunctionClauseError` from `Enum`
  (`S1 lib/logex/configuration.ex:233-234`; `S3 lib/logex/configuration.ex:174`, `:189`,
  `:247`). S3's `start/1`, which checks again, crashes the same way on a hand-built
  struct whose `instances` is improper. S2 walks every host list with `proper/4`
  (`S2 lib/logex/configuration.ex:250-252`) and refuses each with a pinned message. The
  codebase already decided that a host's list is checked as a proper list (fix F8,
  org:1608-1609), so S2 follows precedent and S1 and S3 do not. S3 claims its
  constructor walk shows "nothing else escapes" (S3.md:696-704); the walk never draws an
  improper list.
- **S1: a hand-built configuration.** S1 puts it outside the contract (S1.md:103-106,
  §11 Q-L). Reproduced consequences: an instance of an unknown program gives `KeyError`
  at `start/1`; a connection to an unknown global gives `KeyError` in `cycle/3`; an
  instance whose task is renamed to an unknown one starts, and **never runs**, silently
  (the cycle's events are `[]`). S2 and S3 refuse all three with the constructor's
  messages, because `start/1` runs `check/1` again. `%Logex.Configuration{}` is a public
  struct and the data API by design (org:775-780), so S2's argument (S2.md:880-884) that
  `start/1` must check it holds.

### 4.2 Readiness questions asked of all three (`probe-S*.log`)

| Question | S1 | S2 | S3 |
|---|---|---|---|
| First cycle at elapsed 10 (inventory C14) | `{:overlap, "fast", 1}` | same | same |
| Events of a late cycle | overlap just before its task's scans | same | all overlaps first |
| `next_due_in/1` after `start/1` | 0 | 0 | 0 |
| An output point with `initial: 1` | refused | refused | **accepted; `get` gives 1** |
| `at: "panel.i.00"` | refused (leading zero) | **accepted, the same address as `panel.i.0`** | refused |
| No `name:` | refused | **accepted (nil)** | refused |
| A global named `program` (an `.lcf` word, org:745) | accepted | accepted | accepted (all defer reservation, by design) |
| 40 task-less instances declared in reverse name order run in declaration order | yes | yes | yes |
| P5, M2-5: `get(rt, "r01.s1")` for a block type whose only member is an input | `ArgumentError`, pinned form | **`FunctionClauseError` in `example_member/1`** (`S2 lib/logex/runtime.ex:793-794`) | `ArgumentError`, pinned form |
| P5, M2-5: the same for a block type with no public member | `ArgumentError` from `hd([])`, unpinned text | **`FunctionClauseError`** | `ArgumentError` from `hd([])`, unpinned text |

P5 builds the program by hand, which today's contract excludes: no text can declare a
user block before M2-5. It shows what M2-5 will meet in each `get/2`.

### 4.3 What M2-2's reader gets back (P6, `lines-S2.log`, `lines-S3.log`)

The same configuration, read from a file: an interval of 0 on line 2, an instance under
an unknown task on line 6, and a global on line 9 named like the instance on line 6.

```
S2: %Logex.Diagnostic{stage: :configure, line: 2, message: "task `fast`: an interval is 1 to 2147483647 ms, found 0", file: "plant.lcf", …}
S2: %Logex.Diagnostic{stage: :configure, line: 6, message: "program instance `r1`: there is no task `fsat` — did you mean `fast`?", file: "plant.lcf", …}
S2: %Logex.Diagnostic{stage: :configure, line: 9, message: "`r1` is already the name of a program instance (line 6): tasks, globals and program instances share one namespace", file: "plant.lcf", …}

S3: {2, "task `fast`: its interval is 1 to 2147483647 ms, got: 0"}
S3: {6, "`r1` runs under `fsat`, but no task is named `fsat` — did you mean `fast`?"}
S3: {6, "`r1` names a global and an instance: globals, instances and tasks share one namespace"}
```

S2 already gives M2-2's Done-when ("a located diagnostic naming its file and line",
PLAN:1319-1320): the stage, the file, line order, the clash cited at the later line with
a cross-reference to the earlier. S3 cites the clash at the **earlier** line, because its
namespace takes globals, then instances, then tasks (`S3 lib/logex/configuration.ex:556-
563`); sorting its output by line cannot move it, so M2-2 must change the check. S1 has no
public way in for a configuration with lines.

---

## 5. Readiness for the later items

| Item | S1 | S2 | S3 |
|---|---|---|---|
| **M2-2** text, located diagnostics, the §4.4 checks, reserved words | Checks private; `new!/1` erases lines; no `file`; no stage chosen; messages carry no line cross-references. The reader must live inside `Logex.Configuration` or the checks go public, and lines must be plumbed through untested code (M8 green) | `check/1` public, returns `:configure` diagnostics with line and file in line order, with ` (line N)` cross-references, all pinned (M7, M8 red); `file` field; `location/1` parses `{device, io, address}`. The reader builds the four element structs and calls `check/1`. One gap: line order of the namespace unpinned (M12) | `check/1` public, `{line, message}` in part order; `location/1` gives only `:input`/`:output`; no `file`. The reader converts, sorts, and must rework the namespace's order (§4.3); line plumbing untested (M8) |
| M2-3 tasks in text | nothing to change | nothing | nothing |
| **M2-4** `var_external`, one copy, two-writer warning | sketched; `warnings` to add | sketched; `warnings: []` already on the struct (`S2 lib/logex/configuration.ex:42-49`) | sketched; `warnings` to add |
| **M2-5** blocks inside programs, `m1.s2.run` | `get/2` walks members at any depth | same; but `example_member/1` crashes on a block with no output (P5) | same |
| **M2-6** event tasks | `rt.tasks` holds a bare integer per task (`S1 lib/logex/runtime.ex` `@opaque t`): the trigger's last value reshapes it (private, so cheap) | task state is a map: add `last`; `Task`'s `@enforce_keys` drops `:interval` (S2.md:514-516) | task state is a map: add `last_single` |
| **OE-2** | no stored overlap count (a decided count dropped, §6); no restart; no re-check of a candidate struct | count and `overlaps/1`; re-check in `start/1`; no restart (its rules tabled, S2.md:410-422) | count and `overlaps/1`; re-check; `restart/2` built, keeping the clock and the input image (S3.md:298-304), the nearest thing to §4.9's "a restart, which may keep values by name" (org:858) |

An independent track agrees with S2 on the points M2-2 needs. T1, which designed the
configuration file without seeing track S, asks of S's constructor: problems back as
diagnostics at stage `:configure`, with a line, in line order; one `ArgumentError` with
every problem from Elixir; a `warnings` channel; a global's location read back as device,
direction and address; and a connection with its instance and member apart (T1.md:223-
252, T1.md:146-173). S2 provides each of these; S3 provides the first two in another
shape; S1 the second only. T1 also keeps org:470's argument order for `compile/3`, against
S2's proposal S2-Q15 (T1.md:1175-1176): a merge must pick one, and it is M2-2's question.

---

## 6. Decided rules, and where a design departs without saying so

- **The overlap count.** org:596 ("adds `missed` … to its overlap count"), decision 11
  (org:1482-1484, "counted") and PLAN:1361-1362. S1 stores none and says so as a
  departure (S1.md:718-721). S2 and S3 keep it and read it through `overlaps/1`, one
  function beyond org §4.6's list, which both declare. From this lens S1's departure
  costs OE-2 and the runner a piece of state they will want, and the reason given (no
  reader) is answered by adding the reader.
- **S3: an output point with an initial value.** org:414's line shape has no initial
  value with `at`, and the data API "refuses anything the text cannot say" (org:779-780).
  S3 accepts one (P4 table: `get` gives 1). S3 lists it as open question Q-10 with the
  recommendation "allowed" (S3.md:947-953), but not among its departures (S3.md:1011-
  1027). It is one: either M2-2's line shape changes, or the data path refuses it, as S1
  and S2 do.
- **S1: execution order not pinned** against name order (M9, M10), against org:570-576,
  org:876-877 and the rule that every rule has a test that fails when it is reverted
  (CLAUDE.md:178-180; PLAN:1295).
- **S1, S3: non-`ArgumentError` escapes** (§4.1), against CLAUDE.md:135, with fix F8 as
  the precedent for a host's improper list (org:1608-1609).
- **All three: plain data not pinned** (M13), against org:874.
- Agreed by all three and argued: the §4.4 checks land with M2-1, not M2-2 (org:1377). I
  agree with the argument: copy-in needs globals and connections (org:1365-1367), and a
  data path that accepted what M2-2's text then refuses would break hand-built plants.

---

## 7. Scores

| | Readiness (M2-2…OE-2) | Host contract | Tests | Decided-rule fidelity | Score |
|---|---|---|---|---|---|
| **S2** | best: diagnostics, file, line order, cross-references, `warnings`, parsed locations, matches T1's contract | best enforced: 0 escapes in 6,000 junk calls; `start/1` re-checks; text adequate | 11 of 15 red; M12 green (its own rule), M13-M15 green | keeps the count; refuses the output initial; departures listed | **8** |
| S3 | good: public `check/1`, restart rules built; but part order, no file, untested lines | clearest prose (the host loop and nine promises, S3.md:139-188); `restart/2`; improper lists escape | 11 of 14 red; the only one to catch M15; M8 green | keeps the count; output initial accepted, not listed as a departure | **7** |
| S1 | weakest: private checks, lines erased, no file, no warnings, no count | smallest surface; a `FunctionClauseError` from `new!/1`; hand-built configs crash or silently skip an instance | 7 of 13 red; M8-M10 green; strongest README clause (300-step seeded walk plus a 300-step timed walk) | drops the decided count (declared) | **5** |

Strengths reproduced for each, beyond the table: all three pass their Done-when as
written; all three refuse every junk `get/2` path and every junk input with an
`ArgumentError`; all three run 40 instances in declaration order past the 32-key map limit
(CONTRIBUTING.md:328-332); all three build each instance with `Runtime.instance/1`
(fix F14, each pinned by the design's own mutant).

---

## 8. The winner, and what to graft onto it

**S2**, because the item after M2-1 is the configuration file, and S2 alone already
returns what that file's reader must show (§4.3), pins it (M7, M8 red), and refuses every
junk value a host can pass (§4.1). Its remaining gaps are tests to add, not shapes to
change.

Graft, each with its reason:

1. **From S3, the 16x instances growth step** (100 against 1,600 instances, bound 19.5,
   S3.md:706-717). Why: M15, a per-scan rebuild of the event list, is red in S3 and green
   in S2, whose 4x step and bound 6 cannot see it. (A plain `++` per scan, M14, stays
   invisible to any reductions test; record that limit beside CONTRIBUTING.md:302-306.)
2. **From S3, the host's loop and its numbered promises** in `Logex.Runtime`'s moduledoc
   (S3.md:139-193): first cycle at elapsed 0, inputs a delta, outputs a snapshot, events an
   open set, a recorded run replays exactly. Why: S2 enforces the contract best but states
   it least; the prose is S3's strongest part.
3. **From S3, the order test past 32 keys** (40 instances in reverse name order,
   S3.md:652-653). Why: S2's M9 is red only through a handful of instances; an order taken
   from a map larger than 32 keys is what CONTRIBUTING.md:328-332 warns of.
4. **From S3, `restart/2`'s rule, recorded now** (S3.md:298-304 and its §6 column: the
   clock and the input image kept, every other global to its initial value, each instance
   through `restart/3`, every task due at the next cycle, every count 0), and built only if
   the maintainer takes S3's Q-3(a). Why: decision 14 requires "an explicit restart"
   (org:1494) and §4.9 makes a restart the way to apply what an edit refuses (org:858); S2
   leaves its restart column at "start/1 again", which loses the input image.
5. **From S1, the README clause as a seeded walk** (S1's `end_to_end_test.exs`: the
   README steps plus 300 seeded input steps, and a 300-step timed walk through `scan/3`).
   Why: S2's test of that clause is 7 steps and 62 timed steps; org §4.6 asks for the test because
   otherwise "the two runtimes drift apart" (org:682-683), and a walk is the stronger guard.
6. **From S1, S3 and T1, a required configuration name.** Why: S2 accepts `name: nil`
   (P4 table); S1, S3 and T1's `compile/3` require one, and relaxing later breaks nothing.
7. **New, for the merge: a plain-data test** that walks the `%Logex.Runtime{}` from
   `start/1` and after cycles and finds no function, pid, reference or port. Why: M13 is
   green in all three, and plain data is §4.9's first must-keep (org:874).

Do not graft: S3's acceptance of an output point's initial value (§6), S3's part-ordered
namespace (§4.3), or S1's unchecked `start/1` (§4.1).

---

## 9. Defects the synthesis must fix (S2, as the base), each reproduced

1. **The namespace's line order has no test.** `python3 JS2-probe/mutate.py S2
   M12-namespace-line-order`: compile 0, `mix test` exit 0, `Result: 486 passed`. Add a
   `check/1` test with an instance on line 6 and a global of the same name on line 9,
   asserting the one diagnostic is at line 9 and cites `(line 6)`, as `lines-S2.log`
   shows the code does today.
2. **Plain data has no test.** `mutate.py S2 M13-fun-in-runtime` (a capture,
   `&System.monotonic_time/0`, in the derived wiring): exit 0, `Result: 486 passed`. Add
   graft 7.
3. **The growth test cannot see a per-scan rebuild of the events.** `mutate.py S2
   M15-S3-own-GR-3`: exit 0; the same mutant in S3 fails "growth a cycle stays linear in
   the instances it runs". Add graft 1.
4. **`get/2` of a whole block instance crashes when its type has no output member.**
   `mix run JS2-probe/contract_probe.exs S2`, P5: `{:escape, FunctionClauseError, "no
   function clause matching in Logex.Runtime.example_member/1"}`; the clauses are
   `S2 lib/logex/runtime.ex:793-794`, which assume an output member exists. Outside
   today's contract (no text declares such a block), so it is M2-5's to pin; fix it when
   the merge lands by falling back to the first public member, then to a message with no
   example, which S1 and S3 already do for the first case.
5. **An unnamed configuration is accepted** (`probe-S2.log`, "no name: {:ok, 0}").
   Refuse it, graft 6, unless the maintainer wants unnamed configurations.

If any of S3's code is grafted (for example `restart/2`), bring S2's `proper/4` with it:
S3's own code lets improper lists through (§4.1).

---

## 10. Where this lens bears on the maintainer's open questions

| Question (design labels) | This lens recommends | Why, reproduced |
|---|---|---|
| Overlap count (S1 Q-B, S2-Q4, S3 Q-2) | keep it, read through `overlaps/1` | decided (org:596); OE-2 and the runner need it; both S2 and S3 pin it |
| `start/1` checks again (S1 Q-L, S2-Q14, S3 Q-17) | yes | S1's hand-built configurations crash with `KeyError` or silently skip an instance (§4.1) |
| Shape of `check/1`'s problems (S2-Q2, S3 Q-14) | `%Logex.Diagnostic{stage: :configure}` with line and file, in line order | P6; T1's contract C3 asks for it |
| An output point's initial value (S1 Q-G, S2-Q9, S3 Q-10) | refuse | org:414 with org:779-780; S3 accepts it today |
| A restart of the resource (S1 Q-I, S2-Q7, S3 Q-3) | record S3's rule now; build it when the runner or OE-2 needs it, or now if the maintainer prefers S3's Q-3(a) | org:858, org:1494; S3's rule is ready and pinned in S3 |
| Event order within a cycle (S3 Q-19) | either; S1 and S2 put an overlap before its own task's scans, S3 all overlaps first | the events are an open set (org:887); pick one before M2-1 lands and pin it |
| The first cycle (S1 Q-A, S2-Q5, S3 Q-5) | keep §4.6 as written | all three report `{:overlap, "fast", 1}` at elapsed 10, which is a true miss |
| `next_due_in/1` with task-less instances (S1 Q-C, S2-Q6, S3 Q-4) | ignore them | all three agree; org:661 |

---

## 11. Unverified

- Wall-clock time per cycle was not measured; every growth figure here is the designs'
  own, and only M15's red or green was reproduced.
- I did not rerun the designs' own mutation tables; §3's 42 mutants are my own.
- P5 builds a program by hand, outside today's contract, to show what M2-5 will meet; the
  shape M2-5 gives a user block type is not decided.
- Whether a dialyzer run would flag a host matching on the `@opaque` runtime was not
  checked.
