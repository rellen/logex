defmodule Logex.LexAndParseTest do
  use ExUnit.Case

  test "lexes and parses a rung" do
    source = "( mov aa bb | mov cc dd | mov ee ff ( mov 123 hh ) ) ( ote xx | ote yy )"

    {:ok, tokens, _} = Logex.Compiler.tokenize(source)

    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert ast ==
             {:routine,
              {:rungs,
               [
                 {:rung,
                  [
                    {:branches,
                     [
                       [{:name, 1, "mov"}, {:name, 1, "aa"}, {:name, 1, "bb"}],
                       [{:name, 1, "mov"}, {:name, 1, "cc"}, {:name, 1, "dd"}],
                       [
                         {:name, 1, "mov"},
                         {:name, 1, "ee"},
                         {:name, 1, "ff"},
                         {:branches, [[{:name, 1, "mov"}, {:int_lit, 1, 123}, {:name, 1, "hh"}]]}
                       ]
                     ]},
                    {:branches,
                     [
                       [{:name, 1, "ote"}, {:name, 1, "xx"}],
                       [{:name, 1, "ote"}, {:name, 1, "yy"}]
                     ]}
                  ]}
               ]}}
  end

  test "lexes and parses two rungs" do
    source = "ote yy\nmov 3 xx"

    {:ok, tokens, _} = Logex.Compiler.tokenize(source)

    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert ast ==
             {:routine,
              {:rungs,
               [
                 {:rung, [{:name, 1, "ote"}, {:name, 1, "yy"}]},
                 {:rung, [{:name, 2, "mov"}, {:int_lit, 2, 3}, {:name, 2, "xx"}]}
               ]}}
  end

  test "every elem carries the line it was read from" do
    # Blank lines, indentation and a CRLF all sit between these rungs. The
    # coalescing rnd rule swallows them as one delimiter, and this asserts that
    # doing so does not lose the count: the rungs are on lines 1, 3 and 6. The
    # last rung puts a branch group and an elem outside it on the same line, so
    # a parser that rebuilt the group's legs without their lines would fail here
    # while the bare elems beside it still passed.
    source = "ote aa\n\n  xic bb ote cc\r\n\n\n( mov 7 dd | xic ee ) ote ff"

    {:ok, tokens, _} = Logex.Compiler.tokenize(source)
    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert {:routine,
            {:rungs,
             [
               {:rung, [{:name, 1, "ote"}, {:name, 1, "aa"}]},
               {:rung,
                [{:name, 3, "xic"}, {:name, 3, "bb"}, {:name, 3, "ote"}, {:name, 3, "cc"}]},
               {:rung,
                [
                  {:branches,
                   [
                     [{:name, 6, "mov"}, {:int_lit, 6, 7}, {:name, 6, "dd"}],
                     [{:name, 6, "xic"}, {:name, 6, "ee"}]
                   ]},
                  {:name, 6, "ote"},
                  {:name, 6, "ff"}
                ]}
             ]}} = ast
  end

  # DOC-1's close (decision 596; RV-34): a four-leg branch with an empty third leg keeps
  # its four legs, the third a jumper, through the parse, the printer and the compile, and
  # its rung is `a` alone, as the empty leg passes the power that comes into the branch.
  # The close's "changes its rung" does not reproduce on `main` at 516afd7.
  test "a four-leg branch with an empty third leg keeps its legs and passes power" do
    source = "xic a ( xic b | xic c | | xic d ) ote e"
    {:ok, tokens, _} = Logex.Compiler.tokenize(source)
    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert {:routine, {:rungs, [{:rung, [_xic, _a, {:branches, legs}, _ote, _e]}]}} = ast

    assert legs == [
             [{:name, 1, "xic"}, {:name, 1, "b"}],
             [{:name, 1, "xic"}, {:name, 1, "c"}],
             [],
             [{:name, 1, "xic"}, {:name, 1, "d"}]
           ]

    assert Logex.Printer.print(ast) == source

    declared =
      Enum.map_join(~w(a b c d), "", &"var_input #{&1} bool\n") <> "var_output e bool\n\n"

    {:ok, p} = Logex.compile(declared <> source <> "\n", name: "p")

    for {a, e} <- [{0, 0}, {1, 1}] do
      s = Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"a" => a})
      assert {%{"e" => ^e}, _s} = Logex.Runtime.scan(p, s)
    end
  end
end
