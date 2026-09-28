defmodule Logex.ValidationTest do
  @moduledoc """
  M1-2: `instructionize/1` checks every instruction against its operand signature and
  returns located diagnostics instead of raising. Each case in PLAN.md's M1-2 table is
  here, driven from source text, and each asserts the whole diagnostic list, so a
  missing, extra or cascading diagnostic fails as surely as a wrong one.
  """
  use ExUnit.Case, async: true

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
               "line 2: unknown type `int`: logex has `bool` and `dint`",
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
               "line 14: `retain` is not supported yet: nothing restarts a logex program, " <>
                 "so there is nothing for a tag to survive (PLAN.md M1-5)",
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

    test "a program that declares nothing is told how, once" do
      assert source_errors("xic a ote b") == [
               "line 1: `a` is not declared (this program declares no tags: each is now " <>
                 "declared before the first rung, as `var a bool`)",
               "line 1: `b` is not declared"
             ]
    end

    test "a program whose declarations were all wrong is not told it declares nothing" do
      assert source_errors("var a int\nxic a ote a") == [
               "line 1: unknown type `int`: logex has `bool` and `dint`",
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

  defp source_errors(source, declared \\ []) do
    {:error, diagnostics} = source_compile(source, declared)
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp errors(source) do
    {:error, diagnostics} = compile(source)
    Enum.map(diagnostics, &Logex.Diagnostic.format/1)
  end

  defp run(source, env) do
    {:ok, ir} = compile(source)
    {_, env} = Compiler.evaluate(ir, {true, env})
    env
  end
end
