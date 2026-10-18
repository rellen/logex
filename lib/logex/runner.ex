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
  and `name:`, a name to register it under, as `GenServer.start_link/3` takes one. It
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
  - What changed since it last passed anything on, it passes on to the runner by a call,
    one change at a time, in order. The runner merges it into the next round's inputs, and
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
    instance, fault}` by default, with the trips, restarts and edits M4-4 and M4-5 bring,
    and, only where named, the resource's `{:ran, task, instance, now}` and the runner's
    `{:round, now, outputs}`, each round's output points. A subscriber is monitored and
    dropped when it goes down. `unsubscribe/1` stops them.
  - `stop/2` writes every output 0 once, through each device, and closes every device, in
    device-name order, before it returns (decision 116). It is served at once, whatever
    the share.

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

  alias Logex.{Configuration, Runtime}
  alias Logex.IO.Point
  alias Logex.Runner.{Clock, Device}

  @options [:configuration, :io, :clock, :poll, :overhead, :idle, :name]

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
  before it closed again and the runner gone.
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
  The runner's status, a map: `status`, `:running`; `now`, the resource's time; `rounds`,
  the rounds run; `trip`, nil; `overlaps`, each task's (`Logex.Runtime.overlaps/1`);
  `forces`, `%{}`; `edit`, nil; `runs`, each task's longest run against its watchdog,
  `{ms, watchdog_ms}`, a timed task's run and the continuous task's round, under its name
  or `:none`, a continuous task that runs no instance timing none and listed at 0; `latest_wake`, the most a round's wake came after its time, in ms; and
  `refresh_gap`, the longest wait between two refreshes of the devices, in ms. M4-4 gives
  `trip` its reasons and `status` `:tripped`, and M4-5 the forces and the edit.
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
  def init(start), do: opening(start.devices, [], %{}, start)

  # A device's changes, by address, from that device's own process: merged into the next
  # round's inputs, and each change of an event task's trigger its own round, in address
  # order, answered once each has run and its outputs are written (decisions 120 and
  # 124), whatever the share.
  @impl GenServer
  def handle_call({:changes, device, changes}, {pid, _tag}, %{pids: pids} = state)
      when :erlang.map_get(device, pids) == pid,
      do: {:reply, :ok, changed(device, changes, state)}

  # A host's request is the runner's own work: served at once where no round is owed, and
  # otherwise queued for the share's slot (decision 122).
  def handle_call(request, from, state),
    do: {:noreply, requested(owed?(state), {from, request}, state)}

  @impl GenServer
  def handle_info({__MODULE__, :wake, token}, %{wake: {_timer, token, at}} = state),
    do: {:noreply, woken(state, at)}

  def handle_info({__MODULE__, :wake, _stale}, state), do: {:noreply, state}

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
  def terminate(_reason, %{devices: devices, queue: queue}) do
    for {from, _request} <- :queue.to_list(queue),
        do: GenServer.reply(from, gone(self()))

    Enum.each(devices, fn {_name, pid, _points} -> Device.close(pid) end)
  end

  defp requested(false, request, state), do: answered(request, refresh(state, :idle))
  defp requested(true, request, state), do: %{state | queue: :queue.in(request, state.queue)}

  defp answered({from, request}, state) do
    {reply, state} = served(request, state)
    GenServer.reply(from, reply)
    state
  end

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

  defp serve(other, _state),
    do:
      raise(
        ArgumentError,
        "Logex.Runner has no request #{inspect(other)}: a runner is called through " <>
          "get/2, get!/2, status/1, subscribe/2, unsubscribe/1 and stop/2"
      )

  defp demonitor(nil), do: :ok
  defp demonitor({ref, _kinds}), do: Process.demonitor(ref, [:flush])

  defp status_of(state),
    do: %{
      status: :running,
      now: state.logical,
      rounds: state.rounds,
      trip: nil,
      overlaps: Runtime.overlaps(state.runtime),
      forces: %{},
      edit: nil,
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
    {:ok, pid} =
      Device.start_link(%{
        name: name,
        module: module,
        opts: opts,
        points: points,
        runner: self(),
        clock: start.clock,
        poll: start.poll
      })

    device = {name, pid, points}
    reading(Device.open(pid), device, rest, opened, read, start)
  end

  defp opening([], opened, read, start) do
    state = running(Enum.reverse(opened), start)
    {:ok, rounded(merged(Enum.flat_map(read, &named(&1, state)), state))}
  end

  defp reading({:ok, values}, {name, _pid, _points} = device, rest, opened, read, start),
    do: opening(rest, [device | opened], Map.put(read, name, values), start)

  defp reading({:error, reason}, {name, _pid, _points}, _rest, opened, _read, _start) do
    for {_name, pid, _points} <- Enum.reverse(opened), do: Device.close(pid)
    {:error, {:io_init, name, reason}}
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
      devices: devices,
      pids: Map.new(devices, fn {name, pid, _points} -> {name, pid} end),
      anchor: now(start),
      logical: 0,
      rounds: 0,
      addresses: Map.new(inputs, fn {device, point} -> {{device, point.address}, point.name} end),
      outputs:
        Map.new(devices, fn {name, _pid, points} ->
          {name,
           for(%Point{direction: :output} = point <- points, do: {point.address, point.name})}
        end),
      triggers: MapSet.new(for {_device, point} <- inputs, point.name in singles, do: point.name),
      pending: %{},
      written: %{},
      watchdogs: watchdogs(start.configuration)
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
  defp scheduling(state, %Configuration{tasks: tasks, instances: instances}) do
    named = Enum.find_value(tasks, :none, &(&1.continuous && &1.name))
    timed = for %Configuration.Task{continuous: false, name: name} <- tasks, do: name
    untimed = Enum.any?(instances, &(&1.task not in timed))
    continuous = continuous(untimed, named)

    Map.merge(state, %{
      untimed: untimed,
      continuous: continuous,
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
      queue: :queue.new(),
      subscribers: %{},
      next_round: nil,
      wake: nil,
      token: 0,
      refreshed: state.anchor,
      refresh_gap: 0,
      latest_wake: 0,
      longest:
        Map.new(
          for(%Configuration.Task{name: name} <- tasks, do: name) ++ List.wrap(continuous),
          &{&1, 0}
        )
    })
  end

  # A continuous line that runs no instance times no round: its watchdog then times
  # nothing (decision 111), and a round of timed tasks alone is no round of its.
  defp continuous(false, _named), do: nil
  defp continuous(true, named), do: named

  # The conventional table's slots for a share of p percent: C = max(1, round((100 - p) /
  # p)) ms of the continuous task's rounds, then up to S = max(1, round(p / (100 - p))) ms
  # of the runner's own work, 4 and 1 at 20% (decision 122).
  defp slots(p), do: {max(1, round((100 - p) / p)), max(1, round(p / (100 - p)))}

  defp named({device, values}, state),
    do:
      for({address, value} <- values, do: {Map.fetch!(state.addresses, {device, address}), value})

  defp merged(changes, state), do: %{state | pending: Enum.into(changes, state.pending)}

  defp changed(device, changes, state) do
    {triggers, others} =
      changes
      |> Enum.sort()
      |> Enum.map(fn {address, value} ->
        {Map.fetch!(state.addresses, {device, address}), value}
      end)
      |> Enum.split_with(fn {name, _value} -> MapSet.member?(state.triggers, name) end)

    Enum.reduce(triggers, merged(others, state), &rounded(merged([&1], &2)))
  end

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

  defp wake(false, _late, state), do: scheduled(refresh(state, :idle))

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
    do: serving(answered(request, %{state | queue: queue}), until)

  # A round is owed where the configuration has untimed programs and its time has come: a
  # host's request then waits for the share's slot.
  defp owed?(%{untimed: true, next_round: at} = state) when at != nil, do: now(state) >= at
  defp owed?(_state), do: false

  # One round: the inputs taken, each step of the cycle run and timed, every device
  # refreshed before each with that step's deadline, its task's watchdog and a poll period
  # from the step's start, and before the write with the idle watchdog's, and each device
  # whose outputs changed written, in device-name order, its answer awaited (decisions
  # 118, 125 and 128). Then the share's count, the next round planned, and the requests
  # that waited served in the rest of the millisecond.
  defp rounded(%{anchor: anchor, logical: logical} = state) do
    start = now(state)
    elapsed = max(start - anchor - logical, 0)
    {runtime, steps} = Runtime.cycle_steps(state.runtime, elapsed, state.pending)

    {state, timed, events} =
      Enum.reduce(steps, {%{state | runtime: runtime}, 0, []}, &stepped/2)

    state = ran(state, state.continuous, now(state) - start)
    outputs = Runtime.cycle_outputs(state.runtime)
    state = written(refresh(state, :idle), outputs)
    finish = now(state)
    {logic, again} = logic(state)

    state = %{
      state
      | logical: logical + elapsed,
        pending: %{},
        rounds: state.rounds + 1,
        logic: logic,
        used: used(state, finish - start - timed)
    }

    published(state, Enum.reverse(events, [{:round, state.logical, outputs}]))

    state
    |> planned(start, finish, state.untimed or again)
    |> slot()
    |> freely()
  end

  defp stepped({kind, task, _run} = step, {state, timed, events}) do
    begun = now(state)
    state = refresh(state, begun + watchdog(task, state) + state.poll)
    {runtime, ran} = Runtime.cycle_step(state.runtime, step)
    took = now(state) - begun

    {ran(%{state | runtime: runtime}, task, took), timed + timed(kind, took),
     Enum.reverse(ran, events)}
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
        wake: {module.wake_at(clock, self(), {__MODULE__, :wake, token}, at), token, at}
    }
  end

  defp cancel(nil, _clock), do: :ok
  defp cancel({timer, _token, _at}, {module, clock}), do: module.cancel(clock, timer)

  # The requests that waited, served while no round is owed, every device refreshed first
  # where one waits, as before any of the runner's own work (decision 125).
  defp freely(%{untimed: true, next_round: at, queue: queue} = state),
    do: free(:queue.is_empty(queue) or now(state) >= at, at, state)

  defp freely(state), do: state

  defp free(true, _at, state), do: state
  defp free(false, at, state), do: serving(refresh(state, :idle), at)

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
  defp refresh(state, :idle), do: refresh(state, now(state) + state.idle + state.poll)

  defp refresh(%{devices: devices, refreshed: last} = state, deadline) do
    Enum.each(devices, fn {_name, pid, _points} -> Device.refresh(pid, deadline) end)
    now = now(state)
    %{state | refreshed: now, refresh_gap: max(state.refresh_gap, now - last)}
  end

  defp written(%{devices: devices} = state, outputs),
    do: Enum.reduce(devices, state, &write(&1, &2, outputs))

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

  defp wrote(false, _name, _pid, _values, state), do: state

  defp wrote(true, name, pid, values, state) do
    :ok = Device.write(pid, values)
    %{state | written: Map.put(state.written, name, values)}
  end

  defp now(%{clock: {module, clock}}), do: module.now_ms(clock)

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
    devices = Logex.IO.bind!(configuration, io)

    {%{
       configuration: configuration,
       runtime: runtime,
       devices: devices,
       clock: clock,
       poll: poll,
       overhead: overhead,
       idle: idle
     }, Keyword.take(opts, [:name])}
  end

  defp takes(opts),
    do:
      "Logex.Runner.start_link/1 takes a keyword list of options, configuration:, io:, " <>
        "clock:, poll:, overhead:, idle: and name:, got: " <> inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle: and name:, " <>
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

  defp ms!(ms, _key) when ms in @interval, do: ms

  defp ms!(other, key),
    do:
      raise(
        ArgumentError,
        "the runner's #{key}: is a whole number of milliseconds, 1 to 2147483647, got: " <>
          inspect(other)
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
