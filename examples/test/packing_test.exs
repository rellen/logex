defmodule PackingTest do
  use ExUnit.Case, async: true

  alias Logex.IO.Sim
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  # Starts a manual clock, a simulated panel and a runner for 1 test.
  # The panel gets each failure of the list before the runner opens it.
  defp start_plant(failures) do
    {:ok, plant} = Logex.Configuration.compile_file("packing.logex")
    clock = start_supervised!(Manual)
    panel = start_supervised!({Sim, reports: true, clock: clock})
    for {callback, how} <- failures, do: Sim.fail(panel, callback, how)
    io = %{"panel" => {Sim, sim: panel}}
    runner = start_supervised!({Runner, configuration: plant, io: io, clock: {Manual, clock}})
    %{clock: clock, panel: panel, runner: runner}
  end

  describe "the packing line" do
    setup do: start_plant([])

    test "the start button starts the conveyor", %{clock: clock, panel: panel} do
      Sim.set(panel, "panel.i.0", 1)
      Manual.advance(clock, 10)
      assert %{"panel.q.0" => 1} = Sim.outputs(panel)
    end

    test "3 boxes fill the case", %{clock: clock, panel: panel, runner: runner} do
      for _box <- 1..3 do
        Sim.set(panel, "panel.i.8", 1)
        Manual.advance(clock, 2)
        Sim.set(panel, "panel.i.8", 0)
        Manual.advance(clock, 2)
      end

      assert Runner.get!(runner, "b1.count") == 3
      assert %{"panel.q.4" => 1} = Sim.outputs(panel)
    end

    test "c1 reads estop when its task runs at 20 ms", %{clock: clock, panel: panel} do
      Sim.set(panel, "panel.i.0", 1)
      Manual.advance(clock, 10)
      Sim.set(panel, "panel.i.0", 0)
      Manual.advance(clock, 2)
      Sim.set(panel, "panel.i.7", 1)
      Manual.advance(clock, 7)
      assert %{"panel.q.0" => 1} = Sim.outputs(panel)
      Manual.advance(clock, 1)
      assert %{"panel.q.0" => 0} = Sim.outputs(panel)
    end

    test "a failed read trips the runner", %{clock: clock, panel: panel, runner: runner} do
      Sim.set(panel, "panel.i.0", 1)
      Manual.advance(clock, 10)
      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert %{status: :tripped, trip: trip} = Runner.status(runner)
      assert trip == {:io, "panel", {:error, :eio}}
      assert Sim.outputs(panel) == %{"panel.q.0" => 0, "panel.q.4" => 0}
    end
  end

  describe "a panel whose first write takes 2 ms" do
    setup do: start_plant(write: {:delay, 2})

    test "a call from a task gets its answer", %{clock: clock, runner: runner} do
      task = Task.async(fn -> Runner.get!(runner, "b1.count") end)
      assert answer(task, clock) == 0
    end
  end

  # Moves the clock by 0 ms until the task has its answer.
  defp answer(task, clock), do: answered(Task.yield(task, 10), task, clock)

  defp answered({:ok, value}, _task, _clock), do: value

  defp answered(nil, task, clock) do
    Manual.advance(clock, 0)
    answer(task, clock)
  end
end
