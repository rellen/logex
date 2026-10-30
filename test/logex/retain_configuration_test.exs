defmodule Logex.RetainConfigurationTest do
  @moduledoc """
  M6-3 (`PLAN.md`, Milestone 6; `docs/organisation.md` §4.13, decisions 267, 268, 271,
  272 and 298): retained globals in a configuration. `var_global retain total_boxes dint
  0` and `var_global non_retain count dint` from a configuration file's text and from
  Elixir, every refusal of the reader at its column, a located global's `retain` refused,
  the warning where a retained var_output drives an output point, both words reserved in a
  configuration file, the exact round trip, and `Logex.Runtime.restart/2` `:warm` keeping
  a retained global, which a var_external of it reads, and `:cold` putting it back.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.{Connection, Global, Instance, Text}

  # A counter that adds each box to a total it keeps in a global it shares through a
  # var_external, and lights a lamp it may retain.
  @tally """
  var_input eye bool
  var_external total_boxes dint
  var_output retain lamp bool
  var_output count dint
  var retain boxes ctu
  var e bool

  xic eye ctu boxes 1000
  xic eye ons e add total_boxes 1 total_boxes
  move boxes.cv count
  xic eye otl lamp
  """

  @plain """
  var_input eye bool
  var_output lamp bool
  xic eye ote lamp
  """

  @motor """
  var_input start bool
  var_input stop bool
  var_output run bool
  var_output sp dint
  var t ton
  var c ctu
  var e bool
  ( xic start | xic run ) xio stop ote run
  xic run ton t 100
  xic run ctu c 10
  xic start ons e move 1200 sp
  """

  defp programs do
    {:ok, tally} = Logex.compile(@tally, name: "tally")
    {:ok, plain} = Logex.compile(@plain, name: "plain")
    %{"tally" => tally, "plain" => plain}
  end

  defp compiled(source), do: Configuration.compile("plant", source, programs())

  defp messages({:error, diagnostics}),
    do: Enum.map(diagnostics, &"#{&1.line}:#{&1.column} #{&1.message}")

  defp messages({:ok, config}), do: {:ok, Enum.map(config.warnings, &"#{&1.line} #{&1.message}")}

  defp read(source), do: Text.read(source)

  defp read_messages({:error, diagnostics, _entries}),
    do: Enum.map(diagnostics, &"#{&1.line}:#{&1.column} #{&1.message}")

  @plant """
  var_global eye_1 bool at panel.i.0
  var_global retain total_boxes dint 0
  var_global non_retain shown dint
  var_global lamp_q bool at panel.q.0
  program t1 tally
    t1.eye eye_1
    t1.lamp lamp_q
    t1.count shown
  """

  describe "M6-3: the line" do
    test "`var_global retain` and `var_global non_retain` read into the global's retain, in " <>
           "any case, and print back exactly" do
      assert {:ok, config} = compiled(@plant)

      assert Enum.map(config.globals, &{&1.name, &1.retain}) == [
               {"eye_1", nil},
               {"total_boxes", :retain},
               {"shown", :non_retain},
               {"lamp_q", nil}
             ]

      assert compiled(Text.print(config)) == {:ok, config}

      assert Text.print(config) =~
               "var_global retain total_boxes dint 0\nvar_global non_retain shown dint\n"

      for word <- ["RETAIN", "Retain", "rEtAiN"] do
        assert {:ok, [%Global{name: "g", retain: :retain}]} =
                 read("var_global #{word} g dint")
      end

      assert {:ok, [%Global{name: "g", retain: :non_retain, type: {:array, :int, [3]}}]} =
               read("var_global NON_RETAIN g int[3] 1 2 3")

      assert {:ok, [%Global{retain: nil}]} = read("var_global g dint 5")
    end

    test "from Elixir, a global's retain is the line's qualifier, printed as a line says it" do
      config =
        Configuration.new!(
          name: "plant",
          programs: Map.values(programs()),
          globals: [
            %Global{name: "eye_1", type: :bool, at: "panel.i.0"},
            %Global{name: "total_boxes", type: :dint, initial: 0, retain: :retain},
            %Global{name: "shown", type: :dint, retain: :non_retain},
            %Global{name: "lamp_q", type: :bool, at: "panel.q.0"}
          ],
          instances: [%Instance{name: "t1", type: "tally"}],
          connections: [
            %Connection{instance: "t1", member: "eye", to: "eye_1"},
            %Connection{instance: "t1", member: "lamp", to: "lamp_q"},
            %Connection{instance: "t1", member: "count", to: "shown"}
          ]
        )

      assert Text.print(config) ==
               "var_global eye_1 bool at panel.i.0\nvar_global retain total_boxes dint 0\n" <>
                 "var_global non_retain shown dint\nvar_global lamp_q bool at panel.q.0\n" <>
                 "program t1 tally\nt1.eye eye_1\nt1.lamp lamp_q\nt1.count shown\n"
    end

    # Decision 304 (the maintainer, 2026-10-29): a global from Elixir takes its qualifier as
    # Logex.Tag.new!/5 takes it, the line's own word as an option, with the same refusals.
    test "Global.new!/3 takes the qualifier as a keyword option, as Logex.Tag.new!/5 does " <>
           "(decision 304)" do
      assert Global.new!("total_boxes", :dint, initial: 0, retain: true) ==
               %Global{name: "total_boxes", type: :dint, initial: 0, retain: :retain}

      assert Global.new!("shown", :dint, non_retain: true) ==
               %Global{name: "shown", type: :dint, retain: :non_retain}

      assert Global.new!("eye_1", :bool, at: "panel.i.0", retain: false, non_retain: false) ==
               %Global{name: "eye_1", type: :bool, at: "panel.i.0"}

      assert Global.new!("g", :dint) == %Global{name: "g", type: :dint}

      assert Global.new!("arr", {:array, :int, [3]}, initial: [1, 2, 3], retain: true) ==
               %Global{
                 name: "arr",
                 type: {:array, :int, [3]},
                 initial: [1, 2, 3],
                 retain: :retain
               }

      # The plant of the first test, built from Elixir through it, prints as its text.
      config =
        Configuration.new!(
          name: "plant",
          programs: [programs()["tally"]],
          globals: [
            Global.new!("eye_1", :bool, at: "panel.i.0"),
            Global.new!("total_boxes", :dint, initial: 0, retain: true),
            Global.new!("shown", :dint, non_retain: true),
            Global.new!("lamp_q", :bool, at: "panel.q.0")
          ],
          instances: [%Instance{name: "t1", type: "tally"}],
          connections: [
            %Connection{instance: "t1", member: "eye", to: "eye_1"},
            %Connection{instance: "t1", member: "lamp", to: "lamp_q"},
            %Connection{instance: "t1", member: "count", to: "shown"}
          ]
        )

      assert {:ok, read} = compiled(Text.print(config))

      assert Enum.map(read.globals, &{&1.name, &1.retain}) ==
               Enum.map(config.globals, &{&1.name, &1.retain})

      for {options, message} <- [
            {:retain,
             "the options of `g` are a keyword list of `initial:`, `at:`, `retain: true` or " <>
               "`non_retain: true`, found :retain"},
            {[:retain],
             "the options of `g` are a keyword list of `initial:`, `at:`, `retain: true` or " <>
               "`non_retain: true`, found [:retain]"},
            {[qualifier: :retain],
             "unknown option :qualifier for `g`: Logex.Configuration.Global.new!/3 takes " <>
               "`initial:`, `at:`, `retain:` and `non_retain:`"},
            {[retain: 1], "`retain:` for `g` takes true or false, found 1"},
            {[non_retain: :yes], "`non_retain:` for `g` takes true or false, found :yes"},
            {[retain: true, retain: true], "`retain:` is given twice for `g`"},
            {[initial: 1, initial: 2], "`initial:` is given twice for `g`"},
            {[retain: true, non_retain: true],
             "`g` takes `retain: true` or `non_retain: true`, not both, as a `var_global` line " <>
               "takes `retain` or `non_retain`, not both"},
            {[retain: true, non_retain: true, line: 3],
             "unknown option :line for `g`: Logex.Configuration.Global.new!/3 takes " <>
               "`initial:`, `at:`, `retain:` and `non_retain:`\n" <>
               "`g` takes `retain: true` or `non_retain: true`, not both, as a `var_global` line " <>
               "takes `retain` or `non_retain`, not both"}
          ] do
        assert_raise ArgumentError, message, fn -> Global.new!("g", :dint, options) end
      end

      # A name that is no string is labelled as given.
      assert_raise ArgumentError, "`retain:` for :g takes true or false, found nil", fn ->
        Global.new!(:g, :dint, retain: nil)
      end

      # What the global says is check/1's, as for a struct built by hand.
      assert_raise ArgumentError, ~r/`retain` is a keyword and cannot name a global/, fn ->
        Configuration.new!(
          name: "plant",
          programs: [programs()["plain"]],
          globals: [Global.new!("retain", :bool), Global.new!("e", :bool)],
          instances: [%Instance{name: "p", type: "plain"}],
          connections: [%Connection{instance: "p", member: "eye", to: "e"}]
        )
      end
    end

    test "a global's retain no line can say is the host's mistake, a pinned line" do
      config =
        Configuration.new!(
          name: "plant",
          programs: [programs()["plain"]],
          globals: [%Global{name: "e", type: :bool, at: "panel.i.0"}],
          instances: [%Instance{name: "p", type: "plain"}],
          connections: [%Connection{instance: "p", member: "eye", to: "e"}]
        )

      for junk <- [true, "retain", :persistent] do
        bad = %{
          config
          | globals: [%Global{name: "e", type: :bool, at: "panel.i.0", retain: junk}]
        }

        assert_raise ArgumentError,
                     "unknown qualifier #{inspect(junk)} on global `e`: logex has :retain and " <>
                       ":non_retain, or nil for none",
                     fn -> Configuration.check(bad) end

        assert_raise ArgumentError,
                     "not an entry a configuration file can say: a global's retain is " <>
                       ":retain, :non_retain or nil, got: " <>
                       inspect(%Global{name: "g", type: :bool, retain: junk}),
                     fn -> Text.print([%Global{name: "g", type: :bool, retain: junk}]) end
      end

      # A global named by a qualifier is no entry a line can say, as one named `at` is.
      assert_raise ArgumentError, ~r/a global's name is not .*`non_retain`.*`retain`/, fn ->
        Text.print([%Global{name: "Retain", type: :bool}])
      end
    end

    test "every refusal of the reader at its column, a broken line still naming its global" do
      source =
        Enum.join(
          [
            "var_global retain",
            "var_global retain non_retain t1 dint",
            "var_global retain retain t2 dint",
            "var_global t3 retain dint",
            "var_global t4 dint 5 retain",
            "var_global t5 bool at panel.q.0 retain",
            "var_global t6 int[2] 1 2 non_retain",
            "retain t7 dint",
            "var_global retain bool",
            "var_global non_retain",
            "var_global t8 bool non_retain at panel.q.1",
            "NON_RETAIN x"
          ],
          "\n"
        )

      assert read_messages(read(source)) == [
               "1:12 `var_global retain` needs a name and a type, as in `var_global retain " <>
                 "total_boxes dint 0`",
               "2:19 a global takes `retain` or `non_retain`, not both: found `retain` and " <>
                 "`non_retain`",
               "3:19 `retain` is given twice: a global takes `retain` once, as in " <>
                 "`var_global retain total_boxes dint 0`",
               "4:15 `retain` comes straight after `var_global`, as in `var_global retain t3 dint`",
               "5:22 `retain` comes straight after `var_global`, as in `var_global retain t4 dint`",
               "6:33 `retain` comes straight after `var_global`, as in `var_global retain t5 bool`",
               "7:26 `non_retain` comes straight after `var_global`, as in " <>
                 "`var_global non_retain t6 int[2]`",
               "8:1 a line cannot start with `retain`: it goes on a `var_global` line, straight " <>
                 "after `var_global`, as in `var_global retain total_boxes dint 0`",
               "9:19 `var_global` needs a name before `bool`, as in `var_global estop bool`",
               "10:12 `var_global non_retain` needs a name and a type, as in " <>
                 "`var_global non_retain total_boxes dint 0`",
               "11:20 `non_retain` comes straight after `var_global`, as in " <>
                 "`var_global non_retain t8 bool`",
               "12:1 a line cannot start with `NON_RETAIN`: it goes on a `var_global` line, " <>
                 "straight after `var_global`, as in `var_global retain total_boxes dint 0`"
             ]

      # Decision 301 (the maintainer, 2026-10-29), decision 294's rule in a configuration
      # file: each line refused for its qualifiers alone, given twice, both or out of their
      # place, is read on without them and declares its global with no qualifier, so its
      # uses are checked; no line here is refused for anything else but those that name
      # no global.
      {:error, _diagnostics, entries} = read(source)
      assert for({:declared, _, _} = placeholder <- entries, do: placeholder) == []

      assert entries == [
               %Global{name: "t1", type: :dint, line: 2},
               %Global{name: "t2", type: :dint, line: 3},
               %Global{name: "t3", type: :dint, line: 4},
               %Global{name: "t4", type: :dint, initial: 5, line: 5},
               %Global{name: "t5", type: :bool, at: "panel.q.0", line: 6},
               %Global{name: "t6", type: {:array, :int, [2]}, initial: [1, 2], line: 7},
               %Global{name: "t8", type: :bool, at: "panel.q.1", line: 11}
             ]

      # Its uses are checked, `t1.eye` a bool, which a dint does not connect to.
      for line <- [
            "var_global retain retain total_boxes dint",
            "var_global retain non_retain total_boxes dint",
            "var_global total_boxes retain dint",
            "var_global total_boxes dint 0 non_retain",
            "var_global total_boxes dint non_retain",
            # Since the review of M6-4: a qualifier where the initial value goes, or where
            # the location goes (below), read on past too.
            "var_global total_boxes dint retain 0",
            "var_global total_boxes dint RETAIN 0",
            "var_global total_boxes dint non_retain -7"
          ] do
        assert [_qualifier, "3: `t1.eye` is a bool, but `total_boxes` is a dint (line 1)"] =
                 messages(compiled("#{line}\nprogram t1 tally\nt1.eye total_boxes\n")),
               line
      end

      # The declaration itself is checked too, as the line without its qualifier is.
      assert messages(
               compiled("var_global retain non_retain t bool 7\nprogram p plain\np.eye t\n")
             ) ==
               [
                 "1:19 a global takes `retain` or `non_retain`, not both: found `retain` and " <>
                   "`non_retain`",
                 "1: `t` is a bool: its initial value must be 0 or 1, found `7`"
               ]

      # A line broken another way too only names its global (decision 42): its uses are
      # silent, as before.
      for line <- [
            "var_global total_boxes retain dint 5 6",
            "var_global total_boxes retain dint (",
            "var_global retain retain total_boxes dint 0 0",
            "var_global total_boxes dint non_retain at"
          ] do
        assert [_one] =
                 messages(compiled("#{line}\nprogram t1 tally\nt1.eye total_boxes\n")),
               line
      end

      assert {:error, [_], [{:declared, 1, %{kind: :global, name: "total_boxes"}}]} =
               read("var_global total_boxes retain dint (")

      # Since the review of M6-4, an array's initial list read on past a qualifier before
      # it or among it, and a location past one where the location goes, each told where
      # the qualifier goes, the global declared as the line without it is.
      for {line, column, global} <- [
            {"var_global x int[2] retain 1 2", 21,
             %Global{name: "x", type: {:array, :int, [2]}, initial: [1, 2], line: 1}},
            {"var_global x int[2] 1 non_retain 2", 23,
             %Global{name: "x", type: {:array, :int, [2]}, initial: [1, 2], line: 1}},
            {"var_global x int[2] 1 2 retain", 25,
             %Global{name: "x", type: {:array, :int, [2]}, initial: [1, 2], line: 1}},
            {"var_global x dint retain 5", 19,
             %Global{name: "x", type: :dint, initial: 5, line: 1}},
            {"var_global x bool at retain panel.i.0", 22,
             %Global{name: "x", type: :bool, at: "panel.i.0", line: 1}}
          ] do
        assert {:error, [%Logex.Diagnostic{column: ^column, message: message}], [^global]} =
                 read(line),
               line

        assert message =~ "comes straight after `var_global`", line
      end

      # One the line ends on is read as the location, as before, so that a global printed
      # with any location reads back to it, which check/1 judges.
      assert read("var_global x bool at retain") ==
               {:ok, [%Global{name: "x", type: :bool, at: "retain", line: 1}]}
    end
  end

  describe "M6-3: decision 298, both words reserved in a configuration file" do
    test "a global, an instance, a task, a program type or a device named `retain` or " <>
           "`non_retain`, in any case, is refused with the word named" do
      source = """
      var_global eye_1 bool at Retain.i.0
      var_global q bool at non_retain.q.0
      task non_retain interval 10 priority 1
      task RETAIN interval 20 priority 2
      program Non_Retain plain
      program p2 retain
      program p3 plain
      p3.eye retain
      p3.lamp q
      """

      assert messages(compiled(source)) == [
               "1: `Retain` is a keyword and cannot name a device",
               "2: `non_retain` is a keyword and cannot name a device",
               "3: `non_retain` is a keyword and cannot name a task",
               "4: `RETAIN` is a keyword and cannot name a task",
               "5: `Non_Retain` is a keyword and cannot name an instance",
               "6: `retain` is a keyword and cannot name a program type",
               "8: no global `retain`: `retain` is a keyword of a configuration file, and " <>
                 "nothing in one is named so"
             ]
    end

    # Decision 300 (the maintainer, 2026-10-29): every configuration keyword, not only the
    # two qualifiers, is refused as a device's name, in any case, at its global's line.
    test "a device named by any configuration keyword is refused (decision 300)" do
      words = Enum.sort(Text.keywords())
      assert "program" in words and "at" in words and "task" in words

      cased = for word <- words, spelled <- [word, String.upcase(word)], do: spelled

      source =
        cased
        |> Enum.with_index()
        |> Enum.map_join(fn {device, n} -> "var_global g#{n} bool at #{device}.i.0\n" end)

      assert messages(compiled(source <> "program p plain\np.eye g0\n")) ==
               for(
                 {device, n} <- Enum.with_index(cased),
                 do: "#{n + 1}: `#{device}` is a keyword and cannot name a device"
               )

      assert messages(compiled("var_global e bool at program.i.0\nprogram p plain\np.eye e\n")) ==
               ["1: `program` is a keyword and cannot name a device"]

      # A device whose name is no keyword, whatever its length, is a device as before.
      ok = """
      var_global e1 bool at tasks.i.0
      var_global e2 bool at at1.i.0
      var_global e3 bool at programs.i.0
      var_global l1 bool at panel.q.0
      program p plain
        p.eye e1
        p.lamp l1
      """

      assert {:ok, config} = compiled(ok)
      assert Enum.map(config.globals, & &1.at) == ~w(tasks.i.0 at1.i.0 programs.i.0 panel.q.0)

      # From Elixir too.
      assert_raise ArgumentError, ~r/`Task` is a keyword and cannot name a device/, fn ->
        Configuration.new!(
          name: "plant",
          programs: [programs()["plain"]],
          globals: [%Global{name: "e", type: :bool, at: "Task.i.0"}],
          instances: [%Instance{name: "p", type: "plain"}],
          connections: [%Connection{instance: "p", member: "eye", to: "e"}]
        )
      end
    end

    # Since the review of M6-4: a device's name is looked up among the keywords only where
    # its first two letters and its length are a keyword's, so `drive` costs what `xrive`
    # does, where its first letter and length, `dword`'s, had it lowercased and looked up,
    # some 17 reductions a located global; one of a keyword's shape, `dwive`, still pays it.
    test "a device's keyword check costs nothing where no keyword shares its first two " <>
           "letters and length (decision 300)" do
      check = fn device ->
        source =
          Enum.map_join(0..31, "", fn i ->
            "var_global e#{i} bool at #{device}.i.#{i}\n" <>
              "var_global l#{i} bool at #{device}.q.#{i}\n" <>
              "program p#{i} plain\n  p#{i}.eye e#{i}\n  p#{i}.lamp l#{i}\n"
          end)

        assert {:ok, config} = compiled(source)
        reductions(fn -> Configuration.check(config) end)
      end

      assert check.("drive") == check.("xrive")
      assert check.("dwive") >= check.("xrive") + 8 * 64
    end

    test "an element of either word, at a connection's far end or as a task's single, is " <>
           "told the word is a keyword, as the word alone is (M6-3's review)" do
      source = """
      var_global q bool
      task t single Non_Retain[1] priority 1
      program p3 plain with t
        p3.eye retain[0]
        p3.lamp q
      """

      assert messages(compiled(source)) == [
               "2: the single of `t`: no global `Non_Retain[1]`: `Non_Retain` is a keyword of " <>
                 "a configuration file, and nothing in one is named so",
               "4: no global `retain[0]`: `retain` is a keyword of a configuration file, and " <>
                 "nothing in one is named so"
             ]

      # Any other name in brackets is told as before.
      assert messages(compiled(String.replace(source, ["Non_Retain[1]", "retain[0]"], "qq[0]"))) ==
               [
                 "2: the single of `t`: no global `qq[0]`: a global is named here whole, never " <>
                   "by one of its elements",
                 "4: no global `qq[0]`: there is no global array `qq` — did you mean `q`?"
               ]
    end

    test "from Elixir too, a global named by one is refused" do
      for word <- ["retain", "NON_RETAIN"] do
        assert_raise ArgumentError, ~r/`#{word}` is a keyword and cannot name a global/, fn ->
          Configuration.new!(
            name: "plant",
            programs: [programs()["plain"]],
            globals: [%Global{name: word, type: :bool}, %Global{name: "e", type: :bool}],
            instances: [%Instance{name: "p", type: "plain"}],
            connections: [%Connection{instance: "p", member: "eye", to: "e"}]
          )
        end
      end
    end

    test "Text.keywords/0 holds both, and a `.ld` file reserves them as it did" do
      assert "retain" in Text.keywords() and "non_retain" in Text.keywords()

      assert {:error, [_ | _]} =
               Logex.compile("var retain bool\nxic retain ote retain", name: "p")
    end
  end

  describe "M6-3: decision 272, located globals and outputs" do
    test "a located global takes no `retain`, an input, an output and an array of them, from " <>
           "text and from Elixir; `non_retain` is taken (provisional)" do
      source = """
      var_global retain eye_1 bool at panel.i.0
      var_global retain lamp_q bool at panel.q.0
      var_global retain temps int[2] at card.i.0
      var_global non_retain lamps bool[2] at card.q.0
      var_global non_retain o2 bool at panel.q.1
      program p plain
      p.eye eye_1
      p.lamp o2
      """

      assert messages(compiled(source)) == [
               "1: `eye_1` is an input point, and a located global takes no `retain`: an input " <>
                 "point is read again at every start, and an output point starts at 0 until " <>
                 "logic writes it",
               "2: `lamp_q` is an output point, and a located global takes no `retain`: an " <>
                 "input point is read again at every start, and an output point starts at 0 " <>
                 "until logic writes it",
               "3: `temps` is an array of input points, `card.i.0` to `card.i.1`, and a " <>
                 "located global takes no `retain`: an input point is read again at every " <>
                 "start, and an output point starts at 0 until logic writes it"
             ]

      assert_raise ArgumentError, ~r/`k` is an output point, and a located global takes no/, fn ->
        Configuration.new!(
          name: "plant",
          programs: [programs()["plain"]],
          globals: [
            %Global{name: "e", type: :bool, at: "panel.i.0"},
            %Global{name: "k", type: :bool, at: "panel.q.0", retain: :retain}
          ],
          instances: [%Instance{name: "p", type: "plain"}],
          connections: [
            %Connection{instance: "p", member: "eye", to: "e"},
            %Connection{instance: "p", member: "lamp", to: "k"}
          ]
        )
      end
    end

    test "a retained var_output wired straight to an output point, or to an element of an " <>
           "array of them, is warned of; one to an unlocated global, or not retained, is not" do
      {:ok, arrays} =
        Logex.compile(
          "var_input eye bool\nvar_output retain o bool[2]\nvar_output p bool[2]\n" <>
            "xic eye ote o[0]\nxic eye ote p[0]",
          name: "arrays"
        )

      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain total_boxes dint 0
      var_global lamp_q bool at panel.q.0
      var_global shown dint
      var_global l bool[2] at card.q.0
      var_global l2 bool[2] at card.q.4
      var_global l3 bool[2] at card.q.8
      var_global q2 bool at panel.q.1
      program t1 tally
        t1.eye eye_1
        t1.lamp lamp_q
        t1.count shown
      program a1 arrays
        a1.eye eye_1
        a1.o l
        a1.o[1] l2[0]
        a1.p l3
      program p1 plain
        p1.eye eye_1
        p1.lamp q2
      var_global lamp_g bool
      program t2 keep
        t2.eye eye_1
        t2.lamp lamp_g
      """

      {:ok, keep} =
        Logex.compile("var_input eye bool\nvar_output retain lamp bool\nxic eye ote lamp",
          name: "keep"
        )

      given = programs() |> Map.put("arrays", arrays) |> Map.put("keep", keep)
      assert {:ok, config} = Configuration.compile("plant", source, given)

      assert Enum.sort(Enum.map(config.warnings, &{&1.line, &1.message})) ==
               [
                 {11,
                  "`t1.lamp` is retained and drives the output `lamp_q`: after a warm start it " <>
                    "is written in the first round"},
                 {15,
                  "`a1.o` is retained and drives the output `l`: after a warm start it is " <>
                    "written in the first round"},
                 {16,
                  "`a1.o[1]` is retained and drives the output `l2[0]`: after a warm start it " <>
                    "is written in the first round"},
                 {6,
                  "`l2` is an array of output points, `card.q.4` to `card.q.5`, but nothing " <>
                    "drives `l2[1]`: it stays at 0"}
               ]
               |> Enum.sort()

      retained = for w <- config.warnings, w.message =~ "is retained", do: {w.line, w.message}

      assert retained == [
               {11,
                "`t1.lamp` is retained and drives the output `lamp_q`: after a warm start it " <>
                  "is written in the first round"},
               {15,
                "`a1.o` is retained and drives the output `l`: after a warm start it is " <>
                  "written in the first round"},
               {16,
                "`a1.o[1]` is retained and drives the output `l2[0]`: after a warm start it " <>
                  "is written in the first round"}
             ]
    end
  end

  describe "M6-3: decision 272's warning looks at every program type" do
    test "the one program type that retains anything is seen whatever its name's place " <>
           "among the types given, first, last or between (M6-3's review)" do
      plain = programs()["plain"]

      {:ok, keep} =
        Logex.compile("var_input eye bool\nvar_output retain lamp bool\nxic eye ote lamp",
          name: "keep"
        )

      source = """
      var_global eye_1 bool at panel.i.0
      var_global lamp_q bool at panel.q.0
      var_global q2 bool at panel.q.1
      var_global q3 bool at panel.q.2
      program p1 PLAIN_A
        p1.eye eye_1
        p1.lamp q2
      program p2 PLAIN_Z
        p2.eye eye_1
        p2.lamp q3
      program k1 KEEP
        k1.eye eye_1
        k1.lamp lamp_q
      """

      for {a, k, z} <- [
            {"b_plain", "a_keep", "c_plain"},
            {"a_plain", "z_keep", "b_plain"},
            {"a_plain", "m_keep", "z_plain"}
          ] do
        text =
          String.replace(source, ["PLAIN_A", "PLAIN_Z", "KEEP"], fn
            "PLAIN_A" -> a
            "PLAIN_Z" -> z
            "KEEP" -> k
          end)

        given = %{a => %{plain | name: a}, z => %{plain | name: z}, k => %{keep | name: k}}
        assert {:ok, config} = Configuration.compile("plant", text, given)

        assert Enum.map(config.warnings, &{&1.line, &1.message}) == [
                 {13,
                  "`k1.lamp` is retained and drives the output `lamp_q`: after a warm start it " <>
                    "is written in the first round"}
               ],
               inspect({a, k, z})
      end
    end
  end

  describe "M6-3: restart/2 keeps a retained global warm" do
    defp cycled(runtime, eyes),
      do:
        Enum.reduce(eyes, runtime, fn eye, rt ->
          {rt, _outputs, _events} = Runtime.cycle(rt, 10, %{"eye_1" => eye})
          rt
        end)

    test "a warm restart keeps a retained global, which a var_external of it reads, and the " <>
           "program's retained counter; a cold one puts both back; a global with no `retain` " <>
           "or `non_retain` is put back either way" do
      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain total_boxes dint 0
      var_global non_retain shown dint 3
      var_global plain_total dint 7
      var_global lamp_q bool at panel.q.0
      program t1 tally
        t1.eye eye_1
        t1.lamp lamp_q
        t1.count shown
      program p1 plain
        p1.eye eye_1
        p1.lamp plain_q
      var_global plain_q bool
      """

      assert {:ok, config} = compiled(source)
      runtime = cycled(Runtime.start(config), [0, 1, 0, 1, 0, 1, 1, 0])

      assert Runtime.get!(runtime, "total_boxes") == 3
      assert Runtime.get!(runtime, "t1.total_boxes") == 3
      assert Runtime.get!(runtime, "t1.boxes.cv") == 3
      assert Runtime.get!(runtime, "shown") == 3

      runtime = Runtime.restart(runtime, :warm)
      assert Runtime.get!(runtime, "total_boxes") == 3
      assert Runtime.get!(runtime, "t1.total_boxes") == 3
      assert Runtime.get!(runtime, "t1.boxes.cv") == 3
      assert Runtime.get!(runtime, "t1.lamp") == 1
      assert Runtime.get!(runtime, "shown") == 3
      assert Runtime.get!(runtime, "plain_total") == 7
      assert Runtime.get!(runtime, "eye_1") == 0

      # The first scan counts no edge, the eye already high; then it counts on.
      runtime = cycled(runtime, [1, 0, 1])
      assert Runtime.get!(runtime, "total_boxes") == 4
      assert Runtime.get!(runtime, "t1.boxes.cv") == 4
      %Runtime{globals: globals} = runtime
      assert globals["shown"] == 4

      # The non_retain global is put back warm, as an unmarked one is.
      %Runtime{} = warm = Runtime.restart(runtime, :warm)
      assert Runtime.get!(warm, "shown") == 3

      cold = Runtime.restart(runtime, :cold)
      assert Runtime.get!(cold, "total_boxes") == 0
      assert Runtime.get!(cold, "t1.boxes.cv") == 0
      assert Runtime.get!(cold, "shown") == 3
      assert Runtime.get!(cold, "t1.lamp") == 0
    end

    test "a warm restart during a configuration edit keeps the running instances' retained " <>
           "values and drops those set aside (decision 65)" do
      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain total_boxes dint 0
      var_global shown dint
      var_global lamp_q bool at panel.q.0
      program t1 tally
        t1.eye eye_1
        t1.lamp lamp_q
        t1.count shown
      program t2 tally
        t2.eye eye_1
      """

      assert {:ok, config} = compiled(source)
      runtime = cycled(Runtime.start(config), [0, 1, 0, 1])
      assert Runtime.get!(runtime, "t2.boxes.cv") == 2
      assert Runtime.get!(runtime, "total_boxes") == 4

      # The candidate stops t2, which its switch sets aside.
      candidate_text = String.replace(source, "program t2 tally\n  t2.eye eye_1\n", "")
      assert {:ok, candidate} = compiled(candidate_text)
      {:ok, edit, _report} = Logex.Configuration.Edit.accept(runtime, candidate)
      {edit, runtime, _report} = Logex.Configuration.Edit.test(edit, runtime)
      runtime = cycled(runtime, [0, 1])
      assert Runtime.get!(runtime, "total_boxes") == 5

      runtime = Runtime.restart(runtime, :warm)
      assert Runtime.get!(runtime, "total_boxes") == 5
      assert Runtime.get!(runtime, "t1.boxes.cv") == 3
      %Runtime{aside: aside} = runtime
      assert aside == %{}

      # untest brings back t2 started again, its retained counter not kept from aside.
      {_edit, runtime, _report} = Logex.Configuration.Edit.untest(edit, runtime)
      assert Runtime.get!(runtime, "t2.boxes.cv") == 0
      assert Runtime.get!(runtime, "total_boxes") == 5
    end

    # Decision 302 (the maintainer, 2026-10-29): an edit that only changes a global's
    # qualifier reports it by the global's name with the value it holds and writes nothing,
    # decision 278's report for a global; the next warm restart follows the configuration
    # running.
    test "an edit adding `retain` reports `:retain_added`, writes nothing, and untest " <>
           "`:retain_removed` (decision 302)" do
      source = """
      var_global eye_1 bool at panel.i.0
      var_global total_boxes dint 0
      var_global shown dint
      var_global lamp_q bool at panel.q.0
      program t1 tally
        t1.eye eye_1
        t1.lamp lamp_q
        t1.count shown
      """

      assert {:ok, config} = compiled(source)
      runtime = cycled(Runtime.start(config), [0, 1, 0, 1])
      assert Runtime.restart(runtime, :warm) |> Runtime.get!("total_boxes") == 0

      candidate =
        String.replace(source, "var_global total_boxes", "var_global retain total_boxes")

      assert {:ok, candidate} = compiled(candidate)
      {:ok, edit, accepted} = Logex.Configuration.Edit.accept(runtime, candidate)
      assert accepted == [{:retain_added, "total_boxes", 2}]
      {edit, tested_rt, tested} = Logex.Configuration.Edit.test(edit, runtime)
      assert tested == [{:retain_added, "total_boxes", 2}]

      # Nothing written: every global and instance as the step found it.
      assert Runtime.get!(tested_rt, "total_boxes") == 2

      for path <- ~w(eye_1 shown lamp_q t1.boxes.cv t1.count t1.lamp) do
        assert Runtime.get!(tested_rt, path) == Runtime.get!(runtime, path), path
      end

      assert Runtime.restart(tested_rt, :warm) |> Runtime.get!("total_boxes") == 2

      # Untest runs the original again, which does not retain it.
      {_edit, untested_rt, untested} = Logex.Configuration.Edit.untest(edit, tested_rt)
      assert untested == [{:retain_removed, "total_boxes", 2}]
      assert Runtime.get!(untested_rt, "total_boxes") == 2
      assert Runtime.restart(untested_rt, :warm) |> Runtime.get!("total_boxes") == 0
    end

    test "an edit taking `retain` away reports `:retain_removed`, and none to `non_retain` " <>
           "nothing (decision 302)" do
      {:ok, setter} = Logex.compile(setter("arr", "r", "lr"), name: "setter")

      source = """
      var_global eye_1 bool at panel.i.0
      var_global QA arr int[3] 0 0 0
      var_global QR r real 1.0
      var_global QL lr lreal 2.0
      program s1 setter
        s1.eye eye_1
      """

      text = fn a, r, l ->
        String.replace(source, ["QA ", "QR ", "QL "], fn
          "QA " -> a
          "QR " -> r
          "QL " -> l
        end)
      end

      types = %{"setter" => setter}
      {:ok, config} = Configuration.compile("plant", text.("retain ", "", "non_retain "), types)
      runtime = cycled(Runtime.start(config), [0, 1, 0])
      {:ok, candidate} = Configuration.compile("plant", text.("", "non_retain ", ""), types)

      {:ok, edit, accepted} = Logex.Configuration.Edit.accept(runtime, candidate)
      assert accepted == [{:retain_removed, "arr", [0, 1, 0]}]
      {_edit, tested_rt, tested} = Logex.Configuration.Edit.test(edit, runtime)
      assert tested == accepted
      assert Runtime.restart(tested_rt, :warm) |> Runtime.get!("arr") == [0, 0, 0]

      # Every qualifier to every other: a report only where `retain` comes or goes.
      for from <- ["", "retain ", "non_retain "], to <- ["", "retain ", "non_retain "] do
        {:ok, running} = Configuration.compile("plant", text.(from, from, from), types)
        runtime = cycled(Runtime.start(running), [0, 1, 0])
        {:ok, candidate} = Configuration.compile("plant", text.(to, to, to), types)
        {:ok, _edit, report} = Logex.Configuration.Edit.accept(runtime, candidate)

        expected =
          case {from, to} do
            {"retain ", "retain "} -> []
            {"retain ", _} -> [:retain_removed]
            {_, "retain "} -> [:retain_added]
            _ -> []
          end

        assert Enum.uniq(for({kind, _, _} <- report, do: kind)) == expected,
               inspect({from, to})

        assert length(report) == 3 * length(expected)
      end
    end

    test "a retained array global and real and lreal globals are kept warm, each element " <>
           "and each value as the resource holds it, and put back cold; unretained twins are " <>
           "put back either way (M6-3's review)" do
      {:ok, setter} = Logex.compile(setter("arr", "r", "lr"), name: "setter")
      {:ok, twin} = Logex.compile(setter("arr2", "r2", "lr2"), name: "twin")

      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain arr int[3] 0 0 0
      var_global retain r real 1.0
      var_global retain lr lreal 2.0
      var_global arr2 int[3] 7 7 7
      var_global r2 real 1.0
      var_global lr2 lreal 2.0
      program s1 setter
        s1.eye eye_1
      program s2 twin
        s2.eye eye_1
      """

      assert {:ok, config} =
               Configuration.compile("plant", source, %{"setter" => setter, "twin" => twin})

      runtime = cycled(Runtime.start(config), [0, 1, 0, 1, 0])
      held = ~w(arr r lr arr2 r2 lr2)

      assert Enum.map(held, &Runtime.get!(runtime, &1)) ==
               [[0, 2, 0], 4.0, 2.5, [7, 9, 7], 4.0, 2.5]

      warm = Runtime.restart(runtime, :warm)

      assert Enum.map(held, &Runtime.get!(warm, &1)) ==
               [[0, 2, 0], 4.0, 2.5, [7, 7, 7], 1.0, 2.0]

      assert Runtime.get!(warm, "s1.arr[1]") == 2
      assert Runtime.get!(warm, "s1.lr") == 2.5

      # It counts on from the kept values, the first scan seeing no edge (decision 274).
      warm = cycled(warm, [0, 1])
      assert Enum.map(~w(arr r lr), &Runtime.get!(warm, &1)) == [[0, 3, 0], 5.5, 2.75]

      cold = Runtime.restart(runtime, :cold)

      assert Enum.map(held, &Runtime.get!(cold, &1)) ==
               [[0, 0, 0], 1.0, 2.0, [7, 7, 7], 1.0, 2.0]
    end

    # Decision 305 (the maintainer, 2026-10-29), decision 274's rule for a trigger: after a
    # warm restart a retained single's last sample is the value it kept, so a trigger kept
    # at 1 is no rising edge and its event task waits for a real one; cold, the global is
    # put back and its last sample is 0, as after every restart (M2-6). Until decision 305
    # the warm restart ran the event task in its first cycle (M6-3's review, provisional).
    test "a retained single kept at 1 runs its event task only on a real rising edge after " <>
           "a warm restart (decision 305)" do
      {:ok, arming} =
        Logex.compile(
          "var_input eye bool\nvar_input clear bool\nvar_external arm bool\n" <>
            "xic eye otl arm\nxic clear otu arm",
          name: "arming"
        )

      {:ok, counting} =
        Logex.compile(
          "var_external arm bool\nvar_output hits dint\nxic arm add hits 1 hits",
          name: "counting"
        )

      source = """
      task fast interval 10 priority 1
      task ev single arm priority 0
      var_global eye_1 bool at panel.i.0
      var_global clr bool at panel.i.1
      var_global retain arm bool
      program a1 arming with fast
        a1.eye eye_1
        a1.clear clr
      program c1 counting with ev
      """

      types = %{"arming" => arming, "counting" => counting}
      assert {:ok, config} = Configuration.compile("plant", source, types)

      step = fn rt, eye, clr ->
        {rt, _outputs, events} = Runtime.cycle(rt, 10, %{"eye_1" => eye, "clr" => clr})
        {rt, Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))}
      end

      runtime = cycled(Runtime.start(config), [0, 1, 0, 0])
      assert Runtime.get!(runtime, "arm") == 1
      assert Runtime.get!(runtime, "c1.hits") == 1

      # The trigger held high runs nothing more before the restart.
      {runtime, ran?} = step.(runtime, 0, 0)
      refute ran?

      warm = Runtime.restart(runtime, :warm)
      assert Runtime.get!(warm, "arm") == 1
      assert Runtime.get!(warm, "c1.hits") == 0

      # Held at 1 through the first cycles after it, it is no edge.
      {warm, ran1?} = step.(warm, 0, 0)
      {warm, ran2?} = step.(warm, 0, 0)
      refute ran1? or ran2?
      assert Runtime.get!(warm, "c1.hits") == 0

      # Cleared and set again, a real rising edge, it runs once.
      {warm, ran?} = step.(warm, 0, 1)
      refute ran?
      {warm, ran?} = step.(warm, 1, 0)
      refute ran?
      {warm, ran?} = step.(warm, 0, 0)
      assert ran?
      assert Runtime.get!(warm, "c1.hits") == 1

      cold = Runtime.restart(runtime, :cold)
      assert Runtime.get!(cold, "arm") == 0
      {cold, ran?} = step.(cold, 0, 0)
      refute ran?
      assert Runtime.get!(cold, "c1.hits") == 0
    end

    # Decision 313 (the maintainer, 2026-10-30), restating decision 305: the last sample a
    # warm restart keeps is the one the resource took, not the value kept. Logic latches
    # `arm` in the cycle after `ev` sampled it at 0, and the restart comes before the next
    # cycle: the first cycle after it samples 1 against that 0 and runs `ev` once, as the
    # next cycle would have with no restart. Under decision 305 alone it ran nothing.
    test "a rise logic wrote after the trigger's last sample runs its event task once after " <>
           "a warm restart (decision 313)" do
      {:ok, arming} =
        Logex.compile(
          "var_input eye bool\nvar_input clear bool\nvar_external arm bool\n" <>
            "xic eye otl arm\nxic clear otu arm",
          name: "arming"
        )

      {:ok, counting} =
        Logex.compile(
          "var_external arm bool\nvar_external hits dint\nxic arm add hits 1 hits",
          name: "counting"
        )

      source = """
      task fast interval 10 priority 1
      task ev single arm priority 0
      var_global eye_1 bool at panel.i.0
      var_global clr bool at panel.i.1
      var_global retain arm bool
      var_global retain hits dint
      program a1 arming with fast
        a1.eye eye_1
        a1.clear clr
      program c1 counting with ev
      """

      types = %{"arming" => arming, "counting" => counting}
      assert {:ok, config} = Configuration.compile("plant", source, types)

      ran = fn rt ->
        {rt, _outputs, events} = Runtime.cycle(rt, 10, %{"eye_1" => 0, "clr" => 0})
        {rt, Enum.count(events, &match?({:ran, "ev", "c1", _}, &1))}
      end

      # `ev` samples `arm` at 0 and then `a1` latches it, in the one cycle.
      runtime = cycled(Runtime.start(config), [0, 1])
      assert Runtime.get!(runtime, "arm") == 1
      assert Runtime.get!(runtime, "hits") == 0

      {_next, runs} = ran.(runtime)
      assert runs == 1

      warm = Runtime.restart(runtime, :warm)
      {warm, runs} = ran.(warm)
      assert runs == 1
      assert Runtime.get!(warm, "hits") == 1
      {warm, runs} = ran.(warm)
      assert runs == 0

      # Restarted warm again with `arm` sampled at 1 since, it is no edge.
      {_warm, runs} = ran.(Runtime.restart(warm, :warm))
      assert runs == 0

      # Cold, `arm` is put back at 0 with its sample: nothing.
      {_cold, runs} = ran.(Runtime.restart(runtime, :cold))
      assert runs == 0
    end

    test "an unretained single, or an input point, already 1 fires in the first cycle after " <>
           "any restart (decisions 51 and 305)" do
      {:ok, counting} =
        Logex.compile(
          "var_external arm bool\nvar_output hits dint\nxic arm add hits 1 hits",
          name: "counting"
        )

      {:ok, setting} =
        Logex.compile("var_input eye bool\nvar_external arm bool\nxic eye ote arm",
          name: "setting"
        )

      for {qualifier, expected} <- [{"retain ", false}, {"", true}, {"non_retain ", true}] do
        source = """
        task fast interval 10 priority 1
        task ev single arm priority 0
        var_global eye_1 bool at panel.i.0
        var_global #{qualifier}arm bool 1
        program s1 setting with fast
          s1.eye eye_1
        program c1 counting with ev
        """

        types = %{"counting" => counting, "setting" => setting}
        assert {:ok, config} = Configuration.compile("plant", source, types)
        # `arm` held at 1 by the eye.
        runtime = cycled(Runtime.start(config), [1, 1])

        for mode <- [:warm, :cold] do
          {_rt, _outputs, events} = Runtime.cycle(Runtime.restart(runtime, mode), 10, %{})
          ran? = Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))
          # Kept at 1 warm only where retained; every other restart puts it at its initial
          # 1 with a last sample of 0.
          assert ran? == (expected or mode == :cold), inspect({qualifier, mode})
        end
      end

      # A trigger on an input point already 1 still fires after a warm restart.
      source = """
      task ev single eye_1 priority 0
      var_global eye_1 bool at panel.i.0
      var_global retain arm bool
      program c1 counting with ev
      """

      assert {:ok, config} = Configuration.compile("plant", source, %{"counting" => counting})
      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(config), 0, %{"eye_1" => 1})
      {_rt, _outputs, events} = Runtime.cycle(Runtime.restart(runtime, :warm), 10, %{})
      assert Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))
    end

    # M6-3's review, question 8: the connection copies its var_output out at every scan, so
    # one the program does not retain, back at its initial value after the restart, writes
    # over the kept value in its instance's first run; one it retains keeps it. Since
    # decision 306 the first is warned of, at the connection's line.
    test "a retained global an unretained var_output drives keeps its value warm until the " <>
           "driver's first run writes over it, and is warned of (decision 306)" do
      counted =
        "var_input eye bool\nvar_output COUNT dint\nvar e bool\n" <>
          "xic eye ons e add count 1 count"

      {:ok, w} = Logex.compile(String.replace(counted, "COUNT", "count"), name: "w")
      {:ok, wk} = Logex.compile(String.replace(counted, "COUNT", "retain count"), name: "wk")

      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain total dint 0
      var_global retain kept dint 0
      program w1 w
        w1.eye eye_1
        w1.count total
      program w2 wk
        w2.eye eye_1
        w2.count kept
      """

      assert {:ok, config} = Configuration.compile("plant", source, %{"w" => w, "wk" => wk})

      assert Enum.map(config.warnings, &{&1.line, &1.message}) == [
               {6,
                "`total` is retained but driven by `w1.count`, which is not: the first round " <>
                  "writes over it"}
             ]

      runtime = cycled(Runtime.start(config), [0, 1, 0, 1, 0])
      assert {Runtime.get!(runtime, "total"), Runtime.get!(runtime, "kept")} == {2, 2}

      warm = Runtime.restart(runtime, :warm)
      assert {Runtime.get!(warm, "total"), Runtime.get!(warm, "kept")} == {2, 2}
      assert {Runtime.get!(warm, "w1.count"), Runtime.get!(warm, "w2.count")} == {0, 2}

      warm = cycled(warm, [0])
      assert {Runtime.get!(warm, "total"), Runtime.get!(warm, "kept")} == {0, 2}

      cold = Runtime.restart(runtime, :cold)
      assert {Runtime.get!(cold, "total"), Runtime.get!(cold, "kept")} == {0, 0}
    end

    # Decision 306 (the maintainer, 2026-10-29), at the connection's line, an element of a
    # global array or of a var_output array by its element, from text and from Elixir, a
    # var_output the program retains told nothing, and a global that is not retained, or a
    # var_input's connection, told nothing.
    test "decision 306's warning, element by element, from text and from Elixir, and none " <>
           "for a retained var_output or an unretained global" do
      outs =
        "var_input eye bool\nvar_output COUNT dint\nvar_output OS dint[2]\nvar e bool\n" <>
          "xic eye ons e add count 1 count\nmove count os[0]"

      {:ok, w} =
        Logex.compile(String.replace(outs, ["COUNT", "OS"], &String.downcase/1), name: "w")

      {:ok, wk} =
        Logex.compile(
          String.replace(outs, ["COUNT", "OS"], &("retain " <> String.downcase(&1))),
          name: "wk"
        )

      {:ok, reads} = Logex.compile("var_input n dint\nvar_output o dint\nmove n o", name: "reads")

      source = """
      var_global eye_1 bool at panel.i.0
      var_global retain total dint 0
      var_global retain totals dint[2]
      var_global retain pair dint[2]
      var_global retain kept dint 0
      var_global retain kepts dint[2]
      var_global retain kept1 dint
      var_global plain dint 0
      var_global plains dint[2]
      program w1 w
        w1.eye eye_1
        w1.count total
        w1.os[1] totals[0]
        w1.os pair
      program w2 wk
        w2.eye eye_1
        w2.count kept
        w2.os kepts
        w2.os[1] kept1
      program w3 w
        w3.eye eye_1
        w3.count plain
        w3.os plains
      program r1 reads
        r1.n total
      """

      types = %{"w" => w, "wk" => wk, "reads" => reads}
      assert {:ok, config} = Configuration.compile("plant", source, types)

      told = [
        {12,
         "`total` is retained but driven by `w1.count`, which is not: the first round writes " <>
           "over it"},
        {13,
         "`totals[0]` is retained but driven by `w1.os[1]`, which is not: the first round " <>
           "writes over it"},
        {14,
         "`pair` is retained but driven by `w1.os`, which is not: the first round writes " <>
           "over it"}
      ]

      assert Enum.map(config.warnings, &{&1.line, &1.message}) == told

      # From Elixir, the same warnings in the order of the connections, with no line.
      unlined = &Enum.map(Map.fetch!(config, &1), fn element -> %{element | line: nil} end)

      elixir =
        Configuration.new!(
          name: "plant",
          programs: Map.values(types),
          globals: unlined.(:globals),
          instances: unlined.(:instances),
          connections: unlined.(:connections)
        )

      assert Enum.map(elixir.warnings, & &1.message) == Enum.map(told, &elem(&1, 1))

      # The same plant with no global retained is told nothing.
      plain = String.replace(source, "var_global retain ", "var_global ")
      assert {:ok, %{warnings: []}} = Configuration.compile("plant", plain, types)
    end

    test "with nothing retained, a warm restart costs no more than a cold one, and a cycle " <>
           "what it costs with every unlocated global retained (M6-3's review)" do
      {:ok, motor} = Logex.compile(@motor, name: "motor")

      for n <- [1, 32] do
        plain = motors(n, "")
        kept = motors(n, "retain ")
        {:ok, plain} = Configuration.compile("plant", plain, %{"motor" => motor})
        {:ok, kept} = Configuration.compile("plant", kept, %{"motor" => motor})
        presses = Map.new(1..n, &{"pb#{&1}", 1})

        [rp, rk] =
          for config <- [plain, kept] do
            {rt, _, _} = Runtime.cycle(Runtime.start(config), 0, presses)
            {rt, _, _} = Runtime.cycle(rt, 10, %{})
            rt
          end

        assert Runtime.restart(rp, :warm) == Runtime.restart(rp, :cold)
        warm = reductions(fn -> Runtime.restart(rp, :warm) end)
        cold = reductions(fn -> Runtime.restart(rp, :cold) end)
        assert warm <= cold + 4, "n=#{n}: warm #{warm}, cold #{cold}"

        cycle = fn rt -> reductions(fn -> Runtime.cycle(rt, 10, %{"pb1" => 0}) end) end
        assert cycle.(rp) == cycle.(rk), "n=#{n}"
      end
    end

    test "a configuration with nothing retained restarts warm exactly as cold" do
      source = String.replace(@plant, ["retain ", "non_retain "], "")
      {:ok, tally} = Logex.compile(String.replace(@tally, "retain ", ""), name: "tally")
      assert {:ok, config} = Configuration.compile("plant", source, %{"tally" => tally})
      runtime = cycled(Runtime.start(config), [0, 1, 0, 1, 1])
      assert Runtime.restart(runtime, :warm) == Runtime.restart(runtime, :cold)
    end
  end

  describe "M6-3: the runner's warm restart keeps a retained global (M6-3's review)" do
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    # The runner trips on the panel's read and is restarted: warm, the retained global and
    # the program's retained counter are kept through Logex.Runner.restart/2, which reaches
    # Logex.Runtime.restart/2; cold, both are lost; an unretained global is put back either
    # way.
    test "Runner.restart/2 :warm keeps a retained global and :cold loses it" do
      source = """
      task fast interval 10 priority 1
      var_global eye_1 bool at panel.i.0
      var_global retain total_boxes dint 0
      var_global plain dint 7
      var_global shown dint
      program t1 tally with fast
        t1.eye eye_1
        t1.count shown
      """

      assert {:ok, config} = compiled(source)
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: config,
          io: %{"panel" => {Sim, sim: panel}},
          clock: {Manual, clock},
          poll: 10
        )

      for eye <- [1, 0, 1, 0, 1, 0] do
        Sim.set(panel, [0], eye)
        Manual.advance(clock, 10)
      end

      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      paths = ~w(total_boxes t1.total_boxes t1.boxes.cv plain)
      # The start's first round sees the eye low, so its three rises are counted.
      assert for(path <- paths, do: Runner.get!(runner, path)) == [3, 3, 3, 7]

      assert Runner.restart(runner, :warm) == :ok
      assert for(path <- paths, do: Runner.get!(runner, path)) == [3, 3, 3, 7]

      Sim.set(panel, [0], 1)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "total_boxes") == 4

      Sim.fail(panel, :read, {:error, :eio})
      Manual.advance(clock, 10)
      assert %{status: :tripped} = Runner.status(runner)
      assert Runner.restart(runner, :cold) == :ok
      assert for(path <- paths, do: Runner.get!(runner, path)) == [0, 0, 0, 7]

      Runner.stop(runner)
    end

    # Since the review of M6-4, decision 305 through the runner on the manual clock: a
    # retained single kept at 1 by a warm Logex.Runner.restart/2 fires nothing until it is
    # cleared and set again; a cold one puts it back at 0; an unretained single whose
    # initial value is 1 fires in the first round after a warm restart, as decision 51 has
    # every restart's first sample.
    test "Runner.restart/2 :warm keeps a retained single's last sample (decision 305)" do
      {:ok, arming} =
        Logex.compile(
          "var_input eye bool\nvar_input clear bool\nvar_external arm bool\n" <>
            "xic eye otl arm\nxic clear otu arm",
          name: "arming"
        )

      {:ok, counting} =
        Logex.compile("var_external hits dint\nadd hits 1 hits", name: "counting")

      for qualifier <- ["retain ", ""] do
        source = """
        task fast interval 10 priority 1
        task ev single arm priority 0
        var_global eye_1 bool at panel.i.0
        var_global clr bool at panel.i.1
        var_global #{qualifier}arm bool #{initial(qualifier)}
        var_global retain hits dint
        program a1 arming with fast
          a1.eye eye_1
          a1.clear clr
        program c1 counting with ev
        """

        types = %{"arming" => arming, "counting" => counting}
        assert {:ok, config} = Configuration.compile("plant", source, types)
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: config,
            io: %{"panel" => {Sim, sim: panel}},
            clock: {Manual, clock},
            poll: 10
          )

        state = fn -> {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} end

        press = fn point ->
          Sim.set(panel, [point], 1)
          Manual.advance(clock, 10)
          Sim.set(panel, [point], 0)
          Manual.advance(clock, 30)
        end

        trip_and = fn mode ->
          Sim.fail(panel, :read, {:error, :eio})
          Manual.advance(clock, 10)
          assert %{status: :tripped} = Runner.status(runner)
          assert Runner.restart(runner, mode) == :ok
          Manual.advance(clock, 50)
          state.()
        end

        # Clear, then arm: one run of `ev` on the eye's rising edge, and, unretained, one
        # more at the start, where `arm` starts at 1.
        press.(1)
        press.(0)
        warm = trip_and.(:warm)
        # Cleared and set again after the warm restart: a real rising edge, one run more.
        press.(1)
        press.(0)
        rearmed = state.()
        cold = trip_and.(:cold)
        # Pressed again with `arm` where the cold restart put it.
        press.(0)
        assert [warm, rearmed, cold, state.()] == seen(qualifier), qualifier

        Runner.stop(runner)
      end
    end
  end

  # Decision 313 through the runner on the manual clock (the maintainer, 2026-10-30): the
  # round that latches `arm` after `ev` sampled it at 0 trips on `f1`'s index fault, before
  # any round samples it again. The warm restart keeps the sample, 0, so its first round
  # runs `ev` once, the rise logic made before the trip; decision 305 alone took the kept 1
  # for the sample, and `ev` never ran for it.
  describe "decision 313 through the runner" do
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    test "a rise logic wrote just before a trip runs its event task once after a warm " <>
           "Runner.restart/2, and a cold one runs nothing" do
      {:ok, arming} =
        Logex.compile(
          "var_input eye bool\nvar_input clear bool\nvar_external arm bool\n" <>
            "xic eye otl arm\nxic clear otu arm",
          name: "arming"
        )

      {:ok, counting} = Logex.compile("var_external hits dint\nadd hits 1 hits", name: "counting")

      {:ok, faulting} =
        Logex.compile(
          "var_input eye bool\nvar w int[2]\nvar i dint\nxic eye move 5 i\nxic eye move 1 w[i]",
          name: "faulting"
        )

      source = """
      task fast interval 10 priority 1
      task ev single arm priority 0
      var_global eye_1 bool at panel.i.0
      var_global clr bool at panel.i.1
      var_global retain arm bool
      var_global retain hits dint
      program a1 arming with fast
        a1.eye eye_1
        a1.clear clr
      program f1 faulting with fast
        f1.eye eye_1
      program c1 counting with ev
      """

      types = %{"arming" => arming, "counting" => counting, "faulting" => faulting}
      assert {:ok, config} = Configuration.compile("plant", source, types)

      for {mode, seen} <- [warm: {1, 1}, cold: {0, 0}] do
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: config,
            io: %{"panel" => {Sim, sim: panel}},
            clock: {Manual, clock},
            poll: 10
          )

        state = fn -> {Runner.get!(runner, "arm"), Runner.get!(runner, "hits")} end
        Manual.advance(clock, 30)
        assert state.() == {0, 0}
        Sim.set(panel, [0], 1)
        Manual.advance(clock, 10)
        assert %{status: :tripped} = Runner.status(runner)
        assert state.() == {1, 0}
        Sim.set(panel, [0], 0)
        Manual.advance(clock, 10)
        assert Runner.restart(runner, mode) == :ok
        Manual.advance(clock, 50)
        assert state.() == seen, inspect(mode)
        Runner.stop(runner)
      end
    end
  end

  defp initial("retain "), do: 0
  defp initial(""), do: 1

  # Retained: `arm` kept at 1 by the warm restart with its last sample, so nothing fires
  # (hits stays 1, retained); cold, both at 0 and nothing fires until the eye sets `arm`.
  defp seen("retain "), do: [{1, 1}, {1, 2}, {0, 0}, {1, 1}]

  # Unretained, its initial value 1: each restart puts it back at 1 and its first sample
  # of 1 runs `ev` in the first round (decision 51), warm (hits 2 to 3, retained) and
  # cold (0 to 1); the eye's press then sets nothing new, so no edge.
  defp seen(""), do: [{1, 3}, {1, 4}, {1, 1}, {1, 1}]

  # A setter that adds to an int array's element, a real and an lreal on each press, each
  # a global it reads through a var_external.
  defp setter(arr, r, lr),
    do: """
    var_input eye bool
    var_external #{arr} int[3]
    var_external #{r} real
    var_external #{lr} lreal
    var e1 bool
    var e2 bool
    var e3 bool
    xic eye ons e1 add #{arr}[1] 1 #{arr}[1]
    xic eye ons e2 add #{r} 1.5 #{r}
    xic eye ons e3 add #{lr} 0.25 #{lr}
    """

  # cost63.exs's plant: n motors, each with its button, lamp, setpoint and stop, the last
  # two unlocated globals, `qualifier` on each of them.
  defp motors(n, qualifier),
    do:
      "task fast interval 10 priority 1\ntask slow interval 50 priority 2\n" <>
        Enum.map_join(1..n, "", fn i ->
          "var_global pb#{i} bool at panel.i.#{i}\nvar_global k#{i} bool at panel.q.#{i}\n" <>
            "var_global #{qualifier}sp#{i} dint\nvar_global #{qualifier}st#{i} bool 1\n" <>
            "program m#{i} motor with #{Enum.at(["slow", "fast"], rem(i, 2))}\n" <>
            "m#{i}.start pb#{i}\nm#{i}.stop st#{i}\nm#{i}.run k#{i}\nm#{i}.sp sp#{i}\n"
        end)

  defp reductions(fun) do
    parent = self()

    {_pid, ref} =
      :erlang.spawn_opt(
        fn ->
          {:reductions, before} = Process.info(self(), :reductions)
          fun.()
          {:reductions, later} = Process.info(self(), :reductions)
          send(parent, {:reductions, later - before})
        end,
        [:monitor, min_heap_size: 8_000_000]
      )

    assert_receive {:reductions, r}, 10_000
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 10_000
    r
  end
end
