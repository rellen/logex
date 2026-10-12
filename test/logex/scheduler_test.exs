defmodule Logex.SchedulerTest do
  @moduledoc """
  M2-1: the rules of a cycle (`Logex.Runtime`'s moduledoc; `docs/organisation.md` §4.6),
  one test at least for each, driven through the public API from configurations built in
  Elixir. The messages a host's mistakes raise are in `runtime_test.exs`, the
  configuration's diagnostics in `configuration_test.exs`, and PLAN.md M2-1's Done-when in
  `end_to_end_test.exs`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.{Connection, Global, Instance}

  # One var_input copied to one var_output.
  @relay "var_input in bool\nvar_output out bool\nxic in ote out"

  # A one-shot on its input: no power on an instance's first scan (M1-6), whatever `in`.
  @pulse "var_input in bool\nvar_output out bool\nvar s bool\nxic in ons s ote out"

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  defp task(name, interval, priority),
    do: %Configuration.Task{name: name, interval: interval, priority: priority}

  defp wire(instance, input, output),
    do: [
      %Connection{instance: instance, member: "in", to: input},
      %Connection{instance: instance, member: "out", to: output}
    ]

  defp ran(events), do: for({:ran, task, instance, now} <- events, do: {task, instance, now})

  # Cycles at the given elapsed times, from a fresh start: the events of each.
  defp events_of(config, steps) do
    {events, _runtime} =
      Enum.map_reduce(steps, Runtime.start(config), fn elapsed, runtime ->
        {runtime, _outputs, events} = Runtime.cycle(runtime, elapsed, %{})
        {events, runtime}
      end)

    events
  end

  # `p`, a one-shot on the 10 ms task, drives the output point `y`; `inv`, task-less,
  # drives the unlocated `g`, whose initial value is 1, with the inverse of `x`.
  defp plant do
    inverter = program("var_input in bool\nvar_output out bool\nxio in ote out", "inverter")

    Configuration.new!(
      name: "plant",
      programs: [program(@pulse, "pulse"), inverter],
      tasks: [task("t", 10, 0)],
      globals: [
        %Global{name: "x", type: :bool, at: "panel.i.0"},
        %Global{name: "y", type: :bool, at: "panel.q.0"},
        %Global{name: "g", type: :bool, initial: 1}
      ],
      instances: [
        %Instance{name: "p", type: "pulse", task: "t"},
        %Instance{name: "inv", type: "inverter"}
      ],
      connections: wire("p", "x", "y") ++ wire("inv", "x", "g")
    )
  end

  describe "start/1" do
    test "every global at its initial value, 0 without one, at time 0, every task due" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("fast", 10, 0)],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "g", type: :bool, initial: 1},
            %Global{name: "sp", type: :dint, initial: 1200},
            %Global{name: "y", type: :bool, at: "panel.q.0"}
          ],
          instances: [%Instance{name: "r", type: "relay", task: "fast"}],
          connections: wire("r", "g", "y")
        )

      runtime = Runtime.start(config)
      assert {Runtime.get!(runtime, "x"), Runtime.get!(runtime, "g")} == {0, 1}
      assert {Runtime.get!(runtime, "sp"), Runtime.get!(runtime, "y")} == {1200, 0}
      assert Runtime.get!(runtime, "r.out") == 0
      assert Runtime.next_due_in(runtime) == 0
      assert Runtime.overlaps(runtime) == %{"fast" => 0}

      # Time 0: the first cycle, with no time elapsed, is at 0 ms.
      assert {_runtime, %{"y" => 1}, [{:ran, "fast", "r", 0}]} = Runtime.cycle(runtime, 0, %{})
    end

    # Configuration.initial/1 is the one rule for a global's value where nothing has set
    # it: start/1 starts every global by it, and restart/2 every global but an input point.
    test "starts every global by the one rule" do
      config = plant()
      runtime = Runtime.start(config)

      assert Map.new(config.globals, &{&1.name, Runtime.get!(runtime, &1.name)}) ==
               Map.new(config.globals, &{&1.name, Configuration.initial(&1)})
    end

    # Fix F14: start/1 builds each instance as Runtime.instance/1 does, so its first scan
    # is a first scan, and an `ons` passes no power on it.
    test "builds each instance as instance/1 does: its first scan is a first scan" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@pulse, "pulse")],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "y", type: :bool, at: "panel.q.0"}
          ],
          instances: [%Instance{name: "p", type: "pulse"}],
          connections: wire("p", "x", "y")
        )

      {runtime, outputs, _} = Runtime.cycle(Runtime.start(config), 0, %{"x" => 1})
      assert outputs == %{"y" => 0}
      {runtime, outputs, _} = Runtime.cycle(runtime, 10, %{"x" => 0})
      assert outputs == %{"y" => 0}
      {_runtime, outputs, _} = Runtime.cycle(runtime, 10, %{"x" => 1})
      assert outputs == %{"y" => 1}
    end
  end

  describe "the input image" do
    setup do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          globals: [
            %Global{name: "a", type: :bool, at: "panel.i.0"},
            %Global{name: "b", type: :bool, at: "panel.i.1"},
            %Global{name: "ya", type: :bool, at: "panel.q.0"},
            %Global{name: "yb", type: :bool, at: "panel.q.1"}
          ],
          instances: [%Instance{name: "ra", type: "relay"}, %Instance{name: "rb", type: "relay"}],
          connections: wire("ra", "a", "ya") ++ wire("rb", "b", "yb")
        )

      %{runtime: Runtime.start(config)}
    end

    test "keeps each input point's value between cycles: a host sends only what changed",
         %{runtime: runtime} do
      {runtime, outputs, _} = Runtime.cycle(runtime, 0, %{"a" => 1, "b" => 1})
      assert outputs == %{"ya" => 1, "yb" => 1}
      {runtime, outputs, _} = Runtime.cycle(runtime, 10, %{"b" => 0})
      assert outputs == %{"ya" => 1, "yb" => 0}
      {_runtime, outputs, _} = Runtime.cycle(runtime, 10, %{})
      assert outputs == %{"ya" => 1, "yb" => 0}
    end

    test "a refused cycle changes nothing: the runtime is a value", %{runtime: runtime} do
      assert_raise ArgumentError, fn -> Runtime.cycle(runtime, 0, %{"a" => 1, "zz" => 1}) end
      {_runtime, outputs, _} = Runtime.cycle(runtime, 0, %{})
      assert outputs == %{"ya" => 0, "yb" => 0}
    end
  end

  describe "copy in and copy out" do
    test "a var_input tied to a constant reads it at every scan" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          globals: [%Global{name: "y", type: :bool, at: "panel.q.0"}],
          instances: [%Instance{name: "r", type: "relay"}],
          connections: [
            %Connection{instance: "r", member: "in", to: 1},
            %Connection{instance: "r", member: "out", to: "y"}
          ]
        )

      assert {_, %{"y" => 1}, _} = Runtime.cycle(Runtime.start(config), 0, %{})
    end

    test "a var_output drives every global it is connected to; an output point no " <>
           "connection drives stays 0; an unlocated global is never an output" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "y1", type: :bool, at: "panel.q.0"},
            %Global{name: "y2", type: :bool, at: "panel.q.1"},
            %Global{name: "spare", type: :bool, at: "panel.q.2"},
            %Global{name: "g", type: :bool}
          ],
          instances: [%Instance{name: "r", type: "relay"}],
          connections:
            wire("r", "x", "y1") ++
              [
                %Connection{instance: "r", member: "out", to: "y2"},
                %Connection{instance: "r", member: "out", to: "g"}
              ]
        )

      {runtime, outputs, _} = Runtime.cycle(Runtime.start(config), 0, %{"x" => 1})
      assert outputs == %{"y1" => 1, "y2" => 1, "spare" => 0}
      assert Runtime.get!(runtime, "g") == 1
    end

    test "an instance sees what an earlier one wrote in the cycle, and never what a later " <>
           "one writes until the next cycle" do
      chain = fn order ->
        instances = for name <- order, do: %Instance{name: name, type: "relay"}

        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "g", type: :bool},
            %Global{name: "y", type: :bool, at: "panel.q.0"}
          ],
          instances: instances,
          connections: wire("first", "x", "g") ++ wire("second", "g", "y")
        )
      end

      # `first` writes g, then `second` reads it: in the same cycle.
      assert {_, %{"y" => 1}, _} =
               Runtime.cycle(Runtime.start(chain.(~w(first second))), 0, %{"x" => 1})

      # Declared the other way round, `second` reads g before `first` writes it: the next
      # cycle.
      {runtime, outputs, _} =
        Runtime.cycle(Runtime.start(chain.(~w(second first))), 0, %{"x" => 1})

      assert outputs == %{"y" => 0}
      assert {_, %{"y" => 1}, _} = Runtime.cycle(runtime, 0, %{})
    end

    test "two instances of one program keep independent state" do
      latch = program("var_input set bool\nvar_output q bool\nxic set otl q", "latch")

      config =
        Configuration.new!(
          name: "plant",
          programs: [latch],
          globals: [
            %Global{name: "s1", type: :bool, at: "panel.i.0"},
            %Global{name: "s2", type: :bool, at: "panel.i.1"},
            %Global{name: "q1", type: :bool, at: "panel.q.0"},
            %Global{name: "q2", type: :bool, at: "panel.q.1"}
          ],
          instances: [%Instance{name: "l1", type: "latch"}, %Instance{name: "l2", type: "latch"}],
          connections:
            for(
              {i, s, q} <- [{"l1", "s1", "q1"}, {"l2", "s2", "q2"}],
              c <- [
                %Connection{instance: i, member: "set", to: s},
                %Connection{instance: i, member: "q", to: q}
              ],
              do: c
            )
        )

      {runtime, outputs, _} = Runtime.cycle(Runtime.start(config), 0, %{"s1" => 1})
      assert outputs == %{"q1" => 1, "q2" => 0}
      {_runtime, outputs, _} = Runtime.cycle(runtime, 10, %{"s1" => 0})
      assert outputs == %{"q1" => 1, "q2" => 0}
    end
  end

  describe "due tasks and their order" do
    # Three tasks of one priority: `b` and `c` due at 0 and every 20 ms, `a`, declared last,
    # every 30 ms.
    defp ties do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [task("b", 20, 5), task("c", 20, 5), task("a", 30, 5)],
        instances: for(t <- ~w(a b c), do: %Instance{name: "i" <> t, type: "relay", task: t}),
        connections: for(t <- ~w(a b c), do: %Connection{instance: "i" <> t, member: "in", to: 0})
      )
    end

    test "of one priority, the earlier due time runs first, then the order declared" do
      [first, _at10, _at20, at40] = events_of(ties(), [0, 10, 10, 20])

      # At 0 all are due at 0: declaration order.
      assert ran(first) == [{"b", "ib", 0}, {"c", "ic", 0}, {"a", "ia", 0}]

      # At 40, late: `a` was due at 30, `b` and `c` at 40, so `a`, declared last, waited
      # longest and runs first.
      assert ran(at40) == [{"a", "ia", 40}, {"b", "ib", 40}, {"c", "ic", 40}]

      # At 60 all were due at 60: declaration order again; at 80, `b` and `c`, due at 80,
      # run, and `a`, next at 90, does not.
      [_, _, at60, at80] = events_of(ties(), [0, 40, 20, 20])
      assert ran(at60) == [{"b", "ib", 60}, {"c", "ic", 60}, {"a", "ia", 60}]
      assert ran(at80) == [{"b", "ib", 80}, {"c", "ic", 80}]
    end

    test "a higher priority, the lower number, runs before an earlier due time" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("low", 10, 2), task("high", 25, 1)],
          instances: [
            %Instance{name: "l", type: "relay", task: "low"},
            %Instance{name: "h", type: "relay", task: "high"}
          ],
          connections: for(i <- ~w(l h), do: %Connection{instance: i, member: "in", to: 0})
        )

      # At 50 `low` has waited since 40, `high` since 50: priority first all the same.
      [_, _, at50] = events_of(config, [0, 30, 20])
      assert ran(at50) == [{"high", "h", 50}, {"low", "l", 50}]
    end

    test "task-less instances run last, once in every cycle, an elapsed 0 one included, " <>
           "where a periodic task runs once per period" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("t", 10, 0)],
          instances: [
            %Instance{name: "free", type: "relay"},
            %Instance{name: "timed", type: "relay", task: "t"}
          ],
          connections: for(i <- ~w(free timed), do: %Connection{instance: i, member: "in", to: 0})
        )

      assert Enum.map(events_of(config, [0, 0, 5, 5, 0]), &ran/1) == [
               [{"t", "timed", 0}, {:none, "free", 0}],
               [{:none, "free", 0}],
               [{:none, "free", 5}],
               [{"t", "timed", 10}, {:none, "free", 10}],
               [{:none, "free", 10}]
             ]
    end
  end

  describe "the order of instances" do
    # Execution order is the configuration's list (docs/organisation.md §4.9), never a
    # name's order nor a map's: so the instances here are declared against the order of
    # their names, and 40 of them, past the 32 keys a map iterates in key order.
    defp ordered(on_task, taskless) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [task("t", 10, 0)],
        instances:
          for(n <- on_task, do: %Instance{name: n, type: "relay", task: "t"}) ++
            for(n <- taskless, do: %Instance{name: n, type: "relay"}),
        connections:
          for(n <- on_task ++ taskless, do: %Connection{instance: n, member: "in", to: 0})
      )
    end

    test "a task's instances, and the task-less ones, run in the order declared" do
      [events] = events_of(ordered(~w(zeta alpha mid), ~w(omega beta)), [0])

      assert ran(events) == [
               {"t", "zeta", 0},
               {"t", "alpha", 0},
               {"t", "mid", 0},
               {:none, "omega", 0},
               {:none, "beta", 0}
             ]
    end

    test "in the order declared past 32 instances" do
      names = fn prefix ->
        for i <- 40..1//-1, do: prefix <> String.pad_leading("#{i}", 2, "0")
      end

      [events] = events_of(ordered(names.("a"), names.("b")), [0])

      assert ran(events) ==
               for(n <- names.("a"), do: {"t", n, 0}) ++ for(n <- names.("b"), do: {:none, n, 0})
    end
  end

  describe "restart/2" do
    test "starts the resource again, keeping the clock and the input image" do
      runtime = Runtime.start(plant())
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 1})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"x" => 0})

      # Late, at 45 ms: two periods missed, and the one-shot sees `x` rise.
      {runtime, outputs, _} = Runtime.cycle(runtime, 35, %{"x" => 1})
      assert outputs == %{"y" => 1}
      assert {Runtime.get!(runtime, "g"), Runtime.get!(runtime, "p.out")} == {0, 1}
      assert Runtime.overlaps(runtime) == %{"t" => 2}

      runtime = Runtime.restart(runtime, :cold)

      # The input image is kept; every other global is back at its initial value, each
      # instance is restarted, no overlap is counted, and every task is due at once.
      assert Runtime.get!(runtime, "x") == 1
      assert {Runtime.get!(runtime, "g"), Runtime.get!(runtime, "y")} == {1, 0}
      assert Runtime.get!(runtime, "p.out") == 0
      assert Runtime.overlaps(runtime) == %{"t" => 0}
      assert Runtime.next_due_in(runtime) == 0

      # The clock is kept: the next cycle, at elapsed 0, runs the task at 45 ms, and the
      # task-less instance reads the kept `x`.
      {runtime, outputs, events} = Runtime.cycle(runtime, 0, %{})
      assert events == [{:ran, "t", "p", 45}, {:ran, :none, "inv", 45}]
      assert {outputs, Runtime.get!(runtime, "g")} == {%{"y" => 0}, 0}
      assert Runtime.next_due_in(runtime) == 10
      assert Runtime.restart(runtime, :warm) == Runtime.restart(runtime, :cold)
    end

    # Configuration.initial/1, the one rule, puts back every global but an input point.
    test "puts every global but an input point back by the one rule" do
      config = plant()
      runtime = Runtime.start(config)
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"x" => 1})
      assert {Runtime.get!(runtime, "y"), Runtime.get!(runtime, "g")} == {1, 0}
      runtime = Runtime.restart(runtime, :cold)

      assert Map.new(config.globals, &{&1.name, Runtime.get!(runtime, &1.name)}) ==
               Map.new(config.globals, &{&1.name, Configuration.initial(&1)})
               |> Map.put("x", 1)
    end

    test "leaves a runtime of plain data" do
      {runtime, _, _} = Runtime.cycle(Runtime.start(plant()), 0, %{"x" => 1})
      assert impure(Runtime.restart(runtime, :cold)) == []
    end

    # Its first scan after the restart is a first scan: the one-shot passes no power on it
    # though its input rose since the last scan.
    test "each instance's next scan is a first scan" do
      runtime = Runtime.start(plant())
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"x" => 0})
      runtime = Runtime.restart(runtime, :cold)
      {_runtime, outputs, _} = Runtime.cycle(runtime, 0, %{"x" => 1})
      assert outputs == %{"y" => 0}
    end
  end

  describe "missed periods" do
    defp one_task(interval) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [task("t", interval, 0)],
        instances: [%Instance{name: "r", type: "relay", task: "t"}],
        connections: [%Connection{instance: "r", member: "in", to: 0}]
      )
    end

    test "are counted, not run again, and the phase is kept" do
      # Due at 10, the cycle comes at 47: the periods at 10, 20 and 30 are missed, the run
      # at 47 is the 40 ms one, and the next is due at 50.
      runtime = Runtime.start(one_task(10))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{})
      {runtime, _, events} = Runtime.cycle(runtime, 47, %{})
      assert events == [{:overlap, "t", 3}, {:ran, "t", "r", 47}]
      assert Runtime.next_due_in(runtime) == 3
      assert Runtime.overlaps(runtime) == %{"t" => 3}

      {runtime, _, events} = Runtime.cycle(runtime, 3, %{})
      assert events == [{:ran, "t", "r", 50}]
      {runtime, _, events} = Runtime.cycle(runtime, 25, %{})
      assert events == [{:overlap, "t", 1}, {:ran, "t", "r", 75}]
      assert Runtime.overlaps(runtime) == %{"t" => 4}
    end

    # Every periodic task is due at 0, at start (§4.6): a first cycle later than that
    # missed the periods before it, and says so.
    test "a first cycle after the start reports the periods before it" do
      {_runtime, _, events} = Runtime.cycle(Runtime.start(one_task(10)), 25, %{})
      assert events == [{:overlap, "t", 2}, {:ran, "t", "r", 25}]
    end

    test "a task with no instance keeps its time and its count, and runs nothing" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("idle", 10, 0)],
          instances: [%Instance{name: "r", type: "relay"}],
          connections: [%Connection{instance: "r", member: "in", to: 0}]
        )

      runtime = Runtime.start(config)
      {runtime, _, events} = Runtime.cycle(runtime, 0, %{})
      assert events == [{:ran, :none, "r", 0}]
      assert Runtime.next_due_in(runtime) == 10
      {runtime, _, events} = Runtime.cycle(runtime, 30, %{})
      assert events == [{:overlap, "idle", 2}, {:ran, :none, "r", 30}]
      assert Runtime.overlaps(runtime) == %{"idle" => 2}
    end
  end

  describe "next_due_in/1" do
    test "is when a periodic task is next due, never a task-less instance" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("a", 30, 0), task("b", 20, 1)],
          instances: [
            %Instance{name: "ra", type: "relay", task: "a"},
            %Instance{name: "rb", type: "relay", task: "b"},
            %Instance{name: "free", type: "relay"}
          ],
          connections: for(i <- ~w(ra rb free), do: %Connection{instance: i, member: "in", to: 0})
        )

      runtime = Runtime.start(config)
      assert Runtime.next_due_in(runtime) == 0

      dues =
        Enum.map_reduce([0, 7, 13, 5, 35], runtime, fn elapsed, runtime ->
          {runtime, _, _} = Runtime.cycle(runtime, elapsed, %{})
          {Runtime.next_due_in(runtime), runtime}
        end)
        |> elem(0)

      # At 0, both ran: b next at 20. At 7: 13 to go. At 20, b ran: a at 30, b at 40. At
      # 25: 5. At 60 both ran, a missing 30 (due 30, ran 60 → next 90) and b (due 40, ran
      # 60 → next 80).
      assert dues == [20, 13, 10, 5, 20]
    end

    test "is :infinity for a configuration of task-less instances alone" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          instances: [%Instance{name: "r", type: "relay"}],
          connections: [%Connection{instance: "r", member: "in", to: 0}]
        )

      runtime = Runtime.start(config)
      assert Runtime.next_due_in(runtime) == :infinity
      assert Runtime.overlaps(runtime) == %{}
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{})
      assert Runtime.next_due_in(runtime) == :infinity
    end
  end

  describe "plain data" do
    # A %Logex.Runtime{} is plain data (docs/organisation.md §4.9): no function, pid,
    # reference or port anywhere in it, so it can be stored, compared, sent and replayed.
    # The test looks inside the opaque struct on purpose.
    defp impure(term) when is_function(term) or is_pid(term) or is_reference(term),
      do: [term]

    defp impure(term) when is_port(term), do: [term]
    defp impure(%_{} = struct), do: impure(Map.from_struct(struct))
    defp impure(map) when is_map(map), do: Enum.flat_map(map, &impure(Tuple.to_list(&1)))
    defp impure([head | tail]), do: impure(head) ++ impure(tail)
    defp impure(tuple) when is_tuple(tuple), do: impure(Tuple.to_list(tuple))
    defp impure(_plain), do: []

    test "a runtime holds nothing but plain data, at start and after cycles" do
      runtime = Runtime.start(plant())
      assert impure(runtime) == []
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 1})
      {runtime, _, _} = Runtime.cycle(runtime, 25, %{"x" => 0})
      assert impure(runtime) == []
    end
  end

  describe "a cycle" do
    test "is a function of its arguments: made twice, it gives the same result" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("t", 10, 0)],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "y", type: :bool, at: "panel.q.0"}
          ],
          instances: [%Instance{name: "r", type: "relay", task: "t"}],
          connections: wire("r", "x", "y")
        )

      runtime = Runtime.start(config)
      assert Runtime.cycle(runtime, 15, %{"x" => 1}) == Runtime.cycle(runtime, 15, %{"x" => 1})
      assert Runtime.start(config) == runtime
    end
  end

  # M2-4 (docs/organisation.md §4.10, decisions 46, 47 and 49): one copy of each global.
  # The scheduler merges each var_external's global into its instance's state before
  # call/4 and splits it off after, into the global, before the copy-out.
  describe "a global shared through var_external" do
    # Copies `x`, read through a var_external, to `g`, written through one.
    @copier "var_external x bool\nvar_external g bool\nxic x ote g"

    # Reads `g` through a var_external into its output.
    @reader "var_output out bool\nvar_external g bool\nxic g ote out"

    defp copier_and_reader(order) do
      programs = [program(@copier, "copier"), program(@reader, "reader")]
      instances = for {name, type} <- order, do: %Instance{name: name, type: type}

      Configuration.new!(
        name: "plant",
        programs: programs,
        globals: [
          %Global{name: "x", type: :bool, at: "panel.i.0"},
          %Global{name: "g", type: :bool, initial: 1},
          %Global{name: "y", type: :bool, at: "panel.q.0"}
        ],
        instances: instances,
        connections: [%Connection{instance: "r", member: "out", to: "y"}]
      )
    end

    # The opaque resource, looked into on purpose (decision 49): one copy of each global
    # means no instance's state holds a var_external between cycles, which no public call
    # can see, since every merge overwrites a stale copy and get/2 reads the global.
    defp held(%Runtime{instances: instances}, name),
      do: for({instance, state} <- instances, Map.has_key?(state.env, name), do: instance)

    test "no instance's state holds one between cycles: start/1, a cycle and restart/2 " <>
           "keep the one copy, the resource's" do
      runtime = Runtime.start(copier_and_reader([{"c", "copier"}, {"r", "reader"}]))
      assert {held(runtime, "x"), held(runtime, "g")} == {[], []}
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 1})
      assert {held(runtime, "x"), held(runtime, "g")} == {[], []}
      runtime = Runtime.restart(runtime, :cold)
      assert {held(runtime, "x"), held(runtime, "g")} == {[], []}
      # Each instance's own tags stay in its state.
      assert Map.keys(runtime.instances["r"].env) == ["out"]
    end

    test "an instance reads and writes the global itself: what an earlier one wrote in the " <>
           "cycle, and a later one's in the next" do
      # The copier first: the reader sees `g` as it wrote it, in the same cycle.
      runtime = Runtime.start(copier_and_reader([{"c", "copier"}, {"r", "reader"}]))
      {runtime, first, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      {_runtime, second, _} = Runtime.cycle(runtime, 10, %{"x" => 1})
      assert {first, second} == {%{"y" => 0}, %{"y" => 1}}

      # The reader first: it sees `g` at its initial value, 1, then the copier's 0 a cycle
      # late.
      runtime = Runtime.start(copier_and_reader([{"r", "reader"}, {"c", "copier"}]))
      {runtime, first, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      {runtime, second, _} = Runtime.cycle(runtime, 10, %{"x" => 1})
      {_runtime, third, _} = Runtime.cycle(runtime, 10, %{})
      assert {first, second, third} == {%{"y" => 1}, %{"y" => 0}, %{"y" => 1}}
    end

    test "a connection's copy-out lands after a write through a var_external to one global " <>
           "(decision 47)" do
      both = program("var_output q bool\nvar_external g bool\notl g\notu q", "both")

      config =
        Configuration.new!(
          name: "plant",
          programs: [both],
          globals: [%Global{name: "g", type: :bool, at: "panel.q.0"}],
          instances: [%Instance{name: "b", type: "both"}],
          connections: [%Connection{instance: "b", member: "q", to: "g"}]
        )

      assert [
               %Logex.Diagnostic{
                 message: "`b` writes `g` through its var_external, and its own " <> _
               }
             ] =
               config.warnings

      # The scan latches `g`, and its copy-out of `q`, 0, lands after: it stands.
      {runtime, outputs, _} = Runtime.cycle(Runtime.start(config), 0, %{})

      assert {outputs, Runtime.get(runtime, "g"), Runtime.get(runtime, "b.g")} ==
               {%{"g" => 0}, {:ok, 0}, {:ok, 0}}
    end

    test "an output point written through one is an output, and get/2 reads it as the " <>
           "global, whoever wrote it last" do
      runtime = Runtime.start(copier_and_reader([{"c", "copier"}, {"r", "reader"}]))
      # Before any cycle: the global's initial value, 1, through every path.
      assert for(path <- ~w(g c.g r.g), do: Runtime.get(runtime, path)) ==
               List.duplicate({:ok, 1}, 3)

      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      assert for(path <- ~w(g c.g r.g c.x), do: Runtime.get!(runtime, path)) == [0, 0, 0, 0]

      assert Runtime.get(runtime, "c.g.x") ==
               {:error, "`c.g.x` goes too deep: `c.g` is a bool, which has no members"}

      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@copier, "copier")],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "g", type: :bool, at: "panel.q.4"}
          ],
          instances: [%Instance{name: "c", type: "copier"}]
        )

      assert config.warnings == []
      {_runtime, outputs, _} = Runtime.cycle(Runtime.start(config), 0, %{"x" => 1})
      assert outputs == %{"g" => 1}
    end

    test "restart/2: the global back by its one rule, an input point kept, and the " <>
           "instances' var_externals still out of their states" do
      runtime = Runtime.start(copier_and_reader([{"c", "copier"}, {"r", "reader"}]))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"x" => 0})
      assert Runtime.get!(runtime, "g") == 0
      runtime = Runtime.restart(runtime, :cold)

      assert for(path <- ~w(g c.g x c.x r.out), do: Runtime.get!(runtime, path)) == [
               1,
               1,
               0,
               0,
               0
             ]

      {_runtime, outputs, _} = Runtime.cycle(runtime, 10, %{"x" => 1})
      assert outputs == %{"y" => 1}
    end

    # §4.6's "scan/2 and a one-line configuration give identical outputs" holds for a
    # program with var_externals, given for each an unlocated global of no initial value
    # that no other instance uses: the lone instance's own tag at 0.
    test "a program run alone agrees with a one-instance configuration of its globals" do
      alarm =
        program(
          "var_input trip bool\nvar_input reset bool\nvar_output lamp bool\n" <>
            "var_external latched bool\nvar_external trips dint\nvar edge bool\n" <>
            "xic trip ons edge otl latched\nxic reset otu latched\nxic latched ote lamp\n" <>
            "xic edge move 1 trips",
          "alarm"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [alarm],
          tasks: [task("t", 10, 0)],
          globals: [
            %Global{name: "trip", type: :bool, at: "panel.i.0"},
            %Global{name: "reset", type: :bool, at: "panel.i.1"},
            %Global{name: "lamp", type: :bool, at: "panel.q.0"},
            %Global{name: "latched", type: :bool},
            %Global{name: "trips", type: :dint}
          ],
          instances: [%Instance{name: "a", type: "alarm", task: "t"}],
          connections: [
            %Connection{instance: "a", member: "trip", to: "trip"},
            %Connection{instance: "a", member: "reset", to: "reset"},
            %Connection{instance: "a", member: "lamp", to: "lamp"}
          ]
        )

      :rand.seed(:exsss, {2026, 10, 12})

      Enum.reduce(1..400, {Runtime.instance(alarm), Runtime.start(config), 0}, fn step,
                                                                                  {lone, rt, now} ->
        inputs = %{"trip" => :rand.uniform(2) - 1, "reset" => Enum.random([0, 0, 0, 1])}
        restart = rem(step, 37) == 0

        {lone, rt} =
          if restart,
            do: {Runtime.restart(alarm, lone, :cold), Runtime.restart(rt, :cold)},
            else: {lone, rt}

        elapsed = if now == 0 and step == 1, do: 0, else: 10
        {outputs, lone} = Runtime.scan(alarm, Runtime.put_inputs(alarm, lone, inputs), elapsed)
        {rt, rt_outputs, _} = Runtime.cycle(rt, elapsed, inputs)
        assert rt_outputs == outputs, "step #{step}"

        for tag <- ~w(latched trips edge),
            do: assert(Runtime.get!(rt, "a." <> tag) == lone.env[tag], "a.#{tag} at step #{step}")

        {lone, rt, now + elapsed}
      end)
    end
  end

  # M2-6: event tasks, a task's `single` (docs/organisation.md §4.6 step 3; §4.10, M2-6;
  # decisions 11, 39, 50, 51 and 52). PLAN M2-6's Done-when is in end_to_end_test.exs.
  defp event(name, single, priority),
    do: %Configuration.Task{name: name, single: single, priority: priority}

  defp both(name, single, interval, priority),
    do: %Configuration.Task{name: name, single: single, interval: interval, priority: priority}

  defp points(names, io),
    do:
      for(
        {name, k} <- Enum.with_index(names),
        do: %Global{name: name, type: :bool, at: "p.#{io}.#{k}"}
      )

  # Cycles from a fresh start, each `{elapsed, inputs}`: the events of each.
  defp run(config, steps) do
    {events, _runtime} =
      Enum.map_reduce(steps, Runtime.start(config), fn {elapsed, inputs}, runtime ->
        {runtime, _outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
        {events, runtime}
      end)

    events
  end

  # One task, `task`, on the input point `trig`, its instance `r` copying `x` to `y`.
  defp one_event(task) do
    Configuration.new!(
      name: "plant",
      programs: [program(@relay, "relay")],
      tasks: [task],
      globals: points(~w(trig x), "i") ++ points(~w(y), "q"),
      instances: [%Instance{name: "r", type: "relay", task: task.name}],
      connections: wire("r", "x", "y")
    )
  end

  describe "an event task's edge (M2-6)" do
    test "runs once on each rising edge of its trigger, and never while it is held or low" do
      trace = [0, 1, 1, 0, 1, 0, 0, 1]
      events = run(one_event(event("e", "trig", 0)), for(v <- trace, do: {10, %{"trig" => v}}))
      assert Enum.map(events, &length(ran(&1))) == [0, 1, 0, 0, 1, 0, 0, 1]
      assert for([{:ran, "e", "r", now}] <- events, do: now) == [20, 50, 80]
    end

    # Decision 11: the last sample starts at 0, MatIEC's reading.
    test "a trigger already 1 in the first cycle is an edge: an input point the host sets, " <>
           "or an initial value" do
      assert ran(hd(run(one_event(event("e", "trig", 0)), [{0, %{"trig" => 1}}]))) ==
               [{"e", "r", 0}]

      armed =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [event("e", "armed", 0)],
          globals: [%Global{name: "armed", type: :bool, initial: 1}] ++ points(~w(y), "q"),
          instances: [%Instance{name: "r", type: "relay", task: "e"}],
          connections: wire("r", 1, "y")
        )

      # Nothing writes `armed`: it fires once a start, and never again (§4.10, M2-6).
      assert Enum.map(run(armed, List.duplicate({10, %{}}, 4)), &ran/1) ==
               [[{"e", "r", 10}], [], [], []]
    end

    # One sample a cycle (§4.6 step 3): a host that cycles once a change loses no edge.
    test "a pulse inside one host step is not seen, and an elapsed 0 cycle samples again" do
      config = one_event(event("e", "trig", 0))

      # 0 → 1, an edge; then 1 → 0 → 1 inside one step, sent as 1 or not at all; then
      # 0 → 1 → 0 inside one step, sent as 0.
      steps = [
        {0, %{"trig" => 1}},
        {10, %{"trig" => 1}},
        {10, %{}},
        {10, %{"trig" => 0}},
        {10, %{"trig" => 0}}
      ]

      assert Enum.map(run(config, steps), &length(ran(&1))) == [1, 0, 0, 0, 0]

      steps = [{0, %{"trig" => 1}}, {0, %{"trig" => 0}}, {0, %{"trig" => 1}}]
      assert Enum.map(run(config, steps), &ran/1) == [[{"e", "r", 0}], [], [{"e", "r", 0}]]
    end

    # A writer on a higher-priority periodic task runs before the event task would in the
    # same cycle, and still the event task runs only in the next: every trigger is sampled
    # after the input merge and before any scan.
    for {kind, at} <- [{"an unlocated global", nil}, {"an output point", "p.q.9"}] do
      test "a trigger written by logic, #{kind} a connection drives, fires in the next cycle" do
        config =
          Configuration.new!(
            name: "plant",
            programs: [program(@relay, "relay")],
            tasks: [task("fast", 10, 0), event("e", "g", 1)],
            globals:
              points(~w(x), "i") ++
                [%Global{name: "g", type: :bool, at: unquote(at)}] ++ points(~w(y), "q"),
            instances: [
              %Instance{name: "w", type: "relay", task: "fast"},
              %Instance{name: "r", type: "relay", task: "e"}
            ],
            connections: wire("w", "x", "g") ++ wire("r", "x", "y")
          )

        events = run(config, [{0, %{}}, {10, %{"x" => 1}}, {0, %{}}, {10, %{}}])

        assert Enum.map(events, &ran/1) == [
                 [{"fast", "w", 0}],
                 # `w` writes g = 1 at 10 ms, before `e` would run: e's sample was 0.
                 [{"fast", "w", 10}],
                 # The next cycle, elapsed 0, samples 1: an edge.
                 [{"e", "r", 10}],
                 [{"fast", "w", 20}]
               ]
      end
    end

    # The trigger is sampled after the input merge: the inputs a cycle brings are its
    # sample, not the last cycle's image.
    test "is sampled from this cycle's inputs" do
      steps = [{0, %{}}, {10, %{"trig" => 1}}, {10, %{"trig" => 0}}]

      assert Enum.map(run(one_event(event("e", "trig", 0)), steps), &ran/1) ==
               [[], [{"e", "r", 10}], []]
    end

    test "never overlaps, has no periodic due time, and overlaps/1 lists it at 0" do
      runtime = Runtime.start(one_event(event("e", "trig", 0)))
      assert Runtime.next_due_in(runtime) == :infinity
      assert Runtime.overlaps(runtime) == %{"e" => 0}

      runtime =
        Enum.reduce([1, 0, 1, 1, 0], runtime, fn v, runtime ->
          {runtime, _, _} = Runtime.cycle(runtime, 1_000, %{"trig" => v})
          runtime
        end)

      assert Runtime.overlaps(runtime) == %{"e" => 0}
      assert Runtime.next_due_in(runtime) == :infinity
    end

    # No new event kind (§4.10, M2-6): an edge is seen in the scans it runs.
    test "a run is its {:ran, ...} events alone, and one with no instance leaves none" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [event("idle", "trig", 0), event("e", "trig", 1)],
          globals: points(~w(trig), "i"),
          instances: [%Instance{name: "r", type: "relay", task: "e"}],
          connections: [%Connection{instance: "r", member: "in", to: 0}]
        )

      assert run(config, [{0, %{"trig" => 1}}]) == [[{:ran, "e", "r", 0}]]
    end

    # §4.6's caveat: a ton's `.acc` counts the time between runs, which only the
    # configuration's warning says (the configuration file's task lines).
    test "a ton in its program times across events" do
      timed =
        program(
          "var_input go bool\nvar_output done bool\nvar t1 ton\nxic go ton t1 100\n" <>
            "xic t1.dn ote done",
          "timed"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [timed],
          tasks: [event("e", "trig", 0)],
          globals: points(~w(trig), "i") ++ points(~w(done), "q"),
          instances: [%Instance{name: "t", type: "timed", task: "e"}],
          connections: [
            %Connection{instance: "t", member: "go", to: 1},
            %Connection{instance: "t", member: "done", to: "done"}
          ]
        )

      # Runs at 0 and 60 ms count 60 ms, though the timer ran twice; 500 ms with no event,
      # then one: done at once, by time no scan saw.
      runtime = Runtime.start(config)
      {runtime, %{"done" => 0}, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      {runtime, %{"done" => 0}, []} = Runtime.cycle(runtime, 30, %{"trig" => 0})
      {runtime, %{"done" => 0}, _} = Runtime.cycle(runtime, 30, %{"trig" => 1})
      assert Runtime.get!(runtime, "t.t1.acc") == 60
      {runtime, _, []} = Runtime.cycle(runtime, 500, %{"trig" => 0})
      {runtime, %{"done" => 1}, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      assert Runtime.get!(runtime, "t.t1.acc") == 100
    end
  end

  # §4.10, M2-6: an event task's due time, for the earlier-due-time tie-break, is the
  # cycle's `now`. Its visibility form: `w`, on a periodic task, copies `x` to the global
  # `g`; `r`, on an event task of the same priority, copies `g` to the output `y`, so `y`
  # shows which ran first. The form with two writers of one global is end_to_end_test.exs's.
  describe "the tie-break between an event task and a periodic one (M2-6)" do
    defp tie(tasks) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: tasks,
        globals:
          points(~w(trig x), "i") ++ [%Global{name: "g", type: :bool}] ++ points(~w(y), "q"),
        instances: [
          %Instance{name: "w", type: "relay", task: "p"},
          %Instance{name: "r", type: "relay", task: "e"}
        ],
        connections: wire("w", "x", "g") ++ wire("r", "g", "y")
      )
    end

    defp tie_outputs(config, elapsed) do
      {runtime, _, _} = Runtime.cycle(Runtime.start(config), 0, %{})
      {_runtime, outputs, events} = Runtime.cycle(runtime, elapsed, %{"trig" => 1, "x" => 1})
      {outputs, ran(events)}
    end

    test "a late periodic task of the same priority runs first, declared after it or not" do
      for tasks <- [
            [event("e", "trig", 1), task("p", 10, 1)],
            [task("p", 10, 1), event("e", "trig", 1)]
          ] do
        # p was due at 10, the cycle is at 15: p has waited longer.
        assert tie_outputs(tie(tasks), 15) == {%{"y" => 1}, [{"p", "w", 15}, {"e", "r", 15}]}
      end
    end

    test "a periodic task due exactly at now ties, and falls to the order declared" do
      assert tie_outputs(tie([event("e", "trig", 1), task("p", 10, 1)]), 10) ==
               {%{"y" => 0}, [{"e", "r", 10}, {"p", "w", 10}]}

      assert tie_outputs(tie([task("p", 10, 1), event("e", "trig", 1)]), 10) ==
               {%{"y" => 1}, [{"p", "w", 10}, {"e", "r", 10}]}
    end

    test "priority comes first" do
      assert tie_outputs(tie([task("p", 10, 2), event("e", "trig", 1)]), 15) ==
               {%{"y" => 0}, [{"e", "r", 15}, {"p", "w", 15}]}
    end

    # With an interval too: an edge run's due time is `now`, even where a periodic due time
    # came in the same cycle, which decision 39 skips; a periodic run's is its due time.
    test "a task with single and interval: an edge run is due at now, a periodic run at its " <>
           "due time" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [task("p", 12, 1), both("c", "trig", 10, 1)],
          globals: points(~w(trig), "i"),
          instances: [
            %Instance{name: "rp", type: "relay", task: "p"},
            %Instance{name: "rc", type: "relay", task: "c"}
          ],
          connections: for(i <- ~w(rp rc), do: %Connection{instance: i, member: "in", to: 0})
        )

      # At 15, trigger 0: c due at 10 and p at 12, so c, though declared later, has waited
      # longer. At 30 c samples an edge: its due time 30 was skipped, and the edge run is
      # due at now, 30, where p, due at 24, has waited longer.
      steps = [{0, %{}}, {15, %{}}, {15, %{"trig" => 1}}]

      assert Enum.map(run(config, steps), &ran/1) == [
               [{"p", "rp", 0}, {"c", "rc", 0}],
               [{"c", "rc", 15}, {"p", "rp", 15}],
               [{"p", "rp", 30}, {"c", "rc", 30}]
             ]
    end
  end

  describe "decision 39: a task with single and interval (M2-6)" do
    # Each cycle: how many scans ran, the task's overlap count, and next_due_in/1 after.
    defp at_times(steps) do
      steps
      |> Enum.map_reduce(Runtime.start(one_event(both("b", "trig", 10, 0))), fn
        {elapsed, inputs}, runtime ->
          {runtime, _, events} = Runtime.cycle(runtime, elapsed, inputs)

          {{length(ran(events)), Runtime.overlaps(runtime)["b"], Runtime.next_due_in(runtime)},
           runtime}
      end)
      |> elem(0)
    end

    test "runs periodically while its trigger is 0; a due time under a high trigger is " <>
           "skipped, not counted, and the next is on the same phase" do
      steps = [
        # 0: due, trigger 0: a periodic run.
        {0, %{}},
        # 5: an edge: one run.
        {5, %{"trig" => 1}},
        # 10, 20, 30: held high, each due time skipped, none counted.
        {5, %{}},
        {10, %{}},
        {10, %{}},
        # 35: falls; the next due time is 40, on the phase.
        {5, %{"trig" => 0}},
        # 40: periodic again.
        {5, %{}}
      ]

      assert at_times(steps) == [
               {1, 0, 10},
               {1, 0, 5},
               {0, 0, 10},
               {0, 0, 10},
               {0, 0, 10},
               {0, 0, 5},
               {1, 0, 10}
             ]
    end

    test "an edge run does not move the phase, and an edge and a due time in one cycle are " <>
           "one run" do
      steps = [
        {0, %{}},
        # 3: an edge run; the phase stays at 10.
        {3, %{"trig" => 1}},
        {1, %{"trig" => 0}},
        # 10: a periodic run, on the phase.
        {6, %{}},
        # 20: an edge and a due time: one run, the next due at 30.
        {10, %{"trig" => 1}}
      ]

      assert at_times(steps) == [{1, 0, 10}, {1, 0, 7}, {0, 0, 6}, {1, 0, 10}, {1, 0, 10}]
    end

    test "the trigger falling keeps the phase: the next run is on it, not a period after " <>
           "the fall" do
      # 0 periodic; 2 an edge; 7 falls, the next due still 10; 10 periodic.
      steps = [{0, %{}}, {2, %{"trig" => 1}}, {5, %{"trig" => 0}}, {3, %{}}]
      assert at_times(steps) == [{1, 0, 10}, {1, 0, 8}, {0, 0, 3}, {1, 0, 10}]
    end

    # Decision 51: a late host's edge cycle reads by its sample, 1, so the due times since
    # the last cycle are skipped, not counted; a cycle that samples 0 is a periodic task's,
    # its missed periods counted.
    test "a late cycle counts its missed periods only while its trigger samples 0" do
      steps = [
        {0, %{}},
        # 35, trigger 0: one run, 10 and 20 missed, the next due at 40.
        {35, %{}},
        # 75, an edge: one run, 40 to 70 skipped, none counted.
        {40, %{"trig" => 1}},
        # 115, still 1: nothing runs, nothing counted.
        {40, %{}}
      ]

      assert at_times(steps) == [{1, 0, 10}, {1, 2, 5}, {1, 2, 5}, {0, 2, 5}]
    end

    # Decision 52: a due time that came while the image still held 1 runs in the cycle
    # that samples 0, since only the sample is known, a late one's missed periods counted
    # as any late periodic task's are.
    test "a late cycle that samples 0 runs a due time that came while the image held 1" do
      steps = [
        {0, %{}},
        # 5: an edge; the next due time stays 10.
        {5, %{"trig" => 1}},
        # 35 samples 0: 10, 20 and 30 came while the image held 1; 30 runs, 10 and 20 are
        # counted missed.
        {30, %{"trig" => 0}}
      ]

      assert at_times(steps) == [{1, 0, 10}, {1, 0, 5}, {1, 2, 5}]
    end

    # Decision 50: next_due_in/1 counts a periodic due time, a combined task's among them,
    # even while its trigger is held 1.
    test "next_due_in/1 counts its periodic due time, held high or not" do
      runtime = Runtime.start(one_event(both("b", "trig", 10, 0)))
      assert Runtime.next_due_in(runtime) == 0
      {runtime, _, _} = Runtime.cycle(runtime, 4, %{"trig" => 1})
      assert Runtime.next_due_in(runtime) == 6
      {runtime, _, []} = Runtime.cycle(runtime, 6, %{})
      assert Runtime.next_due_in(runtime) == 10
    end
  end

  describe "restart/2 and an event task (M2-6)" do
    # §4.9's table: a restart sets the last sample to 0, so a trigger already 1 fires
    # again: an input point held through it, since the image is kept, and an unlocated
    # global back at its initial value 1; with an interval too.
    test "a trigger already 1 fires again in the next cycle" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [event("held", "trig", 0), event("armed", "a", 1), both("b", "trig", 50, 2)],
          globals:
            points(~w(trig x), "i") ++
              [%Global{name: "a", type: :bool, initial: 1}] ++ points(~w(y), "q"),
          instances: [
            %Instance{name: "r1", type: "relay", task: "held"},
            %Instance{name: "r2", type: "relay", task: "armed"},
            %Instance{name: "r3", type: "relay", task: "b"}
          ],
          connections:
            wire("r1", "x", "y") ++
              [
                %Connection{instance: "r2", member: "in", to: 0},
                %Connection{instance: "r3", member: "in", to: 0}
              ]
        )

      runtime = Runtime.start(config)
      {runtime, _, events} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      assert ran(events) == [{"held", "r1", 0}, {"armed", "r2", 0}, {"b", "r3", 0}]
      {runtime, _, events} = Runtime.cycle(runtime, 7, %{})
      assert ran(events) == []

      runtime = Runtime.restart(runtime, :cold)
      {_runtime, _, events} = Runtime.cycle(runtime, 0, %{})
      assert ran(events) == [{"held", "r1", 7}, {"armed", "r2", 7}, {"b", "r3", 7}]
    end

    # Decision 50: next_due_in/1 counts periodic due times only, so after start/1 or
    # restart/2 a configuration of event tasks says :infinity, and a runner cycles at once
    # whatever it says.
    test "next_due_in/1 counts no event task alone after start/1 or restart/2" do
      runtime = Runtime.start(one_event(event("e", "trig", 0)))
      assert Runtime.next_due_in(runtime) == :infinity
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      runtime = Runtime.restart(runtime, :cold)
      assert Runtime.next_due_in(runtime) == :infinity
      assert {_, _, [{:ran, "e", "r", 0}]} = Runtime.cycle(runtime, 0, %{})
    end
  end

  describe "growth" do
    # A cycle of n instances, each on a task of its own, all due, each copying an input
    # point in and an output point out. Counted in reductions, the least of three.
    defp relays(n) do
      relay = program(@relay, "relay")

      Configuration.new!(
        name: "plant",
        programs: [relay],
        tasks: for(i <- 1..n, do: task("t#{i}", 10, rem(i, 7))),
        globals:
          Enum.flat_map(1..n, fn i ->
            [
              %Global{name: "x#{i}", type: :bool, at: "panel.i.#{i}"},
              %Global{name: "y#{i}", type: :bool, at: "panel.q.#{i}"}
            ]
          end),
        instances: for(i <- 1..n, do: %Instance{name: "r#{i}", type: "relay", task: "t#{i}"}),
        connections: Enum.flat_map(1..n, &wire("r#{&1}", "x#{&1}", "y#{&1}"))
      )
    end

    defp reductions_to_cycle(n) do
      runtime = Runtime.start(relays(n))
      inputs = Map.new(1..n, &{"x#{&1}", 1})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {_runtime, _outputs, _events} = Runtime.cycle(runtime, 10, inputs)
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    # start/1 checks the configuration again, builds every instance and derives what a
    # cycle reads of it.
    defp reductions_to_start(n) do
      config = relays(n)

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          %Runtime{} = Runtime.start(config)
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    # One task and as many task-less instances as on it, each reading one shared input
    # point and driving a global of its own: every instance runs in the counted cycle.
    defp crowd(n) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [task("t", 10, 0)],
        globals:
          [%Global{name: "x", type: :bool, at: "panel.i.0"}] ++
            for(i <- 1..(2 * n), do: %Global{name: "g#{i}", type: :bool}),
        instances:
          for(i <- 1..n, do: %Instance{name: "a#{i}", type: "relay", task: "t"}) ++
            for(i <- 1..n, do: %Instance{name: "b#{i}", type: "relay"}),
        connections:
          Enum.flat_map(1..n, &wire("a#{&1}", "x", "g#{&1}")) ++
            Enum.flat_map(1..n, &wire("b#{&1}", "x", "g#{n + &1}"))
      )
    end

    defp reductions_to_cycle_crowd(n) do
      runtime = Runtime.start(crowd(n))

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {_runtime, _outputs, _events} = Runtime.cycle(runtime, 10, %{"x" => 1})
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    # At 16x, not 4x: `++` is charged few reductions for what it copies (CONTRIBUTING.md),
    # so an event list rebuilt at every scan grows within a 4x bound at 4x the instances,
    # and shows only at 16x: 24.6x to 25.0x, where a linear cycle takes 16.5x to 16.6x
    # (32 runs).
    test "a cycle stays linear in the instances it runs" do
      ratio = reductions_to_cycle_crowd(1600) / reductions_to_cycle_crowd(100)
      assert ratio < 20.5, "16x the instances took #{Float.round(ratio, 2)}x the reductions"
    end

    test "start/1 stays linear in the configuration's size" do
      ratio = reductions_to_start(2000) / reductions_to_start(500)
      assert ratio < 6, "4x the instances took #{Float.round(ratio, 1)}x the reductions"
    end

    # One 1 ms task and n tasks that are never due again: a cycle at 1 ms runs one task,
    # and walks the n others to find it. Linear in the tasks declared, which is what a
    # cycle and next_due_in/1 cost, whatever runs.
    defp idle(n) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [task("fast", 1, 0) | for(i <- 1..n, do: task("t#{i}", 2_147_483_647, 1))],
        instances: [%Instance{name: "r", type: "relay", task: "fast"}],
        connections: [%Connection{instance: "r", member: "in", to: 1}]
      )
    end

    defp reductions_with_one_due(n) do
      {runtime, _, _} = Runtime.cycle(Runtime.start(idle(n)), 0, %{})

      for f <- [&Runtime.cycle(&1, 1, %{}), &Runtime.next_due_in/1] do
        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            _ = f.(runtime)
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end
    end

    test "a cycle that runs one task, and next_due_in/1, stay linear in the tasks declared" do
      {[cycle, next], [cycle4, next4]} =
        {reductions_with_one_due(500), reductions_with_one_due(2000)}

      assert cycle4 / cycle < 6,
             "4x the tasks took #{Float.round(cycle4 / cycle, 1)}x for a cycle"

      assert next4 / next < 6,
             "4x the tasks took #{Float.round(next4 / next, 1)}x for next_due_in/1"
    end

    # M2-4: n task-less instances of a type that reads and writes k globals through
    # var_external: a scan merges k globals in and splits k off, so a cycle is linear in
    # the instances and in their var_externals. Over 32 runs on Elixir 1.20.4, 16 alone and
    # 16 beside three full suites, 4x the instances took 4.20x at most and 4x the
    # var_externals 3.34x, each bound a fifth above the highest.
    defp sharers(n, k) do
      sharer =
        program(
          Enum.map_join(1..k, &"var_external g#{&1} bool\n") <>
            Enum.map_join(1..k, &"xio g#{&1} ote g#{&1}\n"),
          "sharer"
        )

      Configuration.new!(
        name: "plant",
        programs: [sharer],
        globals: for(j <- 1..k, do: %Global{name: "g#{j}", type: :bool}),
        instances: for(i <- 1..n, do: %Instance{name: "s#{i}", type: "sharer"})
      )
    end

    defp reductions_to_share(n, k) do
      {runtime, _, _} = Runtime.cycle(Runtime.start(sharers(n, k)), 0, %{})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          _ = Runtime.cycle(runtime, 10, %{})
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    test "a cycle stays linear in the instances that share globals and in their " <>
           "var_externals" do
      instances = reductions_to_share(400, 8) / reductions_to_share(100, 8)
      externals = reductions_to_share(100, 32) / reductions_to_share(100, 8)
      assert instances < 5.04, "4x the instances took #{Float.round(instances, 2)}x"
      assert externals < 4.01, "4x the var_externals took #{Float.round(externals, 2)}x"
    end

    # M2-6: n tasks with single and interval on one input point, each running one relay,
    # and one periodic task: a cycle samples and plans every task, and sorts those due,
    # all of them in a cycle the trigger rises. Over 32 runs on Elixir 1.20.4, 3 of the test
    # alone, 16 beside three full suites and 13 in a full suite, 4x the tasks took 3.96x
    # with the trigger at 0 and 4.04x to 4.08x with it rising; the bounds, 4.76 and 4.90,
    # are a fifth above the highest.
    defp triggered(n) do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [
          task("p", 10, 0)
          | for(i <- 1..n, do: both("e#{i}", "trig", 10 + rem(i, 7), rem(i, 5)))
        ],
        globals: points(~w(trig), "i"),
        instances: for(i <- 1..n, do: %Instance{name: "r#{i}", type: "relay", task: "e#{i}"}),
        connections: for(i <- 1..n, do: %Connection{instance: "r#{i}", member: "in", to: "trig"})
      )
    end

    defp reductions_triggered(n, inputs) do
      {runtime, _, _} = Runtime.cycle(Runtime.start(triggered(n)), 0, %{"trig" => 0})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          _ = Runtime.cycle(runtime, 5, inputs)
          _ = Runtime.next_due_in(runtime)
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    test "a cycle stays linear in the event tasks declared, whether their trigger rises or not" do
      quiet =
        reductions_triggered(2000, %{"trig" => 0}) / reductions_triggered(500, %{"trig" => 0})

      rises =
        reductions_triggered(2000, %{"trig" => 1}) / reductions_triggered(500, %{"trig" => 1})

      assert quiet < 4.76, "4x the tasks took #{Float.round(quiet, 2)}x, the trigger at 0"
      assert rises < 4.90, "4x the tasks took #{Float.round(rises, 2)}x, the trigger rising"
    end

    test "a cycle stays linear in the number of instances, tasks and connections" do
      ratio = reductions_to_cycle(2000) / reductions_to_cycle(500)
      assert ratio < 6, "4x the instances took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
