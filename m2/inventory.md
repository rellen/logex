# Milestone 2 inventory: decided rules, open questions, contradictions

Written 2026-10-02 for the Milestone 2 (M2) design pass, against `/home/user/logex` at
`47319f7` (main, 2026-10-01). Nothing in the repository was changed. Probes ran in a copy,
`scratchpad/m2/inv-questions-work`, on Elixir 1.20.4 / OTP 28; their scripts are in
`scratchpad/m2/inv-probe/` and their output is in §12. No spike patch: this pass changed
no code, so there is no `inv-questions.patch`.

**How to read this file.** It is the checklist each designer works from.

- **D** marks a decided rule. A design keeps it, or asks the maintainer to depart from it
  as an explicit, argued question.
- **Q** marks an open question that an item cannot be built without answering.
- **C** marks a contradiction or tension between two sources, quoted on both sides (§8).
- **U** marks a claim M2 relies on that is unverified, from memory, inferred, or an
  absence claim (§9).

Citations use `file:line` for the repository, and section numbers for `docs/organisation.md`
("org") and `PLAN.md`.

**The labels are this file's own.** Never cite `Q1.4`, `C7` or `U3` in `lib/`, `test/`
or `CLAUDE.md`. `edit_test.exs`'s labels test (`test/logex/edit_test.exs:1541-1603`)
refuses a lettered hazard, `R` and a number, and any decision or `F` number that org §7
does not define. In the spirit of org §4.9 ("Tests", org:1182-1189), a label that only a
design pass's notes define is not cited at all. A new decision or fix is appended to
org §7 first, numbered on from 29 and F16 with none missing (`edit_test.exs:1557-1560`).

---

## Contents

0. Cross-cutting: rules and questions every item meets
1. M2-1 · The scheduler, from Elixir data
2. M2-2 · The configuration file, task-less
3. M2-3 · Periodic tasks in text
4. M2-4 · Shared globals
5. M2-5 · User function blocks
6. M2-6 · Event tasks
7. OE-2's constraints on Milestone 2
8. Contradictions and tensions (C1–C31)
9. Unverified, from memory, inferred, absence claims (U1–U26)
10. New words, stanzas owed, and what they break
11. The order of landing
12. Probe receipts

---

## 0. Cross-cutting: rules and questions every item meets

### 0(a) Decided rules

- **D0.1 The direction.** logex follows IEC 61131-3's software model: a configuration
  contains resources, a resource runs program instances under tasks, program instances
  contain function-block instances, and globals and I/O bindings connect them (org §1,
  org:37-42; PLAN §5, PLAN:1894-1905).
- **D0.2 The dialect.** Lowercase keyword lines, one declaration per line, no IEC
  punctuation (`:`, `:=`, `=>`, `;`, `( )`), IEC names lowercased where IEC names the
  thing, integer milliseconds in place of `T#`, and time that the caller injects and never
  reads from a clock (org:44-50; decision 13, org:1491-1492).
- **D0.3 Not adopted or deferred.** These are routines; controller scope; program-to-program
  connections; several resources; preemption; FB-to-task association; direct
  representation and raw addresses; VAR_ACCESS and a host write path; STRUCT and arrays;
  VAR_IN_OUT, VAR_TEMP, CONSTANT, user FUNCTIONs and `T#`; and IEC paste-compatibility
  (org §5, org:1240-1255). VAR_CONFIG, RETAIN and forcing are "target", not scheduled
  (org:1250).
- **D0.4 Three rules from M1-3.**
  1. The compiled program is a named, stateless type.
  2. Its state is one instance: a tree keyed by declared tag name.
  3. `var_input` and `var_output` are the program's interface.

  (org §4.1, org:211-222.)
- **D0.5 How an item lands.**
  - It surveys its new words in `docs/naming.md` first, appending stanzas.
  - It lands green on its own.
  - Every diagnostic is pinned by a test that asserts whole diagnostic lists from
    source.
  - Each rule is checked by reverting it.

  (org §6.2, org:1355-1361; PLAN:1293-1295; CLAUDE.md:177-180.)
- **D0.6 The error model.** A source mistake is a returned `%Logex.Diagnostic{}`. A host
  mistake is a raised `ArgumentError` whose message a test pins. Nothing else escapes the
  public API (CLAUDE.md:135; PLAN M1-5, PLAN:964-972).
- **D0.7 Style.** Use pattern matching with multiple function clauses, not conditionals
  (CLAUDE.md:181).
- **D0.8 No BEAM, no Elixir compiler.** Nothing compiles a user's program to BEAM, and no
  front end puts the Elixir compiler on the path that changes a running program
  (CLAUDE.md:174-177; PLAN §6, PLAN:1974-1984; org:785-794; decision 16).
- **D0.9 One model, held as data.** `%Logex.Program{}` and, from M2-1,
  `%Logex.Configuration{}` are values. Their saved form is `.ld` and `.lcf` text, which
  printers write. Every way of writing a controller ends in the one validator, and the data
  API refuses what the text cannot say (org:775-783; PLAN:1783-1785; decisions 15 and 28).
- **D0.10 Reserved words, by file kind.** Every keyword is reserved in any case
  (org §2 fact 3, org:124-126; org §4.8, org:739-764; decision 10). Each commit names the
  words it reserves and the tag names they break (org:761-764; CLAUDE.md:146-157).
- **D0.11 One diagnostic type.** `%Logex.Diagnostic{stage:, line:, message:, file:,
  column:, severity:}` with `format/1` (PLAN:945-949; `lib/logex/diagnostic.ex:22-24`).
- **D0.12 Documents each stage stales** (org:1428-1436):
  - `README.md` gets a syntax-list entry and an example that is re-run;
  - `PLAN.md` gets a §8 entry, B5's module list and B9's preconditions;
  - CLAUDE.md's Key Files gets `configuration.ex`;
  - PLAN §5's organisation bullet keeps its one-line summary.

  The README has no test behind it (CLAUDE.md:113-118; CONTRIBUTING.md:257-259).
- **D0.13 Growth tests.** Any new pass over a program, a configuration or a step that is
  not a compile needs a growth test in reductions. It runs at two sizes, and at two depths
  where it walks nesting. Its figures are read over 30 runs or more, and its bound is set a
  fifth or more above the highest (CONTRIBUTING.md:290-327).
- **D0.14 A property asserts its reach.** It reaches every refusal kind and every case
  each restated condition decides, checked under seeds it was not tuned on
  (CONTRIBUTING.md:167-205).
- **D0.15 The public surface is pinned.** `runtime_test.exs:688-735` pins every public
  function of `Logex`, `Logex.Runtime`, `Logex.Compiler`, `Logex.Edit`, `Logex.Parser` and
  `Logex.FbType`, and the fields of `%Logex.Instance{}` and `%Logex.Scan{}`.
- **D0.16 New syntax.** A new syntax form goes into `printer_test.exs`'s generator and
  `@required_shapes` before it lands. The golden record is regenerated only on purpose,
  with its diff read (CLAUDE.md, the `lexer.ex`/`parser.ex` bullet; CONTRIBUTING.md:356-364).
- **D0.17 New state.** Every new piece of instance or runtime state states its rule across
  an online edit. A field of `%Logex.Instance{}` gets three things: a check with a pinned
  message, a value from `instance/1`, and a rule for each of a scan, `restart/3` and a
  switch (CLAUDE.md:166-173; org:878-881, org:1106-1122).
- **D0.18 The conventional family stays unnamed** (CONTRIBUTING.md:261-266; org:62-65).

### 0(b) Questions every item meets

- **Q0.1 Diagnostic stage.** Which `stage:` does a configuration problem carry?
  `@type stage` is `:file | :lex | :parse | :validate | :edit`
  (`lib/logex/diagnostic.ex:24`). Do `.lcf` lex and parse errors reuse `:lex` and `:parse`?
  Does a configuration check get a new stage, and is a cross-file check, such as a
  `var_external` against a `var_global`, a stage of its own?
- **Q0.2 Where a program's file is kept** (fix F15; C17). Today `%Logex.Program{}` has no
  `file` (`lib/logex/program.ex:16`). `compile_file/1` stamps `file:` only on diagnostics
  and warnings (`lib/logex.ex:110-114`). These need the file of a program type:
  - an `:edit` diagnostic (org:954-956; `diagnostic.ex:15-17`);
  - a configuration diagnostic that cites a `.ld` line (M2-4's type agreement, M2-5's
    recursion);
  - the done sentence's "names its file and line" (PLAN:1372-1373).

  Options:
  - a `file:` field on `%Program{}`;
  - a map from type name to path, kept by the loader;
  - a diagnostic that names a second location in its message.

  Q0.2 also asks how a `%Program{}` built from data, with no file, is cited.
- **Q0.3 Where configuration warnings live** (C5, C27). The two-writer warning, the
  ton-in-an-event-task warning, and any "unused global" or "task with no instance" warning
  need a home. Is it a `warnings:` field on `%Configuration{}`?
- **Q0.4 Tuple order** (C16). `cycle/3` is documented as `{rt, outputs, events}`. `call/4`
  and `scan/2,3` return `{outputs, state}`, and `Logex.Edit` returns `{edit, state, report}`.
  Choose one order for the new API, and say why.
- **Q0.5 Printers** (C17). §5 says the saved form is text that printers write.
  `Logex.Printer` prints only a parse AST (`lib/logex/printer.ex:1-48`). Does M2 owe a
  printer from `%Configuration{}` to `.lcf`, with a round-trip test? Does it owe one from
  `%Program{}` to `.ld`, for a program built as data?
- **Q0.6 naming_test reach.** `naming_test.exs` checks only `Compiler.instructions/0` and
  `Declarations.keywords/0` (`test/logex/naming_test.exs:35-61`). The `.lcf` words and
  `function_block` have no table it reads. Where are they held as data, so that a test
  refuses one without a stanza?
- **Q0.7 New options on `Logex.compile/2`.** `Logex.compile/2` refuses any option but
  `name:`, with a pinned message (`lib/logex.ex:65-71`; `test/logex_test.exs:133-137`).
  Any new option, such as a function block library, changes it.
- **Q0.8 A configuration built as data.** The data path for a configuration needs its
  entry check. `Logex.Parser.well_formed!/1` (`lib/logex/parser.ex:65-70`) defines what text
  can say for a program. What defines it for a configuration?
  - A name must lex as one name token.
  - An integer must be at least 0, and an interval at least 1.
  - A location must lex as one name.
  - A `%Program{}` passed in must have a name.
- **Q0.9 Tests that must grow.** Three tests pin today's surface and contract:
  - `runtime_test.exs`'s surface test;
  - `api_contract_test.exs`, whose host-contract property must reach `cycle/3`, `start/1`
    and `get/2` refusals, and whose `@refusals` list must grow;
  - `logex_test.exs`.

  Which item extends each?

---

## 1. M2-1 · The scheduler, from Elixir data, no syntax

### 1(a) Decided rules

- **D1.1 Scope.**
  - `%Logex.Configuration{}`, with a pure, checked constructor.
  - `Logex.Runtime.start/cycle/next_due_in/get`.
  - Periodic and task-less instances.
  - Copy-in and copy-out.
  - Overlap events.

  (PLAN:1297-1298; org:1363-1367.)
- **D1.2 Acceptance**, verbatim:
  > *a configuration built in Elixir with a 10 ms task, a 30 ms task and a task-less
  > instance, cycled for one simulated second by an injected clock, runs each instance
  > exactly as often as its task dictates, in priority order; a late cycle yields one
  > `{:overlap, …}` and no lost phase; the README program gives identical outputs through
  > `scan/2` and through a one-instance configuration.*

  (PLAN:1298-1303; org:1368-1372.)
- **D1.3 The §4.9 constraints.** M2-1 keeps every one (PLAN:1304-1313; org:873-887; full
  list in §7, D7.1–D7.9).
- **D1.4 Fix F14.** `start/1` builds each instance through the same constructor as
  `Runtime.instance/1`, so `first`, `ons_blocked`, `switched` and any later field cannot
  drift (org:882-884; org:1628-1629; PLAN:1311-1313).
- **D1.5 A resource is one value.** It is `%Logex.Runtime{}`. Its clock is an integer
  `now` in ms, and nothing inside it reads a clock (org:536-537). It is opaque, and its
  configuration changes only through the API (org:885).
- **D1.6 `cycle/3`.** `Logex.Runtime.cycle(rt, elapsed_ms, inputs) :: {rt, outputs, [event]}`.
  A *scan* is one execution of one instance; a *cycle* is one step of the resource
  (org:539-544, org:676).
- **D1.7 The order of a cycle** (org:546-583):
  1. **Time.** `now` advances by `elapsed_ms`, which must be at least 0.
  2. **Input image.** `inputs` are merged into a persistent image, so a host may send only
     what changed. Every scan in the cycle sees one sample. An undeclared name raises,
     since it is a host bug.
  3. **Due tasks,** worked out once per cycle:
     - each periodic task keeps a `next_due`, anchored at start;
     - every periodic task is due in the first cycle;
     - after a run, `next_due` advances by whole intervals, so the phase never drifts.
  4. **Order.**
     - Due tasks run by priority, 0 first, then the earlier due time, then declaration
       order (rule 3a).
     - Within a task, instances run in declaration order.
     - Task-less instances run last, once each.
     - Each scan copies the connected var_inputs in, runs the rungs, and copies the
       var_outputs out.
  5. **Output image.** The output map is returned once, after every due scan.
- **D1.8 No preemption, and visibility follows order.** A scan runs to completion in zero
  logical time. An instance sees any global an earlier instance wrote in the same cycle,
  and never one a later instance writes (org:585-590; decision 11).
- **D1.9 Missed periods are reported, not replayed.** The task:
  - runs once;
  - adds `missed = div(now - next_due, interval)` to its overlap count;
  - emits `{:overlap, task, missed}`;
  - moves `next_due` past `now` without losing phase.

  (org:592-602; decision 11, org:1481-1487.)
- **D1.10 Events.** `{:ran, task | :none, instance, now} | {:overlap, task, missed}`. The
  events are an open set, which a host must tolerate (org:679, org:887).
- **D1.11 The rest of the API** (org:670-678):
  - `instance/1`, `call/4`, `put_inputs/3`, `scan/2,3` and `restart/3` stay;
  - `start(config) :: rt`;
  - `next_due_in(rt) :: non_neg_integer | :infinity`, "what the runner sleeps on";
  - `get(rt, "m1.t1.acc")`, an access path with the resource omitted.
- **D1.12 `scan/2` agrees with a one-instance configuration.** `scan/2` and a one-line
  configuration give identical outputs for the README program, and a test pins it
  (org:682-684). `restart/3` keeps the var_inputs for this reason (org:685-690;
  `lib/logex/runtime.ex:95-105`).
- **D1.13 The scheduler calls `call/4`.** "`call/4` is one scan of one instance … It is
  what a configuration's scheduler calls for each instance it runs"
  (`lib/logex/runtime.ex:7-8`).
- **D1.14 The deviations from IEC, labelled** (org:657-665):
  - a task-less instance runs once per cycle;
  - SINGLE is a bool global and INTERVAL a constant in ms;
  - scans are zero-time and non-preemptive;
  - instances run in declaration order;
  - a missed deadline is reported as `{:overlap, …}` and counted.
- **D1.15 The core and the runner.** The pure core takes an input map keyed by input-point
  name, and returns an output map keyed by output-point name. Devices and adapters are the
  runner's, outside the core (org:510-532). The wall-clock runner, the `Logex.IO` adapters
  and the watchdog come after M2, and nothing in M2 blocks them (org:1249). A later forcing
  map sits "after the input latch and before the output return, in `cycle/3`" (org:1250),
  so the cycle must keep those two points.
- **D1.16 Timers.**
  - Each `ton` uses its own `last`, not a per-instance `dt` (decision 8, org:609-639).
  - The increment is the actual time, not the nominal interval (org:637-639).
  - `first` is per instance (org:647).
- **D1.17 One rule for new state.** `Logex.Program.initial_env/1` starts every tag
  (`lib/logex/program.ex:28-45`; org:1106-1110).
- **D1.18 The host contract M1-5 set.** It stays for `call/4`: only a declared var_input is
  set; every input problem comes in one raise; inputs merge; time never goes backwards;
  `first` must agree (`lib/logex/runtime.ex:21-43`; PLAN:964-972).
- **D1.19 Execution order and instances.** Execution order is a list in the configuration.
  Program instances are held flat, keyed by instance name, and never nested under a task
  (org:875-877).
- **D1.20 Watchdog.** The watchdog's fault policy is decided with the runner, not in M2
  (decision 14; PLAN:1363-1366).

### 1(b) Open questions

**The data shapes**

- **Q1.1 What `%Logex.Configuration{}` holds.** Its fields and their order:
  - name;
  - tasks;
  - globals, located or not;
  - instances, with their type name and task;
  - connections;
  - the execution order list;
  - declaration order, kept as lists, since maps lose it.

  Q1.1 also asks whether M2-1's data already holds located points and connections. It
  must, for copy-in and copy-out (C7).
- **Q1.2 Programs in the configuration.** Does `%Configuration{}` embed the `%Program{}` of
  each type? Or does `start/1` take the programs beside it? §4.9 says a running controller
  holds "a `%Logex.Program{}` per program type and … one `%Logex.Configuration{}`"
  (org:775-777). That reads as two things, yet `Configuration.compile/3` takes compiled
  types in (org:470).
- **Q1.3 The fields of `%Logex.Runtime{}`.** One candidate set is:
  - `now`;
  - the configuration;
  - the input image;
  - the global values (one copy);
  - the instance states, keyed by name;
  - per task: `next_due` and an overlap count;
  - per event task: the last SINGLE value (M2-6).

  Does it reserve OE-2's generation counter now (org:981; `lib/logex/edit.ex:178-182`)?
  Each field needs D0.17's rules.
- **Q1.4 A task-less instance.** How is "no task" represented: `nil`, `:none`, or absent?
- **Q1.5 Names and namespaces.** Do these share one namespace: global names, instance
  names, task names, program type names and function block type names? A global named
  `m1` beside an instance `m1` makes `get(rt, "m1")` ambiguous.

**Constructors and error modes**

- **Q1.6 The Elixir constructor.** What is it called, and what is its error mode?
  - Like `Tag.new!/4`, which raises the first message (`lib/logex/declarations.ex:132-141`)?
  - Or raising with every problem, like `merge!` (`runtime.ex:270-289`)?

  §4.4 says it "runs the same checks, as `Tag.new!/4` does for M1-3" (org:474-475).
- **Q1.7 One constructor, two front ends.** How does one checked constructor feed both the
  Elixir path, which raises `ArgumentError`, and the `.lcf` path, which returns located
  diagnostics? The existing pattern is `Declarations.check/1` returning messages, used by
  both `validate!/1` and declaration lines (`declarations.ex:132-141`, `declarations.ex:316-323`).
- **Q1.8 Which checks M2-1's constructor runs** (C7). §4.4's checks are listed under M2-2
  (org:1377). M2-1's constructor is "checked" (org:1365).
- **Q1.9 Refusing what the text cannot say, before the text exists** (C8). M2-1 must fix
  the limits of every field before M2-2's grammar exists:
  - name shape;
  - interval at least 1;
  - priority range;
  - location shape.
- **Q1.10 What `start/1` refuses.** Something other than a configuration, and a
  configuration whose programs are not the types it names. With which pinned messages?

**`cycle/3`**

- **Q1.11 Input keys.** Are the inputs keyed by the global's name (org:512-513, "keyed by
  input-point name")? Does a key that is an output point, an unlocated global or an
  instance path raise? Every problem in one raise, in key order, as `merge!` does? Values
  checked to fit the global's type? §5 leaves a host write to unlocated globals "if
  wanted" (org:1251).
- **Q1.12 The input image.** What is its initial value? 0 for every input point? Does a key
  left out keep its last value? That is decided: "merged into a persistent image"
  (org:550).
- **Q1.13 The output map.**
  - Every output point on every cycle, or only those that changed?
  - Are unlocated globals left out?
  - What is in it on a cycle where no task is due?
- **Q1.14 Events.**
  - Their order: execution order, with each `:overlap` before its task's `:ran`?
  - One `:ran` per scan, so a task of N instances gives N events?
  - Is `task` the task's name, a string?
  - Is `now` the cycle's `now`?
- **Q1.15 Errors in a cycle.** `elapsed_ms` that is negative or not an integer, and `rt`
  that is not a runtime. Can a valid `rt` ever raise inside `call/4`? For example, a
  constant tie-off that does not fit must be refused statically.
- **Q1.16 First-cycle timing** (C14). `start/1`'s `now`: 0, or a start time given? If the
  host's first `cycle/3` has `elapsed_ms` 10 and every periodic task is due at 0, then
  rule D1.9 gives the 10 ms task `missed = 1` in cycle 1, a spurious overlap. The options:
  - anchor `next_due` at the first cycle;
  - require the first cycle at elapsed 0;
  - take a start time.
- **Q1.17 What "one simulated second" means.** M2-3's counts (100 and 20,
  PLAN:1329-1330) imply cycles at t = 0, 10, …, 990. At 10 ms steps the 30 ms task of
  M2-1's acceptance runs at 0, 30, …, 990: 34 times. The acceptance should say how the
  clock is stepped.

**`next_due_in/1` and `get/2`**

- **Q1.18 `next_due_in/1` with task-less instances** (C13). They run every cycle
  (org:577, org:661). Does `next_due_in/1` ignore them, so a configuration of only
  task-less instances returns `:infinity` and a runner never cycles? Or does it return 0,
  so a runner busy-loops? Who paces the cycles ("The runner paces cycles", org:661)? With
  event tasks (M2-6), a SINGLE edge cannot be predicted.
- **Q1.19 What `get/2` accepts:**
  - `inst.tag`;
  - `inst.timer.member`;
  - `inst.fb.member`, at any depth, `m1.s2.run` (PLAN:1345);
  - a bare global name;
  - an internal member (`m1.t1.last`): refused?
  - a function block's `:local` member: refused until M2-5 says who may read one?
    (`lib/logex/fb_type.ex:21-24`)
  - a whole instance or timer (`m1.t1`): its map, or refused?
  - a `var_external` inside an instance (`m1.estop`): the global's value, or refused?
  - task state, such as an overlap count?

  It also asks the error mode for an unknown path: `ArgumentError` with a did-you-mean,
  or `:error`. And the case sensitivity of each part.
- **Q1.20 Overlap counts.** How does a host read them? They are state (org:596), but no
  API returns them except through events.

**Restart, acceptance and tests**

- **Q1.21 Restarting a configuration.** The API has `restart/3` for one instance only
  (org:674). Is there `Runtime.restart(rt, :cold | :warm)`? What does it do to each of
  these?
  - the instance states: `restart/3` each;
  - global values: back to initial, except input points?
  - the input image: kept?
  - `next_due`: re-anchored at `now`, or kept?
  - overlap counts;
  - the last SINGLE values (M2-6);
  - `now`: kept, since time never goes backwards.

  Can a host restart one instance inside a running `rt`?
- **Q1.22 Equal outputs in the acceptance.** What makes the README outputs "identical
  through `scan/2` and a one-instance configuration"? `scan/2`'s outputs are keyed by
  var_output name. A configuration's are keyed by output-point name, so the test must name
  its points after the var_outputs or map one set to the other. Decision 7 needs every
  var_input connected (to points named like them?). Q1.22 also asks whether there is a
  helper that builds the implicit configuration from one program (org:247-249).
- **Q1.23 Growth tests owed.**
  - `cycle/3` in the number of instances and tasks: is due-task selection a sort per
    cycle?
  - The constructor's checks, such as the one-driver check, in the size of the
    configuration.
  - `get/2` in path depth.
- **Q1.24 The contract property.** `api_contract_test.exs` extended to `start/1`,
  `cycle/3` and `get/2`, with every refusal reached (D0.14).
- **Q1.25 The moduledoc.** `Logex.Runtime`'s moduledoc says what is outside the contract
  (`runtime.ex:42-43`). It gains `%Configuration{}` and `%Runtime{}` built or edited by
  hand.
- **Q1.26 One module, two roles.** `%Logex.Runtime{}` as a struct makes `Logex.Runtime`
  both the API module and the resource value. The pinned surface gains `__struct__/0,1`
  (`runtime_test.exs:692-693`). Is that the intent, or is the value its own module?

---

## 2. M2-2 · The configuration file, task-less

### 2(a) Decided rules

- **D2.1 A separate configuration file.** IEC makes a configuration its own library element
  (decision 3, org:1457-1460). The extension `.lcf` is a placeholder: "choose it before
  M2-2, because a rename later is a migration" (org:1459-1460; PLAN:1314-1316).
- **D2.2 Lines** (PLAN:1314-1317; org:1375-1376):
  - `var_global`, plain and located (`at panel.q.0`);
  - `program <inst> <type>`;
  - arrow-free connections (`m1.start pb_start_1`, decision 5).
- **D2.3 Line shapes** (org:406-424):
  - every line is a keyword line or a connection line, starting with a qualified name, and
    indentation is cosmetic;
  - `var_global <n> <type> [<initial>]`;
  - `var_global <n> <type> at <dev>.i.<k>` or `… at <dev>.q.<k>`;
  - `program <inst> <type> [with <task>]`, the type always the third word;
  - `<inst>.<var_input> <global or constant>`, copied in before each scan, a constant
    being a tie-off, as in `m2.reset 0`;
  - `<inst>.<var_output> <global>`, copied out after each scan, one line per sink;
  - connections carry no arrow, and a wrong direction is a diagnostic that names the
    member's section;
  - there are no blocks.
- **D2.4 I/O mapping is IEC's mechanism 2:** a named global given a location (decision 6;
  org:488-494). The location `panel.q.0`:
  - keeps `i` and `q` as Table 15's prefixes;
  - takes the integer fields as the hierarchical address, the leftmost highest;
  - has no size prefix;
  - lexes as one name (org:496-503).

  The `at` stanza must argue the device root plainly as a coinage. The fallback is
  `at %ix0.0` (org:505-508).
- **D2.5 The checks**, each marked as IEC's or logex's (org:426-447):
  - an input point takes no initial value, and nothing may drive it;
  - at most one driver per sink is an error;
  - two var_external writers are a warning (M2-4);
  - every var_input is connected, to a global, a point or a constant (decision 7);
  - types agree at both ends;
  - only a var_input or a var_output connects;
  - an unknown task, type, instance or member is a located diagnostic with a
    did-you-mean.
- **D2.6 Loading** (org:469-475):
  - `Logex.Configuration.compile(name, source, %{"motor" => program, …})` is the pure seam:
    `{:ok, config}` or `{:error, [%Logex.Diagnostic{}]}`, and the core does no file I/O;
  - a convenience loader resolves `motor` to `motor.ld` beside the `.lcf`;
  - a constructor from Elixir data runs the same checks.
- **D2.7 Reserved in `.lcf`:** `program var_global at bool dint` (org:1378; org §4.8,
  org:745). A `var_external` name must be legal in both kinds (org:747-748).
- **D2.8 `configuration_test.exs`** is added (org:1379).
- **D2.9 Acceptance**, verbatim:
  > *two instances of one `.ld` program type, wired in a configuration file to different
  > input and output points, run for N cycles from one input image and keep independent
  > state; a mis-wired, unknown, undriven-input or mistyped connection is a located
  > diagnostic naming its file and line.*

  (PLAN:1317-1320; org:1380-1383.)
- **D2.10 `.ld` only.** "the extension says what kind of file it is, so
  `Logex.compile_file/1` refuses anything but `.ld` with a `:file` diagnostic … its
  `seal.txt` assertion flips with this item" (PLAN:1321-1324; C2).
- **D2.11 Reading output points back is allowed.** The snapshot example reads `k1` and
  `k2` (org:402-404).
- **D2.12 VAR_CONFIG is target, not scheduled.** Refusing it on a var_input is logex's
  rule (org:477-484).
- **D2.13 B8 is fixed** (a lone CR is a newline) before any `.lcf` exists. Done
  (org:1342-1343).

### 2(b) Open questions

**The extension and files**

- **Q2.1 The extension.** Choose it (decision 3). **`.lcf` clashes:** it is the extension
  of the CodeWarrior (NXP) linker command file, "Linker command files must end in .lcf"
  (U26; sources there). That is an embedded toolchain, the audience logex shares. Which
  extension, and its naming argument?
- **Q2.2 How `compile_file/1` refuses a non-`.ld` file.** The message wording. Is the
  extension's case significant (`seal.LD`)? A file with no extension (`seal`,
  `test/logex_test.exs:276`) compiles today and flips too, which PLAN does not mention
  (C2). Does a `.lcf` path given to `compile_file/1` get a message that points to the
  configuration loader?
- **Q2.3 The loader.** Which public function loads a configuration from disk
  (`Logex.Configuration.compile_file/1`? a `load/1`?), and what does it return?
  - Does it compile each `.ld` it resolves, and stamp their diagnostics with their own
    files?
  - Does it return their warnings, and where?
  - Does it resolve the function block types those programs use (M2-5), and from which
    directory: beside the `.lcf`, or beside the `.ld` that names them?
- **Q2.4 A type with no file.** A type named in the `.lcf` with no `<type>.ld` beside it
  is a `:file` diagnostic at the `program` line? The same for a type name that cannot name
  a file.

**`compile/3`**

- **Q2.5 The `types` map.** `Configuration.compile/3`'s argument order (C15). Is it a host
  mistake when a key differs from its program's `name`? A program with no name? A function
  block type passed as a program? An unused type: warn, or ignore?
- **Q2.6 The configuration's own name.** Where does it come from: the basename? What is it
  used for, given that access paths omit the resource (org:678)? Is it checked for shape
  like a program's name (`lib/logex.ex:116-125`)?

**Parsing**

- **Q2.7 The parser.** Reuse `Logex.Lexer`/`Logex.Parser`, which read the §4.4 plant as a
  well-formed tree of rungs (§12, probe 1), so there is no grammar change and no golden
  change? Or write a dedicated line parser? Either way: a branch group in a `.lcf` line is
  a diagnostic.
- **Q2.8 Case.** Are keywords case-insensitive in `.lcf` (D0.10) while names stay
  case-sensitive? What is the case of a location's `i` and `q` (`panel.Q.0`)?

**Locations and globals**

- **Q2.9 The location grammar.**
  - Is the device one name, or may it be dotted (`rack1.slot2.i.0`)?
  - How many integer fields: one, or a hierarchy (`panel.i.0.3`), which "integer fields"
    (org:498-499) suggests?
  - Only `i` and `q`, or memory too?
  - May a device be spelled like a reserved word (`program.i.0`)? §4.8 says a qualified
    token is never a keyword (org:753-754).
  - Two globals at one address: refused?
  - Where is a location's legality checked in the data constructor?
- **Q2.10 Initial values.** May an output point take an initial value, and where on the
  line, before or after `at`? The table gives none with `at` (org:413-414). An initial
  value must fit, and a negative one cannot lex yet (PLAN §5, PLAN:1871-1876).
- **Q2.11 The namespace** (Q1.5). Clashes among globals, instances, task names, program
  types and function block types. An instance named like its type (`program motor
  motor`)? A name that is a `.lcf` keyword is refused, with which message?

**The `program` line**

- **Q2.12 Program line checks.**
  - An unknown type, with a did-you-mean among the types given.
  - A type that is a function block, given that programs are not callable and function
    blocks are not instantiated in a resource.
  - An instance declared twice.
  - A `with` on a program line before M2-3 lands: a diagnostic that tasks arrive later, or
    simply unknown?

**Connection lines**

- **Q2.13 Connection checks** beyond D2.5:
  - a constant on an output connection;
  - a constant that does not fit;
  - a var_input connected twice;
  - a var_output to several sinks, allowed (org:417);
  - a global driven by one connection and also written by a `var_external`: error or
    warning? (§4.4 makes the first an error and the second a warning, org:428-433);
  - a member path deeper than one (`m1.t1.pre`, `m1.s1.run`): refused as "only a
    var_input or var_output connects";
  - a connection whose instance is declared on a later line;
  - a connection line before its `program` line.
- **Q2.14 Where an unconnected var_input is cited.** It has no line of its own: is it the
  `program` line? In which file: the `.lcf`, which needs F15's answer only for the
  `.lcf`? Is its message the spike's, "undriven input"?

**Diagnostics and warnings**

- **Q2.15 Diagnostic wording.** The spike's seven messages (org:452-460) are not decided
  wording and are pinned by no test (org:1704; U17). Which are adopted? The did-you-mean
  reuses `Declarations.suggest/4` (`declarations.ex:67-89`)?
- **Q2.16 Diagnostic order** across a `.lcf` and the `.ld` files it loads. In line order
  per file? Files in which order?
- **Q2.17 Warnings, if any:**
  - an unused global;
  - an input point nothing reads;
  - an output point nothing drives, which stays at its initial value;
  - an unconnected var_output.

**Online edit**

- **Q2.18 Rules for new state across an online edit** (D0.17, for OE-2):
  - a global an edit adds: its initial value;
  - a global it removes: pruned at assemble;
  - a global whose initial value changes: like decision 29;
  - a located global's `at`: refused while running (org:860-863);
  - a connection added or removed: allowed (org:869);
  - an instance added: through `instance/1`, so `first` is true;
  - an instance removed: pruned.

---

## 3. M2-3 · Periodic tasks in text

### 3(a) Decided rules

- **D3.1 Lines.** `task <n> interval <ms> priority <p>` and `with` (PLAN:1325; org:1386).
  PRIORITY is mandatory, as IEC's grammar has it, and 0 is the highest (org:411; decision
  11).
- **D3.2 Reserved in `.lcf`:** `task interval priority with` (org:1387).
- **D3.3 A task needs `interval` or `single`,** and `interval` is at least 1. IEC reads
  INTERVAL 0 as no periodic scheduling, and MatIEC runs such a task every tick, so logex
  refuses the ambiguous case (org:442-444).
- **D3.4 Acceptance**, verbatim:
  > *the plant of `docs/organisation.md` §4.4 without its event task, its `motor` the §4.2
  > one plus `var t1 ton` and a rung `xic motor ton t1 5000` … driven for one simulated
  > second, runs `m1` 100 times and `m2` 20 times, and each instance's `t1` times against
  > the one clock.*

  It must "say how the inputs are timed": the equality holds per rising edge, when both
  instances see the edge at one time and the preset is a multiple of both periods. A
  timer that re-triggers itself differs by task (PLAN:1325-1334; org:711-722).
- **D3.5 Changes while running.** A task's interval and priority may change while running.
  Moving an instance to another task is refused, and adding or removing a task is refused
  until its rule is verified (decision 19; org:858-871; PLAN §5, PLAN:1795-1796).
- **D3.6 One task per instance.** An instance runs under at most one task. IEC's
  `PROGRAM inst WITH task` (org:415) and the conventional family's "A program can be
  scheduled under one task only" (org:168).

### 3(b) Open questions

- **Q3.1 Priority range.** Any non-negative integer, a dint, or a bound? IEC leaves it
  open, and the conventional family's documents disagree on range (org:165; U2). What of
  two tasks of equal priority? That is decided: earlier due time, then declaration order.
- **Q3.2 Interval upper bound.** A dint? Must it be a literal? That is decided: "INTERVAL
  is an integer constant in ms" (org:662).
- **Q3.3 Word order.** Must `interval` come before `priority`? Is either repeated an
  error? Is a missing `priority` "PRIORITY is mandatory"?
- **Q3.4 Task names.** A task named like a global or an instance (Q1.5). Two tasks of one
  name.
- **Q3.5 Line order.** Must a `task` line precede the `program` lines that use it? The
  spike says "declare it first" (org:454).
- **Q3.6 A task with no instance.** A warning? Does it still keep `next_due`, and can it
  overlap?
- **Q3.7 `with` on an unknown task.** The spike's message (org:454) is not decided. Is it
  adopted?
- **Q3.8 Rules for new state across an edit** (D0.17, for OE-2). `next_due` and the
  overlap count, at start, at a configuration restart, and when an edit changes the
  interval or the priority (decision 19). On an interval change, is `next_due` re-anchored
  at the switch, kept, or moved to the next multiple?
- **Q3.9 How the acceptance's inputs are timed.** Which cycle step? 10 ms, from t = 0
  (Q1.16, Q1.17).

---

## 4. M2-4 · Shared globals

### 4(a) Decided rules

- **D4.1 Scope.** `var_external` in `.ld`, reserved there. The type agreement of Ed 2
  §2.4.3, no writes to an input point, and a two-writer warning (PLAN:1335-1336;
  org:1393-1396).
- **D4.2 Acceptance**, verbatim:
  > *an e-stop declared once as a `var_global` and read by two instances through
  > `var_external` stops both in the same cycle; a `var_external` with no matching
  > global, or of another type, is a located diagnostic.*

  (PLAN:1336-1339; org:1397-1399.)
- **D4.3 The binding.** `var_external estop bool` binds to the configuration's
  `var_global estop bool` by name. During a scan it reads and writes the global directly.
  Per-instance wiring stays a connection (org:462-465).
- **D4.4 Input points.** A program that writes a `var_external` bound to an input point is
  an error, "so `%Logex.Program{}` records which tags it writes" (org:465-467). Nothing
  may drive an input point, including a write through a `var_external` (org:428-429).
- **D4.5 Two writers.** Two instances that write one global through `var_external` are a
  warning, "in M1-5's `warnings:` channel" (org:431-433; C5).
- **D4.6 A row in the section table.** `var_external` is one more row of the data table of
  sections, with no second declaration parser (org §6.1 point 1, org:1268-1270;
  PLAN:731-733).
- **D4.7 Names legal in two kinds.** A `var_external` name must be legal in both file
  kinds, because it is declared again as a `var_global` (org:747-748).
- **D4.8 One copy.** There is one copy of each global's value (org:886).
- **D4.9 Scope.** The file is the POU's scope. There is no controller scope, and sharing
  goes through `var_global`/`var_external` (PLAN:752-753; org:1243).
- **D4.10 Visibility** follows execution order (D1.8).

### 4(b) Open questions

**The value at run time**

- **Q4.1 One copy against `call/4`'s instance env.**
  - `call/4` runs rungs over `state.env` (`runtime.ex:141-151`).
  - `initial_env/1` gives every declared tag a value (`program.ex:44-45`), so a
    `var_external` would get a second, per-instance copy.
  - `call/4`'s `inputs` refuse anything but a var_input, with "is a var_external, not a
    var_input: only a var_input is set from outside" (`runtime.ex:303-308`).

  The options:
  - copy the globals into the env before each scan and out after, a transient second
    copy;
  - a globals map threaded beside the env, read and written by `read/2` and `write/3`;
  - a private entry for the scheduler.

  Each must keep D1.8's visibility. Which one, and does `call/4`'s contract change?
- **Q4.2 A lone program with a `var_external`.** What do `instance/1`, `scan/2,3`,
  `call/4` and `restart/3` do with it?
  - Refuse it: a program with a `var_external` runs only in a configuration.
  - Treat it as an instance-local tag, starting at 0.
  - Something else.

  M1's done sentence and the implicit configuration (org:245-249) have no globals.
- **Q4.3 An initial value on a `var_external`.** Refused? IEC's rule on initialising a
  VAR_EXTERNAL is not quoted in the documents (U18).
- **Q4.4 Which sections may hold an external.** `var_external` of a timer or a function
  block instance: only `bool` and `dint`?

**Checks and diagnostics**

- **Q4.5 Where the type-agreement and no-matching-global diagnostics are cited.** At the
  `.ld` declaration line, which needs the program's file (Q0.2), or at the `.lcf`
  `program` line? Which message?
- **Q4.6 Recording the writes.** How `%Program{}` "records which tags it writes":
  - a new field, `writes:`;
  - a function computed on demand;
  - reuse of `Logex.Edit`'s private walk (`edit.ex:489-518`).

  Do writes through a `cal` output (M2-5), through an `ons` bit and through members
  count?
- **Q4.7 The mixed case.** A global with a connection driving it and a `var_external`
  writer is an error or a warning (Q2.13).
- **Q4.8 Where a `var_external` name is checked against `.lcf` keywords** (D4.7). At the
  `.ld` compile, which knows nothing of `.lcf`? At the configuration compile, which then
  cites the `.ld`?
- **Q4.9 Function block files.** Is `var_external` allowed in a function block file (M2-5)?
  IEC allows VAR_EXTERNAL in function blocks (U19). If allowed: the input-point write check
  must see writes inside block bodies, and Q4.1's mechanism must reach a nested `cal`.
- **Q4.10 Warnings.** The warning for "declared but no rung uses it" already covers an
  unused `var_external` (`lib/logex/warnings.ex:70-71`). Are there others?

**Online edit and access**

- **Q4.11 Online-edit rules** (D0.17):
  - `Logex.Edit` on a lone program whose candidate moves a tag from `var` to
    `var_external` or back. Decision 25 allows a section change and keeps the value, but
    the value then lives in the configuration;
  - a plain swap of such a program;
  - what the report says.
- **Q4.12 `get(rt, "m1.estop")`** (Q1.19).

---

## 5. M2-5 · User function blocks

### 5(a) Decided rules

- **D5.1 Scope.**
  - `function_block <name>` as a file's first line, matching the file name (decision 4).
  - Instances, `var s1 seal`.
  - `cal` with positional operands, rung power as EN, and nothing copied on a false EN.
  - Nesting.
  - Recursion is a diagnostic.

  (PLAN:1340-1343; org:1401-1406.)
- **D5.2 Acceptance**, verbatim:
  > *a seal-in written once as a function block and instantiated three times in one
  > program behaves as three independent seal-ins, `m1.s2.run` reads one of them, a false
  > EN freezes only its own instance, and a recursive type, an unknown FB type or a `cal`
  > of a non-instance is a located diagnostic.*

  (PLAN:1343-1347; org:1407-1410; C1.)
- **D5.3 Prerequisites.** M2-5 needs only M1-6 and B5, so it may move ahead of M2-1
  (PLAN:1295; org:1402; decision 1).
- **D5.4 A function block file.** It is a `.ld` file whose first line names its kind. Its
  shape is the `seal` example (org:253-262).
- **D5.5 `cal` and EN** (org:293-307; decision 12):
  - rung power is the instance's EN;
  - ENO is the power out;
  - on a false EN, `cal` copies nothing in and writes nothing out, so the instance is
    frozen, and so is every tag its output operands name.
- **D5.6 Two meanings of rung power.** Built-in timers keep the conventional model: rung
  power is IN, and a false rung resets the timer. The `cal` stanza must say so. The
  de-energised `evaluate` clause is mandatory for both (org:309-312).
- **D5.7 `cal`'s signature** comes from the function block type (org:319-329):
  - the operands are positional: the var_inputs, then the var_outputs, in declaration
    order, as IL's non-formal CAL (Ed 2 Table 53 feature 1a);
  - an arity or type error names the formal, for example ``operand 2 of `cal s1` is
    `stop` (var_input bool)``;
  - two swapped bool operands still compile;
  - `@instructions` and `naming_test.exs` stay the table of built-in mnemonics, and the
    signatures of user types are built per compile;
  - reads of outputs such as `s1.run` work anywhere (C3 on writes).
- **D5.8 Why the word `cal`.** The rule-1 claim rests on Ed 2/3 IL. `docs/naming.md` is
  append-only, so M2-5 appends a `cal` stanza that supersedes its `cal <routine>` row and
  leaves the row in place (org:331-340; the row is `docs/naming.md:240`).
- **D5.9 Recursion is a diagnostic.** logex forbids a cycle among function block types
  (org:342-344).
- **D5.10 Nested state.** `m1.s1.run` (org:207). One instance is one nested map
  (org:343-344). `%Logex.FbType{}` is the schema that M2-5 reuses (PLAN:1157-1159,
  PLAN:1202-1203; decision 9).
- **D5.11 Facts from M1-6, for this item** (PLAN:1347-1353):
  1. `Logex.FbType` already recurses into a member whose type is a type.
  2. `public/1` leaves a `:local` role out by default.
  3. A frozen instance must leave a timer's `.en` and `last` alone, so a timer that was
     timing catches up.
  4. The "no `ton` runs it" warning must say `cal` for a user type.
  5. `first` is the program instance's, so an `ons` inside a block frozen on the first
     scan is not held back when it first runs.
  6. Which of a user block's members logic may write is open.
  7. `cal` on a built-in type should be refused.
- **D5.12 Per-timer `last`.** It is chosen because it catches up in the frozen
  function block case (decision 8, org:1473-1475; org:633-636).
- **D5.13 Type names are not reserved.** A user function block's name "is built per
  compile, not a row, so it is not reserved" (PLAN:732-734).
- **D5.14 Private re-entry.** A call into a function block re-enters rung evaluation, and
  must not do so through a public clause (org §6.1 M1-5 point 6, org:1299-1301; B5).
- **D5.15 Dotted names.** A dotted name in a body that is not a declared member is a
  located diagnostic, never a reach into another instance (org:735-737).
- **D5.16 Edits of a block's members.** They are refused while running, "until M2-5 brings
  the nested migration: copy the members that match by name and type, as CODESYS does,
  and initialise the rest" (org:866-867; PLAN OE-2, PLAN:1491-1493).
- **D5.17 Reserved.** `function_block` in function block files (org:744). `cal` is a
  mnemonic, so it is reserved in any case in every `.ld` (org:743; CLAUDE.md:146-157).
- **D5.18 Code that names M2-5 as its decider:**
  - `Runtime.blocked?/2`'s member clause: "M2-5, whose function blocks may have such a
    member, decides how one is named" (`runtime.ex:479-484`);
  - `Declarations.fb_type/1`: "Only a built-in function block type … until M2-5"
    (`declarations.ex:349-355`);
  - `FbType`'s moduledoc on `:local` (`fb_type.ex:21-24`).

### 5(b) Open questions

**The file and its kind**

- **Q5.1 The header.**
  - Where is it parsed: `Logex.compile`, `Declarations`, or a new module?
    `Declarations.declaration?/1` takes only section words (`declarations.ex:143`).
  - Must it be the first rung, given that blank lines and comments come before it and the
    lexer drops them?
  - A `function_block` line anywhere else is a diagnostic.
  - Name shape, and a reserved word as a block name. `move.ld` compiles as a program today
    (`test/logex_test.exs:281-284`). A block's name is spelled in a `.ld` body (`var s1
    move`), so the shape-only rule cannot hold for it (C18).
- **Q5.2 "Matching the file name".** Checked only by `compile_file/1`? With
  `Logex.compile(source, name:)`, must `name:` match the header, or does the header name
  it?
- **Q5.3 What compiling a block returns.** `%Logex.Program{}` with a kind,
  `%Logex.FbType{}` with a body, or a new struct? What do `compile/2` and
  `compile_file/1` return for a block file? Their docs say "a program" (`lib/logex.ex:41-49`).

**Where the body lives, and how blocks reach the compiler**

- **Q5.4 Where the body's rungs live, and how the evaluator reaches them.**
  - (a) `%FbType{}` gains `rungs`. Then the equality in `Declarations.fb_type/1`
    (`declarations.ex:352-353`) and `Edit`'s `retyped/2`, which compares `Tag.type` with
    `!=` (`edit.ex:357-365`), refuse every edit of a block's body as a type change. That
    includes a body whose lines only moved, if lines are kept (C12).
  - (b) The program carries a library of types, and the IR `cal` names its type. The
    evaluator then needs the library, beyond `(instruction, {power, env}, %Scan{})`
    (C11).
  - (c) The body is inlined in the IR per `cal`.
- **Q5.5 How a library reaches the compiler.**
  - `instructionize/3`? The pinned surface is `instructionize/1,2`
    (`runtime_test.exs:695-696`).
  - An option on `Logex.compile/2` (Q0.7).
  - A loader in `compile_file/1` resolving `seal` to `seal.ld`: beside the program? beside
    the `.lcf` (Q2.3)?
  - A pure seam taking compiled types, as `Configuration.compile/3` does.

  `Declarations.split/2` has no library parameter, and `type_word/1` knows only builtins
  (`declarations.ex:34-37`, `declarations.ex:111-121`). Org §6.1 says `var s1 seal`
  "resolve[s] through the same type lookup" (org:1268-1270).
- **Q5.6 Namespaces.**
  - Can a tag share the name of a block type in scope (`var seal seal`)?
  - Can a block be named like a program type?
  - Is there one namespace for program and block types in a configuration (Q1.5)?
  - Is a block named like a built-in (`ton.ld`) refused? `ton` is reserved.

**Recursion and unknown types**

- **Q5.7 Recursion detection.** Where:
  - in the loader, as a cycle while resolving files;
  - or impossible by construction, if blocks are passed in compiled, since a compiled
    type can only reference types compiled before it.

  Where is it cited: at the `var` line that closes the cycle, in which file (Q0.2), and
  naming the cycle's path? A block naming itself? Growth in the library's size.
- **Q5.8 The unknown-type message.** Today it reads "unknown type `seal`: logex has
  `bool`, `dint` and `ton`" (`declarations.ex:293-294`; probe 1), and it is pinned at
  `validation_test.exs:416`, `:505`, `:661` and `:1105`. With a library, does it list the
  library's types, or give a did-you-mean among them?

**`cal`**

- **Q5.9 `cal` in `@instructions`.** How is it represented there? It must be a key, so
  that it is reserved (`declarations.ex:40-43`) and surveyed (`naming_test.exs:35-48`).
  Its signature is variadic and per compile. `kind/1` and `check_kind/4` need a clause
  for any new access kind (`compiler.ex:378-415`).
- **Q5.10 `cal`'s operand rules.**
  - A var_input operand is a `:value`: a tag, a member or a literal that fits.
  - A var_output operand is a `:write`: a tag or a writable member, never the caller's
    var_input. A literal there is an error.
  - May trailing outputs be left out, so that `s1.run` is read instead?
  - The exact message form for arity and type (D5.7's example).
- **Q5.11 A `cal` of what.**
  - `cal` of a non-instance or an undeclared name: in the acceptance.
  - `cal` of a built-in, `cal t1`: refuse, with which message?
  - `ton s1 5000` on a user instance: the existing `{:instance, "ton"}` check.
  - A second `cal` of one instance: error, warning, or allowed? IEC allows calling an
    instance more than once per scan. logex refuses a second `ton` on a timer
    (`compiler.ex:106-147`).
  - `cal` inside a branch leg.
  - What may follow `cal` on its path: ENO is the power out (D5.5), so is everything
    allowed?
- **Q5.12 The evaluator's `cal` clauses.**
  - Energised: copy the var_inputs in, run the body over the instance's nested map, then
    copy the var_outputs out.
  - De-energised: nothing, and pass no power.
  - Does the body see the same `%Scan{}`? Its `now` yes. Its `first` is the program's
    (D5.11 point 5). Its `ons_blocked` see Q5.15.
  - Recursion of the private evaluator (D5.14).

**`first`, one-shots and timers inside blocks**

- **Q5.13 `first` inside blocks.** Accept D5.11 point 5 as a documented consequence? Or
  give each block instance its own first-run bit, which is new state with D0.17's rules?
  IEC's R_TRIG fires on its first execution if CLK is 1 (U20).
- **Q5.14 An `ons` inside a block.**
  - Its storage bit is a member of the instance: a `var` of the block, `:local`.
  - A second `ons` on one bit is checked per body (`compiler.ex:76-104`).
  - Two instances of one type have separate bits.
- **Q5.15 `ons_blocked` paths** (C11).
  - The block list holds names checked to be binaries (`runtime.ex:198-211`).
  - The scan's map is keyed by top-level names.
  - `blocked?({:member, _, _path}, _)` is always false (`runtime.ex:483-484`).

  If a body runs with the program's scan, a program tag `edge` that an edit blocks also
  blocks every block's own `edge`: a collision. How is a nested bit named (`"s1.edge"`?),
  and how does a body see only its own?

  An edit that adds `var s4 seal` and `cal s4` must keep `s4`'s internal `ons` from firing
  on the switch scan, as decision 21 requires of an added `ons`. A block first run on a
  later scan has the same problem with `first` (Q5.13).
- **Q5.16 Timers inside blocks.**
  - The preset comes from the body's `ton`, into the member's `initial` map
    (`fb_type.ex:75-84`).
  - "No `ton` runs it" inside a body.
  - Is `move 3000 s1.t1.pre` from outside allowed? It is a path three deep, and the
    compiler reports anything past one member as too deep (`compiler.ex:533-541`).
  - Is `ton s1.t1 5000` from outside refused?
  - Under a frozen EN, `.en` and `last` are untouched (D5.11 point 3).
  - The interplay with §4.9's Resume rule (C9).
- **Q5.17 Warnings.**
  - An instance no `cal` runs, "must say `cal`" (D5.11 point 4). The message today is
    "`t2` is a ton, but no `ton` runs it: it never times" (`warnings.ex:75-83`).
  - `Warnings.uses/2` must count `cal`'s operands (C10). Otherwise `motor`, written only
    by `cal s1 start halt motor`, is warned "a var_output, but no rung writes it", and
    `s1` "declared but no rung uses it".
  - A tag written by both an `ote` and a `cal` output: a warning?

**Members**

- **Q5.18 Which members are readable from outside.**
  - `:input`: `public/1` includes inputs (`fb_type.ex:96-97`).
  - `:output`: decided readable.
  - `:local`.
  - Nested members at depth (`s1.t1.acc`).

  It also asks how many path parts the compiler takes past one member. It reports more
  as too deep today.
- **Q5.19 Which members logic outside may write** (C3). None? Inputs, as IEC's ST allows
  assigning an instance's input outside a call (U21)? The members a `write: true` flag
  marks, where a block file has no syntax to set it? And `ons s1.x`, `otl s1.x`.
- **Q5.20 Declarations inside a block.**
  - A var_input with an initial value: IEC gives defaults, but positional `cal` passes
    every input, and M1-3 refuses an initial value on a var_input.
  - A var_output with an initial value.
  - Instances inside a block (`var t1 ton`, `var s seal2`).
  - `var_external` inside a block (Q4.9).
  - The body writing its own var_input: refused already by the check for "logic must not
    write an input" (`compiler.ex:720-726`).
  - Does a block's `var_output` stay out of the host's outputs? It never reaches them,
    since a block is not a program.
- **Q5.21 Messages that change**, and the tests that pin them (§10):
  - "only a timer has members" (`compiler.ex:647-652`; `validation_test.exs:1607`,
    `:1611`, `:1637`, `:1692`);
  - "logex has :bool, :dint and Logex.FbType.ton()" (`declarations.ex:346-347`, `:363-364`;
    `validation_test.exs:1125`, `:1134-1152`, `:1740`);
  - "unknown type …: logex has `bool`, `dint` and `ton`" (Q5.8).

**`Logex.Edit`**

- **Q5.22 `Logex.Edit` with blocks** (C9, C10, C12):
  1. `rungs/1` and `written/3` look each IR symbol up with `Map.fetch!`, so a `cal` raises
     `KeyError` (probe 2).
  2. Writes through `cal` outputs must count, or held outputs are missed.
  3. `facts/1` takes every `%FbType{}` tag for a timer (`edit.ex:407`). A user block with
     a member named `pre` reaches the `.pre` rules (`edit.ex:633-654`).
  4. `fit/1` checks a block's top-level keys only (`edit.ex:479-480`, `edit.ex:617-618`).
  5. `retyped/2`'s message names a type by its name only (`edit.ex:367-377`). A changed
     `seal` reads "`s1` is a seal in the running program and a seal in the candidate".
  6. An added block instance's internal one-shots (Q5.15).
  7. The nested migration (D5.16): is it M2-5's to build, or OE-2's?
- **Q5.23 Tags from Elixir.** `Tag.new!/4` with a user `%FbType{}`. `check/1` refuses any
  non-built-in type (`declarations.ex:349-364`). How does the data path check that a
  hand-built type is one a block file could say: members, roles, write flags, no
  `:clock`, no `:internal`?
- **Q5.24 The typespec.** `FbType.Member`'s `role` lacks `:local`, which its moduledoc
  names (`fb_type.ex:21-24` against `fb_type.ex:35`). Is `:local` a role, or is a block's
  `var` an `:internal`?

**Acceptance, tests and documents**

- **Q5.25 The acceptance, if M2-5 lands before M2-1.** It names `m1.s2.run`, an access path
  of M2-1's `get/2` in a configuration (C1). Reword it to read `s2.run` from one instance,
  through `call/4`'s outputs or `state.env`, and assert `m1.s2.run` again at M2-1?
- **Q5.26 Growth tests owed:**
  - compiling a block nested N deep;
  - a large library, for recursion detection;
  - a `cal` with many operands;
  - the scan cost of `cal` at depth;
  - `Logex.Edit`'s walks over `cal`.
- **Q5.27 The contract property.** `api_contract_test.exs` reaches `cal`, blocks and
  nested state. Its `@words` vocabulary (`api_contract_test.exs:58-59`) has no block word.
- **Q5.28 Documents.** A README row for `cal` and syntax-list entries for `function_block`
  (D0.12). The `cal` stanza's two meanings of rung power (D5.6).

---

## 6. M2-6 · Event tasks

### 6(a) Decided rules

- **D6.1 Line.** `task <n> single <g> [interval <ms>] priority <p>` (PLAN:1354; org:412).
  The task fires on a rising edge, and in the first cycle if the trigger is already true.
  With `interval` too, it runs periodically only while the trigger is 0, plus a run on
  each edge (IEC rule 2; PLAN:1354-1356).
- **D6.2 Reserved in `.lcf`:** `single` (org:1414).
- **D6.3 Acceptance**, verbatim:
  > *an event task triggered from an input point runs once per rising edge, before
  > lower-priority tasks due in the same cycle, and runs in cycle 1 if its trigger is
  > already true.*

  (PLAN:1356-1358; org:1415-1417.)
- **D6.4 Sampling** (org:559-569):
  - `single` is sampled once per cycle;
  - a 0→1 change since the last cycle makes the task due;
  - a trigger already 1 in the first cycle counts as an edge, MatIEC's reading
    (decision 11);
  - a 1→0→1 pulse inside one host step cannot be seen;
  - a trigger written by logic takes effect in the next cycle.
- **D6.5 The source.** A `single` source must be a bool global, a logex restriction
  (org:445-447; org:662).
- **D6.6 State.** Per task, the last SINGLE value (org:208).
- **D6.7 A warning waits for this item.** "A `ton` in an event-task program times across
  events. It should be an M1-5 warning … the warning waits for event tasks, M2-6"
  (org:649-652).
- **D6.8 An exception to the one rule.** The trigger is a listed exception to the one rule
  for new state: "M2-6 will add an event task's trigger" (`program.ex:41-42`; org:1122;
  org:879-880).

### 6(b) Open questions

- **Q6.1 When `single` is sampled.** After the input merge and before any scan (D6.4
  implies it). Is that stated as such?
- **Q6.2 Which globals may be a trigger.** Any bool global: an input point, an unlocated
  global written by logic, or an output point? D6.5 says "a bool global".
- **Q6.3 `single` with `interval`.**
  - An edge and a periodic due time in one cycle: one run or two?
  - Does an edge's run move the periodic phase?
  - While the trigger is 1, does `next_due` keep advancing? It must not count overlaps
    for the periods it suspends.
  - When the trigger falls to 0, is the task due at once, or at the next phase?
- **Q6.4 Ordering.** An event task's "due time" for the earlier-due-time tie-break (D1.7)
  among tasks of equal priority.
- **Q6.5 Overlaps.** A pure event task never overlaps in zero time. With `interval`,
  overlaps count as for a periodic task?
- **Q6.6 Rules for the trigger's state** (D0.17, D6.8):
  - at `start/1`: 0, so an already-true trigger fires;
  - at a configuration restart: back to 0, so it fires again, as IEC's R_TRIG note on a
    cold restart reads (org:563-566), or kept;
  - at an OE-2 edit: adding a task is refused (decision 19). But an edit that changes a
    trigger's source, or adds or removes `interval` on an event task, is not listed as
    allowed or refused (org:869-871). What is "the exception" D6.8 names? A trigger
    sampled without firing?
- **Q6.7 `next_due_in/1` with event tasks** (Q1.18). An edge cannot be predicted, so does
  a runner cycle on every input change?
- **Q6.8 The warning.** Where the ton-in-an-event-task warning lives (Q0.3, C27), and which
  file and line it cites. Is there a matching caveat for `ons`?
- **Q6.9 Shared and checked triggers.** Two tasks on one trigger. A trigger that is a
  `var_output` connected to a global. A trigger not declared, or of type dint: "a bool
  global" (D6.5), with which messages?

---

## 7. OE-2's constraints on Milestone 2

### 7(a) Decided rules

From org §4.9, "What Milestone 2 must keep, so that this needs no rework" (org:873-887),
which PLAN M2-1 repeats (PLAN:1304-1313):

- **D7.1 Plain data.** The runtime value holds plain data only: no funs, pids or refs.
- **D7.2 Keyed by name.** Every piece of runtime state is keyed by name, never by
  position. Program instances are held flat, keyed by instance name, and never nested
  under a task. Execution order is a list in the configuration.
- **D7.3 One rule per new piece of state.** Each M2 item writes its rule for a new piece of
  state once, used by `start/1` and by an edit that adds one. The edit's exceptions are
  listed: `ons`, an event task's trigger and `first`.
- **D7.4 One checked constructor,** which the `.lcf` parser feeds.
- **D7.5 Fix F14.** `start/1` builds each instance through the same constructor as
  `Runtime.instance/1`.
- **D7.6 Opaque.** `%Logex.Runtime{}` is opaque, and its configuration changes only
  through the API.
- **D7.7 One copy** of each global's value.
- **D7.8 Open events.** The events `cycle/3` returns are an open set, which a host must
  tolerate.

Further:

- **D7.9 The edit cycle.** Accept, test, untest, assemble, cancel. The candidate is "the
  whole configuration" from M2 (org:797-799). Every switch happens between two cycles
  (org:808-809).
- **D7.10 Changes while running** (decision 19; org:858-871; PLAN:1488-1495).
  - **Refused:** a type change; located I/O and devices; moving an instance to another
    task; adding or removing a task, until verified; a block's members, until the nested
    migration.
  - **Allowed:** rungs; adding and removing tags, instances, globals and connections; a
    section change; a task's interval and priority.
- **D7.11 Held output points.** Output points left undriven are held and reported. "From
  M2-2 each output point" is in every step's report (org:852-856; C6).
- **D7.12 Fix F5.** OE-2 builds one plan per program type and calls a per-instance switch
  and prune for each instance. These stay private until OE-2 (org:924-929;
  `edit.ex:167-171`; PLAN:1433-1434). A report names an `instance.tag` path from OE-2
  (org:929).
- **D7.13 A generation counter.** Errors outside OE-1's contract are detected only once
  OE-2's configuration carries one (org:981; `edit.ex:178-182`).
- **D7.14 Fix F15.** An `:edit` diagnostic carries no file. Milestone 2 needs it closed
  (org:954-956; org:1630-1631).
- **D7.15 OE-2's Done-when** is "to be written by its design pass, after M2-6"
  (PLAN:1494-1495).
- **D7.16 No Elixir compiler** on the edit path (D0.8).

### 7(b) Open questions M2 must answer for OE-2

- **Q7.1 The per-item rules.** For every new piece of state, each M2 item states its value
  at `start/1`, at each `cycle/3`, at a configuration restart (Q1.21), and at an edit that
  adds it, keeps it or removes it. The pieces:
  - global values (Q2.18);
  - the input image;
  - `next_due` and overlap counts (Q3.8);
  - the last SINGLE value (Q6.6);
  - a block instance's nested members and its nested one-shots (Q5.15).
- **Q7.2 A generation field.** Does M2-1's `%Runtime{}` reserve it now (Q1.3), or does OE-2
  add it?
- **Q7.3 Comparable shapes.** Do M2's shapes let OE-2 compare two configurations by name?
  - Instance to type and task, so a move is refused.
  - A global's `at`, so a change of located I/O is refused.
  - A task's interval and priority, so a change is allowed.
- **Q7.4 One plan per type.** Can OE-2 find every instance of a type? `Instance.type` holds
  the program name (`instance.ex:27-28`).
- **Q7.5 Output points held during M2.** Is anything owed before OE-2 (C6)?
- **Q7.6 Edits during M2.** With `%Runtime{}` opaque (D1.5), a host cannot take an instance
  out to run `Logex.Edit` on it. So no running configuration can be edited at all until
  OE-2. Is that accepted, and documented?
- **Q7.7 Instance-level edits.** Does `Logex.Edit` itself change during M2 (Q4.11,
  Q5.22)? Those are instance-level edit rules, not OE-2's.

---

## 8. Contradictions and tensions

- **C1 M2-5's acceptance against "M2-5 may move ahead of M2-1".**
  - PLAN:1295: "M2-5 needs only M1-6 and B5, so it may move ahead of M2-1"; org:1402.
  - PLAN:1345 and org:1408: "`m1.s2.run` reads one of them". That is an access path of a
    configuration's instance `m1`, read by M2-1's `Runtime.get/2` (org:678).

  Landed first, M2-5 has no `m1` and no `get/2`.
- **C2 The `.ld`-only rule.**
  - PLAN:1321-1324: "Also decided 2026-09-30: … `Logex.compile_file/1` refuses anything
    but `.ld` … its `seal.txt` assertion flips with this item."
  - `test/logex_test.exs:270-271`: "No document chooses between that and `.ld` only; if
    one does, the first line flips." This comment is stale against PLAN.

  The same test's second assertion, a file with no extension
  (`test/logex_test.exs:276`), flips too, and PLAN does not say so.
- **C3 Writes to a user block's members.**
  - org:328-329: "Writes to an instance's members from outside it: reads anywhere, writes
    only to `.pre` and `.acc` (decision 9; M1-6)." That reads as decided, giving a user
    block no writable member.
  - PLAN:1352: "which of a user block's members logic may write is open"; and
    `fb_type.ex:16-18`.
- **C4 `function_block`'s reservation against how a file's kind is detected.**
  - org:744: `function_block` is reserved in a function block file only, not in a program
    file.
  - Decision 4 (org:1461-1463): a file's kind is its first line, and both kinds are
    `.ld`.

  So the word must be recognised in the first-line position of every `.ld` before its
  kind is known. A program may declare `var function_block bool` today (§12, probe 1).
- **C5 The two-writer warning's channel.**
  - org:431-433: "that is a warning, in M1-5's `warnings:` channel".
  - M1-5's channel is `%Program{}.warnings`, built by `instructionize/2` from one program
    (`compiler.ex:260-261`; `warnings.ex:19-40`). It cannot see two instances.
- **C6 Held output points before OE-2.**
  - org:855-856: "The report of every step lists each var_output, and from M2-2 each
    output point, that no logic drives any more."
  - PLAN:1488: a configuration edit is OE-2, "after Milestone 2".

  No step of M2-2 reports.
- **C7 Globals, connections and checks: M2-1 or M2-2?**
  - org §4.1, org:203-204: VAR_GLOBAL and connections are stage M2-2.
  - org §6.2, org:1377: "The §4.4 checks" are M2-2's.
  - M2-1 has "copy-in/copy-out" (org:1367; PLAN:1299) and a "pure, checked constructor"
    (org:1365). §4.4 says the data constructor "runs the same checks" (org:474-475).

  So M2-1 needs globals, points and connections as data, and some of the checks.
- **C8 Refusing what the text cannot say, before the text.**
  - PLAN:1783-1785 and org:779-780: the data API refuses what the text cannot say.
  - M2-1 lands the data API, "No syntax" (org:1363), before M2-2 defines the text.
- **C9 §4.9's Resume rule against a frozen block's timer.**
  - org:1004 and `edit.ex:84-87`, `edit.ex:692-695`: "Every `ton` stamps `last` at every
    scan, so within the contract a `last` before `now` says F did not run it."
  - PLAN:1349-1350 and decision 8: a frozen instance leaves its timer's `last` alone,
    though the program still runs it.

  §4.9's resume (decision 23) also exists so that a timer whose `ton` an edit removes and
  restores does not catch up the gap. An edit that removes and restores the rung holding
  `cal s1` does the same to `s1`'s timer, which Edit's timer rules, top-level only
  (`edit.ex:407`), never see. Decision 8 wants catch-up across a false EN. Decision 23
  wants a resume across an edit.
- **C10 Edit's and Warnings' walks against per-compile signatures.**
  - `edit.ex:490`, `edit.ex:510` and `warnings.ex:21`, `warnings.ex:61` look every IR
    symbol up in `Compiler.instructions/0` with `Map.fetch!`.
  - org:326-327: user signatures are "built per compile".

  A `cal` absent from `@instructions` raises `KeyError` in both. A `cal` present with a
  fixed signature has its operands dropped by `Enum.zip` (both in §12, probe 2).
- **C11 CLAUDE.md's convention against a nested block list.**
  - CLAUDE.md:134: "The scan is read-only and the same for every instruction of one
    call."
  - A body that needs its own `ons_blocked` view, or its own first bit (Q5.13, Q5.15),
    needs a different scan or another argument. `runtime.ex:479-484` leaves it to M2-5.
- **C12 Editing a block's body.**
  - org:869: "Allowed while running: rungs". org:866-867 refuses only "the members of a
    function block type".
  - If the body lives in `%FbType{}` (Q5.4 a), then `retyped/2` (`edit.ex:357-365`)
    refuses any change to a block's rungs as a type change.
- **C13 `next_due_in/1` against task-less instances.**
  - org:677: `next_due_in(rt)` is "what the runner sleeps on".
  - org:577, org:661: task-less instances run once in every cycle, "The runner paces
    cycles".

  With one task-less instance, something is always due.
- **C14 The first cycle against the overlap rule.**
  - org:556-557: `next_due` is "anchored at start", and "Every periodic task is due in the
    first cycle".
  - org:596: `missed = div(now - next_due, interval)`.

  A first cycle whose `elapsed_ms` is at least an interval reports a spurious overlap
  (Q1.16).
- **C15 Argument order.**
  - org:470: `Logex.Configuration.compile(name, source, types)`, name first.
  - `lib/logex.ex:50-71`: `Logex.compile(source, name: name)`, source first, name a
    keyword.
- **C16 Tuple order.**
  - org:540: `cycle/3` gives `{rt, outputs, events}`.
  - `runtime.ex:65-74` and `runtime.ex:89-93`: `call/4` and `scan/2,3` give
    `{outputs, state}`.
  - `edit.ex:8-12`: `Logex.Edit` gives `{edit, state, report}`.
- **C17 Printers.**
  - PLAN:1783-1785 and org:776-777: "Their saved form is text, `.ld` and `.lcf`, which
    printers write."
  - `printer.ex:1-48`: only a parse AST is printed. There is no printer for `%Program{}`,
    nor for a configuration. A configuration built as data has no saved form.
- **C18 Shape-only names against block names in bodies.**
  - PLAN:951-954, `lib/logex.ex:116-118` and `logex_test.exs:281-284`: a program's name is
    checked for shape only, because "a program type's name is never spelled in a `.ld`
    body". `move.ld` compiles.
  - A block's name *is* spelled in a body (`var s1 seal`), so a block named `move` cannot
    be used.
- **C19 `:local` in FbType.** `fb_type.ex:21-24` says "its vars take a fourth role,
  `:local`", but the `role` type is `:input | :output | :internal` (`fb_type.ex:35`).
  Minor.
- **C20 Who brings the nested migration.**
  - org:866-867: refused "until M2-5 brings the nested migration".
  - PLAN:1491-1493, OE-2: "a function block's members refused … until M2-5".
  - PLAN:1295: M2-5 needs only M1-6 and B5.

  If M2-5 brings the migration, M2-5 changes `Logex.Edit` (OE-1's), which PLAN's scope
  sentence does not say.
- **C21 The trigger's state is not instance state.**
  - `program.ex:41-42`, `initial_env/1`'s doc on instance state, says "M2-6 will add an
    event task's trigger", as do org:1122 and org:879-880.
  - The trigger's last value is resource state, kept per task (org:208, org:559-560), not
    an instance's. The rule needs a home outside `initial_env/1`'s doc.
- **C22 The loader against block files.**
  - org:473: the loader "resolves `motor` to `motor.ld` beside the `.lcf`".
  - The done sentence needs a block inside the program type (PLAN:1369). Where block files
    resolve is unstated (Q2.3, Q5.5).
- **C23 "Records which tags it writes".**
  - org:465-467: "`%Logex.Program{}` records which tags it writes".
  - `program.ex:16`: no such field. The write set is computed privately in
    `edit.ex:489-518`.
- **C24 CLAUDE.md's front-end bullet.**
  - CLAUDE.md:174-177: "every front end … ends in `%Logex.Program{}` data".
  - PLAN:1976: "(and from M2-1 `%Logex.Configuration{}`)". CLAUDE.md is stale for M2.
- **C25 CLAUDE.md's new-state rule.** CLAUDE.md:166-173 gives the rule for a field of
  `%Logex.Instance{}`: a check, a value from `instance/1`, a rule for a scan, `restart/3`
  and a switch. M2's new state is mostly in `%Logex.Runtime{}`: globals, `next_due`,
  overlaps, the trigger. CLAUDE.md has no analogue for a cycle, a configuration restart
  and an OE-2 switch.
- **C26 Unlocated globals as outputs.**
  - org:512-513 and D1.15: inputs are keyed by input point and outputs by output point.
  - org:1251: "A host write, if wanted, is limited to unlocated globals."

  Not a contradiction, but whether an unlocated global ever reaches the host (Q1.11,
  Q1.13) is left open.
- **C27 The ton-in-an-event-task warning.**
  - org:650-652: it "should be an M1-5 warning".
  - It needs the configuration's task of each instance. A program's warnings cannot see
    it, as in C5.
- **C28 "Every wiring, typing or scheduling mistake".**
  - PLAN:1372-1373: the done sentence wants every such mistake as a located diagnostic.
  - Some mistakes are host mistakes, `ArgumentError` (D0.6): an Elixir-built
    configuration, a bad `cycle/3` input. The sentence covers only files on disk, which is
    consistent, but designs should say so.
- **C29 Decision 7 against the implicit configuration.**
  - Decision 7 (org:1471-1472): every var_input connected is an error.
  - org:247-249: in the implicit configuration of a lone `.ld`, the var_inputs are the
    host's image.

  Not a contradiction, but M2-1's one-instance acceptance (D1.2) must satisfy decision 7
  with explicit points (Q1.22).
- **C30 Reserving a block's name in the files that use it.**
  - PLAN:732-734: a user block's name "is not reserved".
  - org:337-338: mnemonic position must never depend on a file's declarations, and a type
    word appears only in type position. Consistent.

  But `Declarations.one/1` and `short/4` (`declarations.ex:250-264`) read a lone word
  after a section as a type when it is a type word. With a library in scope, `var seal`
  becomes "needs a tag name before the type `seal`". That is a behaviour change for a
  program with a tag `seal` declared wrongly. Minor.
- **C31 The decided order against the recommendation here.**
  - Decision 1 (org:1447-1448) adopts M2-1…M2-6, with M2-5 free to move earlier.
  - §11 recommends M2-5 first. That is allowed by decision 1, but it is a change of
    default for the maintainer to confirm.

---

## 9. Unverified, from memory, inferred, absence claims

Each is a claim M2 relies on. None may be repeated as fact.

**From memory**

- **U1** That the conventional continuous task runs at the lowest priority and is
  preempted by periodic and event tasks (org:164, org:1688-1689). It bears on the
  task-less row, D1.14.
- **U2** That a lower priority number is higher in the conventional family. Its two
  documents give "(1...15)" and "0...15" and neither says which end is higher (org:165,
  org:1690). logex's 0-highest is IEC's (org:411).
- **U3** That an unscheduled program does not run in the conventional family
  (org:1691).
- **U4** That the conventional family's logic may `move` into `.pre` and `.acc`
  (org:1326-1327, org:1478, org:1692). It is the basis of decision 9 and bears on Q5.19.
- **U5** What the conventional controller does to outputs on a watchdog fault
  (org:1693). It bears on decision 14, after M2.

**Inferred**

- **U6** That the conventional family has no program type/instance split
  (org:168, org:1695-1696).
- **U7** The timer member mapping `.pre`→PT, `.acc`→ET, `.dn`→Q (org:173, org:1697;
  `fb_type.ex:46-50`).

**Not found in IEC**

- **U8** Any rule for an unconnected program input (org:434-436, org:1699). It is the
  basis of decision 7.
- **U9** That IEC forbids neither two drivers of one global nor two var_external writers
  (org:433). An absence claim.
- **U10** That IEC says nothing about an input image (org:554) and is silent on instance
  order within a task (org:574). Absence claims.
- **U11** That "routine" occurs zero times in either edition (org:116). Absence claims are
  weaker for Ed 3, whose text layer splits words (org:1701-1702).
- **U12** That no general read-only rule for an FB's members was found, beyond the
  VAR_IN_OUT rule (org:1325-1326). An absence claim, and it bears on Q5.19.

**Unread or unverified sources**

- **U13** Ed 4's organisation clauses were not read beyond the publisher preview
  (org:1647-1648). The `cal` stanza's rule-1 claim rests on Ed 2/3 IL, which Ed 4
  removed (org:333-336).
- **U14** Whether Ed 3's Table 68 is row-for-row identical to Ed 2's Table 52, the IL
  operator table that holds CAL (`docs/instruction-sets.md` §10 item 5;
  `docs/instruction-sets.md:273`). It bears on the `cal` stanza's Ed 3 citation.
- **U15** Whether the conventional family's online switch is atomic at a scan boundary;
  whether it can create a task online; and when CODESYS and Siemens switch within a
  cycle (org:809-810, org:1682-1684). Decision 19's "adding or removing a task … until
  its rule is verified" waits on the second.
- **U16** IEC's B.1.7 contradicting itself on whether the resource name is optional in
  `instance_specific_init` (org:481-484). A reading, and it bears on VAR_CONFIG and
  `get/2`'s path form.

**Spike output and missing quotations**

- **U17** The §4.4 configuration diagnostics are spike output only, "pinned by no test"
  and "Not yet measured" (org:449-460, org:1704-1705). The configuration spike's
  t = 0…120 receipt (org:692-709) is also spike output: the spikes "are not in the
  repository … and pin nothing" (org:71-74).
- **U18** IEC's rule on an initial value in a VAR_EXTERNAL declaration. It is not quoted
  in the documents. Unverified, and it bears on Q4.3.
- **U19** That IEC allows VAR_EXTERNAL inside a FUNCTION_BLOCK. It is not quoted in the
  documents. Unverified, and it bears on Q4.9.
- **U20** That IEC's R_TRIG fires on its first execution when CLK is 1. Only the NOTE on
  a cold restart is quoted (org:563-566). The general case is unverified, and it bears on
  Q5.13.
- **U21** That IEC's ST allows assigning an FB instance's input outside a call. It is not
  quoted in the documents. Unverified, and it bears on Q5.19.
- **U22** The MatIEC behaviours cited by symbol: `static R_TRIG` on SINGLE, INTERVAL 0
  emitted as 1, copy-in and copy-out around each call, single configuration, PRIORITY
  parsed and ignored (org:559-569, org:442-444, org:579-582, org:586-587, org:1659-1665).
  They are read from source at the cited commits, not executed. "MatIEC parses PRIORITY
  but ignores it" is not tied to a symbol.
- **U23** OpenPLC v3's cycle and hardware layer at `b5d4135` (org:515-518, org:552-554,
  org:1666-1668). Read, not run.
- **U24** IEC's priority range. No range is quoted (Q3.1).
- **U25** That the conventional family's event task has "a fixed list of hardware and
  software triggers" (org:166). It carries no page citation in the table. Unverified.

**Checked in this pass**

- **U26** "**`.lcf`:** whether the extension clashes with an existing tool" (org:1703;
  decision 3, org:1459). **Checked on 2026-10-02: it does.** `.lcf` is the CodeWarrior
  (NXP) linker command file: "Linker command files must end in .lcf". NXP application
  notes AN4498 (Kinetis) and AN4497 (Qorivva/PX) are titled "CodeWarrior Linker Command
  File (LCF)". Sources:
  - [AN4498](https://www.nxp.com/docs/en/application-note/AN4498.pdf)
  - [AN4497](https://www.nxp.com/docs/en/application-note/AN4497.pdf)
  - [NXP community, ".lcf file"](https://community.nxp.com/t5/Classic-Legacy-CodeWarrior/lcf-file/m-p/173628?profile.language=en)
  - [extension.informer.com/lcf](https://extension.informer.com/lcf/)

  The quotation is from the search engine's summary of these pages; the PDFs were not
  opened in this pass. Whether other tools also use `.lcf` was not checked.

---

## 10. New words, stanzas owed, and what they break

**The naming rule.** Rule 1: if IEC names the operation, take IEC's name, lowercased.
Rule 2: if IEC has only a graphical element, take the clearest vendor mnemonic and say
which. Rule 3: never invent a readable word for a thing with a standard name. Mark what
could not be verified `unverified` (`docs/naming.md:29-48`). Stanzas go at the end of the
file, under `## Stanzas`, which is append-only (`docs/naming.md:50-58`).

| Item | Word | Reserved where | Stanza owed | Notes |
|---|---|---|---|---|
| M2-2 | `program` | `.lcf` | yes | IEC's `PROGRAM … WITH` (org:415) |
| M2-2 | `var_global` | `.lcf` | yes | IEC Table 49 f2 (org:413) |
| M2-2 | `at` | `.lcf` | yes | Must argue the location form `<dev>.i\|q.<k>` and the device-root coinage plainly against rule 3 (org:505-508) |
| M2-2 | `bool`, `dint` | `.lcf` too | stanzas exist (`docs/naming.md:442`, `docs/naming.md:457`) | Reserved in a second file kind; does the stanza note it? |
| M2-3 | `task`, `interval`, `priority`, `with` | `.lcf` | yes, four | Ed 2 Table C.2 lists TASK and WITH but not INTERVAL or PRIORITY (org:756-758) |
| M2-4 | `var_external` | `.ld` (programs and blocks) | yes | Ed 2 Table 16a; a row in `@sections` (D4.6) |
| M2-5 | `function_block` | `.ld` block files (C4) | yes | Not a section word, so `Declarations.keywords/0` will not carry it (Q0.6) |
| M2-5 | `cal` | every `.ld`, as a mnemonic | yes; supersedes the `cal <routine>` row at `docs/naming.md:240`, which stays | Rule-1 claim rests on Ed 2/3 IL (U13, U14); must state the two meanings of rung power (D5.6) |
| M2-6 | `single` | `.lcf` | yes | IEC's SINGLE input (org:93) |
| later | `var_config`, `retain` | `.lcf`, `.ld` | — | Not M2 (org:745; PLAN:742-746) |
| M2-2 | the extension | — | no stanza rule; decision 3 | `.lcf` clashes (U26) |

**Location parts.** `i` and `q` are part of a qualified token, not words, and are not
reserved (org:497, org:753-754).

**What reserving them breaks.** Measured by grep on `47319f7`; receipts in §12.

- **None of the words is a tag anywhere.** `cal`, `var_external`, `function_block`,
  `task`, `interval`, `single`, `priority`, `program`, `with`, `var_global` and `at` occur
  0 times as a quoted name token in `test/fixtures/frontend_golden.txt`. None is used as
  a tag in `lib/` or `test/`. The hits are English in comments and test titles: "ton
  with" in `validation_test.exs:1309` and `validation_test.exs:1527` is a test title.
  `cal`, `var_external` and `function_block` occur 0 times as whole words in `lib/` and
  `test/`.
- **The golden record does not change.** It is front-end only: tokenize and parse, with
  no reservation (`test/fixtures/generate_frontend_golden.exs:16-31`). If `.lcf` reuses
  the existing lexer and parser (Q2.7), no M2 word changes it. Only a `%` lexeme for the
  rejected `at %ix0.0` fallback would.
- **What compiles today and stops.** Every M2 word compiles today as a `.ld` tag
  (probe 1: `var at bool` … `var function_block bool` → `:ok`). Reserving `cal` and
  `var_external` in `.ld` breaks any such program. The words reserved only in `.lcf`
  break no `.ld` program, except a tag that must also be a `var_external` (D4.7).
- **What today's message for `var_external` is.** It is "unknown instruction
  `var_external`", and every later declaration then cascades as "after the first rung"
  (probe 1). No test pins it.
- **Pinned messages that M2 changes:**
  - `test/logex_test.exs:270-279`: the extension rule (C2);
  - `test/logex_test.exs:133-137`: the options of `compile/2`, if a library option is
    added (Q0.7);
  - `validation_test.exs:416`, `:505`, `:661` and `:1105`: "logex has `bool`, `dint` and
    `ton`", if the message lists user types (Q5.8);
  - `validation_test.exs:1125`, `:1134-1152` and `:1740`: "logex has
    Logex.FbType.ton()" (Q5.21);
  - `validation_test.exs:1607`, `:1611`, `:1637` and `:1692`: "only a timer has members"
    (Q5.21);
  - `validation_test.exs:1173` and `:1347`: the "no `ton` runs it" warning, which stays
    for a ton, while a block gets a new `cal` one (D5.11 point 4);
  - `runtime_test.exs:688-735`: the public surface (D0.15);
  - `api_contract_test.exs`'s `@words` and `@refusals` (`api_contract_test.exs:58-59`,
    `:158-169`): reach.
- **The README** says "the section `var`, `var_input` or `var_output`, the type `bool`,
  `dint` or `ton`" (`README.md:27-29`). It changes with M2-4 and M2-5, and gains a
  `cal` row in the instruction table (`README.md:92-105`). Its "Settled, not yet landed"
  bullet for program organisation clears item by item (`README.md:131-140`).

---

## 11. The order of landing

### The decided default

Decision 1 (org:1447-1448) and PLAN:1293-1295 give M2-1, M2-2, M2-3, M2-4, M2-5, M2-6,
"with M2-5 free to move earlier".

### The dependencies, from the documents and the code

- **M2-2 after M2-1.** M2-2's parser feeds M2-1's checked constructor (D7.4).
- **M2-3 after M2-2.** M2-3 adds a line kind to M2-2's file. Tasks exist as data from
  M2-1 (D1.2).
- **M2-4 after M2-2, not M2-3.** It needs `var_global` lines (M2-2) and the runtime's one
  copy (M2-1). Its acceptance, "stops both in the same cycle", works with task-less
  instances, which run in every cycle. So it does not need M2-3.
- **M2-6 after M2-3 and M2-2.** It needs M2-3's `task` line and M2-2's input points.
- **M2-5 depends on none of them** (D5.3). But it changes code OE-1 just landed: Edit's
  walks raise on `cal` (C10), its timer rules take every function block tag for a timer
  (Q5.22), and `ons_blocked` names only top-level bits (Q5.15). It also settles what M2-1
  needs:
  - the nested-state paths `get/2` reads (Q1.19, `m1.s2.run`);
  - which members are readable (`:local`, Q5.18);
  - the nested one-shot rule that D7.3's "one rule for new state" must list.

### Decisions to take before the first item, whichever order is chosen

- **Where a program's file is kept** (Q0.2, fix F15). M2-2's, M2-4's and M2-5's
  diagnostics all need it, and M2-5 meets it first if it leads.
- **The extension** (Q2.1). Decision 3 says before M2-2, and `.lcf` clashes (U26).
- **The namespace of type, instance, global and task names** (Q1.5, Q5.6).
- **How a library of block types reaches the compiler, and the loader's resolution
  rule** (Q5.5, Q2.3). M2-5 and M2-2 must share one rule, or the done sentence's
  configuration with a block inside it gets two.

### Recommendation: M2-5, then M2-1, M2-2, M2-3, M2-4, M2-6

Reasons:

1. **It fixes code while it is fresh.** M2-5 is the only item that changes the `.ld`
   language and `Logex.Edit`. The `KeyError` on `cal` (probe 2), the timer rules applied
   to any function block, and nested one-shot blocking (decision 21 for an added block
   instance) belong to the instance-level edit OE-1 just landed. They are cheapest while
   its tests and the four growth tests are fresh, and before M2-1 builds `start/1` on
   `instance/1`.
2. **It fixes the shape of nested state before M2-1 needs it.** `get/2`'s paths and the
   readable members are M2-1's questions. M2-1's growth test for `get/2` in depth needs
   real depth.
3. **It is self-contained** (D5.3), and its acceptance needs no configuration once
   reworded (Q5.25).

Costs:

- M2-5's acceptance must be reworded to read `s2.run` from one instance, and `m1.s2.run`
  re-asserted in M2-1's acceptance (C1).
- The block loader is designed before M2-2's `.lcf` loader, so both resolution rules must
  be fixed now.
- The scheduler, the milestone's core, waits for the largest language item.

### The alternative: the decided order, M2-1 first

Reasons:

- It is decision 1's default.
- M2-1 has no syntax and the least risk.
- The scheduler is the core of the milestone.

Costs:

- M2-1 must define `get/2` over nested state generically, for any depth of public members,
  before M2-5 says which members are public.
- M2-5 later changes `Logex.Edit`, `Logex.Warnings`, `Logex.Declarations`' messages and
  the evaluator's convention (C11) underneath a landed scheduler.
- It does not fix the Edit hazards of C10 until M2-5. That is acceptable, since no `cal`
  exists before it.

### Within the rest

- **M2-3 before M2-4,** as decided. M2-3 is small; M2-4 has the harder questions (Q4.1,
  Q4.2, Q4.11).
- **M2-4 may go before M2-3** if the one-copy design (Q4.1) is wanted early, since M2-4
  does not need tasks.
- **M2-6 last.** It needs M2-3, and its trigger state rules (Q6.6) depend on Q1.21.

---

## 12. Probe receipts

The scripts are `scratchpad/m2/inv-probe/probe1.exs` and `scratchpad/m2/inv-probe/probe2.exs`.
Each was run with `mix run` in `scratchpad/m2/inv-questions-work`, a copy of `47319f7`, on
Elixir 1.20.4 / OTP 28. Both exited 0.

### Probe 1: today's front end and compiler on M2 sources

- **The §4.4 plant's lines parse.** Every line is a rung of names and integers. The
  located points are single name tokens: `{:name, 4, "panel.i.7"}`. The tie-off is
  `{:int_lit, 9, 0}`.

  ```
  lcf tree well formed: true
  ```
- **Through `Logex.compile/2`, today:**

  ```
  "line 2: unknown instruction `task`", ... "line 4: unknown instruction `var_global`", ...
  "line 7: unknown instruction `program`", "line 8: unknown instruction `m1.start`",
  "line 9: unknown instruction `m2.reset`"
  ```
- **`compile_file/1` on `plant.lcf`** compiles it as a program named `plant`. Its first
  two diagnostics are `…/plant.lcf: line 2: unknown instruction `task``, then line 3 the
  same.
- **The block file of §4.3:**

  ```
  "line 1: unknown instruction `function_block`",
  "line 2: `var_input` after the first rung (line 1): declarations come first", ...
  ```
- **Every M2 word as a `.ld` tag:** `var at bool`, `var with bool`, `var task bool`,
  `var program bool`, `var single bool`, `var priority bool`, `var interval bool`,
  `var var_global bool`, `var var_external bool`, `var cal bool` and
  `var function_block bool`, each used. Result: `:ok`.
- **A tag named like its own program:** `var seal bool` in a program named `seal` gives
  `:ok`.
- **`var s1 seal`:**

  ```
  "line 1: unknown type `seal`: logex has `bool`, `dint` and `ton`", "line 2: `s1` is not declared"
  ```
- **`cal s1 a`:**

  ```
  "line 2: unknown instruction `cal`"
  ```
- **`var_external estop bool` as the first line:**

  ```
  "line 1: unknown instruction `var_external`",
  "line 2: `var` after the first rung (line 1): declarations come first",
  "line 3: `estop` is not declared"
  ```

### Probe 2: Edit's and Warnings' walks on an IR symbol outside `@instructions`

This probe is out of contract on purpose: it hand-edits a program's rungs.

```
Edit.accept with a :cal rung raises: KeyError
Warnings.of with a :cal rung raises: KeyError
zip of a 1-slot signature with 3 operands: [{{:instance, :any}, {:name, 3, "s1"}}]
```
