### Milestone 2 — program organisation

**Decided 2026-09-28** (§5; design and rationale in `docs/organisation.md`, whose §7
decisions were all taken as recommended). *(Its §7 has since gained decisions 15–29, on
online edit, taken on 2026-10-01: 18, 28 and 29 depart from their recommendations and 19
had none; see "Online edit — decided 2026-10-01".)* Each item surveys its new words in
`docs/naming.md` first, lands green, and pins every rule with a test that fails when the
rule is reverted. M2-5 needs only M1-6 and B5, so it may move ahead of M2-1. *(Ordered
2026-10-02 by decision 30, below: M2-5 lands after M2-1.)*

**Designed 2026-10-02** (`docs/organisation.md` §4.10, "Milestone 2's design", and its §7
decisions 30–40; "decision N" in this section is that §7's). A design pass spiked
Milestone 2 in three tracks on copies of `47319f7`: the scheduler (M2-1); user function
blocks (M2-5); and the configuration file, shared globals and event tasks (M2-2, M2-3,
M2-4, M2-6). Each track was reviewed for correctness and for fit, then revised, and each
reverted every rule it adds alone under its full suite: 113 rules in the scheduler's
spike, 88 in the function blocks' and 127 in the configuration file's, every one red but
one (owed below). The scheduler's and the function blocks' spikes, merged, pass together:
582 tests on Elixir 1.20.4. The maintainer took decisions 30–40 as recommended but 35,
the configuration file's extension, where the maintainer chose `.logex`, outside the
options offered; the pass's routine choices, the rules of §4.10, were all taken as
recommended. None of it has landed.

**The order (decision 30):** the design record, then M2-1, M2-5, M2-2, M2-3, M2-4 and
M2-6.
- **M2-1 first**, decision 1's default. M2-5's Done-when then stands as written: its
  `m1.s2.run` is read through M2-1's `get/2`.
- **M2-5 before M2-2,** so the configuration file's reader, its loader and the IR walk
  are written against `cal` from their first commit. In the other order a hand merge of
  the spikes failed at four seams: a walk of a program's writes that raised on `cal`, a
  loader that put a function block type among the programs, a block's `var_external` that
  raised `FunctionClauseError`, and two loaders.
- **Then the text items in turn:** M2-3's task lines build on M2-2's reader, M2-4's checks
  on the IR walk that is its first commit, and M2-6's event tasks on M2-3's task lines.
  The walk lands before the first check that reads a program's writes or timers.

Each commit lands green under the full gate, with its mutation rows in its message, every
rule it adds reverted alone. Only M2-1's commits were built as a gated series; M2-5's and
the configuration file's must be built that way before they land.

- **M2-1 · The scheduler, from Elixir data, no syntax.** `%Logex.Configuration{}`,
  `Logex.Runtime.start/cycle/next_due_in/get`, periodic and task-less instances,
  copy-in/copy-out, overlap events. *Done when* a configuration built in Elixir with a 10
  ms task, a 30 ms task and a task-less instance, cycled every 10 ms from 0 to 990 ms by an
  injected clock, runs each instance exactly as often as its task dictates, in priority
  order; a late cycle yields one `{:overlap, …}` and no lost phase; the README program
  gives identical outputs through `scan/2` and through a one-instance configuration.
  *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "cycled for one
  simulated second", which did not say how the clock is stepped. The counts are 100, 34
  and 100 runs.)*
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

  *Designed 2026-10-02* (`docs/organisation.md` §4.10, M2-1). The scope widens twice,
  each annotated where it was decided: every `docs/organisation.md` §4.4 check that M2-1's
  data can express, over tasks, globals, located points, instances and connections, lands
  here in `Logex.Configuration.check/1`, pinned from data, where M2-2 had them; and
  `restart/2` and `overlaps/1` join §4.6's API (decision 38). A host mistake no text can
  say raises `ArgumentError` (decision 36), and a priority is 0 to 65535 (decision 37).
  `CLAUDE.md`'s rule for new state extends to `%Logex.Runtime{}`. A configured plant is
  not edited until OE-2: `Logex.Edit` edits a lone instance, and `%Logex.Runtime{}`
  changes only through the API. It lands as:
  1. `Logex.Configuration` and the `:configure` stage: the element structs, `check/1`,
     `new!/1`, `location/1` and `initial/1`;
  2. the resource with periodic tasks: `%Logex.Runtime{}`, `start/1`, `cycle/3`,
     `next_due_in/1`, `overlaps/1` and `get/2`;
  3. `restart/2`;
  4. the contract walk over a configuration, in `api_contract_test.exs`;
  5. the Done-when end to end, with the walks of the README's examples;
  6. the documents, among them the README's "Changing a running program", which says that
     a configured plant is not edited until OE-2.

  The first five are built as a gated series on copies of `47319f7`: 466, 504, 509, 510
  and 514 tests, from 430, each commit's rules red in its own tree. The second's prose
  names `restart/2` early and is trimmed when it lands.
- **M2-2 · The configuration file, task-less.** A separate `.logex` file (the extension
  was a placeholder until decision 35 chose it on 2026-10-02): `var_global`, plain and
  located (`at panel.q.0`), `program <inst> <type>`, arrow-free connections (`m1.start
  pb_start_1`), every `var_input` connected, one driver per sink. *Done when* two instances
  of one `.ld` program type, wired in a configuration file to different input and output
  points, run for N cycles from one input image and keep independent state; a mis-wired,
  unknown, undriven-input or mistyped connection is a located diagnostic naming its file
  and line. *Also decided 2026-09-30:* the extension says what kind of file it is, so
  `Logex.compile_file/1` refuses anything but `.ld` with a `:file` diagnostic. Until
  then it names a program after its basename less the last extension, whatever that is,
  and `test/logex_test.exs` pins that; its `seal.txt` assertion flips with this item.

  *Designed 2026-10-02* (§4.10, M2-2). Two departures from the scope above, each annotated
  where it was decided: the §4.4 checks M2-1's data can express land with M2-1, and M2-2
  asserts each again as a whole diagnostic list from source; and the loader is M2-5's, one
  memo per configuration. The file is read by a recursive descent over `Logex.Lexer`'s
  tokens and printed back with an exact round trip. It reserves `program var_global at`
  in the configuration file. It lands as:
  1. the `program`, `var_global` and `at` stanzas;
  2. `compile_file/1` takes only `.ld`, as a gate in front of M2-5's loader;
  3. `Logex.Configuration.Text`: the reader, the text's own definition of what a line can
     say, and the printer; it reserves the words, and each message that names a word
     lands with it;
  4. the configuration file's checks as rows of M2-1's `check/1`, in the file's words,
     with one diagnostic per instance for its unconnected var_inputs;
     `Configuration.compile/3`; every M2-1 check asserted again from source; the
     public-surface pin of `Logex.Configuration` rewritten once;
  5. the configuration's loader, through M2-5's with one memo per configuration, refusing
     a block's file on a `program` line;
  6. the round trip, totality and growth;
  7. a location in a `.ld` rung named as one;
  8. the Done-when on M2-1's `cycle/3`, and the documents.

  The fourth is the largest piece no spike built (owed, below).
- **M2-3 · Periodic tasks in text.** `task <n> interval <ms> priority <p>` and `with`.
  *Done when* the plant of `docs/organisation.md` §4.4 without its event task, its `motor`
  the §4.2 one plus `var t1 ton` and a rung `xic motor ton t1 5000` (so no `estop`,
  `var_external` or `cal`, which arrive with M2-4 and M2-5), cycled every 10 ms from 0 to
  990 ms, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  the one clock. *(Worded 2026-10-02: "cycled every 10 ms from 0 to 990 ms" was "driven
  for one simulated second".)* *(M1-6: that motor compiles without a warning and times. Say how the
  inputs are timed: an instance sees an edge when a scan copies it in, so the equality
  holds per rising edge, when two instances see that edge at one time and the preset is a
  multiple of both periods. A timer that re-triggers itself repeats every preset plus two
  task periods, so its rate differs between tasks, as MatIEC's TON does.)*

  *Designed 2026-10-02* (§4.10, M2-3). A priority is 0 to 65535 (decision 37), and the
  item's documents state decision 40's rule for an interval OE-2 changes. It reserves
  `task interval priority with`, and lands as: (1) the `task`, `interval`, `priority` and
  `with` stanzas; (2) task lines and `with` turned on, with the warning for a task that
  runs no instance; (3) the Done-when, on M2-1's scheduler, and the documents. The reader
  is spiked.
- **M2-4 · Shared globals.** `var_external` in `.ld`; type agreement (Ed 2 §2.4.3); no
  writes to an input point; a two-writer warning. *Done when* an e-stop declared once as
  a `var_global` and read by two instances through `var_external` stops both in the same
  cycle; a `var_external` with no matching global, or of another type, is a located
  diagnostic.

  *Designed 2026-10-02* (§4.10, M2-4). One copy of each global: the scheduler merges each
  `var_external`'s global into its instance's state before `call/4` and splits it off
  after. A function block's file refuses `var_external`, a deliberate, reversible
  departure from IEC. The two-writer warnings ride on the configuration's `warnings`. It
  lands as: (1) B5's one IR walk, with public functions for which tags a program writes
  and which timers it runs, knowing `cal` and reaching block bodies, and no change in
  behaviour; (2) `var_external`: its stanza, the section and its `.ld` rules, and its
  refusal in a block's file with a located diagnostic; (3) the binding checks and the two
  writer warnings, from the walk, into M2-1's `check/1`; (4) one copy of a global at run
  time, the Done-when and the documents. The walk, the block-file refusal and the
  run-time copy are not spiked.
- **M2-5 · User function blocks.** `function_block <name>` as a file's first line,
  matching the file name; *(its first rung since 2026-10-02: comments and blank lines may
  come before it, §4.10)*
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
  `cal` on a built-in type should be refused.)* *(Answered 2026-10-02: no member of a user
  block is written from outside it, by decision 33, and `cal` of a `ton` is refused,
  naming the `ton` that runs it; the other notes stand as written.)*

  *Designed 2026-10-02* (§4.10, M2-5). It lands after M2-1 (decision 30), so its
  Done-when stands as written and its own test reads `get(rt, "m1.s2.run")`. The scope
  above leaves out three things the design gives it, each annotated where it was decided:
  the nested migration that `docs/organisation.md` §4.9 and OE-2 below assign to it, so a
  program that holds blocks may change while it runs, by path (decision 31), a one-shot
  inside a block blocked until a scan runs it (decision 32); the loader, ahead of M2-2,
  `compile_file/1` finding `<word>.ld` beside the file and handing back the loaded blocks'
  warnings (decision 34); and `types:` on `Logex.compile/2`, a block's file compiling to
  `{:ok, %Logex.FbType{}}`. Fix F15 lands here: `%Logex.Program{}` gains a `file`. It
  lands as:
  1. the survey: the `function_block` and `cal` stanzas, and
     `Logex.Declarations.kinds/0` with its naming test;
  2. the IR walks learn a signature per instruction, with no change in behaviour;
  3. blocks and `cal`, reserving `cal` in every `.ld`, in any case, and `function_block`
     in a block's file; fix F15; the Done-when, through `get/2`; one message for a block
     type given where a program goes, at every entry point, M2-1's `check/1` included;
  4. the edit by path (decisions 31 and 32), in one push with the third, whose edit refuses
     every change to a block;
  5. the loader (decision 34);
  6. the documents.

  The spike holds the first five, not cut into commits. Fix F15, the `get/2` assertion,
  the one message in `check/1` and the warnings of decision 34 are not built. A separate
  commit after M2-5 excuses the uses of a declaration whose type is unknown.
- **M2-6 · Event tasks.** `task <n> single <g> [interval <ms>] priority <p>`, fired by a
  rising edge, and in the first cycle if the trigger is already true; with `interval` too,
  it runs periodically only while the trigger is 0, plus a run on each edge (IEC rule 2). *Done when* an event task triggered
  from an input point runs once per rising edge, before lower-priority tasks due in the
  same cycle, and runs in cycle 1 if its trigger is already true.

  *Designed 2026-10-02* (§4.10, M2-6). `single` with `interval` is decision 39; an event
  task's due time, for the tie-break, is the cycle's `now`; a restart sets a trigger's
  last sample to 0, and an edit keeps it. The warning for a `ton` in a program an event
  task runs, on the configuration's `warnings`, covers a task with `interval` too and a
  `ton` inside a block. It reserves `single`, and lands as: (1) `single`: its stanza, its
  task lines, the warning from the walk, and `single` on `Logex.Configuration.Task`; (2)
  edges at run time, the Done-when and the documents. The reader and the checks are
  spiked; the edges at run time are not.

The scheduling rules are decided too: PRIORITY on every task, 0 the highest; ties go to
the earlier due time, then declaration order; no preemption; missed periods coalesced,
counted and reported; time injected in milliseconds, never read from a clock; reserved
words scoped by file kind. Once a wall-clock runner exists, a watchdog fault is to stop
scheduling, zero the output image once, report, and require an explicit restart: the
recommended choice, confirmed when the runner is designed (`docs/organisation.md` §7,
decision 14). *(Since 2026-10-02 a priority is 0 to 65535, decision 37, and an event
task's due time, for the tie-break, is the cycle's `now`.)*

**Milestone 2 is done when** a configuration file on disk instantiates one `.ld` program
type twice, with a function block inside it; wires the instances to declared I/O points
and to a shared global; schedules them under a periodic task, an event task and no task;
runs deterministically for N cycles from an injected clock and input image, with the same
outputs on every run; and reports every wiring, typing or scheduling mistake as a located
diagnostic naming its file and line.

**Owed, from the design (2026-10-02).**
- **The port of the configuration checks into one validator.** The configuration
  spike's checks stand in a validator of their own, which cannot be merged with M2-1's:
  both add `lib/logex/configuration.ex`. M2-2's fourth commit ports them into M2-1's
  `check/1` as rows, rewrites the public-surface pin once, and asserts every M2-1 check
  again from source. Two device names that differ only in case are refused there; no
  spike built it.
- **The seams between M2-5 and the configuration file** are planned, not built: the
  configuration spike has no `cal`. Each commit at a seam checks it on the composed tree:
  a `cal`'s outputs among a program's writes, a block's `ton` among its timers, a block's
  file on a `program` line, a block's `var_external`, and one loader.
- **Two run-time pieces were not spiked:** M2-4's one copy of a global, and M2-6's edges
  with `single` and `interval`. Their rules are the design's text alone. A test of the
  event task's tie-break is owed: an event task and a late periodic task of one priority,
  both writing one global, asserting which write lands.
- **The untested rising-lines check.** M2-5 checks that a block's body given in `types:`
  is one a compile gives, its rungs among them on rising lines, each on one line, after
  its declarations. Reverted alone, that line check left the function blocks' spike
  green, and three more calls in the same check (to the compiler's `shared_bits/2`,
  `calls/1` and `path/2`) have no revert at all. Each gets a test that fails when it is
  reverted, or the check goes.
- **Messages.** M1-6's member messages put "a" before a type's name, which reads "a
  outer" for a block so named.
- **Costs to keep in view.** Every compile checks each block type it is given at full
  depth: 2,486 reductions for a small block against 244 before, and 138,358,875 for a
  chain of 400 files built one at a time. A refusal of many bad keys is quadratic in its
  keys and the names. Three growth tests in reductions failed now and then under a load
  average near 40, and pass run alone; a CI runner that shares cores could see that.

