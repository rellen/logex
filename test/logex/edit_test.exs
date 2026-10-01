defmodule Logex.EditTest do
  @moduledoc """
  OE-1: `Logex.Edit`, a staged edit of one program instance (docs/organisation.md §4.9).
  Every message a host mistake raises is pinned here, every `:edit` diagnostic, and every
  rule a switch or a prune applies, each by a test that fails when the rule alone is
  reverted. Programs come from `Logex.compile/2`, or unnamed from
  `Logex.Compiler.instructionize/2`, never from editing a struct (fix F12).
  """
  use ExUnit.Case, async: true

  alias Logex.{Compiler, Diagnostic, Edit, Instance, Runtime, Tag}

  defp c!(src, name \\ "m") do
    {:ok, program} = Logex.compile(src, name: name)
    program
  end

  # An unnamed program, within the contract: instructionize/2 names none.
  defp unnamed!(src, declared \\ []) do
    {:ok, tokens, _} = Compiler.tokenize(src)
    {:ok, ast} = Compiler.parse(tokens)
    {:ok, program} = Compiler.instructionize(ast, declared)
    program
  end

  # Scans `program` from `state`, each step `{elapsed_ms, inputs}`: the last outputs and
  # the state after.
  defp drive(program, state, steps),
    do:
      Enum.reduce(steps, {%{}, state}, fn {ms, inputs}, {_, state} ->
        Runtime.scan(program, Runtime.put_inputs(program, state, inputs), ms)
      end)

  defp run(program, steps), do: drive(program, Runtime.instance(program), steps)

  defp accept!(running, candidate, state) do
    {:ok, edit, _forecast} = Edit.accept(running, candidate, state)
    edit
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # A host mistake the type checker can see is a warning on every run; this hides it.
  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  @motor """
  var_input start bool
  var_input stop bool
  var_output motor bool
  var_output lamp bool
  var t1 ton

  ( xic start | xic motor ) xio stop ote motor
  xic motor ote lamp
  xic motor ton t1 5000
  """

  describe "accept" do
    test "refuses a type change, every one, at the candidate's line, in line order" do
      v1 = c!("var_input go bool\nvar z dint\nvar t1 ton\nvar k bool\nxic go ton t1 5\nmove 1 z")

      # Declared z, t1, k: line order, which is not name order.
      v2 =
        c!("var_input go bool\nvar z bool\nvar t1 bool\nvar k ton\nxic go ton k 5\nxic t1 ote z")

      assert {:error, diagnostics} = Edit.accept(v1, v2, Runtime.instance(v1))

      assert Enum.map(diagnostics, &{&1.stage, &1.severity, Diagnostic.format(&1)}) == [
               {:edit, :error,
                "line 2: `z` is a dint in the running program and a bool in the candidate: " <>
                  "a tag's type changes only with a restart"},
               {:edit, :error,
                "line 3: `t1` is a ton in the running program and a bool in the candidate: " <>
                  "a tag's type changes only with a restart"},
               {:edit, :error,
                "line 4: `k` is a bool in the running program and a ton in the candidate: " <>
                  "a tag's type changes only with a restart"}
             ]

      assert Enum.all?(diagnostics, &(&1.file == nil and &1.column == nil))
    end

    test "cites a tag declared from Elixir without a line, after every tag with one, by name" do
      # More than 32 tags, so the order comes from the sort and not from a small map's.
      names = Enum.map(1..40, &"x#{&1}")
      v1 = unnamed!("var n dint\nmove 1 n", Enum.map(names, &Tag.new!(&1, :bool)))
      v2 = unnamed!("var n bool\nvar m bool\nxic m ote n", Enum.map(names, &Tag.new!(&1, :dint)))

      assert {:error, [%Diagnostic{line: 1} = first | elixir]} =
               Edit.accept(v1, v2, Runtime.instance(v1))

      assert Diagnostic.format(first) =~ "line 1: `n` is a dint in the running program"
      assert Enum.map(elixir, & &1.line) == List.duplicate(nil, 40)
      cited = Enum.map(elixir, &hd(String.split(Diagnostic.format(&1), " ")))
      assert cited == Enum.map(Enum.sort(names), &"`#{&1}`")

      assert Diagnostic.format(hd(elixir)) ==
               "`x1` is a bool in the running program and a dint in the candidate: " <>
                 "a tag's type changes only with a restart"
    end

    test "takes a section change, keeping its value, and a candidate with a warning" do
      v1 = c!("var_input a bool\nvar f bool\nxic a otl f")
      v2 = c!("var_input a bool\nvar_output f bool\nvar spare bool\nxic a otl f")
      assert [%Diagnostic{severity: :warning}] = v2.warnings
      {_, state} = run(v1, [{0, %{"a" => 1}}, {10, %{"a" => 0}}])
      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "spare", 0}]
      assert {%{"f" => 1}, _} = Runtime.scan(v2, state, 10)
    end

    test "changes nothing, and forecasts the report a test taken now gives" do
      v1 = c!("var_input go bool\nvar_output y bool\nvar_output n dint 3\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output n dint 4\nvar k dint 9\nmove 1 n")
      {_, state} = run(v1, [{0, %{"go" => 1}}])

      assert {:ok, edit, forecast} = Edit.accept(v1, v2, state)

      assert forecast == [
               {:added, "k", 9},
               {:held, "y", 1},
               {:initial_changed, "n", {3, 4}}
             ]

      assert Edit.stage(edit) == :accepted
      assert {_edit, _state, ^forecast} = Edit.test(edit, state)
    end

    test "a test taken later reads the state as it is then, not as accept saw it" do
      v1 = c!("var_input go bool\nvar_output y bool\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output z bool\nxic go ote z")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {:ok, edit, [{:added, "z", 0}, {:held, "y", 1}]} = Edit.accept(v1, v2, state)
      {_, state} = drive(v1, state, [{10, %{"go" => 0}}])
      assert {_, _, [{:added, "z", 0}, {:held, "y", 0}]} = Edit.test(edit, state)
    end
  end

  describe "host mistakes" do
    setup do
      v1 = c!(@motor, "motor")
      v2 = c!(String.replace(@motor, "var t1 ton", "var t1 ton\nvar k dint"), "motor")
      {_, state} = run(v1, [{0, %{"start" => 1}}])
      %{v1: v1, v2: v2, state: state}
    end

    test "accept takes two programs of one name and the running program's state", %{
      v1: v1,
      v2: v2,
      state: s
    } do
      raises("expected a %Logex.Program{} from Logex.compile/2, got: :x", fn ->
        Edit.accept(opaque(:x), v2, s)
      end)

      raises("expected a %Logex.Program{} from Logex.compile/2, got: :y", fn ->
        Edit.accept(v1, opaque(:y), s)
      end)

      # A program's struct is not enough: its tags must be a map and its rungs a list,
      # checked before anything walks either.
      for {running, candidate, bad} <- [
            {%{v1 | tags: nil}, v2, %{v1 | tags: nil}},
            {v1, %{v2 | tags: nil}, %{v2 | tags: nil}},
            {v1, %{v2 | rungs: nil}, %{v2 | rungs: nil}}
          ] do
        raises("expected a %Logex.Program{} from Logex.compile/2, got: #{inspect(bad)}", fn ->
          Edit.accept(opaque(running), opaque(candidate), s)
        end)
      end

      raises(
        "the candidate is `pump`, but the running program is `motor`: " <>
          "an edit keeps the program's name",
        fn -> Edit.accept(v1, c!(@motor, "pump"), s) end
      )

      raises(
        "the candidate is an unnamed program, but the running program is `motor`: " <>
          "an edit keeps the program's name",
        fn -> Edit.accept(v1, unnamed!(@motor), s) end
      )

      raises(
        "the candidate is `motor`, but the running program is an unnamed program: " <>
          "an edit keeps the program's name",
        fn -> Edit.accept(unnamed!(@motor), v1, s) end
      )

      raises("this state is an instance of `motor`, not of `pump`", fn ->
        Edit.accept(c!(@motor, "pump"), c!(@motor, "pump"), s)
      end)

      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: nil", fn ->
        Edit.accept(v1, v2, opaque(nil))
      end)

      raises("state.ons_blocked must be a list of storage bit names, got: nil", fn ->
        Edit.accept(v1, v2, %{s | ons_blocked: nil})
      end)
    end

    test "accept checks the running program, the candidate, the name, then the state", %{
      v1: v1,
      state: s
    } do
      raises("expected a %Logex.Program{} from Logex.compile/2, got: :x", fn ->
        Edit.accept(opaque(:x), opaque(:y), opaque(nil))
      end)

      raises("expected a %Logex.Program{} from Logex.compile/2, got: :y", fn ->
        Edit.accept(v1, opaque(:y), opaque(nil))
      end)

      raises(
        "the candidate is `pump`, but the running program is `motor`: " <>
          "an edit keeps the program's name",
        fn -> Edit.accept(v1, c!(@motor, "pump"), opaque(nil)) end
      )

      # A host mistake comes before a refused candidate: the state is checked first.
      retyped = fn name ->
        @motor
        |> String.replace("var_output lamp bool", "var_output lamp dint")
        |> String.replace("ote lamp", "move 1 lamp")
        |> c!(name)
      end

      assert {:error, [%Diagnostic{stage: :edit}]} = Edit.accept(v1, retyped.("motor"), s)

      raises("this state is an instance of `motor`, not of `pump`", fn ->
        Edit.accept(c!(@motor, "pump"), retyped.("pump"), s)
      end)

      raises("state.now must be a non-negative integer of milliseconds, got: -1", fn ->
        Edit.accept(v1, retyped.("motor"), %{s | now: -1})
      end)
    end

    test "two unnamed programs are one name" do
      v1 = unnamed!("var_input go bool\nvar_output y bool\nxic go ote y")
      v2 = unnamed!("var_input go bool\nvar_output y bool\nvar k dint 4\nxic go ote y")
      state = Runtime.instance(v1)
      assert state.type == nil
      assert {:ok, edit, [{:added, "k", 4}]} = Edit.accept(v1, v2, state)
      assert {_, %Instance{env: %{"k" => 4}}, _} = Edit.test(edit, state)
    end

    test "a step takes an edit, then the state of the program it runs, then its stage", %{
      v1: v1,
      v2: v2,
      state: s
    } do
      edit = accept!(v1, v2, s)

      for step <- [:test, :untest, :assemble, :cancel] do
        raises("expected a %Logex.Edit{} from Logex.Edit.accept/3, got: :x", fn ->
          apply(Edit, step, [opaque(:x), opaque(nil)])
        end)

        raises("expected a %Logex.Edit{} from Logex.Edit.accept/3, got: nil", fn ->
          apply(Edit, step, [opaque(nil), s])
        end)
      end

      for f <- [&Edit.running/1, &Edit.stage/1] do
        raises("expected a %Logex.Edit{} from Logex.Edit.accept/3, got: %{stage: :testing}", fn ->
          f.(opaque(%{stage: :testing}))
        end)
      end

      # The state is checked before the stage, against the program the edit runs.
      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: nil", fn ->
        Edit.untest(edit, opaque(nil))
      end)

      raises("this state is an instance of `pump`, not of `motor`", fn ->
        Edit.assemble(edit, Runtime.instance(c!(@motor, "pump")))
      end)

      raises("state.switched must be true or false, got: nil", fn ->
        Edit.test(edit, %{s | switched: nil})
      end)
    end

    test "a step taken at the wrong stage", %{v1: v1, v2: v2, state: s} do
      accepted = accept!(v1, v2, s)
      {testing, s, _} = Edit.test(accepted, s)
      {untested, s, _} = Edit.untest(testing, s)

      for {edit, step, message} <- [
            {accepted, :untest, "untest takes an edit under test, but this one is accepted"},
            {accepted, :assemble, "assemble takes an edit under test, but this one is accepted"},
            {testing, :test,
             "test takes an edit accepted or untested, but this one is under test"},
            {testing, :cancel,
             "cancel takes an edit accepted or untested, but this one is under test"},
            {untested, :untest, "untest takes an edit under test, but this one is untested"},
            {untested, :assemble, "assemble takes an edit under test, but this one is untested"}
          ] do
        raises(message, fn -> apply(Edit, step, [edit, s]) end)
      end
    end

    test "running/1 and stage/1 say which program the host scans", %{v1: v1, v2: v2, state: s} do
      edit = accept!(v1, v2, s)
      assert {Edit.stage(edit), Edit.running(edit)} == {:accepted, v1}
      {edit, s, _} = Edit.test(edit, s)
      assert {Edit.stage(edit), Edit.running(edit)} == {:testing, v2}
      {edit, _s, _} = Edit.untest(edit, s)
      assert {Edit.stage(edit), Edit.running(edit)} == {:untested, v1}
    end
  end

  describe "state moves by name" do
    test "an added tag starts at its initial value, an added timer at its preset" do
      v1 = c!("var_input go bool\nvar_output y bool\nxic go ote y")

      v2 =
        c!(
          "var_input go bool\nvar_output y bool\nvar_output k dint 42\nvar t2 ton\n" <>
            "xic go ote y\nxic t2.dn move 7 k\nxic go ton t2 5000"
        )

      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      fresh = Runtime.instance(v2)
      assert report == [{:added, "k", 42}, {:added, "t2", fresh.env["t2"]}]
      assert %{"pre" => 5000, "dn" => 0} = fresh.env["t2"]
      assert state.env == %{fresh.env | "go" => 1, "y" => 1}
      assert {%{"y" => 1, "k" => 42}, state} = Runtime.scan(v2, state, 10)
      assert %{"pre" => 5000, "dn" => 0} = state.env["t2"]
    end

    test "at the first test, a tag the candidate adds starts so over what a plain swap left" do
      v0 = c!("var_input go bool\nvar k dint\nxic go move 9 k")
      v1 = c!("var_input go bool\nvar_output y bool\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output y bool\nvar_output k dint 42\nxic go ote y")
      {_, state} = run(v0, [{0, %{"go" => 1}}])
      # A plain swap, within the runtime's contract: v1 runs over v0's state, k kept.
      {_, state} = Runtime.scan(v1, state, 10)
      assert state.env["k"] == 9
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      {_edit, state, report} = Edit.test(edit, state)
      assert report == [{:added, "k", 42}] and report == forecast
      assert {%{"k" => 42}, _} = Runtime.scan(v2, state, 10)
    end

    test "a later test keeps what the first added, as logic left it" do
      v1 = c!("var_input go bool\nvar_output y bool\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output y bool\nvar k dint 42\nxic go ote y\nmove 7 k")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, _} = Edit.untest(edit, state)
      {edit, state, report} = Edit.test(edit, state)
      assert report == []
      assert state.env["k"] == 7
      {_program, state, report} = Edit.assemble(edit, state)
      assert report == [] and state.env["k"] == 7
    end

    test "at the first test, a value a plain swap left that does not fit its type starts " <>
           "again (decision 26)" do
      v0 =
        c!(
          "var_input go bool\nvar k dint\nvar b dint\nvar t1 ton\nvar_output n dint\n" <>
            "xic go move 7 k\nxic go move 5 b\nxic go ton t1 50"
        )

      # The plain swap keeps k's 7 under a timer, b's 5 under a bool, and t1's map under a
      # dint; a well-typed n is kept.
      v1 =
        c!(
          "var_input go bool\nvar k ton\nvar b bool\nvar t1 dint 3\nvar_output n dint\n" <>
            "xic go move 4 n"
        )

      v2 = String.replace(v1.source, "move 4 n", "move 4 n\nxic go ton k 5000\nxic b ote b")
      v2 = c!(v2)
      {_, state} = run(v0, [{0, %{"go" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      assert %{"k" => 7, "b" => 5, "t1" => %{}, "n" => 4} = state.env
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      {_edit, state, report} = Edit.test(edit, state)
      fresh = Runtime.instance(v2).env
      assert report == [{:added, "b", 0}, {:added, "k", fresh["k"]}, {:added, "t1", 3}]
      assert report == forecast
      assert %{"b" => 0, "t1" => 3, "n" => 4} = state.env
      assert %{"pre" => 5000} = state.env["k"]
    end

    test "a timer's map that a plain swap left without all its members does not fit" do
      # Over a bool, a member write makes a map of that member alone.
      v0 = c!("var_input go bool\nvar t1 bool\nxic go ote t1")
      v1 = c!("var_input go bool\nvar t1 ton\nxic go move 40 t1.pre")
      v2 = c!("var_input go bool\nvar t1 ton\nxic go move 40 t1.pre\nxic go ton t1 300")
      {_, state} = run(v0, [{0, %{"go" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      assert state.env["t1"] == %{"pre" => 40}
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      {_edit, state, report} = Edit.test(edit, state)
      assert report == [{:added, "t1", Runtime.instance(v2).env["t1"]}] and report == forecast
      assert %{"pre" => 300, "acc" => 0, "en" => 0} = state.env["t1"]
    end

    test "a kept timer fits, whatever values logic gave its members" do
      v1 = c!("var_input go bool\nvar_input sp dint\nvar t1 ton\nxio go move sp t1.pre")
      v2 = c!("var_input go bool\nvar_input sp dint\nvar t1 ton\nxic go ton t1 50")
      {_, state} = run(v1, [{0, %{"sp" => -5}}])
      assert state.env["t1"]["pre"] == -5

      # Kept, not started again: the ton the candidate adds then gives it its preset.
      assert {_, %Instance{env: %{"t1" => t1}}, [{:preset, "t1", {-5, 50}}]} =
               Edit.test(accept!(v1, v2, state), state)

      assert t1 == %{state.env["t1"] | "pre" => 50}
    end

    test "a value that does not fit is started only at the first test, and only for the " <>
           "candidate's tags" do
      # The plain swap leaves 7 under `b`, a bool of the original the candidate drops, and 9
      # under `k`, a timer of it: the first test leaves both alone, and so does the untest,
      # which starts nothing, and whose timer rules read no timer that is not a map.
      v0 = c!("var_input go bool\nvar b dint\nvar k dint\nxic go move 7 b\nxic go move 9 k")
      v1 = c!("var_input go bool\nvar b bool\nvar k ton\nvar_output y bool\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output y bool\nxic go ote y")
      {_, state} = run(v0, [{0, %{"go" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      assert {_, %Instance{env: %{"b" => 7, "k" => 9}}, []} = Edit.untest(edit, state)
    end

    test "a restart during the test drops what only the original declares, and untest " <>
           "starts it again" do
      v1 =
        c!(
          "var_input go bool\nvar_input jog bool\nvar_output lamp bool\nvar n dint 5\n" <>
            "( xic go | xic jog ) ote lamp\nmove 6 n"
        )

      v2 = c!("var_input go bool\nvar_output lamp bool\nxic go ote lamp")
      {_, state} = run(v1, [{0, %{"go" => 1, "jog" => 1}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      state = Runtime.restart(Edit.running(edit), state, :cold)
      refute Map.has_key?(state.env, "n") or Map.has_key?(state.env, "jog")
      {edit, state, report} = Edit.untest(edit, state)
      # A var_input it starts is an input: its value is the host's.
      assert report == [{:added, "n", 5}, {:input, "jog", 0}]
      assert Edit.stage(edit) == :untested
      assert {_, %{env: %{"n" => 6}}} = Runtime.scan(v1, state, 10)
    end

    test "a removed tag is kept, unused, through the test, so the original finds it at untest" do
      v1 =
        c!(
          "var_input go bool\nvar n dint 5\nvar_output lamp bool\nxic go move 6 n\nxic go ote lamp"
        )

      v2 = c!("var_input go bool\nvar_output lamp bool\nxic go ote lamp")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = Runtime.scan(v2, state, 10)
      assert state.env["n"] == 6
      {_edit, state, []} = Edit.untest(edit, state)
      assert state.env["n"] == 6
    end

    test "assemble prunes what only the original declares, cancel after an untest what " <>
           "only the candidate does, and cancel from accept changes nothing" do
      v1 =
        c!("var_input go bool\nvar_output lamp bool\nvar old dint 3\nxic go ote lamp\nmove 4 old")

      v2 = c!("var_input go bool\nvar_output lamp bool\nvar new dint 8\nxic go ote lamp")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      edit = accept!(v1, v2, state)
      assert Edit.cancel(edit, state) == {v1, state, []}

      # Not even an output the candidate drives and the original shows but does not drive.
      v3 = c!("var_input go bool\nvar_output lamp bool\nvar_output y bool\nxic go ote lamp")
      v4 = c!("var_input go bool\nvar_output lamp bool\nvar_output y bool\nxic go ote y")
      {_, s3} = run(v3, [{0, %{"go" => 1}}])
      {testing, s4, _} = Edit.test(accept!(v3, v4, s3), s3)
      assert {_, _, [{:held, "y", 0}]} = Edit.untest(testing, s4)
      assert Edit.cancel(accept!(v3, v4, s3), s3) == {v3, s3, []}

      {testing, tested, [{:added, "new", 8}]} = Edit.test(edit, state)
      assert {^v2, assembled, [{:pruned, "old", 4}]} = Edit.assemble(testing, tested)
      assert assembled == %{tested | env: Map.delete(tested.env, "old")}
      assert Enum.sort(Map.keys(assembled.env)) == Enum.sort(Map.keys(v2.tags))

      {untested, back, []} = Edit.untest(testing, tested)
      assert {^v1, cancelled, [{:pruned, "new", 8}]} = Edit.cancel(untested, back)
      assert cancelled == %{back | env: Map.delete(back.env, "new")}
      assert Enum.sort(Map.keys(cancelled.env)) == Enum.sort(Map.keys(v1.tags))
    end

    test "a switch sets the instance's switched and touches neither now nor first; a " <>
           "prune touches none of them" do
      v1 = c!(@motor)
      {_, state} = run(v1, [{0, %{"start" => 1}}, {10, %{}}])
      v2 = c!(String.replace(@motor, "var t1 ton", "var t1 ton\nvar k dint 1"))
      {edit, tested, _} = Edit.test(accept!(v1, v2, state), state)
      assert {tested.now, tested.first, tested.switched} == {10, false, true}
      {_, assembled, _} = Edit.assemble(edit, tested)
      assert {assembled.now, assembled.first, assembled.switched} == {10, false, true}
      {_, scanned} = Runtime.scan(v2, assembled, 10)
      assert scanned.switched == false

      fresh = Runtime.instance(v1)
      {_, untested, _} = Edit.untest(elem(Edit.test(accept!(v1, v2, fresh), fresh), 0), fresh)
      assert {untested.now, untested.first, untested.switched} == {0, true, true}
    end
  end

  describe "a var_input across a switch (decision 22)" do
    @seal "var_input start bool\nvar_output motor bool\n"
    @stop "var_input stop bool\n"

    test "one the candidate removes is unread at test, and live again at untest with the " <>
           "value the host last sent" do
      v1 = c!(@seal <> @stop <> "( xic start | xic motor ) xio stop ote motor")
      v2 = c!(@seal <> "( xic start | xic motor ) ote motor")

      {%{"motor" => 1}, state} =
        run(v1, [{0, %{"start" => 1, "stop" => 1}}, {10, %{"start" => 1, "stop" => 0}}])

      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:unread, "stop", 0}]

      # The host's duty under test: send only the running program's inputs.
      raises("input `stop` is not declared: the var_inputs are `start`", fn ->
        Runtime.put_inputs(v2, state, %{"stop" => 1})
      end)

      {edit, state, report} = Edit.untest(edit, state)
      assert report == [{:input, "stop", 0}]
      assert Edit.running(edit) == v1
      # The report tells the host to send it before the next scan.
      state = Runtime.put_inputs(v1, state, %{"stop" => 1})
      assert {%{"motor" => 0}, _} = Runtime.scan(v1, state, 10)
    end

    test "an added one reads 0 until the host sends it, and is reported once" do
      v1 = c!(@seal <> "xic start ote motor")
      v2 = c!(@seal <> "var_input jog bool\n( xic start | xic jog ) ote motor")
      {_, state} = run(v1, [{0, %{}}])
      {_edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:input, "jog", 0}]
      assert state.env["jog"] == 0
    end

    test "a section change keeps the value, and is reported as the input it becomes or " <>
           "stops being (decision 25)" do
      v1 = c!(@seal <> "var_input a bool\nvar b bool\nxic a ote motor\nxic start ote b")
      v2 = c!(@seal <> "var a bool\nvar_input b bool\nxic b ote motor\nxic start ote a")
      {_, state} = run(v1, [{0, %{"start" => 1, "a" => 1}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:input, "b", 1}, {:unread, "a", 1}]
      assert %{"a" => 1, "b" => 1} = state.env
      assert {_, _, [{:input, "a", 1}, {:unread, "b", 1}]} = Edit.untest(edit, state)
    end

    test "one the state lacks after a plain swap is unread at 0" do
      v0 = c!(@seal <> "xic start ote motor")
      v1 = c!(@seal <> @stop <> "xic start xio stop ote motor")
      v2 = c!(@seal <> "xic start ote motor")
      {_, state} = run(v0, [{0, %{"start" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      refute Map.has_key?(state.env, "stop")

      assert {_, %Instance{env: env}, [{:unread, "stop", 0}]} =
               Edit.test(accept!(v1, v2, state), state)

      refute Map.has_key?(env, "stop")
    end

    test "one the state lacks after a plain swap, that the candidate keeps as a var, is " <>
           "unread at the value the switch starts it at" do
      v0 = c!(@seal <> "xic start ote motor")
      v1 = c!(@seal <> @stop <> "xic start xio stop ote motor")
      v2 = c!(@seal <> "var stop bool 1\nxic start xio stop ote motor")
      {_, state} = run(v0, [{0, %{"start" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      refute Map.has_key?(state.env, "stop")

      # The report states the state it leaves: `stop` holds 1 after the test, not the 0 a
      # read of the state before the start rules would give.
      assert {_, %Instance{env: %{"stop" => 1}}, report} =
               Edit.test(accept!(v1, v2, state), state)

      assert report == [{:added, "stop", 1}, {:unread, "stop", 1}]
    end
  end

  describe "an output an edit leaves undriven holds its value, and is reported (F4)" do
    @out "var_input go bool\nvar_output y bool\n"

    test "one still declared but no longer written, at test and at assemble" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!(@out <> "var_output z bool\nxic go ote z")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "z", 0}, {:held, "y", 1}]
      {out, state} = Runtime.scan(v2, Runtime.put_inputs(v2, state, %{"go" => 0}), 10)
      assert out == %{"y" => 1, "z" => 0}
      assert {_, _, [{:held, "y", 1}]} = Edit.assemble(edit, state)
    end

    test "one that stops being a var_output holds what its point last received, though " <>
           "logic then writes it as a var" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!("var_input go bool\nvar y bool\nvar_output z bool\nxio go ote y\nxic y ote z")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "z", 0}, {:held, "y", 1}]
      {out, state} = Runtime.scan(v2, state, 10)
      assert out == %{"z" => 0} and state.env["y"] == 0
      assert {_, _, [{:held, "y", 1}]} = Edit.assemble(edit, state)
    end

    test "one that becomes a var_output no logic writes holds the state's value" do
      v1 = c!("var_input go bool\nvar_output y bool\nvar w bool\nxic go ote y\nxic go ote w")
      v2 = c!("var_input go bool\nvar y bool\nvar_output w bool\nxic go ote y")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:held, "w", 1}, {:held, "y", 1}]

      assert {%{"w" => 1}, state} =
               Runtime.scan(v2, Runtime.put_inputs(v2, state, %{"go" => 0}), 10)

      # After a restart the candidate shows w's initial value, and that is what it holds.
      state = Runtime.restart(v2, state, :cold)
      assert {_, _, [{:held, "w", 0}, {:held, "y", 1}]} = Edit.assemble(edit, state)
    end

    test "at untest, one the candidate added and drove; one never driven is never reported, " <>
           "though read" do
      v1 = c!(@out <> "var_output idle bool\nxic go xio idle ote y")
      v2 = c!(@out <> "var_output idle bool\nvar_output blip bool\nxic go ote y\nxic go ote blip")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, [{:added, "blip", 0}]} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, [{:held, "blip", 1}]} = Edit.untest(edit, state)
      assert {_, _, [{:held, "blip", 1}, {:pruned, "blip", 1}]} = Edit.cancel(edit, state)
    end

    test "one driven only in a group nested in another is driven" do
      v1 = c!(@out <> "var a bool\n( ( xic go ote y | xic a ) | xic a ) ote a")
      v2 = c!(@out <> "var a bool\nxic a ote a")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      assert {_, _, [{:held, "y", 1}]} = Edit.test(accept!(v1, v2, state), state)
      # And driven there, it is not held.
      assert {_, _, []} = Edit.test(accept!(v1, v1, state), state)
    end

    test "a restart does not make up a value: the recorded one stands, and nothing it " <>
           "dropped is pruned" do
      v1 = c!("var_input go bool\nvar_output run_lamp bool\nxic go ote run_lamp")
      v2 = c!("var_input go bool\nvar_output m bool\nxic go ote m")
      {_, state} = run(v1, [{0, %{"go" => 1}}])

      {edit, state, [{:added, "m", 0}, {:held, "run_lamp", 1}]} =
        Edit.test(accept!(v1, v2, state), state)

      state = Runtime.restart(Edit.running(edit), state, :cold)
      refute Map.has_key?(state.env, "run_lamp")
      assert {_, _, [{:held, "run_lamp", 1}]} = Edit.assemble(edit, state)
    end

    test "nothing is known of a point a restart cleared after the scan that showed it" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!(@out <> "var_output blip bool\nxic go ote y\nxic go ote blip")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {%{"blip" => 1}, state} = Runtime.scan(v2, state, 10)
      # Shown 1, then cleared: the point holds 1, which the state no longer says.
      state = Runtime.restart(v2, state, :cold)
      assert {_, _, []} = Edit.untest(edit, state)
      # A scan since the restart shows it again, so it is known.
      {%{"blip" => 1}, state} = Runtime.scan(v2, state, 10)
      assert {_, _, [{:held, "blip", 1}]} = Edit.untest(edit, state)
    end

    test "a restart since the last scan forgets what the record knew of a point" do
      v1 = c!("var_input go bool\nvar_output y bool 1\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output z bool\nxic go ote z")
      {_, state} = run(v1, [{0, %{"go" => 1}}])

      {edit, state, [{:added, "z", 0}, {:held, "y", 1}]} =
        Edit.test(accept!(v1, v2, state), state)

      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, _} = Edit.untest(edit, state)
      # The original shows y as 0, then a restart puts the state back at 1: the point holds
      # the 0, which neither the state nor the record says, so y is not reported.
      {%{"y" => 0}, state} = drive(v1, state, [{10, %{"go" => 0}}])
      state = Runtime.restart(v1, state, :cold)
      assert state.env["y"] == 1
      assert {_, _, [{:added, "z", 0}]} = Edit.test(edit, state)
    end

    test "with no scan since the last switch, the point is as that switch found it" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!("var_input go bool\nvar y bool\nvar_output z bool\nxio go ote y\nxic y ote z")
      {_, state} = run(v1, [{0, %{"go" => 1}}])

      {edit, state, [{:added, "z", 0}, {:held, "y", 1}]} =
        Edit.test(accept!(v1, v2, state), state)

      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, _} = Edit.untest(edit, state)
      assert state.env["y"] == 0
      # The original has not scanned since the untest, so the point still holds 1.
      assert {edit, state, [{:held, "y", 1}]} = Edit.test(edit, state)
      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, _} = Edit.untest(edit, state)
      {%{"y" => 1}, state} = Runtime.scan(v1, state, 10)
      {_, state} = Runtime.scan(v1, Runtime.put_inputs(v1, state, %{"go" => 0}), 10)
      # And once it has, the point holds what it showed last.
      assert {_, _, [{:held, "y", 0}]} = Edit.test(edit, state)
    end

    test "a restart after a switch, with no scan since, leaves the record standing at the " <>
           "next switch" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!(@out <> "var_output blip bool\nxic go ote y\nxic go ote blip")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {%{"blip" => 1}, state} = Runtime.scan(v2, state, 10)
      {edit, state, [{:held, "blip", 1}]} = Edit.untest(edit, state)
      {edit, state, []} = Edit.test(edit, state)
      # The restart clears the state, not the point: nothing has scanned since the
      # candidate showed blip as 1, so the point still holds it.
      state = Runtime.restart(Edit.running(edit), state, :cold)
      assert %Instance{switched: true, env: %{"blip" => 0}} = state
      assert {_, _, [{:held, "blip", 1}]} = Edit.untest(edit, state)
    end

    test "before any scan, a point no program has shown is not reported" do
      v1 = c!(@out <> "xic go ote y")
      v2 = c!(@out <> "var_output z bool\nvar w bool\nxic go ote w")
      fresh = Runtime.instance(v1)
      # y is still shown by the candidate, which holds it at the state's value.
      assert {:ok, _edit, [{:added, "w", 0}, {:added, "z", 0}, {:held, "y", 0}]} =
               Edit.accept(v1, v2, fresh)

      v3 = c!("var_input go bool\nvar_output z bool\nxic go ote z")
      assert {:ok, _edit, [{:added, "z", 0}]} = Edit.accept(v1, v3, fresh)
    end
  end

  describe "a changed initial value (decision 29)" do
    test "for a kept var or var_output, keeps the running value, is reported at each " <>
           "switch, and applies at a restart" do
      # A timer's preset is not the initial value of a bool or a dint.
      v1 =
        c!("var_input go bool\nvar_output sp dint 1200\nvar b bool\nvar t1 ton\nxic go ton t1 50")

      v2 =
        c!(
          "var_input go bool\nvar_output sp dint 900\nvar b bool 1\nvar t1 ton\nxic go ton t1 80"
        )

      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)

      assert report == [
               {:initial_changed, "b", {0, 1}},
               {:initial_changed, "sp", {1200, 900}},
               {:preset, "t1", {50, 80}}
             ]

      assert %{"sp" => 1200, "b" => 0} = state.env
      {edit, back, report} = Edit.untest(edit, state)

      assert report == [
               {:initial_changed, "b", {1, 0}},
               {:initial_changed, "sp", {900, 1200}},
               {:preset, "t1", {80, 50}}
             ]

      assert back.env == %{state.env | "t1" => %{state.env["t1"] | "pre" => 50}}
      {edit, state, _} = Edit.test(edit, back)
      assert {_, _, []} = Edit.assemble(edit, state)
      assert %{"sp" => 900, "b" => 1} = Runtime.restart(v2, state, :cold).env
    end

    test "is not reported for a tag the first test starts again, which :added reports" do
      p0 = c!("var x dint\nvar_output y bool\nmove 7 x")
      v1 = c!("var x bool\nvar_output y bool\nxic x ote y")
      v2 = c!("var x bool 1\nvar_output y bool\nxic x ote y")
      {_, state} = run(p0, [{0, %{}}])
      {_, state} = drive(v1, state, [{0, %{}}])
      assert {:ok, edit, [{:added, "x", 1}]} = Edit.accept(v1, v2, state)
      {edit, state, [{:added, "x", 1}]} = Edit.test(edit, state)
      assert {_, _, [{:initial_changed, "x", {1, 0}}]} = Edit.untest(edit, state)
    end

    test "is not reported for a var_input of the program started, whose value a restart keeps" do
      v1 = c!("var sp dint 100\nvar_output out dint\nmove sp out")
      v2 = c!("var_input sp dint\nvar_output out dint\nmove sp out")
      {_, state} = run(v1, [{0, %{}}])
      {edit, state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:input, "sp", 100}]
      assert Runtime.restart(v2, state, :cold).env["sp"] == 100

      assert {_, _, [{:initial_changed, "sp", {0, 100}}, {:unread, "sp", 100}]} =
               Edit.untest(edit, state)
    end

    test "is not reported for a tag only one program declares" do
      v1 = c!("var_input go bool\nvar_output sp dint 1200\nxic go move sp sp")
      v2 = c!("var_input go bool\nvar_output sq dint 900\nxic go move sq sq")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {_edit, _state, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "sq", 900}, {:held, "sp", 1200}]
    end
  end

  describe "a timer's .pre across a switch (decision 23, fix F1)" do
    @timed "var_input go bool\nvar_input w bool\nvar_input sp dint\nvar t1 ton\n" <>
             "xic w move sp t1.pre\n"

    test "follows the new preset where it still holds the old one, and untest gives it back" do
      v1 = c!(@timed <> "xic go ton t1 5000")
      v2 = c!(@timed <> "xic go ton t1 9000")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      assert forecast == [{:preset, "t1", {5000, 9000}}]
      {edit, state, ^forecast} = Edit.test(edit, state)
      assert state.env["t1"]["pre"] == 9000
      {_, state} = Runtime.scan(v2, state, 10)
      {edit, state, [{:preset, "t1", {9000, 5000}}]} = Edit.untest(edit, state)
      assert state.env["t1"]["pre"] == 5000

      assert {_, %Instance{env: %{"t1" => %{"pre" => 9000}}}, [{:preset, "t1", {5000, 9000}}]} =
               Edit.test(edit, state)
    end

    test "is kept where logic changed it, as the test finds it and not as accept did " <>
           "(decision 27)" do
      v1 = c!(@timed <> "xic go ton t1 5000")
      v2 = c!(@timed <> "xic go ton t1 9000")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {:ok, edit, [{:preset, "t1", {5000, 9000}}]} = Edit.accept(v1, v2, state)
      {_, state} = drive(v1, state, [{10, %{"w" => 1, "sp" => 7000}}, {10, %{"w" => 0}}])
      {_edit, state, report} = Edit.test(edit, state)
      assert report == [{:preset_kept, "t1", {7000, 9000}}]
      assert state.env["t1"]["pre"] == 7000
    end

    test "untest gives back exactly the .pre its test found, where the test moved none (F1)" do
      r =
        "var_input go bool\nvar_input up bool\nvar_output lamp bool\nvar t1 ton\n" <>
          "xic up move 8000 t1.pre\n"

      v1 = c!(r <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      v2 = c!(r <> "xic go ton t1 8000\nxic t1.dn ote lamp")
      {_, state} = run(v1, [{0, %{"go" => 1, "up" => 1}}, {10, %{"up" => 0}}, {6000, %{}}])
      assert %{"pre" => 8000, "acc" => 6010, "dn" => 0} = state.env["t1"]
      # Logic gave .pre the candidate's preset: the test moves nothing, and reports nothing.
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:preset_kept, "t1", {8000, 5000}}]
      assert state.env["t1"]["pre"] == 8000
      # The original's next scan, as if no edit had been taken: the lamp stays off.
      assert {%{"lamp" => 0}, _} = Runtime.scan(v1, state, 10)
    end

    test "a .pre logic changed since the last switch is not given back: the preset rules " <>
           "apply instead" do
      v1 = c!(@timed <> "xic go ton t1 5000")
      v2 = c!(@timed <> "xic go ton t1 9000")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, [{:preset, "t1", {5000, 9000}}]} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = drive(v2, state, [{10, %{"w" => 1, "sp" => 7000}}, {10, %{"w" => 0}}])
      {edit, state, report} = Edit.untest(edit, state)
      assert report == [{:preset_kept, "t1", {7000, 5000}}]
      assert state.env["t1"]["pre"] == 7000
      # What this untest found, the next test gives back.
      assert {_, _, [{:preset_kept, "t1", {7000, 9000}}]} = Edit.test(edit, state)
    end

    test "a timer whose ton the candidate removes keeps its .pre frozen (decision 23)" do
      e = "var_input go bool\nvar_output early bool\nvar t1 ton\nge t1.acc t1.pre ote early\n"
      v1 = c!(e <> "xic go ton t1 5000")
      v2 = c!(e)
      {%{"early" => 0}, state} = run(v1, [{0, %{"go" => 1}}, {3000, %{}}])
      assert state.env["t1"]["acc"] == 3000
      {_edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      assert state.env["t1"]["pre"] == 5000
      # At a .pre of 0 the candidate's first scan would turn `early` on.
      assert {%{"early" => 0}, _} = Runtime.scan(v2, state, 10)
    end

    test "a ton the switch restores, where logic changed the frozen .pre, takes its preset " <>
           "outright" do
      tb = "var_input go bool\nvar_input w bool\nvar_output y bool\nvar t1 ton\n"
      v1 = c!(tb <> "xic go ton t1 5000\nxic t1.dn ote y")
      v2 = c!(tb <> "xic w move 3000 t1.pre\nxic t1.dn ote y")
      {_, state} = run(v1, [{0, %{"go" => 1}}, {100, %{}}])
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = drive(v2, state, [{10, %{"w" => 1}}])
      assert state.env["t1"]["pre"] == 3000
      {_edit, untested, report} = Edit.untest(edit, state)
      assert report == [{:preset, "t1", {3000, 5000}}, {:resumed, "t1", 10}]
      assert untested == %{state | env: rebuilt(state.env, report), switched: true}
      assert %{"pre" => 5000, "last" => 110} = untested.env["t1"]
    end

    test "a ton removed, assembled and restored at a new preset takes it outright, as a " <>
           "restart would (decision 23)" do
      tb = "var_input go bool\nvar_output y bool\nvar t1 ton\nxic t1.dn ote y\n"
      v1 = c!(tb <> "xic go ton t1 5000")
      v2 = c!(tb)
      v3 = c!(tb <> "xic go ton t1 8000")
      {_, state} = run(v1, [{0, %{"go" => 1}}, {100, %{}}])
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {^v2, state, []} = Edit.assemble(edit, state)
      {_, state} = Runtime.scan(v2, state, 10)
      assert state.env["t1"]["pre"] == 5000
      {_edit, state, report} = Edit.test(accept!(v2, v3, state), state)
      assert report == [{:preset, "t1", {5000, 8000}}, {:resumed, "t1", 10}]
      assert state.env["t1"]["pre"] == Runtime.restart(v3, state, :cold).env["t1"]["pre"]
    end

    test "a ton the candidate adds on a timer no ton ran takes its preset outright, and " <>
           "untest gives back the .pre it found, with no forecast of .dn" do
      v1 = c!("var_input go bool\nvar_output y bool\nvar t1 ton\nxic t1.dn ote y")

      v2 =
        c!("var_input go bool\nvar_output y bool\nvar t1 ton\nxic go ton t1 300\nxic t1.dn ote y")

      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, [{:preset, "t1", {0, 300}}]} = Edit.test(accept!(v1, v2, state), state)
      {%{"y" => 0}, state} = Runtime.scan(v2, state, 10)
      assert %{"en" => 1, "dn" => 0, "acc" => 0} = state.env["t1"]
      # Back at 0, with .acc at it: .dn would rise, if a ton of the original counted it.
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:preset, "t1", {300, 0}}]
      assert state.env["t1"]["pre"] == 0
    end

    test "a later test gives a timer the original runs no ton on the .pre it had under the " <>
           "candidate (F1)" do
      timed = "var_output y bool\n" <> @timed
      v1 = c!(timed <> "xic t1.dn ote y")
      v2 = c!(timed <> "xic go ton t1 9000\nxic t1.dn ote y")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, [{:preset, "t1", {0, 9000}}]} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = drive(v2, state, [{10, %{"w" => 1, "sp" => 7000}}, {10, %{"w" => 0}}])
      # Frozen under the original, which runs no ton on it.
      {edit, state, []} = Edit.untest(edit, state)
      assert state.env["t1"]["pre"] == 7000
      assert {_, state, [{:preset_kept, "t1", {7000, 9000}}]} = Edit.test(edit, state)
      assert state.env["t1"]["pre"] == 7000
    end

    test "untest gives back the .pre of a timer the candidate drops, though logic changed it" do
      d = "var_input go bool\nvar_input w bool\nvar_output y bool\n"
      v1 = c!(d <> "var t1 ton\nxic w move 7000 t1.pre\nxic go ton t1 5000\nxic go ote y")
      v2 = c!(d <> "xic go ote y")
      {_, state} = run(v1, [{0, %{"go" => 1, "w" => 1}}, {10, %{"w" => 0}}])
      assert state.env["t1"]["pre"] == 7000
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = Runtime.scan(v2, state, 10)
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:preset_kept, "t1", {7000, 5000}}, {:resumed, "t1", 10}]
      assert state.env["t1"]["pre"] == 7000
    end

    test "a timer the candidate removes is kept, unused, through the test, and the original " <>
           "finds it as it was" do
      v1 =
        c!(
          "var_input go bool\nvar_output lamp bool\nvar t1 ton\n" <>
            "xic go ton t1 5000\nxic t1.dn ote lamp"
        )

      v2 = c!("var_input go bool\nvar_output lamp bool\nxic go ote lamp")
      {_, state} = run(v1, [{0, %{"go" => 1}}, {10, %{}}])
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = Runtime.scan(v2, state, 10)
      assert %{"pre" => 5000, "acc" => 10, "en" => 1} = state.env["t1"]
      {_edit, state, [{:resumed, "t1", 10}]} = Edit.untest(edit, state)
      {%{"lamp" => 0}, state} = Runtime.scan(v1, state, 10)
      assert %{"pre" => 5000, "acc" => 20, "dn" => 0} = state.env["t1"]
    end
  end

  describe "a timer's .dn after its .pre moves (fix F6)" do
    defp lamp(preset),
      do:
        c!(
          "var_input go bool\nvar_input sp dint\nvar_output lamp bool\nvar t1 ton\n" <>
            "xic go ton t1 #{preset}\nxic t1.dn ote lamp"
        )

    test "a preset raised over a done timer's .acc drops .dn at the next scan with its rung " <>
           "true, and the report says so" do
      {%{"lamp" => 1}, state} = run(lamp(1000), [{0, %{"go" => 1}}, {1500, %{}}])
      assert %{"acc" => 1000, "dn" => 1} = state.env["t1"]
      {:ok, edit, forecast} = Edit.accept(lamp(1000), lamp(5000), state)
      assert forecast == [{:dn_drops, "t1", {1000, 5000}}, {:preset, "t1", {1000, 5000}}]
      {edit, tested, ^forecast} = Edit.test(edit, state)
      assert {%{"lamp" => 0}, scanned} = Runtime.scan(lamp(5000), tested, 10)
      assert %{"acc" => 1010, "dn" => 0} = scanned.env["t1"]
      # Given back with no scan between, at its .acc: still done, so no news of .dn.
      assert {_, _, [{:preset, "t1", {5000, 1000}}]} = Edit.untest(edit, tested)
    end

    test "unless .pre - .acc ms have passed by that scan" do
      {_, state} = run(lamp(1000), [{0, %{"go" => 1}}, {1500, %{}}])

      {_edit, state, [{:dn_drops, "t1", {1000, 1005}}, {:preset, "t1", {1000, 1005}}]} =
        Edit.test(accept!(lamp(1000), lamp(1005), state), state)

      assert {%{"lamp" => 0}, _} = Runtime.scan(lamp(1005), state, 4)
      assert {%{"lamp" => 1}, _} = Runtime.scan(lamp(1005), state, 5)
    end

    test "a preset lowered under a timing timer's .acc raises .dn at that scan; lowered on " <>
           "a done timer, .dn stays" do
      {_, timing} = run(lamp(5000), [{0, %{"go" => 1}}, {2000, %{}}])
      {_edit, state, report} = Edit.test(accept!(lamp(5000), lamp(1000), timing), timing)
      assert report == [{:dn_rises, "t1", {2000, 1000}}, {:preset, "t1", {5000, 1000}}]
      assert {%{"lamp" => 1}, state} = Runtime.scan(lamp(1000), state, 0)
      assert %{"dn" => 1, "acc" => 1000} = state.env["t1"]

      {_, done} = run(lamp(5000), [{0, %{"go" => 1}}, {6000, %{}}])

      assert {_, _, [{:preset, "t1", {5000, 1000}}]} =
               Edit.test(accept!(lamp(5000), lamp(1000), done), done)
    end

    test "is not forecast for an idle timer, which starts timing against whatever .pre it has" do
      {_, idle} = run(lamp(5000), [{0, %{"go" => 0}}])
      assert %{"en" => 0, "dn" => 0, "acc" => 0} = idle.env["t1"]

      assert {_, _, [{:preset, "t1", {5000, 0}}]} =
               Edit.test(accept!(lamp(5000), lamp(0), idle), idle)
    end

    test "counts a negative .acc as 0, as ton does" do
      neg = fn preset ->
        c!(
          "var_input go bool\nvar_input sp dint\nvar t1 ton\n" <>
            "xic go ton t1 #{preset}\nxic go move sp t1.acc"
        )
      end

      {_, state} = run(neg.(5000), [{0, %{"go" => 1, "sp" => -5}}, {10, %{}}])
      assert %{"acc" => -5, "dn" => 0, "en" => 1} = state.env["t1"]
      {_edit, state, report} = Edit.test(accept!(neg.(5000), neg.(0), state), state)
      assert report == [{:dn_rises, "t1", {0, 0}}, {:preset, "t1", {5000, 0}}]
      {_, state} = Runtime.scan(neg.(0), state, 10)
      assert state.env["t1"]["dn"] == 1
    end
  end

  describe "a timer the switch gives back its ton resumes from the switch (§4.9's Resume rule)" do
    @back "var_input go bool\nvar_output lamp bool\nvar t1 ton\n"

    test "so the time no ton ran it is not caught up" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {990, %{}}])
      assert %{"acc" => 990, "en" => 1} = state.env["t1"]
      {edit, state, []} = Edit.test(accept!(b1, b2, state), state)
      {_, state} = drive(b2, state, List.duplicate({1000, %{}}, 58))
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:resumed, "t1", 58_000}]
      assert state.env["t1"]["last"] == state.now
      {%{"lamp" => 0}, state} = Runtime.scan(b1, state, 10)
      assert %{"acc" => 1000, "dn" => 0} = state.env["t1"]
    end

    test "and so does one the candidate added, frozen while the original ran" do
      v1 = c!("var_input go bool\nvar_output y bool\nxic go ote y")
      v2 = c!("var_input go bool\nvar_output y bool\nvar t2 ton\nxic go ote y\nxic go ton t2 900")
      {_, state} = run(v1, [{0, %{"go" => 1}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = drive(v2, state, List.duplicate({10, %{}}, 3))
      {edit, state, []} = Edit.untest(edit, state)
      {_, state} = drive(v1, state, List.duplicate({10, %{}}, 50))
      {_edit, state, report} = Edit.test(edit, state)
      assert report == [{:resumed, "t2", 500}]
      {_, state} = Runtime.scan(v2, state, 10)
      assert state.env["t2"]["acc"] == 30
    end

    test "and an untest with no scan since gives the resume back, so a plain swap after " <>
           "catches up as it would have (F11)" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {1000, %{}}])
      {edit, state, _} = Edit.test(accept!(b1, b2, state), state)
      {^b2, state, _} = Edit.assemble(edit, state)
      {_, frozen} = Runtime.scan(b2, state, 3000)
      assert %{"en" => 1, "last" => 1000} = frozen.env["t1"]
      {edit, tested, [{:resumed, "t1", 3000}]} = Edit.test(accept!(b2, b1, frozen), frozen)
      {edit, untested, report} = Edit.untest(edit, tested)
      assert report == [{:resume_undone, "t1", 3000}]
      assert untested == %{tested | env: rebuilt(tested.env, report)}
      assert untested.env == frozen.env
      {^b2, cancelled, []} = Edit.cancel(edit, untested)
      {_, cancelled} = Runtime.scan(b2, cancelled, 1000)
      {_, frozen} = Runtime.scan(b2, frozen, 1000)
      assert cancelled == frozen
      assert {%{"lamp" => 1}, _} = Runtime.scan(b1, cancelled, 1000)
    end

    test "but not after a scan of the program the test started" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {1000, %{}}])
      {edit, state, _} = Edit.test(accept!(b1, b2, state), state)
      {^b2, state, _} = Edit.assemble(edit, state)
      {_, state} = Runtime.scan(b2, state, 3000)
      {edit, state, [{:resumed, "t1", 3000}]} = Edit.test(accept!(b2, b1, state), state)
      {_, state} = Runtime.scan(b1, state, 0)
      assert {_, %{env: %{"t1" => %{"last" => 4000}}}, []} = Edit.untest(edit, state)
    end

    test "nor after a restart of it, which started the timer again" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {1000, %{}}])
      {edit, state, _} = Edit.test(accept!(b1, b2, state), state)
      {^b2, state, _} = Edit.assemble(edit, state)
      {_, state} = Runtime.scan(b2, state, 3000)
      {edit, state, [{:resumed, "t1", 3000}]} = Edit.test(accept!(b2, b1, state), state)
      state = Runtime.restart(b1, state, :cold)
      assert {_, ^state, []} = Edit.untest(edit, state)
    end

    test "but not one that was not timing when it last ran" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 0}}, {10, %{}}])
      {edit, state, []} = Edit.test(accept!(b1, b2, state), state)
      {_, state} = drive(b2, state, List.duplicate({10, %{}}, 5))
      assert {_, _, []} = Edit.untest(edit, state)
    end

    test "nor one a ton ran at the last scan: a switch with no scan since resumes nothing" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {10, %{}}])
      {edit, state, []} = Edit.test(accept!(b1, b2, state), state)
      assert {_, _, []} = Edit.untest(edit, state)
    end

    test "nor one the program started runs no ton on" do
      b1 = c!(@back <> "xic go ton t1 5000\nxic t1.dn ote lamp")
      b2 = c!(@back <> "xic t1.dn ote lamp")
      b3 = c!(@back <> "var_output z bool\nxic t1.dn ote lamp\nxic go ote z")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {10, %{}}])
      {edit, state, []} = Edit.test(accept!(b1, b2, state), state)
      {^b2, state, []} = Edit.assemble(edit, state)
      {_, state} = Runtime.scan(b2, state, 10)
      assert %{"en" => 1, "last" => 10} = state.env["t1"]
      assert {_, _, [{:added, "z", 0}]} = Edit.test(accept!(b2, b3, state), state)
    end
  end

  describe "an ons across a switch (decision 21; fixes F2, F3, F7)" do
    @d "var_input go bool\nvar_input a bool\nvar_input b bool\nvar_input q bool\nvar s9 bool\n" <>
         "var_output pulse bool\nvar_output y bool\n"

    # Runs `src1` through `before`, tests `src2` over its state, then drives `src2` through
    # `after_`: the last outputs, the test's report, and its state.
    defp switched(src1, src2, before, after_) do
      v1 = c!(@d <> src1)
      v2 = c!(@d <> src2)
      {_, state} = run(v1, before)
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      {_edit, tested, report} = Edit.test(edit, state)
      assert report == forecast
      {out, _} = drive(v2, tested, after_)
      {out, report, tested}
    end

    test "one the edit adds on a tag that already exists does not fire on the next scan " <>
           "(decision 21), and the next real edge fires" do
      src1 = "xio go ote s9\nxic a ote pulse"
      src2 = "xic go ons s9 ote pulse"
      before = [{0, %{"go" => 1}}, {10, %{}}]

      assert {%{"pulse" => 0}, [{:ons_blocked, "s9", 0}], %Instance{ons_blocked: ["s9"]}} =
               switched(src1, src2, before, [{10, %{}}])

      assert {%{"pulse" => 1}, _, _} =
               switched(src1, src2, before, [{10, %{}}, {10, %{"go" => 0}}, {10, %{"go" => 1}}])
    end

    test "one on a storage bit the edit adds is blocked too, and reported at the bit's " <>
           "initial value" do
      src2 = "var s8 bool 1\nxic go ons s8 ote pulse"

      assert {%{"pulse" => 0}, report, %Instance{ons_blocked: ["s8"]}} =
               switched("xic go ote y", src2, [{0, %{"go" => 1}}], [{10, %{}}])

      assert report == [{:added, "s8", 1}, {:held, "y", 1}, {:ons_blocked, "s8", 1}]
    end

    test "nor one whose condition the edit changed (decision 21), which fires on the next " <>
           "real edge" do
      src1 = "xic a ons s9 ote pulse\nxic b ote y"
      src2 = "xic b ons s9 ote pulse\nxic b ote y"
      before = [{0, %{"b" => 1}}, {50, %{}}]

      assert {%{"pulse" => 0}, [{:ons_blocked, "s9", 0}], _} =
               switched(src1, src2, before, [{10, %{}}])

      assert {%{"pulse" => 1}, _, _} =
               switched(src1, src2, before, [{10, %{}}, {10, %{"b" => 0}}, {10, %{"b" => 1}}])
    end

    test "one the edit leaves alone keeps a real edge on the switch scan, though its rung " <>
           "moved" do
      for src2 <- ["xic go ons s9 ote pulse\nxic b ote y", "xic b ote y\nxic go ons s9 ote pulse"] do
        assert {%{"pulse" => 1}, [], %Instance{ons_blocked: []}} =
                 switched(
                   "xic go ons s9 ote pulse\nxic a ote y",
                   src2,
                   [{0, %{}}, {10, %{}}],
                   [{10, %{"go" => 1}}]
                 )
      end
    end

    test "no switch writes a storage bit, so a rung that reads one sees no phantom write" do
      assert {%{"y" => 0, "pulse" => 0}, [{:ons_blocked, "s9", 0}], %Instance{env: env}} =
               switched(
                 "xic a ons s9 ote pulse",
                 "xic s9 ote y\nxic b ons s9 ote pulse",
                 [{0, %{}}, {10, %{}}],
                 [{10, %{"b" => 1}}]
               )

      assert env["s9"] == 0
    end

    test "untest blocks one the candidate changed, the candidate having last scanned" do
      v1 = c!(@d <> "xic a ons s9 ote pulse")
      v2 = c!(@d <> "xic b ons s9 ote pulse")
      {_, state} = run(v1, [{0, %{}}, {10, %{}}])
      {edit, state, _} = Edit.test(accept!(v1, v2, state), state)
      {_, state} = drive(v2, state, [{10, %{}}])
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:ons_blocked, "s9", 0}]
      assert {%{"pulse" => 0}, state} = drive(v1, state, [{10, %{"a" => 1}}])
      assert {%{"pulse" => 1}, _} = drive(v1, state, [{10, %{"a" => 0}}, {10, %{"a" => 1}}])
    end

    test "a test then an untest with no scan between blocks nothing at the untest, so the " <>
           "original loses no real edge (fix F3)" do
      v1 = c!(@d <> "xic a ons s9 ote pulse")
      v2 = c!(@d <> "xic b ons s9 ote pulse")
      {_, state} = run(v1, [{0, %{}}, {10, %{}}])
      {edit, tested, [{:ons_blocked, "s9", 0}]} = Edit.test(accept!(v1, v2, state), state)
      {edit, state, report} = Edit.untest(edit, tested)
      assert report == [] and state.ons_blocked == []
      assert {%{"pulse" => 1}, _} = drive(v1, state, [{10, %{"a" => 1}}])

      # Nor a test after an untest with no scan between, where the candidate last scanned:
      # its storage bit is as it left it.
      {edit, state, _} = Edit.test(edit, state)
      {_, state} = drive(v2, state, [{10, %{}}])
      {edit, state, [{:ons_blocked, "s9", 0}]} = Edit.untest(edit, state)
      {_edit, state, report} = Edit.test(edit, state)
      assert report == [] and state.ons_blocked == []
      assert {%{"pulse" => 1}, _} = drive(v2, state, [{10, %{"b" => 1}}])
    end

    test "a block no scan has used survives a second edit, wherever the program started " <>
           "still has that ons (fix F2)" do
      decl =
        "var_input go bool\nvar_output q bool\nvar s1 bool\nvar s2 bool\nvar s3 bool\n" <>
          "var_output p1 bool\nvar_output p2 bool\nvar_output p3 bool\nxic go ote q\n"

      o = c!(decl)
      c1 = c!(decl <> "xic go ons s1 ote p1\nxic go ons s3 ote p3")
      {_, state} = run(o, [{0, %{"go" => 1}}, {10, %{}}])
      {edit, state, _} = Edit.test(accept!(o, c1, state), state)
      {^c1, state, _} = Edit.assemble(edit, state)
      assert state.ons_blocked == ["s1", "s3"]

      # The second edit adds an ons on s2 and changes s3's: each bit is listed once.
      c2 = c!(decl <> "xic go ons s1 ote p1\nxic go ons s2 ote p2\nxic q ons s3 ote p3")
      {edit, tested, report} = Edit.test(accept!(c1, c2, state), state)
      assert for({:ons_blocked, bit, 0} <- report, do: bit) == ["s1", "s2", "s3"]
      assert tested.ons_blocked == ["s1", "s2", "s3"]
      assert {%{"p1" => 0, "p2" => 0, "p3" => 0}, _} = Runtime.scan(c2, tested, 10)

      # Given back with no scan, the untest leaves the list the test found.
      assert {_, %Instance{ons_blocked: ["s1", "s3"]}, _} = Edit.untest(edit, tested)

      # A pending bit the program started has no ons on is dropped.
      c3 = c!(decl <> "xic go ons s1 ote p1")
      {_edit, tested, report} = Edit.test(accept!(c1, c3, state), state)
      assert for({:ons_blocked, bit, _} <- report, do: bit) == ["s1"]
      assert tested.ons_blocked == ["s1"]
    end

    test "one whose storage bit the program that last scanned also writes another way is " <>
           "blocked (fix F7)" do
      v1 = c!(@d <> "xic a ons s9 ote pulse")
      v2 = c!(@d <> "xic a ons s9 ote pulse\nxic q otu s9")
      assert Enum.any?(v2.warnings, &(&1.message =~ "the one-shot then fires on the wrong scans"))
      {_, state} = run(v1, [{0, %{"a" => 1, "q" => 1}}, {10, %{}}])
      # The original writes s9 through its ons alone, so the test blocks nothing.
      {edit, state, []} = Edit.test(accept!(v1, v2, state), state)
      {%{"pulse" => 0}, state} = drive(v2, state, [{10, %{}}])
      assert state.env["s9"] == 0
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:ons_blocked, "s9", 0}]
      # a has been 1 throughout: no real edge, so no pulse.
      assert {%{"pulse" => 0}, _} = drive(v1, state, [{10, %{}}])
    end
  end

  describe "the report" do
    test "is sorted, past the 32 keys where a map stops being" do
      many = Enum.map_join(1..40, fn i -> "var x#{i} dint #{i}\n" end)
      m1 = c!("var a bool\nxic a ote a", "many")

      m2 =
        c!(
          many <>
            "var a bool\nxic a ote a\n" <> Enum.map_join(1..40, "\n", &"xic a move x#{&1} x#{&1}"),
          "many"
        )

      state = Runtime.instance(m1)
      {_edit, _state, report} = Edit.test(accept!(m1, m2, state), state)
      assert length(report) == 40
      assert report == Enum.sort(report)
    end

    test "its writes, applied to the state before the step, give the state after it" do
      v1 = c!(@motor)

      v2 =
        @motor
        |> String.replace("var_output lamp bool", "var_input jog bool\nvar k dint 3")
        |> String.replace("xic motor ote lamp\n", "")
        |> c!()

      {_, state} = run(v1, [{0, %{"start" => 1}}])
      {edit, tested, report} = Edit.test(accept!(v1, v2, state), state)
      assert report == [{:added, "k", 3}, {:held, "lamp", 1}, {:input, "jog", 0}]
      assert tested == %{state | env: rebuilt(state.env, report), switched: true}
      {_, assembled, report} = Edit.assemble(edit, tested)
      assert report == [{:held, "lamp", 1}, {:pruned, "lamp", 1}]
      assert assembled == %{tested | env: rebuilt(tested.env, report)}
    end
  end

  defp rebuilt(env, report),
    do:
      Enum.reduce(report, env, fn
        {kind, name, value}, env when kind in [:added, :input] -> Map.put(env, name, value)
        {:preset, name, {_from, to}}, env -> put_in(env, [name, "pre"], to)
        {:resumed, name, gap}, env -> update_in(env, [name, "last"], &(&1 + gap))
        {:resume_undone, name, gap}, env -> update_in(env, [name, "last"], &(&1 - gap))
        {:pruned, name, _value}, env -> Map.delete(env, name)
        _fact, env -> env
      end)

  # F16: accept builds its plans once, linear in the two programs, and a switch and a prune
  # are linear too. Counted in reductions rather than time, as logex_test.exs counts a
  # compile, and the least of three counts.
  describe "growth (F16)" do
    defp edited(n) do
      o =
        Enum.map_join(1..n, "\n", fn i ->
          "var_input i#{i} bool\nvar_output o#{i} bool\nvar_output k#{i} dint 1\nvar t#{i} ton\n" <>
            "var s#{i} bool\nvar u#{i} bool"
        end) <>
          "\n" <>
          Enum.map_join(1..n, "\n", fn i ->
            "xic i#{i} ote o#{i}\nxic i#{i} move 5 k#{i}\nxic i#{i} ons s#{i} move 7 k#{i}\n" <>
              "xic i#{i} ons u#{i} move 8 k#{i}\nxic i#{i} ton t#{i} 50"
          end)

      c =
        Enum.map_join(1..n, "\n", fn i ->
          "var_input i#{i} bool\nvar_input j#{i} bool\nvar_output k#{i} dint 2\n" <>
            "var t#{i} ton\nvar a#{i} dint 4\nvar s#{i} bool\nvar u#{i} bool"
        end) <>
          "\n" <>
          Enum.map_join(1..n, "\n", fn i ->
            "xic j#{i} move 6 k#{i}\nxic i#{i} move a#{i} a#{i}\nxic j#{i} ons s#{i} move 7 k#{i}\n" <>
              "xic i#{i} ons u#{i} move 8 k#{i}\nxic i#{i} ton t#{i} 60"
          end)

      {c!(o, "big"), c!(c, "big")}
    end

    defp reductions_to_edit({original, candidate}) do
      {_, state} = Runtime.scan(original, Runtime.instance(original))

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, edit, _} = Edit.accept(original, candidate, state)
          {edit, s, _} = Edit.test(edit, state)
          {edit, s, _} = Edit.untest(edit, s)
          {edit, s, _} = Edit.test(edit, s)
          {_, _, report} = Edit.assemble(edit, s)
          {:reductions, later} = Process.info(self(), :reductions)
          assert length(report) > 0
          later - before
        end
      )
    end

    # At 500 and 2,000 of each tag a linear edit grows about 4x; one that walks a list for
    # every tag grows about 16x. Every timer's preset changes, so each switch moves every
    # `.pre`, and the untest and second test give each back from the record; and every
    # program has two `ons` per input, one whose rung the candidate changes, which each
    # test blocks, and one it leaves alone.
    test "accept and its steps stay linear in the program's size" do
      ratio = reductions_to_edit(edited(2000)) / reductions_to_edit(edited(500))
      assert ratio < 6, "4x the tags took #{Float.round(ratio, 1)}x the reductions"
    end

    defp deep(depth) do
      nest =
        Enum.reduce(1..depth, "xic a ons s ote y", fn _, inner ->
          "( #{inner} | xic b ote z ) xic a"
        end)

      decl = "var a bool\nvar b bool\nvar s bool\nvar_output y bool\nvar_output z bool\n"
      {c!(decl <> nest <> " ote b", "deep"), c!(decl <> "xic a ote b", "deep")}
    end

    # At 500 and 8,000 levels a linear walk grows about 16x; one that copies what it found
    # in a group at every level grows 20x or more (CONTRIBUTING.md).
    test "accept stays linear in the depth of nesting" do
      ratio = reductions_to_edit(deep(8000)) / reductions_to_edit(deep(500))
      assert ratio < 18.5, "16x the depth took #{Float.round(ratio, 1)}x the reductions"
    end

    # A program of n rungs on `go`, edited to one whose every rung gains a one-shot, all of
    # which the test blocks: the reductions of the scan after the switch, with `go` set so
    # that every `ons` is energised and looks its bit up in the block list.
    defp reductions_to_scan_blocked(n) do
      decl =
        "var_input go bool\n" <> Enum.map_join(1..n, "\n", &"var s#{&1} bool\nvar p#{&1} bool")

      original = c!(decl <> "\n" <> Enum.map_join(1..n, "\n", &"xic go ote p#{&1}"), "big")

      candidate =
        c!(decl <> "\n" <> Enum.map_join(1..n, "\n", &"xic go ons s#{&1} ote p#{&1}"), "big")

      {_, state} = Runtime.scan(original, Runtime.instance(original))
      {:ok, edit, _} = Edit.accept(original, candidate, state)
      {_edit, state, _report} = Edit.test(edit, state)
      assert length(state.ons_blocked) == n
      state = Runtime.put_inputs(candidate, state, %{"go" => 1})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {_, %Instance{env: env}} = Runtime.scan(candidate, state, 10)
          {:reductions, later} = Process.info(self(), :reductions)
          assert env["s#{n}"] == 1 and env["p#{n}"] == 0
          later - before
        end
      )
    end

    # At 500 and 8,000 one-shots a scan that looks each blocked bit up grows 16.4x to 17.9x
    # over 48 runs on Elixir 1.20.4; one that walks the block list for every `ons`, as the
    # scan did before the review of OE-1, grows 65.4x to 65.8x over 10. The figure moves by
    # up to 9% from run to run, with garbage collection, so the bound is a third above the
    # highest run, where 18.5, the bound this test landed with, was 3% above it, and still
    # a third of the walk's lowest.
    test "the scan after a switch stays linear in the one-shots it blocks" do
      ratio = reductions_to_scan_blocked(8000) / reductions_to_scan_blocked(500)
      assert ratio < 24, "16x the one-shots took #{Float.round(ratio, 1)}x the reductions"
    end

    # Three versions of n one-shots: the first edit changes every `ons` rung and is kept
    # with no scan after, so its n blocks are still pending; the second leaves those rungs
    # alone and changes one other, so only the pending path keeps the blocks (F2).
    defp pending(n) do
      decl =
        "var_input a bool\nvar_input b bool\nvar_output q bool\n" <>
          Enum.map_join(1..n, "\n", &"var s#{&1} bool\nvar_output p#{&1} bool")

      version = fn edge, other ->
        decl <>
          "\nxic #{other} ote q\n" <>
          Enum.map_join(1..n, "\n", &"xic #{edge} ons s#{&1} ote p#{&1}")
      end

      {c!(version.("a", "a"), "big"), c!(version.("b", "a"), "big"),
       c!(version.("b", "b"), "big")}
    end

    defp reductions_to_second_edit({original, first, second}) do
      {_, state} = Runtime.scan(original, Runtime.instance(original))
      {edit, state, _} = Edit.test(accept!(original, first, state), state)
      {^first, state, _} = Edit.assemble(edit, state)
      assert state.ons_blocked != []

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, edit, _} = Edit.accept(first, second, state)
          {edit, s, report} = Edit.test(edit, state)
          {edit, s, _} = Edit.untest(edit, s)
          {edit, s, _} = Edit.test(edit, s)
          {_, _, _} = Edit.assemble(edit, s)
          {:reductions, later} = Process.info(self(), :reductions)
          assert for({:ons_blocked, bit, _} <- report, do: bit) == state.ons_blocked
          later - before
        end
      )
    end

    # Every switch of a second edit taken before any scan filters the first edit's pending
    # bits by its plan's one-shots. At 500 and 8,000 bits that grows 16.2x to 17.5x, over
    # 48 runs on Elixir 1.20.4, its sort being n log n. A filter that walks a list of the
    # one-shots, built once, for every bit grows 36.5x to 38.3x over 10, the lowest of the
    # quadratic filters measured; one that builds that list again for every bit, 108x to
    # 116x. The bound is a third above the highest run, and the list walk's lowest is half
    # as much again as the bound. At 500 and 2,000 the two quadratic filters grow 5.1x and
    # 6.8x, too near a linear switch's 4x.
    test "a second edit before any scan stays linear in the bits still pending (F2)" do
      ratio = reductions_to_second_edit(pending(8000)) / reductions_to_second_edit(pending(500))
      assert ratio < 24, "16x the pending bits took #{Float.round(ratio, 1)}x the reductions"
    end
  end

  describe "the labels this work cites" do
    @root Path.expand("../..", __DIR__)

    # The code, the tests and CLAUDE.md cite decisions and fixes by the names
    # docs/organisation.md §7 gives them, a number for a decision and F and a number for a
    # fix, and cite them only where §7 defines that number. A label only the design pass's
    # own notes define, a lettered hazard or a numbered review finding, cannot be resolved
    # from the repository, so none may be cited: a hazard in the singular or the plural,
    # its letter bare or in brackets, and R and a number. A decision is checked by its
    # number alone, since the design decisions of PLAN.md M1-6, cited in places, share
    # §7's numbers; the other labels of PLAN.md and of commit messages are not checked.
    test "are only those docs/organisation.md defines" do
      [_, rest] =
        String.split(File.read!(Path.join(@root, "docs/organisation.md")), "\n## 7. Decisions\n")

      [seven | _] = String.split(rest, "\n## 8. ")
      decisions = numbered(~r/^(\d+)\. \*\*/m, seven)
      fixes = numbered(~r/^- \*\*F(\d+)\.\*\*/m, seven)
      assert decisions != [] and decisions == Enum.to_list(1..length(decisions))
      assert fixes != [] and fixes == Enum.to_list(1..length(fixes))

      files =
        Path.wildcard(Path.join(@root, "{lib,test}/**/*.{ex,exs}")) ++
          [Path.join(@root, "CLAUDE.md")]

      cited =
        for file <- files,
            text = File.read!(file),
            label <- refused(text) ++ undefined(text, decisions, fixes),
            do: {Path.relative_to(file, @root), label}

      assert cited == []
    end

    defp numbered(regex, text),
      do: Enum.sort(for [_, n] <- Regex.scan(regex, text), do: String.to_integer(n))

    defp refused(text),
      do: for([label] <- Regex.scan(~r/\b[Hh]azards? \(?[A-Z]\d?\b|\bR\d+\b/, text), do: label)

    # "decision 21", "decisions 24 and 28", "decisions 21–29", over a line break too.
    defp undefined(text, decisions, fixes) do
      list = ~r/\b[Dd]ecisions? (\d+(?:(?:\s*[–,]\s*|\s+and\s+)(?:#\s+)?\d+)*)/u

      for(
        [label, numbers] <- Regex.scan(list, text),
        [n] <- Regex.scan(~r/\d+/, numbers),
        String.to_integer(n) not in decisions,
        do: label
      ) ++
        for [label, n] <- Regex.scan(~r/\bF(\d+)\b/, text),
            String.to_integer(n) not in fixes,
            do: label
    end
  end
end
