defmodule Logex.ConfigurationTest do
  @moduledoc """
  `Logex.Configuration` (M2-1, M2-2): the one validator, `check/1`, the constructor from
  Elixir, `new!/1`, and `compile/3`, from a configuration file's text. Every problem is
  pinned as a whole list, in its order: `new!/1` raises one `ArgumentError` whose message
  is every problem, a line each; `check/1` gives a mistake a configuration's text could
  also make as a diagnostic, at its element's line in the configuration's file, which is
  how a reader of the text will cite it, and raises a mistake no text can make, the
  host's, as one `ArgumentError` (decision 36); and `compile/3` gives the same
  diagnostics, in the same words, for a configuration file's text. Every check pinned
  from data is pinned again from source, but a task's, whose lines M2-3 reads.
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
    # Its warnings stop nothing, and are no problem to check/1.
    test "is built, and check/1 finds nothing in it", %{seal: seal} do
      config = Configuration.new!(base(seal))
      assert %Configuration{name: "plant", file: nil} = config
      assert config.programs == %{"seal" => seal}
      assert Configuration.check(config) == []

      assert Enum.map(config.warnings, &Diagnostic.format/1) == [
               "warning: `pb2` is declared but nothing uses it",
               "warning: `sp` is declared but nothing uses it"
             ]
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
               "unknown program type `seal`: no program types were given"
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
    # A map, another struct and a configuration's fields as a plain map are refused as 5
    # is: being a map makes nothing a configuration, so nothing reads a key it lacks.
    test "takes a configuration", %{seal: seal} do
      fields = Map.from_struct(Configuration.new!(base(seal)))

      for value <- [5, %{}, seal, fields] do
        message = "expected a %Logex.Configuration{}, got: #{inspect(value)}"
        assert_raise ArgumentError, message, fn -> Configuration.check(opaque(value)) end
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

      # The name comes before the programs, as the file before the name.
      assert mistakes(%{config | file: nil, programs: [seal]}) == [
               ~s|"a b" cannot name a configuration: a name is a letter or `_`, then letters, | <>
                 "digits or `_`",
               "programs must be a map of program names to %Logex.Program{}, got a list: " <>
                 "Logex.Configuration.new!/1 takes a list and keys it by name",
               "task `t`: an interval is 1 to 2147483647 ms, found -5",
               "program instance `m`: its type is a program's name, found :seal"
             ]
    end

    test "each field is a list of its element struct, a proper one", %{seal: seal} do
      pb = %Global{name: "pb", type: :bool, at: "panel.i.0"}

      assert refused(Keyword.merge(base(seal), globals: [pb | :tail], tasks: :x)) == [
               "tasks must be a list of %Logex.Configuration.Task{}, got: :x",
               "globals must be a list of %Logex.Configuration.Global{}, got: " <>
                 inspect([pb | :tail]),
               "no global `k`: declare it, as in `var_global k bool`"
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

    # A map that names a struct but lacks one of its keys, as Map.delete/2 makes one, is
    # not that struct, even with another key in the lacking one's place: refused as any
    # other value is, so nothing reads the missing key.
    test "a configuration or an element that lacks a key of its struct is not that struct",
         %{seal: seal} do
      config = Configuration.new!(Keyword.put(base(seal), :tasks, [task("fast", 10, 0)]))

      for {part, what} <- [
            tasks: "a task",
            globals: "a global",
            instances: "an instance",
            connections: "a connection"
          ],
          element = hd(Map.fetch!(config, part)),
          key <- Map.keys(element) -- [:__struct__],
          other <- [nil, :extra] do
        lacking = instead(element, key, other)
        message = "#{what} is a %#{inspect(element.__struct__)}{}, got: #{inspect(lacking)}"
        assert mistakes(Map.put(config, part, [lacking])) == [message]
        # new!/1 refuses a line on an element from Elixir, but not on one that is no element.
        lined = instead(%{element | line: 1}, key, other)
        fields = Keyword.put(base(seal), :tasks, [task("fast", 10, 0)])

        assert hd(refused(Keyword.put(fields, part, [lined]))) ==
                 "#{what} is a %#{inspect(element.__struct__)}{}, got: #{inspect(lined)}"
      end

      for key <- Map.keys(config) -- [:__struct__], other <- [nil, :extra] do
        lacking = instead(config, key, other)
        message = "expected a %Logex.Configuration{}, got: #{inspect(lacking)}"
        assert_raise ArgumentError, message, fn -> Configuration.check(lacking) end
        assert_raise ArgumentError, message, fn -> Logex.Runtime.start(lacking) end
      end
    end

    # A struct without `key`, and with `other` in its place unless that is nil.
    defp instead(struct, key, nil), do: Map.delete(struct, key)
    defp instead(struct, key, other), do: Map.put(Map.delete(struct, key), other, 1)

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

      # A %Logex.Program{} whose tags are not a map, or whose rungs are not a list, is no
      # program Logex.compile/2 gives.
      for junk <- [%{seal | tags: nil}, %{seal | tags: []}, %{seal | rungs: nil}],
          do:
            assert(
              mistakes(%{config | programs: %{"seal" => junk}}) == [
                "the program under `seal` is not a %Logex.Program{} from Logex.compile/2, " <>
                  "got: #{inspect(junk)}"
              ]
            )

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
    # order that needs it: n refusals against n names are n diagnostics, not n lists. An
    # unknown global or instance is told how to declare it, and lists nothing.
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
               "line 5: unknown program type `aaa`: the types given are `seal`",
               "line 6: unknown program type `zzz`",
               "line 7: program instance `x3`: there is no task `qq`: the tasks are `fast`",
               "line 8: program instance `x4`: there is no task `ww`",
               "line 11: no global `aa`: declare it, as in `var_global aa dint`",
               "line 12: no global `zz`: declare it, as in `var_global zz bool`",
               "line 13: `m` is a `seal`, which declares no `qq`: its var_inputs and " <>
                 "var_outputs are `motor`, `sp`, `start` and `stop`",
               "line 14: `m` is a `seal`, which declares no `ww`",
               "line 15: no instance `qq`: declare it, as in `program qq motor`",
               "line 16: no instance `ww`: declare it, as in `program ww motor`"
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

      # The instance `m` loses its name to the task, which keeps it: a duplicate is not
      # recovered, so each use of the name is checked against the task, as on a `.ld`
      # declaration line. A name with `.` parts is refused for them.
      assert refused(fields) == [
               ":t cannot name a task: a name is a letter or `_`, then letters, digits or `_`",
               ~s|"a b" cannot name a task: a name is a letter or `_`, then letters, digits or `_`|,
               "`a.b` cannot name a task: `.` is kept for a path, as in `m1.start`, and a " <>
                 "location, as in `panel.i.0`",
               "`pb` and `PB` differ only in case: names are case-sensitive, so these would be " <>
                 "two (`PB` is a task)",
               "`m` is declared twice: the first is a task",
               "`m` is a task, not an instance",
               "`m` is a task, not an instance",
               "`m` is a task, not an instance",
               "`seal` leaves its var_inputs `start` and `stop` unconnected: connect each to a " <>
                 "global, a point or a constant, as in `seal.start 0`"
             ]
    end

    # Such an element is left out of every diagnostic, which would cite it by a name no
    # text can say, so none of its other fields is checked: here a task's interval and
    # priority, a global's initial value, location and address, and an instance's program
    # and task, each out of its rule, give nothing.
    test "a task's, a global's or an instance's name the lexer does not read as one token " <>
           "is the host's mistake",
         %{seal: seal} do
      fields =
        Keyword.merge(base(seal),
          tasks: [task(:t, 0, 70_000)],
          globals:
            base(seal)[:globals] ++
              [
                %Global{name: "", type: :bool, initial: 7, at: "nowhere"},
                %Global{name: "a b", type: :bool, at: "panel.i.0"}
              ],
          instances: [
            %Instance{name: "m", type: "seal"},
            %Instance{name: "n//x", type: "zzz", task: "qqq"},
            %Instance{name: "p.q", type: "seal"}
          ]
        )

      assert refused(fields) == [
               ":t cannot name a task: a name is a letter or `_`, then letters, digits or `_`",
               ~s|"" cannot name a global: a name is a letter or `_`, then letters, digits or `_`|,
               ~s|"a b" cannot name a global: a name is a letter or `_`, then letters, digits | <>
                 "or `_`",
               ~s|"n//x" cannot name a program instance: a name is a letter or `_`, then | <>
                 "letters, digits or `_`",
               "`p.q` cannot name an instance: `.` is kept for a path, as in `m1.start`, and a " <>
                 "location, as in `panel.i.0`"
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
               "`b` is a bool: its initial value must be 0 or 1, found `2`",
               "`c` is a dint: `2147483648` does not fit in 32 bits",
               "`f` is an input point: its value comes from the input image, so it takes no " <>
                 "initial value",
               "`h` is an output point: it takes no initial value, and is 0 until its driver " <>
                 "writes it"
             ]
    end

    # A location the lexer reads as one token is a diagnostic when it is no location, and
    # one written another way than its one spelling is told that spelling; one the lexer
    # does not read as one token, or that is not a string, no line can say.
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

      no =
        "is not a location: a location is a device, `i` or `q`, and an address, as in " <>
          "`panel.i.0`"

      as_written =
        "is not a location as written: a location's `i` or `q` is lowercase and its address " <>
          "has no leading zero, so it is written"

      assert refused(Keyword.put(base(seal), :globals, base(seal)[:globals] ++ globals)) == [
               "global `l4` is at `panel.i.0x`, which is not a location: " <> rule,
               "global `l5` is at 5, which is not a location: " <> rule,
               "global `l14` is at `panel. i.2`, which is not a location: " <> rule,
               "`panel.x.0` " <> no,
               "`panel.i` " <> no,
               "`rack.slot.i.0` " <> no,
               "`panel.Q.0` " <> as_written <> " `panel.q.0`",
               "`panel.i.0.x` " <> no,
               "`panel.i.00` " <> as_written <> " `panel.i.0`",
               "`panel.q.1.02` " <> as_written <> " `panel.q.1.2`",
               "`l10` is at `panel.q.0`, where `k` already is: a location holds one global"
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
               "unknown program type `Seal` — did you mean `seal`? (program types are " <>
                 "case-sensitive)",
               "unknown program type `zzz`: the types given are `seal`",
               "`seal.x` cannot name a program type: a type is named by its file, `motor.ld` " <>
                 "for `motor`, and a name is a letter or `_`, then letters, digits or `_`",
               "`e` leaves its var_inputs `start` and `stop` unconnected: connect each to a " <>
                 "global, a point or a constant, as in `e.start 0`"
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
               "this configuration declares no `program`: it would run nothing"
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
               "unknown program type `zzz`: the types given are `seal`",
               "no instance `q`: declare it, as in `program q motor`",
               "`m` is a `seal`, which declares no `strt` — did you mean `start`?",
               "`m.t1.pre` goes too deep: a connection names an instance's var_input or " <>
                 "var_output, as in `m.start`",
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
               "no global `pbb` — did you mean `pb`?",
               "`m.stop` is a bool, but `sp` is a dint",
               "`m.stop` is already connected, to `sp`: a var_input has one source",
               "`m.start` is already connected, to `pbb`: a var_input has one source"
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

      # A var_input tied to a constant is connected as surely as one tied to a global; a
      # name with `.` parts is one a line can hold, so connecting to one is a diagnostic.
      again = [
        %Connection{instance: "m", member: "start", to: 0},
        %Connection{instance: "m", member: "start", to: "pb"},
        %Connection{instance: "m", member: "stop", to: "m.motor"},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      config = Configuration.new!(base(seal))

      assert Enum.map(Configuration.check(%{config | connections: again}), & &1.message) == [
               "`m.start` is already connected, to `0`: a var_input has one source",
               "`m.motor` is an instance's member: instances share a value only through a " <>
                 "global, which one drives and the other reads"
             ]
    end

    test "a dint var_input's constant fits in 32 bits" do
      {:ok, dints} =
        Logex.compile("var_input a dint\nvar_output q dint\nmove a q", name: "dints")

      fields = fn to ->
        [
          name: "plant",
          programs: [dints],
          globals: [%Global{name: "n", type: :dint}],
          instances: [%Instance{name: "d", type: "dints"}],
          connections: [
            %Connection{instance: "d", member: "a", to: to},
            %Connection{instance: "d", member: "q", to: "n"}
          ]
        ]
      end

      assert %Configuration{} = Configuration.new!(fields.(2_147_483_647))

      for to <- [2_147_483_648, 3_000_000_000],
          do: assert(refused(fields.(to)) == ["`d.a` is a dint: `#{to}` does not fit in 32 bits"])
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
               "`m.motor` is a var_output, which drives a global: it cannot drive the constant " <>
                 "`1`",
               "no global `kk` — did you mean `k`?",
               "`pb` is an input point: `m.motor`, a var_output, cannot drive it",
               "`m.motor` is a bool, but `sp` is a dint",
               "`k` is already driven by `m.motor`"
             ]

      # A var_output refused for its type drives nothing, so the one that then drives its
      # global is not refused as a second: one mistake, one message.
      mistyped = [
        %Connection{instance: "m", member: "start", to: "pb"},
        %Connection{instance: "m", member: "stop", to: 0},
        %Connection{instance: "m", member: "sp", to: "k"},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      assert refused(Keyword.put(base(seal), :connections, mistyped)) == [
               "`m.sp` is a dint, but `k` is a bool"
             ]
    end

    # One diagnostic an instance, at its line, naming every var_input it leaves.
    test "every var_input is connected (decision 7), cited at its instance", %{seal: seal} do
      assert refused(
               name: "plant",
               programs: [seal],
               instances: [%Instance{name: "m", type: "seal"}]
             ) ==
               [
                 "`m` leaves its var_inputs `start` and `stop` unconnected: connect each to a " <>
                   "global, a point or a constant, as in `m.start 0`"
               ]

      assert refused(
               name: "plant",
               programs: [seal],
               instances: [%Instance{name: "m", type: "seal"}],
               connections: [%Connection{instance: "m", member: "stop", to: 0}]
             ) ==
               [
                 "`m` leaves its var_input `start` unconnected: connect it to a global, a point " <>
                   "or a constant, as in `m.start 0`"
               ]

      # In the order the program declares them, which is not the order of their names.
      {:ok, zig} =
        Logex.compile(
          "var_input zeta bool\nvar_input alpha bool\nvar_output o bool\n" <>
            "xic zeta xic alpha ote o",
          name: "zig"
        )

      assert refused(
               name: "plant",
               programs: [zig],
               instances: [%Instance{name: "z", type: "zig"}]
             ) ==
               [
                 "`z` leaves its var_inputs `zeta` and `alpha` unconnected: connect each to a " <>
                   "global, a point or a constant, as in `z.zeta 0`"
               ]
    end

    # A bad name is not recovered, as on a `.ld` declaration line: a connection whose
    # member the host gave as an atom names no var_input, so new!/1, which gives the
    # diagnostics beside the host's mistakes, finds that var_input not connected. A bad
    # other end names the var_input, which counts as connected.
    test "a connection whose end is the host's mistake connects nothing", %{seal: seal} do
      ends = [
        %Connection{instance: "m", member: :start, to: "pb"},
        %Connection{instance: "m", member: "stop", to: -1},
        %Connection{instance: "m", member: "motor", to: "k"}
      ]

      assert refused(Keyword.put(base(seal), :connections, ends)) == [
               ~s|a connection's instance is a name, and with its member makes one path, as | <>
                 ~s|in `m1.start`, found "m" and :start|,
               "`m.stop` is connected to -1: a connection's other end is a global, by name, or " <>
                 "a constant of 0 or more",
               "`m` leaves its var_input `start` unconnected: connect it to a global, a point " <>
                 "or a constant, as in `m.start 0`"
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
               "plant.logex: line 4: `k` is at `panel.i.0`, where `pb` already is (line 3): a " <>
                 "location holds one global",
               "plant.logex: line 6: `m` leaves its var_input `stop` unconnected: connect it to " <>
                 "a global, a point or a constant, as in `m.stop 0`",
               "plant.logex: line 7: `m.start` is already connected, to `pb` (line 5): a " <>
                 "var_input has one source",
               "plant.logex: line 8: `k` is an input point (line 4): `m.motor`, a var_output, " <>
                 "cannot drive it",
               "plant.logex: line 10: `fast` is declared twice: first on line 2, as a task"
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
               "plant.logex: line 9: `m` is declared twice: first on line 6, as an instance"
             ]
    end
  end

  describe "a refused name, in a file" do
    # The name is all that is refused: every other field of the element is checked, as on
    # a `.ld` declaration line, and a use of the name finds the element that kept it.
    test "an element whose name is refused still has its other fields checked",
         %{seal: seal} do
      config = %Configuration{
        name: "plant",
        file: "plant.logex",
        programs: %{"seal" => seal},
        tasks: [
          %{task("t", 10, 0) | line: 1},
          %{task("T", 0, 70_000) | line: 2},
          %{task("u.v", nil, nil) | line: 3}
        ],
        globals: [
          %Global{name: "g", type: :bool, line: 4},
          %Global{name: "g", type: :bool, initial: 7, at: "nowhere", line: 5}
        ],
        instances: [
          %Instance{name: "m", type: "seal", line: 6},
          %Instance{name: "m", type: "zzz", task: "qqq", line: 7}
        ],
        connections:
          for(
            {member, line} <- [{"start", 8}, {"stop", 9}],
            do: %Connection{instance: "m", member: member, to: 0, line: line}
          )
      }

      assert formatted(config) == [
               "plant.logex: line 2: `T` and `t` (line 1) differ only in case: names are " <>
                 "case-sensitive, so these would be two (`t` is a task)",
               "plant.logex: line 2: task `T`: an interval is 1 to 2147483647 ms, found 0",
               "plant.logex: line 2: task `T`: a priority is 0, the highest, to 65535, found 70000",
               "plant.logex: line 3: `u.v` cannot name a task: `.` is kept for a path, as in " <>
                 "`m1.start`, and a location, as in `panel.i.0`",
               "plant.logex: line 3: task `u.v`: an interval is 1 to 2147483647 ms, found nil",
               "plant.logex: line 3: task `u.v`: a priority is 0, the highest, to 65535, found nil",
               "plant.logex: line 5: `g` is declared twice: first on line 4, as a global",
               "plant.logex: line 5: `g` is a bool: its initial value must be 0 or 1, found `7`",
               "plant.logex: line 5: `nowhere` is not a location: a location is a device, `i` " <>
                 "or `q`, and an address, as in `panel.i.0`",
               "plant.logex: line 7: `m` is declared twice: first on line 6, as an instance",
               "plant.logex: line 7: unknown program type `zzz`: the types given are `seal`",
               "plant.logex: line 7: program instance `m`: there is no task `qqq`: the tasks " <>
                 "are `t`"
             ]
    end

    # A duplicate is not recovered: a use of its name is checked against the global that
    # kept the name, the first in line order, never the later one. So `m.start`, a bool,
    # reads the bool `pb`, not the dint; `m.motor` drives the `k` that is no input point;
    # and `m.sp`, a dint, cannot drive the bool `pb`.
    test "a use of a refused name finds the element that kept it", %{seal: seal} do
      config = %Configuration{
        name: "plant",
        file: "plant.logex",
        programs: %{"seal" => seal},
        globals: [
          %Global{name: "pb", type: :bool, line: 1},
          %Global{name: "pb", type: :dint, line: 2},
          %Global{name: "k", type: :bool, line: 3},
          %Global{name: "k", type: :bool, at: "panel.i.0", line: 4}
        ],
        instances: [%Instance{name: "m", type: "seal", line: 5}],
        connections: [
          %Connection{instance: "m", member: "start", to: "pb", line: 6},
          %Connection{instance: "m", member: "stop", to: 0, line: 7},
          %Connection{instance: "m", member: "motor", to: "k", line: 8},
          %Connection{instance: "m", member: "sp", to: "pb", line: 9}
        ]
      }

      assert formatted(config) == [
               "plant.logex: line 2: `pb` is declared twice: first on line 1, as a global",
               "plant.logex: line 4: `k` is declared twice: first on line 3, as a global",
               "plant.logex: line 9: `m.sp` is a dint, but `pb` is a bool (line 1)"
             ]
    end
  end

  # M2-2: a configuration file's text, compiled against program types given as data.

  # `base/1` as a configuration file says it, one element a line.
  @base """
  var_global pb bool at panel.i.0
  var_global pb2 bool at panel.i.1
  var_global k bool at panel.q.0
  var_global sp dint
  program m seal
  m.start pb
  m.stop 0
  m.motor k
  """

  # The §4.2 motor, which `docs/organisation.md` §4.4's plant and its receipt run.
  @motor """
  var_input start bool
  var_input stop bool
  var_input overtemp bool
  var_input reset bool
  var_output motor bool
  var_output run_lamp bool
  var_output speed_sp dint 1200
  var fault bool

  ( xic start | xic motor ) xio stop ote motor
  xic motor ote run_lamp
  xic overtemp otl fault
  xic reset otu fault
  xic fault move 0 speed_sp
  """

  @snapshot """
  var_input a bool
  var_input b bool
  var_output a_was bool
  var_output b_was bool

  xic a ote a_was
  xic b ote b_was
  """

  # The receipt's broken source (`docs/organisation.md` §4.4), one mistake on each of
  # lines 7, 9, 11, 12, 14, 15 and 16 and every other line right, as the design pass wrote
  # it: its line 6 declares a task, and line 9's mistake is the task its instance names.
  @broken """
  // broken: seven mistakes, one a line
  var_global pb bool at panel.i.0
  var_global k bool at panel.q.0
  var_global lamp bool at panel.q.1
  var_global x bool
  task fast interval 10 priority 1
  progam m0 motor
  var_global st bool at panel.i.1
  program m1 motor with medium
  m1.start pb
  m1.strat pb
  m1.motor pb
  m1.run_lamp k
  m1.motor k
  m1.fault x
  m1.speed_sp k
  m1.stop st
  m1.overtemp 0
  m1.reset 0
  """

  defp plant_programs do
    {:ok, motor} = Logex.compile(@motor, name: "motor")
    {:ok, snapshot} = Logex.compile(@snapshot, name: "snapshot")
    %{"motor" => motor, "snapshot" => snapshot}
  end

  defp compiled(source, programs), do: Configuration.compile("plant", source, programs)

  # Every diagnostic compile/3 gives for `source`, formatted.
  defp errors(source, programs) do
    assert {:error, diagnostics} = compiled(source, programs)
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  # The warnings of a configuration compile/3 accepts, formatted.
  defp warned(source, programs) do
    assert {:ok, %Configuration{warnings: warnings}} = compiled(source, programs)
    Enum.map(warnings, &Diagnostic.format/1)
  end

  # `docs/organisation.md` §4.4's plant, cut from the document, its task lines and each
  # `with` blanked, so every line keeps its number: M2-2's words.
  defp taskless_plant do
    [_before, rest] =
      String.split(File.read!("docs/organisation.md"), "```\n// plant.", parts: 2)

    [block, _after] = String.split("// plant." <> rest, "```", parts: 2)

    block
    |> String.replace(~r/^task .*$/m, "")
    |> String.replace(~r/ with \w+$/m, "")
  end

  describe "compile/3 (M2-2): a configuration file's text, checked by check/1's rules" do
    # The plant's motor is the §4.3 form, whose `estop` is a var_external, which M2-4
    # brings: run against the §4.2 motor, `estop` is a global nothing uses.
    test "§4.4's plant, in M2-2's words, compiles, starts and cycles" do
      programs = plant_programs()
      assert {:ok, plant} = compiled(taskless_plant(), programs)

      assert %Configuration{name: "plant", file: nil, tasks: []} = plant
      assert plant.programs == programs

      assert Enum.map(plant.instances, &{&1.name, &1.type, &1.task, &1.line}) ==
               [{"m1", "motor", nil, 23}, {"m2", "motor", nil, 32}, {"snap", "snapshot", nil, 41}]

      assert length(plant.globals) == 16 and length(plant.connections) == 18

      assert Enum.map(plant.warnings, &Diagnostic.format/1) == [
               "line 6: warning: `estop` is declared but nothing uses it"
             ]

      assert Configuration.check(plant) == []
      runtime = Logex.Runtime.start(plant)
      {runtime, outputs, _events} = Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 1})
      assert %{"k1" => 1, "k2" => 0, "sp_1" => 1200} = outputs
      assert Logex.Runtime.get!(runtime, "m1.motor") == 1
    end

    # Six of the receipt's seven, word for word as M2-2's checks give them, with the task
    # its line 6 declares and line 9's `with` left out, so every line keeps its number.
    # Line 9's, an instance's unknown task, lands with M2-3, which reads `task` and `with`.
    test "gives the receipt's diagnostics for its broken source, one a line" do
      taskless =
        @broken
        |> String.replace("task fast interval 10 priority 1", "// a task line, M2-3's")
        |> String.replace(" with medium", "")

      assert errors(taskless, plant_programs()) == [
               "line 7, column 1: unknown configuration line `progam` — did you mean `program`?",
               "line 11: `m1` is a `motor`, which declares no `strat` — did you mean `start`?",
               "line 12: `pb` is an input point (line 2): `m1.motor`, a var_output, cannot drive " <>
                 "it",
               "line 14: `k` is already driven by `m1.run_lamp` (line 13)",
               "line 15: `m1.fault` is internal to `motor` (declared `var`): only a var_input or " <>
                 "var_output connects",
               "line 16: `m1.speed_sp` is a dint, but `k` is a bool (line 3)"
             ]
    end

    # As written, its task line and its `with` are words no M2-2 line reads. The broken
    # `program` line still declares `m1`, so nothing that names `m1` is reported again.
    test "the receipt's source as written is refused where it names a task, its broken " <>
           "instance's connections silent" do
      assert errors(@broken, plant_programs()) == [
               "line 6, column 1: unknown configuration line `task`: a line starts with " <>
                 "`var_global` or `program`, or is a connection, as in `m1.start pb_start_1`",
               "line 7, column 1: unknown configuration line `progam` — did you mean `program`?",
               "line 9, column 18: unexpected `with` after `program m1 motor`"
             ]
    end

    test "a diagnostic is at stage :configure, in no file, and a line's reading comes " <>
           "before its checks" do
      source = "var_global program\nprogram m snapshot\nm.a 0\nm.b 0"
      assert {:error, [read, checked]} = compiled(source, plant_programs())

      assert %Diagnostic{stage: :configure, line: 1, column: 1, file: nil, severity: :error} =
               read

      assert %Diagnostic{stage: :configure, line: 1, column: nil, file: nil} = checked

      assert Enum.map([read, checked], &Diagnostic.format/1) == [
               "line 1, column 1: `program` needs a type: `var_global program bool` or " <>
                 "`var_global program dint`",
               "line 1: `program` is a keyword and cannot name a global"
             ]
    end

    test "a lex error stops it and is the only diagnostic" do
      assert compiled("program m1 motor\nvar_global a bool at %ix0.0\nm1.zz 7", plant_programs()) ==
               {:error,
                [
                  %Diagnostic{
                    stage: :lex,
                    line: 2,
                    column: 22,
                    message: ~s(illegal character "%")
                  }
                ]}
    end

    # Its warnings are the ones its configuration built from Elixir gets, and stop
    # nothing; a configuration with a mistake carries none.
    test "what it accepts, check/1 accepts and start/1 runs; what it refuses carries no " <>
           "warning",
         %{seal: seal} do
      assert {:ok, config} = compiled(@base, %{"seal" => seal})
      assert Configuration.check(config) == []
      assert %Logex.Runtime{} = Logex.Runtime.start(config)

      assert Enum.map(config.warnings, &Diagnostic.format/1) == [
               "line 2: warning: `pb2` is declared but nothing uses it",
               "line 4: warning: `sp` is declared but nothing uses it"
             ]

      assert errors(@base <> "m.stop 1\n", %{"seal" => seal}) == [
               "line 9: `m.stop` is already connected, to `0` (line 7): a var_input has one source"
             ]
    end
  end

  # Every check M2-1 pins from data, again as a whole list from source, in the same words
  # (`docs/organisation.md` §4.10). A task's checks wait for M2-3, which reads task lines,
  # and a host's mistake is no text's.
  describe "every check from data, again from source" do
    test "a configuration that runs", %{seal: seal} do
      programs = %{"seal" => seal}

      assert {:ok, _} =
               compiled(
                 String.replace(@base, "program m seal", "program seal seal")
                 |> String.replace(~r/^m\./m, "seal."),
                 programs
               )

      assert warned(
               @base <>
                 "var_global k2 bool at panel.q.1\nprogram m2 seal\nm.motor k2\nm2.start k\n" <>
                 "m2.stop pb2\nm.sp sp\n",
               programs
             ) == []
    end

    test "each list of names is given once, by the first diagnostic in line order",
         %{seal: seal} do
      source = """
      var_global pb bool at panel.i.0
      var_global k bool at panel.q.0
      program m seal
      program x1 aaa
      program x2 zzz
      m.start pb
      m.stop 0
      m.sp aa
      m.motor zz
      m.qq 0
      m.ww 0
      qq.start 0
      ww.start 0
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 4: unknown program type `aaa`: the types given are `seal`",
               "line 5: unknown program type `zzz`",
               "line 8: no global `aa`: declare it, as in `var_global aa dint`",
               "line 9: no global `zz`: declare it, as in `var_global zz bool`",
               "line 10: `m` is a `seal`, which declares no `qq`: its var_inputs and " <>
                 "var_outputs are `motor`, `sp`, `start` and `stop`",
               "line 11: `m` is a `seal`, which declares no `ww`",
               "line 12: no instance `qq`: declare it, as in `program qq motor`",
               "line 13: no instance `ww`: declare it, as in `program ww motor`"
             ]
    end

    # The instance `m` loses its name to the global, which keeps it: each use of the name
    # is checked against the global.
    test "globals and instances share one namespace, case-only twins refused, and a name " <>
           "has no `.`",
         %{seal: seal} do
      source = """
      var_global pb bool at panel.i.0
      var_global k bool at panel.q.0
      var_global m bool
      program m seal
      var_global a.b bool
      program PB seal
      program seal seal
      m.start pb
      m.stop 0
      m.motor k
      seal.start 0
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 4: `m` is declared twice: first on line 3, as a global",
               "line 5: `a.b` cannot name a global: `.` is kept for a path, as in `m1.start`, " <>
                 "and a location, as in `panel.i.0`",
               "line 6: `PB` and `pb` (line 1) differ only in case: names are case-sensitive, " <>
                 "so these would be two (`pb` is a global)",
               "line 7: `seal` leaves its var_input `stop` unconnected: connect it to a global, " <>
                 "a point or a constant, as in `seal.stop 0`",
               "line 8: `m` is a global (line 3), not an instance",
               "line 9: `m` is a global (line 3), not an instance",
               "line 10: `m` is a global (line 3), not an instance"
             ]
    end

    test "an element whose name is refused still has its other fields checked", %{seal: seal} do
      source = """
      var_global g bool
      var_global g bool 7 at nowhere
      program m seal
      program m zzz
      m.start 0
      m.stop 0
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 2: `g` is declared twice: first on line 1, as a global",
               "line 2: `g` is a bool: its initial value must be 0 or 1, found `7`",
               "line 2: `nowhere` is not a location: a location is a device, `i` or `q`, and " <>
                 "an address, as in `panel.i.0`",
               "line 4: `m` is declared twice: first on line 3, as an instance",
               "line 4: unknown program type `zzz`: the types given are `seal`"
             ]
    end

    test "a use of a refused name finds the element that kept it", %{seal: seal} do
      source = """
      var_global pb bool
      var_global pb dint
      var_global k bool
      var_global k bool at panel.i.0
      program m seal
      m.start pb
      m.stop 0
      m.motor k
      m.sp pb
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 2: `pb` is declared twice: first on line 1, as a global",
               "line 4: `k` is declared twice: first on line 3, as a global",
               "line 9: `m.sp` is a dint, but `pb` is a bool (line 1)"
             ]
    end

    test "a global's initial value fits its type, and a located global takes none",
         %{seal: seal} do
      source =
        @base <>
          """
          var_global b bool 2
          var_global c dint 2147483648
          var_global f bool 1 at panel.i.5
          var_global h dint 7 at drive.q.0
          var_global i bool 1
          var_global j dint 2147483647
          """

      assert errors(source, %{"seal" => seal}) == [
               "line 9: `b` is a bool: its initial value must be 0 or 1, found `2`",
               "line 10: `c` is a dint: `2147483648` does not fit in 32 bits",
               "line 11: `f` is an input point: its value comes from the input image, so it " <>
                 "takes no initial value",
               "line 12: `h` is an output point: it takes no initial value, and is 0 until its " <>
                 "driver writes it"
             ]
    end

    test "a location is a device, i or q, and an address in its one spelling, one address " <>
           "a global",
         %{seal: seal} do
      source =
        @base <>
          """
          var_global l0 bool at panel.x.0
          var_global l1 bool at panel.i
          var_global l2 bool at rack.slot.i.0
          var_global l3 bool at panel.Q.0
          var_global l6 bool at panel.i.0.x
          var_global l7 bool at panel.i.00
          var_global l8 bool at panel.q.1.2
          var_global l9 bool at panel.q.1.02
          var_global l10 bool at panel.q.0
          var_global l11 bool at panel.q.0.1
          var_global l12 bool at panel.i.1.0
          var_global l13 bool at panel.i.10
          """

      no =
        "is not a location: a location is a device, `i` or `q`, and an address, as in " <>
          "`panel.i.0`"

      as_written =
        "is not a location as written: a location's `i` or `q` is lowercase and its address " <>
          "has no leading zero, so it is written"

      assert errors(source, %{"seal" => seal}) == [
               "line 9: `panel.x.0` " <> no,
               "line 10: `panel.i` " <> no,
               "line 11: `rack.slot.i.0` " <> no,
               "line 12: `panel.Q.0` " <> as_written <> " `panel.q.0`",
               "line 13: `panel.i.0.x` " <> no,
               "line 14: `panel.i.00` " <> as_written <> " `panel.i.0`",
               "line 16: `panel.q.1.02` " <> as_written <> " `panel.q.1.2`",
               "line 17: `l10` is at `panel.q.0`, where `k` already is (line 3): a location " <>
                 "holds one global"
             ]
    end

    test "an instance names a program type given", %{seal: seal} do
      source = """
      program m seal
      program a Seal
      program b zzz
      program f seal.x
      """

      tied = for x <- ~w(m a b f), member <- ~w(start stop), do: "#{x}.#{member} 0"

      assert errors(source <> Enum.join(tied, "\n"), %{"seal" => seal}) == [
               "line 2: unknown program type `Seal` — did you mean `seal`? (program types are " <>
                 "case-sensitive)",
               "line 3: unknown program type `zzz`: the types given are `seal`",
               "line 4: `seal.x` cannot name a program type: a type is named by its file, " <>
                 "`motor.ld` for `motor`, and a name is a letter or `_`, then letters, digits " <>
                 "or `_`"
             ]

      assert errors("program m seal\nm.start 0\nm.stop 0", %{}) == [
               "line 1: unknown program type `seal`: no program types were given"
             ]
    end

    test "a configuration runs at least one program instance" do
      for source <- ["var_global a bool", "", "// nothing\n"] do
        assert errors(source, plant_programs()) == [
                 "this configuration declares no `program`: it would run nothing"
               ]
      end
    end

    test "a connection names a var_input or var_output of a declared instance", %{seal: seal} do
      source =
        @base <>
          """
          program u zzz
          q.start pb
          u.start pb
          m.strt pb
          m.t1.pre sp
          m.fault pb
          m.t1 pb
          m.zz pb
          """

      # `u` cannot run, its program unknown, so its own connection is not checked.
      assert errors(source, %{"seal" => seal}) == [
               "line 9: unknown program type `zzz`: the types given are `seal`",
               "line 10: no instance `q`: declare it, as in `program q motor`",
               "line 12: `m` is a `seal`, which declares no `strt` — did you mean `start`?",
               "line 13: `m.t1.pre` goes too deep: a connection names an instance's var_input " <>
                 "or var_output, as in `m.start`",
               "line 14: `m.fault` is internal to `seal` (declared `var`): only a var_input or " <>
                 "var_output connects",
               "line 15: `m.t1` is internal to `seal` (declared `var`): only a var_input or " <>
                 "var_output connects",
               "line 16: `m` is a `seal`, which declares no `zz`: its var_inputs and " <>
                 "var_outputs are `motor`, `sp`, `start` and `stop`"
             ]
    end

    test "a var_input has one source, a global of its type or a constant that fits",
         %{seal: seal} do
      source = """
      var_global pb bool at panel.i.0
      var_global pb2 bool at panel.i.1
      var_global k bool at panel.q.0
      var_global sp dint
      program m seal
      m.start pbb
      m.stop sp
      m.stop 1
      m.motor k
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 6: no global `pbb` — did you mean `pb`?",
               "line 7: `m.stop` is a bool, but `sp` is a dint (line 4)",
               "line 8: `m.stop` is already connected, to `sp` (line 7): a var_input has one " <>
                 "source"
             ]

      assert errors(String.replace(@base, "m.start pb", "m.start 2"), %{"seal" => seal}) == [
               "line 6: `m.start` is a bool: only 0 or 1 fit, found `2`"
             ]

      {:ok, dints} =
        Logex.compile("var_input a dint\nvar_output q dint\nmove a q", name: "dints")

      dint = fn to -> "var_global n dint\nprogram d dints\nd.a #{to}\nd.q n" end
      assert {:ok, _} = compiled(dint.(2_147_483_647), %{"dints" => dints})

      assert errors(dint.(2_147_483_648), %{"dints" => dints}) == [
               "line 3: `d.a` is a dint: `2147483648` does not fit in 32 bits"
             ]
    end

    test "a var_output drives a global of its type, never an input point, and is the one " <>
           "connection that drives it",
         %{seal: seal} do
      source = """
      var_global pb bool at panel.i.0
      var_global pb2 bool at panel.i.1
      var_global k bool at panel.q.0
      var_global sp dint
      program m seal
      program m2 seal
      m.start pb
      m.stop 0
      m2.start k
      m2.stop pb2
      m.motor 1
      m.motor kk
      m.motor pb
      m.motor sp
      m.motor k
      m2.motor k
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 11: `m.motor` is a var_output, which drives a global: it cannot drive the " <>
                 "constant `1`",
               "line 12: no global `kk` — did you mean `k`?",
               "line 13: `pb` is an input point (line 1): `m.motor`, a var_output, cannot drive " <>
                 "it",
               "line 14: `m.motor` is a bool, but `sp` is a dint (line 4)",
               "line 16: `k` is already driven by `m.motor` (line 15)"
             ]

      # A var_output refused for its type drives nothing.
      mistyped = "var_global k bool\nprogram m seal\nm.start 0\nm.stop 0\nm.sp k\nm.motor k"

      assert errors(mistyped, %{"seal" => seal}) == [
               "line 5: `m.sp` is a dint, but `k` is a bool (line 1)"
             ]
    end

    # One diagnostic an instance, at its `program` line, naming every var_input it leaves,
    # in the order its program declares them.
    test "every var_input is connected (decision 7), cited at its instance's line",
         %{seal: seal} do
      {:ok, zig} =
        Logex.compile(
          "var_input zeta bool\nvar_input alpha bool\nvar_output o bool\nxic zeta xic alpha ote o",
          name: "zig"
        )

      source = "program m seal\nprogram n seal\nn.stop 0\nprogram z zig\n"

      assert errors(source, %{"seal" => seal, "zig" => zig}) == [
               "line 1: `m` leaves its var_inputs `start` and `stop` unconnected: connect each " <>
                 "to a global, a point or a constant, as in `m.start 0`",
               "line 2: `n` leaves its var_input `start` unconnected: connect it to a global, a " <>
                 "point or a constant, as in `n.start 0`",
               "line 4: `z` leaves its var_inputs `zeta` and `alpha` unconnected: connect each " <>
                 "to a global, a point or a constant, as in `z.zeta 0`"
             ]

      # A duplicate keeps no name, so only the instance that keeps it is told.
      assert errors("program m seal\nprogram m seal\n", %{"seal" => seal}) == [
               "line 1: `m` leaves its var_inputs `start` and `stop` unconnected: connect each " <>
                 "to a global, a point or a constant, as in `m.start 0`",
               "line 2: `m` is declared twice: first on line 1, as an instance"
             ]
    end

    # Lines come in any order a file gives them, and the problems in line order, each at
    # its own line; a message that names another element gives that element's line.
    test "each problem is cited at its line, in line order", %{seal: seal} do
      source = """
      m.start pb
      var_global pb bool at panel.i.0
      var_global k bool at panel.i.0
      program m seal
      m.start pb
      m.motor k
      var_global m2 bool
      program m2 seal
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 3: `k` is at `panel.i.0`, where `pb` already is (line 2): a location holds " <>
                 "one global",
               "line 4: `m` leaves its var_input `stop` unconnected: connect it to a global, a " <>
                 "point or a constant, as in `m.stop 0`",
               "line 5: `m.start` is already connected, to `pb` (line 1): a var_input has one " <>
                 "source",
               "line 6: `k` is an input point (line 3): `m.motor`, a var_output, cannot drive it",
               "line 8: `m2` is declared twice: first on line 7, as a global"
             ]
    end
  end

  describe "what a configuration file names (M2-2)" do
    # A keyword names nothing in a configuration file (§4.8): no global, instance or task
    # is named so, in any case, nor a program type; and no message advises declaring one.
    # From Elixir as from the text, where a line can say it.
    test "a configuration file's keyword names nothing, and nothing is told to declare one",
         %{seal: seal} do
      source = """
      var_global program bool
      program var_global seal
      program DINT seal
      program m At
      program n seal
      n.start bool
      n.stop 0
      n.motor Program
      program.start 0
      at.start 0
      """

      assert errors(source, %{"seal" => seal, "At" => %{seal | name: "At"}}) == [
               "line 1: `program` is a keyword and cannot name a global",
               "line 2: `var_global` is a keyword and cannot name an instance",
               "line 3: `DINT` is a keyword and cannot name an instance",
               "line 4: `At` is a keyword and cannot name a program type",
               "line 6: no global `bool`: `bool` is a keyword of a configuration file, and " <>
                 "nothing in one is named so",
               "line 8: no global `Program`: `Program` is a keyword of a configuration file, " <>
                 "and nothing in one is named so",
               "line 10: no instance `at`: `at` is a keyword of a configuration file, and " <>
                 "nothing in one is named so"
             ]

      fields =
        Keyword.merge(base(seal),
          tasks: [task("At", 10, 0)],
          globals: base(seal)[:globals] ++ [%Global{name: "bool", type: :bool}],
          instances: [
            %Instance{name: "m", type: "seal"},
            %Instance{name: "program", type: "seal"}
          ]
        )

      assert refused(fields) == [
               "`At` is a keyword and cannot name a task",
               "`bool` is a keyword and cannot name a global",
               "`program` is a keyword and cannot name an instance"
             ]
    end

    # Decision 42: a name refused for its `.` or as a keyword is refused once, at its
    # declaration, and nothing that names it is reported again, so a connection to it, an
    # instance of it, or a member of it is silent; nor is that instance's var_input
    # unconnected. A name M2-3's task lines will say is refused so from Elixir already.
    test "a name refused for its `.` or as a keyword is reported once, its uses silent",
         %{seal: seal} do
      source = """
      var_global a.b bool
      program program seal
      program m seal
      m.start a.b
      m.stop 0
      program.start 0
      m.motor a.b
      m.motor program.motor
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 1: `a.b` cannot name a global: `.` is kept for a path, as in `m1.start`, " <>
                 "and a location, as in `panel.i.0`",
               "line 2: `program` is a keyword and cannot name an instance"
             ]

      fields =
        Keyword.merge(base(seal),
          tasks: [task("u.v", 10, 0)],
          instances: [%Instance{name: "m", type: "seal", task: "u.v"}]
        )

      assert refused(fields) == [
               "`u.v` cannot name a task: `.` is kept for a path, as in `m1.start`, and a " <>
                 "location, as in `panel.i.0`"
             ]
    end

    # What a line that cannot be read names is declared by it: nothing that names it is
    # reported again, a broken connection connects its var_input, a later connection to
    # that var_input is no second source but has its own source checked, and a broken
    # `program` line is a program the configuration declares.
    test "a broken line declares what it names", %{seal: seal} do
      source = """
      var_global estop
      program m1 seal fast
      m1.start estop
      program m2 seal
      m2.start estop
      m2.stop
      m2.stop pbx
      m2.motor estop
      program m3 seal
      m3.start 0 1
      m3.stop 0
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 1, column 1: `estop` needs a type: `var_global estop bool` or " <>
                 "`var_global estop dint`",
               "line 2, column 17: unexpected `fast` after `program m1 seal`",
               "line 6, column 1: `m2.stop` needs a global or a constant to connect, as in " <>
                 "`m2.stop pb_start_1`",
               "line 7: no global `pbx`: declare it, as in `var_global pbx bool`",
               "line 10, column 12: unexpected `1` after `m3.start 0`"
             ]

      assert errors("program m1 seal )", %{"seal" => seal}) == [
               "line 1, column 17: a configuration line cannot hold `)`"
             ]

      # A line that names nothing declares nothing.
      assert errors("var_global dInT", %{"seal" => seal}) == [
               "line 1, column 12: `var_global` needs a name before `dInT`, as in " <>
                 "`var_global estop bool`",
               "this configuration declares no `program`: it would run nothing"
             ]

      # A broken line's name passes the name checks too: a keyword is refused as one.
      assert errors("program at seal x", %{"seal" => seal}) == [
               "line 1, column 17: unexpected `x` after `program at seal`",
               "line 1: `at` is a keyword and cannot name an instance"
             ]
    end

    # Each wrong reading of a dotted name is named (§4.7): a location is written only after
    # `at`, its advice in its one spelling, and one a global is at reads as that location
    # first, whatever its device is called; instances share a value only through a global;
    # and a member of what is no instance says what it is.
    test "a dotted name where a global or an instance is wanted is told its reading",
         %{seal: seal} do
      source = """
      var_global pb bool at panel.i.0
      var_global k1 bool at panel.q.0
      var_global g bool at m.i.1
      var_global sp dint
      program m seal
      program m2 seal
      m.start panel.i.0
      m.stop panel.I.0
      m2.start panel.i.9
      m2.stop m.i.1
      m2.motor m.q.0
      m.motor panel.q.00
      m.sp drive.q.4
      panel.q.0 1
      m2.sp pb.x
      m2.motor zz.y
      m.motor m_.motor
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 7: `panel.i.0` is a location, written only after `at` on a `var_global` " <>
                 "line: name the global at it, `pb` (line 1)",
               "line 8: `panel.I.0` is a location, written only after `at` on a `var_global` " <>
                 "line: name the global at it, `pb` (line 1)",
               "line 9: `panel.i.9` is a location, written only after `at` on a `var_global` " <>
                 "line: declare a global at it, as in `var_global point bool at panel.i.9`, and " <>
                 "name that",
               "line 10: `m.i.1` is a location, written only after `at` on a `var_global` " <>
                 "line: name the global at it, `g` (line 3)",
               "line 11: `m.q.0` is an instance's member: instances share a value only through " <>
                 "a global, which one drives and the other reads",
               "line 12: `panel.q.00` is a location, written only after `at` on a " <>
                 "`var_global` line: name the global at it, `k1` (line 2)",
               "line 13: `drive.q.4` is a location, written only after `at` on a `var_global` " <>
                 "line: declare a global at it, as in `var_global point dint at drive.q.4`, " <>
                 "and name that",
               "line 14: `panel.q.0` is a location, written only after `at` on a `var_global` " <>
                 "line: a connection begins with an instance's var_input or var_output, as in " <>
                 "`m1.start`",
               "line 15: `pb.x` names a member of `pb`, but `pb` is a global (line 1), not an " <>
                 "instance",
               "line 16: `zz.y` names a member of an instance, and there is no instance `zz`",
               "line 17: `m_.motor` names a member of an instance, and there is no instance " <>
                 "`m_` — did you mean `m`?"
             ]

      # From Elixir, the same readings in the same words.
      fields =
        Keyword.put(base(seal), :connections, [
          %Connection{instance: "m", member: "start", to: "panel.i.1"},
          %Connection{instance: "m", member: "stop", to: "panel.i.7"},
          %Connection{instance: "m", member: "motor", to: "m.sp"},
          %Connection{instance: "panel", member: "q.0", to: 1}
        ])

      assert refused(fields) == [
               "`panel.i.1` is a location, written only after `at` on a `var_global` line: " <>
                 "name the global at it, `pb2`",
               "`panel.i.7` is a location, written only after `at` on a `var_global` line: " <>
                 "declare a global at it, as in `var_global point bool at panel.i.7`, and name " <>
                 "that",
               "`m.sp` is an instance's member: instances share a value only through a global, " <>
                 "which one drives and the other reads",
               "`panel.q.0` is a location, written only after `at` on a `var_global` line: a " <>
                 "connection begins with an instance's var_input or var_output, as in `m1.start`"
             ]
    end

    test "a name of another kind where a global or an instance is wanted says what it is",
         %{seal: seal} do
      source = @base <> "program n seal\nn.start m\nn.stop 0\nk.start 0\n"

      assert errors(source, %{"seal" => seal}) == [
               "line 10: `m` is an instance (line 5), not a global",
               "line 12: `k` is a global (line 3), not an instance"
             ]

      fields =
        Keyword.merge(base(seal),
          tasks: [task("fast", 10, 0)],
          connections:
            base(seal)[:connections] ++ [%Connection{instance: "m", member: "sp", to: "fast"}]
        )

      assert refused(fields) == ["`fast` is a task, not a global"]
    end

    # One device under two spellings is likely one device mistyped, as two names that
    # differ only in case are; the first spelling, in line order, keeps the device.
    test "two device names that differ only in case are refused", %{seal: seal} do
      source = @base <> "var_global pb3 bool at Panel.i.2\nvar_global pb4 bool at panel.i.3\n"

      assert errors(source, %{"seal" => seal}) == [
               "line 9: the device `Panel` and the device `panel` of `pb` (line 1) differ only " <>
                 "in case: device names are case-sensitive, so these would be two devices"
             ]

      fields =
        Keyword.put(base(seal), :globals, [
          %Global{name: "pb", type: :bool, at: "panel.i.0"},
          %Global{name: "k", type: :bool, at: "PANEL.q.0"},
          %Global{name: "x", type: :bool, at: "Panel.i.0"}
        ])

      assert refused(fields) == [
               "the device `PANEL` and the device `panel` of `pb` differ only in case: device " <>
                 "names are case-sensitive, so these would be two devices",
               "the device `Panel` and the device `panel` of `pb` differ only in case: device " <>
                 "names are case-sensitive, so these would be two devices"
             ]
    end

    # One mistake, one message: a global refused for its name has its location checked,
    # but holds no address another global is then refused for.
    test "a refused global does not take its location", %{seal: seal} do
      source = """
      var_global a bool at panel.i.0
      var_global a bool at panel.i.1
      var_global b bool at panel.i.1
      var_global at bool at panel.i.2
      var_global c bool at panel.i.2
      var_global Program bool at rack.i.3
      var_global d bool at RACK.i.4
      program m seal
      m.start a
      m.stop b
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 2: `a` is declared twice: first on line 1, as a global",
               "line 4, column 12: `var_global` needs a name before `at`, as in " <>
                 "`var_global estop bool`",
               "line 6: `Program` is a keyword and cannot name a global"
             ]
    end
  end

  describe "a did-you-mean (M2-2)" do
    # A name, a program type and a member are case-sensitive, and a near one that differs
    # only in case says which it is.
    test "a case-only did-you-mean says what is case-sensitive", %{seal: seal} do
      source = """
      var_global Pb bool at panel.i.0
      program m2 seal
      m2.Start Pb
      m2.stop pb
      M2.start 0
      program m3 Seal
      """

      assert errors(source, %{"seal" => seal}) == [
               "line 2: `m2` leaves its var_input `start` unconnected: connect it to a global, " <>
                 "a point or a constant, as in `m2.start 0`",
               "line 3: `m2` is a `seal`, which declares no `Start` — did you mean `start`? " <>
                 "(members are case-sensitive)",
               "line 4: no global `pb` — did you mean `Pb`? (names are case-sensitive)",
               "line 5: no instance `M2` — did you mean `m2`? (names are case-sensitive)",
               "line 6: unknown program type `Seal` — did you mean `seal`? (program types are " <>
                 "case-sensitive)"
             ]
    end
  end

  describe "warnings (M2-2), which stop nothing" do
    # A use is a connection's source or sink. An output point nothing uses is unused only;
    # one that something reads and nothing drives stays at 0.
    test "a global nothing uses, and an output point something reads and nothing drives",
         %{seal: seal} do
      source =
        @base <>
          """
          var_global spare bool at panel.i.9
          var_global k3 bool at panel.q.3
          var_global k4 bool at panel.q.4
          var_global note dint 5
          program m2 seal
          m2.start k3
          m2.stop 0
          """

      assert warned(source, %{"seal" => seal}) == [
               "line 2: warning: `pb2` is declared but nothing uses it",
               "line 4: warning: `sp` is declared but nothing uses it",
               "line 9: warning: `spare` is declared but nothing uses it",
               "line 10: warning: `k3` is an output point, but nothing drives it: it stays at 0",
               "line 11: warning: `k4` is declared but nothing uses it",
               "line 12: warning: `note` is declared but nothing uses it"
             ]

      assert {:ok, %Configuration{warnings: [warning | _]}} = compiled(source, %{"seal" => seal})
      assert %Diagnostic{stage: :configure, severity: :warning, line: 2, file: nil} = warning

      # From Elixir, the same warnings, with no line.
      fields =
        Keyword.merge(base(seal),
          globals: base(seal)[:globals] ++ [%Global{name: "k3", type: :bool, at: "panel.q.3"}],
          instances: [%Instance{name: "m", type: "seal"}, %Instance{name: "m2", type: "seal"}],
          connections:
            base(seal)[:connections] ++
              [
                %Connection{instance: "m2", member: "start", to: "k3"},
                %Connection{instance: "m2", member: "stop", to: 0},
                %Connection{instance: "m2", member: "sp", to: "sp"}
              ]
        )

      assert %Configuration{warnings: warnings} = Configuration.new!(fields)

      assert Enum.map(warnings, &Diagnostic.format/1) == [
               "warning: `pb2` is declared but nothing uses it",
               "warning: `k3` is an output point, but nothing drives it: it stays at 0"
             ]
    end
  end

  describe "one message a rule (M2-2)" do
    # The same configuration from the text and from Elixir: each diagnostic in the same
    # words, but for the line a message cites, which an element from Elixir has none of.
    test "the elements a text reads, built in Elixir, meet the same checks in the same words" do
      source =
        @broken
        |> String.replace("task fast interval 10 priority 1\n", "")
        |> String.replace("progam m0 motor\n", "")
        |> String.replace(" with medium", "")

      {:ok, entries} = Configuration.Text.read(source)
      unlined = Enum.map(entries, &%{&1 | line: nil})

      fields = [
        name: "plant",
        programs: Map.values(plant_programs()),
        globals: for(%Global{} = g <- unlined, do: g),
        instances: for(%Instance{} = i <- unlined, do: i),
        connections: for(%Connection{} = c <- unlined, do: c)
      ]

      {:error, from_text} = compiled(source, plant_programs())
      assert length(from_text) == 5

      assert refused(fields) ==
               Enum.map(from_text, &String.replace(&1.message, ~r/ \(line \d+\)/, ""))
    end
  end

  describe "compile/3's host mistakes" do
    # What no configuration text holds is the host's, raised as check/1 raises it.
    test "a source that is not a binary, a name that is not one, programs that are not a " <>
           "map of programs",
         %{seal: seal} do
      assert_raise ArgumentError,
                   "Logex.Configuration.compile/3 takes source text as a binary, got: " <>
                     ~s(~c"program m seal"),
                   fn -> Configuration.compile("plant", opaque(~c"program m seal"), %{}) end

      for {name, message} <- [
            {nil, ~s|a configuration needs a name, as in name: "plant"|},
            {:plant,
             ":plant cannot name a configuration: a name is a letter or `_`, then letters, " <>
               "digits or `_`"},
            {"plant.logex",
             ~s|"plant.logex" cannot name a configuration: a name is a letter or `_`, then | <>
               "letters, digits or `_`"}
          ],
          do:
            assert_raise(ArgumentError, message, fn ->
              Configuration.compile(opaque(name), "program m seal", %{"seal" => seal})
            end)

      for {programs, message} <- [
            {[seal],
             "programs must be a map of program names to %Logex.Program{}, got a list: " <>
               "Logex.Configuration.new!/1 takes a list and keys it by name"},
            {:seal, "programs must be a map of program names to %Logex.Program{}, got: :seal"},
            {%{"motor" => seal}, "the program under `motor` is named `seal`"},
            {%{"ton" => Logex.FbType.ton()},
             "`ton` is a function block type, which runs inside a program: an instance is of " <>
               "a %Logex.Program{}"}
          ],
          do:
            assert_raise(ArgumentError, message, fn ->
              Configuration.compile("plant", "program m seal", opaque(programs))
            end)

      # Every mistake, a line each, the name's first; and before the source is read.
      assert_raise ArgumentError,
                   ~s|"a b" cannot name a configuration: a name is a letter or `_`, then | <>
                     "letters, digits or `_`\nprograms must be a map of program names to " <>
                     "%Logex.Program{}, got: 7",
                   fn -> Configuration.compile("a b", "%", opaque(7)) end
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

    # A host's list is never trusted to be proper (decision 36): an improper one, in any
    # part or as the keyword list itself, is refused like any other value that is not a
    # list.
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
               "`y.z` cannot name an instance: `.` is kept for a path, as in `m1.start`, and a " <>
                 "location, as in `panel.i.0`",
               "no instance `q`: declare it, as in `program q motor`"
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
