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
            {fn -> Logex.compile(@seal, name: "my seal") end,
             ~s("my seal" cannot name a program: a name is a letter or `_`, ) <>
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

    test "a name is checked for shape only: a word reserved in .ld files is a good name" do
      assert {:ok, %Logex.Program{name: "move"}} = Logex.compile(@seal, name: "move")
      assert {:ok, %Logex.Program{name: "_Seal2"}} = Logex.compile(@seal, name: "_Seal2")
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

      assert formatted(Logex.compile_file(clean)) == [
               ~s(#{clean}: "motor-v2" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)"
             ]

      broken = write(dir, "2motor.ld", "var a bool\nxyz a")

      assert formatted(Logex.compile_file(broken)) == [
               ~s(#{broken}: "2motor" cannot name a program: a name is a letter or `_`, ) <>
                 "then letters, digits or `_` (rename the file)",
               "#{broken}: line 2: unknown instruction `xyz`"
             ]
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
