defmodule Logex.FrontendTest do
  @moduledoc """
  What `frontend_golden_test.exs` cannot check. That record reduces every location to its
  line and keeps the AST rather than the tokens, so it cannot see columns, messages, or
  the token stream itself. The deliberate departures from the leex/yecc front end are
  pinned here too: columns, invalid UTF-8, B2 and B8. So are `//` comments, names with
  `.` parts, negative literals and, since M5-7, based literals and `_` separators
  (decision 149), which leex's lexer never had. All but one of these tests fail against
  that front end; "the AST keeps only the line" is a parity pin and passes on both. The
  last test checks that a checkout upgraded from it has been cleaned.
  """
  use ExUnit.Case, async: true

  alias Logex.Compiler

  describe "every token and every error has a column" do
    test "tokens carry {line, column}, counted from 1" do
      assert {:ok, tokens, 2} = Compiler.tokenize("xic aa\n  ( ote bb | )")

      assert tokens == [
               {:name, {1, 1}, "xic"},
               {:name, {1, 5}, "aa"},
               {:rnd, {1, 7}},
               {:bst, {2, 3}},
               {:name, {2, 5}, "ote"},
               {:name, {2, 9}, "bb"},
               {:nxb, {2, 12}},
               {:bnd, {2, 14}}
             ]
    end

    test "a lex error is located to the character, on whichever line it is" do
      assert {:error, {{1, 5}, Logex.Lexer, {:illegal, "@"}}, 1} = Compiler.tokenize("xic @")
      assert {:error, {{3, 3}, Logex.Lexer, {:illegal, "@"}}, 3} = Compiler.tokenize("a\n\n  @")
    end

    test "a parse error is located to the token" do
      assert {:error, {{1, 8}, Logex.Parser, _}} = parse("xic aa )")
      assert {:error, {{2, 1}, Logex.Parser, _}} = parse("xic aa\n| ote bb")
    end

    test "the AST keeps only the line, as before" do
      assert {:ok, {:routine, {:rungs, [{:rung, [{:name, 1, "xic"}, {:name, 1, "aa"}]}]}}} =
               parse("xic aa")
    end
  end

  describe "a run of newlines is one rung delimiter" do
    # The golden record cannot see the first: it keeps the AST, and the parser drops empty
    # rungs, so one `rnd` or three parse alike. It could see the second, since it keeps
    # error lines, but none of its sources puts an error at a run of newlines.
    test "blank and whitespace-only lines between rungs are one rnd, at the first newline" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 2}}, {:name, {4, 1}, "b"}], 4} =
               Compiler.tokenize("a\n \n\t\nb")
    end

    test "an error at a run of newlines is reported where the run starts" do
      assert {:error, {{1, 9}, Logex.Parser, _}} = parse("( xic aa\n\n)")
      assert {:error, {{1, 10}, Logex.Parser, _}} = parse("( xic aa\r\n\r\n)")
    end
  end

  describe "B8: a lone CR is a newline" do
    test "it ends the line and the rung, with real line numbers after it" do
      assert {:ok, tokens, 2} = Compiler.tokenize("ote aa\rote bb")

      assert tokens == [
               {:name, {1, 1}, "ote"},
               {:name, {1, 5}, "aa"},
               {:rnd, {1, 7}},
               {:name, {2, 1}, "ote"},
               {:name, {2, 5}, "bb"}
             ]

      assert {:error, {{3, 3}, Logex.Lexer, {:illegal, "@"}}, 3} = Compiler.tokenize("a\r\r  @")
    end

    test "a CRLF is still one newline, located at its LF" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 3}}, {:name, {2, 1}, "b"}], 2} =
               Compiler.tokenize("a\r\nb")
    end

    test "a run of lone CRs is one rnd, at the first" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 2}}, {:name, {3, 1}, "b"}], 3} =
               Compiler.tokenize("a\r\rb")
    end

    test "a CR before a CRLF is a newline of its own, in the same run" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 2}}, {:name, {3, 1}, "b"}], 3} =
               Compiler.tokenize("a\r\r\nb")
    end
  end

  describe "names with `.` parts" do
    test "are one name token, whatever their parts" do
      assert {:ok, tokens, 1} = Compiler.tokenize("xic t1.dn ote word.3 m1.t1.acc a._b.2")

      assert tokens == [
               {:name, {1, 1}, "xic"},
               {:name, {1, 5}, "t1.dn"},
               {:name, {1, 11}, "ote"},
               {:name, {1, 15}, "word.3"},
               {:name, {1, 22}, "m1.t1.acc"},
               {:name, {1, 32}, "a._b.2"}
             ]
    end

    test "an integer part may hold any digits, and any part may follow it" do
      assert {:ok, tokens, 1} = Compiler.tokenize("word.10 panel.i.0 a.1.b m1.3.acc Timer.DN")

      assert tokens == [
               {:name, {1, 1}, "word.10"},
               {:name, {1, 9}, "panel.i.0"},
               {:name, {1, 19}, "a.1.b"},
               {:name, {1, 25}, "m1.3.acc"},
               {:name, {1, 34}, "Timer.DN"}
             ]
    end

    test "an integer part running into a letter is B2's mistyped lexeme, named whole" do
      # Named on past a `.`, since `b.c` alone is a name: the run is all of `a.1b.c`.
      assert {:error, {{1, 5}, Logex.Lexer, {:missing_separator, "a.1b.c"}}, 1} =
               Compiler.tokenize("xic a.1b.c ote b")

      assert {:error, {{1, 6}, Logex.Lexer, {:missing_separator, "1b.c"}}, 1} =
               Compiler.tokenize("move 1b.c x")

      assert {:error, {{1, 1}, Logex.Lexer, {:missing_separator, "a.1B"}}, 1} =
               Compiler.tokenize("a.1B")

      assert {:error, {{1, 5}, Logex.Lexer, {:missing_separator, "a.1bst"}}, 1} =
               Compiler.tokenize("xic a.1bst ote b")

      assert {:error, {{1, 1}, Logex.Lexer, {:missing_separator, "t1.2_"}}, 1} =
               Compiler.tokenize("t1.2_")

      assert Logex.Lexer.format_error({:missing_separator, "a.1b"}) ==
               ~s(missing separator after integer: "a.1b" is neither a number nor a tag)
    end

    test "a `.` with no name or integer after it is illegal, and there are no decimals" do
      for {source, column} <- [
            {"a.", 2},
            {"a. b", 2},
            {".a", 1},
            {"a..b", 2},
            {"a.b.", 4},
            {"1.5", 2},
            {"a.(", 2}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, {:illegal, "."}}, 1} =
                 Compiler.tokenize(source),
               inspect(source)
      end
    end
  end

  describe "// comments" do
    test "a comment runs to the end of the line, and not past it" do
      assert {:ok, tokens, 2} = Compiler.tokenize("ote a // note\note b")

      assert tokens == [
               {:name, {1, 1}, "ote"},
               {:name, {1, 5}, "a"},
               {:rnd, {1, 14}},
               {:name, {2, 1}, "ote"},
               {:name, {2, 5}, "b"}
             ]

      # A CRLF is located at its LF here too, as B8 has it everywhere.
      for {newline, column} <- [{"\r\n", 12}, {"\r", 11}] do
        assert {:ok, [_, _, {:rnd, {1, ^column}}, _, _], 2} =
                 Compiler.tokenize("ote a // x" <> newline <> "ote b")
      end
    end

    test "a line that is only a comment is a blank line" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 2}}, {:name, {3, 1}, "b"}], 3} =
               Compiler.tokenize("a\n  // note\nb")
    end

    test "it may end the source, follow a token directly, and hold any character" do
      assert {:ok, [{:name, {1, 1}, "ote"}, {:name, {1, 5}, "a"}], 1} =
               Compiler.tokenize("ote a//no space")

      assert {:ok, [_, _], 1} = Compiler.tokenize("ote a // é ✓ ( | ) @ ; 1bst")
      assert {:ok, [_, _], 1} = Compiler.tokenize("ote a // a/b\tc\x01")

      # A character is one column, however many bytes it takes.
      assert {:ok, [_, _, {:rnd, {1, 12}}, _], 2} = Compiler.tokenize("ote a // é✓\nb")
      assert {:ok, [], 1} = Compiler.tokenize("//")
    end

    test "a newline after a comment is located where it is, for the parser's errors" do
      assert {:error, {{1, 14}, Logex.Parser, _}} = parse("( xic aa // x\n)")
    end

    test "a lone / and a ; are still illegal, and so is invalid UTF-8 in a comment" do
      assert {:error, {{1, 7}, Logex.Lexer, {:illegal, "/"}}, 1} = Compiler.tokenize("ote a / b")
      assert {:error, {{1, 6}, Logex.Lexer, {:illegal, ";"}}, 1} = Compiler.tokenize("ote a;")

      assert {:error, {{1, 10}, Logex.Lexer, {:illegal, <<0xFF>>}}, 1} =
               Compiler.tokenize(<<"ote a // ", 0xFF>>)
    end
  end

  describe "input that is not ASCII" do
    # leex reported one character here too. This guards against a lexer that works byte
    # by byte and would report `<<0xC3>>`, the first byte of the character.
    test "a non-ASCII character is reported whole, not by its first byte" do
      assert {:error, {{1, 5}, Logex.Lexer, {:illegal, "é"}}, 1} = Compiler.tokenize("xic é")
    end

    # String.to_charlist/1 raised UnicodeConversionError here before leex ever ran.
    test "a source that is not valid UTF-8 is a located error, not an exception" do
      assert {:error, {{1, 5}, Logex.Lexer, {:illegal, <<0xFF>>}}, 1} =
               Compiler.tokenize(<<"xic ", 0xFF>>)
    end
  end

  describe "B2: a number must be followed by a separator" do
    test "digits running into a letter or _ are one located error naming the whole run" do
      assert {:error, {{1, 5}, Logex.Lexer, {:missing_separator, "1bst"}}, 1} =
               Compiler.tokenize("mov 1bst aa")

      assert {:error, {{2, 3}, Logex.Lexer, {:missing_separator, "12ab_3"}}, 2} =
               Compiler.tokenize("xic aa\n  12ab_3 ote bb")

      # Since decision 149 a `_` may stand between two digits, so `7_` ends on one, and is
      # refused as a separator out of place (below); `7_a` still runs into a letter.
      assert {:error, {_, _, {:missing_separator, "7_a"}}, _} = Compiler.tokenize("mov 7_a aa")
      assert {:error, {_, _, {:missing_separator, "9Z"}}, _} = Compiler.tokenize("mov 9Z aa")
    end

    test "the message says what is wrong" do
      assert Logex.Lexer.format_error({:missing_separator, "1bst"}) ==
               ~s(missing separator after integer: "1bst" is neither a number nor a tag)
    end

    test "numbers, tags ending in digits, and a number before punctuation are unaffected" do
      for source <- ["mov 123 hh", "1", "ote tag1", "ote bst1", "mov 1 aa", "1(", "( mov 7 aa|)"] do
        assert {:ok, _, _} = Compiler.tokenize(source), "#{inspect(source)} should lex"
      end

      assert {:ok, [{:int_lit, {1, 1}, 1}, {:bst, {1, 2}}], 1} = Compiler.tokenize("1(")
    end
  end

  describe "negative literals (M3-3, decision 97): a sign glued to its digits" do
    test "a `-` straight before digits is one int_lit, located at the `-`" do
      assert {:ok, tokens, 1} = Compiler.tokenize("move -5 x eq -0 -007 ( -2147483648 |-1)")

      assert tokens == [
               {:name, {1, 1}, "move"},
               {:int_lit, {1, 6}, -5},
               {:name, {1, 9}, "x"},
               {:name, {1, 11}, "eq"},
               {:int_lit, {1, 14}, 0},
               {:int_lit, {1, 17}, -7},
               {:bst, {1, 22}},
               {:int_lit, {1, 24}, -2_147_483_648},
               {:nxb, {1, 36}},
               {:int_lit, {1, 37}, -1},
               {:bnd, {1, 39}}
             ]

      # Any number of digits, as for a positive one: the compiler says what does not fit.
      assert {:ok, [{:int_lit, {1, 1}, n}], 1} =
               Compiler.tokenize("-" <> String.duplicate("9", 40))

      assert n == -(10 ** 40 - 1)
    end

    test "a `-` with no digit straight after it is illegal, and there is no `+`" do
      for {source, column} <- [
            {"move - 5 x", 6},
            {"move --5 x", 6},
            {"-", 1},
            {"move -x y", 6},
            {"ote a-b", 6},
            {"move 7 -", 8}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, {:illegal, "-"}}, 1} =
                 Compiler.tokenize(source),
               inspect(source)
      end

      assert {:error, {{1, 6}, Logex.Lexer, {:illegal, "+"}}, 1} = Compiler.tokenize("move +5 x")
    end

    # B2 widened to `-?[0-9]+`: a signed number running into a letter or `_` is named whole.
    test "a signed number running into a letter is B2's mistyped lexeme, named whole" do
      assert {:error, {{1, 6}, Logex.Lexer, {:missing_separator, "-5ab"}}, 1} =
               Compiler.tokenize("move -5ab x")

      assert {:error, {{2, 1}, Logex.Lexer, {:missing_separator, "-12_x.y"}}, 2} =
               Compiler.tokenize("xic a\n-12_x.y")
    end

    # A sign begins a number, so it needs a separator before it: `a-5` is no tag and then a
    # literal, which would be a silent split, nor a subtraction, which is `sub`.
    test "a name or number running straight into a signed number is one lexeme, named whole" do
      for {source, column, run} <- [
            {"ote a-5", 5, "a-5"},
            {"xic t1.dn-5", 5, "t1.dn-5"},
            {"move 5-3 x", 6, "5-3"},
            {"move -5-3 x", 6, "-5-3"},
            {"eq a.1-5x b", 4, "a.1-5x"},
            {"xic a\n\n  b-0", 3, "b-0"}
          ] do
        assert {:error, {{line, ^column}, Logex.Lexer, {:signed_inside, ^run}}, line} =
                 Compiler.tokenize(source),
               inspect(source)
      end

      assert Logex.Lexer.format_error({:signed_inside, "a-5"}) ==
               ~s(missing separator before `-`: "a-5" is neither a tag nor a number, and a ) <>
                 "sign begins a number"
    end

    test "a sign after punctuation or a separator begins a number" do
      for source <- ["(-5)", "( -5 | -6 )", "move -5\tx", "move -5\r\nmove -6 y", "xic a // -5"] do
        assert {:ok, _, _} = Compiler.tokenize(source), inspect(source)
      end
    end

    test "parse/1 keeps a negative literal as any other, and the printer gives it back" do
      assert {:ok, {:routine, {:rungs, [rung: [_, {:int_lit, 1, -900}, _]]}} = tree} =
               parse("move -900 speed_sp")

      assert Logex.Printer.print(tree) == "move -900 speed_sp"
    end
  end

  describe "based literals and `_` separators (M5-7, decision 149)" do
    test "a based literal is one int_lit, the number it spells, located at its first digit" do
      assert {:ok, tokens, 1} =
               Compiler.tokenize("move 16#ff x eq 16#FFFF 2#1010_0000 ( 16#Ff |2#0)")

      assert tokens == [
               {:name, {1, 1}, "move"},
               {:int_lit, {1, 6}, 255},
               {:name, {1, 12}, "x"},
               {:name, {1, 14}, "eq"},
               {:int_lit, {1, 17}, 65_535},
               {:int_lit, {1, 25}, 160},
               {:bst, {1, 37}},
               {:int_lit, {1, 39}, 255},
               {:nxb, {1, 45}},
               {:int_lit, {1, 46}, 0},
               {:bnd, {1, 49}}
             ]

      # Any number of digits, as for a decimal one: the slot judges what fits (decision 149).
      assert {:ok, [{:int_lit, {1, 1}, n}], 1} =
               Compiler.tokenize("16#" <> String.duplicate("f", 40))

      assert n == 16 ** 40 - 1

      assert {:ok, [{:int_lit, _, 0xFFFF_FFFF_FFFF_FFFF}], 1} =
               Compiler.tokenize("16#ffff_ffff_ffff_ffff")
    end

    test "a single `_` may stand between two digits of any number, signed too" do
      for {source, value} <- [
            {"1_000", 1000},
            {"1_000_000", 1_000_000},
            {"-1_000", -1000},
            {"0_7", 7},
            {"16#f_f", 255},
            {"2#1_0", 2}
          ] do
        assert {:ok, [{:int_lit, {1, 1}, ^value}], 1} = Compiler.tokenize(source), source
      end

      assert {:ok, [_, {:int_lit, {1, 6}, -1000}, {:name, {1, 13}, "x"}], 1} =
               Compiler.tokenize("move -1_000 x")
    end

    test "each refusal is located at the number's start and names it whole" do
      for {source, column, reason} <- [
            {"move 8#17 x", 6, {:base, "8#17"}},
            {"move 10#5 x", 6, {:base, "10#5"}},
            {"move 016#ff x", 6, {:base, "016#ff"}},
            {"move 1_6#ff x", 6, {:base, "1_6#ff"}},
            {"move 16#-1 x", 6, {:signed_based, "16#-1"}},
            {"move -16#1 x", 6, {:signed_based, "-16#1"}},
            {"move -2#1 x", 6, {:signed_based, "-2#1"}},
            # The base is judged before the sign (M5-7's review).
            {"move -8#17 x", 6, {:base, "-8#17"}},
            {"move -10#5 x", 6, {:base, "-10#5"}},
            # A second `#` is in the number, Ada's `16#ff#` among them (M5-7's review).
            {"move 16#ff# x", 6, {:hash, "16#ff#"}},
            {"move 16#FF# x", 6, {:hash, "16#FF#"}},
            {"move 2#1#1 x", 6, {:hash, "2#1#1"}},
            {"move 16#ff#1 x", 6, {:hash, "16#ff#1"}},
            {"move 16##1 x", 6, {:hash, "16##1"}},
            {"move 1_6#ff# x", 6, {:base, "1_6#ff#"}},
            {"move 16#f_# x", 6, {:separator, "16#f_#"}},
            {"move 16#_ff x", 6, {:separator, "16#_ff"}},
            {"move 16#ff_ x", 6, {:separator, "16#ff_"}},
            {"move 2#1__0 x", 6, {:separator, "2#1__0"}},
            {"move 1__0 x", 6, {:separator, "1__0"}},
            {"move 1_ x", 6, {:separator, "1_"}},
            {"move 7_ x", 6, {:separator, "7_"}},
            {"move -5_ x", 6, {:separator, "-5_"}},
            {"move 16# x", 6, {:digits, 16, "16#"}},
            {"move 2# x", 6, {:digits, 2, "2#"}},
            {"move 2#102 x", 6, {:digits, 2, "2#102"}},
            {"move 16#fg x", 6, {:digits, 16, "16#fg"}},
            {"xic a\n  move 16#z bb", 8, {:digits, 16, "16#z"}}
          ] do
        assert {:error, {{line, ^column}, Logex.Lexer, ^reason}, line} =
                 Compiler.tokenize(source),
               inspect(source)
      end
    end

    test "the vendors' suffixes are B2's mistyped lexeme, at their columns, and `_1` a name" do
      for {source, column, run} <- [
            {"move 5U x", 6, "5U"},
            {"move 5L x", 6, "5L"},
            {"eq a 16 ote 300U", 13, "300U"},
            {"move 1_000bst x", 6, "1_000bst"},
            {"move 1_a x", 6, "1_a"}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, {:missing_separator, ^run}}, 1} =
                 Compiler.tokenize(source),
               inspect(source)
      end

      assert {:ok, [_, {:name, {1, 6}, "_1"}, _], 1} = Compiler.tokenize("move _1 x")
    end

    # Reals are M5-10's, so until then a `.` after digits is illegal where it stands, as
    # before decision 149; and a sign after a based number is the next lexeme's.
    test "what follows a number is read as it was before" do
      for {source, column, reason} <- [
            {"move 1.5_ x", 7, {:illegal, "."}},
            {"move 1.5L x", 7, {:illegal, "."}},
            {"move 16#ff.3 x", 11, {:illegal, "."}},
            {"move 16 #ff x", 9, {:illegal, "#"}},
            {"move 16#ff-1 x", 6, {:signed_inside, "16#ff-1"}},
            {"move 1_0-1 x", 6, {:signed_inside, "1_0-1"}}
          ] do
        assert {:error, {{1, ^column}, Logex.Lexer, ^reason}, 1} = Compiler.tokenize(source),
               inspect(source)
      end
    end

    test "each message says what is wrong" do
      assert Logex.Lexer.format_error({:separator, "1__0"}) ==
               ~s("1__0" is no number: a `_` in a number stands only between two digits)

      assert Logex.Lexer.format_error({:base, "8#17"}) ==
               ~s("8#17" is no number: a based number is written in base 16, `16#ff`, or ) <>
                 "base 2, `2#1010`, and logex reads no other base"

      assert Logex.Lexer.format_error({:signed_based, "16#-1"}) ==
               ~s("16#-1" is no number: a based number takes no sign)

      assert Logex.Lexer.format_error({:digits, 16, "16#fg"}) ==
               ~s("16#fg" is no number: a number in base 16 is written with the digits 0 to 9 ) <>
                 "and a to f, in either case, after its `16#`"

      assert Logex.Lexer.format_error({:hash, "16#ff#"}) ==
               ~s("16#ff#" is no number: a based number holds one `#`, between its base and ) <>
                 "its digits, `16#ff`"

      assert Logex.Lexer.format_error({:digits, 2, "2#102"}) ==
               ~s("2#102" is no number: a number in base 2 is written with the digits 0 and 1 ) <>
                 "after its `2#`"

      assert {:error, [%Logex.Diagnostic{stage: :lex, line: 1, column: 6} = d]} =
               Logex.compile("move 8#17 x", name: "m")

      assert Logex.Diagnostic.format(d) =~ ~s(line 1, column 6: "8#17" is no number)
    end

    # A plain decimal is read by `String.to_integer/1` as before, so it costs what it did,
    # 2 reductions more than a name of its length; a `_` or a base is read digit by digit,
    # and every spelling is linear in the number of literals and in their digits. Counted
    # where the collector never runs, so each count is the same on every run.
    test "growth: a plain decimal costs what it did, and every spelling is linear" do
      line = fn word, n -> lexed(String.duplicate("mov #{word} hh\n", n)) end
      per = fn word -> (line.(word, 200) - line.(word, 100)) / 100 end

      assert per.("1234") <= per.("abcd") + 2
      assert per.("-1234") <= per.("abcd") + 2

      for word <- ["1234", "1_234", "16#04d2", "2#1_0011_0100_10", "-1_234"] do
        assert line.(word, 400) <= 2 * line.(word, 200) + 20, word
      end

      digits = fn n -> lexed("move 16#" <> String.duplicate("f_", n) <> "f x") end
      # Its digits are read by `String.to_integer/2`, a little more than linear in them: a
      # read digit by digit with an integer grown at each was 3.5 times the cost at twice
      # the digits.
      assert digits.(2000) <= 2.2 * digits.(1000)
    end
  end

  describe "error messages say what is wrong and point at where to fix it" do
    test "an unclosed group is reported at the innermost ( still open" do
      assert {:error, {{1, 1}, Logex.Parser, :unclosed}} = parse("( ( xic aa ) ote bb")
      assert {:error, {{1, 12}, Logex.Parser, :unclosed}} = parse("( xic aa | ( xic bb")

      assert Logex.Parser.format_error(:unclosed) ==
               "this `(` is never closed: the input ends before its `)`"
    end

    test "an unexpected token names what was expected" do
      assert {:error, {{1, 8}, Logex.Parser, reason}} = parse("xic aa )")
      assert Logex.Parser.format_error(reason) == "expected a newline or end of input, found `)`"

      assert {:error, {{1, 9}, Logex.Parser, reason}} = parse("( xic aa\n)")
      assert Logex.Parser.format_error(reason) == "expected `|` or `)`, found a newline"
    end

    test "a token the lexer never makes is an error, not a crash" do
      assert {:error, {{1, 1}, Logex.Parser, reason}} = Compiler.parse([{:foo, {1, 1}}])

      assert Logex.Parser.format_error(reason) ==
               "expected a newline or end of input, found {:foo, {1, 1}}"

      # A token list in the old leex shape, whose location is a bare line.
      assert {:error, {1, Logex.Parser, _}} = Compiler.parse([{:name, 1, "xic"}])
    end

    test "an illegal character is quoted" do
      assert {:error, {_, Logex.Lexer, reason}, _} = Compiler.tokenize("xic @")
      assert Logex.Lexer.format_error(reason) == ~s(illegal character "@")
    end
  end

  describe "a checkout built before the hand-written front end" do
    # Pulling the rewrite leaves the old front end's modules in _build. The first build of
    # an environment built before the pull deletes the generated src/*.erl but keeps their
    # modules; a build of any other environment compiles them afresh. Nothing calls them,
    # but `mix test --cover` crashes on them.
    test "has none of the leex/yecc front end's modules left" do
      for module <- [:ladder_lexer, :ladder_parser] do
        refute Code.ensure_loaded?(module),
               "#{inspect(module)} is left over from the leex/yecc front end: " <>
                 "run `rm -rf src/*.erl _build` once"
      end
    end
  end

  defp lexed(source) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          {:ok, _, _} = Compiler.tokenize(source)
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 4_000_000]
      )

    assert_receive {:reductions, n}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    n
  end

  defp parse(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    Compiler.parse(tokens)
  end
end
