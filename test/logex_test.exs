defmodule LogexTest do
  @moduledoc """
  M1-5: `Logex.compile/2` and `Logex.compile_file/1`, the public way in. A program comes
  out named and stateless, or every mistake comes out as a located diagnostic.
  """
  use ExUnit.Case, async: true

  doctest Logex

  alias Logex.Diagnostic

  @seal "var_input start bool\nvar_input stop bool\nvar_output motor bool\n" <>
          "( xic start | xic motor ) xio stop ote motor\n"

  defp formatted({:error, diagnostics}), do: Enum.map(diagnostics, &Diagnostic.format/1)

  # Each tag has a rung of its own, with a one-shot whose storage bit a second rung also
  # writes, a comparison of two literals, and a timer run by a `ton` whose members are read
  # and written, so every pass over the program, the M1-6 warnings among them, has work to
  # do. A second copy runs each timer with a second `ton`, followed on its path by a
  # contact, two errors, so the one-ton rule's and the path rule's reports are timed too,
  # and runs a timer no line declares, with a tag preset and a contact after it, so the
  # hints that look for a declared twin of it are.
  defp reductions_to_compile(tags) do
    names = for i <- 1..tags, do: "t#{i}"
    declarations = Enum.map(names, &"var #{&1} bool\nvar #{&1}_s bool\nvar #{&1}_t ton")

    rungs =
      Enum.map(
        names,
        &("xic #{&1} ons #{&1}_s eq 1 1 ote #{&1}\nxio #{&1} ote #{&1}_s\n" <>
            "xic #{&1}_t.dn move #{&1}_t.acc #{&1}_t.pre\nxic #{&1} ton #{&1}_t 50")
      )

    source = Enum.join(declarations ++ rungs, "\n")
    tons = Enum.map(names, &"ton #{&1}_t 60 xic #{&1}\nton zz #{&1} xic #{&1}")
    twice = Enum.join(declarations ++ rungs ++ tons, "\n")

    {:reductions, before} = Process.info(self(), :reductions)
    {:ok, _program} = Logex.compile(source, name: "big")
    {:error, _two_tons} = Logex.compile(twice, name: "big")
    {:reductions, later} = Process.info(self(), :reductions)
    later - before
  end

  # One rung nested `depth` groups deep, each with a second leg and a contact after it, and
  # a timer's contact, a comparison of two literals and a one-shot innermost, so every walk
  # of a rung has work at every depth. A second copy has a `ton` innermost, which the
  # contact after every group follows on its path, an error at every depth, and as many
  # declarations after the rung, each told the rung's line, found at its innermost. The
  # least of three counts, since a busy VM can raise one by a few percent.
  defp reductions_to_nest(depth) do
    nest = fn innermost ->
      Enum.reduce(1..depth, innermost, fn _, inner -> "( #{inner} | xic b ) xic a" end)
    end

    declarations = "var a bool\nvar b bool\nvar s bool\nvar t1 ton\n"
    source = declarations <> "xic a ton t1 5\n" <> nest.("xic t1.dn eq 1 1 ons s") <> " ote b"
    late = Enum.map_join(1..depth, &"\nvar z#{&1} bool")
    timed = declarations <> nest.("xic a ton t1 5") <> late

    Enum.min(
      for _ <- 1..3 do
        {:reductions, before} = Process.info(self(), :reductions)
        {:ok, _program} = Logex.compile(source, name: "deep")
        {:error, _after_a_ton} = Logex.compile(timed, name: "deep")
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end
    )
  end

  describe "compile/2" do
    test "names the program, keeps its source, and lowers it as instructionize/2 does" do
      {:ok, tokens, _} = Logex.Compiler.tokenize(@seal)
      {:ok, ast} = Logex.Compiler.parse(tokens)
      {:ok, lowered} = Logex.Compiler.instructionize(ast)

      assert {:ok, program} = Logex.compile(@seal, name: "seal")
      assert %Logex.Program{name: "seal", source: @seal, warnings: []} = program
      assert program.rungs == lowered.rungs
      assert program.tags == lowered.tags
    end

    test "a lex error is the one diagnostic, with its column" do
      result = Logex.compile("var a bool\nxic @a ote a", name: "p")
      assert {:error, [%Diagnostic{stage: :lex, line: 2, column: 5}]} = result
      assert formatted(result) == [~s(line 2, column 5: illegal character "@")]
    end

    test "a parse error is the one diagnostic, with its column" do
      result = Logex.compile("var a bool\nxic a ) ote a", name: "p")
      assert {:error, [%Diagnostic{stage: :parse, line: 2, column: 7}]} = result

      assert formatted(result) == [
               "line 2, column 7: expected a newline or end of input, found `)`"
             ]

      assert formatted(Logex.compile("var a bool\n( xic a ote a", name: "p")) == [
               "line 2, column 1: this `(` is never closed: the input ends before its `)`"
             ]
    end

    test "after the front end, every mistake is reported, stamped :validate" do
      result = Logex.compile("var a bool\nzzz\nxic b ote a", name: "p")

      assert formatted(result) == [
               "line 2: unknown instruction `zzz`",
               "line 3: `b` is not declared"
             ]

      {:error, diagnostics} = result
      assert Enum.all?(diagnostics, &(&1.stage == :validate))
    end

    test "raises ArgumentError when the call breaks its contract, never for the source" do
      for {call, message} <- [
            {fn -> Logex.compile(~c"xic a", name: "p") end,
             ~s(Logex.compile/2 takes source text as a binary, got: ~c"xic a")},
            {fn -> Logex.compile(@seal, name: :seal) end,
             "a program's name is a string, got: :seal"},
            {fn -> Logex.compile(@seal, name: nil) end, "a program's name is a string, got: nil"},
            {fn -> Logex.compile(@seal, name: "my seal") end,
             ~s("my seal" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            # The rule is anchored at the very end: `$` would let a final newline through.
            {fn -> Logex.compile(@seal, name: "seal\n") end,
             ~s("seal\\n" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            {fn -> Logex.compile(@seal, name: "") end,
             ~s("" cannot name a program: a name is a letter or `_`, ) <>
               "then letters, digits or `_`"},
            {fn -> Logex.compile(@seal, []) end,
             "Logex.compile/2 takes a name and no other option, as in " <>
               ~s|Logex.compile(source, name: "motor"), got: []|},
            {fn -> Logex.compile(@seal, name: "p", file: "x") end,
             "Logex.compile/2 takes a name and no other option, as in " <>
               ~s|Logex.compile(source, name: "motor"), got: [name: "p", file: "x"]|}
          ] do
        assert_raise ArgumentError, message, call
      end
    end

    # Counted in reductions rather than time, so the bound holds on any machine. At 500
    # and 2,000 tags a linear compile grows about 4x; a pass that walks every use for
    # every tag, as the warnings first did, grows about 14x.
    test "compiling stays linear in the program's size" do
      ratio = reductions_to_compile(2000) / reductions_to_compile(500)
      assert ratio < 6, "4x the tags took #{Float.round(ratio, 1)}x the reductions"
    end

    # And in its depth. At 500 and 8,000 levels a linear compile grows about 16x. A walk
    # that copies what it found in a group at every level, as the instruction and warning
    # walks first did, grows 20x or more, since `++` is charged few reductions for what it
    # copies; the path pass, which copied its diagnostics so, grew about 140x, and finding
    # the first rung's line again for each declaration after it about 180x.
    test "compiling stays linear in the depth of nesting" do
      ratio = reductions_to_nest(8000) / reductions_to_nest(500)
      assert ratio < 18.5, "16x the depth took #{Float.round(ratio, 1)}x the reductions"
    end

    test "a name is checked for shape only: a word reserved in .ld files is a good name" do
      assert {:ok, %Logex.Program{name: "move"}} = Logex.compile(@seal, name: "move")
      assert {:ok, %Logex.Program{name: "_Seal2"}} = Logex.compile(@seal, name: "_Seal2")
      assert {:ok, %Logex.Program{name: "motor_v2"}} = Logex.compile(@seal, name: "motor_v2")
    end
  end

  describe "compile_file/1" do
    @describetag :tmp_dir

    defp write(dir, file, source) do
      path = Path.join(dir, file)
      File.write!(path, source)
      path
    end

    test "names the program after the file and keeps its source", %{tmp_dir: dir} do
      path = write(dir, "seal.ld", @seal)
      assert {:ok, %Logex.Program{name: "seal", source: @seal}} = Logex.compile_file(path)
    end

    test "gives the done sentence's diagnostic, with the file on every one", %{tmp_dir: dir} do
      path = write(dir, "seal.ld", "var_input a bool\nvar b bool\nxyz a\nxic c ote b")

      assert formatted(Logex.compile_file(path)) == [
               "#{path}: line 3: unknown instruction `xyz`",
               "#{path}: line 4: `c` is not declared"
             ]
    end

    test "a file that cannot be read is a :file diagnostic, not an exception", %{tmp_dir: dir} do
      missing = Path.join(dir, "missing.ld")
      assert {:error, [%Diagnostic{stage: :file, line: nil}]} = Logex.compile_file(missing)

      assert formatted(Logex.compile_file(missing)) == [
               "#{missing}: cannot be read: no such file or directory"
             ]

      assert formatted(Logex.compile_file(dir)) == [
               "#{dir}: cannot be read: illegal operation on a directory"
             ]
    end

    test "a file whose name cannot name a program is a :file diagnostic, and the source is " <>
           "still compiled",
         %{tmp_dir: dir} do
      clean = write(dir, "motor-v2.ld", @seal)

      assert {:error, [%Diagnostic{stage: :file, line: nil, file: ^clean}]} =
               Logex.compile_file(clean)

      assert formatted(Logex.compile_file(clean)) == [
               ~s(#{clean}: "motor-v2" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)"
             ]

      broken = write(dir, "2motor.ld", "var a bool\nxyz a")

      assert {:error,
              [%Diagnostic{stage: :file, line: nil}, %Diagnostic{stage: :validate, line: 2}]} =
               Logex.compile_file(broken)

      assert formatted(Logex.compile_file(broken)) == [
               ~s(#{broken}: "2motor" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)",
               "#{broken}: line 2: unknown instruction `xyz`"
             ]
    end

    test "a refused name gives no warnings: an :error result carries none", %{tmp_dir: dir} do
      path = write(dir, "motor-v2.ld", "var spare bool\nvar a bool\nxic a ote a")

      assert formatted(Logex.compile_file(path)) == [
               ~s(#{path}: "motor-v2" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)"
             ]
    end

    test "stamps the file on every warning too", %{tmp_dir: dir} do
      path = write(dir, "w.ld", "var spare bool\nvar a bool\nxic a ote a")
      assert {:ok, %Logex.Program{warnings: [warning]}} = Logex.compile_file(path)

      assert Diagnostic.format(warning) ==
               "#{path}: line 1: warning: `spare` is declared but no rung uses it"
    end

    test "Milestone 1's done sentence, as written in PLAN.md", %{tmp_dir: dir} do
      # A seal-in circuit written in a .ld file on disk ...
      path = write(dir, "seal.ld", @seal)
      # ... compiled once into a named, stateless value you can hold ...
      assert {:ok, %Logex.Program{name: "seal"} = seal} = Logex.compile_file(path)
      # ... run for N scans as an instance against a typed tag table ...
      steps = [{%{"start" => 1}, 1}, {%{"start" => 0}, 1}, {%{}, 1}, {%{"stop" => 1}, 0}]

      Enum.reduce(steps, Logex.Runtime.instance(seal), fn {inputs, motor}, state ->
        state = Logex.Runtime.put_inputs(seal, state, inputs)
        assert {%{"motor" => ^motor}, state} = Logex.Runtime.scan(seal, state, 10)
        state
      end)

      # ... and report a located diagnostic instead of raising.
      broken = write(dir, "broken.ld", "var_input a bool\nvar b bool\nxyz a\nxic a ote b")

      assert formatted(Logex.compile_file(broken)) == [
               "#{broken}: line 3: unknown instruction `xyz`"
             ]
    end

    # The rule the code has, pinned: the basename less its last extension, whatever it is.
    # No document chooses between that and `.ld` only; if one does, the first line flips.
    test "the name is the basename less its last extension", %{tmp_dir: dir} do
      assert {:ok, %Logex.Program{name: "seal"}} =
               Logex.compile_file(write(dir, "seal.txt", @seal))

      assert {:ok, %Logex.Program{name: "seal"}} = Logex.compile_file(write(dir, "seal", @seal))

      assert {:error, [%Diagnostic{stage: :file, message: ~s("seal.v2" cannot name) <> _}]} =
               Logex.compile_file(write(dir, "seal.v2.ld", @seal))
    end

    test "a file named after a word reserved in .ld files compiles", %{tmp_dir: dir} do
      path = write(dir, "move.ld", @seal)
      assert {:ok, %Logex.Program{name: "move"}} = Logex.compile_file(path)
    end

    test "raises ArgumentError for a path that is not a binary" do
      assert_raise ArgumentError,
                   ~s(Logex.compile_file/1 takes a path as a binary, got: ~c"m.ld"),
                   fn -> Logex.compile_file(~c"m.ld") end
    end
  end
end
