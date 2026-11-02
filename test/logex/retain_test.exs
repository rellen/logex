defmodule Logex.RetainTest do
  @moduledoc """
  Milestone 6 (`docs/organisation.md` §4.13): M6-1's words, `retain` and `non_retain`,
  their lines and refusals, and `Logex.Program`'s `retained`, settled by the nearest mark
  on a member's path (decisions 266 to 270); and M6-2's warm restart in the core,
  `Logex.Runtime.restart/3` and `restart/2` with `:warm`, keeping what is marked and
  putting back the rest, a retained timer resuming without counting the time before the
  restart since it last ran and no edge firing on the first scan (decisions 271, 273, 274
  and 279). Each rule a test that fails when it alone is reverted. The configuration's
  `var_global retain`, the image and the store are later items' (M6-3 to M6-5).
  """
  use ExUnit.Case, async: true

  alias Logex.{Instance, Program, Runtime, Scan, Tag}

  defp c!(src, types \\ []) do
    {:ok, program} = Logex.compile(src, name: "m", types: types)
    program
  end

  defp block!(src, types \\ []) do
    [_, name | _] = String.split(src, ~r/\s+/, parts: 3)
    {:ok, type} = Logex.compile(src, name: name, types: types)
    type
  end

  defp errors(src, types \\ []) do
    {:error, diagnostics} = Logex.compile(src, name: "m", types: types)
    Enum.map(diagnostics, &"line #{&1.line}: #{&1.message}")
  end

  defp raises(message, fun), do: assert_raise(ArgumentError, message, fun)

  defp qualifiers(%Program{tags: tags}), do: Map.new(tags, fn {n, t} -> {n, t.retain} end)

  # Scans `program` from `state` once per entry of `inputs`, `dt` ms apart.
  defp scans(program, state, inputs, dt \\ 10),
    do:
      Enum.reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {_out, state} = Runtime.call(program, state, input, %Scan{now: now + dt, first: first})
        state
      end)

  @seal """
  function_block seal
  var_input go bool
  var_output q bool
  var non_retain jog bool
  var t ton
  var retain k dint
  xic go ton t 100
  xic t.dn ote q
  xic go add k 1 k
  xic go ote jog
  """

  @plain """
  function_block plain
  var_input go bool
  var_output q bool
  var t ton
  xic go ton t 100
  xic t.dn ote q
  """

  describe "M6-1: the words (decision 267)" do
    test "each section that takes a qualifier takes either, in any case, and the tag keeps it" do
      p =
        c!(
          "var retain c dint\nvar non_retain j bool\nvar_output RETAIN total dint 5\n" <>
            "Var_Output Non_Retain lamp bool\nvar plain bool\nxic j move 1 c\nxic j ote lamp\n" <>
            "xic plain add total 1 total"
        )

      assert qualifiers(p) == %{
               "c" => :retain,
               "j" => :non_retain,
               "total" => :retain,
               "lamp" => :non_retain,
               "plain" => nil
             }

      b =
        block!(
          "function_block blk\nvar_input retain go bool\nvar_output non_retain q bool\n" <>
            "var retain k dint\nxic go ote q\nxic go move 1 k"
        )

      assert Map.new(b.members, &{&1.name, &1.retain}) == %{
               "go" => :retain,
               "q" => :non_retain,
               "k" => :retain
             }
    end

    test "every refusal of decisions 267 and 268 is at its line" do
      assert errors(
               "var retain non_retain a bool\nvar non_retain retain b bool\n" <>
                 "var retain retain c bool\nvar d retain bool\nvar e bool retain\nvar retain\n" <>
                 "var retain f\nvar_input retain g bool\nvar_input non_retain h bool\n" <>
                 "var_external retain i bool\nvar_external non_retain j bool\n" <>
                 "var x bool\nxic i ote x\nxic j ote x\nretain x\nxic retain ote x\n" <>
                 "xic g ote x\nxic h ote x"
             ) == [
               "line 1: a declaration takes `retain` or `non_retain`, not both: found " <>
                 "`retain` and `non_retain`",
               "line 2: a declaration takes `retain` or `non_retain`, not both: found " <>
                 "`non_retain` and `retain`",
               "line 3: `retain` is given twice: a declaration takes `retain` once, as in " <>
                 "`var retain count dint`",
               "line 4: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 5: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 6: `var retain` needs a tag name and a type, as in `var retain fault bool`",
               "line 7: `f` needs a type, as in `var retain f bool` or `var retain f dint`",
               "line 8: `g` is a program's var_input, which takes no `retain`: a var_input " <>
                 "holds the host's value, which every restart keeps where it fits",
               "line 9: `h` is a program's var_input, which takes no `non_retain`: a " <>
                 "var_input holds the host's value, which every restart keeps where it fits",
               "line 10: `i` is a var_external, which takes no `retain`: its global carries " <>
                 "it, as the configuration declares it",
               "line 11: `j` is a var_external, which takes no `non_retain`: its global " <>
                 "carries it, as the configuration declares it",
               "line 15: `retain` qualifies a declaration, straight after its section word, " <>
                 "as in `var retain count dint`",
               "line 16: `xic` expects a tag, found the keyword `retain`"
             ]
    end

    # A var_external or a program's var_input refused for its qualifier alone is still
    # declared, with none, so its uses are checked and none is told it is undeclared.
    test "a line refused for its qualifier alone still declares its tag" do
      assert errors("var_external retain e bool\nvar x bool\nxic e ote x\nxic e ote e") == [
               "line 1: `e` is a var_external, which takes no `retain`: its global carries " <>
                 "it, as the configuration declares it"
             ]
    end

    # M6-2's review: so is one refused for a qualifier out of its place or given twice,
    # read without it: with the qualifier in its place where it has one, and none where
    # two were given.
    test "a line refused for a qualifier out of place or given twice still declares its tag" do
      assert errors(
               "var retain non_retain a bool\nvar retain retain b bool\nvar c retain bool\n" <>
                 "var d bool retain\nvar e dint 5 retain\nvar f retain retain bool\n" <>
                 "var x bool\nxic a ote x\nxic b ote x\nxic c ote x\nxic d ote x\n" <>
                 "xic x move e e\nxic f ote x"
             ) == [
               "line 1: a declaration takes `retain` or `non_retain`, not both: found " <>
                 "`retain` and `non_retain`",
               "line 2: `retain` is given twice: a declaration takes `retain` once, as in " <>
                 "`var retain count dint`",
               "line 3: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 4: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 5: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 6: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 6: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`"
             ]

      # The rest of the line is read as any line is: a type still wanted is told, and a
      # line of no type declares nothing, as `var f` does.
      assert errors("var retain retain f\nvar g retain\nvar x bool\nxic x ote x") ==
               [
                 "line 1: `retain` is given twice: a declaration takes `retain` once, as in " <>
                   "`var retain count dint`",
                 "line 1: `f` needs a type, as in `var f bool` or `var f dint`",
                 "line 2: `retain` comes straight after the section word, as in " <>
                   "`var retain count dint`",
                 "line 2: `g` needs a type, as in `var g bool` or `var g dint`"
               ]

      # Declared with its initial value, and with the qualifier in its place, where it
      # has one.
      {:ok, ast} =
        Logex.Compiler.parse(
          elem(
            Logex.Compiler.tokenize(
              "var retain a dint 7 retain\nvar non_retain retain b bool\nvar c non_retain dint\nxic b ote b"
            ),
            1
          )
        )

      {:routine, {:rungs, rungs}} = ast
      {table, _logic, diagnostics, _untyped} = Logex.Declarations.split(rungs)
      assert length(diagnostics) == 3

      assert Map.new(table, fn {n, t} -> {n, {t.retain, t.initial}} end) == %{
               "a" => {:retain, 7},
               "b" => {nil, nil},
               "c" => {nil, nil}
             }
    end

    # RV-2 (the review after Milestone 6, M15): so is one after an array's type word,
    # before or among its initial list, where it was told it was no literal of the list,
    # or for an array of instances that it takes none; the line read without it, its
    # initial list kept and its array's uses checked.
    test "a qualifier after an array's type word is told where it goes" do
      assert errors(
               "var x int[2] retain 1 2\nvar t ton[2] Retain\nvar y int[2] 1 non_retain 2\n" <>
                 "var z int[2] 1 2 retain\nvar u ton[2] retain 5\nvar w int[2] 1 w 2\n" <>
                 "var_input a bool\nvar_output o int\nmove x[1] o\nxic a ton t[0] 5\n" <>
                 "xic a ton t[1] 5\nmove y[0] o\nmove z[1] o\nxic a ton u[0] 5\nxic a ton u[1] 5"
             ) == [
               "line 1: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 2: `Retain` comes straight after the section word, as in " <>
                 "`var Retain count dint`",
               "line 3: `non_retain` comes straight after the section word, as in " <>
                 "`var non_retain count dint`",
               "line 4: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 5: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`",
               "line 5: `u` is an array of 2 tons, which takes no initial values: each " <>
                 "element's preset is the number on its `ton` instruction, as in `ton u[0] 5000`",
               "line 6: unexpected `w` in the initial list of `w`: an array's initial list is " <>
                 "one literal for every element"
             ]

      # Read without it, the list kept and no qualifier taken.
      {:ok, tokens, _} =
        Logex.Compiler.tokenize("var x int[2] retain 1 2\nvar y int[2] 1 retain 2")

      {:ok, {:routine, {:rungs, rungs}}} = Logex.Compiler.parse(tokens)
      {table, _logic, [_, _], _untyped} = Logex.Declarations.split(rungs)

      assert Map.new(table, fn {n, t} -> {n, {t.retain, t.initial}} end) == %{
               "x" => {nil, [1, 2]},
               "y" => {nil, [1, 2]}
             }
    end

    # RV-2's review: a program's var_input and a var_external take no qualifier wherever it
    # stands, so one out of its place is told that, in the words its place gives, where
    # it was told to move to where it is refused too; the tag is declared with none, its
    # uses checked. A block's var_input and a `var` are told where it goes, as before.
    test "a misplaced qualifier on a section that takes none is told the section takes none" do
      input =
        &("`#{&1}` is a program's var_input, which takes no `#{&2}`: a var_input holds the " <>
            "host's value, which every restart keeps where it fits")

      external =
        &("`#{&1}` is a var_external, which takes no `#{&2}`: its global carries it, as the " <>
            "configuration declares it")

      assert errors(
               "var_input x int[2] retain\nvar_input y dint Non_Retain\n" <>
                 "var_input z retain dint\nvar_external e int[2] retain\n" <>
                 "var_external f dint NON_RETAIN\nvar w int[2] retain\nvar_output q dint\n" <>
                 "move x[1] q\nmove y q\nmove z q\nmove e[0] q\nmove f q\nmove w[0] q"
             ) == [
               "line 1: " <> input.("x", "retain"),
               "line 2: " <> input.("y", "non_retain"),
               "line 3: " <> input.("z", "retain"),
               "line 4: " <> external.("e", "retain"),
               "line 5: " <> external.("f", "non_retain"),
               "line 6: `retain` comes straight after the section word, as in " <>
                 "`var retain count dint`"
             ]

      {:error, [d]} =
        Logex.compile(
          "function_block fb\nvar_input x dint retain\nvar_output y dint\nmove x y",
          name: "fb"
        )

      assert d.message ==
               "`retain` comes straight after the section word, as in " <>
                 "`var_input retain count dint`"
    end

    test "a section word is quoted as written beside its qualifier" do
      assert errors("VAR_OUTPUT Retain\nVar x Retain bool") == [
               "line 1: `VAR_OUTPUT Retain` needs a tag name and a type, as in " <>
                 "`VAR_OUTPUT Retain fault bool`",
               "line 2: `Retain` comes straight after the section word, as in " <>
                 "`Var Retain count dint`"
             ]
    end

    test "a block's var_input takes one, and a block's file refuses its var_external still" do
      assert [{:ok, _}, {:error, [external, d]}] = [
               Logex.compile(
                 "function_block a\nvar_input retain go bool\nvar_output q bool\nxic go ote q",
                 name: "a"
               ),
               Logex.compile(
                 "function_block b\nvar_external retain go bool\nvar_output q bool\nxic go ote q",
                 name: "b"
               )
             ]

      assert external.message =~ "cannot be a var_external in a function block's file"
      assert d.message =~ "takes no `retain`: its global carries it"
    end

    test "an instance and an array, of every kind, take a qualifier, and an instance's line " <>
           "out of `var` is refused as before" do
      p =
        c!(
          "var retain boxes ctu\nvar retain lube rto\nvar retain w int[3] 1 2 3\n" <>
            "var non_retain lane_t ton[2]\nvar retain s seal\nvar x bool\n" <>
            "xic x ctu boxes 5\nxic x rto lube 5\nxic x ton lane_t[0] 5\nxic x ton lane_t[1] 5\n" <>
            "cal s x x",
          [block!(@seal)]
        )

      assert qualifiers(p) == %{
               "boxes" => :retain,
               "lube" => :retain,
               "w" => :retain,
               "lane_t" => :non_retain,
               "s" => :retain,
               "x" => nil
             }

      assert errors("var_output retain t1 ton") == [
               "line 1: `t1` is a ton: an instance is the program's own, declared with " <>
                 "`var`, as in `var t1 ton`, not with `var_output`"
             ]
    end

    test "`retain` and `non_retain` are reserved in any case: no tag, block or label is named " <>
           "by either" do
      for word <- ~w(retain non_retain RETAIN Non_Retain) do
        raises("`#{word}` is a keyword and cannot name a tag", fn -> Tag.new!(word, :bool) end)
        assert Logex.Declarations.reserved(word) == :qualifier
      end

      assert errors("var a bool\nlbl retain xic a ote a") == [
               "line 2: `lbl` takes a label, found the keyword `retain`"
             ]

      assert {:error, [d]} =
               Logex.compile("function_block non_retain\nvar_input a bool", name: "non_retain")

      assert d.message == "`non_retain` is a keyword and cannot name a function block"
    end

    test "from Elixir, Logex.Tag.new!/5 takes the qualifier a line could give, and refuses " <>
           "what no line can say" do
      # Decision 296: the qualifier is an option, the line's own word as its key.
      assert %Tag{retain: :retain} = Tag.new!("c", :dint, :var, nil, retain: true)
      assert %Tag{retain: :non_retain} = Tag.new!("c", :dint, :var_output, 3, non_retain: true)
      assert %Tag{retain: nil} = Tag.new!("c", :dint)
      assert %Tag{retain: nil} = Tag.new!("c", :dint, :var, nil, [])
      assert %Tag{retain: nil} = Tag.new!("c", :dint, :var, nil, retain: false)

      assert %Tag{retain: :non_retain} =
               Tag.new!("c", :dint, :var, nil, retain: false, non_retain: true)

      assert %Tag{retain: :retain} = Tag.new!("t", Logex.FbType.ton(), :var, nil, retain: true)

      assert Tag.new!("c", :dint, :var, nil, retain: true) == %Tag{
               name: "c",
               type: :dint,
               section: :var,
               retain: :retain
             }

      raises(
        "`e` is a var_external, which takes no `retain`: its global carries it, as the " <>
          "configuration declares it",
        fn -> Tag.new!("e", :bool, :var_external, nil, retain: true) end
      )

      # A hand-built struct's qualifier is still checked where the tag is.
      raises(
        "unknown qualifier true on `c`: logex has :retain and :non_retain, or nil for none",
        fn ->
          Logex.Declarations.validate!(%Tag{name: "c", type: :dint, section: :var, retain: true})
        end
      )

      i = Tag.new!("i", :bool, :var_input, nil, retain: true)
      assert i.retain == :retain
    end

    test "decision 296: Logex.Tag.new!/5's options, each mistake a pinned line" do
      # M6-1's positional fifth argument is no option list.
      raises(
        "the options of `c` are a keyword list, `retain: true` or `non_retain: true`, " <>
          "found :retain",
        fn -> Tag.new!("c", :dint, :var, nil, :retain) end
      )

      raises(
        "the options of `c` are a keyword list, `retain: true` or `non_retain: true`, " <>
          "found [{\"retain\", true}]",
        fn -> Tag.new!("c", :dint, :var, nil, [{"retain", true}]) end
      )

      raises(
        "the options of `c` are a keyword list, `retain: true` or `non_retain: true`, " <>
          "found [{:retain, true} | :x]",
        fn -> Tag.new!("c", :dint, :var, nil, [{:retain, true} | :x]) end
      )

      raises(
        "unknown option :persistent for `c`: Logex.Tag.new!/5 takes `retain:` and `non_retain:`",
        fn -> Tag.new!("c", :dint, :var, nil, persistent: true) end
      )

      raises("`retain:` for `c` takes true or false, found :yes", fn ->
        Tag.new!("c", :dint, :var, nil, retain: :yes)
      end)

      raises("`non_retain:` for `c` takes true or false, found 1", fn ->
        Tag.new!("c", :dint, :var, nil, non_retain: 1)
      end)

      raises("`retain:` is given twice for `c`", fn ->
        Tag.new!("c", :dint, :var, nil, retain: true, retain: false)
      end)

      raises(
        "`c` takes `retain: true` or `non_retain: true`, not both, as a declaration takes " <>
          "`retain` or `non_retain`, not both",
        fn -> Tag.new!("c", :dint, :var, nil, retain: true, non_retain: true) end
      )

      # Every mistake a line, in order, before the declaration's own check.
      raises(
        "`retain:` for `c` takes true or false, found nil\n" <>
          "unknown option :keep for `c`: Logex.Tag.new!/5 takes `retain:` and `non_retain:`",
        fn -> Tag.new!("c", :nope, :var, nil, retain: nil, keep: true) end
      )

      # M6-3's review: both `true` beside another mistake is a line of the same message,
      # the last, not dropped for the first.
      raises(
        "unknown option :x for `c`: Logex.Tag.new!/5 takes `retain:` and `non_retain:`\n" <>
          "`c` takes `retain: true` or `non_retain: true`, not both, as a declaration takes " <>
          "`retain` or `non_retain`, not both",
        fn -> Tag.new!("c", :dint, :var, nil, retain: true, non_retain: true, x: 1) end
      )

      raises(
        "`retain:` is given twice for `c`\n" <>
          "`c` takes `retain: true` or `non_retain: true`, not both, as a declaration takes " <>
          "`retain` or `non_retain`, not both",
        fn -> Tag.new!("c", :dint, :var, nil, retain: true, non_retain: true, retain: true) end
      )

      raises(
        "the options of 5 are a keyword list, `retain: true` or `non_retain: true`, found :x",
        fn -> Tag.new!(5, :dint, :var, nil, :x) end
      )
    end

    test "decision 296: a program's var_input from Elixir refused where it compiles" do
      # A program's var_input, which only the compile tells from a block's.
      {:ok, tokens, _} = Logex.Compiler.tokenize("var x bool\nxic i ote x")
      {:ok, routine} = Logex.Compiler.parse(tokens)
      i = Tag.new!("i", :bool, :var_input, nil, retain: true)

      raises(
        "`i` is a program's var_input, which takes no `retain`: a var_input holds the " <>
          "host's value, which every restart keeps where it fits",
        fn -> Logex.Compiler.instructionize(routine, [i]) end
      )

      assert {:ok, %Program{retained: ["c"]}} =
               Logex.Compiler.instructionize(routine, [
                 Tag.new!("i", :bool, :var_input),
                 Tag.new!("c", :dint, :var, nil, retain: true)
               ])
    end
  end

  describe "M6-1: a qualified line's readers by place" do
    # The loader reads a block's name from a declaration's type word by its place, so a
    # qualifier after the section word is taken out first.
    @tag :tmp_dir
    test "compile_file/1 loads the block a qualified line names", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "seal.ld"), @seal)
      path = Path.join(dir, "line.ld")

      File.write!(
        path,
        "var retain s1 seal\nvar non_retain s2 seal\nvar x bool\ncal s1 x x\ncal s2 x x"
      )

      assert {:ok, %Program{retained: ["s1.go", "s1.k", "s1.q", "s1.t", "s2.k"]}} =
               Logex.compile_file(path)
    end

    # M6-2's review: one out of its place before the type word is taken out too, so the
    # block it names is loaded and the line told only where its qualifier goes.
    @tag :tmp_dir
    test "compile_file/1 loads the block a line with a misplaced qualifier names",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "seal.ld"), @seal)
      path = Path.join(dir, "line.ld")
      File.write!(path, "var s1 retain seal\nvar x bool\ncal s1 x x")

      assert {:error, [%Logex.Diagnostic{line: 1, message: message}]} = Logex.compile_file(path)

      assert message ==
               "`retain` comes straight after the section word, as in `var retain count dint`"
    end

    # Decision 227's warning reads a real's initial value by its place on the line.
    test "a real's initial value on a qualified line is warned of at its line, as on any" do
      p =
        c!(
          "var retain sp real 16777217.0\nvar non_retain q lreal 0.1\nvar x real 16777217.0\n" <>
            "var a bool\nxic a move sp q\nxic a move x q"
        )

      assert Enum.map(p.warnings, &{&1.line, &1.message}) == [
               {1, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"},
               {3, "`16777217.0` is more precise than a real keeps: it is held as 16777216.0"}
             ]
    end
  end

  describe "M6-1: Program.retained (decisions 269 and 270)" do
    # Decision 269: every elementary type, the reals among them, whole or in an array.
    test "a retained real and an array of lreals are retained, and kept by a warm restart" do
      p =
        c!(
          "var_input go bool\nvar retain sp real\nvar retain hist lreal[2]\nvar tmp real\n" <>
            "var non_retain off lreal\nxic go move 3.0 sp\nxic go move 5.0 hist[1]\n" <>
            "xic go move 7.0 tmp\nxic go move 9.0 off"
        )

      assert p.retained == ["hist", "sp"]
      s = scans(p, Runtime.instance(p), [%{"go" => 1}])
      warm = Runtime.restart(p, s, :warm)
      assert {warm.env["sp"], warm.env["hist"]} == {3.0, {0.0, 5.0}}
      assert {warm.env["tmp"], warm.env["off"]} == {0.0, 0.0}
      assert {s.env["tmp"], s.env["off"]} == {7.0, 9.0}
      assert Runtime.restart(p, s, :cold).env["sp"] == 0.0
    end

    # An array of a block's instances of two dimensions, a member retained in each element.
    test "a member a block retains is kept in every element of a 2-D array of its instances" do
      cell =
        block!(
          "function_block cell\nvar_input go bool\nvar retain k dint\nvar j dint\n" <>
            "var t ton\nxic go add k 1 k\nxic go add j 1 j\nxic go ton t 100"
        )

      p =
        c!(
          "var_input go bool\nvar g cell[2,2]\ncal g[0,1] go\ncal g[1,0] go\ncal g[1,1] go",
          [cell]
        )

      assert p.retained == ["g[*].k"]
      s = scans(p, Runtime.instance(p), List.duplicate(%{"go" => 1}, 3))
      warm = Runtime.restart(p, s, :warm)
      fresh = Runtime.instance(p).env["g"]

      for {i, j, k} <- [{0, 0, 0}, {0, 1, 3}, {1, 0, 3}, {1, 1, 3}] do
        element = elem(elem(warm.env["g"], i), j)
        assert element["k"] == k
        assert element["j"] == 0 and element["t"] == elem(elem(fresh, i), j)["t"]
      end

      assert elem(elem(s.env["g"], 1), 1)["j"] == 3
    end

    test "a program that marks nothing has none, and compiles as it did, its warnings " <>
           "exactly as before" do
      src =
        "var_input go bool\nvar t ton\nvar c dint\nvar_output q bool\nvar n bool\n" <>
          "xic go ton t 10\nxic t.dn ote q\nxic go add c 1 c\nxic go ote q"

      marked = String.replace(src, ~r/^var (?!_)/m, "var non_retain ")
      marked = String.replace(marked, "var_output q", "var_output non_retain q")

      plain = c!(src)
      stated = c!(marked)
      assert plain.retained == nil
      assert stated.retained == nil
      assert Enum.all?(Map.values(plain.tags), &(&1.retain == nil))
      assert plain.rungs == stated.rungs
      assert plain.warnings == stated.warnings

      assert Map.new(plain.tags, fn {n, t} -> {n, %{t | retain: nil}} end) ==
               Map.new(stated.tags, fn {n, t} -> {n, %{t | retain: nil}} end)
    end

    test "the nearest mark on a member's path wins, at every depth, and a path is listed " <>
           "whole where everything under it is retained" do
      seal = block!(@seal)
      plain = block!(@plain)

      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_output q bool\nvar retain s seal\n" <>
            "var p plain\nvar non_retain r plain\ncal s go q\ncal p go q\ncal r go q",
          [seal, plain]
        )

      p =
        c!(
          "var retain s1 seal\nvar s2 seal\nvar retain p1 plain\nvar retain o outer\n" <>
            "var o2 outer\nvar retain gs seal[2]\nvar retain ps plain[3]\nvar retain boxes ctu\n" <>
            "var retain w int[4]\nvar non_retain x bool\nvar go bool\nvar q bool\n" <>
            "cal s1 go q\ncal s2 go q\ncal p1 go q\ncal o go q\ncal o2 go q\ncal gs[0] go q\n" <>
            "cal gs[1] go q\ncal ps[0] go q\ncal ps[1] go q\ncal ps[2] go q\n" <>
            "xic go ctu boxes 5\nxic go ote x",
          [seal, plain, outer]
        )

      assert seal.body.retained == ["k"]
      assert plain.body.retained == nil
      assert outer.body.retained == ["s.go", "s.k", "s.q", "s.t"]

      assert p.retained == [
               "boxes",
               "gs[*].go",
               "gs[*].k",
               "gs[*].q",
               "gs[*].t",
               "o.go",
               "o.p",
               "o.q",
               "o.s.go",
               "o.s.k",
               "o.s.q",
               "o.s.t",
               "o2.s.go",
               "o2.s.k",
               "o2.s.q",
               "o2.s.t",
               "p1",
               "ps",
               "s1.go",
               "s1.k",
               "s1.q",
               "s1.t",
               "s2.k",
               "w"
             ]

      assert Program.edited_by_hand(p) == []
    end

    # The rule restated over seeded programs of blocks three deep: every leaf, an elementary
    # member, a built-in instance or an array, by the nearest qualifier on its path.
    test "over seeded programs, every leaf retained is the one the rule restated gives" do
      :rand.seed(:exsss, {6, 1, 270})

      for _ <- 1..60 do
        {sources, program_source, leaves} = rule_draw()
        types = Enum.reduce(sources, [], fn src, types -> [block!(src, types) | types] end)
        p = c!(program_source, types)
        expected = for {path, true} <- leaves, do: path
        covered = for {path, _} <- leaves, covered?(path, p.retained || []), do: path

        assert {covered -- expected, expected -- covered} == {[], []},
               Enum.join(sources, "\n\n") <> "\n\n" <> program_source
      end
    end

    # M6-2's review: the check of a program handed in (edited_by_hand/1, which instance/1,
    # an edit's accept and a configuration's check run) passes over an instance of a block
    # that retains nothing by a guard, so that each costs no more than it did at `c963cab`,
    # before M6-1, where it cost 7 reductions more an instance: the slopes over 100 and 400
    # instances, of `seal` and of `seal[2]`, against the parent's, 24 and 21 a check and
    # 138.3 and 256.3 an instance/1, measured on it.
    test "a program of unmarked block instances is checked as it was before M6-1" do
      plain = block!(@plain)

      for {decl, use, check, made} <- [
            {"plain", &"cal s#{&1} go q", 24, 139},
            {"plain[2]", &"cal s#{&1}[0] go q", 21, 257}
          ] do
        [{c1, i1}, {c2, i2}] =
          for n <- [100, 400] do
            p =
              c!(
                "var_input go bool\nvar_output q bool\n" <>
                  Enum.map_join(1..n, "\n", &"var s#{&1} #{decl}") <>
                  "\n" <> Enum.map_join(1..n, "\n", use),
                [plain]
              )

            {reductions(fn -> Program.edited_by_hand(p) end),
             reductions(fn -> Runtime.instance(p) end)}
          end

        assert (c2 - c1) / 300 <= check, "#{decl}: a check #{(c2 - c1) / 300} an instance"
        assert (i2 - i1) / 300 <= made, "#{decl}: instance/1 #{(i2 - i1) / 300} an instance"
      end
    end

    test "a hand edit of a program's or a body's retained paths is refused where it is " <>
           "handed in" do
      p = c!("var retain c dint\nvar x bool\nxic x move 1 c")

      raises(
        "`m`'s retained paths do not hold `c`, where its tags hold it: `m` was edited by " <>
          "hand after it compiled",
        fn -> Runtime.instance(%{p | retained: nil}) end
      )

      raises(
        "`m`'s retained paths hold `x`, where its tags do not hold it: `m` was edited by " <>
          "hand after it compiled",
        fn -> Runtime.instance(%{p | retained: ["c", "x"]}) end
      )

      raises(
        "`m`'s retained paths are neither nil nor a list of paths, got: %{}: `m` was " <>
          "edited by hand after it compiled",
        fn -> Runtime.instance(%{p | retained: %{}}) end
      )

      seal = block!(@seal)
      q = c!("var s seal\nvar x bool\ncal s x x", [seal])
      held = q.blocks["seal"]
      edited = %{q | blocks: %{"seal" => %{held | body: %{held.body | retained: nil}}}}

      # The program's own paths read its bodies' (Logex.Program.retained/2), so the hand
      # edit is told at both.
      raises(
        "`m`'s retained paths hold `s.k`, where its tags do not hold it: `m` was edited by " <>
          "hand after it compiled\n" <>
          "`seal`'s body's retained paths do not hold `k`, where its tags hold it: `m` was " <>
          "edited by hand after it compiled",
        fn -> Runtime.instance(edited) end
      )

      # A type given whose body's retained paths were edited is no type a compile gives.
      refute Logex.FbType.user?(%{seal | body: %{seal.body | retained: nil}})
      refute Logex.Compiler.lowered?(%{seal.body | retained: ["jog"]})
      assert Logex.Compiler.lowered?(seal.body)
    end
  end

  describe "M6-2: the warm restart in the core (decisions 271, 273 and 274)" do
    @line """
    var e bool
    var_input eye bool
    var_input motor bool
    var retain boxes ctu
    var retain lube rto
    var retain total dint
    var count dint
    var fan tof
    xic eye ctu boxes 100
    xic motor rto lube 100000
    xic eye ons e add total 1 total
    xic eye add count 1 count
    xic motor tof fan 50
    """

    defp line_source, do: @line

    test "a box counter, a totaliser and an rto marked retain keep their values through a " <>
           "warm restart and lose them through a cold one" do
      p = c!(line_source())
      s = scans(p, Runtime.instance(p), for(i <- 1..8, do: %{"eye" => rem(i, 2), "motor" => 1}))
      # The first scan's edges count nothing (decision 69), so three of the four boxes.
      assert s.env["boxes"]["cv"] == 3
      assert s.env["total"] == 3
      assert s.env["lube"]["acc"] == 70
      assert s.env["count"] > 0

      warm = Runtime.restart(p, s, :warm)
      assert warm.env["boxes"] == s.env["boxes"]
      assert warm.env["total"] == 3
      assert warm.env["lube"] == %{s.env["lube"] | "last" => s.now}
      # Unmarked: put back, as at a cold restart.
      assert warm.env["count"] == 0
      assert warm.env["fan"] == Runtime.instance(p).env["fan"]
      assert warm.env["e"] == 0
      assert %Instance{first: true, ons_blocked: [], now: now} = warm
      assert now == s.now

      cold = Runtime.restart(p, s, :cold)
      assert cold.env == Map.merge(Runtime.instance(p).env, Map.take(s.env, ~w(eye motor)))
      assert cold.env["boxes"]["cv"] == 0 and cold.env["lube"]["acc"] == 0
    end

    test "a program with no retain restarts warm exactly as cold, in no more reductions" do
      p = c!(String.replace(line_source(), "retain ", ""))
      s = scans(p, Runtime.instance(p), for(i <- 1..8, do: %{"eye" => rem(i, 2), "motor" => 1}))
      assert Runtime.restart(p, s, :warm) == Runtime.restart(p, s, :cold)

      warm = reductions(fn -> Runtime.restart(p, s, :warm) end)
      cold = reductions(fn -> Runtime.restart(p, s, :cold) end)
      assert warm <= cold + 4, "warm #{warm}, cold #{cold}"
    end

    # Decision 273: the time before the restart since a retained timer last ran is not
    # counted; its `last` is the restart's `now`, so it resumes from where it stood.
    test "a retained ton, tof and tp caught mid-time resume, counting none of the time before " <>
           "the restart since they last ran" do
      p =
        c!(
          "var_input run bool\nvar_input skip bool\nvar retain t ton\nvar retain f tof\n" <>
            "var retain pulse tp\nvar landed bool\nxic skip jmp past\nxic run ton t 100\n" <>
            "xio run tof f 100\nxic run tp pulse 100\nlbl past ote landed"
        )

      # The pulse's rising edge after the first scan, then 20 ms of running, then the
      # timers' rungs skipped for 50 ms: each frozen mid-time, its `last` 50 ms behind the
      # instance's `now`.
      s = scans(p, Runtime.instance(p), [%{"run" => 0}, %{"run" => 1}, %{"run" => 1}])
      s = scans(p, s, [%{"run" => 1}])
      s = scans(p, s, List.duplicate(%{"skip" => 1}, 5))
      t = s.env["t"]["acc"]
      pulse = s.env["pulse"]["acc"]

      assert {t, s.env["t"]["tt"], s.env["t"]["last"], s.now} == {20, 1, 40, 90}
      assert {pulse, s.env["pulse"]["tt"]} == {20, 1}

      warm = Runtime.restart(p, s, :warm)

      for timer <- ~w(t f pulse),
          do: assert(warm.env[timer] == %{s.env[timer] | "last" => 90})

      # A first scan at the restart's own `now` adds nothing; the next adds its 10 ms.
      {_, at_once} =
        Runtime.call(p, warm, %{"run" => 1, "skip" => 0}, %Scan{now: 90, first: true})

      assert {at_once.env["t"]["acc"], at_once.env["pulse"]["acc"]} == {t, pulse}
      later = scans(p, at_once, [%{"run" => 1}])
      assert {later.env["t"]["acc"], later.env["pulse"]["acc"]} == {t + 10, pulse + 10}

      # The tof, run on after a stop, resumes its delay where it stood.
      off = scans(p, Runtime.instance(p), [%{"run" => 0}, %{"run" => 1}, %{"run" => 1}])
      assert {off.env["f"]["acc"], off.env["f"]["tt"]} == {10, 1}
      resumed = scans(p, Runtime.restart(p, off, :warm), [%{"run" => 1}])
      assert {resumed.env["f"]["acc"], resumed.env["f"]["dn"]} == {20, 1}

      # Without the rebase, the frozen 50 ms would be counted on the first scan.
      unrebased = %{warm | env: Map.put(warm.env, "t", s.env["t"])}

      {_, counted} =
        Runtime.call(p, unrebased, %{"run" => 1, "skip" => 0}, %Scan{now: 90, first: true})

      assert counted.env["t"]["acc"] == t + 50
    end

    # Decision 349 (the maintainer, 2026-11-01): a first scan reads no falling edge from a
    # retained `tof`'s `.en` kept at 1, so one held on at the outage comes to rest, `.dn`
    # 0, where until then it ran its whole delay with nothing commanding it; one in its
    # delay at the outage, `.tt` 1, resumes it (decision 273). Every kind: a `tof`, a
    # `tof_ltime`, an element of an array of them and a member of a block. Since decision
    # 385 the restart or the start puts it at rest itself, and a scan reads no `first` for
    # it (the tests after these two).
    @run_on_block """
    function_block runon
    var_input go bool
    var_output q bool
    var t tof
    xic go tof t 50
    xic t.dn ote q
    """

    @run_on """
    var_input motor bool
    var_output k1 bool
    var_output k2 bool
    var_output k3 bool
    var_output k4 bool
    var retain fan tof
    var retain lf tof_ltime
    var retain fs tof[2]
    var retain r runon
    xic motor tof fan 50
    xic motor tof lf 50000000
    xic motor tof fs[1] 50
    cal r motor k4
    xic fan.dn ote k1
    xic lf.dn ote k2
    xic fs[1].dn ote k3
    """

    defp run_on_outputs(p, state, inputs) do
      Enum.map_reduce(inputs, state, fn input, %Instance{now: now, first: first} = state ->
        {out, state} = Runtime.call(p, state, input, %Scan{now: now + 10, first: first})
        {Enum.map(~w(k1 k2 k3 k4), &out[&1]), state}
      end)
    end

    defp run_on_timers(env),
      do: [env["fan"], env["lf"], elem(env["fs"], 1), env["r"]["t"]]

    test "a retained tof held on at the outage comes to rest on the first scan, of every kind" do
      p = c!(@run_on, [block!(@run_on_block)])
      on = scans(p, Runtime.instance(p), List.duplicate(%{"motor" => 1}, 3))

      assert Enum.map(run_on_timers(on.env), &{&1["en"], &1["dn"], &1["tt"]}) ==
               List.duplicate({1, 1, 0}, 4)

      for restarted <- [
            Runtime.restart(p, on, :warm),
            elem(Runtime.instance(p, Runtime.retained(p, on)), 0)
          ] do
        {outputs, after_} = run_on_outputs(p, restarted, List.duplicate(%{"motor" => 0}, 8))
        assert outputs == List.duplicate([0, 0, 0, 0], 8)

        assert Enum.map(run_on_timers(after_.env), &{&1["en"], &1["dn"], &1["tt"], &1["acc"]}) ==
                 List.duplicate({0, 0, 0, 0}, 4)
      end

      # The rung true on the first scan: held on, as any energised run.
      {[first | _], _} = run_on_outputs(p, Runtime.restart(p, on, :warm), [%{"motor" => 1}])
      assert first == [1, 1, 1, 1]
    end

    test "a retained tof in its delay at the outage resumes it on the first scan, of every kind" do
      p = c!(@run_on, [block!(@run_on_block)])

      off =
        scans(p, Runtime.instance(p), [
          %{"motor" => 1},
          %{"motor" => 1},
          %{"motor" => 0},
          %{"motor" => 0}
        ])

      # The long timer counts its 10 ms in nanoseconds.
      assert Enum.map(run_on_timers(off.env), &{&1["tt"], &1["acc"]}) ==
               [{1, 10}, {1, 10_000_000}, {1, 10}, {1, 10}]

      {outputs, _} =
        run_on_outputs(p, Runtime.restart(p, off, :warm), List.duplicate(%{"motor" => 0}, 4))

      # 10 ms a scan from 10: on at 20, 30 and 40, and off at 50, the preset.
      assert outputs == [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1], [0, 0, 0, 0]]
    end

    # Decision 385 (the maintainer, 2026-11-01), RV-3's review's question 12: a retained
    # `tof` held on at the outage that the first scan does not run, on a rung a jump skips
    # or in a block whose `cal` is false, is put at rest by the restart or the start itself,
    # so its first run with its rung false, whenever it comes, sees no falling edge and runs
    # no off-delay, where until RV-10 decision 349's rest was a first scan's and such a
    # `tof` kept its `.en` 1 and ran its delay at its first run, a fan coming on with nobody
    # pressing anything (`[1, 1, 1]` and `[0, 1, 1]` below, RV-3's pins).
    @skipped_tof "var_input a bool\nvar_input j bool\nvar_output q bool\nvar retain t tof\n" <>
                   "xic j jmp over\nxic a tof t 100\nlbl over xic t.dn ote q\n"

    @skipped_block "function_block fb\nvar_input a bool\nvar_output q bool\n" <>
                     "var retain t tof\nxic a tof t 100\nxic t.dn ote q\n"

    test "a retained tof the first scan does not run is at rest at its first run " <>
           "(decision 385)" do
      top = c!(@skipped_tof)

      inb =
        c!(
          "var_input a bool\nvar_input go bool\nvar_output q bool\nvar retain b fb\n" <>
            "xic go cal b a q\n",
          [block!(@skipped_block)]
        )

      for {p, on, steps, expected} <- [
            {top, %{"a" => 1, "j" => 0}, [%{"a" => 0, "j" => 0}, %{}], [0, 0]},
            {top, %{"a" => 1, "j" => 0}, [%{"a" => 0, "j" => 1}, %{"j" => 0}, %{}], [0, 0, 0]},
            {inb, %{"a" => 1, "go" => 1}, [%{"a" => 0, "go" => 0}, %{"go" => 1}, %{}], [0, 0, 0]}
          ] do
        held = scans(p, Runtime.instance(p), [on, on])

        for restarted <- [
              Runtime.restart(p, held, :warm),
              elem(Runtime.instance(p, Runtime.retained(p, held)), 0)
            ] do
          {outputs, _} =
            Enum.map_reduce(steps, restarted, fn inputs,
                                                 %Instance{now: now, first: first} = state ->
              state = Runtime.put_inputs(p, state, inputs)
              {out, state} = Runtime.call(p, state, %{}, %Scan{now: now + 10, first: first})
              {out["q"], state}
            end)

          assert outputs == expected, inspect({p.source, steps})
        end
      end
    end

    # Decision 385 (the maintainer, 2026-11-01): the restart or the start itself puts every
    # retained `tof` held on and not timing, `.en` 1 and `.tt` 0, at rest, `.dn`, `.tt` and
    # `.en` 0 and `.acc` kept, wherever it sits: a `tof` and a `tof_ltime`, an element of an
    # array of them, a member of a block, of a block inside a block and of an element of an
    # array of blocks, and one on a rung a jump skips; one in its delay, `.tt` 1, keeps it,
    # its `last` the restart's `now`, and one at rest stays at rest. So before any scan its
    # `.dn` already reads 0, where decision 349's first scan left it 1 until the `tof` ran.
    @deep_runon """
    function_block deep
    var_input go bool
    var_output q bool
    var r runon
    cal r go q
    """

    @everywhere """
    var_input motor bool
    var_input j bool
    var_output k bool
    var retain fan tof
    var retain lf tof_ltime
    var retain fs tof[2]
    var retain r runon
    var retain d deep
    var retain rs runon[2]
    var retain sk tof
    var retain run tof
    var retain idle tof
    xic motor tof fan 50
    xic motor tof lf 50000000
    xic motor tof fs[1] 50
    cal r motor k
    cal d motor k
    cal rs[1] motor k
    xic motor xio j tof run 50
    xic j jmp over
    xic motor tof sk 50
    lbl over xic j xio j tof idle 50
    """

    defp everywhere(env),
      do: [
        env["fan"],
        env["lf"],
        elem(env["fs"], 1),
        env["r"]["t"],
        env["d"]["r"]["t"],
        elem(env["rs"], 1)["t"],
        env["sk"]
      ]

    test "the restart and the start put every retained tof held on at rest themselves, " <>
           "wherever it sits (decision 385)" do
      runon = block!(@run_on_block)
      p = c!(@everywhere, [runon, block!(@deep_runon, [runon])])

      # Held on everywhere, then `run` into its delay with `j`, which `idle` never saw.
      held = scans(p, Runtime.instance(p), [%{"motor" => 1}, %{"motor" => 1}, %{"j" => 1}])

      assert Enum.map(everywhere(held.env), &{&1["en"], &1["dn"], &1["tt"]}) ==
               List.duplicate({1, 1, 0}, 7)

      assert {held.env["run"]["tt"], held.env["run"]["acc"]} == {1, 0}
      assert {held.env["idle"]["en"], held.env["idle"]["dn"]} == {0, 0}

      for {door, restarted} <- [
            warm: Runtime.restart(p, held, :warm),
            image: elem(Runtime.instance(p, Runtime.retained(p, held)), 0)
          ] do
        assert Enum.map(everywhere(restarted.env), &{&1["en"], &1["dn"], &1["tt"], &1["acc"]}) ==
                 List.duplicate({0, 0, 0, 0}, 7),
               inspect(door)

        # The long timer's `.acc` and every other member kept, `last` the restart's `now`.
        now = restarted.now
        assert restarted.env["fan"] == %{held.env["fan"] | "dn" => 0, "en" => 0, "last" => now}
        assert restarted.env["run"] == %{held.env["run"] | "last" => now}, inspect(door)
        assert restarted.env["idle"] == %{held.env["idle"] | "last" => now}, inspect(door)

        # Its first run with its rung false, the jump taken and then not, runs no delay;
        # `run` resumes its own, 10 ms a scan from where it was.
        {outs, after_} =
          Enum.map_reduce([%{"motor" => 0, "j" => 1}, %{"j" => 0}, %{}], restarted, fn input,
                                                                                       state ->
            state = Runtime.put_inputs(p, state, input)

            {out, state} =
              Runtime.call(p, state, %{}, %Scan{now: state.now + 10, first: state.first})

            {{out["k"], state.env["run"]["acc"]}, state}
          end)

        assert outs == [{0, 10}, {0, 20}, {0, 30}], inspect(door)
        assert Enum.map(everywhere(after_.env), & &1["dn"]) == List.duplicate(0, 7)
      end
    end

    # Decision 385: the rest is the restart's, so a scan pays nothing for it: the first scan
    # after a warm restart of retained `tof`s held on at the outage, every kind, costs
    # exactly what the same scan not marked first does, its rung false and true, where
    # decision 349's first-scan clauses read `first` and ran a rule of their own.
    test "a scan reads no first for a tof: the first after a restart costs as any other" do
      p = c!(@run_on, [block!(@run_on_block)])
      on = scans(p, Runtime.instance(p), List.duplicate(%{"motor" => 1}, 3))
      warm = Runtime.restart(p, on, :warm)
      later = %{warm | first: false}

      for motor <- [0, 1] do
        scan = fn state, first ->
          fn ->
            Runtime.call(p, state, %{"motor" => motor}, %Scan{now: warm.now + 10, first: first})
          end
        end

        {out, first} = scan.(warm, true).()
        {^out, again} = scan.(later, false).()
        assert first.env == again.env
        assert reductions(scan.(warm, true)) == reductions(scan.(later, false)), inspect(motor)
      end
    end

    # Decision 385 in a resource: a warm `restart/2` and `start/2` from the resource's
    # image put a retained `tof` held on at rest, a member of a block whose `cal` was false
    # at the last scan, frozen held on, among them, so the first cycle's run of the block
    # with its rung false lights nothing.
    test "a resource's warm restart and start from its image put every retained tof held on " <>
           "at rest (decision 385)" do
      runon = block!(@run_on_block)

      {:ok, fans} =
        Logex.compile(
          "var_input motor bool\nvar_input go bool\nvar_output k bool\nvar_output l bool\n" <>
            "var retain fan tof\nvar retain r runon\nxic motor tof fan 50\n" <>
            "xic go cal r motor k\nxic fan.dn ote l",
          name: "fans",
          types: [runon]
        )

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          "task fast interval 10 priority 1\nvar_global m bool at panel.i.0\n" <>
            "var_global g bool at panel.i.1\nvar_global k bool at panel.q.0\n" <>
            "var_global l bool at panel.q.1\nprogram f1 fans with fast\nf1.motor m\n" <>
            "f1.go g\nf1.k k\nf1.l l",
          %{"fans" => fans}
        )

      cycled = fn rt, inputs -> elem(Runtime.cycle(rt, 10, inputs), 0) end
      rt = Runtime.start(config)
      rt = Enum.reduce([%{"m" => 1, "g" => 1}, %{"g" => 0}], rt, &cycled.(&2, &1))
      env = rt.instances["f1"].env
      assert {env["fan"]["dn"], env["r"]["t"]["en"], env["r"]["t"]["dn"]} == {1, 1, 1}

      for restarted <- [
            Runtime.restart(rt, :warm),
            elem(Runtime.start(config, Runtime.retained(rt)), 0)
          ] do
        env = restarted.instances["f1"].env
        assert Map.take(env["fan"], ~w(en dn tt)) == %{"en" => 0, "dn" => 0, "tt" => 0}
        assert Map.take(env["r"]["t"], ~w(en dn tt)) == %{"en" => 0, "dn" => 0, "tt" => 0}

        {outputs, _rt} =
          Enum.map_reduce([%{"m" => 0, "g" => 0}, %{"g" => 1}, %{}], restarted, fn inputs, rt ->
            {rt, outputs, _events} = Runtime.cycle(rt, 10, inputs)
            {outputs, rt}
          end)

        assert Enum.uniq(outputs) == [%{"k" => 0, "l" => 0}]
      end
    end

    test "a block's non_retain member and an unmarked nested timer follow decision 270" do
      seal = block!(@seal)
      plain = block!(@plain)

      outer =
        block!(
          "function_block outer\nvar_input go bool\nvar_output q bool\nvar retain s seal\n" <>
            "var p plain\ncal s go q\ncal p go q",
          [seal, plain]
        )

      p =
        c!(
          "var_input go bool\nvar retain s1 seal\nvar o outer\nvar q bool\ncal s1 go q\ncal o go q",
          [seal, plain, outer]
        )

      s = scans(p, Runtime.instance(p), List.duplicate(%{"go" => 1}, 4))
      fresh = Runtime.instance(p).env
      warm = Runtime.restart(p, s, :warm)

      # `s1` retained, but its `jog` marked non_retain in `seal`.
      assert warm.env["s1"]["k"] == 4 and warm.env["s1"]["t"]["acc"] == 30
      assert warm.env["s1"]["jog"] == fresh["s1"]["jog"] and s.env["s1"]["jog"] == 1
      # `o` unmarked: its `s`, marked retain in `outer`, kept, its `p` and its timer not.
      assert warm.env["o"]["s"]["t"]["acc"] == 30 and warm.env["o"]["s"]["k"] == 4
      assert warm.env["o"]["s"]["jog"] == 0
      assert warm.env["o"]["p"] == fresh["o"]["p"] and s.env["o"]["p"]["t"]["acc"] == 30
    end

    test "an array of instances, marked retain, keeps every element" do
      seal = block!(@seal)

      p =
        c!(
          "var_input go bool\nvar retain lanes ton[2,2]\nvar retain gs seal[2]\nvar q bool\n" <>
            "xic go ton lanes[0,0] 100\nxic go ton lanes[1,1] 100\ncal gs[0] go q\ncal gs[1] go q",
          [seal]
        )

      s = scans(p, Runtime.instance(p), List.duplicate(%{"go" => 1}, 3))
      warm = Runtime.restart(p, s, :warm)
      lanes = warm.env["lanes"]

      assert elem(elem(lanes, 0), 0)["acc"] == 20 and elem(elem(lanes, 1), 1)["acc"] == 20
      assert elem(elem(lanes, 0), 0)["last"] == s.now
      assert elem(warm.env["gs"], 0)["k"] == 3 and elem(warm.env["gs"], 1)["k"] == 3
      assert elem(warm.env["gs"], 1)["t"]["last"] == s.now
      assert elem(warm.env["gs"], 1)["jog"] == 0
      assert Runtime.restart(p, s, :cold).env["gs"] == Runtime.instance(p).env["gs"]
    end

    # Decision 274: first: true on every start, so a retained counter counts no edge on
    # the first scan, a box that arrived while the plant stood among it.
    test "no edge fires on the first scan after a warm restart: a retained cu of 0 under a " <>
           "held eye" do
      p = c!(line_source())
      s = scans(p, Runtime.instance(p), [%{"eye" => 1}, %{"eye" => 0}])
      assert {s.env["boxes"]["cv"], s.env["boxes"]["cu"]} == {0, 0}

      # Counted without a restart, on the rising edge.
      assert scans(p, s, [%{"eye" => 1}]).env["boxes"]["cv"] == 1

      warm = Runtime.restart(p, s, :warm)
      after_restart = scans(p, warm, [%{"eye" => 1}])
      assert after_restart.env["boxes"]["cv"] == 0
      assert after_restart.env["total"] == s.env["total"]
      assert scans(p, after_restart, [%{"eye" => 0}, %{"eye" => 1}]).env["boxes"]["cv"] == 1
    end

    test "a blocked one-shot is dropped by a warm restart, as by a cold one" do
      p = c!(line_source())
      s = %{scans(p, Runtime.instance(p), [%{"eye" => 0}]) | ons_blocked: ["e"]}
      assert Runtime.restart(p, s, :warm).ons_blocked == []
    end

    # Decision 194's pattern (M6-2's review): a program instance/1 checked and then edited
    # by hand is trusted, and a warm restart that reaches retained paths its tags do not
    # give raises a pinned ArgumentError there; a cold one reads none.
    test "a warm restart of a program whose retained paths were edited by hand after its " <>
           "check raises where it reaches them" do
      seal = block!(@seal)
      p = c!("var_input go bool\nvar retain c dint\nvar s seal\nvar q bool\ncal s go q", [seal])
      assert p.retained == ["c", "s.k"]
      s = scans(p, Runtime.instance(p), [%{"go" => 1}])
      by_hand = "the program was edited by hand after it was handed in and checked"

      for path <- ["zz", "c.x", "s.zz", "s[*].k", "s.k.x", "go.x.y", "zz[*].k"] do
        raises(
          "a warm restart keeps the retained path `#{path}`, which the program's tags do " <>
            "not give: #{by_hand}",
          fn -> Runtime.restart(%{p | retained: ["c", path]}, s, :warm) end
        )
      end

      raises("a warm restart keeps the retained path :c, which is no path: #{by_hand}", fn ->
        Runtime.restart(%{p | retained: ["c", :c]}, s, :warm)
      end)

      for paths <- [:all, %{}, "c"] do
        raises(
          "a warm restart reads retained paths that are no list of paths, got: " <>
            "#{inspect(paths)}: #{by_hand}",
          fn -> Runtime.restart(%{p | retained: paths}, s, :warm) end
        )
      end

      raises(
        "a warm restart reads retained paths that are no list of paths, got: :tail: " <>
          by_hand,
        fn -> Runtime.restart(%{p | retained: ["c" | :tail]}, s, :warm) end
      )

      # A cold restart reads no retained path.
      assert Runtime.restart(%{p | retained: ["zz"]}, s, :cold) == Runtime.restart(p, s, :cold)
      # And a path edited by hand that the tags do give is taken as it stands.
      assert Runtime.restart(%{p | retained: ["c"]}, s, :warm).env["s"]["k"] == 0
    end

    test "a resource's warm restart keeps each instance's retained values, and a cold one " <>
           "loses them" do
      p = c!(line_source())

      config =
        Logex.Configuration.new!(
          name: "plant",
          programs: [p],
          tasks: [%Logex.Configuration.Task{name: "fast", interval: 10, priority: 1}],
          globals: [
            %Logex.Configuration.Global{name: "eye_g", type: :bool, at: "panel.i.0"},
            %Logex.Configuration.Global{name: "motor_g", type: :bool, at: "panel.i.1"}
          ],
          instances: [%Logex.Configuration.Instance{name: "m1", type: "m", task: "fast"}],
          connections: [
            %Logex.Configuration.Connection{instance: "m1", member: "eye", to: "eye_g"},
            %Logex.Configuration.Connection{instance: "m1", member: "motor", to: "motor_g"}
          ]
        )

      runtime =
        Enum.reduce(1..6, Runtime.start(config), fn i, rt ->
          {rt, _, _} = Runtime.cycle(rt, 10, %{"eye_g" => rem(i, 2), "motor_g" => 1})
          rt
        end)

      assert Runtime.get!(runtime, "m1.total") == 2
      warm = Runtime.restart(runtime, :warm)
      assert Runtime.get!(warm, "m1.total") == 2
      assert Runtime.get!(warm, "m1.boxes.cv") == 2
      assert Runtime.get!(warm, "m1.lube.acc") == Runtime.get!(runtime, "m1.lube.acc")
      assert Runtime.get!(warm, "m1.count") == 0
      cold = Runtime.restart(runtime, :cold)
      assert Runtime.get!(cold, "m1.total") == 0 and Runtime.get!(cold, "m1.boxes.cv") == 0
    end

    # The review after Milestone 6 (b2-resource-2), decision 382 (the maintainer,
    # 2026-11-01): a resource's warm restart sets each retained timer's `last` to the
    # resource's `now`, as `start/2` from the image starts each at its own, so a slow
    # task's `rto` counts, at its first run after `restart/2`, none of the time from its
    # instance's last scan to the restart, as after `start/2`; until RV-10 its `last` was
    # its instance's own `now`, and it counted that time, 140 where `start/2` gave 90
    # (RV-3's pin, changed as decision 382 says).
    test "a resource's warm restart counts a timer's time from the restart (decision 382)" do
      {:ok, relay} = Logex.compile("var_input in bool\nvar o bool\nxic in ote o", name: "relay")

      {:ok, lube} =
        Logex.compile(
          "var_input in bool\nvar_output done bool\nvar retain t rto\nxic in rto t 230\n" <>
            "xic t.dn ote done",
          name: "lube"
        )

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          "task fast interval 10 priority 1\ntask slow interval 100 priority 2\n" <>
            "var_global x bool at panel.i.0\nvar_global lamp bool at panel.q.0\n" <>
            "program m1 relay with fast\nm1.in x\nprogram m2 lube with slow\nm2.in x\n" <>
            "m2.done lamp",
          %{"relay" => relay, "lube" => lube}
        )

      cycled = fn runtime, ms -> elem(Runtime.cycle(runtime, ms, %{"x" => 1}), 0) end
      runtime = Enum.reduce(1..15, Runtime.start(config), fn _, rt -> cycled.(rt, 10) end)
      assert {runtime.now, runtime.instances["m2"].now} == {150, 100}
      assert Runtime.get!(runtime, "m2.t.acc") == 90

      restarted = Runtime.restart(runtime, :warm)
      assert restarted.instances["m2"].now == 150
      assert restarted.instances["m2"].env["t"]["last"] == 150
      warm = cycled.(restarted, 0)
      assert Runtime.get!(warm, "m2.t.acc") == 90

      {started, []} = Runtime.start(config, Runtime.retained(runtime))
      assert Runtime.get!(cycled.(started, 0), "m2.t.acc") == 90
    end
  end

  # Decision 382 (the maintainer, 2026-11-01): every kind of timer at any depth, a `ton`, a
  # `tof` in its run-on, a `tp` in its pulse, an `rto`, a `ton_ltime`, an element of an
  # array of timers, a block's timer, a block's block's and an element of an array of
  # blocks', in a slow task whose instance last ran 50 ms before the restart: a warm
  # `restart/2` sets each one's `last` to the resource's `now`, and the resource then runs
  # on exactly as one `start/2` starts from its image, every retained value alike cycle by
  # cycle and the fan's run-on ending on the same cycle.
  describe "decision 382: a warm restart/2 counts each timer from the restart" do
    @slow_blk "function_block blk\nvar_input go bool\nvar_output q bool\nvar t ton\n" <>
                "xic go ton t 300\nxic t.dn ote q\n"
    @slow_deep "function_block deep\nvar_input go bool\nvar_output q bool\nvar b blk\n" <>
                 "cal b go q\n"

    @slow_fans """
    var_input run bool
    var_output fan bool
    var_output q bool
    var retain f tof
    var retain t ton
    var retain p tp
    var retain r rto
    var retain l ton_ltime
    var retain ts ton[2]
    var retain b blk
    var retain d deep
    var retain bs blk[2]
    xic run tof f 250
    xic run ton t 300
    xic run tp p 300
    xic run rto r 300
    xic run ton l 300000000
    xic run ton ts[1] 300
    cal b run q
    cal d run q
    cal bs[1] run q
    xic f.dn ote fan
    """

    defp slow_timers(env),
      do: [
        env["f"],
        env["t"],
        env["p"],
        env["r"],
        env["l"],
        elem(env["ts"], 1),
        env["b"]["t"],
        env["d"]["b"]["t"],
        elem(env["bs"], 1)["t"]
      ]

    test "every timer's last is the resource's now, and the resource runs on as start/2's" do
      {:ok, relay} = Logex.compile("var_input in bool\nvar o bool\nxic in ote o", name: "relay")
      blk = block!(@slow_blk)
      deep = block!(@slow_deep, [blk])
      {:ok, fans} = Logex.compile(@slow_fans, name: "fans", types: [blk, deep])

      {:ok, config} =
        Logex.Configuration.compile(
          "plant",
          "task fast interval 10 priority 1\ntask slow interval 100 priority 2\n" <>
            "var_global x bool at panel.i.0\nvar_global lamp bool at panel.q.0\n" <>
            "program m1 relay with fast\nm1.in x\nprogram m2 fans with slow\nm2.run x\n" <>
            "m2.fan lamp",
          %{"relay" => relay, "fans" => fans}
        )

      cycled = fn runtime, inputs -> elem(Runtime.cycle(runtime, 10, inputs), 0) end

      # Run at 0 and 100 with `x` 1, then at 200 with `x` 0, the fan's run-on started: the
      # restart at 250, 50 ms after `m2`'s last scan.
      xs = List.duplicate(1, 15) ++ List.duplicate(0, 10)
      runtime = Enum.reduce(xs, Runtime.start(config), &cycled.(&2, %{"x" => &1}))

      assert {runtime.now, runtime.instances["m2"].now} == {250, 200}
      assert runtime.instances["m2"].env["f"]["tt"] == 1

      restarted = Runtime.restart(runtime, :warm)
      assert restarted.instances["m2"].now == 250

      assert Enum.map(slow_timers(restarted.instances["m2"].env), & &1["last"]) ==
               List.duplicate(250, 9)

      {started, []} = Runtime.start(config, Runtime.retained(runtime))

      {_, runs} =
        Enum.reduce(1..40, {{restarted, started}, []}, fn i, {{a, b}, runs} ->
          {a, out_a, _} = Runtime.cycle(a, 10, %{"x" => 0})
          {b, out_b, _} = Runtime.cycle(b, 10, %{"x" => 0})
          assert out_a == out_b, inspect(i)
          assert Runtime.retained(a) == Runtime.retained(b), inspect(i)
          {{a, b}, [out_a["lamp"] | runs]}
        end)

      # The fan's run-on, started at 200, counts none of the 50 ms before the restart: 10 ms
      # at the slow task's first run after it, 260, and 90 at each run after, so on until
      # its run at 550, the 30th cycle, where counted from its last scan it went off at 450.
      assert Enum.reverse(runs) == List.duplicate(1, 29) ++ List.duplicate(0, 11)
    end
  end

  # The review after Milestone 6 (c4-api-fuzz-1, c4-api-fuzz-5): a plain swap, within the
  # contract, hands a state to a program that declares a retained path the state lacks; a
  # warm restart starts that path at its initial value, as `instance/2` starts a path its
  # image lacks, at any depth, where until then it gave nil or raised, and nothing after it
  # refuses the state; and the image passes it by, blaming no hand edit.
  describe "a warm restart after a plain swap" do
    @swap_block_v1 "function_block blk\nvar_input en bool\nvar n dint\nxic en add n 1 n\n"
    @swap_block_v2 "function_block blk\nvar_input en bool\nvar n dint\nvar retain k dint 7\n" <>
                     "var t ton\nxic en add n 1 n\nxic en add k 1 k\nxic en ton t 5\n"

    # Every way the program swapped in may retain what the state lacks: a tag, a timer that
    # has not run, a member a block's new version adds under a false `cal`, the block
    # retained whole, and that member in every element of an array of the block's
    # instances, the array retained whole too. (A state that lacks an array whole is
    # refused where it is handed in, as one that lacks an array always was.)
    @swaps [
      {"var retain k dint 5\n", "xic go add k 1 k\n", %{"k" => 5}},
      {"var retain t ton\n", "xic go ton t 100\n", :timer},
      {"var b blk\n", "xic go cal b go\n", :member},
      {"var retain b blk\n", "xic go cal b go\n", :member},
      {"var gs blk[2]\n", "xic go cal gs[1] go\n", :members},
      {"var retain gs blk[2]\n", "xic go cal gs[1] go\n", :members}
    ]

    defp swapped({declared, rungs, _}) do
      v1 =
        c!(
          "var_input go bool\nvar c dint\n" <>
            declared_v1(declared) <> "xic go add c 1 c\n" <> rungs_v1(rungs),
          [block!(@swap_block_v1)]
        )

      v2 =
        c!("var_input go bool\nvar c dint\n" <> declared <> "xic go add c 1 c\n" <> rungs, [
          block!(@swap_block_v2)
        ])

      {v1, v2}
    end

    # The original declares the block instances, under its first version, and none of the
    # rest.
    defp declared_v1("var" <> _ = declared), do: blocks_only(declared)
    defp blocks_only(declared), do: block_line(String.contains?(declared, "blk"), declared)
    defp block_line(true, declared), do: declared
    defp block_line(false, _declared), do: ""
    defp rungs_v1(rungs), do: block_line(String.contains?(rungs, "cal"), rungs)

    test "each path the state lacks starts at its initial value, and the state is taken on" do
      for {_, _, expect} = swap <- @swaps do
        {v1, v2} = swapped(swap)
        state = scans(v1, Runtime.instance(v1), [%{"go" => 1}, %{"go" => 1}])
        warm = Runtime.restart(v2, state, :warm)
        assert lacked(expect, warm.env, Runtime.instance(v2).env), inspect(swap)
        taken_on!(v2, warm)

        # Swapped in and scanned with `go` false first, so that no `cal` runs the new body
        # and no rung writes what the state lacks: as the review's repro had it.
        warm = Runtime.restart(v2, scans(v2, state, [%{"go" => 0}]), :warm)
        taken_on!(v2, warm)
      end
    end

    # Nothing after the warm restart refuses the state: a cold restart, inputs, scans and
    # the image.
    defp taken_on!(program, state) do
      assert %Instance{} = Runtime.restart(program, state, :cold)
      assert %Instance{} = Runtime.put_inputs(program, state, %{"go" => 1})
      assert %Instance{} = scans(program, state, [%{"go" => 1}, %{"go" => 1}])
      assert %{program: "m"} = Runtime.retained(program, state)
    end

    defp lacked(%{"k" => k}, env, _fresh), do: env["k"] == k
    defp lacked(:timer, env, fresh), do: env["t"] == fresh["t"]

    defp lacked(:member, env, fresh),
      do: env["b"]["k"] == fresh["b"]["k"] and env["b"]["t"] == fresh["b"]["t"]

    defp lacked(:members, env, fresh),
      do:
        Enum.map(Tuple.to_list(env["gs"]), &Map.take(&1, ["k", "t"])) ==
          Enum.map(Tuple.to_list(fresh["gs"]), &Map.take(&1, ["k", "t"]))

    test "the image of a swapped state lacks what the state lacks, and laid over a new " <>
           "instance starts it as the warm restart does" do
      for {_, _, _} = swap <- @swaps do
        {v1, v2} = swapped(swap)
        state = scans(v1, Runtime.instance(v1), [%{"go" => 1}])
        image = Runtime.retained(v2, state)
        assert {laid, []} = Runtime.instance(v2, image)
        warm = Runtime.restart(v2, state, :warm)

        assert Map.drop(laid.env, ["c", "go"]) ==
                 Map.drop(rebased(warm.env, laid.now), ["c", "go"]),
               inspect(swap)
      end
    end

    # A block instance the state held keeps the timers it holds, each `last` at the
    # restart's `now` (decision 273), where a fresh instance's is 0.
    defp rebased(env, now),
      do: Map.new(env, fn {name, value} -> {name, rebased_value(value, now)} end)

    defp rebased_value(%{"last" => _} = timer, now), do: %{timer | "last" => now}
    defp rebased_value(%{} = map, now), do: rebased(map, now)
    defp rebased_value(value, _now), do: value

    test "a retained path the program's tags do not give is still a hand edit's" do
      {_v1, v2} = swapped(hd(@swaps))
      state = Runtime.instance(v2)
      edited = %{v2 | retained: ["k", "zz"]}

      raises(
        "a warm restart keeps the retained path `zz`, which the program's tags do not give: " <>
          "the program was edited by hand after it was handed in and checked",
        fn -> Runtime.restart(edited, state, :warm) end
      )
    end
  end

  describe "M6-2: the runner's warm restart (decisions 113, 271 and 273)" do
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @plant """
    task fast interval 10 priority 1

    var_global eye_g   bool at panel.i.0
    var_global motor_g bool at panel.i.1
    var_global lamp_g  bool at panel.q.0

    program m1 m with fast
      m1.eye   eye_g
      m1.motor motor_g
      m1.lamp  lamp_g
    """

    defp plant do
      p = c!("var_output lamp bool\n" <> line_source() <> "xic lube.dn ote lamp")
      {:ok, config} = Logex.Configuration.compile("plant", @plant, %{"m" => p})
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 10
        )

      %{runner: runner, clock: clock, panel: panel}
    end

    # The runner trips on the panel's read, stands tripped for a second, and is restarted:
    # warm, the box count, the total and the lube timer are kept and the timer adds none of
    # the second it stood; cold, each is lost.
    test "Runner.restart/2 :warm keeps what is retained, not counting the time it stood " <>
           "tripped, and :cold loses it" do
      %{runner: runner, clock: clock, panel: panel} = plant()
      Sim.set(panel, [1], 1)

      for eye <- [1, 0, 1, 0, 1, 0] do
        Sim.set(panel, [0], eye)
        Manual.advance(clock, 10)
      end

      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert %{status: :tripped, trip: {:io, "panel", {:error, :eio}}} = Runner.status(runner)
      kept = for path <- ~w(m1.boxes.cv m1.total m1.lube.acc), do: Runner.get!(runner, path)
      # The start's first round sees the eye low, so its three rises are counted.
      assert [3, 3, 50] = kept
      assert Runner.get!(runner, "m1.count") == 3

      Manual.advance(clock, 1000)
      assert Runner.restart(runner, :warm) == :ok
      # The restart's first round, at once, scanned with the motor still on.
      assert for(path <- ~w(m1.boxes.cv m1.total m1.lube.acc), do: Runner.get!(runner, path)) ==
               kept

      # Unmarked, the count is put back, the eye low in that round; and the resource's
      # `now` has not moved over the second stood, nor has the timer's.
      assert {Runner.get!(runner, "m1.count"), Runner.status(runner).now} == {0, 60}
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "m1.lube.acc") == 60

      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert Runner.restart(runner, :cold) == :ok

      assert for(path <- ~w(m1.boxes.cv m1.total m1.lube.acc), do: Runner.get!(runner, path)) ==
               [0, 0, 0]

      Runner.stop(runner)
    end
  end

  defp reductions(fun) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 8_000_000]
      )

    assert_receive {:reductions, r}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    r
  end

  # ---- the rule restated, for the seeded programs above ------------------------------

  # Whether one of `paths` covers a leaf: the leaf itself, or a path above it.
  defp covered?(leaf, paths), do: Enum.any?(paths, &above?(&1, leaf))

  defp above?(path, path), do: true

  defp above?(path, leaf),
    do: String.starts_with?(leaf, path <> ".") or String.starts_with?(leaf, path <> "[*].")

  # A draw: two to three block types, each holding the one before it, and a program of
  # instances of each, every line's qualifier drawn; and each leaf's path with whether the
  # rule restated retains it.
  defp rule_draw do
    count = 2 + :rand.uniform(2)

    {sources, leaves_of} =
      Enum.reduce(1..count, {[], %{}}, fn i, {sources, leaves_of} ->
        {src, leaves} = rule_block(i, leaves_of)
        {sources ++ [src], Map.put(leaves_of, i, leaves)}
      end)

    lines =
      for i <- 1..count, k <- 1..2 do
        q = rule_qualifier()
        array = :rand.uniform(3) == 1
        {name, type} = rule_instance("p#{i}_#{k}", i, array)
        {"var #{rule_word(q)}#{name} #{type}", {name, i, array, q}}
      end

    elementary = for k <- 1..2, do: {"e#{k}", rule_qualifier()}

    program =
      Enum.map_join(lines, "\n", &elem(&1, 0)) <>
        "\n" <>
        Enum.map_join(elementary, "\n", fn {n, q} -> "var #{rule_word(q)}#{n} dint" end) <>
        "\nvar go bool\nvar q bool\n" <>
        Enum.map_join(lines, "\n", fn {_, {name, _i, array, _q}} -> rule_cal(name, array) end)

    leaves =
      Enum.flat_map(lines, fn {_, {name, i, array, q}} ->
        for {path, flag} <- leaves_of[i],
            do: {rule_prefix(name, array) <> path, rule_nearest(flag, rule_flag(q, false))}
      end) ++
        for({n, q} <- elementary, do: {n, rule_flag(q, false)}) ++
        [{"go", false}, {"q", false}]

    {sources, program, leaves}
  end

  # A block's members: its two formals, a dint and a timer, each line's qualifier drawn,
  # and an instance of the block below, scalar or an array; each leaf relative, its flag
  # the member's own qualifier, or `:inherit` where its line has none.
  defp rule_block(i, leaves_of) do
    members = for m <- ~w(go q k t), do: {m, rule_qualifier()}
    nested = rule_nested(i, leaves_of)

    decls =
      Enum.map_join(members, "\n", fn {m, q} ->
        "#{rule_section(m)} #{rule_word(q)}#{m} #{rule_type(m)}"
      end)

    src =
      "function_block b#{i}\n" <>
        decls <>
        rule_nested_decl(nested) <>
        "\nxic go ton t 10\nxic t.dn ote q\nxic go move 1 k" <>
        rule_nested_cal(nested)

    own = for {m, q} <- members, do: {m, rule_mark(q)}
    {src, own ++ rule_nested_leaves(nested)}
  end

  defp rule_nested(1, _leaves_of), do: nil

  defp rule_nested(i, leaves_of),
    do: {"n", i - 1, :rand.uniform(2) == 1, rule_qualifier(), leaves_of[i - 1]}

  defp rule_nested_decl(nil), do: ""

  defp rule_nested_decl({name, below, array, q, _leaves}) do
    {name, type} = rule_instance(name, below, array)
    "\nvar #{rule_word(q)}#{name} #{type}"
  end

  defp rule_nested_cal(nil), do: ""
  defp rule_nested_cal({name, _below, array, _q, _leaves}), do: "\n" <> rule_cal(name, array)

  defp rule_nested_leaves(nil), do: []

  defp rule_nested_leaves({name, _below, array, q, leaves}),
    do:
      for(
        {path, flag} <- leaves,
        do: {rule_prefix(name, array) <> path, rule_nested_flag(flag, rule_mark(q))}
      )

  # Inside a block a nested member's flag: its own mark, else its instance line's, else
  # inherited from further out.
  defp rule_nested_flag(:inherit, outer), do: outer
  defp rule_nested_flag(flag, _outer), do: flag

  defp rule_nearest(:inherit, outer), do: outer
  defp rule_nearest(flag, _outer), do: flag

  defp rule_mark(:retain), do: true
  defp rule_mark(:non_retain), do: false
  defp rule_mark(nil), do: :inherit

  defp rule_flag(:retain, _held), do: true
  defp rule_flag(:non_retain, _held), do: false
  defp rule_flag(nil, held), do: held

  defp rule_qualifier, do: Enum.at([nil, nil, :retain, :non_retain], :rand.uniform(4) - 1)

  defp rule_word(nil), do: ""
  defp rule_word(q), do: "#{q} "

  defp rule_section("go"), do: "var_input"
  defp rule_section("q"), do: "var_output"
  defp rule_section(_m), do: "var"

  defp rule_type("t"), do: "ton"
  defp rule_type("k"), do: "dint"
  defp rule_type(_bool), do: "bool"

  defp rule_instance(name, i, false), do: {name, "b#{i}"}
  defp rule_instance(name, i, true), do: {name, "b#{i}[2]"}

  defp rule_prefix(name, false), do: name <> "."
  defp rule_prefix(name, true), do: name <> "[*]."

  defp rule_cal(name, false), do: "cal #{name} go q"
  defp rule_cal(name, true), do: "cal #{name}[0] go q\ncal #{name}[1] go q"
end
