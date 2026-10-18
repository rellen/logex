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
      refute_received {:trace, ^device, :receive, {:"$gen_cast", {:refresh, _}}}
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

  defp flush_traces(device) do
    receive do
      {:trace, ^device, _, _} -> flush_traces(device)
    after
      0 -> :ok
    end
  end

  # Waits until the runner holds a request in its queue.
  defp wait_queued(runner), do: queued(:queue.is_empty(:sys.get_state(runner).queue), runner)

  defp queued(true, runner), do: wait_queued(runner)
  defp queued(false, _runner), do: :ok
end
