# OE-2's design: a staged edit of a running configuration

Design pass for `PLAN.md` OE-2, against `main` at `92431a9` (2026-10-13), on Elixir 1.20.4 /
OTP 28. A throwaway spike on that commit (branch `backup/oe2-design`, two commits,
`2c49aaa` and `8bdb939`) built the switch from OE-1's per-instance plan, switch and prune
plus decision 45's merge and split, and ran 13 probes on §4.4's plant. Its findings are in
§6. Nothing here is landed.

Read with: `docs/organisation.md` §4.9 (online edit, "OE-1's design", "One rule for new
state"), §4.10, §7 decisions 19–29, 31–32, 40, 43–45, 47 and 49–52; `Logex.Runtime`'s
one-rule section; `Logex.Edit`'s moduledoc.

**Already decided, and built on here:** decision 43 (a retyped instance is a remove plus an
add); 44 (a kept global's changed initial value is reported); 45 (merge by the running
program's var_externals, split by the candidate's); 40 (`min(next_due, now + new
interval)`); an event task's trigger keeps its last sample; refused while running: a
changed `single`, an event task's interval added or removed, an instance moved to another
task, a task added or removed, located I/O and devices; output points left undriven held
and reported; a generation counter detects an edit outside the contract.

---

## 1. The public API

### 1.1 Where it lives

A new module, **`Logex.Configuration.Edit`**, holding an opaque **`%Logex.Configuration.Edit{}`**,
beside `Logex.Configuration.Text` and `Logex.Configuration.Task`. Its steps have OE-1's
names, order and report shape. (Open question Q5 asks the maintainer to confirm this over
extending `Logex.Edit`.)

Two internal moves make it possible, with no behaviour change:

- **The per-instance half of `Logex.Edit`** (`retyped/2`, `plans/2`, `switch/4`,
  `prune/3` and the empty record) moves to an internal module, `Logex.Edit.Plan`
  (`@moduledoc false`). `Logex.Edit` and `Logex.Configuration.Edit` both call it. This is
  fix F5 as it was meant: "OE-2 can build one plan per program type and call them once for
  each instance". The exact-public-surface test in `runtime_test.exs` lists the new
  module as internal.
- **`%Logex.Runtime{}` stays opaque** and is still defined in `Logex.Runtime`. The switch
  that writes into it is a function of `Logex.Runtime` (`@doc false`, named as internal in
  the surface test), and `Logex.Configuration.Edit` calls it with what it computed. So the
  resource's fields are written in one module only. The spike wrote them straight from
  the edit module, which works but spreads the struct's invariants (decision 49's "no
  var_external held") over two files.

### 1.2 The functions

```elixir
Logex.Configuration.Edit.accept(runtime, candidate)
  :: {:ok, edit, forecast} | {:error, [%Logex.Diagnostic{stage: :edit}]}
Logex.Configuration.Edit.test(edit, runtime)     :: {edit, runtime, report}
Logex.Configuration.Edit.untest(edit, runtime)   :: {edit, runtime, report}
Logex.Configuration.Edit.assemble(edit, runtime) :: {candidate, runtime, report}  # ends
Logex.Configuration.Edit.cancel(edit, runtime)   :: {original, runtime, report}   # ends
Logex.Configuration.Edit.running(edit) :: %Logex.Configuration{}  # what the resource runs now
Logex.Configuration.Edit.stage(edit)   :: :accepted | :testing | :untested
```

- **`accept/2`, not `/3`.** The resource carries the configuration it runs, so accept
  needs no "running" argument. That removes two of OE-1's undetectable cases outright:
  scanning the program the edit is not running, and accepting against a program the state
  is not running. Accept reads the runtime only for the forecast, which is never applied
  (decision 27). It does not change the runtime, so it returns none.
- **Each step takes and returns the runtime.** Test installs the candidate configuration
  into the resource; from then on `Logex.Runtime.cycle/3` runs it. The host never chooses
  a program to scan. `running/1` is informational: what `cycle/3` will run.
- **Assemble and cancel return the configuration kept** beside the runtime, as OE-1
  returns the program kept, so a host that saves the plant's text can print it
  (`Logex.Configuration.Text.print/1`).

### 1.3 How the host drives it

Every step is taken between two cycles, never inside one. The loop of `Logex.Runtime`'s
moduledoc is unchanged; a step slots in between two `cycle/3` calls:

```elixir
{:ok, candidate} = Logex.Configuration.compile_file("plant.logex")
{:ok, edit, forecast} = Logex.Configuration.Edit.accept(rt, candidate)
# ... the operator reads the forecast; cycles go on running the original ...
{edit, rt, report} = Logex.Configuration.Edit.test(edit, rt)      # candidate from next cycle
{rt, outputs, events} = Logex.Runtime.cycle(rt, 10, inputs)        # the candidate runs
{edit, rt, report} = Logex.Configuration.Edit.untest(edit, rt)    # the original again
{edit, rt, report} = Logex.Configuration.Edit.test(edit, rt)
{config, rt, report} = Logex.Configuration.Edit.assemble(edit, rt) # the edit ends
```

| Step | Taken from | `cycle/3` then runs | The resource |
|---|---|---|---|
| accept | — | the original | read for the forecast, unchanged |
| test | accepted, untested | the candidate | switched to the candidate: instances, globals, tasks, wiring |
| untest | testing | the original | switched back |
| assemble | testing | the candidate; the edit ends | pruned to the candidate: instances set aside, globals and tags only the original has |
| cancel | accepted | the original; the edit ends | unchanged but for its generation; the report is `[]` |
| cancel | untested | the original; the edit ends | pruned to the original |

To finalise without cycling the candidate, the host takes test and assemble at one
boundary, as in OE-1.

**The host's duties shrink.** OE-1's four duties (send only the running program's inputs,
resend each `:input`, stop sending each `:unread`, hold each `:held` point) all fall away
in a resource:

- the input image is the resource's, kept across every step, and located I/O cannot
  change, so the same input points are sent before and after;
- a var_input is copied in from its connection before every scan (decision 22's "OE-2's
  copy-in will then make it automatic"), so a step's `:input` and `:unread` carry no
  duty;
- a held output point keeps its global's value, and `cycle/3` returns every output point
  every cycle, so the host holds it by writing the outputs it is given, as always.

What remains: take each step between two cycles, keep the runtime each step returns,
restart through `Logex.Runtime.restart/2` (allowed during an edit, keeping its stage), and
tolerate a report kind it does not know.

### 1.4 The report

A list of `{kind, name, detail}`, sorted, at most one entry per kind and name; the kinds an
open set. Names: a global, task or instance by its own name (they share one namespace,
which `check/1` keeps free of case twins, so a bare name is never ambiguous); anything
inside an instance by its path, `m1.t1`, `m1.s1.edge` (§4.9's "from OE-2 it names an
`instance.tag` path").

**OE-1's twelve kinds, by path**, from each kept instance's switch or prune, as
`Logex.Edit` gives them: `:added`, `:input`, `:unread`, `:preset`, `:preset_kept`,
`:dn_drops`, `:dn_rises`, `:resumed`, `:resume_undone`, `:ons_blocked`,
`:initial_changed`, `:held`, `:pruned`. (`:input` and `:unread` are kept, as facts and,
for `:input`, as a write the walk can rebuild; neither carries a duty, §1.3.)

**New kinds:**

| Kind | Name | Detail | Given by | Write or fact |
|---|---|---|---|---|
| `:instance_added` | instance | its program type | a switch | write: started by `Runtime.instance/1`, var_externals held by no state |
| `:instance_stopped` | instance | its program type | a switch | write: set aside, its state kept unused |
| `:instance_back` | instance | its program type | a switch | write: back from aside, its state as it was set aside |
| `:instance_pruned` | instance | its program type | assemble, cancel | write: its state dropped |
| `:added` | global | its initial value | a switch | write: `Configuration.initial/1` |
| `:initial_changed` | global | `{old, new}` | a switch | fact: the running value is kept (decision 44) |
| `:pruned` | global | the value it had | assemble, cancel | write |
| `:held` | global | its value | every step | fact: nothing drives it any more (decision 20) |
| `:interval` | task | `{old, new}` ms | a switch | fact |
| `:next_due` | task | `{from, to}` ms | a switch | write: decision 40 |
| `:priority` | task | `{old, new}` | a switch | fact |
| `:joined` | `instance.tag` | `{own, global}`: the instance's own value, nil where it had none, and the global's | a switch | fact: the instance reads the global from its next scan (Q1) |
| `:left` | `instance.tag` | the global's value | a switch | fact: a var_external become the instance's own tag, starting at the global's value (decision 45) |
| `:order` | task, or `:none` | the instance names in their new order | a switch | fact (Q8; only if adopted) |

The writes a report lists, applied to the resource before the step, give the resource
after it, exactly, with `switched` and the block lists as OE-1 states them. The contract
walk checks it (§5, commit 7).

### 1.5 The host mistakes

`ArgumentError`, each message pinned by a test. A step checks the edit, then the runtime,
then that the edit is current, then the stage, as OE-1 checks the edit, the state, then the
stage.

| Mistake | Message |
|---|---|
| `runtime` not a resource, at accept or a step | the runtime's own: ``expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: …`` |
| `candidate` not a configuration | `start/1`'s own: ``expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: …`` |
| `candidate` with a problem `check/1` finds | `start/1`'s own: every diagnostic, a line each, as `Diagnostic.format/1` gives it; `check/1`'s own raise for a host mistake no text can make |
| `candidate` with another name | ``the candidate is `pump_house`, but the running configuration is `plant`: an edit keeps the configuration's name`` |
| `edit` not one | ``expected a %Logex.Configuration.Edit{} from Logex.Configuration.Edit.accept/2, got: …`` (so a `%Logex.Edit{}` is refused here, and a `%Logex.Configuration.Edit{}` by `Logex.Edit`'s own message) |
| the resource runs another configuration than the edit's | ``this edit is of another configuration than the one the resource runs: accept the candidate against this resource`` |
| the generation has moved (§2.5) | ``this edit expects the resource at generation 3, but it is at generation 5: the edit has ended, or another edit has stepped since`` |
| a step at the wrong stage | OE-1's words: ``test takes an edit accepted or untested, but this one is under test``, and likewise for untest, assemble and cancel |

A candidate with `check/1` problems is the host's mistake, not the source's: a candidate
from text reaches accept only through `compile/3` or `compile_file/1`, which return those
problems first, and `start/1` raises the same. One rule for handing a configuration to a
running resource.

---

## 2. Every rule

### 2.1 What may change while running

- **A task's interval** (a periodic task, or an event task that has one) and **priority**.
  A changed interval makes the task next due at `min(next_due, now + new interval)`, at
  test and again, with the old interval, at untest (decision 40), reported as
  `:interval` and, where it moves, `:next_due`. A priority is read at each cycle's sort,
  so it needs no state: `:priority`.
- **The order** of tasks and of instances: execution order and the tie-break are
  configuration, not state, so a reorder needs no rule for state (Q8 asks whether it is
  reported).
- **Instances added and removed**, keyed by name. An instance only the started
  configuration runs is started by `Runtime.instance/1`, its var_externals dropped as
  `start/1` drops them, `:instance_added`; or brought back from aside, `:instance_back`.
  An instance only the stopped configuration runs is set aside, its state kept unused,
  `:instance_stopped`, and pruned at assemble (or at cancel after an untest),
  `:instance_pruned`.
- **An instance's program type** (decision 43): a remove plus an add under one name. The
  old state is set aside and the new one started, both reported; at untest they trade
  places. A retyped instance may run on another task than the old one (Q7).
- **A program type changed**: each kept instance (same name, same type name in both)
  moves through OE-1's per-instance switch, one plan per program type and direction, built
  once at accept (fix F5), its reports by path. A program type no instance runs in both is
  not planned.
- **A function block type changed for the whole configuration** (decision 31): each
  program type holding it is a changed program type, moved by its own plan. Its members
  move by path; a member whose kind changes is refused by its path in that program
  type's file.
- **A tag's section**, a var_external among them (decisions 25 and 45, §2.4).
- **Globals**, unlocated: added at `Configuration.initial/1`, `:added`; removed, kept
  unused at test and pruned at assemble, `:pruned`; a kept global's changed initial value
  reported, `:initial_changed`, its running value kept until `restart/2` (decision 44).
- **Connections**, any of them: the resource's wiring is derived again from the
  configuration it switches to. A var_input's new connection is read at its instance's
  next scan; an output point that loses its driver holds (§2.3).

### 2.2 What is refused at accept

Each is an `%Logex.Diagnostic{stage: :edit}`, in the candidate's `file`, at its element's
line, in line order, an element only the running configuration has (no candidate line)
last. The message ends, as OE-1's do, with "… only with a restart".

| Change | Cited at | Message (proposed; the spike pinned plainer forms of the first, third, fifth and seventh, to be settled in commit 4) |
|---|---|---|
| a task added | its `task` line | ``task `extra` is added: a task is added only with a restart`` |
| a task removed | no line, last; the message names the running configuration's line | ``task `slow` (line 3 of the running configuration) is removed: a task is removed only with a restart`` |
| a task's `single` added, removed or changed | its `task` line | ``task `trip`'s single changes from `estop` to `pb_reset`: a task's single changes only with a restart`` |
| an event task's interval added or removed | its `task` line | ``task `trip` has a single, and its interval is added: an event task's interval is added or removed only with a restart`` |
| a kept instance moved to another task, or to or from none | its `program` line | ``` `m2` runs with `slow` in the running configuration and with `fast` in the candidate: an instance moves to another task only with a restart``` |
| a global's type changed | its `var_global` line | ``` `sp_2` is a dint global in the running configuration and a bool in the candidate: a global's type changes only with a restart``` |
| located I/O: a located global added, removed, moved, or a location added to or taken from a global | its line, or no line for one removed | ``` `sp_2` is at `drive.q.1` in the running configuration and at `drive.q.2` in the candidate: located I/O changes only with a restart``` |
| a tag's or member's type, in a program type a kept instance runs | that type's own file and line (fix F15) | OE-1's own messages, once a type |

A device exists only as its points' prefix (§4.5), so a device renamed or added is a
location change and is refused by the same row. A candidate's warnings stop nothing, as in
OE-1.

### 2.3 Held outputs (decision 20)

A global the stopped configuration drives and the started one does not holds its value,
and every step reports it, `{:held, global, value}`, the value being the global's in the
resource, which is what the next cycle's outputs give for an output point. "Drives" is:
a connection copies out a var_output its program writes (`Logex.Walk.writes/1`), or a
program writes the global through a var_external. A connection whose var_output the
program no longer writes copies a frozen value, so its point holds too; the spike found
that a connection-only reading missed this (`lamp_1` stayed unreported). Each kept
instance's own `:held` entries for its var_outputs come by path beside it (Q4).

### 2.4 Shared globals across a switch (decisions 45, 47 and 49)

For each kept instance, at every switch:

1. **Merge** each global into the instance's state by the var_externals of the program
   the switch stops.
2. **Switch** the instance by its type's plan. The plan is built knowing the started
   program's var_externals, so no start rule starts one: none is reported as `:added`.
   (The spike filtered those `:added` entries out of the report after the fact; landing
   it in the plan is cleaner, risk R4.)
3. **Split** each var_external of the program started off the state. The global itself is
   never written by a switch (Q1's recommendation, and decision 45's "the global itself is
   untouched").

So:

- a var_external in both programs: merged, kept, split; the global untouched; no report;
- a var_external become a `var` (`estop`, the running program's var_external, the
  candidate's own `var`): merged in, kept as the instance's own tag at the global's value
  (decision 25), `{:left, "m1.estop", v}`;
- a `var` become a var_external: the instance's own value is dropped at the split, the
  global left alone, and the instance reads the global from its next scan,
  `{:joined, "m1.estop", {own, global}}` (Q1);
- a var_external the candidate adds, of a name the running program never declared: bound
  to its global, `{:joined, "m1.alarm", {nil, global}}`; where the global is one the edit
  adds, it starts at `Configuration.initial/1`, reported `{:added, "alarm", v}`.

After every step no instance's state holds a var_external (decision 49), which the walk
asserts by looking inside the resource, as the decision-49 test does.

### 2.5 The generation counter

- **What it is:** a non-negative integer in `%Logex.Runtime{}`, `generation`, counting the
  configuration edits' steps taken on this resource.
- **Its rules** (the one-rule section, §2.6): `start/1` gives 0; a cycle keeps it;
  `restart/2` keeps it, since a restart during an edit keeps the edit's stage; every step
  of a configuration edit but accept moves it on by one, cancel from accept included, so
  an edit that has ended can never step again.
- **The edit** records the generation it expects: the resource's at accept, and the new
  one after each of its steps.
- **What it detects:** a step on an edit that has ended (assembled or cancelled), on an
  edit superseded by another that has stepped since, and on one of two edits accepted at
  once after the other has stepped. Together with the check that the resource runs the
  edit's configuration (`runtime.config == running(edit)`, a comparison linear in the
  configuration, as accept is), it also refuses an edit taken to another resource that
  runs another configuration.
- **What it cannot detect:** two resources started from one configuration are equal, plain
  data with no identity (no refs or pids, by §4.9), so an edit accepted on one may be
  stepped on the other while their generations agree. Its plans fit (same configuration);
  only its record of each instance (F1, F3, F4, F11) may be wrong. Outside the contract,
  and documented.
- **A lone instance** (`Logex.Edit`, OE-1) gains no generation: its undetected cases stay
  outside the contract as documented (Q6).

### 2.6 One rule for each piece of state across the switch

Extends §4.9's table and `Logex.Runtime`'s one-rule section; CLAUDE.md's "New state…" asks
for a value from `start/1` and a rule for a cycle, `restart/2` and OE-2's switch.

| Piece | `start/1` | A cycle | `restart/2` | Switch: kept | Switch: added | Switch: removed | Assemble / cancel |
|---|---|---|---|---|---|---|---|
| the clock, `now` | 0 | `+ elapsed_ms` | kept | never touched | — | — | never touched |
| the input image | 0 | inputs merged | kept | kept | refused (located I/O) | refused | kept |
| an output point's value | 0 | its driver's write | 0 | kept; held and reported where nothing drives it (§2.3) | refused | refused | kept; held reported |
| an unlocated global | `Configuration.initial/1` | copy-out, var_external writes | `Configuration.initial/1` | kept; `:initial_changed` (decision 44) | `Configuration.initial/1`, `:added`, at the switch that first finds it missing | kept unused | pruned, `:pruned` |
| a task's `next_due` | 0 | whole intervals | the kept `now` | kept; a changed interval gives `min(next_due, now + new)` (decision 40) | refused | refused | kept |
| a task's overlap count | 0 | `+ missed` | 0 | kept | — | — | kept |
| an event task's last sample | 0 | sampled once | 0 | kept: no switch fires an event | refused | refused | kept |
| `generation` (new) | 0 | kept | kept | `+ 1` | — | — | `+ 1` |
| instances set aside (new; `aside`) | none | kept, never scanned | dropped: the next switch starts each again, `:instance_added` | — | — | an instance only the stopped configuration runs, and a retyped one's old state, set aside | pruned, `:instance_pruned` |
| a kept instance's env | `Runtime.instance/1` | `call/4` | `restart/3` | OE-1's per-instance switch, by path, between decision 45's merge and split | — | — | OE-1's prune, by path |
| an added instance | — | — | — | — | `Runtime.instance/1`, var_externals dropped, or back from aside | — | — |
| an instance's `now` | 0 | the cycle's `now` at its scan | kept | the resource's `now` (Q2) | 0, as `start/1` gives | — | kept |
| an instance's `first` | true | false after its scan | true | never touched | true | — | never touched |
| an instance's `ons_blocked` | `[]` | emptied, but for bits inside a block not run (decision 32) | `[]` | OE-1's rules, against the program that last scanned it | `[]` | — | OE-1's: kept, not added to |
| an instance's `switched` | false | false after its scan | kept | true | false | — | kept |
| a var_external | none held | merged in, split off | none held | decision 45, §2.4 | bound by name | — | none held |
| an instance back from aside | — | — | — | — | its state as set aside, each timer timing resumed from the switch, `:resumed` by path (Q3) | — | — |

Two points the table makes, which OE-1's single instance never met:

- **An instance on a slow task is not scanned by every cycle.** Its `switched` stays true
  from a switch until its own next scan, however many cycles pass, which is what fix F3's
  "no scan since the last switch" needs, read per instance. The spike's slow-task probe
  ran through it.
- **`restart/2` during an edit** restarts the instances of the configuration the resource
  runs, drops those set aside and the globals only the other configuration declares, and
  keeps the generation and the edit's stage: the next switch starts again what it dropped,
  `:instance_added` and `:added`, as OE-1's restart during an edit does for tags.

### 2.7 The forecast

Accept's forecast is the report a test taken now would give: the switch computed over the
runtime as it is and thrown away. A test taken later reads the resource as it is then
(decision 27). The spike asserted `forecast == report` for a test taken at once.

---

## 3. The open questions

Each is given twice: technically, for the record; then in plain language for the
maintainer, with the example plant below. The plain versions are written to be put to
the maintainer exactly as they stand.

**The example plant, used in every plain-language question.** Two conveyor motors, `m1`
and `m2`, run by one motor program. The motor program is checked every 10 ms for `m1` and
every 50 ms for `m2`. One emergency-stop button, wired into the plant once, is read by
both motors. A "trip recorder", `snap`, notes which motors were running when the e-stop
was pressed. Each motor has a run-on timer and a "running" lamp. A change is tried on the
live plant in steps: accept it (check it, nothing changes), test it (the new version
runs), untest it (back to the old one), and assemble it (keep the new one) or cancel it.

### Q1. The write into a shared global when a `var` becomes a `var_external`

*Technically.* Decision 45 merges by the running program's var_externals and splits by the
candidate's. Where the candidate turns a `var estop` into a `var_external estop`, the
merge does not bring the global in, the switch keeps the instance's own value (decision
25), and the split must do something with it. Options:
- (a) drop it: the global is untouched, the instance reads the global from its next
  scan, `{:joined, "m1.estop", {own, global}}` reports the value dropped;
- (b) write it into the global, `{:written, "estop", {from, to}}`, which every reader sees
  in its next scan, and which is impossible where the global is an input point (the input
  image is the host's) or is driven by another instance's connection;
- (c) refuse a `var` become a `var_external` on a configured instance, as stricter than
  decision 25.

*Recommend (a).* No switch writes shared state, as no switch writes a storage bit
(decision 21); decision 45's text already says "the global itself is untouched"; and (b)
can release a pressed e-stop for the whole plant from an edit. The spike built (a) and it
needed no special case.

*Plain language.*
> Today conveyor 2's program keeps its own private "stopped" flag. The change makes it
> read the plant's real emergency-stop button instead. At the moment you test the change,
> the private flag might say "stopped" while the real button is not pressed, or the other
> way round. Which one wins?
> - **The real button wins.** From the next check, conveyor 2 follows the real e-stop.
>   Its private flag's last value is thrown away, and the change's report tells you what
>   it was.
> - **The private flag is copied onto the real e-stop.** Every machine that reads the
>   e-stop sees conveyor 2's old private value straight away. That can stop the whole
>   plant, or make it look as if a pressed e-stop had been released, just by testing an
>   edit.
> - **Not allowed while running.** A change like this needs a restart.
>
> *Recommendation: the real button wins*, because testing a change to one program should
> never change what every other machine sees, least of all an e-stop.

### Q2. Which clock a timer resumes from, in an instance its task does not scan every cycle

*Technically.* OE-1's resume rule sets a restored timer's `last` to the instance's `now`,
its last scan's time. In a resource an instance on a slow task last scanned up to one
interval before the switch. Options:
- (a) the resource's `now`: the switch gives the instance the resource's clock (its `now`
  becomes the resource's), so `last` is the switch's time and nothing is caught up;
- (b) the instance's own `now`, OE-1's rule untouched: the next scan catches up the time
  between the instance's last scan and the switch, which no program with that `ton` ran.

*Recommend (a).* It is what OE-1's resume means, "it resumes from the switch", and the
spike measured the difference: `m2` on a 50 ms task, last scanned at 100 ms, switched at
130 ms, resumed 80 ms under (a), and under (b) 50 ms with 30 ms then caught up at the next
scan. The cost is that §4.9's "`now` and `first` never touched" becomes "an instance's
`now` is set to the resource's at a switch", which is never earlier and no scan reads
otherwise.

*Plain language.*
> Conveyor 2 is checked only every 50 ms. A change took its run-on timer out, and you are
> now putting it back. Conveyor 2 was last checked 30 ms before the moment of the change.
> When the timer comes back, where does it start counting from?
> - **From the moment of the change.** The timer only ever counts time when a version of
>   the program that has the timer is running.
> - **From conveyor 2's last check.** The timer gains up to 50 ms (here 30 ms) that no
>   program with the timer was counting.
>
> *Recommendation: from the moment of the change*, because that is what "the timer
> resumes when it comes back" promises today, and the extra time is a small, silent jump
> that nobody asked for.

### Q3. An instance brought back from aside: do its timers catch up?

*Technically.* An instance set aside (removed at test, or the old state of a retyped one)
comes back at untest, or at a second test for one only the candidate runs. Its timers that
were timing kept `.en` 1 and a stale `last`. Options:
- (a) resume each from the switch, reported `:resumed` by path, as decision 23 resumes a
  `ton` an edit restores;
- (b) let them catch up the time set aside, as a block frozen by a false `cal` catches up
  (decision 8).

*Recommend (a).* The edit stopped the instance, not its logic, which is decision 23's
case, not decision 8's. Its one-shots need no block: their bits hold what they last
received, so an edge they see on return is a real one. The spike did not build this (its
instance came back with its timers stale), so it is commit 5's to test.

*Plain language.*
> You test a change that removes conveyor 2, watch for two minutes, then go back to the
> old version. Conveyor 2 comes back. When it was taken away its run-on timer was halfway
> through counting. When it comes back:
> - **The timer carries on from where it stopped**, as if the two minutes had not
>   happened. The change's report says so.
> - **The timer jumps ahead by the two minutes**, as if conveyor 2 had been running all
>   along, so it may finish at once.
>
> *Recommendation: carry on from where it stopped*, because it was the edit that paused
> conveyor 2, not anything the conveyor did, and that is how a timer put back by an edit
> already behaves.

### Q4. How a held output is named in the report

*Technically.* A var_output no longer written in a kept instance gives OE-1's `{:held,
"m1.run_lamp", v}` by path; the output point it is connected to, `lamp_1`, holds too, and
§2.3 gives `{:held, "lamp_1", v}`. Options: (a) both; (b) the point only, dropping
instance-level `:held` in a resource, since no host holds a var_output; (c) the instance's
only. *Recommend (a):* the point is what the operator sees, the instance's output what the
programmer changed, and keeping OE-1's entries means the per-instance switch is used
unchanged and the walk can check both.

*Plain language.*
> A change stops the motor program switching conveyor 1's "running" lamp. The lamp stays
> as it was (that is already decided), and the report must say so. How should it say it?
> - **Both:** "the lamp output `lamp_1` (terminal `panel.q.2`) is held on" and "`m1`'s
>   `run_lamp` is no longer written, held on".
> - **Only the terminal:** "`lamp_1` is held on".
> - **Only the program:** "`m1`'s `run_lamp` is held on".
>
> *Recommendation: both*, because the operator looks at the lamp and the programmer looks
> at the program, and each needs their own name for it.

### Q5. One tool or two

*Technically.* The configuration edit could be `Logex.Edit` extended, with `accept/2`
over a runtime beside `accept/3` over an instance, and each step dispatching on the
struct; or a new module `Logex.Configuration.Edit`, the same step names and report shape,
the per-instance plan shared through an internal module. *Recommend the new module:*
`Logex.Edit`'s moduledoc and its pinned host-mistake messages describe one instance, and
mixing two kinds of edit in one struct makes every message say which kind it means. The
cost is one more public module in the surface test.

*Plain language.*
> Changing one program on the bench and changing the whole running plant use the same
> steps (accept, test, untest, assemble, cancel) and give the same kind of report. Should
> they be one tool or two?
> - **One tool**, which works out from what you hand it whether you mean one program or
>   the whole plant. There are fewer names to learn, but its help and its error messages
>   have to cover both cases.
> - **Two tools with the same steps**: one for a program on its own, one for the plant.
>   Each has its own help and its own list of mistakes.
>
> *Recommendation: two tools with the same steps*, because the plant version has
> different mistakes to catch (a change that is out of date, the wrong plant) and its own
> help is clearer for it.

### Q6. Does a lone instance get the generation counter too

*Technically.* OE-1's undetected cases (a step on an ended or superseded edit, two edits at
once) stay undetected for `Logex.Edit` on a lone `%Logex.Instance{}`. Giving it a
`generation` is a new field of `%Logex.Instance{}`, with a runtime check, a pinned message,
a value from `instance/1` and a rule for a scan, `restart/3` and a switch (CLAUDE.md), and
it changes the field set the surface test pins. *Recommend not now:* a lone instance is
the bench and the test harness; a running controller is a resource, which gets it. Record
it as a known limit.

*Plain language.*
> The running plant now has a change counter, so a change that is out of date (already
> finished, or overtaken by another change) is refused. Should a single program running
> on its own on the bench get the same protection?
> - **No, the plant only.** On the bench, using an out-of-date change stays your own
>   responsibility, as it is today, and the documents say so.
> - **Yes, both.** Every single program carries a counter too, and checks it at every
>   step.
>
> *Recommendation: the plant only*, because the bench is where you try things, the real
> risk is on the running plant, and adding a counter to every program is extra machinery
> for little gain.

### Q7. May a retyped instance run on another task

*Technically.* Decision 19 refuses moving an instance to another task; decision 43 makes a
retyped instance a remove plus an add. Options: (a) allowed, since the new instance is a
new one and an added instance may go on any task that exists; (b) refused, so a name keeps
its task whatever its type. *Recommend (a):* it follows from decision 43, and a refusal
would make the host rename the instance to get the same effect.

*Plain language.*
> Moving a program to a different schedule (say from every 50 ms to every 10 ms) is not
> allowed while the plant runs. Now a change replaces the trip recorder `snap` with a
> completely different program that keeps the name `snap`. That is already treated as
> "remove the old one, add a new one". May the new `snap` run on a different schedule from
> the old one?
> - **Yes.** It is a new program, and a new program may go on any schedule.
> - **No.** The same name always keeps the same schedule while running.
>
> *Recommendation: yes*, because it really is a new program, and otherwise you would just
> rename it to get around the rule.

### Q8. Reordering tasks or instances while running

*Technically.* The order of `instances` is the execution order within a task, and the order
of `tasks` breaks priority ties (decision 11). Neither is state, so a reorder is allowed
with no rule, but it changes behaviour: an instance moved earlier no longer sees, in the
same cycle, what the one it now precedes writes. Options: (a) allowed and reported,
`{:order, task, names}`; (b) allowed silently; (c) refused. *Recommend (a):* nothing about
it needs a restart, and the report is where a change in behaviour belongs.

*Plain language.*
> A change only reorders the plant file: conveyor 2 is now listed before conveyor 1 on the
> same schedule. Each cycle conveyor 2 now runs first, so it sees what conveyor 1 wrote
> one cycle later than before. Is that:
> - **Allowed, and listed in the report** ("on the 10 ms schedule, the order is now `m2`,
>   `m1`");
> - **Allowed without a word**;
> - **Not allowed while running**?
>
> *Recommendation: allowed and listed*, because nothing needs a restart, but the order
> does change what each program sees, and the report is where you look for changes.

### Routine choices, taken as recommended unless the maintainer objects

Not put as questions; each is in the rules above with its reason.

- A candidate `check/1` refuses is a host mistake, raised as `start/1` raises it (§1.5).
- Cancel from accept moves the generation, so an ended edit can never step (§2.5).
- `:input` and `:unread` stay in the report by path, as facts, with no host duty (§1.3).
- A removed element is cited with no candidate line, last, its running line in the text
  (§2.2).
- An instance's plan is built once per program type and direction; a configuration of N
  instances of one type builds two plans (fix F5).
- `restart/2` during an edit drops what only the other configuration has, and the next
  switch starts it again (§2.6), as OE-1's restart during an edit does for tags.
- A global removed by the candidate, still read by an instance set aside, is kept unused
  until assemble, so the instance finds it if it comes back.

---

## 4. Done when

> *Done when* §4.4's plant, from text and from files on disk, running with both motors
> sealed in and `t1` timing, takes a candidate that raises `t1`'s preset and adds an `ons`
> in `motor.ld`, adds a member to `seal.ld`, shortens `slow`'s interval from 50 to 20 ms,
> removes `snap`, and adds an unlocated global `alarm` with an initial value, which the
> motor reads through `var_external`: test switches the resource between two cycles with
> no instance restarted, no one-shot pulsed and no event fired, `m1` and `m2` keeping
> their state by path with the decided `.pre`, `slow` next due within 20 ms, and its
> report names each instance's preset move and added member, the added global, `alarm`
> joined in each instance, the interval, `snap` stopped and `k1_at_trip` held; untest
> runs the original over the same resource, `snap` running from the state it was set
> aside with; assemble prunes `snap` and its report names it; a changed `single`, an added
> task, an instance moved to another task, a moved output point and a changed tag type are
> each refused at accept, at their line in `plant.logex` or `motor.ld`; and a step on an
> edit that has ended is refused by the generation counter.

(`trip` then runs no instance, a warning, which stops nothing. The candidate's `ons`
moves no output, so it drives no new point, as OE-1's Done-when keeps its own.)

---

## 5. The landing order

OE-2 reserves no word: it adds no syntax to a `.ld` file or a configuration file, and
report kinds are not words of either. **So no survey commit and no `docs/naming.md`
stanza.** Each commit is gated by `mix format` and `mix test --warnings-as-errors` judged
by its exit code, on Elixir 1.20.4, and each rule's test is checked to fail when that rule
alone is reverted, by reverting.

1. **The design record.** `docs/organisation.md` §4.9 gains "OE-2's design" (this
   document's §1–§2, as decided), the one-rule table of §2.6 replacing §4.9's OE-2
   columns, §7 the maintainer's answers to Q1–Q8 as decisions 55 on, and `PLAN.md` OE-2
   its Done-when and landing order.
2. **The per-instance half extracted.** `Logex.Edit.Plan` (internal) takes `retyped/2`,
   `plans/2`, `switch/4`, `prune/3` and the empty record; a plan can be told the started
   program's var_externals, so no start rule starts one (R4). No behaviour change:
   `edit_test.exs`, `function_block_test.exs` and the OE-1 walk unchanged and green; the
   surface test lists the module.
3. **The resource's new state.** `generation` and `aside` in `%Logex.Runtime{}`, their
   rules in the one-rule section; `restart/2` drops `aside`. Tests in `scheduler_test.exs`:
   0 from `start/1`, kept by a cycle and by `restart/2`; the plain-data test.
4. **`Logex.Configuration.Edit`: accept and the stages.** The host mistakes, in order, each
   message pinned; every refusal of §2.2 as a whole diagnostic list from source and from
   data, in `config_edit_test.exs`; cancel from accept; the generation and
   configuration checks.
5. **Kept instances.** One plan per program type and direction; decision 45's merge and
   split; the resource's clock for a resume (Q2); reports by path; `:joined` and `:left`;
   assemble's and cancel's prune by path; decision 49 after every step. A test per rule,
   among them a block type changed for the whole configuration.
6. **Instances added, removed and retyped** (decision 43): set aside, back, pruned; timers
   of an instance back resumed (Q3); `restart/2` during an edit; a retyped instance on
   another task (Q7).
7. **Globals, connections, tasks:** `:added`, `:pruned` and `:initial_changed` for globals
   (decision 44); held globals by the refined "drives" (§2.3); a connection changed read at
   the next scan; decision 40 at test and at untest; priority; the trigger kept, so no
   switch fires an event; order (Q8).
8. **The contract walk.** `api_contract_test.exs` gains a configuration edit walk over the
   configurations it already draws (periodic and event tasks, shared globals, blocks two
   deep), with candidates drawn from every change of §2.1 and §2.2: refusals exactly as
   predicted; the listed writes rebuild the resource; every accepted step made twice; the
   forecast equal to a test taken at once; test then untest with no cycle between leaves
   the resource as it was but for what a switch started; no trigger's sample and no clock
   moved by a step; decision 49 after every step; a stale edit refused; the M2-4 model
   driving each instance through `call/4` alone after assemble. Every property asserts its
   reach. Growth tests in reductions (fix F16): accept and a switch at two numbers of
   instances of one type (linear, one plan), and at two numbers of types.
9. **The Done-when** in `end_to_end_test.exs`, from text and from files on disk.
10. **The documents.** README's "Changing a running plant", its output a real run;
    CLAUDE.md's key files and tests; `Logex.Runtime`'s moduledoc (its "Until OE-2" and
    "is to" sentences, the host's loop); `Logex.Edit`'s "not detected until OE-2"; every
    "until OE-2" in `docs/organisation.md` annotated where it stands; `PLAN.md` status.

---

## 6. The spike, and what it found

Branch `backup/oe2-design`: `lib/logex/configuration/edit.ex` (about 400 lines), three
`@doc false` hooks into `Logex.Edit` and one into `Logex.Runtime`, `generation` and `idle`
on the resource, and `test/logex/config_edit_spike_test.exs`, 13 tests on §4.4's plant
read from `docs/organisation.md`, all green; the full suite fails only the exact
public-surface test, for the hooks (876 of 877 with all 13 probes).

- **The switch builds from OE-1's per-instance switch plus decision 45's merge and split,**
  with no change to the switch's rules. A changed preset in `motor.ld` moved `m1.t1` and
  `m2.t1` by one plan; a block member added to `seal` started as `m1.s1.n` and `m2.s1.n`;
  test, untest, test and assemble round-tripped; the forecast equalled the test's report;
  no instance's state held a var_external after any step.
- **A var_external become a var** kept the global's value as the instance's own; the
  global was untouched, and untest dropped the instance's value and read the global again.
  **A var become a var_external** dropped the instance's value and left the global alone
  (Q1, option a). A var_external added beside a global added was bound, not started.
- **The start rule reports a candidate's var_external as `:added`** before the split, a
  0 the split then drops; the spike filtered those out. Commit 2 should build the plan
  knowing the externals instead (R4).
- **Decision 40** behaved as recorded both ways: `slow` cut from 50 to 20 ms at 10 ms was
  next due at 30, untest kept 30; lengthened to 200 it kept 50.
- **A removed instance** was set aside, its contactor `k2` held at 1 across cycles and
  reported, brought back by untest with its state, and pruned at assemble. A retyped
  instance traded places at test and untest. `restart/2` during a test dropped it, and
  untest started it again.
- **The refusals** for a changed `single`, an added task, a moved point and a moved
  instance came out located at their lines in the plant's text.
- **The generation counter** refused the second of two edits once the first had tested,
  and an assembled edit; cycles moved nothing.
- **The resume clock (Q2):** in a 50 ms task, the instance's own clock left 30 ms to catch
  up; the resource's clock left none.
- **Held points:** "drives" read as connections alone missed a var_output the program no
  longer writes; reading it as connections whose var_output the program writes, plus
  var_external writes, caught `lamp_1`.
- **Not built:** timers of an instance back from aside (Q3), order reports (Q8), the
  configuration check of §1.5, the walk, the growth tests.

---

## 7. Risks, and what to spike before landing

- **R1. The opaque resource is written from a second module.** Keep every write to
  `%Logex.Runtime{}` in `Logex.Runtime` (§1.1), or decision 49's drops can be lost in a
  refactor. Nothing runs dialyzer, so nothing else will catch it.
- **R2. Cost.** Accept builds two plans per program type, a switch is linear in the
  instances' state, the wiring is derived again at each switch, and the configuration
  equality check is linear in the configuration. Growth tests are owed (commit 8); with
  blocks, the state grows as §4.9's "Cost" records, and so will a switch.
- **R3. OE-1's record per instance across slow tasks.** F3's and F4's logic reads
  `switched` and `first` per instance; an instance that does not scan between two switches
  is the common case in a resource, not a corner. The walk must draw slow tasks and test
  then untest with cycles between that scan some instances and not others. **Spike this
  in the walk's first draft before commit 5.**
- **R4. The `:added` var_external.** Filtering reports after the switch is brittle: the
  writes-rebuild property would see a write that was not made. Build it into the plan.
- **R5. Changing an instance's `now` (Q2)** touches OE-1's "`now` is never touched". Check
  every reader of `Instance.now` (the runtime's `scan!` and `scan/2,3`, the edit's resume)
  before landing.
- **R6. Two resources from one configuration** are indistinguishable (§2.5): documented,
  not fixed.
- **R7. Event tasks under a switch.** The last sample is kept, so a switch fires no
  event; but an event task with an interval whose interval changes while its trigger is
  held 1 gets decision 40's `next_due`, which decision 39 then skips while the trigger
  stays 1. The two rules compose, but nothing has run them together: the walk's decision-39
  oracle must run across switches, and a probe of this one case is worth taking first.
- **R8. A candidate that holds two versions of one block** across program types (from
  Elixir data; the loader cannot) is planned per type and works, but the record should say
  that a configuration edit does not enforce one version.
