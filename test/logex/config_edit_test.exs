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

    test "accept and its steps stay linear in a program's size" do
      ratio = reductions_to_edit(grown(1, 2, 800)) / reductions_to_edit(grown(1, 2, 200))
      assert ratio < 4.86, "4x the program took #{Float.round(ratio, 2)}x the reductions"
    end
  end
end
