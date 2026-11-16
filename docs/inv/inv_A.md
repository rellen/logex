# Inventory A: README.md lines 1-349

Range: the introduction, the stage summary, the host contract, "The dialect" (source syntax,
every bullet, the configuration file's lines, the history of the branch delimiters, the naming
rule) and the "Instructions" table (every row) with the paragraphs after it. About 6,630 words.

Conventions used here. Type: T tutorial, H how-to, R reference, E explanation, C contributor,
X drop. Destinations are slugs from PAGES.md; a slug marked NEW is proposed here. Line numbers
are README.md's as of 2026-11-15. A table row of the README is one physical line, so a row's
rules all cite that one line number.

Range-wide facts for the later writer:

- **No runnable example lives in this range.** There is no `<!-- file: path -->` marker, no
  `$ mix run` block and no `elixir` block in lines 1-349. The one fenced block (330-333) has no
  language tag and holds two diagnostic lines.
- Almost every unit here is type R. The range is the README's only statement of the source
  syntax and the only one-line-per-instruction table, so it is the raw material for
  `reference/source-syntax`, `reference/declarations-and-types`, `reference/literals`,
  `reference/instructions`, `reference/conversions` and `reference/cheatsheet`.
- Many bullets end with a pointer of the form ("Bit strings", below). Each such pointer marks
  content that is repeated, at greater length and with examples, in a later README section
  (outside this range). The later section is the fuller source; the bullet here is the
  summary.

---

## logex: title and introduction (lines 1-6, about 62 words)

**Reader and purpose.** A first-time visitor who wants to know in ten seconds what logex is.
It is the only text that should stay in the short landing README, rewritten.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 1-5 | What logex is: a Ladder Logic compiler and interpreter in Elixir; text compiled to a named, stateless value; run as instances, one scan at a time, on time the host injects | E | explanation/what-logex-is (and the landing README) |
| 5-6 | How it is built: no dependencies, no generated code, lexer and parser written by hand, forty-five modules in `lib/` | C | contributor/architecture-overview; one clause also in explanation/programs-as-data |

**Examples.** None.

**Rules stated.**

- logex compiles a ladder program written as text into a named, stateless value (3-4).
- It runs that value as instances, one scan at a time (4).
- Time is injected by the host (4-5).
- No dependencies and no generated code (5).
- The lexer and parser are written by hand (5-6).
- "forty-five modules in `lib/`" (6). Checked today: `lib/` holds 45 `defmodule`s in 40 files,
  so the count is right but will go stale; do not carry a count into the new pages.

**Citations.** None.

**Pictures.** A pipeline diagram: `.ld` text -> lexer -> parser -> compiler -> `%Logex.Program{}`
(data) -> `Logex.Runtime` instance -> scan, with "host gives inputs and time" entering at the
scan. It is the one picture a newcomer needs before anything else.

**Glossary.**

- *scan*: one run of a program's rungs, top to bottom (used at 4, never defined in this range).
- *instance*: a program being run, with its own state; the compiled program itself is stateless (4).
- *host*: the Elixir application that calls logex and gives it inputs and time (5).

**Hard to read.**

- (3-5) "It compiles a ladder program written as text into a named, stateless value, and runs
  it as instances, one scan at a time, with the time the host injects."

---

## Stage summary: "Stage: early, and honest about it." (lines 8-55, about 657 words)

**Reader and purpose.** An evaluator deciding whether logex does what they need: a list of
everything that works today. It is three sentences long; the first runs from line 8 to line 30.
It should become a short feature list on the landing page and in `explanation/what-logex-is`,
each item linking to its how-to or reference page. The plan item numbers (`M5-2` ...) are
history and belong to the contributor docs.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 8-11 | Instruction inventory by family: forty instructions (four timers, two for IEC's three counters and typed variants, seven of arithmetic and `sqrt`, eight bitwise and shift, a one-shot and two pulse coils, six comparisons, a forward jump to a label) and 182 typed conversions | E / R | explanation/what-logex-is; the counts as the head of reference/instructions and reference/cheatsheet |
| 12-16 | Language and API features: nested parallel branches, latch/unlatch across scans, power flow reset per rung, typed tag table, function blocks run with `cal`, public API `Logex.compile/2`, `compile_file/1`, `compile_files/1`, `Logex.Runtime` | E | explanation/what-logex-is |
| 17-19 | Two online edits: of a running instance (`Logex.Edit`), of a running configuration as a whole (`Logex.Configuration.Edit`) | E | explanation/what-logex-is (links to explanation/online-edit-model) |
| 19-24 | Scheduler: several programs as one configuration on periodic and event tasks, wired to I/O points, globals shared by `var_external`, from a `.logex` file or Elixir data | E | explanation/what-logex-is (links to explanation/tasks-and-scheduling) |
| 24-25 | Printer: an AST back to source, a routine round-trips, a configuration file too | E / C | explanation/what-logex-is; contributor/compile-pipeline |
| 25-28 | Runner: a configuration on the clock through device adapters, a watchdog on every task, a trip switching every output off once, input forcing, online edits while it runs | E | explanation/what-logex-is (links to explanation/trips-and-watchdogs) |
| 28-30 | Diagnostics promise: every mistake of a program or configuration reported with file and line, not an exception, a misspelt tag included | E / H | explanation/what-logex-is; howto/read-diagnostics |
| 30-45 | The type system, told as Milestone 5's fourteen plan items: bool and eight integer widths, wrap with no power, 56 integer conversions, based literals, typed counters, long timers, bit strings with 76 conversions and bit access, a bit number in a tag, reals with `sqrt`, 34 conversions and 16 truncations, arrays, tag subscripts, located arrays, arrays of instances | E / C | explanation/what-logex-is (the feature list, without item numbers); explanation/types-and-overflow (wrap with no power); contributor/project-status-and-history (the M5-n mapping) |
| 45-52 | Retained values, told as Milestone 6: `retain`, warm restart, a retained timer resumes without counting the outage, the image as plain data laid over by name and type, a runner's store on disk written at its ends and every `retain_period:` | E / C | explanation/what-logex-is; explanation/warm-and-cold-restarts; contributor/project-status-and-history |
| 52-53 | Pointer: logex is not a safety controller ("What logex is not") | E | explanation/safety-and-limits (must stay prominent on the landing page) |
| 54-55 | Pointer: `PLAN.md` is a full review of the codebase and says what is missing, in what order, and why | C | contributor/project-status-and-history |

**Examples.** None.

**Rules stated.** (Facts rather than rules; each is restated with its rules later in the README.)

- Forty instructions (8).
- Four timers (8).
- Two instructions run IEC's three counters and their typed variants (9).
- Seven instructions of arithmetic, and `sqrt` (9).
- Eight bitwise and shift instructions (10).
- A one-shot and two pulse coils (10).
- Six comparisons (10).
- A forward jump to a label (11).
- 182 typed conversions between its types (11). The parts are 56 (32-33) + 76 (36) + 34 (38) + 16 (38-39).
- Parallel branches nest to arbitrary depth (12).
- Latch/unlatch holds across scans (13).
- Power flow resets per rung (13).
- A typed tag table; every tag is declared in it (13-14).
- A function block of your own is written once in a file of its own, instantiated as often as needed and run with `cal` (14-15).
- The public API is `Logex.compile/2`, `Logex.compile_file/1`, `Logex.compile_files/1` and `Logex.Runtime` (15-16).
- An online edit changes a running instance's program, its function blocks included, without a restart: `Logex.Edit` (17-18).
- Another changes a running configuration as a whole: `Logex.Configuration.Edit` (18-19).
- A scheduler runs instances of several programs as one configuration on periodic tasks and on event tasks (19-20).
- The rising edge of a bool global makes an event task due (20-21).
- A configuration is wired to input and output points (21).
- Its programs share globals by name, such as an e-stop, through `var_external`: `Logex.Configuration` (21-23).
- A configuration is written as a configuration file (`.logex`) that names its `.ld` program types, or built from Elixir data (23-24).
- A printer turns an AST back into source so a routine round-trips; a configuration file round-trips too (24-25).
- A runner runs a configuration on the clock through device adapters: `Logex.Runner` (25-28).
- A watchdog on every task (26).
- A trip switches every output off once (26-27).
- Input forcing and online edits while the runner runs (27).
- A program or a configuration with mistakes gets every one reported with its file and line rather than an exception, a misspelt tag included (28-30).
- Types: `bool` and IEC's eight integer widths, `sint` to `ulint`, signed and unsigned (31).
- A result past its width wraps with no power (32).
- 56 conversions between the integer widths (32-33).
- Based literals, `16#ff` and `1_000` (33).
- IEC's typed counters, `ctu_int` and the rest (33-34).
- Long timers in nanoseconds, `ton_ltime` (34).
- IEC's four bit strings, `byte word dword lword`, with the bitwise instructions, bit access `status.3` and 76 conversions between a bit string and another type (34-36).
- A bit whose number a tag holds, `status.[n]`; its number out of range is a major fault that trips the plant (36-38).
- The reals, `real` and `lreal`, with `sqrt`, the 34 real conversions and the 16 truncations (38-39).
- Arrays of one to three dimensions of an elementary type; an element named by literal subscripts, `weights[3]` and `grid[1,7]` (39-40).
- An element named by a subscript held in a tag, `weights[slot]`; an index out of range is a major fault that trips the plant (40-42).
- Located arrays: one point an element at consecutive addresses, `var_global zone_t real[8] at card.i.0` (42-43).
- Arrays of timers, counters and blocks, `var lane_t ton[4]`; each element is run by literal subscripts and its members are read through a tag subscript (43-45).
- A tag, member, array, instance or global marked `retain` is kept by a warm restart; everything else starts again at its initial value (46-47).
- A retained timer resumes without counting the outage (47-48).
- The retained values are taken out as plain data and laid over a new instance or resource by name and type (48-49).
- A runner given a store keeps them in a file on the host's disk, written at its ends and every `retain_period:`, so that a crash and a fresh start come back to its last write (49-51).
- logex is not a safety controller (52-53).

**Citations.**

- `PLAN.md`'s Milestone 5, "landed whole" (30-31); `PLAN.md`'s Milestone 6, "landed whole" (45).
- Plan items: M5-2 and M5-4 (32), M5-3 (33), M5-7 (33), M5-5 (34), M5-6 (34), M5-8 (36), M5-9 (38), M5-10 (39), M5-11 (40), M5-12 (42), M5-13 (43), M5-14 (45).
- Forward pointers to README sections: "Retained values", "A retained global", "The store on disk" (51-52); "What logex is not" (53).
- `PLAN.md` as "a full review of the codebase" (54-55). Possibly stale: `CLAUDE.md` now says the plan and history are `PLAN.md` and the review of the whole codebase is `docs/review-2026-11-01.md`.

**Pictures.**

- A feature map as a table: rows "language", "types", "blocks", "scheduling", "running on the clock", "changing a running program", "keeping values", each with a one-line status and a link. It replaces the 300-word sentence.
- A block diagram of the layers: program -> instance -> configuration (tasks, globals, I/O points) -> runner (clock, devices, store).

**Glossary.**

- *power flow*: the true/false state passed from one instruction to the next along a rung (13).
- *latch/unlatch*: a coil pair that sets or clears a tag and leaves it alone otherwise (13).
- *tag*: a named, typed variable of a program (13).
- *function block*: a reusable routine with its own state, written in a file of its own, of which a program declares instances (14-15).
- *configuration*: several program instances scheduled together, with globals and I/O points (19-23).
- *periodic task / event task*: a task due every interval / due when a bool global rises (20-21).
- *global*: a configuration's variable that programs share by name (22).
- *input point, output point*: a device's input or output that a global is located at (21).
- *runner*: the process that runs a configuration on the wall clock (25-26).
- *device adapter*: the module through which the runner reads and writes a device (26).
- *watchdog*: a per-task limit whose overrun trips the plant (26).
- *trip*: the runner stopping and switching every output off once (26-27).
- *forcing*: overriding an input's value while the runner runs (27).
- *online edit*: changing a running program without a restart (17).
- *bit string*: `byte`, `word`, `dword`, `lword`, types holding bits rather than a number (34-35).
- *major fault*: a fault that trips the plant (37-38, 41-42).
- *located*: at a device's point, written `at <device>.i.<n>` (42-43).
- *retain / warm restart*: a mark on a declaration / the restart that keeps what is marked (46-47).
- *store*: the runner's file of retained values on the host's disk (49-50).

**Hard to read.**

- (8-30) The whole first sentence, one sentence of about 300 words: "Forty instructions, among
  them four timers, two that run IEC's three counters and their typed variants, seven of
  arithmetic and `sqrt`, eight bitwise and shift instructions, a one-shot and two pulse coils,
  six comparisons and a forward jump to a label, and beside them the 182 typed conversions
  between its types; parallel branches to arbitrary nesting depth, latch/unlatch that holds
  across scans, power flow that resets per rung, a typed tag table that every tag is declared
  in, function blocks of your own, each written once in a file of its own, instantiated as
  often as needed and run with `cal`, a public API (`Logex.compile/2`, `Logex.compile_file/1`,
  `Logex.compile_files/1` and `Logex.Runtime`), an online edit that changes a running
  instance's program, its function blocks included, without a restart (`Logex.Edit`), and one
  that changes a running configuration as a whole (`Logex.Configuration.Edit`), a scheduler
  that runs instances of several programs as one configuration on periodic tasks and on event
  tasks, which the rising edge of a bool global makes due, wired to input and output points,
  its programs sharing globals by name, such as an e-stop, through `var_external`
  (`Logex.Configuration`), written as a configuration file (`.logex`) that names its `.ld`
  program types or built from Elixir data, a printer that turns an AST back into source so a
  routine round-trips, as a configuration file does too, and a runner that runs a
  configuration on the clock through device adapters, a watchdog on every task, a trip
  switching every output off once, with input forcing and online edits while it runs
  (`Logex.Runner`) — all of that works and is tested end to end, and a program or a
  configuration with mistakes in it gets every one reported with its file and line rather than
  an exception, a misspelt tag included."
- (39-45) "and arrays, one to three dimensions, of an elementary type, each element named by
  literal subscripts, `weights[3]` and `grid[1,7]` (M5-11), or by a subscript held in a tag,
  `weights[slot]`, an index out of range a major fault that trips the plant (M5-12), located,
  one point an element at consecutive addresses, `var_global zone_t real[8] at card.i.0`
  (M5-13), and of timers, counters and blocks, `var lane_t ton[4]`, each element run by literal
  subscripts and its members read through a tag subscript (M5-14)."
- (45-52) "And since `PLAN.md`'s Milestone 6, landed whole, retained values and a true warm
  restart: a tag, member, array, instance or global marked `retain` is kept by a warm restart
  and everything else starts again at its initial value, a retained timer resuming without
  counting the outage; the retained values are taken out as plain data and laid over a new
  instance or resource by name and type; and a runner given a store keeps them in a file on
  the host's disk, written at its ends and every `retain_period:`, so that a crash and a fresh
  start come back to its last write ("Retained values", "A retained global" and "The store on
  disk", below)."

---

## The host contract (lines 57-68, about 131 words)

**Reader and purpose.** A host developer who needs to know which modules they may call and what
happens when they pass something wrong. Also a contributor, who needs to know which modules
must guard their arguments.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 57-61 | The contract's modules and its one rule: a host's mistake is refused with an `ArgumentError` whose message says what the function takes; nothing else escapes; every other module takes logex's own data unguarded and says so | R | reference/host-contract; the reason in adr/NNNN-host-contract (decision 514) |
| 61-66 | Modules the examples call that are inside the contract: `Logex.Configuration.Task`, `Global`, `Instance`, `Connection` (checked by `Logex.Configuration.new!/1`), `Logex.IO.Sim`, the runner's clocks, `Logex.Runner.Clock.Manual` | R | reference/host-contract |
| 66-68 | Calls the examples make outside the contract, on logex's own data, unguarded: `Logex.Diagnostic.format/1`, `Logex.FbType.ctu/0`, a `%Logex.Scan{}` that `Logex.Runtime.call/4` checks | R / C | reference/host-contract; contributor/architecture-overview (guarded and unguarded modules) |

**Examples.** None.

**Rules stated.**

- The host contract is `Logex`, `Logex.Runtime`, `Logex.Edit`, `Logex.Configuration`, `Logex.Configuration.Edit`, `Logex.Runner`, `Logex.IO` and `Logex.Tag.new!/5` (57-58).
- What a host hands any of them that it was not made for is refused with an `ArgumentError` (58-59).
- The `ArgumentError`'s message says what the function takes (59-60).
- Nothing else escapes them (60).
- Every other module takes logex's own data unguarded, and says so in its doc (60-61).
- Inside the contract, each refusing a host's mistake where it can make one: the configuration's elements `Logex.Configuration.Task`, `Global`, `Instance` and `Connection` (62-64).
- `Logex.Configuration.new!/1` checks those elements (64).
- `Logex.IO.Sim`, the simulated device, is inside the contract (64-65).
- The runner's clocks are inside the contract; `Logex.Runner.Clock.Manual` is the one a test moves (65-66).
- Outside the contract, unguarded, on logex's own data: `Logex.Diagnostic.format/1` on the diagnostics logex gives (66-67).
- Outside the contract: `Logex.FbType.ctu/0`, used beside a tag's type (67).
- Outside the contract: a `%Logex.Scan{}`; `Logex.Runtime.call/4` checks the one it is handed (67-68).

**Citations.** decision 514 (61); decision 523 (68). Note: `CLAUDE.md` names `Logex.Tag.new!/4,5`; the README names only `new!/5` (58).

**Pictures.** A table of modules in three columns: "in the contract (guarded)", "in the contract,
used by the examples", "outside (unguarded, logex's own data)". A boundary diagram, host on the
left and logex on the right, would show the same thing.

**Glossary.**

- *host contract*: the set of modules a host may call, each of which refuses a wrong argument with an `ArgumentError` (57-60).
- *unguarded*: a module that assumes its arguments are logex's own data and does not check them (60-61).
- *simulated device*: `Logex.IO.Sim`, a device with no hardware behind it (64-65).

**Hard to read.**

- (61-68) "The examples below call a few more: inside the contract, each refusing a host's
  mistake where it can make one, the configuration's elements, `Logex.Configuration.Task`,
  `Global`, `Instance` and `Connection`, which `Logex.Configuration.new!/1` checks,
  `Logex.IO.Sim`, the simulated device, and the runner's clocks, `Logex.Runner.Clock.Manual`
  the one a test moves; and outside it, on logex's own data, unguarded,
  `Logex.Diagnostic.format/1` on the diagnostics logex gives, `Logex.FbType.ctu/0` beside a
  tag's type and a `%Logex.Scan{}` that `Logex.Runtime.call/4` checks (decision 523)."
- (57-60) "**The host contract** is `Logex`, `Logex.Runtime`, `Logex.Edit`,
  `Logex.Configuration` and `Logex.Configuration.Edit`, `Logex.Runner`, `Logex.IO` and
  `Logex.Tag.new!/5`: what a host hands any of them that it was not made for is refused with
  an `ArgumentError` whose message says what it takes, and nothing else escapes them."

---

## The dialect: opening statement (lines 70-75, about 26 words)

**Reader and purpose.** Anyone arriving with ladder text from a vendor tool: logex will not read it.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 72-73 | logex is its own dialect; it does not import vendor neutral text and will not become an importer | E | explanation/the-dialect-and-iec; one line in explanation/safety-and-limits (what logex is not) |
| 75 | Lead-in "Source syntax today:" | X | drop (becomes the heading of reference/source-syntax) |

**Examples.** None.

**Rules stated.**

- logex is its own dialect (72).
- It does not aim to import vendor neutral text (72).
- It will not become an importer (72-73).

**Citations.** None. **Pictures.** None. **Glossary.** *dialect*: a ladder text syntax of logex's own, not a vendor's export format (72). **Hard to read.** None.

---

## The dialect: declarations (lines 77-88, about 169 words)

**Reader and purpose.** A program author writing the head of a `.ld` file: which lines declare
tags, which sections and types exist, and what a tag starts at.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 77-78 | The declaration line's form and place: before the first rung, one tag a line, `<section> <name> <type> [<initial>]` | R | reference/declarations-and-types; shown in tutorials/first-program |
| 78 | The four sections: `var`, `var_input`, `var_output`, `var_external` | R | reference/declarations-and-types |
| 78-84 | The type words: `bool`; the eight integer widths with their sizes; the four bit strings; `real`, `lreal`; timer and counter types; a function block's name; five example lines | R | reference/declarations-and-types |
| 85-86 | Every tag a rung uses must be declared; a `var_input` comes from outside and no instruction writes it; no initial value means 0 | R | reference/declarations-and-types |
| 86-88 | A timer and a function block instance are declared only with `var` and with no initial value; a timer's preset is the number on its `ton` | R | reference/declarations-and-types; reference/function-blocks |

**Examples.** None (inline code only: `var_output speed_sp dint 1200`, `var tare dint -120`, `var_input hz uint`, `var mask word 16#00ff`, `var ratio real 0.5`, `var t1 ton`, `var s1 seal`).

**Rules stated.**

- Declaration lines stand before the first rung (77).
- One tag a line (77).
- The form is `<section> <name> <type> [<initial>]` (77-78).
- The section is `var`, `var_input`, `var_output` or `var_external` (78).
- The type is `bool` (79).
- Or an integer width: `sint int dint lint` signed and `usint uint udint ulint` unsigned, of 8, 16, 32 and 64 bits (79-80).
- Or a bit string: `byte word dword lword` (80).
- Or a real: `real` or `lreal` (80-81).
- Or a timer or counter type: `ton` to `rto_ltime` and `ctu` to `ctud_ulint` (81-82). The full list is not given here.
- Or a function block's name (82).
- An initial value follows the type: `var_output speed_sp dint 1200`; a negative one `var tare dint -120`; a based one `var mask word 16#00ff`; a real `var ratio real 0.5` (82-84).
- Every tag a rung uses must be declared (85).
- A `var_input` is supplied from outside (85).
- No instruction may write a `var_input` (85-86).
- A tag with no initial value starts at 0 (86).
- A timer is declared only with `var` (86-87).
- A timer takes no initial value (87).
- A timer's preset is the number on the `ton` that runs it (87-88).
- An instance of a function block is declared the same way: only with `var`, no initial value (88).

**Citations.** Forward pointers "Integer widths", "Bit strings" and "Reals" (84).

**Pictures.** A table of the elementary types: word, kind (bool, signed integer, unsigned integer,
bit string, real), bits, range. A second small table of sections: who writes the tag (logic, host,
a global), may it take an initial value, may it take a qualifier. The second table would also
serve the qualifier and `var_external` bullets.

**Glossary.**

- *declaration line*: a line that names one tag, its section and its type (77).
- *section*: the first word of a declaration, saying where the tag's value comes from: `var`, `var_input`, `var_output`, `var_external` (78).
- *integer width*: one of the eight integer types, by size and sign (79-80).
- *initial value*: the value a tag starts at; 0 where none is written (86).
- *preset*: the number written on a timer's or counter's instruction, its time or count limit (87).

**Hard to read.**

- (77-84) "declaration lines before the first rung, one tag each: `<section> <name> <type>
  [<initial>]`, the section `var`, `var_input`, `var_output` or `var_external`, the type
  `bool`, an integer width, `sint int dint lint` signed and `usint uint udint ulint` unsigned,
  of 8, 16, 32 and 64 bits, a bit string, `byte word dword lword`, a real, `real` or `lreal`,
  a timer or counter type, `ton` to `rto_ltime` and `ctu` to `ctud_ulint`, or a function
  block's name, as in `var_output speed_sp dint 1200`, `var tare dint -120`, `var_input hz
  uint`, `var mask word 16#00ff` or `var ratio real 0.5` ("Integer widths", "Bit strings" and
  "Reals", below)."
- (86-88) "A timer, `var t1 ton`, is declared only with `var` and with no initial value: its
  preset is the number on the `ton` that runs it. So is an instance of a function block, `var
  s1 seal`"

---

## The dialect: qualifiers `retain` and `non_retain` (lines 89-102, about 177 words)

**Reader and purpose.** A program author who wants a value to survive a warm restart: where the
qualifier goes, which declarations take one, and what it means inside an instance.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 89-92 | The qualifier's place (straight after the section word), its two words, which sections take one, and its meaning at a warm restart | R | reference/declarations-and-types; reference/retained-values-and-store |
| 92-94 | An instance or array is retained whole; inside an instance the nearest mark on a member's path wins | R | reference/retained-values-and-store |
| 94-97 | `var_input` and `var_external` take none; the two words never share a line; both are reserved words | R | reference/declarations-and-types; reference/source-syntax (reserved words) |
| 97-98 | A configuration's global takes one: `var_global retain total_boxes dint 0` | R | reference/configuration-file |
| 98-102 | Where retained values are kept: in memory across `Logex.Runtime.restart/2,3` and `Logex.Runner.restart/2` with `:warm`; on disk by a runner given a store | R / H | reference/retained-values-and-store; howto/keep-values-across-a-restart; howto/keep-values-on-disk |

**Examples.** None (inline: `var retain count dint`, `var non_retain jog bool`, `var non_retain step dint`, `var retain s1 seal`, `var_global retain total_boxes dint 0`).

**Rules stated.**

- A qualifier stands straight after the section word (89).
- The qualifiers are `retain` and `non_retain` (89-90).
- A program's `var` and `var_output` take one (90).
- A block's three sections take one (90-91).
- A warm restart keeps a tag its line marks `retain` (91).
- A warm restart puts back every other tag (91-92).
- An instance or an array is retained whole (92).
- Inside an instance the nearest mark on a member's path wins (92-93).
- So a block's `var non_retain step dint` stays out of `var retain s1 seal` (93-94).
- A program's `var_input` takes no qualifier; the host gives its value and every restart keeps it (94-96).
- A `var_external` takes no qualifier; its global carries it (95-96).
- `retain` and `non_retain` never stand on one line together (96).
- Both are reserved: no tag is named `retain` or `non_retain` (96-97).
- A configuration's global takes one too: `var_global retain total_boxes dint 0` (97-98).
- Retained values are kept in memory across `Logex.Runtime.restart/2,3` with `:warm` (98-100).
- And across `Logex.Runner.restart/2` with `:warm` (100).
- And on the host's disk, across a crash and a fresh start, by a runner given a store (100-102).

**Citations.** `PLAN.md`'s M6-1 and M6-2 (92); M6-3 (98); forward pointers "A retained global" (98), "Retained values" and "The store on disk" (101-102).

**Pictures.** A before/after pair: a table of four tags (plain `var`, `var retain`, `var_input`,
a member marked `non_retain` inside a retained instance) with their values before a warm
restart and after it.

**Glossary.**

- *qualifier*: `retain` or `non_retain`, written straight after the section word (89).
- *warm restart*: a restart that keeps what is marked `retain` and puts everything else back to its initial value (91-92).
- *nearest mark*: of the marks on a member's path (the instance's line, the block's own line), the one closest to the member decides (92-94).
- *store*: the file in which a runner keeps retained values on disk (101).

**Hard to read.**

- (89-92) "a qualifier straight after the section word, `var retain count dint` or `var
  non_retain jog bool`, on a program's `var` and `var_output` and a block's three sections: a
  warm restart keeps a tag its line marks `retain` and puts back every other (`PLAN.md`'s M6-1
  and M6-2)."
- (94-97) "A program's `var_input`, whose value the host gives and every restart keeps, and a
  `var_external`, whose global carries it, take none, and the two words never stand on one
  line together."
- (92-94) "An instance or an array is retained whole, and inside an instance the nearest mark on
  a member's path wins, so a block's `var non_retain step dint` stays out of `var retain s1
  seal`."

---

## The dialect: `var_external` (lines 103-109, about 91 words)

**Reader and purpose.** A program author whose program must read or write a value shared across
a plant, such as an e-stop.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 103-105 | `var_external` names a configuration's global of the same name; logic reads and writes the global itself, one copy for every instance | R / H | reference/declarations-and-types; howto/share-a-global |
| 105-107 | Its type rules: elementary, exactly its global's, never widened, no initial value, no configuration keyword as its name | R | reference/declarations-and-types |
| 107-108 | A function block's file refuses it; a block takes a global through a `var_input` its `cal` fills | R | reference/function-blocks |
| 108-109 | A program run alone keeps it as a tag of its own, at 0, which its host cannot set | R | reference/declarations-and-types; reference/host-contract |

**Examples.** None (inline: `var_external estop bool`, `var_global estop bool`).

**Rules stated.**

- `var_external estop bool` names a configuration's global, its `var_global estop bool` (103).
- Logic reads and writes the global itself (104).
- There is one copy for every instance that declares it (104-105).
- A `var_external` is of an elementary type (105).
- Its type is exactly its global's, never widened (105-106).
- It takes no initial value (106).
- No configuration file's keyword names one (106-107).
- A function block's file refuses `var_external` (107).
- A block takes a global through a `var_input` its `cal` fills (107-108).
- A program run alone keeps a `var_external` as a tag of its own, at 0 (108-109).
- The host of a program run alone cannot set it (109).

**Citations.** Forward pointer "A global shared by name" (104).

**Pictures.** A diagram of two program instances and one global box, each instance's
`var_external estop` drawn as an arrow to the same box, beside a `var_input` drawn as a copy
made through a connection. It shows "the global itself, one copy" against "a copy in".

**Glossary.** *global*: a configuration's variable, declared `var_global` in a configuration file (103). *run alone*: a program run as an instance outside any configuration (108).

**Hard to read.**

- (105-107) "It is of an elementary type, exactly its global's, never widened, with no initial
  value, and no configuration file's keyword names one."
- (107-108) "A function block's file refuses it: a block takes a global through a var_input its
  `cal` fills."

---

## The dialect: case and reserved words (lines 110-113, about 56 words)

**Reader and purpose.** A program author choosing tag names, or puzzled by "reserved word" errors.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 110-112 | Mnemonics, sections and types are read in any case and are reserved in any case; tags are case-sensitive | R | reference/source-syntax |
| 112-113 | A function block's name is matched exactly and is not reserved | R | reference/source-syntax; reference/function-blocks |

**Examples.** None.

**Rules stated.**

- Mnemonics, sections and types may be written in any case: `xic`, `XIC`, `VAR_INPUT` (110).
- They are reserved: no tag may be named after one, in any case (110-111).
- So `ote`, `Ote`, `cal` and `bool` are never tags (111-112).
- Tags are case-sensitive: `aa` and `AA` are two tags (112).
- A function block's name is matched exactly, as a tag's is (112-113).
- A function block's name is not reserved (113).
- Other reserved words stated elsewhere in the range: `retain`, `non_retain` (96-97); `function_block` in a block's file only (190); a label is no reserved word (180-181); a configuration file's own words (230-235).

**Citations.** None.

**Pictures.** A table: kind of word (mnemonic, section, qualifier, type word, block type name,
tag, member, label, `function_block`, configuration keyword) against "case-sensitive?" and
"reserved where?". The rules are spread over six bullets (96, 110-113, 153, 180-184, 190,
230-235) and only a table brings them together.

**Glossary.** *mnemonic*: an instruction's short name, such as `xic` (110). *reserved*: a word that cannot name a tag (110-111).

**Hard to read.**

- (110-113) "mnemonics, sections and types in any case (`xic`, `XIC`, `VAR_INPUT`), and
  reserved: no tag may be named after one, in any case, so `ote`, `Ote`, `cal` and `bool` are
  never tags; tags are case-sensitive (`aa` and `AA` are two tags)."

---

## The dialect: operands, spacing, no parentheses, comments (lines 114-115 and 147-148, about 48 words)

**Reader and purpose.** A program author learning how a rung's text is cut into words.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 114-115 | Operands are separated by spaces; a number must be followed by one (`move 1bst aa` is an error naming `1bst`) | R | reference/source-syntax; the error in reference/diagnostics-and-warnings |
| 147 | No operand parentheses, no terminator | R | reference/source-syntax |
| 148 | `//` starts a comment that runs to the end of its line | R | reference/source-syntax |

**Examples.** None.

**Rules stated.**

- Operands are separated by spaces (114).
- A number must be followed by a space (114).
- `move 1bst aa` is an error naming `1bst`, not the number `1` and a tag `bst` (114-115).
- No operand parentheses (147).
- No terminator (147).
- `//` starts a comment (148).
- A comment runs to the end of its line (148).

**Citations.** None. **Pictures.** One annotated rung, `xic start xio stop ote motor // seal`, with each word labelled mnemonic, operand or comment. **Glossary.** *operand*: a tag, member, bit, element, label or literal that follows a mnemonic (114). **Hard to read.** None.

---

## The dialect: integer literals (lines 116-123, about 126 words)

**Reader and purpose.** A program author writing a number on a rung or in a declaration: how it
is spelled and what range it may have.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 116-118 | Spelling: digits, a `-` glued to them, no `+`; a sign begins a number and needs a space before it (`5-3`, `a-5` are errors) | R | reference/literals |
| 118-123 | A literal is judged by its slot: it must fit the slot's type; the ranges for a `dint`, a `uint`, a timer's preset, a long timer's, and a counter's by its `pv`'s type | R | reference/literals; ranges repeated per row in reference/instructions |

**Examples.** None.

**Rules stated.**

- An integer is digits, `5` (116).
- A negative one has its sign glued to its digits, `-5` (116).
- There is no `+` sign (116).
- A sign begins a number, so it needs a space before it (116-117).
- `move 5-3 aa` is an error naming `5-3` (117-118).
- `ote a-5` is an error naming `a-5` (118).
- A difference is written with `sub` (118).
- A literal is judged by the slot it goes into: it must fit that slot's type (118-119).
- A `dint` slot takes −2147483648 to 2147483647 (119-120).
- A `uint` slot takes 0 to 65535 (120).
- A timer's preset is 0 to 2147483647 ms (120).
- A long timer's preset is 0 to 9223372036854775807 ns (120-121).
- A counter's preset is any value of its `pv`'s type, as IEC's PV is (121-122).
- A `ctu` preset is −2147483648 to 2147483647 (122).
- A `ctu_int` preset is −32768 to 32767 (123).
- A `ctu_udint` preset is 0 to 4294967295 (123).

**Citations.** Forward pointer "Long timers" (121); IEC's PV (122).

**Pictures.** A table "slot -> range a literal must fit" (each elementary type, a timer's preset, a long timer's, a counter's by type).

**Glossary.** *slot*: the operand position a literal goes into; its type decides whether the literal fits (118-119). *`pv`*: a counter's preset member (122). *long timer*: a timer that counts in nanoseconds, a `..._ltime` type (120-121).

**Hard to read.**

- (118-123) "A literal is judged by the slot it goes into: it must fit that slot's type,
  −2147483648 to 2147483647 for a dint, 0 to 65535 for a `uint`, a timer's preset 0 to
  2147483647 ms, a long timer's 0 to 9223372036854775807 ns ("Long timers", below), and a
  counter's any value of its `pv`'s type, as IEC's PV is, −2147483648 to 2147483647 for a
  `ctu`, −32768 to 32767 for a `ctu_int` and 0 to 4294967295 for a `ctu_udint`"

---

## The dialect: based integers, underscores, real literals, spelling kept, size limits (lines 124-146, about 325 words)

**Reader and purpose.** A program author writing hexadecimal or binary masks, long numbers with
`_`, or reals; and anyone asking why a message or the printer shows a number exactly as typed.
This is one README bullet holding five separate topics.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 124-127 | A based integer, base 16 or 2, no sign, is the number it spells and is judged by its slot; `move 16#ffff i` into an `int` is refused where Logix would store −1 | R / E | reference/literals; the Logix contrast in explanation/types-and-overflow |
| 127-128 | Any number may hold a single `_` between two digits | R | reference/literals |
| 128-132 | The malformed numbers, each an error naming the number whole: other bases, a sign after `#`, a second `#`, a misplaced `_`, a digit outside its base, Logix's `5U` and `5L`; `_1` is a name | R | reference/literals; reference/diagnostics-and-warnings |
| 133-136 | A real literal's form: digits, `.`, digits, an optional exponent; the malformed reals, each an error naming the number at its column | R | reference/literals |
| 136-139 | A real literal is a value of the real its slot computes in, so in a `real`'s slot it is the nearest single (provisional) | R / E | reference/literals; explanation/types-and-overflow; howto/use-reals |
| 139-142 | A rung keeps each literal as typed: printed back as written, quoted so in every message; its value is what every rule judges, so an edit that only respells one changes nothing | R | reference/literals; reference/online-edit (a respelling changes nothing) |
| 142-143 | A configuration file's numbers take the same forms, quoted as written | R | reference/configuration-file |
| 144-146 | Size limits: a number at most 10,000 characters, a real's exponent at most 9,999; past either an error naming the number by its start; the store's and the forces file's readers refuse it too | R / C | reference/literals; reference/retained-values-and-store; reference/forcing; the reason in adr/NNNN (decision 369) |

**Examples.** None.

**Rules stated.**

- A based integer is written `16#ff`, `16#FF` or `2#1010_0000` (124).
- The base is 16 or 2 (124).
- A based integer has no sign (124).
- It is the number it spells (125).
- It is judged by its slot as any literal is (125).
- `move 16#ffff hz` puts 65535 in a `uint` (125-126).
- `move 16#ffff i` into an `int` is refused: `16#ffff` is outside −32768 to 32767 (126-127).
- Logix would store −1 there; logex does not (127).
- Any number may hold a single `_` between two digits: `1_000_000`, `-1_000`, `2#1010_0000` (127-128).
- Each of the following is an error naming the number whole (128-129):
  - `8#17` and `-8#17`: octal and every other base (129).
  - `16#-1`: a sign inside a based number (129).
  - `16#ff#`: a second `#` (130).
  - `16#_ff`, `1__0` and `1_`: a `_` not between two digits (130).
  - `2#102`: a digit outside its base (131).
  - Logix's `5U` and `5L`, as `1bst` is (131-132).
- `_1` is a name (132).
- A real literal is digits, a `.` and digits, then an exponent if wanted: `37.5`, `-0.25`, `1.5e3`, `2.5E-3` (133-134).
- A real literal may hold `_` between two digits, as an integer may (134).
- `1.`, `.5`, `1e5`, `1.5e+3` and Logix's `1.5L` are each an error naming the number, at its column (134-135).
- A real literal is a value of the real its slot computes in (136).
- That real is the destination's, the other side of a comparison's, or a conversion's source type (136-137).
- So in a `real`'s slot it is the nearest single (137-138).
- `eq sp 37.1` is true after `move 37.1 sp` (138).
- That rule is marked provisional (139).
- A rung keeps each literal as it was typed (139).
- Printed back, `move 16#00ff mask` reads as written; `007` and `-0` too (140).
- Every message quotes a literal as written: "`move` writes `16#ffff` into `i`" (140-141).
- A literal's value is what every rule judges (141-142).
- So an edit that only respells a literal changes nothing (142).
- A configuration file's numbers take the same forms (142-143).
- The configuration file's reader quotes each number as written (143).
- A number is at most 10,000 characters (144).
- A real's exponent is at most 9,999 (144).
- Past either limit it is an error naming the number by its start (145).
- The store's and the forces file's readers refuse such a number too (146).

**Citations.** "(provisional)" (139); decision 369 (146); forward pointer "Reals" (136); Logix named as the contrast (127, 131, 135).

**Pictures.**

- A railroad (syntax) diagram for a number: optional `-`, digits with single `_`, optional `.digits`, optional `e`/`E` with optional `-` and digits; and a second for `16#` / `2#` digits.
- A two-column table "accepted / refused, and why" built from 128-135: it is the clearest way to give the fourteen malformed forms.

**Glossary.**

- *based integer*: an integer written with its base and `#`, `16#ff` or `2#1010` (124).
- *Logix*: a vendor's controller family, used as the contrast for what logex refuses (127).
- *nearest single*: the single-precision value nearest the real written (138).
- *spelling*: a literal's text as typed, kept apart from its value (139-142).

**Hard to read.**

- (128-132) "Each is an error naming the number whole otherwise: `8#17` and `-8#17`, octal and
  every other base; `16#-1`, a sign; `16#ff#`, a second `#`; `16#_ff`, `1__0` and `1_`, a `_`
  not between two digits; `2#102`, a digit outside its base; and Logix's `5U` and `5L` as
  `1bst` is."
- (136-139) "A real literal is a value of the real its slot computes in, the destination's, the
  other side of a comparison's or a conversion's source type, so in a `real`'s slot it is the
  nearest single and `eq sp 37.1` is true after `move 37.1 sp` (provisional)."
- (139-142) "A rung keeps each literal as it was typed: printed back, `move 16#00ff mask` reads
  as written, `007` and `-0` too, and every message quotes a literal so, "`move` writes
  `16#ffff` into `i`", while its value is what every rule judges, so an edit that only
  respells one changes nothing."

---

## The dialect: names with `.` parts, members and bits (lines 149-159, about 171 words)

**Reader and purpose.** A program author reading a timer's done bit, a block's output, or one bit
of a status word.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 149-151 | A name may have `.` parts; a timer's members `.pre`, `.acc`, `.dn`, `.tt`, `.en`, their types, and who may write them | R | reference/source-syntax (the dotted name); reference/function-blocks (the member table) |
| 151-154 | A block instance's inputs and outputs are read anywhere; its own `var`s only inside it; nothing outside writes any member; members are case-sensitive; an undeclared member is an error | R | reference/function-blocks |
| 154-157 | Bit access: `status.3`, `t1.acc.3`; a bool wherever one goes, read by a contact and written by a coil; its number checked against the width | R / H | reference/source-syntax; howto/use-bit-strings |
| 157-158 | `status.[n]`: the bit whose number the integer tag `n` holds when the instruction runs | R | reference/source-syntax; howto/use-bit-strings; reference/faults (the out-of-range number) |
| 158-159 | A bit of a `bool` or of a real is an error; no tag is declared with a `.` | R | reference/source-syntax; reference/diagnostics-and-warnings |

**Examples.** None.

**Rules stated.**

- A name may have `.` parts: `t1.dn` is the member `dn` of the timer `t1` (149).
- A timer's members are `.pre` and `.acc`, `.dn`, `.tt` and `.en` (149-150). (An `rto`'s `.r` and the counters' members are given only in the table, 308-310.)
- `.pre` and `.acc` are `dint`; a long timer's are `lint` (150).
- Logic may write `.pre` and `.acc` (150).
- `.dn`, `.tt` and `.en` are `bool` (150-151).
- Only the timer's `ton` sets `.dn`, `.tt` and `.en` (151).
- A timer's members are read anywhere (151).
- A function block instance's inputs and outputs, `s1.run`, are read anywhere (151-152).
- A block instance's own `var`s are named only inside it (152).
- Nothing outside an instance writes any of its members (153).
- Members are case-sensitive (153).
- A dotted name that is not a declared member is an error (153-154).
- `status.3` is bit 3 of `status`, an integer or a bit string (154-155).
- `t1.acc.3` is a bit of a member (155).
- A bit is a bool wherever one goes: read by a contact and written by a coil (155-156).
- A bit's number is checked against the width (156).
- `status.[n]` is the bit whose number the integer tag `n` holds when the instruction runs (157-158).
- A bit of a `bool` is an error (158-159).
- A bit of a real is an error (158-159).
- No tag is declared with a `.` (159).

**Citations.** Forward pointers "Bit strings" (157) and "A bit number in a tag" (158).

**Pictures.**

- A table of the built-in types' members: member, type, meaning, who writes it (the instruction, logic, nothing). The table would merge 149-151 with rows 305-310.
- A drawn 16-bit word with bit 3 highlighted and `xic status.3` beside it, bit 0 on the right.

**Glossary.**

- *member*: a named part of a timer, counter or block instance, written after a `.` (149).
- *`.pre`, `.acc`, `.dn`, `.tt`, `.en`*: a timer's preset, accumulated time, done, timing and enabled members (150-151; the text gives the names and types, not the meanings).
- *bit access*: naming one bit of an integer or bit string as a bool, `status.3` (154-156).
- *contact / coil*: an instruction that reads a bool / one that writes a bool (156).

**Hard to read.**

- (149-151) "A timer's members are `.pre` and `.acc` (dint, a long timer's lint, which logic may
  write) and `.dn`, `.tt` and `.en` (bool, which only its `ton` sets), read anywhere."
- (154-159) "`status.3` is bit 3 of `status`, an integer or a bit string, and `t1.acc.3` of a
  member: a bool wherever one goes, read by a contact and written by a coil, its number
  checked against the width ("Bit strings", below); `status.[n]` is the bit whose number the
  integer tag `n` holds when the instruction runs ("A bit number in a tag", below); a bit of a
  `bool` or of a real is an error."

---

## The dialect: arrays and subscripts (lines 160-169, about 137 words)

**Reader and purpose.** A program author declaring an array and naming its elements.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 160-162 | Declaring an array: one to three sizes after the type, an initial list of one literal an element, the rightmost subscript varying fastest | R | reference/declarations-and-types; howto/use-arrays |
| 162-167 | Naming an element: one pair of brackets, literal subscripts from 0 split by `,` with no space, or integer tags read as the instruction runs; an element is a tag of the elements' type; a bit of one, `faults[2].3` | R | reference/source-syntax; howto/use-arrays |
| 167-169 | An array of timers, counters or block instances, `var lane_t ton[4]`: each element run by literal subscripts, its members read and written through any | R | reference/declarations-and-types; reference/function-blocks; howto/use-arrays |

**Examples.** None.

**Rules stated.**

- An array is declared with its sizes after its type (160).
- One to three sizes: `var weights int[8]`, `var grid int[4,8]`, `var cube real[2,3,4]` (160-161).
- An initial list holds one literal an element (161-162).
- In the initial list the rightmost subscript varies fastest: `var limits int[3] 10 20 30` (162).
- An element is its name and one pair of brackets (162-163).
- Literal subscripts start from 0 (163).
- Subscripts are split by `,` with no space: `weights[3]`, `grid[1,7]` (163-164).
- A subscript may be an integer tag, `weights[slot]` or `grid[1,c]`, read as the instruction runs (164-165).
- An element is a tag of the elements' type wherever one goes (165-166).
- A bit of an element, `faults[2].3`, is a bit as a tag's is (166).
- An array may hold timers, counters or a block's instances: `var lane_t ton[4]` (167-168).
- Each element of such an array is run by literal subscripts (168).
- Its members are read and written through any subscript, literal or tag (168-169).

**Citations.** Forward pointers "A subscript in a tag" (165), "Arrays" (167), "Arrays of instances" (169).

**Pictures.** A grid drawing of `var grid int[2,3] 1 2 3 4 5 6` showing which literal lands in
which element (row-major order: "the rightmost subscript varying fastest" is hard to see in words).

**Glossary.** *element*: one value of an array, named by subscripts in brackets (162-163). *subscript*: an element's index, from 0, a literal or an integer tag (163-165). *initial list*: the literals after an array's type, one an element (161-162).

**Hard to read.**

- (160-167) "an array is declared with its sizes after its type, one to three, `var weights
  int[8]`, `var grid int[4,8]`, `var cube real[2,3,4]`, and an initial list of one literal an
  element, the rightmost subscript varying fastest, `var limits int[3] 10 20 30`; an element
  is its name and one pair of brackets, literal subscripts from 0 split by `,` with no space,
  `weights[3]` or `grid[1,7]`, or integer tags, `weights[slot]` or `grid[1,c]`, read as the
  instruction runs ("A subscript in a tag", below), a tag of the elements' type wherever one
  goes, and a bit of one, `faults[2].3`, a bit as a tag's is ("Arrays", below)."

---

## The dialect: rungs, newlines, branches and labels (lines 170-184, about 223 words)

**Reader and purpose.** A program author learning what one line of a `.ld` file is: a rung. Also
the author who split a rung over two lines by mistake and got a refusal.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 170 | A newline ends a rung: LF, CRLF or a lone CR | R | reference/source-syntax |
| 170-175 | A rung that writes nothing and jumps nowhere is refused at its line, told that a newline ends a rung; the split-rung example and why it matters | R / E | reference/source-syntax; reference/diagnostics-and-warnings; the reason in adr/NNNN (decision 351) and explanation/the-dialect-and-iec |
| 175-178 | A rung that is a label alone is taken where a `jmp` names it and refused where none does; a label and a contact write nothing | R | reference/source-syntax; reference/instructions (`lbl`); howto/jump-over-rungs |
| 179 | `(` … `\|` … `)` open, separate and close a parallel branch group | R | reference/source-syntax; reference/instructions; tutorials/first-program (the seal-in branch) |
| 180-184 | A label: a name with no `.` parts, no reserved word, never a tag, not declared, its routine's own namespace, case-sensitive, two differing only in case refused | R | reference/source-syntax; howto/jump-over-rungs |

**Examples.** None.

**Rules stated.**

- A newline ends a rung (170).
- A newline is LF, CRLF or a lone CR (170).
- A rung that writes nothing and jumps nowhere is refused at its line (170-172).
- "Writes nothing" means: none of its instructions writes a tag, a member, a bit or a one-shot's storage bit, or runs an instance (171-172).
- "Jumps nowhere" means: no `jmp` on it (172).
- The refusal tells the author that a newline ends a rung (172-173).
- `xic start xio stop` on one line and `ote motor` on the next are two rungs: the first is refused, and the second would run the motor whatever stop does (173-174).
- The rule is Logix's: a rung's last instruction is an output (174-175).
- A rung that is a label alone, `lbl done`, is taken where a `jmp` of its routine names the label (175-176).
- Such a rung is the landing of a jump to the routine's end (176-177).
- It is refused as a rung that writes nothing where no `jmp` names it (177).
- A label and a contact, `lbl done xic a`, write nothing (so are refused) (177-178).
- `(` opens, `|` separates and `)` closes a parallel branch group (179).
- A label is what `jmp auto` and `lbl auto` name (180).
- A label is a name with no `.` parts (180).
- A label is no reserved word; `function_block` is among the reserved words in a function block's file (180-181).
- A label is never a tag: it is not declared (181-182).
- Labels are their routine's own namespace, so `lbl auto` may stand beside a tag `auto` (182-183).
- Labels are case-sensitive (183).
- Two labels that differ only in case are refused (183).

**Citations.** decision 351 (174); decision 367 (177); "Logix's rule" (174); forward pointer "A forward jump" (184).

**Pictures.**

- A drawn ladder rung for `xic start xio stop ote motor` beside its one line of text. This is the first place a drawing pays for itself.
- A drawn rung with a parallel branch for `( xic start | xic motor ) xio stop ote motor`, the two legs joined at both ends, with `(`, `|` and `)` marked on the drawing.
- A before/after pair for the split rung (173-174): the two-line mistake and the one-line fix, with the diagnostic.

**Glossary.**

- *rung*: one line of ladder: instructions run left to right, ending in an output (170-175).
- *output*: an instruction that writes; Logix requires a rung's last instruction to be one (174-175).
- *parallel branch group*: alternative paths on a rung, joined at both ends (179).
- *label*: the name a `lbl` gives a rung and a `jmp` jumps to (180).
- *routine*: a program's rungs, or a block's body: the unit a label belongs to (176, 182).
- *one-shot's storage bit*: the bool in which a one-shot keeps the power it saw last (171-172).

**Hard to read.**

- (170-175) "So a rung that writes nothing and jumps nowhere, none of its instructions writing a
  tag, a member, a bit or a one-shot's storage bit or running an instance, and no `jmp` on it,
  is refused at its line, told that a newline ends a rung: `xic start xio stop` on one line
  and `ote motor` on the next are that rung and one that runs the motor whatever stop does
  (decision 351, Logix's rule, a rung's last instruction an output)."
- (175-178) "A rung that is a label alone, `lbl done`, is taken where a `jmp` of its routine
  names the label, the landing of a jump to the routine's end, and refused as such a rung
  where none does (decision 367); a label and a contact, `lbl done xic a`, write nothing"
- (180-184) "a label, what `jmp auto` and `lbl auto` name, is a name with no `.` parts and no
  reserved word, `function_block` among them in a function block's file, and never a tag: it
  is not declared, labels are their routine's own namespace, so `lbl auto` may stand beside a
  tag `auto`, and they are case-sensitive, two that differ only in case refused ("A forward
  jump", below)"

---

## The dialect: files (a function block's file, the loaders) (lines 185-197, about 161 words)

**Reader and purpose.** A program author splitting logic into blocks, and a host developer
choosing between `compile/2`, `compile_file/1` and `compile_files/1`.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 185-187 | A file whose first rung is `function_block seal` is a function block type named as its file is; its declarations are its members, its rungs its body | R / H | reference/function-blocks; howto/write-a-function-block |
| 187-190 | `Logex.compile/2` returns it as a `%Logex.FbType{}`; a program gets it through `types:` or from `seal.ld` beside it with `Logex.compile_file/1`, and runs each instance with `cal` | R / H | reference/function-blocks; howto/write-a-function-block; howto/install-and-run |
| 190-191 | In a block's file `function_block` is reserved in any case; a block holds no instance of itself, at any depth | R | reference/function-blocks; reference/source-syntax (reserved words) |
| 192-194 | `Logex.compile_file/1` takes a `.ld` file only (any other name is a `:file` diagnostic); `Logex.compile_files/1` compiles several through one memo | R | reference/host-contract; reference/diagnostics-and-warnings; howto/install-and-run |
| 194-197 | Each file is read raw, off the VM's file server, so a compile waits on no file call made through the server; it shares the dirty I/O schedulers | C | contributor/compile-pipeline; adr/NNNN (decision 464) |

**Examples.** None.

**Rules stated.**

- A file whose first rung is `function_block seal` is a function block type, `seal` (185-186).
- Comments and blank lines are allowed before that first rung (185-186).
- The block type is named as its file is (186).
- Its declarations are its members (186-187).
- Its rungs are its body (187).
- `Logex.compile/2` returns a block's file as a `%Logex.FbType{}` (187-188).
- A program given the type in `types:` declares instances of it (188-189).
- A program compiled by `Logex.compile_file/1` with `seal.ld` beside it declares instances of it (188-189).
- Each instance is run with `cal` (189-190).
- In a block's file `function_block` is reserved, in any case (190).
- A block holds no instance of itself, at any depth (190-191).
- `Logex.compile_file/1` takes a `.ld` file only, exactly (192).
- Any other file name is a `:file` diagnostic (192-193).
- `Logex.compile_files/1` compiles several files, each as `compile_file/1` does (193).
- It compiles them through one memo, so a block several of them hold is compiled once (193-194).
- Each file is read raw, off the VM's file server (194-195).
- So a compile waits on no file call the VM makes through the server (195-196).
- A compile shares the VM's dirty I/O schedulers with every other raw file call (196-197).

**Citations.** decision 464 (196).

**Pictures.** A file-tree sketch: `motor.ld`, `seal.ld` beside it, an arrow "declares `var s1 seal`,
runs `cal s1 ...`", with the first line of `seal.ld` shown as `function_block seal`.

**Glossary.**

- *function block type*: what a file headed `function_block <name>` compiles to, a `%Logex.FbType{}` (185-188).
- *body*: a block's rungs (187).
- *memo*: the record of files already compiled within one `compile_files/1` call (194).
- *`:file` diagnostic*: a diagnostic about the file itself rather than a line of it (192-193).
- *raw read*: a file read that does not go through the VM's file server process (194-196).

**Hard to read.**

- (194-197) "Each file is read raw, off the VM's file server, so a compile waits on no file call
  the VM makes through the server (decision 464), though it shares the VM's dirty I/O
  schedulers with every other raw file call"
- (187-190) "A program given it in `types:`, or compiled by `Logex.compile_file/1` with
  `seal.ld` beside it, declares instances of it and runs each with `cal`."

---

## The dialect: a configuration file's lines (lines 199-240, about 531 words)

**Reader and purpose.** A plant author writing a `.logex` file: the five kinds of line, the
connection rules, and the reserved words. This is a second syntax summary set inside "The
dialect"; the full treatment is the README's later "A configuration" section (2690 onward).

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 199-201 | A `.logex` file has lines of its own, one element each, keywords in any case, `//` comments, line endings as a `.ld` file's | R | reference/configuration-file |
| 203-205 | `task <name> interval <ms> priority <p>`: a periodic task, 1 to 2147483647 ms, priority 0 (highest) to 65535; a number out of range is a diagnostic at its line | R / H | reference/configuration-file; howto/write-a-configuration-file |
| 206-209 | `task <name> single <global> [interval <ms>] priority <p>`: an event task, due when its bool trigger rises, and in the first cycle if it is already 1; with `interval`, also periodic while the trigger is 0; `single` first, as IEC orders them | R / H | reference/configuration-file; howto/use-an-event-task; reference/execution-model |
| 210-217 | `var_global`: types, initial values, arrays, located globals `at <device>.i.<n>` / `.q.<n>` (no initial value), the I/O list, `retain` / `non_retain` | R / H | reference/configuration-file; howto/map-io-points; howto/keep-values-across-a-restart |
| 218-220 | `program <instance> <type> [with <task>]`: an instance of `<type>.ld` beside the file, on a task or, without `with`, run in every cycle after the tasks | R | reference/configuration-file; reference/execution-model |
| 221-229 | A connection line `<instance>.<member> <global or constant>`: no arrow; every `var_input` connected once; widening; a `var_output` never drives an input point; one driver a global; arrays whole or by element; names resolve over the whole file | R / H | reference/configuration-file; howto/write-a-configuration-file |
| 230-235 | The configuration file's reserved words, reserved in that file kind only; `retain` and `non_retain` reserved in both kinds | R | reference/configuration-file; reference/source-syntax (the cross-file table of reserved words) |
| 236-239 | A `var_external` binds to the global of its name and type, checked once a type; nothing writes an input point through one; no connection names one; two warnings | R | reference/configuration-file; howto/share-a-global; reference/diagnostics-and-warnings |

**Examples.** None.

**Rules stated.**

- A configuration file is a `.logex` file (199).
- It has one element a line (199-200).
- Its keywords are read in any case (200).
- `//` comments (200).
- A line ends as a `.ld` file's does (200-201).
- `task <name> interval <ms> priority <p>` declares a periodic task (203).
- A periodic task's interval is 1 to 2147483647 ms (203).
- A priority is 0, the highest, to 65535 (204).
- A task's inputs stand in that order (`interval`, then `priority`) (204).
- A number out of range, a negative one among them, is a diagnostic at its line (204-205).
- `task <name> single <global> [interval <ms>] priority <p>` declares an event task (206).
- An event task is due in the cycle its trigger, a bool global, rises from 0 to 1 (206-207).
- It is due in the first cycle if its trigger is already 1 (207-208).
- With `interval` too, it is also due periodically while the trigger is 0 (208).
- It is due at most once a cycle (208-209).
- `single` comes first of the three inputs, as IEC orders them (209).
- `var_global <name> <type> [<initial>]` declares a global (210).
- A global is a `bool`, any integer width, a bit string or a real (210-211).
- `var_global sp real 0.1` is printed back as `0.1` (211).
- A global may be an array of an elementary type: `var_global limits int[3] 10 20 30` (211-212).
- "never located yet" is said of an array global (212). **Stale**: lines 42-43 and the later "A located array" section (4733) say located arrays landed with M5-13, `var_global zone_t real[8] at card.i.0`; `lib/logex/configuration.ex` agrees.
- `var_global <name> <type> at <device>.i.<n>` locates a global at an input point (212-213).
- `… at <device>.q.<n>` locates it at an output point (213).
- A located global takes no initial value (214).
- The `var_global … at` lines are the plant's I/O list (214).
- `var_global retain <name> <type> …` declares a global a warm restart keeps (215).
- `var_global non_retain …` states the default (215-216).
- The qualifier stands straight after `var_global` (216).
- A qualifier never stands on a located global (217).
- `program <instance> <type> [with <task>]` declares an instance of the program type in `<type>.ld` beside the file (218-219).
- With `with <task>` the instance runs on that task (219).
- Without `with` it runs in every cycle, after the tasks (219-220).
- `<instance>.<member> <global or constant>` is a connection (221).
- A connection has no arrow: the member's section fixes its direction (221-222).
- Every `var_input` is connected once (222).
- A `var_input` is connected to a global of its type, or of one that widens into it as `move`'s source does, or to a constant that fits it (222-224).
- A `var_output` drives a global of its type or one it widens into (224).
- A `var_output` never drives an input point (224-225).
- One connection at most drives a global (225).
- An array connects whole to a global array of its sizes, its elements widening as above (225-226).
- Or an array connects an element by itself: `m1.limits[2] 50` (226-227).
- An array `var_input` is connected whole or at every element (227).
- A far end may be an element of a global array: `m2.speed speeds[1]` (227-228).
- Names resolve over the whole file (228-229), so order of lines does not matter.
- `task single interval priority with program var_global at` are reserved in a configuration file (230).
- So are the type words, "`bool` and the eight integer widths" (230-231). **Looks incomplete**: `Logex.Configuration.Text` reserves every word of the type table (`Logex.Declarations.type_words/0`, so the bit strings and reals too) and also `continuous` and `watchdog` (M4-2), neither of which this bullet names. The `continuous` task and a task's `watchdog` word are not in this list of line forms at all (they are at README 3910 onward).
- These words are reserved in any case (232).
- They are reserved nowhere else: a `.ld` program may have a tag called `task` or `single` (232-233).
- But a `.ld` program may have no `var_external` of such a name, since its name is a global's too (233).
- `retain` and `non_retain` are reserved in both kinds of file (234).
- So nothing in a configuration file is named by either, a device among it (234-235).
- A program type's `var_external` binds to the global of its name and type (236).
- The binding is checked once a type, at its first instance's `program` line (236-237).
- Nothing writes an input point through a `var_external` (237-238).
- No connection names a `var_external` (238).
- Two instances that write one global through a `var_external` are a warning (238-239).
- An instance that writes through one a global a connection drives is a warning (239).

**Citations.** M6-3 (215); decision 223 (228); decision 298 (235); forward pointers "A configuration" (199), "A retained global" (217); "as IEC orders them" (209).

**Pictures.**

- An annotated `.logex` file of about eight lines with each line's kind labelled in the margin (task, event task, global, located global, program, connection).
- A wiring diagram: device points -> located globals -> connections -> an instance's `var_input`s and `var_output`s, and a `var_external` going straight to its global. It makes "no arrow, the member's section fixes its direction" visible.
- A small timing diagram for the event task: the trigger global against cycles, marking the cycles in which the task is due (rising edge; already 1 in the first cycle; periodic while 0).

**Glossary.**

- *configuration file*: a `.logex` file, one element a line (199-200).
- *periodic task*: a task due every `interval` ms (203).
- *priority*: a task's rank, 0 the highest (204).
- *event task*: a task due when its trigger rises (206-207).
- *trigger*: the bool global a `single` task watches (207).
- *cycle*: one round of the scheduler over the tasks that are due (207-209; not defined in this range).
- *located global*: a global at a device's input or output point, `at <device>.i.<n>` or `.q.<n>` (212-214).
- *I/O list*: the set of `var_global … at` lines of a plant (214).
- *connection*: a line joining an instance's `var_input` or `var_output` to a global or a constant (221).
- *widens into*: a type whose every value another type holds, as `move`'s source rule has it (223).
- *far end*: the global, element or constant on the right of a connection (227-228).
- *program type*: a compiled `.ld` program, of which a `program` line makes an instance (218).

**Hard to read.**

- (210-217) "`var_global <name> <type> [<initial>]`, a `bool`, any integer width, a bit string or
  a real, `var_global sp real 0.1` printed back as `0.1`, or an array of one, `var_global
  limits int[3] 10 20 30`, never located yet, and `var_global <name> <type> at
  <device>.i.<n>` or `… at <device>.q.<n>`, an input or an output point, which takes no
  initial value: the `var_global … at` lines are the plant's I/O list; since M6-3 `var_global
  retain <name> <type> …`, a global a warm restart keeps, or `var_global non_retain …`, which
  states the default, the qualifier straight after `var_global` and never on a located global
  ("A retained global", below)"
- (230-235) "`task single interval priority with program var_global at` and the type words,
  `bool` and the eight integer widths, are reserved in a configuration file, in any case, and
  nowhere else: a `.ld` program may still have a tag called `task` or `single`, though no
  `var_external`, whose name is a global's too; and `retain` and `non_retain`, reserved in
  both kinds of file, so nothing in a configuration file is named by either, a device among it
  (decision 298)"
- (222-225) "Every `var_input` is connected once, to a global of its type, or of one that
  widens into it as `move`'s source does, or a constant that fits it; a `var_output` drives a
  global of its type or one it widens into, never an input point, and one connection at most
  drives a global."

---

## The dialect: vocabulary, the branch delimiters' history, no importer (lines 241-265, about 284 words)

**Reader and purpose.** A reader with a vendor background who asks why logex's mnemonics look
familiar and its branches do not. It is explanation and history; no rule a program author needs.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 241-243 | The vocabulary is a conventional ladder mnemonic set; the branch delimiters used to be and are no longer | E | explanation/the-dialect-and-iec |
| 245-254 | The precedent: a vendor's current family exports uppercase, parenthesised, semicolon-terminated text with bracket-and-comma branches; an earlier family's ASCII format spells a branch `BST … NXB … BND`, which was logex's own form until §4·B1 landed | E / X | explanation/the-dialect-and-iec (two sentences); the detail to contributor/project-status-and-history and `docs/naming.md`, where it already is |
| 256-261 | Why `(` `\|` `)`: the three words share tag names' character set, so one missing space fused `nxb` into a neighbour and turned a parallel group into a series one with no error; punctuation cannot fuse | E / C | explanation/the-dialect-and-iec; adr/NNNN-punctuation-branch-delimiters |
| 263-265 | Borrowing a vocabulary is not accepting a format: no importer, none of that family's operand syntax (`I:003/4`, `T4:5/DN`) | E | explanation/the-dialect-and-iec; explanation/safety-and-limits |

**Examples.** None.

**Rules stated.**

- The vocabulary is a conventional ladder mnemonic set (241).
- The branch delimiters were once conventional too (`bst`, `nxb`, `bnd`, lowercase) and are no longer (241-242, 248-249).
- logex takes `(` `|` `)` for branches (256).
- The reason is lexical: the three words are drawn from the same character set as tag names, so a missing space fused `nxb` into a neighbouring identifier (256-258).
- The effect was a parallel group read as a series one with no error anywhere (258-259).
- Punctuation cannot fuse (259).
- logex will not grow an importer (264).
- logex takes none of that vendor family's operand syntax, `I:003/4`, `T4:5/DN` (264-265).

**Citations.** §4·B1 (248); `PLAN.md` §4·B1 "has the measurements" (260-261); `docs/naming.md` "the survey" (261). The vendor is never named in this passage ("That vendor", 245), though "Logix" is named at 127, 131, 135 and 174.

**Pictures.** A before/after pair: `bst xic a nxb xic b bnd ote c` and the same with one space
missing, `bst xic anxb xic b bnd ote c`, against `( xic a | xic b ) ote c`. It shows the bug
that the change removed better than the paragraph does.

**Glossary.**

- *branch start, next branch, branch end*: the spelled-out names of `BST`, `NXB`, `BND` (250-251).
- *series / parallel*: instructions one after another (AND) / on alternative legs (OR) (258).
- *importer*: a reader of a vendor's export format; logex has none (264).

**Hard to read.**

- (241-243) "The *branch delimiters used to be too*, and are no longer — which is worth stating
  plainly, because the survey that found the precedent is the same one that records giving it
  up."
- (246-252) "An **earlier** family's ASCII rung format is uppercase, space-separated and
  unparenthesised, and spells a branch `BST … NXB … BND` — which, until §4·B1 landed, was
  logex's own line with the case flipped and the rung delimiters dropped. Those three are that
  vendor's own mnemonics, glossed in the earlier family's programming-software guide as branch
  start, next branch and branch end; its controller reference bills the same three, under
  those spelled-out names, as instructions with an execution time and a word of memory each."
- (259-261) "That is a deliberate divergence from a real precedent rather than a coinage filling
  a gap, which is the more expensive kind — `PLAN.md` §4·B1 has the measurements and
  `docs/naming.md` the survey."

---

## The dialect: how names are chosen (lines 267-285, about 241 words)

**Reader and purpose.** A reader who asks why an instruction has the name it has, and a
contributor about to add an instruction.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 267-273 | Every new instruction is surveyed before it is written; the survey is `docs/naming.md`, one stanza a word; `test/logex/naming_test.exs` fails without one | C / E | contributor/compile-pipeline (adding an instruction) or NEW contributor/adding-an-instruction (the README, `CLAUDE.md` and `CONTRIBUTING.md` each state this procedure; one contributor page should own it); a sentence in explanation/the-dialect-and-iec |
| 273-276 | The naming rule, in order: the IEC name; else the clearest vendor mnemonic, saying which; never a new readable word for what has a standard name | E / C | explanation/the-dialect-and-iec; the same contributor page |
| 278-285 | Two findings: IEC 61131-3 defines contacts and coils as graphical symbols, so `xic` and `ote` have no standard name; Edition 4.0 (2025) removed Instruction List, so there is no IEC textual mnemonic vocabulary at all | E | explanation/the-dialect-and-iec |

**Examples.** None.

**Rules stated.**

- Every new instruction is surveyed before it is written (268).
- The survey asks: what IEC 61131-3 calls it, what the major vendor toolchains call it, what logex should call it (268-269).
- The survey lives in `docs/naming.md`, one stanza per mnemonic, declaration word, word that heads a file (`function_block`), or configuration file's word (270-272).
- `test/logex/naming_test.exs` fails if any of them reaches the compiler without a stanza (273).
- Rule 1: if IEC names the operation, take the IEC name (274).
- Rule 2: if IEC supplies only a graphical element, take the clearest vendor mnemonic and say which (274-275).
- Rule 3: never invent a readable word for a thing that already has a standard name (275-276).
- IEC 61131-3 defines ladder contacts and coils as graphical symbols with English names, not mnemonics (279-280).
- So `xic` and `ote` have no standard name to conform to (280-281).
- Edition 4.0 (2025) removed Instruction List from the standard (281).
- There is no longer any IEC textual mnemonic vocabulary (283-284).
- A mnemonic ladder language is necessarily a dialect (284-285).

**Citations.** [`docs/naming.md`](docs/naming.md) (270); `test/logex/naming_test.exs` (273); IEC 61131-3 Edition 4.0 (2025), its Scope quoted (281-283).

**Pictures.** A three-step flowchart of the naming rule: "Does IEC name the operation?" -> take it,
lowercased; "Does IEC give only a graphical element?" -> clearest vendor mnemonic, cite it;
otherwise never coin a word.

**Glossary.**

- *IEC 61131-3*: the international standard for programmable controller languages (268).
- *Instruction List (IL)*: IEC's former textual mnemonic language, removed in Edition 4.0 (281).
- *stanza*: one entry of `docs/naming.md`, the survey of one word (270).
- *LD, FBD, ST*: ladder diagram, function block diagram, structured text (282-283).

**Hard to read.**

- (270-273) "The survey lives in [`docs/naming.md`](docs/naming.md), one stanza per mnemonic,
  declaration word, word that heads a file, `function_block`, or configuration file's word,
  and `test/logex/naming_test.exs` fails if any of them reaches the compiler without one."
- (278-281) "Two findings from that survey are worth stating up front, because they explain why
  the rule has two tiers. IEC 61131-3 defines ladder contacts and coils as *graphical symbols*
  with English names, not mnemonics — so for `xic` or `ote` there is no standard name to
  conform to."

---

## Instructions: the table as a whole (lines 287-321, about 2,730 words)

**Reader and purpose.** Every program author, every time: what an instruction takes and what it
does. It is a three-column Markdown table ("Written as", "Operands", "Does") of 31 rows, each
row one physical line of up to 190 words. A row packs operand rules, the true-rung behaviour,
the false-rung behaviour, the power passed on, faults, compile refusals, warnings and
online-edit rules into one cell. It is the densest text in the range and the main source for
`reference/instructions`.

**Every mnemonic the table names** (40 instructions, row line in brackets):

- Contacts and coils: `xic` (291), `xio` (292), `ote` (293), `otl` (294), `otu` (295).
- Move: `move` (296); the former name `mov` (296).
- Conversions, 182 in four families: the 34 real conversions, named `real_to_int`,
  `lreal_to_real`, `dint_to_real` (297); the 16 truncations `<real>_trunc_<integer>`, named
  `real_trunc_int` (298); the 56 integer conversions `<from>_to_<to>`, named `dint_to_int`,
  `dint_to_sint` (300); the 76 bit-string conversions, named `word_to_int`, `byte_to_word`,
  `int_to_dword` (317). The conversions are not counted among the forty.
- Arithmetic: `add`, `sub`, `mul` (311), `div`, `mod` (312), `neg`, `abs` (313); `sqrt` (299).
- Comparisons: `eq`, `ne`, `lt`, `gt`, `le`, `ge` (304).
- Bitwise and shifts: `and`, `or`, `xor` (314), `not` (315), `shl`, `shr`, `rol`, `ror` (316).
- Timers: `ton` (305), `tof` (306), `tp` (307), `rto` (308). Instance types named: `ton`,
  `tof`, `tp`, `rto`, `ton_ltime`, `tof_ltime`, `tp_ltime`, `rto_ltime`.
- Counters: `ctu` (309), `ctd` (310). Instance types named: `ctu`, `ctd`, `ctud`, `ctu_int`,
  `ctud_ulint`, `ctd_udint` (and `ctu_udint` at 123). The full list of typed counters is not
  in this range.
- One-shot and pulse coils: `ons` (301), `osr` (302), `osf` (303).
- Jump and label: `jmp` (319), `lbl` (320).
- Function block call: `cal` (318).
- Branch group, no mnemonic: `( … | … )` (321).

Count check: 5 + 1 + 7 + 1 + 6 + 8 + 4 + 2 + 3 + 2 + 1 = 40, which agrees with line 8.

**Notes for the rewrite (apply to every family below).**

- The table has no fixed schema. Some rows say what happens on a false rung and what power
  passes on; others do not. Missing from the table: the false-rung behaviour and power out of
  `move` (296); the power out of `xic`/`xio` on a false rung (implied); the false-rung
  behaviour of the truncations (298) and of `not` (315, "as `and`'s" covers operands only);
  whether anything may follow `tof`, `tp`, `rto` and `ctd` (305 and 309 say "nothing may
  follow it on its path" for `ton` and `ctu` only); the power out of the timers and counters.
  `reference/instructions` should give each instruction the same fields: operands, true rung,
  false rung, power out, faults, compile refusals, warnings. The gaps must be filled from the
  later README sections or the moduledocs, not guessed.
- Row order is not by family: `sqrt` (299) sits between two conversion rows, the one-shots
  (301-303) before the comparisons, the conversions on rows 297, 298, 300 and 317.
- The phrase "Anything may follow it on the rung" (300, 302, 311, 314, 319) and its opposite
  "nothing may follow it on its path" (305, 309) are one rule seen from two sides: the
  compiler refuses an instruction after one whose power out is not settled. Line 311 gives
  the reason once: "its power out is IEC's ENO".

**Citations (whole table).** M1-2 (296); M5-6 (305); M5-5 (309); IEC's Figure 11 (296, 311, 314);
IEC's typed conversions (297, 300); IEC's TRUNC (298); IEC's SQRT (299); IEC's positive and
negative transition-sensing coils (302, 303); IEC's TOF (306), TP (307); "the conventional RTO"
(308); IEC's ENO (311); IEC's remainder (312); IEC's typing (315). No decision number and no
"provisional" mark appears in the table itself.

---

## Instructions: contacts and coils (lines 291-295, about 107 words; with 343-348)

**Reader and purpose.** A beginner writing a first rung: the five instructions every program uses.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 291-292 | `xic` (examine if closed) passes power when its bool tag is 1; `xio` (examine if open) when it is 0 | R / T | reference/instructions; reference/cheatsheet; tutorials/first-program |
| 293 | `ote` (output energize) writes 1 on a true rung and 0 on a false rung; not a `var_input` | R / T | reference/instructions; reference/cheatsheet; tutorials/first-program |
| 294-295 | `otl` (output latch) writes 1 on a true rung; `otu` (output unlatch) writes 0 on a true rung; each leaves the tag alone otherwise | R | reference/instructions; reference/cheatsheet |

**Examples.** None.

**Rules stated.**

- `xic aa` takes a bool tag (291).
- `xic` is "examine if closed": it passes power when `aa` is 1 (291).
- `xio aa` takes a bool tag (292).
- `xio` is "examine if open": it passes power when `aa` is 0 (292).
- `ote xx` takes a bool tag that is not a `var_input` (293).
- `ote` is "output energize": it writes 1 on a true rung (293).
- `ote` writes 0 on a false rung (293, in bold).
- `otl xx` takes a bool tag that is not a `var_input` (294).
- `otl` is "output latch": it writes 1 on a true rung and leaves the tag alone otherwise (294).
- `otu xx` takes a bool tag that is not a `var_input` (295).
- `otu` is "output unlatch": it writes 0 on a true rung and leaves the tag alone otherwise (295).
- (From 154-156: a bit, `status.3`, goes wherever a bool tag goes, read by a contact and written by a coil.)
- (From 343: `xic` and `xio` are complementary; exactly one of them passes power. See the last section.)

**Citations.** None in these rows.

**Pictures.**

- The ladder symbols: `xic` as `-| |-`, `xio` as `-|/|-`, `ote` as `-( )-`, `otl` as `-(L)-`, `otu` as `-(U)-`, each beside its mnemonic. A newcomer from a graphical tool needs this mapping first.
- A truth table: tag value against power in, giving power out, for `xic` and `xio`; rung state against the value written, for `ote`, `otl`, `otu`.
- A timing diagram contrasting `ote` and `otl`/`otu`: the rung's power against the tag over six scans.

**Glossary.**

- *examine if closed / examine if open*: the conventional names of the two contacts (291-292).
- *output energize, output latch, output unlatch*: the conventional names of the three coils (293-295).
- *true rung / false rung*: a rung whose power reaches the instruction, or does not (293).
- *passes power*: gives a true state to the instruction after it (291).

**Hard to read.** None; these five rows are the plainest text in the range.

---

## Instructions: `move` and the conversions (lines 296-298, 300 and 317, about 500 words)

**Reader and purpose.** A program author copying a value into a tag of another type: which
copies `move` allows, which need a named conversion, and what a conversion does with a value
that does not fit.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 296 | `move`: copies a literal or a tag into a tag in the destination's type; the source is of that type or one IEC's Figure 11 widens into it; any other is refused naming its conversion; a literal must fit | R / H | reference/instructions; reference/cheatsheet; howto/choose-integer-widths-and-convert |
| 296 | `mov` was the name until M1-2 and now gets a diagnostic pointing to `move` | X / R | drop the history; keep the diagnostic in reference/diagnostics-and-warnings |
| 297 | The 34 real conversions (`real_to_int`, `lreal_to_real`, …): round to nearest, ties to even; low bits and no power where it does not fit; an integer into a real rounded once; an lreal past a real's range gives the largest value with no power | R / H | reference/conversions; howto/use-reals; explanation/types-and-overflow |
| 298 | The 16 truncations `<real>_trunc_<integer>`: IEC's TRUNC, toward zero; low bits and no power where it does not fit | R / H | reference/conversions; howto/use-reals |
| 300 | The 56 integer conversions `<from>_to_<to>`: writes the value where it fits, with power; else keeps its low bits, two's complement where signed, no power, no fault; anything may follow | R / H | reference/conversions; howto/choose-integer-widths-and-convert; explanation/types-and-overflow |
| 317 | The 76 bit-string conversions (`word_to_int`, `byte_to_word`, …): a binary transfer, never a sign extension | R / H | reference/conversions; howto/use-bit-strings |

**Examples.** None.

**Rules stated.**

`move` (296):

- `move 123 hh` takes a source, then a destination.
- The destination is not a `var_input`.
- The destination is of the source's type or one the source's type widens into.
- It copies a literal or a tag into a tag, in the destination's type.
- The source is of the destination's type or one IEC's Figure 11 widens into it, for example a `uint` into a `dint`.
- Any other source type is refused, the message naming the conversion to use.
- A literal source must fit the destination.
- The instruction was `mov` until M1-2; `mov` now gets a diagnostic pointing to `move`.
- Not stated in the row: what `move` does on a false rung and what power it passes on.

The 34 real conversions (297):

- Written `real_to_int a dst`, `lreal_to_real a dst` "and the 32 others".
- The source is of the `from` type or one that widens into it.
- The destination is a tag of the `to` type.
- One of `from` and `to` is a real.
- The destination is not a `var_input`.
- A literal source is a warning.
- They are IEC's typed conversions.
- Into an integer: the nearest integer, a tie going to the even neighbour (`real_to_int` of 2.5 is 2 and of 3.5 is 4).
- Into an integer where the nearest does not fit: its low bits, with no power (`real_to_int` of 40000.7 is −25535).
- Into a real: its nearest value, an integer rounded once (`dint_to_real` of 16777217 is 16777216.0).
- An `lreal` past a `real`'s range: the `real`'s largest value, with no power.
- False: writes nothing, passes no power.

The 16 truncations (298):

- Written `real_trunc_int a dst` "and the 15 others", `<real>_trunc_<integer>`.
- The source is a `real` or an `lreal`; the destination is an integer tag.
- It is IEC's TRUNC: the source with its fraction dropped, toward zero (`real_trunc_int` of −1.6 is −1).
- Where that does not fit: its low bits, with no power (40000.7 gives −25536).
- Not stated in the row: the false-rung behaviour, the `var_input` rule, the literal-source warning.

The 56 integer conversions (300):

- Written `dint_to_int a dst` "and the 55 others", `<from>_to_<to>`.
- The source is of the `from` integer type or one that widens into it.
- The source is a tag, a member or a literal.
- The destination is a tag of the `to` type, which the instruction writes; not a `var_input`.
- A literal source is a warning.
- They convert between two integer widths, IEC's typed conversions.
- True, the value fits: writes it, with power.
- True, the value does not fit: keeps its low bits, two's complement where signed, and passes no power.
- That is no fault.
- `dint_to_sint` of 129 gives −127.
- False: writes nothing, passes no power.
- Anything may follow it on the rung.

The 76 bit-string conversions (317):

- Written `word_to_int a dst`, `byte_to_word a dst` "and the 74 others".
- The source is of the `from` type or one that widens into it.
- The destination is a tag of the `to` type, which it writes.
- A literal source is a warning.
- It is a binary transfer between a bit string and another bit string or an integer type.
- It is never a sign extension: `int_to_dword` of −1 is 16#0000ffff.
- `word_to_int` of 16#ffff is −1.
- True: writes and passes power.
- False: writes nothing, passes no power.

**Citations.** M1-2 (296); IEC's Figure 11 (296); IEC's typed conversions (297, 300); IEC's TRUNC (298).

**Pictures.**

- The widening diagram (IEC's Figure 11) as a drawn lattice: an arrow from each type to every type it widens into (`sint` -> `int` -> `dint` -> `lint`, `usint` -> `uint` -> ..., `usint` -> `int`, integers -> reals, `bool` -> bit strings). "One it widens into" is used on eleven rows and never drawn.
- A matrix of the 182 conversions: `from` type down, `to` type across, each cell one of "move (widens)", "`x_to_y`", "`x_trunc_y`", "none". It answers "which instruction do I write" at a glance.
- A bit-level before/after for `dint_to_sint` of 129 -> −127 and `int_to_dword` of −1 -> 16#0000ffff, to show "keeps its low bits" and "never a sign extension".

**Glossary.**

- *widens into*: type A widens into type B where B holds every value of A; IEC's Figure 11 gives the pairs (296).
- *typed conversion*: an instruction named `<from>_to_<to>` that converts between two named types (297, 300).
- *low bits*: the bits of a value that fit the destination's width, the rest dropped (297, 300).
- *two's complement*: the bit pattern of a signed integer (300).
- *a tie to the even neighbour*: rounding a value halfway between two integers to the even one (297).
- *binary transfer*: copying the bit pattern unchanged, not the numeric value (317).
- *sign extension*: filling the upper bits with the sign bit; the bit-string conversions never do it (317).
- *with no power*: the instruction writes its result but the rung is false after it (297).

**Hard to read.**

- (297) "a real converted, IEC's typed conversions — into an integer the nearest, a tie to the
  even neighbour (`real_to_int` of 2.5 is 2 and of 3.5 is 4), and where that does not fit its
  low bits, with no power, `real_to_int` of 40000.7 −25535; into a real its nearest value, an
  integer rounded once, `dint_to_real` of 16777217 16777216.0, an lreal past a real's range
  its largest value with no power."
- (296) "copies a literal or a tag into a tag, in the destination's type: the source is of that
  type or one IEC's Figure 11 widens into it, a `uint` into a `dint`, and any other is refused
  naming its conversion; a literal must fit the destination (`mov` until M1-2; it now gets a
  diagnostic pointing here)"
- (300) "converts between two integer widths, IEC's typed conversions — true: writes the value
  where it fits, with power, and where it does not keeps its low bits, two's complement where
  signed, and passes no power, with no fault: `dint_to_sint` of 129 gives −127."

---

## Instructions: arithmetic and `sqrt` (lines 299 and 311-313, about 432 words)

**Reader and purpose.** A program author doing sums on a rung: operand types, what happens on
overflow and on a zero divisor, and how a later instruction learns that the result is wrong.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 311 | `add`, `sub`, `mul`: operands, result in `dst`'s type, integer wrap with no power and no fault, real rounding and saturation, sources read first, power out is IEC's ENO | R / H | reference/instructions; reference/cheatsheet; howto/do-arithmetic; explanation/types-and-overflow |
| 312 | `div`, `mod`: truncation toward zero, the remainder's sign, the zero divisor (writes 0, no power, a minor fault), a literal 0 refused, minimum divided by −1 | R / H | reference/instructions; howto/do-arithmetic; reference/faults |
| 313 | `neg`, `abs`: one source; `neg` into an unsigned type refused; a signed minimum wraps to itself with no power; a real's is exact | R / H | reference/instructions; howto/do-arithmetic |
| 299 | `sqrt`: IEC's SQRT into a real or lreal; a negative source writes 0.0, passes no power and is the minor fault `:negative_sqrt`; a literal negative refused | R / H | reference/instructions; howto/use-reals; reference/faults |

**Examples.** None.

**Rules stated.**

`add a b dst`, `sub a b dst`, `mul a b dst` (311):

- Two number sources, each a tag, a member or a literal.
- Each source is of `dst`'s type or one IEC's Figure 11 widens into it.
- Then an integer or real tag or member, which it writes; not a `var_input`.
- Any other source is refused, the message naming its conversion.
- Add, subtract (`a − b`), multiply, computed in `dst`'s type.
- True: writes the result and passes power.
- A result outside an integer type wraps, keeping its low bits, in two's complement where signed.
- Examples: 2147483647 + 1 is −2147483648 in a `dint`; 127 + 1 is −128 in an `sint`; 0 − 1 is 255 in a `usint`.
- A wrapped result passes no power on that scan.
- A wrap is no fault.
- A real's result is rounded to its nearest value, a `real`'s to a single: `add 16777216 1.0 x` is 16777216.0 in a `real`.
- A real's result past its range is its largest value, the sign kept, with no power.
- False: writes nothing, passes no power.
- The sources are read first, so `add total flow total` runs a total on.
- Anything may follow on the rung: its power out is IEC's ENO.

`div a b dst`, `mod a b dst` (312):

- Operands as `add`'s; `mod` takes integers only.
- `div` of integers truncates toward zero: `div -7 2 q` is −3.
- `div` of reals is exact.
- `mod` is IEC's remainder, its sign the dividend's: `mod -7 3 r` is −1.
- A zero divisor writes 0, or 0.0 into a real.
- A zero divisor passes no power.
- A zero divisor is a minor fault the scan reports.
- The fault appears in `state.faults`, or as a cycle's `{:fault, task, instance, fault}` event.
- A literal 0 divisor is refused (at compile).
- A signed type's minimum divided by −1 wraps to itself, `div -2147483648 -1` to −2147483648 in a `dint`, with no power.

`neg a dst`, `abs a dst` (313):

- A source as `add`'s, then an integer or real tag or member it writes; not a `var_input`.
- `neg` into an unsigned type is refused.
- Negate, absolute value: as `add`, with one source.
- A signed type's minimum, −2147483648 in a `dint`, has no positive twin, so each of `neg` and `abs` wraps to the minimum itself, with no power.
- A real's is exact: `neg -2.5 r` is 2.5.

`sqrt a dst` (299):

- The source is a number of `dst`'s type or one that widens into it.
- The destination is a real or an lreal tag, which it writes.
- Square root, IEC's SQRT, computed in `dst`'s type.
- True: writes the root and passes power.
- A negative source writes 0.0.
- A negative source passes no power.
- A negative source is the minor fault `:negative_sqrt`.
- A literal negative source is refused (at compile).
- False: writes nothing, passes no power.

**Citations.** IEC's Figure 11 (311); IEC's ENO (311); IEC's remainder (312); IEC's SQRT (299). The zero-divisor fault's name is not given in row 312; `:negative_sqrt` is named in row 299.

**Pictures.**

- A number-line or clock-face drawing of wrap in an `sint`: 127 + 1 -> −128, with the power out dropping.
- A drawn rung showing ENO in use: `add a b total` then `ote ok`, with `ok` 0 on the scan that wraps. It shows what "passes no power" is for.
- A table of the edge cases: operation, operands, value written, power out, fault (wrap; zero divisor; minimum / −1; `neg` and `abs` of the minimum; negative `sqrt`; real past its range).

**Glossary.**

- *wraps*: an out-of-range integer result keeps only its low bits, so it comes round to the other end of the range (311).
- *ENO*: IEC's "enable out", the power an instruction passes on; false here when the result is not the true answer (311).
- *minor fault*: a fault a scan records and runs on through (312; contrast "major fault", 37-38).
- *`state.faults`*: where an instance's scan reports its faults (312).
- *runs a total on*: accumulates, the destination also being a source (311).
- *truncated toward zero*: the fraction dropped, so −3.5 gives −3 (312).

**Hard to read.**

- (311) "add, subtract (`a − b`), multiply, in `dst`'s type — true: writes the result and passes
  power; a result outside an integer type wraps, keeping its low bits, in two's complement
  where signed (2147483647 + 1 is −2147483648 in a `dint`, 127 + 1 −128 in an `sint`, 0 − 1
  255 in a `usint`), and passes no power on that scan, with no fault; a real's result is
  rounded to its nearest value, a `real`'s a single, so `add 16777216 1.0 x` is 16777216.0 in
  a `real`, and past its range is its largest value, the sign kept, with no power."
- (313) "negate, absolute value — as `add`, one source: a signed type's minimum, −2147483648 in
  a `dint`, has no positive twin, so each wraps to it itself for it, with no power; a real's
  is exact, `neg -2.5 r` 2.5"
- (312) "A zero divisor writes 0, or 0.0 into a real, passes no power and is a minor fault the
  scan reports, `state.faults` or a cycle's `{:fault, task, instance, fault}` event; a literal
  0 divisor is refused."

---

## Instructions: comparisons (line 304, about 136 words)

**Reader and purpose.** A program author testing a value on a rung.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 304 | `eq ne lt gt le ge`: which pairs of types compare; comparison by value whatever the two types; no power on a false rung | R | reference/instructions; reference/cheatsheet; howto/do-arithmetic |
| 304 | Refusals and warnings: a bit string with an integer tag refused; a literal its tag's type cannot hold refused; two literals a warning; a literal at the type's limit whose result never changes a warning | R | reference/instructions; reference/diagnostics-and-warnings |

**Examples.** None.

**Rules stated.** (all 304)

- `eq a b`, `ne a b`, `lt a b`, `gt a b`, `le a b`, `ge a b` each take two operands.
- The two may be two integers of any widths.
- Or two reals.
- Or an integer with a real it widens into.
- Or two bit strings.
- Each operand is a tag, a member or a literal.
- A bit string with an integer tag is refused, the message naming the conversions.
- They compare by value, whatever the two types.
- They pass power when `a = b`, `a ≠ b`, `a < b`, `a > b`, `a ≤ b`, `a ≥ b` respectively.
- So an `sint` −1 is less than a `udint` 0.
- None passes power on a false rung.
- A literal its tag's type cannot hold is refused.
- Two literals are a warning.
- A literal at its tag's type's limit whose result never changes is a warning: `ge count 0` with a `usint` `count`.
- (From 136-138: a real literal in a comparison is a value of the other side's real type.)

**Citations.** None.

**Pictures.** A small table: left operand kind against right operand kind (integer, real, bit string, bool), each cell "compares", "compares where the integer widens", or "refused: convert first".

**Glossary.** *compare by value*: the numbers are compared, not their bit patterns, so a signed and an unsigned operand compare correctly (304).

**Hard to read.**

- (304) "two integers of any widths, two reals, an integer with a real it widens into, or two
  bit strings, each a tag, a member or a literal; a bit string with an integer tag is refused,
  naming the conversions"
- (304) "A literal its tag's type cannot hold is refused, and two literals are a warning, as is
  a literal at its tag's type's limit whose result never changes, `ge count 0` with a `usint`
  `count`"

---

## Instructions: bitwise and shifts (lines 314-316, about 307 words)

**Reader and purpose.** A program author masking, inverting, shifting or rotating bits.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 314 | `and`, `or`, `xor`: operands all bools and bit strings or all integers; result in `dst`'s type; cannot fail, so always passes power on a true rung | R / H | reference/instructions; reference/cheatsheet; howto/use-bit-strings |
| 315 | `not`: each bit inverted in the source's type, the result widened into `dst`'s by value; four worked values | R / H | reference/instructions; howto/use-bit-strings |
| 316 | `shl`, `shr`, `rol`, `ror`: the count operand; 0 filling; within the source's width; rotate by `n` modulo the width; a shift of the width or more writes 0; a negative tag count writes the source unshifted with no power and no fault | R / H | reference/instructions; howto/use-bit-strings |

**Examples.** None.

**Rules stated.**

`and a b dst`, `or a b dst`, `xor a b dst` (314):

- Two sources, each a tag, a member, a bit or a literal.
- Then a tag, member or bit it writes; not a `var_input`.
- The operands are all bools and bit strings, or all integers.
- Each source is of `dst`'s type or one Figure 11 widens into it; a bool widens into a bit string.
- Any other source is refused, the message naming its conversion.
- Bitwise AND, OR and exclusive OR, IEC's, in `dst`'s type.
- On a bool, its one bit.
- On an integer, its two's-complement pattern.
- True: writes and passes power, as it cannot fail.
- False: writes nothing, passes no power.
- Anything may follow it on the rung.

`not src dst` (315):

- A source, then a destination, as `and`'s.
- Each bit of the source is inverted in the source's type.
- The result is widened into `dst`'s type by value; this is IEC's typing.
- `not` of a `byte` 2#0000_1111 is 2#1111_0000.
- `not` of an `int` 0 is −1.
- `not` of a `bool` 1 is 0.
- `not` of a `bool` 1 into a `word` is 16#0000.
- Not stated in the row: true-rung and false-rung behaviour and power out (presumably as `and`'s).

`shl src n dst`, `shr src n dst`, `rol src n dst`, `ror src n dst` (316):

- A source and a destination as `and`'s.
- Between them a count: an integer tag of any width or a literal.
- A literal count is never negative.
- `shl` and `shr` shift left or right, 0 filling.
- So `shr` of an `int` −2 by 1 is 32767 (a logical shift, not an arithmetic one).
- `rol` and `ror` rotate left or right.
- Each works within the source's width.
- A rotate is by `n` modulo the width.
- The result is widened into `dst`'s type by value, so `rol` of a `byte` into a `word` rotates within 8 bits.
- True: writes and passes power.
- A shift of the width or more writes 0.
- A tag count that is negative when the rung runs writes the source unshifted and passes no power ("**no**" in bold), with no fault.
- False: writes nothing, passes no power.

**Citations.** IEC (314); Figure 11 (314); IEC's typing (315).

**Pictures.**

- Bit-row drawings, eight boxes each: `shl` by 1, `shr` by 1 (0 entering), `rol` by 1 and `ror` by 1 (the bit wrapping round).
- A two-step drawing for `rol` of a `byte` into a `word`: rotate inside 8 bits, then widen into 16.
- A drawing for `not` of a `bool` 1 into a `word`: invert in one bit (0), then widen (16#0000). The result surprises readers who expect 16#fffe.

**Glossary.**

- *bit string*: `byte`, `word`, `dword`, `lword` (314; defined at 80).
- *widened by value*: the result is computed in the narrower type and then copied as a value into the wider one (315).
- *0 filling*: the emptied bit positions of a shift are set to 0 (316).
- *rotate*: a shift in which a bit pushed out of one end enters at the other (316).
- *modulo the width*: a rotate count is reduced by the number of bits in the source's type (316).

**Hard to read.**

- (316) "shift left or right, 0 filling, so `shr` of an `int` −2 by 1 is 32767, and rotate left or
  right, each within the source's width, by `n` modulo the width, the result widened into
  `dst`'s type by value, so `rol` of a `byte` into a `word` rotates within 8 bits — true:
  writes and passes power; a shift of the width or more writes 0; a tag count that is negative
  when the rung runs writes the source unshifted and passes **no** power, with no fault;
  false: writes nothing, passes no power"
- (314) "two sources, each a tag, a member, a bit or a literal, then a tag, member or bit it
  writes, not a `var_input`: all bools and bit strings or all integers, each source of `dst`'s
  type or one Figure 11 widens into it, a bool into a bit string, any other refused naming its
  conversion"
- (315) "each bit of the source inverted in the source's type and the result widened into
  `dst`'s by value, IEC's typing, `not` of a `byte` 2#0000_1111 2#1111_0000, of an `int` 0 −1,
  of a `bool` 1 0, and of a `bool` 1 into a `word` 16#0000"

---

## Instructions: timers (lines 305-308, about 406 words)

**Reader and purpose.** A program author who needs a delay, a hold-on time, a fixed pulse or an
accumulated running time. Each row is a behaviour over time written as prose.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 305 | `ton`: on-delay; operands and preset ranges (ms, or ns for a long timer); `.acc` counts to `.pre`, `.dn` set there; false resets; one `ton` runs a timer; nothing may follow it | R / H / T | reference/instructions; reference/function-blocks (members); howto/use-timers; tutorials/timers-and-counters |
| 305 | The preset and `.pre`: where `.pre` starts, a `move` into `.pre`, and what an online edit of the preset does | R | reference/instructions; reference/online-edit |
| 306 | `tof`: off-delay, IEC's TOF; `.dn` set while true, held through the delay after the rung drops; at rest when new or restarted | R / H | reference/instructions; howto/use-timers |
| 307 | `tp`: pulse, IEC's TP; a rising edge starts a pulse on `.tt` exactly `.pre` long; an edge during it ignored; `.dn` as the pulse ends | R / H | reference/instructions; howto/use-timers |
| 308 | `rto`: retentive on-delay; keeps `.acc` and `.dn` on a false rung; reset `.r`; cold and warm restart; what logic writes | R / H | reference/instructions; howto/use-timers; reference/retained-values-and-store |

**Examples.** None.

**Rules stated.**

`ton t1 5000` (305):

- Operands: a timer, then a preset.
- The preset is 0 to 2147483647 ms.
- Or a long timer (`var t1 ton_ltime`) and a preset of 0 to 9223372036854775807 ns.
- The unit is the instance's (ms or ns by its type).
- On-delay timer: rung power is its IN.
- True: `.acc` counts the milliseconds since the scan that first saw the rung true.
- `.acc` counts up to `.pre`, where `.dn` is set.
- False: the timer resets.
- The preset is where `.pre` starts, when the instance starts or restarts.
- A `move` into `.pre` holds until the instance starts or restarts.
- An online edit that changes the preset moves `.pre` to the new one where `.pre` still holds the old one.
- An online edit keeps a `.pre` that logic changed.
- One `ton` runs a timer (a second `ton` on the same timer is not allowed).
- Nothing may follow a `ton` on its path.
- Read it with `xic t1.dn` on a rung below.

`tof run_on 30000` (306):

- Operands: an off-delay timer (`var run_on tof`), then a preset in ms; or a `tof_ltime` and a preset in ns.
- Off-delay timer, IEC's TOF: rung power is its IN.
- True: `.dn` is set and `.acc` is 0.
- The first false scan starts the delay.
- `.dn` stays set until `.acc` reaches `.pre`, then drops.
- A true rung during the delay ends the delay with `.dn` still set.
- A new or restarted `tof` is at rest, `.dn` 0.
- Read it with `xic run_on.dn` on a rung below.

`tp horn_pulse 3000` (307):

- Operands: a pulse timer (`var horn_pulse tp`), then a preset in ms; or a `tp_ltime` and a preset in ns.
- Pulse timer, IEC's TP.
- A rising edge of its rung starts a pulse on `.tt`.
- Never on an instance's first scan.
- The pulse is exactly `.pre` long, whatever the rung does meanwhile.
- An edge during the pulse is ignored.
- `.dn` is set as the pulse ends.
- `.dn` holds while the rung does (while the rung stays true).
- Read the pulse with `xic horn_pulse.tt` on a rung below.

`rto lube 360000000` (308):

- Operands: a retentive timer (`var lube rto`), then a preset in ms; or an `rto_ltime` and a preset in ns.
- Retentive on-delay timer, "the conventional RTO" (not an IEC block).
- True: it times as `ton`.
- False: it keeps `.acc` and `.dn`, so its time adds up across the rung's drops.
- Its reset is `.r`, an input a rung writes: `xic greased ote lube.r`.
- `.r` puts `.acc`, `.dn` and `.tt` to 0 at the timer's next run.
- A cold restart starts it at 0.
- A warm restart keeps it only where it is marked, `var retain lube rto`.
- Logic writes `.pre`, `.acc` and `.r`.

Related rules outside the table: a timer's members and their types (149-151); a timer is declared only with `var`, with no initial value (86-88); the preset ranges (120-121); a skipped or uncalled timer is frozen and catches up when it next runs (318, 319); a retained timer resumes without counting the outage (47-48).

**Citations.** M5-6 (305); IEC's TOF (306); IEC's TP (307); "the conventional RTO" (308).

**Pictures.** Timing diagrams, one a timer, are the single most useful addition in this range.
Each shows the rung (IN), `.acc`, `.tt` and `.dn` against time:

- `ton`: IN rises, `.acc` ramps to `.pre`, `.dn` rises; IN drops, everything resets. A second, short IN pulse that never reaches `.pre`.
- `tof`: IN true (`.dn` 1), IN drops, `.acc` ramps, `.dn` drops at `.pre`; a second case where IN returns during the delay and `.dn` never drops.
- `tp`: IN edge, `.tt` high for exactly `.pre` regardless of IN; a second edge during the pulse ignored; `.dn` set at the pulse's end and held while IN is true.
- `rto`: IN in three bursts, `.acc` a staircase that holds between them, `.dn` at `.pre`, then `.r` clearing all.
- A side-by-side table of the four: what starts it, what `.dn` means, what a false rung does, what resets it.

**Glossary.**

- *on-delay / off-delay / pulse / retentive timer*: `ton`, `tof`, `tp`, `rto` (305-308).
- *IN*: a timer block's input, here the rung's power (305).
- *`.pre`*: the preset member, the time to count to (305).
- *`.acc`*: the accumulated time (305).
- *`.dn`*: done (305). *`.tt`*: timing, the pulse of a `tp` (307). *`.r`*: an `rto`'s reset input (308). (The row gives the behaviour of each member; the words "done" and "timing" are the conventional readings, not the README's.)
- *long timer*: a `..._ltime` timer whose preset and members are in nanoseconds (305).
- *at rest*: a `tof` that is not holding `.dn` (306).
- *cold restart / warm restart*: a restart that starts everything at its initial value / one that keeps what is marked `retain` (308).
- *its path*: used at 305 and 309 ("nothing may follow it on its path") and not defined in this range; it appears to mean the series of instructions the power takes through the rung, one leg of each branch. Define it from the compiler's rule when rewriting.

**Hard to read.**

- (305) "The preset is where `.pre` starts, when the instance starts or restarts; a `move` into
  `.pre` holds until then. An online edit that changes the preset moves `.pre` to it where
  `.pre` still holds the old one, and keeps a `.pre` that logic changed."
- (307) "pulse timer, IEC's TP — a rising edge of its rung, never on an instance's first scan,
  starts a pulse on `.tt` exactly `.pre` long, whatever the rung does meanwhile, an edge
  during it ignored; `.dn` is set as the pulse ends and holds while the rung does."
- (308) "Its reset `.r`, an input a rung writes, `xic greased ote lube.r`, puts `.acc`, `.dn` and
  `.tt` to 0 at its next run; a cold restart starts it at 0, and a warm one keeps it only
  where it is marked, `var retain lube rto`."

---

## Instructions: counters (lines 309-310, about 279 words)

**Reader and purpose.** A program author counting events (boxes past an eye, parts left in a hopper).

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 309 | `ctu`: operands (a `ctu` or `ctud`, any typed counter), the preset's range, counting on a rising edge, `.q`, the reset `.r`, the stop at the top with `.ov`, what logic writes, one `ctu` a counter, nothing after it | R / H / T | reference/instructions; reference/function-blocks (members); howto/use-counters; tutorials/timers-and-counters |
| 310 | `ctd`: counting down, the load `.ld`, the stop at the bottom with `.un`, `.q` at `.cv <= 0` | R / H | reference/instructions; howto/use-counters |
| 310 | A `ctud`: run by one `ctu` and one `ctd` on two rungs with one preset; `.r`, `.ld`, `.qu`, `.qd` | R / H | reference/instructions; reference/function-blocks; howto/use-counters |

**Examples.** None.

**Rules stated.**

`ctu boxes 12` (309):

- Operands: an up counter (`var boxes ctu`) or an up-down one (`ctud`), then a preset.
- The counter may be any of IEC's typed counters, `ctu_int` or `ctud_ulint`.
- The preset is any value of its `pv`'s type.
- For a `ctu`: −2147483648 to 2147483647, negatives among them.
- For an unsigned typed counter: 0 to its top.
- Count up: rung power is the counter's count input `cu`.
- Each rising edge adds one to `.cv`.
- Never on an instance's first scan.
- `.q` is `.cv >= .pv`.
- Its reset `.r` is an input a rung writes: `xic reset_pb ote boxes.r`.
- `.r` puts `.cv` to 0 at the counter's next run.
- A reset keeps the counter's memory of `cu`, so a box on the eye at a reset is not counted again.
- At 2147483647, or a typed counter's top, the count stops.
- `.ov` then stays on until a reset.
- The preset is where `.pv` starts.
- Logic writes only `.r` and `.pv`, and a `ctud`'s `.ld`.
- One `ctu` runs a counter.
- Nothing may follow a `ctu` on its path.
- Read it with `xic boxes.q` on a rung below.

`ctd hopper 40` (310):

- Operands: a down counter (`var hopper ctd`) or an up-down one, then a preset.
- Count down: rung power is `cd`.
- Its load `.ld` puts `.cv` to `.pv`.
- Each rising edge takes one away.
- The count stops at −2147483648, or a typed counter's bottom, 0 for a `ctd_udint`.
- `.un` is then on until a load.
- `.q` is `.cv <= 0`.

A `ctud` (310):

- Declared `var stock ctud`.
- Run by one `ctu` and one `ctd` on two rungs.
- With one preset.
- It has `.r` and `.ld`.
- `.qu` is `.cv >= .pv`.
- `.qd` is `.cv <= 0`.

Related rules outside the table: preset ranges by type (121-123); two instructions run IEC's three counters (9).

**Citations.** M5-5 (309); "IEC's typed counters" (309).

**Pictures.**

- A timing diagram for `ctu`: `cu` pulses, `.cv` as a staircase, `.q` rising at `.pv`, `.r` clearing `.cv`; with one case of `cu` still true across the reset, to show that the box is not counted twice.
- A timing diagram for `ctd`: `.ld` loading `.pv`, `.cv` stepping down, `.q` at 0.
- A block drawing of a `ctud` with its two rungs (`ctu stock 10` on one, `ctd stock 10` on the other) feeding one `.cv`, and its members `.r`, `.ld`, `.qu`, `.qd`.
- A member table for the three counter types: member, type, who writes it, meaning.

**Glossary.**

- *`cu`, `cd`*: a counter's count-up and count-down inputs, here the rung's power (309, 310).
- *`.cv`*: the current value. *`.pv`*: the preset value (309).
- *`.q`, `.qu`, `.qd`*: the outputs: done; up done (`.cv >= .pv`); down done (`.cv <= 0`) (309, 310).
- *`.r`*: reset input. *`.ld`*: load input (309, 310).
- *`.ov`, `.un`*: overflow and underflow marks, on once the count has stopped at its top or bottom (309, 310).
- *typed counter*: a counter whose `cv` and `pv` are of a named integer type, `ctu_int` (309).
- *rising edge*: the rung's power going from false to true between two runs (309).
- *top / bottom*: the largest and smallest value of the counter's type (309, 310).

**Hard to read.**

- (309) "Its reset `.r`, an input a rung writes, as `xic reset_pb ote boxes.r`, puts `.cv` to 0 at
  the counter's next run, and keeps its memory of `cu`, so a box on the eye at a reset is not
  counted again."
- (309) "an up counter (`var boxes ctu`) or an up-down one (`ctud`), of any of IEC's typed
  counters too, `ctu_int` or `ctud_ulint` (M5-5), then a preset, any value of its `pv`'s type,
  −2147483648 to 2147483647 for a `ctu`, negatives among them, and 0 to its top for an
  unsigned typed counter"
- (310) "Its load `.ld` puts `.cv` to `.pv`; each rising edge takes one away, stopping at
  −2147483648, or a typed counter's bottom, 0 for a `ctd_udint`, with `.un` on until a load;
  `.q` is `.cv <= 0`."

---

## Instructions: one-shot and pulse coils (lines 301-303, about 262 words)

**Reader and purpose.** A program author who wants something to happen once when a condition
becomes true (or false), not on every scan while it stays so.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 301 | `ons`: passes power for the one scan in which the power reaching it rises; never on a first scan or the first scan after an edit; the storage bit; a second `ons` on it an error, any other write a warning | R / H | reference/instructions; reference/cheatsheet; howto/use-one-shots-and-pulse-coils; reference/online-edit (first scan after an edit) |
| 302 | `osr`: sets a pulse bit for that one scan and clears it on every other run; passes its power on; the errors and warnings on its two bits | R / H | reference/instructions; howto/use-one-shots-and-pulse-coils; reference/diagnostics-and-warnings |
| 303 | `osf`: the same on a falling edge, which its run on the false rung sees | R / H | reference/instructions; howto/use-one-shots-and-pulse-coils |

**Examples.** None.

**Rules stated.**

`ons s1` (301):

- One operand: a bool tag, the storage bit; not a `var_input`.
- One-shot: passes power for the one scan in which the power reaching it rises.
- Never on an instance's first scan.
- Nor on the first scan after an online edit that adds it or changes its rung.
- `s1` holds the power it saw last scan.
- A second `ons` on `s1` is an error.
- Any other write to `s1` is a warning.

`osr s1 pulse` (302):

- Two bool tags it writes, each not a `var_input`: the storage bit, then the pulse bit.
- The pulse bit may be a member logic may write.
- One-shot rising: IEC's positive transition-sensing coil "in the conventional set's form".
- Sets `pulse` for the one scan in which the power reaching it rises.
- Clears `pulse` on every other run.
- Never on an instance's first scan.
- Nor on the first scan after an online edit that adds it or changes its rung.
- `s1` holds the power it saw last run.
- It passes that power on (the power reaching it), so anything may follow it on its rung.
- A second `ons`, `osr` or `osf` on `s1` is an error.
- `s1` used as its own pulse bit is an error too.
- Any other write to `s1` is a warning.
- A second coil on `pulse`, an `ote` among them, is the second-`ote` warning.

`osf s1 pulse` (303):

- Operands as `osr`'s.
- One-shot falling: IEC's negative transition-sensing coil.
- Sets `pulse` for the one scan in which the power reaching it falls.
- Its run on the false rung is what sees the fall.
- It is `osr` in every other rule.

Wording to keep exact: `ons` "saw last scan" (301) against `osr` "saw last run" (302); `osr` clears "on every other run". The difference between a scan and a run matters where a rung is skipped by a `jmp` or sits in a block whose `cal` is false (318, 319).

**Citations.** IEC's positive transition-sensing coil (302); IEC's negative transition-sensing coil (303).

**Pictures.**

- A timing diagram on a scan grid: the power reaching the instruction, the storage bit, and (for `ons`) the power out or (for `osr`, `osf`) the pulse bit, each one scan wide. One diagram for the three, plus the first-scan case where no pulse appears though the power is already true.
- The ladder symbols `-(P)-` and `-(N)-` beside `osr` and `osf`.

**Glossary.**

- *one-shot*: an instruction that acts for one scan when its input changes (301).
- *storage bit*: the bool in which a one-shot keeps the power it saw last (301).
- *pulse bit*: the bool an `osr` or `osf` sets for one scan (302).
- *transition-sensing coil*: IEC's name for a coil that pulses on a rising (positive) or falling (negative) edge (302, 303).
- *first scan*: an instance's first scan after it starts or restarts; edges are not seen on it (301).
- *the second-`ote` warning*: the warning given where two coils write one tag (302).

**Hard to read.**

- (302) "one-shot rising, IEC's positive transition-sensing coil in the conventional set's form —
  sets `pulse` for the one scan in which the power reaching it rises, and clears it on every
  other run, never on an instance's first scan, nor on the first scan after an online edit
  that adds it or changes its rung; `s1` holds the power it saw last run."
- (302) "A second `ons`, `osr` or `osf` on `s1` is an error, as is `s1` for its pulse bit too,
  and any other write to `s1` a warning; a second coil on `pulse`, an `ote` among them, is the
  second-`ote` warning"
- (303) "one-shot falling, IEC's negative transition-sensing coil — sets `pulse` for the one
  scan in which the power reaching it falls, which its run on the false rung sees, and is
  `osr` in every other rule"

---

## Instructions: jump and label (lines 319-320, about 210 words)

**Reader and purpose.** A program author who wants to skip a group of rungs, for example the
manual-mode rungs while in automatic.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 319 | `jmp`: true, skips the rungs after its own up to the one its label heads, after the rest of its rung has run; passes on its power; forward only; one `jmp` a rung | R / H | reference/instructions; reference/cheatsheet; howto/jump-over-rungs |
| 319 | What a skipped rung keeps: coils hold; counters, one-shots and timers frozen; a timer catches up | R / E | reference/instructions; reference/execution-model; howto/jump-over-rungs |
| 320 | `lbl`: first on its rung; passes on its power; names one rung of its routine; an unused label a warning; a label alone is a landing | R / H | reference/instructions; howto/jump-over-rungs; reference/diagnostics-and-warnings |

**Examples.** None.

**Rules stated.**

`jmp auto` (319):

- One operand: a label, a name declared nowhere.
- True: once the rest of its rung has run, it skips the rungs after its own up to the one `lbl auto` heads.
- The rung `lbl auto` heads runs.
- It passes on the power it receives, so anything may follow it.
- False: skips nothing and passes no power.
- The label is on a later rung of the same routine.
- A jump back is refused.
- A jump to its own rung is refused.
- A rung holds one `jmp`.
- A skipped rung runs nothing.
- So a skipped rung's coils hold.
- And its counters, one-shots and timers are frozen, as in a block whose `cal` is false.
- A skipped timer catches up when it next runs.

`lbl auto` (320):

- One operand: a label.
- `lbl` is first on its rung.
- It names its rung as a jump's target.
- It passes on the power it receives.
- A label names one rung of its routine.
- A block's body is a routine of its own (its labels are its own).
- A label no `jmp` names is a warning.
- A rung that is a label alone, `lbl done`, is a jump's landing.
- It is taken where a `jmp` names it.
- It is refused as a rung that writes nothing where none does.
- Landing on a label alone is landing on the rung after it, or on the routine's end.

Related rules outside the table: a label's spelling and namespace (180-184); the label-alone rung and decision 367 (175-178); a rung that jumps is not "a rung that writes nothing" (170-172).

**Citations.** None in the rows (decision 367 is at 177; forward pointer "A forward jump" at 184).

**Pictures.**

- A flowchart or a rung list with an arrow: rungs 1 to 6, `jmp auto` on rung 2, `lbl auto` on rung 5; rungs 3 and 4 greyed as skipped, rung 5 run. A second arrow to a `lbl done` standing alone at the end.
- A before/after table of what a skipped rung keeps: an `ote`'s tag (holds its last value, not 0), a `ton` (frozen, catches up), a `ctu` (frozen), an `ons` (frozen).

**Glossary.**

- *jump*: skipping rungs up to a label (319).
- *landing*: the rung a jump arrives at (320).
- *frozen*: not run, its state as it was (319).
- *catches up*: a timer that was not run counts the whole time that passed when it next runs (319).
- *routine*: a program's rungs, or one block's body (319, 320).

**Hard to read.**

- (319) "jump — true: once the rest of its rung has run, skips the rungs after its own up to the
  one `lbl auto` heads, which runs, and passes on the power it receives, so anything may
  follow it."
- (320) "A rung that is a label alone, `lbl done`, is a jump's landing, taken where a `jmp` names
  it and refused as a rung that writes nothing where none does: landing on it is landing on
  the rung after it, or on the routine's end"
- (319) "A skipped rung runs nothing, so its coils hold and its counters, one-shots and timers
  are frozen, as in a block whose `cal` is false, a timer catching up when it next runs"

---

## Instructions: `cal` and the branch group (lines 318 and 321, about 145 words)

**Reader and purpose.** A program author running an instance of a function block of their own;
and any author reading what a parallel branch does at run time.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 318 | `cal`: operands in the block's declaration order (the instance, a value for each `var_input`, a tag for each `var_output`); rung power is its EN and passes on; true copies in, runs, copies out; false freezes the instance and its outputs | R / H | reference/instructions; reference/function-blocks; howto/write-a-function-block |
| 318 | One `cal` runs an instance; a `ton` is run by its `ton`, never by `cal`; a timer inside catches up when the block next runs | R | reference/function-blocks; reference/execution-model |
| 321 | `( … \| … )`: the legs OR together, and every leg runs | R | reference/instructions; reference/source-syntax; reference/cheatsheet |

**Examples.** None.

**Rules stated.**

`cal s1 a b q` (318):

- First operand: an instance of a function block.
- Then a value for each of the block's `var_input`s: a tag, a member or a literal of its type.
- Then a tag for each of its `var_output`s, which `cal` writes, so not a `var_input`.
- The operands stand in the block's declaration order.
- `cal` runs the instance: rung power is its EN.
- It passes its power on.
- True: copies the inputs (`a` and `b`) in.
- True: runs the block's rungs over the instance's state.
- True: copies its outputs out (to `q`).
- False: copies nothing in or out and runs nothing.
- So on a false rung the instance and `q` are frozen.
- A timer inside catches up when the block next runs.
- One `cal` runs an instance.
- A `ton` is run by its `ton`, never by `cal`.

Branch group (321):

- `( … | … )` is a parallel branch group; it has no operands.
- The legs OR together.
- Every leg runs (see 338-341: no short-circuit).

Related rules outside the table: a block's file and `types:` (185-191); a block's members are read anywhere, its own `var`s only inside, nothing outside writes them (151-153); a block takes a global through a `var_input` its `cal` fills (107-108).

**Citations.** None in the rows.

**Pictures.**

- A sequence diagram for a true `cal`: caller's tags -> copy in to the instance's `var_input`s -> the block's rungs run over the instance's state -> copy out to the caller's tags. Beside it the false case: nothing moves.
- A box drawing of the block, as a graphical tool shows a function block: EN on the left, the `var_input`s down the left side, the `var_output`s down the right, with the `cal` line's operands mapped onto the pins.
- For the branch: the drawn rung with two legs (already proposed for 179).

**Glossary.**

- *EN*: IEC's "enable" input of a block; here the rung's power (318).
- *instance*: one declared use of a block type, with its own state (318).
- *declaration order*: the order of the `var_input` and `var_output` lines in the block's file (318).
- *leg*: one of the alternative paths of a branch group (321).

**Hard to read.**

- (318) "an instance of a function block, then a value for each of its var_inputs (a tag, a
  member or a literal of its type) and a tag for each of its var_outputs, which it writes, so
  not a `var_input`, in the block's declaration order"
- (318) "False: copies nothing in or out and runs nothing, so the instance and `q` are frozen; a
  timer inside catches up when the block next runs. One `cal` runs an instance, and a `ton` is
  run by its `ton`, never by `cal`"

---

## After the table: checking, branch semantics, contact values (lines 323-348, about 286 words)

**Reader and purpose.** A program author reading a list of diagnostics; a host developer handing
a state to the runtime; anyone asking what order a branch's legs run in.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 323-326 | Every mistake in a routine's declarations and instructions is reported with its line, in line order; a lex or parse error still stops at the first | R / H | reference/diagnostics-and-warnings; howto/read-diagnostics |
| 326-333 | Worked case: `move src ote` gives two diagnostics, with their text | H / R | howto/read-diagnostics; reference/diagnostics-and-warnings |
| 335-336 | A tag an instruction writes may be a `var_external`: the write is to its global, which a configuration refuses where that global is an input point | R | reference/declarations-and-types; reference/configuration-file |
| 338-341 | Two deliberate behaviours of branches: no short-circuit; the environment threads through the legs in order | R / E | reference/execution-model; reference/instructions; explanation/scan-cycle-and-time |
| 343-348 | `xic` and `xio` are complementary; only a bool reaches them; a state's value outside its tag's type or of no integer kind is refused with an `ArgumentError` where the state is handed in; a tag the state leaves out reads as 0 | R | reference/host-contract; reference/instructions |

**Examples.**

- Lines 330-333: a fenced block with **no language tag**, holding two diagnostic lines
  (`line 2: \`move\` expects 2 operands (a value, then a tag), found 1 before the instruction
  \`ote\`` and `line 2: \`ote\` expects 1 operand (a tag), found none`). It belongs to the unit
  326-333. It is not an `elixir` block, has no `<!-- file: -->` marker and no `$ mix run`, so
  `readme_test.exs` does not run it; no test was found that pins this exact text against the
  README. If it moves, check the wording against the compiler's output.
- No `<!-- file: path -->` block, no `$ mix run` block and no `elixir` block in lines 1-349.

**Rules stated.**

- Each instruction's operands are checked against the table (323).
- And against their tags' declarations (323-324).
- Every mistake in a routine's declarations and instructions is reported (324).
- Each with its line, in line order (325).
- A lex or parse error still stops at the first (325-326).
- A lex or parse error stops before any instruction is checked (326).
- With `src` declared, `move src ote` gives two diagnostics (326-327).
- `move` runs out of operands at an instruction: "`move` expects 2 operands (a value, then a tag), found 1 before the instruction `ote`" (327, 331).
- `ote` then has none of its own: "`ote` expects 1 operand (a tag), found none" (327-328, 332).
- A diagnostic is printed as `line <n>: <message>` (331-332).
- A tag an instruction writes may be a `var_external` (335).
- The write is to its global (335).
- A configuration refuses that write where the global is an input point (335-336).
- Branches do not short-circuit (338-339).
- So a later leg's `ote` and `move` still take effect after an earlier leg is already true (339-340).
- The environment threads through the legs in order, so a leg can see what an earlier leg wrote (340-341).
- Both match how a real controller scans a rung (341).
- `xic` and `xio` are complementary by construction: exactly one of them passes power (343).
- The compiler lets only a `bool` reach either (343-344).
- The runtime lets only a bool's 0 or 1 reach it from a state (344-345).
- A value outside its tag's type is refused where the state is handed in: a 5 in a `bool`, 5000000000 in a `dint` (345-346).
- A value that is no integer at all is refused there too: a `2.5`, a `false`, a `nil` or a `"x"` (346-347). Check when rewriting: this sentence reads as written before reals landed; a `2.5` is a legal value of a `real` tag.
- The refusal is an `ArgumentError` naming each such value (347).
- So no scan ever sees such a value (347-348).
- A tag the state leaves out reads open, as 0 (348).

**Citations.** decisions 171 and 173 (348).

**Pictures.**

- A drawn rung with two legs, each ending in a coil, annotated "leg 1 runs, then leg 2 runs, even though leg 1 was true", with the tag values after each leg. It shows both deliberate behaviours at once.
- A before/after of the `move src ote` mistake: the line, the two diagnostics under it, the corrected line.

**Glossary.**

- *diagnostic*: a located report of a mistake in the source, returned not raised (324-325).
- *lex error / parse error*: a mistake found while cutting the text into words, or while reading the words as rungs; it stops the compile at the first (325-326).
- *short-circuit*: skipping a later alternative once an earlier one is true; logex's branches do not (338-339).
- *environment*: the tags' values during a scan (340).
- *state*: an instance's values as a host hands them in (345-347).
- *reads open*: a contact on a tag with no value behaves as on 0 (348).

**Hard to read.**

- (343-348) "The compiler lets only a `bool` reach either, and the runtime lets only a bool's 0 or
  1 reach it from a state: a value outside its tag's type, a 5 in a `bool` or 5000000000 in a
  `dint`, and a value that is no integer at all, a `2.5`, a `false`, a `nil` or a `"x"`, is
  refused where the state is handed in, an `ArgumentError` naming each such value, so no scan
  ever sees one (decisions 171 and 173)."
- (326-328) "With `src` declared, `move src ote` gives two, because `move` runs out of operands
  at an instruction and `ote` then has none of its own:"
- (338-341) "Two behaviours that are deliberate rather than accidental: branches do **not**
  short-circuit, so a later leg's `ote` and `move` still take effect after an earlier leg is
  already true; and the environment threads through the legs in order, so a leg can see what
  an earlier leg wrote."

---

## Summary of findings for this range

**Main destinations.** `reference/source-syntax`, `reference/declarations-and-types`,
`reference/literals`, `reference/instructions`, `reference/conversions`,
`reference/configuration-file`, `reference/host-contract`, `reference/cheatsheet`,
`explanation/what-logex-is`, `explanation/the-dialect-and-iec`.

**Proposed new slugs.**

- NEW `contributor/adding-an-instruction`: the naming survey and its three-step rule (267-276)
  are stated in the README, in `CLAUDE.md` and in `CONTRIBUTING.md`; one contributor page
  should own the procedure.
- `adr/NNNN-punctuation-branch-delimiters` (256-261), `adr/NNNN-host-contract` (decisions 514
  and 523), and ADR candidates for decisions 351 (a rung must write), 367 (a label alone),
  369 (a number's size limits) and 464 (raw file reads).

**Content repeated elsewhere.**

- The stage summary (8-55) is a prose index of the whole README; every clause is restated in a
  later section.
- The preset ranges appear three times in this range (120-123, 305, 309).
- The label-alone rule appears twice (175-178 and 320); the label's spelling twice (180-184, 319-320).
- The reserved-word rules are spread over 96-97, 110-113, 180-181, 190 and 230-235.
- `retain` on a global is at 97-98 and again at 215-217; `var_external` binding at 103-109 and 236-239.
- "A skipped or uncalled timer catches up" is at 318 and 319.
- The configuration file's lines (199-240) are a second summary of the later "A configuration" sections.

**Claims that look stale or incomplete.**

- 212: an array global is "never located yet", against 42-43 (M5-13, located arrays landed),
  README 4733 "A located array" and `lib/logex/configuration.ex`.
- 230-231: the configuration file's reserved words omit `continuous` and `watchdog`, and give
  the type words as "`bool` and the eight integer widths" where the code reserves every type
  word (bit strings and reals too). The task line forms (203-209) do not mention the
  `continuous` task or a task's `watchdog` at all.
- 346: "a value that is no integer at all, a `2.5`" predates reals.
- 54-55: `PLAN.md` called "a full review of the codebase"; `CLAUDE.md` now names
  `docs/review-2026-11-01.md` as the review.
- 6: "forty-five modules" is right today (45 `defmodule`s in 40 files) but is a count that will rot.
- 149-151: the timer members listed omit an `rto`'s `.r` (given at 308).
- The instruction table omits the false-rung behaviour or power out of several rows (`move`,
  the truncations, `not`, `tof`, `tp`, `rto`, `ctd`); see the notes at the head of the table's section.

**Content that fits no page cleanly.**

- The loader's file-server detail (194-197, decision 464) is contributor material inside a user syntax list.
- The `mov` rename (296) and "until §4·B1 landed" (248) are history.
- The M5-n and M6-n item numbers throughout are plan references with no meaning to a user.
