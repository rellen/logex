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

  defp run(src, env) do
    {:ok, program} = compile(src)
    env_after(program, env)
  end

  defp compile(src), do: Logex.compile(src, name: "t")

  # One scan through the public API, from an env the test chooses: an instance built by
  # hand, which Logex.Runtime runs without checking its values (outside its contract).
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
      # that looks like it works and does not.
      assert lex_error?("ote a[3]")
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

  # One scan, not the first, at 7 ms, from an env the test builds by hand.
  defp later_scan(program, env) do
    state = %Logex.Instance{type: program.name, env: env, now: 0, first: false}
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

    test "a storage bit holding anything is read as a contact reads it" do
      p = program(@ons)

      for {junk, fires} <- [{0, 1}, {nil, 1}, {false, 1}, {0.0, 1}, {5, 0}, {"x", 0}, {true, 0}] do
        assert {%{"pulse" => ^fires}, %{"s1" => 1}} = later_scan(p, %{"s1" => junk, "go" => 1}),
               inspect(junk)
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

    test "on an env the host builds, they never raise, and each pair is complementary" do
      src =
        "var a dint\nvar b dint\nvar eq_ bool\nvar ne_ bool\nvar lt_ bool\nvar ge_ bool\n" <>
          "var gt_ bool\nvar le_ bool\neq a b ote eq_\nne a b ote ne_\nlt a b ote lt_\n" <>
          "ge a b ote ge_\ngt a b ote gt_\nle a b ote le_"

      p = program(src)
      values = [0, 1, -1, 1.0, 2.5, nil, true, :on, "0", [], %{}, {1}, :missing]

      for a <- values, b <- values do
        env = for({k, v} <- [{"a", a}, {"b", b}], v != :missing, into: %{}, do: {k, v})
        {_, env} = later_scan(p, env)
        pairs = [{"eq_", "ne_"}, {"lt_", "ge_"}, {"gt_", "le_"}]
        assert Enum.all?(pairs, fn {x, y} -> env[x] + env[y] == 1 end), inspect({a, b})
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

    test "a restart under a recompile of the same name starts again a var_input whose type " <>
           "it changed" do
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

      # `go` still fits, and is kept as the input image is; `x` and `t1` no longer do.
      restarted = Logex.Runtime.restart(v2, state, :cold)
      assert restarted.env == %{"go" => 1, "x" => 0, "t1" => 0, "y" => 0}
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
      go = fn now -> if now >= 1000, do: 1, else: 0 end
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
            5,
            nil,
            "x",
            [1],
            %{},
            %{"pre" => "q", "acc" => :a, "last" => "z", "en" => 1},
            %{"dn" => nil, "acc" => 2.5, "pre" => 1.0},
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
    end

    test "a `last` that is not an integer adds nothing" do
      # A .pre with room above .acc, so the cap cannot hide what was added.
      for last <- ["z", nil, 1.5] do
        timer = %{"pre" => 50, "acc" => 5, "en" => 1, "last" => last}

        assert {_, %{"t1" => %{"acc" => 5, "last" => 7}}} =
                 later_scan(program(@ton), %{"t1" => timer, "go" => 1}),
               inspect(last)
      end
    end

    test "a `last` later than now, or .en read as a contact reads it" do
      p = program(@ton)
      timer = %{"pre" => 50, "acc" => 5, "dn" => 0, "tt" => 1, "last" => 1000}

      assert {_, %{"t1" => %{"acc" => 5, "last" => 7}}} =
               later_scan(p, %{"t1" => Map.put(timer, "en", 1), "go" => 1})

      for {en, acc} <- [{1, 7}, {true, 7}, {5, 7}, {0, 5}, {nil, 5}, {false, 5}] do
        from_zero = %{timer | "last" => 5}

        assert {_, %{"t1" => %{"acc" => ^acc}}} =
                 later_scan(p, %{"t1" => Map.put(from_zero, "en", en), "go" => 1}),
               inspect(en)
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
    # Outside the contract, like M1-4's contacts, but still total: whatever a hand-built
    # env holds where a timer belongs, or in its members, nothing raises.
    @junk [5, nil, "x", [1], %{}, %{"dn" => nil, "acc" => 2.5}, %Logex.Scan{now: 0, first: true}]

    test "a contact on a member is total, and xic and xio stay complementary" do
      p = program("var t1 ton\nvar hi bool\nvar lo bool\nxic t1.dn ote hi\nxio t1.dn ote lo")

      for junk <- @junk ++ [%{"dn" => 1}, %{"dn" => true}, %{"dn" => 0}] do
        {_, env} = later_scan(p, %{"t1" => junk})
        assert env["hi"] + env["lo"] == 1, inspect(junk)
      end

      assert {_, %{"hi" => 1}} = later_scan(p, %{"t1" => %{"dn" => 1}})
    end

    test "move from a member the host left out, or of a timer that is not a map, copies 0" do
      p = program("var t1 ton\nvar d dint\nmove t1.acc d")

      for junk <- @junk -- [%{"dn" => nil, "acc" => 2.5}] do
        assert {_, %{"d" => 0}} = later_scan(p, %{"t1" => junk, "d" => 9}), inspect(junk)
      end
    end

    test "a write into a timer that is not a map makes one" do
      p = program("var t1 ton\nmove 3 t1.pre")

      for junk <- [5, nil, "x", [1]] do
        assert {_, %{"t1" => %{"pre" => 3}}} = later_scan(p, %{"t1" => junk}), inspect(junk)
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

    test "xic and xio are complementary for every value: a number by value, a boolean as " <>
           "itself, anything else closed" do
      for {env, closed} <- [
            {%{"t" => 0}, 0},
            {%{"t" => 1}, 1},
            {%{"t" => 5}, 1},
            {%{"t" => -3}, 1},
            {%{"t" => 0.0}, 0},
            {%{"t" => -0.0}, 0},
            {%{"t" => 2.5}, 1},
            {%{"t" => false}, 0},
            {%{"t" => true}, 1},
            {%{"t" => nil}, 0},
            {%{}, 0},
            {%{"t" => :on}, 1},
            {%{"t" => "0"}, 1}
          ] do
        assert %{"hi" => ^closed, "lo" => lo} = run(@contacts, env)
        assert lo == 1 - closed, "xio must be the complement of xic for #{inspect(env)}"
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

      # No text says `move -900 speed_sp` until a negative literal lexes (PLAN.md §5), so
      # the tree that would is a host mistake. Matched by its rule: the rest of the message
      # prints the node, a shape of the tree.
      error =
        assert_raise ArgumentError, fn ->
          Logex.Compiler.instructionize(replace(tree, 900, -900), [t2])
        end

      assert "not a tree Logex.Parser.parse/1 can produce: a literal is an integer, 0 or " <>
               "more: a negative one does not lex yet (PLAN.md §5), got: " <> _node =
               error.message

      # Nor does a declaration line give a timer its preset, or a tag a negative value.
      assert_raise ArgumentError,
                   "`t2` is a ton: its preset is the number on its `ton` instruction, as in " <>
                     "`ton t2 5000`, not an initial value on its declaration",
                   fn -> Logex.Tag.new!("t2", Logex.FbType.ton(), :var, %{"pre" => 2000}) end

      assert_raise ArgumentError,
                   "`speed_sp` is a dint: its initial value `-1` is negative, which no " <>
                     "declaration line can say until a negative literal lexes",
                   fn -> Logex.Tag.new!("speed_sp", :dint, :var_output, -1) end
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
    defp x_at(now), do: if(rem(div(now, 10), 7) in [3, 4], do: 1, else: 0)

    test "M2-1's Done-when: a 10 ms task, a 30 ms task and a task-less instance, cycled " <>
           "every 10 ms from 0 to 990 ms, each run as often as its task dictates, in " <>
           "priority order" do
      times = Enum.to_list(0..990//10)
      steps = Enum.map(times, &{if(&1 == 0, do: 0, else: 10), %{"x" => x_at(&1)}})
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
        assert order == if(rem(now, 30) == 0, do: ~w(s f n), else: ~w(f n)), "at #{now} ms"
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

      # As for any unknown type since M1-3, the line declares nothing, so s3's use is
      # reported too, until a commit after M2-5 excuses it.
      assert formatted.(Logex.compile_file(unknown)) == [
               "#{unknown}: line 12: unknown type `sael`: logex has `bool`, `dint` and `ton`, " <>
                 "and the function block `seal` — did you mean `seal`?",
               "#{unknown}: line 16: `s3` is not declared"
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
               "line 1: unknown type `sael`: logex has `bool`, `dint` and `ton`, " <>
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
end
