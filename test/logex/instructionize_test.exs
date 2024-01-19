defmodule Logex.InstructionizeTest do
  use ExUnit.Case

  test "instructionizes an AST" do
    ast =
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

    result = Logex.Compiler.instructionize(ast)

    assert result ==
             {:rung,
              [
                branches: [
                  [{:mov, [name: "aa", name: "bb"]}],
                  [{:mov, [name: "cc", name: "dd"]}],
                  [
                    {:mov, [name: "ee", name: "ff"]},
                    branches: [[{:mov, [int_lit: 123, name: "hh"]}]]
                  ]
                ],
                branches: [[{:ote, name: "xx"}], [{:ote, name: "yy"}]]
              ]}
  end
end
