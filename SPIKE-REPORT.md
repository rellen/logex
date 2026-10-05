# M2-4 spike: one copy of a global at run time

Label: m24-spike. Throwaway; never lands.

| | |
|---|---|
| Tree | `scratchpad/m2-4/spike`, branch `m2-4-spike`, a copy of `/home/user/logex` at `025199a` (M2-1 landed; M2-5 and M2-2 not) |
| Patch | `scratchpad/m2-4/spike.patch` (`git add -A; git diff --cached HEAD`): 8 files, +1080 −10 |
| Toolchain | Elixir 1.20.4 / OTP 28 (`scratchpad/toolchain/env.sh`) |
| Gate | `scratchpad/m2-4/gate.sh`: `mix format --check-formatted`, `mix compile --force --warnings-as-errors`, `MIX_ENV=test mix compile --force --warnings-as-errors`, `mix test --warnings-as-errors`. Run three times, **exit 0 each**, 548 tests (529 before the spike; 19 new in `test/logex/external_test.exs`). Logs `gate-1.log` to `gate-3.log` |
| Mutation | `scratchpad/m2-4/mutate.py`: 21 rules reverted one at a time under the full suite, **21 of 21 red** (`mutation-table.txt`, `mutation-full.json`) |
| Probes | `scratchpad/m2-4/probe/p1`–`p7`, each `.exs` with its `.log` |

"Probe pN" below is `probe/pN_*.log`; "test" is a test of `test/logex/external_test.exs`
in the spike, named by its title.

---

## 1. What the spike built, and no more

The least that runs a `var_external` end to end. Nothing of M2-5 (`cal`, blocks) or M2-2
(the configuration file, its warnings W1 and W2) exists in this tree.

- **`.ld`**: `var_external` is a row of `Logex.Declarations`' `@sections`, so it is a
  section, reserved in any case. A bool or a dint; an initial value is refused (Ed 2 p.43),
  and so is an instance of a function block (the existing "declared with `var`" message).
  Logic reads and writes it; `Logex.Compiler` needed no change. `Logex.Tag`'s type spec
  gains the section. `docs/naming.md` takes the design pass's `var_external` stanza
  unchanged, so `naming_test.exs` stays green.
- **The writes walk, stand-in for B5's**: `Logex.Compiler.writes/1`, a program's written
  tags, each to the line of its first write (a `:write` slot, an `:instance` slot, a member
  write counted as its instance's). It knows no `cal`. The surface pin in
  `runtime_test.exs` gains `writes: 1`.
- **Binding, in `Logex.Configuration.check/1`**: for each instantiated type, once, at its
  first instance in line order, each var_external in declaration order: no global of its
  name (with a did-you-mean among the globals), a global of another type, and a write
  (from the walk) to a global that is an input point. Each is a `:configure` diagnostic at
  the instance's line, prefixed `program instance `m1`: ` as M2-1's other instance
  messages are.
- **Warnings**: `new!/1` fills `%Logex.Configuration{}.warnings` with two kinds, from the
  walk: a second instance that writes a global through var_external, and an instance that
  writes, through var_external, a global a connection drives (worded differently when the
  connection is the same instance's).
- **Run time, in `Logex.Runtime`**: `wiring.externals`, each instance's var_external
  names; in a scan, `Map.take(globals, externals)` merged into the env before `call/4`,
  then `Map.take(env, externals)` merged into the globals and `Map.drop(env, externals)`,
  both before the connections' copy-out; `start/1` and `restart/2` drop the var_externals
  that `instance/1` and `restart/3` put in every env at 0; `get/2` and `get!/2` read an
  instance's var_external from the global. `call/4`, `scan/2,3`, `put_inputs/3`,
  `restart/3`, `Logex.Edit` and `Logex.Program.initial_env/1` are unchanged.

## 2. Rules settled, each with what shows it

**One copy, at run time**

1. **Merge before the scan, split after, through the env, and `call/4` unchanged.** The
   scheduler cannot pass a global through `call/4`'s `inputs`, which refuses a
   var_external key ("only a var_input is set from outside"), so it writes the env
   directly. Shown by the walk test ("a seeded walk of resources against a model that runs
   each program over one map of globals", 120 configurations × 40 steps), whose model
   runs each program as Elixir over one map of globals, the pointer reading of IEC and
   MatIEC (`research.md` MAT-8), with no merge and no split: outputs, events, every global,
   every `m.ext` and every own tag agree at every step. Its reach set is asserted whole:
   restart, a global another instance changed earlier in the cycle read through a
   var_external, a write a reader earlier in the cycle missed, an output point written
   through one, a copy-out over the same scan's write, a one-shot fired, a dint moved, a
   task not due. So the merge/split and direct access agree wherever scans do not
   interleave, which §4.6's "no preemption" guarantees.
2. **Visibility follows the order, §4.6, with nothing added.** An instance sees a global
   an earlier instance wrote in the same cycle (declaration order in a task, priority across
   tasks, task-less last), never a later one's, which it sees in the next cycle; a slower
   writer's value holds between its runs. Probe p3; test "an instance sees a global an
   earlier instance wrote in the cycle, and a later one's in the next" (y traces
   `[0,1,0,0]`, `[0,0,1,0]` three ways, and `[1,1,1,0]` for a 30 ms writer under a 10 ms
   reader).
3. **Within one scan, a connection's copy-out lands after a write through a
   var_external** to the same global: the split comes before the copy-out. That is
   IEC's and MatIEC's order (a VAR_EXTERNAL is written during the body; `=>` assignments
   follow it). Probe p1 last block (`g` 0, `b.g` 0); test "two instances that write one
   global, and an instance that writes one a connection drives" (`h` and `b.h` both 0).
   Reverting the order is red (mutant "split before the copy-out").
4. **The split writes every var_external back, read-only ones included.** Within the
   contract it equals writing back only what the walk says the program writes: nothing
   else runs during a scan, and `check/1` refuses a write to an input point, so a
   read-only var_external writes back the value it was merged with. Not separately
   pinned; no mutant tells the two apart.
5. **Between scans no instance env holds a var_external** (start, every cycle, restart).
   Pinned only by tests that look inside the opaque struct on purpose (`envs_hold/2`), as
   `scheduler_test.exs`'s plain-data test does. **With that peek blinded, reverting the
   drop after a scan, or the drop at `start/1`, or at `restart/2`, leaves all 548 tests
   green** (`mutation-blind.json`): one copy is structural, unobservable through the
   public API, because every merge overwrites the stale value and `get/2` reads the
   global. Its first observable consequence is OE-2's switch (rule 14). See Q6.
6. **`get/2` and `get!/2` read `m1.estop` as the global**: the same value as `estop`,
   whoever wrote it last, before any cycle (an unlocated global's initial value, 7 in the
   test), after `restart/2` (an input point's kept image). `m1.estop.x` gives the
   ordinary "goes too deep: `m1.estop` is a bool" reason. Probes p2, p4; tests "get/2
   reads an instance's var_external as the global, whoever wrote it last" and "an output
   point written through var_external, and restart/2…". Reverting it is red in 4 tests.
7. **`restart/2` holds no var_external**: the global goes back by
   `Configuration.initial/1`, an input point keeps its image, an output point goes to 0,
   and the instance's own tags restart through `restart/3`, whose var_externals at 0 are
   dropped again. Probe p4 (`{0, 0, 7, 1}` for `m.k`, `k`, `m.n`, `m.x`); the walk's
   restarts.
8. **An output point written through a var_external is driven by it**: the output image,
   read after every scan, shows the write. Probe p4 (`%{"k" => 1}`); test above.

**The e-stop Done-when**

9. **"Stops both in the same cycle" holds only where both instances run in that cycle.**
   On one task, the README motor plus `var_external estop bool` and `xic estop otl fault`
   stops `m1` and `m2` in the cycle the input point rises (`k1`, `k2`: 1,1,0,0); test "the
   Done-when: an e-stop read by two instances through var_external stops both in the same
   cycle". **On §4.4's rates (m1 every 10 ms, m2 every 50 ms) a 10 ms e-stop pulse never
   reaches m2**: it runs at 0 and 50 ms, the e-stop is 1 only at 20 ms, so its `fault`
   never latches and `k2` stays 1 throughout. Probe p2 second block; test "an instance on a
   slower task sees the e-stop only when it next runs, and misses a shorter pulse". This
   is sampling, as true of a connection as of a var_external, but the Done-when and §4.4
   read as if it were not. See Q1.

**A program run alone**

10. **A lone instance's var_external is a tag of its own at 0, which the host cannot set**
    (§4.9's row, the design's G2): `instance/1` starts it at 0; `put_inputs/3` and
    `call/4` refuse it with the existing message, ``input `estop` is a var_external
    (declared on line 5), not a var_input: only a var_input is set from outside``; logic
    may write it and it then persists in the env; `restart/3` puts it back to 0. Probe p2.
11. **That is exactly a one-instance configuration whose global is unlocated, with no
    initial value, that only this instance uses.** Test "agrees with a one-instance
    configuration whose global is unlocated, at 0": 400 seeded steps, scan/3 against
    cycle/3, cold restarts on both sides, equal outputs and `m.g` and `m.s` at every step.
    So §4.6's "scan/2 and a one-line configuration give identical outputs" extends to a
    program with a var_external, given that global; a global with an initial value, or an
    input point, breaks the agreement, as it must.
12. **`Logex.Edit` on a lone instance moves a var_external as any tag.** `var g` ↔
    `var_external g` keeps the value with an empty report (decision 25);
    `var_external g` → `var_input g` reports `{:input, "g", 0}` (decision 22). Probe p4;
    test "Logex.Edit moves a var_external as any tag". No edit rule needs a var_external
    clause for a lone instance.
13. *(Owed to OE-2, pinned here)* **Over the env a resource holds between scans, which
    lacks the var_external, an edit reports `{:added, "g", 0}` and writes a second copy**:
    test "Logex.Edit over an env with no var_external in it reports one :added". So OE-2's
    switch must merge first (the design's recommended pair, §4.9's "OE-2 decides" cell); a
    plain per-instance `Edit` call inside a resource is wrong. This is the one place where
    rule 5 (one copy) becomes observable. Decision 45, recorded on main at `293b3e8` while
    the spike ran, adopts that merge (Q12).

**Checks and warnings**

14. **Binding, once an instantiated type** (probe p1; tests in "binding, in check/1"), whole
    messages from Elixir data:
    - `program instance `m1`: `motor` declares `var_external estop bool` (line 5), but there is no global `estop` — did you mean `estp`?`
    - `program instance `m1`: `motor` declares `var_external estop bool` (line 5), but `estop` is a dint`
    - `program instance `w`: `writer` writes its var_external `estop` (line 3), but `estop` is an input point: nothing writes an input point`

    A type given among `programs:` but not instantiated is not checked; two instances of a
    type give one diagnostic. An input point read through a var_external is legal and gives
    nothing. Each is red when reverted ("once a type", "only instantiated types" included).
15. **A var_external named in a connection is refused**, by the existing rule that only a
    var_input or var_output connects, but in words that call it internal:
    ``` `m1.estop` is internal to `motor` (declared `var_external`): only a var_input or var_output connects```
    (probe p1; pinned as is). See Q4.
16. **Which instances write which global comes from the IR**: `writes/1` on each instance's
    program, filtered to its var_externals, grouped by global, in instance order. An `ons`
    storage bit counts (its slot writes), a `ton` counts its timer, a member write counts
    its instance (`%{"e" => 6, "n" => 7, "s" => 6, "t1" => 8}` in probe p1). Two
    instances of one type that write a global are two writers (probe p6).
17. **Cost**: linear in instances and in var_externals, with a fixed overhead per
    instance. A cycle of n task-less instances each reading and writing k globals
    (probe p5, least of five, reductions): n=25 k=4 6,441 vs 5,833 for the same rungs on
    own tags (+10%); n=100 k=4 26,540 (4.12× for 4× n); n=25 k=16 19,201; n=25 k=64 77,311
    (4.03× for 4× k, +21% over own tags); 4.5 to 8.5 reductions per external per instance per
    scan. The growth test asserts < 5.1× for 4× instances (measured 3.99×) and 4×
    externals (3.26×), probe p7, stable over three runs and three gates at load ~10.
    `start/1` 34,024 → 118,035 and `restart/2` 10,509 → 34,795 from 25 to 100 instances of
    16 externals. `get/2` of `m1.g1` costs 69 reductions at either size: it merges the
    instance's own externals, linear in those, not in n (see Q9).

## 3. Where the record is silent or wrong

**Q1. The e-stop Done-when on two rates.** PLAN M2-4: "an e-stop … read by two instances
through `var_external` stops both in the same cycle". §4.4's plant puts m1 on 10 ms and m2
on 50 ms, and says the `trip` task "on the cycle the e-stop rises … runs before `m1` and
`m2`", as if both ran in that cycle. They do only when both tasks are due; and an e-stop
shorter than m2's interval never reaches m2 at all (rule 9).
- (a) The Done-when on instances that both run in the cycle the e-stop rises: one task,
  or §4.4's plant (from its configuration file, since M2-2 and M2-3 have landed, without
  `trip` until M2-6) with the e-stop raised at a cycle both tasks are due, 50 ms; plus a
  second test that pins the sampling (rule 9's second test). §4.4 gains one sentence: an
  instance sees a global when it runs, so an e-stop must be held at least the slowest
  interval that reads it, as a maintained e-stop contact is.
- (b) Reword the Done-when to "each instance stops at its next scan".
- (c) Make the e-stop reach every reader in the cycle it rises (an event task that runs
  m1 and m2, or a latch in the configuration): new mechanism, no decided text asks for it.

*Recommend (a)*, on §4.4's plant at 50 ms: it keeps the decided words true of the
decided plant and documents what they do not say. §4.4's "before `m1` and `m2`" becomes
"before any instance due in that cycle".

**Q2. A write through a var_external and a connection's copy-out to one global, in one
scan.** The record is silent on the order. (a) The copy-out lands last (spike: split, then
copy-out; IEC and MatIEC write externals during the body and `=>` after it). (b) The
external write lands last. (c) Refuse a global that one instance both writes through a
var_external and drives by a connection. *Recommend (a)*, stated in `Logex.Runtime`'s
cycle step 4 and in the warning's words (Q3); (c) would refuse what IEC allows and what
§4.4 already makes a warning.

**Q3. The two writer warnings' words, and a shared `ons` storage bit.** §4.10 lists the
two warnings and nothing of their words; the design's words, "the later of the two in a
cycle wins", are wrong in three cases the spike found:
- two instances that only latch (`otl`) one alarm both contribute; neither "wins" (probe
  p6: a2's latch stands after a1 runs);
- an `ons` whose storage bit is a var_external, in two instances of one type: the first
  to run sets the bit, so the second never fires on the same edge (probe p6: `y2` never
  1). That is the hazard `Logex.Warnings` already names inside one program ("the
  one-shot then fires on the wrong scans");
- one instance that writes a global through a var_external and drives it by its own
  connection: the copy-out wins whatever the order (rule 3).

Options: (a) one wording true of all: ``…: each scan reads what the other last wrote, and the later write in a cycle stands``, with the same-instance case its own (``its own copy-out, after the scan, stands``) and the `ons` case the one-shot wording; (b) warn only where a writer writes unconditionally (`ote`, `move`, `ons`), sparing latches; (c) refuse an `ons` on a var_external storage bit in `.ld`, since the bit is the instance's own edge memory. *Recommend (a)*, keeping the record's two warnings as decided and their scope, with (c) left as a later tightening (refusing later breaks programs; warning now does not).

**Q4. A var_external named in a connection.** The rule refuses it (correct), but the
existing message calls it internal, which a var_external is not. *Recommend* its own
words, as the design pass had them: ``…`m1.estop` is a var_external of `motor`, which reaches the global `estop` itself: only a var_input or var_output connects``.
Alternative: keep the shared message with the section named (as now). One message per
rule argues for one sentence with the section's own reason.

**Q5. Where a lone instance's var_external comes from.** The record (§4.9, §4.10) says it
starts at 0 and its host cannot set it; it does not say what that equals. Rule 11 settles
it: an unlocated global, no initial value, used by this instance alone. *Recommend* stating
that equivalence in `Logex.Runtime`'s moduledoc and §4.6, beside "scan/2 and a one-line
configuration give identical outputs", whose one-line configuration then declares an
unlocated global per var_external. Alternatives (refuse `instance/1` for such a program;
let the host set it as an input) are the design's G1 and G3, already rejected.

**Q6. How to pin "one copy".** The record states it as a rule (§4.9's checklist, §4.10)
but it is invisible through the public API (rule 5). (a) Pin it by a test that looks
inside the opaque struct on purpose, as the plain-data test does (spike). (b) Pin it only
through OE-2's switch when OE-2 lands. (c) Drop the drop: let the env carry a stale copy,
overwritten at every merge. *Recommend (a)*: three one-line drops a refactor can lose,
and OE-2's rule (rule 13) depends on them; (c) puts a second, stale value where OE-2's
switch would read it.

**Q7. The input-point write check: once a type, cited where.** §4.10 says the binding is
"checked once a type"; it is silent for the write check, and on which line the message
names. Spike: once a type too, at the first instance, naming the `.ld` line of the first
write ("(line 3)"). With F15's `file` on `%Logex.Program{}` (M2-5), the text names the
file: `on line 3 of writer.ld` (M2-2's "Citing a program type"). *Recommend* that, and
that B5's walk give each written tag its first line, not only its name.

**Q8. Seams with M2-2's warnings.** M2-2's W1 ("a global nothing uses") and W2 ("an output
point something reads and nothing drives") land before M2-4 and know no var_external.
Unchanged, an e-stop read only through `var_external estop` gets "nothing uses it", and an
output point written only through a var_external gets "nothing drives it". *Recommend*
M2-4's checks commit amend both: a var_external of an instantiated type is a use; a write
through one drives an output point.

**Q9. `get/2`'s cost and shape.** The spike merges an instance's var_externals into a view
of its env for every read, linear in that instance's externals. *Recommend* the landing
read the global directly when the path's tag is a var_external, O(1); the result is the
same.

**Q10. A var_external named like a configuration keyword** (§4.8: "must be legal in both
kinds"). Not built here. The check needs the configuration's keyword list, which grows
by item: at M2-4 `program var_global at task interval priority with`; M2-6 then reserves
`single`, so `var_external single bool` compiles under M2-4 and is refused under M2-6.
*Recommend* M2-4 refuse against `Logex.Configuration.Text.keywords/0` as it stands, and
M2-6's commit name `var_external single` among the names it breaks (CLAUDE.md step 2).

**Q11. Warnings' home.** `check/1` returns only errors (`start/1` raises on any), so the
spike fills `warnings` in `new!/1`. M2-2 lands the configuration's warnings pipeline
first; M2-4 adds its two to that pipeline, and `start/1` never reads them. Also: the
spike's `warned/1` finds each connection's instance by a linear search, quadratic in a
large configuration; the landing indexes once, so §4.10's "checking … is linear in its
instances" holds.

**Q12 (for OE-2): answered while the spike ran.** Main moved to `293b3e8` after the
spike's base, recording decision 45: the switch merges each global in by the running
program's externals and splits it off by the candidate's. Rule 13 is the run-time
evidence it needs: without that merge, an edit over a resource's env reports
`{:added, "g", 0}`. Nothing in M2-4 depends on it; M2-4's documents cite decision 45
where §4.9's row is updated.

Not wrong, but worth a line in the documents: a var_external bound to an event task's
`single` global (M2-6) and written by logic takes effect at the next cycle's sample, as
§4.6 says of any trigger written by logic; a block takes a global through a var_input
operand of `cal` (M2-5), whose output operand may be a var_external, which the walk must
count as a write.

## 4. What M2-4's landing commits must contain

After M2-5 and M2-2 (and M2-3), as PLAN M2-4 orders them. Each green under the full gate,
its mutation rows in its message.

1. **B5's one IR walk.** Public, over the IR: which tags a program writes, each with the
   line of its first write (Q7), and which timers it runs; a `cal`'s output operands as
   writes, block bodies reached, an `ons` bit and a member write counted as in rule 16.
   No behaviour change; `Logex.Warnings`' and `Logex.Edit`'s walks moved onto it; the
   surface pin rewritten once.
2. **`var_external`.** The naming stanza (the design pass's, used here unchanged); the
   `@sections` row and `Logex.Tag`'s type; refusals of an initial value and of an instance
   (words as in rule 14's source tests); the keyword-name refusal against the
   configuration's keywords (Q10); its refusal in a block's file with a located diagnostic
   (M2-5's `FbType.role/1` must not see one); reserved in any case, breaking no tag in the
   repository; `api_contract_test.exs`'s `@words` gains it; README's syntax list.
3. **Binding and warnings.** In `check/1`, once an instantiated type at its first
   instance's `program` line, naming the type's `.ld` file and line: no global (with
   did-you-mean), another type, a write to an input point; a var_external in a connection
   with its own words (Q4); the two writer warnings with Q3's words, in M2-2's warnings
   pipeline, indexed (Q11); W1 and W2 amended (Q8). Every one pinned as a whole list from
   data and again from a configuration file's text.
4. **One copy at run time.** `wiring.externals`; merge before `call/4`; split into the
   globals, then the copy-out (Q2); the drop at `start/1` and `restart/2`; `get/2` reading
   the global directly (Q9). Tests: the Done-when per Q1 (§4.4's plant at a cycle both
   tasks run) and the sampling test; visibility (rule 2); copy-out order (rule 3); an
   output point and `restart/2` (rules 7, 8); `get/2` (rule 6); the lone-instance
   equivalence (rule 11) and the two `Logex.Edit` tests (rules 12, 13); one copy by a peek
   (Q6); the seeded walk against a model with no merge (as spiked, or folded into
   `api_contract_test.exs`'s configuration walk, whose model scans through `call/4` and
   would need its own pointer semantics to stay independent); growth in reductions.
   Documents: `Logex.Runtime`'s moduledoc (cycle step 4; the one-rule section: a
   var_external holds no state in a resource; the lone-instance equivalence),
   `Logex.Program.initial_env/1`'s doc, §4.4 (Q1's sentence), §4.6 (step 4; scan/2's
   agreement), §4.9's row (as built), §4.10 and PLAN M2-4 marked landed (and PLAN's
   "two run-time pieces were not spiked" now one), CLAUDE.md's key-file lines, README's
   "A configuration" with an e-stop shared through `var_external`.

**The spike's mutation rows** (each reverted alone; all red under the full suite):

| Rule reverted | Tests red |
|---|---|
| merge before `call/4` | 6 |
| split: write back into the global | 5 |
| split: drop from the env after a scan | 2 (peek only) |
| split before the copy-out | 2 |
| `get/2` reads the global | 4 |
| `start/1` drops the var_externals | 1 (peek only) |
| `restart/2` drops them | 2 (peek only) |
| only var_external tags are merged | 9 |
| binding: no global of its name | 1 |
| binding: types agree | 1 |
| binding: no write to an input point | 1 |
| binding: once a type | 2 |
| binding: only instantiated types | 1 |
| warning: two writers | 1 |
| warning: a writer and a connection | 1 |
| warning: its own copy-out wins | 1 |
| warnings filled by `new!/1` | 1 |
| declaration: the section row | 20 |
| declaration: no initial value | 1 |
| declaration: no instance | 1 |
| `writes/1`: an instance slot is a write | 1 |

The three "peek only" rows go green when the peek is blinded (rule 5, Q6).
