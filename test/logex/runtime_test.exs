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
               ons_blocked: [],
               switched: false,
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
            {%Scan{now: 0, first: nil}, "scan.first must be true or false, got: nil"},
            # OE-1: the block list is the instance's, which call/4 puts in the scan itself,
            # as a map of its bits.
            {%Scan{now: 0, first: true, ons_blocked: ["s1"]},
             "scan.ons_blocked is the runtime's, taken from the instance: " <>
               ~s|a host leaves it out, got: ["s1"]|},
            {%Scan{now: 0, first: true, ons_blocked: nil},
             "scan.ons_blocked is the runtime's, taken from the instance: " <>
               "a host leaves it out, got: nil"}
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
             "state.env must be a map of tag names to values, " <>
               "got: %Logex.Scan{now: 0, first: true, ons_blocked: []}"},
            {%{s | now: nil},
             "state.now must be a non-negative integer of milliseconds, got: nil"},
            {%{s | now: -5}, "state.now must be a non-negative integer of milliseconds, got: -5"},
            {%{s | now: -1}, "state.now must be a non-negative integer of milliseconds, got: -1"},
            {%{s | first: nil}, "state.first must be true or false, got: nil"},
            # OE-1: an edit's switch sets it and a scan clears it.
            {%{s | switched: nil}, "state.switched must be true or false, got: nil"},
            {%{s | switched: 1}, "state.switched must be true or false, got: 1"},
            # OE-1, F8: a proper list of names, or a blocked `ons` would raise unpinned.
            {%{s | ons_blocked: nil},
             "state.ons_blocked must be a list of storage bit names, got: nil"},
            {%{s | ons_blocked: "s1"},
             ~s|state.ons_blocked must be a list of storage bit names, got: "s1"|},
            {%{s | ons_blocked: %{"s1" => true}},
             ~s|state.ons_blocked must be a list of storage bit names, got: %{"s1" => true}|},
            {%{s | ons_blocked: ["s1" | "x"]},
             ~s|state.ons_blocked must be a list of storage bit names, got: ["s1" \| "x"]|},
            {%{s | ons_blocked: [:s1]},
             "state.ons_blocked must be a list of storage bit names, got: [:s1]"},
            {%{s | ons_blocked: ["s1", 7]},
             ~s|state.ons_blocked must be a list of storage bit names, got: ["s1", 7]|}
          ] do
        raises(message, fn -> Runtime.call(m, state, %{}, %Scan{now: 0, first: true}) end)
      end

      # The state's own fields are checked before its owner, the block list among them.
      raises("state.ons_blocked must be a list of storage bit names, got: [:s1]", fn ->
        Runtime.call(pump, %{s | ons_blocked: [:s1]}, %{}, %Scan{now: 0, first: true})
      end)

      raises("state.switched must be true or false, got: nil", fn ->
        Runtime.call(pump, %{s | switched: nil}, %{}, %Scan{now: 0, first: true})
      end)
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

      # The var_inputs are listed once, on the first line that needs them, so a refusal of
      # n keys against n var_inputs is n lines, not n lists of n names.
      message =
        Enum.join(
          [
            "input `x01` is not declared: the var_inputs are `sp_in`, `start`, `stop`"
            | for(name <- tl(names), do: "input `#{name}` is not declared")
          ],
          "\n"
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

  describe "a timer in an instance (M1-6)" do
    @timed """
    var_input go bool
    var_input sp dint
    var_output done bool
    var t1 ton

    xic go move sp t1.pre
    xic t1.dn ote done
    """

    setup do
      {:ok, timed} = Logex.compile(@timed, name: "timed")
      %{timed: timed}
    end

    test "is a map of its members in state.env, every key a string, and never an output", %{
      timed: p
    } do
      state = Runtime.instance(p)

      assert state.env["t1"] ==
               %{"pre" => 0, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 0}

      assert {%{"done" => 0}, _} = Runtime.scan(p, state)
    end

    test "restart puts it back at its initial state, and keeps the input image", %{timed: p} do
      state = Runtime.put_inputs(p, Runtime.instance(p), %{"go" => 1, "sp" => 700})
      {_, state} = Runtime.scan(p, state)
      assert %{"pre" => 700} = state.env["t1"]
      restarted = Runtime.restart(p, state, :cold)
      assert %{"pre" => 0} = restarted.env["t1"]
      assert %{"go" => 1, "sp" => 700} = restarted.env
    end

    test "a member is not an input: the host sets none, nor the instance whole", %{timed: p} do
      state = Runtime.instance(p)

      raises(
        "input `t1.dn` names a member of `t1`, a ton: only a var_input is set from outside",
        fn ->
          Runtime.put_inputs(p, state, %{"t1.dn" => 1})
        end
      )

      raises(
        "input `t1` is a var (declared on line 4), not a var_input: " <>
          "only a var_input is set from outside",
        fn -> Runtime.put_inputs(p, state, %{"t1" => 1}) end
      )

      raises("input `zz.dn` is not declared: the var_inputs are `go`, `sp`", fn ->
        Runtime.put_inputs(p, state, %{"zz.dn" => 1})
      end)

      raises(
        ~s|input "t1.1x" reaches into `t1`, a ton: only a var_input is set from outside|,
        fn ->
          Runtime.call(p, state, %{"t1.1x" => 1}, %Scan{now: 0, first: true})
        end
      )

      # Called a member only where the compiler would take it for one: `last` is internal.
      for key <- ~w(t1.last t1.zz t1.dn.x t1.DN) do
        raises(
          "input `#{key}` reaches into `t1`, a ton: only a var_input is set from outside",
          fn -> Runtime.put_inputs(p, state, %{key => 1}) end
        )
      end

      raises(
        "input `t1.pre` names a member of `t1`, a ton: only a var_input is set from outside",
        fn -> Runtime.put_inputs(p, state, %{"t1.pre" => 1}) end
      )

      raises(~s|input "go." is not declared — did you mean `go`?|, fn ->
        Runtime.put_inputs(p, state, %{"go." => 1})
      end)
    end
  end

  describe "Logex.FbType (M1-6)" do
    alias Logex.FbType
    alias Logex.FbType.Member

    test "the ton's members, and which a program may name and write" do
      ton = FbType.ton()
      assert Enum.map(ton.members, & &1.name) == ~w(pre acc dn tt en last)
      assert Enum.map(FbType.public(ton), & &1.name) == ~w(pre acc dn tt en)
      assert Enum.map(FbType.writable(ton), & &1.name) == ~w(pre acc)
      assert {:ok, %Member{name: "dn", type: :bool, role: :output}} = FbType.member(ton, "dn")
      assert FbType.member(ton, "last") == :error
      assert FbType.member(ton, "DN") == :error
      assert FbType.builtin("TON") == ton
      assert FbType.builtin("tof") == nil
      assert FbType.builtins() == %{"ton" => ton}
    end

    test "a new instance starts where its type says, overridden member by member, and " <>
           "nested" do
      ton = FbType.ton()
      base = %{"pre" => 0, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 0}
      assert FbType.initial(ton) == base
      assert FbType.initial(ton, %{"pre" => 50}) == %{base | "pre" => 50}

      outer = %FbType{
        name: "outer",
        members: [
          %Member{name: "t", type: ton, role: :output, initial: %{"pre" => 9}},
          %Member{name: "n", type: :dint, role: :output, initial: 7}
        ]
      }

      assert FbType.initial(outer) == %{"t" => %{base | "pre" => 9}, "n" => 7}
    end
  end

  describe "an instance's one-shot block list (OE-1)" do
    @ons "var_input go bool\nvar_output pulse bool\nvar s1 bool\nxic go ons s1 ote pulse"

    # Only Logex.Edit's switch sets it (edit_test.exs); here it is set by hand, after a
    # first scan, to see what the runtime does with it.
    setup do
      {:ok, p} = Logex.compile(@ons, name: "o")

      {%{"pulse" => 0}, running} =
        Runtime.call(p, Runtime.instance(p), %{}, %Scan{now: 0, first: true})

      %{ons: p, blocked: %{running | ons_blocked: ["s1"]}}
    end

    test "blocks each ons it names for one scan, which still writes the storage bit", %{
      ons: p,
      blocked: b
    } do
      # A real edge, blocked.
      {%{"pulse" => 0}, s} = Runtime.call(p, b, %{"go" => 1}, %Scan{now: 10, first: false})
      assert s.ons_blocked == [] and s.env["s1"] == 1
      # The bit was written, so `go` held is no edge; and the next edge fires.
      {%{"pulse" => 0}, s} = Runtime.call(p, s, %{}, %Scan{now: 20, first: false})
      {%{"pulse" => 0}, s} = Runtime.call(p, s, %{"go" => 0}, %Scan{now: 30, first: false})
      assert {%{"pulse" => 1}, _} = Runtime.call(p, s, %{"go" => 1}, %Scan{now: 40, first: false})
    end

    test "an ons it does not name fires on a real edge", %{ons: p, blocked: b} do
      other = %{b | ons_blocked: ["s9", "pulse"]}

      assert {%{"pulse" => 1}, _} =
               Runtime.call(p, other, %{"go" => 1}, %Scan{now: 10, first: false})
    end

    test "put_inputs/3 keeps it, and scan/2 and scan/3 use it, as call/4 does", %{
      ons: p,
      blocked: b
    } do
      s = Runtime.put_inputs(p, b, %{"go" => 1})
      assert s.ons_blocked == ["s1"]
      assert {%{"pulse" => 0}, %Instance{ons_blocked: []}} = Runtime.scan(p, s, 10)
      assert {%{"pulse" => 0}, %Instance{ons_blocked: []}} = Runtime.scan(p, s)
      assert {%{"pulse" => 1}, _} = Runtime.scan(p, %{s | ons_blocked: []})
    end

    test "restart/3 empties it", %{ons: p, blocked: b} do
      assert %Instance{ons_blocked: [], first: true} = Runtime.restart(p, b, :cold)
    end

    test "a host fills in no scan's list, not even the instance's own", %{ons: p, blocked: b} do
      raises(
        "scan.ons_blocked is the runtime's, taken from the instance: " <>
          ~s|a host leaves it out, got: ["s1"]|,
        fn -> Runtime.call(p, b, %{}, %Scan{now: 10, first: false, ons_blocked: ["s1"]}) end
      )

      assert {_, _} = Runtime.call(p, b, %{}, %Scan{now: 10, first: false, ons_blocked: []})
    end
  end

  describe "an instance's `switched` (OE-1)" do
    # Only Logex.Edit's switch sets it (edit_test.exs); here it is set by hand, to see what
    # the runtime does with it.
    setup %{motor: m, state: s} do
      {_, running} = Runtime.scan(m, s)
      %{switched: %{running | switched: true}}
    end

    test "a new instance has none, and a scan clears it", %{motor: m, switched: s} do
      assert %Instance{switched: false} = Runtime.instance(m)
      assert {_, %Instance{switched: false}} = Runtime.scan(m, s, 10)

      assert {_, %Instance{switched: false}} =
               Runtime.call(m, s, %{}, %Scan{now: 10, first: false})
    end

    test "put_inputs/3 and restart/3 keep it, as neither is a scan", %{motor: m, switched: s} do
      assert %Instance{switched: true} = Runtime.put_inputs(m, s, %{"start" => 1})
      assert %Instance{switched: true, first: true} = Runtime.restart(m, s, :cold)
    end
  end

  describe "a resource's host contract (M2-1)" do
    alias Logex.Configuration
    alias Logex.Configuration.{Connection, Global, Instance}

    # The motor, one task-less instance: its two bools wired to input points, its dint to
    # an unlocated global, its outputs to an output point and an unlocated dint.
    defp plant(motor),
      do:
        Configuration.new!(
          name: "plant",
          programs: [motor],
          tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 0}],
          globals: [
            %Global{name: "pb_start", type: :bool, at: "panel.i.0"},
            %Global{name: "pb_stop", type: :bool, at: "panel.i.1"},
            %Global{name: "sp", type: :dint, at: "drive.i.0"},
            %Global{name: "k", type: :bool, at: "panel.q.0"},
            %Global{name: "speed", type: :dint}
          ],
          instances: [%Instance{name: "m1", type: "motor", task: "fast"}],
          connections: [
            %Connection{instance: "m1", member: "start", to: "pb_start"},
            %Connection{instance: "m1", member: "stop", to: "pb_stop"},
            %Connection{instance: "m1", member: "sp_in", to: "sp"},
            %Connection{instance: "m1", member: "motor", to: "k"},
            %Connection{instance: "m1", member: "speed_sp", to: "speed"}
          ]
        )

    test "start/1 takes a configuration, checked again", %{motor: motor} do
      raises(
        "expected a %Logex.Configuration{} from Logex.Configuration.new!/1, got: 5",
        fn -> Runtime.start(opaque(5)) end
      )

      config = %{plant(motor) | instances: [], connections: []}

      raises("a configuration runs at least one program instance", fn -> Runtime.start(config) end)
    end

    test "every call takes a runtime from start/1, checked first", %{motor: motor} do
      message = "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: 5"
      raises(message, fn -> Runtime.cycle(opaque(5), -1, []) end)
      raises(message, fn -> Runtime.next_due_in(opaque(5)) end)
      raises(message, fn -> Runtime.overlaps(opaque(5)) end)
      raises(message, fn -> Runtime.get!(opaque(5), opaque(5)) end)
      raises(message, fn -> Runtime.get(opaque(5), "m1") end)
      error = assert_raise ArgumentError, fn -> Runtime.cycle(opaque(plant(motor)), 0, %{}) end

      assert "expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: %Logex.Configuration{" <>
               _ = error.message
    end

    test "cycle/3 takes elapsed time, then inputs", %{motor: motor} do
      runtime = Runtime.start(plant(motor))

      for elapsed <- [-1, 1.5, nil],
          do:
            raises(
              "elapsed_ms must be a non-negative integer of milliseconds, got: #{inspect(elapsed)}",
              fn -> Runtime.cycle(runtime, opaque(elapsed), []) end
            )

      # A struct is a map, but no input image: it is refused as a list is.
      for inputs <- [[], %Scan{now: 0, first: true}],
          do:
            raises(
              ~s|inputs must be a map of input-point names to values, as in | <>
                ~s|%{"pb_start_1" => 1}, got: #{inspect(inputs)}|,
              fn -> Runtime.cycle(runtime, 0, opaque(inputs)) end
            )
    end

    test "only an input point is set, with a value that fits it, every problem in one raise, " <>
           "in key order",
         %{motor: motor} do
      runtime = Runtime.start(plant(motor))

      inputs = %{
        5 => 1,
        "k" => 1,
        "speed" => 1,
        "m1.start" => 1,
        "pb_strat" => 1,
        "zz" => 0,
        "pb_start" => 2,
        "sp" => 1.5,
        "pb_stop" => 1
      }

      raises(
        Enum.join(
          [
            ~s|input 5 is not a point name: inputs are keyed by input-point name, as a string, | <>
              ~s|as in %{"pb_start_1" => 1}|,
            "input `k` is an output point (at `panel.q.0`), not an input point: only an input " <>
              "point is set from outside",
            "input `m1.start` reaches into the program instance `m1`: only an input point is " <>
              "set from outside",
            "input `pb_start` is a bool: only 0 or 1 fit, found 2",
            "input `pb_strat` is not an input point — did you mean `pb_start`?",
            "input `sp` is a dint: its value must be an integer, found 1.5",
            "input `speed` is a global with no location, not an input point: only an input " <>
              "point is set from outside",
            "input `zz` is not an input point: the input points are `pb_start`, `pb_stop` and `sp`"
          ],
          "\n"
        ),
        fn -> Runtime.cycle(runtime, 0, inputs) end
      )

      raises("input `sp` is a dint: 3000000000 does not fit in 32 bits", fn ->
        Runtime.cycle(runtime, 0, %{"sp" => 3_000_000_000})
      end)

      no_points =
        Configuration.new!(
          name: "plant",
          programs: [motor],
          instances: [%Instance{name: "m1", type: "motor"}],
          connections:
            for(m <- ~w(start stop sp_in), do: %Connection{instance: "m1", member: m, to: 0})
        )

      raises("input `x` is not an input point: this configuration has no input point", fn ->
        Runtime.cycle(Runtime.start(no_points), 0, %{"x" => 1})
      end)
    end

    test "get/2 reads a global, a tag or a public member, and refuses anything else" do
      timed =
        String.replace(@motor, "var fault bool\n", "var fault bool\nvar t1 ton\n") <>
          "xic motor ton t1 100\n"

      {:ok, timed} = Logex.compile(timed, name: "motor")
      runtime = Runtime.start(plant(timed))
      {runtime, _outputs, _events} = Runtime.cycle(runtime, 0, %{"pb_start" => 1, "sp" => 7})

      assert Runtime.get!(runtime, "pb_start") == 1
      assert Runtime.get!(runtime, "speed") == 7
      assert Runtime.get!(runtime, "m1.sp_in") == 7
      assert Runtime.get!(runtime, "m1.motor") == 1
      assert Runtime.get!(runtime, "m1.fault") == 0
      assert Runtime.get!(runtime, "m1.t1.en") == 1
      assert Runtime.get!(runtime, "m1.t1.pre") == 100

      path =
        ~s|is not an access path: a global, or a program instance, its tag and the members | <>
          ~s|below it, joined by `.`, as in "m1.t1.acc"|

      for {bad, message} <- [
            {5, "5 " <> path},
            {"m1..x", ~s|"m1..x" | <> path},
            {"", ~s|"" | <> path},
            {"m1 t1", ~s|"m1 t1" | <> path},
            {"zz", "`zz` is neither a global nor a program instance"},
            {"pb_strat",
             "`pb_strat` is neither a global nor a program instance — did you mean " <>
               "`pb_start`?"},
            {"m11", "`m11` is neither a global nor a program instance — did you mean `m1`?"},
            {"k.x", "`k.x` goes too deep: `k` is a bool global, which has no members"},
            {"m1",
             "`m1` is a program instance of `motor`: an access path names one of its " <>
               "tags, as in `m1.fault`"},
            {"m1.strat",
             "`m1` is a program instance of `motor`, which declares no `strat` — did you " <>
               "mean `start`?"},
            {"m1.fault.x",
             "`m1.fault.x` goes too deep: `m1.fault` is a bool, which has no members"},
            {"m1.t1",
             "`m1.t1` is a ton: an access path names one of its members, as in " <>
               "`m1.t1.acc`"},
            {"m1.t1.last",
             "`m1.t1.last` is internal to `m1.t1`: an access path reads only its public " <>
               "members, `pre`, `acc`, `dn`, `tt` and `en`"},
            {"m1.t1.zz",
             "`m1.t1.zz` is not a member of `m1.t1`, a ton: its members are " <>
               "`pre`, `acc`, `dn`, `tt` and `en`"},
            {"m1.t1.Acc",
             "`m1.t1.Acc` is not a member of `m1.t1`, a ton — did you mean " <>
               "`m1.t1.acc`? (members are case-sensitive)"},
            {"m1.t1.acc.x",
             "`m1.t1.acc.x` goes too deep: `m1.t1.acc` is a dint, which has no " <>
               "members"}
          ],
          do: raises(message, fn -> Runtime.get!(runtime, opaque(bad)) end)
    end

    # Decision 41: get/2 gives what get!/2 reads as {:ok, value}, and the reason get!/2
    # raises as {:error, reason} for any string; a path that is not a string is the
    # host's mistake, raised by both.
    test "get/2 gives {:ok, value} or {:error, reason}, the reason get!/2 raises" do
      timed =
        String.replace(@motor, "var fault bool\n", "var fault bool\nvar t1 ton\n") <>
          "xic motor ton t1 100\n"

      {:ok, timed} = Logex.compile(timed, name: "motor")
      runtime = Runtime.start(plant(timed))
      {runtime, _outputs, _events} = Runtime.cycle(runtime, 0, %{"pb_start" => 1, "sp" => 7})

      for {path, value} <- [{"pb_start", 1}, {"m1.sp_in", 7}, {"m1.t1.pre", 100}],
          do: assert(Runtime.get(runtime, opaque(path)) == {:ok, value})

      for bad <- ["m1..x", "", "zz", "m1", "m1.t1.last", "m1.t1.acc.x"] do
        error = assert_raise ArgumentError, fn -> Runtime.get!(runtime, opaque(bad)) end
        assert Runtime.get(runtime, opaque(bad)) == {:error, error.message}
      end

      raises(
        ~s|5 is not an access path: a global, or a program instance, its tag and the | <>
          ~s|members below it, joined by `.`, as in "m1.t1.acc"|,
        fn -> Runtime.get(runtime, opaque(5)) end
      )
    end
  end

  describe "a name that is no input point and no global" do
    alias Logex.Configuration
    alias Logex.Configuration.{Connection, Global, Instance}

    defp named_plant(motor, name),
      do:
        Configuration.new!(
          name: name,
          programs: [motor],
          tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 0}],
          globals: [%Global{name: "pb", type: :bool, at: "panel.i.0"}],
          instances: [%Instance{name: "m1", type: "motor", task: "fast"}],
          connections:
            for(m <- ~w(start stop sp_in), do: %Connection{instance: "m1", member: m, to: 0})
        )

    # Tasks, globals and program instances share one namespace, and the configuration has
    # a name: a key or a path that names one of them is told which it is.
    test "is told what it names: a program instance, a task, or the configuration", %{
      motor: motor
    } do
      runtime = Runtime.start(named_plant(motor, "plant"))
      outside = "not an input point: only an input point is set from outside"

      for {key, message} <- [
            {"m1", "input `m1` is a program instance of `motor`, " <> outside},
            {"fast", "input `fast` is a task, " <> outside},
            {"plant", "input `plant` is the configuration's name, " <> outside}
          ],
          do: raises(message, fn -> Runtime.cycle(runtime, 0, %{key => 1}) end)

      raises(
        "`fast` is a task, not a global or a program instance: an access path starts at one " <>
          "of those, and overlaps/1 reads a task's overlap count",
        fn -> Runtime.get!(runtime, "fast") end
      )

      raises(
        "`plant` is the configuration's name, which an access path leaves out: it starts at " <>
          "a global or a program instance",
        fn -> Runtime.get!(runtime, "plant") end
      )
    end

    # The configuration's name is outside the namespace, so a task may share it: the name
    # is then the task's.
    test "a task that shares the configuration's name is the task", %{motor: motor} do
      runtime = Runtime.start(named_plant(motor, "fast"))

      raises(
        "input `fast` is a task, not an input point: only an input point is set from outside",
        fn -> Runtime.cycle(runtime, 0, %{"fast" => 1}) end
      )

      raises(
        "`fast` is a task, not a global or a program instance: an access path starts at one " <>
          "of those, and overlaps/1 reads a task's overlap count",
        fn -> Runtime.get!(runtime, "fast") end
      )
    end

    # The input points are listed once, on the first line that needs them.
    test "a refusal lists the input points once", %{motor: motor} do
      runtime = Runtime.start(named_plant(motor, "plant"))

      raises(
        "input `aa` is not an input point: the input points are `pb`\n" <>
          "input `zz` is not an input point",
        fn -> Runtime.cycle(runtime, 0, %{"zz" => 1, "aa" => 1}) end
      )
    end

    # A map of 32 keys or fewer iterates in key order, so only more keys show whether the
    # lines are sorted.
    test "key order holds past 32 keys, the input points listed once", %{motor: motor} do
      runtime = Runtime.start(named_plant(motor, "plant"))
      names = for i <- 1..40, do: "wrong_#{String.pad_leading(Integer.to_string(i), 2, "0")}"

      raises(
        Enum.join(
          [
            "input `wrong_01` is not an input point: the input points are `pb`"
            | for(name <- tl(names), do: "input `#{name}` is not an input point")
          ],
          "\n"
        ),
        fn -> Runtime.cycle(runtime, 0, Map.new(names, &{&1, 1})) end
      )
    end

    # n wrong keys against n input points: the message grows with n, not with n * n.
    test "a refusal of many keys grows linearly in its size", %{motor: motor} do
      bytes = fn n ->
        config =
          Configuration.new!(
            name: "plant",
            programs: [motor],
            globals: for(i <- 1..n, do: %Global{name: "pt#{i}", type: :bool, at: "io.i.#{i}"}),
            instances: [%Instance{name: "m1", type: "motor"}],
            connections:
              for(m <- ~w(start stop sp_in), do: %Connection{instance: "m1", member: m, to: 0})
          )

        runtime = Runtime.start(config)
        inputs = Map.new(1..n, &{"wrong_#{&1}", 1})
        error = assert_raise ArgumentError, fn -> Runtime.cycle(runtime, 0, inputs) end
        byte_size(error.message)
      end

      ratio = bytes.(400) / bytes.(100)
      assert ratio < 6, "4x the keys made a message #{Float.round(ratio, 1)}x the size"
    end
  end

  describe "a resource's host contract (M2-1), the rest" do
    alias Logex.Configuration
    alias Logex.Configuration.{Connection, Global, Instance}

    test "restart/2 takes a runtime, then :cold or :warm", %{motor: motor} do
      config =
        Configuration.new!(
          name: "plant",
          programs: [motor],
          instances: [%Instance{name: "m1", type: "motor"}],
          connections:
            for(m <- ~w(start stop sp_in), do: %Connection{instance: "m1", member: m, to: 0})
        )

      runtime = Runtime.start(config)

      raises("expected a %Logex.Runtime{} from Logex.Runtime.start/1, got: 5", fn ->
        Runtime.restart(opaque(5), :hot)
      end)

      for mode <- [:hot, nil, "cold"],
          do:
            raises("restart takes :cold or :warm, got: #{inspect(mode)}", fn ->
              Runtime.restart(runtime, opaque(mode))
            end)

      assert %Runtime{} = Runtime.restart(runtime, :warm)
    end
  end

  describe "get/2 of an instance whole" do
    # A program may declare no tag at all, and then there is no tag to give as an example.
    test "names one of its tags, or says it declares none" do
      {:ok, empty} = Logex.compile("", name: "empty")

      config =
        Logex.Configuration.new!(
          name: "plant",
          programs: [empty],
          instances: [%Logex.Configuration.Instance{name: "e", type: "empty"}]
        )

      raises(
        "`e` is a program instance of `empty`: an access path names one of its tags, and it " <>
          "declares none",
        fn -> Runtime.get!(Runtime.start(config), "e") end
      )
    end
  end

  describe "the public surface (B5)" do
    test "is exactly this: every evaluate clause is private, in Logex.Runtime" do
      assert Enum.sort(Logex.__info__(:functions)) == [compile: 2, compile_file: 1]

      # M2-1: the scheduler, and its resource, `%Logex.Runtime{}`, opaque as an edit is.
      assert Enum.sort(Runtime.__info__(:functions)) ==
               [
                 __struct__: 0,
                 __struct__: 1,
                 call: 4,
                 cycle: 3,
                 get: 2,
                 get!: 2,
                 instance: 1,
                 next_due_in: 1,
                 overlaps: 1,
                 put_inputs: 3,
                 restart: 2,
                 restart: 3,
                 scan: 2,
                 scan: 3,
                 start: 1
               ]

      # M2-1: the configuration, its one validator and its constructor from Elixir.
      assert Enum.sort(Logex.Configuration.__info__(:functions)) ==
               [__struct__: 0, __struct__: 1, check: 1, initial: 1, location: 1, new!: 1]

      assert Enum.sort(Map.keys(Logex.Configuration.__struct__())) ==
               [:__struct__, :connections, :file, :globals, :instances, :name, :programs] ++
                 [:tasks, :warnings]

      for {module, keys} <- [
            {Logex.Configuration.Task, [:interval, :line, :name, :priority]},
            {Logex.Configuration.Global, [:at, :initial, :line, :name, :type]},
            {Logex.Configuration.Instance, [:line, :name, :task, :type]},
            {Logex.Configuration.Connection, [:instance, :line, :member, :to]}
          ],
          do: assert(Enum.sort(Map.keys(Map.from_struct(struct(module)))) == keys)

      assert Enum.sort(Logex.Compiler.__info__(:functions)) ==
               [instructionize: 1, instructionize: 2, instructions: 0, parse: 1, tokenize: 1]

      # The two structs a host holds and builds; OE-1 gave both `ons_blocked`, and the
      # instance `switched`.
      assert Enum.sort(Map.keys(Instance.__struct__())) ==
               [:__struct__, :env, :first, :now, :ons_blocked, :switched, :type]

      assert Enum.sort(Map.keys(Scan.__struct__())) == [:__struct__, :first, :now, :ons_blocked]

      # OE-1: the staged edit of one instance, whose struct is opaque.
      assert Enum.sort(Logex.Edit.__info__(:functions)) == [
               __struct__: 0,
               __struct__: 1,
               accept: 3,
               assemble: 2,
               cancel: 2,
               running: 1,
               stage: 1,
               test: 2,
               untest: 2
             ]

      # OE-1: the definition of a well-formed tree, which instructionize/2 checks on entry.
      assert Enum.sort(Logex.Parser.__info__(:functions)) ==
               [format_error: 1, parse: 1, well_formed!: 1]

      assert Enum.sort(Logex.FbType.__info__(:functions)) == [
               __struct__: 0,
               __struct__: 1,
               builtin: 1,
               builtins: 0,
               initial: 1,
               initial: 2,
               member: 2,
               public: 1,
               ton: 0,
               writable: 1
             ]
    end
  end
end
