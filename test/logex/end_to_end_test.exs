defmodule Logex.EndToEndTest do
  @moduledoc """
  Drives ladder source all the way to an environment.

  Every other test in this suite hand-types the input to a single stage, so a
  mismatch at a stage boundary is invisible to all of them — which is how the
  `:lit_int` / `:int_lit` transposition survived eight commits with a green
  suite. These tests name no IR tag at all: they can only be satisfied by the
  stages actually agreeing with each other.
  """
  use ExUnit.Case

  defp run(src, env) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(src)
    {:ok, ast} = Logex.Compiler.parse(tokens)

    {_power_flow, new_env} =
      ast
      |> Logex.Compiler.instructionize()
      |> Logex.Compiler.evaluate({true, env})

    new_env
  end

  defp rung_count(src) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(src)
    {:ok, {:routine, {:rungs, rungs}}} = Logex.Compiler.parse(tokens)
    length(rungs)
  end

  defp parse_error?(src) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(src)
    match?({:error, _}, Logex.Compiler.parse(tokens))
  end

  describe "integer literals" do
    test "mov of a literal writes the literal" do
      assert %{"dd" => 123} = run("mov 123 dd", %{"dd" => 0})
    end

    test "mov of a tag copies the tag" do
      assert %{"dd" => 7} = run("mov aa dd", %{"aa" => 7})
    end

    test "the showcase routine from lex_and_parse_test.exs" do
      src =
        "bst mov aa bb nxb mov cc dd nxb mov ee ff bst mov 123 hh bnd bnd " <>
          "bst ote xx nxb ote yy bnd"

      assert %{
               "aa" => 1,
               "bb" => 1,
               "cc" => 2,
               "dd" => 2,
               "ee" => 3,
               "ff" => 3,
               "hh" => 123,
               "xx" => 1,
               "yy" => 1
             } = run(src, %{"aa" => 1, "cc" => 2, "ee" => 3})
    end
  end

  describe "rungs" do
    test "each rung starts with its own power flow" do
      assert %{"r1" => 0, "r2" => 1} = run("xic gg ote r1\note r2", %{"gg" => 0, "r1" => 1})
    end

    test "a trailing newline is not a syntax error" do
      assert %{"xx" => 1} = run("ote xx\n", %{})
    end

    test "leading, repeated and CRLF newlines are all one delimiter" do
      assert %{"xx" => 1} = run("\note xx", %{})
      assert %{"xx" => 1, "yy" => 1} = run("ote xx\n\n\note yy\n", %{})
      assert %{"xx" => 1, "yy" => 1} = run("ote xx\r\note yy\r\n", %{})
      assert %{"xx" => 1, "yy" => 1} = run("  ote xx  \n\n  ote yy\n", %{})
    end

    test "blank lines do not become empty rungs" do
      assert 1 = rung_count("ote xx\n")
      assert 1 = rung_count("\note xx")
      assert 2 = rung_count("ote xx\n\n\note yy\n")
      assert 0 = rung_count("")
      assert 0 = rung_count("\n\n\n")
    end

    test "an empty program is a legal no-op, not a parse error" do
      assert %{"aa" => 1} = run("", %{"aa" => 1})
    end
  end

  describe "branches" do
    test "parallel branches OR, and every branch still runs for its side effects" do
      env = run("bst xic aa ote p1 nxb xic bb ote p2 bnd ote res", %{"aa" => 1, "p2" => 1})
      assert %{"p1" => 1, "p2" => 0, "res" => 1} = env
    end

    test "a nested branch group is an AND of an OR" do
      src = "xic aa bst xic bb nxb xic cc bnd ote res"
      assert %{"res" => 1} = run(src, %{"aa" => 1, "bb" => 0, "cc" => 1})
      assert %{"res" => 0} = run(src, %{"aa" => 1, "bb" => 0, "cc" => 0})
    end

    test "an empty branch leg is a jumper and passes power unconditionally" do
      assert %{"xx" => 1} = run("bst xic aa nxb bnd ote xx", %{"aa" => 0})
      assert %{"xx" => 1} = run("bst bnd ote xx", %{})
    end

    test "unbalanced branch tokens are still rejected" do
      assert parse_error?("xic aa bnd")
      assert parse_error?("bst xic aa")
      assert parse_error?("xic aa nxb ote bb")
    end
  end

  describe "output instructions" do
    test "ote de-energises on a false rung, otl does not" do
      assert %{"xx" => 0} = run("xic gg ote xx", %{"gg" => 0, "xx" => 1})
      assert %{"xx" => 1} = run("xic gg otl xx", %{"gg" => 0, "xx" => 1})
    end
  end

  describe "a seal-in motor circuit, one scan per evaluate/2 call" do
    @seal "bst xic start nxb xic motor bnd xio stop ote motor"

    test "starts, seals in when the button is released, and drops out on stop" do
      scan1 = run(@seal, %{"start" => 1, "stop" => 0, "motor" => 0})
      assert %{"motor" => 1} = scan1

      scan2 = run(@seal, Map.put(scan1, "start", 0))
      assert %{"motor" => 1} = scan2, "the seal-in branch should hold the motor on"

      scan3 = run(@seal, Map.put(scan2, "stop", 1))
      assert %{"motor" => 0} = scan3
    end
  end
end
