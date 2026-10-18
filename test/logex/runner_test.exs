defmodule Logex.RunnerTest do
  @moduledoc """
  M4-3: the wall-clock runner, `Logex.Runner` (`docs/organisation.md` §4.11), every rule on
  the manual clock with simulated devices, so that a run repeats exactly from fresh
  processes: its start and every host mistake of §4.11 with its pinned message, raised in
  the caller with the runner still alive. PLAN.md M4-3's Done-when, from files on disk, is
  in `end_to_end_test.exs`.
  """
  use ExUnit.Case, async: true

  alias Logex.Configuration
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  # A device whose every write takes `ms` on the manual clock, as a slow drive's does, and
  # which has nothing to read: so a round that writes it fills its milliseconds.
  defmodule SlowIO do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Map.new(opts)}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, %{clock: clock, ms: ms} = state) do
      Manual.pass(clock, ms)
      {:ok, state}
    end
  end

  # A device that logs each write and its close to an agent, in the order they come: so
  # that the order between devices can be asserted. `fail: true` refuses to open.
  defmodule LogIO do
    @behaviour Logex.IO

    @impl true
    def init(device, _points, opts), do: opened(Keyword.get(opts, :fail, false), device, opts)

    defp opened(true, _device, _opts), do: {:error, :refused}
    defp opened(false, device, opts), do: {:ok, %{log: opts[:log], device: device}}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(values, %{log: log} = state) do
      Agent.update(log, &[{:write, state.device, values} | &1])
      {:ok, state}
    end

    @impl true
    def close(%{log: log, device: device}), do: Agent.update(log, &[{:close, device} | &1])
  end

  # A clock whose every reading takes a millisecond, the manual clock's: so that the
  # runner's own work, a host's request among it, takes time, as on a real machine.
  defmodule TickClock do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock) do
      Manual.pass(clock, 1)
      Manual.now_ms(clock)
    end

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(clock, timer), do: Manual.cancel(clock, timer)
  end

  # A clock whose cancel/2 stops nothing, as a real clock's cannot stop a message already
  # sent: every wake the runner set comes, the ones it superseded among them.
  defmodule NoCancelClock do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms(clock), do: Manual.now_ms(clock)

    @impl true
    def wake_at(clock, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel(_clock, _timer), do: :ok
  end

  # A name for GenServer's `{:via, module, name}`, whose registration, made in the new
  # runner's own process before its init/1 runs, sends the runner the messages it is given:
  # so that a host's call or stop is in the runner's mailbox before anything else is.
  defmodule Early do
    import Kernel, except: [send: 2]

    def register_name({key, messages}, pid) do
      Enum.each(messages, &Kernel.send(pid, &1))
      :global.register_name(key, pid)
    end

    def unregister_name({key, _messages}), do: :global.unregister_name(key)
    def whereis_name({key, _messages}), do: :global.whereis_name(key)
    def send({key, _messages}, message), do: :global.send(key, message)
  end

  # The growth tests' bounds, each a fifth above the highest of 32 runs (see "growth").
  @both_bound 4.33
  @instances_bound 4.24
  @devices_bound 1.28

  # One var_input copied to one var_output.
  @relay "var_input in bool\nvar_output out bool\nxic in ote out"

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  # A relay on a 10 ms task, from the panel's one input to its one output.
  @relayed """
  task fast interval 10 priority 1

  var_global x bool at panel.i.0
  var_global y bool at panel.q.0

  program r relay with fast
    r.in  x
    r.out y
  """

  defp relayed do
    {:ok, config} =
      Configuration.compile("plant", @relayed, %{"relay" => program(@relay, "relay")})

    config
  end

  # A manual clock and a sim for the panel, and the options that run `config` on them.
  defp rig(config \\ relayed(), extra \\ []) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(reports: true, clock: clock)

    {[
       configuration: config,
       io: %{"panel" => {Sim, sim: panel}},
       clock: {Manual, clock}
     ] ++ extra, %{clock: clock, panel: panel}}
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # The relay on the 10 ms task, and an event task on the panel's `e` counting its rises
  # into `hits`, the drive's one output: a trigger at a device that reports.
  @counted """
  task fast interval 10 priority 1
  task trip single e priority 0

  var_global x    bool at panel.i.0
  var_global e    bool at panel.i.1
  var_global y    bool at panel.q.0
  var_global hits dint at drive.q.0

  program r relay with fast
    r.in  x
    r.out y

  program c count with trip
    c.n hits
  """

  defp counted(text \\ @counted) do
    programs = %{
      "relay" => program(@relay, "relay"),
      "count" => program("var_output n dint\nadd n 1 n", "count")
    }

    {:ok, config} = Configuration.compile("plant", text, programs)
    config
  end

  # The panel that reports and the drive that does not, on one manual clock.
  defp plant_rig(config \\ counted(), extra \\ []) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(reports: true, clock: clock)
    {:ok, drive} = Sim.start_link(clock: clock)

    {[
       configuration: config,
       io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
       clock: {Manual, clock}
     ] ++ extra, %{clock: clock, panel: panel, drive: drive}}
  end

  # The runner's device processes, by name, from its state: the refreshes they are sent
  # are internal, and these tests trace them.
  defp devices(runner),
    do: Map.new(:sys.get_state(runner).devices, fn {name, pid, _} -> {name, pid} end)

  # Every refresh a device was sent since it was traced, its deadline, in order: the
  # trace of a :sys call made last marks the end, so that none is missed, one that no
  # simulated device makes.
  defp refreshes(device) do
    :sys.get_status(device)
    collected(device, [])
  end

  defp collected(device, deadlines) do
    receive do
      {:trace, ^device, :receive, {:"$gen_cast", {:refresh, deadline}}} ->
        collected(device, [deadline | deadlines])

      {:trace, ^device, :receive, {:system, _from, :get_status}} ->
        Enum.reverse(deadlines)

      {:trace, ^device, :receive, _other} ->
        collected(device, deadlines)
    end
  end

  describe "start_link/1's host mistakes, each raised in the caller before anything starts" do
    test "options that are no keyword list" do
      for opts <- [:x, [1], %{configuration: nil}] do
        raises(
          "Logex.Runner.start_link/1 takes a keyword list of options, configuration:, io:, " <>
            "clock:, poll:, overhead:, idle: and name:, got: #{inspect(opts)}",
          fn -> Runner.start_link(opts) end
        )
      end
    end

    test "an unknown option, the first named" do
      {opts, _rig} = rig()

      raises(
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle: and name:, " <>
          "got: :pole",
        fn -> Runner.start_link(opts ++ [pole: 10, period: 5]) end
      )
    end

    test "an option given more than once, the first repeated named" do
      {opts, _rig} = rig()

      raises("Logex.Runner takes each option once, got :name more than once", fn ->
        Runner.start_link(opts ++ [poll: 5, name: :a1, name: :a2, poll: 6])
      end)

      raises("Logex.Runner takes each option once, got :poll more than once", fn ->
        Runner.start_link(opts ++ [poll: 5, poll: 5, poll: 5])
      end)

      # An unknown key repeated is told as unknown.
      raises(
        "Logex.Runner takes configuration:, io:, clock:, poll:, overhead:, idle: and name:, " <>
          "got: :pole",
        fn -> Runner.start_link(opts ++ [pole: 1, pole: 2]) end
      )
    end

    test "a missing configuration: or io:" do
      {opts, _rig} = rig()

      raises(
        "Logex.Runner needs configuration:, the %Logex.Configuration{} it runs",
        fn -> Runner.start_link(Keyword.delete(opts, :configuration)) end
      )

      raises(
        "Logex.Runner needs io:, each device its points are at bound by name to its adapter, " <>
          "%{} for a configuration with no point",
        fn -> Runner.start_link(Keyword.delete(opts, :io)) end
      )
    end

    test "a configuration Logex.Runtime.start/1 refuses, in its words" do
      {opts, _rig} = rig()

      raises(
        "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: :plant",
        fn -> Runner.start_link(Keyword.put(opts, :configuration, :plant)) end
      )

      broken = %{relayed() | tasks: [%Configuration.Task{name: "fast", priority: 1}]}
      message = Exception.message(catch_error(Logex.Runtime.start(broken)))
      raises(message, fn -> Runner.start_link(Keyword.put(opts, :configuration, broken)) end)
    end

    test "bindings Logex.IO.bind!/2 refuses, in its words" do
      {opts, %{panel: panel}} = rig()
      io = %{"panel" => {Sim, sim: panel}, "panle" => {Sim, sim: panel}}
      message = Exception.message(catch_error(Logex.IO.bind!(relayed(), io)))

      assert message =~ "the device `panle` is bound, but no point is at it"
      raises(message, fn -> Runner.start_link(Keyword.put(opts, :io, io)) end)

      raises(
        "no adapter is bound to the device `panel`, which `x` (panel.i.0) and `y` " <>
          "(panel.q.0) are at",
        fn -> Runner.start_link(Keyword.put(opts, :io, %{})) end
      )
    end

    test "a clock that is no {module, clock} implementing Logex.Runner.Clock" do
      {opts, _rig} = rig()

      for clock <- [Manual, {"Manual", nil}, nil] do
        raises(
          "the runner's clock: is {module, clock}, a module that implements " <>
            "Logex.Runner.Clock and the clock its callbacks take, got: #{inspect(clock)}",
          fn -> Runner.start_link(Keyword.put(opts, :clock, clock)) end
        )
      end

      raises("the runner's clock `NoSuchClock` is no module", fn ->
        Runner.start_link(Keyword.put(opts, :clock, {NoSuchClock, nil}))
      end)

      raises(
        "the runner's clock `Logex.IO.Sim` does not implement Logex.Runner.Clock: it has no " <>
          "now_ms/1, wake_at/4, cancel/2",
        fn -> Runner.start_link(Keyword.put(opts, :clock, {Sim, nil})) end
      )

      # The clock's own term, checked by the clock in its own words.
      raises(
        "expected a manual clock from Logex.Runner.Clock.Manual.start_link/1, got: :clock",
        fn -> Runner.start_link(Keyword.put(opts, :clock, {Manual, :clock})) end
      )
    end

    test "a poll period, a share or an idle watchdog out of its range" do
      {opts, _rig} = rig()

      for key <- [:poll, :idle], value <- [0, -1, 2_147_483_648, 1.5, "10", nil] do
        raises(
          "the runner's #{key}: is a whole number of milliseconds, 1 to 2147483647, got: " <>
            inspect(value),
          fn -> Runner.start_link(Keyword.put(opts, key, value)) end
        )
      end

      for value <- [9, 91, 0, 100, 20.0, "20", nil] do
        raises(
          "the runner's overhead: is the share of the time kept for its own work, a whole " <>
            "number of percent from 10 to 90, got: #{inspect(value)}",
          fn -> Runner.start_link(Keyword.put(opts, :overhead, value)) end
        )
      end

      # Each end of each range is taken.
      for {key, value} <-
            [poll: 1, poll: 2_147_483_647, idle: 1, idle: 2_147_483_647] ++
              [overhead: 10, overhead: 90] do
        {opts, _rig} = rig()
        assert {:ok, _runner} = Runner.start_link(Keyword.put(opts, key, value))
      end
    end

    # The checks come in order: the list, each key, the two it needs, the configuration,
    # the clock, the poll period, the share, the idle watchdog, and then the bindings.
    test "in their order, the first mistake raised" do
      {opts, _rig} = rig()
      bad = [configuration: :plant, io: :io, clock: :c, poll: 0, overhead: 0, idle: 0]

      orders = [
        {[:configuration], "expected a %Logex.Configuration{}"},
        {[:clock], "the runner's clock: is"},
        {[:poll], "the runner's poll:"},
        {[:overhead], "the runner's overhead:"},
        {[:idle], "the runner's idle:"},
        {[:io], "io binds each device"}
      ]

      orders
      |> Enum.with_index()
      |> Enum.each(fn {{_keys, start}, index} ->
        # Every mistake from this one on, the earlier ones put right.
        wrong = orders |> Enum.drop(index) |> Enum.flat_map(&elem(&1, 0))
        opts = Enum.reduce(wrong, opts, &Keyword.put(&2, &1, bad[&1]))
        error = catch_error(Runner.start_link(opts))
        assert String.starts_with?(Exception.message(error), start), Exception.message(error)
      end)
    end

    test "a bad name, in GenServer's words, and a name taken" do
      {opts, _rig} = rig()
      assert_raise ArgumentError, fn -> Runner.start_link(opts ++ [name: "runner"]) end

      name = :"runner_#{System.unique_integer([:positive])}"
      assert {:ok, runner} = Runner.start_link(opts ++ [name: name])
      {opts, _rig} = rig()
      assert {:error, {:already_started, ^runner}} = Runner.start_link(opts ++ [name: name])
    end
  end

  test "its child spec starts it once: restart: :temporary (decision 115)" do
    {opts, _rig} = rig()

    assert %{id: Runner, start: {Runner, :start_link, [^opts]}, restart: :temporary} =
             Runner.child_spec(opts)
  end

  describe "a call's host mistakes, raised in the caller with the runner still alive" do
    setup do
      {opts, rig} = rig()
      {:ok, runner} = Runner.start_link(opts)
      Map.put(rig, :runner, runner)
    end

    test "get/2 of a path that names nothing gives its reason, get!/2 raises it", %{
      runner: runner
    } do
      # The resource's own reason, word for word, from a resource that knows nothing of
      # the runner.
      {:error, reason} = Logex.Runtime.get(Logex.Runtime.start(relayed()), "q")
      assert reason == "`q` is neither a global nor a program instance"
      assert Runner.get(runner, "q") == {:error, reason}
      raises(reason, fn -> Runner.get!(runner, "q") end)
      assert Process.alive?(runner)
      assert Runner.get(runner, "y") == {:ok, 0}
      assert Runner.get!(runner, "r.in") == 0
    end

    test "a path that is not a string, raised by both", %{runner: runner} do
      for get <- [&Runner.get/2, &Runner.get!/2] do
        raises(
          ":y is not an access path: a global, or a program instance, its tag and the " <>
            "members below it, joined by `.`, as in \"m1.t1.acc\"",
          fn -> get.(runner, :y) end
        )
      end

      assert Process.alive?(runner)
      assert Runner.get!(runner, "x") == 0
    end

    test "a runner that is none: no pid, another process, a process down, a name unused",
         %{runner: runner, clock: clock} do
      raises("expected a runner from Logex.Runner.start_link/1, got: 42", fn ->
        Runner.get(42, "y")
      end)

      raises(
        "expected a runner from Logex.Runner.start_link/1, got: #{inspect(clock)}, another " <>
          "process",
        fn -> Runner.get(clock, "y") end
      )

      down = spawn(fn -> :ok end)
      ref = Process.monitor(down)
      assert_receive {:DOWN, ^ref, :process, ^down, _}

      raises("the runner #{inspect(down)} is not running", fn -> Runner.get(down, "y") end)

      raises("no runner is running under the name :nobody_here", fn ->
        Runner.get(:nobody_here, "y")
      end)

      assert Process.alive?(runner)
    end
  end

  # The runner's mailbox, polled until it holds a message `held?` takes.
  defp holding(pid, held?) do
    {:messages, messages} = Process.info(pid, :messages)
    holding(Enum.any?(messages, held?), pid, held?)
  end

  defp holding(true, _pid, _held?), do: :ok

  defp holding(false, pid, held?) do
    Process.sleep(1)
    holding(pid, held?)
  end

  # The runner's queue of host requests, polled until it holds `n`.
  defp queued(runner, n), do: queued(:queue.len(:sys.get_state(runner).queue) == n, runner, n)

  defp queued(true, _runner, _n), do: :ok

  defp queued(false, runner, n) do
    Process.sleep(1)
    queued(runner, n)
  end

  defp call?({:"$gen_call", _from, _request}), do: true
  defp call?(_other), do: false

  # What a call raised, or what it gave.
  defp outcome(fun) do
    {:gave, fun.()}
  rescue
    error in ArgumentError -> {:raised, Exception.message(error)}
  catch
    kind, reason -> {kind, reason}
  end

  describe "what comes first, last, or from no host" do
    test "a call by its name that comes before its devices are open waits for them and " <>
           "its first round" do
      {opts, %{panel: panel}} = rig()
      Sim.set(panel, [0], 1)
      ref = make_ref()
      key = {__MODULE__, ref}
      name = {:via, Early, {key, [{:"$gen_call", {self(), ref}, :status}]}}

      assert {:ok, runner} = Runner.start_link(opts ++ [name: name])
      assert_receive {^ref, %{status: :running, rounds: 1}}
      assert Runner.get!(name, "y") == 1
      assert Process.alive?(runner)
    end

    # start_link/1 gives the runner, which stops once its first round has run, every
    # output 0 once and every device closed.
    test "a stop by its name that comes before its devices are open" do
      {opts, %{panel: panel}} = rig()
      Sim.set(panel, [0], 1)
      ref = make_ref()
      stop = {:system, {self(), ref}, {:terminate, :normal}}
      name = {:via, Early, {{__MODULE__, ref}, [stop]}}

      assert {:ok, runner} = Runner.start_link(opts ++ [name: name])
      assert_receive {^ref, :ok}

      # Gone normally, or already gone when the monitor was set.
      monitor = Process.monitor(runner)

      assert_receive {:DOWN, ^monitor, :process, ^runner, reason}
                     when reason in [:normal, :noproc]

      assert Sim.writes(panel) == [%{[0] => 1}, %{[0] => 0}]
      assert Sim.closed?(panel)
    end

    test "a request still waiting at a stop raises in its caller that the runner is not " <>
           "running, whatever the stop's reason" do
      config =
        configured("var_global x bool at panel.i.0\nprogram b count\n", %{
          "count" => "var_output n dint\nadd n 1 n"
        })

      for reason <- [:normal, :shutdown, :abandoned] do
        {opts, %{clock: clock, panel: panel}} = rig(config)
        {:ok, runner} = Runner.start_link(opts)
        Process.unlink(runner)

        # Time passed and no wake delivered: a round is owed, so the request waits.
        Manual.pass(clock, 5)
        waiting = Task.async(fn -> outcome(fn -> Runner.get(runner, "b.n") end) end)
        queued(runner, 1)

        ExUnit.CaptureLog.capture_log(fn -> Runner.stop(runner, reason) end)

        assert Task.await(waiting) == {:raised, "the runner #{inspect(runner)} is not running"}
        assert Sim.closed?(panel)
      end
    end

    test "a call that reaches the runner as it stops, unanswered, raises the same, " <>
           "whatever the stop's reason" do
      for reason <- [:normal, :shutdown, {:shutdown, :x}, :abandoned] do
        {opts, _rig} = rig()
        {:ok, runner} = Runner.start_link(opts)
        Process.unlink(runner)
        :sys.suspend(runner)
        waiting = Task.async(fn -> outcome(fn -> Runner.status(runner) end) end)
        holding(runner, &call?/1)
        ExUnit.CaptureLog.capture_log(fn -> Runner.stop(runner, reason) end)

        assert Task.await(waiting) == {:raised, "the runner #{inspect(runner)} is not running"},
               inspect(reason)
      end
    end

    # A call none of its functions makes, and a device's change from another process.
    test "a cast or a message is passed over, and a call it does not make is the caller's " <>
           "mistake" do
      {opts, %{panel: panel}} = rig()
      {:ok, runner} = Runner.start_link(opts)
      GenServer.cast(runner, :x)
      GenServer.cast(runner, {:changes, "panel", %{[0] => 1}})
      send(runner, {:changes, "panel", %{[0] => 1}})

      for request <- [:foo, :open, {:changes, "panel", %{[0] => 1}}, {:changes, :x, :y}] do
        assert {:raise, %ArgumentError{message: message}} = GenServer.call(runner, request)

        assert message ==
                 "Logex.Runner has no request #{inspect(request)}: a runner is called " <>
                   "through get/2, get!/2, status/1, subscribe/2, unsubscribe/1 and stop/2"
      end

      assert Process.alive?(runner)
      assert %{rounds: 1, status: :running} = Runner.status(runner)
      assert Runner.get!(runner, "x") == 0
      assert Sim.writes(panel) == [%{[0] => 0}]
    end

    # Starts and stops by one name while another process polls the runner by that name:
    # the starter is never taken down with the runner, and the poller is told each time
    # that the runner is running or that it is not.
    test "a host polling it by name across starts and stops takes neither it nor its " <>
           "starter down" do
      name = :"runner_#{System.unique_integer([:positive])}"
      poller = spawn_link(fn -> polling(name, MapSet.new()) end)

      for _ <- 1..100 do
        {opts, _rig} = rig()

        {starter, monitor} =
          spawn_monitor(fn ->
            {:ok, runner} = Runner.start_link(opts ++ [name: name])
            :ok = Runner.stop(runner)
          end)

        assert_receive {:DOWN, ^monitor, :process, ^starter, :normal}, 5_000
      end

      send(poller, {:report, self()})
      assert_receive {:polled, polled}, 5_000

      assert MapSet.subset?(
               polled,
               MapSet.new([
                 :running,
                 "no runner is running under the name #{inspect(name)}",
                 :gone
               ])
             ),
             inspect(polled)
    end
  end

  # A poller's outcomes, each a status that is running, the name unused, or the runner
  # gone as it was called.
  defp polling(name, polled) do
    receive do
      {:report, test} -> send(test, {:polled, polled})
    after
      0 -> polling(name, MapSet.put(polled, polled_once(outcome(fn -> Runner.status(name) end))))
    end
  end

  defp polled_once({:gave, %{status: :running}}), do: :running
  defp polled_once({:raised, "the runner " <> _not_running}), do: :gone
  defp polled_once({:raised, message}), do: message
  defp polled_once(other), do: other

  describe "the devices (decisions 120, 124 and 125)" do
    test "each opened in device-name order and read once at start, and the first round " <>
           "run at once, every device with an output written" do
      {opts, %{panel: panel, drive: drive}} = plant_rig()
      Sim.set(panel, %{[0] => 1})
      assert {:ok, runner} = Runner.start_link(opts)

      # The relay, due at 0, saw `x` at 1 in the first round, before the clock moved.
      assert {Sim.reads(panel), Sim.reads(drive)} == {1, 1}
      assert Sim.writes(panel) == [%{[0] => 1}]
      assert Sim.writes(drive) == [%{[0] => 0}]
      assert Runner.get!(runner, "r.out") == 1
    end

    test "a device that cannot be opened is {:error, {:io_init, device, reason}}, every " <>
           "device opened before it closed and zeroed, and the runner gone" do
      {opts, %{panel: panel, drive: drive}} = plant_rig()
      Sim.fail(panel, :init, {:error, :unplugged})
      Process.flag(:trap_exit, true)
      name = :"runner_#{System.unique_integer([:positive])}"

      # The runner's normal exit is start_link/1's to take: no exit signal reaches the
      # caller, and its name is free again.
      assert Runner.start_link(opts ++ [name: name]) ==
               {:error, {:io_init, "panel", :unplugged}}

      assert GenServer.whereis(name) == nil
      refute_received {:EXIT, _runner, _reason}

      # `drive` comes first, so it was opened, and is closed again, its output zeroed once.
      assert Sim.closed?(drive)
      assert Sim.writes(drive) == [%{[0] => 0}]
      assert Sim.writes(panel) == []

      # The first fails, and none after it is opened.
      {opts, %{panel: panel, drive: drive}} = plant_rig()
      Sim.fail(drive, :init, {:error, :no_route})
      assert Runner.start_link(opts) == {:error, {:io_init, "drive", :no_route}}
      assert {Sim.reads(panel), Sim.reads(drive)} == {0, 0}
      refute Sim.closed?(panel)
    end

    test "each read every poll period from its opening, on a grid, 10 ms unless set" do
      for {extra, reads} <- [{[], 4}, {[poll: 5], 7}, {[poll: 7], 5}] do
        {opts, %{clock: clock, panel: panel, drive: drive}} = plant_rig(counted(), extra)
        {:ok, _runner} = Runner.start_link(opts)
        Manual.advance(clock, 30)
        assert {Sim.reads(panel), Sim.reads(drive)} == {reads, reads}, inspect(extra)
      end
    end

    test "a change a device that does not report reads is passed on at its next poll, " <>
           "a trigger's making its round then" do
      # No periodic task, so that every round is a trigger's.
      text =
        @counted
        |> String.replace("task fast interval 10 priority 1\n", "")
        |> String.replace("program r relay with fast", "program r relay with trip")

      {opts, %{clock: clock}} = plant_rig(counted(text))
      {:ok, quiet} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(Keyword.put(opts, :io, %{opts[:io] | "panel" => {Sim, sim: quiet}}))

      Sim.set(quiet, [1], 1)
      Manual.advance(clock, 9)
      assert Runner.get!(runner, "hits") == 0
      Manual.advance(clock, 1)
      assert Runner.get!(runner, "hits") == 1

      # Read again at each poll, it has not changed, and makes no round.
      rounds = :sys.get_state(runner).rounds
      Manual.advance(clock, 20)
      assert Runner.get!(runner, "hits") == 1
      assert :sys.get_state(runner).rounds == rounds
    end

    test "a device with no output point is never written, nor zeroed" do
      text =
        @counted
        |> String.replace("var_global e    bool at panel.i.1", "var_global e    bool at keys.i.0")

      {opts, %{clock: clock}} = plant_rig(counted(text))
      {:ok, keys} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(Keyword.update!(opts, :io, &Map.put(&1, "keys", {Sim, sim: keys})))

      Sim.set(keys, [0], 1)
      assert Runner.get!(runner, "hits") == 1
      assert Sim.reads(keys) == 1
      assert Sim.writes(keys) == []

      # Closed when a device after it cannot be opened, it is written nothing then either.
      {opts, %{clock: clock, panel: panel}} = plant_rig(counted(text))
      {:ok, keys} = Sim.start_link(clock: clock)
      Sim.fail(panel, :init, {:error, :unplugged})
      io = Map.put(opts[:io], "keys", {Sim, sim: keys})

      assert {:error, {:io_init, "panel", :unplugged}} =
               Runner.start_link(Keyword.put(opts, :io, io))

      assert Sim.closed?(keys)
      assert Sim.writes(keys) == []
    end

    test "a round passes the time since the last, on the runner's clock" do
      text =
        @counted
        |> String.replace(
          "program c count with trip\n  c.n hits",
          "program c clocked with trip\n  c.n hits"
        )

      programs = %{
        "relay" => program(@relay, "relay"),
        "clocked" =>
          program("var_output n dint\nvar t ton\nxio t.dn ton t 100000\nadd t.acc 0 n", "clocked")
      }

      {:ok, config} = Configuration.compile("plant", text, programs)
      {opts, %{clock: clock, panel: panel}} = plant_rig(config)
      {:ok, runner} = Runner.start_link(opts)

      # The timer starts at the rise at 2, and reads 5 ms at the rise at 7.
      Manual.pass(clock, 2)
      Sim.set(panel, [1], 1)
      Sim.set(panel, [1], 0)
      Manual.pass(clock, 5)
      Sim.set(panel, [1], 1)
      assert Runner.get!(runner, "hits") == 5
    end

    test "a change of an event task's trigger makes a round at once, each its own, and " <>
           "set/3 returns once it has run and its outputs are written" do
      {opts, %{panel: panel, drive: drive}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)

      Sim.set(panel, [1], 1)
      assert Runner.get!(runner, "hits") == 1
      assert Sim.outputs(drive) == %{[0] => 1}

      # A fall is a change too, its own round, which runs no event task; and the next rise
      # another.
      Sim.set(panel, [1], 0)
      Sim.set(panel, [1], 1)
      assert Runner.get!(runner, "hits") == 2
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 1}, %{[0] => 2}]
    end

    test "a change of another input is merged, makes no round, and the next round takes " <>
           "it, with the trigger's own change" do
      {opts, %{panel: panel}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)

      Sim.set(panel, [0], 1)
      assert Runner.get!(runner, "x") == 0
      assert Sim.writes(panel) == [%{[0] => 0}]

      # The trigger's round takes `x` too, and the relay, not due at 0 once it has run,
      # leaves `y` as it was.
      Sim.set(panel, %{[1] => 1})
      assert Runner.get!(runner, "x") == 1
      assert Runner.get!(runner, "hits") == 1

      # One report with both: `x`'s change is merged before the trigger's round, which
      # takes it.
      Sim.set(panel, %{[0] => 0, [1] => 0})
      assert Runner.get!(runner, "x") == 0
    end

    test "each change of a trigger in one report its own round, in address order" do
      text =
        @counted
        |> String.replace(
          "task trip single e priority 0",
          "task trip single e priority 1\ntask two single f priority 0"
        )
        |> String.replace(
          "var_global e    bool at panel.i.1",
          "var_global e    bool at panel.i.1\nvar_global f    bool at panel.i.2\nvar_global seen dint"
        )
        |> Kernel.<>("\nprogram d copy with two\n  d.a hits\n  d.b seen\n")

      programs = %{
        "relay" => program(@relay, "relay"),
        "count" => program("var_output n dint\nadd n 1 n", "count"),
        "copy" => program("var_input a dint\nvar_output b dint\nadd a 0 b", "copy")
      }

      {:ok, config} = Configuration.compile("plant", text, programs)
      {opts, %{panel: panel, drive: drive}} = plant_rig(config)
      {:ok, runner} = Runner.start_link(opts)

      # Both rise in one report: `e`'s round first, at [1], counting 1, and then `f`'s, at
      # [2], which copies the count it finds; in one round `two`, of the higher priority,
      # would copy it before `trip` counted.
      Sim.set(panel, %{[2] => 1, [1] => 1})
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 1}]
      assert {Runner.get!(runner, "hits"), Runner.get!(runner, "seen")} == {1, 1}
    end

    test "a device written only where its outputs changed, waited for, and answering the " <>
           "runner's write while it waits on its own change" do
      text =
        String.replace(
          @counted,
          "program r relay with fast\n  r.in  x",
          "program r relay with trip\n  r.in  e"
        )

      {opts, %{panel: panel}} = plant_rig(counted(text))
      {:ok, _runner} = Runner.start_link(opts)
      assert Sim.writes(panel) == [%{[0] => 0}]

      # The panel's own change makes a round that writes the panel, which answers the write
      # while it waits for that round: `y` follows `e`.
      Sim.set(panel, [1], 1)
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 1}]

      # A fall runs no event task, so `y` stays 1, and the panel is not written again.
      Sim.set(panel, [1], 0)
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 1}]
    end

    test "every device refreshed before each step with its deadline, its task's watchdog " <>
           "and a poll period from the step's start, and before the write with the idle " <>
           "watchdog's" do
      text =
        String.replace(
          @counted,
          "task trip single e priority 0",
          "task trip single e priority 0 watchdog 40"
        )

      {opts, %{clock: clock, panel: panel}} = plant_rig(counted(text), poll: 7, idle: 300)
      {:ok, runner} = Runner.start_link(opts)
      %{"panel" => panel_device, "drive" => drive_device} = devices(runner)
      for device <- [panel_device, drive_device], do: :erlang.trace(device, true, [:receive])

      # A rise of `e` at 2: the event task's step, 40 and 7 on, and the write's, 300 and 7.
      Manual.pass(clock, 2)
      Sim.set(panel, [1], 1)
      assert refreshes(panel_device) == [2 + 47, 2 + 307]
      assert refreshes(drive_device) == [2 + 47, 2 + 307]

      # A fall runs no step: the write's alone.
      Manual.pass(clock, 3)
      Sim.set(panel, [1], 0)
      assert refreshes(drive_device) == [5 + 307]

      # A watchdog left unset is 500 ms, and the idle watchdog 500 ms and the poll period
      # 10 ms unless set.
      {opts, %{clock: clock, panel: panel}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)
      %{"drive" => drive_device} = devices(runner)
      :erlang.trace(drive_device, true, [:receive])
      Manual.pass(clock, 2)
      Sim.set(panel, [1], 1)
      assert refreshes(drive_device) == [2 + 510, 2 + 510]
    end
  end

  # The runner's count of the rounds it has run, from its state: `status/1` is step 5's.
  defp rounds(runner), do: :sys.get_state(runner).rounds

  # A counter of its own runs, `n`, and an output that changes at every run, `q`.
  @count "var_output n dint\nadd n 1 n"
  @toggle "var_output q bool\nxio q ote q"

  defp configured(text, programs) do
    {:ok, config} =
      Configuration.compile(
        "plant",
        text,
        Map.new(programs, fn {name, source} -> {name, program(source, name)} end)
      )

    config
  end

  # A request's answer, the clock moved one wake at a time until it comes.
  defp waited(request, clock),
    do: answer(:gen_server.wait_response(request, 0), request, clock)

  defp answer({:reply, value}, _request, _clock), do: value

  defp answer(:timeout, request, clock) do
    Manual.advance(clock, 0)
    waited(request, clock)
  end

  # How many of the requests each slot served, one wake at a time, until all are.
  defp slotted([], _clock, slots), do: Enum.reverse(slots)

  defp slotted(requests, clock, slots) do
    Manual.advance(clock, 0)
    left = Enum.filter(requests, &(:gen_server.wait_response(&1, 0) == :timeout))
    slotted(left, clock, record(length(requests) - length(left), slots))
  end

  defp record(0, slots), do: slots
  defp record(served, slots), do: [served | slots]

  describe "the rounds (decisions 108, 122 and 123)" do
    test "while untimed programs exist, one round each clock millisecond, advance(n) " <>
           "running n, the first at once" do
      config =
        configured(
          "task main continuous\nvar_global x bool at panel.i.0\nprogram b count\n",
          %{"count" => @count}
        )

      {opts, %{clock: clock}} = rig(config)
      {:ok, runner} = Runner.start_link(opts)
      assert Runner.get!(runner, "b.n") == 1

      for n <- [1, 10, 37, 0, 252] do
        before = Runner.get!(runner, "b.n")
        Manual.advance(clock, n)
        assert Runner.get!(runner, "b.n") == before + n
      end
    end

    test "a round that takes a millisecond or more is followed at once, a wake on the clock" do
      config =
        configured(
          "var_global q bool at slow.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 3}},
          clock: {Manual, clock}
        )

      # The first round took 3 ms, so the next is due at once, at 3, and runs at the next
      # advance, however short: each round from then on starts where the last ended.
      assert {rounds(runner), Manual.now_ms(clock)} == {1, 3}
      Manual.advance(clock, 0)
      assert {rounds(runner), Manual.now_ms(clock)} == {2, 6}
      Manual.advance(clock, 6)
      assert {rounds(runner), Manual.now_ms(clock)} == {5, 15}

      # Each at once, at the time the last ended: no wake was late, and one is pending.
      assert :sys.get_state(runner).latest_wake == 0
      assert [{15, ^runner, _wake}, {_poll, _device, _}] = Manual.pending(clock)

      # A round is owed, at 15, so a host's call would wait for the share's slot, which
      # the next advance brings: the count is read from the runner's state.
      assert Logex.Runtime.get!(:sys.get_state(runner).runtime, "b.n") == 5
    end

    test "with no untimed program, a round only at a due time or a trigger's change" do
      text = String.replace(@counted, "program c count with trip", "program c count with trip\n")
      {opts, %{clock: clock, panel: panel}} = plant_rig(counted(text))
      {:ok, runner} = Runner.start_link(opts)

      # At 0, 10, 20 and 30: the relay's due times.
      Manual.advance(clock, 35)
      assert rounds(runner) == 4

      # A press and release between two due times: two rounds at once, `trip` run once,
      # each planning the next round again, its earlier wake cancelled.
      Sim.set(panel, [1], 1)
      assert {rounds(runner), Runner.get!(runner, "hits")} == {5, 1}
      assert [{40, ^runner, _}] = Enum.filter(Manual.pending(clock), &(elem(&1, 1) == runner))
      Sim.set(panel, [1], 0)
      assert {rounds(runner), Runner.get!(runner, "hits")} == {6, 1}

      # And the due times go on as before, on their grid.
      Manual.advance(clock, 5)
      assert rounds(runner) == 7
      Manual.advance(clock, 9)
      assert rounds(runner) == 7
      Manual.advance(clock, 1)
      assert rounds(runner) == 8
    end

    # A wake the runner superseded, which a real clock may deliver all the same, is stale by
    # its token and does nothing: the runs, rounds and refreshes are those of a clock that
    # cancels it.
    test "a superseded wake that comes all the same changes nothing" do
      [cancelled, delivered] =
        for module <- [Manual, NoCancelClock] do
          {opts, %{clock: clock, panel: panel}} = plant_rig(counted(), poll: 50)
          {:ok, runner} = Runner.start_link(Keyword.put(opts, :clock, {module, clock}))
          %{"drive" => drive} = devices(runner)
          :erlang.trace(drive, true, [:receive])

          Manual.advance(clock, 13)
          Sim.set(panel, [1], 1)
          Sim.set(panel, [1], 0)
          Manual.advance(clock, 30)
          {rounds(runner), Runner.get!(runner, "hits"), refreshes(drive)}
        end

      assert delivered == cancelled
      assert {7, 1, _refreshes} = delivered
    end

    test "a trigger logic writes makes its round at the next clock millisecond: two event " <>
           "tasks that write each other's trigger round once a millisecond, a call served " <>
           "between" do
      text = """
      task a single ga priority 0
      task b single gb priority 0

      var_global ga bool 1
      var_global gb bool
      var_global x  bool at panel.i.0

      program pa flip_a with a
      program pb flip_b with b
      """

      config =
        configured(text, %{
          "flip_a" => "var_external ga bool\nvar_external gb bool\nmove 1 gb\nmove 0 ga",
          "flip_b" => "var_external ga bool\nvar_external gb bool\nmove 1 ga\nmove 0 gb"
        })

      {opts, %{clock: clock}} = rig(config)
      {:ok, runner} = Runner.start_link(opts)

      # `ga` starts at 1, so `a` runs in the first round, which sets `gb`: `b` runs at 1,
      # setting `ga` again, `a` at 2, and so on, a call served at each.
      assert {rounds(runner), Runner.get!(runner, "gb")} == {1, 1}

      for ms <- 1..6 do
        Manual.advance(clock, 1)
        assert rounds(runner) == 1 + ms
        assert Runner.get!(runner, "ga") == rem(ms, 2)
      end

      Manual.advance(clock, 100)
      assert rounds(runner) == 107
    end

    # Each round writes the slow device, which takes 1 ms, so rounds fill their
    # milliseconds and a host's request waits for a slot. A request sent once the runner
    # has run r rounds is served after C x (floor(r / C) + 1): the slot comes at the end of
    # the round that completes every C ms of rounds, the first counted from start (decision
    # 122), so one sent just after a slot waits for the next (decision 131). The request is sent with
    # :gen_server.send_request/2, the runner's own request for get!/2, so that the test can
    # move the clock while it waits.
    test "the share's slots: after C ms of rounds that fill their milliseconds the runner " <>
           "serves the requests that waited, at 10%, 20%, 50% and 90%" do
      config =
        configured(
          "var_global q bool at slow.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      # 15% and 40% round C, 5.67 to 6 and 1.5 to 2.
      for {share, c} <- [{10, 9}, {15, 6}, {20, 4}, {40, 2}, {50, 1}, {90, 1}] do
        {:ok, clock} = Manual.start_link()

        {:ok, runner} =
          Runner.start_link(
            configuration: config,
            io: %{"slow" => {SlowIO, clock: clock, ms: 1}},
            clock: {Manual, clock},
            overhead: share
          )

        for gap <- [0, 3, 1, 8, 2, 13, 0, 5] do
          Enum.each(1..gap//1, fn _ -> Manual.advance(clock, 0) end)
          r = rounds(runner)
          request = :gen_server.send_request(runner, {:get!, "b.n"})
          served = waited(request, clock)
          assert served == c * (div(r, c) + 1), "#{share}%: sent after #{r} rounds"
        end
      end
    end

    # A slot serves its requests for up to S ms, each whole, its first whatever the time:
    # on a clock whose every reading takes a millisecond, each request served takes the
    # one reading made after it, so a slot of S ms serves S of a queue of forty, one at
    # 50% and nine at 90%, and the rest wait for the slots after.
    test "a slot serves the runner's own work for up to S ms, each request whole" do
      config =
        configured("var_global x bool at panel.i.0\nprogram b count\n", %{"count" => @count})

      for {share, slots} <- [{50, List.duplicate(1, 40)}, {90, [9, 9, 9, 9, 4]}] do
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: config,
            io: %{"panel" => {Sim, sim: panel}},
            clock: {TickClock, clock},
            overhead: share
          )

        requests = for _ <- 1..40, do: :gen_server.send_request(runner, {:get!, "b.n"})
        assert slotted(requests, clock, []) == slots, "#{share}%"
      end
    end

    # The share is of the continuous task's time and the runner's own: a timed task's runs
    # in a round are left out of the round's count (decision 122). On the ticking clock a
    # task due in every round takes time in each, and the slots come as they come without
    # it.
    test "the timed tasks' runs are left out of the share's count" do
      served =
        for text <- [
              "var_global x bool at panel.i.0\nprogram b count\n",
              "task t interval 1 priority 1\nvar_global x bool at panel.i.0\n" <>
                "program b count\nprogram c count with t\n"
            ] do
          {:ok, clock} = Manual.start_link()
          {:ok, panel} = Sim.start_link(clock: clock)

          {:ok, runner} =
            Runner.start_link(
              configuration: configured(text, %{"count" => @count}),
              io: %{"panel" => {Sim, sim: panel}},
              clock: {TickClock, clock},
              overhead: 10
            )

          for _ <- 1..4,
              do: waited(:gen_server.send_request(runner, {:get!, "b.n"}), clock)
        end

      assert [alone, beside] = served
      assert alone == beside
    end

    # A request that waited for a round is served in the rest of the millisecond the next
    # round does not fill, before the share's slot would come.
    test "a request that waited is served in the rest of a millisecond no round wants" do
      config =
        configured(
          "var_global q bool at drive.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, drive} = Sim.start_link(clock: clock)
      Sim.fail(drive, :write, {:delay, 2})

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      # The first round's write took 2 ms, so the next is owed at 2, and the request waits;
      # the round at 2 takes none, and the request is served before the next, at 3, long
      # before the slot 4 ms of rounds bring.
      assert {rounds(runner), Manual.now_ms(clock)} == {1, 2}
      request = :gen_server.send_request(runner, {:get!, "b.n"})
      assert :gen_server.wait_response(request, 0) == :timeout
      Manual.advance(clock, 0)
      assert :gen_server.wait_response(request, 0) == {:reply, 2}
    end

    # The review's probe: the first round's write passed 3 ms, so the next round is owed,
    # and a call made from another process waits. At 20% C is 4, and the round the next
    # advance runs, at 3, completes 6 ms of rounds: its slot, at its end, serves the call
    # in that advance, advance(clock, 0) though it is, never at a later one.
    test "a call whose slot a round completes is served in the advance that runs the " <>
           "round, advance(clock, 0) among them (decision 131)" do
      config =
        configured(
          "var_global q bool at slow.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 3}},
          clock: {Manual, clock}
        )

      assert Manual.now_ms(clock) == 3
      task = Task.async(fn -> Runner.get!(runner, "b.n") end)
      queued(runner, 1)
      Manual.advance(clock, 0)
      assert Task.yield(task, 1_000) == {:ok, 2}
    end

    # The moduledoc's way for a test to make a call on the manual clock, word for word: at
    # 10% C is 9, so the ninth advance after a slot brings the next.
    test "a call from another process, the clock advanced until it is answered" do
      config =
        configured(
          "var_global q bool at slow.q.0\nprogram t toggle\n  t.q q\nprogram boxes count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 1}},
          clock: {Manual, clock},
          overhead: 10
        )

      task = Task.async(fn -> Logex.Runner.get!(runner, "boxes.n") end)

      answered = fn answered ->
        case Task.yield(task, 10) do
          {:ok, value} ->
            value

          nil ->
            Logex.Runner.Clock.Manual.advance(clock, 0)
            answered.(answered)
        end
      end

      assert answered.(answered) == 9
    end

    # Decision 125: every device is refreshed, with the idle watchdog's deadline, before
    # the runner serves its own work, whichever way it serves it: at once, in a slot, or
    # in the rest of a millisecond.
    test "a refresh before a request served at once, before a slot, and before the rest " <>
           "of a millisecond is served" do
      # At once: no untimed program, so no round is ever owed.
      {opts, %{clock: clock}} = rig()
      {:ok, runner} = Runner.start_link(opts)
      %{"panel" => panel} = devices(runner)
      :erlang.trace(panel, true, [:receive])
      Manual.pass(clock, 3)
      assert Runner.get!(runner, "y") == 0
      assert refreshes(panel) == [3 + 510]

      # In a slot: at 50% every round's end is a slot, the step's and the write's
      # refreshes at the round's start, and the slot's after the write's 1 ms.
      config =
        configured(
          "var_global q bool at slow.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 1}},
          clock: {Manual, clock},
          overhead: 50
        )

      %{"slow" => slow} = devices(runner)
      :erlang.trace(slow, true, [:receive])
      request = :gen_server.send_request(runner, {:get!, "b.n"})
      queued(runner, 1)
      Manual.advance(clock, 0)
      assert :gen_server.wait_response(request, 0) == {:reply, 2}
      assert refreshes(slow) == [1 + 510, 1 + 510, 2 + 510]

      # In the rest of a millisecond: the first round's write took 2 ms, the round at 2
      # takes none, and the request is served before the round at 3, after a refresh.
      config =
        configured(
          "var_global q bool at drive.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, drive} = Sim.start_link(clock: clock)
      Sim.fail(drive, :write, {:delay, 2})

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      %{"drive" => device} = devices(runner)
      :erlang.trace(device, true, [:receive])
      request = :gen_server.send_request(runner, {:get!, "b.n"})
      queued(runner, 1)
      Manual.advance(clock, 0)
      assert :gen_server.wait_response(request, 0) == {:reply, 2}
      assert refreshes(device) == [2 + 510, 2 + 510, 2 + 510]

      # And where none waits, the rest of a millisecond refreshes nothing: each round of no
      # time its step's refresh and its write's, and the round at 3, the fourth of the
      # share's count, its slot's, no more.
      Manual.advance(clock, 2)
      assert refreshes(device) == [3 + 510, 3 + 510, 3 + 510, 4 + 510, 4 + 510]
    end

    # A round that takes no time counts a millisecond: the first, whose write takes none,
    # counts one, and the request sent after the second, each after it taking 1 ms, is
    # served at the slot after the fourth.
    test "a round counts a millisecond at least" do
      config =
        configured(
          "var_global q bool at drive.q.0\nprogram t toggle\n  t.q q\nprogram b count\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      for _ <- 1..10, do: Sim.fail(drive, :write, {:delay, 1})
      Manual.advance(clock, 1)
      assert {rounds(runner), Manual.now_ms(clock)} == {2, 2}
      assert waited(:gen_server.send_request(runner, {:get!, "b.n"}), clock) == 4
    end

    test "with no untimed program, a request is served at once, a round owed or not" do
      config =
        configured(
          "task fast interval 10 priority 1\nvar_global q bool at slow.q.0\n" <>
            "program t toggle with fast\n  t.q q\n",
          %{"toggle" => @toggle}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 15}},
          clock: {Manual, clock}
        )

      # The first round took 15 ms, so the round due at 10 is owed; the call is served.
      assert Manual.now_ms(clock) == 15
      assert Runner.get!(runner, "t.q") == 1
    end

    test "while it waits, every device refreshed at least once a poll period, with the " <>
           "idle watchdog's deadline" do
      {opts, %{clock: clock}} = plant_rig(counted(), poll: 3, idle: 100)
      {:ok, runner} = Runner.start_link(opts)
      %{"drive" => drive} = devices(runner)
      :erlang.trace(drive, true, [:receive])

      # Waiting from 0 for the round at 10: refreshed at 3, 6 and 9; then the round's step,
      # 500 ms and 3 on, and its write's.
      Manual.advance(clock, 10)
      assert refreshes(drive) == [3 + 103, 6 + 103, 9 + 103, 10 + 503, 10 + 103]
    end

    test "the due times are on the runner's clock, from the time it started" do
      {:ok, clock} = Manual.start_link(now: 7_003)
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: relayed(),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock}
        )

      assert rounds(runner) == 1
      Manual.advance(clock, 9)
      assert rounds(runner) == 1
      Manual.advance(clock, 1)
      assert rounds(runner) == 2

      assert Enum.filter(Manual.pending(clock), &(elem(&1, 1) == runner)) ==
               [{7_023, runner, {Runner, :wake, :sys.get_state(runner).token}}]
    end

    test "rounds on a periodic task keep their grid, absolute, a slow write's time not " <>
           "counted: 100,000 rounds, every one on time" do
      config =
        configured(
          "task fast interval 10 priority 1\nvar_global q bool at slow.q.0\n" <>
            "program t toggle with fast\n  t.q q\nprogram b count with fast\n",
          %{"toggle" => @toggle, "count" => @count}
        )

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 3}},
          clock: {Manual, clock},
          poll: 100_000
        )

      Manual.advance(clock, 999_990)
      assert Runner.get!(runner, "b.n") == 100_000
      assert rounds(runner) == 100_000
      assert Logex.Runtime.overlaps(:sys.get_state(runner).runtime) == %{"fast" => 0}
      assert Manual.now_ms(clock) == 999_993
    end
  end

  describe "the review's survivors, each a test" do
    # Decision 116's order, at a stop and when a device cannot be opened: each device
    # written its zeros and closed before the next, in device-name order.
    test "devices zeroed and closed in device-name order, at a stop and at an io_init" do
      {:ok, log} = Agent.start_link(fn -> [] end)
      {:ok, clock} = Manual.start_link()
      io = Map.new(0..2, &{"dev#{&1}", {LogIO, log: log}})

      {:ok, runner} =
        Runner.start_link(configuration: idle_crowd(3), io: io, clock: {Manual, clock})

      Agent.update(log, fn _ -> [] end)
      Runner.stop(runner)

      assert Enum.reverse(Agent.get(log, & &1)) ==
               Enum.flat_map(0..2, &[{:write, "dev#{&1}", %{[0] => 0}}, {:close, "dev#{&1}"}])

      # The third cannot be opened: the two before it, in their order.
      Agent.update(log, fn _ -> [] end)
      io = Map.put(io, "dev2", {LogIO, log: log, fail: true})

      assert {:error, {:io_init, "dev2", :refused}} =
               Runner.start_link(configuration: idle_crowd(3), io: io, clock: {Manual, clock})

      assert Enum.reverse(Agent.get(log, & &1)) ==
               Enum.flat_map(0..1, &[{:write, "dev#{&1}", %{[0] => 0}}, {:close, "dev#{&1}"}])
    end

    test "subscribing again and unsubscribing leave one monitor and then none" do
      {opts, _rig} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)
      monitors = fn -> length(elem(Process.info(runner, :monitors), 1)) end
      assert monitors.() == 0
      :ok = Runner.subscribe(runner)
      :ok = Runner.subscribe(runner, [:round])
      :ok = Runner.subscribe(runner, [:ran])
      assert monitors.() == 1
      :ok = Runner.unsubscribe(runner)
      assert monitors.() == 0
    end

    # A trigger logic writes is compared, after the first round, with its value before it:
    # `g`, declared 1 and left at 1 by the first round, which its task's run sees as
    # already high, is no change, and makes no round.
    test "a trigger logic writes starts at its declared value" do
      text = """
      task t single g priority 0
      var_global g bool 1
      var_global x bool at panel.i.0
      program c count with t
      """

      {opts, %{clock: clock}} = rig(configured(text, %{"count" => @count}))
      {:ok, runner} = Runner.start_link(opts)
      assert Runner.get!(runner, "c.n") == 1
      Manual.advance(clock, 20)
      assert rounds(runner) == 1
    end

    # The continuous task's round is timed from its start to the end of its last program,
    # the timed tasks' steps in it included (decisions 111 and 126): on the ticking clock
    # its longest round with two timed steps in it is at least its longest without them,
    # plus each one's run.
    test "the continuous task's round includes its timed steps' runs" do
      runs = fn text ->
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: configured(text, %{"count" => @count}),
            io: %{"panel" => {Sim, sim: panel}},
            clock: {TickClock, clock}
          )

        waited(:gen_server.send_request(runner, :status), clock).runs
      end

      head = "task main continuous\nvar_global x bool at panel.i.0\nprogram b count\n"
      %{"main" => {alone, 500}} = runs.(head)

      %{"main" => {beside, 500}, "fast" => {fast, 500}, "slow" => {slow, 500}} =
        runs.(
          head <>
            "task fast interval 10 priority 1\ntask slow interval 1000000 priority 2\n" <>
            "program c count with fast\nprogram d count with slow\n"
        )

      assert fast > 0 and slow > 0
      assert beside >= alone + fast + slow
    end

    # A continuous line that runs no instance times no round (decision 111): the rounds
    # of timed tasks alone are not its, so its longest round stays 0.
    test "a continuous task that runs no instance times no round" do
      text =
        "task main continuous watchdog 200\ntask fast interval 10 priority 1\n" <>
          "var_global x bool at panel.i.0\nprogram c count with fast\n"

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text, %{"count" => @count}),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {TickClock, clock}
        )

      Manual.advance(clock, 30)
      assert %{"main" => {0, 200}, "fast" => {fast, 500}} = Runner.status(runner).runs
      assert fast > 0
    end

    # The runner refreshes every device during the round a device's change makes, the
    # device that made it among them, which takes each refresh while it waits: so its
    # deadline is the last, the write's, when set/3 returns.
    test "a device waiting on its own change takes the refreshes sent meanwhile" do
      {opts, %{clock: clock, panel: panel}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)
      %{"panel" => device} = devices(runner)
      assert :sys.get_state(device).deadline == 0 + 510
      Manual.pass(clock, 2)
      Sim.set(panel, [1], 1)
      assert :sys.get_state(device).deadline == 2 + 510
    end

    # The slow device's every write takes 13 ms, so the first round ends at 13, past the
    # panel's first poll, at 10, which comes late: the polls after it keep their grid, at
    # 20, 30 and 40, not 23 and 33. And the panel, written at 0, is written again at the
    # late poll, at 13, and so not at 20, within a poll period of it, but at 30 and 40:
    # at most once a poll period (decision 130).
    test "the polls after a late one keep their grid" do
      config =
        configured(
          "task fast interval 100 priority 1\nvar_global q bool at slow.q.0\n" <>
            "var_global x bool at panel.i.0\nvar_global y bool at panel.q.0\n" <>
            "program r relay with fast\n  r.in x\n  r.out y\n" <>
            "program t toggle with fast\n  t.q q\n",
          %{"toggle" => @toggle, "relay" => @relay}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, _runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}, "slow" => {SlowIO, clock: clock, ms: 13}},
          clock: {Manual, clock}
        )

      assert Manual.now_ms(clock) == 13
      Manual.advance(clock, 27)
      assert Sim.reads(panel) == 5
      assert length(Sim.writes(panel)) == 4
    end
  end

  describe "the outputs written again each poll period (decision 130)" do
    test "a device whose outputs do not change is written them again once a poll period, " <>
           "from its last write" do
      for {poll, again} <- [{10, 3}, {7, 4}] do
        {opts, %{clock: clock, panel: panel}} = rig(relayed(), poll: poll)
        Sim.set(panel, [0], 1)
        {:ok, _runner} = Runner.start_link(opts)
        Manual.advance(clock, 30)
        assert Sim.writes(panel) == List.duplicate(%{[0] => 1}, 1 + again), "poll #{poll}"
      end

      # The values last written: a change written by a round is what comes again. `x` set
      # at 12 reaches `y` in the round at 20, whose write follows the poll at 20, which
      # wrote 0 again; the poll at 30 writes the 1.
      {opts, %{clock: clock, panel: panel}} = rig()
      {:ok, _runner} = Runner.start_link(opts)
      Manual.advance(clock, 12)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 8)
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}, %{[0] => 0}, %{[0] => 1}]
      Manual.advance(clock, 10)
      assert Enum.drop(Sim.writes(panel), 3) == [%{[0] => 1}, %{[0] => 1}]
    end

    test "a device a round writes within each poll period is written nothing more" do
      config =
        configured(
          "var_global q bool at panel.q.0\nprogram t toggle\n  t.q q\n",
          %{"toggle" => @toggle}
        )

      {opts, %{clock: clock, panel: panel}} = rig(config)
      {:ok, runner} = Runner.start_link(opts)
      Manual.advance(clock, 30)
      assert length(Sim.writes(panel)) == rounds(runner)
      assert rounds(runner) == 31
    end

    test "a device with no output point is never written, at any poll" do
      text =
        String.replace(
          @counted,
          "var_global e    bool at panel.i.1",
          "var_global e    bool at keys.i.0"
        )

      {opts, %{clock: clock}} = plant_rig(counted(text))
      {:ok, keys} = Sim.start_link(clock: clock)

      {:ok, _runner} =
        Runner.start_link(Keyword.update!(opts, :io, &Map.put(&1, "keys", {Sim, sim: keys})))

      Manual.advance(clock, 50)
      assert Sim.reads(keys) == 6
      assert Sim.writes(keys) == []
    end

    # A runner suspended after its first round refreshes nothing more: its last deadline
    # is the write's, 500 ms and a poll period on, and the panel writes again at each poll
    # before it, never after.
    test "a device whose last refresh's deadline has passed writes nothing again" do
      {opts, %{clock: clock, panel: panel}} = rig()
      {:ok, runner} = Runner.start_link(opts)
      :sys.suspend(runner)
      Manual.advance(clock, 600)
      assert length(Sim.writes(panel)) == 1 + 50
      :sys.resume(runner)
    end

    # Idle devices cost one write each a poll period, however many there are: d devices
    # whose outputs never change, over 1,000 ms at a poll period of 10 ms, are written 101
    # times each, the first round's and one each period.
    test "idle devices cost one write each a poll period" do
      for d <- [1, 4, 16] do
        {:ok, clock} = Manual.start_link()

        sims =
          Map.new(0..(d - 1), fn k ->
            {:ok, sim} = Sim.start_link(clock: clock)
            {"dev#{k}", sim}
          end)

        {:ok, runner} =
          Runner.start_link(
            configuration: idle_crowd(d),
            io: Map.new(sims, fn {name, sim} -> {name, {Sim, sim: sim}} end),
            clock: {Manual, clock}
          )

        Manual.advance(clock, 1_000)

        assert Enum.map(sims, fn {_name, sim} -> length(Sim.writes(sim)) end) ==
                 List.duplicate(101, d)

        Runner.stop(runner)
      end
    end
  end

  # d devices, each with one output a 10 ms task's program holds at 0.
  defp idle_crowd(d) do
    hold = program("var_output q bool\nxic q ote q", "hold")

    Configuration.new!(
      name: "plant",
      programs: [hold],
      tasks: [%Configuration.Task{name: "slow", interval: 10, priority: 1}],
      globals:
        for(
          k <- 0..(d - 1),
          do: %Configuration.Global{name: "q#{k}", type: :bool, at: "dev#{k}.q.0"}
        ),
      instances:
        for(
          k <- 0..(d - 1),
          do: %Configuration.Instance{name: "h#{k}", type: "hold", task: "slow"}
        ),
      connections:
        for(
          k <- 0..(d - 1),
          do: %Configuration.Connection{instance: "h#{k}", member: "q", to: "q#{k}"}
        )
    )
  end

  describe "stop/2, status/1 and subscriptions" do
    test "stop/2 writes every output 0 once and closes every device before it returns " <>
           "(decision 116)" do
      {opts, %{panel: panel, drive: drive, clock: clock}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)
      Sim.set(panel, %{[0] => 1, [1] => 1})
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 1}
      before = {Sim.writes(panel), Sim.writes(drive)}

      # One write each at the stop, every output 0, and nothing else.
      assert Runner.stop(runner) == :ok
      refute Process.alive?(runner)

      assert {Sim.writes(panel), Sim.writes(drive)} ==
               {elem(before, 0) ++ [%{[0] => 0}], elem(before, 1) ++ [%{[0] => 0}]}

      assert Sim.closed?(panel) and Sim.closed?(drive)
      reads = Sim.reads(panel)

      # Nothing after: no read, no write.
      Manual.advance(clock, 50)
      assert Sim.reads(panel) == reads
      assert List.last(Sim.writes(panel)) == %{[0] => 0}

      # Its reason is a GenServer's, and a runner that is none is told so.
      {opts, _rig} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)
      Process.flag(:trap_exit, true)
      assert Runner.stop(runner, :shutdown) == :ok
      assert_receive {:EXIT, ^runner, :shutdown}

      raises("the runner #{inspect(runner)} is not running", fn -> Runner.stop(runner) end)
    end

    test "status/1 at start" do
      {opts, _rig} = plant_rig(counted(), poll: 4)
      {:ok, runner} = Runner.start_link(opts)

      assert Runner.status(runner) == %{
               status: :running,
               now: 0,
               rounds: 1,
               trip: nil,
               overlaps: %{"fast" => 0, "trip" => 0},
               forces: %{},
               edit: nil,
               runs: %{"fast" => {0, 500}, "trip" => {0, 500}},
               latest_wake: 0,
               refresh_gap: 0
             }
    end

    test "status/1's runs: each timed task's longest step and the continuous task's " <>
           "longest round, against its watchdog" do
      text =
        "task main continuous watchdog 200\ntask fast interval 10 priority 1 watchdog 50\n" <>
          "task idle interval 1000000 priority 2\n" <>
          "var_global x bool at panel.i.0\nprogram b count\nprogram c count with fast\n" <>
          "program d count with idle\n"

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text, %{"count" => @count}),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {TickClock, clock}
        )

      # Rounds are always owed on this clock, so the request waits for its slot.
      status = fn -> waited(:gen_server.send_request(runner, :status), clock) end
      %{runs: runs} = status.()
      assert %{"main" => {main, 200}, "fast" => {fast, 50}, "idle" => {idle, 500}} = runs
      assert map_size(runs) == 3

      # Each step reads the clock twice and refreshes once on the ticking clock, and the
      # round holds two steps more.
      assert fast > 0 and idle > 0 and main > fast + idle
      Manual.advance(clock, 30)
      assert %{"main" => {^main, 200}, "idle" => {^idle, 500}} = status.().runs

      # Untimed programs and no continuous line: under :none, 500 ms.
      {opts, _rig} =
        rig(configured("var_global x bool at panel.i.0\nprogram b count\n", %{"count" => @count}))

      {:ok, runner} = Runner.start_link(opts)
      assert Runner.status(runner).runs == %{none: {0, 500}}
    end

    test "status/1's latest wake and longest wait between two refreshes, in ms" do
      config =
        configured(
          "task fast interval 10 priority 1\nvar_global q bool at slow.q.0\n" <>
            "program t toggle with fast\n  t.q q\n",
          %{"toggle" => @toggle}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, slow} = Sim.start_link(clock: clock)
      Sim.fail(slow, :write, {:delay, 14})

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {Sim, sim: slow}},
          clock: {Manual, clock},
          poll: 20
        )

      # The first round's write took 14 ms: the round due at 10 woke at 14, 4 late, after
      # a wait of 14 ms since the last refresh, before its write.
      Manual.advance(clock, 0)
      assert %{latest_wake: 4, refresh_gap: 14, rounds: 2, now: 14} = Runner.status(runner)

      # Each the longest: later wakes are on time, and later waits 10 ms.
      Manual.advance(clock, 30)
      assert %{latest_wake: 4, refresh_gap: 14, rounds: 5, now: 40} = Runner.status(runner)
    end

    test "subscribe/2: the resource's overlaps and faults by default, `:ran` and `:round` " <>
           "where named, each as {Logex.Runner, runner, event}" do
      text =
        "task fast interval 10 priority 1\nvar_global q bool at slow.q.0\n" <>
          "program t toggle with fast\n  t.q q\nprogram z zero with fast\n"

      config =
        configured(text, %{
          "toggle" => @toggle,
          "zero" => "var_output n dint\nvar d dint\ndiv 1 d n"
        })

      {:ok, clock} = Manual.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"slow" => {SlowIO, clock: clock, ms: 25}},
          clock: {Manual, clock},
          poll: 1000
        )

      assert Runner.subscribe(runner) == :ok
      forwarding(runner, [:ran, :round])

      # The first round's write took 25 ms, so the round at 25 runs the task due at 10 and
      # misses the one at 20.
      Manual.advance(clock, 0)
      assert_received {Runner, ^runner, {:overlap, "fast", 1}}

      assert_received {Runner, ^runner,
                       {:fault, "fast", "z", %Logex.Fault{kind: :divide_by_zero}}}

      refute_received {Runner, ^runner, {:ran, _, _, _}}

      assert Runner.status(runner).overlaps == %{"fast" => 1}

      # In the order they happened, the round's last.
      assert for(_ <- 1..3, do: receive(do: ({:forwarded, event} -> event))) == [
               {:ran, "fast", "t", 25},
               {:ran, "fast", "z", 25},
               {:round, 25, %{"q" => 0}}
             ]

      refute_received {:forwarded, _}

      # Subscribing again replaces the kinds; unsubscribing stops them.
      assert Runner.subscribe(runner, [:round]) == :ok
      Manual.advance(clock, 0)
      assert_received {Runner, ^runner, {:round, 50, %{"q" => 1}}}
      refute_received {Runner, ^runner, {:fault, _, _, _}}
      assert Runner.unsubscribe(runner) == :ok
      Manual.advance(clock, 0)
      refute_received {Runner, ^runner, _}
      assert_receive {:forwarded, {:round, 75, _}}
    end

    test "a subscriber that goes down is dropped" do
      {opts, %{clock: clock}} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)

      gone =
        spawn(fn ->
          Runner.subscribe(runner, [:round])
        end)

      ref = Process.monitor(gone)
      assert_receive {:DOWN, ^ref, :process, ^gone, _}
      :sys.get_state(runner)
      assert :sys.get_state(runner).subscribers == %{}
      Manual.advance(clock, 10)
      assert Process.alive?(runner)
    end

    test "subscribe/2's host mistakes, raised in the caller" do
      {opts, _rig} = plant_rig()
      {:ok, runner} = Runner.start_link(opts)

      for kinds <- [:ran, [:ran, :rounds], ["ran"], [:round | :ran], [:ran, :round | :overlap]] do
        raises(
          "a runner's events are subscribed by a list of their kinds, among :overlap, " <>
            ":fault, :trip, :restart, :edit, :ran and :round, got: #{inspect(kinds)}",
          fn -> Runner.subscribe(runner, kinds) end
        )
      end

      raises("expected a runner from Logex.Runner.start_link/1, got: 42", fn ->
        Runner.unsubscribe(42)
      end)

      raises("no runner is running under the name :x", fn -> Runner.status(:x) end)
      assert Process.alive?(runner)

      # Anything else sent to it changes nothing.
      send(runner, :junk)
      assert Runner.status(runner).rounds == 1
    end
  end

  # A subscriber of its own, which passes each event it is sent on to the test, tagged.
  defp forwarding(runner, kinds) do
    test = self()

    pid =
      spawn_link(fn ->
        :ok = Runner.subscribe(runner, kinds)
        send(test, :subscribed)
        forward(test)
      end)

    assert_receive :subscribed
    pid
  end

  defp forward(test) do
    receive do
      {Runner, _runner, event} -> send(test, {:forwarded, event})
    end

    forward(test)
  end

  # The runner's cost a round, in reductions of its own process over 20 rounds, against the
  # instances and the devices: each instance an untimed toggle whose output point changes
  # every round, so that every device is written in every round, its points spread over
  # the devices. Linear in both (PLAN.md Milestone 4's growth rule): measured at 3.60x for
  # 4x the instances and the devices together, 3.53x for the instances alone and 1.06x for
  # the devices alone, deterministic to a few hundred reductions; each bound is a fifth
  # above the highest of 32 runs, half of them beside three full suites.
  describe "growth" do
    defp crowd(n, d) do
      toggle = program("var_input in bool\nvar_output q bool\nxio q ote q", "toggle")

      Configuration.new!(
        name: "plant",
        programs: [toggle],
        tasks: [%Configuration.Task{name: "main", continuous: true}],
        globals:
          Enum.flat_map(1..n, fn i ->
            at = "dev#{rem(i - 1, d)}.%s.#{div(i - 1, d)}"

            [
              %Configuration.Global{
                name: "x#{i}",
                type: :bool,
                at: String.replace(at, "%s", "i")
              },
              %Configuration.Global{name: "y#{i}", type: :bool, at: String.replace(at, "%s", "q")}
            ]
          end),
        instances: for(i <- 1..n, do: %Configuration.Instance{name: "r#{i}", type: "toggle"}),
        connections:
          Enum.flat_map(1..n, fn i ->
            [
              %Configuration.Connection{instance: "r#{i}", member: "in", to: "x#{i}"},
              %Configuration.Connection{instance: "r#{i}", member: "q", to: "y#{i}"}
            ]
          end)
      )
    end

    defp round_cost(n, d) do
      {:ok, clock} = Manual.start_link()

      io =
        Map.new(0..(d - 1), fn k ->
          {:ok, sim} = Sim.start_link(clock: clock)
          {"dev#{k}", {Sim, sim: sim}}
        end)

      {:ok, runner} =
        Runner.start_link(
          configuration: crowd(n, d),
          io: io,
          clock: {Manual, clock},
          poll: 1_000_000
        )

      Manual.advance(clock, 5)
      {:reductions, before} = Process.info(runner, :reductions)
      Manual.advance(clock, 20)
      {:reductions, later} = Process.info(runner, :reductions)
      Runner.stop(runner)
      later - before
    end

    test "a round's work is linear in the instances and the devices" do
      base = round_cost(20, 2)
      both = round_cost(80, 8) / base
      instances = round_cost(80, 2) / base
      devices = round_cost(20, 8) / base
      assert both < @both_bound, "4x both took #{Float.round(both, 2)}x"
      assert instances < @instances_bound, "4x the instances took #{Float.round(instances, 2)}x"
      assert devices < @devices_bound, "4x the devices took #{Float.round(devices, 2)}x"
    end
  end
end
