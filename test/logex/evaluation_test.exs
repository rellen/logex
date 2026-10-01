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

    {:routine, {:rungs, rungs}} = ast

    assert env_after(%Logex.Program{rungs: rungs, tags: %{}}, env) ==
             %{
               "bit0" => 1,
               "bit1" => 0,
               "aa" => 1,
               "bb" => 2,
               "dd" => 123,
               "xx" => 0,
               "yy" => 1
             }
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

    {:routine, {:rungs, rungs}} = ast

    assert env_after(%Logex.Program{rungs: rungs, tags: %{}}, env) ==
             %{
               "bit0" => 1,
               "bit1" => 0,
               "aa" => 1,
               "bb" => 2,
               "dd" => 123,
               "xx" => 1,
               "yy" => 1
             }
  end

  # OE-1: an instance's block list names storage bits, which are declared bools, so no
  # compiled program has an `ons` on a member. One built by hand is run all the same, and
  # never blocked, whatever the list holds.
  test "an ons on a member, which only a program built by hand holds, is never blocked" do
    rungs = [
      {:rung,
       [
         {:xic, 1, [{:name, 1, "go"}]},
         {:ons, 1, [{:member, 1, ["fb", "x"]}]},
         {:ote, 1, [{:name, 1, "pulse"}]}
       ]}
    ]

    state = %Logex.Instance{
      type: nil,
      env: %{"go" => 1, "fb" => %{"x" => 0}, "pulse" => 0},
      now: 0,
      first: false,
      ons_blocked: ["fb.x", "fb", "x"]
    }

    program = %Logex.Program{rungs: rungs, tags: %{}}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 1, first: false})
    assert state.env == %{"go" => 1, "fb" => %{"x" => 1}, "pulse" => 1}
  end

  # One scan through the public API, from an env the test chooses: a program and an
  # instance built by hand, which Logex.Runtime runs without checking (outside its contract).
  defp env_after(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: true}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 0, first: true})
    state.env
  end
end
