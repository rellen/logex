# Runs and tables of the records: tasks and edits

This page is for a contributor who reads a decision record about the schedule and the online edit. It holds the
runs, the measurements and the long tables of records 0011 and 0012, so that each record stays
short. Each section names its record, and each record links to its section.

The suite runs each example of this page, as it runs the examples of each other page.
Each script and its files are under `examples/`.

## 0011. Tasks and rounds

These tables and runs support [0011. Tasks and rounds](../adr/0011-tasks-and-rounds.md).

### The rules of 1 cycle

| Rule | What logex does |
|---|---|
| The priority | Each timed task must have one, from 0 to 65535. 0 is the highest (decisions 11 and 37) |
| A tie of priority | The task with the earlier due time runs first. The due time of an event task is the time of the cycle (decision 11) |
| A tie of due time | The task whose line comes first in the configuration runs first (decision 11) |
| The instances of a task | They run in the sequence of their `program` lines (decision 11) |
| The continuous task | Its instances run last, 1 time in each cycle. It is never due and never misses a period (decision 111) |
| A late periodic task | It runs 1 time, and counts each other due time that passed as an [overlap](../../guides/reference/glossary.md#overlap): 3 due times give 1 run and 2 overlaps. It reports `{:overlap, task, missed}`. Its due times stay on the grid (decision 11) |
| An event task | It is due when the cycle samples 1 from its trigger and the last sample was 0. A trigger that is 1 in the first cycle counts (decision 11) |
| A pulse of a trigger between 2 cycles | No cycle sees it (§4.6) |
| A trigger that logic writes | The next cycle samples it (decision 50) |
| A task with `single` and `interval` | It runs 1 time in a cycle at most. It skips a due time while the cycle samples 1 from its trigger, and does not count it. Its due times stay on the grid (decision 39) |
| A late cycle that samples a rise | It runs the task 1 time. logex judges the due times since the last cycle by this sample, 1, so it skips them and does not count them (decision 51) |
| A late cycle that samples a fall | It runs the task 1 time, for a due time that came while the input image held 1. It counts the other due times that passed as overlaps (decision 52) |
| `Logex.Runtime.next_due_in/1` | It counts the periodic due times only. With event tasks or untimed instances only, it gives `:infinity` (decision 50) |
| The first cycle | The host must run it immediately after `Logex.Runtime.start/1` and `Logex.Runtime.restart/2`, whatever `next_due_in/1` gives (decision 50) |
| `Logex.Runtime.restart/2` | It starts each instance again. It keeps the clock and the input image, and sets each count of overlaps to 0 (decision 38) |
| `Logex.Runtime.overlaps/1` | It gives the count of overlaps of each task (decision 38) |

### The slots of the share

| `overhead:` | C, ms of rounds | S, ms for calls |
|---|---|---|
| 10 | 9 | 1 |
| 20, the default | 4 | 1 |
| 50 | 1 | 1 |
| 90 | 1 | 9 |

### The causes of a round

| Cause | When the round runs |
|---|---|
| A start or a [restart](../../guides/reference/glossary.md#restart) | Immediately (decision 50) |
| The configuration has an untimed instance | Back to back, 1 round in each millisecond of the clock at most. After a round of 1 ms or more, the next round runs immediately (decisions 108 and 122) |
| A periodic task is due | At its due time. If a round is in progress, at the start of the next round (decisions 108 and 122) |
| A [device](../../guides/reference/glossary.md#device) reports a change of a trigger | Immediately. Each change of a trigger has its own round, in the sequence of the changes (decisions 112 and 120) |
| A force or an unforce changes what a trigger reads | Immediately, 1 round for each trigger that it changes (decision 123) |
| A round writes a trigger | In the next millisecond of the clock (decision 123) |
| A device reports a change of a different input | No round. The next round merges the change (decision 120) |

### A rise that a trip cuts off

In a probe on the runner, the eye latches `arm`, and the event task counts a box and
clears `arm`. A [fault](../../guides/reference/glossary.md#fault) of a periodic task trips
the round before the step of the event task:

| | After the trip | After the warm restart |
|---|---|---|
| The count of the event task | 0 | 1 |
| `arm` | 1 | 0 |

The case "a trigger's rise a trip cut off (decision 350)" in
`test/logex/retain_store_test.exs` checks the same rule, with the same `arm`.

### The rules in a run

The script `examples/0011-tasks-and-rounds.exs` shows the rules of this record as
numbered results. Run it from `examples/`. It reads this configuration, the plant of the
design:

<!-- file: 0011-tasks-and-rounds/plant.logex -->
```text
// plant.logex -- the conveyor, the fan, the e-stop and the boxes
task fast interval 10 priority 1
task slow interval 500 priority 2
task trip single estop priority 0
task main continuous

var_global estop      bool at panel.i.7
var_global pb_start_1 bool at panel.i.0
var_global pb_reset   bool at panel.i.2
var_global eye        bool at panel.i.8
var_global hz         real at drive.i.0
var_global k1         bool at panel.q.0
var_global case_full  bool at panel.q.4
var_global fan_rpm    int  at drive.q.0
var_global k1_at_trip bool

program c1 conveyor with fast
  c1.start pb_start_1
  c1.stop  0
  c1.reset pb_reset
  c1.motor k1

program f1 fan with slow
  f1.hz  hz
  f1.rpm fan_rpm

program snap snapshot with trip
  snap.a     k1
  snap.a_was k1_at_trip

program b1 boxes
  b1.eye       eye
  b1.reset_pb  pb_reset
  b1.full_lamp case_full
```

The script also reads 4 program files from `examples/`. Each link leads to the page that
shows the file:

- [`conveyor.ld`](../../guides/howto/try-an-edit-on-a-simulated-device.md), the conveyor.
- [`boxes.ld`](../../guides/howto/try-an-edit-on-a-simulated-device.md), which counts
  the boxes.
- [`snapshot.ld`](../../guides/howto/edit-a-plant-without-the-runner.md), which copies
  `k1` when the e-stop rises.
- [`fan.ld`](record-runs-faults.md), which computes the speed of the fan.

Results 6 and 7 use a small program, `flash`, that changes the lamp in each scan and
counts its scans in `n`. In results 6 and 7, each write to the device `lamps` moves the
manual clock. A write moves it 25 ms in result 6 and 1 ms in result 7, so each round takes
that time. On the manual clock, `advance(clock, 0)` runs the 1 round that the runner owes.
In result 7, each answer is `l1.n`, the count of scans, which is the number of the last
round.

This table gives the line of output that shows each rule:

| Result | Rule | The output to read |
|---|---|---|
| 1 | The due tasks run by priority, then the continuous task. A trigger that is 1 in the first cycle counts | `trip`, priority 0, runs first, then `fast`, `slow` and `main` |
| 2 | A late cycle runs a task 1 time and counts the overlaps | At 55 ms: 30, 40 and 50 ms passed, so 1 run and `{:overlap, "fast", 2}`. The next due time is 60 ms |
| 3 | `next_due_in/1` counts the periodic due times only | `:infinity` for an event task alone |
| 4 | With an untimed instance, the rounds come back to back, and a trigger makes a round immediately | 10 rounds in 10 ms. The e-stop makes 1 more round at 10 ms. The eye makes no round, and the next round counts the box |
| 5 | With no untimed instance, a round comes only at a due time. A trigger that logic writes makes a round 1 ms later | `now` is the time of the last round, 30 ms. The 4 rounds are the start and 3 due times. The start button makes no round. `c1` sets `k1` at 40 ms, and `started` runs at 41 ms |
| 6 | A due task waits for the round in progress | Each round takes 25 ms. `fast` runs every 25 ms, not every 10 ms, and counts its overlaps |
| 7 | A call waits for its slot | At 20 %, the answers come after rounds 4, 8 and 12: C is 4. An open slot answers a call immediately, after round 7 |

```elixir
alias Logex.Runtime
alias Logex.Runner
alias Logex.Runner.Clock.Manual
alias Logex.IO.Sim

programs =
  Map.new(~w(conveyor fan snapshot boxes), fn name ->
    {:ok, program} = Logex.compile_file(name <> ".ld")
    {name, program}
  end)

text = File.read!("0011-tasks-and-rounds/plant.logex")
{:ok, plant} = Logex.Configuration.compile("plant", text, programs)

# Give each cycle its milliseconds and the inputs that change. Print the events.
cycles = fn runtime, changes ->
  Enum.reduce(changes, runtime, fn {ms, inputs}, runtime ->
    {runtime, _outputs, events} = Runtime.cycle(runtime, ms, inputs)
    IO.puts("  +#{ms} ms #{inspect(inputs)}: #{inspect(events)}")
    runtime
  end)
end

IO.puts("1. The core: the due tasks by priority, then the continuous task")
runtime = cycles.(Runtime.start(plant), [{0, %{"estop" => 1}}, {10, %{}}])

IO.puts("2. A late cycle: 1 run, the missed periods counted")
runtime = cycles.(runtime, [{10, %{"estop" => 0}}, {35, %{"estop" => 1}}])
IO.puts("  overlaps: #{inspect(Runtime.overlaps(runtime))}")
IO.puts("  next_due_in: #{Runtime.next_due_in(runtime)} ms")

IO.puts("3. next_due_in/1 counts the periodic tasks only")

{:ok, alone} =
  Logex.Configuration.compile(
    "alone",
    """
    task trip single estop priority 0
    var_global estop      bool at panel.i.7
    var_global k1_at_trip bool
    program snap snapshot with trip
      snap.a     estop
      snap.a_was k1_at_trip
    """,
    Map.take(programs, ["snapshot"])
  )

IO.puts("  an event task alone: #{inspect(Runtime.next_due_in(Runtime.start(alone)))}")

# Each of the first 100 writes to the device passes ms on the manual clock.
slow_writes = fn {:ok, sim}, ms ->
  Enum.each(1..100, fn _write -> Sim.fail(sim, :write, {:delay, ms}) end)
  {:ok, sim}
end

# A device that reports its changes, a device that does not, or a slow device.
device = fn
  clock, :reports -> Sim.start_link(clock: clock, reports: true)
  clock, :reads -> Sim.start_link(clock: clock)
  clock, ms -> slow_writes.(Sim.start_link(clock: clock), ms)
end

# Start a runner on a manual clock, with a simulated device for each name.
on_the_clock = fn configuration, devices, options ->
  {:ok, clock} = Manual.start_link()

  io =
    Map.new(devices, fn {name, kind} ->
      {:ok, sim} = device.(clock, kind)
      {name, {Sim, sim: sim}}
    end)

  options = [configuration: configuration, io: io, clock: {Manual, clock}] ++ options
  {:ok, runner} = Runner.start_link(options)
  {runner, clock, Map.new(io, fn {name, {Sim, sim: sim}} -> {name, sim} end)}
end

rounds = fn runner, label ->
  %{now: now, rounds: rounds} = Runner.status(runner)
  IO.puts("  #{label}: now #{now} ms, #{rounds} rounds")
end

# Print each event that the runner sent since the last look.
events = fn events, runner ->
  receive do
    {Runner, ^runner, event} ->
      IO.puts("    #{inspect(event)}")
      events.(events, runner)
  after
    0 -> :ok
  end
end

IO.puts("4. The runner: rounds back to back while the continuous task runs a program")

{runner, clock, %{"panel" => panel}} =
  on_the_clock.(plant, %{"panel" => :reports, "drive" => :reads}, [])

rounds.(runner, "start")
Manual.advance(clock, 10)
rounds.(runner, "10 ms later")
Sim.set(panel, "panel.i.7", 1)
rounds.(runner, "the e-stop rises")
Sim.set(panel, "panel.i.8", 1)
rounds.(runner, "the eye sees a box")
Manual.advance(clock, 1)
rounds.(runner, "1 ms later")
IO.puts("  b1.count: #{Runner.get!(runner, "b1.count")}")
:ok = Runner.stop(runner)

IO.puts("5. No untimed instance: a round only when a task is due")

{:ok, timed} =
  Logex.Configuration.compile(
    "timed",
    """
    task fast interval 10 priority 1
    task started single k1 priority 3
    var_global pb_start_1 bool at panel.i.0
    var_global estop      bool at panel.i.7
    var_global k1         bool at panel.q.0
    var_global k1_seen    bool
    program c1 conveyor with fast
      c1.start pb_start_1
      c1.stop  0
      c1.reset 0
      c1.motor k1
    program snap snapshot with started
      snap.a     k1
      snap.a_was k1_seen
    """,
    Map.take(programs, ["conveyor", "snapshot"])
  )

{runner, clock, %{"panel" => panel}} = on_the_clock.(timed, %{"panel" => :reports}, [])
:ok = Runner.subscribe(runner, [:ran])
Manual.advance(clock, 35)
rounds.(runner, "35 ms later")
events.(events, runner)
Sim.set(panel, "panel.i.0", 1)
rounds.(runner, "start pressed")
Manual.advance(clock, 5)
rounds.(runner, "5 ms later")
events.(events, runner)
Manual.advance(clock, 1)
rounds.(runner, "1 ms later")
events.(events, runner)
:ok = Runner.stop(runner)

# A program that changes the lamp in each scan, and counts its scans.
{:ok, flash} =
  Logex.compile(
    """
    var_output lamp bool
    var_output n dint

    xio lamp ote lamp
    add n 1 n
    """,
    name: "flash"
  )

IO.puts("6. A round of 25 ms: the fast task waits for the next round")

{:ok, delays} =
  Logex.Configuration.compile(
    "delays",
    """
    task fast interval 10 priority 1
    task main continuous
    var_global lamp       bool at lamps.q.0
    var_global k1_at_trip bool
    program l1 flash
      l1.lamp lamp
    program snap snapshot with fast
      snap.a     0
      snap.a_was k1_at_trip
    """,
    Map.put(Map.take(programs, ["snapshot"]), "flash", flash)
  )

{runner, clock, _sims} = on_the_clock.(delays, %{"lamps" => 25}, poll: 1000)
:ok = Runner.subscribe(runner, [:ran, :overlap])
Enum.each(1..3, fn _advance -> Manual.advance(clock, 0) end)
IO.puts("  each round takes 25 ms: the clock at #{Manual.now_ms(clock)} ms")
events.(events, runner)
:ok = Runner.stop(runner)

IO.puts("7. The share: a call waits for its slot")

# Make the call from a separate process. Advance the clock 0 ms until it answers.
answered = fn
  _answered, {:ok, n}, _task, _clock ->
    n

  answered, nil, task, clock ->
    Manual.advance(clock, 0)
    answered.(answered, Task.yield(task, 10), task, clock)
end

slots = fn configuration, overhead, idle ->
  {runner, clock, _sims} =
    on_the_clock.(configuration, %{"lamps" => 1}, overhead: overhead, poll: 1000)

  Enum.each(1..idle//1, fn _advance -> Manual.advance(clock, 0) end)

  answers =
    Enum.map(1..3, fn _call ->
      task = Task.async(fn -> Runner.get!(runner, "l1.n") end)
      answered.(answered, Task.yield(task, 10), task, clock)
    end)

  :ok = Runner.stop(runner)
  Enum.join(answers, ", ")
end

flashing = fn tasks ->
  {:ok, configuration} =
    Logex.Configuration.compile(
      "lamp",
      tasks <>
        "var_global lamp bool at lamps.q.0\nprogram l1 flash with lamp_task\n  l1.lamp lamp\n",
      %{"flash" => flash}
    )

  configuration
end

continuous = flashing.("task lamp_task continuous\n")
periodic = flashing.("task lamp_task interval 1 priority 1\n")

for {label, configuration, overhead, idle} <- [
      {"continuous task, overhead 20", continuous, 20, 0},
      {"continuous task, overhead 50", continuous, 50, 0},
      {"continuous task, overhead 10", continuous, 10, 0},
      {"continuous task, overhead 20, a call after round 7", continuous, 20, 6},
      {"periodic task of 1 ms, overhead 20", periodic, 20, 0}
    ] do
  IO.puts("  #{label}: answers after rounds #{slots.(configuration, overhead, idle)}")
end
```

```console
$ mix run 0011-tasks-and-rounds.exs
1. The core: the due tasks by priority, then the continuous task
  +0 ms %{"estop" => 1}: [{:ran, "trip", "snap", 0}, {:ran, "fast", "c1", 0}, {:ran, "slow", "f1", 0}, {:ran, "main", "b1", 0}]
  +10 ms %{}: [{:ran, "fast", "c1", 10}, {:ran, "main", "b1", 10}]
2. A late cycle: 1 run, the missed periods counted
  +10 ms %{"estop" => 0}: [{:ran, "fast", "c1", 20}, {:ran, "main", "b1", 20}]
  +35 ms %{"estop" => 1}: [{:ran, "trip", "snap", 55}, {:overlap, "fast", 2}, {:ran, "fast", "c1", 55}, {:ran, "main", "b1", 55}]
  overlaps: %{"fast" => 2, "main" => 0, "slow" => 0, "trip" => 0}
  next_due_in: 5 ms
3. next_due_in/1 counts the periodic tasks only
  an event task alone: :infinity
4. The runner: rounds back to back while the continuous task runs a program
  start: now 0 ms, 1 rounds
  10 ms later: now 10 ms, 11 rounds
  the e-stop rises: now 10 ms, 12 rounds
  the eye sees a box: now 10 ms, 12 rounds
  1 ms later: now 11 ms, 13 rounds
  b1.count: 1
5. No untimed instance: a round only when a task is due
  35 ms later: now 30 ms, 4 rounds
    {:ran, "fast", "c1", 10}
    {:ran, "fast", "c1", 20}
    {:ran, "fast", "c1", 30}
  start pressed: now 30 ms, 4 rounds
  5 ms later: now 40 ms, 5 rounds
    {:ran, "fast", "c1", 40}
  1 ms later: now 41 ms, 6 rounds
    {:ran, "started", "snap", 41}
6. A round of 25 ms: the fast task waits for the next round
  each round takes 25 ms: the clock at 100 ms
    {:overlap, "fast", 1}
    {:ran, "fast", "snap", 25}
    {:ran, "main", "l1", 25}
    {:overlap, "fast", 2}
    {:ran, "fast", "snap", 50}
    {:ran, "main", "l1", 50}
    {:overlap, "fast", 1}
    {:ran, "fast", "snap", 75}
    {:ran, "main", "l1", 75}
7. The share: a call waits for its slot
  continuous task, overhead 20: answers after rounds 4, 8, 12
  continuous task, overhead 50: answers after rounds 1, 2, 3
  continuous task, overhead 10: answers after rounds 9, 18, 27
  continuous task, overhead 20, a call after round 7: answers after rounds 7, 8, 12
  periodic task of 1 ms, overhead 20: answers after rounds 4, 8, 12
```

In result 6, the round at 25 ms finds 2 due times of `fast`, 10 and 20 ms: 1 run and 1
overlap. The round at 50 ms finds 3, 30, 40 and 50 ms: 1 run and 2 overlaps.

In result 7, the first call at 50 % takes the slot that opened after round 1, so it gets
its answer immediately. A call after round 7 takes the slot that opened after round 4.
The count started again at that slot, so the next call waits only for round 8 (decision
471). The periodic task of 1 ms gives the same answers as the continuous task (decision
396).

## 0012. The staged online edit

These tables and this run support
[0012. The staged online edit](../adr/0012-staged-online-edit.md).

### What each step does

| Step | What it does, and what runs next |
|---|---|
| [accept](../../guides/reference/glossary.md#accept) | It changes no state, and the original runs on. It returns the forecast: the report of a test at this moment (decision 27) |
| [test](../../guides/reference/glossary.md#test) | It switches the state to the candidate. The candidate runs |
| [untest](../../guides/reference/glossary.md#untest) | It switches the state back. The original runs |
| [assemble](../../guides/reference/glossary.md#assemble) | It removes the values that only the original declares. The candidate runs, and the edit ends |
| [cancel](../../guides/reference/glossary.md#cancel) from accept | It changes no state, and the report is `[]`. The original runs, and the edit ends |
| cancel after an untest | It removes the values that only the candidate declares. The original runs, and the edit ends |

### What a switch does with each change

| Change in the candidate | What a switch does |
|---|---|
| An added tag | It starts the tag at its initial value, as `:added` (decisions 18 and 26) |
| A removed tag | It keeps the tag, unused, until assemble or cancel removes it, as `:pruned` (decisions 18 and 315) |
| A [one-shot](../../guides/reference/glossary.md#one-shot) that the edit adds, or whose [rung](../../guides/reference/glossary.md#rung) changes | It blocks the one-shot until a scan runs it, as `:ons_blocked` (decisions 21, 32, 87 and 106) |
| The [preset](../../guides/reference/glossary.md#preset) of a [timer](../../guides/reference/glossary.md#timer) or a [counter](../../guides/reference/glossary.md#counter) | It moves `.pre` (`.pv` of a counter) only if it holds the old preset, as `:preset`. It keeps a value that logic wrote, as `:preset_kept` (decisions 23, 88 and 95). `:dn_rises` and `:dn_drops` say what the done bit does at its next run (decisions 381 and 421) |
| A timer that the program after the switch runs, and the program before the switch does not | It resumes the timer, as `:resumed` (decisions 23 and 339 to 341) |
| An output that the program after the switch does not drive | It keeps the value, as `:held` (decisions 20 and 58) |

### The rules in a run

The script `examples/0012-staged-online-edit.exs` shows the rules of this record as
numbered results. Run it from `examples/`. It reads `motor.ld` and `motor_v2.ld`.

`motor.ld` is the original. A [seal-in](../../guides/reference/glossary.md#seal-in)
rung runs the motor, and a lamp shows that it runs:

<!-- file: motor.ld -->
```text
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output run_lamp bool
var_output speed_sp dint 1200
var fault bool

( xic start | xic motor ) xio stop ote motor
xic motor ote run_lamp
xic overtemp otl fault
xic reset otu fault
xic fault move 0 speed_sp
```

`motor_v2.ld` is the candidate. It removes `run_lamp`. It adds `at_speed`, which comes
on 2 s after the motor starts, and `started`, a pulse when the motor starts:

<!-- file: motor_v2.ld -->
```text
var_input start bool
var_input stop bool
var_input overtemp bool
var_input reset bool
var_output motor bool
var_output at_speed bool
var_output started bool
var_output speed_sp dint 1200
var fault bool
var t1 ton
var s1 bool

( xic start | xic motor ) xio stop ote motor
xic motor ton t1 2000
xic t1.dn ote at_speed
xic motor ons s1 ote started
xic overtemp otl fault
xic reset otu fault
xic fault move 0 speed_sp
```

| Result | What it shows |
|---|---|
| 1 | The original runs the motor. `run_lamp` is 1 |
| 2 | The forecast names each change: 4 tags added, `run_lamp` held at 1, `s1` blocked (decisions 20, 21 and 27) |
| 3 | The report of the test is the forecast. `started` stays 0, because the switch blocks the one-shot. `at_speed` comes on after 2000 ms (decisions 21 and 27) |
| 8 | The forecast reports a shorter interval. The task is due at 30 ms in place of 50 ms (decision 40) |
| 9 | After a cancel from accept, the generation refuses a step on the edit (decisions 60 and 64) |

```elixir
alias Logex.Configuration.Edit, as: PlantEdit
alias Logex.Edit
alias Logex.Runtime

{:ok, motor} = Logex.compile_file("motor.ld")
# An edit keeps the name of the program. compile_file/1 names this program `motor_v2`.
{:ok, v2} = Logex.compile(File.read!("motor_v2.ld"), name: "motor")

# Prints each entry of a report on a line of its own.
show = fn report -> Enum.each(report, &IO.puts("     #{inspect(&1)}")) end

# Gives the inputs to the program, runs 1 scan and prints the outputs.
scan = fn state, program, elapsed, inputs ->
  state = Runtime.put_inputs(program, state, inputs)
  {outputs, state} = Runtime.scan(program, state, elapsed)
  IO.puts("     scan at #{state.now} ms: #{inspect(outputs)}")
  state
end

IO.puts("1. The original runs:")

state =
  Runtime.instance(motor)
  |> scan.(motor, 10, %{"start" => 1})
  |> scan.(motor, 10, %{"start" => 0})

IO.puts("2. accept/3 gives the forecast:")
{:ok, edit, forecast} = Edit.accept(motor, v2, state)
show.(forecast)

IO.puts("3. test/2 gives the same report. The candidate runs:")
{edit, state, report} = Edit.test(edit, state)
IO.puts("     the report is the forecast: #{report == forecast}")
state = state |> scan.(v2, 10, %{}) |> scan.(v2, 2000, %{})

IO.puts("4. untest/2. The original runs again:")
{edit, state, report} = Edit.untest(edit, state)
show.(report)
state = scan.(state, motor, 10, %{})

IO.puts("5. cancel/2 after the untest:")
{_motor, _state, report} = Edit.cancel(edit, state)
show.(report)

IO.puts("6. A change of type is refused:")
text = String.replace(File.read!("motor.ld"), "speed_sp dint", "speed_sp int")
{:ok, retyped} = Logex.compile(text, name: "motor")
{:error, [diagnostic]} = Edit.accept(motor, retyped, Runtime.instance(motor))
IO.puts("     " <> Logex.Diagnostic.format(diagnostic))

plant = """
task fast interval 10 priority 1
task slow interval 50 priority 2
var_global start_1 bool at panel.i.0
var_global stop_1  bool at panel.i.1
var_global start_2 bool at panel.i.2
var_global stop_2  bool at panel.i.3
var_global k1      bool at panel.q.0
var_global k2      bool at panel.q.1
program m1 motor with fast
  m1.start    start_1
  m1.stop     stop_1
  m1.overtemp 0
  m1.reset    0
  m1.motor    k1
program m2 motor with slow
  m2.start    start_2
  m2.stop     stop_2
  m2.overtemp 0
  m2.reset    0
  m2.motor    k2
"""

# Compiles the text of a configuration that runs motor.ld.
configuration = fn text ->
  {:ok, configuration} = Logex.Configuration.compile("plant", text, %{"motor" => motor})
  configuration
end

{runtime, _outputs, _events} = Runtime.start(configuration.(plant)) |> Runtime.cycle(0, %{})
{runtime, _outputs, _events} = Runtime.cycle(runtime, 10, %{})

IO.puts("7. A plant: an instance cannot move to a different task:")
moved = String.replace(plant, "m2 motor with slow", "m2 motor with fast")
{:error, [diagnostic]} = PlantEdit.accept(runtime, configuration.(moved))
IO.puts("     " <> Logex.Diagnostic.format(diagnostic))

IO.puts("8. An interval can change. The forecast:")
faster = String.replace(plant, "slow interval 50", "slow interval 20")
{:ok, edit, forecast} = PlantEdit.accept(runtime, configuration.(faster))
show.(forecast)

IO.puts("9. A step on an edit that has ended is refused:")
{_plant, runtime, []} = PlantEdit.cancel(edit, runtime)

try do
  PlantEdit.test(edit, runtime)
rescue
  error in ArgumentError -> IO.puts("     " <> error.message)
end
```

```console
$ mix run 0012-staged-online-edit.exs
1. The original runs:
     scan at 10 ms: %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
     scan at 20 ms: %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
2. accept/3 gives the forecast:
     {:added, "at_speed", 0}
     {:added, "s1", 0}
     {:added, "started", 0}
     {:added, "t1", %{"acc" => 0, "dn" => 0, "en" => 0, "last" => 0, "pre" => 2000, "tt" => 0}}
     {:held, "run_lamp", 1}
     {:ons_blocked, "s1", 0}
3. test/2 gives the same report. The candidate runs:
     the report is the forecast: true
     scan at 30 ms: %{"at_speed" => 0, "motor" => 1, "speed_sp" => 1200, "started" => 0}
     scan at 2030 ms: %{"at_speed" => 1, "motor" => 1, "speed_sp" => 1200, "started" => 0}
4. untest/2. The original runs again:
     {:held, "at_speed", 1}
     {:held, "started", 0}
     scan at 2040 ms: %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
5. cancel/2 after the untest:
     {:held, "at_speed", 1}
     {:held, "started", 0}
     {:pruned, "at_speed", 1}
     {:pruned, "s1", 1}
     {:pruned, "started", 0}
     {:pruned, "t1", %{"acc" => 2000, "dn" => 1, "en" => 1, "last" => 2030, "pre" => 2000, "tt" => 0}}
6. A change of type is refused:
     line 7: `speed_sp` is a dint in the running program and an int in the candidate: a tag's type changes only with a restart
7. A plant: an instance cannot move to a different task:
     line 15: `m2` runs with `slow` in the running configuration and with `fast` in the candidate: an instance moves to another task only with a restart
8. An interval can change. The forecast:
     {:interval, "slow", {50, 20}}
     {:next_due, "slow", {50, 30}}
9. A step on an edit that has ended is refused:
     this edit expects the resource at generation 0, but it is at generation 1: the edit has ended, or another edit has stepped since
```

In result 5, `s1` is 1. The blocked `ons` passed no power, but it wrote its bit at each
scan.


### The cost of an accept

An accept reads each write through a
[subscript](../../guides/reference/glossary.md#subscript) in a tag as a write of each
element (decision 513). An accept of a program with `var lane_t ton[4096]` and 40 rungs
such as `xic a1 move x lane_t[i].pre` takes about 0.5 s to 0.65 s.

## See also

- [Decision records](../adr/README.md): the list of the records.
- [The checks of a change](testing-checks.md): how the suite runs the examples of a page.
