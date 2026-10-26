defmodule Logex.EndToEndTest do
  @moduledoc """
  Drives ladder source all the way to an environment.

  When it was written, every other test in this suite hand-typed the input to a
  single stage, so a mismatch at a stage boundary was invisible to all of them —
  which is how the `:lit_int` / `:int_lit` transposition survived six commits
  (`0f7d77f` through `6dbbdd7`) with a green suite. The *assertions* here name no IR tag:
  they can only be satisfied by the stages actually agreeing with each other.
  One helper, `rung_count/1`, matches the `{:routine, {:rungs, _}}` wrapper —
  that is the only AST shape in the file.
  """
  use ExUnit.Case

  # M3-2: logex's own type words, as an unknown type's message lists them: the elementary
  # types, then every built-in function block type, each set in order.
  @has "logex has `bool`, `sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, " <>
         "`real`, `lreal`, `byte`, `word`, `dword`, `lword`, " <>
         "`ctd`, `ctd_dint`, `ctd_int`, `ctd_lint`, `ctd_udint`, `ctd_ulint`, " <>
         "`ctu`, `ctu_dint`, `ctu_int`, `ctu_lint`, `ctu_udint`, `ctu_ulint`, " <>
         "`ctud`, `ctud_dint`, `ctud_int`, `ctud_lint`, `ctud_udint`, `ctud_ulint`, " <>
         "`rto`, `rto_ltime`, `tof`, `tof_ltime`, `ton`, `ton_ltime`, `tp` and `tp_ltime`"

  defp run(src, env) do
    {:ok, program} = compile(src)
    env_after(program, env)
  end

  defp compile(src), do: Logex.compile(src, name: "t")

  # One scan through the public API, from an env the test chooses: an instance built by
  # hand, which Logex.Runtime runs refusing any value outside its tag's type, an integer
  # outside its range (decision 171) or a value that is no integer (decision 173).
  defp env_after(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: true}
    {_outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 0, first: true})
    state.env
  end

  defp rung_count(src) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(src)
    {:ok, {:routine, {:rungs, rungs}}} = Logex.Compiler.parse(tokens)
    length(rungs)
  end

  defp parse_error?(src) do
    {:ok, tokens, _} = Logex.Compiler.tokenize(src)
    match?({:error, _}, Logex.Compiler.parse(tokens))
  end

  # Declaration lines for a test's tags: `var <name> bool` for each bool, then
  # `var <name> dint` for each dint. Real source, so every test still crosses every stage.
  defp decl(bools, dints \\ []),
    do: Enum.map_join(bools, &"var #{&1} bool\n") <> Enum.map_join(dints, &"var #{&1} dint\n")

  defp lex_error?(src), do: match?({:error, _, _}, Logex.Compiler.tokenize(src))

  describe "integer literals" do
    test "move of a literal writes the literal" do
      assert %{"dd" => 123} = run(decl([], ~w(dd)) <> "move 123 dd", %{"dd" => 0})
    end

    test "move of a tag copies the tag" do
      assert %{"dd" => 7} = run(decl([], ~w(aa dd)) <> "move aa dd", %{"aa" => 7})
    end

    test "the showcase routine from lex_and_parse_test.exs" do
      src =
        decl(~w(xx yy), ~w(aa bb cc dd ee ff hh)) <>
          "( move aa bb | move cc dd | move ee ff ( move 123 hh ) ) " <>
          "( ote xx | ote yy )"

      assert %{
               "aa" => 1,
               "bb" => 1,
               "cc" => 2,
               "dd" => 2,
               "ee" => 3,
               "ff" => 3,
               "hh" => 123,
               "xx" => 1,
               "yy" => 1
             } = run(src, %{"aa" => 1, "cc" => 2, "ee" => 3})
    end
  end

  describe "rungs" do
    test "each rung starts with its own power flow" do
      assert %{"r1" => 0, "r2" => 1} =
               run(decl(~w(gg r1 r2)) <> "xic gg ote r1\note r2", %{"gg" => 0, "r1" => 1})
    end

    test "a trailing newline is not a syntax error" do
      assert %{"xx" => 1} = run(decl(~w(xx)) <> "ote xx\n", %{})
    end

    test "leading, repeated and CRLF newlines are all one delimiter" do
      assert %{"xx" => 1} = run(decl(~w(xx)) <> "\note xx", %{})
      assert %{"xx" => 1, "yy" => 1} = run(decl(~w(xx yy)) <> "ote xx\n\n\note yy\n", %{})
      assert %{"xx" => 1, "yy" => 1} = run(decl(~w(xx yy)) <> "ote xx\r\note yy\r\n", %{})
      assert %{"xx" => 1, "yy" => 1} = run(decl(~w(xx yy)) <> "  ote xx  \n\n  ote yy\n", %{})
    end

    # B8: a lone CR was whitespace, so a file with classic-Mac line endings was one rung,
    # and `r2` read the first rung's power flow instead of starting its own.
    test "a lone CR ends a rung, as LF and CRLF do" do
      for newline <- ["\n", "\r\n", "\r"] do
        source = decl(~w(gg r1 r2)) <> "xic gg ote r1" <> newline <> "ote r2"
        assert %{"r1" => 0, "r2" => 1} = run(source, %{"gg" => 0}), inspect(newline)
      end

      assert 2 = rung_count("ote xx\rote yy")
    end

    test "a comment ends at the end of its line, not of the rung, and never runs" do
      source = decl(~w(gg r1 r2)) <> "// seal-in\nxic gg ote r1 // not ote r2\note r2"
      assert %{"r1" => 0, "r2" => 1} = run(source, %{"gg" => 0, "r2" => 0})
      assert %{"r2" => 0} = run(decl(~w(r1 r2)) <> "ote r1 // ote r2", %{"r2" => 0})

      declared = "var_input gg bool // the start button\nvar r1 bool\nxic gg ote r1"
      assert %{"r1" => 1} = run(declared, %{"gg" => 1})
    end

    test "blank lines do not become empty rungs" do
      assert 1 = rung_count("ote xx\n")
      assert 1 = rung_count("\note xx")
      assert 2 = rung_count("ote xx\n\n\note yy\n")
      assert 0 = rung_count("")
      assert 0 = rung_count("\n\n\n")
    end

    test "an empty program is a legal no-op, not a parse error" do
      assert %{"aa" => 1} = run("", %{"aa" => 1})
    end
  end

  describe "branches" do
    test "a later leg sees what an earlier leg wrote" do
      # PLAN.md §6 keeps the sequential `env` threading in the {:branches, _}
      # reducer deliberately: it looks like an accident of using Enum.reduce and
      # is faithful controller behaviour. The natural "parallel legs are
      # independent" refactor — evaluating each leg against the incoming env and
      # merging — flips this case to mm=1, zz=1 and is otherwise invisible.
      assert %{"mm" => 0, "zz" => 0} =
               run(decl(~w(gg mm zz)) <> "( xic gg ote mm | xic mm ote zz )", %{
                 "gg" => 0,
                 "mm" => 1
               })
    end

    test "parallel branches OR, and every branch still runs for its side effects" do
      env =
        run(decl(~w(aa bb p1 p2 res)) <> "( xic aa ote p1 | xic bb ote p2 ) ote res", %{
          "aa" => 1,
          "p2" => 1
        })

      assert %{"p1" => 1, "p2" => 0, "res" => 1} = env
    end

    test "a nested branch group is an AND of an OR" do
      src = decl(~w(aa bb cc res)) <> "xic aa ( xic bb | xic cc ) ote res"
      assert %{"res" => 1} = run(src, %{"aa" => 1, "bb" => 0, "cc" => 1})
      assert %{"res" => 0} = run(src, %{"aa" => 1, "bb" => 0, "cc" => 0})
      # The AND: an open contact before the group leaves every leg without power.
      assert %{"res" => 0} = run(src, %{"aa" => 0, "bb" => 1, "cc" => 1})
    end

    test "an empty branch leg is a jumper and passes power unconditionally" do
      assert %{"xx" => 1} = run(decl(~w(aa xx)) <> "( xic aa | ) ote xx", %{"aa" => 0})
      assert %{"xx" => 1} = run(decl(~w(xx)) <> "( ) ote xx", %{})
    end

    test "unbalanced branch tokens are still rejected" do
      assert parse_error?("xic aa )")
      assert parse_error?("( xic aa")
      assert parse_error?("xic aa | ote bb")
    end

    test "branch nesting has no depth limit" do
      # The dialect logex borrows its mnemonics from stops at 6 levels; logex has
      # none, and docs/naming.md records that as a deliberate divergence. This is
      # what keeps the claim true: 50 is well past 6, and the only bound left is
      # the machine's. Both power states, so a nesting bug cannot pass by being
      # uniformly false.
      src =
        decl(~w(aa xx)) <>
          String.duplicate("( ", 50) <> "xic aa" <> String.duplicate(" )", 50) <> " ote xx"

      assert %{"xx" => 1} = run(src, %{"aa" => 1})
      assert %{"xx" => 0} = run(src, %{"aa" => 0})
    end

    test "deleting a space around a delimiter is a no-op, not a silent AND" do
      # This is the whole of B1. While the delimiters were the words `bst`/`nxb`/
      # `bnd` they came from the same character set as NAME, so leex's maximal
      # munch fused them into a neighbouring tag: `xic aa nxb` with the space
      # gone became a tag called `aanxb`, the group lost a leg, and an OR turned
      # silently into an AND with no error at any stage. `(`, `|` and `)` are
      # outside NAME, so the same deletion cannot change the token stream.
      spaced = decl(~w(aa bb dd)) <> "( xic aa | xic bb ) ote dd"
      fused = decl(~w(aa bb dd)) <> "( xic aa|xic bb ) ote dd"

      assert run(spaced, %{"aa" => 0, "bb" => 1}) == run(fused, %{"aa" => 0, "bb" => 1})
      assert %{"dd" => 1} = run(fused, %{"aa" => 0, "bb" => 1})

      # The same deletion against an operand rather than a contact: this one used
      # to write to a tag named `dstnxb` and leave `dst` alone.
      tags = decl(~w(bb ee), ~w(src dst))

      assert run(tags <> "( move src dst | xic bb ) ote ee", %{"src" => 9}) ==
               run(tags <> "( move src dst|xic bb ) ote ee", %{"src" => 9})

      assert %{"dst" => 9} = run(tags <> "( move src dst|xic bb ) ote ee", %{"src" => 9})
    end

    test "an old bst program names the word and its line rather than dying in Map.get" do
      # B1's migration is otherwise silent: `bst` is an ordinary tag name now, so
      # an old program is no longer a syntax error and reaches instructionize/1,
      # where `Map.get(@instructions, "bst")` returned nil and the bare MatchError
      # named neither the word nor the line.
      assert {:error, [first | _]} =
               compile(
                 decl(~w(aa bb cc dd ee)) <> "xic aa ote bb\nbst xic cc nxb xic dd bnd ote ee"
               )

      assert Logex.Diagnostic.format(first) =~ ~r/^line 7: `bst` is no longer a keyword/
    end
  end

  describe "tag names" do
    # These two guard the name rule: a letter or `_`, then any run of letters, digits
    # and `_` — now Logex.Lexer's name clause and word/2. As the leex regex
    # `NAME = [a-zA-Z_][a-zA-Z0-9_]*` it once had two independent bugs on one line
    # (PLAN.md §2·M0-4). Each test fails if its own half regresses, and passes if only
    # the other half does.

    test "a single-character tag is a legal name" do
      # Guards "any run", which includes an empty one. When the leex regex said `+`,
      # NAME needed two characters and this was {:error, {1, :ladder_lexer,
      # {:illegal, 'a'}}, 1}.
      assert %{"b" => 1} = run(decl(~w(a b)) <> "xic a ote b", %{"a" => 1})
      assert %{"z" => 1} = run(decl(~w(z)) <> "ote z", %{})
      refute lex_error?("xic a ote b")
    end

    test "brackets are illegal in a tag name, not swallowed into one" do
      # Guards the character class. The original `a-zA-z` is a lowercase-z typo
      # spanning ASCII 91-96, so [ \ ] ^ ` were legal inside identifiers and
      # "ote a[3]" lexed as a single tag literally named "a[3]" — array indexing
      # that looks like it works and does not. Since M5-11 (decision 151) it is indexing
      # that works: `a[3]` is element 3 of the array `a`, refused where `a` is no array,
      # and no tag is named with brackets.
      refute lex_error?("ote a[3]")

      assert {:error, [%{message: "`a[3]` names an element of `a`, but `a` is a bool" <> _}]} =
               Logex.compile("var a bool\note a[3]", name: "p")

      assert {:error, [%{message: "`a[3]` cannot name a tag: brackets are kept for" <> _} | _]} =
               Logex.compile("var a[3] bool\nxic b ote c", name: "p")

      assert lex_error?("ote a]b")
      assert lex_error?("ote a^b")
      assert lex_error?("ote a\\b")
    end
  end

  describe "line numbers" do
    test "no stage depends on an instruction sitting on line 1" do
      # Every operand carries its line, and so does every instruction since M1-2;
      # each evaluate/3, read/2 and write/3 pattern destructures them as `_`. That is only
      # a wildcard if nothing breaks when every instruction sits below line 1 -- so:
      # every instruction, both power states, a literal and a tag operand, from line
      # 3 down. The last rung opens its first contact, so every instruction after it
      # runs de-energised. Asserting values rather than survival is what makes a
      # literal 1 in any of those slots a FunctionClauseError here.
      src =
        decl(~w(aa bb p1 p2 q1 q2 r1 u1 t1), ~w(s1 s2 t2)) <>
          "\n\n( xic aa ote p1 | xic bb ote p2 )\n" <>
          "( xio bb otl q1 | xio aa otl q2 )\n" <>
          "xic aa otu r1 move 5 s1 move s1 s2\n" <>
          "xio aa xic bb xio bb otu u1 move 7 t2 ote t1"

      env = run(src, %{"aa" => 1, "bb" => 0, "p2" => 1, "r1" => 1, "u1" => 1})

      assert %{"p1" => 1, "p2" => 0, "q1" => 1, "r1" => 0, "s1" => 5, "s2" => 5} = env
      assert %{"u1" => 1, "t1" => 0} = env
      refute Map.has_key?(env, "q2")
      refute Map.has_key?(env, "t2")
    end
  end

  describe "output instructions" do
    test "a de-energised contact stays open, whatever its bit" do
      src = decl(~w(gg hh xx yy)) <> "xio gg xic hh ote xx\nxio gg xio yy ote yy"
      assert %{"xx" => 0, "yy" => 0} = run(src, %{"gg" => 1, "hh" => 1, "xx" => 1})
      assert %{"xx" => 1, "yy" => 1} = run(src, %{"gg" => 0, "hh" => 1})
    end

    test "a coil passes on the power it receives, energised or not" do
      src =
        decl(~w(gg m1 n1 m2 n2 m3 n3)) <>
          "xic gg otl m1 ote n1\nxic gg ote m2 ote n2\nxic gg otu m3 ote n3"

      assert %{"n1" => 1, "n2" => 1, "n3" => 1} = run(src, %{"gg" => 1})
      assert %{"n1" => 0, "n2" => 0, "n3" => 0} = run(src, %{"gg" => 0, "n1" => 1, "n3" => 1})
    end

    test "ote de-energises on a false rung, otl does not" do
      assert %{"xx" => 0} = run(decl(~w(gg xx)) <> "xic gg ote xx", %{"gg" => 0, "xx" => 1})
      assert %{"xx" => 1} = run(decl(~w(gg xx)) <> "xic gg otl xx", %{"gg" => 0, "xx" => 1})
    end
  end

  describe "a seal-in motor circuit, one scan per call" do
    @seal "var_input start bool\nvar_input stop bool\nvar_output motor bool\n" <>
            "( xic start | xic motor ) xio stop ote motor"

    test "starts, seals in when the button is released, and drops out on stop" do
      scan1 = run(@seal, %{"start" => 1, "stop" => 0, "motor" => 0})
      assert %{"motor" => 1} = scan1

      scan2 = run(@seal, Map.put(scan1, "start", 0))
      assert %{"motor" => 1} = scan2, "the seal-in branch should hold the motor on"

      scan3 = run(@seal, Map.put(scan2, "stop", 1))
      assert %{"motor" => 0} = scan3
    end
  end

  describe "the tag table (M1-3)" do
    test "a misspelt tag is a compile error, not a dead rung" do
      src = "var_input start bool\nvar_output motor bool\nxic strat ote motor"

      assert {:error, [diagnostic]} = compile(src)

      assert Logex.Diagnostic.format(diagnostic) ==
               "line 3: `strat` is not declared — did you mean `start`?"
    end

    test "logic cannot write an input" do
      assert {:error, [diagnostic]} =
               compile(
                 "var_input start bool\nvar_output motor bool\n( xic start | xic motor ) ote start"
               )

      assert Logex.Diagnostic.format(diagnostic) ==
               "line 3: `ote` writes `start`, a var_input (declared on line 1): " <>
                 "logic must not write an input"
    end

    test "every declared tag starts at its initial value" do
      {:ok, program} =
        compile("var_input go bool\nvar_output sp dint 1200\nvar lamp bool 1\nxic go move 0 sp")

      assert Logex.Program.initial_env(program) == %{"go" => 0, "sp" => 1200, "lamp" => 1}
    end

    test "the README's motor program, declared, runs five scans" do
      src = """
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

      # As the README runs it: compiled once, one instance, each step's inputs, one scan.
      {:ok, motor} = Logex.compile(src, name: "motor")

      steps = [
        {%{"start" => 1}, %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}, 0},
        {%{"start" => 0}, %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}, 0},
        {%{"overtemp" => 1}, %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 0}, 1},
        {%{"stop" => 1}, %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 0}, 1},
        # The fault stays latched after the overtemperature input clears.
        {%{"stop" => 0, "overtemp" => 0}, %{"motor" => 0, "run_lamp" => 0, "speed_sp" => 0}, 1}
      ]

      Enum.reduce(steps, Logex.Runtime.instance(motor), fn {inputs, outputs, fault}, state ->
        state = Logex.Runtime.put_inputs(motor, state, inputs)
        assert {^outputs, state} = Logex.Runtime.scan(motor, state)
        assert state.env["fault"] == fault
        state
      end)
    end
  end

  # M1-6: several scans of one instance through the public API, each step `{elapsed_ms,
  # inputs}`, giving each scan's outputs.
  defp drive(program, steps), do: drive(program, Logex.Runtime.instance(program), steps)

  defp drive(program, state, steps), do: elem(driven(program, state, steps), 0)

  # As drive/3, keeping the state the last scan left: `{trace, state}`.
  defp driven(program, state, steps),
    do:
      Enum.map_reduce(steps, state, fn {elapsed, inputs}, state ->
        state = Logex.Runtime.put_inputs(program, state, inputs)
        Logex.Runtime.scan(program, state, elapsed)
      end)

  defp program(src) do
    {:ok, program} = compile(src)
    program
  end

  # One scan, not the first, at 7 ms, after one at 5 ms, from an env the test builds by
  # hand.
  defp later_scan(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 5, first: false}
    {outputs, state} = Logex.Runtime.call(program, state, %{}, %Logex.Scan{now: 7, first: false})
    {outputs, state.env}
  end

  describe "ons (M1-6)" do
    @ons "var_input go bool\nvar_output pulse bool\nvar s1 bool\nxic go ons s1 ote pulse"

    defp pulses(src, gos),
      do:
        src |> program() |> drive(Enum.map(gos, &{10, %{"go" => &1}})) |> Enum.map(& &1["pulse"])

    test "passes power once per rising edge: not while held, and again after a drop" do
      assert pulses(@ons, [0, 1, 1, 1, 0, 1, 0, 0, 1]) == [0, 1, 0, 0, 0, 1, 0, 0, 1]
    end

    test "a rung already true on the first scan does not fire, whatever the storage bit holds" do
      for initial <- ["", " 0", " 1"] do
        src = String.replace(@ons, "var s1 bool", "var s1 bool" <> initial)
        assert pulses(src, [1, 1, 0, 1]) == [0, 0, 0, 1], "declared `var s1 bool#{initial}`"
      end
    end

    test "nor on the first scan after a restart, with the input still held" do
      p = program(@ons)
      state = Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"go" => 0})
      {_, state} = Logex.Runtime.scan(p, state)
      state = Logex.Runtime.put_inputs(p, state, %{"go" => 1})
      {%{"pulse" => 1}, state} = Logex.Runtime.scan(p, state, 10)
      restarted = Logex.Runtime.restart(p, state, :cold)

      assert [%{"pulse" => 0}, %{"pulse" => 0}, %{"pulse" => 1}] =
               drive(p, restarted, [{10, %{}}, {10, %{"go" => 0}}, {10, %{"go" => 1}}])
    end

    test "after xio it fires on a falling edge" do
      src = "var_input go bool\nvar_output pulse bool\nvar s1 bool\nxio go ons s1 ote pulse"
      assert pulses(src, [1, 1, 0, 0, 1, 0]) == [0, 0, 1, 0, 0, 1]
    end

    test "the storage bit follows the power it receives, and a var_output may hold it" do
      src =
        "var_input go bool\nvar_output s1 bool 1\nvar_output pulse bool\nxic go ons s1 ote pulse"

      assert drive(program(src), Enum.map([0, 1, 1, 0], &{10, %{"go" => &1}})) == [
               %{"s1" => 0, "pulse" => 0},
               %{"s1" => 1, "pulse" => 1},
               %{"s1" => 1, "pulse" => 0},
               %{"s1" => 0, "pulse" => 0}
             ]
    end

    test "in a branch leg it is held back on the first scan too, and fires on the next edge" do
      src =
        "var_input go bool\nvar_input other bool\nvar_output pulse bool\nvar s1 bool\n" <>
          "( xic go ons s1 | xic other ) ote pulse"

      assert pulses(src, [1, 0, 1]) == [0, 0, 1]
    end

    test "a storage bit holding a bool's 0 or 1 is read as a contact reads it, and anything " <>
           "else is the host's mistake (decisions 171 and 173)" do
      p = program(@ons)

      for {bit, fires} <- [{0, 1}, {1, 0}] do
        assert {%{"pulse" => ^fires}, %{"s1" => 1}} = later_scan(p, %{"s1" => bit, "go" => 1})
      end

      # Until decision 173 a nil or a false read as 0 and fired, a 2.5, "x" or true as 1.
      for junk <- [5, nil, false, 0.0, 2.5, "x", true] do
        assert_raise ArgumentError,
                     "state.env holds `s1` outside its type: it is a bool, and only 0 or 1 " <>
                       "fit, found #{inspect(junk)}",
                     fn -> later_scan(p, %{"s1" => junk, "go" => 1}) end
      end
    end
  end

  describe "comparisons (M1-6)" do
    @compare """
    var_input a dint
    var_input b dint
    var_input on bool
    var_output o_eq bool
    var_output o_ne bool
    var_output o_lt bool
    var_output o_gt bool
    var_output o_le bool
    var_output o_ge bool
    var_output big bool
    var_output small bool
    var_output gated bool
    var_output either bool

    eq a b ote o_eq
    ne a b ote o_ne
    lt a b ote o_lt
    gt a b ote o_gt
    le a b ote o_le
    ge a b ote o_ge
    gt a 100 ote big
    lt 100 a ote small
    xic on ( eq a a | ne a a | lt a a | gt a a | le a a | ge a a ) ote gated
    ( lt a b | gt a b ) ote either
    """

    test "each compares its first operand with its second, as `lt a b` reads a < b" do
      p = program(@compare)

      for {a, b, expected} <- [
            {1, 2, [0, 1, 1, 0, 1, 0]},
            {2, 2, [1, 0, 0, 0, 1, 1]},
            {3, 2, [0, 1, 0, 1, 0, 1]},
            {-2_147_483_648, 2_147_483_647, [0, 1, 1, 0, 1, 0]},
            {2_147_483_647, -2_147_483_648, [0, 1, 0, 1, 0, 1]}
          ] do
        [outputs] = drive(p, [{0, %{"a" => a, "b" => b}}])
        found = Enum.map(~w(o_eq o_ne o_lt o_gt o_le o_ge), &outputs[&1])
        assert found == expected, "a=#{a} b=#{b}"
      end
    end

    test "a literal may stand on either side" do
      p = program(@compare)
      assert [%{"big" => 1, "small" => 1}] = drive(p, [{0, %{"a" => 101}}])
      assert [%{"big" => 0, "small" => 0}] = drive(p, [{0, %{"a" => 100}}])
    end

    test "on a de-energised rung each passes no power, whatever it would find" do
      # With `on`, `eq a a`, `le a a` and `ge a a` hold, so the group passes power.
      assert [%{"gated" => 1}] = drive(program(@compare), [{0, %{"on" => 1}}])
      assert [%{"gated" => 0}] = drive(program(@compare), [{0, %{"on" => 0}}])
    end

    test "in parallel legs they OR, as contacts do" do
      p = program(@compare)
      assert [%{"either" => 1}] = drive(p, [{0, %{"a" => 1, "b" => 2}}])
      assert [%{"either" => 0}] = drive(p, [{0, %{"a" => 2, "b" => 2}}])
    end

    test "on an env the host builds, each pair is complementary, and a value that is no " <>
           "integer is the host's mistake (decision 173)" do
      src =
        "var a dint\nvar b dint\nvar eq_ bool\nvar ne_ bool\nvar lt_ bool\nvar ge_ bool\n" <>
          "var gt_ bool\nvar le_ bool\neq a b ote eq_\nne a b ote ne_\nlt a b ote lt_\n" <>
          "ge a b ote ge_\ngt a b ote gt_\nle a b ote le_"

      p = program(src)
      values = [0, 1, -1, -2_147_483_648, 2_147_483_647, :missing]

      for a <- values, b <- values do
        env = for({k, v} <- [{"a", a}, {"b", b}], v != :missing, into: %{}, do: {k, v})
        {_, env} = later_scan(p, env)
        pairs = [{"eq_", "ne_"}, {"lt_", "ge_"}, {"gt_", "le_"}]
        assert Enum.all?(pairs, fn {x, y} -> env[x] + env[y] == 1 end), inspect({a, b})
      end

      # Until decision 173 each of these was compared as Erlang orders terms.
      for junk <- [1.0, 2.5, nil, true, :on, "0", [], %{}, {1}] do
        assert_raise ArgumentError,
                     "state.env holds `a` outside its type: it is a dint, and its value must " <>
                       "be an integer, found #{inspect(junk)}",
                     fn -> later_scan(p, %{"a" => junk, "b" => 0}) end
      end
    end
  end

  describe "ton (M1-6)" do
    @timer """
    var_input go bool
    var_input newpre bool
    var_input setacc bool
    var_input sp dint
    var_output done bool
    var_output timing bool
    var_output enabled bool
    var_output acc dint
    var_output pre dint
    var t1 ton

    xic newpre move sp t1.pre
    xic setacc move sp t1.acc
    xic go ton t1 5000
    xic t1.dn ote done
    xic t1.tt ote timing
    xic t1.en ote enabled
    move t1.acc acc
    move t1.pre pre
    """

    defp timer_trace(steps),
      do: Enum.map(drive(program(@timer), steps), &Map.take(&1, ~w(acc done timing enabled)))

    test "times from the first scan that sees its rung true, and is done at its preset" do
      assert timer_trace([
               {0, %{}},
               {700, %{"go" => 1}},
               {10, %{}},
               {4980, %{}},
               {10, %{}},
               {1000, %{}}
             ]) == [
               %{"acc" => 0, "done" => 0, "timing" => 0, "enabled" => 0},
               # The 700 ms before the rung went true are not counted.
               %{"acc" => 0, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 10, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 4990, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1},
               # .acc stops at the preset.
               %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1}
             ]
    end

    test "a false rung resets a done timer too" do
      assert timer_trace([{0, %{"go" => 1}}, {6000, %{}}, {10, %{"go" => 0}}]) == [
               %{"acc" => 0, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1},
               %{"acc" => 0, "done" => 0, "timing" => 0, "enabled" => 0}
             ]
    end

    test "a false rung resets it, and it starts again from 0 at the next true one" do
      assert timer_trace([
               {0, %{"go" => 1}},
               {3000, %{}},
               {10, %{"go" => 0}},
               {500, %{"go" => 1}},
               {100, %{}}
             ]) == [
               %{"acc" => 0, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 3000, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 0, "done" => 0, "timing" => 0, "enabled" => 0},
               # The 500 ms the rung was false are not counted.
               %{"acc" => 0, "done" => 0, "timing" => 1, "enabled" => 1},
               %{"acc" => 100, "done" => 0, "timing" => 1, "enabled" => 1}
             ]
    end

    test "a leg beside a ton is a path of its own: it runs from the power into the group" do
      # Nothing may follow a ton on its path (validation_test.exs), but a parallel leg is
      # not on its path.
      src =
        "var_input go bool\nvar_output beside bool\nvar_output done bool\nvar t1 ton\n" <>
          "xic go ( ton t1 20 | ote beside )\nxic t1.dn ote done"

      assert drive(program(src), [{0, %{"go" => 1}}, {20, %{}}, {10, %{"go" => 0}}]) == [
               %{"beside" => 1, "done" => 0},
               %{"beside" => 1, "done" => 1},
               %{"beside" => 0, "done" => 0}
             ]
    end

    test "keeps the time of its last run in state.env, energised or not, and nothing a " <>
           "host could set" do
      p = program(@timer)
      state = Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"go" => 1})
      {_, state} = Logex.Runtime.scan(p, state, 40)
      {_, state} = Logex.Runtime.scan(p, state, 60)

      assert state.env["t1"] == %{
               "pre" => 5000,
               "acc" => 60,
               "dn" => 0,
               "tt" => 1,
               "en" => 1,
               "last" => 100
             }

      # De-energised, it still runs, and `last` is its time (decision 5); the edge is read
      # from `.en`, so the next true scan adds nothing.
      state = Logex.Runtime.put_inputs(p, state, %{"go" => 0})
      {_, state} = Logex.Runtime.scan(p, state, 25)

      assert state.env["t1"] == %{
               "pre" => 5000,
               "acc" => 0,
               "dn" => 0,
               "tt" => 0,
               "en" => 0,
               "last" => 125
             }

      state = Logex.Runtime.put_inputs(p, state, %{"go" => 1})
      {_, state} = Logex.Runtime.scan(p, state, 30)
      assert %{"acc" => 0, "en" => 1, "last" => 155} = state.env["t1"]
    end

    test "its preset is where .pre starts: a move into .pre holds, the ton never " <>
           "rewrites it, and a restart puts it back" do
      p = program(@timer)

      steps = [
        {0, %{"go" => 1, "newpre" => 1, "sp" => 2000}},
        {10, %{"newpre" => 0}},
        {1990, %{}}
      ]

      assert [%{"pre" => 2000}, %{"pre" => 2000, "done" => 0}, %{"pre" => 2000, "done" => 1}] =
               drive(p, steps)

      state =
        Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"newpre" => 1, "sp" => 2000})

      {%{"pre" => 2000}, state} = Logex.Runtime.scan(p, state)

      restarted =
        Logex.Runtime.restart(p, Logex.Runtime.put_inputs(p, state, %{"newpre" => 0}), :cold)

      assert [%{"pre" => 5000}] = drive(p, restarted, [{10, %{}}])
    end

    test "a move into .acc is counted from, while the rung stays true" do
      assert timer_trace([
               {0, %{"go" => 1}},
               {6000, %{}},
               {10, %{"setacc" => 1, "sp" => 0}},
               {10, %{"setacc" => 0}},
               {10, %{"setacc" => 1, "sp" => 4995}},
               {10, %{"setacc" => 0}}
             ]) ==
               [
                 %{"acc" => 0, "done" => 0, "timing" => 1, "enabled" => 1},
                 %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1},
                 # 0 is moved into .acc before the ton runs, which then adds its 10 ms.
                 %{"acc" => 10, "done" => 0, "timing" => 1, "enabled" => 1},
                 %{"acc" => 20, "done" => 0, "timing" => 1, "enabled" => 1},
                 %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1},
                 %{"acc" => 5000, "done" => 1, "timing" => 0, "enabled" => 1}
               ]
    end

    test "a negative .acc written by logic counts from 0" do
      # -50 is floored to 0 before the 100 ms are added, not after: 100, not 50.
      steps = [{0, %{"go" => 1}}, {100, %{"setacc" => 1, "sp" => -50}}, {10, %{"setacc" => 0}}]
      assert [_, %{"acc" => 100, "timing" => 1}, %{"acc" => 110}] = drive(program(@timer), steps)
    end

    test "a member written below the ton takes effect at the next scan: its invariants hold " <>
           "right after the ton runs, not at the end of every scan" do
      src =
        "var_input go bool\nvar_input lower bool\nvar t1 ton\n" <>
          "xic go ton t1 5000\nxic lower move 1000 t1.pre"

      p = program(src)
      state = Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"go" => 1})
      {_, state} = Logex.Runtime.scan(p, state)

      {_, state} =
        Logex.Runtime.scan(p, Logex.Runtime.put_inputs(p, state, %{"lower" => 1}), 1500)

      # A host reading state.env sees .acc past .pre, and not done.
      assert %{"pre" => 1000, "acc" => 1500, "dn" => 0, "tt" => 1} = state.env["t1"]
      {_, state} = Logex.Runtime.scan(p, state, 10)
      assert %{"pre" => 1000, "acc" => 1000, "dn" => 1, "tt" => 0} = state.env["t1"]
    end

    test "an instance kept under a recompiled program of the same name keeps its old .pre " <>
           "until a restart" do
      # The preset is where .pre starts, so a recompile scanned over a kept instance, a plain
      # swap, reaches a new or restarted instance only. Logex.Edit moves .pre by rule instead
      # (docs/organisation.md §4.9, and its online-edit row in §5).
      src =
        &"var_input go bool\nvar_output done bool\nvar t1 ton\nxic go ton t1 #{&1}\nxic t1.dn ote done"

      {:ok, v1} = Logex.compile(src.(5000), name: "m")
      {:ok, v2} = Logex.compile(src.(3000), name: "m")

      state = Logex.Runtime.put_inputs(v1, Logex.Runtime.instance(v1), %{"go" => 1})
      {_, state} = Logex.Runtime.scan(v1, state)
      {%{"done" => 0}, state} = Logex.Runtime.scan(v2, state, 3000)
      {%{"done" => 0}, state} = Logex.Runtime.scan(v2, state, 10)
      assert %{"pre" => 5000, "acc" => 3010} = state.env["t1"]
      {%{"done" => 1}, state} = Logex.Runtime.scan(v2, state, 1990)

      restarted = Logex.Runtime.restart(v2, state, :cold)
      assert %{"pre" => 3000, "acc" => 0} = restarted.env["t1"]
    end

    test "a timer a recompile of the same name adds is missing from a kept instance, so it " <>
           "starts at .pre 0 until a restart" do
      # As any tag a recompile adds reads 0, not its initial value, until a restart.
      {:ok, v1} =
        Logex.compile("var_input go bool\nvar_output done bool\nxic go ote done", name: "m")

      {:ok, v2} =
        Logex.compile(
          "var_input go bool\nvar_output done bool\nvar t2 ton\nxic go ton t2 5000\n" <>
            "xic t2.dn ote done",
          name: "m"
        )

      state = Logex.Runtime.put_inputs(v1, Logex.Runtime.instance(v1), %{"go" => 1})
      {_, state} = Logex.Runtime.scan(v1, state)
      {%{"done" => 1}, state} = Logex.Runtime.scan(v2, state, 10)
      assert %{"pre" => 0, "acc" => 0, "dn" => 1} = state.env["t2"]

      restarted = Logex.Runtime.restart(v2, state, :cold)
      assert %{"pre" => 5000, "acc" => 0, "dn" => 0} = restarted.env["t2"]
    end

    test "a restart under a recompile of the same name keeps a var_input whose value fits " <>
           "its new type, and refuses one outside it (decisions 171 and 173)" do
      {:ok, v1} =
        Logex.compile("var_input go bool\nvar_input x dint\nvar t1 ton\nxic go ton t1 50",
          name: "m"
        )

      {:ok, v2} =
        Logex.compile(
          "var_input go bool\nvar_input x bool\nvar_input t1 dint\nvar_output y dint\n" <>
            "xic x move t1 y",
          name: "m"
        )

      state = Logex.Runtime.put_inputs(v1, Logex.Runtime.instance(v1), %{"go" => 1, "x" => 5})
      {_, state} = Logex.Runtime.scan(v1, state)
      {_, state} = Logex.Runtime.scan(v1, state, 10)
      assert %{"x" => 5, "t1" => %{"acc" => 10}} = state.env

      # `x`'s 5 is outside its new type, a bool: the host's mistake; and `t1`, a timer's map
      # where a dint now goes, is no integer: the host's mistake too (decision 173), where
      # until then it was started again.
      timer = "found #{inspect(state.env["t1"])}"

      assert_raise ArgumentError,
                   "state.env holds `t1` outside its type: it is a dint, and its value must " <>
                     "be an integer, #{timer}\n" <>
                     "state.env holds `x` outside its type: it is a bool, and only 0 or 1 fit, " <>
                     "found 5",
                   fn -> Logex.Runtime.restart(v2, state, :cold) end

      state = %{state | env: %{state.env | "x" => 1}}

      assert_raise ArgumentError,
                   "state.env holds `t1` outside its type: it is a dint, and its value must " <>
                     "be an integer, #{timer}",
                   fn -> Logex.Runtime.restart(v2, state, :cold) end

      # `go`, a 1 in `x` and a 7 in `t1` fit, and are kept as the input image is.
      state = %{state | env: %{state.env | "t1" => 7}}
      restarted = Logex.Runtime.restart(v2, state, :cold)
      assert restarted.env == %{"go" => 1, "x" => 1, "t1" => 7, "y" => 0}
    end

    test "a preset lowered below .acc is done at the next true scan, .acc brought down to it" do
      steps = [{0, %{"go" => 1}}, {3000, %{}}, {10, %{"newpre" => 1, "sp" => 1000}}]

      assert [_, %{"acc" => 3000, "done" => 0}, %{"acc" => 1000, "done" => 1, "pre" => 1000}] =
               drive(program(@timer), steps)
    end

    test "a preset raised after it is done resumes the count: .dn is .acc against .pre on " <>
           "every true scan" do
      steps = [{0, %{"go" => 1}}, {6000, %{}}, {10, %{"newpre" => 1, "sp" => 8000}}]

      assert [_, %{"acc" => 5000, "done" => 1}, %{"acc" => 5010, "done" => 0, "timing" => 1}] =
               drive(program(@timer), steps)
    end

    test "a negative preset times as 0: done at the first true scan, .acc 0, .pre as written" do
      steps = [{0, %{"newpre" => 1, "sp" => -5}}, {10, %{"go" => 1}}]

      assert [_, %{"acc" => 0, "done" => 1, "timing" => 0, "pre" => -5}] =
               drive(program(@timer), steps)
    end

    test "a ton in a branch group starts from its own preset too" do
      src =
        "var_input go bool\nvar_output done bool\nvar t1 ton\n" <>
          "( xic go ton t1 50 | )\nxic t1.dn ote done"

      assert [%{"done" => 0}, %{"done" => 0}, %{"done" => 1}] =
               drive(program(src), [{0, %{"go" => 1}}, {40, %{}}, {10, %{}}])
    end

    test "a preset of 0 is done at the first true scan" do
      src =
        "var_input go bool\nvar_output done bool\nvar t1 ton\nxic go ton t1 0\nxic t1.dn ote done"

      assert [%{"done" => 0}, %{"done" => 1}] =
               drive(program(src), [{0, %{}}, {10, %{"go" => 1}}])
    end

    test "however long the gap between scans, .acc comes to the preset and no further" do
      steps = [{0, %{"go" => 1}}, {1_000_000_000_000_000, %{}}]
      assert [_, %{"acc" => 5000, "done" => 1}] = drive(program(@timer), steps)
    end

    test "the increment is the time that passed, not a nominal interval: stepped at 10, " <>
           "25, 30 or 7 ms, it is done at the first scan at or after 5000 ms" do
      for {step, done_at} <- [{10, 5000}, {25, 5000}, {30, 5010}, {7, 5005}] do
        steps = [{0, %{"go" => 1}} | List.duplicate({step, %{}}, div(6000, step))]
        times = Enum.scan(steps, 0, fn {elapsed, _}, t -> t + elapsed end)
        trace = drive(program(@timer), steps)

        assert {%{"acc" => 5000}, ^done_at} =
                 Enum.zip(trace, times) |> Enum.find(fn {o, _t} -> o["done"] == 1 end)
      end
    end

    # Each instance stepped through call/4 at the times given, with `go` as `at.(now)`
    # gives it, since tasks, which would schedule them, are M2-1's.
    defp scans(program, times, go) do
      {trace, _} =
        Enum.map_reduce(times, Logex.Runtime.instance(program), fn now, state ->
          scan = %Logex.Scan{now: now, first: state.first}
          {outputs, state} = Logex.Runtime.call(program, state, %{"go" => go.(now)}, scan)
          {{now, outputs}, state}
        end)

      trace
    end

    defp done_at(trace), do: Enum.find_value(trace, fn {now, out} -> out["done"] == 1 && now end)

    # PLAN.md M1-6, decision 6: before the model is called settled, one program type, two
    # instances on 10 ms and 50 ms tasks, and .acc reaching the preset at the same logical
    # time in both. `go` rises at 1000 ms, a time both scan. `last` is stamped on every run,
    # so a first energised scan that counted the time since it would be done at 5990 ms
    # and 5950 ms; the edge is read from `.en`, and that scan counts nothing.
    test "decision 6: two instances of one program, scanned every 10 ms and every 50 ms, " <>
           "reach the preset at the same logical time" do
      p = program(@timer)
      go = &bit(&1 >= 1000)
      fast = scans(p, Enum.to_list(0..8000//10), go)
      slow = scans(p, Enum.to_list(0..8000//50), go)

      assert done_at(fast) == 6000
      assert done_at(slow) == 6000
      assert {6000, %{"acc" => 5000}} = List.keyfind(slow, 6000, 0)

      # At every time both scan, the two agree exactly.
      fast_at = Map.new(fast)
      for {now, outputs} <- slow, do: assert(fast_at[now] == outputs, "at #{now} ms")

      # The actual time counts, not a nominal period: scanned irregularly, a third
      # instance is not done at 5999 ms, and is at 6000 ms.
      jittered = scans(p, [0, 7, 1000, 1003, 2500, 2501, 4444, 5999, 6000], go)

      assert for({now, out} <- jittered, now >= 5999, do: {now, out["acc"], out["done"]}) ==
               [{5999, 4999, 0}, {6000, 5000, 1}]
    end

    # The same logical time holds per rising edge: it needs both instances to see the edge
    # at one time, and a preset both periods divide. Otherwise each is done at its first
    # scan at or after edge + preset, with .acc stopped at the preset: M2-3's acceptance
    # should say so.
    test "decision 6's condition: a preset of 1030 ms is done at 1030 ms on 10 ms scans " <>
           "and at 1050 ms on 50 ms scans, .acc 1030 in both" do
      p = program(String.replace(@timer, "ton t1 5000", "ton t1 1030"))
      fast = scans(p, Enum.to_list(0..2000//10), fn _ -> 1 end)
      slow = scans(p, Enum.to_list(0..2000//50), fn _ -> 1 end)
      assert {1030, %{"acc" => 1030}} = List.keyfind(fast, done_at(fast), 0)
      assert {1050, %{"acc" => 1030}} = List.keyfind(slow, done_at(slow), 0)
    end

    # Per rising edge, not per period: a timer that re-triggers itself is reset by the scan
    # after it is done and restarts on the scan after that, adding nothing, so it repeats
    # every preset plus two task periods, as MatIEC's TON does, and its period differs at
    # 10 and 50 ms although both see its first edge at 0 ms.
    test "decision 6 holds per rising edge: a timer that re-triggers itself repeats every " <>
           "preset plus two task periods" do
      p =
        program(
          "var_input go bool\nvar_output pulse bool\nvar t1 ton\n" <>
            "xic go xio t1.dn ton t1 1000\nxic t1.dn ote pulse"
        )

      pulses = fn period ->
        for {now, %{"pulse" => 1}} <- scans(p, Enum.to_list(0..4000//period), fn _ -> 1 end),
            do: now
      end

      assert pulses.(10) == [1000, 2020, 3040]
      assert pulses.(50) == [1000, 2100, 3200]
    end

    # PLAN.md M2-3's motor, the README's plus a timer, compiles as written and times.
    test "M2-3's motor: the README motor with `var t1 ton` and `xic motor ton t1 5000`" do
      src = """
      var_input start bool
      var_input stop bool
      var_input overtemp bool
      var_input reset bool
      var_output motor bool
      var_output run_lamp bool
      var_output speed_sp dint 1200
      var_output running_ms dint
      var fault bool
      var t1 ton

      ( xic start | xic motor ) xio stop ote motor
      xic motor ote run_lamp
      xic overtemp otl fault
      xic reset otu fault
      xic fault move 0 speed_sp
      xic motor ton t1 5000
      xic motor move t1.acc running_ms
      """

      assert {:ok, %Logex.Program{warnings: []} = p} = compile(src)
      steps = [{0, %{"start" => 1}}, {10, %{"start" => 0}} | List.duplicate({10, %{}}, 500)]
      trace = drive(p, steps)
      assert %{"motor" => 1, "running_ms" => 0} = hd(trace)
      assert %{"motor" => 1, "running_ms" => 5000} = List.last(trace)
      assert Enum.at(trace, 300)["running_ms"] == 3000
    end
  end

  describe "ton on an env the host builds (M1-6)" do
    @ton "var_input go bool\nvar t1 ton\nxic go ton t1 50"

    test "leaves a well-formed timer, whatever was there, energised or not" do
      p = program(@ton)

      for junk <- [
            %{},
            %{"pre" => 0, "en" => 1},
            %{"dn" => 0, "acc" => 0, "pre" => 0},
            %Logex.Scan{now: 0, first: true}
          ] do
        {_, on} = later_scan(p, %{"t1" => junk, "go" => 1})
        {_, off} = later_scan(p, %{"t1" => junk, "go" => 0})

        assert on["t1"] == %{"pre" => 0, "acc" => 0, "dn" => 1, "tt" => 0, "en" => 1, "last" => 7},
               inspect(junk)

        assert off["t1"] ==
                 %{"pre" => 0, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 7},
               inspect(junk)
      end

      # A member of a bool or an integer type holding no integer is the host's mistake
      # (decision 173), where until then it was read as a well-formed timer's.
      assert_raise ArgumentError,
                   "state.env holds `t1.acc` outside its type: it is a dint, and its value " <>
                     "must be an integer, found 2.5\n" <>
                     "state.env holds `t1.dn` outside its type: it is a bool, and only 0 or 1 " <>
                     "fit, found nil\n" <>
                     "state.env holds `t1.pre` outside its type: it is a dint, and its value " <>
                     "must be an integer, found \"q\"",
                   fn ->
                     later_scan(p, %{
                       "t1" => %{"dn" => nil, "acc" => 2.5, "pre" => "q"},
                       "go" => 1
                     })
                   end

      # So is a timer's tag that holds no map (decision 184), where until then it was read
      # as an empty timer's.
      for junk <- [5, nil, "x", [1]] do
        assert_raise ArgumentError,
                     "state.env holds `t1` outside its type: it is a ton, and its value must " <>
                       "be a map of its members, found #{inspect(junk)}",
                     fn -> later_scan(p, %{"t1" => junk, "go" => 1}) end
      end
    end

    test "a `last` that is not an integer is refused, and one left out adds nothing" do
      # Decision 186: until then a `last` that was no integer added nothing, as one the env
      # leaves out still does. A .pre with room above .acc, so the cap cannot hide what was
      # added.
      for last <- ["z", nil, 1.5] do
        timer = %{"pre" => 50, "acc" => 5, "en" => 1, "last" => last}

        assert_raise ArgumentError,
                     "state.env holds `t1.last` outside its type: it is a clock, and its " <>
                       "value must be an integer, found #{inspect(last)}",
                     fn -> later_scan(program(@ton), %{"t1" => timer, "go" => 1}) end
      end

      timer = %{"pre" => 50, "acc" => 5, "en" => 1}

      assert {_, %{"t1" => %{"acc" => 5, "last" => 7}}} =
               later_scan(program(@ton), %{"t1" => timer, "go" => 1})
    end

    # Decision 188: a `last` later than the instance's `now`, a time the timer cannot have
    # run at yet, is the host's mistake, where it added nothing until then.
    test "a `last` later than now refused, or .en read as a contact reads it" do
      p = program(@ton)
      timer = %{"pre" => 50, "acc" => 5, "dn" => 0, "tt" => 1, "last" => 1000}

      assert_raise ArgumentError,
                   "state.env holds `t1.last` outside its type: it is a clock, and 1000 is " <>
                     "later than the instance's now, 5",
                   fn -> later_scan(p, %{"t1" => Map.put(timer, "en", 1), "go" => 1}) end

      # Up to the instance's own `now` it is taken, adding the time from it.
      assert {_, %{"t1" => %{"acc" => 7, "last" => 7}}} =
               later_scan(p, %{"t1" => Map.merge(timer, %{"en" => 1, "last" => 5}), "go" => 1})

      for {en, acc} <- [{1, 7}, {0, 5}] do
        from_zero = %{timer | "last" => 5}

        assert {_, %{"t1" => %{"acc" => ^acc}}} =
                 later_scan(p, %{"t1" => Map.put(from_zero, "en", en), "go" => 1}),
               inspect(en)
      end

      # Anything else in a bool is the host's mistake: an integer outside it (decision 171)
      # or, since decision 173, a value that is no integer, a true or a 2.5 read as 1 until
      # then and a nil or a false as 0.
      for junk <- [5, true, 2.5, nil, false] do
        assert_raise ArgumentError,
                     "state.env holds `t1.en` outside its type: it is a bool, and only 0 or 1 " <>
                       "fit, found #{inspect(junk)}",
                     fn ->
                       later_scan(p, %{
                         "t1" => Map.merge(timer, %{"last" => 0, "en" => junk}),
                         "go" => 1
                       })
                     end
      end
    end
  end

  describe "members (M1-6)" do
    @members """
    var_input set bool
    var_input sp dint
    var_output pre dint
    var_output acc dint
    var_output done bool
    var_output early bool
    var t1 ton

    gt t1.pre 0 ote early
    xic set move sp t1.pre
    xic set move sp t1.acc
    move t1.pre pre
    move t1.acc acc
    xic t1.dn ote done
    """

    test "a move into .pre or .acc holds from scan to scan, and a rung reads what an " <>
           "earlier rung of the scan wrote" do
      assert drive(program(@members), [
               {0, %{}},
               {10, %{"set" => 1, "sp" => 300}},
               {10, %{"set" => 0}}
             ]) == [
               %{"pre" => 0, "acc" => 0, "done" => 0, "early" => 0},
               # `early` is above the move: it sees last scan's .pre.
               %{"pre" => 300, "acc" => 300, "done" => 0, "early" => 0},
               %{"pre" => 300, "acc" => 300, "done" => 0, "early" => 1}
             ]
    end
  end

  describe "members on an env the host builds (M1-6)" do
    # Outside the contract, like M1-4's contacts, but still total: whatever map a
    # hand-built env holds where a timer belongs, nothing raises; a member of a bool or an
    # integer type holding anything outside its type is the host's mistake (decisions 171
    # and 173), and so is a timer's tag that holds no map (decision 184).
    @junk [%{}, %{"acc" => 2}, %Logex.Scan{now: 0, first: true}]
    @not_maps [5, nil, "x", [1]]

    defp not_a_map(junk),
      do:
        "state.env holds `t1` outside its type: it is a ton, and its value must be a map of " <>
          "its members, found #{inspect(junk)}"

    test "a contact on a member is total, and xic and xio stay complementary" do
      p = program("var t1 ton\nvar hi bool\nvar lo bool\nxic t1.dn ote hi\nxio t1.dn ote lo")

      for junk <- @junk ++ [%{"dn" => 1}, %{"dn" => 0}] do
        {_, env} = later_scan(p, %{"t1" => junk})
        assert env["hi"] + env["lo"] == 1, inspect(junk)
      end

      assert {_, %{"hi" => 1}} = later_scan(p, %{"t1" => %{"dn" => 1}})

      for junk <- @not_maps do
        assert_raise ArgumentError, not_a_map(junk), fn -> later_scan(p, %{"t1" => junk}) end
      end

      # Until decision 173 a true read as closed, a nil and a 2.5 as open and closed.
      for junk <- [true, nil, 2.5] do
        assert_raise ArgumentError,
                     "state.env holds `t1.dn` outside its type: it is a bool, and only 0 or 1 " <>
                       "fit, found #{inspect(junk)}",
                     fn -> later_scan(p, %{"t1" => %{"dn" => junk}}) end
      end
    end

    test "move from a member the host left out copies 0, and of a timer that is not a map " <>
           "is refused" do
      p = program("var t1 ton\nvar d dint\nmove t1.acc d")

      for junk <- @junk -- [%{"acc" => 2}] do
        assert {_, %{"d" => 0}} = later_scan(p, %{"t1" => junk, "d" => 9}), inspect(junk)
      end

      for junk <- @not_maps do
        assert_raise ArgumentError, not_a_map(junk), fn ->
          later_scan(p, %{"t1" => junk, "d" => 9})
        end
      end
    end

    test "a write into a timer the host left without the member adds it, and into one that " <>
           "is not a map is refused" do
      p = program("var t1 ton\nmove 3 t1.pre")

      for junk <- [%{}, %Logex.Scan{now: 0, first: true}] do
        assert {_, %{"t1" => %{"pre" => 3}}} = later_scan(p, %{"t1" => junk}), inspect(junk)
      end

      for junk <- @not_maps do
        assert_raise ArgumentError, not_a_map(junk), fn -> later_scan(p, %{"t1" => junk}) end
      end

      assert {_, %{"t1" => %{"pre" => 3, "acc" => 4}}} =
               later_scan(p, %{"t1" => %{"pre" => 1, "acc" => 4}})
    end
  end

  describe "comparisons on an env the host builds (M1-6)" do
    test "a tag the host left out reads 0, as move reads it" do
      p = program("var a dint\nvar z bool\nvar n bool\neq a 0 ote z\nlt a 0 ote n")
      assert {_, %{"z" => 1, "n" => 0}} = later_scan(p, %{})
    end
  end

  describe "contacts on an env the host builds (M1-4)" do
    # The compiler lets only a bool reach a contact, but evaluate/3 takes whatever env the
    # host hands it. xic and xio must still disagree on every value: before M1-4 a 5, a
    # nil or a missing tag read false for both, so an interlock on xio never fired.
    @contacts "var t bool\nvar hi bool\nvar lo bool\nxic t ote hi\nxio t ote lo"

    test "xic and xio are complementary for a bool's two values and a tag left out, and " <>
           "anything else is the host's mistake (decisions 171 and 173)" do
      for {env, closed} <- [{%{"t" => 0}, 0}, {%{"t" => 1}, 1}, {%{}, 0}] do
        assert %{"hi" => ^closed, "lo" => lo} = run(@contacts, env)
        assert lo == 1 - closed, "xio must be the complement of xic for #{inspect(env)}"
      end

      # Since decision 171 an integer outside a bool, a 5 or a -3, never reaches a contact,
      # and since decision 173 nor does a value that is no integer, which M1-4 read by
      # value, 0.0 and -0.0 open and 2.5 closed, a boolean as itself, a nil open and
      # anything else closed: each is the host's mistake, refused before the scan.
      for t <- [5, -3, 0.0, -0.0, 2.5, false, true, nil, :on, "0"] do
        assert_raise ArgumentError,
                     "state.env holds `t` outside its type: it is a bool, and only 0 or 1 " <>
                       "fit, found #{inspect(t)}",
                     fn -> run(@contacts, %{"t" => t}) end
      end
    end

    test "move from a tag the host left out copies 0, not nil" do
      src = "var s dint\nvar d dint\nmove s d"
      assert %{"d" => 0} = run(src, %{})
    end
  end

  describe "online edit (OE-1)" do
    # PLAN.md OE-1's Done-when, as it is worded, through the public API alone: source
    # compiled by Logex.compile/2, one instance scanned by Logex.Runtime, and a staged edit
    # by Logex.Edit (docs/organisation.md §4.9). M2-3's motor: the README's, with
    # `var t1 ton` and a rung `xic motor ton t1 5000`.
    @motor """
    var_input start bool
    var_input stop bool
    var_input overtemp bool
    var_input reset bool
    var_output motor bool
    var_output run_lamp bool
    var_output speed_sp dint 1200
    var fault bool
    var t1 ton

    ( xic start | xic motor ) xio stop ote motor
    xic motor ote run_lamp
    xic overtemp otl fault
    xic reset otu fault
    xic fault move 0 speed_sp
    xic motor ton t1 5000
    """

    # The candidate raises t1's preset, adds a second timer and an ons, and removes the rung
    # that drives the var_output run_lamp, and with it run_lamp's declaration, which
    # assemble then prunes. It keeps the motor's own rung, so t1's rung stays true. Its ons
    # moves a setpoint the original drives too, so it drives no new var_output: one that
    # did would rightly be held at untest, against the Done-when's "lists no undriven
    # output" (§4.9, Tests).
    @candidate """
    var_input start bool
    var_input stop bool
    var_input overtemp bool
    var_input reset bool
    var_output motor bool
    var_output speed_sp dint 1200
    var fault bool
    var t1 ton
    var t2 ton
    var s1 bool

    ( xic start | xic motor ) xio stop ote motor
    xic overtemp otl fault
    xic reset otu fault
    xic fault move 0 speed_sp
    xic motor ton t1 8000
    xic motor ton t2 2000
    xic motor ons s1 move 900 speed_sp
    """

    # An edit keeps the program's name, so both programs are `motor`.
    defp motor(src) do
      {:ok, program} = Logex.compile(src, name: "motor")
      program
    end

    # The motor started, then run in 10 ms scans until t1 is done, 5,000 ms later.
    defp running_with_t1_done(running) do
      steps = [{0, %{"start" => 1}}, {10, %{"start" => 0}} | List.duplicate({10, %{}}, 500)]
      {trace, state} = driven(running, Logex.Runtime.instance(running), steps)
      assert List.last(trace) == %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
      assert %{"pre" => 5000, "acc" => 5000, "dn" => 1} = state.env["t1"]
      state
    end

    # The parse tree of `src`, through the stages' public functions, as a host building a
    # program as data would start from it.
    defp tree(src) do
      {:ok, tokens, _end_line} = Logex.Compiler.tokenize(src)
      {:ok, tree} = Logex.Compiler.parse(tokens)
      tree
    end

    # `term` with every `from` in it, however deep, replaced by `to`: a change made to data
    # without naming any node of it.
    defp replace(from, from, to), do: to
    defp replace(list, from, to) when is_list(list), do: Enum.map(list, &replace(&1, from, to))

    defp replace(tuple, from, to) when is_tuple(tuple),
      do: tuple |> Tuple.to_list() |> replace(from, to) |> List.to_tuple()

    defp replace(other, _from, _to), do: other

    test "test, untest and assemble, over an instance running with t1 done" do
      running = motor(@motor)
      candidate = motor(@candidate)
      state = running_with_t1_done(running)

      {:ok, edit, forecast} = Logex.Edit.accept(running, candidate, state)
      assert Logex.Edit.running(edit) == running

      # Test runs the candidate with the decided .pre, initial values and no one-shot pulse,
      # and its report names the held output and the dropped .dn. Accept forecast it.
      {edit, state, report} = Logex.Edit.test(edit, state)

      assert report == [
               {:added, "s1", 0},
               {:added, "t2",
                %{"pre" => 2000, "acc" => 0, "dn" => 0, "tt" => 0, "en" => 0, "last" => 0}},
               {:dn_drops, "t1", {5000, 8000}},
               {:held, "run_lamp", 1},
               {:ons_blocked, "s1", 0},
               {:preset, "t1", {5000, 8000}}
             ]

      assert report == forecast
      assert Logex.Edit.running(edit) == candidate

      # The one-shot's rung is true on the switch scan, and the setpoint does not move. t1
      # times on from 5000 ms towards 8000, so its .dn drops; t2 starts timing from 0.
      {[outputs], state} = driven(candidate, state, [{10, %{}}])
      assert outputs == %{"motor" => 1, "speed_sp" => 1200}
      assert %{"pre" => 8000, "acc" => 5010, "dn" => 0} = state.env["t1"]
      assert %{"pre" => 2000, "acc" => 0, "dn" => 0, "en" => 1} = state.env["t2"]

      # 2,990 ms more: each timer is done at its preset, and the setpoint never pulses.
      {trace, state} = driven(candidate, state, List.duplicate({10, %{}}, 299))
      assert Enum.uniq(trace) == [outputs]
      assert %{"pre" => 8000, "acc" => 8000, "dn" => 1} = state.env["t1"]
      assert %{"pre" => 2000, "acc" => 2000, "dn" => 1} = state.env["t2"]

      # Untest runs the original over the same state, and its report lists no undriven
      # output. t1's .pre goes back to the one the test found; what the candidate added
      # stays, unused, until the edit ends.
      {edit, state, report} = Logex.Edit.untest(edit, state)
      assert report == [{:preset, "t1", {8000, 5000}}]
      refute List.keymember?(report, :held, 0)
      assert Logex.Edit.running(edit) == running

      {[outputs], state} = driven(running, state, [{10, %{}}])
      assert outputs == %{"motor" => 1, "run_lamp" => 1, "speed_sp" => 1200}
      assert %{"pre" => 5000, "acc" => 5000, "dn" => 1} = state.env["t1"]
      assert %{"s1" => 1, "t2" => %{"dn" => 1}} = state.env

      # Assemble is taken under test: a second test, then assemble at the same boundary, as
      # a host finalises without scanning the candidate again. Assemble prunes what only
      # the original declares, and its report names the held output.
      {edit, state, report} = Logex.Edit.test(edit, state)

      assert report == [
               {:dn_drops, "t1", {5000, 8000}},
               {:held, "run_lamp", 1},
               {:ons_blocked, "s1", 1},
               {:preset, "t1", {5000, 8000}},
               {:resumed, "t2", 10}
             ]

      {program, state, report} = Logex.Edit.assemble(edit, state)
      assert program == candidate
      assert report == [{:held, "run_lamp", 1}, {:pruned, "run_lamp", 1}]
      assert Enum.sort(Map.keys(state.env)) == Enum.sort(Map.keys(candidate.tags))

      # The candidate runs on, and its one-shot fires at the motor's next real start.
      assert {[
                %{"motor" => 1, "speed_sp" => 1200},
                %{"motor" => 0, "speed_sp" => 1200},
                %{"motor" => 1, "speed_sp" => 900}
              ], _state} =
               driven(candidate, state, [
                 {10, %{}},
                 {10, %{"stop" => 1}},
                 {10, %{"stop" => 0, "start" => 1}}
               ])
    end

    # What the edit is for (§4.9, "What it fixes"): the same candidate swapped in with no
    # edit, a plain swap, pulses its new one-shot, keeps t1 at the old preset and done, and
    # starts t2 at a preset of 0, done on its first scan.
    test "without an edit, a plain swap of the same candidate pulses and keeps t1's old preset" do
      state = running_with_t1_done(motor(@motor))
      {[outputs], state} = driven(motor(@candidate), state, [{10, %{}}])
      assert outputs == %{"motor" => 1, "speed_sp" => 900}
      assert %{"pre" => 5000, "dn" => 1} = state.env["t1"]
      assert %{"pre" => 0, "acc" => 0, "dn" => 1} = state.env["t2"]
    end

    test "a type change is refused at accept" do
      running = motor(@motor)
      state = running_with_t1_done(running)

      # The candidate, keeping run_lamp's declaration, as a dint.
      retyped =
        motor(
          String.replace(
            @candidate,
            "var_output speed_sp",
            "var_output run_lamp dint\nvar_output speed_sp"
          )
        )

      assert {:error, [%Logex.Diagnostic{stage: :edit} = diagnostic]} =
               Logex.Edit.accept(running, retyped, state)

      assert Logex.Diagnostic.format(diagnostic) ==
               "line 6: `run_lamp` is a bool in the running program and a dint in the " <>
                 "candidate: a tag's type changes only with a restart"
    end

    # The data path refuses what the text cannot say where the data enters, so accept
    # needs no check of its own (§4.9, "The data path"; validation_test.exs pins each
    # message and every malformed tree).
    test "a program built from data that the text cannot say is refused" do
      # The candidate built as data: its parse tree, and t2 declared from Elixir. Said as
      # the text can say it, it is a program.
      tree = tree(String.replace(@candidate, "var t2 ton\n", ""))
      t2 = Logex.Tag.new!("t2", Logex.FbType.ton())
      assert {:ok, %Logex.Program{}} = Logex.Compiler.instructionize(tree, [t2])

      # No text says `move 900.5 speed_sp`, since logex has no decimals, so the tree that
      # would is a host mistake. Matched by its rule: the rest of the message prints the
      # node, a shape of the tree. A negative literal lexes since M3-3 (decision 97), so
      # `move -900 speed_sp` is a tree the text says.
      error =
        assert_raise ArgumentError, fn ->
          Logex.Compiler.instructionize(replace(tree, 900, 900.5), [t2])
        end

      assert "not a tree Logex.Parser.parse/1 can produce: a literal is an integer, got: " <>
               _node = error.message

      assert {:ok, %Logex.Program{}} =
               Logex.Compiler.instructionize(replace(tree, 900, -900), [t2])

      # Nor does a declaration line give a timer its preset, or a tag a value that is no
      # integer.
      assert_raise ArgumentError,
                   "`t2` is a ton: its preset is the number on its `ton` instruction, as in " <>
                     "`ton t2 5000`, not an initial value on its declaration",
                   fn -> Logex.Tag.new!("t2", Logex.FbType.ton(), :var, %{"pre" => 2000}) end

      assert_raise ArgumentError,
                   "the initial value of `speed_sp` must be an integer, found 1.5",
                   fn -> Logex.Tag.new!("speed_sp", :dint, :var_output, 1.5) end
    end
  end

  describe "a configuration, run by the scheduler (M2-1)" do
    alias Logex.Configuration
    alias Logex.Configuration.{Connection, Global, Instance}

    @readme_motor """
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

    # One var_input copied to one var_output: what each instance below runs.
    @relay "var_input in bool\nvar_output out bool\nxic in ote out"

    # A 10 ms task and a 30 ms task, the 30 ms one first in priority (0) and last in
    # declaration, and a task-less instance declared between them, so neither declaration
    # order nor rate gives the order priority does. `s`, on the 30 ms task, samples the
    # input point `x` into the global `g`; `f`, on the 10 ms task, copies `g` to the output
    # point `y`, and the task-less `n` copies it to `z`.
    defp three_rates do
      Configuration.new!(
        name: "plant",
        programs: [program_named(@relay, "relay")],
        tasks: [
          %Configuration.Task{name: "fast", interval: 10, priority: 1},
          %Configuration.Task{name: "slow", interval: 30, priority: 0}
        ],
        globals: [
          %Global{name: "x", type: :bool, at: "panel.i.0"},
          %Global{name: "g", type: :bool},
          %Global{name: "y", type: :bool, at: "panel.q.0"},
          %Global{name: "z", type: :bool, at: "panel.q.1"}
        ],
        instances: [
          %Instance{name: "f", type: "relay", task: "fast"},
          %Instance{name: "n", type: "relay"},
          %Instance{name: "s", type: "relay", task: "slow"}
        ],
        connections: [
          %Connection{instance: "f", member: "in", to: "g"},
          %Connection{instance: "f", member: "out", to: "y"},
          %Connection{instance: "n", member: "in", to: "g"},
          %Connection{instance: "n", member: "out", to: "z"},
          %Connection{instance: "s", member: "in", to: "x"},
          %Connection{instance: "s", member: "out", to: "g"}
        ]
      )
    end

    defp program_named(source, name) do
      {:ok, program} = Logex.compile(source, name: name)
      program
    end

    # Cycles of a resource, each step `{elapsed_ms, inputs}`: `{runtime, trace}`, the trace
    # a `{now, outputs, events}` for each cycle.
    defp cycles(runtime, steps) do
      {trace, {runtime, _now}} =
        Enum.map_reduce(steps, {runtime, 0}, fn {elapsed, inputs}, {runtime, now} ->
          {runtime, outputs, events} = Logex.Runtime.cycle(runtime, elapsed, inputs)
          {{now + elapsed, outputs, events}, {runtime, now + elapsed}}
        end)

      {runtime, trace}
    end

    defp ran(trace, instance),
      do: for({_now, _outputs, events} <- trace, {:ran, _task, ^instance, now} <- events, do: now)

    # `x` is 1 for two cycles in every seven, so that a 30 ms sample of it differs from a
    # 10 ms one.
    defp x_at(now), do: bit(rem(div(now, 10), 7) in [3, 4])

    test "M2-1's Done-when: a 10 ms task, a 30 ms task and a task-less instance, cycled " <>
           "every 10 ms from 0 to 990 ms, each run as often as its task dictates, in " <>
           "priority order" do
      times = Enum.to_list(0..990//10)
      steps = Enum.map(times, &{elapsed(&1), %{"x" => x_at(&1)}})
      {runtime, trace} = cycles(Logex.Runtime.start(three_rates()), steps)

      # As often as its task dictates: every cycle at 10 ms, every third at 30 ms, and the
      # task-less instance in every cycle.
      assert ran(trace, "f") == times
      assert ran(trace, "s") == Enum.filter(times, &(rem(&1, 30) == 0))
      assert ran(trace, "n") == times

      assert {100, 34, 100} ==
               {length(ran(trace, "f")), length(ran(trace, "s")), length(ran(trace, "n"))}

      # In priority order: in every cycle the 30 ms task's instance, when due, runs first,
      # then the 10 ms task's, then the task-less one, last.
      for {now, _outputs, events} <- trace do
        order = for {:ran, _task, instance, _now} <- events, do: instance
        assert order == run_order(rem(now, 30)), "at #{now} ms"
      end

      # Seen in the outputs too, without the events: `y` and `z` show `x` as `s` last
      # sampled it, in the same cycle, which `f` and `n` see only because `s` ran before
      # them. In declaration order `f` would show the sample before.
      for {now, outputs, _events} <- trace do
        sampled = x_at(now - rem(now, 30))
        assert outputs == %{"y" => sampled, "z" => sampled}, "at #{now} ms"
      end

      assert Logex.Runtime.overlaps(runtime) == %{"fast" => 0, "slow" => 0}
    end

    test "M2-1's Done-when: a late cycle yields one {:overlap, ...} and no lost phase" do
      steps =
        [{0, %{}}] ++
          List.duplicate({10, %{}}, 50) ++ [{25, %{}}, {5, %{}}] ++ List.duplicate({10, %{}}, 46)

      {runtime, trace} = cycles(Logex.Runtime.start(three_rates()), steps)
      assert [{_, _, _} | _] = trace
      assert {990, _, _} = List.last(trace)

      # One overlap, at the late cycle, for the one period of the 10 ms task it missed: due
      # at 510 ms, run at 525 ms, its 520 ms period counted, not run. The 30 ms task, due at
      # 510 ms too, missed no period, so has none.
      assert for({_now, _outputs, events} <- trace, {:overlap, _, _} = e <- events, do: e) ==
               [{:overlap, "fast", 1}]

      # Reported before its task's scans, in the order the cycle ran them: the 30 ms task
      # first, by priority.
      assert [{525, _, events}] = Enum.filter(trace, fn {now, _, _} -> now == 525 end)

      assert events == [
               {:ran, "slow", "s", 525},
               {:overlap, "fast", 1},
               {:ran, "fast", "f", 525},
               {:ran, :none, "n", 525}
             ]

      # No lost phase: after the late cycle each task runs on its own multiples again.
      assert ran(trace, "f") == Enum.to_list(0..500//10) ++ [525] ++ Enum.to_list(530..990//10)
      assert ran(trace, "s") == Enum.to_list(0..480//30) ++ [525] ++ Enum.to_list(540..990//30)
      assert Logex.Runtime.overlaps(runtime) == %{"fast" => 1, "slow" => 0}
    end

    # Or the two runtimes drift apart (docs/organisation.md §4.6). The README's steps, then
    # a seeded walk of input changes, and a cold or warm restart of each side now and
    # then: `restart/3` on the lone instance, `restart/2` on the configuration, each of
    # which keeps the host's input image, so the host sends nothing again after one.
    test "M2-1's Done-when: the README program gives identical outputs through scan/2 and " <>
           "through a one-instance configuration" do
      motor = program_named(@readme_motor, "motor")

      readme = [
        %{"start" => 1},
        %{"start" => 0},
        %{"overtemp" => 1},
        %{"stop" => 1},
        %{"stop" => 0, "overtemp" => 0},
        %{"reset" => 1},
        %{"reset" => 0, "start" => 1}
      ]

      :rand.seed(:exsss, {2026, 10, 2})

      walk =
        for _ <- 1..300 do
          Map.new(
            Enum.take_random(~w(start stop overtemp reset), :rand.uniform(3)),
            &{&1, :rand.uniform(2) - 1}
          )
        end

      steps = Enum.map(readme, &{0, &1, nil}) ++ Enum.map(walk, &{0, &1, restart_now()})
      assert Enum.any?(steps, &match?({_, _, mode} when mode != nil, &1))
      side_by_side(motor, steps, "m.fault", &[&1.env["fault"]])
    end

    # And with time: M2-3's motor, its timer stepped through scan/3 and through cycles at
    # the same elapsed times, which a task-less instance takes as they come, restarts
    # included.
    test "a timed program agrees through scan/3 and a one-instance configuration" do
      timed =
        String.replace(@readme_motor, "var fault bool\n", "var fault bool\nvar t1 ton\n") <>
          "xic motor ton t1 500\n"

      motor = program_named(timed, "motor")
      :rand.seed(:exsss, {2026, 10, 3})

      walk =
        for _ <- 1..300 do
          {:rand.uniform(40) - 1,
           Map.new(Enum.take_random(~w(start stop), 1), &{&1, :rand.uniform(2) - 1}),
           restart_now()}
        end

      steps = [{0, %{"start" => 1}, nil}, {7, %{"start" => 0}, nil} | walk]
      side_by_side(motor, steps, "m.t1.acc", &[&1.env["t1"]["acc"]])
    end

    # One step in 30 restarts both sides, cold or warm.
    defp restart_now, do: Enum.at([:cold, :warm | List.duplicate(nil, 28)], :rand.uniform(30) - 1)

    # Each step `{elapsed_ms, inputs, restart}` on both sides: the lone instance through
    # put_inputs/3, restart/3 and scan/3, the configuration through restart/2 and cycle/3.
    # Their outputs are equal at every step, and so is the tag read at `path`.
    defp side_by_side(motor, steps, path, read) do
      Enum.reduce(
        steps,
        {Logex.Runtime.instance(motor), Logex.Runtime.start(one_instance(motor))},
        fn {elapsed, inputs, mode}, {state, runtime} ->
          {state, runtime} = restarted(motor, state, runtime, mode)
          state = Logex.Runtime.put_inputs(motor, state, inputs)
          {scanned, state} = Logex.Runtime.scan(motor, state, elapsed)
          {runtime, cycled, _events} = Logex.Runtime.cycle(runtime, elapsed, inputs)
          assert scanned == cycled
          assert [Logex.Runtime.get!(runtime, path)] == read.(state)
          {state, runtime}
        end
      )
    end

    defp restarted(_motor, state, runtime, nil), do: {state, runtime}

    defp restarted(motor, state, runtime, mode),
      do: {Logex.Runtime.restart(motor, state, mode), Logex.Runtime.restart(runtime, mode)}

    # The README motor in a configuration of one task-less instance: an input point named
    # after each var_input, an output point after each var_output, each connected to it.
    defp one_instance(program) do
      tags = program.tags |> Map.values() |> Enum.sort_by(& &1.name)
      inputs = for %Logex.Tag{section: :var_input} = tag <- tags, do: tag
      outputs = for %Logex.Tag{section: :var_output} = tag <- tags, do: tag

      points =
        Enum.with_index(inputs, &%Global{name: &1.name, type: &1.type, at: "panel.i.#{&2}"}) ++
          Enum.with_index(outputs, &%Global{name: &1.name, type: &1.type, at: "panel.q.#{&2}"})

      Configuration.new!(
        name: "plant",
        programs: [program],
        globals: points,
        instances: [%Instance{name: "m", type: program.name}],
        connections:
          Enum.map(inputs ++ outputs, &%Connection{instance: "m", member: &1.name, to: &1.name})
      )
    end
  end

  describe "user function blocks (M2-5)" do
    alias Logex.Configuration
    alias Logex.Configuration.{Connection, Global, Instance}

    @seal_block """
    function_block seal
    var_input start bool
    var_input stop bool
    var_output run bool

    ( xic start | xic run ) xio stop ote run
    """

    # Three instances of one seal-in, the third run under an enable, and a lamp that reads
    # the second's output.
    @three_seals """
    var_input a1 bool
    var_input a2 bool
    var_input a3 bool
    var_input stop bool
    var_input en3 bool
    var_output k1 bool
    var_output k2 bool
    var_output k3 bool
    var_output lamp bool
    var s1 seal
    var s2 seal
    var s3 seal

    cal s1 a1 stop k1
    cal s2 a2 stop k2
    xic en3 cal s3 a3 stop k3
    xic s2.run ote lamp
    """

    # The program, with its block, in a configuration of one task-less instance `m1`, each
    # var_input wired to an input point and each var_output to an output point of its name.
    defp seals do
      {:ok, seal} = Logex.compile(@seal_block, name: "seal")
      {:ok, motor} = Logex.compile(@three_seals, name: "motor", types: [seal])
      configured(motor)
    end

    defp configured(motor) do
      tags = motor.tags |> Map.values() |> Enum.sort_by(& &1.name)
      inputs = for %Logex.Tag{section: :var_input} = tag <- tags, do: tag.name
      outputs = for %Logex.Tag{section: :var_output} = tag <- tags, do: tag.name

      config =
        Configuration.new!(
          name: "plant",
          programs: [motor],
          globals:
            Enum.with_index(inputs, &%Global{name: &1, type: :bool, at: "panel.i.#{&2}"}) ++
              Enum.with_index(outputs, &%Global{name: &1, type: :bool, at: "panel.q.#{&2}"}),
          instances: [%Instance{name: "m1", type: "motor"}],
          connections:
            Enum.map(inputs ++ outputs, &%Connection{instance: "m1", member: &1, to: &1})
        )

      Logex.Runtime.start(config)
    end

    defp cycled(runtime, steps),
      do:
        Enum.reduce(steps, {runtime, nil}, fn {elapsed, inputs}, {runtime, _} ->
          {runtime, outputs, _events} = Logex.Runtime.cycle(runtime, elapsed, inputs)
          {runtime, outputs}
        end)

    test "M2-5's Done-when: a seal-in written once as a function block and instantiated " <>
           "three times in one program behaves as three independent seal-ins, and " <>
           "m1.s2.run reads one of them" do
      {rt, outputs} = cycled(seals(), [{0, %{"a1" => 1, "en3" => 1}}])
      assert outputs == %{"k1" => 1, "k2" => 0, "k3" => 0, "lamp" => 0}

      {rt, outputs} = cycled(rt, [{10, %{"a1" => 0, "a2" => 1}}, {10, %{"a2" => 0}}])
      assert outputs == %{"k1" => 1, "k2" => 1, "k3" => 0, "lamp" => 1}
      assert Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 1}
      assert Logex.Runtime.get!(rt, "m1.s2.run") == 1
      assert Logex.Runtime.get(rt, "m1.s3.run") == {:ok, 0}

      {rt, outputs} = cycled(rt, [{10, %{"a3" => 1}}])
      assert outputs == %{"k1" => 1, "k2" => 1, "k3" => 1, "lamp" => 1}

      {rt, outputs} = cycled(rt, [{10, %{"a3" => 0, "stop" => 1}}])
      assert outputs == %{"k1" => 0, "k2" => 0, "k3" => 0, "lamp" => 0}
      assert Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 0}
    end

    test "M2-5's Done-when: a false EN freezes only its own instance, and the tags its " <>
           "outputs name" do
      {rt, _} =
        cycled(seals(), [{0, %{"a1" => 1, "a3" => 1, "en3" => 1}}, {10, %{"a1" => 0, "a3" => 0}}])

      {:ok, frozen} = Logex.Runtime.get(rt, "m1.s3.stop")

      # s3's EN falls, then stop: s1 drops out, s3 and k3 hold, not even reading stop in.
      {rt, outputs} = cycled(rt, [{10, %{"en3" => 0, "stop" => 1}}])
      assert outputs == %{"k1" => 0, "k2" => 0, "k3" => 1, "lamp" => 0}
      assert Logex.Runtime.get(rt, "m1.s3.stop") == {:ok, frozen}
      assert Logex.Runtime.get(rt, "m1.s1.stop") == {:ok, 1}

      # Its EN back with stop still pressed, s3 runs and drops out at once.
      {_rt, outputs} = cycled(rt, [{10, %{"en3" => 1}}])
      assert outputs == %{"k1" => 0, "k2" => 0, "k3" => 0, "lamp" => 0}
    end

    # The same, from files on disk: compile_file/1 finds `seal.ld` beside the program that
    # names it (decision 34), and every diagnostic names its file and line.
    # A loader that missed the chain of a.ld and b.ld would recurse until the default
    # minute ran out: a chain is found in a few milliseconds.
    @tag :tmp_dir
    @tag timeout: 10_000
    test "M2-5's Done-when from files on disk, through compile_file/1", %{tmp_dir: dir} do
      write = fn name, text ->
        path = Path.join(dir, name)
        File.write!(path, text)
        path
      end

      formatted = fn {:error, diagnostics} ->
        Enum.map(diagnostics, &Logex.Diagnostic.format/1)
      end

      write.("seal.ld", @seal_block)
      motor = write.("motor.ld", @three_seals)
      {:ok, program} = Logex.compile_file(motor)
      assert program.name == "motor" and program.file == motor

      {rt, outputs} =
        cycled(configured(program), [
          {0, %{"a1" => 1, "en3" => 1}},
          {10, %{"a1" => 0, "a2" => 1}},
          {10, %{"a2" => 0}}
        ])

      assert outputs == %{"k1" => 1, "k2" => 1, "k3" => 0, "lamp" => 1}
      assert Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 1}

      # A false EN freezes s3 alone: sealed in, its EN falls, then stop drops s1 and s2.
      {rt, _} = cycled(rt, [{10, %{"a3" => 1}}, {10, %{"a3" => 0, "en3" => 0, "stop" => 1}}])
      assert Logex.Runtime.get(rt, "m1.s3.run") == {:ok, 1}
      assert Logex.Runtime.get(rt, "m1.s2.run") == {:ok, 0}

      loop = write.("loop.ld", "function_block loop\nvar_input a bool\nvar x loop\ncal x a\n")

      assert formatted.(Logex.compile_file(loop)) == [
               "#{loop}: line 3: `loop` cannot hold an instance of `loop`: " <>
                 "a function block never holds an instance of itself"
             ]

      a = write.("a.ld", "function_block a\nvar_input go bool\nvar x b\ncal x go\n")
      b = write.("b.ld", "function_block b\nvar_input go bool\nvar y a\ncal y go\n")

      assert formatted.(Logex.compile_file(a)) == [
               "#{b}: line 3: `b` cannot hold an instance of `a` (b → a → b): " <>
                 "a function block never holds an instance of itself, at any depth"
             ]

      unknown = write.("unknown.ld", String.replace(@three_seals, "var s3 seal", "var s3 sael"))

      # The line declares nothing, and s3's use is excused: one mistake, one message.
      assert formatted.(Logex.compile_file(unknown)) == [
               "#{unknown}: line 12: unknown type `sael`: #{@has}, " <>
                 "and the function block `seal` — did you mean `seal`?"
             ]

      wired = write.("wired.ld", String.replace(@three_seals, "cal s1 a1", "cal a1 a1"))

      assert formatted.(Logex.compile_file(wired)) == [
               "#{wired}: line 14: `cal` runs an instance of a function block, but `a1` is a " <>
                 "bool (declared on line 1)"
             ]
    end

    test "M2-5's Done-when: a recursive type, an unknown function block type and a cal of " <>
           "a non-instance are each a located diagnostic" do
      formatted = fn {:error, diagnostics} ->
        Enum.map(diagnostics, &Logex.Diagnostic.format/1)
      end

      {:ok, seal} = Logex.compile(@seal_block, name: "seal")

      assert formatted.(Logex.compile(@seal_block <> "var inner seal\n", name: "seal")) == [
               "line 7: `var` after the first rung (line 6): declarations come first",
               "line 7: `seal` cannot hold an instance of `seal`: " <>
                 "a function block never holds an instance of itself"
             ]

      assert formatted.(
               Logex.compile("var s1 sael\nvar_input a bool\nxic a ote a",
                 name: "m",
                 types: [seal]
               )
             ) == [
               "line 1: unknown type `sael`: #{@has}, " <>
                 "and the function block `seal` — did you mean `seal`?",
               "line 3: `ote` writes `a`, a var_input (declared on line 2): " <>
                 "logic must not write an input"
             ]

      assert formatted.(
               Logex.compile("var x bool\nvar_input a bool\ncal x a a x",
                 name: "m",
                 types: [seal]
               )
             ) == [
               "line 3: `cal` runs an instance of a function block, but `x` is a bool " <>
                 "(declared on line 1)"
             ]
    end
  end

  describe "a configuration file, run by the scheduler (M2-3)" do
    alias Logex.Configuration

    # The snapshot docs/organisation.md §4.4's plant runs.
    @snapshot """
    var_input a bool
    var_input b bool
    var_output a_was bool
    var_output b_was bool

    xic a ote a_was
    xic b ote b_was
    """

    # docs/organisation.md §4.4's plant, cut from the document, without its event task,
    # which M2-6 brings: its `trip` line blanked, so every line keeps its number, and the
    # snapshot that `trip` runs left with no task, so it runs in every cycle.
    defp periodic_plant do
      [_before, rest] =
        String.split(File.read!("docs/organisation.md"), "```\n// plant.", parts: 2)

      [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
      plant |> String.replace(~r/^task trip .*$/m, "") |> String.replace(" with trip", "")
    end

    # What a motor's scan at `scanned` leaves, `{motor, t1.acc}`: 1 from the scan that saw
    # its start button until the one that saw its stop button, its timer counting the
    # clock's time since the first, and 0 and 0 while stopped. Each instance sees the first
    # start at 100 ms and the stop at 500 ms, and the second start at `restarted`.
    defp seen(scanned, _restarted) when scanned < 100, do: {0, 0}
    defp seen(scanned, _restarted) when scanned < 500, do: {1, scanned - 100}
    defp seen(scanned, restarted) when scanned < restarted, do: {0, 0}
    defp seen(scanned, restarted), do: {1, scanned - restarted}

    # PLAN.md M2-3's Done-when, as worded on 2026-10-02. The plant is read from its text by
    # Configuration.compile/3, the pure seam (docs/organisation.md §4.4), its program types
    # given as data: M2-3's motor, `@motor` above (the §4.2 one with `var t1 ton` and `xic
    # motor ton t1 5000`), and §4.4's snapshot.
    #
    # How the inputs are timed. An instance sees an input when a scan of it copies the
    # input in: `m1`, on the 10 ms task, in the cycle the input changes, and `m2`, on the
    # 50 ms task, at its next multiple of 50 ms. Each `t1` starts on the scan that first
    # sees its motor run, which adds nothing, and then adds the one clock's time since its
    # last scan, 10 ms at a time in `m1` and 50 ms in `m2`. So the two time alike per
    # rising edge, when both instances see the edge at one time. Both start buttons are
    # pressed at 100 ms, a time both tasks run, so where both scan the two `.acc`s agree;
    # both stop buttons at 500 ms, which both see, stop both; and both start buttons again
    # at 620 ms, which `m2` sees only at 650 ms, so its `.acc` is then 30 ms behind. In 990
    # ms neither is done. Had they run on, an edge both see would have them done at one
    # time too, since 5000 ms is a multiple of both periods: the condition PLAN.md M1-6's
    # two-rate tests, above, pin.
    test "M2-3's Done-when: §4.4's plant without its event task, cycled every 10 ms from 0 " <>
           "to 990 ms, runs m1 100 times and m2 20 times, and each t1 times against the one " <>
           "clock" do
      assert %Logex.Program{warnings: []} = motor = motor(@motor)
      programs = %{"motor" => motor, "snapshot" => program_named(@snapshot, "snapshot")}
      assert {:ok, plant} = Configuration.compile("plant", periodic_plant(), programs)

      assert Enum.map(plant.tasks, &{&1.name, &1.interval, &1.priority}) ==
               [{"fast", 10, 1}, {"slow", 50, 2}]

      assert Enum.map(plant.instances, &{&1.name, &1.task}) ==
               [{"m1", "fast"}, {"m2", "slow"}, {"snap", nil}]

      # `estop` is read by §4.3's motor through a var_external, which M2-4 brings.
      assert Enum.map(plant.warnings, &Logex.Diagnostic.format/1) ==
               ["line 6: warning: `estop` is declared but nothing uses it"]

      # The host sends what changes, when it changes: the input image keeps the rest.
      presses = %{
        100 => %{"pb_start_1" => 1, "pb_start_2" => 1},
        110 => %{"pb_start_1" => 0, "pb_start_2" => 0},
        500 => %{"pb_stop_1" => 1, "pb_stop_2" => 1},
        510 => %{"pb_stop_1" => 0, "pb_stop_2" => 0},
        620 => %{"pb_start_1" => 1, "pb_start_2" => 1},
        700 => %{"pb_start_1" => 0, "pb_start_2" => 0}
      }

      times = Enum.to_list(0..990//10)
      steps = Enum.zip([0 | List.duplicate(10, 99)], times)

      {cycled, runtime} =
        Enum.map_reduce(steps, Logex.Runtime.start(plant), fn {elapsed, now}, runtime ->
          {runtime, outputs, events} =
            Logex.Runtime.cycle(runtime, elapsed, Map.get(presses, now, %{}))

          timers =
            {Logex.Runtime.get!(runtime, "m1.t1.acc"), Logex.Runtime.get!(runtime, "m2.t1.acc")}

          {{{now, outputs, events}, {now, outputs, timers}}, runtime}
        end)

      {trace, timed} = Enum.unzip(cycled)

      # As often as its task dictates: `m1` in every cycle and `m2` in every fifth, from
      # the first, and the snapshot, with no task, in every cycle.
      assert ran(trace, "m1") == times
      assert ran(trace, "m2") == Enum.filter(times, &(rem(&1, 50) == 0))
      assert ran(trace, "snap") == times
      assert {length(ran(trace, "m1")), length(ran(trace, "m2"))} == {100, 20}
      assert Logex.Runtime.overlaps(runtime) == %{"fast" => 0, "slow" => 0}

      # Each motor and its `t1.acc` as its last scan left them: `m1`'s scan in this cycle,
      # and `m2`'s at the last multiple of 50 ms.
      for {now, outputs, {m1, m2}} <- timed do
        assert {outputs["k1"], m1} == seen(now, 620), "m1 at #{now} ms"
        assert {outputs["k2"], m2} == seen(now - rem(now, 50), 650), "m2 at #{now} ms"
      end

      # Where both scan, `m1`'s lead: none after the start both saw at one time, and 30 ms
      # after the one `m2` saw 30 ms late.
      lead = for {now, _outputs, {m1, m2}} <- timed, rem(now, 50) == 0, do: {now, m1 - m2}
      assert for({now, ms} <- lead, now in 100..450, uniq: true, do: ms) == [0]
      assert for({now, ms} <- lead, now >= 650, uniq: true, do: ms) == [30]

      # Neither is done, each `.pre` the preset on its `ton`.
      for timer <- ~w(m1.t1 m2.t1) do
        assert {Logex.Runtime.get!(runtime, timer <> ".pre"),
                Logex.Runtime.get!(runtime, timer <> ".dn")} == {5000, 0}
      end
    end
  end

  describe "a configuration file on disk (M2-2)" do
    @describetag :tmp_dir

    # One program type, a seal-in whose run lamp lights 30 ms after it seals in: two
    # pieces of state, the seal and its timer.
    @motor_ld """
    var_input start bool
    var_input stop bool
    var_output motor bool
    var_output run_lamp bool
    var t1 ton

    ( xic start | xic motor ) xio stop ote motor
    xic motor ton t1 30
    xic t1.dn ote run_lamp
    """

    # Two instances of it, task-less, wired to different points.
    @plant_logex """
    // plant.logex -- two conveyors, one program type (motor.ld)
    var_global pb_start_1 bool at panel.i.0
    var_global pb_stop_1  bool at panel.i.1
    var_global pb_start_2 bool at panel.i.2
    var_global pb_stop_2  bool at panel.i.3
    var_global k1         bool at panel.q.0
    var_global k2         bool at panel.q.1
    var_global lamp_1     bool at panel.q.2
    var_global lamp_2     bool at panel.q.3

    program m1 motor
      m1.start    pb_start_1
      m1.stop     pb_stop_1
      m1.motor    k1
      m1.run_lamp lamp_1

    program m2 motor
      m2.start    pb_start_2
      m2.stop     pb_stop_2
      m2.motor    k2
      m2.run_lamp lamp_2
    """

    defp on_disk(dir, files) do
      for {name, text} <- files, into: %{} do
        path = Path.join(dir, name)
        File.write!(path, text)
        {name, path}
      end
    end

    # The input image at `now`: each button pressed for one window, so each instance seals
    # in, runs and is stopped at its own times. The host sends the whole image each cycle.
    defp image(now),
      do: %{
        "pb_start_1" => pressed(now, 20, 40),
        "pb_stop_1" => pressed(now, 300, 310),
        "pb_start_2" => pressed(now, 150, 160),
        "pb_stop_2" => pressed(now, 420, 450)
      }

    defp pressed(now, from, to) when now >= from and now < to, do: 1
    defp pressed(_now, _from, _to), do: 0

    # An oracle for one seal-in instance that knows nothing of logex: it seals in on start,
    # drops on stop, and lights its lamp once it has been sealed in for 30 ms, its timer
    # starting on the scan that seals it in.
    defp oracle({start, stop}, now, {motor, since}) do
      sealed = (start == 1 or motor == 1) and stop == 0
      since = since(sealed, motor == 1, since, now)
      {sealed, since, lamp(sealed, since, now)}
    end

    defp since(false, _was, _since, _now), do: nil
    defp since(true, true, since, _now), do: since
    defp since(true, false, _since, now), do: now

    defp lamp(true, since, now) when now - since >= 30, do: 1
    defp lamp(_sealed, _since, _now), do: 0

    # The first cycle starts the clock; each after it is 10 ms on.
    defp elapsed(0), do: 0
    defp elapsed(_now), do: 10

    defp bit(true), do: 1
    defp bit(false), do: 0

    # The oracles' clauses (decision 264): the order of M2-1's runs in a cycle, the 30 ms
    # task's first where it is due.
    defp run_order(0), do: ~w(s f n)
    defp run_order(_late), do: ~w(f n)

    # A list of one where its condition holds, and none where not.
    defp noted(true, entry), do: [entry]
    defp noted(false, _entry), do: []

    # PLAN.md M2-2's Done-when: two instances of one `.ld` program type, wired in a
    # configuration file to different input and output points, run for N cycles from one
    # input image and keep independent state. Both files are on disk, and the
    # configuration's loader reads the program type beside the configuration.
    test "two instances of one .ld program type, wired in a configuration file, run N " <>
           "cycles from one input image and keep independent state",
         %{tmp_dir: dir} do
      %{"plant.logex" => plant} =
        on_disk(dir, [{"motor.ld", @motor_ld}, {"plant.logex", @plant_logex}])

      {:ok, config} = Logex.Configuration.compile_file(plant)
      assert {config.name, config.file, Map.keys(config.programs)} == {"plant", plant, ["motor"]}
      assert config.warnings == [] and config.programs["motor"].warnings == []

      runtime = Logex.Runtime.start(config)
      models = %{"m1" => {0, nil}, "m2" => {0, nil}}
      points = %{"m1" => {"pb_start_1", "pb_stop_1"}, "m2" => {"pb_start_2", "pb_stop_2"}}
      outs = %{"m1" => {"k1", "lamp_1"}, "m2" => {"k2", "lamp_2"}}

      # N = 60 cycles, every 10 ms from 0 to 590 ms, each from the one image of that time.
      {runtime, _models, seen} =
        for now <- 0..590//10, reduce: {runtime, models, []} do
          {runtime, models, seen} ->
            inputs = image(now)
            {runtime, outputs, _events} = Logex.Runtime.cycle(runtime, elapsed(now), inputs)

            {models, expected} =
              Enum.reduce(["m1", "m2"], {models, %{}}, fn m, {models, expected} ->
                {start, stop} = points[m]
                {sealed, since, lamp} = oracle({inputs[start], inputs[stop]}, now, models[m])
                {k, l} = outs[m]

                {Map.put(models, m, {bit(sealed), since}),
                 Map.merge(expected, %{k => bit(sealed), l => lamp})}
              end)

            assert outputs == expected, "at #{now} ms"
            {runtime, models, [{now, outputs} | seen]}
        end

      # Each instance's state is its own: at 160 ms `m2` has just sealed in, its lamp dark
      # while `m1`'s is lit; by 200 ms both lamps are lit; at 300 ms `m1` is stopped while
      # `m2` runs on; by 590 ms both have been stopped, each timer reset.
      assert {200, %{"k1" => 1, "lamp_1" => 1, "k2" => 1, "lamp_2" => 1}} in seen
      assert {160, %{"k1" => 1, "lamp_1" => 1, "k2" => 1, "lamp_2" => 0}} in seen
      assert {300, %{"k1" => 0, "lamp_1" => 0, "k2" => 1, "lamp_2" => 1}} in seen
      assert Logex.Runtime.get!(runtime, "m1.t1.acc") == 0
      assert Logex.Runtime.get!(runtime, "m2.t1.acc") == 0
      assert Logex.Runtime.get!(runtime, "m2.motor") == 0

      # And the same plant, one instance held, keeps the other's state: stopping `m1`
      # alone leaves `m2` sealed in.
      {runtime, outputs, _} =
        Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 1, "pb_start_2" => 1})

      assert {outputs["k1"], outputs["k2"]} == {1, 1}

      {_runtime, outputs, _} =
        Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 0, "pb_start_2" => 0, "pb_stop_1" => 1})

      assert {outputs["k1"], outputs["k2"]} == {0, 1}
    end

    # The Done-when's second half: a mis-wired, unknown, undriven-input or mistyped
    # connection is a located diagnostic naming its file and line.
    test "a mis-wired, unknown, undriven-input or mistyped connection is a located " <>
           "diagnostic naming its file and line",
         %{tmp_dir: dir} do
      %{"wired.logex" => wired} =
        on_disk(dir, [
          {"motor.ld", @motor_ld},
          {"wired.logex",
           """
           var_global pb_1 bool at panel.i.0
           var_global pb_2 bool at panel.i.1
           var_global k1   bool at panel.q.0
           var_global sp   dint
           program m1 motor
           m1.start pb_1
           m1.stop  pb_2
           m1.motor pb_1
           m1.strat pb_2
           program m2 motor
           m2.start sp
           m2.motor k9
           m2.run_lamp k1
           """}
        ])

      assert {:error, diagnostics} = Logex.Configuration.compile_file(wired)

      assert Enum.map(diagnostics, &Logex.Diagnostic.format/1) == [
               # mis-wired: a var_output driving an input point
               "#{wired}: line 8: `pb_1` is an input point (line 1): `m1.motor`, a " <>
                 "var_output, cannot drive it",
               # unknown: a member the program type does not declare
               "#{wired}: line 9: `m1` runs `motor`, which declares no `strat` — did you " <>
                 "mean `start`?",
               # undriven input: a var_input left unconnected
               "#{wired}: line 10: `m2` leaves its var_input `stop` unconnected: connect " <>
                 "it to a global, a point or a constant, as in `m2.stop 0`",
               # mistyped: a bool var_input connected to a dint
               "#{wired}: line 11: `m2.start` is a bool, but `sp` is a dint (line 4)",
               # unknown: a global the file does not declare
               "#{wired}: line 12: no global `k9`: declare it, as in `var_global k9 bool`"
             ]
    end
  end

  # PLAN.md M2-4's Done-when, as decision 46 has it tested: §4.4's plant, its `estop`
  # declared once, as an input point, and read by the two motors through `var_external`,
  # stops both in the same cycle where both run; and a pulse shorter than `m2`'s interval
  # never reaches `m2`, since an instance sees a global when it runs (§4.4).
  describe "a global shared through var_external (M2-4)" do
    @describetag :tmp_dir

    alias Logex.Configuration

    # docs/organisation.md's text, cut where it stands: §4.4's plant, without its event
    # task, its `trip` line blanked, so every line keeps its number, and the snapshot that
    # `trip` runs left with no task, as M2-4 landed it (M2-6's Done-when below runs the
    # plant whole); §4.3's seal-in block, and §4.3's
    # motor, written to use it, whose `estop` is a var_external; and §4.4's snapshot.
    defp document, do: File.read!("docs/organisation.md")

    defp cut(after_text) do
      [_before, rest] = String.split(document(), after_text, parts: 2)
      [_before, block] = String.split(rest, "```\n", parts: 2)
      [text, _after] = String.split(block, "```", parts: 2)
      text
    end

    defp shared_plant do
      [_before, rest] = String.split(document(), "```\n// plant.", parts: 2)
      [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
      plant |> String.replace(~r/^task trip .*$/m, "") |> String.replace(" with trip", "")
    end

    @snapshot_ld """
    var_input a bool
    var_input b bool
    var_output a_was bool
    var_output b_was bool

    xic a ote a_was
    xic b ote b_was
    """

    defp shared_programs do
      seal_ld = cut("**A function block type** is")
      motor_ld = cut("**The motor, rewritten to use it**")
      assert motor_ld =~ "var_external estop bool"
      assert {:ok, seal} = Logex.compile(seal_ld, name: "seal")

      assert {:ok, %Logex.Program{warnings: []} = motor} =
               Logex.compile(motor_ld, name: "motor", types: [seal])

      {:ok, snapshot} = Logex.compile(@snapshot_ld, name: "snapshot")

      {%{"motor" => motor, "snapshot" => snapshot},
       %{"seal.ld" => seal_ld, "motor.ld" => motor_ld}}
    end

    # The plant cycled every 10 ms from 0 to `last` ms, each cycle's inputs `image.(now)`:
    # each cycle's time, contactors and the instances it ran.
    defp cycled_plant(plant, image, last) do
      times = Enum.to_list(0..last//10)

      Enum.map_reduce(times, Logex.Runtime.start(plant), fn now, runtime ->
        {runtime, outputs, events} = Logex.Runtime.cycle(runtime, min(now, 10), image.(now))
        ran = for {:ran, _task, instance, _now} <- events, do: instance
        {{now, {outputs["k1"], outputs["k2"]}, ran}, runtime}
      end)
    end

    # Both start buttons pressed at 0 ms, which both tasks see, and released at 10 ms.
    defp contactors_at(true), do: {1, 1}
    defp contactors_at(false), do: {0, 0}

    defp started(0), do: %{"pb_start_1" => 1, "pb_start_2" => 1}
    defp started(10), do: %{"pb_start_1" => 0, "pb_start_2" => 0}
    defp started(_now), do: %{}

    defp held_from(at), do: fn now -> Map.merge(started(now), estop(now == at)) end
    defp estop(true), do: %{"estop" => 1}
    defp estop(false), do: %{}

    defp the_done_when(plant) do
      assert plant.warnings == []
      {trace, runtime} = cycled_plant(plant, held_from(50), 100)

      for {now, contactors, ran} <- trace do
        # `m1` runs every 10 ms, `m2` every 50: both at 50 ms, the cycle the e-stop rises.
        assert "m2" in ran == (rem(now, 50) == 0)
        expected = contactors_at(now < 50)
        assert contactors == expected, "at #{now} ms"
      end

      # The one e-stop, read as the global through each instance's var_external.
      for path <- ~w(estop m1.estop m2.estop),
          do: assert(Logex.Runtime.get(runtime, path) == {:ok, 1})

      for path <- ~w(m1.fault m2.fault), do: assert(Logex.Runtime.get!(runtime, path) == 1)
    end

    test "M2-4's Done-when: an e-stop declared once as a var_global and read by two " <>
           "instances through var_external stops both in the same cycle, from text" do
      {programs, _files} = shared_programs()
      assert {:ok, plant} = Configuration.compile("plant", shared_plant(), programs)
      the_done_when(plant)
    end

    test "M2-4's Done-when, from files on disk", %{tmp_dir: dir} do
      {_programs, files} = shared_programs()

      for {name, text} <-
            Map.merge(files, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => shared_plant()}),
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, plant} = Configuration.compile_file(Path.join(dir, "plant.logex"))
      the_done_when(plant)
    end

    test "an e-stop shorter than `m2`'s interval never reaches it: it must be held as long " <>
           "as the slowest interval that reads it (decision 46)" do
      {programs, _files} = shared_programs()
      {:ok, plant} = Configuration.compile("plant", shared_plant(), programs)

      # A 10 ms pulse at 20 ms: `m1` sees it and stops; `m2`, which runs at 0 and 50 ms,
      # never does.
      pulse = fn now -> Map.merge(started(now), %{"estop" => bit(now in [20])}) end
      {trace, runtime} = cycled_plant(plant, pulse, 100)

      for {now, {k1, k2}, _ran} <- trace do
        assert k1 == bit(now < 20), "k1 at #{now} ms"
        assert k2 == 1, "k2 at #{now} ms"
      end

      assert {Logex.Runtime.get!(runtime, "m1.fault"), Logex.Runtime.get!(runtime, "m2.fault")} ==
               {1, 0}
    end

    # §4.10, M2-6's tie-break, as M2-4 lets it be written: two writers of one global through
    # var_external, here in one task at one priority, each scan sees what the one before it
    # in the cycle wrote, and the later write stands.
    test "two instances that write one global through var_external: the later in the cycle " <>
           "stands, and each reads what the other last wrote" do
      {:ok, writer} =
        Logex.compile(
          "var_input v dint\nvar_output seen dint\nvar_external shared dint\n" <>
            "move shared seen\nmove v shared",
          name: "writer"
        )

      plant =
        Configuration.new!(
          name: "plant",
          programs: [writer],
          tasks: [%Configuration.Task{name: "t", interval: 10, priority: 0}],
          globals: [
            %Configuration.Global{name: "shared", type: :dint, initial: 7},
            %Configuration.Global{name: "s1", type: :dint, at: "drive.q.0"},
            %Configuration.Global{name: "s2", type: :dint, at: "drive.q.1"}
          ],
          instances: [
            %Configuration.Instance{name: "w1", type: "writer", task: "t"},
            %Configuration.Instance{name: "w2", type: "writer", task: "t"}
          ],
          connections: [
            %Configuration.Connection{instance: "w1", member: "v", to: 1},
            %Configuration.Connection{instance: "w1", member: "seen", to: "s1"},
            %Configuration.Connection{instance: "w2", member: "v", to: 2},
            %Configuration.Connection{instance: "w2", member: "seen", to: "s2"}
          ]
        )

      assert [%Logex.Diagnostic{severity: :warning}] = plant.warnings
      {runtime, first, _events} = Logex.Runtime.cycle(Logex.Runtime.start(plant), 0, %{})
      {runtime, second, _events} = Logex.Runtime.cycle(runtime, 10, %{})
      assert {first, second} == {%{"s1" => 7, "s2" => 1}, %{"s1" => 2, "s2" => 1}}
      assert Logex.Runtime.get(runtime, "shared") == {:ok, 2}
    end
  end

  # PLAN.md M2-6's Done-when, from Elixir data: an event task triggered from an input point
  # runs once per rising edge, before lower-priority tasks due in the same cycle, and runs
  # in cycle 1 if its trigger is already true. Its edges are found from the trace of the
  # input alone, which knows nothing of how the scheduler samples. The same from a
  # configuration file is below, with the task lines.
  describe "an event task (M2-6), from data" do
    alias Logex.Configuration

    @relay "var_input in bool\nvar_output out bool\nxic in ote out"

    # `trip`, an event task at priority 0 on the input point `estop`, runs `snap`; `slow`,
    # a 10 ms task at priority 2, runs `m`, so both are due in every cycle `estop` rises.
    defp tripped do
      {:ok, relay} = Logex.compile(@relay, name: "relay")

      Configuration.new!(
        name: "plant",
        programs: [relay],
        tasks: [
          %Configuration.Task{name: "slow", interval: 10, priority: 2},
          %Configuration.Task{name: "trip", single: "estop", priority: 0}
        ],
        globals: [
          %Configuration.Global{name: "estop", type: :bool, at: "panel.i.0"},
          %Configuration.Global{name: "x", type: :bool, at: "panel.i.1"},
          %Configuration.Global{name: "y", type: :bool, at: "panel.q.0"},
          %Configuration.Global{name: "z", type: :bool, at: "panel.q.1"}
        ],
        instances: [
          %Configuration.Instance{name: "m", type: "relay", task: "slow"},
          %Configuration.Instance{name: "snap", type: "relay", task: "trip"}
        ],
        connections:
          for(
            {instance, out} <- [{"m", "y"}, {"snap", "z"}],
            member <- ~w(in out),
            do: %Configuration.Connection{
              instance: instance,
              member: member,
              to: connected_to(member, out)
            }
          )
      )
    end

    # Each cycle's runs, `estop` set to each value of `trace` in turn, 10 ms apart.
    defp connected_to("in", _out), do: "x"
    defp connected_to(_member, out), do: out

    defp tripped_runs(config, trace) do
      trace
      |> Enum.map_reduce(Logex.Runtime.start(config), fn value, runtime ->
        {runtime, _outputs, events} = Logex.Runtime.cycle(runtime, 10, %{"estop" => value})
        {for({:ran, task, instance, _now} <- events, do: {task, instance}), runtime}
      end)
      |> elem(0)
    end

    # The cycles where the trace rises from 0 to 1, the trace starting from 0.
    defp rising(trace),
      do:
        for(
          {[before, now], cycle} <- Enum.with_index(Enum.chunk_every([0 | trace], 2, 1, :discard)),
          before == 0 and now == 1,
          do: cycle
        )

    test "M2-6's Done-when: it runs once per rising edge, before a lower-priority task due " <>
           "in the same cycle, and in cycle 1 if its trigger is already true" do
      for trace <- [[0, 1, 1, 0, 0, 1, 0, 1, 1, 1], [1, 1, 0, 1, 0, 0, 1, 1, 0, 1]] do
        runs = tripped_runs(tripped(), trace)

        tripped =
          for {cycle_runs, cycle} <- Enum.with_index(runs), {"trip", _} <- cycle_runs, do: cycle

        assert tripped == rising(trace)

        # The 10 ms task runs in every cycle, and after `trip` in each it runs.
        for {cycle_runs, cycle} <- Enum.with_index(runs) do
          expected = noted(cycle in tripped, {"trip", "snap"}) ++ [{"slow", "m"}]
          assert cycle_runs == expected, "cycle #{cycle + 1}"
        end
      end

      # In cycle 1: the second trace's trigger is 1 at once.
      assert hd(tripped_runs(tripped(), [1])) == [{"trip", "snap"}, {"slow", "m"}]
    end

    # docs/organisation.md §4.10, M2-6: the tie-break owed, in the form decision 47's
    # var_external lets it be written: an event task and a late periodic task of one
    # priority, both writing one global, and which write lands. The event task's due time
    # is the cycle's now, so the periodic task, late and due earlier, runs first, and the
    # event task's write stands, whichever is declared first; one due exactly at now ties,
    # and the order declared decides.
    test "an event task and a late periodic task of one priority, both writing one global: " <>
           "the write that lands" do
      {:ok, writer} =
        Logex.compile("var_input v dint\nvar_external shared dint\nmove v shared",
          name: "writer"
        )

      plant = fn tasks ->
        Configuration.new!(
          name: "plant",
          programs: [writer],
          tasks: tasks,
          globals: [
            %Configuration.Global{name: "trig", type: :bool, at: "panel.i.0"},
            %Configuration.Global{name: "shared", type: :dint}
          ],
          instances: [
            %Configuration.Instance{name: "wp", type: "writer", task: "p"},
            %Configuration.Instance{name: "we", type: "writer", task: "e"}
          ],
          connections: [
            %Configuration.Connection{instance: "wp", member: "v", to: 1},
            %Configuration.Connection{instance: "we", member: "v", to: 2}
          ]
        )
      end

      periodic = %Configuration.Task{name: "p", interval: 10, priority: 1}
      event = %Configuration.Task{name: "e", single: "trig", priority: 1}

      # Started at 0, where `p` runs alone; then the trigger rises at `at` ms.
      landed = fn tasks, at ->
        config = plant.(tasks)
        assert [%Logex.Diagnostic{severity: :warning}] = config.warnings
        {runtime, _, _} = Logex.Runtime.cycle(Logex.Runtime.start(config), 0, %{})
        {runtime, _, events} = Logex.Runtime.cycle(runtime, at, %{"trig" => 1})
        {Logex.Runtime.get!(runtime, "shared"), for({:ran, t, _, _} <- events, do: t)}
      end

      # At 15 `p` is 5 ms late: it runs first, and `e`'s write, 2, lands.
      assert landed.([event, periodic], 15) == {2, ["p", "e"]}
      assert landed.([periodic, event], 15) == {2, ["p", "e"]}

      # At 10 `p` is due exactly at now: the order declared decides.
      assert landed.([event, periodic], 10) == {1, ["e", "p"]}
      assert landed.([periodic, event], 10) == {2, ["p", "e"]}
    end
  end

  # PLAN.md M2-6's Done-when from source: §4.4's plant as written, its `trip` task on the
  # input point `estop` running the snapshot, with §4.3's motor and seal-in block and
  # §4.4's snapshot, from a configuration file's text and from files on disk. Its edges are
  # found from the trace of `estop` alone.
  describe "an event task (M2-6), from source" do
    @describetag :tmp_dir

    alias Logex.Configuration

    defp whole_plant do
      [_before, rest] = String.split(document(), "```\n// plant.", parts: 2)
      [plant, _after] = String.split("// plant." <> rest, "```", parts: 2)
      assert plant =~ "task trip single estop priority 0"
      plant
    end

    # The plant cycled every 10 ms from 0, `estop` at each value of `trace` in turn and
    # both start buttons pressed in the first cycle: each cycle's runs, as `{task,
    # instance}`, and the resource at the end.
    defp tripped_plant(plant, trace) do
      trace
      |> Enum.with_index()
      |> Enum.map_reduce(Logex.Runtime.start(plant), fn {estop, cycle}, runtime ->
        inputs = Map.merge(started(cycle * 10), %{"estop" => estop})
        {runtime, _outputs, events} = Logex.Runtime.cycle(runtime, min(cycle, 1) * 10, inputs)
        {for({:ran, task, instance, _now} <- events, do: {task, instance}), runtime}
      end)
    end

    defp rises(trace),
      do:
        for(
          {[before, now], cycle} <- Enum.with_index(Enum.chunk_every([0 | trace], 2, 1, :discard)),
          before == 0 and now == 1,
          do: cycle
        )

    defp the_event_done_when(plant) do
      assert plant.warnings == []

      for trace <- [[0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1], [1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1]] do
        {runs, _runtime} = tripped_plant(plant, trace)

        tripped =
          for {cycle_runs, cycle} <- Enum.with_index(runs), {"trip", _} <- cycle_runs, do: cycle

        # Once per rising edge, and in cycle 1 where `estop` is 1 at once.
        assert tripped == rises(trace)
        assert hd(trace) == 0 or 0 in tripped

        for {cycle_runs, cycle} <- Enum.with_index(runs) do
          # `m1` is due every cycle and `m2` every fifth: `trip`, priority 0, runs `snap`
          # first in each cycle it runs, before every lower-priority task due in it.
          due = [{"fast", "m1"}] ++ noted(rem(cycle, 5) == 0, {"slow", "m2"})
          expected = noted(cycle in tripped, {"trip", "snap"}) ++ due
          assert cycle_runs == expected, "cycle #{cycle + 1}"
        end
      end

      # `snap` reads the contactors as the cycle before the trip left them: both closed by
      # the start buttons at 0 ms, opened by the e-stop at 20 ms, which `snap` sees first.
      {_runs, runtime} = tripped_plant(plant, [0, 0, 1])
      assert Logex.Runtime.get!(runtime, "k1_at_trip") == 1
      assert Logex.Runtime.get!(runtime, "k2_at_trip") == 1
      assert Logex.Runtime.get!(runtime, "k1") == 0
    end

    test "M2-6's Done-when, from a configuration file's text" do
      {programs, _files} = shared_programs()
      assert {:ok, plant} = Configuration.compile("plant", whole_plant(), programs)
      the_event_done_when(plant)
    end

    test "M2-6's Done-when, from files on disk", %{tmp_dir: dir} do
      {_programs, files} = shared_programs()

      for {name, text} <-
            Map.merge(files, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => whole_plant()}),
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, plant} = Configuration.compile_file(Path.join(dir, "plant.logex"))
      the_event_done_when(plant)
    end
  end

  # PLAN.md OE-2's Done-when, as it is worded: §4.4's plant whole, with §4.3's motor and
  # seal-in block and §4.4's snapshot, from a configuration file's text and from files on
  # disk, changed by a candidate in all three kinds of file and edited while it runs,
  # through Logex.Configuration.Edit's steps and Logex.Runtime's cycles alone.
  describe "a staged edit of the running plant (OE-2)" do
    @describetag :tmp_dir

    alias Logex.Configuration
    alias Logex.Configuration.Edit, as: ConfigEdit

    # The candidate's files: `t1`'s preset raised and a one-shot added in `motor.ld`, whose
    # rung moves no output, and the global `alarm` read through a var_external; a member
    # added to `seal.ld`; and in `plant.logex`, `slow` cut from 50 to 20 ms, `snap` removed
    # and `alarm` declared, with an initial value.
    defp edited_files do
      motor =
        cut("**The motor, rewritten to use it**")
        |> String.replace("ton t1 5000", "ton t1 6000")
        |> String.replace(
          "var_external estop bool",
          "var_external estop bool\nvar_external alarm bool\nvar edge bool\nvar kick bool\nvar lit bool"
        )
        |> Kernel.<>("xic start ons edge ote kick\nxic alarm ote lit\n")

      seal =
        String.replace(
          cut("**A function block type** is"),
          "var_output run bool",
          "var_output run bool\nvar n dint 7"
        )

      plant =
        whole_plant()
        |> String.replace("task slow interval 50 priority 2", "task slow interval 20 priority 2")
        |> String.replace(~r/\nprogram snap snapshot with trip\n(  snap\..*\n)+/, "")
        |> String.replace(
          "var_global k2_at_trip bool",
          "var_global k2_at_trip bool\nvar_global alarm bool 1"
        )

      %{
        "motor.ld" => motor,
        "seal.ld" => seal,
        "plant.logex" => plant,
        "snapshot.ld" => @snapshot_ld
      }
    end

    # The same files, refused: `trip`'s single changed, a task added, `m2` moved to `fast`
    # and `sp_2` to another point in `plant.logex`, and `running_ms` made a bool in
    # `motor.ld`.
    defp refused_files do
      motor =
        cut("**The motor, rewritten to use it**")
        |> String.replace("var_output running_ms dint", "var_output running_ms bool")
        |> String.replace("xic motor move t1.acc running_ms", "xic motor ote running_ms")

      plant =
        whole_plant()
        |> String.replace(
          "task trip single estop priority 0",
          "task trip single pb_reset priority 0\ntask extra interval 5 priority 3"
        )
        |> String.replace("program m2 motor with slow", "program m2 motor with fast")
        |> String.replace(
          "var_global sp_2       dint at drive.q.1",
          "var_global sp_2       dint at drive.q.2"
        )

      %{
        "motor.ld" => motor,
        "seal.ld" => cut("**A function block type** is"),
        "plant.logex" => plant,
        "snapshot.ld" => @snapshot_ld
      }
    end

    defp compiled_from_text(files) do
      {:ok, seal} = Logex.compile(files["seal.ld"], name: "seal")
      {:ok, motor} = Logex.compile(files["motor.ld"], name: "motor", types: [seal])
      {:ok, snapshot} = Logex.compile(files["snapshot.ld"], name: "snapshot")

      {:ok, config} =
        Configuration.compile("plant", files["plant.logex"], %{
          "motor" => motor,
          "snapshot" => snapshot
        })

      config
    end

    defp compiled_from_disk(files, dir) do
      File.mkdir_p!(dir)
      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, config} = Configuration.compile_file(Path.join(dir, "plant.logex"))
      config
    end

    defp line_of(text, start),
      do: 1 + Enum.find_index(String.split(text, "\n"), &String.starts_with?(&1, start))

    defp oe2_done_when(original, candidate, refused, files) do
      # Running: both motors sealed in from 0 ms, `t1` timing; at 60 ms the start button
      # of `m1` is pressed again and held, so that a one-shot on it would fire.
      runtime = Logex.Runtime.start(original)
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 0, %{"pb_start_1" => 1, "pb_start_2" => 1})
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 0, "pb_start_2" => 0})

      runtime =
        Enum.reduce(20..50//10, runtime, fn _, rt -> elem(Logex.Runtime.cycle(rt, 10, %{}), 0) end)

      {runtime, outputs, _} = Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 1})
      assert {outputs["k1"], outputs["k2"]} == {1, 1}
      assert Logex.Runtime.get!(runtime, "m1.t1.acc") == 60
      assert Logex.Runtime.get!(runtime, "m2.t1.acc") == 50

      # `trip` then runs no instance: a warning, which stops nothing.
      assert Enum.any?(candidate.warnings, &(&1.message =~ "`trip`"))
      assert Logex.Runtime.get!(runtime, "snap.a_was") == 0

      # Accept, and test: the resource switched between two cycles.
      assert {:ok, edit, forecast} = ConfigEdit.accept(runtime, candidate)
      {edit, runtime, report} = ConfigEdit.test(edit, runtime)
      assert report == forecast

      for entry <- [
            {:preset, "m1.t1", {5000, 6000}},
            {:preset, "m2.t1", {5000, 6000}},
            {:added, "m1.s1.n", 7},
            {:added, "m2.s1.n", 7},
            {:added, "alarm", 1},
            {:joined, "m1.alarm", {nil, 1}},
            {:joined, "m2.alarm", {nil, 1}},
            {:interval, "slow", {50, 20}},
            {:instance_stopped, "snap", "snapshot"},
            {:held, "k1_at_trip", 0}
          ],
          do: assert(entry in report, inspect(entry))

      refute Enum.any?(report, &match?({:instance_added, _, _}, &1))

      assert {Logex.Runtime.get!(runtime, "m1.t1.pre"), Logex.Runtime.get!(runtime, "m2.t1.pre")} ==
               {6000, 6000}

      # The next cycle runs the candidate: no instance restarted, no one-shot pulsed with
      # the start button held, and no event fired.
      {runtime, outputs, events} = Logex.Runtime.cycle(runtime, 10, %{})
      assert {outputs["k1"], outputs["k2"]} == {1, 1}
      assert Logex.Runtime.get!(runtime, "m1.t1.acc") == 70
      assert Logex.Runtime.get!(runtime, "m1.kick") == 0
      assert Logex.Runtime.get!(runtime, "m1.lit") == 1

      assert for({:ran, task, instance, _} <- events, do: {task, instance}) == [{"fast", "m1"}]

      # `slow` next due within 20 ms of the switch: at 80 ms, where 50 would have made it 100.
      {runtime, _, events} = Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 0})
      assert {:ran, "slow", "m2", 80} in events
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 10, %{"pb_start_1" => 1})
      assert Logex.Runtime.get!(runtime, "m1.kick") == 1

      # Untest: the original over the same resource, `snap` back as it was set aside.
      {edit, runtime, report} = ConfigEdit.untest(edit, runtime)
      assert {:instance_back, "snap", "snapshot"} in report
      refute Enum.any?(report, &match?({:resumed, "snap." <> _, _}, &1))
      assert Logex.Runtime.get!(runtime, "snap.a_was") == 0
      assert ConfigEdit.running(edit) == original
      {runtime, _, events} = Logex.Runtime.cycle(runtime, 10, %{"estop" => 1})
      assert {"trip", "snap"} in for({:ran, task, instance, _} <- events, do: {task, instance})
      assert Logex.Runtime.get!(runtime, "k1_at_trip") == 1
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 10, %{"estop" => 0, "pb_reset" => 1})
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 10, %{"pb_reset" => 0})

      # Test again, and assemble at the same boundary: `snap` pruned, and named.
      {edit, runtime, _} = ConfigEdit.test(edit, runtime)
      {kept, runtime, report} = ConfigEdit.assemble(edit, runtime)
      assert kept == candidate
      assert {:instance_pruned, "snap", "snapshot"} in report
      assert {:error, _} = Logex.Runtime.get(runtime, "snap.a")

      # A step on the edit that has ended is refused by the generation counter.
      assert_raise ArgumentError,
                   ~r/^this edit expects the resource at generation \d+, but it is at generation/,
                   fn ->
                     ConfigEdit.untest(edit, runtime)
                   end

      # Refused at accept, each at its line in plant.logex or motor.ld.
      assert {:error, diagnostics} = ConfigEdit.accept(Logex.Runtime.start(original), refused)
      plant = files["plant.logex"]
      motor = files["motor.ld"]

      assert Enum.map(diagnostics, &{&1.file && Path.basename(&1.file), &1.line, &1.message}) == [
               {plant_file(refused), line_of(plant, "task trip"),
                "task `trip`'s single changes from `estop` to `pb_reset`: a task's single changes only with a restart"},
               {plant_file(refused), line_of(plant, "task extra"),
                "task `extra` is added: a task is added only with a restart"},
               {plant_file(refused), line_of(plant, "var_global sp_2"),
                "`sp_2` is at `drive.q.1` in the running configuration and at `drive.q.2` in the candidate: located I/O changes only with a restart"},
               {plant_file(refused), line_of(plant, "program m2"),
                "`m2` runs with `slow` in the running configuration and with `fast` in the candidate: an instance moves to another task only with a restart"},
               {motor_file(refused), line_of(motor, "var_output running_ms"),
                "`running_ms` is a dint in the running program and a bool in the candidate: a tag's type changes only with a restart"}
             ]
    end

    defp plant_file(%Configuration{file: nil}), do: nil
    defp plant_file(%Configuration{}), do: "plant.logex"
    defp motor_file(%Configuration{programs: %{"motor" => %{file: nil}}}), do: nil
    defp motor_file(%Configuration{}), do: "motor.ld"

    test "OE-2's Done-when, from a configuration file's text" do
      {_programs, originals} = shared_programs()

      files =
        Map.merge(originals, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => whole_plant()})

      oe2_done_when(
        compiled_from_text(files),
        compiled_from_text(edited_files()),
        compiled_from_text(refused_files()),
        refused_files()
      )
    end

    test "OE-2's Done-when, from files on disk", %{tmp_dir: dir} do
      {_programs, originals} = shared_programs()

      files =
        Map.merge(originals, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => whole_plant()})

      oe2_done_when(
        compiled_from_disk(files, Path.join(dir, "running")),
        compiled_from_disk(edited_files(), Path.join(dir, "candidate")),
        compiled_from_disk(refused_files(), Path.join(dir, "refused")),
        refused_files()
      )
    end
  end

  # PLAN.md M3-1's Done-when, as worded on 2026-10-14: IEC's counters, each against an
  # oracle that knows nothing of logex, from text and from files on disk.
  describe "counters (M3-1)" do
    @boxes_ld """
    var_input eye bool
    var_input reset_pb bool
    var_output full_lamp bool
    var_output count dint
    var boxes ctu
    xic reset_pb ote boxes.r
    xic eye ctu boxes 12
    xic boxes.q ote full_lamp
    move boxes.cv count
    """

    @buffer_ld """
    var_input infeed bool
    var_input outfeed bool
    var_input clear bool
    var_input refill bool
    var_input portion bool
    var_output stock_count dint
    var_output buffer_full bool
    var_output buffer_empty bool
    var_output left dint
    var_output hopper_empty bool
    var stock ctud
    var hopper ctd
    xic clear ote stock.r
    xic infeed ctu stock 2
    xic outfeed ctd stock 2
    move stock.cv stock_count
    xic stock.qu ote buffer_full
    xic stock.qd ote buffer_empty
    xic refill ote hopper.ld
    xic portion ctd hopper 4
    move hopper.cv left
    xic hopper.q ote hopper_empty
    """

    # Each scan's inputs, seeded: a level held for a few scans at a time, a reset or a
    # load rarely.
    defp seeded(names, rare, n) do
      Enum.map_reduce(1..n, Map.new(names ++ rare, &{&1, 0}), fn _i, levels ->
        levels =
          Map.new(levels, fn {name, level} ->
            {name, flip(name in rare, level)}
          end)

        {levels, levels}
      end)
      |> elem(0)
    end

    defp flip(true, _level), do: bit(Enum.random(1..60) == 1)
    defp flip(false, level), do: Enum.random([level, level, 1 - level])

    defp box_scans(program, inputs, state \\ nil) do
      state = state || Logex.Runtime.instance(program)

      Enum.map_reduce(inputs, state, fn input, state ->
        Logex.Runtime.scan(program, Logex.Runtime.put_inputs(program, state, input), 10)
      end)
    end

    # The oracle: a box is counted on a scan whose eye is 1 where the last scan's was 0, but
    # never on the first scan, and none while the reset is held; the reset, on its rung
    # above the counter's, empties the count on its own scan.
    defp boxes_oracle(inputs) do
      {counts, _} =
        Enum.map_reduce(Enum.with_index(inputs), {0, 0}, fn {%{"eye" => eye} = input, i},
                                                            {count, last} ->
          count = box_counted(input["reset_pb"], i > 0 and eye == 1 and last == 0, count)
          {count, {count, eye}}
        end)

      counts
    end

    defp box_counted(1, _edge, _count), do: 0
    defp box_counted(_reset, true, count), do: count + 1
    defp box_counted(_reset, false, count), do: count

    defp boxes_checked(program) do
      :rand.seed(:exsss, {2026, 10, 14})
      inputs = seeded(["eye"], ["reset_pb"], 400)
      {outputs, _state} = box_scans(program, inputs)
      expected = boxes_oracle(inputs)

      assert Enum.map(outputs, & &1["count"]) == expected

      assert Enum.map(outputs, & &1["full_lamp"]) ==
               Enum.map(expected, &bit(&1 >= 12))

      assert Enum.max(expected) >= 12

      # A box on the eye at a reset is not counted again once the reset is let go.
      reset_on_eye =
        for {input, i} <- Enum.with_index(inputs),
            i > 0,
            input["reset_pb"] == 1 and input["eye"] == 1,
            do: i

      assert reset_on_eye != []
    end

    test "M3-1's Done-when: a box counter counts every rising edge of its photo-eye once, " <>
           "none on the first scan and none for a box on the eye at a reset, and lights the " <>
           "case-full lamp at its preset" do
      {:ok, program} = Logex.compile(@boxes_ld, name: "boxes")
      boxes_checked(program)

      # A box already on the eye at start is not counted.
      {[first | _], _} = box_scans(program, [%{"eye" => 1}, %{"eye" => 1}])
      assert first["count"] == 0
    end

    @tag :tmp_dir
    test "M3-1's Done-when from files on disk, through compile_file/1", %{tmp_dir: dir} do
      path = Path.join(dir, "boxes.ld")
      File.write!(path, @boxes_ld)
      {:ok, program} = Logex.compile_file(path)
      boxes_checked(program)

      buffer = Path.join(dir, "buffer.ld")
      File.write!(buffer, @buffer_ld)
      {:ok, program} = Logex.compile_file(buffer)
      buffer_checked(program)
    end

    # The buffer: each infeed edge adds one, each outfeed edge takes one away, the clear
    # empties it; the hopper is loaded full by the refill and each portion takes one away.
    defp buffer_oracle(inputs) do
      {rows, _} =
        Enum.map_reduce(Enum.with_index(inputs), {0, 0, %{}}, fn {input, i},
                                                                 {stock, left, last} ->
          rise = fn name -> i > 0 and input[name] == 1 and Map.get(last, name, 0) == 0 end

          stock = buffer_stock(input["clear"], stock, rise)
          left = hopper_left(input["refill"], left, rise)

          {{stock, left}, {stock, left, input}}
        end)

      rows
    end

    defp buffer_stock(1, _stock, _rise), do: 0

    defp buffer_stock(_clear, stock, rise),
      do: stock + bit(rise.("infeed")) - bit(rise.("outfeed"))

    defp hopper_left(1, _left, _rise), do: 4
    defp hopper_left(_refill, left, rise), do: hopper_portioned(rise.("portion"), left)

    defp hopper_portioned(true, left), do: left - 1
    defp hopper_portioned(false, left), do: left

    defp buffer_checked(program) do
      :rand.seed(:exsss, {2026, 10, 15})
      inputs = seeded(~w(infeed outfeed portion), ~w(clear refill), 400)
      {outputs, _state} = box_scans(program, inputs)
      expected = buffer_oracle(inputs)

      assert Enum.map(outputs, &{&1["stock_count"], &1["left"]}) == expected

      assert Enum.map(outputs, &{&1["buffer_full"], &1["buffer_empty"], &1["hopper_empty"]}) ==
               Enum.map(expected, fn {stock, left} ->
                 {bit(stock >= 2), bit(stock <= 0), bit(left <= 0)}
               end)

      assert Enum.any?(expected, fn {stock, _} -> stock >= 2 end)
      assert Enum.any?(expected, fn {stock, _} -> stock < 0 end)
      assert Enum.any?(expected, fn {_, left} -> left in 1..3 end)
    end

    test "M3-1's Done-when: a ctud buffer and a ctd hopper agree with an oracle that knows " <>
           "nothing of logex" do
      {:ok, program} = Logex.compile(@buffer_ld, name: "buffer")
      buffer_checked(program)
    end

    test "M3-1's Done-when: a count driven to the dint's top stops there with `ov` on until " <>
           "a reset" do
      {:ok, program} = Logex.compile(@boxes_ld, name: "boxes")
      state = %{Logex.Runtime.instance(program) | first: false}
      state = put_in(state.env["boxes"]["cv"], 2_147_483_645)
      inputs = for(eye <- [1, 0, 1, 0, 1, 0, 1, 0], do: %{"eye" => eye}) ++ [%{"reset_pb" => 1}]

      {seen, _state} =
        Enum.map_reduce(inputs, state, fn input, state ->
          {outputs, state} =
            Logex.Runtime.scan(program, Logex.Runtime.put_inputs(program, state, input), 10)

          {{outputs["count"], state.env["boxes"]["ov"]}, state}
        end)

      assert seen == [
               {2_147_483_646, 0},
               {2_147_483_646, 0},
               {2_147_483_647, 0},
               {2_147_483_647, 0},
               {2_147_483_647, 1},
               {2_147_483_647, 1},
               {2_147_483_647, 1},
               {2_147_483_647, 1},
               {0, 0}
             ]
    end

    test "M3-1's Done-when: an online edit that raises the preset while boxes are counted " <>
           "keeps the count, moves `pv`, forecasts `q`, and counts no box at the switch that " <>
           "was not a real edge" do
      {:ok, running} = Logex.compile(@boxes_ld, name: "boxes")

      {:ok, candidate} =
        @boxes_ld
        |> String.replace("ctu boxes 12", "ctu boxes 20")
        |> String.replace("var boxes ctu\n", "var boxes ctu\nvar rejects ctu\n")
        |> Kernel.<>("xic eye ctu rejects 5\n")
        |> Logex.compile(name: "boxes")

      # Thirteen boxes, the last still on the eye at the switch.
      inputs = [%{"eye" => 0}] ++ Enum.flat_map(1..13, fn _ -> [%{"eye" => 1}, %{"eye" => 0}] end)
      {outputs, state} = box_scans(running, Enum.drop(inputs, -1))
      assert List.last(outputs) == %{"count" => 13, "full_lamp" => 1}

      {:ok, edit, forecast} = Logex.Edit.accept(running, candidate, state)
      {edit, tested, report} = Logex.Edit.test(edit, state)
      assert report == forecast

      assert report == [
               {:added, "rejects", Logex.Program.initial_env(candidate)["rejects"]},
               {:dn_drops, "boxes", {13, 20}},
               {:ons_blocked, "rejects.cu", 0},
               {:preset, "boxes", {12, 20}}
             ]

      assert %{"cv" => 13, "pv" => 20} = tested.env["boxes"]

      # The box on the eye counts once, before the switch; the new counter counts nothing
      # for it; the next box counts in each.
      {outputs, later} =
        box_scans(candidate, [%{"eye" => 1}, %{"eye" => 0}, %{"eye" => 1}], tested)

      assert Enum.map(outputs, &{&1["count"], &1["full_lamp"]}) == [{13, 0}, {13, 0}, {14, 0}]
      assert later.env["rejects"]["cv"] == 1
      {_program, _state, _report} = Logex.Edit.assemble(edit, later)
    end
  end

  # PLAN.md M3-2's Done-when, as worded on 2026-10-14: a fan's tof runs it on for its
  # preset after the motor stops, two instances on 10 ms and 50 ms tasks stopping the fan at
  # the same logical time, as decision 6 measured ton; a tp sounds a horn for exactly its
  # preset from a fault's rising edge, whatever the fault does meanwhile, and not for a
  # fault present at start; an rto lubrication timer keeps its time across the motor
  # stopping and loses it only to its clear and a restart; and the event-task warning names
  # each. Each piece runs in one configuration through Logex.Runtime.cycle/3, against an
  # oracle in plain Elixir that knows nothing of logex.
  describe "the other timers (M3-2)" do
    alias Logex.Configuration

    @fan_ld """
    var_input motor bool
    var_output fan bool
    var run_on tof
    xic motor tof run_on 3000
    xic run_on.dn ote fan
    """

    @horn_ld """
    var_input fault bool
    var_output horn bool
    var_output fault_lamp bool
    var horn_pulse tp
    xic fault tp horn_pulse 3000
    xic horn_pulse.tt ote horn
    xic fault ote fault_lamp
    """

    @lube_ld """
    var_input conveyor bool
    var_input greased bool
    var_output grease_due bool
    var_output run_ms dint
    var lube rto
    xic greased ote lube.r
    xic conveyor rto lube 20000
    xic lube.dn ote grease_due
    move lube.acc run_ms
    """

    @line_logex """
    task fast interval 10 priority 1
    task slow interval 50 priority 2
    task trip single estop priority 0
    var_global estop bool at panel.i.0
    var_global motor bool at panel.i.1
    var_global fault bool at panel.i.2
    var_global conveyor bool at panel.i.3
    var_global greased bool at panel.i.4
    var_global fan_1 bool at panel.q.0
    var_global fan_2 bool at panel.q.1
    var_global horn bool at panel.q.2
    var_global fault_lamp bool at panel.q.3
    var_global grease_due bool at panel.q.4
    var_global run_ms dint
    program f1 fan with fast
    f1.motor motor
    f1.fan fan_1
    program f2 fan with slow
    f2.motor motor
    f2.fan fan_2
    program h1 horn with fast
    h1.fault fault
    h1.horn horn
    h1.fault_lamp fault_lamp
    program l1 lube with fast
    l1.conveyor conveyor
    l1.greased greased
    l1.grease_due grease_due
    l1.run_ms run_ms
    program f9 fan with trip
    f9.motor estop
    program h9 horn with trip
    h9.fault estop
    program l9 lube with trip
    l9.conveyor estop
    l9.greased 0
    """

    defp line_programs,
      do:
        Map.new([{"fan", @fan_ld}, {"horn", @horn_ld}, {"lube", @lube_ld}], fn {name, text} ->
          {:ok, program} = Logex.compile(text, name: name)
          {name, program}
        end)

    defp line_from_text do
      assert {:ok, line} = Configuration.compile("line", @line_logex, line_programs())
      line
    end

    defp line_from_files(dir) do
      for {name, text} <- [
            {"fan.ld", @fan_ld},
            {"horn.ld", @horn_ld},
            {"lube.ld", @lube_ld},
            {"line.logex", @line_logex}
          ],
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, line} = Configuration.compile_file(Path.join(dir, "line.logex"))
      line
    end

    # The line cycled every 10 ms from 0, each cycle's changes from `changes`, by its time:
    # each cycle's time and the globals named.
    defp line_cycles(runtime, last, changes, names) do
      Enum.map_reduce(0..last//10, runtime, fn now, runtime ->
        {runtime, _outputs, _events} =
          Logex.Runtime.cycle(runtime, elapsed(now), Map.get(changes, now, %{}))

        {{now, Map.new(names, &{&1, Logex.Runtime.get!(runtime, &1)})}, runtime}
      end)
    end

    defp fan_stops_together(line) do
      # The motor runs from 0 to 1000 ms, a time both tasks scan.
      {trace, _runtime} =
        line_cycles(
          Logex.Runtime.start(line),
          6000,
          %{0 => %{"motor" => 1}, 1000 => %{"motor" => 0}},
          ~w(fan_1 fan_2)
        )

      off = fn fan ->
        Enum.find_value(trace, fn {now, g} -> g[fan] == 0 and now > 0 and now end)
      end

      # On with the motor, through its 3 s run-on, and off at 4000 ms in both: the fast
      # instance's delay starts at its 1000 ms scan and the slow one's at its own, so each
      # is done at its first scan at or after 4000 ms, which both make.
      assert off.("fan_1") == 4000
      assert off.("fan_2") == 4000

      for {now, g} <- trace, now in 0..3990 do
        assert g["fan_1"] == 1, "fan_1 at #{now} ms"
      end

      for {now, g} <- trace, rem(now, 50) == 0, do: assert(g["fan_1"] == g["fan_2"], "at #{now}")
      assert Logex.Runtime.get!(Logex.Runtime.start(line), "f1.run_on.dn") == 0
    end

    # The line cycled at the elapsed times given, each with its changes: each cycle's time
    # and the globals named.
    defp line_at(runtime, steps, names) do
      {trace, _} =
        Enum.map_reduce(steps, {runtime, 0}, fn {elapsed, changes}, {runtime, now} ->
          {runtime, _outputs, _events} = Logex.Runtime.cycle(runtime, elapsed, changes)
          now = now + elapsed
          {{now, Map.new(names, &{&1, Logex.Runtime.get!(runtime, &1)})}, {runtime, now}}
        end)

      trace
    end

    defp horn_oracle(faults) do
      {horn, _} =
        Enum.map_reduce(Enum.with_index(faults), {0, nil}, fn {fault, i}, {prev, start} ->
          now = i * 10

          {on, start} = horn_pulse(start, now, i > 0 and fault == 1 and prev == 0)

          {on, {fault, start}}
        end)

      horn
    end

    # IEC's TP restated: a pulse of 3000 ms from a rising edge, an edge during it ignored.
    defp horn_pulse(nil, now, true), do: {1, now}
    defp horn_pulse(nil, _now, false), do: {0, nil}
    defp horn_pulse(start, now, _edge) when now - start >= 3000, do: {0, nil}
    defp horn_pulse(start, _now, _edge), do: {1, start}

    defp horn_sounds(line) do
      :rand.seed(:exsss, {2026, 10, 32})

      {faults, _} =
        Enum.map_reduce(0..1999, 0, fn _, level ->
          level = toggled(:rand.uniform(40) == 1, level)
          {level, level}
        end)

      changes = Map.new(Enum.with_index(faults), fn {f, i} -> {i * 10, %{"fault" => f}} end)
      {trace, _} = line_cycles(Logex.Runtime.start(line), 19_990, changes, ~w(horn fault_lamp))
      expected = horn_oracle(faults)

      for {{now, g}, {want, fault}} <- Enum.zip(trace, Enum.zip(expected, faults)) do
        assert g["horn"] == want, "horn at #{now} ms"
        assert g["fault_lamp"] == fault
      end

      # The seed gives pulses, the fault falling and rising inside one, and a pulse ending
      # with the fault still on: each pulse the trace sees end is exactly 3000 ms of horn.
      runs = Enum.chunk_by(Enum.with_index(expected), &elem(&1, 0))
      ended = Enum.reject(runs, &(elem(List.last(&1), 1) == length(expected) - 1))
      lengths = for [{1, _} | _] = run <- ended, do: length(run) * 10
      assert length(lengths) >= 3 and Enum.all?(lengths, &(&1 == 3000))

      inside =
        for [{1, i} | _] = run <- runs,
            Enum.any?(Enum.slice(faults, i, length(run)), &(&1 == 0)),
            do: i

      assert inside != []

      # A fault present at start sounds no horn, its lamp lit.
      {trace, _} =
        line_cycles(Logex.Runtime.start(line), 4000, %{0 => %{"fault" => 1}}, ~w(horn fault_lamp))

      assert Enum.all?(trace, fn {_now, g} -> g["horn"] == 0 and g["fault_lamp"] == 1 end)

      # The actual time counts, not a nominal period: cycled late and irregularly, its task
      # running once a late cycle, the horn sounds from the fault's rising edge at 10 ms
      # until the first cycle at or past 3010 ms.
      steps = [{0, %{}}, {10, %{"fault" => 1}}, {10, %{"fault" => 0}}, {1480, %{}}]
      steps = steps ++ [{1500, %{"fault" => 1}}, {10, %{}}, {10, %{}}]

      assert line_at(Logex.Runtime.start(line), steps, ~w(horn)) ==
               Enum.map([0, 10, 20, 1500, 3000, 3010, 3020], &{&1, %{"horn" => tm_on(&1)}})
    end

    defp tm_on(now) when now in 10..3000, do: 1
    defp tm_on(_now), do: 0

    # The oracle: the conveyor's running time, each 10 ms where it ran on this scan and the
    # last, stopping at 20000; the greased button, on its rung above, clears it on its own
    # scan and holds it at 0.
    defp lube_oracle(inputs) do
      {acc, _} =
        Enum.map_reduce(inputs, {0, 0}, fn %{"conveyor" => c, "greased" => g}, {acc, prev} ->
          acc = lube_timed(g, c == 1 and prev == 1, acc)

          {acc, {acc, c}}
        end)

      acc
    end

    # The conventional RTO restated: the reset first, then 10 ms a scan it ran and the last.
    defp lube_timed(1, _ran, _acc), do: 0
    defp lube_timed(_greased, true, acc), do: min(acc + 10, 20_000)
    defp lube_timed(_greased, false, acc), do: acc

    # A level the draw turns over where it says so.
    defp toggled(true, level), do: 1 - level
    defp toggled(false, level), do: level

    defp lube_keeps(line) do
      :rand.seed(:exsss, {2026, 10, 76})

      {inputs, _} =
        Enum.map_reduce(0..19_999, %{"conveyor" => 0, "greased" => 0}, fn _, levels ->
          conveyor = toggled(:rand.uniform(300) == 1, levels["conveyor"])
          greased = bit(:rand.uniform(6000) == 1)
          levels = %{"conveyor" => conveyor, "greased" => greased}
          {levels, levels}
        end)

      changes = Map.new(Enum.with_index(inputs), fn {input, i} -> {i * 10, input} end)

      {trace, runtime} =
        line_cycles(Logex.Runtime.start(line), 199_990, changes, ~w(run_ms grease_due))

      expected = lube_oracle(inputs)

      for {{now, g}, want} <- Enum.zip(trace, expected) do
        assert g["run_ms"] == want, "run_ms at #{now} ms"
        assert g["grease_due"] == bit(want == 20_000)
      end

      # The seed gives time kept across a stop, the preset reached, and a clear.
      kept =
        Enum.zip([expected, tl(expected), tl(inputs)])
        |> Enum.any?(fn {acc, next, input} ->
          input["conveyor"] == 0 and acc > 0 and next == acc
        end)

      assert kept
      assert 20_000 in expected
      assert Enum.any?(Enum.zip(expected, tl(expected)), fn {a, b} -> a > 0 and b == 0 end)

      # Cycled late and irregularly, it adds the actual time between two scans that both see
      # the conveyor run, and none across a stop.
      steps = [{0, %{"conveyor" => 1}}, {10, %{}}, {990, %{}}, {500, %{"conveyor" => 0}}]
      steps = steps ++ [{500, %{"conveyor" => 1}}, {600, %{}}, {10, %{"greased" => 1}}]

      assert for(
               {now, g} <- line_at(Logex.Runtime.start(line), steps, ~w(run_ms)),
               do: {now, g["run_ms"]}
             ) ==
               [{0, 0}, {10, 10}, {1000, 1000}, {1500, 1000}, {2000, 1000}, {2600, 1600}] ++
                 [{2610, 0}]

      # A restart, warm or cold, loses it, until `retain` lands (decision 76).
      for mode <- [:warm, :cold] do
        assert Logex.Runtime.get!(runtime, "l1.lube.acc") == List.last(expected)
        restarted = Logex.Runtime.restart(runtime, mode)
        assert Logex.Runtime.get!(restarted, "l1.lube.acc") == 0
      end
    end

    defp file_at(nil), do: ""
    defp file_at(file), do: "#{file}: "

    defp warned(line, file) do
      at = file_at(file)

      assert Enum.map(line.warnings, &Logex.Diagnostic.format/1) == [
               "#{at}line 30: warning: `f9` runs under the event task `trip`, and `fan` runs " <>
                 "the timer `run_on`#{cited("fan", 4, file)}: a tof's delay ends only at one of " <>
                 "the task's runs, so what it holds on stays on until the first run after its " <>
                 "preset has passed",
               "#{at}line 32: warning: `h9` runs under the event task `trip`, and `horn` runs " <>
                 "the timer `horn_pulse`#{cited("horn", 5, file)}: a tp's pulse ends only at one " <>
                 "of the task's runs, so it lasts until the first run after its preset has " <>
                 "passed, and it starts only on an edge between two runs: a rung that is the " <>
                 "task's trigger is true at every run and never starts one",
               "#{at}line 34: warning: `l9` runs under the event task `trip`, and `lube` runs " <>
                 "the timer `lube`#{cited("lube", 7, file)}: an rto times across the task's " <>
                 "runs, and one whose rung is true on two runs in a row adds the whole time " <>
                 "between them"
             ]
    end

    defp cited(_type, line, nil), do: " on its line #{line}"
    defp cited(type, line, _file), do: " on line #{line} of `#{type}.ld`"

    test "M3-2's Done-when, from text: the fan, the horn, the lubrication timer and the " <>
           "event-task warning" do
      line = line_from_text()
      warned(line, nil)
      fan_stops_together(line)
      horn_sounds(line)
      lube_keeps(line)
    end

    @tag :tmp_dir
    test "M3-2's Done-when, from files on disk", %{tmp_dir: dir} do
      line = line_from_files(dir)
      warned(line, Path.join(dir, "line.logex"))
      fan_stops_together(line)
      horn_sounds(line)
      lube_keeps(line)
    end
  end

  # PLAN.md M3-3's Done-when, as worded on 2026-10-14: a fill valve's total, `add total flow
  # total` on every scan of a 100 ms task, agrees with an Elixir oracle over seeded flows
  # and closes the valve at a setpoint read with `ge`; a total driven past 2147483647, a
  # `div` by a tag that is 0, which the cycle reports as its event, and a `mod` of a
  # negative operand each give what their stanzas say; and no value outside a dint ever
  # reaches a state. Each piece runs in one configuration through Logex.Runtime.cycle/3,
  # from text and from files on disk, against an oracle in plain Elixir that knows nothing
  # of logex. Since M5-2 the total past 2147483647 wraps, its low 32 bits kept in two's
  # complement, `total_ok` off for the one run that wrapped (decision 146, superseding
  # decision 77's saturation on purpose), and the oracle wraps where it clamped.
  describe "integer arithmetic (M3-3)" do
    alias Logex.{Configuration, Fault, Runtime}

    @max 2_147_483_647
    @min -2_147_483_648

    @fill_ld """
    var_input flow dint
    var_input setpoint dint
    var_input reset bool
    var_output valve bool
    var_output total dint
    var_output total_ok bool
    var full bool
    xic reset move 0 total
    xio reset add total flow total ote total_ok
    ge total setpoint ote full
    xio full ote valve
    """

    # Boxes per minute, its minutes 0 just after start-up (decision 78), and a phase of a
    # signed offset, a `mod` of a negative operand.
    @rate_ld """
    var_input total dint
    var_input minutes dint
    var_input offset dint
    var_output per_minute dint
    var_output rate_ok bool
    var_output phase dint
    div total minutes per_minute ote rate_ok
    mod offset 4 phase
    """

    @fill_logex """
    task fill interval 100 priority 1
    var_global flow dint at meter.i.0
    var_global setpoint dint 5000
    var_global reset bool at panel.i.0
    var_global minutes dint at panel.i.1
    var_global offset dint at panel.i.2
    var_global valve bool at panel.q.0
    var_global total_ok bool at panel.q.1
    var_global total dint
    var_global per_minute dint
    var_global rate_ok bool
    var_global phase dint
    program f1 fill with fill
    f1.flow flow
    f1.setpoint setpoint
    f1.reset reset
    f1.valve valve
    f1.total total
    f1.total_ok total_ok
    program r1 rate with fill
    r1.total total
    r1.minutes minutes
    r1.offset offset
    r1.per_minute per_minute
    r1.rate_ok rate_ok
    r1.phase phase
    """

    defp fill_from_text do
      programs =
        Map.new([{"fill", @fill_ld}, {"rate", @rate_ld}], fn {name, text} ->
          {:ok, program} = Logex.compile(text, name: name)
          {name, program}
        end)

      assert {:ok, plant} = Configuration.compile("plant", @fill_logex, programs)
      {plant, nil}
    end

    defp fill_from_files(dir) do
      for {name, text} <- [
            {"fill.ld", @fill_ld},
            {"rate.ld", @rate_ld},
            {"plant.logex", @fill_logex}
          ],
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, plant} = Configuration.compile_file(Path.join(dir, "plant.logex"))
      {plant, Path.join(dir, "rate.ld")}
    end

    # Every value the resource holds, each instance's state and each global, is a dint's
    # or a bool's: looked at inside the opaque resource on purpose, since no public call
    # shows a value that never reaches an output.
    defp all_dints?(%Runtime{instances: instances, globals: globals}),
      do:
        Enum.all?(Map.values(globals), &dint?/1) and
          Enum.all?(Map.values(instances), &(dint?(&1.env) and &1.faults == []))

    defp dint?(%{} = map), do: Enum.all?(Map.values(map), &dint?/1)
    defp dint?(value), do: is_integer(value) and value in @min..@max

    # Cycles every 10 ms from 0 to `last`, each cycle's input changes from `changes` by its
    # time: each cycle's time, its events and the globals named.
    defp fill_cycles(runtime, last, changes, names) do
      Enum.map_reduce(0..last//10, runtime, fn now, runtime ->
        {runtime, _outputs, events} =
          Runtime.cycle(runtime, elapsed(now), Map.get(changes, now, %{}))

        assert all_dints?(runtime), "a value outside a dint at #{now} ms"
        {{now, events, Map.new(names, &{&1, Runtime.get!(runtime, &1)})}, runtime}
      end)
    end

    # Decision 146, restated: the integer of the dint's 2^32 values that the exact one is
    # congruent to.
    defp wrap(value), do: Integer.mod(value - @min, 4_294_967_296) + @min

    # The oracle: the task runs at every 100 ms, from 0, and each run adds the flow then
    # sampled to the total, wrapped into a dint, and closes the valve once the total reaches
    # the setpoint.
    defp fill_oracle(flows, setpoint, last) do
      {trace, _} =
        Enum.map_reduce(0..last//10, {0, 0}, fn now, {flow, total} ->
          flow = Map.get(flows, now, flow)
          total = fill_totalled(rem(now, 100), total, flow)
          {{now, total, 1 - bit(total >= setpoint)}, {flow, total}}
        end)

      trace
    end

    # The 100 ms task's run adds the flow to the total, wrapped in the dint.
    defp fill_totalled(0, total, flow), do: wrap(total + flow)
    defp fill_totalled(_between, total, _flow), do: total

    defp fills_to_setpoint({plant, _file}) do
      :rand.seed(:exsss, {2026, 10, 33})

      flows =
        Map.new(
          for(now <- 0..3000//10, :rand.uniform(4) == 1, do: {now, :rand.uniform(400) - 50})
        )

      {trace, _runtime} =
        fill_cycles(
          Runtime.start(plant),
          3000,
          Map.new(flows, fn {t, f} -> {t, %{"flow" => f}} end),
          ~w(total valve)
        )

      assert for({now, _events, g} <- trace, do: {now, g["total"], g["valve"]}) ==
               fill_oracle(flows, 5000, 3000)

      # The valve closes at the scan where the total reaches the setpoint, and stays closed.
      assert {closed, _, _} = Enum.find(trace, fn {_now, _events, g} -> g["valve"] == 0 end)
      assert rem(closed, 100) == 0
      assert Enum.all?(trace, fn {now, _, g} -> now < closed or g["valve"] == 0 end)
    end

    defp total_wraps_past_the_top({plant, _file}) do
      {trace, _runtime} =
        fill_cycles(
          Runtime.start(plant),
          600,
          %{0 => %{"flow" => 1_500_000_000}, 300 => %{"flow" => -1}, 500 => %{"reset" => 1}},
          ~w(total total_ok)
        )

      runs =
        for {now, _events, g} <- trace, rem(now, 100) == 0, do: {now, g["total"], g["total_ok"]}

      # 1.5 billion, then past the top: 3 billion less 2^32 and no power, so `total_ok` is
      # off for that one run; the next counts on from the wrapped total with power, as does
      # a flow of -1, and the reset brings it to 0.
      assert runs == [
               {0, 1_500_000_000, 1},
               {100, -1_294_967_296, 0},
               {200, 205_032_704, 1},
               {300, 205_032_703, 1},
               {400, 205_032_702, 1},
               {500, 0, 0},
               {600, 0, 0}
             ]

      # The oracle wraps as the scan does, at every cycle up to the reset.
      assert for({now, _events, g} <- trace, now < 500, do: {now, g["total"]}) ==
               for(
                 {now, total, _valve} <- fill_oracle(%{0 => 1_500_000_000, 300 => -1}, 0, 490),
                 do: {now, total}
               )
    end

    defp divides_by_zero({plant, file}) do
      {trace, _runtime} =
        fill_cycles(
          Runtime.start(plant),
          300,
          %{0 => %{"flow" => 60, "minutes" => 0}, 200 => %{"minutes" => 2}},
          ~w(per_minute rate_ok valve total)
        )

      fault = %Fault{
        severity: :minor,
        kind: :divide_by_zero,
        instruction: :div,
        path: nil,
        file: file,
        line: 7
      }

      for {now, events, g} <- trace,
          rem(now, 100) == 0,
          do: rate_cycled!(now < 200, {now, events, g}, fault)

      assert for({now, _, g} <- trace, rem(now, 100) == 0, do: g["total"]) == [60, 120, 180, 240]
    end

    # The rate is 0 and not real, the cycle reports the fault after r1's run, and the plant
    # runs on: the valve is open and the total counts.
    defp rate_cycled!(true, {now, events, g}, fault) do
      assert events == [
               {:ran, "fill", "f1", now},
               {:ran, "fill", "r1", now},
               {:fault, "fill", "r1", fault}
             ]

      assert {g["per_minute"], g["rate_ok"], g["valve"]} == {0, 0, 1}
    end

    defp rate_cycled!(false, {now, events, g}, _fault) do
      assert events == [{:ran, "fill", "f1", now}, {:ran, "fill", "r1", now}]
      assert {g["per_minute"], g["rate_ok"]} == {div(g["total"], 2), 1}
    end

    defp phase_of_a_negative({plant, _file}) do
      {trace, _runtime} =
        fill_cycles(
          Runtime.start(plant),
          400,
          %{
            0 => %{"offset" => -7, "minutes" => 1},
            100 => %{"offset" => 7},
            200 => %{"offset" => -8},
            300 => %{"offset" => @min},
            400 => %{"offset" => -1}
          },
          ~w(phase)
        )

      # IEC's IN1 - (IN1/IN2)*IN2: the dividend's sign, never the divisor's.
      assert for({now, _, g} <- trace, rem(now, 100) == 0, do: g["phase"]) == [-3, 3, 0, 0, -1]
    end

    test "M3-3's Done-when, from text: the fill valve, its total past the top, a rate by " <>
           "zero minutes and a phase of a negative offset" do
      plant = fill_from_text()
      fills_to_setpoint(plant)
      total_wraps_past_the_top(plant)
      divides_by_zero(plant)
      phase_of_a_negative(plant)
    end

    @tag :tmp_dir
    test "M3-3's Done-when, from files on disk, each fault naming its file", %{tmp_dir: dir} do
      plant = fill_from_files(dir)
      fills_to_setpoint(plant)
      total_wraps_past_the_top(plant)
      divides_by_zero(plant)
      phase_of_a_negative(plant)
    end
  end

  # PLAN.md M3-4's Done-when, as worded on 2026-10-14: `osr` and `osf` give, on seeded
  # inputs, the pulses `ons` and `xio … ons` give on their own rungs, pass on the power
  # they receive, never fire on a first scan, and an edit that adds or changes one blocks
  # it until a scan runs it, as decision 21 blocks an `ons`. A start button steps a
  # sequence once a press, and a photo-eye says a box has left it; each from text and from
  # files on disk, against an oracle in plain Elixir that knows nothing of logex, the edit
  # a block's body's too, whose block is frozen at the switch (decision 32).
  describe "the pulse coils (M3-4)" do
    # Each coil beside its twin on a rung of its own, the falling one's storage bit
    # declared 1, so a first scan with the eye clear would fire it.
    @pulses_ld """
    var_input start_pb bool
    var_input eye bool
    var_output step bool
    var_output gone bool
    var_output held_lamp bool
    var_output on_eye bool
    var_output ons_step bool
    var_output ons_gone bool
    var s1 bool
    var s2 bool 1
    var s3 bool
    var s4 bool
    xic start_pb osr s1 step ote held_lamp
    xic eye osf s2 gone ote on_eye
    xic start_pb ons s3 ote ons_step
    xio eye ons s4 ote ons_gone
    """

    defp pulse_scans(program, inputs, state),
      do:
        Enum.map_reduce(inputs, state, fn input, state ->
          Logex.Runtime.scan(program, Logex.Runtime.put_inputs(program, state, input), 10)
        end)

    # The oracle: a rise of an input since the last scan, never on the first; `before` the
    # inputs the scan before the first saw, nil where there was none.
    defp edges(inputs, name, way, before \\ nil) do
      {edges, _} =
        Enum.map_reduce(inputs, before, fn input, last ->
          now = input[name]
          {one(last != nil and edge?(way, last[name], now)), input}
        end)

      edges
    end

    defp edge?(:rise, last, now), do: last == 0 and now == 1
    defp edge?(:fall, last, now), do: last == 1 and now == 0

    defp one(true), do: 1
    defp one(false), do: 0

    defp pulses_checked(program) do
      :rand.seed(:exsss, {2026, 10, 16})
      # The button held and the eye clear at start: neither coil fires on the first scan.
      inputs = [%{"start_pb" => 1, "eye" => 0}] ++ seeded(~w(start_pb eye), [], 500)
      {outputs, _state} = pulse_scans(program, inputs, Logex.Runtime.instance(program))

      assert hd(outputs) == %{
               "step" => 0,
               "gone" => 0,
               "held_lamp" => 1,
               "on_eye" => 0,
               "ons_step" => 0,
               "ons_gone" => 0
             }

      steps = edges(inputs, "start_pb", :rise)
      gone = edges(inputs, "eye", :fall)
      assert Enum.map(outputs, & &1["step"]) == steps
      assert Enum.map(outputs, & &1["gone"]) == gone
      assert Enum.map(outputs, & &1["step"]) == Enum.map(outputs, & &1["ons_step"])
      assert Enum.map(outputs, & &1["gone"]) == Enum.map(outputs, & &1["ons_gone"])

      # Each passes on the power it receives: the lamps follow the button and the eye.
      assert Enum.map(outputs, & &1["held_lamp"]) == Enum.map(inputs, & &1["start_pb"])
      assert Enum.map(outputs, & &1["on_eye"]) == Enum.map(inputs, & &1["eye"])
      assert Enum.sum(steps) > 20 and Enum.sum(gone) > 20
    end

    test "M3-4's Done-when: `osr` and `osf` give the pulses `ons` and `xio … ons` give, " <>
           "pass on the power they receive, and never fire on a first scan" do
      {:ok, program} = Logex.compile(@pulses_ld, name: "pulses")
      pulses_checked(program)
    end

    # The block: a coil and its twin, its body's rung changed by the candidate's version.
    @pulser_ld """
    function_block pulser
    var_input in bool
    var_output up bool
    var_output ons_up bool
    var s bool
    var t bool
    xic in osr s up
    xic in ons t ote ons_up
    """

    @armed_ld """
    function_block pulser
    var_input in bool
    var_input arm bool
    var_output up bool
    var_output ons_up bool
    var s bool
    var t bool
    xic in xic arm osr s up
    xic in xic arm ons t ote ons_up
    """

    @line_ld """
    var_input start_pb bool
    var_input on bool
    var_input jog bool
    var_output step bool
    var_output ons_step bool
    var_output up bool
    var_output ons_up bool
    var s1 bool
    var s3 bool
    var p pulser
    xic start_pb osr s1 step
    xic start_pb ons s3 ote ons_step
    xic on cal p jog up ons_up
    """

    # The candidate: the button's coil and its twin gated by an enable, a coil and its twin
    # added on the eye, a falling coil and its twin added on a jam sensor, its storage bit
    # declared 1, so a jam clear at the switch would fire it, and the block's body gated by
    # its new `arm`, which the `cal` fills.
    @line_v2_ld """
    var_input start_pb bool
    var_input enable bool
    var_input on bool
    var_input jog bool
    var_input eye bool
    var_input jam bool
    var_output step bool
    var_output ons_step bool
    var_output up bool
    var_output ons_up bool
    var_output left bool
    var_output ons_left bool
    var_output cleared bool
    var_output ons_cleared bool
    var s1 bool
    var s3 bool
    var s5 bool
    var s6 bool
    var s7 bool 1
    var s8 bool
    var p pulser
    xic start_pb xic enable osr s1 step
    xic start_pb xic enable ons s3 ote ons_step
    xic on cal p jog on up ons_up
    xic eye osr s5 left
    xic eye ons s6 ote ons_left
    xic jam osf s7 cleared
    xio jam ons s8 ote ons_cleared
    """

    defp twins(outputs, a, b), do: Enum.map(outputs, & &1[a]) == Enum.map(outputs, & &1[b])

    defp edit_checked(running, candidate) do
      # The button, the eye and the jog low, then the block frozen: `p`'s bits as its last
      # run left them, with `jog` low.
      before = [%{"start_pb" => 0, "on" => 1, "jog" => 0}, %{"on" => 0}]
      {_outputs, state} = pulse_scans(running, before, Logex.Runtime.instance(running))
      {:ok, edit, forecast} = Logex.Edit.accept(running, candidate, state)
      {edit, tested, report} = Logex.Edit.test(edit, state)
      assert report == forecast

      # Each coil the edit adds or changes is blocked with its twin, the block's by path.
      assert for({:ons_blocked, bit, _} <- report, do: bit) ==
               ["p.s", "p.t", "s1", "s3", "s5", "s6", "s7", "s8"]

      # At the switch every one would pulse, unblocked: the button and the eye rise, the jam
      # sensor is clear with its coil's storage bit at 1, and the jog rises while the block
      # is frozen. None does; the block's stay listed while its `cal` is false, and give
      # none when it first runs, where `jog` is already high.
      switch = [
        %{"start_pb" => 1, "enable" => 1, "eye" => 1, "jog" => 1},
        %{},
        %{"on" => 1},
        %{}
      ]

      {outputs, later} = pulse_scans(candidate, switch, tested)

      assert Enum.map(outputs, &{&1["step"], &1["left"], &1["cleared"], &1["up"]}) ==
               [{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}]

      assert twins(outputs, "step", "ons_step") and twins(outputs, "left", "ons_left") and
               twins(outputs, "cleared", "ons_cleared") and twins(outputs, "up", "ons_up")

      assert later.ons_blocked == []

      # From then on each coil gives exactly its twin's pulses, and the program's the
      # oracle's; the block's are held with it while its `cal` is false.
      :rand.seed(:exsss, {2026, 10, 17})
      inputs = seeded(~w(start_pb enable eye jam jog on), [], 400)
      {outputs, _state} = pulse_scans(candidate, inputs, later)
      gated = Enum.map(inputs, &%{"g" => one(&1["start_pb"] == 1 and &1["enable"] == 1)})

      # The scan before the first saw the button, the enable and the eye high, the jam clear.
      assert Enum.map(outputs, & &1["step"]) == edges(gated, "g", :rise, %{"g" => 1})
      assert Enum.map(outputs, & &1["left"]) == edges(inputs, "eye", :rise, %{"eye" => 1})
      assert Enum.map(outputs, & &1["cleared"]) == edges(inputs, "jam", :fall, %{"jam" => 0})
      assert twins(outputs, "step", "ons_step") and twins(outputs, "left", "ons_left")
      assert twins(outputs, "cleared", "ons_cleared")
      assert twins(outputs, "up", "ons_up")
      assert Enum.sum(Enum.map(outputs, & &1["up"])) > 5
      {_program, _state, _report} = Logex.Edit.assemble(edit, later)
    end

    test "M3-4's Done-when: an edit that adds or changes a coil blocks it until a scan runs " <>
           "it, as decision 21 blocks an `ons`, inside a frozen block too" do
      {:ok, pulser} = Logex.compile(@pulser_ld, name: "pulser")
      {:ok, armed} = Logex.compile(@armed_ld, name: "pulser")
      {:ok, running} = Logex.compile(@line_ld, name: "line", types: [pulser])
      {:ok, candidate} = Logex.compile(@line_v2_ld, name: "line", types: [armed])
      edit_checked(running, candidate)
    end

    @tag :tmp_dir
    test "M3-4's Done-when from files on disk, through compile_file/1", %{tmp_dir: dir} do
      write = fn name, text ->
        path = Path.join(dir, name)
        File.write!(path, text)
        path
      end

      {:ok, program} = Logex.compile_file(write.("pulses.ld", @pulses_ld))
      pulses_checked(program)

      # Two versions of the line, each in a folder of its own with its block beside it.
      File.mkdir_p!(Path.join(dir, "v2"))
      write.("pulser.ld", @pulser_ld)
      write.("v2/pulser.ld", @armed_ld)
      {:ok, running} = Logex.compile_file(write.("line.ld", @line_ld))
      {:ok, candidate} = Logex.compile_file(write.("v2/line.ld", @line_v2_ld))
      edit_checked(running, candidate)
    end
  end

  # PLAN.md M3-5's Done-when, as worded on 2026-10-14: a forward `jmp` over a manual-mode
  # section freezes that section's outputs, counters and timers exactly as a false `cal`
  # freezes a block; a backward jump, a missing label and a label not first on its rung are
  # each a located diagnostic; and a program with no `jmp` scans within a measured bound of
  # its cost before. A conveyor's manual section, a jog lamp, a jog step, a count of jogs
  # and a jog timer, skipped by a `jmp` while the line is in auto, beside the same section
  # as a block its `cal` runs only in manual; from text and from files on disk, against
  # checks in plain Elixir that know nothing of logex.
  describe "a forward jump (M3-5)" do
    @jog_rungs """
    xic jog_pb ote jog_lamp
    xic jog_pb ons s_jog ote jog_step
    xic jog_pb ctu jogs 99
    xic jog_pb ton jog_t 3000
    xic jog_t.dn ote jog_long
    """

    # The jump lights the auto lamp on its own rung, and the motor's rung is the one its
    # label heads.
    @jogged_ld """
    var_input manual bool
    var_input jog_pb bool
    var_input run bool
    var_output motor bool
    var_output auto_lamp bool
    var_output jog_lamp bool
    var_output jog_step bool
    var_output jog_long bool
    var s_jog bool
    var jogs ctu
    var jog_t ton
    xio manual jmp auto ote auto_lamp
    #{@jog_rungs}lbl auto xic run xio manual ote motor
    """

    @jog_section_ld """
    function_block jog_section
    var_input jog_pb bool
    var_output jog_lamp bool
    var_output jog_step bool
    var_output jog_long bool
    var s_jog bool
    var jogs ctu
    var jog_t ton
    #{@jog_rungs}
    """

    @called_ld """
    var_input manual bool
    var_input jog_pb bool
    var_input run bool
    var_output motor bool
    var_output auto_lamp bool
    var_output jog_lamp bool
    var_output jog_step bool
    var_output jog_long bool
    var m jog_section
    xio manual ote auto_lamp
    xic manual cal m jog_pb jog_lamp jog_step jog_long
    xic run xio manual ote motor
    """

    defp jog_scans(program, steps, state),
      do:
        Enum.map_reduce(steps, state, fn {ms, input}, state ->
          {outputs, state} =
            Logex.Runtime.scan(program, Logex.Runtime.put_inputs(program, state, input), ms)

          {{outputs, state}, state}
        end)

    # The section's state in each program: its own tags in the one, its block's members in
    # the other.
    defp section(state, nil), do: Map.take(state.env, ~w(s_jog jogs jog_t))
    defp section(state, block), do: Map.take(state.env[block], ~w(s_jog jogs jog_t))

    defp jump_checked(jumped, called) do
      :rand.seed(:exsss, {2026, 10, 18})
      inputs = seeded(~w(manual jog_pb run), [], 600)
      steps = Enum.map(inputs, &{Enum.random([10, 30, 100, 400]), &1})
      {a, _} = jog_scans(jumped, steps, Logex.Runtime.instance(jumped))
      {b, _} = jog_scans(called, steps, Logex.Runtime.instance(called))

      # Scan for scan, the jumped section and the frozen block give the same outputs and
      # hold the same one-shot, counter and timer.
      for {{{out_a, state_a}, {out_b, state_b}}, i} <- Enum.with_index(Enum.zip(a, b)) do
        assert out_a == out_b, "scan #{i}"
        assert section(state_a, nil) == section(state_b, "m"), "scan #{i}"
      end

      # And they do what the line says: in manual the jog lamp follows the button and the
      # motor stops; in auto the auto lamp is lit, the motor follows `run` and nothing of the
      # section moves.
      a
      |> Enum.zip(inputs)
      |> Enum.reduce(nil, fn {{outputs, state}, input}, last ->
        assert outputs["motor"] == one(input["run"] == 1 and input["manual"] == 0)
        assert outputs["auto_lamp"] == 1 - input["manual"]

        jogged!(input["manual"], outputs, input, {last, state})

        {outputs, state}
      end)

      modes = inputs |> Enum.chunk_by(& &1["manual"]) |> length()
      jogs = List.last(a) |> elem(1) |> then(& &1.env["jogs"]["cv"])
      assert modes > 100 and jogs > 20
    end

    # In manual the jog lamp follows the button; in auto nothing of the section moves.
    defp jogged!(1, outputs, input, _scans), do: assert(outputs["jog_lamp"] == input["jog_pb"])
    defp jogged!(_auto, outputs, _input, {last, state}), do: frozen!(last, {outputs, state})

    defp frozen!(nil, _now), do: :ok

    defp frozen!({outputs, state}, {now_out, now_state}) do
      assert Map.take(now_out, ~w(jog_lamp jog_step jog_long)) ==
               Map.take(outputs, ~w(jog_lamp jog_step jog_long))

      assert section(now_state, nil) == section(state, nil)
    end

    # The timer in the skipped section catches up the time the line spent in auto when it
    # next runs (decision 82), as one in a frozen block does; an edge of the button while the
    # line is in auto is never counted, and one still held when it returns to manual counts
    # if the counter last saw it released.
    defp catch_up_checked(program) do
      steps = [
        {0, %{"manual" => 1, "jog_pb" => 0}},
        {100, %{"jog_pb" => 1}},
        {100, %{}},
        {100, %{"manual" => 0, "jog_pb" => 0}},
        {500, %{"jog_pb" => 1}},
        {500, %{"jog_pb" => 0}},
        {100, %{"manual" => 1, "jog_pb" => 1}}
      ]

      {scans, _} = jog_scans(program, steps, Logex.Runtime.instance(program))

      assert Enum.map(scans, fn {_, s} -> {s.env["jog_t"]["acc"], s.env["jogs"]["cv"]} end) ==
               [{0, 0}, {0, 1}, {100, 1}, {100, 1}, {100, 1}, {100, 1}, {1300, 1}]
    end

    test "M3-5's Done-when: a forward jmp over a manual-mode section freezes its outputs, " <>
           "counters and timers exactly as a false cal freezes a block" do
      {:ok, jumped} = Logex.compile(@jogged_ld, name: "conveyor")
      {:ok, section} = Logex.compile(@jog_section_ld, name: "jog_section")
      {:ok, called} = Logex.compile(@called_ld, name: "conveyor", types: [section])
      assert jumped.warnings == [] and called.warnings == []
      jump_checked(jumped, called)
      catch_up_checked(jumped)
    end

    # One mistake of each kind the Done-when names on a line of its own: a jump back to the
    # rung `start` heads, a jump to a label no rung begins with, and a label after a contact.
    @misjumped_ld """
    var_input manual bool
    var_input jog_pb bool
    var_output jog_lamp bool
    lbl start xic jog_pb ote jog_lamp
    xio manual jmp start
    xio manual jmp atuo
    xic jog_pb lbl auto
    lbl atuo2
    """

    test "M3-5's Done-when: a backward jump, a missing label and a label not first on its " <>
           "rung are each a located diagnostic" do
      assert {:error, diagnostics} = Logex.compile(@misjumped_ld, name: "conveyor")

      assert Enum.map(diagnostics, &Logex.Diagnostic.format/1) == [
               "line 5: `jmp start` jumps back, to the rung on line 4: a jump goes forward " <>
                 "only, to a label on a later rung, since one back could loop for ever",
               "line 6: `jmp atuo` names no label: no rung of this program begins `lbl atuo` " <>
                 "— did you mean `atuo2`?",
               "line 7: `lbl auto` is not first on its rung: a label stands at the head of " <>
                 "the rung it names, before any other instruction or branch group"
             ]
    end

    # The rung loop's own cost per rung beside its instructions': a scan of 400 rungs of
    # `xic a ote y` against one of 200 rungs of two such pairs, the same instructions, the
    # least of three counts each. On Elixir 1.20.4, over 32 runs each, 16 alone and 16
    # beside three suites, the ratio was 1.179 at 16d47ed, before M3-5, its loop 8
    # reductions a rung, and is 1.141 with the jump, 6 a rung: one recursion over the rungs
    # took 3 off, and the jump's look after each rung puts 1 back. The bound is the ratio a
    # loop a fifth dearer than before would give, 9.6 a rung, 1.207: a call more a rung,
    # 2 reductions, gives 1.179, and two, 1.214.
    test "M3-5's Done-when: a program with no jmp scans within a fifth of the rung loop's " <>
           "cost before M3-5" do
      decl = "var_input a bool\nvar_output y bool\n"
      one = decl <> Enum.map_join(1..400, "\n", fn _ -> "xic a ote y" end)
      two = decl <> Enum.map_join(1..200, "\n", fn _ -> "xic a ote y xic a ote y" end)
      ratio = scan_reductions(one) / scan_reductions(two)
      assert ratio < 1.207, "the loop's share of a scan rose to #{Float.round(ratio, 3)}"
    end

    defp scan_reductions(source) do
      {:ok, p} = Logex.compile(source, name: "m")

      {_, s} =
        Logex.Runtime.call(p, Logex.Runtime.instance(p), %{}, %Logex.Scan{now: 0, first: true})

      Enum.min(
        for _ <- 1..3 do
          {:reductions, before} = Process.info(self(), :reductions)
          Logex.Runtime.call(p, s, %{"a" => 1}, %Logex.Scan{now: 10, first: false})
          {:reductions, later} = Process.info(self(), :reductions)
          later - before
        end
      )
    end

    @tag :tmp_dir
    test "M3-5's Done-when from files on disk, through compile_file/1", %{tmp_dir: dir} do
      write = fn name, text ->
        path = Path.join(dir, name)
        File.write!(path, text)
        path
      end

      {:ok, jumped} = Logex.compile_file(write.("jogged.ld", @jogged_ld))
      write.("jog_section.ld", @jog_section_ld)
      {:ok, called} = Logex.compile_file(write.("conveyor.ld", @called_ld))
      jump_checked(jumped, called)
      catch_up_checked(jumped)

      broken = write.("misjumped.ld", @misjumped_ld)
      assert {:error, diagnostics} = Logex.compile_file(broken)
      assert Enum.map(diagnostics, &{&1.file, &1.line}) == [{broken, 5}, {broken, 6}, {broken, 7}]
    end
  end

  describe "the clock, the I/O contract and the simulated device (M4-1)" do
    alias Logex.IO.Sim
    alias Logex.Runner.Clock.Manual

    # A device's process, as the runner's will be: it opens its adapter with its points in
    # its own process, reads it on the clock every 10 ms where it has input points, takes
    # each report, writes what it is given, and keeps each input change it saw with the
    # clock's time then.
    defmodule PolledDevice do
      use GenServer

      def start(args), do: GenServer.start_link(__MODULE__, args)
      def seen(pid), do: GenServer.call(pid, :seen)
      def write(pid, values), do: GenServer.call(pid, {:write, values})

      @impl true
      def init({clock, adapter, device, points, opts}) do
        {:ok, state} = adapter.init(device, points, opts)
        inputs? = Enum.any?(points, &(&1.direction == :input))

        s = %{
          clock: clock,
          adapter: adapter,
          state: state,
          image: %{},
          seen: [],
          inputs?: inputs?
        }

        {:ok, read(s)}
      end

      @impl true
      def handle_call(:seen, _from, s), do: {:reply, Enum.reverse(s.seen), s}

      def handle_call({:write, values}, _from, s) do
        {:ok, state} = s.adapter.write(values, s.state)
        {:reply, :ok, %{s | state: state}}
      end

      @impl true
      def handle_info(:poll, s), do: {:noreply, read(s)}

      def handle_info(message, s) do
        {:ok, changed, state} = s.adapter.report(message, s.state)
        {:noreply, changes(%{s | state: state}, changed, :report)}
      end

      # A read, where the device has inputs, and the next one set 10 ms on.
      defp read(%{inputs?: false} = s), do: s

      defp read(s) do
        {:ok, values, state} = s.adapter.read(s.state)
        Manual.wake_at(s.clock, self(), :poll, Manual.now_ms(s.clock) + 10)
        changes(%{s | state: state}, values, :read)
      end

      defp changes(s, values, how) do
        now = Manual.now_ms(s.clock)

        new =
          for {address, value} <- Enum.sort(values),
              Map.get(s.image, address) != value,
              do: {now, how, address, value}

        %{s | image: Map.merge(s.image, values), seen: Enum.reverse(new) ++ s.seen}
      end
    end

    # The plant's files, as the M2-6 and OE-2 tests above cut them.
    @tag :tmp_dir
    test "M4-1's Done-when: §4.4's plant from files on disk, its points grouped and bound " <>
           "to two simulated devices, read and written on the manual clock",
         %{tmp_dir: dir} do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"plant.logex", whole_plant()}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      assert {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      # The grouping: the panel's eight inputs and four outputs, the drive's two outputs.
      assert [
               {"drive", Sim, [sim: ^drive], drive_points},
               {"panel", Sim, [sim: ^panel], panel_points}
             ] =
               Logex.IO.bind!(plant, %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}})

      directions = &Enum.frequencies(Enum.map(&1, fn point -> point.direction end))
      assert directions.(panel_points) == %{input: 8, output: 4}
      assert directions.(drive_points) == %{output: 2}
      assert Enum.map(drive_points, &{&1.name, &1.type}) == [{"sp_1", :dint}, {"sp_2", :dint}]

      {:ok, panel_device} = PolledDevice.start({clock, Sim, "panel", panel_points, [sim: panel]})
      {:ok, drive_device} = PolledDevice.start({clock, Sim, "drive", drive_points, [sim: drive]})

      # The panel reports a press at once, before the clock moves; a release 15 ms on is
      # reported at 15, between two reads; the drive, with no input, is never read.
      Sim.set(panel, [0], 1)
      Manual.advance(clock, 15)
      Sim.set(panel, [0], 0)
      Manual.advance(clock, 15)

      assert PolledDevice.seen(panel_device) ==
               for(address <- 0..7, do: {0, :read, [address], 0}) ++
                 [{0, :report, [0], 1}, {15, :report, [0], 0}]

      # Read every 10 ms in time order, at 0, 10, 20 and 30; the poll timers each device set
      # all delivered, none left behind.
      assert Sim.reads(panel) == 4
      assert Sim.reads(drive) == 0
      assert Manual.pending(clock) == [{40, panel_device, :poll}]

      # A held input is read on the next poll whatever reports: a sim that does not report.
      {:ok, quiet} = Sim.start_link(clock: clock)
      {:ok, quiet_device} = PolledDevice.start({clock, Sim, "panel", panel_points, [sim: quiet]})
      Sim.set(quiet, [7], 1)
      Manual.advance(clock, 10)
      assert {40, :read, [7], 1} in PolledDevice.seen(quiet_device)

      # Writes are recorded in order; a write the drive takes 25 ms over passes on the
      # clock and delivers nothing, the reads due meanwhile coming at the next advance.
      PolledDevice.write(panel_device, %{[0] => 1, [1] => 0, [2] => 1, [3] => 0})
      Sim.fail(drive, :write, {:delay, 25})
      PolledDevice.write(drive_device, %{[0] => 1200, [1] => 0})
      assert Manual.now_ms(clock) == 65
      assert Sim.reads(panel) == 5
      Manual.advance(clock, 0)
      assert Sim.reads(panel) == 6
      PolledDevice.write(panel_device, %{[0] => 0, [1] => 0, [2] => 0, [3] => 0})

      assert Sim.writes(panel) == [
               %{[0] => 1, [1] => 0, [2] => 1, [3] => 0},
               %{[0] => 0, [1] => 0, [2] => 0, [3] => 0}
             ]

      assert Sim.outputs(drive) == %{[0] => 1200, [1] => 0}
    end
  end

  # PLAN.md M4-2's Done-when, as it is worded: §4.4's plant, every task line with a
  # watchdog, and a box counter in its continuous task, `task main continuous watchdog 200`
  # and `program boxes counter`, from a configuration file's text and from files on disk.
  # It reads, prints back exactly, compiles with no warning and cycles as before, the box
  # counter's runs reported under `main`; and an online edit that adds `with main` moves
  # nothing.
  describe "watchdogs and the continuous task in the plant (M4-2)" do
    @describetag :tmp_dir

    alias Logex.Configuration
    alias Logex.Configuration.{Edit, Text}

    # A box counter: a photo-eye adds one for each box, the case-full lamp lights at twelve,
    # and the reset button empties the count, README's `boxes.ld` at a case of twelve.
    @counter_ld """
    var_input eye bool
    var_input reset_pb bool
    var_output full_lamp bool
    var boxes ctu

    xic reset_pb ote boxes.r
    xic eye ctu boxes 12
    xic boxes.q ote full_lamp
    """

    @boxes """

    task main continuous watchdog 200

    var_global eye_1     bool at panel.i.8
    var_global case_full bool at panel.q.4

    program boxes counter
      boxes.eye       eye_1
      boxes.reset_pb  pb_reset
      boxes.full_lamp case_full
    """

    # §4.4's plant as written, each task line given a watchdog, and the box counter.
    defp watched_plant do
      whole_plant()
      |> String.replace(
        "task fast interval 10 priority 1",
        "task fast interval 10 priority 1 watchdog 50"
      )
      |> String.replace(
        "task slow interval 50 priority 2",
        "task slow interval 50 priority 2 watchdog 2000"
      )
      |> String.replace(
        "task trip single estop priority 0",
        "task trip single estop priority 0 watchdog 20"
      )
      |> Kernel.<>(@boxes)
    end

    defp counter_programs do
      {programs, files} = shared_programs()
      {:ok, counter} = Logex.compile(@counter_ld, name: "counter")
      {Map.put(programs, "counter", counter), Map.put(files, "counter.ld", @counter_ld)}
    end

    # The plant cycled every 10 ms from 0, both motors started, the e-stop at each value of
    # `trace` in turn and the eye at each of `eyes`: each cycle's runs and lamp, and the
    # resource at the end.
    # The boxes counted before a cycle, none before the first.
    defp boxes_before(0, _counted), do: 0
    defp boxes_before(cycle, counted), do: Enum.at(counted, cycle - 1)

    defp boxed(plant, trace, eyes) do
      Enum.zip(trace, eyes)
      |> Enum.with_index()
      |> Enum.map_reduce(Logex.Runtime.start(plant), fn {{estop, eye}, cycle}, runtime ->
        inputs = Map.merge(started(cycle * 10), %{"estop" => estop, "eye_1" => eye})
        {runtime, outputs, events} = Logex.Runtime.cycle(runtime, min(cycle, 1) * 10, inputs)

        {{for({:ran, task, instance, _} <- events, do: {task, instance}), outputs["case_full"]},
         runtime}
      end)
    end

    defp the_watched_done_when(plant, text) do
      # It reads and prints back exactly, and compiles with no warning.
      assert plant.warnings == []
      assert Text.print(plant) == printed_as(text)

      assert Enum.find(plant.tasks, &(&1.name == "main")) == %Configuration.Task{
               name: "main",
               continuous: true,
               watchdog: 200,
               line: watched_line(text, "task main")
             }

      assert Enum.map(plant.tasks, &Configuration.watchdog/1) == [50, 2000, 20, 200]

      # It cycles as before, the box counter last in every cycle under `main`; the oracle
      # knows nothing of logex: the lamp is on once twelve rising edges of the eye have
      # come after the first cycle, which counts none.
      :rand.seed(:exsss, {2026, 10, 18})
      trace = [0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1] ++ List.duplicate(0, 49)
      eyes = for _ <- trace, do: Enum.random([0, 1])
      {cycles, _runtime} = boxed(plant, trace, eyes)

      rises =
        for {[before, now], cycle} <-
              Enum.with_index(Enum.chunk_every([0 | trace], 2, 1, :discard)),
            before == 0 and now == 1,
            do: cycle

      counted =
        eyes
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [before, now] -> bit(before == 0 and now == 1) end)
        |> Enum.scan(&+/2)

      for {{runs, lamp}, cycle} <- Enum.with_index(cycles) do
        due = [{"fast", "m1"}] ++ noted(rem(cycle, 5) == 0, {"slow", "m2"})
        due = noted(cycle in rises, {"trip", "snap"}) ++ due
        assert runs == due ++ [{"main", "boxes"}], "cycle #{cycle + 1}"
        boxes = boxes_before(cycle, counted)
        assert lamp == bit(boxes >= 12), "cycle #{cycle + 1}"
      end

      assert Enum.any?(cycles, &match?({_, 1}, &1)) and Enum.any?(cycles, &match?({_, 0}, &1))

      # An online edit that adds `with main` moves nothing: no report, and the next cycles
      # run as they did.
      runtime = Logex.Runtime.start(plant)
      {runtime, _, _} = Logex.Runtime.cycle(runtime, 0, started(0))

      with_main =
        String.replace(text, "program boxes counter\n", "program boxes counter with main\n")

      {:ok, candidate} = Configuration.compile("plant", with_main, plant.programs)
      assert {:ok, edit, []} = Edit.accept(runtime, candidate)
      assert {edit, tested, []} = Edit.test(edit, runtime)
      assert {_candidate, assembled, []} = Edit.assemble(edit, tested)

      Enum.reduce(
        [{10, started(10)}, {10, %{"eye_1" => 1}}, {10, %{"eye_1" => 0}}, {10, %{"estop" => 1}}],
        {runtime, assembled},
        fn {elapsed, inputs}, {kept, edited} ->
          {kept, kept_outputs, kept_events} = Logex.Runtime.cycle(kept, elapsed, inputs)
          {edited, edited_outputs, edited_events} = Logex.Runtime.cycle(edited, elapsed, inputs)
          assert {edited_outputs, edited_events} == {kept_outputs, kept_events}

          assert Logex.Runtime.get!(edited, "boxes.boxes.cv") ==
                   Logex.Runtime.get!(kept, "boxes.boxes.cv")

          {kept, edited}
        end
      )
    end

    # The text as print/1 writes it: lowercase keywords, one space, no comment, no indent.
    defp printed_as(text) do
      text
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.replace(~r{//.*}, "") |> String.split() |> Enum.join(" ")))
      |> Enum.join("\n")
      |> String.trim_trailing()
      |> Kernel.<>("\n")
    end

    defp watched_line(text, start),
      do: 1 + Enum.find_index(String.split(text, "\n"), &String.starts_with?(&1, start))

    test "M4-2's Done-when, from a configuration file's text" do
      {programs, _files} = counter_programs()
      assert {:ok, plant} = Configuration.compile("plant", watched_plant(), programs)
      the_watched_done_when(plant, watched_plant())
    end

    test "M4-2's Done-when, from files on disk", %{tmp_dir: dir} do
      {_programs, files} = counter_programs()

      for {name, text} <-
            Map.merge(files, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => watched_plant()}),
          do: File.write!(Path.join(dir, name), text)

      assert {:ok, plant} = Configuration.compile_file(Path.join(dir, "plant.logex"))
      the_watched_done_when(plant, watched_plant())
    end
  end

  # PLAN.md M4-3's Done-when, as it is worded: §4.4's plant with M4-2's box counter, loaded
  # from files on disk, runs through Logex.Runner on the manual clock and two simulated
  # devices, the panel reporting its changes and the drive only read, over a seeded
  # sequence of presses and waits, and every round's outputs, events and get/2 values equal
  # those of Logex.Runtime.cycle/3 called directly with the same elapsed_ms and inputs, an
  # oracle that knows nothing of the runner; and the run repeats exactly from fresh
  # processes. The oracle's rounds are the rule the runner keeps: one each clock
  # millisecond, the box counter being untimed, and one at once for each change of the
  # e-stop, the trigger of `trip`, every other change taken by the next.
  describe "the runner on the plant (M4-3)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @paths ~w(k1 k2 lamp_1 lamp_2 sp_1 sp_2 case_full k1_at_trip k2_at_trip estop eye_1 pb_reset) ++
             ~w(boxes.boxes.cv m1.motor m2.motor)

    defp plant_on_disk(dir) do
      {_programs, files} = counter_programs()

      for {name, text} <-
            Map.merge(files, %{"snapshot.ld" => @snapshot_ld, "plant.logex" => watched_plant()}),
          do: File.write!(Path.join(dir, name), text)

      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      plant
    end

    # A seeded sequence of presses and waits: a press sets one of the panel's inputs, the
    # photo-eye most often, and a wait moves the clock on; halfway, every fault's cause is
    # taken away, the reset button pressed and released, which empties the case and
    # clears the motors' faults, and both conveyors started.
    defp presses(seed, n) do
      :rand.seed(:exsss, seed)

      inputs =
        ~w(pb_start_1 pb_start_1 pb_stop_1 tt_1 pb_start_2 pb_start_2 pb_stop_2 tt_2) ++
          ~w(estop estop) ++ List.duplicate("eye_1", 16)

      random = fn -> press_drawn(:rand.uniform(5), inputs) end

      half = for _ <- 1..div(n, 2), do: random.()
      rest = for _ <- 1..div(n, 2), do: random.()
      half ++ restarted() ++ rest
    end

    defp press_drawn(kind, _inputs) when kind <= 3, do: {:wait, Enum.random(0..25)}
    defp press_drawn(_press, inputs), do: {:press, Enum.random(inputs), Enum.random(0..1)}

    # Every fault's cause taken away, the faults reset and both conveyors started.
    defp restarted,
      do:
        for(name <- ~w(estop tt_1 tt_2 pb_stop_1 pb_stop_2), do: {:press, name, 0}) ++
          [{:press, "pb_reset", 1}, {:wait, 55}, {:press, "pb_reset", 0}, {:wait, 1}] ++
          [{:press, "pb_start_1", 1}, {:press, "pb_start_2", 1}, {:wait, 55}] ++
          [{:press, "pb_start_1", 0}, {:press, "pb_start_2", 0}]

    # The run through the runner: each step's events, as a subscriber gets them, the
    # devices' outputs and the values get/2 reads, in order.
    defp through_runner(plant, steps) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)
      points = Logex.IO.points(plant)
      address = Map.new(for {_device, ps} <- points, p <- ps, do: {p.name, p.address})

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      :ok = Runner.subscribe(runner, [:overlap, :fault, :ran, :round])

      # The first round ran at start, before the subscription: it is told by get/2 alone.
      first = observed(runner, [], panel, drive)

      {log, _} =
        Enum.map_reduce(steps, nil, fn step, nil ->
          step_runner(step, clock, panel, address)
          {observed(runner, drained(runner), panel, drive), nil}
        end)

      Runner.stop(runner)
      [first | log]
    end

    defp step_runner({:wait, ms}, clock, _panel, _address), do: Manual.advance(clock, ms)

    defp step_runner({:press, name, value}, _clock, panel, address),
      do: Sim.set(panel, Map.fetch!(address, name), value)

    # Every event the runner has sent: a :sys call answered after them, from the same
    # process, marks the end.
    defp drained(runner) do
      :sys.get_state(runner)
      drain(runner, [])
    end

    defp drain(runner, events) do
      receive do
        {Runner, ^runner, event} -> drain(runner, [event | events])
      after
        0 -> Enum.reverse(events)
      end
    end

    defp observed(runner, events, panel, drive),
      do:
        {events, Sim.outputs(panel), Sim.outputs(drive),
         Map.new(@paths, &{&1, Runner.get(runner, &1)})}

    # The oracle: Logex.Runtime.cycle/3 called directly, with the elapsed times and the
    # inputs the runner's rules give, and the devices' outputs by address.
    defp through_oracle(plant, steps) do
      points = Logex.IO.points(plant)
      inputs = for {_device, ps} <- points, %{direction: :input} = p <- ps, do: p.name
      image = Map.new(inputs, &{&1, 0})
      {runtime, outputs, _events} = Logex.Runtime.cycle(Logex.Runtime.start(plant), 0, image)

      model = %{
        runtime: runtime,
        now: 0,
        last: 0,
        image: image,
        pending: %{},
        outputs: outputs,
        points: points
      }

      {log, _model} =
        Enum.map_reduce(steps, model, fn step, model ->
          {events, model} = step_oracle(step, model)
          {oracle_seen(events, model), model}
        end)

      [oracle_seen([], model) | log]
    end

    defp step_oracle({:wait, ms}, model) do
      Enum.reduce(1..ms//1, {[], model}, fn _, {events, model} ->
        {round, model} = oracle_round(%{model | now: model.now + 1})
        {events ++ round, model}
      end)
    end

    defp step_oracle({:press, name, value}, %{image: image} = model) do
      oracle_pressed(Map.fetch!(image, name) == value, name, value, model)
    end

    defp oracle_pressed(true, _name, _value, model), do: {[], model}

    defp oracle_pressed(false, "estop", value, model),
      do:
        oracle_round(%{
          model
          | image: Map.put(model.image, "estop", value),
            pending: Map.put(model.pending, "estop", value)
        })

    defp oracle_pressed(false, name, value, model),
      do:
        {[],
         %{
           model
           | image: Map.put(model.image, name, value),
             pending: Map.put(model.pending, name, value)
         }}

    defp oracle_round(%{runtime: runtime, now: now, last: last, pending: pending} = model) do
      {runtime, outputs, events} = Logex.Runtime.cycle(runtime, now - last, pending)

      {events ++ [{:round, now, outputs}],
       %{model | runtime: runtime, last: now, pending: %{}, outputs: outputs}}
    end

    defp oracle_seen(events, %{runtime: runtime, outputs: outputs, points: points}) do
      by_device = fn device ->
        for %{direction: :output} = p <- Map.fetch!(points, device),
            into: %{},
            do: {p.address, Map.fetch!(outputs, p.name)}
      end

      {events, by_device.("panel"), by_device.("drive"),
       Map.new(@paths, &{&1, Logex.Runtime.get(runtime, &1)})}
    end

    test "M4-3's Done-when: the plant through the runner on the manual clock, round for " <>
           "round the oracle's, from files on disk, repeating exactly",
         %{tmp_dir: dir} do
      plant = plant_on_disk(dir)
      assert plant.warnings == []
      steps = presses({2026, 10, 18}, 600)

      runner_log = through_runner(plant, steps)
      oracle_log = through_oracle(plant, steps)
      assert length(runner_log) == length(oracle_log)

      for {{ran, want}, index} <- Enum.with_index(Enum.zip(runner_log, oracle_log)) do
        assert ran == want, "step #{index}: #{inspect(Enum.at([nil | steps], index))}"
      end

      # It reached what it is about: the conveyors run and stop, `trip` runs, a case
      # fills, and the drive's speed is set.
      events = Enum.flat_map(runner_log, &elem(&1, 0))

      assert Enum.any?(events, &match?({:ran, "trip", "snap", _}, &1))
      assert Enum.any?(events, &match?({:round, _, %{"k1" => 1}}, &1))
      assert Enum.any?(events, &match?({:round, _, %{"case_full" => 1}}, &1))
      assert Enum.any?(runner_log, &match?({_, _, %{[0] => 1200}, _}, &1))
      rounds = Enum.count(events, &match?({:round, _, _}, &1))
      assert rounds > 2_000

      # From fresh processes, exactly again.
      assert through_runner(plant, steps) == runner_log
    end

    # On the real clock, liveness only, with bounds far from what load can reach: CI
    # shares its cores (§4.11, "Risks"). Both conveyors started, the plant runs for 2 s,
    # rounding and keeping its clock, and then stops in order, every output zeroed once.
    test "on the real clock the plant runs for 2 s and stops in order", %{tmp_dir: dir} do
      plant = plant_on_disk(dir)
      {:ok, panel} = Sim.start_link(reports: true)
      {:ok, drive} = Sim.start_link()

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}}
        )

      Sim.set(panel, %{[0] => 1, [3] => 1})
      Process.sleep(2_000)
      status = Runner.status(runner)
      assert %{status: :running, trip: nil} = status
      assert status.rounds >= 20
      assert status.now >= 500
      # One round a clock millisecond at most, counted over the run: no trigger changes
      # here, so no round of its own beside them.
      assert status.rounds <= status.now + 1
      assert Runner.get!(runner, "k1") == 1

      assert Runner.stop(runner) == :ok
      refute Process.alive?(runner)
      assert List.last(Sim.writes(panel)) == %{[0] => 0, [1] => 0, [2] => 0, [3] => 0, [4] => 0}
      assert List.last(Sim.writes(drive)) == %{[0] => 0, [1] => 0}
      assert Sim.closed?(panel) and Sim.closed?(drive)
    end
  end

  # PLAN.md M4-5's Done-when, as it is worded: §4.4's plant with M4-2's box counter, from
  # files on disk, edited while it runs through Logex.Runner's accept, test, untest,
  # assemble and cancel, every report and every round's outputs those the same steps give
  # taken over the resource directly, by an oracle that knows nothing of the runner;
  # `slow` cut to 20 ms next due as decision 40 says, no round lost or added; and forcing
  # (decisions 117 and 127), the photo-eye forced, across a restart, a crash and a fresh
  # start from its forces file. Accept's work in the caller's process (decision 119) is
  # pinned in `runner_edit_test.exs`.
  describe "edits and forcing through the runner (M4-5)" do
    @describetag :tmp_dir

    alias Logex.Configuration.Edit, as: ConfigEdit
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    # The candidate, from files on disk beside the plant's: `slow` cut from 50 to 20 ms
    # and the case cut from twelve boxes to six.
    defp candidate_on_disk(dir) do
      dir = Path.join(dir, "candidate")
      File.mkdir_p!(dir)
      {_programs, files} = counter_programs()

      plant =
        String.replace(
          watched_plant(),
          "task slow interval 50 priority 2 watchdog 2000",
          "task slow interval 20 priority 2 watchdog 2000"
        )

      for {name, text} <-
            Map.merge(files, %{
              "counter.ld" => String.replace(@counter_ld, "ctu boxes 12", "ctu boxes 6"),
              "snapshot.ld" => @snapshot_ld,
              "plant.logex" => plant
            }),
          do: File.write!(Path.join(dir, name), text)

      {:ok, candidate} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      candidate
    end

    # M4-3's seeded presses and waits, with an edit's steps among them: the candidate
    # accepted, tested, untested, tested again and assembled; then the original accepted
    # back and cancelled from accept; and accepted, tested, untested and cancelled.
    defp edited_steps(seed) do
      edits = [
        {100, {:edit, :accept, :candidate}},
        {160, {:edit, :test}},
        {260, {:edit, :untest}},
        {300, {:edit, :test}},
        {360, {:edit, :assemble}},
        {420, {:edit, :accept, :original}},
        {440, {:edit, :cancel}},
        {480, {:edit, :accept, :original}},
        {500, {:edit, :test}},
        {540, {:edit, :untest}},
        {560, {:edit, :cancel}}
      ]

      steps =
        Enum.reduce(Enum.reverse(edits), presses(seed, 600), fn {at, step}, steps ->
          List.insert_at(steps, at, step)
        end)

      # The first test taken a millisecond after one of `slow`'s runs, every 50 ms from 0,
      # so that its next due time, 49 ms on, is moved to 20 ms on.
      {before, rest} = Enum.split(steps, Enum.find_index(steps, &(&1 == {:edit, :test})))
      before ++ [{:wait, rem(51 - rem(waited(before), 50), 50)} | rest]
    end

    defp waited(steps), do: Enum.sum(for {:wait, ms} <- steps, do: ms)

    defp through_runner_edited(plant, configs, steps) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)
      points = Logex.IO.points(plant)
      address = Map.new(for {_device, ps} <- points, p <- ps, do: {p.name, p.address})

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      :ok = Runner.subscribe(runner, [:overlap, :fault, :ran, :round, :edit])
      first = {nil, observed(runner, [], panel, drive)}

      log =
        Enum.map(steps, fn step ->
          reply = edit_runner(step, runner, configs, clock, panel, address)
          {reply, observed(runner, drained(runner), panel, drive)}
        end)

      Runner.stop(runner)
      [first | log]
    end

    defp edit_runner({:edit, :accept, which}, runner, configs, _clock, _panel, _address),
      do: Runner.accept(runner, Map.fetch!(configs, which))

    defp edit_runner({:edit, step}, runner, _configs, _clock, _panel, _address),
      do: apply(Runner, step, [runner])

    defp edit_runner(step, _runner, _configs, clock, panel, address) do
      step_runner(step, clock, panel, address)
      nil
    end

    # The oracle: M4-3's, Logex.Runtime.cycle/3 called directly, and each edit's step
    # taken over its resource directly with Logex.Configuration.Edit.
    defp through_oracle_edited(plant, configs, steps) do
      points = Logex.IO.points(plant)
      inputs = for {_device, ps} <- points, %{direction: :input} = p <- ps, do: p.name
      image = Map.new(inputs, &{&1, 0})
      {runtime, outputs, _events} = Logex.Runtime.cycle(Logex.Runtime.start(plant), 0, image)

      model = %{
        runtime: runtime,
        now: 0,
        last: 0,
        image: image,
        pending: %{},
        outputs: outputs,
        points: points,
        edit: nil
      }

      {log, _model} =
        Enum.map_reduce(steps, model, fn step, model ->
          {reply, events, model} = edit_oracle(step, configs, model)
          {{reply, oracle_seen(events, model)}, model}
        end)

      [{nil, oracle_seen([], model)} | log]
    end

    defp edit_oracle({:edit, :accept, which}, configs, model) do
      {:ok, edit, forecast} = ConfigEdit.accept(model.runtime, Map.fetch!(configs, which))
      {{:ok, forecast}, [{:edit, :accept, forecast}], %{model | edit: edit}}
    end

    defp edit_oracle({:edit, step}, _configs, model) when step in [:test, :untest] do
      {edit, runtime, report} = apply(ConfigEdit, step, [model.edit, model.runtime])
      {{:ok, report}, [{:edit, step, report}], %{model | edit: edit, runtime: runtime}}
    end

    defp edit_oracle({:edit, step}, _configs, model) when step in [:assemble, :cancel] do
      {_kept, runtime, report} = apply(ConfigEdit, step, [model.edit, model.runtime])
      {{:ok, report}, [{:edit, step, report}], %{model | edit: nil, runtime: runtime}}
    end

    defp edit_oracle(step, _configs, model) do
      {events, model} = step_oracle(step, model)
      {nil, events, model}
    end

    test "M4-5's Done-when: the plant edited through the runner, every report and round " <>
           "the same steps give over the resource directly, from files on disk",
         %{tmp_dir: dir} do
      plant = plant_on_disk(dir)
      candidate = candidate_on_disk(dir)
      configs = %{original: plant, candidate: candidate}
      steps = edited_steps({2026, 10, 19})

      runner_log = through_runner_edited(plant, configs, steps)
      oracle_log = through_oracle_edited(plant, configs, steps)
      assert length(runner_log) == length(oracle_log)

      for {{ran, want}, index} <- Enum.with_index(Enum.zip(runner_log, oracle_log)) do
        assert ran == want, "step #{index}: #{inspect(Enum.at([nil | steps], index))}"
      end

      # Every step was taken and reported, the candidate's first test moving `slow`'s next
      # due time within 20 ms of the step's time (decision 40), the resource's, since the
      # box counter rounds every millisecond (decision 139).
      replies = for {{:ok, report}, _seen} <- runner_log, do: report
      assert length(replies) == 11
      events = Enum.flat_map(runner_log, fn {_reply, {events, _, _, _}} -> events end)

      assert [{:edit, :accept, _}, {:edit, :test, tested} | _] =
               for({:edit, _, _} = event <- events, do: event)

      assert {:interval, "slow", {50, 20}} in tested
      assert {:preset, "boxes.boxes", {12, 6}} in tested

      {test_at, untest_at} =
        {Enum.find_index(steps, &(&1 == {:edit, :test})),
         Enum.find_index(steps, &(&1 == {:edit, :untest}))}

      now = waited(Enum.take(steps, test_at))
      assert rem(now, 50) == 1
      assert {:next_due, "slow", {now + 49, now + 20}} in tested
      to = now + 20

      # From the test to the untest, `slow` runs every 20 ms from where decision 40 put
      # it, one round each millisecond throughout, none lost or added.
      window =
        runner_log
        |> Enum.slice((test_at + 1)..untest_at)
        |> Enum.flat_map(fn {_reply, {events, _, _, _}} -> events end)

      slow_runs = for {:ran, "slow", "m2", at} <- window, do: at
      assert hd(slow_runs) == to

      assert Enum.chunk_every(slow_runs, 2, 1, :discard)
             |> Enum.all?(fn [a, b] -> b - a == 20 end)

      # A round every millisecond, and one more at once for each change of the e-stop.
      round_times = Enum.uniq(for {:round, at, _} <- window, do: at)
      assert round_times == Enum.to_list(hd(round_times)..List.last(round_times))

      # From fresh processes, exactly again.
      assert through_runner_edited(plant, configs, steps) == runner_log
    end

    test "M4-5's Done-when: the photo-eye forced, against its device, across a restart, " <>
           "a crash and a fresh start from its forces file",
         %{tmp_dir: dir} do
      plant = plant_on_disk(dir)
      file = Path.join(dir, "forces")
      points = Logex.IO.points(plant)
      address = Map.new(for {_device, ps} <- points, p <- ps, do: {p.name, p.address})

      start = fn ->
        {:ok, clock} = Manual.start_link()
        {:ok, panel} = Sim.start_link(reports: true, clock: clock)
        {:ok, drive} = Sim.start_link(clock: clock)

        {:ok, runner} =
          Runner.start_link(
            configuration: plant,
            io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
            clock: {Manual, clock},
            forces: file
          )

        {runner, clock, panel}
      end

      {runner, clock, panel} = start.()
      eye = Map.fetch!(address, "eye_1")

      # A box on the eye, counted; then the eye forced blocked while its device says clear
      # and blocked again: no box counted, the controller reading 1 throughout.
      Sim.set(panel, eye, 1)
      Manual.advance(clock, 5)
      Sim.set(panel, eye, 0)
      Manual.advance(clock, 5)
      assert Runner.get!(runner, "boxes.boxes.cv") == 1
      assert Runner.force(runner, "eye_1", 1) == :ok
      Manual.advance(clock, 5)
      assert Runner.get!(runner, "boxes.boxes.cv") == 2

      for value <- [0, 1, 0] do
        Sim.set(panel, eye, value)
        Manual.advance(clock, 5)
      end

      assert {Runner.get!(runner, "eye_1"), Runner.get!(runner, "boxes.boxes.cv")} == {1, 2}
      assert Runner.status(runner).forces == %{"eye_1" => 1}
      assert File.read!(file) == "eye_1 1\n"

      # The e-stop forced: its task runs at once, before force/3 returns.
      Runner.subscribe(runner, [:ran])
      assert Runner.force(runner, "estop", 1) == :ok
      assert_received {Runner, ^runner, {:ran, "trip", "snap", _now}}
      assert Runner.unforce(runner, "estop") == :ok

      # Refused in the caller: an output point, and a value that does not fit.
      assert_raise ArgumentError,
                   "`k1` is an output point, at `panel.q.0`: only an input point is forced",
                   fn -> Runner.force(runner, "k1", 1) end

      assert_raise ArgumentError, "`eye_1` is a bool, forced to 0 or 1, got: 2", fn ->
        Runner.force(runner, "eye_1", 2)
      end

      # Tripped by a value that does not fit, and restarted: still forced.
      Sim.set(panel, Map.fetch!(address, "pb_reset"), 7)
      assert %{status: :tripped} = Runner.status(runner)
      Sim.set(panel, Map.fetch!(address, "pb_reset"), 0)
      assert Runner.restart(runner, :cold) == :ok
      assert %{status: :running, forces: %{"eye_1" => 1}} = Runner.status(runner)
      assert Runner.get!(runner, "eye_1") == 1

      # Killed: a fresh runner from the same file comes back with the eye forced, listed.
      Process.flag(:trap_exit, true)
      Process.exit(runner, :kill)
      assert_receive {:EXIT, ^runner, :killed}
      {runner, clock, panel} = start.()
      assert %{forces: %{"eye_1" => 1}, rounds: 1} = Runner.status(runner)
      assert Runner.get!(runner, "eye_1") == 1

      # Unforced: the device's last value, which the fresh sim says is 0.
      assert Runner.unforce(runner, "eye_1") == :ok
      Manual.advance(clock, 1)
      assert Runner.get!(runner, "eye_1") == 0
      Sim.set(panel, eye, 1)
      Manual.advance(clock, 1)
      assert Runner.get!(runner, "eye_1") == 1

      # Every force off, the file written empty.
      Runner.force(runner, "eye_1", 0)
      assert Runner.unforce_all(runner) == :ok
      assert File.read!(file) == ""
      assert Runner.status(runner).forces == %{}
      Runner.stop(runner)
    end
  end

  # PLAN M5-3's Done-when: §4.4's plant reads its drive's speed as a `uint` point through
  # the simulated drive and moves it into a `dint` (decisions 144, 145, 147 and 156), from
  # files on disk through `Logex.Runner` on the manual clock; a reading the `uint` cannot
  # hold is a bad value that trips the plant, and a force is held to the `uint` too.
  describe "the integer widths in the plant (M5-3)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @fan_ld """
    var_input  hz    uint
    var_output speed dint
    move hz speed
    """

    @fan_lines """

    var_global fan_hz    uint at drive.i.0
    var_global fan_speed dint

    program fan1 fan with fast
      fan1.hz    fan_hz
      fan1.speed fan_speed
    """

    defp fan_plant(dir) do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"fan.ld", @fan_ld},
        {"plant.logex", whole_plant() <> @fan_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      plant
    end

    test "M5-3's Done-when: the drive's speed read as a uint point and moved into a dint",
         %{tmp_dir: dir} do
      plant = fan_plant(dir)
      assert plant.warnings == []
      assert %{type: :uint} = Enum.find(plant.globals, &(&1.name == "fan_hz"))

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      assert [{"drive", Sim, _, drive_points}, {"panel", Sim, _, _}] =
               Logex.IO.bind!(plant, %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}})

      assert {"fan_hz", :input, :uint} in Enum.map(
               drive_points,
               &{&1.name, &1.direction, &1.type}
             )

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      # Every value a 16-bit register gives, its top among them, reaches the dint whole: a
      # uint widens into a dint, so the oracle is the value itself.
      for hz <- [0, 1, 1200, 32_767, 32_768, 65_534, 65_535] do
        Sim.set(drive, [0], hz)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "fan_hz") == hz
        assert Runner.get!(runner, "fan1.speed") == hz
        assert Runner.get!(runner, "fan_speed") == hz
      end

      # A force is held to the uint's range, and one that fits is read as the device's is.
      assert_raise ArgumentError,
                   "`fan_hz` is a uint, forced to an integer from 0 to 65535, got: 65536",
                   fn -> Runner.force(runner, "fan_hz", 65_536) end

      assert :ok = Runner.force(runner, "fan_hz", 40_000)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "fan_speed") == 40_000
      assert File.read!(Path.join(dir, "forces")) == "fan_hz 40000\n"
      assert :ok = Runner.unforce(runner, "fan_hz")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "fan_speed") == 65_535

      # A reading the uint cannot hold is a bad value, and the plant trips on it.
      Sim.set(drive, [0], 65_536)
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [0], 65_536}}
      assert Runner.get!(runner, "fan_speed") == 65_535
      Runner.stop(runner)
    end
  end

  # PLAN M5-8's Done-when: §4.4's plant reads its drive's status as a `word` point through
  # the simulated drive, `var_global drive_status word at drive.i.4`, and its bit 3, "at
  # speed", lights the run lamp (decisions 155 and 156), from files on disk through
  # `Logex.Runner` on the manual clock, against an oracle that knows nothing of logex; a
  # reading the word cannot hold, 65,536, -1 or a float, is a bad value that trips the
  # plant, and a force is held to the word, read back from the forces file across a
  # restart and a fresh start.
  describe "a bit string in the plant (M5-8)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @lamp_ld """
    var_input  status word
    var_output lamp   bool
    xic status.3 ote lamp
    """

    @lamp_lines """

    var_global drive_status word at drive.i.4
    var_global run_lamp     bool at panel.q.6

    program lamp1 lamp with fast
      lamp1.status drive_status
      lamp1.lamp   run_lamp
    """

    defp lamp_plant(dir) do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"lamp.ld", @lamp_ld},
        {"plant.logex", whole_plant() <> @lamp_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      plant
    end

    defp lamp_runner(plant, dir) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      {runner, clock, panel, drive}
    end

    # The oracle: bit 3 of a 16-bit register, by division.
    defp at_speed(status), do: rem(div(status, 8), 2)

    test "M5-8's Done-when: the drive's status read as a word point, its bit 3 lighting the run lamp",
         %{tmp_dir: dir} do
      plant = lamp_plant(dir)
      assert plant.warnings == []
      assert %{type: :word} = Enum.find(plant.globals, &(&1.name == "drive_status"))

      assert {"drive_status", :input, [4], :word} in Enum.map(
               Map.fetch!(Logex.IO.points(plant), "drive"),
               &{&1.name, &1.direction, &1.address, &1.type}
             )

      {runner, clock, panel, drive} = lamp_runner(plant, dir)

      :rand.seed(:exsss, {8, 5, 8})

      statuses =
        [0, 8, 7, 0xFFFF, 0xFFF7, 0x8008, 0x8000] ++
          for(_ <- 1..40, do: :rand.uniform(65_536) - 1)

      for status <- statuses do
        Sim.set(drive, [4], status)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "drive_status") == status
        assert Runner.get!(runner, "run_lamp") == at_speed(status), inspect(status)
        assert Sim.outputs(panel)[[6]] == at_speed(status)
      end

      # A force is held to the word, read as the device's is, and kept in the forces file.
      assert_raise ArgumentError,
                   "`drive_status` is a word, forced to an integer from 0 to 65535, got: 65536",
                   fn -> Runner.force(runner, "drive_status", 65_536) end

      assert_raise ArgumentError,
                   "`drive_status` is a word, forced to an integer from 0 to 65535, got: -1",
                   fn -> Runner.force(runner, "drive_status", -1) end

      Sim.set(drive, [4], 0)
      assert :ok = Runner.force(runner, "drive_status", 65_535)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "run_lamp") == 1
      assert File.read!(Path.join(dir, "forces")) == "drive_status 65535\n"

      # Each reading the word cannot hold is a bad value, and the plant trips on it; put
      # right, it restarts with the force still on.
      for {bad, how} <- [{65_536, :set}, {-1, :set}, {37.5, :read}] do
        assert :ok = Runner.unforce(runner, "drive_status")
        bad_reading(how, drive, bad)
        Manual.advance(clock, 10)
        assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [4], bad}}
        Sim.set(drive, [4], 0)
        assert :ok = Runner.force(runner, "drive_status", 65_535)
        assert Runner.restart(runner, :cold) == :ok
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "run_lamp") == 1
      end

      Runner.stop(runner)

      # A fresh start reads the force back from its file.
      {runner, clock, _panel, drive} = lamp_runner(plant, dir)
      Sim.set(drive, [4], 0)
      Manual.advance(clock, 10)
      assert Runner.status(runner).forces == %{"drive_status" => 65_535}
      assert Runner.get!(runner, "run_lamp") == 1
      Runner.stop(runner)

      # A host's input is held to the word too, in its words.
      {:ok, lamp} = Logex.compile_file(Path.join(dir, "lamp.ld"))

      for value <- [65_536, -1] do
        assert_raise ArgumentError,
                     "input `status` is a word: #{value} is outside 0 to 65535",
                     fn ->
                       Logex.Runtime.put_inputs(lamp, Logex.Runtime.instance(lamp), %{
                         "status" => value
                       })
                     end
      end

      assert_raise ArgumentError,
                   "input `status` is a word: its value must be an integer, found 37.5",
                   fn ->
                     Logex.Runtime.put_inputs(lamp, Logex.Runtime.instance(lamp), %{
                       "status" => 37.5
                     })
                   end
    end

    defp bad_reading(:set, drive, value), do: Sim.set(drive, [4], value)
    defp bad_reading(:read, drive, value), do: Sim.fail(drive, :read, {:value, [4], value})
  end

  # PLAN M5-9's Done-when: §4.4's plant shows on its run lamp the bit of the drive's fault
  # word that the panel's selector names, `xic drive_faults.[sel] ote lamp` (decision 160),
  # from files on disk through `Logex.Runner` on the manual clock, against an oracle that
  # knows nothing of logex; `sel` at 16 in a `word` trips the runner at the end of the fast
  # task's step, before the round's write, every output 0 once and nothing after, the trip
  # naming the instance, the file, the line and the number (decisions 153 and 160), the slow
  # task's step of that round never run.
  describe "a bit number held in a tag in the plant (M5-9)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @selected_ld """
    var_input  faults word
    var_input  sel    int
    var_output lamp   bool
    // the fault the operator selects
    xic faults.[sel] ote lamp
    """

    @selected_lines """

    var_global drive_faults word at drive.i.4
    var_global sel          int  at panel.i.8
    var_global run_lamp     bool at panel.q.6

    program lamp1 selected with fast
      lamp1.faults drive_faults
      lamp1.sel    sel
      lamp1.lamp   run_lamp
    """

    # The oracle: bit n of a 16-bit register, by division.
    defp selected(faults, n), do: rem(div(faults, Integer.pow(2, n)), 2)

    test "M5-9's Done-when: the run lamp follows `drive_faults.[sel]`, and `sel` at 16 trips the plant",
         %{tmp_dir: dir} do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"selected.ld", @selected_ld},
        {"plant.logex", whole_plant() <> @selected_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      assert plant.warnings == []

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      :rand.seed(:exsss, {5, 9, 160})

      for _ <- 1..60 do
        faults = :rand.uniform(65_536) - 1
        n = :rand.uniform(16) - 1
        Sim.set(drive, [4], faults)
        Sim.set(panel, [8], n)
        Manual.advance(clock, 10)
        assert Runner.get!(runner, "run_lamp") == selected(faults, n), inspect({faults, n})
        assert Sim.outputs(panel)[[6]] == selected(faults, n)
      end

      # Every output lit that can be, the lamp among them, then `sel` at 16 as the slow
      # task falls due: the fast task's step trips, the slow task's never runs.
      Sim.set(drive, [4], 0xFFFF)
      Sim.set(panel, %{[0] => 1, [3] => 1, [8] => 15})
      Manual.advance(clock, 10)
      assert Sim.outputs(panel)[[6]] == 1
      assert Sim.outputs(panel)[[0]] == 1

      %{now: now} = Runner.status(runner)
      at = now + 50 - rem(now, 50)
      Manual.advance(clock, at - now - 1)
      Runner.subscribe(runner, [:ran, :fault, :trip, :round])
      Sim.set(panel, [8], 16)
      Manual.advance(clock, 1)

      fault = %Logex.Fault{
        severity: :major,
        kind: :bit_out_of_range,
        instruction: :xic,
        path: nil,
        file: Path.join(dir, "selected.ld"),
        line: 5,
        read: 16
      }

      assert Runner.status(runner).trip == {:fault, "fast", "lamp1", fault}
      assert_receive {Runner, ^runner, {:ran, "fast", "lamp1", ^at}}
      assert_receive {Runner, ^runner, {:fault, "fast", "lamp1", ^fault}}
      assert_receive {Runner, ^runner, {:trip, {:fault, "fast", "lamp1", ^fault}}}
      refute_received {Runner, ^runner, {:ran, "slow", "m2", ^at}}
      refute_received {Runner, ^runner, {:round, ^at, _}}

      # Every output 0 once, through each device, and nothing after.
      panel_writes = Sim.writes(panel)
      drive_writes = Sim.writes(drive)
      assert List.last(panel_writes) == Map.new([0, 1, 2, 3, 6], &{[&1], 0})
      assert List.last(drive_writes) == %{[0] => 0, [1] => 0}
      Manual.advance(clock, 1000)
      Sim.set(panel, [8], 3)
      Manual.advance(clock, 1000)
      assert {Sim.writes(panel), Sim.writes(drive)} == {panel_writes, drive_writes}
      Runner.stop(runner)
    end
  end

  # PLAN M5-10's Done-when: §4.4's plant reads its fan's speed as a `real` point through
  # the simulated drive, `var_global fan_hz real at drive.i.0`, and computes its speed in
  # revolutions a minute in a `real` and an `lreal`, lighting an alarm over an `int` limit
  # (decisions 147, 150, 156 and 166), from files on disk through `Logex.Runner` on the
  # manual clock, against an oracle that knows nothing of logex: a single is restated
  # through the BEAM's own 32-bit float encoding. An integer reading is stored as its
  # nearest real, one past a real's range trips the plant, and a force of `0.1` is written
  # and read back exactly, across a restart and a fresh start.
  describe "a real in the plant (M5-10)" do
    @describetag :tmp_dir

    alias Logex.Configuration.Text
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @speed_ld """
    var_input  hz    real
    var_input  limit int
    var_output speed real
    var_output rpm   lreal
    var_output over  bool
    // revolutions a minute, in a real and in an lreal, and the alarm over the limit
    mul hz 60.0 speed
    mul hz 60.0 rpm
    gt speed limit ote over
    """

    @speed_lines """

    var_global fan_hz    real  at drive.i.0
    var_global fan_limit int   3000
    var_global fan_speed real
    var_global fan_rpm   lreal 0.1
    var_global fan_over  bool  at panel.q.7

    program fan1 speed with fast
      fan1.hz    fan_hz
      fan1.limit fan_limit
      fan1.speed fan_speed
      fan1.rpm   fan_rpm
      fan1.over  fan_over
    """

    # The oracle: a single is the 32-bit float nearest a double, as IEEE 754 rounds it,
    # the BEAM's encoding restated, with −0.0 and a single too small to be normal 0.0.
    defp single(x) do
      <<y::float-32>> = <<x::float-32>>
      flushed(y)
    end

    defp flushed(y) when abs(y) < 1.1754943508222875e-38, do: 0.0
    defp flushed(y), do: y

    # A single past its range saturates at its largest finite value.
    defp saturated(x) when abs(x) > 3.4028234663852886e38, do: 3.4028234663852886e38
    defp saturated(x), do: single(x)

    defp speed_plant(dir) do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"speed.ld", @speed_ld},
        {"plant.logex", whole_plant() <> @speed_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      plant
    end

    defp speed_runner(plant, dir) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      {runner, clock, panel, drive}
    end

    test "M5-10's Done-when: the fan's speed is a real read from the drive", %{tmp_dir: dir} do
      plant = speed_plant(dir)
      assert plant.warnings == []
      assert %{type: :real, at: "drive.i.0"} = Enum.find(plant.globals, &(&1.name == "fan_hz"))

      # The configuration file's round trip holds with reals, `0.1` in an lreal printed as
      # written.
      text = Text.print(plant)
      assert text =~ "var_global fan_rpm lreal 0.1\n"

      assert Logex.Configuration.compile("plant", text, plant.programs) ==
               {:ok, %{plant | file: nil}}

      {runner, clock, panel, drive} = speed_runner(plant, dir)
      :rand.seed(:exsss, {5, 10, 150})

      readings =
        [0, 50, 37.5, 0.1, 16_777_217, -0.0, 1.0e-40, 3.4028235e38, -12.25] ++
          for(_ <- 1..60, do: Enum.random([:rand.uniform() * 100, :rand.uniform(100)]))

      for reading <- readings do
        Sim.set(drive, [0], reading)
        Manual.advance(clock, 10)
        hz = single(reading * 1.0)

        speed = saturated(hz * 60.0)
        over = bit(speed > 3000)
        assert Runner.get!(runner, "fan_hz") === hz, inspect(reading)
        assert Runner.get!(runner, "fan_speed") === speed, inspect(reading)
        assert Runner.get!(runner, "fan_rpm") === hz * 60.0 + 0.0, inspect(reading)
        assert Sim.outputs(panel)[[7]] == over, inspect(reading)
      end

      # A force is held to the real's nearest value, written as the shortest text that
      # reads back to it, and read back exactly across a restart and a fresh start.
      assert_raise ArgumentError,
                   "`fan_hz` is a real, forced to a number from -3.4028234663852886e38 to " <>
                     "3.4028234663852886e38, got: 1.0e39",
                   fn -> Runner.force(runner, "fan_hz", 1.0e39) end

      assert :ok = Runner.force(runner, "fan_hz", 0.1)
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "fan_hz") === single(0.1)
      assert Runner.get!(runner, "fan_speed") === single(single(0.1) * 60.0)
      assert File.read!(Path.join(dir, "forces")) == "fan_hz 0.1\n"

      # A reading past the real's range is a bad value, and the plant trips on it.
      assert :ok = Runner.unforce(runner, "fan_hz")
      Sim.set(drive, [0], Integer.pow(2, 128))
      Manual.advance(clock, 10)
      assert Runner.status(runner).trip == {:io, "drive", {:bad_value, [0], Integer.pow(2, 128)}}
      Sim.set(drive, [0], 50.5)
      assert :ok = Runner.force(runner, "fan_hz", 0.1)
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "fan_hz") === single(0.1)
      Runner.stop(runner)

      {runner, clock, _panel, drive} = speed_runner(plant, dir)
      Sim.set(drive, [0], 50.5)
      Manual.advance(clock, 10)
      assert Runner.status(runner).forces == %{"fan_hz" => single(0.1)}
      assert Runner.get!(runner, "fan_hz") === single(0.1)
      assert :ok = Runner.unforce(runner, "fan_hz")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "fan_speed") === 3030.0
      assert Runner.get!(runner, "fan_over") == 1
      Runner.stop(runner)
    end
  end

  # PLAN M5-5's Done-when: IEC's typed counters in a plant, from files on disk through
  # Logex.Configuration.compile_file/1 and Logex.Runtime.cycle/3: a stock counted as an
  # int stopping at 32767 with `ov` on, a hopper of udints stopping at 0 with `un` on, and
  # a `ctu_dint` box counter the very `ctu` it names, against an oracle that knows nothing
  # of logex.
  describe "typed counters (M5-5)" do
    @describetag :tmp_dir

    @line_ld """
    var_input infeed bool
    var_input outfeed bool
    var_input refill bool
    var_input full_load bool
    var_output stock_over bool
    var_output hopper_under bool
    var stock ctud_int
    var hopper ctd_udint
    var boxes ctu_dint
    xic full_load ote stock.ld
    xic infeed ctu stock 32767
    xic outfeed ctd stock 32767
    xic refill ote hopper.ld
    xic outfeed ctd hopper 2
    xic infeed ctu boxes 3
    xic stock.ov ote stock_over
    xic hopper.un ote hopper_under
    """

    @line_logex """
    task fast interval 10 priority 1
    var_global infeed bool at panel.i.0
    var_global outfeed bool at panel.i.1
    var_global refill bool at panel.i.2
    var_global full_load bool at panel.i.3
    var_global over bool at panel.q.0
    var_global under bool at panel.q.1
    program line line with fast
    line.infeed infeed
    line.outfeed outfeed
    line.refill refill
    line.full_load full_load
    line.stock_over over
    line.hopper_under under
    """

    # The oracle: IEC's CTUD and CTD bodies restated, each stopping at its type's limits.
    defp oracle(model, step) do
      infeed = step["infeed"] == 1 and model.last["infeed"] == 0
      outfeed = step["outfeed"] == 1 and model.last["outfeed"] == 0
      stock = stock_up(step["full_load"], infeed, model.stock)
      stock = stock_down(step["full_load"], outfeed, stock)
      hopper = hopper_down(step["refill"], outfeed, model.hopper)
      %{model | stock: stock, hopper: hopper, last: step}
    end

    # The ctud_int's up side: LD, then an edge at its top, then an edge.
    defp stock_up(1, _edge, stock), do: %{stock | cv: 32_767, ov: 0, un: 0}
    defp stock_up(_load, true, %{cv: 32_767} = stock), do: %{stock | ov: 1}
    defp stock_up(_load, true, stock), do: %{stock | cv: stock.cv + 1}
    defp stock_up(_load, false, stock), do: stock

    # Its down side, after: LD again holds it, then an edge at its bottom, then an edge.
    defp stock_down(1, _edge, stock), do: stock
    defp stock_down(_load, true, %{cv: -32_768} = stock), do: %{stock | un: 1}
    defp stock_down(_load, true, stock), do: %{stock | cv: stock.cv - 1}
    defp stock_down(_load, false, stock), do: stock

    # The ctd_udint: LD, then an edge at 0, then an edge.
    defp hopper_down(1, _edge, _hopper), do: %{cv: 2, un: 0}
    defp hopper_down(_load, true, %{cv: 0} = hopper), do: %{hopper | un: 1}
    defp hopper_down(_load, true, hopper), do: %{hopper | cv: hopper.cv - 1}
    defp hopper_down(_load, false, hopper), do: hopper

    test "M5-5's Done-when: a ctud_int and a ctd_udint stop at their types' limits in a plant",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "line.ld"), @line_ld)
      File.write!(Path.join(dir, "plant.logex"), @line_logex)
      {:ok, config} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      runtime = Logex.Runtime.start(config)

      # The first cycle is the instance's first scan, which counts nothing.
      idle = %{"infeed" => 0, "outfeed" => 0, "refill" => 0, "full_load" => 0}

      {runtime, _, _} = Logex.Runtime.cycle(runtime, 0, idle)

      model = %{stock: %{cv: 0, ov: 0, un: 0}, hopper: %{cv: 0, un: 0}, last: idle}

      steps =
        [Map.put(idle, "full_load", 1), idle] ++
          List.duplicate([Map.put(idle, "infeed", 1), idle], 3) ++
          [[Map.put(idle, "refill", 1), idle]] ++
          List.duplicate([Map.put(idle, "outfeed", 1), idle], 4) ++
          [Map.put(idle, "full_load", 1), idle]

      Enum.reduce(List.flatten(steps), {runtime, model}, fn step, {runtime, model} ->
        {runtime, outputs, _events} = Logex.Runtime.cycle(runtime, 10, step)
        model = oracle(model, step)
        assert Logex.Runtime.get!(runtime, "line.stock.cv") == model.stock.cv
        assert Logex.Runtime.get!(runtime, "line.stock.ov") == model.stock.ov
        assert Logex.Runtime.get!(runtime, "line.hopper.cv") == model.hopper.cv
        assert Logex.Runtime.get!(runtime, "line.hopper.un") == model.hopper.un
        assert outputs == %{"over" => model.stock.ov, "under" => model.hopper.un}
        {runtime, Map.update(model, :seen, [outputs], &[outputs | &1])}
      end)
      |> then(fn {runtime, model} ->
        # The stock reached its top, its `ov` set and cleared by a load, the hopper its
        # bottom, and the boxes counted as a `ctu`.
        assert %{"over" => 1, "under" => 0} in model.seen
        assert %{"over" => 0, "under" => 1} in model.seen
        assert {model.stock, model.hopper} == {%{cv: 32_767, ov: 0, un: 0}, %{cv: 0, un: 1}}
        assert Logex.Runtime.get!(runtime, "line.boxes.cv") == 3
      end)

      # `ctu_dint` declared the very `ctu`: the program's tag holds the type `ctu` gives.
      {:ok, line} = Logex.compile_file(Path.join(dir, "line.ld"))
      assert line.tags["boxes"].type == Logex.FbType.ctu()
    end
  end

  # PLAN M5-6's Done-when in a plant, from files on disk through
  # Logex.Configuration.compile_file/1 and Logex.Runtime.cycle/3: a curing press's 30-day
  # `ton_ltime`, and the one rung `ton t 2000000` on a `ton` and on a `ton_ltime`, over
  # seeded presses and waits, against an oracle that knows nothing of logex: a lamp is lit
  # once its press has been held, cycle after cycle, for its delay, 30 days, 2,000,000 ms
  # or 2 ms, the time a cycle passes counted in whole ms.
  describe "long timers (M5-6)" do
    @describetag :tmp_dir

    @press_ld """
    var_input press bool
    var_output cured bool
    var_output slow_lamp bool
    var_output quick_lamp bool
    var cure ton_ltime
    var slow ton
    var quick ton_ltime
    xic press ton cure 2592000000000000
    xic press ton slow 2000000
    xic press ton quick 2000000
    xic cure.dn ote cured
    xic slow.dn ote slow_lamp
    xic quick.dn ote quick_lamp
    """

    # The continuous task runs the press at every cycle, whatever the time it passes.
    @press_logex """
    task main continuous
    var_global press bool at panel.i.0
    var_global cured bool at panel.q.0
    var_global slow_lamp bool at panel.q.1
    var_global quick_lamp bool at panel.q.2
    program p press
    p.press press
    p.cured cured
    p.slow_lamp slow_lamp
    p.quick_lamp quick_lamp
    """

    test "M5-6's Done-when: a 30-day cure and the one rung's two units in a plant",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "press.ld"), @press_ld)
      File.write!(Path.join(dir, "plant.logex"), @press_logex)
      {:ok, config} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      day = 86_400_000
      delays = %{"cured" => 30 * day, "slow_lamp" => 2_000_000, "quick_lamp" => 2}

      # The oracle: the time the press has been held, from the first cycle that saw it.
      lit = fn held ->
        Map.new(delays, fn {lamp, delay} ->
          {lamp, bit(held != nil and held >= delay)}
        end)
      end

      :rand.seed(:exsss, {2026, 10, 156})

      waits =
        for _ <- 1..400 do
          {Enum.random([0, 1, 1, 2, 3, 1_000, 1_999_997, 3_600_000, day, 7 * day]),
           Enum.random([1, 1, 1, 1, 1, 1, 1, 0])}
        end

      # Each delay's edge: held one ms short of it, then at it.
      edges =
        for delay <- [2, 2_000_000, 30 * day],
            step <- [{0, 0}, {0, 1}, {delay - 1, 1}, {1, 1}],
            do: step

      seen =
        Enum.reduce(edges ++ waits, {Logex.Runtime.start(config), nil, []}, fn
          {elapsed, press}, {runtime, held, seen} ->
            {runtime, outputs, _events} =
              Logex.Runtime.cycle(runtime, elapsed, %{"press" => press})

            held = held_for(press, held, elapsed)
            assert outputs == lit.(held), "held #{inspect(held)}"
            {runtime, held, [outputs | seen]}
        end)
        |> elem(2)

      # Each lamp was seen lit and dark, the slow one dark while the quick one was lit.
      for lamp <- Map.keys(delays),
          value <- [0, 1],
          do: assert(Enum.any?(seen, &(&1[lamp] == value)))

      assert Enum.any?(seen, &(&1["quick_lamp"] == 1 and &1["slow_lamp"] == 0))

      # The rung's unit is its instance's: the two compiled tags differ in type alone.
      {:ok, press} = Logex.compile_file(Path.join(dir, "press.ld"))
      assert press.tags["slow"].type == Logex.FbType.ton()
      assert press.tags["quick"].type == Logex.FbType.ton_ltime()
    end
  end

  # PLAN M5-11's Done-when in a plant, from files on disk through
  # `Logex.Configuration.compile_file/1` and `Logex.Runtime.cycle/3`: a checkweigher keeps
  # the last eight weights in `weights int[8]`, shifting them along on each pick's rising
  # edge, `ons edges[1]` (decision 154), copies the fourth, `weights[3]`, into `grid[1,7]`
  # of an `int[4,8]` and into a var_output array connected whole to a global array, and
  # lights a lamp while `weights[3]` is over 500, over seeded loads and picks, against an
  # oracle that knows nothing of logex: a list of eight weights, shifted.
  describe "arrays in the plant (M5-11)" do
    @describetag :tmp_dir

    @weigh_ld """
    var_input  load    int
    var_input  pick    bool
    var_output heavy   bool
    var_output corner  int
    var_output history int[8]
    var weights int[8]
    var grid    int[4,8]
    var edges   bool[2]
    var p       bool
    xic pick ons edges[1] ote p
    xic p move weights[6] weights[7]
    xic p move weights[5] weights[6]
    xic p move weights[4] weights[5]
    xic p move weights[3] weights[4]
    xic p move weights[2] weights[3]
    xic p move weights[1] weights[2]
    xic p move weights[0] weights[1]
    xic p move load weights[0]
    xic p move weights[3] grid[1,7]
    xic p move weights[3] history[3]
    gt weights[3] 500 ote heavy
    move grid[1,7] corner
    """

    @weigh_logex """
    task fast interval 10 priority 1
    var_global load    int  at panel.i.0
    var_global pick    bool at panel.i.1
    var_global heavy   bool at panel.q.0
    var_global corner  int  at panel.q.1
    var_global history int[8] 1 1 1 1 1 1 1 1
    program line weigh with fast
    line.load    load
    line.pick    pick
    line.heavy   heavy
    line.corner  corner
    line.history history
    """

    # Eight weights shifted along on a pick's rising edge, the fourth copied out.
    defp weighed(true, load, model) do
      weights = [load | Enum.take(model.weights, 7)]

      %{
        model
        | weights: weights,
          corner: Enum.at(weights, 3),
          history3: Enum.at(weights, 3),
          shifts: model.shifts + 1
      }
    end

    defp weighed(false, _load, model), do: model

    # The time the press has been held: 0 at the first cycle that sees it, nil released.
    defp held_for(1, nil, _elapsed), do: 0
    defp held_for(1, held, elapsed), do: held + elapsed
    defp held_for(_released, _held, _elapsed), do: nil

    test "M5-11's Done-when: `weights[3]` and `grid[1,7]` run in a plant against an oracle",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "weigh.ld"), @weigh_ld)
      File.write!(Path.join(dir, "plant.logex"), @weigh_logex)
      {:ok, config} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))

      assert Logex.Configuration.Text.print(config) =~
               "var_global history int[8] 1 1 1 1 1 1 1 1\n"

      runtime = Logex.Runtime.start(config)
      assert Logex.Runtime.get!(runtime, "history") == List.duplicate(1, 8)

      :rand.seed(:exsss, {2026, 10, 23})

      steps =
        for _ <- 1..400,
            do: %{"load" => :rand.uniform(1000) - 1, "pick" => :rand.uniform(2) - 1}

      # The oracle: the last eight weights, newest first, shifted on a pick's rising edge,
      # never on the first scan; the corner and the history's fourth the fourth weight
      # once a pick has shifted it there, the history's copy-out writing over the global's
      # initial list from the first scan on.
      model = %{
        weights: List.duplicate(0, 8),
        last: 0,
        first: true,
        corner: 0,
        history3: 0,
        shifts: 0
      }

      {_runtime, model} =
        Enum.reduce(steps, {runtime, model}, fn step, {runtime, model} ->
          {runtime, outputs, _events} = Logex.Runtime.cycle(runtime, 10, step)
          rose = step["pick"] == 1 and model.last == 0 and not model.first

          model = weighed(rose, step["load"], model)

          model = %{model | last: step["pick"], first: false}
          fourth = Enum.at(model.weights, 3)

          assert Logex.Runtime.get!(runtime, "line.weights") == model.weights
          assert Logex.Runtime.get!(runtime, "line.weights[3]") == fourth
          assert Logex.Runtime.get!(runtime, "line.grid[1,7]") == model.corner
          assert Logex.Runtime.get!(runtime, "history[3]") == model.history3
          assert Logex.Runtime.get!(runtime, "line.history[3]") == model.history3

          heavy = bit(fourth > 500)

          assert outputs == %{"heavy" => heavy, "corner" => model.corner}
          {runtime, Map.update(model, :lit, [heavy], &[heavy | &1])}
        end)

      # The walk lit the lamp and left it dark, and shifted every weight along many times.
      assert 1 in model.lit and 0 in model.lit
      assert model.shifts > 50
    end
  end

  # PLAN M5-12's Done-when: §4.4's plant weighs each box the photo-eye sees into the slot
  # the panel names, `weights[slot]` (decision 152), from files on disk through
  # `Logex.Runner` on the manual clock, against an oracle that knows nothing of logex: eight
  # weights in a list. `slot` at 8, the rung that steps it edited wrongly, trips the runner
  # at the end of the fast task's step as the slow task falls due, before the round's
  # write, every output 0 once and nothing after, the trip naming the instance, the file,
  # the line and the index (decision 153), the slow task's step of that round never run.
  describe "a subscript held in a tag in the plant (M5-12)" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @scales_ld """
    var_input  eye    bool
    var_input  weight int
    var_input  slot   int
    var_output last   int
    var_output heavy  bool
    var weights int[8]
    var edge    bool
    var p       bool
    // each box's weight, kept in the slot the panel names
    xic eye ons edge ote p
    xic p move weight weights[slot]
    move weights[slot] last
    gt weights[slot] 500 ote heavy
    """

    @scales_lines """

    var_global box_eye    bool at panel.i.8
    var_global box_slot   int  at panel.i.9
    var_global box_weight int  at drive.i.4
    var_global box_last   int  at panel.q.7
    var_global box_heavy  bool at panel.q.6

    program scales scales with fast
      scales.eye    box_eye
      scales.weight box_weight
      scales.slot   box_slot
      scales.last   box_last
      scales.heavy  box_heavy
    """

    test "M5-12's Done-when: the box counter's `weights[slot]` runs in the plant, and `slot` at 8 trips it",
         %{tmp_dir: dir} do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"scales.ld", @scales_ld},
        {"plant.logex", whole_plant() <> @scales_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      assert plant.warnings == []

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{"panel" => {Sim, sim: panel}, "drive" => {Sim, sim: drive}},
          clock: {Manual, clock}
        )

      :rand.seed(:exsss, {5, 12, 152})

      # The oracle: eight weights, a box's written into the slot named as the eye rises,
      # the first round, which ran at start with the eye dark, counting none.
      {weights, _eye} =
        Enum.reduce(1..200, {List.duplicate(0, 8), 0}, fn _, {weights, last_eye} ->
          eye = Enum.random([0, 0, 1])
          weight = Enum.random(0..999)
          slot = Enum.random(0..7)
          Sim.set(drive, [4], weight)
          Sim.set(panel, %{[8] => eye, [9] => slot})
          Manual.advance(clock, 10)

          weights = box_weighed(eye == 1 and last_eye == 0, weights, {slot, weight})
          last = Enum.at(weights, slot)
          heavy = bit(last > 500)
          assert Runner.get!(runner, "scales.weights") == weights
          assert Runner.get!(runner, "box_last") == last
          assert Sim.outputs(panel)[[7]] == last
          assert Sim.outputs(panel)[[6]] == heavy
          {weights, eye}
        end)

      assert Enum.count(weights, &(&1 > 0)) >= 6

      # Every output lit that can be, then `slot` at 8 as the slow task falls due: the fast
      # task's step trips, the slow task's never runs.
      heavy_slot = Enum.find_index(weights, &(&1 > 500))
      Sim.set(panel, %{[0] => 1, [3] => 1, [8] => 0, [9] => heavy_slot})
      Manual.advance(clock, 10)
      assert Sim.outputs(panel)[[6]] == 1
      assert Sim.outputs(panel)[[0]] == 1

      %{now: now} = Runner.status(runner)
      at = now + 50 - rem(now, 50)
      Manual.advance(clock, at - now - 1)
      Runner.subscribe(runner, [:ran, :fault, :trip, :round])
      Sim.set(panel, [9], 8)
      Manual.advance(clock, 1)

      fault = %Logex.Fault{
        severity: :major,
        kind: :index_out_of_range,
        instruction: :move,
        path: nil,
        file: Path.join(dir, "scales.ld"),
        line: 12,
        read: {8}
      }

      assert Runner.status(runner).trip == {:fault, "fast", "scales", fault}
      assert_receive {Runner, ^runner, {:ran, "fast", "scales", ^at}}
      assert_receive {Runner, ^runner, {:fault, "fast", "scales", ^fault}}
      refute_received {Runner, ^runner, {:ran, "slow", "m2", ^at}}
      refute_received {Runner, ^runner, {:round, ^at, _}}

      # Every output 0 once, through each device, and nothing after.
      outputs =
        for {device, points} <- Logex.IO.points(plant),
            %{direction: :output, address: address} <- points,
            reduce: %{} do
          acc -> Map.update(acc, device, %{address => 0}, &Map.put(&1, address, 0))
        end

      panel_writes = Sim.writes(panel)
      drive_writes = Sim.writes(drive)
      assert List.last(panel_writes) == outputs["panel"]
      assert List.last(drive_writes) == outputs["drive"]
      assert Map.keys(outputs["panel"]) |> Enum.member?([7])
      Manual.advance(clock, 1000)
      Sim.set(panel, [9], 3)
      Manual.advance(clock, 1000)
      assert {Sim.writes(panel), Sim.writes(drive)} == {panel_writes, drive_writes}
      Runner.stop(runner)
    end
  end

  # PLAN M5-13's Done-when: §4.4's plant reads its oven card's eight zone temperatures as
  # one located array, `var_global zone_t real[8] at card.i.0`, each element a point at
  # its own address (decision 156), and lights a lamp for each zone over its setpoint
  # through a located array of output points, `zone_hot bool[8] at card.q.0`, from files
  # on disk through `Logex.Runner` on the manual clock, against an oracle that knows
  # nothing of logex: eight singles in a list, restated through the BEAM's 32-bit encoding.
  # `zone_t[3]` is forced against its device, across a restart, a crash and a fresh start
  # from its forces file; a sim of seven inputs is refused for the range past it.
  describe "a located array in the plant (M5-13)" do
    @describetag :tmp_dir

    alias Logex.Configuration.Text
    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    @zones_ld """
    var_input  t   real[8]
    var_input  sp  real
    var_output hot bool[8]
    var_output t0  real
    // a lamp for each zone over its setpoint
    gt t[0] sp ote hot[0]
    gt t[1] sp ote hot[1]
    gt t[2] sp ote hot[2]
    gt t[3] sp ote hot[3]
    gt t[4] sp ote hot[4]
    gt t[5] sp ote hot[5]
    gt t[6] sp ote hot[6]
    gt t[7] sp ote hot[7]
    move t[0] t0
    """

    @zones_lines """

    var_global zone_t   real[8] at card.i.0
    var_global zone_hot bool[8] at card.q.0
    var_global zone_sp  real    180.0
    var_global zone_t0  real

    program oven zones with fast
      oven.t   zone_t
      oven.sp  zone_sp
      oven.hot zone_hot
      oven.t0  zone_t0
    """

    defp one_single(x) do
      <<y::float-32>> = <<x::float-32>>
      y
    end

    defp oven_runner(plant, dir, card) do
      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: %{
            "panel" => {Sim, sim: panel},
            "drive" => {Sim, sim: drive},
            "card" => {Sim, sim: card}
          },
          clock: {Manual, clock},
          forces: Path.join(dir, "forces")
        )

      {runner, clock}
    end

    # The runner killed is reported by its devices as they go down.
    @tag :capture_log
    test "M5-13's Done-when: the oven card's eight zones are one located array", %{tmp_dir: dir} do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"zones.ld", @zones_ld},
        {"plant.logex", whole_plant() <> @zones_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      assert plant.warnings == []

      # Printed back exactly; and its points, the card's, one an element.
      text = Text.print(plant)
      assert text =~ "var_global zone_t real[8] at card.i.0\n"

      assert Logex.Configuration.compile("plant", text, plant.programs) ==
               {:ok, %{plant | file: nil}}

      assert for(
               p <- Map.fetch!(Logex.IO.points(plant), "card"),
               do: {p.name, p.direction, p.address}
             ) ==
               for(i <- 0..7, do: {"zone_t[#{i}]", :input, [i]}) ++
                 for(i <- 0..7, do: {"zone_hot[#{i}]", :output, [i]})

      # A card of seven inputs is refused for the range past it, at start, in the caller.
      {:ok, short} = Sim.start_link(inputs: 7)

      assert_raise ArgumentError,
                   "the device `card`'s adapter options: `zone_t[7]` is at `card.i.7`, past the sim's 7 inputs, `card.i.0` to `card.i.6`",
                   fn -> oven_runner(plant, dir, short) end

      {:ok, card} = Sim.start_link(reports: true, inputs: 8, outputs: 8)
      {runner, clock} = oven_runner(plant, dir, card)
      :rand.seed(:exsss, {5, 13, 156})

      # The oracle: eight singles, each zone's lamp lit while its temperature is over 180.
      temps =
        Enum.reduce(1..120, List.duplicate(0.0, 8), fn _, temps ->
          changed =
            for zone <- Enum.take_random(0..7, Enum.random(1..8)),
                into: %{},
                do: {zone, Enum.random([Enum.random(0..400), :rand.uniform() * 400])}

          Sim.set(card, Map.new(changed, fn {zone, t} -> {[zone], t} end))
          Manual.advance(clock, 10)

          temps =
            Enum.reduce(changed, temps, fn {zone, t}, temps ->
              List.replace_at(temps, zone, one_single(t * 1.0))
            end)

          assert Runner.get!(runner, "zone_t") == temps
          assert Runner.get!(runner, "zone_t0") === hd(temps)

          assert for(i <- 0..7, do: Sim.outputs(card)[[i]]) ==
                   for(t <- temps, do: bit(t > 180.0))

          temps
        end)

      # Zone 3 forced over its setpoint against a card that says it is cold: its lamp
      # lit, the zones beside it still the card's, its line in the forces file by name.
      Sim.set(card, %{[3] => 20, [4] => 20})
      assert :ok = Runner.force(runner, "zone_t[3]", 250)
      Manual.advance(clock, 10)
      temps = temps |> List.replace_at(3, 250.0) |> List.replace_at(4, 20.0)
      assert Runner.get!(runner, "zone_t") == temps
      assert Sim.outputs(card)[[3]] == 1 and Sim.outputs(card)[[4]] == 0
      assert File.read!(Path.join(dir, "forces")) == "zone_t[3] 250.0\n"

      # A zone past a real's range trips the plant; put right, a restart reads the card
      # again, the force still on.
      Sim.set(card, [6], Integer.pow(2, 128))
      assert Runner.status(runner).trip == {:io, "card", {:bad_value, [6], Integer.pow(2, 128)}}
      Sim.set(card, [6], 190.5)
      assert Runner.restart(runner, :cold) == :ok
      Manual.advance(clock, 10)
      temps = List.replace_at(temps, 6, 190.5)
      assert Runner.get!(runner, "zone_t") == temps
      assert Sim.outputs(card)[[3]] == 1 and Sim.outputs(card)[[6]] == 1

      # Killed: a fresh runner from the same file comes back with zone 3 forced.
      Process.flag(:trap_exit, true)
      Process.exit(runner, :kill)
      assert_receive {:EXIT, ^runner, :killed}
      {runner, clock} = oven_runner(plant, dir, card)
      assert %{forces: %{"zone_t[3]" => 250.0}} = Runner.status(runner)
      assert Runner.get!(runner, "zone_t[3]") === 250.0

      # Unforced: the card's last value, 20.
      assert :ok = Runner.unforce(runner, "zone_t[3]")
      Manual.advance(clock, 10)
      assert Runner.get!(runner, "zone_t") == List.replace_at(temps, 3, 20.0)
      assert Sim.outputs(card)[[3]] == 0
      assert File.read!(Path.join(dir, "forces")) == ""
      Runner.stop(runner)
    end
  end

  # PLAN M5-14's Done-when in a plant, from files on disk through
  # `Logex.Configuration.compile_file/1` and `Logex.Runtime.cycle/3`: a sorter of four reject
  # lanes keeps a reject timer for each lane in `lane_t ton[4]`, a gate for each in
  # `gates gate[4]`, an array of a user block loaded from `gate.ld` beside it whose one-shot
  # pulses as its lane's timer is done, and a kick counter for each in `lane_c ctu_int[4]`,
  # each element run by literal subscripts (decision 154); the panel's selector reads the
  # lane it names through a tag subscript, `lane_t[sel].dn` and `lane_c[sel].cv`, and a
  # selector outside the lanes is M5-12's index fault, an event of the cycle. Over seeded
  # eyes and selectors against an oracle that knows nothing of logex: four on-delay timers
  # and four counts of their done edges, restated.
  describe "arrays of instances in the plant (M5-14)" do
    @describetag :tmp_dir

    @gate_ld """
    function_block gate
    var_input  s bool
    var_output q bool
    var e bool
    xic s ons e ote q
    """

    @sorter_ld """
    var_input  eye0 bool
    var_input  eye1 bool
    var_input  eye2 bool
    var_input  eye3 bool
    var_input  sel  dint
    var_output kick0 bool
    var_output kick1 bool
    var_output kick2 bool
    var_output kick3 bool
    var_output lamp  bool
    var_output count int
    var lane_t ton[4]
    var lane_c ctu_int[4]
    var gates  gate[4]
    var p      bool[4]
    xic eye0 ton lane_t[0] 30
    xic eye1 ton lane_t[1] 40
    xic eye2 ton lane_t[2] 50
    xic eye3 ton lane_t[3] 60
    xic lane_t[0].dn ote kick0
    xic lane_t[1].dn ote kick1
    xic lane_t[2].dn ote kick2
    xic lane_t[3].dn ote kick3
    cal gates[0] lane_t[0].dn p[0]
    cal gates[1] lane_t[1].dn p[1]
    cal gates[2] lane_t[2].dn p[2]
    cal gates[3] lane_t[3].dn p[3]
    xic p[0] ctu lane_c[0] 5
    xic p[1] ctu lane_c[1] 5
    xic p[2] ctu lane_c[2] 5
    xic p[3] ctu lane_c[3] 5
    xic lane_t[sel].dn ote lamp
    move lane_c[sel].cv count
    """

    @sorter_logex """
    task fast interval 10 priority 1
    var_global eye0  bool at panel.i.0
    var_global eye1  bool at panel.i.1
    var_global eye2  bool at panel.i.2
    var_global eye3  bool at panel.i.3
    var_global sel   dint at panel.i.4
    var_global kick0 bool at panel.q.0
    var_global kick1 bool at panel.q.1
    var_global kick2 bool at panel.q.2
    var_global kick3 bool at panel.q.3
    var_global lamp  bool at panel.q.4
    var_global count int  at panel.q.5
    program line sorter with fast
    line.eye0  eye0
    line.eye1  eye1
    line.eye2  eye2
    line.eye3  eye3
    line.sel   sel
    line.kick0 kick0
    line.kick1 kick1
    line.kick2 kick2
    line.kick3 kick3
    line.lamp  lamp
    line.count count
    """

    test "M5-14's Done-when: four lanes, each element its own timer, gate and counter, against an oracle",
         %{tmp_dir: dir} do
      File.write!(Path.join(dir, "gate.ld"), @gate_ld)
      File.write!(Path.join(dir, "sorter.ld"), @sorter_ld)
      File.write!(Path.join(dir, "plant.logex"), @sorter_logex)
      {:ok, config} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      assert config.warnings == []
      runtime = Logex.Runtime.start(config)
      :rand.seed(:exsss, {2026, 10, 154})
      presets = [30, 40, 50, 60]

      # The oracle: for each lane, an on-delay timer over its eye, `acc` counting the time
      # since the eye rose and done at its preset, and a count of the done's rising edges;
      # the selector's lane read where it names one, and a fault where it names none.
      lanes = for pre <- presets, do: %{pre: pre, acc: 0, timing: false, done: false, count: 0}
      model = %{lanes: lanes, count: 0, faults: 0, kicks: 0, lit: MapSet.new()}

      {_runtime, model} =
        Enum.reduce(1..600, {runtime, model}, fn _step, {runtime, model} ->
          eyes = for _ <- 1..4, do: Enum.random([0, 1, 1, 1])
          sel = Enum.random([0, 1, 2, 3, 0, 1, 2, 3, 4, -1])
          inputs = Map.new(Enum.with_index(eyes), fn {e, i} -> {"eye#{i}", e} end)

          {runtime, outputs, events} =
            Logex.Runtime.cycle(runtime, 10, Map.put(inputs, "sel", sel))

          lanes =
            for {lane, eye} <- Enum.zip(model.lanes, eyes) do
              acc = lane_timed(eye, lane)

              done = eye == 1 and acc == lane.pre
              rose = done and not lane.done

              %{
                lane
                | acc: acc,
                  timing: eye == 1,
                  done: done,
                  count: lane.count + bit(rose)
              }
            end

          inside = sel in 0..3
          {lamp, count} = lane_picked(inside, lanes, {sel, model.count})

          assert outputs ==
                   Map.merge(
                     Map.new(Enum.with_index(lanes), fn {l, i} -> {"kick#{i}", bit(l.done)} end),
                     %{"lamp" => lamp, "count" => count}
                   )

          faults =
            for {:fault, "fast", "line", fault} <- events, do: {fault.instruction, fault.read}

          assert faults == lane_faults(inside, sel)

          for {lane, i} <- Enum.with_index(lanes) do
            assert Logex.Runtime.get!(runtime, "line.lane_t[#{i}].acc") == lane.acc
            assert Logex.Runtime.get!(runtime, "line.lane_c[#{i}].cv") == lane.count
          end

          {runtime,
           %{
             model
             | lanes: lanes,
               count: count,
               faults: model.faults + length(faults),
               kicks: model.kicks + Enum.count(lanes, & &1.done),
               lit: MapSet.put(model.lit, lamp)
           }}
        end)

      # The walk counted every lane's kicks, lit the lamp and left it dark, and met the
      # index fault.
      assert Enum.all?(model.lanes, &(&1.count > 5))
      assert model.lit == MapSet.new([0, 1])
      assert model.faults > 50
    end
  end

  # PLAN Milestone 5's done sentence in one plant (M5-16's review, question 1's (b)):
  # §4.4's plant from files on disk with a bench program that declares every elementary
  # type, decisions 144, 150 and 155's fifteen, each read from a point of its own type and
  # written to one, an integer through `add` past its width wrapping with no power, a bit
  # string through `not`, a real through `mul` saturating; the fan's speed a `real` from
  # the drive card; the oven's eight zone temperatures a located `real[8]`; and a box
  # counter that is a typed counter, a `ctud_int`, weighing each box into `weights[slot]`,
  # all through `Logex.Runner` on the manual clock against an oracle that knows nothing of
  # logex, every state's real a single or a double and never −0.0. `slot` at 8 trips the
  # plant at the fast task's step with every output 0 once, through every device, and
  # nothing after.
  describe "Milestone 5's done sentence in one plant" do
    @describetag :tmp_dir

    alias Logex.IO.Sim
    alias Logex.Runner
    alias Logex.Runner.Clock.Manual

    # Each type, the range a point of it holds, and what the bench writes from it.
    @integer_types [
      {"sint", -128, 127},
      {"int", -32_768, 32_767},
      {"dint", -2_147_483_648, 2_147_483_647},
      {"lint", -9_223_372_036_854_775_808, 9_223_372_036_854_775_807},
      {"usint", 0, 255},
      {"uint", 0, 65_535},
      {"udint", 0, 4_294_967_295},
      {"ulint", 0, 18_446_744_073_709_551_615}
    ]
    @bit_strings [{"byte", 8}, {"word", 16}, {"dword", 32}, {"lword", 64}]

    defp bench_ld do
      ports =
        for {type, _, _} <- @integer_types do
          "var_input i_#{type} #{type}\nvar_output o_#{type} #{type}\nvar_output ok_#{type} bool\n"
        end ++
          for {type, _} <- @bit_strings do
            "var_input i_#{type} #{type}\nvar_output o_#{type} #{type}\n"
          end ++
          for type <- ["bool", "real", "lreal"] do
            "var_input i_#{type} #{type}\nvar_output o_#{type} #{type}\n"
          end

      rungs =
        for({type, _, _} <- @integer_types, do: "add i_#{type} 1 o_#{type} ote ok_#{type}\n") ++
          for({type, _} <- @bit_strings, do: "not i_#{type} o_#{type}\n") ++
          [
            "xio i_bool ote o_bool\n",
            "mul i_real 2.0 o_real\n",
            "mul i_lreal 2.0 o_lreal\n"
          ]

      Enum.join(ports) <> "// every type in, through its rule, and out\n" <> Enum.join(rungs)
    end

    # The bench's points, each type at an address of its own on the bench device.
    defp bench_types,
      do:
        for({type, _, _} <- @integer_types, do: type) ++
          for({type, _} <- @bit_strings, do: type) ++ ["bool", "real", "lreal"]

    defp bench_lines do
      types = Enum.with_index(bench_types())
      integers = for {type, _, _} <- @integer_types, do: type

      globals =
        for({type, n} <- types, do: "var_global b_i_#{type} #{type} at bench.i.#{n}\n") ++
          for({type, n} <- types, do: "var_global b_o_#{type} #{type} at bench.q.#{n}\n") ++
          for {type, n} <- Enum.with_index(integers, 15),
              do: "var_global b_ok_#{type} bool at bench.q.#{n}\n"

      connections =
        for(
          {type, _} <- types,
          do: "  bench.i_#{type} b_i_#{type}\n  bench.o_#{type} b_o_#{type}\n"
        ) ++
          for type <- integers, do: "  bench.ok_#{type} b_ok_#{type}\n"

      "\n" <>
        Enum.join(globals) <>
        "\nprogram bench bench with fast\n" <> Enum.join(connections)
    end

    @boxes_ld """
    var_input  eye     bool
    var_input  outfeed bool
    var_input  full    bool
    var_input  weight  int
    var_input  slot    int
    var_output count   int
    var_output over    bool
    var_output last    int
    var boxes   ctud_int
    var weights int[8]
    var edge    bool
    var p       bool
    // the box counter, a ctud_int, and each box's weight in the slot the panel names
    xic full ote boxes.ld
    xic eye ctu boxes 32767
    xic outfeed ctd boxes 32767
    move boxes.cv count
    xic boxes.ov ote over
    xic eye ons edge ote p
    xic p move weight weights[slot]
    move weights[slot] last
    """

    @rest_lines """

    var_global fan_hz    real at drive.i.0
    var_global fan_speed real
    var_global fan_rpm   lreal
    var_global fan_limit int  3000
    var_global fan_over  bool at panel.q.7

    program fan1 speed with fast
      fan1.hz    fan_hz
      fan1.limit fan_limit
      fan1.speed fan_speed
      fan1.rpm   fan_rpm
      fan1.over  fan_over

    var_global zone_t   real[8] at card.i.0
    var_global zone_hot bool[8] at card.q.0
    var_global zone_sp  real    180.0
    var_global zone_t0  real

    program oven zones with fast
      oven.t   zone_t
      oven.sp  zone_sp
      oven.hot zone_hot
      oven.t0  zone_t0

    var_global box_eye     bool at panel.i.8
    var_global box_slot    int  at panel.i.9
    var_global box_outfeed bool at panel.i.10
    var_global box_full    bool at panel.i.11
    var_global box_weight  int  at drive.i.4
    var_global box_count   int  at panel.q.4
    var_global box_last    int  at panel.q.5
    var_global box_over    bool at panel.q.6

    program boxes boxes with fast
      boxes.eye     box_eye
      boxes.outfeed box_outfeed
      boxes.full    box_full
      boxes.weight  box_weight
      boxes.slot    box_slot
      boxes.count   box_count
      boxes.last    box_last
      boxes.over    box_over
    """

    # The oracle's rules, restated: an integer wraps by its width, a bit string's `not`
    # flips its bits, a single is the BEAM's 32-bit float nearest a double, a real past
    # its range is its largest value with its sign, and −0.0 is 0.0.
    defp wrapped(x, lo, hi), do: Integer.mod(x - lo, hi - lo + 1) + lo

    # An lreal too small to be normal is held as 0.0.
    defp lreal_flushed(l) when abs(l) < 2.2250738585072014e-308, do: 0.0
    defp lreal_flushed(l), do: l

    # IEC's CTUD restated over an int: a load, then an up edge at its top, then an edge.
    defp box_loaded({1, _rose, _cv}, _ov), do: {32_767, 0}
    defp box_loaded({0, true, 32_767}, _ov), do: {32_767, 1}
    defp box_loaded({0, true, cv}, ov), do: {cv + 1, ov}
    defp box_loaded({0, false, cv}, ov), do: {cv, ov}

    defp box_down(true, cv), do: cv - 1
    defp box_down(false, cv), do: cv

    # A box's weight kept in its slot as the eye rises.
    defp box_weighed(true, weights, {slot, weight}), do: List.replace_at(weights, slot, weight)
    defp box_weighed(false, weights, _box), do: weights

    # A lane's TON restated: timing 10 ms a cycle while its eye is held, from the cycle after
    # it rose; the lane the panel picks lighting the lamp and showing its count, one outside
    # the lanes the index fault of each instruction that reads through it.
    defp lane_timed(1, %{timing: true} = lane), do: min(lane.acc + 10, lane.pre)
    defp lane_timed(1, %{timing: false}), do: 0
    defp lane_timed(0, _lane), do: 0

    defp lane_picked(true, lanes, {sel, _count}) do
      picked = Enum.at(lanes, sel)
      {bit(picked.done), picked.count}
    end

    defp lane_picked(false, _lanes, {_sel, count}), do: {0, count}

    defp lane_faults(true, _sel), do: []
    defp lane_faults(false, sel), do: [{:xic, {sel}}, {:move, {sel}}]
    defp saturated(x, max) when x > max, do: max
    defp saturated(x, max) when x < -max, do: -max
    defp saturated(x, _max), do: x + 0.0

    defp doubled_lreal(x) when x > 8.98846567431158e307, do: 1.7976931348623157e308
    defp doubled_lreal(x) when x < -8.98846567431158e307, do: -1.7976931348623157e308
    defp doubled_lreal(x), do: x * 2.0 + 0.0

    defp drawn({_type, lo, hi}), do: Enum.random([lo, hi, hi - 1, lo + 1, Enum.random(lo..hi)])

    defp drawn_bits(width),
      do: Enum.random([0, Integer.pow(2, width) - 1, Enum.random(0..(Integer.pow(2, width) - 1))])

    defp drawn_real,
      do:
        Enum.random([
          0,
          -0.0,
          1.0e-40,
          3.4028235e38,
          -3.4e38,
          37.5,
          :rand.uniform() * 1000,
          -:rand.uniform(1000)
        ])

    defp drawn_lreal,
      do:
        Enum.random([
          0,
          -0.0,
          1.0e-310,
          1.7e308,
          -1.7e308,
          0.1,
          :rand.uniform() * 1.0e6,
          -:rand.uniform(1000)
        ])

    test "every type, a ctud_int box counter, the fan's real, the oven's real[8] and weights[slot], through the runner",
         %{tmp_dir: dir} do
      files = [
        {"seal.ld", cut("**A function block type** is")},
        {"motor.ld", cut("**The motor, rewritten to use it**")},
        {"snapshot.ld", @snapshot_ld},
        {"bench.ld", bench_ld()},
        {"speed.ld", @speed_ld},
        {"zones.ld", @zones_ld},
        {"boxes.ld", @boxes_ld},
        {"plant.logex", whole_plant() <> bench_lines() <> @rest_lines}
      ]

      for {name, text} <- files, do: File.write!(Path.join(dir, name), text)
      {:ok, plant} = Logex.Configuration.compile_file(Path.join(dir, "plant.logex"))
      assert plant.warnings == []

      # The program and the configuration declare each of the fifteen.
      bench = Map.fetch!(plant.programs, "bench")
      declared = for {_name, tag} <- bench.tags, into: MapSet.new(), do: tag.type
      assert declared == MapSet.new(bench_types(), &String.to_atom/1)

      assert MapSet.new(for g <- plant.globals, String.starts_with?(g.name, "b_i_"), do: g.type) ==
               declared

      {:ok, clock} = Manual.start_link()
      {:ok, panel} = Sim.start_link(reports: true, clock: clock)
      {:ok, drive} = Sim.start_link(clock: clock)
      {:ok, card} = Sim.start_link(reports: true, inputs: 8, outputs: 8)
      {:ok, bench_io} = Sim.start_link(reports: true, inputs: 15, outputs: 23)
      sims = %{"panel" => panel, "drive" => drive, "card" => card, "bench" => bench_io}

      {:ok, runner} =
        Runner.start_link(
          configuration: plant,
          io: Map.new(sims, fn {name, sim} -> {name, {Sim, sim: sim}} end),
          clock: {Manual, clock}
        )

      :rand.seed(:exsss, {2026, 10, 256})
      types = Enum.with_index(bench_types())
      at = Map.new(types)

      model = %{
        weights: List.duplicate(0, 8),
        temps: List.duplicate(0.0, 8),
        eye: 0,
        outfeed: 0,
        cv: 0,
        ov: 0,
        seen: MapSet.new()
      }

      model =
        Enum.reduce(1..300, model, fn _, model ->
          # The bench: each type's point drawn about its limits.
          ints = for {type, _, _} = row <- @integer_types, into: %{}, do: {type, drawn(row)}
          bits = for {type, width} <- @bit_strings, into: %{}, do: {type, drawn_bits(width)}
          bool = Enum.random([0, 1])
          real = drawn_real()
          lreal = drawn_lreal()

          values =
            ints
            |> Map.merge(bits)
            |> Map.merge(%{"bool" => bool, "real" => real, "lreal" => lreal})

          Sim.set(bench_io, Map.new(values, fn {type, v} -> {[at[type]], v} end))

          # The fan, the oven and the box counter.
          hz = Enum.random([:rand.uniform() * 100, :rand.uniform(100), -0.0])
          weight = Enum.random(0..999)

          zones =
            for zone <- Enum.take_random(0..7, Enum.random(1..8)),
                into: %{},
                do: {zone, Enum.random([Enum.random(0..400), :rand.uniform() * 400])}

          eye = Enum.random([0, 0, 1])
          outfeed = Enum.random([0, 0, 0, 1])
          full = Enum.random(List.duplicate(0, 40) ++ [1])
          slot = Enum.random(0..7)
          Sim.set(drive, %{[0] => hz, [4] => weight})
          Sim.set(card, Map.new(zones, fn {zone, t} -> {[zone], t} end))
          Sim.set(panel, %{[8] => eye, [9] => slot, [10] => outfeed, [11] => full})
          Manual.advance(clock, 10)

          out = Sim.outputs(bench_io)

          for {type, lo, hi} <- @integer_types do
            assert out[[at[type]]] == wrapped(ints[type] + 1, lo, hi), type
            assert out[[15 + at[type]]] == bit(ints[type] < hi), type
          end

          for {type, width} <- @bit_strings,
              do: assert(out[[at[type]]] == Integer.pow(2, width) - 1 - bits[type], type)

          assert out[[at["bool"]]] == 1 - bool
          r = single(real * 1.0)
          assert Runner.get!(runner, "b_i_real") === r

          assert Runner.get!(runner, "b_o_real") ===
                   single(saturated(r * 2.0, 3.4028234663852886e38))

          l = lreal * 1.0 + 0.0

          assert Runner.get!(runner, "b_i_lreal") === lreal_flushed(l)

          assert Runner.get!(runner, "b_o_lreal") ===
                   doubled_lreal(Runner.get!(runner, "b_i_lreal"))

          # The fan's speed, in a real and an lreal, its alarm over 3000.
          fan = single(hz * 1.0)
          speed = single(fan * 60.0)
          assert Runner.get!(runner, "fan_hz") === fan
          assert Runner.get!(runner, "fan_speed") === speed
          assert Runner.get!(runner, "fan_rpm") === fan * 60.0 + 0.0
          assert Sim.outputs(panel)[[7]] == bit(speed > 3000)

          # The oven's eight zones, each lamp lit over 180.
          temps =
            Enum.reduce(zones, model.temps, fn {z, t}, ts ->
              List.replace_at(ts, z, one_single(t * 1.0))
            end)

          assert Runner.get!(runner, "zone_t") == temps

          assert for(i <- 0..7, do: Sim.outputs(card)[[i]]) ==
                   for(t <- temps, do: bit(t > 180.0))

          # The box counter, IEC's CTUD restated over an int: a load first, then an up
          # edge, stopping at 32767 with `ov`, then a down edge; each box's weight kept in
          # its slot as the eye rises.
          rose = eye == 1 and model.eye == 0
          fell_in = outfeed == 1 and model.outfeed == 0

          {cv, ov} = box_loaded({full, rose, model.cv}, model.ov)
          cv = box_down(full == 0 and fell_in and cv > -32_768, cv)
          weights = box_weighed(rose, model.weights, {slot, weight})
          assert Runner.get!(runner, "boxes.boxes.cv") == cv
          assert Runner.get!(runner, "boxes.weights") == weights
          assert Sim.outputs(panel)[[4]] == cv
          assert Sim.outputs(panel)[[5]] == Enum.at(weights, slot)
          assert Sim.outputs(panel)[[6]] == ov

          %{
            model
            | weights: weights,
              temps: temps,
              eye: eye,
              outfeed: outfeed,
              cv: cv,
              ov: ov,
              seen:
                MapSet.union(
                  model.seen,
                  MapSet.new([{:ov, ov}, {:wrap, out[[15]]}, {:full, full}])
                )
          }
        end)

      # The walk reached the counter's top and its `ov`, a wrap and a load.
      assert MapSet.subset?(MapSet.new([{:ov, 1}, {:wrap, 0}, {:full, 1}]), model.seen)

      # `slot` at 8: the fast task's step trips on `move weights[slot] last`, and every
      # output of every device is written 0 once, and nothing after.
      Runner.subscribe(runner, [:fault, :trip, :round])
      Sim.set(panel, [9], 8)
      Manual.advance(clock, 10)

      assert {:fault, "fast", "boxes",
              %Logex.Fault{kind: :index_out_of_range, instruction: :move, read: {8}, line: 21} =
                fault} =
               Runner.status(runner).trip

      assert fault.file == Path.join(dir, "boxes.ld")

      zeros =
        for {device, points} <- Logex.IO.points(plant),
            %{direction: :output, address: address} <- points,
            reduce: %{} do
          acc -> Map.update(acc, device, %{address => 0}, &Map.put(&1, address, 0))
        end

      writes = Map.new(sims, fn {name, sim} -> {name, Sim.writes(sim)} end)
      for {name, zero} <- zeros, do: assert(List.last(writes[name]) == zero, name)
      Manual.advance(clock, 1000)
      Sim.set(panel, [9], 3)
      Manual.advance(clock, 1000)
      assert Map.new(sims, fn {name, sim} -> {name, Sim.writes(sim)} end) == writes
      Runner.stop(runner)
    end
  end
end
