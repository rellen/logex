defmodule Logex.LexAndParseTest do
  use ExUnit.Case

  test "lexes and parses a rung" do
    source =
      "bst mov aa bb nxb mov cc dd nxb mov ee ff bst mov 123 hh bnd bnd bst ote xx nxb ote yy bnd"

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
    source = "ote aa\n\n  xic bb ote cc\r\n\n\nbst mov 7 dd nxb xic ee bnd ote ff"

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
end
