defmodule Logex.InstructionizeTest do
  use ExUnit.Case

  test "instructionizes an AST" do
    ast =
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

    result = Logex.Compiler.instructionize(ast)

    assert result ==
             {:routine,
              {:rungs,
               [
                 {:rung,
                  [
                    {:branches,
                     [
                       [{:mov, [{:name, 1, "aa"}, {:name, 1, "bb"}]}],
                       [{:mov, [{:name, 1, "cc"}, {:name, 1, "dd"}]}],
                       [
                         {:mov, [{:name, 1, "ee"}, {:name, 1, "ff"}]},
                         {:branches, [[{:mov, [{:int_lit, 1, 123}, {:name, 1, "hh"}]}]]}
                       ]
                     ]},
                    {:branches,
                     [
                       [{:ote, [{:name, 1, "xx"}]}],
                       [{:ote, [{:name, 1, "yy"}]}]
                     ]}
                  ]}
               ]}}
  end
end
