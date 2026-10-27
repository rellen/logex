defmodule Logex.RetainTest do
  @moduledoc """
  Milestone 6 (`docs/organisation.md` §4.13): M6-1's words, `retain` and `non_retain`,
  their lines and refusals, and `Logex.Program`'s `retained`, settled by the nearest mark
  on a member's path (decisions 266 to 270). Each rule a test that fails when it alone is
  reverted. The warm restart that keeps what is marked is M6-2's, which lands in the same
  push; the configuration's `var_global retain`, the image and the store are later items'
  (M6-3 to M6-5).
  """
  use ExUnit.Case, async: true

  alias Logex.{Program, Runtime, Tag}

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
      assert %Tag{retain: :retain} = Tag.new!("c", :dint, :var, nil, :retain)
      assert %Tag{retain: :non_retain} = Tag.new!("c", :dint, :var_output, 3, :non_retain)
      assert %Tag{retain: nil} = Tag.new!("c", :dint)
      assert %Tag{retain: :retain} = Tag.new!("t", Logex.FbType.ton(), :var, nil, :retain)

      raises(
        "`e` is a var_external, which takes no `retain`: its global carries it, as the " <>
          "configuration declares it",
        fn -> Tag.new!("e", :bool, :var_external, nil, :retain) end
      )

      raises(
        "unknown qualifier true on `c`: logex has :retain and :non_retain, or nil for none",
        fn -> Tag.new!("c", :dint, :var, nil, true) end
      )

      # A program's var_input, which only the compile tells from a block's.
      {:ok, tokens, _} = Logex.Compiler.tokenize("var x bool\nxic i ote x")
      {:ok, routine} = Logex.Compiler.parse(tokens)
      i = Tag.new!("i", :bool, :var_input, nil, :retain)

      raises(
        "`i` is a program's var_input, which takes no `retain`: a var_input holds the " <>
          "host's value, which every restart keeps where it fits",
        fn -> Logex.Compiler.instructionize(routine, [i]) end
      )

      assert {:ok, %Program{retained: ["c"]}} =
               Logex.Compiler.instructionize(routine, [
                 Tag.new!("i", :bool, :var_input),
                 Tag.new!("c", :dint, :var, nil, :retain)
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
