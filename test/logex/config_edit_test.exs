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
      refute Enum.any?(forecast, &match?({_, "m" <> _, _}, &1))

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
      refute Enum.any?(forecast, &match?({_, "m1.alarm", _}, &1))
      refute Enum.any?(forecast, &match?({_, "m2.alarm", _}, &1))

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
end
