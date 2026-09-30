defmodule Logex.FrontendTest do
  @moduledoc """
  What `frontend_golden_test.exs` cannot check. That record reduces every location to its
  line and keeps the AST rather than the tokens, so it cannot see columns, messages, or
  the token stream itself. The deliberate departures from the leex/yecc front end are
  pinned here too: columns, invalid UTF-8, B2 and B8. So are `//` comments, which leex's
  lexer never had. All but one of these tests fail against
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

    test "a CR before a CRLF is a newline of its own, in the same run" do
      assert {:ok, [{:name, {1, 1}, "a"}, {:rnd, {1, 2}}, {:name, {3, 1}, "b"}], 3} =
               Compiler.tokenize("a\r\r\nb")
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

      for newline <- ["\r\n", "\r"] do
        assert {:ok, [_, _, {:rnd, _}, _, _], 2} =
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

      assert {:error, {_, _, {:missing_separator, "7_"}}, _} = Compiler.tokenize("mov 7_ aa")
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

  defp parse(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    Compiler.parse(tokens)
  end
end
