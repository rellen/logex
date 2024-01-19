defmodule Logex.EvaluationTest do
  use ExUnit.Case

  test "evaluates an AST" do
    ast =
      {:rung,
       [
         branches: [
           [{:xio, [name: "bit0"]}, {:mov, [name: "aa", name: "bb"]}],
           [{:xic, [name: "bit0"]}, {:mov, [lit_int: 123, name: "dd"]}]
         ],
         branches: [
           [{:xic, [name: "bit1"]}, {:ote, name: "xx"}],
           [{:xio, [name: "bit1"]}, {:ote, name: "yy"}]
         ]
       ]}

    env = %{
      "bit0" => 1,
      "bit1" => 0,
      "aa" => 1,
      "bb" => 2,
      "dd" => 3,
      "xx" => 0,
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
end
