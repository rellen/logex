defmodule Logex.IO.Sim do
  @moduledoc """
  A simulated device (M4-1, `docs/organisation.md` §4.11): an adapter whose device is a
  small process the test owns, the fixture of every runner test and of README's example.
  A test starts one, binds it to a device by name, `io: %{"panel" => {Logex.IO.Sim, sim:
  panel}}`, sets its inputs and reads what was written to its outputs:

      {:ok, panel} = Logex.IO.Sim.start_link(reports: true)
      Logex.IO.Sim.set(panel, [0], 1)        # an input, at its address
      Logex.IO.Sim.outputs(panel)            # the last value written to each output

  **The test's side.**
  - `start_link/1` starts one linked to the caller. `reports: true` makes it report each
    change of an input to the device that opened it, as a device that can report does
    (decision 112); without it the device is only read. `clock:` is a manual clock
    (`Logex.Runner.Clock.Manual`) on which a delay passes, a delay sleeping in real time
    without one; `wait:` is how long `set/3` waits for the device that opened it to handle
    a report, 5000 ms unless set, from 1 ms to 4294967295, the longest the VM waits for an
    answer.
  - `set/3` sets one input, at its address, and `set/2` several, a map of addresses to
    values, unset inputs reading 0. Where the sim reports, the inputs that changed are
    sent to the device that opened it as one report, from the caller, which waits until
    the device has handled it, so that a test that sets an input and then moves the clock
    finds the device's change made, by construction. A device that is down, or goes down
    while it handles the report, with whatever reason, `:timeout` among them, is passed
    over; one still alive that does not answer within `wait:` is the test's mistake.
  - `outputs/1` gives the last value written to each output, `writes/1` every write in
    order, so that "zeroed once" can be asserted, `reads/1` the number of reads made,
    failed ones among them, and `closed?/1` whether the device was closed since it was
    last opened.
  - `fail/3` acts out one failure on the next call of the callback it names, `:init`,
    `:read`, `:write`, `:report` or `:close`, failures told to one callback acted out in
    the order told, each once: `{:error, reason}`, given back as the callback's error;
    `:raise`, `:throw` and `:exit`, in the device's process; `:hang`, for ever; `{:delay,
    ms}`, time passing on its clock, or slept, before the call goes on as usual; and, for
    a read or a report, `{:value, address, value}`, which the call gives beside the
    device's own, a value that need not fit its point at an address that need not be one.
    A close cannot give an error back, nor a value.

  **The adapter's side** is `Logex.IO`'s callbacks. `init/3` takes `sim:` among its
  options and opens the sim for the device's process that calls it, which is the one it
  reports to; `read/1` gives every input point of the device, by address; `write/2`
  records what it is given; `report/2` gives the input points among a report of its own
  and `%{}` for any other message; and `close/1` marks the device closed.

  A mistake of the test's, an option, a sim, an address, a value or a failure that is not
  one, raises `ArgumentError` with a message a test pins.
  """

  use GenServer

  @behaviour Logex.IO

  alias Logex.IO.Point
  alias Logex.Runner.Clock.Manual

  @options [:reports, :clock, :wait]
  @callbacks [:init, :read, :write, :report, :close]

  # The longest a process waits for an answer, 2^32 - 1 ms: a call refuses a longer one.
  @longest 4_294_967_295

  @doc """
  Starts a simulated device linked to the caller: `reports:` true or false, false unless
  set; `clock:` a manual clock for its delays, or nil; `wait:` ms, 5000 unless set, 1 to
  4294967295.
  """
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, options!(opts))

  @doc "Sets the input at `address` to `value`, reporting it where the sim reports and it changed."
  def set(sim, address, value) do
    sim = sim!(sim)
    setting(sim, %{address!(address) => value!(value)})
  end

  @doc "Sets several inputs, a map of addresses to values, reported as one where the sim reports."
  def set(sim, values) do
    sim = sim!(sim)
    setting(sim, values!(values))
  end

  @doc "The last value written to each output, by address."
  def outputs(sim), do: GenServer.call(sim!(sim), :outputs)

  @doc "Every write, in order, each the values `write/2` was given."
  def writes(sim), do: GenServer.call(sim!(sim), :writes)

  @doc "The number of reads made, failed ones among them."
  def reads(sim), do: GenServer.call(sim!(sim), :reads)

  @doc "Whether the device was closed since it was last opened."
  def closed?(sim), do: GenServer.call(sim!(sim), :closed)

  @doc "Acts out `how` on the next call of `callback`, after any failure told to it before."
  def fail(sim, callback, how) do
    sim = sim!(sim)
    GenServer.call(sim, {:fail, callback!(callback), failure!(callback, how)})
  end

  # The inputs set, and, where they changed and the sim reports to a device, reported to
  # it from the caller, which then waits through `:sys` until the device has handled it.
  defp setting(sim, values) do
    {reporter, changed, wait} = GenServer.call(sim, {:set, values})
    reported(reporter, {__MODULE__, sim, changed}, wait)
  end

  defp reported(nil, _report, _wait), do: :ok

  # A device that stops with the reason :timeout exits the call as a wait does, so only a
  # device still alive has not answered.
  defp reported(pid, report, wait) do
    send(pid, report)
    :sys.get_state(pid, wait)
    :ok
  catch
    :exit, {:timeout, _} -> unanswered!(Process.alive?(pid), pid, wait)
    :exit, _down -> :ok
  end

  defp unanswered!(true, pid, wait), do: raise(ArgumentError, unanswered(pid, wait))
  defp unanswered!(false, _pid, _wait), do: :ok

  defp unanswered(pid, wait),
    do:
      "Logex.IO.Sim waited #{wait} ms for #{inspect(pid)}, the device that opened it, to " <>
        "handle its report: a device is an OTP process, as the runner's are, which answers " <>
        ":sys once it has handled what it was sent"

  @impl Logex.IO
  def init(device, points, opts) do
    sim = bound!(opts)
    points = points!(points)
    act(take(sim, :init), :init, %{device: device}, fn _given -> opened(sim, device, points) end)
  end

  @impl Logex.IO
  def read(%{sim: sim, inputs: inputs} = state) do
    act(take(sim, :read), :read, state, fn given ->
      {:ok, Map.merge(GenServer.call(sim, {:inputs, inputs}), given), state}
    end)
  end

  @impl Logex.IO
  def write(values, %{sim: sim} = state) do
    values = values!(values)

    act(take(sim, :write), :write, state, fn _given ->
      GenServer.call(sim, {:written, values})
      {:ok, state}
    end)
  end

  @impl Logex.IO
  def report({__MODULE__, sim, changed}, %{sim: sim, inputs: inputs} = state) do
    act(take(sim, :report), :report, state, fn given ->
      {:ok, Map.merge(Map.take(changed, inputs), given), state}
    end)
  end

  def report(_message, state), do: {:ok, %{}, state}

  @impl Logex.IO
  def close(%{sim: sim} = state) do
    act(take(sim, :close), :close, state, fn _given ->
      GenServer.call(sim, :close)
      :ok
    end)
  end

  defp opened(sim, device, points) do
    GenServer.call(sim, {:opened, self()})

    {:ok,
     %{
       sim: sim,
       device: device,
       inputs: for(%Point{direction: :input, address: address} <- points, do: address),
       outputs: for(%Point{direction: :output, address: address} <- points, do: address)
     }}
  end

  # The next failure told to a callback, taken, with the clock a delay passes on.
  defp take(sim, callback), do: GenServer.call(sim, {:take, callback})

  # A failure acted out in the calling process, the device's; `go` is the call as usual,
  # given the values a `{:value, ...}` adds.
  defp act({:none, _clock}, _callback, _state, go), do: go.(%{})
  defp act({{:error, reason}, _clock}, :init, _state, _go), do: {:error, reason}
  defp act({{:error, reason}, _clock}, _callback, state, _go), do: {:error, reason, state}

  defp act({:raise, _clock}, callback, %{device: device}, _go),
    do: raise("the simulated device #{inspect(device)} raised in #{callback}, as fail/3 told it")

  defp act({:throw, _clock}, callback, _state, _go), do: throw({__MODULE__, callback})
  defp act({:exit, _clock}, callback, _state, _go), do: exit({__MODULE__, callback})
  defp act({:hang, _clock}, _callback, _state, _go), do: Process.sleep(:infinity)

  defp act({{:delay, ms}, clock}, _callback, _state, go) do
    delayed(clock, ms)
    go.(%{})
  end

  defp act({{:value, address, value}, _clock}, _callback, _state, go),
    do: go.(%{address => value})

  defp delayed(nil, ms), do: Process.sleep(ms)
  defp delayed(clock, ms), do: Manual.pass(clock, ms)

  @impl GenServer
  def init(options) do
    {:ok,
     Map.merge(options, %{
       inputs: %{},
       outputs: %{},
       writes: [],
       reads: 0,
       closed: false,
       reporter: nil,
       failures: %{}
     })}
  end

  @impl GenServer
  def handle_call({:set, values}, _from, state) do
    changed =
      for {address, value} <- values,
          Map.get(state.inputs, address, 0) != value,
          into: %{},
          do: {address, value}

    {:reply, {reporter(state.reports, state.reporter, changed), changed, state.wait},
     %{state | inputs: Map.merge(state.inputs, values)}}
  end

  def handle_call(:outputs, _from, state), do: {:reply, state.outputs, state}
  def handle_call(:writes, _from, state), do: {:reply, Enum.reverse(state.writes), state}
  def handle_call(:reads, _from, state), do: {:reply, state.reads, state}
  def handle_call(:closed, _from, state), do: {:reply, state.closed, state}

  def handle_call({:fail, callback, how}, _from, state),
    do:
      {:reply, :ok,
       %{state | failures: Map.update(state.failures, callback, [how], &(&1 ++ [how]))}}

  def handle_call({:take, callback}, _from, state) do
    {how, rest} = next(Map.get(state.failures, callback, []))

    {:reply, {how, state.clock},
     counted(callback, %{state | failures: Map.put(state.failures, callback, rest)})}
  end

  def handle_call({:opened, pid}, _from, state),
    do: {:reply, :ok, %{state | reporter: pid, closed: false}}

  def handle_call({:inputs, addresses}, _from, state),
    do: {:reply, Map.new(addresses, &{&1, Map.get(state.inputs, &1, 0)}), state}

  def handle_call({:written, values}, _from, state),
    do:
      {:reply, :ok,
       %{state | outputs: Map.merge(state.outputs, values), writes: [values | state.writes]}}

  def handle_call(:close, _from, state), do: {:reply, :ok, %{state | closed: true}}

  defp next([]), do: {:none, []}
  defp next([how | rest]), do: {how, rest}

  defp counted(:read, state), do: %{state | reads: state.reads + 1}
  defp counted(_callback, state), do: state

  # The device a sim reports to: the one that opened it, where it reports and an input
  # changed.
  defp reporter(true, pid, changed) when is_pid(pid) and map_size(changed) > 0, do: pid
  defp reporter(_reports, _pid, _changed), do: nil

  # The options, checked in order: the list, each key, then each value.
  defp options!(opts) when is_list(opts), do: listed!(Keyword.keyword?(opts), opts)
  defp options!(opts), do: raise(ArgumentError, takes(opts))

  defp listed!(false, opts), do: raise(ArgumentError, takes(opts))

  defp listed!(true, opts) do
    known!(Keyword.keys(opts) -- @options)

    %{
      reports: reports!(Keyword.get(opts, :reports, false)),
      clock: clock!(Keyword.get(opts, :clock)),
      wait: wait!(Keyword.get(opts, :wait, 5000))
    }
  end

  defp takes(opts),
    do:
      "Logex.IO.Sim takes a keyword list of options, reports:, clock: and wait:, got: " <>
        inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(ArgumentError, "Logex.IO.Sim takes reports:, clock: and wait:, got: #{inspect(key)}")

  defp reports!(reports) when is_boolean(reports), do: reports

  defp reports!(other),
    do: raise(ArgumentError, "Logex.IO.Sim's reports: is true or false, got: #{inspect(other)}")

  # A manual clock, which Logex.Runner.Clock.Manual checks in its own words.
  defp clock!(nil), do: nil

  defp clock!(clock) do
    Manual.now_ms(clock)
    clock
  end

  defp wait!(wait) when wait in 1..@longest, do: wait

  defp wait!(other),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim's wait: is a whole number of milliseconds, 1 to #{@longest}, the " <>
          "longest the VM waits, got: " <> inspect(other)
      )

  # A sim is a process this module started, by its pid.
  defp sim!(sim) when is_pid(sim), do: started!(Process.info(sim, :dictionary), sim)
  defp sim!(other), do: raise(ArgumentError, expected(other))

  defp started!({:dictionary, dictionary}, sim),
    do: ours!(List.keyfind(dictionary, :"$initial_call", 0), sim)

  defp started!(nil, sim),
    do: raise(ArgumentError, "the simulated device #{inspect(sim)} is not running")

  defp ours!({_key, {__MODULE__, :init, 1}}, sim), do: sim
  defp ours!(_other, sim), do: raise(ArgumentError, expected(sim) <> ", another process")

  defp expected(other),
    do: "expected a simulated device from Logex.IO.Sim.start_link/1, got: #{inspect(other)}"

  # The options it is bound with: `sim:` among them.
  defp bound!(opts) when is_list(opts),
    do: binding!(Keyword.keyword?(opts) and Keyword.has_key?(opts, :sim), opts)

  defp bound!(opts), do: binding!(false, opts)

  defp binding!(true, opts), do: sim!(Keyword.fetch!(opts, :sim))

  defp binding!(false, opts),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim is bound with its sim, {Logex.IO.Sim, sim: sim}, got the options " <>
          inspect(opts)
      )

  defp points!(points), do: each_point!(points?(points), points)

  defp points?([]), do: true
  defp points?([%Point{} | points]), do: points?(points)
  defp points?(_other), do: false

  defp each_point!(true, points), do: points

  defp each_point!(false, points),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim opens a device given its points, a list of %Logex.IO.Point{}, got: " <>
          inspect(points)
      )

  defp values!(values) when is_map(values) and not is_struct(values) do
    Enum.each(values, fn {address, value} -> {address!(address), value!(value)} end)
    values
  end

  defp values!(other),
    do:
      raise(
        ArgumentError,
        "values go by address, a map of addresses to integers, got: #{inspect(other)}"
      )

  defp address!([_ | _] = address), do: whole!(fields?(address), address)
  defp address!(other), do: whole!(false, other)

  defp fields?([]), do: true
  defp fields?([field | fields]) when is_integer(field) and field >= 0, do: fields?(fields)
  defp fields?(_other), do: false

  defp whole!(true, address), do: address

  defp whole!(false, other),
    do:
      raise(
        ArgumentError,
        "an address is a list of whole numbers, 0 or more, as `panel.i.1.3`'s is [1, 3], " <>
          "got: #{inspect(other)}"
      )

  defp value!(value) when is_integer(value), do: value

  defp value!(other),
    do: raise(ArgumentError, "a point's value is an integer, got: #{inspect(other)}")

  defp callback!(callback) when callback in @callbacks, do: callback

  defp callback!(other),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim fails one of its callbacks, :init, :read, :write, :report or :close, " <>
          "got: #{inspect(other)}"
      )

  # What each callback can act out: a close neither gives an error back nor a value, and
  # only a read or a report gives a value.
  defp failure!(:close, {:error, _reason} = how), do: cannot!(how, :close)
  defp failure!(callback, {:error, _reason} = how) when callback in @callbacks, do: how
  defp failure!(_callback, how) when how in [:raise, :throw, :exit, :hang], do: how
  defp failure!(_callback, {:delay, ms} = how) when is_integer(ms) and ms >= 0, do: how

  defp failure!(callback, {:value, address, value}) when callback in [:read, :report],
    do: {:value, address!(address), value}

  defp failure!(callback, {:value, _address, _value} = how), do: cannot!(how, callback)

  defp failure!(_callback, other),
    do:
      raise(
        ArgumentError,
        "a failure is {:error, reason}, :raise, :throw, :exit, :hang, {:delay, ms} with ms " <>
          "0 or more, or, for a read or a report, {:value, address, value}, got: " <>
          inspect(other)
      )

  defp cannot!(how, callback),
    do: raise(ArgumentError, "Logex.IO.Sim cannot act out #{inspect(how)} in #{callback}")
end
