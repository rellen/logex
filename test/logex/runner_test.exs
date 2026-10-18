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
end
