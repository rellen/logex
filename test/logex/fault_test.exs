defmodule Logex.FaultTest do
  @moduledoc """
  M3-3: the minor fault a zero divisor raises, reported to the host (docs/organisation.md
  decisions 78 and 99), `severity: :minor` since M5-9 (decisions 153 and 160): in a lone instance's `state.faults` after `Logex.Runtime.call/4`,
  `scan/2` and `scan/3`, and in a resource's events, `{:fault, task, instance, fault}`, each
  just after its scan's `{:ran, ...}`. Each rule pinned from source, a test that fails when
  the rule alone is reverted; the rest of a `div` or a `mod` is `arithmetic_test.exs`'s.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Fault, Instance, Runtime, Scan}
  alias Logex.Configuration.{Connection, Global}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "rate", types: types)
    program
  end

  # Boxes per minute, the minutes 0 just after start-up (decision 78's picture).
  @rate """
  var_input boxes dint
  var_input minutes dint
  var_output per_minute dint
  var_output rate_ok bool
  div boxes minutes per_minute ote rate_ok
  """

  defp scans(program, inputs, state \\ nil) do
    state = state || Runtime.instance(program)

    Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
      {outputs, state} = Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
      {{outputs, state.faults}, state}
    end)
  end

  defp fault(instruction, line, path \\ nil, file \\ nil),
    do: %Fault{
      severity: :minor,
      kind: :divide_by_zero,
      instruction: instruction,
      path: path,
      file: file,
      line: line
    }

  describe "a lone instance's faults, after call/4" do
    test "a zero divisor is one fault of the scan that met it, and the next scan's are its own" do
      p = c!(@rate)

      {seen, _state} =
        scans(p, [
          %{"boxes" => 120, "minutes" => 0},
          %{"minutes" => 0},
          %{"minutes" => 2},
          %{"minutes" => 0}
        ])

      assert seen == [
               {%{"per_minute" => 0, "rate_ok" => 0}, [fault(:div, 5)]},
               {%{"per_minute" => 0, "rate_ok" => 0}, [fault(:div, 5)]},
               {%{"per_minute" => 60, "rate_ok" => 1}, []},
               {%{"per_minute" => 0, "rate_ok" => 0}, [fault(:div, 5)]}
             ]
    end

    # M5-9 (decisions 153 and 160): a zero divisor is a minor fault, which reads nothing out
    # of range, and the plant runs on through it.
    test "a zero divisor's fault is minor, and reads nothing" do
      p = c!(@rate)
      assert {[{_, [fault]}], _} = scans(p, [%{"boxes" => 120, "minutes" => 0}])
      assert %Fault{severity: :minor, kind: :divide_by_zero, read: nil} = fault
    end

    # M5-9 (decisions 153 and 160): a bit whose number a tag holds, out of its word's bits,
    # is a major fault, with the number read.
    test "a bit out of range's fault is major, and reads its number" do
      p = c!("var_input w word\nvar_input n int\nvar_output q bool\nxic w.[n] ote q")

      assert {[{_, faults}], _} = scans(p, [%{"w" => 1, "n" => 16}])
      assert [%Fault{severity: :major, kind: :bit_out_of_range, read: 16, line: 4}] = faults
    end

    test "a new instance has none, and a scan with no zero divisor gives none" do
      p = c!(@rate)
      assert %Instance{faults: []} = Runtime.instance(p)
      assert {[{_, []}], _} = scans(p, [%{"boxes" => 1, "minutes" => 1}])
    end

    test "every fault of one scan, in the order they happened, `mod`'s among them" do
      p =
        c!("""
        var_input a dint
        var_input z dint
        var_output q dint
        var_output r dint
        div a z q
        ( mod a z r | div a 1 q )
        mod z z r div z z q
        """)

      # The `div` after a faulted `mod` on its rung gets no power, so divides nothing.
      assert {[{_, faults}], _} = scans(p, [%{"a" => 7, "z" => 0}])
      assert faults == [fault(:div, 5), fault(:mod, 6), fault(:mod, 7)]
    end

    test "a de-energised `div` divides nothing, and meets no fault" do
      p =
        c!(
          "var_input go bool\nvar_input z dint\nvar_output q dint\nxic go div 5 z q",
          []
        )

      assert {[{_, []}, {_, [_]}], _} = scans(p, [%{"go" => 0, "z" => 0}, %{"go" => 1}])
    end

    test "scan/2 and scan/3 give the scan's faults in its state too" do
      p = c!(@rate)
      state = Runtime.put_inputs(p, Runtime.instance(p), %{"boxes" => 5, "minutes" => 0})
      assert {_, %Instance{faults: [%Fault{line: 5}]} = state} = Runtime.scan(p, state)
      state = Runtime.put_inputs(p, state, %{"minutes" => 5})
      assert {%{"per_minute" => 1}, %Instance{faults: []}} = Runtime.scan(p, state, 10)
    end

    # Neither is a scan, so the last scan's faults stay, as `switched` does.
    test "put_inputs/3 and restart/3 keep the last scan's faults" do
      p = c!(@rate)
      {_, state} = scans(p, [%{"boxes" => 5, "minutes" => 0}])
      assert [%Fault{}] = state.faults
      assert Runtime.put_inputs(p, state, %{"minutes" => 1}).faults == state.faults
      assert Runtime.restart(p, state, :cold).faults == state.faults
      assert Runtime.restart(p, state, :warm).faults == state.faults
    end

    test "a program read from its file names it, as a diagnostic does", %{} do
      dir = Path.join(System.tmp_dir!(), "logex_fault_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "rate.ld")
      File.write!(path, "// boxes per minute\n" <> @rate)
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, p} = Logex.compile_file(path)
      assert {[{_, [fault]}], _} = scans(p, [%{"boxes" => 5, "minutes" => 0}])
      assert fault == fault(:div, 6, nil, path)
    end
  end

  describe "a fault inside a function block" do
    @inner """
    function_block inner
    var_input n dint
    var_input d dint
    var_output q dint
    mod n d q
    """

    @outer """
    function_block outer
    var_input n dint
    var_input d dint
    var_output q dint
    var i1 inner
    div n d q
    cal i1 n d q
    """

    defp blocks do
      {:ok, inner} = Logex.compile(@inner, name: "inner")
      {:ok, outer} = Logex.compile(@outer, name: "outer", types: [inner])
      {inner, outer}
    end

    test "is named by the block instance's path, at its body's line" do
      {inner, outer} = blocks()

      p =
        c!(
          "var_input go bool\nvar_input d dint\nvar_output q dint\nvar s1 outer\n" <>
            "var s2 inner\nxic go cal s1 7 d q\nxic go cal s2 7 d q\ndiv 7 d q",
          [outer, inner]
        )

      assert {[{_, faults}], _} = scans(p, [%{"go" => 1, "d" => 0}])

      assert faults == [
               fault(:div, 6, "s1"),
               fault(:mod, 5, "s1.i1"),
               fault(:mod, 5, "s2"),
               fault(:div, 8)
             ]

      # No state keeps a body's record, so the next scan's faults are its own; and a body
      # that does not run meets nothing.
      {seen, state} = scans(p, [%{"go" => 1, "d" => 0}, %{"d" => 1}, %{"go" => 0, "d" => 0}])
      assert [{_, [_, _, _, _]}, {_, []}, {_, [%Fault{path: nil}]}] = seen
      refute Map.has_key?(state.env["s1"], :faults)
      refute Map.has_key?(state.env["s1"]["i1"], :faults)
      refute Map.has_key?(state.env["s2"], :faults)
      refute Map.has_key?(state.env, :faults)
    end

    test "in the block's own file, where the loader read it from" do
      dir = Path.join(System.tmp_dir!(), "logex_fault_fb_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      File.write!(Path.join(dir, "inner.ld"), @inner)
      File.write!(Path.join(dir, "outer.ld"), @outer)

      File.write!(
        Path.join(dir, "line.ld"),
        "var_input d dint\nvar_output q dint\nvar s1 outer\ncal s1 7 d q\nmod 7 d q"
      )

      assert {:ok, p} = Logex.compile_file(Path.join(dir, "line.ld"))
      assert {[{_, faults}], _} = scans(p, [%{"d" => 0}])

      assert faults == [
               fault(:div, 6, "s1", Path.join(dir, "outer.ld")),
               fault(:mod, 5, "s1.i1", Path.join(dir, "inner.ld")),
               fault(:mod, 5, nil, Path.join(dir, "line.ld"))
             ]
    end
  end

  describe "a resource's faults, events of its cycle" do
    defp plant(rate) do
      Configuration.new!(
        name: "plant",
        programs: [rate],
        tasks: [%Configuration.Task{name: "fast", interval: 10, priority: 1}],
        globals: [
          %Global{name: "minutes", type: :dint, at: "panel.i.0"},
          %Global{name: "lamp", type: :bool, at: "panel.q.0"}
        ],
        instances: [
          %Configuration.Instance{name: "r1", type: "rate", task: "fast"},
          %Configuration.Instance{name: "r2", type: "rate"}
        ],
        connections: [
          %Connection{instance: "r1", member: "boxes", to: 120},
          %Connection{instance: "r1", member: "minutes", to: "minutes"},
          %Connection{instance: "r1", member: "rate_ok", to: "lamp"},
          %Connection{instance: "r2", member: "boxes", to: 0},
          %Connection{instance: "r2", member: "minutes", to: "minutes"}
        ]
      )
    end

    test "each fault is an event just after its scan's {:ran, ...}, and the plant runs on" do
      rt = Runtime.start(plant(c!(@rate)))
      {rt, outputs, events} = Runtime.cycle(rt, 0, %{"minutes" => 0})

      assert outputs == %{"lamp" => 0}

      assert events == [
               {:ran, "fast", "r1", 0},
               {:fault, "fast", "r1", fault(:div, 5)},
               {:ran, :none, "r2", 0},
               {:fault, :none, "r2", fault(:div, 5)}
             ]

      {rt, outputs, events} = Runtime.cycle(rt, 10, %{"minutes" => 4})
      assert outputs == %{"lamp" => 1}
      assert events == [{:ran, "fast", "r1", 10}, {:ran, :none, "r2", 10}]
      assert Runtime.get!(rt, "r1.per_minute") == 30
    end

    # The events are the record: no instance's state in the resource keeps a fault between
    # cycles, as none keeps a var_external (decision 49), looked at inside.
    test "no instance's state in the resource keeps a fault between cycles" do
      rt = Runtime.start(plant(c!(@rate)))
      {rt, _, _} = Runtime.cycle(rt, 0, %{"minutes" => 0})
      %Runtime{instances: instances} = rt
      assert Enum.all?(Map.values(instances), &(&1.faults == []))
      {_rt, _, events} = Runtime.cycle(Runtime.restart(rt, :cold), 0, %{})

      assert [{:ran, _, "r1", 0}, {:fault, _, "r1", _}, {:ran, _, "r2", 0}, {:fault, _, "r2", _}] =
               events
    end
  end

  describe "across an edit" do
    # No switch is a scan, so it keeps the last scan's faults, as it keeps what the scan
    # wrote; the next scan, the candidate's, replaces them.
    test "a switch keeps the last scan's faults, and the candidate's scan replaces them" do
      p = c!(@rate)

      candidate =
        c!(
          String.replace(
            @rate,
            "var_output rate_ok bool\n",
            "var_output rate_ok bool\nvar_output shown bool\n"
          ) <>
            "xic rate_ok ote shown\n"
        )

      {_, state} = scans(p, [%{"boxes" => 5, "minutes" => 0}])
      assert [%Fault{line: 5}] = faults = state.faults
      {:ok, edit, _forecast} = Logex.Edit.accept(p, candidate, state)
      {_edit, state, _report} = Logex.Edit.test(edit, state)
      assert state.faults == faults
      assert {_, %Instance{faults: [%Fault{line: 6}]}} = Runtime.scan(candidate, state, 10)
    end
  end

  # A scan records each fault once, newest first, and a routine places its body's once, so
  # its cost grows with the faults it meets, as it does with the rungs it runs.
  describe "growth" do
    defp flat(n) do
      c!(
        "var_input z dint\nvar_output q dint\n" <>
          Enum.map_join(1..n, "\n", fn _ -> "div 7 z q" end)
      )
    end

    # The faults two blocks down, each placed once a level.
    defp deep(n) do
      {:ok, inner} =
        Logex.compile(
          "function_block inner\nvar_input z dint\nvar_output q dint\n" <>
            Enum.map_join(1..n, "\n", fn _ -> "div 7 z q" end),
          name: "inner"
        )

      {:ok, mid} =
        Logex.compile(
          "function_block mid\nvar_input z dint\nvar_output q dint\nvar i inner\ncal i z q",
          name: "mid",
          types: [inner]
        )

      c!("var_input z dint\nvar_output q dint\nvar m mid\ncal m z q", [mid, inner])
    end

    # The least of three counts of a scan's reductions, since a busy VM can raise one.
    defp reductions_to_scan(p) do
      state = Runtime.instance(p)

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)

          {_, %Instance{faults: [_ | _]}} =
            Runtime.call(p, state, %{"z" => 0}, %Scan{now: 0, first: true})

          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    # 4x the faults took at most 3.98x on the program's own rungs and 3.88x two blocks
    # down, over 32 runs on Elixir 1.20.4; the bounds, 4.77 and 4.66, a fifth above the
    # highest.
    test "a scan's cost grows with the faults it meets, on the program's rungs" do
      ratio = reductions_to_scan(flat(400)) / reductions_to_scan(flat(100))
      assert ratio < 4.77, "4x the faults took #{Float.round(ratio, 2)}x the reductions"
    end

    test "a scan's cost grows with the faults it meets, two blocks down" do
      ratio = reductions_to_scan(deep(400)) / reductions_to_scan(deep(100))
      assert ratio < 4.66, "4x the faults took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  # A record of a scan's own is kept under an atom no tag can be, and taken out before the
  # scan ends, so no state holds one. A host's env holding the record's key is refused, as a
  # fault under it would be one no divisor met; a block instance's map holding it, a value
  # no scan checks, has it dropped, so its body's faults are its own (M3-5's review).
  describe "a hand-built env" do
    test "holding the record's key is refused, whatever it holds there" do
      p = c!(@rate)

      for junk <- [:x, [div: 3], %{}, [fault(:div, 99)]] do
        state = %Instance{
          type: "rate",
          env: %{"boxes" => 1, "minutes" => 0, faults: junk},
          now: 0,
          first: true
        }

        assert_raise ArgumentError,
                     "state.env holds :faults, the runtime's own key for a record a scan " <>
                       "keeps and takes out before it ends: an env is keyed by tag names",
                     fn -> Runtime.call(p, state, %{}, %Scan{now: 0, first: true}) end
      end
    end

    test "whose block instance holds it under the key, gives the body's faults alone" do
      {:ok, block} =
        Logex.compile(
          "function_block per\nvar_input n dint\nvar_input d dint\nvar_output q dint\n" <>
            "div n d q",
          name: "per"
        )

      p =
        c!(
          "var_input go bool\nvar_input d dint\nvar_output q dint\nvar s1 per\n" <>
            "xic go cal s1 7 d q",
          [block]
        )

      fresh = Runtime.instance(p)

      for junk <- [:x, [div: 3], %{}, [fault(:div, 99)]] do
        state = %{fresh | env: Map.update!(fresh.env, "s1", &Map.put(&1, :faults, junk))}

        {_, state} =
          Runtime.call(p, state, %{"go" => 1, "d" => 0}, %Scan{now: 0, first: true})

        assert state.faults == [fault(:div, 5, "s1")]
        assert Enum.all?(Map.keys(state.env["s1"]), &is_binary/1)

        {_, state} =
          Runtime.call(
            p,
            %{state | env: Map.update!(state.env, "s1", &Map.put(&1, :faults, junk))},
            %{"d" => 7},
            %Scan{now: 10, first: false}
          )

        assert state.faults == []
      end
    end
  end

  describe "the host's mistakes" do
    test "state.faults must be a list of faults, as a scan gives it" do
      p = c!(@rate)
      state = Runtime.instance(p)

      for junk <- [nil, :x, [nil], [%{kind: :divide_by_zero}], [fault(:div, 5) | :tail]] do
        assert_raise ArgumentError,
                     "state.faults must be a list of %Logex.Fault{}, got: #{inspect(junk)}",
                     fn ->
                       Runtime.call(p, %{state | faults: junk}, %{}, %Scan{now: 0, first: true})
                     end
      end

      assert {_, %Instance{faults: []}} =
               Runtime.call(p, %{state | faults: [fault(:mod, 99)]}, %{"minutes" => 1}, %Scan{
                 now: 0,
                 first: true
               })
    end
  end
end
