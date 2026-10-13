defmodule Logex.ConfigEditSpikeTest do
  # SPIKE (OE-2 design pass, throwaway): does a configuration's switch build from OE-1's
  # per-instance plan, switch and prune plus decision 45's merge and split?
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.Edit, as: CEdit

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

  @snapshot_ld """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  defp programs(motor_ld \\ nil) do
    {:ok, seal} = Logex.compile(cut("**A function block type** is"), name: "seal")
    motor_ld = motor_ld || cut("**The motor, rewritten to use it**")
    {:ok, motor} = Logex.compile(motor_ld, name: "motor", types: [seal])
    {:ok, snapshot} = Logex.compile(@snapshot_ld, name: "snapshot")
    %{"motor" => motor, "snapshot" => snapshot}
  end

  defp motor_ld, do: cut("**The motor, rewritten to use it**")

  defp plant(text \\ plant_text(), programs \\ programs()) do
    {:ok, config} = Configuration.compile("plant", text, programs)
    config
  end

  # The plant cycled to `last` ms: both motors started at 0 ms.
  defp running(last) do
    rt = Runtime.start(plant())
    {rt, _, _} = Runtime.cycle(rt, 0, %{"pb_start_1" => 1, "pb_start_2" => 1})
    {rt, _, _} = Runtime.cycle(rt, 10, %{"pb_start_1" => 0, "pb_start_2" => 0})

    Enum.reduce(20..last//10, rt, fn _now, rt ->
      {rt, _, _} = Runtime.cycle(rt, 10, %{})
      rt
    end)
  end

  defp cycles(rt, n, inputs \\ %{}) do
    Enum.reduce(1..n, {rt, nil}, fn _, {rt, _} ->
      {rt, out, _} = Runtime.cycle(rt, 10, inputs)
      {rt, out}
    end)
  end

  test "a changed preset in the program type moves every instance by one plan, by path" do
    rt = running(100)
    assert Runtime.get!(rt, "m1.t1.acc") == 100

    candidate =
      plant(plant_text(), programs(String.replace(motor_ld(), "ton t1 5000", "ton t1 6000")))

    {:ok, edit, forecast} = CEdit.accept(rt, candidate)
    {edit, rt, report} = CEdit.test(edit, rt)
    assert forecast == report
    assert {:preset, "m1.t1", {5000, 6000}} in report
    assert {:preset, "m2.t1", {5000, 6000}} in report
    assert Runtime.get!(rt, "m1.t1.pre") == 6000
    # Decision 49 holds across the switch: no instance's state holds its var_external.
    refute Map.has_key?(rt.instances["m1"].env, "estop")
    {rt, _} = cycles(rt, 3)
    {edit, rt, report} = CEdit.untest(edit, rt)
    assert {:preset, "m1.t1", {6000, 5000}} in report
    {edit, rt, _} = CEdit.test(edit, rt)
    {program, rt, report} = CEdit.assemble(edit, rt)
    assert program == candidate
    assert report == []
    assert Runtime.get!(rt, "m1.t1.pre") == 6000
    {_rt, out} = cycles(rt, 2)
    assert out["k1"] == 1
  end

  test "decision 45: a var_external made a var keeps the global's value, the global alone" do
    rt = running(40)
    {rt, _, _} = Runtime.cycle(rt, 10, %{"estop" => 1})
    {rt, _, _} = Runtime.cycle(rt, 10, %{"estop" => 0})
    # m1's fault latched; the e-stop is released. Now `estop` becomes m1's own var, with
    # a rung that latches it, so its value is visible.
    motor = String.replace(motor_ld(), "var_external estop bool", "var estop bool")
    candidate = plant(plant_text(), programs(motor))
    {:ok, edit, _} = CEdit.accept(rt, candidate)
    {edit, rt, report} = CEdit.test(edit, rt)
    assert {:left, "m1.estop", 0} in report
    assert rt.instances["m1"].env["estop"] == 0
    assert Runtime.get!(rt, "estop") == 0
    # The global changes; m1's own var does not follow it.
    {rt, _, _} = Runtime.cycle(rt, 10, %{"estop" => 1})
    assert rt.instances["m1"].env["estop"] == 0
    # Back: m1 reads the global again, its own value dropped, the global untouched.
    {_edit, rt, report} = CEdit.untest(edit, rt)
    assert {:joined, "m1.estop", {0, 1}} in report
    refute Map.has_key?(rt.instances["m1"].env, "estop")
    assert Runtime.get!(rt, "estop") == 1
  end

  test "the open question: a var made a var_external never writes the shared global" do
    motor = String.replace(motor_ld(), "var_external estop bool", "var estop bool")

    motor =
      String.replace(motor, "xic estop otl fault", "xic estop otl fault\nxic overtemp otl estop")

    original = plant(plant_text(), programs(motor))
    rt = Runtime.start(original)
    {rt, _, _} = Runtime.cycle(rt, 0, %{"tt_1" => 1})
    {rt, _, _} = Runtime.cycle(rt, 10, %{"tt_1" => 0})
    assert rt.instances["m1"].env["estop"] == 1
    assert Runtime.get!(rt, "estop") == 0
    {:ok, edit, _} = CEdit.accept(rt, plant())
    {_edit, rt, report} = CEdit.test(edit, rt)
    assert {:joined, "m1.estop", {1, 0}} in report
    assert {:joined, "m2.estop", {0, 0}} in report
    assert Runtime.get!(rt, "estop") == 0
    refute Map.has_key?(rt.instances["m1"].env, "estop")
  end

  test "decision 40: a shorter interval within one new period, a longer one on the old phase" do
    rt = running(10)
    # slow ran at 0, next due 50; now 10.
    shorter = plant(String.replace(plant_text(), "interval 50", "interval 20"))
    {:ok, edit, _} = CEdit.accept(rt, shorter)
    {edit, rt2, report} = CEdit.test(edit, rt)
    assert {:interval, "slow", {50, 20}} in report
    assert {:next_due, "slow", {50, 30}} in report
    {_rt, _} = cycles(rt2, 1)
    {_edit, _rt2, report} = CEdit.untest(edit, rt2)
    # Back at 10 ms: min(30, 10 + 50) keeps 30.
    assert {:interval, "slow", {20, 50}} in report
    refute Enum.any?(report, &match?({:next_due, _, _}, &1))

    longer = plant(String.replace(plant_text(), "interval 50", "interval 200"))
    {:ok, edit, _} = CEdit.accept(rt, longer)
    {_edit, _rt, report} = CEdit.test(edit, rt)
    assert {:interval, "slow", {50, 200}} in report
    refute Enum.any?(report, &match?({:next_due, _, _}, &1))
  end

  test "an instance removed is set aside, its output held, and pruned at assemble" do
    rt = running(60)

    text =
      plant_text()
      |> String.replace(~r/program m2 motor with slow\n(  m2\..*\n)+/, "")

    candidate = plant(text)
    {:ok, edit, _} = CEdit.accept(rt, candidate)
    {edit, rt, report} = CEdit.test(edit, rt)
    assert {:instance_stopped, "m2", "motor"} in report
    assert {:held, "k2", 1} in report
    {rt, out} = cycles(rt, 3)
    assert out["k2"] == 1
    {edit, rt, report} = CEdit.untest(edit, rt)
    refute Enum.any?(report, &match?({:instance_added, _, _}, &1))
    assert Runtime.get!(rt, "m2.motor") == 1
    {edit, rt, _} = CEdit.test(edit, rt)
    {_c, rt, report} = CEdit.assemble(edit, rt)
    assert {:instance_pruned, "m2", "motor"} in report
    assert rt.idle == %{}
  end

  test "decision 43: an instance retyped is a remove plus an add, and untest brings it back" do
    rt = running(60)

    text =
      plant_text()
      |> String.replace("program snap snapshot with trip", "program snap motor with trip")
      |> String.replace(~r/  snap\..*\n/, "")
      |> Kernel.<>("  snap.start 0\n  snap.stop 0\n  snap.overtemp 0\n  snap.reset 0\n")

    {:ok, candidate} = Configuration.compile("plant", text, programs())
    {:ok, edit, _} = CEdit.accept(rt, candidate)
    {edit, rt, report} = CEdit.test(edit, rt)
    assert {:instance_stopped, "snap", "snapshot"} in report
    assert {:instance_added, "snap", "motor"} in report
    assert {:held, "k1_at_trip", 0} in report
    {_edit, rt, report} = CEdit.untest(edit, rt)
    assert {:instance_stopped, "snap", "motor"} in report
    assert rt.instances["snap"].type == "snapshot"
  end

  test "refusals: a task added, a single changed, an instance moved, a located point" do
    rt = running(10)

    text =
      plant_text()
      |> String.replace(
        "task trip single estop priority 0",
        "task trip single pb_reset priority 0\ntask extra interval 5 priority 3"
      )
      |> String.replace("program m2 motor with slow", "program m2 motor with fast")
      |> String.replace("sp_2       dint at drive.q.1", "sp_2       dint at drive.q.2")

    {:ok, candidate} = Configuration.compile("plant", text, programs())
    assert {:error, diagnostics} = CEdit.accept(rt, candidate)

    assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
             {4,
              "task `trip`'s single changes from \"estop\" to \"pb_reset\": a task's single changes only with a restart"},
             {5, "task `extra` is added: a task is added only with a restart"},
             {20,
              "`sp_2` is at \"drive.q.1\" in the running configuration and at \"drive.q.2\" in the candidate: located I/O changes only with a restart"},
             {33,
              "`m2` runs with `slow` in the running configuration and with `fast` in the candidate: an instance moves to another task only with a restart"}
           ]
  end

  test "the generation counter: a stale or superseded edit is refused" do
    rt = running(10)
    candidate = plant(String.replace(plant_text(), "interval 50", "interval 20"))
    {:ok, a, _} = CEdit.accept(rt, candidate)
    {:ok, b, _} = CEdit.accept(rt, candidate)
    {a, rt, _} = CEdit.test(a, rt)
    # A cycle does not move the generation.
    {rt, _} = cycles(rt, 2)

    assert_raise ArgumentError,
                 "this edit last saw the resource at generation 0, but it is at generation 1: " <>
                   "the edit has ended, or another edit has changed the resource since",
                 fn -> CEdit.test(b, rt) end

    {_c, rt, _} = CEdit.assemble(a, rt)

    assert_raise ArgumentError, ~r/generation 1, but it is at generation 2/, fn ->
      CEdit.untest(a, rt)
    end
  end

  test "restart/2 during a test drops the instances set aside; untest starts them again" do
    rt = running(60)
    text = String.replace(plant_text(), ~r/program m2 motor with slow\n(  m2\..*\n)+/, "")
    {:ok, edit, _} = CEdit.accept(rt, plant(text))
    {edit, rt, _} = CEdit.test(edit, rt)
    rt = Runtime.restart(rt, :cold)
    {_edit, _rt, report} = CEdit.untest(edit, rt)
    assert {:instance_added, "m2", "motor"} in report
  end

  test "a timer resumed in a slow task starts timing at the switch, not its last scan" do
    # m2 on `slow` scans at 0 and 50; the candidate removes the motor's timer rung and the
    # untest gives it back, at 70 ms, so m2's last scan was at 50.
    rt = running(70)
    assert rt.instances["m2"].now == 50
    motor = String.replace(motor_ld(), "xic motor ton t1 5000\n", "")
    {:ok, edit, _} = CEdit.accept(rt, plant(plant_text(), programs(motor)))
    {edit, rt, _} = CEdit.test(edit, rt)
    {rt, _} = cycles(rt, 5)
    # Now 120: m2 scanned at 100 under the candidate.
    {rt, _} = cycles(rt, 1)
    {_edit, rt, report} = CEdit.untest(edit, rt)
    # 50 to 130 ms: the instance's own clock, 100, would leave 100 to 130 to be caught up.
    assert {:resumed, "m2.t1", 80} in report
    acc = rt.instances["m2"].env["t1"]["acc"]
    {rt2, _} = cycles(rt, 2)
    assert rt2.instances["m2"].env["t1"]["acc"] == acc + 20
    assert rt.instances["m2"].env["t1"]["last"] == rt.now
  end

  test "a var_output no longer written holds its point, named by instance and by point" do
    rt = running(60)
    motor = String.replace(motor_ld(), "xic motor ote run_lamp\n", "")
    {:ok, edit, _} = CEdit.accept(rt, plant(plant_text(), programs(motor)))
    {_edit, _rt, report} = CEdit.test(edit, rt)
    assert {:held, "lamp_1", 1} in report
    assert {:held, "m1.run_lamp", 1} in report
  end

  test "a block type changed for the whole configuration moves each instance by path" do
    rt = running(60)

    seal_ld =
      cut("**A function block type** is")
      |> String.replace("var_output run bool", "var_output run bool\nvar n dint 7")

    {:ok, seal} = Logex.compile(seal_ld, name: "seal")
    {:ok, motor} = Logex.compile(motor_ld(), name: "motor", types: [seal])
    {:ok, snapshot} = Logex.compile(@snapshot_ld, name: "snapshot")
    candidate = plant(plant_text(), %{"motor" => motor, "snapshot" => snapshot})
    {:ok, edit, _} = CEdit.accept(rt, candidate)
    {_edit, rt, report} = CEdit.test(edit, rt)
    assert {:added, "m1.s1.n", 7} in report
    assert {:added, "m2.s1.n", 7} in report
    assert rt.instances["m1"].env["s1"]["n"] == 7
  end

  test "a var_external added, bound to a global the edit adds, is no tag started" do
    rt = running(20)

    motor =
      String.replace(
        motor_ld(),
        "var_external estop bool",
        "var_external estop bool\nvar_external alarm bool\nvar_external level dint"
      )

    text =
      String.replace(
        plant_text(),
        "var_global k1_at_trip bool",
        "var_global k1_at_trip bool\nvar_global alarm bool 1\nvar_global level dint 42"
      )

    {:ok, candidate} = Configuration.compile("plant", text, programs(motor))
    {:ok, edit, _} = CEdit.accept(rt, candidate)
    {_edit, rt, report} = CEdit.test(edit, rt)
    assert {:added, "alarm", 1} in report
    assert {:joined, "m1.alarm", {nil, 1}} in report
    assert {:joined, "m1.level", {nil, 42}} in report
    refute Enum.any?(report, &match?({:added, "m1.alarm", _}, &1))
    refute Map.has_key?(rt.instances["m1"].env, "alarm")
  end
end
