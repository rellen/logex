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
  a runner without one taking no force, and `name:`, a name to register it under, as
  `GenServer.start_link/3` takes one. It
  checks every option in the caller before anything starts, the configuration as
  `Logex.Runtime.start/1` checks it and the bindings as `Logex.IO.bind!/2` does, so a
  host's mistake is an `ArgumentError` in the host's own process, with a message a test
  pins, and never a crash of the runner. Its child spec is `restart: :temporary`
  (decision 115): nothing starts it again that no person asked to start.

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
  - What changed since the runner last took a change of it, it passes on to the runner by
    a call, one change at a time, in order; a change the runner refuses, holding a value
    that does not fit or an address that is no input point's (an I/O fault, below), is not
    taken, and the device passes it on again at its next read, so that one that goes on
    giving it trips the runner again once restarted. The runner merges it into the next round's inputs, and
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
    `{:round, now, outputs}`, each round's output points. A subscriber is monitored and
    dropped when it goes down. `unsubscribe/1` stops them.
  - `force/3`, `unforce/2` and `unforce_all/1` force an input point, below.
  - `stop/2` writes every output 0 once, through each device, and closes every device, in
    device-name order, before it returns (decision 116). It is served at once, whatever
    the share.
  - `restart/2` starts a tripped runner again (below); a runner that is running is the
    host's mistake (decision 133).

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
  change of a forced trigger makes none. `status/1` lists every force. The forces file is the host's to name, `forces:`,
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
  (decision 140). A point a restart's file no longer forces reads its device's last value
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
  - `{:internal, message}`: an exception out of the core, which the host contract says
    cannot happen; tripping rather than crashing keeps the state for diagnosis. No host
    can cause it: a test reaches it through one hidden option of `start_link/1`, which
    stands a module of the test's in for `Logex.Runtime`'s steps.

  `restart(runner, :cold | :warm)`, `:warm` being `:cold` until `retain` lands, releases
  every latch, in device-name order, a device that does not answer within the idle
  watchdog and a poll period killed, as one that hung while the runner was tripped; opens
  again each device that went down, those among them, in device-name order, `{:error,
  {:io_init, device, reason}}` for one that cannot be opened, the runner left tripped with
  its first reason and every device that answers latched again, written 0 once more, as
  a restart that trips again is (decision 136); restarts the resource
  (`Logex.Runtime.restart/2`), which keeps its input image and puts every other global
  back to its initial value; sends `{:restart, mode}`; and runs the
  first round at once, before it returns, the clock not counting the time it was
  stopped. A runner that crashes, is killed or loses its clock is gone (decision 115):
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

  alias Logex.{Configuration, Declarations, Runtime}
  alias Logex.Configuration.Edit
  alias Logex.IO.Point
  alias Logex.Runner.{Clock, Device}

  # `steps:` is hidden (M4-4): a module of a test's standing in for Logex.Runtime's
  # steps, the one seam through which a test reaches a fault no host can cause, an
  # exception out of the core, `{:internal, message}` (docs/organisation.md §4.11).
  @options [:configuration, :io, :clock, :poll, :overhead, :idle, :forces, :name, :steps]
  @steps [cycle_steps: 3, cycle_step: 2, cycle_outputs: 1]

  # The events a subscriber may name, and those it gets unless it names them (§4.11).
  @kinds [:overlap, :fault, :trip, :restart, :edit, :ran, :round]
  @default_kinds [:overlap, :fault, :trip, :restart, :edit]

  # A poll period and the idle watchdog are an interval's range, as a watchdog is
  # (decision 109); the share is the conventional table's span (decision 121).
  @interval 1..2_147_483_647
  @share 10..90

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
    GenServer.start_link(__MODULE__, start, name)
  end

  @doc "The value at an access path, as `Logex.Runtime.get/2` gives it: `{:ok, value}` or `{:error, reason}`."
  def get(runner, path), do: call(runner, {:get, path})

  @doc "The value at an access path, as `Logex.Runtime.get!/2` gives it, raising `ArgumentError` with its reason."
  def get!(runner, path), do: call(runner, {:get!, path})

  @doc """
  Stops the runner: every output written 0 once, through each device, and every device
  closed, in device-name order, before it returns (decision 116). A reason other than
  `:normal`, `:shutdown` or `{:shutdown, term}` is an abnormal exit, as for any GenServer.
  """
  def stop(runner, reason \\ :normal), do: GenServer.stop(runner!(runner), reason, :infinity)

  @doc """
  The runner's status, a map: `status`, `:running`, or `:tripped` from a trip until a
  restart; `now`, the resource's time; `rounds`, the rounds run, a round that tripped
  not among them; `trip`, the trip's reason, nil while running; `overlaps`, each task's
  (`Logex.Runtime.overlaps/1`);
  `forces`, every force, by its point's name, with its value; `edit`, the stage of the
  edit the runner holds, `:accepted`, `:testing` or `:untested`, nil for none; `runs`, each task's longest run against its watchdog,
  `{ms, watchdog_ms}`, a timed task's run and the continuous task's round, under its name
  or `:none`, a continuous task that runs no instance timing none and listed at 0; `latest_wake`, the most a round's wake came after its time, in ms; and
  `refresh_gap`, the longest wait between two refreshes of the devices, in ms.
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
  not fit are the host's mistakes.
  """
  def force(runner, point, value), do: call(runner, {:force, point, value})

  @doc """
  Takes the force off an input point, by its name, so that the next round reads its
  device's last value again (decision 117), the whole set of forces written to the file
  before it returns: `:ok`, or `{:error, {:forces, reason}}`, the force not taken off. A
  trigger that reads another value makes its round at once, as a force does.
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
  Starts a tripped runner again, `:cold` or `:warm`, `:warm` being `:cold` until `retain`
  lands (decision 113): every device's latch released, each device that went down, or
  does not answer its release, opened again, the resource restarted
  (`Logex.Runtime.restart/2`, which keeps the input image and puts every other global
  back to its initial value), `{:restart, mode}` sent to the subscribers, and the first
  round run at once, before it returns, the clock not counting the time it was stopped,
  so that round's elapsed time is 0. `:ok`; a runner that is running is the host's
  mistake (decision 133). It reads the forces file again first, as every start does
  (decision 127): a force it cannot take is raised here, the runner left tripped.
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
        ":trip, :restart, :edit, :ran and :round, got: #{inspect(kinds)}"

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
  # 124), whatever the share.
  @impl GenServer
  def handle_call({:changes, device, changes}, {pid, _tag}, %{pids: pids} = state)
      when :erlang.map_get(device, pids) == pid do
    vetted = vetted(device, changes, state)
    {:reply, took(vetted), changed(device, vetted, state)}
  end

  # A host's request is the runner's own work: served at once where no round is owed, and
  # otherwise queued for the share's slot (decision 122).
  def handle_call(request, from, state),
    do: {:noreply, requested(owed?(state), {from, request}, state)}

  # The device's answer: a change taken, or one refused, which the device passes on again
  # at its next read, so that a device that goes on giving it trips the runner again once
  # it is restarted (decision 114).
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
  def handle_info({:EXIT, pid, reason}, state), do: {:noreply, exited(pid, reason, state)}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state),
    do: {:noreply, %{state | subscribers: Map.delete(state.subscribers, pid)}}

  # Anything else sent to the runner is no request of its, and changes nothing: a message
  # or a cast, and a call, which is answered as a host's mistake (see serve/2).
  def handle_info(_other, state), do: {:noreply, state}

  @impl GenServer
  def handle_cast(_other, state), do: {:noreply, state}

  # A stop: each host's request still waiting answered as one to a runner that is not
  # running, raised in its caller, and then every output written 0 once and every device
  # closed, in device-name order (decision 116).
  @impl GenServer
  def terminate(_reason, %{queue: queue} = state) do
    for {from, _request} <- :queue.to_list(queue),
        do: GenServer.reply(from, gone(self()))

    each_live(state, &Device.close/2)
    :ok
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
    type = input!(input(name, state))
    fits!(Declarations.fits?(type, value), name, type, value)
    kept(state, Map.put(state.forces, name, value), [name])
  end

  defp serve({:unforce, name}, state) do
    filed!(state)
    input!(input(name, state))
    kept(state, Map.delete(state.forces, name), [name])
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
    unforced = Map.keys(state.forces) -- Map.keys(forces)

    restarted(mode, %{
      state
      | forces: forces,
        pending: Enum.into(Map.take(state.values, unforced), state.pending)
    })
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
    do: {:error, not_input(Map.fetch(state.located, name), name, state)}

  defp not_input({:ok, at}, name, _state),
    do: "`#{name}` is an output point, at `#{at}`: only an input point is forced"

  defp not_input(:error, name, %{configuration: configuration, types: types}),
    do: no_input(Map.keys(types), name, configuration)

  defp no_input([], name, configuration),
    do:
      "`#{name}` is no input point of `#{configuration.name}`, which has none: only an " <>
        "input point is forced"

  defp no_input(names, name, configuration),
    do:
      "`#{name}` is no input point of `#{configuration.name}`" <>
        Declarations.suggest(name, Enum.sort(names), & &1, "names")

  defp input!({:ok, type}), do: type
  defp input!({:error, message}), do: raise(ArgumentError, message)

  defp fits!(true, _name, _type, _value), do: :ok
  defp fits!(false, name, type, value), do: raise(ArgumentError, misfit(name, type, value))

  defp misfit(name, :bool, value),
    do: "`#{name}` is a bool, forced to 0 or 1, got: #{inspect(value)}"

  defp misfit(name, :dint, value),
    do:
      "`#{name}` is a dint, forced to an integer from -2147483648 to 2147483647, got: " <>
        inspect(value)

  # The new set of forces, written whole to the file before it is taken (decision 127):
  # a write that fails changes nothing, `{:error, {:forces, reason}}`. Each input point
  # unforced reads its device's last value again; each trigger whose reading changed makes
  # its own round (decision 120), in kicked/1.
  defp kept(state, forces, names), do: taken(stored(state.file, forces), forces, names, state)

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

  defp parsed([name, value]), do: valued(Integer.parse(value), name, value)
  defp parsed(_parts), do: :error

  defp valued({integer, ""}, name, value),
    do: spelled(Integer.to_string(integer) == value, name, integer)

  defp valued(_other, _name, _value), do: :error

  defp spelled(true, name, integer), do: {:ok, name, integer}
  defp spelled(false, _name, _integer), do: :error

  defp force_read(:error, text, line, {forces, lines, problems}, _points),
    do:
      {forces, lines,
       [
         {line,
          "`#{text}` is no force: a line holds an input point's name and its value, as " <>
            "`eye_1 1`"}
         | problems
       ]}

  defp force_read({:ok, name, value}, _text, line, {forces, lines, problems}, points),
    do:
      once(
        Map.fetch(lines, name),
        name,
        value,
        line,
        {forces, Map.put_new(lines, name, line), problems},
        points
      )

  defp once({:ok, first}, name, _value, line, {forces, lines, problems}, _points),
    do: {forces, lines, [{line, "`#{name}` is forced on line #{first} already"} | problems]}

  defp once(:error, name, value, line, {forces, lines, problems}, points),
    do:
      taken_from_file(
        force_problem(input(name, points), name, value),
        name,
        value,
        line,
        {forces, lines, problems}
      )

  defp force_problem({:ok, type}, name, value),
    do: fitting_force(Declarations.fits?(type, value), name, type, value)

  defp force_problem({:error, message}, _name, _value), do: message

  defp fitting_force(true, _name, _type, _value), do: nil
  defp fitting_force(false, name, type, value), do: misfit(name, type, value)

  defp taken_from_file(nil, name, value, _line, {forces, lines, problems}),
    do: {Map.put(forces, name, value), lines, problems}

  defp taken_from_file(problem, _name, _value, line, {forces, lines, problems}),
    do: {forces, lines, [{line, problem} | problems]}

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
  defp stored(path, forces) do
    beside = path <> ".tmp"

    text =
      for {name, value} <- Enum.sort(forces), do: [name, ?\s, Integer.to_string(value), ?\n]

    renamed(written_out(:file.open(beside, [:write, :raw, :binary]), text), beside, path)
  end

  defp written_out({:ok, io}, text), do: synced(:file.write(io, text), io)
  defp written_out(error, _text), do: error

  defp synced(:ok, io), do: closed(:file.sync(io), io)
  defp synced(error, io), do: closed(error, io)

  defp closed(:ok, io), do: :file.close(io)

  defp closed(error, io) do
    :file.close(io)
    error
  end

  defp renamed(:ok, beside, path), do: discarded(:file.rename(beside, path), beside)
  defp renamed(error, beside, _path), do: discarded(error, beside)

  defp discarded(:ok, _beside), do: :ok

  defp discarded(error, beside) do
    :file.delete(beside)
    error
  end

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
      refresh_gap: state.refresh_gap
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

    singles =
      MapSet.new(
        for %Configuration.Task{single: single} <- start.configuration.tasks,
            single != nil,
            do: single
      )

    Map.merge(start, %{
      bindings:
        Map.new(start.devices, fn {name, module, opts, _points} -> {name, {module, opts}} end),
      devices: devices,
      pids: Map.new(devices, fn {name, pid, _points} -> {name, pid} end),
      anchor: now(start),
      logical: 0,
      rounds: 0,
      addresses:
        Map.new(inputs, fn {device, point} ->
          {{device, point.address}, {point.name, point.type}}
        end),
      down: MapSet.new(),
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
      written: %{}
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

  defp wake(false, _late, state),
    do: heard_from(silent(state), state, &scheduled(refresh(&1, :idle)))

  # Decision 122's slots: after C ms of the continuous task's rounds, at the end of the
  # round that completes them, the runner serves its own work for up to S ms, each request
  # whole, before the next round, and goes back to rounds at once where none waits; so on
  # the manual clock a slot comes in the advance that runs that round, never at a later one
  # (decision 131). Only a configuration with untimed programs is served in slots: one
  # without serves its requests whenever it waits (decision 108).
  defp slot(%{untimed: true, used: used, slots: {c, s}} = state) when used >= c do
    state = refresh(state, :idle)
    %{popped(:queue.out(state.queue), now(state) + s, state) | used: 0}
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
  # its round's, checked as the round ends (decision 111).
  defp stepped({:ok, {runtime, ran}}, kind, task, begun, {state, timed, events, times}) do
    took = now(state) - begun
    state = ran(%{state | runtime: runtime}, task, took)
    events = Enum.reverse(ran, events)
    limit = watchdog(task, state)

    checked(
      kind == :timed and took > limit,
      {:watchdog, {:task, task, took, limit}},
      {:ok, state, timed + timed(kind, took), events, [{task, took} | times]}
    )
  end

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
    state = each_live(state, &Device.zero/2)
    published(state, [{:trip, reason}])
    drained(:queue.out(state.queue), state)
  end

  defp drained({:empty, _queue}, state), do: state

  defp drained({{:value, request}, queue}, state) do
    state = answered(request, %{state | queue: queue})
    drained(:queue.out(state.queue), state)
  end

  # A restart (decision 113): every latch released, a device that does not answer its
  # release killed and marked down, as one that hung or went down while the runner was
  # tripped; every device down opened again; the resource restarted, which keeps its
  # clock and its input image, the triggers logic writes sampled again, the anchor moved
  # so that the time stopped is not counted, and the first round run at once.
  defp restarted(mode, state) do
    restarts = state.restarts + 1
    state = each_live(%{state | restarts: restarts}, &Device.release(&1, restarts, &2))
    reopened(reopen(Enum.filter(state.devices, &down?(&1, state)), state), mode)
  end

  defp down?({name, _pid, _points}, state), do: MapSet.member?(state.down, name)

  # Each device that went down opened again, in device-name order, and read once, its
  # values checked; the first that cannot be opened leaves the runner tripped.
  defp reopen([], state), do: {:ok, state}

  defp reopen([{name, _old, points} | rest], state) do
    {:ok, pid} = device(name, Map.fetch!(state.bindings, name), points, state, state.restarts)
    timeout = state.idle + state.poll
    reopen_read(asked(pid, &Device.open/2, timeout), name, pid, points, rest, state)
  end

  defp reopen_read({:ok, values}, name, pid, points, rest, state),
    do: reopen_checked(vetted(name, values, state), name, pid, points, rest, state)

  defp reopen_read({:error, reason}, name, _pid, _points, _rest, state),
    do: {{:error, {:io_init, name, reason}}, state}

  defp reopen_checked({:ok, changes}, name, pid, points, rest, state) do
    devices = List.keyreplace(state.devices, name, 0, {name, pid, points})

    reopen(rest, %{
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
  # released and one opened again before it alike.
  defp reopened({error, state}, _mode), do: {error, each_live(state, &Device.zero/2)}

  defp released(mode, state) do
    runtime = Runtime.restart(state.runtime, mode)
    at = now(state)

    state = %{
      state
      | runtime: runtime,
        status: :running,
        trip: nil,
        anchor: at - state.logical,
        refreshed: at,
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
  defp planned(state, start, finish, again) do
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
    at = earliest(state.next_round, state.refreshed + state.poll)
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
      located:
        Map.new(
          for(
            %Configuration.Global{at: at, name: name} <- configuration.globals,
            at != nil,
            do: {name, at}
          )
        )
    }

    {%{
       forces: read_forces(file, points),
       types: points.types,
       located: points.located,
       configuration: configuration,
       steps: steps,
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
        "clock:, poll:, overhead:, idle:, forces: and name:, got: " <> inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle:, forces: " <>
          "and name:, " <>
          "got: #{inspect(key)}"
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
