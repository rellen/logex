defmodule Logex.FrontendTest do
  @moduledoc """
  What the hand-written front end does differently from the leex/yecc one it replaced,
  on purpose. Everything else it does the same, which `frontend_golden_test.exs` checks
  against the record the old front end wrote; these are the exceptions, and each test
  here fails against that front end.
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

  defp parse(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    Compiler.parse(tokens)
  end
end
