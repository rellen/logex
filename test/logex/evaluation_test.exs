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

  # DOC-1's close (decision 605; RV-34): a de-energised `ote` writes 0 and passes no power,
  # so the coil after it on the rung writes 0 too, and a contact after it in series is
  # never reached with power; the mutant that gives power out of a de-energised `ote` set
  # `c` here, and this file passed it, one end-to-end test, two walks and the examples'
  # test catching it.
  test "a de-energised ote writes 0 and passes no power to what follows it" do
    rungs = [
      {:rung,
       [
         {:xic, 1, [{:name, 1, "a"}]},
         {:ote, 1, [{:name, 1, "b"}]},
         {:ote, 1, [{:name, 1, "c"}]}
       ]},
      {:rung,
       [
         {:xic, 2, [{:name, 2, "a"}]},
         {:ote, 2, [{:name, 2, "d"}]},
         {:xio, 2, [{:name, 2, "a"}]},
         {:ote, 2, [{:name, 2, "e"}]}
       ]}
    ]

    program = %Logex.Program{rungs: rungs, tags: %{}}

    assert env_after(program, %{"a" => 0, "b" => 1, "c" => 1, "d" => 1, "e" => 1}) ==
             %{"a" => 0, "b" => 0, "c" => 0, "d" => 0, "e" => 0}

    assert env_after(program, %{"a" => 1, "b" => 0, "c" => 0, "d" => 0, "e" => 1}) ==
             %{"a" => 1, "b" => 1, "c" => 1, "d" => 1, "e" => 0}
  end

  # One scan through the public API, from an env the test chooses: a program and an
  # instance built by hand, which Logex.Runtime runs without checking (outside its contract).
  defp env_after(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: true}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 0, first: true})
    state.env
  end
end
