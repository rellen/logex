defmodule Logex.IOTest do
  @moduledoc """
  M4-1: the adapter behaviour the wall-clock runner reads and writes devices through
  (`docs/organisation.md` §4.5 and §4.11), `Logex.IO` with `%Logex.IO.Point{}`, and the
  one adapter logex ships, `Logex.IO.Sim`: every rule of the simulated device, its change
  reports and each failure it acts out, and every mistake a test can make with it, each
  message pinned. Its callbacks are called as a device's process calls them, from the
  test's process or from a small GenServer that stands for the device's.
  """
  use ExUnit.Case, async: true

  alias Logex.IO.{Point, Sim}
  alias Logex.Runner.Clock.Manual

  # A device's process, as the runner's will be: it opens the sim in its own process,
  # reads it when asked, and takes each message it is sent through report/2, recording
  # what each gave; told to, it takes its time over each, and then tells the test.
  defmodule Device do
    use GenServer

    def start(opts, slow \\ nil), do: GenServer.start_link(__MODULE__, {opts, slow})
    def read(pid), do: GenServer.call(pid, :read)
    def reported(pid), do: GenServer.call(pid, :reported)

    @impl true
    def init({opts, slow}) do
      {:ok, state} = Logex.IO.Sim.init("panel", Logex.IOTest.points(), opts)
      {:ok, %{adapter: state, reported: [], slow: slow}}
    end

    @impl true
    def handle_call(:read, _from, s) do
      {:ok, values, adapter} = Logex.IO.Sim.read(s.adapter)
      {:reply, values, %{s | adapter: adapter}}
    end

    def handle_call(:reported, _from, s), do: {:reply, Enum.reverse(s.reported), s}

    @impl true
    def handle_info(message, s) do
      {:ok, changed, adapter} = Logex.IO.Sim.report(message, s.adapter)
      told(s.slow, changed)
      {:noreply, %{s | adapter: adapter, reported: [changed | s.reported]}}
    end

    defp told(nil, _changed), do: :ok

    defp told({test, ms}, changed) do
      Process.sleep(ms)
      send(test, {:handled, changed})
    end
  end

  # A device's process that opens the sim and goes down with the reason :timeout while it
  # handles its first report, as one whose adapter's own call timed out may: once the :sys
  # call that waits for it has come, so that set/3 is waiting when it goes, and by an exit
  # signal to itself, so that OTP writes no crash report.
  defmodule StopsOnReport do
    use GenServer

    def start(sim), do: GenServer.start(__MODULE__, sim)

    @impl true
    def init(sim), do: Logex.IO.Sim.init("panel", Logex.IOTest.points(), sim: sim)

    @impl true
    def handle_info(_report, _state) do
      receive do: ({:system, _from, _request} -> Process.exit(self(), :timeout))
      Process.sleep(:infinity)
    end
  end

  # The panel's points: three inputs, one of them a dint two fields deep, and two outputs.
  def points,
    do: [
      %Point{name: "start", direction: :input, address: [0], type: :bool},
      %Point{name: "stop", direction: :input, address: [1], type: :bool},
      %Point{name: "speed", direction: :input, address: [2, 1], type: :dint},
      %Point{name: "motor", direction: :output, address: [0], type: :bool},
      %Point{name: "sp", direction: :output, address: [1], type: :dint}
    ]

  defp sim(opts \\ []) do
    {:ok, sim} = Sim.start_link(opts)
    sim
  end

  # The sim opened from the test's process: the adapter's state.
  defp opened(sim) do
    {:ok, state} = Sim.init("panel", points(), sim: sim)
    state
  end

  defp device(opts, slow \\ nil) do
    {:ok, pid} = Device.start(opts, slow)
    pid
  end

  # A value passed through a function the type checker cannot see through, so that a
  # deliberate mistake draws no warning (as runtime_test.exs's opaque/1).
  defp opaque(value), do: :erlang.binary_to_term(:erlang.term_to_binary(value))

  # Returns once `pid` is in Process.sleep/1, looking every millisecond.
  defp asleep(pid), do: asleep(pid, Process.info(pid, :current_function))

  defp asleep(_pid, {:current_function, {Process, :sleep, 1}}), do: :ok

  defp asleep(pid, _elsewhere) do
    Process.sleep(1)
    asleep(pid)
  end

  describe "Logex.IO, the behaviour" do
    test "is six callbacks, report/2, close/1 and check/3 optional" do
      assert Enum.sort(Logex.IO.behaviour_info(:callbacks)) ==
               [check: 3, close: 1, init: 3, read: 1, report: 2, write: 2]

      assert Enum.sort(Logex.IO.behaviour_info(:optional_callbacks)) ==
               [check: 3, close: 1, report: 2]
    end

    test "a point is its name, direction, address and type, each enforced" do
      enforced = for %{field: field, required: true} <- Point.__info__(:struct), do: field
      assert Enum.sort(enforced) == [:address, :direction, :name, :type]

      assert Enum.sort(Map.keys(Point.__struct__())) == [
               :__struct__,
               :address,
               :direction,
               :name,
               :type
             ]
    end

    test "the simulated device implements every callback" do
      behaviours = List.flatten(Keyword.get_values(Sim.module_info(:attributes), :behaviour))
      assert Logex.IO in behaviours

      for {name, arity} <- Logex.IO.behaviour_info(:callbacks),
          do: assert(function_exported?(Sim, name, arity))
    end
  end

  describe "the simulated device" do
    test "starts linked to the caller" do
      sim = sim()
      assert {:links, links} = Process.info(self(), :links)
      assert sim in links
    end

    test "reads every input point of its device, 0 until set, and counts its reads" do
      sim = sim()
      state = opened(sim)
      assert Sim.read(state) == {:ok, %{[0] => 0, [1] => 0, [2, 1] => 0}, state}

      assert Sim.set(sim, [0], 1) == :ok
      assert Sim.set(sim, %{[1] => 1, [2, 1] => -120, [9] => 1}) == :ok
      assert {:ok, values, ^state} = Sim.read(state)
      assert values == %{[0] => 1, [1] => 1, [2, 1] => -120}
      assert Sim.reads(sim) == 2
    end

    test "records every write in order, and the last value written to each output" do
      sim = sim()
      state = opened(sim)
      assert Sim.outputs(sim) == %{}
      assert {:ok, ^state} = Sim.write(%{[0] => 1, [1] => 1200}, state)
      assert {:ok, ^state} = Sim.write(%{[0] => 0, [1] => 1200}, state)

      assert Sim.outputs(sim) == %{[0] => 0, [1] => 1200}
      assert Sim.writes(sim) == [%{[0] => 1, [1] => 1200}, %{[0] => 0, [1] => 1200}]

      # A write of some outputs leaves the others as last written.
      assert {:ok, ^state} = Sim.write(%{[1] => 900}, state)
      assert Sim.outputs(sim) == %{[0] => 0, [1] => 900}
    end

    test "is closed by close/1 until it is opened again" do
      sim = sim()
      state = opened(sim)
      refute Sim.closed?(sim)
      assert Sim.close(state) == :ok
      assert Sim.closed?(sim)
      opened(sim)
      refute Sim.closed?(sim)
    end

    test "reports each change of an input to the device that opened it, and set/3 returns " <>
           "once that device has handled the report" do
      sim = sim(reports: true)
      pid = device(sim: sim)

      Sim.set(sim, [0], 1)
      assert Device.reported(pid) == [%{[0] => 1}]

      # One report for what changed of what is set, none for what did not change.
      Sim.set(sim, %{[0] => 1, [1] => 1, [2, 1] => 900})
      Sim.set(sim, [0], 1)
      Sim.set(sim, [1], 0)
      assert Device.reported(pid) == [%{[0] => 1}, %{[1] => 1, [2, 1] => 900}, %{[1] => 0}]

      # An address that is no input point changes the sim, and reports nothing of the device's.
      Sim.set(sim, [9], 1)
      assert List.last(Device.reported(pid)) == %{}
      assert Device.read(pid) == %{[0] => 1, [1] => 0, [2, 1] => 900}
    end

    test "an input never set reads 0, so setting it to 0 changes nothing and reports nothing" do
      sim = sim(reports: true)
      pid = device(sim: sim)

      Sim.set(sim, [0], 0)
      Sim.set(sim, %{[1] => 0, [2, 1] => 0})
      assert Device.reported(pid) == []

      # One of several set to what it was is left out of the report.
      Sim.set(sim, %{[0] => 0, [1] => 1})
      assert Device.reported(pid) == [%{[1] => 1}]
    end

    test "set/3 returns only once the device has handled the report, however long it takes" do
      sim = sim(reports: true)
      # The device takes 30 ms of real time over each report, and then tells the test.
      device([sim: sim], {self(), 30})

      Sim.set(sim, [0], 1)
      assert_received {:handled, %{[0] => 1}}
    end

    test "takes the longest wait the VM can wait, and waits it for the device" do
      sim = sim(reports: true, wait: 4_294_967_295)
      pid = device(sim: sim)
      assert Sim.set(sim, [0], 1) == :ok
      assert Device.reported(pid) == [%{[0] => 1}]
    end

    test "a sim that does not report sends nothing: its device is only read" do
      sim = sim()
      pid = device(sim: sim)
      Sim.set(sim, [0], 1)
      assert Device.reported(pid) == []
      assert Device.read(pid) == %{[0] => 1, [1] => 0, [2, 1] => 0}
    end

    test "reports to the process that opened it last, and to the one that sets, in its " <>
           "own mailbox" do
      sim = sim(reports: true)
      first = device(sim: sim)
      state = opened(sim)

      Sim.set(sim, [1], 1)
      assert_received {Sim, ^sim, _changed} = report
      assert report == {Sim, sim, %{[1] => 1}}
      assert Sim.report(report, state) == {:ok, %{[1] => 1}, state}
      assert Device.reported(first) == []
    end

    test "report/2 gives nothing for a message that is not its own sim's report" do
      sim = sim()
      state = opened(sim)
      assert Sim.report(:other, state) == {:ok, %{}, state}
      assert Sim.report({Sim, sim(), %{[0] => 1}}, state) == {:ok, %{}, state}
    end

    test "acts out each failure on the call it names, once, in the order told" do
      sim = sim()

      Sim.fail(sim, :init, {:error, :econnrefused})
      assert Sim.init("panel", points(), sim: sim) == {:error, :econnrefused}
      state = opened(sim)

      Sim.fail(sim, :read, {:error, :timeout})
      Sim.fail(sim, :read, :raise)
      Sim.fail(sim, :read, :throw)
      Sim.fail(sim, :read, :exit)
      Sim.fail(sim, :read, {:value, [0], 7})
      Sim.fail(sim, :read, {:value, [9], 1})
      assert Sim.read(state) == {:error, :timeout, state}

      assert_raise RuntimeError,
                   "the simulated device \"panel\" raised in read, as fail/3 told it",
                   fn -> Sim.read(state) end

      assert catch_throw(Sim.read(state)) == {Sim, :read}
      assert catch_exit(Sim.read(state)) == {Sim, :read}
      assert Sim.read(state) == {:ok, %{[0] => 7, [1] => 0, [2, 1] => 0}, state}
      assert Sim.read(state) == {:ok, %{[0] => 0, [1] => 0, [2, 1] => 0, [9] => 1}, state}
      assert Sim.read(state) == {:ok, %{[0] => 0, [1] => 0, [2, 1] => 0}, state}
      assert Sim.reads(sim) == 7

      Sim.fail(sim, :write, {:error, :busy})
      assert Sim.write(%{[0] => 1, [1] => 5}, state) == {:error, :busy, state}
      assert Sim.writes(sim) == []
      Sim.fail(sim, :write, :raise)

      assert_raise RuntimeError,
                   "the simulated device \"panel\" raised in write, as fail/3 told it",
                   fn -> Sim.write(%{[0] => 1, [1] => 5}, state) end

      assert Sim.writes(sim) == []

      Sim.fail(sim, :report, {:error, :garbled})
      Sim.fail(sim, :report, {:value, [1], 2})
      report = {Sim, sim, %{[0] => 1}}
      assert Sim.report(report, state) == {:error, :garbled, state}
      assert Sim.report(report, state) == {:ok, %{[0] => 1, [1] => 2}, state}
      # Another message takes no failure told to a report.
      Sim.fail(sim, :report, :raise)
      assert Sim.report(:other, state) == {:ok, %{}, state}

      assert_raise RuntimeError,
                   "the simulated device \"panel\" raised in report, as fail/3 told it",
                   fn -> Sim.report(report, state) end

      Sim.fail(sim, :close, :exit)
      assert catch_exit(Sim.close(state)) == {Sim, :close}
      refute Sim.closed?(sim)
      assert Sim.close(state) == :ok
    end

    test "a hang blocks the device's process for ever" do
      sim = sim()
      state = opened(sim)
      Sim.fail(sim, :read, :hang)
      task = Task.async(fn -> Sim.read(state) end)
      assert Task.yield(task, 100) == nil
      Task.shutdown(task, :brutal_kill)
      assert {:ok, _values, ^state} = Sim.read(state)
    end

    test "a delay passes on its manual clock, delivering nothing, before the call goes on" do
      {:ok, clock} = Manual.start_link()
      Manual.wake_at(clock, self(), :due, 100)
      sim = sim(clock: clock)
      state = opened(sim)
      Sim.fail(sim, :read, {:delay, 150})
      Sim.fail(sim, :write, {:delay, 50})

      assert Sim.read(state) == {:ok, %{[0] => 0, [1] => 0, [2, 1] => 0}, state}
      assert Manual.now_ms(clock) == 150
      assert {:ok, ^state} = Sim.write(%{[0] => 1, [1] => 0}, state)
      assert Manual.now_ms(clock) == 200
      assert Sim.writes(sim) == [%{[0] => 1, [1] => 0}]
      assert Manual.pending(clock) == [{100, self(), :due}]
      refute_received :due
    end

    test "a delay is acted out before its call: a write that sleeps its delay has written " <>
           "nothing yet" do
      sim = sim()
      state = opened(sim)
      Sim.fail(sim, :write, {:delay, 60_000})
      task = Task.async(fn -> Sim.write(%{[0] => 1, [1] => 5}, state) end)
      asleep(task.pid)

      assert Sim.writes(sim) == []
      Task.shutdown(task, :brutal_kill)
    end

    test "a delay without a clock sleeps in real time, no less" do
      sim = sim()
      state = opened(sim)
      Sim.fail(sim, :init, {:delay, 30})
      before = System.monotonic_time(:millisecond)
      assert {:ok, _state} = Sim.init("panel", points(), sim: sim)
      assert System.monotonic_time(:millisecond) - before >= 30
      assert Sim.close(state) == :ok
    end

    test "waits 5000 ms for the device that opened it unless wait: says otherwise" do
      sim = sim(reports: true)
      test = self()

      plain =
        spawn_link(fn ->
          {:ok, _state} = Sim.init("panel", points(), sim: sim)
          send(test, :opened)
          receive do: (:never -> :ok)
        end)

      assert_receive :opened, 5_000

      assert_raise ArgumentError, ~r/^Logex.IO.Sim waited 5000 ms for #{inspect(plain)}, /, fn ->
        Sim.set(sim, [0], 1)
      end
    end

    test "a device that does not answer :sys within wait: is the test's mistake" do
      sim = sim(reports: true, wait: 20)
      test = self()

      plain =
        spawn_link(fn ->
          {:ok, _state} = Sim.init("panel", points(), sim: sim)
          send(test, :opened)
          receive do: (:never -> :ok)
        end)

      assert_receive :opened, 5_000

      assert_raise ArgumentError,
                   "Logex.IO.Sim waited 20 ms for #{inspect(plain)}, the device that opened " <>
                     "it, to handle its report: a device is an OTP process, as the runner's " <>
                     "are, which answers :sys once it has handled what it was sent",
                   fn -> Sim.set(sim, [0], 1) end
    end

    test "waits only wait: for the device: one that answers later is still the test's " <>
           "mistake" do
      sim = sim(reports: true, wait: 20)
      # The device takes a second of real time over the report, well within 5000 ms.
      device([sim: sim], {self(), 1_000})

      assert_raise ArgumentError, ~r/^Logex.IO.Sim waited 20 ms for /, fn ->
        Sim.set(sim, [0], 1)
      end
    end

    test "a device that is down is passed over by set/3" do
      sim = sim(reports: true)
      pid = device(sim: sim)
      GenServer.stop(pid)
      assert Sim.set(sim, [0], 1) == :ok
      assert {:ok, values, _state} = Sim.read(opened(sim))
      assert values == %{[0] => 1, [1] => 0, [2, 1] => 0}
    end

    test "a device that stops with the reason :timeout while it handles the report is " <>
           "passed over by set/3" do
      sim = sim(reports: true)
      {:ok, pid} = StopsOnReport.start(sim)
      assert Sim.set(sim, [0], 1) == :ok
      refute Process.alive?(pid)
      assert {:ok, %{[0] => 1, [1] => 0, [2, 1] => 0}, _state} = Sim.read(opened(sim))
    end

    test "check/3 gives each mistake in the options it is bound with, which bind!/2 raises " <>
           "in the host's process and init/3 the first of in the device's" do
      sim = sim()
      {:ok, stopped} = Sim.start_link()
      GenServer.stop(stopped)
      {:ok, other} = Agent.start_link(fn -> nil end)
      config = configured("var_global lamp bool at panel.q.0\nprogram m blink\n  m.lamp lamp\n")

      assert Sim.check("panel", points(), sim: sim) == []

      assert [{"panel", Sim, [sim: sim], _points}] =
               Logex.IO.bind!(config, %{"panel" => {Sim, sim: sim}})

      assert {:ok, _state} = Sim.init("panel", points(), sim: sim)

      for {opts, [first | _rest] = mistakes} <- [
            {[],
             [
               "Logex.IO.Sim is bound with its sim, {Logex.IO.Sim, sim: sim}, got the options []"
             ]},
            {[simulator: sim],
             [
               "Logex.IO.Sim is bound with its sim, {Logex.IO.Sim, sim: sim}, got the options " <>
                 "[simulator: #{inspect(sim)}]"
             ]},
            {[sim: :panel],
             ["expected a simulated device from Logex.IO.Sim.start_link/1, got: :panel"]},
            {[sim: stopped], ["the simulated device #{inspect(stopped)} is not running"]},
            {[sim: other],
             [
               "expected a simulated device from Logex.IO.Sim.start_link/1, got: " <>
                 "#{inspect(other)}, another process"
             ]},
            {[sim: sim, reports: true, clock: nil],
             [
               "Logex.IO.Sim is bound with sim: alone, got: :reports",
               "Logex.IO.Sim is bound with sim: alone, got: :clock"
             ]},
            {[sim: :panel, reports: true],
             [
               "expected a simulated device from Logex.IO.Sim.start_link/1, got: :panel",
               "Logex.IO.Sim is bound with sim: alone, got: :reports"
             ]}
          ] do
        assert Sim.check("panel", points(), opaque(opts)) == mistakes
        lines = for mistake <- mistakes, do: "the device `panel`'s adapter options: " <> mistake

        assert_raise ArgumentError, Enum.join(lines, "\n"), fn ->
          Logex.IO.bind!(config, %{"panel" => {Sim, opaque(opts)}})
        end

        assert_raise ArgumentError, first, fn -> Sim.init("panel", points(), opaque(opts)) end
      end

      # Bound alone, it is given no options, and so no sim.
      assert_raise ArgumentError,
                   "the device `panel`'s adapter options: Logex.IO.Sim is bound with its sim, " <>
                     "{Logex.IO.Sim, sim: sim}, got the options []",
                   fn -> Logex.IO.bind!(config, %{"panel" => Sim}) end
    end

    test "refuses options, sims, addresses, values and failures that are not ones, each " <>
           "with its message" do
      for {opts, message} <- [
            {:fast,
             "Logex.IO.Sim takes a keyword list of options, reports:, clock: and wait:, got: " <>
               ":fast"},
            {[1],
             "Logex.IO.Sim takes a keyword list of options, reports:, clock: and wait:, got: " <>
               "[1]"},
            {[loud: true], "Logex.IO.Sim takes reports:, clock: and wait:, got: :loud"},
            {[reports: :yes], "Logex.IO.Sim's reports: is true or false, got: :yes"},
            {[clock: :nope],
             "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, got: :nope"},
            {[wait: 0],
             "Logex.IO.Sim's wait: is a whole number of milliseconds, 1 to 4294967295, the " <>
               "longest the VM waits, got: 0"},
            {[wait: 4_294_967_296],
             "Logex.IO.Sim's wait: is a whole number of milliseconds, 1 to 4294967295, the " <>
               "longest the VM waits, got: 4294967296"}
          ],
          do: assert_raise(ArgumentError, message, fn -> Sim.start_link(opaque(opts)) end)

      {:ok, stopped} = Sim.start_link()
      GenServer.stop(stopped)
      {:ok, other} = Agent.start_link(fn -> nil end)

      for {not_a_sim, message} <- [
            {:nope, "expected a simulated device from Logex.IO.Sim.start_link/1, got: :nope"},
            {stopped, "the simulated device #{inspect(stopped)} is not running"},
            {other,
             "expected a simulated device from Logex.IO.Sim.start_link/1, got: " <>
               "#{inspect(other)}, another process"}
          ],
          call <- [
            &Sim.set(&1, [0], 1),
            &Sim.set(&1, %{[0] => 1}),
            &Sim.outputs/1,
            &Sim.writes/1,
            &Sim.reads/1,
            &Sim.closed?/1,
            &Sim.fail(&1, :read, :raise),
            &Sim.init("panel", points(), sim: &1)
          ],
          do: assert_raise(ArgumentError, message, fn -> call.(opaque(not_a_sim)) end)

      sim = sim()
      state = opened(sim)

      for address <- [[], [-1], [1.5], :a, [0 | 1]] do
        assert_raise ArgumentError,
                     "an address is a list of whole numbers, 0 or more, as `panel.i.1.3`'s " <>
                       "is [1, 3], got: #{inspect(address)}",
                     fn -> Sim.set(sim, opaque(address), 1) end

        assert_raise ArgumentError,
                     "an address is a list of whole numbers, 0 or more, as `panel.i.1.3`'s " <>
                       "is [1, 3], got: #{inspect(address)}",
                     fn -> Sim.set(sim, opaque(%{address => 1})) end
      end

      for value <- [1.5, :on] do
        assert_raise ArgumentError, "a point's value is an integer, got: #{inspect(value)}", fn ->
          Sim.set(sim, [0], opaque(value))
        end

        assert_raise ArgumentError, "a point's value is an integer, got: #{inspect(value)}", fn ->
          Sim.write(opaque(%{[0] => value}), state)
        end
      end

      for values <- [[{[0], 1}], MapSet.new([1])] do
        message =
          "values go by address, a map of addresses to integers, got: #{inspect(values)}"

        assert_raise ArgumentError, message, fn -> Sim.set(sim, opaque(values)) end
        assert_raise ArgumentError, message, fn -> Sim.write(opaque(values), state) end
      end

      assert_raise ArgumentError,
                   "Logex.IO.Sim fails one of its callbacks, :init, :read, :write, :report or " <>
                     ":close, got: :open",
                   fn -> Sim.fail(sim, opaque(:open), :raise) end

      for how <- [:explode, {:delay, -1}, {:delay, 1.5}, {:error}] do
        assert_raise ArgumentError,
                     "a failure is {:error, reason}, :raise, :throw, :exit, :hang, {:delay, ms} " <>
                       "with ms 0 or more, or, for a read or a report, {:value, address, " <>
                       "value}, got: #{inspect(how)}",
                     fn -> Sim.fail(sim, :read, opaque(how)) end
      end

      for {callback, how} <- [
            close: {:error, :x},
            close: {:value, [0], 1},
            init: {:value, [0], 1},
            write: {:value, [0], 1}
          ] do
        assert_raise ArgumentError,
                     "Logex.IO.Sim cannot act out #{inspect(how)} in #{callback}",
                     fn -> Sim.fail(sim, callback, opaque(how)) end
      end

      assert_raise ArgumentError,
                   "an address is a list of whole numbers, 0 or more, as `panel.i.1.3`'s is " <>
                     "[1, 3], got: :a",
                   fn -> Sim.fail(sim, :read, opaque({:value, :a, 1})) end

      for opts <- [[], :nope, [other: sim]] do
        assert_raise ArgumentError,
                     "Logex.IO.Sim is bound with its sim, {Logex.IO.Sim, sim: sim}, got the " <>
                       "options #{inspect(opts)}",
                     fn -> Sim.init("panel", points(), opaque(opts)) end
      end

      for points <- [:points, [:x], [%{name: "x"}]] do
        assert_raise ArgumentError,
                     "Logex.IO.Sim opens a device given its points, a list of " <>
                       "%Logex.IO.Point{}, got: #{inspect(points)}",
                     fn -> Sim.init("panel", opaque(points), sim: sim) end
      end
    end
  end

  # §4.4's plant, cut from docs/organisation.md with §4.3's motor and seal-in block, as
  # config_edit_test.exs cuts it.
  defp document, do: File.read!("docs/organisation.md")

  defp cut(after_text) do
    [_before, rest] = String.split(document(), after_text, parts: 2)
    [_before, block] = String.split(rest, "```\n", parts: 2)
    [text, _after] = String.split(block, "```", parts: 2)
    text
  end

  defp plant_text do
    [_before, rest] = String.split(document(), "```\n// plant.", parts: 2)
    [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
    plant
  end

  @snapshot_ld """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  # The plant written to disk and loaded from there, as a host loads it.
  defp plant_on_disk(dir) do
    for {name, text} <- [
          {"seal.ld", cut("**A function block type** is")},
          {"motor.ld", cut("**The motor, rewritten to use it**")},
          {"snapshot.ld", @snapshot_ld},
          {"plant.logex", plant_text()}
        ],
        do: File.write!(Path.join(dir, name), text)

    assert {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
    plant
  end

  defp input(name, address, type \\ :bool),
    do: %Point{name: name, direction: :input, address: address, type: type}

  defp output(name, address, type \\ :bool),
    do: %Point{name: name, direction: :output, address: address, type: type}

  defp panel_points,
    do: [
      input("estop", [7]),
      input("pb_start_1", [0]),
      input("pb_stop_1", [1]),
      input("tt_1", [2]),
      input("pb_start_2", [3]),
      input("pb_stop_2", [4]),
      input("tt_2", [5]),
      input("pb_reset", [6]),
      output("k1", [0]),
      output("k2", [1]),
      output("lamp_1", [2]),
      output("lamp_2", [3])
    ]

  defp drive_points, do: [output("sp_1", [0], :dint), output("sp_2", [1], :dint)]

  @blink_ld """
  var_output lamp bool

  xio lamp ote lamp
  """

  # A small configuration from text, with one instance of a program that blinks its lamp.
  defp configured(text) do
    {:ok, blink} = Logex.compile(@blink_ld, name: "blink")
    assert {:ok, config} = Logex.Configuration.compile("rack", text, %{"blink" => blink})
    config
  end

  # An adapter that implements every callback Logex.IO requires, and checks nothing.
  defmodule Plain do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, _opts), do: {:ok, nil}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, state), do: {:ok, state}
  end

  # An adapter whose check/3 tells the test what it was given and in which process, and
  # gives back what its options say to.
  defmodule Checked do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, _opts), do: {:ok, nil}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, state), do: {:ok, state}

    @impl true
    def check(device, points, opts) do
      send(Keyword.fetch!(opts, :test), {:checked, self(), device, points, opts})
      Keyword.get(opts, :gives, [])
    end
  end

  # A module with a check/3 that would tell the test it was called, and no write/2.
  defmodule HalfChecked do
    def init(_device, _points, _opts), do: {:ok, nil}
    def read(state), do: {:ok, %{}, state}

    def check(device, points, opts) do
      send(Keyword.fetch!(opts, :test), {:checked, self(), device, points, opts})
      []
    end
  end

  # A module that has an adapter's init/3 and read/1, and no write/2.
  defmodule HalfAdapter do
    def init(_device, _points, _opts), do: {:ok, nil}
    def read(state), do: {:ok, %{}, state}
  end

  describe "a configuration's points, by device" do
    @describetag :tmp_dir

    test "§4.4's plant, from files on disk, groups as panel, eight inputs and four outputs, " <>
           "and drive, two outputs, each in the configuration's order",
         %{tmp_dir: dir} do
      assert Logex.IO.points(plant_on_disk(dir)) == %{
               "panel" => panel_points(),
               "drive" => drive_points()
             }

      assert Enum.count(panel_points(), &(&1.direction == :input)) == 8
      assert Enum.count(panel_points(), &(&1.direction == :output)) == 4
    end

    test "an address several fields deep, and no device where no global is located" do
      config =
        configured("""
        var_global eye bool at rack.i.1.3
        var_global hold bool
        var_global lamp bool at rack.q.0
        var_global speed dint at rack.i.0
        program m blink
          m.lamp lamp
        """)

      assert Logex.IO.points(config) == %{
               "rack" => [input("eye", [1, 3]), output("lamp", [0]), input("speed", [0], :dint)]
             }

      assert Logex.IO.points(configured("var_global lamp bool\nprogram m blink\n  m.lamp lamp\n")) ==
               %{}
    end

    test "a configuration Logex.Runtime.start/1 refuses raises in its words" do
      {:ok, blink} = Logex.compile(@blink_ld, name: "blink")

      config = %Logex.Configuration{
        name: "rack",
        programs: %{"blink" => blink},
        instances: [%Logex.Configuration.Instance{name: "m", type: "nope"}]
      }

      message = assert_raise(ArgumentError, fn -> Logex.Runtime.start(config) end).message
      assert message =~ "nope"
      assert_raise ArgumentError, message, fn -> Logex.IO.points(config) end
      assert_raise ArgumentError, message, fn -> Logex.IO.bind!(config, %{}) end

      assert_raise ArgumentError, "expected a %Logex.Configuration{}, got: :nope", fn ->
        Logex.IO.points(opaque(:nope))
      end
    end
  end

  # A configuration of `devices` devices, `dev1` and on, each with ten input points, built
  # from Elixir data, and one instance of the blinking program.
  defp many(devices, name \\ &"dev#{&1}") do
    {:ok, blink} = Logex.compile(@blink_ld, name: "blink")

    globals =
      for device <- 1..devices,
          address <- 0..9,
          do: %Logex.Configuration.Global{
            name: "p#{device}_#{address}",
            type: :bool,
            at: "#{name.(device)}.i.#{address}"
          }

    Logex.Configuration.new!(
      name: "many",
      programs: [blink],
      globals: globals ++ [%Logex.Configuration.Global{name: "lamp", type: :bool}],
      instances: [%Logex.Configuration.Instance{name: "m", type: "blink"}],
      connections: [%Logex.Configuration.Connection{instance: "m", member: "lamp", to: "lamp"}]
    )
  end

  describe "a host's bindings" do
    @describetag :tmp_dir

    test "give each device with its adapter, its options and its points, in device-name " <>
           "order",
         %{tmp_dir: dir} do
      sim = sim()

      assert Logex.IO.bind!(plant_on_disk(dir), %{"panel" => {Sim, sim: sim}, "drive" => Plain}) ==
               [{"drive", Plain, [], drive_points()}, {"panel", Sim, [sim: sim], panel_points()}]

      assert Logex.IO.bind!(
               configured("var_global lamp bool\nprogram m blink\n  m.lamp lamp\n"),
               %{}
             ) ==
               []
    end

    test "every mistake comes in one ArgumentError, a line each, a key that is no device's " <>
           "name first, then in device-name order",
         %{tmp_dir: dir} do
      io = %{:panel => Plain, "panle" => Plain, "drive" => 42}

      assert_raise ArgumentError,
                   Enum.join(
                     [
                       "io names each device by a string, got: :panel — did you mean \"panel\"?",
                       "the device `drive` is bound to 42: an adapter is a module that " <>
                         "implements Logex.IO, or {module, options}",
                       "no adapter is bound to the device `panel`, which `estop` (panel.i.7), " <>
                         "`pb_start_1` (panel.i.0), `pb_stop_1` (panel.i.1), `tt_1` " <>
                         "(panel.i.2), `pb_start_2` (panel.i.3), `pb_stop_2` (panel.i.4), " <>
                         "`tt_2` (panel.i.5), `pb_reset` (panel.i.6), `k1` (panel.q.0), `k2` " <>
                         "(panel.q.1), `lamp_1` (panel.q.2) and `lamp_2` (panel.q.3) are at",
                       "the device `panle` is bound, but no point is at it — did you mean " <>
                         "`panel`?"
                     ],
                     "\n"
                   ),
                   fn -> Logex.IO.bind!(plant_on_disk(dir), opaque(io)) end
    end

    test "a device no adapter is bound to is told the points at it" do
      config =
        configured("""
        var_global lamp bool at drive.q.2
        var_global sp_1 dint at drive.q.0
        var_global sp_2 dint at drive.q.1.4
        program m blink
          m.lamp lamp
        """)

      assert_raise ArgumentError,
                   "no adapter is bound to the device `drive`, which `lamp` (drive.q.2), `sp_1` " <>
                     "(drive.q.0) and `sp_2` (drive.q.1.4) are at",
                   fn -> Logex.IO.bind!(config, %{}) end

      two =
        configured("""
        var_global lamp bool at drive.q.2
        var_global sp_1 dint at drive.q.0
        program m blink
          m.lamp lamp
        """)

      assert_raise ArgumentError,
                   "no adapter is bound to the device `drive`, which `lamp` (drive.q.2) and " <>
                     "`sp_1` (drive.q.0) are at",
                   fn -> Logex.IO.bind!(two, %{}) end

      lone = configured("var_global lamp bool at drive.q.2\nprogram m blink\n  m.lamp lamp\n")

      assert_raise ArgumentError,
                   "no adapter is bound to the device `drive`, which `lamp` (drive.q.2) is at",
                   fn -> Logex.IO.bind!(lone, %{}) end
    end

    test "more than 32 devices come back in name order" do
      names = for device <- 1..40, do: "dev#{device}"
      bound = Logex.IO.bind!(many(40), Map.new(names, &{&1, Plain}))
      assert Enum.map(bound, &elem(&1, 0)) == Enum.sort(names)
    end

    test "more than 32 mistakes come in order: keys that are no names, then devices by name" do
      names = Enum.sort(for device <- 1..40, do: "dev#{device}")
      keys = for key <- 1..40, do: String.to_atom("key#{key}")

      lines =
        for(key <- Enum.sort(keys), do: "io names each device by a string, got: #{inspect(key)}") ++
          for name <- names do
            points =
              for address <- 0..9,
                  do: "`p#{String.trim_leading(name, "dev")}_#{address}` (#{name}.i.#{address})"

            "no adapter is bound to the device `#{name}`, which " <>
              Enum.join(Enum.drop(points, -1), ", ") <> " and #{List.last(points)} are at"
          end

      assert_raise ArgumentError, Enum.join(lines, "\n"), fn ->
        Logex.IO.bind!(many(40), Map.new(keys, &{&1, Plain}))
      end
    end

    test "among more than 32 devices the nearest is suggested, the first in name order " <>
           "where several are as near" do
      # `d0` is as near to each of `d00` to `d09`, and nearer than any other.
      config = many(40, &"d#{String.pad_leading(Integer.to_string(&1 - 1), 2, "0")}")
      io = Map.new(0..39, &{"d#{String.pad_leading(Integer.to_string(&1), 2, "0")}", Plain})

      assert_raise ArgumentError,
                   "the device `d0` is bound, but no point is at it — did you mean `d00`?",
                   fn -> Logex.IO.bind!(config, Map.put(io, "d0", Sim)) end
    end

    test "a device bound that no point is at is told the nearest device, a case twin among " <>
           "them, or none" do
      config = configured("var_global lamp bool at panel.q.0\nprogram m blink\n  m.lamp lamp\n")

      for {name, hint} <- [
            {"panle", " — did you mean `panel`?"},
            {"Panel", " — did you mean `panel`? (devices are case-sensitive)"},
            {"drive", ""}
          ] do
        assert_raise ArgumentError,
                     "the device `#{name}` is bound, but no point is at it#{hint}",
                     fn -> Logex.IO.bind!(config, %{"panel" => Plain, name => Plain}) end
      end
    end

    test "an adapter's check/3 is given what init/3 will be, in the host's process, and " <>
           "each line it gives is one of the one ArgumentError" do
      config = configured("var_global lamp bool at panel.q.0\nprogram m blink\n  m.lamp lamp\n")
      [lamp] = Logex.IO.points(config)["panel"]
      test = self()

      assert Logex.IO.bind!(config, %{"panel" => {Checked, test: test}}) ==
               [{"panel", Checked, [test: test], [lamp]}]

      assert_received {:checked, ^test, "panel", [^lamp], [test: ^test]}

      assert_raise ArgumentError,
                   "the device `panel`'s adapter options: no host 10.0.0.5 is configured\n" <>
                     "the device `panel`'s adapter options: unit: is 1 to 247, got: 300",
                   fn ->
                     Logex.IO.bind!(config, %{
                       "panel" =>
                         {Checked,
                          test: test,
                          gives: ["no host 10.0.0.5 is configured", "unit: is 1 to 247, got: 300"]}
                     })
                   end

      for gives <- [:ok, ["fine", :nope], ["a" | "b"]] do
        assert_raise ArgumentError,
                     "the device `panel` is bound to `Logex.IOTest.Checked`, whose check/3 " <>
                       "gives a list of messages, got: #{inspect(gives)}",
                     fn ->
                       Logex.IO.bind!(config, %{"panel" => {Checked, test: test, gives: gives}})
                     end
      end
    end

    test "an adapter's check/3 is not called where its options are no keyword list or its " <>
           "module lacks a callback, and its lines come in device-name order among the rest" do
      config =
        configured("""
        var_global lamp bool at panel.q.0
        var_global horn bool at drive.q.0
        program m blink
          m.lamp lamp
        """)

      test = self()

      assert_raise ArgumentError,
                   "the device `drive`'s adapter options: drive's\n" <>
                     "the device `panel` is bound to `Logex.IOTest.HalfChecked`, which does not " <>
                     "implement Logex.IO: it has no write/2\n" <>
                     "the device `pnael` is bound, but no point is at it — did you mean `panel`?",
                   fn ->
                     Logex.IO.bind!(
                       config,
                       opaque(%{
                         "panel" => {HalfChecked, test: test},
                         "drive" => {Checked, test: test, gives: ["drive's"]},
                         "pnael" => {Checked, test: test, gives: ["never asked"]}
                       })
                     )
                   end

      assert_received {:checked, ^test, "drive", _points, _opts}
      refute_received {:checked, _pid, _device, _points, _opts}

      assert_raise ArgumentError,
                   "the device `panel`'s adapter options are a keyword list, got: [1]",
                   fn ->
                     Logex.IO.bind!(
                       config,
                       opaque(%{"panel" => {Checked, [1]}, "drive" => {Checked, test: test}})
                     )
                   end

      assert_received {:checked, ^test, "drive", _points, _opts}
      refute_received {:checked, _pid, _device, _points, _opts}
    end

    test "an adapter not yet loaded is loaded to be checked", %{tmp_dir: dir} do
      # A module compiled to a file beside the code path, and not loaded, as an adapter of a
      # host's application may be until something calls it.
      [{module, binary}] =
        Code.compile_string("""
        defmodule Logex.IOTest.NotYetLoaded do
          def init(_device, _points, _opts), do: {:ok, nil}
          def read(state), do: {:ok, %{}, state}
          def write(_values, state), do: {:ok, state}
        end
        """)

      :code.delete(module)
      :code.purge(module)
      File.write!(Path.join(dir, "#{module}.beam"), binary)
      Code.prepend_path(dir)
      on_exit(fn -> Code.delete_path(dir) end)
      refute :code.is_loaded(module)

      config = configured("var_global lamp bool at panel.q.0\nprogram m blink\n  m.lamp lamp\n")

      assert [{"panel", ^module, [], [%Point{name: "lamp"}]}] =
               Logex.IO.bind!(config, %{"panel" => module})
    end

    test "an adapter is a module that implements Logex.IO, alone or with a keyword list of " <>
           "options" do
      config = configured("var_global lamp bool at panel.q.0\nprogram m blink\n  m.lamp lamp\n")

      for {binding, message} <- [
            {{Sim, :fast}, "the device `panel`'s adapter options are a keyword list, got: :fast"},
            {{Sim, [1]}, "the device `panel`'s adapter options are a keyword list, got: [1]"},
            {Nope.Adapter, "the device `panel` is bound to `Nope.Adapter`, which is no module"},
            {Enum,
             "the device `panel` is bound to `Enum`, which does not implement Logex.IO: it " <>
               "has no init/3, read/1 or write/2"},
            {{HalfAdapter, []},
             "the device `panel` is bound to `Logex.IOTest.HalfAdapter`, which does not " <>
               "implement Logex.IO: it has no write/2"},
            {"Logex.IO.Sim",
             "the device `panel` is bound to \"Logex.IO.Sim\": an adapter is a module that " <>
               "implements Logex.IO, or {module, options}"},
            {{"Sim", []},
             "the device `panel` is bound to {\"Sim\", []}: an adapter is a module that " <>
               "implements Logex.IO, or {module, options}"}
          ] do
        assert_raise ArgumentError, message, fn ->
          Logex.IO.bind!(config, %{"panel" => opaque(binding)})
        end
      end

      assert_raise ArgumentError,
                   "the device `panel`'s adapter options are a keyword list, got: :fast\n" <>
                     "the device `panel` is bound to `Nope.Adapter`, which is no module",
                   fn -> Logex.IO.bind!(config, %{"panel" => opaque({Nope.Adapter, :fast})}) end

      for io <- [[panel: Sim], MapSet.new()] do
        assert_raise ArgumentError,
                     "io binds each device by its name to its adapter, a map such as " <>
                       "%{\"panel\" => MyApp.PanelIO}, got: #{inspect(io)}",
                     fn -> Logex.IO.bind!(config, opaque(io)) end
      end

      assert_raise ArgumentError, "io names each device by a string, got: 1", fn ->
        Logex.IO.bind!(config, opaque(%{1 => Plain, "panel" => Plain}))
      end
    end
  end

  describe "the bindings' growth" do
    # bind!/2's reductions, in a process of its own, the least of three counts.
    defp bound(devices) do
      config = many(devices)
      io = Map.new(1..devices, &{"dev#{&1}", Plain})

      for _ <- 1..3, reduce: :infinity do
        least ->
          task =
            Task.async(fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              Logex.IO.bind!(config, io)
              {:reductions, after_} = Process.info(self(), :reductions)
              after_ - before
            end)

          min(least, Task.await(task, :infinity))
      end
    end

    test "checking a host's bindings stays linear in the devices and their points" do
      ratio = bound(800) / bound(50)
      assert ratio < 20, "16x the devices took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
