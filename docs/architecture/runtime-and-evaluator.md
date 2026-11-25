# The runtime and the evaluator

This page is for a contributor. It describes the core of `Logex.Runtime`: the
[instance](../../guides/reference/glossary.md#instance) and its
[state](../../guides/reference/glossary.md#state), the
[scan](../../guides/reference/glossary.md#scan) and the evaluator. Read it before you add
a clause of the evaluator or a field of `%Logex.Instance{}`.
[The records, faults and restarts of a scan](scan-records-and-faults.md) gives what a scan
keeps in `env`, the faults and the state after a restart. [The IR and the program type](ir-and-program-type.md) gives the data
that the runtime runs. [The resource and the schedule](resource-and-schedule.md) gives the
[cycle](../../guides/reference/glossary.md#cycle) of a
[configuration](../../guides/reference/glossary.md#configuration).

> #### Caution {: .error}
>
> Do not read a clock in `Logex.Runtime`, and do not raise an exception for a
> [fault](../../guides/reference/glossary.md#fault). The host gives the time of each scan
> as a number. A fault is data, and the scan runs to its last rung. An `ArgumentError` is
> only for a wrong argument of the host. A check raises it before the rungs of the scan
> run.

## What the runtime does

`Logex.Runtime` is a module of functions. It starts no process. It
[interprets](../../guides/reference/glossary.md#interpret) a
[program type](../../guides/reference/glossary.md#program-type) in 2 forms:

| Form | Data | Functions |
|---|---|---|
| A lone instance | `%Logex.Instance{}` | `instance/1,2`, `call/4`, `put_inputs/3`, `scan/2,3`, `restart/3`, `retained/2` |
| A [resource](../../guides/reference/glossary.md#resource) | `%Logex.Runtime{}`, opaque | `start/1,2`, `cycle/3`, `next_due_in/1`, `overlaps/1`, `get/2`, `get!/2`, `restart/2`, `retained/1` |

```mermaid
flowchart TD
  host["Host or runner"] -->|"cycle/3"| steps["cycle_steps/3"]
  steps -->|"1 step for each due task, 1 for the untimed instances"| step["cycle_step/2"]
  step -->|"each instance of the step"| scanned["scanned/3"]
  host -->|"call/4 or scan/2,3"| callf["call/4"]
  scanned --> callf
  callf --> runf["run/3"]
  runf --> rungs["rungs/3"]
  rungs --> series["series/3"]
  series --> element["element/3"]
  element --> evaluate["evaluate/3"]
  step -->|"after the last step"| outputs["cycle_outputs/1"]
```

Figure: the calls from the host to 1 instruction. A cycle and a lone scan meet at
`call/4`, and each instruction of each scan goes through `evaluate/3`.

`cycle/3` calls 3 internal functions in sequence: `cycle_steps/3`, `cycle_step/2` and
`cycle_outputs/1`. The [runner](../../guides/reference/glossary.md#runner) calls the 3
functions itself. It reads its clock between 2 steps of the cycle. `scanned/3` runs 1
instance in a step of the cycle.
[The resource and the schedule](resource-and-schedule.md) gives these 4 functions.

## The instance

`Logex.Runtime.instance/1` makes the state of a new instance. The state does not hold the
program type. Thus 1 program type can run as many instances. Each instance has its own
state.

| Field | Holds | Changed by |
|---|---|---|
| `type` | The name of the program type | Nothing |
| `env` | The value of each [tag](../../guides/reference/glossary.md#tag), by name | A scan, `put_inputs/3`, `restart/3`, an edit |
| `now` | The time of the last scan, in ms. It is 0 before the first scan | A scan |
| `first` | `true` if the next scan is the [first scan](../../guides/reference/glossary.md#first-scan) | A scan clears it. `restart/3` sets it |
| `ons_blocked` | The [blocked edge memories](scan-records-and-faults.md#blocked-edge-memories) | A switch sets it. A scan keeps those that did not run. `restart/3` empties it |
| `switched` | `true` after a switch, until the next scan | A switch sets it. A scan clears it |
| `faults` | Each `%Logex.Fault{}` of the last scan, in sequence | A scan replaces it |

The value of a tag in `env` is an integer, or a float for a real. For an instance of a
[function block](../../guides/reference/glossary.md#function-block), it is a map of its
[members](../../guides/reference/glossary.md#member). An
[array](../../guides/reference/glossary.md#array) is a tuple, with a tuple of tuples for
2 or 3 dimensions. The host sets and reads an array as a list. An edge memory is the
[storage bit](../../guides/reference/glossary.md#storage-bit) of a
[one-shot](../../guides/reference/glossary.md#one-shot), or the memory of the last input of
a [counter](../../guides/reference/glossary.md#counter).

Each function that takes a state checks all of the state. The check includes the tags that
no rung writes. A guard checks each element of an integer, bit-string or bool array. A
function, `value?/2` of [`real.ex`](../../lib/logex/real.ex), checks each element of a real
array, and that costs more.
Thus the check costs time with a large array. These times are from 3 runs on 1 machine,
with 200 scans of 1 rung in each run:

| The state holds | Time of 1 scan |
|---|---|
| No array | About 1.4 µs |
| `int[4096]` | About 36 µs |
| `int[65536]` | 0.5 ms to 0.64 ms |
| `real[65536]` | 9.5 ms to 10.5 ms |

## A scan

`call/4` is 1 scan. A host gives the program type, the state, the
[inputs](../../guides/reference/glossary.md#input) and a `%Logex.Scan{}` with `now` and
`first`. `scan/2,3` makes the `%Logex.Scan{}` from the state and the time that passed,
and calls `call/4`. `scan/2` gives 0 ms. `call/4` does these actions in sequence:

1. It checks the program type, the state and the `%Logex.Scan{}`. A wrong value raises an
   `ArgumentError`.
2. It merges the inputs into `env`. It refuses a tag that is not a `var_input` and a value
   outside its [type](../../guides/reference/glossary.md#type).
3. `run/3` completes the `%Logex.Scan{}`. It adds the tag table, the block types, `units`
   and `reals` from the program type. It adds the state's `ons_blocked` as a nested map,
   by instance.
4. `run/3` runs the rungs. The `%Logex.Scan{}` is the same for each instruction of the
   program's rungs.
5. `run/3` takes the records `:faults` and `:ran` out of `env`. It makes a
   `%Logex.Fault{}` of each fault.
6. It returns the [outputs](../../guides/reference/glossary.md#output) and the new state.
   The state has the new `now`, and `first` and `switched` set to `false`. Its
   `ons_blocked` holds the edge memories that did not run, and `faults` the new faults.

The program `scales.ld` weighs a box when the eye sees it. It keeps each weight in an
array, at the subscript that `slot` gives.

<!-- file: scales.ld -->
```text
var_input  eye    bool
var_input  weight int
var_input  slot   int
var_output last   int
var_output heavy  bool
var weights int[8]
var edge    bool
var p       bool

xic eye ons edge ote p
xic p move weight weights[slot]
move weights[slot] last
gt weights[slot] 500 ote heavy
```

The script `runtime-and-evaluator-scan.exs` calls `call/4` 3 times. It then gives 3
wrong arguments. Run it from `examples/`, which holds `scales.ld`:

```elixir
{:ok, scales} = Logex.compile_file("scales.ld")

# A new instance: each tag at its initial value. The array is a tuple.
state = Logex.Runtime.instance(scales)
IO.inspect(state, label: "instance", width: 70)

# call/4 is 1 scan. The host gives the inputs and a %Logex.Scan{}.
scan = fn state, inputs, now ->
  at = %Logex.Scan{now: now, first: state.first}
  {outputs, state} = Logex.Runtime.call(scales, state, inputs, at)
  IO.inspect(outputs, label: "t=#{now} outputs")
  state
end

state = scan.(state, %{"eye" => 0}, 0)
state = scan.(state, %{"eye" => 1, "weight" => 620, "slot" => 2}, 10)
IO.inspect(state.env["weights"], label: "weights")

# A subscript outside int[8]: 2 faults. The scan runs on.
state = scan.(state, %{"eye" => 0, "slot" => 8}, 20)
IO.inspect(state.faults, label: "faults", width: 70)

# Each of these calls raises an ArgumentError. The script prints its message.
refused = fn call ->
  try do
    call.()
  rescue
    error in ArgumentError -> IO.puts(Exception.message(error))
  end
end

refused.(fn -> Logex.Runtime.call(scales, state, %{}, %Logex.Scan{now: 10, first: false}) end)
refused.(fn -> Logex.Runtime.call(scales, state, %{}, %Logex.Scan{now: 30, first: true}) end)
held = %{state | env: Map.put(state.env, :faults, [])}
refused.(fn -> Logex.Runtime.call(scales, held, %{}, %Logex.Scan{now: 30, first: false}) end)
```

```console
$ mix run runtime-and-evaluator-scan.exs
instance: %Logex.Instance{
  type: "scales",
  env: %{
    "edge" => 0,
    "eye" => 0,
    "heavy" => 0,
    "last" => 0,
    "p" => 0,
    "slot" => 0,
    "weight" => 0,
    "weights" => {0, 0, 0, 0, 0, 0, 0, 0}
  },
  now: 0,
  first: true,
  ons_blocked: [],
  switched: false,
  faults: []
}
t=0 outputs: %{"heavy" => 0, "last" => 0}
t=10 outputs: %{"heavy" => 1, "last" => 620}
weights: {0, 0, 620, 0, 0, 0, 0, 0}
t=20 outputs: %{"heavy" => 0, "last" => 620}
faults: [
  %Logex.Fault{
    severity: :major,
    kind: :index_out_of_range,
    instruction: :move,
    path: nil,
    file: "scales.ld",
    line: 12,
    read: {8}
  },
  %Logex.Fault{
    severity: :major,
    kind: :index_out_of_range,
    instruction: :gt,
    path: nil,
    file: "scales.ld",
    line: 13,
    read: {8}
  }
]
time went backwards: this scan is at 10 ms, but the instance was last scanned at 20 ms
scan.first is true, but the instance has been scanned since it started or restarted
state.env holds :faults, the runtime's own key for a record a scan keeps and takes out before it ends: an env is keyed by tag names
```

At `t=20`, the rungs `move weights[slot] last` (line 12) and `gt weights[slot] 500 ote
heavy` (line 13) read `weights[8]`. Each of the 2 instructions does nothing and passes no
power, and the scan continues. `last` keeps 620. `heavy` is 0, because the `gt` passes no
power. The rung `xic p move weight weights[slot]` is false, so its `move` reads no
subscript and finds no fault.

## The evaluator

The evaluator is a set of private functions of `Logex.Runtime`. They run the rungs of a
[routine](../../guides/reference/glossary.md#routine): the rungs of the program, or the
rungs of the body of a block. No test calls them. A test runs a program through
`call/4`, on a state from `instance/1` or on a `%Logex.Instance{}` that the test makes.

| Function | Job |
|---|---|
| `run/3` | Completes the `%Logex.Scan{}`, runs the rungs of the program, takes out `:faults` and `:ran`, and gives the new state |
| `rungs/3` | Runs each rung in sequence. Each rung starts with power, `true` |
| `jumped/3` | After a rung, skips to the rung of the [label](../../guides/reference/glossary.md#label) if the rung energised a `jmp` |
| `series/3` | Gives `{power, env}` from each element of a rung to the next element |
| `element/3` | Runs a group of [branches](../../guides/reference/glossary.md#branch), or catches a fault of 1 instruction |
| `evaluate/3` | Runs 1 [instruction](../../guides/reference/glossary.md#instruction) |
| `closed/1` | At the end of a routine, writes the elements of each large array back into its tuple |

`evaluate/3` takes `(instruction, {power, env}, %Logex.Scan{})` and gives
`{power, env}`. Each instruction has 2 clauses: 1 for `{true, env}` and 1 for
`{false, env}`. Without the clause for `false`, a program raises `FunctionClauseError`
when a contact opens. A clause that does not read the scan takes `_scan`. A clause for
`units: nil` or `reals: nil` comes before the general clause, so a routine with no long
timer and no real does no look-up.

A group of branches runs each [leg](../../guides/reference/glossary.md#leg) from the power
that comes into the group. The `env` goes through the legs in sequence, so a leg reads
what an earlier leg wrote. The group passes power if 1 leg passes power. The group skips
no leg.

### How `cal` runs a body

A `cal` on a false rung does not run its block. A `cal` on a true rung runs the body of
the block in `called/5`.

First, `members_of/1` drops each key of `@own_keys` from the map
of the block instance. Then the body runs with a narrowed scan. The scan has the tags,
`units`, `reals` and blocked edge memories of the block. It keeps the same `now`, `first`
and block types. At the end of the body, `called/5` takes the records `:faults` and
`:ran` out of the map of the instance.

## Why it is built this way

Each number is a decision of [`docs/organisation.md`](../organisation.md) §7, the full
log. §4.6 of that document gives the design of the scan.

- **The host gives the time (13).** A test moves the time with a number.
  [0007. The host gives the time](../adr/0007-the-host-gives-the-time.md).
- **A `cal` on a false rung runs nothing (12).** The block keeps its state, as in
  IEC 61131-3.
- **The check of each state (171, 173).** No value outside its type gets to a rung.
- **Records, faults and restarts.** [The records, faults and restarts of a
  scan](scan-records-and-faults.md) gives their reasons.

## How to change it

Read the moduledoc of `Logex.Runtime`, `Logex.Instance` and `Logex.Scan` first.

### Add an instruction

1. Do [The naming survey](../implementation/naming-survey.md) of
   [Add an instruction](../implementation/adding-an-instruction.md).
2. Write a test case that runs a program through `call/4`. See it fail.
3. Add the mnemonic and its operands to `@instructions` in `lib/logex/compiler.ex`.
4. Add the 2 clauses of `evaluate/3`, for `true` and for `false`.
5. Run `scripts/gate.sh`. It must print `GATE-OK`.

To add a record of a scan, follow
[The records, faults and restarts of a scan](scan-records-and-faults.md#how-to-change-it).

### Add a field of the instance

1. Write a test case that runs a program through `call/4`. See it fail.
2. Add the field to `%Logex.Instance{}` and to its type `Logex.Instance.t()`.
3. Give the field a value in `instance/1`.
4. Add a check to `state!/2`, with a message that a test compares.
5. Give the field a rule for a scan in `run/3`, and for `restart/3`.
6. Give the field a rule for a switch, in `lib/logex/edit/plan.ex`.
7. Run `scripts/gate.sh`. It must print `GATE-OK`.

Each test file of this table is under `test/logex/`:

| If you change | The test file that fails |
|---|---|
| An instruction | `evaluation_test.exs` and the file of its kind, such as `timer_test.exs` |
| A message of the [host contract](../../guides/reference/glossary.md#host-contract) | `runtime_test.exs` |
| A field or the type of a spec | `typespec_test.exs` |
| The cost of a scan | `ceiling_test.exs` |

## See also

- [0001. A program is data](../adr/0001-a-program-is-data.md), [0010. A fault does not
  stop a scan](../adr/0010-a-fault-does-not-stop-a-scan.md) and the other [decision
  records](../adr/README.md).
- [The records, faults and restarts of a scan](scan-records-and-faults.md): the records in
  `env`, the faults and the state after a restart.
- [The resource and the schedule](resource-and-schedule.md): the cycle of a
  configuration.
- [The parts of logex](overview.md) and [The IR and the program
  type](ir-and-program-type.md).
- [Execution model](../../guides/reference/execution-model.md): the rules of a scan for a
  user.
- [The scan, the cycle and time](../../guides/explanation/scan-cycle-and-time.md) and
  [Power flow in a rung](../../guides/explanation/power-flow.md).
- [Rungs that a scan does not run](../../guides/explanation/rungs-that-do-not-run.md) and
  [Warm and cold restarts](../../guides/explanation/warm-and-cold-restarts.md).
- [Glossary](../../guides/reference/glossary.md): the technical words of logex.
