# Use one-shots and pulse coils

This guide is for a reader who writes a ladder
[program](../reference/glossary.md#program). It shows how to do an action 1 time when the
[power flow](../reference/glossary.md#power-flow) on a rung changes. For example, a push
button moves a conveyor 1 position for each press, and a photoelectric sensor counts each
box 1 time. You use the [one-shots](../reference/glossary.md#one-shot) `ons`, `osr` and
`osf`.

> #### Caution {: .error}
>
> Do not expect a pulse on the first scan. A one-shot gives no pulse on the
> [first scan](../reference/glossary.md#first-scan) of the program's
> [instance](../reference/glossary.md#instance), and on the first scan after a
> [restart](../reference/glossary.md#restart). If the operator holds a button when the
> program starts, the one-shot does nothing. The operator must release the button and
> press it again.

## Before you start

- You must have a Mix project that has logex.
  [Install logex and run a program](install-and-run.md) gives the steps.
- You must know how a script sets inputs and runs scans.
  [Your first program](../tutorials/first-program.md) shows this.

## Choose the instruction

A one-shot compares the power flow that it gets with the power flow of its last run. It
keeps the power flow of each run in its
[storage bit](../reference/glossary.md#storage-bit). A
[pulse coil](../reference/glossary.md#pulse-coil), `osr` or `osf`, also writes a
[pulse bit](../reference/glossary.md#pulse-bit): a bool that is 1 for 1 scan.

| You want | Use | Example |
|---|---|---|
| Instructions that run 1 time at a [rising edge](../reference/glossary.md#rising-edge) | `ons` | `xic eye ons s2 add boxes 1 boxes` |
| A [bit](../reference/glossary.md#bit) that is 1 for 1 scan at a rising edge, and instructions that follow the power flow | `osr` | `xic index_pb osr s1 index ote held_lamp` |
| A bit that is 1 for 1 scan at a [falling edge](../reference/glossary.md#falling-edge) | `osf` | `xic eye osf s3 box_left` |
| Instructions that run 1 time at a falling edge | `osf`, then a contact on its pulse bit on the next rung | `xic eye osf s3 box_left`, then `xic box_left add left 1 left` |

The 3 instructions give a different power flow to the
[instructions](../reference/glossary.md#instruction) after them on the
[rung](../reference/glossary.md#rung):

| Instruction | The instructions after it on the rung get power |
|---|---|
| `ons` | Only in the scan of the rising edge |
| `osr` | In each scan in which the `osr` gets power |
| `osf` | In each scan in which the `osf` gets power |

## Steps

In this example, the button `index_pb` moves a conveyor 1 position for each press. The
lamp `held_lamp` is on while the operator holds the button. The sensor `eye` is 1 while a
box is at the sensor. The program counts each box 1 time, and `box_left` is 1 for 1 scan
when a box leaves the sensor.

1. Make the file `use-one-shots-and-pulse-coils/conveyor.ld` in your project, with this
   text:

<!-- file: use-one-shots-and-pulse-coils/conveyor.ld -->
```text
var_input index_pb bool
var_input eye bool
var_output held_lamp bool
var_output index bool
var_output position dint
var_output boxes dint
var_output box_left bool
var s1 bool
var s2 bool
var s3 bool

xic index_pb osr s1 index ote held_lamp
xic index add position 1 position
xic eye ons s2 add boxes 1 boxes
xic eye osf s3 box_left
```

The program declares 1 storage bit for each one-shot, with the
[section](../reference/glossary.md#section) `var`. Use each storage bit for 1 one-shot
only. The first [operand](../reference/glossary.md#operand) of a one-shot is its storage
bit. The second operand of a pulse coil is its pulse bit.

| Rung | What it does |
|---|---|
| 1 | The `osr` sets the pulse bit `index` to 1 for 1 scan for each press. `held_lamp` follows the button. |
| 2 | A [contact](../reference/glossary.md#contact) reads the pulse bit. The `add` adds 1 to `position` for each press. |
| 3 | The `ons` gives power to the `add` for 1 scan for each box. |
| 4 | The `osf` sets the pulse bit `box_left` to 1 for 1 scan for each box that leaves. |

This drawing shows the 4 rungs. The letter P marks an `osr`, and the letter N marks an
`osf`. The storage bit of a pulse coil is under the
[coil](../reference/glossary.md#coil). The storage bit of an `ons` is over its box.

<!-- rung: use-one-shots-and-pulse-coils/conveyor.ld -->
![The 4 rungs of conveyor.ld as a ladder drawing. Rung 1: the contact index_pb, the pulse coil index with the letter P and the storage bit s1, then the coil held_lamp. Rung 2: the contact index, then the box add. Rung 3: the contact eye, the box ons with the storage bit s2, then the box add. Rung 4: the contact eye, then the pulse coil box_left with the letter N and the storage bit s3.](../assets/use-one-shots-and-pulse-coils-conveyor.svg)

2. Make the file `use-one-shots-and-pulse-coils.exs` in the root directory of your
   project, with this text. It sets the [inputs](../reference/glossary.md#input), runs 9
   [scans](../reference/glossary.md#scan) and prints the outputs of each scan in a fixed
   order. The third argument of `Logex.Runtime.scan/3` is the time since the last scan,
   in milliseconds. This program has no timer, so the time changes no
   [output](../reference/glossary.md#output).

```elixir
{:ok, conveyor} = Logex.compile_file("use-one-shots-and-pulse-coils/conveyor.ld")
shown = ["index", "position", "held_lamp", "boxes", "box_left"]

scan = fn state, label, inputs ->
  state = Logex.Runtime.put_inputs(conveyor, state, inputs)
  {outputs, state} = Logex.Runtime.scan(conveyor, state, 10)
  values = Enum.map_join(shown, " ", fn tag -> "#{tag}=#{outputs[tag]}" end)
  IO.puts(String.pad_trailing(label, 25) <> values)
  state
end

Logex.Runtime.instance(conveyor)
|> scan.("button held, box at eye", %{"index_pb" => 1, "eye" => 1})
|> scan.("button released", %{"index_pb" => 0})
|> scan.("button pressed", %{"index_pb" => 1})
|> scan.("button held", %{})
|> scan.("box leaves the eye", %{"eye" => 0})
|> scan.("new box at the eye", %{"eye" => 1})
|> scan.("box stays", %{})
|> scan.("box leaves, released", %{"eye" => 0, "index_pb" => 0})
|> scan.("button pressed", %{"index_pb" => 1})
```

3. Run the script:

```console
$ mix run use-one-shots-and-pulse-coils.exs
button held, box at eye  index=0 position=0 held_lamp=1 boxes=0 box_left=0
button released          index=0 position=0 held_lamp=0 boxes=0 box_left=0
button pressed           index=1 position=1 held_lamp=1 boxes=0 box_left=0
button held              index=0 position=1 held_lamp=1 boxes=0 box_left=0
box leaves the eye       index=0 position=1 held_lamp=1 boxes=0 box_left=1
new box at the eye       index=0 position=1 held_lamp=1 boxes=1 box_left=0
box stays                index=0 position=1 held_lamp=1 boxes=1 box_left=0
box leaves, released     index=0 position=1 held_lamp=0 boxes=1 box_left=1
button pressed           index=1 position=2 held_lamp=1 boxes=1 box_left=0
```

If `conveyor.ld` has an error, the script stops at its first line with a `MatchError`.
[Read a diagnostic](read-diagnostics.md) gives the steps.

## The result

Rung 2 adds 1 to `position` for each press, and rung 3 adds 1 to `boxes` for each box.
In this timing diagram, `index` and `box_left` are 1 for 1 scan only. Scan 1 gives no
pulse, but `index_pb` and `eye` are 1 in it.

<!-- timing: use-one-shots-and-pulse-coils-conveyor.timing.exs -->
![A timing diagram of the 9 scans of use-one-shots-and-pulse-coils.exs. The input index_pb is on in scan 1, in scans 3 to 7 and in scan 9. The pulse index is on in scans 3 and 9 only, and held_lamp has the same value as index_pb. The input eye is on in scans 1 to 4 and in scans 6 and 7. The value position gets to 1 in scan 3 and to 2 in scan 9, and boxes gets to 1 in scan 6. The pulse box_left is on in scans 5 and 8.](../assets/use-one-shots-and-pulse-coils-conveyor-run.svg)

| Scan | What changes | What the outputs show |
|---|---|---|
| 1 | The operator holds the button, and a box is at the sensor, when the program starts. | No pulse. `held_lamp` is 1: the `osr` gives the power flow that it gets. |
| 2 | The operator releases the button. | `held_lamp` is 0. |
| 3 | The operator presses the button. | A rising edge: `index` is 1, and `position` is 1. |
| 4 | The button stays held. | `index` is 0 again. `held_lamp` stays 1. |
| 5 | The box leaves the sensor. | A falling edge: `box_left` is 1. `boxes` stays 0, because scan 1 gave no pulse. |
| 6 | A new box comes to the sensor. | A rising edge: `boxes` is 1. |
| 7 | The box stays at the sensor. | `boxes` stays 1, because the `ons` gives no power. |
| 8 | The box leaves, and the operator releases the button. | `box_left` is 1, and `held_lamp` is 0. |
| 9 | The operator presses the button. | `position` is 2. |

## Under an event task and under a periodic task

A one-shot sees the power flow only when its program runs. In a
[configuration](../reference/glossary.md#configuration), the
[task](../reference/glossary.md#task) of the instance decides when the program runs. This
example runs 1 program under 2 tasks. Each instance counts the presses of the same push
button `pb`.

1. Make the file `use-one-shots-and-pulse-coils/lamp.ld`, with this text:

<!-- file: use-one-shots-and-pulse-coils/lamp.ld -->
```text
var_input pb bool
var_output presses dint
var s1 bool

xic pb ons s1 add presses 1 presses
```

2. Make the file `use-one-shots-and-pulse-coils/lamp.logex`, with this text. The
   instance `event_lamp` runs under the [event task](../reference/glossary.md#event-task)
   `on_tick`, which runs when `tick` rises. The instance `period_lamp` runs under the
   [periodic task](../reference/glossary.md#periodic-task) `fast`, every 10 ms.

<!-- file: use-one-shots-and-pulse-coils/lamp.logex -->
```text
task on_tick single tick priority 0
task fast interval 10 priority 1

var_global pb bool at panel.i.0
var_global tick bool at panel.i.1
var_global by_event dint
var_global by_period dint

program event_lamp lamp with on_tick
  event_lamp.pb pb
  event_lamp.presses by_event

program period_lamp lamp with fast
  period_lamp.pb pb
  period_lamp.presses by_period
```

3. Make the file `use-one-shots-and-pulse-coils-tasks.exs`, with this text. It prints
   the warnings of the configuration, then runs 10 cycles. Each cycle prints the time in
   ms, the 2 inputs, the 2 counts and the tasks that ran.

```elixir
{:ok, plant} = Logex.Configuration.compile_file("use-one-shots-and-pulse-coils/lamp.logex")
Enum.each(plant.warnings, &IO.puts(Logex.Diagnostic.format(&1)))

# Each entry gives the ms since the last cycle, the globals at input points that change
# before the cycle, and what the operator or the machine does.
entries = [
  {0, %{}, "start"},
  {10, %{"pb" => 1}, "press"},
  {10, %{"pb" => 0}, "release"},
  {10, %{"tick" => 1}, "tick"},
  {10, %{"tick" => 0, "pb" => 1}, "press"},
  {10, %{"tick" => 1}, "tick, held"},
  {10, %{"pb" => 0, "tick" => 0}, "release"},
  {5, %{"pb" => 1}, "short press"},
  {3, %{"pb" => 0}, "release"},
  {12, %{"tick" => 1}, "tick"}
]

IO.puts("time  pb  tick  by_event  by_period  ran")

Enum.reduce(entries, {Logex.Runtime.start(plant), 0}, fn {ms, changes, what}, {plant, time} ->
  {plant, _outputs, events} = Logex.Runtime.cycle(plant, ms, changes)
  ran = for {:ran, task, _instance, _time} <- events, do: task
  values = [time + ms] ++ Enum.map(~w(pb tick by_event by_period), &Logex.Runtime.get!(plant, &1))
  cells = Enum.zip_with(values, [4, 4, 6, 10, 11], &String.pad_leading("#{&1}", &2))
  IO.puts("#{cells}  #{String.pad_trailing(Enum.join(ran, " "), 13)} #{what}")
  {plant, time + ms}
end)
```

4. Run the script:

```console
$ mix run use-one-shots-and-pulse-coils-tasks.exs
use-one-shots-and-pulse-coils/lamp.logex: line 9: warning: `event_lamp` runs under the event task `on_tick`, and `lamp` runs an `ons` on line 5 of `lamp.ld`, whose storage bit is `s1`: an ons sees its rung only at the task's runs, so a pulse between two runs never fires it, and a rung that is the task's trigger is true at every run and never fires it
time  pb  tick  by_event  by_period  ran
   0   0     0         0          0  fast          start
  10   1     0         0          1  fast          press
  20   0     0         0          1  fast          release
  30   0     1         0          1  on_tick fast  tick
  40   1     0         0          2  fast          press
  50   1     1         1          2  on_tick fast  tick, held
  60   0     0         1          2  fast          release
  65   1     0         1          2                short press
  68   0     0         1          2                release
  80   0     1         1          2  on_tick fast  tick
```

| Time | What happens | What the counts show |
|---|---|---|
| 10 to 20 | The operator presses and releases `pb` between 2 runs of `on_tick`. | `period_lamp` counts the press. `event_lamp` does not run, and does not see it. |
| 40 to 60 | The operator holds `pb` while `tick` rises. | `event_lamp` sees the press at its run at 50, and counts it. |
| 65 to 68 | A press of 3 ms, shorter than the 10 ms of `fast`. | No task runs while `pb` is 1. Neither instance counts it. |

The warning of `event_lamp` gives this result before the program runs. A periodic task
sees each press that lasts longer than its interval.

## If it does not work

The column **What you see** gives some words of each message. Look for these words in
the message. [Instructions: contacts and coils](../reference/instructions-contacts-and-coils.md)
gives each [diagnostic](../reference/glossary.md#diagnostic) and each
[warning](../reference/glossary.md#warning) of a one-shot.

### Diagnostics when you compile

| What you see | Cause | What to do |
|---|---|---|
| `` is both the storage bit and the pulse bit `` | The `osr` or the `osf` has the same [tag](../reference/glossary.md#tag) as its storage bit and its pulse bit. | Declare a different tag for the pulse bit. |
| `` needs a storage bit of its own `` | 2 one-shots have the same storage bit. | Declare 1 storage bit for each one-shot. |
| `` keeps its storage bit in a bool `` | The storage bit is a [member](../reference/glossary.md#member) of an instance, or a bit of a member. | Declare a `bool` tag for the storage bit. |
| `` follows `ton t1` on its path `` | A one-shot comes after a [timer](../reference/glossary.md#timer) on its rung. | Put the one-shot on a new rung that starts with `xic t1.dn`. |
| A different message about an operand of a one-shot | The operand has a wrong form, for example a `var_input`, a `dint` or a number. | Use a `bool` tag of the section `var` or `var_output`. The pulse bit can also be the member `r` of a [counter](../reference/glossary.md#counter). |

### Warnings when you compile

| What you see | Cause | What to do |
|---|---|---|
| `` the one-shot then fires on the wrong scans `` | A different instruction writes the storage bit. | Remove that write. A contact can read the storage bit. |
| `` the last one in the scan decides it `` | An `ote` or a second pulse coil writes the pulse bit. | Write the pulse bit with 1 pulse coil only. To keep the event, [latch](../reference/glossary.md#latch) a different tag on the next rung: `xic index otl moving`. |
| `` sees its rung only at the task's runs `` | The program runs under an [event task](../reference/glossary.md#event-task). A one-shot sees an edge only when the [task](../reference/glossary.md#task) runs. A pulse bit stays 1 until the next run of the task. | If the one-shot must see each press, run the program under a [periodic task](../reference/glossary.md#periodic-task) whose interval is shorter than the shortest press. [Under an event task and under a periodic task](#under-an-event-task-and-under-a-periodic-task) shows both. [Use an event task](use-an-event-task.md) gives the rules. |

### When you run the scans

| What you see | Cause | What to do |
|---|---|---|
| A button that the operator holds at the start does nothing | The first scan gives no pulse. A restart also gives a first scan. | Release the button and press it again. |
| The instructions after an `ons` run 1 time, but they must follow the power flow | An `ons` gives power for 1 scan only. | Use `osr`, and read its pulse bit on the next rung. |
| An `add` after an `osr` or an `osf` adds 1 in each scan of a long press | An `osr` or an `osf` gives the instructions after it the power flow that it gets. | Read the pulse bit on the next rung. |
| A pulse bit stays 1 for more than 1 scan | The rung does not run. A `jmp` [jumps](../reference/glossary.md#jump) over it, or the `cal` of its [function block](../reference/glossary.md#function-block) is on a [false rung](../reference/glossary.md#false-rung). | If a `jmp` skips the rung, put the one-shot on a rung that the jump does not skip. If `cal` is on a false rung, put `cal` on a rung with no condition. |
| A pulse bit stays 1 after an [online edit](../reference/glossary.md#online-edit) | The edit removes the pulse coil in the scan of its pulse. The edit report gives `{:held, "index", 1}`. | In the same edit, write the pulse bit, for example with the rung `otu index`. |
| A one-shot in a function block gives a pulse when `cal` first gets power | Only the program's instance has a first scan. The first run of the block in a later scan compares the power flow with the [initial value](../reference/glossary.md#initial-value) of the storage bit. | Put `cal` on a rung with no condition. If `cal` must have a condition, give the storage bit of an `osf` no initial value. |
| A rising edge gives no pulse after an online edit | The edit adds the one-shot or changes its rung. The one-shot gives no pulse in its first run after the edit. | Make the edge again. |

## See also

- [Instructions: contacts and coils](../reference/instructions-contacts-and-coils.md):
  each rule of `ons`, `osr` and `osf`, with the forms of the storage bit and the pulse
  bit.
- [Function blocks](../reference/function-blocks.md): what a block does while its `cal`
  is on a false rung.
- [Use an event task](use-an-event-task.md): a program that runs only on an event.
- [Online edit](../reference/online-edit.md): what an edit does to a one-shot and to its
  pulse bit.
- [Glossary](../reference/glossary.md): the words of this guide.
