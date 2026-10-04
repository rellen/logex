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
                [{:name, 4, "move"}, {:name, 4, "aa"}, {:name, 4, "bb"}],
                [{:name, 4, "move"}, {:name, 4, "cc"}, {:name, 4, "dd"}],
                [
                  {:name, 4, "move"},
                  {:name, 4, "ee"},
                  {:name, 4, "ff"},
                  {:branches, [[{:name, 4, "move"}, {:int_lit, 4, 123}, {:name, 4, "hh"}]]}
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

    declared =
      Enum.map(~w(aa bb cc dd ee ff hh), &Logex.Tag.new!(&1, :dint)) ++
        Enum.map(~w(xx yy zz), &Logex.Tag.new!(&1, :bool))

    assert {:ok, %Logex.Program{rungs: rungs}} = Logex.Compiler.instructionize(ast, declared)

    assert rungs ==
             [
               {:rung,
                [
                  {:branches,
                   [
                     [{:move, 4, [{:name, 4, "aa"}, {:name, 4, "bb"}]}],
                     [{:move, 4, [{:name, 4, "cc"}, {:name, 4, "dd"}]}],
                     [
                       {:move, 4, [{:name, 4, "ee"}, {:name, 4, "ff"}]},
                       {:branches, [[{:move, 4, [{:int_lit, 4, 123}, {:name, 4, "hh"}]}]]}
                     ]
                   ]},
                  {:branches,
                   [
                     [{:ote, 4, [{:name, 4, "xx"}]}],
                     [{:ote, 4, [{:name, 4, "yy"}]}]
                   ]}
                ]},
               {:rung, [{:ote, 9, [{:name, 9, "zz"}]}]}
             ]
  end

  describe "an instruction's slots (M2-5)" do
    # Logex.Warnings and Logex.Edit look every instruction's slots up through
    # Logex.Compiler.signature/2, never in a table of their own.
    test "each instruction a compile gives has its mnemonic's signature" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input start bool\nvar_input stop bool\n" <>
            "var_output run bool\n( xic start | xic run ) xio stop ote run",
          name: "seal"
        )

      source = """
      var a bool
      var b bool
      var c bool
      var e bool
      var g bool
      var h bool
      var d dint
      var f dint
      var t1 ton
      var s1 seal
      xic a xio b ons e ote c
      xic a otl b
      xic a otu b
      move d f
      eq d 1 ne d 4 lt d 2 gt d 0 le d 3 ge d 0 ote g
      xic a ton t1 100
      cal s1 a 0 h
      """

      assert {:ok, %Logex.Program{rungs: rungs, tags: tags}} =
               Logex.compile(source, name: "every", types: [seal])

      table =
        Map.new(Logex.Compiler.instructions(), fn {_word, {symbol, signature}} ->
          {symbol, signature}
        end)

      instructions = for {:rung, elements} <- rungs, instruction <- elements, do: instruction

      assert Enum.sort(Enum.uniq(for {symbol, _, _} <- instructions, do: symbol)) ==
               Enum.sort(Map.keys(table))

      # `cal`'s entry is a marker: its slots are its instance's type's, the instance and
      # then a slot per formal, the var_inputs read and the var_output written.
      assert table.cal == :block

      expected =
        Map.put(table, :cal, [
          {:instance, "seal"},
          {:value, :bool},
          {:value, :bool},
          {:write, :bool}
        ])

      for {symbol, _line, _operands} = instruction <- instructions,
          do: assert(Logex.Compiler.signature(instruction, tags) == Map.fetch!(expected, symbol))
    end

    # Total: the lookup never raises, whatever a program built by hand holds. A `cal` has
    # slots only where its instance is a user block's in the table given.
    test "an instruction no mnemonic gives, or anything that is not an instruction, has none" do
      tags = %{
        "a" => Logex.Tag.new!("a", :bool),
        "t1" => Logex.Tag.new!("t1", Logex.FbType.ton())
      }

      for anything <- [{:nope, 1, [{:name, 1, "a"}]}, {:xic, 1}, :xic, nil, [], %{}],
          do: assert(Logex.Compiler.signature(anything, %{}) == [])

      for cal <- [
            {:cal, 1, [{:name, 1, "zz"}]},
            {:cal, 1, [{:name, 1, "a"}]},
            {:cal, 1, [{:name, 1, "t1"}]},
            {:cal, 1, [{:int_lit, 1, 5}]},
            {:cal, 1, []},
            {:cal, 1, :junk}
          ],
          table <- [tags, %{}, :junk],
          do: assert(Logex.Compiler.signature(cal, table) == [])
    end
  end
end
