defmodule Logex.Runner do
  @moduledoc """
  The wall-clock runner (M4-3, `docs/organisation.md` §4.11): a process that runs one
  configuration's resource, `%Logex.Runtime{}`, on a clock, through the devices its points
  are bound to. It is the one piece of logex that reads a clock (`Logex.Runner.Clock`);
  `Logex.Runtime` stays pure, a cycle a function of its arguments.

      {:ok, runner} =
        Logex.Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Logex.IO.Sim, sim: panel}, "drive" => {Logex.IO.Sim, sim: drive}},
          clock: {Logex.Runner.Clock.Manual, clock}
        )

  **Starting it.** `start_link/1` takes `configuration:`, the configuration it runs, and
  `io:`, each device its points are at bound by name to its adapter (`Logex.IO.bind!/2`),
  and optionally `clock:`, `{module, clock}`, `Logex.Runner.Clock.Monotonic` unless set,
  `poll:`, each device's poll period in ms, 10 unless set, `overhead:`, the share of the
  time kept for the runner's own work in percent, 10 to 90, 20 unless set (decisions 108,
  121 and 122), `idle:`, the runner's idle watchdog in ms, 500 unless set (decision 128),
  `forces:`, the path of the file its forces are kept in (decision 127), none unless set,
  a runner without one taking no force, since M6-5 `retain:`, the path of its store, the
  file its retained values are kept in across a crash (decision 275), none unless set,
  since M6-6 `retain_period:`, how often it writes that store, 100 to 3,600,000 ms, 1000
  unless set or nil (decision 275), and `start:`, `:warm` or `:cold`, how a fresh start
  meets that store, `:warm` unless set (decision 271), each of the last two the host's
  mistake without `retain:` (decision 323), and `name:`, a name to register it under, as
  `GenServer.start_link/3` takes one. It
  checks every option in the caller before anything starts, the configuration as
  `Logex.Runtime.start/1` checks it and the bindings as `Logex.IO.bind!/2` does, so a
  host's mistake is an `ArgumentError` in the host's own process, with a message a test
  pins, and never a crash of the runner. Its child spec is `restart: :temporary`
  (decision 115): nothing starts it again that no person asked to start; and since M6-6's
  review its `shutdown:` is long enough for every device's close and the store's write,
  `(devices + 2) * (idle + poll)` ms and never less than 5000 (`child_spec/1`, decision
  326), so that a supervisor does not kill it before decision 316's write.

  **Its devices** (decisions 112, 120, 124 and 125). Each bound device runs in a process
  of its own, linked to the runner, which holds its adapter's state and calls its
  callbacks; the runner opens them in device-name order, reads each once, and runs the
  first round at once, so a device that cannot be opened is `start_link/1`'s
  `{:error, {:io_init, device, reason}}`, every device opened before it closed again. It
  does so before it handles anything sent to it, so a call or a stop by its name that
  comes first waits until its devices are open and its first round has run.
  - Each device reads its adapter every poll period on the runner's clock, from the time
    it was opened, on a grid that never drifts, and gives each other message its process
    receives to the adapter's `report/2`, where it has one: so a device that reports
    passes each change on as it comes, between reads, and one that cannot is read.
  - A device keeps each point's newest reading the runner has not taken, and passes on
    what of it changed since the runner last took a change of it, by a call, one change
    at a time, in order; a change the runner refuses, holding a value that does not fit
    or an address that is no input point's (an I/O fault, below), is not taken, its
    refused point's reading dropped, so that the device passes it on again at its next
    read that gives it, and the rest passed on with its next reading (decision 143), and
    a restart reads every device whole (decision 142), so that one that goes on giving
    it leaves each restart refused; from a restart's release until the runner has taken
    a device's own read, the device passes nothing on, the read merged over every
    reading the device holds untaken, one between the release and the read or one passed
    on before the release and answered stale, so that the read supersedes it for each
    point it gives and the rest is checked as the restart's read, one after it passed on
    against it, and a report the device handles late, having waited on the runner
    meanwhile, dropped for each point that read gives where it came before it; a restart
    refused, the device passes on what it held, as a change read while tripped. The
    runner merges a change into the next round's inputs, and
    a change of an event task's trigger, an input point that is a task's `single`, makes a
    round at once, each such change its own, in address order; it answers once those
    rounds have run and their outputs are written, so that `Logex.IO.Sim.set/3` returns
    after them, by construction. While it waits the device answers the runner's own
    requests to it, so that neither waits on the other.
  - After each round every device whose outputs changed is given every one of its output
    points, by address, and the runner waits for its answer, which comes once its adapter
    has written them. Every device is refreshed, without a wait, before each step of a
    round, the refresh carrying that step's deadline, its task's watchdog and one poll
    period from the step's start, and before the write, carrying the idle watchdog's and
    one poll period from then (decisions 125 and 128): a refresh calls no adapter.
  - At each poll, after its read, a device writes the outputs it last wrote again,
    whether or not a round wrote to it within the poll period, while its last refresh's
    deadline has not passed: a fixed timer, as Logix re-sends a module's outputs at its
    RPI, so that every device hears from its master once a poll period while the runner
    is well, at the cost of one adapter write a device a poll period beside each round's
    (decision 130); a device never written, a device with no output point among them,
    is written nothing at a poll.

  **Its rounds** (decisions 108, 122 and 123). A *round* takes the inputs, runs the cycle's
  steps, the due timed tasks and then the untimed programs (`Logex.Runtime.cycle/3`, cut
  into its steps, decision 118), and writes the outputs. The runner keeps `anchor`, the
  time on its clock it counts from, and the resource's `now`, the sum of the elapsed
  times it has passed, and each round passes the time since the last, the clock less the
  anchor less `now`, so that rounding to whole milliseconds never accumulates; it sleeps
  to absolute times on its clock, never relative ones, so its rounds keep their grid.
  - The first round runs at once after start.
  - While the configuration has untimed programs, the continuous task's or a program
    with no task, rounds run back to back, to the clock's resolution: the next round at
    the millisecond after the one the last began in, or at once where it took a
    millisecond or more, a wake on the clock either way. So at most one round runs a
    clock millisecond, and on the manual clock `advance(clock, n)` runs n where rounds
    take no time.
  - A periodic task's due time is a wake of its own, at the next due time on the
    runner's clock (`Logex.Runtime.next_due_in/1`), a round's first steps, never
    preempting one; with no untimed program a round comes only then, or when a device
    changes a trigger. A trigger logic writes, an event task's single that is no input
    point, changed by a round, makes the next round at the next clock millisecond, so
    that two event tasks that write each other's trigger round once a millisecond.
  - The share, `overhead:`, is served in the conventional table's slots: after C ms of
    the continuous task's rounds the runner serves its own work, the host's requests that
    waited, for up to S ms, C = max(1, round((100 − p)/p)) and S = max(1, round(p/(100 −
    p))) for a share of p%, 9 and 1 at 10%, 4 and 1 at 20%, 1 and 1 at 50%, 1 and 9 at
    90%. A round counts from its start to its end, a millisecond at least, the timed
    tasks' runs in it left out, so that the runner's own work never counts as the
    round's; the slot comes at the end of the round that completes C
    ms; it serves its first request whatever the time, and each whole, so it may run over
    by one; and in the rest of a millisecond a round did not fill the runner serves its
    requests freely. A host's request is served at once where no round is owed, and with
    no untimed program always. Every device is refreshed before the runner serves its own
    work, whichever way.
  - **On the manual clock** (decision 131) the same rules run: a round takes no time
    unless something passes time inside it, so a request is served before the next
    round; but one made while a round is owed, after a round that passed time, waits for
    its slot, which comes in the advance that runs the round completing C ms of rounds,
    `advance(clock, 0)` among them, never later. A test that calls from the process that
    moves the clock would wait for ever, so it calls from another and moves the clock on
    until the call is answered:

        task = Task.async(fn -> Logex.Runner.get!(runner, "boxes.n") end)

        answered = fn answered ->
          case Task.yield(task, 10) do
            {:ok, value} -> value
            nil ->
              Logex.Runner.Clock.Manual.advance(clock, 0)
              answered.(answered)
          end
        end

        answered.(answered)

    Each `advance(clock, 0)` runs the one round owed, so at most C of them, 4 at 20%,
    bring the slot.
  - While it waits for a round longer than a poll period, the runner refreshes every
    device at least once a poll period, with the idle watchdog's deadline.

  **A host's calls** go through the runner's mailbox, so each is served between two
  rounds. A mistake in one is the host's: the runner rescues the `ArgumentError`, replies
  with it, and the function raises it in the caller, the runner running on. A runner is
  given by its pid, or by the name it was started under; a call still waiting when the
  runner stops raises in its caller that the runner is not running, as a call to a
  runner already stopped does. Anything else sent to the runner changes nothing: a
  message or a cast is passed over, and a call that is none of its functions' is the
  caller's mistake, answered with the `ArgumentError` `Logex.Runner has no request ...`.

  - `get/2` and `get!/2` read the resource as `Logex.Runtime.get/2` and `get!/2` do, of the
    last round computed, a path that names nothing being `{:error, reason}` from the one
    and a raise from the other, and a path that is not a string a raise from both.
  - `status/1` gives the runner's state, its rounds, each task's overlaps and longest run
    against its watchdog, the latest wake and the longest wait between two refreshes.
  - `subscribe/2` sends the caller each event of the kinds it names, as `{Logex.Runner,
    runner, event}`: the resource's `{:overlap, task, missed}` and `{:fault, task,
    instance, fault}` and the runner's `{:trip, reason}` and `{:restart, mode}` by
    default, with `{:edit, step, report}`, and, only where named, the resource's `{:ran, task, instance, now}` and the runner's
    `{:round, now, outputs}`, each round's output points; and since M6-5, by default,
    `{:retain, {:error, reason}}`, a store write that failed. A subscriber is monitored and
    dropped when it goes down. `unsubscribe/1` stops them.
  - `force/3`, `unforce/2` and `unforce_all/1` force an input point, below.
  - `stop/2` writes every output 0 once, through each device, and closes every device, in
    device-name order, before it returns (decision 116), and since M6-5 then writes the
    store, where one is named, answering `:ok` or `{:error, {:retain, reason}}` (decision
    275). It is served at once, whatever the share, a system message, so that a runner
    suspended is stopped too.
  - `restart/2` starts a tripped runner again (below); a runner that is running is the
    host's mistake (decision 133).

  **Its store** (M6-5, `docs/organisation.md` §4.13; decisions 271, 275, 276, 284, 285,
  291 and 292). A runner given `retain:` keeps every value its configuration retains, the
  resource's retained image (`Logex.Runtime.retained/1`), in a file on the host's disk,
  which stands in for battery-backed memory:
  - *Its text* is a person's to read, and to edit by hand where a retained value tripped
    the plant (decision 284): `logex retain 1`; `configuration <name> written <time>`,
    the time of the write on the host's wall clock, in UTC to the second, read through
    the clock's `wall_ms/1` (`Logex.Runner.Clock`), for a person and for `status/1`, never
    for a timer; each retained global, `global total_boxes dint 41`; each retained
    `single`'s last sample, `trigger arm 0` (decision 313); and each instance whose program
    retains anything, `instance m1 motor`, then its lines in path order, each instance on
    the way to a value with its kind, `m1.boxes ctu`, and each value with its type,
    `m1.boxes.cv dint 41`, an array's elements in the elements' order, `m1.weights int[8]
    0 0 12 14 0 0 0 0`, a real in the shortest text that reads back to it, and a timer's
    `last` never.
  - *Its writes*: at every trip, of the resource as the trip left it, after every output
    is 0; at every `stop/2`, and since decisions 316 and 328 at every orderly exit, a
    parent's shutdown or `:normal`, after every output is 0 and every device closed; at every cold restart, of the
    resource as it restarts it, before any device is released or read (decision 291),
    and where a device then refuses it, of the resource as the runner still holds it,
    after the refusal's zeros (decision 317); and at a fresh start with `start: :cold`, or with no store file,
    in the caller, before any device is opened. Each is synchronous, written whole to
    `<path>.tmp` beside it, flushed and renamed over it, the forces file's rule, so that a
    crash at any moment leaves the old store or the new. A write that fails leaves the
    store as it was and is reported, `{:retain, {:error, reason}}` to the subscribers and
    `failed` in `status/1`'s `retain`: a trip stays a trip; a cold restart leaves the
    runner tripped as it was, every output still 0 and no device released or read, and
    answers `{:error, {:retain, reason}}`; a stop stops all the same and answers it; and
    a fresh start starts nothing and gives it. Since decision 317 a cold restart that a
    device then refuses writes the store back, after the refusal's zeros, with the values
    the runner still holds, the trip's, so that a refused restart changes nothing on disk
    or in memory, a write-back that fails reported as any failed write, the runner tripped
    either way. Since decision 316 an orderly shutdown from the runner's parent, a
    supervisor's `:shutdown` or a `{:shutdown, term}`, writes as `stop/2` does, after
    every output is 0 and every device closed, a failure reported to the subscribers;
    the runner tells a shutdown by its reason alone, so `GenServer.stop(runner,
    :shutdown)` from any other process writes as its parent's does, its caller given
    `:ok` and the failure only to the subscribers, where `stop/2` answers it (decision
    327). Since decision 328 a `:normal` exit writes too, a parent's that ends `:normal`
    and a `GenServer.stop(runner)` from any process, after the same zeros and closes, so
    that every orderly exit writes. A runner that crashes or is killed, whose clock goes
    down, a shutdown of its own, `{:shutdown, {:clock, reason}}`, or that ends for any
    other reason, writes none (decision 292), so its next fresh start meets the last
    write, a period's or an event's; and one whose devices cannot be opened, whose
    `init/1` gives `{:error, {:io_init, device, reason}}` and so ends `:normal` with no
    `terminate/2`, writes none either, the store as the caller left it.
  - *Its period* (M6-6, decision 275): every `retain_period:` ms, 1000 unless set, on a
    grid from the runner's start on its clock, as a periodic task's due times are, a due
    time passed while the runner was busy skipped, never made up, and none while tripped,
    the trip's own write standing, a restart taking up the grid at its next due time
    (provisional). The runner takes the retained image out between rounds, at a cost in
    proportion to the retained values alone, as its own work: with untimed programs first
    in the share's slot at or after the due time, out of its S ms and before the requests
    that waited, and with none at a wake of its own, or just after the round due with it
    or running then, so that the period never runs inside a round nor moves a round's
    due time (decisions 108 and 122, provisional). A writer process of the runner's own,
    linked to it, writes the image by the same rule as every write, so that a slow write
    delays no round: while one is in progress the next waits, the newest replacing the
    one before, latest wins. A write made is the store's age in `status/1`'s
    `written_at`; one that fails leaves the store as it was and is reported,
    `{:retain, {:error, reason}}` and `failed`, the plant running on; a writer gone down
    is reported, `{:down, reason}`, and a new one writes the next (provisional), one gone
    down while idle forgotten. Every
    write at an event waits first for the write in progress and drops the one pending,
    so that the event's is the last on disk: the trip's, the stop's, a shutdown's and a
    cold restart's, a writer that has not answered by the idle watchdog and a poll period,
    in real time, killed, its write reported `:timeout`, and one already gone down taken
    as gone at once, `{:down, reason}` (provisional). So a crash or a kill loses what
    changed since the last write made: at most a period and the write in progress while
    writes succeed and the writer keeps up, but everything since the last good write
    while they fail, a full disk's among them, and, while tripped, what an edit stepped
    then changed, which no write takes until a restart.
  - *A fresh start* reads the store in the caller, after the forces file, warm unless
    `start: :cold`: a store laid over the resource by decision 277's matching
    (`Logex.Runtime.start/2`), each value kept only where the configuration retains its
    path, of exactly its type, and it fits, the rest dropped and reported in `status/1`'s
    `retain`; a file that does not exist none, written at once; and one that cannot be
    read, that is no store, a line of no store's shape, an image `Logex.Runtime.start/2`
    refuses, or a store of another configuration, which a renamed configuration's is, the
    host's mistake, one `ArgumentError`, a line each, `<path>: line <n>: ...`, the runner
    not started and no device opened. `start: :cold` reads none, a broken one among them,
    and writes a new store at once.
  - A runner with no `retain:` keeps nothing across a crash; a warm `restart/2` still
    keeps retained values in memory, and `status/1`'s `retain` is nil. `start:` without
    `retain:` is the host's mistake (decision 323), as are `retain:` naming the forces
    file, after `Path.expand/1`, or the `.tmp` either is written through (decision 325),
    and a clock with no `wall_ms/1` (decision 322). The first round's `{:retain, ...}`
    news, the store's age and its drops, reaches no subscriber, since none can exist
    before `start_link/1` returns: `status/1`'s `retain` carries both (decision 324).

  **Forcing** (M4-5; decisions 117 and 127). `force(runner, point, value)` makes the
  runner read an input point, by its name, at `value`, whatever its device says: every
  force is merged over the devices' changes into each round's inputs, after the input
  latch (§5), from the next round until `unforce/2` or `unforce_all/1`, across a restart
  and, kept in the forces file, across a crash and a fresh start. The runner keeps each
  input point's last value from its device, the input image's until a device gives one,
  and `unforce/2` puts it back, the next round reading it. A force or an unforce that
  changes what an event task's trigger reads is a change of it, and makes its round at
  once, before the call returns (decisions 120 and 138), each trigger it changes, as
  `unforce_all/1` may change several, its own round, in device-name and then address
  order, as a device's changes are; one that changes nothing makes none, and a device's
  change of a forced trigger makes none. Since M5-13 an element of a located array is an
  input point of its own, forced, unforced and written in the forces file by its name,
  `temps[3] 37.5` (decision 156); and since decision 241 an array of input points named
  whole is forced to a list of its shape, each element then forced, every misfit told, ten
  and then a count, and unforced whole, each element reading its device's last value
  again; a forces file's line for it is its name and one value an element in the
  elements' order, `temps 20.0 21.5 …`, read as each element forced, the file written
  back element by element.
  `status/1` lists every force. The forces file is the host's to name, `forces:`,
  and each force and unforce writes the whole set to it before it returns:
  one force a line, `name value`, in name order, the empty file for none, written to
  `<path>.tmp` beside it, flushed to the disk and renamed over it, so that a crash at any
  moment leaves the old set or the new; a write that fails changes nothing and gives
  `{:error, {:forces, reason}}`. Every start reads it, `start_link/1` in the caller,
  after the configuration and the bindings, and `restart/2` before it releases anything,
  so that a runner killed while an input is forced, and started again from the same file,
  comes back with it forced and listed: a file that does not exist is no force; one that
  cannot be read, a line that is no force, a point forced twice, and a force the
  configuration cannot take, on a point it does not have as an input point or of a value
  that does not fit, are the host's mistake, every one named in one `ArgumentError`, a
  line each, `<path>: line <n>: ...`, the runner not started, or at a restart left
  tripped: the file is read exactly as the runner writes it, a last line with no newline
  read, and an unforce of a point not forced is accepted, writing the set again
  (decision 140), but for a point's value, which since decision 218 for a real point and
  decision 226 for every other is any number the lexer reads as one literal and the
  point's type holds, `fan_hz 37.50`, `3.75e1` or `37`, `eye_1 01` or `level 16#ff`, held
  at the type's nearest value as `force/3` holds one, the next force or unforce writing
  the whole file again in the runner's spelling, `fan_hz 37.5` and `level 255`. A point a restart's file no longer forces reads its device's last value
  again. With no runner, the host clears every force by deleting the file. A runner
  started without `forces:` takes no force, an
  output point or a name that is no input point's is forced by no one, and a value that
  does not fit its point is refused, each the host's mistake. Output forcing waits for
  §5's forcing in `cycle/3`.

  **Edits** (M4-5, §4.11). Each step of a `Logex.Configuration.Edit` is a call to the
  runner, served between two rounds as any request is, and the runner holds the edit, one
  at a time: `accept/2` gives `{:ok, forecast}` or `{:error, diagnostics}`, a second
  accept superseding the first (decision 66), a refused one leaving the edit held as it
  was; `test/1`, `untest/1`, `assemble/1` and `cancel/1` each give `{:ok, report}`, the
  report the same step gives taken over the resource directly at the same time, and its
  next round runs the resource the step returns. Accept's work, which grows with the
  programs, is done in the caller's process, against the resource the runner hands it
  (decision 119), and done again where another step was taken meanwhile (decision 141).
  After each step the rounds read the configuration the resource runs: each task's
  watchdog (decision 129), and whether it has untimed programs, an instance an edit adds
  with no task rounding back to back and one it sets aside no more, and a step that
  leaves none followed at once by every request that waited for the share's slot, in
  order, as each is served from then on; and the next round is planned again from the
  last, so that a task whose interval changed is next due where decision 40 moves it,
  its `now` the step's time on the runner's clock, given to the switch as the time since
  the last round, 0 while tripped, so that with no untimed program a cut served long
  after the last round misses no period and adds no round (decision 139). Each step
  sends `{:edit, step, report}`, accept's its forecast, and `status/1` gives the stage. A step may be taken while tripped, so that a program can be fixed and
  then restarted, and a restart keeps the stage (decision 65). A step with no edit held,
  and one its stage refuses, are the host's mistakes, the latter in
  `Logex.Configuration.Edit`'s words, and so is each of accept's, raised in the caller.

  **Its trips** (M4-4; decisions 110, 111, 113 to 115, 125, 126, 128 and 133 to 137). A
  trip has one path, whatever caused it: scheduling stops, its wake cancelled; every
  output is written 0 once through each device that answers, in device-name order, which
  latches and writes nothing more, a round's write and a poll's write again among it,
  until a restart; `{:trip, reason}` goes to the subscribers and `status/1` gives
  `:tripped` and the reason; the host's requests that waited are answered, and every one
  after is served at once; a device's change is merged into the next round's inputs and
  makes no round; and the resource is kept as the last round computed it, for `get/2`,
  outputs the plant never received among them where the round tripped before its write. A
  runner tripped already keeps its first reason; the devices' notices that waited for it,
  a latch or a fault of their own, are taken together, in the order of the time each was
  raised, ties in device-name order, so that two devices that latch in one millisecond
  trip it for the same reason on every run, and each is acted on before the trip, which
  may serve a restart that waited, so that its first round finds every device heard as
  late as they say. A notice carries the count of restarts its device had been released
  for, and one raised before the last restart's release, taken with the notice that made
  the trip or come in behind a restart the trip served, trips nothing. The reasons:
  - `{:watchdog, {:task, task, took_ms, limit_ms}}`: a timed task's run, from the start of
    its first instance's scan to the end of its last, longer than its task's watchdog,
    checked after its step and before the round's write (decision 110);
  - `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`: a round of the continuous
    task, from the inputs taken to the end of its last program's scan, the timed tasks'
    runs in it included, longer than the continuous task's watchdog, `task` its name or
    `:none`, 500 ms, where none is declared, and `steps` each step the round ran, in
    order, `{task, ms}` (decisions 111 and 126);
  - `{:watchdog, {:idle, ms}}`: a host's request served whole, from its start to its end,
    longer than the idle watchdog, the trip made once it is answered (decision 128);
  - `{:watchdog, {:device, device, ms}}`: a device that heard nothing from the runner by
    the deadline its last refresh carried, `ms` from that refresh to it, the heartbeat it
    was given (decision 137), which writes every output 0 once and latches by itself and
    tells the runner, which trips when it next runs, before any round (decision 125).
    Every device is refreshed before each step with that step's deadline, its task's
    watchdog and a poll period from its start, and before the runner's own work, a write
    or a wait with the idle watchdog's and a poll period, so a runner that is well never
    misses one, and one stuck in the conveyor's 50 ms step leaves every device that
    answers at 0 within 50 ms and a poll period;
  - `{:io, device, cause}`: an I/O fault (decision 114). Every callback is called guarded
    in its device's process: an `{:error, reason, state}` it gives is `{:error, reason}`,
    a raise `{:raised, message}`, a throw `{:thrown, term}`, an exit `{:exited, term}`,
    and a result of no shape `Logex.IO` gives `{:raised, message}`, a message that says
    so; a read's or a report's value that does not fit its point is `{:bad_value,
    address, value}` and an address that is no input point's `{:unknown_address,
    address}`; a device that does not answer the runner within the deadline its last
    refresh carried, in real time, is `:timeout`, and is killed, its outputs left to what
    it does on losing its master; one that answers a round's write after that deadline on
    the runner's clock is `:timeout` too, and is written its 0 by the trip, as every
    device that answers is; so is one hung inside its own read or report,
    which has not told the runner it is back from its adapter, after a read or a report,
    at a poll while it waits on the runner or by answering a round's write in time, within
    the idle watchdog and a poll period, seen as each round begins and at each wait's
    refresh, at the cost of a message to the runner a device a poll period (decision
    134); and a device's process that goes down, which the runner traps, is `{:down,
    reason}`. A device whose own read, report or write again fails tells the runner and
    latches, its 0 written where its adapter still takes it (decision 135);
    a round's write that fails trips at once, the devices after it not written;
  - `{:fault, task, instance, fault}`: since M5-9 (decisions 153 and 160), a major fault,
    a `%Logex.Fault{severity: :major}`, a bit whose number a tag holds outside its word's
    bits, `kind: :bit_out_of_range`, with its instance, file, line and the number read,
    or since M5-12 an element whose subscript a tag holds outside its dimension, `kind:
    :index_out_of_range`, with the subscripts read, a tuple, `{8}` (decision 233):
    the round's first, at the end of the step whose run met it, one task's run or the
    untimed programs', that run having scanned every instance it holds, and before the
    round's write; no later step of the round runs, so `get/2` reads each later task's
    instances as the round before left them. The fault's own event, `{:fault, ...}`, is
    published with the round's, then the trip. A minor fault, a zero divisor, trips nothing;
  - `{:internal, message}`: an exception out of the core, which the host contract says
    cannot happen; tripping rather than crashing keeps the state for diagnosis. No host
    can cause it: a test reaches it through one hidden option of `start_link/1`, which
    stands a module of the test's in for `Logex.Runtime`'s steps.

  `restart(runner, :cold | :warm)`, `:warm` keeping what each program retains, since M6-2
  (`Logex.Runtime.restart/2`, decision 271), in memory, and `:cold`, since M6-5, writing
  the store first, where one is named, of the resource as it restarts it, before it
  releases or reads any device (decision 291), a write that fails leaving it tripped as it
  was, `{:error, {:retain, reason}}`; releases
  every latch, in device-name order, a device that does not answer within the idle
  watchdog and a poll period killed, as one that hung while the runner was tripped; reads
  every device once, in device-name order, as a start does (decision 142), opening again
  each device that went down, those among them, and checking each value read as a start's
  first reads are; `{:error, {:io_init, device, reason}}` for the first that cannot be
  opened or whose read fails, an error, a raise, a throw, an exit, a value that does not
  fit, an address that is no input point's, no answer in time (the device killed, and
  opened again at the next restart) or a process gone down, the runner left tripped with
  its first reason and every device that answers latched again, written 0 once more, as
  a restart that trips again is (decision 136), so that nothing switches on from a card
  still at fault; restarts the resource (`Logex.Runtime.restart/2`), which keeps its
  input image and puts every other global back to its initial value; sends `{:restart,
  mode}`; and runs the first round at once, on what the devices read, before it returns,
  the clock not counting the time it was stopped. A runner that crashes, is killed or loses its clock is gone (decision 115):
  each device traps its exit and writes every output 0 once, where it had not, and closes;
  its child spec is `restart: :temporary`, so nothing starts it again, and the host starts
  a new one. A clock that goes down or fails stops it as a shutdown, `{:shutdown,
  {:clock, reason}}`, its devices zeroed and closed as at a stop.

  **What logex is not.** logex is not a safety controller, and must not implement a
  safety function: an emergency stop, a guard interlock, a light curtain, two-hand
  control, burner or pressure protection belong in hardwired circuits or a safety-rated
  controller designed and validated to the functional-safety standards that apply,
  against which logex makes no claim. An e-stop a program reads is a signal it records;
  the e-stop that cuts the power must be wired to work with logex stopped, crashed or never
  started. logex is not hard real-time, its watchdogs being a backstop, not a guarantee,
  and it is not certified for any industrial use.
  """

  use GenServer, restart: :temporary

  alias Logex.{Configuration, Declarations, Fault, Runtime}
  alias Logex.Configuration.Edit
  alias Logex.IO.Point
  alias Logex.Runner.{Clock, Device, Writer}

  # `steps:` is hidden (M4-4): a module of a test's standing in for Logex.Runtime's
  # steps, the one seam through which a test reaches a fault no host can cause, an
  # exception out of the core, `{:internal, message}` (docs/organisation.md §4.11).
  @options [
    :configuration,
    :io,
    :clock,
    :poll,
    :overhead,
    :idle,
    :forces,
    :retain,
    :retain_period,
    :start,
    :name,
    :steps
  ]
  @steps [cycle_steps: 3, cycle_step: 2, cycle_outputs: 1]

  # The events a subscriber may name, and those it gets unless it names them (§4.11).
  @kinds [:overlap, :fault, :trip, :restart, :edit, :retain, :ran, :round]
  @default_kinds [:overlap, :fault, :trip, :restart, :edit, :retain]

  # A poll period and the idle watchdog are an interval's range, as a watchdog is
  # (decision 109); the share is the conventional table's span (decision 121).
  @interval 1..2_147_483_647
  @share 10..90

  # A store's period, the record's range (decision 275, M6-6, provisional).
  @period 100..3_600_000

  @doc """
  Starts a runner linked to the caller, every option checked first in the caller (see the
  moduledoc), opens every device in device-name order, reads each once and runs the first
  round at once: `{:ok, pid}`, or `{:error, {:io_init, device, reason}}` for a device that
  cannot be opened, which is the plant's state, not a host mistake, every device opened
  before it closed again and the runner gone: `reason` init/3's own, or the cause of an
  init/3 or a first read that raised, threw, exited, gave no result `Logex.IO` gives or a
  value that does not fit, or `:timeout` for one that did not answer within the idle
  watchdog and a poll period, as an I/O fault's (M4-4).
  """
  def start_link(opts) do
    {start, name} = options!(opts)
    begun(first_write(start), start, name)
  end

  @doc """
  The child spec a supervisor starts a runner by, `restart: :temporary` (decision 115),
  and, since M6-6's review, a `shutdown:` long enough for the orderly shutdown decision 316
  writes the store at: every device's 0 and close, each bounded by the idle watchdog and a
  poll period in real time, the writer's write in progress, bounded the same, and the
  store's own write, given one more: `(devices + 2) * (idle + poll)` ms, and never less
  than the 5000 ms of any GenServer's spec, so a plant of a few devices keeps that
  (decision 326). `devices` is the number of devices `io:` binds; an option that is not
  yet the runner's, which `start_link/1` refuses, counts as its default. A host that
  gives its own `shutdown:`, by `Supervisor.child_spec/2`, takes its own.
  """
  def child_spec(opts),
    do: Map.put(super(opts), :shutdown, shutdown_ms(opts))

  @shutdown 5000

  defp shutdown_ms(opts) when is_list(opts), do: shutdown_ms(Keyword.keyword?(opts), opts)
  defp shutdown_ms(_opts), do: @shutdown

  defp shutdown_ms(true, opts) do
    each = within(Keyword.get(opts, :idle), 500) + within(Keyword.get(opts, :poll), 10)
    max(@shutdown, (bound(Keyword.get(opts, :io)) + 2) * each)
  end

  defp shutdown_ms(false, _opts), do: @shutdown

  defp within(ms, _default) when is_integer(ms) and ms in @interval, do: ms
  defp within(_ms, default), do: default

  defp bound(io) when is_map(io), do: map_size(io)
  defp bound(_io), do: 0

  # M6-5 (decisions 271 and 291): a fresh start with `start: :cold`, or with no store file,
  # writes the store before any device is opened, here in the caller; a write that fails
  # starts nothing, `{:error, {:retain, reason}}`, the store as it was.
  defp begun(:ok, start, name), do: GenServer.start_link(__MODULE__, first_written(start), name)
  defp begun({:error, reason}, _start, _name), do: {:error, {:retain, reason}}

  defp first_write(%{retain: %{path: path}, at: %DateTime{} = at, runtime: runtime}),
    do: Logex.Retain.written(path, Logex.Retain.encode(Runtime.retained(runtime), at))

  defp first_write(_start), do: :ok

  defp first_written(%{at: %DateTime{} = at, retain: retain} = start),
    do: %{start | retain: %{retain | written_at: at}}

  defp first_written(start), do: start

  @doc "The value at an access path, as `Logex.Runtime.get/2` gives it: `{:ok, value}` or `{:error, reason}`."
  def get(runner, path), do: call(runner, {:get, path})

  @doc "The value at an access path, as `Logex.Runtime.get!/2` gives it, raising `ArgumentError` with its reason."
  def get!(runner, path), do: call(runner, {:get!, path})

  @doc """
  Stops the runner: every output written 0 once, through each device, and every device
  closed, in device-name order, before it returns (decision 116); a tripped runner's
  devices written no 0 again but, since decision 286, each whose trip's 0 its adapter has
  not taken, which `status/1` names, tried once more and closed whether or not the 0 is
  taken. A device whose 0 hangs, a running runner's or that last 0, is waited on until
  its deadline, the idle watchdog and a poll period in real time, and then killed, its
  adapter not closed, so a stop returns within that time a device. A reason other than
  `:normal`, `:shutdown` or `{:shutdown, term}` is an abnormal exit, as for any GenServer.

  Since M6-5 (decisions 116 and 275) a runner given `retain:` then writes its store, of
  the resource as the stop found it, the zeros and the closes first, so that no store
  write keeps an output on, and the stop answers `:ok`, or `{:error, {:retain, reason}}`
  where the write failed, the runner stopped all the same; one with no store answers
  `:ok` as before. The stop is still a system message, served when the runner reaches it,
  never held for a slot and served by a runner suspended too: its caller names itself to
  the runner first, and the runner answers it as it terminates, a call in effect only,
  since a call would wait on a suspended runner for ever (decision 321).
  """
  def stop(runner, reason \\ :normal) do
    pid = runner!(runner)
    ref = make_ref()
    send(pid, {__MODULE__, :stopping, self(), ref})
    GenServer.stop(pid, reason, :infinity)
    stopped(ref)
  end

  # The stop's answer, which the runner sends as it terminates, after its zeros, its closes
  # and its store's write; a runner that went down by itself meanwhile sends none.
  defp stopped(ref) do
    receive do
      {^ref, reply} -> reply
    after
      0 -> :ok
    end
  end

  @doc """
  The runner's status, a map: `status`, `:running`, or `:tripped` from a trip until a
  restart; `now`, the resource's time; `rounds`, the rounds run, a round that tripped
  not among them; `trip`, the trip's reason, nil while running; `overlaps`, each task's
  (`Logex.Runtime.overlaps/1`);
  `forces`, every force, by its point's name, with its value; `edit`, the stage of the
  edit the runner holds, `:accepted`, `:testing` or `:untested`, nil for none; `runs`, each task's longest run against its watchdog,
  `{ms, watchdog_ms}`, a timed task's run and the continuous task's round, under its name
  or `:none`, a continuous task that runs no instance timing none and listed at 0; `latest_wake`, the most a round's wake came after its time, in ms;
  `refresh_gap`, the longest wait between two refreshes of the devices, in ms; and since
  decision 262 `unzeroed`, the names, in device-name order, of the devices whose outputs
  are not known to be 0 since the trip: one whose adapter did not take the trip's 0,
  which its poll writes again until one is taken, and one down, at the trip or, since
  decision 287, after it, though its 0 was taken, until a restart; `[]` while running;
  and since M6-5 `retain`, nil for a runner given no `retain:`, and otherwise its store,
  `%{path: path, written_at: at, failed: reason, dropped: dropped}`: `written_at` the time
  in the header of the store on disk, the last write's, since M6-6 a period's among
  them once its writer has made it, or, until a write, the one the fresh start read, a
  UTC `DateTime` to the second, the store's age; `failed` the reason
  the last write failed, nil where it did not; and `dropped` what the fresh start's
  matching dropped, `{path, reason}` in path order, as `Logex.Runtime.start/2` gives it
  (decisions 275 and 277).
  """
  def status(runner), do: call(runner, :status)

  @doc """
  Subscribes the caller to the runner's events of the kinds named, each sent as
  `{Logex.Runner, runner, event}`: `:overlap` and `:fault`, the resource's own, and
  `:trip`, `:restart` and `:edit` by default; `:ran`, the resource's `{:ran, task,
  instance, now}`, and `:round`, the runner's `{:round, now, outputs}` after each round,
  only where named, since a live display's events come at thousands a second. A
  subscriber is monitored, and dropped when it goes down; subscribing again replaces the
  kinds. Events are sent, never awaited.
  """
  def subscribe(runner, kinds \\ @default_kinds),
    do: call(runner, {:subscribe, self(), kinds!(kinds)})

  @doc "Stops sending the caller the runner's events."
  def unsubscribe(runner), do: call(runner, {:unsubscribe, self()})

  @doc """
  Forces an input point, by its name, to `value`, whatever its device says, from the next
  round until it is unforced, across a restart and, kept in the forces file, across a
  crash and a fresh start (decisions 117 and 127): the whole set of forces is written to
  the file before it returns, `:ok`, or `{:error, {:forces, reason}}` where it cannot be,
  the force not taken. A force that changes what an event task's trigger reads is a change
  of it, and makes its round at once, before it returns (decisions 120 and 138). A runner started
  without `forces:`, an output point, a name that is no input point and a value that does
  not fit are the host's mistakes. Since decision 241 a located array of input points
  named whole, `"zone_t"`, is forced to a list of its shape in the elements' order, each
  element then forced as its own point, nothing forced where its shape or any element does
  not fit.
  """
  def force(runner, point, value), do: call(runner, {:force, point, value})

  @doc """
  Takes the force off an input point, by its name, so that the next round reads its
  device's last value again (decision 117), the whole set of forces written to the file
  before it returns: `:ok`, or `{:error, {:forces, reason}}`, the force not taken off. A
  trigger that reads another value makes its round at once, as a force does. A located
  array of input points named whole unforces every element (decision 241).
  """
  def unforce(runner, point), do: call(runner, {:unforce, point})

  @doc """
  Takes every force off, each input point back to its device's last value, and writes the
  forces file empty (decision 127): `:ok`, or `{:error, {:forces, reason}}`, no force
  taken off. Each trigger that reads another value makes its own round at once, in
  device-name and then address order, each round reading those before it at their new
  values and those after it as they were (decision 120).
  """
  def unforce_all(runner), do: call(runner, :unforce_all)

  @doc """
  Accepts `candidate` against the configuration the runner runs, as
  `Logex.Configuration.Edit.accept/3` does at the time the runner hands it, the time
  since its last round (decision 139): `{:ok, forecast}`, the runner then holding the
  edit, a second accept superseding the first, or `{:error, diagnostics}`, the edit it
  held kept. Accept's work, which grows with the programs, is done in the caller's
  process, against the resource the runner hands it, so that the runner's rounds wait on
  it no longer than on a request; where another step was taken meanwhile, it is done
  again against the resource as it is then (decision 141). `{:edit, :accept, forecast}` goes to the
  subscribers. Its host mistakes are `Logex.Configuration.Edit.accept/3`'s, raised in the
  caller.
  """
  def accept(runner, candidate) do
    {edits, runtime, elapsed} = call(runner, :resource)
    accepting(Edit.accept(runtime, candidate, elapsed), edits, runner, candidate)
  end

  defp accepting({:ok, edit, forecast}, edits, runner, candidate),
    do: held(call(runner, {:accept, edits, edit, forecast}), runner, candidate)

  defp accepting(refused, _edits, _runner, _candidate), do: refused

  defp held(:stale, runner, candidate), do: accept(runner, candidate)
  defp held(reply, _runner, _candidate), do: reply

  @doc """
  Runs the candidate of the edit the runner holds, from accept or after an untest, as
  `Logex.Configuration.Edit.test/3` does, between two rounds, at the time since the last
  round (decision 139): `{:ok, report}`, the next round running the resource it
  switched. A runner that holds no edit, and a step its
  stage refuses, are the host's mistakes.
  """
  def test(runner), do: call(runner, {:edit, :test})

  @doc """
  Runs the original again, from test, as `Logex.Configuration.Edit.untest/3` does at the
  time since the last round, as `test/1` does: `{:ok, report}`.
  """
  def untest(runner), do: call(runner, {:edit, :untest})

  @doc """
  Keeps the candidate, from test, and ends the edit, as
  `Logex.Configuration.Edit.assemble/2` does: `{:ok, report}`, the runner running the
  candidate from now on.
  """
  def assemble(runner), do: call(runner, {:edit, :assemble})

  @doc """
  Keeps the original and ends the edit, from accept or after an untest, as
  `Logex.Configuration.Edit.cancel/2` does: `{:ok, report}`.
  """
  def cancel(runner), do: call(runner, {:edit, :cancel})

  @doc """
  Starts a tripped runner again, `:cold` or `:warm`, `:warm` keeping what each program
  retains, in memory, since M6-2, a retained timer resuming from its instance's `now`,
  its last scan's, so the time it stood tripped is not counted, the clock not counting it
  either (decisions 113, 271 and 273): every device's latch released, every device read once, as a
  start reads it (decision 142), each device that went down, or does not answer its
  release, opened again, the resource restarted
  (`Logex.Runtime.restart/2`, which keeps the input image and puts every other global
  back to its initial value), `{:restart, mode}` sent to the subscribers, and the first
  round run at once, on what was read, before it returns, the clock not counting the time
  it was stopped, so that round's elapsed time is 0. `:ok`, or `{:error, {:io_init,
  device, reason}}` for the first device, in device-name order, that cannot be opened or
  whose read fails, the runner left tripped with its first reason and every device that
  answers written 0 once more (decisions 136 and 142); a runner that is running is the
  host's mistake (decision 133). It reads the forces file again first, as every start does
  (decision 127): a force it cannot take is raised here, the runner left tripped. Since
  M6-5 a cold restart of a runner given `retain:` then writes its store, of the resource
  as it restarts it, before it releases or reads any device, so that a crash right after
  it brings back none of what it discarded (decisions 271 and 291): a write that fails
  answers `{:error, {:retain, reason}}`, the runner left tripped as it was, the store as
  it was, every output still 0 and no device released or read; and since decision 317 a
  cold restart a device then refuses writes the store back, after the refusal's zeros,
  with the values the runner still holds, so that the refusal changes nothing on disk or
  in memory, a write-back that fails reported as any failed write and the restart
  answered with the device's reason all the same. A warm restart writes none.
  """
  def restart(runner, mode), do: call(runner, {:restart, mode!(mode)})

  defp mode!(mode) when mode in [:cold, :warm], do: mode

  defp mode!(other),
    do: raise(ArgumentError, "a runner restarts :cold or :warm, got: #{inspect(other)}")

  # A proper list of kinds, each one of the seven: an improper list is told as any other
  # that is not one, before a subtraction that cannot take it.
  defp kinds!(kinds) when is_list(kinds), do: proper_kinds!(List.improper?(kinds), kinds)
  defp kinds!(other), do: raise(ArgumentError, kinds_told(other))

  defp proper_kinds!(false, kinds), do: kinds!(kinds -- @kinds, kinds)
  defp proper_kinds!(true, kinds), do: raise(ArgumentError, kinds_told(kinds))

  defp kinds!([], kinds), do: kinds
  defp kinds!(_unknown, kinds), do: raise(ArgumentError, kinds_told(kinds))

  defp kinds_told(kinds),
    do:
      "a runner's events are subscribed by a list of their kinds, among :overlap, :fault, " <>
        ":trip, :restart, :edit, :retain, :ran and :round, got: #{inspect(kinds)}"

  # A host's call, a mistake in it raised here, in the caller; and a runner that goes down
  # before it answers, stopped as its call waited for whatever reason the stop gave, or
  # gone before it, is one that is not running: the call never waits, so its exit can only
  # be the runner's going down.
  defp call(runner, request), do: relayed(asked(runner!(runner), request))

  defp asked(runner, request) do
    GenServer.call(runner, request, :infinity)
  catch
    :exit, {_reason, {GenServer, :call, _args}} -> gone(runner)
  end

  defp gone(runner), do: {:raise, ArgumentError.exception(not_running(runner))}

  defp not_running(runner), do: "the runner #{inspect(runner)} is not running"

  defp relayed({:raise, exception}), do: raise(exception)
  defp relayed(reply), do: reply

  # The devices are opened, and the first round run, inside init/1, so that nothing a
  # host sends, a call or a stop by the runner's name, is handled before they are: it
  # waits in the mailbox until they are open. A device that cannot be opened is init/1's
  # {:error, reason}, which start_link/1 returns, the runner exiting normally, so that
  # its link does not kill the caller.
  @impl GenServer
  def init(start) do
    Process.flag(:trap_exit, true)
    opening(start.devices, [], [], start)
  end

  # A device's changes, by address, from that device's own process: merged into the next
  # round's inputs, and each change of an event task's trigger its own round, in address
  # order, answered once each has run and its outputs are written (decisions 120 and
  # 124), whatever the share. A change read before the last restart, which may wait in
  # the mailbox behind the restart, is stale, answered `:stale` and taken as nothing: the
  # device gave its readings with the restart's own read, which supersedes them for the
  # points it gives, or passes them on again after a refused restart (decision 142).
  @impl GenServer
  def handle_call(
        {:changes, device, restarts, changes},
        {pid, _tag},
        %{pids: pids, restarts: restarts} = state
      )
      when :erlang.map_get(device, pids) == pid do
    vetted = vetted(device, changes, state)
    {:reply, took(vetted), changed(device, vetted, state)}
  end

  def handle_call({:changes, device, _stale, _changes}, {pid, _tag}, %{pids: pids} = state)
      when :erlang.map_get(device, pids) == pid,
      do: {:reply, :stale, state}

  # A host's request is the runner's own work: served at once where no round is owed, and
  # otherwise queued for the share's slot (decision 122).
  def handle_call(request, from, state),
    do: {:noreply, requested(owed?(state), {from, request}, state)}

  # The device's answer: a change taken, or one refused, which the device passes on again
  # at its next read (decision 114), its other points with its next reading (decision
  # 143); a restart reads every device whole (decision 142).
  defp took({:ok, _changes}), do: :ok
  defp took({:fault, cause}), do: {:error, cause}

  @impl GenServer
  def handle_info({__MODULE__, :wake, token}, %{wake: {_timer, token, at}} = state),
    do: {:noreply, woken(state, at)}

  def handle_info({__MODULE__, :wake, _stale}, state), do: {:noreply, state}

  # A device's notice, from its own process: it has latched on its deadline (decision
  # 125), or its own callback failed (decision 114), which trips the runner. A notice from
  # a process that is no longer its device's is passed over, and so is one raised before
  # the device answered the last restart's release (see noticed/2).
  def handle_info({Device, _pid, _restarts, _at, _notice} = notice, state),
    do: {:noreply, noticed([notice], state)}

  # A device's process gone down, which the runner traps: an I/O fault (decision 114), the
  # device opened again at the next restart. One it killed, or that stopped as it was
  # closed, is already none of its devices.
  def handle_info({:EXIT, pid, reason}, %{retain: %{period: %{writer: pid}}} = state),
    do: {:noreply, writer_down(state, reason)}

  def handle_info({:EXIT, pid, reason}, state), do: {:noreply, exited(pid, reason, state)}

  # M6-6: the writer's answer to the period's write it was handed (decision 275).
  def handle_info({Writer, pid, at, result}, %{retain: %{period: %{writer: pid}}} = state),
    do: {:noreply, period_written(state, at, result)}

  # M6-5: the caller of stop/2, named before its stop, answered as the runner terminates.
  def handle_info({__MODULE__, :stopping, pid, ref}, state),
    do: {:noreply, %{state | stoppers: [{pid, ref} | state.stoppers]}}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
    do: {:noreply, %{state | subscribers: Map.delete(state.subscribers, pid)}}

  # Anything else sent to the runner is no request of its, and changes nothing: a message
  # or a cast, and a call, which is answered as a host's mistake (see serve/2).
  def handle_info(_other, state), do: {:noreply, state}

  @impl GenServer
  def handle_cast(_other, state), do: {:noreply, state}

  # A stop: each host's request still waiting answered as one to a runner that is not
  # running, raised in its caller, and then every output written 0 once and every device
  # closed, in device-name order (decision 116), a latched device's 0 tried once more where
  # its adapter has not taken it (decision 286, in the device's close).
  # Since M6-5 a stop/2's then writes the store, where one is named, of the resource as the
  # stop found it, its outputs 0 and its devices closed first, so that no store write keeps
  # an output on, and answers its caller, `:ok` or `{:error, {:retain, reason}}` (decisions
  # 116 and 275); since decision 316 an orderly shutdown from the runner's parent, a
  # supervisor's `:shutdown` or a `{:shutdown, term}`, which the runner sees here as it
  # traps exits, writes it the same way, after the same zeros and closes, a failure
  # reported to the subscribers, and so, since decision 327, does one from any process,
  # and since decision 328 a `:normal` exit, its parent's or a `GenServer.stop/3`'s; a
  # runner that terminates for any other reason writes none, as one that crashes or is
  # killed (decision 292), its clock gone among them, the runner's own exit,
  # `{:shutdown, {:clock, reason}}`, told by its reason.
  @impl GenServer
  def terminate(reason, %{queue: queue} = state) do
    for {from, _request} <- :queue.to_list(queue),
        do: GenServer.reply(from, gone(self()))

    state = each_live(state, &Device.close/2)
    answered_stop(stoppers(state.stoppers), reason, state)
    writer_stopped(state)
    :ok
  end

  defp stoppers(named) do
    receive do
      {__MODULE__, :stopping, pid, ref} -> stoppers([{pid, ref} | named])
    after
      0 -> named
    end
  end

  defp answered_stop([], reason, state), do: shut_down(reason, state)

  defp answered_stop(stoppers, _reason, state) do
    {reply, _state} = kept_store(state, state.runtime)
    for {pid, ref} <- stoppers, do: send(pid, {ref, reply})
  end

  # Decisions 316, 327 and 328: every orderly exit writes the store as stop/2 does, a
  # parent's `:normal`, `:shutdown` or `{:shutdown, term}` and a `GenServer.stop/3` with
  # one of them from any process, told by its reason alone; the clock gone, which stops
  # the runner as a shutdown of its own, and every other reason, a crash's, write none
  # (decision 292), as a kill, which runs no terminate/2, does. A clock that goes down
  # while the shutdown writes names no time, so that write is none too. A runner whose
  # devices cannot be opened never reaches here: its init/1 gives `{:error, reason}`, on
  # which a GenServer calls no terminate/2, so it writes nothing.
  defp shut_down({:shutdown, {:clock, _reason}}, _state), do: :ok
  defp shut_down(:normal, state), do: shutdown_store(state)
  defp shut_down(:shutdown, state), do: shutdown_store(state)
  defp shut_down({:shutdown, _term}, state), do: shutdown_store(state)
  defp shut_down(_crash, _state), do: :ok

  defp shutdown_store(state) do
    kept_store(state, state.runtime)
    :ok
  catch
    :exit, {:shutdown, {:clock, _reason}} -> :ok
  end

  defp requested(false, request, state), do: answered(request, refresh(state, :idle))
  defp requested(true, request, state), do: %{state | queue: :queue.in(request, state.queue)}

  # Each request answered; one that took longer than the idle watchdog, served whole,
  # trips the runner once it is answered, `{:watchdog, {:idle, ms}}` (decision 128). A
  # restart is the tripped runner's own, its first round timed by its steps' watchdogs.
  defp answered({from, {:restart, _mode} = request}, state) do
    {reply, state} = served(request, state)
    GenServer.reply(from, reply)
    state
  end

  defp answered({from, request}, state) do
    begun = now(state)
    {reply, state} = served(request, state)
    took = now(state) - begun
    state = kicked(state)
    GenServer.reply(from, reply)
    idled(took, state)
  end

  # A force or unforce that changed what a trigger reads makes a round at once, before its
  # call returns, a force of a trigger being a change of it (decisions 117 and 120); each
  # trigger it changed its own round, in device-name and then address order, as a
  # device's changes are, each round reading the triggers before it at their new values
  # and those after it as they were; each round timed by its steps' watchdogs, not the
  # idle watchdog's.
  defp kicked(%{kick: kick} = state), do: Enum.reduce(kick, %{state | kick: []}, &kick/2)

  defp kick(name, state),
    do: rounded(%{state | pending: Enum.into(Map.take(state.values, [name]), state.pending)})

  defp idled(took, %{status: :running, idle: idle} = state) when took > idle,
    do: tripped(state, {:watchdog, {:idle, took}})

  defp idled(_took, state), do: state

  # Each request, a host's mistake in it given back to be raised in the caller.
  defp served(request, state) do
    serve(request, state)
  rescue
    error in ArgumentError -> {{:raise, error}, state}
  end

  defp serve({:get, path}, %{runtime: runtime} = state), do: {Runtime.get(runtime, path), state}
  defp serve({:get!, path}, %{runtime: runtime} = state), do: {Runtime.get!(runtime, path), state}
  defp serve(:status, state), do: {status_of(state), state}

  defp serve({:subscribe, pid, kinds}, %{subscribers: subscribers} = state) do
    demonitor(Map.get(subscribers, pid))
    {:ok, %{state | subscribers: Map.put(subscribers, pid, {Process.monitor(pid), kinds})}}
  end

  defp serve({:unsubscribe, pid}, %{subscribers: subscribers} = state) do
    demonitor(Map.get(subscribers, pid))
    {:ok, %{state | subscribers: Map.delete(subscribers, pid)}}
  end

  # Forcing (decisions 117 and 127): an input point held at a value, whatever its device
  # says, until it is unforced; each force and unforce writes the whole set to the forces
  # file before it returns, a write that fails changing nothing.
  defp serve({:force, name, value}, state) do
    filed!(state)
    forcing(input(name, state), name, value, state)
  end

  defp serve({:unforce, name}, state) do
    filed!(state)
    unforcing(input(name, state), name, state)
  end

  defp serve(:unforce_all, state) do
    filed!(state)
    kept(state, %{}, Map.keys(state.forces))
  end

  defp serve({:restart, _mode}, %{status: :running}),
    do:
      raise(
        ArgumentError,
        "the runner is running: restart/2 starts a runner again once it has tripped"
      )

  # An edit's steps (§4.11, "Edits"): accept's work is the caller's, against the resource
  # handed it with the count of steps the runner has taken, which the edit it accepted is
  # held by only where no step came between, a second accept superseding the first
  # (decision 66); each other step is taken here, between two rounds, on the edit held.
  defp serve(:resource, state), do: {{state.edits, state.runtime, step_time(state)}, state}

  defp serve({:accept, edits, edit, forecast}, %{edits: edits} = state) do
    published(state, [{:edit, :accept, forecast}])
    {{:ok, forecast}, %{state | edit: edit}}
  end

  defp serve({:accept, _edits, _edit, _forecast}, state), do: {:stale, state}

  defp serve({:edit, step}, %{edit: nil}),
    do:
      raise(
        ArgumentError,
        "the runner holds no edit: #{step}/1 is a step of the edit accept/2 accepts"
      )

  defp serve({:edit, step}, %{edit: edit} = state) when step in [:test, :untest] do
    {edit, runtime, report} = apply(Edit, step, [edit, state.runtime, step_time(state)])
    {{:ok, report}, edited(state, step, edit, Edit.running(edit), runtime, report)}
  end

  defp serve({:edit, step}, %{edit: edit} = state) when step in [:assemble, :cancel] do
    {configuration, runtime, report} = apply(Edit, step, [edit, state.runtime])
    {{:ok, report}, edited(state, step, nil, configuration, runtime, report)}
  end

  # A restart reads the forces file again, as every start does (decision 127): a force it
  # cannot take is raised in the caller, the runner left tripped; a point no longer forced
  # reads its device's last value again.
  defp serve({:restart, mode}, state) do
    forces = read_forces(state.file, state)
    restarting(cold_store(mode, state), mode, forces)
  end

  defp serve(other, _state),
    do:
      raise(
        ArgumentError,
        "Logex.Runner has no request #{inspect(other)}: a runner is called through " <>
          "get/2, get!/2, status/1, subscribe/2, unsubscribe/1, force/3, unforce/2, " <>
          "unforce_all/1, accept/2, test/1, untest/1, assemble/1, cancel/1, restart/2 and " <>
          "stop/2"
      )

  # M6-5 (decisions 271 and 291): a cold restart writes the store, of the resource as the
  # restart will start it, before it releases or reads any device; a write that fails
  # leaves the runner tripped as it was, `{:error, {:retain, reason}}`, the store as it was
  # and every output still 0. A warm restart writes none.
  defp cold_store(_mode, %{retain: nil} = state), do: {:ok, state}
  defp cold_store(:cold, state), do: kept_store(state, Runtime.restart(state.runtime, :cold))
  defp cold_store(:warm, state), do: {:ok, state}

  defp restarting({{:error, _reason}, _state} = failed, _mode, _forces), do: failed

  defp restarting({:ok, state}, mode, forces) do
    unforced = Map.keys(state.forces) -- Map.keys(forces)

    restarted(mode, %{
      state
      | forces: forces,
        pending: Enum.into(Map.take(state.values, unforced), state.pending)
    })
  end

  # A step taken: the edit held, or none once it ends, the resource the step returned,
  # which the next round runs, and, of the configuration it runs, each task's watchdog and
  # its untimed programs, which the rounds read from now on (decision 129); its points,
  # its tasks and its name no edit changes (§4.9); `{:edit, step, report}`
  # sent; and, running, the next round planned again from the last, a task whose interval
  # changed next due where decision 40 moved it, so that no round is lost or added.
  defp edited(state, step, edit, configuration, runtime, report) do
    state =
      %{
        state
        | edit: edit,
          runtime: runtime,
          edits: state.edits + 1
      }
      |> Map.merge(timing(configuration))
      |> longest()

    published(state, [{:edit, step, report}])
    replanned(state)
  end

  # Decision 139: a switch's time, decision 40's `now`, is the step's on the runner's clock,
  # the time since the last round, so that a cut served long after it is counted from the
  # edit, and none while tripped, the clock not counting the time it is stopped.
  defp step_time(%{status: :running, anchor: anchor, logical: logical} = state),
    do: max(now(state) - anchor - logical, 0)

  defp step_time(_tripped), do: 0

  defp replanned(%{status: :running, last: {start, finish, again}} = state),
    do: planned(state, start, finish, state.untimed or again)

  defp replanned(state), do: state

  defp stage(nil), do: nil
  defp stage(edit), do: Edit.stage(edit)

  defp forcing({:ok, type}, name, value, state) do
    fits!(Declarations.fits?(type, value), name, type, value)
    kept(state, Map.put(state.forces, name, forced(type, value)), [name])
  end

  # Decision 241: a located array of input points forced whole, a list of its shape in
  # the elements' order, as a host sets one whole (decision 222), is each element forced,
  # every misfit told, ten and then a count, and nothing forced where one is.
  defp forcing({:array, {_type, _dims, names} = array}, name, value, state) do
    values = elements!(array, name, value)
    kept(state, Map.merge(state.forces, Map.new(Enum.zip(names, values))), names)
  end

  defp forcing({:error, message}, _name, _value, _state), do: raise(ArgumentError, message)

  defp unforcing({:ok, _type}, name, state),
    do: kept(state, Map.delete(state.forces, name), [name])

  # Decision 241: the array named whole unforces every element, forced or not, each
  # reading its device's last value again.
  defp unforcing({:array, {_type, _dims, names}}, _name, state),
    do: kept(state, Map.drop(state.forces, names), names)

  defp unforcing({:error, message}, _name, _state), do: raise(ArgumentError, message)

  # A whole array's list: of its shape, each element a value of its type, held at its
  # nearest; the misfits, ten and then a count, one message.
  defp elements!({_type, dims, _names} = array, name, value),
    do: shaped!(Logex.Array.listed?(value, dims, &(not is_list(&1))), array, name, value)

  defp shaped!(false, {type, dims, _names}, name, value),
    do:
      raise(
        ArgumentError,
        "`#{name}` is #{Declarations.a_type({:array, type, dims})}, forced to a list of " <>
          "#{Logex.Array.shape(dims, "list")} in the elements' order, got: " <>
          inspect(value, charlists: :as_lists)
      )

  defp shaped!(true, {type, dims, names}, name, value) do
    values = List.flatten(value)

    names
    |> Enum.zip(values)
    |> Enum.reject(fn {_element, v} -> Declarations.fits?(type, v) end)
    |> Enum.map(fn {element, v} -> misfit(element, type, v) end)
    |> Logex.Array.capped(&more_misfits(name, {:array, type, dims}, &1))
    |> all_fit!()

    Enum.map(values, &forced(type, &1))
  end

  defp more_misfits(name, array, count),
    do:
      "`#{name}` is #{Declarations.a_type(array)}, with #{count} more " <>
        "#{plural(count, "element")} outside its type, not listed"

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"

  defp all_fit!([]), do: :ok
  defp all_fit!(lines), do: raise(ArgumentError, Enum.join(lines, "\n"))

  defp filed!(%{file: nil}),
    do:
      raise(
        ArgumentError,
        "the runner keeps no forces file, so a force would not survive a crash: start it " <>
          "with forces: a path"
      )

  defp filed!(_state), do: :ok

  # An input point, by its name: `{:ok, type}`, or what the name is instead, told.
  defp input(name, %{types: types} = state) when is_binary(name),
    do: input_of(Map.fetch(types, name), name, state)

  defp input(other, _state),
    do:
      {:error,
       "a force names an input point by its name, a string, as in \"eye_1\", got: " <>
         inspect(other)}

  defp input_of({:ok, type}, _name, _state), do: {:ok, type}

  defp input_of(:error, name, state),
    do: whole_input(Map.fetch(state.arrays, name), name, state)

  # Decision 241: a located array of input points, named whole, `{type, dims, names}`, its
  # elements' type and sizes and each element's name in the elements' order.
  defp whole_input({:ok, array}, _name, _state), do: {:array, array}

  defp whole_input(:error, name, state),
    do: {:error, not_input(Map.fetch(state.located, name), name, state)}

  defp not_input({:ok, {:point, at}}, name, _state),
    do: "`#{name}` is an output point, at `#{at}`: only an input point is forced"

  defp not_input({:ok, {:array, :output, {_first, from}, {_last, to}}}, name, _state),
    do:
      "`#{name}` is an array of output points, `#{from}` to `#{to}`: only an input point " <>
        "is forced"

  defp not_input(:error, name, %{configuration: configuration, types: types} = state),
    do: unheld(element_of(Logex.Array.split(name), state.located), name, {types, configuration})

  defp element_of({array, _subscripts}, located), do: Map.get(located, array)
  defp element_of(nil, _located), do: nil

  # M5-13: an element a located array of input points does not hold, as written.
  defp unheld({:array, :input, {first, _from}, {last, _to}}, name, {_types, configuration}),
    do:
      "`#{name}` is no input point of `#{configuration.name}`: its array is one of input " <>
        "points, each element forced by its name as its subscripts' values, `#{first}` to " <>
        "`#{last}`"

  defp unheld(_other, name, {types, configuration}),
    do: no_input(Map.keys(types), name, configuration)

  defp no_input([], name, configuration),
    do:
      "`#{name}` is no input point of `#{configuration.name}`, which has none: only an " <>
        "input point is forced"

  defp no_input(names, name, configuration),
    do:
      "`#{name}` is no input point of `#{configuration.name}`" <>
        Declarations.suggest(name, Enum.sort(names), & &1, "names")

  # Every located global's point by its name, an element of a located array by its own,
  # `temps[3]`, at its own location, and a located array whole by its name with the range
  # its elements occupy: what a force naming no input point is told.
  defp located(configuration, devices) do
    points =
      for {device, _module, _opts, points} <- devices,
          %Point{name: name, direction: direction, address: address} <- points,
          do: {name, {direction, spelled(device, direction, address)}}

    arrays =
      for %Configuration.Global{name: name, type: {:array, _type, dims}, at: at} <-
            configuration.globals,
          at != nil,
          do: {name, ranged(name, dims, Configuration.location(at))}

    Map.new(for({name, {_direction, at}} <- points, do: {name, {:point, at}}) ++ arrays)
  end

  # Decision 241: each located array of input points, by name, with its elements' type,
  # its sizes and its elements' names in the elements' order, which a force names whole.
  defp input_arrays(configuration),
    do:
      Map.new(
        for %Configuration.Global{name: name, type: {:array, type, dims}, at: at} <-
              configuration.globals,
            {:ok, {_device, "i", fields}} <- [Configuration.location(at)],
            do:
              {name,
               {type, dims,
                for({_, element, _} <- Logex.Array.points(name, dims, fields), do: element)}}
      )

  defp ranged(name, dims, {:ok, {device, io, fields}}) do
    direction = direction(io)
    points = Logex.Array.points(name, dims, fields)
    {_index, first, from} = hd(points)
    {_index, last, to} = List.last(points)

    {:array, direction, {first, spelled(device, direction, from)},
     {last, spelled(device, direction, to)}}
  end

  defp direction("i"), do: :input
  defp direction("q"), do: :output

  defp spelled(device, :input, address), do: Enum.join([device, "i" | address], ".")
  defp spelled(device, :output, address), do: Enum.join([device, "q" | address], ".")

  # M5-10 (decision 166): a real point is forced to the nearest value of its type, as a
  # device's reading is stored, `fan_speed` forced to 16777217 held at 16777216.0.
  defp forced(type, value) when type in [:real, :lreal],
    do: elem(Logex.Real.stored(type, value), 1)

  defp forced(_type, value), do: value

  defp fits!(true, _name, _type, _value), do: :ok
  defp fits!(false, name, type, value), do: raise(ArgumentError, misfit(name, type, value))

  defp misfit(name, type, value), do: misfit_written(name, type, inspect(value))

  defp misfit_written(name, type, spelling),
    do:
      "`#{name}` is #{Declarations.a_type(type)}, forced to #{Declarations.values(type)}, " <>
        "got: " <> spelling

  # The new set of forces, written whole to the file before it is taken (decision 127):
  # a write that fails changes nothing, `{:error, {:forces, reason}}`. Each input point
  # unforced reads its device's last value again; each trigger whose reading changed makes
  # its own round (decision 120), in kicked/1.
  defp kept(state, forces, names),
    do: taken(stored(state.file, forces, state.types), forces, names, state)

  defp taken({:error, reason}, _forces, _names, state), do: {{:error, {:forces, reason}}, state}

  defp taken(:ok, forces, names, state) do
    before = Enum.map(names, &seen(&1, state))
    unforced = Enum.reject(names, &Map.has_key?(forces, &1))

    state = %{
      state
      | forces: forces,
        pending: Enum.into(Map.take(state.values, unforced), state.pending)
    }

    after_ = Enum.map(names, &seen(&1, state))

    kick =
      for(
        {name, was, is} <- Enum.zip([names, before, after_]),
        was != is and MapSet.member?(state.triggers, name),
        do: name
      )
      |> Enum.sort_by(&Map.fetch!(state.places, &1))

    # Each trigger to be kicked read at its new value only from its own round on.
    {:ok, %{state | kick: kick, pending: Map.drop(state.pending, kick)}}
  end

  # What the next round reads at an input point: its force, else its device's change not
  # yet taken, else the input image.
  defp seen(name, %{forces: forces, pending: pending, runtime: runtime}),
    do:
      Map.get_lazy(forces, name, fn ->
        Map.get_lazy(pending, name, fn -> Runtime.get!(runtime, name) end)
      end)

  # The forces file read at a start, `start_link/1`'s in the caller and `restart/2`'s
  # (decision 127): a file that does not exist is no force; one that cannot be read, a
  # line that is no force, a point forced twice, and a force the configuration cannot
  # take are the host's mistakes, every one named, a line each, the runner not started or
  # left tripped.
  defp read_forces(nil, _points), do: %{}
  defp read_forces(path, points), do: forces_read(File.read(path), path, points)

  defp forces_read({:error, :enoent}, _path, _points), do: %{}

  defp forces_read({:error, reason}, path, _points),
    do:
      raise(
        ArgumentError,
        "#{path}: the forces file cannot be read: #{:file.format_error(reason)}"
      )

  defp forces_read({:ok, text}, path, points) do
    {forces, _lines, problems} =
      text
      |> String.split("\n")
      |> unended()
      |> Enum.with_index(1)
      |> Enum.reduce({%{}, %{}, []}, &force_line(&1, &2, points))

    forces_taken(Enum.reverse(problems), path, forces)
  end

  # The text after the last newline, empty in a file the runner wrote, is no line.
  defp unended(lines), do: unended(List.last(lines), lines)
  defp unended("", lines), do: Enum.drop(lines, -1)
  defp unended(_last, lines), do: lines

  defp force_line({text, line}, acc, points),
    do: force_read(parsed(String.split(text, " ")), text, line, acc, points)

  # M5-10 (decision 156): a value is one number, and since decision 218 any number the
  # lexer reads as one literal, decision 149's forms among them, `37.50`, `3.75e1`, `16#ff`
  # or `1_000`, for a real point and since decision 226 for every point.
  # The value is the number's text and nothing else, so a comment or a tab the lexer would
  # pass over, `1//c` or `1\t`, is no force, as before decision 218 (M5-11's review). Since
  # decision 241 a located array of input points is forced whole on one line, its name and
  # then one value an element in the elements' order, each separated by one space,
  # `zone_t 20.0 21.5 …`, which the runner keeps, and writes back, element by element.
  defp parsed([name, value]), do: one_value(value(value), name)
  defp parsed([name, _, _ | _] = parts), do: values(Enum.map(tl(parts), &value/1), name, [])
  defp parsed(_parts), do: :error

  defp one_value({:ok, number}, name), do: {:ok, name, number}
  defp one_value(:error, _name), do: :error

  defp values([], name, numbers), do: {:ok, name, {:list, Enum.reverse(numbers)}}
  defp values([{:ok, number} | rest], name, numbers), do: values(rest, name, [number | numbers])
  defp values([:error | _rest], _name, _numbers), do: :error

  defp value(text), do: Logex.Retain.number(text)

  defp no_force,
    do: "is no force: a line holds an input point's name and its value, as `eye_1 1`"

  defp force_read(:error, text, line, {forces, lines, problems}, _points),
    do: {forces, lines, [{line, "`#{text}` " <> no_force()} | problems]}

  # A line of several values naming no located array is no force, as before decision 241,
  # and an array of output points is told what it is.
  defp force_read({:ok, name, {:list, _}}, text, line, {forces, lines, problems}, points)
       when not is_map_key(points.located, name),
       do: {forces, lines, [{line, "`#{text}` " <> no_force()} | problems]}

  defp force_read({:ok, name, value}, text, line, acc, points),
    do: read_point(input(name, points), {name, value, text}, line, acc)

  # A line's point: an input point's, or, since decision 241, each element of a located
  # array of input points named whole; a line with more than one value names such an array.
  defp read_point({:ok, _type}, {_name, {:list, _}, text}, line, {forces, lines, problems}),
    do: {forces, lines, [{line, "`#{text}` " <> no_force()} | problems]}

  defp read_point({:ok, _type} = point, {name, value, text}, line, acc),
    do:
      once(
        first_line([name], acc),
        [name],
        line,
        acc,
        force_problem(point, name, value, written(text))
      )

  defp read_point({:array, {_type, _dims, names}} = point, {name, value, text}, line, acc),
    do:
      once(
        first_line(names, acc),
        names,
        line,
        acc,
        force_problem(point, name, value, written(text))
      )

  # A point forced twice is told so before its value is judged, as before decision 241.
  defp read_point({:error, message}, {name, _value, _text}, line, acc),
    do: once(first_line([name], acc), [name], line, acc, [message])

  # M5-14's review: each value as the line writes it, after its name, which a misfit
  # quotes as decision 202 quotes a literal, `2#10` and `1.0e-400` as written, and since
  # decision 255 beside the value read where that differs.
  defp written(text), do: tl(String.split(text, " "))

  # A point forced on an earlier line, the first of the line's points that is.
  defp first_line(names, {_forces, lines, _problems}),
    do: Enum.find_value(names, &forced_on(&1, Map.fetch(lines, &1)))

  defp forced_on(name, {:ok, line}), do: {name, line}
  defp forced_on(_name, :error), do: nil

  defp once({name, first}, _names, line, {forces, lines, problems}, _problem),
    do: {forces, lines, [{line, "`#{name}` is forced on line #{first} already"} | problems]}

  defp once(nil, names, line, {forces, lines, problems}, problem),
    do:
      taken_from_file(
        problem,
        line,
        {forces, Enum.reduce(names, lines, &Map.put_new(&2, &1, line)), problems}
      )

  # Decision 218: a real point's line holds any number that is a value of its type, held
  # at its nearest, as `force/3` holds one, `fan_hz 37.50` as 37.5 and `big 3` as 3.0, the
  # next force or unforce writing the file again in the runner's spelling; and since
  # decision 226 so does an integer or bool point's, any integer the lexer reads as one
  # literal, `eye_1 01` as 1 and `level 16#ff` as 255, held to its type, one outside it
  # refused and a real told it does not fit, the next force writing it in plain decimal.
  defp force_problem({:ok, type}, name, value, [spelling]) when type in [:real, :lreal],
    do: real_force(Declarations.fits?(type, value), name, type, {value, spelling})

  defp force_problem({:ok, type}, name, value, [spelling]),
    do: fitting_force(Declarations.fits?(type, value), name, type, {value, spelling})

  # Decision 241: a whole array's line holds one value an element, each judged as its
  # point's, every misfit a line, ten and then a count.
  defp force_problem({:array, {type, dims, names}}, name, {:list, values}, spellings)
       when length(values) == length(names) do
    misfits =
      [names, values, spellings]
      |> Enum.zip()
      |> Enum.reject(fn {_element, v, _spelling} -> Declarations.fits?(type, v) end)
      |> Enum.map(fn {element, v, spelling} -> misfit_read(element, type, {v, spelling}) end)
      |> Logex.Array.capped(&more_misfits(name, {:array, type, dims}, &1))

    whole_force(misfits, names, Enum.map(values, &forced(type, &1)))
  end

  defp force_problem({:array, {type, dims, names}}, name, value, _spellings),
    do: [
      "`#{name}` is #{Declarations.a_type({:array, type, dims})}, forced whole on one line, " <>
        "its name and then #{length(names)} values in the elements' order: the line holds " <>
        "#{count_of(value)}"
    ]

  defp whole_force([], names, values), do: {:take, Enum.zip(names, values)}
  defp whole_force(misfits, _names, _values), do: misfits

  defp count_of({:list, values}), do: "#{length(values)}"
  defp count_of(_one), do: "1"

  defp real_force(true, name, type, {value, _}), do: {:take, [{name, forced(type, value)}]}
  defp real_force(false, name, type, read), do: [misfit_read(name, type, read)]

  defp fitting_force(true, name, _type, {value, _}), do: {:take, [{name, value}]}

  defp fitting_force(false, name, type, read), do: [misfit_read(name, type, read)]

  # Decision 255: a forces file's misfit quoted as its line writes it and as it is read,
  # "got: 16#ffffffff, which is 4294967295", once where the two are one text, `37.5` at an
  # int point, as a line that holds no number is quoted as written, "is no force".
  defp misfit_read(name, type, {value, spelling}),
    do: misfit_written(name, type, written_and_read(spelling, inspect(value)))

  defp written_and_read(same, same), do: same
  defp written_and_read(spelling, read), do: "#{spelling}, which is #{read}"

  defp taken_from_file({:take, taken}, _line, {forces, lines, problems}),
    do: {Enum.into(taken, forces), lines, problems}

  defp taken_from_file(misfits, line, {forces, lines, problems}),
    do: {forces, lines, Enum.reduce(misfits, problems, &[{line, &1} | &2])}

  defp forces_taken([], _path, forces), do: forces

  defp forces_taken(problems, path, _forces),
    do:
      raise(
        ArgumentError,
        Enum.map_join(problems, "\n", fn {line, problem} ->
          "#{path}: line #{line}: #{problem}"
        end)
      )

  # The forces file, written whole: one force a line, `name value`, in name order, to a file
  # beside it, flushed to the disk and renamed over it, so that a crash at any moment leaves
  # the old set or the new (decision 127); a write that fails leaves the file as it was.
  defp stored(path, forces, types),
    do:
      Logex.Retain.written(
        path,
        for(
          {name, value} <- Enum.sort(forces),
          do: [name, ?\s, spelled_force(Map.fetch!(types, name), value), ?\n]
        )
      )

  # M5-10 (decision 156): a real's value in the shortest text that reads back to it, a
  # single's for a `real`, `0.1` and never `0.10000000149011612`.
  defp spelled_force(type, value) when type in [:real, :lreal],
    do: Logex.Real.spelled(type, value)

  defp spelled_force(_type, value), do: Integer.to_string(value)

  defp demonitor(nil), do: :ok
  defp demonitor({ref, _kinds}), do: Process.demonitor(ref, [:flush])

  defp status_of(state),
    do: %{
      status: state.status,
      now: state.logical,
      rounds: state.rounds,
      trip: state.trip,
      overlaps: Runtime.overlaps(state.runtime),
      forces: state.forces,
      edit: stage(state.edit),
      runs: Map.new(state.longest, fn {task, ms} -> {task, {ms, watchdog(task, state)}} end),
      latest_wake: state.latest_wake,
      refresh_gap: state.refresh_gap,
      unzeroed: Enum.sort(state.unzeroed),
      retain: shown_store(state.retain)
    }

  # Each event of a kind its subscriber named, sent, never awaited.
  defp published(%{subscribers: subscribers}, events),
    do:
      for(
        {pid, {_ref, kinds}} <- subscribers,
        event <- events,
        elem(event, 0) in kinds,
        do: send(pid, {__MODULE__, self(), event})
      )

  # ---- the devices -----------------------------------------------------------------------

  # Each device opened in device-name order, its process linked to the runner, and read
  # once; the first that cannot be opened closes every one opened before it.
  defp opening([{name, module, opts, points} | rest], opened, read, start) do
    {:ok, pid} = device(name, {module, opts}, points, start, 0)

    device = {name, pid, points}
    timeout = start.idle + start.poll
    reading(asked(pid, &Device.open/2, timeout), device, rest, opened, read, start)
  end

  defp opening([], opened, read, start) do
    state = running(Enum.reverse(opened), start)
    first_read(Enum.find_value(read, &misread(&1, state)), read, state)
  end

  # Each device's process, given the count of restarts its notices carry: 0 at the start,
  # and a restart's own for one it opens again.
  defp device(name, {module, opts}, points, start, restarts),
    do:
      Device.start_link(%{
        name: name,
        module: module,
        opts: opts,
        points: points,
        runner: self(),
        clock: start.clock,
        poll: start.poll,
        restarts: restarts
      })

  defp reading({:ok, values}, {name, _pid, _points} = device, rest, opened, read, start),
    do: opening(rest, [device | opened], [{name, values} | read], start)

  defp reading({:error, reason}, {name, _pid, _points}, _rest, opened, _read, start) do
    timeout = start.idle + start.poll

    for {_name, pid, _points} <- Enum.reverse(opened),
        do: asked(pid, &Device.close/2, timeout)

    {:error, {:io_init, name, reason}}
  end

  # The first reads, checked as every change is: a value that does not fit, or an address
  # that is no input point's, is a device that cannot be opened (decision 114).
  defp misread({device, values}, state), do: misfit(vetted(device, values, state), device)

  defp misfit({:ok, _changes}, _device), do: nil
  defp misfit({:fault, cause}, device), do: {device, cause}

  defp first_read(nil, read, state) do
    changes =
      Enum.flat_map(read, fn {device, values} -> elem(vetted(device, values, state), 1) end)

    {:ok, rounded(merged(changes, state))}
  end

  defp first_read({device, cause}, _read, state) do
    each_live(state, &Device.close/2)
    {:error, {:io_init, device, cause}}
  end

  # The runner's state, once its devices are open: the anchor its clock counts from and
  # `logical`, the resource's `now`, the sum of the elapsed_ms it has passed (§4.11); each
  # device with its points, an input point by its device and address and each device's
  # output points by address; the trigger every event task samples that is an input point,
  # whose change a device makes its own round; the next round's inputs, `pending`; what
  # each device was last written; and each task's watchdog.
  defp running(devices, start) do
    points = for {name, _pid, points} <- devices, point <- points, do: {name, point}
    inputs = for {name, %Point{direction: :input} = point} <- points, do: {name, point}
    at = now(start)

    singles =
      MapSet.new(
        for %Configuration.Task{single: single} <- start.configuration.tasks,
            single != nil,
            do: single
      )

    Map.merge(Map.drop(start, [:retain_period, :taker]), %{
      bindings:
        Map.new(start.devices, fn {name, module, opts, _points} -> {name, {module, opts}} end),
      devices: devices,
      pids: Map.new(devices, fn {name, pid, _points} -> {name, pid} end),
      anchor: at,
      logical: 0,
      rounds: 0,
      addresses:
        Map.new(inputs, fn {device, point} ->
          {{device, point.address}, {point.name, point.type}}
        end),
      down: MapSet.new(),
      unzeroed: MapSet.new(),
      heard: Map.new(devices, fn {name, _pid, _points} -> {name, now(start)} end),
      deadline: nil,
      outputs:
        Map.new(devices, fn {name, _pid, points} ->
          {name,
           for(%Point{direction: :output} = point <- points, do: {point.address, point.name})}
        end),
      triggers: MapSet.new(for {_device, point} <- inputs, point.name in singles, do: point.name),
      pending: %{},
      values:
        Map.new(inputs, fn {_device, point} ->
          {point.name, Runtime.get!(start.runtime, point.name)}
        end),
      places: Map.new(inputs, fn {device, point} -> {point.name, {device, point.address}} end),
      kick: [],
      written: %{},
      stoppers: [],
      retain: periodic(start.retain, start.retain_period, start.taker, at)
    })
    |> scheduling(start.configuration)
  end

  # What the rounds' timing reads, once a configuration (decisions 108, 122 and 123):
  # whether it has untimed programs, which run under the continuous task's name, or
  # `:none` where none is declared, `continuous`, nil for none; the share's slots, C ms of
  # rounds and S ms of the runner's own work; the triggers logic writes, each event task's
  # single that is no input point, at their values as the first round finds them; and the
  # count the share keeps, the requests waiting for it, the subscribers with the kinds of
  # event each named, the next round, the one wake, each task's longest run, the latest
  # wake and the longest wait between two refreshes.
  defp scheduling(%{configuration: configuration} = state, %Configuration{tasks: tasks}) do
    state
    |> Map.put(:longest, %{})
    |> Map.merge(timing(configuration))
    |> Map.merge(%{
      slots: slots(state.overhead),
      logic:
        Map.new(
          for(
            %Configuration.Task{single: single} <- tasks,
            single != nil,
            not MapSet.member?(state.triggers, single),
            do: {single, Runtime.get!(state.runtime, single)}
          )
        ),
      used: 0,
      restarts: 0,
      status: :running,
      trip: nil,
      queue: :queue.new(),
      subscribers: %{},
      next_round: nil,
      wake: nil,
      token: 0,
      refreshed: state.anchor,
      refresh_gap: 0,
      latest_wake: 0,
      last: nil,
      edit: nil,
      edits: 0
    })
    |> longest()
  end

  # What the rounds' timing reads of the configuration the resource runs, at the start and
  # again after each step of an edit: whether it has untimed programs, which run under
  # the continuous task's name, or `:none` where none is declared, `continuous`, nil for
  # none; and each task's watchdog (decisions 111 and 129).
  defp timing(%Configuration{tasks: tasks, instances: instances} = configuration) do
    named = Enum.find_value(tasks, :none, &(&1.continuous && &1.name))
    timed = for %Configuration.Task{continuous: false, name: name} <- tasks, do: name
    untimed = Enum.any?(instances, &(&1.task not in timed))

    %{
      untimed: untimed,
      continuous: continuous(untimed, named),
      watchdogs: watchdogs(configuration)
    }
  end

  # Each task's longest run, 0 for one not yet timed, those timed before an edit's step
  # kept.
  defp longest(%{configuration: %Configuration{tasks: tasks}, continuous: continuous} = state),
    do: %{
      state
      | longest:
          Map.merge(
            Map.new(
              for(%Configuration.Task{name: name} <- tasks, do: name) ++ List.wrap(continuous),
              &{&1, 0}
            ),
            state.longest
          )
    }

  # A continuous line that runs no instance times no round: its watchdog then times
  # nothing (decision 111), and a round of timed tasks alone is no round of its.
  defp continuous(false, _named), do: nil
  defp continuous(true, named), do: named

  # The conventional table's slots for a share of p percent: C = max(1, round((100 - p) /
  # p)) ms of the continuous task's rounds, then up to S = max(1, round(p / (100 - p))) ms
  # of the runner's own work, 4 and 1 at 20% (decision 122).
  defp slots(p), do: {max(1, round((100 - p) / p)), max(1, round(p / (100 - p)))}

  # A device's values checked, in address order, each against the device's input points
  # (decision 114): `{:ok, changes}`, each by its global's name, or `{:fault, cause}` for
  # the first address that is no input point's, `{:unknown_address, address}`, or value
  # that does not fit its point, `{:bad_value, address, value}`.
  defp vetted(device, values, state),
    do: Enum.reduce_while(Enum.sort(values), {:ok, []}, &check(device, &1, &2, state))

  defp check(device, {address, value}, {:ok, changes}, state),
    do: fit(Map.fetch(state.addresses, {device, address}), address, value, changes)

  defp fit(:error, address, _value, _changes), do: {:halt, {:fault, {:unknown_address, address}}}

  defp fit({:ok, {name, type}}, address, value, changes),
    do: fitting(Declarations.fits?(type, value), name, address, value, changes)

  defp fitting(true, name, _address, value, changes),
    do: {:cont, {:ok, changes ++ [{name, value}]}}

  defp fitting(false, _name, address, value, _changes),
    do: {:halt, {:fault, {:bad_value, address, value}}}

  # A device's changes, merged into the next round's inputs and kept as each input point's
  # last value from its device, which an unforce puts back (decision 117).
  defp merged(changes, state),
    do: %{
      state
      | pending: Enum.into(changes, state.pending),
        values: Enum.into(changes, state.values)
    }

  defp changed(device, {:fault, cause}, state), do: tripped(state, {:io, device, cause})

  defp changed(_device, {:ok, changes}, state) do
    {triggers, others} = Enum.split_with(changes, &unforced_trigger?(&1, state))

    Enum.reduce(triggers, merged(others, state), &rounded(merged([&1], &2)))
  end

  # A trigger's change makes its round, but not one forced: what the controller reads
  # stays the force's (decision 117).
  defp unforced_trigger?({name, _value}, state),
    do: MapSet.member?(state.triggers, name) and not Map.has_key?(state.forces, name)

  # ---- the rounds ------------------------------------------------------------------------

  # A wake: a round where one is due, and otherwise the refresh a wait makes at least once
  # a poll period. A round's wake that came late is kept in the status, the latest.
  defp woken(state, at) do
    now = now(state)
    wake(due?(state.next_round, now), now - at, state)
  end

  defp due?(nil, _now), do: false
  defp due?(at, now), do: now >= at

  defp wake(true, late, state), do: rounded(%{state | latest_wake: max(state.latest_wake, late)})

  defp wake(false, _late, %{retain: nil} = state),
    do: heard_from(silent(state), state, &scheduled(refresh(&1, :idle)))

  defp wake(false, _late, state),
    do: heard_from(silent(state), state, &scheduled(waited(refresh(&1, :idle))))

  # Decision 122's slots: after C ms of the continuous task's rounds, at the end of the
  # round that completes them, the runner serves its own work for up to S ms, each request
  # whole, before the next round, and goes back to rounds at once where none waits; so on
  # the manual clock a slot comes in the advance that runs that round, never at a later one
  # (decision 131). Only a configuration with untimed programs is served in slots: one
  # without serves its requests whenever it waits (decision 108).
  defp slot(%{untimed: true, used: used, slots: {c, s}, retain: nil} = state) when used >= c do
    state = refresh(state, :idle)
    %{popped(:queue.out(state.queue), now(state) + s, state) | used: 0}
  end

  # M6-6: a runner given a store takes a period due out first in the slot, out of its S ms.
  defp slot(%{untimed: true, used: used, slots: {c, s}} = state) when used >= c do
    state = refresh(state, :idle)
    now = now(state)
    %{popped(:queue.out(state.queue), now + s, period(state, now)) | used: 0}
  end

  defp slot(state), do: state

  # Requests served while the time lasts, each whole, so the last may run over: up to a
  # slot's end, its first served whatever the time, or, after a round, in the rest of a
  # millisecond no round wants.
  defp serving(state, until), do: serve_next(now(state) < until, until, state)

  defp serve_next(false, _until, state), do: state
  defp serve_next(true, until, state), do: popped(:queue.out(state.queue), until, state)

  defp popped({:empty, _queue}, _until, state), do: state

  defp popped({{:value, request}, queue}, until, state),
    do: going_on(answered(request, %{state | queue: queue}), until)

  # A request served may be an edit's step that leaves the configuration with no untimed
  # program, which no slot comes for again: the requests that waited behind it are then
  # served at once, in order, as every request is from now on (decision 108).
  defp going_on(%{untimed: false} = state, _until), do: freely(state)
  defp going_on(state, until), do: serving(state, until)

  # A round is owed where the configuration has untimed programs and its time has come: a
  # host's request then waits for the share's slot.
  defp owed?(%{untimed: true, next_round: at} = state) when at != nil, do: now(state) >= at
  defp owed?(_state), do: false

  # One round: the inputs taken, each step of the cycle run and timed, every device
  # refreshed before each with that step's deadline, its task's watchdog and a poll period
  # from the step's start, and before the write with the idle watchdog's, and each device
  # whose outputs changed written, in device-name order, its answer awaited (decisions
  # 118, 125 and 128). Then the share's count, the next round planned, and the requests
  # that waited served in the rest of the millisecond. A tripped runner runs none
  # (decision 113); an exception out of the core, the cycle's steps, trips it
  # `{:internal, message}`, the resource kept as the last step that finished left it.
  defp rounded(%{status: :tripped} = state), do: state

  # A device's notice that came while the runner was stuck is taken first, so that a
  # runner that comes back after its devices latched trips before it runs anything.
  defp rounded(state) do
    receive do
      {Device, _pid, _restarts, _at, _notice} = notice -> rounded(noticed([notice], state))
    after
      0 -> heard_from(silent(state), state, &a_round/1)
    end
  end

  defp a_round(%{anchor: anchor, logical: logical} = state) do
    start = now(state)
    elapsed = max(start - anchor - logical, 0)
    steps = state.steps

    begun(
      core(fn -> steps.cycle_steps(state.runtime, elapsed, inputs(state)) end),
      start,
      elapsed,
      state
    )
  end

  # A round's inputs: the devices' changes since the last, and every force merged over
  # them, after the input latch, so that a forced input holds against its device (§5,
  # decision 117).
  defp inputs(%{pending: pending, forces: forces}), do: Map.merge(pending, forces)

  defp begun({:internal, _message} = reason, _start, _elapsed, state), do: tripped(state, reason)

  # The resource's clock has moved on and its image taken the inputs, so `logical` and
  # `pending` follow it whatever the round's end.
  defp begun({:ok, {runtime, steps}}, start, elapsed, state) do
    state = %{state | runtime: runtime, logical: state.logical + elapsed, pending: %{}}

    steps
    |> Enum.reduce_while({:ok, state, 0, [], []}, &stepped/2)
    |> computed(start)
  end

  defp stepped({kind, task, _run} = step, {:ok, state, timed, events, times}) do
    begun = now(state)
    state = refresh(state, begun, watchdog(task, state))
    steps = state.steps

    stepped(
      core(fn -> steps.cycle_step(state.runtime, step) end),
      kind,
      task,
      begun,
      {state, timed, events, times}
    )
  end

  defp stepped({:internal, _message} = reason, _kind, _task, _begun, {state, _, events, _}),
    do: {:halt, {:trip, reason, state, events}}

  # A step that ran, timed and checked: a timed task's run that outlasts its watchdog trips
  # before the round's write, naming it (decision 110); the continuous task's programs are
  # its round's, checked as the round ends (decision 111). Since M5-9 a step whose run met a
  # major fault trips at its end, before the round's write and before any later step of
  # the round, naming the first, `{:fault, task, instance, fault}` (decisions 153 and 160),
  # the step's own run having scanned every instance it holds; a step that met one and
  # outlasted its watchdog too is tripped for the fault, which came first (provisional).
  defp stepped({:ok, {runtime, ran}}, kind, task, begun, {state, timed, events, times}) do
    took = now(state) - begun
    state = ran(%{state | runtime: runtime}, task, took)
    events = Enum.reverse(ran, events)
    limit = watchdog(task, state)

    checked(
      major(ran),
      kind == :timed and took > limit,
      {:watchdog, {:task, task, took, limit}},
      {:ok, state, timed + timed(kind, took), events, [{task, took} | times]}
    )
  end

  defp checked(nil, over, reason, acc), do: checked(over, reason, acc)
  defp checked(fault, _over, _reason, acc), do: checked(true, fault, acc)

  # The first major fault among a step's events, as the trip's reason, or nil.
  defp major([]), do: nil
  defp major([{:fault, _task, _instance, %Fault{severity: :major}} = fault | _events]), do: fault
  defp major([_event | events]), do: major(events)

  defp checked(false, _reason, acc), do: {:cont, acc}

  defp checked(true, reason, {:ok, state, _timed, events, _times}),
    do: {:halt, {:trip, reason, state, events}}

  # A round that tripped is published as far as it ran, and then its trip; one whose
  # steps all ran is timed against the continuous task's watchdog, from its start to the
  # end of its last program's scan, the timed tasks' runs in it included, its trip naming
  # each step with its time (decisions 111 and 126), and its outputs computed and written.
  defp computed({:trip, reason, state, events}, _start) do
    published(state, Enum.reverse(events))
    tripped(state, reason)
  end

  defp computed({:ok, state, timed, events, times}, start) do
    took = now(state) - start
    state = ran(state, state.continuous, took)
    over(round_over(state.continuous, took, times, state), {state, timed, events}, start)
  end

  defp round_over(nil, _took, _times, _state), do: nil

  defp round_over(task, took, times, state),
    do: round_over(took > watchdog(task, state), task, took, times, state)

  defp round_over(false, _task, _took, _times, _state), do: nil

  defp round_over(true, task, took, times, state),
    do: {:watchdog, {:round, task, took, watchdog(task, state), Enum.reverse(times)}}

  defp over(nil, {state, timed, events}, start) do
    steps = state.steps
    outputs(core(fn -> steps.cycle_outputs(state.runtime) end), start, timed, events, state)
  end

  defp over(reason, {state, _timed, events}, _start),
    do: computed({:trip, reason, state, events}, nil)

  defp outputs({:internal, _message} = reason, _start, _timed, events, state),
    do: computed({:trip, reason, state, events}, nil)

  defp outputs({:ok, outputs}, start, timed, events, state),
    do: delivered(written(refresh(state, :idle), outputs), outputs, start, timed, events)

  defp delivered({:trip, reason, state}, _outputs, _start, _timed, events),
    do: computed({:trip, reason, state, events}, nil)

  defp delivered({:ok, state}, outputs, start, timed, events) do
    finish = now(state)
    {logic, again} = logic(state)

    state = %{
      state
      | rounds: state.rounds + 1,
        logic: logic,
        used: used(state, finish - start - timed),
        last: {start, finish, again}
    }

    published(state, Enum.reverse(events, [{:round, state.logical, outputs}]))

    state
    |> planned(start, finish, state.untimed or again)
    |> slot()
    |> freely()
  end

  # The core called, an exception out of it given back as the trip it causes: it cannot
  # happen through the host contract, so tripping rather than crashing keeps the state for
  # diagnosis, and zeroes the outputs either way (§4.11).
  defp core(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:internal, Exception.message(exception)}
  catch
    kind, reason -> {:internal, Exception.format_banner(kind, reason)}
  end

  # ---- the trip and the restart ----------------------------------------------------------

  # Every notice waiting is taken with the first, and each acted on in the order of the
  # time on the runner's clock its device raised it, ties in device-name order: the trip
  # names the first, so that two devices that latch in one millisecond, whose notices
  # come in whichever order their processes ran, trip the runner for one reason, the same
  # on every run on the manual clock. Every notice taken is acted on before the trip, which
  # may serve a host's restart that waited: so that none taken with it is acted on after
  # that restart, a "back" among them, which would leave its device unheard as the
  # restart's first round begins.
  #
  # Each notice carries the count of restarts its device had heard as it raised it, the
  # count its last release, or its opening, gave it: one raised before the last restart's
  # release, which may wait in the mailbox behind a restart served inside the trip it
  # raced, or be taken with the notice that made that trip, never trips the restarted
  # runner. A "back" is a fact whenever it was raised, so it counts whatever its count.
  defp noticed(taken, state) do
    receive do
      {Device, _pid, _restarts, _at, _notice} = notice -> noticed([notice | taken], state)
    after
      0 ->
        taken
        |> Enum.reverse()
        |> Enum.sort_by(fn {Device, _pid, _restarts, at, {_kind, name, _detail}} ->
          {at, name}
        end)
        |> Enum.reduce({state, nil}, &notice/2)
        |> tripped_by()
    end
  end

  defp notice({Device, pid, _restarts, at, {:back, name, nil}}, {%{pids: pids} = state, trip})
       when :erlang.map_get(name, pids) == pid,
       do: {%{state | heard: Map.put(state.heard, name, at)}, trip}

  # Decision 262: a latched device's 0 taken at last, by a poll's write of it.
  defp notice(
         {Device, pid, restarts, _at, {:zeroed, name, nil}},
         {%{pids: pids, restarts: restarts} = state, trip}
       )
       when :erlang.map_get(name, pids) == pid,
       do: {%{state | unzeroed: MapSet.delete(state.unzeroed, name)}, trip}

  defp notice({Device, _pid, _restarts, _at, {:zeroed, _name, nil}}, acc), do: acc

  defp notice(
         {Device, pid, restarts, _at, {_kind, name, _detail} = notice},
         {%{pids: pids, restarts: restarts} = state, nil}
       )
       when :erlang.map_get(name, pids) == pid,
       do: {state, reason(notice)}

  defp notice(_notice, acc), do: acc

  defp tripped_by({state, nil}), do: state
  defp tripped_by({state, reason}), do: tripped(state, reason)

  # A device hung inside its own adapter (decision 114): one that has told the runner it is
  # back from its adapter, after a read or a report or by answering a round's write in
  # time, within the idle watchdog and a poll period, the time the runner gives any call
  # of its own to a device, is heard; the first in device-name order that has not, checked
  # as a round begins and at each wait's refresh, both while running, when no device is
  # down, is killed, its outputs left to what it does on losing its master, and trips the
  # runner `{:io, device, :timeout}`, the trip's zero finding it down.
  defp silent(%{devices: devices, heard: heard, idle: idle, poll: poll} = state) do
    now = now(state)

    Enum.find_value(devices, fn {name, pid, _points} ->
      now - Map.fetch!(heard, name) > idle + poll && {name, pid}
    end)
  end

  defp heard_from(nil, state, go), do: go.(state)

  defp heard_from({name, pid}, state, _go) do
    Process.exit(pid, :kill)
    tripped(state, {:io, name, :timeout})
  end

  defp reason({:latched, name, ms}), do: {:watchdog, {:device, name, ms}}
  defp reason({:fault, name, cause}), do: {:io, name, cause}

  # A device's process down: marked so, to be opened again at a restart, and the trip.
  defp exited(pid, reason, state), do: exited(device_of(pid, state), pid, reason, state)

  defp exited(nil, _pid, _reason, state), do: state

  defp exited(name, _pid, reason, state),
    do: tripped(went_down(name, state), {:io, name, {:down, reason}})

  defp device_of(pid, state),
    do:
      Enum.find_value(state.devices, fn {name, device, _} ->
        device == pid and live(name, state)
      end)

  defp live(name, %{down: down}), do: not MapSet.member?(down, name) and name

  # Decision 287: a device that goes down while the runner is tripped is named in status/1's
  # `unzeroed` until a restart opens it again, though its 0 was taken, as one down at the
  # trip is, since nothing reaches its outputs now; one that goes down while running is
  # named by the trip's zero it causes.
  defp went_down(name, %{status: :tripped} = state),
    do: %{state | down: MapSet.put(state.down, name), unzeroed: MapSet.put(state.unzeroed, name)}

  defp went_down(name, state), do: %{state | down: MapSet.put(state.down, name)}

  # A call to a device's process, answered within `timeout` ms: one that does not answer
  # in time is killed, `{:error, :timeout}`, and one that goes down meanwhile is
  # `{:error, {:down, reason}}` (decisions 114 and 125).
  defp asked(pid, call, timeout) do
    call.(pid, timeout)
  catch
    :exit, {:timeout, _call} ->
      Process.exit(pid, :kill)
      {:error, :timeout}

    :exit, {reason, _call} ->
      {:error, {:down, reason}}
  end

  # Each device whose process is up, in device-name order, called with the runner's own
  # time to answer, the idle watchdog and a poll period (decision 128); one that does not
  # answer is marked down.
  defp each_live(state, call) do
    timeout = state.idle + state.poll

    Enum.reduce(state.devices, state, fn {name, pid, _points}, state ->
      each_device(MapSet.member?(state.down, name), name, pid, call, timeout, state)
    end)
  end

  defp each_device(true, _name, _pid, _call, _timeout, state), do: state

  defp each_device(false, name, pid, call, timeout, state),
    do: device_answered(asked(pid, call, timeout), name, state)

  defp device_answered(:ok, _name, state), do: state

  # Decision 262: a device whose trip's 0 its adapter did not take.
  defp device_answered(:unzeroed, name, state),
    do: %{state | unzeroed: MapSet.put(state.unzeroed, name)}

  defp device_answered({:error, _reason}, name, state), do: went_down(name, state)

  # A trip's one path, whatever caused it (decision 113): scheduling stopped, its wake
  # cancelled and any that comes stale; every output written 0 once, through each device,
  # in device-name order, which latches; `{:trip, reason}` sent to the subscribers; and the
  # host's requests that waited answered, every one from now on served at once. The
  # resource is kept as the last round computed it, for get/2.
  defp tripped(%{status: :tripped} = state, _reason), do: state

  defp tripped(state, reason) do
    cancel(state.wake, state.clock)
    state = %{state | status: :tripped, trip: reason, wake: nil, next_round: nil, written: %{}}
    state = zeroed(state)
    published(state, [{:trip, reason}])
    {_written, state} = kept_store(state, state.runtime)
    drained(:queue.out(state.queue), state)
  end

  defp drained({:empty, _queue}, state), do: state

  defp drained({{:value, request}, queue}, state) do
    state = answered(request, %{state | queue: queue})
    drained(:queue.out(state.queue), state)
  end

  # M6-5 (decisions 275 and 276): the store written whole, where one is named, of
  # `runtime`'s retained image at the host's wall clock's time, synchronously, as the
  # forces file is; a write that fails is reported, `{:retain, {:error, reason}}` to the
  # subscribers and `failed` in `status/1`'s `retain`, the store as it was, and given back
  # as `{:error, {:retain, reason}}`.
  defp kept_store(%{retain: nil} = state, _runtime), do: {:ok, state}

  defp kept_store(%{retain: retain} = state, runtime) do
    state = drained_writer(state)
    at = wall(state.clock)
    text = Logex.Retain.encode(Runtime.retained(runtime), at)
    noted(Logex.Retain.written(retain.path, text), at, state)
  end

  defp noted(:ok, at, %{retain: retain} = state),
    do: {:ok, %{state | retain: %{retain | written_at: at, failed: nil}}}

  defp noted({:error, reason}, _at, %{retain: retain} = state) do
    published(state, [{:retain, {:error, reason}}])
    {{:error, {:retain, reason}}, %{state | retain: %{retain | failed: reason}}}
  end

  # ---- the period's writes (M6-6, decision 275) -----------------------------------------

  # A runner given a store writes it every `retain_period:` ms, on a grid from its start on
  # its clock, as a periodic task's due times are, a due time passed while it was busy or
  # tripped skipped, never made up (provisional); with no store, nothing. Its writer, a
  # process of its own, is started at the first write it is given.
  defp periodic(nil, nil, _taker, _at), do: nil

  defp periodic(%{path: path} = retain, every, taker, at),
    do:
      Map.put(retain, :period, %{
        path: path,
        every: every,
        from: at,
        next: at + every,
        taker: taker,
        writer: nil,
        busy: false,
        pending: nil
      })

  # The period's state is the store's, under `retain`, so that a runner with no store
  # holds nothing more than before (`status/1` shows the store without it).
  defp put_period(%{retain: retain} = state, period),
    do: %{state | retain: %{retain | period: period}}

  defp shown_store(nil), do: nil
  defp shown_store(retain), do: Map.delete(retain, :period)

  # The next due time after `at`, on the grid.
  defp next_due(%{every: every, from: from}, at), do: from + every * (div(at - from, every) + 1)

  # A restart takes up the grid at its next due time after the restart: a warm one writes
  # nothing of its own, and no due time passed while tripped is made up.
  defp period_from(nil, _at), do: nil

  defp period_from(%{period: periodic} = retain, at),
    do: %{retain | period: %{periodic | next: next_due(periodic, at)}}

  # The period's take-out is the runner's own work, between rounds, never inside one, and
  # it moves no round's due time (decisions 108 and 122, restated for the period,
  # provisional): with untimed programs, first in the share's slot that comes at or after
  # its due time, out of the slot's S ms, before the requests that waited; with none, at
  # the wake of its due time, or just after the round that runs at it or is running then,
  # its outputs written, so that a round owed at that time runs first. While tripped the
  # runner takes none: the trip wrote the resource as it left it. (The trip cancels the
  # runner's wake, so no wake and no round reaches period/2 while tripped, and its
  # `status: :running` is a statement of that rule more than a guard: M6-6's review found
  # its removal an equivalent mutant.)
  defp after_round(%{untimed: false} = state, now), do: period(state, now)
  defp after_round(state, _now), do: state

  defp waited(%{untimed: false} = state), do: period(state, state.refreshed)
  defp waited(state), do: state

  # The period's own wake, where no round or refresh comes sooner: only a runner with no
  # untimed program needs one, the share's slots coming every C ms otherwise.
  defp soonest(round, refresh, %{period: %{next: next}}, false),
    do: earliest(earliest(round, refresh), next)

  defp soonest(nil, refresh, _periodic, _untimed), do: refresh
  defp soonest(round, refresh, _periodic, _untimed), do: min(round, refresh)

  defp period(%{retain: %{period: %{next: next} = periodic}, status: :running} = state, now)
       when now >= next do
    image = periodic.taker.retained(state.runtime)
    at = wall(state.clock)
    handed(put_period(state, %{periodic | next: next_due(periodic, now)}), {at, image})
  end

  defp period(state, _now), do: state

  # The image handed to the writer where it is idle, and otherwise kept until it answers,
  # the newest taken out replacing the one that waited, latest wins.
  defp handed(%{retain: %{period: %{busy: true} = periodic}} = state, write),
    do: put_period(state, %{periodic | pending: write})

  defp handed(%{retain: %{period: periodic}} = state, {at, image}) do
    pid = writer(periodic.writer, periodic.path)
    Writer.write(pid, at, image)
    put_period(state, %{periodic | writer: pid, busy: true})
  end

  defp writer(nil, path) do
    {:ok, pid} = Writer.start_link(path)
    pid
  end

  defp writer(pid, _path), do: pid

  # The writer's answer: a write made is the store's age in `status/1`, one that failed
  # reported as every failed write is, `{:retain, {:error, reason}}` and `failed`, the
  # plant running on; and the image that waited, if any, handed on.
  defp period_written(state, at, result) do
    {_written, state} = noted(result, at, state)
    next_write(put_period(state, %{state.retain.period | busy: false}))
  end

  defp next_write(%{retain: %{period: %{pending: nil}}} = state), do: state

  defp next_write(%{retain: %{period: %{pending: write} = periodic}} = state),
    do: handed(put_period(state, %{periodic | pending: nil}), write)

  # Before a write at an event, a trip, a stop, a shutdown or a cold restart, the
  # writer's write in progress waited for and any pending one dropped, so that the
  # event's write is the last on disk (decision 275). The wait is bounded as a device's
  # close is, by the idle watchdog and a poll period in real time; a writer that has not
  # answered by then is killed, its write reported failed, `:timeout`, the store the old
  # or the new, and a new writer started at the next period (provisional). A writer gone
  # down before it answered, whose exit the runner has not yet handled, is taken as gone at
  # once, its write reported `{:down, reason}` as writer_down/2 reports it, never waited on
  # to its deadline (M6-6's review).
  defp drained_writer(%{retain: %{period: %{busy: true, writer: pid}}} = state) do
    receive do
      {Writer, ^pid, at, result} ->
        {_written, state} = noted(result, at, state)
        idled_writer(state, pid)

      {:EXIT, ^pid, reason} ->
        {_failed, state} = noted({:error, {:down, reason}}, nil, state)
        idled_writer(state, nil)
    after
      state.idle + state.poll -> hung_writer(state, pid)
    end
  end

  defp drained_writer(%{retain: %{period: %{} = periodic}} = state),
    do: put_period(state, %{periodic | pending: nil})

  defp drained_writer(state), do: state

  defp idled_writer(state, pid),
    do: put_period(state, %{state.retain.period | writer: pid, busy: false, pending: nil})

  defp hung_writer(state, pid) do
    killed_writer(pid)
    {_failed, state} = noted({:error, :timeout}, nil, state)
    idled_writer(state, nil)
  end

  defp killed_writer(nil), do: :ok

  defp killed_writer(pid) do
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end

    receive do
      {:EXIT, ^pid, _reason} -> :ok
    after
      0 -> :ok
    end
  end

  # A writer gone down, which the runner traps: the write it held reported failed,
  # `{:down, reason}`, and the image that waited handed to a new one (provisional).
  defp writer_down(%{retain: %{period: %{busy: true}}} = state, reason) do
    {_failed, state} = noted({:error, {:down, reason}}, nil, state)
    next_write(put_period(state, %{state.retain.period | writer: nil, busy: false}))
  end

  defp writer_down(state, _reason),
    do: put_period(state, %{state.retain.period | writer: nil})

  # The writer stopped as the runner terminates, after the stop's or the shutdown's write,
  # which waited for it, or at once where the runner crashed: its write, if any, leaves
  # the old store or the new.
  defp writer_stopped(%{retain: %{period: %{writer: pid}}}), do: killed_writer(pid)
  defp writer_stopped(_state), do: :ok

  # A restart (decision 113): every latch released, a device that does not answer its
  # release killed and marked down, as one that hung or went down while the runner was
  # tripped; every device read once, in device-name order, as a start reads them (decision
  # 142), one down opened again and read as its opening reads it; the resource restarted,
  # which keeps its clock and its input image, the triggers logic writes sampled again,
  # the anchor moved so that the time stopped is not counted, and the first round run at
  # once.
  defp restarted(mode, state) do
    restarts = state.restarts + 1
    state = each_live(%{state | restarts: restarts}, &Device.release(&1, restarts, &2))
    reopened(read_again(state.devices, state), mode)
  end

  defp down?({name, _pid, _points}, state), do: MapSet.member?(state.down, name)

  # Each device read once, its values checked as a start's first reads are: one up read
  # by its process, one down opened again; the first that cannot be read or opened leaves
  # the runner tripped, the restart answered with its reason (decisions 136 and 142).
  defp read_again([], state), do: {:ok, state}

  defp read_again([device | rest], state),
    do: read_device(down?(device, state), device, rest, state)

  defp read_device(true, {name, _old, points}, rest, state) do
    {:ok, pid} = device(name, Map.fetch!(state.bindings, name), points, state, state.restarts)
    timeout = state.idle + state.poll
    reopen_read(asked(pid, &Device.open/2, timeout), name, pid, points, rest, state)
  end

  defp read_device(false, {name, pid, _points}, rest, state) do
    timeout = state.idle + state.poll
    reread(asked(pid, &Device.reread/2, timeout), name, pid, rest, state)
  end

  # A device up, read again: its values checked and, taken, told to the device as what it
  # last passed on, by a cast that comes before anything else the runner sends it, or,
  # refused, its cause told, so that the device drops the refused point's reading and
  # holds the rest, and a read refused leaves nothing in it to hide the same fault at a
  # later read; and
  # its fault, or no answer in time or its process gone down, the restart's answer; one
  # killed for no answer, or gone down, is marked down by its exit, which the runner
  # traps, and so opened again at the next restart.
  defp reread({:ok, values}, name, pid, rest, state),
    do: reread_checked(vetted(name, values, state), values, name, pid, rest, state)

  defp reread({_failed, cause}, name, _pid, _rest, state),
    do: {{:error, {:io_init, name, cause}}, state}

  defp reread_checked({:ok, changes}, values, _name, pid, rest, state) do
    Device.taken(pid, values)
    read_again(rest, merged(changes, state))
  end

  defp reread_checked({:fault, cause}, _values, name, pid, _rest, state) do
    Device.refused(pid, cause)
    {{:error, {:io_init, name, cause}}, state}
  end

  defp reopen_read({:ok, values}, name, pid, points, rest, state),
    do: reopen_checked(vetted(name, values, state), name, pid, points, rest, state)

  defp reopen_read({:error, reason}, name, _pid, _points, _rest, state),
    do: {{:error, {:io_init, name, reason}}, state}

  defp reopen_checked({:ok, changes}, name, pid, points, rest, state) do
    devices = List.keyreplace(state.devices, name, 0, {name, pid, points})

    read_again(rest, %{
      merged(changes, state)
      | devices: devices,
        pids: Map.put(state.pids, name, pid),
        down: MapSet.delete(state.down, name),
        heard: Map.put(state.heard, name, now(state))
    })
  end

  defp reopen_checked({:fault, cause}, name, pid, _points, _rest, state) do
    asked(pid, &Device.close/2, state.idle + state.poll)
    {{:error, {:io_init, name, cause}}, state}
  end

  defp reopened({:ok, state}, mode), do: {:ok, released(mode, state)}

  # A device that cannot be opened leaves the runner tripped, every device that answers
  # latched again, its 0 written once more, as a restart that trips again does: one
  # released and one opened again before it alike. Since decision 317 a cold restart so
  # refused then writes the store back, after those zeros, with the values the runner
  # still holds, the resource as the trip left it, so that the refusal changes nothing on
  # disk or in memory; a write-back that fails is reported as any failed write, and the
  # runner stays tripped either way, the restart answered with the device's reason.
  defp reopened({error, state}, mode), do: {error, written_back(mode, zeroed(state))}

  defp written_back(:cold, state) do
    {_reply, state} = kept_store(state, state.runtime)
    state
  end

  defp written_back(:warm, state), do: state

  # Every device that answers latched, its outputs written 0 once; and since decision 262
  # each device whose outputs are not known to be 0 named, one whose adapter did not take
  # its 0, until a poll's write of it is taken, and one down, which nothing reaches until a
  # restart opens it again.
  defp zeroed(state) do
    state = each_live(%{state | unzeroed: MapSet.new()}, &Device.zero/2)
    %{state | unzeroed: MapSet.union(state.unzeroed, state.down)}
  end

  defp released(mode, state) do
    runtime = Runtime.restart(state.runtime, mode)
    at = now(state)

    state = %{
      state
      | runtime: runtime,
        status: :running,
        trip: nil,
        unzeroed: MapSet.new(),
        anchor: at - state.logical,
        refreshed: at,
        retain: period_from(state.retain, at),
        logic: Map.new(state.logic, fn {name, _value} -> {name, Runtime.get!(runtime, name)} end)
    }

    published(state, [{:restart, mode}])
    rounded(state)
  end

  defp timed(:timed, took), do: took
  defp timed(:untimed, _took), do: 0

  # Each task's longest run, a timed task's step and the continuous task's round.
  defp ran(state, nil, _took), do: state

  defp ran(state, task, took),
    do: %{state | longest: Map.update!(state.longest, task, &max(&1, took))}

  # The share's count: a round of the continuous task's from its start to its end, a
  # millisecond at least, the timed tasks' runs in it left out (decision 122).
  defp used(%{untimed: true, used: used}, took), do: used + max(took, 1)
  defp used(%{used: used}, _took), do: used

  # A trigger logic writes, an event task's single that is no input point: one that a round
  # changed makes the next round at the next millisecond (decision 123).
  defp logic(%{logic: logic, runtime: runtime}) do
    now = Map.new(logic, fn {name, _value} -> {name, Runtime.get!(runtime, name)} end)
    {now, now != logic}
  end

  # The next round: at the millisecond after the one this round began in, or at once where
  # it took a millisecond or more, while untimed programs exist or logic changed a trigger
  # (decisions 122 and 123); at the next periodic due time, on the runner's clock, which
  # counts from `anchor` (§4.11); the earlier, a wake either way.
  defp planned(%{retain: nil} = state, start, finish, again) do
    next =
      earliest(
        back_to_back(again, start, finish),
        due(Runtime.next_due_in(state.runtime), state)
      )

    scheduled(%{state | next_round: next})
  end

  # M6-6: a runner given a store and no untimed program takes a period due out first, its
  # round's outputs written (see after_round/2).
  defp planned(state, start, finish, again) do
    state = after_round(state, finish)

    next =
      earliest(
        back_to_back(again, start, finish),
        due(Runtime.next_due_in(state.runtime), state)
      )

    scheduled(%{state | next_round: next})
  end

  defp back_to_back(false, _start, _finish), do: nil
  defp back_to_back(true, start, finish) when finish > start, do: finish
  defp back_to_back(true, start, _finish), do: start + 1

  defp due(:infinity, _state), do: nil
  defp due(ms, %{anchor: anchor, logical: logical}), do: anchor + logical + ms

  defp earliest(nil, at), do: at
  defp earliest(at, nil), do: at
  defp earliest(one, other), do: min(one, other)

  # The one wake: the next round, or sooner the refresh a wait makes a poll period after
  # the last, its token making any earlier wake stale.
  defp scheduled(%{clock: {module, clock}, token: token} = state) do
    cancel(state.wake, state.clock)
    at = soonest(state.next_round, state.refreshed + state.poll, state.retain, state.untimed)
    token = token + 1

    %{
      state
      | token: token,
        wake:
          {clocked(fn -> module.wake_at(clock, self(), {__MODULE__, :wake, token}, at) end),
           token, at}
    }
  end

  defp cancel(nil, _clock), do: :ok

  defp cancel({timer, _token, _at}, {module, clock}),
    do: clocked(fn -> module.cancel(clock, timer) end)

  # The requests that waited, served while no round is owed, every device refreshed first
  # where one waits, as before any of the runner's own work (decision 125).
  defp freely(%{untimed: true, next_round: at, queue: queue} = state),
    do: free(:queue.is_empty(queue) or now(state) >= at, at, state)

  # With no untimed program no round is owed but for a due time, so every request that
  # waited is served at once, in order: one an edit's step left waiting for a slot that
  # no longer comes among them (decision 108).
  defp freely(%{untimed: false, queue: queue} = state),
    do: free(:queue.is_empty(queue), nil, state)

  defp free(true, _at, state), do: state
  defp free(false, nil, state), do: released(refresh(state, :idle))
  defp free(false, at, state), do: serving(refresh(state, :idle), at)

  # Each served, the next where one waits: a step that brings an untimed program back
  # puts the rest under the share's slots again.
  defp released(state) do
    {{:value, request}, queue} = :queue.out(state.queue)
    freely(answered(request, %{state | queue: queue}))
  end

  defp watchdog(task, %{watchdogs: watchdogs}), do: Map.fetch!(watchdogs, task)

  # Each task's watchdog by its name, the one rule's (decision 110), read once a
  # configuration; the untimed instances' under the continuous task's name, or `:none`
  # where none is declared, 500 ms then (decision 111).
  defp watchdogs(%Configuration{tasks: tasks}),
    do:
      Map.new(
        [%Configuration.Task{name: :none, continuous: true} | tasks],
        &{&1.name, Configuration.watchdog(&1)}
      )

  # Every device refreshed, without a wait, carrying its deadline: a step's, or `:idle`'s,
  # the idle watchdog and a poll period from now (decisions 125 and 128); the longest wait
  # between two refreshes kept for the status.
  defp refresh(state, :idle), do: refresh(state, now(state), state.idle)

  # Every device refreshed at `at`, its deadline `span` and a poll period on: a step's
  # watchdog from its start, or the idle watchdog from now (decisions 125 and 128).
  defp refresh(%{status: :tripped} = state, _at, _span), do: state

  defp refresh(%{devices: devices, refreshed: last} = state, at, span) do
    deadline = at + span + state.poll
    Enum.each(devices, fn {_name, pid, _points} -> Device.refresh(pid, deadline, at) end)
    now = now(state)
    %{state | refreshed: now, deadline: deadline, refresh_gap: max(state.refresh_gap, now - last)}
  end

  # Each device whose outputs changed written, in device-name order, its answer awaited
  # within the deadline its last refresh carried: a write that fails, or answers late, is
  # an I/O fault, and the devices after it are not written (decision 114).
  defp written(%{devices: devices} = state, outputs),
    do:
      Enum.reduce_while(devices, {:ok, state}, fn device, {:ok, state} ->
        write(device, state, outputs)
      end)

  defp write({name, pid, _points}, state, outputs) do
    values =
      Map.new(Map.fetch!(state.outputs, name), fn {address, global} ->
        {address, Map.fetch!(outputs, global)}
      end)

    wrote(
      map_size(values) > 0 and Map.get(state.written, name) != values,
      name,
      pid,
      values,
      state
    )
  end

  defp wrote(false, _name, _pid, _values, state), do: {:cont, {:ok, state}}

  defp wrote(true, name, pid, values, state) do
    timeout = max(state.deadline - now(state), 0)
    answer = asked(pid, &Device.write(&1, values, &2), timeout)
    in_time(answer, now(state), name, pid, values, state)
  end

  # A write answered in time: the device is back from its adapter, heard then.
  defp in_time(:ok, answered, name, _pid, values, %{deadline: deadline} = state)
       when answered < deadline,
       do:
         {:cont,
          {:ok,
           %{
             state
             | written: Map.put(state.written, name, values),
               heard: Map.put(state.heard, name, answered)
           }}}

  # One that answered after its deadline on the runner's clock answered all the same, so it
  # is no hung device: it is `:timeout`, and the trip's zero writes it its 0 as it does
  # every device that answers. One killed, or gone down, the trip's zero finds down.
  defp in_time(:ok, _late, name, _pid, _values, state),
    do: {:halt, {:trip, {:io, name, :timeout}, state}}

  defp in_time({:error, cause}, _answered, name, _pid, _values, state),
    do: {:halt, {:trip, {:io, name, cause}, state}}

  defp now(%{clock: {module, clock}}), do: clocked(fn -> module.now_ms(clock) end)

  # A clock that has gone down, or fails, stops the runner, a shutdown, every device zeroed
  # and closed as at a stop: a runner cannot run without its clock, and a test's manual
  # clock goes down with the test that started it, before the runner has taken its
  # parent's exit.
  defp clocked(call) do
    call.()
  rescue
    exception -> exit({:shutdown, {:clock, Exception.message(exception)}})
  catch
    :exit, reason -> exit({:shutdown, {:clock, reason}})
  end

  # The options, checked in the caller in order: the list, each key, each once, the two it
  # needs, and then each value, the configuration first, so that its bindings are checked
  # against a configuration that starts.
  defp options!(opts) when is_list(opts), do: listed!(Keyword.keyword?(opts), opts)
  defp options!(opts), do: raise(ArgumentError, takes(opts))

  defp listed!(false, opts), do: raise(ArgumentError, takes(opts))

  defp listed!(true, opts) do
    keys = Keyword.keys(opts)
    known!(Enum.reject(keys, &(&1 in @options)))
    once!(keys -- Enum.uniq(keys))
    configuration = needed!(Keyword.fetch(opts, :configuration), :configuration)
    io = needed!(Keyword.fetch(opts, :io), :io)
    runtime = Runtime.start(configuration)
    clock = clock!(Keyword.get(opts, :clock, {Clock.Monotonic, nil}))
    poll = ms!(Keyword.get(opts, :poll, 10), :poll)
    overhead = share!(Keyword.get(opts, :overhead, 20))
    idle = ms!(Keyword.get(opts, :idle, 500), :idle)
    file = file!(Keyword.get(opts, :forces))
    store = retain!(Keyword.get(opts, :retain), file, clock)
    mode = start!(Keyword.fetch(opts, :start), store)
    period = period!(Keyword.get(opts, :retain_period), store)
    devices = Logex.IO.bind!(configuration, io)
    steps = steps!(Keyword.get(opts, :steps, Runtime))

    points = %{
      configuration: configuration,
      types:
        Map.new(
          for {_device, _module, _opts, points} <- devices,
              %Point{direction: :input} = point <- points,
              do: {point.name, point.type}
        ),
      located: located(configuration, devices),
      arrays: input_arrays(configuration)
    }

    forces = read_forces(file, points)
    {runtime, retain, at} = store_read!(store, mode, configuration, runtime, clock)

    {%{
       forces: forces,
       retain: retain,
       at: at,
       types: points.types,
       located: points.located,
       arrays: points.arrays,
       configuration: configuration,
       steps: steps,
       taker: taker(function_exported?(steps, :retained, 1), steps),
       retain_period: period,
       runtime: runtime,
       devices: devices,
       clock: clock,
       poll: poll,
       overhead: overhead,
       idle: idle,
       file: file
     }, Keyword.take(opts, [:name])}
  end

  defp takes(opts),
    do:
      "Logex.Runner.start_link/1 takes a keyword list of options, configuration:, io:, " <>
        "clock:, poll:, overhead:, idle:, forces:, retain:, retain_period:, start: and " <>
        "name:, got: " <>
        inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle:, forces:, " <>
          "retain:, retain_period:, start: and name:, got: #{inspect(key)}"
      )

  # A key given twice, the first repeated named: which of two values was meant is the
  # host's to say.
  defp once!([]), do: :ok

  defp once!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.Runner takes each option once, got #{inspect(key)} more than once"
      )

  defp needed!({:ok, value}, _key), do: value

  defp needed!(:error, :configuration),
    do:
      raise(
        ArgumentError,
        "Logex.Runner needs configuration:, the %Logex.Configuration{} it runs"
      )

  defp needed!(:error, :io),
    do:
      raise(
        ArgumentError,
        "Logex.Runner needs io:, each device its points are at bound by name to its adapter, " <>
          "%{} for a configuration with no point"
      )

  # A clock is a module that implements Logex.Runner.Clock and the term its callbacks take,
  # which the clock checks itself when it is first read, here, in its own words.
  defp clock!({module, clock}) when is_atom(module) do
    implements!(lacking_clock(module, Code.ensure_loaded?(module)), module)
    module.now_ms(clock)
    {module, clock}
  end

  defp clock!(other),
    do:
      raise(
        ArgumentError,
        "the runner's clock: is {module, clock}, a module that implements " <>
          "Logex.Runner.Clock and the clock its callbacks take, got: #{inspect(other)}"
      )

  defp lacking_clock(_module, false), do: :no_module

  defp lacking_clock(module, true),
    do:
      for(
        {f, a} <- [now_ms: 1, wake_at: 4, cancel: 2],
        not function_exported?(module, f, a),
        do: "#{f}/#{a}"
      )

  defp implements!([], _module), do: :ok

  defp implements!(:no_module, module),
    do: raise(ArgumentError, "the runner's clock `#{inspect(module)}` is no module")

  defp implements!(callbacks, module),
    do:
      raise(
        ArgumentError,
        "the runner's clock `#{inspect(module)}` does not implement Logex.Runner.Clock: it " <>
          "has no " <> Enum.join(callbacks, ", ")
      )

  # The hidden seam: a module with the three steps of Logex.Runtime's it stands in for.
  defp steps!(module) when is_atom(module),
    do:
      stands_in!(
        Code.ensure_loaded?(module) and Enum.all?(@steps, &exported?(module, &1)),
        module
      )

  defp steps!(other), do: stands_in!(false, other)

  defp exported?(module, {function, arity}), do: function_exported?(module, function, arity)

  defp stands_in!(true, module), do: module

  defp stands_in!(false, other),
    do:
      raise(
        ArgumentError,
        "the runner's steps: is a module with cycle_steps/3, cycle_step/2 and " <>
          "cycle_outputs/1, standing in for Logex.Runtime's, got: #{inspect(other)}"
      )

  defp ms!(ms, _key) when ms in @interval, do: ms

  defp ms!(other, key),
    do:
      raise(
        ArgumentError,
        "the runner's #{key}: is a whole number of milliseconds, 1 to 2147483647, got: " <>
          inspect(other)
      )

  # The forces file (decision 127): a path, or none, a runner that takes no force.
  defp file!(nil), do: nil
  defp file!(path) when is_binary(path) and path != "", do: path

  defp file!(other),
    do:
      raise(
        ArgumentError,
        "the runner's forces: is the path of the file its forces are kept in, a string, " <>
          "got: #{inspect(other)}"
      )

  # M6-5 (decisions 271, 275 and 285): the store, a path, or none, a runner whose
  # retained values survive no crash; never the forces file's, and read through a clock
  # that gives the wall clock its header is written by (decisions 322 and 325).
  defp retain!(nil, _forces, _clock), do: nil

  defp retain!(path, path, _clock),
    do:
      raise(
        ArgumentError,
        "the runner's retain: and forces: name one file, #{inspect(path)}: the store and the " <>
          "forces file are two files"
      )

  defp retain!(path, forces, {module, _clock}) when is_binary(path) and path != "" do
    apart!(met(expanded(forces), Path.expand(path)), path, forces)
    walled!(function_exported?(module, :wall_ms, 1), module, path)
  end

  defp retain!(other, _forces, _clock),
    do:
      raise(
        ArgumentError,
        "the runner's retain: is the path of the file its retained values are kept in, a " <>
          "string, got: #{inspect(other)}"
      )

  # The store and the forces file are two files however each is named, `./plant.retain`
  # and `plant.retain` one file, and neither is the `.tmp` the other is written through
  # (decisions 127 and 275), which each write would replace with its own text.
  defp expanded(nil), do: nil
  defp expanded(forces), do: Path.expand(forces)

  defp met(nil, _path), do: :apart
  defp met(forces, path), do: meeting(forces, path, forces <> ".tmp", path <> ".tmp")

  defp meeting(same, same, _forces_tmp, _path_tmp), do: {:one, same}
  defp meeting(_forces, path, path, _path_tmp), do: :store_through
  defp meeting(forces, _path, _forces_tmp, forces), do: :forces_through
  defp meeting(_forces, _path, _forces_tmp, _path_tmp), do: :apart

  defp apart!(:apart, _path, _forces), do: :ok

  defp apart!({:one, expanded}, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's retain: #{inspect(path)} and forces: #{inspect(forces)} name one " <>
          "file, #{inspect(expanded)}: the store and the forces file are two files"
      )

  defp apart!(:store_through, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's retain: #{inspect(path)} is the file its forces: #{inspect(forces)} " <>
          "is written through, each written whole to the `.tmp` beside it and renamed over " <>
          "it: the store and the forces file are two files, neither the other's `.tmp`"
      )

  defp apart!(:forces_through, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's forces: #{inspect(forces)} is the file its retain: #{inspect(path)} " <>
          "is written through, each written whole to the `.tmp` beside it and renamed over " <>
          "it: the store and the forces file are two files, neither the other's `.tmp`"
      )

  defp walled!(true, _module, path), do: path

  defp walled!(false, module, _path),
    do:
      raise(
        ArgumentError,
        "the runner's clock `#{inspect(module)}` has no wall_ms/1, which a runner given " <>
          "retain: writes its store's time by"
      )

  # How a fresh start meets its store (decision 271): warm unless `start: :cold`, which a
  # runner with no store has nothing to start from (decision 323).
  defp start!(:error, _store), do: :warm
  defp start!({:ok, mode}, store) when mode in [:warm, :cold] and is_binary(store), do: mode

  defp start!({:ok, mode}, nil) when mode in [:warm, :cold],
    do:
      raise(
        ArgumentError,
        "the runner keeps no store, so start: #{inspect(mode)} has none to start from: start " <>
          "it with retain: a path"
      )

  defp start!({:ok, other}, _store),
    do:
      raise(
        ArgumentError,
        "the runner's start: is :warm, a fresh start from its store, or :cold, from the " <>
          "configuration's initial values, got: #{inspect(other)}"
      )

  # M6-6 (decision 275): how often a runner given a store writes it, 1000 ms unless set or
  # nil, as `forces:` and `retain:` take nil for none, a whole number of milliseconds from
  # 100 to 3,600,000, the record's range (provisional); given to a runner that keeps no
  # store, the host's mistake, as `start:` is (decision 323).
  defp period!(nil, nil), do: nil
  defp period!(nil, _store), do: 1000
  defp period!(ms, store) when ms in @period and is_binary(store), do: ms

  defp period!(ms, nil) when ms in @period,
    do:
      raise(
        ArgumentError,
        "the runner keeps no store, so retain_period: #{ms} has none to write: start it " <>
          "with retain: a path"
      )

  defp period!(other, _store),
    do:
      raise(
        ArgumentError,
        "the runner's retain_period: is how often it writes its store, a whole number of " <>
          "ms from 100 to 3600000, got: #{inspect(other)}"
      )

  # The take-out a period makes: through the hidden seam's `retained/1` where its module
  # has one, so that a test sees when it comes, and otherwise Logex.Runtime's.
  defp taker(true, steps), do: steps
  defp taker(false, _steps), do: Runtime

  # The store at a fresh start (decisions 271, 276, 277 and 285), read in the caller after
  # the forces file: none, nothing; `start: :cold`, not read, the store written at once;
  # warm, a file that does not exist the same; one that cannot be read, that is no store,
  # or of another configuration, the host's mistake, every problem a line; and a store,
  # laid over the resource by decision 277's matching, what it drops reported.
  defp store_read!(nil, _mode, _configuration, runtime, _clock), do: {runtime, nil, nil}

  defp store_read!(path, :cold, _configuration, runtime, clock),
    do: {runtime, retained(path, nil, []), wall(clock)}

  defp store_read!(path, :warm, configuration, runtime, clock),
    do: store_text!(File.read(path), path, configuration, runtime, clock)

  defp store_text!({:error, :enoent}, path, _configuration, runtime, clock),
    do: {runtime, retained(path, nil, []), wall(clock)}

  defp store_text!({:error, reason}, path, _configuration, _runtime, _clock),
    do:
      raise(
        ArgumentError,
        "#{path}: the store cannot be read: #{:file.format_error(reason)}"
      )

  defp store_text!({:ok, text}, path, configuration, _runtime, _clock) do
    {image, written_at} = Logex.Retain.decode!(text, {path, configuration.name})
    {runtime, dropped} = started!(configuration, image, path)
    {runtime, retained(path, written_at, dropped), nil}
  end

  # The image a store holds judged as `Logex.Runtime.start/2` judges any, each of its
  # refusals a line naming the store.
  defp started!(configuration, image, path) do
    Runtime.start(configuration, image)
  rescue
    error in ArgumentError ->
      reraise ArgumentError,
              error.message |> String.split("\n") |> Enum.map_join("\n", &"#{path}: #{&1}"),
              __STACKTRACE__
  end

  # `status/1`'s `retain` (decisions 275 and 277): the store's path, the time its last
  # write was made at, nil before the first, the reason the last write failed, nil where
  # it did not, and what the fresh start dropped.
  defp retained(path, written_at, dropped),
    do: %{path: path, written_at: written_at, failed: nil, dropped: dropped}

  # The host's wall clock, to the second, for a store's header.
  defp wall({module, clock}), do: Logex.Retain.at(clocked(fn -> module.wall_ms(clock) end))

  defp share!(share) when share in @share, do: share

  defp share!(other),
    do:
      raise(
        ArgumentError,
        "the runner's overhead: is the share of the time kept for its own work, a whole " <>
          "number of percent from 10 to 90, got: #{inspect(other)}"
      )

  # A runner is a process this module started, by its pid or the name it was started
  # under: one that is down, or is another kind of process, is the host's mistake.
  defp runner!(runner) when is_pid(runner),
    do: started!(Process.info(runner, :dictionary), runner)

  defp runner!(runner), do: named!(where(runner), runner)

  defp where(name) do
    GenServer.whereis(name)
  rescue
    _not_a_name -> :not_a_name
  catch
    :exit, _not_a_name -> :not_a_name
  end

  defp named!(pid, _name) when is_pid(pid), do: runner!(pid)

  defp named!(nil, name),
    do: raise(ArgumentError, "no runner is running under the name #{inspect(name)}")

  defp named!(_other, name), do: raise(ArgumentError, expected(name))

  defp started!({:dictionary, dictionary}, runner),
    do: ours!(List.keyfind(dictionary, :"$initial_call", 0), runner)

  defp started!(nil, runner), do: raise(ArgumentError, not_running(runner))

  defp ours!({_key, {__MODULE__, :init, 1}}, runner), do: runner
  defp ours!(_other, runner), do: raise(ArgumentError, expected(runner) <> ", another process")

  defp expected(other),
    do: "expected a runner from Logex.Runner.start_link/1, got: #{inspect(other)}"
end
