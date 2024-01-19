defmodule Logex.LexAndParseTest do
  use ExUnit.Case

  test "lexes and parses" do
    source =
      "bst mov aa bb nxb mov cc dd nxb mov ee ff bst mov 123 hh bnd bnd bst ote xx nxb ote yy bnd"

    {:ok, tokens, _} = Logex.Compiler.tokenize(source)

    {:ok, ast} = Logex.Compiler.parse(tokens)

    assert ast ==
             {:rung,
              [
                branches: [
                  [name: ~c"mov", name: ~c"aa", name: ~c"bb"],
                  [name: ~c"mov", name: ~c"cc", name: ~c"dd"],
                  [
                    name: ~c"mov",
                    name: ~c"ee",
                    name: ~c"ff",
                    branches: [[name: ~c"mov", int_lit: 123, name: ~c"hh"]]
                  ]
                ],
                branches: [[name: ~c"ote", name: ~c"xx"], [name: ~c"ote", name: ~c"yy"]]
              ]}
  end
end
