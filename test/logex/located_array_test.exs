defmodule Logex.LocatedArrayTest do
  @moduledoc """
  PLAN M5-13, located arrays (`docs/organisation.md` §4.12, "I/O points", decision 156 and
  its follow-up): `var_global temps real[8] at card.i.0` occupies `card.i.0` to
  `card.i.7`, in the elements' order, each element a point named `temps[3]`. Every rule
  from source: the configuration line and its round trip, `Logex.IO.points/1` and
  `bind!/2`, a range that overlaps another point refused with both names, an initial list
  refused, a location in a connection naming the element, an input array driven refused,
  an event task's single still a whole bool global, an array of output points nothing
  drives warned element by element; a cycle's inputs and outputs by element, a restart
  keeping an input array, every host mistake pinned; the runner reading and writing
  element by element through the sim, a sim of fewer points refusing a range past them,
  forces on an element held against its device, across a restart, a crash and a fresh
  start, the forces file's line spelled by the element's name, unforce and unforce_all,
  a restart's reread, a refused value of one element keeping the others' (decision 143);
  an online edit's located-I/O refusal covering the range; and the growth in reductions,
  a configuration of no located array cycling as it did at `a8af419`.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.Global
  alias Logex.IO.{Point, Sim}
  alias Logex.Runner
  alias Logex.Runner.Clock.Manual

  # The oven's zone program: eight temperatures in, a lamp for each zone over its
  # setpoint out, and the hottest zone's temperature kept in `peak` (a scalar).
  @zones """
  var_input  temps real[8]
  var_input  sp    real
  var_output hot   bool[8]
  var_output first real
  gt temps[0] sp ote hot[0]
  gt temps[1] sp ote hot[1]
  gt temps[2] sp ote hot[2]
  gt temps[3] sp ote hot[3]
  gt temps[4] sp ote hot[4]
  gt temps[5] sp ote hot[5]
  gt temps[6] sp ote hot[6]
  gt temps[7] sp ote hot[7]
  move temps[0] first
  """

  @oven """
  task fast interval 10 priority 1

  var_global temps real[8] at card.i.0
  var_global lamps bool[8] at card.q.0
  var_global sp    real 100.0
  var_global first real

  program z zones with fast
    z.temps temps
    z.sp    sp
    z.hot   lamps
    z.first first
  """

  defp zones do
    {:ok, program} = Logex.compile(@zones, name: "zones")
    program
  end

  defp programs, do: %{"zones" => zones()}

  defp compiled(text), do: Configuration.compile("oven", text, programs())

  defp oven do
    {:ok, configuration} = compiled(@oven)
    configuration
  end

  defp refused(text) do
    {:error, diagnostics} = compiled(text)
    Enum.map(diagnostics, & &1.message)
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  # `@oven` with `lines` in place of its two located lines.
  defp with_points(lines),
    do:
      String.replace(
        @oven,
        "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n",
        lines
      )

  describe "the configuration line" do
    test "reads, checks with no warning, and prints back exactly" do
      oven = oven()
      assert oven.warnings == []

      assert %Global{type: {:array, :real, [8]}, at: "card.i.0", initial: nil} =
               Enum.find(oven.globals, &(&1.name == "temps"))

      text = Configuration.Text.print(oven)
      assert text =~ "var_global temps real[8] at card.i.0\n"
      assert text =~ "var_global lamps bool[8] at card.q.0\n"
      assert Configuration.compile("oven", text, oven.programs) == {:ok, oven}
    end

    test "built from Elixir, checks as from text" do
      oven = oven()

      built =
        Configuration.new!(
          name: "oven",
          programs: Map.values(oven.programs),
          tasks: oven.tasks |> Enum.map(&%{&1 | line: nil}),
          globals: oven.globals |> Enum.map(&%{&1 | line: nil}),
          instances: oven.instances |> Enum.map(&%{&1 | line: nil}),
          connections: oven.connections |> Enum.map(&%{&1 | line: nil})
        )

      assert Configuration.check(built) == []
      assert Logex.IO.points(built) == Logex.IO.points(oven)
    end

    test "each element is a point at the next address, in the elements' order, of its type" do
      points = Logex.IO.points(oven())

      assert Map.fetch!(points, "card") ==
               for(
                 i <- 0..7,
                 do: %Point{name: "temps[#{i}]", direction: :input, address: [i], type: :real}
               ) ++
                 for(
                   i <- 0..7,
                   do: %Point{name: "lamps[#{i}]", direction: :output, address: [i], type: :bool}
                 )

      # Two dimensions, the rightmost subscript fastest; a hierarchical address counting up
      # in its last field (provisional).
      {:ok, c} =
        compiled(
          with_points(
            "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n" <>
              "var_global grid bool[2,4] at rack.q.1.4\n"
          )
        )

      assert for(
               %Point{name: n, address: a} <- Map.fetch!(Logex.IO.points(c), "rack"),
               do: {n, a}
             ) ==
               [
                 {"grid[0,0]", [1, 4]},
                 {"grid[0,1]", [1, 5]},
                 {"grid[0,2]", [1, 6]},
                 {"grid[0,3]", [1, 7]},
                 {"grid[1,0]", [1, 8]},
                 {"grid[1,1]", [1, 9]},
                 {"grid[1,2]", [1, 10]},
                 {"grid[1,3]", [1, 11]}
               ]
    end

    test "a range that overlaps another point is refused, both named, once a pair" do
      # A point inside an array's range, an array over a point, and two arrays that share
      # three addresses: one message for the pair, at the first element they share.
      assert refused(
               with_points(
                 "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n" <>
                   "var_global eye bool at card.i.3\n"
               )
             ) == [
               "`eye` is at `card.i.3`, where `temps[3]` already is (line 3): a location holds one global"
             ]

      assert refused(
               with_points(
                 "var_global eye bool at card.i.3\nvar_global temps real[8] at card.i.0\n" <>
                   "var_global lamps bool[8] at card.q.0\n"
               )
             ) == [
               "`temps[3]` is at `card.i.3`, where `eye` already is (line 3): a location holds one global, and `temps` is an array of input points, `card.i.0` to `card.i.7`"
             ]

      assert refused(
               with_points(
                 "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n" <>
                   "var_global more real[4] at card.i.5\n"
               )
             ) == [
               "`more[0]` is at `card.i.5`, where `temps[5]` already is (line 3): a location holds one global, and `more` is an array of input points, `card.i.5` to `card.i.8`"
             ]

      # An array over two points is told each of them.
      assert refused(
               with_points(
                 "var_global a bool at card.i.1\nvar_global b bool at card.i.6\n" <>
                   "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n"
               )
             ) == [
               "`temps[1]` is at `card.i.1`, where `a` already is (line 3): a location holds one global, and `temps` is an array of input points, `card.i.0` to `card.i.7`",
               "`temps[6]` is at `card.i.6`, where `b` already is (line 4): a location holds one global, and `temps` is an array of input points, `card.i.0` to `card.i.7`"
             ]

      # An input range and an output range at the same numbers do not overlap; nor do two
      # devices; and a device spelled in another case is told so, once.
      assert {:ok, _} =
               compiled(
                 with_points(
                   "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n" <>
                     "var_global other real[8] at drive.i.0\n"
                 )
               )

      assert refused(
               with_points(
                 "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at Card.q.0\n"
               )
             ) == [
               "the device `Card` and the device `card` of `temps` (line 3) differ only in case: device names are case-sensitive, so these would be two devices"
             ]
    end

    test "takes no initial list, from Elixir, an input's or an output's" do
      oven = oven()

      for {name, message} <- [
            {"temps",
             "`temps` is an array of input points, `card.i.0` to `card.i.7`: their values come from the input image, so it takes no initial list"},
            {"lamps",
             "`lamps` is an array of output points, `card.q.0` to `card.q.7`: it takes no initial list, and each element is 0 until its driver writes it"}
          ] do
        globals =
          for g <- oven.globals,
              do: if(g.name == name, do: %{g | initial: List.duplicate(1, 8)}, else: g)

        assert Enum.map(Configuration.check(%{oven | globals: globals}), & &1.message) == [
                 message
               ]
      end

      # Its sizes are still an array's: a dimension of 0 is refused, located or not.
      assert refused(
               with_points(
                 "var_global temps real[0] at card.i.0\nvar_global lamps bool[8] at card.q.0\n"
               )
             ) == [
               "`temps` is declared with a dimension of 0, `[0]`: each dimension of an array holds 1 element or more",
               "`z.temps` is an array of 8 reals, but `temps` is an array of 0 reals (line 3)"
             ]

      # One refused for its sizes is told nothing of its list, nor takes an address.
      globals =
        for g <- oven.globals,
            do:
              if(g.name == "temps",
                do: %{g | type: {:array, :real, [0]}, initial: [1.0]},
                else: g
              )

      assert Enum.map(Configuration.check(%{oven | globals: globals}), & &1.message) == [
               "`temps` is declared with a dimension of 0, `[0]`: each dimension of an array holds 1 element or more",
               "`z.temps` is an array of 8 reals, but `temps` is an array of 0 reals (line 3)"
             ]
    end

    test "a location in a connection names the element at it" do
      oven = String.replace(@oven, "  z.sp    sp\n", "  z.sp    card.i.3\n")

      assert refused(oven) == [
               "`card.i.3` is a location, written only after `at` on a `var_global` line: name the global at it, `temps[3]` (line 3)"
             ]
    end
  end

  describe "what reads and drives it" do
    @writer "var_external temps real[8]\nvar_output o real\nmove 1.0 temps[2]\nmove temps[1] o\n"
    @lamp "var_input a bool\nvar_output l bool\nxic a ote l\n"
    @reader "var_input ls bool[8]\nvar_output o bool\nxic ls[0] ote o\n"

    defp more do
      {:ok, writer} = Logex.compile(@writer, name: "writer")
      {:ok, lamp} = Logex.compile(@lamp, name: "lamp")
      {:ok, reader} = Logex.compile(@reader, name: "reader")
      Map.merge(programs(), %{"writer" => writer, "lamp" => lamp, "reader" => reader})
    end

    defp checked(text), do: Configuration.compile("oven", text, more())

    @head """
    task fast interval 10 priority 1
    var_global temps real[8] at card.i.0
    var_global lamps bool[8] at card.q.0
    var_global sp    real 100.0
    var_global first real
    var_global a     bool
    """

    test "an element of an input array is an input point: nothing drives it" do
      {:error, [diagnostic]} =
        checked(
          @head <>
            "program z zones with fast\nz.temps temps\nz.sp sp\nz.hot lamps\nz.first temps[2]\n"
        )

      assert diagnostic.message ==
               "`temps[2]` is an input point (line 2): `z.first`, a var_output, cannot drive it"

      {:error, diagnostics} =
        checked(
          @head <>
            "program z zones with fast\nz.temps temps\nz.sp temps[1]\nz.hot temps\nz.first first\n"
        )

      assert Enum.map(diagnostics, & &1.message) == [
               "`temps` is an array of input points, `card.i.0` to `card.i.7` (line 2): `z.hot`, a var_output, cannot drive it"
             ]

      {:error, diagnostics} =
        checked(@head <> "program v writer with fast\nv.o first\n")

      assert Enum.map(diagnostics, & &1.message) == [
               "`writer` writes its var_external `temps` on its line 3, but `temps` is an array of input points, `card.i.0` to `card.i.7` (line 2): nothing writes an input point"
             ]
    end

    test "an event task's single is still a whole bool global" do
      {:error, diagnostics} =
        checked(
          @head <>
            "task ev single lamps[1] priority 0\ntask ev2 single temps priority 3\n" <>
            "program z zones with fast\nz.temps temps\nz.sp sp\nz.hot lamps\nz.first first\n"
        )

      assert Enum.map(diagnostics, & &1.message) == [
               "the single of `ev`: `lamps[1]` names an element of `lamps`, a global array of 8 bools (line 3): a global is named here whole, never by one of its elements",
               "the single of `ev2`, `temps`, is an array of 8 reals (line 2): a single is a bool global"
             ]
    end

    test "an array of output points nothing drives is warned, whole or by element" do
      lamps = fn n ->
        Enum.map_join(
          n,
          "",
          &"program o#{&1} lamp with fast\no#{&1}.a a\no#{&1}.l lamps[#{&1}]\n"
        )
      end

      reads = "program r reader with fast\nr.ls lamps\nr.o a\n"

      {:ok, c} =
        checked(
          @head <> reads <> "program z zones with fast\nz.temps temps\nz.sp sp\nz.first first\n"
        )

      assert "`lamps` is an array of output points, `card.q.0` to `card.q.7`, but nothing drives it: each element stays at 0" in Enum.map(
               c.warnings,
               & &1.message
             )

      {:ok, c} = checked(@head <> reads <> lamps.([2, 5]))

      assert "`lamps` is an array of output points, `card.q.0` to `card.q.7`, but nothing drives `lamps[0]`, `lamps[1]`, `lamps[3]`, `lamps[4]`, `lamps[6]` or `lamps[7]`: they stay at 0" in Enum.map(
               c.warnings,
               & &1.message
             )

      {:ok, c} = checked(@head <> reads <> lamps.([0, 1, 2, 3, 4, 5, 6]))

      assert "`lamps` is an array of output points, `card.q.0` to `card.q.7`, but nothing drives `lamps[7]`: it stays at 0" in Enum.map(
               c.warnings,
               & &1.message
             )

      {:ok, c} = checked(@head <> reads <> lamps.(Enum.to_list(0..7)))
      refute Enum.any?(c.warnings, &(&1.message =~ "nothing drives"))
    end

    # M5-13's review: ten elements are named, eleven are ten and then a count.
    test "the elements nothing drives are named to ten, the rest counted" do
      told = fn size, driven ->
        {:ok, c} =
          checked(
            "task fast interval 10 priority 1\nvar_global ls bool[#{size}] at card.q.0\n" <>
              "var_global a bool\n" <>
              Enum.map_join(
                driven,
                "",
                &"program o#{&1} lamp with fast\no#{&1}.a a\no#{&1}.l ls[#{&1}]\n"
              )
          )

        for %{message: message} <- c.warnings, message =~ "nothing drives", do: message
      end

      assert told.(12, [0, 1]) == [
               "`ls` is an array of output points, `card.q.0` to `card.q.11`, but nothing drives " <>
                 Enum.map_join(2..10, ", ", &"`ls[#{&1}]`") <> " or `ls[11]`: they stay at 0"
             ]

      assert told.(13, [0, 1]) == [
               "`ls` is an array of output points, `card.q.0` to `card.q.12`, but nothing drives " <>
                 Enum.map_join(2..11, ", ", &"`ls[#{&1}]`") <> " and 1 more: they stay at 0"
             ]

      assert told.(14, [0, 1]) == [
               "`ls` is an array of output points, `card.q.0` to `card.q.13`, but nothing drives " <>
                 Enum.map_join(2..11, ", ", &"`ls[#{&1}]`") <> " and 2 more: they stay at 0"
             ]
    end

    # M5-13's review: a write through a var_external drives what it writes, each element by
    # its subscripts' values, as decision 236 counts a writer, and the array whole where it
    # writes through a tag subscript.
    test "an array of output points a program writes through its var_external is driven by what it writes" do
      told = fn rungs, connections ->
        {:ok, ext} =
          Logex.compile(
            "var_external lamps bool[8]\nvar_input a bool\nvar_input slot dint\n" <> rungs,
            name: "ext"
          )

        {:ok, c} =
          Configuration.compile(
            "oven",
            @head <>
              "var_global slot dint\nprogram r reader with fast\nr.ls lamps\nr.o a\n" <>
              "program e ext with fast\ne.a a\ne.slot slot\n" <> connections,
            Map.put(more(), "ext", ext)
          )

        for %{message: message} <- c.warnings, message =~ "nothing drives", do: message
      end

      assert told.("xic a ote lamps[2]\n", "") == [
               "`lamps` is an array of output points, `card.q.0` to `card.q.7`, but nothing drives `lamps[0]`, `lamps[1]`, `lamps[3]`, `lamps[4]`, `lamps[5]`, `lamps[6]` or `lamps[7]`: they stay at 0"
             ]

      # A bit of the program's writes and a connection's drive the rest between them.
      assert told.(
               "xic a ote lamps[2]\nxic a otl lamps[0]\nmove 1 lamps[16#7]\n",
               Enum.map_join(
                 [1, 3, 4, 5],
                 "",
                 &"program o#{&1} lamp with fast\no#{&1}.a a\no#{&1}.l lamps[#{&1}]\n"
               )
             ) == [
               "`lamps` is an array of output points, `card.q.0` to `card.q.7`, but nothing drives `lamps[6]`: it stays at 0"
             ]

      assert told.("xic a ote lamps[slot]\n", "") == []
      assert told.("xic a ote lamps[2]\nxic a ote lamps[slot]\n", "") == []
    end

    test "an array refused for its sizes takes no address, so overlaps nothing" do
      {:error, diagnostics} =
        checked(
          "task fast interval 10 priority 1\nvar_global grid int[2,2,2,2] at card.i.0\n" <>
            "var_global b bool at card.i.3\nvar_global a bool\nprogram o1 lamp with fast\n" <>
            "o1.a b\no1.l a\n"
        )

      assert Enum.map(diagnostics, & &1.message) == [
               "`grid` is declared with 4 dimensions, `[2,2,2,2]`: an array has one to three, as in `int[8]`, `int[4,8]` or `int[2,3,4]`"
             ]
    end

    test "an element of a global whose line is refused is silent, as its name is" do
      {:error, diagnostics} =
        checked(
          "task fast interval 10 priority 1\nvar_global lamps bool[8] at card.q.0 x\n" <>
            "var_global a bool\nprogram o1 lamp with fast\no1.a a\no1.l lamps[1]\n"
        )

      assert Enum.map(diagnostics, & &1.message) == [
               "unexpected `x` after the declaration of `lamps`"
             ]
    end
  end

  describe "a cycle" do
    defp cycled(runtime, inputs) do
      {runtime, outputs, _events} = Runtime.cycle(runtime, 10, inputs)
      {runtime, outputs}
    end

    test "sets each element by its name and gives each output element by its own" do
      runtime = Runtime.start(oven())
      assert Runtime.get!(runtime, "temps") == List.duplicate(0.0, 8)

      {runtime, outputs} = cycled(runtime, %{"temps[3]" => 150, "temps[5]" => 16_777_217})
      assert Runtime.get!(runtime, "temps") == [0.0, 0.0, 0.0, 150.0, 0.0, 16_777_216.0, 0.0, 0.0]
      assert Runtime.get!(runtime, "temps[3]") === 150.0

      assert outputs ==
               Map.new(0..7, &{"lamps[#{&1}]", if(&1 in [3, 5], do: 1, else: 0)})

      # The rest of the array is kept from cycle to cycle, as an input point is.
      {runtime, outputs} = cycled(runtime, %{"temps[0]" => 101.5})

      assert Runtime.get!(runtime, "temps") == [
               101.5,
               0.0,
               0.0,
               150.0,
               0.0,
               16_777_216.0,
               0.0,
               0.0
             ]

      assert Runtime.get!(runtime, "first") === 101.5
      assert outputs["lamps[0]"] == 1 and outputs["lamps[3]"] == 1

      # Every element at once, the array laid over in one pass, as each alone.
      all = Map.new(0..7, &{"temps[#{&1}]", &1 * 30})
      {runtime, outputs} = cycled(runtime, all)
      assert Runtime.get!(runtime, "temps") == Enum.map(0..7, &(&1 * 30.0))
      assert outputs == Map.new(0..7, &{"lamps[#{&1}]", if(&1 * 30 > 100, do: 1, else: 0)})

      # A restart keeps the input image, an input array's among it, and the outputs go to 0.
      restarted = Runtime.restart(runtime, :cold)
      assert Runtime.get!(restarted, "temps") == Enum.map(0..7, &(&1 * 30.0))
      assert Runtime.get!(restarted, "lamps") == List.duplicate(0, 8)
    end

    test "more than 16 elements set at once are laid over the array as one by one" do
      {:ok, wide} =
        Logex.compile("var_input t int[40]\nvar_output s dint\nmove t[39] s\n", name: "wide")

      {:ok, c} =
        Configuration.compile(
          "w",
          "var_global t int[40] at card.i.0\nvar_global s dint\nprogram w wide\nw.t t\nw.s s\n",
          %{"wide" => wide}
        )

      runtime = Runtime.start(c)

      for set <- [Enum.to_list(0..39), Enum.take_every(0..39, 2), [0, 39], Enum.to_list(20..39)] do
        inputs = Map.new(set, &{"t[#{&1}]", &1 + 1})
        {all, _} = cycled(runtime, inputs)

        each =
          Enum.reduce(set, runtime, fn i, rt -> elem(cycled(rt, %{"t[#{i}]" => i + 1}), 0) end)

        assert Runtime.get!(all, "t") == Runtime.get!(each, "t")
        assert Runtime.get!(all, "t") == for(i <- 0..39, do: if(i in set, do: i + 1, else: 0))
      end
    end

    # M5-13's review: an output array of more dimensions, each element given by its own
    # name and, through the runner, at its own address, the rightmost subscript fastest,
    # beside an input array of more dimensions placed the same way.
    test "an array of more dimensions gives each output element by its own name and address" do
      {:ok, grid} =
        Logex.compile(
          "var_input ti int[2,3]\nvar_output tq dint[2,3]\n" <>
            Enum.map_join(0..1, "", fn i ->
              Enum.map_join(0..2, "", &"add ti[#{i},#{&1}] #{10 * i + &1} tq[#{i},#{&1}]\n")
            end),
          name: "grid"
        )

      {:ok, c} =
        Configuration.compile(
          "g",
          "task fast interval 10 priority 1\nvar_global ti int[2,3] at card.i.0\n" <>
            "var_global tq dint[2,3] at card.q.0\nprogram g grid with fast\ng.ti ti\ng.tq tq\n",
          %{"grid" => grid}
        )

      {_runtime, outputs, _events} =
        Runtime.cycle(Runtime.start(c), 10, %{"ti[0,1]" => 100, "ti[1,0]" => 200})

      assert outputs == %{
               "tq[0,0]" => 0,
               "tq[0,1]" => 101,
               "tq[0,2]" => 2,
               "tq[1,0]" => 210,
               "tq[1,1]" => 11,
               "tq[1,2]" => 12
             }

      {:ok, clock} = Manual.start_link()
      {:ok, card} = Sim.start_link(clock: clock, inputs: 6, outputs: 6)

      {:ok, runner} =
        Runner.start_link(
          configuration: c,
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock}
        )

      Sim.set(card, %{[1] => 100, [3] => 200, [5] => 300})
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "ti") == [[0, 100, 0], [200, 0, 300]]
      assert Runner.get!(runner, "tq[1,2]") == 312

      assert Sim.outputs(card) ==
               %{[0] => 0, [1] => 101, [2] => 2, [3] => 210, [4] => 11, [5] => 312}

      Runner.stop(runner)
    end

    # Decision 241: a located array of input points set whole, a list of its shape, each
    # element stored as its point's value is, the array replaced whole.
    test "sets a located array of input points whole, as a list" do
      runtime = Runtime.start(oven())
      {runtime, _outputs} = cycled(runtime, %{"temps[2]" => 7})

      {runtime, outputs} =
        cycled(runtime, %{"temps" => [150, 0.1, 16_777_217, 1, 2, 3, 4, 5]})

      assert Runtime.get!(runtime, "temps") ==
               [150.0, 0.10000000149011612, 16_777_216.0, 1.0, 2.0, 3.0, 4.0, 5.0]

      assert outputs["lamps[0]"] == 1 and outputs["lamps[2]"] == 1 and outputs["lamps[1]"] == 0

      # Kept from cycle to cycle, an element then set alone.
      {runtime, _outputs} = cycled(runtime, %{"temps[7]" => 50})
      assert Runtime.get!(runtime, "temps[2]") === 16_777_216.0
      assert Runtime.get!(runtime, "temps[7]") === 50.0

      # More dimensions: a list of lists, the rightmost subscript fastest.
      {:ok, grid} =
        Logex.compile("var_input ti int[2,3]\nvar_output q bool\ngt ti[1,2] 0 ote q",
          name: "grid"
        )

      {:ok, c} =
        Configuration.compile(
          "g",
          "task fast interval 10 priority 1\nvar_global ti int[2,3] at card.i.0\n" <>
            "var_global q bool at card.q.0\nprogram g grid with fast\ng.ti ti\ng.q q\n",
          %{"grid" => grid}
        )

      {runtime, outputs, _} =
        Runtime.cycle(Runtime.start(c), 10, %{"ti" => [[1, 2, 3], [4, 5, 6]]})

      assert Runtime.get!(runtime, "ti[1,2]") == 6
      assert outputs == %{"q" => 1}

      raises(
        "input `ti` is an array of 2 by 3 ints: its value must be a list of 2 lists of 3 elements, found [1, 2, 3, 4, 5, 6]",
        fn -> Runtime.cycle(runtime, 10, %{"ti" => [1, 2, 3, 4, 5, 6]}) end
      )

      # Misfits ten and then a count.
      {:ok, c} =
        Configuration.compile(
          "g",
          "task fast interval 10 priority 1\nvar_global ti int[12] at card.i.0\n" <>
            "var_global q bool at card.q.0\nprogram g grid12 with fast\ng.ti ti\ng.q q\n",
          %{
            "grid12" =>
              elem(
                Logex.compile("var_input ti int[12]\nvar_output q bool\ngt ti[1] 0 ote q",
                  name: "grid12"
                ),
                1
              )
          }
        )

      runtime = Runtime.start(c)

      for {bad, more} <- [{11, "1 more element"}, {12, "2 more elements"}] do
        lines =
          for i <- 0..9,
              do: "input `ti[#{i}]` is an int: its value must be an integer, found 1.5"

        raises(
          Enum.join(lines, "\n") <>
            "\ninput `ti` is an array of 12 ints, with #{more} outside its type, not listed",
          fn ->
            Runtime.cycle(runtime, 10, %{
              "ti" => List.duplicate(1.5, bad) ++ List.duplicate(0, 12 - bad)
            })
          end
        )
      end

      # Ten misfits exactly are each listed, with no count.
      lines =
        for i <- 0..9, do: "input `ti[#{i}]` is an int: its value must be an integer, found 1.5"

      raises(Enum.join(lines, "\n"), fn ->
        Runtime.cycle(runtime, 10, %{"ti" => List.duplicate(1.5, 10) ++ [0, 0]})
      end)
    end

    test "refuses the array named whole, an output element, an element its array lacks and a misfit" do
      runtime = Runtime.start(oven())

      for {inputs, message} <- [
            # Decision 241: the array whole is a list of its shape, each element a value
            # of its type, as a host's array var_input is (decision 222).
            {%{"temps" => List.duplicate(1.0, 7)},
             "input `temps` is an array of 8 reals: its value must be a list of 8 elements, found [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]"},
            {%{"temps" => {1.0}},
             "input `temps` is an array of 8 reals: its value must be a list of 8 elements, found {1.0}"},
            {%{"temps" => [1.0, true, 2.0, 1.0e39, 1.0, 1.0, 1.0, 1.0]},
             "input `temps[1]` is a real: its value must be a number, found true\n" <>
               "input `temps[3]` is a real: 1.0e39 is beyond a real's range, -3.4028234663852886e38 to 3.4028234663852886e38"},
            {%{"temps" => List.duplicate(1.0, 8), "temps[3]" => 2.0, "temps[1]" => 2.0},
             "inputs `temps` and `temps[1]` and `temps[3]` each set `temps`, an array of 8 reals (line 3): a call sets an array whole or by its elements, not both"},
            {%{"lamps" => List.duplicate(1, 8)},
             "input `lamps` is an array of output points, `card.q.0` to `card.q.7`, not an input point: only an input point is set from outside"},
            {%{"lamps[2]" => 1},
             ~s|input `lamps[2]` is an output point (at `card.q.2`), not an input point: only an input point is set from outside|},
            {%{"temps[8]" => 1.0},
             ~s|input `temps[8]` is not an input point: `temps` is an array of input points, each element set by its name as its subscripts' values, `temps[0]` to `temps[7]`|},
            {%{"temps[03]" => 1.0},
             ~s|input `temps[03]` is not an input point: `temps` is an array of input points, each element set by its name as its subscripts' values, `temps[0]` to `temps[7]`|},
            {%{"temps[1]" => true},
             "input `temps[1]` is a real: its value must be a number, found true"},
            {%{"temps[1]" => 1.0e39},
             "input `temps[1]` is a real: 1.0e39 is beyond a real's range, -3.4028234663852886e38 to 3.4028234663852886e38"},
            {%{"nope" => 1},
             "input `nope` is not an input point: the input points are `temps[0]` to `temps[7]`"},
            # M5-13's review: an element the lexer reads as one name is quoted as a misfit's
            # is, beside it in one message; anything else is shown as the host gave it.
            {%{"temps[9]" => 1.0, "temps[1]" => 1.0e39, "temps[1, 2]" => 1.0, "temps[2" => 1.0},
             Enum.join(
               [
                 "input \"temps[1, 2]\" is not an input point: `temps` is an array of input points, each element set by its name as its subscripts' values, `temps[0]` to `temps[7]`",
                 "input `temps[1]` is a real: 1.0e39 is beyond a real's range, -3.4028234663852886e38 to 3.4028234663852886e38",
                 "input \"temps[2\" is not an input point: `temps` is an array of input points, each element set by its name as its subscripts' values, `temps[0]` to `temps[7]`",
                 "input `temps[9]` is not an input point: `temps` is an array of input points, each element set by its name as its subscripts' values, `temps[0]` to `temps[7]`"
               ],
               "\n"
             )}
          ] do
        raises(message, fn -> Runtime.cycle(runtime, 10, inputs) end)
      end

      # An element of a global array with no location is no point either.
      {:ok, c} =
        compiled(
          String.replace(
            @oven,
            "var_global first real\n",
            "var_global first real\nvar_global ws int[2]\n"
          )
        )

      raises(
        ~s|input `ws[0]` is an element of a global with no location, not an input point: only an input point is set from outside|,
        fn -> Runtime.cycle(Runtime.start(c), 10, %{"ws[0]" => 1}) end
      )

      raises(
        "input `ws` is an array with no location, not an input point: only an input point is set from outside",
        fn -> Runtime.cycle(Runtime.start(c), 10, %{"ws" => [1, 2]}) end
      )
    end
  end

  describe "the devices" do
    test "a sim of fewer points refuses a range past them, at bind and at init" do
      {:ok, card} = Sim.start_link(inputs: 6, outputs: 8)

      raises(
        "the device `card`'s adapter options: `temps[6]` is at `card.i.6`, past the sim's 6 inputs, `card.i.0` to `card.i.5`\n" <>
          "the device `card`'s adapter options: `temps[7]` is at `card.i.7`, past the sim's 6 inputs, `card.i.0` to `card.i.5`",
        fn -> Logex.IO.bind!(oven(), %{"card" => {Sim, sim: card}}) end
      )

      # One of a sim's points is its only address; an address of more fields is past it.
      points = [%Point{name: "x", direction: :input, address: [0, 1], type: :bool}]

      assert Sim.check("rack", points, sim: card) == [
               "`x` is at `rack.i.0.1`, past the sim's 6 inputs, `rack.i.0` to `rack.i.5`"
             ]

      # init/3 refuses the first, as its check would.
      raises(
        "`temps[6]` is at `card.i.6`, past the sim's 6 inputs, `card.i.0` to `card.i.5`",
        fn -> Sim.init("card", Map.fetch!(Logex.IO.points(oven()), "card"), sim: card) end
      )

      # Many past are counted after the first ten.
      {:ok, one} = Sim.start_link(outputs: 1, inputs: 1)

      many =
        for i <- 0..20, do: %Point{name: "p#{i}", direction: :output, address: [i], type: :bool}

      lines = Sim.check("d", many, sim: one)
      assert length(lines) == 11
      assert List.last(lines) == "and 10 more points past the sim's"

      # A sim of as many points as the range takes them all.
      {:ok, exact} = Sim.start_link(inputs: 8, outputs: 8)

      assert [{"card", Sim, [sim: ^exact], _points}] =
               Logex.IO.bind!(oven(), %{"card" => {Sim, sim: exact}})
    end

    test "a device no adapter is bound to names each array's range" do
      raises(
        "no adapter is bound to the device `card`, which `temps[0]` to `temps[7]` (card.i.0 to card.i.7) and `lamps[0]` to `lamps[7]` (card.q.0 to card.q.7) are at",
        fn -> Logex.IO.bind!(oven(), %{}) end
      )
    end
  end

  describe "through the runner" do
    defp running(dir, opts \\ []) do
      {:ok, clock} = Manual.start_link()
      {:ok, card} = Sim.start_link([clock: clock, inputs: 8, outputs: 8] ++ opts)

      {:ok, runner} =
        Runner.start_link(
          configuration: oven(),
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      %{runner: runner, clock: clock, card: card, file: Path.join(dir, "forces")}
    end

    defp lamps(card), do: for(i <- 0..7, do: Map.get(Sim.outputs(card), [i]))

    test "reads and writes each element at its own address", %{tmp_dir: dir} do
      %{runner: runner, clock: clock, card: card} = running(dir, reports: true)
      Sim.set(card, %{[1] => 120, [6] => 99.5, [7] => 100.5})
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == [0.0, 120.0, 0.0, 0.0, 0.0, 0.0, 99.5, 100.5]
      assert lamps(card) == [0, 1, 0, 0, 0, 0, 0, 1]

      # A read device, as a reporting one: its change of one element reaches that element.
      Sim.set(card, [1], 80)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps[1]") === 80.0
      assert lamps(card) == [0, 0, 0, 0, 0, 0, 0, 1]
      Runner.stop(runner)

      %{runner: runner, clock: clock, card: card} = running(dir)
      Sim.set(card, %{[3] => 300})
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps[3]") === 300.0
      assert lamps(card) == [0, 0, 0, 1, 0, 0, 0, 0]
      Runner.stop(runner)
    end

    test "a force names one element, held against its device, its line in the file", %{
      tmp_dir: dir
    } do
      %{runner: runner, clock: clock, card: card, file: file} = running(dir, reports: true)
      Sim.set(card, %{[3] => 50, [4] => 20})
      assert Runner.force(runner, "temps[3]", 150) == :ok
      assert Runner.status(runner).forces == %{"temps[3]" => 150.0}
      assert File.read!(file) == "temps[3] 150.0\n"
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == [0.0, 0.0, 0.0, 150.0, 20.0, 0.0, 0.0, 0.0]
      assert lamps(card) == [0, 0, 0, 1, 0, 0, 0, 0]

      # Held against its device; the elements beside it still read the device.
      Sim.set(card, %{[3] => 10, [4] => 200})
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == [0.0, 0.0, 0.0, 150.0, 200.0, 0.0, 0.0, 0.0]

      # Two elements forced, the file in name order, `temps[10]` before `temps[2]` were
      # there one; an unforce puts back the device's last value of that element alone.
      assert Runner.force(runner, "temps[0]", 0.1) == :ok
      assert File.read!(file) == "temps[0] 0.1\ntemps[3] 150.0\n"
      assert Runner.unforce(runner, "temps[3]") == :ok
      assert File.read!(file) == "temps[0] 0.1\n"
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps[3]") === 10.0
      assert Runner.get!(runner, "temps[0]") === 0.10000000149011612

      Runner.force(runner, "temps[7]", 101)
      assert Runner.unforce_all(runner) == :ok
      assert File.read!(file) == ""
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == [0.0, 0.0, 0.0, 10.0, 200.0, 0.0, 0.0, 0.0]
      Runner.stop(runner)
    end

    test "refuses a force of the array whole, of an output and of an element it lacks", %{
      tmp_dir: dir
    } do
      %{runner: runner} = running(dir)

      for {name, value, message} <- [
            # Decision 241: the array whole is forced to a list of its shape, every element a
            # value of its type, nothing forced where one is not.
            {"temps", 1.0,
             "`temps` is an array of 8 reals, forced to a list of 8 elements in the elements' order, got: 1.0"},
            {"temps", [[1.0]] ++ List.duplicate(1.0, 7),
             "`temps` is an array of 8 reals, forced to a list of 8 elements in the elements' order, got: [[1.0], 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]"},
            {"temps", [1.0, true, 1.0, 1.0e39, 1.0, 1.0, 1.0, 1.0],
             "`temps[1]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: true\n" <>
               "`temps[3]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0e39"},
            {"lamps", 1,
             "`lamps` is an array of output points, `card.q.0` to `card.q.7`: only an input point is forced"},
            {"lamps[2]", 1,
             "`lamps[2]` is an output point, at `card.q.2`: only an input point is forced"},
            {"temps[8]", 1.0,
             "`temps[8]` is no input point of `oven`: its array is one of input points, each element forced by its name as its subscripts' values, `temps[0]` to `temps[7]`"},
            {"temps[1]", true,
             "`temps[1]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: true"}
          ] do
        raises(message, fn -> Runner.force(runner, name, value) end)
      end

      assert Runner.status(runner).forces == %{}
      Runner.stop(runner)
    end

    test "the forces file names an element, read at every start; the array whole is refused",
         %{tmp_dir: dir} do
      file = Path.join(dir, "forces")
      File.write!(file, "temps[03] 1\n")
      {:ok, clock} = Manual.start_link()
      {:ok, card} = Sim.start_link(clock: clock)

      start = fn ->
        Runner.start_link(
          configuration: oven(),
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock},
          forces: file
        )
      end

      raises(
        "#{file}: line 1: `temps[03]` is no input point of `oven`: its array is one of input points, each element forced by its name as its subscripts' values, `temps[0]` to `temps[7]`",
        start
      )

      # Decision 241: a whole array's line holds its name and one value an element.
      File.write!(file, "temps 1\nlamps[0] 1\nlamps 1 1 1 1 1 1 1 1\n")

      raises(
        "#{file}: line 1: `temps` is an array of 8 reals, forced whole on one line, its name and then 8 values in the elements' order: the line holds 1\n" <>
          "#{file}: line 2: `lamps[0]` is an output point, at `card.q.0`: only an input point is forced\n" <>
          "#{file}: line 3: `lamps` is an array of output points, `card.q.0` to `card.q.7`: only an input point is forced",
        start
      )

      File.write!(file, "temps 1 2 3\ntemps[0] 1\n")

      raises(
        "#{file}: line 1: `temps` is an array of 8 reals, forced whole on one line, its name and then 8 values in the elements' order: the line holds 3\n" <>
          "#{file}: line 2: `temps[0]` is forced on line 1 already",
        start
      )

      File.write!(file, "temps 1 2 3 4 5 6 7 8 9\n")

      raises(
        "#{file}: line 1: `temps` is an array of 8 reals, forced whole on one line, its name and then 8 values in the elements' order: the line holds 9",
        start
      )

      # Every misfit a line, and an element a whole line forces named twice either way.
      File.write!(
        file,
        "temps 1 2 1.0e39 4 5 6 1.0e40 8\ntemps[2] 1\ntemps[5] 1\ntemps 1 1 1 1 1 1 1 1\n" <>
          "eye 1 2\n"
      )

      raises(
        "#{file}: line 1: `temps[2]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0e39\n" <>
          "#{file}: line 1: `temps[6]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0e40\n" <>
          "#{file}: line 2: `temps[2]` is forced on line 1 already\n" <>
          "#{file}: line 3: `temps[5]` is forced on line 1 already\n" <>
          "#{file}: line 4: `temps[0]` is forced on line 1 already\n" <>
          "#{file}: line 5: `eye 1 2` is no force: a line holds an input point's name and its value, as `eye_1 1`",
        start
      )

      File.write!(file, "temps[5] 1\ntemps 1 1 1 1 1 1 1 1\n")
      raises("#{file}: line 2: `temps[5]` is forced on line 1 already", start)

      # M5-14's review (provisional): a real element's misfit quoted as its line writes it.
      File.write!(file, "temps[2] 1.0E39\n")

      raises(
        "#{file}: line 1: `temps[2]` is a real, forced to a number from -3.4028234663852886e38 to 3.4028234663852886e38, got: 1.0E39",
        start
      )

      File.write!(file, "temps[2] 37.50\n")
      {:ok, runner} = start.()
      assert Runner.status(runner).forces == %{"temps[2]" => 37.5}
      assert Runner.get!(runner, "temps[2]") === 37.5
      Runner.stop(runner)
    end

    # Decision 241: the array named whole is forced to a list, each element then forced, and
    # unforced whole, each element reading its device's last value again; the file keeps
    # each element on its own line, and a whole line is read as each element forced.
    test "a force of the array whole forces each element, an unforce of it unforces each", %{
      tmp_dir: dir
    } do
      %{runner: runner, clock: clock, card: card, file: file} = running(dir, reports: true)
      Sim.set(card, %{[1] => 11, [6] => 66})
      Manual.advance(clock, 10)
      assert Runner.force(runner, "temps[7]", 7) == :ok

      values = [150, 0.1, 16_777_217, 0, 0, 0, 0, 0]
      assert Runner.force(runner, "temps", values) == :ok

      forced = [150.0, 0.10000000149011612, 16_777_216.0, 0.0, 0.0, 0.0, 0.0, 0.0]

      assert Runner.status(runner).forces ==
               Map.new(Enum.with_index(forced), fn {v, i} -> {"temps[#{i}]", v} end)

      assert File.read!(file) ==
               "temps[0] 150.0\ntemps[1] 0.1\ntemps[2] 16777216.0\ntemps[3] 0.0\n" <>
                 "temps[4] 0.0\ntemps[5] 0.0\ntemps[6] 0.0\ntemps[7] 0.0\n"

      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == forced
      assert lamps(card) == [1, 0, 1, 0, 0, 0, 0, 0]

      # Held against the device; an unforce of one element keeps the rest forced.
      Sim.set(card, %{[1] => 12, [6] => 67})
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == forced
      assert Runner.unforce(runner, "temps[6]") == :ok
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps[6]") === 67.0
      assert Runner.get!(runner, "temps[1]") === 0.10000000149011612

      # Unforced whole: each element its device's last value.
      assert Runner.unforce(runner, "temps") == :ok
      assert Runner.status(runner).forces == %{}
      assert File.read!(file) == ""
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == [0.0, 12.0, 0.0, 0.0, 0.0, 0.0, 67.0, 0.0]
      Runner.stop(runner)

      # A whole line, read at a start, each element forced, written back by element.
      File.write!(file, "temps 1 2.5 16#3 4 5 6 7 8\n")
      %{runner: runner, clock: clock} = running(dir)
      expected = [1.0, 2.5, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]

      assert Runner.status(runner).forces ==
               Map.new(Enum.with_index(expected), fn {v, i} -> {"temps[#{i}]", v} end)

      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps") == expected
      assert File.read!(file) == "temps 1 2.5 16#3 4 5 6 7 8\n"
      assert Runner.unforce(runner, "temps[0]") == :ok

      assert File.read!(file) ==
               "temps[1] 2.5\ntemps[2] 3.0\ntemps[3] 4.0\ntemps[4] 5.0\ntemps[5] 6.0\n" <>
                 "temps[6] 7.0\ntemps[7] 8.0\n"

      Runner.stop(runner)

      # The file the runner writes reads back to the very forces it holds.
      %{runner: runner} = running(dir)

      assert Runner.status(runner).forces ==
               Map.new(tl(Enum.with_index(expected)), fn {v, i} -> {"temps[#{i}]", v} end)

      Runner.stop(runner)
    end

    # Decision 241: a whole force's misfits, ten and then a count, nothing forced.
    test "a whole force's misfits are ten and then a count", %{tmp_dir: dir} do
      {:ok, grid} =
        Logex.compile("var_input ti int[12]\nvar_output q bool\ngt ti[1] 0 ote q", name: "grid12")

      {:ok, c} =
        Configuration.compile(
          "g",
          "task fast interval 10 priority 1\nvar_global ti int[12] at card.i.0\n" <>
            "var_global q bool at card.q.0\nprogram g grid12 with fast\ng.ti ti\ng.q q\n",
          %{"grid12" => grid}
        )

      {:ok, clock} = Manual.start_link()
      {:ok, card} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: c,
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      lines =
        for i <- 0..9,
            do: "`ti[#{i}]` is an int, forced to an integer from -32768 to 32767, got: 1.5"

      for {bad, more} <- [{11, "1 more element"}, {12, "2 more elements"}] do
        raises(
          Enum.join(lines, "\n") <>
            "\n`ti` is an array of 12 ints, with #{more} outside its type, not listed",
          fn ->
            Runner.force(runner, "ti", List.duplicate(1.5, bad) ++ List.duplicate(0, 12 - bad))
          end
        )
      end

      raises(Enum.join(lines, "\n"), fn ->
        Runner.force(runner, "ti", List.duplicate(1.5, 10) ++ [0, 0])
      end)

      assert Runner.status(runner).forces == %{}
      Runner.stop(runner)
    end

    # M5-14's review (provisional): a forces file's misfit is quoted as its line writes it,
    # as decision 202 quotes a literal, `1.0e-400` and `16#8000` and never the 0.0 and the
    # 32768 they are read as, an element's line and a whole line's alike.
    test "a forces file's misfit at an int element is quoted as the line writes it", %{
      tmp_dir: dir
    } do
      {:ok, grid} =
        Logex.compile("var_input ti int[2,2]\nvar_output q bool\ngt ti[1,1] 0 ote q",
          name: "grid22"
        )

      {:ok, c} =
        Configuration.compile(
          "g",
          "task fast interval 10 priority 1\nvar_global ti int[2,2] at card.i.0\n" <>
            "var_global q bool at card.q.0\nprogram g grid22 with fast\ng.ti ti\ng.q q\n",
          %{"grid22" => grid}
        )

      file = Path.join(dir, "forces")
      {:ok, clock} = Manual.start_link()
      {:ok, card} = Sim.start_link(clock: clock)

      start = fn ->
        Runner.start_link(
          configuration: c,
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock},
          forces: file
        )
      end

      int = "is an int, forced to an integer from -32768 to 32767, got: "

      File.write!(file, "ti[1,1] 1.0e-400\n")
      raises("#{file}: line 1: `ti[1,1]` #{int}1.0e-400", start)

      File.write!(file, "ti 1 2 3 1.0e-400\n")
      raises("#{file}: line 1: `ti[1,1]` #{int}1.0e-400", start)

      File.write!(file, "ti 16#8000 2 3.50 4\n")

      raises(
        "#{file}: line 1: `ti[0,0]` #{int}16#8000\n#{file}: line 1: `ti[1,0]` #{int}3.50",
        start
      )

      # The host's value is quoted as the value it is, which has no other spelling.
      File.write!(file, "")
      {:ok, runner} = start.()
      raises("`ti[1,1]` #{int}0.0", fn -> Runner.force(runner, "ti[1,1]", 0.0) end)
      Runner.stop(runner)
    end

    # The runner killed is reported by its devices as they go down.
    @tag :capture_log
    test "a force holds across a restart, a crash and a fresh start", %{tmp_dir: dir} do
      %{runner: runner, clock: clock, card: card, file: file} = running(dir, reports: true)
      Sim.set(card, %{[3] => 50, [5] => 60})
      Runner.force(runner, "temps[3]", 150)
      Manual.advance(clock, 10)

      # A value that does not fit at another element trips the plant; put right, it
      # restarts on what the card gives now, the force still on.
      Sim.set(card, [5], 1.0e39)

      assert %{status: :tripped, trip: {:io, "card", {:bad_value, [5], 1.0e39}}} =
               Runner.status(runner)

      Sim.set(card, [5], 70)
      assert Runner.restart(runner, :cold) == :ok
      assert Runner.get!(runner, "temps") == [0.0, 0.0, 0.0, 150.0, 0.0, 70.0, 0.0, 0.0]
      Manual.advance(clock, 10)
      assert lamps(card) == [0, 0, 0, 1, 0, 0, 0, 0]

      Process.flag(:trap_exit, true)
      Process.exit(runner, :kill)
      assert_receive {:EXIT, ^runner, :killed}

      {:ok, runner} =
        Runner.start_link(
          configuration: oven(),
          io: %{"card" => {Sim, sim: card}},
          clock: {Manual, clock},
          forces: file
        )

      assert %{forces: %{"temps[3]" => 150.0}} = Runner.status(runner)
      assert Runner.get!(runner, "temps") == [0.0, 0.0, 0.0, 150.0, 0.0, 70.0, 0.0, 0.0]
      Runner.unforce(runner, "temps[3]")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "temps[3]") === 50.0
      Runner.stop(runner)
    end

    test "a change refused for one element keeps the other elements it read (decision 143)",
         %{tmp_dir: dir} do
      %{runner: runner, clock: clock, card: card} = running(dir)
      Sim.fail(card, :read, {:value, [2], 1.0e39})
      Sim.set(card, %{[1] => 11.0, [3] => 33.0})
      Manual.advance(clock, 10)

      assert %{status: :tripped, trip: {:io, "card", {:bad_value, [2], 1.0e39}}} =
               Runner.status(runner)

      # The restart reads the card whole again, the good elements with it.
      assert Runner.restart(runner, :warm) == :ok
      assert Runner.get!(runner, "temps") == [0.0, 11.0, 0.0, 33.0, 0.0, 0.0, 0.0, 0.0]
      Runner.stop(runner)
    end
  end

  describe "an online edit (decision 156, and §4.9's located-I/O rule)" do
    alias Logex.Configuration.Edit

    defp edited(lines, programs \\ programs()) do
      {:ok, candidate} = Configuration.compile("oven", with_points(lines), programs)
      Edit.accept(Runtime.start(oven()), candidate)
    end

    defp refusals(lines, programs \\ programs()) do
      {:error, diagnostics} = edited(lines, programs)
      Enum.map(diagnostics, & &1.message)
    end

    test "refuses a located array moved, grown, unlocated, added or removed, by its range" do
      assert refusals(
               "var_global temps real[8] at card.i.1\nvar_global lamps bool[8] at card.q.0\n"
             ) ==
               [
                 "`temps` is at `card.i.0` to `card.i.7` in the running configuration and at `card.i.1` to `card.i.8` in the candidate: located I/O changes only with a restart"
               ]

      assert refusals("var_global temps real[8]\nvar_global lamps bool[8] at card.q.0\n") == [
               "`temps` is at `card.i.0` to `card.i.7` in the running configuration and has no location in the candidate: located I/O changes only with a restart"
             ]

      # Decision 244: grown, it is refused once, for its range, and the program for its own
      # tag; where until then the global was told its type too.
      {:ok, wider} =
        Logex.compile(String.replace(@zones, "temps real[8]", "temps real[10]"), name: "zones")

      assert refusals(
               "var_global temps real[10] at card.i.0\nvar_global lamps bool[8] at card.q.0\n",
               %{"zones" => wider}
             ) == [
               "`temps` is at `card.i.0` to `card.i.7` in the running configuration and at `card.i.0` to `card.i.9` in the candidate: located I/O changes only with a restart",
               "`temps` is an array of 8 reals in the running program and an array of 10 reals in the candidate: a tag's type changes only with a restart"
             ]

      # Grown and unlocated: its range alone.
      for {lines, range} <- [
            {"var_global temps real[10]\nvar_global lamps bool[8] at card.q.0\n",
             "at `card.i.0` to `card.i.7` in the running configuration and has no location"}
          ] do
        {:ok, candidate} = Configuration.compile("oven", with_points(lines), %{"zones" => wider})
        {:error, diagnostics} = Edit.accept(Runtime.start(oven()), candidate)
        globals = Enum.filter(Enum.map(diagnostics, & &1.message), &(&1 =~ "configuration"))

        assert globals == [
                 "`temps` is #{range} in the candidate: located I/O changes only with a restart"
               ]
      end

      # Its range kept and its elements' type changed: told its type, as before.
      {:ok, ints} =
        Logex.compile(
          @zones
          |> String.replace("temps real[8]", "temps int[8]")
          |> String.replace("sp    real", "sp    int")
          |> String.replace("first real", "first int"),
          name: "zones"
        )

      {:ok, candidate} =
        Configuration.compile(
          "oven",
          @oven
          |> String.replace("temps real[8]", "temps int[8]")
          |> String.replace("sp    real 100.0", "sp    int 100")
          |> String.replace("first real", "first int"),
          %{"zones" => ints}
        )

      {:error, diagnostics} = Edit.accept(Runtime.start(oven()), candidate)

      assert "`temps` is a global array of 8 reals in the running configuration and an array of 8 ints in the candidate: a global's type changes only with a restart" in Enum.map(
               diagnostics,
               & &1.message
             )

      refute Enum.any?(diagnostics, &(&1.message =~ "located I/O"))

      # An unlocated array grown is still told its type (decision 157).
      {:ok, original} =
        Configuration.compile("oven", @oven <> "var_global spare int[4]\n", programs())

      {:ok, candidate} =
        Configuration.compile("oven", @oven <> "var_global spare int[6]\n", programs())

      {:error, [diagnostic]} = Edit.accept(Runtime.start(original), candidate)

      assert diagnostic.message ==
               "`spare` is a global array of 4 ints in the running configuration and an array of 6 ints in the candidate: a global's type changes only with a restart"

      assert refusals(
               "var_global temps real[8] at card.i.0\nvar_global lamps bool[8] at card.q.0\n" <>
                 "var_global more int[4] at card.i.8\n"
             ) == [
               "`more` at `card.i.8` to `card.i.11` is added: located I/O changes only with a restart"
             ]

      {:ok, gone} =
        Configuration.compile(
          "oven",
          String.replace(@oven, "var_global lamps bool[8] at card.q.0\n", "")
          |> String.replace("  z.hot   lamps\n", ""),
          programs()
        )

      {:error, [diagnostic]} = Edit.accept(Runtime.start(oven()), gone)

      assert diagnostic.message ==
               "`lamps` at `card.q.0` to `card.q.7` (line 4 of the running configuration) is removed: located I/O changes only with a restart"

      # Moved in the text but the same range: nothing to refuse.
      assert {:ok, _edit, []} =
               edited(
                 "var_global lamps bool[8] at card.q.0\nvar_global temps real[8] at card.i.0\n"
               )
    end

    test "an element an edit stops driving is held at its output point, by its name" do
      {:ok, lamp} =
        Logex.compile("var_input a bool\nvar_output l bool\nxic a ote l\n", name: "lamp")

      programs = Map.put(programs(), "lamp", lamp)

      text =
        String.replace(
          @oven,
          "var_global first real\n",
          "var_global first real\nvar_global a bool\n"
        )

      {:ok, original} = Configuration.compile("oven", text, programs)

      {:ok, candidate} =
        Configuration.compile(
          "oven",
          String.replace(text, "  z.hot   lamps\n", "") <>
            "program o lamp with fast\n  o.a a\n  o.l lamps[2]\n",
          programs
        )

      {runtime, _outputs, _events} =
        Runtime.cycle(Runtime.start(original), 10, %{"temps[2]" => 500, "temps[4]" => 500})

      {:ok, edit, forecast} = Edit.accept(runtime, candidate)

      assert forecast ==
               for(
                 i <- [0, 1, 3, 4, 5, 6, 7],
                 do: {:held, "lamps[#{i}]", if(i == 4, do: 1, else: 0)}
               ) ++
                 [{:instance_added, "o", "lamp"}]

      {_edit, runtime, report} = Edit.test(edit, runtime)
      assert report == forecast
      {_runtime, outputs, _events} = Runtime.cycle(runtime, 10, %{})
      assert outputs == Map.new(0..7, &{"lamps[#{&1}]", if(&1 == 4, do: 1, else: 0)})
    end
  end

  describe "its growth, in reductions" do
    defp reductions(fun) do
      parent = self()

      {_pid, ref} =
        :erlang.spawn_opt(
          fn ->
            {:reductions, before} = Process.info(self(), :reductions)
            fun.()
            {:reductions, later} = Process.info(self(), :reductions)
            send(parent, {:counted, later - before})
          end,
          [:monitor, min_heap_size: 8_000_000]
        )

      receive do
        {:counted, n} -> receive(do: ({:DOWN, ^ref, _, _, _} -> n))
      end
    end

    defp sized(n) do
      {:ok, relay} =
        Logex.compile("var_input in bool\nvar_output out bool\nxic in ote out\n", name: "relay")

      text =
        "task fast interval 10 priority 1\nvar_global a bool at panel.i.0\nvar_global b bool at panel.q.0\n" <>
          "var_global t real[#{n}] at card.i.0\nvar_global l bool[#{n}] at card.q.0\n" <>
          "program r relay with fast\nr.in a\nr.out b\n"

      {:ok, c} = Configuration.compile("plant", text, %{"relay" => relay})
      c
    end

    test "a check, a start, the points and a cycle setting every element are linear in the elements" do
      measured =
        for n <- [256, 2048] do
          c = sized(n)
          runtime = Runtime.start(c)
          inputs = Map.new(0..(n - 1), &{"t[#{&1}]", 1.5})
          {runtime, _, _} = Runtime.cycle(runtime, 10, inputs)

          {reductions(fn -> Configuration.check(c) end), reductions(fn -> Runtime.start(c) end),
           reductions(fn -> Logex.IO.points(c) end),
           reductions(fn -> Runtime.cycle(runtime, 10, inputs) end),
           reductions(fn -> Runtime.cycle_outputs(runtime) end)}
        end

      [small, large] = Enum.map(measured, &Tuple.to_list/1)

      # Eight times the elements: each at most nine times the cost (measured about 8).
      for {s, l} <- Enum.zip(small, large), do: assert(l <= 9 * s, inspect({small, large}))
    end

    # A configuration with no located array cycles and restarts, a point at a time, in what
    # it did at a8af419, before M5-13: measured there with this very configuration, 105.625 a
    # pair of an input and an output point and 4.53 an output point's copy-out, and here
    # within half a reduction a point, which one more call a point would pass: runs vary by a
    # quarter of one, as the BEAM moves a Map.new by a reduction or two from run to run.
    test "a configuration of no located array cycles as before M5-13" do
      {:ok, relay} =
        Logex.compile("var_input in bool\nvar_output out bool\nxic in ote out\n", name: "relay")

      measure = fn n ->
        globals =
          Enum.map_join(1..n, "", fn i ->
            "var_global x#{i} bool at panel.i.#{i}\nvar_global f#{i} real at drive.i.#{i}\n" <>
              "var_global y#{i} bool at panel.q.#{i}\nvar_global w#{i} int[4]\n"
          end)

        text =
          "task fast interval 10 priority 1\nvar_global a bool at panel.i.0\nvar_global b bool at panel.q.0\n" <>
            globals <> "program r relay with fast\nr.in a\nr.out b\n"

        {:ok, c} = Configuration.compile("plant", text, %{"relay" => relay})
        inputs = Map.merge(Map.new(1..n, &{"x#{&1}", 1}), Map.new(1..n, &{"f#{&1}", 1.5}))
        {runtime, _, _} = Runtime.cycle(Runtime.start(c), 10, inputs)

        {reductions(fn -> Runtime.cycle(runtime, 10, inputs) end),
         reductions(fn -> Runtime.cycle_outputs(runtime) end),
         reductions(fn -> Runtime.restart(runtime, :cold) end)}
      end

      {c32, o32, r32} = measure.(32)
      {c64, o64, r64} = measure.(64)
      assert_in_delta (c64 - c32) / 32, 105.625, 0.5
      assert_in_delta (o64 - o32) / 32, 4.53, 0.5
      # A restart, measured there at 39.4 to 39.7 a group of four globals, an unlocated
      # array among them, which a located array's look-up would make 2 dearer.
      assert_in_delta (r64 - r32) / 32, 39.55, 0.5
    end
  end
end
