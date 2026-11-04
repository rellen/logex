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
  since decision 400 `write_limit:`, how long in ms of real time each file write and read
  the runner makes may take, the forces file's, the store's and the store's copy's,
  1 to 2147483647, 5000 unless set, a limit of its own apart from the heartbeat (below,
  "Its write limit"), since decision 398 `open:`, how long in ms of real time a device's
  opening may take, its adapter's init/3 and its first read, 5000 unless set, a whole
  number from 1 to 2147483647 for every device or a map of device names to one, each
  device it names given its own and every other 5000, a device it names that `io:` binds
  no adapter to the host's mistake (below, "Its devices"), `forces:`, the path of the file its forces are kept in (decision 127), none unless set,
  a runner without one taking no force, since M6-5 `retain:`, the path of its store, the
  file its retained values are kept in across a crash (decision 275), none unless set,
  since M6-6 `retain_period:`, how often it writes that store, 100 to 3,600,000 ms, 1000
  unless set or nil (decision 275), and `start:`, `:warm` or `:cold`, how a fresh start
  meets that store, `:warm` unless set (decision 271), each of the last two the host's
  mistake without `retain:` (decision 323), and `name:`, a name to register it under, as
  `GenServer.start_link/3` takes one, a `{:via, module, term}` name's module a registry
  that exports register_name/2, unregister_name/1, whereis_name/1 and send/2. It
  checks every option in the caller before anything starts, the configuration as
  `Logex.Runtime.start/1` checks it and the bindings as `Logex.IO.bind!/2` does, so a
  host's mistake is an `ArgumentError` in the host's own process, with a message a test
  pins, and never a crash of the runner. Its child spec is `restart: :temporary`
  (decision 115): nothing starts it again that no person asked to start; and since M6-6's
  review its `shutdown:` is long enough for every device's close and the store's write,
  `(devices + 2) * (idle + poll)` ms and never less than 5000 (`child_spec/1`, decision
  326), since decision 400 `devices * (idle + poll) + 2 * write_limit`, the writer's write
  and the store's own each given the write limit, and since decision 414 the store's own
  its text's making among it, so that a supervisor does not kill it before decision
  316's write, nor more than 4294967295, the longest a supervisor waits
  (c1-runner-rounds-6).

  **Its files** (RV-4). A runner holds its store and its forces file, each with the `.tmp`
  beside it that it is written through, and since decision 360 its store's copies, since
  decision 418 every copy's name, `<store>.dropped.<n>` whatever its number, with the one
  `.tmp` they are written through, `<store>.dropped.tmp`, from its start until it stops,
  crashes or is killed (decision 356): a start that names a file another runner of this
  VM holds, as its store, its forces file, one of its store's copies' names or the `.tmp`
  of any, or whose store's copies' names another runner holds a file at, is the host's
  mistake, one
  `ArgumentError` naming the option, the path as the host spelled it, what the file is to
  the other runner and that runner's pid, told before either file is read and nothing
  written or opened; once the holder is gone, stopped, crashed or killed, the file is free
  again, and the next start takes it. A start under a name already registered is
  `{:error, {:already_started, pid}}` first, OTP's, and claims nothing. Two VMs on one
  file are the host's to avoid: nothing in one VM sees another, nor one file reached by
  two paths through a linked directory, a store or forces file that is itself a link
  being refused (RV-5). Each path is resolved once, at the start, against the working
  directory then (c2-runner-persist-9), every read and write of the file made through it,
  so that a `File.cd` after the start moves neither file and `./plant.retain`,
  `plant.retain` and its absolute path are one file to the check; `status/1` and every
  message give the path as the host spelled it. The claims live in a table a process of
  logex's own keeps for the VM, which the first runner starts and which does nothing else.

  **Its write limit** (decisions 353 and 400). Every file write and read the runner makes,
  the forces file's and the store's at every event and start, the period's, the store's
  copy and the look at each file for a link, is made in a process of its own and limited
  to `write_limit:` of real time, 5000 ms unless set, a limit of its own apart from the
  heartbeat, so that a healthy disk's sync on a machine whose cores are all busy meets
  it, and a disk that has not answered by then is a stalled one, the write killed and
  reported `:timeout`, unknown until a later write lands or fails (decision 391), or the
  read told as a file that cannot be read, the runner answering on. A relative path's
  expansion at a start, which reads the working directory through the VM's file server,
  is made so too, never in the caller; one the disk does not answer in time leaves the
  start no file to hold, check or write, and refuses it, the store or the forces file
  "cannot be located" (provisional), where decision 390 carries a fresh start on past a
  forces file that cannot be read. Since decision 437 a force's or an unforce's write of
  the forces file is made off the runner's path, in a process of its own limited the
  same, and the rounds run on while it is out, every device refreshed by them and by the
  waits as ever, so that the logic keeps the plant under control on a slow disk and no
  time of the disk's is any request's, where decision 400 held every round for up to the
  write limit while the runner waited on the disk, renewing the heartbeat (below,
  "Forcing").

  **Its devices** (decisions 112, 120, 124 and 125). Each bound device runs in a process
  of its own, linked to the runner, which holds its adapter's state and calls its
  callbacks; the runner opens them in device-name order, reads each once, and runs the
  first round at once, so a device that cannot be opened is `start_link/1`'s
  `{:error, {:io_init, device, reason}}`, every device opened before it closed again; one
  that has not opened within its own `open:` limit of real time, 5000 ms unless set, is
  killed and `:timeout`, so that a drive whose connect takes 600 ms opens beside the idle
  watchdog's 500, the heartbeat left as it is, and a hung card refuses the start at the
  time its limit gives (decision 398, provisional: the option, its map form and its
  default); a device a restart opens again is given the same limit, and since decision 439
  so is one up that a restart reads again, every device a restart opens or reads limited
  by its own `open:`, so that a gateway that stayed up and answers its reread in 700 ms
  lets the restart through, the heartbeat left the idle watchdog and a poll period, a
  restart's release of each device and every other device call limited so (decision
  128). It
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
    points, by address, in device-name order, and the runner waits for its answer, which
    comes once its adapter has written them, each device's write given the idle watchdog
    and a poll period of its own from the start of its own write, on the runner's clock
    and as long in real time, so that a device is cut short only by its own slowness,
    never by a slow device written before it that answered in time (decision 348). Every
    device is refreshed, without a wait, before each step of a round, the refresh carrying
    that step's deadline, its task's watchdog and one poll period from the step's start,
    and before the writes, carrying the idle watchdog's and one poll period from then, and
    again before a device's write where the clock has moved since, so that the device
    written hears its own deadline and every other the runner well while it waits on a
    slow one in time (decisions 125, 128 and 348): a refresh calls no adapter.
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
    requests freely. A host's request is served at once where no round is owed.
  - With no untimed program, since decision 396, a host's requests are held to their share
    against a due periodic round as against the continuous task. A request that comes
    while a periodic round's due time has come waits for that round, which runs first;
    the requests that waited are served after it, each whole, while no round is due, the
    time no due round needs, as Logix's communications take only the time no periodic
    task needs with no continuous task.
    The rounds are the share's count, each whole from its start to its end, a
    millisecond at least, and the slot comes at the end of the round that completes C ms
    of them, S ms as above, so that a plant whose rounds outrun their periods leaves the
    host its S ms of every C + S, never none and never more (provisional). So a tight loop
    of `status/1` or `force/3` makes a due round wait for one request at most, or a slot,
    where it delayed a 10 ms task for as long as it lasted, every period missed an overlap
    (c1-runner-rounds-2). Every device is refreshed before the runner serves its own
    work, whichever way. A slot serves the requests in the runner's queue as the round
    that brings it ends; one still in its mailbox then, a caller's next request sent as
    its last is answered, finds the slot gone and the count begun again, as with the
    continuous task, so that a lone caller in a loop, each request sent once the last is
    answered, is served once every other slot where every round brings one (provisional).
  - **On the manual clock** (decision 131) the same rules run: a round takes no time
    unless something passes time inside it, so a request is served before the next
    round; but one made while a round is owed, after a round that passed time, waits for
    its slot, which comes in the advance that runs the round completing C ms of rounds,
    or with no untimed program the round due where none is due after it,
    `advance(clock, 0)` among them, never later, as decision 131 has a call wait for its
    slot (provisional for a periodic round: an overdue one is not run by the request that
    finds it, decision 131's option passed over). A test that calls from the process
    that moves the clock would wait for ever, so it calls from another and moves the
    clock on until the call is answered:

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
    host's mistake (decision 133), judged as the restart arrives (decision 354): one asked
    while the runner runs, waiting in its mailbox while a round is under way or in its
    queue for the share's slot, is refused all the same where a trip comes before it is
    served, the trip refusing it.

  **Its store** (M6-5, `docs/organisation.md` §4.13; decisions 271, 275, 276, 284, 285,
  291 and 292). A runner given `retain:` keeps every value its configuration retains, the
  resource's retained image (`Logex.Runtime.retained/1`), in a file on the host's disk,
  which stands in for battery-backed memory:
  - *Its text* is a person's to read, and to edit by hand where a retained value tripped
    the plant (decision 284): `logex retain 2`; `configuration <name> written <time>`,
    the time of the write on the host's wall clock, in UTC to the second, read through
    the clock's `wall_ms/1` (`Logex.Runner.Clock`), for a person and for `status/1`, never
    for a timer; each retained global, `global total_boxes dint 41`; each retained
    `single`'s last sample, `trigger arm 0` (decision 313); each instance whose program
    retains anything, `instance m1 motor`, then its lines in path order, each instance on
    the way to a value with its kind, `m1.boxes ctu`, and each value with its type,
    `m1.boxes.cv dint 41`, an array's elements in the elements' order, `m1.weights int[8]
    0 0 12 14 0 0 0 0`, a real in the shortest text that reads back to it, and a timer's
    `last` never; and since decision 355 its end line, `end 9 lines`, its count of lines,
    the header and the end line among them (the words decision 409's), so that a store
    cut short anywhere, at a line's end or inside a number, is refused at a fresh start,
    never read short. A store of `logex retain 1`, which has no end line, is read as
    before. The runner writes each line ended by LF, and since decision 410 reads a line
    ended by LF, CRLF or a lone CR alike, as the source's and a configuration file's
    readers do, so that a store a hand edit saved with CRLF line ends starts, its lines
    counted however they end, where RV-5 refused it at its first carriage return; a
    comment, a tab and a byte no store holds are each told as what they are; and a
    refusal, the forces file's as the store's, names at most its first 50 problems and
    counts the rest, each text of the file it quotes at most 60 bytes and printable. A
    hand edit is made with the runner stopped (decision 284): a runner still running
    holds every retained value in memory, a warm restart starts from what it holds and a
    stop writes it over the edit. A store or a forces file that is a symbolic link is the
    host's mistake at start, every write being a new file renamed over the old, which
    would put a file in the link's place (decision 413).
  - *Its writes*: at every trip, of the resource as the trip left it, after every output
    is 0; at every `stop/2`, and since decisions 316 and 328 at every orderly exit, a
    parent's shutdown or `:normal`, after every output is 0 and every device closed; at every cold restart, of the
    resource as it restarts it, before any device is released or read (decision 291),
    and where a device then refuses it, of the resource as the runner still holds it,
    after the refusal's zeros (decision 317); and at a fresh start with `start: :cold`, or with no store file,
    in the runner's own process once its name is registered and its files claimed, before
    any device is opened, so that a start refused, `{:already_started, pid}` or a file
    another runner holds, writes nothing (M11). Each is synchronous, written whole to
    `<path>.tmp` beside it, flushed and renamed over it, the forces file's rule, so that a
    crash at any moment leaves the old store or the new; since decision 353 each is made
    in a process of its own and limited to the write limit of real time, since decision
    400 `write_limit:`, where it was the idle watchdog and a poll period, as the period's
    write is where the runner waits on it, one the disk has not
    finished by then killed and failed, `:timeout`, so that a stalled disk leaves the
    runner answering, its outputs 0 through the trip as ever, though one killed in its
    rename may land once the disk answers; since RV-4's review that process is linked to
    the runner, so that a runner killed while it writes takes the write down with it, the
    write doing nothing after the call of the file system it was in; and since M10 each write's `.tmp` is its own,
    made new and exclusively, whatever stands at `<path>.tmp` deleted, a FIFO, a link or
    a write's leftover, so that a write killed inside a call of the file system, which
    runs on to its end in the kernel, never writes into the next write's file: the store
    is the old or the new, never a mix (decision 392). A write
    that fails leaves the store as it was and is reported, `{:retain, {:error, reason}}`
    to the subscribers and `failed` in `status/1`'s `retain`: a trip stays a trip; a cold
    restart leaves the runner tripped as it was, every output still 0 and no device
    released or read, and answers `{:error, {:retain, reason}}`; a stop stops all the same
    and answers it; and a fresh start starts nothing and gives it. Since decision 391 a
    write past its limit, which may still land once the disk answers, is neither failed
    nor written: it is reported `{:retain, {:error, :timeout}}` as one that fails is, its
    caller answered `{:error, {:retain, :timeout}}` and a cold restart or a fresh start
    left as for a write that fails, and `status/1`'s `retain` names the file it may land
    in, `unknown: "plant.retain"`, the store or its copy as the host spelled it, `failed`
    nil and `written_at` the last write known made, until a later write lands or fails,
    the key absent otherwise (provisional: its name and that it stands only so long); a
    stop told `{:error, {:retain, :timeout}}` leaves the store so, the old or the new,
    the last write or the stop's. Since decision 317 a
    cold restart that a device then refuses writes the store back, after the refusal's
    zeros, with the values the runner still holds, the trip's, so that a refused restart
    changes nothing on disk or in memory, a write-back that fails reported as any failed
    write, the runner tripped either way. Since decision 316 an orderly shutdown from the
    runner's parent, a supervisor's `:shutdown` or a `{:shutdown, term}`, writes as
    `stop/2` does, after every output is 0 and every device closed, a failure reported to
    the subscribers; the runner tells a shutdown by its reason alone, so
    `GenServer.stop(runner, :shutdown)` from any other process writes as its parent's
    does, its caller given `:ok` and the failure only to the subscribers, where `stop/2`
    answers it (decision 327). Since decision 328 a `:normal` exit writes too, a parent's
    that ends `:normal` and a `GenServer.stop(runner)` from any process, after the same
    zeros and closes, so that every orderly exit writes. A runner that crashes or is
    killed, whose clock goes down, a shutdown of its own, `{:shutdown, {:clock, reason}}`,
    or that ends for any other reason, writes none (decision 292), so its next fresh start
    meets the last write, a period's or an event's; and one whose devices cannot be
    opened, whose `init/1` gives `{:error, {:io_init, device, reason}}` and so ends
    `:normal` with no `terminate/2`, writes none as it ends either: a warm start's store
    is as the caller left it, and a cold start's, `start: :cold`, or one with no store
    holds the initial values it wrote before it opened a device (decisions 271 and 291).
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
    `{:retain, {:error, reason}}` and `failed`, the plant running on; since RV-4's review
    one the disk has not finished within the write limit of real time is reported
    `{:error, :timeout}` so, once, and left to finish, its answer taken when it comes
    (decision 401), since decision 391 named `unknown` meanwhile, neither failed nor
    written, its answer making it written or failed; a writer gone
    down is reported, `{:down, reason}`, and a new one writes the next (provisional), one
    gone down while idle forgotten. Every
    write at an event waits first for the write in progress and drops the one pending,
    so that the event's is the last on disk: the trip's, the stop's, a shutdown's and a
    cold restart's, a writer that has not answered by the write limit, in real time,
    killed, its write reported `:timeout`, and one already gone down taken
    as gone at once, `{:down, reason}` (provisional). So a crash or a kill loses what
    changed since the last write made: at most a period and the write in progress while
    writes succeed and the writer keeps up, but everything since the last good write
    while they fail, a full disk's among them, and, while tripped, what an edit stepped
    then changed, which no write takes until a restart.
  - *A fresh start* reads the store in the caller, after the forces file, warm unless
    `start: :cold`, since RV-5 raw and limited to the write limit of real time, as the
    forces file's read is, so that a FIFO or a stalled disk in its place refuses the start
    as a store that cannot be read (decision 415), and since RV-5's review so is the look
    at each file for a symbolic link before either is read, neither file looked at nor
    read in the caller itself: a store laid over the resource by decision 277's matching
    (`Logex.Runtime.start/2`), each value kept only where the configuration retains its
    path, of exactly its type, and it fits, the rest dropped and reported in `status/1`'s
    `retain`, and since decision 360 the store, as the start read it, copied before its
    first write over it, in the runner's own process once its files are claimed and before
    any device is opened, so that a mistaken deploy's drops can be taken back from the
    copy once the next write has made the store the new configuration's: since decision
    418 each copy is a name of its own, `<store>.dropped.<n>`, n one past the highest
    number standing beside the store, every file or directory named so counting, 1 where
    none does, and none is replaced, a copy staying until the host deletes it; an
    unnumbered `<store>.dropped` an earlier logex left is kept as it stands and counts for
    nothing (provisional). The copy is written as every other write is, through the
    copies' one `.tmp`, `<store>.dropped.tmp`, limited the same, and renamed only where
    nothing stands at its name as it looks, raw, just before its rename, so that a file a
    host makes there while it is written, before that look, fails it, `:eexist`
    (provisional); one made between the look and the rename, which goes through the VM's
    file server and on a stalled disk waits in its queue, is replaced (provisional). A
    store's copies are its name read whole, so that `plant.dropped`'s are
    `plant.dropped.dropped.<n>`; and each start that drops makes a copy of its own, the
    same bytes as the highest copy's where the store has not changed since, a start that
    failed after its copy and is started again among them (provisional). A copy's
    failure is reported as a failed write's, `failed` in `status/1`, and the start goes
    on, the copy then owed (decision 416): since RV-5's review every write over the
    store, the period's, a trip's, a stop's, a shutdown's and a cold restart's, makes it
    first, under the next number then, and writes the store only once it is made, each
    while it cannot be made a write that fails, so that no write replaces the store
    before its copy is made; a start that drops
    nothing makes none, and `status/1`'s `retain` names the copy the start made, `copy`,
    `plant.retain.dropped.2`; a file that does not exist none, written at once; and one
    that cannot be read, that is no store, a line of no store's shape, an image
    `Logex.Runtime.start/2` refuses, a store of another configuration, which a renamed
    configuration's is, or since decision 355 one of `logex retain 2` cut short, its last
    line no end line or its end line's count not its lines', the host's mistake, one
    `ArgumentError`, a line each, `<path>: line <n>: ...`, the runner not started and no
    device opened. `start: :cold` starts from none of it, a broken one among them, and
    writes a new store at once; since decision 417 it reads the store first, as a warm
    start does, and one that stands and that a warm start would refuse, cut short or
    refused by any line of it or its image, it copies first, under the next of its
    numbered copies, `status/1` naming the copy, and writes the new store only once the
    copy is made, so that the readable part of a store the refusal's remedy starts over is
    kept; a copy that cannot be made is judged as decision 291 judges a cold start whose
    first write fails, the runner not started, `{:error, {:retain, reason}}`, the store as
    it was, and so is a store that stands but cannot be read, a FIFO's read past the write
    limit or a directory in its place, which no copy can be made of (provisional). A store
    that reads whole needs no copy and gets none. A cold `restart/2` reads no store,
    starting from the resource the runner holds, and copies none (provisional): the store
    is its own last write, a hand edit made while the runner runs being lost anyway
    (decision 284).
  - A runner with no `retain:` keeps nothing across a crash; a warm `restart/2` still
    keeps retained values in memory, and `status/1`'s `retain` is nil. `start:` without
    `retain:` is the host's mistake (decision 323), as are `retain:` naming the forces
    file, after `Path.expand/1`, or the `.tmp` either is written through (decision 325),
    since decision 360 `forces:` naming the store's copy or the `.tmp` the copy is written
    through, since decision 418 any of its numbered copies' names, `<store>.dropped.<n>`,
    whatever the number's digits, the copies' `.tmp` and `<store>.dropped`, which is
    written through it, and a clock with no `wall_ms/1` (decision 322). The first round's
    `{:retain, ...}` news, the store's age and its drops, reaches no subscriber, since
    none can exist before `start_link/1` returns: `status/1`'s `retain` carries both
    (decision 324).

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
  `temps[3] 37.5` (decision 156), and since decision 384 by its subscripts' values however
  a host or the file writes them, `temps[03]` and `temps[16#3]` naming `temps[3]`, under
  which it is kept, written and shown in `status/1`; and since decision 241 an array of input points named
  whole is forced to a list of its shape, each element then forced, every misfit told, ten
  and then a count, and unforced whole, each element reading its device's last value
  again; a forces file's line for it is its name and one value an element in the
  elements' order, `temps 20.0 21.5 …`, read as each element forced, the file written
  back element by element.
  `status/1` lists every force. The forces file is the host's to name, `forces:`,
  and each force and unforce writes the whole set to it before it returns:
  one force a line, `name value`, in name order, the empty file for none, written to
  `<path>.tmp` beside it, flushed to the disk and renamed over it, so that a crash at any
  moment leaves the old set or the new. Since decision 437 the rounds run on while the
  write is out, in a process of its own, and the force takes effect at the first round
  after the write lands, its caller answered then, a trigger it changes making its round
  first, so that the logic keeps the plant under control on a slow disk and no force is
  in effect before the file holds it (decision 117): meanwhile every round reads the
  forces as they were and `status/1` lists those, the force not among them until its
  write lands. A force, an unforce or an unforce_all asked while a write is out waits
  behind it, in order, each served once the one before it is answered, its write built on
  the set that one left, so that no two writes are out at once (provisional, the record
  silent); a trip, a restart and an edit's step made meanwhile leave the write as it is,
  the force taken, or not, onto the set the runner then holds as its answer says, a
  restart reading the file as it stands, the old set or the new, as every start does; and
  a stop waits for it to its own limit, after its zeros and its closes, answers its
  caller as it ends and gives the file up only after it, a force waiting behind it
  answered as to a runner that is not running (provisional). A write that fails changes nothing and gives
  `{:error, {:forces, reason}}`, and since decision 353 one the disk has not finished
  within the write limit of real time, since decision 400 `write_limit:`, is killed and
  gives `{:error, {:forces, :timeout}}`, the force not taken and the runner answering on: a
  call the disk makes after the kill can still bring the file to the new set, the old or
  the new, which a restart, reading the file as every start does, then takes, and
  `status/1` lists; since decision 391 `status/1` names meanwhile the set the write
  held, `forces_unknown`, until a later write of the file lands or fails or a restart
  reads it, the key absent otherwise (provisional: its name and that it stands only so
  long). Every start reads it, `start_link/1` in the caller,
  after the configuration and the bindings, and `restart/2` before it releases anything,
  each raw, off the VM's file server, and limited to the write limit of real time
  (decisions 353 and 400), so that a runner killed while an input is forced, and started
  again from the same file, comes back with it forced and listed: a file that does not
  exist is no force; since decision 390 one that cannot be read, a read the disk has not
  finished within the write limit, a FIFO's among them, or one the file system refuses,
  a directory or a file the runner may not read in its place, starts a fresh start with
  no force and keeps at a restart the forces the runner holds, the start or the restart
  going on, the line coming back, and `status/1` names the file, `forces_unread: {path,
  reason}`, the path as the host spelled it and `reason` `:timeout` or the file system's
  own, until a force's or an unforce's write of the file lands or a restart reads it,
  the key absent while the file reads (provisional: its name and that it stands only so
  long); a restart that reads the file once it reads again takes what it holds, as every
  start does (decision 127), so that a fresh start that could not read it, which started
  with no force, takes at its next restart the forces the file held, ones no one forced
  since and `status/1` did not show (provisional, RV-11's review); a line that is no force, a point forced twice, and a force the configuration
  cannot take, on a point it does not have as an input point or of a value that does not
  fit, are the host's mistake, every one named in one `ArgumentError`, a line each,
  `<path>: line <n>: ...`, the runner not started, or at a restart left tripped: the file
  is read exactly as the runner writes it, a last line with no line end read, and since
  decision 410 a line ended by LF, CRLF or a lone CR read alike, the runner writing LF, so
  that `hz 1.5` saved with CRLF line ends forces 1.5, where its carriage return was no
  force (M5-11's review), and an unforce of a point not forced is accepted, writing the
  set again (decision 140), but for a point's value, which since decision 218 for a real
  point and decision 226 for every other is any number the lexer reads as one literal and
  the
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
  leaves none followed by every request that waited for the share's slot, in order, as
  each is served from then on, at once while no periodic round is due (decision 396); and the next round is planned again from the
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
  trip it for the same reason on every run, and each is acted on before the trip, so that
  a restart asked after it finds every device heard as late as they say. A notice
  carries the count of restarts its device had been released for, and one raised before
  the last restart's release, come in behind that restart, trips nothing. A restart is
  judged as it arrives (decision 354): one asked while the runner runs is refused,
  whatever comes before it is served, a trip that answers it among it, so that a trip
  stands until a restart asked after it. The reasons:
  - `{:watchdog, {:task, task, took_ms, limit_ms}}`: a timed task's run, from the start of
    its first instance's scan to the end of its last, longer than its task's watchdog,
    checked after its step and before the round's write (decision 110);
  - `{:watchdog, {:round, task, took_ms, limit_ms, steps}}`: a round of the continuous
    task, from the inputs taken to the end of its last program's scan, the timed tasks'
    runs in it included, longer than the continuous task's watchdog, `task` its name or
    `:none`, 500 ms, where none is declared, and `steps` each step the round ran, in
    order, `{task, ms}` (decisions 111 and 126);
  - `{:watchdog, {:idle, ms}}`: a host's request served whole, from its start to its end,
    longer than the idle watchdog, the trip made once it is answered (decision 128), a
    force's write of the forces file none of it, made off the runner's path since
    decision 437;
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
    so; a read's or a report's value that does not fit its point is `{:bad_value, at,
    value}` and an address that is no input point's `{:unknown_address, at}`, `at` the
    address as the configuration writes it since decision 399, `"panel.i.7"`, a text,
    where an adapter gives a list of whole numbers, and as the adapter gave it otherwise,
    `:pump` or `[-1]`, which no configuration writes (provisional); a device that does not answer a round's write within its own deadline, the
    idle watchdog and a poll period from the start of its own write (decision 348), in
    real time, is `:timeout`, and is killed, its outputs left to what it does on losing
    its master, and named, every device written before it having answered in time and
    each taking the trip's 0, as every device after it, not written, does; one that
    answers a round's write after its own deadline on the runner's clock is `:timeout`
    too, and is written its 0 by the trip, as every device that answers is; so is one
    hung inside its own read or report,
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
  - `{:clock, {:now_ms, answer}}` or `{:clock, {:wall_ms, answer}}`: since decision 394, the
    clock gave the runner, or a device, no time it can hold, once the runner runs (below);
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
  each device that went down, those among them, each read or opened within its own
  `open:` since decision 439, and checking each value read as a start's first reads are;
  `{:error, {:io_init, device, reason}}` for the first that cannot be
  opened or whose read fails, an error, a raise, a throw, an exit, a value that does not
  fit, an address that is no input point's, no answer in time (the device killed, and
  opened again at the next restart) or a process gone down, the runner left tripped with
  its first reason and every device that answers latched again, written 0 once more, as
  a restart that trips again is (decision 136), so that nothing switches on from a card
  still at fault; restarts the resource (`Logex.Runtime.restart/2`), which keeps its
  input image and puts every other global back to its initial value; sends `{:restart,
  mode}`; and runs the first round at once, on what the devices read, before it returns,
  the clock not counting the time it was stopped. A runner that crashes, is killed or loses its clock is gone (decision 115):
  each device traps its exit and writes every output 0 once, where it had not, and closes,
  and since RV-4 one hung inside its adapter, which cannot take the exit, is killed by a
  process of its own within the idle watchdog and a poll period of real time of its
  runner's death, its outputs left to what it does on losing its master and what it held
  free for the next start (c7-premortem-plant-3); its child spec is `restart: :temporary`,
  so nothing starts it again, and the host starts a new one. A clock that goes down, or
  whose callback raises or exits, stops it as a shutdown, `{:shutdown, {:clock, reason}}`,
  its devices zeroed and closed as at a stop. A clock that answers no time is the host's
  mistake where the start reads it (c2-runner-persist-6, c3-io-contract-9): a `now_ms/1`
  that gives no whole number of milliseconds, or since decision 394 one out of the range
  the runner holds a time in, a signed 64-bit integer, and a `wall_ms/1` whose answer no
  store's header holds, no whole number of milliseconds since the epoch from year 0 to
  year 9999. Once the runner runs, since decision 394 such an answer trips it, naming the
  clock, `{:clock, {:now_ms, answer}}` or `{:clock, {:wall_ms, answer}}`, every output 0,
  where a bad `now_ms/1` stopped it as a shutdown: the runner's own read of `now_ms/1`
  tells it so, the work in hand finished with the last time it refreshed its devices at,
  and it trips as it next takes a message; a device's read of it takes the device down,
  every output 0 as it closes, and the runner trips naming the clock, however it finds
  the device gone, by its exit or by a round's write to it (RV-11's review); and a period's
  write whose `wall_ms/1` gives no time fails, reported as any failed write, and trips it
  so, a trip's, a stop's or a cold restart's write failing so as before. A restart while
  the clock still answers so is refused, `{:error, {:clock, cause}}`, the runner left
  tripped, the wall clock asked where a store is named, and once it is mended a restart
  brings the line back (provisional: the range, the round in progress finished, and the
  restart's look at both clocks).

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
  alias Logex.Runner.{Clock, Device, Paths, Writer}

  # c1-runner-rounds-9 (RV-4): a device's notice, of the shape Logex.Runner.Device sends
  # one; a message of any other shape, from whatever process, is passed over as any
  # message the runner does not know.
  defguardp notice?(pid, restarts, at, kind, name)
            when is_pid(pid) and is_integer(restarts) and is_integer(at) and
                   kind in [:back, :zeroed, :latched, :fault] and is_binary(name)

  # Decision 437 (RV-16): a host's request that writes the forces file, a force's, an
  # unforce's or an unforce_all's.
  defguardp forcing?(request)
            when request == :unforce_all or
                   (is_tuple(request) and elem(request, 0) in [:force, :unforce])

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
    :write_limit,
    :open,
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

  # Decision 398 (RV-11): a device's opening, its own limit's default (opens!/2).
  @open 5000

  # Decision 394 (RV-11): the times a runner holds, as the renewal's `:atomics` holds them.
  @time_range -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  # Decision 400 (RV-11): every file write and read decision 353 limits is limited by
  # `write_limit:`, apart from the heartbeat, "a few seconds" unless set: 5000 ms, some
  # twenty times the slowest store write measured on a machine whose every core was busy
  # (231 ms in 1,912, RV-4) and seven times the most a 10 ms sleep overshot there (668 ms,
  # RV-4's review), so that a healthy disk on a loaded machine meets it, and a disk that
  # has not answered in five seconds is a stalled one, told so.
  @write_limit 5000

  @doc """
  Starts a runner linked to the caller, every option checked first in the caller (see the
  moduledoc), opens every device in device-name order, reads each once and runs the first
  round at once: `{:ok, pid}`, or `{:error, {:io_init, device, reason}}` for a device that
  cannot be opened, which is the plant's state, not a host mistake, every device opened
  before it closed again and the runner gone: `reason` init/3's own, or the cause of an
  init/3 or a first read that raised, threw, exited, gave no result `Logex.IO` gives or a
  value that does not fit, or `:timeout` for one that did not answer within its own
  opening limit, `open:` (decision 398), where every device call was limited to the idle
  watchdog and a poll period, as an I/O fault's (M4-4); `{:error, {:retain, reason}}` for
  a fresh start's write of its store that failed, `:timeout` among it, past the write
  limit (decisions 353 and 400);
  `{:error, {:already_started, pid}}` for a name another process holds, nothing written;
  and a raise of the host's mistake, in the caller, for a store or forces path another
  runner of this VM holds (decision 356).
  """
  def start_link(opts) do
    {start, name} = options!(opts)
    started(GenServer.start_link(__MODULE__, start, name))
  end

  # Decision 356: a file another runner of this VM holds is the host's mistake, found in
  # the runner's init/1, once its name is registered, and raised here, in the caller.
  defp started({:error, {:held, message}}), do: raise(ArgumentError, message)
  defp started(result), do: result

  @doc """
  The child spec a supervisor starts a runner by, `restart: :temporary` (decision 115),
  and, since M6-6's review, a `shutdown:` long enough for the orderly shutdown decision 316
  writes the store at: every device's 0 and close, each bounded by the idle watchdog and a
  poll period in real time, the writer's write in progress, bounded the same, and the
  store's own write, given one more: `(devices + 2) * (idle + poll)` ms, and never less
  than the 5000 ms of any GenServer's spec, so a plant of a few devices keeps that
  (decision 326); since decision 400 the writer's write and the store's own each given
  the write limit, `devices * (idle + poll) + 2 * write_limit` ms, never less than 5000. `devices` is the number of devices `io:` binds; an option that is not
  yet the runner's, which `start_link/1` refuses, counts as its default. A host that
  gives its own `shutdown:`, by `Supervisor.child_spec/2`, takes its own. Since decision
  414 the deadline follows `write_limit:` whole: the shutdown's write, every orderly
  exit's, takes the retained image out and makes the store's text in the write's own
  process, within the write limit, where the runner made them first, with no limit, in
  proportion to the retained values (b3-store-image-4), so that a supervisor waits as long
  as the shutdown's write may take, and a store too big to make and write within the
  limit is cut off at it and reported as any write past its limit, `{:retain, {:error,
  :timeout}}`, the store keeping its last write (decision 391), where the supervisor
  killed the runner in its write and no one was told: a shutdown of two arrays of 65,536
  retained timers, some 15 s of work here, ends at the write limit, 5 s, reported, and
  with `write_limit: 30_000` writes its store. RV-6 makes the write itself cheaper
  (decision 352).
  """
  def child_spec(opts),
    do: Map.put(super(opts), :shutdown, shutdown_ms(opts))

  @shutdown 5000
  @longest 4_294_967_295

  defp shutdown_ms(opts) when is_list(opts), do: shutdown_ms(Keyword.keyword?(opts), opts)
  defp shutdown_ms(_opts), do: @shutdown

  # c1-runner-rounds-6 (RV-4): never more than the longest a supervisor waits, 2^32 - 1 ms,
  # which a long idle watchdog and poll period over many devices passed. Decision 400
  # (RV-11): the writer's write and the store's own each given the write limit, decision
  # 353's limit on them, where each was given the idle watchdog and a poll period.
  defp shutdown_ms(true, opts) do
    each = within(Keyword.get(opts, :idle), 500) + within(Keyword.get(opts, :poll), 10)
    writes = 2 * within(Keyword.get(opts, :write_limit), @write_limit)
    min(@longest, max(@shutdown, bound(Keyword.get(opts, :io)) * each + writes))
  end

  defp shutdown_ms(false, _opts), do: @shutdown

  defp within(ms, _default) when is_integer(ms) and ms in @interval, do: ms
  defp within(_ms, default), do: default

  defp bound(io) when is_map(io), do: map_size(io)
  defp bound(_io), do: 0

  # M6-5 (decisions 271 and 291): a fresh start with `start: :cold`, or with no store file,
  # writes the store before any device is opened; a write that fails starts nothing,
  # `{:error, {:retain, reason}}`, the store as it was. Since M11 (RV-4) the write is the
  # runner's own, in its init/1, once its name is registered and its files claimed, so
  # that a start refused, `{:already_started, pid}` or another runner's file, writes
  # nothing over the running runner's store.
  defp first_write(%{retain: %{at: path}, at: %DateTime{} = at, runtime: runtime} = start),
    do:
      Writer.written(
        path,
        Logex.Retain.encode(Runtime.retained(runtime), at),
        start.write_limit
      )

  defp first_write(_start), do: :ok

  defp first_written(%{at: %DateTime{} = at, retain: retain} = start),
    do: %{start | retain: %{retain | written_at: at}}

  defp first_written(start), do: start

  # Decision 360 (RV-5): a fresh start that dropped anything from its store (decision
  # 277's matching, `status/1`'s `dropped`) copies the store, as it read it, before its
  # first write over it, here in its init/1, before any device is opened, so that a
  # mistaken deploy's drops can be taken back from the copy after the next write has made
  # the store the new configuration's. Since decision 418 (RV-13) each copy is a name of
  # its own, `<store>.dropped.<n>`, n one past the highest that stands, and none is
  # replaced, where one `<store>.dropped` was replaced at each start that dropped
  # (`Writer.copy/3`); a copy stays until the host deletes it, and a start that makes none
  # leaves every one as it is. The copy is a write as every other, through
  # `<store>.dropped.tmp`, the one `.tmp` of the copies (decision 392), synced and renamed
  # to its name, limited to the idle watchdog and a poll period of real time (decision
  # 353), since decision 400 to the write limit. `status/1`'s `retain` names the copy the
  # start made, `copy`, its path as the host spelled the store, `plant.retain.dropped.2`,
  # or nil where its write failed, the failure then `failed` as any failed write's, and the
  # start goes on; since decision 412 `copy` is always there, nil too where the start
  # dropped nothing, where it was a key only a start that dropped had. Since RV-5's review
  # a copy that fails is owed, its text kept under `retain`'s `owed`, and every write over
  # the store, the period's, a trip's, a stop's, a shutdown's and a cold restart's, makes
  # the copy first, numbered as it is made, and writes the store only once it is made
  # (`Writer.stored/4`, noted/3), so that no write replaces the store before its copy is
  # made, as decision 360 has it, where one did and the drops were lost; the start still
  # goes on, decision 275's rule for a failed write, decision 416's.
  defp dropped_copy(%{copy: text, retain: retain} = start) when is_binary(text) do
    copied = Writer.copied(retain.at, text, start.write_limit)
    %{start | copy: nil, retain: copy_made(copied, text, retain)}
  end

  defp dropped_copy(start), do: start

  defp copy_made({:ok, n}, _text, retain), do: Map.put(retain, :copy, Paths.copy(retain.path, n))

  # Decision 391 (RV-11): a copy past its limit may yet land, so it is owed as one that
  # failed is and named `unknown`, neither failed nor made, until a later write makes it;
  # since decision 418 by the number it took, and one killed before it took a number,
  # which can land nowhere, is a copy that failed, `:timeout` (provisional).
  defp copy_made({:unknown, n}, text, retain),
    do: unknown(Map.merge(retain, %{copy: nil, owed: text}), Paths.copy(retain.path, n))

  defp copy_made({:error, reason}, text, retain),
    do: Map.merge(retain, %{copy: nil, failed: reason, owed: text})

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
  Since RV-4 stops made at once each answer (c1-runner-rounds-10): the first's reason
  stops the runner, and each other that named itself to the runner in time is given its
  answer, one ended by another's orderly stop otherwise `:ok`; one that finds the runner
  gone already raises that it is not running, as a stop of a stopped runner does.

  Since M6-5 (decisions 116 and 275) a runner given `retain:` then writes its store, of
  the resource as the stop found it, the zeros and the closes first, so that no store
  write keeps an output on, and the stop answers `:ok`, or `{:error, {:retain, reason}}`
  where the write failed, the runner stopped all the same; one with no store answers
  `:ok` as before; since decision 391 a write past its limit, `{:error, {:retain,
  :timeout}}`, may still land once the disk answers, so that the store is then the old or
  the stop's own, unknown; and since decision 414 the stop's write makes the store's text
  within the write limit too, the retained image taken out and written in the write's own
  process, so that a store too big to make within the limit answers `{:error, {:retain,
  :timeout}}` at it, the store keeping its last write. The stop is still a system
  message, served when the runner reaches it, never held for a slot and served by a
  runner suspended too: its caller names itself to the runner first, and the runner
  answers it as it terminates, a call in effect only,
  since a call would wait on a suspended runner for ever (decision 321). A clock gone by
  the time the store is written names no time, so that write is none and the stop answers
  `{:error, {:retain, {:clock, reason}}}`, the runner stopped by the stop's reason all the
  same (c1-runner-rounds-5).
  """
  def stop(runner, reason \\ :normal) do
    pid = runner!(runner)
    ref = make_ref()
    send(pid, {__MODULE__, :stopping, self(), ref})
    stopped(stopping(pid, reason), ref, pid)
  end

  # c1-runner-rounds-10 (RV-4): a runner another stop/2, or anything else, ended while
  # this one asked, whose exit GenServer.stop/3 gives this caller as its own, is stopped.
  defp stopping(pid, reason) do
    GenServer.stop(pid, reason, :infinity)
  catch
    :exit, {ended, {GenServer, :stop, _args}} -> {:ended, ended}
  end

  # The stop's answer, which the runner sends as it terminates, after its zeros, its closes
  # and its store's write, to every stop that named itself to it by then; a runner that
  # went down by itself meanwhile sends none. One ended meanwhile by another's orderly stop
  # is `:ok`, that stop's answer its own; one gone for any other reason, a crash, a kill or
  # gone before this call reached it, is a runner that is not running. A runner that ends
  # while this stop's request waits in its mailbox ends the request with its own reason,
  # `{reason, {:sys, :terminate, args}}`, which is read for that reason (RV-4's review:
  # only the bare reason was, which no stop meets).
  defp stopped(:ok, ref, _pid), do: answer_of(ref, :ok)
  defp stopped({:ended, ended}, ref, pid), do: answer_of(ref, orderly(ended, pid))

  defp answer_of(ref, otherwise) do
    receive do
      {^ref, reply} -> reply
    after
      0 -> relayed(otherwise)
    end
  end

  defp orderly({ended, {:sys, :terminate, _args}}, pid), do: orderly(ended, pid)
  defp orderly(:normal, _pid), do: :ok
  defp orderly(:shutdown, _pid), do: :ok
  defp orderly({:shutdown, _term}, _pid), do: :ok
  defp orderly(_gone, pid), do: gone(pid)

  @doc """
  The runner's status, a map: `status`, `:running`, or `:tripped` from a trip until a
  restart; `now`, the resource's time; `rounds`, the rounds run, a round that tripped
  not among them; `trip`, the trip's reason, nil while running; `overlaps`, each task's
  (`Logex.Runtime.overlaps/1`);
  `forces`, every force, by its point's name, with its value; since decision 390, where
  the last start or restart could not read the forces file, `forces_unread`, `{path,
  reason}`, until a force's or an unforce's write of it lands or a restart reads it, and
  no such key otherwise; since decision 391, where a force's write ran past its limit
  and may yet land, `forces_unknown`, the set it held, until a later write of the file
  lands or fails or a restart reads it, and no such key otherwise; `edit`, the stage of the
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
  (decisions 275 and 277); and since decision 360 `copy`, always there since decision
  412: the copy of the store the fresh start made before its first write, since decision
  418 `<store>.dropped.<n>`, its own number, as the host spelled the store, nil where the
  start dropped nothing,
  and nil while the copy is owed, its write having failed, its reason then `failed` as
  any failed write's, until a write over the store makes it first, `dropped` and `failed`
  telling the two nils apart; and since decision 391, where the last write
  over the store or its copy ran past its limit and may yet land, `unknown`, that file's
  path as the host spelled it, `failed` then nil, until a later write lands or fails, and
  no `unknown` otherwise.
  """
  def status(runner), do: call(runner, :status)

  @doc """
  Subscribes the caller to the runner's events of the kinds named, each sent as
  `{Logex.Runner, runner, event}`: `:overlap` and `:fault`, the resource's own, and
  `:trip`, `:restart`, `:edit` and `:retain`, `{:retain, {:error, reason}}`, a store
  write that failed, by default; `:ran`, the resource's `{:ran, task,
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
  Forces an input point, by its name, to `value`, whatever its device says, from the
  first round after its write lands until it is unforced, across a restart and, kept in
  the forces file, across a crash and a fresh start (decisions 117 and 127): the whole
  set of forces is written to the file before it returns, `:ok`, or `{:error, {:forces,
  reason}}` where it cannot be, the force not taken, `{:error, {:forces, :timeout}}`
  where the disk has not finished the write within the write limit of real time,
  `write_limit:` (decisions 353 and 400), the rounds running on meanwhile on the forces
  as they were (decision 437), a force asked while another's write is out waiting behind
  it. A
  force that changes what an event task's trigger reads is a change of it, and makes its
  round at once, before it returns (decisions 120 and 138). A runner started without
  `forces:`, an output point, a name that is no input point and a value that does not fit
  are the host's mistakes. Since decision 241 a located array of input points named whole,
  `"zone_t"`, is forced to a list of its shape in the elements' order, each element then
  forced as its own point, nothing forced where its shape or any element does not fit.
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
  release, opened again, each read or opened within its own `open:` (decisions 398 and
  439), the resource restarted
  (`Logex.Runtime.restart/2`, which keeps the input image and puts every other global
  back to its initial value), `{:restart, mode}` sent to the subscribers, and the first
  round run at once, on what was read, before it returns, the clock not counting the time
  it was stopped, so that round's elapsed time is 0. `:ok`, or `{:error, {:io_init,
  device, reason}}` for the first device, in device-name order, that cannot be opened or
  whose read fails, the runner left tripped with its first reason and every device that
  answers written 0 once more (decisions 136 and 142), and since decision 394 `{:error,
  {:clock, cause}}` while its clock still answers no time, the runner left tripped; a
  runner that is running is the host's mistake (decision 133), judged as the restart arrives, so that one asked while
  it runs is refused whatever comes before it is served, a trip among it, which refuses
  every restart that reached the runner before it, waiting in its mailbox or its queue,
  and the trip stands until a restart asked after it (decision 354). It reads the forces
  file again first, as every start does (decision 127): a force it cannot take is raised
  here, the runner left tripped, and since decision 390 a read that fails, one the disk
  has not finished within the write limit of real time (decisions 353 and 400) or one the
  file system refuses, keeps the forces the runner holds and goes on, `status/1` naming
  the file, `forces_unread`, where it answered `{:error, {:forces, :timeout}}` and left
  the runner tripped. Since M6-5 a cold restart of a
  runner given `retain:` then writes its store, of the resource
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
    held(Paths.claim(start.files, self()), Map.put(start, :beat, beat()))
  end

  # Decision 348's renewal (RV-4's review): the one shared write by which the runner renews
  # every device's deadline while it writes a round's devices, the deadline and the time
  # it renewed at, made once at the start, kept by every restart and every edit, as the
  # runner's devices are, and never written but by renew/2; a device takes a renewal only
  # where it was made after the refresh it last heard (`Logex.Runner.Device`), so one from
  # before a trip or a restart is never taken after it. Its time starts at the least an
  # `:atomics` holds, before every time on any clock.
  @never -9_223_372_036_854_775_808

  defp beat do
    beat = :atomics.new(2, signed: true)
    :atomics.put(beat, 2, @never)
    beat
  end

  # Decision 356: the runner's files claimed, all or none, once its name is registered, a
  # file another runner of this VM holds refused before anything is written; then the
  # fresh start's write, M11's, and the devices opened. A start that ends here, refused or
  # unable to write or to open a device, gives its files up at once, so that a start made
  # right after it finds them free.
  defp held({:held, path, holder, role}, start),
    do: {:error, {:held, held_told(named_entry(start.named, path), holder, role)}}

  defp held(:ok, start), do: given_up(cold_begun(cold_copy(start)), start)

  defp cold_begun({:ok, start}), do: first_begun(first_write(start), dropped_copy(start))
  defp cold_begun({:error, reason}), do: {:error, {:retain, reason}}

  defp first_begun(:ok, start), do: opening(start.devices, [], [], first_written(start))
  defp first_begun({:error, reason}, _start), do: {:error, {:retain, reason}}

  # Decision 417 (RV-13): a cold start, `start: :cold`, over a store that stands and that
  # a fresh start would refuse, cut short (decision 355) or refused by any of the store's
  # refusals or the image's (`Logex.Retain.decode!/2`, `Logex.Runtime.start/2`), copies it
  # first, as decision 360 copies a store a fresh start drops from, under decision 418's
  # next number, here in its init/1 once its files are claimed, and writes the store only
  # once the copy is made, so that the readable part of a store a cut left is never lost
  # to the start the refusal's remedy names; a copy that cannot be made is judged as
  # decision 291 judges a cold start whose first write fails, the runner not started,
  # `{:error, {:retain, reason}}`, the store as it was and no device opened, a copy past
  # its limit among them, `:timeout`, and a store that stands but cannot be read, which no
  # copy can be made of, the read's reason (provisional). `status/1`'s `copy` names the
  # copy, `dropped` empty. A store that reads whole needs none: decision 360 copies only
  # what a start drops, and a cold start over a whole store makes no copy, as before.
  defp cold_copy(%{copy: {:cold, text}, retain: retain} = start),
    do: cold_copied(Writer.copied(retain.at, text, start.write_limit), start)

  defp cold_copy(%{copy: {:unread, reason}}), do: {:error, reason}
  defp cold_copy(start), do: {:ok, start}

  defp cold_copied({:ok, n}, %{retain: retain} = start),
    do: {:ok, %{start | copy: nil, retain: %{retain | copy: Paths.copy(retain.path, n)}}}

  defp cold_copied({:unknown, _n}, _start), do: {:error, :timeout}
  defp cold_copied({:error, reason}, _start), do: {:error, reason}

  defp given_up({:ok, _state} = opened, _start), do: opened

  defp given_up(failed, start) do
    Paths.release(start.files, self())
    failed
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

  # Decision 354: a restart is judged as it arrives, the runner's status then kept with it,
  # so that one asked while the runner runs is refused whatever comes before it is served,
  # a trip among it, and a trip stands until a restart asked after it.
  def handle_call({:restart, mode}, from, state) when mode in [:cold, :warm],
    do: {:noreply, requested(owed(state), {from, {:restart, mode, state.status}}, state)}

  # A host's request is the runner's own work: served at once where no round is owed, and
  # otherwise queued for the share's slot (decision 122).
  def handle_call(request, from, state),
    do: {:noreply, requested(owed(state), {from, request}, state)}

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
  def handle_info({Device, pid, restarts, at, {kind, name, _}} = notice, state)
      when notice?(pid, restarts, at, kind, name),
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

  # Decision 353, since RV-4's review: the period's write not answered within its limit.
  def handle_info(
        {Writer, :late, token},
        %{retain: %{period: %{busy: true, late: {_timer, token}}}} = state
      ),
      do: {:noreply, late_writer(state)}

  # Decision 394 (RV-11): the clock answered no time the runner can hold, the runner's own
  # read or a device's (exited/4): a trip naming it, one tripped already keeping its first
  # reason.
  def handle_info({__MODULE__, :clock, cause}, state),
    do: {:noreply, tripped(state, {:clock, cause})}

  # Decision 437 (RV-16): the force's write of the forces file answered, by its process's
  # exit, or cut at its limit; a timer of a write answered already is stale.
  def handle_info({:DOWN, ref, :process, pid, reason}, %{writing: %{write: {pid, ref}}} = state),
    do: {:noreply, forces_landed(Writer.ended({pid, ref}, reason), state)}

  def handle_info({Writer, :forces_late, ref}, %{writing: %{write: {_pid, ref} = write}} = state),
    do: {:noreply, forces_landed(Writer.cut(write), state)}

  def handle_info({Writer, :forces_late, _stale}, state), do: {:noreply, state}

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
  def terminate(reason, %{queue: queue, behind: behind} = state) do
    for {from, _request} <- :queue.to_list(queue) ++ :queue.to_list(behind),
        do: GenServer.reply(from, gone(self()))

    state = each_live(state, &Device.close/2)
    answered_stop(stoppers(state.stoppers), reason, state)
    writer_stopped(state)
    forces_ended(state)
    Paths.release(state.files, self())
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
    reply = stop_written(state)
    for {pid, ref} <- stoppers, do: send(pid, {ref, reply})
  end

  # c1-runner-rounds-5, c2-runner-persist-2 (RV-4): a clock gone as the stop writes names
  # no time, so the stop's write is none, answered as a write that failed, the runner
  # stopped by its stop's reason all the same, where the clock's exit escaped to the caller.
  defp stop_written(state) do
    {reply, _state} = kept_store(state, state.runtime, :end)
    reply
  catch
    :exit, {:shutdown, {:clock, reason}} -> {:error, {:retain, {:clock, reason}}}
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
    kept_store(state, state.runtime, :end)
    :ok
  catch
    :exit, {:shutdown, {:clock, _reason}} -> :ok
  end

  # A request served at once is refreshed at the time owed/1 read, where it read one, so
  # that the look for a due round costs no reading more (RV-11's review).
  defp requested(:owed, request, state), do: %{state | queue: :queue.in(request, state.queue)}

  defp requested({:free, at}, request, state),
    do: answered(request, refresh(state, at, state.idle))

  defp requested(:free, request, state), do: answered(request, refresh(state, :idle))

  # Each request answered; one that took longer than the idle watchdog, served whole,
  # trips the runner once it is answered, `{:watchdog, {:idle, ms}}` (decision 128). A
  # restart is the tripped runner's own, its first round timed by its steps' watchdogs.
  defp answered({from, {:restart, _mode, _asked} = request}, state) do
    {reply, state} = served(request, state)
    GenServer.reply(from, reply)
    state
  end

  # Decision 437 (RV-16): a force, an unforce or an unforce_all that comes while a write of
  # the forces file is out waits behind it, in order, each served once the one before it
  # is answered (forces_landed/2), so that each write builds on the set the last one left
  # and no two are out at once (provisional, the record silent on a second force).
  defp answered({_from, request} = asked, %{writing: %{}} = state) when forcing?(request),
    do: %{state | behind: :queue.in(asked, state.behind)}

  # Decision 437 (RV-16): a force's request is served once its write is begun, the rounds
  # running on while it is out, and answered when the write is (forces_landed/2): its
  # time, the idle watchdog's, is its own work alone, the disk's never among it, where
  # since decision 400 the runner waited on the disk inside it and left the wait out.
  defp answered({from, request}, state) do
    begun = now(state)
    {reply, state} = served(request, state)
    took = now(state) - begun
    idled(took, replied(reply, from, state))
  end

  defp replied({__MODULE__, :writing, forces, names}, from, state),
    do: writing(forces, names, from, state)

  defp replied(reply, from, state) do
    GenServer.reply(from, reply)
    state
  end

  # A force or unforce that changed what a trigger reads makes a round at once, before its
  # call returns, a force of a trigger being a change of it (decisions 117 and 120), since
  # decision 437 once its write has landed (forces_landed/2); each
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
    name = by_value(name, state)
    forcing(input(name, state), name, value, state)
  end

  defp serve({:unforce, name}, state) do
    filed!(state)
    name = by_value(name, state)
    unforcing(input(name, state), name, state)
  end

  defp serve(:unforce_all, state) do
    filed!(state)
    kept(state, %{}, Map.keys(state.forces))
  end

  # Decision 133: a restart asked while the runner runs is the host's mistake, judged as it
  # arrived (decision 354), whatever has come since.
  defp serve({:restart, _mode, :running}, _state),
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
  # reads its device's last value again. Since decision 353 the read is the runner's own
  # file call, limited as its writes are, since decision 400 to the write limit. It is
  # raw, so that the VM's file server, busy with every other process's calls, is not on
  # its way. Decision 390 (RV-11): a read that fails, one not made within the write limit
  # or one the file system refuses, a directory or a file it may not read in the file's
  # place, keeps the forces the runner holds, and the restart goes on, the line coming
  # back, the file it could not read reported in `status/1`, `forces_unread`, where the
  # restart answered `{:error, {:forces, :timeout}}`, or raised that the file cannot be
  # read, and left the runner tripped.
  defp serve({:restart, mode, :tripped}, state), do: mended(clock_answer(state), mode, state)

  defp serve(other, _state),
    do:
      raise(
        ArgumentError,
        "Logex.Runner has no request #{inspect(other)}: a runner is called through " <>
          "get/2, get!/2, status/1, subscribe/2, unsubscribe/1, force/3, unforce/2, " <>
          "unforce_all/1, accept/2, test/1, untest/1, assemble/1, cancel/1, restart/2 and " <>
          "stop/2"
      )

  # Decision 394 (RV-11): a restart once its clock answers a time again.
  defp mended(:ok, mode, state) do
    clock_notices_dropped()
    restarting_with(forces_at_restart(state), mode, state)
  end

  defp mended({:error, cause}, _mode, state), do: {{:error, {:clock, cause}}, state}

  # M6-5 (decisions 271 and 291): a cold restart writes the store, of the resource as the
  # restart will start it, before it releases or reads any device; a write that fails
  # leaves the runner tripped as it was, `{:error, {:retain, reason}}`, the store as it was
  # and every output still 0. A warm restart writes none.
  defp cold_store(_mode, %{retain: nil} = state), do: {:ok, state}
  defp cold_store(:cold, state), do: kept_store(state, Runtime.restart(state.runtime, :cold))
  defp cold_store(:warm, state), do: {:ok, state}

  defp forces_at_restart(%{file: nil}), do: {%{}, nil}

  defp forces_at_restart(%{forces_at: path} = state),
    do:
      forces_text(
        Writer.within(fn -> :file.read_file(path, [:raw]) end, state.write_limit),
        state
      )

  # The forces a restart takes and the file it could not read, nil where it read it or
  # found none: a read made, the file's forces; a file that does not exist, none; and a
  # read that failed, the forces the runner holds (decision 390). A read made takes the
  # file's whatever the runner held, the file being what is forced at each start
  # (decision 127), so that after a fresh start that could not read it the next restart
  # that can takes the forces the file held then (provisional, RV-11's review).
  defp forces_text({:ok, _text} = read, state), do: {forces_read(read, state.file, state), nil}
  defp forces_text({:error, :enoent}, _state), do: {%{}, nil}
  defp forces_text({:error, reason}, state), do: {state.forces, {state.file, reason}}

  # Decision 391: a restart that reads the file, or finds none, knows what it holds.
  defp known(nil, _unknown), do: nil
  defp known(_unread, unknown), do: unknown

  defp restarting_with({forces, unread}, mode, state),
    do: restarting(cold_store(mode, state), mode, forces, unread)

  defp restarting({{:error, _reason}, _state} = failed, _mode, _forces, _unread), do: failed

  defp restarting({:ok, state}, mode, forces, unread) do
    unforced = Map.keys(state.forces) -- Map.keys(forces)

    restarted(mode, %{
      state
      | forces: forces,
        forces_unread: unread,
        forces_unknown: known(unread, state.forces_unknown),
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
      |> recounted(state.untimed)
      |> longest()

    published(state, [{:edit, step, report}])
    replanned(state)
  end

  # Decision 396 (RV-11's review): the share's count is of the continuous task's rounds,
  # or with no untimed program of the periodic rounds whole, so a step that adds the
  # first untimed program or takes away the last begins it again, the rounds it counted
  # being of the other kind: a plant of timed rounds alone edited to add a continuous
  # program is served its first slot C ms of the continuous task's rounds after the
  # step, as before decision 396 (provisional).
  defp recounted(%{untimed: same} = state, same), do: state
  defp recounted(state, _was), do: %{state | used: 0}

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

  # Decision 384 (the maintainer, 2026-11-01): an element of a located array of input points
  # named by numbers otherwise than as its subscripts' values, `temps[03]`, is the point of
  # their values, `temps[3]` (`Logex.Name.by_value/1`), forced, unforced, kept and shown in
  # `status/1` under that name, where until RV-10 it was no input point; a name that is
  # none either way is told as the host wrote it.
  defp by_value(name, %{types: types}) when is_binary(name) and not is_map_key(types, name),
    do: known_point(Logex.Name.by_value(name), name, types)

  defp by_value(name, _state), do: name

  defp known_point(point, _name, types) when is_map_key(types, point), do: point
  defp known_point(_point, name, _types), do: name

  # An input point, by its name: `{:ok, type}`, or what the name is instead, told, the name
  # as `force/3` gives it; since RV-5's review a forces file's line's name told as the
  # file's text is (`Logex.Refusal.shown/1`, at most 60 bytes), `shown`.
  defp input(name, state), do: input(name, name, state)

  defp input(name, shown, %{types: types} = state) when is_binary(name),
    do: input_of(Map.fetch(types, name), {name, shown}, state)

  defp input(other, _shown, _state),
    do:
      {:error,
       "a force names an input point by its name, a string, as in \"eye_1\", got: " <>
         inspect(other)}

  defp input_of({:ok, type}, _name, _state), do: {:ok, type}

  defp input_of(:error, {name, _shown} = named, state),
    do: whole_input(Map.fetch(state.arrays, name), named, state)

  # Decision 241: a located array of input points, named whole, `{type, dims, names}`, its
  # elements' type and sizes and each element's name in the elements' order.
  defp whole_input({:ok, array}, _name, _state), do: {:array, array}

  # Since the review of RV-10 a name that is no input point is looked up by its
  # subscripts' values (decision 384), `lamps[02]` told it is the output point `lamps[2]`
  # and `Temps[03]` offered `temps[3]`, each by the name as written.
  defp whole_input(:error, {name, _shown} = named, state),
    do: {:error, not_input(Map.fetch(state.located, Logex.Name.by_value(name)), named, state)}

  defp not_input({:ok, {:point, at}}, {_name, shown}, _state),
    do: "`#{shown}` is an output point, at `#{at}`: only an input point is forced"

  defp not_input({:ok, {:array, :output, {_first, from}, {_last, to}}}, {_name, shown}, _state),
    do:
      "`#{shown}` is an array of output points, `#{from}` to `#{to}`: only an input point " <>
        "is forced"

  defp not_input(:error, {name, _shown} = named, %{configuration: configuration} = state),
    do:
      unheld(
        element_of(Logex.Name.element(name), state.located),
        named,
        {state.types, configuration}
      )

  defp element_of({array, _subscripts}, located), do: Map.get(located, array)
  defp element_of(nil, _located), do: nil

  # M5-13: an element a located array of input points does not hold, as written.
  defp unheld({:array, :input, {first, _from}, {last, _to}}, {_name, shown}, {_, configuration}),
    do:
      "`#{shown}` is no input point of `#{configuration.name}`: its array is one of input " <>
        "points, each element forced by its name as its subscripts' values, `#{first}` to " <>
        "`#{last}`"

  defp unheld(_other, name, {types, configuration}),
    do: no_input(Map.keys(types), name, configuration)

  defp no_input([], {_name, shown}, configuration),
    do:
      "`#{shown}` is no input point of `#{configuration.name}`, which has none: only an " <>
        "input point is forced"

  defp no_input(names, {name, shown}, configuration),
    do:
      "`#{shown}` is no input point of `#{configuration.name}`" <>
        Declarations.suggest(Logex.Name.by_value(name), Enum.sort(names), & &1, "names")

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
  # its own round (decision 120), in kicked/1. Since decision 437 (RV-16) the write is
  # begun here and the request answered once it is (replied/3, forces_landed/2).
  defp kept(state, forces, names), do: {{__MODULE__, :writing, forces, names}, state}

  # The forces file, written whole: one force a line, `name value`, in name order, to a file
  # beside it, flushed to the disk and renamed over it, so that a crash at any moment leaves
  # the old set or the new (decision 127); a write that fails leaves the file as it was, and
  # since decision 353 one not made within the runner's write limit of real time, since
  # decision 400 `write_limit:`, fails, `:timeout`, the runner answering on. Decision 437
  # (RV-16): the write begun in a process of its own (`Logex.Runner.Writer.begun/2`),
  # and the rounds run on while it is
  # out, so that the logic keeps the plant under control on a slow disk, every force read
  # as it was until the write lands: the runner takes its answer as a message, or cuts it
  # at the write limit of real time, counted from before its process is made as every
  # write's is (decision 414), its end the millisecond at or after it, so that the write
  # is given its whole limit, a timer of the VM's own, never the runner's clock, and the
  # caller waits for it as it did while the runner waited (forces_landed/2). Every device
  # is refreshed by the rounds and the waits as ever meanwhile, so that the write needs
  # none of decision 400's renewals, and no time of the disk's is any request's.
  defp writing(forces, names, from, %{forces_at: path, types: types} = state) do
    text =
      IO.iodata_to_binary(
        for(
          {name, value} <- Enum.sort(forces),
          do: [name, ?\s, spelled_force(Map.fetch!(types, name), value), ?\n]
        )
      )

    until = div(System.monotonic_time(:microsecond) + 1000 * state.write_limit + 999, 1000)
    {_pid, ref} = write = Writer.begun(path, text)
    timer = Process.send_after(self(), {Writer, :forces_late, ref}, until, abs: true)

    %{
      state
      | writing: %{
          write: write,
          timer: timer,
          until: until,
          from: from,
          forces: forces,
          names: names
        }
    }
  end

  # Decision 437 (RV-16): the write's answer taken, or the write cut at its limit, and the
  # force taken or not as the answer says (taken/4), its caller answered, the triggers it
  # changed each making its round first (kicked/1), so that a force is in effect from the
  # first round after its write lands and in none before, the file holding it first
  # (decision 117); and the next request that waited behind it served, in order. A trip,
  # a restart and an edit's step made while it was out leave it as it was: it is taken,
  # or not, as its answer says, onto the set the runner then holds.
  defp forces_landed(result, %{writing: writing} = state) do
    Process.cancel_timer(writing.timer)
    {reply, state} = taken(result, writing.forces, writing.names, %{state | writing: nil})
    state = kicked(state)
    GenServer.reply(writing.from, reply)
    behind(:queue.out(state.behind), state)
  end

  defp behind({:empty, _behind}, state), do: state

  defp behind({{:value, asked}, rest}, state),
    do: behind_served(answered(asked, %{state | behind: rest}))

  # One served behind whose write is not out, a host's mistake raised in its caller, lets
  # the next be served.
  defp behind_served(%{writing: nil} = state), do: behind(:queue.out(state.behind), state)
  defp behind_served(state), do: state

  # Decision 437 (RV-16): a runner that stops while a force's write is out waits for it to
  # its own limit, which began before the stop, and answers its caller as the write ends,
  # so that no write is renamed into a file once the runner has given it up (decision
  # 356); the forces' requests that waited behind it are answered as to a runner that is
  # not running, as the requests waiting for the share's slot are (provisional).
  defp forces_ended(%{writing: nil}), do: :ok

  defp forces_ended(%{writing: writing} = state) do
    result = Writer.awaited(writing.write, writing.until)
    {reply, _state} = taken(result, writing.forces, writing.names, state)
    GenServer.reply(writing.from, reply)
  end

  # Decision 391 (RV-11): a force's write past its limit may yet land once the disk
  # answers, the file the old set or the new: `status/1` names the set it held,
  # `forces_unknown`, the force not taken, until a later write of the file lands or fails
  # or a restart reads it; one that failed changed nothing, and is known.
  defp taken({:error, :timeout}, forces, _names, state),
    do: {{:error, {:forces, :timeout}}, %{state | forces_unknown: forces}}

  defp taken({:error, reason}, _forces, _names, state),
    do: {{:error, {:forces, reason}}, %{state | forces_unknown: nil}}

  defp taken(:ok, forces, names, state) do
    before = Enum.map(names, &seen(&1, state))
    unforced = Enum.reject(names, &Map.has_key?(forces, &1))

    # Decisions 390 and 391: the file written whole, the runner's set, reported unread or
    # unknown no more.
    state = %{
      state
      | forces: forces,
        forces_unread: nil,
        forces_unknown: nil,
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
  # (decision 127): a file that does not exist is no force; a line that is no force, a
  # point forced twice, and a force the configuration cannot take are the host's
  # mistakes, every one named, a line each, the runner not started or left tripped. Since
  # RV-4's review the start's read is raw and limited as the restart's is (decision 353),
  # so that a FIFO or a stalled disk in its place holds neither the caller for ever nor,
  # through the VM's file server, every other process's file calls. Decision 390 (RV-11):
  # a read that fails, one not made within the write limit (decision 400) or one the
  # file system refuses, a directory or a file it may not read in the file's place,
  # starts the runner with no force, the file it could not read reported in `status/1`,
  # `forces_unread`, where the start was refused as the host's mistake; and so does a
  # look at it for a link that the disk does not answer in time, its read then not made.
  # A link it is stays the host's mistake (RV-5).
  defp forces_looked(nil, nil, _ms), do: :ok

  defp forces_looked(given, at, ms),
    do: looked(Writer.read(fn -> :file.read_link_info(at, [:raw]) end, ms), given)

  defp looked({:error, :timeout}, _given), do: {:unread, :timeout}
  defp looked(info, given), do: link!(info, given, :forces)

  defp read_forces(_looked, nil, nil, _points, _ms), do: {%{}, nil}
  defp read_forces({:unread, reason}, path, _at, _points, _ms), do: {%{}, {path, reason}}

  defp read_forces(:ok, path, at, points, ms),
    do: start_forces(Writer.read(fn -> :file.read_file(at, [:raw]) end, ms), path, points)

  defp start_forces({:ok, _text} = read, path, points), do: {forces_read(read, path, points), nil}
  defp start_forces({:error, :enoent}, _path, _points), do: {%{}, nil}
  defp start_forces({:error, reason}, path, _points), do: {%{}, {path, reason}}

  # A read past its limit told with the limit, for its refusal's words (decision 400).
  defp timed_out({:error, :timeout}, ms), do: {:error, {:timeout, ms}}
  defp timed_out(read, _ms), do: read

  # Since RV-5 the refusal bounded and printable as the store's is (`Logex.Refusal`,
  # b3-store-image-11): its first 50 problems and then their count, each text of the file
  # it quotes at most 60 bytes and printable.
  defp forces_read({:ok, text}, path, points) do
    {forces, _lines, problems} =
      text
      |> forces_lines()
      |> unended()
      |> Enum.with_index(1)
      |> Enum.reduce({%{}, %{}, []}, &force_line(&1, &2, points))

    forces_taken(Enum.reverse(problems), path, forces)
  end

  # Decision 410 (RV-13): the file's lines end with LF, CRLF or a lone CR alike, as B8 has
  # the source's and a configuration file's readers read them and as the store's are
  # (`Logex.Retain`), so that `hz 1.5` saved with CRLF line ends forces 1.5, where M5-11's
  # review read the carriage return after its value as no force; the runner writes LF.
  defp forces_lines(text), do: String.split(text, ["\r\n", "\r", "\n"])

  # The text after the last line end, empty in a file the runner wrote, is no line.
  defp unended(lines), do: unended(List.last(lines), lines)
  defp unended("", lines), do: Enum.drop(lines, -1)
  defp unended(_last, lines), do: lines

  # A line holding a byte no forces file holds, a tab, any other control byte or one past
  # ASCII, is no force (RV-5), told before its name is read, so that a refusal quotes no
  # such byte raw; a tab after a value was no force before (M5-11's review), quoted as it
  # is. A carriage return ends a line since decision 410, so no line holds one.
  defp force_line({text, line}, acc, points),
    do: force_text(Logex.Refusal.unprintable(text), {text, line}, acc, points)

  defp force_text(:nomatch, {text, line}, acc, points),
    do: force_read(parsed(String.split(text, " ")), text, line, acc, points)

  defp force_text(_byte, {text, line}, acc, _points), do: force_read(:error, text, line, acc, nil)

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
    do: {forces, lines, [{line, Logex.Refusal.quoted(text) <> " " <> no_force()} | problems]}

  # A line of several values naming no located array is no force, as before decision 241,
  # and an array of output points is told what it is.
  defp force_read({:ok, name, {:list, _}}, text, line, {forces, lines, problems}, points)
       when not is_map_key(points.located, name),
       do: {forces, lines, [{line, Logex.Refusal.quoted(text) <> " " <> no_force()} | problems]}

  defp force_read({:ok, name, value}, text, line, acc, points) do
    name = by_value(name, points)
    read_point(input(name, Logex.Refusal.shown(name), points), {name, value, text}, line, acc)
  end

  # A line's point: an input point's, or, since decision 241, each element of a located
  # array of input points named whole; a line with more than one value names such an array.
  defp read_point({:ok, _type}, {_name, {:list, _}, text}, line, {forces, lines, problems}),
    do: {forces, lines, [{line, Logex.Refusal.quoted(text) <> " " <> no_force()} | problems]}

  # Since the review of RV-10 a point forced twice is told by its name as the later line
  # writes it, `temps[003]`, where until then by its point's (decision 384).
  defp read_point({:ok, _type} = point, {name, value, text}, line, acc),
    do:
      once(
        as_written(first_line([name], acc), text),
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

  defp as_written(nil, _text), do: nil
  defp as_written({_name, first}, text), do: {hd(String.split(text, " ")), first}

  defp once({name, first}, _names, line, {forces, lines, problems}, _problem),
    do:
      {forces, lines,
       [{line, "`#{Logex.Refusal.shown(name)}` is forced on line #{first} already"} | problems]}

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
      |> Logex.Array.capped(&more_misfits(Logex.Refusal.shown(name), {:array, type, dims}, &1))

    whole_force(misfits, names, Enum.map(values, &forced(type, &1)))
  end

  defp force_problem({:array, {type, dims, names}}, name, value, _spellings),
    do: [
      "`#{Logex.Refusal.shown(name)}` is #{Declarations.a_type({:array, type, dims})}, " <>
        "forced whole on one line, " <>
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
  # Since RV-5's review the name, the spelling and the value read each told as the file's
  # text is, at most 60 bytes (`Logex.Refusal.shown/1`), where a long one was told whole.
  defp misfit_read(name, type, {value, spelling}),
    do:
      misfit_written(
        Logex.Refusal.shown(name),
        type,
        written_and_read(spelling, inspect(value))
      )

  defp written_and_read(same, same), do: Logex.Refusal.shown(same)

  defp written_and_read(spelling, read),
    do: "#{Logex.Refusal.shown(spelling)}, which is #{Logex.Refusal.shown(read)}"

  defp taken_from_file({:take, taken}, _line, {forces, lines, problems}),
    do: {Enum.into(taken, forces), lines, problems}

  defp taken_from_file(misfits, line, {forces, lines, problems}),
    do: {forces, lines, Enum.reduce(misfits, problems, &[{line, &1} | &2])}

  defp forces_taken([], _path, forces), do: forces

  defp forces_taken(problems, path, _forces),
    do: raise(ArgumentError, Logex.Refusal.of(problems, path))

  # M5-10 (decision 156): a real's value in the shortest text that reads back to it, a
  # single's for a `real`, `0.1` and never `0.10000000149011612`.
  defp spelled_force(type, value) when type in [:real, :lreal],
    do: Logex.Real.spelled(type, value)

  defp spelled_force(_type, value), do: Integer.to_string(value)

  defp demonitor(nil), do: :ok
  defp demonitor({ref, _kinds}), do: Process.demonitor(ref, [:flush])

  defp status_of(state),
    do:
      shown_unread(
        %{
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
        },
        state
      )

  # Decision 390 (RV-11): the forces file a start or a restart could not read, `{path,
  # reason}`, the path as the host spelled it, shown while it stands, and no key otherwise
  # (provisional), as decision 360's `copy` was until decision 412 made it always there,
  # so that every status of a file read holds as it was.
  defp shown_unread(status, %{forces_unread: nil, forces_unknown: nil}), do: status

  defp shown_unread(status, %{forces_unread: unread, forces_unknown: nil}),
    do: Map.put(status, :forces_unread, unread)

  defp shown_unread(status, %{forces_unread: nil, forces_unknown: unknown}),
    do: Map.put(status, :forces_unknown, unknown)

  defp shown_unread(status, %{forces_unread: unread, forces_unknown: unknown}),
    do: Map.merge(status, %{forces_unread: unread, forces_unknown: unknown})

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
  # Decision 398 (RV-11): each device's opening limited by its own `open:`, where every
  # device call was limited by the idle watchdog and a poll period (decision 128): no
  # device's heartbeat is at stake while one opens, none having heard a deadline yet.
  defp opening([{name, module, opts, points} | rest], opened, read, start) do
    {:ok, pid} = device(name, {module, opts}, points, start, 0)

    device = {name, pid, points}
    timeout = Map.fetch!(start.opens, name)
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
        idle: start.idle,
        restarts: restarts,
        beat: start.beat
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
  defp misfit({:fault, cause}, device), do: {device, shown(device, cause)}

  # Decision 399 (RV-11): an address a fault names is shown as the configuration writes
  # it, `panel.i.7`, a reading's being an input's, where the adapter's own list,
  # `{:unknown_address, ~c"\a"}`, printed as a charlist; one that is no list of whole
  # numbers, which no configuration writes, as the adapter gave it (provisional). The
  # device is told its refusal by the adapter's own address, by which it holds the point.
  defp shown(device, {:unknown_address, address}),
    do: {:unknown_address, written(fields?(address), device, address)}

  defp shown(device, {:bad_value, address, value}),
    do: {:bad_value, written(fields?(address), device, address), value}

  defp written(true, device, address), do: spelled(device, :input, address)
  defp written(false, _device, address), do: address

  defp fields?([field]) when is_integer(field) and field >= 0, do: true
  defp fields?([field | rest]) when is_integer(field) and field >= 0, do: fields?(rest)
  defp fields?(_other), do: false

  defp first_read(nil, read, state) do
    changes =
      Enum.flat_map(read, fn {device, values} -> elem(vetted(device, values, state), 1) end)

    {:ok, rounded(merged(changes, state))}
  end

  defp first_read({device, cause}, _read, state) do
    each_live(state, &Device.close/2)
    {:error, {:io_init, device, cause}}
  end

  # The runner's state, once its devices are open, without what only the start reads: the
  # copy's text (decision 360) and the files' names as the host spelled them, which only a
  # claim's refusal reads (decision 356), where a round of a runner with a store paid a
  # reduction more for the copy's two names among them (RV-5); the anchor its clock counts
  # from and `logical`, the resource's `now`, the sum of the elapsed_ms it has passed
  # (§4.11); each device with its points, an input point by its device and address and
  # each device's output points by address; the trigger every event task samples that is
  # an input point, whose change a device makes its own round; the next round's inputs,
  # `pending`; what each device was last written; and each task's watchdog. Decision 400
  # (RV-11): `write_limit`, the option, kept for the runner's life, every round, trip,
  # restart/2, stop and edit's step leaving it as it is. Decision 437 (RV-16): `writing`,
  # the force's write of the forces file that is out, its process, its timer, its limit's
  # end, its caller and the set it holds, or nil, set by a force's, an unforce's or an
  # unforce_all's request and nil once its answer is taken or it is cut at its limit; a
  # round, a trip, a restart and an edit's step leave it as it is, the force taken onto the
  # set the runner then holds as its answer says, and a stop waits for it to its limit and
  # answers its caller; and `behind`, the forces' requests that came while one was out, in
  # order, each served once the one before it is answered, a round, a trip, a restart and
  # an edit's step leaving them waiting, and a stop answering each as a runner that is not
  # running. Decision 390
  # (RV-11): `forces_unread`, the forces file the start could not read, or nil, set again
  # by each restart that reads it, one a device then refuses among them, as such a restart
  # takes the file's forces, nil where it read the file or found none, and nil once a
  # force's or an unforce's write of the file lands; a round, a trip, a restart its cold
  # write refuses, a stop and an edit's step leave it as it is. Decision 391 (RV-11):
  # `forces_unknown`, the set a force's write past its limit held, or nil, set by such a
  # write, nil once a later write of the file lands or fails, nil at a start and at a
  # restart that reads the file or finds none, kept by one whose read fails; and the
  # store's `unknown`, under `retain`, set by a write over the store or its copy past its
  # limit and gone once a later write lands or fails, a start having none; a round, an
  # edit's step and a restart refused write nothing of their own, and a trip's, a stop's
  # and a cold restart's write each set or clear it as any write does.
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

    Map.merge(Map.drop(start, [:retain_period, :taker, :copy, :named]), %{
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
      writing: nil,
      behind: :queue.new(),
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
  # M9 (RV-4): each change taken onto the front, the list reversed once at the end, so that
  # the check is linear in the device's points, where an append made it quadratic.
  defp vetted(device, values, state),
    do: in_order(Enum.reduce_while(Enum.sort(values), {:ok, []}, &check(device, &1, &2, state)))

  defp in_order({:ok, changes}), do: {:ok, :lists.reverse(changes)}
  defp in_order(fault), do: fault

  defp check(device, {address, value}, {:ok, changes}, state),
    do: fit(Map.fetch(state.addresses, {device, address}), address, value, changes)

  defp fit(:error, address, _value, _changes), do: {:halt, {:fault, {:unknown_address, address}}}

  defp fit({:ok, {name, type}}, address, value, changes),
    do: fitting(Declarations.fits?(type, value), name, address, value, changes)

  defp fitting(true, name, _address, value, changes),
    do: {:cont, {:ok, [{name, value} | changes]}}

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

  defp changed(device, {:fault, cause}, state),
    do: tripped(state, {:io, device, shown(device, cause)})

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
  # (decision 131). A configuration with no untimed program served its requests whenever
  # it waited (decision 108); since decision 396 it is served so while no round is due,
  # and in the slot after C ms of its periodic rounds (below).
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

  # Decision 396 (RV-11): with no untimed program the periodic rounds are the share's
  # count, each whole, so that the slot comes at the end of the round that completes C ms
  # of them, as the continuous task's does, and a plant whose rounds outrun their periods,
  # each due again at once, leaves the host's requests their S ms, never none and never
  # more (provisional). A slot with no request waiting refreshes nothing: the requests
  # that come while no round is due are served at once, and the rest after the round that
  # was due (freely/1).
  defp slot(%{untimed: false, used: used, slots: {c, s}, queue: queue} = state)
       when used >= c,
       do: %{periodic_slot(:queue.is_empty(queue), s, state) | used: 0}

  defp slot(state), do: state

  defp periodic_slot(true, _s, state), do: state

  defp periodic_slot(false, s, state) do
    state = refresh(state, :idle)
    popped(:queue.out(state.queue), now(state) + s, state)
  end

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
  # program, which no slot of the continuous task's comes for again: the requests that
  # waited behind it are then served in order as every request is from now on (decision
  # 108), at once where no round is due and, since decision 396, on to the slot's end, and
  # after it while no round is due (freely/1), where one is.
  defp going_on(%{untimed: false, next_round: nil} = state, _until), do: freely(state)
  defp going_on(state, until), do: serving(state, until)

  # A round is owed where the configuration has untimed programs and its time has come: a
  # host's request then waits for the share's slot. Decision 396 (RV-11): and with none,
  # where a periodic round's due time has come: the request then waits for that round,
  # which runs at its wake, and is served after it while no round is due (freely/1), so
  # that a host's requests are held to their share against a due periodic round as
  # against the continuous task, the time no due round needs, where a tight loop of
  # requests was served ahead of a due round with no bound and made a 10 ms task late
  # (c1-runner-rounds-2); on the manual clock the round comes in the advance that delivers
  # its wake, as an owed round's slot does (decision 131), the request that finds it due
  # waiting for that advance rather than running it (provisional, RV-11's review). Since
  # decision 396 it reads the clock at every request of a plant with a periodic task,
  # where it read none with no untimed program, and a request served at once is
  # refreshed at that reading (requested/3), so that it costs no reading more.
  defp owed(%{next_round: at} = state) when at != nil, do: owed_at(now(state), at)
  defp owed(_state), do: :free

  defp owed_at(now, at) when now >= at, do: :owed
  defp owed_at(now, _at), do: {:free, now}

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
      {Device, pid, restarts, at, {kind, name, _}} = notice
      when notice?(pid, restarts, at, kind, name) ->
        rounded(noticed([notice], state))
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
        used: used(state, finish - start, timed),
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
  # answers the host's requests that waited, every restart in its queue or its mailbox
  # refused since decision 354, each having been asked while the runner ran: so that a
  # "back" taken with the trip's
  # notice leaves its device heard as late as it says for a restart asked after.
  #
  # Each notice carries the count of restarts its device had heard as it raised it, the
  # count its last release, or its opening, gave it: one raised before the last restart's
  # release, which may wait in the mailbox behind that restart, never trips the restarted
  # runner. A "back" is a fact whenever it was raised, so it counts whatever its count.
  defp noticed(taken, state) do
    receive do
      {Device, pid, restarts, at, {kind, name, _}} = notice
      when notice?(pid, restarts, at, kind, name) ->
        noticed([notice | taken], state)
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

  # Decision 394 (RV-11): a device gone down as its clock gave no time, the device's own read
  # of it, trips the runner naming the clock, as the runner's own read does, the device
  # opened again at the restart.
  defp exited(name, _pid, {:shutdown, {:clock, {kind, _answer} = cause}}, state)
       when kind in [:now_ms, :wall_ms],
       do: tripped(went_down(name, state), {:clock, cause})

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
  # cancelled and any that comes stale; every restart that reached the mailbox before the
  # trip refused; every output written 0 once, through each device, in device-name order,
  # which latches; `{:trip, reason}` sent to the subscribers; and the host's requests that
  # waited answered, every one from now on served at once. The resource is kept as the
  # last round computed it, for get/2.
  defp tripped(%{status: :tripped} = state, _reason), do: state

  defp tripped(state, reason) do
    cancel(state.wake, state.clock)
    state = %{state | status: :tripped, trip: reason, wake: nil, next_round: nil, written: %{}}
    refused_waiting(state)
    state = zeroed(state)
    published(state, [{:trip, reason}])
    {_written, state} = kept_store(state, state.runtime)
    drained(:queue.out(state.queue), state)
  end

  # Decision 354, since RV-4's review: a restart is judged as it arrives, and every one in
  # the mailbox as the runner trips arrived while it ran, before the trip, so each is
  # refused there and then in decision 133's words, whatever the runner would have taken
  # before it, a device's change whose round trips or a notice a round's start takes; one
  # that arrives once the trip has begun is the trip's own to serve. A restart taken from
  # the mailbox before the trip, waiting in the queue for the share's slot, keeps the
  # status it was taken under and is refused as the queue is drained.
  defp refused_waiting(state) do
    receive do
      {:"$gen_call", from, {:restart, mode}} when mode in [:cold, :warm] ->
        {refusal, _state} = served({:restart, mode, :running}, state)
        GenServer.reply(from, refusal)
        refused_waiting(state)
    after
      0 -> :ok
    end
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
  defp kept_store(state, runtime), do: kept_store(state, runtime, :event)

  defp kept_store(%{retain: nil} = state, _runtime, _when), do: {:ok, state}

  defp kept_store(%{retain: retain} = state, runtime, ending) do
    state = drained_writer(state)
    stamped(wall(state.clock), retain, {runtime, ending}, state)
  end

  defp stamped({:ok, at}, retain, made, state),
    do: noted(store_written(retain, text_of(made, at), state.write_limit), at, state)

  defp stamped(failed, _retain, _made, state), do: noted(failed, nil, state)

  # Decision 414 (RV-13): the end's write, every orderly exit's, a stop's, a parent's
  # shutdown and a `:normal` exit (decisions 316 and 328), takes the retained image out and
  # makes the store's text in the write's own process, within the write limit
  # (`Writer.written/3`), where the runner made them first, with no limit, in proportion to
  # the retained values (b3-store-image-4): so that the end's write ends within its
  # limit, its text's making counted, as the child spec's shutdown deadline counts it, and
  # a store too big to make and write within it is cut off at it and reported as any write
  # past its limit (decision 391), `{:retain, {:error, :timeout}}` and a stop's answer,
  # where a supervisor killed the runner in its write and no one was told. A trip's write,
  # a cold restart's and a fresh start's make it in the runner as before, no deadline but
  # the write limit on the file's own write waiting on them, the runner's own work
  # decision 352 gives RV-6 to bound (provisional).
  defp text_of({runtime, :end}, at),
    do: fn -> Logex.Retain.encode(Runtime.retained(runtime), at) end

  defp text_of({runtime, :event}, at), do: Logex.Retain.encode(Runtime.retained(runtime), at)

  # An event's write of the store, the owed copy first where one is (decision 360).
  defp store_written(%{owed: nil, at: path}, text, ms), do: Writer.written(path, text, ms)
  defp store_written(%{owed: owed, at: path}, text, ms), do: Writer.stored(path, text, owed, ms)

  # Decision 391 (RV-11): a write that lands is the store's age, `written_at`, the last
  # write neither failed nor unknown.
  defp noted(:ok, at, %{retain: retain} = state),
    do: {:ok, %{state | retain: Map.delete(%{retain | written_at: at, failed: nil}, :unknown)}}

  # Decision 360 (RV-5's review): a copy owed and made by a write over the store, before
  # it, named in `status/1` from then on and owed no more, since decision 418 by the
  # number it took, the store's own write then noted as any; and one that failed again a
  # failed write, the store not written and the copy still owed.
  defp noted({:copied, n, result}, at, %{retain: retain} = state),
    do:
      noted(result, at, %{
        state
        | retain: %{retain | owed: nil, copy: Paths.copy(retain.path, n)}
      })

  # Decision 391 (RV-11's review): an event's write killed at its limit in the owed copy's
  # write, the store's after it not begun, names the copy as unknown, since decision 418
  # by the number it took, the store as it was and the copy still owed, where it named
  # the store, which it could not have reached (`Writer.stored/4`); one killed in the
  # store's write, the copy made, names the store, by the clause above (provisional); and
  # one killed before its copy took a number, which can land nowhere, a write that failed,
  # `:timeout`, the copy still owed (provisional).
  defp noted({:uncopied, {:unknown, n}}, _at, %{retain: retain} = state) do
    published(state, [{:retain, {:error, :timeout}}])

    {{:error, {:retain, :timeout}},
     %{state | retain: unknown(retain, Paths.copy(retain.path, n))}}
  end

  defp noted({:uncopied, reason}, _at, state), do: failed(reason, state)

  # Decision 391 (RV-11): a write past its limit, killed or left to finish, may still land
  # once the disk answers, the store the old or the new, so it is neither failed nor
  # written: `status/1`'s `retain` names the store as `unknown`, `failed` nil and
  # `written_at` the last write known made, until a later write lands or fails. It is
  # reported `{:retain, {:error, :timeout}}` once all the same, as decision 401 has it, and
  # the write's caller told `{:error, {:retain, :timeout}}`, a cold restart left tripped
  # and a fresh start not started as for any write that does not land (decision 291).
  defp noted({:error, :timeout}, _at, %{retain: retain} = state) do
    published(state, [{:retain, {:error, :timeout}}])
    {{:error, {:retain, :timeout}}, %{state | retain: unknown(retain, retain.path)}}
  end

  defp noted({:error, reason}, _at, state), do: failed(reason, state)

  defp failed(reason, %{retain: retain} = state) do
    published(state, [{:retain, {:error, reason}}])

    {{:error, {:retain, reason}},
     %{state | retain: Map.delete(%{retain | failed: reason}, :unknown)}}
  end

  # ---- the period's writes (M6-6, decision 275) -----------------------------------------

  # A runner given a store writes it every `retain_period:` ms, on a grid from its start on
  # its clock, as a periodic task's due times are, a due time passed while it was busy or
  # tripped skipped, never made up (provisional); with no store, nothing. Its writer, a
  # process of its own, is started at the first write it is given.
  defp periodic(nil, nil, _taker, _at), do: nil

  defp periodic(%{at: path} = retain, every, taker, at),
    do:
      Map.put(retain, :period, %{
        path: path,
        every: every,
        from: at,
        next: at + every,
        taker: taker,
        writer: nil,
        busy: false,
        pending: nil,
        late: nil
      })

  # The period's state is the store's, under `retain`, so that a runner with no store
  # holds nothing more than before (`status/1` shows the store without it).
  defp put_period(%{retain: retain} = state, period),
    do: %{state | retain: %{retain | period: period}}

  defp shown_store(nil), do: nil
  defp shown_store(retain), do: Map.drop(retain, [:period, :at, :owed])

  # Decision 391: the file a write past its limit may yet land in, the store or its copy,
  # as the host spelled it, `failed` nil: a key of `retain`'s only while it stands
  # (provisional), as `copy` was until decision 412 made it always there, so that every
  # status of a write that landed or failed holds as it was.
  defp unknown(retain, path), do: Map.put(%{retain | failed: nil}, :unknown, path)

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
    state = put_period(state, %{periodic | next: next_due(periodic, now)})
    period_stamped(wall(state.clock), image, state)
  end

  defp period(state, _now), do: state

  # A period whose wall clock gives no time is a write that fails, reported as one.
  defp period_stamped({:ok, at}, image, state), do: handed(state, {at, image})

  # Decision 394 (RV-11): a wall clock no store's header holds, once the runner runs, a
  # write that fails reported as one, and a trip naming the clock, taken as the runner next
  # handles a message, where the plant ran on with every period's write failing.
  defp period_stamped({:error, {:clock, cause}} = failed, _image, state) do
    {_failed, state} = noted(failed, nil, state)
    send(self(), {__MODULE__, :clock, cause})
    state
  end

  # The image handed to the writer where it is idle, and otherwise kept until it answers,
  # the newest taken out replacing the one that waited, latest wins. Since RV-4's review
  # the write is limited as every other file write the runner makes is (decision 353):
  # one not answered within the write limit of real time (decision 400) from when it
  # was handed is reported once, `{:retain, {:error, :timeout}}`, and since decision 391
  # named `unknown` in `status/1`, neither failed nor written, the plant running on, where
  # nothing told a stalled disk before. The writer is left to its write, one at a time and
  # the newest image waiting as ever (decision 275), since a write the disk finishes late
  # is still the newest on it: its answer, when it comes, is taken as any, a write made
  # or failed ending the unknown (decision 401). An event's write still waits on it within
  # its own limit and kills it past that (drained_writer/1).
  defp handed(%{retain: %{period: %{busy: true} = periodic}} = state, write),
    do: put_period(state, %{periodic | pending: write})

  defp handed(%{retain: %{period: periodic}} = state, {at, image}) do
    pid = writer(periodic.writer, periodic.path)
    Writer.write(pid, at, image, state.retain.owed)
    token = make_ref()
    late = {Process.send_after(self(), {Writer, :late, token}, state.write_limit), token}
    put_period(state, %{periodic | writer: pid, busy: true, late: late})
  end

  # The period's write past its limit, reported, its writer left to it.
  defp late_writer(state) do
    {_failed, state} = noted({:error, :timeout}, nil, state)
    put_period(state, %{state.retain.period | late: nil})
  end

  # A write answered, drained or gone down has its limit's timer cancelled, any message of
  # it already sent passed over as stale.
  defp timer_off(%{late: nil} = periodic), do: periodic

  defp timer_off(%{late: {timer, _token}} = periodic) do
    Process.cancel_timer(timer)
    %{periodic | late: nil}
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
    next_write(put_period(state, %{timer_off(state.retain.period) | busy: false}))
  end

  defp next_write(%{retain: %{period: %{pending: nil}}} = state), do: state

  defp next_write(%{retain: %{period: %{pending: write} = periodic}} = state),
    do: handed(put_period(state, %{periodic | pending: nil}), write)

  # Before a write at an event, a trip, a stop, a shutdown or a cold restart, the
  # writer's write in progress waited for and any pending one dropped, so that the
  # event's write is the last on disk (decision 275). The wait is bounded as a device's
  # close was, by the write limit in real time (decision 400); a writer that has not
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
      state.write_limit -> hung_writer(state, pid)
    end
  end

  defp drained_writer(%{retain: %{period: %{} = periodic}} = state),
    do: put_period(state, %{periodic | pending: nil})

  defp drained_writer(state), do: state

  defp idled_writer(state, pid),
    do:
      put_period(state, %{timer_off(state.retain.period) | writer: pid, busy: false, pending: nil})

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
    next_write(put_period(state, %{timer_off(state.retain.period) | writer: nil, busy: false}))
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

  # Decision 398: a device opened again at a restart limited by its own `open:`, as at a
  # start, every device released then hearing no deadline until the restart's first
  # round; and since decision 439 (RV-16) one up read again limited by its own `open:`
  # too, where it was given the idle watchdog and a poll period, so that a gateway that
  # stayed up and answers its reread in 700 ms lets the restart through as it would its
  # opening. The heartbeat stays the idle watchdog and a poll period: the release, which
  # comes first, is limited so, and no device hears a deadline until the first round.
  defp read_device(true, {name, _old, points}, rest, state) do
    {:ok, pid} = device(name, Map.fetch!(state.bindings, name), points, state, state.restarts)
    timeout = Map.fetch!(state.opens, name)
    reopen_read(asked(pid, &Device.open/2, timeout), name, pid, points, rest, state)
  end

  defp read_device(false, {name, pid, _points}, rest, state) do
    timeout = Map.fetch!(state.opens, name)
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
    {{:error, {:io_init, name, shown(name, cause)}}, state}
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
    {{:error, {:io_init, name, shown(name, cause)}}, state}
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
  # millisecond at least, the timed tasks' runs in it left out (decision 122); and since
  # decision 396 (RV-11), with no untimed program, a round whole, its timed tasks' runs
  # being all it runs, so that the share holds against a due periodic round as against
  # the continuous task (provisional).
  defp used(%{untimed: true, used: used}, took, timed), do: used + max(took - timed, 1)
  defp used(%{used: used}, took, _timed), do: used + max(took, 1)

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
  # waited is served, in order, one an edit's step left waiting for a slot that no longer
  # comes among them (decision 108), and since decision 396 (RV-11) while no periodic
  # round is due, each whole, the rest waiting for the round that is due and served after
  # it: the time no due round needs.
  defp freely(%{untimed: false, next_round: nil, queue: queue} = state),
    do: free(:queue.is_empty(queue), nil, state)

  defp freely(%{untimed: false, next_round: at, queue: queue} = state),
    do: free(:queue.is_empty(queue) or now(state) >= at, at, state)

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
  # within a deadline of its own, the idle watchdog and a poll period from the start of
  # its own write (decision 348): a write that fails, or answers late, is an I/O fault,
  # and the devices after it are not written (decision 114).
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

  # Decision 348: each device's write has the idle watchdog and a poll period from its own
  # start, on the runner's clock, and as long in real time, so that a device written after
  # a slow one that answered in time is not cut short by it. Where the clock has moved
  # since the refresh before the writes, so that the deadline it carried comes sooner than
  # that, every device is renewed first, at the write's start: the one written hears its
  # own deadline, and those written after it or not at all hear the runner well while it
  # waits on a slow device in time. A write in the millisecond of the last refresh needs
  # none, its deadline that refresh's. Since RV-4's review the renewal is one shared
  # write every device reads (renew/2), where a refresh sent to every device at every
  # write made a round's cost the square of its devices wherever writes take time.
  defp wrote(true, name, pid, values, state) do
    begun = now(state)
    state = renewed(begun + state.idle + state.poll > state.deadline, begun, state)
    answer = asked(pid, &Device.write(&1, values, &2), max(state.deadline - begun, 0))
    in_time(answer, now(state), name, pid, values, state)
  end

  defp renewed(true, begun, state), do: renew(state, begun)
  defp renewed(false, _begun, state), do: state

  # Every device's deadline the idle watchdog and a poll period from `at`, by the shared
  # write each device reads at its wake and its poll, the deadline written before the time
  # (`Logex.Runner.Device`): the runner's wait between two refreshes counts it as one.
  defp renew(%{beat: beat, refreshed: last} = state, at) do
    deadline = at + state.idle + state.poll
    :atomics.put(beat, 1, deadline)
    :atomics.put(beat, 2, at)
    %{state | refreshed: at, deadline: deadline, refresh_gap: max(state.refresh_gap, at - last)}
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

  # One that answered after its own deadline on the runner's clock, a time that passed in
  # its write on the manual clock, answered all the same, so it is no hung device: it is
  # `:timeout`, and the trip's zero writes it its 0 as it does every device that answers,
  # each device's zero its own call with its own time to answer. One that did not answer
  # within its own deadline in real time was killed, as one gone down is lost, and the
  # trip's zero finds it down; since decision 348 that is only ever the device whose own
  # write was slow, every device written before it having answered in time and every one
  # after it not written, so each of them takes the trip's 0.
  defp in_time(:ok, _late, name, _pid, _values, state),
    do: {:halt, {:trip, {:io, name, :timeout}, state}}

  # Decision 394 (RV-11's review): a device that went down as its own read of the clock
  # gave no time, found so by the write, trips the runner naming the clock, as its exit
  # does (exited/4): one down inside the write by its reason, and one down before it, the
  # write told only that it is gone, by its exit's, which waits in the mailbox and is
  # taken here, an exit for any other reason left there as it was. So the trip names the
  # clock whichever of the device's write and its poll comes first in a millisecond, where
  # a write first named the device gone down.
  defp in_time({:error, {:down, :noproc}}, _answered, name, pid, _values, state),
    do: downed(clock_exit(pid), name, state)

  defp in_time({:error, {:down, reason}}, _answered, name, _pid, _values, state),
    do: downed(reason, name, state)

  defp in_time({:error, cause}, _answered, name, _pid, _values, state),
    do: {:halt, {:trip, {:io, name, cause}, state}}

  defp downed({:shutdown, {:clock, {kind, _} = cause}}, name, state)
       when kind in [:now_ms, :wall_ms],
       do: {:halt, {:trip, {:clock, cause}, went_down(name, state)}}

  defp downed(reason, name, state), do: {:halt, {:trip, {:io, name, {:down, reason}}, state}}

  defp clock_exit(pid) do
    receive do
      {:EXIT, ^pid, {:shutdown, {:clock, {kind, _}}} = reason} when kind in [:now_ms, :wall_ms] ->
        reason
    after
      0 -> :noproc
    end
  end

  defp now(%{clock: {module, clock}} = state), do: whole(time(module, clock), state)

  # The clock read as clocked/1 reads it, its failure a shutdown, without the closure, so
  # that the check of its answer costs a round nothing more than the closure did.
  defp time(module, clock) do
    module.now_ms(clock)
  rescue
    exception -> exit({:shutdown, {:clock, Exception.message(exception)}})
  catch
    :exit, reason -> exit({:shutdown, {:clock, reason}})
  end

  # c3-io-contract-9 (RV-4): a time that is no whole number of milliseconds is a clock that
  # fails. Decision 394 (RV-11): it, and one out of the range a time is held in, a signed
  # 64-bit integer as the renewal's `:atomics` and the timers take, trips the runner,
  # naming the clock, `{:clock, {:now_ms, answer}}`, where it stopped it as a shutdown: the
  # runner tells itself, a message it takes as it next handles one, and the work in hand
  # goes on with the last time it refreshed its devices at, a round in progress run with
  # no time passed, so that no read of the clock halfway through a step ends the runner;
  # the trip zeroes every output, and a restart brings the line back once the clock is
  # mended (clock_answer/1, provisional: the range, and the round in progress finished).
  defp whole(ms, _state) when is_integer(ms) and ms in @time_range, do: ms
  defp whole(other, state), do: wrong_clock({:now_ms, other}, Map.get(state, :refreshed, 0))

  defp wrong_clock(cause, fallback) do
    send(self(), {__MODULE__, :clock, cause})
    fallback
  end

  # A restart's look at the clock first (decision 394): one that still answers no time is
  # the restart's answer, `{:error, {:clock, cause}}`, the runner left tripped, and so is a
  # wall clock no store's header holds where a store is named; a mended one restarts, the
  # clock's notices from before it, sent while the runner stood tripped, taken as nothing.
  defp clock_answer(%{clock: {module, clock}} = state),
    do: walled_answer(time_answer(time(module, clock)), state)

  defp time_answer(ms) when is_integer(ms) and ms in @time_range, do: :ok
  defp time_answer(other), do: {:error, {:now_ms, other}}

  defp walled_answer(:ok, %{retain: nil}), do: :ok
  defp walled_answer(:ok, state), do: wall_answer(wall(state.clock))
  defp walled_answer(failed, _state), do: failed

  defp wall_answer({:ok, _at}), do: :ok
  defp wall_answer({:error, {:clock, cause}}), do: {:error, cause}

  defp clock_notices_dropped do
    receive do
      {__MODULE__, :clock, _cause} -> clock_notices_dropped()
    after
      0 -> :ok
    end
  end

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
    limit = ms!(Keyword.get(opts, :write_limit, @write_limit), :write_limit)
    file = file!(Keyword.get(opts, :forces))
    # c2-runner-persist-9: each path resolved once, here, against the directory the start
    # is made in, every read and write after made through it, so that a File.cd moves
    # neither file and two spellings of one path are one file to decision 356's check.
    # Since decision 400 (RV-11) a relative path's expansion, which reads that directory
    # through the VM's file server, is made in a process of its own within the write
    # limit, as every read of the start is, and before decision 325's check, which reads
    # the expanded paths.
    forces_at = expanded!(file, :forces, limit)
    {store, store_at} = retain!(Keyword.get(opts, :retain), {file, forces_at}, clock, limit)
    mode = start!(Keyword.fetch(opts, :start), store)
    period = period!(Keyword.get(opts, :retain_period), store)
    devices = Logex.IO.bind!(configuration, io)
    opens = opens!(Keyword.get(opts, :open, @open), devices)
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

    named = held_files(store, store_at, file, forces_at)
    files = Enum.map(named, fn {at, role, _option, _given} -> {at, role} end)
    unheld!(registered?(name!(Keyword.get(opts, :name))), Paths.held(files), named)
    looked = forces_looked(file, forces_at, limit)
    unlinked!(store, store_at, :retain, limit)
    {forces, unread} = read_forces(looked, file, forces_at, points, limit)

    {runtime, retain, at, copy} =
      store_read!({store, store_at}, mode, configuration, runtime, clock, limit)

    {%{
       forces: forces,
       forces_unread: unread,
       forces_unknown: nil,
       retain: retain,
       at: at,
       copy: copy,
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
       write_limit: limit,
       opens: opens,
       file: file,
       forces_at: forces_at,
       files: files,
       named: named
     }, Keyword.take(opts, [:name])}
  end

  defp takes(opts),
    do:
      "Logex.Runner.start_link/1 takes a keyword list of options, configuration:, io:, " <>
        "clock:, poll:, overhead:, idle:, write_limit:, open:, forces:, retain:, " <>
        "retain_period:, start: and name:, got: " <>
        inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle:, " <>
          "write_limit:, open:, forces:, retain:, retain_period:, start: and name:, got: " <>
          inspect(key)
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
    timed!(module.now_ms(clock), module)
    {module, clock}
  end

  defp clock!(other),
    do:
      raise(
        ArgumentError,
        "the runner's clock: is {module, clock}, a module that implements " <>
          "Logex.Runner.Clock and the clock its callbacks take, got: #{inspect(other)}"
      )

  # c3-io-contract-9 (RV-4): a clock's time is a whole number of milliseconds, its first
  # answer checked here, in the caller; one later that is not stops the runner (whole/1).
  defp timed!(ms, _module) when is_integer(ms) and ms in @time_range, do: :ok

  # Decision 394 (RV-11): one out of the range a time is held in, at start too.
  defp timed!(ms, module) when is_integer(ms),
    do:
      raise(
        ArgumentError,
        "the runner's clock `#{inspect(module)}` gave #{ms} from now_ms/1: a clock's time is " <>
          "a whole number of milliseconds from -9223372036854775808 to 9223372036854775807"
      )

  defp timed!(other, module),
    do:
      raise(
        ArgumentError,
        "the runner's clock `#{inspect(module)}` gave #{inspect(other)} from now_ms/1: a " <>
          "clock's time is a whole number of milliseconds"
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

  # Decision 398 (RV-11): a device's opening, its adapter's init/3 and the first read, at a
  # start and where a restart opens it again, limited by a limit of its own, `open:`, the
  # heartbeat by the idle watchdog and a poll period as ever: a whole number of ms for
  # every device, or a map of device names to one, each device it names given its own and
  # every other the default, 5000 ms, "a module's open its own timeout", as Logix gives one
  # (provisional: the option and its default, a few seconds as the write limit's, where
  # Logix's transition to Run waits 20 s for one attempt to connect, decision 142). A
  # device it names that `io:` binds no adapter to, by a name of no device or a key that
  # is no string, is the host's mistake, as is a time out of an interval's range.
  defp opens!(ms, devices) when ms in @interval,
    do: Map.new(devices, fn {name, _module, _opts, _points} -> {name, ms} end)

  defp opens!(named, devices) when is_map(named) and not is_struct(named) do
    names = for {name, _module, _opts, _points} <- devices, do: name
    Enum.each(named, &open_named!(&1, names, named))
    Map.merge(opens!(@open, devices), named)
  end

  defp opens!(other, _devices), do: raise(ArgumentError, open_told(other))

  defp open_named!({name, ms}, names, named) when is_binary(name) and ms in @interval,
    do: bound_open!(name in names, name, names, named)

  defp open_named!(_entry, _names, named), do: raise(ArgumentError, open_told(named))

  defp bound_open!(true, _name, _names, _named), do: :ok

  defp bound_open!(false, name, names, _named),
    do:
      raise(
        ArgumentError,
        "the runner's open: names the device `#{name}`, which io: binds no adapter to" <>
          Declarations.suggest(name, names, & &1, "devices")
      )

  defp open_told(other),
    do:
      "the runner's open: is how long a device's opening may take, a whole number of " <>
        "milliseconds from 1 to 2147483647, or a map of device names to one, got: " <>
        inspect(other)

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
  defp retain!(nil, _forces, _clock, _ms), do: {nil, nil}

  defp retain!(path, {path, _forces_at}, _clock, _ms),
    do:
      raise(
        ArgumentError,
        "the runner's retain: and forces: name one file, #{inspect(path)}: the store and the " <>
          "forces file are two files"
      )

  defp retain!(path, {forces, forces_at}, {module, _clock} = clock, ms)
       when is_binary(path) and path != "" do
    at = expanded!(path, :retain, ms)
    apart!(met(forces_at, at), path, forces)
    {walled!(function_exported?(module, :wall_ms, 1), clock, path), at}
  end

  defp retain!(other, _forces, _clock, _ms),
    do:
      raise(
        ArgumentError,
        "the runner's retain: is the path of the file its retained values are kept in, a " <>
          "string, got: #{inspect(other)}"
      )

  # Decision 356: the files a runner holds, each `{path, role, option, given}`, its store
  # and its forces file and then the `.tmp` beside each, so that a file another runner
  # holds is named before a `.tmp` that meets one; and since decision 360 (RV-5) the
  # `.tmp` the copies a start keeps of its store are written through, and since decision
  # 418 (RV-13) every copy's name, `<store>.dropped.<n>`, which `Logex.Runner.Paths`
  # checks against every other runner's files where no row could claim them, in place of
  # the one `<store>.dropped` decision 360 had.
  defp held_files(store, store_at, forces, forces_at) do
    files = held_file(store, store_at, :retain) ++ held_file(forces, forces_at, :forces)

    files ++
      for({at, role, option, given} <- files, do: {at <> ".tmp", {:tmp, role}, option, given}) ++
      held_copy(store, store_at)
  end

  defp held_copy(nil, nil), do: []
  defp held_copy(given, at), do: [{at <> ".dropped.tmp", {:tmp, :dropped}, :retain, given}]

  # The runner's own file a holder's refusal names: one of its rows, or, where another
  # runner holds one of its store's copies' names (decision 418), that copy, as the host
  # spelled the store.
  defp named_entry(named, path), do: named_or_copy(List.keyfind(named, path, 0), named, path)

  defp named_or_copy(nil, named, path) do
    {store, :retain, :retain, given} = List.keyfind(named, :retain, 1)
    true = is_integer(Paths.copy_of(path, store))

    {path,
     {:copy, given <> binary_part(path, byte_size(store), byte_size(path) - byte_size(store))},
     :retain, given}
  end

  defp named_or_copy(entry, _named, _path), do: entry

  defp held_file(nil, nil, _role), do: []
  defp held_file(given, at, role), do: [{at, role, role, given}]

  # Decision 356, checked in the caller before either file is read, so that a file another
  # runner holds is told as that, never as what it holds; where the name the runner is
  # started under is taken already, the start is `{:already_started, pid}`, OTP's, which
  # GenServer.start_link/3 gives before the runner's init/1 claims anything, and nothing is
  # checked here. The claim in init/1 decides, two starts at once among it.
  defp unheld!(true, _held, _named), do: :ok
  defp unheld!(false, :ok, _named), do: :ok

  defp unheld!(false, {:held, path, holder, role}, named),
    do: raise(ArgumentError, held_told(named_entry(named, path), holder, role))

  defp registered?(nil), do: false
  defp registered?(name), do: is_pid(where(name))

  # c4-api-fuzz-9 (RV-4's review): a `{:via, module, term}` name whose module is no
  # registry, which GenServer calls in the caller to look the name up, is the host's
  # mistake told in the runner's words, where it escaped as an UndefinedFunctionError;
  # every other name GenServer checks in its own.
  @registry [register_name: 2, unregister_name: 1, whereis_name: 1, send: 2]

  defp name!({:via, module, _term} = name) when is_atom(module),
    do:
      registry!(
        Code.ensure_loaded?(module) and Enum.all?(@registry, &exported?(module, &1)),
        name
      )

  defp name!(name), do: name

  defp registry!(true, name), do: name

  defp registry!(false, {:via, module, _term} = name),
    do:
      raise(
        ArgumentError,
        "the runner's name: #{inspect(name)} names #{inspect(module)}, which is no " <>
          "registry: a via name's module exports register_name/2, unregister_name/1, " <>
          "whereis_name/1 and send/2"
      )

  # A file another runner of this VM holds, told by what it is to each: the option that
  # names it here, as the host spelled it, and the holder's file it meets.
  defp held_told({_at, ours, option, given}, holder, theirs),
    do:
      "the runner's #{option}: #{inspect(given)} #{meets(ours, given)}" <>
        "#{theirs(theirs, holder)}: two runners on one file write each over the other's"

  defp meets({:copy, copy}, _given), do: "is copied to #{inspect(copy)}, "

  defp meets({:tmp, :dropped}, given),
    do: "is copied through #{inspect(given <> ".dropped.tmp")}, "

  defp meets({:tmp, _role}, given), do: "is written through #{inspect(given <> ".tmp")}, "
  defp meets(_role, _given), do: "names "

  defp theirs({:tmp, role}, holder),
    do:
      "the `.tmp` another runner of this VM, #{inspect(holder)}, writes its " <>
        "#{file_of(role)} through, which it holds until it stops"

  defp theirs(role, holder),
    do:
      "the #{file_of(role)} of another runner of this VM, #{inspect(holder)}, which holds " <>
        "it until it stops"

  # RV-5 (b3-store-image-5): a store or forces file that is a symbolic link is the host's
  # mistake at start, told before either file is read: every write of either is a new file
  # renamed over it (`Logex.Retain.written/2`), which would put a file in the link's place
  # and leave the file it names as it was, so the next start from the place the link
  # pointed meets an old store. Looked at raw, off the VM's file server, as the files are
  # read (decision 413: refused, where the review found the link replaced at the first
  # write; one put there after the start is replaced so, as the documents say). A link at
  # either's `.tmp` or at the store's copy is logex's own name, and replaced. Since RV-5's
  # review the look is made as each file's read is, in a process of its own limited to
  # the write limit of real time (`Writer.read/2`, decision 400), where it was made
  # in the caller with no limit, so that a stalled disk refuses the start as a file that
  # cannot be read before either is read, as the reads do, and neither file is looked at
  # or read in the caller. (A relative path's expansion, once, at the start, reads the
  # directory the start is made in through the VM's file server, in the caller, RV-4's
  # c2-runner-persist-9; RV-5's review left it, PLAN.md.)
  defp unlinked!(nil, nil, _option, _ms), do: :ok

  defp unlinked!(given, at, option, ms),
    do:
      link!(
        timed_out(Writer.read(fn -> :file.read_link_info(at, [:raw]) end, ms), ms),
        given,
        option
      )

  defp link!({:error, {:timeout, ms}}, given, option),
    do:
      raise(
        ArgumentError,
        "#{Logex.Refusal.path(given)}: the #{file_of(option)} cannot be read: the disk did " <>
          "not answer within " <> limit_told(ms)
      )

  defp link!({:ok, info}, given, option) when elem(info, 2) == :symlink,
    do:
      raise(
        ArgumentError,
        "the runner's #{option}: #{inspect(given)} is a symbolic link: the #{file_of(option)} " <>
          "is written whole beside it and renamed over it, which would put a file in the " <>
          "link's place and leave the file it names as it was: name that file itself"
      )

  defp link!(_info, _given, _option), do: :ok

  defp file_of(:retain), do: "store"
  defp file_of(:forces), do: "forces file"
  defp file_of(:dropped), do: "store's copy, `.dropped.<n>`,"

  # The store and the forces file are two files however each is named, `./plant.retain`
  # and `plant.retain` one file, and neither is the `.tmp` the other is written through
  # (decisions 127 and 275), which each write would replace with its own text.
  # Decision 400 (RV-11): a path expanded against the working directory, which a relative
  # one is read against through the VM's file server, so that its expansion is made in a
  # process of its own within the write limit, as every file call of the start is (RV-5's
  # review left it in the caller). An expansion the disk does not answer in time, or a
  # working directory that cannot be read, is no read of the file, which decision 390
  # carries on past for the forces file: it leaves the start with no file to read, hold
  # as its own (decision 356), tell from the other (decision 325) or write, a file that
  # cannot be located, and refuses the start, the host's mistake, for either file
  # (provisional, RV-11's review). An absolute path is expanded by its words alone,
  # reading no file, and in the caller.
  defp expanded!(nil, _option, _ms), do: nil
  defp expanded!(path, option, ms), do: expanding!(Path.type(path), path, option, ms)

  defp expanding!(:absolute, path, _option, _ms), do: Path.expand(path)

  defp expanding!(_relative, path, option, ms),
    do: expanded_told!(Writer.read(fn -> Path.expand(path) end, ms), path, option, ms)

  defp expanded_told!(at, _path, _option, _ms) when is_binary(at), do: at

  defp expanded_told!({:error, :timeout}, path, option, ms),
    do:
      raise(
        ArgumentError,
        "#{Logex.Refusal.path(path)}: the #{file_of(option)} cannot be located: the " <>
          "working directory a relative path is read against did not answer within " <>
          limit_told(ms)
      )

  defp expanded_told!({:error, _down}, path, option, _ms),
    do:
      raise(
        ArgumentError,
        "#{Logex.Refusal.path(path)}: the #{file_of(option)} cannot be located: the " <>
          "working directory a relative path is read against cannot be read"
      )

  # Decision 400: a limit as a refusal names it, the option's and its time.
  defp limit_told(ms), do: "the write limit, #{ms} ms (write_limit:)"

  defp met(nil, _path), do: :apart

  defp met(forces, path),
    do: copied_over(meeting(forces, path, forces <> ".tmp", path <> ".tmp"), forces, path)

  defp meeting(same, same, _forces_tmp, _path_tmp), do: {:one, same}
  defp meeting(_forces, path, path, _path_tmp), do: :store_through
  defp meeting(forces, _path, _forces_tmp, forces), do: :forces_through
  defp meeting(_forces, _path, _forces_tmp, _path_tmp), do: :apart

  # Decision 360 (RV-5): nor is the forces file the store's copy or the `.tmp` the copy is
  # written through, which a start that copies would write over with the store's text,
  # decision 325's rule for the copy; since decision 418 (RV-13) any of the store's
  # numbered copies, `<store>.dropped.<n>`, a copy's name, the store's name read whole
  # (`Logex.Runner.Paths.copy_of/2`), and `<store>.dropped`, which is no copy's name but
  # is written through the copies' `.tmp`, `<store>.dropped.tmp`; and since decision 417 a
  # cold start over a store a fresh start would refuse copies it too.
  defp copied_over(:apart, forces, path),
    do:
      copy_met(
        forces == path <> ".dropped.tmp" or is_integer(Paths.copy_of(forces, path)),
        forces == path <> ".dropped"
      )

  defp copied_over(met, _forces, _path), do: met

  defp copy_met(true, _through), do: :forces_copied
  defp copy_met(false, true), do: :forces_through_copies
  defp copy_met(false, false), do: :apart

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

  defp apart!(:forces_copied, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's forces: #{inspect(forces)} is a copy its retain: #{inspect(path)} " <>
          "is copied to, `.dropped.<n>`, by a start that drops from it or a cold start " <>
          "over it where a fresh start would refuse it, or the `.tmp` the copies are " <>
          "written through: the store's copies and the forces file are apart"
      )

  defp apart!(:forces_through_copies, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's forces: #{inspect(forces)} is written through " <>
          "#{inspect(forces <> ".tmp")}, the `.tmp` its retain: #{inspect(path)} is copied " <>
          "through by a start that drops from it or a cold start over it where a fresh " <>
          "start would refuse it: the store's copies and the forces file are apart"
      )

  defp apart!(:forces_through, path, forces),
    do:
      raise(
        ArgumentError,
        "the runner's forces: #{inspect(forces)} is the file its retain: #{inspect(path)} " <>
          "is written through, each written whole to the `.tmp` beside it and renamed over " <>
          "it: the store and the forces file are two files, neither the other's `.tmp`"
      )

  # Since RV-4 the wall clock's answer is checked too, as a store's header holds it.
  defp walled!(true, clock, path) do
    wall!(clock)
    path
  end

  defp walled!(false, {module, _clock}, _path),
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
  # laid over the resource by decision 277's matching, what it drops reported. Since RV-5
  # the read is raw and limited to the write limit of real time (decision 400), as
  # the forces file's is since RV-4's review, so that a FIFO or a stalled disk in the
  # store's place refuses the start as a file that cannot be read where it hung the
  # caller for good (decision 415). Decision 360: a store it dropped anything from is kept
  # as it was read, the text the start copies, since decision 418 to the next of the
  # store's numbered copies, `<store>.dropped.<n>` (dropped_copy/1).
  defp store_read!({nil, nil}, _mode, _configuration, runtime, _clock, _ms),
    do: {runtime, nil, nil, nil}

  # Decision 417 (RV-13): `start: :cold` reads the store as a warm start does, raw and
  # limited, and judges it, so that one a fresh start would refuse is copied before it is
  # written over (cold_copy/1): none, or one that reads whole, nothing to copy; one a
  # fresh start refuses, its text, `{:cold, text}`; one that stands but cannot be read,
  # its reason, `{:unread, reason}`, which no copy can be made of.
  defp store_read!({_given, at} = path, :cold, configuration, runtime, clock, ms),
    do:
      {runtime, retained(path, nil, []), wall!(clock),
       cold_read(Writer.read(fn -> :file.read_file(at, [:raw]) end, ms), path, configuration)}

  defp store_read!({_given, at} = path, :warm, configuration, runtime, clock, ms),
    do:
      store_text!(
        timed_out(Writer.read(fn -> :file.read_file(at, [:raw]) end, ms), ms),
        path,
        configuration,
        runtime,
        clock
      )

  defp cold_read({:error, :enoent}, _path, _configuration), do: nil

  defp cold_read({:ok, text}, {given, _at}, configuration),
    do: cold_judged(refused?(text, given, configuration), text)

  defp cold_read({:error, reason}, _path, _configuration), do: {:unread, reason}

  defp cold_judged(true, text), do: {:cold, text}
  defp cold_judged(false, _text), do: nil

  # A store's text judged as a warm fresh start judges it, its refusal caught: refused or
  # not.
  defp refused?(text, given, configuration) do
    {image, _written_at} = Logex.Retain.decode!(text, {given, configuration.name})
    _started = Runtime.start(configuration, image)
    false
  rescue
    ArgumentError -> true
  end

  defp store_text!({:error, :enoent}, path, _configuration, runtime, clock),
    do: {runtime, retained(path, nil, []), wall!(clock), nil}

  defp store_text!({:error, {:timeout, ms}}, {path, _at}, _configuration, _runtime, _clock),
    do:
      raise(
        ArgumentError,
        "#{Logex.Refusal.path(path)}: the store cannot be read: the disk did not answer " <>
          "within " <> limit_told(ms)
      )

  defp store_text!({:error, reason}, {path, _at}, _configuration, _runtime, _clock),
    do:
      raise(
        ArgumentError,
        "#{Logex.Refusal.path(path)}: the store cannot be read: #{:file.format_error(reason)}"
      )

  defp store_text!({:ok, text}, {given, _at} = path, configuration, _runtime, _clock) do
    {image, written_at} = Logex.Retain.decode!(text, {given, configuration.name})
    {runtime, dropped} = started!(configuration, image, given)
    {runtime, retained(path, written_at, dropped), nil, copied(dropped, text)}
  end

  # Decision 360: the store's text kept for its copy where the start dropped anything,
  # whatever decision 277's matching dropped, the drop report itself the copy's trigger,
  # so that a drop of any kind is covered, one a later matching adds among them.
  defp copied([], _text), do: nil
  defp copied(_dropped, text), do: text

  # The image a store holds judged as `Logex.Runtime.start/2` judges any, each of its
  # refusals a line naming the store.
  # Since RV-5 bounded as the store's own refusal is, its first 50 lines and then their
  # count, each at most 1,000 bytes (b3-store-image-11).
  defp started!(configuration, image, path) do
    Runtime.start(configuration, image)
  rescue
    error in ArgumentError ->
      reraise ArgumentError,
              error.message
              |> String.split("\n")
              |> Logex.Refusal.told(path),
              __STACKTRACE__
  end

  # `status/1`'s `retain` (decisions 275 and 277): the store's path, the time its last
  # write was made at, nil before the first, the reason the last write failed, nil where
  # it did not, and what the fresh start dropped; since decision 412 (RV-13) the copy the
  # start made, always there, nil until it is made and where the start made none, as the
  # report's other keys are always there (dropped_copy/1); and, kept from status/1, the
  # path every read and write of the store is made through, resolved once at the start,
  # and since RV-5's review the copy of the store a fresh start owes, its text, where its
  # own write failed, nil otherwise (decision 360, dropped_copy/1).
  defp retained({path, at}, written_at, dropped),
    do: %{
      path: path,
      at: at,
      written_at: written_at,
      failed: nil,
      dropped: dropped,
      copy: nil,
      owed: nil
    }

  # The host's wall clock, to the second, for a store's header, `{:ok, at}`; since RV-4
  # (c2-runner-persist-6) an answer that is no whole number of milliseconds since the Unix
  # epoch from year 0 to year 9999, `{:error, {:clock, {:wall_ms, answer}}}`, a write it
  # was asked for failing so, reported as any failed write. A time before 1970 is a
  # negative number, and taken; since RV-4's review a year before 0, which a `DateTime`
  # holds to year -9999 and a header would spell `-0001-...`, is refused as the message
  # says.
  defp wall({module, clock}), do: walled(clocked(fn -> module.wall_ms(clock) end))

  defp walled(ms) when is_integer(ms), do: in_range(DateTime.from_unix(ms, :millisecond), ms)
  defp walled(other), do: {:error, {:clock, {:wall_ms, other}}}

  defp in_range({:ok, %DateTime{year: year}}, ms) when year >= 0,
    do: {:ok, Logex.Retain.at(ms)}

  defp in_range(_beyond, ms), do: {:error, {:clock, {:wall_ms, ms}}}

  # At a fresh start, in the caller: a wall clock that gives no time a store's header can
  # hold is the host's mistake, before anything starts.
  defp wall!({module, _clock} = clock), do: wall_ok!(wall(clock), module)

  defp wall_ok!({:ok, at}, _module), do: at

  defp wall_ok!({:error, {:clock, {:wall_ms, answer}}}, module),
    do:
      raise(
        ArgumentError,
        "the runner's clock `#{inspect(module)}` gave #{inspect(answer)} from wall_ms/1: " <>
          "a store's header is written at the wall clock's time, a whole number of " <>
          "milliseconds since the Unix epoch from year 0 to year 9999"
      )

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
