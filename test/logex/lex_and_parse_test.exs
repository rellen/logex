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
                    branches: [
                      [name: "mov", name: "aa", name: "bb"],
                      [name: "mov", name: "cc", name: "dd"],
                      [
                        name: "mov",
                        name: "ee",
                        name: "ff",
                        branches: [[name: "mov", int_lit: 123, name: "hh"]]
                      ]
                    ],
                    branches: [[name: "ote", name: "xx"], [name: "ote", name: "yy"]]
                  ]}
               ]}}
  end

  test "lexes and parses two rungs" do
    source = "ote yy\note xx"

    {:ok, tokens, _} = Logex.Compiler.tokenize(source)

    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert ast ==
             {:routine,
              {:rungs, [{:rung, [name: "ote", name: "yy"]}, {:rung, [name: "ote", name: "xx"]}]}}
  end
end
