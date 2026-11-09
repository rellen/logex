defmodule Logex.CeilingTest do
  @moduledoc """
  Decision 459 (RV-17): one ceiling a stage. Each test holds one stage's cost on a standard
  program, README's motor and plant as they stand at RV-17, under twice a figure recorded
  with it: the compile, a scan, a cycle and a round. A same-run bound (decision 357) holds
  a guarded path against a twin that makes every other call as often, so a cost both twins
  pay alike cancels out of it: each instruction dispatched, read or lowered, each cycle step
  or round step, made dearer across the board, turns no such bound red. A ceiling catches
  such a slowdown once it is gross, the stage at twice its figure or past it, while a
  toolchain's shift of a reduction or two a step, which RV-7's probes charge, and a saving
  each leave it green. How a figure is recorded, and when and how a ceiling is raised, is
  `CONTRIBUTING.md`'s "Hold each stage under a ceiling twice its recorded figure".

  Since RV-17's review each stage is held twice: whole, on the motor and the plant as
  README has them, which holds what the stage pays a call and a tag, a compile's
  declarations, a scan's checks of its state, a cycle's connections, a round's devices,
  the most of its cost; and a rung, the same stage over the motor with its five rungs
  written sixteen times over less the same over eight, a rung of the forty between them,
  its tags the motor's at both, so that what the stage pays a call or a tag cancels and
  what it pays a rung, its lowering or its evaluation, is held at its own size. On the
  motor a rung's evaluation is a sixth of a scan, so that every instruction evaluated four
  times over read 1.44 of the whole scan's figure, under its ceiling (the review's probe),
  and reads 2.25 a rung, past it.

  Each count is made in a process of its own whose heap no collection visits, the least of
  five, as the same-run bounds' are, and a rung's the least of five differences, each pair
  counted one after the other; a round's is the runner's own, the manual clock's
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

  # A rung's figures, recorded with this test (RV-17's review, 2026-11-08, Elixir 1.20.4 on
  # OTP 28): each stage over the motor's rungs written sixteen times over less the same over
  # eight, the least of five differences, a rung of the forty between them, the same on
  # six runs, the round's 37.49 to 37.57; each ceiling twice its figure (decision 481:
  # each stage held whole and a rung). Under a rung's evaluation made dearer across the board,
  # each instruction evaluated four times over or each element 20 reductions dearer, a
  # rung of a scan, a cycle and a round read 2.25 and 2.75 its figure, red, and a rung's
  # lowering made three times over 1.86; each element evaluated once again read 1.96 to
  # 2.0, on the line, and RV-7's probes, two reductions an element, 1.25; each saving
  # tried read less (`PLAN.md`'s RV-17).
  @rung_figures %{compile: 999.2, scans: 3_110.0, cycles: 3_762.9, round: 37.5}

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

  # The times over the motor's rungs are written for a rung's cost, the few and the many.
  @few 8
  @many 16

  defp motor, do: motor(@motor)

  defp motor(source) do
    {:ok, motor} = Logex.compile(source, name: "motor")
    motor
  end

  defp plant, do: plant(motor())

  defp plant(motor) do
    {:ok, plant} = Configuration.compile("plant", @plant, %{"motor" => motor})
    plant
  end

  # README's motor with its five rungs written `times` over, its declarations as they are,
  # so that what a stage pays a tag, a compile's declarations, a scan's checks of its state
  # and its outputs, a cycle's connections, is the same at any `times`, and a rung more
  # costs a rung's work alone.
  defp rewritten(times) do
    [declarations, rungs] = String.split(@motor, "\n\n")
    declarations <> "\n\n" <> String.duplicate(rungs, times)
  end

  # The few's and the many's sources, and what `make` makes of each motor compiled.
  defp sources, do: Map.new([@few, @many], &{&1, rewritten(&1)})
  defp both(make), do: Map.new(sources(), fn {times, source} -> {times, make.(motor(source))} end)

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

  # A stage's cost a rung: its count over the many less its count over the few, the two
  # counted one after the other, the least of five differences, a rung of those between.
  defp a_rung(made, count) do
    differences =
      for _ <- 1..5, do: -count.(Map.fetch!(made, @few)) + count.(Map.fetch!(made, @many))

    Enum.min(differences) / (5 * (@many - @few))
  end

  defp under_ceiling(stage, cost), do: under(stage, cost, Map.fetch!(@figures, stage), "")

  defp under_ceiling(stage, :rung, cost),
    do: under(stage, cost, Map.fetch!(@rung_figures, stage), " a rung")

  defp under(stage, cost, figure, unit) do
    assert cost < 2 * figure,
           "the #{stage} cost #{cost} reductions#{unit}, at or past its ceiling of twice " <>
             "its figure, #{figure}: a gross slowdown, or a change that makes the stage " <>
             "dearer on purpose, which raises the figure and says why (CONTRIBUTING.md)"
  end

  # A motor's source compiled.
  defp compiled(source), do: fn -> {:ok, _} = Logex.compile(source, name: "motor") end

  test "the compile: README's motor.ld by Logex.compile/2, and a rung of it" do
    under_ceiling(:compile, least(fn -> reductions(compiled(@motor)) end))
    under_ceiling(:compile, :rung, a_rung(sources(), &reductions(compiled(&1))))
  end

  # 100 scans of a motor, its start button toggled before each.
  defp scans(program) do
    state = Runtime.instance(program)

    fn ->
      Enum.reduce(1..100, state, fn i, state ->
        state = Runtime.put_inputs(program, state, %{"start" => rem(i, 2)})
        {_outputs, state} = Runtime.scan(program, state, 10)
        state
      end)
    end
  end

  test "a scan: 100 scans of README's motor, its start button toggled before each, and a " <>
         "rung of them" do
    under_ceiling(:scans, least(fn -> reductions(scans(motor())) end))
    under_ceiling(:scans, :rung, a_rung(both(& &1), &reductions(scans(&1))))
  end

  # 100 cycles of a plant, 10 ms apart, both start buttons toggled.
  defp cycles(plant) do
    runtime = Runtime.start(plant)

    fn ->
      Enum.reduce(1..100, runtime, fn i, runtime ->
        inputs = %{"pb_start_1" => rem(i, 2), "pb_start_2" => rem(i, 2)}
        {runtime, _outputs, _events} = Runtime.cycle(runtime, 10, inputs)
        runtime
      end)
    end
  end

  test "a cycle: 100 cycles of README's plant, 10 ms apart, both start buttons toggled, and " <>
         "a rung of them" do
    under_ceiling(:cycles, least(fn -> reductions(cycles(plant())) end))
    under_ceiling(:cycles, :rung, a_rung(both(&plant/1), &reductions(cycles(&1))))
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

  test "a round: README's plant on the runner, its own reductions a round, and a rung of it" do
    plant = plant()
    under_ceiling(:round, least(fn -> own_round(plant) end))
    under_ceiling(:round, :rung, a_rung(both(&plant/1), &own_round/1))
  end
end
