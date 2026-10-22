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
               "got: %Logex.Scan{now: 0, first: true, ons_blocked: [], tags: nil, blocks: nil}"},
            # M3-5's review: the keys a scan keeps its own records under, which no tag can
            # be, and which it takes out before it ends, so no state holds one.
            {%{s | env: Map.put(s.env, :jump, "nowhere")},
             "state.env holds :jump, the runtime's own key for a record a scan keeps and " <>
               "takes out before it ends: an env is keyed by tag names"},
            {%{s | env: Map.put(s.env, :faults, div: 3)},
             "state.env holds :faults, the runtime's own key for a record a scan keeps and " <>
               "takes out before it ends: an env is keyed by tag names"},
            {%{s | env: Map.put(s.env, :ran, %{"s1" => :skipped})},
             "state.env holds :ran, the runtime's own key for a record a scan keeps and " <>
               "takes out before it ends: an env is keyed by tag names"},
            {%{s | env: Map.merge(s.env, %{ran: nil, jump: nil, faults: nil})},
             "state.env holds :faults, :jump and :ran, the runtime's own keys for records a " <>
               "scan keeps and takes out before it ends: an env is keyed by tag names"},
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
             ~s|state.ons_blocked must be a list of storage bit names, got: ["s1", 7]|},
            # M3-3 (decision 99): the last scan's faults, a proper list of them, whose
            # values are not looked into, since the next scan replaces them.
            {%{s | faults: nil}, "state.faults must be a list of %Logex.Fault{}, got: nil"},
            {%{s | faults: :x}, "state.faults must be a list of %Logex.Fault{}, got: :x"},
            {%{s | faults: [nil]}, "state.faults must be a list of %Logex.Fault{}, got: [nil]"},
            {%{s | faults: [%{kind: :divide_by_zero}]},
             "state.faults must be a list of %Logex.Fault{}, got: [%{kind: :divide_by_zero}]"},
            {%{s | faults: [nil | :tail]},
             "state.faults must be a list of %Logex.Fault{}, got: [nil | :tail]"}
          ] do
        raises(message, fn -> Runtime.call(m, state, %{}, %Scan{now: 0, first: true}) end)
      end

      # The state's own fields are checked before its owner, the block list and the faults
      # among them.
      raises("state.ons_blocked must be a list of storage bit names, got: [:s1]", fn ->
        Runtime.call(pump, %{s | ons_blocked: [:s1]}, %{}, %Scan{now: 0, first: true})
      end)

      raises("state.faults must be a list of %Logex.Fault{}, got: nil", fn ->
        Runtime.call(pump, %{s | faults: nil}, %{}, %Scan{now: 0, first: true})
      end)

      raises("state.switched must be true or false, got: nil", fn ->
        Runtime.call(pump, %{s | switched: nil}, %{}, %Scan{now: 0, first: true})
      end)

      # The env's keys are checked with its shape: after the type, before the clock and
      # the owner.
      jumped = Map.put(s.env, :jump, "nowhere")

      raises("state.type must be a program name, got: :motor", fn ->
        Runtime.call(m, %{s | type: :motor, env: jumped}, %{}, %Scan{now: 0, first: true})
      end)

      for {state, program} <- [{%{s | env: jumped, now: -1}, m}, {%{s | env: jumped}, pump}] do
        raises(
          "state.env holds :jump, the runtime's own key for a record a scan keeps and " <>
            "takes out before it ends: an env is keyed by tag names",
          fn -> Runtime.call(program, state, %{}, %Scan{now: 0, first: true}) end
        )
      end
    end

    test "every entry point that takes a state refuses one whose env holds the runtime's " <>
           "own key, and a key no tag is but none of those is never read",
         %{motor: m, state: s} do
      held = opaque(%{s | env: Map.put(s.env, :jump, "nowhere")})

      for f <- [
            fn -> Runtime.call(m, held, %{}, %Scan{now: 0, first: true}) end,
            fn -> Runtime.put_inputs(m, held, %{}) end,
            fn -> Runtime.scan(m, held) end,
            fn -> Runtime.scan(m, held, 5) end,
            fn -> Runtime.restart(m, held, :cold) end
          ] do
        raises(
          "state.env holds :jump, the runtime's own key for a record a scan keeps and " <>
            "takes out before it ends: an env is keyed by tag names",
          f
        )
      end

      other = %{s | env: Map.merge(s.env, %{:skipped => 1, 7 => 1})}

      assert {%{"motor" => 1}, %{env: env}} =
               Runtime.call(m, other, %{"start" => 1}, %Scan{now: 0, first: true})

      assert {env[:skipped], env[7]} == {1, 1}
    end

    # Decision 171: an integer outside its tag's type is the host's mistake; and since
    # decision 173 so is a value that is no integer, which M1-4 read as it was, a 1.5 in
    # `start` closing its contact and a nil in `stop` leaving its xio closed.
    test "a value that is no integer is refused, as an integer outside its type is",
         %{motor: m, state: s} do
      s = %{s | env: %{s.env | "start" => 1.5, "stop" => nil}}

      raises(
        "state.env holds `start` outside its type: it is a bool, and only 0 or 1 fit, found " <>
          "1.5\nstate.env holds `stop` outside its type: it is a bool, and only 0 or 1 fit, " <>
          "found nil",
        fn -> Runtime.call(m, s, %{}, %Scan{now: 0, first: true}) end
      )
    end
  end

  describe "a state's values (decision 171)" do
    @held """
    var_input go bool
    var_output q bool
    var n dint
    var t ton
    xic go ton t 100
    xic t.dn ote q
    """

    @holder """
    var_input a bool
    var_output y bool
    var p held
    cal p a y
    """

    defp holder do
      {:ok, held} = Logex.compile("function_block held\n" <> @held, name: "held")
      {:ok, holder} = Logex.compile(@holder, name: "holder", types: [held])
      holder
    end

    defp outside(name, type, value),
      do: "state.env holds `#{name}` outside its type: it is #{type}, and #{misfit(type, value)}"

    defp misfit("a bool", value), do: "only 0 or 1 fit, found #{value}"
    defp misfit("a dint", value), do: "#{value} is outside -2147483648 to 2147483647"

    test "an integer outside its tag's type is refused by every entry point that takes a state",
         %{motor: m, state: s} do
      bad = %{s | env: %{s.env | "speed_sp" => 5_000_000_000}}
      message = outside("speed_sp", "a dint", 5_000_000_000)
      {:ok, edit, _} = Logex.Edit.accept(m, m, s)

      for call <- [
            fn -> Runtime.call(m, bad, %{}, %Scan{now: 0, first: true}) end,
            fn -> Runtime.put_inputs(m, bad, %{}) end,
            fn -> Runtime.scan(m, bad) end,
            fn -> Runtime.scan(m, bad, 10) end,
            fn -> Runtime.restart(m, bad, :cold) end,
            fn -> Logex.Edit.accept(m, m, bad) end,
            fn -> Logex.Edit.test(edit, bad) end,
            fn -> Logex.Edit.cancel(edit, bad) end
          ] do
        raises(message, call)
      end
    end

    test "each limit fits and one past it does not, a bool's and a dint's", %{
      motor: m,
      state: s
    } do
      for {tag, value} <- [
            {"start", 0},
            {"start", 1},
            {"sp_in", -2_147_483_648},
            {"sp_in", 2_147_483_647}
          ] do
        assert %Instance{} = Runtime.put_inputs(m, %{s | env: %{s.env | tag => value}}, %{})
      end

      for {tag, type, value} <- [
            {"start", "a bool", -1},
            {"fault", "a bool", 2},
            {"motor", "a bool", 5},
            {"sp_in", "a dint", -2_147_483_649},
            {"speed_sp", "a dint", 2_147_483_648}
          ] do
        raises(outside(tag, type, value), fn ->
          Runtime.put_inputs(m, %{s | env: %{s.env | tag => value}}, %{})
        end)
      end
    end

    test "every value outside is a line of one message, in path order, a member's and a " <>
           "block's by their paths" do
      p = holder()
      s = Runtime.instance(p)
      inner = s.env["p"]
      inner = %{inner | "n" => -5_000_000_000, "t" => %{inner["t"] | "acc" => 2 ** 40}}
      bad = %{s | env: %{s.env | "y" => 3, "p" => %{inner | "q" => 7}}}

      raises(
        Enum.join(
          [
            outside("p.n", "a dint", -5_000_000_000),
            outside("p.q", "a bool", 7),
            outside("p.t.acc", "a dint", 2 ** 40),
            outside("y", "a bool", 3)
          ],
          "\n"
        ),
        fn -> Runtime.put_inputs(p, bad, %{}) end
      )
    end

    test "is checked after the state's owner, and after its shape", %{motor: m, state: s} do
      {:ok, other} = Logex.compile(@motor, name: "other")
      bad = %{s | env: %{s.env | "speed_sp" => 5_000_000_000}}

      raises("this state is an instance of `motor`, not of `other`", fn ->
        Runtime.put_inputs(other, bad, %{})
      end)

      raises("state.now must be a non-negative integer of milliseconds, got: -1", fn ->
        Runtime.put_inputs(m, %{bad | now: -1}, %{})
      end)
    end

    test "a tag the program lacks, one the env leaves out, and an instance that is no map " <>
           "are not looked into, but a value that is no integer is (decision 173)",
         %{motor: m, state: s} do
      p = holder()
      ps = Runtime.instance(p)

      raises(
        "state.env holds `sp_in` outside its type: it is a dint, and its value must be an " <>
          "integer, found 1.0e20\nstate.env holds `start` outside its type: it is a bool, and " <>
          "only 0 or 1 fit, found \"x\"",
        fn ->
          Runtime.put_inputs(m, %{s | env: %{s.env | "sp_in" => 1.0e20, "start" => "x"}}, %{})
        end
      )

      raises(
        "state.env holds `p.n` outside its type: it is a dint, and its value must be an " <>
          "integer, found nil",
        fn ->
          Runtime.put_inputs(p, %{ps | env: %{ps.env | "p" => %{ps.env["p"] | "n" => nil}}}, %{})
        end
      )

      for env <- [
            Map.put(s.env, "extra", 5_000_000_000),
            Map.delete(s.env, "fault")
          ] do
        assert %Instance{} = Runtime.put_inputs(m, %{s | env: env}, %{})
      end

      for inner <- [7, nil, Map.delete(ps.env["p"], "n"), %{ps.env["p"] | "t" => 9}] do
        assert %Instance{} = Runtime.put_inputs(p, %{ps | env: %{ps.env | "p" => inner}}, %{})
      end
    end

    test "a plain swap that narrows a tag over a value outside it is refused at its next call" do
      {:ok, v1} = Logex.compile("var_input go bool\nvar k dint\nxic go move 7 k", name: "m")
      {:ok, v2} = Logex.compile("var_input go bool\nvar k bool\nxic go ote k", name: "m")

      {_, state} =
        Runtime.call(v1, Runtime.instance(v1), %{"go" => 1}, %Scan{now: 0, first: true})

      raises(outside("k", "a bool", 7), fn -> Runtime.scan(v2, state) end)
      raises(outside("k", "a bool", 7), fn -> Runtime.restart(v2, state, :cold) end)

      # Restarted under the program whose values it holds, it is taken.
      restarted = Runtime.restart(v1, state, :cold)
      assert {_, %Instance{env: %{"k" => 1}}} = Runtime.scan(v2, restarted)
    end

    test "a resource's instance is checked as each scan takes it, a var_external's global with it" do
      {:ok, m} =
        Logex.compile("var_external e dint\nvar_output y dint\nvar k dint\nmove e y",
          name: "m"
        )

      config =
        Logex.Configuration.new!(
          name: "plant",
          programs: [m],
          globals: [
            %Logex.Configuration.Global{name: "e", type: :dint},
            %Logex.Configuration.Global{name: "o", type: :dint}
          ],
          instances: [%Logex.Configuration.Instance{name: "m1", type: "m"}],
          connections: [%Logex.Configuration.Connection{instance: "m1", member: "y", to: "o"}]
        )

      runtime = Runtime.start(config)
      %Runtime{instances: %{"m1" => m1}, globals: globals} = runtime
      by_hand = %{runtime | instances: %{"m1" => %{m1 | env: %{m1.env | "k" => 2 ** 32}}}}
      raises(outside("k", "a dint", 2 ** 32), fn -> Runtime.cycle(by_hand, 0, %{}) end)
      raises(outside("k", "a dint", 2 ** 32), fn -> Runtime.restart(by_hand, :cold) end)
      by_hand = %{runtime | globals: %{globals | "e" => -(2 ** 32)}}
      raises(outside("e", "a dint", -(2 ** 32)), fn -> Runtime.cycle(by_hand, 0, %{}) end)
    end

    test "a global a connection copies in is checked against its own type, narrower than its var_input" do
      {:ok, m} =
        Logex.compile(
          "var_input i dint\nvar_input j lint\nvar_input k dint\nvar_output o lint\n" <>
            "move i o",
          name: "m"
        )

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          "var_global a uint\nvar_global s sint\nvar_global b lint\nprogram m1 m\n" <>
            "program m2 m\nm1.i a\nm1.j s\nm1.k a\nm1.o b\nm2.i a\nm2.j s\nm2.k a",
          %{"m" => m}
        )

      runtime = Runtime.start(config)
      %Runtime{globals: globals} = runtime

      # Each global's value fits its var_input, so only its own type refuses it, every
      # one a line in name order, `a`, read twice, told once; nothing is copied out.
      by_hand = %{runtime | globals: %{globals | "a" => 70000, "s" => -129}}

      raises(
        "runtime.globals holds `a` outside its type: it is a uint, and 70000 is outside 0 to 65535\n" <>
          "runtime.globals holds `s` outside its type: it is an sint, and -129 is outside -128 to 127",
        fn -> Runtime.cycle(by_hand, 0, %{}) end
      )

      # A value that is no integer is outside its type too (decision 173), shown as given.
      no_integer = %{runtime | globals: %{globals | "a" => 37.5, "s" => nil}}

      raises(
        "runtime.globals holds `a` outside its type: it is a uint, and its value must be an " <>
          "integer, found 37.5\n" <>
          "runtime.globals holds `s` outside its type: it is an sint, and its value must be an " <>
          "integer, found nil",
        fn -> Runtime.cycle(no_integer, 0, %{}) end
      )

      # At its limits it is taken and widened.
      at_limits = %{runtime | globals: %{globals | "a" => 65535, "s" => -128}}
      {ran, _outputs, _events} = Runtime.cycle(at_limits, 0, %{})
      assert Runtime.get(ran, "b") == {:ok, 65535}
    end

    # A state of n dints and n timers, checked whole by put_inputs/3 with no inputs: linear
    # in the tags. 4x the tags took 3.99x to 4.02x over five runs on Elixir 1.20.4; the
    # bound is a fifth above the highest.
    defp reductions_to_check(n) do
      {:ok, p} =
        Logex.compile(
          Enum.map_join(1..n, "\n", &"var d#{&1} dint\nvar t#{&1} ton") <>
            "\n" <> Enum.map_join(1..n, "\n", &"xic t#{&1}.dn move 1 d#{&1}"),
          name: "m"
        )

      s = Runtime.instance(p)

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          Runtime.put_inputs(p, s, %{})
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    test "is linear in the state it checks" do
      ratio = reductions_to_check(2000) / reductions_to_check(500)
      assert ratio < 4.8, "4x the tags took #{Float.round(ratio, 2)}x the reductions"
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
             "input `sp_in` is a dint: 2147483648 is outside -2147483648 to 2147483647"},
            {%{"sp_in" => -2_147_483_649},
             "input `sp_in` is a dint: -2147483649 is outside -2147483648 to 2147483647"},
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

  # M2-4: outside a configuration, a var_external is a tag of its own at 0, which its host
  # cannot set: exactly a one-instance configuration whose global is unlocated, with no
  # initial value, that no other instance uses (docs/organisation.md §4.10, M2-4).
  describe "a var_external run alone (M2-4)" do
    setup do
      {:ok, alarm} =
        Logex.compile(
          "var_input trip bool\nvar_output lamp bool\nvar_external estop bool\n" <>
            "var_external count dint\nxic trip otl estop\nxic estop ote lamp\n" <>
            "xic trip move 3 count",
          name: "alarm"
        )

      %{alarm: alarm}
    end

    test "starts at 0, as its own tag, and keeps what logic writes", %{alarm: a} do
      state = Runtime.instance(a)
      assert state.env == %{"trip" => 0, "lamp" => 0, "estop" => 0, "count" => 0}
      {_, state} = Runtime.scan(a, Runtime.put_inputs(a, state, %{"trip" => 1}), 10)
      {outputs, state} = Runtime.scan(a, Runtime.put_inputs(a, state, %{"trip" => 0}), 10)
      assert outputs == %{"lamp" => 1}
      assert %{"estop" => 1, "count" => 3} = state.env
    end

    test "is no input: its host cannot set it", %{alarm: a} do
      state = Runtime.instance(a)

      raises(
        "input `count` is a var_external (declared on line 4), not a var_input: only a " <>
          "var_input is set from outside\n" <>
          "input `estop` is a var_external (declared on line 3), not a var_input: only a " <>
          "var_input is set from outside",
        fn -> Runtime.put_inputs(a, state, %{"estop" => 1, "count" => 2}) end
      )

      raises(
        "input `estop` is a var_external (declared on line 3), not a var_input: only a " <>
          "var_input is set from outside",
        fn -> Runtime.call(a, state, %{"estop" => 0}, %Scan{now: 0, first: true}) end
      )
    end

    test "restart/3 puts it back at 0, keeping only the var_inputs", %{alarm: a} do
      state = Runtime.put_inputs(a, Runtime.instance(a), %{"trip" => 1})
      {_, state} = Runtime.scan(a, state, 10)
      assert %{"estop" => 1, "count" => 3} = state.env

      assert Runtime.restart(a, state, :cold).env ==
               %{"trip" => 1, "lamp" => 0, "estop" => 0, "count" => 0}
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
      assert FbType.builtin("tonr") == nil

      assert FbType.builtins() == %{
               "ton" => ton,
               "tof" => FbType.tof(),
               "tp" => FbType.tp(),
               "rto" => FbType.rto(),
               "ctu" => FbType.ctu(),
               "ctd" => FbType.ctd(),
               "ctud" => FbType.ctud()
             }
    end

    # M3-2: the other timers keep the ton's members (decision 68), each its own type.
    test "the other timers' members, and which a program may name and write" do
      for {type, times} <- [{FbType.tof(), "tt"}, {FbType.tp(), "tt"}] do
        assert Enum.map(type.members, & &1.name) == ~w(pre acc dn tt en last)
        assert Enum.map(FbType.public(type), & &1.name) == ~w(pre acc dn tt en)
        assert Enum.map(FbType.writable(type), & &1.name) == ~w(pre acc)
        assert FbType.builtin(String.upcase(type.name)) == type
        assert FbType.initial(type) == FbType.initial(FbType.ton())
        assert %{kind: :timer, preset: "pre", done: "dn", times: ^times} = FbType.rules(type)
        refute type == FbType.ton()
      end
    end

    # M3-1: IEC's pins lowercased (decision 68), and the inputs only written (decision 86).
    test "the counters' members, and which a program may name and write" do
      for {type, members, writable} <- [
            {FbType.ctu(), ~w(cu r pv q cv ov), ~w(r pv)},
            {FbType.ctd(), ~w(cd ld pv q cv un), ~w(ld pv)},
            {FbType.ctud(), ~w(cu cd r ld pv qu qd cv ov un), ~w(r ld pv)}
          ] do
        assert Enum.map(type.members, & &1.name) == members
        assert Enum.map(FbType.public(type), & &1.name) == members
        assert Enum.map(FbType.writable(type), & &1.name) == writable
        assert FbType.builtin(String.upcase(type.name)) == type
        assert FbType.initial(type) == Map.new(members, &{&1, 0})
      end

      assert FbType.rules(FbType.ctud()).runs == %{ctu: {"cu", "qu"}, ctd: {"cd", "qd"}}
      assert FbType.runners() == [:ctd, :ctu, :rto, :tof, :ton, :tp]

      # An rto adds its reset input, which logic writes (decision 90).
      rto = FbType.rto()
      assert Enum.map(rto.members, & &1.name) == ~w(pre acc dn tt en r last)
      assert Enum.map(FbType.writable(rto), & &1.name) == ~w(pre acc r)
      assert {:ok, %Member{type: :bool, role: :input}} = FbType.member(rto, "r")
      assert FbType.builtin("RTO") == rto
      assert %{kind: :timer, times: "en", forecast: :retentive} = FbType.rules(rto)
      assert FbType.initial(rto) == Map.put(FbType.initial(FbType.ton()), "r", 0)
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

      raises("this configuration declares no `program`: it would run nothing", fn ->
        Runtime.start(config)
      end)
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

      raises("input `sp` is a dint: 3000000000 is outside -2147483648 to 2147483647", fn ->
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
      # M2-2: compile_files/1, the loader's one memo over several files, which a
      # configuration's loader goes through.
      assert Enum.sort(Logex.__info__(:functions)) ==
               [compile: 2, compile_file: 1, compile_files: 1]

      # M2-1: the scheduler, and its resource, `%Logex.Runtime{}`, opaque as an edit is.
      # OE-2: edited/2, internal (no doc), the one writer of a configuration edit's step
      # into the resource. M4-3: the cycle in steps, internal too (decision 118), which the
      # runner times: cycle_steps/3, cycle_step/2 and cycle_outputs/1.
      assert Enum.sort(Runtime.__info__(:functions)) ==
               [
                 __struct__: 0,
                 __struct__: 1,
                 call: 4,
                 cycle: 3,
                 cycle_outputs: 1,
                 cycle_step: 2,
                 cycle_steps: 3,
                 edited: 2,
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

      # M2-1: the configuration, its one validator and its constructor from Elixir; M2-2:
      # its compile from a configuration file's text, and from its file on disk.
      # M4-2: watchdog/1, the one rule for a task's watchdog.
      assert Enum.sort(Logex.Configuration.__info__(:functions)) == [
               __struct__: 0,
               __struct__: 1,
               check: 1,
               compile: 3,
               compile_file: 1,
               initial: 1,
               location: 1,
               new!: 1,
               watchdog: 1
             ]

      assert Enum.sort(Map.keys(Logex.Configuration.__struct__())) ==
               [:__struct__, :connections, :file, :globals, :instances, :name, :programs] ++
                 [:tasks, :warnings]

      # M2-2: a configuration file's text, read and printed back.
      assert Enum.sort(Logex.Configuration.Text.__info__(:functions)) ==
               [entries!: 1, keywords: 0, print: 1, read: 1]

      for {module, keys} <- [
            {Logex.Configuration.Task,
             [:continuous, :interval, :line, :name, :priority, :single, :watchdog]},
            {Logex.Configuration.Global, [:at, :initial, :line, :name, :type]},
            {Logex.Configuration.Instance, [:line, :name, :task, :type]},
            {Logex.Configuration.Connection, [:instance, :line, :member, :to]}
          ],
          do: assert(Enum.sort(Map.keys(Map.from_struct(struct(module)))) == keys)

      # M2-6: a task needs an interval, a single or both, which check/1 says, so a struct
      # literal enforces its name and its priority only; struct/1 above ignores which.
      # M4-2: a continuous task has no priority, so its name alone.
      enforced =
        for %{field: field, required: true} <- Logex.Configuration.Task.__info__(:struct),
            do: field

      assert Enum.sort(enforced) == [:name]

      # M2-5: an instruction's slots, the one lookup of Logex.Warnings and Logex.Edit;
      # instructionize/3, which takes the function blocks a routine may declare instances
      # of; and lowered?/1, the definition of a compiled body, which a type given must have.
      # Decision 54: recompiled/3, a block's body from its source text over the types it
      # names, trusted, which Logex.FbType.check/2 asks a type given to be.
      assert Enum.sort(Logex.Compiler.__info__(:functions)) == [
               instructionize: 1,
               instructionize: 2,
               instructionize: 3,
               instructions: 0,
               lowered?: 1,
               parse: 1,
               recompiled: 3,
               recompiled: 4,
               signature: 2,
               tokenize: 1
             ]

      # M2-4: B5's one walk of a program's IR, which the compiler, Logex.Warnings,
      # Logex.Edit and Logex.Configuration read.
      # M3-1: presets/1, every built-in instance a program runs, and counters/1 beside
      # timers/1. Decision 96: member_writes/1, the members a program writes, by path.
      # M3-4: one_shots/0 and storage_bits/1, every one-shot's storage bit, and uses_of/2,
      # one instruction's uses; since its review one_shots/1, the one-shots a program runs,
      # at any depth (decision 103).
      assert Enum.sort(Logex.Walk.__info__(:functions)) == [
               counters: 1,
               instructions: 1,
               member_writes: 1,
               one_shots: 0,
               one_shots: 1,
               presets: 1,
               storage_bits: 1,
               timers: 1,
               uses: 2,
               uses_of: 2,
               writes: 1
             ]

      assert Logex.Walk.one_shots() == [:ons, :osr, :osf]

      # The two structs a host holds and builds; OE-1 gave both `ons_blocked`, and the
      # instance `switched`; M3-3 the instance `faults`, its last scan's (decision 99).
      assert Enum.sort(Map.keys(Instance.__struct__())) ==
               [:__struct__, :env, :faults, :first, :now, :ons_blocked, :switched, :type]

      # M3-3: a minor fault, as a scan's state and a cycle's events give it, plain data.
      assert Enum.sort(Map.keys(Logex.Fault.__struct__())) ==
               [:__struct__, :file, :instruction, :kind, :line, :path]

      assert Logex.Fault.__info__(:functions) == [__struct__: 0, __struct__: 1]

      # M2-5: the scan also carries the tag table of the routine it runs, and the block types
      # it holds, the runtime's.
      assert Enum.sort(Map.keys(Scan.__struct__())) ==
               [:__struct__, :blocks, :first, :now, :ons_blocked, :tags]

      # M2-5 (fix F15): a program keeps the file it was read from; a program, and a block's
      # body, hold the block types their instances reach in one table, `blocks` (decision
      # 53).
      assert Enum.sort(Map.keys(Logex.Program.__struct__())) ==
               [:__struct__, :blocks, :file, :name, :rungs, :source, :tags, :warnings]

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

      # OE-2: the per-instance half of an edit, internal (no moduledoc), which Logex.Edit
      # calls, and a configuration's edit is to: the type-change refusals, a plan per
      # direction, the empty record, a switch and a prune.
      assert Enum.sort(Logex.Edit.Plan.__info__(:functions)) ==
               [plans: 2, plans: 3, prune: 3, record: 0, retyped: 2, switch: 4, switch: 5]

      assert {:docs_v1, _, _, _, :hidden, _, _} = Code.fetch_docs(Logex.Edit.Plan)

      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Runtime)

      assert [{{:function, :edited, 2}, _, _, :hidden, _}] =
               for({{_, :edited, _}, _, _, _, _} = doc <- docs, do: doc)

      assert Enum.sort(
               for {{:function, name, arity}, _, _, :hidden, _} <- docs,
                   name in [:cycle_steps, :cycle_step, :cycle_outputs],
                   do: {name, arity}
             ) == [cycle_outputs: 1, cycle_step: 2, cycle_steps: 3]

      # OE-2: the staged edit of a running configuration, whose struct is opaque; since
      # M4-5, accept, test and untest take the step's time too (decision 139).
      assert Enum.sort(Logex.Configuration.Edit.__info__(:functions)) == [
               __struct__: 0,
               __struct__: 1,
               accept: 2,
               accept: 3,
               assemble: 2,
               cancel: 2,
               running: 1,
               stage: 1,
               test: 2,
               test: 3,
               untest: 2,
               untest: 3
             ]

      # OE-1: the definition of a well-formed tree, which instructionize/2 checks on entry.
      assert Enum.sort(Logex.Parser.__info__(:functions)) ==
               [format_error: 1, parse: 1, well_formed!: 1]

      # M2-5: same?/2, the one definition of one version of a block, which a compile's
      # one-version check uses. Decision 53: held/1 and within/2, a type as the one table
      # holds it and as it reads inside the table, and check/2, user?/1 across the types a
      # compile is given. M3-1: the three counters, and rules/1, runners/0 and runs?/2, each
      # built-in type as data. M3-2: the other timers.
      assert Enum.sort(Logex.FbType.__info__(:functions)) == [
               __struct__: 0,
               __struct__: 1,
               builtin: 1,
               builtins: 0,
               check: 2,
               ctd: 0,
               ctu: 0,
               ctud: 0,
               held: 1,
               initial: 1,
               initial: 2,
               member: 2,
               of: 1,
               public: 1,
               rto: 0,
               rules: 1,
               runners: 0,
               runs?: 2,
               same?: 2,
               signature: 1,
               tof: 0,
               ton: 0,
               tp: 0,
               type_of: 2,
               user?: 1,
               within: 2,
               writable: 1
             ]

      # M4-1: the clock the wall-clock runner reads, a behaviour whose three checks, hidden,
      # give both clocks one message a rule, and its two clocks, the manual one a GenServer.
      assert Enum.sort(Logex.Runner.Clock.__info__(:functions)) ==
               [receiver!: 1, time!: 1, timer!: 1]

      assert Enum.sort(Logex.Runner.Clock.behaviour_info(:callbacks)) ==
               [cancel: 2, now_ms: 1, wake_at: 4]

      {:docs_v1, _, _, _, _, _, clock_docs} = Code.fetch_docs(Logex.Runner.Clock)

      assert Enum.sort(
               for {{:function, name, arity}, _, _, :hidden, _} <- clock_docs, do: {name, arity}
             ) ==
               [receiver!: 1, time!: 1, timer!: 1]

      assert Enum.sort(Logex.Runner.Clock.Monotonic.__info__(:functions)) ==
               [cancel: 2, now_ms: 1, wake_at: 4]

      assert Enum.sort(Logex.Runner.Clock.Manual.__info__(:functions)) == [
               advance: 2,
               cancel: 2,
               child_spec: 1,
               code_change: 3,
               handle_call: 3,
               handle_cast: 2,
               handle_info: 2,
               init: 1,
               now_ms: 1,
               pass: 2,
               pending: 1,
               start_link: 0,
               start_link: 1,
               terminate: 2,
               wake_at: 4
             ]

      # M4-1: the adapter behaviour, with a point as plain data, a configuration's points
      # by device and a host's bindings checked against them, and the simulated device, an
      # adapter whose device is a GenServer of its own; since M4-1's review an adapter's
      # optional check/3 of its own options, which the simulated device has.
      assert Enum.sort(Logex.IO.__info__(:functions)) == [bind!: 2, points: 1]

      assert Enum.sort(Logex.IO.behaviour_info(:callbacks)) ==
               [check: 3, close: 1, init: 3, read: 1, report: 2, write: 2]

      assert Enum.sort(Map.keys(Logex.IO.Point.__struct__())) ==
               [:__struct__, :address, :direction, :name, :type]

      assert Logex.IO.Point.__info__(:functions) == [__struct__: 0, __struct__: 1]

      assert Enum.sort(Logex.IO.Sim.__info__(:functions)) == [
               check: 3,
               child_spec: 1,
               close: 1,
               closed?: 1,
               code_change: 3,
               fail: 3,
               handle_call: 3,
               handle_cast: 2,
               handle_info: 2,
               init: 1,
               init: 3,
               outputs: 1,
               read: 1,
               reads: 1,
               report: 2,
               set: 2,
               set: 3,
               start_link: 0,
               start_link: 1,
               terminate: 2,
               write: 2,
               writes: 1
             ]

      # M4-3: the wall-clock runner, a GenServer, its every call through its mailbox; and
      # M4-4's restart/2; and M4-5's forcing and an edit's steps.
      assert Enum.sort(Logex.Runner.__info__(:functions)) == [
               accept: 2,
               assemble: 1,
               cancel: 1,
               child_spec: 1,
               code_change: 3,
               force: 3,
               get: 2,
               get!: 2,
               handle_call: 3,
               handle_cast: 2,
               handle_info: 2,
               init: 1,
               restart: 2,
               start_link: 1,
               status: 1,
               stop: 1,
               stop: 2,
               subscribe: 1,
               subscribe: 2,
               terminate: 2,
               test: 1,
               unforce: 2,
               unforce_all: 1,
               unsubscribe: 1,
               untest: 1
             ]

      # M4-3: each bound device's process, internal (no moduledoc), which the runner starts.
      assert Enum.sort(Logex.Runner.Device.__info__(:functions)) == [
               child_spec: 1,
               close: 1,
               close: 2,
               code_change: 3,
               handle_call: 3,
               handle_cast: 2,
               handle_info: 2,
               init: 1,
               open: 1,
               open: 2,
               refresh: 3,
               refused: 2,
               release: 2,
               release: 3,
               reread: 1,
               reread: 2,
               start_link: 1,
               taken: 2,
               terminate: 2,
               write: 2,
               write: 3,
               zero: 1,
               zero: 2
             ]

      assert {:docs_v1, _, _, _, :hidden, _, _} = Code.fetch_docs(Logex.Runner.Device)
    end
  end
end
