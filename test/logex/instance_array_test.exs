defmodule Logex.InstanceArrayTest do
  @moduledoc """
  PLAN M5-14: arrays of function block instances (`docs/organisation.md` §4.12, decision
  154), every rule from source through `Logex.compile/2`, `Logex.Runtime.call/4`,
  `Logex.Edit`, `Logex.Configuration` and `Logex.Runtime.get/2`: an array of timers, of
  counters or of a user block's instances, `var lane_t ton[4]`, `var lane_c ctu_int[4]` or
  `var lanes seal[4]`, of one to three dimensions, the long and the typed variants among
  them, each element an instance of its own with its own path, `lane_t[2]`; a literal
  subscript on every instruction that runs one, `ton lane_t[2] 500`, `ctu lane_c[1] 5` or
  `cal lanes[2] …`, and one a tag subscripts refused, told why; a member read or written by
  literal subscripts or through a tag subscript, `xic lane_t[slot].dn` or `move 0
  lane_c[i].pv`, one outside its dimension M5-12's index fault; M1-6's one-run rule and
  decision 85's two counter rungs per element; an edit's preset, resume and block list by
  the element's path; the warnings and the event task's warnings naming each element; the
  host contract and the state check of an array of instances, at depth for user blocks
  holding arrays; and a configuration, where an array of instances is never a global, a
  connection or located.

  Each element's behaviour is restated here as a scalar instance's of its type, never read
  from `Logex.Runtime`.
  """
  use ExUnit.Case, async: true

  alias Logex.{Edit, Fault, Runtime, Scan, Walk}

  @seal "function_block seal\nvar_input s bool\nvar_output q bool\nvar t ton\nvar e bool\n" <>
          "xic s ton t 30\nxic t.dn ote q\nxic s ons e\n"

  defp seal do
    {:ok, seal} = Logex.compile(@seal, name: "seal")
    seal
  end

  defp program(source, types \\ [], name \\ "p") do
    {:ok, program} = Logex.compile(source, name: name, types: types)
    program
  end

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "p", types: types)
    Enum.map(diagnostics, &{&1.line, &1.message})
  end

  defp warnings(source, types \\ []),
    do: Enum.map(program(source, types).warnings, &{&1.line, &1.message})

  # Scans of one instance through call/4 at the times given, the first a first scan, each
  # with its inputs: the last outputs and the state.
  defp run(program, scans, state \\ nil) do
    state = state || Runtime.instance(program)

    Enum.reduce(scans, {nil, state}, fn {now, inputs}, {_outputs, state} ->
      Runtime.call(program, state, inputs, %Scan{now: now, first: state.first})
    end)
  end

  defp element(state, array, i), do: elem(state.env[array], i)

  defp fault(instruction, line, read, path \\ nil, file \\ nil),
    do: %Fault{
      severity: :major,
      kind: :index_out_of_range,
      instruction: instruction,
      path: path,
      file: file,
      line: line,
      read: List.to_tuple(read)
    }

  # Restated: a ton's state, IEC's TON with logex's members (docs/naming.md, `ton`), as a
  # scalar `ton` keeps it.
  defp ton(pre, acc, dn, tt, en, last),
    do: %{"pre" => pre, "acc" => acc, "dn" => dn, "tt" => tt, "en" => en, "last" => last}

  describe "the declaration (decision 154)" do
    test "an array of timers, counters or a user block's instances, of one to three dimensions, starts each element as an instance of its own" do
      p =
        program(
          "var lane_t ton[4]\nvar lane_c ctu_int[2]\nvar grid ctud[2,3]\nvar cube tof[2,2,2]\n" <>
            "var cure ton_ltime[2]\nvar lanes seal[3]\nvar go bool\n" <>
            "xic go ton lane_t[2] 500\nxic go ctu lane_c[1] 7\nxic go ctu grid[1,2] 4\n" <>
            "xic go ctd grid[1,2] 4\nxic go tof cube[1,0,1] 20\nxic go ton cure[0] 3000000\n" <>
            "cal lanes[2] go go",
          [seal()]
        )

      state = Runtime.instance(p)
      assert tuple_size(state.env["lane_t"]) == 4
      # Each element's preset is the number on the instruction that runs it; the others
      # start at their type's 0.
      assert element(state, "lane_t", 2) == ton(500, 0, 0, 0, 0, 0)

      for i <- [0, 1, 3], do: assert(element(state, "lane_t", i) == ton(0, 0, 0, 0, 0, 0))

      assert %{"pv" => 7, "cv" => 0, "ov" => 0} = element(state, "lane_c", 1)
      assert %{"pv" => 0} = element(state, "lane_c", 0)
      assert %{"pv" => 4, "qd" => 0, "qu" => 0} = elem(element(state, "grid", 1), 2)
      assert %{"pre" => 20} = state.env["cube"] |> elem(1) |> elem(0) |> elem(1)
      assert %{"pre" => 3_000_000} = element(state, "cure", 0)
      assert %{"s" => 0, "q" => 0, "e" => 0, "t" => %{"pre" => 30}} = element(state, "lanes", 2)
    end

    test "an array of instances takes no initial list and no section but var, and its sizes meet every array's rule, each at its line" do
      assert messages("var lane_t ton[4] 1 2 3 4\nvar a bool\nxic a ton lane_t[2] 500") == [
               {1,
                "`lane_t` is an array of 4 tons, which takes no initial values: each " <>
                  "element's preset is the number on its `ton` instruction, as in " <>
                  "`ton lane_t[0] 5000`"}
             ]

      # Whatever the list holds, a word among its literals too.
      assert messages("var lane_t ton[2] 1 x\nvar a bool\nxic a ton lane_t[1] 500") == [
               {1,
                "`lane_t` is an array of 2 tons, which takes no initial values: each " <>
                  "element's preset is the number on its `ton` instruction, as in " <>
                  "`ton lane_t[0] 5000`"}
             ]

      assert messages("var lanes seal[2] 1 2\nvar a bool\ncal lanes[1] a a", [seal()]) == [
               {1,
                "`lanes` is an array of 2 instances of `seal`, which takes no initial values: " <>
                  "each element's members start where its type says"}
             ]

      for section <- ~w(var_input var_output var_external) do
        assert messages("#{section} lane_c ctud[2]\nvar a bool\nxic a ctu lane_c[1] 5") == [
                 {1,
                  "`lane_c` is an array of 2 ctuds: an array of instances is the program's " <>
                    "own, declared with `var`, as in `var lane_c ctud[2]`, not with `#{section}`"}
               ]
      end

      assert messages("var t ton[0]\nvar a bool\nxic a ton t[0] 5") == [
               {1,
                "`t` is declared with a dimension of 0, `[0]`: each dimension of an array " <>
                  "holds 1 element or more"}
             ]

      assert messages("var t ton[2,2,2,2]\nvar a bool\nxic a ton t[0,0,0,0] 5") == [
               {1,
                "`t` is declared with 4 dimensions, `[2,2,2,2]`: an array has one to three, " <>
                  "as in `int[8]`, `int[4,8]` or `int[2,3,4]`"}
             ]

      assert messages("var t ton[300,300]\nvar a bool\nxic a ton t[0,0] 5") == [
               {1, "`t` would hold 90000 elements, `[300,300]`: an array holds 65536 at most"}
             ]

      assert messages("var t ton[n]\nvar a bool\nxic a ton t[0] 5") == [
               {1,
                "`t` is declared `ton[n]`, sized by `n`: an array's sizes are literal " <>
                  "numbers, as in `int[8]`, fixed when the program compiles"}
             ]

      assert [{1, "unknown type `tonn`: logex has " <> _}] =
               messages("var t tonn[2]\nvar a bool\nxic a ton t[0] 5")
    end

    test "a block never holds an array of instances of itself, at any depth" do
      {:error, [diagnostic]} =
        Logex.compile("function_block seal\nvar_output q bool\nvar s2 seal[2]\nxic q ote q",
          name: "seal"
        )

      assert {diagnostic.line, diagnostic.message} ==
               {3,
                "`seal` cannot hold an instance of `seal`: a function block never holds an " <>
                  "instance of itself"}

      inner = program("function_block inner\nvar_output q bool\nxic q ote q", [], "inner")

      {:ok, outer} =
        Logex.compile("function_block outer\nvar_output q bool\nvar i inner[2]\nxic q ote q",
          name: "outer",
          types: [inner]
        )

      {:error, [diagnostic]} =
        Logex.compile(
          "function_block inner\nvar_output q bool\nvar o outer[2]\nxic q ote q",
          name: "inner",
          types: [outer]
        )

      assert diagnostic.message =~ "never holds an instance of itself"
    end

    test "from Elixir, an array of instances is declared as an instance is, and each rule refuses it in the host's words" do
      ton = Logex.FbType.ton()
      tag = Logex.Tag.new!("lane_t", {:array, ton, [2]}, :var)
      assert tag.type == {:array, ton, [2]}

      assert_raise ArgumentError,
                   "`lane_t` is an array of 2 tons: an array of instances is the program's own, " <>
                     "declared with `var`, as in `var lane_t ton[2]`, not with `var_input`",
                   fn -> Logex.Tag.new!("lane_t", {:array, ton, [2]}, :var_input) end

      assert_raise ArgumentError,
                   "`lane_t` is an array of 2 tons, which takes no initial values: each " <>
                     "element's preset is the number on its `ton` instruction, as in " <>
                     "`ton lane_t[0] 5000`",
                   fn -> Logex.Tag.new!("lane_t", {:array, ton, [2]}, :var, %{[0] => %{}}) end

      assert_raise ArgumentError,
                   "`lane_t` is declared with a dimension of 0, `[0]`: each dimension of an " <>
                     "array holds 1 element or more",
                   fn -> Logex.Tag.new!("lane_t", {:array, ton, [0]}, :var) end

      assert_raise ArgumentError, ~r/^unknown function block type "tonx"/, fn ->
        Logex.Tag.new!("lane_t", {:array, %{ton | name: "tonx"}, [2]}, :var)
      end

      # M5-14's review: an array of a user block's instances declared from Elixir holds the
      # one version of its block the types given hold, as a scalar instance does.
      {:ok, other} =
        Logex.compile(String.replace(@seal, "ton t 30", "ton t 40"), name: "seal")

      routine = Logex.Compiler.parse(elem(Logex.Compiler.tokenize("xic go ote q"), 1))
      go = [Logex.Tag.new!("go", :bool, :var_input), Logex.Tag.new!("q", :bool, :var_output)]

      for tag <- [
            Logex.Tag.new!("lanes", {:array, other, [2]}, :var),
            Logex.Tag.new!("lane", other, :var)
          ] do
        assert_raise ArgumentError,
                     "a tag declared from Elixir holds a function block named `seal` other " <>
                       "than the one of that name in the types given or in another tag: give " <>
                       "every instance of a block the same version, compiled against the same " <>
                       "types",
                     fn ->
                       Logex.Compiler.instructionize(elem(routine, 1), [tag | go], [seal()])
                     end
      end
    end
  end

  describe "the instruction that runs an element (decision 154)" do
    @runs "var_input go bool\nvar_input i dint\nvar_output q bool\n"

    test "every instruction that runs an instance runs an element by literal subscripts, and one a tag subscripts is refused, told why" do
      for {word, symbol, preset} <- [
            {"ton", "ton", "500"},
            {"tof", "tof", "500"},
            {"tp", "tp", "500"},
            {"rto", "rto", "500"},
            {"ton_ltime", "ton", "500"},
            {"ctu", "ctu", "5"},
            {"ctd_int", "ctd", "5"},
            {"ctud_ulint", "ctu", "5"}
          ] do
        source = @runs <> "var x #{word}[3]\n"
        assert {:ok, _} = Logex.compile(source <> "xic go #{symbol} x[2] #{preset}", name: "p")

        assert messages(source <> "xic go #{symbol} x[i] #{preset}") == [
                 {5,
                  "`#{symbol}` runs `x[i]`, whose subscript `i` holds: an instruction that runs " <>
                    "an instance takes an element of an array of instances by literal " <>
                    "subscripts, as in `#{symbol} x[0]`, so that each element is one instance, " <>
                    "run by one instruction whatever the program does"}
               ]
      end

      assert messages(@runs <> "var lanes seal[2,2]\ncal lanes[1,i] go q", [seal()]) == [
               {5,
                "`cal` runs `lanes[1,i]`, whose subscript `i` holds: an instruction that runs " <>
                  "an instance takes an element of an array of instances by literal " <>
                  "subscripts, as in `cal lanes[1,0]`, so that each element is one instance, " <>
                  "run by one instruction whatever the program does"}
             ]
    end

    test "an array of instances is run an element at a time, each subscript within its dimension and one a dimension" do
      source = @runs <> "var t ton[2,3]\nvar lanes seal[2]\n"

      assert messages(source <> "xic go ton t 500", [seal()]) == [
               {6,
                "`ton` runs one tag, but `t` is an array of 2 by 3 tons (declared on line 4): " <>
                  "an instruction takes one of its elements, as in `t[0,0]`"}
             ]

      assert messages(source <> "cal lanes go q", [seal()]) == [
               {6,
                "`cal` runs one instance of a function block, but `lanes` is an array of 2 " <>
                  "instances of `seal` (declared on line 5): `cal` runs one of its elements, " <>
                  "as in `cal lanes[0]`"}
             ]

      assert messages(source <> "xic go ton t[1,3] 500", [seal()]) == [
               {6,
                "`t[1,3]`'s subscript `3` is outside the second dimension of `t`, 0 to 2: `t` " <>
                  "is an array of 2 by 3 tons (declared on line 4)"}
             ]

      assert messages(source <> "xic go ton t[1] 500", [seal()]) == [
               {6,
                "`t[1]` names an element of `t`, an array of 2 by 3 tons (declared on line 4), " <>
                  "by 1 subscript, where it takes 2, one a dimension, as in `t[0,0]`"}
             ]

      assert messages(source <> "cal lanes[2] go q", [seal()]) == [
               {6,
                "`lanes[2]`'s subscript `2` is outside the elements of `lanes`, 0 to 1: " <>
                  "`lanes` is an array of 2 instances of `seal` (declared on line 5)"}
             ]

      # An element runs only by its own type's instruction.
      assert messages(source <> "cal t[1,1] go q", [seal()]) == [
               {6,
                "`cal` runs an instance of a user function block, but `t[1,1]` is a ton " <>
                  "(declared on line 4), which `ton t[1,1]` and its preset run"}
             ]

      assert messages(source <> "xic go ton lanes[1] 5", [seal()]) == [
               {6,
                "`ton` runs a ton or ton_ltime, but `lanes[1]` is an instance of `seal` " <>
                  "(declared on line 5)"}
             ]
    end

    test "M1-6's one-run rule holds per element: `ton lane_t[2] 500` twice is refused, however its subscript is spelled" do
      source = @runs <> "var lane_t ton[4]\nvar lanes seal[2]\n"

      assert messages(source <> "xic go ton lane_t[2] 500\nxic go ton lane_t[2] 500", [seal()]) ==
               [
                 {7, "`lane_t[2]` is already run by the `ton` on line 6: one `ton` runs a timer"}
               ]

      assert messages(source <> "xic go ton lane_t[2] 500\nxio go ton lane_t[16#2] 700", [seal()]) ==
               [{7, "`lane_t[2]` is already run by the `ton` on line 6: one `ton` runs a timer"}]

      assert messages(source <> "cal lanes[1] go q\ncal lanes[01] go q", [seal()]) == [
               {7, "`lanes[1]` is already run by the `cal` on line 6: one `cal` runs an instance"}
             ]

      # Each element is its own instance: four timers, each by one `ton`.
      p =
        program(
          source <>
            Enum.map_join(0..3, "\n", &"xic go ton lane_t[#{&1}] #{100 * (&1 + 1)}") <>
            "\ncal lanes[0] go q\ncal lanes[1] go q",
          [seal()]
        )

      assert Enum.map(0..3, &element(Runtime.instance(p), "lane_t", &1)["pre"]) ==
               [100, 200, 300, 400]
    end

    test "decision 85's two counter rungs hold per element: each element's ctu and ctd give it one preset" do
      source = @runs <> "var both ctud[2]\nvar up ctu[2]\n"

      p = program(source <> "xic go ctu both[1] 5\nxio go ctd both[1] 5\nxic go ctu both[0] 9")
      state = Runtime.instance(p)
      assert {element(state, "both", 1)["pv"], element(state, "both", 0)["pv"]} == {5, 9}

      assert messages(source <> "xic go ctu both[1] 5\nxio go ctd both[1] 6") == [
               {7,
                "`both[1]` already has the preset 5 from the `ctu` on line 6: the `ctu` and the " <>
                  "`ctd` of a ctud give it one preset, so this `ctd` takes 5 too"}
             ]

      assert messages(source <> "xic go ctu both[1] 5\nxio go ctu both[1] 5") == [
               {7,
                "`both[1]` is already run by the `ctu` on line 6: one `ctu` runs a counter's " <>
                  "count up"}
             ]

      assert messages(source <> "xic go ctd up[1] 5") == [
               {6,
                "`ctd` runs a ctd, ctud, ctd_int, ctud_int, ctd_lint, ctud_lint, ctd_udint, " <>
                  "ctud_udint, ctd_ulint or ctud_ulint, but `up[1]` is a ctu (declared on line " <>
                  "5): a ctu only counts up; declare its array `var up ctud[2]` to count both " <>
                  "ways"}
             ]
    end

    test "nothing follows an element's instruction on its path, and an element's member keeps no storage bit" do
      source = @runs <> "var lane_t ton[2]\nvar lane_c ctu[2]\n"

      assert messages(source <> "xic go ton lane_t[1] 500 ote q") == [
               {6,
                "`ote q` follows `ton lane_t[1]` on its path: what passes on after a `ton` is " <>
                  "not settled, so a `ton` ends its path; read the timer's `.dn` on a rung below"}
             ]

      assert messages(source <> "xic go ons lane_c[1].r ote q") == [
               {6,
                "`ons` keeps its storage bit in a bool of its own, not in `lane_c[1].r`, a " <>
                  "member of `lane_c[1]`, which its instance reads"}
             ]
    end
  end

  describe "a member of an element (decision 154)" do
    @members "var_input go bool\nvar_input slot dint\nvar_output q bool\nvar_output n dint\n" <>
               "var lane_t ton[3]\nvar lane_c ctu_int[3]\nvar lanes seal[2]\n"

    test "is read and written by literal subscripts or through a tag subscript, as the member of an instance is" do
      p =
        program(
          @members <>
            "xic go ton lane_t[1] 20\nxic lane_t[slot].dn ote q\nmove lane_t[slot].acc n\n" <>
            "xic go move 7 lane_c[slot].pv\nxic go add lane_c[2].pv 1 lane_c[2].pv",
          [seal()]
        )

      {outputs, state} = run(p, [{0, %{"go" => 1, "slot" => 1}}, {30, %{}}])
      assert outputs == %{"q" => 1, "n" => 20}
      assert element(state, "lane_t", 1) == ton(20, 20, 1, 0, 1, 30)
      # Through the tag subscript, `slot` 1, and by a literal one, `lane_c[2]`.
      assert Enum.map(0..2, &element(state, "lane_c", &1)["pv"]) == [0, 7, 2]

      {outputs, _state} = run(p, [{40, %{"slot" => 0}}], state)
      assert outputs == %{"q" => 0, "n" => 0}
    end

    test "a member of an element of two dimensions is written through its tag subscripts, the rest kept" do
      p =
        program(
          "var_input go bool\nvar_input k dint\nvar grid ctu[2,2]\n" <>
            "xic go move 7 grid[k,1].pv\nxic go move 1 grid[1,k].r"
        )

      {_, state} = run(p, [{0, %{"go" => 1, "k" => 1}}])
      pvs = for row <- Tuple.to_list(state.env["grid"]), c <- Tuple.to_list(row), do: c["pv"]
      cvs = for row <- Tuple.to_list(state.env["grid"]), c <- Tuple.to_list(row), do: c["r"]
      assert pvs == [0, 0, 0, 7]
      assert cvs == [0, 0, 0, 1]
      {_, state} = run(p, [{10, %{"k" => 0}}], state)
      pvs = for row <- Tuple.to_list(state.env["grid"]), c <- Tuple.to_list(row), do: c["pv"]
      assert pvs == [0, 7, 0, 7]
    end

    test "a member is written where logic may write it, and its bits are read and written as a member's are" do
      assert messages(@members <> "move 1 lane_t[slot].dn", [seal()]) == [
               {8,
                "`move` writes `lane_t[slot].dn`, but logic may write only `.pre` and `.acc` of a ton"}
             ]

      assert messages(@members <> "move 1 lanes[1].s", [seal()]) == [
               {8,
                "`move` writes `lanes[1].s`, but `lanes[1]` is an instance of `seal`, whose " <>
                  "members only its body writes"}
             ]

      assert messages(@members <> "xic lane_t[1].last ote q", [seal()]) == [
               {8,
                "`lane_t[1].last` is not a member of `lane_t[1]`, a ton: its members are `pre`, " <>
                  "`acc`, `dn`, `tt` and `en`"}
             ]

      assert messages(@members <> "move lane_t[1] n", [seal()]) == [
               {8,
                "`move` reads a value, but `lane_t[1]` is a ton (declared on line 5): name one " <>
                  "of its members, as in `lane_t[1].acc`"}
             ]

      p =
        program(
          @members <>
            "xic go ote lane_c[1].pv.3\nxic go ote lane_c[slot].pv.[slot]\n" <>
            "xic lane_c[2].pv.2 ote q\nmove lane_c[1].pv n",
          [seal()]
        )

      {outputs, state} = run(p, [{0, %{"go" => 1, "slot" => 2}}])
      assert Enum.map(0..2, &element(state, "lane_c", &1)["pv"]) == [0, 8, 4]
      assert outputs == %{"q" => 1, "n" => 8}
    end

    test "a member of a user block's element is read as its instance's public member" do
      p = program(@members <> "cal lanes[1] go q\nxic lanes[01].q ote q", [seal()])
      {:rung, [{:xic, 9, [member]} | _]} = List.last(p.rungs)
      # The member is held in its element, which keeps its name as written.
      assert member == {:member, 9, {:element, 9, "lanes", [1], "lanes[01]"}, ["q"]}
      {outputs, state} = run(p, [{0, %{"go" => 1}}, {30, %{}}])
      assert outputs["q"] == 1
      assert %{"q" => 1, "t" => %{"dn" => 1}} = element(state, "lanes", 1)
    end
  end

  describe "a scan (decision 154)" do
    test "each element times as a scalar ton would, on its own rung, the others left as they were" do
      source =
        "var_input a bool\nvar_input b bool\nvar_output q0 bool\nvar_output q1 bool\n" <>
          "var lane_t ton[3]\nvar t0 ton\nvar t1 ton\n" <>
          "xic a ton lane_t[0] 50\nxic b ton lane_t[1] 20\nxic a ton t0 50\nxic b ton t1 20\n" <>
          "xic lane_t[0].dn ote q0\nxic lane_t[1].dn ote q1"

      p = program(source)

      draws = [
        {0, %{"a" => 1, "b" => 1}},
        {10, %{}},
        {25, %{"b" => 0}},
        {60, %{"b" => 1}},
        {90, %{}}
      ]

      Enum.reduce(draws, Runtime.instance(p), fn {now, inputs}, state ->
        {_outputs, state} = Runtime.call(p, state, inputs, %Scan{now: now, first: state.first})
        # Restated: each element is the very state its scalar twin, on the same rung, keeps.
        assert element(state, "lane_t", 0) == state.env["t0"]
        assert element(state, "lane_t", 1) == state.env["t1"]
        assert element(state, "lane_t", 2) == ton(0, 0, 0, 0, 0, 0)
        state
      end)
    end

    test "an element of an array of pulse timers starts no pulse on a first scan, nor without a rising edge, as a scalar tp" do
      source =
        "var_input a bool\nvar horn tp[2]\nvar one tp\nxic a tp horn[1] 50\nxic a tp one 50"

      p = program(source)

      draws = [
        {0, %{"a" => 1}},
        {10, %{}},
        {20, %{"a" => 0}},
        {30, %{"a" => 1}},
        {40, %{}},
        {90, %{}}
      ]

      states =
        Enum.map_reduce(draws, Runtime.instance(p), fn {now, inputs}, state ->
          {_outputs, state} = Runtime.call(p, state, inputs, %Scan{now: now, first: state.first})
          # Restated: the element is the very state its scalar twin, on the same rung, keeps.
          assert element(state, "horn", 1) == state.env["one"]
          {element(state, "horn", 1)["tt"], state}
        end)
        |> elem(0)

      # A first scan's high rung pulses nothing; the edge at 30 pulses for 50 ms.
      assert states == [0, 0, 0, 1, 1, 0]
    end

    test "each element counts its own rising edges, never on a first scan, and stops at its type's limits" do
      source =
        "var_input a bool\nvar_input b bool\nvar_input r bool\nvar lane_c ctu_int[2]\n" <>
          "var down ctd_udint[2]\nxic a ctu lane_c[0] 2\nxic b ctu lane_c[1] 2\n" <>
          "xic r ote lane_c[1].r\nxic a ctd down[1] 0"

      p = program(source)

      {_, state} =
        run(p, [{0, %{"a" => 1, "b" => 0, "r" => 0}}, {10, %{"a" => 0}}, {20, %{"a" => 1}}])

      # The first scan's rising rung counts nothing; the second edge of `a` counts once.
      assert %{"cv" => 1, "q" => 0} = element(state, "lane_c", 0)
      assert %{"cv" => 0} = element(state, "lane_c", 1)
      assert %{"cv" => 0, "un" => 1, "q" => 1} = element(state, "down", 1)
      assert element(state, "down", 0)["un"] == 0

      {_, state} =
        run(
          p,
          [{30, %{"b" => 1}}, {40, %{"b" => 0}}, {50, %{"b" => 1}}],
          state
        )

      assert %{"cv" => 2, "q" => 1} = element(state, "lane_c", 1)
      # Its reset, written after its rung, resets it at its next run.
      {_, state} = run(p, [{60, %{"r" => 1}}, {65, %{}}], state)
      assert %{"cv" => 0, "q" => 0, "r" => 1} = element(state, "lane_c", 1)
      assert element(state, "lane_c", 0)["cv"] == 1

      # A typed counter's element stops at its type's top, 32767, `ov` latched.
      full =
        Map.put(
          state.env,
          "lane_c",
          put_elem(state.env["lane_c"], 0, %{element(state, "lane_c", 0) | "cv" => 32_767})
        )

      {_, state} = run(p, [{70, %{"a" => 0}}, {80, %{"a" => 1}}], %{state | env: full})
      assert %{"cv" => 32_767, "ov" => 1, "q" => 1} = element(state, "lane_c", 0)
    end

    test "a `cal` of an element runs its instance alone, its body over the element's own state" do
      source =
        "var_input a bool\nvar_input b bool\nvar_output q0 bool\nvar_output q1 bool\n" <>
          "var lanes seal[3]\ncal lanes[0] a q0\ncal lanes[2] b q1"

      p = program(source, [seal()])
      {outputs, state} = run(p, [{0, %{"a" => 1, "b" => 0}}, {40, %{}}])
      assert outputs == %{"q0" => 1, "q1" => 0}

      assert %{"s" => 1, "q" => 1, "e" => 1, "t" => %{"acc" => 30, "dn" => 1}} =
               element(state, "lanes", 0)

      # `lanes[1]` no `cal` runs, and `lanes[2]`'s body ran on a false input.
      assert element(state, "lanes", 1) == Logex.FbType.initial(seal())
      assert %{"s" => 0, "e" => 0, "t" => %{"en" => 0, "last" => 40}} = element(state, "lanes", 2)

      # A false `cal` runs nothing: its element and every output it fills keep their values.
      p = program(source <> "\nxic b cal lanes[1] a q1", [seal()])
      {_outputs, state} = run(p, [{0, %{"a" => 1, "b" => 0}}, {40, %{}}])
      assert element(state, "lanes", 1) == Logex.FbType.initial(seal())
    end

    test "a fault in an element's body is placed at the element, by its path, in its body's file" do
      blk = "function_block bad\nvar_input s dint\nvar_output q dint\ndiv 10 s q\n"
      {:ok, bad} = Logex.compile(blk, name: "bad")

      p =
        program("var_input z dint\nvar_output q dint\nvar lanes bad[2]\ncal lanes[1] z q", [bad])

      {_outputs, state} = run(p, [{0, %{"z" => 0}}])

      assert state.faults == [
               %Fault{
                 severity: :minor,
                 kind: :divide_by_zero,
                 instruction: :div,
                 path: "lanes[1]",
                 file: nil,
                 line: 4,
                 read: nil
               }
             ]
    end

    test "a block holding arrays of instances runs each element of its own, at depth" do
      blk =
        "function_block bank\nvar_input s bool\nvar_input k dint\nvar_output q bool\n" <>
          "var t ton[2]\nvar c ctu[2]\nxic s ton t[1] 10\nxic s ctu c[0] 3\nxic t[k].dn ote q\n"

      {:ok, bank} = Logex.compile(blk, name: "bank")

      p =
        program(
          "var_input s bool\nvar_input k dint\nvar_output q bool\nvar banks bank[2]\ncal banks[1] s k q",
          [bank]
        )

      {outputs, state} = run(p, [{0, %{"s" => 1, "k" => 1}}, {10, %{}}])
      assert outputs == %{"q" => 1}
      inner = element(state, "banks", 1)
      assert elem(inner["t"], 1) == ton(10, 10, 1, 0, 1, 10)
      assert elem(inner["c"], 0)["pv"] == 3
      assert element(state, "banks", 0) == Logex.FbType.initial(bank)

      # The index fault inside the body is placed at the element that ran it.
      {outputs, state} = run(p, [{20, %{"k" => 2}}], state)
      assert outputs == %{"q" => 0}
      assert state.faults == [fault(:xic, 9, [2], "banks[1]")]
    end
  end

  describe "the index fault (decision 153) of a member through a tag subscript" do
    @fault "var_input go bool\nvar_input slot dint\nvar_output q bool\nvar_output n dint\n" <>
             "var lane_t ton[3]\nvar lane_c ctu[3]\n"

    test "an instruction whose element is outside its dimension does nothing, passes no power and records the major fault with the subscript read" do
      p =
        program(
          @fault <>
            "xic go ton lane_t[1] 20\nxic lane_t[slot].dn ote q\nxic go move lane_t[slot].acc n\n" <>
            "xic go move 7 lane_c[slot].pv\nxic go move 3 n"
        )

      {outputs, state} = run(p, [{0, %{"go" => 1, "slot" => 3}}])
      # The contact passes no power, so `ote q` writes 0; the moves write nothing; the rung
      # after each runs on.
      assert outputs == %{"q" => 0, "n" => 3}
      assert Enum.map(0..2, &element(state, "lane_c", &1)["pv"]) == [0, 0, 0]
      assert state.faults == [fault(:xic, 8, [3]), fault(:move, 9, [3]), fault(:move, 10, [3])]

      {_outputs, state} = run(p, [{0, %{"go" => 1, "slot" => -1}}])
      assert state.faults == [fault(:xic, 8, [-1]), fault(:move, 9, [-1]), fault(:move, 10, [-1])]
    end

    test "a de-energised instruction that reads and writes nothing, a rung a jump skips and a block whose `cal` is false check nothing" do
      p =
        program(
          @fault <>
            "xic go move 7 lane_c[slot].pv\nxio go jmp past\nxic lane_t[slot].dn ote q\n" <>
            "lbl past xio go ote n.0"
        )

      {_outputs, state} = run(p, [{0, %{"go" => 0, "slot" => 9}}])
      assert state.faults == []

      blk =
        "function_block reader\nvar_input k dint\nvar_output q bool\nvar t ton[2]\nxic t[k].dn ote q\n"

      {:ok, reader} = Logex.compile(blk, name: "reader")

      p =
        program(
          "var_input go bool\nvar_input k dint\nvar_output q bool\nvar r reader[1]\nxic go cal r[0] k q",
          [reader]
        )

      {_outputs, state} = run(p, [{0, %{"go" => 0, "k" => 5}}])
      assert state.faults == []
      {_outputs, state} = run(p, [{0, %{"go" => 1, "k" => 5}}])
      assert state.faults == [fault(:xic, 5, [5], "r[0]")]
    end

    test "a member through a tag subscript as any of an instruction's first three operands is checked, nothing escaping" do
      p =
        program(
          @fault <>
            "var_input x dint\nxic go add lane_c[slot].pv 1 n\nxic go add x lane_c[slot].pv n\n" <>
            "xic go add x 1 lane_c[slot].pv\nxic go and x 3 lane_c[slot].pv\n" <>
            "xic go shl x 1 lane_c[slot].pv\nxic go move 3 n"
        )

      {outputs, state} = run(p, [{0, %{"go" => 1, "slot" => 5, "x" => 1}}])
      assert outputs == %{"q" => 0, "n" => 3}
      assert Enum.map(0..2, &element(state, "lane_c", &1)["pv"]) == [0, 0, 0]

      assert state.faults == [
               fault(:add, 8, [5]),
               fault(:add, 9, [5]),
               fault(:add, 10, [5]),
               fault(:and, 11, [5]),
               fault(:shl, 12, [5])
             ]

      {_outputs, state} = run(p, [{0, %{"go" => 1, "slot" => 2, "x" => 1}}])
      assert state.faults == []
      assert element(state, "lane_c", 2)["pv"] == 2
    end

    test "an element of two dimensions is checked subscript by subscript, every subscript read" do
      p =
        program(
          "var_input i dint\nvar_input j dint\nvar_output q bool\nvar grid tp[2,3]\n" <>
            "xic grid[i,j].tt ote q"
        )

      {_outputs, state} = run(p, [{0, %{"i" => 1, "j" => 3}}])
      assert state.faults == [fault(:xic, 5, [1, 3])]
      {_outputs, state} = run(p, [{0, %{"i" => 1, "j" => 2}}])
      assert state.faults == []
    end
  end

  describe "the long and typed variants (decisions 158 and 154)" do
    test "an element of an array of long timers times in nanoseconds, a millisecond adding 1,000,000" do
      p =
        program(
          "var_input go bool\nvar_output q bool\nvar cure ton_ltime[2]\nvar press tof_ltime[2]\n" <>
            "xic go ton cure[1] 3000000\nxic go tof press[0] 2000000\nxic cure[1].dn ote q"
        )

      assert p.units == %{"cure" => 1_000_000, "press" => 1_000_000}
      {outputs, state} = run(p, [{0, %{"go" => 1}}, {2, %{}}])
      assert outputs == %{"q" => 0}
      assert element(state, "cure", 1)["acc"] == 2_000_000
      {outputs, state} = run(p, [{3, %{}}, {4, %{"go" => 0}}, {5, %{}}], state)
      assert outputs == %{"q" => 0}
      assert %{"acc" => 1_000_000, "dn" => 1} = element(state, "press", 0)
      {_outputs, state} = run(p, [{6, %{}}], state)
      assert %{"acc" => 2_000_000, "dn" => 0} = element(state, "press", 0)
    end

    test "a typed counter's element takes a preset of its type and counts in its width" do
      assert messages("var_input go bool\nvar c ctu_int[2]\nxic go ctu c[0] 32768") == [
               {3, "`ctu` takes a preset of -32768 to 32767 for a counter of ints, found `32768`"}
             ]

      p = program("var_input go bool\nvar c ctd_int[2]\nxic go ctd c[1] -5")
      assert element(Runtime.instance(p), "c", 1)["pv"] == -5
    end
  end

  describe "an online edit (decisions 32, 87, 106 and 157)" do
    @lanes "var_input go bool\nvar_input k dint\nvar_output lamp bool\nvar lane_t ton[4]\n" <>
             "var lane_c ctu[2]\n"

    defp accept!(running, candidate, state) do
      {:ok, edit, _forecast} = Edit.accept(running, candidate, state)
      edit
    end

    test "an element's timer moves its preset, and resumes, by its path `lane_t[2]`" do
      b1 = program(@lanes <> "xic go ton lane_t[2] 5000\nxic lane_t[2].dn ote lamp")
      b2 = program(@lanes <> "xic lane_t[2].dn ote lamp")
      {_, state} = run(b1, [{0, %{"go" => 1}}, {990, %{}}])
      assert %{"acc" => 990, "en" => 1} = element(state, "lane_t", 2)
      edit = accept!(b1, b2, state)
      {edit, state, []} = Edit.test(edit, state)
      {_, state} = Enum.reduce(1..58, {nil, state}, fn _, {_, s} -> Runtime.scan(b2, s, 1000) end)
      {_edit, state, report} = Edit.untest(edit, state)
      assert report == [{:resumed, "lane_t[2]", 58_000}]
      assert element(state, "lane_t", 2)["last"] == state.now
      {%{"lamp" => 0}, state} = Runtime.scan(b1, state, 10)
      assert %{"acc" => 1000, "dn" => 0} = element(state, "lane_t", 2)

      b3 = program(@lanes <> "xic go ton lane_t[2] 8000\nxic lane_t[2].dn ote lamp")
      {_edit, state, report} = Edit.test(accept!(b1, b3, state), state)
      assert report == [{:preset, "lane_t[2]", {5000, 8000}}]
      assert element(state, "lane_t", 2)["pre"] == 8000
      assert Enum.map([0, 1, 3], &element(state, "lane_t", &1)["pre"]) == [0, 0, 0]
    end

    test "a counter's edge memory on an element is on the block list by its path, until a scan runs it" do
      b1 = program(@lanes <> "xic go ctu lane_c[1] 3")
      b2 = program(@lanes <> "xic go xic go ctu lane_c[1] 3")
      {_, state} = run(b1, [{0, %{"go" => 0}}, {10, %{}}])
      {edit, state, report} = Edit.test(accept!(b1, b2, state), state)
      assert report == [{:ons_blocked, "lane_c[1].cu", 0}]
      assert state.ons_blocked == ["lane_c[1].cu"]
      # The rising rung its next scan finds counts no edge, and the scan drops the block.
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 1}), 10)
      assert %{"cv" => 0, "cu" => 1} = element(state, "lane_c", 1)
      assert state.ons_blocked == []
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 0}), 10)
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 1}), 10)
      assert element(state, "lane_c", 1)["cv"] == 1
      assert {^b2, _state, []} = Edit.assemble(edit, state)
    end

    test "a memory blocked on a rung a jump skips stays listed until a scan runs its instruction" do
      b1 = program(@lanes <> "xic go ctu lane_c[0] 3")

      b2 =
        program(
          @lanes <> "xic k.0 jmp past\nxio lamp xic go ctu lane_c[0] 3\nlbl past xic go ote lamp"
        )

      {_, state} = run(b1, [{0, %{"go" => 0, "k" => 1}}])
      {_edit, state, _} = Edit.test(accept!(b1, b2, state), state)
      assert state.ons_blocked == ["lane_c[0].cu"]
      {_, state} = Runtime.scan(b2, state, 10)
      assert state.ons_blocked == ["lane_c[0].cu"]
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"k" => 0}), 10)
      assert state.ons_blocked == []
    end

    test "a ctud element's two sides are each kept by its own rung, one skipped and one run" do
      b1 = program(@lanes <> "var both ctud[2]\nxic go ctu both[1] 3\nxic go ctd both[1] 3")

      b2 =
        program(
          @lanes <>
            "var both ctud[2]\nxic k.0 jmp past\nxio lamp xic go ctu both[1] 3\n" <>
            "lbl past xic go ctd both[1] 3"
        )

      {_, state} = run(b1, [{0, %{"go" => 0, "k" => 1}}])
      {_edit, state, _} = Edit.test(accept!(b1, b2, state), state)
      assert state.ons_blocked == ["both[1].cd", "both[1].cu"]
      # The skipped `ctu` keeps its side blocked; the `ctd` that ran used its own up.
      {_, state} = Runtime.scan(b2, state, 10)
      assert state.ons_blocked == ["both[1].cu"]
    end

    test "an array of timers a plain swap left over counters does not fit, and starts again at the first test (decision 26)" do
      v0 = program("var_input go bool\nvar t ctu[2]\nxic go ctu t[0] 3")
      v1 = program("var_input go bool\nvar t ton[2]\nxic go move 40 t[0].pre")

      v2 =
        program("var_input go bool\nvar t ton[2]\nxic go move 40 t[0].pre\nxic go ton t[0] 300")

      {_, state} = run(v0, [{0, %{"go" => 1}}])
      {_, state} = Runtime.scan(v1, state, 10)
      assert Map.has_key?(element(state, "t", 0), "cu")
      {:ok, edit, forecast} = Edit.accept(v1, v2, state)
      {_edit, state, report} = Edit.test(edit, state)
      assert report == forecast
      assert [{:added, "t", _}] = report
      assert %{"pre" => 300, "acc" => 0, "en" => 0} = element(state, "t", 0)
    end

    test "a pulse timer's edge memory on an element is on the block list by its path, `horn[1].en`" do
      b1 = program(@lanes <> "var horn tp[2]\nxic go tp horn[1] 50")
      b2 = program(@lanes <> "var horn tp[2]\nxic go xic go tp horn[1] 50")
      {_, state} = run(b1, [{0, %{"go" => 0}}, {10, %{}}])
      {_edit, state, report} = Edit.test(accept!(b1, b2, state), state)
      assert report == [{:ons_blocked, "horn[1].en", 0}]
      # The rising rung its next scan finds starts no pulse, and the scan drops the block.
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 1}), 10)
      assert %{"tt" => 0, "en" => 1} = element(state, "horn", 1)
      assert state.ons_blocked == []
    end

    test "a one-shot in an element of an array of user blocks is blocked by its path, `lanes[1].e`" do
      blk2 = String.replace(@seal, "xic s ons e", "xic s xic s ons e")
      {:ok, seal2} = Logex.compile(blk2, name: "seal")
      source = @lanes <> "var lanes seal[2]\ncal lanes[1] go lamp\ncal lanes[0] go lamp"
      b1 = program(source, [seal()])
      b2 = program(source, [seal2])
      {_, state} = run(b1, [{0, %{"go" => 0}}])
      {_edit, _state, report} = Edit.test(accept!(b1, b2, state), state)

      assert Enum.filter(report, &match?({:ons_blocked, _, _}, &1)) ==
               [{:ons_blocked, "lanes[0].e", 0}, {:ons_blocked, "lanes[1].e", 0}]
    end

    test "a one-shot blocked in an element of user blocks passes no power at its next run, as a scalar instance's, and the scan that runs it drops the block" do
      shot = "function_block shot\nvar_input s bool\nvar_output q bool\nvar e bool\n"
      {:ok, v1} = Logex.compile(shot <> "xic s ons e ote q\n", name: "shot")
      {:ok, v2} = Logex.compile(shot <> "xic s xic s ons e ote q\n", name: "shot")

      source =
        "var_input go bool\nvar_input a bool\nvar_output q bool\nvar_output q1 bool\n" <>
          "var l shot[2]\nvar one shot\nxic go cal l[1] a q\nxic go cal one a q1"

      b1 = program(source, [v1])
      b2 = program(source, [v2])
      {_, state} = run(b1, [{0, %{"go" => 1, "a" => 0}}])
      {_edit, state, report} = Edit.test(accept!(b1, b2, state), state)

      assert Enum.filter(report, &match?({:ons_blocked, _, _}, &1)) ==
               [{:ons_blocked, "l[1].e", 0}, {:ons_blocked, "one.e", 0}]

      # A scan whose `cal` is false keeps both blocks; the rising rung of the next scan that
      # runs the body passes no power, and that scan drops each block.
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 0, "a" => 1}), 10)
      assert Enum.sort(state.ons_blocked) == ["l[1].e", "one.e"]
      {outputs, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"go" => 1}), 20)
      assert outputs == %{"q" => 0, "q1" => 0}
      assert state.ons_blocked == []
      # Its next rising edge fires, the element's as its twin's.
      {_, state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"a" => 0}), 30)
      {outputs, _state} = Runtime.scan(b2, Runtime.put_inputs(b2, state, %{"a" => 1}), 40)
      assert outputs == %{"q" => 1, "q1" => 1}
    end

    # M5-14's review: each element of an array of user blocks is migrated member by member,
    # a member the candidate's version adds started and reported by the element's path,
    # and pruned by it when the edit is cancelled, as a scalar instance's is.
    test "a member a block's new version adds starts in each element of its array, and a cancel prunes it" do
      shot = "function_block shot\nvar_input s bool\nvar_output q bool\nvar e bool\n"
      {:ok, v1} = Logex.compile(shot <> "xic s ons e ote q\n", name: "shot")

      {:ok, v2} =
        Logex.compile(shot <> "var n dint 7\nxic s ons e ote q\nxic s move 3 n\n",
          name: "shot"
        )

      source =
        "var_input go bool\nvar_output q bool\nvar_output q1 bool\nvar l shot[2]\n" <>
          "var one shot\nxic go cal l[1] go q\nxic go cal one go q1"

      b1 = program(source, [v1])
      b2 = program(source, [v2])
      {_, state} = run(b1, [{0, %{"go" => 1}}])
      {edit, state, report} = Edit.test(accept!(b1, b2, state), state)

      assert Enum.filter(report, &match?({:added, _, _}, &1)) ==
               [{:added, "l[0].n", 7}, {:added, "l[1].n", 7}, {:added, "one.n", 7}]

      assert element(state, "l", 1)["n"] == 7
      assert element(state, "l", 0)["n"] == 7
      {edit, state, _report} = Edit.untest(edit, state)
      {_edit, state, report} = Edit.cancel(edit, state)

      assert Enum.filter(report, &match?({:pruned, _, _}, &1)) ==
               [{:pruned, "l[0].n", 7}, {:pruned, "l[1].n", 7}, {:pruned, "one.n", 7}]

      refute Map.has_key?(element(state, "l", 1), "n")
      refute Map.has_key?(state.env["one"], "n")
    end

    test "a timer inside a block's array of instances resumes by its path, `s1.t[1]`" do
      inner = "function_block bank\nvar_input s bool\nvar_output q bool\nvar t ton[2]\n"
      {:ok, v1} = Logex.compile(inner <> "xic s ton t[1] 5000\nxic t[1].dn ote q\n", name: "bank")
      {:ok, v2} = Logex.compile(inner <> "xic t[1].dn ote q\n", name: "bank")
      outer = "var_input go bool\nvar_output lamp bool\nvar s1 bank\ncal s1 go lamp"
      b1 = program(outer, [v1])
      b2 = program(outer, [v2])
      {_, state} = run(b1, [{0, %{"go" => 1}}, {100, %{}}])
      {edit, state, []} = Edit.test(accept!(b1, b2, state), state)
      {_, state} = Runtime.scan(b2, state, 500)
      {_edit, _state, report} = Edit.untest(edit, state)
      assert report == [{:resumed, "s1.t[1]", 500}]
    end

    test "a member input the candidate no longer writes is reported by the element's path, a tag subscript's for each element" do
      b1 =
        program(
          @lanes <>
            "xic go ctu lane_c[1] 3\nxic go move 9 lane_c[1].pv\nxic go move 2 lane_c[k].pv"
        )

      b2 = program(@lanes <> "xic go ctu lane_c[1] 3")
      {_, state} = run(b1, [{0, %{"go" => 1, "k" => 0}}])
      {_edit, _state, report} = Edit.test(accept!(b1, b2, state), state)

      assert Enum.filter(report, &match?({:unwritten, _, _}, &1)) ==
               [{:unwritten, "lane_c[0].pv", 2}, {:unwritten, "lane_c[1].pv", 9}]
    end

    test "an array of instances changes its sizes or type only with a restart, a user block's elements by their members' kinds" do
      b1 = program(@lanes <> "xic go ton lane_t[2] 5000")
      state = Runtime.instance(b1)

      for {word, rung} <- [
            {"ton[5]", "xic go ton lane_t[2] 5000"},
            {"tof[4]", "xic go tof lane_t[2] 5000"},
            {"ton", "xic go ton lane_t 5000"}
          ] do
        b2 = program(String.replace(@lanes, "lane_t ton[4]", "lane_t #{word}") <> rung)
        assert {:error, [diagnostic]} = Edit.accept(b1, b2, state)
        assert diagnostic.message =~ "`lane_t` is an array of 4 tons in the running program and "
        assert diagnostic.message =~ "a tag's type changes only with a restart"
      end

      {:ok, w1} =
        Logex.compile(
          "function_block w\nvar_input s bool\nvar_output q bool\nvar x bool\nxic s ote x\nxic x ote q",
          name: "w"
        )

      {:ok, w2} =
        Logex.compile(
          "function_block w\nvar_input s bool\nvar_output q bool\nvar x dint\nxic s move 1 x\nxic s ote q",
          name: "w"
        )

      outer = "var_input go bool\nvar_output lamp bool\nvar ws w[3]\ncal ws[2] go lamp"
      p1 = program(outer, [w1])
      p2 = program(outer, [w2])

      assert {:error, [%{message: message}]} = Edit.accept(p1, p2, Runtime.instance(p1))

      # Decision 254, superseding M5-14's provisional reading, which cited it by the first
      # element's path, `ws[0].x`: once, for the array; since decision 259 by one path, its
      # subscripts `[*]`, where decision 254 cited "`x` of every element of `ws`".
      assert message ==
               "`ws[*].x` is a bool in the running program and a dint in the candidate, in " <>
                 "every element: a member's type changes only with a restart"

      # So in a block's instance, by its path, and in an array of blocks that hold one, by
      # one path through both arrays (decision 259), each cited once.
      holder = fn w ->
        {:ok, h} =
          Logex.compile(
            "function_block h\nvar_input s bool\nvar_output q bool\nvar ws w[2]\ncal ws[1] s q",
            name: "h",
            types: [w]
          )

        h
      end

      held =
        "var_input go bool\nvar_output lamp bool\nvar b h\nvar hs h[2]\n" <>
          "cal b go lamp\ncal hs[0] go lamp"

      h1 = holder.(w1)
      h2 = holder.(w2)

      assert {:error, diagnostics} =
               Edit.accept(
                 program(held, [h1]),
                 program(held, [h2]),
                 Runtime.instance(program(held, [h1]))
               )

      assert Enum.map(diagnostics, &{&1.line, &1.message}) == [
               {3,
                "`b.ws[*].x` is a bool in the running program and a dint in the candidate, in " <>
                  "every element: a member's type changes only with a restart"},
               {4,
                "`hs[*].ws[*].x` is a bool in the running program and a dint in the " <>
                  "candidate, in every element: a member's type changes only with a restart"}
             ]

      # A body changed with its members' kinds kept is no type change.
      {:ok, w3} =
        Logex.compile(
          "function_block w\nvar_input s bool\nvar_output q bool\nvar x bool\nxio s ote x\nxic x ote q",
          name: "w"
        )

      assert {:ok, _edit, _} = Edit.accept(p1, program(outer, [w3]), Runtime.instance(p1))
    end

    test "an element the candidate adds a ton for takes its preset outright, and an array the candidate adds starts whole" do
      b1 = program(@lanes <> "xic go ton lane_t[2] 5000")
      b2 = program(@lanes <> "xic go ton lane_t[2] 5000\nxic go ton lane_t[0] 300")
      state = Runtime.instance(b1)
      {_edit, state, report} = Edit.test(accept!(b1, b2, state), state)
      assert report == [{:preset, "lane_t[0]", {0, 300}}]
      assert element(state, "lane_t", 0)["pre"] == 300

      b3 = program(@lanes <> "var more ctud[2]\nxic go ton lane_t[2] 5000\nxic go ctu more[1] 4")

      {_edit, state, report} =
        Edit.test(accept!(b1, b3, Runtime.instance(b1)), Runtime.instance(b1))

      # Its counter's edge memory is blocked, as a counter's the edit adds is.
      assert [{:added, "more", [_, %{"pv" => 4}]}, {:ons_blocked, "more[1].cu", 0}] = report
      assert element(state, "more", 1)["pv"] == 4
    end
  end

  describe "the warnings" do
    test "an array of instances is told the elements no instruction runs, in the elements' order, ten and then a count" do
      source =
        "var_input go bool\nvar_output q bool\nvar lane_t ton[4]\nvar lane_c ctu[12]\n" <>
          "var lanes seal[3]\nvar grid tp[2,2]\nvar idle ton[2]\nvar unused ctud[2]\n" <>
          "xic go ton lane_t[2] 500\nxic go ctu lane_c[1] 5\ncal lanes[1] go q\n" <>
          "xic grid[0,1].dn ote q\nxic go tp grid[1,1] 5"

      assert warnings(source, [seal()]) ==
               [
                 {3,
                  "`lane_t` is an array of 4 tons, but no `ton` runs `lane_t[0]`, `lane_t[1]` or " <>
                    "`lane_t[3]`: they never time"},
                 {4,
                  "`lane_c` is an array of 12 ctus, but no `ctu` runs `lane_c[0]`, `lane_c[2]`, " <>
                    "`lane_c[3]`, `lane_c[4]`, `lane_c[5]`, `lane_c[6]`, `lane_c[7]`, " <>
                    "`lane_c[8]`, `lane_c[9]`, `lane_c[10]` or 1 more: they never count"},
                 {5,
                  "`lanes` is an array of 3 instances of `seal`, but no `cal` runs `lanes[0]` or " <>
                    "`lanes[2]`: they never run, and their members stay at their initial values"},
                 {6,
                  "`grid` is an array of 2 by 2 tps, but no `tp` runs `grid[0,0]`, `grid[0,1]` or `grid[1,0]`: they never time"},
                 {7, "`idle` is declared but no rung uses it"},
                 {8, "`unused` is declared but no rung uses it"}
               ]

      assert warnings(
               "var_input go bool\nvar_output q bool\nvar both ctud[1]\nxic both[0].qu xic go ote q"
             ) ==
               [
                 {3,
                  "`both` is an array of 1 ctud, but no `ctu` or `ctd` runs any of its elements: it never counts"}
               ]
    end

    test "a long timer's element is told a preset that is no whole number of milliseconds, and a literal beside its `.acc`" do
      assert warnings(
               "var_input go bool\nvar_output q bool\nvar cure ton_ltime[1]\n" <>
                 "xic go ton cure[0] 1500000\nge cure[0].acc 3000 ote q"
             ) == [
               {4,
                "`ton` gives `cure[0]` a preset of 1500000 ns, which is no whole number of " <>
                  "milliseconds: a ton_ltime counts whole milliseconds, so it times as the " <>
                  "next whole millisecond, 2 ms"},
               {5,
                "`ge` compares `cure[0].acc` with `3000`, where `cure[0].acc` is a " <>
                  "ton_ltime's time in nanoseconds: 3000 ns is no whole number of " <>
                  "milliseconds, and a ton_ltime counts whole milliseconds"}
             ]
    end

    test "a second coil on a member of an element is the second-`ote` warning, by its path, through the very tags" do
      source =
        "var_input go bool\nvar_input i dint\nvar_output q bool\nvar lane_c ctu[2]\n" <>
          "xic go ctu lane_c[0] 1\nxic go ctu lane_c[1] 1\nxic lane_c[0].q ote q\n"

      assert warnings(source <> "xic go ote lane_c[1].r\nxio go ote lane_c[01].r") == [
               {2, "`i` is declared but no rung uses it"},
               {9,
                "`lane_c[01].r` already has an `ote` on line 8: the last one in the scan decides it"}
             ]

      assert warnings(source <> "xic go ote lane_c[i].r\nxio go ote lane_c[i].r") == [
               {9,
                "`lane_c[i].r` already has an `ote` on line 8: the last one in the scan decides it"}
             ]

      # Decision 253, superseding M5-14's provisional reading that a literal element's
      # member beside one through a tag subscript is not compared: they are, as decision 235
      # compares a bool array's elements, either first.
      assert warnings(source <> "xic go ote lane_c[i].r\nxio go ote lane_c[1].r") == [
               {9,
                "`lane_c[1].r` is in `lane_c`, which the `ote` on line 8 may write through a " <>
                  "tag subscript: the last one in the scan decides it"}
             ]

      assert warnings(source <> "xic go ote lane_c[1].r\nxio go ote lane_c[i].r") == [
               {9,
                "`lane_c[i].r` is in `lane_c`, as `lane_c[1].r` is, which already has an `ote` " <>
                  "on line 8: the last one in the scan decides it"}
             ]
    end

    # Decision 253: any write of a member through a tag subscript beside a coil on that
    # member of a literal element, and a write of a literal element's member beside a coil
    # through a tag subscript, either first, is the second-`ote` warning, as for a bool
    # array's element (decision 235); the very member through the very tags is warned of
    # nothing (decision 246), and through other tags it is.
    test "a member through a tag subscript and a literal element's member compared, as a bool array's elements" do
      source =
        "var_input go bool\nvar_input i dint\nvar_input j dint\nvar_output q bool\n" <>
          "var_output p bool\nvar lane_c ctud[2]\nxic go ctu lane_c[0] 1\n" <>
          "xic go ctu lane_c[1] 1\nxic lane_c[0].qu ote q\nge i j ote p\n"

      may = fn shown, symbol ->
        "`#{shown}` is in `lane_c`, which the `#{symbol}` on line 11 may write through a tag " <>
          "subscript: the last one in the scan decides it"
      end

      as = fn shown ->
        "`#{shown}` is in `lane_c`, as `lane_c[1].r` is, which already has an `ote` on line " <>
          "11: the last one in the scan decides it"
      end

      for {rungs, expected} <- [
            {"xic go otl lane_c[i].r\nxio go ote lane_c[1].r",
             [{12, may.("lane_c[1].r", "otl")}]},
            {"xic go ote lane_c[1].r\nxio go otl lane_c[i].r", [{12, as.("lane_c[i].r")}]},
            {"xic go ote lane_c[i].r\nxio go otl lane_c[1].r",
             [{12, may.("lane_c[1].r", "ote")}]},
            {"xic go otl lane_c[1].r\nxio go ote lane_c[i].r",
             [
               {12,
                "`lane_c[i].r` is in `lane_c`, as `lane_c[1].r` is, which the `otl` on line 11 " <>
                  "writes: the last one in the scan decides it"}
             ]},
            {"xic go ote lane_c[i].r\nxio go ote lane_c[j].r",
             [{12, may.("lane_c[j].r", "ote")}]},
            {"xic go ote lane_c[i].r\nxio go otl lane_c[j].r",
             [{12, may.("lane_c[j].r", "ote")}]},
            {"xic go ote lane_c[i].r\nxio go otl lane_c[i].r", []},
            {"xic go otl lane_c[i].r\nxio go ote lane_c[i].r", []},
            {"xic go otl lane_c[1].r\nxio go ote lane_c[1].r", []},
            {"xic go ote lane_c[i].r\nxio go ote lane_c[1].ld", []},
            {"xic go ote lane_c[i].ld\nxio go move 1 lane_c[0].r", []}
          ] do
        assert warnings(source <> rungs) == expected, rungs
      end
    end

    # Decision 257, superseding M5-14's provisional reading that a bit of a member of an
    # element is not compared: two coils on it, `ote lane_c[1].pv.3` twice, and a coil on it
    # beside a write of the member whole, are the second-`ote` warning, as on a scalar
    # instance's member's bit, `c.pv.3` (M5-8's review); and through a tag subscript in
    # decisions 253's and 256's words, the bit's number one more part of the member's path.
    test "a bit of a member of an element is compared as a scalar instance's member's bit, and through a tag subscript as a member" do
      source =
        "var_input go bool\nvar_input i dint\nvar_input j dint\nvar_output q bool\n" <>
          "var_output p bool\nvar lane_c ctu[2]\nvar c ctu\nxic go ctu lane_c[0] 1\n" <>
          "xic go ctu lane_c[1] 1\nxic go ctu c 1\nge i j ote p xic c.q ote q\n"

      last = "the last one in the scan decides it"

      may = fn shown, symbol ->
        "`#{shown}` is in `lane_c`, which the `#{symbol}` on line 12 may write through a tag " <>
          "subscript: #{last}"
      end

      as = fn shown ->
        "`#{shown}` is in `lane_c`, as `lane_c[1].pv.3` is, which already has an `ote` on " <>
          "line 12: #{last}"
      end

      for {rungs, expected} <- [
            # The scalar twin, as M5-8's review built it.
            {"xic go ote c.pv.3\nxio go ote c.pv.3",
             [{13, "`c.pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go move 5 c.pv\nxio go ote c.pv.3",
             [
               {13,
                "`c.pv.3` is a bit of `c.pv`, which the `move` on line 12 writes whole: #{last}"}
             ]},
            # A literal element's, by its path, the bit keyed by its number's value.
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[1].pv.3",
             [{13, "`lane_c[1].pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[01].pv.03",
             [{13, "`lane_c[01].pv.03` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.3\nxio go move 5 lane_c[1].pv",
             [{13, "`lane_c[1].pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go move 5 lane_c[1].pv\nxio go ote lane_c[1].pv.3",
             [
               {13,
                "`lane_c[1].pv.3` is a bit of `lane_c[1].pv`, which the `move` on line 12 " <>
                  "writes whole: #{last}"}
             ]},
            # Through a tag subscript: the very tags "already has", other tags "may".
            {"xic go ote lane_c[i].pv.3\nxio go ote lane_c[i].pv.3",
             [{13, "`lane_c[i].pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[i].pv.3\nxio go ote lane_c[j].pv.3",
             [{13, may.("lane_c[j].pv.3", "ote")}]},
            {"xic go ote lane_c[i].pv.3\nxio go otl lane_c[j].pv.3",
             [{13, may.("lane_c[j].pv.3", "ote")}]},
            {"xic go ote lane_c[i].pv.3\nxio go otl lane_c[i].pv.3", []},
            {"xic go otl lane_c[i].pv.3\nxio go ote lane_c[i].pv.3", []},
            # A literal element's beside one through a tag subscript, either first.
            {"xic go ote lane_c[i].pv.3\nxio go ote lane_c[1].pv.3",
             [{13, may.("lane_c[1].pv.3", "ote")}]},
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[i].pv.3",
             [{13, as.("lane_c[i].pv.3")}]},
            {"xic go ote lane_c[1].pv.3\nxio go otl lane_c[i].pv.3",
             [{13, as.("lane_c[i].pv.3")}]},
            {"xic go otl lane_c[i].pv.3\nxio go ote lane_c[1].pv.3",
             [{13, may.("lane_c[1].pv.3", "otl")}]},
            {"xic go ote lane_c[i].pv.3\nxio go otl lane_c[1].pv.3",
             [{13, may.("lane_c[1].pv.3", "ote")}]},
            {"xic go otl lane_c[1].pv.3\nxio go ote lane_c[i].pv.3",
             [
               {13,
                "`lane_c[i].pv.3` is in `lane_c`, as `lane_c[1].pv.3` is, which the `otl` on " <>
                  "line 12 writes: #{last}"}
             ]},
            # A write of a literal element's bit beside its own coil, as a member's, nothing;
            # another bit, another element or a member of another name, nothing.
            {"xic go ote lane_c[1].pv.3\nxio go otl lane_c[1].pv.3", []},
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[1].pv.4", []},
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[0].pv.3", []},
            {"xic go ote lane_c[i].pv.3\nxio go ote lane_c[i].pv.4", []},
            {"xic go ote lane_c[i].pv.3\nxio go ote lane_c[1].r", []},
            # A bit a tag numbers of a literal element's member, `lane_c[1].pv.[i]`, keyed by
            # the member's path, as `c.pv.[n]` is by `c.pv` (M5-9).
            {"xic go ote c.pv.3\nxio go ote c.pv.[i]",
             [{13, "`c.pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.3\nxio go ote lane_c[1].pv.[i]",
             [{13, "`lane_c[1].pv.3` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.[i]\nxio go ote lane_c[1].pv.[j]",
             [{13, "`lane_c[1].pv.[j]` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.[i]\nxio go ote lane_c[1].pv.[i]",
             [{13, "`lane_c[1].pv.[i]` already has an `ote` on line 12: #{last}"}]},
            {"xic go ote lane_c[1].pv.[i]\nxio go otl lane_c[1].pv.[i]", []},
            {"xic go ote lane_c[1].pv.[i]\nxio go ote lane_c[0].pv.[i]", []},
            # Decision 288, superseding the provisional reading that left it uncompared: a
            # member's whole write beside a coil on its bit through a tag subscript, either
            # first, "may" where the write may come through a tag subscript (decision 257's
            # words; the whole write first "…writes whole"); through the very tags
            # nothing (decision 246). Still not compared (provisional): a whole write
            # through a tag subscript beside a coil on a literal element's bit.
            {"xic go move 5 lane_c[1].pv\nxio go ote lane_c[i].pv.3",
             [
               {13,
                "`lane_c[i].pv.3` is in `lane_c`, as `lane_c[1].pv` is, which the `move` on " <>
                  "line 12 writes whole: #{last}"}
             ]},
            {"xic go ote lane_c[i].pv.3\nxio go move 5 lane_c[1].pv",
             [{13, may.("lane_c[1].pv", "ote")}]},
            {"xic go move 5 lane_c[j].pv\nxio go ote lane_c[i].pv.3",
             [{13, may.("lane_c[i].pv.3", "move")}]},
            {"xic go ote lane_c[i].pv.3\nxio go move 5 lane_c[j].pv",
             [{13, may.("lane_c[j].pv", "ote")}]},
            {"xic go move 5 lane_c[0].pv\nxio go ote lane_c[i].pv.4",
             [
               {13,
                "`lane_c[i].pv.4` is in `lane_c`, as `lane_c[0].pv` is, which the `move` on " <>
                  "line 12 writes whole: #{last}"}
             ]},
            {"xic go ote lane_c[i].pv.3\nxio go move 5 lane_c[i].pv", []},
            {"xic go move 5 lane_c[i].pv\nxio go ote lane_c[i].pv.3", []},
            {"xic go ote lane_c[1].pv.3\nxio go move 5 lane_c[i].pv", []}
          ] do
        assert warnings(source <> rungs) == expected, rungs
      end
    end
  end

  describe "the walks (Logex.Walk)" do
    test "each element is a fact of its own by its path, a block's at depth, and a write of its array" do
      p =
        program(
          "var_input go bool\nvar_input k dint\nvar_output q bool\nvar lane_t tof[3]\n" <>
            "var lane_c ctud[2]\nvar lanes seal[2]\nxic go tof lane_t[16#2] 500\n" <>
            "xic go ctu lane_c[1] 4\nxio go ctd lane_c[1] 4\ncal lanes[1] go q\n" <>
            "xic go move 3 lane_c[k].pv\nxic go move 3 lane_c[0].pv",
          [seal()]
        )

      assert Walk.timers(p) == %{"lane_t[2]" => {7, 500}, "lanes[1].t" => {6, 30}}
      assert Walk.counters(p) == %{"lane_c[1]" => {8, 4}}
      assert Walk.one_shots(p) == %{"lanes[1].e" => {8, :ons}}
      assert Walk.writes(p)["lane_c"] == [8, 9, 11, 12]
      assert Walk.writes(p)["lanes"] == [10]

      assert Walk.member_writes(p) == %{
               "lane_c[0].pv" => [11, 12],
               "lane_c[1].pv" => [11]
             }

      assert Walk.element_writes(p)["lane_c[0]"] == [12]
      assert Walk.element_writes(p)["lane_c"] == [11]

      # A member through a tag subscript is a use of its array with its slot's access and
      # of the subscript's tag read.
      assert Enum.filter(
               Walk.uses(p.rungs, Logex.Program.typed_tags(p)),
               &match?({_, _, 11, :move}, &1)
             ) == [{:write, "lane_c", 11, :move}, {:read, "k", 11, :move}]
    end
  end

  describe "the host contract" do
    @hosted "var_input go bool\nvar_output q bool\nvar cure ton_ltime[2]\nvar c ctu_int[2]\n" <>
              "xic go ton cure[1] 3000000\nxic cure[1].dn ote q\nxic go add c[1].cv 1 c[1].pv"

    defp refused(program, state, inputs \\ %{}) do
      error =
        assert_raise ArgumentError, fn ->
          Runtime.call(program, state, inputs, %Scan{now: 0, first: true})
        end

      Exception.message(error)
    end

    test "a state's array of instances is held whole, a tuple of its sizes, each element its type's map, at depth for a block holding one" do
      p = program(@hosted)
      s = Runtime.instance(p)

      put = fn array, i, value ->
        %{s | env: Map.put(s.env, array, put_elem(s.env[array], i, value))}
      end

      assert refused(p, %{s | env: Map.delete(s.env, "cure")}) ==
               "state.env lacks `cure`: it is an array of 2 ton_ltimes, which a state holds " <>
                 "whole, as `Logex.Runtime.instance/1` makes it"

      assert refused(p, %{s | env: Map.put(s.env, "c", [1, 2])}) ==
               "state.env holds `c` outside its type: it is an array of 2 ctu_ints, and its " <>
                 "value must be a tuple of 2 elements, found [1, 2]"

      assert refused(p, put.("c", 0, %{elem(s.env["c"], 0) | "cv" => 40_000})) ==
               "state.env holds `c[0].cv` outside its type: it is an int, and 40000 is " <>
                 "outside -32768 to 32767"

      assert refused(p, put.("c", 1, 5)) ==
               "state.env holds `c[1]` outside its type: it is a ctu_int, and its value must " <>
                 "be a map of its members, found 5"

      assert refused(p, put.("cure", 1, %{elem(s.env["cure"], 1) | "last" => 5})) ==
               "state.env holds `cure[1].last` outside its type: it is a clock, and 5 is " <>
                 "later than the instance's now, 0"

      blk =
        "function_block bank\nvar_input s bool\nvar_output q bool\nvar t ton[2]\nxic s ton t[1] 10\nxic t[1].dn ote q\n"

      {:ok, bank} = Logex.compile(blk, name: "bank")

      deep =
        program("var_input s bool\nvar_output q bool\nvar banks bank[2]\ncal banks[1] s q", [bank])

      s = Runtime.instance(deep)
      inner = elem(s.env["banks"], 1)
      bad = %{inner | "t" => put_elem(inner["t"], 0, %{elem(inner["t"], 0) | "dn" => 2})}

      assert refused(deep, %{s | env: %{s.env | "banks" => put_elem(s.env["banks"], 1, bad)}}) ==
               "state.env holds `banks[1].t[0].dn` outside its type: it is a bool, and only 0 " <>
                 "or 1 fit, found 2"
    end

    test "an array of instances is no input, whole or by an element" do
      p = program(@hosted)

      assert refused(p, Runtime.instance(p), %{"cure" => 1}) ==
               "input `cure` is a var (declared on line 3), not a var_input: only a var_input " <>
                 "is set from outside"

      assert refused(p, Runtime.instance(p), %{"cure[1]" => 1}) ==
               "input \"cure[1]\" names an element of `cure`, a var (declared on line 3), not a " <>
                 "var_input: only a var_input is set from outside"
    end

    test "a program edited by hand after it compiled is refused where it is handed in" do
      p = program(@hosted)

      assert_raise ArgumentError,
                   "`p`'s units give `cure` no unit, where each element of an array of 2 " <>
                     "ton_ltimes adds 1000000 to its `acc` each millisecond: `p` was edited by " <>
                     "hand after it compiled",
                   fn -> Runtime.instance(%{p | units: nil}) end

      retyped = %{
        p
        | tags: Map.put(p.tags, "c", %{p.tags["c"] | type: {:array, Logex.FbType.ton(), [2]}})
      }

      assert_raise ArgumentError,
                   "`p`'s `add` on line 7 computes in the type of `c[1].pv`, and a ton has no " <>
                     "`pv`: `p` was edited by hand after it compiled",
                   fn -> Runtime.instance(retyped) end
    end

    test "a block holding an array of instances is the type its source compiles to, and its body a compiled body" do
      blk =
        "function_block bank\nvar_input s bool\nvar_input k dint\nvar_output q bool\nvar t ton[2]\nvar c ctud[2]\n" <>
          "xic s ton t[1] 10\nxic s ctu c[0] 3\nxic s ctd c[0] 3\nxic t[k].dn ote q\n"

      {:ok, bank} = Logex.compile(blk, name: "bank")
      assert Logex.FbType.user?(bank)
      assert Logex.Compiler.lowered?(bank.body)

      refute Logex.FbType.user?(%{
               bank
               | body: %{bank.body | tags: Map.delete(bank.body.tags, "c")}
             })

      # A preset edited by hand is no compiled body's.
      [t | _] = for %{name: "t"} = m <- bank.members, do: m

      edited = %{
        bank.body
        | tags: %{
            bank.body.tags
            | "t" => %{bank.body.tags["t"] | initial: %{[1] => %{"pre" => 11}}}
          }
      }

      refute Logex.Compiler.lowered?(edited)
      assert t.initial == %{[1] => %{"pre" => 10}}
    end
  end

  describe "a configuration (decision 154)" do
    @plant "var_input go bool\nvar_input k dint\nvar_output q bool\nvar lane_t ton[2]\n" <>
             "var lane_c ctu[2]\nvar lanes seal[2]\nxic go ton lane_t[1] 20\nxic go ctu lane_c[0] 2\n" <>
             "cal lanes[1] go q\nxic lane_t[k].dn ote q"

    test "an array of instances is never a global, a connection or located" do
      m = program(@plant, [seal()], "m")

      base =
        "var_global g bool\ntask t interval 10 priority 1\nprogram m1 m with t\nm1.go g\nm1.k 1\n"

      refusals = fn text ->
        {:error, diagnostics} = Logex.Configuration.compile("c", text, %{"m" => m})
        Enum.map(diagnostics, & &1.message)
      end

      assert refusals.("var_global w ton[2]\n" <> base) == [
               "`w` cannot be an array of tons, `ton[2]`: a global array's type is `bool`, " <>
                 "`sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, " <>
                 "`lreal`, `byte`, `word`, `dword` or `lword` with its sizes, and an array of " <>
                 "tons is declared inside a program, as in `var w ton[2]`"
             ]

      assert refusals.("var_global w ton[2] at card.i.0\n" <> base) == [
               "`w` cannot be an array of tons, `ton[2]`: a global array's type is `bool`, " <>
                 "`sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, " <>
                 "`lreal`, `byte`, `word`, `dword` or `lword` with its sizes, and an array of " <>
                 "tons is declared inside a program, as in `var w ton[2]`"
             ]

      assert refusals.(base <> "m1.lane_t g\n") == [
               "`m1.lane_t` is internal to `m` (declared `var`): only a var_input or var_output connects"
             ]

      assert refusals.(base <> "m1.lane_t[1].pre g\n") == [
               "`m1.lane_t[1].pre` goes too deep: a connection names an instance's var_input " <>
                 "or var_output, as in `m1.start`"
             ]
    end

    test "an event task's timer, counter and one-shot warnings name each element" do
      m = program(@plant, [seal()], "m")

      {:ok, config} =
        Logex.Configuration.compile(
          "c",
          "var_global g bool\nvar_global trip bool\ntask t single trip priority 1\nprogram m1 m with t\nm1.go g\nm1.k 1\n",
          %{"m" => m}
        )

      assert Enum.map(config.warnings, & &1.message) == [
               "`m1` runs under the event task `t`, and `m` runs the timer `lane_t[1]` on its " <>
                 "line 7: a ton times across the task's runs, and one whose rung is true on two " <>
                 "runs in a row counts the whole time between them",
               "`m1` runs under the event task `t`, and `m` runs the timer `lanes[1].t` on line " <>
                 "6 of block `seal`: a ton times across the task's runs, and one whose rung is " <>
                 "true on two runs in a row counts the whole time between them",
               "`m1` runs under the event task `t`, and `m` runs the counter `lane_c[0]` on its " <>
                 "line 8: a counter sees its rung only at the task's runs, so a pulse between two " <>
                 "runs is never counted, and a rung that is the task's trigger is true at every " <>
                 "run and never counts",
               "`m1` runs under the event task `t`, and `m` runs an `ons` on line 8 of block " <>
                 "`seal`, whose storage bit is `lanes[1].e`: an ons sees its rung only at the " <>
                 "task's runs, so a pulse between two runs never fires it, and a rung that is " <>
                 "the task's trigger is true at every run and never fires it"
             ]
    end

    test "`get/2` names a member of an element, `m1.lane_t[1].acc`, and never an element or its array whole" do
      m = program(@plant, [seal()], "m")

      {:ok, config} =
        Logex.Configuration.compile(
          "c",
          "var_global g bool 1\ntask t interval 10 priority 1\nprogram m1 m with t\nm1.go g\nm1.k 1\n",
          %{"m" => m}
        )

      runtime = Runtime.start(config)
      {runtime, _, _} = Runtime.cycle(runtime, 0, %{})
      {runtime, _, _} = Runtime.cycle(runtime, 10, %{})
      assert Runtime.get(runtime, "m1.lane_t[1].acc") == {:ok, 10}
      assert Runtime.get(runtime, "m1.lane_t[01].pre") == {:ok, 20}
      assert Runtime.get(runtime, "m1.lanes[1].q") == {:ok, 0}
      assert Runtime.get(runtime, "m1.lane_c[0].pv") == {:ok, 2}

      for {path, reason} <- [
            {"m1.lane_t",
             "`m1.lane_t` is an array of 2 tons: an access path names a member of one of its " <>
               "elements, as in `m1.lane_t[0].acc`"},
            {"m1.lane_t[1]",
             "`m1.lane_t[1]` is a ton: an access path names one of its members, as in " <>
               "`m1.lane_t[1].acc`"},
            {"m1.lane_t[2].acc",
             "`m1.lane_t[2]`'s subscript `2` is outside 0 to 1: `m1.lane_t` is an array of 2 tons"},
            {"m1.lane_t[k].acc",
             "`m1.lane_t[k]`'s subscript `k` is a tag's name: an access path names an element by " <>
               "literal subscripts, as in `m1.lane_t[0]`"},
            {"m1.lane_t[1].last",
             "`m1.lane_t[1].last` is internal to `m1.lane_t[1]`: an access path reads only its " <>
               "public members, `pre`, `acc`, `dn`, `tt` and `en`"},
            {"m1.lanes[1].t",
             "`m1.lanes[1].t` is a `var` of `seal`, hidden outside it: an access path reads only " <>
               "its public members, `s` and `q`"}
          ] do
        assert Runtime.get(runtime, path) == {:error, reason}
      end
    end
  end

  describe "growth, in reductions" do
    # Counted in a process of its own with a heap the collector never visits, so each count
    # is the same on every run: a scan's reductions for each rung, the difference of 200
    # rungs and 100 over 100.
    defp per_rung(head, rung) do
      cost = fn n ->
        source = head.(n) <> Enum.map_join(1..n, "\n", rung)
        {:ok, p} = Logex.compile(source, name: "p", types: [cost_seal()])
        state = Runtime.instance(p)
        inputs = for {k, %{section: :var_input}} <- p.tags, into: %{}, do: {k, 1}
        parent = self()

        {_pid, ref} =
          :erlang.spawn_opt(
            fn ->
              {:reductions, before} = Process.info(self(), :reductions)
              Runtime.call(p, state, inputs, %Scan{now: 0, first: true})
              {:reductions, later} = Process.info(self(), :reductions)
              send(parent, {:reductions, later - before})
            end,
            [:monitor, min_heap_size: 8_000_000]
          )

        assert_receive {:reductions, r}, 10_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
        r
      end

      # Measured once to warm what the first scan of each loads, and then counted.
      _warm = cost.(10)
      (cost.(200) - cost.(100)) / 100
    end

    defp cost_seal do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input s bool\nvar_output q bool\nvar t ton\n" <>
            "xic s ton t 10\nxic t.dn ote q",
          name: "seal"
        )

      seal
    end

    defp scalars(kind),
      do: fn n ->
        "var_input a bool\nvar_input k dint\nvar_output q bool\nvar_output d dint\n" <>
          Enum.map_join(1..n, "\n", &"var t#{&1} #{kind}") <> "\n"
      end

    defp arrayed(kind),
      do: fn n ->
        "var_input a bool\nvar_input k dint\nvar_output q bool\nvar_output d dint\n" <>
          "var t #{kind}[#{n}]\n"
      end

    # A program with no array of instances scans, rung for rung, in exactly the reductions
    # it took at aa41f4d, before M5-14: an element's clauses are told by their heads.
    test "a program of none scans as it did before M5-14" do
      for {kind, rung, measured} <- [
            {"ton", &"xic a ton t#{&1} 100", 112.01},
            {"ton_ltime", &"xic a ton t#{&1} 100", 115.01},
            {"tp", &"xic a tp t#{&1} 100", 119.01},
            {"ctu", &"xic a ctu t#{&1} 5", 154.02},
            {"ctud", &"xic a ctu t#{&1} 5\nxic a ctd t#{&1} 5", 343.01},
            {"seal", &"cal t#{&1} a q", 288.02},
            {"ton", &"xic t#{&1}.dn ote q", 87.03},
            {"ctu", &"move t#{&1}.cv d", 80.01}
          ] do
        assert per_rung(scalars(kind), rung) == measured, "#{kind}: #{rung.(1)}"
      end
    end

    # Measured: each element costs its instruction's run and some 9 to 14 reductions more
    # than a scalar instance of its type, its read from its array's tuple and its write back,
    # and the state's check of the array, one element's map a rung; a member through a tag
    # subscript 5 more than a literal one, the subscript's read, its check and the
    # instruction's catch.
    test "an element runs in a bounded few reductions more than a scalar instance of its type, linear in the elements" do
      for {kind, scalar_rung, element_rung} <- [
            {"ton", &"xic a ton t#{&1} 100", &"xic a ton t[#{&1 - 1}] 100"},
            {"ton_ltime", &"xic a ton t#{&1} 100", &"xic a ton t[#{&1 - 1}] 100"},
            {"tp", &"xic a tp t#{&1} 100", &"xic a tp t[#{&1 - 1}] 100"},
            {"ctu", &"xic a ctu t#{&1} 5", &"xic a ctu t[#{&1 - 1}] 5"},
            {"ctud", &"xic a ctu t#{&1} 5\nxic a ctd t#{&1} 5",
             &"xic a ctu t[#{&1 - 1}] 5\nxic a ctd t[#{&1 - 1}] 5"},
            {"seal", &"cal t#{&1} a q", &"cal t[#{&1 - 1}] a q"},
            {"ton", &"xic t#{&1}.dn ote q", &"xic t[#{&1 - 1}].dn ote q"},
            {"ctu", &"move t#{&1}.cv d", &"move t[#{&1 - 1}].cv d"}
          ] do
        scalar = per_rung(scalars(kind), scalar_rung)
        element = per_rung(arrayed(kind), element_rung)
        assert element <= scalar + 15, "#{element_rung.(1)}: #{element} against #{scalar}"
      end

      literal = per_rung(arrayed("ton"), &"xic t[#{&1 - 1}].dn ote q")
      tagged = per_rung(arrayed("ton"), fn _ -> "xic t[k].dn ote q" end)
      assert tagged <= literal + 5, "#{tagged} against #{literal}"
      write = per_rung(arrayed("ctu"), &"move d t[#{&1 - 1}].pv")
      tagged_write = per_rung(arrayed("ctu"), fn _ -> "move d t[k].pv" end)
      assert tagged_write <= write + 5, "#{tagged_write} against #{write}"
    end
  end

  describe "the code" do
    # CLAUDE.md: multiple function clauses, not conditionals. M5-14 brought seven `case`
    # expressions into `lib/`, which its review found; the four this test names are older,
    # the parser's three and the runner's one, and no new one joins them unseen.
    test "lib/ holds no case, cond, if or unless but the parser's three and the runner's one" do
      found =
        for path <- Path.wildcard("lib/**/*.ex"),
            {line, number} <- Enum.with_index(File.read!(path) |> String.split("\n"), 1),
            Regex.match?(~r/^[^#"]*\b(case|cond|if|unless)\b[^#"]*\bdo\s*$/, line),
            do: {path, number}

      assert Enum.map(found, &elem(&1, 0)) |> Enum.sort() == [
               "lib/logex/parser.ex",
               "lib/logex/parser.ex",
               "lib/logex/parser.ex",
               "lib/logex/runner.ex"
             ]
    end
  end

  describe "growth, in the words a step allocates" do
    # M5-14's review: an edit that moved each element by a put into its array's tuple copied
    # the array once an element, quadratic in wall time, while the reductions, which count
    # a tuple's copy as about one, grew linearly, so no reduction count could see it. A
    # step's allocation can: counted here as the words its process's heap gains while the
    # step runs, in a process given a heap the collector never visits during it, which the
    # count checks, so each count is the same on every run. Its data are built first, and
    # collected, in that process.
    defp allocated(prepare, step) do
      parent = self()

      {pid, ref} =
        :erlang.spawn_opt(
          fn ->
            arguments = prepare.()
            :erlang.garbage_collect()
            send(parent, {:ready, self()})
            assert_receive :go, 60_000
            result = step.(arguments)
            send(parent, {:done, self()})
            assert_receive :stop, 60_000
            exit({:ok, :erlang.phash2(result)})
          end,
          [:monitor, min_heap_size: 6_000_000]
        )

      assert_receive {:ready, ^pid}, 60_000
      before = heap(pid)
      send(pid, :go)
      assert_receive {:done, ^pid}, 60_000
      later = heap(pid)
      send(pid, :stop)
      assert_receive {:DOWN, ^ref, :process, ^pid, {:ok, _hash}}, 60_000
      # No collection came during the step, so the heap's growth is what it allocated.
      assert elem(later, 1) == elem(before, 1), "collected during the step"
      elem(later, 0) - elem(before, 0)
    end

    defp heap(pid) do
      {:garbage_collection_info, info} = Process.info(pid, :garbage_collection_info)
      {:garbage_collection, gc} = Process.info(pid, :garbage_collection)
      {info[:heap_size], {gc[:minor_gcs], info[:heap_block_size]}}
    end

    # A user block holding an array of user blocks' instances, one instance of it.
    defp edited("rack", n) do
      {:ok, rack} =
        Logex.compile("function_block rack\nvar_output q bool\nvar l seal[#{n}]\nxic q ote q",
          name: "rack",
          types: [seal()]
        )

      head = "var_input go bool\nvar_output q bool\nvar r rack\n"
      running = program(head <> "xic go ote q", [rack])
      candidate = program(head <> "xio go ote q", [rack])
      {running, candidate}
    end

    defp edited(kind, n) do
      head = "var_input go bool\nvar_output q bool\nvar t #{kind}[#{n}]\n"
      running = program(head <> "xic go ote q", [seal()])
      candidate = program(head <> "xio go ote q", [seal()])
      {running, candidate}
    end

    # Measured, at 500 and 2,000 elements: each step's words grow some 4.1 times, as the
    # elements do, for an array of timers and of a user block's instances; with a put into
    # the tuple an element, accept, test and untest grew 10 to 12 times, and a prune of the
    # blocks' members 11, and of a block holding an array of blocks the same.
    test "accept, test, untest and assemble of an array of instances allocate linearly in its elements" do
      for kind <- ["ton", "seal", "rack"] do
        words =
          for n <- [500, 2000] do
            {running, candidate} = edited(kind, n)

            prepare = fn ->
              state = Runtime.instance(running)
              {:ok, edit, _forecast} = Edit.accept(running, candidate, state)
              {tested, after_test, _report} = Edit.test(edit, state)
              {state, edit, tested, after_test}
            end

            [
              allocated(prepare, fn {state, _, _, _} -> Edit.accept(running, candidate, state) end),
              allocated(prepare, fn {state, edit, _, _} -> Edit.test(edit, state) end),
              allocated(prepare, fn {_, _, tested, state} -> Edit.untest(tested, state) end),
              allocated(prepare, fn {_, _, tested, state} -> Edit.assemble(tested, state) end)
            ]
          end

        for {step, small, large} <- Enum.zip([[:accept, :test, :untest, :assemble] | words]) do
          assert large < 6 * small, "#{kind} #{step}: #{large} words at 2000, #{small} at 500"
        end
      end
    end
  end
end
