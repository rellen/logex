defmodule Logex.ConfigEditTest do
  @moduledoc """
  OE-2: `Logex.Configuration.Edit`, the staged edit of a running configuration
  (`docs/organisation.md` §4.9, "OE-2's design"; decisions 55-65): every host mistake's
  message and the order of the checks, every refusal at accept as a whole diagnostic list
  from source and from data, and a test per rule of a step. Its plant is §4.4's, cut from
  `docs/organisation.md` with §4.3's motor and seal-in block, as `end_to_end_test.exs`
  cuts it, and each candidate is that text changed.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Diagnostic, Runtime}
  alias Logex.Configuration.Edit

  defp document, do: File.read!("docs/organisation.md")

  defp cut(after_text) do
    [_before, rest] = String.split(document(), after_text, parts: 2)
    [_before, block] = String.split(rest, "```\n", parts: 2)
    [text, _after] = String.split(block, "```", parts: 2)
    text
  end

  defp plant_text do
    [_before, rest] = String.split(document(), "```\n// plant.", parts: 2)
    [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
    plant
  end

  defp motor_ld, do: cut("**The motor, rewritten to use it**")
  defp seal_ld, do: cut("**A function block type** is")

  @snapshot_ld """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  defp programs(motor \\ motor_ld(), seal \\ seal_ld()) do
    {:ok, seal} = Logex.compile(seal, name: "seal")
    {:ok, motor} = Logex.compile(motor, name: "motor", types: [seal])
    {:ok, snapshot} = Logex.compile(@snapshot_ld, name: "snapshot")
    %{"motor" => motor, "snapshot" => snapshot}
  end

  defp plant(text \\ plant_text(), programs \\ programs()) do
    assert {:ok, config} = Configuration.compile("plant", text, programs)
    config
  end

  # The line of `text` that starts with `start`, counted from 1.
  defp line(text, start),
    do: 1 + Enum.find_index(String.split(text, "\n"), &String.starts_with?(&1, start))

  # The plant cycled every 10 ms to `last` ms, both motors started at 0 ms.
  defp running(last, config \\ plant()) do
    runtime = Runtime.start(config)
    {runtime, _, _} = Runtime.cycle(runtime, 0, %{"pb_start_1" => 1, "pb_start_2" => 1})
    {runtime, _, _} = Runtime.cycle(runtime, 10, %{"pb_start_1" => 0, "pb_start_2" => 0})

    Enum.reduce(20..last//10, runtime, fn _now, runtime ->
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{})
      runtime
    end)
  end

  # `n` cycles of 10 ms, and when `slow` ran in them.
  defp slow_runs(runtime, n) do
    Enum.reduce(1..n, {runtime, []}, fn _, {runtime, ats} ->
      {runtime, _, events} = Runtime.cycle(runtime, 10, %{})
      {runtime, ats ++ for({:ran, "slow", "m2", at} <- events, do: at)}
    end)
  end

  defp accepted(runtime, candidate) do
    assert {:ok, edit, forecast} = Edit.accept(runtime, candidate)
    {edit, forecast}
  end

  # A value the type checker cannot see through, so that a host's mistake is passed as the
  # host would pass it, as runtime_test.exs passes its own.
  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  defp message(fun) do
    fun.()
    flunk("no ArgumentError")
  rescue
    error in ArgumentError -> error.message
  end

  describe "accept's host mistakes, in the order it checks them" do
    test "a runtime that is no resource, with the runtime's own message" do
      assert_raise ArgumentError,
                   "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: :nope",
                   fn -> Edit.accept(opaque(:nope), plant()) end

      # The runtime is checked before the candidate.
      assert_raise ArgumentError, ~r/^expected a %Logex.Runtime{}/, fn ->
        Edit.accept(opaque(:nope), opaque(:nope))
      end
    end

    test "a step's time that is no non-negative integer of milliseconds, in " <>
           "Logex.Runtime.cycle/3's words (decision 139)" do
      for bad <- [-1, 1.5, :soon] do
        assert_raise ArgumentError,
                     "elapsed_ms must be a non-negative integer of milliseconds, got: " <>
                       inspect(bad),
                     fn -> Edit.accept(running(10), plant(), opaque(bad)) end
      end

      # After the runtime, and before the candidate.
      assert_raise ArgumentError, ~r/^expected a %Logex.Runtime{}/, fn ->
        Edit.accept(opaque(:nope), plant(), opaque(-1))
      end

      assert_raise ArgumentError, ~r/^elapsed_ms must be/, fn ->
        Edit.accept(running(10), opaque(:nope), opaque(-1))
      end
    end

    test "a candidate that is no configuration, with start/1's own message" do
      assert_raise ArgumentError,
                   "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, " <>
                     "got: :nope",
                   fn -> Edit.accept(running(10), opaque(:nope)) end
    end

    test "a candidate check/1 refuses, raised as start/1 raises it (decision 63)" do
      runtime = running(10)
      config = plant()

      # A diagnostic a text could make: every one, a line each, as Diagnostic.format/1
      # gives it.
      bad = %{
        config
        | instances: [%{hd(config.instances) | task: "medium"} | tl(config.instances)]
      }

      assert [%Diagnostic{} | _] = diagnostics = Configuration.check(bad)
      expected = Enum.map_join(diagnostics, "\n", &Diagnostic.format/1)
      assert message(fn -> Edit.accept(runtime, opaque(bad)) end) == expected
      assert message(fn -> Runtime.start(opaque(bad)) end) == expected

      # A host mistake no text can make, check/1's own raise.
      nameless = %{config | name: 7}
      expected = message(fn -> Runtime.start(opaque(nameless)) end)
      assert expected =~ "name"
      assert message(fn -> Edit.accept(runtime, opaque(nameless)) end) == expected

      # The candidate is checked before its name.
      assert message(fn -> Edit.accept(runtime, opaque(%{bad | name: "pump_house"})) end) =~
               "medium"
    end

    test "a candidate with another name" do
      assert {:ok, other} = Configuration.compile("pump_house", plant_text(), programs())

      assert_raise ArgumentError,
                   "the candidate is `pump_house`, but the running configuration is " <>
                     "`plant`: an edit keeps the configuration's name",
                   fn -> Edit.accept(running(10), other) end
    end
  end

  describe "a step's host mistakes, in the order it checks them" do
    test "something other than an edit, a lone instance's among them" do
      runtime = running(10)

      assert_raise ArgumentError,
                   "expected a %Logex.Configuration.Edit{} from " <>
                     "Logex.Configuration.Edit.accept/2, got: :nope",
                   fn -> Edit.cancel(opaque(:nope), runtime) end

      {:ok, program} = Logex.compile(@snapshot_ld, name: "snapshot")
      {:ok, lone, _} = Logex.Edit.accept(program, program, Runtime.instance(program))

      assert_raise ArgumentError, ~r/^expected a %Logex.Configuration.Edit{} .*got: /, fn ->
        Edit.cancel(opaque(lone), runtime)
      end

      for call <- [&Edit.running/1, &Edit.stage/1] do
        assert_raise ArgumentError, ~r/^expected a %Logex.Configuration.Edit{}/, fn ->
          call.(opaque(lone))
        end
      end

      # And Logex.Edit refuses a configuration's edit with its own message.
      {edit, _} = accepted(runtime, plant())

      assert_raise ArgumentError, ~r/^expected a %Logex.Edit{} from Logex.Edit.accept\/3/, fn ->
        Logex.Edit.cancel(opaque(edit), Runtime.instance(program))
      end

      # The edit is checked before the runtime.
      assert_raise ArgumentError, ~r/^expected a %Logex.Configuration.Edit{}/, fn ->
        Edit.cancel(opaque(:nope), opaque(:nope))
      end
    end

    test "a runtime that is no resource, with the runtime's own message" do
      {edit, _} = accepted(running(10), plant())

      assert_raise ArgumentError,
                   "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: :nope",
                   fn -> Edit.cancel(edit, opaque(:nope)) end
    end

    test "a step's time that is no non-negative integer of milliseconds, test's and " <>
           "untest's, after the runtime and before the generation (decision 139)" do
      runtime = running(10)
      {edit, _} = accepted(runtime, plant())

      assert_raise ArgumentError,
                   "elapsed_ms must be a non-negative integer of milliseconds, got: -1",
                   fn -> Edit.test(edit, runtime, opaque(-1)) end

      {tested, testing, _} = Edit.test(edit, runtime)

      assert_raise ArgumentError,
                   "elapsed_ms must be a non-negative integer of milliseconds, got: :soon",
                   fn -> Edit.untest(tested, testing, opaque(:soon)) end

      assert_raise ArgumentError, ~r/^expected a %Logex.Runtime{}/, fn ->
        Edit.test(edit, opaque(:nope), opaque(-1))
      end

      assert_raise ArgumentError, ~r/^elapsed_ms must be/, fn ->
        Edit.untest(tested, runtime, opaque(-1))
      end

      # Test and untest each check the step's time before the generation: on an edit
      # that has ended, the time is told first.
      {_assembled, ended, _} = Edit.assemble(tested, testing)

      assert_raise ArgumentError, ~r/^this edit expects the resource at generation 0/, fn ->
        Edit.test(edit, ended)
      end

      assert_raise ArgumentError,
                   "elapsed_ms must be a non-negative integer of milliseconds, got: -1",
                   fn -> Edit.test(edit, ended, opaque(-1)) end

      assert_raise ArgumentError, ~r/^this edit expects the resource at generation 1/, fn ->
        Edit.untest(tested, ended)
      end

      assert_raise ArgumentError,
                   "elapsed_ms must be a non-negative integer of milliseconds, got: -1",
                   fn -> Edit.untest(tested, ended, opaque(-1)) end
    end

    test "an edit that has ended: the generation has moved (decisions 60 and 64)" do
      runtime = running(10)
      {edit, _} = accepted(runtime, plant())
      {_original, later, []} = Edit.cancel(edit, runtime)

      assert_raise ArgumentError,
                   "this edit expects the resource at generation 0, but it is at generation " <>
                     "1: the edit has ended, or another edit has stepped since",
                   fn -> Edit.cancel(edit, later) end

      # Of two edits accepted at once, the second is refused once the first has stepped.
      {first, _} = accepted(later, plant())
      {second, _} = accepted(later, plant())
      {_original, after_first, []} = Edit.cancel(first, later)

      assert_raise ArgumentError, ~r/generation 1, but it is at generation 2/, fn ->
        Edit.cancel(second, after_first)
      end
    end

    test "a resource that runs another configuration than the edit's" do
      {edit, _} = accepted(running(10), plant())
      other = plant(String.replace(plant_text(), "interval 50", "interval 40"))

      assert_raise ArgumentError,
                   "this edit is of another configuration than the one the resource runs: " <>
                     "accept the candidate against this resource",
                   fn -> Edit.cancel(edit, Runtime.start(other)) end

      # The generation is checked first: one moved on, whatever it runs, is that.
      {stepped, _} = accepted(Runtime.start(other), other)
      {_original, moved, []} = Edit.cancel(stepped, Runtime.start(other))

      assert_raise ArgumentError, ~r/^this edit expects the resource at generation 0/, fn ->
        Edit.cancel(edit, moved)
      end
    end
  end

  describe "accept refuses what may change only with a restart" do
    test "each of the configuration's own, from source: in line order, in the candidate's " <>
           "file" do
      original =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool\n",
          "var_global k2_at_trip bool\nvar_global spare bool\n"
        )

      text =
        original
        |> String.replace(
          "task trip single estop priority 0",
          "task trip single estop interval 20 priority 0\ntask extra interval 5 priority 3"
        )
        |> String.replace(
          "var_global sp_2       dint at drive.q.1",
          "var_global sp_2       dint at drive.q.2"
        )
        |> String.replace("var_global lamp_2     bool at panel.q.3\n", "")
        |> String.replace("  m2.run_lamp lamp_2\n", "")
        |> String.replace("var_global k1_at_trip bool", "var_global k1_at_trip bool at panel.q.9")
        |> String.replace("var_global spare bool", "var_global spare dint")
        |> String.replace("program m2 motor with slow", "program m2 motor with fast")

      candidate = %{plant(text) | file: "candidate.logex"}
      assert {:error, diagnostics} = Edit.accept(running(10, plant(original)), candidate)

      assert Enum.map(diagnostics, &{&1.stage, &1.file, &1.line, &1.message}) == [
               {:edit, "candidate.logex", line(text, "task trip"),
                "task `trip` has a single, and its interval is added: an event task's " <>
                  "interval is added or removed only with a restart"},
               {:edit, "candidate.logex", line(text, "task extra"),
                "task `extra` is added: a task is added only with a restart"},
               {:edit, "candidate.logex", line(text, "var_global sp_2"),
                "`sp_2` is at `drive.q.1` in the running configuration and at `drive.q.2` " <>
                  "in the candidate: located I/O changes only with a restart"},
               {:edit, "candidate.logex", line(text, "var_global k1_at_trip"),
                "`k1_at_trip` has no location in the running configuration and is at " <>
                  "`panel.q.9` in the candidate: located I/O changes only with a restart"},
               {:edit, "candidate.logex", line(text, "var_global spare"),
                "`spare` is a bool global in the running configuration and a dint in the " <>
                  "candidate: a global's type changes only with a restart"},
               {:edit, "candidate.logex", line(text, "program m2"),
                "`m2` runs with `slow` in the running configuration and with `fast` in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {:edit, "candidate.logex", nil,
                "`lamp_2` at `panel.q.3` (line 17 of the running configuration) is removed: " <>
                  "located I/O changes only with a restart"}
             ]
    end

    test "in line order however the candidate's text orders its elements, globals before " <>
           "tasks among them" do
      tasks =
        "task fast interval 10 priority 1\ntask slow interval 50 priority 2\n" <>
          "task trip single estop priority 0\n"

      text =
        plant_text()
        |> String.replace(tasks <> "\n", "")
        |> String.replace(
          "var_global sp_2       dint at drive.q.1",
          "var_global sp_2       dint at drive.q.2"
        )
        |> String.replace(
          "\nprogram m1 motor",
          "\n" <> tasks <> "task extra interval 5 priority 3\n\nprogram m1 motor",
          global: false
        )

      assert line(text, "var_global sp_2") < line(text, "task extra")
      assert {:error, diagnostics} = Edit.accept(running(10), plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "var_global sp_2"),
                "`sp_2` is at `drive.q.1` in the running configuration and at `drive.q.2` " <>
                  "in the candidate: located I/O changes only with a restart"},
               {line(text, "task extra"),
                "task `extra` is added: a task is added only with a restart"}
             ]
    end

    test "a task's single changed, a task removed, and an instance moved to no task, from " <>
           "source" do
      text =
        plant_text()
        |> String.replace(
          "task trip single estop priority 0",
          "task trip single pb_reset priority 0"
        )
        |> String.replace("task slow interval 50 priority 2\n", "")
        |> String.replace("program m2 motor with slow", "program m2 motor")

      assert {:error, diagnostics} = Edit.accept(running(10), plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "task trip"),
                "task `trip`'s single changes from `estop` to `pb_reset`: a task's single " <>
                  "changes only with a restart"},
               {line(text, "program m2"),
                "`m2` runs with `slow` in the running configuration and with no task in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {nil,
                "task `slow` (line 3 of the running configuration) is removed: a task is " <>
                  "removed only with a restart"}
             ]
    end

    test "the elements only the running configuration has: its tasks, then its located " <>
           "globals, each in its order there, whatever their lines" do
      # The running configuration declares `lamp_2` on its first line, before any task.
      original =
        "var_global lamp_2     bool at panel.q.3\n" <>
          String.replace(plant_text(), "var_global lamp_2     bool at panel.q.3\n", "")

      text =
        plant_text()
        |> String.replace("var_global lamp_2     bool at panel.q.3\n", "")
        |> String.replace("  m2.run_lamp lamp_2\n", "")
        |> String.replace("task slow interval 50 priority 2\n", "")
        |> String.replace("program m2 motor with slow", "program m2 motor with fast")
        |> String.replace("var_global sp_2       dint at drive.q.1\n", "")
        |> String.replace("  m2.speed_sp sp_2\n", "")

      runtime = running(10, plant(original))
      assert {:error, diagnostics} = Edit.accept(runtime, plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "program m2"),
                "`m2` runs with `slow` in the running configuration and with `fast` in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {nil,
                "task `slow` (line #{line(original, "task slow")} of the running " <>
                  "configuration) is removed: a task is removed only with a restart"},
               {nil,
                "`lamp_2` at `panel.q.3` (line 1 of the running configuration) is removed: " <>
                  "located I/O changes only with a restart"},
               {nil,
                "`sp_2` at `drive.q.1` (line #{line(original, "var_global sp_2")} of the " <>
                  "running configuration) is removed: located I/O changes only with a restart"}
             ]
    end

    test "each, from Elixir data: no line, in the candidate's order, a removed element last" do
      {:ok, relay} =
        Logex.compile("var_input in bool\nvar_output out bool\nxic in ote out", name: "relay")

      global = &%Configuration.Global{name: &1, type: &2, at: &3}
      task = &%Configuration.Task{name: &1, interval: &2, single: &3, priority: 1}

      config = fn tasks, globals, instances ->
        Configuration.new!(
          name: "plant",
          programs: [relay],
          tasks: tasks,
          globals: globals,
          instances: instances,
          connections: [
            %Configuration.Connection{instance: "r", member: "in", to: "x"},
            %Configuration.Connection{instance: "r", member: "out", to: "y"}
          ]
        )
      end

      original =
        config.(
          [
            task.("t", 10, nil),
            task.("e", nil, "x"),
            task.("both", 10, "x"),
            task.("gone", 10, nil)
          ],
          [
            global.("x", :bool, "p.i.0"),
            global.("y", :bool, "p.q.0"),
            global.("g", :bool, "p.q.1"),
            global.("h", :bool, nil),
            global.("l", :bool, "p.q.2")
          ],
          [%Configuration.Instance{name: "r", type: "relay", task: "t"}]
        )

      candidate =
        config.(
          [
            task.("t", 10, nil),
            task.("e", 15, nil),
            task.("both", nil, "x"),
            task.("new", 5, nil)
          ],
          [
            global.("x", :bool, "p.i.0"),
            global.("y", :bool, "p.q.0"),
            global.("g", :bool, nil),
            global.("h", :dint, nil),
            global.("z", :bool, "p.q.3")
          ],
          [%Configuration.Instance{name: "r", type: "relay", task: nil}]
        )

      assert {:error, diagnostics} = Edit.accept(Runtime.start(original), candidate)

      assert Enum.map(diagnostics, &{&1.line, &1.file, &1.message}) == [
               {nil, nil,
                "task `e`'s single changes from `x` to none: a task's single changes only " <>
                  "with a restart"},
               {nil, nil,
                "task `both` has a single, and its interval is removed: an event task's " <>
                  "interval is added or removed only with a restart"},
               {nil, nil, "task `new` is added: a task is added only with a restart"},
               {nil, nil,
                "`g` is at `p.q.1` in the running configuration and has no location in the " <>
                  "candidate: located I/O changes only with a restart"},
               {nil, nil,
                "`h` is a bool global in the running configuration and a dint in the " <>
                  "candidate: a global's type changes only with a restart"},
               {nil, nil, "`z` at `p.q.3` is added: located I/O changes only with a restart"},
               {nil, nil,
                "`r` runs with `t` in the running configuration and with no task in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {nil, nil, "task `gone` is removed: a task is removed only with a restart"},
               {nil, nil, "`l` at `p.q.2` is removed: located I/O changes only with a restart"}
             ]
    end

    @tag :tmp_dir
    test "a program type's own refusal, once a type, in its own file and at its line, after " <>
           "the configuration's (fix F15)",
         %{tmp_dir: dir} do
      files = %{"seal.ld" => seal_ld(), "motor.ld" => motor_ld(), "snapshot.ld" => @snapshot_ld}

      for {name, text} <- Map.put(files, "plant.logex", plant_text()),
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, original} = Configuration.compile_file(Path.join(dir, "plant.logex"))

      motor =
        motor_ld()
        |> String.replace("var_output running_ms dint", "var_output running_ms bool")
        |> String.replace("xic motor move t1.acc running_ms", "xic motor ote running_ms")

      text =
        String.replace(
          plant_text(),
          "task trip single estop priority 0",
          "task trip single estop priority 0\ntask extra interval 5 priority 3"
        )

      next = Path.join(dir, "next")
      File.mkdir_p!(next)

      for {name, t} <- %{files | "motor.ld" => motor} |> Map.put("plant.logex", text),
          do: File.write!(Path.join(next, name), t)

      assert {:ok, candidate} = Configuration.compile_file(Path.join(next, "plant.logex"))

      assert {:error, diagnostics} = Edit.accept(Runtime.start(original), candidate)

      assert Enum.map(
               diagnostics,
               &{Path.basename(&1.file), Path.basename(Path.dirname(&1.file)), &1.line,
                &1.message}
             ) == [
               {"plant.logex", "next", 5,
                "task `extra` is added: a task is added only with a restart"},
               {"motor.ld", "next", line(motor, "var_output running_ms"),
                "`running_ms` is a dint in the running program and a bool in the candidate: " <>
                  "a tag's type changes only with a restart"}
             ]
    end

    test "a retyped instance is a remove plus an add, and may run on another task " <>
           "(decisions 43 and 61); a candidate's warnings stop nothing" do
      text =
        plant_text()
        |> String.replace("program snap snapshot with trip", "program snap motor with fast")
        |> String.replace(~r/  snap\..*\n/, "")
        |> Kernel.<>("  snap.start 0\n  snap.stop 0\n  snap.overtemp 0\n  snap.reset 0\n")

      candidate = plant(text)
      assert candidate.warnings != []
      {_edit, forecast} = accepted(running(10), candidate)
      assert {:instance_stopped, "snap", "snapshot"} in forecast
      assert {:instance_added, "snap", "motor"} in forecast

      # A program type no instance runs as that type in both is neither planned nor
      # checked: here the candidate's snapshot, which no instance runs, retypes a tag.
      snapshot =
        @snapshot_ld
        |> String.replace("var_output a_was bool", "var_output a_was dint\nvar_output a2 bool")
        |> String.replace("xic a ote a_was", "xic a ote a2")

      {:ok, retyped} = Logex.compile(snapshot, name: "snapshot")

      {_edit, ^forecast} =
        accepted(running(10), plant(text, %{programs() | "snapshot" => retyped}))
    end
  end

  describe "the forecast, the report a test taken now gives" do
    test "a kept instance moves by its type's one plan, its reports by path" do
      motor = String.replace(motor_ld(), "ton t1 5000", "ton t1 6000")
      {_edit, forecast} = accepted(running(100), plant(plant_text(), programs(motor)))
      assert {:preset, "m1.t1", {5000, 6000}} in forecast
      assert {:preset, "m2.t1", {5000, 6000}} in forecast
      assert forecast == Enum.sort(forecast)
      assert Enum.filter(forecast, &match?({:preset, _, _}, &1)) |> length() == 2
    end

    test "a function block type changed for the whole configuration moves each instance by " <>
           "its path (decision 31)" do
      seal = String.replace(seal_ld(), "var_output run bool", "var_output run bool\nvar n dint 7")
      {_edit, forecast} = accepted(running(60), plant(plant_text(), programs(motor_ld(), seal)))
      assert {:added, "m1.s1.n", 7} in forecast
      assert {:added, "m2.s1.n", 7} in forecast
    end

    test "a var_external is merged in by the program stopped's, and no start rule starts the " <>
           "started program's (decision 45)" do
      runtime = running(20)

      # `estop` made each motor's own `var`: merged in at the global's value, so nothing
      # starts it.
      own = String.replace(motor_ld(), "var_external estop bool", "var estop bool 1")
      {_edit, forecast} = accepted(runtime, plant(plant_text(), programs(own)))
      refute Enum.any?(forecast, &match?({kind, "m" <> _, _} when kind != :left, &1))

      # A var_external added, bound to a global the edit adds: the global starts, and no
      # tag of the instance does.
      motor =
        String.replace(
          motor_ld(),
          "var_external estop bool",
          "var_external estop bool\nvar_external alarm bool"
        )

      text =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool 1"
        )

      {_edit, forecast} = accepted(runtime, plant(text, programs(motor)))
      assert {:added, "alarm", 1} in forecast
      refute Enum.any?(forecast, &match?({kind, "m1.alarm", _} when kind != :joined, &1))
      refute Enum.any?(forecast, &match?({kind, "m2.alarm", _} when kind != :joined, &1))

      # A `var` with an initial value made a var_external: no changed initial value, since
      # its value is the global's.
      original = plant(plant_text(), programs(own))
      {_edit, forecast} = accepted(Runtime.start(original), plant())
      refute Enum.any?(forecast, &match?({:initial_changed, _, _}, &1))
    end

    test "an instance added is started, and one removed is stopped (decision 43)" do
      text =
        plant_text()
        |> String.replace(~r/program snap snapshot with trip\n(  snap\..*\n)+/, "")
        |> Kernel.<>(
          "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n"
        )

      {_edit, forecast} = accepted(running(10), plant(text))
      assert {:instance_added, "m3", "motor"} in forecast
      assert {:instance_stopped, "snap", "snapshot"} in forecast
    end

    test "a global added starts at its initial value, a kept one whose initial value changed " <>
           "is reported, and one removed is kept, unreported (decision 44)" do
      text =
        plant_text()
        |> String.replace(
          "var_global k2_at_trip bool",
          "var_global alarm bool 1\nvar_global level dint 42"
        )
        |> String.replace("  snap.b_was k2_at_trip\n", "")
        |> String.replace("var_global k1_at_trip bool", "var_global k1_at_trip bool 1")

      {_edit, forecast} = accepted(running(10), plant(text))
      assert {:added, "alarm", 1} in forecast
      assert {:added, "level", 42} in forecast
      assert {:initial_changed, "k1_at_trip", {0, 1}} in forecast
      refute Enum.any?(forecast, &match?({_, "k2_at_trip", _}, &1))
    end

    test "a changed interval makes the task next due at min(next_due, now + new interval) " <>
           "(decision 40)" do
      # `slow` ran at 0, next due at 50; now is 10.
      runtime = running(10)
      shorter = plant(String.replace(plant_text(), "interval 50", "interval 20"))
      {_edit, forecast} = accepted(runtime, shorter)
      assert {:interval, "slow", {50, 20}} in forecast
      assert {:next_due, "slow", {50, 30}} in forecast

      longer = plant(String.replace(plant_text(), "interval 50", "interval 200"))
      {_edit, forecast} = accepted(runtime, longer)
      assert {:interval, "slow", {50, 200}} in forecast
      refute Enum.any?(forecast, &match?({:next_due, _, _}, &1))

      # An event task with an interval changes it by the same rule, its trigger kept.
      both =
        String.replace(
          plant_text(),
          "task trip single estop priority 0",
          "task trip single estop interval 30 priority 0"
        )

      runtime = running(10, plant(both))

      {_edit, forecast} =
        accepted(runtime, plant(String.replace(both, "interval 30", "interval 5")))

      assert {:interval, "trip", {30, 5}} in forecast
      assert {:next_due, "trip", {30, 15}} in forecast
    end
  end

  describe "cancel from accept (decision 64)" do
    test "ends the edit with nothing changed but the generation, and reports nothing" do
      runtime = running(10)
      original = plant()

      {edit, _forecast} =
        accepted(runtime, plant(String.replace(plant_text(), "interval 50", "interval 20")))

      assert Edit.stage(edit) == :accepted
      assert Edit.running(edit) == original
      {kept, later, report} = Edit.cancel(edit, runtime)
      assert {kept, report} == {original, []}
      assert later.generation == runtime.generation + 1
      assert %{later | generation: runtime.generation} == runtime

      assert Runtime.cycle(later, 10, %{}) |> elem(1) ==
               Runtime.cycle(runtime, 10, %{}) |> elem(1)
    end
  end

  # The resource looked into on purpose, as scheduler_test.exs's decision-49 test looks:
  # which instances' states hold `name`.
  defp holding(%Runtime{instances: instances}, name),
    do: for({instance, state} <- instances, Map.has_key?(state.env, name), do: instance)

  # A timer's `last`, internal to it, which no access path reads.
  defp last_of(%Runtime{instances: instances}, name), do: instances[name].env["t1"]["last"]

  defp cycles(runtime, n, inputs \\ %{}) do
    Enum.reduce(1..n, {runtime, nil}, fn _, {runtime, _} ->
      {runtime, outputs, _} = Runtime.cycle(runtime, 10, inputs)
      {runtime, outputs}
    end)
  end

  defp without_m2(text \\ plant_text()),
    do: String.replace(text, ~r/program m2 motor with slow\n(  m2\..*\n)+/, "")

  describe "the steps, at the wrong stage" do
    test "each is refused in OE-1's words" do
      runtime = running(10)

      {edit, _} =
        accepted(runtime, plant(String.replace(plant_text(), "interval 50", "interval 20")))

      assert_raise ArgumentError,
                   "untest takes an edit under test, but this one is accepted",
                   fn ->
                     Edit.untest(edit, runtime)
                   end

      assert_raise ArgumentError,
                   "assemble takes an edit under test, but this one is accepted",
                   fn ->
                     Edit.assemble(edit, runtime)
                   end

      {testing, runtime, _} = Edit.test(edit, runtime)

      assert_raise ArgumentError,
                   "test takes an edit accepted or untested, but this one is under test",
                   fn -> Edit.test(testing, runtime) end

      assert_raise ArgumentError,
                   "cancel takes an edit accepted or untested, but this one is under test",
                   fn -> Edit.cancel(testing, runtime) end

      {untested, runtime, _} = Edit.untest(testing, runtime)
      assert Edit.stage(untested) == :untested

      assert_raise ArgumentError,
                   "untest takes an edit under test, but this one is untested",
                   fn ->
                     Edit.untest(untested, runtime)
                   end

      assert_raise ArgumentError,
                   "assemble takes an edit under test, but this one is untested",
                   fn ->
                     Edit.assemble(untested, runtime)
                   end

      # The generation is checked before the stage: an edit stepped past is told so.
      assert_raise ArgumentError, ~r/^this edit expects the resource at generation 1/, fn ->
        Edit.test(testing, runtime)
      end
    end
  end

  describe "test and untest switch the resource between two cycles" do
    test "test runs the candidate from the next cycle, its report the forecast; untest runs " <>
           "the original again; each moves the generation on" do
      runtime = running(100)
      motor = String.replace(motor_ld(), "ton t1 5000", "ton t1 6000")
      candidate = plant(plant_text(), programs(motor))
      {edit, forecast} = accepted(runtime, candidate)
      {edit, tested, report} = Edit.test(edit, runtime)
      assert report == forecast
      assert {Edit.stage(edit), Edit.running(edit)} == {:testing, candidate}
      assert tested.generation == runtime.generation + 1
      assert Runtime.get!(tested, "m1.t1.pre") == 6000
      {tested, _} = cycles(tested, 3)
      assert Runtime.get!(tested, "m1.t1.pre") == 6000

      {edit, untested, report} = Edit.untest(edit, tested)
      assert {:preset, "m1.t1", {6000, 5000}} in report
      assert {Edit.stage(edit), Edit.running(edit)} == {:untested, plant()}
      assert untested.generation == tested.generation + 1
      {untested, _} = cycles(untested, 2)
      assert Runtime.get!(untested, "m2.t1.pre") == 5000
    end

    test "no instance's state holds a var_external after any step (decisions 45 and 49)" do
      runtime = running(40)

      text =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool 1"
        )

      motor =
        String.replace(
          motor_ld(),
          "var_external estop bool",
          "var_external estop bool\nvar_external alarm bool"
        )

      text =
        text <> "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n"

      {edit, _} = accepted(runtime, plant(text, programs(motor)))
      {edit, runtime, _} = Edit.test(edit, runtime)
      assert {holding(runtime, "estop"), holding(runtime, "alarm")} == {[], []}
      {runtime, _} = cycles(runtime, 5)
      assert {holding(runtime, "estop"), holding(runtime, "alarm")} == {[], []}
      {edit, runtime, _} = Edit.untest(edit, runtime)
      assert {holding(runtime, "estop"), holding(runtime, "alarm")} == {[], []}
      {edit, runtime, _} = Edit.test(edit, runtime)
      {_config, runtime, _} = Edit.assemble(edit, runtime)
      assert {holding(runtime, "estop"), holding(runtime, "alarm")} == {[], []}
      assert Runtime.get!(runtime, "m3.alarm") == 1
    end

    test "a var_external the program started does not declare leaves no copy in the state" do
      runtime = running(20)

      motor =
        String.replace(motor_ld(), "var_external estop bool\n", "")
        |> String.replace("xic estop otl fault\n", "")

      {edit, _} = accepted(runtime, plant(plant_text(), programs(motor)))
      {_edit, runtime, _} = Edit.test(edit, runtime)
      assert holding(runtime, "estop") == []
    end

    test "a connection changed is read at its instance's next scan" do
      runtime = running(50)

      {edit, _} =
        accepted(
          runtime,
          plant(String.replace(plant_text(), "  m2.reset    0", "  m2.reset    pb_reset"))
        )

      {_edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _, _} = Runtime.cycle(runtime, 50, %{"pb_reset" => 1})
      assert Runtime.get!(runtime, "m2.reset") == 1
    end

    test "no switch fires an event: a trigger's last sample is kept" do
      runtime = running(10)
      {runtime, _, events} = Runtime.cycle(runtime, 10, %{"estop" => 1})
      assert {:ran, "trip", "snap", 20} in events

      {edit, _} =
        accepted(runtime, plant(String.replace(plant_text(), "interval 50", "interval 20")))

      {_edit, runtime, _} = Edit.test(edit, runtime)
      {_runtime, _, events} = Runtime.cycle(runtime, 10, %{})
      refute Enum.any?(events, &match?({:ran, "trip", _, _}, &1))
    end

    test "decision 40's next due time is the resource's from the switch" do
      runtime = running(10)

      {edit, _} =
        accepted(runtime, plant(String.replace(plant_text(), "interval 50", "interval 20")))

      {edit, runtime, _} = Edit.test(edit, runtime)
      assert Runtime.next_due_in(runtime) == 10
      {runtime, _, events} = Runtime.cycle(runtime, 20, %{})
      assert {:ran, "slow", "m2", 30} in events

      # And back at untest, with the old interval: min(50, 30 + 50) keeps 50.
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:interval, "slow", {20, 50}} in report
      assert {:next_due, "slow", {50, 50}} not in report
      {_runtime, _, events} = Runtime.cycle(runtime, 20, %{})
      assert {:ran, "slow", "m2", 50} in events
    end

    test "decision 40's now is the step's time, the resource's and elapsed_ms since, the " <>
           "resource's own by default (decision 139)" do
      # `slow` ran at 0, next due at 50; the resource is at 10.
      runtime = running(10)
      shorter = plant(String.replace(plant_text(), "interval 50", "interval 20"))

      # 15 ms after the last cycle: min(50, 25 + 20) = 45; 0 by default: 30.
      assert {:ok, _, forecast} = Edit.accept(runtime, shorter, 15)
      assert {:next_due, "slow", {50, 45}} in forecast
      assert {:ok, _, forecast} = Edit.accept(runtime, shorter)
      assert {:next_due, "slow", {50, 30}} in forecast

      # Cut 35 ms after the last cycle, at 45: min(50, 45 + 20) keeps 50, so the next
      # cycle at 50 runs it on time, no period missed; the step moves no clock.
      {edit, _} = accepted(runtime, shorter)
      {edit, runtime, report} = Edit.test(edit, runtime, 35)
      assert {:interval, "slow", {50, 20}} in report
      refute Enum.any?(report, &match?({:next_due, _, _}, &1))
      assert runtime.now == 10
      {runtime, events} = slow_runs(runtime, 4)
      assert events == [50]
      assert Runtime.overlaps(runtime)["slow"] == 0

      # Untested 5 ms after that cycle, at 55, back to 50 ms: min(70, 55 + 50) keeps 70.
      {_edit, runtime, report} = Edit.untest(edit, runtime, 5)
      assert {:interval, "slow", {20, 50}} in report
      refute Enum.any?(report, &match?({:next_due, _, _}, &1))
      assert {_runtime, [70, 120]} = slow_runs(runtime, 7)

      # Untest's own time: lengthened to 200 ms and run at 50, `slow` is next due at 250;
      # untested 30 ms after that cycle, at 80, back to 50 ms: min(250, 80 + 50) = 130,
      # where the resource's own 50 would give 100.
      longer = plant(String.replace(plant_text(), "interval 50", "interval 200"))
      {edit, _} = accepted(running(10), longer)
      {edit, runtime, _} = Edit.test(edit, running(10))
      {runtime, [50]} = slow_runs(runtime, 4)
      {_edit, runtime, report} = Edit.untest(edit, runtime, 30)
      assert {:next_due, "slow", {250, 130}} in report
      assert {_runtime, [130]} = slow_runs(runtime, 8)
    end

    test "only the first test starts again a tag the candidate adds" do
      runtime = running(10)

      motor =
        String.replace(motor_ld(), "var halt bool", "var halt bool\nvar kept dint 5") <>
          "xic motor move 9 kept\n"

      {edit, forecast} = accepted(runtime, plant(plant_text(), programs(motor)))
      assert {:added, "m1.kept", 5} in forecast
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = cycles(runtime, 1)
      assert Runtime.get!(runtime, "m1.kept") == 9
      {edit, runtime, _} = Edit.untest(edit, runtime)
      {_edit, runtime, report} = Edit.test(edit, runtime)
      refute Enum.any?(report, &match?({:added, "m1.kept", _}, &1))
      assert Runtime.get!(runtime, "m1.kept") == 9
    end
  end

  describe "the resource's clock (decision 56)" do
    test "a switch gives each kept instance the resource's now, and a timer resumes from it" do
      # `m2`, on the 50 ms task, scans at 0 and 50; the candidate takes its timer's rung
      # out, and the untest gives it back at 130 ms, `m2` last scanned at 100.
      runtime = running(70)
      assert runtime.instances["m2"].now == 50
      motor = String.replace(motor_ld(), "xic motor ton t1 5000\n", "")
      {edit, _} = accepted(runtime, plant(plant_text(), programs(motor)))
      {edit, runtime, _} = Edit.test(edit, runtime)
      assert runtime.instances["m2"].now == 70
      {runtime, _} = cycles(runtime, 6)
      assert runtime.instances["m2"].now == 100
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      # From 50 ms, where the original last ran it: 130 - 50, none caught up.
      assert {:resumed, "m2.t1", 80} in report
      assert runtime.instances["m2"].now == 130
      assert Runtime.get!(runtime, "m2.t1.acc") == 50
      {runtime, _} = cycles(runtime, 2)
      assert Runtime.get!(runtime, "m2.t1.acc") == 50 + 20
    end

    test "fix F11's undo reads the instance's own clock, so a cycle that does not scan it " <>
           "cannot hide a resume from the untest" do
      # First an edit that takes the timer's rung out, assembled at 60 ms: `m2.t1` frozen,
      # timing, its `last` the 50 ms of `m2`'s last scan.
      runtime = running(60)

      no_timer =
        plant(plant_text(), programs(String.replace(motor_ld(), "xic motor ton t1 5000\n", "")))

      {edit, _} = accepted(runtime, no_timer)
      {edit, runtime, _} = Edit.test(edit, runtime)
      {_config, runtime, _} = Edit.assemble(edit, runtime)
      assert last_of(runtime, "m2") == 50

      # Then one that gives it back, tested at once, and untested at 90 ms, `m2` not
      # scanned between: the untest gives the test's resume back.
      {edit, _} = accepted(runtime, plant())
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert {:resumed, "m2.t1", 10} in report
      {runtime, _} = cycles(runtime, 3)
      assert runtime.instances["m2"].switched
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resume_undone, "m2.t1", 10} in report
      assert last_of(runtime, "m2") == 50
    end
  end

  describe "a resume asks who has held the instance since the last switch (decision 336)" do
    @conveyor """
    var_input run bool
    var_output oiled bool
    var lube rto

    xic run rto lube 30
    xic lube.dn ote oiled
    """

    @line """
    task oiler single tick priority 1

    var_global tick bool at panel.i.0
    var_global run bool at panel.i.1
    var_global oil_q bool at panel.q.0

    program c1 conveyor with oiler
      c1.run run
      c1.oiled oil_q
    """

    defp line_with(conveyor) do
      {:ok, program} = Logex.compile(conveyor, name: "conveyor")
      assert {:ok, config} = Configuration.compile("line", @line, %{"conveyor" => program})
      config
    end

    # One cycle of `ms` with `tick` as given, and one at once with it 1, so that `c1`'s
    # event task runs once at the clock's new time.
    defp ticked(runtime, ms) do
      {runtime, _, _} = Runtime.cycle(runtime, ms, %{"tick" => 0})
      {runtime, outputs, [{:ran, "oiler", "c1", _}]} = Runtime.cycle(runtime, 0, %{"tick" => 1})
      {runtime, outputs}
    end

    test "a conveyor's lube timer, tested, untested, 30 ms, and tested and untested at " <>
           "once, finishes on time ({7613, 10, 19})" do
      # The lube `rto` times from 0 under the original, run by `oiler`'s event: 10 ms by 10.
      runtime = Runtime.start(line_with(@conveyor))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"run" => 1, "tick" => 1})
      {runtime, _} = ticked(runtime, 10)
      assert %{"acc" => 10, "en" => 1, "last" => 10} = runtime.instances["c1"].env["lube"]

      # A candidate that takes the lube rung out, tested, its scan at once, and untested:
      # nothing is due back, the candidate having held `c1` for no time.
      candidate = line_with(String.replace(@conveyor, "xic run rto lube 30\n", ""))
      {edit, _} = accepted(runtime, candidate)
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = ticked(runtime, 0)
      {edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:resumed, _, _}, &1))

      # The original holds `c1` for 30 ms its event task does not run it; tested and
      # untested at once, the timer is given back exactly, the 30 ms the original's.
      {runtime, _, []} = Runtime.cycle(runtime, 30, %{})
      assert runtime.now == 40
      {edit, runtime, _} = Edit.test(edit, runtime)
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:resumed, _, _}, &1))
      assert %{"acc" => 10, "last" => 10} = runtime.instances["c1"].env["lube"]

      # Its next run, at 45 ms, catches up the 35 ms since 10, and the lube is done.
      {runtime, outputs} = ticked(runtime, 5)
      assert Runtime.get!(runtime, "c1.lube.dn") == 1
      assert outputs["oil_q"] == 1
    end

    test "an untest gives back what the test gave back, the clock having moved since with " <>
           "no scan, so the time the original held is caught up" do
      # `m2`, on the 50 ms task, last scanned at 50 with `t1` timing; the candidate takes
      # `t1`'s rung out and scans `m2` at 100; the untest at 110 resumes `t1` by 60.
      runtime = running(60)
      motor = String.replace(motor_ld(), "xic motor ton t1 5000\n", "")
      {edit, _} = accepted(runtime, plant(plant_text(), programs(motor)))
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = cycles(runtime, 5)
      {edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resumed, "m2.t1", 60} in report
      assert last_of(runtime, "m2") == 110
      acc = Runtime.get!(runtime, "m2.t1.acc")

      # The original then holds `m2` from 110 to 140, unscanned; the test gives the resume
      # back, and the untest at once gives back what the test gave back, so `t1` is as the
      # test found it: the 30 ms the original held it are not taken.
      {runtime, _} = cycles(runtime, 3)
      assert runtime.instances["m2"].switched
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert {:resume_undone, "m2.t1", 60} in report
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resumed, "m2.t1", 60} in report
      assert last_of(runtime, "m2") == 110

      # `m2`'s next scan, at 150, catches up the 40 ms since 110.
      {runtime, _} = cycles(runtime, 1)
      assert Runtime.get!(runtime, "m2.t1.acc") == acc + 40
    end

    # Three readings the record leaves open (provisional), each a question for the
    # maintainer in `PLAN.md` M6-9: what the built rule does where the candidate scans
    # between the two switches, where the instance comes back from aside, and where the
    # candidate holds it unscanned. Each test pins the rule as built, so that an answer
    # that changes it changes a test on purpose.
    @oil "function_block oil\nvar_input go bool\nvar_output d bool\nvar lube rto\n\n" <>
           "xic go rto lube 100000\nxic lube.dn ote d"

    # The lube `rto` at four depths: a tag, an element of an array of timers, a block's
    # timer and a timer in an element of an array of blocks, each with the rung that runs
    # it and its path in a report.
    @depths [
      {"var lube rto\n", "xic run rto lube 100000\n", "lube"},
      {"var lube rto[2]\n", "xic run rto lube[1] 100000\n", "lube[1]"},
      {"var o1 oil\nvar dd bool\n", "cal o1 run dd\n", "o1.lube"},
      {"var o1 oil[2]\nvar dd bool\n", "cal o1[1] run dd\n", "o1[1].lube"}
    ]

    defp depth_line(conveyor) do
      {:ok, oil} = Logex.compile(@oil, name: "oil")
      {:ok, program} = Logex.compile(conveyor, name: "conveyor", types: [oil])

      line = String.replace(@line, ~r/^var_global oil_q.*\n|^  c1\.oiled.*\n/m, "")
      assert {:ok, config} = Configuration.compile("line", line, %{"conveyor" => program})
      config
    end

    # The original's lube timing from 0, run at 10 ms by `oiler`'s event, and a candidate
    # that takes its rung out.
    defp lube_at_ten({declared, rung, _path}) do
      original =
        "var_input run bool\nvar zz bool\n" <> declared <> "\n" <> rung <> "xic run ote zz\n"

      runtime = Runtime.start(depth_line(original))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"run" => 1, "tick" => 1})
      {runtime, _} = ticked(runtime, 10)
      {runtime, depth_line(String.replace(original, rung, ""))}
    end

    test "provisional: after a candidate's scan the resume takes the original's hold, " <>
           "at every depth" do
      for {_declared, _rung, path} = depth <- @depths do
        {runtime, candidate} = lube_at_ten(depth)
        {edit, _} = accepted(runtime, candidate)
        {edit, runtime, _} = Edit.test(edit, runtime)
        {runtime, _} = ticked(runtime, 0)
        {edit, runtime, report} = Edit.untest(edit, runtime)
        refute Enum.any?(report, &match?({:resumed, _, _}, &1)), path

        # The original holds `c1` from 10 to 40 unscanned; the second test at 40, the
        # candidate's one scan at 45 and the untest: the resume counts from the timer's
        # last run at 10, 35 ms, not from the second test, 5 ms.
        {runtime, _, []} = Runtime.cycle(runtime, 30, %{})
        {edit, runtime, _} = Edit.test(edit, runtime)
        {runtime, _} = ticked(runtime, 5)
        {_edit, runtime, report} = Edit.untest(edit, runtime)
        assert {:resumed, "c1." <> path, 35} in report, path
        assert runtime.now == 45
      end

      # The tag's `acc` at its next run, 5 ms on: 15, the 30 ms the original held lost.
      {runtime, candidate} = lube_at_ten(hd(@depths))
      {edit, _} = accepted(runtime, candidate)
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = ticked(runtime, 0)
      {edit, runtime, _} = Edit.untest(edit, runtime)
      {runtime, _, []} = Runtime.cycle(runtime, 30, %{})
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = ticked(runtime, 5)
      {_edit, runtime, _} = Edit.untest(edit, runtime)
      assert %{"acc" => 10, "last" => 45} = runtime.instances["c1"].env["lube"]
      {runtime, _} = ticked(runtime, 5)
      assert Runtime.get!(runtime, "c1.lube.acc") == 15
    end

    test "provisional: one back from aside takes the original's hold before it" do
      other = "var_input run bool\nvar x bool\n\nxic run ote x\n"
      {:ok, program} = Logex.compile(other, name: "other")
      line = String.replace(@line, "conveyor with", "other with")
      line = String.replace(line, ~r/^  c1\.oiled.*\n/m, "")
      {:ok, retyped} = Configuration.compile("line", line, %{"other" => program})

      runtime = Runtime.start(line_with(@conveyor))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"run" => 1, "tick" => 1})
      {runtime, _} = ticked(runtime, 10)
      assert %{"acc" => 10, "last" => 10} = runtime.instances["c1"].env["lube"]

      # `c1` retyped, so each test sets the conveyor's instance aside: tested, the other
      # program's scan at once, untested, back from aside with nothing to resume.
      {edit, _} = accepted(runtime, retyped)
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = ticked(runtime, 0)
      {edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:resumed, _, _}, &1))

      # The original holds `c1` from 10 to 40 unscanned; set aside at 40 and brought back
      # at once, for no time aside, it resumes by the 30 ms the original held.
      {runtime, _, []} = Runtime.cycle(runtime, 30, %{})
      {edit, runtime, _} = Edit.test(edit, runtime)
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resumed, "c1.lube", 30} in report
      {runtime, _} = ticked(runtime, 0)
      assert Runtime.get!(runtime, "c1.lube.acc") == 10
    end

    test "provisional: the candidate's unscanned hold is caught up" do
      runtime = Runtime.start(line_with(String.replace(@conveyor, "lube 30", "lube 100000")))
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"run" => 1, "tick" => 1})
      {runtime, _} = ticked(runtime, 10)
      candidate = String.replace(@conveyor, "xic run rto lube 30\n", "")
      {edit, _} = accepted(runtime, line_with(candidate))

      # Tested at 10, the candidate holds `c1` to 40 and never scans it; untested at 40,
      # the original scanned last, so nothing is resumed and the 30 ms are caught up.
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _, []} = Runtime.cycle(runtime, 30, %{})
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:resumed, _, _}, &1))
      refute Enum.any?(report, &match?({:resume_undone, _, _}, &1))
      assert %{"acc" => 10, "last" => 10} = runtime.instances["c1"].env["lube"]
      {runtime, _} = ticked(runtime, 0)
      assert Runtime.get!(runtime, "c1.lube.acc") == 40
    end
  end

  describe "instances set aside and brought back (decisions 43, 57 and 65)" do
    test "one removed is set aside, unscanned, and brought back by untest with its state" do
      runtime = running(60)
      {edit, _} = accepted(runtime, plant(without_m2()))
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert {:instance_stopped, "m2", "motor"} in report
      aside = runtime.aside["m2"]
      assert aside == running(60).instances["m2"]
      {runtime, _} = cycles(runtime, 5)
      assert runtime.aside["m2"] == aside
      refute Map.has_key?(runtime.instances, "m2")

      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:instance_back, "m2", "motor"} in report
      refute Enum.any?(report, &match?({:instance_added, _, _}, &1))
      assert runtime.aside == %{}
      back = runtime.instances["m2"]
      assert %{back | now: aside.now, env: aside.env} == aside
      assert Runtime.get!(runtime, "m2.motor") == 1
    end

    test "its timers carry on from where they stopped, reported (decision 57)" do
      runtime = running(60)
      acc = Runtime.get!(runtime, "m2.t1.acc")
      {edit, _} = accepted(runtime, plant(without_m2()))
      {edit, runtime, _} = Edit.test(edit, runtime)
      {runtime, _} = cycles(runtime, 12)
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resumed, "m2.t1", 180 - 50} in report
      assert runtime.instances["m2"].now == 180
      assert last_of(runtime, "m2") == 180
      {runtime, _} = cycles(runtime, 2)
      assert Runtime.get!(runtime, "m2.t1.acc") == acc + 20
    end

    test "a timer inside a block an instance holds carries on too, by its path" do
      {:ok, block} =
        Logex.compile(
          "function_block sb\nvar_input i bool\nvar_output q bool\nvar t ton\n\n" <>
            "xic i ton t 1000\nxic t.dn ote q\n",
          name: "sb"
        )

      {:ok, held} =
        Logex.compile("var_input x bool\nvar_output y bool\nvar s1 sb\n\ncal s1 x y\n",
          name: "a",
          types: [block]
        )

      {:ok, other} =
        Logex.compile("var_input x bool\nvar_output y bool\n\nxic x ote y\n", name: "b")

      head =
        "task fast interval 10 priority 1\nvar_global i bool at d.i.0\n" <>
          "var_global q bool at d.q.0\nvar_global r bool at d.q.1\n" <>
          "program k b with fast\n  k.x i\n  k.y r\n"

      {:ok, original} =
        Configuration.compile("plant", head <> "program p a with fast\n  p.x i\n  p.y q\n", %{
          "a" => held,
          "b" => other
        })

      {:ok, candidate} = Configuration.compile("plant", head, %{"b" => other})
      # A block's own `var` is hidden from an access path, so the state is looked into.
      acc = fn %Runtime{instances: instances} -> instances["p"].env["s1"]["t"]["acc"] end
      {runtime, _} = cycles(Runtime.start(original), 30, %{"i" => 1})
      assert acc.(runtime) == 290
      {edit, _} = accepted(runtime, candidate)
      {edit, runtime, _} = Edit.test(edit, runtime)
      # Set aside for 500 ms, which its timer does not catch up (decision 57).
      {runtime, _} = cycles(runtime, 50)
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:resumed, "p.s1.t", 500} in report
      {runtime, outputs} = cycles(runtime, 1)
      assert {acc.(runtime), outputs["q"]} == {300, 0}
    end

    # M3-2: a `tof` in its delay and a `tp` in its pulse are timing while `.tt` is set, with
    # `.en` 0 where the rung is false (decisions 93 and 94), so each comes back resumed by its
    # own timing member, not by `.en` as a `ton` does.
    test "a tof in its delay and a tp in its pulse, their rungs false, carry on too, each " <>
           "by `.tt` (decisions 57, 93 and 94)" do
      for {type, shows, start} <- [{"tof", "dn", [1, 0, 0]}, {"tp", "tt", [0, 1, 0]}] do
        {:ok, timed} =
          Logex.compile(
            "var_input x bool\nvar_output y bool\nvar t #{type}\n\nxic x #{type} t 50\n" <>
              "xic t.#{shows} ote y\n",
            name: "a"
          )

        {:ok, other} =
          Logex.compile("var_input x bool\nvar_output y bool\n\nxic x ote y\n", name: "b")

        head =
          "task fast interval 10 priority 1\nvar_global i bool at d.i.0\n" <>
            "var_global q bool at d.q.0\nvar_global r bool at d.q.1\n" <>
            "program k b with fast\n  k.x i\n  k.y r\n"

        {:ok, original} =
          Configuration.compile("plant", head <> "program p a with fast\n  p.x i\n  p.y q\n", %{
            "a" => timed,
            "b" => other
          })

        {:ok, candidate} = Configuration.compile("plant", head, %{"b" => other})

        runtime =
          Enum.reduce(start, Runtime.start(original), fn i, runtime ->
            elem(cycles(runtime, 1, %{"i" => i}), 0)
          end)

        # 10 ms of its 50 gone, its rung false.
        assert %{"tt" => 1, "en" => 0, "acc" => 10} = runtime.instances["p"].env["t"]
        {edit, _} = accepted(runtime, candidate)
        {edit, runtime, _} = Edit.test(edit, runtime)
        # Set aside for 500 ms, which its timer does not catch up (decision 57).
        {runtime, _} = cycles(runtime, 50, %{"i" => 0})
        {_edit, runtime, report} = Edit.untest(edit, runtime)
        assert {:resumed, "p.t", 500} in report, type
        # The 40 ms left: three cycles more with `.tt` set, and the fourth ends it.
        {runtime, outputs} = cycles(runtime, 3)
        timer = fn rt -> Map.take(rt.instances["p"].env["t"], ~w(acc tt)) end
        assert {timer.(runtime), outputs["q"]} == {%{"acc" => 40, "tt" => 1}, 1}, type
        {runtime, outputs} = cycles(runtime, 1)
        assert {Runtime.get!(runtime, "p.t.tt"), outputs["q"]} == {0, 0}, type
      end
    end

    test "one brought back at the time it was set aside resumes nothing" do
      # `m1`, on `fast`, last scanned at 60 ms, set aside and brought back at 60 ms.
      runtime = running(60)
      text = String.replace(plant_text(), ~r/program m1 motor with fast\n(  m1\..*\n)+/, "")
      {edit, _} = accepted(runtime, plant(text))
      {edit, runtime, _} = Edit.test(edit, runtime)
      assert runtime.aside["m1"].env["t1"]["en"] == 1
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:instance_back, "m1", "motor"} in report
      refute Enum.any?(report, &match?({:resumed, "m1." <> _, _}, &1))
      assert runtime.instances["m1"].env == running(60).instances["m1"].env
    end

    test "a timer that was not timing is left as it was set aside" do
      # `m2` stopped at 50 ms, its timer no longer timing.
      {runtime, _, _} = Runtime.cycle(running(40), 10, %{"pb_stop_2" => 1})
      assert Runtime.get!(runtime, "m2.t1.en") == 0
      {edit, _} = accepted(runtime, plant(without_m2()))
      {edit, runtime, _} = Edit.test(edit, runtime)
      aside = runtime.aside["m2"]
      {runtime, _} = cycles(runtime, 6)
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:resumed, _, _}, &1))
      assert runtime.instances["m2"].env == aside.env
    end

    test "one retyped trades places with its old state at each switch (decision 43)" do
      runtime = running(60)

      text =
        plant_text()
        |> String.replace("program snap snapshot with trip", "program snap motor with fast")
        |> String.replace(~r/  snap\..*\n/, "")
        |> Kernel.<>("  snap.start 0\n  snap.stop 0\n  snap.overtemp 0\n  snap.reset 0\n")

      {edit, _} = accepted(runtime, plant(text))
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert {:instance_stopped, "snap", "snapshot"} in report
      assert {:instance_added, "snap", "motor"} in report
      assert runtime.instances["snap"].type == "motor"
      assert runtime.aside["snap"].type == "snapshot"
      {edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:instance_stopped, "snap", "motor"} in report
      assert {:instance_back, "snap", "snapshot"} in report
      assert {runtime.instances["snap"].type, runtime.aside["snap"].type} == {"snapshot", "motor"}
      {_edit, runtime, report} = Edit.test(edit, runtime)
      assert {:instance_back, "snap", "motor"} in report
      assert runtime.aside["snap"].type == "snapshot"
    end

    test "restart/2 during an edit drops what is set aside and what only the other " <>
           "configuration declares; the next switch starts each again (decision 65)" do
      runtime = running(60)

      text =
        without_m2(
          String.replace(plant_text(), "var_global k2_at_trip bool\n", "")
          |> String.replace("  snap.b_was k2_at_trip\n", "")
        )

      {edit, _} = accepted(runtime, plant(text))
      {edit, runtime, _} = Edit.test(edit, runtime)
      generation = runtime.generation
      runtime = Runtime.restart(runtime, :cold)
      assert {runtime.aside, runtime.generation, Edit.stage(edit)} == {%{}, generation, :testing}
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:instance_added, "m2", "motor"} in report
      assert {:added, "k2_at_trip", 0} in report
      assert Runtime.get!(runtime, "m2.motor") == 0
    end
  end

  describe "assemble and cancel after an untest prune" do
    test "assemble prunes the instances set aside, the globals and the tags only the " <>
           "original has, by path" do
      motor = String.replace(motor_ld(), "var halt bool", "var halt bool\nvar spare dint 4")
      original = plant(plant_text(), programs(motor))
      runtime = running(60, original)

      text =
        without_m2(
          String.replace(plant_text(), "var_global k2_at_trip bool\n", "")
          |> String.replace("  snap.b_was k2_at_trip\n", "")
        )

      candidate = plant(text)
      {edit, _} = accepted(runtime, candidate)
      {edit, runtime, _} = Edit.test(edit, runtime)
      {kept, runtime, report} = Edit.assemble(edit, runtime)
      assert kept == candidate
      assert {:instance_pruned, "m2", "motor"} in report
      assert {:pruned, "k2_at_trip", 0} in report
      assert {:pruned, "m1.spare", 4} in report
      assert runtime.aside == %{}
      refute Map.has_key?(runtime.globals, "k2_at_trip")
      refute Map.has_key?(runtime.instances["m1"].env, "spare")
      assert_raise ArgumentError, ~r/generation/, fn -> Edit.untest(edit, runtime) end
    end

    test "cancel after an untest prunes what only the candidate has" do
      runtime = running(60)

      text =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool 1"
        ) <> "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n"

      {edit, _} = accepted(runtime, plant(text))
      {edit, runtime, _} = Edit.test(edit, runtime)
      {edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:instance_stopped, "m3", "motor"} in report
      {kept, runtime, report} = Edit.cancel(edit, runtime)
      assert kept == plant()
      assert {:instance_pruned, "m3", "motor"} in report
      assert {:pruned, "alarm", 1} in report
      assert {runtime.aside, Map.has_key?(runtime.globals, "alarm")} == {%{}, false}
      assert_raise ArgumentError, ~r/generation/, fn -> Edit.test(edit, runtime) end
    end
  end

  describe "an edit accepted while another is open, superseding it (decision 66)" do
    test "an instance the superseded edit set aside is dropped at the first test, and one " <>
           "the candidate runs again starts as a fresh start of the candidate starts it" do
      runtime = running(60)
      {first, _} = accepted(runtime, plant(without_m2()))
      {_first, runtime, _} = Edit.test(first, runtime)
      {runtime, _} = cycles(runtime, 3)
      assert Map.keys(runtime.aside) == ["m2"]

      # The corrected candidate runs `m2` again, under a motor whose timer is slower.
      motor = String.replace(motor_ld(), "ton t1 5000", "ton t1 7000")
      candidate = plant(plant_text(), programs(motor))
      {second, forecast} = accepted(runtime, candidate)
      {_second, runtime, report} = Edit.test(second, runtime)
      assert report == forecast
      assert {:instance_pruned, "m2", "motor"} in report
      assert {:instance_added, "m2", "motor"} in report
      refute Enum.any?(report, &match?({:instance_back, _, _}, &1))
      assert runtime.aside == %{}
      assert runtime.instances["m2"] == Runtime.start(candidate).instances["m2"]
      assert Runtime.get!(runtime, "m2.t1.pre") == 7000
      assert Runtime.get!(runtime, "m2.motor") == 0
    end

    test "an instance the superseded edit set aside and the candidate does not run is " <>
           "dropped, and reported" do
      runtime = running(60)
      {first, _} = accepted(runtime, plant(without_m2()))
      {first, runtime, _} = Edit.test(first, runtime)
      {_first, runtime, _} = Edit.untest(first, runtime)
      assert runtime.aside == %{}

      # Untested, the first edit has set aside its own `m3`, which the original never ran.
      text =
        plant_text() <>
          "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n"

      {first, _} = accepted(runtime, plant(text))
      {first, runtime, _} = Edit.test(first, runtime)
      {_first, runtime, _} = Edit.untest(first, runtime)
      assert Map.keys(runtime.aside) == ["m3"]

      {second, forecast} =
        accepted(runtime, plant(String.replace(plant_text(), "priority 2", "priority 3")))

      {second, runtime, report} = Edit.test(second, runtime)
      assert report == forecast
      assert {:instance_pruned, "m3", "motor"} in report
      assert runtime.aside == %{}
      {_second, runtime, report} = Edit.untest(second, runtime)
      refute Enum.any?(report, &match?({_, "m3", _}, &1))
      refute Map.has_key?(runtime.instances, "m3")
    end

    test "a global the superseded edit kept unused is dropped at the first test, and one " <>
           "the candidate declares again starts at its initial value, of its new type" do
      original =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool\n",
          "var_global k2_at_trip bool\nvar_global level dint 1200\nvar_global spare dint 7\n"
        )

      runtime = running(10, plant(original))
      {first, _} = accepted(runtime, plant())
      {_first, runtime, report} = Edit.test(first, runtime)
      refute Enum.any?(report, &match?({:pruned, _, _}, &1))

      # Kept unused, which no access path reads.
      assert Map.take(runtime.globals, ~w(level spare)) == %{"level" => 1200, "spare" => 7}

      candidate =
        plant(
          String.replace(
            plant_text(),
            "var_global k2_at_trip bool\n",
            "var_global k2_at_trip bool\nvar_global level bool\n"
          )
        )

      {second, forecast} = accepted(runtime, candidate)
      {_second, runtime, report} = Edit.test(second, runtime)
      assert report == forecast
      assert {:pruned, "level", 1200} in report
      assert {:pruned, "spare", 7} in report
      assert {:added, "level", 0} in report
      assert Runtime.get(runtime, "level") == {:ok, 0}
      refute Map.has_key?(runtime.globals, "spare")
      assert Map.keys(runtime.globals) == Map.keys(Runtime.start(candidate).globals)
    end

    # Decision 315 (the maintainer, 2026-10-30): every prune drops whatever a kept
    # instance's running program does not declare, whatever left it there. Here an edit
    # tested and untested leaves `spare`, which only its candidate's motor declares, in
    # `m1`, and is superseded before any prune; the next edit retypes `m1`, so its type's
    # plan prunes nothing of it. Until decision 315 `spare` stayed until a restart.
    test "a tag a superseded edit left in a kept instance is dropped by the next prune, by " <>
           "its path" do
      runtime = running(60)
      spare = String.replace(motor_ld(), "var halt bool", "var halt bool\nvar spare dint 4")
      # Its seal block's new version holds a member more, `held`.
      seal =
        String.replace(seal_ld(), "var_output run bool", "var_output run bool\nvar held dint 9")

      {first, _} = accepted(runtime, plant(plant_text(), programs(spare, seal)))
      {first, runtime, _} = Edit.test(first, runtime)
      {_first, runtime, _} = Edit.untest(first, runtime)
      assert runtime.instances["m1"].env["spare"] == 4
      assert runtime.instances["m1"].env["s1"]["held"] == 9

      {:ok, other} =
        Logex.compile(motor_ld(), name: "motor_b", types: [programs()["motor"].blocks["seal"]])

      text = String.replace(plant_text(), "program m1 motor", "program m1 motor_b")
      candidate = plant(text, Map.put(programs(), "motor_b", other))
      {second, _} = accepted(runtime, candidate)
      {second, runtime, report} = Edit.test(second, runtime)
      refute Enum.any?(report, &match?({:pruned, "m1.spare", _}, &1))
      {second, runtime, _} = Edit.untest(second, runtime)
      assert runtime.instances["m1"].env["spare"] == 4
      {kept, runtime, report} = Edit.cancel(second, runtime)
      assert kept == plant()
      assert {:pruned, "m1.spare", 4} in report
      assert {:pruned, "m1.s1.held", 9} in report
      assert {:pruned, "m2.spare", 4} in report
      refute Map.has_key?(runtime.instances["m1"].env, "spare")
      refute Map.has_key?(runtime.instances["m1"].env["s1"], "held")
      assert Enum.count(report, &match?({:pruned, "m2.s1.held", 9}, &1)) == 1
      refute Map.has_key?(runtime.instances["m2"].env, "spare")

      assert Map.keys(runtime.instances["m1"].env) ==
               Map.keys(Runtime.start(plant()).instances["m1"].env)

      _ = second
    end

    test "a member a superseded edit left in each element of an array of blocks, and in a " <>
           "block inside a block, is dropped by the next prune, by its path" do
      cell = fn extra ->
        {:ok, cell} =
          Logex.compile(
            "function_block cell\nvar_input go bool\nvar k dint\n#{extra}xic go add k 1 k",
            name: "cell"
          )

        cell
      end

      typed = fn name, block ->
        {:ok, outer} =
          Logex.compile("function_block outer\nvar_input go bool\nvar c cell\ncal c go",
            name: "outer",
            types: [block]
          )

        {:ok, program} =
          Logex.compile(
            "var_input go bool\nvar cs cell[2]\nvar o outer\ncal cs[0] go\ncal cs[1] go\ncal o go",
            name: name,
            types: [outer, block]
          )

        program
      end

      config = fn type, block ->
        programs = %{"p" => typed.("p", block), "q" => typed.("q", cell.(""))}

        plant(
          "task fast interval 10 priority 1\nprogram m1 #{type} with fast\n  m1.go 0\n",
          programs
        )
      end

      runtime = Runtime.start(config.("p", cell.("")))
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{})
      {first, _} = accepted(runtime, config.("p", cell.("var extra dint 3\n")))
      {first, runtime, _} = Edit.test(first, runtime)
      {_first, runtime, _} = Edit.untest(first, runtime)
      assert elem(runtime.instances["m1"].env["cs"], 1)["extra"] == 3
      assert runtime.instances["m1"].env["o"]["c"]["extra"] == 3

      {second, _} = accepted(runtime, config.("q", cell.("")))
      {second, runtime, _} = Edit.test(second, runtime)
      {second, runtime, _} = Edit.untest(second, runtime)
      {_kept, runtime, report} = Edit.cancel(second, runtime)
      assert {:pruned, "m1.cs[0].extra", 3} in report
      assert {:pruned, "m1.cs[1].extra", 3} in report
      assert {:pruned, "m1.o.c.extra", 3} in report
      refute Map.has_key?(runtime.instances["m1"].env["o"]["c"], "extra")
      refute Map.has_key?(elem(runtime.instances["m1"].env["cs"], 0), "extra")
      refute Map.has_key?(elem(runtime.instances["m1"].env["cs"], 1), "extra")
    end

    test "the report's writes rebuild the resource, the prunes written first" do
      runtime = running(60)
      {first, _} = accepted(runtime, plant(without_m2()))
      {_first, before, _} = Edit.test(first, runtime)
      {second, _} = accepted(before, plant())
      {_second, later, report} = Edit.test(second, before)

      {prunes, writes} =
        Enum.split_with(
          report,
          &match?({kind, _, _} when kind in [:pruned, :instance_pruned], &1)
        )

      assert prunes == [{:instance_pruned, "m2", "motor"}]
      assert {:instance_added, "m2", "motor"} in writes
      assert later.aside == Map.drop(before.aside, ["m2"])
      assert later.instances["m2"] == Runtime.start(plant()).instances["m2"]
    end
  end

  describe "a global nothing drives any more holds its value, and every step reports it " <>
             "(decisions 20 and 58)" do
    test "a var_output no longer written: its point and the instance's own output, both" do
      runtime = running(60)
      motor = String.replace(motor_ld(), "xic motor ote run_lamp\n", "")
      {edit, forecast} = accepted(runtime, plant(plant_text(), programs(motor)))
      assert {:held, "lamp_1", 1} in forecast
      assert {:held, "m1.run_lamp", 1} in forecast
      assert {:held, "lamp_2", 1} in forecast
      assert {:held, "m2.run_lamp", 1} in forecast
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert report == forecast
      {runtime, outputs} = cycles(runtime, 3, %{"pb_stop_1" => 1})
      assert {outputs["k1"], outputs["lamp_1"]} == {0, 1}

      # Back, the original drives them: nothing is held. Assemble holds them again.
      {edit, runtime, report} = Edit.untest(edit, runtime)
      refute Enum.any?(report, &match?({:held, _, _}, &1))
      {edit, runtime, _} = Edit.test(edit, runtime)
      {_config, _runtime, report} = Edit.assemble(edit, runtime)
      assert {:held, "lamp_1", 1} in report
      assert {:held, "m1.run_lamp", 1} in report
    end

    test "an instance removed: each point it drove, held across the cycles it is set aside" do
      runtime = running(60)
      {edit, _} = accepted(runtime, plant(without_m2()))
      {_edit, runtime, report} = Edit.test(edit, runtime)

      assert for({:held, name, value} <- report, do: {name, value}) == [
               {"k2", 1},
               {"lamp_2", 1},
               {"sp_2", 1200}
             ]

      {_runtime, outputs} = cycles(runtime, 5)
      assert {outputs["k2"], outputs["lamp_2"], outputs["sp_2"]} == {1, 1, 1200}
    end

    test "a global written through a var_external, which nothing writes any more" do
      alarm =
        String.replace(
          motor_ld(),
          "var_external estop bool",
          "var_external estop bool\nvar_external alarm bool"
        ) <> "xic fault ote alarm\n"

      text =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool"
        )

      runtime = running(60, plant(text, programs(alarm)))
      quiet = String.replace(alarm, "xic fault ote alarm\n", "")
      {_edit, forecast} = accepted(runtime, plant(text, programs(quiet)))
      assert {:held, "alarm", 0} in forecast
    end

    test "a point another driver takes over is not held, nor one the candidate removes" do
      runtime = running(60)

      text =
        plant_text()
        |> String.replace("  m1.run_lamp lamp_1", "  m1.motor    lamp_1")
        |> String.replace("  snap.b_was k2_at_trip\n", "")
        |> String.replace("var_global k2_at_trip bool\n", "")

      {_edit, forecast} = accepted(runtime, plant(text))
      refute Enum.any?(forecast, &match?({:held, _, _}, &1))
    end

    test "cancel after an untest holds what the candidate drove and the original does not" do
      text =
        plant_text() <>
          "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n  m3.run_lamp k2_at_trip\n"

      text = String.replace(text, "  snap.b_was k2_at_trip\n", "")
      original = plant(String.replace(plant_text(), "  snap.b_was k2_at_trip\n", ""))
      runtime = running(60, original)
      {edit, _} = accepted(runtime, plant(text))
      {edit, runtime, report} = Edit.test(edit, runtime)
      refute Enum.any?(report, &match?({:held, _, _}, &1))
      {edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:held, "k2_at_trip", 0} in report
      {_config, _runtime, report} = Edit.cancel(edit, runtime)
      assert {:held, "k2_at_trip", 0} in report
    end
  end

  # Decision 96: a kept instance's member input that its program type's candidate version
  # writes no more keeps its value, and is reported by its path.
  describe "a member input no logic writes any more keeps its value, by path (decision 96)" do
    test "a counter's `r` and an rto's `r`, held at the switch, stay on" do
      head =
        "var_input clr bool\nvar_input go bool\nvar_output y bool\nvar boxes ctu\n" <>
          "var lube rto\n\n"

      tail = "xic go ctu boxes 3\nxic go rto lube 50\nxic boxes.q ote y\n"

      {:ok, a} =
        Logex.compile(head <> "xic clr ote boxes.r\nxic clr ote lube.r\n" <> tail, name: "a")

      {:ok, a2} = Logex.compile(head <> tail, name: "a")

      text =
        "task fast interval 10 priority 1\nvar_global c bool at d.i.0\n" <>
          "var_global g bool at d.i.1\nvar_global q bool at d.q.0\n" <>
          "program p a with fast\n  p.clr c\n  p.go g\n  p.y q\n"

      {:ok, original} = Configuration.compile("plant", text, %{"a" => a})
      {:ok, candidate} = Configuration.compile("plant", text, %{"a" => a2})
      {runtime, _} = cycles(Runtime.start(original), 2, %{"c" => 1, "g" => 1})
      {edit, forecast} = accepted(runtime, candidate)
      assert forecast == [{:unwritten, "p.boxes.r", 1}, {:unwritten, "p.lube.r", 1}]
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert report == forecast

      # The button let go and three boxes on a running motor: none counted, no time kept.
      runtime =
        Enum.reduce([0, 1, 0, 1, 0, 1], runtime, fn eye, runtime ->
          elem(cycles(runtime, 1, %{"c" => 0, "g" => eye}), 0)
        end)

      assert {Runtime.get!(runtime, "p.boxes.r"), Runtime.get!(runtime, "p.boxes.cv")} == {1, 0}
      assert {Runtime.get!(runtime, "p.lube.r"), Runtime.get!(runtime, "p.lube.acc")} == {1, 0}

      # The original writes both again: its untest reports neither.
      {_edit, _runtime, back} = Edit.untest(edit, runtime)
      refute Enum.any?(back, &match?({:unwritten, _, _}, &1))
    end
  end

  describe "a shared global across a switch (decisions 45, 49 and 55)" do
    # The motor with its `estop` its own `var`, which a rung latches from `overtemp`, so
    # its value can differ from the global's.
    defp own_estop,
      do:
        motor_ld()
        |> String.replace("var_external estop bool", "var estop bool")
        |> Kernel.<>("xic overtemp otl estop\n")

    test "a var_external become a var keeps the global's value as the instance's own, the " <>
           "global alone" do
      runtime = running(40)
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"estop" => 1})
      {edit, _} = accepted(runtime, plant(plant_text(), programs(own_estop())))
      {edit, runtime, report} = Edit.test(edit, runtime)
      assert {:left, "m1.estop", 1} in report
      assert {:left, "m2.estop", 1} in report
      assert runtime.instances["m1"].env["estop"] == 1

      # The global falls; `m1`'s own `estop` does not follow it.
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"estop" => 0})
      assert {Runtime.get!(runtime, "estop"), Runtime.get!(runtime, "m1.estop")} == {0, 1}

      # Back: `m1` reads the global again, its own value dropped and reported.
      {_edit, runtime, report} = Edit.untest(edit, runtime)
      assert {:joined, "m1.estop", {1, 0}} in report
      refute Map.has_key?(runtime.instances["m1"].env, "estop")
      assert Runtime.get!(runtime, "estop") == 0
    end

    test "a var become a var_external: the shared global wins, and no switch writes it " <>
           "(decision 55)" do
      original = plant(plant_text(), programs(own_estop()))
      runtime = Runtime.start(original)
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{"tt_1" => 1})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{"tt_1" => 0})
      assert {runtime.instances["m1"].env["estop"], Runtime.get!(runtime, "estop")} == {1, 0}
      {edit, _} = accepted(runtime, plant())
      {_edit, runtime, report} = Edit.test(edit, runtime)
      assert {:joined, "m1.estop", {1, 0}} in report
      assert {:joined, "m2.estop", {0, 0}} in report
      assert Runtime.get!(runtime, "estop") == 0
      assert holding(runtime, "estop") == []
    end

    test "a var_external added, bound to its global, had no value of its own" do
      runtime = running(20)

      motor =
        String.replace(
          motor_ld(),
          "var_external estop bool",
          "var_external estop bool\nvar_external alarm bool\nvar_external level dint"
        )

      text =
        String.replace(
          plant_text(),
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool 1\nvar_global level dint 42"
        )

      {_edit, forecast} = accepted(runtime, plant(text, programs(motor)))
      assert {:added, "alarm", 1} in forecast
      assert {:joined, "m1.alarm", {nil, 1}} in forecast
      assert {:joined, "m1.level", {nil, 42}} in forecast
    end

    test "a var_external in both, or one the candidate drops, is reported by neither" do
      runtime = running(20)
      motor = String.replace(motor_ld(), "ton t1 5000", "ton t1 6000")
      {_edit, forecast} = accepted(runtime, plant(plant_text(), programs(motor)))
      refute Enum.any?(forecast, &match?({kind, _, _} when kind in [:joined, :left], &1))

      dropped =
        String.replace(motor_ld(), "var_external estop bool\n", "")
        |> String.replace("xic estop otl fault\n", "")

      {_edit, forecast} = accepted(runtime, plant(plant_text(), programs(dropped)))
      refute Enum.any?(forecast, &match?({kind, _, _} when kind in [:joined, :left], &1))
    end
  end

  describe "a task's priority and the order of tasks and instances (decision 62)" do
    test "a priority changed is reported, and read at the next cycle's sort" do
      runtime = running(40)

      text =
        String.replace(
          plant_text(),
          "task fast interval 10 priority 1",
          "task fast interval 10 priority 5"
        )

      {edit, forecast} = accepted(runtime, plant(text))
      assert {:priority, "fast", {1, 5}} in forecast
      {_edit, runtime, _} = Edit.test(edit, runtime)
      {_runtime, _, events} = Runtime.cycle(runtime, 10, %{})
      assert for({:ran, task, _, _} <- events, do: task) == ["slow", "fast"]
    end

    test "instances reordered on a task are reported, and run in their new order" do
      one_task =
        String.replace(plant_text(), "program m2 motor with slow", "program m2 motor with fast")

      runtime = running(20, plant(one_task))

      swapped =
        String.replace(
          one_task,
          ~r/(program m1 motor with fast\n(?:  m1\..*\n)+)\n(program m2 motor with fast\n(?:  m2\..*\n)+)/,
          "\\2\n\\1"
        )

      assert swapped != one_task
      {edit, forecast} = accepted(runtime, plant(swapped))
      assert {:order, "fast", ["m2", "m1"]} in forecast
      {_edit, runtime, _} = Edit.test(edit, runtime)
      {_runtime, _, events} = Runtime.cycle(runtime, 10, %{})
      assert for({:ran, "fast", instance, _} <- events, do: instance) == ["m2", "m1"]
    end

    test "tasks reordered are reported; the task-less instances' order by :none" do
      runtime = running(20)

      text =
        plant_text()
        |> String.replace(
          "task fast interval 10 priority 1\ntask slow interval 50 priority 2",
          "task slow interval 50 priority 2\ntask fast interval 10 priority 1"
        )

      {_edit, forecast} = accepted(runtime, plant(text))
      assert {:order, :tasks, ["slow", "fast", "trip"]} in forecast

      extra =
        "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n\nprogram m4 motor\n  m4.start 0\n  m4.stop 0\n  m4.overtemp 0\n  m4.reset 0\n"

      runtime = running(20, plant(plant_text() <> extra))

      swapped =
        plant_text() <> String.replace(extra, ~r/(program m3.*?\n)\n(program m4.*)/s, "\\2\n\\1")

      {_edit, forecast} = accepted(runtime, plant(swapped))
      assert {:order, :none, ["m4", "m3"]} in forecast
    end

    test "an instance added or removed is no reorder" do
      runtime = running(20)

      text =
        without_m2() <>
          "program m9 motor with fast\n  m9.start 0\n  m9.stop 0\n  m9.overtemp 0\n  m9.reset 0\n"

      {_edit, forecast} = accepted(runtime, plant(text))
      refute Enum.any?(forecast, &match?({:order, _, _}, &1))
      refute Enum.any?(forecast, &match?({:priority, _, _}, &1))
    end
  end

  # Decision 129 (M4-2): a task's watchdog changes while the plant runs and is reported;
  # the continuous task's line is a task's, added or removed only with a restart, as is a
  # task made continuous or timed; and an instance with no `with` and one `with` the
  # continuous task run in one place, so `with main` added or taken away moves nothing.
  # The plant is §4.4's with two more instances of `motor` and its continuous line.
  describe "a watchdog and the continuous task across an edit (decision 129)" do
    @untimed "\ntask main continuous watchdog 200\n\n" <>
               "program m3 motor\n  m3.start 0\n  m3.stop 0\n  m3.overtemp 0\n  m3.reset 0\n\n" <>
               "program m4 motor\n  m4.start 0\n  m4.stop 0\n  m4.overtemp 0\n  m4.reset 0\n"

    defp untimed_plant, do: plant_text() <> @untimed

    # Ten cycles' outputs and events, a motor started, stopped and tripped among them.
    defp traced(runtime) do
      inputs = [
        %{"pb_start_1" => 1},
        %{"pb_start_1" => 0},
        %{"pb_stop_2" => 1},
        %{"estop" => 1},
        %{}
      ]

      {trace, _runtime} =
        Enum.map_reduce(inputs ++ inputs, runtime, fn image, runtime ->
          {runtime, outputs, events} = Runtime.cycle(runtime, 10, image)
          {{outputs, events}, runtime}
        end)

      trace
    end

    defp ran_in(runtime) do
      {_runtime, _, events} = Runtime.cycle(runtime, 10, %{})
      for {:ran, task, instance, _} <- events, do: {task, instance}
    end

    test "a watchdog changed is reported, in ms, 500 for none, and changes no cycle" do
      runtime = running(40)

      text =
        plant_text()
        |> String.replace(
          "task fast interval 10 priority 1",
          "task fast interval 10 priority 1 watchdog 30"
        )
        |> String.replace(
          "task slow interval 50 priority 2",
          "task slow interval 50 priority 2 watchdog 500"
        )
        |> String.replace(
          "task trip single estop priority 0",
          "task trip single estop priority 0 watchdog 5"
        )

      {edit, forecast} = accepted(runtime, plant(text))
      watched = for {:watchdog, _, _} = entry <- forecast, do: entry
      assert watched == [{:watchdog, "fast", {500, 30}}, {:watchdog, "trip", {500, 5}}]

      {edit, tested, report} = Edit.test(edit, runtime)
      assert for({:watchdog, _, _} = entry <- report, do: entry) == watched
      assert ran_in(tested) == ran_in(runtime)

      {_edit, _runtime, report} = Edit.untest(edit, tested)

      assert for({:watchdog, _, _} = entry <- report, do: entry) ==
               [{:watchdog, "fast", {30, 500}}, {:watchdog, "trip", {5, 500}}]

      # A continuous task's own, from its line's 200.
      runtime = running(20, plant(untimed_plant()))
      candidate = plant(String.replace(untimed_plant(), "continuous watchdog 200", "continuous"))
      {_edit, forecast} = accepted(runtime, candidate)
      assert {:watchdog, "main", {200, 500}} in forecast
    end

    test "the continuous line added or removed is refused as any task's, from source" do
      runtime =
        running(
          20,
          plant(
            plant_text() <> String.replace(@untimed, "task main continuous watchdog 200\n", "")
          )
        )

      text = untimed_plant()
      assert {:error, diagnostics} = Edit.accept(runtime, plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "task main"),
                "task `main` is added: a task is added only with a restart"}
             ]

      runtime = running(20, plant(untimed_plant()))
      text = plant_text() <> String.replace(@untimed, "task main continuous watchdog 200\n", "")
      assert {:error, diagnostics} = Edit.accept(runtime, plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {nil,
                "task `main` (line #{line(untimed_plant(), "task main")} of the running " <>
                  "configuration) is removed: a task is removed only with a restart"}
             ]
    end

    test "a task made continuous, or a continuous one made timed, is refused as its kind, " <>
           "once, from source" do
      for {line_now, kind} <- [
            {"task main interval 20 priority 3", "periodic"},
            {"task main single estop priority 3", "an event task"}
          ] do
        # `m3` names the task in both and `m4` none: neither is told it moved, the task's
        # own refusal being the one mistake.
        with_main = String.replace(untimed_plant(), "program m3 motor
", "program m3 motor with main
")
        text = String.replace(with_main, "task main continuous watchdog 200", line_now)
        assert {:error, diagnostics} = Edit.accept(running(20, plant(with_main)), plant(text))

        assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
                 {line(text, "task main"),
                  "task `main` is continuous in the running configuration and #{kind} in the " <>
                    "candidate: a task's kind changes only with a restart"}
               ]
      end

      runtime = running(20)

      text =
        String.replace(plant_text(), "task trip single estop priority 0", "task trip continuous")

      text = String.replace(text, "program snap snapshot with trip", "program snap snapshot")
      assert {:error, diagnostics} = Edit.accept(runtime, plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "task trip"),
                "task `trip` is an event task in the running configuration and continuous in " <>
                  "the candidate: a task's kind changes only with a restart"}
             ]
    end

    test "`with main` added or taken away moves nothing and reports no order" do
      runtime = running(20, plant(untimed_plant()))
      before = ran_in(runtime)
      assert {"main", "m3"} in before and {"main", "m4"} in before

      text = String.replace(untimed_plant(), "program m3 motor\n", "program m3 motor with main\n")
      {edit, forecast} = accepted(runtime, plant(text))
      assert forecast == []
      {edit, tested, report} = Edit.test(edit, runtime)
      assert report == []
      assert ran_in(tested) == before
      {_config, assembled, []} = Edit.assemble(edit, tested)
      assert ran_in(assembled) == before

      # And taken away again.
      runtime = running(20, plant(text))
      {_edit, forecast} = accepted(runtime, plant(untimed_plant()))
      assert forecast == []
    end

    # Decision 129's note: the continuous task is never due and takes part in no tie, so
    # its place among the task lines is no order of the tasks.
    test "the continuous line moved among the task lines reports nothing, and test then " <>
           "untest leaves the plant as it was" do
      runtime = running(20, plant(untimed_plant()))
      before = ran_in(runtime)

      moved =
        String.replace(
          plant_text(),
          "task fast interval 10 priority 1",
          "task main continuous watchdog 200\ntask fast interval 10 priority 1"
        ) <> String.replace(@untimed, "task main continuous watchdog 200\n", "")

      assert moved != untimed_plant()
      {edit, forecast} = accepted(runtime, plant(moved))
      assert forecast == []
      {edit, tested, report} = Edit.test(edit, runtime)
      assert report == []
      assert ran_in(tested) == before
      {_edit, untested, report} = Edit.untest(edit, tested)
      assert report == []
      assert untested.generation == runtime.generation + 2
      assert traced(tested) == traced(runtime)
      assert traced(untested) == traced(runtime)

      # Moved among the timed tasks too, only theirs is the tasks' order.
      reordered =
        String.replace(
          moved,
          "task fast interval 10 priority 1\ntask slow interval 50 priority 2",
          "task slow interval 50 priority 2\ntask fast interval 10 priority 1"
        )

      assert reordered != moved
      {_edit, forecast} = accepted(runtime, plant(reordered))
      assert forecast == [{:order, :tasks, ["slow", "fast", "trip"]}]
    end

    test "an instance moved between a timed task and the continuous one is refused, the " <>
           "continuous task named" do
      runtime = running(20, plant(untimed_plant()))

      text =
        untimed_plant()
        |> String.replace("program m1 motor with fast", "program m1 motor with main")
        |> String.replace("program m2 motor with slow", "program m2 motor")
        |> String.replace("program m3 motor\n", "program m3 motor with fast\n")

      assert {:error, diagnostics} = Edit.accept(runtime, plant(text))

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {line(text, "program m1"),
                "`m1` runs with `fast` in the running configuration and with `main` in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {line(text, "program m2"),
                "`m2` runs with `slow` in the running configuration and with `main` in the " <>
                  "candidate: an instance moves to another task only with a restart"},
               {line(text, "program m3"),
                "`m3` runs with `main` in the running configuration and with `fast` in the " <>
                  "candidate: an instance moves to another task only with a restart"}
             ]
    end

    test "the untimed instances, with no task or `with main`, are one order, under its name" do
      runtime = running(20, plant(untimed_plant()))

      swapped =
        (plant_text() <>
           String.replace(@untimed, ~r/(program m3.*?\n)\n(program m4.*)/s, "\\2\n\\1"))
        |> String.replace("program m4 motor\n", "program m4 motor with main\n")

      {edit, forecast} = accepted(runtime, plant(swapped))
      assert {:order, "main", ["m4", "m3"]} in forecast
      {_edit, tested, _report} = Edit.test(edit, runtime)
      assert for({"main", instance} <- ran_in(tested), do: instance) == ["m4", "m3"]
    end

    test "each, from Elixir data" do
      {:ok, relay} =
        Logex.compile("var_input in bool\nvar_output out bool\nxic in ote out", name: "relay")

      config = fn tasks, instances ->
        Configuration.new!(
          name: "plant",
          programs: [relay],
          tasks: tasks,
          globals: [%Configuration.Global{name: "x", type: :bool, at: "p.i.0"}],
          instances:
            for(
              {name, task} <- instances,
              do: %Configuration.Instance{name: name, type: "relay", task: task}
            ),
          connections:
            for(
              {name, _} <- instances,
              do: %Configuration.Connection{instance: name, member: "in", to: "x"}
            )
        )
      end

      main = %Configuration.Task{name: "main", continuous: true}
      fast = %Configuration.Task{name: "fast", interval: 10, priority: 1}
      runtime = Runtime.start(config.([main, fast], [{"a", nil}, {"b", "main"}, {"c", "fast"}]))

      # A watchdog, and `with main` added and taken away.
      candidate =
        config.([%{main | watchdog: 40}, fast], [{"a", "main"}, {"b", nil}, {"c", "fast"}])

      assert {:ok, _edit, [{:watchdog, "main", {500, 40}}]} = Edit.accept(runtime, candidate)

      # The continuous task made periodic: its kind, once, and `c` moved to no task, where
      # the candidate declares no continuous task.
      candidate =
        config.(
          [%Configuration.Task{name: "main", interval: 10, priority: 2}, fast],
          [{"a", nil}, {"b", "main"}, {"c", nil}]
        )

      assert {:error, diagnostics} = Edit.accept(runtime, candidate)

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {nil,
                "task `main` is continuous in the running configuration and periodic in the " <>
                  "candidate: a task's kind changes only with a restart"},
               {nil,
                "`c` runs with `fast` in the running configuration and with no task in the " <>
                  "candidate: an instance moves to another task only with a restart"}
             ]
    end
  end

  # Fix F16 for the plant: accept and every step stay linear in the instances of one type,
  # which share one plan, in the program types, each its own plan, and in a program's
  # size. Each measure is the least of three counts of reductions for accept, test,
  # untest, test and assemble, the candidate's every timer moved to a new preset and every
  # one-shot's rung changed, so each switch moves and blocks something in each instance.
  describe "growth (fix F16)" do
    defp grown(types, instances, size) do
      source = fn preset, contact ->
        decl =
          Enum.map_join(1..size, "\n", &"var t#{&1} ton\nvar s#{&1} bool\nvar_output o#{&1} bool")

        "var_input in bool\n" <>
          decl <>
          "\n\n" <>
          Enum.map_join(
            1..size,
            "\n",
            &"xic in ton t#{&1} #{preset}\n#{contact} in ons s#{&1} ote o#{&1}"
          )
      end

      config = fn preset, contact ->
        programs =
          for t <- 1..types do
            {:ok, program} = Logex.compile(source.(preset, contact), name: "p#{t}")
            program
          end

        names = for t <- 1..types, i <- 1..instances, do: {"m#{t}_#{i}", "p#{t}"}

        Configuration.new!(
          name: "plant",
          programs: programs,
          tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 1}],
          instances:
            for(
              {name, type} <- names,
              do: %Configuration.Instance{name: name, type: type, task: "fast"}
            ),
          connections:
            for(
              {name, _type} <- names,
              do: %Configuration.Connection{instance: name, member: "in", to: 1}
            )
        )
      end

      {config.(30, "xic"), config.(40, "xio")}
    end

    defp reductions_to_edit({original, candidate}) do
      {runtime, _, _} = Runtime.cycle(Runtime.start(original), 0, %{})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, edit, _} = Edit.accept(runtime, candidate)
          {edit, rt, _} = Edit.test(edit, runtime)
          {edit, rt, _} = Edit.untest(edit, rt)
          {edit, rt, _} = Edit.test(edit, rt)
          {_, _, report} = Edit.assemble(edit, rt)
          {:reductions, later} = Process.info(self(), :reductions)
          assert report == []
          later - before
        end
      )
    end

    # Over 32 runs on Elixir 1.20.4, 16 alone and 16 beside a full suite, 4x the instances
    # took 3.90x to 3.95x, 4x the types 4.00x to 4.03x and 4x the program 4.01x to 4.05x;
    # each bound is a fifth above its highest.
    test "accept and its steps stay linear in the instances of one type, one plan" do
      ratio = reductions_to_edit(grown(1, 200, 4)) / reductions_to_edit(grown(1, 50, 4))
      assert ratio < 4.74, "4x the instances took #{Float.round(ratio, 2)}x the reductions"
    end

    test "accept and its steps stay linear in the program types, a plan each" do
      ratio = reductions_to_edit(grown(80, 1, 4)) / reductions_to_edit(grown(20, 1, 4))
      assert ratio < 4.84, "4x the types took #{Float.round(ratio, 2)}x the reductions"
    end

    # Tasks and instances grown together, each task running one instance and as many
    # instances running in the continuous task, declared last, the candidate moving one
    # of those to the end: decision 62's orders are found once an edit, not once an
    # instance and task.
    defp tasked(n) do
      {:ok, relay} =
        Logex.compile("var_input in bool\nvar_output out bool\nxic in ote out",
          name: "relay"
        )

      config = fn untimed ->
        timed = for i <- 1..n, do: {"m#{i}", "t#{i}"}

        Configuration.new!(
          name: "plant",
          programs: [relay],
          tasks:
            for(i <- 1..n, do: %Configuration.Task{name: "t#{i}", interval: 10, priority: 1}) ++
              [%Configuration.Task{name: "main", continuous: true}],
          instances:
            for(
              {name, task} <- timed ++ untimed,
              do: %Configuration.Instance{name: name, type: "relay", task: task}
            ),
          connections:
            for(
              {name, _task} <- timed ++ untimed,
              do: %Configuration.Connection{instance: name, member: "in", to: 0}
            )
        )
      end

      [first | rest] = for i <- 1..n, do: {"u#{i}", nil}
      {config.([first | rest]), config.(rest ++ [first])}
    end

    defp reductions_to_test({original, candidate}) do
      runtime = Runtime.start(original)

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, edit, _} = Edit.accept(runtime, candidate)
          {edit, rt, _} = Edit.test(edit, runtime)
          {_edit, _rt, report} = Edit.untest(edit, rt)
          {:reductions, later} = Process.info(self(), :reductions)
          assert [{:order, "main", _}] = report
          later - before
        end
      )
    end

    # Over 32 runs on Elixir 1.20.4, 16 alone and 16 beside three full suites, 4x the tasks
    # and instances took 4.01x to 4.02x, and 6.85x with the continuous task looked for once
    # an instance; the bound is a fifth above the highest.
    test "accept, test and untest stay linear in the tasks and instances grown together" do
      ratio = reductions_to_test(tasked(200)) / reductions_to_test(tasked(50))

      assert ratio < 4.83,
             "4x the tasks and instances took #{Float.round(ratio, 2)}x the reductions"
    end

    test "accept and its steps stay linear in a program's size" do
      ratio = reductions_to_edit(grown(1, 2, 800)) / reductions_to_edit(grown(1, 2, 200))
      assert ratio < 4.86, "4x the program took #{Float.round(ratio, 2)}x the reductions"
    end
  end
end
