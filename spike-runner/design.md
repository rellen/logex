# The wall-clock runner: design pass

**Status: proposed, nothing landed.** Written on 2026-10-17 against `d3931bd`, on Elixir
1.20.4 / OTP 28, on a 4-core Linux container. It answers `docs/organisation.md`'s
"Wall-clock runner, `Logex.IO` adapters, watchdog: target, after Milestone 2" (its §5), the
adapter sketch in §4.5, "the watchdog belongs to the wall-clock runner" in §4.6, the two
"revisit with the runner" notes of §4.10, and decision 14, "decide with the runner". A
throwaway spike built every piece below. It is on the branch `backup/runner-design`
(`spike-runner/`), never to land; its figures are receipts and pin nothing.

Eight questions are left to the maintainer (§6), each asked twice: technically, for the
record, and in plain words. Taken, they would become decisions 108 to 115. Everything
else here is a routine choice, given with its reason and the alternative it passes over.

**Contents.**
1. Where it lives and what it is
2. The `Logex.IO` adapter behaviour
3. Timing
4. The watchdog
5. Process and failure model
6. Open questions, twice
7. The milestone's shape
8. Risks, and what was spiked

**Summary.** `Logex.Runner` is one GenServer per resource, which the host puts under its
own supervisor; logex still starts no application. It owns the `%Logex.Runtime{}`, reads
`System.monotonic_time/1`, and is the only code in logex that does. It wakes on absolute
timers at the earlier of the next periodic due time (`next_due_in/1`) and the next tick
of its own pace (`period:`, 10 ms unless set). Each wake it reads every device, calls
`cycle/3` with the whole milliseconds that really passed, checks the watchdog, writes
every device, and publishes events. Each bound device runs in a process of its own,
linked to the runner, which holds the adapter's state.

That split buys three properties a single process cannot give:
- an adapter that hangs costs one call timeout, never the scheduler;
- each output device zeroes itself if no write reaches it within the watchdog's time, so
  a wedged runner still leaves its outputs at 0;
- a runner that dies, however it dies, takes its devices' outputs to 0 on the way.

A watchdog trip, a device fault or a stop zeroes every output once, through the devices
that still answer, stops scheduling, reports, and waits for an explicit `restart/2`.
That confirms decision 14. Tests drive the runner on a manual clock with a simulated
device, deterministically. The pure core does not change; the runner reuses its rules
(`Logex.Declarations.fits?/2`, `Logex.Configuration.location/1`) and its contract.

---

## 1. Where it lives and what it is

### What it is

| Piece | Kind | What it does |
|---|---|---|
| `Logex.Runner` | GenServer, one per resource | Owns the resource, the clock reading, the schedule, the devices, the watchdog, the subscribers and the current edit |
| `Logex.Runner.Device` | GenServer, one per bound device, linked to the runner, trapping exits; internal | Holds one adapter's state; reads and writes it for the runner; zeroes its outputs once and latches on a trip, on its own heartbeat and when the runner dies |
| `Logex.IO` | behaviour | The adapter contract (§2) |
| `Logex.IO.Sim` | adapter, with a small process of its own | An in-memory device for tests and demos (§2) |
| `Logex.Runner.Clock` | behaviour | `now_ms/1`, `wake_at/4` and `cancel/2`, so that a test can move time |
| `Logex.Runner.Clock.Monotonic` | the default clock | `System.monotonic_time(:millisecond)` and `Process.send_after(pid, msg, at, abs: true)` |
| `Logex.Runner.Clock.Manual` | a clock a test moves | `advance/2` delivers each timer due on the way in time order, and waits until each process has handled what it was sent |

**It lives in logex.** It uses only OTP and Elixir's standard library, so the rule of no
external dependencies holds. Adapters for real hardware, such as Modbus TCP or a GPIO
board, need libraries, so they live outside logex: in the host's application, or in
packages of their own that implement `Logex.IO`. logex ships only `Logex.IO.Sim`.

**It starts no application.** `mix.exs` has `application: []`, so nothing is started on
logex's behalf (`PLAN.md` B6), and the runner keeps it that way. The host starts it under
its own supervisor, as it starts any library's server:

```elixir
children = [
  {Logex.Runner,
   name: Plant.Runner,
   configuration: config,                       # %Logex.Configuration{}, from compile_file/1
   io: %{"panel" => MyApp.PanelIO, "drive" => {MyApp.ModbusIO, host: "10.0.0.5"}},
   period: 10,                                  # ms, the longest wait between two cycles
   watchdog: 100}                               # ms, or :off (Question 2)
]
Supervisor.start_link(children, strategy: :one_for_one)
```

Its `child_spec/1` is `restart: :temporary` (Question 6): a runner that crashes is not
started again by its supervisor, because a fault stops the plant until a person restarts
it.

**The pure core does not change.** The runner calls only `Logex.Runtime`'s public API
(`start/1`, `cycle/3`, `next_due_in/1`, `overlaps/1`, `get/2`, `restart/2`) and
`Logex.Configuration.Edit`'s steps. It reads two existing public rules:
- `Logex.Configuration.location/1`, to route each point to its device;
- `Logex.Declarations.fits?/2`, to check each value a device gives.

The resource stays opaque. The runner keeps its own count of the milliseconds it has
passed to `cycle/3`, which equals the resource's clock, since nothing else cycles it.

**No word joins either language.** The runner reserves nothing in a `.ld` file or a
`.logex` file, so there is no `docs/naming.md` stanza to write first. `period:` and
`watchdog:` are Elixir options, not configuration words. A watchdog per task would be a
`.logex` word, and so owe a survey first (Question 3).

### Its public API

Every call goes through the runner's mailbox, so each runs between two cycles, never
inside one. A call's reply waits at most one cycle: measured at p50 0.2 ms for §4.4's
plant, and 27 ms for a plant of 1,000 motors (§3).

| Function | Returns | Notes |
|---|---|---|
| `start_link(opts)`, `child_spec(opts)` | `{:ok, pid}` or `{:error, {:io_init, device, reason}}` | Checks the options in the caller before anything starts (below). Runs `Logex.Runtime.start/1` in the caller too, so a configuration `check/1` refuses raises there. Opens every device, in device-name order, then runs the first cycle at once (decision 50) |
| `stop(runner, reason \\ :normal)` | `:ok` | Zeroes every output once and closes every device before it returns (Question 7) |
| `status(runner)` | a map | `:running` or `:tripped`; the clock, `now`; the cycles run; the trip's reason; each task's overlap count; the forced inputs; the edit's stage; how late the latest wake was, the longest cycle and the longest gap between two writes, in ms |
| `get(runner, path)`, `get!(runner, path)` | as `Logex.Runtime.get/2` and `get!/2` | Reads the resource. After a trip it reads the values of the last cycle computed, which may differ from the zeroed devices (§4) |
| `subscribe(runner, kinds)`, `unsubscribe(runner)` | `:ok` | The caller is sent `{Logex.Runner, runner, event}` for each event of a kind it named. Monitored, so a subscriber that dies is dropped |
| `force(runner, point, value)`, `unforce(runner, point)` | `:ok` | Input points only, for now (Question 8) |
| `restart(runner, :cold \| :warm)` | `:ok` or `{:error, {:io_init, device, reason}}` | From `:tripped` or `:running`. Opens again each device that went down, releases every latch, calls `Logex.Runtime.restart/2`, and runs the first cycle at once, inside the call |
| `accept(runner, candidate)` | `{:ok, forecast}` or `{:error, diagnostics}` | `Logex.Configuration.Edit.accept/2` over the resource. The runner holds the edit, one at a time; a second accept supersedes the first, as decision 66 allows |
| `test/1`, `untest/1`, `assemble/1`, `cancel/1` | `{:ok, report}` | The edit's steps, each between two cycles. Assemble and cancel end the edit, and the runner then runs the configuration they return |

**Events,** an open set, as the resource's are:

| Kind | Event | Subscribed by default |
|---|---|---|
| `:overlap` | `{:overlap, task, missed}`, the resource's own: missed periods | yes |
| `:fault` | `{:fault, task, instance, %Logex.Fault{}}`, the resource's own: minor faults | yes |
| `:trip` | `{:trip, reason}` (§4) | yes |
| `:restart` | `{:restart, :cold \| :warm}` | yes |
| `:edit` | `{:edit, step, report}` | yes |
| `:ran` | `{:ran, task \| :none, instance, now}`, the resource's own | no: 100 or more a second for each instance |
| `:cycle` | `{:cycle, now, outputs}`, for a live display | no |

A trip's `reason` is one of:
- `{:watchdog, {:cycle, gap_ms, limit_ms}}`;
- `{:watchdog, {:device, device, limit_ms}}`;
- `{:io, device, cause}`, where `cause` is `:timeout`, `{:error, term}`,
  `{:raised, message}`, `{:bad_value, address, value}`, `{:unknown_address, address}` or
  `{:down, exit_reason}`;
- `{:internal, message}`, for an exception out of the core: a logex bug, by the host
  contract.

### Host mistakes

A host mistake raises `ArgumentError` in the host's own process, with a message a test
pins, and never crashes the runner.

**At start,** `start_link/1` checks its options before it spawns anything. Each of these
is a host mistake, and the proposed words follow the codebase's:
- a missing or unknown option;
- a configuration `Logex.Runtime.start/1` refuses, with its own message;
- a device the configuration's points name that no adapter is bound to (§4.5):
  ``no adapter is bound to the device `drive`, which `sp_1` (drive.q.0) and `sp_2` (drive.q.1) are at``;
- a bound device with no point at it (§4.5), with a did-you-mean:
  ``the device `panle` is bound, but no point is at it — did you mean `panel`?``;
- an adapter module that does not implement `Logex.IO`;
- `period` not a positive integer of milliseconds;
- `watchdog` neither `:off` nor a whole number of milliseconds longer than the period:
  `watchdog must be :off or more milliseconds than the period (10), got: 5`;
- a clock that does not implement `Logex.Runner.Clock`.

A device that cannot be reached is not a host mistake. It is the plant's state, so it
comes back as `{:error, {:io_init, device, reason}}`, as any GenServer start fails.

**In a call,** a mistake is relayed: the server rescues the `ArgumentError`, replies
`{:raise, exception}`, and the client function raises it. The spike shows five, each
raised in the caller with the runner still alive:
- `get!/2` of a path that names nothing, with the core's own message;
- forcing an output point;
- forcing a bool to 2;
- `test/1` with no edit accepted;
- `restart/2` with `:hot`, with the core's message.

### How a host test drives it

The manual clock replaces the monotonic one, and the simulated device replaces the
plant. From the spike's scenario A, on §4.4's plant, cut from `docs/organisation.md` as
`config_edit_test.exs` cuts it:

```elixir
{:ok, clock} = Logex.Runner.Clock.Manual.start_link()
panel = Logex.IO.Sim.new()
drive = Logex.IO.Sim.new()

{:ok, runner} =
  Logex.Runner.start_link(
    configuration: plant,
    io: %{"panel" => {Logex.IO.Sim, sim: panel}, "drive" => {Logex.IO.Sim, sim: drive}},
    clock: {Logex.Runner.Clock.Manual, clock},
    period: 10,
    watchdog: 100
  )

Logex.IO.Sim.set(panel, [0], 1)                  # pb_start_1, at panel.i.0
Logex.Runner.Clock.Manual.advance(clock, 10)     # one cycle at t=10, run to its end
assert Logex.IO.Sim.outputs(panel)[[0]] == 1     # k1, at panel.q.0
```

The spike ran that scenario twice, from fresh processes, and every line it printed was
identical (`A twice identical: true`). Its first seven:

```
t=   0 started, first cycle at once   running k1=0 k2=0 lamp_1=0 lamp_2=0 sp_1=1200 sp_2=1200
t=  10 both starts pressed            running k1=1 k2=0 lamp_1=1 lamp_2=0 sp_1=1200 sp_2=1200
t=  50 held to 50 ms                  running k1=1 k2=1 lamp_1=1 lamp_2=1 sp_1=1200 sp_2=1200
t=  60 released                       running k1=1 k2=1 lamp_1=1 lamp_2=1 sp_1=1200 sp_2=1200
t=  70 estop pressed (event task)     running k1=0 k2=1 lamp_1=0 lamp_2=1 sp_1=0 sp_2=1200
t= 100 m2 sees estop at its scan      running k1=0 k2=0 lamp_1=0 lamp_2=0 sp_1=0 sp_2=0
snapshot k1_at_trip=1 k2_at_trip=1
```

**How the manual clock works.** `advance/2` runs in the test's process. It pops each
timer due on the way, sets the clock to its time, sends its message, and then calls
`:sys.get_state/1` on the receiver and on every other process that has set a timer. So
each cycle, and each heartbeat it re-arms, is done before the next timer is delivered.
Time that passes inside a cycle, as for a slow device, moves the clock without
delivering anything until the next `advance/2`. The spike's version relies on two
messages from two senders arriving in the order sent, which holds on one node and which
the landed clock should not rely on (§8).

**Where the timing arithmetic lives.** The arithmetic is three private functions, the
wake time, the elapsed time and the watchdog's verdict, tested through the manual clock,
so that a test reaches them only through the public API, as CLAUDE.md's evaluator is
reached. A pure `Logex.Runner.Pace` module, property-tested without processes, is the
alternative; it would be one more public surface for little gain, since the manual clock
is already deterministic.

---

## 2. The `Logex.IO` adapter behaviour

§4.5's sketch, revised so that every callback can fail without raising and a device can
be closed:

```elixir
defmodule Logex.IO do
  @type address :: [non_neg_integer]          # panel.i.1.3 -> [1, 3]; Logex.Configuration.location/1's third part
  @type point :: %{name: String.t(), direction: :input | :output, address: address, type: :bool | :dint}

  @callback init(device :: String.t(), points :: [point], opts :: keyword) :: {:ok, state} | {:error, term}
  @callback read(state) :: {:ok, %{address => integer}, state} | {:error, term, state}
  @callback write(%{address => integer}, state) :: {:ok, state} | {:error, term, state}
  @callback close(state) :: :ok
  @optional_callbacks close: 1
end
```

**What changes from §4.5's sketch, and why:**
- `read/1` and `write/2` return `{:error, reason, state}` rather than raising. A device
  that does not answer is the plant's state, not a bug, and the runner must tell it from
  a raise, which is one.
- `write/2` returns its state, so a connection can be reconnected inside it.
- `close/1` is optional, called once after the last write of zeros.
- A point carries its name and type, so an adapter can log or convert by them.

### Points and devices

- **How a point is routed.** A point is a global with `at`. Its device is the first part
  of its location, and its direction is `i` or `q`. Its address is the integer fields,
  read by `Logex.Configuration.location/1`, "what a runner routes a point by". The
  runner groups them once, at start.
- **Located I/O cannot change while running.** OE-2's accept refuses a location added,
  removed or moved, so the binding is fixed for the runner's life, across every edit.
  §4.9: "logex binds devices only at start".
- **Read.** `read/1` is called each cycle on each device that has input points. It
  returns values by address, for some or all of them. The runner checks each with
  `Logex.Declarations.fits?/2`, the core's own rule, and an address the device does not
  hold as an input point, so that a bad value names its device and address:
  `{:io, "panel", {:bad_value, [0], 7}}` in the spike. The values that pass are merged by
  `cycle/3` into the input image, which keeps them, so an adapter may return only what
  changed (§4.6, step 2).
- **Write.** `write/2` is called each cycle on each device that has output points, with
  every one of them, by address. Outputs are a snapshot (`Logex.Runtime`'s moduledoc,
  "What it may rely on", item 4), so an adapter may skip those that did not change.
- **Order.** Devices are read in device-name order, one after another, and written the
  same way, so a run is deterministic. Reading them in parallel would cut a cycle's time
  where several devices sit on a network. It is left for later, until a real network
  adapter has been measured (§8): §3 measured only the simulated device.
- **Values the runner keeps.** The runner keeps each input point's last value as read,
  so that `unforce/2` can put back what the device said even where the device reports
  only changes (Question 8).

### When an adapter fails

Each callback runs inside the device's process, guarded: a raise, a throw or an exit
becomes `{:error, ...}`. The runner calls each device with a timeout equal to the
watchdog's time, or 5 s with the watchdog off. Each of these is one thing, an I/O fault:
- an `{:error, ...}` return;
- a raise;
- a value that does not fit its point;
- an unknown address;
- no answer in time;
- the device's process going down.

An I/O fault trips the runner, by the same path as the watchdog (Question 5). A device
that did not answer in time is stuck inside its adapter, so the runner kills its process
and opens a fresh one at the next `restart/2`. Its outputs cannot be zeroed from
software: they are whatever the device does when it loses its master (§5).

The spike gives each of these, on the manual clock but for the hang:

```
t=  10 drive read fails               tripped ... sp_1=0 sp_2=0  [trip: {:io, "drive", :econnreset}]
t=  20 panel adapter raises           tripped ...                [trip: {:io, "panel", {:raised, "sim panel: read raised"}}]
t=  30 panel gives 7 for a bool       tripped ...                [trip: {:io, "panel", {:bad_value, [0], 7}}]
t=  10 panel read hangs               tripped k1=1 ... sp_1=0    [trip: {:io, "panel", {:timeout, 100}}]
tripped after 102 ms of real time
```

In the last case the hung panel kept `k1=1`, the drive was zeroed, and `restart/2`
opened the panel again.

### The simulated device

`Logex.IO.Sim` is an adapter whose device is a small process the test owns:
- `new/0`;
- `set(sim, address, value)`, for an input;
- `outputs(sim)`, the last value written to each output;
- `writes(sim)`, every write in order, so that "zeroed once" can be asserted;
- `closed?(sim)`;
- `fail(sim, how)`, which acts out one failure on the next read: `{:error, reason}`,
  `:raise`, `:hang`, a bad value, or `{:delay, ms}` on the manual clock.

It is bound as `{Logex.IO.Sim, sim: sim}`. README's example would run on it, and it is
the fixture for every test in §7.

---

## 3. Timing

### When it cycles

- **At once,** after `start_link/1` and after `restart/2`, whatever `next_due_in/1`
  says (decision 50). An event task whose trigger is already 1 runs in that cycle
  (decision 11).
- **Then at the earlier of two times:**
  - the next periodic due time: `now + next_due_in(rt)`, nothing when that is
    `:infinity`;
  - the next tick of the runner's own pace: ticks every `period` ms from the clock's
    value at the last start or restart.

  Either way the wait is never longer than `period`.
- **What runs in each cycle.** The task-less instances run in every cycle, each event
  task's trigger is sampled in every cycle, and a periodic task runs in the cycle at or
  after its due time. So `period` is how often the "continuous" programs run, and how
  long an e-stop's edge can wait to be seen, where no periodic task cycles sooner.
- **A configuration of only task-less instances,** or of only event tasks, has no
  periodic due time, so it cycles on the pace alone: every `period` ms, 10 by default.
  That is its base period. MatIEC would refuse it (below), and logex runs it.
- **The default `period` is 10 ms** (Question 1). Where it divides every interval, as
  on §4.4's plant, every cycle lands on its grid. Where it does not, the cycles are the
  union of the two grids: for a 15 ms task, at 0, 10, 15, 20, 30, 40, 45 and so on.
- **Precedents.** MatIEC generates one tick for a configuration, the greatest common
  divisor of its task intervals (`calculate_common_ticktime_c`,
  `stage4/generate_c/generate_c.cc`, read at `3a41303`), and refuses a configuration with
  no periodic task: *"You must define at least
  one periodic task (to set cycle period)!"*. OpenPLC v3's main loop sleeps to that
  tick, `sleep_until(&timer_start, common_ticktime__)`, an absolute
  `clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, …)` (`webserver/core/main.cpp`,
  `utils.cpp`, at `b5d4135`). The greatest common divisor degenerates, to 1 ms for 7 and
  10 ms tasks, and the union of due times and a fixed pace does not.

### How much time passes to `cycle/3`

The runner keeps two numbers:
- `anchor`, the monotonic millisecond its clock counts from;
- `logical`, the sum of every `elapsed_ms` it has passed, which is the resource's `now`.

At each wake it reads `wall = System.monotonic_time(:millisecond)`, before it reads any
device, and passes `elapsed = (wall - anchor) - logical`, never negative, since the
clock is monotonic. Because `anchor` is fixed, each cycle's rounding to whole
milliseconds is made against absolute time and never accumulates. The deadline it sleeps
to is absolute too, `anchor + next`, through `Process.send_after(self(), msg, at, abs:
true)`.

**Measured, 1,000 cycles at 10 ms, the real §4.4 plant cycled each wake**
(`spike-runner/timing.exs`):

| Timer | Idle machine | Beside a full test suite |
|---|---|---|
| absolute, the default | p50 0.19 ms late, p99 0.58 ms, max 3.4 ms; no early wake in 6,000, idle or loaded; 992 of 1,000 cycles given exactly 10 ms | p50 1.8 ms, p99 126 ms, max 196 ms |
| absolute, at process priority `:high` | p50 0.21 ms, p99 0.63 ms, max 7.3 ms | p50 0.48 ms, p99 167 ms, max 237 ms |
| relative, `send_after(10)` after each cycle | 11 ms a cycle: 1,067 ms of drift in 1,000 cycles, and 106 periods falsely reported missed | — |

So the runner uses absolute deadlines, never relative ones. A timer was never seen to
fire early. Process priority helps the median, not the tail: the competition is another
operating-system process, which the BEAM's own priorities do not reach.

**After a stop or a trip,** the runner sets `anchor = wall - logical`. The clock does not
count the time the runner was not running, and the first cycle after a restart gets 0 ms.
The alternative, counting the stopped time, would make the first cycle after a restart
report every period of the outage as missed, since `restart/2` makes each task due at
the kept clock. In the spike's scenario C the clock stood at 60 ms before a trip, 200 ms
passed, and the restarted resource went on from 60.

### Overrun, late cycles, and decisions 39 and 50 to 52 in real time

- **A late wake** gives a larger `elapsed`. The resource then runs each due task once,
  counts the periods it missed, and moves its due time past `now` on its phase (§4.6):
  late is reported, never replayed. Sleeping on `next_due_in/1` is what keeps it so.
  The timing spike first re-armed every 10 ms deadline whatever happened, and under load
  it replayed the backlog: 288 of its 1,000 cycles were given 0 ms, OpenPLC's catch-up.
  The runner's next deadline is always computed from the resource after the cycle, so
  there is no backlog to replay.
- **A cycle that takes longer than a period.** The next deadline is already past, so
  the timer fires at once, the next cycle reports the periods missed, and the runner runs
  back to back until it catches up or the watchdog trips. That is the honest reading of
  an overloaded controller.
- **Event tasks** (decisions 39, 51 and 52). A trigger is sampled once a cycle, after the
  devices are read. An edge is seen at the latest one period after it reaches the
  device, plus that wake's lateness. A pulse shorter than a cycle can be missed
  altogether, as §4.4 already says an e-stop must be held at least as long as the
  slowest interval that reads it. Late cycles are read by their sample, exactly as
  `cycle/3` reads them, since the runner only feeds it.
- **Decision 50** is why the runner has a pace of its own. `next_due_in/1` counts
  periodic due times only, so a plant of event tasks and task-less programs alone would
  otherwise never cycle after the first.

### Jitter, and what the BEAM can and cannot promise

**What the spike measured.** These are runner soaks: §4.4's plant through the whole
runner on the real clock, with simulated devices, a button toggled every 500 ms, and the
watchdog off so that every gap is counted rather than tripped on (`spike-runner/soak.exs`):

| Run | Cycles | Gaps between two output writes | Latest wake | Missed periods reported |
|---|---|---|---|---|
| idle, 20 s | 2,005 | 1,976 at 10 ms or less, 29 of 11–20 ms | 2 ms | 0 |
| beside one test suite, 40 s | 3,933 | 315 of 11–20 ms, 29 of 21–50, 4 of 51–100 | 83 ms | 83 |
| beside two test suites, load average 8.4 on 4 cores, 40 s | 1,462 | 195 of 11–20 ms, 78 of 21–50, 48 of 51–100, 70 of 101–250, 46 of 251–500, 3 over 500 | 692 ms | 3,620 |

**What a cycle costs.** The runner's own cost per cycle, from wake to the last write,
with two devices read, `cycle/3` and two devices written, was p50 0.21 to 0.24 ms,
p99 0.52 to 0.57 ms and p99.9 2.3 to 4.0 ms. That held in all three runs: the delays
under load are the BEAM not being given the CPU, not the runner's work. `cycle/3` alone
costs about 9 to 26 µs per instance of §4.3's motor (`spike-runner/size.exs`):

| Motor instances | `cycle/3`, p50 | Share of a 10 ms period |
|---|---|---|
| 1 | 16 µs | — |
| 10 | 91 µs | — |
| 100 | 2.0 ms | 20% |
| 1,000 | 27 ms | does not fit |

**What logex can promise**, to be said plainly in README:
- **Exact replay.** Given the same `elapsed_ms` and inputs for each cycle, the outputs
  and events are exactly the same (`Logex.Runtime`'s moduledoc, "What it may rely on",
  item 6). The runner adds nothing to the logic, so a recorded run replays.
- **No drift.** Each phase stays on its grid however long the runner runs, because every
  deadline is absolute.
- **Lateness is reported.** A periodic task that ran late by a whole interval or more is
  counted and reported as an overlap, and with the watchdog on, outputs left unrefreshed
  longer than its time trip the controller.
- **Outputs go to 0** when the runner trips, stops, dies or stops refreshing a device,
  as long as the device itself still answers (§5).

**What it cannot promise:**
- **No hard deadline and no bounded jitter.** On an idle machine it keeps 10 ms to
  within a millisecond nearly always, with a few-millisecond outlier now and then. On a
  busy machine it can be hundreds of milliseconds late.
- **No real-time scheduling.** The BEAM runs on a general-purpose operating system, its
  schedulers are shared with every other process in the VM, and its garbage collection
  is per process. The runner's own heap is small, but a cycle's p99.9 of 2 to 4 ms
  includes collections and preemption.
- **No edge shorter than a cycle,** as above.
- **Nothing once the VM stops,** whether from power loss, the operating system killing
  it, or a hang of the whole VM.

**What a host can do to help:**
- give the controller a machine, or cores, of its own;
- keep heavy work out of its VM;
- choose `period` and `watchdog` from a soak on the target machine, which a status
  map's longest-gap counter makes easy.

Two more knobs are left unmeasured: operating-system real-time priority, which OpenPLC v3
sets for its main thread (`SCHED_FIFO`, priority 30, in `main.cpp`), and the VM's
scheduler flags. Their effect on the BEAM is **unverified**.

### Two things §4.10 left to revisit with the runner

- **No `outputs` field on `%Logex.Program{}`.** `cycle/3` already returns the output
  points, and the runner's whole cycle measured 0.2 ms, so there is still nothing to
  gain.
- **No queue of tasks by due time.** `next_due_in/1` is linear in the tasks and is
  called once a cycle, and §4.4's plant has three tasks. A plant of hundreds of tasks
  might want one. None has been seen.

### Edits while running

Each step of an edit is a call to the runner, served between two cycles, as the host
contract requires. The runner keeps the resource each step returns, and its next cycle
runs it. The spike stepped one on §4.4's plant:
- the change: `slow` from 50 ms to 20 ms, and `m2.reset` wired to `pb_reset`;
- the forecast and the test's report: `[{:interval, "slow", {50, 20}}, {:next_due,
  "slow", {100, 80}}]`, decision 40's move;
- assemble's report: `[]`;
- no overlap, and the outputs unbroken throughout.

A step may be taken while tripped too: a program can be fixed and then restarted.

---

## 4. The watchdog

**The rule, as an operator would read it.** If the outputs have not been refreshed for
the watchdog's time, the controller stops:
1. every output goes to 0, once;
2. it reports why;
3. nothing runs again until a person restarts it.

### What trips it, and how it is measured

The one rule is checked in two places, so that it holds whatever has gone wrong:

1. **The runner, before each write.** Each cycle, after `cycle/3` and before writing any
   device, the runner measures `gap = now - last_written`, the time since the last
   cycle's writes ended. Over the watchdog's time, it trips without writing, so a late
   cycle's outputs never reach the plant. This catches a heavy program, a slow device and
   a late wake.

   The spike first checked after the write. Scenario C, a panel read that took 150 ms of
   the manual clock, then wrote the late cycle's outputs and zeroed them a moment later:
   two writes, `[%{[0] => 1, …}, %{[0] => 0, …}]`. Checked before, the panel saw one
   write, zeros: `[trip: {:watchdog, {:cycle, 160, 100}}]`.
2. **Each output device, by its own heartbeat.** Each write arms a timer for the
   watchdog's time. If it fires with no newer write, the device zeroes its outputs,
   latches, and tells the runner. This catches a runner that is wedged and can trip
   nothing itself: a bug in a loop, or a process starved by the VM.

   In the spike's scenario E the runner was suspended with `:sys.suspend/1` and the
   manual clock moved 150 ms. Both devices zeroed themselves while it stood
   (`panel %{[0] => 0, …} drive %{[0] => 0, [1] => 0}`). On resuming, the runner ran the
   cycle it owed, which reported 14 missed periods of `fast` and 2 of `slow`, and tripped
   before writing, `{:watchdog, {:cycle, 150, 100}}`. With the first draft's check after
   the write, the latched device refused the write instead, and the trip named it,
   `{:watchdog, {:device, "drive", 100}}`. The reason names whichever check sees it first;
   both are the watchdog. This is the BEAM's strength used on purpose: another process
   runs while one is stuck.

**Its time is per resource, not per task** (Question 3). It is the runner's
`watchdog:` option, in milliseconds, or `:off`, and must be longer than `period`. A
cycle runs every due task in one call, so the cycle is the only thing whose time can be
taken, and outputs are written once a cycle, so "outputs refreshed" is one fact for the
whole plant.

**Its default** is Question 2. The soaks above are the evidence: on an idle machine no
gap passed 20 ms; beside one heavy neighbour none passed 100 ms; beside two, three
passed 500 ms and the worst wake was 692 ms late.

### What a trip does (decision 14)

1. **It stops scheduling.** The wake timer is cancelled and stale wakes are ignored.
2. **It zeroes every output once.** Each device writes 0 to every output point and
   latches, so it writes nothing more until a restart. In the spike, 200 ms after a trip
   the panel had been written 0 times since its zeroing (`panel writes while tripped:
   0`). A dint output is 0 too: a drive's speed setpoint goes to 0.
3. **It reports,** `{:trip, reason}` to every subscriber of `:trip`, and `status/1`
   gives the reason until a restart.
4. **It keeps the resource as the last cycle computed it,** for diagnosis. `get/2`
   still reads it. Where that cycle tripped before its write, the resource holds outputs
   the plant never received. The spike's scenario C read `k1` as 1 from the resource
   while the panel held 0. `status/1` says so, and README must.
5. **It waits for `restart(runner, :cold | :warm)`.** Restart opens again every device
   that went down, releases every latch, calls `Logex.Runtime.restart/2`, which keeps
   the input image and puts every other global, the output points among them, back to
   its initial value, and runs the first cycle at once. `:warm` is `:cold` until
   `retain` lands, as everywhere else.

**An adapter failure trips it too** (Question 5), through the same five steps, with the
reason `{:io, device, cause}`. So does an exception out of the core, `{:internal, …}`,
which the host contract says cannot happen. Tripping rather than crashing keeps the
runner alive for diagnosis, and zeroes the outputs either way.

**A stop does the zeroing too,** synchronously, before `stop/2` returns (Question 7).
The spike first left it to the devices' exit handling, and its scenario A showed the
race: `stop` returned while the panel still held `k1=1`.

### Decision 14, confirmed, with five refinements

**Confirmed: zero, not hold.**
- **The plant is wired so that off is safe.** The usual practice, de-energise to trip,
  makes 0 the safe state of a contactor, a valve or a drive's enable, so zeroing leaves
  a plant wired that way safe. Holding leaves motors running with no logic watching
  them, which is the very condition the watchdog exists to end.
- **There is precedent.** OpenPLC v3 zeroes every output when its runtime shuts down,
  `disableOutputs(); updateBuffersOut();` (`main.cpp`, `utils.cpp` at `b5d4135`).
- **IEC allows it.** §1.5.1 d) 4) asks the system to *"initiate appropriate system- or
  user-defined error handling procedures"*, and stopping with outputs off is one.
- **Unverified:** what the conventional family's controller does to outputs on a
  watchdog fault, still from memory (§8 of `docs/organisation.md`).

**Refined:**
1. **"Once" means through each device's write,** and only a device that answers can be
   zeroed. A hung device is left to its own behaviour on losing its master.
2. **The resource is not zeroed,** only the devices. Its values stay for diagnosis, and
   `restart/2` puts the output points back to 0 anyway.
3. **The same path serves** a device fault, a stop and the runner's own death (§5), so
   the plant sees one rule.
4. **A restart is cold or warm,** never a resume of the tripped state. The resource's
   clock does not count the stopped time.
5. **No per-point fault value.** I/O modules commonly let each output choose to hold, go
   off or go on when they fault. logex zeroes them all, and a per-point value is a later
   item if a plant needs one: a cooling fan that should keep running, for one.

---

## 5. Process and failure model

```
host's supervisor
└── Logex.Runner            (restart: :temporary; traps exits)
    ├── Device "drive"      (linked; traps exits; holds MyApp.ModbusIO's state)
    └── Device "panel"      (linked; traps exits; holds MyApp.PanelIO's state)
```

The two devices are linked to the runner, not supervised.

### What can fail, and what happens

| What fails | How it is seen | What happens | In the spike |
|---|---|---|---|
| The pure core raises | the host contract says it cannot: the runner checks every value it passes first | caught; trip `{:internal, message}` | — |
| An adapter callback returns an error, raises, throws or exits | guarded in the device's process | an I/O fault: trip, the other devices zeroed | D |
| An adapter hangs | the runner's call times out (the watchdog's time) | trip; the device's process killed, its outputs left to the device; a fresh one opened at `restart/2` | G, 102 ms |
| A device's process dies | the runner traps the `EXIT` | trip; opened again at `restart/2` | — |
| The runner is wedged | each output device's heartbeat | the devices zero and latch; the runner trips when it next runs, by its own gap check or by the latched device's refusal | E |
| The runner crashes or is killed | each device traps its parent's `EXIT`, and OTP calls its `terminate/2` | each device zeroes its outputs and closes | F, after `Process.exit(runner, :kill)`: both devices zeroed, `closed=true` |
| The runner is stopped | `terminate/2` | zero and close each device, then return | every scenario but F |
| A subscriber is slow | — | nothing: events are sent asynchronously, so a subscriber's mailbox grows, never the runner's wait. `:ran` and `:cycle` are opt-in for that reason | — |
| The VM, the operating system or the power dies | — | nothing in software can act. Outputs are what the I/O hardware does on losing its master. Use I/O with a configurable communication-loss state, and set it to off | — |

**Logging.** OTP itself writes a crash report when a device stops with an abnormal
reason, as when its parent is killed: the spike's scenario F printed two. The runner
logs nothing of its own, since everything it knows goes to subscribers, keeping B6's
"nothing uses Logger". A device can be started so that a dying runner reaches its
`handle_info/2` and it stops with `:shutdown`, which OTP does not report; that is a
landing detail.

**The supervisor.** `restart: :temporary` (Question 6): a crashed runner stays down, as
a tripped one stays stopped, and the host restarts it on purpose. A host that wants
automatic restarts can say so in its own child spec, knowing that a cold restart runs
the program from its initial values.
- A motor sealed in by a start button stays off until someone presses start.
- An output driven straight from a maintained switch comes straight back on.

### What logex is not

To be stated in README, in `Logex.Runner`'s moduledoc and in `docs/organisation.md`:
- **logex is not a safety controller.** It must not implement a safety function: an
  emergency stop, a guard interlock, a light curtain, two-hand control, burner or
  pressure protection. Those belong in hardwired circuits or in a safety-rated
  controller designed and validated to the functional-safety standards that apply,
  against which logex makes no claim.
- **The e-stop in §4.4's plant is a signal the program reads.** It records which
  contactors were closed at the trip. It is not the e-stop that cuts the contactors'
  power, which must be wired so that it works with logex stopped, crashed or never
  started.
- **logex is not hard real-time.** §3 measured what it does on one machine. A plant must
  tolerate a late cycle, and the watchdog is a backstop, not a guarantee.
- **logex is not certified** for any industrial use.

**Is a runner that dies a safety hazard?** Not more than any software controller's
failure, provided the plant follows the rules above. The design makes the common deaths
go to outputs off: a crash, a kill, a stop, a wedge, a device fault. It is honest about
the rest: a hung device, and a dead VM.

---

## 6. Open questions, twice

### For the record

**Q1. How often the runner cycles when nothing periodic is due (§3).**
- (a) The earlier of the next periodic due time and a fixed pace, `period:`, 10 ms unless
  set. The task-less instances and the triggers then run every `period` at the least.
- (b) Only at periodic due times. A configuration with no periodic task must be given
  `period:`, and refusing it otherwise follows MatIEC.
- (c) Back to back, yielding between cycles, as IEC's rule 4 and the conventional
  continuous task. It keeps a scheduler busy for ever.

*Recommend (a).* Response is bounded by one number, whatever tasks a plant declares, at
about 2% of one core at 10 ms (0.2 ms a cycle). (b) ties the task-less programs to an
unrelated task, and lets a plant with only a slow task miss short inputs. (c) spends a
core to gain milliseconds the BEAM's jitter takes back.

**Q2. The watchdog's default time (§4).**
- (a) None: `watchdog:` is required, a number or `:off`.
- (b) 500 ms unless set.
- (c) 100 ms unless set.
- (d) `:off` unless set.

*Recommend (a).* No number is right on every machine. In §3's soaks no gap passed 20 ms
idle and none passed 100 ms beside one heavy job, while beside two the worst wake was
692 ms late. Requiring it now and giving it a default later
breaks no host, as decision 7 reasoned for unconnected var_inputs, while a default
given now and changed later changes a running plant's behaviour without a word.

**Q3. One watchdog time per resource, or one per task.**
- (a) One per resource, a runner option.
- (b) One per task, a word in the `.logex` task line (`task fast interval 10 priority 1
  watchdog 50`), checked against the cycles that run that task. This owes a
  `docs/naming.md` stanza first and a configuration's diagnostics.
- (c) Both.

*Recommend (a) now.* A cycle runs every due task in one call and writes every output
once, so one measure of "outputs refreshed" is what exists. (b) can be added later
without breaking a plant, and would want a survey first: IEC has no watchdog, and the
conventional family's per-task one is from memory.

**Q4. What a watchdog trip does to outputs: decision 14, to confirm (§4).**
- (a) Zero once, stop scheduling, report, explicit restart, with §4's five refinements.
- (b) Hold the last outputs, stop scheduling, report, explicit restart.

*Recommend (a).* Off is the safe state of a plant wired to de-energise to trip, and
holding leaves motors running with no logic watching them.

**Q5. A device fault (an error, a raise, a bad value, no answer, its process down).**
- (a) Trip, as the watchdog does.
- (b) Keep running on the device's last good inputs for a grace time, then trip.
- (c) Keep running on the last good inputs and report it: a minor fault.

*Recommend (a).* The runner cannot know whether a stop button or an e-stop changed on the
silent device, so it must not go on driving outputs from what it last saw. One path for
every major fault keeps the operator's rule simple. (b) is a later option, if a plant
with a flaky network needs it.

**Q6. The runner's restart policy under the host's supervisor (§5).**
- (a) `restart: :temporary`: a crash leaves it stopped, its outputs zeroed by its devices.
- (b) `:permanent`: the supervisor starts it again at once, cold.
- (c) A crash brings it back stopped: outputs off, devices open, waiting for `restart/2`.

*Recommend (a).* It is the trip's rule: nothing starts again that no person asked to
start. (c) is friendlier for a status screen, but needs the knowledge that it crashed to
survive the crash, more machinery than the first runner needs.

**Q7. What a normal stop does to outputs.**
- (a) Zero once, then close every device, before `stop/2` returns.
- (b) Leave them as they are, and close every device.

*Recommend (a).* It is OpenPLC v3's rule, and a controller that has stopped should not
leave a conveyor running behind it.

**Q8. Forcing.**
- (a) Force input points now, in the runner: a forced value is merged over the device's
  every cycle, kept across a restart, listed by `status/1`, and taken off by
  `unforce/2`, which puts back the device's last value. Output forcing waits for
  `docs/organisation.md` §5's forcing in `cycle/3`, which the runner's `force/3` will
  then call.
- (b) Wait for that forcing in the core, inputs and outputs together.
- (c) No forcing: tests and commissioning use `Logex.IO.Sim`.

*Recommend (a).* Forcing an input is exactly the input map the runner already supplies,
which `docs/organisation.md` §5's design also applies "after the input latch", so it
costs nothing to add now
and does not have to be undone later.

**Routine choices, taken here, each with what it passes over:**
- **Absolute timers on the monotonic millisecond,** over relative ones, which drifted 7%.
- **The runner keeps the clock,** re-anchored at a restart so that stopped time is not
  counted, over counting it, which reports every period of an outage as missed.
- **The watchdog is checked before the write,** over after it, which writes a late
  cycle's outputs a moment before zeroing them.
- **A hung device is killed and opened again,** with its outputs left to the device,
  over waiting on it, which would wedge the runner.
- **Host mistakes are relayed** as `{:raise, e}` and raised in the caller, over raising
  in the server, which would crash the plant for a typo.
- **The runner holds the edit,** one at a time, over the host holding `%Edit{}` and
  passing it in, which allows a step against a stale edit that only the generation
  catches.
- **Devices are read and written in name order,** one after another, over in parallel,
  which is later and measurable.
- **An exception out of the core trips,** over crashing, which zeroes the outputs too but
  loses the state.
- **No logging,** over Logger, which B6 keeps out.
- **`:ran` and `:cycle` are opt-in,** over sending every event, which grows a slow
  subscriber's mailbox.
- **`get/2` reads the resource after a trip,** over reading the zeroed devices.
- **No `outputs` field and no task queue,** both revisited and still not needed.

### In plain words, for the maintainer

These are the questions exactly as they should be put.

> **The plant in every question.** A conveyor motor with a start button, a stop button
> and an emergency stop. A cooling fan that keeps running for a minute after the
> conveyor stops. A photo-eye that counts boxes, and a "case full" lamp that lights at
> 12 boxes. A speed setting sent to the conveyor's drive over the network. The
> conveyor's logic is checked every 10 milliseconds and the fan's twice a second. The
> box counting and the lamp have no timing of their own: they are checked whenever the
> controller does a round.
>
> **The new piece.** Until now, logex has only been told what time it is: a program
> calls it, round by round. The new piece runs the controller on the computer's real
> clock. It reads the buttons and sensors, does a round of logic, sets the motors and
> lamps, and waits for the next round.

**1. How often does the controller do a round when nothing timed is due?**

The fan's logic is only due twice a second. But the box counter and the lamp should
respond quickly.
- **A.** It keeps a steady beat of its own, every 10 milliseconds unless the programmer
  picks another, and does each timed job exactly when it is due. A box is counted, and
  the lamp lights, within about 10 milliseconds, whatever else the plant has. The
  computer does a round 100 times a second, about 2% of one processor core.
- **B.** It only does a round when a timed job is due. Here that is still every 10
  milliseconds, because of the conveyor. But in a plant with only the fan, boxes would be
  checked only twice a second and a quick box could be missed. A plant with no timed job
  at all would need the programmer to set a beat, as the main open-source PLC compiler
  insists.
- **C.** It does rounds flat out, one after another. This gives the fastest response,
  but keeps one processor core completely busy all the time.

*Recommendation: A, because the response time then stays the same whatever timed jobs a
plant has, at a small and steady cost.*

**2. How long may the controller go without updating its outputs before it stops itself?**

If the computer gets too busy, or something gets stuck, the controller can stop itself
with everything switched off. That is the "watchdog". On the test computer, the longest
the controller went without updating its outputs was 20 milliseconds when the computer
was otherwise idle, a tenth of a second with one other heavy job running beside it, and
about seven tenths of a second with two.
- **A.** There is no default: whoever sets up the controller must write down a time, or
  write down "no watchdog". The controller will not start without one.
- **B.** Half a second, unless set. On a very busy computer it could still stop the plant
  now and then.
- **C.** A tenth of a second, unless set. On a busy computer it may stop the plant now
  and then for no fault of the program.

*Recommendation: A, because no one time suits every computer, and having to write it
down makes someone decide what it should be for theirs.*

**3. One watchdog time for the whole controller, or one for each timed job?**

The conveyor's outputs matter within a twentieth of a second; the fan could wait two
seconds.
- **A.** One time for the whole controller, set where the controller is started.
- **B.** A time for each timed job, written in the configuration file next to the job:
  "the conveyor's job must be done within 50 milliseconds, the fan's within 2 seconds".

*Recommendation: A for now, because the controller updates every output together, once
a round, so there is only one thing to time; B can be added later without changing any
existing plant.*

**4. When the watchdog stops the controller, what happens to the outputs?**

This was decided provisionally before; it is asked again now that the details are
known.
- **A.** Everything goes off, once: the conveyor stops, the fan stops, the lamp goes out
  and the drive's speed setting goes to zero. The controller then does nothing until
  someone restarts it. The last count and the last state of every signal can still be
  read on a screen, to see what happened. Note the cost: the fan stops too, even though
  it was meant to run on.
- **B.** Everything stays as it was: the conveyor keeps running at its speed and the lamp
  stays lit, with no logic in control, until someone notices and restarts.

*Recommendation: A, because a plant wired the usual way, where power off is the safe
state, is then safe, while B leaves machines running with nothing watching them.*

**5. The drive's network cable comes loose, or an input card stops answering.**
- **A.** It is treated like the watchdog: everything off, and wait for a restart.
- **B.** The controller carries on, using the last values it read from that card for a
  short grace time (say a second), then stops as in A if the card is still silent. A
  brief network blip then does not stop the line, but during that second a press of stop
  on that card is not seen.
- **C.** The controller carries on with the last values it read, for as long as it
  takes, and reports the problem.

*Recommendation: A, because the controller cannot know whether someone pressed stop or
the emergency stop on the card it can no longer hear, so it should not keep driving the
conveyor.*

**6. If the controller software itself crashes, should it start again by itself?**

Whichever is chosen, a crash switches every output off on the way down.
- **A.** It stays stopped until someone starts it again, as after the watchdog.
- **B.** It starts again by itself straight away, from the beginning. The conveyor stays
  off until someone presses start. But anything switched straight from a held switch
  comes straight back on: a fan wired to a "fan on" switch, say.
- **C.** It starts again by itself, but waits with everything off until someone presses
  restart on a screen.

*Recommendation: A, because it is the same rule as every other fault: nothing starts
again until a person decides it should.*

**7. When someone shuts the controller down normally, for maintenance say, what happens to the outputs?**
- **A.** Everything is switched off first, then it shuts down: the conveyor stops and
  the lamp goes out.
- **B.** The outputs are left as they were. The cards keep whatever they were last told,
  or do whatever they do when they lose contact.

*Recommendation: A, because that is what the main open-source PLC runtime does, and a
controller that has shut down should not leave a conveyor running behind it.*

**8. Forcing a signal for testing.**

A technician wants to check the "case full" lamp without loading 12 boxes. So they make
the controller see the photo-eye as blocked and unblocked from a laptop, whatever the
real photo-eye says. That is "forcing". Forcing an output is the other kind: telling the
lamp to light whatever the program says.
- **A.** Forcing of inputs (buttons and sensors) now. A forced input stays forced until
  it is taken off, even across a restart, and the controller's status always lists
  what is forced. Forcing of outputs comes later, together with the rest of forcing.
- **B.** Wait, and add forcing of inputs and outputs together later.
- **C.** No forcing at all. Testing uses a simulated card instead of the real one.

*Recommendation: A, because forcing an input only changes what the controller reads,
which the new piece already controls, so it can come now and will not need redoing.*

---

## 7. The milestone's shape

**Milestone 4 — the wall-clock runner.** It has six items, after this design record,
which lands first as `docs/organisation.md` §4.11 with decisions 108–115 and `PLAN.md`'s
Milestone 4. No item reserves a word in either language, so none surveys a name first.
Each item lands as a gated series, as Milestone 3's did. Each commit is gated alone by:
- `mix format --check-formatted`;
- `mix compile --force --warnings-as-errors`, in both environments;
- `mix test --warnings-as-errors`, judged by exit code on Elixir 1.20.4.

Each commit's message carries its mutation table: every rule it adds reverted alone, and
every survivor given a test.

**Two rules for every test in this milestone.**
- **Every rule is tested on the manual clock.** A test on the real clock asserts only
  liveness, with bounds read from §3's two-suite soak and a fifth above them, since CI
  shares its cores. CONTRIBUTING.md forbids skipping or quarantining a test, so none may
  depend on the machine being idle.
- **Growth is tested in reductions.** The runner's work per cycle must be linear in the
  points, and `start_link/1`'s checks linear in the devices and points.

- **M4-1 · The clock, the I/O contract and the simulated device.**
  `Logex.Runner.Clock` with `Monotonic` and `Manual`; `Logex.IO`; `Logex.IO.Sim`; and the
  grouping of a configuration's located points by device. *Done when* the manual clock
  delivers timers in time order, ties in the order they were set, and returns from
  `advance/2` only once each receiver has handled its message; `Logex.IO.Sim` reads,
  writes, records every write and acts out each failure; and §4.4's plant's points group
  as `panel` with eight inputs and four outputs and `drive` with two outputs. Its
  landing order:
  1. the clock;
  2. the behaviour and the simulated device;
  3. the grouping, with its host mistakes pinned.
- **M4-2 · The runner: start, pace, cycle, stop, read, subscribe.** *Done when* §4.4's
  plant, loaded from files on disk through `Logex.Configuration.compile_file/1`, runs
  through `Logex.Runner` on the manual clock and two simulated devices over a seeded
  sequence of presses and waits. Its outputs, events and `get/2` values must equal those
  of `Logex.Runtime.cycle/3` called directly with the same `elapsed_ms` and inputs: an
  oracle that knows nothing of the runner. The run must also:
  - repeat exactly from fresh processes;
  - cycle at once after start;
  - never wait longer than `period`;
  - keep 100,000 cycles on their grid with no drift;
  - raise every host mistake of §1, with its pinned message, in the caller, with the
    runner still alive.

  A real-clock test runs the plant for 2 s and asserts liveness and an orderly stop.
  Its landing order:
  1. start and the host mistakes;
  2. the pace and the cycle;
  3. stop, status, `get/2`, subscriptions;
  4. the oracle test from files on disk.
- **M4-3 · The watchdog and the fault path.** *Done when* each of the spike's scenarios
  C to G is a test on the manual clock, G's timeout in real time and short:
  - a late cycle trips before its write;
  - a wedged runner's devices zero themselves;
  - each kind of I/O fault trips, naming its device;
  - a killed runner's devices zero and close;
  - a hung device is killed, and opened again at a restart.

  In each, every device that answers is written 0 exactly once and nothing after; the
  resource is kept for `get/2`; and `restart/2`, cold and warm, resumes with the first
  cycle at once and the clock not counting the stopped time. Its landing order:
  1. the trip and restart;
  2. the runner's gap check;
  3. the device heartbeat;
  4. the I/O faults;
  5. the runner's death.
- **M4-4 · Edits and forcing through the runner.** *Done when* §4.4's plant, edited while
  it runs through `Logex.Runner`'s accept, test, untest, assemble and cancel, gives every
  report and every cycle's outputs that the same steps give taken over the resource
  directly. In particular, `slow` cut to 20 ms moves its next due time as decision 40
  says, with no cycle lost or added. Forcing must: hold a forced input against its device
  and across a restart; refuse an output point or a value that does not fit, in the
  caller; and on `unforce/2`, put back the device's last value even for an adapter that
  reports only changes.
- **M4-5 · The contract walk.** `api_contract_test.exs` gains a runner walk on the
  manual clock: seeded configurations, simulated devices, random waits and presses,
  injected faults, edits, forcing and restarts. It is checked against a model that calls
  `cycle/3` directly with the recorded times and inputs, and a model of the watchdog and
  the trip that knows nothing of the runner. *Done when* its reach is asserted, every
  event kind and trip reason reached.
- **M4-6 · The documents.** README's "Running a plant on the clock", with a real run;
  "What logex is not", plainly; CLAUDE.md's Key Files; `docs/organisation.md` §4.5's
  adapter contract as landed, its §4.6's watchdog paragraph, its §5's row, and decision 14's
  annotation; and `PLAN.md`'s status.

**Milestone 4 is done when** §4.4's plant, loaded from files on disk, runs on the real
clock through bound devices, each periodic task on its grid as closely as the machine
allows and every late period reported; a host test drives the same plant on a manual
clock with simulated devices, and its outputs and events are exactly those `cycle/3`
gives for the same times and inputs; a cycle that would refresh the outputs later than
the watchdog's time, a device that fails, a runner that is stopped, wedged or killed
each leave every output that can still be written at 0, written once, and nothing runs
again until the host restarts it; and an online edit is stepped through the running
runner between cycles.

---

## 8. Risks, and what was spiked

**Spiked, on the branch `backup/runner-design`, `spike-runner/`:**

| Spike | What it settled |
|---|---|
| `timing.exs` | Absolute timers keep a 10 ms grid with no early wake and no drift. Relative ones drift 7%. Process priority does not fix the loaded tail. Re-arming a fixed grid replays a backlog |
| `runner.exs` with `scenarios.exs` | The whole design on the manual clock: §4.4's plant, deterministic (A); an edit through the runner (B); the watchdog before the write (C); I/O faults (D); the heartbeat (E); the runner killed (F); a hung device (G); host mistakes relayed (H); 2 s on the real clock, 201 cycles, no overlap, at most 1 ms late (R). Two defects of the first draft were found and fixed: a late cycle written before its trip, and a stop that returned before the devices were zeroed |
| `soak.exs` | Gaps between writes, idle and under one and two neighbouring suites: §3 |
| `size.exs` | `cycle/3` per motor instance, 9 to 26 µs: §3 |

**Risks.**
- **Real-time tests in CI.** Every rule is tested on the manual clock, and the real-clock
  tests assert only liveness, with bounds from the two-suite soak.
- **A hung device cannot be zeroed from software.** This is said plainly, and README
  advises I/O with an off state on communication loss.
- **A suspended machine** (unverified). The BEAM here reads `CLOCK_MONOTONIC`
  (`erlang:system_info(os_monotonic_time_source)`). By clock_gettime(2)'s definition,
  that clock does not count time the system is suspended. So a controller on a laptop
  that sleeps would wake with no trip and no overlap, its clock having skipped the
  sleep. The devices' heartbeats run on the same clock. This could not be tested in the
  container. It must be tested on a real machine before README says what a sleep does.
- **The manual clock's ordering.** The spike's clock syncs each process after a delivery
  and relies on one-node message ordering between two senders. The landed clock should
  have each receiver acknowledge each delivery (a call rather than a send, or a reply
  from the runner) so that the order is by construction.
- **A slow or failed close** at stop. Each device's close is bounded by the call
  timeout, so a dead network cannot hold up a host's shutdown longer than that.
- **Plants larger than the period.** 1,000 motors cost 27 ms a cycle. The overlaps and
  the watchdog report it, and README should give the measured cost per instance, so
  that a programmer can size `period`.
- **Determinism of the devices.** Exact replay holds only given the same inputs. A real
  device's sampling time inside a cycle is the adapter's, and reading devices one after
  another samples them at slightly different instants.
- **Events in volume.** `:ran` at 100 a second per instance is opt-in. A host that
  subscribes to it and stops reading grows its own mailbox, not the runner's.

**Not spiked, and worth a spike before or during the milestone:**
- a real network adapter, outside logex, for the cost of a device on a network and of
  reading devices in parallel;
- operating-system real-time priority and the VM's scheduler flags, against §3's tail;
- what a suspended laptop does to the runner;
- the device process started outside OTP's parent handling, so that a dying runner
  gives no crash report.
