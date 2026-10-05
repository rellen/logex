defmodule Logex.EventTaskTest do
  @moduledoc """
  Spike only: event tasks at run time (docs/organisation.md §4.6 step 3, §4.10 M2-6,
  decisions 11, 19 and 39), from Elixir data. Each test names the rule it pins.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime, Scan}
  alias Logex.Configuration.{Connection, Global, Instance}

  @relay "var_input in bool\nvar_output out bool\nxic in ote out"
  @timer "var_input go bool\nvar_output done bool\nvar t1 ton\nxic go ton t1 100\nxic t1.dn ote done"

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  defp periodic(name, interval, priority),
    do: %Configuration.Task{name: name, interval: interval, priority: priority}

  defp event(name, single, priority),
    do: %Configuration.Task{name: name, single: single, priority: priority}

  defp both(name, single, interval, priority),
    do: %Configuration.Task{name: name, single: single, interval: interval, priority: priority}

  defp wire(instance, input, output),
    do: [
      %Connection{instance: instance, member: "in", to: input},
      %Connection{instance: instance, member: "out", to: output}
    ]

  defp ran(events), do: for({:ran, task, instance, now} <- events, do: {task, instance, now})

  # Cycles from a fresh start, each `{elapsed, inputs}`: the events of each.
  defp run(config, steps) do
    {events, _runtime} =
      Enum.map_reduce(steps, Runtime.start(config), fn {elapsed, inputs}, runtime ->
        {runtime, _outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
        {events, runtime}
      end)

    events
  end

  defp points(names, io),
    do:
      for(
        {name, k} <- Enum.with_index(names),
        do: %Global{name: name, type: :bool, at: "p.#{io}.#{k}"}
      )

  # An event task `e` on the input point `trig`, its instance `r` copying `x` to `y`.
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

  describe "the configuration: single (org §4.4)" do
    setup do
      %{relay: program(@relay, "relay")}
    end

    defp checked(relay, tasks, globals) do
      config = %Configuration{
        name: "plant",
        programs: %{"relay" => relay},
        tasks: tasks,
        globals: globals,
        instances: [%Instance{name: "r", type: "relay"}],
        connections: [%Connection{instance: "r", member: "in", to: 0}]
      }

      Enum.map(Configuration.check(config), & &1.message)
    end

    test "a task with single alone, or with interval, is accepted", %{relay: relay} do
      globals = [%Global{name: "go", type: :bool}]
      assert checked(relay, [event("e", "go", 0), both("b", "go", 10, 1)], globals) == []
    end

    test "a task needs an interval or a single", %{relay: relay} do
      assert checked(relay, [%Configuration.Task{name: "t", priority: 0}], []) == [
               "task `t` needs an interval, as in `task t interval 10 priority 1`, or a " <>
                 "trigger, as in `task t single estop priority 0`"
             ]
    end

    test "an event task's interval of 0 is told to leave it out", %{relay: relay} do
      assert checked(relay, [both("t", "go", 0, 3)], [%Global{name: "go", type: :bool}]) == [
               "task `t`: an interval is 1 to 2147483647 ms, found 0: a task that runs only " <>
                 "on the edges of its `single` is declared without one, as in " <>
                 "`task t single go priority 3`"
             ]
    end

    test "a single names a bool global", %{relay: relay} do
      globals = [
        %Global{name: "n", type: :dint},
        %Global{name: "estop", type: :bool, at: "panel.i.0"}
      ]

      tasks = [
        event("a", "n", 0),
        event("b", "estp", 0),
        event("c", "r", 0),
        event("d", "a", 0),
        event("e", "r.out", 0),
        event("f", "zz", 0)
      ]

      assert checked(relay, tasks, globals) == [
               "task `a`: its `single` `n` is a dint: a task's `single` is a bool global",
               "task `b`: its `single` `estp` is not a global — did you mean `estop`?",
               "task `c`: its `single` `r` is a program instance, not a global: a task's " <>
                 "`single` is a bool global",
               "task `d`: its `single` `a` is a task, not a global: a task's `single` is a " <>
                 "bool global",
               "task `e`: its `single` `r.out` is not a global: the bool globals are `estop`",
               "task `f`: its `single` `zz` is not a global"
             ]
    end

    test "a single no line can say is the host's mistake", %{relay: relay} do
      error =
        assert_raise ArgumentError, fn ->
          checked(relay, [event("e", 3, 0), event("f", "a b", 0)], [])
        end

      assert error.message ==
               "task `e`: its `single` is a global's name, or nil for none, found 3\n" <>
                 ~s|task `f`: its `single` is a global's name, or nil for none, found "a b"|
    end
  end

  describe "PLAN M2-6's Done-when" do
    # An event task on an input point, a periodic task of a lower priority, both due in
    # the cycles the trigger rises.
    defp done_when do
      Configuration.new!(
        name: "plant",
        programs: [program(@relay, "relay")],
        tasks: [periodic("slow", 10, 2), event("trip", "estop", 0)],
        globals: points(~w(estop x), "i") ++ points(~w(y z), "q"),
        instances: [
          %Instance{name: "m", type: "relay", task: "slow"},
          %Instance{name: "snap", type: "relay", task: "trip"}
        ],
        connections: wire("m", "x", "y") ++ wire("snap", "x", "z")
      )
    end

    test "runs once per rising edge, before lower-priority tasks due in the same cycle, " <>
           "and in cycle 1 if its trigger is already true" do
      trace = [0, 1, 1, 0, 0, 1, 0, 1, 1, 1]

      events =
        run(done_when(), for(v <- trace, do: {10, %{"estop" => v}}))
        |> Enum.map(&ran/1)

      # The edges, from the trace alone: a 0 then a 1, the trace starting from 0.
      edges =
        for {[a, b], i} <- Enum.with_index(Enum.chunk_every([0 | trace], 2, 1, :discard)),
            a == 0 and b == 1,
            do: i

      runs =
        for {cycle, i} <- Enum.with_index(events), {"trip", "snap", _} <- cycle, do: i

      assert runs == edges
      assert edges == [1, 5, 7]

      # In every cycle it runs, it runs before the lower-priority task due in that cycle.
      for i <- runs, do: assert([{"trip", "snap", _}, {"slow", "m", _}] = Enum.at(events, i))
    end

    test "runs in cycle 1 if its trigger is already true" do
      [first | _] = run(done_when(), [{0, %{"estop" => 1}}, {10, %{}}])
      assert ran(first) == [{"trip", "snap", 0}, {"slow", "m", 0}]
    end
  end

  describe "the edge (org §4.6 step 3)" do
    test "a trigger already 1 in the first cycle counts as an edge: an initial value too" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [event("e", "armed", 0)],
          globals: [%Global{name: "armed", type: :bool, initial: 1}] ++ points(~w(y), "q"),
          instances: [%Instance{name: "r", type: "relay", task: "e"}],
          connections: wire("r", 1, "y")
        )

      assert Enum.map(run(config, List.duplicate({10, %{}}, 4)), &ran/1) ==
               [[{"e", "r", 10}], [], [], []]
    end

    test "a pulse inside one host step is not seen" do
      config = one_event(event("e", "trig", 0))
      # 0 → 1 (edge); then 1 → 0 → 1 inside one step, sent as 1 or not at all; then
      # 0 → 1 → 0 inside one step, sent as 0.
      steps = [
        {0, %{"trig" => 1}},
        {10, %{"trig" => 1}},
        {10, %{}},
        {10, %{"trig" => 0}},
        {10, %{"trig" => 0}}
      ]

      assert Enum.map(run(config, steps), &length(ran(&1))) == [1, 0, 0, 0, 0]
    end

    test "a sample is taken once a cycle: elapsed 0 cycles sample again" do
      config = one_event(event("e", "trig", 0))
      steps = [{0, %{"trig" => 1}}, {0, %{"trig" => 0}}, {0, %{"trig" => 1}}]
      assert Enum.map(run(config, steps), &ran/1) == [[{"e", "r", 0}], [], [{"e", "r", 0}]]
    end

    # A writer on a higher-priority periodic task runs before the event task would in the
    # same cycle, and still the event task runs only in the next cycle: the trigger is
    # sampled before any scan.
    for {kind, at} <- [{"an unlocated global", nil}, {"an output point", "p.q.9"}] do
      test "a trigger written by logic, #{kind} an instance's output connection drives, " <>
             "takes effect in the next cycle" do
        config =
          Configuration.new!(
            name: "plant",
            programs: [program(@relay, "relay")],
            tasks: [periodic("fast", 10, 0), event("e", "g", 1)],
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
                 # `w` writes g = 1 at 10 ms, before `e` would run; e's sample was 0.
                 [{"fast", "w", 10}],
                 # The next cycle, elapsed 0: e's sample is 1, an edge.
                 [{"e", "r", 10}],
                 [{"fast", "w", 20}]
               ]
      end
    end
  end

  describe "the tie-break (§4.10 M2-6, owed): an event task's due time is the cycle's now" do
    # `w`, on a periodic task, copies the input `x` to the global `g`; `r`, on an event
    # task of the same priority, copies `g` to the output `y`. Which runs first is which
    # `y` the cycle gives back: one driver per sink (M2-1) lets two connections write no
    # one global, so the order shows in what the later instance reads.
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
      runtime = Runtime.start(config)
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{})
      {_runtime, outputs, events} = Runtime.cycle(runtime, elapsed, %{"trig" => 1, "x" => 1})
      {outputs, ran(events)}
    end

    test "a late periodic task of the same priority runs first, declared after it or not" do
      for tasks <- [
            [event("e", "trig", 1), periodic("p", 10, 1)],
            [periodic("p", 10, 1), event("e", "trig", 1)]
          ] do
        # p was due at 10, the cycle is at 15: p waited longer.
        assert tie_outputs(tie(tasks), 15) ==
                 {%{"y" => 1}, [{"p", "w", 15}, {"e", "r", 15}]}
      end
    end

    test "a periodic task due exactly at now ties, and falls to the order declared" do
      assert tie_outputs(tie([event("e", "trig", 1), periodic("p", 10, 1)]), 10) ==
               {%{"y" => 0}, [{"e", "r", 10}, {"p", "w", 10}]}

      assert tie_outputs(tie([periodic("p", 10, 1), event("e", "trig", 1)]), 10) ==
               {%{"y" => 1}, [{"p", "w", 10}, {"e", "r", 10}]}
    end

    test "priority still comes first" do
      assert tie_outputs(tie([periodic("p", 10, 2), event("e", "trig", 1)]), 15) ==
               {%{"y" => 0}, [{"e", "r", 15}, {"p", "w", 15}]}
    end
  end

  describe "decision 39: single with interval" do
    defp d39, do: one_event(both("b", "trig", 10, 0))

    # Each cycle: how many scans ran, b's overlap count, and next_due_in/1 after it.
    defp at_times(config, steps) do
      steps
      |> Enum.map_reduce(Runtime.start(config), fn {elapsed, inputs}, runtime ->
        {runtime, _, events} = Runtime.cycle(runtime, elapsed, inputs)

        {{length(ran(events)), Runtime.overlaps(runtime)["b"], Runtime.next_due_in(runtime)},
         runtime}
      end)
      |> elem(0)
    end

    test "periodic while the trigger is 0; a due time under a high trigger is skipped, " <>
           "not counted, and the next is on the same phase" do
      steps = [
        # t=0: due, trigger 0: periodic run.
        {0, %{}},
        # t=5: an edge: one run.
        {5, %{"trig" => 1}},
        # t=10, 20, 30: high: each due time skipped, no overlap.
        {5, %{}},
        {10, %{}},
        {10, %{}},
        # t=35: falls; the next due time is 40, on the phase.
        {5, %{"trig" => 0}},
        # t=40: periodic again.
        {5, %{}}
      ]

      assert at_times(d39(), steps) == [
               {1, 0, 10},
               {1, 0, 5},
               {0, 0, 10},
               {0, 0, 10},
               {0, 0, 10},
               {0, 0, 5},
               {1, 0, 10}
             ]
    end

    test "an edge run does not move the phase, and an edge and a due time in one cycle " <>
           "make one run" do
      steps = [
        {0, %{}},
        # t=3: edge run; the phase stays at 10.
        {3, %{"trig" => 1}},
        {1, %{"trig" => 0}},
        # t=10: periodic run, on the phase.
        {6, %{}},
        # t=20: an edge and a due time: one run, and the next due at 30.
        {10, %{"trig" => 1}}
      ]

      assert at_times(d39(), steps) == [
               {1, 0, 10},
               {1, 0, 7},
               {0, 0, 6},
               {1, 0, 10},
               {1, 0, 10}
             ]
    end

    test "a late cycle counts its missed periods only while the trigger samples 0" do
      steps = [
        {0, %{}},
        # t=35, trigger 0: one run, 30 and 20 missed (2), next 40.
        {35, %{}},
        # t=75, trigger 1, an edge: one run, 40..70 skipped, not counted.
        {40, %{"trig" => 1}},
        # t=115, still 1: nothing runs, nothing counted.
        {40, %{}}
      ]

      assert at_times(d39(), steps) == [{1, 0, 10}, {1, 2, 5}, {1, 2, 5}, {0, 2, 5}]
    end

    test "the trigger falling keeps the phase: the next run is on it, not a period after " <>
           "the fall" do
      steps = [{0, %{}}, {2, %{"trig" => 1}}, {5, %{"trig" => 0}}, {3, %{}}]
      # t=0 periodic; t=2 edge; t=7 falls: next due still 10; t=10 periodic.
      assert at_times(d39(), steps) == [{1, 0, 10}, {1, 0, 8}, {0, 0, 3}, {1, 0, 10}]
    end

    test "a periodic run is due at its due time, not at now, for the tie-break" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@relay, "relay")],
          tasks: [periodic("p", 12, 1), both("c", "trig", 10, 1)],
          globals: points(~w(trig), "i"),
          instances: [
            %Instance{name: "rp", type: "relay", task: "p"},
            %Instance{name: "rc", type: "relay", task: "c"}
          ],
          connections: for(i <- ~w(rp rc), do: %Connection{instance: i, member: "in", to: 0})
        )

      # At 15: c due at 10, p at 12: c waited longer, though declared later.
      assert Enum.map(run(config, [{0, %{}}, {15, %{}}]), &ran/1) == [
               [{"p", "rp", 0}, {"c", "rc", 0}],
               [{"c", "rc", 15}, {"p", "rp", 15}]
             ]
    end

    test "a task with single alone never overlaps, and has no periodic due time" do
      config = one_event(event("e", "trig", 0))
      runtime = Runtime.start(config)
      assert Runtime.next_due_in(runtime) == :infinity
      {runtime, _, _} = Runtime.cycle(runtime, 1_000, %{"trig" => 1})
      {runtime, _, _} = Runtime.cycle(runtime, 1_000, %{"trig" => 0})
      {runtime, _, _} = Runtime.cycle(runtime, 1_000, %{"trig" => 1})
      assert Runtime.overlaps(runtime) == %{"e" => 0}
      assert Runtime.next_due_in(runtime) == :infinity
    end
  end

  describe "restart/2 (org §4.9: the last sample to 0)" do
    test "a trigger already 1 fires again in the next cycle, held input point or initial value" do
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
      # The input image is kept, so `trig` is still 1; `a` is back at its initial 1.
      {_runtime, _, events} = Runtime.cycle(runtime, 0, %{})
      assert ran(events) == [{"held", "r1", 7}, {"armed", "r2", 7}, {"b", "r3", 7}]
    end

    test "after restart/2, next_due_in/1 counts no event task alone: a runner cycles at once" do
      runtime = Runtime.start(one_event(event("e", "trig", 0)))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      runtime = Runtime.restart(runtime, :cold)
      assert Runtime.next_due_in(runtime) == :infinity
      assert {_, _, [{:ran, "e", "r", 0}]} = Runtime.cycle(runtime, 0, %{})
    end
  end

  describe "a ton in an event-task program (org §4.6 caveat)" do
    test "times across events: the time between them counts" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [program(@timer, "timed")],
          tasks: [event("e", "trig", 0)],
          globals: points(~w(trig), "i") ++ points(~w(done), "q"),
          instances: [%Instance{name: "t", type: "timed", task: "e"}],
          connections: [
            %Connection{instance: "t", member: "go", to: 1},
            %Connection{instance: "t", member: "done", to: "done"}
          ]
        )

      runtime = Runtime.start(config)
      # The timer starts at the first event, 0 ms, and runs again only at the next, 60 ms
      # later: 60 ms counted, though it ran twice.
      {runtime, %{"done" => 0}, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      {runtime, %{"done" => 0}, []} = Runtime.cycle(runtime, 30, %{"trig" => 0})
      {runtime, %{"done" => 0}, _} = Runtime.cycle(runtime, 30, %{"trig" => 1})
      assert Runtime.get!(runtime, "t.t1.acc") == 60
      {runtime, _, []} = Runtime.cycle(runtime, 500, %{"trig" => 0})
      assert Runtime.get!(runtime, "t.t1.acc") == 60
      # The next event, 500 ms later: done at once, by time no scan saw.
      {runtime, %{"done" => 1}, _} = Runtime.cycle(runtime, 0, %{"trig" => 1})
      assert Runtime.get!(runtime, "t.t1.acc") == 100
    end
  end

  describe "the events" do
    test "an event task's run is its {:ran, ...} events alone; one with no instance leaves none" do
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
  end

  describe "growth" do
    # n event tasks on one input point, each running one relay, and one periodic task.
    defp crowd(n) do
      relay = program(@relay, "relay")

      Configuration.new!(
        name: "plant",
        programs: [relay],
        tasks: [
          periodic("p", 10, 0)
          | for(i <- 1..n, do: both("e#{i}", "trig", 10 + rem(i, 7), rem(i, 5)))
        ],
        globals: points(~w(trig), "i"),
        instances: for(i <- 1..n, do: %Instance{name: "r#{i}", type: "relay", task: "e#{i}"}),
        connections: for(i <- 1..n, do: %Connection{instance: "r#{i}", member: "in", to: "trig"})
      )
    end

    defp reductions(n, inputs) do
      runtime = Runtime.start(crowd(n))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"trig" => 0})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          Runtime.cycle(runtime, 5, inputs)
          Runtime.next_due_in(runtime)
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    test "a cycle stays linear in the event tasks, whether they fire or not" do
      for inputs <- [%{"trig" => 0}, %{"trig" => 1}] do
        ratio = reductions(2000, inputs) / reductions(500, inputs)
        assert ratio < 6, "4x the tasks took #{Float.round(ratio, 2)}x (#{inspect(inputs)})"
      end
    end
  end

  describe "a seeded walk against a model from the record's text" do
    @points [
      {"i0", "panel.i.0", nil},
      {"i1", "panel.i.1", nil},
      {"i2", "panel.i.2", nil},
      {"o0", "panel.q.0", nil},
      {"o1", "panel.q.1", nil},
      {"g0", nil, nil},
      {"g1", nil, 1}
    ]
    @inputs ~w(i0 i1 i2)
    @types %{
      "relay" => @relay,
      "inverter" => "var_input in bool\nvar_output out bool\nxio in ote out",
      "pulse" => "var_input in bool\nvar_output out bool\nvar s bool\nxic in ons s ote out",
      "timed" => @timer
    }

    defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

    defp walk_config(programs) do
      tasks =
        for name <- Enum.take(Enum.shuffle(~w(ta tb tc td)), :rand.uniform(5) - 1) do
          single = pick(Enum.map(@points, &elem(&1, 0)))

          case :rand.uniform(3) do
            1 -> periodic(name, pick([5, 10, 15, 30]), pick([0, 1, 1, 2]))
            2 -> event(name, single, pick([0, 1, 1, 2]))
            3 -> both(name, single, pick([5, 10, 15, 30]), pick([0, 1, 1, 2]))
          end
        end

      instances =
        for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4 m5)), :rand.uniform(5)),
            do: %Instance{
              name: name,
              type: pick(Map.keys(programs)),
              task: pick([nil | Enum.map(tasks, & &1.name)])
            }

      {connections, _} =
        Enum.flat_map_reduce(instances, MapSet.new(), fn instance, driven ->
          tags = programs[instance.type].tags |> Map.values() |> Enum.sort_by(& &1.name)

          ins =
            for %{section: :var_input} = tag <- tags,
                do: %Connection{
                  instance: instance.name,
                  member: tag.name,
                  to: pick(Enum.map(@points, &elem(&1, 0)) ++ [0, 1])
                }

          {outs, driven} =
            Enum.flat_map_reduce(
              for(%{section: :var_output} = tag <- tags, do: tag),
              driven,
              fn tag, driven ->
                sinks = for s <- ~w(o0 o1 g0 g1), s not in driven, :rand.uniform(2) == 1, do: s

                outs =
                  for s <- Enum.take(sinks, 1),
                      do: %Connection{instance: instance.name, member: tag.name, to: s}

                {outs, Enum.reduce(outs, driven, &MapSet.put(&2, &1.to))}
              end
            )

          {ins ++ outs, driven}
        end)

      Configuration.new!(
        name: "plant",
        programs: Map.values(programs),
        tasks: tasks,
        globals:
          for(
            {name, at, initial} <- @points,
            do: %Global{name: name, type: :bool, at: at, initial: initial}
          ),
        instances: instances,
        connections: connections
      )
    end

    defp initial(name), do: Enum.find_value(@points, 0, fn {n, _, i} -> n == name && (i || 0) end)

    # The model, from the record's words alone (§4.6 steps 1-5, decision 39, §4.10 M2-6):
    # each task's phase points are anchor + k * interval, `next` the first not yet run,
    # skipped or counted; `last` its trigger's last sample, 0 at start and restart.
    defp model_start(config),
      do: %{
        now: 0,
        globals: Map.new(@points, fn {n, _, i} -> {n, i || 0} end),
        states: Map.new(config.instances, &{&1.name, Runtime.instance(config.programs[&1.type])}),
        tasks:
          Map.new(
            config.tasks,
            &{&1.name, %{anchor: 0, next: &1.interval && 0, last: 0, overlaps: 0}}
          )
      }

    defp model_restart(config, model),
      do: %{
        model
        | globals:
            Map.new(model.globals, fn {n, v} -> {n, if(n in @inputs, do: v, else: initial(n))} end),
          states:
            Map.new(model.states, fn {n, s} ->
              {n, Runtime.restart(config.programs[s.type], s, :cold)}
            end),
          tasks:
            Map.new(
              config.tasks,
              &{&1.name,
               %{anchor: model.now, next: &1.interval && model.now, last: 0, overlaps: 0}}
            )
      }

    defp model_cycle(config, model, elapsed, inputs) do
      now = model.now + elapsed
      globals = Map.merge(model.globals, inputs)

      # Step 3: every trigger sampled, then what each task does.
      {plans, tasks} =
        config.tasks
        |> Enum.with_index()
        |> Enum.map_reduce(model.tasks, fn {task, index}, tasks ->
          t = tasks[task.name]
          sample = task.single && globals[task.single]
          edge? = task.single != nil and t.last == 0 and sample == 1
          t = if task.single, do: %{t | last: sample}, else: t
          come? = task.interval != nil and t.next <= now

          phase_after = fn ->
            t.anchor + (div(now - t.anchor, task.interval) + 1) * task.interval
          end

          {plan, t} =
            cond do
              edge? and come? ->
                {{:edge, now}, %{t | next: phase_after.()}}

              edge? ->
                {{:edge, now}, t}

              come? and sample == 1 ->
                {nil, %{t | next: phase_after.()}}

              come? ->
                missed =
                  div(now - t.anchor, task.interval) - div(t.next - t.anchor, task.interval)

                {{:periodic, t.next, missed},
                 %{t | next: phase_after.(), overlaps: t.overlaps + missed}}

              true ->
                {nil, t}
            end

          {plan && {task, index, plan}, Map.put(tasks, task.name, t)}
        end)

      due =
        plans
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn {task, index, plan} -> {task.priority, elem(plan, 1), index} end)

      model = %{model | now: now, globals: globals, tasks: tasks}

      {model, events} =
        Enum.reduce(due, {model, []}, fn {task, _index, plan}, {model, events} ->
          events =
            case plan do
              {:periodic, _, missed} when missed > 0 -> [{:overlap, task.name, missed} | events]
              _ -> events
            end

          Enum.reduce(
            for(i <- config.instances, i.task == task.name, do: i),
            {model, events},
            &model_scan(config, &1, task.name, &2)
          )
        end)

      {model, events} =
        Enum.reduce(
          for(i <- config.instances, i.task == nil, do: i),
          {model, events},
          &model_scan(config, &1, :none, &2)
        )

      outputs =
        for {n, at, _} <- @points, at != nil and at =~ ".q.", into: %{}, do: {n, model.globals[n]}

      {model, outputs, Enum.reverse(events)}
    end

    defp model_scan(config, instance, task, {model, events}) do
      program = config.programs[instance.type]
      mine = for c <- config.connections, c.instance == instance.name, do: c

      inputs =
        for c <- mine,
            program.tags[c.member].section == :var_input,
            into: %{},
            do: {c.member, if(is_binary(c.to), do: model.globals[c.to], else: c.to)}

      state = model.states[instance.name]

      {outputs, state} =
        Runtime.call(program, state, inputs, %Scan{now: model.now, first: state.first})

      globals =
        for c <- mine, program.tags[c.member].section == :var_output, reduce: model.globals do
          globals -> Map.put(globals, c.to, outputs[c.member])
        end

      {%{model | states: Map.put(model.states, instance.name, state), globals: globals},
       [{:ran, task, instance.name, model.now} | events]}
    end

    defp model_next_due_in(model) do
      case for({_, %{next: n}} <- model.tasks, n != nil, do: n) do
        [] -> :infinity
        nexts -> Enum.min(nexts) - model.now
      end
    end

    defp reach(name, true),
      do: Process.put(:reach, MapSet.put(Process.get(:reach, MapSet.new()), name))

    defp reach(_name, false), do: :ok

    defp walk(_config, _runtime, _model, _seen, _fresh, 0), do: :ok

    defp walk(config, runtime, model, seen, fresh, n) do
      if :rand.uniform(12) == 1 do
        runtime = Runtime.restart(runtime, :cold)
        model = model_restart(config, model)
        reach(:restart, true)
        walk(config, runtime, model, Map.new(config.tasks, &{&1.name, 0}), :restart, n - 1)
      else
        elapsed = pick([0, 1, 3, 5, 7, 10, 10, 25, 40])
        inputs = for i <- @inputs, :rand.uniform(3) == 1, into: %{}, do: {i, :rand.uniform(2) - 1}

        # The oracle's samples, from outside: each trigger's value going into this cycle,
        # an input point's as the inputs set it.
        samples =
          Map.new(config.tasks, fn task ->
            {task.name,
             task.single && Map.get(inputs, task.single, Runtime.get!(runtime, task.single))}
          end)

        {next, outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
        before = model
        {model, expected_outputs, expected_events} = model_cycle(config, model, elapsed, inputs)

        assert events == expected_events
        assert outputs == expected_outputs
        assert Runtime.overlaps(next) == Map.new(model.tasks, fn {n, t} -> {n, t.overlaps} end)
        assert Runtime.next_due_in(next) == model_next_due_in(model)
        for {name, value} <- model.globals, do: assert(Runtime.get!(next, name) == value)

        for instance <- config.instances,
            {tag, value} <- model.states[instance.name].env,
            is_integer(value),
            do: assert(Runtime.get!(next, "#{instance.name}.#{tag}") == value)

        # Oracles that know only the samples: an event task runs exactly on its edges; a
        # task with single and interval runs on every edge, never while its trigger stays
        # 1, and at most once a cycle.
        ran_tasks = Enum.dedup(for {:ran, t, _, _} <- events, t != :none, do: t)
        has_instance = MapSet.new(for i <- config.instances, i.task != nil, do: i.task)

        for task <- config.tasks, task.single != nil, MapSet.member?(has_instance, task.name) do
          edge? = seen[task.name] == 0 and samples[task.name] == 1
          held? = seen[task.name] == 1 and samples[task.name] == 1
          runs = Enum.count(ran_tasks, &(&1 == task.name))
          assert runs <= 1
          if task.interval == nil, do: assert(runs == if(edge?, do: 1, else: 0))
          if edge?, do: assert(runs == 1)
          if held?, do: assert(runs == 0)
          reach({:edge, task.interval == nil}, edge?)

          reach(
            :held_skip,
            held? and task.interval != nil and before.tasks[task.name].next <= model.now
          )

          reach(:first_cycle_edge, edge? and fresh == :start)
          reach(:restart_refire, edge? and fresh == :restart)
          reach(:logic_trigger, edge? and task.single in ~w(o0 o1 g0) and fresh == false)
        end

        reach(
          :overlap_under_zero,
          Enum.any?(config.tasks, fn task ->
            name = task.name

            task.single != nil and task.interval != nil and
              Enum.any?(events, &match?({:overlap, ^name, _}, &1))
          end)
        )

        by_name = Map.new(config.tasks, &{&1.name, &1})
        order = for t <- ran_tasks, do: by_name[t]

        for [a, b] <- Enum.chunk_every(order, 2, 1, :discard) do
          assert a.priority <= b.priority

          reach(
            :tie_event_periodic,
            a.priority == b.priority and is_nil(a.single) != is_nil(b.single)
          )
        end

        seen = Map.new(config.tasks, &{&1.name, samples[&1.name] || 0})
        walk(config, next, model, seen, false, n - 1)
      end
    end

    test "event, periodic and combined tasks run as the record's rules say" do
      programs = Map.new(@types, fn {name, source} -> {name, program(source, name)} end)
      :rand.seed(:exsss, {2026, 10, String.to_integer(System.get_env("WALK_SEED", "4"))})

      for _ <- 1..300 do
        config = walk_config(programs)

        walk(
          config,
          Runtime.start(config),
          model_start(config),
          Map.new(config.tasks, &{&1.name, 0}),
          :start,
          40
        )
      end

      assert Process.get(:reach) ==
               MapSet.new([
                 :restart,
                 {:edge, true},
                 {:edge, false},
                 :held_skip,
                 :first_cycle_edge,
                 :restart_refire,
                 :logic_trigger,
                 :overlap_under_zero,
                 :tie_event_periodic
               ])
    end
  end
end
