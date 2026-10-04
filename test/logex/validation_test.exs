defmodule Logex.ValidationTest do
  @moduledoc """
  M1-2: `instructionize/2` checks every instruction against its operand signature and
  returns located diagnostics instead of raising. M1-3: it reads the declaration lines
  into a tag table and checks every operand against it. Each case is here, driven from
  source text, and each asserts the whole diagnostic list, so a missing, extra or
  cascading diagnostic fails as surely as a wrong one.
  """
  use ExUnit.Case, async: true

  # M2-5: what Logex.Declarations.check/1 says an unknown function block type is not.
  @given "and the types Logex.compile/2 gives for a function block's file"

  alias Logex.Compiler

  # The operand-shape cases below are about instructions, not tags, so their tags are
  # declared from Elixir and every line they assert stays where M1-2 put it.
  @declared Enum.map(~w(aa bb cc dd src x a b mov bst nxb), &Logex.Tag.new!(&1, :bool))

  describe "the cases that used to raise or pass silently" do
    test "an unknown mnemonic is named, with its line" do
      assert errors("zzz aa") == ["line 1: unknown instruction `zzz`"]
    end

    test "an extra tag operand is read as the next instruction, and named" do
      assert errors("xic aa bb") == ["line 1: unknown instruction `bb`"]
    end

    test "an extra literal operand, or a literal where an instruction starts, is named" do
      assert errors("xic aa 7 ote bb") == ["line 1: expected an instruction, found `7`"]
      assert errors("123 aa") == ["line 1: expected an instruction, found `123`"]
    end

    test "a missing operand is counted" do
      assert errors("ote") == ["line 1: `ote` expects 1 operand (a tag), found none"]

      assert errors("move src") == [
               "line 1: `move` expects 2 operands (a value, then a tag), found 1"
             ]
    end

    test "a mnemonic is never taken as an operand" do
      # The worst case: no exception, and a coil became a tag called `ote`.
      assert errors("move src ote") == [
               "line 1: `move` expects 2 operands (a value, then a tag), found 1 " <>
                 "before the instruction `ote`",
               "line 1: `ote` expects 1 operand (a tag), found none"
             ]

      # Stopping at the mnemonic keeps the instruction after it intact.
      assert errors("move src ote bb") == [
               "line 1: `move` expects 2 operands (a value, then a tag), found 1 " <>
                 "before the instruction `ote`"
             ]
    end

    test "a branch group is never taken as an operand" do
      assert errors("ote ( xic a )") == [
               "line 1: `ote` expects 1 operand (a tag), found none before a branch group"
             ]

      # After the group, `b` is where an instruction starts, and is reported as one: the
      # writer may have meant it as move's destination or as a new instruction.
      assert errors("move ( xic a ) b") == [
               "line 1: `move` expects 2 operands (a value, then a tag), found none " <>
                 "before a branch group",
               "line 1: unknown instruction `b`"
             ]
    end

    test "a literal where a tag must go is named" do
      assert errors("ote 7") == ["line 1: `ote` expects a tag, found `7`"]
      assert errors("OTE 7") == ["line 1: `OTE` expects a tag, found `7`"]
      assert errors("move 1 2") == ["line 1: `move` expects a tag, found `2`"]
    end
  end

  describe "mnemonics" do
    test "are matched in any case" do
      assert run("XIC aa Ote bb", %{"aa" => 1}) == %{"aa" => 1, "bb" => 1}
    end

    test "are reserved in any case: none may name a tag" do
      # Two diagnostics, because which mistake was made cannot be known: `OTE` meant as
      # a tag, or two forgotten operands. Both say only what is there.
      assert errors("xic OTE") == [
               "line 1: `xic` expects 1 operand (a tag), found none before the instruction `OTE`",
               "line 1: `OTE` expects 1 operand (a tag), found none"
             ]
    end

    test "the old `mov` is not an alias: it is named, and pointed at `move`" do
      message = "unknown instruction `mov` — did you mean `move`? (renamed to its IEC name)"
      assert errors("mov 1 aa") == ["line 1: " <> message]

      assert errors("xic bb\nMOV aa cc") == [
               "line 2: " <> String.replace(message, "`mov`", "`MOV`")
             ]
    end

    test "`mov` is an ordinary tag name again" do
      assert run("xic mov ote x", %{"mov" => 1}) == %{"mov" => 1, "x" => 1}
    end

    test "a tag may still be named after an old branch keyword" do
      assert run("xic bst ote nxb", %{"bst" => 1}) == %{"bst" => 1, "nxb" => 1}
    end
  end

  describe "diagnostics" do
    test "are all reported, in source order, each with its own line" do
      assert errors("zzz\nxic aa ote bb\n( xic cc | ote 7 )\nqqq") == [
               "line 1: unknown instruction `zzz`",
               "line 3: `ote` expects a tag, found `7`",
               "line 4: unknown instruction `qqq`"
             ]

      assert errors("xic aa\note") == ["line 2: `ote` expects 1 operand (a tag), found none"]

      assert errors("zzz\n7 aa") == [
               "line 1: unknown instruction `zzz`",
               "line 2: expected an instruction, found `7`"
             ]
    end

    test "come from every leg of a branch group, in order" do
      assert errors("( ote 7 | xic aa )") == ["line 1: `ote` expects a tag, found `7`"]

      assert errors("( zzz | qqq )") == [
               "line 1: unknown instruction `zzz`",
               "line 1: unknown instruction `qqq`"
             ]
    end

    test "skip what follows a word that is not an instruction, up to the next one" do
      # The instruction the skip stops at has a mistake of its own, so a skip that went
      # too far would hide it.
      assert errors("zzz aa 7 bb ote 7") == [
               "line 1: unknown instruction `zzz`",
               "line 1: `ote` expects a tag, found `7`"
             ]

      assert errors("xic aa 7 ote 7") == [
               "line 1: expected an instruction, found `7`",
               "line 1: `ote` expects a tag, found `7`"
             ]

      assert errors("zzz aa OTE 7") == [
               "line 1: unknown instruction `zzz`",
               "line 1: `OTE` expects a tag, found `7`"
             ]

      assert errors("zzz aa ( xic bb ) qqq") == [
               "line 1: unknown instruction `zzz`",
               "line 1: unknown instruction `qqq`"
             ]
    end

    test "the old branch keywords name the migration, in any case" do
      assert errors("BST xic aa") == [
               "line 1: `BST` is no longer a keyword — branches are written `( … | … )`"
             ]
    end
  end

  describe "the IR" do
    test "every instruction carries its mnemonic's line" do
      assert {:ok, %Logex.Program{rungs: [{:rung, [{:xic, 3, _}, {:move, 3, _}]}]}} =
               compile("\n\nxic aa move 1 bb")
    end

    test "declaration lines become the tag table, not rungs" do
      assert {:ok, %Logex.Program{rungs: [{:rung, [{:xic, 3, _}, {:move, 3, _}]}], tags: tags}} =
               source_compile("var_input go bool\nvar_output sp dint 1200\nxic go move 0 sp")

      assert tags == %{
               "go" => %Logex.Tag{name: "go", type: :bool, section: :var_input, line: 1},
               "sp" => %Logex.Tag{
                 name: "sp",
                 type: :dint,
                 section: :var_output,
                 initial: 1200,
                 line: 2
               }
             }
    end
  end

  describe "the entry check (OE-1): only a tree Logex.Parser.parse/1 could produce" do
    # Decision 28: a tree built as data that no text could have said is a host mistake,
    # refused before any stage reads it, by an ArgumentError naming the first node that
    # parse/1 could not have produced. Logex.Parser.well_formed!/1 states the shape.
    @refused "not a tree Logex.Parser.parse/1 can produce: "

    defp refused(tree, message, declared \\ []) do
      assert_raise ArgumentError, @refused <> message, fn ->
        Compiler.instructionize(tree, declared)
      end
    end

    defp rungs(rungs), do: {:routine, {:rungs, rungs}}

    # A good rung on line 1, so a broken node is never the first thing the walk meets.
    @good {:rung, [{:name, 1, "xic"}, {:name, 1, "aa"}]}

    test "a tree that is not {:routine, {:rungs, rungs}}, checked before declared" do
      for tree <- [:motor, {:routine, []}, {:routine, {:rungs, :x}}, {:rungs, []}, [@good]] do
        refused(tree, "a tree is {:routine, {:rungs, rungs}}, got: #{inspect(tree)}")
      end

      refused(:motor, "a tree is {:routine, {:rungs, rungs}}, got: :motor", :not_a_list)
    end

    test "an empty rung, or a rung of no known shape" do
      for rung <- [{:rung, []}, {:rung, :x}, {:rung, [{:name, 1, "a"}], 1}, :x, []] do
        refused(
          rungs([@good, rung]),
          "a rung is {:rung, elements}, with one element or more, got: #{inspect(rung)}"
        )
      end
    end

    test "an element of no known shape, an instruction of the IR among them" do
      for element <- [{:xic, 2, [{:name, 2, "aa"}]}, {:name, 2}, {:name, 2, "a", 2}, "xic", nil] do
        refused(
          rungs([@good, {:rung, [{:name, 2, "xic"}, element]}]),
          "an element is {:name, line, word}, {:int_lit, line, n} or {:branches, legs}, " <>
            "got: #{inspect(element)}"
        )
      end
    end

    test "a name whose word does not lex as one name token" do
      for word <- ["a b", "", "7", "t1.", "a//b", "é", "a\n", "(", :aa, ~c"aa", 7] do
        name = {:name, 2, word}

        refused(
          rungs([@good, {:rung, [{:name, 2, "xic"}, name]}]),
          "a name's word lexes as one name token, got: #{inspect(name)}"
        )
      end

      # The lexer is the rule, so a name with `.` parts is a name, as in source.
      tree = rungs([{:rung, [{:name, 1, "xic"}, {:name, 1, "t1.dn"}, {:name, 1, "ote"}]}])
      assert {:error, _undeclared} = Compiler.instructionize(tree)
    end

    test "a negative literal, or one that is not an integer, in a declaration line too" do
      for value <- [-1, -2_147_483_648, 1.5, :x, "1"] do
        literal = {:int_lit, 2, value}

        message =
          "a literal is an integer, 0 or more: a negative one does not lex yet " <>
            "(PLAN.md §5), got: #{inspect(literal)}"

        refused(rungs([@good, {:rung, [{:name, 2, "move"}, literal, {:name, 2, "aa"}]}]), message)

        refused(
          rungs([{:rung, [{:name, 2, "var"}, {:name, 2, "k"}, {:name, 2, "dint"}, literal]}]),
          message
        )
      end

      # The lexer reads any number of digits, so a literal of any size is a tree, and the
      # compiler says what it does not fit.
      tree = rungs([{:rung, [{:name, 1, "move"}, {:int_lit, 1, 10 ** 40}, {:name, 1, "aa"}]}])

      assert {:error, [%Logex.Diagnostic{message: "`move` writes `1" <> _}]} =
               Compiler.instructionize(tree, @declared)
    end

    test "a branch group with no legs, which differs from one with an empty leg" do
      for group <- [{:branches, []}, {:branches, :x}, {:branches, {[]}}] do
        refused(
          rungs([@good, {:rung, [group, {:name, 2, "ote"}, {:name, 2, "aa"}]}]),
          "a branch group is {:branches, legs}, with one leg or more: `( )` is one empty " <>
            "leg, got: #{inspect(group)}"
        )
      end

      # One empty leg is `( )`, a jumper.
      tree = rungs([{:rung, [{:branches, [[]]}, {:name, 1, "ote"}, {:name, 1, "aa"}]}])
      assert {:ok, _} = Compiler.instructionize(tree, @declared)
    end

    test "a leg that is not a list of elements" do
      for leg <- [:x, {:name, 2, "aa"}, nil] do
        refused(
          rungs([@good, {:rung, [{:branches, [[], leg]}, {:name, 2, "ote"}, {:name, 2, "aa"}]}]),
          "a leg is a list of elements, got: #{inspect(leg)}"
        )
      end
    end

    test "a line that is not a positive integer, on a name or a literal, in a group too" do
      for line <- [nil, 0, -3, 1.0, "2", :two] do
        name = {:name, line, "aa"}
        literal = {:int_lit, line, 5}
        message = &"a line is a positive integer, got: #{inspect(&1)}"

        refused(rungs([{:rung, [name]}]), message.(name))
        refused(rungs([{:rung, [literal]}]), message.(literal))
        refused(rungs([{:rung, [{:branches, [[], [{:branches, [[name]]}]]}]}]), message.(name))
      end
    end

    test "a rung over two lines, in a group nested in another too" do
      refused(
        rungs([@good, {:rung, [{:name, 2, "xic"}, {:name, 3, "aa"}]}]),
        ~s|a rung is one line, and this one began on line 2, got: {:name, 3, "aa"}|
      )

      deep = {:branches, [[{:name, 2, "xic"}], [{:branches, [[], [{:int_lit, 1, 7}]]}]]}

      refused(
        rungs([{:rung, [deep]}]),
        "a rung is one line, and this one began on line 2, got: {:int_lit, 1, 7}"
      )
    end

    test "two rungs on one line, or out of order" do
      later = {:rung, [{:name, 1, "ote"}, {:name, 1, "bb"}]}

      refused(
        rungs([@good, later]),
        ~s|each rung starts on a line of its own, after line 1, got: {:name, 1, "ote"}|
      )

      refused(
        rungs([{:rung, [{:name, 3, "xic"}, {:name, 3, "aa"}]}, @good]),
        ~s|each rung starts on a line of its own, after line 3, got: {:name, 1, "xic"}|
      )

      # From text, two rungs are on two lines, and the second `ote` is warned about; as two
      # rungs on one line built as data, it went unwarned before the entry check.
      assert source_warnings("var a bool\nxic a ote a\nxio a ote a") == [
               "line 3: warning: `a` already has an `ote` on line 2: the last one in the scan " <>
                 "decides it"
             ]
    end

    test "a rung of nothing but empty groups carries no line, but stands on a line of its own" do
      jumper = {:rung, [{:branches, [[], [{:branches, [[]]}]]}]}
      on = &{:rung, [{:name, &1, "ote"}, {:name, &1, "aa"}]}

      # From text: `ote aa`, then `( | ( ) )`, then `ote aa` on the line after.
      assert {:ok, _} = Compiler.instructionize(rungs([on.(1), jumper, on.(3)]), @declared)
      assert {:ok, _} = Compiler.instructionize(rungs([jumper, jumper, on.(3)]), @declared)

      refused(
        rungs([on.(1), jumper, on.(2)]),
        ~s|each rung starts on a line of its own, after line 2, got: {:name, 2, "ote"}|
      )

      refused(
        rungs([jumper, on.(1)]),
        ~s|each rung starts on a line of its own, after line 1, got: {:name, 1, "ote"}|
      )
    end

    test "an improper list of rungs, of elements or of legs" do
      for tree <- [
            {:routine, {:rungs, [@good | :x]}},
            rungs([@good, {:rung, [{:name, 2, "ote"} | :x]}]),
            rungs([@good, {:rung, [{:branches, [[] | :x]}]}]),
            rungs([@good, {:rung, [{:branches, [[{:name, 2, "ote"} | :x]]}]}])
          ] do
        refused(tree, "every list in it ends in [], got a list ending in: :x")
      end
    end
  end

  describe "declaration lines (M1-3)" do
    test "section and type words match in any case; the tag keeps its own" do
      assert {:ok, %Logex.Program{tags: %{"Start" => %Logex.Tag{section: :var_input}}}} =
               source_compile("VAR_INPUT Start BOOL\nVar Run Bool\nxic Start ote Run")
    end

    test "a tag declared twice is named, with the first declaration's line" do
      assert source_errors("var a bool\nvar a dint") == [
               "line 2: `a` is declared twice: first on line 1"
             ]
    end

    test "two tags differing only in case are an error" do
      assert source_errors("var a bool\nvar A bool") == [
               "line 2: `A` and `a` (line 1) differ only in case: tags are case-sensitive, " <>
                 "so these would be two tags"
             ]
    end

    test "a declaration after the first rung is named, and still declares its tag" do
      assert source_errors("var a bool\nxic a ote b\nvar b bool") == [
               "line 3: `var` after the first rung (line 2): declarations come first"
             ]
    end

    test "diagnostics from declaration lines and from rungs come in line order" do
      assert source_errors("var a bool\nzzz\nvar b bool\nyyy") == [
               "line 2: unknown instruction `zzz`",
               "line 3: `var` after the first rung (line 2): declarations come first",
               "line 4: unknown instruction `yyy`"
             ]
    end

    test "a section word where an instruction starts is named as a declaration" do
      assert source_errors("var aa bool\nxic aa var bb") == [
               "line 2: `var` starts a declaration, which is a line of its own before the first rung"
             ]
    end

    test "every malformed line is named, each with its own line" do
      assert source_errors(
               "var b\nvar c int\nvar e bool 2\nvar f dint 3000000000\nvar ote bool\n" <>
                 "var Bool bool\nvar var_input bool\nvar 7 bool\nvar g bool 1 2\nvar x 5\n" <>
                 "var\nvar_input i bool 1\nvar h ( xic a )\nvar retain r bool\nvar p q bool"
             ) == [
               "line 1: `b` needs a type: `var b bool` or `var b dint`",
               "line 2: unknown type `int`: logex has `bool`, `dint` and `ton`",
               "line 3: `e` is a bool: its initial value must be 0 or 1, found `2`",
               "line 4: `f` is a dint: `3000000000` does not fit in 32 bits",
               "line 5: `ote` is an instruction and cannot name a tag",
               "line 6: `Bool` is a type and cannot name a tag",
               "line 7: `var_input` is a keyword and cannot name a tag",
               "line 8: expected a tag name after `var`, found `7`",
               "line 9: unexpected `2` after the declaration of `g`",
               "line 10: `x` needs a type before its initial value `5`",
               "line 11: `var` needs a tag name and a type, as in `var fault bool`",
               "line 12: `i` is a var_input: its value comes from outside, so it takes no initial value",
               "line 13: a declaration cannot hold a branch group",
               "line 14: `retain` is not supported yet: a warm restart, like a cold one, " <>
                 "starts every tag at its initial value but the var_inputs whose values fit " <>
                 "their types",
               "line 15: `var` declares one tag: found `p` and `q` before the type"
             ]
    end

    test "a dint's largest value, and a bool's 0 and 1, are initial values" do
      assert {:ok, %Logex.Program{tags: tags}} =
               source_compile(
                 "var lo dint 0\nvar hi dint 2147483647\nvar t bool 1\nvar f bool 0\nxic t ote f"
               )

      assert Map.new(tags, fn {name, tag} -> {name, tag.initial} end) ==
               %{"lo" => 0, "hi" => 2_147_483_647, "t" => 1, "f" => 0}
    end
  end

  describe "declaration lines, the rarer shapes (M1-3)" do
    # A name with `.` parts is one token since PLAN.md §5's rule landed, and the `.` is for
    # members, so it names no tag. Until M1-6 declares members, using one is undeclared.
    test "a name with a `.` cannot be declared, and is undeclared where it is used" do
      assert source_errors("var t1.dn bool\nvar word.3 dint\nvar a bool\nxic t1.dn ote a") == [
               "line 1: `t1.dn` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`",
               "line 2: `word.3` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`",
               "line 4: `t1` is not declared"
             ]

      # Refused for its name even with no type, rather than told to add one.
      assert source_errors("var m1.t1.acc\nvar_input x.y 5\nvar a bool\nxic a ote a") == [
               "line 1: `m1.t1.acc` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`",
               "line 2: `x.y` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`"
             ]
    end

    test "a line breaking two rules gets both, in order" do
      assert source_errors("var ote bool 2") == [
               "line 1: `ote` is an instruction and cannot name a tag",
               "line 1: `ote` is a bool: its initial value must be 0 or 1, found `2`"
             ]

      assert source_errors("xic a ote a\nvar b") == [
               "line 1: `a` is not declared",
               "line 2: `var` after the first rung (line 1): declarations come first",
               "line 2: `b` needs a type: `var b bool` or `var b dint`"
             ]
    end

    test "a branch group anywhere in a declaration gets one message" do
      assert source_errors("var ( xic a )\nvar g bool ( xic a )\nvar h bool 1 ( xic a )") == [
               "line 1: a declaration cannot hold a branch group",
               "line 2: a declaration cannot hold a branch group",
               "line 3: a declaration cannot hold a branch group"
             ]
    end

    test "anything after a declaration's type and initial value is named" do
      assert source_errors("var g bool x\nvar h bool 1 x") == [
               "line 1: unexpected `x` after the declaration of `g`",
               "line 2: unexpected `x` after the declaration of `h`"
             ]
    end

    test "a reserved word where the tag name belongs is named for what it is" do
      assert source_errors("var bool\nvar dint 5\nvar xic\nvar var\nvar Ote bool") == [
               "line 1: `var` needs a tag name before the type `bool`, as in `var fault bool`",
               "line 2: `var` needs a tag name before the type `dint`, as in `var fault dint`",
               "line 3: `xic` is an instruction and cannot name a tag",
               "line 4: `var` is a keyword and cannot name a tag",
               "line 5: `Ote` is an instruction and cannot name a tag"
             ]
    end

    test "two names before the type are named, however the line goes on" do
      assert source_errors("var p q bool 1\nvar p q r bool\nvar p q ote") == [
               "line 1: `var` declares one tag: found `p` and `q` before the type",
               "line 2: `var` declares one tag: found `p` and `q` before the type",
               "line 3: unknown type `q`: logex has `bool`, `dint` and `ton`"
             ]
    end

    test "`retain` is recognised in any case, and the section word is quoted as written" do
      assert source_errors("VAR RETAIN r bool\nVAR b") == [
               "line 1: `retain` is not supported yet: a warm restart, like a cold one, " <>
                 "starts every tag at its initial value but the var_inputs whose values fit " <>
                 "their types",
               "line 2: `b` needs a type: `VAR b bool` or `VAR b dint`"
             ]

      assert source_errors("VAR a bool\nxic a ote a\nVAR b bool") == [
               "line 3: `VAR` after the first rung (line 2): declarations come first"
             ]
    end

    test "a late declaration cites the first rung's own line, or none when it has none" do
      assert source_errors("var a bool\n( xic a )\nxic a ote a\nvar b bool") == [
               "line 4: `var` after the first rung (line 2): declarations come first"
             ]

      assert source_errors("var a bool\n( )\nxic a ote a\nvar b bool") == [
               "line 4: `var` after the first rung: declarations come first"
             ]

      assert source_errors("var a bool\n( )\nvar b bool") == [
               "line 3: `var` after the first rung: declarations come first"
             ]
    end

    test "a type word where an instruction starts is an unknown instruction" do
      assert source_errors("bool a") == ["line 1: unknown instruction `bool`"]
    end

    test "the dint range ends exactly at 2147483647" do
      assert source_errors("var f dint 2147483648\nvar d dint\nmove 2147483648 d") == [
               "line 1: `f` is a dint: `2147483648` does not fit in 32 bits",
               "line 3: `move` writes `2147483648` into `d`, a dint: it does not fit in 32 bits"
             ]
    end

    test "after a clash the first declaration is the one in the table" do
      assert source_errors("var a bool\nvar a dint\nxic a ote a") == [
               "line 2: `a` is declared twice: first on line 1"
             ]

      assert source_errors("var a bool\nvar A bool\nxic A ote a") == [
               "line 2: `A` and `a` (line 1) differ only in case: tags are case-sensitive, " <>
                 "so these would be two tags",
               "line 3: `A` is not declared — did you mean `a`? (tags are case-sensitive)"
             ]
    end

    test "Logex.Declarations.split/2 gives its diagnostics in line order" do
      {:ok, tokens, _} = Compiler.tokenize("var a bool\nvar a bool\nvar b int")
      {:ok, {:routine, {:rungs, rungs}}} = Compiler.parse(tokens)
      {_tags, [], diagnostics} = Logex.Declarations.split(rungs)
      assert Enum.map(diagnostics, & &1.line) == [2, 3]
    end
  end

  describe "strictness (M1-3): every tag a rung uses is declared" do
    test "an undeclared tag is named once, at its first use, with the nearest declared name" do
      assert source_errors("var_input start bool\nvar m bool\nxic strat ote m\nxic strat ote m") ==
               ["line 3: `strat` is not declared — did you mean `start`?"]
    end

    test "a tag far from every declared name gets no suggestion" do
      assert source_errors("var_input start bool\nxic start ote horn") ==
               ["line 2: `horn` is not declared"]
    end

    test "a tag differing from a declared one only in case is named as such" do
      assert source_errors("var motor bool\nxic Motor ote motor") == [
               "line 2: `Motor` is not declared — did you mean `motor`? (tags are case-sensitive)"
             ]
    end

    test "is checked in every leg of a branch group" do
      assert source_errors("var a bool\n( xic a | xic zz ) ote a") == [
               "line 2: `zz` is not declared"
             ]
    end

    test "a near miss is suggested, and a far one is not" do
      assert source_errors("var start bool\nxic stort ote start") == [
               "line 2: `stort` is not declared — did you mean `start`?"
             ]

      assert source_errors("var lamp bool\nxic lmp_x ote lamp") == [
               "line 2: `lmp_x` is not declared"
             ]

      # Either side of the 0.8 cut-off: a Jaro distance of 0.815, and of 0.790.
      assert source_errors("var stop bool\nxic stop_hold ote stop") == [
               "line 2: `stop_hold` is not declared — did you mean `stop`?"
             ]

      assert source_errors("var start bool\nxic stat_pb ote start") == [
               "line 2: `stat_pb` is not declared"
             ]
    end

    test "the how-to note needs a program with no declaration at all, and survives other errors" do
      assert source_errors("xic zz ote a", [Logex.Tag.new!("a", :bool)]) == [
               "line 1: `zz` is not declared"
             ]

      assert source_errors("zzz\nxic a") == [
               "line 1: unknown instruction `zzz`",
               "line 2: `a` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var a bool` or `var a dint`)"
             ]
    end

    test "a program that declares nothing is told how, once" do
      assert source_errors("xic a ote b") == [
               "line 1: `a` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var a bool` or `var a dint`)",
               "line 1: `b` is not declared"
             ]
    end

    test "a name with a `.` is not told to declare itself; the next name is" do
      assert source_errors("xic t1.dn ote b") == [
               "line 1: `t1` is not declared",
               "line 1: `b` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var b bool` or `var b dint`)"
             ]
    end

    test "a name a `ton` runs is shown the one declaration that fits it" do
      assert source_errors("ton t1 5000\nxic t1.dn ote lamp") == [
               "line 1: `t1` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var t1 ton`)",
               "line 2: `lamp` is not declared"
             ]
    end

    test "so is a timer first used as a member, or whole as a bool, that a `ton` runs" do
      assert source_errors("xio t1.dn ton t1 1000\nxic t1.dn ote pulse") == [
               "line 1: `t1` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var t1 ton`)",
               "line 2: `pulse` is not declared"
             ]

      assert source_errors("xic t1 ote x\nton t1 5000") == [
               "line 1: `t1` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var t1 ton`)",
               "line 1: `x` is not declared"
             ]
    end

    test "a program whose declarations were all wrong is not told it declares nothing" do
      assert source_errors("var a int\nxic a ote a") == [
               "line 1: unknown type `int`: logex has `bool`, `dint` and `ton`",
               "line 2: `a` is not declared"
             ]
    end
  end

  describe "types and roles (M1-3)" do
    test "a dint on a contact or coil is named, with its declaration" do
      assert source_errors("var d dint\nvar b bool\nxic d ote b\nxic b ote d") == [
               "line 3: `xic` reads a bool, but `d` is a dint (declared on line 1)",
               "line 4: `ote` writes a bool, but `d` is a dint (declared on line 1)"
             ]
    end

    test "xio, otl and otu take only a bool, as xic and ote do" do
      assert source_errors("var d dint\nvar b bool\nxic b xio d ote b\nxic b otl d\nxic b otu d") ==
               [
                 "line 3: `xio` reads a bool, but `d` is a dint (declared on line 1)",
                 "line 4: `otl` writes a bool, but `d` is a dint (declared on line 1)",
                 "line 5: `otu` writes a bool, but `d` is a dint (declared on line 1)"
               ]
    end

    test "logic cannot write a var_input, by any instruction that writes" do
      assert source_errors(
               "var_input i bool\nvar_input n dint\nvar b bool\n" <>
                 "xic b ote i\nxic b otl i\nxic b otu i\nmove 5 n"
             ) == [
               "line 4: `ote` writes `i`, a var_input (declared on line 1): logic must not write an input",
               "line 5: `otl` writes `i`, a var_input (declared on line 1): logic must not write an input",
               "line 6: `otu` writes `i`, a var_input (declared on line 1): logic must not write an input",
               "line 7: `move` writes `n`, a var_input (declared on line 2): logic must not write an input"
             ]
    end

    test "logic may read a var_input and read and write a var_output" do
      assert {:ok, _} =
               source_compile("var_input i bool\nvar_output o bool\n( xic i | xic o ) ote o")
    end

    test "move takes operands of one type" do
      assert source_errors("var b bool\nvar d dint\nmove b d\nmove d b\nmove d d\nmove b b") == [
               "line 3: `move` takes operands of one type: `b` is a bool, `d` is a dint",
               "line 4: `move` takes operands of one type: `d` is a dint, `b` is a bool"
             ]
    end

    test "a literal must fit the tag move writes it into" do
      assert source_errors(
               "var b bool\nvar d dint\nmove 2 b\nmove 3000000000 d\n" <>
                 "move 1 b\nmove 0 b\nmove 2147483647 d"
             ) == [
               "line 3: `move` writes `2` into `b`, a bool: only 0 or 1 fit",
               "line 4: `move` writes `3000000000` into `d`, a dint: it does not fit in 32 bits"
             ]
    end

    test "a literal where a tag must go is reported once, not range-checked too" do
      assert source_errors("var b bool\nxic b ote 7\nmove 3000000000 7") == [
               "line 2: `ote` expects a tag, found `7`",
               "line 3: `move` expects a tag, found `7`"
             ]
    end

    test "a keyword or type is not a tag" do
      assert source_errors("var b bool\nxic bool ote b\nxic VAR ote b\nmove Dint b") == [
               "line 2: `xic` expects a tag, found the type `bool`",
               "line 3: `xic` expects a tag, found the keyword `VAR`",
               "line 4: `move` expects a tag, found the type `Dint`"
             ]
    end

    test "a tag declared from Elixir is cited without a line" do
      declared = [Logex.Tag.new!("d", :dint), Logex.Tag.new!("i", :bool, :var_input)]

      assert source_errors("xic d ote i", declared) == [
               "line 1: `xic` reads a bool, but `d` is a dint",
               "line 1: `ote` writes `i`, a var_input: logic must not write an input"
             ]
    end
  end

  describe "warnings (M1-5): what compiles but is probably a mistake" do
    test "a tag declared but used by no rung, var_inputs included" do
      assert source_warnings(
               "var_input spare_in bool\nvar spare bool\nvar_output spare_out bool\n" <>
                 "var a bool\nxic a ote a"
             ) ==
               [
                 "line 1: warning: `spare_in` is declared but no rung uses it",
                 "line 2: warning: `spare` is declared but no rung uses it",
                 # Unused says more than unwritten, so a var_output no rung names gets this one.
                 "line 3: warning: `spare_out` is declared but no rung uses it"
               ]
    end

    test "a var_output a rung reads but none writes stays at its initial value" do
      assert source_warnings(
               "var_output lamp bool\nvar_output sp dint 1200\nvar_output m bool\n" <>
                 "var a dint\nxic lamp ote m\nmove sp a"
             ) == [
               "line 1: warning: `lamp` is a var_output, but no rung writes it: it stays at 0",
               "line 2: warning: `sp` is a var_output, but no rung writes it: it stays at 1200"
             ]
    end

    test "a var that is read and never written is not warned about" do
      assert source_warnings("var a bool\nvar b bool\nxic a ote b") == []
    end

    test "a var_output that only move, otl or otu writes is written" do
      assert source_warnings(
               "var a bool\nvar_output sp dint 1200\nvar_output on bool\nvar_output off bool\n" <>
                 "xic a move 5 sp\nxic a otl on\nxio a otu off"
             ) == []
    end

    test "a second ote on one tag cites the first, in its rung or on its line" do
      assert source_warnings(
               "var a bool\nvar m bool\nxic a ote m\n( xic a ote m | xio a )\nxic a ote m ote m"
             ) == [
               "line 4: warning: `m` already has an `ote` on line 3: the last one in the scan decides it",
               "line 5: warning: `m` already has an `ote` on line 3: the last one in the scan decides it",
               "line 5: warning: `m` already has an `ote` on line 3: the last one in the scan decides it"
             ]

      assert source_warnings("var a bool\nvar m bool\nxic a ote m ote m") == [
               "line 3: warning: `m` already has an `ote` in this rung: the last one in the scan decides it"
             ]
    end

    test "a use inside a group nested in another group counts" do
      assert source_warnings("var a bool\nvar b bool\nxic a ( xio a | ( xic b | xio b ) ) ote a") ==
               []

      assert source_warnings(
               "var a bool\nvar m bool\nxic a ote m\nxic a ( xio a | ( xic a ote m | xio a ) )"
             ) == [
               "line 4: warning: `m` already has an `ote` on line 3: the last one in the scan decides it"
             ]
    end

    test "otl and otu may share a tag with an ote, as a latch and its reset do" do
      assert source_warnings("var a bool\nvar m bool\nxic a otl m\nxio a otu m\nxic m ote m") ==
               []
    end

    test "are in line order, stamped :validate, with severity :warning" do
      {:ok, program} =
        source_compile("var a bool\nvar m bool\nvar_output z bool\nxic a ote m\nxic a ote m")

      assert [%Logex.Diagnostic{line: 3}, %Logex.Diagnostic{line: 5}] = program.warnings

      assert Enum.all?(
               program.warnings,
               &match?(%Logex.Diagnostic{stage: :validate, severity: :warning}, &1)
             )
    end

    test "are given only when the program compiles" do
      assert {:error, diagnostics} = source_compile("var spare bool\nzzz")

      assert Enum.map(diagnostics, &Logex.Diagnostic.format/1) == [
               "line 2: unknown instruction `zzz`"
             ]
    end

    test "are never about a tag declared from Elixir" do
      declared = [Logex.Tag.new!("m", :bool), Logex.Tag.new!("unused", :bool, :var_output)]
      assert {:ok, %Logex.Program{warnings: []}} = source_compile("xic m ote m ote m", declared)
    end
  end

  describe "ons (M1-6)" do
    test "its storage bit is a bool tag it writes: M1-3's rules refuse anything else" do
      assert source_errors(
               "var_input i bool\nvar d dint\nvar a bool\nxic a ons i\nxic a ons d\nxic a ons 5\nons"
             ) == [
               "line 4: `ons` writes `i`, a var_input (declared on line 1): " <>
                 "logic must not write an input",
               "line 5: `ons` writes a bool, but `d` is a dint (declared on line 2)",
               "line 6: `ons` expects a tag, found `5`",
               "line 7: `ons` expects 1 operand (a tag), found none"
             ]
    end

    test "its storage bit may be a var or a var_output, and is read freely elsewhere" do
      assert source_warnings(
               "var_input go bool\nvar s1 bool\nvar_output s2 bool\nvar_output p bool\n" <>
                 "xic go ons s1 ote p\nxio go ons s2 ote p\nxic s1 xic s2 ote p"
             ) == [
               "line 6: warning: `p` already has an `ote` on line 5: the last one in the scan decides it",
               "line 7: warning: `p` already has an `ote` on line 5: the last one in the scan decides it"
             ]
    end

    test "is reserved in any case" do
      assert source_errors("var ons bool\nvar Ons bool") == [
               "line 1: `ons` is an instruction and cannot name a tag",
               "line 2: `Ons` is an instruction and cannot name a tag"
             ]
    end

    test "another write to its storage bit, before or after it, is warned about at the write" do
      assert source_warnings(
               "var go bool\nvar s1 bool\nvar d bool\nxio go otu s1\nxic go ons s1 ote d\n" <>
                 "xic d ote s1\nxic d otl s1\nxic d move 1 s1"
             ) == [
               "line 4: warning: `otu` writes `s1`, the storage bit of the `ons` on line 5: " <>
                 "the one-shot then fires on the wrong scans",
               "line 6: warning: `ote` writes `s1`, the storage bit of the `ons` on line 5: " <>
                 "the one-shot then fires on the wrong scans",
               "line 7: warning: `otl` writes `s1`, the storage bit of the `ons` on line 5: " <>
                 "the one-shot then fires on the wrong scans",
               "line 8: warning: `move` writes `s1`, the storage bit of the `ons` on line 5: " <>
                 "the one-shot then fires on the wrong scans"
             ]
    end

    test "a second ons on one storage bit is an error citing the first, in its rung or on its line" do
      # The false one clears the bit every scan, so the true one fires every scan.
      assert source_errors(
               "var go bool\nvar s1 bool\nvar d bool\nxic go ons s1 ons s1 ote d\n" <>
                 "( xio go ons s1 | xic d ) ote d\nxic d ( xic go | ( xio d | ons s1 ) )"
             ) == [
               "line 4: `s1` is already the storage bit of the `ons` in this rung: " <>
                 "each `ons` needs a storage bit of its own",
               "line 5: `s1` is already the storage bit of the `ons` on line 4: " <>
                 "each `ons` needs a storage bit of its own",
               "line 6: `s1` is already the storage bit of the `ons` on line 4: " <>
                 "each `ons` needs a storage bit of its own"
             ]
    end

    test "a second ons is an error however its storage bit was declared" do
      declared = [Logex.Tag.new!("go", :bool), Logex.Tag.new!("s1", :bool)]

      assert source_errors("xic go ons s1\nxio go ons s1", declared) == [
               "line 2: `s1` is already the storage bit of the `ons` on line 1: " <>
                 "each `ons` needs a storage bit of its own"
             ]

      # A var_input bool is still a bool the ons names: two mistakes on line 3.
      assert source_errors("var_input i bool\nxic i ons i\nxio i ons i") == [
               "line 2: `ons` writes `i`, a var_input (declared on line 1): " <>
                 "logic must not write an input",
               "line 3: `ons` writes `i`, a var_input (declared on line 1): " <>
                 "logic must not write an input",
               "line 3: `i` is already the storage bit of the `ons` on line 2: " <>
                 "each `ons` needs a storage bit of its own"
             ]
    end

    test "an ons on a tag that cannot be a storage bit is reported once, not as a second ons" do
      assert source_errors(
               "var d dint\nvar a bool\nxic a ons d\nxic a ons d\nxic a ons zz ons zz"
             ) ==
               [
                 "line 3: `ons` writes a bool, but `d` is a dint (declared on line 1)",
                 "line 4: `ons` writes a bool, but `d` is a dint (declared on line 1)",
                 "line 5: `zz` is not declared"
               ]
    end

    test "two otes on a storage bit get one warning each, never the second ote's" do
      # The ons on line 6 writes s1 last, so the line-5 ote does not decide it.
      assert source_warnings(
               "var go bool\nvar b bool\nvar s1 bool\nxic b ote s1\nxio b ote s1\n" <>
                 "xic go ons s1 ote b\nxic s1 ote b"
             ) == [
               "line 4: warning: `ote` writes `s1`, the storage bit of the `ons` on line 6: " <>
                 "the one-shot then fires on the wrong scans",
               "line 5: warning: `ote` writes `s1`, the storage bit of the `ons` on line 6: " <>
                 "the one-shot then fires on the wrong scans",
               "line 7: warning: `b` already has an `ote` on line 6: the last one in the scan decides it"
             ]
    end

    test "a write to a storage bit in the ons's own rung cites it there" do
      assert source_warnings("var go bool\nvar s1 bool\nxic go ons s1 ( otl s1 | otu s1 )") == [
               "line 3: warning: `otl` writes `s1`, the storage bit of the `ons` in this rung: " <>
                 "the one-shot then fires on the wrong scans",
               "line 3: warning: `otu` writes `s1`, the storage bit of the `ons` in this rung: " <>
                 "the one-shot then fires on the wrong scans"
             ]
    end

    test "storage warnings on one line come in rung order, however many there are" do
      # 40 storage bits, written on one line in the reverse of their names' order: an order
      # taken from a map of more than 32 keys would not be this one.
      names = for i <- 40..1//-1, do: "s" <> String.pad_leading("#{i}", 2, "0")
      declarations = Enum.map_join(names, &"var #{&1} bool\n")
      shots = Enum.map_join(names, "\n", &"xic go ons #{&1}")
      writes = "xic go " <> Enum.map_join(names, " ", &"ote #{&1}")

      assert source_warnings("var go bool\n" <> declarations <> shots <> "\n" <> writes) ==
               Enum.map(names, fn name ->
                 "line 82: warning: `ote` writes `#{name}`, the storage bit of the `ons` " <>
                   "on line #{42 + Enum.find_index(names, &(&1 == name))}: " <>
                   "the one-shot then fires on the wrong scans"
               end)
    end

    test "is never warned about for a storage bit declared from Elixir" do
      declared = [Logex.Tag.new!("go", :bool), Logex.Tag.new!("s1", :bool)]

      assert {:ok, %Logex.Program{warnings: []}} =
               source_compile("xic go ons s1\nxic go ote s1 otl s1", declared)
    end
  end

  describe "comparisons (M1-6)" do
    test "take two dints, each a tag or a literal that fits 32 bits" do
      assert source_errors(
               "var b bool\nvar d dint\nvar_input i dint\nvar_output o dint\n" <>
                 "eq b d ote b\ngt d 2147483648 ote b\nge d ote b\nlt 2147483647 i le o i ote b"
             ) == [
               "line 5: `eq` reads a dint, but `b` is a bool (declared on line 1)",
               "line 6: `gt` reads a dint: `2147483648` does not fit in 32 bits",
               "line 7: `ge` expects 2 operands (a value, then a value), found 1 " <>
                 "before the instruction `ote`"
             ]
    end

    test "a literal may stand on either side, and a var_input or var_output be read" do
      assert source_warnings(
               "var_input i dint\nvar_output o dint\nvar b bool\n" <>
                 "lt 2147483647 i le o i ne i 0 ote b\nmove i o"
             ) == []
    end

    test "are reserved in any case" do
      assert source_errors(
               "var eq bool\nvar NE bool\nvar lt dint\nvar Gt dint\nvar le bool\nvar gE bool"
             ) ==
               for(
                 {word, line} <- Enum.with_index(~w(eq NE lt Gt le gE), 1),
                 do: "line #{line}: `#{word}` is an instruction and cannot name a tag"
               )
    end

    test "two literals compile, with a warning, in a branch leg too" do
      assert source_warnings("var b bool\neq 1 1 ote b\n( ge 0 5 | xic b ) ote b") == [
               "line 2: warning: `eq` compares two literals, `1` and `1`: its result never changes",
               "line 3: warning: `b` already has an `ote` on line 2: the last one in the scan decides it",
               "line 3: warning: `ge` compares two literals, `0` and `5`: its result never changes"
             ]

      assert source_warnings("var b bool\nxic b ( xic b | ( lt 2 3 | xio b ) ) ote b") == [
               "line 2: warning: `lt` compares two literals, `2` and `3`: its result never changes"
             ]
    end
  end

  describe "timers declared (M1-6)" do
    test "`var t1 ton` declares a timer, the type word in any case" do
      assert {:ok, program} =
               source_compile("var t1 ton\nVAR T2 TON\nvar a bool\nxic t1.dn xic T2.dn ote a")

      assert %Logex.Tag{type: %Logex.FbType{name: "ton"}, section: :var} = program.tags["t1"]
      assert %Logex.Tag{type: %Logex.FbType{name: "ton"}, line: 2} = program.tags["T2"]
      assert "ton" in Logex.Declarations.keywords()
    end

    test "only with `var`, and with no initial value, but still declared, so its uses " <>
           "are not each undeclared" do
      assert source_errors(
               "var_input t1 ton\nvar_output t2 ton\nvar t3 ton 5000\nvar a bool\n" <>
                 "xic t1.dn xic t2.dn xic t3.dn ote a"
             ) == [
               "line 1: `t1` is a ton: an instance is the program's own, declared with `var`, " <>
                 "as in `var t1 ton`, not with `var_input`",
               "line 2: `t2` is a ton: an instance is the program's own, declared with `var`, " <>
                 "as in `var t2 ton`, not with `var_output`",
               "line 3: `t3` is a ton: its preset is the number on its `ton` instruction, " <>
                 "as in `ton t3 5000`, not an initial value on its declaration"
             ]
    end

    test "a misdeclared timer enters the table as `var t1 ton` would" do
      rungs = fn source ->
        {:ok, tokens, _} = Compiler.tokenize(source)
        {:ok, {:routine, {:rungs, rungs}}} = Compiler.parse(tokens)
        rungs
      end

      {tags, [], [_, _]} = Logex.Declarations.split(rungs.("var_input t1 ton\nvar t2 ton 5"))
      ton = Logex.FbType.ton()
      assert %Logex.Tag{type: ^ton, section: :var, initial: nil, line: 1} = tags["t1"]
      assert %Logex.Tag{type: ^ton, section: :var, initial: nil, line: 2} = tags["t2"]
    end

    test "so is a timer whose line breaks after its type word" do
      assert source_errors(
               "var t1 ton 5 6\nvar t2 ton x\nvar t3 ton ( xic a )\nvar_input t4 ton 5 6\n" <>
                 "var a bool\nxic a ton t1 5\nxic t1.dn xic t2.dn xic t3.dn xic t4.dn ote a"
             ) == [
               "line 1: unexpected `6` after the declaration of `t1`",
               "line 2: unexpected `x` after the declaration of `t2`",
               "line 3: a declaration cannot hold a branch group",
               "line 4: unexpected `6` after the declaration of `t4`"
             ]

      # Declared on its own line, as any source tag is, which a later message cites.
      assert source_errors("var t1 ton 5 6\nvar t1 bool\nvar a bool\nxic t1 ote a") == [
               "line 1: unexpected `6` after the declaration of `t1`",
               "line 2: `t1` is declared twice: first on line 1",
               "line 4: `xic` reads a bool, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.dn`"
             ]

      # A bad name is not salvaged: not offered to a near miss, and no clash.
      assert source_errors(
               "var tt.x ton 5 6\nvar Var ton 5 6\nvar VAR ton 5 6\nvar a bool\nxic a ton tt 5"
             ) == [
               "line 1: unexpected `6` after the declaration of `tt.x`",
               "line 2: unexpected `6` after the declaration of `Var`",
               "line 3: unexpected `6` after the declaration of `VAR`",
               "line 5: `tt` is not declared"
             ]
    end

    test "a misdeclared timer with a name that cannot be a tag is not declared" do
      assert source_errors("var_input var ton\nvar a bool\nxic a ote a") == [
               "line 1: `var` is a keyword and cannot name a tag",
               "line 1: `var` is a ton: an instance is the program's own, declared with " <>
                 "`var`, as in `var var ton`, not with `var_input`"
             ]

      # Not in the table, so not offered to a near miss either.
      assert source_errors("var_input t1.x ton\nvar a bool\nxic t1 ote a") == [
               "line 1: `t1.x` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`",
               "line 1: `t1.x` is a ton: an instance is the program's own, declared with " <>
                 "`var`, as in `var t1.x ton`, not with `var_input`",
               "line 3: `t1` is not declared"
             ]
    end

    test "the rarer shapes of a timer's declaration line" do
      assert source_errors(
               "var ton\nvar p q ton\nvar t6 timer\nvar t7.x ton\nvar ton bool\nvar a bool\nxic a ote a"
             ) == [
               "line 1: `var` needs a tag name before the type `ton`, as in `var t1 ton`",
               "line 2: `var` declares one tag: found `p` and `q` before the type",
               "line 3: unknown type `timer`: logex has `bool`, `dint` and `ton`",
               "line 4: `t7.x` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`",
               "line 5: `ton` is an instruction and cannot name a tag"
             ]

      # With no name, a timer in another section is shown the declaration that works.
      assert source_errors("var_input ton\nvar_output TON\nVAR Ton\nvar a bool\nxic a ote a") == [
               "line 1: `var_input` needs a tag name before the type `ton`; " <>
                 "a ton is declared with `var`, as in `var t1 ton`",
               "line 2: `var_output` needs a tag name before the type `TON`; " <>
                 "a ton is declared with `var`, as in `var t1 TON`",
               "line 3: `VAR` needs a tag name before the type `Ton`, as in `VAR t1 Ton`"
             ]
    end

    test "from Elixir, a timer is a tag whose type is Logex.FbType.ton(), checked alike" do
      ton = Logex.FbType.ton()
      assert %Logex.Tag{name: "t1", type: ^ton, section: :var} = Logex.Tag.new!("t1", ton)

      for {args, message} <- [
            {["t1", :ton], "unknown type :ton: logex has :bool, :dint and Logex.FbType.ton()"},
            {["t1", ton, :var_input],
             "`t1` is a ton: an instance is the program's own, declared with `var`, " <>
               "as in `var t1 ton`, not with `var_input`"},
            {["t1", ton, :input], "unknown section :input"},
            {["t1", ton, :var, 5000],
             "`t1` is a ton: its preset is the number on its `ton` instruction, " <>
               "as in `ton t1 5000`, not an initial value on its declaration"},
            {["t1", %{ton | name: "tof"}],
             ~s|unknown function block type "tof": logex has Logex.FbType.ton() | <> @given},
            {["t1", %{ton | members: []}],
             ~s|unknown function block type "ton": logex has Logex.FbType.ton() | <> @given},
            # A hand-built schema may hold anything, and is refused, never looked up by it.
            {["t1", %{ton | name: nil}],
             "unknown function block type nil: logex has Logex.FbType.ton() " <> @given},
            {["t1", %{ton | name: 5}, :var_input],
             "unknown function block type 5: logex has Logex.FbType.ton() " <> @given},
            # Nor is it looked into, where a name that cannot be printed would escape.
            {["t1", %{ton | name: %{}}, :var_input],
             "unknown function block type %{}: logex has Logex.FbType.ton() " <> @given},
            {["t1", %{ton | name: {:a}}, :var, 5],
             "unknown function block type {:a}: logex has Logex.FbType.ton() " <> @given},
            # Whatever an unknown schema's members hold, and a struct is never taken for a
            # map of inputs.
            {["t1", %{ton | members: :junk}, :var, %{"acc" => 1}],
             ~s|unknown function block type "ton": logex has Logex.FbType.ton() | <> @given},
            {["t1", %{ton | members: [1]}, :var, %{"acc" => 1}],
             ~s|unknown function block type "ton": logex has Logex.FbType.ton() | <> @given},
            {["t1", ton, :var, %Logex.Scan{now: 0, first: true}],
             "`t1` is a ton: its preset is the number on its `ton` instruction, " <>
               "as in `ton t1 5000`, not an initial value on its declaration"}
          ] do
        assert_raise ArgumentError, message, fn -> apply(Logex.Tag, :new!, args) end
      end

      # A name that is not a string is refused first, and the other messages name it as
      # given, suggesting `t1` in its place.
      assert Logex.Declarations.check(%Logex.Tag{name: :t1, type: ton, section: :var_output}) ==
               [
                 ":t1 is not a tag name",
                 ":t1 is a ton: an instance is the program's own, declared with `var`, " <>
                   "as in `var t1 ton`, not with `var_output`"
               ]
    end

    test "a timer declared and used by no rung is warned about; a member's use is a use" do
      assert source_warnings("var t1 ton\nvar t2 ton\nvar a bool\nxic t2.dn ote a") == [
               "line 1: warning: `t1` is declared but no rung uses it",
               "line 2: warning: `t2` is a ton, but no `ton` runs it: it never times"
             ]
    end
  end

  describe "ton (M1-6)" do
    @timer "var t1 ton\nvar a bool\nvar d dint\n"

    test "runs a declared timer with a literal preset, in any case" do
      assert {:ok, program} = source_compile(@timer <> "xic a ton t1 5000\nxic t1.dn ote a")
      assert {:ok, _} = source_compile(@timer <> "xic a TON t1 0")
      # The preset is the timer's starting .pre, carried by the compiled tag. Only the
      # compiler gives that map (OE-1): as a declaration, the one validator refuses it.
      assert %Logex.Tag{initial: %{"pre" => 5000}} = program.tags["t1"]

      assert Logex.Declarations.check(program.tags["t1"]) == [
               "`t1` is a ton: its preset is the number on its `ton` instruction, " <>
                 "as in `ton t1 5000`, not an initial value on its declaration"
             ]
    end

    test "its first operand is a declared timer, and nothing else" do
      assert source_errors(
               @timer <> "ton a 5\nton t1.acc 5\nton 5 5000\nton t1\nton t9 5\nton d 5"
             ) == [
               "line 4: `ton` runs a ton, but `a` is a bool (declared on line 2)",
               "line 5: `ton` runs a ton, but `t1.acc` is a dint",
               "line 6: `ton` expects a ton, found `5`",
               "line 7: `ton` expects 2 operands (a ton, then a preset), found 1",
               "line 8: `t9` is not declared",
               "line 9: `ton` runs a ton, but `d` is a dint (declared on line 3)"
             ]
    end

    test "its preset is a number of 0 to 2147483647 ms, and one from a tag is moved " <>
           "into .pre instead" do
      assert source_errors(@timer <> "ton t1 d\nton t1 zz\nton t1 2147483648\nton 5 d") == [
               "line 4: `ton` takes its preset as a number of milliseconds, found `d`: " <>
                 "to preset `t1` from a tag, `move d t1.pre` on a rung above",
               "line 5: `ton` takes its preset as a number of milliseconds, found `zz`: " <>
                 "to preset `t1` from a tag, `move zz t1.pre` on a rung above",
               "line 5: `t1` is already run by the `ton` on line 4: one `ton` runs a timer",
               "line 6: `ton` takes a preset of 0 to 2147483647 ms, found `2147483648`",
               "line 6: `t1` is already run by the `ton` on line 4: one `ton` runs a timer",
               "line 7: `ton` expects a ton, found `5`",
               "line 7: `ton` takes its preset as a number of milliseconds, found `d`"
             ]

      # The range ends exactly at 2147483647, the one place a preset is given (OE-1).
      assert {:ok, program} = source_compile(@timer <> "xic a ton t1 2147483647")
      assert %{"pre" => 2_147_483_647} = Logex.Program.initial_env(program)["t1"]
    end

    test "the move for a tag preset is named only where that move would compile" do
      # Into a timer, from a dint: a tag, a member, or a name not declared yet.
      assert source_errors(@timer <> "var t2 ton\nton t1 t2.acc\nton t9 d") == [
               "line 5: `ton` takes its preset as a number of milliseconds, found `t2.acc`: " <>
                 "to preset `t1` from a tag, `move t2.acc t1.pre` on a rung above",
               "line 6: `t9` is not declared",
               "line 6: `ton` takes its preset as a number of milliseconds, found `d`: " <>
                 "to preset `t9` from a tag, `move d t9.pre` on a rung above"
             ]

      # From a bool, a timer named whole, a bool member or a type word, or into what is
      # not a timer, the move would be refused in its turn.
      for {rung, found, also} <- [
            {"ton t1 a", "a", []},
            {"ton t1 t2", "t2", []},
            {"ton t1 t2.dn", "t2.dn", []},
            {"ton t1 bool", "bool", []},
            {"ton d t2.acc", "t2.acc",
             ["`ton` runs a ton, but `d` is a dint (declared on line 3)"]},
            {"ton t1.dn d", "d", ["`ton` runs a ton, but `t1.dn` is a bool"]},
            {"ton dint d", "d", ["`ton` expects a tag, found the type `dint`"]},
            # One name cannot be both the timer and the dint moved into it.
            {"ton b b", "b", ["`b` is not declared"]},
            # Nor two that differ only in case, which cannot both be declared.
            {"ton b B", "B", ["`b` is not declared"]},
            {"ton T9 t9", "t9", ["`T9` is not declared"]},
            # A case-only twin of a declared tag can never be declared.
            {"ton t1 D", "D", []},
            {"ton T1 d", "d",
             ["`T1` is not declared — did you mean `t1`? (tags are case-sensitive)"]}
          ] do
        assert source_errors(@timer <> "var t2 ton\n" <> rung) ==
                 Enum.map(also, &"line 5: #{&1}") ++
                   [
                     "line 5: `ton` takes its preset as a number of milliseconds, found `#{found}`"
                   ],
               rung
      end

      # A twin is a twin whichever of the two is in capitals, the declared or the used.
      assert source_errors("var T1 ton\nvar D dint\nton T1 d\nton t1 D") == [
               "line 3: `ton` takes its preset as a number of milliseconds, found `d`",
               "line 4: `t1` is not declared — did you mean `T1`? (tags are case-sensitive)",
               "line 4: `ton` takes its preset as a number of milliseconds, found `D`"
             ]

      assert source_errors("ton b b") == [
               "line 1: `b` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var b ton`)",
               "line 1: `ton` takes its preset as a number of milliseconds, found `b`"
             ]
    end

    test "a negative preset never reaches the compiler: the tree is refused on entry" do
      # `-1` does not lex yet (PLAN.md §5), so only a tree built as data holds it, and
      # instructionize/2 refuses that as a host mistake (OE-1, decision 28). Until a
      # negative literal lexes, the preset's range is reached only at its upper end, above.
      {:ok, tokens, _} = Compiler.tokenize("var t1 ton")
      {:ok, {:routine, {:rungs, declarations}}} = Compiler.parse(tokens)
      rung = {:rung, [{:name, 2, "ton"}, {:name, 2, "t1"}, {:int_lit, 2, -1}]}

      assert_raise ArgumentError,
                   "not a tree Logex.Parser.parse/1 can produce: a literal is an integer, " <>
                     "0 or more: a negative one does not lex yet (PLAN.md §5), " <>
                     "got: {:int_lit, 2, -1}",
                   fn -> Compiler.instructionize({:routine, {:rungs, declarations ++ [rung]}}) end
    end

    test "one ton runs a timer: a second is an error, citing the first" do
      assert source_errors(
               @timer <>
                 "xic a ton t1 5\n( xic a ton t1 6 | xio a )\nxic a ( ton t1 7 | ton t1 8 )"
             ) == [
               "line 5: `t1` is already run by the `ton` on line 4: one `ton` runs a timer",
               "line 6: `t1` is already run by the `ton` on line 4: one `ton` runs a timer",
               "line 6: `t1` is already run by the `ton` on line 4: one `ton` runs a timer"
             ]

      assert source_errors(@timer <> "xic a ( ton t1 5 | ton t1 5 )") == [
               "line 4: `t1` is already run by the `ton` in this rung: one `ton` runs a timer"
             ]
    end

    test "a ton with a wrong preset still runs its timer, so a second ton is reported too" do
      # A tag, a number out of range, and no preset at all.
      for preset <- ["d", "3000000000", ""] do
        assert [_, "line 5: `t1` is already run by the `ton` on line 4: one `ton` runs a timer"] =
                 source_errors(@timer <> "xic a ton t1 #{preset}\nxic a ton t1 5000")
      end
    end

    test "a ton on a declared tag that is not a timer runs nothing, so a second is not counted" do
      assert source_errors(@timer <> "xic a ton a 5\nxic a ton d 6\nxic a ton a 7") == [
               "line 4: `ton` runs a ton, but `a` is a bool (declared on line 2)",
               "line 5: `ton` runs a ton, but `d` is a dint (declared on line 3)",
               "line 6: `ton` runs a ton, but `a` is a bool (declared on line 2)"
             ]
    end

    test "a ton in a group nested in another group carries its preset, and is counted" do
      assert {:ok, program} =
               source_compile(@timer <> "xic a ( xic a | ( xio a | ton t1 5000 ) )")

      assert %Logex.Tag{initial: %{"pre" => 5000}} = program.tags["t1"]

      assert source_errors(@timer <> "( xic a | ( ton t1 5 | xio a ) )\n( ( ton t1 6 ) )") == [
               "line 5: `t1` is already run by the `ton` on line 4: one `ton` runs a timer"
             ]
    end

    test "is reserved in any case, as an instruction as well as a type" do
      assert source_errors("var ton bool\nvar TON dint\nvar tOn ton") == [
               "line 1: `ton` is an instruction and cannot name a tag",
               "line 2: `TON` is an instruction and cannot name a tag",
               "line 3: `tOn` is an instruction and cannot name a tag"
             ]
    end

    test "a timer read but run by no ton is warned about; one run is not" do
      assert source_warnings(
               "var t1 ton\nvar t2 ton\nvar a bool\nxic a ton t1 5\nxic t1.dn xic t2.dn ote a"
             ) == ["line 2: warning: `t2` is a ton, but no `ton` runs it: it never times"]

      declared = [Logex.Tag.new!("t3", Logex.FbType.ton()), Logex.Tag.new!("a", :bool)]
      assert {:ok, %Logex.Program{warnings: []}} = source_compile("xic t3.dn ote a", declared)
    end

    test "from Elixir, a timer takes no preset: that is the number on the ton that runs it" do
      # OE-1 (decision 24) withdrew M1-6's `%{"pre" => ms}`: a ton on the rung silently
      # replaced it, and with none no text could give that .pre. Any initial value on an
      # instance gets the message its declaration line would, whatever the value.
      ton = Logex.FbType.ton()

      assert source_errors("var t1 ton 50
var a bool
xic a ton t1 7") == [
               "line 1: `t1` is a ton: its preset is the number on its `ton` instruction, " <>
                 "as in `ton t1 5000`, not an initial value on its declaration"
             ]

      for initial <- [
            %{"pre" => 50},
            %{"pre" => 2_147_483_647},
            %{"pre" => 0},
            %{"acc" => 5},
            %{"pre" => -5},
            %{},
            0
          ] do
        assert_raise ArgumentError,
                     "`t1` is a ton: its preset is the number on its `ton` instruction, " <>
                       "as in `ton t1 5000`, not an initial value on its declaration",
                     fn -> Logex.Tag.new!("t1", ton, :var, initial) end
      end

      # So a timer from Elixir starts where a declaration line's does: at the preset of the
      # ton that runs it, or at 0 with none.
      declared = [Logex.Tag.new!("t1", ton), Logex.Tag.new!("a", :bool)]
      {:ok, unrun} = source_compile("xic t1.dn ote a", declared)
      assert %{"pre" => 0} = Logex.Program.initial_env(unrun)["t1"]
      {:ok, run} = source_compile("xic a ton t1 7", declared)
      assert %{"pre" => 7} = Logex.Program.initial_env(run)["t1"]
    end
  end

  describe "nothing may follow a ton on its path (M1-6)" do
    @paths "var_input go bool\nvar_input b bool\nvar_output lamp bool\nvar t1 ton\nvar t2 ton\n"

    # Whether the power after a ton is the rung's or the timer's .dn is not settled, so a
    # ton ends its path, and the message says what to write instead.
    defp after_ton(line, element, timer \\ "t1"),
      do:
        "line #{line}: #{element} follows `ton #{timer}` on its path: what passes on after a " <>
          "`ton` is not settled, so a `ton` ends its path; read the timer with " <>
          "`xic #{timer}.dn` on a rung below"

    test "an element in series after a ton is an error at its line, each one, citing the ton" do
      assert source_errors(@paths <> "xic go ton t1 5000 ote lamp") == [
               after_ton(6, "`ote lamp`")
             ]

      assert source_errors(@paths <> "xic go ton t1 5000 xic b ote lamp\nTON t2 5 XIC t1.dn") == [
               after_ton(6, "`xic b`"),
               after_ton(6, "`ote lamp`"),
               after_ton(7, "`xic t1.dn`", "t2")
             ]
    end

    test "so is one after a group one of whose legs ends in a ton, or holds one" do
      assert source_errors(
               @paths <>
                 "xic go ( ton t1 5000 | xic b ) ote lamp\n( xic b | xio go ton t2 5 ) move 1 lamp"
             ) == [
               after_ton(6, "`ote lamp`"),
               after_ton(7, "`move 1 lamp`", "t2")
             ]
    end

    test "and one after a group nested in another, however deep the ton, once, in its own " <>
           "series" do
      assert source_errors(
               @paths <>
                 "xic go ( xic b | ( xio b | ton t1 5000 ) ) ote lamp\n" <>
                 "xic go ( ( ton t2 5 ) xic b | xio b )"
             ) == [
               after_ton(6, "`ote lamp`"),
               after_ton(7, "`xic b`", "t2")
             ]
    end

    test "a group, or a second ton, after a ton is one element, and cites the first ton" do
      assert source_errors(@paths <> "xic go ton t1 5 ( ote lamp | xic b ) ton t2 5 ote lamp") ==
               [
                 after_ton(6, "a branch group"),
                 after_ton(6, "`ton t2 5`"),
                 after_ton(6, "`ote lamp`")
               ]
    end

    test "a group with a ton in more than one leg cites the first of them" do
      assert source_errors(@paths <> "xic go ( ton t1 5000 | ton t2 3000 ) ote lamp") == [
               after_ton(6, "`ote lamp`")
             ]
    end

    test "the timer to read is named only when the ton runs one" do
      unnamed =
        "on its path: what passes on after a `ton` is not settled, so a `ton` ends its " <>
          "path; read the timer's `.dn` on a rung below"

      assert source_errors(
               @paths <>
                 "xic go ton b 5 ote lamp\nxic go ton t1.dn 5 ote lamp\nxic go ton bool 5 ote lamp"
             ) == [
               "line 6: `ton` runs a ton, but `b` is a bool (declared on line 2)",
               "line 6: `ote lamp` follows `ton b` " <> unnamed,
               "line 7: `ton` runs a ton, but `t1.dn` is a bool",
               "line 7: `ote lamp` follows `ton t1.dn` " <> unnamed,
               "line 8: `ton` expects a tag, found the type `bool`",
               "line 8: `ote lamp` follows `ton bool` " <> unnamed
             ]

      # A case-only twin of a declared timer can never be declared, whichever of the two
      # is in capitals.
      assert source_errors(@paths <> "xic go ton T1 5000 ote lamp") == [
               "line 6: `T1` is not declared — did you mean `t1`? (tags are case-sensitive)",
               "line 6: `ote lamp` follows `ton T1` " <> unnamed
             ]

      assert source_errors(@paths <> "var T3 ton\nxic go ton t3 5000 ote lamp") == [
               "line 7: `t3` is not declared — did you mean `T3`? (tags are case-sensitive)",
               "line 7: `ote lamp` follows `ton t3` " <> unnamed
             ]
    end

    test "in rung order: a group's own error, then each leg's, then what follows the group" do
      assert source_errors(
               @paths <>
                 "var t3 ton\n" <>
                 "xic go ton t1 5 ( xic b ton t2 5 ote lamp | ton t3 5 xic b ) ote lamp"
             ) == [
               after_ton(7, "a branch group"),
               after_ton(7, "`ote lamp`", "t2"),
               after_ton(7, "`xic b`", "t3"),
               after_ton(7, "`ote lamp`")
             ]
    end

    test "a leg beside a ton is not on its path" do
      assert {:ok, _} =
               source_compile(
                 @paths <>
                   "xic go ( ton t1 5000 | ote lamp )\n( xic b | ( ton t2 5 | xio b ) )\n" <>
                   "xic t1.dn xic t2.dn ote lamp"
               )
    end

    test "a rung over two lines never reaches the path check: it is refused on entry" do
      # A rung is one line, so every element after a ton shares the ton's line. A rung over
      # two lines, which once showed an element cited at its own, is built only as data,
      # and instructionize/2 refuses it (OE-1, decision 28) until PLAN.md §5's line
      # continuations land; the citing of an element's own line is kept for them.
      {:ok, tokens, _} = Compiler.tokenize("var t1 ton\nvar a bool")
      {:ok, {:routine, {:rungs, declarations}}} = Compiler.parse(tokens)

      rung =
        {:rung,
         [
           {:name, 3, "ton"},
           {:name, 3, "t1"},
           {:int_lit, 3, 5},
           {:name, 4, "ote"},
           {:name, 4, "a"}
         ]}

      assert_raise ArgumentError,
                   "not a tree Logex.Parser.parse/1 can produce: a rung is one line, and this " <>
                     ~s|one began on line 3, got: {:name, 4, "ote"}|,
                   fn -> Compiler.instructionize({:routine, {:rungs, declarations ++ [rung]}}) end
    end

    test "a ton with a mistake of its own is still the end of its path" do
      assert source_errors(@paths <> "xic go ton t9 5 ote lamp\nxic go ton ote lamp") == [
               "line 6: `t9` is not declared",
               after_ton(6, "`ote lamp`", "t9"),
               "line 7: `ton` expects 2 operands (a ton, then a preset), found none " <>
                 "before the instruction `ote`",
               "line 7: `ote lamp` follows `ton` on its path: what passes on after a `ton` is " <>
                 "not settled, so a `ton` ends its path; read the timer's `.dn` on a rung below"
             ]
    end
  end

  describe "members (M1-6)" do
    @timer "var t1 ton\nvar a bool\nvar d dint\n"

    test "are typed, read anywhere, and written only where logic may: .pre and .acc" do
      assert {:ok, _} =
               source_compile(
                 @timer <>
                   "xic t1.dn xio t1.tt xic t1.en ote a\nmove t1.acc d\nmove t1.pre d\n" <>
                   "move 3000 t1.pre\nmove d t1.acc\neq t1.acc 5 ote a\nmove t1.acc t1.pre"
               )
    end

    test "take their type from the schema, as a tag takes its declaration's" do
      assert source_errors(
               @timer <>
                 "xic t1.acc ote a\nmove t1.dn d\nmove 2147483648 t1.pre\nlt t1.tt 5 ote a"
             ) == [
               "line 4: `xic` reads a bool, but `t1.acc` is a dint",
               "line 5: `move` takes operands of one type: `t1.dn` is a bool, `d` is a dint",
               "line 6: `move` writes `2147483648` into `t1.pre`, a dint: it does not fit in 32 bits",
               "line 7: `lt` reads a dint, but `t1.tt` is a bool"
             ]
    end

    test "a write to .dn, .tt or .en is one diagnostic, by every instruction that writes" do
      assert source_errors(
               @timer <>
                 "xic a ote t1.dn\nxic a otl t1.tt\nxic a otu t1.en\nmove 5 t1.dn\nxic a ons t1.en"
             ) ==
               for(
                 {word, member, line} <- [
                   {"ote", "dn", 4},
                   {"otl", "tt", 5},
                   {"otu", "en", 6},
                   {"move", "dn", 7},
                   {"ons", "en", 8}
                 ],
                 do:
                   "line #{line}: `#{word}` writes `t1.#{member}`, but logic may write only " <>
                     "`.pre` and `.acc` of a ton"
               )
    end

    test "an unknown member gets the member it is near, matched on its own name, or the list" do
      assert source_errors(
               @timer <>
                 "xic t1.dne ote a\nxic t1.DN ote a\nxic t1.et ote a\nxic t1.pt ote a\n" <>
                 "xic t1.in ote a\nxic t1.last ote a\nxic t1.q ote a"
             ) ==
               [
                 "line 4: `t1.dne` is not a member of `t1`, a ton — did you mean `t1.dn`?",
                 "line 5: `t1.DN` is not a member of `t1`, a ton — did you mean `t1.dn`? " <>
                   "(members are case-sensitive)"
               ] ++
                 for(
                   {member, line} <- [{"et", 6}, {"pt", 7}, {"in", 8}, {"last", 9}, {"q", 10}],
                   do:
                     "line #{line}: `t1.#{member}` is not a member of `t1`, a ton: " <>
                       "its members are `pre`, `acc`, `dn`, `tt` and `en`"
                 )
    end

    test "a dotted name on a tag that is not an instance, or past a member, is named" do
      assert source_errors(
               @timer <>
                 "xic a.b ote a\nxic d.3 ote a\nmove t1.acc.x d\nxic a.dn.x ote a\nxic t1.dn.x ote a"
             ) == [
               "line 4: `a.b` names a member of `a`, but `a` is a bool (declared on line 2): " <>
                 "only an instance of a function block has members",
               "line 5: `d.3` names a bit of `d`, a dint: bit access is not supported yet",
               "line 6: `t1.acc.x` goes too deep: `t1.acc` is a dint, which has no members",
               "line 7: `a.dn.x` names a member of `a`, but `a` is a bool (declared on line 2): " <>
                 "only an instance of a function block has members",
               "line 8: `t1.dn.x` goes too deep: `t1.dn` is a bool, which has no members"
             ]
    end

    test "a bit of a member is bit access, as a bit of a tag is, and a bool has none" do
      assert source_errors(
               @timer <>
                 "move t1.acc.3 d\nxic t1.dn.0 ote a\nxic a.0 ote a\nmove t1.acc.3.x d\nmove t1.acc.3.4 d"
             ) == [
               "line 4: `t1.acc.3` names a bit of `t1.acc`, a dint: bit access is not supported yet",
               "line 5: `t1.dn.0` names a bit of `t1.dn`, a bool, which has no bits",
               "line 6: `a.0` names a bit of `a`, a bool, which has no bits",
               # Past a bit, as past a member, a path goes too deep, bit access or none.
               "line 7: `t1.acc.3.x` goes too deep: `t1.acc` is a dint, which has no members",
               "line 8: `t1.acc.3.4` goes too deep: `t1.acc` is a dint, which has no members"
             ]

      assert source_errors(
               @timer <> "move d.3.x d\nmove d.3.4 d\nxic a.0.1 ote a\nxic a.b.1 ote a"
             ) ==
               [
                 "line 4: `d.3.x` goes too deep: `d` is a dint, which has no members",
                 "line 5: `d.3.4` goes too deep: `d` is a dint, which has no members",
                 "line 6: `a.0.1` goes too deep: `a` is a bool, which has no members",
                 "line 7: `a.b.1` names a member of `a`, but `a` is a bool (declared on " <>
                   "line 2): only an instance of a function block has members"
               ]
    end

    test "a dotted name on a reserved word is named as such, never as undeclared" do
      assert source_errors(
               @timer <>
                 "xic ton.dn ote a\nxic VAR.dn xic bool.x ote a\nxic bool.3 xic ton.3.x ote a"
             ) == [
               "line 4: `ton.dn` begins with `ton`, an instruction, which cannot name a tag",
               "line 5: `VAR.dn` begins with `VAR`, a keyword, which cannot name a tag",
               "line 5: `bool.x` begins with `bool`, a type, which cannot name a tag",
               "line 6: `bool.3` begins with `bool`, a type, which cannot name a tag",
               "line 6: `ton.3.x` begins with `ton`, an instruction, which cannot name a tag"
             ]
    end

    test "an undeclared instance is named once, whichever members are used, and never " <>
           "reached into from another" do
      assert source_errors(
               "var timer1 ton\nvar a bool\nxic t9.dn ote a\nxic t9.tt ote a\nxic t9 ote a\n" <>
                 "xic timr1.dn ote a\nxic m1.t1.acc ote a\nxic timer1.dn ote a"
             ) == [
               "line 3: `t9` is not declared",
               "line 6: `timr1` is not declared — did you mean `timer1`?",
               "line 7: `m1` is not declared"
             ]
    end

    test "an instance named whole is refused, with a member suggested where one fits" do
      assert source_errors(
               @timer <>
                 "xic t1 ote a\nmove t1 d\nmove d t1\nxic a ote t1\neq t1 5 ote a\nmove t1 a"
             ) == [
               "line 4: `xic` reads a bool, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.dn`",
               "line 5: `move` reads a value, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.acc`",
               "line 6: `move` writes a value, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.pre`",
               "line 7: `ote` writes a bool, but `t1` is a ton (declared on line 1)",
               "line 8: `eq` reads a dint, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.acc`",
               # One diagnostic: an instance named whole is not also unified with `a`.
               "line 9: `move` reads a value, but `t1` is a ton (declared on line 1): " <>
                 "name one of its members, as in `t1.acc`"
             ]
    end

    test "of a timer declared from Elixir, cited without a line" do
      declared = [Logex.Tag.new!("t1", Logex.FbType.ton()), Logex.Tag.new!("a", :bool)]

      assert source_errors("xic t1 ote a\nxic a.dn ote a", declared) == [
               "line 1: `xic` reads a bool, but `t1` is a ton: name one of its members, " <>
                 "as in `t1.dn`",
               "line 2: `a.dn` names a member of `a`, but `a` is a bool: only an instance of a function block has members"
             ]

      assert {:ok, _} = source_compile("xic t1.dn ote a", declared)
    end
  end

  describe "tags declared from Elixir (M1-3)" do
    test "are checked by the same rules as a declaration line" do
      assert source_errors("var ote bool") == [
               "line 1: `ote` is an instruction and cannot name a tag"
             ]

      assert_raise ArgumentError, "`ote` is an instruction and cannot name a tag", fn ->
        Logex.Tag.new!("ote", :bool)
      end

      assert_raise ArgumentError, ~s("t1 x" is not a tag name), fn ->
        Logex.Tag.new!("t1 x", :bool)
      end

      assert_raise ArgumentError,
                   "`i` is a var_input: its value comes from outside, " <>
                     "so it takes no initial value",
                   fn ->
                     Logex.Tag.new!("i", :bool, :var_input, 1)
                   end
    end

    test "are returned as declared, and start at their initial value" do
      assert Logex.Tag.new!("x", :bool) ==
               %Logex.Tag{name: "x", type: :bool, section: :var, initial: nil, line: nil}

      assert Logex.Tag.new!("x", :dint, :var, 2_147_483_647).initial == 2_147_483_647
      assert Logex.Tag.new!("x", :dint, :var, 0).initial == 0

      {:ok, program} =
        source_compile("var Lamp bool 1\nxic Lamp ote Lamp ote x\nmove 5 sp", [
          Logex.Tag.new!("x", :bool),
          Logex.Tag.new!("sp", :dint, :var_output, 5)
        ])

      assert Logex.Program.initial_env(program) == %{"Lamp" => 1, "x" => 0, "sp" => 5}
    end

    test "raise ArgumentError for every rule they break, whatever the argument" do
      for {args, message} <- [
            {["x", :bool, :input], "unknown section :input"},
            {["x", :int], "unknown type :int: logex has :bool, :dint and Logex.FbType.ton()"},
            {["ote", :int], "`ote` is an instruction and cannot name a tag"},
            {[{:a}, :bool, :var_input, 1], "{:a} is not a tag name"},
            # 0 is the default, and still not the program's to give.
            {["i", :bool, :var_input, 0],
             "`i` is a var_input: its value comes from outside, so it takes no initial value"},
            {["a", :dint, :var, {1}], "the initial value of `a` must be an integer, found {1}"},
            {["a", :bool, :var, "1"], ~s(the initial value of `a` must be an integer, found "1")},
            {["x", :dint, :var, -2_147_483_649],
             "`x` is a dint: `-2147483649` does not fit in 32 bits"},
            # What no declaration line can say, until a negative literal lexes (OE-1).
            {["x", :dint, :var, -1],
             "`x` is a dint: its initial value `-1` is negative, which no declaration line " <>
               "can say until a negative literal lexes"},
            {["x", :dint, :var_output, -2_147_483_648],
             "`x` is a dint: its initial value `-2147483648` is negative, which no declaration " <>
               "line can say until a negative literal lexes"},
            {["x", :bool, :var, -1],
             "`x` is a bool: its initial value must be 0 or 1, found `-1`"},
            {["x", :int, :var, 5],
             "unknown type :int: logex has :bool, :dint and Logex.FbType.ton()"},
            {[" a", :bool], ~s(" a" is not a tag name)},
            {["t1.dn", :bool],
             "`t1.dn` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`"},
            {["m1.t1.acc", :bool],
             "`m1.t1.acc` cannot name a tag: `.` is kept for a member, as in a timer's `t1.dn`"},
            {["a b", :bool], ~s("a b" is not a tag name)}
          ] do
        assert_raise ArgumentError, message, fn -> apply(Logex.Tag, :new!, args) end
      end
    end

    test "are checked again as they enter the table, however they were built" do
      for {declared, message} <- [
            {[%Logex.Tag{name: "a", type: :real, section: :var}],
             "unknown type :real: logex has :bool, :dint and Logex.FbType.ton()"},
            {[%Logex.Tag{name: "a", type: :bool, section: :var, initial: 7}],
             "`a` is a bool: its initial value must be 0 or 1, found `7`"},
            {[%Logex.Tag{name: "a", type: :dint, section: :var, initial: -7}],
             "`a` is a dint: its initial value `-7` is negative, which no declaration line " <>
               "can say until a negative literal lexes"},
            {[
               %Logex.Tag{
                 name: "a",
                 type: Logex.FbType.ton(),
                 section: :var,
                 initial: %{"pre" => 5000}
               }
             ],
             "`a` is a ton: its preset is the number on its `ton` instruction, " <>
               "as in `ton a 5000`, not an initial value on its declaration"},
            {[%Logex.Tag{name: "a", type: %Logex.FbType{name: nil, members: nil}, section: :var}],
             "unknown function block type nil: logex has Logex.FbType.ton() " <> @given},
            {[
               %Logex.Tag{
                 name: "a",
                 type: %Logex.FbType{name: "ton", members: :junk},
                 section: :var,
                 initial: %{"acc" => 1}
               }
             ], ~s|unknown function block type "ton": logex has Logex.FbType.ton() | <> @given},
            # A line marks a tag declared in source, which the warnings would then cite.
            {[%Logex.Tag{name: "a", type: :bool, section: :var, line: 2}],
             "a tag declared from Elixir has no line, got: 2"},
            {["a"], ~s(expected a %Logex.Tag{}, got: "a")},
            {%Logex.Tag{name: "a", type: :bool, section: :var},
             "declared must be a list of %Logex.Tag{}, got: " <>
               inspect(%Logex.Tag{name: "a", type: :bool, section: :var})}
          ] do
        assert_raise ArgumentError, message, fn -> source_compile("xic a ote a", declared) end
      end
    end

    test "enter the table before the source's own, which may not clash with them" do
      declared = [Logex.Tag.new!("a", :bool), Logex.Tag.new!("Start", :bool)]

      assert source_errors("var a bool\nvar start bool", declared) == [
               "line 1: `a` is declared twice: the caller's table already has it",
               "line 2: `start` and `Start` (the caller's table) differ only in case: " <>
                 "tags are case-sensitive, so these would be two tags"
             ]
    end

    test "that clash among themselves raise" do
      assert_raise ArgumentError,
                   "`a` is declared twice: the caller's table already has it",
                   fn ->
                     source_compile("ote a", [
                       Logex.Tag.new!("a", :bool),
                       Logex.Tag.new!("a", :dint)
                     ])
                   end
    end
  end

  defp compile(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    {:ok, ast} = Compiler.parse(tokens)
    Compiler.instructionize(ast, @declared)
  end

  # From source alone, or with a table declared from Elixir: the M1-3 cases.
  defp source_compile(source, declared \\ []) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    {:ok, ast} = Compiler.parse(tokens)
    Compiler.instructionize(ast, declared)
  end

  defp source_warnings(source) do
    {:ok, program} = source_compile(source)
    Enum.map(program.warnings, &Logex.Diagnostic.format/1)
  end

  defp source_errors(source, declared \\ []) do
    {:error, diagnostics} = source_compile(source, declared)
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp errors(source) do
    {:error, diagnostics} = compile(source)
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp run(source, env) do
    {:ok, program} = compile(source)
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: true}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 0, first: true})
    state.env
  end
end
