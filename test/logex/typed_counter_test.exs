defmodule Logex.TypedCounterTest do
  @moduledoc """
  PLAN M5-5: IEC's typed counters and the dint's three words (`docs/organisation.md`
  §4.12, "Timers and counters", decisions 158 and 163; `docs/naming.md`, `ctu_int` to
  `ctud_ulint` and `ctu_dint`, `ctd_dint` and `ctud_dint`), every rule from source through
  `Logex.compile/2`, `Logex.Runtime.call/4`, `Logex.Edit` and `Logex.Configuration`: each
  of the twelve run by `ctu` and `ctd`, its preset judged in its type, stopping at its
  type's limits with `ov` or `un` latched, decision 71 by width; its edge memory on the
  edit's block list as a `ctu`'s; an edit of its width refused; the event task's warning
  naming it; and each alias the very type of its plain word, named by that word in every
  message and warning, and keeping no spelling.

  The limits are restated here from IEC's Table 10, never read from `Logex.Declarations`.
  """
  use ExUnit.Case, async: true

  # Decision 192: a counter's slot names every type word it runs.
  @runs_ctu "a ctu, ctud, ctu_int, ctud_int, ctu_lint, ctud_lint, ctu_udint, ctud_udint, ctu_ulint or ctud_ulint"
  @runs_ctd "a ctd, ctud, ctd_int, ctud_int, ctd_lint, ctud_lint, ctd_udint, ctud_udint, ctd_ulint or ctud_ulint"

  alias Logex.{Configuration, Diagnostic, Edit, FbType, Instance, Runtime, Scan}

  # IEC 61131-3 Ed 3 Table 10: each counter width's limits, footnotes c and d.
  @limits %{
    "int" => {-32_768, 32_767},
    "dint" => {-2_147_483_648, 2_147_483_647},
    "lint" => {-9_223_372_036_854_775_808, 9_223_372_036_854_775_807},
    "udint" => {0, 4_294_967_295},
    "ulint" => {0, 18_446_744_073_709_551_615}
  }
  @typed ~w(int lint udint ulint)
  @kinds ~w(ctu ctd ctud)

  defp c!(src, name \\ "m") do
    {:ok, program} = Logex.compile(src, name: name)
    program
  end

  defp messages(src) do
    {:error, diagnostics} = Logex.compile(src, name: "m")
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  defp warnings(src), do: Enum.map(c!(src).warnings, &Diagnostic.format/1)

  # Scans `program` from `state` once per entry of `inputs`, 10 ms apart, after a first scan
  # with every input 0: each scan's counter map at `at`.
  defp trace(program, state, inputs, at) do
    {values, _state} =
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + 10, first: first})
        {get_in(state.env, at), state}
      end)

    values
  end

  # An instance whose counter `c` stands at `cv`, its first scan done.
  defp at(program, cv) do
    state = Runtime.instance(program)
    {_out, state} = Runtime.call(program, state, %{}, %Scan{now: 0, first: true})
    put_in(state.env["c"]["cv"], cv)
  end

  defp pulses(n, input), do: Enum.flat_map(1..n, fn _ -> [%{input => 1}, %{input => 0}] end)

  defp up(width),
    do:
      c!(
        "var_input e bool\nvar_input rst bool\nvar c ctu#{width}\nxic rst ote c.r\nxic e ctu c 5"
      )

  defp down(width),
    do:
      c!(
        "var_input e bool\nvar_input load bool\nvar c ctd#{width}\nxic load ote c.ld\nxic e ctd c 5"
      )

  describe "PLAN M5-5's Done-when: each typed counter stops at its type's limits" do
    test "a `ctu_int` count stops at 32,767 with `ov` on, which stays until `r`" do
      p = up("_int")
      [one, two, three, four] = trace(p, at(p, 32_766), pulses(2, "e"), ["c"])
      assert {one["cv"], one["ov"]} == {32_767, 0}
      assert {two["cv"], three["cv"], three["ov"], four["ov"]} == {32_767, 32_767, 1, 1}
      [reset] = trace(p, put_in(at(p, 32_767).env["c"]["ov"], 1), [%{"rst" => 1}], ["c"])
      assert {reset["cv"], reset["ov"]} == {0, 0}
    end

    test "a `ctd_udint` count stops at 0 with `un` on, which stays until `ld`" do
      p = down("_udint")
      [one, _, two, three] = trace(p, at(p, 1), pulses(2, "e"), ["c"])
      assert {one["cv"], one["un"]} == {0, 0}
      assert {two["cv"], two["un"], three["un"]} == {0, 1, 1}
      [loaded] = trace(p, put_in(at(p, 0).env["c"]["un"], 1), [%{"load" => 1}], ["c"])
      assert {loaded["cv"], loaded["un"]} == {5, 0}
    end

    test "a `ctu_ulint` counts past 2^63, where a dint and an lint stop long before" do
      p = up("_ulint")
      top = Integer.pow(2, 63)
      assert [%{"cv" => cv, "ov" => 0} | _] = trace(p, at(p, top - 1), pulses(2, "e"), ["c"])
      assert cv == top
      assert List.last(trace(p, at(p, top - 1), pulses(2, "e"), ["c", "cv"])) == top + 1
    end

    test "every kind of every width stops at its own two limits, its flag latched, one " <>
           "inside them counting" do
      for kind <- @kinds, width <- Map.keys(@limits) do
        {min, max} = @limits[width]
        word = if width == "dint", do: kind, else: "#{kind}_#{width}"

        p =
          c!(
            "var_input u bool\nvar_input d bool\nvar c #{word}\n" <>
              Enum.join(rungs(kind), "\n")
          )

        if kind != "ctd" do
          assert [%{"cv" => ^max, "ov" => 1}, _] =
                   trace(p, at(p, max), pulses(1, "u"), ["c"]),
                 "#{word} at its top"

          below = max - 1
          assert [%{"cv" => ^max, "ov" => 0}, _] = trace(p, at(p, below), pulses(1, "u"), ["c"])
        end

        if kind != "ctu" do
          assert [%{"cv" => ^min, "un" => 1}, _] =
                   trace(p, at(p, min), pulses(1, "d"), ["c"]),
                 "#{word} at its bottom"

          above = min + 1
          assert [%{"cv" => ^min, "un" => 0}, _] = trace(p, at(p, above), pulses(1, "d"), ["c"])
        end
      end
    end

    test "a count of a member's `pv`, written past a dint's top, sets `q` in a wide counter" do
      p =
        c!(
          "var_input e bool\nvar big lint\nvar c ctu_lint\nvar_output full bool\n" <>
            "xic e ctu c 1\nxic e move big c.pv\nxic c.q ote full"
        )

      state = put_in(at(p, 4_000_000_000).env["big"], 4_000_000_001)
      [_one, two] = trace(p, state, [%{"e" => 1}, %{"e" => 1}], ["c"])
      assert {two["cv"], two["pv"], two["q"]} == {4_000_000_001, 4_000_000_001, 1}
    end
  end

  defp rungs("ctu"), do: ["xic u ctu c 1"]
  defp rungs("ctd"), do: ["xic d ctd c 1"]
  defp rungs("ctud"), do: ["xic u ctu c 1", "xic d ctd c 1"]

  describe "a typed counter's preset is judged in its type" do
    # Decision 191: any value of the counter's type, as IEC's PV is, a signed counter's
    # negatives among them, an unsigned one's 0 to its top.
    test "its two limits are taken and one past either refused at its line, a dint's too" do
      for kind <- ~w(ctu ctd), width <- @typed ++ ["dint"] do
        {min, max} = @limits[width]
        of = if width == "dint", do: "", else: " for a counter of #{width}s"

        for value <- [min, max] do
          assert %Logex.Program{} =
                   p = c!("var e bool\nvar c #{kind}_#{width}\nxic e #{kind} c #{value}")

          assert Logex.Program.initial_env(p)["c"]["pv"] == value
        end

        for value <- [min - 1, max + 1] do
          assert messages("var e bool\nvar c #{kind}_#{width}\nxic e #{kind} c #{value}") == [
                   "line 3: `#{kind}` takes a preset of #{min} to #{max}#{of}, found `#{value}`"
                 ]
        end
      end

      assert messages("var e bool\nvar c ctu_dint\nxic e ctu c 2147483648") == [
               "line 3: `ctu` takes a preset of -2147483648 to 2147483647, found `2147483648`"
             ]

      assert %Logex.Program{} = c!("var e bool\nvar offset ctu_int\nxic e ctu offset -10")
      assert %Logex.Program{} = c!("var e bool\nvar c ctu\nxic e ctu c -2147483648")

      assert messages("var e bool\nvar c ctu_udint\nxic e ctu c -1") == [
               "line 3: `ctu` takes a preset of 0 to 4294967295 for a counter of udints, " <>
                 "found `-1`"
             ]

      assert messages("var e bool\nvar t ton\nxic e ton t 2147483648") == [
               "line 3: `ton` takes a preset of 0 to 2147483647 ms, found `2147483648`"
             ]
    end

    test "a ctud's two sides each judge its preset in its type, and a preset starts its `pv`" do
      p =
        c!(
          "var e bool\nvar c ctud_ulint\nxic e ctu c 18446744073709551615\nxio e ctd c 18446744073709551615"
        )

      assert Logex.Program.initial_env(p)["c"]["pv"] == 18_446_744_073_709_551_615

      assert messages("var e bool\nvar c ctud_int\nxic e ctu c 32767\nxio e ctd c 32768") == [
               "line 4: `ctd` takes a preset of -32768 to 32767 for a counter of ints, found " <>
                 "`32768`",
               "line 4: `c` already has the preset 32767 from the `ctu` on line 3: the `ctu` " <>
                 "and the `ctd` of a ctud_int give it one preset, so this `ctd` takes 32767 too"
             ]

      # The message names the counter by its own word, as every other does (M5-5's
      # review); an alias keeps no spelling, so a `ctud_dint` is a ctud; and a counter of
      # one kind, refused for the other side, is named the ctud of its own width it is told
      # to declare.
      for {word, named} <- [
            {"ctud_ulint", "a ctud_ulint"},
            {"ctud_dint", "a ctud"},
            {"ctud", "a ctud"},
            {"CTUD_LINT", "a ctud_lint"},
            {"ctu_udint", "a ctud_udint"},
            {"ctd_int", "a ctud_int"}
          ] do
        assert ("line 4: `c` already has the preset 5 from the `ctu` on line 3: the `ctu` " <>
                  "and the `ctd` of #{named} give it one preset, so this `ctd` takes 5 too") in messages(
                 "var e bool\nvar c #{word}\nxic e ctu c 5\nxio e ctd c 4"
               )
      end
    end

    test "a preset from a tag is told the `move`, where the tag widens into its `pv`" do
      assert [message] = messages("var e bool\nvar s sint\nvar c ctu_int\nxic e ctu c s")
      assert message =~ "to preset `c` from a tag, `move s c.pv` on a rung above"

      assert [message] = messages("var e bool\nvar s dint\nvar c ctu_int\nxic e ctu c s")
      refute message =~ "move"

      assert [message] = messages("var e bool\nvar s udint\nvar c ctu_ulint\nxic e ctu c s")
      assert message =~ "`move s c.pv`"
    end

    test "a `move` into a typed counter's `pv` takes a source that widens into its type" do
      assert %Logex.Program{} =
               c!("var e bool\nvar s int\nvar c ctu_int\nxic e ctu c 1\nxic e move s c.pv")

      assert [message] =
               messages("var e bool\nvar s dint\nvar c ctu_int\nxic e ctu c 1\nxic e move s c.pv")

      assert message =~ "dint_to_int"
    end
  end

  describe "the instructions of its kind run it, and no other" do
    test "a counter of the other kind is told the up-down counter of its own type" do
      assert messages("var e bool\nvar c ctd_lint\nxic e ctu c 1") == [
               "line 3: `ctu` runs #{@runs_ctu}, but `c` is a ctd_lint (declared on line 2): " <>
                 "a ctd_lint only counts down; declare it `var c ctud_lint` to count both ways"
             ]

      assert messages("var e bool\nvar c ctu_dint\nxic e ctd c 1") == [
               "line 3: `ctd` runs #{@runs_ctd}, but `c` is a ctu (declared on line 2): " <>
                 "a ctu only counts up; declare it `var c ctud` to count both ways"
             ]

      assert messages("var e bool\nvar c ctu_udint\nxic e ton c 1") == [
               "line 3: `ton` runs a ton, but `c` is a ctu_udint (declared on line 2)"
             ]
    end

    test "its members are named as a counter's, of its type" do
      assert [message] = messages("var e bool\nvar c ctu_int\nxic e ctu c 1\nxic c.dn ote e")

      assert message =~
               "`c.dn` is not a member of `c`, a ctu_int: its members are `cu`, `r`, `pv`, `q`, `cv` and `ov`"

      assert [message] = messages("var e bool\nvar c ctu_uint\nxic e ctu c 1")
      assert message =~ "unknown type `ctu_uint`"
    end
  end

  describe "PLAN M5-5's Done-when: across an online edit" do
    @c "var_input e bool\nvar_input g bool\nvar_output y bool\n"

    test "an edit that changes a counter's width is refused at its line, in its type's words" do
      for {from, to, was, now} <- [
            {"ctu", "ctu_int", "ctu", "ctu_int"},
            {"ctu_dint", "ctu_int", "ctu", "ctu_int"},
            {"ctd_udint", "ctd_ulint", "ctd_udint", "ctd_ulint"},
            {"ctud_lint", "ctud", "ctud_lint", "ctud"}
          ] do
        side = if String.starts_with?(from, "ctd"), do: "ctd", else: "ctu"
        v1 = c!(@c <> "var c #{from}\nxic e #{side} c 3")
        v2 = c!(@c <> "var c #{to}\nxic e #{side} c 3")

        assert Edit.accept(v1, v2, Runtime.instance(v1)) ==
                 {:error,
                  [
                    %Diagnostic{
                      stage: :edit,
                      line: 4,
                      message:
                        "`c` is a #{was} in the running program and a #{now} in the candidate: " <>
                          "a tag's type changes only with a restart"
                    }
                  ]}
      end
    end

    test "an edit from a plain word to its alias, or back, is accepted and reports nothing" do
      for {from, to} <- [{"ctu", "ctu_dint"}, {"ctd_dint", "ctd"}, {"ctud", "ctud_dint"}] do
        side = if String.starts_with?(from, "ctd"), do: "ctd", else: "ctu"
        v1 = c!(@c <> "var c #{from}\nxic e #{side} c 3")
        v2 = c!(@c <> "var c #{to}\nxic e #{side} c 3")
        state = Runtime.instance(v1)
        assert {:ok, edit, []} = Edit.accept(v1, v2, state)
        assert {_edit, tested, []} = Edit.test(edit, state)
        assert tested.env == state.env
      end
    end

    test "its edge memory is on the block list as a `ctu`'s, and a real edge counts after" do
      v1 = c!(@c <> "var c ctu_int\nxic e ctu c 3")
      v2 = c!(@c <> "var c ctu_int\nxic e xic g ctu c 3")
      state = Runtime.instance(v1)
      {_, state} = Runtime.scan(v1, Runtime.put_inputs(v1, state, %{"e" => 0, "g" => 1}), 10)
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      assert forecast == [{:ons_blocked, "c.cu", 0}]
      {_edit, tested, report} = Edit.test(edit, state)
      assert report == forecast
      assert tested.ons_blocked == ["c.cu"]
      {_, later} = Runtime.scan(v2, Runtime.put_inputs(v2, tested, %{"e" => 1}), 10)
      assert {later.env["c"]["cv"], later.ons_blocked} == {0, []}
      {_, later} = Runtime.scan(v2, Runtime.put_inputs(v2, later, %{"e" => 0}), 10)
      {_, later} = Runtime.scan(v2, Runtime.put_inputs(v2, later, %{"e" => 1}), 10)
      assert later.env["c"]["cv"] == 1
    end
  end

  # Decision 191: a signed counter's preset is any value of its type, as IEC's PV is. The
  # done lamps are IEC's Table 45 bodies restated, `q` (`qu`) CV >= PV and `qd` CV <= 0,
  # whatever the preset's sign.
  describe "a negative preset (decision 191)" do
    test "an up counter's done lamp is lit at once by a preset below its count, as CV >= PV" do
      p =
        c!(
          "var_input e bool\nvar offset ctu_int\nvar_output lamp bool\nxic e ctu offset -10\nxic offset.q ote lamp"
        )

      state = Runtime.instance(p)
      assert state.env["offset"]["pv"] == -10
      {out, state} = Runtime.call(p, state, %{"e" => 0}, %Scan{now: 0, first: true})
      assert {state.env["offset"]["cv"], state.env["offset"]["q"], out["lamp"]} == {0, 1, 1}
    end

    test "a ctud's `qu` holds while its count is at or above a negative preset, and drops " <>
           "below it" do
      p = c!("var_input u bool\nvar_input d bool\nvar c ctud_int\nxic u ctu c -3\nxic d ctd c -3")
      values = trace(p, at(p, 0), pulses(4, "d"), ["c"])
      seen = for %{"cv" => cv, "qu" => qu, "qd" => qd} <- values, do: {cv, qu, qd}

      assert seen == [
               {-1, 1, 1},
               {-1, 1, 1},
               {-2, 1, 1},
               {-2, 1, 1},
               {-3, 1, 1},
               {-3, 1, 1},
               {-4, 0, 1},
               {-4, 0, 1}
             ]
    end

    test "a down counter loads a negative preset, its `q` CV <= 0" do
      p =
        c!(
          "var_input e bool\nvar_input load bool\nvar c ctd_lint\nxic load ote c.ld\nxic e ctd c -5"
        )

      [loaded] = trace(p, at(p, 7), [%{"load" => 1}], ["c"])
      assert {loaded["cv"], loaded["q"]} == {-5, 1}
    end

    test "an edit's preset rules and forecast hold at a negative preset" do
      v1 = c!("var_input e bool\nvar c ctu_int\nxic e ctu c 5")
      v2 = c!("var_input e bool\nvar c ctu_int\nxic e ctu c -10")
      state = at(v1, 0)
      assert state.env["c"]["q"] == 0

      # `pv` still at the old preset takes the new one, and `q` rises at the next run.
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      assert forecast == [{:dn_rises, "c", {0, -10}}, {:preset, "c", {5, -10}}]
      {_edit, tested, report} = Edit.test(edit, state)
      assert report == forecast
      assert tested.env["c"]["pv"] == -10
      {_, later} = Runtime.call(v2, tested, %{"e" => 0}, %Scan{now: 20, first: false})
      assert later.env["c"]["q"] == 1

      # And back: `q` drops.
      {:ok, back, forecast} = Edit.accept(v2, v1, later)
      assert forecast == [{:dn_drops, "c", {0, 5}}, {:preset, "c", {-10, 5}}]
      {_edit, tested, _report} = Edit.test(back, later)
      assert tested.env["c"]["pv"] == 5

      # A `pv` logic moved off the old preset, to a negative one, is kept.
      moved = put_in(state.env["c"]["pv"], -2)
      {:ok, _edit, forecast} = Edit.accept(v1, v2, moved)
      assert forecast == [{:preset_kept, "c", {-2, -10}}]
    end
  end

  describe "PLAN M5-5's Done-when: an alias is its plain word's very type" do
    # A test that fails when an alias is made a type of its own: the two programs differ
    # in their text alone.
    test "`var boxes ctu_dint` and `var boxes ctu` compile to equal programs, and so the " <>
           "other two, in any case" do
      for {alias, word, side} <- [
            {"ctu_dint", "ctu", "ctu"},
            {"CTD_DINT", "ctd", "ctd"},
            {"Ctud_Dint", "ctud", "ctu"}
          ] do
        a = c!("var e bool\nvar boxes #{alias}\nxic e #{side} boxes 4")
        b = c!("var e bool\nvar boxes #{word}\nxic e #{side} boxes 4")
        assert %{a | source: nil} == %{b | source: nil}
        assert a.tags["boxes"].type == FbType.builtin(word)
        assert FbType.builtin(alias) == FbType.builtin(word)
      end
    end

    test "an instance declared `ctu_dint` is named `ctu` in its unrun warning and its article" do
      assert warnings("var_output e bool\nvar boxes ctu_dint\nxic boxes.q ote e") == [
               "line 2: warning: `boxes` is a ctu, but no `ctu` runs it: it never counts"
             ]

      assert warnings("var_output e bool\nvar boxes ctud_dint\nxic boxes.qu ote e") == [
               "line 2: warning: `boxes` is a ctud, but no `ctu` or `ctd` runs it: it never counts"
             ]

      assert warnings("var_output e bool\nvar boxes ctu_int\nxic boxes.q ote e") == [
               "line 2: warning: `boxes` is a ctu_int, but no `ctu` runs it: it never counts"
             ]

      assert Logex.Declarations.instance_of(FbType.builtin("ctu_dint")) == "a ctu"
      assert Logex.Declarations.instance_of(FbType.ctu_int()) == "a ctu_int"
    end

    test "the compiler's refusal of a second `ctu` on it names it as a `ctu`'s" do
      assert messages("var e bool\nvar boxes ctu_dint\nxic e ctu boxes 3\nxic e ctu boxes 3") == [
               "line 4: `boxes` is already run by the `ctu` on line 3: one `ctu` runs a " <>
                 "counter's count up"
             ]

      assert messages("var e bool\nvar boxes ctu_dint\nxic e ctu boxes 3 xic e") == [
               "line 3: `xic e` follows `ctu boxes` on its path: what passes on after a `ctu` " <>
                 "is not settled, so a `ctu` ends its path; read the counter with " <>
                 "`xic boxes.q` on a rung below"
             ]

      assert messages("var e bool\nvar boxes ctu_dint\nxic boxes ote e") |> hd() =~
               "but `boxes` is a ctu (declared on line 2)"
    end

    test "a declared initial value is told of the `ctu` that presets it, in the plain word" do
      assert [message] = messages("var boxes ctu_dint 4")
      assert message =~ "`boxes` is a ctu: its preset is the number on its `ctu` instruction"
    end
  end

  describe "PLAN M5-5's Done-when: the event task's counter warning names each" do
    @counted """
    var_input go bool
    var boxes ctu_int
    var cases ctu_dint
    var stock ctud_ulint
    xic go ctu boxes 5
    xic go ctu cases 5
    xic go ctu stock 5
    xio go ctd stock 5
    """

    test "a typed counter and an alias's, each in the counter's words" do
      {:ok, counted} = Logex.compile(@counted, name: "counted")

      text = """
      task trip single go priority 0
      var_global go bool
      program a counted with trip
      a.go go
      """

      assert {:ok, config} = Configuration.compile("plant", text, %{"counted" => counted})

      assert Enum.map(config.warnings, & &1.message) ==
               for(
                 {counter, line} <- [{"boxes", 5}, {"cases", 6}, {"stock", 7}],
                 do:
                   "`a` runs under the event task `trip`, and `counted` runs the counter " <>
                     "`#{counter}` on its line #{line}: a counter sees its rung only at the " <>
                     "task's runs, so a pulse between two runs is never counted, and a rung " <>
                     "that is the task's trigger is true at every run and never counts"
               )
    end
  end

  describe "a typed counter in the host contract" do
    test "a state whose counter holds a value outside its type is refused, in its type's words" do
      p = up("_int")
      state = put_in(Runtime.instance(p).env["c"]["cv"], 32_768)

      assert_raise ArgumentError,
                   ~r/`c.cv` outside its type: .*32768.* is outside -32768 to 32767/,
                   fn -> Runtime.call(p, state, %{}, %Scan{now: 0, first: true}) end
    end

    test "inside a function block it counts in its type, by its path" do
      {:ok, tally} =
        Logex.compile(
          "function_block tally\nvar_input go bool\nvar c ctd_udint\nxic go ctd c 2",
          name: "tally"
        )

      {:ok, p} =
        Logex.compile("var_input e bool\nvar s tally\ncal s e", name: "m", types: [tally])

      state = Runtime.instance(p)
      {_, state} = Runtime.call(p, state, %{"e" => 0}, %Scan{now: 0, first: true})
      [one, _, two] = trace(p, state, [%{"e" => 1}, %{"e" => 0}, %{"e" => 1}], ["s", "c"])
      assert {one["cv"], one["un"], two["cv"], two["un"]} == {0, 1, 0, 1}
    end
  end

  describe "growth" do
    # A counter's limits are its `cv` member's range, found in its type's few members, so
    # 4x the counters compile and scan in about 4x the reductions, and a typed counter's
    # scan costs about a dint counter's.
    test "a program's typed counters cost linear reductions to compile and to scan" do
      source = fn n, word ->
        "var_input e bool\n" <>
          Enum.map_join(1..n, "\n", &"var c#{&1} #{word}") <>
          "\n" <> Enum.map_join(1..n, "\n", &"xic e ctu c#{&1} 5")
      end

      cost = fn n, word, what ->
        text = source.(n, word)
        {:ok, p} = Logex.compile(text, name: "p")
        state = Runtime.put_inputs(p, Runtime.instance(p), %{"e" => 1})

        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            what.(text, p, state)
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      compile = fn text, _p, _state -> Logex.compile(text, name: "p") end
      scan = fn _text, p, state -> Runtime.scan(p, state) end

      for {what, name} <- [{compile, "compile"}, {scan, "scan"}] do
        ratio = cost.(400, "ctu_ulint", what) / cost.(100, "ctu_ulint", what)
        assert ratio < 4.8, "4x the counters took #{Float.round(ratio, 2)}x to #{name}"
      end

      typed = cost.(400, "ctu_ulint", scan) / cost.(400, "ctu", scan)
      assert typed < 1.2, "a typed counter scanned in #{Float.round(typed, 2)}x a dint's"
    end

    # The fifteen new type words cost a program that uses none of them nothing: a type
    # word is looked up in a table built once, as logex compiles, a lookup costing tens of
    # reductions where building the table on each call cost over a thousand (M5-5's
    # review), so a program of bools compiles, against its own parse, as it did before
    # M5-5, about 12x, where a table built on each lookup made it about 40x.
    test "a type word's lookup builds no table, so a program of bools compiles as before" do
      least = fn f ->
        Enum.min(
          for _ <- 1..3 do
            {:reductions, before} = Process.info(self(), :reductions)
            f.()
            {:reductions, later} = Process.info(self(), :reductions)
            later - before
          end
        )
      end

      for word <- Map.keys(Logex.FbType.builtins()) ++ ["ctu_foo", "abc"] do
        looked = least.(fn -> Logex.FbType.builtin(word) end)
        assert looked < 200, "looking `#{word}` up took #{looked} reductions"
        reserved = least.(fn -> Logex.Declarations.reserved(word) end)
        assert reserved < 300, "`#{word}`'s reservation took #{reserved} reductions"
      end

      text =
        Enum.map_join(1..400, "\n", &"var b#{&1} bool") <>
          "\n" <> Enum.map_join(1..400, "\n", &"xic b#{&1} ote b#{&1}")

      compiled = least.(fn -> Logex.compile(text, name: "p") end)

      parsed =
        least.(fn ->
          {:ok, tokens, _end} = Logex.Compiler.tokenize(text)
          Logex.Compiler.parse(tokens)
        end)

      assert compiled / parsed < 20,
             "400 bool rungs compiled in #{Float.round(compiled / parsed, 1)}x their parse"
    end
  end

  describe "the fifteen counter words are reserved in every `.ld` file, in any case" do
    test "none names a tag or a label" do
      words =
        for(kind <- @kinds, width <- @typed, do: "#{kind}_#{width}") ++
          ~w(ctu_dint ctd_dint ctud_dint)

      assert length(words) == 15

      for word <- words, shown <- [word, String.upcase(word)] do
        assert messages("var #{shown} bool\nxic #{shown} ote #{shown}") |> hd() ==
                 "line 1: `#{shown}` is a type and cannot name a tag"

        assert messages("var b bool\nxic b jmp #{shown}\nlbl #{shown} ote b") |> hd() =~
                 "`#{shown}`"
      end
    end
  end
end
