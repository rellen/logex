### Milestone 2 — program organisation

**Decided 2026-09-28** (§5; design and rationale in `docs/organisation.md`, whose §7
decisions were all taken as recommended). *(Its §7 has since gained decisions 15–29, on
online edit, taken on 2026-10-01: 18, 28 and 29 depart from their recommendations and 19
had none; see "Online edit — decided 2026-10-01".)* Each item surveys its new words in
`docs/naming.md` first, lands green, and pins every rule with a test that fails when the
rule is reverted. M2-5 needs only M1-6 and B5, so it may move ahead of M2-1.

- **M2-1 · The scheduler, from Elixir data, no syntax.** `%Logex.Configuration{}`,
  `Logex.Runtime.start/cycle/next_due_in/get`, periodic and task-less instances,
  copy-in/copy-out, overlap events. *Done when* a configuration built in Elixir with a 10
  ms task, a 30 ms task and a task-less instance, cycled for one simulated second by an
  injected clock, runs each instance exactly as often as its task dictates, in priority
  order; a late cycle yields one `{:overlap, …}` and no lost phase; the README program
  gives identical outputs through `scan/2` and through a one-instance configuration.
  *(Online edit, 2026-10-01: M2-1 also keeps `docs/organisation.md` §4.9's constraints,
  so OE-2 needs no rework: the runtime value holds plain data only; state is keyed by name,
  program instances are held flat and never nested under a task, and execution order is a
  list; each item's rule for a new piece
  of state serves both `start/1` and an edit that adds one, with the edit's exceptions
  listed; one checked constructor, which M2-2's parser feeds; an opaque
  `%Logex.Runtime{}`; one copy of each global; and an open set of events. OE-1's design
  adds one: `start/1` builds each instance through the same constructor as
  `Runtime.instance/1`, so an instance's `first`, its one-shot block list and any field it
  gains later cannot drift between the two.)*
- **M2-2 · The configuration file, task-less.** A separate `.lcf` file (the extension is
  still a placeholder; choose it before this item lands): `var_global`, plain and located
  (`at panel.q.0`), `program <inst> <type>`, arrow-free connections (`m1.start
  pb_start_1`), every `var_input` connected, one driver per sink. *Done when* two instances
  of one `.ld` program type, wired in a configuration file to different input and output
  points, run for N cycles from one input image and keep independent state; a mis-wired,
  unknown, undriven-input or mistyped connection is a located diagnostic naming its file
  and line. *Also decided 2026-09-30:* the extension says what kind of file it is, so
  `Logex.compile_file/1` refuses anything but `.ld` with a `:file` diagnostic. Until
  then it names a program after its basename less the last extension, whatever that is,
  and `test/logex_test.exs` pins that; its `seal.txt` assertion flips with this item.
- **M2-3 · Periodic tasks in text.** `task <n> interval <ms> priority <p>` and `with`.
  *Done when* the plant of `docs/organisation.md` §4.4 without its event task, its `motor`
  the §4.2 one plus `var t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`,
  `var_external` or `cal`, which arrive with M2-4 and M2-5), driven for one simulated
  second, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  the one clock. *(M1-6: that motor compiles without a warning and times. Say how the
  inputs are timed: an instance sees an edge when a scan copies it in, so the equality
  holds per rising edge, when two instances see that edge at one time and the preset is a
  multiple of both periods. A timer that re-triggers itself repeats every preset plus two
  task periods, so its rate differs between tasks, as MatIEC's TON does.)*
- **M2-4 · Shared globals.** `var_external` in `.ld`; type agreement (Ed 2 §2.4.3); no
  writes to an input point; a two-writer warning. *Done when* an e-stop declared once as
  a `var_global` and read by two instances through `var_external` stops both in the same
  cycle; a `var_external` with no matching global, or of another type, is a located
  diagnostic.
- **M2-5 · User function blocks.** `function_block <name>` as a file's first line,
  matching the file name;
  instances (`var s1 seal`); `cal` with positional operands, rung power as EN, and nothing
  copied on a false EN; nesting; recursion is a diagnostic. *Done when* a seal-in written
  once as a function block and instantiated three times in one program behaves as three
  independent seal-ins, `m1.s2.run` reads one of them, a false EN freezes only its own
  instance, and a recursive type, an unknown FB type or a `cal` of a non-instance is a
  located diagnostic. *(From M1-6, for this item: `Logex.FbType` already recurses into a
  member whose type is a type, and `public/1` leaves a `:local` role out by default; a
  frozen instance must leave a timer's `.en` and `last` alone, so a timer that was timing
  catches up; the "no `ton` runs it" warning must say `cal` for a user type; `first` is
  the program instance's, so an `ons` inside a block frozen on the first scan is not held
  back when it first runs; which of a user block's members logic may write is open; and
  `cal` on a built-in type should be refused.)*
- **M2-6 · Event tasks.** `task <n> single <g> [interval <ms>] priority <p>`, fired by a
  rising edge, and in the first cycle if the trigger is already true; with `interval` too,
  it runs periodically only while the trigger is 0, plus a run on each edge (IEC rule 2). *Done when* an event task triggered
  from an input point runs once per rising edge, before lower-priority tasks due in the
  same cycle, and runs in cycle 1 if its trigger is already true.

The scheduling rules are decided too: PRIORITY on every task, 0 the highest; ties go to
the earlier due time, then declaration order; no preemption; missed periods coalesced,
counted and reported; time injected in milliseconds, never read from a clock; reserved
words scoped by file kind. Once a wall-clock runner exists, a watchdog fault is to stop
scheduling, zero the output image once, report, and require an explicit restart: the
recommended choice, confirmed when the runner is designed (`docs/organisation.md` §7,
decision 14).

**Milestone 2 is done when** a configuration file on disk instantiates one `.ld` program
type twice, with a function block inside it; wires the instances to declared I/O points
and to a shared global; schedules them under a periodic task, an event task and no task;
runs deterministically for N cycles from an injected clock and input image, with the same
outputs on every run; and reports every wiring, typing or scheduling mistake as a located
diagnostic naming its file and line.

