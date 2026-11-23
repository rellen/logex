# Configuration file: messages

This page is for a reader who has a message of a configuration and looks for its cause.
It gives each [diagnostic](glossary.md#diagnostic) and each
[warning](glossary.md#warning) of a [configuration file](glossary.md#configuration-file)
and of a [configuration](glossary.md#configuration) from Elixir data. A script makes
each message from a text, and the suite runs each script.
[Configuration file](configuration-file.md) gives the rules that the messages name.

Each case has a number. For each case, a script prints the number and the text of the
case. Then it prints each diagnostic, each warning, or the message of an
`ArgumentError`. `line 1` is the first line of the text, on the line of the number. If
the text is correct, the script prints that it compiles.
[Words in the messages](configuration-file.md#words-in-the-messages) gives the meaning of
the words of a message.

| Group | Cases | Rules |
|---|---|---|
| [The text of a file](#the-text-of-a-file-cases-1-to-10) | 1 to 10 | [The text of a file](configuration-file.md#the-text-of-a-file) |
| [Task lines](#task-lines-cases-11-to-34) | 11 to 34 | [Task lines](configuration-file.md#task-lines) |
| [`var_global` lines](#var_global-lines-cases-35-to-52) | 35 to 52 | [`var_global` lines](configuration-file.md#var_global-lines) |
| [Locations](#locations-cases-53-to-66) | 53 to 66 | [Locations and points](configuration-file.md#locations-and-points) |
| [`program` lines](#program-lines-cases-67-to-79) | 67 to 79 | [`program` lines](configuration-file.md#program-lines) |
| [Connection lines](#connection-lines-cases-80-to-111) | 80 to 111 | [Connection lines](configuration-file.md#connection-lines) |
| [`var_external` tags](#var_external-tags-cases-112-to-116) | 112 to 116 | [Globals that a program declares `var_external`](configuration-file.md#globals-that-a-program-declares-var_external) |
| [Names](#names-cases-117-to-125) | 117 to 125 | [Names and reserved words](configuration-file.md#names-and-reserved-words) |
| [Files](#files-cases-126-to-134) | 126 to 134 | [The functions that compile a configuration](configuration-file.md#the-functions-that-compile-a-configuration) |
| [Elixir data](#elixir-data-cases-135-to-153) | 135 to 153 | [A configuration from Elixir data](configuration-file.md#a-configuration-from-elixir-data) |
| [Warnings](#warnings-cases-154-to-176) | 154 to 176 | Each rules section that the table of the warnings names |

## The program types of the cases

Each script reads the file
[`instructions-contacts-and-coils/report.exs`](instructions-contacts-and-coils.md#the-tags-of-the-wrong-rungs),
which prints each case and each message in lines of 80 characters or fewer. It is not
necessary to read the scripts to use the messages.

Most scripts also read `configuration-file/types.exs`. It compiles 5 program types: the
4 of the example `line_1.logex` and `lamp.ld`. Get
[`configuration-file/belt.ld`](configuration-file.md#the-example-line_1logex),
[`configuration-file/box_count.ld`](configuration-file.md#the-example-line_1logex),
[`configuration-file/fan_control.ld`](configuration-file.md#the-example-line_1logex) and
[`configuration-file/stop_record.ld`](configuration-file.md#the-example-line_1logex).

<!-- file: configuration-file/types.exs -->
```elixir
# The program types of the directory configuration-file, by name, for
# Logex.Configuration.compile/3.
for name <- ~w(lamp belt box_count fan_control stop_record), into: %{} do
  {:ok, program} = Logex.compile_file("configuration-file/#{name}.ld")
  {name, program}
end
```

<!-- file: configuration-file/lamp.ld -->
```text
var_input  on   bool
var_output lamp bool

xic on ote lamp
```

The script of the Elixir data reads `configuration-file/calls.exs`. It runs each case
and prints the message of the `ArgumentError`.

<!-- file: configuration-file/calls.exs -->
```elixir
# calls.(first, cases) runs each case of the list cases, a {call, function} pair, the first
# of them as the case `first`. It prints the number of the case and the call. Then it
# prints the message of the ArgumentError that the function raises, in lines of 80
# characters or fewer.
wrap = fn message ->
  message
  |> String.split(" ")
  |> Enum.chunk_while(
    "     ",
    fn
      word, line when byte_size(line) + byte_size(word) < 80 -> {:cont, line <> " " <> word}
      word, line -> {:cont, line, "      " <> word}
    end,
    fn line -> {:cont, line, ""} end
  )
end

fn first, cases ->
  for {{call, fun}, number} <- Enum.with_index(cases, first) do
    message =
      try do
        fun.()
        "no error"
      rescue
        error in ArgumentError -> error.message
      end

    lines = Enum.flat_map(String.split(message, "\n"), wrap)
    IO.puts(Enum.join([String.pad_leading("#{number}", 2) <> "  " <> call | lines], "\n"))
  end
end
```

## The text of a file: cases 1 to 10

Case 2 shows that a file has no `resource` line. Case 9 has 2 errors, and logex gives
only the lex error.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "taks fast interval 10 priority 1" <> lamp,
  "resource line_1" <> lamp,
  "at fast" <> lamp,
  "interval 10" <> lamp,
  "retain total dint" <> lamp,
  "task fast interval 10 priority 1 |" <> lamp,
  "program l1 lamp\n  l1.on 0\n( l1.lamp )",
  "task fast interval 10ms priority 1" <> lamp,
  "taks fast interval 10 priority 1\nvar_global x bool @ panel.i.0" <> lamp,
  "program l1 lamp\n  l1.on -> 0"
]

report.(1, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-text.exs
 1  taks fast interval 10 priority 1
    program l1 lamp
      l1.on 0
      line 1, column 1: unknown configuration line `taks` — did you mean
      `task`?
 2  resource line_1
    program l1 lamp
      l1.on 0
      line 1, column 1: unknown configuration line `resource`: a line starts
      with `task`, `var_global` or `program`, or is a connection, as in
      `m1.start pb_start_1`
 3  at fast
    program l1 lamp
      l1.on 0
      line 1, column 1: a line cannot start with `at`: it goes on a `var_global`
      line, as in `var_global k1 bool at panel.q.0`
 4  interval 10
    program l1 lamp
      l1.on 0
      line 1, column 1: a line cannot start with `interval`: it goes on a `task`
      line, as in `task fast interval 10 priority 1`
 5  retain total dint
    program l1 lamp
      l1.on 0
      line 1, column 1: a line cannot start with `retain`: it goes on a
      `var_global` line, straight after `var_global`, as in `var_global retain
      total_boxes dint 0`
 6  task fast interval 10 priority 1 |
    program l1 lamp
      l1.on 0
      line 1, column 34: a configuration line cannot hold `|`
 7  program l1 lamp
      l1.on 0
    ( l1.lamp )
      line 3, column 1: a configuration line cannot hold `(`
 8  task fast interval 10ms priority 1
    program l1 lamp
      l1.on 0
      line 1, column 20: missing separator after integer: "10ms" is neither a
      number nor a tag
 9  taks fast interval 10 priority 1
    var_global x bool @ panel.i.0
    program l1 lamp
      l1.on 0
      line 2, column 19: illegal character "@"
10  program l1 lamp
      l1.on -> 0
      line 2, column 9: illegal character "-"
```

## Task lines: cases 11 to 34

Cases 11 to 15 and 30 break the sequence of the words of a [task](glossary.md#task)
line. Cases 25 to 29 give a wrong [trigger](glossary.md#trigger). Cases 31 to 33 break
the rules of the [continuous task](glossary.md#continuous-task).

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp with fast\n  l1.on 0"

texts = [
  "task fast priority 1 interval 10" <> lamp,
  "task fast interval 10 interval 20 priority 1" <> lamp,
  "task fast interval 10 watchdog 50 priority 1" <> lamp,
  "task fast interval 10 priority 1 continuous" <> lamp,
  "task fast interval 10 priority 1 phase 5" <> lamp,
  "task fast interval 10" <> lamp,
  "task fast priority 1" <> lamp,
  "task fast" <> lamp,
  "task fast interval 0 priority 1" <> lamp,
  "task fast interval 2147483648 priority 1" <> lamp,
  "task fast interval 10 priority 65536" <> lamp,
  "task fast interval 10 priority -1" <> lamp,
  "task fast interval 1.5 priority 1" <> lamp,
  "task fast interval 10 priority 1 watchdog 0" <> lamp,
  "task fast single estop priority 0" <> lamp,
  "task fast single 5 priority 0" <> lamp,
  "var_global estop dint\ntask fast single estop priority 0" <> lamp,
  "var_global estop bool[2]\ntask fast single estop[1] priority 0" <> lamp,
  "task fast single l1.lamp priority 0" <> lamp,
  "var_global estop bool\ntask fast interval 10 single estop priority 0" <> lamp,
  "task fast continuous priority 1" <> lamp,
  "var_global estop bool\ntask fast continuous single estop interval 10" <> lamp,
  "task fast continuous\ntask main continuous" <> lamp,
  "task" <> lamp
]

report.(11, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-tasks.exs
11  task fast priority 1 interval 10
    program l1 lamp with fast
      l1.on 0
      line 1, column 22: `interval` goes before `priority`, as in `task fast
      interval 10 priority 1`
12  task fast interval 10 interval 20 priority 1
    program l1 lamp with fast
      l1.on 0
      line 1, column 23: `interval` is given twice on the line of task `fast`
13  task fast interval 10 watchdog 50 priority 1
    program l1 lamp with fast
      l1.on 0
      line 1, column 35: `priority` goes before `watchdog`, as in `task fast
      interval 10 priority 1 watchdog 50`
14  task fast interval 10 priority 1 continuous
    program l1 lamp with fast
      l1.on 0
      line 1, column 34: `continuous` goes before `interval`, as in `task main
      continuous watchdog 200`
15  task fast interval 10 priority 1 phase 5
    program l1 lamp with fast
      l1.on 0
      line 1, column 34: unexpected `phase` on the line of task `fast`: a task
      takes `continuous`, `single`, `interval`, `priority` and `watchdog`
16  task fast interval 10
    program l1 lamp with fast
      l1.on 0
      line 1: task `fast` needs a priority, as in `task fast interval 10
      priority 1`: 0 is the highest
17  task fast priority 1
    program l1 lamp with fast
      l1.on 0
      line 1: task `fast` needs an interval or a single, as in `task fast
      interval 10 priority 1` or `task fast single estop priority 0`
18  task fast
    program l1 lamp with fast
      l1.on 0
      line 1: task `fast` needs an interval or a single, as in `task fast
      interval 10 priority 1` or `task fast single estop priority 0`, or is the
      continuous task, as in `task fast continuous`
      line 1: task `fast` needs a priority, as in `task fast interval 10
      priority 1`: 0 is the highest
19  task fast interval 0 priority 1
    program l1 lamp with fast
      l1.on 0
      line 1: the interval of `fast` is 0: an interval is at least 1 ms, and an
      instance that runs every cycle is declared without `with`
20  task fast interval 2147483648 priority 1
    program l1 lamp with fast
      l1.on 0
      line 1: the interval of `fast` is `2147483648` ms: an interval is 1 to
      2147483647 ms
21  task fast interval 10 priority 65536
    program l1 lamp with fast
      l1.on 0
      line 1: the priority of `fast` is `65536`: a priority is 0 to 65535, and 0
      is the highest
22  task fast interval 10 priority -1
    program l1 lamp with fast
      l1.on 0
      line 1: the priority of `fast` is `-1`: a priority is 0 to 65535, and 0 is
      the highest
23  task fast interval 1.5 priority 1
    program l1 lamp with fast
      l1.on 0
      line 1, column 20: `interval` takes a number of milliseconds, as in
      `interval 10`, found `1.5`
24  task fast interval 10 priority 1 watchdog 0
    program l1 lamp with fast
      l1.on 0
      line 1: the watchdog of `fast` is 0: a watchdog is at least 1 ms, and a
      task that sets none has 500
25  task fast single estop priority 0
    program l1 lamp with fast
      l1.on 0
      line 1: the single of `fast`: no global `estop`: declare it, as in
      `var_global estop bool`
26  task fast single 5 priority 0
    program l1 lamp with fast
      l1.on 0
      line 1, column 18: `single` takes a bool global's name, as in `single
      estop`, found `5`
27  var_global estop dint
    task fast single estop priority 0
    program l1 lamp with fast
      l1.on 0
      line 2: the single of `fast`, `estop`, is a dint (line 1): a single is a
      bool global
28  var_global estop bool[2]
    task fast single estop[1] priority 0
    program l1 lamp with fast
      l1.on 0
      line 2: the single of `fast`: `estop[1]` names an element of `estop`, a
      global array of 2 bools (line 1): a global is named here whole, never by
      one of its elements
29  task fast single l1.lamp priority 0
    program l1 lamp with fast
      l1.on 0
      line 1: the single of `fast`: `l1.lamp` is an instance's member: instances
      share a value only through a global, which one drives and the other reads
30  var_global estop bool
    task fast interval 10 single estop priority 0
    program l1 lamp with fast
      l1.on 0
      line 2, column 23: `single` goes before `interval`, as in `task parts
      single part_in interval 1000 priority 2`
31  task fast continuous priority 1
    program l1 lamp with fast
      l1.on 0
      line 1: `fast` is the continuous task, which takes no `priority`: it runs
      every program instance with no timed task, after the due tasks, as in
      `task fast continuous watchdog 200`
32  var_global estop bool
    task fast continuous single estop interval 10
    program l1 lamp with fast
      l1.on 0
      line 2: `fast` is the continuous task, which takes no `single` or
      `interval`: it runs every program instance with no timed task, after the
      due tasks, as in `task fast continuous watchdog 200`
33  task fast continuous
    task main continuous
    program l1 lamp with fast
      l1.on 0
      line 2: `main` is a second continuous task: a configuration has one at
      most, and `fast` (line 1) is its continuous task
34  task
    program l1 lamp with fast
      l1.on 0
      line 1, column 1: `task` needs a name, as in `task fast interval 10
      priority 1`
      line 2: no task `fast`: declare it with a `task` line, as in `task fast
      interval 10 priority 1`
```

## `var_global` lines: cases 35 to 52

Cases 39 to 47 give a wrong [initial value](glossary.md#initial-value) or a wrong size
of an [array](glossary.md#array). Cases 49 to 52 put [`retain`](glossary.md#retain) in
a wrong place, or on a [located global](glossary.md#located-global). In these 4 cases,
the [instance](glossary.md#instance) `l1` reads the [global](glossary.md#global), and no
diagnostic says that the global is not there.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"
# In cases 49 to 52, the instance l1 reads the global: no diagnostic says that the global
# is not there.
reads = fn global -> "\nprogram l1 lamp\n  l1.on #{global}" end

texts = [
  "var_global total" <> lamp,
  "var_global total dint 1 2" <> lamp,
  "var_global total ton" <> lamp,
  "var_global total time" <> lamp,
  "var_global total dint 2147483648" <> lamp,
  "var_global total word -1" <> lamp,
  "var_global total dint 1.5" <> lamp,
  "var_global estop bool 2" <> lamp,
  "var_global temp real 1.0e40" <> lamp,
  "var_global temp real 1.0e-40" <> lamp,
  "var_global limits real[2] 40.0" <> lamp,
  "var_global limits real[0]" <> lamp,
  "var_global limits real[100000]" <> lamp,
  "var_global limits real [2]" <> lamp,
  "var_global retain retain done bool" <> reads.("done"),
  "var_global retain non_retain done bool" <> reads.("done"),
  "var_global done bool 0 retain" <> reads.("done"),
  "var_global retain estop bool at panel.i.7" <> reads.("estop")
]

report.(35, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-globals.exs
35  var_global total
    program l1 lamp
      l1.on 0
      line 1, column 1: `total` needs a type, as in `var_global total bool` or
      `var_global total dint`
36  var_global total dint 1 2
    program l1 lamp
      l1.on 0
      line 1, column 25: unexpected `2` after the declaration of `total`
37  var_global total ton
    program l1 lamp
      l1.on 0
      line 1, column 18: `total` cannot be a `ton`: a global's type is `bool`,
      `sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`,
      `lreal`, `byte`, `word`, `dword` or `lword`, and a ton is declared inside
      a program, as in `var total ton`
38  var_global total time
    program l1 lamp
      l1.on 0
      line 1, column 18: unknown type `time`: a global's type is `bool`, `sint`,
      `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, `lreal`,
      `byte`, `word`, `dword` or `lword`
39  var_global total dint 2147483648
    program l1 lamp
      l1.on 0
      line 1: `total` is a dint: `2147483648` is outside -2147483648 to
      2147483647
40  var_global total word -1
    program l1 lamp
      l1.on 0
      line 1: `total` is a word: `-1` is outside 0 to 65535
41  var_global total dint 1.5
    program l1 lamp
      l1.on 0
      line 1: `total` is a dint: `1.5` is a real, and a dint holds only integers
42  var_global estop bool 2
    program l1 lamp
      l1.on 0
      line 1: `estop` is a bool: its initial value must be 0 or 1, found `2`
43  var_global temp real 1.0e40
    program l1 lamp
      l1.on 0
      line 1: `temp` is a real: `1.0e40` is beyond a real's range,
      -3.4028234663852886e38 to 3.4028234663852886e38
44  var_global temp real 1.0e-40
    program l1 lamp
      l1.on 0
      line 1: `temp` is a real: `1.0e-40` is too near 0.0 for a real, whose
      smallest above 0.0 is 1.1754943508222875e-38: it would be written as 0.0
45  var_global limits real[2] 40.0
    program l1 lamp
      l1.on 0
      line 1: `limits` is an array of 2 reals: its initial list holds 1 value,
      and an array's holds one for every element, 2, in the elements' order
46  var_global limits real[0]
    program l1 lamp
      l1.on 0
      line 1: `limits` is declared with a dimension of 0, `[0]`: each dimension
      of an array holds 1 element or more
47  var_global limits real[100000]
    program l1 lamp
      l1.on 0
      line 1: `limits` would hold 100000 elements, `[100000]`: an array holds
      65536 at most
48  var_global limits real [2]
    program l1 lamp
      l1.on 0
      line 1, column 24: illegal character "["
49  var_global retain retain done bool
    program l1 lamp
      l1.on done
      line 1, column 19: `retain` is given twice: a global takes `retain` once,
      as in `var_global retain total_boxes dint 0`
50  var_global retain non_retain done bool
    program l1 lamp
      l1.on done
      line 1, column 19: a global takes `retain` or `non_retain`, not both:
      found `retain` and `non_retain`
51  var_global done bool 0 retain
    program l1 lamp
      l1.on done
      line 1, column 24: `retain` comes straight after `var_global`, as in
      `var_global retain done bool`
52  var_global retain estop bool at panel.i.7
    program l1 lamp
      l1.on estop
      line 1: `estop` is an input point, and a located global takes no `retain`:
      an input point is read again at every start, and an output point starts at
      0 until logic writes it
```

## Locations: cases 53 to 66

Cases 56 and 57 show the message that gives the correct form of a
[location](glossary.md#location). Cases 64 and 65 show a located array that overlaps a
different [point](glossary.md#point).

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "var_global estop bool at" <> lamp,
  "var_global estop bool at panel" <> lamp,
  "var_global estop bool at panel.x.7" <> lamp,
  "var_global estop bool at panel.I.7" <> lamp,
  "var_global estop bool at panel.i.07" <> lamp,
  "var_global estop bool at 5.i.7" <> lamp,
  "var_global estop bool at task.i.7" <> lamp,
  "var_global estop bool 0 at panel.i.7" <> lamp,
  "var_global motor_k bool 1 at panel.q.0" <> lamp,
  "var_global temps real[2] 20.0 20.0 at card.i.0" <> lamp,
  "var_global estop bool at panel.i.7\nvar_global eye bool at panel.i.7" <> lamp,
  "var_global temps real[2] at card.i.0\nvar_global door bool at card.i.1" <> lamp,
  "var_global temps real[2] at card.i.0\nvar_global spare real[3] at card.i.1" <> lamp,
  "var_global estop bool at panel.i.7\nvar_global eye bool at Panel.i.2" <> lamp
]

report.(53, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-locations.exs
53  var_global estop bool at
    program l1 lamp
      l1.on 0
      line 1, column 23: `at` needs a location, as in `at panel.i.0`
54  var_global estop bool at panel
    program l1 lamp
      l1.on 0
      line 1: `panel` is not a location: a location is a device, `i` or `q`, and
      an address, as in `panel.i.0`
55  var_global estop bool at panel.x.7
    program l1 lamp
      l1.on 0
      line 1: `panel.x.7` is not a location: a location is a device, `i` or `q`,
      and an address, as in `panel.i.0`
56  var_global estop bool at panel.I.7
    program l1 lamp
      l1.on 0
      line 1: `panel.I.7` is not a location as written: a location's `i` or `q`
      is lowercase and its address has no leading zero, so it is written
      `panel.i.7`
57  var_global estop bool at panel.i.07
    program l1 lamp
      l1.on 0
      line 1: `panel.i.07` is not a location as written: a location's `i` or `q`
      is lowercase and its address has no leading zero, so it is written
      `panel.i.7`
58  var_global estop bool at 5.i.7
    program l1 lamp
      l1.on 0
      line 1, column 26: "5.i.7" is no number: a real has digits on both sides
      of its `.`, `1.0` or `0.5`
59  var_global estop bool at task.i.7
    program l1 lamp
      l1.on 0
      line 1: `task` is a keyword and cannot name a device
60  var_global estop bool 0 at panel.i.7
    program l1 lamp
      l1.on 0
      line 1: `estop` is an input point: its value comes from the input image,
      so it takes no initial value
61  var_global motor_k bool 1 at panel.q.0
    program l1 lamp
      l1.on 0
      line 1: `motor_k` is an output point: it takes no initial value, and is 0
      until its driver writes it
62  var_global temps real[2] 20.0 20.0 at card.i.0
    program l1 lamp
      l1.on 0
      line 1: `temps` is an array of input points, `card.i.0` to `card.i.1`:
      their values come from the input image, so it takes no initial list
63  var_global estop bool at panel.i.7
    var_global eye bool at panel.i.7
    program l1 lamp
      l1.on 0
      line 2: `eye` is at `panel.i.7`, where `estop` already is (line 1): a
      location holds one global
64  var_global temps real[2] at card.i.0
    var_global door bool at card.i.1
    program l1 lamp
      l1.on 0
      line 2: `door` is at `card.i.1`, where `temps[1]` already is (line 1): a
      location holds one global
65  var_global temps real[2] at card.i.0
    var_global spare real[3] at card.i.1
    program l1 lamp
      l1.on 0
      line 2: `spare[0]` is at `card.i.1`, where `temps[1]` already is (line 1):
      a location holds one global, and `spare` is an array of input points,
      `card.i.1` to `card.i.3`
66  var_global estop bool at panel.i.7
    var_global eye bool at Panel.i.2
    program l1 lamp
      l1.on 0
      line 2: the device `Panel` and the device `panel` of `estop` (line 1)
      differ only in case: device names are case-sensitive, so these would be
      two devices
```

## `program` lines: cases 67 to 79

Case 77 is the form `PROGRAM RETAIN` of [IEC 61131-3](glossary.md#iec-61131-3), which
logex does not have. Case 78 has no `program` line, and its diagnostic has no line.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
fast = "task fast interval 10 priority 1\n"

texts = [
  "program l1\n  l1.on 0",
  "program l1 with fast\n  l1.on 0",
  "program l1 lamp fast\n  l1.on 0",
  "program l1 lamb\n  l1.on 0",
  "program l1 Lamp\n  l1.on 0",
  fast <> "program l1 lamp with slow\n  l1.on 0",
  fast <> "program l1 lamp with fast.x\n  l1.on 0",
  "program l1.x lamp\n  l1.on 0",
  "program task lamp\n  task.on 0",
  "program retain lamp\n  retain.on 0",
  "program retain l1 lamp\n  l1.on 0",
  "var_global total dint",
  fast <> "program l1 lamp with fast\n  l1.on 0\nprogram l1 lamp with fast\n  l1.on 0"
]

report.(67, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-programs.exs
67  program l1
      l1.on 0
      line 1, column 1: `program l1` needs a program type, as in `program l1
      motor`
68  program l1 with fast
      l1.on 0
      line 1, column 12: `program l1` needs a program type before `with`, as in
      `program l1 motor with fast`
69  program l1 lamp fast
      l1.on 0
      line 1, column 17: unexpected `fast` after `program l1 lamp`
70  program l1 lamb
      l1.on 0
      line 1: unknown program type `lamb` — did you mean `lamp`?
71  program l1 Lamp
      l1.on 0
      line 1: unknown program type `Lamp` — did you mean `lamp`? (program
      types are case-sensitive)
72  task fast interval 10 priority 1
    program l1 lamp with slow
      l1.on 0
      line 2: no task `slow`: declare it with a `task` line, as in `task slow
      interval 10 priority 1`
73  task fast interval 10 priority 1
    program l1 lamp with fast.x
      l1.on 0
      line 2: no task `fast.x`: a task's name has no `.`, which is kept for a
      path and a location — did you mean `fast`?
74  program l1.x lamp
      l1.on 0
      line 1: `l1.x` cannot name an instance: `.` is kept for a path, as in
      `m1.start`, and a location, as in `panel.i.0`
      line 2: no instance `l1`: declare it, as in `program l1 motor`
75  program task lamp
      task.on 0
      line 1: `task` is a keyword and cannot name an instance
76  program retain lamp
      retain.on 0
      line 1: `retain` is a keyword and cannot name an instance
77  program retain l1 lamp
      l1.on 0
      line 1, column 9: `retain` before an instance's name is IEC's `PROGRAM
      RETAIN`, which logex does not have: mark in its program what it keeps, as
      in `var retain count dint`
78  var_global total dint
      this configuration declares no `program`: it would run nothing
79  task fast interval 10 priority 1
    program l1 lamp with fast
      l1.on 0
    program l1 lamp with fast
      l1.on 0
      line 4: `l1` is declared twice: first on line 2, as an instance
      line 5: `l1.on` is already connected, to `0` (line 3): a var_input has one
      source
```

## Connection lines: cases 80 to 111

Cases 107 to 111 connect the arrays of the [program type](glossary.md#program-type)
`fans`, which the script [compiles](glossary.md#compile) from text. Case 111 compiles:
each `int` of the global [widens](glossary.md#widen) into a `real` of the input.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

# fans: a program type with 2 arrays, for texts 105 to 109.
fans_text = """
var_input  temps real[2]
var_output fans  bool[2]

gt temps[0] 40.0 ote fans[0]
gt temps[1] 40.0 ote fans[1]
"""

{:ok, fans} = Logex.compile(fans_text, name: "fans")
fan = "program f1 fan_control\n  f1.temp 20.0\n"

texts = [
  "program l1 lamp",
  "program c1 belt\n  c1.start 0\nvar_global estop bool",
  "program l1 lamp\n  l1.of 0",
  "program l1 lamp\n  l1.on 0\n  l2.on 0",
  "program l1 lamp\n  l1.on",
  "program l1 lamp\n  l1 0",
  "program l1 lamp\n  l1.on 0 1",
  "program l1 lamp\n  l1.on 0\n  l1.on 1",
  "program l1 lamp\n  l1.on 2",
  "program l1 lamp\n  l1.on 1.0",
  "program l1 lamp\n  l1.on pb_start",
  "var_global total dint\nprogram l1 lamp\n  l1.on total",
  "var_global level int\nprogram b1 box_count\n  b1.eye 0\nprogram r1 stop_record\n  r1.count 0\n  r1.count_at_stop level\nvar_global total dint",
  "var_global level real\nprogram r1 stop_record\n  r1.count level\nvar_global total dint",
  fan <> "  f1.limit 1.0e40",
  "program l1 lamp\n  l1.on 0\n  l1.lamp 1",
  "var_global pb_start bool at panel.i.0\nprogram l1 lamp\n  l1.on 0\n  l1.lamp pb_start",
  "var_global lamp_k bool at panel.q.3\nprogram l1 lamp\nprogram l2 lamp\n  l1.on 0\n  l2.on 0\n  l1.lamp lamp_k\n  l2.lamp lamp_k",
  "var_global estop bool\nprogram c1 belt\n  c1.start 0\n  c1.stop 0\n  c1.estop estop",
  "program b1 box_count\n  b1.eye 0\n  b1.seen 0\nvar_global total dint",
  "program l1 lamp\n  l1.on l2.lamp",
  "program l1 lamp\n  l1.on panel.i.0",
  "program l1 lamp\n  l1[1].on 0",
  "program r1 stop_record\n  r1.count 0\n  r1.x.y 0",
  "var_global temps real[2]\n" <> fan <> "  f1.limit temps",
  "var_global temps real[2]\n" <> fan <> "  f1.limit temps[2]",
  "var_global temps real[2]\nvar_global i dint\n" <> fan <> "  f1.limit temps[i]",
  "program f1 fans\n  f1.temps 20.0",
  "program f1 fans\n  f1.temps[0] 20.0",
  "program f1 fans\n  f1.temps[0] 20.0\n  f1.temps[1] 20.0\n  f1.temps[2] 20.0",
  "var_global temps real[3]\nprogram f1 fans\n  f1.temps temps",
  "var_global temps int[2]\nvar_global fan_k bool[2]\nprogram f1 fans\n  f1.temps temps\n  f1.fans fan_k"
]

report.(80, texts, &Logex.Configuration.compile("line_1", &1, Map.put(types, "fans", fans)))
```

```console
$ mix run configuration-file-wrong-connections.exs
80  program l1 lamp
      line 1: `l1` leaves its var_input `on` unconnected: connect it to a
      global, a point or a constant, as in `l1.on 0`
81  program c1 belt
      c1.start 0
    var_global estop bool
      line 1: `c1` leaves its var_input `stop` unconnected: connect it to a
      global, a point or a constant, as in `c1.stop 0`
82  program l1 lamp
      l1.of 0
      line 1: `l1` leaves its var_input `on` unconnected: connect it to a
      global, a point or a constant, as in `l1.on 0`
      line 2: `l1` runs `lamp`, which declares no `of`: its var_inputs and
      var_outputs are `lamp` and `on`
83  program l1 lamp
      l1.on 0
      l2.on 0
      line 3: no instance `l2`: declare it, as in `program l2 motor`
84  program l1 lamp
      l1.on
      line 2, column 3: `l1.on` needs a global or a constant to connect, as in
      `l1.on pb_start_1`
85  program l1 lamp
      l1 0
      line 1: `l1` leaves its var_input `on` unconnected: connect it to a
      global, a point or a constant, as in `l1.on 0`
      line 2, column 3: unknown configuration line `l1`: a line starts with
      `task`, `var_global` or `program`, or is a connection, as in `m1.start
      pb_start_1`
86  program l1 lamp
      l1.on 0 1
      line 2, column 11: unexpected `1` after `l1.on 0`
87  program l1 lamp
      l1.on 0
      l1.on 1
      line 3: `l1.on` is already connected, to `0` (line 2): a var_input has one
      source
88  program l1 lamp
      l1.on 2
      line 2: `l1.on` is a bool: only 0 or 1 fit, found `2`
89  program l1 lamp
      l1.on 1.0
      line 2: `l1.on` is a bool: `1.0` is a real, and a bool holds only 0 or 1
90  program l1 lamp
      l1.on pb_start
      line 2: no global `pb_start`: declare it, as in `var_global pb_start bool`
91  var_global total dint
    program l1 lamp
      l1.on total
      line 3: `l1.on` is a bool, but `total` is a dint (line 1)
92  var_global level int
    program b1 box_count
      b1.eye 0
    program r1 stop_record
      r1.count 0
      r1.count_at_stop level
    var_global total dint
      line 6: `r1.count_at_stop` is a dint, but `level` is an int (line 1): a
      dint does not widen into an int, and a connection converts nothing:
      convert it inside the program, with `dint_to_int`
93  var_global level real
    program r1 stop_record
      r1.count level
    var_global total dint
      line 3: `r1.count` is a dint, but `level` is a real (line 1): a real does
      not widen into a dint, and a connection converts nothing: convert it
      inside the program, with `real_to_dint`
94  program f1 fan_control
      f1.temp 20.0
      f1.limit 1.0e40
      line 3: `f1.limit` is a real: `1.0e40` is beyond a real's range,
      -3.4028234663852886e38 to 3.4028234663852886e38
95  program l1 lamp
      l1.on 0
      l1.lamp 1
      line 3: `l1.lamp` is a var_output, which drives a global: it cannot drive
      the constant `1`
96  var_global pb_start bool at panel.i.0
    program l1 lamp
      l1.on 0
      l1.lamp pb_start
      line 4: `pb_start` is an input point (line 1): `l1.lamp`, a var_output,
      cannot drive it
97  var_global lamp_k bool at panel.q.3
    program l1 lamp
    program l2 lamp
      l1.on 0
      l2.on 0
      l1.lamp lamp_k
      l2.lamp lamp_k
      line 7: `lamp_k` is already driven by `l1.lamp` (line 6)
98  var_global estop bool
    program c1 belt
      c1.start 0
      c1.stop 0
      c1.estop estop
      line 5: `c1.estop` is a var_external of `belt`, which reaches the global
      `estop` itself: only a var_input or var_output connects
99  program b1 box_count
      b1.eye 0
      b1.seen 0
    var_global total dint
      line 3: `b1.seen` is internal to `box_count` (declared `var`): only a
      var_input or var_output connects
100  program l1 lamp
      l1.on l2.lamp
      line 2: `l2.lamp` names a member of an instance, and there is no instance
      `l2`
101  program l1 lamp
      l1.on panel.i.0
      line 2: `panel.i.0` is a location, written only after `at` on a
      `var_global` line: declare a global at it, as in `var_global point bool at
      panel.i.0`, and name that
102  program l1 lamp
      l1[1].on 0
      line 2, column 3: `l1[1].on` names an element of `l1`: a connection's
      instance is named whole, never by one of its elements, as in `l1.on`
103  program r1 stop_record
      r1.count 0
      r1.x.y 0
      line 3: `r1.x.y` goes too deep: a connection names an instance's var_input
      or var_output, as in `r1.start`
104  var_global temps real[2]
    program f1 fan_control
      f1.temp 20.0
      f1.limit temps
      line 4: `f1.limit` is a real, but `temps` is an array of 2 reals (line 1)
105  var_global temps real[2]
    program f1 fan_control
      f1.temp 20.0
      f1.limit temps[2]
      line 4: `temps[2]`'s subscript `2` is outside 0 to 1: `temps` is a global
      array of 2 reals (line 1)
106  var_global temps real[2]
    var_global i dint
    program f1 fan_control
      f1.temp 20.0
      f1.limit temps[i]
      line 5: `temps[i]`'s subscript `i` is a tag's name: a connection names an
      element of a global by literal subscripts, as in `temps[0]`
107  program f1 fans
      f1.temps 20.0
      line 2: `f1.temps` is an array of 2 reals, and the constant `20.0` is one
      value: connect it to a global array of its sizes, or each element to a
      constant, as in `f1.temps[0] 20.0`
108  program f1 fans
      f1.temps[0] 20.0
      line 1: `f1` leaves its var_input `temps[1]` unconnected: connect it to a
      global, a point or a constant, as in `f1.temps[1] 0`
109  program f1 fans
      f1.temps[0] 20.0
      f1.temps[1] 20.0
      f1.temps[2] 20.0
      line 4: `f1.temps[2]`'s subscript `2` is outside 0 to 1: `temps` is an
      array of 2 reals
110  var_global temps real[3]
    program f1 fans
      f1.temps temps
      line 3: `f1.temps` is an array of 2 reals, but `temps` is an array of 3
      reals (line 1)
111  var_global temps int[2]
    var_global fan_k bool[2]
    program f1 fans
      f1.temps temps
      f1.fans fan_k
      the text compiles, and logex gives no warning
```

## `var_external` tags: cases 112 to 116

Each case runs `belt.ld` or `box_count.ld`. The message gives a line of the `.ld` file.
For a write to an [input](glossary.md#input) point, it is the line of the first write
(case 115). For each other case, it is the line of the
[declaration](glossary.md#declaration).

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
belt = "\nprogram c1 belt\n  c1.start 0\n  c1.stop 0"
boxes = "\nprogram b1 box_count\n  b1.eye 0"

texts = [
  "var_global estap bool" <> belt,
  "var_global estop int" <> belt,
  "var_global estop bool[2]" <> belt,
  "var_global total dint at panel.i.3" <> boxes,
  "var_global total lint" <> boxes
]

report.(112, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-externals.exs
112  var_global estap bool
    program c1 belt
      c1.start 0
      c1.stop 0
      line 2: `belt` declares `var_external estop bool` on line 4 of `belt.ld`,
      but there is no global `estop` — did you mean `estap`?
113  var_global estop int
    program c1 belt
      c1.start 0
      c1.stop 0
      line 2: `belt` declares `var_external estop bool` on line 4 of `belt.ld`,
      but `estop` is an int (line 1)
114  var_global estop bool[2]
    program c1 belt
      c1.start 0
      c1.stop 0
      line 2: `belt` declares `var_external estop bool` on line 4 of `belt.ld`,
      but `estop` is an array of 2 bools (line 1): a var_external is its global,
      so it is an array of exactly the global's type and sizes, every dimension
      included
115  var_global total dint at panel.i.3
    program b1 box_count
      b1.eye 0
      line 2: `box_count` writes its var_external `total` on line 5 of
      `box_count.ld`, but `total` is an input point (line 1): nothing writes an
      input point
116  var_global total lint
    program b1 box_count
      b1.eye 0
      line 2: `box_count` declares `var_external total dint` on line 2 of
      `box_count.ld`, but `total` is an lint (line 1): a var_external is its
      global, so its type is exactly the global's, never widened
```

## Names: cases 117 to 125

Case 125 compiles: an instance can have the name of its program type.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")
lamp = "\nprogram l1 lamp\n  l1.on 0"

texts = [
  "var_global eye bool\nvar_global eye bool" <> lamp,
  "var_global eye bool\nvar_global Eye bool" <> lamp,
  "task l1 interval 10 priority 1" <> lamp,
  "var_global Task bool" <> lamp,
  "var_global PROGRAM bool" <> lamp,
  "var_global non_retain bool" <> lamp,
  "var_global pb.start bool" <> lamp,
  "task fast.1 interval 10 priority 1" <> lamp,
  "program lamp lamp\n  lamp.on 0"
]

report.(117, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-wrong-names.exs
117  var_global eye bool
    var_global eye bool
    program l1 lamp
      l1.on 0
      line 2: `eye` is declared twice: first on line 1, as a global
118  var_global eye bool
    var_global Eye bool
    program l1 lamp
      l1.on 0
      line 2: `Eye` and `eye` (line 1) differ only in case: names are
      case-sensitive, so these would be two (`eye` is a global)
119  task l1 interval 10 priority 1
    program l1 lamp
      l1.on 0
      line 2: `l1` is declared twice: first on line 1, as a task
      line 3: `l1` is a task (line 1), not an instance
120  var_global Task bool
    program l1 lamp
      l1.on 0
      line 1: `Task` is a keyword and cannot name a global
121  var_global PROGRAM bool
    program l1 lamp
      l1.on 0
      line 1: `PROGRAM` is a keyword and cannot name a global
122  var_global non_retain bool
    program l1 lamp
      l1.on 0
      line 1, column 23: `var_global` needs a name before `bool`, as in
      `var_global estop bool`
123  var_global pb.start bool
    program l1 lamp
      l1.on 0
      line 1: `pb.start` cannot name a global: `.` is kept for a path, as in
      `m1.start`, and a location, as in `panel.i.0`
124  task fast.1 interval 10 priority 1
    program l1 lamp
      l1.on 0
      line 1: `fast.1` cannot name a task: `.` is kept for a path, as in
      `m1.start`, and a location, as in `panel.i.0`
125  program lamp lamp
      lamp.on 0
      the text compiles, and logex gives no warning
```

## Files: cases 126 to 134

The script writes the files into a new directory and loads each file from there. Case
131 shows that logex compiles a file with a wrong name, and gives its diagnostics too.
Case 134 compiles: the name of a configuration can be a keyword.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")

# The script writes these files into a new directory, with a copy of lamp.ld. They are
# not in examples/, because most of them do not compile.
lamp = "\nprogram l1 lamp\n  l1.on 0\n"

files = %{
  "lamp_relay.ld" =>
    "function_block lamp_relay\nvar_input on bool\nvar_output lamp bool\nxic on ote lamp\n",
  "blink.ld" => "var_input on bool\nvar_output lamp bool\nxic on ote lammp\n",
  "missing.logex" => "program l1 lamq\n  l1.on 0\n",
  "relay.logex" => "program r1 lamp_relay\n  r1.on 0\n",
  "blinks.logex" => "program b1 blink\n  b1.on 0\nprogram b2 blink\n  b2.on 0\n",
  "line_2.txt" => lamp,
  ".logex" => lamp,
  "line-2.logex" => "program l1 lamb\n  l1.on 0\n",
  "task.logex" => lamp
}

dir = Path.join(System.tmp_dir!(), "configuration-file-#{System.pid()}")
File.rm_rf!(dir)
File.mkdir_p!(dir)
for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
File.cp!("configuration-file/lamp.ld", Path.join(dir, "lamp.ld"))
File.mkdir_p!(Path.join(dir, "folder.logex"))

File.cd!(dir, fn ->
  names =
    ~w(missing.logex relay.logex blinks.logex line_2.txt .logex line-2.logex none.logex folder.logex task.logex)

  report.(126, names, &Logex.Configuration.compile_file/1)
end)

File.rm_rf!(dir)
```

```console
$ mix run configuration-file-wrong-files.exs
126  missing.logex
      missing.logex: line 1: unknown program type `lamq`: there is no `lamq.ld`
      beside `missing.logex` — did you mean `lamp`?
127  relay.logex
      relay.logex: line 1: `lamp_relay` is a function block type, which runs
      inside a program through `cal`: an instance is of a %Logex.Program{}
128  blinks.logex
      blinks.logex: line 1: program type `blink` does not compile: its mistakes
      follow, cited in `blink.ld`
      ./blink.ld: line 3: `lammp` is not declared — did you mean `lamp`?
129  line_2.txt
      line_2.txt: `line_2.txt` is not a configuration file:
      Logex.Configuration.compile_file/1 loads a configuration from its `.logex`
      file
130  .logex
      .logex: `.logex` names no configuration: a configuration file is named
      after its configuration, as `plant.logex` is `plant`
131  line-2.logex
      line-2.logex: "line-2" cannot name a configuration: a name is a letter or
      `_`, then letters, digits or `_` (rename the file)
      line-2.logex: line 1: unknown program type `lamb`: there is no `lamb.ld`
      beside `line-2.logex` — did you mean `lamp`?
132  none.logex
      none.logex: cannot be read: no such file or directory
133  folder.logex
      folder.logex: cannot be read: illegal operation on a directory
134  task.logex
      the text compiles, and logex gives no warning
```

## Elixir data: cases 135 to 153

The script prints the call of each case and the message of the `ArgumentError`. Case
142 shows that `Global.new!/3` takes a global of a type that no global has, and that
`new!/1` refuses it. In case 144, `Global.new!/3` itself refuses the initial value, in
the words of `new!/1`.

```elixir
# Each case calls a function with wrong data. calls.exs prints the number of the case,
# the call and the message of the ArgumentError.
alias Logex.Configuration
alias Logex.Configuration.{Connection, Global, Instance, Task}
{calls, _} = Code.eval_file("configuration-file/calls.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

lamp = [
  name: "line_1",
  programs: [types["lamp"]],
  instances: [%Instance{name: "l1", type: "lamp"}],
  connections: [%Connection{instance: "l1", member: "on", to: 0}]
]

cases = [
  {"Configuration.new!(%{name: \"line_1\"})", fn -> Configuration.new!(%{name: "line_1"}) end},
  {"no name:", fn -> Configuration.new!(Keyword.delete(lamp, :name)) end},
  {"name: \"line-1\"", fn -> Configuration.new!(Keyword.put(lamp, :name, "line-1")) end},
  {"devices: []", fn -> Configuration.new!(lamp ++ [devices: []]) end},
  {"programs: [:lamp]", fn -> Configuration.new!(Keyword.put(lamp, :programs, [:lamp])) end},
  {"a task with priority: 1.5 and a task that is not there",
   fn ->
     Configuration.new!(
       Keyword.merge(lamp,
         tasks: [%Task{name: "fast", interval: 10, priority: 1.5}],
         instances: [%Instance{name: "l1", type: "lamp", task: "fsat"}]
       )
     )
   end},
  {"an instance with line: 3",
   fn ->
     Configuration.new!(
       Keyword.put(lamp, :instances, [%Instance{name: "l1", type: "lamp", line: 3}])
     )
   end},
  {"a global from Global.new!(\"t\", :time)",
   fn -> Configuration.new!(Keyword.put(lamp, :globals, [Global.new!("t", :time)])) end},
  {"a global named \"at\"",
   fn -> Configuration.new!(Keyword.put(lamp, :globals, [%Global{name: "at", type: :bool}])) end},
  {"a global from Global.new!(\"total\", :dint, initial: 1.5)",
   fn ->
     Configuration.new!(Keyword.put(lamp, :globals, [Global.new!("total", :dint, initial: 1.5)]))
   end},
  {"Global.new!(\"total\", :dint, retain: true, non_retain: true)",
   fn -> Global.new!("total", :dint, retain: true, non_retain: true) end},
  {"Global.new!(\"total\", :dint, retained: true)",
   fn -> Global.new!("total", :dint, retained: true) end},
  {"Global.new!(\"total\", :dint, retain: :yes)",
   fn -> Global.new!("total", :dint, retain: :yes) end},
  {"Global.new!(\"total\", :dint, at: \"panel.i.0\", at: \"panel.i.1\")",
   fn -> Global.new!("total", :dint, at: "panel.i.0", at: "panel.i.1") end},
  {"Global.new!(\"total\", :dint, %{retain: true})",
   fn -> Global.new!("total", :dint, %{retain: true}) end},
  {"Configuration.compile(\"line_1\", :text, %{})",
   fn -> Configuration.compile("line_1", :text, %{}) end},
  {"Configuration.compile(\"line_1\", \"\", %{\"lamb\" => lamp})",
   fn -> Configuration.compile("line_1", "", %{"lamb" => types["lamp"]}) end},
  {"Configuration.compile_file(:line_1)", fn -> Configuration.compile_file(:line_1) end},
  {"Configuration.watchdog(%Task{name: \"fast\", watchdog: 0})",
   fn -> Configuration.watchdog(%Task{name: "fast", watchdog: 0}) end}
]

calls.(135, cases)
```

```console
$ mix run configuration-file-wrong-data.exs
135  Configuration.new!(%{name: "line_1"})
      Logex.Configuration.new!/1 takes a keyword list of name:, programs:,
      tasks:, globals:, instances: and connections:, got: %{name: "line_1"}
136  no name:
      a configuration needs a name, as in name: "plant"
137  name: "line-1"
      "line-1" cannot name a configuration: a name is a letter or `_`, then
      letters, digits or `_`
138  devices: []
      :devices is not a field of a configuration: its fields are name:,
      programs:, tasks:, globals:, instances: and connections:
139  programs: [:lamp]
      programs: :lamp is not a %Logex.Program{} from Logex.compile/2
      unknown program type `lamp`: no program types were given
140  a task with priority: 1.5 and a task that is not there
      task `fast`: a priority is 0, the highest, to 65535, found 1.5
      no task `fsat` — did you mean `fast`?
141  an instance with line: 3
      program instance `l1` from Elixir has no line, got: 3
142  a global from Global.new!("t", :time)
      global `t` has type :time: a global is :bool, :sint, :int, :dint, :lint,
      :usint, :uint, :udint, :ulint, :real, :lreal, :byte, :word, :dword or
      :lword, or an array of one of them, as in `{:array, :int, [8]}`, its sizes
      a list of one integer a dimension
143  a global named "at"
      `at` is a keyword and cannot name a global
144  a global from Global.new!("total", :dint, initial: 1.5)
      `total` is a dint: `1.5` is a real, and a dint holds only integers
145  Global.new!("total", :dint, retain: true, non_retain: true)
      `total` takes `retain: true` or `non_retain: true`, not both, as a
      `var_global` line takes `retain` or `non_retain`, not both
146  Global.new!("total", :dint, retained: true)
      unknown option :retained for `total`: Logex.Configuration.Global.new!/3
      takes `initial:`, `at:`, `retain:` and `non_retain:`
147  Global.new!("total", :dint, retain: :yes)
      `retain:` for `total` takes true or false, found :yes
148  Global.new!("total", :dint, at: "panel.i.0", at: "panel.i.1")
      `at:` is given twice for `total`
149  Global.new!("total", :dint, %{retain: true})
      the options of `total` are a keyword list of `initial:`, `at:`, `retain:
      true` or `non_retain: true`, found %{retain: true}
150  Configuration.compile("line_1", :text, %{})
      Logex.Configuration.compile/3 takes source text as a binary, got: :text
151  Configuration.compile("line_1", "", %{"lamb" => lamp})
      the program under `lamb` is named `lamp`
152  Configuration.compile_file(:line_1)
      Logex.Configuration.compile_file/1 takes a path as a binary, got: :line_1
153  Configuration.watchdog(%Task{name: "fast", watchdog: 0})
      expected a %Logex.Configuration.Task{} whose watchdog is 1 to 2147483647
      ms or nil, got: %Logex.Configuration.Task{name: "fast", single: nil,
      interval: nil, priority: nil, watchdog: 0, continuous: false, line: nil}
```

## Warnings: cases 154 to 176

The script compiles 23 configurations and prints each warning. Each configuration
compiles. It uses the program types of
[The program types of the cases](#the-program-types-of-the-cases), and 11 more that it
compiles from text.

```elixir
{report, _} = Code.eval_file("instructions-contacts-and-coils/report.exs")
{types, _} = Code.eval_file("configuration-file/types.exs")

# More program types. kept_lamp retains its var_output lamp. flash keeps the storage bit
# of its ons in a global, and rise and fall have an osr and an osf. lamp_0, lamp_2 and
# lamp_3 write 1 element of the global array lamps, lamp_z writes the element that its
# input z gives, and lamps_12 writes 12 elements. bit_0 and bit_1 write 1 bit of the
# global w.
more = %{
  "kept_lamp" =>
    "var_input on bool\nvar_output retain lamp bool\nvar_output count dint\n" <>
      "xic on ote lamp\nxic on add count 1 count",
  "flash" =>
    "var_input on bool\nvar_output lamp bool\nvar_external memory bool\n" <>
      "xic on ons memory ote lamp",
  "rise" => "var_input on bool\nvar_output q bool\nvar s bool\nxic on osr s q",
  "fall" => "var_input on bool\nvar_output q bool\nvar s bool\nxic on osf s q",
  "lamp_0" => "var_input on bool\nvar_external lamps bool[13]\nxic on ote lamps[0]",
  "lamp_2" => "var_input on bool\nvar_external lamps bool[4]\nxic on ote lamps[2]",
  "lamp_3" => "var_input on bool\nvar_external lamps bool[4]\nxic on ote lamps[3]",
  "lamp_z" =>
    "var_input on bool\nvar_input z dint\nvar_external lamps bool[4]\nxic on ote lamps[z]",
  "lamps_12" =>
    "var_input on bool\nvar_external lamps bool[13]\n" <>
      Enum.map_join(0..11, "\n", &"xic on ote lamps[#{&1}]"),
  "bit_0" => "var_input on bool\nvar_external w word\nxic on ote w.0",
  "bit_1" => "var_input on bool\nvar_external w word\nxic on ote w.1"
}

types =
  Enum.reduce(more, types, fn {name, text}, types ->
    {:ok, program} = Logex.compile(text, name: name)
    Map.put(types, name, program)
  end)

lamp = "\nprogram l1 lamp\n  l1.on 0"
boxes = "\nvar_global total dint\nprogram b1 box_count with fast\n  b1.eye 0"
fast = "task fast interval 10 priority 1\n"
two = fn a, b -> "\nprogram a1 #{a}\nprogram a2 #{b}\n  a1.on 0\n  a2.on 0" end

texts = [
  # 154 to 158: a global that nothing uses, and output points that nothing writes
  "var_global spare bool" <> lamp,
  "var_global estop bool at panel.q.7" <> "\nprogram c1 belt\n  c1.start 0\n  c1.stop 0",
  "var_global fan_k bool[2] at panel.q.1\nprogram f1 fan_control\n  f1.temp 20.0\n  f1.limit 40.0\n  f1.fan fan_k[0]",
  "var_global lamps bool[3] at panel.q.0\nprogram l1 lamp\n  l1.on lamps[0]",
  "var_global lamps bool[13] at card.q.0\nprogram a1 lamp_0\n  a1.on 0",
  # 159 and 160: tasks
  fast <> "task slow interval 50 priority 2" <> lamp,
  fast <> "task main continuous\nprogram l1 lamp with fast\n  l1.on 0",
  # 161 to 164: 2 writers of 1 global
  fast <> "program b2 box_count with fast\n  b2.eye 0" <> boxes,
  fast <> "program r1 stop_record with fast\n  r1.count 0\n  r1.count_at_stop total" <> boxes,
  "var_global w word" <> two.("bit_0", "bit_1"),
  "var_global memory bool\nprogram f1 flash\n  f1.on 0\nprogram f2 flash\n  f2.on 0",
  # 165 and 166: one-shots under an event task
  "var_global eye bool\ntask on_eye single eye priority 0\nprogram b1 box_count with on_eye\n  b1.eye eye\nvar_global total dint",
  "var_global eye bool\ntask on_eye single eye priority 0\nprogram p1 rise with on_eye\n  p1.on eye\nprogram p2 fall with on_eye\n  p2.on eye",
  # 167 and 168: reals
  "var_global limit real 16777217.0\nprogram f1 fan_control\n  f1.temp 20.0\n  f1.limit limit",
  "program f1 fan_control\n  f1.temp 20.0\n  f1.limit 16777217.0",
  # 169 and 170: retained values
  "var_global lamp_k bool at panel.q.3\nprogram k1 kept_lamp\n  k1.on 0\n  k1.lamp lamp_k",
  "var_global retain count dint\nprogram k1 kept_lamp\n  k1.on 0\n  k1.count count",
  # 171 to 176: elements of a global array
  "var_global lamps bool[4] at card.q.0\nprogram a1 lamp_2\n  a1.on 0",
  "var_global lamps bool[4] at card.q.0\nprogram a1 lamp_z\n  a1.on 0\n  a1.z 0",
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_3"),
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_2"),
  "var_global lamps bool[4]" <> two.("lamp_2", "lamp_z") <> "\n  a2.z 0",
  "var_global lamps bool[13]" <> two.("lamps_12", "lamps_12")
]

report.(154, texts, &Logex.Configuration.compile("line_1", &1, types))
```

```console
$ mix run configuration-file-warnings.exs
154  var_global spare bool
    program l1 lamp
      l1.on 0
      line 1: warning: `spare` is declared but nothing uses it
155  var_global estop bool at panel.q.7
    program c1 belt
      c1.start 0
      c1.stop 0
      line 1: warning: `estop` is an output point, but nothing drives it: it
      stays at 0
156  var_global fan_k bool[2] at panel.q.1
    program f1 fan_control
      f1.temp 20.0
      f1.limit 40.0
      f1.fan fan_k[0]
      line 1: warning: `fan_k` is an array of output points, `panel.q.1` to
      `panel.q.2`, but nothing drives `fan_k[1]`: it stays at 0
157  var_global lamps bool[3] at panel.q.0
    program l1 lamp
      l1.on lamps[0]
      line 1: warning: `lamps` is an array of output points, `panel.q.0` to
      `panel.q.2`, but nothing drives it: each element stays at 0
158  var_global lamps bool[13] at card.q.0
    program a1 lamp_0
      a1.on 0
      line 1: warning: `lamps` is an array of output points, `card.q.0` to
      `card.q.12`, but nothing drives `lamps[1]`, `lamps[2]`, `lamps[3]`,
      `lamps[4]`, `lamps[5]`, `lamps[6]`, `lamps[7]`, `lamps[8]`, `lamps[9]`,
      `lamps[10]` and 2 more: they stay at 0
159  task fast interval 10 priority 1
    task slow interval 50 priority 2
    program l1 lamp
      l1.on 0
      line 1: warning: task `fast` runs no instance
      line 2: warning: task `slow` runs no instance
160  task fast interval 10 priority 1
    task main continuous
    program l1 lamp with fast
      l1.on 0
      line 2: warning: task `main` runs no instance
161  task fast interval 10 priority 1
    program b2 box_count with fast
      b2.eye 0
    var_global total dint
    program b1 box_count with fast
      b1.eye 0
      line 5: warning: `b1` writes `total` through its var_external, as `b2`
      does (line 2): each scan reads what the other last wrote, and the later
      write in a cycle stands
162  task fast interval 10 priority 1
    program r1 stop_record with fast
      r1.count 0
      r1.count_at_stop total
    var_global total dint
    program b1 box_count with fast
      b1.eye 0
      line 6: warning: `b1` writes `total` through its var_external, and
      `r1.count_at_stop` drives it (line 4): each scan reads what the other last
      wrote, and the later write in a cycle stands
163  var_global w word
    program a1 bit_0
    program a2 bit_1
      a1.on 0
      a2.on 0
      line 3: warning: `a2` writes `w` through its var_external, as `a1` does
      (line 2): each scan reads what the other last wrote, and the later write
      in a cycle stands
164  var_global memory bool
    program f1 flash
      f1.on 0
    program f2 flash
      f2.on 0
      line 4: warning: `f2` writes `memory` through its var_external, as `f1`
      does (line 2): `memory` is the storage bit of an `ons`: the one-shot then
      fires on the wrong scans
165  var_global eye bool
    task on_eye single eye priority 0
    program b1 box_count with on_eye
      b1.eye eye
    var_global total dint
      line 3: warning: `b1` runs under the event task `on_eye`, and `box_count`
      runs an `ons` on line 5 of `box_count.ld`, whose storage bit is `seen`: an
      ons sees its rung only at the task's runs, so a pulse between two runs
      never fires it, and a rung that is the task's trigger is true at every run
      and never fires it
166  var_global eye bool
    task on_eye single eye priority 0
    program p1 rise with on_eye
      p1.on eye
    program p2 fall with on_eye
      p2.on eye
      line 3: warning: `p1` runs under the event task `on_eye`, and `rise` runs
      an `osr` on its line 4, whose storage bit is `s`: an osr sees its rung
      only at the task's runs, so a pulse between two runs is never seen, the
      pulse it sets stays on until the task's next run, and a rung that is the
      task's trigger is true at every run and never pulses
      line 5: warning: `p2` runs under the event task `on_eye`, and `fall` runs
      an `osf` on its line 4, whose storage bit is `s`: an osf sees its rung
      only at the task's runs, so a drop between two runs is never seen, the
      pulse it sets stays on until the task's next run, and a rung that is the
      task's trigger is true at every run and never pulses
167  var_global limit real 16777217.0
    program f1 fan_control
      f1.temp 20.0
      f1.limit limit
      line 1: warning: `16777217.0` is more precise than a real keeps: it is
      held as 16777216.0
168  program f1 fan_control
      f1.temp 20.0
      f1.limit 16777217.0
      line 3: warning: `16777217.0` is more precise than a real keeps: it is
      held as 16777216.0
169  var_global lamp_k bool at panel.q.3
    program k1 kept_lamp
      k1.on 0
      k1.lamp lamp_k
      line 4: warning: `k1.lamp` is retained and drives the output `lamp_k`:
      after a warm start it is written in the first round
170  var_global retain count dint
    program k1 kept_lamp
      k1.on 0
      k1.count count
      line 4: warning: `count` is retained but driven by `k1.count`, which is
      not: the first round writes over it
171  var_global lamps bool[4] at card.q.0
    program a1 lamp_2
      a1.on 0
      line 1: warning: `lamps` is an array of output points, `card.q.0` to
      `card.q.3`, but nothing drives `lamps[0]`, `lamps[1]` or `lamps[3]`: they
      stay at 0
172  var_global lamps bool[4] at card.q.0
    program a1 lamp_z
      a1.on 0
      a1.z 0
      the text compiles, and logex gives no warning
173  var_global lamps bool[4]
    program a1 lamp_2
    program a2 lamp_3
      a1.on 0
      a2.on 0
      the text compiles, and logex gives no warning
174  var_global lamps bool[4]
    program a1 lamp_2
    program a2 lamp_2
      a1.on 0
      a2.on 0
      line 3: warning: `a2` writes `lamps[2]` through its var_external, as `a1`
      does (line 2): each scan reads what the other last wrote, and the later
      write in a cycle stands
175  var_global lamps bool[4]
    program a1 lamp_2
    program a2 lamp_z
      a1.on 0
      a2.on 0
      a2.z 0
      line 3: warning: `a2` may write `lamps[2]` through its var_external, as
      `a1` does (line 2): each scan reads what the other last wrote, and the
      later write in a cycle stands
176  var_global lamps bool[13]
    program a1 lamps_12
    program a2 lamps_12
      a1.on 0
      a2.on 0
      line 3: warning: `a2` writes `lamps[0]`, `lamps[1]`, `lamps[2]`,
      `lamps[3]`, `lamps[4]`, `lamps[5]`, `lamps[6]`, `lamps[7]`, `lamps[8]`,
      `lamps[9]` and 2 more through its var_external, as `a1` does (line 2):
      each scan reads what the other last wrote, and the later write in a cycle
      stands
```

| Case | The warning |
|---|---|
| 154 | A global that nothing uses |
| 155 | An output point that a program reads and nothing writes. It stays at 0. |
| 156 | 1 [element](glossary.md#element) of an array of output points that nothing writes |
| 157 | An array of output points that nothing writes. Each element stays at 0. |
| 158 | More than 10 elements that nothing writes. The message names 10 of them and gives the number of the others. |
| 159, 160 | A task that runs no instance. The continuous task is such a task when each instance has a timed task. |
| 161 | 2 instances write 1 global through `var_external` tags. |
| 162 | An instance writes through a `var_external` [tag](glossary.md#tag) a global that a driver also writes. |
| 163 | 2 instances write different [bits](glossary.md#bit) of 1 global. A write of a bit is a write of the global. |
| 164 | The global is the [storage bit](glossary.md#storage-bit) of a [one-shot](glossary.md#one-shot), and 2 instances write it. The warning also comes for an `osr` and an `osf`. |
| 165 | An `ons` under an [event task](glossary.md#event-task) |
| 166 | An `osr` and an `osf` under an event task. Each has its own words. |
| 167 | A `real` initial value with more digits than a `real` keeps |
| 168 | A `real` constant with more digits than a `real` keeps |
| 169 | A retained output writes an output point. After a [warm restart](glossary.md#warm-restart), the output point gets the kept value in the first [round](glossary.md#round), or the first [cycle](glossary.md#cycle) with no [runner](glossary.md#runner). |
| 170 | A retained global with a driver that its program does not retain. The first round, or the first cycle, writes over the kept value. |
| 171 | An array of output points, and a program writes 1 element through a `var_external` tag. The other elements stay at 0. |
| 172 | No warning. logex counts `ote lamps[z]` as a write of each element of the array. |
| 173 | No warning. 2 instances write different elements. |
| 174 | 2 instances write the same element. |
| 175 | An instance writes `lamps[2]`, and an instance with `ote lamps[z]` possibly writes it too. The message says `may write`. |
| 176 | 2 instances write the same 12 elements. 1 warning names 10 of them and gives the number of the others. |

Each [timer](glossary.md#timer) and each [counter](glossary.md#counter) under an event
task also gives a warning.
[Instructions: timers and counters](instructions-timers-and-counters.md) shows each of
these messages. [Warnings](warnings.md) gives each warning of logex.

## See also

- [Configuration file](configuration-file.md) gives the rules of each line.
- [Diagnostics](diagnostics.md) gives the form of a diagnostic.
- [Write a configuration file](../howto/write-a-configuration-file.md) shows how to
  write a configuration file step by step.
- [Glossary](glossary.md) gives the technical words of logex.
