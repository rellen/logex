# rf-S-fit — refutation of S-synth (M2-1) on fit

Label: rf-S-fit. Lens: fit with the decided rules (org §4.4–§4.9, §7 decisions 1–29 and
fixes F1–F16, PLAN M2-1 with its OE-2 constraints, CLAUDE.md, §4.9 "What Milestone 2 must
keep"); whether S-synth §13's questions are real, correctly framed and complete; whether
its departures are argued; whether its landing order is right and each commit green.

Written 2026-10-02 against `/home/user/logex` at `47319f7`, which was not modified. Work
was in `scratchpad/m2/rf-S-fit-work` (a `cp -a` of `S-synth-work`) and
`scratchpad/m2/rf-S-fit-c2` (a `cp -a` of `/home/user/logex` with three spike files),
both deleted when done. Receipts kept: `scratchpad/m2/rf-S-fit-c2.log`,
`scratchpad/m2/rf-S-fit-probe/q23.exs` and `q23.out`, `scratchpad/m2/rf-S-fit-mut.txt`
(S-synth's mutation log flattened to one row per mutant). Every `mix` run on Elixir
1.20.4 / OTP 28, judged by exit code.

`org` is `docs/organisation.md`; `spike:` is `S-synth-work`. Labels (`S-FIT-n`) are this
report's own and must never be cited in `lib/`, `test/` or `CLAUDE.md`.

## What was confirmed (no finding)

- The spike's gate, rerun once in my copy: `mix test --warnings-as-errors` exit 0,
  `Result: 500 passed (7 doctests, 493 tests)`.
- The cycle's order, the overlap formula, the first-cycle rule, visibility, the output
  snapshot, the input image, `start/1` through `instance/1` (F14), plain data and opacity
  match org §4.6 and §4.9's must-keep list as written. The citations S-synth leans on
  (org:414, 434-435, 470-475, 556-557, 596, 669-680, 686-688, 852-856, 858-866, 873-887,
  1377-1379) say what S-synth says they say.
- No conditional in the new code (`grep -E '\b(if|unless|cond|case)\b'` over
  `configuration.ex` and the added lines of `runtime.ex` finds only prose).
- D-1 (the §4.4 checks with M2-1), D-2 (`overlaps/1`, `restart/2`), D-3 (`new!/1` raises
  every problem) and D-4 (the "New state" rule for an opaque struct) are each argued
  against the text they depart from. The precedent for D-4 holds: the runtime moduledoc
  already puts a hand-built `%Logex.Edit{}` outside the contract.

## Findings

### S-FIT-1 (medium) — §4.9's "one rule for a new piece of state, with the edit's exceptions listed" is not landed for globals or tasks

org:878-880 (must-keep): "each M2 item writes its rule for a new piece of state once, used
by `start/1` and by an edit that adds one, with the edit's exceptions listed". org:1106-1110
says where such a rule lives: `Program.initial_env/1` is the one rule and "Its doc lists
the edit's exceptions". S-synth's rules for a global's value and a task's state exist only
as the table in S-synth §4. In the spike they are private and undocumented:

```elixir
defp initial_value(%Configuration.Global{initial: nil}), do: 0
defp initial_value(%Configuration.Global{initial: initial}), do: initial
defp task_state(due), do: %{next_due: due, overlaps: 0}
```

`grep -n -i "one rule\|exception\|OE-2" lib/logex/configuration.ex lib/logex/runtime.ex`
in the spike finds nothing about either piece. §9's documents table sends nothing of §4's
table to org §4.9 either: commit 1 lists §4.4, §4.6, §6.2 and §8, not §4.9's "One rule
for new state". The spike's CLAUDE.md says such a piece "gets a value from `start/1` and a
rule for each of a cycle, `restart/2` and OE-2's switch", but no file in the repository
would hold those rules. *Fix:* give each piece one documented place, as `initial_env/1`'s
doc is for a tag (a "One rule" section in `Logex.Runtime`'s moduledoc, or public documented
functions), listing the value at `start/1`, at a cycle, at `restart/2`, and OE-2's
exceptions. Commit 1 then copies §4's table into org §4.9's "One rule for new state".

### S-FIT-2 (medium) — editing during M2: a false claim, and a missing question

S-synth §5 (line 491-492): "Editing during M2 is not possible: the runtime is opaque, so
`Logex.Edit` cannot reach an instance inside it; the moduledoc says so." The spike's
moduledoc does not say so. `git diff --cached HEAD -- lib | grep -i "edit\|opaque"` in the
spike finds only the pre-existing "A running instance takes a changed program through
`Logex.Edit`" paragraph, now directly under the new configuration section, which a reader
will take to cover a resource's instances too, and the opacity sentence. The inventory asked
it as a question (Q7.6: "no running configuration can be edited at all until OE-2. Is that
accepted, and documented?"). S-synth §13 does not ask it. It is a real choice. The
maintainer's brief (org §4.9) is to change a running controller without a restart. OE-1
delivers that for a lone instance. M2-1 takes it away from any plant run as a
configuration until OE-2, which comes after M2-6. The options are (a) accept the gap and
document it in the moduledoc and PLAN, or (b) a narrow interim hook, at the cost of
opacity (org:886). *Fix:* add the question with both consequences, and the moduledoc
sentence §5 claims.

### S-FIT-3 (medium) — the landing order is asserted, not built, and three of its steps do not hold as written

S-synth §8 says each commit is green and §8 (line 766) says "Each of 2–5 carries its rows
of the mutation table". The table was measured only on the final spike, and no commit was
built.

1. **Commit 2 is red as described.** Reproduced: a fresh copy of `47319f7` with only
   `lib/logex/configuration.ex`, `lib/logex/diagnostic.ex` and
   `test/logex/configuration_test.exs` from the spike. `mix compile --warnings-as-errors`
   exits 0. `mix test --warnings-as-errors test/logex/configuration_test.exs` exits 3,
   `Result: 28/32 passed (1/1 doctest, 27/31 tests)`, with `(UndefinedFunctionError)
   function Logex.Runtime.start/1 is undefined or private` and the warnings
   `Logex.Runtime.start/1 is undefined or private` and `Logex.Runtime.cycle/3 is undefined
   or private` (`rf-S-fit-c2.log`). Four tests call `Logex.Runtime.start/1` (lines 239,
   589, 641, 685), and two of them also call `cycle/3`. CF-31's worked test is one of the
   four. They have to be split across commits, and S-synth does not say so. The same
   holds for the runtime-test "every call takes a runtime from start/1, checked first"
   (CY-0, RS-0: `restart/2`, `next_due_in/1` and `overlaps/1` land in 4 and 5) and for
   PD-1's test, which restarts (commit 3 against commit 5).
2. **Commit 3, "the resource, task-less", has no defined behaviour for a task.** Commit 2's
   `check/1` accepts tasks (CF-5, CF-6, CF-14), and commit 3 lands `start/1` with RT-3
   ("every task due at 0"). CY-3…CY-7d land in commit 4. In commit 3 a valid configuration
   with an instance on a task therefore either never runs that instance, or runs it on a
   rule commit 4 then reverses. The alternative is a temporary refusal that commit 4
   removes. Each of these breaks S-synth §5's own standard ("Nothing below reshapes a
   struct M2-1 lands or reverses one of its rules") inside M2-1.
3. **Commit 5 "can be dropped whole" (Q-3) is not true of the order given.** Commit 5
   carries "the README walk's restarts", but the README walk lands in commit 7
   (`end_to_end_test.exs`). The contract walk (6) draws `restart/2` with good and bad modes
   (§7.1), and the Done-when tests (7) restart both sides. Choosing Q-3 (b) after 6 and 7
   are built means editing them.

*Fix:* merge commits 3 and 4, or have commit 3 refuse a configuration with a task and say
so. Build the commits in a copy and gate each, as OE-1's landing did. Run each commit's
mutation rows at that commit. Move restart/2's uses so that commit 5 really is removable,
or drop the claim.

### S-FIT-4 (medium) — Q-23 states one side of option (a)'s consequence and leaves out the option the other track recommends

Q-23 (a): "Keep it; the next run steps by the new interval ... No run added or lost at the
switch." It does not say what keeping `next_due` costs when an interval shrinks.
Reproduced by simulating (a) on the spike (`rf-S-fit-probe/q23.exs`): a task at 60000 ms
runs at 0, and at `now` = 20 its interval changes to 10 ms with its task state kept. The
output:

```
before switch (interval 60000): {[{:ran, "t", "m", 0}], [], 59980}
after switch to 10 ms, next_due_in: 59980
runs of a 10 ms task in the 1000 ms after the switch: 0
```

The new rate takes effect only after 59,980 ms, the whole remainder of the old period.
The conventional family's reason for allowing the change while running (decision 19) is
that logic writes it to take effect. T-synth Q-16 offers `min(next_due, now + new
interval)`, "bounds the wait by the new interval and adds no run", and recommends it;
S-synth lists neither that option nor the delay. *Fix:* add the `min` option and state
(a)'s worst-case delay (the old interval). Since the two tracks now recommend differently,
mark it as one question for the merge.

### S-FIT-5 (low) — Q-8 recommends against the rule every sibling question applies

Q-8: "*Recommend (a)*, logex's integers being dints; (b) is the safer start by decision 7's
reasoning, so the choice is the maintainer's." Q-7 ("relaxing later breaks nothing;
tightening later breaks plants"), Q-9 ("tightest now, each part widenable later"), Q-11
("relaxable later"), Q-19 ("relaxing later breaks nothing") and decision 7 itself all take
the tight option for that reason. Q-8 alone recommends the loose bound while saying the
tight one is safer. The dint argument does not decide it. A priority of 2147483647 is no
more expressible in IEC's grammar than one of 31, and a later tightening breaks plants
that use the wide range. *Fix:* either recommend (b), or say why priority is the exception
to the rule the other four questions apply.

### S-FIT-6 (low) — "one checked constructor, which the `.lcf` parser feeds": an unlisted reading, with a cross-track conflict

org:881 and PLAN M2-1 decide "one checked constructor, which M2-2's parser feeds". In
S-synth the parser does not feed the constructor. §1.1 says M2-2's reader "builds the same
structs with lines and a file and calls [`check/1`]". `new!/1` keeps checks that `check/1`
lacks: NW-1…NW-4, CF-3c and CF-3d. `start/1` checks a third time. That may well be the
right shape: one validator, `check/1`, as `Declarations.check/1` is for tags. But it is a
reading of a decided sentence, and §11 does not list it. T-synth, meanwhile, calls its
`check/3` "the one checked constructor's core" with a `new!/3` stand-in (T-synth §1, Q-19,
Q-20; "Two validators until the merge"). *Fix:* list it in §11 as a reading ("the
constructor is the struct plus `check/1`; `new!/1` is its Elixir face"). Add a question
that names T-synth's alternative, decided before commit 2.

### S-FIT-7 (low) — §6.2's "whole diagnostic lists from source" is left unowed

org §6.2 (line 1356-1357): "Every diagnostic is pinned by a test that asserts whole
diagnostic lists from source, like `validation_test.exs`." D-1 moves the §4.4 checks into
M2-1, where no source exists, so `configuration_test.exs` pins them from data. That is
unavoidable, but D-1 does not say it is a departure. §5's M2-2 bullet does not oblige M2-2
to pin each `check/1` diagnostic again from `.lcf` text. *Fix:* add both: the departure in
D-1, and the obligation in §5.

### S-FIT-8 (low) — GT-4b and GT-7 are pinned only on a program the runtime's contract excludes

`runtime_test.exs` (spike, "get/2 names a block's member as its example") builds its block
type by `program = put_in(timed.tags["p"].type, type)`, a compiled `%Logex.Program{}`
edited by hand. Then `Configuration.new!/1` and `Runtime.start/1` accept it. The runtime
moduledoc says "A `%Logex.Program{}`, `%Logex.Instance{}` or `%Logex.Edit{}` built or edited
by hand is outside this contract", and CLAUDE.md's testing convention (fix F12;
`edit_test.exs`: "never from editing a struct") builds programs from source. In
`rf-S-fit-mut.txt`, GT-4b and GT-7 are red in that one test and nowhere else. So two of
the 101 rows pin behaviour that no input within the contract reaches at M2-1. *Fix:* land
GT-4b and GT-7 with M2-5, whose text can declare such a block. F-synth's FS-Q9 (a) would
then decide whether one is reachable. Otherwise record the hand-edited program as a
deliberate exception.

### S-FIT-9 (low) — §4's table proposes two OE-2 rules that §13 does not ask

- "an instance's `type` — a change refused (proposed for OE-2)". org §4.9 allows "adding and
  removing ... instances" while running. One edit that removes `m1` (a `motor`) and adds
  `m1` (a `pump`) is a type change, so refusing it narrows a decided allowance.
- "an unlocated global's value — kept; a changed `initial` is reported, as decision 29
  reports a tag's". This extends decision 29, which the maintainer took against its
  recommendation, from a tag to a global.

Both are choices for the maintainer. *Fix:* move both into §13, each with its consequence.

### S-FIT-10 (low) — questions the inventory raised that S-synth neither answers nor asks

- Inventory Q1.21: "Can a host restart one instance inside a running `rt`?" `restart/2` is
  resource-wide only.
- Inventory Q1.26: `%Logex.Runtime{}` defined in the API module puts `__struct__/0,1` on
  the pinned surface (readiness §1.6 item 2). Is that intended, or should the value be its
  own module?

*Fix:* answer each in the design, or add it to §13.

### S-FIT-11 (low) — commit 0 is a public struct change that §8, §9 and §5 do not account for

§8 commit 0: "The compiler lists a program's var_outputs once and `outputs/2` reads the
list". readiness §1.7 says what that is: "a new `outputs` field of `%Logex.Program{}` ... It
is a public struct change", with a nil clause for hand-built programs. §5 claims "Nothing
below reshapes a struct M2-1 lands". §9 has no row for commit 0, though it stales
`program.ex`, CLAUDE.md's Key Files and the surface test's struct keys. The commit also
adds a derived field that a hand-built program can set against its `tags`. *Fix:* name it
as a `%Logex.Program{}` change, give it its §9 row, and either state the field's rule
against `tags` or keep the list out of the struct.

### S-FIT-12 (low) — three tracks, contradictory recommendations and colliding numbers

- S-synth §8 commit 1, F-synth (§ landing, line 702) and T-synth (line 818, 992) each
  append their answers to org §7 "as decisions 30 onward". The labels test fails on any
  decision a commit cites before it is defined, so the three records must be one commit
  with one numbering.
- Q-22 recommends M2-1 first. F-synth FS-Q16 recommends M2-5 first, to settle "`get/2`'s
  reach" before `start/1` is built on it.
- Q-24 recommends departing from org:470's `compile(name, source, types)`. T-synth Q-19
  recommends keeping it.
- GT-1 and §5 promise `get/2` "at any depth", and §5 says M2-5 owes it a depth growth test.
  F-synth's FbType keeps `member/2` going through `public/1`, which leaves `:local` out, and
  FS-Q9 (a) recommends hiding a block's own instances. Under that answer `get/2` never goes
  deeper than `inst.tag.member`, so the depth promise has nothing to bind.

*Fix:* one merged question per pair, decided before commit 1. Number the decisions once,
across tracks.

## Verdict on the lens

S-synth fits the decided execution model closely, and its four departures are argued. The
gaps are about what the design carries forward:
- the must-keep rule for new state, which has no home in code or org (S-FIT-1);
- the loss of online edit for configured plants, mis-described as documented (S-FIT-2);
- a landing order that was never built and that breaks at commits 2, 3 and 5 as written
  (S-FIT-3).

Q-23 and Q-8 are framed one-sidedly, and four choices sit outside §13 (S-FIT-6, S-FIT-9,
S-FIT-10).
