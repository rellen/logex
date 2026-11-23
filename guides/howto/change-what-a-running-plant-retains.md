# Change what a running plant retains

This guide is for a reader who runs a [plant](../reference/glossary.md#plant) and wants
to add or remove the [qualifier](../reference/glossary.md#qualifier) `retain` with no
stop. It shows what an [online edit](../reference/glossary.md#online-edit) of a
qualifier does to the values, to the next
[warm restart](../reference/glossary.md#warm-restart) and to the
[store](../reference/glossary.md#store).

> #### Warning {: .warning}
>
> Do not use logex for a safety function, for example an emergency stop. logex can stop
> at any time. [Safety and limits](../explanation/safety-and-limits.md) gives the limits
> of logex.

## Before you start

You must know the steps of an edit of a plant:

- [Edit a running plant](edit-a-running-plant.md), if a
  [runner](../reference/glossary.md#runner) runs your plant
- [Edit a running plant without the runner](edit-a-plant-without-the-runner.md), if
  your [host](../reference/glossary.md#host) calls `Logex.Runtime.cycle/3`

You must know what [retain](../reference/glossary.md#retain) does.
[Keep values across a restart](keep-values-across-a-restart.md) shows it.

## What the edit does

| Moment | What logex does |
|---|---|
| The [accept](../reference/glossary.md#accept) | The forecast has 1 entry for each [global](../reference/glossary.md#global) or [tag](../reference/glossary.md#tag) with a different qualifier: `:retain_added` or `:retain_removed`. The entry gives the value at that moment. |
| The [test](../reference/glossary.md#test) | logex writes nothing. Each value stays. |
| A warm restart after the test | The restart keeps the values that the new plant retains. |
| A write of the store after the test | The runner writes the values that the new plant retains. |
| The [untest](../reference/glossary.md#untest) | The report has the reverse entries. The old plant decides again what a warm restart keeps. |

The words `non_retain` and no qualifier have the same effect. A change from one to the
other gives no entry.

## The example

The plant `tally.logex` counts boxes. The program `tally.ld` retains its
[counter](../reference/glossary.md#counter) `boxes` and its
[output](../reference/glossary.md#output) `full`. The plant retains the global
`total_boxes`.

<!-- file: tally.ld -->
```text
var_input eye bool
var_output retain full bool
var_external total_boxes dint
var retain boxes ctu
var e bool

xic eye ctu boxes 3
xic eye ons e add total_boxes 1 total_boxes
xic boxes.q otl full
```

<!-- file: tally.logex -->
```text
// tally.logex -- a box counter whose count and total survive a warm restart
var_global eye_1              bool at panel.i.0
var_global retain total_boxes dint 0
var_global case_full          bool

program t1 tally
  t1.eye  eye_1
  t1.full case_full
```

## Steps

1. **Change the qualifier in a copy of the file.** The example removes `retain` from the
   line `var retain boxes ctu`.

The script `requalified.exs` makes the new plant from the text of the 2 files. It has no
second directory.

<!-- part of: requalified.exs -->
```elixir
{:ok, plain} = Logex.compile(String.replace(ld, "var retain boxes", "var boxes"), name: "tally")
{:ok, candidate} = Logex.Configuration.compile("tally", text, %{"tally" => plain})
```

2. **Do the accept, and read the forecast.** Make sure that each entry names a value
   that you want to change.

3. **Do the test.** The report has the entries of the forecast.

<!-- part of: requalified.exs -->
```elixir
{edit, rt, report} = Logex.Configuration.Edit.test(edit, rt)
```

> #### Caution {: .error}
>
> After a `:retain_removed` entry, the next warm restart sets the value to its
> [initial value](../reference/glossary.md#initial-value). The next write of the store
> does not have the value. If you do an untest after that, the value does not come back.

4. **Do the assemble, and put the new qualifier in the files of your host.**

### The complete script

The script counts 1 box. It does the test and a warm restart, and then the untest and a
second warm restart. Each restart starts from the same state, because the script does
not keep the result of the first restart.

```elixir
{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
{:ok, ld} = File.read("tally.ld")
{:ok, text} = File.read("tally.logex")
{:ok, plain} = Logex.compile(String.replace(ld, "var retain boxes", "var boxes"), name: "tally")
{:ok, candidate} = Logex.Configuration.compile("tally", text, %{"tally" => plain})

count = fn rt, label ->
  IO.puts("#{label}  t1.boxes.cv=#{Logex.Runtime.get!(rt, "t1.boxes.cv")}")
  rt
end

rt =
  Enum.reduce([1, 0, 1, 0], Logex.Runtime.start(plant), fn eye, rt ->
    elem(Logex.Runtime.cycle(rt, 10, %{"eye_1" => eye}), 0)
  end)

{:ok, edit, _forecast} = Logex.Configuration.Edit.accept(rt, candidate)
{edit, rt, report} = Logex.Configuration.Edit.test(edit, rt)
IO.puts("test")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
count.(rt, "under test   ")
rt |> Logex.Runtime.restart(:warm) |> count.("warm restart ")

{_edit, rt, report} = Logex.Configuration.Edit.untest(edit, rt)
IO.puts("untest")
Enum.each(report, &IO.puts("        #{inspect(&1)}"))
rt |> Logex.Runtime.restart(:warm) |> count.("warm restart ")
```

```console
$ mix run requalified.exs
test
        {:retain_removed, "t1.boxes", %{"cu" => 0, "cv" => 1, "ov" => 0, "pv" => 3, "q" => 0, "r" => 0}}
under test     t1.boxes.cv=1
warm restart   t1.boxes.cv=0
untest
        {:retain_added, "t1.boxes", %{"cu" => 0, "cv" => 1, "ov" => 0, "pv" => 3, "q" => 0, "r" => 0}}
warm restart   t1.boxes.cv=1
```

## The result

| Line of the output | What it shows |
|---|---|
| `{:retain_removed, "t1.boxes", %{...}}` | The new plant does not retain the counter `boxes` of the instance `t1`. The map gives each [member](../reference/glossary.md#member) of the counter. The count `cv` is 1. |
| `under test     t1.boxes.cv=1` | The test does not change the count. |
| `warm restart   t1.boxes.cv=0` | A warm restart under test starts the count at 0. |
| `{:retain_added, "t1.boxes", %{...}}` | The old plant retains the counter. |
| `warm restart   t1.boxes.cv=1` | A warm restart after the untest keeps the count. |

The name of an entry is the name of a global, or the path of a tag in its
[instance](../reference/glossary.md#instance). Examples are `"total_boxes"` for the
global and `"t1.full"` for the output `full` of `t1`.

Through a runner, the entries are the same. If the runner has a store, the write of the
store after the test has no line for `t1.boxes`.

## If it does not work

| What you see | Cause | What to do |
|---|---|---|
| The forecast is the empty list `[]`. | The qualifier is the same in the 2 plants, or the change is from `non_retain` to no qualifier. | Compare the 2 files. |
| A value is at its initial value after a warm restart. | The plant that ran at the restart did not retain the value. | Do the edit before the restart. |
| A `:retain_added` entry, and the value is not in the store. | The runner did not write the store after the test. | Wait for the next write of the store. [Keep values on disk](keep-values-on-disk.md) gives the moments of a write. |

## See also

- [Edit a running plant](edit-a-running-plant.md): the steps of the edit through the
  runner.
- [Keep values across a restart](keep-values-across-a-restart.md): how to declare
  `retain`.
- [Retained values](../reference/retained-values-and-store.md) and [The store](../reference/store.md): the rules
  of a warm restart and of the store.
- [Online edit](../reference/online-edit.md): the path of each entry.
- [Glossary](../reference/glossary.md): the technical words.
