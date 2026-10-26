defmodule Logex.LongTimerTest do
  @moduledoc """
  PLAN M5-6: the long timers, `ton_ltime`, `tof_ltime`, `tp_ltime` and `rto_ltime`
  (`docs/organisation.md` §4.12, "Timers and counters", decision 158; `docs/naming.md`,
  `ton_ltime` to `rto_ltime`), every rule from source through `Logex.compile/2`,
  `Logex.Runtime.call/4`, `Logex.Edit`, `Logex.Configuration`, a cycle and the runner:
  each run by its kind's instruction, its `.pre` and `.acc` lint nanoseconds, its preset 0
  to 2^63-1 ns on the instruction, each millisecond of a scan adding 1,000,000 ns, so its
  resolution is a millisecond, a preset that is no whole number of them reached at the
  next and warned of; every rule of M3-2 its kind's, a frozen block's and a skipped rung's
  catch-up among them; an edit resuming it by its type's `times` member, its preset rules
  and forecast in ns, its edge memory on the block list, and a change to or from its plain
  timer refused; and the event task's warning naming it.

  The nanosecond and the lint's limits are restated here, IEC's (Ed 3 Table 10 footnote
  m, and footnote c), never read from `Logex.Declarations` or `Logex.FbType`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Diagnostic, Edit, Instance, Runner, Runtime, Scan}
  alias Logex.IO.Sim
  alias Logex.Runner.Clock.Manual

  # IEC's LTIME is a count of nanoseconds, and logex's clock counts milliseconds.
  @ns 1_000_000
  @lint_top 9_223_372_036_854_775_807
  @kinds ~w(ton tof tp rto)

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  defp messages(src) do
    {:error, diagnostics} = Logex.compile(src, name: "m")
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  defp warnings(src), do: Enum.map(c!(src).warnings, &Diagnostic.format/1)

  # Scans `program` from `state` once per `{elapsed, input}`: each scan's state.
  defp scans(program, state, steps) do
    {states, _state} =
      Enum.map_reduce(steps, state, fn {elapsed, input}, %Instance{now: now, first: first} = s ->
        {_out, s} = Runtime.call(program, s, input, %Scan{now: now + elapsed, first: first})
        {s, s}
      end)

    states
  end

  defp at(states, path), do: Enum.map(states, &get_in(&1.env, path))

  @cure """
  var_input press bool
  var_output cured bool
  var cure ton_ltime
  xic press ton cure 2592000000000000
  xic cure.dn ote cured
  """

  describe "PLAN M5-6's Done-when" do
    # 30 days is 2,592,000,000 ms, or 2,592,000,000,000,000 ns.
    test "a ton_ltime of 30 days in ns is done at exactly 30 days of scans and never before" do
      p = c!(@cure)
      day = 86_400_000
      start = scans(p, Runtime.instance(p), [{0, %{"press" => 1}}])
      hourly = scans(p, List.last(start), List.duplicate({3_600_000, %{}}, 719))
      assert Enum.uniq(at(hourly, ["cure", "dn"])) == [0]
      assert List.last(hourly).now == 719 * 3_600_000

      [short, done, later] =
        scans(p, List.last(hourly), [{3_599_999, %{}}, {1, %{}}, {day, %{}}])

      assert short.now == 30 * day - 1
      assert {short.env["cure"]["acc"], short.env["cure"]["dn"]} == {(30 * day - 1) * @ns, 0}
      assert {done.env["cure"]["acc"], done.env["cure"]["dn"]} == {30 * day * @ns, 1}
      assert {done.env["cured"], later.env["cure"]["acc"]} == {1, 30 * day * @ns}

      # A `ton` counts ms, a dint of them, so the same preset is refused there.
      assert messages(String.replace(@cure, "ton_ltime", "ton")) == [
               "line 4: `ton` takes a preset of 0 to 2147483647 ms, found `2592000000000000`"
             ]
    end

    test "a preset of 1,500,000 ns is done at the 2 ms scan, and warned of" do
      src =
        "var_input go bool\nvar_output y bool\nvar t ton_ltime\nxic go ton t 1500000\nxic t.dn ote y"

      p = c!(src)
      states = scans(p, Runtime.instance(p), [{0, %{"go" => 1}}, {1, %{}}, {1, %{}}])

      assert Enum.map(states, &{&1.now, &1.env["t"]["acc"], &1.env["t"]["dn"]}) == [
               {0, 0, 0},
               {1, 1_000_000, 0},
               {2, 1_500_000, 1}
             ]

      assert warnings(src) == [
               "line 4: warning: `ton` gives `t` a preset of 1500000 ns, which is no whole " <>
                 "number of milliseconds: a ton_ltime counts whole milliseconds, so it times " <>
                 "as the next whole millisecond, 2 ms"
             ]

      # A whole number of ms, and any preset of a timer counted in ms, is no such preset.
      assert warnings(String.replace(src, "1500000", "2000000")) == []
      assert warnings(String.replace(src, "ton_ltime", "ton")) == []
      assert warnings(String.replace(src, "1500000", "0")) == []
    end

    test "each long timer is warned of a preset between milliseconds, in its own words, and " <>
           "the next whole millisecond is the one after its preset" do
      for kind <- @kinds, {preset, next} <- [{1, 1}, {999_999, 1}, {1_000_001, 2}] do
        src =
          "var_input go bool\nvar_output y bool\nvar t #{kind}_ltime\nxic go #{kind} t #{preset}\nxic t.dn ote y"

        assert warnings(src) == [
                 "line 4: warning: `#{kind}` gives `t` a preset of #{preset} ns, which is no " <>
                   "whole number of milliseconds: #{article(kind)} #{kind}_ltime counts whole " <>
                   "milliseconds, so it times as the next whole millisecond, #{next} ms"
               ]
      end
    end

    # The unit is the instance's: the one rung means 2,000,000 ms, about 33 minutes, on a
    # `ton` and 2 ms on a `ton_ltime`, so this fails where either unit is taken for both.
    test "the one rung `ton t 2000000` is done at 2,000,000 ms with `t` a `ton`, and at 2 ms " <>
           "with `t` a `ton_ltime`" do
      rung =
        "var_input go bool\nvar_output lamp bool\nvar t TYPE\nxic go ton t 2000000\n" <>
          "xic t.dn ote lamp"

      ms = c!(String.replace(rung, "TYPE", "ton"))
      ns = c!(String.replace(rung, "TYPE", "ton_ltime"))

      lamp = fn p, steps -> at(scans(p, Runtime.instance(p), steps), ["lamp"]) end
      start = {0, %{"go" => 1}}

      assert lamp.(ms, [start, {1, %{}}, {1, %{}}, {1_999_997, %{}}, {1, %{}}]) ==
               [0, 0, 0, 0, 1]

      assert lamp.(ns, [start, {1, %{}}, {1, %{}}]) == [0, 0, 1]
    end
  end

  # Every rule of M3-2 is its kind's: a long timer scanned beside its plain timer, of the
  # preset in ns that is the plain one's in ms, over the same seeded rung, reset, elapsed
  # times and restarts, holds exactly the plain one's members, its `.pre` and `.acc` a
  # million times theirs, at every scan.
  describe "each long timer's rules of M3-2 hold for it, through call/4" do
    defp twin(kind, unit) do
      word = if unit == :ns, do: "#{kind}_ltime", else: kind

      reset =
        if kind == "rto", do: "xic rst ote t.r\n", else: ""

      """
      var_input go bool
      var_input rst bool
      var_output done bool
      var t #{word}
      xic go #{kind} t PRESET
      #{reset}xic t.dn ote done
      """
    end

    defp side_by_side(kind, seed) do
      :rand.seed(:exsss, {seed, 7, 11})
      preset = Enum.random(0..40)
      ms = c!(String.replace(twin(kind, :ms), "PRESET", "#{preset}"))
      ns = c!(String.replace(twin(kind, :ns), "PRESET", "#{preset * @ns}"))

      steps =
        for _ <- 1..120 do
          {Enum.random([0, 0, 1, 3, 7, 20]),
           %{"go" => Enum.random([0, 1, 1]), "rst" => Enum.random([0, 0, 0, 1])},
           :rand.uniform(30) == 1}
        end

      Enum.reduce(steps, {Runtime.instance(ms), Runtime.instance(ns)}, fn
        {elapsed, input, restart}, {a, b} ->
          {a, b} =
            if restart,
              do: {Runtime.restart(ms, a, :warm), Runtime.restart(ns, b, :warm)},
              else: {a, b}

          {out_a, a} = Runtime.call(ms, a, input, %Scan{now: a.now + elapsed, first: a.first})
          {out_b, b} = Runtime.call(ns, b, input, %Scan{now: b.now + elapsed, first: b.first})
          {x, y} = {a.env["t"], b.env["t"]}
          assert {y["pre"], y["acc"]} == {x["pre"] * @ns, x["acc"] * @ns}
          assert Map.drop(y, ~w(pre acc)) == Map.drop(x, ~w(pre acc))
          assert out_a == out_b
          {a, b}
      end)
    end

    test "ton, tof, tp and rto, each over seeded scans" do
      for kind <- @kinds, seed <- 1..6, do: side_by_side(kind, seed)
    end
  end

  describe "each kind's own rules, read in ns" do
    test "a tof_ltime holds `.dn` through its delay, 30 ms of ns after the fall" do
      p =
        c!(
          "var_input m bool\nvar_output f bool\nvar t tof_ltime\nxic m tof t 30000000\nxic t.dn ote f"
        )

      states =
        scans(
          p,
          Runtime.instance(p),
          [{0, %{"m" => 1}}, {10, %{"m" => 0}} | List.duplicate({10, %{}}, 4)]
        )

      assert Enum.map(states, &{&1.env["t"]["acc"], &1.env["t"]["dn"]}) == [
               {0, 1},
               {0, 1},
               {10_000_000, 1},
               {20_000_000, 1},
               {30_000_000, 0},
               {30_000_000, 0}
             ]
    end

    test "a tp_ltime's pulse lasts its preset whatever the rung, and an edge inside it " <>
           "starts nothing" do
      p =
        c!(
          "var_input a bool\nvar_output h bool\nvar t tp_ltime\nxic a tp t 25000000\nxic t.tt ote h"
        )

      levels = [0, 1, 0, 1, 0, 0, 0]
      steps = Enum.map(levels, &{10, %{"a" => &1}})
      states = scans(p, Runtime.instance(p), steps)

      assert Enum.map(states, &{&1.env["t"]["acc"], &1.env["t"]["tt"]}) == [
               {0, 0},
               {0, 1},
               {10_000_000, 1},
               {20_000_000, 1},
               {0, 0},
               {0, 0},
               {0, 0}
             ]
    end

    test "an rto_ltime adds up its ns across the rung's drops, and `r` clears it" do
      p =
        c!(
          "var_input m bool\nvar_input g bool\nvar_output y bool\nvar t rto_ltime\nxic m rto t 50000000\n" <>
            "xic g ote t.r\nxic t.dn ote y"
        )

      steps =
        [{0, %{"m" => 1}}, {20, %{}}, {10, %{"m" => 0}}, {500, %{}}, {10, %{"m" => 1}}] ++
          [{20, %{}}, {10, %{}}, {10, %{"g" => 1}}, {10, %{"g" => 0}}]

      states = scans(p, Runtime.instance(p), steps)

      assert Enum.map(states, &{&1.env["t"]["acc"], &1.env["t"]["dn"]}) == [
               {0, 0},
               {20_000_000, 0},
               {20_000_000, 0},
               {20_000_000, 0},
               {20_000_000, 0},
               {40_000_000, 0},
               {50_000_000, 1},
               {50_000_000, 1},
               {0, 0}
             ]
    end

    test "a long timer's `.acc` logic writes counts on from there in ns, a negative one from 0" do
      p =
        c!(
          "var_input go bool\nvar_input w bool\nvar_input to lint\nvar t ton_ltime\n" <>
            "xic go ton t 9000000\nxic w move to t.acc"
        )

      steps =
        [{0, %{"go" => 1}}, {1, %{"w" => 1, "to" => 500}}, {2, %{"w" => 0}}] ++
          [{0, %{"w" => 1, "to" => -7}}, {3, %{"w" => 0}}]

      assert at(scans(p, Runtime.instance(p), steps), ["t", "acc"]) ==
               [0, 500, 2_000_500, -7, 3_000_000]
    end

    test "a long timer reaches the lint's top and stays, its `.acc` never past its preset" do
      p = c!("var_input go bool\nvar t ton_ltime\nxic go ton t #{@lint_top}")
      far = div(@lint_top, @ns)

      [_, near, top, after_top] =
        scans(p, Runtime.instance(p), [{0, %{"go" => 1}}, {far, %{}}, {1, %{}}, {far, %{}}])

      assert {near.env["t"]["acc"], near.env["t"]["dn"]} == {far * @ns, 0}
      assert {top.env["t"]["acc"], top.env["t"]["dn"]} == {@lint_top, 1}
      assert after_top.env["t"]["acc"] == @lint_top
    end
  end

  describe "a long timer that does not run catches up when it next does" do
    test "inside a function block whose `cal` is false, by its path" do
      {:ok, cure} =
        Logex.compile(
          "function_block cure\nvar_input go bool\nvar_output done bool\nvar t ton_ltime\n" <>
            "xic go ton t 50000000\nxic t.dn ote done",
          name: "cure"
        )

      p =
        c!(
          "var_input run bool\nvar_input go bool\nvar_output y bool\nvar c cure\nxic run cal c go y",
          [cure]
        )

      steps =
        [{0, %{"run" => 1, "go" => 1}}, {10, %{}}, {10, %{"run" => 0}}, {500, %{}}] ++
          [{10, %{"run" => 1}}]

      assert at(scans(p, Runtime.instance(p), steps), ["c", "t", "acc"]) ==
               [0, 10_000_000, 10_000_000, 10_000_000, 50_000_000]
    end

    test "on a rung a jump skips" do
      p =
        c!(
          "var_input skip bool\nvar_input go bool\nvar_output y bool\nvar t ton_ltime\nxic skip jmp over\n" <>
            "xic go ton t 80000000\nlbl over xic t.dn ote y"
        )

      steps = [{0, %{"go" => 1}}, {10, %{}}, {10, %{"skip" => 1}}, {30, %{}}, {5, %{"skip" => 0}}]

      assert at(scans(p, Runtime.instance(p), steps), ["t", "acc"]) ==
               [0, 10_000_000, 10_000_000, 10_000_000, 55_000_000]
    end
  end

  describe "across an online edit" do
    @e "var_input go bool\nvar_input g bool\nvar_output y bool\n"

    test "an edit from a plain timer to its long timer, or back, is refused at its line" do
      for kind <- @kinds, {from, to} <- [{kind, "#{kind}_ltime"}, {"#{kind}_ltime", kind}] do
        v1 = c!(@e <> "var t #{from}\nxic go #{kind} t 5\nxic t.dn ote y")
        v2 = c!(@e <> "var t #{to}\nxic go #{kind} t 5\nxic t.dn ote y")

        assert Edit.accept(v1, v2, Runtime.instance(v1)) ==
                 {:error,
                  [
                    %Diagnostic{
                      stage: :edit,
                      line: 4,
                      message:
                        "`t` is #{article(from)} #{from} in the running program and " <>
                          "#{article(to)} #{to} in the candidate: a tag's type changes only " <>
                          "with a restart"
                    }
                  ]}
      end
    end

    # Decision 199: an edit's report keeps a member's own unit for a preset, ns, and the
    # clock's for a resume's gap, ms.
    test "a moved preset is reported and forecast in ns, a `.pre` logic moved kept" do
      v1 = c!(@e <> "var t ton_ltime\nxic go ton t 50000000\nxic t.dn ote y")
      v2 = c!(@e <> "var t ton_ltime\nxic go ton t 20000000\nxic t.dn ote y")
      [_, state] = scans(v1, Runtime.instance(v1), [{0, %{"go" => 1}}, {30, %{}}])
      assert state.env["t"]["acc"] == 30_000_000

      {:ok, edit, forecast} = Edit.accept(v1, v2, state)

      assert forecast == [
               {:dn_rises, "t", {30_000_000, 20_000_000}},
               {:preset, "t", {50_000_000, 20_000_000}}
             ]

      {_edit, tested, ^forecast} = Edit.test(edit, state)
      [later] = scans(v2, tested, [{0, %{}}])
      assert {later.env["t"]["pre"], later.env["t"]["dn"]} == {20_000_000, 1}

      moved = put_in(state.env["t"]["pre"], 7)
      assert {:ok, _edit, [{:preset_kept, "t", {7, 20_000_000}}]} = Edit.accept(v1, v2, moved)
    end

    # §4.9's Resume rule by the type's `times` member: `.en` for a `ton_ltime` and an
    # `rto_ltime`, `.tt` for a `tof_ltime` and a `tp_ltime`, its report in ms of the clock.
    test "a long timer the switch gives back resumes from the switch by its `times` member" do
      for {kind, before} <- [
            {"ton", [{0, %{"go" => 1}}, {10, %{}}]},
            {"rto", [{0, %{"go" => 1}}, {10, %{}}]},
            {"tof", [{0, %{"go" => 1}}, {10, %{"go" => 0}}]},
            {"tp", [{0, %{}}, {10, %{"go" => 1}}]}
          ] do
        v1 = c!(@e <> "var t #{kind}_ltime\nxic go #{kind} t 900000000\nxic t.dn ote y")
        v2 = c!(@e <> "var t #{kind}_ltime\nxic t.dn ote y")
        states = scans(v1, Runtime.instance(v1), before)
        state = List.last(states)
        {:ok, edit, _} = Edit.accept(v1, v2, state)
        {edit, state, _} = Edit.test(edit, state)
        state = List.last(scans(v2, state, List.duplicate({10, %{}}, 50)))
        {_edit, state, report} = Edit.untest(edit, state)
        assert {:resumed, "t", 500} in report, "#{kind}_ltime: #{inspect(report)}"
        assert state.env["t"]["last"] == state.now
        [later] = scans(v1, state, [{10, %{}}])
        held = List.last(states).env["t"]["acc"]
        assert later.env["t"]["acc"] == held + 10 * @ns, "#{kind}_ltime caught up"
      end
    end

    test "a tp_ltime's edge memory, `.en`, is on the block list as a tp's, by its path" do
      v1 = c!(@e <> "var h tp_ltime\nxic go tp h 30000000\nxic h.tt ote y")
      v2 = c!(@e <> "var h tp_ltime\nxic go xic g tp h 30000000\nxic h.tt ote y")
      [state] = scans(v1, Runtime.instance(v1), [{0, %{"go" => 0}}])
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      assert forecast == [{:ons_blocked, "h.en", 0}]
      {_edit, tested, ^forecast} = Edit.test(edit, state)
      assert tested.ons_blocked == ["h.en"]

      [blocked, low, edge] =
        scans(v2, tested, [{10, %{"go" => 1, "g" => 1}}, {10, %{"go" => 0}}, {10, %{"go" => 1}}])

      assert {blocked.env["h"]["tt"], blocked.ons_blocked} == {0, []}
      assert {low.env["h"]["tt"], edge.env["h"]["tt"]} == {0, 1}
    end
  end

  describe "the compiler" do
    test "a long timer's preset is 0 to 2^63-1 ns, in its type's words" do
      for kind <- @kinds do
        base = "var_input go bool\nvar t #{kind}_ltime\nxic go #{kind} t "
        assert %Logex.Program{} = c!(base <> "0")
        assert %Logex.Program{} = c!(base <> "#{@lint_top}")

        for bad <- [-1, @lint_top + 1] do
          assert messages(base <> "#{bad}") == [
                   "line 3: `#{kind}` takes a preset of 0 to #{@lint_top} ns for " <>
                     "#{article(kind)} #{kind}_ltime, found `#{bad}`"
                 ]
        end
      end
    end

    test "a preset from a tag is told its unit, and the move into `.pre` where it widens " <>
           "into a lint" do
      for {type, hint} <- [{"lint", true}, {"dint", true}, {"usint", true}, {"ulint", false}] do
        assert messages("var go bool\nvar sp #{type}\nvar t ton_ltime\nxic go ton t sp") == [
                 "line 4: `ton` takes its preset as a number of nanoseconds for a ton_ltime, " <>
                   "found `sp`" <>
                   if(hint,
                     do: ": to preset `t` from a tag, `move sp t.pre` on a rung above",
                     else: ""
                   )
               ]
      end

      assert %Logex.Program{} =
               c!(
                 "var go bool\nvar sp lint\nvar t ton_ltime\nxic go move sp t.pre\nxic go ton t 5"
               )

      assert messages("var go bool\nvar sp dint\nvar t ton\nxic go ton t sp") == [
               "line 4: `ton` takes its preset as a number of milliseconds, found `sp`: to " <>
                 "preset `t` from a tag, `move sp t.pre` on a rung above"
             ]

      # A lint is no ton's `.pre`, a dint of ms.
      assert [message] =
               messages(
                 "var go bool\nvar sp lint\nvar t ton\nxic go move sp t.pre\nxic go ton t 5"
               )

      assert message ==
               "line 4: `move` writes `sp`, an lint, into `t.pre`, a dint: an lint does not " <>
                 "widen into a dint, so convert it with `lint_to_dint`"
    end

    # Decision 198: a timer's slot names both its words.
    test "each instruction runs its own kind's timers, both units, and is told so" do
      assert messages(
               "var e bool\nvar f tof_ltime\nvar c ctu\nxic e ton f 1\nxic e tp c 1\nxic e rto 5 1"
             ) == [
               "line 4: `ton` runs a ton or ton_ltime, but `f` is a tof_ltime (declared on line 2)",
               "line 5: `tp` runs a tp or tp_ltime, but `c` is a ctu (declared on line 3)",
               "line 6: `rto` expects an rto or rto_ltime, found `5`"
             ]

      # One instruction of its kind runs it, as a plain timer's.
      assert messages("var e bool\nvar t ton_ltime\nxic e ton t 1\nxic e ton t 1") == [
               "line 4: `t` is already run by the `ton` on line 3: one `ton` runs a timer"
             ]

      assert messages("var e bool\nvar t tof_ltime\nxic e tof t 1 xic e") |> hd() =~
               "`xic e` follows `tof t` on its path"
    end

    test "a long timer no instruction runs is warned of in its type's words" do
      assert warnings("var_output e bool\nvar t rto_ltime\nxic t.dn ote e") == [
               "line 2: warning: `t` is an rto_ltime, but no `rto` runs it: it never times"
             ]
    end

    test "its members are named as a plain timer's, `.pre` and `.acc` lints" do
      assert [message] = messages("var e bool\nvar t ton_ltime\nxic e ton t 1\nxic t.et ote e")
      assert message =~ "`t.et` is not a member of `t`, a ton_ltime"

      assert [message] =
               messages(
                 "var e bool\nvar d dint\nvar t ton_ltime\nxic e ton t 1\nxic e move t.acc d"
               )

      assert message =~ "`t.acc`"
    end

    # M5-15's review: a lint member's bits above 31, its top bit by its sign, read and
    # written as any bit is, of a scalar timer and of an element by literal and by tag
    # subscripts; bit n restated as the integer 2^n, and bit 63 of a lint as -2^63.
    test "a bit of a `.pre` reads and writes all 64 bits, the top one its sign" do
      bit = fn
        63 -> -Integer.pow(2, 63)
        n -> Integer.pow(2, n)
      end

      for n <- [0, 31, 32, 40, 62, 63],
          t <- ["t", "a[1]", "a[i]"] do
        program =
          c!(
            "var_input v lint\nvar_input i int\nvar_input k bool\nvar_output q bool\n" <>
              "var_output o lint\nvar t ton_ltime\nvar a ton_ltime[2]\nmove v #{t}.pre\n" <>
              "xic #{t}.pre.#{n} ote q\nxic k otl #{t}.pre.#{n}\nmove #{t}.pre o"
          )

        state = Runtime.instance(program)
        scan = %Scan{now: 1, first: true}

        for {v, k, q, o} <- [
              {bit.(n), 0, 1, bit.(n)},
              {Bitwise.bxor(-1, bit.(n)), 0, 0, Bitwise.bxor(-1, bit.(n))},
              {0, 1, 0, bit.(n)},
              {0, 0, 0, 0}
            ] do
          {out, _state} = Runtime.call(program, state, %{"v" => v, "i" => 1, "k" => k}, scan)
          assert {n, t, v, k, out} == {n, t, v, k, %{"q" => q, "o" => o}}
        end
      end
    end

    test "the four words are reserved in every `.ld` file, in any case" do
      for kind <- @kinds, word <- ["#{kind}_ltime", String.upcase("#{kind}_ltime")] do
        assert messages("var #{word} bool\nxic #{word} ote #{word}") |> hd() ==
                 "line 1: `#{word}` is a type and cannot name a tag"
      end
    end
  end

  describe "the host contract" do
    test "a state whose long timer holds a value outside the lint is refused, by its path" do
      p = c!("var_input go bool\nvar t ton_ltime\nxic go ton t 5")
      state = put_in(Runtime.instance(p).env["t"]["acc"], @lint_top + 1)

      assert_raise ArgumentError,
                   ~r/`t.acc` outside its type: .*9223372036854775808.* is outside -9223372036854775808 to 9223372036854775807/,
                   fn -> Runtime.call(p, state, %{}, %Scan{now: 0, first: true}) end

      # A value no dint holds is a lint's: the plain timer refuses it, the long one takes it.
      big = put_in(Runtime.instance(p).env["t"]["acc"], 2 ** 40)
      assert {_, _} = Runtime.call(p, big, %{}, %Scan{now: 0, first: true})
    end
  end

  describe "a configuration" do
    @long """
    var_input go bool
    var a ton_ltime
    var b tof_ltime
    var c tp_ltime
    var d rto_ltime
    xic go ton a 5000000
    xic go tof b 5000000
    xic go tp c 5000000
    xic go rto d 5000000
    """

    test "the event task's warning names each long timer in its own words" do
      {:ok, long} = Logex.compile(@long, name: "long")

      text = """
      task trip single go priority 0
      var_global go bool
      program p long with trip
      p.go go
      """

      assert {:ok, config} = Configuration.compile("plant", text, %{"long" => long})
      cited = "`p` runs under the event task `trip`, and `long` runs the timer"

      assert Enum.map(config.warnings, & &1.message) == [
               "#{cited} `a` on its line 6: a ton_ltime times across the task's runs, and one " <>
                 "whose rung is true on two runs in a row counts the whole time between them",
               "#{cited} `b` on its line 7: a tof_ltime's delay ends only at one of the " <>
                 "task's runs, so what it holds on stays on until the first run after its " <>
                 "preset has passed",
               "#{cited} `c` on its line 8: a tp_ltime's pulse ends only at one of the task's " <>
                 "runs, so it lasts until the first run after its preset has passed, and it " <>
                 "starts only on an edge between two runs: a rung that is the task's trigger " <>
                 "is true at every run and never starts one",
               "#{cited} `d` on its line 9: an rto_ltime times across the task's runs, and one " <>
                 "whose rung is true on two runs in a row adds the whole time between them"
             ]
    end

    # The real resolution: the resource's clock counts whole milliseconds, so a preset of
    # 2,000,000 ns is 2 ms of cycles, and 1,500,000 ns 2 ms too.
    test "a cycle counts its elapsed milliseconds, 1,000,000 ns each" do
      {:ok, p} =
        Logex.compile(
          "var_input go bool\nvar_output y bool\nvar_output z bool\nvar t ton_ltime\n" <>
            "var u ton_ltime\nxic go ton t 2000000\nxic go ton u 1500000\nxic t.dn ote y\n" <>
            "xic u.dn ote z",
          name: "p"
        )

      text =
        "task fast interval 1 priority 1\nvar_global go bool at card.i.0\n" <>
          "program m p with fast\nm.go go\n"

      {:ok, config} = Configuration.compile("plant", text, %{"p" => p})

      {seen, _rt} =
        Enum.map_reduce([0, 1, 1, 1], Runtime.start(config), fn elapsed, rt ->
          {rt, _out, _events} = Runtime.cycle(rt, elapsed, %{"go" => 1})
          {{Runtime.get!(rt, "m.t.acc"), Runtime.get!(rt, "m.y"), Runtime.get!(rt, "m.z")}, rt}
        end)

      assert seen == [{0, 0, 0}, {1_000_000, 0, 0}, {2_000_000, 1, 1}, {2_000_000, 1, 1}]
    end

    test "through the runner on its clock of milliseconds, a preset of 2,000,000 ns is 2 ms" do
      {:ok, p} =
        Logex.compile(
          "var_input go bool\nvar_output y bool\nvar t ton_ltime\nxic go ton t 2000000\n" <>
            "xic t.dn ote y",
          name: "p"
        )

      text =
        "task fast interval 1 priority 1\nvar_global go bool at card.i.0\n" <>
          "var_global lamp bool at card.q.0\nprogram m p with fast\nm.go go\nm.y lamp\n"

      {:ok, config} = Configuration.compile("plant", text, %{"p" => p})
      {:ok, clock} = Manual.start_link()
      {:ok, sim} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"card" => {Sim, sim: sim}},
          clock: {Manual, clock}
        )

      Sim.set(sim, [0], 1)
      # The device reads it at its next poll, 10 ms on.
      Manual.advance(clock, 10)
      timing = Runner.get!(runner, "m.t.acc")

      lit =
        for _ <- 1..3,
            do:
              Manual.advance(clock, 1) &&
                {Runner.get!(runner, "m.t.acc"), Runner.get!(runner, "lamp")}

      Runner.stop(runner)

      # Each round adds the milliseconds since the last, a million ns each, and the lamp
      # lights 2 ms after timing starts.
      assert [{a1, 0}, {a2, 1}, {a2, 1}] = lit
      assert {a1 - timing, a2 - timing} == {1_000_000, 2_000_000}
    end
  end

  describe "each timer's unit, carried in the compiled program (decision 197)" do
    @mixed """
    var_input go bool
    var_output y bool
    var cure ton_ltime
    var t ton
    var f tof
    xic go ton cure 30000000
    xic go ton t 30
    xic go tof f 5
    xic cure.dn ote y
    """

    test "the compiler settles each long timer's unit by its name, and none for a plain " <>
           "routine" do
      assert c!(@mixed).units == %{"cure" => @ns}
      assert c!("var_input go bool\nvar t ton\nxic go ton t 5").units == nil
      assert c!("var_input go bool\nvar c ctu_lint\nxic go ctu c 5").units == nil

      for kind <- @kinds do
        assert c!("var_input go bool\nvar t #{kind}_ltime\nxic go #{kind} t 5").units ==
                 %{"t" => @ns}
      end

      assert Logex.Program.units(c!(@mixed).tags) == %{"cure" => @ns}
    end

    test "a block's body holds its own, and the program that holds the block none" do
      {:ok, cure} =
        Logex.compile(
          "function_block cure\nvar_input go bool\nvar_output done bool\nvar t ton_ltime\n" <>
            "xic go ton t 50000000\nxic t.dn ote done",
          name: "cure"
        )

      assert cure.body.units == %{"t" => @ns}
      p = c!("var_input go bool\nvar_output y bool\nvar c cure\ncal c go y", [cure])
      assert p.units == nil
      assert p.blocks["cure"].body.units == %{"t" => @ns}
      assert Logex.Compiler.lowered?(cure.body)
      refute Logex.Compiler.lowered?(%{cure.body | units: nil})
      refute Logex.Compiler.lowered?(%{cure.body | units: %{"t" => 1}})
    end

    test "a plain timer beside a long one counts its ms, and the long one its ns" do
      p = c!(@mixed)
      steps = [{0, %{"go" => 1}}, {10, %{}}, {20, %{}}, {5, %{"go" => 0}}, {3, %{}}]
      states = scans(p, Runtime.instance(p), steps)
      assert at(states, ["cure", "acc"]) == [0, 10 * @ns, 30 * @ns, 0, 0]
      assert at(states, ["t", "acc"]) == [0, 10, 30, 0, 0]
      assert at(states, ["f", "acc"]) == [0, 0, 0, 0, 3]
      assert at(states, ["f", "dn"]) == [1, 1, 1, 1, 1]
    end

    @told ": `m` was edited by hand after it compiled"

    test "a program whose units its tags do not give is refused where it is handed in, a " <>
           "line each in name order" do
      p = c!(@mixed)
      s = Runtime.instance(p)

      for {units, lines} <- [
            {nil,
             [
               "`m`'s units give `cure` no unit, where a ton_ltime adds 1000000 to its `acc` " <>
                 "each millisecond"
             ]},
            {%{"cure" => 5},
             [
               "`m`'s units give `cure` 5 a millisecond, where a ton_ltime adds 1000000 to " <>
                 "its `acc` each millisecond"
             ]},
            {%{"cure" => @ns, "t" => @ns, "go" => 1, "x" => @ns},
             [
               "`m`'s units give `go` 1 a millisecond, where a bool keeps no time",
               "`m`'s units give `t` 1000000 a millisecond, where a ton adds 1 to its `acc` " <>
                 "each millisecond, which takes no unit",
               "`m`'s units give `x` 1000000 a millisecond, where `m` declares no such tag"
             ]},
            {:junk,
             [
               "`m`'s units are neither nil nor a map of timer names to units, got: :junk"
             ]}
          ] do
        edited = %{p | units: units}
        message = Enum.map_join(lines, "\n", &(&1 <> @told))
        assert_raise ArgumentError, message, fn -> Runtime.instance(edited) end
        assert_raise ArgumentError, message, fn -> Edit.accept(edited, p, s) end
        assert_raise ArgumentError, message, fn -> Edit.accept(p, edited, s) end

        assert_raise ArgumentError, message, fn ->
          Configuration.new!(
            name: "plant",
            programs: [edited],
            instances: [%Configuration.Instance{name: "m1", type: "m"}],
            connections: [%Configuration.Connection{instance: "m1", member: "go", to: 0}]
          )
        end
      end

      # An empty table is the routine of plain timers nil says it is.
      plain = c!("var_input go bool\nvar t ton\nxic go ton t 5")
      assert %Instance{} = Runtime.instance(%{plain | units: %{}})
    end

    test "a body's units, before its rungs, a line after the program's" do
      {:ok, cure} =
        Logex.compile(
          "function_block cure\nvar_input go bool\nvar_output done bool\nvar t ton_ltime\n" <>
            "xic go ton t 50000000\nxic t.dn ote done",
          name: "cure"
        )

      p = c!("var_input go bool\nvar_output y bool\nvar c cure\ncal c go y", [cure])
      held = p.blocks["cure"]

      edited = %{
        p
        | units: %{"c" => 1},
          blocks: %{"cure" => %{held | body: %{held.body | units: nil}}}
      }

      assert_raise ArgumentError,
                   "`m`'s units give `c` 1 a millisecond, where an instance of `cure` keeps no " <>
                     "time#{@told}\n`cure`'s body's units give `t` no unit, where a ton_ltime " <>
                     "adds 1000000 to its `acc` each millisecond#{@told}",
                   fn -> Runtime.instance(edited) end
    end

    test "one swapped in by hand after its check counts as its units say, and a scan that " <>
           "reaches a unit that is no positive whole number raises there" do
      p = c!(@mixed)
      s = Runtime.instance(p)
      scan = %Scan{now: 0, first: true}

      # Trusted: no units, so the long timer counts as a plain one.
      {_, s1} = Runtime.call(%{p | units: nil}, s, %{"go" => 1}, scan)
      {_, s2} = Runtime.call(%{p | units: nil}, s1, %{}, %Scan{now: 7, first: false})
      assert s2.env["cure"]["acc"] == 7

      for {units, told} <- [
            {%{"cure" => 0},
             "times `cure` in a unit of 0, which is no positive whole number a " <>
               "millisecond"},
            {%{"cure" => "ns"},
             ~s|times `cure` in a unit of "ns", which is no positive whole | <>
               "number a millisecond"},
            {:junk, "reads the unit of `cure` from units that are no map, got: :junk"}
          ] do
        assert_raise ArgumentError,
                     "a scan's `ton` on line 6 #{told}: the program was edited by hand after " <>
                       "it was handed in and checked",
                     fn -> Runtime.call(%{p | units: units}, s, %{"go" => 1}, scan) end
      end

      # A rung that does not reach the timer runs on.
      assert {_, _} = Runtime.call(%{p | units: %{"cure" => 0}}, s, %{"go" => 0}, scan)

      # Every clause that reads a clock: a `tof`'s de-energised run, both of a `tp`'s and of
      # an `rto`'s.
      for {kind, go} <- [{"tof", 0}, {"tp", 1}, {"tp", 0}, {"rto", 1}, {"rto", 0}] do
        q = c!("var_input go bool\nvar t #{kind}_ltime\nxic go #{kind} t 5000000")

        assert_raise ArgumentError,
                     ~r/^a scan's `#{kind}` on line 3 times `t` in a unit of 0/,
                     fn ->
                       Runtime.call(
                         %{q | units: %{"t" => 0}},
                         Runtime.instance(q),
                         %{"go" => go},
                         scan
                       )
                     end
      end
    end

    test "a scan's units are the runtime's: a host leaves them out" do
      p = c!(@mixed)

      assert_raise ArgumentError,
                   "scan.units is the runtime's, taken from the program: a host leaves it out, " <>
                     "got: %{}",
                   fn ->
                     Runtime.call(p, Runtime.instance(p), %{}, %Scan{
                       now: 0,
                       first: true,
                       units: %{}
                     })
                   end
    end
  end

  describe "a literal taken beside a long timer's time (decision 196)" do
    @beside "var_input go bool\nvar_output y bool\nvar cure ton_ltime\nvar x lint\n" <>
              "xic go ton cure 30000000\n"

    # The warnings on the line under test, the declarations' own aside.
    defp beside(rungs),
      do: Enum.filter(warnings(@beside <> rungs), &String.starts_with?(&1, "line 6:"))

    @ns_told "is a ton_ltime's time in nanoseconds"

    test "each instruction that takes a literal as a time warns of one that is no whole ms" do
      assert beside("ge cure.acc 3000 ote y") == [
               "line 6: warning: `ge` compares `cure.acc` with `3000`, where `cure.acc` " <>
                 "#{@ns_told}: 3000 ns is no whole number of milliseconds, and a ton_ltime " <>
                 "counts whole milliseconds"
             ]

      assert beside("lt 2000500 cure.acc ote y") == [
               "line 6: warning: `lt` compares `2000500` with `cure.acc`, where `cure.acc` " <>
                 "#{@ns_told}: 2000500 ns is no whole number of milliseconds, and a ton_ltime " <>
                 "counts whole milliseconds"
             ]

      assert beside("move 1500000 cure.pre") == [
               "line 6: warning: `move` writes `1500000` into `cure.pre`, where `cure.pre` " <>
                 "#{@ns_told}: 1500000 ns is no whole number of milliseconds, and a ton_ltime " <>
                 "counts whole milliseconds"
             ]

      assert beside("add cure.acc 500 cure.acc") == [
               "line 6: warning: `add` adds `cure.acc` and `500` into `cure.acc`, where " <>
                 "`cure.acc` #{@ns_told}: 500 ns is no whole number of milliseconds, and a " <>
                 "ton_ltime counts whole milliseconds"
             ]

      assert beside("sub cure.pre -7 cure.pre") == [
               "line 6: warning: `sub` takes `-7` from `cure.pre` into `cure.pre`, where " <>
                 "`cure.pre` #{@ns_told}: -7 ns is no whole number of milliseconds, and a " <>
                 "ton_ltime counts whole milliseconds"
             ]

      # A tag's sum written into the member: its literal is a time too.
      assert [_] = beside("add x 1 cure.pre")

      # A conversion writes it, and is warned of its literal too (decision 178).
      assert beside("dint_to_lint 3 cure.pre") == [
               "line 6: warning: `dint_to_lint` reads a literal, `3`: its result never changes",
               "line 6: warning: `dint_to_lint` writes `3` into `cure.pre`, where `cure.pre` " <>
                 "#{@ns_told}: 3 ns is no whole number of milliseconds, and a ton_ltime counts " <>
                 "whole milliseconds"
             ]

      for op <- ~w(eq ne lt gt le ge) do
        assert [warning] = beside("#{op} cure.acc 1 ote y")
        assert warning =~ "`#{op}` compares `cure.acc` with `1`, where"
      end
    end

    test "a whole number of ms, a factor, a divisor, a negation and a plain timer are not " <>
           "looked at" do
      for rung <- [
            "ge cure.acc 3000000 ote y",
            "move -2000000 cure.pre",
            "add cure.acc 0 cure.acc",
            "mul cure.acc 3 x",
            "div cure.acc 7 x",
            "mod cure.acc 7 x",
            "ge x 3000 ote y"
          ] do
        assert beside(rung) == [], rung
      end

      assert warnings(
               "var_input go bool\nvar_output y bool\nvar t ton\nxic go ton t 30\n" <>
                 "ge t.acc 3 ote y\nmove 1 t.pre"
             ) == []
    end

    test "each long timer's own word, and one warning a literal" do
      for kind <- @kinds do
        [warning] =
          warnings(
            "var_input go bool\nvar_output y bool\nvar t #{kind}_ltime\n" <>
              "xic go #{kind} t 30000000\nge t.acc 3 ote y"
          )

        assert warning =~ "where `t.acc` is #{article(kind)} #{kind}_ltime's time in nanoseconds"
        assert warning =~ "and #{article(kind)} #{kind}_ltime counts whole milliseconds"
      end

      assert length(beside("add cure.acc 5 cure.pre")) == 1
      assert length(beside("lt 3 cure.acc ote y")) == 1
    end

    # Decision 196: the first long timer's member among the operands is the one named, the
    # instruction's own order, whichever side it is on.
    test "of two long timers' members, the first among the operands is named" do
      text =
        "var_input go bool\nvar_output y bool\nvar cure ton_ltime\nvar c2 tof_ltime\n" <>
          "xic go ton cure 30000000\nxic go tof c2 30000000\n"

      on = fn rung ->
        Enum.filter(warnings(text <> rung), &String.starts_with?(&1, "line 7:"))
      end

      assert on.("add c2.acc 5 cure.pre") == [
               "line 7: warning: `add` adds `c2.acc` and `5` into `cure.pre`, where `c2.acc` " <>
                 "is a tof_ltime's time in nanoseconds: 5 ns is no whole number of " <>
                 "milliseconds, and a tof_ltime counts whole milliseconds"
             ]

      assert on.("add cure.acc 5 c2.pre") == [
               "line 7: warning: `add` adds `cure.acc` and `5` into `c2.pre`, where " <>
                 "`cure.acc` #{@ns_told}: 5 ns is no whole number of milliseconds, and a " <>
                 "ton_ltime counts whole milliseconds"
             ]

      assert [warning] = on.("lt c2.acc cure.acc ote y") ++ on.("ge 3 c2.acc ote y")
      assert warning =~ "where `c2.acc` is a tof_ltime's time"
    end
  end

  describe "growth" do
    # A long timer's unit is its type's, read from its rules on each run: a scan of 400
    # long timers costs about a scan of 400 plain ones, and 4x the timers about 4x.
    test "a long timer's scan costs about a plain timer's, linear in the timers" do
      cost = fn n, word ->
        text =
          "var_input e bool\n" <>
            Enum.map_join(1..n, "\n", &"var t#{&1} #{word}") <>
            "\n" <> Enum.map_join(1..n, "\n", &"xic e ton t#{&1} 5000000")

        {:ok, p} = Logex.compile(text, name: "p")
        state = Runtime.put_inputs(p, Runtime.instance(p), %{"e" => 1})
        {_, state} = Runtime.scan(p, state, 1)

        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            Runtime.scan(p, state, 1)
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      ratio = cost.(400, "ton_ltime") / cost.(100, "ton_ltime")
      assert ratio < 4.8, "4x the timers took #{Float.round(ratio, 2)}x to scan"
      long = cost.(400, "ton_ltime") / cost.(400, "ton")
      assert long < 1.2, "a long timer scanned in #{Float.round(long, 2)}x a plain one's"
    end

    # Decision 197: a plain timer's run in a routine of plain timers, whose `units` are nil,
    # pays nothing for its unit. Its energised run, the one that reads its clock, costs
    # exactly 19 reductions more than its de-energised one, which reads none, with no
    # collection, as before long timers (`6a15701`), where a look-up of each timer's tag
    # cost about 3 more (M5-6's review), and a walk of its type's rules about 8 (M5-6).
    test "a plain timer's energised run costs what it did before long timers" do
      cost = fn e ->
        text =
          "var_input e bool\n" <>
            Enum.map_join(1..400, "\n", &"var t#{&1} ton") <>
            "\n" <> Enum.map_join(1..400, "\n", &"xic e ton t#{&1} 5000")

        {:ok, p} = Logex.compile(text, name: "p")
        state = Runtime.put_inputs(p, Runtime.instance(p), %{"e" => 1})
        {_, state} = Runtime.scan(p, state, 1)
        state = Runtime.put_inputs(p, state, %{"e" => e})
        collected_nothing(fn -> Runtime.scan(p, state, 1) end)
      end

      clock = (cost.(1) - cost.(0)) / 400
      assert clock <= 19, "a plain timer's clock cost #{Float.round(clock, 1)} reductions a run"
    end
  end

  # The reductions `fun` takes in a process of its own whose heap is large enough that the
  # garbage collector, whose work the reductions count, never runs: the same count on every
  # run, so a bound may be tight.
  defp collected_nothing(fun) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 4_000_000]
      )

    assert_receive {:reductions, n}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    n
  end

  describe "growth, decision 197" do
    # A routine of plain timers has no units, nil, and each of its timers' runs matches that
    # in its clause's head, paying no look-up; the same program handed an empty table, which
    # a routine holding a long timer has, pays the look-up on every run that reads a clock,
    # 2 reductions a run with no collection. So each clause that reads a clock, energised or not, is
    # seen to take the plain path.
    test "a plain routine's timers pay nothing for their units, each clause that reads a " <>
           "clock" do
      for {kind, go} <- [{"ton", 1}, {"tof", 0}, {"tp", 1}, {"tp", 0}, {"rto", 1}, {"rto", 0}] do
        text =
          "var_input e bool\n" <>
            Enum.map_join(1..400, "\n", &"var t#{&1} #{kind}") <>
            "\n" <> Enum.map_join(1..400, "\n", &"xic e #{kind} t#{&1} 5000")

        {:ok, p} = Logex.compile(text, name: "p")
        assert p.units == nil
        state = Runtime.put_inputs(p, Runtime.instance(p), %{"e" => 1})
        {_, state} = Runtime.scan(p, state, 1)
        state = Runtime.put_inputs(p, state, %{"e" => go})

        cost = fn program -> collected_nothing(fn -> Runtime.scan(program, state, 1) end) end

        saved = (cost.(%{p | units: %{}}) - cost.(p)) / 400
        assert saved >= 2, "#{kind} at #{go} saved #{Float.round(saved, 1)} reductions a run"
      end
    end
  end

  defp article("rto" <> _), do: "an"
  defp article(_kind), do: "a"
end
