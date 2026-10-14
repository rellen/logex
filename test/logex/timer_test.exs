defmodule Logex.TimerTest do
  @moduledoc """
  M3-2: the timers beside `ton`, the off-delay `tof` (docs/organisation.md decisions 68,
  69, 73 and 93; docs/naming.md, `tof`), each rule of a scan pinned from source through `Logex.Runtime.call/4`, a test that fails when the rule
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

  test "a timer's type given where a program goes is refused, naming its instruction" do
    assert_raise ArgumentError,
                 "`tof` is a function block type, which runs inside a program through `tof`: " <>
                   "an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.tof()) end
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
