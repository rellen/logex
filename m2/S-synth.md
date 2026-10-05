# S-synth — M2-1, the scheduler from Elixir data: the merged design

Label: S-synth. Track S, `PLAN.md` M2-1. Written 2026-10-02 against `/home/user/logex` at
`47319f7` (main, 2026-10-01), which was not modified (`git -C /home/user/logex status
--short` is empty). The spike was built in a fresh copy, `scratchpad/m2/S-synth-work`,
starting from S2's patch as the base and porting what this document takes from S1, S3 and
the two judges. Its diff is `scratchpad/m2/S-synth.patch`; the mutation driver and its log
are `scratchpad/m2/S-synth-mutation.py` and `scratchpad/m2/S-synth-mutation.jsonl`; every
other probe and receipt is in `scratchpad/m2/S-synth-probe/`. Every `mix` run was on
Elixir 1.20.4 / OTP 28 (the scratchpad toolchain) and is judged by its exit code.

**Citations.** `org` is `docs/organisation.md`, `PLAN` is `PLAN.md`, both at `47319f7`. A
bare `file:line` is the repository at `47319f7`; `spike:file` is the file in
`S-synth-work` (cited by function name where line numbers would move). `S1.md`, `S2.md`,
`S3.md`, `JS1.md`, `JS2.md`, `inventory.md`, `readiness.md` and `research.md` are the
pass's own documents in `scratchpad/m2/`. Rule labels (`CF-n`, `NW-n`, `RT-n`, `CY-n`,
`EV-n`, `IN-n`, `NX-n`, `GT-n`, `RS-n`, `PD-n`, `ST-n`, `GR-n`) and question labels
(`Q-n`) are this document's own. Like the inventory's, they must never be cited in `lib/`,
`test/` or `CLAUDE.md` (`test/logex/edit_test.exs` enforces it); the spike cites none.
"Unverified" marks what was not checked.

---

## 0. Summary

- **Base: S2**, the winner of both judges (JS1 8.5, JS2 8). Its validator is the only
  total one, it alone serves M2-2 with lines and a file, and it keeps the decided overlap
  count. Both judges agree on the base, so there was nothing to break a tie on.
- **Grafted:** S3's `restart/2`, which keeps the clock and the input image (built: the
  judges differ only on whether to build it now, §13 Q-3); S1's seeded README walk, now
  with restarts on both sides; S3's refusal of a line from Elixir; S3's 16x growth step;
  shuffled names and worked order tests, past 32 keys; S3's host-loop text; a required
  configuration name; a plain-data test.
- **Fixed:** every defect the judges reproduced on S2 (JS1 D1–D5, JS2 items 1–5), and three
  more this pass found: a junk `file` on a hand-built configuration crashed `start/1` with
  `Protocol.UndefinedError` (S2 had it too: `S-synth-probe/file_junk.exs`); `get/2` of a
  block with no public member gave a junk message from `and_list([])`; and `get/2` of an
  instance of a program with no tag gave "as in `m.`".
- **Gate:** passes three times, 500 tests (7 doctests), up from 430 (§6). PLAN M2-1's
  Done-when is three passing tests in `end_to_end_test.exs`, plus a timed fourth.
- **Mutation table:** 101 rules reverted one at a time in a scripted table (§7.2).

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
  warnings:    [%Logex.Diagnostic{severity: :warning}]  # empty in M2-1; M2-4 is the first to fill it
}

%Logex.Configuration.Task{name:, interval: pos_integer, priority: non_neg_integer, line: nil | pos_integer}
%Logex.Configuration.Global{name:, type: :bool | :dint, initial: nil | non_neg_integer, at: nil | String.t(), line:}
%Logex.Configuration.Instance{name:, type: program_name, task: nil | task_name, line:}
%Logex.Configuration.Connection{instance:, member:, to: global_name | non_neg_integer, line:}

Logex.Configuration.new!(keyword)  :: %Logex.Configuration{}         # ArgumentError: every problem, a line each
Logex.Configuration.check(config)  :: [%Logex.Diagnostic{stage: :configure}]
Logex.Configuration.location(at)   :: {:ok, {device, "i" | "q", [non_neg_integer]}} | :error
```

- `new!/1` takes `name:`, `programs:` (a **list** of `%Logex.Program{}`, keyed by each
  program's name), `tasks:`, `globals:`, `instances:` and `connections:`. An element from
  Elixir has no `line` (NW-3). It raises one `ArgumentError` whose message is its own
  problems, then `check/1`'s errors, each formatted by `Logex.Diagnostic.format/1`, one per
  line.
- `check/1` is the one validator, total over any value in any field. It returns
  diagnostics at stage `:configure`, at the element's line in the configuration's file, in
  line order, a problem with no line last. M2-2's reader builds the same structs with lines
  and a file and calls it; nothing reshapes.
- `location/1` is public because the wall-clock runner routes points by device and address
  (org §4.5, org:514-516).
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

- `instance/1`, `call/4`, `put_inputs/3`, `scan/2,3` and `restart/3` are unchanged. A scan
  inside a cycle is `call/4` with the instance's copy-in, then its copy-out; `start/1`
  builds every instance with `instance/1` (fix F14) and `restart/2` restarts each with
  `restart/3`, so the lone instance and the resource share one constructor and one
  restart.
- `start/1`, `cycle/3`, `next_due_in/1` and `get/2` are org §4.6's decided signatures
  (org:675-678). `overlaps/1` and `restart/2` are two additions (§11 D-2).
- The struct's fields: `config`, the configuration; `now`; `globals`, one value per global
  (the input points' values are the input image); `instances`, each `%Logex.Instance{}`
  by name; `tasks`, `%{next_due:, overlaps:}` by task name; `wiring`, what `start/1`
  derives once from the configuration (tasks in declaration order with their instances,
  the task-less instances, each instance's type and connections in and out, the input
  points' types, the output points' names, the globals by name). `wiring` is not state.

### 1.3 `Logex.Diagnostic`

`@type stage` gains `:configure` (`spike:lib/logex/diagnostic.ex`), and the moduledoc says
`line` is nil for a `:configure` problem of an element built from Elixir or of the
configuration as a whole.

### 1.4 The host's loop (the `Logex.Runtime` moduledoc, from S3)

A runner sleeps `next_due_in/1` ms (or less, when it paces task-less instances or watches
for an input change), reads its devices into an input map, calls `cycle/3` with the time
that really passed, and writes the outputs back. What it may rely on, each pinned (§7):
the first cycle runs at once; late is reported, never replayed; inputs are a delta;
outputs are a snapshot; events are a log and an open set; a cycle is a function of its
arguments, so a recorded run replays exactly; a host mistake raises `ArgumentError` and
nothing else escapes.

---

## 2. The rules, numbered

Every rule below is built in the spike and has a mutant in §7.2 unless the row says
otherwise.

### 2.1 Building from Elixir (`new!/1`)

- **NW-1** `new!/1` takes a keyword list, a proper one with atom keys; anything else raises
  the "takes a keyword list" message alone, since nothing can be built.
- **NW-2** No unknown field, and none given twice.
- **NW-3** An element from Elixir has no `line`: a line is where a configuration file
  declares the element, and every message that cites one relies on that, as
  `Logex.Declarations.validate!/1` refuses a line on a tag from Elixir
  (`lib/logex/declarations.ex:125-134`). (From S3; JS1 D2.)
- **NW-4** The element is checked without the line it brought: one mistake, one message.
- **CF-3c** `programs:` is a list of programs, each name once.
- **CF-3d** An unnamed program is refused as unnamed: an instance names its program.

### 2.2 The configuration (`check/1`, the one validator)

- **CF-1** Every name of a task, global or program instance, and the configuration's own,
  is a name (`Declarations.name?/1`).
- **CF-2** Tasks, globals and program instances share one namespace. **CF-2b** The first to
  take a name **in line order** keeps it, so in a file the later line is refused, citing
  the earlier one's line, whatever part each is in. **CF-2c** A name differing only in case
  is refused, as tags' are. A program type is named in type position only, so `program
  motor motor` is not a clash.
- **CF-3a** A program is under its own name. **CF-3b** A program's name is a name.
- **CF-4** A line is a positive integer or nil. **CF-4b** Each part is a proper list of
  its element struct: an improper tail is refused like any non-list (fix F8's rule for a
  host's lists, org:1608-1609).
- **CF-5** A task's interval is 1 to 2147483647 ms. **CF-6** Its priority is 0, the
  highest, to 2147483647.
- **CF-7** A global is `:bool` or `:dint`. **CF-8** Its initial value fits its type.
  **CF-9** It is not negative (no line can say one until a negative literal lexes).
- **CF-10a** An input point takes no initial value. **CF-10b** Nor does an output point:
  the line shape `var_global <n> <type> at <dev>.q.<k>` has no place for one (org:414),
  and the data API refuses what the text cannot say (org:779-780).
- **CF-11** A location is `<device>.i.<address>` or `<device>.q.<address>`, one token to
  the lexer, the device a name, `i` or `q` lowercase. **CF-11b** Its address is one or more
  whole numbers **with no leading zero**, the leftmost the highest level, so an address
  has one spelling. (Changed from S2, which compared fields as numbers so that
  `panel.i.00` was `panel.i.0`; S1 and S3 refused the leading zero. §13 Q-9.)
- **CF-12** One address holds one global.
- **CF-13** A program instance's type is a program of the configuration (with a
  did-you-mean, or the list). **CF-14** Its task, if any, is a task of the configuration.
- **CF-15** A connection names a declared program instance; one whose instance is declared
  but cannot run is not checked again.
- **CF-16** …and a member its program declares (a dotted member "goes too deep").
- **CF-17** …and only a var_input or a var_output.
- **CF-18** A var_input is connected once. **CF-19** …to a global of its type. **CF-20**
  …or to a constant that fits it.
- **CF-21** A connection's instance and member are names; its `to` a name or an integer of
  0 or more.
- **CF-22** A var_output drives a global, never a constant. **CF-23** …never an input
  point. **CF-24** …of its type. **CF-25** One connection at most drives a global; a
  var_output may drive several globals, and an output point may be read back.
- **CF-26** Every var_input is connected (decision 7), each missing one cited at its
  instance's line.
- **CF-27** A configuration runs at least one program instance.
- **CF-28a** Diagnostics are in line order, those with no line last. **CF-28b** Each is
  stamped with the configuration's `file`. **CF-28c** Each is at stage `:configure`.
- **CF-29a** A junk instance name is never offered as a did-you-mean. **CF-29b/c** A
  connection to a global whose type CF-7 refused is not checked again, input or output.
- **CF-30** A configuration has a name (IEC's CONFIGURATION is named; S1, S3 and T1's
  `compile/3` require one; JS2 graft 6).
- **CF-31** A configuration's `file` is a string or nil; a junk one is refused and the
  rest cited in no file. (Found by this pass: S2's `start/1` raised
  `Protocol.UndefinedError` formatting a hand-built configuration whose `file` was a map
  and which had any other problem.)

### 2.3 Starting (`start/1`)

- **RT-1** `start/1` takes a `%Logex.Configuration{}` and runs `check/1` again; any error
  raises one `ArgumentError`, every problem formatted, a line each. A configuration is the
  data API, built or edited by hand by design, so it stays inside the contract (decision
  28's full entry check is the precedent, org:1559-1572).
- **RT-2** Each instance is built with `Runtime.instance/1` (fix F14), so its first scan is
  a first scan.
- **RT-3** `now` is 0; every global is at its initial value, 0 without one; every task is
  due at 0 ("anchored at start", org:556) with an overlap count of 0.

### 2.4 A cycle (`cycle/3`), in order (org:546-583)

- **CY-0** The checks, in order: the runtime, `elapsed_ms`, the inputs.
- **CY-1** `now` advances by `elapsed_ms`, a non-negative integer.
- **IN-1a** `inputs` is a map keyed by input-point name: an output point or an unlocated
  global is refused as such. **IN-1b** A path into an instance is refused as one. **IN-1c**
  A key that is not a string is refused as one. An unknown name gets a did-you-mean or the
  list.
- **IN-2** Each value fits its point's type exactly, with `call/4`'s messages.
- **IN-3** Every input problem in one raise, a line each, in key order; a refused cycle
  changes nothing.
- **CY-2** The inputs merge into the input points, which keep their values between cycles.
- **CY-3** A periodic task is due when `next_due <= now`.
- **CY-4** Due tasks run by priority, the lower number first (**a**); then the earlier
  `next_due` (**b**); then declaration order (**c**, reversed; **d**, by name).
- **CY-5** A task that runs moves `next_due` to `next_due + (missed + 1) * interval`,
  `missed = div(now - next_due, interval)`, so the phase never drifts.
- **CY-6** `missed > 0` emits `{:overlap, task, missed}` (**a**) and adds `missed` to the
  task's count (**b**).
- **CY-7** Task-less instances run after every due task (**a**), once in every cycle, an
  elapsed-0 one included (**b**). A task's instances run in declaration order (**c**, by
  name; **d**, reversed), and so do the task-less ones (**e**, by name; **f**, reversed).
- **CY-8** A scan copies each connected var_input in, from a constant (**a**) or its
  global's current value (**b**), runs `call/4` with `%Scan{now: now, first:
  state.first}`, and copies each connected var_output out to its global at once (**c**).
- **CY-9** The outputs are every output point after every scan, never an unlocated global.
- **CY-10** A task with no instance is still scheduled, counted and reported; it runs no
  scan. (No line implements it apart: an empty instance list. No mutant.)
- **EV-1** One `{:ran, task, instance, now}` per scan, `task` the task's name or `:none`.
  **EV-2** Each `{:overlap, …}` comes just before its task's scans (§13 Q-18). **EV-3**
  The kinds are an open set (org:887); a host ignores a kind it does not know. (A
  documented promise, not code: no mutant.)

### 2.5 Reading

- **NX-1** `next_due_in/1` is the soonest `next_due` minus `now` (**b**), ignoring
  task-less instances, `:infinity` with no task (**a**). It is 0 after `start/1` and after
  `restart/2`, and above 0 after every cycle.
- **NX-2** `overlaps/1` is each task's overlap count, by name, since `start/1` or
  `restart/2`.
- **GT-1** `get/2` reads a global, an instance's declared tag (a `var` included), or a
  public member of a function block instance at any depth, through `FbType.member/2`, so
  never an internal member.
- **GT-2** An instance named whole is refused. **GT-3** A path past a bool or a dint is
  refused. **GT-5** A path is one name token to the lexer.
- **GT-4** A block instance named whole is refused with an example: its first output
  member (**a**), else its first public member, else none (**b**). **GT-6** An instance of
  a program with no tag is refused saying it declares none. **GT-7** A missing member of a
  block with no public member says it has none. (GT-4b, GT-6 and GT-7 are this pass's;
  JS2 item 4 found GT-4's crash, and the other two are the same defect in two more places.)

### 2.6 Restarting (`restart/2`, from S3)

- **RS-0** The runtime is checked, then the mode: `:cold` or `:warm`, with `restart/3`'s
  message; `:warm` is `:cold` until `retain` exists.
- **RS-1** Every overlap count goes to 0.
- **RS-2** Every task is due at the next cycle: `next_due` is the kept `now`, so the phase
  is re-anchored at the restart, as `start/1` anchors it at 0.
- **RS-3** The input image is kept: an input point keeps its value, as `restart/3` keeps an
  instance's var_inputs, so that `scan/2` with `restart/3` and a one-instance configuration
  agree across a restart with nothing resent (org:686-688; JS1 D1).
- **RS-4** Each instance restarts through `restart/3`: every tag back at its initial value
  but the var_inputs, its next scan a first scan.
- **RS-5** Every other global goes back to its initial value, 0 without one (an output
  point to 0).
- **RS-6** The clock is kept: time never goes backwards for an instance.

### 2.7 The value itself

- **PD-1** A `%Logex.Runtime{}` holds plain data only: no function, pid, reference or port,
  at start, after cycles and after a restart (org:874; JS2 graft 7).
- **ST-1** Every call checks its runtime first. A `%Logex.Runtime{}` built or edited by
  hand is outside the contract; a `%Logex.Configuration{}` is not (RT-1).
- **ST-2** Every call is a function of its arguments: made twice, it gives the same result.
  (No one-line mutant makes a function impure; the contract walk makes every accepted call
  twice.)
- **GR-1** A cycle is linear in the instances it runs, measured at 16x (JS2 graft 1).
  **GR-2** …and in the tasks due, at 4x. **GR-3** `check/1`, so `new!/1` and `start/1`, is
  linear in the configuration, at 4x. **GR-4** `start/1`'s own part is linear, at 4x.

---

## 3. Every message, exact

`<x>` is a value: a name in backticks when it is a string, else `inspect`ed. `<where>` is
` (line N)` for an element with a line, else empty.

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

The first is raised alone. The rest are followed by `check/1`'s errors in the same
message.

### 3.2 `check/1`'s diagnostics (stage `:configure`)

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
task `<n>` has line <inspect>: a line is a positive integer, or nil for one built from Elixir   (also: global, program instance, the connection of)
<inspect> cannot name a task: a name is a letter or `_`, then letters, digits or `_`          (also: a global, a program instance)
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
program instance `<n>`: there is no program `<t>`<hint>      hint: " — did you mean `x`?" | ": the programs are `a` and `b`" | ": this configuration has no program"
program instance `<n>`: its type is a program's name, found <inspect>
program instance `<n>`: there is no task `<t>`<hint>         (": the tasks are …" | ": this configuration has no task")
program instance `<n>`: its task is a task's name, or nil for none, found <inspect>
`<i>.<m>`: there is no program instance `<i>`<hint>         (": the program instances are …")
`<i>` is a `<type>`, which declares no `<m>`<hint>          (" — did you mean …?" | ": its var_inputs and var_outputs are …" | ": it has no var_input or var_output")
`<i>.<m>` goes too deep: a connection names a var_input or var_output of a program instance, as in `<i>.start`
`<i>.<m>` is internal to `<type>` (declared `<section>`): only a var_input or var_output connects
a connection's instance and member are names, as in `m1.start`, found <inspect> and <inspect>
`<i>.<m>` is already connected, to <`g` | constant><where>: a var_input is connected once
`<i>.<m>` is connected to `<g>`, which is not a global<hint> (": the globals are …")
`<i>.<m>` is a <type>, but `<g>` is a <type><where>
`<i>.<m>` is a bool: only 0 or 1 fit, found `<v>`
`<i>.<m>` is a dint: `<v>` does not fit in 32 bits
`<i>.<m>` is connected to <inspect>: a connection's other end is a global, by name, or a constant of 0 or more
`<i>.<m>` is a var_output: it drives a global, and a constant cannot be driven
`<g>` is an input point<where>: `<i>.<m>` cannot drive it
`<g>` is already driven by `<i>.<m>`<where>: one connection drives a global
`<i>.<m>` is not connected: every var_input is connected, to a global or a constant
a configuration runs at least one program instance
expected a %Logex.Configuration{}, got: <inspect>              (raised by check/1 itself, for a non-configuration)
```

Four of the configuration spike's seven messages (org:452-460) are kept word for word but
for the trailing rule, as S2.md §5.2 records; "unknown configuration line" is M2-2's
reader's.

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
input `<k>` is not an input point<hint>       (" — did you mean `x`?" | ": the input points are `a`, `b` and `c`" | ": this configuration has no input point")
input `<k>` is a bool: only 0 or 1 fit, found <v>                                             (call/4's)
input `<k>` is a dint: its value must be an integer, found <inspect>                          (call/4's)
input `<k>` is a dint: <v> does not fit in 32 bits                                           (call/4's)
<inspect> is not an access path: a global, or a program instance, its tag and the members below it, joined by `.`, as in "m1.t1.acc"
`<h>` is neither a global nor a program instance<did-you-mean>
`<path>` goes too deep: `<g>` is a <type> global, which has no members
`<i>` is a program instance, a `<type>`: an access path names one of its tags, as in `<i>.<first tag>`
`<i>` is a program instance, a `<type>`: an access path names one of its tags, and it declares none
`<i>` is a `<type>`, which declares no `<tag>`<did-you-mean>
`<path>` goes too deep: `<i>.<tag>` is a <type>, which has no members
`<at>` is a <block type>: an access path names one of its members, as in `<at>.<first output, else first public member>`
`<at>` is a <block type>: an access path names one of its members, and it has none a path can name
`<at>.<m>` is not a member of `<at>`, a <block type><hint>    (" — did you mean …? (members are case-sensitive)" | ": its members are `pre`, `acc`, `dn`, `tt` and `en`" | ": it has no member a path can name")
`<path>` goes too deep: `<at>.<m>` is a <type>, which has no members
```

---

## 4. Each new piece of state across an online edit

CLAUDE.md's rule (CLAUDE.md:166-173 at `47319f7`) is written for a field of
`%Logex.Instance{}`. M2-1 adds none to `%Logex.Instance{}` or `%Logex.Scan{}`. Its state
is in the opaque `%Logex.Runtime{}`, which no host hands in, so a field gets no
entry check with a pinned message; it gets a value from `start/1` and a rule for a
cycle, for `restart/2` and for OE-2's switch, with the edit's exceptions listed. The spike's
CLAUDE.md says so (§11 D-4).

| Piece | `start/1` (the one rule) | `cycle/3` | `restart/2` | OE-2 switch: kept | OE-2: added | OE-2: removed |
|---|---|---|---|---|---|---|
| `now` | 0 | `+ elapsed_ms` | kept | never touched | — | — |
| an input point's value | 0 | the input merge | kept (RS-3) | kept, same name and type | refused while running: located I/O (org:860-863) | refused while running |
| an output point's value | 0 | the copy-out of its driver | 0 (RS-5) | kept; an output point no connection drives any more holds its value and is reported held (decision 20, org:852-856) | refused while running | refused while running |
| an unlocated global's value | `initial` or 0 | copy-out | `initial` or 0 (RS-5) | kept; a changed `initial` is reported, as decision 29 reports a tag's | `initial` or 0, the one rule | kept unused at test, pruned at assemble |
| — a global's type, `at` | — | — | — | a change refused at accept (org:860-863) | — | — |
| `instances[i]` | `Runtime.instance/1` (F14) | that instance's `call/4` | `restart/3` (RS-4) | moved by `Logex.Edit`'s per-instance switch for its type's plan (F5, org:924-929) | `Runtime.instance/1`: `first` true, so its first scan holds back its `ons`, as at start | kept at test, pruned at assemble; every global it drove holds its value and is reported held |
| — an instance's `type` | — | — | — | a change refused (proposed for OE-2) | — | — |
| — an instance's `task` | — | — | — | a change refused (decision 19, org:864) | — | — |
| `tasks[t].next_due` | 0 | CY-5 | the kept `now` (RS-2) | kept; an interval change keeps it and the next run steps by the new interval (§13 Q-23) | refused until verified (decision 19, org:866-867) | refused until verified |
| `tasks[t].overlaps` | 0 | `+ missed` | 0 (RS-1) | kept | — | — |
| `config` | the configuration | — | kept | the candidate's at test, the original's at untest | | |
| `wiring` | derived | — | kept (derived from the same `config`) | rebuilt from the configuration switched to | | |

Inside a resource each `%Logex.Instance{}` keeps OE-1's rules unchanged: `first` set by
`instance/1` and `restart/3`, cleared by a scan; `ons_blocked` and `switched` stay `[]` and
false, because nothing in M2-1 switches an instance, and `call/4` clears both at every
scan. An instance's `now` is the resource's `now` at its last scan, so an instance on a
slow task lags the clock, and `call/4`'s "time went backwards" check cannot fire, because
the resource's `now` only grows and `restart/2` keeps it (RS-6).

The edit's exceptions (org:879-880) do not grow in M2-1. A connection is not state: an
added var_input connection takes effect at the instance's next copy-in (decision 22
foresaw it, org:1528-1530); a removed var_output connection leaves its global holding its
value. The `restart/2` column is a cold restart of the same configuration. §4.9's
"restart, which may keep values by name" (org:858) that applies a change an edit refuses
takes a candidate, and is OE-2's to design on top of it.

---

## 5. What each later item and OE-2 add

Nothing below reshapes a struct M2-1 lands or reverses one of its rules. Each item adds
text, a field with a default, or a rule.

- **M2-2 · the configuration file.** `Logex.Configuration.compile/3` lexes and parses with
  `Logex.Lexer`/`Logex.Parser` as `Logex.Declarations` does (no golden-record change,
  `readiness.md` §6), maps each line to one element struct by its first word with its
  `line`, sets `file` and `name`, and calls `check/1`. Its own diagnostics at stage
  `:configure` are the line shapes (unknown line word, missing or extra word, a branch
  group, `with` before M2-3). It reserves `program var_global at bool dint` in `.lcf`
  (org:1378) with their `docs/naming.md` stanzas; CF-1 then grows "and not a configuration
  keyword", so the data path refuses a name the text cannot say. It owes fix F15 (a `file`
  on `%Logex.Program{}`, set by `compile_file/1`), the loader resolving `motor` to
  `motor.ld` beside the `.lcf`, `compile_file/1` refusing anything but `.ld`
  (PLAN:1321-1324), and a printer with a round-trip test (§13 Q-25). Warnings, if any (an
  unused global, a task with no instance), go to `warnings`.
- **M2-3 · periodic tasks in text.** `task <n> interval <ms> priority <p>` and `program …
  with <task>` build `Task` and `Instance.task`, which exist from M2-1. Its words, `task
  interval priority with`, need four stanzas; `priority`'s must say Siemens numbers the
  other way (`research.md` SIE-1). Its acceptance counts (100 and 20) are M2-1's scheduler
  at 10 ms steps from 0 to 990 ms (§13 Q-21).
- **M2-4 · shared globals.** `var_external` becomes a section; a public "which tags a
  program writes" (one IR walk, `readiness.md` §4.1). `check/1` gains: each `var_external`
  has a global of its name and type; one the program writes is not bound to an input
  point; two writers is a warning in `config.warnings`, which M2-1 lands empty (inventory
  C5). The scan step puts each external's global value into the instance's env before
  `call/4` and writes it back after, so between scans the only copy is in `globals`
  (org:886). `get/2` reads `m1.estop` as the global.
- **M2-5 · user function blocks.** Nothing in the configuration or the scheduler. `get/2`
  already walks a member whose type is a `%Logex.FbType{}` at any depth through
  `FbType.member/2`, and GT-4b, GT-6 and GT-7 already give a total message for a block
  with no output or no public member, which M2-5's types may have. M2-5 owes `get/2` a
  growth test in depth and decides what `FbType.public/1` returns for `:local`; `get/2`
  follows. Not run: no nested user block type exists at `47319f7`, so `m1.s2.run` through
  `get/2` is unverified (JS1 §9).
- **M2-6 · event tasks.** `Task` gains `single: nil | global_name`, and `:interval` leaves
  its `@enforce_keys`. CF-5 becomes "an interval of 1 to 2147483647 ms, or a `single`, or
  both"; a new rule: `single` names a bool global. Each event task's state gains `last: 0`:
  0 at `start/1` (a trigger already 1 fires in the first cycle, org:559-566), 0 at
  `restart/2`, kept by OE-2, a changed `single` refused. `cycle/3` samples triggers after
  the input merge; `next_due_in/1` ignores event-only tasks. The `ton`-in-an-event-task
  warning goes to `config.warnings`.
- **OE-2.** Instances, globals and tasks are lists of named structs, compared by name. A
  plan per program type serves every instance of it. A generation counter is OE-2's to add
  to the opaque struct (§13 Q-26). A restart that keeps values by name and takes a
  candidate builds on `restart/2`'s rules. Editing during M2 is not possible: the runtime
  is opaque, so `Logex.Edit` cannot reach an instance inside it; the moduledoc says so.

---

## 6. Spike receipts

**Gate,** three times on the final spike, each command judged by its exit code
(`S-synth-probe/gate-1.log`, `gate-2.log`, `gate-3.log`):

| Run | `mix format --check-formatted` | `mix compile --force --warnings-as-errors` | `MIX_ENV=test mix compile --force --warnings-as-errors` | `mix test --warnings-as-errors` |
|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 0, `Result: 500 passed (7 doctests, 493 tests)` |
| 2 | 0 | 0 | 0 | 0, `Result: 500 passed (7 doctests, 493 tests)` |
| 3 | 0 | 0 | 0 | 0, `Result: 500 passed (7 doctests, 493 tests)` |

At `47319f7` the suite is 430 tests (6 doctests).

**Patch.** `git add -A && git diff --cached HEAD` in `S-synth-work`, saved as
`S-synth.patch`; `git apply --check` against a fresh copy of `47319f7`: exit 0 (on a fresh clone of `/home/user/logex` at `47319f7`, deleted after).
Ten files: `lib/logex/configuration.ex` (new), `lib/logex/runtime.ex`,
`lib/logex/diagnostic.ex`, `lib/logex/program.ex` (doc only), `CLAUDE.md`, and five test
files (`configuration_test.exs` and `scheduler_test.exs` new; `runtime_test.exs`,
`end_to_end_test.exs`, `api_contract_test.exs`). Test count 430 → 500: +31
`configuration_test.exs`, +25 `scheduler_test.exs`, +8 `runtime_test.exs`, +4
`end_to_end_test.exs`, +1 `api_contract_test.exs`, +1 doctest.

**Done-when, as the spike runs it** (`S-synth-probe/done_when.exs`, output
`done_when.out`; the tests assert the same):

```
one second, cycles at 0, 10, ..., 990: f (10 ms) 100, s (30 ms) 34, n (task-less) 100
events at 0: [{:ran, "slow", "s", 0}, {:ran, "fast", "f", 0}, {:ran, :none, "n", 0}]
events at 10: [{:ran, "fast", "f", 10}, {:ran, :none, "n", 10}]
overlaps: %{"fast" => 0, "slow" => 0}
late cycle at 525: overlaps [{:overlap, "fast", 1}]; events there [{:ran, "slow", "s", 525}, {:overlap, "fast", 1}, {:ran, "fast", "f", 525}, {:ran, :none, "n", 525}]
after it: [{:ran, "fast", "f", 530}, {:ran, :none, "n", 530}] then [{:ran, "slow", "s", 540}, {:ran, "fast", "f", 540}, {:ran, :none, "n", 540}]
overlaps/1: %{"fast" => 1, "slow" => 0}, next_due_in: 10
```

The 30 ms task (priority 0) is declared after the 10 ms task (priority 1), with the
task-less instance between them, so neither declaration order nor rate gives the order
priority does; the test also reads the order from the outputs alone (an input sampled by
the 30 ms instance into a global the 10 ms instance copies out in the same cycle).

The README clause (`end_to_end_test.exs`): the README motor through `put_inputs/3` and
`scan/2` and through a one-instance configuration, over the README's 7 steps and 300
seeded steps with 9 cold and 5 warm restarts of both sides (`restart/3` and `restart/2`);
and M2-3's timed motor through `scan/3` and `cycle/3` over 302 steps, 5,980 ms of elapsed
time and 5 cold and 13 warm restarts (`S-synth-probe/readme_walk.out`). Outputs equal at
every step, and `m.fault` and `m.t1.acc` equal through `get/2`.

**The judges' probes, rerun on the spike** (`S-synth-probe/js1/*-Ssynth.out`,
`S-synth-probe/js2/probe-Ssynth.log`; JS1's adapter's restart now calls `restart/2`):
- `restart_min`: `scan/2 %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
  configuration %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}` (S2 gave
  `"motor" => 0`).
- `readme`: 0 mismatching steps of 3,000 with no resend after a restart (S2: 708).
- `newjunk`: every case an `ArgumentError`; `task line given` now refused.
- `handbuilt`: 2,999 refused, 1 accepted, 0 escaped of 3,000.
- `sched_fuzz` seed 1: 400 configurations × 60 cycles, 0 mismatches against JS1's
  closed-form oracle.
- JS2's `contract_probe`: 0 escapes of 4,000 junk calls and of 2,000 hand-built structs;
  `get/2` of a block with only an internal member, with no member, and with no output now
  each a pinned `ArgumentError` (S2: `FunctionClauseError`); `panel.i.00` refused; no name
  refused.

**Growth,** ten VMs, the least of three reduction counts each (`S-synth-probe/growth.exs`,
`growth-receipt.txt`): a cycle 4.11x–4.14x for 4x the tasks (bound 6); a cycle
16.55x–16.66x for 16x the instances (bound 19.5); `start/1` 4.07x–4.11x for 4x (bound 6);
`check/1` 4.06x–4.11x for 4x (bound 6).

**The contract walk** passed under its own seed and ten others it was not tuned on
(`S-synth-probe/walk-seeds.txt`: {1,2,3}, {7,7,7}, {2026,10,2}, {11,22,33}, {99,1,5},
{4,4,4}, {123,456,789}, {5,6,7}, {8,9,10}, {31,41,59}).

---

## 7. Test plan and mutation table

### 7.1 Where each rule is pinned

| Test file | What it pins |
|---|---|
| `configuration_test.exs` (31 tests, the `location/1` doctest) | NW-1…NW-4, CF-1…CF-31, each as a whole list of formatted messages from `new!/1` or `check/1`; lines and file with a configuration built as M2-2's reader will build one (CF-28); the namespace in line order (CF-2b: an instance on line 6 and a global of its name on line 9, one diagnostic at line 9 citing line 6); an improper list in each part and as the keyword list (CF-4b, NW-1); two seeded properties: 3,000 spoiled `new!/1` calls and 2,000 configurations spoiled by hand, twice each, through `start/1` and a cycle, nothing but `ArgumentError` escaping; `check/1`'s growth |
| `scheduler_test.exs` (25 tests) | RT-2, RT-3, CY-1…CY-9, EV-1, NX-1, NX-2, ST-2, the input image, copy-in and copy-out, independence of two instances of one type; order of instances against name order and past 32 (CY-7c…f); `restart/2` (RS-1…RS-6) and a first scan after it; plain data (PD-1); growth (GR-1, GR-2, GR-4) |
| `runtime_test.exs` (+8) | §3.3's messages: `start/1`, `cycle/3` (CY-0, IN-1…IN-3), `next_due_in/1`, `overlaps/1`, `restart/2` (RS-0), `get/2` (GT-1…GT-7, the last three with a block type built by hand standing in for M2-5's, and a program with no tag); the public surface, `Logex.Runtime`'s and `Logex.Configuration`'s functions and the keys of the five structs |
| `end_to_end_test.exs` (+4) | PLAN M2-1's Done-when as three tests, and the timed program; both README walks with restarts (RS-3, RS-4 end to end) |
| `api_contract_test.exs` (+1) | a seeded walk: 150 configurations of 1–4 instances of four program types, 0–3 tasks, 11 globals (one with an initial value), random connections, 50 operations each, among them `restart/2` with good and bad modes; task and instance names drawn shuffled, so declaration order is not name order; every accepted call made twice; every refusal one of 19 documented kinds, each line of a multi-line refusal classified; outputs, events, overlaps, `next_due_in/1` and `get/2` of every global and every instance tag checked against a model that scans through `call/4` and restarts through `restart/3` alone and computes `next_due` from an anchor; one oracle that knows nothing of the scheduler (runs plus missed periods equal `div(now - anchor, interval) + 1`); reach asserted for all 19 refusal kinds and 16 behaviours |

### 7.2 The mutation table

Driver: `scratchpad/m2/S-synth-mutation.py`, run by `S-synth-probe/run-mutation.sh` in
three workers, each in its own copy of the spike. For each mutant it applies one exact
text replacement (which must match once), runs `mix compile --warnings-as-errors`, and, if
that exits 0, runs the whole suite with `mix test --warnings-as-errors`, recording the exit
code and the failing tests; then it restores the file, and at the end checks with `cmp`
that each copy's files are the spike's again. Log: `scratchpad/m2/S-synth-mutation.jsonl`
(one JSON object per mutant). Exit 2 is ExUnit's for a failing suite.

**Result: 101 mutants, every one compiled cleanly (`mix compile --warnings-as-errors`
exit 0), every one red.** 100 exit 2; NX-1a exits 3, because its mutant also makes a test
file draw a type warning (comparing `0` with `:infinity`), which `--warnings-as-errors`
adds to the two failures (`S-synth-probe/nx1a.out`). No rule is red only through the
contract walk: each has a worked test too (CONTRIBUTING.md's warning that a property
restating a rule cannot catch that rule's defect).

How the table was reached, so its count can be trusted:
- A first run with literal mutants (`true`, `nil`, `false` passed to a multi-clause
  private function) did not compile cleanly under Elixir 1.20's type checker, which warns
  that the other clause is never used (`S-synth-probe/mutation-discovery.jsonl`). Those
  mutants pass `Process.get(:logex_mutant, <literal>)` instead, which the checker cannot
  see through and which returns the literal.
- In the final run (`S-synth-probe/mutation-run1.jsonl`) nine mutants' first forms still
  did not compile cleanly (an unused helper or variable): CF-20, CF-21, CF-28a, CF-28b,
  RT-1, IN-1a, IN-1b, GT-2, GT-3. Each was rewritten to keep every name used and rerun
  alone (`S-synth-probe/mut-rerun.jsonl`); the merged log marks them. None was counted in
  its uncompilable form.
- The three workers' copies were checked with `cmp` against the spike after the run.

| Rule | Reverted alone | compile | mix test | Red in | First failing tests |
|---|---|---|---|---|---|
| NW-1 | new!/1 takes a keyword list | 0 | 2 | ConfigurationTest | nothing escapes an improper list, in any part or as the keyword list, is an ArgumentError; new!/1's own refusals a keyword list, and nothing else |
| NW-2 | new!/1: no unknown field, none given twice | 0 | 2 | ConfigurationTest | new!/1's own refusals a keyword list, and nothing else |
| NW-3 | new!/1 refuses an element from Elixir that brings a line | 0 | 2 | ConfigurationTest | new!/1's own refusals an element from Elixir has no line |
| NW-4 | new!/1 checks such an element without its line (one mistake, one message) | 0 | 2 | ConfigurationTest | new!/1's own refusals an element from Elixir has no line |
| CF-3c | new!/1: two programs of one name refused | 0 | 2 | ConfigurationTest | new!/1's own refusals programs: a list of named programs, each named once |
| CF-3d | new!/1: an unnamed program refused as unnamed | 0 | 2 | ConfigurationTest | new!/1's own refusals programs: a list of named programs, each named once |
| CF-1 | a name is a name | 0 | 2 | ConfigurationTest | names tasks, globals and program instances share one namespace, case-only twins refused, and a name is a name |
| CF-2 | one namespace: a name taken twice is refused | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order; names, in a file the later line is refused, citing the earlier |
| CF-2b | the namespace is taken in line order | 0 | 2 | ConfigurationTest | names, in a file the later line is refused, citing the earlier |
| CF-2c | a case-only twin is refused | 0 | 2 | ConfigurationTest | names tasks, globals and program instances share one namespace, case-only twins refused, and a name is a name |
| CF-3a | a program is under its own name | 0 | 2 | ConfigurationTest | check/1 programs are a map of named programs, each under its own name |
| CF-3b | a program's name is a name | 0 | 2 | ConfigurationTest | check/1 programs are a map of named programs, each under its own name |
| CF-4 | a line is a positive integer or nil | 0 | 2 | ConfigurationTest | check/1 a line is a positive integer, or nil |
| CF-4b | each part is a proper list (fix F8) | 0 | 2 | ConfigurationTest | check/1 each field is a list of its element struct, a proper one; nothing escapes an improper list, in any part or as the keyword list, is an Argument… |
| CF-5 | an interval is 1..2147483647 | 0 | 2 | ConfigurationTest | nothing escapes start/1 refuses a configuration spoiled by hand, raising nothing else; new!/1's own refusals an element from Elixir has no line |
| CF-6 | a priority is 0..2147483647 | 0 | 2 | ConfigurationTest | tasks an interval is 1 to 2147483647 ms, and a priority 0 to 2147483647 |
| CF-7 | a global is a bool or a dint | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-8 | an initial value fits | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-9 | an initial value is not negative | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-10a | an input point takes no initial value | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-10b | an output point takes no initial value | 0 | 2 | ConfigurationTest | globals a bool or a dint, its initial value fitting it, never negative, and none on a located global |
| CF-11 | a location is <device>.i\|q.<address> | 0 | 2 | ConfigurationTest | globals location/1 reads a location's parts; globals a location is a device, i or q, and an address, and one address holds one global |
| CF-11b | an address field has no leading zero | 0 | 2 | ConfigurationTest | globals a location is a device, i or q, and an address, and one address holds one global; globals location/1 reads a location's parts |
| CF-12 | one address holds one global | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order; globals a location is a device, i or q, and an address, and one addr… |
| CF-13 | an instance names a program | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance; nothing escapes start/1 refuses a configuration spoiled by hand, raising nothing el… |
| CF-14 | an instance's task is declared | 0 | 2 | ConfigurationTest | program instances name a program, and a task if any |
| CF-15 | a connection names a declared instance | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance; nothing escapes start/1 refuses a configuration spoiled by hand, raising nothing el… |
| CF-16 | a connection names a declared member | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance |
| CF-17 | only a var_input or var_output connects | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance |
| CF-18 | a var_input is connected once | 0 | 2 | ConfigurationTest | connections a var_input is connected once, to a global of its type or a constant that fits; lines and the file each problem is cited at its line, in i… |
| CF-19 | a var_input's global is of its type | 0 | 2 | ConfigurationTest | connections a var_input is connected once, to a global of its type or a constant that fits |
| CF-20 | a constant fits its var_input | 0 | 2 | ConfigurationTest | connections a var_input is connected once, to a global of its type or a constant that fits |
| CF-21 | a connection's instance and member are names | 0 | 2 | ConfigurationTest | connections name a var_input or var_output of a declared instance; nothing escapes check/1 and new!/1 give a diagnostic or an ArgumentError, never any… |
| CF-22 | a var_output drives no constant | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-23 | a var_output never drives an input point | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it; lines and the file each problem … |
| CF-24 | a var_output's global is of its type | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-25 | one connection drives a global | 0 | 2 | ConfigurationTest | connections a var_output drives a global of its type, never an input point, and is the one connection that drives it |
| CF-26 | every var_input is connected (decision 7) | 0 | 2 | ConfigurationTest | connections every var_input is connected (decision 7), cited at its instance; program instances name a program, and a task if any |
| CF-27 | at least one program instance | 0 | 2 | ConfigurationTest, RuntimeTest | a resource's host contract (M2-1) start/1 takes a configuration, checked again; program instances at least one |
| CF-28a | problems in line order | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order |
| CF-28b | problems carry the configuration's file | 0 | 2 | ConfigurationTest | names, in a file the later line is refused, citing the earlier; lines and the file each problem is cited at its line, in its file, in line order |
| CF-28c | a problem's stage is :configure | 0 | 2 | ConfigurationTest | lines and the file each problem is cited at its line, in its file, in line order |
| CF-29a | a junk instance name is never offered as a did-you-mean | 0 | 2 | ConfigurationTest | nothing escapes check/1 and new!/1 give a diagnostic or an ArgumentError, never anything else; nothing escapes a global of a refused type, or an insta… |
| CF-29b | a var_input to a global of a refused type is not checked again | 0 | 2 | ConfigurationTest | nothing escapes start/1 refuses a configuration spoiled by hand, raising nothing else; nothing escapes a global of a refused type, or an instance of a… |
| CF-29c | a var_output to a global of a refused type is not checked again | 0 | 2 | ConfigurationTest | nothing escapes a global of a refused type, or an instance of a junk name, is reported once, and a junk name is never offered as a did-you-mean; nothi… |
| CF-30 | a configuration has a name | 0 | 2 | ConfigurationTest | check/1 a configuration has a name, and it is a name |
| CF-31 | a configuration's file is a name or nil | 0 | 2 | ConfigurationTest | nothing escapes start/1 refuses a configuration spoiled by hand, raising nothing else; check/1 a configuration's file is a name, or nil |
| RT-1 | start/1 checks the configuration again | 0 | 2 | ConfigurationTest, RuntimeTest | a resource's host contract (M2-1) start/1 takes a configuration, checked again; check/1 a configuration's file is a name, or nil |
| RT-2 | start/1 builds each instance as instance/1 (F14) | 0 | 2 | ApiContractTest, SchedulerTest | start/1 builds each instance as instance/1 does: its first scan is a first scan; a resource refuses every host mistake with a documented ArgumentError… |
| RT-3 | every task is due at start | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | due tasks and their order task-less instances run last, once in every cycle, an elapsed 0 one included, where a periodic task runs once per period; th… |
| CY-0 | the runtime is checked before elapsed_ms | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) every call takes a runtime from start/1, checked first |
| CY-1 | time advances by elapsed_ms | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; due tasks and their order task-less instances run last, once in every cycl… |
| CY-2 | the input image persists between cycles | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | the input image keeps each input point's value between cycles: a host sends only what changed; restart/2 starts the resource again, keeping the clock … |
| CY-3 | a periodic task is due when its due time has come | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | due tasks and their order a higher priority, the lower number, runs before an earlier due time; missed periods are counted, not run again, and the pha… |
| CY-4a | due tasks by priority first | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | due tasks and their order a higher priority, the lower number, runs before an earlier due time; a resource refuses every host mistake with a documente… |
| CY-4b | then by the earlier due time | 0 | 2 | ApiContractTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; a resource refuses every host mistake with a docu… |
| CY-4c | then by declaration (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; a resource refuses every host mistake with a docu… |
| CY-4d | then by declaration (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | due tasks and their order of one priority, the earlier due time runs first, then the order declared; a resource refuses every host mistake with a docu… |
| CY-5 | the phase is kept: next due moves by whole intervals | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods are counted, not run again, and the phase is kept; due tasks and their order a higher priority, the lower number, runs before an earlie… |
| CY-6a | a missed period is reported | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods a task with no instance keeps its time and its count, and runs nothing; missed periods a first cycle after the start reports the period… |
| CY-6b | a missed period is counted | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods are counted, not run again, and the phase is kept; restart/2 starts the resource again, keeping the clock and the input image |
| CY-7a | task-less instances run after every due task | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | the order of instances in the order declared past 32 instances; due tasks and their order task-less instances run last, once in every cycle, an elapse… |
| CY-7b | task-less instances run in every cycle | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | the order of instances in the order declared past 32 instances; due tasks and their order task-less instances run last, once in every cycle, an elapse… |
| CY-7c | a task's instances in declaration order (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | a resource refuses every host mistake with a documented ArgumentError, accepts every call without one, and runs as its rules say; the order of instanc… |
| CY-7d | a task's instances in declaration order (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | the order of instances in the order declared past 32 instances; the order of instances a task's instances, and the task-less ones, run in the order de… |
| CY-7e | task-less instances in declaration order (mutant: by name) | 0 | 2 | ApiContractTest, SchedulerTest | the order of instances a task's instances, and the task-less ones, run in the order declared; the order of instances in the order declared past 32 ins… |
| CY-7f | task-less instances in declaration order (mutant: reversed) | 0 | 2 | ApiContractTest, SchedulerTest | the order of instances in the order declared past 32 instances; the order of instances a task's instances, and the task-less ones, run in the order de… |
| CY-8a | copy in: a constant | 0 | 2 | ApiContractTest, SchedulerTest | copy in and copy out a var_input tied to a constant reads it at every scan; a resource refuses every host mistake with a documented ArgumentError, acc… |
| CY-8b | copy in: a global's current value | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | start/1 builds each instance as instance/1 does: its first scan is a first scan; copy in and copy out an instance sees what an earlier one wrote in th… |
| CY-8c | copy out: a var_output to its global, at once | 0 | 2 | ApiContractTest, EndToEndTest, RuntimeTest, SchedulerTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; copy in and copy out a var_input tied to … |
| CY-9 | the outputs are the output points only | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | copy in and copy out a var_output drives every global it is connected to; an output point no connection drives stays 0; an unlocated global is never a… |
| EV-1 | a task-less scan is reported with :none | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | due tasks and their order task-less instances run last, once in every cycle, an elapsed 0 one included, where a periodic task runs once per period; th… |
| EV-2 | an overlap is reported just before its task's scans | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods a first cycle after the start reports the periods before it; missed periods are counted, not run again, and the phase is kept |
| IN-1a | only an input point is set: an output point or unlocated global refused | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-1b | a path into an instance is refused as one | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-1c | a key that is not a string is refused as one | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-2 | an input point's value fits it | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order; a resource refuses … |
| IN-3 | every input problem in one raise | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) only an input point is set, with a value that fits it, every problem in one raise, in key order |
| NX-1a | next_due_in is :infinity with no task | 0 | 3 | ApiContractTest, SchedulerTest | a resource refuses every host mistake with a documented ArgumentError, accepts every call without one, and runs as its rules say; next_due_in/1 is :in… |
| NX-1b | next_due_in is the soonest task | 0 | 2 | ApiContractTest, SchedulerTest | next_due_in/1 is when a periodic task is next due, never a task-less instance; a resource refuses every host mistake with a documented ArgumentError, … |
| NX-2 | overlaps/1 reads each task's count | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | missed periods a task with no instance keeps its time and its count, and runs nothing; missed periods are counted, not run again, and the phase is kep… |
| GT-1 | get/2 never reads an internal member | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; a resource refuses every host mistake wit… |
| GT-2 | get/2 refuses an instance named whole | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; get/2 of an instance whole names one of i… |
| GT-3 | get/2 refuses a path past a bool or a dint | 0 | 2 | ApiContractTest, RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else; a resource refuses every host mistake wit… |
| GT-4a | a whole block's example is an output member first | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else |
| GT-4b | else any public member, else none | 0 | 2 | RuntimeTest | a resource's host contract (M2-1), the rest get/2 names a block's member as its example: an output, else any, else none |
| GT-6 | an instance whole: one of its tags as the example, else none | 0 | 2 | RuntimeTest | get/2 of an instance whole names one of its tags, or says it declares none |
| GT-7 | a block with no public member says so when a member is not found | 0 | 2 | RuntimeTest | a resource's host contract (M2-1), the rest get/2 names a block's member as its example: an output, else any, else none |
| GT-5 | an access path lexes as one name token | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) get/2 reads a global, a tag or a public member, and refuses anything else |
| RS-0 | restart/2 checks the runtime, then the mode | 0 | 2 | RuntimeTest | a resource's host contract (M2-1) every call takes a runtime from start/1, checked first |
| RS-1 | restart/2 zeroes every overlap count | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-2 | restart/2 makes every task due at the next cycle | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-3 | restart/2 keeps the input image | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-4 | restart/2 restarts each instance through restart/3 | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 each instance's next scan is a first scan; restart/2 starts the resource again, keeping the clock and the input image |
| RS-5 | restart/2 puts every other global back at its initial value | 0 | 2 | ApiContractTest, SchedulerTest | restart/2 starts the resource again, keeping the clock and the input image; a resource refuses every host mistake with a documented ArgumentError, acc… |
| RS-6 | restart/2 keeps the clock | 0 | 2 | ApiContractTest, EndToEndTest, SchedulerTest | restart/2 each instance's next scan is a first scan; restart/2 starts the resource again, keeping the clock and the input image |
| PD-1 | a runtime is plain data | 0 | 2 | SchedulerTest | plain data a runtime holds nothing but plain data, at start, after cycles and a restart |
| GR-1 | a cycle is linear in the instances it runs (an event list rebuilt per scan) | 0 | 2 | SchedulerTest | growth a cycle stays linear in the instances it runs |
| GR-2 | a cycle is linear in the tasks due | 0 | 2 | SchedulerTest | growth a cycle stays linear in the number of instances, tasks and connections |
| GR-3 | check/1 (so new!/1 and start/1) is linear in the instances | 0 | 2 | ConfigurationTest, SchedulerTest | growth check/1 stays linear in the configuration's size; growth start/1 stays linear in the configuration's size |
| GR-4 | start/1 is linear in the instances (its own part) | 0 | 2 | SchedulerTest | growth start/1 stays linear in the configuration's size |


### 7.3 Rules no test can see, and why

- **CY-10** (a task with no instance keeps its schedule): no line implements it apart; it
  is a task whose instance list is empty. Pinned by `scheduler_test.exs` ("a task with no
  instance keeps its time and its count") and by the walk, but no one-line revert exists.
- **EV-3** (events are an open set): a promise to the host, in the moduledoc; there is no
  code to revert.
- **ST-1** (a hand-built runtime is outside the contract): a statement of scope. The entry
  check every call makes (`runtime!/1`) is CY-0's and RS-0's rows.
- **ST-2** (a call is a function of its arguments): no one-line edit makes a pure function
  impure without adding a clock or a process, which PD-1's mutant does and which the
  plain-data test catches; the walk makes every accepted call twice.
- **Limits a reductions count cannot see** (§12): a plain `events ++ [event]` per scan
  (JS2 M14) and a quadratic made only of BIF calls (S1's G-build). GR-1…GR-4's mutants use
  Elixir-level work (`Enum.reverse/1`, `Enum.count/2`, `Enum.map/2`), which is counted.

---

## 8. Landing order, as commits, each green

M2-1 has no syntax: **no commit adds a word to any language, so none owes a
`docs/naming.md` stanza, none reserves a word, and none breaks a tag.** The words a
configuration needs (`program var_global at bool dint`, then `task interval priority
with`, `var_external`, `single`) are M2-2's, M2-3's, M2-4's and M2-6's, each surveyed in
its own commit (§13 Q-27). `Logex.Configuration.Task` and the other element modules are
Elixir names, not language words.

0. *(Optional, independent.)* The compiler lists a program's var_outputs once and
   `outputs/2` reads the list (`readiness.md` §1.7: the motor's `call/4` 277 → 233
   reductions), with a growth test. A cycle pays `outputs/2` once per scan.
1. **The design record.** The maintainer's answers to §13 into org §4.4/§4.6/§6.2 and PLAN
   M2-1, appended to org §7 as decisions 30 onward (the labels test requires every
   decision number cited in `lib/` or `test/` to be defined there first). Documents only.
2. **`Logex.Configuration` and the `:configure` stage.** The structs, `check/1`, `new!/1`,
   `location/1`, `configuration_test.exs` with its two properties and its growth test; the
   surface test gains `Logex.Configuration`. Nothing runs a configuration yet. Carries the
   NW-, CF- rows of the mutation table.
3. **The resource, task-less.** `%Logex.Runtime{}`, `start/1` (RT-1…RT-3), `cycle/3` with
   the input image and copy-in/copy-out for task-less instances (CY-0…CY-2, CY-7b, e, f,
   CY-8, CY-9, IN-, EV-1), `get/2` (GT-), plain data (PD-1); their messages in
   `runtime_test.exs`; the scheduler tests that need no task; GR-4.
4. **Periodic tasks.** CY-3…CY-7d, EV-2, NX-1, NX-2 (`overlaps/1`), their tests, GR-1 and
   GR-2.
5. **`restart/2`** (RS-0…RS-6), its tests, and the README walk's restarts. Separate so the
   maintainer's answer to §13 Q-3 can drop it whole.
6. **The contract walk** in `api_contract_test.exs`, with its reach.
7. **The Done-when end to end** (`end_to_end_test.exs`). It adds no rule; its message
   reverts the rules it relies on, as OE-1 step 7 did.
8. **Documents** (§9).

Each of 2–5 carries its rows of the mutation table in its message, every rule reverted
alone and the full suite judged by exit code (CLAUDE.md, "A fix needs a test that fails
when the fix is reverted").

---

## 9. Documents each commit stales

| Commit | README | CLAUDE.md | PLAN | organisation.md | naming.md |
|---|---|---|---|---|---|
| 1 | — | — | M2-1's Done-when reworded to the clock it means, if Q-21 is taken (`PLAN.md:1297-1302`, and M2-3's at `PLAN.md:1325-1330`) | §7 decisions 30+; §4.4's checks "with M2-1" (org:470-475) and §6.2 (org:1377-1379: "The §4.4 checks" and "Adds `configuration_test.exs`" move to M2-1); §4.6's API block gains `overlaps/1` and `restart/2` (org:667-680); org:596's overlap count gets its reader; §4.4's unconnected-input sentence (org:434-435) and §8 (org:1699) corrected by `research.md` IEC-14, inferred: an unconnected program input keeps its initial value in IEC | — |
| 2 | — | Key Files gains `lib/logex/configuration.ex`; the tests line gains `configuration_test.exs` | — | — | — |
| 3 | the stage paragraph, "and a scheduler — the host calls one scan at a time" (`README.md:16-17`); the `call/4` sentence "which is what a scheduler will call" (`README.md:225-227`) | the `lib/logex/runtime.ex` entry (the resource, `start/1`, `cycle/3`, `get/2`); "New state in an instance" extended to `%Logex.Runtime{}` (§11 D-4); the tests line gains `scheduler_test.exs` | — | — | — |
| 4 | — | the runtime entry gains `next_due_in/1`, `overlaps/1` | — | — | — |
| 5 | — | the runtime entry gains `restart/2` | — | §4.9's "Refused while running" paragraph notes that a cold restart of the same configuration exists, and OE-2's restart takes a candidate (org:858) | — |
| 6 | — | the `api_contract_test.exs` description gains the configuration walk | — | — | — |
| 7, 8 | a worked example of a configuration from Elixir, its output a real run (CLAUDE.md: the README's examples are real) | — | M2-1's status, and §8 item 2 ("There is no loop", `PLAN.md:2046-2049`) | §4.6 and §6.2 marked landed; §4.9's "What Milestone 2 must keep" checked off item by item | — |

`lib/logex/program.ex`'s `initial_env/1` doc ("M2-1's `start/1` will start every
instance by it", `lib/logex/program.ex:32-33`) changes in commit 3; the spike already
carries it. The spike also carries commit 3's and 5's CLAUDE.md edits; README, PLAN and
organisation.md are left for the documents commit, as the brief allows.

---

## 10. What came from which design and judge

| Piece | From | Why |
|---|---|---|
| The whole base: structs with a `line`, `file`, `warnings`; public `check/1` returning `:configure` diagnostics in line order with ` (line N)` cross-references; `location/1`; `proper/4` over every host list; `start/1` re-checking; `overlaps/1`; the scheduler; `get/2` at any depth; the plant receipt | S2 | Winner of both judges (JS1 §6, JS2 §8) |
| `restart/2`: the clock and the input image kept, every task due at the next cycle, every count 0, each instance through `restart/3`, other globals to initial | S3 (SC-21…SC-25); JS1 graft 1 and D1; JS2 graft 4 | org:686-688's agreement between `scan/2` and a one-instance configuration across a restart |
| The README clause as a seeded walk of 300 steps and a timed walk | S1; JS1 graft 2; JS2 graft 5 | 7 steps was too few a guard against two runtimes drifting (org:682-683); restarts added both sides |
| An element from Elixir has no line (NW-3), message form `… from Elixir has no line, got: …` | S3; JS1 graft 3 and D2 | the `Declarations.validate!/1` rule |
| 16x growth step on the instances a cycle runs | S3 (GR-3); JS1 graft 4; JS2 graft 1 and item 3 | a 4x step cannot see a per-scan rebuild of the event list |
| Shuffled task and instance names in the walk; worked order tests against name order and past 32 keys | S3; JS1 graft 5 and D3; JS2 graft 3 | neither order can then pass for the other (CONTRIBUTING.md's 32-key warning) |
| The host-loop paragraph and its promises | S3; JS1 graft 6; JS2 graft 2 | the clearest statement of the contract a runner builds on |
| Q-21, rewording the Done-when's clock | S3 Q-20; JS1 graft 7 | all three designs read "one simulated second" as cycles at 0…990 ms |
| A required configuration name (CF-30) | S1, S3, T1; JS2 graft 6 and item 5 | relaxing later breaks nothing |
| Plain-data test (PD-1) | JS2 graft 7 and item 2 | §4.9's first must-keep had no test in any design |
| Namespace line-order test (CF-2b) | JS2 item 1 | S2's own rule had no test |
| `get/2` of a block with no output member (GT-4) | JS2 item 4 | crashed with `FunctionClauseError` in S2 |
| No leading zero in an address (CF-11b) | S1, S3 (against S2) | one spelling per address; relaxable later; §13 Q-9 |
| A junk `file` refused (CF-31), GT-6, GT-7 | this pass | found by probing the merged spike |
| Tests guarding improper lists (CF-4b, NW-1) and junk lines through `start/1` | JS1 D4, D5 | S1 and S3 regressed there; S2 passed and now has the tests |
| **Not taken:** S3's initial value on an output point; S3's OE-2 rule letting located I/O be added or removed while running; S3's namespace checked by part; S1's dropped overlap count; S1's unchecked `start/1` | JS1 §6, JS2 §8 | against org:414 with org:779-780; against org:858-863; cites the wrong line; against org:596; against decision 28's precedent |

---

## 11. Departures from decided rules

- **D-1. The §4.4 checks land with M2-1, not M2-2.** org §6.2 lists "The §4.4 checks" and
  "Adds `configuration_test.exs`" under M2-2 (org:1377-1379), and PLAN M2-2 "every
  `var_input` connected, one driver per sink" (PLAN:1317). The spike lands every check on
  data M2-1 holds (CF-10…CF-27) with M2-1. No rule changes, only the item that lands it.
  Argued: copy-in needs a source and copy-out a sink, so M2-1's data holds globals and
  connections; a constructor from Elixir data "runs the same checks" (org:474-475); and a
  data path that accepted what M2-2's text then refuses would break hand-built plants,
  which is decision 7's reasoning. All three designs and both judges agree. §13 Q-1.
- **D-2. Two functions beyond org §4.6's API block** (org:669-680): `overlaps/1`, the
  reader of the decided overlap count (org:596, decision 11's "counted", org:1484), and
  `restart/2`. An extension, not a contradiction; without `overlaps/1` the decided count is
  state no test can observe. §13 Q-2, Q-3.
- **D-3. `new!/1` raises every problem in one `ArgumentError`,** where org:474-475 says the
  constructor runs the same checks "as `Tag.new!/4` does", and `Tag.new!/4` raises the
  first (`lib/logex/declarations.ex:140-141`). The reading here is that the clause is about
  running the same checks, not the error mode; listed in case the maintainer reads it the
  other way. §13 Q-14.
- **D-4. CLAUDE.md's "New state in an instance" is extended** (CLAUDE.md:166-173): a field
  of the opaque `%Logex.Runtime{}` gets a value from `start/1` and a rule for a cycle,
  `restart/2` and OE-2's switch, not an entry check with a pinned message, because no host
  hands one in. The spike's CLAUDE.md says so. §13 Q-30.

Readings to confirm, not departures: an output point takes no initial value (org:414 with
org:779-780; §13 Q-10); a first cycle after elapsed time reports the periods before it
(org:556 read literally; §13 Q-5); an address may have any number of fields (org:498-499,
"the integer fields").

---

## 12. Risks

- **The walk's model restates the scheduler.** It computes `next_due` from an anchor, not by
  CY-5's formula, and one oracle (runs plus missed periods) knows nothing of the scheduler,
  and JS1's closed-form oracle agreed over 24,000 more cycles; but a misreading of §4.6
  shared by all would pass. The Done-when's output-order check is a third, independent
  guard.
- **A plain `++` per scan is invisible to any growth test counted in reductions**
  (JS2 M14): `++` is a BIF, charged little for what it copies. GR-1 catches the
  `Enum.reverse(… ++ …)` form; the plain form is a limit to record beside CONTRIBUTING.md's
  note on `++`. So is a quadratic made only of BIF calls (S1's G-build).
- **Cost per scan.** `call/4` checks the program, state, scan and inputs again at every
  scan (about 12%, `readiness.md` §1.6), and `outputs/2` walks every tag (commit 0). A
  configuration multiplies both by its instances. Linear, measured.
- **`Logex.Configuration.Task` shadows Elixir's `Task`** where a host aliases it. The spike
  never aliases it (§13 Q-28).
- **`warnings` is landed empty**: no M2-1 rule fills it, so no test pins a value in it,
  only its key (the surface test). M2-4 is the first to fill it (§13 Q-29).
- **`get/2` at depth** is linear in the path, but no growth test pins it until M2-5 gives
  it depth.
- **Messages that inspect a configuration or a runtime** print the whole value, programs
  included: long but correct.
- **M2-4's one copy is sketched, not spiked** (§5). It changes the scan step, not
  `call/4`'s contract.
- **`configuration.ex` is about 1,160 lines**, most of it the validator's messages. M2-2's
  reader belongs in a module beside it.
- **A hand-built `%Logex.Program{}` inside a configuration** is checked only as a struct
  with a map of tags and a list of rungs; deeper junk is outside the contract, as a
  hand-built program given to `call/4` is (`lib/logex/runtime.ex:42-43`).
- **Restart re-anchors every task** (RS-2): a host that restarts and then cycles a whole
  interval later sees an overlap, as after `start/1` (Q-5). Consistent, and stated.

---

## 13. Decisions for the maintainer

Each: the question, 2–4 options with their consequence, a recommendation and why, and the
item it must be decided before. "Built" marks what the spike does.

**Q-1. Do M2-1's data and checks hold globals, located points and connections, or only
tasks and instances?** (§11 D-1; inventory C7; S2-Q1, S3 Q-1.) *Decide before
commit 1.*
- (a) All of it in M2-1, with every §4.4 check its data can express (built). M2-2 adds
  text, words and line shapes only. Consequence: M2-1 is larger, and lands checks org
  §6.2 assigns to M2-2.
- (b) Tasks and instances only, copy-in keyed by `instance.var_input`, globals in M2-2.
  Consequence: M2-2 reshapes data M2-1 landed, which §4.9 asks to avoid (org:873), and
  between the two the data API accepts what the text will refuse.
- *Recommend (a).* Copy-in needs a source; org:474-475 and org:881 both read as one
  validator before any text; all three designs and both judges agree.

**Q-2. How does a host read a task's overlap count?** (§11 D-2; S1 Q-B, S2-Q4, S3 Q-2.)
*Before commit 4.*
- (a) `Runtime.overlaps/1`, a map by task name (built). One function beyond org:669-680.
- (b) Events only, no stored count. Departs from org:596 and decision 11's "counted".
- (c) Kept, unread. State no test can observe, against CLAUDE.md's revert rule.
- *Recommend (a)*: keeps the decided count and makes it testable; OE-2 and a runner will
  want it.

**Q-3. Is there a restart of the resource in M2-1?** (JS1 graft 1 builds it; JS2 graft 4
records its rule and builds it only on this answer; S2-Q7, S3 Q-3, S1 Q-I.) *Before commit
5.*
- (a) `restart/2`, `:cold | :warm`, keeping the clock and the input image (built; RS-0…6).
  Consequence: one more function and six rules now; `scan/2` with `restart/3` and a
  one-instance configuration agree across a restart with nothing resent (JS1: 0 of 3,000
  mismatching steps, against 708 without it).
- (b) None: `start/1` again is the cold restart, and the host resends its whole input
  image. Consequence: the agreement org:686-688 states becomes a host duty; a runner's
  explicit restart (decision 14) is `start/1` plus a resend.
- (c) Defer to the runner or OE-2. Consequence: the new state has no restart rule until
  then.
- *Recommend (a)*: org:686-688 already gives `restart/3` its input rule for the sake of
  this agreement, and §8's commit 5 can be dropped whole if (b) is chosen.

**Q-4. After `restart/2`, when is each task next due?** (S3's rule.) *Before commit 5.*
- (a) At the next cycle: `next_due` is the kept `now`, the phase re-anchored at the restart
  (built). Consequence: a restart behaves as a start at the kept clock; a first cycle a
  whole interval later reports an overlap, as after `start/1`.
- (b) Each task keeps its `next_due` and phase. Consequence: the first cycle after a
  restart may run nothing periodic.
- (c) The next multiple of its interval from 0. Consequence: a phase from the original
  start survives a restart.
- *Recommend (a)*: one rule with `start/1`, "as `start/1` left it but for the clock and the
  input image".

**Q-5. What does the first cycle's elapsed time mean?** (inventory C14; S1 Q-A, S2-Q5, S3
Q-5.) *Before commit 4.*
- (a) Phases anchored at `start/1`, at 0; a runner's first call is `cycle(rt, 0, inputs)`,
  and a first cycle after elapsed `e` reports the periods before it (built). No special
  case.
- (b) Anchor each task at the first cycle. No overlap in cycle 1, but the phase depends on
  the host, and a special case in the code and in OE-2.
- (c) `start/2` with a start time. A second origin to explain and check.
- *Recommend (a)*: org:556-557 as written; the overlap it reports is a true miss.

**Q-6. Does `next_due_in/1` count task-less instances?** (inventory C13; S1 Q-C, S2-Q6, S3
Q-4.) *Before commit 4.*
- (a) No: the soonest periodic task, `:infinity` with none (built). A runner of task-less
  instances paces itself (org:661).
- (b) 0 whenever a task-less instance exists. A runner that sleeps on it busy-loops.
- *Recommend (a).*

**Q-7. One namespace for tasks, globals and program instances?** (S1 Q-D, S2-Q3, S3 Q-6.)
*Before commit 2.*
- (a) One, case-only twins refused, the first in line order keeping a name; program types
  apart, so `program motor motor` is legal (built).
- (b) One per kind. `get(rt, "m1")` becomes ambiguous; every message must say which kind.
- (c) Program types in it too. Refuses `program motor motor`.
- *Recommend (a)*: relaxing later breaks nothing; tightening later breaks plants.

**Q-8. The bounds of a task's interval and priority.** (S1 Q-E, S2-Q11, S3 Q-11.) *Before
commit 2.*
- (a) Interval 1..2147483647 ms, priority 0..2147483647, the dint range (built).
- (b) Priority 0..31 (CODESYS) or 0..15. Tighter, relaxable later.
- (c) Unbounded. Values no dint holds.
- *Recommend (a)*, logex's integers being dints; (b) is the safer start by decision 7's
  reasoning, so the choice is the maintainer's. Either way M2-3's `priority` stanza says
  Siemens numbers the other way.

**Q-9. The location grammar.** (S1 Q-F, S2-Q8, S3 Q-9.) *Before commit 2.*
- (a) One-name device, lowercase `i` or `q`, one or more whole-number fields with no
  leading zero (built; S1's and S3's). One spelling per address: two globals at one
  address have the same string.
- (b) S2's: fields compared as numbers, `panel.i.00` the same address as `panel.i.0`.
  Two spellings of one address, which a printer must normalise.
- (c) Dotted devices (`rack1.slot2.i.0`), or `I`/`Q` in any case. Ambiguous where `i`/`q`
  sits; needs normalising.
- *Recommend (a)*: tightest now, each part widenable later without breaking a plant. A
  known oddity: `panel.i.1` and `panel.i.1.0` are two addresses (IEC's rule unverified).

**Q-10. May an output point take an initial value?** (S1 Q-G, S2-Q9, S3 Q-10.) *Before
commit 2.*
- (a) Refused, as an input point's is (built). It starts at 0 until its driver's first
  scan copies out the var_output's own initial value.
- (b) Allowed. M2-2 must then place it on the `at` line, which org:414 does not.
- *Recommend (a)*: org:414 with org:779-780; S3's acceptance was the one rule both judges
  said not to graft.

**Q-11. Is a configuration with no program instance refused?** (S1 Q-H, S2-Q10, S3 Q-12.)
*Before commit 2.*
- (a) Refused (built), as IEC's grammar requires a program (`research.md` IEC-5).
- (b) Allowed: an empty resource that cycles and reports nothing.
- *Recommend (a)*; relaxable later.

**Q-12. How does a configuration hold its program types?** (S1 Q-K, S2-Q12.) *Before
commit 2.*
- (a) `programs: %{name => %Program{}}` inside the struct; `new!/1` takes a list and keys
  it by name (built). Keeps both decided signatures, `start(config)` and `compile/3`'s map.
- (b) `start/2` taking the programs beside a configuration that names them. Changes the
  decided `start/1` (org:675).
- *Recommend (a).*

**Q-13. Does `start/1` check its configuration again?** (S1 Q-L, S2-Q14, S3 Q-17; both
judges.) *Before commit 3.*
- (a) Yes, `check/1` in full (built). A hand-built configuration is refused with the
  constructor's messages; 0 of 3,000 hand edits escape.
- (b) No; a hand-edited configuration is outside the contract. S1 let 2,364 of 3,000
  escape as other exceptions, and silently skipped an instance whose task was renamed.
- *Recommend (a)*: the configuration is the data API, built by hand by design; decision 28
  is the precedent.

**Q-14. Does `new!/1` raise every problem, or the first?** (§11 D-3; S1 Q-M, S3 Q-16.)
*Before commit 2.*
- (a) Every problem, a line each (built), as `call/4`'s inputs and M2-2's diagnostics do.
- (b) The first only, as `Tag.new!/4` does. One round trip per mistake.
- *Recommend (a).*

**Q-15. Elements as structs, maps or tuples?** (S2-Q14, S3 Q-15.) *Before commit 2.*
- (a) A struct per kind with `@enforce_keys` (built). Four more public modules, and
  fields documented and enforced; `Task` shadows Elixir's `Task` (Q-28).
- (b) Plain maps with every key and a line. No new modules; unknown keys refused by hand.
- (c) Tuples mirroring the lines. Awkward from Elixir.
- *Recommend (a)*: it is what the judges scored and what T1's reader builds.

**Q-16. The stage of a configuration problem.** (S2-Q2, S3 Q-14.) *Before commit 2.*
- (a) A new `:configure` stage (built), for `check/1` and M2-2's line shapes; `.lcf` lex
  and parse errors keep `:lex` and `:parse`.
- (b) Reuse `:validate`, which means `instructionize/2` today (`lib/logex/diagnostic.ex:9-12`).
- *Recommend (a).*

**Q-17. What may `get/2` read?** (S1 Q-J, S2-Q19, S3 Q-7.) *Before commit 3.*
- (a) A global, any declared tag of an instance (a `var` included), a public member of a
  block instance at any depth; never an internal member, an instance whole or a member of a
  scalar (built). `m1.fault` reads, as org §4.6's receipt and the README read it.
- (b) var_inputs, var_outputs and public members only. A latched fault cannot be read;
  M2-5's `m1.s2.run`, `s2` a `var`, cannot be read.
- (c) (a) plus task state under task names. Task names enter path space.
- *Recommend (a)*: a host's read, not logic; IEC's ban on reading a block's inputs
  (`research.md` IEC-11) is about logic. VAR_ACCESS stays deferred.

**Q-18. Where does an overlap event sit within a cycle's events?** (S3 Q-19; JS1 §1.3,
JS2 §10.) *Before commit 4.*
- (a) Just before its own task's scans (built; S1 and S2). An event log in the order things
  happened.
- (b) All overlaps first, then the scans (S3). §4.6's step 3 then step 4.
- *Recommend (a)*: the same information, kept in the order the cycle worked; pinned by the
  Done-when's late-cycle test and the walk.

**Q-19. Must a configuration have a name?** (JS2 graft 6.) *Before commit 2.*
- (a) Yes (built; CF-30). M2-2's reader takes it from `compile/3`'s argument.
- (b) No, `name: nil` allowed. A runner has nothing to report the resource by.
- *Recommend (a)*: IEC names its CONFIGURATION; relaxing later breaks nothing.

**Q-20. Does an element built from Elixir carry a line?** (JS1 D2.) *Before commit 2.*
- (a) No: `new!/1` refuses one (built; NW-3), as `Declarations.validate!/1` refuses a line
  on a tag from Elixir; `check/1` and `start/1` accept lines, for M2-2's reader.
- (b) Yes. A diagnostic may then cite a line no file has.
- *Recommend (a).*

**Q-21. Should M2-1's Done-when say how the clock is stepped?** (S3 Q-20; JS1 graft 7.)
*Before commit 1.*
- (a) Reword "cycled for one simulated second" to "cycled every 10 ms from 0 to 990 ms"
  (100, 34 and 100 runs), and M2-3's likewise (100 and 20).
- (b) Leave it. The counts then depend on an unstated reading.
- *Recommend (a)*: every design's test reads it so.

**Q-22. The order of the milestone: M2-1 first, or M2-5?** (inventory §11 recommends
M2-5 first; S2-Q17 recommends M2-1.) *Before M2-1 lands.*
- (a) Decision 1's default, M2-1 first. `get/2` already walks `FbType.member/2` at any
  depth and gives total messages for block types M2-5 may bring (GT-4, GT-7), so M2-1
  forces no answer from M2-5. M2-5's acceptance `m1.s2.run` reads through `get/2`
  unchanged (unverified until a nested user block exists).
- (b) M2-5 first. M2-5's acceptance must be reworded (inventory C1), since it names an
  access path of M2-1's `get/2`.
- *Recommend (a).*

**Q-23. When OE-2 changes a task's interval, what becomes of its `next_due`?** (S2-Q13,
S3 Q-21, S1 Q-I.) *Before OE-2's design pass.*
- (a) Keep it; the next run steps by the new interval, so the phase re-anchors at that run.
  No run added or lost at the switch.
- (b) The next multiple of the new interval from the anchor. May run early or skip.
- (c) Re-anchor at the switch. An immediate run, or a gap.
- *Recommend (a).*

**Q-24. `Configuration.compile`'s argument order.** (inventory C15; S2-Q15; T1 keeps
org:470.) *Before M2-2.*
- (a) `compile(source, programs, name: "plant")`, mirroring `Logex.compile/2`. Departs from
  org:470.
- (b) org:470's `compile(name, source, types)`. Two orders for two compile functions.
- *Recommend (a)*, but it is M2-2's question and T1 keeps (b); the merge of track T
  decides.

**Q-25. Does M2-2 owe a printer from `%Configuration{}` to `.lcf`?** (inventory C17;
S2-Q16.) *Before M2-2.*
- (a) Yes, with a round trip: every configuration `new!/1` accepts prints to text that
  compiles to an equal one but for lines and file. The data API's "refuses what the text
  cannot say" gets a check.
- (b) No printer in M2. A configuration built as data has no saved form.
- *Recommend (a).*

**Q-26. Does M2-1 reserve OE-2's generation counter?** (S2-Q18.) *Before OE-2.*
- (a) OE-2 adds it; the struct is opaque, so a new field breaks no host.
- (b) Reserve it now: a field with no rule and no test.
- *Recommend (a).*

**Q-27. Does M2-1's data path refuse the `.lcf` words before the text exists?** (S1 Q-N,
S3 Q-13.) *Before commit 2.*
- (a) No; each text item reserves its words, in both front ends, in the commit that
  surveys them (built). A global named `task` built from Elixir between M2-1 and M2-3
  would break at M2-3.
- (b) All of org §4.8's `.lcf` words now. Words reserved before their stanzas exist,
  against CLAUDE.md's naming rule; a stanza may still change a spelling.
- *Recommend (a)*: no release falls between M2-1 and M2-2.

**Q-28. Keep the name `Logex.Configuration.Task`?** (S2 §12; JS1.) *Before commit 2.*
- (a) Keep it, IEC's word; the moduledoc warns that aliasing it shadows Elixir's `Task`.
- (b) Rename, for example `Logex.Configuration.TaskDecl`. No shadowing; a name IEC does
  not use.
- *Recommend (a)*: hosts write `%Logex.Configuration.Task{}`, as the tests do.

**Q-29. Land `warnings` on the configuration now, empty?** (inventory C5; JS1, JS2.)
*Before commit 2.*
- (a) Yes (built): M2-2's reader and M2-4's two-writer warning fill it, and no struct
  reshapes later. Nothing in M2-1 fills it, so only its key is pinned.
- (b) M2-4 adds it. A field added then, to a public struct.
- *Recommend (a)*: T1's reader asks for it (T1.md:223-252).

**Q-30. How does CLAUDE.md's "New state" rule apply to `%Logex.Runtime{}`?** (§11 D-4;
inventory C25.) *Before commit 3.*
- (a) A value from `start/1` and a rule for a cycle, `restart/2` and OE-2's switch, with no
  entry check, since no host hands the state in (built in the spike's CLAUDE.md).
- (b) An entry check with a pinned message for each field, as an instance's. Checks on a
  value only `start/1` makes.
- *Recommend (a).*

