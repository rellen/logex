# The records, faults and restarts of a scan

This page is for a contributor. It gives these parts of a
[scan](../../guides/reference/glossary.md#scan):

- the records that a scan keeps in `env` while it runs
- the edge memories that an online edit blocks
- the [faults](../../guides/reference/glossary.md#fault) and the rungs that do not run
- the state after a restart

Read it before you add a record of a scan or a fault. Read it also before you change a
rule of a one-shot, a counter or a `tof` at a restart.
[The runtime and the evaluator](runtime-and-evaluator.md) gives the instance, the steps
of a scan and the functions of the evaluator.

## What the part does

The evaluator runs the rungs of a [routine](../../guides/reference/glossary.md#routine)
with `{power, env}`. While the routine runs, it keeps some facts in `env` under atom keys.
At the end of the routine, it takes them out. The host never sees these keys: it sees
`state.faults` and the new `env`.

## How it is built

### The records of a scan

A scan keeps some records in `env`, each under an atom key. A tag name is a string, so no
tag can have the key of a record.

| Key | Holds | Taken out by |
|---|---|---|
| `:faults` | Each fault that the routine found | `run/3`, or `called/5` for a body, at the end of the routine |
| `:jump` | The label of a `jmp` that its rung energised | `jumped/3`, when the rung ends |
| `:ran` | The instances whose bodies ran, and the edge memories of skipped rungs | `run/3`, through `unrun/2`, or `called/5` for a body, through `ran/3` |
| `:open` | The elements written of each array of more than 256 elements | `closed/1`, at the end of the routine |

The 4 keys are `@own_keys`. `state!/2` refuses an `env` that holds 1 of these keys. The script of
[The runtime and the evaluator](runtime-and-evaluator.md#a-scan) shows the message. A guard cannot read a list, so the guard of `state!/2` names each key.

### Blocked edge memories

An online edit can change a rung that holds a one-shot. The edit's
[switch](../../guides/reference/glossary.md#switch) then blocks the edge memories of the
changed rungs:

- The switch puts each of these memories into `ons_blocked`. Thus a one-shot does not
  compare the new rung with the bit that the old rung wrote, and it fires no false pulse.
- `run/3` gives the evaluator these memories as a nested map, by instance. Each one-shot
  finds its bit with 1 look-up.
- A blocked one-shot passes no power on its next run, and it writes its bit.
- If the routine has a blocked memory, a skipped rung marks its edge memories under
  `:ran`. A body that does not run marks nothing.
- After the rungs, `unrun/2` keeps in `ons_blocked` each memory that a skipped rung marked,
  and each memory in a body that did not run. It drops the others.

### Faults

A fault never leaves `element/3` as an exception. A tag can give the subscript of an
element or the number of a bit. If its value is out of range, the read or the write
throws.

No instruction except `cal` has more than 3 operands. Thus a clause of `element/3` adds a
`catch` only if 1 of the first 3 operands has such a tag. Each `cal` has a `catch`,
because a `cal` can have any number of operands. A `catch` costs 1 reduction, so the other
instructions have none.

The `catch` writes the fault to `:faults` and gives the power `false`. A division by 0 and
the square root of a negative number do not throw. The clause of `evaluate/3` writes these
2 faults.

| Kind | Severity | What the instruction does |
|---|---|---|
| `:divide_by_zero` | Minor | Writes 0, or 0.0 to a real, and passes no power |
| `:negative_sqrt` | Minor | Writes 0.0 and passes no power |
| `:bit_out_of_range` | Major | Writes nothing and passes no power |
| `:index_out_of_range` | Major | Writes nothing and passes no power |

The runtime does not stop the plant for a
[major fault](../../guides/reference/glossary.md#major-fault). A host that calls `call/4` or
`scan/2,3` reads `state.faults` and decides what to do. The runner
[trips](../../guides/reference/glossary.md#trip) at the end of the step of the cycle that
found the fault. [The resource and the schedule](resource-and-schedule.md) gives the
steps. The script of [The runtime and the evaluator](runtime-and-evaluator.md#a-scan)
shows 2 faults of a subscript out of range.

### Rungs that do not run

A `jmp` on a true rung puts its label under `:jump`. After that rung, `jumped/3` skips the
rungs up to the rung that the label starts. A skipped rung runs nothing.

A timer has a hidden member `last`, the time of its last run. A skipped rung does not change it. At its
next run, the timer adds all the time since `last`.
[Rungs that a scan does not run](../../guides/explanation/rungs-that-do-not-run.md) gives
these rules for a user.

### After a restart

After each start and each restart, `first` is `true`, and `ons_blocked` is empty. On the
first scan, no one-shot and no counter fires on an edge. This rule includes a retained
counter. The clauses of a one-shot and of a counter read `first` from the scan.

A retained `tof` can be on and not timing: its input was on when the instance stopped. A
[warm restart](../../guides/reference/glossary.md#warm-restart), and a start from a
[retained image](../../guides/reference/glossary.md#retained-image), put such a `tof` at
rest. Its `.dn`, `.tt` and `.en` go to 0, and `.acc` keeps its value. A `tof_ltime` is the
same. Thus a run-on does not start by itself when its rung is first false. A retained
`tof` in its delay continues the delay at its next run.

The restart or the start does this, and no scan does it. A scan pays nothing for it. Thus
the restart puts a `tof` at rest wherever it is:

- On a skipped rung
- In a block that does not run
- In an element of an array of `tof`
- In a member of a block at any depth

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log.

- **A fault is data (78, 99, 153, 160).** The scan runs on, and `state.faults` reports.
  [0010. A fault does not stop a scan](../adr/0010-a-fault-does-not-stop-a-scan.md).
- **The block list (21).** A changed rung fires no false pulse after a switch.
- **Jumps (104, 106).** Decision 104: the skip starts when the whole rung of the `jmp`
  ends. Decision 106: a skipped rung keeps each edge memory that a switch blocked, until a
  scan runs its instruction.
- **Large arrays (352).** A write into a tuple copies the tuple. With `:open`, a scan that
  writes each element of `ton[16000]` takes 84 ms, not 1.8 s.
- **A restart puts a `tof` at rest (385).** A scan pays nothing.
  [0016. Retained values and starts](../adr/0016-retained-values-and-starts.md).

## How to change it

Read the moduledoc of `Logex.Runtime` first.

To add a record of a scan:

1. Write a test case that runs a program through `call/4`. See it fail.
2. Use an atom key. Add the key to `@own_keys` and to the guard of `state!/2`.
3. Take the record out at the end of the routine: in `run/3` for the program.
4. For the body of a block, take the record out in `called/5`.
5. Run `scripts/gate.sh`. It must print `GATE-OK`.

| If you change | The test file that fails, under `test/logex/` |
|---|---|
| A fault, its kind or its severity | `fault_test.exs` |
| A jump or a skipped rung | `jump_test.exs` |
| A blocked edge memory after a switch | `edit_test.exs` |
| A retained `tof` at a restart | `retain_test.exs` |

## See also

- [0010. A fault does not stop a scan](../adr/0010-a-fault-does-not-stop-a-scan.md).
- [The runtime and the evaluator](runtime-and-evaluator.md): the instance, a scan and
  the evaluator.
- [The architecture of an online edit](online-edit.md): the switch that blocks the edge
  memories.
- [Rungs that a scan does not run](../../guides/explanation/rungs-that-do-not-run.md) and
  [Warm and cold restarts](../../guides/explanation/warm-and-cold-restarts.md): the rules
  for a user.
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
