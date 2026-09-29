defmodule Logex.RuntimeTest do
  @moduledoc """
  M1-5: `Logex.Runtime`, an instance at a time. A mistake by the host raises
  `ArgumentError` with the message pinned here, never anything else.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Runtime, Scan}

  @motor """
  var_input start bool
  var_input stop bool
  var_input sp_in dint
  var_output motor bool
  var_output speed_sp dint 1200
  var fault bool

  ( xic start | xic motor ) xio stop ote motor
  xic fault move 0 speed_sp
  xic motor move sp_in speed_sp
  xic motor xio motor ote fault
  """

  setup do
    {:ok, motor} = Logex.compile(@motor, name: "motor")
    %{motor: motor, state: Runtime.instance(motor)}
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # A host mistake the type checker can see is a warning on every run; this hides the
  # deliberately wrong argument from it, since Process.get/2 may return anything.
  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  describe "instance/1" do
    test "every tag at its initial value, before a first scan at 0 ms", %{motor: motor} do
      assert Runtime.instance(motor) == %Instance{
               type: "motor",
               now: 0,
               first: true,
               env: %{
                 "start" => 0,
                 "stop" => 0,
                 "sp_in" => 0,
                 "motor" => 0,
                 "speed_sp" => 1200,
                 "fault" => 0
               }
             }
    end

    test "raises for anything but a program" do
      raises("expected a %Logex.Program{} from Logex.compile/2, got: :motor", fn ->
        Runtime.instance(opaque(:motor))
      end)
    end

    # The program is checked first everywhere, so a good state is never blamed for it.
    test "every function blames a non-program before a good state", %{state: s} do
      motor = opaque(:motor)

      for f <- [
            fn -> Runtime.call(motor, s, %{}, %Scan{now: 0, first: true}) end,
            fn -> Runtime.put_inputs(motor, s, %{}) end,
            fn -> Runtime.scan(motor, s) end,
            fn -> Runtime.scan(motor, s, 5) end,
            fn -> Runtime.restart(motor, s, :cold) end
          ] do
        raises("expected a %Logex.Program{} from Logex.compile/2, got: :motor", f)
      end
    end
  end

  describe "call/4" do
    test "copies inputs in, runs every rung, and gives back the var_outputs", %{
      motor: m,
      state: s
    } do
      {outputs, s} =
        Runtime.call(m, s, %{"start" => 1, "sp_in" => 900}, %Scan{now: 0, first: true})

      assert outputs == %{"motor" => 1, "speed_sp" => 900}
      assert %Instance{now: 0, first: false} = s
      assert s.env["fault"] == 0
    end

    test "inputs merge: one left out keeps its value", %{motor: m, state: s} do
      {_, s} = Runtime.call(m, s, %{"start" => 1, "sp_in" => 900}, %Scan{now: 0, first: true})
      {outputs, s} = Runtime.call(m, s, %{"start" => 0}, %Scan{now: 10, first: false})
      assert outputs == %{"motor" => 1, "speed_sp" => 900}
      assert s.env["sp_in"] == 900
      assert s.now == 10
    end

    test "a var_output a hand-built env leaves out reads 0", %{motor: m, state: s} do
      s = %{s | env: Map.delete(s.env, "speed_sp")}
      assert {%{"speed_sp" => 0}, _} = Runtime.call(m, s, %{}, %Scan{now: 0, first: true})
    end

    test "time never goes backwards, and first must agree with the instance", %{
      motor: m,
      state: s
    } do
      {_, s} = Runtime.call(m, s, %{}, %Scan{now: 10, first: true})

      raises(
        "time went backwards: this scan is at 9 ms, but the instance was last scanned at 10 ms",
        fn ->
          Runtime.call(m, s, %{}, %Scan{now: 9, first: false})
        end
      )

      raises(
        "scan.first is true, but the instance has been scanned since it started or restarted",
        fn ->
          Runtime.call(m, s, %{}, %Scan{now: 10, first: true})
        end
      )

      raises(
        "scan.first is false, but this is the instance's first scan since it started or restarted",
        fn ->
          Runtime.call(m, Runtime.instance(m), %{}, %Scan{now: 0, first: false})
        end
      )
    end

    test "a scan that is not a scan, or not a valid one, raises", %{motor: m, state: s} do
      raises("expected a %Logex.Scan{}, got: 0", fn -> Runtime.call(m, s, %{}, 0) end)

      for {scan, message} <- [
            {%Scan{now: -1, first: true},
             "scan.now must be a non-negative integer of milliseconds, got: -1"},
            {%Scan{now: 1.5, first: true},
             "scan.now must be a non-negative integer of milliseconds, got: 1.5"},
            {%Scan{now: 0, first: nil}, "scan.first must be true or false, got: nil"}
          ] do
        raises(message, fn -> Runtime.call(m, s, %{}, scan) end)
      end
    end

    test "a state that is not an instance of this program raises", %{motor: m, state: s} do
      {:ok, pump} = Logex.compile(@motor, name: "pump")

      raises("this state is an instance of `motor`, not of `pump`", fn ->
        Runtime.call(pump, s, %{}, %Scan{now: 0, first: true})
      end)

      unnamed = %{m | name: nil}

      raises("this state is an instance of `motor`, not of an unnamed program", fn ->
        Runtime.call(unnamed, s, %{}, %Scan{now: 0, first: true})
      end)

      raises(
        ~s|expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: %{"fault" => 0}|,
        fn ->
          Runtime.call(m, %{"fault" => 0}, %{}, %Scan{now: 0, first: true})
        end
      )

      for {state, message} <- [
            {%{s | type: :motor}, "state.type must be a program name, got: :motor"},
            {%{s | env: nil}, "state.env must be a map of tag names to values, got: nil"},
            {%{s | env: %Scan{now: 0, first: true}},
             "state.env must be a map of tag names to values, got: %Logex.Scan{now: 0, first: true}"},
            {%{s | now: nil},
             "state.now must be a non-negative integer of milliseconds, got: nil"},
            {%{s | now: -5}, "state.now must be a non-negative integer of milliseconds, got: -5"},
            {%{s | now: -1}, "state.now must be a non-negative integer of milliseconds, got: -1"},
            {%{s | first: nil}, "state.first must be true or false, got: nil"}
          ] do
        raises(message, fn -> Runtime.call(m, state, %{}, %Scan{now: 0, first: true}) end)
      end
    end

    test "the values in a state's env are not checked, so M1-4's totality stays reachable", %{
      motor: m,
      state: s
    } do
      s = %{s | env: %{s.env | "start" => 5, "stop" => nil}}
      assert {%{"motor" => 1}, _} = Runtime.call(m, s, %{}, %Scan{now: 0, first: true})
    end
  end

  describe "the inputs a host may set" do
    defp put(m, s, inputs), do: Runtime.put_inputs(m, s, inputs)

    test "only a declared var_input, with a value that fits its type exactly", %{
      motor: m,
      state: s
    } do
      for {inputs, message} <- [
            {%{"strat" => 1}, "input `strat` is not declared — did you mean `start`?"},
            {%{"Stop" => 1},
             "input `Stop` is not declared — did you mean `stop`? (tags are case-sensitive)"},
            {%{"b" => 1},
             "input `b` is not declared: the var_inputs are `sp_in`, `start`, `stop`"},
            # Close to a var_output and a var: the did-you-mean offers only a var_input.
            {%{"moter" => 1},
             "input `moter` is not declared: the var_inputs are `sp_in`, `start`, `stop`"},
            {%{"Fault" => 1},
             "input `Fault` is not declared: the var_inputs are `sp_in`, `start`, `stop`"},
            {%{"stop_pb" => 1}, "input `stop_pb` is not declared — did you mean `stop`?"},
            {%{"start\n" => 1}, ~s(input "start\\n" is not declared — did you mean `start`?)},
            {%{"a b" => 1},
             ~s(input "a b" is not declared: the var_inputs are `sp_in`, `start`, `stop`)},
            {%{"motor" => 1},
             "input `motor` is a var_output (declared on line 4), not a var_input: only a var_input is set from outside"},
            {%{"fault" => 1},
             "input `fault` is a var (declared on line 6), not a var_input: only a var_input is set from outside"},
            {%{"start" => 2}, "input `start` is a bool: only 0 or 1 fit, found 2"},
            {%{"start" => true}, "input `start` is a bool: only 0 or 1 fit, found true"},
            {%{"start" => 1.0}, "input `start` is a bool: only 0 or 1 fit, found 1.0"},
            {%{"sp_in" => 2_147_483_648},
             "input `sp_in` is a dint: 2147483648 does not fit in 32 bits"},
            {%{"sp_in" => -2_147_483_649},
             "input `sp_in` is a dint: -2147483649 does not fit in 32 bits"},
            {%{"sp_in" => 2.0},
             "input `sp_in` is a dint: its value must be an integer, found 2.0"},
            {%{"sp_in" => "12"},
             ~s(input `sp_in` is a dint: its value must be an integer, found "12")},
            {%{"sp_in" => %{}},
             "input `sp_in` is a dint: its value must be an integer, found %{}"},
            {%{start: 1},
             ~s|input :start is not a tag name: inputs are keyed by tag name, as a string, as in %{"start" => 1}|}
          ] do
        raises(message, fn -> put(m, s, inputs) end)
      end
    end

    test "the widest dint values fit", %{motor: m, state: s} do
      assert put(m, s, %{"sp_in" => -2_147_483_648}).env["sp_in"] == -2_147_483_648
      assert put(m, s, %{"sp_in" => 2_147_483_647}).env["sp_in"] == 2_147_483_647
    end

    test "every problem comes in one raise, a line each, in key order", %{motor: m, state: s} do
      inputs = %{"strat" => 1, "motor" => 1, 7 => 1, "start" => 2}

      raises(
        Enum.join(
          [
            ~s|input 7 is not a tag name: inputs are keyed by tag name, as a string, as in %{"start" => 1}|,
            "input `motor` is a var_output (declared on line 4), not a var_input: only a var_input is set from outside",
            "input `start` is a bool: only 0 or 1 fit, found 2",
            "input `strat` is not declared — did you mean `start`?"
          ],
          "\n"
        ),
        fn -> put(m, s, inputs) end
      )
    end

    test "key order holds past 32 inputs, where a map's own order stops being sorted", %{
      motor: m,
      state: s
    } do
      names = for i <- 1..40, do: "x#{String.pad_leading(Integer.to_string(i), 2, "0")}"

      message =
        Enum.map_join(
          names,
          "\n",
          &"input `#{&1}` is not declared: the var_inputs are `sp_in`, `start`, `stop`"
        )

      raises(message, fn -> put(m, s, Map.new(names, &{&1, 0})) end)
    end

    test "the var_inputs are listed in order in a program of more than 32 tags" do
      # A map of 32 keys or fewer iterates in key order, so only a larger tag table can
      # show whether the list is sorted.
      spares = for i <- 1..40, do: "v#{String.pad_leading(Integer.to_string(i), 2, "0")}"

      source =
        "var_input start bool\nvar_input stop bool\nvar_input sp_in dint\n" <>
          Enum.map_join(spares, &"var #{&1} bool\n") <>
          "xic start xio stop " <> Enum.map_join(spares, " ", &"ote #{&1}")

      {:ok, p} = Logex.compile(source, name: "p")

      raises("input `b` is not declared: the var_inputs are `sp_in`, `start`, `stop`", fn ->
        put(p, Runtime.instance(p), %{"b" => 1, "sp_in" => 0})
      end)
    end

    test "a tag declared from Elixir is cited without a line", %{motor: m} do
      {:ok, tokens, _} = Logex.Compiler.tokenize("xic a ote b")
      {:ok, ast} = Logex.Compiler.parse(tokens)
      declared = [Logex.Tag.new!("a", :bool, :var_input), Logex.Tag.new!("b", :bool, :var_output)]
      {:ok, p} = Logex.Compiler.instructionize(ast, declared)

      raises(
        "input `b` is a var_output, not a var_input: only a var_input is set from outside",
        fn -> put(p, Runtime.instance(p), %{"b" => 1}) end
      )

      raises("this state is an instance of an unnamed program, not of `motor`", fn ->
        put(m, Runtime.instance(p), %{"start" => 1})
      end)
    end

    test "the state and its owner are checked before the inputs", %{motor: m, state: s} do
      {:ok, pump} = Logex.compile(@motor, name: "pump")

      # A bad input as well, so the owner must be checked first to be the one blamed.
      raises("this state is an instance of `motor`, not of `pump`", fn ->
        put(pump, s, %{"zz" => 1})
      end)

      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: nil", fn ->
        put(m, nil, %{"start" => 1})
      end)
    end

    test "a key that is not valid UTF-8 is named, not a crash", %{motor: m, state: s} do
      raises(
        "input `strat` is not declared — did you mean `start`?\n" <>
          "input <<255>> is not declared: the var_inputs are `sp_in`, `start`, `stop`",
        fn -> put(m, s, %{<<255>> => 1, "strat" => 1}) end
      )
    end

    test "a program with no var_input says so" do
      {:ok, p} = Logex.compile("var a bool\nxic a ote a", name: "p")

      raises("input `b` is not declared: this program has no var_input", fn ->
        put(p, Runtime.instance(p), %{"b" => 1})
      end)
    end

    test "inputs must be a map, and not a struct", %{motor: m, state: s} do
      raises(
        ~s|inputs must be a map of var_input names to values, as in %{"start" => 1}, got: [start: 1]|,
        fn ->
          put(m, s, start: 1)
        end
      )

      raises(
        ~s|inputs must be a map of var_input names to values, as in %{"start" => 1}, got: | <>
          inspect(%Scan{now: 0, first: true}),
        fn -> put(m, s, %Scan{now: 0, first: true}) end
      )
    end
  end

  describe "the task-less sugar" do
    test "put_inputs/3 then scan/2 and scan/3, with the instance's own clock", %{
      motor: m,
      state: s
    } do
      s = Runtime.put_inputs(m, s, %{"start" => 1})
      assert {%{"motor" => 1}, s} = Runtime.scan(m, s)
      assert %Instance{now: 0, first: false} = s
      s = Runtime.put_inputs(m, s, %{"start" => 0})
      assert {%{"motor" => 1}, s} = Runtime.scan(m, s, 25)
      assert {_, %Instance{now: 35}} = Runtime.scan(m, s, 10)
    end

    test "scan hands call/4 the instance's first and its time", %{motor: m, state: s} do
      {_, s} = Runtime.scan(m, s, 40)
      assert %Instance{now: 40, first: false} = s
    end

    test "scan/2 and scan/3 check the state before reading its clock", %{motor: m, state: s} do
      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: nil", fn ->
        Runtime.scan(m, opaque(nil))
      end)

      raises("state.now must be a non-negative integer of milliseconds, got: nil", fn ->
        Runtime.scan(m, %{s | now: nil}, 5)
      end)
    end

    test "elapsed_ms must be a non-negative integer", %{motor: m, state: s} do
      raises("elapsed_ms must be a non-negative integer of milliseconds, got: -1", fn ->
        Runtime.scan(m, s, -1)
      end)

      raises("elapsed_ms must be a non-negative integer of milliseconds, got: 2.5", fn ->
        Runtime.scan(m, s, opaque(2.5))
      end)
    end

    test "one program runs as many independent instances", %{motor: m} do
      a = Runtime.put_inputs(m, Runtime.instance(m), %{"start" => 1})
      b = Runtime.instance(m)
      assert {%{"motor" => 1}, _} = Runtime.scan(m, a)
      assert {%{"motor" => 0}, _} = Runtime.scan(m, b)
    end
  end

  describe "restart/3" do
    setup %{motor: m, state: s} do
      s = Runtime.put_inputs(m, s, %{"start" => 1, "sp_in" => 900})
      {_, s} = Runtime.scan(m, s, 30)
      {_, s} = Runtime.scan(m, s, 20)
      %{running: s}
    end

    test "puts every tag but the var_inputs back at its initial value", %{motor: m, running: s} do
      assert %{"motor" => 1, "speed_sp" => 900} = s.env
      restarted = Runtime.restart(m, s, :cold)

      assert restarted.env == %{
               "start" => 1,
               "stop" => 0,
               "sp_in" => 900,
               "motor" => 0,
               "speed_sp" => 1200,
               "fault" => 0
             }
    end

    test "marks the next scan first, and keeps the clock", %{motor: m, running: s} do
      assert %Instance{now: 50, first: true} = Runtime.restart(m, s, :cold)
    end

    test "keeps the input image, so scan/2 still sees what the host holds", %{
      motor: m,
      running: s
    } do
      # A configuration copies its inputs in on every scan, so after a restart its instance
      # sees `start` still held; the sugar must agree (docs/organisation.md §4.6).
      assert {%{"motor" => 1, "speed_sp" => 900}, _} =
               Runtime.scan(m, Runtime.restart(m, s, :cold))
    end

    test "a warm restart is a cold one until retain exists", %{motor: m, running: s} do
      assert Runtime.restart(m, s, :warm) == Runtime.restart(m, s, :cold)
    end

    test "raises for another mode, or a state that is not this program's", %{motor: m, running: s} do
      raises("restart takes :cold or :warm, got: :hot", fn -> Runtime.restart(m, s, :hot) end)
      {:ok, pump} = Logex.compile(@motor, name: "pump")

      raises("this state is an instance of `motor`, not of `pump`", fn ->
        Runtime.restart(pump, s, :cold)
      end)

      raises("expected a %Logex.Instance{} from Logex.Runtime.instance/1, got: nil", fn ->
        Runtime.restart(m, opaque(nil), :cold)
      end)

      raises("state.now must be a non-negative integer of milliseconds, got: nil", fn ->
        Runtime.restart(m, %{s | now: nil}, :cold)
      end)
    end
  end

  describe "the public surface (B5)" do
    test "is exactly this: every evaluate clause is private, in Logex.Runtime" do
      assert Enum.sort(Logex.__info__(:functions)) == [compile: 2, compile_file: 1]

      assert Enum.sort(Runtime.__info__(:functions)) ==
               [call: 4, instance: 1, put_inputs: 3, restart: 3, scan: 2, scan: 3]

      assert Enum.sort(Logex.Compiler.__info__(:functions)) ==
               [instructionize: 1, instructionize: 2, instructions: 0, parse: 1, tokenize: 1]
    end
  end
end
