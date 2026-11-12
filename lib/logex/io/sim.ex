defmodule Logex.IO.Sim do
  @moduledoc """
  A simulated device (M4-1, `docs/organisation.md` §4.11): an adapter whose device is a
  small process the test owns, the fixture of every runner test and of README's example.
  A test starts one, binds it to a device by name, `io: %{"panel" => {Logex.IO.Sim, sim:
  panel}}`, sets its inputs and reads what was written to its outputs:

      {:ok, panel} = Logex.IO.Sim.start_link(reports: true)
      Logex.IO.Sim.set(panel, [0], 1)              # before a runner opens it: its list
      # ... a runner started with io: %{"panel" => {Logex.IO.Sim, sim: panel}} ...
      Logex.IO.Sim.set(panel, "panel.i.0", 1)      # an input, as the configuration writes it
      Logex.IO.Sim.outputs(panel)                  # the last value written to each output

  **Its addresses** (decision 517 (e), RV-21). An address is the adapter's list,
  `panel.i.1.3`'s `[1, 3]` (`Logex.IO`), until a runner has opened the sim, and from then
  on the configuration's text, `"panel.i.0"`, the location in its one spelling, a bit
  `"panel.i.1.3"` and a located array's element at its own address, `temps real[8] at
  card.i.0`'s `temps[3]` at `"card.i.3"`, as decision 399 has a trip name one, so that a
  test sets the button the configuration writes `panel.i.0` as `"panel.i.0"` and reads the
  motor it writes `drive.q.0` as `%{"drive.q.0" => 1}`. A sim is opened by a runner when
  `init/3` is called from a runner's device, a `Logex.Runner.Device` process, and keeps
  that device's name once the device closes it, between runners and after a stop; an open
  refused, another device holding the sim, names nothing, the sim keeping its holder's
  name, its addresses and its writes' spelling (RV-21's review); a test that calls the
  callbacks itself opens no runner's, and its sim keeps the list (provisional,
  `PLAN.md`'s RV-21 question 3):
  - `set/3` and `set/2` take a list before a runner's open and the text after it; the
    other form is the test's mistake, its message naming the form the sim takes, and so
    is a text of an output, of another device or of no location in its one spelling,
    `"panel.I.0"` or `"panel.i.00"`; a text of an input no point reads, past none of
    `inputs:`, is set as a list would be, read by no point;
  - `outputs/1` and `writes/1` give lists before and the text after, every write spelled
    by the device a runner last opened the sim for, those made before a reopen among
    them, since a sim is one device's, `writes/1` spelling them in the caller's process,
    so that the sim's own work for it is the list's (RV-21's review);
  - `fail/3`'s `{:value, address, value}` is the adapter's own term, a list of whole
    numbers as before a runner's open, any other the test's mistake, which the runner
    names as the configuration writes it (decision 399), so it stays a list, an address
    no point reads among them;
  - the sim's own refusal of an address past `inputs:` names it in the form the test gave,
    `the sim has 8 inputs, at the addresses "card.i.0" to "card.i.7", got: "card.i.9"`
    after a runner's open (decision 443's refusal, in the new form).

  **The test's side.**
  - `start_link/1` starts one linked to the caller. `reports: true` makes it report each
    change of an input to the device that opened it, as a device that can report does
    (decision 112); without it the device is only read. `clock:` is a manual clock
    (`Logex.Runner.Clock.Manual`) on which a delay passes, a delay sleeping in real time
    without one; `wait:` is how long `set/3` waits for the device that opened it to handle
    a report, 5000 ms unless set, from 1 ms to 4294967295, the longest the VM waits for an
    answer. Since M5-13 `inputs:` and `outputs:` are how many points of each direction it
    has, `[0]` to `[n - 1]`, nil for as many as it is given, so that a located array
    past them, `temps real[10] at card.i.0` on a sim of 8 inputs, is refused at bind;
    since M5-13's review each option is taken once, a key given twice refused; and since
    RV-4 `writes:` is how many writes it keeps, its newest, 100,000 unless set.
  - `set/3` sets one input, at its address (above), and `set/2` several, a map of
    addresses to values, each any number, an integer or a float, which the runner checks against its
    point's type, a real point's taking either (`Logex.IO`), unset inputs reading 0;
    since M5-13's review an address past `inputs:` is refused, the first in order, and
    nothing set. Where the sim reports, the inputs that changed are
    sent to the device that opened it as one report, from the caller, which waits until
    the device has handled it, so that a test that sets an input and then moves the clock
    finds the device's change made, by construction. A device that is down, or goes down
    while it handles the report, with whatever reason, `:timeout` among them, is passed
    over; one still alive that does not answer within `wait:` is the test's mistake.
  - `outputs/1` gives the last value written to each output, by address (above),
    `writes/1` every write in order, so that "zeroed once" can be asserted, since RV-4 its newest 100,000, or as
    many as `writes:` says, so that a sim written again every poll period for hours holds a
    bounded record (c6-pmi-7, provisional), `reads/1` the number of reads made,
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
  - `hold/1` holds the device's next reread, a restart's read of a device that stayed up
    (decision 142), until `let_go/1` lets it go on, and `holding?/1` says whether one
    waits in the hold (decision 462), so that a test on the real clock can let one device
    poll, released, while the runner waits on the reread of the device before it. A reread
    is told from a poll's read by the fence `Logex.Runner.Device` sends itself just before
    it, which waits in the device's mailbox while the adapter reads: a read is a restart's
    where the newest fence in its process's mailbox is one no read of the sim found there
    before, so that a poll, a tripped device's or a released one's, passes the hold by,
    whatever else waits in the mailbox, the fence of a reread the poll was queued behind
    among them (RV-17's review, decision 476). A poll passing the hold by goes on as
    usual, a failure told to `:read` acted out in it. The held read then goes on as usual,
    a failure told to `:read` meanwhile acted out in it, and `reads/1` counts it only
    then; and a held read whose process goes down, a reread the runner gave up and killed
    (`{:io_init, device, :timeout}`), spends the hold, `holding?/1` false, so that
    `let_go/1` then holds nothing (decision 479). `hold/1` on a sim that holds already,
    `let_go/1` on one that holds nothing, and since decision 477 `let_go/1` of a hold no
    reread has come to, where it took the hold back, are the test's mistakes, each raised
    and its message pinned, the sim left as it was, so that a test whose hold never
    engaged fails, the hold still armed for the next reread (decision 496: left armed, as
    the other two mistakes leave the sim).

  **The adapter's side** is `Logex.IO`'s callbacks. `check/3` gives the mistakes in the
  options it is bound with, which are `sim:` alone, a sim that is running and that no
  other device holds open, and since M5-13 each point at an address past the sim's own
  where it was started with `inputs:` or `outputs:`, the first ten and then a count, so
  that `Logex.IO.bind!/2` raises them in the host's process;
  `init/3` refuses the same, the first of them, and opens the sim for the device's process
  that calls it, which is the one it reports to; `read/1` gives every input point of the
  device, by address; `write/2` records what it is given; `report/2` gives the input
  points among a report of its own and `%{}` for any other message; and `close/1` marks
  the device closed.

  A sim is one device's: once a device's process has opened it, another may open it only
  once the first has closed it or gone down, so that two devices bound to one sim never
  share its inputs and outputs. The process that opened it may open it again.

  A mistake of the test's, an option, a sim, an address, a value or a failure that is not
  one, raises `ArgumentError` with a message a test pins.
  """

  use GenServer

  @behaviour Logex.IO

  alias Logex.IO.Point
  alias Logex.Runner.Clock.Manual

  @options [:reports, :clock, :wait, :inputs, :outputs, :writes]
  @callbacks [:init, :read, :write, :report, :close]

  # The longest a process waits for an answer, 2^32 - 1 ms: a call refuses a longer one.
  @longest 4_294_967_295

  # The writes a sim keeps unless `writes:` says otherwise (c6-pmi-7).
  @kept 100_000

  @doc """
  Starts a simulated device linked to the caller: `reports:` true or false, false unless
  set; `clock:` a manual clock for its delays, or nil; `wait:` ms, 5000 unless set, 1 to
  4294967295; `inputs:` and `outputs:` how many points of each direction it has, 1 or
  more, or nil, unless set, for as many as it is given; `writes:` how many writes it keeps,
  its newest, 1 or more, 100,000 unless set.
  """
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, options!(opts))

  @doc """
  Sets the input at `address` to `value`, reporting it where the sim reports and it
  changed: the address a list, `[0]`, until a runner has opened the sim, and from then on
  as the configuration writes it, `"panel.i.0"` (decision 517 (e)).
  """
  def set(sim, address, value) do
    sim = sim!(sim)
    setting(sim, &%{addressed!(&1, address, sim) => value!(value)})
  end

  @doc """
  Sets several inputs, a map of addresses to values, reported as one where the sim
  reports, each address as `set/3` takes one.
  """
  def set(sim, values) do
    sim = sim!(sim)
    setting(sim, &inputs!(values, &1, sim))
  end

  @doc """
  The last value written to each output, by address: a list, `[0]`, until a runner has
  opened the sim, and from then on as the configuration writes it, `"drive.q.0"` (decision
  517 (e)).
  """
  def outputs(sim), do: GenServer.call(sim!(sim), :outputs)

  @doc """
  Every write, in order, each the values `write/2` was given, by address as `outputs/1`
  gives them.
  """
  def writes(sim) do
    {writes, named} = GenServer.call(sim!(sim), :writes)
    each_spelled(writes, named)
  end

  @doc "The number of reads made, failed ones among them."
  def reads(sim), do: GenServer.call(sim!(sim), :reads)

  @doc "Whether the device was closed since it was last opened."
  def closed?(sim), do: GenServer.call(sim!(sim), :closed)

  @doc "Acts out `how` on the next call of `callback`, after any failure told to it before."
  def fail(sim, callback, how) do
    sim = sim!(sim)
    GenServer.call(sim, {:fail, callback!(callback), failure!(callback, how)})
  end

  @doc "Holds the device's next reread, a restart's read, until `let_go/1` (decision 462)."
  def hold(sim) do
    sim = sim!(sim)
    held!(GenServer.call(sim, :hold), sim)
  end

  @doc """
  Lets the held reread go on. A hold no reread has come to, and no hold, is the test's
  mistake (decision 477).
  """
  def let_go(sim) do
    sim = sim!(sim)
    let!(GenServer.call(sim, :let_go), sim)
  end

  @doc "Whether a reread waits in the hold."
  def holding?(sim), do: GenServer.call(sim!(sim), :holding)

  defp held!(:ok, _sim), do: :ok

  defp held!(:held, sim),
    do:
      raise(
        ArgumentError,
        "the simulated device #{inspect(sim)} holds its next reread already: let_go/1 " <>
          "lets it go"
      )

  defp let!(:ok, _sim), do: :ok

  defp let!(:unheld, sim),
    do:
      raise(
        ArgumentError,
        "the simulated device #{inspect(sim)} holds no reread: hold/1 holds its next"
      )

  # Decision 477 (RV-18): a hold armed that no reread has come to, let go, is the test's
  # mistake, where it was taken back: a test whose hold never engaged fails.
  defp let!(:unreached, sim),
    do:
      raise(
        ArgumentError,
        "the simulated device #{inspect(sim)} holds no reread yet: hold/1 armed the hold, " <>
          "and no restart has read the device since"
      )

  # The inputs set, and, where they changed and the sim reports to a device, reported to
  # it from the caller, which then waits through `:sys` until the device has handled it.
  # Decision 517 (e) (RV-21): the addresses are taken by the device the sim is named for
  # as the set reaches it, so that where a runner opened it between the look and the set
  # they are taken again, by the name it has now, and never set by the one it had.
  defp setting(sim, taken), do: setting(sim, taken, GenServer.call(sim, :named))

  defp setting(sim, taken, named),
    do: set!(GenServer.call(sim, {:set, taken.(named), named}), sim, taken)

  # M5-13's review: an address past the sim's inputs, where it was started with `inputs:`,
  # is the test's mistake, as a point bound past them is the host's, and nothing is set.
  # Decision 517 (e) (RV-21): once a runner has opened the sim, in the configuration's
  # text, as the test wrote it.
  defp set!(:renamed, sim, taken), do: setting(sim, taken)

  defp set!({:past, address, size, nil}, _sim, _taken),
    do:
      raise(
        ArgumentError,
        "the sim has #{size} #{noun(:input, size)}, at the addresses [0] to [#{size - 1}], " <>
          "got: #{inspect(address, charlists: :as_lists)}"
      )

  defp set!({:past, address, size, named}, _sim, _taken),
    do:
      raise(
        ArgumentError,
        "the sim has #{size} #{noun(:input, size)}, at the addresses " <>
          "#{inspect(at(named, :input, [0]))} to #{inspect(at(named, :input, [size - 1]))}, " <>
          "got: #{inspect(at(named, :input, address))}"
      )

  defp set!({reporter, changed, wait}, sim, _taken),
    do: reported(reporter, {__MODULE__, sim, changed}, wait)

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
  def check(device, points, opts), do: misbound(opts, {device, points})

  @impl Logex.IO
  def init(device, points, opts) do
    sim = bound!(opts, {device, []})
    points = points!(points)
    first!(past(GenServer.call(sim, :sizes), {device, points}), sim)
    act(take(sim, :init), :init, %{device: device}, fn _given -> opened(sim, device, points) end)
  end

  # Decision 462: each read's take names the newest fence in its process's mailbox, the
  # device's, so that the sim tells a restart's read from a poll's.
  @impl Logex.IO
  def read(%{sim: sim} = state),
    do:
      reading(GenServer.call(sim, {:take, :read, fence(Process.info(self(), :messages))}), state)

  # Decision 462: a sim holding its next reread answers `:armed` to its take, taking
  # nothing, and the read, a restart's, waits in the hold until the test lets it go; then
  # it takes its failure past the hold and goes on as usual, as a poll's does at once.
  defp reading(:armed, %{sim: sim} = state) do
    GenServer.call(sim, :held, :infinity)
    reading(GenServer.call(sim, {:take, :read, :past_hold}), state)
  end

  defp reading(taken, %{sim: sim, inputs: inputs} = state) do
    act(taken, :read, state, fn given ->
      {:ok, Map.merge(GenServer.call(sim, {:inputs, inputs}), given), state}
    end)
  end

  # The newest fence in the device's mailbox, this process's, nil where none waits: the
  # one `Logex.Runner.Device` sends itself just before it reads again (decision 142's
  # reread), which waits there while the adapter reads, and stays until the device
  # handles it, so that a poll queued before the fence reads with it there still.
  defp fence({:messages, messages}),
    do: List.last(for {Logex.Runner.Device, :fence, fence} <- messages, do: fence)

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
    open!(GenServer.call(sim, {:opened, self(), device, runner?()}), sim)

    {:ok,
     %{
       sim: sim,
       device: device,
       inputs: for(%Point{direction: :input, address: address} <- points, do: address),
       outputs: for(%Point{direction: :output, address: address} <- points, do: address)
     }}
  end

  # Decision 517 (e) (RV-21): whether the process that opens the sim is a runner's device,
  # `Logex.Runner.Device`'s, which a runner starts for each device it binds, rather than a
  # test that calls the adapter's callbacks itself, which keeps the list form.
  defp runner?, do: Process.get(:"$initial_call") == {Logex.Runner.Device, :init, 1}

  # A sim another device opened meanwhile, though no device held it when its options were
  # checked, is refused as the check refuses it.
  defp open!(:ok, _sim), do: :ok
  defp open!({:held, pid, device}, sim), do: raise(ArgumentError, holding(sim, pid, device))

  defp holding(sim, pid, device),
    do:
      "the simulated device #{inspect(sim)} is the device `#{device}`'s, opened by " <>
        "#{inspect(pid)}, which has not closed it: a sim is one device's"

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
       count: 0,
       reads: 0,
       closed: false,
       reporter: nil,
       device: nil,
       failures: %{},
       hold: nil,
       found: nil,
       named: nil
     })}
  end

  @impl GenServer
  def handle_call({:set, values, named}, _from, %{named: named} = state),
    do:
      set_in(
        values |> Map.keys() |> Enum.reject(&within?(&1, state.sizes.input)) |> Enum.sort(),
        values,
        state
      )

  def handle_call({:set, _values, _named}, _from, state), do: {:reply, :renamed, state}

  def handle_call(:outputs, _from, state),
    do: {:reply, spelled(state.named, :output, state.outputs), state}

  # RV-21's review (F5): the writes as they are kept and the name they are spelled by, the
  # spelling the caller's (writes/1), so that a sim keeping 100,000 writes spends no more
  # of its own time on writes/1 once a runner has opened it than before, a runner's device
  # waiting on it meanwhile.
  def handle_call(:writes, _from, state),
    do: {:reply, {Enum.reverse(Enum.take(state.writes, state.kept)), state.named}, state}

  def handle_call(:named, _from, state), do: {:reply, state.named, state}

  def handle_call(:reads, _from, state), do: {:reply, state.reads, state}
  def handle_call(:closed, _from, state), do: {:reply, state.closed, state}

  def handle_call({:fail, callback, how}, _from, state),
    do:
      {:reply, :ok,
       %{state | failures: Map.update(state.failures, callback, [how], &(&1 ++ [how]))}}

  def handle_call({:take, :read, :past_hold}, _from, state), do: taken(:read, state)

  # Decision 462: a read whose newest fence no read found before is a restart's, the fence
  # noted as found, held where a hold is armed; any other is a poll's, which passes the
  # hold by.
  def handle_call({:take, :read, fence}, _from, %{found: found} = state)
      when is_reference(fence) and fence != found,
      do: reread(%{state | found: fence})

  def handle_call({:take, :read, _polled}, _from, state), do: taken(:read, state)
  def handle_call({:take, callback}, _from, state), do: taken(callback, state)

  # Decision 462: the hold armed by hold/1, a reread waiting in it its caller, `{:holding,
  # from, monitor}`, answered by let_go/1; a reread whose process goes down meanwhile
  # spends it (handle_info/2). Since decision 477 (RV-18) a let-go of the hold armed, no
  # reread in it, is the test's mistake, the hold left armed, where it was taken back.
  def handle_call(:hold, _from, %{hold: nil} = state), do: {:reply, :ok, %{state | hold: :armed}}
  def handle_call(:hold, _from, state), do: {:reply, :held, state}

  def handle_call(:held, {pid, _tag} = from, %{hold: :armed} = state),
    do: {:noreply, %{state | hold: {:holding, from, Process.monitor(pid)}}}

  def handle_call(:held, _from, state), do: {:reply, :ok, state}

  def handle_call(:let_go, _from, %{hold: {:holding, from, monitor}} = state) do
    Process.demonitor(monitor, [:flush])
    GenServer.reply(from, :ok)
    {:reply, :ok, %{state | hold: nil}}
  end

  def handle_call(:let_go, _from, %{hold: :armed} = state), do: {:reply, :unreached, state}

  def handle_call(:let_go, _from, state), do: {:reply, :unheld, state}

  def handle_call(:holding, _from, state),
    do: {:reply, match?({:holding, _from, _monitor}, state.hold), state}

  def handle_call({:opened, pid, device, runner}, _from, state),
    do: opening(holder(state), pid, {device, runner}, state)

  def handle_call(:holder, _from, state), do: {:reply, holder(state), state}
  def handle_call(:sizes, _from, state), do: {:reply, state.sizes, state}

  def handle_call({:inputs, addresses}, _from, state),
    do: {:reply, Map.new(addresses, &{&1, Map.get(state.inputs, &1, 0)}), state}

  def handle_call({:written, values}, _from, state),
    do:
      {:reply, :ok,
       recorded(%{
         state
         | outputs: Map.merge(state.outputs, values),
           writes: [values | state.writes],
           count: state.count + 1
       })}

  def handle_call(:close, _from, state), do: {:reply, :ok, %{state | closed: true}}

  # Decision 462: a held reread whose process went down, killed by a runner that gave it up
  # (decision 479), spends the hold, which holds nothing then; `let_go/1` takes the monitor
  # out, its message with it, so no other comes. Any other message, which nothing the sim
  # is called by sends, is passed over, where GenServer's default logged it.
  @impl GenServer
  def handle_info(
        {:DOWN, monitor, :process, _pid, _reason},
        %{hold: {:holding, _, monitor}} = state
      ),
      do: {:noreply, %{state | hold: nil}}

  def handle_info(_message, state), do: {:noreply, state}

  # The newest `kept` of the writes made, newest first, `count` of them held; the list cut
  # back to them only once it holds twice as many, so that a write costs a constant on the
  # whole.
  defp recorded(%{count: count, kept: kept} = state) when count > 2 * kept,
    do: %{state | writes: Enum.take(state.writes, kept), count: kept}

  defp recorded(state), do: state

  # A restart's read, held where a hold is armed, taken at once where none is.
  defp reread(%{hold: :armed} = state), do: {:reply, :armed, state}
  defp reread(state), do: taken(:read, state)

  # The next failure told to a callback, taken, a read counted.
  defp taken(callback, state) do
    {how, rest} = next(Map.get(state.failures, callback, []))

    {:reply, {how, state.clock},
     counted(callback, %{state | failures: Map.put(state.failures, callback, rest)})}
  end

  defp next([]), do: {:none, []}
  defp next([how | rest]), do: {how, rest}

  defp counted(:read, state), do: %{state | reads: state.reads + 1}
  defp counted(_callback, state), do: state

  # Who holds the sim open: the process that opened it, while it is alive and has not
  # closed it, with the device it opened it for; nil for none.
  defp holder(%{reporter: pid, closed: false, device: device}) when is_pid(pid),
    do: alive(Process.alive?(pid), pid, device)

  defp holder(_state), do: nil

  defp alive(true, pid, device), do: {pid, device}
  defp alive(false, _pid, _device), do: nil

  # Decision 517 (e) (RV-21): the device a runner opened the sim for last, by whose name
  # its addresses are taken and given from then on, kept once the device closes it, and
  # by an open of a test's own; and the values by address, each spelled as the
  # configuration writes it once a runner has opened the sim, `panel.i.0` an input's and
  # `drive.q.0` an output's, a list until then.
  defp named(true, device, state), do: %{state | named: device}
  defp named(false, _device, state), do: state

  defp spelled(nil, _direction, values), do: values

  defp spelled(named, direction, values),
    do: Map.new(values, fn {address, value} -> {at(named, direction, address), value} end)

  # Every write, each address spelled once for them all, so that a sim that keeps 100,000
  # writes of a few outputs spells a few, not 100,000 of each; in the caller's process,
  # writes/1's, since RV-21's review (F5).
  defp each_spelled(writes, nil), do: writes

  defp each_spelled(writes, named) do
    names = Map.new(Enum.uniq(Enum.flat_map(writes, &Map.keys/1)), &{&1, at(named, :output, &1)})
    Enum.map(writes, &Map.new(&1, fn {address, value} -> {Map.fetch!(names, address), value} end))
  end

  # Opened by the process that holds it, or by any once none does; named for the device
  # only where it is opened, since RV-21's review (F4), so that an open refused, another
  # device holding the sim, leaves the name its holder's, where it renamed the sim for the
  # device it refused.
  defp opening({holder, held}, pid, _opener, state) when holder != pid,
    do: {:reply, {:held, holder, held}, state}

  defp opening(_holder, pid, {device, runner}, state),
    do:
      {:reply, :ok,
       named(runner, device, %{state | reporter: pid, device: device, closed: false})}

  # The device a sim reports to: the one that opened it, where it reports and an input
  # changed.
  defp set_in([address | _past], _values, state),
    do: {:reply, {:past, address, state.sizes.input, state.named}, state}

  defp set_in([], values, state) do
    changed =
      for {address, value} <- values,
          Map.get(state.inputs, address, 0) != value,
          into: %{},
          do: {address, value}

    {:reply, {reporter(state.reports, state.reporter, changed), changed, state.wait},
     %{state | inputs: Map.merge(state.inputs, values)}}
  end

  defp reporter(true, pid, changed) when is_pid(pid) and map_size(changed) > 0, do: pid
  defp reporter(_reports, _pid, _changed), do: nil

  # The options, checked in order: the list, each key, each key once, then each value.
  defp options!(opts) when is_list(opts), do: listed!(Keyword.keyword?(opts), opts)
  defp options!(opts), do: raise(ArgumentError, takes(opts))

  defp listed!(false, opts), do: raise(ArgumentError, takes(opts))

  defp listed!(true, opts) do
    keys = Keyword.keys(opts)
    known!(Enum.reject(keys, &(&1 in @options)))
    once!(keys -- Enum.uniq(keys))

    %{
      reports: reports!(Keyword.get(opts, :reports, false)),
      clock: clock!(Keyword.get(opts, :clock)),
      wait: wait!(Keyword.get(opts, :wait, 5000)),
      sizes: %{
        input: size!(Keyword.get(opts, :inputs), :inputs),
        output: size!(Keyword.get(opts, :outputs), :outputs)
      },
      kept: kept!(Keyword.get(opts, :writes, @kept))
    }
  end

  # c6-pmi-7 (RV-4): the writes a sim keeps, its newest, 100,000 unless set, so that one
  # written again every poll period for hours holds a bounded record (provisional).
  defp kept!(n) when is_integer(n) and n >= 1, do: n

  defp kept!(other),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim's writes: is how many writes it keeps, its newest, 1 or more, got: " <>
          inspect(other)
      )

  # M5-13: how many points of a direction the sim has, nil for as many as it is given.
  defp size!(nil, _key), do: nil
  defp size!(n, _key) when is_integer(n) and n >= 1, do: n

  defp size!(other, key),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim's #{key}: is how many points it has, 1 or more, or nil for as many " <>
          "as it is given, got: " <> inspect(other)
      )

  defp takes(opts),
    do:
      "Logex.IO.Sim takes a keyword list of options, reports:, clock:, wait:, inputs:, " <>
        "outputs: and writes:, got: " <> inspect(opts)

  defp known!([]), do: :ok

  defp known!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim takes reports:, clock:, wait:, inputs:, outputs: and writes:, got: " <>
          inspect(key)
      )

  # A key given twice, as `Logex.Runner.start_link/1` tells one (M5-13's review): which of
  # two values was meant is the caller's to say.
  defp once!([]), do: :ok

  defp once!([key | _]),
    do:
      raise(
        ArgumentError,
        "Logex.IO.Sim takes each option once, got #{inspect(key)} more than once"
      )

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

  # A sim is a process this module started, by its pid: what is wrong with one, `[]` for
  # none, and the sim itself where nothing is.
  defp sim!(sim), do: first!(unsimulated(sim), sim)

  defp unsimulated(sim) when is_pid(sim), do: started(Process.info(sim, :dictionary), sim)
  defp unsimulated(other), do: [expected(other)]

  defp started({:dictionary, dictionary}, sim),
    do: ours(List.keyfind(dictionary, :"$initial_call", 0), sim)

  defp started(nil, sim), do: ["the simulated device #{inspect(sim)} is not running"]

  defp ours({_key, {__MODULE__, :init, 1}}, _sim), do: []
  defp ours(_other, sim), do: [expected(sim) <> ", another process"]

  defp expected(other),
    do: "expected a simulated device from Logex.IO.Sim.start_link/1, got: #{inspect(other)}"

  defp first!([], value), do: value
  defp first!([mistake | _rest], _value), do: raise(ArgumentError, mistake)

  # The options it is bound with, `sim:` alone, a sim that is running and that no other
  # device holds open: each mistake in them, the sim's first, and then each other key; and
  # since M5-13 each point past the sim's own, where it was started with `inputs:` or
  # `outputs:`.
  defp misbound(opts, device) when is_list(opts),
    do: bound(Keyword.keyword?(opts) and Keyword.has_key?(opts, :sim), opts, device)

  defp misbound(opts, device), do: bound(false, opts, device)

  defp bound(true, opts, device) do
    sim = Keyword.fetch!(opts, :sim)

    simulated(unsimulated(sim), sim, device) ++
      twice(length(Keyword.get_values(opts, :sim))) ++
      for key <- Enum.uniq(Keyword.keys(opts)) -- [:sim],
          do: "Logex.IO.Sim is bound with sim: alone, got: #{inspect(key)}"
  end

  defp bound(false, opts, _device),
    do: [
      "Logex.IO.Sim is bound with its sim, {Logex.IO.Sim, sim: sim}, got the options " <>
        inspect(opts)
    ]

  # c3-io-contract-8 (RV-4): `sim:` once, as each option of start_link/1 is, the first of
  # two no longer taken silently.
  defp twice(1), do: []
  defp twice(n), do: ["Logex.IO.Sim is bound with sim: once, got it #{n} times"]

  defp simulated([], sim, device),
    do: free(GenServer.call(sim, :holder), sim) ++ past(GenServer.call(sim, :sizes), device)

  defp simulated(mistakes, _sim, _device), do: mistakes

  # M5-13: a point the sim has no point for, an address past its last of that direction or
  # of more than one field, each told with the sim's own range, the first ten and then a
  # count of the rest (`Logex.Array.capped/2`), so that a located array past the sim's
  # points, `temps real[10] at card.i.0` on a sim of 8 inputs, is told at each element past.
  defp past(sizes, {device, points}),
    do:
      Logex.Array.capped(
        for(
          %Point{direction: direction, address: address} = point <- points,
          size = Map.fetch!(sizes, direction),
          not within?(address, size),
          do: beyond(point, device, size)
        ),
        &"and #{&1} more point#{plural(&1)} past the sim's"
      )

  defp within?(_address, nil), do: true
  defp within?([n], size), do: n < size
  defp within?(_fields, _size), do: false

  defp beyond(%Point{name: name, direction: direction, address: address}, device, size),
    do:
      "`#{name}` is at `#{at(device, direction, address)}`, past the sim's #{size} " <>
        "#{noun(direction, size)}, `#{at(device, direction, [0])}` to " <>
        "`#{at(device, direction, [size - 1])}`"

  defp at(device, :input, address), do: Enum.join([device, "i" | address], ".")
  defp at(device, :output, address), do: Enum.join([device, "q" | address], ".")

  defp noun(:input, 1), do: "input"
  defp noun(:input, _size), do: "inputs"
  defp noun(:output, 1), do: "output"
  defp noun(:output, _size), do: "outputs"

  defp plural(1), do: ""
  defp plural(_n), do: "s"

  # Held by none, or by the very process that asks, which may open it again.
  defp free(nil, _sim), do: []
  defp free({pid, _device}, _sim) when pid == self(), do: []
  defp free({pid, device}, sim), do: [holding(sim, pid, device)]

  # The sim init/3 opens, its options' first mistake raised.
  defp bound!(opts, device), do: Keyword.fetch!(first!(misbound(opts, device), opts), :sim)

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

  # The values the runner's device writes, by the adapter's own address, a list.
  defp values!(values) when is_map(values) and not is_struct(values) do
    Enum.each(values, fn {address, value} -> {address!(address), value!(value)} end)
    values
  end

  defp values!(other), do: raise(ArgumentError, by_address(other))

  # The inputs a test sets, by the address set/3 takes.
  defp inputs!(values, named, sim) when is_map(values) and not is_struct(values),
    do:
      Map.new(values, fn {address, value} -> {addressed!(named, address, sim), value!(value)} end)

  defp inputs!(other, _named, _sim), do: raise(ArgumentError, by_address(other))

  defp by_address(other),
    do: "values go by address, a map of addresses to numbers, got: #{inspect(other)}"

  # Decision 517 (e) (RV-21): an input's address as a test gives one, a list until a runner
  # has opened the sim and from then on the configuration's text, the device's own input,
  # `panel.i.0`, read as the configuration reads a location (`Logex.Configuration.
  # location/1`), its one spelling, and taken as its list, `[0]`; the other form, and a
  # text that is no input of the device's, the test's mistake, its message naming the
  # form the sim takes (provisional, `PLAN.md`'s RV-21 question 3).
  defp addressed!(nil, address, _sim) when is_list(address), do: address!(address)

  defp addressed!(nil, address, sim) when is_binary(address),
    do:
      raise(
        ArgumentError,
        "no runner has opened the simulated device #{inspect(sim)}, so it knows no device's " <>
          "name: until one has, an input's address is a list of whole numbers, [0], got: " <>
          inspect(address)
      )

  defp addressed!(nil, address, _sim), do: address!(address)

  defp addressed!(named, address, sim) when is_binary(address),
    do: located!(Logex.Configuration.location(address), named, address, sim)

  defp addressed!(named, address, sim),
    do:
      raise(
        ArgumentError,
        "a runner has opened the simulated device #{inspect(sim)} for the device `#{named}`: " <>
          "an input's address is the configuration's text from then on, " <>
          "#{inspect(at(named, :input, [0]))}, got: " <>
          inspect(address, charlists: :as_lists)
      )

  defp located!({:ok, {named, "i", fields}}, named, _address, _sim), do: fields

  defp located!({:ok, {named, "q", _fields}}, named, address, sim),
    do:
      raise(
        ArgumentError,
        "#{inspect(address)} is an output of the device `#{named}`, and set/2 and set/3 " <>
          "set the simulated device #{inspect(sim)}'s inputs"
      )

  defp located!({:ok, {device, _io, _fields}}, named, address, sim),
    do:
      raise(
        ArgumentError,
        "#{inspect(address)} is the device `#{device}`'s, and the simulated device " <>
          "#{inspect(sim)} is the device `#{named}`'s, its inputs " <>
          "#{inspect(at(named, :input, [0]))} and on"
      )

  defp located!(:error, named, address, _sim),
    do:
      raise(
        ArgumentError,
        "#{inspect(address)} is no address as the configuration writes one, an input of " <>
          "the device `#{named}` as #{inspect(at(named, :input, [0]))}"
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

  # M5-10: a real point's value is a float or an integer, which the runner stores as its
  # nearest real (decision 166); every other point's an integer, which the runner checks.
  defp value!(value) when is_number(value), do: value

  defp value!(other),
    do: raise(ArgumentError, "a point's value is a number, got: #{inspect(other)}")

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
