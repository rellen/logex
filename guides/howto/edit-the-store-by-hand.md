# Edit the store by hand

This guide is for a reader whose [runner](../reference/glossary.md#runner) has a
[store](../reference/glossary.md#store) that holds a wrong retained value. For example, a
retained [subscript](../reference/glossary.md#subscript) [trips](../reference/glossary.md#trip)
the [plant](../reference/glossary.md#plant) again at each
[warm restart](../reference/glossary.md#warm-restart), and at each
[fresh start](../reference/glossary.md#fresh-start) without `start: :cold`. You stop the
runner, change 1 value in the store with a text editor, and start the runner from the
store.

> #### Warning {: .warning}
>
> Make sure that the machine is safe before you start the runner again. The start sets
> each retained value from the store. This includes the value that you change. A
> [rung](../reference/glossary.md#rung) that reads the value can set an
> [output](../reference/glossary.md#output) in the first
> [round](../reference/glossary.md#round), before a person does anything. logex checks
> the form and the [type](../reference/glossary.md#type) of the value. It does not check
> that the value is correct for the machine.

> #### Caution {: .error}
>
> Stop the runner before you edit the store. A runner holds each retained value in
> memory. This is also true when its status is `:tripped`. The runner writes the values
> in memory to the store at each trip and each stop. While it runs, it also writes them
> at each period of `retain_period:`, 1000 ms unless you set it. Each of these writes
> goes over your edit.

This table gives what occurs when the runner holds 8 in memory and you edit the store to
0, as in [the example](#an-example-a-subscript-past-the-end-of-an-array).

| You edit the store | Then the runner | The next start reads |
|---|---|---|
| While the runner runs | Writes 8 over the edit in 1 period at most | 8 |
| While the status is `:tripped` | Starts from 8 in memory at a warm restart, and trips again. The trip or the stop writes 8 over the edit. | 8 |
| After the stop | Does not run | 0 |

## Before you start

You must have:

- A runner with a store, as in [Keep retained values on disk](keep-values-on-disk.md).
- The options that you gave to `Logex.Runner.start_link/1`, for example
  `retain: "packer.retain"`. Step 7 uses them again.
- A text editor that saves ASCII text with no tab and no byte-order mark.
- The correct value of the [tag](../reference/glossary.md#tag).

A hand edit changes only the value that you select. A
[cold restart](../reference/glossary.md#cold-restart) sets each retained value to its
[initial value](../reference/glossary.md#initial-value). An
[online edit](../reference/glossary.md#online-edit) can add a rung that writes a correct
value. [Restart after a trip](restart-after-a-trip.md) gives these 2 other ways.

## Steps

1. Find the tag and the store before you stop the runner. The stop ends the status. For
   a trip by a [major fault](../reference/glossary.md#major-fault), the status gives the
   [instance](../reference/glossary.md#instance) and the fault.

<!-- fragment: the fault of a trip and the path of the store, with runner the pid or the name of the runner -->
```elixir
%{trip: {:fault, _task, instance, fault}, retain: %{path: store}} =
  Logex.Runner.status(runner)
```

   `fault.file`, `fault.line` and `fault.read` give the file, the line and the subscript
   that the [scan](../reference/glossary.md#scan) read. Read that line of the file to
   find the tag. `store` gives the path of the store.

> #### Caution {: .error}
>
> If a supervisor starts the runner, stop it through the supervisor. If the child spec
> gives `restart: :permanent`, `Logex.Runner.stop/1` does not stop the plant. The
> supervisor starts a new runner from the store immediately.

2. Stop the runner. The stop writes 0 to each output, then it writes the store. The child
   id is `Logex.Runner` if your child spec gives no other `id:`.

| The runner | Stop it with |
|---|---|
| Has no supervisor | `:ok = Logex.Runner.stop(runner)` |
| Has a supervisor | `:ok = Supervisor.terminate_child(supervisor, Logex.Runner)` |

3. Copy the store to a backup.

```console
$ cp packer.retain packer.retain.bak
```

4. Open the store in the text editor. Find the line of the tag. These are the forms of a
   line that holds a value:

| Line | Example |
|---|---|
| A [global](../reference/glossary.md#global) | `global total_boxes dint 4` |
| A tag of an instance | `s1.place dint 8` |
| A [member](../reference/glossary.md#member) of a [timer](../reference/glossary.md#timer) or a [counter](../reference/glossary.md#counter) | `t1.boxes.cv dint 4` |
| An [array](../reference/glossary.md#array), all its [elements](../reference/glossary.md#element) on 1 line, in order | `s1.weights int[8] 410 520 380 600 450 470 390 505` |
| The last sample of a [trigger](../reference/glossary.md#trigger) | `trigger arm 0` |

5. Change only the value: the words after the type. A value of an array has 1 word for
   each element. Keep 1 space between the words. Do not add, move or remove a line. The
   start reads these forms of a value:

| You write | The start |
|---|---|
| An integer, for example `-1`, `16#FF` or `1_000` | Reads it. |
| A real for a `real` or an `lreal`, for example `2.5` or `1.5E3` | Reads it. |
| An integer for a `real` or an `lreal` | Reads the nearest real. |
| `0` or `1` for a `bool` | Reads it. |
| A value out of the range of the type, a real for an integer type, or `2` for a `bool` | Drops the value. The tag gets its initial value. |
| `+0`, `-16#1`, `.5`, a word such as `true`, or a space or a comment after the value | Refuses the store. |

   In the store of the example, step 5 changes 1 line:

```diff
 instance s1 packer
-s1.place dint 8
+s1.place dint 0
 s1.weights int[8] 410 520 380 600 450 470 390 505
 end 8 lines
```

6. Save the store.
7. Start the runner with the options of the stopped runner. Do not give `start: :cold`.

| The runner | Start it with |
|---|---|
| Has no supervisor | `{:ok, runner} = Logex.Runner.start_link(opts)` |
| Has a supervisor, with `restart: :permanent` or `:transient` | `{:ok, runner} = Supervisor.restart_child(supervisor, Logex.Runner)` |
| Has a supervisor, with the default `restart: :temporary` | `{:ok, runner} = Supervisor.start_child(supervisor, {Logex.Runner, opts})` |

8. Make sure that the value is correct and that `dropped` is `[]`.

<!-- fragment: the check after the start, with runner the pid of the new runner -->
```elixir
IO.inspect(Logex.Runner.get!(runner, "s1.place"), label: "s1.place")
IO.inspect(Logex.Runner.status(runner).retain.dropped, label: "dropped")
```

   For the example, step 8 prints `s1.place: 0` and `dropped: []`. If `dropped` holds a
   name, go to [The start drops a value](#the-start-drops-a-value).

## The result

The runner runs from the store, with your value. The start does not write the store.
When the runner next writes the store, it writes your value with the other values.

> #### Note {: .info}
>
> The hand edit corrects the value. It does not correct its cause. If a rung wrote the
> wrong value, correct the [program](../reference/glossary.md#program), or the rung
> writes the value again.
> [Edit a running plant](edit-a-running-plant.md) gives the steps.

## If it does not work

### The stop and the edit

| What you see | Cause | What to do |
|---|---|---|
| The start trips with the old fault, and the store holds the old value | You edited before the stop, or a supervisor started the runner again | Stop the runner as step 2 gives. Do the steps again from step 3. |
| About 1 s after your edit, the store holds the old value | The runner runs and writes the store at each period | Stop the runner. Do the steps again from step 3. |
| The stop returns `{:error, {:retain, :timeout}}` | The write did not finish within the write limit: a slow disk, or a very big store | Wait until the write ends. Until then, a start on the store in the same Erlang VM raises an `ArgumentError` that names it. Then do the steps again from step 3. |
| The stop returns `{:error, {:retain, reason}}`, with a different reason | The write failed. The store holds the values of an earlier write. | Check each value of the store in step 4. |

### The start refuses the store

`Logex.Runner.start_link/1` raises an `ArgumentError` that names the store, and the runner
does not start. Put the backup back with `cp packer.retain.bak packer.retain`, then do the
steps again from step 4. [Recover from a refused store](recover-a-refused-store.md) gives
each message, for example of a tab, a comment line or an empty line.

| What you see | Cause | What to do |
|---|---|---|
| `is no number` | The value has a form that the start does not read | Write the value in a form of step 5. |
| `holds one value, and the line gives` | There is a word after the value, for example a comment | Remove each word after the value. |
| `holds 8 values, one an element` | An array line has too many or too few values | Write 1 value for each element. |
| `the store's end line counts` | You added or removed a line | Change only the value. |

### The start drops a value

The runner runs with the initial value of each tag that `dropped` names, and the next
stop writes that value to the store. The start also copies the store, with your edit, to
a numbered copy, for example `packer.retain.dropped.1`. `copy` in the status gives its
name.
Each row of the table gives 1 entry of `dropped`.

| What you see | Cause | What to do |
|---|---|---|
| `{"s1.place", :misfit}` | The value is not of the type, or out of its range | Stop the runner. Do steps 4 to 8 again, with a value of step 5. |
| `{"s1.place", {:retyped, :int, :dint}}` | You changed the type word | Stop the runner. Do steps 4 to 8 again, and keep `dint`. |
| `{"s1.plase", :undeclared}` | You changed the name of the tag | Stop the runner. Do steps 4 to 8 again, and keep the name. |
| `{"s1.weights", :misfit}`, and each element has its initial value | 1 element is out of range. The start drops the whole array. | Stop the runner. Do steps 4 to 8 again, and write each element. |
| `{"t1.boxes.pv", {:preset, 5, 3}}` | The [instruction](../reference/glossary.md#instruction) of the counter gives the [preset](../reference/glossary.md#preset) 3. The runner uses that preset. | Do not edit the line again. Change the program: [Edit a running plant](edit-a-running-plant.md). |

### After the start

| What you see | Cause | What to do |
|---|---|---|
| The tag has its initial value, and `dropped` is `[]` | You removed the line of the tag and changed the end line. The start does not report a lost line. | Stop the runner. Put the backup back. Do steps 4 to 8 again, and change only the value. |
| Each value is the initial value, and `dropped` is `[]` | The options give `start: :cold`. The start wrote the initial values over the store. | Stop the runner. Remove the option and put the backup back. Do steps 4 to 8 again. |
| The plant runs, then trips again with the same fault | The program writes the wrong value again | Correct the program: [Edit a running plant](edit-a-running-plant.md). |

## An example: a subscript past the end of an array

This example puts the weight of each box in its place in a case of 8 places. The rung
that adds 1 to `place` does not set it back to 0 after the 8th box. The 8th box sets
`place` to 8. The rung `move weight weights[place]` then writes to element 8 of
`weights`, which has the elements 0 to 7. The runner trips.

In the root directory of your project, make the directory `edit-the-store-by-hand`. Put
these 2 files in it.

<!-- file: edit-the-store-by-hand/packer.ld -->
```text
// packer.ld -- the weight of each box in its place in a case, places 0 to 7
var_input  weight  int
var_input  eye     bool
var retain place   dint
var retain weights int[8]
var e bool

// the scale is under the place: its weight goes to that place
move weight weights[place]
// the eye sees the box leave: the next box goes to the next place
xic eye ons e add place 1 place
```

<!-- rung: edit-the-store-by-hand/packer.ld -->
![The 2 rungs of packer.ld as a ladder drawing. Rung 1: no contact, then the instruction move, from weight to the element place of weights. Rung 2: the contact eye, the one-shot e, then the instruction add, of place and 1, to place. Each rung has its comment over it.](../assets/edit-the-store-by-hand-packer.svg)

<!-- file: edit-the-store-by-hand/packer.logex -->
```text
// packer.logex -- a scale and an eye on the panel
task fast interval 10 priority 1
var_global weight int  at panel.i.0
var_global eye    bool at panel.i.1

program s1 packer with fast
  s1.weight weight
  s1.eye    eye
```

Run the script in a new project. It deletes each file whose name starts with
`packer.retain`, and that includes a backup. In the root directory, save this script as
`edit-the-store-by-hand.exs`. It runs the plant on the manual
[clock](../reference/glossary.md#clock) with a
[simulated device](../reference/glossary.md#simulated-device). It does steps 1 to 8, and
it edits the store with `String.replace/3`, as a person does in a text editor.

```elixir
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("edit-the-store-by-hand/packer.logex")

# No store and no backup from an earlier run.
for file <- File.ls!(), String.starts_with?(file, "packer.retain"), do: File.rm!(file)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "packer.retain"
]

{:ok, runner} = Runner.start_link(opts)

# 8 boxes: the scale weighs each box, then the eye sees it leave.
for weight <- [410, 520, 380, 600, 450, 470, 390, 505] do
  Sim.set(panel, "panel.i.0", weight)
  Manual.advance(clock, 10)
  Sim.set(panel, "panel.i.1", 1)
  Manual.advance(clock, 10)
  Sim.set(panel, %{"panel.i.0" => 0, "panel.i.1" => 0})
  Manual.advance(clock, 10)
end

# Step 1: find the tag and the store.
%{trip: {:fault, _task, instance, fault}, retain: %{path: store}} = Runner.status(runner)
IO.puts("trip: #{instance}, #{fault.file}, line #{fault.line}, read #{inspect(fault.read)}")
IO.puts("store: #{store}")

# Step 2: stop the runner. Step 3: copy the store to a backup.
:ok = Runner.stop(runner)
File.cp!("packer.retain", "packer.retain.bak")
IO.write(File.read!("packer.retain"))

# Steps 4 to 6: the hand edit, as a person makes it in a text editor: 8 becomes 0.
text = File.read!("packer.retain")
File.write!("packer.retain", String.replace(text, "s1.place dint 8\n", "s1.place dint 0\n"))

# Step 7: start the runner from the store. Step 8: check the value and dropped.
{:ok, runner} = Runner.start_link(opts)
IO.inspect(Runner.get!(runner, "s1.place"), label: "s1.place")
IO.inspect(Runner.status(runner).retain.dropped, label: "dropped")
Manual.advance(clock, 10)
IO.inspect(Runner.status(runner).status, label: "status")
:ok = Runner.stop(runner)
```

```console
$ mix run edit-the-store-by-hand.exs
trip: s1, edit-the-store-by-hand/packer.ld, line 9, read {8}
store: packer.retain
logex retain 3
configuration packer written 2026-10-30T14:00:00Z
resource 8b63f9773c49e74285e113188acd3831
program packer 30d7542a6ecbc37ca8d21f8249e33968
instance s1 packer
s1.place dint 8
s1.weights int[8] 410 520 380 600 450 470 390 505
end 8 lines
s1.place: 0
dropped: []
status: :running
```

The [fault](../reference/glossary.md#fault) is at line 9 of `packer.ld`, whose subscript
is `place`. The stop writes `s1.place dint 8`. After the edit, the start reads 0 and drops
nothing, and the plant runs.

## See also

- [The store](../reference/store.md): each line
  of the store, what a start keeps and what it drops.
- [Restart after a trip](restart-after-a-trip.md): the cold restart and the online edit.
- [Recover from a refused store](recover-a-refused-store.md): a store that the start does
  not read.
- [Keep retained values on disk](keep-values-on-disk.md): give a runner a store.
- [Run a plant under a supervisor](run-under-a-supervisor.md): a runner in a supervision
  tree.
- [Warm and cold restarts](../explanation/warm-and-cold-restarts.md): what each restart
  keeps, and why.
- [Glossary](../reference/glossary.md): the words of this guide.
