defmodule Logex.SchedulerTest do
  @moduledoc """
  M2-1: the rules of a cycle (`Logex.Runtime`'s moduledoc; `docs/organisation.md` §4.6),
  one test at least for each, driven through the public API from configurations built in
  Elixir. The messages a host's mistakes raise are in `runtime_test.exs`, and the
  configuration's diagnostics in `configuration_test.exs`.
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
      assert {Runtime.get(runtime, "x"), Runtime.get(runtime, "g")} == {0, 1}
      assert {Runtime.get(runtime, "sp"), Runtime.get(runtime, "y")} == {1200, 0}
      assert Runtime.get(runtime, "r.out") == 0
      assert Runtime.next_due_in(runtime) == 0
      assert Runtime.overlaps(runtime) == %{"fast" => 0}

      # Time 0: the first cycle, with no time elapsed, is at 0 ms.
      assert {_runtime, %{"y" => 1}, [{:ran, "fast", "r", 0}]} = Runtime.cycle(runtime, 0, %{})
    end

    # Configuration.initial/1 is the one rule for a global's value where nothing has set
    # it: start/1 starts every global by it.
    test "starts every global by the one rule" do
      config = plant()
      runtime = Runtime.start(config)

      assert Map.new(config.globals, &{&1.name, Runtime.get(runtime, &1.name)}) ==
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
      assert Runtime.get(runtime, "g") == 1
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

    test "a cycle stays linear in the number of instances, tasks and connections" do
      ratio = reductions_to_cycle(2000) / reductions_to_cycle(500)
      assert ratio < 6, "4x the instances took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
