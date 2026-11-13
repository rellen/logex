# Changelog

What each release of logex carries, drawn from the decisions of
[`docs/organisation.md`](docs/organisation.md) §7, which hold every rule's reasons and
history (decision 515 (b)). The newest release comes first.

**How an entry reads.** A release's heading is `## X.Y.Z — YYYY-MM-DD`, its version the one
`mix.exs` gives at the commit its tag `vX.Y.Z` names, or `## Unreleased` above the newest
release while the next is made. Its first line, `Decisions: 1–14, 30, 41–54.`, names by
number every decision of §7 it carries, each once in the whole file, a range written with
an en dash; `scripts/changelog.exs` reads that line, and the suite and
`scripts/release.sh` hold every decision §7 records to it (`CONTRIBUTING.md`, "Releasing").
Under it, what a host who upgrades must know first, each item naming its decisions:

- **What changes a running program's outputs**: the rule before and after, a plant that
  shows it, and how to find a program it reaches. For example, had decision 146 come
  after a release, its entry would have read: "An integer result past its type's limit
  wraps, with no power out of the instruction, where a `dint` stopped at its limit before
  (decision 146, replacing 77). A box counter's `add boxes 1 boxes` at 2,147,483,647 gives
  −2,147,483,648 on the next box, where the count stayed at 2,147,483,647; the `add`
  passes no power on that scan in both. Look for: every arithmetic instruction whose
  destination can reach its type's limit, and every rung that reads that destination."
- **What no longer compiles, loads or starts**: a word newly reserved, which breaks a
  program with a tag of that name, a form newly refused, a store or forces file an older
  logex wrote and this one refuses, each with what to write instead.
- **The host's API**: a function, option, event or message changed or added.
- **Added**: what is new and changes nothing a running program did.

## Unreleased

Decisions: 1–531.

The first release, carrying every decision §7 records, taken from 2026-09-28 to
2026-11-13 (provisional: its number, and whether its tag is pushed, are the maintainer's,
`PLAN.md`'s RV-22, questions 1 and 2). No release came before it, but `mix.exs` has said
0.1.0 at every commit of `main`, so a host who ran one upgrades from a logex that said the
same number. For that host, "What changes a running program's outputs" lists each rule §7
records as replacing one that had landed on `main` and that changed what a running
program, or the runner under it, writes, found by a pass through §7, oldest first
(provisional: `PLAN.md`'s RV-22, question 4, its reading (b)); a word newly reserved or a
form newly refused is told by the compile's own diagnostic, and the host's API is
README's, so this first entry lists neither apart.

### What changes a running program's outputs

- **Each device is written again at every poll** (decision 130, amended "fixed timer as
  Logix", decision 132 superseded), the outputs it last wrote, on its own poll grid,
  where once Milestone 4's runner wrote a device only when its outputs changed. A drive
  that turns its outputs off when it hears nothing from its master stopped a conveyor
  after an hour of steady outputs; it runs on now. Look for: an adapter whose write
  counts or acts on each write, not on a change.
- **An integer result past its type's limit wraps** (decision 146, replacing 77), with no
  power out of the instruction, where a `dint` stopped at its limit before. A box
  counter's `add boxes 1 boxes` at 2,147,483,647 gives −2,147,483,648 on the next box,
  where the count stayed at 2,147,483,647; the `add` passes no power on that scan in
  both. Look for: every arithmetic instruction whose destination can reach its type's
  limit, and every rung that reads that destination.
- **`not` and the shifts and rotates compute in their source's type** (decision 214,
  replacing decision 147's rule for them and decision 206's `not` of a bool), the result
  then widened into the destination, where they computed in the destination's type. A
  lamp panel's `not left mask`, `left` a made limit switch and `mask` a `word`, gives
  16#0000 where it gave 16#fffe; `rol b 1 r` of a `byte` 16#81 into a `word` gives
  16#0003. Look for: `not`, `shl`, `shr`, `rol` and `ror` whose destination is wider than
  their source.
- **A held output stays held at a configuration edit's switch** (decisions 347, 386 and
  387, with the refusals of 374, 388 and 428): a point a var_output no rung writes is
  wired to, wired anew or rewired, keeps its value until a rung writes the var_output,
  reported held, where the var_output's initial value was copied over it at the first
  cycle under test, a conveyor's contactor reported held coming on; and an edit that
  would hold a var_output a rung reads, one of another type than its point, or one
  wired to a second point, is refused at accept, where it was taken. Look for: every
  configuration edit that wires a global from a var_output its program does not write.
- **Every device that answers takes a trip's 0** (decision 348): each device's write has
  its own time limit from its own start, where every write of a round shared one
  deadline, so a panel written after a slow drive was killed in its write, never took the
  0 and was the one the trip named. Look for: plants of more than one device.
- **A retained `tof` held on at an outage comes to rest at a warm restart or a start
  from the store** (decision 349, its means decision 385's), `.dn` 0, where its first run
  saw the rung false as a falling edge and ran its off-delay: a fan started by itself
  after a power failure; one already in its run-on resumes it, as before. Look for:
  every `tof` a `retain` reaches.
- **A trigger's rise that a trip cut off runs its event task on the next cycle**
  (decision 350), a warm restart's or a start from the store's first among them, where
  the task never ran: a box the event task counted was lost, and where the task alone
  cleared the bit, the bit never rose again. Look for: event tasks whose trigger is
  retained.
- **A restart asked while the runner runs is refused, whatever comes before it is
  served** (decision 354), where one that waited for its slot while a round was owed was
  served by a trip that came first and cleared it: the line came back on after the trip
  with no restart asked after it. Look for: a host that calls `restart/2` without
  reading `status/1` first.
- **A retained timer's preset no instruction gives is kept at a start from the store**
  (decision 378), as a warm restart keeps it, where it started at 0, reported `{:preset,
  25, 0}`. Look for: retained timers and counters a program declares and runs on no
  instruction, and rungs that read their `.pre`.
- **A warm restart counts each timer from the restart** (decision 382), as a start from
  the store does, where it counted from the timer's last scan: a fan's run-on in a slow
  task stopped up to one interval sooner. Look for: retained timers in tasks of a long
  interval.
- **The rounds run on while a force is written to the forces file** (decision 437), the
  force taking effect at the first round after the write lands, where no round ran
  meanwhile, the outputs held where they were and a task's missed periods reported as
  overlaps: on a slow disk the conveyor's logic stopped for up to `write_limit:`. Look
  for: forces made while the plant runs.
- **A round whose clock reading is wrong writes no outputs** (decision 441, after 394),
  the trip's 0 the first thing the devices are given after it, where the round ran with
  no time passed and wrote its outputs before the trip. Look for: a host's own clock
  module.
- **A runner that wakes late, or whose step runs past the idle watchdog, lets its
  devices run before it judges them** (decisions 461, 484 and 486), so a device the
  machine's scheduler starved trips nothing, where it tripped the line as a hung one,
  every output 0, `{:io, "panel", :timeout}`; a device unheard for four idle watchdogs
  and a poll period trips the line whatever the runner's lateness. Look for: plants on a
  loaded or virtual machine.

### What it carries, by the work that built it

- **Program organisation and the first online edit** (decisions 1–29). The direction
  taken on 2026-09-28, decisions 1–14: a program compiled to a named, stateless value run
  as instances, and Milestone 2's order (1); Milestone 1's changes, a named program
  (`Logex.compile/2`), `call/4`, one diagnostic type carrying the file and line, the
  evaluator's read-only scan and declared, nested timer instances (2); a
  configuration in a file of its own (3) and a function block's file headed
  `function_block <name>` (4); a connection written `m1.start pb_start_1` (5) and an I/O
  point `at panel.q.0` (6); every `var_input` connected (7); each timer timed from its own
  last scan (8); an instance's state as nested maps on its block type's schema, a timer's
  `.pre` and `.acc` alone written from outside it (9); words reserved by the kind of file
  (10); the scheduling policies, a priority on every task, a tie to the earlier due time,
  missed periods coalesced and counted, a `single` already true at start firing (11); a
  `cal` whose EN is false writing nothing (12); elapsed time given in integer
  milliseconds (13); and a watchdog fault stopping the scan, writing every output 0 once
  and waiting for a restart (14). Then decisions 15–29: a controller declared from Elixir
  as plain data (15), the Elixir compiler never on the path that changes a running
  program (16), Spark kept out of logex (17); and the online edit of a lone instance,
  staged from the start (`Logex.Edit`, 18), a task's interval and priority changed while
  running and nothing else of it (19), an output an edit leaves undriven holding its last
  value (20), and decisions 21–29 its rules across a switch.
- **Configurations, tasks and function blocks**, Milestone 2 (decisions 30–54): a
  configuration of program instances on periodic and event tasks, wired to I/O points,
  sharing globals through `var_external` (`Logex.Configuration`), written as a `.logex`
  file or built from Elixir data; function blocks of a user's own, one a file, run with
  `cal`.
- **A configured plant's online edit**, OE-2 (decisions 55–66): `Logex.Configuration.Edit`,
  the same steps over a running resource.
- **Counters, timers, arithmetic, pulse coils and the forward jump**, Milestone 3
  (decisions 67–107).
- **The wall-clock runner**, Milestone 4 (decisions 108–143): `Logex.Runner` on a clock
  through device adapters, a watchdog on every task, a trip that switches every output
  off once, forcing kept in a file across a crash, and online edits while it runs.
- **Data types**, Milestone 5 (decisions 144–265 and 286–290): IEC's integer widths, signed
  and unsigned, a result past its width wrapping with no power; based literals; the typed
  counters and the long timers; the bit strings and their instructions, a bit whose number
  a tag holds; `real` and `lreal`; arrays of up to three dimensions, by literal subscripts
  or a subscript held in a tag, located at I/O points, and of timers, counters and blocks;
  and the typed conversions between them.
- **Retained values and a true warm restart**, Milestone 6 (decisions 266–285 and
  291–346): `retain` and `non_retain`, a warm restart keeping what is marked, the retained
  image as plain data, and the store a runner keeps on the host's disk.
- **The review of the whole codebase after Milestone 6** (decisions 347–531): every source
  text compiling or told why, a rung that writes nothing refused; held outputs that hold;
  each device's write and every file write limited in time; a store cut short refused and a
  fresh start that drops anything keeping a numbered copy; the suite's cost pins bounds
  measured within the run; the host contract named; a long refusal bounded and a compile
  run in a process of its own; a store written by another program warned of; the
  simulator taking the configuration's addresses; README's examples as files under
  `examples/`; CI naming a red run's failed tests, and this release step; and RV-26's,
  decisions 527, 528 and 530, a program's text read canonically before the store compares
  it, the stale store's warning sent to the subscribers too and the store written as
  `logex retain 3`, the release made only once RV-26 is on `main` (provisional).
