defmodule Logex.M3SpikeTest do
  # SPIKE for the Milestone 3 design pass: how far Logex.FbType, the compiler, the walks and
  # the edit machinery carry a built-in counter with no new mechanism. Never lands.
  use ExUnit.Case, async: true

  alias Logex.{Edit, Runtime}

  defp compile!(source, name \\ "box") do
    {:ok, program} = Logex.compile(source, name: name)
    program
  end

  # Scans `program` from `state`, one input map per scan, 10 ms apart; the last state and
  # every scan's outputs.
  defp run(program, state, inputs) do
    Enum.map_reduce(inputs, state, fn input, state ->
      state = Runtime.put_inputs(program, state, input)
      {outputs, state} = Runtime.scan(program, state, 10)
      {outputs, state}
    end)
  end

  @counter """
  var_input eye bool
  var_input clear bool
  var_output full bool
  var_output count dint
  var boxes ctu
  xic eye ctu boxes 3
  xic boxes.dn ote full
  move boxes.acc count
  xic clear move 0 boxes.acc
  """

  test "a ctu counts rising edges, not the first scan, and is done at its preset" do
    program = compile!(@counter)
    assert program.warnings == []
    state = Runtime.instance(program)
    assert state.env["boxes"] == %{"pre" => 3, "acc" => 0, "cu" => 0, "dn" => 0, "ov" => 0}

    # a box on the eye at start is not counted; three more boxes are
    pulses = [1, 1, 0, 1, 0, 1, 1, 0, 1, 0]
    {outputs, state} = run(program, state, Enum.map(pulses, &%{"eye" => &1}))
    assert Enum.map(outputs, & &1["count"]) == [0, 0, 0, 1, 1, 2, 2, 2, 3, 3]
    assert List.last(outputs)["full"] == 1
    assert state.env["boxes"]["dn"] == 1

    # clearing .acc by a move: dn drops at the counter's next run
    {outputs, _state} = run(program, state, [%{"clear" => 1}, %{"clear" => 0}])
    assert Enum.map(outputs, & &1["full"]) == [1, 0]
  end

  test "restart/3 starts the counter again at its preset" do
    program = compile!(@counter)
    {_out, state} = run(program, Runtime.instance(program), [%{"eye" => 0}, %{"eye" => 1}])
    assert state.env["boxes"]["acc"] == 1
    state = Runtime.restart(program, state, :warm)
    assert state.env["boxes"] == %{"pre" => 3, "acc" => 0, "cu" => 0, "dn" => 0, "ov" => 0}
  end

  test "an edit that changes the preset moves .pre where logic left it alone" do
    program = compile!(@counter)
    {_out, state} = run(program, Runtime.instance(program), [%{"eye" => 0}, %{"eye" => 1}])
    candidate = compile!(String.replace(@counter, "ctu boxes 3", "ctu boxes 5"))

    result =
      try do
        {:ok, edit, _forecast} = Edit.accept(program, candidate, state)
        {_edit, state, report} = Edit.test(edit, state)
        {:ok, state.env["boxes"], report}
      rescue
        error -> {:raised, error.__struct__, Exception.message(error)}
      end

    IO.inspect(result, label: "SPIKE preset edit")
  end

  test "an edit that adds a counter whose rung is already true" do
    plain = """
    var_input eye bool
    var_output full bool
    xic eye ote full
    """

    program = compile!(plain)
    {_out, state} = run(program, Runtime.instance(program), [%{"eye" => 1}, %{"eye" => 1}])
    candidate = compile!(@counter)
    {:ok, edit, _forecast} = Edit.accept(program, candidate, state)
    {_edit, state, report} = Edit.test(edit, state)
    IO.inspect(report, label: "SPIKE added counter report")
    {outputs, _state} = run(candidate, state, [%{"eye" => 1}])
    IO.inspect(outputs, label: "SPIKE first scan after the switch, box still on the eye")
  end

  test "a counter inside a frozen block holds its count" do
    block = """
    function_block tally
    var_input pulse bool
    var_output n dint
    var c ctu
    xic pulse ctu c 100
    move c.acc n
    """

    {:ok, tally} = Logex.compile(block, name: "tally")

    outer = """
    var_input run bool
    var_input eye bool
    var_output n dint
    var t tally
    xic run cal t eye n
    """

    {:ok, program} = Logex.compile(outer, name: "line", types: [tally])

    inputs =
      for {run, eye} <- [{1, 0}, {1, 1}, {0, 0}, {0, 1}, {1, 1}, {1, 0}, {1, 1}],
          do: %{"run" => run, "eye" => eye}

    {outputs, _} = run(program, Runtime.instance(program), inputs)
    IO.inspect(Enum.map(outputs, & &1["n"]), label: "SPIKE frozen block counts")
  end

  test "warnings and the walk for a counter no ctu runs" do
    program = compile!("var_output q bool\nvar c ctu\nxic c.dn ote q\n")
    IO.inspect(Enum.map(program.warnings, & &1.message), label: "SPIKE warnings")
    IO.inspect(Logex.Walk.timers(compile!(@counter)), label: "SPIKE Walk.timers")
  end

  test "something after a ctu on its path" do
    IO.inspect(Logex.compile("var c ctu\nvar q bool\nctu c 3 ote q\n", name: "p"),
      label: "SPIKE path"
    )
  end

  @plain_counter """
  var_input eye bool
  var_output count dint
  var boxes ctu
  xic eye ctu boxes 3
  move boxes.acc count
  """

  test "with the block list: an added counter whose rung is true does not count at the switch" do
    plain = "var_input eye bool\nvar_output count dint\nxic eye move 7 count\n"
    program = compile!(plain)
    {_out, state} = run(program, Runtime.instance(program), [%{"eye" => 1}, %{"eye" => 1}])
    candidate = compile!(@plain_counter)
    {:ok, edit, _forecast} = Edit.accept(program, candidate, state)
    {_edit, state, _report} = Edit.test(edit, state)
    assert state.ons_blocked == ["boxes"]
    {outputs, state} = run(candidate, state, [%{"eye" => 1}, %{"eye" => 0}, %{"eye" => 1}])
    assert Enum.map(outputs, & &1["count"]) == [0, 0, 1]
    assert state.ons_blocked == []
  end

  test "with the block list: an unchanged counter is not blocked, so an edge at the switch counts" do
    program = compile!(@plain_counter)
    {_out, state} = run(program, Runtime.instance(program), [%{"eye" => 0}])
    candidate = compile!("var_output spare bool\n" <> @plain_counter <> "xic eye ote spare\n")
    {:ok, edit, _forecast} = Edit.accept(program, candidate, state)
    {_edit, state, _report} = Edit.test(edit, state)
    assert state.ons_blocked == []
    {outputs, _state} = run(candidate, state, [%{"eye" => 1}])
    assert Enum.map(outputs, & &1["count"]) == [1]
  end

  test "a .pre logic moved is kept across a preset change, and a ctu removed and restored" do
    program = compile!(@counter <> "xic clear move 9 boxes.pre\n")
    {_out, state} = run(program, Runtime.instance(program), [%{"clear" => 1}, %{"eye" => 1}])
    assert state.env["boxes"]["pre"] == 9

    candidate =
      compile!(
        String.replace(@counter, "ctu boxes 3", "ctu boxes 5") <> "xic clear move 9 boxes.pre\n"
      )

    {:ok, edit, _} = Edit.accept(program, candidate, state)
    {_edit, state2, report} = Edit.test(edit, state)
    IO.inspect({state2.env["boxes"], report}, label: "SPIKE .pre moved by logic, preset 3 -> 5")

    # the ctu removed: the count is frozen, and kept
    removed = compile!(String.replace(@counter, "xic eye ctu boxes 3\n", ""))
    {:ok, edit, _} = Edit.accept(program, removed, state)
    {edit, state3, report} = Edit.test(edit, state)

    IO.inspect({state3.env["boxes"], report, Enum.map(removed.warnings, & &1.message)},
      label: "SPIKE ctu removed"
    )

    {program3, state3, _} = Edit.assemble(edit, state3)
    restored = compile!(String.replace(@counter, "ctu boxes 3", "ctu boxes 4"))
    {:ok, edit, _} = Edit.accept(program3, restored, state3)
    {_edit, state4, report} = Edit.test(edit, state3)
    IO.inspect({state4.env["boxes"], report}, label: "SPIKE ctu restored at 4")
  end

  test "a type change from ton to ctu is refused" do
    timer = "var_input go bool\nvar_output q bool\nvar t ton\nxic go ton t 100\nxic t.dn ote q\n"
    program = compile!(timer)

    counter =
      "var_input go bool\nvar_output q bool\nvar t ctu\nxic go ctu t 100\nxic t.dn ote q\n"

    candidate = compile!(counter)
    IO.inspect(Edit.accept(program, candidate, Runtime.instance(program)), label: "SPIKE retype")
  end
end
