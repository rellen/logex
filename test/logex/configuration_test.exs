defmodule Logex.ConfigurationTest do
  @moduledoc """
  `Logex.Configuration` (M2-1): the one validator, `check/1`, and the constructor from
  Elixir, `new!/1`. Every problem is pinned as a whole list, in its order: `new!/1` raises
  one `ArgumentError` whose message is every problem, a line each; `check/1` gives a
  mistake a configuration's text could also make as a diagnostic, at its element's line in
  the configuration's file, which is how a reader of the text will cite it, and raises a
  mistake no text can make, the host's, as one `ArgumentError` (decision 36).
  """
  use ExUnit.Case, async: true

  doctest Logex.Configuration

  alias Logex.{Configuration, Diagnostic}
  alias Logex.Configuration.{Connection, Global, Instance}

  # A seal-in with a dint output, an internal var and a timer: every kind of member a
  # connection may name, and two it may not.
  @seal """
  var_input start bool
  var_input stop bool
  var_output motor bool
  var_output sp dint
  var fault bool
  var t1 ton
  ( xic start | xic motor ) xio stop ote motor
  xic motor ton t1 100
  xic fault move 5 sp
  """

  setup_all do
    {:ok, seal} = Logex.compile(@seal, name: "seal")
    %{seal: seal}
  end

  # A configuration that runs: two input points, an output point, an unlocated dint, and
  # one task-less instance with every var_input connected.
  defp base(seal),
    do: [
      name: "plant",
      programs: [seal],
      globals: [
        %Global{name: "pb", type: :bool, at: "panel.i.0"},
        %Global{name: "pb2", type: :bool, at: "panel.i.1"},
        %Global{name: "k", type: :bool, at: "panel.q.0"},
        %Global{name: "sp", type: :dint}
      ],
      instances: [%Instance{name: "m", type: "seal"}],
      connections: [
        %Connection{instance: "m", member: "start", to: "pb"},
        %Connection{instance: "m", member: "stop", to: 0},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]
    ]

  defp task(name, interval, priority),
    do: %Configuration.Task{name: name, interval: interval, priority: priority}

  # Every problem new!/1 raises, a line each.
  defp refused(fields) do
    error = assert_raise ArgumentError, fn -> Configuration.new!(fields) end
    String.split(error.message, "\n")
  end

  # Every host's mistake check/1 raises, a line each.
  defp mistakes(config) do
    error = assert_raise ArgumentError, fn -> Configuration.check(config) end
    String.split(error.message, "\n")
  end

  defp formatted(config), do: Enum.map(Configuration.check(config), &Diagnostic.format/1)

  defp opaque(value), do: Process.get(:__opaque_to_the_type_checker__, value)

  describe "a configuration that runs" do
    test "is built, and check/1 finds nothing in it", %{seal: seal} do
      config = Configuration.new!(base(seal))
      assert %Configuration{name: "plant", file: nil, warnings: []} = config
      assert config.programs == %{"seal" => seal}
      assert Configuration.check(config) == []
    end

    test "an instance may share its program's name: types are named apart", %{seal: seal} do
      fields = Keyword.put(base(seal), :instances, [%Instance{name: "seal", type: "seal"}])

      fields =
        Keyword.put(
          fields,
          :connections,
          Enum.map(fields[:connections], &%{&1 | instance: "seal"})
        )

      assert %Configuration{} = Configuration.new!(fields)
    end

    test "the bounds of an interval and a priority are in", %{seal: seal} do
      tasks = [task("a", 1, 0), task("b", 2_147_483_647, 65_535)]
      assert %Configuration{} = Configuration.new!(Keyword.put(base(seal), :tasks, tasks))
    end

    test "a var_output may drive several globals, and an output point may be read back",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          globals: base(seal)[:globals] ++ [%Global{name: "k2", type: :bool, at: "panel.q.1"}],
          instances: [%Instance{name: "m", type: "seal"}, %Instance{name: "m2", type: "seal"}],
          connections:
            base(seal)[:connections] ++
              [
                %Connection{instance: "m", member: "motor", to: "k2"},
                %Connection{instance: "m2", member: "start", to: "k"},
                %Connection{instance: "m2", member: "stop", to: "pb2"},
                %Connection{instance: "m", member: "sp", to: "sp"}
              ]
        )

      assert %Configuration{} = Configuration.new!(fields)
    end
  end

  describe "new!/1's own refusals" do
    test "a keyword list, and nothing else", %{seal: seal} do
      takes =
        "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:, " <>
          "globals:, instances: and connections:, got: "

      assert_raise ArgumentError, takes <> "[1]", fn -> Configuration.new!(opaque([1])) end
      assert_raise ArgumentError, takes <> "%{}", fn -> Configuration.new!(opaque(%{})) end

      assert refused(base(seal) ++ [colour: 1, tasks: [], tasks: []]) == [
               ":colour is not a field of a configuration: its fields are name:, programs:, " <>
                 "tasks:, globals:, instances: and connections:",
               "tasks: is given twice"
             ]
    end

    test "programs: a list of named programs, each named once", %{seal: seal} do
      assert refused(Keyword.put(base(seal), :programs, seal)) == [
               "programs: is a list of %Logex.Program{}, as in programs: [motor], " <>
                 "got the one program `seal`"
             ]

      assert refused(Keyword.put(base(seal), :programs, [seal, :x, %{seal | name: nil}, seal])) ==
               [
                 "programs: :x is not a %Logex.Program{} from Logex.compile/2",
                 "a program in a configuration needs a name, as Logex.compile/2 gives it: " <>
                   "an instance names its program by it",
                 "two programs are named `seal`: a configuration has one of each"
               ]

      assert refused(Keyword.put(base(seal), :programs, 7)) == [
               "programs: must be a list of %Logex.Program{} from Logex.compile/2, got: 7",
               "program instance `m`: there is no program `seal`: this configuration has no program"
             ]
    end

    # A block type runs inside a program, never as one: refused once, as the host's
    # mistake, and an instance that names it is not refused again as naming no program.
    test "a function block type is not a program, and is refused once", %{seal: seal} do
      fields =
        base(seal)
        |> Keyword.put(:programs, [seal, Logex.FbType.ton()])
        |> Keyword.update!(:instances, &(&1 ++ [%Instance{name: "t", type: "ton"}]))

      assert refused(fields) == [
               "`ton` is a function block type, which runs inside a program: an instance " <>
                 "is of a %Logex.Program{}"
             ]

      config = %Configuration{
        name: "plant",
        programs: %{"ton" => Logex.FbType.ton(), "timer" => Logex.FbType.ton()},
        instances: [%Instance{name: "t", type: "ton"}]
      }

      assert mistakes(config) == [
               "the program under `timer` is `ton`, a function block type, which runs inside " <>
                 "a program: an instance is of a %Logex.Program{}",
               "`ton` is a function block type, which runs inside a program: an instance " <>
                 "is of a %Logex.Program{}"
             ]
    end

    # A line is where a configuration file declares an element, and a message cites it:
    # one from Elixir has none, as a tag declared from Elixir has none. The element is
    # refused for its line before the rule over lines is checked, and checked without it,
    # so one mistake is one message.
    test "an element from Elixir has no line", %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          tasks: [%{task("t", 0, 0) | line: 2}],
          globals: [%{hd(base(seal)[:globals]) | line: 0} | tl(base(seal)[:globals])],
          instances: [%Instance{name: "m", type: "seal", line: 6}],
          connections: [
            %{hd(base(seal)[:connections]) | line: :x} | tl(base(seal)[:connections])
          ]
        )

      assert refused(fields) == [
               "task `t` from Elixir has no line, got: 2",
               "global `pb` from Elixir has no line, got: 0",
               "program instance `m` from Elixir has no line, got: 6",
               "the connection of `m.start` from Elixir has no line, got: :x",
               "task `t`: an interval is 1 to 2147483647 ms, found 0"
             ]
    end
  end

  describe "check/1 raises a host's mistake" do
    test "takes a configuration" do
      assert_raise ArgumentError, "expected a %Logex.Configuration{}, got: 5", fn ->
        Configuration.check(opaque(5))
      end
    end

    # Decision 36: what no configuration text can say is the host's mistake, raised, every
    # one a line of one message, in the order of the fields; a mistake a text could make
    # too is a diagnostic, and new!/1 gives both, the mistakes first.
    test "every one, a line each, before any diagnostic", %{seal: seal} do
      config = %{
        Configuration.new!(base(seal))
        | file: :plant,
          name: "a b",
          tasks: [task("t", -5, 70_000), task("u", 0, 1)],
          instances: [%Instance{name: "m", type: :seal}]
      }

      assert mistakes(config) == [
               "a configuration's file is a file name, or nil for one built from Elixir, " <>
                 "got: :plant",
               ~s|"a b" cannot name a configuration: a name is a letter or `_`, then letters, | <>
                 "digits or `_`",
               "task `t`: an interval is 1 to 2147483647 ms, found -5",
               "program instance `m`: its type is a program's name, found :seal"
             ]

      fields =
        Keyword.merge(base(seal),
          name: "a b",
          tasks: [task("t", -5, 70_000), task("u", 0, 1)],
          instances: [%Instance{name: "m", type: :seal}]
        )

      assert refused(fields) == [
               ~s|"a b" cannot name a configuration: a name is a letter or `_`, then letters, | <>
                 "digits or `_`",
               "task `t`: an interval is 1 to 2147483647 ms, found -5",
               "program instance `m`: its type is a program's name, found :seal",
               "task `t`: a priority is 0, the highest, to 65535, found 70000",
               "task `u`: an interval is 1 to 2147483647 ms, found 0"
             ]
    end

    test "each field is a list of its element struct, a proper one", %{seal: seal} do
      pb = %Global{name: "pb", type: :bool, at: "panel.i.0"}

      assert refused(Keyword.merge(base(seal), globals: [pb | :tail], tasks: :x)) == [
               "tasks must be a list of %Logex.Configuration.Task{}, got: :x",
               "globals must be a list of %Logex.Configuration.Global{}, got: " <>
                 inspect([pb | :tail]),
               "`m.motor` is connected to `k`, which is not a global: the globals are `pb`"
             ]

      assert refused(
               Keyword.merge(base(seal),
                 tasks: [%{name: "t"}],
                 globals: base(seal)[:globals] ++ [%Instance{name: "q", type: "seal"}]
               )
             ) == [
               ~s|a task is a %Logex.Configuration.Task{}, got: %{name: "t"}|,
               "a global is a %Logex.Configuration.Global{}, got: " <>
                 inspect(%Instance{name: "q", type: "seal"})
             ]

      config = Configuration.new!(base(seal))

      assert mistakes(%{config | instances: [%{name: "m"}], connections: 7}) == [
               ~s|an instance is a %Logex.Configuration.Instance{}, got: %{name: "m"}|,
               "connections must be a list of %Logex.Configuration.Connection{}, got: 7"
             ]
    end

    test "a line is a positive integer, or nil", %{seal: seal} do
      config = Configuration.new!(base(seal))

      assert mistakes(%{config | tasks: [%{task("t", 10, 0) | line: 0}]}) == [
               "task `t` has line 0: a line is a positive integer, or nil for one built from " <>
                 "Elixir"
             ]

      assert mistakes(%{config | globals: [%Global{name: "g", type: :bool, line: 1.5}]}) == [
               "global `g` has line 1.5: a line is a positive integer, or nil for one built " <>
                 "from Elixir"
             ]
    end

    test "programs are a map of named programs, each under its own name", %{seal: seal} do
      config = %Configuration{
        name: "plant",
        programs: %{"x" => seal, "seal" => :junk, "a b" => %{seal | name: "a b"}},
        instances: [%Instance{name: "m", type: "seal"}]
      }

      assert mistakes(config) == [
               ~s|"a b" cannot name a program: a name is a letter or `_`, then letters, digits or `_`|,
               "the program under `seal` is not a %Logex.Program{} from Logex.compile/2, got: :junk",
               "the program under `x` is named `seal`"
             ]

      assert mistakes(%{config | programs: [seal]}) == [
               "programs must be a map of program names to %Logex.Program{}, got a list: " <>
                 "Logex.Configuration.new!/1 takes a list and keys it by name"
             ]

      assert mistakes(%{config | programs: :motor}) == [
               "programs must be a map of program names to %Logex.Program{}, got: :motor"
             ]
    end

    # The file is what every diagnostic is cited in, a reader's own choice.
    test "a configuration's file is a name, or nil", %{seal: seal} do
      config = %{Configuration.new!(base(seal)) | file: %{}, tasks: [task("t", 0, 0)]}

      assert mistakes(config) == [
               "a configuration's file is a file name, or nil for one built from Elixir, got: %{}"
             ]

      assert formatted(%{config | file: "plant.logex"}) == [
               "plant.logex: task `t`: an interval is 1 to 2147483647 ms, found 0"
             ]
    end

    # No configuration text names its configuration: a reader is told the name, or takes
    # it from a file's, so a bad one is always the host's.
    test "a configuration has a name, and it is a name", %{seal: seal} do
      assert refused(Keyword.put(base(seal), :name, "a b")) == [
               ~s|"a b" cannot name a configuration: a name is a letter or `_`, then letters, | <>
                 "digits or `_`"
             ]

      assert refused(Keyword.put(base(seal), :name, "plant.a")) == [
               ~s|"plant.a" cannot name a configuration: a name is a letter or `_`, then | <>
                 "letters, digits or `_`"
             ]

      assert refused(Keyword.delete(base(seal), :name)) == [
               ~s|a configuration needs a name, as in name: "plant"|
             ]

      config = Configuration.new!(base(seal))

      assert mistakes(%{config | name: nil}) == [
               ~s|a configuration needs a name, as in name: "plant"|
             ]

      assert mistakes(%{config | name: :plant}) == [
               ":plant cannot name a configuration: a name is a letter or `_`, then letters, " <>
                 "digits or `_`"
             ]
    end
  end

  describe "lines" do
    # As a reader of configuration text will build one: every element at its line, in
    # each list in the order the file gives them.
    defp lined(seal, lines) do
      [t, g1, g2, i, c1, c2] = lines

      %Configuration{
        name: "plant",
        file: "plant.logex",
        programs: %{"seal" => seal},
        tasks: [%{task("fast", 10, 1) | line: t}],
        globals: [
          %Global{name: "pb", type: :bool, at: "panel.i.0", line: g1},
          %Global{name: "k", type: :bool, at: "panel.q.0", line: g2}
        ],
        instances: [%Instance{name: "m", type: "seal", task: "fast", line: i}],
        connections: [
          %Connection{instance: "m", member: "start", to: "pb", line: c1},
          %Connection{instance: "m", member: "stop", to: 0, line: c2}
        ]
      }
    end

    test "all nil, or rising in each list, are taken", %{seal: seal} do
      assert Configuration.check(lined(seal, [nil, nil, nil, nil, nil, nil])) == []
      assert Configuration.check(lined(seal, [1, 2, 3, 4, 5, 6])) == []
      # Lists may interleave, as a file's lines do, and leave gaps.
      assert Configuration.check(lined(seal, [9, 1, 20, 4, 2, 30])) == []
    end

    test "lines beside none are refused, each element with none", %{seal: seal} do
      assert mistakes(lined(seal, [nil, 2, 3, nil, 5, nil])) == [
               "task `fast` has no line, beside global `pb` on line 2: a configuration's " <>
                 "lines are all nil, as from Elixir, or rise in each list, one element a line",
               "program instance `m` has no line, beside global `pb` on line 2: a " <>
                 "configuration's lines are all nil, as from Elixir, or rise in each list, " <>
                 "one element a line",
               "the connection of `m.stop` has no line, beside global `pb` on line 2: a " <>
                 "configuration's lines are all nil, as from Elixir, or rise in each list, " <>
                 "one element a line"
             ]
    end

    test "a line that does not follow the one before it in its list is refused",
         %{seal: seal} do
      assert mistakes(lined(seal, [1, 3, 2, 4, 6, 5])) == [
               "global `k` is on line 2, but follows global `pb`, on line 3: a " <>
                 "configuration's lines are all nil, as from Elixir, or rise in each list, " <>
                 "one element a line",
               "the connection of `m.stop` is on line 5, but follows the connection of " <>
                 "`m.start`, on line 6: a configuration's lines are all nil, as from Elixir, " <>
                 "or rise in each list, one element a line"
             ]

      assert mistakes(lined(seal, [1, 2, 2, 4, 5, 6])) == [
               "global `k` is on line 2, but follows global `pb`, on line 2: a " <>
                 "configuration's lines are all nil, as from Elixir, or rise in each list, " <>
                 "one element a line"
             ]
    end

    test "a line two lists share is refused", %{seal: seal} do
      assert mistakes(lined(seal, [4, 2, 3, 4, 5, 2])) == [
               "the connection of `m.stop` is on line 2, but follows the connection of " <>
                 "`m.start`, on line 5: a configuration's lines are all nil, as from Elixir, " <>
                 "or rise in each list, one element a line",
               "program instance `m` is on line 4, as task `fast` is: a configuration's lines " <>
                 "are all nil, as from Elixir, or rise in each list, one element a line",
               "the connection of `m.stop` is on line 2, as global `pb` is: a configuration's " <>
                 "lines are all nil, as from Elixir, or rise in each list, one element a line"
             ]
    end

    # A line refused as no line is not refused again by the rule over lines.
    test "a bad line is one mistake", %{seal: seal} do
      assert mistakes(lined(seal, [1, 2, 3, 0, 5, 6])) == [
               "program instance `m` has line 0: a line is a positive integer, or nil for " <>
                 "one built from Elixir"
             ]
    end
  end

  describe "lists of names" do
    # Each list a diagnostic would end with is given once, by the first diagnostic in line
    # order that needs it: n refusals against n names are n diagnostics, not n lists.
    test "each list is given once, by the first diagnostic in line order", %{seal: seal} do
      config = %Configuration{
        name: "plant",
        programs: %{"seal" => seal},
        tasks: [%{task("fast", 10, 0) | line: 1}],
        globals: [
          %Global{name: "pb", type: :bool, at: "panel.i.0", line: 2},
          %Global{name: "k", type: :bool, at: "panel.q.0", line: 3}
        ],
        instances: [
          %Instance{name: "m", type: "seal", line: 4},
          %Instance{name: "x1", type: "aaa", line: 5},
          %Instance{name: "x2", type: "zzz", line: 6},
          %Instance{name: "x3", type: "seal", task: "qq", line: 7},
          %Instance{name: "x4", type: "seal", task: "ww", line: 8}
        ],
        connections:
          for(
            {{instance, member, to}, line} <-
              Enum.with_index(
                [
                  {"m", "start", "pb"},
                  {"m", "stop", 0},
                  {"m", "sp", "aa"},
                  {"m", "motor", "zz"},
                  {"m", "qq", 0},
                  {"m", "ww", 0},
                  {"qq", "start", 0},
                  {"ww", "start", 0}
                ] ++ for(x <- ~w(x3 x4), m <- ~w(start stop), do: {x, m, 0}),
                9
              ),
            do: %Connection{instance: instance, member: member, to: to, line: line}
          )
      }

      assert formatted(config) == [
               "line 5: program instance `x1`: there is no program `aaa`: the programs are `seal`",
               "line 6: program instance `x2`: there is no program `zzz`",
               "line 7: program instance `x3`: there is no task `qq`: the tasks are `fast`",
               "line 8: program instance `x4`: there is no task `ww`",
               "line 11: `m.sp` is connected to `aa`, which is not a global: the globals are " <>
                 "`k` and `pb`",
               "line 12: `m.motor` is connected to `zz`, which is not a global",
               "line 13: `m` is a `seal`, which declares no `qq`: its var_inputs and " <>
                 "var_outputs are `motor`, `sp`, `start` and `stop`",
               "line 14: `m` is a `seal`, which declares no `ww`",
               "line 15: `qq.start`: there is no program instance `qq`: the program instances " <>
                 "are `m`, `x1`, `x2`, `x3` and `x4`",
               "line 16: `ww.start`: there is no program instance `ww`"
             ]
    end
  end

  describe "names" do
    # A name with `.` parts is one token to the lexer, so a line can hold it, and it is a
    # diagnostic; one that is no token, or not a string, no line can say.
    test "tasks, globals and program instances share one namespace, case-only twins " <>
           "refused, and a name is a name",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          tasks: [
            task("m", 10, 0),
            task("a.b", 10, 0),
            task(:t, 10, 0),
            task("a b", 10, 0),
            task("PB", 10, 0)
          ],
          instances: [%Instance{name: "m", type: "seal"}, %Instance{name: "seal", type: "seal"}]
        )

      # The instance `m` loses its name to the task, so its connections are not checked
      # against it: one mistake, one message.
      assert refused(fields) == [
               ":t cannot name a task: a name is a letter or `_`, then letters, digits or `_`",
               ~s|"a b" cannot name a task: a name is a letter or `_`, then letters, digits or `_`|,
               ~s|"a.b" cannot name a task: a name is a letter or `_`, then letters, digits or `_`|,
               "`pb` and the task `PB` differ only in case: names are case-sensitive, " <>
                 "so these would be two names",
               "`m` is already the name of a task: tasks, globals and program instances share " <>
                 "one namespace",
               "`seal.start` is not connected: every var_input is connected, to a global or a " <>
                 "constant",
               "`seal.stop` is not connected: every var_input is connected, to a global or a " <>
                 "constant"
             ]
    end

    test "a global's or an instance's name the lexer does not read as one token is the " <>
           "host's mistake",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          globals: base(seal)[:globals] ++ [%Global{name: "", type: :bool}],
          instances: [
            %Instance{name: "m", type: "seal"},
            %Instance{name: "n//x", type: "seal"},
            %Instance{name: "p.q", type: "seal"}
          ]
        )

      assert refused(fields) == [
               ~s|"" cannot name a global: a name is a letter or `_`, then letters, digits or `_`|,
               ~s|"n//x" cannot name a program instance: a name is a letter or `_`, then | <>
                 "letters, digits or `_`",
               ~s|"p.q" cannot name a program instance: a name is a letter or `_`, then | <>
                 "letters, digits or `_`"
             ]
    end
  end

  describe "tasks" do
    test "an interval is 1 to 2147483647 ms, and a priority 0 to 65535", %{seal: seal} do
      tasks = [
        task("a", 0, 65_536),
        task("b", 2_147_483_648, 2_147_483_648),
        task("c", nil, nil),
        task("d", 1.5, -1),
        task("e", -1, 1.0)
      ]

      assert refused(Keyword.put(base(seal), :tasks, tasks)) == [
               "task `d`: an interval is 1 to 2147483647 ms, found 1.5",
               "task `d`: a priority is 0, the highest, to 65535, found -1",
               "task `e`: an interval is 1 to 2147483647 ms, found -1",
               "task `e`: a priority is 0, the highest, to 65535, found 1.0",
               "task `a`: an interval is 1 to 2147483647 ms, found 0",
               "task `a`: a priority is 0, the highest, to 65535, found 65536",
               "task `b`: an interval is 1 to 2147483647 ms, found 2147483648",
               "task `b`: a priority is 0, the highest, to 65535, found 2147483648",
               "task `c`: an interval is 1 to 2147483647 ms, found nil",
               "task `c`: a priority is 0, the highest, to 65535, found nil"
             ]
    end
  end

  describe "a global's initial value" do
    # initial/1 is the one rule for a global's value where nothing has set it; its
    # doctests give its values.
    test "initial/1 takes a global whose initial value is an integer or nil" do
      for other <- [5, %Global{name: "g", type: :bool, initial: "1"}],
          do:
            assert_raise(
              ArgumentError,
              "expected a %Logex.Configuration.Global{} whose initial value is an integer " <>
                "or nil, got: #{inspect(other)}",
              fn -> Configuration.initial(opaque(other)) end
            )
    end
  end

  describe "globals" do
    test "a bool or a dint, its initial value fitting it, never negative, and none on a " <>
           "located global",
         %{seal: seal} do
      globals = [
        %Global{name: "a", type: :real},
        %Global{name: "b", type: :bool, initial: 2},
        %Global{name: "c", type: :dint, initial: 2_147_483_648},
        %Global{name: "d", type: :dint, initial: -1},
        %Global{name: "e", type: :bool, initial: 1.0},
        %Global{name: "f", type: :bool, initial: 1, at: "panel.i.5"},
        %Global{name: "h", type: :dint, initial: 7, at: "drive.q.0"},
        %Global{name: "i", type: :bool, initial: 1},
        %Global{name: "j", type: :dint, initial: 2_147_483_647},
        %Global{name: "l", type: :bool, initial: -1, at: "panel.i.6"},
        %Global{name: "n", type: nil}
      ]

      assert refused(Keyword.put(base(seal), :globals, base(seal)[:globals] ++ globals)) == [
               "global `a` has type :real: a global is :bool or :dint",
               "global `d` has the initial value `-1`, which is negative: no line can say one " <>
                 "until a negative literal lexes",
               "the initial value of global `e` must be an integer, found 1.0",
               "global `l` has the initial value `-1`, which is negative: no line can say one " <>
                 "until a negative literal lexes",
               "global `n` has type nil: a global is :bool or :dint",
               "global `b` is a bool: its initial value must be 0 or 1, found `2`",
               "global `c` is a dint: `2147483648` does not fit in 32 bits",
               "global `f` is an input point: its value comes from outside, so it takes no " <>
                 "initial value",
               "global `h` is an output point: it starts at 0 and takes its value from the " <>
                 "instance that drives it, so it takes no initial value"
             ]
    end

    # A location the lexer reads as one token is a diagnostic when it is no location; one
    # it does not, or that is not a string, no line can say.
    test "a location is a device, i or q, and an address, and one address holds one global",
         %{seal: seal} do
      ats = [
        "panel.x.0",
        "panel.i",
        "rack.slot.i.0",
        "panel.Q.0",
        "panel.i.0x",
        5,
        "panel.i.0.x",
        "panel.i.00",
        "panel.q.1.2",
        "panel.q.1.02",
        "panel.q.0",
        "panel.q.0.1",
        "panel.i.1.0",
        "panel.i.10",
        "panel. i.2"
      ]

      globals = Enum.with_index(ats, &%Global{name: "l#{&2}", type: :bool, at: &1})

      rule =
        "a location is a device, `i` for an input or `q` for an output, then an address, " <>
          "as in `panel.i.0` or `panel.q.3`"

      assert refused(Keyword.put(base(seal), :globals, base(seal)[:globals] ++ globals)) == [
               "global `l4` is at `panel.i.0x`, which is not a location: " <> rule,
               "global `l5` is at 5, which is not a location: " <> rule,
               "global `l14` is at `panel. i.2`, which is not a location: " <> rule,
               "global `l0` is at `panel.x.0`, which is not a location: " <> rule,
               "global `l1` is at `panel.i`, which is not a location: " <> rule,
               "global `l2` is at `rack.slot.i.0`, which is not a location: " <> rule,
               "global `l3` is at `panel.Q.0`, which is not a location: " <> rule,
               "global `l6` is at `panel.i.0.x`, which is not a location: " <> rule,
               "global `l7` is at `panel.i.00`, which is not a location: " <> rule,
               "global `l9` is at `panel.q.1.02`, which is not a location: " <> rule,
               "global `l10` is at `panel.q.0`, the address of global `k`: one address holds one global"
             ]
    end

    test "location/1 reads a location's parts" do
      assert Configuration.location("panel.q.0") == {:ok, {"panel", "q", [0]}}
      assert Configuration.location("rack_1.i.2.70") == {:ok, {"rack_1", "i", [2, 70]}}

      for at <-
            ["panel.x.0", "panel.i", "panel.I.0", "panel.i.x", "panel.i.07", "a b", "", nil] ++
              [~c"p.i.0", "panel.i.0 ", "panel.i.0//x"],
          do: assert(Configuration.location(at) == :error, inspect(at))
    end
  end

  describe "program instances" do
    test "name a program, and a task if any", %{seal: seal} do
      instances = [
        %Instance{name: "m", type: "seal"},
        %Instance{name: "a", type: "Seal"},
        %Instance{name: "b", type: "zzz"},
        %Instance{name: "c", type: :seal},
        %Instance{name: "d", type: "se al"},
        %Instance{name: "e", type: "seal", task: :fast},
        %Instance{name: "f", type: "seal.x", task: "fa st"}
      ]

      assert refused(Keyword.put(base(seal), :instances, instances)) == [
               "program instance `c`: its type is a program's name, found :seal",
               ~s|program instance `d`: its type is a program's name, found "se al"|,
               "program instance `e`: its task is a task's name, or nil for none, found :fast",
               ~s|program instance `f`: its task is a task's name, or nil for none, found "fa st"|,
               "program instance `a`: there is no program `Seal` — did you mean `seal`? " <>
                 "(names are case-sensitive)",
               "program instance `b`: there is no program `zzz`: the programs are `seal`",
               "program instance `f`: there is no program `seal.x` — did you mean `seal`?",
               "`e.start` is not connected: every var_input is connected, to a global or a constant",
               "`e.stop` is not connected: every var_input is connected, to a global or a constant"
             ]

      fields =
        Keyword.merge(base(seal),
          tasks: [task("fast", 10, 0), task("slow", 10, 0)],
          instances: [
            %Instance{name: "m", type: "seal", task: "fsat"},
            %Instance{name: "a", type: "seal", task: "q"},
            %Instance{name: "b", type: "seal", task: "q.r"}
          ],
          connections:
            base(seal)[:connections] ++
              for(
                x <- ~w(a b),
                m <- ~w(start stop),
                do: %Connection{instance: x, member: m, to: 0}
              )
        )

      assert refused(fields) == [
               "program instance `m`: there is no task `fsat` — did you mean `fast`?",
               "program instance `a`: there is no task `q`: the tasks are `fast` and `slow`",
               "program instance `b`: there is no task `q.r`"
             ]

      assert refused(Keyword.put(fields, :tasks, [])) == [
               "program instance `m`: there is no task `fsat`: this configuration has no task",
               "program instance `a`: there is no task `q`: this configuration has no task",
               "program instance `b`: there is no task `q.r`: this configuration has no task"
             ]
    end

    test "at least one", %{seal: seal} do
      assert refused(name: "plant", programs: [seal]) == [
               "a configuration runs at least one program instance"
             ]
    end
  end

  describe "connections" do
    test "name a var_input or var_output of a declared instance", %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          instances: [%Instance{name: "m", type: "seal"}, %Instance{name: "u", type: "zzz"}],
          connections:
            base(seal)[:connections] ++
              [
                %Connection{instance: "q", member: "start", to: "pb"},
                %Connection{instance: "u", member: "start", to: "pb"},
                %Connection{instance: "m", member: "strt", to: "pb"},
                %Connection{instance: "m", member: "t1.pre", to: "sp"},
                %Connection{instance: "m", member: "fault", to: "pb"},
                %Connection{instance: "m", member: "t1", to: "pb"},
                %Connection{instance: :m, member: "start", to: "pb"},
                %Connection{instance: "m.t1", member: "acc", to: "sp"},
                %Connection{instance: "m", member: "st art", to: "pb"},
                %Connection{instance: "m", member: :start, to: "pb"},
                %Connection{instance: "m", member: "zz", to: "pb"}
              ]
        )

      # `u` cannot run, its program unknown, so its own connection is not checked.
      assert refused(fields) == [
               ~s|a connection's instance is a name, and with its member makes one path, as | <>
                 ~s|in `m1.start`, found :m and "start"|,
               ~s|a connection's instance is a name, and with its member makes one path, as | <>
                 ~s|in `m1.start`, found "m.t1" and "acc"|,
               ~s|a connection's instance is a name, and with its member makes one path, as | <>
                 ~s|in `m1.start`, found "m" and "st art"|,
               ~s|a connection's instance is a name, and with its member makes one path, as | <>
                 ~s|in `m1.start`, found "m" and :start|,
               "program instance `u`: there is no program `zzz`: the programs are `seal`",
               "`q.start`: there is no program instance `q`: the program instances are `m` and `u`",
               "`m` is a `seal`, which declares no `strt` — did you mean `start`?",
               "`m.t1.pre` goes too deep: a connection names a var_input or var_output of a " <>
                 "program instance, as in `m.start`",
               "`m.fault` is internal to `seal` (declared `var`): only a var_input or var_output " <>
                 "connects",
               "`m.t1` is internal to `seal` (declared `var`): only a var_input or var_output " <>
                 "connects",
               "`m` is a `seal`, which declares no `zz`: its var_inputs and var_outputs are " <>
                 "`motor`, `sp`, `start` and `stop`"
             ]
    end

    test "a var_input is connected once, to a global of its type or a constant that fits",
         %{seal: seal} do
      connections = [
        %Connection{instance: "m", member: "start", to: "pbb"},
        %Connection{instance: "m", member: "stop", to: "sp"},
        %Connection{instance: "m", member: "stop", to: 1},
        %Connection{instance: "m", member: "start", to: -1},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      # A second connection is refused as one, whatever its other end.
      assert refused(Keyword.put(base(seal), :connections, connections)) == [
               "`m.start` is connected to -1: a connection's other end is a global, by name, " <>
                 "or a constant of 0 or more",
               "`m.start` is connected to `pbb`, which is not a global — did you mean `pb`?",
               "`m.stop` is a bool, but `sp` is a dint",
               "`m.stop` is already connected, to `sp`: a var_input is connected once",
               "`m.start` is already connected, to `pbb`: a var_input is connected once"
             ]

      # A var_input whose one connection has a bad other end counts as connected: one
      # mistake, one message.
      constants = [
        %Connection{instance: "m", member: "start", to: 2},
        %Connection{instance: "m", member: "stop", to: -1},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      assert refused(Keyword.put(base(seal), :connections, constants)) == [
               "`m.stop` is connected to -1: a connection's other end is a global, by name, or " <>
                 "a constant of 0 or more",
               "`m.start` is a bool: only 0 or 1 fit, found `2`"
             ]

      dints = [
        %Connection{instance: "m", member: "start", to: "pb"},
        %Connection{instance: "m", member: "stop", to: "pb 2"},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      assert refused(Keyword.put(base(seal), :connections, dints)) == [
               ~s|`m.stop` is connected to "pb 2": a connection's other end is a global, by | <>
                 "name, or a constant of 0 or more"
             ]
    end

    test "a var_output drives a global of its type, never an input point, and is the one " <>
           "connection that drives it",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          instances: [%Instance{name: "m", type: "seal"}, %Instance{name: "m2", type: "seal"}],
          connections: [
            %Connection{instance: "m", member: "start", to: "pb"},
            %Connection{instance: "m", member: "stop", to: 0},
            %Connection{instance: "m2", member: "start", to: "k"},
            %Connection{instance: "m2", member: "stop", to: "pb2"},
            %Connection{instance: "m", member: "motor", to: 1},
            %Connection{instance: "m", member: "motor", to: "kk"},
            %Connection{instance: "m", member: "motor", to: "pb"},
            %Connection{instance: "m", member: "motor", to: "sp"},
            %Connection{instance: "m", member: "motor", to: "k"},
            %Connection{instance: "m2", member: "motor", to: "k"},
            %Connection{instance: "m", member: "motor", to: :k},
            %Connection{instance: "m", member: "sp", to: -3}
          ]
        )

      assert refused(fields) == [
               "`m.motor` is connected to :k: a connection's other end is a global, by name, or " <>
                 "a constant of 0 or more",
               "`m.sp` is connected to -3: a connection's other end is a global, by name, or " <>
                 "a constant of 0 or more",
               "`m.motor` is a var_output: it drives a global, and a constant cannot be driven",
               "`m.motor` is connected to `kk`, which is not a global — did you mean `k`?",
               "`pb` is an input point: `m.motor` cannot drive it",
               "`m.motor` is a bool, but `sp` is a dint",
               "`k` is already driven by `m.motor`: one connection drives a global"
             ]
    end

    test "every var_input is connected (decision 7), cited at its instance", %{seal: seal} do
      assert refused(
               name: "plant",
               programs: [seal],
               instances: [%Instance{name: "m", type: "seal"}]
             ) ==
               [
                 "`m.start` is not connected: every var_input is connected, to a global or a constant",
                 "`m.stop` is not connected: every var_input is connected, to a global or a constant"
               ]
    end
  end

  describe "lines and the file" do
    # As a reader of configuration text will build one: every element at its line, the
    # configuration in its file. The problems come in line order, each at its own line,
    # and a message that names another element gives that element's line.
    test "each problem is cited at its line, in its file, in line order", %{seal: seal} do
      config = %Configuration{
        name: "plant",
        file: "plant.logex",
        programs: %{"seal" => seal},
        tasks: [%Configuration.Task{name: "fast", interval: 0, priority: 1, line: 2}],
        globals: [
          %Global{name: "pb", type: :bool, at: "panel.i.0", line: 3},
          %Global{name: "k", type: :bool, at: "panel.i.0", line: 4}
        ],
        instances: [
          %Instance{name: "m", type: "seal", task: "fast", line: 6},
          %Instance{name: "fast", type: "seal", line: 10}
        ],
        connections: [
          %Connection{instance: "m", member: "start", to: "pb", line: 5},
          %Connection{instance: "m", member: "start", to: "pb", line: 7},
          %Connection{instance: "m", member: "motor", to: "k", line: 8}
        ]
      }

      assert [%Diagnostic{stage: :configure, file: "plant.logex", severity: :error} | _] =
               Configuration.check(config)

      assert formatted(config) == [
               "plant.logex: line 2: task `fast`: an interval is 1 to 2147483647 ms, found 0",
               "plant.logex: line 4: global `k` is at `panel.i.0`, the address of global `pb` " <>
                 "(line 3): one address holds one global",
               "plant.logex: line 6: `m.stop` is not connected: every var_input is connected, " <>
                 "to a global or a constant",
               "plant.logex: line 7: `m.start` is already connected, to `pb` (line 5): a " <>
                 "var_input is connected once",
               "plant.logex: line 8: `k` is an input point (line 4): `m.motor` cannot drive it",
               "plant.logex: line 10: `fast` is already the name of a task (line 2): tasks, " <>
                 "globals and program instances share one namespace"
             ]
    end
  end

  describe "names, in a file" do
    # The first to take a name in line order keeps it, so the later line is the one
    # refused, whatever part of the configuration each is in: here a global, a part
    # checked before the instances, comes three lines after the instance it clashes with.
    test "the later line is refused, citing the earlier", %{seal: seal} do
      config = %{
        Configuration.new!(base(seal))
        | file: "plant.logex",
          globals: [
            %Global{name: "pb", type: :bool, at: "panel.i.0", line: 2},
            %Global{name: "k", type: :bool, at: "panel.q.0", line: 3},
            %Global{name: "m", type: :bool, line: 9}
          ],
          instances: [%Instance{name: "m", type: "seal", line: 6}],
          connections: [
            %Connection{instance: "m", member: "start", to: "pb", line: 7},
            %Connection{instance: "m", member: "stop", to: 0, line: 8}
          ]
      }

      assert formatted(config) == [
               "plant.logex: line 9: `m` is already the name of a program instance (line 6): " <>
                 "tasks, globals and program instances share one namespace"
             ]
    end
  end

  describe "nothing escapes" do
    # Any of these in any field of the configuration or of one of its elements.
    @junk [nil, 0, -1, 1.5, "", "a b", "x.y", "m", "pb", "seal", "panel.i.0", :atom, [], [1 | 2]] ++
            [%{}, {:t}, 2_147_483_648, %Instance{name: "z", type: "seal"}]

    # A seeded property: new!/1 checks with check/1, so each draw reaches both; the only
    # exception either may raise is the ArgumentError of a refused configuration.
    test "check/1 and new!/1 give a diagnostic or an ArgumentError, never anything else",
         %{seal: seal} do
      assert spoiled_new(seal, &Function.identity/1) > 2000
    end

    # The struct is the data API and may be built or edited by hand: a seeded property
    # over valid configurations spoiled by hand, junk in a field, in one field of one
    # element, an element added, or a list's tail made improper.
    test "check/1 on a configuration spoiled by hand gives diagnostics or an ArgumentError, " <>
           "never anything else",
         %{seal: seal} do
      :rand.seed(:exsss, {2026, 10, 4})
      good = Configuration.new!(Keyword.put(base(seal), :tasks, [task("fast", 10, 0)]))

      outcomes =
        for _ <- 1..2000 do
          config = spoil_struct(spoil_struct(good, :rand.uniform(4)), :rand.uniform(4))

          try do
            Configuration.check(config)
          rescue
            ArgumentError -> :raised
          end
        end

      # Nearly every spoil is one no text can say; a few are diagnostics (1,973 and 23).
      assert Enum.count(outcomes, &(&1 == :raised)) > 1500
      assert Enum.count(outcomes, &match?([%Diagnostic{} | _], &1)) > 10
    end

    # A host's list is never trusted to be proper (fix F8): an improper one, in any part or
    # as the keyword list itself, is refused like any other value that is not a list.
    test "an improper list, in any part or as the keyword list, is an ArgumentError",
         %{seal: seal} do
      for part <- ~w(programs tasks globals instances connections)a do
        fields = Keyword.put(base(seal), :tasks, [task("fast", 10, 0)])
        fields = Keyword.update!(fields, part, &(&1 ++ :tail))
        error = assert_raise ArgumentError, fn -> Configuration.new!(fields) end
        assert error.message =~ "must be a list"
      end

      takes =
        "Logex.Configuration.new!/1 takes a keyword list of name:, programs:, tasks:, " <>
          "globals:, instances: and connections:, got: "

      assert_raise ArgumentError, takes <> ~s|[{:name, "plant"} \| :tail]|, fn ->
        Configuration.new!(opaque([{:name, "plant"} | :tail]))
      end
    end

    test "a global of a refused type, or an instance of a junk name, is reported once, " <>
           "and a junk name is never offered as a did-you-mean",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          globals: [
            %Global{name: "pb", type: {:t}, at: "panel.i.0"},
            %Global{name: "k", type: %{}, at: "panel.q.0"}
          ],
          instances: [
            %Instance{name: "m", type: "seal"},
            %Instance{name: {:x}, type: "seal"},
            %Instance{name: "y.z", type: "seal"}
          ],
          connections:
            base(seal)[:connections] ++ [%Connection{instance: "q", member: "start", to: "pb"}]
        )

      assert refused(fields) == [
               "global `pb` has type {:t}: a global is :bool or :dint",
               "global `k` has type %{}: a global is :bool or :dint",
               "{:x} cannot name a program instance: a name is a letter or `_`, then letters, " <>
                 "digits or `_`",
               ~s|"y.z" cannot name a program instance: a name is a letter or `_`, then | <>
                 "letters, digits or `_`",
               "`q.start`: there is no program instance `q`: the program instances are `m`"
             ]
    end

    # 3,000 draws of new!/1 on a configuration spoiled in its fields, each accepted one
    # handed to `accepted`: the number refused.
    defp spoiled_new(seal, accepted) do
      :rand.seed(:exsss, {2026, 10, 2})
      base = Keyword.put(base(seal), :tasks, [task("fast", 10, 0)])

      for _ <- 1..3000, reduce: 0 do
        refused ->
          fields = spoil(base, :rand.uniform(3))

          try do
            accepted.(Configuration.new!(fields))
            refused
          rescue
            ArgumentError -> refused + 1
          end
      end
    end

    defp junk, do: Enum.at(@junk, :rand.uniform(length(@junk)) - 1)

    # A whole field made junk, one field of one element, or a junk element added.
    defp spoil(fields, 1) do
      key = Enum.at(Keyword.keys(fields) ++ [:name], :rand.uniform(length(fields) + 1) - 1)
      Keyword.put(fields, key, junk())
    end

    defp spoil(fields, 2) do
      key = Enum.at(~w(tasks globals instances connections)a, :rand.uniform(4) - 1)
      list = fields[key]
      i = :rand.uniform(length(list)) - 1
      element = Enum.at(list, i)

      field =
        Enum.at(Map.keys(Map.from_struct(element)), :rand.uniform(map_size(element) - 1) - 1)

      Keyword.put(fields, key, List.replace_at(list, i, Map.put(element, field, junk())))
    end

    defp spoil(fields, 3) do
      key = Enum.at(~w(tasks globals instances connections)a, :rand.uniform(4) - 1)
      Keyword.update!(fields, key, &(&1 ++ [junk()]))
    end

    defp spoil_struct(config, 1) do
      field = Enum.at(~w(name file programs tasks globals instances connections)a, rnd(7))
      Map.put(config, field, junk())
    end

    defp spoil_struct(config, kind) do
      part = Enum.at(~w(tasks globals instances connections)a, rnd(4))
      spoil_part(Map.fetch!(config, part), kind, part, config)
    end

    # A part already spoiled into something that is not a proper list is left as it is.
    defp spoil_part([_ | _] = list, kind, part, config) do
      spoiled_part(List.improper?(list), list, kind, part, config)
    end

    defp spoil_part(_not_a_list, _kind, _part, config), do: config

    defp spoiled_part(true, _list, _kind, _part, config), do: config

    defp spoiled_part(false, list, 2, part, config) do
      i = rnd(length(list))
      spoiled_element(Enum.at(list, i), i, list, part, config)
    end

    defp spoiled_part(false, list, 3, part, config), do: Map.put(config, part, list ++ [junk()])
    defp spoiled_part(false, list, 4, part, config), do: Map.put(config, part, list ++ junk())

    defp spoiled_element(%_{} = element, i, list, part, config) do
      field = Enum.at(Map.keys(Map.from_struct(element)), rnd(map_size(element) - 1))
      Map.put(config, part, List.replace_at(list, i, Map.put(element, field, junk())))
    end

    defp spoiled_element(_junk, _i, _list, _part, config), do: config

    defp rnd(n), do: :rand.uniform(n) - 1
  end

  describe "start/1 checks again" do
    # start/1 runs check/1 again: a host's mistake raises as check/1 raises it, and the
    # diagnostics raise formatted, a line each, in their order.
    test "raises the problems check/1 gives, in their order", %{seal: seal} do
      mistaken = %{Configuration.new!(base(seal)) | file: %{}, tasks: [task("t", -1, 0)]}
      error = assert_raise ArgumentError, fn -> Logex.Runtime.start(mistaken) end
      assert String.split(error.message, "\n") == mistakes(mistaken)
      assert [_, _] = mistakes(mistaken)

      config = %{
        Configuration.new!(base(seal))
        | file: "plant.logex",
          tasks: [%Configuration.Task{name: "fast", interval: 0, priority: 1, line: 2}],
          globals: [
            %Global{name: "pb", type: :bool, at: "panel.i.0", line: 3},
            %Global{name: "k", type: :bool, at: "panel.i.0", line: 4}
          ],
          instances: [%Instance{name: "fast", type: "seal", line: 9}],
          connections: [%Connection{instance: "fast", member: "start", to: "pb", line: 5}]
      }

      error = assert_raise ArgumentError, fn -> Logex.Runtime.start(config) end
      assert [_, _ | _] = lines = String.split(error.message, "\n")
      assert lines == formatted(config)
    end

    # What new!/1 accepts, start/1 starts and a cycle runs.
    test "what new!/1 accepts starts, and cycles", %{seal: seal} do
      assert spoiled_new(seal, fn config ->
               runtime = Logex.Runtime.start(config)
               {_runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, 10, %{})
             end) > 2000
    end

    # The struct is the data API and may be built or edited by hand, so start/1 checks it
    # again: valid configurations spoiled by hand, as check/1's property spoils them.
    test "start/1 refuses a configuration spoiled by hand, raising nothing else",
         %{seal: seal} do
      :rand.seed(:exsss, {2026, 10, 3})
      good = Configuration.new!(Keyword.put(base(seal), :tasks, [task("fast", 10, 0)]))

      outcomes =
        for _ <- 1..2000 do
          config = spoil_struct(spoil_struct(good, :rand.uniform(4)), :rand.uniform(4))

          try do
            runtime = Logex.Runtime.start(config)
            {_runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, 10, %{})
            :ran
          rescue
            ArgumentError -> :refused
          end
        end

      assert Enum.count(outcomes, &(&1 == :refused)) > 1500
    end
  end

  describe "growth" do
    # A configuration of n instances, each with a task, three globals and three
    # connections, two of them refused, so every check has work to do: the namespace, the
    # addresses, the instances' types and tasks, every connection, and the unconnected
    # var_inputs. Each element on its line, so the rule over lines has work to do too.
    # Counted in reductions, the least of three counts.
    defp reductions_to_check(n, seal) do
      tasks = for i <- 1..n, do: %{task("t#{i}", 10, rem(i, 65_536)) | line: i}

      globals =
        Enum.flat_map(1..n, fn i ->
          [
            %Global{name: "pb#{i}", type: :bool, at: "panel.i.#{i}", line: n + 3 * i},
            %Global{name: "k#{i}", type: :bool, at: "panel.q.#{i}", line: n + 3 * i + 1},
            %Global{name: "sp#{i}", type: :dint, line: n + 3 * i + 2}
          ]
        end)

      instances =
        for i <- 1..n,
            do: %Instance{name: "m#{i}", type: "seal", task: "t#{i}", line: 5 * n + 4 * i}

      connections =
        Enum.flat_map(1..n, fn i ->
          [
            %Connection{
              instance: "m#{i}",
              member: "start",
              to: "pb#{i}",
              line: 5 * n + 4 * i + 1
            },
            %Connection{instance: "m#{i}", member: "motor", to: "k#{i}", line: 5 * n + 4 * i + 2},
            %Connection{instance: "m#{i}", member: "motor", to: "pb#{i}", line: 5 * n + 4 * i + 3}
          ]
        end)

      config = %Configuration{
        name: "plant",
        programs: %{"seal" => seal},
        tasks: tasks,
        globals: globals,
        instances: instances,
        connections: connections
      }

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          [_ | _] = Configuration.check(config)
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    # n connections to globals that do not exist, among n globals: the refusal grows with
    # n, not with n * n, since the globals are listed once.
    test "a refusal stays linear in its size", %{seal: seal} do
      bytes = fn n ->
        fields =
          base(seal)
          |> Keyword.update!(
            :globals,
            &(&1 ++ for(i <- 1..n, do: %Global{name: "g#{i}", type: :bool}))
          )
          |> Keyword.update!(
            :connections,
            &(&1 ++ for(i <- 1..n, do: %Connection{instance: "m", member: "sp", to: "wrong_#{i}"}))
          )

        error = assert_raise ArgumentError, fn -> Configuration.new!(fields) end
        byte_size(error.message)
      end

      ratio = bytes.(400) / bytes.(100)
      assert ratio < 6, "4x the refusals made a message #{Float.round(ratio, 1)}x the size"
    end

    test "check/1 stays linear in the configuration's size", %{seal: seal} do
      ratio = reductions_to_check(2000, seal) / reductions_to_check(500, seal)
      assert ratio < 6, "4x the instances took #{Float.round(ratio, 1)}x the reductions"
    end
  end
end
