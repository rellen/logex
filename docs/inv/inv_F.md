# Inventory F: README.md lines 3774 to 4732

Range: "An event task" (3774-3909), "Watchdogs and the continuous task" (3910-4025) and
"Running a plant on the clock" (4026-4732, about 6,800 words, split below into twelve
sections by topic). Line numbers are README.md's as read on 2026-11-15 (5,824 lines).

Type letters: T tutorial, H how-to, R reference, E explanation, C contributor, X drop.

Things that hold for the whole range, said once:

- **The plant.** Every runner example reads `packing.logex` (shown at 3919-3942), which reads
  `conveyor.ld` and `boxes.ld`. Those two files are shown *before* this range ("above", lines
  3776, 3915, 3916). Wherever the runner examples move, `packing.logex`, `conveyor.ld` and
  `boxes.ld` must be shown on (or carried by) the same page, or the harness must learn to find
  them on another page.
- **The harness reads README's prose, not only its blocks.** `test/logex/readme_test.exs`
  holds five pieces of prose in this range, word for word (listed under "Examples" of the
  sections they are in): the two derived-file descriptions (4343-4344, 4414-4415), the
  continuation of `a_trip.exs` (4181), the fragment's sentence (4154-4155) and the "this run's
  figures: " line prefix (4662, 4680, with 4685). Moving or rewording any of them needs the
  matching edit of the test's `@derived`, `@continues`, `@fragments` and `@varies`.
- **No single list of `status/1`'s keys or of the event kinds exists in this range.** They
  are spread over ten bullets. Both are collected in the section "Status, events and
  subscribers" below. `lib/logex/runner.ex`'s doc of `status/1` (about line 1295) has the
  whole list, and two keys README's range never names: `refresh_gap` and `retain`.

---

## An event task (lines 3774-3909, about 930 words)

**Reader and purpose.** A plant author who wants a program to run when a bool global rises
(here: record a contactor's state at the moment the e-stop is pressed), not on a period. They
need the task line's form, exactly when the task fires, and what goes wrong with timers,
counters and one-shots under such a task.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 3776-3777 | Intro: `trip.logex` runs a conveyor on a 10 ms task and `snapshot.ld` on an event task, `trip`, which the e-stop's rising edge makes due | H | howto/use-an-event-task |
| 3779-3785 | `snapshot.ld`: one rung that copies an input to an output | H | howto/use-an-event-task |
| 3787-3808 | `trip.logex`: `task trip single estop priority 0`, five globals, two `program` lines with their connections | H, R | howto/use-an-event-task; reference/configuration-file (the `single` form of a task line) |
| 3810-3813 | What `trip.exs` does (seven steps), and what `timed.logex` and `wrong_trip.logex` are for | H | howto/use-an-event-task |
| 3815-3823 | `debounce.ld`: a `ton` behind an input, used to provoke the warning | H | howto/use-an-event-task |
| 3825-3831 | `timed.logex`: a program with a timer under an event task | H, R | howto/use-an-event-task; reference/diagnostics-and-warnings |
| 3833-3842 | `wrong_trip.logex`: one mistake on each of three task lines | R | reference/diagnostics-and-warnings; reference/configuration-file |
| 3844-3885 | `trip.exs` and its output: seven cycles with which task ran which instance, one warning, three diagnostics | H | howto/use-an-event-task |
| 3887-3893 | When the single is sampled, what makes the task due, the first cycle, `restart/2`, a pulse inside a host step, a trigger logic writes | R, E | reference/execution-model; explanation/tasks-and-scheduling |
| 3894-3898 | The event task's due time; a task with both `single` and `interval`; `next_due_in/1` ignores event tasks | R | reference/execution-model |
| 3899-3906 | The warnings for timers, counters and one-shots under an event task, and why each misbehaves | R, H, E | reference/diagnostics-and-warnings; howto/use-an-event-task (as a "what not to put in it" caveat); explanation/tasks-and-scheduling |
| 3907-3908 | A single must name a bool global; each other case is a diagnostic at the task's line | R | reference/configuration-file; reference/diagnostics-and-warnings |

**Examples.**

- 3779 `<!-- file: snapshot.ld -->` (block 3780-3785): unit "snapshot.ld".
- 3787 `<!-- file: trip.logex -->` (block 3788-3808): unit "trip.logex". Reads `conveyor.ld`,
  shown before this range.
- 3815 `<!-- file: debounce.ld -->` (block 3816-3823): unit "debounce.ld".
- 3825 `<!-- file: timed.logex -->` (block 3826-3831): unit "timed.logex".
- 3833 `<!-- file: wrong_trip.logex -->` (block 3834-3842): unit "wrong_trip.logex".
- 3844 `elixir` block (3844-3870) with 3873 `$ mix run trip.exs` (output block 3872-3885):
  unit "trip.exs and its output". The output's line 3881 quotes `debounce.ld` line 5 and
  `timed.logex` line 3, and lines 3882-3884 quote `wrong_trip.logex` lines 1 to 4, so those
  files must move unchanged with it.
- No `elixir` block without a `$ mix run` in this section.

**Rules stated.**

- 3777, 3791: `task <name> single <global> priority <n>` declares an event task; the rising
  edge of its single makes it due.
- 3837: with both, the order on the line is `single`, then `interval`, then `priority`.
- 3887-3888: a task's `single` is sampled once a cycle, after the inputs are merged and before
  any scan.
- 3888: a sample of 1 after one of 0 makes the task due.
- 3888-3889: it is not due while the trigger is held at 1 (`trip` runs at 20 ms and 60 ms, not
  at 30 or 40).
- 3889-3890: at priority 0 it runs before `c1` (priority 1) in the same cycle, so it reads
  what the cycle before left (`k1_at_trip` is 1 at 20 ms although `k1` goes to 0 in that cycle).
- 3890-3891: the last sample starts at 0, so a trigger already 1 in the first cycle fires.
- 3891-3892: `restart/2` sets the last sample to 0 again.
- 3892: a pulse inside one host step (1 and back to 0 between two cycles) is never seen.
- 3892-3893: a trigger that logic writes fires in the next cycle.
- 3894-3895: an event task's due time is the cycle's `now`, so a late periodic task of the
  same priority runs before it.
- 3895-3896: a task with `interval` too runs at most once a cycle: on an edge, or at its due
  time while the trigger is 0.
- 3896-3897: a due time that comes while the trigger is 1 is skipped and not counted (no
  overlap), and the phase never moves.
- 3897-3898: `next_due_in/1` counts periodic due times only.
- 3898: so a host cycles at once after `start/1` and after `restart/2`, whatever
  `next_due_in/1` says.
- 3859, 3874-3880: a cycle's events hold `{:ran, task, instance, now}` for each run, in run order.
- 3899-3900: a `ton` in a program an event task runs times across the task's runs; only the
  configuration knows that, so the configuration (not the program's compile) warns of each.
- 3900: a block's timer is named by its path.
- 3881: the warning's text, whole: "`d` runs under the event task `trip`, and `debounce` runs
  the timer `t1` on line 5 of `debounce.ld`: a ton times across the task's runs, and one whose
  rung is true on two runs in a row counts the whole time between them".
- 3901: the configuration warns of every other timer too.
- 3901-3902: then of each counter, after the timers; then of each one-shot (`ons`, `osr`,
  `osf`), after the counters.
- 3902-3903: each kind is warned in its own words; a block's one-shot by its storage bit's path.
- 3903-3904: a counter or a one-shot sees its rung only when the task runs, so an edge between
  two runs is never seen.
- 3904-3906: a rung that is the task's trigger is true at every run, so `xic estop osr s1
  pressed` under the e-stop's own event task never pulses.
- 3906: the pulse a coil does set stays on until the task next runs.
- 3907: a single names a bool global.
- 3907-3908: a dint, another kind of name, and no global are each a diagnostic at the task's line.
- 3908: a dotted name is told the reading it has.
- 3882: diagnostic text: "the single of `trip`, `sp`, is a dint (line 4): a single is a bool global".
- 3883: a task with neither is refused: "task `tick` needs an interval or a single, as in
  `task tick interval 10 priority 1` or `task tick single estop priority 0`".
- 3884: `interval 0` is refused: "an interval is at least 1 ms, and a task that runs only on
  the rising edges of its single is declared without one".
- 3866: a configuration's warnings are in `.warnings`, formatted by `Logex.Diagnostic.format/1`.

**Citations.**

- No decision number, plan item or "provisional" mark in this section.
- 3776: "`conveyor.ld`, above" (a file shown before this range).

**Pictures.**

- A timing diagram, 0 to 60 ms in 10 ms cycles: `pb_start_1`, `estop`, `pb_reset`, "trip due",
  `k1`, `k1_at_trip`. It shows the edge at 20 firing once, nothing at 30 and 40 while held, the
  second edge at 60, and `k1_at_trip` holding the value from the cycle before.
- A flowchart of one cycle: merge inputs, sample each single, mark tasks due, run due tasks by
  priority, give outputs. It places "sampled after the inputs are merged and before any scan".
- A small timing diagram for a task with both `single` and `interval`: due times on a grid,
  the one that falls while the trigger is 1 struck out, the grid unmoved.
- A before/after pair for the one-shot caveat: the same `xic estop osr s1 pressed` rung under
  a periodic task (pulses once) and under the e-stop's own event task (never pulses).

**Glossary.**

- **event task**: a task that runs on the rising edge of a bool global, not (only) on a period.
- **single**: the configuration file's word (IEC's `SINGLE`) for the bool global whose rising
  edge makes an event task due.
- **trigger**: the text's other word for the single's global.
- **due**: a task that will run in this cycle.
- **cycle**: one call of `Logex.Runtime.cycle/3`: inputs merged, due tasks run, outputs given.
- **host step**: the time between two cycles the host makes; changes inside it are not seen.
- **phase**: where a periodic task's due times sit on the time line; "never moves" means the
  grid is not shifted by a skipped run.
- **storage bit**: the bool a one-shot keeps its last rung state in.

**Hard to read.**

> So it does of every other timer, of each counter after them, and of each one-shot after those, an `ons`, an `osr` or an `osf`, each in its own words and a block's by its storage bit's path: a counter or a one-shot sees its rung only when the task runs, so an edge between two runs is never seen, and a rung that is the task's trigger is true at every run, so that `xic estop osr s1 pressed` under the e-stop's own event task never pulses; and the pulse a coil does set stays on until the task next runs.
>
> (lines 3899-3906, 102 words)

> With `interval` too, a task runs at most once a cycle: on an edge, or at its due time while the trigger is 0; a due time that comes while it is 1 is skipped and not counted, and the phase never moves.
>
> (lines 3894-3897, 43 words)

> The last sample starts at 0, so a trigger already 1 in the first cycle fires, and `restart/2` sets it to 0 again; a pulse inside one host step is never seen, and a trigger that logic writes fires in the next cycle.
>
> (lines 3890-3893, 43 words)

---

## Watchdogs and the continuous task (lines 3910-4025, about 810 words)

**Reader and purpose.** A plant author who must bound how long a task may run, and who has
programs that should run "as often as possible" instead of on a period. They need the two new
words of the task line (`watchdog`, `continuous`), where task-less programs run, and what an
online edit may change.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 3912-3917 | Each task has a watchdog (500 ms unless set, after its priority); a configuration may declare one continuous task; intro to `packing.logex` | R, H | reference/configuration-file; howto/set-watchdogs |
| 3919-3942 | `packing.logex`: a 10 ms task with `watchdog 50`, `task main continuous watchdog 200`, six located globals, two programs. **The plant every runner example uses** | H, T | howto/set-watchdogs; tutorials/first-plant (must be shown wherever the runner examples go) |
| 3944-3957 | What `packing.exs` does; `wrong_packing.logex`, one mistake on each of four task lines | R | reference/diagnostics-and-warnings; reference/configuration-file |
| 3959-4001 | `packing.exs` and its output: each task's watchdog, six cycles 5 ms apart with which task ran, `next_due_in`, `overlaps`, four diagnostics | H | howto/set-watchdogs |
| 4003-4006 | The continuous task line: its words, their order, what it may not take, where the words are reserved | R | reference/configuration-file |
| 4007-4011 | Where a program with no `with` runs, when, in which order, under which name; never due | R | reference/execution-model |
| 4012-4016 | `Logex.Runtime` reads no clock and so enforces no watchdog; `Logex.Configuration.watchdog/1`; the runner is what times runs against them | R, E | reference/execution-model; explanation/trips-and-watchdogs |
| 4017-4018 | The same task as Elixir data | H, R | howto/build-a-configuration-from-elixir |
| 4019-4024 | What an online edit may and may not change of a watchdog and of the continuous task | R, H | reference/online-edit; howto/edit-a-running-plant |

**Examples.**

- 3919 `<!-- file: packing.logex -->` (block 3920-3942): unit "packing.logex". Reads
  `conveyor.ld` and `boxes.ld`, both shown before this range. Read again by the five runner
  scripts below, and the source of the derived `warm/packing.logex` and `faster/packing.logex`.
- 3947 `<!-- file: wrong_packing.logex -->` (block 3948-3957): unit "wrong_packing.logex".
- 3959 `elixir` block (3959-3984) with 3987 `$ mix run packing.exs` (output block 3986-4001):
  unit "packing.exs and its output". Lines 3997-4000 quote `wrong_packing.logex` by line and
  column.
- No `elixir` block without a `$ mix run` in this section.

**Rules stated.**

- 3912: each task has a watchdog: the longest a run of it may take.
- 3912-3913: it is 500 ms unless the task's line sets one, after its priority.
- 3913-3914: a configuration may declare its one continuous task, which runs every program
  instance with no timed task.
- 3922: form `task fast interval 10 priority 1 watchdog 50`.
- 3923: form `task main continuous watchdog 200`.
- 3961, 4013-4014: `Logex.Configuration.watchdog/1` gives a task's watchdog in ms, 500 where
  its line sets none.
- 3997: a watchdog is at least 1 ms: "the watchdog of `fast` is 0: a watchdog is at least 1 ms,
  and a task that sets none has 500".
- 3998: the continuous task takes no `priority`: "`main` is the continuous task, which takes no
  `priority`: it runs every program instance with no timed task, after the due tasks, as in
  `task main continuous watchdog 200`".
- 3999: a second continuous task is refused, the first named with its line.
- 4000: `priority` goes before `watchdog`; this diagnostic carries a column ("line 4, column 36").
- 4003: `task main continuous` declares the continuous task; `watchdog` sets its time.
- 4003-4004: it takes no `interval`, no `single` and no `priority`.
- 4004: a configuration has one continuous task at most.
- 4004-4005: `continuous` comes straight after the name.
- 4005: `watchdog` comes last, after IEC's three (`interval`, `single`, `priority`).
- 4005-4006: `continuous` and `watchdog` are reserved in a configuration file only, in any
  case, as `single` is.
- 4007: `program b1 boxes`, with no `with`, runs in the continuous task.
- 4007-4008: `program b1 boxes with main` means the same.
- 4008-4009: the continuous task's instances run after every due task, once a cycle, in the
  order of the `program` lines (where task-less instances ran before the line existed).
- 4009-4010: each run is reported under the task's name (`main:b1`, that is `{:ran, "main",
  "b1", now}`); in a configuration with no continuous line the task is `:none`.
- 4010: the continuous task is never due.
- 4010-4011: `next_due_in/1` counts only the timed tasks.
- 4011: `overlaps/1` lists the continuous task, at 0.
- 3995: `next_due_in/1` straight after `start/1` is 0.
- 4012: `Logex.Runtime` reads no clock and so no watchdog: a cycle runs the same whatever the
  watchdogs.
- 4014-4016: the runner times a timed task's run, and each round of the continuous task,
  against the watchdogs, and trips on one that outlasts its watchdog.
- 4017-4018: from Elixir data: `%Logex.Configuration.Task{name: "main", continuous: true,
  watchdog: 200}`, checked in the same words as the file's line.
- 4019-4021: an online edit may change a watchdog while the plant runs; it is reported
  `{:watchdog, "fast", {50, 30}}` (old, new); an interval and a priority may change too.
- 4021: `with main` added or taken away moves nothing (no change).
- 4021-4022: the continuous line moved among the task lines is no change: it has no order.
- 4023: the continuous line added or removed is refused until a restart.
- 4023: a task made continuous, or a continuous task made timed, is refused until a restart.
- 4023-4024: an instance moved between a timed task and the continuous one is refused until a
  restart.

**Citations.**

- 3914-3915: link `docs/organisation.md` §4.11; decisions 109 to 111.
- 3915, 3916: "`conveyor.ld`, above", "`boxes.ld`, above".
- 4014: "`Logex.Runner`, "Running a plant on the clock", below".
- 4019: "`Logex.Configuration.Edit`, "A running plant", below" (README line 5494).
- 4021: decision 129.

**Pictures.**

- A syntax (railroad) diagram of the two forms of a task line: `task NAME [single G]
  [interval N] priority N [watchdog N]` and `task NAME continuous [watchdog N]`. It replaces
  four sentences about word order.
- A table of the six cycles (t = 0, 5, ..., 25): which tasks were due, which instances ran, in
  which order. It shows `fast` every 10 ms and `main` in every cycle, after `fast`.
- A table "what an online edit may change of a task": rows watchdog, interval, priority,
  `with main` added, continuous line moved, continuous line added or removed, task made
  continuous or timed, instance moved to or from the continuous task; columns allowed / refused
  until a restart / report.

**Glossary.**

- **watchdog**: the longest one run of a task may take, in ms; the runner trips the plant when
  a run outlasts it.
- **continuous task**: the one task with no period and no trigger; it runs, once a cycle and
  after the due tasks, every program instance that names no timed task.
- **timed task**: a task with an `interval`, a `single`, or both.
- **untimed program / task-less instance**: a program instance with no `with`, or `with` the
  continuous task.
- **IEC's three**: `interval`, `single`, `priority`, the three task inputs IEC 61131-3 names.

**Hard to read.**

> An online edit (`Logex.Configuration.Edit`, "A running plant", below) may change a watchdog while the plant runs, reported `{:watchdog, "fast", {50, 30}}`, as an interval and a priority may (decision 129); `with main` added or taken away moves nothing, and so does the continuous line moved among the task lines, which is no order; the continuous line added or removed, a task made continuous or timed, and an instance moved between a timed task and the continuous one are refused until a restart.
>
> (lines 4019-4024, 82 words)

> `Logex.Runtime` reads no clock and so no watchdog: a cycle runs as it did whatever the watchdogs, and `Logex.Configuration.watchdog/1` gives each task's, 500 where its line sets none, for the runner (`Logex.Runner`, "Running a plant on the clock", below), which times a timed task's run and each round of the continuous task against them, and trips on one that outlasts its watchdog.
>
> (lines 4012-4016, 62 words)

> Each task has a watchdog, the longest a run of it may take, 500 ms unless its line sets one after its priority, and a configuration may declare its one continuous task, which runs every program instance with no timed task ([`docs/organisation.md`](docs/organisation.md) §4.11, decisions 109 to 111).
>
> (lines 3912-3915, 47 words)

---

# "Running a plant on the clock" (lines 4026-4732, about 6,800 words), in twelve sections

The README section has one heading and no sub-headings. Its structure is: a paragraph, an
example, a bullet list; four times over (first run, trip, warm trip, forcing and edit), then
the real clock. The bullets mix topics, so some sections below take line ranges that are not
contiguous.

## Running a plant on the clock: what the runner is, and a first run (lines 4026-4099, about 370 words)

**Reader and purpose.** A host developer who has a compiled configuration and wants it to run
by itself, on time, against devices. This is the first sight of `Logex.Runner`, the manual
clock and the simulated device, and the first complete script.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4028-4031 | What the runner is: runs a configuration's resource on a clock through devices; each device bound by name to an adapter, in a process of its own; one adapter shipped, `Logex.IO.Sim` | E, R | howto/run-on-the-clock (lead); reference/runner; reference/io-adapters |
| 4031-4033 | The manual clock: a run is deterministic and repeats exactly; time moves only when the test moves it | H, R | howto/test-on-the-manual-clock NEW (a host's own tests of a plant need the manual clock, the sim and the "call from another process" pattern; no page holds that task); reference/runner (`clock:`) |
| 4033-4035 | What `on_the_clock.exs` does | T, H | tutorials/first-plant; howto/run-on-the-clock |
| 4037-4083 | `on_the_clock.exs`: start a clock, a sim and a runner; read status; set inputs; advance the clock; subscribe to `:ran`; stop | T, H | tutorials/first-plant; howto/run-on-the-clock |
| 4085-4099 | Its output: four status lines, the conveyor's run at 30, `runs` / `overlaps` / `latest_wake`, the last two writes, `closed: true` | T, H | tutorials/first-plant; howto/run-on-the-clock |

**Examples.**

- 4037 `elixir` block (4037-4083) with 4086 `$ mix run on_the_clock.exs` (output block
  4085-4099): unit "on_the_clock.exs". Reads `packing.logex` (3919), `conveyor.ld` and
  `boxes.ld`. Two later blocks depend on this one: `a_trip.exs` takes its first lines as its
  setup, and the fragment at 4163 runs "as" a continuation of it.
- No file-marked block and no fragment in this section.

**Rules stated.**

- 4028-4029: `Logex.Runner` runs a configuration's resource on a clock, through the devices its
  points are at.
- 4029-4030: each device is bound by name to an adapter (`Logex.IO`).
- 4030: each device runs in a process of its own.
- 4030-4031: logex ships one adapter, `Logex.IO.Sim`, an in-memory device a test sets and reads.
- 4031-4033: with `Logex.Runner.Clock.Manual` a run is deterministic and repeats exactly: time
  moves only when the test moves it.
- 4043-4051: the calls: `Manual.start_link()`; `Sim.start_link(reports: true, clock: clock)`;
  `Runner.start_link(configuration: plant, io: %{"panel" => {Sim, sim: panel}}, clock:
  {Manual, clock})`. `io:` maps a device's name to `{adapter, options}`.
- 4054: `Runner.status/1` gives a map; `now` and `rounds` are two of its keys.
- 4055, 4097: `Sim.outputs/1` and `Sim.writes/1` are keyed by address (`"panel.q.0"`).
- 4056: `Runner.get!(runner, "b1.count")` reads a value of the resource by name.
- 4060 (comment): a reporting sim's `set` is "reported and merged at once".
- 4061 (comment): `Manual.advance(clock, 10)` runs "a round each millisecond".
- 4073, 4077: `Runner.subscribe(runner, [:ran])`; an event arrives in the subscriber's mailbox
  as `{Logex.Runner, runner, event}`, here `{:ran, "fast", instance, at}`.
- 4087: straight after `start_link/1`, `now` is 0 and `rounds` is 1 (the first round has run).
- 4088-4090: with an untimed program, `rounds` is `now + 1`.
- 4093: `runs` is `%{task => {longest_ms, watchdog_ms}}`.
- 4095: `latest_wake` is 0 on the manual clock.
- 4097: the write before `stop/2`'s holds the last round's outputs; `stop/2`'s write is all 0.
- 4098: `Sim.closed?/1` is true after `stop/2`.

**Citations.**

- 4029: `docs/organisation.md` §4.11, decisions 108 to 143; `PLAN.md`'s Milestone 4.
- 4033: "`packing.logex`, above".

**Pictures.**

- A block diagram: the host process, the runner (a GenServer), the resource inside it, one
  process per device, the adapter, the clock. Arrows for "read", "report", "write", "status".
  This is the picture a newcomer needs before any rule.
- A timeline of the script, 0 to 32 ms: the four `show` points, the three boxes, the e-stop
  set at 22 and read at 30.

**Glossary.**

- **runner**: `Logex.Runner`, the process that runs a resource on a clock and through devices.
- **resource**: a started configuration (`%Logex.Runtime{}`): its tasks, globals and instances.
- **device**: a named piece of I/O hardware the configuration's `at` addresses name
  (`panel.i.7` is point `i.7` of device `panel`).
- **adapter**: a module with the `Logex.IO` behaviour that reads and writes one device.
- **bound**: a device's name paired with an adapter and its options in `io:`.
- **manual clock**: `Logex.Runner.Clock.Manual`, a clock a test moves with `advance/2`.
- **sim**: `Logex.IO.Sim`, the in-memory device.
- **round**: one pass of the runner: inputs taken, a cycle run, outputs written (first used at
  4054; never defined in the range).

**Hard to read.**

> `Logex.Runner` runs a configuration's resource on a clock, through the devices its points are at (`docs/organisation.md` §4.11, decisions 108 to 143; `PLAN.md`'s Milestone 4).
>
> (lines 4028-4029, 24 words)

---

## Starting a runner: `start_link/1` and its options (lines 4101-4112, about 170 words)

**Reader and purpose.** A host developer writing the `start_link` call or a child spec, who
needs every option, its default and its unit.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4101-4102 | Every option is checked in the caller, so a host's mistake is an `ArgumentError` there | R | reference/runner; reference/host-contract |
| 4102-4103 | A start opens each device, reads it once and runs the first round at once | R | reference/runner; reference/execution-model |
| 4103-4112 | The optional options with their defaults: `clock:`, `poll:`, `overhead:`, `idle:`, `write_limit:`, `open:`, `forces:`, `name:` | R | reference/runner (an options table) |
| 4107-4111 | Why `write_limit:` and `open:` are limits of their own, apart from the heartbeat (a drive that takes 600 ms to connect) | E | explanation/trips-and-watchdogs |

**Examples.** None (the options are shown in use at 4046-4051, 4429-4435 and 4637).

**Rules stated.**

- 4101: `start_link/1` checks every option in the caller, the configuration and the bindings
  among them.
- 4101-4102: so a host's mistake is an `ArgumentError` in the caller, not a crash of the runner.
- 4102-4103: it opens each device, reads it once, and runs the first round at once.
- 4047-4049 (by example): `configuration:` and `io:` are given; the text calls the rest "Optional".
- 4103-4104: `clock:`: the monotonic clock unless set.
- 4104: `poll:`: each device's poll period, default 10 ms.
- 4104-4105: `overhead:`: the share kept for the runner's own work, default 20 (percent),
  allowed 10 to 90.
- 4105: `idle:`: default 500 ms (not explained here; it is the watchdog of the runner's own
  work and waits, 4225-4226 and 4308-4310).
- 4105-4107: `write_limit:`: how long each write or read of the runner's files may take in real
  time, default 5000 ms; a limit of its own, apart from the heartbeat.
- 4107-4108: `open:`: how long each device's opening (its adapter's `init/3` and first read)
  may take in real time, default 5000 ms.
- 4108-4109: `open:` is one number for every device, or a map by device name: `open: %{"drive"
  => 2000}`.
- 4109-4110: so a drive whose connect takes 600 ms opens with the heartbeat left as it is.
- 4110-4111: `open:` is also how long a restart's read of each device may take, a device that
  stayed up included.
- 4111-4112: `forces:`: the file the forces are kept in.
- 4112: `name:`.
- Not said here: `retain:` (the store) is a `start_link/1` option too; README gives it in "The
  store on disk" (line 3367), outside this range. The options table needs both.

**Citations.**

- 4107: decision 400. 4110: decision 398. 4111: decision 439.

**Pictures.**

- A table of options: name, meaning, unit, default, allowed range, "read by" (start, restart,
  every round). No drawing needed.

**Glossary.**

- **poll period**: how often each device is read, and its last outputs written again.
- **overhead / the share**: the part of the runner's time kept for the host's requests.
- **idle (watchdog)**: the longest the runner's own work, or a wait, may take.
- **heartbeat**: the deadline the runner gives a device at each refresh; a device that hears
  nothing by then latches itself (4229-4232).
- **write limit**: the longest one file call of the runner may take, in real time.

**Hard to read.**

> Optional: `clock:` (the monotonic one unless set), `poll:` (each device's poll period, 10 ms), `overhead:` (the share kept for the runner's own work, 20%, 10 to 90), `idle:` (500 ms), `write_limit:` (how long each write or read of its files may take in real time, 5000 ms, a limit of its own apart from the heartbeat, decision 400), `open:` (how long each device's opening, its adapter's `init/3` and first read, may take in real time, 5000 ms, for every device or by name, `open: %{"drive" => 2000}`, so a drive whose connect takes 600 ms opens with the heartbeat left as it is, decision 398, and how long a restart's read of each device may take, one that stayed up among them, decision 439), `forces:` (the file its forces are kept in, below) and `name:`.
>
> (lines 4103-4112, 135 words)

---

## A round: when rounds come (lines 4113-4116 and 4126-4127, about 90 words)

**Reader and purpose.** Anyone who must predict when logic runs: how often a round comes, and
when an input a device reports reaches a program.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4113-4114 | With an untimed program, rounds run back to back, one each clock millisecond | R, E | reference/execution-model; explanation/scan-cycle-and-time |
| 4114-4116 | With no untimed program, a round comes only at a due time, or at once when a device changes an event task's trigger | R | reference/execution-model |
| 4116 | Due times are absolute on the runner's clock, so they never drift | R, E | reference/execution-model; explanation/tasks-and-scheduling |
| 4126-4127 | An input that is no trigger is merged when reported but reaches a program only at its task's next run (the e-stop merged at 22, read at 30) | E, T | explanation/scan-cycle-and-time; tutorials/first-plant (it explains the tutorial's output) |

**Examples.** None of its own; the text explains `on_the_clock.exs` (4037).

**Rules stated.**

- 4113: a program in the continuous task ("untimed") makes rounds run back to back.
- 4113-4114: back to back means one round each clock millisecond, no more.
- 4114: `advance(clock, 10)` ran ten rounds, the 10 ms task in the one at 10.
- 4114-4116: with no untimed program a round comes only at a due time, or when a device
  changes an event task's trigger, and then at once.
- 4116: due times are absolute on the runner's clock, so they never drift.
- 4126-4127: an input that is no trigger is merged when its device reports it and is read by a
  program at that program's task's next run.
- 4127: the conveyor "latched its fault and stopped" on reading the e-stop (behaviour of
  `conveyor.ld`, shown before the range).

**Citations.** None.

**Pictures.**

- A timing diagram on a 1 ms grid, 20 to 32 ms: rounds as ticks, `fast`'s runs at 20 and 30,
  the e-stop's change at 22, `k1` falling at 30. It shows "merged at 22, read at 30" at a glance.
- A two-row comparison: a plant with an untimed program (a tick every millisecond) and one
  without (ticks only at due times and at trigger changes).

**Glossary.**

- **back to back**: each round follows the last with no wait, held to one a clock millisecond.
- **merged**: a device's reported value taken into the resource's input image.
- **drift**: due times sliding later because each is counted from the last run; logex counts
  each from the start, so they do not.

**Hard to read.**

> With no untimed program a round comes only at a due time or when a device changes an event task's trigger, at once.
>
> (lines 4114-4116, 23 words)

---

## Device reads and writes (lines 4117-4125 and 4128-4132, about 200 words)

**Reader and purpose.** A host developer who wires a device, or writes an adapter, and needs
to know when it is read, when it is written, and what the runner does for a device that
switches off when its master goes quiet. Also a test author using the sim.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4117-4119 | A reporting device's change is a call, answered once merged; for a trigger, once its round has run and written. So `Sim.set/3` returns after that round | R | reference/io-adapters; reference/runner |
| 4119-4120 | Each device is also read every poll period, and written where its outputs changed | R | reference/runner; reference/io-adapters |
| 4120-4125 | At every poll a device writes its last outputs again (a fixed timer, as Logix re-sends at the RPI); why; its cost; a device with no output point is written nothing | R, E | reference/runner; explanation/trips-and-watchdogs (why outputs are re-sent); howto/write-a-device-adapter |
| 4128-4132 | The sim's addresses: once a runner has opened it, set and read at the configuration's addresses; before that, by the adapter's list (`[8]`) | R, H | reference/io-adapters; howto/test-on-the-manual-clock NEW |

**Examples.** None of its own; the text explains `on_the_clock.exs` (4037).

**Rules stated.**

- 4117-4118: a device that reports passes each change on by a call, which the runner answers
  once it has merged the change.
- 4118-4119: for a change of an event task's trigger, the call is answered once the round it
  makes has run and its outputs are written.
- 4119: so `Logex.IO.Sim.set/3` (of a trigger) returns after that round.
- 4119-4120: each device is also read every poll period.
- 4120: a device is written where its outputs changed.
- 4120-4122: at every poll a device writes its last outputs again, whether or not a round wrote
  to it within the period; the timer is fixed, as Logix re-sends outputs at the RPI.
- 4122-4123: so a drive that turns its outputs off when its master goes quiet never does while
  the runner is well.
- 4123-4124: the cost is one write a device a poll period, beside each round's write.
- 4124-4125: a device never written (one with no output point among them) is written nothing
  at a poll.
- 4128-4129: once a runner has opened it, a sim is set and read at the configuration's
  addresses (`set(panel, "panel.i.8", 1)`).
- 4130: `Sim.outputs/1` and `Sim.writes/1` give values under the configuration's addresses
  (`"panel.q.4"`).
- 4130-4132: a sim no runner has opened knows no device's name, and is set by the adapter's
  list, `[8]`.

**Citations.**

- 4122: decision 130. 4131-4132: decisions 517 (e) and 529.

**Pictures.**

- A sequence diagram: device process, runner, resource. Three cases side by side: (a) a
  reported change of a plain input (call, merge, answer); (b) a reported change of a trigger
  (call, merge, round, write, answer); (c) a poll (read, then the last outputs written again).
- A timing diagram of one output against the poll grid: the round's write, then the same
  value written again at each poll.

**Glossary.**

- **reports**: a device that tells the runner of each input change itself, without waiting to
  be polled (`Sim.start_link(reports: true)`).
- **poll**: the periodic read of a device, with the re-write of its last outputs.
- **RPI**: requested packet interval, the period at which a Rockwell Logix controller re-sends
  a module's outputs (the text uses it without expanding it).
- **master**: the controller a drive expects to hear from; here, the runner.
- **the adapter's list**: the point numbers an adapter is given before any runner tells it the
  device's name.

**Hard to read.**

> Each device is also read every poll period, and written where its outputs changed; and at every poll it writes its last outputs again, whether or not a round wrote to it within the period, a fixed timer, as Logix re-sends outputs at the RPI (decision 130): so a drive that turns its outputs off when its master goes quiet never does while the runner is well, at the cost of one write a device a poll period beside each round's.
>
> (lines 4119-4124, 81 words)

> A device that reports passes each change on by a call the runner answers once it has merged it, and, for a trigger, once the round it makes has run and its outputs are written: so `Logex.IO.Sim.set/3` returns after that round.
>
> (lines 4117-4119, 41 words)

---

## Status, events and subscribers, and `stop/2` (lines 4133-4141, about 110 words, with keys and kinds scattered to line 4700)

**Reader and purpose.** A host developer building an HMI, a log or a supervisor around a
runner: what `status/1` holds, what `subscribe/2` sends, how to read a value, how to stop.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4133-4134 | `status/1` gives each task's longest run against its watchdog (0 on a clock that does not move inside a round); `get/2` reads the resource | R | reference/runner |
| 4134-4140 | `subscribe/2`: the resource's events, `{:round, now, outputs}`, and by default `{:retain, {:error, reason}}`, `{:retain, {:warning, message}}` and `{:forces, {:error, reason}}` | R | reference/runner (an events table); howto/watch-a-runner NEW (an HMI or a log that follows a runner is a task of its own: subscribe, match the message, poll status; no page holds it) |
| 4140-4141 | `stop/2` writes every output 0 once and closes every device before it returns | R, H | reference/runner; howto/run-on-the-clock |
| scattered | The keys of `status/1` and the event kinds, each first named somewhere else in the range (collected under "Rules stated") | R | reference/runner |

**Examples.** None of its own. `subscribe` is used at 4073 (`[:ran]`), 4185 (no list), 4472
(`[:edit]`) and 4478 (`[:ran]`); `status/1` in every runner script.

**Rules stated.**

- 4133-4134: `status/1` gives each task's longest run against its watchdog.
- 4134: that figure is `0` on a clock that does not move inside a round (the manual clock).
- 4134: `get/2` reads the resource (`get!/2` is what every example uses).
- 4134-4135: `subscribe/2` sends the resource's events and the runner's `{:round, now, outputs}`.
- 4135-4136: by default it sends a store's write that failed, `{:retain, {:error, reason}}`.
- 4136-4138: and a fresh start's warning that its store was written by another program,
  `{:retain, {:warning, message}}`, sent as a subscription takes `:retain`.
- 4138-4140: and a forces file's write, made by an orderly end, that failed: `{:forces,
  {:error, reason}}`; a kind of its own; sent by default.
- 4140-4141: `stop/2` writes every output 0 once and closes every device before it returns.
- `status/1`'s keys named in the range, with the line of first use or definition:
  `status` (`:running` or `:tripped`, 4212, 4217); `trip` (the reason, nil while running,
  4212, 4217); `now` (4054); `rounds` (4054); `runs` (4078, 4093, 4133, 4699); `overlaps`
  (4078, 4094); `latest_wake` (4078, 4270, 4700); `unzeroed` (4302); `forces` (4443, 4524);
  `forces_unknown` (4518); `forcing` (4525); `forces_unread` (4573); `edit` (`:testing`, nil,
  4477, 4498, 4501).
- "The key always there": `forces_unknown` (4520), `forcing` (4526), `forces_unread` (4575).
- Event kinds named in the range: `{:ran, task, instance, at}` (4077, 4480); `{:round, now,
  outputs}` (4135, 4251); `{:trip, reason}` (4180, 4213); `{:overlap, task, missed}` (4697);
  `{:retain, {:error, reason}}` and `{:retain, {:warning, message}}` (4136-4137); `{:forces,
  {:error, reason}}` (4139, 4588).
- Subscription kinds used: `[:ran]` (4073), `[:edit]` (4472), `:retain` (4138), none given
  (`subscribe(runner)`, 4185).
- 4077: a subscriber receives `{Logex.Runner, runner_pid, event}`.
- 4197 (comment): a `status/1` call made while a trip is under way is "answered once the
  runner has tripped".

**Citations.**

- 4138: decision 528, "below". 4139: decision 493, "below". 4140: decision 507.

**Pictures.**

- Two tables, no drawing: (1) `status/1`'s keys: key, value's shape, nil or empty when, the
  line that explains it; (2) events: shape, when sent, sent by default or only when asked for.
  These two tables are the largest single gain for a reader of this range.

**Glossary.**

- **subscriber**: a process that asked the runner for its events.
- **event**: a message `{Logex.Runner, runner, event}` the runner sends its subscribers.
- **orderly end**: `stop/2` or a supervisor's shutdown, as against a crash or a kill.
- **the store**: the file retained values are kept in (README's "The store on disk").

**Hard to read.**

> `status/1` gives each task's longest run against its watchdog, `0` on a clock that does not move inside a round; `get/2` reads the resource; `subscribe/2` sends the resource's events and the runner's `{:round, now, outputs}`, and by default a store's write that failed, `{:retain, {:error, reason}}`, a fresh start's warning that its store was written by another program, `{:retain, {:warning, message}}`, sent as a subscription takes `:retain` (decision 528, below), and a forces file's write an orderly end made that failed, `{:forces, {:error, reason}}` (decision 493, below; a kind of its own, by default, decision 507); and `stop/2` writes every output 0 once and closes every device before it returns.
>
> (lines 4133-4141, 110 words)

---

## Calls that wait: the share and its slots (lines 4142-4176, about 345 words)

**Reader and purpose.** Two readers. An HMI author who asks "can my polling slow the plant,
and how long may my call wait?". A test author on the manual clock whose call never returns
because the same process must also move the clock.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4142-4143 | The share is served in slots: at 20%, after each 4 ms of rounds that fill their milliseconds, up to 1 ms of the host's requests | R, E | reference/runner; explanation/tasks-and-scheduling |
| 4143-4148 | With no untimed program the share holds against a due periodic round too: a tight-looping HMI holds a due round back by one request, or by its slot, never for as long as it polls | R, E | reference/runner; explanation/tasks-and-scheduling |
| 4148-4152 | A slot that finds nothing waiting stays open until a request takes it; requests are still held to one a slot | R | reference/runner |
| 4152-4159 | On the manual clock: a request is served before the next round, unless a round is owed after one that passed time; then it waits for its slot, in the advance that brings it | R, H | reference/runner; howto/test-on-the-manual-clock NEW |
| 4159-4176 | The pattern: call from another process (`Task.async`) and move the clock with `advance(clock, 0)` until the call is answered; the fragment | H | howto/test-on-the-manual-clock NEW |
| 4143-4159 (parentheses) | "where it was served every other one", "where ..." asides that tell what the behaviour was before decisions 396, 442, 444 | X, C | drop from user docs; adr or contributor/runner-internals if kept |

**Examples.**

- 4163 `elixir` block (4163-4176), indented two spaces inside the bullet, **no `$ mix run`
  after it**: a fragment. `readme_test.exs` names it in `@fragments` by its first line (`task
  = Task.async(fn -> Runner.get!(runner, "b1.count") end)`), runs it after a setup of its own
  (`@owed`: `on_the_clock.exs`'s plant with `Sim.fail(panel, :write, {:delay, 2})`), and
  checks it printed "b1.count waited, then answered 0 after 1 to 4 owed rounds". The test also
  searches README for these words, which must stay with the fragment: "One made while a round
  is owed, after a round that passed time, a slow drive's write, waits for its slot"
  (4154-4155, with README's line break and two-space indent). It needs `packing.logex`,
  `conveyor.ld` and `boxes.ld`.

**Rules stated.**

- 4142: the share (`overhead:`) is served in slots.
- 4142-4143: at 20%: at the end of each 4 ms of rounds that fill their milliseconds, up to
  1 ms of the host's requests is served.
- 4143-4144: with no untimed program the share holds against a due periodic round too.
- 4144-4145: a request that comes while a round is due waits for that round.
- 4145-4146: it is served after the round while no round is due, or in the slot after 4 ms of
  rounds where rounds outrun their periods.
- 4146-4148: so an HMI polling `status/1` in a tight loop holds a due round back by the request
  in hand at most, or by its slot; never for as long as it polls.
- 4148-4149: a slot that finds nothing waiting stays open until a request takes it.
- 4149-4152: so an HMI that polls one call at a time is served at once as its call comes, after
  every round that brings a slot.
- 4152: the share still holds requests to one a slot.
- 4152-4154: on the manual clock a round takes no time unless something passes time inside it,
  so a request is served before the next round.
- 4154-4155: a request made while a round is owed, after a round that passed time (a slow
  drive's write), waits for its slot, as on the real clock.
- 4156-4158: it is answered in the advance that runs the round completing those 4 ms; or, with
  no untimed program, in the advance that runs the round due; `advance(clock, 0)` counts as
  such an advance; never later.
- 4158-4159: unless a slot left open takes it at once.
- 4159-4161: so a test that would call from the process that moves the clock must call from
  another process, and move the clock on until the call is answered.
- 4171 (comment): `advance(clock, 0)` runs one owed round; at most 4 bring the slot.

**Citations.**

- 4144: decision 396. 4149: decision 442. 4156: decision 131. 4158: decision 444. 4159:
  decision 442. "the conventional table's" (4142) cites nothing; see "Hard to read".

**Pictures.**

- A timing diagram on a 1 ms grid: four rounds, then a slot of up to 1 ms, repeated. A second
  row for a plant with no untimed program: a due round, a request arriving while it is due,
  served straight after it.
- A sequence diagram for the test pattern: test process, a `Task`, the runner, the manual
  clock. The task's call waits; the test advances by 0; the round runs; the slot comes; the
  call is answered.

**Glossary.**

- **the share**: the part of the runner's time given to host requests (`overhead:`, 20%).
- **slot**: the moment, after a run of rounds, at which waiting requests are served.
- **owed round**: a round whose time has come but which has not run yet.
- **HMI**: human-machine interface, the operator's screen; here any process that polls
  `status/1`.
- **"rounds that fill their milliseconds"**: back-to-back rounds, one each millisecond.

**Hard to read.**

> One made while a round is owed, after a round that passed time, a slow drive's write, waits for its slot, as on the real clock (decision 131): it comes in the advance that runs the round completing those 4 ms, or with no untimed program in the advance that runs the round due, `advance(clock, 0)` among them, and never later (decision 444), unless a slot left open takes it at once (decision 442).
>
> (lines 4154-4159, 74 words)

> With no untimed program the share holds against a due periodic round too (decision 396): a request that comes while one is due waits for it, and is served after it while no round is due, or in the slot after 4 ms of rounds where they outrun their periods, so that an HMI polling `status/1` in a tight loop holds a due round back by the request in hand at most, or by its slot, never for as long as it polls.
>
> (lines 4143-4148, 83 words)

"The share is served in slots, the conventional table's: at 20%, at the end of each 4 ms of
rounds that fill their milliseconds, up to 1 ms of the host's requests." (4142-4143; "the
conventional table's" refers to nothing a reader has seen.)

---

## The trip: its one path and its reasons (lines 4178-4256, about 790 words)

**Reader and purpose.** An operator or host developer who sees `status: :tripped` and must
know what the plant was left in and what the reason tuple means. Also anyone deciding whether
logex's failure behaviour is acceptable for their plant.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4178-4181 | A trip has one path, whatever caused it: stop scheduling, write every output 0 once, latch, send `{:trip, reason}`, keep the resource for `get/2`, wait for `restart/2` | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4181-4219 | `a_trip.exs` and its output: a read that fails at the poll at 20, the trip's status and event, `k1` 1 in the resource and 0 at the panel, nothing running while tripped, a cold restart | H | howto/restart-after-a-trip; explanation/trips-and-watchdogs (as its worked case) |
| 4221-4254 | The list of reasons: five watchdog reasons, `{:io, ...}` with its causes, `{:fault, ...}`, two `{:clock, ...}`, `{:internal, message}` | R | reference/runner (a table of trip reasons); reference/faults (for `{:fault, ...}`) |
| 4242-4253 | Inside the list: what a bad clock reading leaves written, case by case, and which `{:round, ...}` event is published | R, C | reference/runner; contributor/runner-internals |
| 4228-4229, 4232, 4240, 4242-4243, 4246 | "since decision 490", "since M5-9", "since decision 394", "since decision 441", "where it was `{:watchdog, {:idle, ms}}`": when each reason appeared or changed | X | drop (history; `docs/organisation.md` §7 has it) |
| 4254-4256 | Device notices that waited are taken in the order raised, ties in device-name order, so a manual-clock run trips for the same reason every time | R, C | reference/runner; contributor/runner-internals |

**Examples.**

- 4184 `elixir` block (4184-4208) with 4211 `$ mix run a_trip.exs` (output block 4210-4219):
  unit "a_trip.exs". **The block is not the whole script**: it starts at `:ok =
  Runner.subscribe(runner)`. `readme_test.exs`'s `@continues` builds the script by putting
  `on_the_clock.exs`'s lines up to `show = fn label` in front, and requires README to hold the
  words "`a_trip.exs` runs the same plant" (4181). `examples/a_trip.exs` holds the whole script.
  If this block moves to another page than `on_the_clock.exs`, either show the whole script or
  teach the harness the new place of its setup.

**Rules stated.**

- 4178: a trip has one path, whatever caused it.
- 4179: the runner stops scheduling.
- 4179: it writes every output 0, once, through each device that answers.
- 4180: each device latches and writes nothing more.
- 4180: the runner sends `{:trip, reason}` to its subscribers.
- 4180-4181: it keeps the resource for `get/2`.
- 4181: it waits for `restart/2`.
- 4195 (comment), 4212: `Sim.fail(panel, :read, {:error, :eio})` makes the next read (the poll
  at 20) fail; the trip is `{:io, "panel", {:error, :eio}}`.
- 4212: after the trip `status` is `:tripped`, `trip` the reason, `now` 19, `rounds` 20: the
  round at 20, which tripped, is not counted and its time not taken.
- 4202-4203, 4216: while tripped nothing runs and nothing is written; `now` and `rounds` stand
  still though the clock moves on 1000 ms.
- 4205-4206, 4217: `restart(runner, :cold)` answers `:ok`; `status` is `:running`, `trip` nil,
  `now` still 19, `rounds` 21.
- 4221-4222: `{:watchdog, {:task, task, took_ms, limit_ms}}`: a timed task's run longer than
  its line's `watchdog`.
- 4222-4223: `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`: a round of the continuous
  task longer than its watchdog.
- 4223-4225: that round is counted from the inputs taken to its last program's scan, the timed
  tasks' runs in it included; each step is named with its time, so the slow one is seen.
- 4225-4226: `{:watchdog, {:idle, ms, work}}`: the runner's own work that took longer than
  `idle:`, the work named.
- 4226-4228: `work` is: a host's request, named by the function called, `:status` or `:get`;
  an edit's step, `{:edit, :test}`; the period's hand-off to the store's writer, `:period`.
- 4229-4232: `{:watchdog, {:device, device, ms}}`: a device that heard nothing from the runner
  by the deadline its last refresh carried, and so latched itself; `ms` is the heartbeat that
  refresh gave it, the time after which the plant went off.
- 4232-4234: `{:watchdog, {:late, ms}}`: the runner's own lateness: a look more than four times
  `idle:` and a poll period after its last; `ms` the time since.
- 4234-4236: `{:io, device, cause}`: an adapter's callback that gave an error, raised, threw,
  exited, or gave no result the behaviour gives.
- 4236: cause `{:bad_value, "panel.i.0", 2}`: a value that does not fit its point (2 at a bool).
- 4236-4237: cause `{:unknown_address, "panel.i.7"}`: an address that is no point's.
- 4237-4238: each address in a cause is written as the configuration writes it.
- 4238-4239: cause `:timeout`: a device that did not answer within its deadline.
- 4239: cause `:timeout` too: a device hung inside its own read or report.
- 4240: `{:io, ...}` also for a device whose process went down.
- 4240-4242: `{:fault, task, instance, fault}`: a major fault (a bit whose number a tag holds,
  out of its word's bits); the round's first; raised at the end of the step that met it.
- 4242-4245: `{:clock, {:now_ms, answer}}` or `{:clock, {:wall_ms, answer}}`: a host's clock
  that gave the runner or a device no time it can hold, once the plant runs.
- 4245: a restart is refused until the clock is mended.
- 4245: a bad reading during `start_link/1` itself is the host's mistake (an `ArgumentError`),
  not a trip.
- 4246-4247: a round that reads the clock so stops there and trips at once; nothing is written
  after the reading.
- 4247-4249: found wrong before the round's writes (as it begins, or as a step is timed): every
  output is left unwritten, so the trip's 0 is the first thing the devices are given after it.
- 4249-4251: found wrong at a device's write, or at the round's end: the devices written by
  then keep the round's outputs until the trip's 0 follows.
- 4251-4253: that round's `{:round, now, outputs}` event is published with the outputs of every
  device its writes reached, as it is where a device's write fails.
- 4254: `{:internal, message}`: an exception out of the core, which no host can cause.
- 4254-4256: a device's notices that waited for the runner (a latch, or a fault of its own) are
  taken in the order they were raised, ties in device-name order.
- 4256: so a run on the manual clock trips for the same reason every time.

**Citations.**

- 4178: M4-4; decisions 110 to 115, 125, 126 and 128.
- 4228: decision 352. 4232: decisions 137 and 490. 4238: decision 399. 4240: M5-9.
- 4242: "A bit number in a tag", above (README line 1380); decision 394.
- 4246: decision 441. 4250-4251: decisions 469 and 470. 4253: decision 474.
- 4234: "(below)" points at 4282-4290.

**Pictures.**

- A state diagram of the runner: `running`, `tripped`, `gone`; edges "any trip reason",
  `restart/2` ok, `restart/2` `{:error, {:io_init, ...}}` (stays tripped), `stop/2`, crash or
  kill. This one drawing replaces a page of prose.
- A sequence diagram of the trip in `a_trip.exs`: the poll at 20, the failed read, the notice
  to the runner, the 0 written, the latch, `{:trip, ...}` to the subscriber, the waiting
  `status/1` call answered.
- A table of trip reasons: tuple, what it means, what `ms` or `cause` holds, where the
  operator should look (the logic, a device, the computer, the clock).
- A before/after pair: the resource (`k1` = 1) against the panel (`q.0` = 0) at the trip.

**Glossary.**

- **trip**: the runner's one safe stop: every output written 0, devices latched, logic stopped.
- **latch**: a device process's state after a trip in which it writes nothing more until a
  restart releases it.
- **refresh**: the runner's periodic message to each device that renews its deadline.
- **look**: the runner's check, as a round begins and at each refresh, of which devices it has
  heard from (the word is first used at 4233 and never defined).
- **step**: one part of a round that is timed by itself: a task's run, a device's write, the
  runner's own work.
- **major fault**: a fault that trips the plant (as against a minor fault a scan runs on through).
- **the core**: `Logex.Runtime`, the part that reads no clock.

**Hard to read.**

> The reasons: `{:watchdog, {:task, task, took_ms, limit_ms}}`, a timed task's run longer than its line's `watchdog`; `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`, a round of the continuous task longer than its watchdog, counted from the inputs taken to its last program's scan, the timed tasks' runs in it included and each step named with its time, so that the slow one is seen; `{:watchdog, {:idle, ms, work}}`, the runner's own work that took longer than `idle:`, named: a host's request served whole by the function it called, `:status` or `:get`, an edit's step `{:edit, :test}`, or the period's hand-off to the store's writer, `:period` (decision 352, where it was `{:watchdog, {:idle, ms}}`); `{:watchdog, {:device, device, ms}}`, a device that heard nothing from the runner by the deadline its last refresh carried, and so latched itself, `ms` the heartbeat that refresh gave it, the time after which the plant went off (decision 137); since decision 490 `{:watchdog, {:late, ms}}`, the runner's own lateness, a look more than four times `idle:` and a poll period after its last, `ms` the time since (below); `{:io, device, cause}`, an adapter's callback that gave an error, raised, threw, exited or gave no result the behaviour gives, a value that does not fit its point, `{:bad_value, "panel.i.0", 2}` at a bool, an address that is no point's, `{:unknown_address, "panel.i.7"}`, each address as the configuration writes it (decision 399), a device that did not answer within its deadline, `:timeout`, a device hung inside its own read or report, `:timeout` too, or one whose process went down; since M5-9 `{:fault, task, instance, fault}`, a major fault, a bit whose number a tag holds out of its word's bits, the round's first, at the end of the step that met it ("A bit number in a tag", above); since decision 394 `{:clock, {:now_ms, answer}}` or `{:clock, {:wall_ms, answer}}`, a host's clock that gave the runner or a device no time it can hold once the plant runs, a restart refused until the clock is mended, where a start's own read of it is the host's mistake, and since decision 441 a round that reads it so stops there and trips at once, nothing written after the reading: found wrong before the round's writes, as it begins or as a step is timed, every output is left unwritten, so the trip's 0 is the first the devices are given after it, and found wrong at a device's write, or at the round's end, the devices written by then keep the round's outputs until the trip's 0 follows (decisions 469 and 470), the round's own `{:round, now, outputs}` event published with the outputs of every device its writes reached, so a log that follows the rounds holds what the plant was given (decision 474), as it is where a device's write fails; and `{:internal, message}`, an exception out of the core, which no host can cause.
>
> (lines 4221-4254, 485 words)

(The whole list of reasons, 4221-4254, is one sentence of about 485 words. It should become a
table. Its hardest clause is the clock's, 4242-4253.)

---

## Checks before the write, hung devices, lateness and `unzeroed` (lines 4257-4315, about 930 words)

**Reader and purpose.** A host developer who must reason about the worst case: how long can a
stuck input card, a stuck runner or a starved computer go unnoticed, what the plant is left in,
and which device or machine the trip will name. This is the densest passage of the range.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4257-4259 | Every check is made before the round's write, so a round that ran too long, or a device that failed, never reaches the plant | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4259-4260 | A device that does not answer is killed, its outputs left to what the device does on losing its master, and opened again at the next restart | R | reference/runner; reference/io-adapters |
| 4261-4265 | Each device reports back after every read and report; one unheard within `idle:` and a poll period is hung: killed, and the runner trips | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4265-4274 | A runner that wakes late judges no device for a poll period ("a turn"); `latest_wake`; what counts as a late look | R, C | reference/runner; contributor/runner-internals |
| 4274-4282 | The cap: a turn spares only a device unheard for less than four times `idle:` and a poll period; past it, `{:io, device, :timeout}` however late the runner; the Logix parallel | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4282-4295 | The runner itself late: `{:watchdog, {:late, ms}}`, no card killed; three worked cases with numbers (221, 211, 201) | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4295-4297 | Order: the runner's own work past `idle:` trips first; a host's request is no look; a round's long step is no lateness | R, C | reference/runner; contributor/runner-internals |
| 4297-4307 | Devices and the trip's 0: a late answer still gets its 0; a 0 not taken is written again at every poll; `status/1`'s `unzeroed`; a stop of a tripped runner | R, H | reference/runner; howto/restart-after-a-trip (read `unzeroed` before going to the plant) |
| 4308-4315 | Each device's deadline: the step's watchdog and a poll period, or `idle:` and a poll period; a round's write gives each device its own deadline | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4287, 4289, 4295, 4313 and others | "where it named the first device in name order", "the sum, decision 491", "the reason, decision 489", "RV-19's review": what changed and when | X | drop (history) |

**Examples.** None of its own; 4258-4259 explains `a_trip.exs`'s output (4214-4215).

**Rules stated.**

- 4257-4258: every check is made before the round's write.
- 4258: so a round that ran too long, or a device that failed, never reaches the plant.
- 4258-4259: in `a_trip.exs`, `k1` is 1 in the resource (the round at 19's) and 0 at the panel.
- 4259: a device that does not answer is killed.
- 4259-4260: its outputs are left to what the device does on losing its master.
- 4260: it is opened again at the next restart.
- 4261-4262: each device tells the runner, after every read and every report, that it is back
  from its adapter (a message a device a poll period).
- 4262-4263: a device the runner has not heard from within `idle:` and a poll period is hung.
- 4263: this is checked as each round begins and at each wait's refresh.
- 4264: a hung device is killed, and trips the runner.
- 4264-4265: so a stop pressed on a card stuck inside its read is never taken for "not pressed"
  for longer than that.
- 4265-4268: a runner that wakes late (its wake past its time by more than `idle:`) judges no
  device for a poll period: each device gets a turn.
- 4268-4269: so a healthy card the host starved beside the runner does not trip the line as hung.
- 4269-4270: a hung one still trips at the first look once the runner is on time.
- 4270: `status/1`'s `latest_wake` shows how late the runner woke.
- 4271-4272: the look sees the lateness itself, whatever brought the runner to it: its wake, or
  a device's change taken first.
- 4272-4273: each late look gives a turn of its own.
- 4273-4274: so does a round's step that runs past `idle:`, counted from the step's end.
- 4274-4275: a turn spares only a device starved for less than four times `idle:` and a poll
  period (the sum of the two).
- 4275-4277: a device unheard that long, counted from when it was last heard, trips the line
  however late the runner: `{:io, device, :timeout}`, as any hung device.
- 4277-4281: so on a host late at every wake a hung input card still trips, at the first look
  past the cap, so as late as the gap between two looks after it; with every wake 200 ms late,
  `idle` 50 and a poll of 10: at 420 ms unheard; every output 0.
- 4281-4282: the model is a Logix controller, which faults a module's connection after four
  missed packets at its RPI, never on one late look.
- 4282-4285: a look that comes more than the cap after the runner's last look (or the end of
  its last round), and finds every card unheard past the cap, trips naming the runner's
  lateness: `{:watchdog, {:late, ms}}`.
- 4285: `ms` is the time since that last look.
- 4285-4286: every output 0, and no card is killed for the naming.
- 4286-4287: so the operator goes to the computer and not to a healthy card.
- 4287-4289: worked case: one wake 211 ms late at `idle` 50 and a poll of 10, every card
  healthy: `{:watchdog, {:late, 221}}`, 221 ms after the round before it; `latest_wake` 211.
- 4289-4290: `ms` is the gap between looks, not the wake's lateness.
- 4290-4291: a hung card on such a look takes no 0, is killed by the trip's 0, and is named in
  `unzeroed`, as any device that does not answer the trip's 0.
- 4291-4293: where the late look finds a card heard within the cap, the hung card beside it is
  named, `{:io, device, :timeout}`, however late the look.
- 4293-4295: where the late look finds no card unheard past its limit, nothing trips; worked
  case: one wake 201 ms late, every card heard at the poll before it, 201 ms unheard.
- 4295-4296: the runner's own work past `idle:` trips first, named by that work
  (`{:watchdog, {:idle, ms, work}}`).
- 4296: a host's request is no look.
- 4296-4297: a round's long step is no lateness: the gap is counted from the round's end.
- 4297-4300: a device that answers a round's write late is `:timeout` too, but it answered, so
  the trip writes it its 0; so does any device whose own callback failed and that still takes
  a write.
- 4300-4301: a device whose adapter does not take the trip's 0 is written its 0 again at every
  poll while the runner is tripped, and nothing else, until a write is taken.
- 4302-4304: `status/1`'s `unzeroed` names each device whose outputs are not known to be 0:
  those that did not take the 0, and any down or killed, at the trip or after it; until a
  restart opens it.
- 4304: `unzeroed` is `[]` while running.
- 4304: the first reason is kept (a later failure does not replace `trip`).
- 4304-4306: a stop of a tripped runner tries the 0 once more on each device `unzeroed` names,
  and closes it whether or not the 0 is taken.
- 4306-4307: a device whose last 0 hangs is killed at its deadline (the idle watchdog and a
  poll period), its adapter not closed.
- 4308-4309: each device's deadline is the step's: its task's watchdog and a poll period, from
  the step's start.
- 4309-4310: or the idle watchdog and a poll period, while the runner serves its own work or
  waits.
- 4310-4312: so a runner stuck in the conveyor's 50 ms step leaves every device that answers at
  0 within 50 ms and a poll period, and the runner trips when it next runs.
- 4312-4313: a round's write gives each device the idle watchdog and a poll period from the
  start of its own write.
- 4313-4315: so a device written after a slow one that answered in time is never cut short by
  it; only a device slow itself is killed and named; every device that answers takes the
  trip's 0.

**Citations.**

- 4265: decision 134. 4270-4271: decision 461. 4272: decision 485. 4273-4274: decisions 486
  and 492. 4275: decision 491. 4277: decision 489. 4281: decision 484. 4289: decisions 490 and
  503. 4295: "RV-19's review". 4296: decision 482. 4297: decision 504. 4300: decision 135.
  4303-4304: decision 287. 4304: decision 262. 4306: decision 286. 4313: decision 348.

**Pictures.**

- A timing diagram of one device's deadline: refreshes as ticks, the deadline moving out with
  each, a missed refresh, the device latching itself at the deadline (`{:watchdog, {:device,
  ...}}`).
- A timing diagram for the three worked cases on one axis (`idle` 50, poll 10, cap 4 x 50 + 10
  = 210): a wake 201 ms late (nothing trips), 211 ms late (`{:late, 221}`), and every wake
  200 ms late with one hung card (`{:io, device, :timeout}` at 420 ms).
- A flowchart of a look: is the runner late? is any device unheard past `idle:` + poll? past
  the cap? is every device unheard? Leaves: nothing; a turn; `{:io, device, :timeout}`;
  `{:watchdog, {:late, ms}}`. The prose cannot be followed without it.
- A table "after a trip, what is each device left in": answered and took the 0; answered late
  (0 written); did not take the 0 (written again each poll, in `unzeroed`); hung or down
  (killed, left to the device, in `unzeroed`).

**Glossary.**

- **hung**: a device process that has not come back from its adapter within `idle:` and a poll
  period.
- **killed**: the device's process is ended at once (4307 adds "its adapter not closed" for
  one killed at a stop).
- **turn**: one poll period, after a late look, in which no device is judged.
- **the cap**: four times `idle:` plus a poll period; a device unheard for longer trips the
  line whatever the runner's lateness.
- **starved**: a process the operating system did not run, though nothing is wrong with it.
- **card**: an I/O module; the text's word for a device when it means the hardware.
- **`unzeroed`**: `status/1`'s list of devices whose outputs are not known to be 0 since the trip.
- **the line**: the plant ("trips the line").

**Hard to read.**

> A turn spares only a device starved for less than four times `idle:` and a poll period (the sum, decision 491): one unheard that long, counted from when it was last heard, trips the line however late the runner, `{:io, device, :timeout}` as any hung device (the reason, decision 489), so on a host late at every wake a hung input card still trips, at the first look past that cap, so as late as the gap between two looks after it (with every wake 200 ms late, idle 50 and a poll of 10, at 420 ms unheard), every output 0 (decision 484), as a Logix controller faults a module's connection after four missed packets at its RPI, never on one late look.
>
> (lines 4274-4282, 124 words)

> A look that comes more than the cap after the runner's last look, or the end of its last round, and finds every card unheard past the cap, the runner itself late, trips naming the lateness, `{:watchdog, {:late, ms}}`, `ms` the time since that look, every output 0 and no card killed for the naming, so the operator goes to the computer and not to a healthy card, where it named the first device in name order: one wake 211 ms late at idle 50 and a poll of 10, every card healthy, trips `{:watchdog, {:late, 221}}`, 221 ms after the round before it, `latest_wake` 211 (decision 490; `ms` the gap and not the wake's lateness, decision 503).
>
> (lines 4282-4290, 118 words)

> A runner that wakes late, its wake past its time by more than `idle:`, as on a host so busy it did not run the runner, and so perhaps not its devices either, judges no device for a poll period, each device's turn, so that a healthy card the host starved beside it does not trip the line as hung, while a hung one still trips at the first look once the runner is on time; `status/1`'s `latest_wake` shows how late it woke (decision 461).
>
> (lines 4265-4271, 85 words)

---

## Restart, warm and cold (lines 4316-4408, about 675 words)

**Reader and purpose.** An operator's tool author, or a host developer, who must bring a
tripped plant back: what `restart/2` does in which order, what it refuses, what a warm restart
keeps, and the one hazard of a warm restart (an output that comes on by itself).

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4316-4326 | `restart(runner, :cold or :warm)` step by step: release latches, read every device, open those that went down, restart the resource, first round at once, stopped time not counted | R, H | reference/runner; howto/restart-after-a-trip |
| 4326-4328 | A released device writes nothing until the first round has written its outputs: a restart never puts back what the plant had before the trip | R, E | reference/runner; explanation/trips-and-watchdogs |
| 4328-4332 | A restart that fails: `{:error, {:io_init, device, cause}}`, still tripped with its first reason, every device latched and written 0 again | R, H | reference/runner; howto/restart-after-a-trip |
| 4332-4338 | A restart of a running runner is the host's mistake, "the runner is running", judged as the restart arrives; a trip refuses every restart already waiting | R | reference/runner; reference/host-contract |
| 4338-4341 | A runner that crashes or is killed is gone; its devices write 0 once and close; its child spec is `restart: :temporary` | R, H | reference/runner; howto/run-on-the-clock (supervision) |
| 4343-4346 | What `a_warm_trip.exs` does; `warm/packing.logex` and `warm/boxes.ld` (the counter declared `var retain boxes ctu`) | H | howto/restart-after-a-trip; howto/keep-values-across-a-restart |
| 4348-4401 | `a_warm_trip.exs` and its output: three boxes, a trip, a warm restart (count kept), a second trip, a cold restart (count 0) | H | howto/restart-after-a-trip; howto/keep-values-across-a-restart |
| 4403-4408 | What the output shows; the hazard: `full_lamp` comes on in the warm restart's first round because it is written from a retained counter's `q`, which no warning catches | E, H | explanation/warm-and-cold-restarts; explanation/safety-and-limits; howto/restart-after-a-trip (as a warning box) |

**Examples.**

- 4348 `elixir` block (4348-4393) with 4396 `$ mix run a_warm_trip.exs` (output block
  4395-4401): unit "a_warm_trip.exs". It reads three files README does **not** show, which the
  harness derives (`@derived`) from files it does show, and it requires README to hold these
  words: "runs the same plant from `warm/packing.logex`" (4343) and "beside `warm/boxes.ld`,"
  + newline + "which is `boxes.ld` with its counter declared `var retain boxes ctu`"
  (4343-4344, line break included). `warm/packing.logex` and `warm/conveyor.ld` are copies;
  `warm/boxes.ld` is `boxes.ld` with `var boxes ctu` replaced by `var retain boxes ctu`. All
  three exist under `examples/warm/`.
- No file-marked block and no fragment in this section.

**Rules stated.**

- 4316: `restart(runner, :cold | :warm)`.
- 4316: it releases every latch.
- 4316-4317: a device that does not answer its release is killed.
- 4317: it reads every device once, as a start does.
- 4317-4318: it opens again each device that went down (those that went down among the
  devices read).
- 4318-4320: each device is read or opened within its own `open:`; a gateway that stayed up and
  answers its reread in 700 ms lets the restart through.
- 4320-4322: every device counts as heard then, having answered that read, so the first round's
  look finds none unheard since the line stood tripped.
- 4322-4323: it restarts the resource, which keeps its input image and puts every other global
  back to its initial value.
- 4323-4324: a warm restart keeps what each program marks `retain`.
- 4324-4325: it runs the first round at once, on what was read.
- 4325: the stopped time is not counted (`now` does not jump).
- 4325-4326: the conveyor stays off until start is pressed again.
- 4326-4328: a released device writes nothing again until the first round has written its own
  outputs, so a restart never puts back, even for a moment, what the plant had before the trip.
- 4328-4330: a restart fails where a device cannot be opened, or its read fails, or its read
  gives a value that does not fit (a drive card still giving a speed no dint holds).
- 4330-4332: then the runner stays tripped with its first reason; the restart is answered
  `{:error, {:io_init, device, cause}}`; every device is latched again and written 0 once more.
- 4332: nothing switches on, and the card at fault is named.
- 4332-4334: a runner that is running refuses a restart as the host's mistake, "the runner is
  running" (an `ArgumentError`, by the convention; the text does not name the exception).
- 4334-4336: that is judged as the restart arrives: one asked while the runner runs is refused
  even where a trip comes before it is served (a restart that arrives while a round is under
  way, or behind a device's change, among them).
- 4336-4338: a trip refuses every restart already waiting, so a trip stands until a restart
  asked after it.
- 4338-4340: a runner that crashes or is killed is gone; its devices write every output 0 once
  and close as it goes; a device waiting on the runner for its own change does so too.
- 4340-4341: the runner's child spec is `restart: :temporary`, so the host starts a new one.
- 4385, 4399: `restart(runner, :warm)`: `boxes` (a retained counter's `cv`) stays 3; `k1` 0.
- 4390, 4400: `restart(runner, :cold)`: every value back to its initial one; `boxes` 0.
- 4398: tripped: both outputs 0 at the panel, while `b1.boxes.cv` still reads 3 in the resource.
- 4403-4404: an unmarked counter would start at 0 again after a warm restart; `conveyor.ld`
  marks nothing, so the conveyor stays off.
- 4404-4405: no output is kept across a restart.
- 4405-4407: but logic that reads a retained value switches an output on as soon as the plant
  restarts warm (`full_lamp` is written from the retained counter's `q`, in the restart's
  first round).
- 4407: no warning catches that.

**Citations.**

- 4318: decision 142. 4320: decision 439. 4321-4322: "RV-19's review", decision 512. 4324:
  M6-2. 4332: decision 136. 4334: decision 133. 4338: decision 354. 4339: decision 115.
- 4407-4408: "A retained global" and "What logex is not", "below". "What logex is not" is
  below (line 5674); "A retained global" is at line 3089, *above*: the pointer is wrong or at
  best ambiguous.

**Pictures.**

- A sequence diagram of `restart/2`: host, runner, each device, the resource. Release, read
  (within `open:`), restart the resource, first round, first write. With the failure branch:
  a read fails, every device latched again and written 0, `{:error, {:io_init, ...}}`.
- A timing diagram of `a_warm_trip.exs`, 0 to 36 ms: `k1`, `case_full`, the count, the two
  trips, the warm and the cold restart. It shows `case_full` coming back on at the warm restart
  with nobody pressing anything: the hazard, drawn.
- A table "what a restart keeps": input image, other globals, `retain` values, outputs, the
  edit's stage, the forces; columns cold / warm.

**Glossary.**

- **cold restart**: every value back to its initial one.
- **warm restart**: as cold, but values declared `retain` are kept.
- **release**: undo a device's latch so it may be written again.
- **input image**: the resource's copy of the input points' last values.
- **`:io_init`**: the error kind of a device that could not be opened or first read.
- **`restart: :temporary`**: an OTP child spec setting: a supervisor does not start the runner
  again after it ends.
- **gateway**: a device that fronts other hardware and may answer slowly.

**Hard to read.**

> `restart(runner, :cold | :warm)` releases every latch, a device that does not answer its release killed, reads every device once, as a start does, opening again each device that went down, those among them (decision 142), each read or opened within its own `open:`, so that a gateway that stayed up and answers its reread in 700 ms lets the restart through (decision 439), every device heard then, having answered that read, so the first round's look finds none unheard by the time the line stood tripped (RV-19's review, decision 512), restarts the resource, which keeps its input image and puts every other global back to its initial value, a warm restart keeping what each program marks `retain` (M6-2), and runs the first round at once, on what was read, the stopped time not counted: the conveyor stays off until start is pressed again.
>
> (lines 4316-4326, 144 words)

> A runner that is running, not tripped, refuses a restart as the host's mistake, "the runner is running" (decision 133), judged as the restart arrives: one asked while it runs is refused even where a trip comes before it is served, a restart that reaches the runner while a round is under way or behind a device's change among them, the trip refusing every restart already waiting, so that a trip stands until a restart asked after it (decision 354).
>
> (lines 4332-4338, 80 words)

> The case-full lamp comes back on in the restart's first round: no output is kept, but `full_lamp` is written from the retained counter's `q`, so logic that reads a retained value switches an output on as soon as the plant restarts warm, which no warning catches ("A retained global" and "What logex is not", below).
>
> (lines 4404-4408, 55 words)

---

## Forcing and the forces file (lines 4410-4468, 4484-4495 and 4504-4610, about 1,950 words)

**Reader and purpose.** A commissioning engineer or HMI author who must hold an input at a
value (a photo-eye forced "blocked") while the plant runs, and must know that the force
survives a crash, how to clear it, and what `status/1` shows while the disk is slow. Most of
the text (4512-4606, one bullet of about 1,500 words) is about a slow, stalled or unreadable
disk: needed by few readers, and by those few as a table.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4410-4415 | Intro: forcing and an online edit go through the runner; what `forced_and_edited.exs` does; `faster/packing.logex` is `packing.logex` with `interval 5` | H | howto/force-inputs; howto/edit-a-running-plant |
| 4417-4468, 4484-4486 | The forcing half of `forced_and_edited.exs`: `forces:` option, `force/3`, the real eye moved, the file read, a fresh runner, `unforce/2`, a refused force of an output | H | howto/force-inputs |
| 4488-4495 | Its output: the force held while the eye moved, the file's text `"eye 1\n"`, the force back after a fresh start, the device's value back after unforce, the refusal's message | H | howto/force-inputs |
| 4504-4511 | What a force is, from when and until when it holds, across a restart and a crash; `unforce/2` puts back the device's last value | R, H | reference/forcing; howto/force-inputs |
| 4512-4514 | The file: the whole set written at each change, `name value` a line, written beside and renamed over, so a crash leaves the old set or the new | R, C | reference/forcing; contributor/store-and-files |
| 4514-4520 | A write that fails or runs past the write limit: the error, the force not taken, `forces_unknown` | R | reference/forcing |
| 4520-4527 | The rounds run on while a write is out; a force is in effect only once the file holds it; `forces` against `forcing` | R, E | reference/forcing; explanation/trips-and-watchdogs (why the disk never holds up the logic) |
| 4527-4539 | Changes asked while a write is out: mistakes raised at once, changes joined into the next write, every caller given the same answer; ten forces in two writes; a trigger forced and unforced in one write makes no round | R, C | reference/forcing; contributor/runner-internals |
| 4540-4556 | A write out during a trip, an edit's step, a restart (which waits for it), a second restart, a stop | R, C | reference/forcing; contributor/runner-internals |
| 4556-4567 | Who holds the file after a runner ends, crashes or is killed while a cut write may still land; a start on a held file is refused | R, C | reference/forcing; contributor/store-and-files |
| 4567-4569 | A start and a restart read the file raw, off the VM's file server, so a FIFO or a stalled disk holds up no other process | C | contributor/store-and-files |
| 4569-4581 | A file that cannot be read: a fresh start has no force, a restart keeps the runner's own, `forces_unread`; the level-switch scenario | R, E | reference/forcing; explanation/warm-and-cold-restarts or explanation/trips-and-watchdogs (the scenario) |
| 4581-4591 | An orderly stop while `forces_unread` stands writes the runner's set; `stop/2`'s error answers; the `{:forces, {:error, reason}}` event | R | reference/forcing; reference/runner |
| 4591-4594 | A relative `forces:` whose working directory the disk does not answer for refuses the start; use an absolute path | R, H | reference/forcing; howto/force-inputs |
| 4594-4601 | A runner without `forces:` takes no force; an output point or a value that does not fit is the host's mistake; a file with a force the configuration cannot take refuses the start; the file is read exactly as written; unforce of an unforced point; deleting the file | R, H | reference/forcing; howto/force-inputs (and its "the file is refused" part; or widen howto/recover-a-refused-store to both files) |
| 4601-4604 | A refusal's bounds: 50 problems then a count, 60 bytes a quoted text, unprintable bytes shown as `\xFF` | R | reference/forcing; reference/host-contract |
| 4604-4606 | Line ends: LF, CRLF or a lone CR are read; the next write uses LF | R | reference/forcing |
| 4607-4610 | A force or unforce that changes an event task's trigger makes its round at once; `unforce_all/1`'s order; no change, no round | R | reference/forcing; reference/execution-model |
| 4535, 4539, 4546-4547 and others | "where each had a write of its own", "where asked one after another each made its own", "where the HMI's status froze for up to the write limit": what the behaviour was before a decision | X | drop (history) |

**Examples.**

- 4417 `elixir` block (4417-4486) with 4489 `$ mix run forced_and_edited.exs` (output block
  4488-4502): one script that holds **both** this section's forcing (4423-4468, output
  4490-4495) and the next section's edit (4470-4484, output 4496-4501). It cannot be shown on
  two pages as it is: either the forcing and the edit how-tos share a page, or the script is
  split in two (new files under `examples/`, the harness and README's replacement changed
  together). It reads `packing.logex`, `conveyor.ld`, `boxes.ld`, and three derived files
  README does not show: `faster/packing.logex` (`interval 10` replaced by `interval 5`),
  `faster/conveyor.ld` and `faster/boxes.ld` (copies). The harness requires README to hold
  "`faster/packing.logex`" + newline + "being `packing.logex` with `interval 5`" (4414-4415,
  line break included). The script writes and deletes `packing.forces` in its directory.
- No file-marked block and no fragment in this section.

**Rules stated.**

What a force is:

- 4504-4505: `force(runner, point, value)` makes the runner read an input point at `value`,
  whatever its device says.
- 4505: it holds from the first round after its write of the forces file lands.
- 4506: it holds until `unforce/2` or `unforce_all/1`.
- 4447, 4492: a point is named by its global's name (`"eye"`), not its address.
- 4506-4507: (example) the real eye moved and no box was counted.
- 4507: a force holds across a restart.
- 4507-4508: kept in the file, it holds across a crash: every start reads the file.
- 4508-4509: a fresh runner comes back with the force, listed in `status/1` (`forces`), its
  first round reading it.
- 4509-4510: nothing was counted in that first round, since no counter counts on a first scan.
- 4510-4511: `unforce/2` puts back the device's last value, which the runner keeps for each
  input point.
- 4594: a runner started without `forces:` takes no force.
- 4594-4595: a force of an output point, or of a value that does not fit, is the host's
  mistake, raised in the caller.
- 4495: message: "`k1` is an output point, at `panel.q.0`: only an input point is forced".
- 4599-4600: an unforce of a point not forced is accepted.

The file and its write:

- 4512: each force and unforce writes the whole set to the file before it returns.
- 4512-4513: the form is `name value` a line (4492: `"eye 1\n"`).
- 4513-4514: it is written to a file beside it, renamed over it, so a crash leaves the old set
  or the new.
- 4514: a write that fails changes nothing and gives `{:error, {:forces, reason}}`.
- 4515-4516: a write the disk has not finished within the write limit (real time) gives
  `{:error, {:forces, :timeout}}`; the force is not taken.
- 4516-4517: such a write may still land once the disk answers.
- 4517-4518: so `status/1` names the set that write held, `forces_unknown`, until a later
  write of the file lands or fails.
- 4518-4519: a restart's read of the file leaves `forces_unknown` named, since the cut write
  may land after the read.
- 4520: `forces_unknown` is nil otherwise; the key is always there.
- 4520-4521: the rounds run on while the write is out; the write is made in a process of its own.
- 4521-4522: the force takes effect at the first round after the write lands; its call is
  answered then.
- 4522-4524: so on a slow disk every round reads the forces as they were, and `status/1` lists
  those in `forces`.
- 4524-4525: no force is in effect before the file holds it.
- 4525-4527: `status/1`'s `forcing` shows the set the write that is out holds (the forces as
  they will be once it lands); nil where no write is out; the key always there.

Changes asked while a write is out:

- 4527-4529: a force, an unforce or an unforce_all asked while another's write is out, or while
  one so asked waits, is served as it is asked.
- 4529-4530: a host's mistake in it (a point that is no input, a value that does not fit) is
  raised in its caller at once, whatever write is out.
- 4530-4531: its change waits its turn behind the write.
- 4531-4532: every change that waited is joined into the next write, applied in the order
  asked, so the last asked is the last applied.
- 4532-4533: each caller is answered when that write lands, or as it fails or is cut; the same
  answer to each.
- 4533-4535: worked case: ten forces asked together on a disk that takes 3 s a write take two
  writes, 6 s.
- 4535-4537: a force answers once its write lands, so one script that forces ten points one
  after another makes ten writes, 30 s.
- 4537-4539: a trigger forced and unforced in one joined write makes no round: the write takes
  the set the last change leaves.

A write out during a trip, an edit, a restart or a stop:

- 4540-4541: a trip or an edit's step meanwhile leaves the write as it is; the set it writes
  (built on the forces held as it began) becomes the runner's once it lands.
- 4541-4543: a restart waits for the write, to its limit, before it reads the file; so it reads
  what the write leaves, and the HMI never shows a force that then vanishes.
- 4543-4546: that wait is off the runner's path: `status/1` and every other request are
  answered meanwhile, the line shown tripped and the force on its way in `forcing`; the
  restart is made and answered once the write has ended.
- 4547-4548: a force asked during the wait is written after the restart.
- 4548-4549: a second restart asked meanwhile finds the line running once the first is made,
  and is refused.
- 4549-4550: or, where the first restart's own first round trips the line again, it is refused
  by that trip, having been asked before it.
- 4550-4552: a stop answers the waiting restart as "a runner not running", as it answers every
  request behind the write.
- 4552-4553: during the wait an edit's step is served at once; a trip's notice changes nothing,
  the line being tripped already.
- 4553-4555: a write the restart's wait cut leaves its set unknown (`forces_unknown`) through
  the restart's read, until a later write of the file ends.
- 4555-4556: a stop waits for a write that is out, to its limit, and answers its caller.

Who holds the file when a runner ends:

- 4556-4557: a write cut at its limit, at a stop as at any time, may still land once the disk
  answers.
- 4557-4559: so a runner that ends gives the file up only once every write of it that it began
  has ended; the file is held until the cut write's last file-system call is answered.
- 4559-4561: a start on the file meanwhile is refused, naming the file, the runner that ended
  and the process holding the file.
- 4561-4562: a runner that crashes holds the file in the same way.
- 4562-4564: a runner killed can hand nothing on: the next start takes the file only once the
  VM's file server has answered a look behind every call the killed runner's writes left in
  its queue.
- 4564-4565: that is at once on a healthy disk; on a stalled disk the start is refused past its
  write limit, the file named "left by the killed runner".
- 4565-4567: on a disk that never answers the hold lasts as long (a holder the host kills
  leaves the file to that same look), until the VM stops.
- 4567-4569: a start reads the file raw, off the VM's file server, as a restart does, so a FIFO
  or a stalled disk in its place holds no other process's file calls.

A file that cannot be read:

- 4569-4571: "cannot be read" means: the disk has not answered within the write limit, or the
  file system refuses it (a directory in its place among them).
- 4571: a fresh start then starts with no force.
- 4571-4572: a restart then keeps the forces the runner holds; the restart goes on and the line
  comes back.
- 4572-4574: `status/1` names it, `forces_unread: {"packing.forces", :timeout}`, until a
  force's or an unforce's write of the file lands; no restart reads the file meanwhile.
- 4574-4575: with no such file to name, `forces_unread` is nil; the key is always there.
- 4575-4576: a restart that reads the file takes what it holds, as every start does.
- 4576-4579: while `forces_unread` stands, a restart keeps the runner's forces and takes none
  from the file, and the next force's or unforce's write writes the runner's set over it.
- 4579-4581: scenario: a level switch forced to 7 before a crash; a start on a stalled disk
  that could not read the file; the disk back; a trip and a restart: the level reads its
  input, never the 7 no one has forced since.
- 4581-4583: an orderly stop while `forces_unread` stands (`stop/2` or a supervisor's shutdown)
  writes the runner's own set over the file before it ends, so the next start brings back no
  force the HMI was not showing.
- 4583-4584: a `stop/2` whose write of it fails or is cut answers `{:error, {:forces, reason}}`.
- 4585: a crash writes nothing.
- 4585-4586: a `stop/2` whose store's write fails too answers both: `{:error, [forces: reason,
  retain: reason]}`, in the order written.
- 4586-4589: every orderly end (a supervisor's shutdown, which answers no one, among them)
  publishes the forces file's failure, `{:forces, {:error, reason}}`, as it publishes the
  store's.
- 4590-4591: that event is a kind of its own, sent by default, and published by a stop as well
  as answered.
- 4591-4594: a relative `forces:` whose working directory the disk does not answer for in time
  refuses the start: the file "cannot be located", as a relative store's does; the advice is an
  absolute path.

What the file may hold:

- 4595-4597: a file a start cannot take (a force on a point the configuration does not have as
  an input) is refused, every such force named, and the runner does not start.
- 4597-4598: the file is read exactly as the runner writes it: a comment or a blank line is
  refused.
- 4598-4599: a value is any number the lexer reads as one literal and the point's type holds.
- 4600-4601: with no runner, deleting the file clears every force.
- 4601-4602: a refusal names at most the first 50 problems and then counts the rest.
- 4602-4603: each text of the file it quotes is at most 60 bytes (a point's name and a value's
  spelling among them).
- 4603-4604: a control byte, or one past ASCII, except a tab, is shown as `\xFF`; the file's
  path is made printable.
- 4604-4605: a line ends at LF, CRLF or a lone CR alike, as in a program.
- 4605-4606: so a file saved with CRLF forces as written (`hz 1.5` forces 1.5); the next force
  writes it with LF.

Forces and event tasks:

- 4607-4608: a force or an unforce that changes what an event task's trigger reads is a change
  of the trigger, and makes its round at once, before the call returns.
- 4608-4610: `unforce_all/1` that changes several triggers makes one round for each, in
  device-name and then address order, as a device's changes do.
- 4610: one that changes nothing makes no round.

**Citations.**

- 4410-4411: M4-5; decisions 117, 119, 127 and 138 to 141.
- 4516: decisions 353 and 400. 4519: decision 502. 4520: decisions 391 and 440. 4522: decision
  437. 4527: decision 466. 4530: decision 473. 4535: decision 465. 4539: decision 501. 4543:
  decision 468. 4546: decisions 500 and 510. 4547-4548: decision 509. 4550: decisions 354 and
  508. 4550-4552: decision 467. 4552: decision 518. 4555: decision 502. 4556: decision 467.
  4561: decision 475. 4567: decision 495. 4574: decisions 390 and 445. 4575: decision 440.
  4579: decision 445. 4585: decision 472. 4589-4591: decisions 493, 506 and 507. 4593:
  decision 446. 4599: decisions 218 and 226. 4600: decision 140. 4601: RV-5. 4606: decision
  410. 4610: decision 138.
- 4505, 4112: "(below)" pointers inside the same README section.

**Pictures.**

- A timing diagram of the example, 0 to 4 ms: the device's eye, the forced value the logic
  reads, the count. It shows the real eye moving under the force and nothing counted.
- A sequence diagram of one `force/3` on a slow disk: caller, runner, the writer process, the
  disk. The rounds go on; `forcing` holds the new set; the write lands; the next round reads
  the force; the caller is answered. A second lane for the timeout: `{:error, {:forces,
  :timeout}}`, `forces_unknown` set.
- A state table of the four status keys (`forces`, `forcing`, `forces_unknown`,
  `forces_unread`): for each situation (idle, a write out, a write cut, a file unreadable at
  start, after the next good write) what each key holds. This replaces most of the bullet.
- A decision table "the file at a start or a restart": readable and valid; readable and holds
  a force the configuration cannot take; unreadable; held by an ended runner; no `forces:`.
  Columns: fresh start / restart / what `status/1` shows.

**Glossary.**

- **force**: an input point held at a value the host gives, whatever its device reports.
- **forces file**: the text file (`forces:`) the set of forces is kept in, `name value` a line.
- **lands**: a write that has reached the file (the rename is done).
- **a write that is out**: a write begun and not yet ended.
- **cut**: a write abandoned at the write limit; it may still land later.
- **`forcing`**: the set an unfinished write will leave. **`forces_unknown`**: the set a cut
  write held, which may or may not be on the disk. **`forces_unread`**: the file a start or
  restart could not read, with the reason.
- **joined**: several waiting changes written in one write.
- **the VM's file server**: the one Erlang process most file calls go through; a stalled disk
  can block it for every process.
- **raw**: a file opened so its calls do not go through that file server.
- **FIFO**: a named pipe; opening one can block for ever.
- **orderly end**: `stop/2` or a supervisor's shutdown.

**Hard to read.**

> A trip or an edit's step meanwhile leaves the write as it is, the set it writes, built on the forces held as it began, becoming the runner's once it lands; a restart waits for it, to its limit, before it reads the file, so it reads what the write leaves and the HMI never shows a force that then vanishes (decision 468), the wait off the runner's path, `status/1` and every other request answered meanwhile, the line shown tripped and the force on its way in `forcing`, the restart made and answered once the write has ended (decisions 500 and 510), where the HMI's status froze for up to the write limit; a force asked during the wait is written after the restart (decision 509), a second restart asked meanwhile finds the line running once the first is made and is refused, or, where the first's own first round trips the line again, is refused by that trip, asked before it (decisions 354 and 508), a stop answers the waiting restart as a runner not running, as it answers every request behind the write (decision 467), and an edit's step is served at once and a trip's notice changes nothing, the line tripped already (decision 518); a write the restart's wait cut leaves the set it held unknown through the restart's read, since it may still land, until a later write of the file ends (decision 502); and a stop waits for it to its limit and answers its caller (decision 467). A write cut at its limit, at a stop as at any time, may still land once the disk answers, so a runner that ends gives the file up only once every write of it it began has ended: the file is held for it until the cut write's last call of the file system is answered, and a start on it meanwhile is refused, naming the file, the runner that ended and the process holding the file, so no runner starts on a file a late write then changes under it (decision 475): a runner that crashes holds it so too.
>
> (lines 4540-4562, 355 words)

> A file that cannot be read, one the disk has not answered within the write limit or one the file system refuses, a directory in its place among them, starts a fresh start with no force and keeps at a restart the forces the runner holds, the restart going on and the line coming back, and `status/1` names it, `forces_unread: {"packing.forces", :timeout}`, until a force's or an unforce's write of it lands, no restart reading it meanwhile (decisions 390 and 445); with no such file to name, `status/1`'s `forces_unread` is nil, the key always there (decision 440). A restart that reads the file takes what it holds, as every start does; but while `forces_unread` stands a restart keeps the forces the runner holds and takes none from the file, and the next force's or unforce's write writes the runner's set over it (decision 445): so a level switch forced to 7 before a crash, a start on a stalled disk that could not read the file, the disk back, a trip and a restart, and the level reads its input, never the 7 no one has forced since; an orderly stop while `forces_unread` stands, `stop/2` or a supervisor's shutdown, writes the runner's own set over the file before it ends, so the next start brings back no force the HMI was not showing either, a `stop/2` whose write fails or is cut answering `{:error, {:forces, reason}}`, and a crash writes nothing (decision 472); a `stop/2` whose store's write fails too answers both, `{:error, [forces: reason, retain: reason]}`, in the order written, and every orderly end, a supervisor's shutdown that answers no one among them, publishes the forces file's failure, `{:forces, {:error, reason}}`, as it publishes the store's, so an HMI or a log can warn that the next start may bring back an old force (decision 493; the list's shape decision 506, and the event a kind of its own, sent by default and published by a stop as well as answered, decision 507); and a relative `forces:` whose working directory the disk does not answer for in time refuses the start, the file "cannot be located", as a relative store's does (decision 446), an absolute path the advice.
>
> (lines 4569-4594, 369 words)

> A force, an unforce or an unforce_all asked while another's write is out, or while one asked so waits, is served as it is asked, a host's mistake in it, a point that is no input or a value that does not fit, raised in its caller at once, whatever write is out (decision 473); its change waits its turn behind the write, and every change that waited is joined into the next write, applied in the order asked, so the last asked is the last applied, each caller answered when that write lands, or as it fails or is cut, the same answer to each: ten forces asked together, by ten panels or ten processes of one HMI, on a disk that takes 3 s a write take two writes, 6 s, where each had a write of its own (decision 465).
>
> (lines 4527-4535, 143 words)

---

## An online edit stepped through the runner (lines 4470-4484, 4496-4501 and 4611-4622, about 260 words)

**Reader and purpose.** A host developer who changes a running plant through the runner, not
on a resource held by hand. They know `Logex.Configuration.Edit`'s steps and need only what
differs: when a step is served, where the work is done, and when a changed interval is next due.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4470-4484 | The edit half of `forced_and_edited.exs`: compile `faster/packing.logex`, subscribe to `:edit`, `accept/2`, `test/1`, read `status.edit`, watch the conveyor's runs, `assemble/1` | H | howto/edit-a-running-plant |
| 4496-4501 | Its output: the forecast and the test report (`{:interval, "fast", {10, 5}}`, `{:next_due, "fast", {10, 6}}`), stage `:testing`, runs at 6 and 11, assemble's `[]`, stage nil | H | howto/edit-a-running-plant |
| 4611-4614 | The five steps are `Logex.Configuration.Edit`'s, each served between two rounds, the runner holding the edit; same reports; the next round runs what it switched to | R | reference/online-edit; reference/runner |
| 4614-4617 | Accept's work is done in the caller's process, so it never holds up a round; done again where another host's step came between | R, C | reference/online-edit; contributor/runner-internals |
| 4617-4621 | After a step the rounds read the new watchdogs and untimed programs; a cut interval is next due at `min(next due, now + new interval)` | R, E | reference/online-edit; explanation/online-edit-model |
| 4622 | A step may be taken while tripped; a restart keeps the edit's stage | R | reference/online-edit; reference/runner |

**Examples.**

- Lines 4470-4484 and 4496-4501 of the block at 4417 and its output at 4489
  (`forced_and_edited.exs`), listed under "Forcing and the forces file". No block of its own.

**Rules stated.**

- 4611-4612: `accept/2`, `test/1`, `untest/1`, `assemble/1` and `cancel/1` of `Logex.Runner`
  are `Logex.Configuration.Edit`'s steps.
- 4612: each is served between two rounds.
- 4612-4613: the runner holds the edit.
- 4613-4614: each gives the report the same step gives when taken over the resource directly.
- 4614: the next round runs what the step switched to.
- 4614-4616: accept's work is done in the caller's process, against the resource the runner
  hands it, so a large plant's accept never holds up a round.
- 4616-4617: it is done again where another host's step came between.
- 4617-4618: after each step the rounds read the watchdogs and the untimed programs of the
  configuration that runs.
- 4618-4619: a cut interval is next due as decision 40 says: `min(next due, now + new
  interval)`.
- 4619: `now` there is the time the step is taken, by the runner's clock.
- 4619-4621: so a plant with no untimed program, whose resource stands at its last round,
  misses no period for an edit.
- 4621, 4499: the conveyor, last run at 0, ran at 6 and 11 after its interval was cut from 10
  to 5 at 1.
- 4622: a step may be taken while the runner is tripped.
- 4622: a restart keeps the edit's stage.
- 4472: `Runner.subscribe(runner, [:edit])` asks for the edit's events.
- 4473-4476, 4496-4497: `accept/2` gives `{:ok, forecast}` and `test/1` `{:ok, report}`; here
  both are `[{:interval, "fast", {10, 5}}, {:next_due, "fast", {10, 6}}]`.
- 4477, 4498, 4483, 4501: `status/1`'s `edit` is the stage: `:testing` after `test/1`, nil
  after `assemble/1`.
- 4481-4482, 4500: `assemble/1` gives `{:ok, []}` here.

**Citations.**

- 4410-4411: M4-5; decisions 117, 119, 127 and 138 to 141 (shared with forcing).
- 4616-4617: decision 141. 4618: decision 40. 4621: decision 139.
- 4019 (earlier): "A running plant", below, is where the steps themselves are explained
  (README line 5494, outside this range).

**Pictures.**

- A timing diagram, 0 to 12 ms: `fast`'s due times on the old 10 ms grid (0, 10), the test
  step at 1, the new due time `min(10, 1 + 5) = 6`, then 11. It makes `{:next_due, "fast",
  {10, 6}}` plain.
- A sequence diagram of `accept/2`: the caller asks the runner for the resource, does the
  work in its own process, hands the result back between two rounds; the retry lane where
  another step came between.

**Glossary.**

- **step**: one of an online edit's five moves: accept, test, untest, assemble, cancel.
- **stage**: where a held edit stands: `:accepted`, `:testing`, `:untested`, or nil for none
  (only `:testing` and nil are shown here).
- **forecast**: accept's report of what a test would change.
- **cut interval**: an interval made shorter by an edit.

**Hard to read.**

> After each step the rounds read the watchdogs and the untimed programs of the configuration that runs, and a cut interval is next due as decision 40 says, `min(next due, now + new interval)`, `now` the time the step is taken by the runner's clock, so that a plant with no untimed program, whose resource stands at its last round, misses no period for an edit (decision 139): the conveyor, last run at 0, ran at 6 and 11.
>
> (lines 4617-4621, 79 words)

> Accept's work is done in the caller's process, against the resource the runner hands it, so a large plant's accept never holds up a round, and done again where another host's step came between (decision 141).
>
> (lines 4614-4617, 36 words)

---

## The real clock, lateness and how large a plant the defaults carry (lines 4624-4731, about 895 words)

**Reader and purpose.** Someone deciding whether logex is fast and steady enough for their
plant, and someone setting `watchdog`, `idle:` and `write_limit:` for a real machine. The
last bullet is for contributors: what the suite tests on the real clock.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 4624-4627 | Without `clock:` the runner reads the machine's clock, `Logex.Runner.Clock.Monotonic`; what `on_the_real_clock.exs` does | H | howto/run-on-the-clock |
| 4629-4683 | `on_the_real_clock.exs` and its output: start with no `clock:`, sleep, read status, stop; a keyword list that is the same on every run and one line of figures that is not | H | howto/run-on-the-clock |
| 4685-4691 | How to read that output: what repeats, what varies, what `no_more_rounds_than_milliseconds` does and does not prove | H, C | howto/run-on-the-clock; contributor/testing-strategy |
| 4692-4696 | Nothing about timing is guaranteed: the BEAM on a general-purpose operating system; the design spike's measured lateness | E | explanation/safety-and-limits; explanation/timing-and-capacity NEW (measured lateness, per-cycle cost and the size of plant the defaults carry: figures and trade-offs, too long for safety-and-limits and too machine-bound for reference/runner) |
| 4696-4698 | A late periodic task runs once and reports the periods it missed, `{:overlap, task, missed}`; never early; due times stay on their grid | R | reference/execution-model; reference/runner |
| 4699-4702 | `runs` and `latest_wake` again, and their use: a soak on the target machine gives what to set each `watchdog` and `idle:` to | H, R | howto/set-watchdogs; reference/runner |
| 4702-4705 | The spike's cost figures: `cycle/3` per instance, for 100 and 1,000 instances; the runner's own cost a round | E | explanation/timing-and-capacity NEW |
| 4706-4720 | The size of plant the defaults carry: array and block sizes against the 500 ms watchdog, the write limit and the idle watchdog; past the bound the plant trips; give the options more | E, H | explanation/timing-and-capacity NEW; howto/set-watchdogs |
| 4711, 4701 | "since RV-6, where `ton[16000]` took 1.8 s", "since decision 461, where it was a round's wake's alone" | X | drop (history) |
| 4721-4731 | What the suite tests on the real clock, and that every timing rule is tested on the manual clock | C | contributor/testing-strategy |

**Examples.**

- 4629 `elixir` block (4629-4668) with 4671 `$ mix run on_the_real_clock.exs` (output block
  4670-4683): unit "on_the_real_clock.exs". Reads `packing.logex`, `conveyor.ld`, `boxes.ld`.
  Two special cases in the harness: (1) `@varies` compares the output line that begins "this
  run's figures: " (4680) by that beginning only, and the test's comment quotes README's "The
  keyword list is the same on every run; the figures are this run's" (4685); (2) this example
  alone runs with `async: false`, after every other module, because it is on the machine's
  clock. It takes about 1.3 s of real time.
- No file-marked block and no fragment in this section.

**Rules stated.**

- 4624: everything before this point ran on the manual clock, where a run repeats exactly.
- 4624-4626: without `clock:` the runner reads the machine's clock,
  `Logex.Runner.Clock.Monotonic`, and the same plant runs in real time.
- 4634: `Sim.start_link(reports: true)` needs no `clock:` on the real clock.
- 4685-4686: the script's keyword list is the same on every run; the figures line differs from
  run to run and machine to machine.
- 4686-4688: here 1,229 rounds ran in 1,230 ms, back to back; both overlaps 0 (no period missed).
- 4688-4690: the rule is one round a millisecond at most; `status.rounds <= status.now + 1`
  says so only on average, which the rule needs but does not prove.
- 4690: the rule itself, round by round, is tested on the manual clock.
- 4690-4691: nothing the script prints says when each of the conveyor's runs came.
- 4692: nothing about timing is guaranteed.
- 4692-4693: the BEAM runs on a general-purpose operating system and shares its schedulers, so
  a round can be late by what the machine is doing.
- 4694-4696: the design's spike measured absolute timers: on an idle machine 0.19 ms late at
  the median and 3.4 ms at worst; beside a full test suite 126 ms at p99 and 196 ms at worst.
- 4696-4697: a late periodic task runs once and reports the periods it missed, `{:overlap,
  task, missed}`.
- 4697-4698: it never runs early, and its due times stay on their grid.
- 4699: `status/1`'s `runs` is each task's longest run against its watchdog.
- 4700-4701: `latest_wake` is the most the runner found itself past its wake's time, at a
  round's look or a refresh's, in ms.
- 4701-4702: so a soak on the target machine gives what to set each `watchdog` and `idle:` to.
- 4702-4704: the spike measured `cycle/3` at 9 to 26 µs an instance (the motor of
  `docs/organisation.md` §4.3), 2.0 ms for 100 instances and 27 ms for 1,000.
- 4704-4705: the runner's own cost, two devices read and written, was 0.2 ms a round at the
  median.
- 4706-4708: the figures that follow were measured with the defaults `idle: 500`, `poll: 10`
  and `write_limit: 5000`, on the real clock, on a four-core machine another workload kept busy.
- 4708-4709: an array of timers run element by element scans in 166 ms at 32,768 elements and
  367 ms at 65,536.
- 4709: 65,536 is the most a declaration holds.
- 4709-4710: both are within a task's 500 ms watchdog; a user block's instances scan in 348 ms
  at 32,768.
- 4710-4711: a scan allocates words linear in its elements.
- 4711-4712: an array of 65,536 counters takes 487 ms on a quiet machine; an array of timers in
  two dimensions is at the watchdog or past it.
- 4712-4713: so the bound is some 32,768 elements a plant.
- 4713-4714: an array of 32,768 retained timers is written every period, its writer taking the
  image out.
- 4714-4715: one of 65,536 is past the write limit: `unknown`.
- 4715-4717: an edit's test step over 65,536 timers takes 355 to 412 ms, near the idle watchdog
  and once past it under load; over a block's instances, some 20,000 are within it.
- 4717-4719: past the bound the plant trips, every output 0, named by the work it was met in:
  `{:watchdog, {:idle, 644, {:edit, :test}}}`.
- 4719: a larger plant gives `idle:`, a task's `watchdog` or `write_limit:` more.
- 4720: each figure is that machine's; a soak on the target machine gives its own.
- 4721-4722: the suite's tests on the real clock are few and short, with generous bounds, and
  none times a round.
- 4722-4724: one runs the plant for 2 s: rounds no more often than its clock's milliseconds,
  the clock kept, a stop in order, the devices' last writes all 0 and both closed.
- 4724-4726: in `trip_test.exs`: a device hung inside its read trips `{:io, "drive",
  :timeout}`; a device waiting on the runner for its change is heard at each poll meanwhile; a
  bad reading of a device released at a restart trips nothing.
- 4726-4730: the contract walk, on the manual clock, waits in real time where the runner waits
  for its devices: a device's open made late by 700 ms (past the walk's idle watchdog and a
  poll period, within its opening limit), and a restart's read of a device as late; nothing
  trips and nothing is refused.
- 4730-4731: every timing rule is tested on the manual clock.

**Citations.**

- 4696: `docs/organisation.md` §4.11 (the spike). 4701: decision 461. 4703:
  `docs/organisation.md` §4.3. 4706: decision 352. 4711: RV-6. 4714: decision 455. 4722:
  §4.11's "Risks". 4724: `trip_test.exs`. 4729: decision 398. 4730: decision 439.

**Pictures.**

- A table of the measured figures: what was measured, the size, the time, the limit it is held
  against (500 ms watchdog, 500 ms idle, 5000 ms write limit), within or past. The paragraph
  4706-4720 is a table written as one sentence.
- A small chart of the spike's lateness: idle machine against loaded machine, median, p99 and
  worst, on a log scale. It shows at a glance why "nothing is guaranteed".
- A timing diagram of a late periodic task: due times on a 10 ms grid, one wake 25 ms late,
  one run, `{:overlap, "fast", 2}`, the next due time back on the grid.

**Glossary.**

- **monotonic clock**: the machine's clock that never goes back; the runner's default.
- **the BEAM**: the Erlang virtual machine logex runs on.
- **scheduler**: a BEAM thread that runs processes; shared by everything in the VM.
- **spike**: a throw-away experiment made during the design to measure something.
- **p99**: the value 99 runs in 100 stay under.
- **overlap**: a period a late periodic task missed; reported, not made up for.
- **grid**: a periodic task's due times, fixed from the start (0, 10, 20, ...).
- **soak**: a long run on the real machine, to see the worst figures before choosing limits.
- **`unknown`**: the store's state when its write ran past the write limit (README's "The
  store on disk", outside this range).

**Hard to read.**

> The size of plant the defaults carry (decision 352), `idle: 500`, `poll: 10` and `write_limit: 5000`, measured on the real clock on a four-core machine another workload kept busy: an array of timers run element by element scans in 166 ms at 32,768 and 367 ms at 65,536, a declaration's most, within a task's 500 ms watchdog, and a user block's instances in 348 ms at 32,768, a scan allocating words linear in its elements since RV-6, where `ton[16000]` took 1.8 s; but an array of counters of 65,536, 487 ms on a quiet machine, or of timers in two dimensions, at the watchdog or past it, so the bound is some 32,768 elements a plant; an array of 32,768 timers retained is written every period, its writer taking the image out (decision 455), and one of 65,536 is past the write limit, `unknown`; and an edit's test step over 65,536 timers takes 355 to 412 ms, near the idle watchdog and once past it under load, over a block's instances some 20,000 within it.
>
> (lines 4706-4717, 175 words)

> The suite's tests on the real clock are few and short, with generous bounds, and none times a round (§4.11's "Risks"): the plant runs for 2 s, rounds no more often than its clock's milliseconds, keeps its clock and stops in order, its devices' last writes all 0 and both closed; in `trip_test.exs` a device hung inside its read trips `{:io, "drive", :timeout}`, a device waiting on the runner for its change is heard at each poll meanwhile, and a bad reading of a device released at a restart trips nothing; and the contract walk, on the manual clock, waits in real time where the runner waits for its devices, a device's open made late by 700 ms, past the walk's idle watchdog and a poll period and within its opening limit (decision 398), and a restart's read of a device up as late (decision 439), tripping and refusing nothing.
>
> (lines 4721-4730, 150 words)

> `status/1`'s `runs` is each task's longest run against its watchdog, and `latest_wake` the most the runner found itself past its wake's time, at a round's look or a refresh's, in ms (since decision 461, where it was a round's wake's alone), so a soak on the target machine gives what to set each `watchdog` and `idle:` to.
>
> (lines 4699-4702, 57 words)

---

## Findings across the range (for the restructure, not a README section)

**New slugs proposed.**

- `howto/test-on-the-manual-clock` NEW: the manual clock, the sim's `set` / `fail` / `outputs`
  / `writes`, and the "call from another process, advance by 0" pattern (4031-4033, 4128-4132,
  4152-4176). A host that tests its own plant needs this, and no page in the list holds it.
- `howto/watch-a-runner` NEW: subscribe, match `{Logex.Runner, pid, event}`, poll `status/1`
  without slowing the plant (4073-4077, 4133-4152). It could instead be a part of
  howto/run-on-the-clock.
- `explanation/timing-and-capacity` NEW: measured lateness, per-cycle cost, the size of plant
  the defaults carry (4692-4720). It could instead be the second half of
  explanation/safety-and-limits.

**Content that fits no page well.**

- 4721-4731 (what the suite tests on the real clock) and 4685-4691 (what the example's output
  proves) are notes to contributors inside a user section.
- The disk-failure half of forcing (4540-4594, about 900 words) is reference by its form but
  reads as a design record: about 20 decisions, each stated as a behaviour and an aside on what it
  replaced. Proposed: a state table in reference/forcing, the mechanisms in
  contributor/store-and-files, the reasons left to `docs/organisation.md` §7.
- The lateness logic (4265-4297) likewise: the three worked cases belong in
  explanation/trips-and-watchdogs, the rules in a short table in reference/runner, the "turn"
  mechanism in contributor/runner-internals.

**Repeated in the range.**

- `runs` is explained at 4133-4134 and again at 4699; `latest_wake` at 4270 and 4700-4701.
- "Due times never drift / stay on their grid": 4116 and 4697-4698.
- `next_due_in/1` counts periodic due times only: 3897-3898 and 4010-4011.
- "Writes every output 0 once and closes every device": `stop/2` at 4140-4141, a crash at 4339.
- A restart of a running runner is refused (decision 354): 4332-4338 and 4548-4550.
- The `{:forces, {:error, reason}}` event (decisions 493, 507): 4138-4140 and 4586-4591.
- `write_limit:` and its timeouts: 4105-4107, 4515-4516, 4564-4565.
- "A soak on the target machine gives its own": 4701-4702 and 4720.
- Much of 4221-4307 and 4512-4606 also stands, nearly word for word, in
  `lib/logex/runner.ex`'s moduledoc and function docs (for example `status/1`'s doc near line
  1295). With ExDoc, the module docs can be the reference and the guides can link to them.

**Looks stale, dangling or missing.**

- 4311: "whatever the fan's watchdog". `packing.logex` has no fan, and no configuration in
  README declares a task for one (its task names are `fast`, `slow`, `main`, `trip`). A
  left-over, probably from the plant of `docs/organisation.md`.
- 4142: "the conventional table's" names a table the reader has never been shown.
- 4407-4408: "A retained global" is cited as "below"; it is at line 3089, above.
- 4029: "decisions 108 to 143" understates the section, which cites decisions up to 529.
- 4101-4112: the options list omits `retain:` (given in "The store on disk", line 3367) and
  does not say which options are required.
- `status/1`: the range never lists its keys together, and never names `refresh_gap` or
  `retain`, both in `lib/logex/runner.ex`'s doc of `status/1`.
- "round", "look", "refresh", "heartbeat", "turn" and "step" are used as terms and never
  defined in the range.
- `test/logex/readme_test.exs` line 121 says "the one at README's line 3790" of the fragment
  that is now at 4163: a stale comment in the test, not in README.
- Some 20 asides ("since decision N", "since M5-9", "since RV-5", ", where it was ...") tell
  history inside rules, beside about 110 bare decision numbers. The asides are marked X above;
  `docs/organisation.md` §7 holds the history.
