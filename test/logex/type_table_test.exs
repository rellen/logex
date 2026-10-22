defmodule Logex.TypeTableTest do
  @moduledoc """
  PLAN M5-1: one table of types in `Logex.Declarations` (`docs/organisation.md` §4.12,
  "The types", decisions 144 and 145), with only `bool` and `dint` in it, which every range
  message, article, guard and `fits?/2` in `lib/` reads, and the configuration file's type
  words and did-you-mean. Nothing a program, a configuration, a host or an edit sees
  changes: each message built from the table is pinned here for both types, whole, from
  source or through the entry point a host calls, as it was before the table, but the
  runner's refusal of a force that does not fit, which `force_test.exs` pins for both.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Declarations, Runtime, Tag}
  alias Logex.Configuration.{Global, Instance, Text}

  @lib Path.expand("../../lib", __DIR__)

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "p", types: types)
    Enum.map(diagnostics, & &1.message)
  end

  defp raised(fun) do
    error = assert_raise ArgumentError, fun
    Exception.message(error)
  end

  setup_all do
    {:ok, motor} =
      Logex.compile(
        "var_input run bool\nvar_input sp dint\nvar_output lamp bool\n" <>
          "var_external estop bool\nvar x dint\nxic run xio estop ote lamp\nxic run move sp x",
        name: "motor"
      )

    %{motor: motor}
  end

  defp configured(text, motor) do
    case Configuration.compile("plant", text, %{"motor" => motor}) do
      {:error, diagnostics} -> Enum.map(diagnostics, & &1.message)
      {:ok, configuration} -> {:ok, configuration}
    end
  end

  describe "the table" do
    test "holds bool and dint, each a row of the record's columns, in its order" do
      assert Declarations.table() == [
               %{
                 word: "bool",
                 type: :bool,
                 kind: :boolean,
                 width: 1,
                 range: 0..1,
                 zero: 0,
                 article: "a"
               },
               %{
                 word: "dint",
                 type: :dint,
                 kind: :signed,
                 width: 32,
                 range: -2_147_483_648..2_147_483_647,
                 zero: 0,
                 article: "a"
               }
             ]

      assert Declarations.elementary() == [:bool, :dint]
      assert Declarations.type_words() == ["bool", "dint"]
      assert Enum.map([:bool, :dint], &Declarations.word/1) == ["bool", "dint"]
      assert Enum.map([:bool, :dint], &Declarations.kind/1) == [:boolean, :signed]

      assert Enum.map([:bool, :dint], &Declarations.range/1) == [
               0..1,
               -2_147_483_648..2_147_483_647
             ]

      assert Enum.map([:bool, :dint], &Declarations.zero/1) == [0, 0]
      assert Enum.map([:bool, :dint], &Declarations.width/1) == [1, 32]
    end

    test "fits?/2 is each row's range, an integer only" do
      for {type, ins, outs} <- [
            {:bool, [0, 1], [-1, 2, 1.0, 0.0, true, false, nil, "1"]},
            {:dint, [-2_147_483_648, 0, 2_147_483_647],
             [-2_147_483_649, 2_147_483_648, 1.0, true, nil, "1"]}
          ] do
        for value <- ins, do: assert(Declarations.fits?(type, value), inspect({type, value}))
        for value <- outs, do: refute(Declarations.fits?(type, value), inspect({type, value}))
      end
    end

    test "is_elementary/1 is a guard over the table's types" do
      import Logex.Declarations, only: [is_elementary: 1]
      kept = for t <- [:bool, :dint, :int, :clock, nil, "bool", %{}], is_elementary(t), do: t
      assert kept == [:bool, :dint]
    end

    test "each message's words come from the row: its article, its values and its width" do
      assert Declarations.a_type(:bool) == "a bool"
      assert Declarations.a_type(:dint) == "a dint"
      assert Declarations.a_type(:clock) == "a clock"
      assert Declarations.a_type(nil) == "a "
      assert Declarations.misfit(:bool, "`2`") == "only 0 or 1 fit, found `2`"
      assert Declarations.misfit(:dint, "`2`") == "`2` does not fit in 32 bits"
      assert Declarations.misfit(:bool) == "only 0 or 1 fit"
      assert Declarations.misfit(:dint) == "it does not fit in 32 bits"

      assert Declarations.initial_misfit(:bool, "`2`") ==
               "its initial value must be 0 or 1, found `2`"

      assert Declarations.initial_misfit(:dint, "`2`") == "`2` does not fit in 32 bits"
      assert Declarations.values(:bool) == "0 or 1"
      assert Declarations.values(:dint) == "an integer from -2147483648 to 2147483647"
      assert Declarations.either(&inspect/1) == ":bool or :dint"
    end

    test "the type words are a declaration's and a configuration file's keywords" do
      assert Enum.all?(["bool", "dint"], &(&1 in Declarations.keywords()))
      assert Enum.all?(["bool", "dint"], &(&1 in Text.keywords()))
      assert Enum.map(["bool", "Dint"], &Declarations.reserved/1) == [:type, :type]
    end

    test "lib/ holds no [:bool, :dint] guard and no hand-written \"32 bits\" outside the table" do
      files = Path.wildcard(Path.join(@lib, "**/*.ex"))
      assert length(files) > 20

      # Words a message said of a type by hand before the table, each now built from its row.
      by_hand = [
        "32 bits",
        "0 or 1",
        ":bool or :dint",
        "a `bool` or a `dint`",
        "-2147483648 to",
        "is a dint"
      ]

      found =
        for file <- files,
            text = File.read!(file),
            word <-
              Enum.filter(
                ["[:bool, :dint]", "in [:bool", "in [:dint"],
                &String.contains?(text, &1)
              ) ++
                Enum.filter(by_hand, &String.contains?(code(text), &1)),
            do: {Path.basename(file), word}

      assert found == []

      # The dint's limits are the table's: only Logex.Declarations writes the lower one.
      limits =
        for file <- files,
            Path.basename(file) != "declarations.ex",
            String.contains?(File.read!(file), "2_147_483_648"),
            do: Path.basename(file)

      assert limits == []
    end

    # An article before an interpolation, quoted in backticks or not, or joined on with
    # `<>`: none names a type. A section, a kind of configuration element, a program type's
    # name, which is any name, and a one-shot's mnemonic, each said letter by letter, are
    # the articles allowed.
    test "lib/ gives a type no article by hand: each `a \#{...}` names a section or a part" do
      allowed = [
        "a \#{tag.section}",
        "a \#{kind(element)}",
        "a `\#{program.name}",
        "an `\#{one_shot}",
        "an `\#{word}"
      ]

      found =
        for file <- Path.wildcard(Path.join(@lib, "**/*.ex")),
            [article] <-
              Regex.scan(~r/\ban? `?#\{[^}]*\}/, File.read!(file)) ++
                Regex.scan(~r/"an? " <>/, File.read!(file)),
            article not in allowed,
            do: {Path.basename(file), article}

      assert found == []
    end
  end

  # A file's code, with its docs and comments taken out: they may say what a message gives,
  # as Logex.Declarations' docs say what its builders give.
  defp code(text) do
    text
    |> String.replace(~r/"""\n.*?"""/s, "")
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
    |> Enum.join("\n")
  end

  describe "each message built from the table, for both types" do
    test "a declared initial value, from source and from Elixir" do
      assert messages("var b bool 2\nvar d dint 2147483648\nvar e dint -2147483649\nxic b ote b") ==
               [
                 "`b` is a bool: its initial value must be 0 or 1, found `2`",
                 "`d` is a dint: `2147483648` does not fit in 32 bits",
                 "`e` is a dint: `-2147483649` does not fit in 32 bits",
                 "`b` is not declared"
               ]

      assert raised(fn -> Tag.new!("b", :bool, :var, 2) end) ==
               "`b` is a bool: its initial value must be 0 or 1, found `2`"

      assert raised(fn -> Tag.new!("d", :dint, :var, 2_147_483_648) end) ==
               "`d` is a dint: `2147483648` does not fit in 32 bits"
    end

    test "a literal in a dint slot, a literal moved into each type, and two types met" do
      assert messages("var d dint\nvar b bool\neq d 2147483648 ote b\nge -2147483649 d ote b") ==
               [
                 "`eq` reads a dint: `2147483648` does not fit in 32 bits",
                 "`ge` reads a dint: `-2147483649` does not fit in 32 bits"
               ]

      assert messages(
               "var b bool\nvar d dint\nvar c bool\nxic c move 2 b\nxic c move 2147483648 d"
             ) ==
               [
                 "`move` writes `2` into `b`, a bool: only 0 or 1 fit",
                 "`move` writes `2147483648` into `d`, a dint: it does not fit in 32 bits"
               ]

      assert messages("var d dint\nvar c bool\nxic c move d c\nxic c move c d") == [
               "`move` takes operands of one type: `d` is a dint, `c` is a bool",
               "`move` takes operands of one type: `c` is a bool, `d` is a dint"
             ]

      assert messages("var d dint\nvar b bool\nxic d.x ote b\nxic d.3 ote b\nxic b ote d") == [
               "`d.x` names a member of `d`, but `d` is a dint (declared on line 1): only an " <>
                 "instance of a function block has members",
               "`d.3` names a bit of `d`, a dint: bit access is not supported yet",
               "`ote` writes a bool, but `d` is a dint (declared on line 1)"
             ]
    end

    test "a literal a `cal` gives a formal of each type" do
      {:ok, seal} =
        Logex.compile(
          "function_block seal\nvar_input start bool\nvar_input sp dint\nvar_output run bool\n" <>
            "var x dint\nxic start ote run\nxic start move sp x",
          name: "seal"
        )

      assert messages("var s1 seal\nvar q bool\ncal s1 7 2147483648 q", [seal]) == [
               "operand 1 of `cal s1` is `start` (var_input bool): only 0 or 1 fit, found `7`",
               "operand 2 of `cal s1` is `sp` (var_input dint): `2147483648` does not fit in 32 bits"
             ]
    end

    test "a host's input of each type" do
      {:ok, program} =
        Logex.compile(
          "var_input b bool\nvar_input d dint\nvar x dint\nvar_output q bool\nxic b ote q\n" <>
            "xic b move d x",
          name: "p"
        )

      state = Runtime.instance(program)

      assert raised(fn ->
               Runtime.put_inputs(program, state, %{"b" => 2, "d" => 2_147_483_648})
             end) ==
               "input `b` is a bool: only 0 or 1 fit, found 2\n" <>
                 "input `d` is a dint: 2147483648 does not fit in 32 bits"

      assert raised(fn -> Runtime.put_inputs(program, state, %{"b" => 1.0, "d" => 1.5}) end) ==
               "input `b` is a bool: only 0 or 1 fit, found 1.0\n" <>
                 "input `d` is a dint: its value must be an integer, found 1.5"

      assert Logex.Program.initial_env(program) == %{"b" => 0, "d" => 0, "q" => 0, "x" => 0}
    end

    test "a global's initial value, a constant connected, a type met and a single", %{
      motor: motor
    } do
      assert configured(
               "var_global estop bool 2\nvar_global x dint 2147483648\nvar_global y dint " <>
                 "-2147483649\nprogram m1 motor\nm1.run estop\nm1.sp y",
               motor
             ) == [
               "`estop` is a bool: its initial value must be 0 or 1, found `2`",
               "`x` is a dint: `2147483648` does not fit in 32 bits",
               "`y` is a dint: `-2147483649` does not fit in 32 bits"
             ]

      assert configured(
               "var_global estop bool\nprogram m1 motor\nm1.run 2\nm1.sp 2147483648",
               motor
             ) == [
               "`m1.run` is a bool: only 0 or 1 fit, found `2`",
               "`m1.sp` is a dint: `2147483648` does not fit in 32 bits"
             ]

      assert configured(
               "var_global estop bool\nvar_global n dint\nvar_global b bool\nprogram m1 motor\n" <>
                 "m1.run n\nm1.sp b",
               motor
             ) == [
               "`m1.run` is a bool, but `n` is a dint (line 2)",
               "`m1.sp` is a dint, but `b` is a bool (line 3)"
             ]

      assert configured("var_global estop dint\nprogram m1 motor\nm1.run 0\nm1.sp 0", motor) == [
               "`motor` declares `var_external estop bool` on its line 4, but `estop` is a dint " <>
                 "(line 1)"
             ]

      assert configured(
               "var_global estop bool\nvar_global n dint\ntask trip single n priority 1\n" <>
                 "program m1 motor with trip\nm1.run 0\nm1.sp 0",
               motor
             ) == ["the single of `trip`, `n`, is a dint (line 2): a single is a bool global"]

      assert Enum.map(
               [%Global{name: "a", type: :bool}, %Global{name: "a", type: :dint}],
               &Configuration.initial/1
             ) == [0, 0]
    end

    # No text declares a connected var_input that holds an instance, but a program edited
    # by hand may: its type is named with the table's article, `an rto`, never by hand.
    test "a connected member a hand-edited program makes an instance is named with its article",
         %{motor: motor} do
      motor = %{motor | tags: Map.update!(motor.tags, "run", &%{&1 | type: Logex.FbType.rto()})}

      configuration = %Configuration{
        name: "plant",
        programs: %{"motor" => motor},
        globals: [%Global{name: "estop", type: :bool}, %Global{name: "g", type: :bool}],
        instances: [%Instance{name: "m1", type: "motor"}],
        connections: [
          %Configuration.Connection{instance: "m1", member: "run", to: "g"},
          %Configuration.Connection{instance: "m1", member: "sp", to: 0}
        ]
      }

      assert Enum.map(Configuration.check(configuration), & &1.message) == [
               "`m1.run` is an rto, but `g` is a bool"
             ]
    end

    test "a configuration's type words, its did-you-mean, its printing and the host's type", %{
      motor: motor
    } do
      assert configured("var_global estop boo\nvar_global t ton\n", motor) == [
               "unknown type `boo`: a global is a `bool` or a `dint` — did you mean `bool`?",
               "`t` cannot be a `ton`: a global is a `bool` or a `dint`, and a ton is declared " <>
                 "inside a program, as in `var t ton`",
               "this configuration declares no `program`: it would run nothing"
             ]

      assert Text.print([%Global{name: "e", type: :bool}, %Global{name: "n", type: :dint}]) ==
               "var_global e bool\nvar_global n dint\n"

      assert raised(fn -> Text.entries!([%Global{name: "e", type: :int}]) end) ==
               "not an entry a configuration file can say: a global's type is :bool or :dint, " <>
                 "got: %Logex.Configuration.Global{name: \"e\", type: :int, initial: nil, at: nil, " <>
                 "line: nil}"

      assert raised(fn ->
               Configuration.new!(
                 name: "plant",
                 programs: [motor],
                 globals: [%Global{name: "estop", type: :int}],
                 instances: [%Instance{name: "m1", type: "motor"}]
               )
             end) =~ "global `estop` has type :int: a global is :bool or :dint\n"
    end

    test "an edit's type change and a path too deep, each type named with its article", %{
      motor: motor
    } do
      {:ok, was} = Logex.compile("var_input b bool\nvar q bool\nxic b ote q", name: "p")
      {:ok, now} = Logex.compile("var_input b dint\nvar q bool\nxic q ote q", name: "p")

      assert {:error, [%{message: message}]} =
               Logex.Edit.accept(was, now, Runtime.instance(was))

      assert message ==
               "`b` is a bool in the running program and a dint in the candidate: a tag's type " <>
                 "changes only with a restart"

      {:ok, before} =
        Configuration.compile(
          "plant",
          "var_global estop bool\nvar_global n dint\nprogram m1 motor\nm1.run 0\nm1.sp 0",
          %{"motor" => motor}
        )

      {:ok, after_edit} =
        Configuration.compile(
          "plant",
          "var_global estop bool\nvar_global n bool\nprogram m1 motor\nm1.run 0\nm1.sp 0",
          %{"motor" => motor}
        )

      runtime = Runtime.start(before)

      assert {:error, [%{message: message}]} = Configuration.Edit.accept(runtime, after_edit)

      assert message ==
               "`n` is a dint global in the running configuration and a bool in the candidate: " <>
                 "a global's type changes only with a restart"

      assert Runtime.get(runtime, "estop.x") ==
               {:error, "`estop.x` goes too deep: `estop` is a bool global, which has no members"}

      assert Runtime.get(runtime, "n.x") ==
               {:error, "`n.x` goes too deep: `n` is a dint global, which has no members"}

      assert Runtime.get(runtime, "m1.run.x") ==
               {:error, "`m1.run.x` goes too deep: `m1.run` is a bool, which has no members"}

      assert Runtime.get(runtime, "m1.sp.x") ==
               {:error, "`m1.sp.x` goes too deep: `m1.sp` is a dint, which has no members"}
    end
  end
end
