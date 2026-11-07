defmodule Logex.CeilingTest do
  @moduledoc """
  Decision 459 (RV-17): one ceiling a stage. Each test holds one stage's cost on a standard
  program, README's motor and plant as they stand at RV-17, under twice a figure recorded
  with it: the compile, a scan, a cycle and a round. A same-run bound (decision 357) holds
  a guarded path against a twin that makes every other call as often, so a cost both twins
  pay alike cancels out of it: each instruction dispatched, read or lowered, each cycle step
  or round step, made dearer across the board, turns no such bound red. A ceiling catches
  such a slowdown once it is gross, the stage past twice its figure, while a toolchain's
  shift of a reduction or two a step, which RV-7's probes charge, and a saving each leave
  it green. How a figure is recorded, and when and how a ceiling is raised, is
  `CONTRIBUTING.md`'s "Hold each stage under a ceiling twice its recorded figure".

  Each count is made in a process of its own whose heap no collection visits, the least
  of five, as the same-run bounds' are; a round's is the runner's own, the manual clock's
  synchronisation taken off as `retain_period_test.exs` takes it.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runner, Runtime}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  # The figures, recorded with this test (RV-17, 2026-11-07, Elixir 1.20.4 on OTP 28),
  # each the least of five counts, the round's the least of 1662 to 1672 in two runs; each
  # ceiling is twice its figure. A commit that raises one says why, and records the new
  # figure measured as this one was. Under each stage made three times as dear, two calls
  # a step each as dear as a step, each read 2.9 to 3.0 times its figure; under a step's
  # own call made once again, 1.2 to 1.8, and RV-7's probes, two reductions a step, at most
  # 1.09; each saving tried read less (`PLAN.md`'s RV-17).
  @figures %{compile: 8_649, scans: 44_606, cycles: 83_262, round: 1_662}

  # README's `motor.ld`.
  @motor """
  var_input start bool
  var_input stop bool
  var_input overtemp bool
  var_input reset bool
  var_output motor bool
  var_output run_lamp bool
  var_output speed_sp dint 1200
  var fault bool

  ( xic start | xic motor ) xio stop ote motor
  xic motor ote run_lamp
  xic overtemp otl fault
  xic reset otu fault
  xic fault move 0 speed_sp
  """

  # README's `plant.logex`: two instances of the motor, on a 10 ms task and a 50 ms one.
  @plant """
  task fast interval 10 priority 1
  task slow interval 50 priority 2

  var_global pb_start_1 bool at panel.i.0
  var_global pb_stop_1  bool at panel.i.1
  var_global tt_1       bool at panel.i.2
  var_global pb_start_2 bool at panel.i.3
  var_global pb_stop_2  bool at panel.i.4
  var_global pb_reset   bool at panel.i.5
  var_global k1         bool at panel.q.0
  var_global k2         bool at panel.q.1
  var_global sp_1       dint at drive.q.0
  var_global sp_2       dint at drive.q.1

  program m1 motor with fast
    m1.start    pb_start_1
    m1.stop     pb_stop_1
    m1.overtemp tt_1
    m1.reset    pb_reset
    m1.motor    k1
    m1.speed_sp sp_1

  program m2 motor with slow
    m2.start    pb_start_2
    m2.stop     pb_stop_2
    m2.overtemp 0
    m2.reset    0
    m2.motor    k2
    m2.speed_sp sp_2
  """

  defp motor do
    {:ok, motor} = Logex.compile(@motor, name: "motor")
    motor
  end

  defp plant do
    {:ok, plant} = Configuration.compile("plant", @plant, %{"motor" => motor()})
    plant
  end

  # A call's reductions, in a process of its own whose heap no collection visits.
  defp reductions(fun) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 8_000_000]
      )

    assert_receive {:reductions, r}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    r
  end

  defp least(fun), do: Enum.min(for _ <- 1..5, do: fun.())

  defp under_ceiling(stage, cost) do
    figure = Map.fetch!(@figures, stage)

    assert cost <= 2 * figure,
           "the #{stage} cost #{cost} reductions, past its ceiling of twice its figure, " <>
             "#{figure}: a gross slowdown, or a change that makes the stage dearer on " <>
             "purpose, which raises the figure and says why (CONTRIBUTING.md)"
  end

  test "the compile: README's motor.ld by Logex.compile/2" do
    under_ceiling(
      :compile,
      least(fn -> reductions(fn -> {:ok, _} = Logex.compile(@motor, name: "motor") end) end)
    )
  end

  test "a scan: 100 scans of README's motor, its start button toggled before each" do
    program = motor()
    state = Runtime.instance(program)

    scans = fn ->
      Enum.reduce(1..100, state, fn i, state ->
        state = Runtime.put_inputs(program, state, %{"start" => rem(i, 2)})
        {_outputs, state} = Runtime.scan(program, state, 10)
        state
      end)
    end

    under_ceiling(:scans, least(fn -> reductions(scans) end))
  end

  test "a cycle: 100 cycles of README's plant, 10 ms apart, both start buttons toggled" do
    runtime = Runtime.start(plant())

    cycles = fn ->
      Enum.reduce(1..100, runtime, fn i, runtime ->
        inputs = %{"pb_start_1" => rem(i, 2), "pb_start_2" => rem(i, 2)}
        {runtime, _outputs, _events} = Runtime.cycle(runtime, 10, inputs)
        runtime
      end)
    end

    under_ceiling(:cycles, least(fn -> reductions(cycles) end))
  end

  # The runner's reductions a round over 200 rounds of README's plant on the manual clock,
  # a panel and a drive simulated, both start buttons toggled every 100 ms, less what the
  # clock's synchronisation costs the runner a round: `Manual.advance/2` follows each timer
  # it delivers with `:sys.get_state/2`, whose answer copies the runner's state, the
  # test's cost and never a round's, measured on the same runner just after, the mean of
  # 200 answers (`retain_period_test.exs`, RV-7).
  defp own_round(plant) do
    {:ok, clock} = Manual.start_link()
    {:ok, panel} = Sim.start_link(clock: clock)
    {:ok, drive} = Sim.start_link(clock: clock)

    {:ok, runner} =
      Runner.start_link(
        configuration: plant,
        io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
        clock: {Manual, clock}
      )

    Manual.advance(clock, 100)
    {:reductions, a} = Process.info(runner, :reductions)
    rounds = Runner.status(runner).rounds

    for i <- 1..20 do
      Sim.set(panel, %{[0] => rem(i, 2), [3] => rem(i, 2)})
      Manual.advance(clock, 100)
    end

    {:reductions, b} = Process.info(runner, :reductions)
    rounds = Runner.status(runner).rounds - rounds
    {:reductions, c} = Process.info(runner, :reductions)
    for _ <- 1..200, do: :sys.get_state(runner)
    {:reductions, d} = Process.info(runner, :reductions)
    assert Runner.stop(runner) == :ok
    for pid <- [panel, drive, clock], do: GenServer.stop(pid)
    assert rounds == 200
    (b - a) / rounds - (d - c) / 200
  end

  test "a round: README's plant on the runner, its own reductions a round" do
    plant = plant()
    under_ceiling(:round, least(fn -> own_round(plant) end))
  end
end
