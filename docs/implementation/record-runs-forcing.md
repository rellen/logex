# Runs and tables of the records: forcing

This page is for a contributor who reads a decision record about input forcing. It holds the
runs, the measurements and the long tables of record 0015, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0015. Input forcing

These tables and this run support [0015. Input forcing](../adr/0015-input-forcing.md).

### The words of the record

| Word | Meaning on this page |
|---|---|
| Input point | A point that a [device](../../guides/reference/glossary.md#device) reads, such as `eye` at `panel.i.8` |
| Output point | A point that a device writes, such as `k1` at `panel.q.0` |
| Last value | The value of an input point that its device gave last. The runner keeps it for each input point |
| The set | All the forces of a runner, by the name of each input point |
| Fresh start | A start of a new runner by `Logex.Runner.start_link/1`, for example after a crash |
| Restart | `Logex.Runner.restart/2` of a runner after a [trip](../../guides/reference/glossary.md#trip). The runner is the same process |
| End of a write | The runner renames `<path>.tmp` over the forces file. The file then holds the new set |
| A write in progress | A write of the forces file that started and did not end |
| A joined write | 1 write for all the changes that wait behind a write in progress |
| A cut write | A write that did not end in `write_limit:` ms |

### What each start does

| Event | What the runner does |
|---|---|
| Fresh start, no file | It starts with no force |
| Fresh start, a file it can read | It forces each point that the file names, and lists the forces from the first round |
| A start or a restart, and a bad line in the file | It raises 1 error that names each bad line, and does not start. A restart stays tripped |
| Restart | It reads the file. A point that the file does not force reads its last value |
| Fresh start, a file it cannot read | It starts with no force. `forces_unread` names the file |
| Restart, a file it cannot read | It keeps its own set. `forces_unread` names the file |
| Restart while `forces_unread` names the file | It keeps its own set and reads no file (decision 445) |
| Orderly stop while `forces_unread` names the file | It writes its own set over the file (decision 472) |
| A crash | It writes nothing |

### The lines of the forces file

| A line | What the runner does |
|---|---|
| `eye 1` | It forces `eye` to 1 |
| `eye 01`, `level 16#ff`, `hz 3.75e1` | It reads any number that the lexer reads as 1 [literal](../../guides/reference/glossary.md#literal), in the range of the type of the point. The next write spells it `eye 1`, `level 255` and `hz 37.5` |
| `hz 16777217` at a `real` | It forces the nearest value that the type holds, `16777216.0` |
| `level 16#ffffffff` at a `dint` | It refuses the line. The message quotes the text of the line and the value that the runner reads (decision 255) |
| `zone_t[3] 170.0` | It forces 1 [element](../../guides/reference/glossary.md#element) of a located [array](../../guides/reference/glossary.md#array) |
| `zone_t 170.0 170.0 ...`, a value for each element | It forces each element. The next write gives each element its own line (decision 248). A different count of values is a bad line |
| `eye 1` on 2 lines | It refuses the start and names the second line |
| `k1 1`, at an output point | It refuses the start: only an input point is forced |
| A comment, an empty line, 2 spaces, a tab, or 1 space after the value | It refuses the start and names the line |
| The last line with no line end | It reads the line |

### The rules in a run

The script `0015-input-forcing.exs` runs the packing line on the manual
[clock](../../guides/reference/glossary.md#clock), with a
[simulated device](../../guides/reference/glossary.md#simulated-device). Thus its output
is the same at each run. The script gives a relative path, `packing.forces`, so that its
messages are the same on each machine. A host gives an absolute path:
[0018](../adr/0018-file-work-with-a-limit.md#a-file-that-cannot-be-read) gives the reason. The
plant of the script is `packing.logex`:

<!-- file: packing.logex -->
```text
// packing.logex -- a conveyor on a 10 ms task, and a box counter in the continuous task
task fast interval 10 priority 1 watchdog 50
task main continuous watchdog 200

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_reset   bool at panel.i.2
var_global eye        bool at panel.i.8
var_global k1         bool at panel.q.0
var_global case_full  bool at panel.q.4

program c1 conveyor with fast
  c1.start pb_start_1
  c1.stop  0
  c1.reset pb_reset
  c1.motor k1

program b1 boxes
  b1.eye       eye
  b1.reset_pb  pb_reset
  b1.full_lamp case_full
```

The script also reads 4 files from `examples/`. Each link leads to the page that shows
the file:

- [`conveyor.ld`](../../guides/howto/try-an-edit-on-a-simulated-device.md), the conveyor.
- [`boxes.ld`](../../guides/howto/try-an-edit-on-a-simulated-device.md), which counts
  the boxes in `b1.count`.
- [`trip.logex`](../../guides/howto/edit-a-plant-without-the-runner.md), the conveyor
  with the event task `trip` on the trigger `estop`.
- [`snapshot.ld`](../../guides/howto/edit-a-plant-without-the-runner.md), the program of
  the task `trip`.

```elixir
# The rules of record 0015 in a run: what a runner forces, where it keeps the forces, and
# what a start and a restart read. The runner runs on a manual clock, with a simulated
# panel, so the output is the same at each run.
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

Logger.configure(level: :none)
{:ok, packing} = Logex.Configuration.compile_file("packing.logex")
{:ok, trip} = Logex.Configuration.compile_file("trip.logex")
forces = "packing.forces"
File.rm_rf!(forces)

# Starts a runner of `plant` with the options, and gives the runner, its clock and its panel.
start = fn plant, options ->
  {:ok, clock} = Manual.start_link()
  {:ok, panel} = Sim.start_link(reports: true, clock: clock)
  io = %{"panel" => {Sim, sim: panel}}
  options = [configuration: plant, io: io, clock: {Manual, clock}] ++ options
  {:ok, runner} = Runner.start_link(options)
  {runner, clock, panel}
end

# Prints the answer of `fun`, or the message of the ArgumentError that it raises.
attempt = fn fun ->
  try do
    IO.puts("  " <> inspect(fun.()))
  rescue
    error in ArgumentError -> IO.puts("  " <> error.message)
  end
end

# Prints the time, the value of eye that the program reads, the count and the forces.
show = fn runner ->
  %{now: now, forces: in_effect} = Runner.status(runner)
  eye = Runner.get!(runner, "eye")
  boxes = Runner.get!(runner, "b1.count")
  IO.puts("  t=#{now} eye=#{eye} boxes=#{boxes} forces=#{inspect(in_effect)}")
end

# Moves the real photo-eye on and off. Each change gets a round of 1 ms.
box = fn panel, clock ->
  Sim.set(panel, "panel.i.8", 1)
  Manual.advance(clock, 1)
  Sim.set(panel, "panel.i.8", 0)
  Manual.advance(clock, 1)
end

file = fn -> IO.puts("  packing.forces: " <> inspect(File.read!(forces))) end

IO.puts("1. A runner with no forces file")
{runner, _clock, _panel} = start.(packing, [])
attempt.(fn -> Runner.force(runner, "eye", 1) end)
:ok = Runner.stop(runner)

IO.puts("2. An output point, a tag of an instance, and the core")
{runner, clock, panel} = start.(packing, forces: forces)
attempt.(fn -> Runner.force(runner, "k1", 1) end)
attempt.(fn -> Runner.force(runner, "b1.eye", 1) end)
{:module, Logex.Runtime} = Code.ensure_loaded(Logex.Runtime)
names = for {name, arity} <- Logex.Runtime.__info__(:functions), do: "#{name}/#{arity}"
forcing = Enum.filter(names, &String.contains?(&1, "forc"))
IO.puts("  functions of Logex.Runtime with forc in the name: #{inspect(forcing)}")

IO.puts("3. The real eye counts, then the force holds eye at 1")
box.(panel, clock)
show.(runner)
:ok = Runner.force(runner, "eye", 1)
Manual.advance(clock, 1)
show.(runner)
box.(panel, clock)
box.(panel, clock)
show.(runner)
file.()

IO.puts("4. A write of the file that fails")
File.mkdir!(forces <> ".tmp")
attempt.(fn -> Runner.force(runner, "pb_reset", 1) end)
show.(runner)
file.()
File.rmdir!(forces <> ".tmp")

IO.puts("5. A crash, and a fresh start that reads the file")
Process.flag(:trap_exit, true)
Process.exit(runner, :kill)
receive do: ({:EXIT, ^runner, :killed} -> :ok)
{runner, clock, panel} = start.(packing, forces: forces)
show.(runner)

IO.puts("6. The real eye is on, and then eye is unforced")
Sim.set(panel, "panel.i.8", 1)
Manual.advance(clock, 1)
show.(runner)
:ok = Runner.unforce(runner, "eye")
Manual.advance(clock, 1)
show.(runner)
file.()
:ok = Runner.stop(runner)

IO.puts("7. A forced trigger")
{runner, _clock, panel} = start.(trip, forces: forces)
:ok = Runner.subscribe(runner, [:ran])

# Prints the tasks that ran since the last look, from the :ran events.
ran = fn label ->
  _ = :sys.get_state(runner)
  {:messages, messages} = Process.info(self(), :messages)
  tasks = for {Runner, ^runner, {:ran, task, _, _}} <- messages, do: task
  for {Runner, ^runner, _} <- messages, do: receive(do: ({Runner, ^runner, _} -> :ok))
  IO.puts("  #{label}: ran #{inspect(tasks)}")
end

press = fn ->
  Sim.set(panel, "panel.i.7", 1)
  Sim.set(panel, "panel.i.7", 0)
end

:ok = Runner.force(runner, "estop", 1)
ran.("force estop 1")
press.()
ran.("the real e-stop pressed and let go")
:ok = Runner.force(runner, "estop", 1)
ran.("force estop 1 again")
:ok = Runner.unforce(runner, "estop")
ran.("unforce estop")
press.()
ran.("the real e-stop pressed and let go")
:ok = Runner.stop(runner)

IO.puts("8. A forces file that a person writes")
File.write!(forces, "// the eye, blocked for a test\neye 1\n")
attempt.(fn -> start.(packing, forces: forces) end)
File.write!(forces, "pb_reset 1_0\n")
attempt.(fn -> start.(packing, forces: forces) end)
File.write!(forces, "eye 01\r\n")
{runner, _clock, _panel} = start.(packing, forces: forces)
show.(runner)
:ok = Runner.force(runner, "pb_reset", 1)
file.()
:ok = Runner.stop(runner)

IO.puts("9. A forces file that the start cannot read")
File.rm!(forces)
File.mkdir!(forces)
{runner, clock, panel} = start.(packing, forces: forces)
%{forces_unread: {_path, reason}} = Runner.status(runner)
IO.puts("  forces_unread: the file, #{inspect(reason)}")
File.rmdir!(forces)
File.write!(forces, "eye 1\n")
# A failed read of the panel trips the runner. The script can then ask for a restart.
Sim.fail(panel, :read, {:error, :eio})
Manual.advance(clock, 10)
IO.puts("  #{Runner.status(runner).status}, restart: #{inspect(Runner.restart(runner, :cold))}")
show.(runner)
IO.puts("  stop: #{inspect(Runner.stop(runner))}")
file.()
File.rm!(forces)
```

```console
$ mix run 0015-input-forcing.exs
1. A runner with no forces file
  the runner keeps no forces file, so a force would not survive a crash: start it with forces: a path
2. An output point, a tag of an instance, and the core
  `k1` is an output point, at `panel.q.0`: only an input point is forced
  `b1.eye` is no input point of `packing`
  functions of Logex.Runtime with forc in the name: []
3. The real eye counts, then the force holds eye at 1
  t=2 eye=0 boxes=1 forces=%{}
  t=3 eye=1 boxes=2 forces=%{"eye" => 1}
  t=7 eye=1 boxes=2 forces=%{"eye" => 1}
  packing.forces: "eye 1\n"
4. A write of the file that fails
  {:error, {:forces, :eisdir}}
  t=7 eye=1 boxes=2 forces=%{"eye" => 1}
  packing.forces: "eye 1\n"
5. A crash, and a fresh start that reads the file
  t=0 eye=1 boxes=0 forces=%{"eye" => 1}
6. The real eye is on, and then eye is unforced
  t=1 eye=1 boxes=0 forces=%{"eye" => 1}
  t=2 eye=1 boxes=0 forces=%{}
  packing.forces: ""
7. A forced trigger
  force estop 1: ran ["trip"]
  the real e-stop pressed and let go: ran []
  force estop 1 again: ran []
  unforce estop: ran []
  the real e-stop pressed and let go: ran ["trip"]
8. A forces file that a person writes
  packing.forces: line 1: `// the eye, blocked for a test` is no force: a line holds an input point's name and its value, as `eye_1 1`
  packing.forces: line 1: `pb_reset` is a bool, forced to 0 or 1, got: 1_0, which is 10
  t=0 eye=1 boxes=0 forces=%{"eye" => 1}
  packing.forces: "eye 1\npb_reset 1\n"
9. A forces file that the start cannot read
  forces_unread: the file, :eisdir
  tripped, restart: :ok
  t=9 eye=0 boxes=0 forces=%{}
  stop: :ok
  packing.forces: ""
```

This table gives the line of output that shows each rule:

| Result and rule | The output to read |
|---|---|
| 1. A runner with no `forces:` refuses each force | The message names the option |
| 2. Only an input point is forced. The core has no force | The runner refuses `k1` and `b1.eye`. No function of `Logex.Runtime` has "forc" in its name |
| 3. A force holds the input against its device | The force is a rise of `eye`, and the count goes to 2. 2 boxes of the real eye then count nothing |
| 4. A write that fails changes nothing | A directory in the place of the `.tmp` file stops the write. The forces and the file are as before |
| 5. The file keeps a force after a crash | The new runner reads `eye 1` and lists it. The count is 0: it is not a retained value |
| 6. An unforce gives the last value of the device | The real eye went on during the force. After the unforce, `eye` reads 1 |
| 7. A forced trigger runs its task 1 time, immediately | The force runs `trip`. A press, a second force and the unforce run nothing. After the unforce, a press runs `trip` |
| 8. The runner reads the file strictly, and a value is any literal | The runner refuses a comment. The message quotes `1_0` and the value 10. The runner reads `eye 01` with CRLF, and the next write spells it `eye 1` |
| 9. A restart keeps the set of the runner while `forces_unread` names the file | The start was not able to read the directory. The restart does not read `eye 1` from the file, and the stop writes the empty set over it |

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
