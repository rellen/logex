defmodule Logex.TripTest do
  @moduledoc """
  M4-4: the wall-clock runner's watchdogs and fault path (`docs/organisation.md` §4.11,
  decisions 110, 111, 113 to 115, 125, 126 and 128), every rule on the manual clock with
  simulated devices, a hung device's deadline in real time and short: a trip's one path,
  every output written 0 once through each device that answers and nothing after, the
  resource kept for `get/2`, and `restart/2`, cold and warm, with the first round at once
  and the clock not counting the stopped time; each trip's reason; and the hidden seam,
  `steps:`, through which a test reaches `{:internal, message}`.
  """
  use ExUnit.Case, async: true

  alias Logex.Configuration
  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual
  alias Logex.Runtime

  # The hidden seam's stand-in for Logex.Runtime's steps: each delegates to the core, and
  # the input `boom` says where an exception comes out of it, 1 in cycle_steps/3 (read
  # among the inputs given it), 2 a raise in a step, 3 a throw, 4 an exit, and 5 a raise in
  # cycle_outputs/1, each after the core has done its part.
  defmodule Boom do
    # A task named `first` never blows, so that a round's steps before the one that does
    # can be seen.
    def cycle_step(runtime, {_kind, "first", _run} = step), do: Runtime.cycle_step(runtime, step)

    def cycle_step(runtime, step) do
      {runtime, events} = Runtime.cycle_step(runtime, step)
      blow(Runtime.get!(runtime, "boom"), 2)
      {runtime, events}
    end

    def cycle_steps(runtime, elapsed, inputs) do
      blow(Map.get(inputs, "boom"), 1)
      Runtime.cycle_steps(runtime, elapsed, inputs)
    end

    def cycle_outputs(runtime) do
      outputs = Runtime.cycle_outputs(runtime)
      blow(Runtime.get!(runtime, "boom"), 5)
      outputs
    end

    defp blow(1, 1), do: raise("boom in the steps")
    defp blow(2, 2), do: raise("boom in a step")
    defp blow(3, 2), do: throw(:boom)
    defp blow(4, 2), do: exit(:boom)
    defp blow(5, 5), do: raise("boom in the outputs")
    defp blow(_value, _where), do: :ok
  end

  # A stand-in that makes time pass inside a task's run, where nothing else can on the
  # manual clock: after each step the core ran, the input `<task>_ms`, `none_ms` for the
  # untimed programs where no continuous task is declared, is passed on the runner's clock,
  # which the test put in this module's table beside the runner. And `<task>_stuck` is a
  # runner stuck in the step that long: the clock advanced from inside it, every timer on
  # the way delivered to the devices, which the runner cannot answer meanwhile, and what
  # each simulated device was written by then recorded in the table, `{runner, :seen}`.
  defmodule Slow do
    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    def cycle_step(runtime, {_kind, task, _run} = step) do
      {runtime, events} = Runtime.cycle_step(runtime, step)
      clock = :ets.lookup(Logex.TripTest, self())
      passed(clock, Runtime.get(runtime, "#{named(task)}_ms"))
      stuck(clock, Runtime.get(runtime, "#{named(task)}_stuck"))
      {runtime, events}
    end

    defp stuck([{runner, clock}], {:ok, ms}) when ms > 0 do
      Manual.advance(clock, ms)
      [{_key, sims}] = :ets.lookup(Logex.TripTest, {runner, :sims})
      :ets.insert(Logex.TripTest, {{runner, :seen}, Enum.map(sims, &Sim.writes/1)})
    end

    defp stuck(_clock, _ms), do: :ok

    defp named(:none), do: "none"
    defp named(task), do: task

    defp passed([{_runner, clock}], {:ok, ms}) when ms > 0, do: Manual.pass(clock, ms)
    defp passed(_clock, _ms), do: :ok
  end

  # A stand-in whose step of the task `e1` sleeps 200 ms on the real clock.
  defmodule Sleeps do
    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    def cycle_step(runtime, {:timed, "e1", _run} = step) do
      Process.sleep(200)
      Runtime.cycle_step(runtime, step)
    end

    def cycle_step(runtime, step), do: Runtime.cycle_step(runtime, step)
  end

  # A clock whose every reading takes `ms`, the manual clock's: so that the runner's own
  # work takes time.
  defmodule Ticks do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms({clock, ms}) do
      Manual.pass(clock, ms)
      Manual.now_ms(clock)
    end

    @impl true
    def wake_at({clock, _ms}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _ms}, timer), do: Manual.cancel(clock, timer)
  end

  # An adapter whose read gives what no callback of Logex.IO gives, and whose close raises.
  defmodule BadIO do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Map.new(opts)}

    @impl true
    def read(%{read: :bad}), do: :nope
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(_values, state), do: {:ok, state}

    @impl true
    def close(_state), do: raise("no close")
  end

  # A stand-in whose cycle_steps/3 gives what the core never gives, where the input `boom`
  # is 6: the runner itself then crashes, outside any call of the core's.
  defmodule Garbage do
    def cycle_steps(_runtime, _elapsed, %{"boom" => 6}), do: :garbage
    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_step(runtime, step), do: Runtime.cycle_step(runtime, step)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)
  end

  # An adapter that refuses to open and tells the test, the parent of the runner that
  # started the device's process, of any write or close it is given after.
  defmodule RefusingIO do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:error, {:refused, opts[:test]}}

    @impl true
    def read(state), do: {:ok, %{}, state}

    @impl true
    def write(values, state), do: told({:written, values}, {:ok, state})

    @impl true
    def close(_state), do: told(:closed, :ok)

    defp told(message, result) do
      [_runner, test | _] = Process.get(:"$ancestors")
      send(test, message)
      result
    end
  end

  # A manual clock that goes down as it is read from `at` on: an exit out of a call to it,
  # as a clock gone down while it is read gives.
  defmodule GoneClock do
    @behaviour Logex.Runner.Clock

    @impl true
    def now_ms({clock, at}), do: gone(Manual.now_ms(clock), at)

    @impl true
    def wake_at({clock, _at}, pid, message, at), do: Manual.wake_at(clock, pid, message, at)

    @impl true
    def cancel({clock, _at}, timer), do: Manual.cancel(clock, timer)

    defp gone(now, at) when now >= at, do: exit(:gone)
    defp gone(now, _at), do: now
  end

  # The simulated device, its adapter's closes counted in this module's table by its sim.
  defmodule Closes do
    @behaviour Logex.IO

    @impl true
    def check(device, points, opts), do: Sim.check(device, points, opts)

    @impl true
    def init(device, points, opts), do: Sim.init(device, points, opts)

    @impl true
    def read(state), do: Sim.read(state)

    @impl true
    def write(values, state), do: Sim.write(values, state)

    @impl true
    def report(message, state), do: Sim.report(message, state)

    @impl true
    def close(%{sim: sim} = state) do
      :ets.update_counter(Logex.TripTest, {:closes, sim}, 1, {{:closes, sim}, 0})
      Sim.close(state)
    end
  end

  # An adapter whose every read gives the values it was bound with, `values:`.
  defmodule Values do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Map.new(opts)}

    @impl true
    def read(%{values: values} = state), do: {:ok, values, state}

    @impl true
    def write(_values, state), do: {:ok, state}
  end

  setup_all do
    :ets.new(__MODULE__, [:named_table, :public, :set])
    :ok
  end

  # The growth test's bound, a fifth above the highest of 38 runs, 4.233, each beside a
  # mutation run's three suites (see "growth").
  @trip_bound 5.08

  # One var_input copied to one var_output, and a counter of its own runs.
  @relay "var_input in bool\nvar_output out bool\nxic in ote out"
  @count "var_output n dint\nadd n 1 n"

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  # The relay on a 10 ms task, from the panel's `x` to its `y`, a count of the task's runs
  # in `runs`, and the panel's `boom`, which the stand-in reads.
  @relayed """
  task fast interval 10 priority 1

  var_global x    bool at panel.i.0
  var_global boom dint at panel.i.1
  var_global y    bool at panel.q.0
  var_global runs dint

  program r relay with fast
    r.in  x
    r.out y

  program c count with fast
    c.n runs
  """

  defp configured(text \\ @relayed) do
    {:ok, config} =
      Configuration.compile("plant", text, %{
        "relay" => program(@relay, "relay"),
        "count" => program(@count, "count")
      })

    config
  end

  # The panel that reports and the drive that does not, on one manual clock, the poll
  # period so long that no poll's write again (decision 130) comes in a test.
  defp rig(config \\ configured(), extra \\ []) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(reports: true, clock: clock)
    {:ok, drive} = Sim.start_link(clock: clock)

    io = Map.take(%{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}}, devices(config))

    {:ok, runner} =
      Runner.start_link(
        Keyword.merge(
          [configuration: config, io: io, clock: {Manual, clock}, poll: 1_000_000, steps: Boom],
          extra
        )
      )

    %{runner: runner, clock: clock, panel: panel, drive: drive}
  end

  defp devices(config), do: Map.keys(Logex.IO.points(config))

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  describe "a trip (decision 113), reached through the hidden seam" do
    test "an exception out of the core trips {:internal, message} before the round's " <>
           "write, every output written 0 once and nothing after, the resource kept" do
      %{runner: runner, clock: clock, panel: panel} = rig()
      Runner.subscribe(runner)
      assert Sim.writes(panel) == [%{[0] => 0}]

      # The round computes y = 1, and its outputs are never written: the panel is zeroed.
      Sim.set(panel, %{[0] => 1, [1] => 5})
      Manual.advance(clock, 10)
      assert_receive {Runner, ^runner, {:trip, {:internal, "boom in the outputs"}}}
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert Runner.get!(runner, "y") == 1
      assert Runner.get!(runner, "r.out") == 1

      assert %{status: :tripped, trip: {:internal, "boom in the outputs"}, rounds: 1} =
               Runner.status(runner)

      # Nothing after: no round, no write, whatever the clock or the inputs do.
      Manual.advance(clock, 1000)
      Sim.set(panel, [0], 0)
      Manual.advance(clock, 1000)
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert %{status: :tripped, rounds: 1} = Runner.status(runner)
      refute Enum.any?(Manual.pending(clock), fn {_at, pid, _message} -> pid == runner end)
      refute_received {Runner, ^runner, _event}
    end

    test "each seam trips: cycle_steps/3, a step's raise, throw and exit, and " <>
           "cycle_outputs/1, each in its words" do
      for {boom, reason} <- [
            {1, "boom in the steps"},
            {2, "boom in a step"},
            {3, "** (throw) :boom"},
            {4, "** (exit) :boom"},
            {5, "boom in the outputs"}
          ] do
        %{runner: runner, clock: clock, panel: panel} = rig()
        Sim.set(panel, [1], boom)
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == {:internal, reason}
        assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      end
    end

    test "a step's exception keeps the resource as the steps before it left it, and " <>
           "the round's events as far as it ran" do
      text =
        "task first interval 10 priority 1\ntask slow interval 10 priority 2\n" <>
          "var_global boom dint at panel.i.1\nvar_global a dint\nvar_global b dint\n" <>
          "program c count with first\n  c.n a\nprogram d count with slow\n  d.n b\n"

      %{runner: runner, clock: clock, panel: panel} = rig(configured(text))
      Runner.subscribe(runner, [:ran, :trip])
      Sim.set(panel, [1], 2)
      Manual.advance(clock, 10)

      # The first task's step ran and is kept, its event sent; the slow task's raised, and
      # its run is lost with it.
      assert_receive {Runner, ^runner, {:ran, "first", "c", 10}}
      assert_receive {Runner, ^runner, {:trip, {:internal, "boom in a step"}}}
      refute_received {Runner, ^runner, {:ran, "slow", _, _}}
      assert {Runner.get!(runner, "a"), Runner.get!(runner, "b")} == {2, 1}
      assert Runner.status(runner).now == 10
    end

    test "while tripped a device's change is merged and makes no round, and a host's " <>
           "request is served at once" do
      %{runner: runner, clock: clock, panel: panel} = rig()
      Sim.set(panel, [1], 5)
      Manual.advance(clock, 10)
      assert %{status: :tripped, rounds: 1} = Runner.status(runner)

      Sim.set(panel, %{[0] => 1, [1] => 0})
      assert :sys.get_state(runner).pending == %{"x" => 1, "boom" => 0}
      assert Runner.get!(runner, "x") == 0
      assert %{rounds: 1} = Runner.status(runner)
    end

    test "a trip that no wake brought cancels the wake set, and a trigger's change while " <>
           "tripped makes no round" do
      text =
        @relayed <>
          "task e single t priority 0\nvar_global t bool at panel.i.2\nvar_global hits dint\n" <>
          "program h count with e\n  h.n hits\n"

      %{runner: runner, clock: clock, panel: panel} = rig(configured(text))
      assert Enum.any?(Manual.pending(clock), fn {_at, pid, _message} -> pid == runner end)

      # The trigger's round, at once, trips: the periodic task's wake at 10 is cancelled.
      Sim.set(panel, [1], 5)
      Sim.set(panel, [2], 1)
      assert %{status: :tripped, rounds: 1} = Runner.status(runner)
      refute Enum.any?(Manual.pending(clock), fn {_at, pid, _message} -> pid == runner end)

      Sim.set(panel, [2], 0)
      Sim.set(panel, [2], 1)
      Manual.advance(clock, 100)
      assert %{status: :tripped, rounds: 1} = Runner.status(runner)
      assert Runner.get!(runner, "hits") == 1
    end

    test "a host's request waiting for the share's slot is answered at the trip" do
      text =
        "task main continuous\nvar_global boom dint at panel.i.1\nvar_global a dint\n" <>
          "program c count\n  c.n a\n"

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 1_000_000,
          steps: Boom
        )

      # A round is owed at 1, so the request waits for its slot; the round trips first.
      Manual.pass(clock, 1)
      task = Task.async(fn -> Runner.get!(runner, "a") end)
      wait_queued(runner)
      Sim.set(panel, [1], 2)
      Manual.advance(clock, 0)
      assert Task.await(task) == 1
      assert Runner.status(runner).trip == {:internal, "boom in a step"}
    end

    test "a latched device writes nothing again at its polls, and a tripped runner " <>
           "refreshes no device" do
      %{runner: runner, clock: clock, panel: panel} = rig(configured(), poll: 10)
      Manual.advance(clock, 30)
      assert length(Sim.writes(panel)) == 4
      Sim.set(panel, [1], 5)
      Manual.advance(clock, 10)
      assert Runner.status(runner).status == :tripped
      device = :sys.get_state(runner).devices |> hd() |> elem(1)
      :erlang.trace(device, true, [:receive])
      written = Sim.writes(panel)
      assert List.last(written) == %{[0] => 0}

      # Its polls go on, reading, and write nothing; and the runner sends no refresh,
      # whatever a host asks of it.
      reads = Sim.reads(panel)
      Manual.advance(clock, 100)
      Runner.status(runner)
      Runner.get(runner, "x")
      Manual.advance(clock, 100)
      assert Sim.writes(panel) == written
      assert Sim.reads(panel) == reads + 20
      :erlang.trace(device, false, [:receive])
      refute_received {:trace, ^device, :receive, {:"$gen_cast", {:refresh, _, _}}}
      flush_traces(device)
    end

    test "stop/2 after a trip writes no 0 again, and closes every device" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@relayed <> "var_global z bool at drive.q.0\n"))

      Sim.set(panel, [1], 5)
      Manual.advance(clock, 10)
      zeroed = {Sim.writes(panel), Sim.writes(drive)}
      assert zeroed == {[%{[0] => 0}, %{[0] => 0}], [%{[0] => 0}, %{[0] => 0}]}
      assert Runner.stop(runner) == :ok
      assert {Sim.writes(panel), Sim.writes(drive)} == zeroed
      assert Sim.closed?(panel) and Sim.closed?(drive)
    end

    test "a message shaped as a device's notice, from a process that is not that " <>
           "device's, is passed over" do
      text =
        "var_global x bool at panel.i.0\nvar_global y bool at panel.q.0\n" <>
          "program r relay\n  r.in x\n  r.out y\n"

      %{runner: runner, clock: clock} =
        rig(configured(text), poll: 10, idle: 100, steps: Runtime)

      # A fault in its words trips nothing.
      send(runner, {Logex.Runner.Device, self(), 0, 0, {:fault, "panel", {:error, :forged}}})
      Manual.advance(clock, 20)
      assert Runner.status(runner).status == :running

      # Nor does a "back" keep a device heard: the panel held after its read at 20 is
      # silent from 131 whatever the forged notice says.
      send(runner, {Logex.Runner.Device, self(), 0, 1_000_000, {:back, "panel", nil}})
      Runner.status(runner)
      :sys.suspend(device_pid(runner, "panel"))
      Manual.advance(clock, 111)
      assert Runner.status(runner).trip == {:io, "panel", :timeout}
    end

    test "the hidden option's mistake, raised in the caller" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      opts = [
        configuration: configured(),
        io: %{"panel" => {Sim, sim: panel}},
        clock: {Manual, clock}
      ]

      for steps <- [Enum, :no_such_module, "Boom"] do
        raises(
          "the runner's steps: is a module with cycle_steps/3, cycle_step/2 and " <>
            "cycle_outputs/1, standing in for Logex.Runtime's, got: #{inspect(steps)}",
          fn -> Runner.start_link(opts ++ [steps: steps]) end
        )
      end
    end
  end

  # A runner on the slow stand-in, its clock in the table for it.
  defp slow(text, extra \\ []) do
    rig = rig(configured(text), Keyword.merge([steps: Slow], extra))
    :ets.insert(__MODULE__, {rig.runner, rig.clock})
    :ets.insert(__MODULE__, {{rig.runner, :sims}, [rig.drive, rig.panel]})
    rig
  end

  defp seen(runner), do: :ets.lookup_element(__MODULE__, {runner, :seen}, 2)

  describe "the watchdogs (decisions 110, 111, 126 and 128)" do
    test "a timed task's run that outlasts its watchdog trips before its round's write, " <>
           "naming it; one that takes exactly its watchdog does not" do
      text =
        "task fast interval 10 priority 1 watchdog 50\nvar_global x bool at panel.i.0\n" <>
          "var_global fast_ms dint at panel.i.1\nvar_global y bool at panel.q.0\n" <>
          "program r relay with fast\n  r.in x\n  r.out y\n"

      %{runner: runner, clock: clock, panel: panel} = slow(text)
      Runner.subscribe(runner)
      Sim.set(panel, [1], 50)
      Manual.advance(clock, 10)
      assert %{status: :running, runs: %{"fast" => {50, 50}}} = Runner.status(runner)

      # The next round, late, takes 51 ms: y = 1 is computed and never written.
      Sim.set(panel, %{[0] => 1, [1] => 51})
      Manual.advance(clock, 50)
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:task, "fast", 51, 50}}}}
      assert Runner.status(runner).trip == {:watchdog, {:task, "fast", 51, 50}}
      assert Runner.get!(runner, "y") == 1
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert Runner.status(runner).runs["fast"] == {51, 50}
    end

    test "an event task's run is watched as a periodic one's" do
      text =
        "task e single t priority 0 watchdog 20\nvar_global t bool at panel.i.0\n" <>
          "var_global e_ms dint at panel.i.1\nvar_global hits dint at panel.q.0\n" <>
          "program c count with e\n  c.n hits\n"

      %{runner: runner, panel: panel} = slow(text)
      Sim.set(panel, [1], 20)
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).status == :running
      Sim.set(panel, %{[0] => 0, [1] => 21})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).trip == {:watchdog, {:task, "e", 21, 20}}
      assert Runner.get!(runner, "hits") == 2
      assert List.last(Sim.writes(panel)) == %{[0] => 0}
    end

    test "a round that outlasts the continuous task's watchdog trips, naming each step " <>
           "with its time, a slow timed task's among them; one of exactly it does not" do
      text =
        "task main continuous watchdog 200\ntask fan interval 1000 priority 2 watchdog 2000\n" <>
          "var_global fan_ms dint at panel.i.0\nvar_global main_ms dint at panel.i.1\n" <>
          "var_global a dint\nvar_global b dint\n" <>
          "program f count with fan\n  f.n a\nprogram m count\n  m.n b\n"

      %{runner: runner, clock: clock, panel: panel} = slow(text)
      Sim.set(panel, [0], 150)
      Manual.advance(clock, 999)
      Sim.set(panel, [1], 50)

      # At 1000 the fan's run, 150 ms, and the box counter's, 50, make the round's 200.
      # A round is owed, so a host's call would wait for the share's slot: the runner's
      # state is read through :sys.
      Manual.advance(clock, 1)

      assert %{status: :running, longest: %{"main" => 200, "fan" => 150}} =
               :sys.get_state(runner)

      # Back to back, 50 ms a round, to 2000, where the fan's run takes 151.
      Sim.set(panel, [0], 151)
      Manual.advance(clock, 800)

      assert Runner.status(runner).trip ==
               {:watchdog, {:round, "main", 201, 200, [{"fan", 151}, {"main", 50}]}}

      assert Runner.status(runner).now == 2000
    end

    test "a round where no continuous task is declared is named :none, 500 ms" do
      text =
        "task fan interval 1000 priority 2\nvar_global none_ms dint at panel.i.0\n" <>
          "var_global b dint\nprogram m count\n  m.n b\n"

      %{runner: runner, clock: clock, panel: panel} = slow(text)
      Sim.set(panel, [0], 500)
      Manual.advance(clock, 1)
      assert :sys.get_state(runner).status == :running
      Sim.set(panel, [0], 501)
      Manual.advance(clock, 0)
      assert Runner.status(runner).trip == {:watchdog, {:round, :none, 501, 500, [{:none, 501}]}}
    end

    test "a host's request served whole that takes longer than the idle watchdog trips " <>
           "once answered; a restart is not timed by it" do
      start = fn idle ->
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: configured(),
            io: %{"panel" => {Sim, sim: panel}},
            clock: {Ticks, {clock, 3}},
            poll: 1_000_000,
            idle: idle
          )

        runner
      end

      runner = start.(3)
      assert Runner.get(runner, "x") == {:ok, 0}
      assert Runner.status(runner).status == :running

      runner = start.(2)
      assert Runner.get(runner, "x") == {:ok, 0}
      assert Runner.status(runner).trip == {:watchdog, {:idle, 3}}
      assert Runner.restart(runner, :cold) == :ok
      assert Runner.status(runner).status == :running
    end
  end

  # The conveyor on its 50 ms watchdog, with the panel and the drive: y on the panel, z
  # on the drive, each its output, and the input that says how long its step is stuck.
  @conveyor """
  task fast interval 10 priority 1 watchdog 50

  var_global x          bool at panel.i.0
  var_global fast_stuck dint at panel.i.1
  var_global fast_ms    dint at panel.i.2
  var_global y          bool at panel.q.0
  var_global z          bool at drive.q.0

  program r relay with fast
    r.in  x
    r.out y

  program s relay with fast
    s.in  x
    s.out z
  """

  describe "each device's deadline, carried by every refresh (decision 125)" do
    test "a runner stuck in the conveyor's 50 ms step leaves every device at 0 within 50 " <>
           "ms and a poll period of the step's start, not before" do
      for {stuck, zeroed} <- [{59, false}, {60, true}] do
        %{runner: runner, clock: clock, panel: panel, drive: drive} =
          slow(@conveyor, poll: 10)

        Sim.set(panel, [0], 1)
        Manual.advance(clock, 600)
        assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}

        # The step at 610 is stuck, the devices polled and their deadlines met meanwhile:
        # each device's one wake has moved on, at 560, to the idle watchdog's deadline then,
        # 1060, and the step's refresh brings it sooner, to 670.
        Sim.set(panel, [1], stuck)
        Manual.advance(clock, 10)
        [drive_seen, panel_seen] = seen(runner)

        assert {List.last(drive_seen), List.last(panel_seen)} ==
                 {%{[0] => b(not zeroed)}, %{[0] => b(not zeroed)}}

        # Either way the step outlasted its watchdog, and the runner trips once it is back,
        # each device written 0 once, by its latch or by the trip, and nothing after.
        assert Runner.status(runner).trip == {:watchdog, {:task, "fast", stuck, 50}}
        Manual.advance(clock, 1000)
        assert [%{[0] => 0}, %{[0] => 1} | _] = Enum.reverse(Sim.writes(panel))
        assert [%{[0] => 0}, %{[0] => 1} | _] = Enum.reverse(Sim.writes(drive))
      end
    end

    test "a step that takes exactly its watchdog leaves a poll period's margin: no " <>
           "device latches, and the runner runs on" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} = slow(@conveyor, poll: 10)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.set(panel, [1], 50)
      Manual.advance(clock, 10)
      [drive_seen, panel_seen] = seen(runner)
      assert {List.last(drive_seen), List.last(panel_seen)} == {%{[0] => 1}, %{[0] => 1}}
      Sim.set(panel, [1], 0)
      Manual.advance(clock, 1000)
      assert %{status: :running, runs: %{"fast" => {50, 50}}} = Runner.status(runner)
      refute %{[0] => 0} in Enum.drop(Sim.writes(panel), 2)
      refute %{[0] => 0} in Enum.drop(Sim.writes(drive), 2)
    end

    test "a runner stuck in its own work leaves every device at 0 within its idle " <>
           "watchdog and a poll period, and trips when it next runs, before any round" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), poll: 10, idle: 100, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 20)
      %{rounds: rounds} = Runner.status(runner)

      # Its last refresh, the write's at 20, carried 20 + 100 + 10.
      :sys.suspend(runner)
      Manual.advance(clock, 109)

      assert {List.last(Sim.writes(panel)), List.last(Sim.writes(drive))} ==
               {%{[0] => 1}, %{[0] => 1}}

      Manual.advance(clock, 1)

      assert {List.last(Sim.writes(panel)), List.last(Sim.writes(drive))} ==
               {%{[0] => 0}, %{[0] => 0}}

      # Its wakes waited in its mailbox; it trips on the first device's notice, the drive's,
      # the first in device-name order, and runs no round.
      :sys.resume(runner)
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, "drive", 110}}}}, 5000
      assert %{status: :tripped, rounds: ^rounds} = Runner.status(runner)
      assert [%{[0] => 0}, %{[0] => 1} | _] = Enum.reverse(Sim.writes(panel))
      assert [%{[0] => 0}, %{[0] => 1} | _] = Enum.reverse(Sim.writes(drive))
      refute_received {Runner, ^runner, {:trip, _}}
    end

    test "a device's wake that comes before the deadline its last refresh carried moves " <>
           "on to it, the device latching at its deadline's millisecond, not one before" do
      text =
        "var_global x bool at panel.i.0\nvar_global y bool at panel.q.0\n" <>
          "program r relay\n  r.in x\n  r.out y\n"

      %{runner: runner, clock: clock, panel: panel} =
        rig(configured(text), poll: 10, idle: 100, steps: Runtime)

      # The round at 0 carried 110, the panel's wake set there; the round at 1, writing
      # y = 1, carried 111, a later deadline, which keeps that wake.
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 1)
      :sys.suspend(runner)
      Manual.advance(clock, 109)
      assert List.last(Sim.writes(panel)) == %{[0] => 1}
      Manual.advance(clock, 1)
      zeroed_once(panel, 1)
      :sys.resume(runner)
      assert Runner.status(runner).trip == {:watchdog, {:device, "panel", 110}}
    end

    test "a poll's write again whose read ends at its deadline's millisecond writes nothing" do
      text =
        "var_global x bool at panel.i.0\nvar_global y bool at panel.q.0\n" <>
          "program r relay\n  r.in x\n  r.out y\n"

      %{runner: runner, clock: clock, panel: panel} =
        rig(configured(text), poll: 10, idle: 100, steps: Runtime)

      # The deadline is 111, as above; the poll at 110 reads for 1 ms, to 111.
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 1)
      :sys.suspend(runner)
      Manual.advance(clock, 99)
      written = length(Sim.writes(panel))
      Sim.fail(panel, :read, {:delay, 1})
      Manual.advance(clock, 10)
      Manual.advance(clock, 1)
      assert Enum.drop(Sim.writes(panel), written) == [%{[0] => 0}]
      :sys.resume(runner)
    end

    test "two devices that latch in one millisecond trip for the first in device-name " <>
           "order, whichever notice comes first" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), poll: 10, idle: 100, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 20)

      # Both deadlines are 130; the drive's process is held, so the panel's notice comes
      # first, and the drive's, raised at 130 too, after it.
      :sys.suspend(runner)
      drive_device = device_pid(runner, "drive")
      :sys.suspend(drive_device)
      Manual.advance(clock, 110)
      assert List.last(Sim.writes(panel)) == %{[0] => 0}
      assert List.last(Sim.writes(drive)) == %{[0] => 1}
      :sys.resume(drive_device)
      :sys.get_state(drive_device)
      zeroed_once(drive, 1)
      :sys.resume(runner)
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, "drive", 110}}}}, 5000
      refute_received {Runner, ^runner, {:trip, _}}

      # And a notice raised sooner comes first, whatever its device's name: the panel's
      # read fails at 30, the drive's at 40, both waiting as the runner comes back.
      read_both = @conveyor <> "var_global d bool at drive.i.0\n"

      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(read_both), poll: 10, steps: Runtime)

      Manual.advance(clock, 20)
      :sys.suspend(runner)
      Sim.fail(panel, :read, {:error, :first})
      Manual.advance(clock, 10)
      Sim.fail(drive, :read, {:error, :second})
      Manual.advance(clock, 10)
      :sys.resume(runner)
      assert Runner.status(runner).trip == {:io, "panel", {:error, :first}}
    end

    test "a restart after a device latched releases it, and its deadline is heard again" do
      %{runner: runner, clock: clock, panel: panel} =
        rig(configured(@conveyor), poll: 10, idle: 100, steps: Runtime)

      Sim.set(panel, [0], 1)
      :sys.suspend(runner)
      Manual.advance(clock, 200)
      :sys.resume(runner)
      assert {:watchdog, {:device, _, 110}} = Runner.status(runner).trip
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 1000)
      assert %{status: :running} = Runner.status(runner)
      assert List.last(Sim.writes(panel)) == %{[0] => 1}

      # And a device that latches after the restart trips it, its notice carrying the
      # count of restarts its release gave it; so does a fault of its own after a second.
      :sys.suspend(runner)
      Manual.advance(clock, 200)
      :sys.resume(runner)
      assert {:watchdog, {:device, _, 110}} = Runner.status(runner).trip
      assert Runner.restart(runner, :cold) == :ok
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "panel", {:error, :eio}}
    end
  end

  # An e-stop's event task, whose round, at once, writes the drive and the panel.
  @stopped """
  task e single t priority 0

  var_global t bool at panel.i.0
  var_global y bool at panel.q.0
  var_global z bool at drive.q.0

  program r relay with e
    r.in  t
    r.out y

  program s relay with e
    s.in  t
    s.out z
  """

  # The conveyor with an input on the drive too, so that both devices are read.
  @read_both @conveyor <> "var_global d bool at drive.i.0\n"

  defp device_pid(runner, name),
    do: :sys.get_state(runner).devices |> List.keyfind(name, 0) |> elem(1)

  # The trip's 0 written once, after the last value, and nothing after.
  defp zeroed_once(sim, last) do
    assert [%{[0] => 0}, %{[0] => ^last} | _] = Enum.reverse(Sim.writes(sim))
  end

  describe "the I/O faults (decision 114)" do
    test "each kind of fault in a poll's read trips, naming its device, every device " <>
           "written 0 once and nothing after" do
      raised = "the simulated device \"drive\" raised in read, as fail/3 told it"

      for {how, cause} <- [
            {{:error, :eio}, {:error, :eio}},
            {:raise, {:raised, raised}},
            {:throw, {:thrown, {Sim, :read}}},
            {:exit, {:exited, {Sim, :read}}},
            {{:value, [0], 7}, {:bad_value, [0], 7}},
            {{:value, [9], 1}, {:unknown_address, [9]}}
          ] do
        %{runner: runner, clock: clock, panel: panel, drive: drive} =
          rig(configured(@read_both), poll: 10, steps: Runtime)

        Runner.subscribe(runner)
        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        Sim.fail(drive, :read, how)
        Manual.advance(clock, 10)
        assert_receive {Runner, ^runner, {:trip, {:io, "drive", ^cause}}}, 5000
        assert Runner.status(runner).trip == {:io, "drive", cause}
        Manual.advance(clock, 100)
        zeroed_once(panel, 1)
        zeroed_once(drive, 1)
        assert Runner.get!(runner, "y") == 1
      end
    end

    test "a report's fault trips, naming its device" do
      %{runner: runner, panel: panel} = rig(configured(@read_both), steps: Runtime)
      Sim.fail(panel, :report, :raise)
      Sim.set(panel, [0], 1)

      assert Runner.status(runner).trip ==
               {:io, "panel",
                {:raised, "the simulated device \"panel\" raised in report, as fail/3 told it"}}
    end

    # Found by M4-6's walk: a device took a change the runner refused as passed on, so a
    # value that does not fit, read again after a restart, was never passed on again and
    # the runner ran on with the last value it took; and a report the runner refused lost
    # the good change beside the bad one for good.
    test "a device that goes on giving a value that does not fit trips the runner again " <>
           "after each restart, and a change refused with it is passed on at the next read" do
      for bad <- [{:value, [0], 2}, {:value, [7], 1}] do
        %{runner: runner, clock: clock, panel: panel} = rig(configured(), poll: 10)
        cause = (bad == {:value, [0], 2} && {:bad_value, [0], 2}) || {:unknown_address, [7]}
        for _ <- 1..3, do: Sim.fail(panel, :read, bad)

        for _ <- 1..3 do
          Manual.advance(clock, 10)
          assert Runner.status(runner).trip == {:io, "panel", cause}
          assert Runner.restart(runner, :cold) == :ok
        end

        # Put right, it is read as it is.
        Manual.advance(clock, 10)
        assert %{status: :running} = Runner.status(runner)
        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "x") == 1
      end

      # A report the runner refuses for a value that does not fit holds a good change
      # beside it, which the next read passes on once the runner is restarted.
      %{runner: runner, clock: clock, panel: panel} = rig(configured(), poll: 10)
      Sim.fail(panel, :report, {:value, [1], 2_147_483_648})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).trip == {:io, "panel", {:bad_value, [1], 2_147_483_648}}
      assert Runner.get!(runner, "x") == 0
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      assert %{status: :running} = Runner.status(runner)
      assert Runner.get!(runner, "x") == 1
    end

    test "a round's write that fails trips, the devices after it not written, and the " <>
           "device that failed zeroed where it still takes a write" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), steps: Runtime)

      Sim.fail(drive, :write, {:error, :eio})
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:error, :eio}}
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 0}]
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert Runner.get!(runner, "y") == 1
    end

    test "a poll's write again that fails trips" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), poll: 10, steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.fail(drive, :write, :throw)
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:thrown, {Sim, :write}}}
      zeroed_once(panel, 1)
      zeroed_once(drive, 1)
    end

    test "a result the behaviour does not give is a raise, in its words; a close that " <>
           "fails is passed over" do
      {:ok, clock} = Manual.start_link()

      config =
        configured(
          "task fast interval 10 priority 1\nvar_global x bool at panel.i.0\n" <>
            "var_global y bool at panel.q.0\nprogram r relay with fast\n  r.in x\n  r.out y\n"
        )

      start = fn read ->
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {BadIO, read: read}},
          clock: {Manual, clock}
        )
      end

      assert start.(:bad) ==
               {:error,
                {:io_init, "panel",
                 {:raised,
                  "Logex.TripTest.BadIO.read/1 gave :nope, which is none of Logex.IO's results"}}}

      {:ok, runner} = start.(:good)
      assert Runner.stop(runner) == :ok
    end

    test "a device that does not answer a round's write within its deadline is killed, " <>
           "the deadline in real time and short, and opened again at a restart" do
      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(@stopped), idle: 30, poll: 10, steps: Runtime)

      # The e-stop's round, at once, writes the drive, which hangs: the runner waits its
      # deadline, 30 ms and a poll period, in real time on the manual clock.
      old = device_pid(runner, "drive")
      Sim.fail(drive, :write, :hang)
      {took, :ok} = :timer.tc(fn -> Sim.set(panel, [0], 1) end, :millisecond)
      assert took >= 40 and took < 2000
      assert Runner.status(runner).trip == {:io, "drive", :timeout}
      refute Process.alive?(old)

      # Its outputs are left to the device; every other device is zeroed.
      assert Sim.writes(drive) == [%{[0] => 0}]
      zeroed_once(panel, 0)

      assert Runner.restart(runner, :cold) == :ok
      assert device_pid(runner, "drive") != old
      assert Sim.outputs(drive) == %{[0] => 1}
      assert Runner.status(runner).status == :running
    end

    test "an answer later than the deadline on the runner's clock is no answer, the " <>
           "device that gave it written its 0 by the trip" do
      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(@stopped), poll: 10, steps: Runtime)

      old = device_pid(runner, "drive")
      Sim.fail(drive, :write, {:delay, 510})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).trip == {:io, "drive", :timeout}
      assert Process.alive?(old)
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 1}, %{[0] => 0}]
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert Runner.restart(runner, :cold) == :ok
      assert device_pid(runner, "drive") == old

      # One a millisecond sooner is in time.
      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(@stopped), poll: 10, steps: Runtime)

      Sim.fail(drive, :write, {:delay, 509})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).status == :running
    end

    test "a device's process that goes down trips, and is opened again at a restart" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), poll: 10, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      assert_receive {Runner, ^runner, {:trip, {:io, "drive", {:down, :killed}}}}, 5000
      zeroed_once(panel, 1)
      assert List.last(Sim.writes(drive)) == %{[0] => 1}

      assert Runner.restart(runner, :warm) == :ok
      assert Process.alive?(device_pid(runner, "drive"))
      Manual.advance(clock, 10)
      assert Runner.status(runner).status == :running

      # Opened again with the restart's count, its own fault after it trips the runner.
      Sim.fail(drive, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:error, :eio}}
    end

    test "a device that cannot be opened at a restart leaves the runner tripped, and a " <>
           "restart after it opens it" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      Runner.status(runner)
      Sim.fail(drive, :init, {:error, :refused})
      assert Runner.restart(runner, :cold) == {:error, {:io_init, "drive", :refused}}
      assert Runner.status(runner).trip == {:io, "drive", {:down, :killed}}
      assert Runner.restart(runner, :cold) == :ok
      assert Sim.outputs(drive) == %{[0] => 1}
    end

    test "a device that cannot be opened at a restart gives the restart its own reason, " <>
           "whatever it is" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      Runner.status(runner)

      for reason <- [:unplugged, {:no_route, 3}] do
        Sim.fail(drive, :init, {:error, reason})
        assert Runner.restart(runner, :warm) == {:error, {:io_init, "drive", reason}}
        assert Runner.status(runner).trip == {:io, "drive", {:down, :killed}}
      end
    end

    test "a device hung inside its own read, its outputs unchanged, trips {:io, device, " <>
           ":timeout} once not heard within the idle watchdog and a poll period, killed" do
      relays =
        "var_global x bool at panel.i.0\nvar_global d bool at drive.i.0\n" <>
          "var_global y bool at panel.q.0\nvar_global z bool at drive.q.0\n" <>
          "program r relay\n  r.in x\n  r.out y\nprogram s relay\n  s.in d\n  s.out z\n"

      # Seen as a round begins, each millisecond where untimed programs run, and at a
      # wait's refresh, each poll period, where a task's rounds are ten seconds apart.
      slow = String.replace(relays, "relay\n", "relay with slow\n")
      slow = "task slow interval 10000 priority 1\n" <> slow

      for {text, seen_in} <- [{relays, 1}, {slow, 10}] do
        %{runner: runner, clock: clock, panel: panel, drive: drive} =
          rig(configured(text), poll: 10, idle: 1000, steps: Runtime)

        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10_000)

        # The drive's process held after its read at 10,000, as one hung in its next read
        # is: heard then, it is silent from 11,011, the idle watchdog and a poll period on.
        old = device_pid(runner, "drive")
        :sys.suspend(old)
        drive_written = Sim.writes(drive)
        Manual.advance(clock, 1010)
        assert %{status: :running, rounds: rounds} = :sys.get_state(runner)
        {took, :ok} = :timer.tc(fn -> Manual.advance(clock, seen_in) end, :millisecond)

        assert %{status: :tripped, trip: {:io, "drive", :timeout}, rounds: ^rounds} =
                 Runner.status(runner)

        # Killed at once, not waited on for its 0: its outputs are left to it.
        assert took < 500
        refute Process.alive?(old)
        zeroed_once(panel, 1)
        assert Sim.writes(drive) == drive_written

        # Opened again at a restart, two seconds on, and heard from its opening.
        Manual.advance(clock, 2000)
        assert Runner.restart(runner, :cold) == :ok
        Manual.advance(clock, 1100)
        assert Runner.status(runner).status == :running
      end
    end

    test "a device hung inside its own read trips on the real clock, short" do
      text =
        "task fast interval 10 priority 1\nvar_global x bool at panel.i.0\n" <>
          "var_global d bool at drive.i.0\nvar_global y bool at panel.q.0\n" <>
          "program r relay with fast\n  r.in x\n  r.out y\n"

      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(text),
          poll: 10,
          idle: 50,
          steps: Runtime,
          clock: {Logex.Runner.Clock.Monotonic, nil}
        )

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      assert written(panel, 200) == %{[0] => 1}
      Sim.fail(drive, :read, :hang)
      assert_receive {Runner, ^runner, {:trip, {:io, "drive", :timeout}}}, 2000
      zeroed_once(panel, 1)
      Runner.stop(runner)
    end

    test "a device waiting on the runner for its change is heard at each poll meanwhile, " <>
           "on the real clock, short" do
      text =
        "task e1 single t1 priority 0 watchdog 1000\ntask e2 single t2 priority 1\n" <>
          "var_global t1 bool at panel.i.0\nvar_global t2 bool at panel.i.1\n" <>
          "var_global y bool at panel.q.0\nvar_global hits dint\n" <>
          "program a count with e1\n  a.n hits\nprogram b relay with e2\n  b.in t2\n  b.out y\n"

      {:ok, panel} = Sim.start_link(reports: true)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text),
          io: %{"panel" => {Sim, sim: panel}},
          poll: 10,
          idle: 50,
          steps: Sleeps
        )

      # One report changes both triggers: e1's round sleeps 200 ms while the panel waits,
      # and e2's round, at once after it, finds the panel heard.
      Sim.set(panel, %{[0] => 1, [1] => 1})
      assert %{status: :running, trip: nil} = Runner.status(runner)
      assert Runner.get!(runner, "y") == 1
      Runner.stop(runner)
    end

    test "a device whose round's write is answered in time is heard then" do
      text =
        "task e1 single t1 priority 0\ntask e2 single t2 priority 1\n" <>
          "var_global t1 bool at panel.i.0\nvar_global t2 bool at panel.i.1\n" <>
          "var_global z bool at drive.q.0\nvar_global hits dint\n" <>
          "program a relay with e1\n  a.in t1\n  a.out z\nprogram b count with e2\n  b.n hits\n"

      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(text), poll: 10, idle: 100, steps: Runtime)

      # The drive last read at 20; at 29 one report changes both triggers. e1's round
      # writes the drive, which takes 105 ms, answered at 134, within its deadline, 139;
      # e2's round begins at 134, the drive heard at 134, not at 20.
      Manual.advance(clock, 29)
      Sim.fail(drive, :write, {:delay, 105})
      Sim.set(panel, %{[0] => 1, [1] => 1})
      assert %{status: :running, trip: nil, now: 134} = Runner.status(runner)
      assert Runner.get!(runner, "hits") == 1
      assert List.last(Sim.writes(drive)) == %{[0] => 1}
    end

    test "a device that hangs while the runner is tripped is killed at the restart's " <>
           "release and opened again, its inputs read, the deadline in real time and short" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), poll: 10, idle: 30, steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert {:io, "panel", {:error, :eio}} = Runner.status(runner).trip

      # The drive's process held, as one hung in its adapter is, and its stop pressed.
      old = device_pid(runner, "drive")
      :sys.suspend(old)
      Sim.set(drive, [0], 1)
      assert Runner.restart(runner, :cold) == :ok
      refute Process.alive?(old)
      assert device_pid(runner, "drive") != old
      assert %{status: :running, trip: nil} = Runner.status(runner)
      assert Runner.get!(runner, "d") == 1
      refute MapSet.member?(:sys.get_state(runner).down, "drive")
    end

    test "a device that cannot be opened again after the others' release latches them " <>
           "again, each written 0 once more, a released one and one opened again alike" do
      # The panel released, the drive killed while tripped and refused at its opening.
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), poll: 10, steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      Runner.status(runner)
      Sim.fail(drive, :init, {:error, :refused})
      written = Sim.writes(panel)
      assert Runner.restart(runner, :cold) == {:error, {:io_init, "drive", :refused}}
      assert :sys.get_state(device_pid(runner, "panel")).latched
      Manual.advance(clock, 100)
      assert Sim.writes(panel) == written ++ [%{[0] => 0}]
      assert Runner.status(runner).trip == {:io, "panel", {:error, :eio}}

      # The drive opened again, the panel then held and refused: the drive is written 0.
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), poll: 10, idle: 30, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      assert_receive {Runner, ^runner, {:trip, {:io, "drive", {:down, :killed}}}}, 5000
      assert List.last(Sim.writes(drive)) == %{[0] => 1}
      :sys.suspend(device_pid(runner, "panel"))
      Sim.fail(panel, :init, {:error, :refused})
      assert Runner.restart(runner, :cold) == {:error, {:io_init, "panel", :refused}}
      zeroed_once(drive, 1)
      assert Runner.status(runner).trip == {:io, "drive", {:down, :killed}}
    end

    test "a device latched by its own fault while a round runs takes no write of that " <>
           "round's" do
      # The drive polls every 7 ms, at 21 inside the round at 20, which is stuck 30 ms.
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        slow(@conveyor <> "var_global d bool at drive.i.0\n", poll: 7)

      Manual.advance(clock, 15)
      Sim.set(panel, %{[0] => 1, [1] => 30})
      Sim.fail(drive, :read, {:error, :eio})
      Manual.advance(clock, 5)

      # The round computed z = 1 and wrote the panel; the drive, latched at 21, took
      # nothing, and the runner tripped on its notice as the next round began.
      assert Runner.get!(runner, "z") == 1
      zeroed_once(panel, 1)
      assert List.last(Sim.writes(drive)) == %{[0] => 0}
      refute %{[0] => 1} in Sim.writes(drive)
      assert Runner.status(runner).trip == {:io, "drive", {:error, :eio}}
    end

    test "of two faults in one read, the first address's is named" do
      # Forty inputs, more than a small map holds in order.
      points = for k <- 0..39, do: "var_global i#{k} bool at dev.i.#{k}\n"

      config =
        configured(
          Enum.join(points) <> "var_global o bool\nprogram r relay\n  r.in i0\n  r.out o\n"
        )

      values = Map.new(0..39, &{[&1], 0})
      {:ok, clock} = Manual.start_link()

      for {bad, first} <- [
            {%{[3] => 7, [31] => 9}, {:bad_value, [3], 7}},
            {%{[17] => 2, [40] => 1}, {:bad_value, [17], 2}},
            {%{[39] => 5, [41] => 1}, {:bad_value, [39], 5}}
          ] do
        assert Runner.start_link(
                 configuration: config,
                 io: %{"dev" => {Values, values: Map.merge(values, bad)}},
                 clock: {Manual, clock}
               ) == {:error, {:io_init, "dev", first}}
      end
    end

    test "a device's zero at a trip is given the idle watchdog and a poll period to answer" do
      text = @relayed <> "var_global z bool at drive.q.0\n"
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text),
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock},
          poll: 200,
          idle: 200,
          steps: Boom
        )

      # The drive's zero sleeps 300 ms in real time, within 200 and 200.
      old = device_pid(runner, "drive")
      Sim.fail(drive, :write, {:delay, 300})
      Sim.set(panel, [1], 5)
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:internal, "boom in the outputs"}
      assert Process.alive?(old)
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 0}]
    end

    test "a device opened again at a restart whose first read does not fit leaves the " <>
           "runner tripped" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "drive"), :kill)
      assert_receive {Runner, ^runner, {:trip, {:io, "drive", {:down, :killed}}}}, 5000
      Sim.fail(drive, :read, {:value, [0], 7})

      assert Runner.restart(runner, :cold) ==
               {:error, {:io_init, "drive", {:bad_value, [0], 7}}}

      assert Runner.status(runner).trip == {:io, "drive", {:down, :killed}}
    end

    test "a device that cannot be opened at start, for each kind of fault, every device " <>
           "opened before it closed" do
      raised = "the simulated device \"panel\" raised in init, as fail/3 told it"

      for {callback, how, reason} <- [
            {:init, {:error, :refused}, :refused},
            {:init, :raise, {:raised, raised}},
            {:init, :exit, {:exited, {Sim, :init}}},
            {:init, :hang, :timeout},
            {:read, {:error, :eio}, {:error, :eio}},
            {:read, {:value, [0], 2}, {:bad_value, [0], 2}},
            {:read, {:value, [7], 0}, {:unknown_address, [7]}}
          ] do
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)
        {:ok, drive} = Sim.start_link(clock: clock)
        Sim.fail(panel, callback, how)

        assert Runner.start_link(
                 configuration: configured(@read_both),
                 io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
                 clock: {Manual, clock},
                 idle: 300
               ) == {:error, {:io_init, "panel", reason}}

        assert Sim.closed?(drive)
      end
    end

    test "a runner whose clock goes down stops, a shutdown, every device zeroed and closed" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      ref = Process.monitor(runner)
      Process.flag(:trap_exit, true)
      Process.unlink(clock)
      Process.exit(clock, :kill)

      assert_raise ArgumentError, ~r/is not running/, fn -> Runner.status(runner) end
      assert_receive {:DOWN, ^ref, :process, ^runner, {:shutdown, {:clock, _reason}}}, 5000
      zeroed_once(panel, 1)
      zeroed_once(drive, 1)
      assert Sim.closed?(panel) and Sim.closed?(drive)
    end

    test "a clock that exits as it is read stops the runner, a shutdown" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@relayed),
          io: %{"panel" => {Sim, sim: panel}},
          clock: {GoneClock, {clock, 5}},
          poll: 1_000_000
        )

      ref = Process.monitor(runner)
      Process.flag(:trap_exit, true)
      Manual.advance(clock, 10)
      assert_receive {:DOWN, ^ref, :process, ^runner, {:shutdown, {:clock, :gone}}}, 5000
    end

    test "a device whose own read fails zeroes itself at once, whatever the runner does" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), poll: 10, steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      :sys.suspend(runner)
      Sim.fail(drive, :read, {:error, :eio})
      Manual.advance(clock, 10)
      zeroed_once(drive, 1)
      assert List.last(Sim.writes(panel)) == %{[0] => 1}
      :sys.resume(runner)
      assert Runner.status(runner).trip == {:io, "drive", {:error, :eio}}
      zeroed_once(panel, 1)
    end

    test "a fault while tripped changes no reason" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), poll: 10, steps: Runtime)

      Sim.fail(drive, :read, {:error, :first})
      Manual.advance(clock, 10)
      Sim.fail(panel, :read, {:error, :second})
      Manual.advance(clock, 10)
      Process.exit(device_pid(runner, "panel"), :kill)
      assert Runner.status(runner).trip == {:io, "drive", {:error, :first}}
    end
  end

  # A stand-in whose event task's step waits, on the real clock, until the panel has
  # written its 0 or two seconds have passed, and records which in the table.
  defmodule Waits do
    def cycle_steps(runtime, elapsed, inputs), do: Runtime.cycle_steps(runtime, elapsed, inputs)
    def cycle_outputs(runtime), do: Runtime.cycle_outputs(runtime)

    def cycle_step(runtime, {:timed, "e", _run} = step) do
      [{_key, panel}] = :ets.lookup(Logex.TripTest, {self(), :panel})
      :ets.insert(Logex.TripTest, {{self(), :seen}, zero(panel, 200)})
      Runtime.cycle_step(runtime, step)
    end

    def cycle_step(runtime, step), do: Runtime.cycle_step(runtime, step)

    defp zero(_panel, 0), do: :never
    defp zero(panel, tries), do: zeroed(List.last(Sim.writes(panel)), panel, tries)

    defp zeroed(%{[0] => 0}, _panel, _tries), do: :zeroed

    defp zeroed(_last, panel, tries) do
      Process.sleep(10)
      zero(panel, tries - 1)
    end
  end

  # The panel's outputs once the runner has written y = 1, on the real clock.
  defp written(_panel, 0), do: :never
  defp written(panel, tries), do: written(Sim.outputs(panel), panel, tries)

  defp written(%{[0] => 1} = outputs, _panel, _tries), do: outputs

  defp written(_outputs, panel, tries) do
    Process.sleep(10)
    written(panel, tries - 1)
  end

  describe "a device waiting on the runner for its own change (decision 124)" do
    # On the real clock, short: the panel's change makes a round at once, whose step is
    # stuck while the panel waits for the runner's answer; the panel hears its deadline,
    # 20 ms and a poll period, there, and zeroes itself.
    test "latches on its deadline while it waits" do
      text =
        "task e single t priority 0 watchdog 20\nvar_global t bool at panel.i.0\n" <>
          "var_global y bool at panel.q.0\nvar_global w bool at panel.i.1\n" <>
          "program r relay with fast\n  r.in w\n  r.out y\ntask fast interval 10 priority 1\n"

      {:ok, panel} = Sim.start_link(reports: true)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text),
          io: %{"panel" => {Sim, sim: panel}},
          poll: 10,
          steps: Waits
        )

      :ets.insert(__MODULE__, {{runner, :panel}, panel})
      Sim.set(panel, [1], 1)
      assert written(panel, 200) == %{[0] => 1}
      Sim.set(panel, [0], 1)
      assert :ets.lookup_element(__MODULE__, {runner, :seen}, 2) == :zeroed
      assert {:watchdog, {:task, "e", _took, 20}} = Runner.status(runner).trip
      Runner.stop(runner)
    end
  end

  describe "the runner's death (decision 115)" do
    # Each device's process goes down with its runner, which is logged.
    @tag :capture_log
    test "a killed runner's devices write every output 0 once and close" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), steps: Runtime)

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      devices = for name <- ["drive", "panel"], do: Process.monitor(device_pid(runner, name))
      Process.flag(:trap_exit, true)
      Process.exit(runner, :kill)
      assert_receive {:EXIT, ^runner, :killed}, 5000
      for ref <- devices, do: assert_receive({:DOWN, ^ref, :process, _pid, :killed}, 5000)

      zeroed_once(panel, 1)
      zeroed_once(drive, 1)
      assert Sim.closed?(panel) and Sim.closed?(drive)
    end

    @tag :capture_log
    test "a tripped runner killed closes its devices and writes no 0 again" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@relayed <> "var_global z bool at drive.q.0\n"))

      Sim.set(panel, %{[0] => 1, [1] => 5})
      Manual.advance(clock, 10)
      zeroed = {Sim.writes(panel), Sim.writes(drive)}
      devices = for name <- ["drive", "panel"], do: Process.monitor(device_pid(runner, name))
      Process.flag(:trap_exit, true)
      Process.exit(runner, :kill)
      for ref <- devices, do: assert_receive({:DOWN, ^ref, :process, _pid, :killed}, 5000)
      assert {Sim.writes(panel), Sim.writes(drive)} == zeroed
      assert Sim.closed?(panel) and Sim.closed?(drive)
    end

    test "a stop while a device waits on the runner for its change zeroes and closes it " <>
           "once, the change a report's or a poll's" do
      text =
        "task fast interval 10 priority 1\nvar_global x bool at panel.i.0\n" <>
          "var_global w dint at panel.i.2\nvar_global y bool at panel.q.0\n" <>
          "program r relay with fast\n  r.in x\n  r.out y\n"

      for {reports, poll} <- [{true, 1_000_000}, {false, 10}] do
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(reports: reports, clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: configured(text),
            io: %{"panel" => {Closes, sim: panel}},
            clock: {Manual, clock},
            poll: poll
          )

        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        assert List.last(Sim.writes(panel)) == %{[0] => 1}

        # The runner held, the panel's change waits in its mailbox, the panel waiting on
        # it, the change reported as it is set or read at the poll at 20; the stop is
        # served all the same, and closes the panel while it waits.
        :sys.suspend(runner)
        spawn(fn -> Sim.set(panel, [2], 5) end)
        spawn(fn -> Manual.advance(clock, 10) end)
        waiting(runner)
        assert Runner.stop(runner) == :ok
        zeroed_once(panel, 1)
        assert :ets.lookup_element(__MODULE__, {:closes, panel}, 2) == 1
      end
    end

    @tag :capture_log
    test "a runner that crashes in a round a device's change made zeroes and closes that " <>
           "device once" do
      text =
        "task e single t priority 0\nvar_global t bool at panel.i.0\n" <>
          "var_global boom dint at panel.i.1\nvar_global x bool at panel.i.2\n" <>
          "var_global y bool at panel.q.0\nprogram r relay with e\n  r.in x\n  r.out y\n"

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(text),
          io: %{"panel" => {Closes, sim: panel}},
          clock: {Manual, clock},
          poll: 1_000_000,
          steps: Garbage
        )

      Process.unlink(runner)
      ref = Process.monitor(runner)
      Sim.set(panel, %{[1] => 6, [2] => 1})
      Sim.set(panel, [0], 1)
      assert_receive {:DOWN, ^ref, :process, ^runner, {:function_clause, _stack}}, 5000
      assert Sim.closed?(panel)
      # The first round's 0, its relay not run, and the close's, once.
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert :ets.lookup_element(__MODULE__, {:closes, panel}, 2) == 1
    end

    test "a device that was never opened is neither zeroed nor closed as it stops" do
      {:ok, clock} = Manual.start_link()

      config =
        configured(
          "task fast interval 10 priority 1\nvar_global y bool at panel.q.0\n" <>
            "var_global x bool\nprogram r relay with fast\n  r.in x\n  r.out y\n"
        )

      assert Runner.start_link(
               configuration: config,
               io: %{"panel" => {RefusingIO, test: self()}},
               clock: {Manual, clock}
             ) == {:error, {:io_init, "panel", {:refused, self()}}}

      refute_received {:written, _values}
      refute_received :closed
    end

    # The device's process goes down as its adapter's close raises, which is logged.
    @tag :capture_log
    test "a close that raises is passed over, and no 0 is written again as the device stops" do
      %{runner: runner, clock: clock, panel: panel} = rig(configured(@conveyor), steps: Runtime)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.fail(panel, :close, :raise)
      assert Runner.stop(runner) == :ok
      zeroed_once(panel, 1)
    end

    @tag :capture_log
    test "a runner that crashes zeroes and closes every device, and its supervisor does " <>
           "not start it again" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      opts = [
        configuration: configured(),
        io: %{"panel" => {Sim, sim: panel}},
        clock: {Manual, clock},
        steps: Garbage
      ]

      {:ok, supervisor} = Supervisor.start_link([{Runner, opts}], strategy: :one_for_one)
      [{Runner, runner, :worker, [Runner]}] = Supervisor.which_children(supervisor)
      ref = Process.monitor(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.set(panel, [1], 6)
      Manual.advance(clock, 10)
      assert_receive {:DOWN, ^ref, :process, ^runner, {:function_clause, _stack}}, 5000
      zeroed_once(panel, 1)
      assert Sim.closed?(panel)
      assert Supervisor.which_children(supervisor) == []
    end
  end

  describe "growth" do
    # d devices, each with one output the relay drives, and the panel's `boom`.
    defp crowd(d) do
      outputs = for k <- 1..d, do: "var_global y#{k} bool at dev#{k}.q.0\n"

      relays =
        for k <- 1..d, do: "program r#{k} relay with fast\n  r#{k}.in x\n  r#{k}.out y#{k}\n"

      configured(
        "task fast interval 10 priority 1\nvar_global x bool at panel.i.0\n" <>
          "var_global boom dint at panel.i.1\n" <> Enum.join(outputs) <> Enum.join(relays)
      )
    end

    # The runner's reductions over the round that trips, every device zeroed.
    defp trip_cost(d) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      io =
        Map.new(1..d, fn k ->
          {:ok, sim} = Sim.start_link(clock: clock)
          {"dev#{k}", {Sim, sim: sim}}
        end)

      {:ok, runner} =
        Runner.start_link(
          configuration: crowd(d),
          io: Map.put(io, "panel", {Sim, sim: panel}),
          clock: {Manual, clock},
          poll: 1_000_000,
          steps: Boom
        )

      Sim.set(panel, [1], 5)
      {:reductions, before} = Process.info(runner, :reductions)
      Manual.advance(clock, 10)
      {:reductions, later} = Process.info(runner, :reductions)
      {:internal, _message} = Runner.status(runner).trip
      Runner.stop(runner)
      later - before
    end

    test "a trip's work is linear in the devices" do
      ratio = trip_cost(32) / trip_cost(8)
      assert ratio < @trip_bound, "4x the devices took #{Float.round(ratio, 2)}x"
    end
  end

  defp b(true), do: 1
  defp b(false), do: 0

  describe "restart/2 (decision 113)" do
    test "cold and warm each release the latches, restart the resource and run the " <>
           "first round at once, the clock not counting the stopped time" do
      for mode <- [:cold, :warm] do
        %{runner: runner, clock: clock, panel: panel} = rig()
        Runner.subscribe(runner)
        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "runs") == 2
        Sim.set(panel, [1], 5)
        Manual.advance(clock, 10)
        assert %{status: :tripped, now: 20, rounds: 2} = Runner.status(runner)

        # Stopped for a second; the input that tripped it is put right meanwhile.
        Manual.advance(clock, 1000)
        Sim.set(panel, [1], 0)
        assert Runner.restart(runner, mode) == :ok
        assert_receive {Runner, ^runner, {:restart, ^mode}}

        # The first round has run: no time counted, the input image kept, every other
        # global at its initial value, and its outputs written.
        assert %{status: :running, trip: nil, now: 20, rounds: 3, refresh_gap: gap} =
                 Runner.status(runner)

        assert gap < 1000
        assert Runner.get!(runner, "runs") == 1
        assert Runner.get!(runner, "x") == 1
        assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 1}, %{[0] => 0}, %{[0] => 1}]

        # And the periodic task keeps its grid from there.
        Manual.advance(clock, 9)
        assert Runner.get!(runner, "runs") == 1
        Manual.advance(clock, 1)
        assert %{now: 30, rounds: 4} = Runner.status(runner)
        assert Runner.get!(runner, "runs") == 2
      end
    end

    test "a restart samples again the triggers logic writes, at their initial values" do
      text =
        "task fast interval 10 priority 1\ntask e single t priority 0\n" <>
          "var_global x bool at panel.i.0\nvar_global boom dint at panel.i.1\n" <>
          "var_global t bool\nvar_global hits dint\n" <>
          "program r relay with fast\n  r.in x\n  r.out t\n" <>
          "program c count with e\n  c.n hits\n"

      %{runner: runner, clock: clock, panel: panel} = rig(configured(text))
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 11)
      assert Runner.get!(runner, "hits") == 1
      Sim.set(panel, [1], 5)
      Manual.advance(clock, 9)
      assert Runner.status(runner).status == :tripped
      Sim.set(panel, [1], 0)

      # t is 0 again after the restart, and its round sets it to 1: a change logic wrote,
      # whose round comes at the next millisecond (decision 123) and runs e.
      assert Runner.restart(runner, :cold) == :ok
      assert %{rounds: rounds, now: 20} = Runner.status(runner)
      assert Runner.get!(runner, "hits") == 0
      Manual.advance(clock, 1)
      assert %{rounds: after_one} = Runner.status(runner)
      assert after_one == rounds + 1
      assert Runner.get!(runner, "hits") == 1
    end

    test "a restart's first round writes again nothing written before the trip, a poll " <>
           "inside it among it: a restart is never a resume" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} = slow(@conveyor, poll: 10)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 30)
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert {:io, "panel", {:error, :eio}} = Runner.status(runner).trip
      zeroed_once(panel, 1)
      zeroed_once(drive, 1)
      tripped = {length(Sim.writes(panel)), length(Sim.writes(drive))}

      # x released while tripped, and the restart's first round stuck 15 ms, the devices
      # polled meanwhile with the step's deadline heard: none writes its 1 again, and the
      # round writes its own 0.
      Sim.set(panel, %{[0] => 0, [1] => 15})
      assert Runner.restart(runner, :cold) == :ok
      {panel_at, drive_at} = tripped
      assert Enum.drop(Sim.writes(panel), panel_at) == [%{[0] => 0}]
      assert Enum.drop(Sim.writes(drive), drive_at) == [%{[0] => 0}]
      assert Runner.status(runner).status == :running
    end

    test "a restart that trips again zeroes once more, and once" do
      %{runner: runner, clock: clock, panel: panel} = rig()
      Sim.set(panel, %{[0] => 1, [1] => 5})
      Manual.advance(clock, 10)
      assert Runner.restart(runner, :cold) == :ok
      assert Runner.status(runner).status == :tripped
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}, %{[0] => 0}]
      Manual.advance(clock, 100)
      assert length(Sim.writes(panel)) == 3
    end

    test "a device the trip latched notices its last deadline with the count of restarts " <>
           "from before, so that a restart taken after it does not trip on it" do
      %{runner: runner, clock: clock, panel: panel} =
        rig(configured(@conveyor), poll: 10, idle: 500, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 30)
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert_receive {Runner, ^runner, {:trip, {:io, "panel", {:error, :eio}}}}
      Sim.set(panel, [0], 0)

      # The host's restart waits in the busy runner's mailbox while time passes the
      # latched panel's last deadline; the restart is taken first, and its first round
      # finds no notice from before it.
      :sys.suspend(runner)
      task = Task.async(fn -> Runner.restart(runner, :cold) end)
      restart_waiting(runner)
      Manual.advance(clock, 600)
      :sys.resume(runner)
      assert Task.await(task) == :ok
      assert %{status: :running, trip: nil} = Runner.status(runner)
    end

    test "a restart a trip serves from its queue trips on no notice taken with the one " <>
           "that made the trip, two devices latching in one millisecond" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} = relayed_both()
      Runner.subscribe(runner)

      # The host's restart waits in the stuck runner's mailbox, a round owed, so that it is
      # queued for the share's slot; then both devices latch at their deadline, 111, each
      # notice behind it. The drive's trips the runner, whose trip serves the restart; the
      # panel's, taken with it and raised before that restart's release, trips nothing.
      :sys.suspend(runner)
      task = Task.async(fn -> Runner.restart(runner, :cold) end)
      restart_waiting(runner)
      Manual.advance(clock, 110)
      zeroed_once(panel, 1)
      zeroed_once(drive, 1)
      :sys.resume(runner)
      assert Task.await(task) == :ok
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, "drive", 110}}}}
      assert_receive {Runner, ^runner, {:restart, :cold}}
      assert %{status: :running, trip: nil} = Runner.status(runner)
      Manual.advance(clock, 50)
      assert %{status: :running} = Runner.status(runner)
      refute_received {Runner, ^runner, {:trip, _}}

      assert {List.last(Sim.writes(panel)), List.last(Sim.writes(drive))} ==
               {%{[0] => 1}, %{[0] => 1}}
    end

    test "a restart a trip serves from its queue trips on no notice that came while the " <>
           "trip ran, from a device not yet latched as the trip began" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} = relayed_both()
      Runner.subscribe(runner)

      # As above, but the drive's process is held, so that its wake at 111 waits for it and
      # the panel's notice alone trips the runner. The drive is let go once the trip waits
      # on its zero: it latches at its wake first, its notice coming in as the trip runs,
      # behind the restart the trip serves.
      :sys.suspend(runner)
      task = Task.async(fn -> Runner.restart(runner, :cold) end)
      restart_waiting(runner)
      drive_device = device_pid(runner, "drive")
      :sys.suspend(drive_device)
      Manual.advance(clock, 110)
      zeroed_once(panel, 1)
      :sys.resume(runner)
      zero_waiting(drive_device)
      :sys.resume(drive_device)
      assert Task.await(task) == :ok
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, "panel", 110}}}}
      assert_receive {Runner, ^runner, {:restart, :cold}}
      assert %{status: :running, trip: nil} = Runner.status(runner)
      assert Enum.take(Sim.writes(drive), -3) == [%{[0] => 1}, %{[0] => 0}, %{[0] => 1}]
      Manual.advance(clock, 50)
      assert %{status: :running} = Runner.status(runner)
      refute_received {Runner, ^runner, {:trip, _}}
    end

    test "a restart a trip serves from its queue finds each device heard as late as the " <>
           "notices taken with the trip's say, so that none is taken for hung" do
      %{runner: runner, clock: clock} = relayed_both()
      Runner.subscribe(runner)

      # Both devices latch at 111 and go on reading, each read's "back" waiting in the
      # stuck runner's mailbox to 300; the restart the trip serves runs its first round
      # with each device heard at 300, not at the latch, 189 ms and more before it.
      :sys.suspend(runner)
      task = Task.async(fn -> Runner.restart(runner, :cold) end)
      restart_waiting(runner)
      Manual.advance(clock, 299)
      :sys.resume(runner)
      assert Task.await(task) == :ok
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, _, 110}}}}
      assert_receive {Runner, ^runner, {:restart, :cold}}
      assert %{status: :running, trip: nil} = Runner.status(runner)
      refute_received {Runner, ^runner, {:trip, _}}
    end

    test "its host mistakes, raised in the caller with the runner still alive" do
      %{runner: runner, clock: clock, panel: panel} = rig()

      raises("the runner is running: restart/2 starts a runner again once it has tripped", fn ->
        Runner.restart(runner, :cold)
      end)

      Sim.set(panel, [1], 5)
      Manual.advance(clock, 10)

      for mode <- [:hot, nil, "cold"] do
        raises("a runner restarts :cold or :warm, got: #{inspect(mode)}", fn ->
          Runner.restart(runner, mode)
        end)
      end

      assert Runner.status(runner).status == :tripped

      raises("no runner is running under the name :nobody", fn ->
        Runner.restart(:nobody, :cold)
      end)
    end
  end

  # The relay copying the panel's x to the panel's y and the drive's z, untimed, so that a
  # round is always owed, on a 10 ms poll and a 100 ms idle watchdog; its first rounds
  # written by 1, each device's deadline then 111.
  defp relayed_both do
    text =
      "var_global x bool at panel.i.0\nvar_global y bool at panel.q.0\n" <>
        "var_global z bool at drive.q.0\n" <>
        "program r relay\n  r.in x\n  r.out y\nprogram s relay\n  s.in x\n  s.out z\n"

    rig = rig(configured(text), poll: 10, idle: 100, steps: Runtime)
    Sim.set(rig.panel, [0], 1)
    Manual.advance(rig.clock, 1)
    rig
  end

  # Waits until a trip's zero waits in a held device's mailbox.
  defp zero_waiting(device), do: zero_waited(Process.info(device, :messages), device)

  defp zero_waited({:messages, messages}, device),
    do: zero_found(Enum.any?(messages, &match?({:"$gen_call", _, :zero}, &1)), device)

  defp zero_found(true, _device), do: :ok
  defp zero_found(false, device), do: zero_waiting(device)

  defp flush_traces(device) do
    receive do
      {:trace, ^device, _, _} -> flush_traces(device)
    after
      0 -> :ok
    end
  end

  # Waits until a message waits in the runner's mailbox.
  defp waiting(runner), do: waited(Process.info(runner, :message_queue_len), runner)

  defp waited({:message_queue_len, 0}, runner), do: waiting(runner)
  defp waited(_len, _runner), do: :ok

  # Waits until a host's restart waits in the runner's mailbox.
  defp restart_waiting(runner),
    do: restart_waited(Process.info(runner, :messages), runner)

  defp restart_waited({:messages, messages}, runner),
    do: restart_found(Enum.any?(messages, &match?({:"$gen_call", _, {:restart, _}}, &1)), runner)

  defp restart_found(true, _runner), do: :ok
  defp restart_found(false, runner), do: restart_waiting(runner)

  # Waits until the runner holds a request in its queue.
  defp wait_queued(runner), do: queued(:queue.is_empty(:sys.get_state(runner).queue), runner)

  defp queued(true, runner), do: wait_queued(runner)
  defp queued(false, _runner), do: :ok
end
