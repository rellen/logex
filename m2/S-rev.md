# S-rev — M2-1, the scheduler from Elixir data: the merged design, revised

Label: S-rev. Track S, `PLAN.md` M2-1. This revises S-synth (`scratchpad/m2/S-synth.md`)
against the confirmed findings of the refutation pass. Written 2026-10-02 against
`/home/user/logex` at `47319f7`, which was not modified (`git -C /home/user/logex status
--short` is empty). The spike was revised in a copy of S-synth's, `scratchpad/m2/S-rev-work`.
Its diff against `47319f7` is `scratchpad/m2/S-rev.patch`. The mutation driver and its log
are `scratchpad/m2/S-rev-mutation.py` and `scratchpad/m2/S-rev-mutation.jsonl`. The
landing order is built as commits in `scratchpad/m2/S-rev-series` (branch `s-rev`, by
`S-rev-probe/series.py`). Every other probe and receipt is in `scratchpad/m2/S-rev-probe/`.
Every `mix` run was on Elixir 1.20.4 / OTP 28 (the scratchpad toolchain), and each is
judged by its exit code.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, both at `47319f7`.
A bare `file:line` is the repository at `47319f7`. `spike:file` is the file in
`S-rev-work`, cited by function name where line numbers would move. `S-synth.md`,
`F-synth.md`, `T-synth.md`, `inventory.md`, `readiness.md`, `research.md` and the
refuters' files (`rf-S-correct.md`, `rf-S-fit.md`, `rf-X-consistency.md`) are the pass's
own documents in `scratchpad/m2/`. Finding ids (`rf-S-correct-F1`, `S-FIT-3`, `X13` and so
on) are the refutation pass's. Rule labels (`CF-n`, `NW-n`, `RT-n`, `CY-n`, `EV-n`, `IN-n`,
`NX-n`, `GT-n`, `RS-n`, `PD-n`, `ST-n`, `GR-n`, `LO-n`, `BT-n`, `IR-n`) and question
labels (`Q-n`) belong to this document. Like the inventory's labels, they must never be
cited in `lib/`, `test/` or `CLAUDE.md`, which `test/logex/edit_test.exs` enforces. The
spike cites none. "Unverified" marks what was not checked. The conventional vendor and
its products are not named; other vendors are cited by `research.md`'s labels.

---

## Changed in revision

Each confirmed finding against track S, and each cross-track finding with an S side, and
what was done about it. "Red" means the mutant that reverts the fix alone fails the full
suite (§7.2). Every such row was rerun on the final spike.

### Fixed in code, each with a test that fails when the fix alone is reverted

- **rf-S-correct-F1** (GR-2's wrong variable). GR-2 now reads "linear in the tasks
  declared", and a new test measures that variable: scheduler_test.exs, "a cycle that runs
  one task, and next_due_in/1, stay linear in the tasks declared". It uses one 1 ms task
  and n tasks that are never due again. Two new rows: **GR-2b**, a per-task walk in
  `due/1`, and **GR-5**, a per-task walk in `next_due_in/1`. Both are red. The old GR-2
  row, where every task is due, stays. The receipt below reproduces the finding's numbers
  exactly (`S-rev-probe/sizes.out`). No queue was built, since nothing decided asks for one
  (§12).
- **rf-S-correct-F2** (refusal messages quadratic in size). A refusal now lists the names a
  key could have been once, on the first line that needs them. This applies in
  `cycle/3`, `check/1` (so `new!/1` and `start/1` too) and, for the same rule in one
  module, in the landed `put_inputs/3` and `call/4` (§11 D-5). In `check/1` each list is
  keyed apart: the programs, the tasks, the program instances, the globals, and each
  program type's members. Tests:
  - configuration_test.exs, "lists of names: each list is given once, by the first
    diagnostic in line order", and "growth: a refusal stays linear in its size";
  - runtime_test.exs, "a refusal lists the input points once" and "a refusal of many keys
    grows linearly in its size";
  - runtime_test.exs's landed "key order holds past 32 inputs" test, rewritten to the new
    form.

  Rows **LO-1**, **LO-2** and **LO-3** are red. The time cost is still quadratic in bad
  keys times names, because `Declarations.suggest/4` runs Jaro against every name for
  each key. That cost is not the listing's, so it is put to the maintainer as **Q-31**.
- **rf-S-correct-F3** (names told nothing). An input key that names a program instance
  whole, a task, or the configuration is now told which it is. So is a `get/2` path that
  names a task or the configuration. The kinds are checked before the configuration's
  name, which a task may share (the verdict's correction). Tests: runtime_test.exs, "a
  name that is no input point and no global" (two tests). The contract walk also gains
  three refusal kinds, `:instance_key`, `:task` and `:configuration`, whose reach it
  asserts. Rows **IN-1d**, **IN-1e**, **IN-1f**, **IN-1g** (task before configuration) and
  **GT-8** are red.
- **X13** (a block type given as a program; S's cascade). `new!/1` keeps a
  `%Logex.FbType{}` under its name, and `check/1` refuses it with its own message, once.
  An instance that names it is no longer refused a second time as naming no program.
  Test: configuration_test.exs, "a function block type is not a program, and is refused
  once", through both `new!/1` and `check/1`. Rows **BT-1** and **BT-2** are red. Sharing
  F's wording across every entry point is a cross-track item (§13 Q-39).
- **S-FIT-1** (no home for the new-state rule of globals and tasks). The rule for a global
  is now the public, documented `Logex.Configuration.initial/1`. Its doc lists the edit's
  exceptions, as `Program.initial_env/1`'s does. `start/1` and `restart/2` use it, and
  OE-2's edit is to use it. `Logex.Runtime`'s moduledoc gains "One rule for each piece of
  a resource's state": the clock, a global, an instance and a task, each with its edit
  column. A task needs no public function, since no edit adds one while running
  (decision 19). Commit 1's documents now copy §4's table into org §4.9's "One rule for
  new state" (§9). Tests:
  - two `initial/1` doctests;
  - configuration_test.exs, "initial/1 takes a global whose initial value is an integer or
    nil";
  - scheduler_test.exs, "starts every global by the one rule" and "puts every global but
    an input point back by the one rule";
  - the surface pin, which now has `initial: 1`.

  Rows **IR-1** and **IR-2** are red, and making `initial/1` private does not compile,
  since `Logex.Runtime` calls it.
- **S-FIT-3** (the landing order never built). The order is rebuilt and actually built as
  five commits on `47319f7` (§8). Old commits 3 and 4 are merged into one, "the resource,
  with periodic tasks", so no task-less interim rule exists. `restart/2` is its own commit
  4. The tests were split so that each commit carries only what it can run:
  - configuration_test.exs's `start/1` parts move into a describe, "start/1 checks again",
    which lands in commit 3;
  - the plain-data, initial-rule and "every call takes a runtime" tests lose their
    `restart/2` lines to commit 4's tests.

  Every commit passes the gate (§6). Each commit's mutation rows were rerun in that
  commit's own tree (§7.3). Q-3's "dropped whole" claim is withdrawn and restated with
  what dropping commit 4 costs commits 5 and 6.

### Fixed in the design (documents only: no code changes, so no test)

- **S-FIT-2.** The moduledoc now says what §5 claimed it said. Until OE-2, an instance
  inside a resource is not edited: `Logex.Edit` takes a lone instance, and the resource
  holds its own instances. §13 **Q-32** asks the maintainer to accept and document the
  gap. It was not an equal "interim hook" option (the verdict's correction).
- **S-FIT-4, X7.** Q-23 now has T's option, `min(next_due, now + new interval)`. It states
  the keep option's worst-case delay, which is up to the whole old interval (the
  verdict's 60000 ms to 10 ms probe ran nothing in 1000 ms). It is now one cross-track
  question, stating what each track recommends. S now recommends the `min` option, for the
  reason T gives: it bounds the wait by the new interval and adds no run.
- **S-FIT-5.** Q-8 now argues explicitly why a priority's bound is the exception to
  decision 7's reasoning, and it names no vendor (the verdict's side note). The
  recommendation stays (a), in agreement with T Q-9 (X19).
- **S-FIT-7.** D-1 records that M2-1 pins the §4.4 diagnostics from data, a departure from
  org §6.2's "from source". §5's M2-2 item owes each `check/1` diagnostic asserted again,
  as a whole list, from configuration-file source.
- **S-FIT-8.** GT-4b and GT-7 leave M2-1. They were pinned only on a `%Logex.Program{}`
  edited by hand, which fix F12 rules out for tests, and no input within the contract
  reaches them: `ton` is the only block type, and it has outputs. The clauses and the
  hand-edited test are gone. `get/2` of a whole block names its first output member, and
  a hand-built type with none is outside the contract. §5's M2-5 item owes both rules
  from source, if its types can lack an output or a public member (FS-Q9).
- **S-FIT-9.** The instance-type rule and the changed-`initial` report in §4's table are
  now §13 **Q-33** and **Q-34**, for OE-2.
- **S-FIT-10.** Inventory Q1.21 is answered in the moduledoc: `restart/2` restarts the
  whole resource, and there is no restart of one instance inside it. It is also asked as
  **Q-35**. Q1.26, a struct in its API module as `Logex.Edit`'s is, is recorded with its
  alternative under Q-35.
- **S-FIT-11.** Commit 0 is now named as a `%Logex.Program{}` change, it has a §9 row, and
  its consistency rule with `tags` is stated (§8). Whether to keep the list out of the
  public struct instead is **Q-36**.
- **S-FIT-12, X14.** Decision numbers are allocated once, in one design-record commit for
  all three tracks, before any M2 code cites one (§8 commit 1). Q-22 and F's FS-Q16 are
  one question (X5). So are Q-24 and T's Q-19. GT-1 and §5 no longer promise "any depth"
  (X16).
- **X2.** Neither design said that the surface pin of `Logex.Configuration` must be
  rewritten once when T's checks merge, and §8 now says so. The validator's error mode for
  a host mistake in a configuration's name or programs is now part of **Q-37**.
  Currently S returns it as a diagnostic, while T raises.
- **X5.** Q-22 is restated. M2-1 first, then M2-5 before M2-2, is the order that keeps the
  decided Done-when text unchanged. It is not the only order consistent with all three
  tracks.
- **X6.** M2-5's Done-when test, `get(rt, "m1.s2.run")`, belongs to whichever item lands
  second. With M2-1 first, that is M2-5 (§5).
- **X9.** S Q-20 and T Q-21 are now one question, Q-20. It covers the line rule, the
  shared message, and whether a bad line in `check/1` is a diagnostic or an
  `ArgumentError`.
- **X10.** The message words and the granularity of an unconnected var_input are part of
  Q-37. S currently gives one diagnostic per member, T one per instance.
- **X11.** §5's M2-2 item no longer asserts a reading route. It is T's Q-2, which
  recommends a recursive descent over the tokens.
- **X12.** §1.1 and §12 now say that M2-2 is the first to fill `warnings` (W1, W2), then
  M2-3 (W3), M2-4 (W4, W5) and M2-6 (W6), following T's plan. The field still lands
  empty in M2-1.
- **X15.** Nothing to do on S's side. T's `diagnostic.ex` takes S's attribution.
- **X16.** GT-1 describes the walk, not a reachable depth. M2-5's depth-growth test is
  owed only under FS-Q9(b).
- **X18.** F15 goes to the first item that meets it. Under §13 Q-22's order that is M2-5.
  §5 states both citation conventions (F's R68 and T's R51).
- **X19.** The agreements are recorded in §13's cross-track table, with the three
  refinements: priority, an event task's `interval`, and the namespace's words.
- **X1, X3, X4, X20** are F and T seams with no S side. They are not repeated here.

---

## 0. Summary

- **Base: S-synth,** itself S2 with grafts from S1, S3 and the two judges. This revision
  changes only what the confirmed findings require.
- **Code changes:**
  - a name is told what it is (F3);
  - a refusal lists names once (F2);
  - a block type is refused once (X13);
  - the one rule for a global is public, and the moduledoc gains a one-rule section (S-FIT-1);
  - GT-4b and GT-7 are dropped to M2-5 (S-FIT-8);
  - a growth test with one task due among many (F1);
  - the tests were split so that each commit is green (S-FIT-3).
- **Gate:** three passes, 514 tests including 8 doctests, up from S-synth's 500 and
  `47319f7`'s 430 (§6).
- **Landing order built:** five commits on `47319f7`, each green under the full gate
  (§6, §8).
- **Mutation table:** 113 rules, each reverted alone (§7.2). Each commit's rows were also
  rerun in that commit's tree (§7.3).
- **§13** now holds 39 questions. Nine are new (Q-31…Q-39), and the ones another track shares are
  merged into one question each, with what each track would do.

---

## 1. The API and the data shapes

### 1.1 `Logex.Configuration` (`spike:lib/logex/configuration.ex`)

```elixir
%Logex.Configuration{
  name:        String.t(),                              # required (CF-30)
  file:        String.t() | nil,                        # set by M2-2's reader; nil from Elixir (CF-31)
  programs:    %{String.t() => %Logex.Program{}},       # the program types, by name
  tasks:       [%Logex.Configuration.Task{}],           # declaration order
  globals:     [%Logex.Configuration.Global{}],         # declaration order
  instances:   [%Logex.Configuration.Instance{}],       # declaration order = order within a task
  connections: [%Logex.Configuration.Connection{}],     # declaration order
  warnings:    [%Logex.Diagnostic{severity: :warning}]  # empty in M2-1; M2-2 first fills it (W1, W2), then M2-3, M2-4, M2-6
}

%Logex.Configuration.Task{name:, interval: pos_integer, priority: non_neg_integer, line: nil | pos_integer}
%Logex.Configuration.Global{name:, type: :bool | :dint, initial: nil | non_neg_integer, at: nil | String.t(), line:}
%Logex.Configuration.Instance{name:, type: program_name, task: nil | task_name, line:}
%Logex.Configuration.Connection{instance:, member:, to: global_name | non_neg_integer, line:}

Logex.Configuration.new!(keyword)  :: %Logex.Configuration{}         # ArgumentError: every problem, a line each
Logex.Configuration.check(config)  :: [%Logex.Diagnostic{stage: :configure}]
Logex.Configuration.location(at)   :: {:ok, {device, "i" | "q", [non_neg_integer]}} | :error
Logex.Configuration.initial(global) :: integer                       # the one rule for a new global (IR-1)
```

- `new!/1` takes `name:`, `programs:` (a **list** of `%Logex.Program{}`, keyed by each
  program's name), `tasks:`, `globals:`, `instances:` and `connections:`.
  - An element from Elixir has no `line` (NW-3).
  - A `%Logex.FbType{}` among the programs is kept under its name, for `check/1` to refuse
    once (BT-1).
  - It raises one `ArgumentError` whose message lists its own problems first, then
    `check/1`'s errors, one per line, each formatted by `Logex.Diagnostic.format/1`.
- `check/1` is the one validator, total over any value in any field.
  - It returns diagnostics at stage `:configure`, at the element's line in the
    configuration's file, in line order, with any problem that has no line last.
  - Each list of names a diagnostic would end with appears once, in the first diagnostic
    in line order that needs it (LO-2, LO-3).
  - M2-2's reader builds the same structs, with lines and a file, and calls it. Nothing
    reshapes.
- `location/1` is public because the wall-clock runner routes points by device and address
  (org §4.5, org:514-516).
- `initial/1` is a global's value before anything sets it: its `initial`, or 0. It is the
  one rule for a new global, as `Logex.Program.initial_env/1` is for a tag. Its doc
  lists the edit's exceptions (§4). Anything but a `%Global{}` whose initial value is an
  integer or nil raises `ArgumentError` (IR-2).
- A connection carries no direction (decision 5): the member's section gives it.

### 1.2 `Logex.Runtime` (`spike:lib/logex/runtime.ex`)

```elixir
%Logex.Runtime{}   # @opaque: config, now, globals, instances, tasks, wiring

Logex.Runtime.start(config)                      :: %Logex.Runtime{}
Logex.Runtime.cycle(rt, elapsed_ms, inputs)      :: {rt, outputs, events}
Logex.Runtime.next_due_in(rt)                    :: non_neg_integer | :infinity
Logex.Runtime.get(rt, path)                      :: integer
Logex.Runtime.overlaps(rt)                       :: %{task_name => non_neg_integer}
Logex.Runtime.restart(rt, :cold | :warm)         :: %Logex.Runtime{}

outputs :: %{output_point_name => integer}            # every output point, every cycle
events  :: [{:ran, task_name | :none, instance_name, now} | {:overlap, task_name, missed}]
```

- `instance/1`, `call/4`, `put_inputs/3`, `scan/2,3` and `restart/3` keep their contract.
  One message changes: a refusal of several undeclared keys lists the var_inputs once (§11
  D-5).
- A scan inside a cycle is `call/4` with the instance's copy-in, then its copy-out.
  `start/1` builds every instance with `instance/1` (fix F14), and `restart/2` restarts
  each instance with `restart/3`.
- `start/1`, `cycle/3`, `next_due_in/1` and `get/2` are org §4.6's decided signatures
  (org:675-678). `overlaps/1` and `restart/2` are two additions (§11 D-2).
- The struct is defined in its API module, as `%Logex.Edit{}` is (§13 Q-35). Its fields:
  - `config`, the configuration;
  - `now`;
  - `globals`, one value per global; the input points' values are the input image;
  - `instances`, each `%Logex.Instance{}` by name;
  - `tasks`, `%{next_due:, overlaps:}` by task name;
  - `wiring`, what `start/1` derives once from the configuration. It is not state.
- The moduledoc now has a "One rule for each piece of a resource's state" section. It also
  states that an instance inside a resource is not edited until OE-2, and that there is no
  restart of one instance inside a resource.

### 1.3 `Logex.Diagnostic`

`@type stage` gains `:configure` (`spike:lib/logex/diagnostic.ex`). The moduledoc says
`line` is nil for a `:configure` problem of an element built from Elixir, or of the
configuration as a whole. T's spike attributes the stage to M2-2. Its merge takes this
attribution (X15).

### 1.4 The host's loop (the `Logex.Runtime` moduledoc)

A runner does four things in each loop:

1. It sleeps `next_due_in/1` ms, or less when it paces task-less instances or watches for
   an input change.
2. It reads its devices into an input map.
3. It calls `cycle/3` with the time that really passed.
4. It writes the outputs back.

What it may rely on, each pinned (§7):

- the first cycle runs at once;
- a late task is reported, never replayed;
- inputs are a delta;
- outputs are a snapshot;
- events are a log and an open set;
- a cycle is a function of its arguments, so a recorded run replays exactly;
- a host mistake raises `ArgumentError`, and nothing else escapes.

---

## 2. The rules, numbered

Every rule below is built in the spike and has a mutant in §7.2 unless the row says
otherwise. Rules new in this revision are marked *(rev)*.

### 2.1 Building from Elixir (`new!/1`)

- **NW-1** `new!/1` takes a proper keyword list with atom keys. Anything else raises the
  "takes a keyword list" message alone, since nothing can be built.
- **NW-2** No field is unknown, and none is given twice.
- **NW-3** An element from Elixir has no `line`. A line is where a configuration file
  declares the element, and every message that cites one relies on that, just as
  `Logex.Declarations.validate!/1` refuses a line on a tag from Elixir
  (`lib/logex/declarations.ex:125-134`).
- **NW-4** The element is checked without the line it brought: one mistake, one message.
- **CF-3c** `programs:` is a list of programs, each name once.
- **CF-3d** An unnamed program is refused as unnamed, because an instance names its
  program.
- **BT-1** *(rev)* A function block type in `programs:` is kept under its name. `check/1`
  then refuses it once (BT-2), and an instance that names it is not refused again as
  naming no program.

### 2.2 The configuration (`check/1`, the one validator)

- **CF-1** Every name of a task, global or program instance, and the configuration's own,
  is a name (`Declarations.name?/1`).
- **CF-2** Tasks, globals and program instances share one namespace.
  - **CF-2b** The first to take a name **in line order** keeps it. In a file, the later
    line is refused, citing the earlier one's line, whatever part each is in.
  - **CF-2c** A name differing only in case is refused, as for tags.
  - A program type is named in type position only, so `program motor motor` is not a
    clash.
  - The configuration's own name is outside the namespace, so a task may share it (IN-1g).
- **CF-3a** A program is under its own name. **CF-3b** A program's name is a name.
- **BT-2** *(rev)* A function block type under a program's name is refused as such:
  "a function block type, which runs inside a program".
- **CF-4** A line is a positive integer or nil (§13 Q-20).
- **CF-4b** Each part is a proper list of its element struct. An improper tail is refused
  like any non-list (fix F8's rule for a host's lists, org:1608-1609).
- **CF-5** A task's interval is 1 to 2147483647 ms. **CF-6** Its priority runs from 0, the
  highest, to 2147483647 (§13 Q-8).
- **CF-7** A global is `:bool` or `:dint`. **CF-8** Its initial value fits its type.
  **CF-9** It is not negative.
- **CF-10a** An input point takes no initial value. **CF-10b** Nor does an output point.
- **CF-11** A location is `<device>.i.<address>` or `<device>.q.<address>`, one token to
  the lexer, the device a name. **CF-11b** Its address is one or more whole numbers, with
  no leading zero.
- **CF-12** One address holds one global.
- **CF-13** A program instance's type is a program of the configuration, with a
  did-you-mean or the list. **CF-14** Its task, if it has one, is a task of the
  configuration.
- **CF-15** A connection names a declared program instance. A connection whose instance
  is declared but cannot run is not checked again.
- **CF-16** It names a member its program declares; a dotted member "goes too deep".
  **CF-17** That member is a var_input or a var_output.
- **CF-18** A var_input is connected once: **CF-19** to a global of its type, or **CF-20**
  to a constant that fits it.
- **CF-21** A connection's instance and member are names. Its `to` is a name or an integer
  of 0 or more.
- A var_output drives a global: **CF-22** never a constant, **CF-23** never an input point,
  and **CF-24** only one of its type. **CF-25** At most one connection drives a global.
- **CF-26** Every var_input is connected (decision 7). Each missing one is cited at its
  instance's line, one diagnostic per member (§13 Q-37).
- **CF-27** A configuration runs at least one program instance.
- **CF-28a** Diagnostics are in line order, those with no line last. **CF-28b** Each is
  stamped with the configuration's `file`. **CF-28c** Each is at stage `:configure`.
- **CF-29a** A junk instance name is never offered as a did-you-mean. **CF-29b/c** A
  connection to a global whose type CF-7 refused is not checked again, input or output.
- **CF-30** A configuration has a name. **CF-31** A configuration's `file` is a string or
  nil.
- **LO-2** *(rev)* Each list of names (the programs, the tasks, the program instances, the
  globals, a program type's var_inputs and var_outputs) is given once, by the first
  diagnostic in line order that needs it. **LO-3** *(rev)* Each list is keyed apart, so the
  first of each kind is listed.
- **IR-1** *(rev)* `initial/1` is a global's `initial`, or 0 without one. **IR-2** *(rev)*
  Anything else raises `ArgumentError`.

### 2.3 Starting (`start/1`)

- **RT-1** `start/1` takes a `%Logex.Configuration{}` and runs `check/1` again. Any error
  raises one `ArgumentError`, with every problem formatted, a line each. Decision 28's full
  entry check is the precedent (org:1559-1572).
- **RT-2** Each instance is built with `Runtime.instance/1` (fix F14).
- **RT-3** `now` is 0. Every global is at `Configuration.initial/1`. Every task is due at 0
  ("anchored at start", org:556), with an overlap count of 0.

### 2.4 A cycle (`cycle/3`), in order (org:546-583)

- **CY-0** The checks run in order: the runtime, then `elapsed_ms`, then the inputs.
- **CY-1** `now` advances by `elapsed_ms`, a non-negative integer.
- **IN-1a** `inputs` is a map keyed by input-point name. An output point or an unlocated
  global is refused as such.
  - **IN-1b** A path into an instance is refused as one.
  - **IN-1c** A key that is not a string is refused as one.
  - **IN-1d** *(rev)* A key that names a program instance whole is told it is one.
  - **IN-1e** *(rev)* A key that names a task is told it is one.
  - **IN-1f** *(rev)* A key that names the configuration is told it is the configuration's
    name.
  - **IN-1g** *(rev)* A task's kind is checked before the configuration's name, which a
    task may share.
  - Any other unknown name gets a did-you-mean or the list.
- **IN-2** Each value fits its point's type exactly, with `call/4`'s messages.
- **IN-3** Every input problem comes in one raise, a line each, in key order. A refused
  cycle changes nothing.
- **LO-1** *(rev)* A refusal of `cycle/3`, `put_inputs/3` or `call/4` lists its names
  once, on the first line that needs them.
- **CY-2** The inputs merge into the input points, which keep their values between cycles.
- **CY-3** A periodic task is due when `next_due <= now`.
- **CY-4** Due tasks run by priority, the lower number first (**a**). Ties go to the
  earlier `next_due` (**b**), then to declaration order (**c**: mutant reversed; **d**:
  mutant by name).
- **CY-5** A task that runs moves `next_due` to `next_due + (missed + 1) * interval`,
  where `missed = div(now - next_due, interval)`.
- **CY-6** When `missed > 0`, the cycle emits `{:overlap, task, missed}` (**a**) and adds
  `missed` to the task's count (**b**).
- **CY-7** Task-less instances run after every due task (**a**), once in every cycle,
  including an elapsed-0 one (**b**). A task's instances run in declaration order (**c**,
  **d**), and so do the task-less ones (**e**, **f**).
- **CY-8** A scan copies each connected var_input in from a constant (**a**) or from its
  global's current value (**b**). It then runs `call/4`, and copies each connected
  var_output out to its global at once (**c**).
- **CY-9** The outputs are every output point after every scan.
- **CY-10** A task with no instance is still scheduled, counted and reported. (No mutant.)
- **EV-1** Each scan emits one `{:ran, task, instance, now}`. **EV-2** Each
  `{:overlap, …}` comes just before its task's scans. **EV-3** The kinds are an open set.
  (A promise, not code: no mutant.)

### 2.5 Reading

- **NX-1** `next_due_in/1` is the soonest `next_due` minus `now` (**b**), or `:infinity`
  when there is no task (**a**).
- **NX-2** `overlaps/1` gives each task's overlap count, by name.
- **GT-1** `get/2` reads a global, an instance's declared tag (a `var` included), or a
  public member of a function block instance, through `FbType.member/2`, so never an
  internal member.
  - The walk follows a member whose type is a block as deep as the types go.
  - Which members are public, and so how deep a path can reach, is `FbType.public/1`'s
    to decide.
  - Under F's FS-Q9(a) no reachable path is deeper than `inst.tag.member` (X16). At
    `47319f7` no path is: `ton` is the only block type.
- **GT-2** An instance named whole is refused. **GT-3** A path past a bool or a dint is
  refused. **GT-5** A path is one name token to the lexer.
- **GT-4** A block instance named whole is refused, with its first output member as the
  example (**a**). *(rev: GT-4b, the fallback to any public member or none, left for
  M2-5; §5.)*
- **GT-6** An instance of a program with no tag is refused with a message saying it
  declares none.
- **GT-8** *(rev)* A path whose head names a task, or the configuration, is told which it
  is.

### 2.6 Restarting (`restart/2`)

- **RS-0** The runtime is checked first, then the mode. **RS-1** Every overlap count goes
  to 0. **RS-2** Every task is due at the next cycle.
- **RS-3** The input image is kept. **RS-4** Each instance restarts through `restart/3`.
- **RS-5** Every other global goes back to `Configuration.initial/1`. **RS-6** The clock
  is kept.

### 2.7 The value itself

- **PD-1** A `%Logex.Runtime{}` holds plain data only, at start, after cycles and after a
  restart.
- **ST-1** Every call checks its runtime first. **ST-2** Every call is a function of its
  arguments. (No mutants; §7.4.)
- **GR-1** A cycle is linear in the instances it runs, measured at 16x.
- **GR-2** A cycle is linear in the tasks due, when every task is due, at 4x. **GR-2b**
  *(rev)* A cycle that runs one task is linear in the tasks declared, at 4x. **GR-5**
  *(rev)* So is `next_due_in/1`. A cycle and `next_due_in/1` cost every declared task,
  whatever runs (rf-S-correct-F1).
- **GR-3** `check/1`, and so `new!/1` and `start/1`, is linear in the configuration, at
  4x. **GR-4** `start/1`'s own part is linear, at 4x.
- **GR-6** *(rev)* A refusal's size is linear in its problems: n wrong keys or connections
  against n names make a message 4.1x the size for 4x (`S-rev-probe/sizes.out`). Pinned by
  LO-1 and LO-2's mutants, which fail the two size tests. The time is not linear (§12,
  §13 Q-31).

---

## 3. Every message, exact

`<x>` is a value: a name in backticks when it is a string, else `inspect`ed. `<where>` is
` (line N)` for an element with a line, else empty. `<list>` is ": the <noun> are `a`,
`b` and `c`". After the first refusal that needs a given list, it is left off (LO-1,
LO-2).

### 3.1 `new!/1`'s own (raised; one line each, before `check/1`'s)

```
Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:, globals:, instances: and connections:, got: <inspect>
:<key> is not a field of a configuration: its fields are name:, programs:, tasks:, globals:, instances: and connections:
<key>: is given twice
programs: is a list of %Logex.Program{}, as in programs: [motor], got the one program `<name>`
programs: must be a list of %Logex.Program{} from Logex.compile/2, got: <inspect>
programs: <inspect> is not a %Logex.Program{} from Logex.compile/2
a program in a configuration needs a name, as Logex.compile/2 gives it: an instance names its program by it
two programs are named `<name>`: a configuration has one of each
task `<n>` from Elixir has no line, got: <inspect>                     (also: global `<n>`, program instance `<n>`, the connection of `<i>.<m>`)
```

### 3.2 `check/1`'s diagnostics (stage `:configure`)

Each is as in S-synth §3.2, with these changes:

```
the program under `<key>` is `<name>`, a function block type, which runs inside a program: a program instance is of a %Logex.Program{}     (rev, BT-2)
program instance `<n>`: there is no program `<t>`<hint>      hint: " — did you mean `x`?" | <list> the first time | "" after | ": this configuration has no program"
program instance `<n>`: there is no task `<t>`<hint>         (likewise, "the tasks are")
`<i>.<m>`: there is no program instance `<i>`<hint>         (likewise, "the program instances are")
`<i>` is a `<type>`, which declares no `<m>`<hint>          (likewise, "its var_inputs and var_outputs are", once per program type)
`<i>.<m>` is connected to `<g>`, which is not a global<hint> (likewise, "the globals are")
```

The other messages are unchanged:

```
a configuration's file is a file name, or nil for one built from Elixir, got: <inspect>
a configuration needs a name, as in name: "plant"
<inspect> cannot name a configuration: a name is a letter or `_`, then letters, digits or `_`
<inspect> cannot name a program: a name is a letter or `_`, then letters, digits or `_`
the program under `<key>` is named `<name>`
the program under `<key>` is not a %Logex.Program{} from Logex.compile/2, got: <inspect>
programs must be a map of program names to %Logex.Program{}, got a list: Logex.Configuration.new!/1 takes a list and keys it by name
programs must be a map of program names to %Logex.Program{}, got: <inspect>
<field> must be a list of %Logex.Configuration.<Struct>{}, got: <inspect>
a task is a %Logex.Configuration.Task{}, got: <inspect>                 (also: a global, an instance, a connection)
task `<n>` has line <inspect>: a line is a positive integer, or nil for one built from Elixir
<inspect> cannot name a task: a name is a letter or `_`, then letters, digits or `_`
`<n>` is already the name of a <kind><where>: tasks, globals and program instances share one namespace
`<n>` and the <kind> `<first>`<where> differ only in case: names are case-sensitive, so these would be two names
task `<n>`: an interval is 1 to 2147483647 ms, found <inspect>
task `<n>`: a priority is 0, the highest, to 2147483647, found <inspect>
global `<n>` has type <inspect>: a global is :bool or :dint
global `<n>` is a bool: its initial value must be 0 or 1, found `<v>`
global `<n>` is a dint: `<v>` does not fit in 32 bits
global `<n>` is a dint: its initial value `<v>` is negative, which no line can say until a negative literal lexes
the initial value of global `<n>` must be an integer, found <inspect>
global `<n>` is an input point: its value comes from outside, so it takes no initial value
global `<n>` is an output point: it starts at 0 and takes its value from the instance that drives it, so it takes no initial value
global `<n>` is at <x>, which is not a location: a location is a device, `i` for an input or `q` for an output, then an address, as in `panel.i.0` or `panel.q.3`
global `<n>` is at `<at>`, the address of global `<first>`<where>: one address holds one global
program instance `<n>`: its type is a program's name, found <inspect>
program instance `<n>`: its task is a task's name, or nil for none, found <inspect>
`<i>.<m>` goes too deep: a connection names a var_input or var_output of a program instance, as in `<i>.start`
`<i>.<m>` is internal to `<type>` (declared `<section>`): only a var_input or var_output connects
a connection's instance and member are names, as in `m1.start`, found <inspect> and <inspect>
`<i>.<m>` is already connected, to <`g` | constant><where>: a var_input is connected once
`<i>.<m>` is a <type>, but `<g>` is a <type><where>
`<i>.<m>` is a bool: only 0 or 1 fit, found `<v>`
`<i>.<m>` is a dint: `<v>` does not fit in 32 bits
`<i>.<m>` is connected to <inspect>: a connection's other end is a global, by name, or a constant of 0 or more
`<i>.<m>` is a var_output: it drives a global, and a constant cannot be driven
`<g>` is an input point<where>: `<i>.<m>` cannot drive it
`<g>` is already driven by `<i>.<m>`<where>: one connection drives a global
`<i>.<m>` is not connected: every var_input is connected, to a global or a constant
a configuration runs at least one program instance
expected a %Logex.Configuration{}, got: <inspect>              (raised by check/1 itself)
expected a %Logex.Configuration.Global{} whose initial value is an integer or nil, got: <inspect>     (raised by initial/1; rev)
```

S keeps four of the seven messages of the configuration spike word for word (org:452-460),
except for the trailing rule. T keeps three and rewords four. Which words land is §13 Q-37.

### 3.3 `Logex.Runtime`'s host mistakes (raised; pinned in `runtime_test.exs`)

```
expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: <inspect>          start/1
<check/1's errors, formatted, one per line>                                                 start/1
expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: <inspect>                      cycle/3, next_due_in/1, overlaps/1, get/2, restart/2
restart takes :cold or :warm, got: <inspect>                                                restart/2 (restart/3's message)
elapsed_ms must be a non-negative integer of milliseconds, got: <inspect>                   cycle/3 (scan/3's message)
inputs must be a map of input-point names to values, as in %{"pb_start_1" => 1}, got: <inspect>
input <inspect> is not a point name: inputs are keyed by input-point name, as a string, as in %{"pb_start_1" => 1}
input `<k>` is an output point (at `<at>`), not an input point: only an input point is set from outside
input `<k>` is a global with no location, not an input point: only an input point is set from outside
input `<k>` reaches into the program instance `<i>`: only an input point is set from outside
input `<k>` is a program instance, a `<type>`, not an input point: only an input point is set from outside     (rev, IN-1d)
input `<k>` is a task, not an input point: only an input point is set from outside                             (rev, IN-1e)
input `<k>` is the configuration's name, not an input point: only an input point is set from outside           (rev, IN-1f)
input `<k>` is not an input point<hint>       (" — did you mean `x`?" | ": the input points are `a`, `b` and `c`" the first time, "" after | ": this configuration has no input point")
input `<k>` is a bool: only 0 or 1 fit, found <v>                                             (call/4's)
input `<k>` is a dint: its value must be an integer, found <inspect>                          (call/4's)
input `<k>` is a dint: <v> does not fit in 32 bits                                           (call/4's)
<inspect> is not an access path: a global, or a program instance, its tag and the members below it, joined by `.`, as in "m1.t1.acc"
`<h>` is neither a global nor a program instance<did-you-mean>
`<h>` is a task, not a global or a program instance: an access path starts at one of those, and overlaps/1 reads a task's overlap count     (rev, GT-8)
`<h>` is the configuration's name, which an access path leaves out: it starts at a global or a program instance                             (rev, GT-8)
`<path>` goes too deep: `<g>` is a <type> global, which has no members
`<i>` is a program instance, a `<type>`: an access path names one of its tags, as in `<i>.<first tag>`
`<i>` is a program instance, a `<type>`: an access path names one of its tags, and it declares none
`<i>` is a `<type>`, which declares no `<tag>`<did-you-mean>
`<path>` goes too deep: `<i>.<tag>` is a <type>, which has no members
`<at>` is a <block type>: an access path names one of its members, as in `<at>.<first output member>`
`<at>.<m>` is not a member of `<at>`, a <block type><hint>    (" — did you mean …? (members are case-sensitive)" | ": its members are `pre`, `acc`, `dn`, `tt` and `en`")
`<path>` goes too deep: `<at>.<m>` is a <type>, which has no members
```

`put_inputs/3` and `call/4`: "input `<k>` is not declared: the var_inputs are …" now lists
them only on the first such line of a refusal (LO-1; §11 D-5). The S-synth messages for a
block with no output and with no public member are gone with GT-4b and GT-7.

---

## 4. Each new piece of state across an online edit

CLAUDE.md's rule (CLAUDE.md:166-173 at `47319f7`) is written for a field of
`%Logex.Instance{}`. M2-1 adds no field to `%Logex.Instance{}` or `%Logex.Scan{}`. Its
state lives in the opaque `%Logex.Runtime{}`, which no host hands in, so a field gets no
entry check with a pinned message. Instead it gets a value from `start/1` and a rule for a
cycle, for `restart/2` and for OE-2's switch, with the edit's exceptions listed. The
rules now live in code (S-FIT-1):

- `Logex.Configuration.initial/1` holds the one rule for a global, and its doc lists the
  edit's exceptions.
- `Logex.Runtime`'s moduledoc section "One rule for each piece of a resource's state"
  holds the rest.
- §9's commit 1 copies this table into org §4.9's "One rule for new state".

| Piece | `start/1` (the one rule) | `cycle/3` | `restart/2` | OE-2 switch: kept | OE-2: added | OE-2: removed |
|---|---|---|---|---|---|---|
| `now` | 0 | `+ elapsed_ms` | kept | never touched | — | — |
| an input point's value | `initial/1`: 0 | the input merge | kept (RS-3) | kept, same name and type | refused while running: located I/O (org:860-863) | refused while running |
| an output point's value | `initial/1`: 0 | the copy-out of its driver | `initial/1`: 0 (RS-5) | kept; held and reported if no connection drives it any more (decision 20) | refused while running | refused while running |
| an unlocated global's value | `initial/1` | copy-out | `initial/1` (RS-5) | kept, a changed `initial` included; whether that change is reported is §13 Q-34 | `initial/1`, the one rule | kept unused at test, pruned at assemble |
| — a global's type, `at` | — | — | — | a change refused at accept (org:860-863) | — | — |
| `instances[i]` | `Runtime.instance/1` (F14) | that instance's `call/4` | `restart/3` (RS-4) | moved by `Logex.Edit`'s per-instance switch for its type's plan (F5, org:924-929) | `Runtime.instance/1` | kept at test, pruned at assemble; every global it drove holds its value and is reported held |
| — an instance's `type` | — | — | — | §13 Q-33 | — | — |
| — an instance's `task` | — | — | — | a change refused (decision 19, org:864) | — | — |
| `tasks[t].next_due` | 0 | CY-5 | the kept `now` (RS-2) | kept, unless its interval changes (§13 Q-23) | refused until verified (decision 19, org:866-867) | refused until verified |
| `tasks[t].overlaps` | 0 | `+ missed` | 0 (RS-1) | kept | — | — |
| `config` | the configuration | — | kept | the candidate's at test, the original's at untest | | |
| `wiring` | derived | — | kept | rebuilt from the configuration switched to | | |

Inside a resource, each `%Logex.Instance{}` keeps OE-1's rules unchanged. `first` is set
by `instance/1` and `restart/3`, and cleared by a scan. `ons_blocked` and `switched` stay
`[]` and false, because nothing in M2-1 switches an instance. An instance's `now` is the
resource's `now` at its last scan, and that `now` only grows (RS-6), so `call/4`'s "time
went backwards" check cannot fire.

The edit's exceptions (org:879-880) do not grow in M2-1. A connection is not state. The
`restart/2` column is a cold restart of the same configuration. A restart that takes a
candidate and keeps values by name (org:858) is OE-2's to design on top of it.

---

## 5. What each later item and OE-2 add

Nothing below reshapes a struct that M2-1 lands, or reverses one of its rules. Each item
adds text, a field with a default, or a rule. Where another track owns an item, this
section says only what M2-1 hands it.

- **M2-2 · the configuration file** (track T).
  - How the file is read is T's Q-2. It recommends a recursive descent over
    `Logex.Lexer`'s tokens, not S-synth's route through `Logex.Parser`'s rung tree (X11).
  - The reader builds the element structs with `line`, sets `file` and `name`, and calls
    `check/1`.
  - It owes each `check/1` diagnostic asserted again as a whole list from
    configuration-file source, as org §6.2 asks of every Milestone 2 diagnostic. M2-1
    pins them from data only (§11 D-1; S-FIT-7).
  - It reserves its words with their `docs/naming.md` stanzas. CF-1 then grows "and not a
    configuration keyword".
  - It is the first to fill `warnings`, with W1 and W2 (X12).
  - Fix F15 goes to whichever item meets it first: M2-5 under §13 Q-22's order (X18).
  - The `Logex.Configuration` surface pin in `runtime_test.exs` must be rewritten once,
    when T's checks become rows of `check/1`. A textual merge keeps both pins, cleanly and
    contradictorily (X2).
- **M2-3 · periodic tasks in text.** It adds `task <n> interval <ms> priority <p>` and
  `program … with <task>`, which build `Task` and `Instance.task`; both exist from M2-1.
  - Its words need stanzas. `priority`'s must say that one vendor family numbers the other
    way (`research.md` SIE-1).
  - Its acceptance counts are M2-1's scheduler at 10 ms steps (§13 Q-21).
  - Its documents state the answer to §13 Q-23.
  - It adds W3.
- **M2-4 · shared globals.** `var_external` becomes a section. B5's one IR walk gives
  "which tags a program writes".
  - `check/1` gains its rows: a `var_external` has a global of its name and type, and a
    written one is not bound to an input point.
  - Two writers is a warning (W4, W5).
  - The scan step merges each external's global into the env before `call/4` and splits
    it off after (G2), so there is one copy (org:886).
  - `get/2` reads `m1.estop` as the global.
- **M2-5 · user function blocks** (track F). Nothing in the configuration or the
  scheduler changes, but M2-5 owes these:
  - `get(rt, "m1.s2.run")`, its Done-when, is asserted by M2-5's test, since M2-5 lands
    second under §13 Q-22 (X6). The S+F merge reads it: `{:ok, 1}` (rf-X-consistency X6).
  - GT-4b and GT-7, from source, if FS-Q9's answer lets a block type have no output
    member or no public member (S-FIT-8).
  - A growth test of `get/2` in depth only under FS-Q9(b). Under (a) no path is deeper
    than `inst.tag.member` (X16).
  - One message for a block type given as a program, across `new!/1`, `check/1`,
    `compile/3`, the loader, `Runtime.instance/1` and `Edit.accept/3` (§13 Q-39; X13).
    BT-2's is S's interim wording.
  - Fix F15, with F's R68 convention (a block file's diagnostics carry its file) stated
    beside T's R51 (a configuration diagnostic names a type's file in its text) (X18).
- **M2-6 · event tasks.** `Task` gains `single: nil | global_name`.
  - CF-5 becomes "an interval, or a `single`, or both", and `single` names a bool global.
  - Each event task's state gains `last: 0`. It is 0 at `start/1` and at `restart/2`, and
    kept by OE-2.
  - OE-2 refuses a changed `single`, and adding or removing an event task's `interval`
    (T Q-15; X19).
  - The `ton`-in-an-event-task warning is W6.
- **OE-2.** Instances, globals and tasks are lists of named structs, compared by name.
  - A generation counter is OE-2's to add (§13 Q-26).
  - Until OE-2, an instance inside a resource is not edited. The moduledoc now says so
    (S-FIT-2; §13 Q-32).
  - A new global starts by `Configuration.initial/1` (S-FIT-1).

---

## 6. Spike receipts

**Gate,** three times on the final spike, each command judged by its exit code
(`S-rev-probe/gate.sh`, logs `gate-1.log`, `gate-2.log`, `gate-3.log`):

| Run | `mix format --check-formatted` | `mix compile --force --warnings-as-errors` | `MIX_ENV=test mix compile --force --warnings-as-errors` | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0, `Result: 514 passed (8 doctests, 506 tests)` |
| 2 | 0 | 0 | 0 | 0, `Result: 514 passed (8 doctests, 506 tests)` |
| 3 | 0 | 0 | 0 | 0, `Result: 514 passed (8 doctests, 506 tests)` |

At `47319f7` the suite is 430 tests, 6 of them doctests. S-synth's was 500.

**The landing order, built** (`S-rev-probe/series.py`, then `gate-series.sh`, log
`series-gate-2.log`). Each commit is gated in its own worktree. `diff -r` of the last
commit's tree against `S-rev-work` (excluding `.git`, `_build`, `deps`, `tmp`) prints
nothing. The commits are `7acab45` (2), `5df3de5` (3), `ea6e537` (4),
`42c636a` (5) and `e897a45` (6), on branch `s-rev`:

| Commit | format | compile | test compile | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| 2: Logex.Configuration and the :configure stage | 0 | 0 | 0 | 0, Result: 466 passed (8 doctests, 458 tests) |
| 3: the resource, with periodic tasks | 0 | 0 | 0 | 0, Result: 504 passed (8 doctests, 496 tests) |
| 4: restart/2 | 0 | 0 | 0 | 0, Result: 509 passed (8 doctests, 501 tests) |
| 5: the contract walk | 0 | 0 | 0 | 0, Result: 510 passed (8 doctests, 502 tests) |
| 6: the Done-when end to end | 0 | 0 | 0 | 0, Result: 514 passed (8 doctests, 506 tests) |

The first build of the series, before a comment edit in `runtime.ex`, gave the same
results (`series-gate-1.log`).

**Patch.** `git add -A && git diff --cached HEAD` in `S-rev-work`, saved as
`S-rev.patch`. `git apply --check` against a fresh clone of `/home/user/logex` at `47319f7` (deleted after) exits 0. Its stat is 10 files changed, 4774 insertions, 22 deletions. The patch has ten files:

- `lib/logex/configuration.ex` (new);
- `lib/logex/runtime.ex`;
- `lib/logex/diagnostic.ex`;
- `lib/logex/program.ex` (doc only);
- `CLAUDE.md`;
- five test files: `configuration_test.exs` and `scheduler_test.exs` (new),
  `runtime_test.exs`, `end_to_end_test.exs` and `api_contract_test.exs`.

The test count goes from 430 to 514:

| File | Tests added |
|---|---|
| `configuration_test.exs` | +37 |
| `scheduler_test.exs` | +29 |
| `runtime_test.exs` | +11 |
| `end_to_end_test.exs` | +4 |
| `api_contract_test.exs` | +1 |
| doctests | +2 |

**rf-S-correct-F1 and F2, measured after the revision** (`S-rev-probe/sizes.exs`, output
`sizes.out`, reductions the least of three):

```
F1 n=100 scans=1 cycle=531 next_due_in=527
F1 n=400 scans=1 cycle=1431 next_due_in=2047
F1 n=1600 scans=1 cycle=5031 next_due_in=8127
F1 n=6400 scans=1 cycle=19431 next_due_in=32447
F2 n=100 cycle bytes=4707 red=1105209 | check bytes=6602 red=1123189 | put_inputs bytes=4102 red=1215115
F2 n=400 cycle bytes=19407 red=19231289 | check bytes=27002 red=19302361 | put_inputs bytes=17002 red=20618922
F2 n=1600 cycle bytes=79409 red=329466155 | check bytes=109804 red=329259233 | put_inputs bytes=69804 red=347173200
```

- F1's cost is linear in the tasks declared, as the finding measured (531 to 19431), and
  is now so stated and pinned.
- F2's message size is now linear: 4.1x for 4x. Before the revision it was 1263491 to
  21376492 bytes from 400 to 1600, quadratic.
- F2's reductions are still about 17x for 4x. This is `Declarations.suggest/4`'s Jaro
  pass per key (§12, §13 Q-31).

**Done-when and README walks:** unchanged from S-synth (§6 there). Its
`end_to_end_test.exs` is byte for byte S-synth's, and passes in the gate above. The
judges' probes, JS1's oracle and the ten extra walk seeds were not rerun on S-rev. They
are S-synth's receipts. One of them no longer holds: JS2's `get/2` of a hand-built block
with no output member was a pinned `ArgumentError` in S-synth. With GT-4b gone it is a
`MatchError`, from a `%Logex.Program{}` edited by hand, which is outside the contract
(runtime.ex's moduledoc; fix F12).

---

## 7. Test plan and mutation table

### 7.1 Where each rule is pinned

| Test file | What it pins |
|---|---|
| `configuration_test.exs` (37 tests, 2 doctests) | NW-1…NW-4, CF-1…CF-31, BT-1, BT-2, LO-2, LO-3, IR-1, IR-2, each as a whole list of formatted messages from `new!/1` or `check/1`; lines and file with a configuration built as M2-2's reader will build one; the two seeded properties; `check/1`'s growth and a refusal's size. The describe "start/1 checks again" (three tests: `start/1` raises `check/1`'s problems; what `new!/1` accepts starts and cycles; 2,000 configurations spoiled by hand) lands with commit 3 |
| `scheduler_test.exs` (29 tests) | RT-2, RT-3 and the one rule for globals, CY-1…CY-9, EV-1, NX-1, NX-2, ST-2, the input image, copy-in and copy-out, two instances of one type; the order of instances against name order and past 32; `restart/2` (RS-1…RS-6), the one rule after it, plain data after it, and a first scan after it; plain data (PD-1); growth (GR-1, GR-2, GR-2b, GR-4, GR-5) |
| `runtime_test.exs` (+11) | §3.3's messages: `start/1`, `cycle/3` (CY-0, IN-1a…IN-1g, IN-2, IN-3, LO-1), `next_due_in/1`, `overlaps/1`, `restart/2` (RS-0), `get/2` (GT-1…GT-8 but GT-4b and GT-7); a refusal's size; `put_inputs/3`'s list once; the public surface, with `Logex.Configuration`'s `initial: 1` |
| `end_to_end_test.exs` (+4) | PLAN M2-1's Done-when as three tests, and the timed program; both README walks with restarts |
| `api_contract_test.exs` (+1) | the seeded walk of S-synth §7.1, with three more refusal kinds (`:instance_key`, `:task`, `:configuration`), now 22, each reached |

### 7.2 The mutation table

Driver: `scratchpad/m2/S-rev-mutation.py`, run by `S-rev-probe/run-mutation.sh` in three
workers, each in its own copy of the spike. For each mutant the driver:

1. applies one exact text replacement, which must match once;
2. runs `mix compile --warnings-as-errors`;
3. if that exits 0, runs the whole suite with `mix test --warnings-as-errors`, recording
   the exit code and the failing tests;
4. restores the file.

At the end it checks with `filecmp` that each copy's files match the spike's again. The
log is `scratchpad/m2/S-rev-mutation.jsonl`, one JSON object per mutant. Exit 2 is
ExUnit's code for a failing suite.

The table has S-synth's 101 rows less GT-4b and GT-7, with five rows' texts updated to the
revised code (IN-1c, IN-3, GT-4a, RS-5, and the driver's paths), plus 14 new rows.

**Result: 113 mutants. Every one compiled cleanly (`mix compile --warnings-as-errors`
exit 0), and every one is red.**

- 112 exit 2.
- NX-1a exits 3, as it did in S-synth. Its mutant also makes a test file draw a type
  warning, which `--warnings-as-errors` adds to its two failures.
- In the first run (`S-rev-probe/mutation-run1.jsonl`), two mutants did not compile
  cleanly, and neither was counted in that form:
  - CY-2's text still named `wiring`, which the revised `image!/2` no longer binds;
  - IR-2's first form called `exit/2`.

  Each was rewritten (CY-2 to `runtime.wiring`, IR-2 to raise `RuntimeError`) and rerun
  alone (`S-rev-probe/mut-rerun.jsonl`), and both are red. The merged log marks them
  `"rerun"`.
- Each worker's copy was checked against the spike with `filecmp` after its run (three
  `{"restored": true}` lines).
- The new rows are IN-1d…g, GT-8, LO-1…3, BT-1, BT-2, IR-1, IR-2, GR-2b and GR-5.

| Rule | Reverted alone | compile | mix test | Red in | First failing tests |
|---|---|---|---|---|---|
| NW-1 | new!/1 takes a keyword list | 0 | 2 | ConfigurationTest | nothing escapes an improper list, in any part or as the keyword list, is an ArgumentError; new!/1's own refusals a keyword list, and nothing else |
| NW-2 | new!/1: no unknown field, none given twice | 0 | 2 | ConfigurationTest | new!/1's own refusals a keyword list, and nothing else |
| NW-3 | new!/1 refuses an element from Elixir that brings a line | 0 | 2 | ConfigurationTest | new!/1's own refusals an element from Elixir has no line |
| NW-4 | new!/1 checks such an element without its line (one mistake, one message) | 0 | 2 | ConfigurationTest | new!/1's own refusals an element from Elixir has no line |
| CF-3c | new!/1: two programs of one name refused | 0 | 2 | ConfigurationTest | new!/1's own refusals programs: a list of named programs, each named once |
| CF-3d | new!/1: an unnamed program refused as unnamed | 0 | 2 | ConfigurationTest | new!/1's own refusals programs: a list of named programs, each named once |
| CF-1 | a name is a name | 0 | 2 | ConfigurationTest | names tasks, globals and program instances share one namespace, case-only twins refused, and a name is a name |
| CF-2 | one namespace: a name taken twice is refused | 0 | 2 | ConfigurationTest | names, in a file the later line is refused, citing the earlier; names tasks, globals and program instances share one namespace, case-only twins refuse… |
| CF-2b | the namespace is taken in line order | 0 | 2 | ConfigurationTest | names, in a file the later line is refused, citing the earlier |
| CF-2c | a case-only twin is refused | 0 | 2 | ConfigurationTest | names tasks, globals and program instances share one namespace, case-only twins refused, and a name is a name |
| CF-3a | a program is under its own name | 0 | 2 | ConfigurationTest | check/1 programs are a map of named programs, each under its own name |
| CF-3b | a program's name is a name | 0 | 2 | ConfigurationTest | check/1 programs are a map of named programs, each under its own name |
| CF-4 | a line is a positive integer or nil | 0 | 2 | ConfigurationTest | check/1 a line is a positive integer, or nil |
| CF-4b | each part is a proper list (fix F8) | 0 | 2 | ConfigurationTest | check/1 each field is a list of its element struct, a proper one; start/1 checks again what new!/1 accepts starts, and cycles |
| CF-5 | an interval is 1..2147483647 | 0 | 2 | ConfigurationTest | start/1 checks again raises the problems check/1 gives, in their order; new!/1's own refusals an element from Elixir has no line |
| CF-6 | a priority is 0..2147483647 | 0 | 2 | ConfigurationTest | tasks an interval is 1 to 2147483647 ms, and a priority 0 to 2147483647 |
| CF-7 | a global is a bool or a dint | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-8 | an initial value fits | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-9 | an initial value is not negative | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-10a | an input point takes no initial value | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-10b | an output point takes no initial value | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-11 | a location is <device>.i\|q.<address> | 0 | 2 | ConfigurationTest | globals a location is a device, i or q, and an address, and one address holds one global; globals location/1 reads a location's parts |
| CF-11b | an address field has no leading zero | 0 | 2 | ConfigurationTest | globals a location is a device, i or q, and an address, and one address holds one global; globals location/1 reads a location's parts |
| CF-12 | one address holds one global | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order; globals a location is a device, i or q, and an address, and one addr… |
| CF-13 | an instance names a program | 0 | 2 | ConfigurationTest | start/1 checks again start/1 refuses a configuration spoiled by hand, raising nothing else; start/1 checks again what new!/1 accepts starts, and cycle… |
| CF-14 | an instance's task is declared | 0 | 2 | ConfigurationTest | lists of names each list is given once, by the first diagnostic in line order; program instances name a program, and a task if any |
| CF-15 | a connection names a declared instance | 0 | 2 | ConfigurationTest | lists of names each list is given once, by the first diagnostic in line order; start/1 checks again what new!/1 accepts starts, and cycles |
| CF-16 | a connection names a declared member | 0 | 2 | ConfigurationTest | lists of names each list is given once, by the first diagnostic in line order; connections name a var_input or var_output of a declared instance |
| CF-17 | only a var_input or var_output connects | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance |
| CF-18 | a var_input is connected once | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order; connections a var_input is connected once, to a global of its type o… |
| CF-19 | a var_input's global is of its type | 0 | 2 | ConfigurationTest | connections a var_input is connected once, to a global of its type or a constant that fits |
| CF-20 | a constant fits its var_input | 0 | 2 | ConfigurationTest | connections a var_input is connected once, to a global of its type or a constant that fits |
| CF-21 | a connection's instance and member are names | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance; start/1 checks again what new!/1 accepts starts, and cycles |
| CF-22 | a var_output drives no constant | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-23 | a var_output never drives an input point | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it; lines and the file each problem … |
| CF-24 | a var_output's global is of its type | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-25 | one connection drives a global | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-26 | every var_input is connected (decision 7) | 0 | 2 | ConfigurationTest | program instances name a program, and a task if any; names tasks, globals and program instances share one namespace, case-only twins refused, and a na… |
| CF-27 | at least one program instance | 0 | 2 | ConfigurationTest, RuntimeTest | a resource's host contract (M2-1) start/1 takes a configuration, checked again; program instances at least one |
| CF-28a | problems in line order | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order |
| CF-28b | problems carry the configuration's file | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order; names, in a file the later line is refused, citing the earlier |
| CF-28c | a problem's stage is :configure | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order |
| CF-29a | a junk instance name is never offered as a did-you-mean | 0 | 2 | ConfigurationTest | nothing escapes check/1 and new!/1 give a diagnostic or an ArgumentError, never anything else; start/1 checks again what new!/1 accepts starts, and cy… |
| CF-29b | a var_input to a global of a refused type is not checked again | 0 | 2 | ConfigurationTest | start/1 checks again start/1 refuses a configuration spoiled by hand, raising nothing else; nothing escapes a global of a refused type, or an instance… |
| CF-29c | a var_output to a global of a refused type is not checked again | 0 | 2 | ConfigurationTest | start/1 checks again start/1 refuses a configuration spoiled by hand, raising nothing else; start/1 checks again what new!/1 accepts starts, and cycle… |
| CF-30 | a configuration has a name | 0 | 2 | ConfigurationTest | check/1 a configuration has a name, and it is a name |
| CF-31 | a configuration's file is a name or nil | 0 | 2 | ConfigurationTest | start/1 checks again start/1 refuses a configuration spoiled by hand, raising nothing else; start/1 checks again raises the problems check/1 gives, in… |
| RT-1 | start/1 checks the configuration again | 0 | 2 | ConfigurationTest, RuntimeTest | a resource's host contract (M2-1) start/1 takes a configuration, checked again; start/1 checks again raises the problems check/1 gives, in their order |
| RT-2 | start/1 builds each instance as instance/1 (F14) | 0 | 2 | ApiContractTest, SchedulerTest | start/1 builds each instance as instance/1 does: its first scan is a first scan; a resource refuses every host mistake with a documented ArgumentError… |
| RT-3 | every task is due at start | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; restart/2 puts every global but an input … |
| CY-0 | the runtime is checked before elapsed_ms | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) every call takes a runtime from start/1, checked first |
| CY-1 | time advances by elapsed_ms | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | due tasks and their order task-less instances run last, once in every cycle, an elapsed 0 one included, where a periodic task runs once per period; du… |
| CY-2 | the input image persists between cycles | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | the input image keeps each input point's value between cycles: a host sends only what changed; restart/2 starts the resource again, keeping the clock … |
| CY-3 | a periodic task is due when its due time has come | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | start/1 every global at its initial value, 0 without one, at time 0, every task due; due tasks and their order of one priority, the earlier due time r… |
| CY-4a | due tasks by priority first | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | due tasks and their order a higher priority, the lower number, runs before an earlier due time; a resource refuses every host mistake with a documente… |
| CY-4b | then by the earlier due time | 0 | 2 | ApiContractTest, SchedulerTest | a resource refuses every host mistake with a documented ArgumentError, accepts every call without one, and runs as its rules say; due tasks and their … |
| CY-4c | then by declaration (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; a resource refuses every host mistake with a docu… |
| CY-4d | then by declaration (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; a resource refuses every host mistake with a docu… |
| CY-5 | the phase is kept: next due moves by whole intervals | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; missed periods are counted, not run again, and th… |
| CY-6a | a missed period is reported | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods a first cycle after the start reports the periods before it; missed periods are counted, not run again, and the phase is kept |
| CY-6b | a missed period is counted | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; missed periods a task with no instance keeps its time and its count, and r… |
| CY-7a | task-less instances run after every due task | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; the order of instances a task's instances, and the task-less ones, run in … |
| CY-7b | task-less instances run in every cycle | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | start/1 builds each instance as instance/1 does: its first scan is a first scan; copy in and copy out a var_input tied to a constant reads it at every… |
| CY-7c | a task's instances in declaration order (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | the order of instances in the order declared past 32 instances; the order of instances a task's instances, and the task-less ones, run in the order de… |
| CY-7d | a task's instances in declaration order (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | a resource refuses every host mistake with a documented ArgumentError, accepts every call without one, and runs as its rules say; the order of instanc… |
| CY-7e | task-less instances in declaration order (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | copy in and copy out an instance sees what an earlier one wrote in the cycle, and never what a later one writes until the next cycle; the order of ins… |
| CY-7f | task-less instances in declaration order (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | copy in and copy out an instance sees what an earlier one wrote in the cycle, and never what a later one writes until the next cycle; the order of ins… |
| CY-8a | copy in: a constant | 0 | 2 | ApiContractTest, SchedulerTest | copy in and copy out a var_input tied to a constant reads it at every scan; a resource refuses every host mistake with a documented ArgumentError, acc… |
| CY-8b | copy in: a global's current value | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; copy in and copy out a var_output drives … |
| CY-8c | copy out: a var_output to its global, at once | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; start/1 builds each instance as instance/… |
| CY-9 | the outputs are the output points only | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | the input image a refused cycle changes nothing: the runtime is a value; restart/2 starts the resource again, keeping the clock and the input image |
| EV-1 | a task-less scan is reported with :none | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods a task with no instance keeps its time and its count, and runs nothing; the order of instances in the order declared past 32 instances |
| EV-2 | an overlap is reported just before its task's scans | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods are counted, not run again, and the phase is kept; missed periods a first cycle after the start reports the periods before it |
| IN-1a | only an input point is set: an output point or unlocated global refused | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-1b | a path into an instance is refused as one | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-1c | a key that is not a string is refused as one | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-2 | an input point's value fits it | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-3 | every input problem in one raise | 0 | 2 | RuntimeTest | a name that is no input point and no global a refusal lists the input points once; a resource's host contract (M2-1) only an input point is set, with … |
| NX-1a | next_due_in is :infinity with no task | 0 | 3 | ApiContractTest, SchedulerTest | next_due_in/1 is :infinity for a configuration of task-less instances alone; a resource refuses every host mistake with a documented ArgumentError, ac… |
| NX-1b | next_due_in is the soonest task | 0 | 2 | ApiContractTest, SchedulerTest | next_due_in/1 is when a periodic task is next due, never a task-less instance; a resource refuses every host mistake with a documented ArgumentError, … |
| NX-2 | overlaps/1 reads each task's count | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods are counted, not run again, and the phase is kept; missed periods a task with no instance keeps its time and its count, and runs nothin… |
| GT-1 | get/2 never reads an internal member | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; a resource refuses every host mistake wit… |
| GT-2 | get/2 refuses an instance named whole | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; get/2 of an instance whole names one of i… |
| GT-3 | get/2 refuses a path past a bool or a dint | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; a resource refuses every host mistake wit… |
| GT-4a | a whole block's example is an output member first | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else |
| GT-6 | an instance whole: one of its tags as the example, else none | 0 | 2 | RuntimeTest, LogexTest | get/2 of an instance whole names one of its tags, or says it declares none; compile/2 compiling stays linear in the program's size |
| GT-5 | an access path lexes as one name token | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else |
| RS-0 | restart/2 checks the runtime, then the mode | 0 | 2 | RuntimeTest | a resource's host contract (M2-1), the rest restart/2 takes a runtime, then :cold or :warm |
| RS-1 | restart/2 zeroes every overlap count | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-2 | restart/2 makes every task due at the next cycle | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-3 | restart/2 keeps the input image | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; restart/2 puts every global but an input point back by the one rule |
| RS-4 | restart/2 restarts each instance through restart/3 | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 each instance's next scan is a first scan; restart/2 starts the resource again, keeping the clock and the input image |
| RS-5 | restart/2 puts every other global back at its initial value | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; restart/2 puts every global but an input point back by the one rule |
| RS-6 | restart/2 keeps the clock | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; restart/2 each instance's next scan is a first scan |
| PD-1 | a runtime is plain data | 0 | 2 | EditTest, SchedulerTest | restart/2 leaves a runtime of plain data; plain data a runtime holds nothing but plain data, at start and after cycles |
| GR-1 | a cycle is linear in the instances it runs (an event list rebuilt per scan) | 0 | 2 | SchedulerTest | growth a cycle stays linear in the instances it runs |
| GR-2 | a cycle is linear in the tasks due | 0 | 2 | SchedulerTest | growth a cycle stays linear in the number of instances, tasks and connections |
| GR-3 | check/1 (so new!/1 and start/1) is linear in the instances | 0 | 2 | ConfigurationTest, EditTest, SchedulerTest | growth check/1 stays linear in the configuration's size; growth start/1 stays linear in the configuration's size |
| GR-4 | start/1 is linear in the instances (its own part) | 0 | 2 | SchedulerTest | growth start/1 stays linear in the configuration's size |
| IN-1d | an input key naming a program instance whole is told so | 0 | 2 | ApiContractTest, RuntimeTest | a name that is no input point and no global is told what it names: a program instance, a task, or the configuration; a resource refuses every host mis… |
| IN-1e | a key or path naming a task is told so | 0 | 2 | ApiContractTest, EditTest, RuntimeTest | a name that is no input point and no global a task that shares the configuration's name is the task; a name that is no input point and no global is to… |
| IN-1f | a key or path naming the configuration is told so | 0 | 2 | ApiContractTest, RuntimeTest | a name that is no input point and no global is told what it names: a program instance, a task, or the configuration; a resource refuses every host mis… |
| IN-1g | a task that shares the configuration's name is the task | 0 | 2 | RuntimeTest | a name that is no input point and no global a task that shares the configuration's name is the task |
| GT-8 | get/2 says what a task's or the configuration's name is | 0 | 2 | RuntimeTest | a name that is no input point and no global a task that shares the configuration's name is the task; a name that is no input point and no global is to… |
| LO-1 | a runtime refusal lists the names once (put_inputs/3, call/4, cycle/3) | 0 | 2 | RuntimeTest | a name that is no input point and no global a refusal lists the input points once; a name that is no input point and no global a refusal of many keys … |
| LO-2 | check/1 gives each list of names once | 0 | 2 | ConfigurationTest | lists of names each list is given once, by the first diagnostic in line order; growth a refusal stays linear in its size |
| LO-3 | check/1 keys each list apart | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance; lists of names each list is given once, by the first diagnostic in line order |
| BT-1 | new!/1 keeps a block type under its name, so it is refused once | 0 | 2 | ConfigurationTest | new!/1's own refusals a function block type is not a program, and is refused once |
| BT-2 | check/1 says a block type is not a program | 0 | 2 | ConfigurationTest | new!/1's own refusals a function block type is not a program, and is refused once |
| IR-1 | initial/1: a global's initial value, or 0 without one | 0 | 2 | ApiContractTest, ConfigurationTest, EndToEndTest, RuntimeTest, SchedulerTest | Logex.Configuration.initial/1 (1); copy in and copy out an instance sees what an earlier one wrote in the cycle, and never what a later one writes unt… |
| IR-2 | initial/1 refuses anything else with ArgumentError | 0 | 2 | ConfigurationTest | a global's initial value initial/1 takes a global whose initial value is an integer or nil |
| GR-2b | a cycle is linear in the tasks declared, one due among many | 0 | 2 | SchedulerTest | growth a cycle stays linear in the number of instances, tasks and connections; growth a cycle that runs one task, and next_due_in/1, stay linear in th… |
| GR-5 | next_due_in/1 is linear in the tasks declared | 0 | 2 | SchedulerTest | growth a cycle that runs one task, and next_due_in/1, stay linear in the tasks declared |

### 7.3 Each commit's rows, in its own tree

Each commit of §8 carries its rows: every rule it lands, reverted alone in that commit's
tree, with that commit's suite (`S_REV_WORK` set to a worktree of the commit). Logs:
`S-rev-probe/mut-c2.jsonl`, `mut-c3.jsonl`, `mut-c4.jsonl`.

| Commit | Rows | Compiled cleanly | Red | Rules |
|---|---|---|---|---|
| 2: `Logex.Configuration` | 54 | 54 | 54 | NW-1, NW-2, NW-3, NW-4, CF-3c, CF-3d, CF-1, CF-2, CF-2b, CF-2c, CF-3a, CF-3b, CF-4, CF-4b, CF-5, CF-6, CF-7, CF-8, CF-9, CF-10a, CF-10b, CF-11, CF-11b, CF-12, CF-13, CF-14, CF-15, CF-16, CF-17, CF-18, CF-19, CF-20, CF-21, CF-22, CF-23, CF-24, CF-25, CF-26, CF-27, CF-28a, CF-28b, CF-28c, CF-29a, CF-29b, CF-29c, CF-30, CF-31, GR-3, LO-2, LO-3, BT-1, BT-2, IR-1, IR-2 |
| 3: the resource | 52 | 52 | 52 | RT-1, RT-2, RT-3, CY-0, CY-1, CY-2, CY-3, CY-4a, CY-4b, CY-4c, CY-4d, CY-5, CY-6a, CY-6b, CY-7a, CY-7b, CY-7c, CY-7d, CY-7e, CY-7f, CY-8a, CY-8b, CY-8c, CY-9, EV-1, EV-2, IN-1a, IN-1b, IN-1c, IN-2, IN-3, NX-1a, NX-1b, NX-2, GT-1, GT-2, GT-3, GT-4a, GT-6, GT-5, PD-1, GR-1, GR-2, GR-4, IN-1d, IN-1e, IN-1f, IN-1g, GT-8, LO-1, GR-2b, GR-5 |
| 4: `restart/2` | 7 | 7 | 7 | RS-0, RS-1, RS-2, RS-3, RS-4, RS-5, RS-6 |

All 113 rows are red in the commit that lands them, so no rule depends on a later
commit's test to be caught, and each commit's message can carry its rows, as OE-1's did.

- One row differs from the final spike's run. NX-1a exits 3 in commit 3, with one
  failure (in SchedulerTest) plus the type warning. The contract walk, which also catches
  it in the final spike, lands in commit 5.
- Each run's copy was checked against its tree afterwards (`{"restored": true}` in each
  log).

### 7.4 Rules no test can see, and why

- **CY-10** (a task with no instance keeps its schedule): no line implements it on its
  own, so there is no one-line revert. It is pinned by `scheduler_test.exs` and by the
  walk.
- **EV-3** (events are an open set): a promise to the host, with no code to revert.
- **ST-1** (a hand-built runtime is outside the contract): a statement of scope. The entry
  check is CY-0's and RS-0's rows.
- **ST-2** (a call is a function of its arguments): PD-1's mutant and the walk's "every
  call twice" guard it.
- **Limits a reductions count cannot see** (§12): a plain `events ++ [event]` per scan,
  and a quadratic made only of BIF calls.
- **The documents-only fixes** (S-FIT-2, 4, 5, 7, 9, 10, 11, 12, and the X items) change
  no code, so no test can fail when they are reverted. The moduledoc sentences for
  S-FIT-2 and S-FIT-10 are text, as README's examples are (CLAUDE.md: "Nothing tests
  this").

---

## 8. Landing order, as commits, each green

M2-1 has no syntax: **no commit adds a word to any language, so none owes a
`docs/naming.md` stanza, none reserves a word, and none breaks a tag.**

The order of the milestone is §13 Q-22: M2-1, then M2-5 before M2-2, then M2-3, M2-4 and
M2-6.

0. *(Optional, independent; a public struct change; §13 Q-36.)* The compiler lists a
   program's var_outputs once, in a new `outputs` field of `%Logex.Program{}` (default
   nil). `outputs/2` reads the list (`readiness.md` §1.7: the motor's `call/4` goes from
   277 to 233 reductions).
   - It stales `program.ex`'s defstruct and type and CLAUDE.md's field list
     (CLAUDE.md:71). No surface test pins Program's keys.
   - Its consistency rule: `outputs` is exactly the var_output names of `tags`, or nil.
     `call/4`'s entry check must refuse any other value with a pinned message. Without
     that, a hand-built program whose `outputs` names a non-var_output tag returns that
     tag as an output and raises nothing (S-FIT-11's probe).
   - The alternative keeps the list out of the public struct: `start/1` derives each
     program type's var_outputs into `wiring`, and a cycle calls a private scan that takes
     them. Not built.
1. **The design record, for all three tracks at once** (X14).
   - The maintainer's answers to S's, F's and T's §13 go into org §7 in one commit, each
     decision numbered once across the tracks, before any M2 code cites one. The labels
     test (`test/logex/edit_test.exs:1557-1569`) refuses any cited decision §7 does not
     define, and needs §7 to run 1..n.
   - The same commit orders the overlapping document edits: org §4.4, §4.6, §4.9, §6.2,
     PLAN's Done-whens, README's syntax list, and CLAUDE.md's `lib/logex.ex` entry.
   - From this track: §4's table goes into org §4.9's "One rule for new state" (S-FIT-1).
     §4.4's checks move "with M2-1". §4.6's API block gains `overlaps/1` and `restart/2`.
     PLAN M2-1's Done-when is reworded if Q-21 is taken.
   - Documents only.
2. **`Logex.Configuration` and the `:configure` stage.** The structs, `check/1`, `new!/1`,
   `location/1` and `initial/1`. `configuration_test.exs`, all but "start/1 checks again".
   The surface pin gains `Logex.Configuration`, and CLAUDE.md gains its Key Files entry.
   Nothing runs a configuration yet. Built: 466 tests, green.
3. **The resource, with periodic tasks** (S-synth's commits 3 and 4 merged; S-FIT-3).
   - `%Logex.Runtime{}`, `start/1`, `cycle/3`, `next_due_in/1`, `overlaps/1` and `get/2`,
     with their messages and the list-once refusals.
   - `scheduler_test.exs` but its `restart/2` describe, and `runtime_test.exs`'s M2-1
     messages but `restart/2`'s.
   - `configuration_test.exs`'s "start/1 checks again", `program.ex`'s doc, and CLAUDE.md's
     runtime entry.
   - Nothing is task-less in the interim, so no rule is landed and then reversed. Built:
     504 tests, green.
   - The spike's moduledoc and CLAUDE.md text already name `restart/2` here. The split
     cuts code and tests, not prose, and the landing removes those words until commit 4.
4. **`restart/2`** (RS-0…RS-6). The function and its tests: the `restart/2` describe, the
   one rule and plain data after a restart, and `restart/2`'s two messages. The surface
   pin gains `restart: 2`. Built: 509 tests, green.
5. **The contract walk** in `api_contract_test.exs`, with its reach. Built: 510, green.
6. **The Done-when end to end** (`end_to_end_test.exs`), with both README walks. Built:
   514, green. It adds no rule; its message reverts the rules it relies on.
7. **Documents** (§9).

If §13 Q-3 is answered (b), commit 4 is dropped, and so is more than commit 4:

- commit 5 loses the walk's restart operation and its model of a restart, and its
  `:mode` refusal kind;
- commit 6's README walks lose their restart steps, or restart through `start/1` plus a
  resend of the whole input image;
- the moduledoc's host-loop promise 1 loses "and after `restart/2`".

So (b) costs edits in 5 and 6, not one dropped commit (S-FIT-3's correction of S-synth's
Q-3).

Each of commits 2–4 carries its rows of §7.3 in its message, every rule reverted alone
and the commit's full suite judged by exit code.

---

## 9. Documents each commit stales

| Commit | README | CLAUDE.md | PLAN | organisation.md | naming.md |
|---|---|---|---|---|---|
| 0 | — | the `%Logex.Program{}` field list (CLAUDE.md:71) | — | — | — |
| 1 | — | — | M2-1's Done-when reworded if Q-21 is taken (PLAN:1297-1302), and M2-3's (PLAN:1325-1330); M2-5's Done-when kept as written (Q-22) | §7 decisions numbered once for S, F and T; §4.4's checks "with M2-1" and §6.2 (org:1377-1379); §4.6's API block gains `overlaps/1` and `restart/2`; §4.9's "One rule for new state" gains §4's table, with `Configuration.initial/1` beside `Program.initial_env/1` (S-FIT-1); §4.4's unconnected-input sentence (org:434-435) per `research.md` IEC-14 | — |
| 2 | — | Key Files gains `lib/logex/configuration.ex` (with `initial/1`); the tests line gains `configuration_test.exs` | — | — | — |
| 3 | the stage paragraph (`README.md:16-17`); the `call/4` sentence (`README.md:225-227`) | the `lib/logex/runtime.ex` entry; "New state" extended to `%Logex.Runtime{}` (§11 D-4); the tests line gains `scheduler_test.exs` | — | — | — |
| 4 | — | the runtime entry gains `restart/2` | — | §4.9's "Refused while running" notes a cold restart of the same configuration exists (org:858) | — |
| 5 | — | the `api_contract_test.exs` description gains the configuration walk | — | — | — |
| 6, 7 | a worked example of a configuration from Elixir, its output a real run | — | M2-1's status; §8 item 2 ("There is no loop", PLAN:2046-2049); a note that a configured plant is not edited until OE-2 (Q-32) | §4.6 and §6.2 marked landed; §4.9's "What Milestone 2 must keep" checked off | — |

---

## 10. What came from which design and judge

S-synth §10's table stands. This revision adds the following:

| Piece | From | Why |
|---|---|---|
| A name told what it is (IN-1d…g, GT-8) | rf-S-correct-F3 | one namespace and a named configuration; the configuration's name may equal a task's |
| Lists once (LO-1…LO-3) | rf-S-correct-F2 | size linear in the problems |
| Block type refused once (BT-1, BT-2) | X13 | S's own "one mistake, one message" |
| `Configuration.initial/1` and the one-rule section | S-FIT-1 | org:878-880 |
| The commit series, built | S-FIT-3 | OE-1's landing practice |
| GT-4b, GT-7 to M2-5 | S-FIT-8 | fix F12: tests within the contract |
| Growth with one task due (GR-2b, GR-5) | rf-S-correct-F1 | the stated variable measured |

---

## 11. Departures from decided rules

- **D-1. The §4.4 checks land with M2-1, not M2-2.** org §6.2 lists them under M2-2
  (org:1377-1379), and so does PLAN M2-2 (PLAN:1317). The spike lands every check that
  M2-1's data holds. No rule changes, only the item that lands it. §13 Q-1.
  - **And they are pinned from data, not source** (S-FIT-7). org §6.2's preamble says
    "every diagnostic is pinned by a test that asserts whole diagnostic lists from source,
    like `validation_test.exs`" (org:1356-1357). M2-1 has no source, so it asserts the
    lists from `new!/1` and `check/1` on structs.
  - The obligation passes to M2-2. It binds M2-2 on org §6.2's own wording, and §5 now
    records it.
- **D-2. Two functions beyond org §4.6's API block:** `overlaps/1` and `restart/2`. §13
  Q-2, Q-3.
- **D-3. `new!/1` raises every problem in one `ArgumentError`.** §13 Q-14.
- **D-4. CLAUDE.md's "New state in an instance" is extended** to `%Logex.Runtime{}`. §13
  Q-30.
- **D-5. A landed message changes** *(rev)*. When `put_inputs/3` or `call/4` refuses
  several undeclared keys, it now lists the var_inputs on the first such line only.
  - At `47319f7` every line listed them, which `runtime_test.exs`'s "key order holds past
    32 inputs" test pinned; that test is rewritten.
  - The change keeps one rule for every runtime refusal (LO-1). A message is a host's
    reading, and the contract pins it but promises it to no program.
  - It is listed because it changes M1-5's pinned text.

Readings to confirm, not departures:

- an output point takes no initial value (§13 Q-10);
- a first cycle after elapsed time reports the periods before it (§13 Q-5);
- an address may have any number of fields.

---

## 12. Risks

- **The walk's model restates the scheduler.** A misreading of §4.6 shared by the model
  and the code would pass. One oracle knows nothing of the scheduler, JS1's closed-form
  oracle agreed on S-synth, and the Done-when's output-order check is independent of both.
- **A plain `++` per scan is invisible to a growth test counted in reductions,** and so is
  a quadratic made only of BIF calls.
- **A cycle and `next_due_in/1` cost every declared task,** whatever runs
  (rf-S-correct-F1).
  - This is linear and pinned (GR-2b, GR-5). A plant with thousands of tasks of which
    few are due pays for all of them.
  - A queue keyed by `next_due` would make both O(log T), but nothing decided asks for
    one. It belongs in the runner's design if it is ever wanted.
- **A refusal's time is quadratic in its bad keys times its names** (rf-S-correct-F2's
  corrected claim): about 17x for 4x, from 1.1M to 329M reductions at 100 to 1600.
  - The cause is `Declarations.suggest/4`, which runs a Jaro pass per bad key, in
    `cycle/3`, `check/1`, and the landed `put_inputs/3` and `call/4` alike. Only host
    mistakes reach it.
  - Its size is now linear (GR-6). §13 Q-31.
- **Cost per scan.** `call/4` checks again at every scan, and `outputs/2` walks every tag
  (commit 0).
- **`Logex.Configuration.Task` shadows Elixir's `Task`** where a host aliases it (§13
  Q-28).
- **`warnings` is landed empty.** Only its key is pinned. M2-2 is the first to fill it
  (X12).
- **`get/2` at depth** is linear in the path. No growth test pins it, and none is owed
  unless FS-Q9(b) gives `get/2` real depth (X16).
- **A hand-built `%Logex.Program{}` inside a configuration** is checked only as a struct.
  Deeper junk is outside the contract, now including a block type with no output member
  (S-FIT-8).
- **Lists left off later diagnostics.** In an editor, the later diagnostics no longer
  carry the list that the first one gave. This is deliberate (LO-2), but a reader who
  jumps to line 12 sees no list there.
- **Restart re-anchors every task** (RS-2).

---

## 13. Decisions for the maintainer

Each question gives its options with their consequences, a recommendation and why, and
the item it must be decided before. "Built" marks what the spike does. **Cross-track**
marks a question that another track's design also asks. Each such question is stated
once here, with what each track would do, and the merged record must answer it once.

**Q-1. Do M2-1's data and checks hold globals, located points and connections, or only
tasks and instances?** (§11 D-1.) *Decide before commit 1.*
- (a) All of it in M2-1, with every §4.4 check its data can express (built). M2-2 adds
  text, words, line shapes, and the from-source assertions of these checks (S-FIT-7).
- (b) Tasks and instances only. M2-2 then reshapes data M2-1 landed.
- *Recommend (a).* T's design agrees (T §1.5, "this track's checks then become rows of
  S's `check/1`").

**Q-2. How does a host read a task's overlap count?** *Before commit 3.*
- (a) `Runtime.overlaps/1` (built). (b) Events only. (c) Kept, unread.
- *Recommend (a).*

**Q-3. Is there a restart of the resource in M2-1?** *Before commit 4.*
- (a) `restart/2`, `:cold | :warm`, keeping the clock and the input image (built; RS-0…6).
  Consequence: `scan/2` with `restart/3` and a one-instance configuration agree across a
  restart, with nothing resent.
- (b) None: `start/1` is the cold restart, and the host resends its whole input image.
  Consequence: commit 4 is dropped, and commits 5 and 6 lose their restart operations
  and steps or rewrite them over `start/1` (§8; S-FIT-3).
- (c) Defer to the runner or OE-2.
- *Recommend (a).*

**Q-4. After `restart/2`, when is each task next due?** *Before commit 4.*
(a) At the next cycle (built). (b) Each keeps its `next_due`. (c) The next multiple from
0. *Recommend (a).*

**Q-5. What does the first cycle's elapsed time mean?** *Before commit 3.*
(a) Phases anchored at 0 (built). (b) Anchored at the first cycle. (c) `start/2`.
*Recommend (a).*

**Q-6. Does `next_due_in/1` count task-less instances?** *Before commit 3.*
(a) No (built). (b) 0 whenever one exists. *Recommend (a).*

**Q-7. One namespace for tasks, globals and program instances?** **Cross-track** (T Q-5,
agreed). *Before commit 2.* (a) One, case-only twins refused, first in line order keeps
a name (built). *Recommend (a).* The two tracks' words differ, and the words are Q-37.

**Q-8. The bounds of a task's interval and priority.** **Cross-track** (T Q-9).
*Before commit 2.*
- (a) Interval 1..2147483647 ms, priority 0..2147483647, the dint range (built here and in
  T).
- (b) A tighter priority bound: 0..31, as one family uses (`research.md` CDS-1), or 0..15.
  Relaxable later.
- (c) Unbounded: values no dint holds.
- *Recommend (a)*, and here is why priority is the exception to the reasoning of Q-7, Q-9,
  Q-11 and decision 7 (S-FIT-5). That reasoning refuses a value because it is probably a
  mistake or ambiguous, and keeps the refusal while relaxing it later breaks nothing.
  - An unconnected var_input, a second spelling of an address, or an empty configuration
    is probably a mistake.
  - A priority of 40 is not: it only orders tasks, holds no resource, and means one thing.
  - IEC types PRIORITY as an unsigned integer and states no bound (`research.md`: "Ed 3
    types PRIORITY as an unsigned integer").
  - Any tighter bound is one vendor's number, and they disagree (0..31, 0..15, 1..15),
    so picking one would be invented.
- T recommends (a) as well. S-synth's Q-8 recommended (a) while calling (b) safer, and
  this resolves that in (a)'s favour. If the maintainer applies decision 7's rule to every
  bound anyway, (b) with 0..31 is the widest tight bound with a precedent. Both tracks
  would then change one module attribute and one test each.
- Whichever is chosen, M2-3's `priority` stanza says that one family numbers the other
  way (SIE-1).

**Q-9. The location grammar.** **Cross-track** (T Q-8, agreed). *Before commit 2.* (a)
One-name device, lowercase `i`/`q`, whole-number fields with no leading zero (built).
*Recommend (a).*

**Q-10. May an output point take an initial value?** **Cross-track** (T Q-7, agreed).
*Before commit 2.* (a) Refused (built). *Recommend (a).*

**Q-11. Is a configuration with no program instance refused?** *Before commit 2.* (a)
Refused (built). *Recommend (a)*, since it can be relaxed later.

**Q-12. How does a configuration hold its program types?** *Before commit 2.* (a)
`programs:` a map in the struct, which `new!/1` builds from a list (built). *Recommend
(a).*

**Q-13. Does `start/1` check its configuration again?** *Before commit 3.* (a) Yes
(built). *Recommend (a).*

**Q-14. Does `new!/1` raise every problem, or the first?** **Cross-track** (agreed).
*Before commit 2.* (a) Every problem (built). *Recommend (a).*

**Q-15. Elements as structs, maps or tuples?** **Cross-track** (T C1, C4: T's tuples are
a stand-in for S's structs). *Before commit 2.* (a) A struct per kind (built).
*Recommend (a).*

**Q-16. The stage of a configuration problem.** **Cross-track** (T Q-3, agreed). (a)
`:configure`, attributed to `check/1` at M2-1 (X15). *Recommend (a).*

**Q-17. What may `get/2` read?** *Before commit 3.*
- (a) A global; any declared tag of an instance; a public member of a block instance,
  through `FbType.member/2`, as deep as the public members reach (built). Never an
  internal member, an instance whole, a task, the configuration, or a member of a scalar.
- (b) var_inputs, var_outputs and public members only.
- (c) (a) plus task state under task names.
- *Recommend (a).* How deep a path can reach is M2-5's FS-Q9 (X16).

**Q-18. Where does an overlap event sit within a cycle's events?** *Before commit 3.* (a)
Just before its own task's scans (built). *Recommend (a).*

**Q-19. Must a configuration have a name?** *Before commit 2.* (a) Yes (built).
*Recommend (a).*

**Q-20. Lines: from Elixir, their order, and a bad one.** **Cross-track** (merges S-synth
Q-20 and T Q-21; X9). *Before commit 2 (S) and T's commit 3.* Three parts:
1. *Order.* (a) S's CF-4: positive or nil, in any order (built). (b) T's R48: all nil, or
   strictly rising. With (b) the data path refuses an order no file gives, and the
   printer's round trip is exact. With (a) the round trip compares "but for lines".
2. *A line from Elixir:* both tracks refuse one, but with different words.
   S: ``task `t1` from Elixir has no line, got: 3`` (one line per element). T: "an entry
   built in Elixir has no line: a line is where a configuration file declares an entry,
   got: <entry>". In T the message also depends on check order: lines [3, nil] gave
   "comes after line 3".
3. *A bad line in `check/1`:* S gives a `:configure` diagnostic, and T raises
   `ArgumentError` (H9).
- *Recommend:*
  - for part 1, (b), taking T's reason: it makes the data API refuse exactly what the text
    cannot say (org:779-780). S's (a) is built only because it was there first;
  - for part 2, S's per-element form, since it names the element;
  - for part 3, a diagnostic, since `check/1` is total over the struct's fields (Q-37's
    error mode).
- What each track would do: S adds R48 as a `check/1` rule with a diagnostic; T drops H9
  and H13 for S's messages.

**Q-21. Should M2-1's Done-when say how the clock is stepped?** *Before commit 1.* (a)
"cycled every 10 ms from 0 to 990 ms" (100, 34 and 100 runs), and M2-3's likewise.
*Recommend (a).*

**Q-22. The order of the milestone.** **Cross-track** (merges S-synth Q-22 and F FS-Q16;
X5). *Before commit 1.*
- (a) M2-1 first, then M2-5 before M2-2 (decision 1's default for M2-1; decision 1 allows
  M2-5 to move).
  - PLAN's and org's M2-5 Done-when (PLAN:1345, org:1408) stays as written, `m1.s2.run`
    read through M2-1's `get/2`. That is F's own FS-Q1(b).
  - With M2-5 before M2-2, T's reader, loader and walks are written against `cal` from
    their first commit.
- (b) M2-5 first, then M2-1 (F's FS-Q16 and inventory §11). M2-5's Done-when must be
  reworded (FS-Q1(a)). F argues that this settles the nested state and the edit changes
  while OE-1 is fresh.
- The code does not choose between them. S+F conflict in the same three files, one hunk
  each, in either order, and the union passes 559 tests. T needs M2-1 before its own
  items either way.
- *Recommend (a)*, because it keeps the decided text unchanged. It is not the only order
  consistent with all three tracks (X5's correction). F recommends (b), and T is
  neutral.

**Q-23. When OE-2 changes a task's interval, what becomes of its `next_due`?**
**Cross-track** (merges S-synth Q-23 and T Q-16; S-FIT-4, X7). *Before OE-2's design pass;
M2-3's documents state the answer.*
- (a) `min(next_due, now + new interval)` (T's recommendation). A shorter interval takes
  effect within one new period, and a longer one runs once more on the old phase. Neither
  adds a run at the switch.
- (b) Keep `next_due`; the next run steps by the new interval (S-synth's
  recommendation).
  - No run is added or lost at the switch.
  - But a shortened interval takes effect only when the old period runs out. The worst
    case is the whole old interval: in S-FIT-4's probe, a 60000 ms task changed to 10 ms
    at 20 ms ran 0 times in the next 1000 ms. Under (a) it ran 100 times.
- (c) The next multiple of the new interval from the anchor. This may run early or skip.
- (d) Re-anchor at the switch: an extra run, or a gap.
- *Recommend (a)*, now in both tracks. It bounds the wait by the new interval and adds
  no run, which (b) does not. S-synth recommended (b) without stating (b)'s delay.

**Q-24. `Configuration.compile`'s argument order, and `new!`'s shape.** **Cross-track**
(merges S-synth Q-24 and T Q-19). *Before M2-2.*
- (a) org:470's `compile(name, source, programs)`, as decided, beside S's `new!(keyword)`.
- (b) `compile(source, programs, name: name)`, mirroring `Logex.compile/2`. This changes
  decided text.
- *Recommend (a)* with S's `new!/1`, as T recommends. S-synth recommended (b) for
  consistency, but the difference is cosmetic, and (a) keeps the decided text. T's
  `new!/3` is a stand-in.

**Q-25. Does M2-2 owe a printer from `%Configuration{}` to the file?** **Cross-track** (T
builds one, R49). (a) Yes, with a round trip. *Recommend (a).*

**Q-26. Does M2-1 reserve OE-2's generation counter?** (a) OE-2 adds it. *Recommend (a).*

**Q-27. Does M2-1's data path refuse the configuration file's words before the text
exists?** (a) No; each text item reserves its words (built). *Recommend (a).*

**Q-28. Keep the name `Logex.Configuration.Task`?** (a) Keep it. *Recommend (a).*

**Q-29. Land `warnings` on the configuration now, empty?** *Before commit 2.*
- (a) Yes (built). M2-2 is the first to fill it (W1, W2), then M2-3 (W3), M2-4 (W4, W5)
  and M2-6 (W6), per T's plan. No struct reshapes later.
- (b) M2-2 adds it.
- *Recommend (a).*

**Q-30. How does CLAUDE.md's "New state" rule apply to `%Logex.Runtime{}`?** *Before
commit 3.* (a) A value from `start/1` and a rule for a cycle, `restart/2` and OE-2's
switch, held in `Configuration.initial/1` and the moduledoc's one-rule section (built).
*Recommend (a).*

**Q-31. May a refusal take time quadratic in its bad keys?** *(new; rf-S-correct-F2.)*
*Before commit 3.*
- The size is now linear. The time is not: `Declarations.suggest/4` runs a Jaro pass over
  every name for each bad key, so a refusal costs bad keys × names. This is about 17x
  for 4x, from 1.1M to 329M reductions at 100 to 1600, in `cycle/3`, `check/1`,
  `put_inputs/3` and `call/4` alike.
- (a) Accept it and say so in the moduledoc (not built). Only host mistakes reach it, and
  no decided text bounds a refusal.
- (b) Cap the did-you-mean work: suggest only for the first k bad keys of one refusal,
  then list once. This bounds the time by k × names, but a host's later mistakes get no
  did-you-mean.
- (c) Index the names once per refusal, for example by first letter or length, to prune
  the Jaro pass. This keeps every did-you-mean, but adds code to a path only mistakes
  take.
- *Recommend (a)*: the cost is a host's own mistake's, and is paid once.

**Q-32. Is it accepted that a configured plant cannot be edited until OE-2?** *(new;
S-FIT-2.)* *Before commit 3.*
- The gap follows from decided rules: OE-2 comes after Milestone 2 (PLAN:1488), and the
  runtime is opaque and changes only through the API (org:885). The moduledoc now says so.
- (a) Accept it, and note it in PLAN M2-1 and the README's "Changing a running program"
  (the documents commit).
- (b) An interim per-instance hook into a resource. This is an extension that needs its
  own case against org:885's opacity, not an equal option.
- *Recommend (a).*

**Q-33. May OE-2 change a program instance's type?** *(new; S-FIT-9.)* *Before OE-2's
design pass.*
- org:868-870 allows adding and removing instances while running, and state is keyed by
  name. So removing `m1` (a `motor`) and adding `m1` (a `pump`) in one edit cannot be told
  apart from changing `m1`'s type.
- (a) Refuse a type change, as org:860 refuses a tag's. This narrows "adding and
  removing instances" for one name in one edit, so the host makes two edits.
- (b) Allow it as a remove plus an add: the old instance is pruned and the new one
  started by `Runtime.instance/1`.
- *Recommend (b)*: it is what §4.9's allowed list already says, and the start rule
  exists. S-synth's table proposed (a) without asking.

**Q-34. Does OE-2 report a kept global whose `initial` changed?** *(new; S-FIT-9.)*
*Before OE-2's design pass.*
- Decision 29 reports a tag's changed initial value as `:initial_changed`. The maintainer
  chose to report it, against the recommendation (org:1573-1581).
- (a) Report a global's the same way, as one rule for two kinds of state.
- (b) Say nothing: a global's value is the plant's, not a program's.
- *Recommend (a)* for one rule, but it extends decision 29 to globals, so it is the
  maintainer's call.

**Q-35. Restarting one instance inside a resource; and where `%Logex.Runtime{}` lives.**
*(new; S-FIT-10; inventory Q1.21, Q1.26.)* *Before commit 3.*
- (a) No per-instance restart in M2-1. `restart/2` restarts the whole resource, as the
  moduledoc now says (built). The struct lives in `Logex.Runtime`, its API module, as
  `%Logex.Edit{}` does in `Logex.Edit`, so `__struct__/0,1` are on the pinned surface
  (built; main's runtime_test.exs:706-708 is the precedent).
- (b) Add `restart(rt, instance, mode)`. That is one more rule for the input image and
  the tasks, for a need no decided text states.
- (c) Put the value in its own module, `Logex.Resource`. That gives two modules for one
  concept, against `Logex.Edit`'s precedent.
- *Recommend (a).*

**Q-36. Commit 0: a field on `%Logex.Program{}`, or none?** *(new; S-FIT-11.)* *Optional,
before commit 0 if it is taken.*
- (a) Not built: an `outputs` field, with `call/4` refusing an `outputs` that disagrees
  with `tags`. That is a public struct change, a new pinned message, and about 16% off
  `call/4` for the motor.
- (b) Not built: keep the list in `wiring`, derived by `start/1`, with a private scan that
  takes it. No public change, and only configurations gain.
- (c) Neither: accept `outputs/2`'s walk of every tag.
- *Recommend (b)* if the cost matters, otherwise (c). Commit 0 is independent of M2-1.

**Q-37. One `Logex.Configuration` for S and T: the words, the granularity, and the error
mode.** **Cross-track** (X2, X10; merges T Q-20). *Before T's commit 4 ports its checks
into `check/1`.*
1. *Words.* Where both tracks check one rule, the messages differ. Examples: the
   namespace, the interval, the priority, an output point's initial value, one address,
   an unknown task, a second source, and no program instance.
   - S keeps four of org §4.4's receipt lines word for word (with ": one connection drives
     a global" added to one). T keeps three and rewords four (X10's correction).
   - T recommends that the configuration file's words win, rule by rule. *Recommend the
     same.* The text is the saved form, and S has no stake in its own words.
2. *Granularity of an unconnected var_input.*
   - (a) One diagnostic per member (S's CF-26, built). Each is a fix, and each fix
     removes one.
   - (b) One per instance, listing its members (T's C37, T1-Q18). Shorter for a fresh
     instance.
   - The diagnostic counts differ, and both are pinned. *Recommend (b)*, as T and its
     judge do, now that S lists names once anyway.
3. *A host mistake in the configuration's name or programs.*
   - S's `check/1` returns it as a diagnostic, total over the struct's fields.
   - T's `check/3` raises `ArgumentError` (H1, H4).
   - *Recommend S's form.* `check/1` is the one validator for a struct a host may build
     by hand, and `new!/1` and `start/1` raise its diagnostics anyway.
- What each track would do: T's checks become rows of S's `check/1`, in T's words, with
  T's granularity. The `Logex.Configuration` surface pin in `runtime_test.exs` is
  rewritten once: a textual merge keeps S's and T's pins side by side, cleanly, and
  cannot pass (X2).

**Q-38. Who owns fix F15?** **Cross-track** (X18). *Before the first item that meets it.*
- (a) The first item that needs a file on a program or block. Under Q-22(a) that is M2-5,
  whose R68 stamps a block file's diagnostics with that file.
- (b) M2-2, as S-synth and T said. M2-5 then works around it with its own convention.
- *Recommend (a)*, stating both conventions together: F's R68 (the block's file in the
  `file` field) and T's R51 (a configuration diagnostic names a type's file in its text).

**Q-39. One message for a block type given as a program.** **Cross-track** (X13). *Before
M2-5.*
- Three wordings exist:
  - F's R8/R9 (`Runtime.instance/1`, `Edit.accept/3`): "`seal` is a function block type,
    which runs inside a program through `cal`: an instance is of a %Logex.Program{}";
  - S's BT-2 (`check/1`, `new!/1`): "the program under `seal` is `seal`, a function block
    type, which runs inside a program: a program instance is of a %Logex.Program{}";
  - T's generic programs-map message (`compile/3`), with its loader crashing (X1).
- (a) F's words at every entry point, with the configuration's prefix "the program under
  `<key>` is" kept where the key and the name differ. One mistake, one message, in no
  more than one shape.
- *Recommend (a).* S's interim words leave out `cal` only because `cal` does not exist
  before M2-5.

### Cross-track agreements (X19), carried into the design record

| Topic | S | T | F | Refinement |
|---|---|---|---|---|
| One namespace | Q-7 | Q-5 | — | words differ (Q-37) |
| Stage `:configure` | Q-16 | Q-3 | — | attributed to M2-1 (X15) |
| Output point initial value refused | Q-10 | Q-7 | — | — |
| Location grammar, no leading zero | Q-9 | Q-8 | — | — |
| Interval and priority bounds | Q-8 (a) | Q-9 (a) | — | S now argues (a) explicitly (S-FIT-5) |
| G2, one copy of a global | §5 M2-4 | Q-10 | — | — |
| Event trigger across restart and edit | §5 M2-6 | Q-15 | — | T also refuses adding or removing an event task's `interval`; §5 now says so |
| `new!` raises every problem | Q-14 | R61 | — | arity: S's `new!/1` keyword form (Q-24) |
| `var_external` refused in a block | — | Q-18 | §5 | — |
| B5's one IR walk before M2-4 | §5 M2-4 | commit 12 | FS-Q23 | — |
