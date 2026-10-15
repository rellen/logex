defmodule Logex.JumpTest do
  @moduledoc """
  M3-5: the forward jump, `jmp` and `lbl` (docs/organisation.md decisions 81, 82, 104 and
  106; docs/naming.md, `jmp` and `lbl`), each rule of a scan pinned from source through
  `Logex.Runtime.call/4`, a test that fails when the rule alone is reverted. A skipped rung
  freezes as a block whose `cal` is false freezes, and the block list an online edit leaves
  holds a skipped rung's edge memories until a scan runs their instructions. The
  compiler's refusals and warnings are `validation_test.exs`'s, and an edit's rules
  `edit_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Program, Runtime, Scan}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  # Scans `program` from `state` once per entry of `inputs`, `dt` ms apart: each scan's
  # values at `at`, a list of paths, read as the env holds them.
  defp trace(program, inputs, at, state \\ nil, dt \\ 10) do
    state = state || Runtime.instance(program)

    {values, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + dt, first: first})
        {Enum.map(at, &get_in(state.env, &1)), state}
      end)

    values
  end

  defp tag(program, inputs, name, state \\ nil),
    do: for([value] <- trace(program, inputs, [[name]], state), do: value)

  # The state after one scan per entry of `inputs`, 10 ms apart.
  defp drive(program, inputs, state \\ nil),
    do:
      Enum.reduce(inputs, state || Runtime.instance(program), fn input, %Instance{} = state ->
        {_out, state} =
          Runtime.call(program, state, input, %Scan{now: state.now + 10, first: state.first})

        state
      end)

  defp skip(levels), do: Enum.map(levels, &%{"skip" => &1})

  @section """
  var_input skip bool
  var_input a bool
  var_output before bool
  var_output inside bool
  var_output landed bool
  var_output after bool
  xic a ote before
  xic skip jmp done
  xic a ote inside
  lbl done xic a ote landed
  xic a ote after
  """

  describe "jmp" do
    test "energised, it skips every rung after its own up to the one its label heads, " <>
           "which runs, as do the rungs before and after" do
      p = c!(@section)
      inputs = [%{"skip" => 0, "a" => 1}, %{"skip" => 1, "a" => 0}, %{"skip" => 0, "a" => 0}]

      assert trace(p, inputs, [["before"], ["inside"], ["landed"], ["after"]]) == [
               [1, 1, 1, 1],
               [0, 1, 0, 0],
               [0, 0, 0, 0]
             ]
    end

    test "de-energised, it does nothing: no rung is skipped" do
      p = c!(@section)
      assert tag(p, [%{"skip" => 0, "a" => 1}, %{"a" => 0}], "inside") == [1, 0]
    end

    test "passes on the power it receives, and the rest of its rung runs before the jump " <>
           "is taken (IEC's rule 3, decision 104)" do
      p =
        c!("""
        var_input skip bool
        var_input a bool
        var_output lamp bool
        var_output inside bool
        xic skip jmp done ote lamp
        xic a ote inside
        lbl done
        """)

      inputs = for s <- [1, 0, 1, 1, 0], do: %{"skip" => s, "a" => 1}
      assert tag(p, inputs, "lamp") == [1, 0, 1, 1, 0]
      # The first scan is skipped, so `inside` is only written once the jump is not taken.
      assert tag(p, inputs, "inside") == [0, 1, 1, 1, 1]
    end

    test "on a leg of a group, it jumps where its leg's power reaches it, and the group " <>
           "passes on the power its legs pass" do
      p =
        c!("""
        var_input skip bool
        var_input other bool
        var_output y bool
        var_output inside bool
        ( xic skip jmp done | xic other ) ote y
        xic other ote inside
        lbl done
        """)

      inputs = for {s, o} <- [{0, 1}, {1, 0}, {1, 1}, {0, 0}], do: %{"skip" => s, "other" => o}
      assert trace(p, inputs, [["y"], ["inside"]]) == [[1, 1], [1, 1], [1, 1], [0, 0]]
    end

    test "goes to its own label, past a rung another label heads, which is skipped too" do
      p =
        c!("""
        var_input skip bool
        var_output first bool
        var_output second bool
        xic skip jmp far
        lbl near xio skip ote first
        xio skip ote second
        lbl far
        """)

      assert trace(p, skip([0, 1]), [["first"], ["second"]]) == [[1, 1], [1, 1]]
    end

    test "a jump on a skipped rung is not taken, and one on the labelled rung is" do
      p =
        c!("""
        var_input j1 bool
        var_input j2 bool
        var_input j3 bool
        var_output y1 bool
        var_output y2 bool
        var_output y3 bool
        xic j1 jmp one
        xic j2 jmp two
        ote y1
        lbl one xic j3 jmp three
        ote y2
        lbl two
        ote y3
        lbl three
        """)

      at = [["y1"], ["y2"], ["y3"]]
      # j1 skips j2's rung, so `two` is never reached from it; `one`'s rung jumps again.
      assert trace(p, [%{"j1" => 1, "j2" => 1, "j3" => 0}], at) == [[0, 1, 1]]
      assert trace(p, [%{"j1" => 1, "j2" => 1, "j3" => 1}], at) == [[0, 0, 0]]
      assert trace(p, [%{"j1" => 0, "j2" => 1, "j3" => 0}], at) == [[0, 0, 1]]
    end

    test "leaves no record of the jump in the state" do
      p = c!(@section)
      state = drive(p, [%{"skip" => 1, "a" => 1}])
      assert Map.keys(state.env) |> Enum.all?(&is_binary/1)
    end
  end

  describe "a program built by hand" do
    test "whose jmp names a label no later rung heads skips the rest of its routine, and " <>
           "nothing escapes" do
      rungs = [
        {:rung, [{:xic, 1, [{:name, 1, "go"}]}, {:jmp, 1, [{:label, 1, "nowhere"}]}]},
        {:rung, [{:ote, 2, [{:name, 2, "y"}]}]}
      ]

      program = %Program{rungs: rungs, tags: %{}}
      state = %Instance{type: nil, env: %{"go" => 1, "y" => 0}, now: 0, first: false}
      {_outputs, state} = Runtime.call(program, state, %{}, %Scan{now: 1, first: false})
      assert state.env == %{"go" => 1, "y" => 0}
    end
  end

  describe "lbl" do
    test "passes on the power it receives, its rung's, so its rung runs as without it" do
      p =
        c!("""
        var_input a bool
        var_output y bool
        var_output z bool
        lbl here xic a ote y
        lbl there ote z
        xic a jmp here2
        lbl here2
        """)

      assert trace(p, [%{"a" => 1}, %{"a" => 0}], [["y"], ["z"]]) == [[1, 1], [0, 1]]
    end

    test "de-energised, which no compiled rung gives it, it passes no power and does nothing" do
      # A program built by hand, outside the contract, whose label follows a contact.
      rungs = [
        {:rung,
         [
           {:xio, 1, [{:name, 1, "go"}]},
           {:lbl, 1, [{:label, 1, "x"}]},
           {:ote, 1, [{:name, 1, "y"}]}
         ]}
      ]

      program = %Program{rungs: rungs, tags: %{}}
      state = %Instance{type: nil, env: %{"go" => 1, "y" => 1}, now: 0, first: false}
      {_outputs, state} = Runtime.call(program, state, %{}, %Scan{now: 1, first: false})
      assert state.env == %{"go" => 1, "y" => 0}
    end
  end

  describe "a skipped rung freezes, as a block whose cal is false (decision 82)" do
    test "its outputs hold, an ote's among them, and neither otl, otu nor move writes" do
      p =
        c!("""
        var_input skip bool
        var_input a bool
        var_input d dint
        var_output y bool
        var_output l bool
        var_output n dint
        xic skip jmp done
        xic a ote y
        xic a otl l
        xio a otu l
        xic a move d n
        lbl done
        """)

      inputs = [
        %{"skip" => 0, "a" => 1, "d" => 7},
        %{"skip" => 1, "a" => 0, "d" => 9},
        %{"skip" => 1, "a" => 0, "d" => 3},
        %{"skip" => 0, "a" => 0, "d" => 3}
      ]

      assert trace(p, inputs, [["y"], ["l"], ["n"]]) == [
               [1, 1, 7],
               [1, 1, 7],
               [1, 1, 7],
               [0, 0, 7]
             ]
    end

    test "a timer in it stops and catches up the time it was skipped when it next runs, " <>
           "since only its own run stamps `last`" do
      p =
        c!("""
        var_input skip bool
        var_input go bool
        var t1 ton
        xic skip jmp done
        xic go ton t1 1000
        lbl done
        """)

      inputs = [%{"skip" => 0, "go" => 1}, %{}, %{"skip" => 1}, %{}, %{}, %{"skip" => 0}]
      # 100 ms apart: timing from the first scan, frozen for three, then 400 ms more at once.
      assert trace(p, inputs, [["t1", "acc"], ["t1", "last"]], nil, 100) == [
               [0, 100],
               [100, 200],
               [100, 200],
               [100, 200],
               [100, 200],
               [500, 600]
             ]
    end

    test "so do a tof in its delay, a tp in its pulse and an rto timing" do
      p =
        c!("""
        var_input skip bool
        var_input fa bool
        var_input tb bool
        var_input rc bool
        var f tof
        var t tp
        var r rto
        xic skip jmp done
        xic fa tof f 1000
        xic tb tp t 1000
        xic rc rto r 1000
        lbl done
        """)

      inputs = [
        %{},
        %{"fa" => 1, "tb" => 1, "rc" => 1},
        %{"fa" => 0},
        %{"skip" => 1},
        %{},
        %{"skip" => 0}
      ]

      assert trace(p, inputs, [["f", "acc"], ["t", "acc"], ["r", "acc"]], nil, 100) == [
               [0, 0, 0],
               [0, 0, 0],
               [0, 100, 100],
               [0, 100, 100],
               [0, 100, 100],
               [300, 400, 400]
             ]
    end

    test "a counter in it counts nothing and keeps its edge memory: an edge that comes and " <>
           "goes while it is skipped is never seen, and one still risen counts at its next run" do
      p =
        c!("""
        var_input skip bool
        var_input eye bool
        var boxes ctu
        xic skip jmp done
        xic eye ctu boxes 9
        lbl done
        """)

      inputs =
        for {s, e} <- [{0, 0}, {0, 1}, {0, 0}, {1, 1}, {1, 0}, {0, 0}, {1, 1}, {0, 1}],
            do: %{"skip" => s, "eye" => e}

      assert trace(p, inputs, [["boxes", "cv"], ["boxes", "cu"]]) == [
               [0, 0],
               [1, 1],
               [1, 0],
               [1, 0],
               [1, 0],
               [1, 0],
               [1, 0],
               [2, 1]
             ]
    end

    test "a one-shot in it keeps its storage bit, and a pulse bit set at its last run stays on" do
      p =
        c!("""
        var_input skip bool
        var_input go bool
        var_output pulse bool
        var_output step bool
        var s1 bool
        var s2 bool
        xic skip jmp done
        xic go ons s1 ote pulse
        xic go osr s2 step
        lbl done
        """)

      inputs =
        for {s, g} <- [{0, 0}, {0, 1}, {1, 1}, {1, 0}, {1, 1}, {0, 1}, {0, 0}, {1, 1}, {0, 1}],
            do: %{"skip" => s, "go" => g}

      assert trace(p, inputs, [["pulse"], ["s1"], ["step"], ["s2"]]) == [
               [0, 0, 0, 0],
               [1, 1, 1, 1],
               [1, 1, 1, 1],
               [1, 1, 1, 1],
               [1, 1, 1, 1],
               [0, 1, 0, 1],
               [0, 0, 0, 0],
               [0, 0, 0, 0],
               [1, 1, 1, 1]
             ]
    end

    test "a block its cal would run stays frozen, its outputs and timers with it" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input go bool\nvar_output q bool\nvar t1 ton\n" <>
            "xic go ton t1 1000\nxic t1.dn ote q\nxic go ote q",
          name: "seal"
        )

      p =
        c!(
          """
          var_input skip bool
          var_input go bool
          var_output q bool
          var s seal
          xic skip jmp done
          cal s go q
          lbl done
          """,
          [seal]
        )

      inputs = [%{"skip" => 0, "go" => 1}, %{"skip" => 1, "go" => 0}, %{}, %{"skip" => 0}]

      assert trace(p, inputs, [["q"], ["s", "t1", "acc"]], nil, 100) == [
               [1, 0],
               [1, 0],
               [1, 0],
               [0, 0]
             ]
    end

    test "raises no fault: a zero divisor on a skipped rung divides nothing" do
      p =
        c!("""
        var_input skip bool
        var_input z dint
        var_output q dint 5
        xic skip jmp done
        div 7 z q
        lbl done
        """)

      {_out, state} =
        Runtime.call(p, Runtime.instance(p), %{"skip" => 1}, %Scan{now: 0, first: true})

      assert {state.faults, state.env["q"]} == {[], 5}

      {_out, state} = Runtime.call(p, state, %{"skip" => 0}, %Scan{now: 10, first: false})
      assert [%Logex.Fault{kind: :divide_by_zero, line: 5}] = state.faults
    end
  end

  describe "in a function block's body" do
    test "a jump skips the body's own rungs, and the program's rungs run as ever" do
      {:ok, half} =
        Logex.compile(
          "function_block half\nvar_input skip bool\nvar_input a bool\nvar_output y bool\n" <>
            "var_output z bool\nxic skip jmp done\nxic a ote y\nlbl done xic a ote z",
          name: "half"
        )

      p =
        c!(
          """
          var_input skip bool
          var_input a bool
          var_output y bool
          var_output z bool
          var_output w bool
          var h half
          cal h skip a y z
          xic a ote w
          """,
          [half]
        )

      inputs = [%{"skip" => 0, "a" => 1}, %{"skip" => 1, "a" => 0}, %{"skip" => 0}]
      assert trace(p, inputs, [["y"], ["z"], ["w"]]) == [[1, 1, 1], [1, 0, 0], [0, 0, 0]]
    end
  end

  # Decision 106: a switch's block list (Logex.Edit) lists a memory until the next scan
  # that runs its instruction, set here by hand, to see what the runtime does with it.
  describe "the block list, across a skipped rung (decision 106)" do
    @ons """
    var_input skip bool
    var_input go bool
    var_output pulse bool
    var s1 bool
    xic skip jmp done
    xic go ons s1 ote pulse
    lbl done
    """

    test "a storage bit on a skipped rung stays listed, and its one-shot's next run is " <>
           "blocked, and then uses it up" do
      p = c!(@ons)
      state = %{drive(p, [%{"skip" => 0, "go" => 0}]) | ons_blocked: ["s1"]}

      state = drive(p, [%{"skip" => 1, "go" => 1}], state)
      assert state.ons_blocked == ["s1"]
      state = drive(p, [%{"skip" => 1}], state)
      assert state.ons_blocked == ["s1"]

      # Its first run, `go` risen while it was skipped, passes no power; the next edge does.
      assert trace(p, [%{"skip" => 0}, %{"go" => 0}, %{"go" => 1}], [["pulse"]], state) ==
               [[0], [0], [1]]

      assert drive(p, [%{"skip" => 0}], state).ons_blocked == []
    end

    test "unblocked, the same one-shot fires at its first run on the edge that rose while " <>
           "it was skipped, as one in a block does" do
      p = c!(@ons)
      state = drive(p, [%{"skip" => 0, "go" => 0}, %{"skip" => 1, "go" => 1}])
      assert tag(p, [%{"skip" => 0}], "pulse", state) == [1]
    end

    test "so does a memory on a leg of a skipped rung's group, at any depth, and its next " <>
           "run is blocked" do
      p =
        c!("""
        var_input skip bool
        var_input go bool
        var_input b bool
        var_output pulse bool
        var_output deep bool
        var_output lamp bool
        var_output full bool
        var s1 bool
        var s2 bool
        var stock ctud
        xic b ctd stock 9
        xic skip jmp done
        ( xic b | xic go ons s1 ) ote pulse
        ( xic b ote lamp | ( xic b | xic go ons s2 ote deep ) )
        ( xic go ctu stock 9 | xic b ote full )
        lbl done
        """)

      blocked = ["s1", "s2", "stock.cu"]
      state = %{drive(p, [%{"skip" => 0, "go" => 0}]) | ons_blocked: blocked}

      # The `ctd`'s run records the counter's, and the skipped `ctu`'s mark keeps its side.
      state = drive(p, [%{"skip" => 1, "go" => 1}], state)
      assert state.ons_blocked == blocked

      # Their first run, `go` risen while they were skipped, sees no edge.
      assert trace(p, [%{"skip" => 0}], [["pulse"], ["deep"], ["stock", "cv"]], state) ==
               [[0, 0, 0]]

      assert drive(p, [%{"skip" => 0}], state).ons_blocked == []
    end

    test "so do a pulse coil's storage bits" do
      p =
        c!("""
        var_input skip bool
        var_input go bool
        var_output rise bool
        var_output fall bool
        var sr bool
        var sf bool
        xic skip jmp done
        xic go osr sr rise
        xic go osf sf fall
        lbl done
        """)

      state = %{drive(p, [%{"skip" => 0, "go" => 0}]) | ons_blocked: ["sf", "sr"]}
      state = drive(p, [%{"skip" => 1, "go" => 1}], state)
      assert state.ons_blocked == ["sf", "sr"]
      assert trace(p, [%{"skip" => 0}], [["rise"], ["sr"]], state) == [[0, 1]]
    end

    test "so does a counter's edge memory, and a ctud's side a jump skips stays listed " <>
           "while the other side's runs and is used up, whichever side runs first" do
      skipped_up =
        "xic outfeed ctd stock 9\nxic skip jmp done\nxic infeed ctu stock 9\nlbl done"

      skipped_down =
        "xic skip jmp done\nxic outfeed ctd stock 9\nlbl done\nxic infeed ctu stock 9"

      for {rungs, kept} <- [{skipped_up, "stock.cu"}, {skipped_down, "stock.cd"}] do
        p =
          c!(
            "var_input skip bool\nvar_input infeed bool\nvar_input outfeed bool\n" <>
              "var stock ctud\n" <> rungs
          )

        state = %{drive(p, [%{"skip" => 0}]) | ons_blocked: ["stock.cd", "stock.cu"]}
        state = drive(p, [%{"skip" => 1, "infeed" => 1, "outfeed" => 1}], state)
        assert {state.ons_blocked, state.env["stock"]["cv"]} == {[kept], 0}, rungs

        # The skipped side's first run is blocked: the box that arrived while it was
        # skipped is no edge.
        state = drive(p, [%{"skip" => 0}], state)
        assert {state.ons_blocked, state.env["stock"]["cv"]} == {[], 0}, rungs
      end
    end

    test "so does a pulse timer's edge memory" do
      p =
        c!("""
        var_input skip bool
        var_input fault bool
        var horn tp
        xic skip jmp done
        xic fault tp horn 3000
        lbl done
        """)

      state = %{drive(p, [%{"skip" => 0}]) | ons_blocked: ["horn.en"]}
      state = drive(p, [%{"skip" => 1, "fault" => 1}], state)
      assert state.ons_blocked == ["horn.en"]
      state = drive(p, [%{"skip" => 0}], state)
      assert {state.ons_blocked, state.env["horn"]["tt"]} == {[], 0}
    end

    test "inside a block whose body runs, a bit its body's jump skips stays listed by path" do
      {:ok, pulse} =
        Logex.compile(
          "function_block pulse\nvar_input skip bool\nvar_input go bool\nvar_output y bool\n" <>
            "var edge bool\nxic skip jmp done\nxic go ons edge ote y\nlbl done",
          name: "pulse"
        )

      p =
        c!(
          "var_input skip bool\nvar_input go bool\nvar_output y bool\nvar p pulse\n" <>
            "cal p skip go y",
          [pulse]
        )

      state = %{drive(p, [%{"skip" => 0, "go" => 0}]) | ons_blocked: ["p.edge"]}
      state = drive(p, [%{"skip" => 1, "go" => 1}], state)
      assert state.ons_blocked == ["p.edge"]
      assert tag(p, [%{"skip" => 0}], "y", state) == [0]
      assert drive(p, [%{"skip" => 0}], state).ons_blocked == []
    end

    test "a cal on a skipped rung runs no body, so its instance's bits stay listed" do
      {:ok, pulse} =
        Logex.compile(
          "function_block pulse\nvar_input go bool\nvar_output y bool\nvar edge bool\n" <>
            "xic go ons edge ote y",
          name: "pulse"
        )

      p =
        c!(
          "var_input skip bool\nvar_input go bool\nvar_output y bool\nvar p pulse\n" <>
            "xic skip jmp done\ncal p go y\nlbl done",
          [pulse]
        )

      state = %{drive(p, [%{"skip" => 0}]) | ons_blocked: ["p.edge"]}
      assert drive(p, [%{"skip" => 1, "go" => 1}], state).ons_blocked == ["p.edge"]
    end

    test "a bit no rung of the program holds, which only a plain swap can leave, is used " <>
           "up by a scan, skip or none, as before M3-5" do
      p = c!(@ons)
      state = %{drive(p, [%{"skip" => 0}]) | ons_blocked: ["s1", "s9"]}
      assert drive(p, [%{"skip" => 1}], state).ons_blocked == ["s1"]
      assert drive(p, [%{"skip" => 0}], state).ons_blocked == []
    end
  end

  # A record of a scan's own is kept under an atom no tag can be and taken out before the
  # scan ends, so no state holds one: a host's env holding the jump's, which would skip
  # rungs, is refused, and a block instance's map holding one, a value no scan checks, has
  # it dropped, so the body runs as its text says (M3-5's review).
  describe "a hand-built env" do
    test "holding the jump's key is refused, so no record left in a state skips a rung" do
      p = c!(@section)
      state = Runtime.instance(p)

      assert_raise ArgumentError,
                   "state.env holds :jump, the runtime's own key for a record a scan keeps " <>
                     "and takes out before it ends: an env is keyed by tag names",
                   fn ->
                     Runtime.call(
                       p,
                       %{state | env: Map.put(state.env, :jump, "done")},
                       %{},
                       %Scan{
                         now: 0,
                         first: true
                       }
                     )
                   end
    end

    test "whose block instance holds a jump's or a run's record, runs the body as its text " <>
           "says and uses its blocks up" do
      {:ok, pulse} =
        Logex.compile(
          "function_block pulse\nvar_input go bool\nvar_output y bool\nvar_output z bool\n" <>
            "var edge bool\nxic go ons edge ote y\nxic go ote z",
          name: "pulse"
        )

      p =
        c!(
          "var_input go bool\nvar_output y bool\nvar_output z bool\nvar p pulse\ncal p go y z",
          [pulse]
        )

      fresh = drive(p, [%{"go" => 0}])
      records = %{jump: "nowhere", ran: %{"edge" => :skipped}}

      held = %{
        fresh
        | env: Map.update!(fresh.env, "p", &Map.merge(&1, records)),
          ons_blocked: ["p.edge"]
      }

      state = drive(p, [%{"go" => 1}], held)
      assert {state.env["z"], state.env["y"], state.ons_blocked} == {1, 0, []}
      assert Enum.all?(Map.keys(state.env["p"]), &is_binary/1)
    end
  end

  # A scan's cost in reductions, the least of three, since a busy VM can raise one: `src`
  # compiled, scanned once, its block list set to `blocked`, and scanned again with
  # `inputs`.
  defp reductions_to_scan(src, inputs, blocked \\ []) do
    p = c!(src)
    {_, state} = Runtime.call(p, Runtime.instance(p), %{}, %Scan{now: 0, first: true})
    state = %{state | ons_blocked: blocked}

    Enum.min(
      for _ <- 1..3 do
        {:reductions, before} = Process.info(self(), :reductions)
        Runtime.call(p, state, inputs, %Scan{now: 10, first: false})
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end
    )
  end

  # `n` sections, each a jump over a rung to its own label.
  defp sections(n),
    do:
      "var_input j bool\nvar_input a bool\n" <>
        Enum.map_join(1..n, "\n", &"var_output y#{&1} bool") <>
        "\n" <> Enum.map_join(1..n, "\n", &"xic j jmp l#{&1}\nxic a ote y#{&1}\nlbl l#{&1}")

  # One jump over `n` rungs, each a one-shot.
  defp one_shots(n),
    do:
      "var_input j bool\nvar_input a bool\nvar_output y bool\n" <>
        Enum.map_join(1..n, "\n", &"var s#{&1} bool") <>
        "\nxic j jmp done\n" <>
        Enum.map_join(1..n, "\n", &"xic a ons s#{&1} ote y") <> "\nlbl done"

  defp bits(n), do: Enum.map(1..n, &"s#{&1}")

  describe "growth" do
    # 4x the sections, each jump taken, took 3.96x to 3.97x the reductions over 32 runs on
    # Elixir 1.20.4, 16 alone and 16 beside three suites; the bound is a fifth above the
    # highest.
    test "a scan stays linear in the jumps it takes" do
      ratio =
        reductions_to_scan(sections(800), %{"j" => 1}) /
          reductions_to_scan(sections(200), %{"j" => 1})

      assert ratio < 4.76, "4x the jumps took #{Float.round(ratio, 2)}x the reductions"
    end

    # 4x the blocked one-shots on skipped rungs, each marked and kept, took 4.00x to 4.07x
    # over the same 32 runs; the bound is a fifth above the highest.
    test "a scan stays linear in the blocked memories its skipped rungs keep (decision 106)" do
      ratio =
        reductions_to_scan(one_shots(800), %{"j" => 1}, bits(800)) /
          reductions_to_scan(one_shots(200), %{"j" => 1}, bits(200))

      assert ratio < 4.89,
             "4x the blocked one-shots took #{Float.round(ratio, 2)}x the reductions"
    end

    # A skipped rung is passed over, and walked for its memories only where the block list
    # holds one: 400 skipped one-shot rungs took 0.230x to 0.232x what running them took over the
    # same 32 runs, the scan's own work most of it, and walked for their memories with the
    # list empty, 0.999x. The bound is a fifth above the highest.
    test "a skipped rung costs a small part of what running it costs, where the block list " <>
           "holds nothing" do
      ratio =
        reductions_to_scan(one_shots(400), %{"j" => 1}) /
          reductions_to_scan(one_shots(400), %{"j" => 0, "a" => 1})

      assert ratio < 0.278, "skipping took #{Float.round(ratio, 3)}x the reductions of running"
    end
  end
end
