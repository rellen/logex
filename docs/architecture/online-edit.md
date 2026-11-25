# The architecture of an online edit

This page is for a contributor. It describes how logex does an
[online edit](../../guides/reference/glossary.md#online-edit): the plans, the
[switch](../../guides/reference/glossary.md#switch), the record of an edit and the
[state](../../guides/reference/glossary.md#state) across the steps. Read it before you
add a kind of report entry. [The plans and the switch of an online
edit](online-edit-plans.md) gives the rules of a switch. Read it also before you add a
field to an [instance](../../guides/reference/glossary.md#instance) or a
[resource](../../guides/reference/glossary.md#resource).

[The online edit of a resource](online-edit-of-a-resource.md) gives the edit of a
[configuration](../../guides/reference/glossary.md#configuration) and the edit through the
[runner](../../guides/reference/glossary.md#runner).
[The model of an online edit](../../guides/explanation/online-edit-model.md) gives the
rules as a user sees them. [Online edit](../../guides/reference/online-edit.md) gives each
rule and each kind of entry.

> #### Caution {: .error}
>
> Report each change that a switch makes to the state, with an entry of a write kind
> ([The report](#the-report)). The host sees only the report. A random test in
> `test/logex/api_contract_test.exs` applies the writes of each report to the state
> before the step. It compares the result with the state after the step. If a change has
> no entry, the test fails.

## What the part does

An edit is plain data that the [host](../../guides/reference/glossary.md#host) keeps
between 2 steps. It holds the old [program](../../guides/reference/glossary.md#program),
the new program, the stage, 2 plans and a record. Each step is a function of the edit and
the state, and it returns a report. No step starts a process, reads a [clock](../../guides/reference/glossary.md#clock) or calls the Elixir
compiler.

```mermaid
flowchart TD
  host["Host"] -->|"edit, state"| edit["Logex.Edit"]
  host -->|"edit, resource"| cedit["Logex.Configuration.Edit"]
  runner["Logex.Runner"] -->|"steps after the accept"| cedit
  edit -->|"2 programs, 1 state"| plan["lib/logex/edit/plan.ex"]
  edit -->|"put_inputs/3, the check"| runtime["Logex.Runtime"]
  cedit -->|"1 plan for each program type"| plan
  cedit -->|"fields/1, edited/2"| runtime
  plan -->|"writes, one-shots, presets"| walk["Logex.Walk"]
  plan -->|"initial_env/1"| program["Logex.Program"]
```

Figure: the modules of an online edit. Both edits use the same plan file for each
instance.

The diagram shows 1 rule of the design: the per-instance work is in 1 internal file,
[`plan.ex`](../../lib/logex/edit/plan.ex). `Logex.Edit` calls it for 1 instance.
`Logex.Configuration.Edit` calls it for each instance of a configuration.

This table gives what each step of `Logex.Edit` calls in the plan file.

| Step | Calls | Returns |
|---|---|---|
| `accept/3` | `retyped/2`, `plans/2`, `switch/4` (plan `test`) | `{:ok, edit, forecast}` |
| `test/2` | `switch/4` (plan `test`) | `{edit, state, report}` |
| `untest/2` | `switch/4` (plan `untest`) | `{edit, state, report}` |
| `assemble/2` | `prune/3` (plan `test`) | `{new program, state, report}` |
| `cancel/2` | `prune/3` (plan `untest`) | `{old program, state, report}` |

`retyped/2` checks that each [tag](../../guides/reference/glossary.md#tag) keeps its
[type](../../guides/reference/glossary.md#type). The accept drops the state of its switch
and keeps only the report, the [forecast](../../guides/reference/glossary.md#forecast).
A [cancel](../../guides/reference/glossary.md#cancel) from the accept calls nothing and
gives an empty report. Each step first checks the state: it calls
`Logex.Runtime.put_inputs/3` with no inputs, which changes nothing.

## How it is built

### The edit

`%Logex.Edit{}` is opaque. A host keeps it and gives it to the next step.

| Field | Holds |
|---|---|
| `original` | The program that runs before the edit |
| `candidate` | The new program |
| `stage` | `:accepted`, `:testing` or `:untested` |
| `plans` | 2 plans: `test`, from the old program to the new program, and `untest`, back |
| `record` | What the switches of this edit learn about the instance |

`%Logex.Configuration.Edit{}` has these fields, with `records` (1 record for each
instance name) in place of `record`. It also has 5 more fields: `generation`, `held`,
`holders`, `holds` and `aside_at`.
[The online edit of a resource](online-edit-of-a-resource.md#the-edit) gives them.

### The plans, the record and the switch

`accept/3` makes 2 plans, 1 for each direction, from the 2 programs alone. Each switch
reads a plan, the record of the edit and the state. It gives a new state, a new record
and a report. [The plans and the switch of an online edit](online-edit-plans.md) gives
the keys of a plan, the fields of the record and the steps.

### The fields of an instance across an edit

2 fields of `%Logex.Instance{}`, `switched` and `ons_blocked`, exist for an online edit.
This table gives what changes them, and also `now` and `first`. The bits to block are
the bits that a switch lists ([A switch](online-edit-plans.md#a-switch)).

| Event | `switched` | `ons_blocked` | `now` | `first` |
|---|---|---|---|---|
| A switch | true | the bits to block | the time of the switch | kept |
| A [scan](../../guides/reference/glossary.md#scan) | false | each bit run removed | + the elapsed time | false |
| `restart/3` | kept | empty | kept | true |

`restart/3` is `Logex.Runtime.restart/3`. `switched` tells the next switch if the program
that it stops did a scan after the last switch. If it did not, the state does not hold
the outputs of that program. The record then gives the values.

### The report

A report is a sorted list of `{kind, name, detail}`, with 1 entry or fewer for each kind
and name. This table gives the write kinds: each entry of these kinds changes the state.

| Kind | The write to the state |
|---|---|
| `:added`, `:input` | Puts the tag at the value of the entry |
| `:preset` | Sets `.pre` (a counter's `.pv`) to `to` of the detail `{from, to}` |
| `:resumed` | Moves the timer's `last` on by the value |
| `:resume_undone` | Moves the timer's `last` back by the value |
| `:pruned` | Removes the tag |

Each other kind is a fact or a forecast and writes nothing. A switch also sets
`switched`, and sets the block list from the `:ons_blocked` entries. The kinds are an
open set, and a host ignores a kind that it does not know. The moduledoc of `Logex.Edit`
has the table of each kind.

## An example

The script `online-edit-architecture.exs` shows the fields of the instance at each step.
It uses [`motor.ld`](../../guides/tutorials/first-program.md) and
[`motor_v2.ld`](../../guides/explanation/online-edit-model.md). Run it from `examples/`.

```elixir
alias Logex.{Edit, Runtime}

{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the name of the program, so the script gives motor_v2.ld the name `motor`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

# 1 line for each step: 3 fields of the instance. Then 1 line for each entry of the
# report: the kind, the name and the value. For a timer, the script shows only the preset.
value = fn
  %{"pre" => preset} -> "pre=#{preset}"
  value -> inspect(value)
end

show = fn label, state, report ->
  fields = Map.take(state, [:now, :switched, :ons_blocked])
  IO.puts(String.pad_trailing(label, 9) <> inspect(fields))

  Enum.each(report, fn {kind, name, detail} ->
    IO.puts("  " <> String.pad_trailing("#{kind}", 12) <> "#{name} " <> value.(detail))
  end)
end

state = Runtime.put_inputs(motor, Runtime.instance(motor), %{"start" => 1})
{_outputs, state} = Runtime.scan(motor, state, 10)
show.("before", state, [])

# The accept does the switch of a test, keeps its report and drops its state.
{:ok, edit, forecast} = Edit.accept(motor, v2, state)
{edit, tested, report} = Edit.test(edit, state)
show.("test", tested, report)
IO.puts("forecast is the report of the test: #{forecast == report}")

# This report has only :added writes. Applied to the state before the test, they give
# the state after it.
added = for {:added, name, value} <- report, into: %{}, do: {name, value}
IO.puts("state rebuilt from the report: #{Map.merge(state.env, added) == tested.env}")

# An untest with no scan between gives the instance back. It removes nothing.
{edit, untested, report} = Edit.untest(edit, tested)
show.("untest", untested, report)
IO.puts("the tags of the test stay: #{Map.merge(state.env, added) == untested.env}")

{edit, tested, report} = Edit.test(edit, untested)
show.("test", tested, report)
# running/1 gives the program that the instance runs at this stage of the edit.
{_outputs, scanned} = Runtime.scan(Edit.running(edit), tested, 10)
show.("scan", scanned, [])
{_program, assembled, report} = Edit.assemble(edit, scanned)
show.("assemble", assembled, report)
```

```console
$ mix run online-edit-architecture.exs
before   %{now: 10, switched: false, ons_blocked: []}
test     %{now: 10, switched: true, ons_blocked: ["s1"]}
  added       at_speed 0
  added       s1 0
  added       started 0
  added       t1 pre=2000
  held        run_lamp 1
  ons_blocked s1 0
forecast is the report of the test: true
state rebuilt from the report: true
untest   %{now: 10, switched: true, ons_blocked: []}
the tags of the test stay: true
test     %{now: 10, switched: true, ons_blocked: ["s1"]}
  held        run_lamp 1
  ons_blocked s1 0
scan     %{now: 20, switched: false, ons_blocked: []}
assemble %{now: 20, switched: false, ons_blocked: []}
  held        run_lamp 1
  pruned      run_lamp 1
```

- **The switch does not move the time.** `now` stays 10 at each switch. Only the scan
  moves it to 20.
- **The test starts 4 tags.** `motor_v2.ld` adds `at_speed`, `s1`, `started` and `t1`.
  The switch starts each at its initial value, `s1` also, and blocks the one-shot on
  `s1`.
- **The [untest](../../guides/reference/glossary.md#untest) blocks nothing and removes nothing.** The program that last scanned is
  `motor.ld`, and the untest starts it again. Its bits are as it left them. The 4 tags of
  the test stay in the state until a prune.
- **The second test blocks `s1` again.** The record says that the old program last wrote
  the bits, and `motor.ld` has no rung with `s1`.
- **The untest reports no held output.** No scan of `motor_v2.ld` gave `at_speed` or
  `started` to the host, so the record knows no value for them.
- **The [assemble](../../guides/reference/glossary.md#assemble) removes `run_lamp`.** `motor_v2.ld` does not declare it. The report
  gives it as held, because the host keeps its
  [point](../../guides/reference/glossary.md#point) at the last value 1. It gives it also
  as pruned, because the prune removes the tag from the state.

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log. §4.9 of that document gives the design.

- **No Elixir compiler.** Decisions 15 and 16 keep a program as data, and keep the
  Elixir compiler off the edit path. An edit with an error changes nothing that runs.
  [0001. A program is data](../adr/0001-a-program-is-data.md).
- **5 steps.** Decision 18 stages the edit from the start: accept, test, untest, assemble
  and cancel. The other option was an edit that applies immediately.
  [0012. The staged online edit](../adr/0012-staged-online-edit.md).
- **The forecast is a switch.** Decision 27 gives the accept the state, so that each step
  returns a report, the accept also. Its report is the forecast: the report of a test at
  that moment. Thus the forecast and a test use 1 function and give 1 report.
- **Plans from the programs alone.** Fix F5 puts the per-instance work in functions of 1
  plan, 1 record and 1 state. Decision 59 then makes `Logex.Configuration.Edit` a
  separate module that calls the same functions.
- **Blocks, not writes.** Decision 21 blocks a one-shot and writes no storage bit. The
  other option was to set the storage bit to 1, so that the one-shot sees no
  [rising edge](../../guides/reference/glossary.md#rising-edge).
  That write also changes each other rung that reads the bit.
- **Held outputs.** Decision 20 keeps the last value of an output that no program drives.
  An output that goes to 0 can stop or start a machine.
- **The time of a timer.** Decisions 339 to 341 give 1 rule: the time counts only while
  the instance runs a program that runs the timer.

## How to change it

To add a rule to a switch:

1. Read §4.9 of `docs/organisation.md` and the moduledoc of `Logex.Edit`.
2. Write a case in `test/logex/edit_test.exs` that the rule makes true. See it fail.
3. Put each fact of the 2 programs that the rule reads into the plan, in `plans/3`
   ([A plan](online-edit-plans.md#a-plan)).
4. Add the rule to `switch/5` ([A switch](online-edit-plans.md#a-switch)). Report each
   write that it makes.
5. Write the rule in the moduledoc of `Logex.Edit`. Add a new kind to its table and to
   §4.9.

> #### Warning {: .warning}
>
> A new kind of entry makes the random test of `test/logex/api_contract_test.exs` fail
> until you do steps 6 to 8.

6. Add the new kind to `@report_kinds` in `test/logex/api_contract_test.exs`. If only the
   edit of a configuration gives it, add it to `@configuration_kinds` also.
7. If the kind is a write, add a clause for it to `write/2` in that file. Without the
   clause, the test does not apply the write, and the rebuilt state is different.
8. Make sure that the random programs of the test give the kind. The test fails if it
   does not get each kind of `@report_kinds`.
9. Run `scripts/gate.sh`. It must print `GATE-OK`.

A new field of `%Logex.Instance{}` needs a check in the runtime with its message. It also
needs a value from `Logex.Runtime.instance/1`, and a rule for a scan, `restart/3` and a
switch. The moduledoc of `Logex.Instance` gives the rules of the other fields.

The files of this table are in `test/logex/`.

| If you change | The test file that fails if it is wrong |
|---|---|
| A rule of 1 instance | `edit_test.exs` |
| A rule inside a function block | `function_block_test.exs` |
| A change of `retain` | `retain_edit_test.exs` |
| A change of the state that no entry lists | `api_contract_test.exs` |
| A field of `%Logex.Instance{}` | `runtime_test.exs` |
| The cost of a step | The growth cases of `edit_test.exs` |

## See also

- [0012. The staged online edit](../adr/0012-staged-online-edit.md) and the other
  [decision records](../adr/README.md).
- [The plans and the switch of an online edit](online-edit-plans.md): the plans, the
  record and the steps of a switch.
- [The online edit of a resource](online-edit-of-a-resource.md): the edit of a
  configuration, and the edit through the runner.
- [The runtime and the evaluator](runtime-and-evaluator.md): the scan that runs between 2
  steps.
- [The model of an online edit](../../guides/explanation/online-edit-model.md) and
  [An online edit of a plant](../../guides/explanation/online-edit-of-a-plant.md): the
  model and the reasons, for a user.
- [Online edit](../../guides/reference/online-edit.md): each rule and each kind of entry.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
