defmodule Logex.EvaluationTest do
  use ExUnit.Case

  test "evaluates an AST with OTEs" do
    ast =
      {:routine,
       {:rungs,
        [
          {:rung,
           [
             branches: [
               [{:xio, [{:name, 1, "bit0"}]}, {:mov, [{:name, 1, "aa"}, {:name, 1, "bb"}]}],
               [{:xic, [{:name, 1, "bit0"}]}, {:mov, [{:int_lit, 1, 123}, {:name, 1, "dd"}]}]
             ],
             branches: [
               [{:xic, [{:name, 1, "bit1"}]}, {:ote, [{:name, 1, "xx"}]}],
               [{:xio, [{:name, 1, "bit1"}]}, {:ote, [{:name, 1, "yy"}]}]
             ]
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
             branches: [
               [{:xio, [{:name, 1, "bit0"}]}, {:mov, [{:name, 1, "aa"}, {:name, 1, "bb"}]}],
               [{:xic, [{:name, 1, "bit0"}]}, {:mov, [{:int_lit, 1, 123}, {:name, 1, "dd"}]}]
             ],
             branches: [
               [{:xic, [{:name, 1, "bit1"}]}, {:otu, [{:name, 1, "xx"}]}],
               [{:xio, [{:name, 1, "bit1"}]}, {:otl, [{:name, 1, "yy"}]}]
             ]
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
