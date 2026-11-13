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
`PLAN.md`'s RV-22, questions 1 and 2). No release came before it, so it lists nothing that
changes what a running program wrote under an earlier release; a host who ran a commit of
`main` reads §7's notes, each saying what a landed decision replaced (provisional,
question 4). What it carries, by the work that built it:

- **Program organisation and the first online edit** (decisions 1–29): a program compiled
  to a named, stateless value run as instances (`Logex.compile/2`, `Logex.Runtime`),
  `call/4`, one diagnostic type carrying the file and line; declaring a controller from
  Elixir as plain data, the Elixir compiler never on the path that changes a running
  program; and the online edit of a lone instance, staged (`Logex.Edit`), decisions 21–29
  its rules across a switch.
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
  `examples/`; CI naming a red run's failed tests, and this release step. Of these,
  decisions 527, 528 and 530, a program's text read canonically before the store compares
  it, the stale store's warning sent to the subscribers and the store written as `logex
  retain 3`, are RV-26's to build, and this entry waits for it (provisional).
