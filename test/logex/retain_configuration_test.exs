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

      # Each broken line that names a global still declares it, so nothing that names it is
      # reported again (decision 42), decision 294's rule in a configuration file.
      {:error, _diagnostics, entries} = read(source)

      assert for({:declared, line, %{kind: :global, name: name}} <- entries, do: {line, name}) ==
               [{2, "t1"}, {3, "t2"}, {4, "t3"}, {5, "t4"}, {6, "t5"}, {7, "t6"}, {11, "t8"}]

      program =
        "var_global retain retain total_boxes dint\nprogram t1 tally\nt1.eye total_boxes\n"

      assert messages(compiled(program)) == [
               "1:19 `retain` is given twice: a global takes `retain` once, as in " <>
                 "`var_global retain total_boxes dint 0`"
             ]
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

    test "an edit that only adds `retain` to a global changes no value and reports nothing " <>
           "until M6-7, and the next warm restart follows the configuration running " <>
           "(provisional)" do
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
      {_edit, runtime, tested} = Logex.Configuration.Edit.test(edit, runtime)
      refute inspect(accepted) =~ "retain"
      refute inspect(tested) =~ "retain"
      assert Runtime.get!(runtime, "total_boxes") == 2
      assert Runtime.restart(runtime, :warm) |> Runtime.get!("total_boxes") == 2
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

    # Provisional, M6-3's review, question 7: the record says nothing of a retained global a
    # task's single reads. A trigger's last sample is 0 after any restart/2 (M2-6), so a
    # kept 1 is read as a trigger already 1 in the first cycle, decision 51's rule for an
    # input point, and the event task runs then, with no rising edge.
    test "a retained global that is a task's single, kept at 1, runs its event task in the " <>
           "first cycle after a warm restart, as a trigger already 1 does; cold it is put " <>
           "back and nothing runs (provisional)" do
      {:ok, arming} =
        Logex.compile("var_input eye bool\nvar_external arm bool\nxic eye otl arm",
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
      var_global retain arm bool
      program a1 arming with fast
        a1.eye eye_1
      program c1 counting with ev
      """

      assert {:ok, config} =
               Configuration.compile("plant", source, %{
                 "arming" => arming,
                 "counting" => counting
               })

      runtime = cycled(Runtime.start(config), [0, 1, 0, 0])
      assert Runtime.get!(runtime, "arm") == 1
      assert Runtime.get!(runtime, "c1.hits") == 1

      # The trigger held high runs nothing more before the restart.
      {runtime, _outputs, events} = Runtime.cycle(runtime, 10, %{"eye_1" => 0})
      refute Enum.any?(events, &match?({:ran, "ev", _, _}, &1))

      warm = Runtime.restart(runtime, :warm)
      assert Runtime.get!(warm, "arm") == 1
      assert Runtime.get!(warm, "c1.hits") == 0
      {warm, _outputs, events} = Runtime.cycle(warm, 10, %{"eye_1" => 0})
      assert Enum.any?(events, &match?({:ran, "ev", "c1", _}, &1))
      assert Runtime.get!(warm, "c1.hits") == 1

      cold = Runtime.restart(runtime, :cold)
      assert Runtime.get!(cold, "arm") == 0
      {cold, _outputs, events} = Runtime.cycle(cold, 10, %{"eye_1" => 0})
      refute Enum.any?(events, &match?({:ran, "ev", _, _}, &1))
      assert Runtime.get!(cold, "c1.hits") == 0
    end

    # Provisional, M6-3's review, question 8: the record says nothing of a retained global a
    # connection drives. The connection copies its var_output out at every scan, so one the
    # program does not retain, back at its initial value after the restart, writes over
    # the kept value in its instance's first run; one it retains keeps it.
    test "a retained global a connection drives keeps its value warm until the driving " <>
           "instance's first run, which writes its var_output over it where that is not " <>
           "retained, and keeps it where it is (provisional)" do
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
      assert config.warnings == []
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
  end

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
