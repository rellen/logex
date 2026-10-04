defmodule Logex.Configuration.TextTest do
  @moduledoc """
  `Logex.Configuration.Text` (M2-2): a configuration file read into the elements of a
  `%Logex.Configuration{}`, each with its line, every line it cannot read a diagnostic at
  its token, as whole lists from source; what a line can say, `entries!/1`; and the
  printer, whose text reads back to the very entries it printed.

  Nothing here checks what the words mean, which is `Logex.Configuration.check/1`'s
  (`configuration_test.exs`).
  """
  use ExUnit.Case, async: true

  alias Logex.Configuration.{Connection, Global, Instance, Text}
  alias Logex.Diagnostic

  # `docs/organisation.md` §4.4's plant, cut from the document, so the decided example and
  # the reader cannot drift apart.
  defp plant do
    [_before, rest] =
      String.split(File.read!("docs/organisation.md"), "```\n// plant.", parts: 2)

    [block, _after] = String.split("// plant." <> rest, "```", parts: 2)
    block
  end

  # The plant in M2-2's words: its task lines and each `with` blanked, so every line keeps
  # its number.
  defp taskless(source) do
    source
    |> String.replace(~r/^task .*$/m, "")
    |> String.replace(~r/ with \w+$/m, "")
  end

  defp errors(source) do
    {:error, diagnostics, _entries} = Text.read(source)
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  defp global(line, name, type, at \\ nil),
    do: %Global{name: name, type: type, at: at, line: line}

  defp instance(line, name, type), do: %Instance{name: name, type: type, line: line}

  defp wire(line, instance, member, to),
    do: %Connection{instance: instance, member: member, to: to, line: line}

  defp unsaid(rule, entry),
    do: "not an entry a configuration file can say: #{rule}, got: #{inspect(entry)}"

  describe "reading (M2-2): the elements of a configuration, each with its line" do
    test "§4.4's plant, its task lines and `with`s blanked, reads to its globals, instances " <>
           "and connections" do
      globals =
        for {name, line, type, at} <- [
              {"estop", 6, :bool, "panel.i.7"},
              {"pb_start_1", 7, :bool, "panel.i.0"},
              {"pb_stop_1", 8, :bool, "panel.i.1"},
              {"tt_1", 9, :bool, "panel.i.2"},
              {"pb_start_2", 10, :bool, "panel.i.3"},
              {"pb_stop_2", 11, :bool, "panel.i.4"},
              {"tt_2", 12, :bool, "panel.i.5"},
              {"pb_reset", 13, :bool, "panel.i.6"},
              {"k1", 14, :bool, "panel.q.0"},
              {"k2", 15, :bool, "panel.q.1"},
              {"lamp_1", 16, :bool, "panel.q.2"},
              {"lamp_2", 17, :bool, "panel.q.3"},
              {"sp_1", 18, :dint, "drive.q.0"},
              {"sp_2", 19, :dint, "drive.q.1"},
              {"k1_at_trip", 20, :bool, nil},
              {"k2_at_trip", 21, :bool, nil}
            ],
            do: global(line, name, type, at)

      assert Text.read(taskless(plant())) ==
               {:ok,
                globals ++
                  [
                    instance(23, "m1", "motor"),
                    wire(24, "m1", "start", "pb_start_1"),
                    wire(25, "m1", "stop", "pb_stop_1"),
                    wire(26, "m1", "overtemp", "tt_1"),
                    wire(27, "m1", "reset", "pb_reset"),
                    wire(28, "m1", "motor", "k1"),
                    wire(29, "m1", "run_lamp", "lamp_1"),
                    wire(30, "m1", "speed_sp", "sp_1"),
                    instance(32, "m2", "motor"),
                    wire(33, "m2", "start", "pb_start_2"),
                    wire(34, "m2", "stop", "pb_stop_2"),
                    wire(35, "m2", "overtemp", "tt_2"),
                    wire(36, "m2", "reset", 0),
                    wire(37, "m2", "motor", "k2"),
                    wire(38, "m2", "run_lamp", "lamp_2"),
                    wire(39, "m2", "speed_sp", "sp_2"),
                    instance(41, "snap", "snapshot"),
                    wire(42, "snap", "a", "k1"),
                    wire(43, "snap", "b", "k2"),
                    wire(44, "snap", "a_was", "k1_at_trip"),
                    wire(45, "snap", "b_was", "k2_at_trip")
                  ]}
    end

    test "§4.4's plant as written is refused only where it names a task: a later item's " <>
           "words are not read, and no message offers them" do
      assert errors(plant()) ==
               (for line <- 2..4 do
                  "line #{line}, column 1: unknown configuration line `task`: a line starts " <>
                    "with `var_global` or `program`, or is a connection, as in " <>
                    "`m1.start pb_start_1`"
                end) ++
                 [
                   "line 23, column 18: unexpected `with` after `program m1 motor`",
                   "line 32, column 18: unexpected `with` after `program m2 motor`",
                   "line 41, column 23: unexpected `with` after `program snap snapshot`"
                 ]
    end

    test "keywords are matched in any case, and names are not folded" do
      assert Text.read("VAR_GLOBAL K1 DINT 7\nVar_Global Pb Bool At Panel.i.0\nPROGRAM M1 Motor") ==
               {:ok,
                [
                  %Global{name: "K1", type: :dint, initial: 7, line: 1},
                  global(2, "Pb", :bool, "Panel.i.0"),
                  instance(3, "M1", "Motor")
                ]}
    end

    test "a line ends at LF, CRLF or a lone CR and keeps its number, and a comment is not read" do
      {:ok, entries} = Text.read(taskless(plant()))
      assert Text.read(String.replace(taskless(plant()), "\n", "\r\n")) == {:ok, entries}
      assert Text.read(String.replace(taskless(plant()), "\n", "\r")) == {:ok, entries}

      assert Text.read("// a plant\n\nvar_global k bool // the contactor\n  // nothing\nm1.x k") ==
               {:ok, [global(3, "k", :bool), wire(5, "m1", "x", "k")]}
    end

    test "a lex error stops the read and is the only diagnostic" do
      assert Text.read("program m1 motor\nvar_global a bool at %ix0.0\nm1.zz 7x") ==
               {:error,
                [
                  %Diagnostic{
                    stage: :lex,
                    line: 2,
                    column: 22,
                    message: ~s(illegal character "%")
                  }
                ], []}
    end

    test "a source with no line reads to no entry" do
      assert Text.read("") == {:ok, []}
      assert Text.read("\n// nothing\r\n\r") == {:ok, []}
    end
  end

  describe "a line's grammar, each mistake a :configure diagnostic at its token" do
    test "a line starts with `var_global` or `program`, or is a connection" do
      assert errors("progam m1 motor\nvar_globl x bool\nzzz m1 motor\n5 m1\nm1 start pb") == [
               "line 1, column 1: unknown configuration line `progam` — did you mean `program`?",
               "line 2, column 1: unknown configuration line `var_globl` — did you mean " <>
                 "`var_global`?",
               "line 3, column 1: unknown configuration line `zzz`: a line starts with " <>
                 "`var_global` or `program`, or is a connection, as in `m1.start pb_start_1`",
               "line 4, column 1: unknown configuration line `5`: a line starts with " <>
                 "`var_global` or `program`, or is a connection, as in `m1.start pb_start_1`",
               "line 5, column 1: unknown configuration line `m1`: a line starts with " <>
                 "`var_global` or `program`, or is a connection, as in `m1.start pb_start_1`"
             ]

      assert %Diagnostic{stage: :configure, line: 1, column: 1, file: nil} =
               hd(elem(Text.read("progam m1 motor"), 1))
    end

    test "`at`, `bool` and `dint` belong on a `var_global` line, and cannot start one" do
      assert errors("at panel.i.0\nbool x\nDINT y 5") ==
               for(
                 {word, line} <- [{"at", 1}, {"bool", 2}, {"DINT", 3}],
                 do:
                   "line #{line}, column 1: a line cannot start with `#{word}`: it goes on a " <>
                     "`var_global` line, as in `var_global k1 bool at panel.q.0`"
               )
    end

    test "a branch delimiter has no place in a configuration" do
      assert errors("( var_global a bool )\nvar_global b bool | c\nprogram m1 motor )") == [
               "line 1, column 1: a configuration line cannot hold `(`",
               "line 2, column 19: a configuration line cannot hold `|`",
               "line 3, column 18: a configuration line cannot hold `)`"
             ]
    end

    test "a global line: a name, a type, then an initial value, a location, or both" do
      source = """
      var_global
      var_global 5 bool
      var_global bool
      var_global At dint
      var_global estop
      var_global e2 1
      var_global k1 at panel.q.0
      var_global x boolean
      var_global t1 TON
      var_global y dint at
      var_global z bool at 5
      var_global w bool 1 2
      var_global v bool at panel.q.4 x
      var_global u bool at panel.q.5 at panel.q.6
      var_global s dint DInt
      """

      assert errors(source) == [
               "line 1, column 1: `var_global` needs a name and a type, as in " <>
                 "`var_global estop bool`",
               "line 2, column 12: expected a global's name after `var_global`, found `5`",
               "line 3, column 12: `var_global` needs a name before `bool`, as in " <>
                 "`var_global estop bool`",
               "line 4, column 12: `var_global` needs a name before `At`, as in " <>
                 "`var_global estop bool`",
               "line 5, column 1: `estop` needs a type: `var_global estop bool` or " <>
                 "`var_global estop dint`",
               "line 6, column 15: `e2` needs a type before its initial value `1`",
               "line 7, column 15: `k1` needs a type before `at`, as in " <>
                 "`var_global k1 bool at panel.q.0`",
               "line 8, column 14: unknown type `boolean`: a global is a `bool` or a `dint` " <>
                 "— did you mean `bool`?",
               "line 9, column 15: `t1` cannot be a `ton`: a global is a `bool` or a `dint`, " <>
                 "and a ton is declared inside a program, as in `var t1 ton`",
               "line 10, column 19: `at` needs a location, as in `at panel.i.0`",
               "line 11, column 22: `at` needs a location, as in `at panel.i.0`, found `5`",
               "line 12, column 21: unexpected `2` after the declaration of `w`",
               "line 13, column 32: unexpected `x` after the declaration of `v`",
               "line 14, column 32: unexpected `at` after the declaration of `u`",
               "line 15, column 19: unexpected `DInt` after the declaration of `s`"
             ]

      # Both an initial value and a location read: what they mean together is the
      # validator's to refuse, not the grammar's.
      assert Text.read("var_global g bool 1 at panel.q.0\nvar_global h dint 0") ==
               {:ok,
                [
                  %Global{name: "g", type: :bool, initial: 1, at: "panel.q.0", line: 1},
                  %Global{name: "h", type: :dint, initial: 0, line: 2}
                ]}
    end

    test "a program line: an instance and its program type, and nothing after" do
      source = """
      program
      program 5 motor
      program m3
      program m4 7
      program m5 motor fast
      program m6 motor 3
      program m7 motor with fast
      """

      assert errors(source) == [
               "line 1, column 1: `program` needs an instance name and a program type, as in " <>
                 "`program m1 motor`",
               "line 2, column 9: expected an instance name after `program`, found `5`",
               "line 3, column 1: `program m3` needs a program type, as in `program m3 motor`",
               "line 4, column 12: expected a program type after `program m4`, found `7`",
               "line 5, column 18: unexpected `fast` after `program m5 motor`",
               "line 6, column 18: unexpected `3` after `program m6 motor`",
               "line 7, column 18: unexpected `with` after `program m7 motor`"
             ]

      # The type is whatever word stands third; a program type is named only there.
      assert Text.read("program motor motor\nprogram at bool") ==
               {:ok, [instance(1, "motor", "motor"), instance(2, "at", "bool")]}
    end

    test "a connection line: a path, then one global or constant" do
      assert errors("m1.motor\nm1.run_lamp k1 k2\nm1.stop 0 1") == [
               "line 1, column 1: `m1.motor` needs a global or a constant to connect, as in " <>
                 "`m1.motor pb_start_1`",
               "line 2, column 16: unexpected `k2` after `m1.run_lamp k1`",
               "line 3, column 11: unexpected `1` after `m1.stop 0`"
             ]

      # The path is split at its first `.`: whatever follows is the member, as the text
      # says it, for the validator to judge.
      assert Text.read("m1.t1.pre 5\nm1.0 k\nprogram.at bool") ==
               {:ok,
                [
                  wire(1, "m1", "t1.pre", 5),
                  wire(2, "m1", "0", "k"),
                  wire(3, "program", "at", "bool")
                ]}
    end

    test "a broken line still names what its words name: a placeholder for each" do
      source = """
      var_global a bool
      var_global estop
      var_global b real
      var_global c bool at
      program m1
      program m2 motor fast
      m1.start
      m1.stop 0 1
      var_global
      program
      program m3 motor
      """

      assert {:error, diagnostics, entries} = Text.read(source)
      assert Enum.map(diagnostics, & &1.line) == [2, 3, 4, 5, 6, 7, 8, 9, 10]

      assert entries == [
               global(1, "a", :bool),
               {:declared, 2, %{kind: :global, name: "estop"}},
               {:declared, 3, %{kind: :global, name: "b"}},
               {:declared, 4, %{kind: :global, name: "c"}},
               {:declared, 5, %{kind: :instance, name: "m1"}},
               {:declared, 6, %{kind: :instance, name: "m2"}},
               {:declared, 7, %{kind: :connection, instance: "m1", member: "start"}},
               {:declared, 8, %{kind: :connection, instance: "m1", member: "stop"}},
               instance(11, "m3", "motor")
             ]
    end

    test "a line broken by a delimiter declares what its words before it name" do
      source = """
      var_global g bool )
      program m1 motor ( x
      m2.start ( g
      var_global ( h bool
      ( program m4 motor
      """

      assert {:error, diagnostics, entries} = Text.read(source)

      assert Enum.map(diagnostics, &Diagnostic.format/1) == [
               "line 1, column 19: a configuration line cannot hold `)`",
               "line 2, column 18: a configuration line cannot hold `(`",
               "line 3, column 10: a configuration line cannot hold `(`",
               "line 4, column 12: a configuration line cannot hold `(`",
               "line 5, column 1: a configuration line cannot hold `(`"
             ]

      # The delimiter is the line's one diagnostic: what its words before it say is read
      # only for what they name, a line that names nothing before it names nothing.
      assert entries == [
               {:declared, 1, %{kind: :global, name: "g"}},
               {:declared, 2, %{kind: :instance, name: "m1"}},
               {:declared, 3, %{kind: :connection, instance: "m2", member: "start"}}
             ]
    end
  end

  describe "printing, and what a line can say" do
    test "print/1 writes each entry in one canonical form, on its own line when it has one" do
      entries = [
        %Global{name: "k1", type: :bool, at: "panel.q.0"},
        %Global{name: "sp", type: :dint, initial: 1200},
        %Global{name: "g", type: :bool, initial: 1, at: "panel.q.1"},
        %Instance{name: "m1", type: "motor"},
        %Connection{instance: "m1", member: "start", to: "k1"},
        %Connection{instance: "m1", member: "t1.pre", to: 0}
      ]

      text = """
      var_global k1 bool at panel.q.0
      var_global sp dint 1200
      var_global g bool 1 at panel.q.1
      program m1 motor
      m1.start k1
      m1.t1.pre 0
      """

      assert Text.print(entries) == text
      assert Text.print([]) == ""

      # With no line, from Elixir, on lines 1, 2, 3 and on; read back, each has that line.
      assert Text.read(text) ==
               {:ok, Enum.with_index(entries, 1) |> Enum.map(fn {e, l} -> %{e | line: l} end)}

      # With lines, as a file gives them, each on its own line and the lines between left
      # empty, so the text reads back to the very entries.
      {:ok, lined} =
        Text.read("\n\nVAR_GLOBAL  K  BOOL  AT panel.i.0 // a button\n\n\nProgram M x")

      assert Text.print(lined) == "\n\nvar_global K bool at panel.i.0\n\n\nprogram M x\n"
      assert Text.read(Text.print(lined)) == {:ok, lined}
    end

    test "an entry no line can say raises ArgumentError, from entries!/1 and print/1 alike" do
      a = %Global{name: "a", type: :bool}
      m1 = %Instance{name: "m1", type: "motor"}
      start = %Connection{instance: "m1", member: "start", to: 0}

      for {entry, rule} <- [
            {%Logex.Configuration.Task{name: "t", interval: 10, priority: 1},
             "an entry is a %Logex.Configuration.Global{}, %Logex.Configuration.Instance{} " <>
               "or %Logex.Configuration.Connection{}, with its struct's keys"},
            {{:declared, 1, %{kind: :global, name: "a"}},
             "an entry is a %Logex.Configuration.Global{}, %Logex.Configuration.Instance{} " <>
               "or %Logex.Configuration.Connection{}, with its struct's keys"},
            {Map.delete(a, :at),
             "an entry is a %Logex.Configuration.Global{}, %Logex.Configuration.Instance{} " <>
               "or %Logex.Configuration.Connection{}, with its struct's keys"},
            {Map.put(m1, :note, "x"),
             "an entry is a %Logex.Configuration.Global{}, %Logex.Configuration.Instance{} " <>
               "or %Logex.Configuration.Connection{}, with its struct's keys"},
            {%{a | line: 0}, "a line is a positive integer, or nil for an entry built in Elixir"},
            {%{start | line: 1.0},
             "a line is a positive integer, or nil for an entry built in Elixir"},
            {%{a | name: "a b"}, "a name lexes as one name token"},
            {%{a | name: :a}, "a name lexes as one name token"},
            {%{a | at: "%ix0.0"}, "a name lexes as one name token"},
            {%{a | type: :real}, "a global's type is :bool or :dint"},
            {%{a | initial: -1},
             "a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)"},
            {%{a | initial: 1.0},
             "a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)"},
            {%{m1 | type: "a b"}, "a name lexes as one name token"},
            {%{m1 | task: "fast"},
             "a `program` line names an instance and its program type, and no task, so an " <>
               "instance's task is nil"},
            {%{start | instance: "m1.x"},
             "a connection's instance has no `.`: its first `.` begins the member"},
            {%{start | member: "start."}, "a name lexes as one name token"},
            {%{start | member: ""}, "a name lexes as one name token"},
            {%{start | member: :start}, "a name lexes as one name token"},
            {%{start | to: "x y"}, "a name lexes as one name token"},
            {%{start | to: -1},
             "a number is an integer, 0 or more: a negative one does not lex yet (PLAN.md §5)"},
            {%{start | to: {:global, "g"}},
             "a connection is to a global, by its name, or to a constant"},
            # A keyword a line reads in a global's name place: no line can say these.
            {%{a | name: "AT"},
             "a global's name is not `at`, `bool` or `dint`, in any case: a line reads that " <>
               "word as its keyword"},
            {%{a | name: "bool"},
             "a global's name is not `at`, `bool` or `dint`, in any case: a line reads that " <>
               "word as its keyword"},
            {%{a | name: "Dint"},
             "a global's name is not `at`, `bool` or `dint`, in any case: a line reads that " <>
               "word as its keyword"}
          ] do
        assert_raise ArgumentError, unsaid(rule, entry), fn -> Text.entries!([m1, entry]) end
        assert_raise ArgumentError, unsaid(rule, entry), fn -> Text.print([entry]) end
      end

      # And what a line can say is taken, the words of other places among it.
      said = [
        %Global{name: "program", type: :dint, initial: 0, at: "at"},
        %Global{name: "var_global", type: :bool, at: "panel.i.0"},
        %Instance{name: "at", type: "bool"},
        %Connection{instance: "bool", member: "at.0", to: "dint"}
      ]

      assert Text.entries!(said) == said
      assert Text.read(Text.print(said)) == {:ok, Enum.map(Enum.with_index(said, 1), &lined/1)}
    end

    test "lines are nil from Elixir, or rise one entry a line, as the text gives them" do
      m = fn name, line -> %Instance{name: name, type: "motor", line: line} end

      for {entries, bad, rule} <- [
            {[m.("m1", 1), m.("m2", 1)], m.("m2", 1), ", and this one comes after line 1"},
            {[m.("m1", 9), m.("m2", 4)], m.("m2", 4), ", and this one comes after line 9"},
            {[m.("m1", 3), m.("m2", nil)], m.("m2", nil), ", and this one comes after line 3"},
            {[m.("m1", nil), m.("m2", 3)], m.("m1", nil),
             ", and no line is nil beside one that is not"}
          ] do
        message =
          unsaid(
            "lines are nil for entries built in Elixir, or rise from entry to entry, one " <>
              "entry a line#{rule}",
            bad
          )

        assert_raise ArgumentError, message, fn -> Text.entries!(entries) end
        assert_raise ArgumentError, message, fn -> Text.print(entries) end
      end

      assert Text.entries!([m.("m1", nil), m.("m2", nil)]) == [m.("m1", nil), m.("m2", nil)]
      assert Text.entries!([m.("m1", 2), m.("m2", 7)]) == [m.("m1", 2), m.("m2", 7)]
    end

    test "every entry entries!/1 takes prints to text that reads back to it, keywords included" do
      :rand.seed(:exsss, {41, 42, 43})
      words = Text.keywords() ++ Enum.map(Text.keywords(), &String.capitalize/1)
      names = words ++ ["m1", "fast", "g", "Panel", "x_1", "panel.i.0", "a.b"]

      results =
        for _ <- 1..3000 do
          entries = for _ <- 1..Enum.random(1..3), do: any_entry(names)

          try do
            assert Text.entries!(entries) == entries
            numbered = Enum.map(Enum.with_index(entries, 1), &lined/1)
            assert Text.read(Text.print(entries)) == {:ok, numbered}
            assert Text.read(Text.print(numbered)) == {:ok, numbered}
            :taken
          rescue
            ArgumentError -> :refused
          end
        end

      # Both halves are reached: the property is not vacuous.
      assert :taken in results and :refused in results
    end

    test "everything read/1 reads, entries!/1 takes, and it prints back to the same text's " <>
           "entries" do
      # Every line of one to four words from a small vocabulary, M2-2's words and a later
      # item's among them: read/1 never raises, and what it reads is what a line can say.
      vocabulary = ~w(var_global program AT bool dint with x m1.a panel.i.0 5 \()

      sources =
        for n <- 1..4,
            words <- words(vocabulary, n),
            do: Enum.join(words, " ")

      read =
        for source <- sources, reduce: 0 do
          count ->
            read_back(Text.read(source), source, count)
        end

      assert read > 100
    end
  end

  describe "host mistakes" do
    test "every public function of the text refuses a host mistake with ArgumentError" do
      improper = [%Global{name: "a", type: :bool} | :x]

      for {call, message} <- [
            {fn -> Text.read(:plant) end,
             "Logex.Configuration.Text.read/1 takes source text as a binary, got: :plant"},
            {fn -> Text.read(~c"program m1 motor") end,
             "Logex.Configuration.Text.read/1 takes source text as a binary, got: " <>
               ~s(~c"program m1 motor")},
            {fn -> Text.print(:entries) end,
             "Logex.Configuration.Text.print/1 takes a %Logex.Configuration{} or a list of " <>
               "entries, got: :entries"},
            {fn -> Text.entries!(%{}) end, "entries must be a list, got: %{}"},
            {fn -> Text.print(improper) end, "entries must be a list, got: #{inspect(improper)}"},
            {fn -> Text.entries!(improper) end,
             "entries must be a list, got: #{inspect(improper)}"}
          ] do
        assert_raise ArgumentError, message, call
      end
    end

    test "nothing but ArgumentError escapes entries!/1 or print/1, whatever they are given" do
      :rand.seed(:exsss, {29, 30, 31})

      for _ <- 1..2000, call <- [&Text.entries!/1, &Text.print/1] do
        given =
          case Enum.random(1..3) do
            1 -> for _ <- 1..Enum.random(0..3)//1, do: junk_entry()
            2 -> junk()
            3 -> [junk_entry() | junk()]
          end

        try do
          call.(given)
        rescue
          ArgumentError -> :refused
        end
      end
    end
  end

  describe "reserved words, by file kind (§4.8, decision 10)" do
    test "a configuration file's words are read as its keywords, in any case, where a line " <>
           "reads them" do
      for word <- ["at", "bool", "dint"], shown <- [word, String.upcase(word)] do
        assert [_] = errors("var_global #{shown} dint"), "#{shown} was taken as a global's name"
      end

      for word <- ["var_global", "program"], shown <- [word, String.upcase(word)] do
        assert {:ok, [_]} = Text.read("#{shown} x bool"),
               "#{shown} did not start its line"
      end
    end

    test "and none is reserved in a program" do
      for word <- Text.keywords() -- ["bool", "dint"] do
        assert {:ok, _} = Logex.compile("var #{word} bool\nxic #{word} ote #{word}", name: "p")
      end
    end
  end

  # An entry of every kind, from `names`: some a line can say, and some it cannot.
  defp any_entry(names) do
    pick = fn -> Enum.random(names) end

    case Enum.random(1..3) do
      1 ->
        %Global{
          name: pick.(),
          type: Enum.random([:bool, :dint]),
          initial: Enum.random([nil, 0, 7]),
          at: Enum.random([nil, pick.(), "panel.i.0"])
        }

      2 ->
        %Instance{name: pick.(), type: pick.(), task: Enum.random([nil, nil, nil, "fast"])}

      3 ->
        %Connection{
          instance: pick.(),
          member: Enum.random([pick.(), "0", "t1.pre"]),
          to: Enum.random([pick.(), 0, 1200])
        }
    end
  end

  defp lined({entry, line}), do: %{entry | line: line}

  defp words(_vocabulary, 0), do: [[]]

  defp words(vocabulary, n),
    do: for(word <- vocabulary, rest <- words(vocabulary, n - 1), do: [word | rest])

  defp read_back({:ok, entries}, source, count) do
    assert Text.entries!(entries) == entries, source
    assert Text.read(Text.print(entries)) == {:ok, entries}, source
    count + 1
  end

  defp read_back({:error, [%Diagnostic{} | _], entries}, source, count) do
    said = Enum.reject(entries, &match?({:declared, _, _}, &1))
    assert Text.read(Text.print(said)) == {:ok, said}, source
    count
  end

  # Junk for the totality test: any term, and terms shaped almost like entries.
  defp junk,
    do:
      Enum.random([
        nil,
        0,
        -1,
        1.5,
        :a,
        "",
        "m1",
        "a b",
        "AT",
        "x.y",
        "panel.i.0",
        <<255>>,
        [],
        %{},
        [:a | :b],
        {:x}
      ])

  defp junk_entry do
    case Enum.random(1..8) do
      1 ->
        %Global{
          name: junk(),
          type: Enum.random([:bool, :dint, junk()]),
          initial: junk(),
          at: junk(),
          line: Enum.random([nil, 1, 0, junk()])
        }

      2 ->
        %Instance{name: junk(), type: junk(), task: junk(), line: Enum.random([nil, 2, junk()])}

      3 ->
        %Connection{
          instance: Enum.random(["m1", junk()]),
          member: junk(),
          to: junk(),
          line: Enum.random([nil, 3])
        }

      4 ->
        %Logex.Configuration.Task{name: "t", interval: 1, priority: 1}

      5 ->
        Map.delete(%Global{name: "a", type: :bool}, Enum.random([:name, :type, :at, :line]))

      6 ->
        %{__struct__: Enum.random([Global, "x", :nope]), line: 1}

      7 ->
        junk()

      8 ->
        {:declared, 1, %{kind: :global, name: "a"}}
    end
  end
end
