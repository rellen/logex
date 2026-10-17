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

    def start(opts, slow \\ nil), do: GenServer.start(__MODULE__, {opts, slow})
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

  describe "Logex.IO, the behaviour" do
    test "is five callbacks, report/2 and close/1 optional" do
      assert Enum.sort(Logex.IO.behaviour_info(:callbacks)) ==
               [close: 1, init: 3, read: 1, report: 2, write: 2]

      assert Enum.sort(Logex.IO.behaviour_info(:optional_callbacks)) == [close: 1, report: 2]
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

    test "set/3 returns only once the device has handled the report, however long it takes" do
      sim = sim(reports: true)
      # The device takes 30 ms of real time over each report, and then tells the test.
      device([sim: sim], {self(), 30})

      Sim.set(sim, [0], 1)
      assert_received {:handled, %{[0] => 1}}
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

    test "a device that is down is passed over by set/3" do
      sim = sim(reports: true)
      pid = device(sim: sim)
      GenServer.stop(pid)
      assert Sim.set(sim, [0], 1) == :ok
      assert {:ok, values, _state} = Sim.read(opened(sim))
      assert values == %{[0] => 1, [1] => 0, [2, 1] => 0}
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
             "Logex.IO.Sim's wait: is a whole number of milliseconds, 1 or more, got: 0"}
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
end
