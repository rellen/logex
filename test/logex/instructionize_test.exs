defmodule Logex.InstructionizeTest do
  use ExUnit.Case

  test "instructionizes an AST" do
    # Lines are 4 and 9, not 1, so a lowering that rewrote every operand's line
    # to a constant could not satisfy the assertion whatever constant it chose.
    ast =
      {:routine,
       {:rungs,
        [
          {:rung,
           [
             {:branches,
              [
                [{:name, 4, "mov"}, {:name, 4, "aa"}, {:name, 4, "bb"}],
                [{:name, 4, "mov"}, {:name, 4, "cc"}, {:name, 4, "dd"}],
                [
                  {:name, 4, "mov"},
                  {:name, 4, "ee"},
                  {:name, 4, "ff"},
                  {:branches, [[{:name, 4, "mov"}, {:int_lit, 4, 123}, {:name, 4, "hh"}]]}
                ]
              ]},
             {:branches,
              [
                [{:name, 4, "ote"}, {:name, 4, "xx"}],
                [{:name, 4, "ote"}, {:name, 4, "yy"}]
              ]}
           ]},
          {:rung, [{:name, 9, "ote"}, {:name, 9, "zz"}]}
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
                       [{:mov, [{:name, 4, "aa"}, {:name, 4, "bb"}]}],
                       [{:mov, [{:name, 4, "cc"}, {:name, 4, "dd"}]}],
                       [
                         {:mov, [{:name, 4, "ee"}, {:name, 4, "ff"}]},
                         {:branches, [[{:mov, [{:int_lit, 4, 123}, {:name, 4, "hh"}]}]]}
                       ]
                     ]},
                    {:branches,
                     [
                       [{:ote, [{:name, 4, "xx"}]}],
                       [{:ote, [{:name, 4, "yy"}]}]
                     ]}
                  ]},
                 {:rung, [{:ote, [{:name, 9, "zz"}]}]}
               ]}}
  end
end
