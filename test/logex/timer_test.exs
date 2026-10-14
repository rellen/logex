defmodule Logex.TimerTest do
  @moduledoc """
  M3-2: the timers beside `ton`, the off-delay `tof`, the pulse `tp` and the retentive
  `rto` (docs/organisation.md decisions 68, 69, 73 to 76, 90 and 93 to 95; docs/naming.md,
  `tof`, `tp` and `rto`), each rule of a scan pinned from source through `Logex.Runtime.call/4`, a test that fails when the rule
  alone is reverted. The compiler's refusals and warnings are `validation_test.exs`'s, an
  edit's rules `edit_test.exs`'s, and the configuration's warning `configuration_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Runtime, Scan}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  # Scans `program` from `state` once per entry of `inputs`, 10 ms apart: each scan's
  # value at `at`, a timer's map or a member, read as the env holds it.
  defp trace(program, inputs, at, state \\ nil) do
    state = state || Runtime.instance(program)

    {values, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
        {get_in(state.env, at), state}
      end)

    values
  end

  # Each scan's timer, its members but `last`, as `{acc, dn, tt, en}`.
  defp members(program, inputs, timer, state \\ nil),
    do:
      for(
        t <- trace(program, inputs, [timer], state),
        do: {t["acc"], t["dn"], t["tt"], t["en"]}
      )

  defp levels(name, levels), do: Enum.map(levels, &%{name => &1})

  @fan """
  var_input motor bool
  var_output fan bool
  var run_on tof
  xic motor tof run_on 30
  xic run_on.dn ote fan
  """

  describe "tof" do
    test "energised, `.dn` and `.en` set and `.acc` and `.tt` 0; the falling edge starts " <>
           "the delay, adding nothing; `.dn` drops at the preset, and stays off at rest" do
      p = c!(@fan)

      assert members(p, levels("motor", [1, 1, 0, 0, 0, 0, 0, 0]), "run_on") == [
               {0, 1, 0, 1},
               {0, 1, 0, 1},
               {0, 1, 1, 0},
               {10, 1, 1, 0},
               {20, 1, 1, 0},
               {30, 0, 0, 0},
               {30, 0, 0, 0},
               {30, 0, 0, 0}
             ]
    end

    test "a rung true again during the delay ends it, `.dn` still set, and the next fall " <>
           "starts it from 0" do
      p = c!(@fan)

      assert members(p, levels("motor", [1, 0, 0, 1, 0, 0, 0, 0]), "run_on") == [
               {0, 1, 0, 1},
               {0, 1, 1, 0},
               {10, 1, 1, 0},
               {0, 1, 0, 1},
               {0, 1, 1, 0},
               {10, 1, 1, 0},
               {20, 1, 1, 0},
               {30, 0, 0, 0}
             ]
    end

    test "a new instance is at rest: a rung false at start runs no delay, and a restart's " <>
           "first scan likewise (decision 69)" do
      p = c!(@fan)
      assert trace(p, levels("motor", [0, 0]), ["run_on", "dn"]) == [0, 0]

      state = Runtime.instance(p)
      {_, state} = Runtime.call(p, state, %{"motor" => 1}, %Scan{now: 0, first: true})
      state = Runtime.restart(p, state, :warm)
      assert state.env["run_on"]["en"] == 0
      assert trace(p, levels("motor", [0, 0]), ["run_on", "dn"], state) == [0, 0]
    end

    test "with a preset of 0, `.dn` drops on the falling edge's own scan" do
      p = c!(String.replace(@fan, "run_on 30", "run_on 0"))

      assert members(p, levels("motor", [1, 0, 0]), "run_on") == [
               {0, 1, 0, 1},
               {0, 0, 0, 0},
               {0, 0, 0, 0}
             ]
    end

    test "raising `.pre` at rest starts nothing; raising it during the delay lengthens it" do
      p = c!("var_input more bool\n" <> @fan <> "xic more move 50 run_on.pre")
      inputs = levels("motor", [1, 0, 0, 0, 0]) ++ [%{"more" => 1}, %{}, %{}]
      assert trace(p, inputs, ["run_on", "dn"]) == [1, 1, 1, 1, 0, 0, 0, 0]

      inputs = levels("motor", [1, 0, 0]) ++ [%{"more" => 1}, %{}, %{}, %{}]
      assert trace(p, inputs, ["run_on", "dn"]) == [1, 1, 1, 1, 1, 1, 0]
    end

    test "`.acc` logic writes during the delay counts from there, a negative one from 0" do
      p =
        c!(
          "var_input skip bool\nvar_input back dint\n" <> @fan <> "xic skip move back run_on.acc"
        )

      inputs = levels("motor", [1, 0]) ++ [%{"skip" => 1, "back" => 25}, %{"skip" => 0}]
      assert trace(p, inputs, ["run_on", "dn"]) == [1, 1, 1, 0]

      # A negative `.acc` counts from 0: 3 runs of 10 ms more, as from the fall.
      state = %{Runtime.instance(p) | first: false}
      state = put_in(state.env["run_on"], %{state.env["run_on"] | "acc" => -40, "tt" => 1})
      assert trace(p, [%{}, %{}, %{}], ["run_on", "acc"], state) == [10, 20, 30]
    end

    test "`last` is the time it last ran, energised, in its delay or at rest (decision 5)" do
      p = c!(@fan)
      inputs = levels("motor", [1, 0, 0, 0, 0, 0])
      assert trace(p, inputs, ["run_on", "last"]) == [10, 20, 30, 40, 50, 60]
    end

    test "a negative `.pre` times as 0: `.acc` stays in 0..max(.pre, 0)" do
      p = c!("var_input low bool\nvar_input to dint\n" <> @fan <> "xic low move to run_on.pre")
      inputs = levels("motor", [1, 0, 0]) ++ [%{"low" => 1, "to" => -5}, %{"low" => 0}]
      assert trace(p, inputs, ["run_on", "acc"]) == [0, 0, 10, 20, 0]
      assert trace(p, inputs, ["run_on", "dn"]) == [1, 1, 1, 1, 0]
    end

    test "a hand-built env's timer comes back well-formed" do
      p = c!(@fan)
      state = put_in(%{Runtime.instance(p) | first: false}.env["run_on"], %{"en" => true})

      assert [%{"pre" => 0, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 10}] =
               trace(p, [%{"motor" => 0}], ["run_on"], state)
    end

    test "inside a function block a frozen `tof` catches up when the block next runs " <>
           "(decision 8)" do
      {:ok, cell} =
        Logex.compile(
          "function_block cell\nvar_input go bool\nvar_output held bool\nvar t tof\n" <>
            "xic go tof t 30\nxic t.dn ote held",
          name: "cell"
        )

      p =
        c!(
          "var_input on bool\nvar_input go bool\nvar_output held bool\nvar s1 cell\n" <>
            "xic on cal s1 go held",
          [cell]
        )

      inputs =
        for {on, go} <- [{1, 1}, {1, 0}, {0, 0}, {0, 0}, {0, 0}, {1, 0}],
            do: %{"on" => on, "go" => go}

      assert trace(p, inputs, ["s1", "t", "acc"]) == [0, 0, 0, 0, 0, 30]
      assert trace(p, inputs, ["s1", "t", "dn"]) == [1, 1, 1, 1, 1, 0]
    end
  end

  @horn """
  var_input fault bool
  var_output horn bool
  var horn_pulse tp
  xic fault tp horn_pulse 30
  xic horn_pulse.tt ote horn
  """

  describe "tp" do
    test "a rising edge starts a pulse of exactly its preset on `.tt`, whatever the rung " <>
           "does meanwhile; an edge during it starts nothing (decisions 74 and 94)" do
      p = c!(@horn)

      assert members(p, levels("fault", [0, 1, 0, 1, 0, 0, 0, 0]), "horn_pulse") == [
               {0, 0, 0, 0},
               {0, 0, 1, 1},
               {10, 0, 1, 0},
               {20, 0, 1, 1},
               {0, 0, 0, 0},
               {0, 0, 0, 0},
               {0, 0, 0, 0},
               {0, 0, 0, 0}
             ]

      assert trace(p, levels("fault", [0, 1, 0, 1, 0, 0]), ["horn"]) == [0, 1, 1, 1, 0, 0]
    end

    test "`.dn` is set as the pulse ends with the rung true and holds while it does; a " <>
           "pulse once ended needs the rung to fall and rise again" do
      p = c!(@horn)

      assert members(p, levels("fault", [0, 1, 1, 1, 1, 1, 0, 1]), "horn_pulse") == [
               {0, 0, 0, 0},
               {0, 0, 1, 1},
               {10, 0, 1, 1},
               {20, 0, 1, 1},
               {30, 1, 0, 1},
               {30, 1, 0, 1},
               {0, 0, 0, 0},
               {0, 0, 1, 1}
             ]
    end

    test "no pulse on the first scan, though the fault is present at start, nor on a " <>
           "restart's (decisions 69 and 75)" do
      p = c!(@horn)
      assert trace(p, levels("fault", [1, 1, 0, 1]), ["horn"]) == [0, 0, 0, 1]

      state = Runtime.instance(p)
      {_, state} = Runtime.call(p, state, %{"fault" => 0}, %Scan{now: 0, first: true})
      state = Runtime.restart(p, state, :cold)
      assert trace(p, levels("fault", [1, 1]), ["horn"], state) == [0, 0]
    end

    test "with a preset of 0 the pulse starts and ends on one scan, `.tt` never set and " <>
           "`.dn` set" do
      p = c!(String.replace(@horn, "horn_pulse 30", "horn_pulse 0"))

      assert members(p, levels("fault", [0, 1, 1, 0]), "horn_pulse") == [
               {0, 0, 0, 0},
               {0, 1, 0, 1},
               {0, 1, 0, 1},
               {0, 0, 0, 0}
             ]
    end

    test "raising `.pre` once the pulse has ended starts nothing; during it, lengthens it" do
      p = c!("var_input more bool\n" <> @horn <> "xic more move 50 horn_pulse.pre")
      inputs = levels("fault", [0, 1, 1, 1, 1]) ++ [%{"more" => 1}, %{}, %{}]
      assert trace(p, inputs, ["horn"]) == [0, 1, 1, 1, 0, 0, 0, 0]

      inputs = levels("fault", [0, 1]) ++ [%{"more" => 1}, %{}, %{}, %{}, %{}, %{}]
      assert trace(p, inputs, ["horn"]) == [0, 1, 1, 1, 1, 1, 0, 0]
    end

    test "`.acc` logic writes during the pulse counts from there, a negative one from 0, " <>
           "and a negative `.pre` ends a pulse at once" do
      p =
        c!(
          "var_input skip bool\nvar_input back dint\n" <>
            @horn <> "xic skip move back horn_pulse.acc"
        )

      inputs = levels("fault", [0, 1]) ++ [%{"skip" => 1, "back" => 25}, %{"skip" => 0}]
      assert trace(p, inputs, ["horn"]) == [0, 1, 1, 0]

      # Written before the edge, it is no part of the pulse, which starts from 0.
      inputs = [%{"skip" => 1, "back" => 25}, %{"skip" => 0, "fault" => 1}, %{}, %{}, %{}]
      assert trace(p, inputs, ["horn"]) == [0, 1, 1, 1, 0]

      state = %{Runtime.instance(p) | first: false}
      timer = %{state.env["horn_pulse"] | "acc" => -40, "tt" => 1, "en" => 1}
      state = put_in(state.env["horn_pulse"], timer)
      assert trace(p, [%{}, %{}, %{}], ["horn_pulse", "acc"], state) == [10, 20, 0]

      neg = put_in(state.env["horn_pulse"], %{timer | "pre" => -5, "acc" => 0})

      assert trace(p, [%{"fault" => 1}], ["horn_pulse"], neg) == [
               %{"pre" => -5, "acc" => 0, "dn" => 1, "tt" => 0, "en" => 1, "last" => 10}
             ]
    end

    test "`last` is the time it last ran, and a hand-built env's timer comes back well-formed" do
      p = c!(@horn)

      assert trace(p, levels("fault", [1, 0, 1, 1, 0]), ["horn_pulse", "last"]) == [
               10,
               20,
               30,
               40,
               50
             ]

      state = put_in(%{Runtime.instance(p) | first: false}.env["horn_pulse"], %{"tt" => true})

      assert [%{"pre" => 0, "acc" => 0, "dn" => 1, "tt" => 0, "en" => 1, "last" => 10}] =
               trace(p, [%{"fault" => 1}], ["horn_pulse"], state)
    end

    test "inside a function block a frozen `tp` ends its pulse when the block next runs, " <>
           "and sees an edge against its last run (decision 8)" do
      {:ok, cell} =
        Logex.compile(
          "function_block cell\nvar_input go bool\nvar_output on bool\nvar t tp\n" <>
            "xic go tp t 30\nxic t.tt ote on",
          name: "cell"
        )

      p =
        c!(
          "var_input run bool\nvar_input go bool\nvar_output on bool\nvar s1 cell\n" <>
            "xic run cal s1 go on",
          [cell]
        )

      inputs =
        for {run, go} <- [{1, 0}, {1, 1}, {0, 0}, {0, 0}, {0, 1}, {1, 1}, {1, 0}, {0, 1}, {1, 1}],
            do: %{"run" => run, "go" => go}

      assert trace(p, inputs, ["s1", "t", "tt"]) == [0, 1, 1, 1, 1, 0, 0, 0, 1]
    end
  end

  @lube """
  var_input motor bool
  var_input greased bool
  var_output grease_lamp bool
  var lube rto
  xic greased ote lube.r
  xic motor rto lube 30
  xic lube.dn ote grease_lamp
  """

  describe "rto" do
    test "energised it times as a ton; de-energised it keeps `.acc` and `.dn`, `.en` and " <>
           "`.tt` going to 0, so its time adds up across the rung's drops (decision 76)" do
      p = c!(@lube)

      assert members(p, levels("motor", [1, 1, 0, 0, 1, 1, 0, 1, 1, 1]), "lube") == [
               {0, 0, 1, 1},
               {10, 0, 1, 1},
               {10, 0, 0, 0},
               {10, 0, 0, 0},
               {10, 0, 1, 1},
               {20, 0, 1, 1},
               {20, 0, 0, 0},
               {20, 0, 1, 1},
               {30, 1, 0, 1},
               {30, 1, 0, 1}
             ]

      # Done, it stays done across a false rung.
      inputs = levels("motor", [1, 1, 1, 1, 0, 0])
      assert trace(p, inputs, ["grease_lamp"]) == [0, 0, 0, 1, 1, 1]
    end

    test "`r` puts `.acc`, `.dn` and `.tt` to 0 at its next run, whatever the rung, and no " <>
           "time is added while it is held; it times again from the last scan that saw it " <>
           "(decisions 90 and 95)" do
      p = c!(@lube)

      inputs =
        levels("motor", [1, 1, 1, 1]) ++
          [%{"greased" => 1}, %{"motor" => 0}, %{"motor" => 1}, %{"greased" => 0}, %{}]

      assert members(p, inputs, "lube") == [
               {0, 0, 1, 1},
               {10, 0, 1, 1},
               {20, 0, 1, 1},
               {30, 1, 0, 1},
               {0, 0, 0, 1},
               {0, 0, 0, 0},
               {0, 0, 0, 1},
               {10, 0, 1, 1},
               {20, 0, 1, 1}
             ]

      assert trace(p, inputs, ["lube", "r"]) == [0, 0, 0, 0, 1, 1, 1, 0, 0]
      assert trace(p, inputs, ["lube", "pre"]) == List.duplicate(30, 9)
    end

    test "a reset rung below the timer's shows at the next scan, as a counter's (decision 91)" do
      below =
        c!(
          "var_input motor bool\nvar_input greased bool\nvar lube rto\nxic motor rto lube 30\n" <>
            "xic greased ote lube.r"
        )

      inputs = levels("motor", [1, 1]) ++ [%{"greased" => 1}, %{"greased" => 0}, %{}]
      assert trace(below, inputs, ["lube", "acc"]) == [0, 10, 20, 0, 10]
    end

    test "every restart, warm or cold, starts it at 0, until `retain` lands (decision 76)" do
      p = c!(@lube)
      state = Runtime.instance(p)

      {_, state} =
        Enum.reduce(1..3, {nil, state}, fn _, {_, state} ->
          Runtime.call(p, state, %{"motor" => 1}, %Scan{now: state.now + 10, first: state.first})
        end)

      assert state.env["lube"]["acc"] == 20

      for mode <- [:warm, :cold] do
        restarted = Runtime.restart(p, state, mode)

        assert restarted.env["lube"] == %{
                 "pre" => 30,
                 "acc" => 0,
                 "dn" => 0,
                 "tt" => 0,
                 "en" => 0,
                 "r" => 0,
                 "last" => 0
               }
      end
    end

    test "`.acc` logic writes counts from there, a negative one from 0, and a negative " <>
           "`.pre` times as 0" do
      p =
        c!("var_input skip bool\nvar_input back dint\n" <> @lube <> "xic skip move back lube.acc")

      inputs =
        levels("motor", [1]) ++ [%{"motor" => 0, "skip" => 1, "back" => 25}, %{"skip" => 0}]

      inputs = inputs ++ [%{"motor" => 1}, %{}]
      assert trace(p, inputs, ["lube", "acc"]) == [0, 25, 25, 25, 30]

      state = %{Runtime.instance(p) | first: false}
      timer = %{state.env["lube"] | "acc" => -40, "en" => 1}
      state = put_in(state.env["lube"], timer)
      assert trace(p, levels("motor", [1, 1]), ["lube", "acc"], state) == [10, 20]

      neg = put_in(state.env["lube"], %{timer | "pre" => -5, "acc" => 3})
      assert [%{"acc" => 0, "dn" => 1}] = trace(p, levels("motor", [1]), ["lube"], neg)

      # De-energised, a hand-built `.acc` is kept as it is, and a bit read as a contact.
      odd = put_in(state.env["lube"], %{timer | "acc" => 7, "dn" => true})
      assert [%{"acc" => 7, "dn" => 1, "en" => 0}] = trace(p, [%{}], ["lube"], odd)
    end

    test "`last` is the time it last ran, energised, de-energised or reset" do
      p = c!(@lube)
      inputs = levels("motor", [1, 0]) ++ [%{"greased" => 1}, %{"greased" => 0, "motor" => 1}]
      assert trace(p, inputs, ["lube", "last"]) == [10, 20, 30, 40]
    end

    test "inside a function block a frozen `rto` catches up when the block next runs " <>
           "(decision 8)" do
      {:ok, cell} =
        Logex.compile(
          "function_block cell\nvar_input go bool\nvar_output done bool\nvar t rto\n" <>
            "xic go rto t 30\nxic t.dn ote done",
          name: "cell"
        )

      p =
        c!(
          "var_input on bool\nvar_input go bool\nvar_output done bool\nvar s1 cell\n" <>
            "xic on cal s1 go done",
          [cell]
        )

      inputs =
        for {on, go} <- [{1, 1}, {1, 1}, {0, 1}, {0, 1}, {1, 1}, {1, 0}],
            do: %{"on" => on, "go" => go}

      assert trace(p, inputs, ["s1", "t", "acc"]) == [0, 10, 10, 10, 30, 30]
    end
  end

  test "a timer's type given where a program goes is refused, naming its instruction" do
    assert_raise ArgumentError,
                 "`tof` is a function block type, which runs inside a program through `tof`: " <>
                   "an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.tof()) end

    assert_raise ArgumentError,
                 "`tp` is a function block type, which runs inside a program through `tp`: " <>
                   "an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.tp()) end

    assert_raise ArgumentError,
                 "`rto` is a function block type, which runs inside a program through `rto`: " <>
                   "an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.rto()) end
  end

  test "a restart, warm or cold, starts a timer again at its preset" do
    p = c!(@fan)
    state = %{Runtime.instance(p) | first: false}
    timer = %{state.env["run_on"] | "acc" => 20, "dn" => 1, "tt" => 1, "pre" => 70}

    for mode <- [:warm, :cold] do
      state = Runtime.restart(p, put_in(state.env["run_on"], timer), mode)

      assert state.env["run_on"] == %{
               "pre" => 30,
               "acc" => 0,
               "dn" => 0,
               "tt" => 0,
               "en" => 0,
               "last" => 0
             }
    end
  end
end
