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
  `{:error, {:io_init, device, reason}}`, every device opened before it closed again.
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

  **A host's calls** go through the runner's mailbox, so each is served between two
  rounds. A mistake in one is the host's: the runner rescues the `ArgumentError`, replies
  with it, and the function raises it in the caller, the runner running on. A runner is
  given by its pid, or by the name it was started under.

  - `get/2` and `get!/2` read the resource as `Logex.Runtime.get/2` and `get!/2` do, a
    path that names nothing being `{:error, reason}` from the one and a raise from the
    other, and a path that is not a string a raise from both.

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
    started(GenServer.start_link(__MODULE__, start, name))
  end

  # The runner opens its devices once it is running, by a call, so that a device that
  # cannot be opened stops it normally and is told to the caller, whom its link would kill
  # were it refused from init/1.
  defp started({:ok, runner}), do: opened(GenServer.call(runner, :open, :infinity), runner)
  defp started(other), do: other

  defp opened(:ok, runner), do: {:ok, runner}
  defp opened({:error, _reason} = error, _runner), do: error

  @doc "The value at an access path, as `Logex.Runtime.get/2` gives it: `{:ok, value}` or `{:error, reason}`."
  def get(runner, path), do: call(runner, {:get, path})

  @doc "The value at an access path, as `Logex.Runtime.get!/2` gives it, raising `ArgumentError` with its reason."
  def get!(runner, path), do: call(runner, {:get!, path})

  # A host's call, a mistake in it raised here, in the caller.
  defp call(runner, request), do: relayed(GenServer.call(runner!(runner), request, :infinity))

  defp relayed({:raise, exception}), do: raise(exception)
  defp relayed(reply), do: reply

  @impl GenServer
  def init(start), do: {:ok, start}

  @impl GenServer
  def handle_call(:open, _from, start), do: opening(start.devices, [], %{}, start)

  # A device's changes, by address: merged into the next round's inputs, and each change of
  # an event task's trigger its own round, in address order, answered once each has run and
  # its outputs are written (decisions 120 and 124).
  def handle_call({:changes, device, changes}, _from, state),
    do: {:reply, :ok, changed(device, changes, state)}

  def handle_call(request, _from, state), do: {:reply, served(request, state), state}

  # Each request, a host's mistake in it given back to be raised in the caller.
  defp served(request, state) do
    serve(request, state)
  rescue
    error in ArgumentError -> {:raise, error}
  end

  defp serve({:get, path}, %{runtime: runtime}), do: Runtime.get(runtime, path)
  defp serve({:get!, path}, %{runtime: runtime}), do: Runtime.get!(runtime, path)

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
    {:reply, :ok, rounded(merged(Enum.flat_map(read, &named(&1, state)), state))}
  end

  defp reading({:ok, values}, {name, _pid, _points} = device, rest, opened, read, start),
    do: opening(rest, [device | opened], Map.put(read, name, values), start)

  defp reading({:error, reason}, {name, _pid, _points}, _rest, opened, _read, start) do
    for {_name, pid, _points} <- Enum.reverse(opened), do: Device.close(pid)
    {:stop, :normal, {:error, {:io_init, name, reason}}, start}
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
  end

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

  # ---- a round ---------------------------------------------------------------------------

  # One round: the inputs taken, each step of the cycle run, every device refreshed before
  # each with that step's deadline, its task's watchdog and a poll period from the step's
  # start, and before the write with the idle watchdog's, and each device whose outputs
  # changed written, in device-name order, its answer awaited (decisions 118, 125 and 128).
  defp rounded(%{anchor: anchor, logical: logical} = state) do
    start = now(state)
    elapsed = max(start - anchor - logical, 0)
    {runtime, steps} = Runtime.cycle_steps(state.runtime, elapsed, state.pending)
    runtime = Enum.reduce(steps, runtime, &stepped(&1, &2, state))
    outputs = Runtime.cycle_outputs(runtime)
    refresh(state, now(state) + state.idle + state.poll)

    written(
      %{
        state
        | runtime: runtime,
          logical: logical + elapsed,
          pending: %{},
          rounds: state.rounds + 1
      },
      outputs
    )
  end

  defp stepped({_kind, task, _run} = step, runtime, state) do
    refresh(state, now(state) + watchdog(task, state) + state.poll)
    {runtime, _events} = Runtime.cycle_step(runtime, step)
    runtime
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

  defp refresh(%{devices: devices}, deadline),
    do: Enum.each(devices, fn {_name, pid, _points} -> Device.refresh(pid, deadline) end)

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

  # The options, checked in the caller in order: the list, each key, the two it needs, and
  # then each value, the configuration first, so that its bindings are checked against a
  # configuration that starts.
  defp options!(opts) when is_list(opts), do: listed!(Keyword.keyword?(opts), opts)
  defp options!(opts), do: raise(ArgumentError, takes(opts))

  defp listed!(false, opts), do: raise(ArgumentError, takes(opts))

  defp listed!(true, opts) do
    known!(Keyword.keys(opts) -- @options)
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

  defp started!(nil, runner),
    do: raise(ArgumentError, "the runner #{inspect(runner)} is not running")

  defp ours!({_key, {__MODULE__, :init, 1}}, runner), do: runner
  defp ours!(_other, runner), do: raise(ArgumentError, expected(runner) <> ", another process")

  defp expected(other),
    do: "expected a runner from Logex.Runner.start_link/1, got: #{inspect(other)}"
end
