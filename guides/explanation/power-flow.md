# Power flow in a rung

This page is for an Elixir developer who does not know ladder logic. It answers 1
question: how does logex run the [instructions](../reference/glossary.md#instruction) of
1 [rung](../reference/glossary.md#rung)?

logex runs the instructions of a rung from left to right. Each instruction gets a
[power flow](../reference/glossary.md#power-flow), which is true or false, and gives a
power flow to the next instruction. A [branch](../reference/glossary.md#branch) runs
each of its [legs](../reference/glossary.md#leg).

## The model: an instruction passes power to the next instruction

A rung is 1 line of a [program](../reference/glossary.md#program). Power flows from the
left end of the rung to the right end. The left end is always true. Each instruction
gets the power flow from the instruction before it. It does its operation and gives a
power flow to the next instruction. An instruction that gets a true power flow has
power.

- A [contact](../reference/glossary.md#contact) reads 1
  [tag](../reference/glossary.md#tag), and passes the power or stops it. The contact
  `xic start` passes power if `start` is 1. The contact `xio stop` passes power if
  `stop` is 0.
- A [coil](../reference/glossary.md#coil) writes 1 tag from the power flow that it gets.
  The coil `ote motor` writes 1 to `motor` with power and 0 with no power.
- The coils `otl` and `otu` write only with power. With power, `otl` writes 1 and `otu`
  writes 0.
- Instructions in series are an AND. An instruction has power only if each instruction
  before it passes power.
- A branch is an OR of its legs. Power flows out of the branch if 1 leg or more passes
  power.

The program `lamps.ld` starts and stops a motor, and it sets 3 lamps. The file is in the
directory `scan-cycle-and-time` of the project.

<!-- file: scan-cycle-and-time/lamps.ld -->
```text
var_input start bool
var_input stop bool
var_output ready_lamp bool
var_output start_lamp bool
var_output motor bool
var_output run_lamp bool

xio motor ote ready_lamp
( xic motor | xic start ote start_lamp ) xio stop ote motor
xic motor ote run_lamp
```

<!-- rung: scan-cycle-and-time/lamps.ld -->
![The 3 rungs of lamps.ld as a ladder drawing. Rung 1: not motor sets ready_lamp. Rung 2: a branch of 2 legs, then a closed contact stop, then the coil motor. Leg 1 is the contact motor. Leg 2 is the contact start and the coil start_lamp. Rung 3: motor sets run_lamp.](../assets/scan-cycle-and-time-lamps.svg)

The text of a program does not show the 2 [rails](../reference/glossary.md#rail) of the
drawing. Each rung starts at the left rail.

## The power flow in rung 2

Rung 2 has a branch of 2 legs, then the contact `xio stop`, then the coil `ote motor`.
The script `scan-cycle-and-time.exs` runs the rungs of `lamps.ld` 6 times. Each run is 1
[scan](../reference/glossary.md#scan). Before each scan, the script changes the
[inputs](../reference/glossary.md#input) `start` and `stop`. The script runs in the
project of [Your first program](../tutorials/first-program.md).

```elixir
{:ok, lamps} = Logex.compile_file("scan-cycle-and-time/lamps.ld")

# The inputs that change before each scan.
changes = [
  %{},
  %{"start" => 1},
  %{"start" => 0},
  %{"start" => 1},
  %{"start" => 0, "stop" => 1},
  %{}
]

# One scan. The state holds the inputs.
scan = fn changed, state ->
  state = Logex.Runtime.put_inputs(lamps, state, changed)
  {outputs, state} = Logex.Runtime.scan(lamps, state)
  inputs = Map.take(state.env, ["start", "stop"])
  {Map.merge(inputs, outputs), state}
end

state = Logex.Runtime.instance(lamps)
{scans, _state} = Enum.map_reduce(changes, state, scan)

row = fn name, values ->
  IO.puts(String.pad_trailing(name, 12) <> Enum.join(values, "  "))
end

row.("scan", 1..6)

for tag <- ~w(start stop ready_lamp start_lamp motor run_lamp) do
  row.(tag, Enum.map(scans, & &1[tag]))
end
```

```console
$ mix run scan-cycle-and-time.exs
scan        1  2  3  4  5  6
start       0  1  0  1  0  0
stop        0  0  0  0  1  1
ready_lamp  1  1  0  0  0  1
start_lamp  0  1  0  1  0  0
motor       0  1  1  1  0  0
run_lamp    0  1  1  1  0  0
```

The script prints 1 column for each scan. The table gives the power flow in rung 2.

| Scan | Power flow | The coils |
|---|---|---|
| 1 and 6 | `motor` and `start` are 0. No leg passes power. | `ote motor` writes 0. |
| 2 | `start` is 1. Leg 2 passes power, and `xio stop` passes it on. | `ote motor` writes 1. |
| 3 | `start` is 0, but `motor` is 1 from scan 2. Leg 1 passes power. | The motor stays on. In leg 2, `ote start_lamp` gets no power and writes 0. |
| 4 | `start` is 1 again. Leg 1 and leg 2 pass power. | In leg 2, `ote start_lamp` writes 1. |
| 5 | `stop` is 1. Leg 1 passes power, but `xio stop` stops it. | `ote motor` writes 0. |

Rungs 1 and 3 each have 1 contact and 1 coil.
[The scan, the cycle and time](scan-cycle-and-time.md) explains the rows `ready_lamp`
and `run_lamp`.

## A branch runs each leg

A branch has 2 rules:

- **logex runs each leg, from the first leg to the last leg.** A true leg does not stop
  the legs after it. In scans 3 and 4, leg 1 is true. logex runs leg 2 also, and
  `ote start_lamp` writes the value of `start`.
- **A leg reads the values that an earlier leg of the same branch wrote.** For example,
  in `( xic start ote a | xic a ote b ) ote c`, leg 2 reads the `a` that leg 1 wrote.
  When `start` goes to 1, the tags `a`, `b` and `c` go to 1 in the same scan.

## How it compares with IEC 61131-3 and Logix

- [IEC 61131-3](../reference/glossary.md#iec-61131-3) defines a rung as a drawing
  between 2 rails. logex reads the same rung as 1 line of text.
  [The dialect and IEC 61131-3](the-dialect-and-iec.md) explains the text.
- A coil of IEC 61131-3 gives its power flow to the right, to the next part of the rung.
  The coil `ote` of logex does the same. Thus an instruction can come after a coil, as
  `ote c` does in the example of the second rule.
- On a [false rung](../reference/glossary.md#false-rung), a
  [Logix](../reference/glossary.md#logix) controller writes 0 for its OTE coil and
  writes nothing for its OTL coil. The coils `ote` and `otl` of logex do the same.

## Why logex does it this way

- **Each leg runs.** A leg can hold an instruction that writes, such as
  `ote start_lamp`. If logex skips the leg, that coil does not write 0, and its tag
  keeps an old value.
- **A leg, an instruction and a rung have 1 rule.** An instruction changes a tag when
  logex runs the instruction. Thus each instruction reads the values that the
  instructions before it wrote.

## See also

- [The scan, the cycle and time](scan-cycle-and-time.md): the sequence of the rungs in a
  scan, and the time.
- [Your first program](../tutorials/first-program.md): a lesson with these instructions.
- [Instructions: contacts and coils](../reference/instructions-contacts-and-coils.md):
  the exact rules of each contact and coil.
- [Glossary](../reference/glossary.md): the technical words of logex.
