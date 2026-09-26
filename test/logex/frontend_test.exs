defmodule Logex.FrontendTest do
  @moduledoc """
  What the hand-written front end does differently from the leex/yecc one it replaced,
  on purpose: positions with columns, invalid UTF-8, and the B2 fix. Everything else it
  does the same, which `frontend_golden_test.exs` checks against the record the old front
  end wrote; these are the exceptions, and each test here fails against that front end.
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

  describe "input that is not ASCII" do
    test "a non-ASCII character is one illegal character, not the bytes of one" do
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

    test "an illegal character is quoted" do
      assert {:error, {_, Logex.Lexer, reason}, _} = Compiler.tokenize("xic @")
      assert Logex.Lexer.format_error(reason) == ~s(illegal character "@")
    end
  end

  defp parse(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    Compiler.parse(tokens)
  end
end
