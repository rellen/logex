defmodule Logex.ValidationTest do
  @moduledoc """
  M1-2: `instructionize/1` checks every instruction against its operand signature and
  returns located diagnostics instead of raising. Each case in PLAN.md's M1-2 table is
  here, driven from source text, and each asserts the whole diagnostic list, so a
  missing, extra or cascading diagnostic fails as surely as a wrong one.
  """
  use ExUnit.Case, async: true

  alias Logex.Compiler

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

      assert errors("mov src") == [
               "line 1: `mov` expects 2 operands (a value, then a tag), found 1"
             ]
    end

    test "a mnemonic is never taken as an operand" do
      # The worst case: no exception, and a coil became a tag called `ote`.
      assert errors("mov src ote") == [
               "line 1: `mov` expects 2 operands (a value, then a tag), found 1 — " <>
                 "`ote` is an instruction, not a tag",
               "line 1: `ote` expects 1 operand (a tag), found none"
             ]

      # Stopping at the mnemonic keeps the instruction after it intact.
      assert errors("mov src ote bb") == [
               "line 1: `mov` expects 2 operands (a value, then a tag), found 1 — " <>
                 "`ote` is an instruction, not a tag"
             ]
    end

    test "a literal where a tag must go is named" do
      assert errors("ote 7") == ["line 1: `ote` expects a tag, found `7`"]
      assert errors("mov 1 2") == ["line 1: `mov` expects a tag, found `2`"]
    end
  end

  describe "mnemonics" do
    test "are matched in any case" do
      assert run("XIC aa Ote bb", %{"aa" => 1}) == %{"aa" => 1, "bb" => 1}
    end

    test "are reserved in any case: none may name a tag" do
      assert errors("xic OTE") == [
               "line 1: `xic` expects 1 operand (a tag), found none — " <>
                 "`OTE` is an instruction, not a tag",
               "line 1: `OTE` expects 1 operand (a tag), found none"
             ]
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
    end

    test "skip what follows a word that is not an instruction, up to the next one" do
      assert errors("zzz aa 7 bb ote cc") == ["line 1: unknown instruction `zzz`"]

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
      assert {:ok, {:routine, {:rungs, [{:rung, [{:xic, 3, _}, {:mov, 3, _}]}]}}} =
               compile("\n\nxic aa mov 1 bb")
    end
  end

  defp compile(source) do
    {:ok, tokens, _} = Compiler.tokenize(source)
    {:ok, ast} = Compiler.parse(tokens)
    Compiler.instructionize(ast)
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
