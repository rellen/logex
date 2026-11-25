# The plans and the switch of an online edit

This page is for a contributor. It gives the plan that an accept makes, the record that
each switch keeps and the steps of a switch. Read it before you change a rule of a
[switch](../../guides/reference/glossary.md#switch).
[The architecture of an online edit](online-edit.md) gives the steps of an edit, the
fields of the instance, the report and an example.

## What the part does

A switch changes the program that an [instance](../../guides/reference/glossary.md#instance)
runs. It reads 3 things:

| Input | Made by | Holds |
|---|---|---|
| A plan | `plans/3`, at the accept | The facts of the 2 programs. It never reads the state |
| The record | Each switch, from the record before it | What occurs between 2 steps of the edit |
| The state | The host gives it to each step | The values of the instance |

The switch gives a new state, a new record and a report. `plans/3`, `switch/5` and
`prune/3` are in the internal file [`plan.ex`](../../lib/logex/edit/plan.ex).

## How it is built

### A plan

A plan is a map that `plans/3` makes at the [accept](../../guides/reference/glossary.md#accept).
It reads the 2 programs only, and never the state. Thus a plan stays correct for the full
edit, and 1 plan serves each instance of a
[program type](../../guides/reference/glossary.md#program-type). Each plan goes in 1
direction: from the program that a switch stops to the program that it starts.

`plans/3` reads the facts of each program 1 time: the tags and their types, the
[inputs](../../guides/reference/glossary.md#input), the
[outputs](../../guides/reference/glossary.md#output) and what the
[rungs](../../guides/reference/glossary.md#rung) write. `Logex.Walk` gives the writes,
the member writes, the [bit](../../guides/reference/glossary.md#bit) writes and the
presets. `Logex.Program.initial_env/1` gives the initial values. `plans/3` then makes 1
plan for each direction.

To find the [one-shots](../../guides/reference/glossary.md#one-shot) to block, `plans/3`
compares the rungs of the 2 programs. Before it compares them, it removes the line
numbers, the preset of each timer and counter, and the spelling of each
[literal](../../guides/reference/glossary.md#literal). The list `blocks` then has the
[storage bit](../../guides/reference/glossary.md#storage-bit) of each one-shot of the
program that the switch starts. It leaves out a bit only if 2 conditions are true:

- The rung of the one-shot is the same in the 2 programs.
- The program that the switch stops writes the bit only through that one-shot.

That program can also write the bit through another
[instruction](../../guides/reference/glossary.md#instruction). Then the bit can hold a
value that is not the power that the one-shot last received. The list also has the edge
memory of each counter and each `tp` whose rung is not the same, for example `boxes.cu`
or `horn.en`. No instruction writes an edge memory, so `plans/3` compares only its rung. A
switch uses `blocks` only if the program that it stops did the last scan.

This table gives the keys of a plan that a switch uses for its rules.

| Key | What the switch does with it |
|---|---|
| `stops` | Names the program that the switch stops: `:original` or `:candidate` |
| `starts` | Lists each tag of the program that it starts, for the start rules ([A switch](#a-switch)) |
| `live` | Reports each input that only the program that it starts reads |
| `unread` | Reports each input that only the program that it stops reads |
| `changed` | Reports each initial value that changes |
| `blocks` | Gives the bits to block if the program that it stops did the last scan |
| `ons` | Lists each one-shot bit of the program that it starts. An earlier bit stays blocked only if it is in this list |
| `held` | Lists each output that the program that it stops drives and the program that it starts does not drive |
| `left` | Lists the held outputs of either direction that the program that it stops shows |
| `shows` | Lists the outputs of the program that it starts |
| `timers` | Moves the [preset](../../guides/reference/glossary.md#preset) of each [timer](../../guides/reference/glossary.md#timer) and [counter](../../guides/reference/glossary.md#counter), and the time of each timer |
| `unwritten` | Reports each [member](../../guides/reference/glossary.md#member) input that the program that it stops writes and the program that it starts does not write |
| `nested` | Does the same work for the members of each instance of a user [function block](../../guides/reference/glossary.md#function-block), by path |
| `requalified` | Reports each path whose `retain` changes |
| `keep` | Gives the tags that a prune keeps |

A plan also has keys that a switch reads to look up a value. They are `initial` (the
initial values), `table` (the
[function block types](../../guides/reference/glossary.md#function-block-type)), `inputs`,
`lists` (the [arrays](../../guides/reference/glossary.md#array)) and `opens` (the arrays
of instances).

The third argument of `plans/3` is `:tags` for `Logex.Edit` and `:globals` for
`Logex.Configuration.Edit`. With `:globals`, each `var_external` is a
[global](../../guides/reference/glossary.md#global). No start rule starts it, and no entry
reports its initial value. `Logex.Configuration.Edit` makes 1 plan for each program type
that an instance runs in both configurations. It calls `switch/5` for each instance that
both configurations run with the same program type.

### The record

A plan cannot know what occurs between 2 steps. The record holds that. It starts empty
at the accept, and each switch returns a new record.

A timer has an internal member, `last`: the time from which it counts. A resume moves
`last` on by a time that the timer must not count. The report gives it as a `:resumed`
entry. A resume given back moves `last` back, as a `:resume_undone` entry.

| Field | Holds |
|---|---|
| `shown` | The last value of each held output, as the host received it |
| `pre` | For each timer and counter, the preset that the last switch found and the preset that it left. For a timer, also the `last` that it found and left, if it moved `last` |
| `scanned` | The program that last wrote the storage bits, and the bits that a switch listed and that no scan has run yet |
| `held` | The time from which the instance runs its current program |
| `prior` | The same time for the other program, before the last switch |

The record field `held` is a time. It is not the plan key `held`, which lists outputs.

A switch uses `pre` to give back a preset or a resume of the last switch. It uses `held`
and `prior` for 1 rule: the time of a timer counts only while the instance runs a program
that runs the timer. A switch that only gives the instance back, with no scan and no time
after the last switch, swaps `held` and `prior`. A new edit starts with an empty record.
Thus it does not give back a move that an earlier edit made.

### A switch

`Logex.Edit` calls `switch/4`. It calls `switch/5` with the `now` of the instance as the
time of the switch, so the time does not move. In a resource, the time is the `now` of
the resource. The fourth argument, `first_test?`, is true at the first
[test](../../guides/reference/glossary.md#test) only.

The start rules start a tag at its
[initial value](../../guides/reference/glossary.md#initial-value):

- A tag that the state does not have starts at each switch.
- At the first test, a tag that the new program adds also starts, even if the state has a
  value for it. A plain swap (a scan of the new program over the old state, with no edit)
  can leave such a value.
- At the first test, a tag of the 2 programs whose value does not fit its type also
  starts.

`switch/5` does these steps, in this sequence:

1. It finds the values of the outputs of `left`. If the program that it stops scanned
   after the last switch, it copies them to the record field `shown`.
   If a [restart](../../guides/reference/glossary.md#restart) came after that scan, it
   removes them from `shown`.
2. It starts each tag that the start rules name.
3. It moves the members of each user block instance by their paths.
4. It reports the inputs, the changed initial values, the bits to block and the held
   outputs.
5. It moves the preset of each timer and counter, and the time of each timer.
6. It reports each input of `unwritten`, with the value that it keeps.
7. It sets `switched` to true and `now` to the time of the switch. It sets `ons_blocked`
   to the bits to block from step 4.
8. It adds the changes of `retain` and sorts the report.

The bits to block are the bits of `blocks`, if the program that it stops did the last
scan. They are also each bit of the record's `scanned` that no scan has run yet, if the
bit is in `ons`.

A switch never sets a storage bit to block a one-shot: it lists the bit in
`ons_blocked`. It starts a storage bit only as it starts any tag, at its initial value,
as `added s1 0` in [the example](online-edit.md#an-example) shows. A switch does not change `first` and removes no
tag. Only `prune/3` removes tags.

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log. §4.9 of that document gives the design.

- **Plans from the programs alone.** Fix F5 puts the per-instance work in functions of 1
  plan, 1 record and 1 state. A plan stays correct for the full edit, and 1 plan serves
  each instance of a program type.
- **Blocks, not writes.** Decision 21 blocks a one-shot and writes no storage bit.
- **The time of a timer.** Decisions 339 to 341 give 1 rule: the time counts only while
  the instance runs a program that runs the timer. The record holds the times that the
  rule needs.

## How to change it

To add a rule to a switch, follow the steps of
[The architecture of an online edit](online-edit.md#how-to-change-it). Put each fact of
the 2 programs that the rule reads into the plan, in `plans/3`. Put each fact of a step
that a later step needs into the record. Then add the rule to `switch/5`, and report each
write that it makes.

| If you change | The test file that fails, under `test/logex/` |
|---|---|
| A rule of a switch for 1 instance | `edit_test.exs` |
| A rule for the members of a block instance | `function_block_test.exs` |
| A write that no report entry lists | `api_contract_test.exs` |

## See also

- [0012. The staged online edit](../adr/0012-staged-online-edit.md).
- [The architecture of an online edit](online-edit.md): the steps, the report and an
  example.
- [The online edit of a resource](online-edit-of-a-resource.md): the switch of each
  instance of a configuration.
- [The records, faults and restarts of a scan](scan-records-and-faults.md): how a scan
  reads the blocked edge memories.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
