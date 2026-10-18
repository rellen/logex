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

      assert Runner.start_link(opts) == {:error, {:io_init, "panel", :unplugged}}
      assert_receive {:EXIT, _runner, :normal}

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

      # One report with both: the trigger's round takes `x` too, and the relay, not due
      # at 0 once it has run, leaves `y` as it was.
      Sim.set(panel, %{[1] => 1})
      assert Runner.get!(runner, "x") == 1
      assert Runner.get!(runner, "hits") == 1
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
end
