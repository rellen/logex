defmodule Logex.EvaluationTest do
  use ExUnit.Case

  test "evaluates an AST with OTEs" do
    ast =
      {:routine,
       {:rungs,
        [
          {:rung,
           [
             {:branches,
              [
                [
                  {:xio, 2, [{:name, 2, "bit0"}]},
                  {:move, 2, [{:name, 2, "aa"}, {:name, 2, "bb"}]}
                ],
                [
                  {:xic, 2, [{:name, 2, "bit0"}]},
                  {:move, 2, [{:int_lit, 2, 123}, {:name, 2, "dd"}]}
                ]
              ]},
             {:branches,
              [
                [{:xic, 2, [{:name, 2, "bit1"}]}, {:ote, 2, [{:name, 2, "xx"}]}],
                [{:xio, 2, [{:name, 2, "bit1"}]}, {:ote, 2, [{:name, 2, "yy"}]}]
              ]}
           ]}
        ]}}

    env = %{
      "bit0" => 1,
      "bit1" => 0,
      "aa" => 1,
      "bb" => 2,
      "dd" => 3,
      "xx" => 1,
      "yy" => 0
    }

    result = Logex.Compiler.evaluate(ast, {true, env})

    assert result ==
             {true,
              %{
                "bit0" => 1,
                "bit1" => 0,
                "aa" => 1,
                "bb" => 2,
                "dd" => 123,
                "xx" => 0,
                "yy" => 1
              }}
  end

  test "evaluates an AST with OTLs and OTUs" do
    ast =
      {:routine,
       {:rungs,
        [
          {:rung,
           [
             {:branches,
              [
                [
                  {:xio, 2, [{:name, 2, "bit0"}]},
                  {:move, 2, [{:name, 2, "aa"}, {:name, 2, "bb"}]}
                ],
                [
                  {:xic, 2, [{:name, 2, "bit0"}]},
                  {:move, 2, [{:int_lit, 2, 123}, {:name, 2, "dd"}]}
                ]
              ]},
             {:branches,
              [
                [{:xic, 2, [{:name, 2, "bit1"}]}, {:otu, 2, [{:name, 2, "xx"}]}],
                [{:xio, 2, [{:name, 2, "bit1"}]}, {:otl, 2, [{:name, 2, "yy"}]}]
              ]}
           ]}
        ]}}

    env = %{
      "bit0" => 1,
      "bit1" => 0,
      "aa" => 1,
      "bb" => 2,
      "dd" => 3,
      "xx" => 1,
      "yy" => 0
    }

    result = Logex.Compiler.evaluate(ast, {true, env})

    assert result ==
             {true,
              %{
                "bit0" => 1,
                "bit1" => 0,
                "aa" => 1,
                "bb" => 2,
                "dd" => 123,
                "xx" => 1,
                "yy" => 1
              }}
  end
end
