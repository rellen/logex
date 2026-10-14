defmodule Logex.CounterTest do
  @moduledoc """
  M3-1: IEC's counters, `ctu`, `ctd` and `ctud` (docs/organisation.md decisions 67 to 71
  and 84 to 89; docs/naming.md, `ctu`, `ctd` and `ctud`), each rule of a scan pinned from
  source through `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted.
  The compiler's refusals and warnings are `validation_test.exs`'s, an edit's rules
  `edit_test.exs`'s, and the configuration's warning `configuration_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Runtime, Scan}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  # Scans `program` from `state` once per entry of `inputs`, 10 ms apart: each scan's
  # value at `at`, a counter's map or a member, read as the env holds it.
  defp trace(program, inputs, at, state \\ nil) do
    state = state || Runtime.instance(program)

    {values, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
        {get_in(state.env, at), state}
      end)

    values
  end

  @boxes """
  var_input eye bool
  var_input rst bool
  var boxes ctu
  xic rst ote boxes.r
  xic eye ctu boxes 3
  """

  defp eye(levels), do: Enum.map(levels, &%{"eye" => &1})

  describe "ctu" do
    test "counts each rising edge of its rung once, and none while it stays true" do
      p = c!(@boxes)

      assert trace(p, eye([0, 1, 1, 1, 0, 1, 0, 0, 1]), ["boxes", "cv"]) == [
               0,
               1,
               1,
               1,
               1,
               2,
               2,
               2,
               3
             ]
    end

    test "counts nothing on an instance's first scan, though its rung is already true " <>
           "(decision 69), and a restart's first scan likewise" do
      p = c!(@boxes)
      assert trace(p, eye([1, 1, 0, 1]), ["boxes", "cv"]) == [0, 0, 0, 1]

      state = Runtime.instance(p)
      {_, state} = Runtime.call(p, state, %{"eye" => 0}, %Scan{now: 0, first: true})
      {_, state} = Runtime.call(p, state, %{"eye" => 1}, %Scan{now: 10, first: false})
      assert state.env["boxes"]["cv"] == 1
      state = Runtime.restart(p, state, :cold)
      assert state.env["boxes"]["cv"] == 0
      assert trace(p, eye([1, 0, 1]), ["boxes", "cv"], state) == [0, 0, 1]
    end

    test "`q` is `cv >= pv`, from the preset on the instruction" do
      p = c!(@boxes)
      assert Logex.Program.initial_env(p)["boxes"]["pv"] == 3
      assert trace(p, eye([0, 1, 0, 1, 0, 1, 0, 1]), ["boxes", "q"]) == [0, 0, 0, 0, 0, 1, 1, 1]
    end

    test "`r` puts `cv` to 0 at the counter's next run, and no edge counts while it is 1" do
      p = c!(@boxes)
      inputs = eye([0, 1, 0, 1]) ++ [%{"rst" => 1}, %{"eye" => 0}, %{"eye" => 1}, %{"rst" => 0}]
      inputs = inputs ++ [%{"eye" => 0}, %{"eye" => 1}]
      assert trace(p, inputs, ["boxes", "cv"]) == [0, 1, 1, 2, 0, 0, 0, 0, 0, 1]
    end

    test "a reset keeps the edge memory: a box on the eye at a reset is not counted again " <>
           "(decision 70)" do
      p = c!(@boxes)
      inputs = eye([0, 1]) ++ [%{"rst" => 1}, %{"rst" => 0}, %{}, %{"eye" => 0}, %{"eye" => 1}]
      assert trace(p, inputs, ["boxes", "cv"]) == [0, 1, 0, 0, 0, 0, 1]
      assert trace(p, inputs, ["boxes", "cu"]) == [0, 1, 1, 1, 1, 0, 1]
    end

    test "a reset rung below the counter's shows at the next scan, IEC's separate " <>
           "assignment (decision 84)" do
      below =
        c!(
          "var_input eye bool\nvar_input rst bool\nvar boxes ctu\nxic eye ctu boxes 3\nxic rst ote boxes.r"
        )

      inputs = eye([0, 1]) ++ [%{"rst" => 1}, %{"rst" => 0}]
      assert trace(below, inputs, ["boxes", "cv"]) == [0, 1, 1, 0]
    end

    test "at 2147483647 a count adds nothing and sets `ov`, which stays until `r` " <>
           "(decision 71)" do
      p = c!(@boxes)
      top = %{Runtime.instance(p) | first: false}
      top = put_in(top.env["boxes"]["cv"], 2_147_483_646)
      inputs = eye([0, 1, 0, 1, 0, 1, 0]) ++ [%{"rst" => 1}, %{"rst" => 0}]

      assert trace(p, inputs, ["boxes", "cv"], top) ==
               [2_147_483_646, 2_147_483_647, 2_147_483_647, 2_147_483_647] ++
                 [2_147_483_647, 2_147_483_647, 2_147_483_647, 0, 0]

      assert trace(p, inputs, ["boxes", "ov"], top) == [0, 0, 0, 1, 1, 1, 1, 0, 0]
    end

    test "a `pv` logic writes is read at the counter's next run, its rung false or true" do
      p = c!("var_input more bool\n" <> @boxes <> "xic more move 9 boxes.pv")
      inputs = eye([0, 1, 0, 1, 0, 1, 0]) ++ [%{"more" => 1}, %{}]
      assert trace(p, inputs, ["boxes", "q"]) == [0, 0, 0, 0, 0, 1, 1, 1, 0]
    end

    test "inside a function block it counts as a member, and a frozen block holds it, " <>
           "missing an edge that comes and goes while it is frozen (decision 89)" do
      {:ok, cell} =
        Logex.compile(
          "function_block cell\nvar_input eye bool\nvar_output full bool\nvar c ctu\n" <>
            "xic eye ctu c 2\nxic c.q ote full",
          name: "cell"
        )

      p =
        c!(
          "var_input on bool\nvar_input eye bool\nvar_output full bool\nvar s1 cell\nxic on cal s1 eye full",
          [cell]
        )

      inputs =
        for {on, eye} <- [{1, 0}, {1, 1}, {1, 0}, {0, 1}, {0, 0}, {1, 0}, {0, 1}, {1, 1}],
            do: %{"on" => on, "eye" => eye}

      assert trace(p, inputs, ["s1", "c", "cv"]) == [0, 1, 1, 1, 1, 1, 1, 2]
    end
  end

  @hopper """
  var_input portion bool
  var_input refill bool
  var hopper ctd
  xic refill ote hopper.ld
  xic portion ctd hopper 2
  """

  defp portion(levels), do: Enum.map(levels, &%{"portion" => &1})

  describe "ctd (decision 67)" do
    test "starts at 0, done, until `ld` puts `cv` to `pv`; each rising edge then takes one " <>
           "away, and `q` is `cv <= 0`" do
      p = c!(@hopper)
      inputs = [%{}, %{"refill" => 1}, %{"refill" => 0}] ++ portion([1, 0, 1, 1, 0, 1])
      assert trace(p, inputs, ["hopper", "cv"]) == [0, 2, 2, 1, 1, 0, 0, 0, -1]
      assert trace(p, inputs, ["hopper", "q"]) == [1, 0, 0, 0, 0, 1, 1, 1, 1]
    end

    test "counts nothing on the first scan, no edge counts while `ld` is 1, and a load " <>
           "keeps the edge memory" do
      p = c!(@hopper)
      inputs = [%{"portion" => 1, "refill" => 1}, %{"portion" => 0}, %{"portion" => 1}]
      inputs = inputs ++ [%{"refill" => 0}, %{"portion" => 0}, %{"portion" => 1}]
      assert trace(p, inputs, ["hopper", "cv"]) == [2, 2, 2, 2, 2, 1]

      inputs = [%{"refill" => 0}, %{"portion" => 1}, %{"refill" => 1}, %{"refill" => 0}, %{}]
      assert trace(p, inputs, ["hopper", "cv"]) == [0, -1, 2, 2, 2]
      assert trace(p, inputs, ["hopper", "cd"]) == [0, 1, 1, 1, 1]
    end

    test "at −2147483648 a count takes nothing away and sets `un`, which stays until `ld` " <>
           "(decision 71)" do
      p = c!(@hopper)
      bottom = %{Runtime.instance(p) | first: false}
      bottom = put_in(bottom.env["hopper"]["cv"], -2_147_483_647)
      inputs = portion([0, 1, 0, 1, 0]) ++ [%{"refill" => 1}, %{"refill" => 0}]

      assert trace(p, inputs, ["hopper", "cv"], bottom) ==
               [-2_147_483_647, -2_147_483_648, -2_147_483_648, -2_147_483_648] ++
                 [-2_147_483_648, 2, 2]

      assert trace(p, inputs, ["hopper", "un"], bottom) == [0, 0, 0, 1, 1, 0, 0]
    end
  end

  @stock """
  var_input infeed bool
  var_input outfeed bool
  var_input clear bool
  var_input fill bool
  var stock ctud
  xic clear ote stock.r
  xic fill ote stock.ld
  xic infeed ctu stock 3
  xic outfeed ctd stock 3
  """

  describe "ctud (decision 85)" do
    test "its `ctu` counts the infeed up and its `ctd` the outfeed down, `qu` at `cv >= pv` " <>
           "and `qd` at `cv <= 0`, and two edges in one scan net zero" do
      p = c!(@stock)

      inputs =
        for {i, o} <- [{0, 0}, {1, 0}, {0, 0}, {1, 0}, {0, 0}, {1, 1}, {0, 0}, {1, 0}, {0, 1}],
            do: %{"infeed" => i, "outfeed" => o}

      assert trace(p, inputs, ["stock", "cv"]) == [0, 1, 1, 2, 2, 2, 2, 3, 2]
      assert trace(p, inputs, ["stock", "qu"]) == [0, 0, 0, 0, 0, 0, 0, 1, 0]
      assert trace(p, inputs, ["stock", "qd"]) == [1, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    test "counts nothing on the first scan, on either side" do
      p = c!(@stock)
      assert trace(p, [%{"infeed" => 1, "outfeed" => 0}], ["stock", "cv"]) == [0]
      assert trace(p, [%{"infeed" => 0, "outfeed" => 1}], ["stock", "cv"]) == [0]
    end

    test "`r` before `ld` before a count, either clearing both flags, and each side " <>
           "keeping the other's edge memory" do
      p = c!(@stock)
      inputs = [%{"fill" => 1}, %{"fill" => 0}, %{"clear" => 1, "fill" => 1}, %{"clear" => 0}]
      inputs = inputs ++ [%{"fill" => 0, "infeed" => 1}, %{"outfeed" => 1}]
      assert trace(p, inputs, ["stock", "cv"]) == [3, 3, 0, 3, 4, 3]
      assert trace(p, inputs, ["stock", "cu"]) == [0, 0, 0, 0, 1, 1]
      assert trace(p, inputs, ["stock", "cd"]) == [0, 0, 0, 0, 0, 1]

      top = %{Runtime.instance(p) | first: false}
      top = put_in(top.env["stock"]["cv"], 2_147_483_647)
      inputs = [%{"infeed" => 1}, %{"infeed" => 0}, %{"outfeed" => 1}, %{"fill" => 1}]
      assert trace(p, inputs, ["stock", "ov"], top) == [1, 1, 1, 0]

      assert trace(p, inputs, ["stock", "cv"], top) == [
               2_147_483_647,
               2_147_483_647,
               2_147_483_646,
               3
             ]

      bottom = put_in(top.env["stock"]["cv"], -2_147_483_648)
      inputs = [%{"outfeed" => 1}, %{"outfeed" => 0}, %{"clear" => 1}]
      assert trace(p, inputs, ["stock", "un"], bottom) == [1, 1, 0]
    end
  end

  test "a counter's type given where a program goes is refused, naming the instructions " <>
         "that run it" do
    assert_raise ArgumentError,
                 "`ctud` is a function block type, which runs inside a program through `ctu` " <>
                   "and `ctd`: an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.ctud()) end

    assert_raise ArgumentError,
                 "`ctd` is a function block type, which runs inside a program through `ctd`: " <>
                   "an instance is of a %Logex.Program{}",
                 fn -> Runtime.instance(Logex.FbType.ctd()) end
  end

  test "a restart, warm or cold, starts a counter again at its preset" do
    p = c!(@boxes)
    state = %{Runtime.instance(p) | first: false}
    state = put_in(state.env["boxes"], %{state.env["boxes"] | "cv" => 2, "pv" => 7, "ov" => 1})
    state = Runtime.restart(p, state, :warm)
    assert state.env["boxes"] == %{"cu" => 0, "r" => 0, "pv" => 3, "q" => 0, "cv" => 0, "ov" => 0}
  end
end
