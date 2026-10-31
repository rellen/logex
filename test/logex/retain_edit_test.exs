defmodule Logex.RetainEditTest do
  # M6-7 (docs/organisation.md §4.9 and §4.13, decisions 270, 277, 278 and 302): an online
  # edit that adds or takes away `retain` on a program's tags, members, arrays and instances
  # reports `:retain_added` or `:retain_removed` by path, with the value the path holds,
  # and writes nothing; the next warm restart and the next store write follow the program
  # running; and a crash while a candidate is tested, then a fresh start with the original
  # configuration, meets the candidate's store by decision 277's matching.
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Edit, Retain, Runner, Runtime}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  @moduletag :tmp_dir
  @moduletag capture_log: true

  defp compiled(source, types \\ []) do
    {:ok, program} = Logex.compile(source, name: "p", types: types)
    program
  end

  # A program scanned `n` times with `go` high, each scan 10 ms on.
  defp scanned(program, n) do
    state = Runtime.put_inputs(program, Runtime.instance(program), %{"go" => 1})

    Enum.reduce(1..n, state, fn _, state ->
      {_outputs, state} = Runtime.scan(program, state, 10)
      state
    end)
  end

  defp kinds(report), do: for({kind, path, _value} <- report, do: {kind, path})

  @plain """
  var_input go bool
  var Q1count dint
  var_output Q2lamp bool
  var Q3lim int[3] 1 2 3
  var Q4t1 ton
  xic go move 5 count
  xic go ote lamp
  xic go ton t1 100
  """

  defp plain(count, lamp \\ "", lim \\ "", t1 \\ ""),
    do:
      compiled(
        String.replace(@plain, ["Q1", "Q2", "Q3", "Q4"], fn
          "Q1" -> count
          "Q2" -> lamp
          "Q3" -> lim
          "Q4" -> t1
        end)
      )

  describe "a program's tags (decisions 278 and 302)" do
    test "an edit that only changes a tag's qualifier reports it by path, with the value it " <>
           "holds, and writes nothing; untest reports the reverse, assemble and cancel neither" do
      running = plain("", "retain ")
      candidate = plain("retain ", "", "retain ", "retain ")
      state = scanned(running, 3)

      expected_test = [
        {:retain_added, "count", 5},
        {:retain_added, "lim", [1, 2, 3]},
        {:retain_added, "t1", state.env["t1"]},
        {:retain_removed, "lamp", 1}
      ]

      {:ok, edit, forecast} = Edit.accept(running, candidate, state)
      assert forecast == expected_test

      {edit, tested, report} = Edit.test(edit, state)
      assert report == expected_test
      # Nothing written: the state as the step found it but for the switch's own mark.
      assert tested == %{state | switched: true}

      {edit, untested, report} = Edit.untest(edit, tested)

      assert report ==
               Enum.sort(
                 for {kind, path, value} <- expected_test,
                     do: {swapped(kind), path, value}
               )

      assert untested == tested

      # Cancel from an untest prunes nothing here and reports no qualifier.
      assert {^running, ^untested, []} = Edit.cancel(edit, untested)

      # Assemble from a test reports none either: the switch has said it.
      {:ok, edit, _forecast} = Edit.accept(running, candidate, state)
      {edit, tested, _report} = Edit.test(edit, state)
      assert {^candidate, ^tested, []} = Edit.assemble(edit, tested)
    end

    test "`non_retain` and no qualifier are one: a report only where `retain` comes or goes" do
      for from <- ["", "retain ", "non_retain "], to <- ["", "retain ", "non_retain "] do
        running = plain(from, from, from, from)
        candidate = plain(to, to, to, to)
        state = scanned(running, 1)
        {:ok, _edit, report} = Edit.accept(running, candidate, state)

        expected = expected_kinds(from, to)

        assert Enum.uniq(for({kind, _, _} <- report, do: kind)) == expected, inspect({from, to})
        assert length(report) == 4 * length(expected)
      end
    end

    test "a qualifier changed with the type is refused for the type alone; a tag the " <>
           "candidate adds retained is `:added` alone" do
      running = plain("")
      state = scanned(running, 1)

      retyped =
        compiled(String.replace(@plain, "var Q1count dint", "var retain count int") |> blank())

      assert {:error, [diagnostic]} = Edit.accept(running, retyped, state)

      assert diagnostic.message ==
               "`count` is a dint in the running program and an int in the candidate: a " <>
                 "tag's type changes only with a restart"

      added = compiled("var retain spare dint 4\n" <> blank(@plain) <> "xic go move 1 spare\n")
      {:ok, _edit, report} = Edit.accept(running, added, state)
      assert report == [{:added, "spare", 4}]
    end

    test "the next warm restart and the image follow the program running at each stage" do
      running = plain("")
      candidate = plain("retain ")
      state = scanned(running, 2)
      {:ok, edit, _forecast} = Edit.accept(running, candidate, state)

      kept = fn edit, state ->
        program = Edit.running(edit)
        warm = Runtime.restart(program, state, :warm)
        {warm.env["count"], Map.has_key?(Runtime.retained(program, state).values, "count")}
      end

      assert kept.(edit, state) == {0, false}
      {edit, tested, _} = Edit.test(edit, state)
      assert kept.(edit, tested) == {5, true}
      {edit, untested, _} = Edit.untest(edit, tested)
      assert kept.(edit, untested) == {0, false}
      {edit, tested, _} = Edit.test(edit, untested)
      {kept_program, assembled, _} = Edit.assemble(edit, tested)
      assert Runtime.restart(kept_program, assembled, :warm).env["count"] == 5
    end
  end

  # The blocks: `latch` counts while its input is high; `cell` holds one and an array of
  # two; the program holds a cell and an array of two cells.
  defp latch(q \\ "", s \\ ""),
    do:
      Logex.compile("function_block latch\nvar_input #{s}s bool\nvar #{q}k dint\nxic s add k 1 k",
        name: "latch"
      )
      |> elem(1)

  defp cell(latch, l \\ ""),
    do:
      Logex.compile(
        "function_block cell\nvar_input go bool\nvar #{l}l latch\nvar ws latch[2]\n" <>
          "cal l go\ncal ws[0] go\ncal ws[1] go",
        name: "cell",
        types: [latch]
      )
      |> elem(1)

  defp holding(cell, c \\ ""),
    do:
      compiled(
        "var_input go bool\nvar #{c}c cell\nvar hs cell[2]\ncal c go\ncal hs[0] go\ncal hs[1] go",
        [cell]
      )

  describe "members, at depth, and arrays of instances (decisions 259, 270 and 310)" do
    test "a block's own member marked: each instance's member by path, an array of " <>
           "instances' by `[*]`, its value a list of each element's" do
      running = holding(cell(latch()))
      candidate = holding(cell(latch("retain ")))
      state = scanned(running, 3)
      {:ok, edit, forecast} = Edit.accept(running, candidate, state)

      assert forecast == [
               {:retain_added, "c.l.k", 3},
               {:retain_added, "c.ws[*].k", [3, 3]},
               {:retain_added, "hs[*].l.k", [3, 3]},
               {:retain_added, "hs[*].ws[*].k", [[3, 3], [3, 3]]}
             ]

      {_edit, tested, report} = Edit.test(edit, state)
      assert report == forecast
      assert tested == %{state | switched: true}
    end

    test "an instance marked whole is one path, its value its map" do
      running = holding(cell(latch()))
      candidate = holding(cell(latch()), "retain ")
      state = scanned(running, 1)
      {:ok, _edit, forecast} = Edit.accept(running, candidate, state)
      assert forecast == [{:retain_added, "c", state.env["c"]}]
    end

    test "a member only one version of a block declares is in no change: the instance " <>
           "is reported member by member" do
      {:ok, wide} =
        Logex.compile(
          "function_block latch\nvar_input s bool\nvar k dint\nvar m dint\nxic s add k 1 k",
          name: "latch"
        )

      running = compiled("var_input go bool\nvar s1 latch\ncal s1 go", [latch()])
      candidate = compiled("var_input go bool\nvar retain s1 latch\ncal s1 go", [wide])
      state = scanned(running, 2)
      {:ok, _edit, forecast} = Edit.accept(running, candidate, state)

      assert forecast == [
               {:added, "s1.m", 0},
               {:retain_added, "s1.k", 2},
               {:retain_added, "s1.s", 1}
             ]

      # And back: the member the running version lacks stays out of the change.
      {:ok, _edit, forecast} = Edit.accept(candidate, running, scanned(candidate, 2))
      assert kinds(forecast) == [{:retain_removed, "s1.k"}, {:retain_removed, "s1.s"}]
    end

    test "a mark moved between an instance and its members reports only the paths whose " <>
           "retention it changes, and one that keeps them nothing" do
      state = scanned(holding(cell(latch())), 1)
      running = holding(cell(latch()), "retain ")
      candidate = holding(cell(latch("retain ")))
      {:ok, _edit, forecast} = Edit.accept(running, candidate, state)

      assert kinds(forecast) ==
               [
                 {:retain_removed, "c.go"},
                 {:retain_removed, "c.l.s"},
                 {:retain_removed, "c.ws[*].s"},
                 {:retain_added, "hs[*].l.k"},
                 {:retain_added, "hs[*].ws[*].k"}
               ]
               |> Enum.sort()

      # `l` retained whole by its line, or by each of its members' lines: the same leaves,
      # whatever `retained` spells them, so only the array `ws` the second marks too.
      running = holding(cell(latch(), "retain "))
      candidate = holding(cell(latch("retain ", "retain ")))
      assert running.retained == ["c.l", "hs[*].l"]
      assert "c.l.k" in candidate.retained and "c.l" not in candidate.retained
      {:ok, _edit, forecast} = Edit.accept(running, candidate, scanned(running, 1))
      assert kinds(forecast) == [{:retain_added, "c.ws"}, {:retain_added, "hs[*].ws"}]
    end
  end

  describe "the cost (M6-7)" do
    # Reductions of `fun` in a process of its own, its heap big enough that the collector
    # does not run during it.
    defp reductions(fun) do
      parent = self()

      {_pid, ref} =
        :erlang.spawn_opt(
          fn ->
            {:reductions, a} = Process.info(self(), :reductions)
            fun.()
            {:reductions, b} = Process.info(self(), :reductions)
            send(parent, {:reductions, b - a})
          end,
          [:monitor, min_heap_size: 8_000_000]
        )

      receive do
        {:reductions, r} ->
          receive do
            {:DOWN, ^ref, _, _, _} -> r
          end
      end
    end

    defp sized(n, q),
      do:
        compiled(
          "var_input go bool\n" <>
            Enum.map_join(1..n, "", &"var #{q}c#{&1} dint\nvar #{q}l#{&1} latch\n") <>
            Enum.map_join(1..n, "", &"xic go add c#{&1} 1 c#{&1}\ncal l#{&1} go\n"),
          [latch()]
        )

    test "an edit's reports of retention grow linearly in the paths it changes" do
      [small, large] =
        for n <- [16, 64] do
          {running, candidate} = {sized(n, ""), sized(n, "retain ")}
          state = scanned(running, 1)
          {:ok, edit, forecast} = Edit.accept(running, candidate, state)
          assert length(forecast) == 2 * n

          {reductions(fn -> Edit.accept(running, candidate, state) end),
           reductions(fn -> Edit.test(edit, state) end)}
        end

      assert elem(large, 0) < 4.6 * elem(small, 0)
      assert elem(large, 1) < 4.6 * elem(small, 1)
    end

    # A plan of no retained path pays one clause a switch: an edit of programs that mark
    # nothing and one of programs that mark every line `non_retain`, which retain nothing,
    # switch at the same cost. (Their accepts differ, as at the parent, in the programs'
    # own checks.)
    test "an edit of programs that retain nothing pays nothing for the qualifiers" do
      state = scanned(sized(16, ""), 1)
      {:ok, edit, _} = Edit.accept(sized(16, ""), sized(16, ""), state)
      marked = sized(16, "non_retain ")
      {:ok, marked_edit, _} = Edit.accept(marked, marked, state)

      assert reductions(fn -> Edit.test(edit, state) end) ==
               reductions(fn -> Edit.test(marked_edit, state) end)
    end
  end

  # A box counter in a configuration: the original keeps its lamp and not its count, the
  # candidate its count and not its lamp.
  @tally """
  var_input eye bool
  var_external total_boxes dint
  var_output QLlamp bool
  var QBboxes ctu
  var e bool

  xic eye ctu boxes 1000
  xic eye ons e add total_boxes 1 total_boxes
  xic eye otl lamp
  """

  @plant """
  task fast interval 10 priority 1
  var_global eye_1 bool at panel.i.0
  var_global lamp_q bool at panel.q.0
  var_global QTtotal_boxes dint 0
  program t1 tally with fast
    t1.eye eye_1
    t1.lamp lamp_q
  """

  defp configured(boxes, lamp, total) do
    {:ok, tally} =
      Logex.compile(String.replace(@tally, ["QL", "QB"], &%{"QL" => lamp, "QB" => boxes}[&1]),
        name: "tally"
      )

    {:ok, config} =
      Configuration.compile("plant", String.replace(@plant, "QT", total), %{"tally" => tally})

    config
  end

  defp original, do: configured("", "retain ", "retain ")
  defp candidate, do: configured("retain ", "", "retain ")

  describe "a configuration's instances (decision 302's form)" do
    test "an instance's paths are reported by the instance's name beside a global's" do
      runtime =
        Enum.reduce([0, 1, 0, 1], Runtime.start(original()), fn eye, rt ->
          elem(Runtime.cycle(rt, 10, %{"eye_1" => eye}), 0)
        end)

      both = configured("retain ", "", "")
      {:ok, edit, forecast} = Configuration.Edit.accept(runtime, both)

      assert [
               {:retain_added, "t1.boxes", %{"cv" => 2, "q" => 0}},
               {:retain_removed, "t1.lamp", 1},
               {:retain_removed, "total_boxes", 2}
             ] = forecast

      {_edit, tested, report} = Configuration.Edit.test(edit, runtime)
      assert report == forecast

      for path <- ~w(t1.boxes.cv t1.lamp total_boxes lamp_q eye_1) do
        assert Runtime.get!(tested, path) == Runtime.get!(runtime, path), path
      end

      warm = Runtime.restart(tested, :warm)
      assert Enum.map(~w(t1.boxes.cv t1.lamp total_boxes), &Runtime.get!(warm, &1)) == [2, 0, 0]
    end
  end

  # ---- through the runner, on the manual clock ------------------------------------------

  # A clock started at a time a store's header names to the second, 2026-10-30T14:00:00Z.
  @wall 1_793_368_800_000

  defp rig(dir) do
    {:ok, clock} = Manual.start_link(now: @wall)
    {:ok, panel} = Sim.start_link(clock: clock)
    store = Path.join(dir, "plant.retain")

    opts = [
      configuration: original(),
      io: %{"panel" => {Sim, sim: panel}},
      clock: {Manual, clock},
      poll: 10,
      retain: store,
      retain_period: 100
    ]

    %{clock: clock, panel: panel, store: store, opts: opts}
  end

  defp pressed(%{panel: panel, clock: clock}, eyes) do
    for eye <- eyes do
      Sim.set(panel, [0], eye)
      Manual.advance(clock, 10)
    end
  end

  # The instance's retained paths in the store as the last write left it, the writer
  # settled first.
  defp stored(rig, runner) do
    Manual.advance(rig.clock, 100)
    synced(runner)
    {image, _written} = Retain.decode!(File.read!(rig.store), {rig.store, "plant"})
    Enum.sort(Map.keys(image.instances["t1"].values))
  end

  defp synced(runner) do
    for _ <- 1..2 do
      _ = :sys.get_state(writer(runner))
      _ = :sys.get_state(runner)
    end
  end

  defp writer(runner) do
    {:links, links} = Process.info(runner, :links)

    Enum.find(links, fn pid ->
      match?(
        {:dictionary, %{"$initial_call": {Logex.Runner.Writer, :init, 1}}},
        dictionary(Process.info(pid, :dictionary))
      )
    end)
  end

  defp dictionary({:dictionary, dictionary}), do: {:dictionary, Map.new(dictionary)}
  defp dictionary(nil), do: nil

  # A trip, the panel's read failing, and a warm restart, the eye low so that nothing
  # counts and nothing latches in its first round: the count and the lamp as it keeps them.
  defp warm(rig, runner) do
    Sim.set(rig.panel, [0], 0)
    Manual.advance(rig.clock, 10)
    Sim.fail(rig.panel, :read, {:error, :eio})
    Manual.advance(rig.clock, 10)
    assert %{status: :tripped} = Runner.status(runner)
    assert Runner.restart(runner, :warm) == :ok
    {Runner.get!(runner, "t1.boxes.cv"), Runner.get!(runner, "t1.lamp")}
  end

  defp killed(runner) do
    Process.unlink(runner)
    ref = Process.monitor(runner)
    Process.exit(runner, :kill)
    assert_receive {:DOWN, ^ref, :process, _, :killed}
  end

  defp opener_down(panel), do: down(GenServer.call(panel, :holder))

  defp down(nil), do: :ok

  defp down({pid, _device}) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, _}, 5000
  end

  @lamp ["lamp"]

  describe "through Logex.Runner (PLAN M6-7's Done-when)" do
    test "an edit that only changes qualifiers reports them by path and writes nothing; the " <>
           "next period's write follows the program running at each stage",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      before = for path <- ~w(t1.boxes.cv t1.lamp total_boxes), do: Runner.get!(runner, path)
      assert before == [2, 1, 2]
      assert stored(rig, runner) == @lamp

      assert {:ok, forecast} = Runner.accept(runner, candidate())

      assert kinds(forecast) == [
               {:retain_added, "t1.boxes"},
               {:retain_removed, "t1.lamp"}
             ]

      assert {:ok, report} = Runner.test(runner)
      assert kinds(report) == kinds(forecast)

      assert for(path <- ~w(t1.boxes.cv t1.lamp total_boxes), do: Runner.get!(runner, path)) ==
               before

      boxes = stored(rig, runner)
      assert "boxes.cv" in boxes and "lamp" not in boxes

      assert {:ok, report} = Runner.untest(runner)
      assert kinds(report) == [{:retain_added, "t1.lamp"}, {:retain_removed, "t1.boxes"}]
      assert stored(rig, runner) == @lamp

      assert {:ok, []} = Runner.cancel(runner)
      assert stored(rig, runner) == @lamp

      assert {:ok, _forecast} = Runner.accept(runner, candidate())
      assert {:ok, _report} = Runner.test(runner)
      assert {:ok, []} = Runner.assemble(runner)
      assert stored(rig, runner) == boxes
      assert Runner.stop(runner) == :ok
    end

    test "the next warm restart follows the program running at each stage", %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])

      # Accepted, the original runs: its lamp kept, its count not.
      assert {:ok, _forecast} = Runner.accept(runner, candidate())
      assert warm(rig, runner) == {0, 1}
      pressed(rig, [1, 0, 1])

      assert {:ok, _report} = Runner.test(runner)
      assert warm(rig, runner) == {2, 0}
      pressed(rig, [1, 0, 1])

      assert {:ok, _report} = Runner.untest(runner)
      assert warm(rig, runner) == {0, 1}
      pressed(rig, [1, 0, 1])

      assert {:ok, _report} = Runner.test(runner)
      assert {:ok, []} = Runner.assemble(runner)
      assert warm(rig, runner) == {2, 0}
      assert Runner.stop(runner) == :ok
    end

    test "a crash while a candidate is tested, then a fresh start with the original " <>
           "configuration, meets the candidate's store by decision 277's matching",
         %{tmp_dir: dir} do
      rig = rig(dir)
      {:ok, runner} = Runner.start_link(rig.opts)
      pressed(rig, [1, 0, 1])
      assert {:ok, _forecast} = Runner.accept(runner, candidate())
      assert {:ok, _report} = Runner.test(runner)
      pressed(rig, [0, 1, 0])
      boxes = stored(rig, runner)
      assert "boxes.cv" in boxes and "lamp" not in boxes
      written = File.read!(rig.store)
      killed(runner)
      assert File.read!(rig.store) == written

      opener_down(rig.panel)
      {:ok, runner} = Runner.start_link(rig.opts)

      # The original retains the lamp, which the store does not hold, and not the count,
      # which it does: the count dropped as unretained, the lamp started as declared.
      assert Runner.status(runner).retain.dropped == [{"t1.boxes", :unretained}]
      assert Runner.get!(runner, "t1.boxes.cv") == 0
      assert Runner.get!(runner, "t1.lamp") == 0
      assert Runner.get!(runner, "total_boxes") == 3
      assert Runner.stop(runner) == :ok
    end
  end

  defp swapped(:retain_added), do: :retain_removed
  defp swapped(:retain_removed), do: :retain_added

  defp blank(source), do: String.replace(source, ["Q1", "Q2", "Q3", "Q4"], "")

  defp expected_kinds(same, same), do: []
  defp expected_kinds("retain ", _to), do: [:retain_removed]
  defp expected_kinds(_from, "retain "), do: [:retain_added]
  defp expected_kinds(_from, _to), do: []
end
