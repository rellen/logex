defmodule Logex.ExternalTest do
  @moduledoc """
  M2-4, spiked: `var_external`, a global shared by name (`docs/organisation.md` §4.4,
  §4.6, §4.9 and §4.10). Its declaration, its binding in `Logex.Configuration.check/1`,
  the configuration's two writer warnings, and one copy of each global at run time: the
  scheduler merges each var_external's global into the instance's env before `call/4` and
  splits it off after. The seeded walk at the end checks a resource against a model that
  knows nothing of the merge: it runs each program as Elixir over one map of globals.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Runtime, Scan}
  alias Logex.Configuration.{Connection, Global, Instance}

  defp program(source, name) do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  defp messages(source) do
    {:error, diagnostics} = Logex.compile(source, name: "p")
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp refused(fields) do
    error = assert_raise ArgumentError, fn -> Configuration.new!(fields) end
    String.split(error.message, "\n")
  end

  # The README motor with an e-stop shared through var_external, which latches `fault`.
  @motor """
  var_input start bool
  var_input stop bool
  var_input reset bool
  var_output motor bool
  var_external estop bool
  var fault bool

  xic estop otl fault
  xic reset otu fault
  ( xic start | xic motor ) xio stop xio fault ote motor
  """

  defp plant(tasks, instances) do
    Configuration.new!(
      name: "plant",
      programs: [program(@motor, "motor")],
      tasks: tasks,
      globals: [
        %Global{name: "estop", type: :bool, at: "panel.i.7"},
        %Global{name: "go", type: :bool, at: "panel.i.0"},
        %Global{name: "k1", type: :bool, at: "panel.q.0"},
        %Global{name: "k2", type: :bool, at: "panel.q.1"}
      ],
      instances: instances,
      connections:
        for(
          {m, k} <- [{"m1", "k1"}, {"m2", "k2"}],
          {member, to} <- [{"start", "go"}, {"stop", 0}, {"reset", 0}, {"motor", k}],
          do: %Connection{instance: m, member: member, to: to}
        )
    )
  end

  defp task(name, interval, priority),
    do: %Configuration.Task{name: name, interval: interval, priority: priority}

  defp cycles(runtime, steps) do
    Enum.map_reduce(steps, runtime, fn {elapsed, inputs}, runtime ->
      {runtime, outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
      {{outputs, for({:ran, _, instance, _} <- events, do: instance)}, runtime}
    end)
  end

  # The opaque resource, looked into on purpose: one copy of each global means no
  # instance's env holds a var_external between scans.
  defp envs_hold(runtime, name),
    do: for({instance, state} <- runtime.instances, Map.has_key?(state.env, name), do: instance)

  describe "the declaration" do
    test "a var_external is a bool or a dint, takes no initial value and is no instance" do
      assert messages("var_external e bool 1\nvar_output o bool\nxic e ote o") == [
               "line 1: `e` is a var_external: its value is the configuration's global of " <>
                 "that name, so it takes no initial value",
               "line 3: `e` is not declared"
             ]

      assert hd(messages("var_external t ton\nxic t.dn ote t.dn")) ==
               "line 1: `t` is a ton: an instance is the program's own, declared with `var`, " <>
                 "as in `var t ton`, not with `var_external`"
    end

    test "logic reads and writes one, without a warning, and the word is reserved" do
      assert program("var_external e bool\nvar_input i bool\nxic i ote e\nxic e otl e", "p").warnings ==
               []

      assert hd(messages("var var_external bool\nxic var_external ote var_external")) ==
               "line 1: `var_external` is a keyword and cannot name a tag"
    end

    test "which tags a program writes, from its IR" do
      p =
        program(
          "var_external e bool\nvar_external n dint\nvar s bool\nvar t1 ton\nvar_input i bool\n" <>
            "xic i ons s ote e\nxic e move 5 n\nxic e ton t1 10\nxic i move 3 t1.acc",
          "p"
        )

      assert Logex.Compiler.writes(p) == %{"e" => 6, "n" => 7, "s" => 6, "t1" => 8}
    end
  end

  describe "binding, in check/1" do
    defp bound(globals, extra \\ []) do
      Keyword.merge(
        [
          name: "plant",
          programs: [
            program(@motor, "motor"),
            program("var_external estop bool\nvar_input i bool\nxic i ote estop", "writer")
          ],
          globals: globals,
          instances: [%Instance{name: "m1", type: "motor"}, %Instance{name: "m2", type: "motor"}],
          connections:
            for(
              m <- ~w(m1 m2),
              x <- ~w(start stop reset),
              do: %Connection{instance: m, member: x, to: 0}
            )
        ],
        extra
      )
    end

    test "a var_external with no global of its name, cited once a type; an uninstantiated type is not checked" do
      assert refused(bound([%Global{name: "estp", type: :bool}])) == [
               "program instance `m1`: `motor` declares `var_external estop bool` (line 5), but " <>
                 "there is no global `estop` — did you mean `estp`?"
             ]
    end

    test "a var_external whose global has another type" do
      assert refused(bound([%Global{name: "estop", type: :dint}])) == [
               "program instance `m1`: `motor` declares `var_external estop bool` (line 5), but " <>
                 "`estop` is a dint"
             ]
    end

    test "an input point is read through a var_external, and never written" do
      assert %Configuration{warnings: []} =
               Configuration.new!(bound([%Global{name: "estop", type: :bool, at: "panel.i.0"}]))

      assert refused(
               bound([%Global{name: "estop", type: :bool, at: "panel.i.0"}],
                 instances: [%Instance{name: "w", type: "writer"}],
                 connections: [%Connection{instance: "w", member: "i", to: 1}]
               )
             ) == [
               "program instance `w`: `writer` writes its var_external `estop` (line 3), but " <>
                 "`estop` is an input point: nothing writes an input point"
             ]
    end

    test "a var_external is not connected, with the message a var gets (its word to settle)" do
      assert refused(
               bound([%Global{name: "estop", type: :bool}],
                 connections:
                   [%Connection{instance: "m1", member: "estop", to: "estop"}] ++
                     for(
                       m <- ~w(m1 m2),
                       x <- ~w(start stop reset),
                       do: %Connection{instance: m, member: x, to: 0}
                     )
               )
             ) == [
               "`m1.estop` is internal to `motor` (declared `var_external`): only a var_input " <>
                 "or var_output connects"
             ]
    end
  end

  describe "the configuration's writer warnings" do
    test "two instances that write one global, and an instance that writes one a connection drives" do
      writer = program("var_external g bool\nvar_input i bool\nxic i ote g", "writer")
      relay = program("var_input a bool\nvar_output b bool\nxic a ote b", "relay")

      both =
        program(
          "var_external h bool\nvar_input i bool\nvar_output o bool\nxic i ote h\nxio i ote o",
          "both"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [writer, relay, both],
          globals: [
            %Global{name: "g", type: :bool, at: "panel.q.0"},
            %Global{name: "h", type: :bool},
            %Global{name: "x", type: :bool, at: "panel.i.0"}
          ],
          instances: [
            %Instance{name: "w1", type: "writer"},
            %Instance{name: "w2", type: "writer"},
            %Instance{name: "r", type: "relay"},
            %Instance{name: "b", type: "both"}
          ],
          connections: [
            %Connection{instance: "w1", member: "i", to: "x"},
            %Connection{instance: "w2", member: "i", to: 1},
            %Connection{instance: "r", member: "a", to: "x"},
            %Connection{instance: "r", member: "b", to: "g"},
            %Connection{instance: "b", member: "i", to: "x"},
            %Connection{instance: "b", member: "o", to: "h"}
          ]
        )

      assert Enum.map(config.warnings, &{&1.severity, &1.stage, &1.message}) == [
               {:warning, :configure,
                "`w2` writes `g` through its var_external, as `w1` does: of two writers in one " <>
                  "cycle, the one that runs later wins"},
               {:warning, :configure,
                "`w1` writes `g` through its var_external, and `r.b` drives it: of the two in " <>
                  "one cycle, the one that runs later wins"},
               {:warning, :configure,
                "`w2` writes `g` through its var_external, and `r.b` drives it: of the two in " <>
                  "one cycle, the one that runs later wins"},
               {:warning, :configure,
                "`b` writes `h` through its var_external, and `b.o` drives it: its own " <>
                  "copy-out, after the scan, wins"}
             ]

      # The copy-out lands after the write through the var_external, in one scan.
      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(config), 0, %{"x" => 1})
      assert Runtime.get(runtime, "h") == {:ok, 0}
      assert Runtime.get(runtime, "b.h") == {:ok, 0}
    end
  end

  describe "one copy of each global at run time" do
    test "the Done-when: an e-stop read by two instances through var_external stops both in the same cycle" do
      config =
        plant([task("fast", 10, 1)], [
          %Instance{name: "m1", type: "motor", task: "fast"},
          %Instance{name: "m2", type: "motor", task: "fast"}
        ])

      {trace, runtime} =
        cycles(Runtime.start(config), [
          {0, %{"go" => 1}},
          {10, %{"go" => 0}},
          {10, %{"estop" => 1}},
          {10, %{"estop" => 0}}
        ])

      assert Enum.map(trace, &elem(&1, 0)) == [
               %{"k1" => 1, "k2" => 1},
               %{"k1" => 1, "k2" => 1},
               %{"k1" => 0, "k2" => 0},
               %{"k1" => 0, "k2" => 0}
             ]

      assert Runtime.get(runtime, "m1.fault") == {:ok, 1}
      assert Runtime.get(runtime, "m2.fault") == {:ok, 1}
      assert envs_hold(runtime, "estop") == []
    end

    test "an instance on a slower task sees the e-stop only when it next runs, and misses a shorter pulse" do
      config =
        plant([task("fast", 10, 1), task("slow", 50, 2)], [
          %Instance{name: "m1", type: "motor", task: "fast"},
          %Instance{name: "m2", type: "motor", task: "slow"}
        ])

      {trace, runtime} =
        cycles(
          Runtime.start(config),
          [{0, %{"go" => 1}}, {10, %{"go" => 0}}, {10, %{"estop" => 1}}, {10, %{"estop" => 0}}] ++
            List.duplicate({10, %{}}, 3)
        )

      assert Enum.map(trace, &elem(&1, 0)["k2"]) == [1, 1, 1, 1, 1, 1, 1]
      assert Enum.map(trace, &elem(&1, 0)["k1"]) == [1, 1, 0, 0, 0, 0, 0]
      assert Runtime.get(runtime, "m2.fault") == {:ok, 0}
    end

    test "an instance sees a global an earlier instance wrote in the cycle, and a later one's in the next" do
      w = program("var_external x bool\nvar_external g bool\nxic x ote g", "w")
      r = program("var_external g bool\nvar_external y bool\nxic g ote y", "r")

      config = fn tasks, instances ->
        Configuration.new!(
          name: "plant",
          programs: [w, r],
          tasks: tasks,
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "g", type: :bool},
            %Global{name: "y", type: :bool, at: "panel.q.0"}
          ],
          instances: instances
        )
      end

      steps = [{0, %{"x" => 0}}, {10, %{"x" => 1}}, {10, %{"x" => 0}}, {10, %{}}]

      y = fn config ->
        config |> Runtime.start() |> cycles(steps) |> elem(0) |> Enum.map(&elem(&1, 0)["y"])
      end

      t = [task("t", 10, 0)]

      # Declaration order within a task; priority across tasks; task-less last.
      assert y.(
               config.(t, [
                 %Instance{name: "w", type: "w", task: "t"},
                 %Instance{name: "r", type: "r", task: "t"}
               ])
             ) == [0, 1, 0, 0]

      assert y.(
               config.(t, [
                 %Instance{name: "r", type: "r", task: "t"},
                 %Instance{name: "w", type: "w", task: "t"}
               ])
             ) == [0, 0, 1, 0]

      assert y.(
               config.([task("hi", 10, 0), task("lo", 10, 1)], [
                 %Instance{name: "w", type: "w", task: "lo"},
                 %Instance{name: "r", type: "r", task: "hi"}
               ])
             ) ==
               [0, 0, 1, 0]

      assert y.(
               config.(t, [
                 %Instance{name: "w", type: "w"},
                 %Instance{name: "r", type: "r", task: "t"}
               ])
             ) == [0, 0, 1, 0]

      # A slower writer's value holds between its runs.
      slow =
        config.([task("slow", 30, 0), task("fast", 10, 1)], [
          %Instance{name: "w", type: "w", task: "slow"},
          %Instance{name: "r", type: "r", task: "fast"}
        ])

      {trace, _} =
        cycles(Runtime.start(slow), [{0, %{"x" => 1}}, {10, %{"x" => 0}}, {10, %{}}, {10, %{}}])

      assert Enum.map(trace, &elem(&1, 0)["y"]) == [1, 1, 1, 0]
    end

    test "an output point written through var_external, and restart/2, which no var_external survives" do
      p =
        program(
          "var_external x bool\nvar_external k bool\nvar_external n dint\nxic x ote k\nxic x move 40 n",
          "p"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [p],
          globals: [
            %Global{name: "x", type: :bool, at: "panel.i.0"},
            %Global{name: "k", type: :bool, at: "panel.q.0"},
            %Global{name: "n", type: :dint, initial: 7}
          ],
          instances: [%Instance{name: "m", type: "p"}]
        )

      runtime = Runtime.start(config)
      assert envs_hold(runtime, "n") == []
      assert {Runtime.get(runtime, "m.n"), Runtime.get(runtime, "m.k")} == {{:ok, 7}, {:ok, 0}}
      {runtime, outputs, _} = Runtime.cycle(runtime, 0, %{"x" => 1})
      assert outputs == %{"k" => 1}
      assert Runtime.get!(runtime, "m.n") == 40
      runtime = Runtime.restart(runtime, :cold)
      assert envs_hold(runtime, "n") == []
      assert envs_hold(runtime, "x") == []

      assert {Runtime.get!(runtime, "m.k"), Runtime.get!(runtime, "m.n"),
              Runtime.get!(runtime, "m.x")} ==
               {0, 7, 1}

      assert {_, %{"k" => 1}, _} = Runtime.cycle(runtime, 0, %{})
    end

    test "get/2 reads an instance's var_external as the global, whoever wrote it last" do
      reader = program("var_external g bool\nvar_output o bool\nxic g ote o", "reader")
      writer = program("var_external g bool\nvar_input i bool\nxic i ote g", "writer")

      config =
        Configuration.new!(
          name: "plant",
          programs: [reader, writer],
          globals: [
            %Global{name: "g", type: :bool},
            %Global{name: "x", type: :bool, at: "panel.i.0"}
          ],
          instances: [%Instance{name: "r", type: "reader"}, %Instance{name: "w", type: "writer"}],
          connections: [%Connection{instance: "w", member: "i", to: "x"}]
        )

      {runtime, _, _} = Runtime.cycle(Runtime.start(config), 0, %{"x" => 1})
      assert Runtime.get(runtime, "r.g") == {:ok, 1}
      assert Runtime.get(runtime, "r.o") == {:ok, 0}
      assert Runtime.get!(runtime, "r.g") == Runtime.get!(runtime, "g")

      assert Runtime.get(runtime, "r.g.x") ==
               {:error, "`r.g.x` goes too deep: `r.g` is a bool, which has no members"}
    end
  end

  describe "a program run alone" do
    test "keeps its var_external as a tag of its own, at 0, which its host cannot set" do
      p = program(@motor, "motor")
      state = Runtime.instance(p)
      assert state.env["estop"] == 0

      error = assert_raise ArgumentError, fn -> Runtime.put_inputs(p, state, %{"estop" => 1}) end

      assert error.message ==
               "input `estop` is a var_external (declared on line 5), not a var_input: only a " <>
                 "var_input is set from outside"
    end

    # What scan/2 and restart/3 give a lone instance's var_external is what a configuration
    # of that one instance gives an unlocated global of no initial value that only it uses.
    test "agrees with a one-instance configuration whose global is unlocated, at 0" do
      p =
        program(
          "var_input i bool\nvar_input j bool\nvar_output o bool\nvar_external g bool\nvar s bool\n" <>
            "xic i ons s otl g\nxic j otu g\nxic g ote o",
          "p"
        )

      config =
        Configuration.new!(
          name: "plant",
          programs: [p],
          globals: [
            %Global{name: "i", type: :bool, at: "panel.i.0"},
            %Global{name: "j", type: :bool, at: "panel.i.1"},
            %Global{name: "o", type: :bool, at: "panel.q.0"},
            %Global{name: "g", type: :bool}
          ],
          instances: [%Instance{name: "m", type: "p"}],
          connections: for(x <- ~w(i j o), do: %Connection{instance: "m", member: x, to: x})
        )

      :rand.seed(:exsss, {2026, 10, 4})

      Enum.reduce(1..400, {Runtime.instance(p), Runtime.start(config)}, fn _, {state, runtime} ->
        {state, runtime} =
          case :rand.uniform(25) do
            1 -> {Runtime.restart(p, state, :cold), Runtime.restart(runtime, :cold)}
            _ -> {state, runtime}
          end

        inputs = Map.new(Enum.take_random(~w(i j), :rand.uniform(2)), &{&1, :rand.uniform(2) - 1})
        state = Runtime.put_inputs(p, state, inputs)
        {scanned, state} = Runtime.scan(p, state, 1)
        {runtime, cycled, _} = Runtime.cycle(runtime, 1, inputs)
        assert scanned == cycled
        assert Runtime.get!(runtime, "m.g") == state.env["g"]
        assert Runtime.get!(runtime, "m.s") == state.env["s"]
        {state, runtime}
      end)
    end

    test "Logex.Edit moves a var_external as any tag: a section change keeps the value" do
      a =
        program("var_input i bool\nvar_output o bool\nvar g bool\nxic i otl g\nxic g ote o", "e")

      b =
        program(
          "var_input i bool\nvar_output o bool\nvar_external g bool\nxic i otl g\nxic g ote o",
          "e"
        )

      {_, state} = Runtime.call(a, Runtime.instance(a), %{"i" => 1}, %Scan{now: 0, first: true})
      {:ok, edit, []} = Edit.accept(a, b, state)
      {edit, state, []} = Edit.test(edit, state)
      assert state.env["g"] == 1
      {^b, state, []} = Edit.assemble(edit, state)
      assert state.env["g"] == 1

      to_input =
        program("var_input i bool\nvar_output o bool\nvar_input g bool\nxic g ote o", "e")

      assert {:ok, _, [{:input, "g", 0}]} = Edit.accept(b, to_input, Runtime.instance(b))
    end

    # Why an edit inside a resource (OE-2) must merge the globals in first: over the env a
    # resource holds between scans, which has no var_external, the edit starts it again.
    test "Logex.Edit over an env with no var_external in it reports one :added" do
      b =
        program(
          "var_input i bool\nvar_output o bool\nvar_external g bool\nxic i otl g\nxic g ote o",
          "e"
        )

      state = %{Runtime.instance(b) | env: Map.delete(Runtime.instance(b).env, "g")}
      assert {:ok, _, [{:added, "g", 0}]} = Edit.accept(b, b, state)
    end
  end

  describe "growth" do
    defp shared(n, k, section) do
      decl = for j <- 1..k, do: "#{section} g#{j} bool\n"
      rungs = for j <- 1..k, do: "xio g#{j} ote g#{j}\n"
      p = program(Enum.join(decl) <> Enum.join(rungs), "p")

      config =
        Configuration.new!(
          name: "plant",
          programs: [p],
          globals: for(j <- 1..k, do: %Global{name: "g#{j}", type: :bool}),
          instances: for(i <- 1..n, do: %Instance{name: "m#{i}", type: "p"})
        )

      {runtime, _, _} = Runtime.cycle(Runtime.start(config), 0, %{})
      reductions(fn -> Runtime.cycle(runtime, 10, %{}) end)
    end

    defp reductions(fun) do
      for _ <- 1..3 do
        task =
          Task.async(fn ->
            {:reductions, before} = Process.info(self(), :reductions)
            fun.()
            {:reductions, after_} = Process.info(self(), :reductions)
            after_ - before
          end)

        Task.await(task)
      end
      |> Enum.min()
    end

    test "a cycle is linear in the instances and in their var_externals" do
      assert shared(100, 8, "var_external") / shared(25, 8, "var_external") < 5.1
      assert shared(25, 32, "var_external") / shared(25, 8, "var_external") < 5.1
    end
  end

  # ---- The walk: a resource against a model with no merge and no split. ----

  # Each program type, with what one scan of it does to the globals and its own state, as
  # Elixir: `{globals, own}` from `{globals, own, inputs, first}`, `inputs` its var_inputs as
  # copied in. A var_external is the global itself, read and written in place.
  @types %{
    "copy" => "var_external i0 bool\nvar_external g0 bool\nxic i0 ote g0",
    "chain" =>
      "var_external g0 bool\nvar_external g1 bool\nvar_external q0 bool\nxic g0 ote g1\nxic g1 ote q0",
    "latch" =>
      "var_external i1 bool\nvar_external g1 bool\nvar_external i0 bool\nxic i1 otl g1\nxic i0 otu g1",
    "pulse" => "var_external g0 bool\nvar_external q1 bool\nvar s bool\nxic g0 ons s ote q1",
    "dint" =>
      "var_external d0 dint\nvar_external n0 dint\nvar_external a0 dint\ngt d0 10 move d0 n0\nmove n0 a0",
    "mixed" =>
      "var_input in bool\nvar_output out bool\nvar_external g0 bool\nxic in ote g0\nxio g0 ote out"
  }

  defp run("copy", {gl, own, _in, _first}), do: {Map.put(gl, "g0", gl["i0"]), own}

  defp run("chain", {gl, own, _in, _first}) do
    gl = Map.put(gl, "g1", gl["g0"])
    {Map.put(gl, "q0", gl["g1"]), own}
  end

  defp run("latch", {gl, own, _in, _first}) do
    gl = if gl["i1"] == 1, do: Map.put(gl, "g1", 1), else: gl
    {if(gl["i0"] == 1, do: Map.put(gl, "g1", 0), else: gl), own}
  end

  defp run("pulse", {gl, own, _in, first}) do
    fired = gl["g0"] == 1 and own["s"] == 0 and not first
    {Map.put(gl, "q1", if(fired, do: 1, else: 0)), %{"s" => gl["g0"]}}
  end

  defp run("dint", {gl, own, _in, _first}) do
    gl = if gl["d0"] > 10, do: Map.put(gl, "n0", gl["d0"]), else: gl
    {Map.put(gl, "a0", gl["n0"]), own}
  end

  defp run("mixed", {gl, own, inputs, _first}) do
    gl = Map.put(gl, "g0", inputs["in"])
    {gl, Map.put(own, "out", if(gl["g0"] == 1, do: 0, else: 1))}
  end

  @globals [
    {"i0", :bool, "panel.i.0", nil},
    {"i1", :bool, "panel.i.1", nil},
    {"d0", :dint, "drive.i.0", nil},
    {"g0", :bool, nil, nil},
    {"g1", :bool, nil, 1},
    {"n0", :dint, nil, 7},
    {"q0", :bool, "panel.q.0", nil},
    {"q1", :bool, "panel.q.1", nil},
    {"a0", :dint, "drive.q.0", nil}
  ]

  test "a seeded walk of resources against a model that runs each program over one map of globals" do
    programs = Map.new(@types, fn {name, source} -> {name, program(source, name)} end)
    :rand.seed(:exsss, {2026, 10, 424})

    for _ <- 1..120 do
      config = walk_config(programs)
      walk(config, Runtime.start(config), walk_model(config), 40)
    end

    assert Process.get(:reached) ==
             MapSet.new(
               ~w(restart saw_earlier_write missed_later_write output_via_external copy_out_over_external pulse_fired dint_moved not_due)a
             )
  end

  defp reach(name, true),
    do: Process.put(:reached, MapSet.put(Process.get(:reached, MapSet.new()), name))

  defp reach(_name, false), do: :ok

  defp pick(list), do: Enum.at(list, :rand.uniform(length(list)) - 1)

  defp walk_config(programs) do
    tasks =
      for name <- Enum.take(Enum.shuffle(~w(fast mid slow)), :rand.uniform(4) - 1),
          do: task(name, pick([5, 10, 15, 30]), pick([0, 1, 1, 2]))

    instances =
      for name <- Enum.take(Enum.shuffle(~w(m1 m2 m3 m4 m5 m6)), :rand.uniform(6)),
          do: %Instance{
            name: name,
            type: pick(Map.keys(@types)),
            task: pick([nil | Enum.map(tasks, & &1.name)])
          }

    # A mixed instance copies `in` from a bool global or constant, and drives `out` into
    # an unlocated global or an output point no other connection drives.
    {connections, _} =
      Enum.flat_map_reduce(instances, ~w(g0 g1 q0 q1), fn
        %Instance{type: "mixed", name: name}, sinks ->
          source = %Connection{
            instance: name,
            member: "in",
            to: pick(~w(i0 i1 g0 g1 q0) ++ [0, 1])
          }

          case sinks do
            [] ->
              {[source], sinks}

            _ ->
              sink = pick(sinks)
              {[source, %Connection{instance: name, member: "out", to: sink}], sinks -- [sink]}
          end

        _instance, sinks ->
          {[], sinks}
      end)

    used = MapSet.new(instances, & &1.type)

    Configuration.new!(
      name: "plant",
      programs: for({name, p} <- programs, name in used, do: p),
      tasks: tasks,
      globals:
        for(
          {name, type, at, initial} <- @globals,
          do: %Global{name: name, type: type, at: at, initial: initial}
        ),
      instances: instances,
      connections: connections
    )
  end

  defp initial(name), do: Enum.find_value(@globals, fn {n, _, _, i} -> n == name and (i || 0) end)

  defp input_point?(name),
    do: Enum.any?(@globals, fn {n, _, at, _} -> n == name and at != nil and at =~ ".i." end)

  defp walk_model(config),
    do: %{
      now: 0,
      globals: Map.new(@globals, fn {n, _, _, i} -> {n, i || 0} end),
      own: Map.new(config.instances, &{&1.name, fresh_own(&1.type)}),
      first: Map.new(config.instances, &{&1.name, true}),
      next: Map.new(config.tasks, &{&1.name, 0}),
      writer: %{},
      read: %{}
    }

  defp fresh_own("pulse"), do: %{"s" => 0}
  defp fresh_own("mixed"), do: %{"out" => 0}
  defp fresh_own(_type), do: %{}

  defp walk(_config, _runtime, _model, 0), do: :ok

  defp walk(config, runtime, model, n) do
    case :rand.uniform(12) do
      1 ->
        runtime = Runtime.restart(runtime, pick([:cold, :warm]))

        model = %{
          model
          | globals:
              Map.new(model.globals, fn {g, v} ->
                {g, if(input_point?(g), do: v, else: initial(g))}
              end),
            own: Map.new(config.instances, &{&1.name, fresh_own(&1.type)}),
            first: Map.new(config.instances, &{&1.name, true}),
            next: Map.new(config.tasks, &{&1.name, model.now})
        }

        reach(:restart, true)
        check(config, runtime, model)
        walk(config, runtime, model, n - 1)

      _ ->
        elapsed = pick([0, 1, 5, 5, 10, 10, 15, 30, 47])

        inputs =
          for {name, type, at, _} <- @globals,
              at != nil and at =~ ".i.",
              :rand.uniform(2) == 1,
              into: %{},
              do: {name, if(type == :bool, do: pick([0, 1]), else: pick([0, 5, 11, 40]))}

        {runtime, outputs, events} = Runtime.cycle(runtime, elapsed, inputs)
        {model, ran} = model_cycle(config, model, elapsed, inputs)
        assert for({:ran, task, instance, _} <- events, do: {task, instance}) == ran

        assert outputs ==
                 for(
                   {name, _, at, _} <- @globals,
                   at != nil and at =~ ".q.",
                   into: %{},
                   do: {name, model.globals[name]}
                 )

        check(config, runtime, model)
        walk(config, runtime, model, n - 1)
    end
  end

  defp model_cycle(config, model, elapsed, inputs) do
    now = model.now + elapsed
    model = %{model | now: now, globals: Map.merge(model.globals, inputs), writer: %{}, read: %{}}

    due =
      config.tasks
      |> Enum.with_index()
      |> Enum.filter(fn {task, _} -> model.next[task.name] <= now end)
      |> Enum.sort_by(fn {task, index} -> {task.priority, model.next[task.name], index} end)
      |> Enum.map(&elem(&1, 0))

    reach(:not_due, length(due) < length(config.tasks) and due != [])

    {model, ran} =
      Enum.reduce(due, {model, []}, fn task, {model, ran} ->
        periods = div(now - model.next[task.name], task.interval)

        model = %{
          model
          | next:
              Map.put(
                model.next,
                task.name,
                model.next[task.name] + (periods + 1) * task.interval
              )
        }

        Enum.reduce(
          for(i <- config.instances, i.task == task.name, do: i),
          {model, ran},
          &model_scan(config, &1, task.name, &2)
        )
      end)

    Enum.reduce(
      for(i <- config.instances, i.task == nil, do: i),
      {model, ran},
      &model_scan(config, &1, :none, &2)
    )
    |> then(fn {model, ran} -> {model, Enum.reverse(ran)} end)
  end

  defp model_scan(config, instance, task, {model, ran}) do
    mine = for c <- config.connections, c.instance == instance.name, do: c

    inputs =
      for c <- mine,
          c.member == "in",
          into: %{},
          do: {"in", if(is_binary(c.to), do: model.globals[c.to], else: c.to)}

    {written, own} =
      run(
        instance.type,
        {model.globals, model.own[instance.name], inputs, model.first[instance.name]}
      )

    globals =
      for c <- mine,
          c.member == "out",
          reduce: written,
          do: (globals -> Map.put(globals, c.to, own["out"]))

    # What the walk reached: a global another instance changed earlier in this cycle, read
    # through a var_external; one this instance changes that another read earlier; an output
    # point written through one; a copy-out over this scan's own write; a one-shot fired.
    externals =
      for {name, %Logex.Tag{section: :var_external}} <- config.programs[instance.type].tags,
          do: name

    changed = for {g, v} <- written, v != model.globals[g], do: g
    others = for {g, w} <- model.writer, w != instance.name, do: g
    reach(:saw_earlier_write, Enum.any?(externals, &(&1 in others)))

    reach(
      :missed_later_write,
      Enum.any?(changed, &(Map.get(model.read, &1, instance.name) != instance.name))
    )

    reach(:output_via_external, Enum.any?(changed, &(&1 in ~w(q0 q1 a0))))

    reach(
      :copy_out_over_external,
      Enum.any?(
        mine,
        &(&1.member == "out" and written[&1.to] != own["out"] and &1.to in externals)
      )
    )

    reach(:pulse_fired, instance.type == "pulse" and written["q1"] == 1)
    reach(:dint_moved, "n0" in changed)

    model = %{
      model
      | writer: Enum.reduce(changed, model.writer, &Map.put(&2, &1, instance.name)),
        read: Enum.reduce(externals, model.read, &Map.put(&2, &1, instance.name))
    }

    {%{
       model
       | globals: globals,
         own: Map.put(model.own, instance.name, own),
         first: Map.put(model.first, instance.name, false)
     }, [{task, instance.name} | ran]}
  end

  # Every global, every var_external of every instance as its global, every own tag, and
  # no var_external held in any instance's env.
  defp check(config, runtime, model) do
    for {name, value} <- model.globals, do: assert(Runtime.get!(runtime, name) == value, name)

    for instance <- config.instances do
      program = config.programs[instance.type]

      for {name, %Logex.Tag{section: :var_external}} <- program.tags do
        assert Runtime.get!(runtime, "#{instance.name}.#{name}") == model.globals[name]
        assert envs_hold(runtime, name) == []
      end

      for {name, value} <- model.own[instance.name],
          do: assert(Runtime.get!(runtime, "#{instance.name}.#{name}") == value)
    end
  end
end
