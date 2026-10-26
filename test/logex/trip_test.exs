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

  # An adapter over an Agent, `agent:`, holding `inputs` and `next`: each read gives the
  # next of `next`, some points or all, and once none is left the inputs.
  defmodule Partial do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Keyword.fetch!(opts, :agent)}

    @impl true
    def read(agent),
      do: {:ok, Agent.get_and_update(agent, &partial/1), agent}

    defp partial(%{next: [values | rest]} = state), do: {values, %{state | next: rest}}
    defp partial(%{inputs: inputs, next: []} = state), do: {inputs, state}

    # A report, `{:report, values}`, gives its values, which a test sends it.
    @impl true
    def report({:report, values}, agent), do: {:ok, values, agent}

    @impl true
    def write(_values, agent), do: {:ok, agent}
  end

  # An adapter over an Agent, `agent:`, holding `{value, slip}`: a read gives `value` at
  # [0], and where `slip` is a value the input changes to it just after the read's sample,
  # the agent set and a report of it, `{:report, values}`, sent to the device's own
  # process, as a message an adapter is sent while it reads.
  defmodule Slips do
    @behaviour Logex.IO

    @impl true
    def init(_device, _points, opts), do: {:ok, Keyword.fetch!(opts, :agent)}

    @impl true
    def read(agent) do
      {value, slip} = Agent.get(agent, & &1)
      slipped(slip, agent)
      {:ok, %{[0] => value}, agent}
    end

    defp slipped(nil, _agent), do: :ok

    defp slipped(slip, agent) do
      Agent.update(agent, fn _ -> {slip, nil} end)
      send(self(), {:report, %{[0] => slip}})
    end

    @impl true
    def report({:report, values}, agent), do: {:ok, values, agent}

    @impl true
    def write(_values, agent), do: {:ok, agent}
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

  describe "the major fault (decisions 153 and 160, M5-9)" do
    # The lamp shows the bit of the panel's `faults` word that its `sel` names; a counter of
    # its own runs beside it; and a second counter on a slower task.
    @lamp "var_input faults word\nvar_input sel int\nvar_output lamp bool\n" <>
            "xic faults.[sel] ote lamp"

    @lamped """
    task fast interval 10 priority 1
    task slow interval 10 priority 2

    var_global faults word at panel.i.0
    var_global sel    int  at panel.i.1
    var_global lamp   bool at panel.q.0
    var_global y      bool at panel.q.1
    var_global a      dint
    var_global b      dint

    program l lamp with fast
      l.faults faults
      l.sel    sel
      l.lamp   lamp
    program c count with fast
      c.n a
    program d count with slow
      d.n b
    program r relay with slow
      r.in  lamp
      r.out y
    """

    defp lamped(text \\ @lamped, poll \\ 1_000_000) do
      {:ok, config} =
        Configuration.compile("plant", text, %{
          "lamp" => program(@lamp, "lamp"),
          "relay" => program(@relay, "relay"),
          "count" => program(@count, "count")
        })

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: poll
        )

      %{runner: runner, clock: clock, panel: panel}
    end

    defp out_of_range(task, instance, line, read),
      do:
        {:fault, task, instance,
         %Logex.Fault{
           severity: :major,
           kind: :bit_out_of_range,
           instruction: :xic,
           path: nil,
           file: nil,
           line: line,
           read: read
         }}

    test "a bit number out of range trips at the end of its step, before the round's " <>
           "write, every output 0 once and nothing after, the trip naming it" do
      %{runner: runner, clock: clock, panel: panel} = lamped()
      Runner.subscribe(runner, [:ran, :fault, :trip, :round])
      Sim.set(panel, %{[0] => 0x8000, [1] => 15})
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}
      assert {Runner.get!(runner, "a"), Runner.get!(runner, "b")} == {2, 2}

      # At 16 in a word: the lamp's run, and the counter's after it in the same task, then
      # the trip; the slow task's step never runs.
      Sim.set(panel, [1], 16)
      Manual.advance(clock, 10)
      fault = out_of_range("fast", "l", 4, 16)
      assert_receive {Runner, ^runner, {:ran, "fast", "l", 20}}
      assert_receive {Runner, ^runner, ^fault}
      assert_receive {Runner, ^runner, {:ran, "fast", "c", 20}}
      assert_receive {Runner, ^runner, {:trip, ^fault}}
      refute_received {Runner, ^runner, {:ran, "slow", _, 20}}
      refute_received {Runner, ^runner, {:round, 20, _}}
      assert %{status: :tripped, trip: ^fault} = Runner.status(runner)

      written = Sim.writes(panel)
      assert List.last(written) == %{[0] => 0, [1] => 0}
      Manual.advance(clock, 1000)
      Sim.set(panel, [1], 3)
      Manual.advance(clock, 1000)
      assert Sim.writes(panel) == written

      # The faulting step's instances as its run left them, the later step's as the round
      # before: `a` counted, `b` not, and `r` never saw the lamp go off.
      assert {Runner.get!(runner, "a"), Runner.get!(runner, "b")} == {3, 2}
      assert Runner.get!(runner, "l.lamp") == 0
      assert Runner.get!(runner, "r.in") == 1
    end

    # M5-15's review, which the runner walk met: a device whose next write fails, the
    # round tripping on a major fault before its write, takes the failure with the trip's
    # 0; the runner keeps its first reason, the device the outputs it last took. Since
    # decision 262 status/1 names the device, whose outputs are not known to be 0, and its
    # poll tries the 0 again (below); with no poll in the time, nothing is written until a
    # restart's first round writes it, as before.
    test "a trip's 0 that fails names its device in status/1, the first reason kept, until a restart" do
      %{runner: runner, clock: clock, panel: panel} = lamped()
      Sim.set(panel, %{[0] => 0x8000, [1] => 15})
      Manual.advance(clock, 10)
      assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}
      assert Runner.status(runner).unzeroed == []
      written = Sim.writes(panel)

      Sim.fail(panel, :write, {:error, :eio})
      Sim.set(panel, [1], 16)
      Manual.advance(clock, 10)
      fault = out_of_range("fast", "l", 4, 16)
      assert %{status: :tripped, trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      assert Sim.writes(panel) == written
      assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}

      Manual.advance(clock, 1000)
      assert %{status: :tripped, trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      assert Sim.writes(panel) == written

      Sim.set(panel, [1], 0)
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, unzeroed: []} = Runner.status(runner)
      assert List.last(Sim.writes(panel)) == %{[0] => 0, [1] => 0}
      assert length(Sim.writes(panel)) == length(written) + 1
    end

    # Decision 262: while the runner is tripped, a device whose adapter did not take the
    # trip's 0 is written its 0 again at every poll, and nothing else, until one is taken,
    # status/1 naming it until then; the first reason is kept, and a restart releases and
    # writes as before.
    test "a trip's 0 that fails is tried again at every poll until it is taken" do
      # Polls at 7, 14, 21, …, apart from the fast task's rounds at 10, 20, ….
      %{runner: runner, clock: clock, panel: panel} = lamped(@lamped, 7)
      Sim.set(panel, %{[0] => 0x8000, [1] => 15})
      Manual.advance(clock, 15)
      assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}

      # The trip's 0, at 20, and the polls' at 21 and 28 fail; the poll's at 35 is taken.
      for _ <- 1..3, do: Sim.fail(panel, :write, {:error, :eio})
      Sim.set(panel, [1], 16)
      Manual.advance(clock, 5)
      fault = out_of_range("fast", "l", 4, 16)
      assert %{status: :tripped, trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      written = Sim.writes(panel)
      assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}

      Manual.advance(clock, 1)
      assert %{trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      assert Sim.writes(panel) == written

      Manual.advance(clock, 7)
      assert %{trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      assert Sim.writes(panel) == written

      Manual.advance(clock, 7)
      assert %{status: :tripped, trip: ^fault, unzeroed: []} = Runner.status(runner)
      assert Sim.writes(panel) == written ++ [%{[0] => 0, [1] => 0}]
      assert Sim.outputs(panel) == %{[0] => 0, [1] => 0}

      # Taken once, it is written nothing more, however the inputs change.
      Sim.set(panel, [1], 3)
      Manual.advance(clock, 100)
      assert Sim.writes(panel) == written ++ [%{[0] => 0, [1] => 0}]
      assert %{status: :tripped, trip: ^fault, unzeroed: []} = Runner.status(runner)

      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, unzeroed: []} = Runner.status(runner)
      assert length(Sim.writes(panel)) > length(written) + 1
    end

    # Decision 262: a restart refused latches every device again, its 0 written once more,
    # and status/1 names afresh the devices whose 0 that write does not take, so one named
    # before whose new 0 is taken is named no more.
    test "a restart refused whose 0 a device named before takes drops its name" do
      %{runner: runner, clock: clock, panel: panel} = lamped()
      Sim.set(panel, %{[0] => 0x8000, [1] => 15})
      Manual.advance(clock, 10)
      Sim.fail(panel, :write, {:error, :eio})
      Sim.set(panel, [1], 16)
      Manual.advance(clock, 10)
      fault = out_of_range("fast", "l", 4, 16)
      assert %{status: :tripped, trip: ^fault, unzeroed: ["panel"]} = Runner.status(runner)
      written = Sim.writes(panel)

      Sim.fail(panel, :read, {:value, [7], 1})

      assert Runner.restart(runner, :cold) ==
               {:error, {:io_init, "panel", {:unknown_address, [7]}}}

      assert Sim.writes(panel) == written ++ [%{[0] => 0, [1] => 0}]
      assert %{status: :tripped, trip: ^fault, unzeroed: []} = Runner.status(runner)
    end

    test "a step that meets two major faults trips for the first, in the order its " <>
           "instances run" do
      text = """
      task fast interval 10 priority 1
      var_global faults word at panel.i.0
      var_global sel    int  at panel.i.1
      var_global sel2   int  at panel.i.2
      var_global lamp   bool at panel.q.0
      var_global lamp2  bool at panel.q.1
      program l lamp with fast
        l.faults faults
        l.sel    sel
        l.lamp   lamp
      program l2 lamp with fast
        l2.faults faults
        l2.sel    sel2
        l2.lamp   lamp2
      """

      %{runner: runner, clock: clock, panel: panel} = lamped(text)
      Runner.subscribe(runner, [:fault, :trip])
      Sim.set(panel, %{[1] => 16, [2] => -1})
      Manual.advance(clock, 10)
      first = out_of_range("fast", "l", 4, 16)
      second = out_of_range("fast", "l2", 4, -1)
      assert_receive {Runner, ^runner, ^first}
      assert_receive {Runner, ^runner, ^second}
      assert_receive {Runner, ^runner, {:trip, ^first}}
      assert Runner.status(runner).trip == first
    end

    test "a host driving the resource through cycle/3 runs every due step and sees the event" do
      {:ok, config} =
        Configuration.compile("plant", @lamped, %{
          "lamp" => program(@lamp, "lamp"),
          "relay" => program(@relay, "relay"),
          "count" => program(@count, "count")
        })

      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(config), 0, %{"sel" => 1})
      {runtime, outputs, events} = Runtime.cycle(runtime, 10, %{"sel" => 16})
      assert out_of_range("fast", "l", 4, 16) in events
      assert {:ran, "slow", "d", 10} in events
      assert Runtime.get!(runtime, "b") == 2
      assert outputs == %{"lamp" => 0, "y" => 0}
    end

    test "the untimed programs' step trips as a timed task's does, under the continuous task" do
      text =
        "task main continuous\nvar_global faults word at panel.i.0\n" <>
          "var_global sel int at panel.i.1\nvar_global lamp bool at panel.q.0\n" <>
          "program l lamp\n  l.faults faults\n  l.sel sel\n  l.lamp lamp\n"

      %{runner: runner, clock: clock, panel: panel} = lamped(text)
      Sim.set(panel, [1], -1)
      Manual.advance(clock, 1)
      assert Runner.status(runner).trip == out_of_range("main", "l", 4, -1)
      assert List.last(Sim.writes(panel)) == %{[0] => 0}
    end

    test "a minor fault trips nothing" do
      text =
        "task fast interval 10 priority 1\nvar_global z dint at panel.i.0\n" <>
          "var_global q dint at panel.q.0\nprogram v divide with fast\n  v.z z\n  v.q q\n"

      {:ok, config} =
        Configuration.compile("plant", text, %{
          "divide" => program("var_input z dint\nvar_output q dint\ndiv 10 z q", "divide")
        })

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 1_000_000
        )

      Manual.advance(clock, 30)
      assert %{status: :running, rounds: 4} = Runner.status(runner)
    end

    test "a restart, cold or warm, runs again once the number is back in range" do
      for mode <- [:cold, :warm] do
        %{runner: runner, clock: clock, panel: panel} = lamped()
        Sim.set(panel, %{[0] => 0x8000, [1] => 16})
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == out_of_range("fast", "l", 4, 16)

        Sim.set(panel, [1], 15)
        assert :ok = Runner.restart(runner, mode)
        assert %{status: :running} = Runner.status(runner)
        Manual.advance(clock, 10)
        assert Sim.outputs(panel) == %{[0] => 1, [1] => 1}
      end
    end

    # A step that met a major fault and outlasted its watchdog is tripped for the fault,
    # which came first (provisional).
    test "a fault and a watchdog on one step trip for the fault" do
      text =
        "task fast interval 10 priority 1 watchdog 50\nvar_global faults word at panel.i.0\n" <>
          "var_global sel int at panel.i.1\nvar_global fast_ms dint at panel.i.2\n" <>
          "var_global lamp bool at panel.q.0\n" <>
          "program l lamp with fast\n  l.faults faults\n  l.sel sel\n  l.lamp lamp\n"

      {:ok, config} =
        Configuration.compile("plant", text, %{"lamp" => program(@lamp, "lamp")})

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 1_000_000,
          steps: Slow
        )

      :ets.insert(__MODULE__, {runner, clock})
      Sim.set(panel, %{[1] => 16, [2] => 51})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == out_of_range("fast", "l", 4, 16)
    end
  end

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
          "var_global a dint\nvar_global b dint at panel.q.0\n" <>
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

      # The round's count is never written: the panel's output is 0, written once after
      # the last count, and nothing after.
      Manual.advance(clock, 100)
      assert [%{[0] => 0}, %{[0] => last} | _] = Enum.reverse(Sim.writes(panel))
      assert last > 0
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

    # Decision 262: a device that latches on its own deadline and whose own 0 fails is
    # named by status/1 once the runner trips on its notice, and its polls write its 0
    # again, and nothing else, until one is taken.
    test "a device latched on its deadline whose own 0 fails is named and written its 0 " <>
           "again at its polls" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@conveyor), poll: 10, idle: 100, steps: Runtime)

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 20)
      :sys.suspend(runner)
      Manual.advance(clock, 109)
      written = Sim.writes(panel)
      assert List.last(written) == %{[0] => 1}

      # Its latch at 130, the poll's 0 at 130 and the next poll's at 140 fail; 150's is taken.
      for _ <- 1..3, do: Sim.fail(panel, :write, {:error, :eio})
      Manual.advance(clock, 1)
      assert Sim.writes(panel) == written
      assert Sim.outputs(panel) == %{[0] => 1}
      assert List.last(Sim.writes(drive)) == %{[0] => 0}

      :sys.resume(runner)
      assert_receive {Runner, ^runner, {:trip, {:watchdog, {:device, "drive", 110}}}}, 5000
      assert %{status: :tripped, unzeroed: ["panel"]} = Runner.status(runner)

      Manual.advance(clock, 10)
      assert %{status: :tripped, unzeroed: ["panel"]} = Runner.status(runner)
      assert Sim.writes(panel) == written

      Manual.advance(clock, 10)
      assert %{trip: {:watchdog, {:device, "drive", 110}}, unzeroed: []} = Runner.status(runner)
      assert Sim.writes(panel) == written ++ [%{[0] => 0}]

      Manual.advance(clock, 100)
      assert Sim.writes(panel) == written ++ [%{[0] => 0}]
      assert Runner.status(runner).unzeroed == []
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

  # The e-stop's round writing the drive alone.
  @drive_stopped String.replace(@stopped, "var_global y bool at panel.q.0", "var_global y bool")

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

    test "a report's fault trips, naming its device, every device written 0 once and " <>
           "nothing after" do
      %{runner: runner, clock: clock, panel: panel, drive: drive} =
        rig(configured(@read_both), steps: Runtime)

      Sim.fail(panel, :report, :raise)
      Sim.set(panel, [0], 1)

      assert Runner.status(runner).trip ==
               {:io, "panel",
                {:raised, "the simulated device \"panel\" raised in report, as fail/3 told it"}}

      Manual.advance(clock, 100)
      zeroed_once(panel, 0)
      zeroed_once(drive, 0)
    end

    # Found by M4-6's walk: a device took a change the runner refused as passed on, so a
    # value that does not fit was never passed on again and the runner ran on with the
    # last value it took; and a report the runner refused lost the good change beside the
    # bad one for good. Since decision 142 a restart reads every device whole, so a card
    # that goes on giving it leaves each restart refused, and the good change is taken by
    # the restart's own read.
    test "a device that goes on giving a value that does not fit refuses each restart with " <>
           "its fault, and a change refused with it is taken once it is put right" do
      for bad <- [{:value, [0], 2}, {:value, [7], 1}] do
        %{runner: runner, clock: clock, panel: panel} = rig(configured(), poll: 10)
        cause = (bad == {:value, [0], 2} && {:bad_value, [0], 2}) || {:unknown_address, [7]}
        for _ <- 1..3, do: Sim.fail(panel, :read, bad)
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == {:io, "panel", cause}

        for _ <- 1..2 do
          assert Runner.restart(runner, :cold) == {:error, {:io_init, "panel", cause}}
          assert Runner.status(runner).trip == {:io, "panel", cause}
        end

        # Put right, it is read as it is.
        assert Runner.restart(runner, :cold) == :ok
        Manual.advance(clock, 10)
        assert %{status: :running} = Runner.status(runner)
        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "x") == 1
      end

      # A report the runner refuses for a value that does not fit holds a good change
      # beside it, which the restart's read takes before its first round.
      %{runner: runner, panel: panel} = rig(configured(), poll: 10)
      Sim.fail(panel, :report, {:value, [1], 2_147_483_648})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).trip == {:io, "panel", {:bad_value, [1], 2_147_483_648}}
      assert Runner.get!(runner, "x") == 0
      assert Runner.restart(runner, :cold) == :ok
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
        rig(configured(@stopped), idle: 300, poll: 10, steps: Runtime)

      # The e-stop's round, at once, writes the drive, which hangs: the runner waits its
      # deadline, 300 ms and a poll period, in real time on the manual clock.
      old = device_pid(runner, "drive")
      Sim.fail(drive, :write, :hang)
      {took, :ok} = :timer.tc(fn -> Sim.set(panel, [0], 1) end, :millisecond)
      assert took >= 310 and took < 3000
      assert Runner.status(runner).trip == {:io, "drive", :timeout}
      refute Process.alive?(old)

      # Its outputs are left to the device; every other device is zeroed. Since decision
      # 262 status/1 names it, its outputs not known to be 0, until the restart.
      assert Sim.writes(drive) == [%{[0] => 0}]
      zeroed_once(panel, 0)
      assert Runner.status(runner).unzeroed == ["drive"]

      assert Runner.restart(runner, :cold) == :ok
      assert device_pid(runner, "drive") != old
      assert Sim.outputs(drive) == %{[0] => 1}
      assert %{status: :running, unzeroed: []} = Runner.status(runner)
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
      assert Runner.status(runner).unzeroed == []
      assert Sim.writes(panel) == [%{[0] => 0}, %{[0] => 0}]
      assert Runner.restart(runner, :cold) == :ok
      assert device_pid(runner, "drive") == old

      # One a millisecond sooner is in time. The panel has no output here: written after
      # the drive, it would have the deadline's last millisecond, on the manual clock a
      # millisecond of real time, to answer in, which a loaded machine misses.
      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(@drive_stopped), poll: 10, steps: Runtime)

      Sim.fail(drive, :write, {:delay, 509})
      Sim.set(panel, [0], 1)
      assert Runner.status(runner).status == :running
      assert Sim.writes(drive) == [%{[0] => 0}, %{[0] => 1}]
      assert Sim.writes(panel) == []
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
      assert Runner.status(runner).unzeroed == ["drive"]

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

      assert %{trip: {:io, "drive", {:down, :killed}}, unzeroed: ["drive"]} =
               Runner.status(runner)

      assert Runner.restart(runner, :cold) == :ok
      assert Runner.status(runner).unzeroed == []
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

      # An idle watchdog of 1000 ms, so that on a busy machine the panel, which does not
      # hang, is never taken for hung (M5-5's review: at 300 it was now and then).
      %{runner: runner, panel: panel, drive: drive} =
        rig(configured(text),
          poll: 10,
          idle: 1000,
          steps: Runtime,
          clock: {Logex.Runner.Clock.Monotonic, nil}
        )

      Runner.subscribe(runner)
      Sim.set(panel, [0], 1)
      assert written(panel, 200) == %{[0] => 1}
      Sim.fail(drive, :read, :hang)
      assert_receive {Runner, ^runner, {:trip, {:io, "drive", :timeout}}}, 5000
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
        rig(configured(@read_both), poll: 10, idle: 300, steps: Runtime)

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
        rig(configured(@read_both), poll: 10, idle: 300, steps: Runtime)

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
          poll: 600,
          idle: 200,
          steps: Boom
        )

      # The drive's zero sleeps 400 ms in real time, past the idle watchdog alone and
      # within it and a poll period, 800, a margin wide enough for a busy machine (M5-5's
      # review: within 200 and 200, a 300 ms zero failed now and then under load).
      old = device_pid(runner, "drive")
      Sim.fail(drive, :write, {:delay, 400})
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

  # The conveyor of a drive whose card gives its speed, a dint, the panel's x running y
  # on the panel and z on the drive.
  @speed """
  task fast interval 10 priority 1

  var_global x     bool at panel.i.0
  var_global speed dint at drive.i.0
  var_global y     bool at panel.q.0
  var_global z     bool at drive.q.0

  program r relay with fast
    r.in  x
    r.out y

  program s relay with fast
    s.in  x
    s.out z
  """

  @too_fast 2_147_483_648

  # The conveyor running, the drive's speed 1000, and then its card giving a speed no
  # dint holds `bad` reads running, which trips the runner at its next read.
  defp tripped_on_speed(extra, bad) do
    rig = rig(configured(@speed), [poll: 10, steps: Runtime] ++ extra)
    %{runner: runner, clock: clock, panel: panel, drive: drive} = rig
    Sim.set(drive, [0], 1000)
    Sim.set(panel, [0], 1)
    Manual.advance(clock, 10)
    assert Runner.get!(runner, "speed") == 1000
    assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}
    for _ <- 1..bad, do: Sim.fail(drive, :read, {:value, [0], @too_fast})
    Manual.advance(clock, 10)
    assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [0], @too_fast}}
    zeroed_once(panel, 1)
    zeroed_once(drive, 1)
    rig
  end

  describe "a restart reads every device before its first round (decision 142)" do
    test "a card still giving a value that does not fit leaves the runner tripped, the " <>
           "restart answered with its fault, cold or warm, nothing written but 0" do
      for mode <- [:cold, :warm] do
        %{runner: runner, clock: clock, panel: panel, drive: drive} = tripped_on_speed([], 3)
        Runner.subscribe(runner)
        %{rounds: rounds} = Runner.status(runner)
        {panel_at, drive_at} = {length(Sim.writes(panel)), length(Sim.writes(drive))}

        # Each restart refused, its trip kept, and every device latched again, its 0
        # written once more (decision 136): nothing switches on.
        for _ <- 1..2 do
          assert Runner.restart(runner, mode) ==
                   {:error, {:io_init, "drive", {:bad_value, [0], @too_fast}}}

          assert %{status: :tripped, trip: {:io, "drive", {:bad_value, [0], @too_fast}}} =
                   Runner.status(runner)
        end

        Manual.advance(clock, 100)
        assert Enum.drop(Sim.writes(panel), panel_at) == [%{[0] => 0}, %{[0] => 0}]
        assert Enum.drop(Sim.writes(drive), drive_at) == [%{[0] => 0}, %{[0] => 0}]
        assert %{status: :tripped, rounds: ^rounds} = Runner.status(runner)
        refute_received {Runner, ^runner, {:restart, _mode}}

        # Put right, the next restart runs.
        assert Runner.restart(runner, mode) == :ok
        assert_received {Runner, ^runner, {:restart, ^mode}}
        assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}
      end
    end

    test "a card put right before the restart lets it run, its first round on what the " <>
           "card gives now, cold or warm" do
      for mode <- [:cold, :warm] do
        %{runner: runner, panel: panel, drive: drive} = tripped_on_speed([], 1)

        # Mended while tripped, and read by no poll before the restart: the restart's own
        # read gives the first round its speed.
        Sim.set(drive, [0], 1200)
        assert Runner.restart(runner, mode) == :ok
        assert %{status: :running, trip: nil} = Runner.status(runner)
        assert Runner.get!(runner, "speed") == 1200
        assert List.last(Sim.writes(panel)) == %{[0] => 1}
        assert List.last(Sim.writes(drive)) == %{[0] => 1}
      end
    end

    test "each kind of fault in a restart's read is the restart's answer, in the card's " <>
           "own words" do
      raised = "the simulated device \"drive\" raised in read, as fail/3 told it"

      for {how, cause} <- [
            {{:error, :eio}, {:error, :eio}},
            {:raise, {:raised, raised}},
            {:throw, {:thrown, {Sim, :read}}},
            {:exit, {:exited, {Sim, :read}}},
            {{:value, [7], 1}, {:unknown_address, [7]}}
          ] do
        %{runner: runner, drive: drive} = tripped_on_speed([], 1)
        Sim.fail(drive, :read, how)
        assert Runner.restart(runner, :cold) == {:error, {:io_init, "drive", cause}}
        assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [0], @too_fast}}
        assert Runner.restart(runner, :cold) == :ok
      end
    end

    # Decision 262: a restart refused writes every 0 again, and a device that does not take
    # it is named by status/1 until a restart, or its poll's write of it, takes it.
    test "a restart refused names a device whose 0 it does not take, and a restart releases it" do
      %{runner: runner, drive: drive, panel: panel} = tripped_on_speed([], 1)
      assert Runner.status(runner).unzeroed == []
      Sim.fail(drive, :read, {:value, [7], 1})
      Sim.fail(panel, :write, {:error, :eio})
      before = Sim.writes(panel)

      assert Runner.restart(runner, :cold) ==
               {:error, {:io_init, "drive", {:unknown_address, [7]}}}

      assert Sim.writes(panel) == before
      assert %{status: :tripped, unzeroed: ["panel"]} = Runner.status(runner)
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, unzeroed: []} = Runner.status(runner)
    end

    test "a card hung in a restart's read is killed, the restart answered :timeout, and " <>
           "opened again at the next restart" do
      %{runner: runner, drive: drive} = tripped_on_speed([idle: 300], 1)
      old = device_pid(runner, "drive")
      Sim.fail(drive, :read, :hang)
      assert Runner.restart(runner, :warm) == {:error, {:io_init, "drive", :timeout}}
      refute Process.alive?(old)
      assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [0], @too_fast}}
      assert Runner.restart(runner, :warm) == :ok
      assert device_pid(runner, "drive") != old
      assert Sim.outputs(drive) == %{[0] => 1}
    end

    test "the cards are read in device-name order, the first that fails the restart's " <>
           "answer, the rest read at the next" do
      %{runner: runner, panel: panel, drive: drive} = tripped_on_speed([], 1)
      Sim.fail(panel, :read, {:value, [0], 2})
      Sim.fail(drive, :read, {:error, :eio})
      assert Runner.restart(runner, :cold) == {:error, {:io_init, "drive", {:error, :eio}}}

      assert Runner.restart(runner, :cold) ==
               {:error, {:io_init, "panel", {:bad_value, [0], 2}}}

      assert Runner.restart(runner, :cold) == :ok
      assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}
    end

    # Found by M4-6's third verification: the device took a restart's read as what it had
    # passed on before the runner checked it, so an address that is no input point's,
    # which no good read gives again, stayed in it for good and the same fault, read again
    # later, was never passed on.
    test "a restart's read the runner refuses leaves nothing in the device to hide the " <>
           "same fault at a later read" do
      %{runner: runner, clock: clock, drive: drive} = tripped_on_speed([], 1)
      Sim.fail(drive, :read, {:value, [7], 1})

      assert Runner.restart(runner, :cold) ==
               {:error, {:io_init, "drive", {:unknown_address, [7]}}}

      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      assert %{status: :running} = Runner.status(runner)
      Sim.fail(drive, :read, {:value, [7], 1})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:unknown_address, [7]}}
    end

    test "a poll's change the runner refuses leaves nothing in the device to hide the " <>
           "same fault after a restart" do
      %{runner: runner, clock: clock, drive: drive} = tripped_on_speed([], 1)
      assert Runner.restart(runner, :cold) == :ok
      Sim.fail(drive, :read, {:value, [7], 1})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:unknown_address, [7]}}
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      Sim.fail(drive, :read, {:value, [7], 1})
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:unknown_address, [7]}}
    end

    # A device's change read before a restart, waiting in the runner's mailbox behind it,
    # is overtaken by the restart's own read: a reading taken before the restart trips
    # nothing after it and overwrites nothing it read.
    test "a change read before a restart and taken after it is stale: a bad one trips " <>
           "nothing, a good one overwrites nothing the restart read" do
      for {before, now} <- [{@too_fast, 1000}, {1500, 1700}] do
        %{runner: runner, clock: clock, panel: panel, drive: drive} = tripped_on_speed([], 1)
        Sim.set(drive, [0], 1000)

        case before do
          @too_fast -> Sim.fail(drive, :read, {:value, [0], @too_fast})
          speed -> Sim.set(drive, [0], speed)
        end

        :sys.suspend(runner)
        restart = Task.async(fn -> Runner.restart(runner, :cold) end)
        restart_waiting(runner)
        poll = Task.async(fn -> Manual.advance(clock, 10) end)
        changes_waiting(runner)
        Sim.set(drive, [0], now)
        :sys.resume(runner)
        assert Task.await(restart) == :ok
        Task.await(poll)

        assert %{status: :running, trip: nil} = Runner.status(runner)
        assert Runner.get!(runner, "speed") == now
        assert :sys.get_state(device_pid(runner, "drive")).image == %{[0] => now}
        assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}
      end
    end

    # Found by M4-6's fourth verification: a device released heard the restart's count
    # at once, so a reading it took between its release and its own reread, while the
    # runner read the devices before it, was passed on as the restart's own, taken after
    # the restart over what its reread read: a bad one tripped the runner just after the
    # restart answered :ok.
    test "a change read between a device's release and its reread is never passed on: " <>
           "a bad one trips nothing, an older one overwrites nothing" do
      for how <- [:poll, :report], window <- [2, 0] do
        %{runner: runner, panel: panel, drive: drive} = tripped_on_speed([idle: 5000], 1)
        panel_pid = device_pid(runner, "panel")
        next = :sys.get_state(panel_pid).next
        reads = Sim.reads(panel)

        # The drive, read first, held inside its reread's read, the panel released.
        :sys.suspend(drive)
        restart = Task.async(fn -> Runner.restart(runner, :cold) end)
        called(drive)

        case how do
          :poll ->
            Sim.fail(panel, :read, {:value, [0], window})
            send(panel_pid, {Logex.Runner.Device, :poll, next})
            read_since(panel, reads)

          :report ->
            Sim.fail(panel, :report, {:value, [0], window})
            report = Task.async(fn -> Sim.set(panel, [5], 1) end)
            reported_or_passed(report, runner)
        end

        :sys.resume(drive)
        assert Task.await(restart) == :ok
        :sys.get_state(panel_pid)
        assert %{status: :running, trip: nil} = Runner.status(runner)
        assert Runner.get!(runner, "x") == 1
        assert :sys.get_state(panel_pid).image[[0]] == 1
        assert {Sim.outputs(panel), Sim.outputs(drive)} == {%{[0] => 1}, %{[0] => 1}}
      end
    end

    test "on the real clock, a bad reading of a device released while the one before " <>
           "it is read again trips nothing" do
      {:ok, panel} = Sim.start_link()
      {:ok, drive} = Sim.start_link()
      Sim.set(drive, [0], 1000)
      Sim.set(panel, [0], 1)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@speed),
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Logex.Runner.Clock.Monotonic, nil},
          poll: 10,
          idle: 2000
        )

      Sim.fail(panel, :read, {:value, [0], 2})
      tripped(runner, 0)
      assert Runner.status(runner).trip == {:io, "panel", {:bad_value, [0], 2}}

      # The drive's reread sleeps 800 ms, the panel's polls going on meanwhile, the bad
      # reading 100 ms in: wide margins on both sides for a busy machine, within the idle
      # watchdog and a poll period (M5-5's review: a 300 ms sleep within 510 failed now and
      # then under load).
      Sim.fail(drive, :read, {:delay, 800})
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      Process.sleep(100)
      Sim.fail(panel, :read, {:value, [0], 2})
      assert Task.await(restart) == :ok
      Process.sleep(30)
      assert %{status: :running, trip: nil} = Runner.status(runner)
      Runner.stop(runner)
    end

    test "a reading between a device's reread and its taking is passed on against the " <>
           "reread, never lost to the image from before" do
      %{runner: runner, panel: panel} = tripped_on_speed([idle: 5000], 1)
      panel_pid = device_pid(runner, "panel")
      next = :sys.get_state(panel_pid).next

      # The panel's reread gives x 0, held inside its read until a poll waits behind it,
      # the poll reading x 1 again, as the image from before the restart holds it.
      Sim.fail(panel, :read, {:value, [0], 0})
      :sys.suspend(panel)
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      called(panel)
      send(panel_pid, {Logex.Runner.Device, :poll, next})
      :sys.resume(panel)
      assert Task.await(restart) == :ok
      :sys.get_state(panel_pid)

      # The poll's x 1 taken by the runner for its next round, and the device's image.
      assert :sys.get_state(runner).values["x"] == 1
      assert :sys.get_state(panel_pid).image[[0]] == 1
    end

    @trigger """
    task e single t priority 1

    var_global x     bool at panel.i.0
    var_global speed dint at drive.i.0
    var_global t     bool at drive.i.1
    var_global y     bool at panel.q.0

    program r relay with e
      r.in  x
      r.out y
    """

    test "a restart's read of some points keeps the rest of the device's image: a " <>
           "trigger read again unchanged makes no round" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)
      {:ok, agent} = Agent.start_link(fn -> %{inputs: %{[0] => 1000, [1] => 1}, next: []} end)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@trigger),
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Partial, agent: agent}},
          clock: {Manual, clock},
          poll: 10
        )

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      Sim.fail(panel, :read, {:value, [0], 7})
      Manual.advance(clock, 10)
      assert {:io, "panel", _} = Runner.status(runner).trip

      # The restart's read of the drive gives its speed alone.
      Agent.update(agent, &%{&1 | next: [%{[0] => 1000}]})
      Runner.subscribe(runner, [:round])
      assert Runner.restart(runner, :cold) == :ok
      %{rounds: rounds} = Runner.status(runner)
      Manual.advance(clock, 10)
      assert %{rounds: ^rounds, trip: nil} = Runner.status(runner)
      assert_received {Runner, ^runner, {:round, 0, _}}
      refute_received {Runner, ^runner, {:round, _, _}}
    end

    @loads """
    task fast interval 10 priority 1

    var_global x     bool at panel.i.0
    var_global speed dint at drive.i.0
    var_global load  dint at drive.i.1
    var_global y     bool at panel.q.0

    program r relay with fast
      r.in  x
      r.out y
    """

    test "readings between a device's reread and its taking, each of some points, are " <>
           "merged and passed on together" do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)
      {:ok, agent} = Agent.start_link(fn -> %{inputs: %{[0] => 1000, [1] => 5}, next: []} end)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@loads),
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Partial, agent: agent}},
          clock: {Manual, clock},
          poll: 10,
          idle: 5000
        )

      Sim.fail(panel, :read, {:value, [0], 7})
      Manual.advance(clock, 10)
      assert {:io, "panel", _} = Runner.status(runner).trip
      drive_pid = device_pid(runner, "drive")
      next = :sys.get_state(drive_pid).next

      # The reread reads both points, and two polls that wait behind it one each.
      Agent.update(agent, fn state ->
        %{
          state
          | inputs: %{[0] => 1200, [1] => 7},
            next: [%{[0] => 1100, [1] => 6}, %{[0] => 1200}, %{[1] => 7}]
        }
      end)

      :sys.suspend(agent)
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      called(agent)
      send(drive_pid, {Logex.Runner.Device, :poll, next})
      send(drive_pid, {Logex.Runner.Device, :poll, next + 10})
      :sys.resume(agent)
      assert Task.await(restart) == :ok
      :sys.get_state(drive_pid)

      assert Map.take(:sys.get_state(runner).values, ["speed", "load"]) == %{
               "speed" => 1200,
               "load" => 7
             }

      assert :sys.get_state(drive_pid).image == %{[0] => 1200, [1] => 7}
    end

    @apart """
    task fast interval 10 priority 1

    var_global x     bool at a.i.0
    var_global speed dint at b.i.0
    var_global y     bool at a.q.0

    program r relay with fast
      r.in  x
      r.out y
    """

    # Found by M4-6's fifth verification: a device waiting on the runner for its own
    # change takes only the runner's answers and requests, so a report already in its
    # mailbox was overtaken by the restart's release, reread and taking, and passed on
    # after them, over what the reread read, until the next poll.
    test "a report in a device's mailbox while it waits on the runner, sent before its " <>
           "reread, is older than the restart's read and overwrites nothing" do
      for sent <- [:before_release, :before_reread, :before_a_refused_restart] do
        {:ok, clock} = Manual.start_link()
        {:ok, a} = Sim.start_link(clock: clock)
        {:ok, agent} = Agent.start_link(fn -> %{inputs: %{[0] => 1000}, next: []} end)

        {:ok, runner} =
          Runner.start_link(
            configuration: configured(@apart),
            io: %{"a" => {Sim, sim: a}, "b" => {Partial, agent: agent}},
            clock: {Manual, clock},
            poll: 100,
            idle: 5000
          )

        Sim.set(a, [0], 1)
        Sim.fail(a, :read, {:value, [0], 7})
        Manual.advance(clock, 100)
        assert {:io, "a", _} = Runner.status(runner).trip
        b = device_pid(runner, "b")

        # b's change waits in the runner's mailbox behind the restart, b waiting on it.
        :sys.suspend(runner)
        restart = Task.async(fn -> Runner.restart(runner, :cold) end)
        restart_waiting(runner)
        refused = refused_first(sent, runner, agent)
        send(b, {:report, %{[0] => 1500}})
        changes_waiting(runner)
        Agent.update(agent, &%{&1 | inputs: %{[0] => 1200}})

        case sent do
          :before_reread ->
            :sys.suspend(a)
            :sys.resume(runner)
            called(a)
            send(b, {:report, %{[0] => 1}})
            :sys.resume(a)

          _before_release ->
            send(b, {:report, %{[0] => 1}})
            :sys.resume(runner)
        end

        assert Task.await(restart) == refused_restart(refused)
        assert second_restart(refused) == :ok
        :sys.get_state(b)

        # A round, and no poll of b, which would read 1200 again.
        Manual.advance(clock, 10)
        assert %{status: :running, trip: nil} = Runner.status(runner)
        assert Runner.get!(runner, "speed") == 1200
        assert :sys.get_state(b).image == %{[0] => 1200}

        # A report after the restart is passed on.
        send(b, {:report, %{[0] => 1300}})
        :sys.get_state(b)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "speed") == 1300
        Runner.stop(runner)
      end
    end

    # Found by M4-6's sixth verification: the fence was sent once the reread had read, so
    # a report the device was sent while its adapter read, which may give what the read's
    # sample missed, came before the fence and was dropped, the input wrong until the next
    # poll.
    test "a report a device is sent while its restart's read samples is newer than that " <>
           "read, and passed on after it" do
      {:ok, clock} = Manual.start_link()
      {:ok, a} = Sim.start_link(clock: clock)
      {:ok, agent} = Agent.start_link(fn -> {1000, nil} end)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@apart),
          io: %{"a" => {Sim, sim: a}, "b" => {Slips, agent: agent}},
          clock: {Manual, clock},
          poll: 100
        )

      Sim.set(a, [0], 1)
      Sim.fail(a, :read, {:value, [0], 7})
      Manual.advance(clock, 100)
      assert {:io, "a", _} = Runner.status(runner).trip

      # The restart's read samples 2000, and the input goes to 3000 as it reads.
      Agent.update(agent, fn _ -> {2000, 3000} end)
      assert Runner.restart(runner, :cold) == :ok
      :sys.get_state(device_pid(runner, "b"))

      # A round, and no poll of b, which would read 3000 again.
      Manual.advance(clock, 10)
      assert %{status: :running, trip: nil} = Runner.status(runner)
      assert Runner.get!(runner, "speed") == 3000
      assert :sys.get_state(device_pid(runner, "b")).image == %{[0] => 3000}
    end

    @pushed """
    task fast interval 10 priority 1

    var_global x     bool at a.i.0
    var_global speed dint at b.i.0
    var_global load  dint at b.i.1
    var_global level dint at b.i.2
    var_global y     bool at a.q.0

    program r relay with fast
      r.in  x
      r.out y
    """

    # b over a Partial adapter whose read gives `inputs`, a reported first, the runner
    # tripped on a's read.
    defp pushed(inputs, reports) do
      {:ok, clock} = Manual.start_link()
      {:ok, a} = Sim.start_link(clock: clock)
      {:ok, agent} = Agent.start_link(fn -> %{inputs: inputs, next: []} end)

      {:ok, runner} =
        Runner.start_link(
          configuration: configured(@pushed),
          io: %{"a" => {Sim, sim: a}, "b" => {Partial, agent: agent}},
          clock: {Manual, clock},
          poll: 100,
          idle: 5000
        )

      b = device_pid(runner, "b")
      send(b, {:report, reports})
      :sys.get_state(b)
      Sim.set(a, [0], 1)
      Sim.fail(a, :read, {:value, [0], 7})
      Manual.advance(clock, 100)
      assert {:io, "a", _} = Runner.status(runner).trip
      %{runner: runner, clock: clock, a: a, b: b, agent: agent}
    end

    # A restart whose read of b gives `reread`, b sent each report once released, while
    # a, read first, is held inside its read.
    defp reported_in_window(%{runner: runner, a: a, b: b, agent: agent}, reread, reports) do
      Agent.update(agent, &%{&1 | next: [reread]})
      :sys.suspend(a)
      restart = Task.async(fn -> Runner.restart(runner, :cold) end)
      called(a)
      for report <- reports, do: send(b, {:report, report})
      :sys.get_state(b)
      :sys.resume(a)
      Task.await(restart)
    end

    # Found by M4-6's seventh verification: a device's readings between its release and
    # its reread were dropped, safe only for the points the reread gives, so a report of a
    # point the adapter's read leaves out was lost for good.
    test "a report between a device's release and its reread, of a point its read does " <>
           "not give, is taken by the restart" do
      rig = pushed(%{}, %{[0] => 1000, [1] => 5})
      assert Runner.get!(rig.runner, "speed") == 1000
      assert reported_in_window(rig, %{}, [%{[0] => 1500}, %{[0] => 2000}]) == :ok
      assert %{status: :running, trip: nil} = Runner.status(rig.runner)
      assert Runner.get!(rig.runner, "speed") == 2000
      assert :sys.get_state(rig.b).image == %{[0] => 2000, [1] => 5}
      Manual.advance(rig.clock, 1000)
      assert Runner.get!(rig.runner, "speed") == 2000
    end

    test "a bad report between a device's release and its reread, of a point its read " <>
           "does not give, refuses the restart with the device's fault" do
      for {reread, speed} <- [{%{}, 1000}, {%{[0] => 1200}, 1200}],
          {bad, cause} <- [
            {%{[2] => @too_fast}, {:bad_value, [2], @too_fast}},
            {%{[5] => 1}, {:unknown_address, [5]}}
          ] do
        rig = pushed(%{}, %{[0] => 1000, [1] => 5, [2] => 0})

        assert reported_in_window(rig, reread, [%{[1] => 6}, bad]) ==
                 {:error, {:io_init, "b", cause}}

        assert %{status: :tripped, trip: {:io, "a", _}} = Runner.status(rig.runner)

        # The refused point is dropped and the rest of the read passed on, as a change
        # read while tripped is, and the next restart reads afresh.
        :sys.get_state(rig.b)
        assert taken_while_tripped(rig) == {speed, 6}
        assert :sys.get_state(rig.b).image == %{[0] => speed, [1] => 6, [2] => 0}
        assert Runner.restart(rig.runner, :cold) == :ok
        assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} == {speed, 6}
        assert Runner.get!(rig.runner, "level") == 0
        Runner.stop(rig.runner)
      end
    end

    # Found by M4-6's eighth verification: a change answered :stale was dropped, safe only
    # for the points the restart's read gives, so one of a point the adapter's read
    # leaves out was lost for good.
    test "a report of a point a device's read does not give, passed on before its release " <>
           "and answered stale, is given with the restart's read" do
      rig = pushed(%{}, %{[0] => 1000, [1] => 5})
      :sys.suspend(rig.runner)
      restart = Task.async(fn -> Runner.restart(rig.runner, :cold) end)
      restart_waiting(rig.runner)
      send(rig.b, {:report, %{[0] => 1500}})
      changes_waiting(rig.runner)
      :sys.resume(rig.runner)
      assert Task.await(restart) == :ok
      :sys.get_state(rig.b)
      assert %{status: :running, trip: nil} = Runner.status(rig.runner)
      assert Runner.get!(rig.runner, "speed") == 1500
      assert :sys.get_state(rig.b).image == %{[0] => 1500, [1] => 5}
    end

    # Found by M4-6's eighth verification: a report in a device's mailbox as its reread
    # began, handled after the fence was set, was dropped whole, so one of a point the
    # read leaves out was lost; it is older than the read only where the read gives it.
    test "reports a device handles late, older than its restart's read, are dropped only " <>
           "where the read gives their points" do
      for {reread, want} <- [{%{}, {1500, 9}}, {%{[0] => 1200}, {1200, 9}}] do
        rig = pushed(%{[0] => 1000}, %{[0] => 1000, [1] => 5})
        Agent.update(rig.agent, &%{&1 | next: [reread]})
        :sys.suspend(rig.runner)
        restart = Task.async(fn -> Runner.restart(rig.runner, :cold) end)
        restart_waiting(rig.runner)
        send(rig.b, {:report, %{[1] => 6}})
        changes_waiting(rig.runner)

        for report <- [%{[1] => 7}, %{[0] => 1500, [1] => 8}, %{[1] => 9}],
            do: send(rig.b, {:report, report})

        :sys.resume(rig.runner)
        assert Task.await(restart) == :ok
        :sys.get_state(rig.b)

        # A round, and no poll of b.
        Manual.advance(rig.clock, 10)
        assert %{status: :running, trip: nil} = Runner.status(rig.runner)
        assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} == want
        {speed, load} = want
        assert :sys.get_state(rig.b).image == %{[0] => speed, [1] => load}
        Runner.stop(rig.runner)
      end
    end

    test "a report a device handles before its fence is older than a poll's read that " <>
           "came before it too, and supersedes it for none of its points" do
      rig = pushed(%{[0] => 1000}, %{[0] => 1000, [1] => 5})
      Agent.update(rig.agent, &%{&1 | next: [%{}, %{[0] => 1300}]})
      next = :sys.get_state(rig.b).next

      # a held inside its read, b suspended once released, its reread, a poll and a
      # report waiting in its mailbox in that order.
      :sys.suspend(rig.a)
      restart = Task.async(fn -> Runner.restart(rig.runner, :cold) end)
      called(rig.a)
      :sys.get_state(rig.b)
      :sys.suspend(rig.b)
      :sys.resume(rig.a)
      reread_waiting(rig.b)
      send(rig.b, {Logex.Runner.Device, :poll, next})
      send(rig.b, {:report, %{[0] => 1100, [1] => 9}})
      :sys.resume(rig.b)
      assert Task.await(restart) == :ok
      :sys.get_state(rig.b)

      # A round, and no poll of b.
      Manual.advance(rig.clock, 10)
      assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} == {1300, 9}
      assert :sys.get_state(rig.b).image == %{[0] => 1300, [1] => 9}
    end

    defp reread_waiting(device),
      do: reread_found(Process.info(device, :messages), device)

    defp reread_found({:messages, messages}, device),
      do: reread_seen(Enum.any?(messages, &match?({:"$gen_call", _, :reread}, &1)), device)

    defp reread_seen(true, _device), do: :ok
    defp reread_seen(false, device), do: reread_waiting(device)

    # Found by M4-6's eighth verification: a restart refused on another device ended b's
    # hold and dropped what it held, so a reading of a point its read leaves out, which a
    # moment before the release would have been taken while tripped, was lost.
    test "a restart refused on another device passes on what a device held since its " <>
           "release, and what it passed on before it" do
      for passed_before <- [false, true] do
        rig = pushed(%{}, %{[0] => 1000, [1] => 5})
        before_release(passed_before, rig)
        Sim.fail(rig.a, :read, {:value, [0], 7})
        assert {:error, {:io_init, "a", _}} = reported_in_window(rig, %{}, [%{[1] => 9}])
        :sys.get_state(rig.b)
        assert %{status: :tripped} = Runner.status(rig.runner)
        assert taken_while_tripped(rig) == {speed_before(passed_before), 9}

        assert Runner.restart(rig.runner, :cold) == :ok
        Manual.advance(rig.clock, 1000)

        assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} ==
                 {speed_before(passed_before), 9}

        Runner.stop(rig.runner)
      end
    end

    # A change of b passed on, its answer waiting behind a restart refused on a's read.
    defp before_release(false, _rig), do: :ok

    defp before_release(true, rig) do
      Sim.fail(rig.a, :read, {:value, [0], 7})
      :sys.suspend(rig.runner)
      restart = Task.async(fn -> Runner.restart(rig.runner, :cold) end)
      restart_waiting(rig.runner)
      send(rig.b, {:report, %{[0] => 1500}})
      changes_waiting(rig.runner)
      :sys.resume(rig.runner)
      assert {:error, {:io_init, "a", _}} = Task.await(restart)
      :sys.get_state(rig.b)
      assert taken_while_tripped(rig) == {1500, 5}
    end

    # The values a tripped runner has taken from b, which its next round's inputs merge.
    defp taken_while_tripped(rig),
      do: {:sys.get_state(rig.runner).values["speed"], :sys.get_state(rig.runner).values["load"]}

    defp speed_before(false), do: 1000
    defp speed_before(true), do: 1500

    test "a change the runner refuses drops the refused point's reading and passes on the " <>
           "rest at the device's next reading" do
      rig = pushed(%{}, %{[0] => 1000, [1] => 5})
      assert Runner.restart(rig.runner, :cold) == :ok
      send(rig.b, {:report, %{[0] => @too_fast, [1] => 6}})
      :sys.get_state(rig.b)
      assert {:io, "b", {:bad_value, [0], @too_fast}} = Runner.status(rig.runner).trip
      assert taken_while_tripped(rig) == {1000, 5}
      Manual.advance(rig.clock, 100)
      assert taken_while_tripped(rig) == {1000, 6}
      assert :sys.get_state(rig.b).image == %{[0] => 1000, [1] => 6}
    end

    # Decision 143's scenario as its record now states it: while tripped the host sees
    # the load from before the refused change, the good load or not, and a card that goes
    # on giving the bad speed gives the load no reading that passes, its restart refused.
    test "a tripped runner shows the load from before a change refused for its speed, and " <>
           "a card still bad passes the load on at no reading" do
      for {still_bad, taken, restarted} <- [
            {false, {1000, 6}, :ok},
            {true, {1000, 5}, {:error, {:io_init, "b", {:bad_value, [0], @too_fast}}}}
          ] do
        rig = pushed(%{}, %{[0] => 1000, [1] => 5})
        assert Runner.restart(rig.runner, :cold) == :ok
        Manual.advance(rig.clock, 10)
        assert Runner.get!(rig.runner, "load") == 5
        card(still_bad, rig.agent)
        send(rig.b, {:report, %{[0] => @too_fast, [1] => 6}})
        :sys.get_state(rig.b)
        assert {:io, "b", {:bad_value, [0], @too_fast}} = Runner.status(rig.runner).trip
        Manual.advance(rig.clock, 300)
        :sys.get_state(rig.b)
        assert taken_while_tripped(rig) == taken
        assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} == {1000, 5}
        assert Runner.restart(rig.runner, :cold) == restarted
        Runner.stop(rig.runner)
      end
    end

    # The card's polls: giving nothing, or the bad speed again.
    defp card(false, _agent), do: :ok
    defp card(true, agent), do: Agent.update(agent, &%{&1 | inputs: %{[0] => @too_fast}})

    test "reports between a device's release and its reread are superseded by the read " <>
           "where it gives their points and taken where it leaves them out, either way" do
      for {reread, want} <- [
            {%{[0] => 1200}, {1200, 6}},
            {%{[1] => 7}, {1100, 7}},
            {%{[0] => 1200, [1] => 7}, {1200, 7}},
            {%{}, {1100, 6}}
          ] do
        rig = pushed(%{[0] => 1000, [1] => 5}, %{})
        assert reported_in_window(rig, reread, [%{[0] => 1050, [1] => 6}, %{[0] => 1100}]) == :ok
        assert {Runner.get!(rig.runner, "speed"), Runner.get!(rig.runner, "load")} == want
        {speed, load} = want
        assert :sys.get_state(rig.b).image == %{[0] => speed, [1] => load}
        Runner.stop(rig.runner)
      end
    end

    # The third kind: a restart refused on b's reread, a second waiting behind it, so that
    # b, waiting on the runner throughout, is read again twice before it handles anything.
    defp refused_first(:before_a_refused_restart, runner, agent) do
      Agent.update(agent, &%{&1 | next: [%{[0] => @too_fast}]})
      second = Task.async(fn -> Runner.restart(runner, :cold) end)
      restarts_waiting(runner, 2)
      second
    end

    defp refused_first(_sent, _runner, _agent), do: nil

    defp second_restart(nil), do: :ok
    defp second_restart(second), do: Task.await(second)

    defp refused_restart(nil), do: :ok
    defp refused_restart(_second), do: {:error, {:io_init, "b", {:bad_value, [0], @too_fast}}}

    test "a device whose restart is refused goes on passing its changes on while tripped, " <>
           "as after any trip" do
      %{runner: runner, clock: clock, drive: drive} = tripped_on_speed([], 1)
      Sim.fail(drive, :read, {:error, :eio})
      assert Runner.restart(runner, :cold) == {:error, {:io_init, "drive", {:error, :eio}}}
      Sim.set(drive, [0], 1300)
      Manual.advance(clock, 10)
      drive_pid = device_pid(runner, "drive")
      assert :sys.get_state(drive_pid).image[[0]] == 1300
      assert :sys.get_state(runner).values["speed"] == 1300
    end

    @tag :tmp_dir
    test "a restart's read is each input point's last value from its device, which an " <>
           "unforce puts back",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, drive: drive} =
        tripped_on_speed([forces: Path.join(dir, "forces")], 1)

      :ok = Runner.force(runner, "speed", 5)
      Sim.set(drive, [0], 1300)
      assert Runner.restart(runner, :cold) == :ok
      assert Runner.get!(runner, "speed") == 5
      :ok = Runner.unforce(runner, "speed")
      Manual.advance(clock, 20)
      assert Runner.get!(runner, "speed") == 1300
    end
  end

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

  # Waits until a device's change waits in the runner's mailbox.
  # Waits until a sim, suspended, holds a call from its device.
  defp called(sim), do: call_found(Process.info(sim, :messages), sim)

  defp call_found({:messages, [{:"$gen_call", _, _} | _]}, _sim), do: :ok
  defp call_found({:messages, _}, sim), do: called(sim)

  # Waits until a sim has been read since it had been read `reads` times.
  defp read_since(sim, reads), do: read_found(Sim.reads(sim) > reads, sim, reads)

  defp read_found(true, _sim, _reads), do: :ok
  defp read_found(false, sim, reads), do: read_since(sim, reads)

  # Waits until a report's set is handled by its device, or its device passes a change on.
  defp reported_or_passed(task, runner),
    do: report_found(Task.yield(task, 1), Process.info(runner, :messages), task, runner)

  defp report_found({:ok, _}, _messages, _task, _runner), do: :ok

  defp report_found(nil, {:messages, messages}, task, runner),
    do:
      passed_found(
        Enum.any?(messages, &match?({:"$gen_call", _, {:changes, _, _, _}}, &1)),
        task,
        runner
      )

  defp passed_found(true, _task, _runner), do: :ok
  defp passed_found(false, task, runner), do: reported_or_passed(task, runner)

  # Waits, on the real clock, up to a second for the runner to trip.
  defp tripped(_runner, 1000), do: flunk("the runner did not trip")
  defp tripped(runner, n), do: trip_found(Runner.status(runner).trip, runner, n)

  defp trip_found(nil, runner, n), do: tripped(Process.sleep(1) && runner, n + 1)
  defp trip_found(_trip, _runner, _n), do: :ok

  defp changes_waiting(runner),
    do: changes_waited(Process.info(runner, :messages), runner)

  defp changes_waited({:messages, messages}, runner),
    do:
      changes_found(
        Enum.any?(messages, &match?({:"$gen_call", _, {:changes, _, _, _}}, &1)),
        runner
      )

  defp changes_found(true, _runner), do: :ok
  defp changes_found(false, runner), do: changes_waiting(runner)

  # Waits until n host's restarts wait in the runner's mailbox.
  defp restarts_waiting(runner, n),
    do: restarts_waited(Process.info(runner, :messages), runner, n)

  defp restarts_waited({:messages, messages}, runner, n),
    do:
      restarts_found(
        Enum.count(messages, &match?({:"$gen_call", _, {:restart, _}}, &1)) >= n,
        runner,
        n
      )

  defp restarts_found(true, _runner, _n), do: :ok
  defp restarts_found(false, runner, n), do: restarts_waiting(runner, n)

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
