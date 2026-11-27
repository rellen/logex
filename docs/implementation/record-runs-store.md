# Runs and tables of the records: the store

This page is for a contributor who reads a decision record about the text of the store. It holds the
runs, the measurements and the long tables of record 0017, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0017. The store on disk

These tables, runs and this script support
[0017. The store on disk](../adr/0017-the-store-on-disk.md).

### The words of the record

| Word | Meaning on this page |
|---|---|
| Fresh start | `Logex.Runner.start_link/1` with the option `retain:` |
| Warm start | A fresh start that reads the store and lays its values over the new [resource](../../guides/reference/glossary.md#resource). It is the default. A warm start is not a [warm restart](../../guides/reference/glossary.md#warm-restart): a warm restart (`Logex.Runner.restart/2`) reads no store |
| Cold start | A fresh start with `start: :cold`. It reads the store, lays none of its values, and writes a new store |
| Store reader | The code that reads the store at a fresh start, in `lib/logex/retain.ex` |
| Dropped value | A stored value that a start does not keep. The start reports it in `dropped` of `Logex.Runner.status/1` |
| Copy | A file `<store>.dropped.<n>` beside the store. It holds the bytes of the store as a start read it |
| Owed copy | A copy that a start must make, because its first try failed |
| Naming lines | The `resource` line and the `program` lines of the store. They name the program that wrote it |
| Way out | The end of a refusal that says how to start with the store refused: a cold start, which copies the store first |
| Hand edit | A change that a person makes to the store in a text editor while the runner is stopped |

### What can change the store between 2 runs

| Event | What the next start finds |
|---|---|
| A crash or a power failure during a write | The old store, the new store, or, on some file systems, a store without its last bytes |
| A copy of the file that stops part of the way | A store without its last lines |
| An operator who corrects 1 value after an incident (decision 284) | A store with 1 line changed, possibly with CRLF line ends |
| A deploy of a changed program | A store of the program before the deploy |
| The files of 1 production line copied to a second production line, or an old backup put back | A store of a different configuration |
| An older logex put back after a failed upgrade | A store that a newer logex wrote |
| An [online edit](../../guides/reference/glossary.md#online-edit) that nobody wrote to the files | A store of a program that the files do not hold |

The first store had no end line. A test run shows the risk. It cuts a store of that
first version after its 6th line. The cut store starts the box counter of this record
with `t1.boxes.cv` at 0 and `full` at 0, and gives no message.

### The rules in a run

The script `examples/0017-the-store-on-disk.exs` shows the rules as numbered results. It
runs a box counter on a
[simulated device](../../guides/reference/glossary.md#simulated-device), the panel, on
the manual clock. The program `tally.ld` counts boxes at a photo-eye, and latches `full`
at 3 boxes. Its [configuration](../../guides/reference/glossary.md#configuration),
`tally.logex`, adds each box to the retained
[global](../../guides/reference/glossary.md#global) `total_boxes`.

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

The script counts 4 boxes and stops. Then it starts a deploy that changes 2 lines of
`tally.ld`, and puts its copy back. Then it cuts the store and edits it by hand.

```elixir
alias Logex.IO.Sim
alias Logex.Runner
alias Logex.Runner.Clock.Manual

{:ok, plant} = Logex.Configuration.compile_file("tally.logex")
Enum.each(Path.wildcard("tally.retain*"), &File.rm/1)

# The manual clock, its wall clock 2026-10-30T14:00:00Z.
{:ok, clock} = Manual.start_link(now: 1_793_368_800_000)
{:ok, panel} = Sim.start_link(clock: clock)

opts = [
  configuration: plant,
  io: %{"panel" => {Sim, sim: panel}},
  clock: {Manual, clock},
  retain: "tally.retain"
]

show = fn runner, title ->
  %{dropped: dropped, copy: copy, warning: warning} = Runner.status(runner).retain
  IO.puts(title)
  IO.puts("  t1.boxes.cv=#{Runner.get!(runner, "t1.boxes.cv")} copy=#{inspect(copy)}")
  IO.puts("  dropped=#{inspect(dropped)}")
  IO.puts("  warning=#{inspect(warning)}")
end

refused = fn title ->
  IO.puts(title)

  try do
    Runner.start_link(opts)
  rescue
    error in ArgumentError ->
      IO.puts(error.message)
      error.message
  end
end

edit = fn from, to ->
  File.write!("tally.retain", String.replace(File.read!("tally.retain"), from, to))
end

files = fn ->
  IO.puts("  files: " <> Enum.join(Enum.sort(Path.wildcard("tally.retain*")), " "))
end

{:ok, runner} = Runner.start_link(opts)

for eye <- [1, 0, 1, 0, 1, 0, 1, 0] do
  Sim.set(panel, "panel.i.0", eye)
  Manual.advance(clock, 1000)
end

:ok = Runner.stop(runner)
IO.puts("1. Four boxes, then a stop. The store:")
IO.write(File.read!("tally.retain"))

# A deploy: boxes made a ctu_int, and full not retained.
source =
  File.read!("tally.ld")
  |> String.replace("var retain boxes ctu", "var retain boxes ctu_int")
  |> String.replace("var_output retain full bool", "var_output full bool")

{:ok, changed} = Logex.compile(source, name: "tally")

{:ok, deploy} =
  Logex.Configuration.compile("tally", File.read!("tally.logex"), %{"tally" => changed})

{:ok, runner} = Runner.start_link(Keyword.put(opts, :configuration, deploy))
show.(runner, "2. A fresh start of the deploy")
:ok = Runner.stop(runner)

File.cp!("tally.retain.dropped.1", "tally.retain")
{:ok, runner} = Runner.start_link(opts)
show.(runner, "3. The copy put back, and a fresh start of the program before the deploy")
:ok = Runner.stop(runner)

text = File.read!("tally.retain")
File.write!("tally.retain", binary_part(text, 0, byte_size(text) - 40))
refused.("4. The store cut short by 40 bytes")

{:ok, runner} = Runner.start_link(opts ++ [start: :cold])
show.(runner, "5. A start with start: :cold")
:ok = Runner.stop(runner)
files.()

edit.("configuration tally", "configuration line_2")
refused.("6. The configuration line edited by hand")

edit.("configuration line_2", "configuration tally")
edit.("t1.boxes.cv dint 0\n", "t1.boxes.cv dint 0\nt1.boxes.cv dint 2\n")
refused.("7. A line added by hand, and the count not changed")

edit.("t1.boxes.cv dint 0\n", "")
message = refused.("8. The old line taken out, and the digest not mended")

# The digest line mended as the refusal gives it, the word of the scheme and the digest.
[_, stored, digest] =
  Regex.run(~r/`(digest \w+ \w+)` is not .* write `(digest \w+ \w+)`/U, message)

edit.(stored, digest)
edit.("\n", "\r\n")
{:ok, runner} = Runner.start_link(opts)
show.(runner, "9. The digest mended, the store saved with CRLF line ends")
:ok = Runner.stop(runner)
```

Run it from the directory `examples/`:

```console
$ mix run 0017-the-store-on-disk.exs
1. Four boxes, then a stop. The store:
logex retain 4
configuration tally written 2026-10-30T14:00:08Z
resource md5 013cc059392445fdcc1e84c9b0de6118
program tally md5 bd882e28a8159d8e8a4ea56ade7b36b6
global total_boxes dint 4
instance t1 tally
t1.boxes ctu
t1.boxes.cu bool 0
t1.boxes.cv dint 4
t1.boxes.ov bool 0
t1.boxes.pv dint 3
t1.boxes.q bool 1
t1.boxes.r bool 0
t1.full bool 1
digest md5 8cfa2e4d3e860b659fe02173b2f9f18a
end 16 lines
2. A fresh start of the deploy
  t1.boxes.cv=0 copy="tally.retain.dropped.1"
  dropped=[{"t1.boxes", {:retyped, "ctu", "ctu_int"}}, {"t1.full", :unretained}]
  warning="tally.retain: the store was written by another program than the one this start was given: `tally`'s text differs; whether by a deploy of changed files, or an edit tested or assembled online that never reached the files, this start runs the program it was given, with the store's retained values laid over it by name and type"
3. The copy put back, and a fresh start of the program before the deploy
  t1.boxes.cv=4 copy=nil
  dropped=[]
  warning=nil
4. The store cut short by 40 bytes
tally.retain: line 15: `digest md5 8cfa2e` is the store's last line, and no end line: a store of `logex retain 4` ends with `end <count> lines`, its count of lines, so this one was cut short, and a store cut short is not read: start it with start: :cold to start over it, which copies it first to the next `.dropped.<n>` beside it and then writes a new store over it
5. A start with start: :cold
  t1.boxes.cv=0 copy="tally.retain.dropped.2"
  dropped=[]
  warning=nil
  files: tally.retain tally.retain.dropped.1 tally.retain.dropped.2
6. The configuration line edited by hand
tally.retain: line 2: the store is of configuration `line_2`, and this configuration is `tally`: a store starts only the configuration it was written for, so a renamed configuration starts only cold: start it with start: :cold to start over it, which copies it first to the next `.dropped.<n>` beside it and then writes a new store over it
7. A line added by hand, and the count not changed
tally.retain: line 10: `t1.boxes.cv dint 2` names what line 9 names already
tally.retain: line 17: the store's end line counts 16 lines, and the store has 17: a line was lost or doubled, or a hand edit added or removed one without changing the count, which counts every line, the end line among them, and the store is not read
8. The old line taken out, and the digest not mended
tally.retain: line 15: `digest md5 d1e15a92bd876216f0fa2e5bf5537c82` is not the digest of the store's value lines, which is `md5 903bc36c4f35937a4479949b473cd42e`: a value line was edited, added or removed by hand and the digest not mended, so the store is not read; to keep the edit write `digest md5 903bc36c4f35937a4479949b473cd42e` in its place, and to start anyway: start it with start: :cold to start over it, which copies it first to the next `.dropped.<n>` beside it and then writes a new store over it
9. The digest mended, the store saved with CRLF line ends
  t1.boxes.cv=2 copy=nil
  dropped=[]
  warning=nil
```

Each result shows these rules:

1. The store is text. Its `digest` line holds the digest of its value lines (decision
   604). Each digest comes after the word of its scheme, `md5` (decision 641). Its end
   line counts 16 lines (decisions 276, 355 and 530).
2. The deploy drops 2 values and reports each (decision 277). It copies the store before
   its first write (decision 360). It warns, because the text of `tally` differs
   (decision 528).
3. With the copy back, the count is 4 again. That start drops nothing, so it makes no
   copy, and `.dropped.1` stays.
4. The cut leaves part of the `digest` line last. The start refuses the store, with the
   way out (decision 417).
5. The cold start copies the cut store to `.dropped.2` first. Then it writes the initial
   values (decision 417).
6. A store of `line_2` does not start `tally`. The refusal has the way out (decisions 285
   and 545).
7. The refusal names 2 problems. Neither has the way out, because a person can correct
   both (decision 545).
8. The hand edit changes a value line and not the `digest` line. So the start refuses the
   store. The refusal gives the `digest` line to write and the way out (decisions 604 and
   641).
9. The hand edit with the `digest` line from the refusal starts with a count of 2. Its
   CRLF line ends read as LF (decision 410).

### The count of lines

A file system can also lose the last bytes of a file. A cut removes bytes from the end of
a file only. So the last line counts the lines: a cut removes that line or changes it
(decisions 355 and 409). The count includes the header and the end line, as `wc -l`
counts them. It catches each cut:

| Where the cut is | The last line that stays | Result |
|---|---|---|
| At the end of a line before the end line | A line that is not an end line | Refused |
| In a line before the end line, also in the digits of a number | Part of a line | Refused |
| In the end line | `end` and a count that is too small, or a count with no word after it | Refused |
| Only the last newline | The whole end line | Read |

`test/logex/retain_store_test.exs` cuts a store that a runner wrote at each byte offset,
and starts from each cut. The store reader refuses each cut, except the cut of the last
newline. The count also catches a line that is lost or doubled. It catches a hand edit
that adds or removes a line and does not change the end line, as result 7 shows. A hand
edit that changes 1 line, and adds or removes none, needs no change to the end line. It
needs a change to the `digest` line, as results 8 and 9 show.

Nothing follows the end line in a store that logex writes. So the store reader refuses
an empty line after it (decision 411).

The same record has more tables on a second page.
[Runs and tables of the records: the copies of the store](record-runs-store-copies.md)
gives its versions, naming lines, copies and refusals.

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
