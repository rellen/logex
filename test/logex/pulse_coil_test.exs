defmodule Logex.PulseCoilTest do
  @moduledoc """
  M3-4: the pulse coils `osr` and `osf`, IEC's transition-sensing coils in the conventional
  set's form, a storage bit and a pulse bit (docs/organisation.md decisions 69, 80 and 100
  to 102; docs/naming.md, `osr` and `osf`), each rule of a scan pinned from source through
  `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted. The
  compiler's refusals and warnings are `validation_test.exs`'s, an edit's rules
  `edit_test.exs`'s, and the configuration's `configuration_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Program, Runtime, Scan}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  # Scans `program` from `state` once per entry of `inputs`, 10 ms apart: each scan's
  # values at `at`, a list of paths, read as the env holds them.
  defp trace(program, inputs, at, state \\ nil) do
    state = state || Runtime.instance(program)

    {values, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
        {Enum.map(at, &get_in(state.env, &1)), state}
      end)

    values
  end

  # Each scan's value of one tag.
  defp tag(program, inputs, name, state \\ nil),
    do: for([value] <- trace(program, inputs, [[name]], state), do: value)

  defp go(levels), do: Enum.map(levels, &%{"go" => &1})

  # A new instance scanned once per entry of `inputs`: the state after.
  defp drive(program, inputs),
    do:
      Enum.reduce(inputs, Runtime.instance(program), fn input, state ->
        {_out, state} = Runtime.scan(program, Runtime.put_inputs(program, state, input), 10)
        state
      end)

  @coils """
  var_input go bool
  var_output rise bool
  var_output fall bool
  var_output y bool
  var_output z bool
  var sr bool
  var sf bool
  xic go osr sr rise ote y
  xic go osf sf fall ote z
  """

  describe "osr" do
    test "sets its pulse bit for the one scan in which the power it receives rises: not " <>
           "while it stays true, and again after a drop" do
      p = c!(@coils)
      levels = [0, 1, 1, 1, 0, 1, 0, 0, 1]
      assert tag(p, go(levels), "rise") == [0, 1, 0, 0, 0, 1, 0, 0, 1]
    end

    test "its storage bit holds the power it received at its last run, set on a true rung " <>
           "and cleared on a false one" do
      p = c!(@coils)
      assert tag(p, go([0, 1, 1, 0, 1, 0]), "sr") == [0, 1, 1, 0, 1, 0]
    end

    test "a storage bit at 1 gives no pulse, and one at 0 does, on a true rung" do
      p = c!(@coils)
      {_, s} = Runtime.call(p, Runtime.instance(p), %{}, %Scan{now: 0, first: true})

      for {held, pulse} <- [{0, 1}, {1, 0}] do
        state = %{s | env: %{s.env | "sr" => held}}
        assert tag(p, go([1]), "rise", state) == [pulse]
      end
    end
  end

  describe "osf" do
    test "sets its pulse bit for the one scan in which the power it receives falls, seen by " <>
           "its run on a false rung" do
      p = c!(@coils)
      levels = [1, 1, 0, 0, 1, 0, 1, 1, 0]
      assert tag(p, go(levels), "fall") == [0, 0, 1, 0, 0, 1, 0, 0, 1]
    end

    test "its storage bit holds the power it received at its last run" do
      p = c!(@coils)
      assert tag(p, go([0, 1, 1, 0, 1, 0]), "sf") == [0, 1, 1, 0, 1, 0]
    end

    test "a storage bit at 1 gives a pulse on a false rung, and one at 0 none" do
      p = c!(@coils)
      {_, s} = Runtime.call(p, Runtime.instance(p), %{}, %Scan{now: 0, first: true})

      for {held, pulse} <- [{1, 1}, {0, 0}] do
        state = %{s | env: %{s.env | "sf" => held}}
        assert tag(p, go([0]), "fall", state) == [pulse]
      end
    end

    test "a true rung clears its pulse bit and sets its storage bit" do
      p = c!(@coils)
      {_, s} = Runtime.call(p, Runtime.instance(p), %{}, %Scan{now: 0, first: true})
      state = %{s | env: %{s.env | "fall" => 1, "sf" => 0}}
      assert trace(p, go([1]), [["fall"], ["sf"]], state) == [[0, 1]]
    end
  end

  describe "both coils" do
    test "pass on the power they receive, as `ote` does, so what follows sees the rung " <>
           "(decision 100)" do
      p = c!(@coils)
      levels = [0, 1, 1, 0, 1, 0, 0]
      assert tag(p, go(levels), "y") == levels
      assert tag(p, go(levels), "z") == levels
    end

    test "on a leg of a group, each sees its leg's power and passes it on to the group" do
      p =
        c!("""
        var_input go bool
        var_input other bool
        var_output rise bool
        var_output fall bool
        var_output y bool
        var sr bool
        var sf bool
        ( xic go osr sr rise | xic other osf sf fall ) ote y
        """)

      inputs =
        for {g, o} <- [{0, 1}, {1, 1}, {1, 0}, {0, 0}, {0, 1}],
            do: %{"go" => g, "other" => o}

      assert trace(p, inputs, [["rise"], ["fall"], ["y"]]) == [
               [0, 0, 1],
               [1, 0, 1],
               [0, 1, 1],
               [0, 0, 0],
               [0, 0, 1]
             ]
    end

    test "one after another on a rung each receives the power the one before passes on" do
      p =
        c!("""
        var_input go bool
        var_output rise bool
        var_output fall bool
        var sr bool
        var sf bool
        xic go osr sr rise osf sf fall
        """)

      assert trace(p, go([0, 1, 0, 1, 0]), [["rise"], ["fall"]]) == [
               [0, 0],
               [1, 0],
               [0, 1],
               [1, 0],
               [0, 1]
             ]
    end

    test "never pulse on an instance's first scan, whatever the storage bit holds (decision " <>
           "69), and write both bits as the rung says" do
      for initial <- ["", " 0", " 1"] do
        src =
          String.replace(
            @coils,
            "var sr bool\nvar sf bool",
            "var sr bool#{initial}\nvar sf bool#{initial}"
          )

        p = c!(src)
        assert trace(p, go([1]), [["rise"], ["sr"]]) == [[0, 1]], "osr, `#{initial}`"
        assert trace(p, go([0]), [["fall"], ["sf"]]) == [[0, 0]], "osf, `#{initial}`"
        assert trace(p, go([0, 1, 0]), [["rise"], ["fall"]]) == [[0, 0], [1, 0], [0, 1]]
      end
    end

    test "a pulse bit declared 1 is cleared by the first scan, whatever the rung" do
      p = c!(String.replace(@coils, "var_output rise bool", "var_output rise bool 1"))
      assert tag(p, go([1]), "rise") == [0]
      assert tag(p, go([0]), "rise") == [0]
    end

    test "nor on the first scan after a restart, cold or warm, with the rung as it was" do
      p = c!(String.replace(@coils, "var sf bool", "var sf bool 1"))

      for mode <- [:cold, :warm] do
        held = drive(p, go([0, 1]))
        again = Runtime.restart(p, held, mode)
        assert trace(p, [%{}, %{"go" => 0}, %{"go" => 1}], [["rise"]], again) == [[0], [0], [1]]

        # The storage bit starts again at 1, the rung still false.
        low = drive(p, go([1, 0]))
        again = Runtime.restart(p, low, mode)
        assert trace(p, [%{}, %{"go" => 1}, %{"go" => 0}], [["fall"]], again) == [[0], [0], [1]]
      end
    end

    test "a storage bit holding anything is read as a contact reads it" do
      p = c!(@coils)

      for {junk, rises, falls} <- [
            {0, 1, 0},
            {nil, 1, 0},
            {false, 1, 0},
            {0.0, 1, 0},
            {5, 0, 1},
            {"x", 0, 1},
            {true, 0, 1}
          ] do
        env = Map.merge(Program.initial_env(p), %{"sr" => junk, "sf" => junk})
        state = %Instance{type: "m", env: env, now: 0, first: false}
        assert trace(p, go([1]), [["rise"], ["sr"]], state) == [[rises, 1]], inspect(junk)
        assert trace(p, go([0]), [["fall"], ["sf"]], state) == [[falls, 0]], inspect(junk)
      end
    end

    test "one whose storage bit an instance's block list holds gives no pulse on that scan, " <>
           "still writes both bits, and pulses on the next edge (decision 21)" do
      p = c!(@coils)
      {_, s} = Runtime.call(p, Runtime.instance(p), go([0]) |> hd(), %Scan{now: 0, first: true})
      blocked = %{s | ons_blocked: ["sf", "sr"]}

      assert [[0, 1, 0, 1, 1, 1]] =
               trace(p, go([1]), [["rise"], ["sr"], ["fall"], ["sf"], ["y"], ["z"]], blocked)

      assert tag(p, go([1, 0, 1]), "rise", blocked) == [0, 0, 1]

      {_, high} = Runtime.call(p, s, %{"go" => 1}, %Scan{now: 10, first: false})
      blocked = %{high | ons_blocked: ["sf"]}
      assert trace(p, go([0]), [["fall"], ["sf"], ["z"]], blocked) == [[0, 0, 0]]
      assert tag(p, go([0, 1, 0]), "fall", blocked) == [0, 0, 1]

      # A bit the list does not name pulses on a real edge, and a scan empties the list.
      other = %{high | ons_blocked: ["rise", "fall", "s9"]}
      assert tag(p, go([0]), "fall", other) == [1]
      assert {_, %Instance{ons_blocked: []}} = Runtime.scan(p, blocked, 10)
    end

    test "a pulse bit may be a member logic may write, a one-scan reset of a counter" do
      p =
        c!("""
        var_input eye bool
        var_input clear bool
        var boxes ctu
        var s bool
        xic clear osr s boxes.r
        xic eye ctu boxes 9
        """)

      inputs =
        for {eye, clear} <- [{0, 0}, {1, 0}, {0, 0}, {1, 1}, {0, 1}, {1, 1}, {0, 0}, {1, 0}],
            do: %{"eye" => eye, "clear" => clear}

      # The press resets the count once, at the scan it rises, and the button held after it
      # resets nothing: the box under it counts.
      assert trace(p, inputs, [["boxes", "cv"]]) == [[0], [1], [1], [0], [0], [1], [1], [2]]
    end

    test "inside a function block they are the block's, and a frozen block holds both bits: " <>
           "a pulse set at its body's last run stays on until it next runs, and an edge that " <>
           "comes and goes while it is frozen is never seen (decision 102)" do
      {:ok, edge} =
        Logex.compile(
          "function_block edge\nvar_input in bool\nvar_output up bool\nvar_output down bool\n" <>
            "var sr bool\nvar sf bool\nxic in osr sr up\nxic in osf sf down",
          name: "edge"
        )

      p =
        c!(
          "var_input on bool\nvar_input go bool\nvar_output up bool\nvar_output down bool\n" <>
            "var e edge\nxic on cal e go up down",
          [edge]
        )

      inputs =
        for {on, go} <- [{1, 0}, {1, 1}, {0, 1}, {0, 0}, {0, 1}, {1, 1}, {1, 0}, {0, 0}, {1, 0}],
            do: %{"on" => on, "go" => go}

      assert trace(p, inputs, [["up"], ["down"], ["e", "sr"]]) == [
               [0, 0, 0],
               [1, 0, 1],
               [1, 0, 1],
               [1, 0, 1],
               [1, 0, 1],
               [0, 0, 1],
               [0, 1, 0],
               [0, 1, 0],
               [0, 0, 0]
             ]
    end

    test "inside a function block whose first run comes after the instance's first scan, " <>
           "each reads its storage bit as declared: an osf declared 1 pulses on a false rung, " <>
           "a fall that never happened, and an osr held true pulses (decision 102)" do
      {:ok, edge} =
        Logex.compile(
          "function_block edge\nvar_input in bool\nvar_output up bool\nvar_output down bool\n" <>
            "var sr bool\nvar sf bool 1\nxic in osr sr up\nxic in osf sf down",
          name: "edge"
        )

      p =
        c!(
          "var_input on bool\nvar_input go bool\nvar_output up bool\nvar_output down bool\n" <>
            "var e edge\nxic on cal e go up down",
          [edge]
        )

      at = [["up"], ["down"]]

      # `go` held at 0 from the start: the block's first run, at the second scan, sees `sf`
      # at its declared 1, and its osf pulses.
      assert trace(p, [%{"on" => 0, "go" => 0}, %{"on" => 1}, %{}], at) ==
               [[0, 0], [0, 1], [0, 0]]

      # `go` held at 1 from the start: `sr` is still its declared 0, and its osr pulses.
      assert trace(p, [%{"on" => 0, "go" => 1}, %{"on" => 1}, %{}], at) ==
               [[0, 0], [1, 0], [0, 0]]

      # The same block run from the instance's first scan pulses neither (decision 69).
      assert trace(p, [%{"on" => 1, "go" => 0}, %{}], at) == [[0, 0], [0, 0]]
      assert trace(p, [%{"on" => 1, "go" => 1}, %{}], at) == [[0, 0], [0, 0]]
    end
  end
end
