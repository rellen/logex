defmodule Logex.ReviewLowsTest do
  @moduledoc """
  RV-2 (the review after Milestone 6): the report's lows of the compiler, the warnings, the
  walk and the loader that RV-2 fixes, each a test that fails when its fix is reverted,
  named by the reviewer's label. The ones kept, each with its reason, are `PLAN.md`'s RV-2
  entry's.
  """
  use ExUnit.Case, async: true

  alias Logex.{Declarations, Diagnostic, Real}

  defp messages(source, types \\ []) do
    {:error, diagnostics} = Logex.compile(source, name: "m", types: types)
    Enum.map(diagnostics, &Diagnostic.format/1)
  end

  defp warnings(source, types \\ []) do
    {:ok, program} = Logex.compile(source, name: "m", types: types)
    Enum.map(program.warnings, &Diagnostic.format/1)
  end

  # A function's cost in reductions, the least of three, in a process of its own whose heap
  # the collector does not visit.
  defp reductions(fun) do
    parent = self()

    Enum.min(
      for _ <- 1..3 do
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

        assert_receive {:reductions, n}, 60_000
        assert_receive {:DOWN, ^ref, :process, _, :normal}, 60_000
        n
      end
    )
  end

  defp dir! do
    dir = Path.join(System.tmp_dir!(), "logex-rv2-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  describe "Logex.Declarations, total" do
    # Since RV-2's review in pinned words, where it raised FunctionClauseError.
    test "c4-api-fuzz-6: a_or_an/1 of nil raises, where it recursed for ever" do
      task = Task.async(fn -> catch_error(Declarations.a_or_an(nil)) end)

      assert %ArgumentError{
               message:
                 "a_or_an/2 takes a word and the word as shown, each a binary, got: nil and nil"
             } = Task.await(task, 2_000)

      assert_raise ArgumentError,
                   "a_or_an/2 takes a word and the word as shown, each a binary, got: 5 and nil",
                   fn -> Declarations.a_or_an(5) end

      assert_raise ArgumentError,
                   ~s(a_or_an/2 takes a word and the word as shown, each a binary, got: "ton" and :x),
                   fn -> Declarations.a_or_an("ton", :x) end

      assert Declarations.a_or_an("rto") == "an rto"
      assert Declarations.a_or_an("rto", "`rto`") == "an `rto`"
    end

    test "c4-api-fuzz-7: an improper list of tags declared from Elixir is a pinned ArgumentError" do
      {:ok, tokens, _} = Logex.Compiler.tokenize("xic a ote a")
      {:ok, tree} = Logex.Compiler.parse(tokens)
      improper = [Logex.Tag.new!("a", :bool) | :x]

      assert_raise ArgumentError,
                   "declared must be a list of %Logex.Tag{}, got: #{inspect(improper)}",
                   fn -> Logex.Compiler.instructionize(tree, improper) end
    end

    test "a3-compiler2-10: a class of reals alone has no integer range, and holds an integer exactly" do
      assert Declarations.class_range(:any_real) == nil
      assert Declarations.class_range(:any_int) == -(2 ** 63)..(2 ** 64 - 1)//1
      assert Declarations.class_holds?(:any_real, 5)
      assert Declarations.class_holds?(:any_real, 2 ** 53)
      refute Declarations.class_holds?(:any_real, 2 ** 60 + 1)
      assert Declarations.class_holds?(:any_real, 1.5)
      refute Declarations.class_holds?(:any_int, 1.5)
    end
  end

  describe "Logex.Real" do
    # The shortest decimal of a single at a power of two, whose interval is half as wide
    # below it as above, may be the nearest decimal's neighbour above.
    test "a5-data-model-5: spelled/2 gives the shortest text at a power of two, and it is warned of no more" do
      for {double, text} <- [
            {1.262177448353619e-29, "1.2621775e-29"},
            {1.5474250491067253e26, "1.5474251e26"},
            {1.2379400392853803e27, "1.2379401e27"},
            {-1.262177448353619e-29, "-1.2621775e-29"}
          ] do
        assert Real.spelled(:real, Real.nearest(:real, double)) == text
      end

      assert warnings("var_output r real 1.2621775e-29\nvar a bool\nxic a move r r") == []
      assert warnings("var_output r real\nvar a bool\nxic a move 1.2379401e27 r") == []
    end

    test "every single's text reads back to it, over seeded draws" do
      :rand.seed(:exsss, {2026, 11, 5})

      for _ <- 1..20_000 do
        <<f::float-32>> = <<:rand.uniform(0x7F7FFFFF)::32>>
        held = Real.nearest(:real, f)
        {read, ""} = Float.parse(Real.spelled(:real, held))
        assert Real.nearest(:real, read) === held, inspect(held)
      end
    end

    # :erlang.float/1 of an integer of 2^64 or more rounds it twice.
    test "a3-compiler2-8, a5-data-model-4: an integer of 2^64 or more is held at its nearest lreal" do
      assert Real.nearest(:lreal, 2 ** 116 + 2 ** 63 + 1) == (2 ** 116 + 2 ** 64) * 1.0
      assert Real.nearest(:lreal, 2 ** 127 + 2 ** 74 + 1) == 1.7014118346046927e38
      assert Real.nearest(:lreal, -(2 ** 127 + 2 ** 74 + 1)) == -1.7014118346046927e38
      assert Real.nearest(:lreal, 2 ** 53 + 1) == 9_007_199_254_740_992.0
      assert Real.nearest(:lreal, 2 ** 53 + 3) == 9_007_199_254_740_996.0

      assert messages("var a lreal 170141183460469250621153235194464960513") == [
               "line 1: `a` is an lreal: `170141183460469250621153235194464960513` is no value " <>
                 "of an lreal, which holds integers exactly only to 2^53: the nearest it holds " <>
                 "is 170141183460469269510619166673045815296.0"
             ]

      {:ok, p} = Logex.compile("var_input x lreal\nvar_output y lreal\nmove x y", name: "m")

      state =
        Logex.Runtime.put_inputs(p, Logex.Runtime.instance(p), %{"x" => 2 ** 127 + 2 ** 74 + 1})

      assert state.env["x"] == 1.7014118346046927e38
    end
  end

  describe "the compiler's messages" do
    test "a2-compiler1-7: a ctud element's path is told its `.qu`, as a scalar ctud's is" do
      source =
        "var a bool\nvar x bool\nvar c ctud[2]\nxic a ctu c[1] 5 ote x\nxic a ctd c[0] 5\n" <>
          "xic a ctd c[1] 5\nxic a ctu c[0] 5"

      assert messages(source) == [
               "line 4: `ote x` follows `ctu c[1]` on its path: what passes on after a `ctu` is " <>
                 "not settled, so a `ctu` ends its path; read the counter with `xic c[1].qu` on " <>
                 "a rung below"
             ]
    end

    test "a2-compiler1-8: `cal` of a tag of an elementary type names it with its article" do
      for {decl, name, what} <- [
            {"var n int", "n", "an int"},
            {"var n lreal", "n", "an lreal"},
            {"var e int[2]", "e[1]", "an int"},
            {"var n usint", "n", "a usint"}
          ] do
        assert messages("var a bool\n#{decl}\nxic a cal #{name}") == [
                 "line 3: `cal` runs an instance of a function block, but `#{name}` is #{what} " <>
                   "(declared on line 2)"
               ]
      end

      assert messages("var a bool\nvar r rto\nxic a cal r") == [
               "line 3: `cal` runs an instance of a user function block, but `r` is an rto " <>
                 "(declared on line 2), which `rto r` and its preset run"
             ]
    end

    test "a2-compiler1-9: `cal` of a built-in element through a tag subscript is shown it by literal subscripts" do
      assert messages("var a bool\nvar i int\nvar tt ton[2]\nxic a cal tt[i]") == [
               "line 4: `cal` runs an instance of a user function block, but `tt[i]` is a ton " <>
                 "(declared on line 3), which `ton tt[0]` and its preset run, each element by " <>
                 "literal subscripts"
             ]
    end

    test "a3-compiler2-11: a zero divisor is told the zero it gives in its destination's type" do
      for {decl, rung, zero} <- [
            {"var d dint", "div d 0.0 d", "0"},
            {"var d dint", "div d 0 d", "0"},
            {"var r real", "div r 0 r", "0.0"},
            {"var r lreal", "mod r 0.0 r", "0.0"},
            {"var r real", "div r 16#0 r", "0.0"}
          ] do
        [found] =
          messages("#{decl}\nvar o bool\nxic o #{rung}")
          |> Enum.filter(&(&1 =~ "divides by"))

        assert found =~ "a zero divisor gives #{zero} and passes no power", rung
      end
    end

    test "a3-compiler2-9: a real initial value on an integer tag is quoted as written" do
      for {line, found} <- [
            {"var x int 1.5e1", "1.5e1"},
            {"var x int 1_0.0", "1_0.0"},
            {"var x dint 15.0", "15.0"}
          ] do
        assert messages(line) == [
                 "line 1: the initial value of `x` must be an integer, found #{found}"
               ]
      end

      assert messages("var a int[2] 1 2.5e0") == [
               "line 1: the initial value of `a[1]` must be an integer, found 2.5e0"
             ]
    end

    # RV-2's review: its twin in a configuration, whose check/1 judges a global's value,
    # which keeps no spelling. The reader stands each such literal in for a value no other
    # literal of the text holds, as decision 237 stands in `1.0e-400`, and compile/3 puts
    # its text back, so that it is quoted as written; a real global keeps its value.
    test "a3-compiler2-9's twin: a configuration global's real initial value is quoted as written" do
      for {line, messages} <- [
            {"var_global g dint 1.5e1",
             ["`g` is a dint: `1.5e1` is a real, and a dint holds only integers"]},
            {"var_global retain g word 1.0e0",
             ["`g` is a word: `1.0e0` is a real, and a word holds only integers"]},
            {"var_global g bool 1.0e0",
             ["`g` is a bool: `1.0e0` is a real, and a bool holds only 0 or 1"]},
            {"var_global g dint 1.0e-400",
             ["`g` is a dint: `1.0e-400` is a real, and a dint holds only integers"]},
            {"var_global g dint 15.0",
             ["`g` is a dint: `15.0` is a real, and a dint holds only integers"]},
            {"var_global g int[3] 2.5 2.50 2.5e0",
             [
               "the initial value of `g[0]` must be an integer, found 2.5",
               "the initial value of `g[1]` must be an integer, found 2.50",
               "the initial value of `g[2]` must be an integer, found 2.5e0"
             ]}
          ] do
        assert {:error, diagnostics} =
                 Logex.Configuration.compile("c", line <> "\nvar_global r real 1.50\n", %{}),
               line

        assert Enum.map(diagnostics, & &1.message) --
                 ["this configuration declares no `program`: it would run nothing"] == messages,
               line
      end

      {:ok, program} =
        Logex.compile("var_input a real\nvar_output q bool\ngt a 1.0 ote q", name: "m")

      assert {:ok, config} =
               Logex.Configuration.compile(
                 "c",
                 "var_global r real 1.50\nvar_global s lreal[2] 2.5e0 -0.250\n" <>
                   "var_global b bool\nprogram m1 m\n  m1.a r\n  m1.q b\n",
                 %{"m" => program}
               )

      assert Enum.map(config.globals, &{&1.name, &1.initial}) == [
               {"r", 1.5},
               {"s", [2.5, -0.25]},
               {"b", nil}
             ]
    end

    # RV-2's review: decision 227's warning read a `var_global` line's type as its third
    # word, so a qualified line, `var_global retain sp real 16777217.0`, was told nothing.
    test "decision 227's warning is given on a qualified global's line" do
      {:ok, program} =
        Logex.compile("var_input a real\nvar_output q bool\ngt a 1.0 ote q", name: "m")

      for line <- [
            "var_global retain sp real 16777217.0",
            "var_global NON_RETAIN sp real[2] 1.0 16777217.0",
            "var_global sp real 16777217.0"
          ] do
        assert {:ok, config} =
                 Logex.Configuration.compile(
                   "c",
                   line <> "\nvar_global x real\nprogram m1 m\n  m1.a x\n",
                   %{"m" => program}
                 )

        assert [%Diagnostic{line: 1, message: message} | _] = config.warnings

        assert message ==
                 "`16777217.0` is more precise than a real keeps: it is held as 16777216.0",
               line
      end
    end
  end

  describe "the warnings" do
    test "a3-compiler2-7: an initial list's rounded reals are warned of to ten, the rest counted" do
      list = fn n -> Enum.map_join(1..n, " ", fn _ -> "16777217.0" end) end

      one =
        "line 1: warning: `16777217.0` is more precise than a real keeps: it is held as 16777216.0"

      assert warnings("var a real[10] #{list.(10)}\nvar_output o real\nmove a[0] o") ==
               List.duplicate(one, 10)

      assert warnings("var a real[11] #{list.(11)}\nvar_output o real\nmove a[0] o") ==
               List.duplicate(one, 10) ++
                 [
                   "line 1: warning: 1 more literal of this initial list is more precise than " <>
                     "a real keeps, not listed"
                 ]

      assert [_ | _] =
               all = warnings("var a real[4096] #{list.(4096)}\nvar_output o real\nmove a[0] o")

      assert length(all) == 11

      assert List.last(all) ==
               "line 1: warning: 4086 more literals of this initial list are more precise " <>
                 "than a real keeps, not listed"
    end

    test "a4-warnings-walk-4: decision 187's warning on a user block's member, scalar and of an element" do
      {:ok, rb} =
        Logex.compile(
          "function_block rb\nvar_input i usint\nvar_output n usint\nvar_output r real\n" <>
            "move i n\nmove 1.5 r",
          name: "rb"
        )

      head =
        "var_output q bool\nvar s1 rb\nvar gs rb[2]\nvar k usint\nvar i int\nvar nn usint\n" <>
          "var rr real\ncal s1 k nn rr\ncal gs[0] k nn rr\ncal gs[1] k nn rr\nmove k i\n"

      for {rung, said} <- [
            {"ge s1.n 0 otl q",
             "`ge` compares `s1.n` with `0`, and a usint holds nothing below `0`"},
            {"le 0 s1.n otl q",
             "`le` compares `0` with `s1.n`, and a usint holds nothing below `0`"},
            {"ge gs[1].n 0 otl q",
             "`ge` compares `gs[1].n` with `0`, and a usint holds nothing below `0`"},
            {"gt gs[i].n 255 otl q",
             "`gt` compares `gs[i].n` with `255`, and a usint holds nothing above `255`"}
          ] do
        assert warnings(head <> rung, [rb]) == [
                 "line 12: warning: #{said}: its result never changes"
               ],
               rung
      end
    end

    test "a4-warnings-walk-6: decision 219's warning on a real member of an element of user blocks" do
      {:ok, rb} =
        Logex.compile(
          "function_block rb\nvar_input i usint\nvar_output r real\nvar k usint\n" <>
            "move 1.5 r\nmove i k",
          name: "rb"
        )

      source =
        "var_output q bool\nvar gs rb[2]\nvar k usint\nvar rr real\ncal gs[0] k rr\n" <>
          "cal gs[1] k rr\neq gs[1].r 16777217.0 ote q"

      assert warnings(source, [rb]) == [
               "line 7: warning: `16777217.0` is more precise than a real keeps: it is held as " <>
                 "16777216.0"
             ]
    end

    test "a4-warnings-walk-9: a real var_output no rung writes stays at 0.0" do
      assert warnings(
               "var_output r real\nvar_output l lreal 1.5\nvar_output d dint\nvar x real\n" <>
                 "var z lreal\nvar e dint\nmove r x\nmove l z\nmove d e"
             ) == [
               "line 1: warning: `r` is a var_output, but no rung writes it: it stays at 0.0",
               "line 2: warning: `l` is a var_output, but no rung writes it: it stays at 1.5",
               "line 3: warning: `d` is a var_output, but no rung writes it: it stays at 0"
             ]

      # Since RV-2's review each element of an array of reals too, where an array of
      # lreals was told 0; one with an initial list and one of ints are told as before.
      assert warnings(
               "var_output la lreal[2]\nvar_output ra real[2,2]\nvar_output ia int[2]\n" <>
                 "var_output li lreal[2] 1.5 2.5\nvar x lreal\nvar y real\nvar z int\n" <>
                 "var w lreal\nmove la[0] x\nmove ra[0,0] y\nmove ia[1] z\nmove li[1] w"
             ) == [
               "line 1: warning: `la` is a var_output, but no rung writes it: it stays at 0.0",
               "line 2: warning: `ra` is a var_output, but no rung writes it: it stays at 0.0",
               "line 3: warning: `ia` is a var_output, but no rung writes it: it stays at 0",
               "line 4: warning: `li` is a var_output, but no rung writes it: it stays at " <>
                 "its initial values"
             ]
    end

    # One-shots on bool tags beside writes through a tag subscript into an unrelated array:
    # every such write sorted and searched every one-shot, so the warnings were quadratic.
    test "a4-warnings-walk-3: the storage-write warning stays linear in the writes through a tag subscript" do
      source = fn n ->
        "var_input a bool\nvar i int\nvar f bool[8]\nvar_output y bool\n" <>
          Enum.map_join(1..n, "\n", &"var s#{&1} bool") <>
          "\n" <>
          Enum.map_join(1..n, "\n", &"xic a ons s#{&1} ote y") <>
          "\n" <> Enum.map_join(1..n, "\n", fn _ -> "xic a move 0 f[i]" end)
      end

      ratio =
        reductions(fn -> Logex.compile(source.(800), name: "m") end) /
          reductions(fn -> Logex.compile(source.(400), name: "m") end)

      assert ratio < 2.4, "2x the one-shots and writes took #{Float.round(ratio, 2)}x"
    end

    # n arrays of timers, each element run: each array walked every instruction again.
    test "a4-warnings-walk-7: the array-of-instances warning stays linear in the arrays" do
      source = fn n ->
        "var_input a bool\n" <>
          Enum.map_join(1..n, "\n", &"var t#{&1} ton[4]") <>
          "\n" <>
          Enum.map_join(1..n, "\n", fn k ->
            Enum.map_join(0..3, "\n", &"xic a ton t#{k}[#{&1}] 5")
          end)
      end

      ratio =
        reductions(fn -> Logex.compile(source.(600), name: "m") end) /
          reductions(fn -> Logex.compile(source.(300), name: "m") end)

      assert ratio < 2.4, "2x the arrays took #{Float.round(ratio, 2)}x"
    end
  end

  describe "the front end's public stages" do
    test "a1-frontend-7, a6-compile-scale-11: the printer is linear in a rung's depth of nesting" do
      tree = fn n ->
        source = String.duplicate("( ", n) <> "xic a" <> String.duplicate(" )", n) <> " ote b"
        {:ok, tokens, _} = Logex.Compiler.tokenize(source)
        {:ok, tree} = Logex.Compiler.parse(tokens)
        tree
      end

      {deep, deeper} = {tree.(4_000), tree.(8_000)}

      ratio =
        reductions(fn -> Logex.Printer.print(deeper) end) /
          reductions(fn -> Logex.Printer.print(deep) end)

      assert ratio < 2.4, "2x the depth took #{Float.round(ratio, 2)}x"
      assert Logex.Printer.print(tree.(2)) == "( ( xic a ) ) ote b"
    end

    test "a1-frontend-9: tokenize/1, parse/1 and print/1 refuse a host's mistake in pinned words" do
      assert_raise ArgumentError, "tokenize/1 takes a source text, a binary, got: 123", fn ->
        Logex.Compiler.tokenize(123)
      end

      for bad <- [:x, "abc"] do
        assert_raise ArgumentError,
                     "parse/1 takes the list of tokens Logex.Lexer.tokenize/1 gives, got: " <>
                       inspect(bad),
                     fn -> Logex.Compiler.parse(bad) end
      end

      assert_raise ArgumentError,
                   "parse/1 takes the list of tokens Logex.Lexer.tokenize/1 gives, got: :tail",
                   fn -> Logex.Compiler.parse([{:name, {1, 1}, "xic"} | :tail]) end

      assert_raise ArgumentError,
                   "parse/1 takes tokens, each a tuple of its kind and its location, got: :foo",
                   fn -> Logex.Compiler.parse([:foo]) end

      assert_raise ArgumentError,
                   "cannot print :x: not a tree Logex.Parser.parse/1 can produce",
                   fn -> Logex.Printer.print(:x) end

      assert_raise ArgumentError,
                   "cannot print {:int_lit, 1, 1.5}: not a tree Logex.Parser.parse/1 can produce",
                   fn -> Logex.Printer.print({:rung, [{:int_lit, 1, 1.5}]}) end

      # RV-2's review: a routine's rungs that are no proper list, where Enum.map_join/3 raised
      # FunctionClauseError.
      assert_raise ArgumentError,
                   "cannot print :x: not a tree Logex.Parser.parse/1 can produce",
                   fn ->
                     Logex.Printer.print({:routine, {:rungs, [{:rung, [{:name, 1, "a"}]} | :x]}})
                   end

      assert Logex.Printer.print({:routine, {:rungs, [{:rung, [{:name, 1, "a"}]}]}}) == "a"

      # A token the lexer never makes is still an error, not a raise, as yecc answered one.
      assert {:error, {{1, 1}, Logex.Parser, _}} = Logex.Compiler.parse([{:foo, {1, 1}}])
    end

    test "a1-frontend-10: a run stops at a comment, and a control byte is quoted in a string" do
      assert {:error, {{1, 5}, Logex.Lexer, reason}, 1} =
               Logex.Compiler.tokenize("xic a.[n // see ladder.[3] ]")

      assert Logex.Lexer.format_error(reason) =~ ~s("a.[n" is no name)

      assert {:error, {{1, 5}, Logex.Lexer, reason}, 1} =
               Logex.Compiler.tokenize(<<"xic a.[n", 0, "]">>)

      assert Logex.Lexer.format_error(reason) =~ ~s("a.[n\\0]" is no name)
    end
  end

  describe "Logex.FbType and Logex.Diagnostic" do
    test "a5-data-model-9: a block's body read from its own `.ld` file alone is its type" do
      {:ok, seal} =
        Logex.compile("function_block seal\nvar_input x bool\nvar_output y bool\nxic x ote y\n",
          name: "seal"
        )

      at = fn file -> %{seal | body: %{seal.body | file: file}} end
      assert Logex.FbType.user?(at.("/plant/seal.ld"))
      assert Logex.FbType.user?(at.(nil))

      for file <- ["/plant/seal.txt", "/plant/seal.LD", "/plant/SEAL.ld", "/plant/seal"],
          do: refute(Logex.FbType.user?(at.(file)), file)
    end

    test "a5-data-model-10: format/1 of an empty file names none, and an unknown severity is refused" do
      assert Diagnostic.format(%Diagnostic{stage: :file, line: nil, file: "", message: "m"}) ==
               "m"

      assert Diagnostic.format(%Diagnostic{stage: :validate, line: 2, file: "", message: "m"}) ==
               "line 2: m"

      severity = String.to_existing_atom("info")

      assert_raise ArgumentError,
                   "a diagnostic's severity is :error or :warning, got: :info",
                   fn ->
                     # Built at run time, since the type checker refuses it at compile time.
                     Diagnostic.format(
                       struct(Diagnostic,
                         stage: :validate,
                         line: 2,
                         message: "m",
                         severity: severity
                       )
                     )
                   end
    end
  end

  describe "the loader" do
    test "a6-compile-scale-12, a7-docs-8: a program that names its own name as a type is told it is a program" do
      dir = dir!()
      path = Path.join(dir, "selfref.ld")
      File.write!(path, "var_input a bool\nvar x selfref\nxic a ote a\n")

      assert {:error, [%Diagnostic{line: 2, file: ^path, message: message}]} =
               Logex.compile_file(path)

      assert message ==
               "`selfref` is a program (selfref.ld), not a function block: only a function " <>
                 "block's file gives a type for `var`"
    end

    test "a6-compile-scale-12: a path that ends in `/` names a directory" do
      assert {:error, [%Diagnostic{stage: :file, file: "x.ld/", message: message}]} =
               Logex.compile_file("x.ld/")

      assert message ==
               "`x.ld/` names a directory, not a `.ld` file: Logex.compile_file/1 compiles a " <>
                 "program or a function block from its `.ld` file"
    end

    test "a6-compile-scale-12: a FIFO beside a program is no file logex reads, and the load ends" do
      dir = dir!()
      fifo = Path.join(dir, "seal.ld")
      main = Path.join(dir, "main.ld")
      mkfifo = System.find_executable("mkfifo")

      if mkfifo do
        {_, 0} = System.cmd(mkfifo, [fifo])
        File.write!(main, "var_input a bool\nvar_output b bool\nvar s seal\ncal s a b\n")

        task = Task.async(fn -> Logex.compile_file(main) end)
        result = Task.yield(task, 5_000)
        # A load that opens the FIFO through File.read/1 holds the VM's file server in the
        # open, waiting for a writer, so that no test's file call, nor the suite, could end:
        # without the file server, the FIFO is put aside for an empty file, which a later
        # open reads, and a writer lets the waiting open go, before the test fails.
        if result == nil do
          aside = fifo <> ".aside"
          :ok = :prim_file.rename(fifo, aside)
          :ok = :prim_file.write_file(fifo, "")
          {:ok, writer} = :file.open(aside, [:write, :raw])
          :ok = :file.close(writer)
          Task.shutdown(task, :brutal_kill)
        end

        assert {:ok, {:error, [%Diagnostic{file: ^fifo, message: message}]}} = result
        assert message =~ "cannot be read: it is no regular file but a FIFO"
      end
    end

    test "a6-compile-scale-10: a link to nothing or a link that loops is told it cannot be read" do
      dir = dir!()
      main = Path.join(dir, "main.ld")
      File.write!(main, "var_input a bool\nvar_output b bool\nvar s seal\ncal s a b\n")
      seal = Path.join(dir, "seal.ld")

      File.ln_s!(Path.join(dir, "gone.ld"), seal)

      assert {:error,
              [%Diagnostic{file: ^seal, message: "cannot be read: no such file or directory"}]} =
               Logex.compile_file(main)

      File.rm!(seal)
      File.ln_s!(seal, seal)

      assert {:error, [%Diagnostic{file: ^seal, message: "cannot be read: " <> _}]} =
               Logex.compile_file(main)

      # And in a configuration, the program type a `program` line names.
      File.rm!(seal)
      motor = Path.join(dir, "motor.ld")
      File.ln_s!(Path.join(dir, "nowhere.ld"), motor)
      plant = Path.join(dir, "plant.logex")
      File.write!(plant, "task fast interval 10 priority 1\nprogram m1 motor with fast\n")

      assert {:error, diagnostics} = Logex.Configuration.compile_file(plant)
      assert Enum.any?(diagnostics, &(&1.file == motor and &1.message =~ "cannot be read"))
      refute Enum.any?(diagnostics, &(&1.message =~ "did you mean `motor`"))
    end

    test "a6-compile-scale-14: one block reached by two spellings of its path is compiled once" do
      dir = dir!()
      File.mkdir_p!(Path.join(dir, "sub"))

      File.write!(
        Path.join(dir, "seal.ld"),
        "function_block seal\nvar_input x bool\nvar_output y bool\nvar unused bool\nxic x ote y\n"
      )

      program = "var_input a bool\nvar_output b bool\nvar s seal\ncal s a b\n"
      File.write!(Path.join(dir, "p1.ld"), program)
      File.write!(Path.join(dir, "p2.ld"), program)

      [{:ok, p1}, {:ok, p2}] =
        Logex.compile_files([Path.join(dir, "p1.ld"), Path.join([dir, "sub", "..", "p2.ld"])])

      unused = &Enum.count(&1.warnings, fn w -> w.message =~ "`unused` is declared" end)
      assert {unused.(p1), unused.(p2)} == {1, 0}

      # And compiled once: a block of 400 rungs reached by two spellings costs what it does
      # by one, where it was compiled again.
      File.write!(
        Path.join(dir, "big.ld"),
        "function_block big\nvar_input x bool\nvar_output y bool\n" <>
          Enum.map_join(1..400, "\n", fn _ -> "xic x ote y" end) <> "\n"
      )

      program = "var_input a bool\nvar_output b bool\nvar s big\ncal s a b\n"
      File.write!(Path.join(dir, "q1.ld"), program)
      File.write!(Path.join(dir, "q2.ld"), program)
      alike = [Path.join(dir, "q1.ld"), Path.join(dir, "q2.ld")]
      spelled = [Path.join(dir, "q1.ld"), Path.join([dir, "sub", "..", "q2.ld"])]

      ratio =
        reductions(fn -> Logex.compile_files(spelled) end) /
          reductions(fn -> Logex.compile_files(alike) end)

      assert ratio < 1.2, "a second spelling cost #{Float.round(ratio, 2)}x"
    end

    # A block saved again between the loader's look at its kind and its compile was read as
    # a program by the second and raised.
    test "a6-compile-scale-2: a block's file swapped for a program's during a load is told it is a program" do
      dir = dir!()
      main = Path.join(dir, "main.ld")
      seal = Path.join(dir, "seal.ld")
      File.write!(main, "var_input a bool\nvar_output b bool\nvar s seal\ncal s a b\n")
      block = "function_block seal\nvar_input x bool\nvar_output y bool\nxic x ote y\n"
      program = "var_input x bool\nvar_output y bool\nxic x ote y\n"
      File.write!(seal, block)

      # The swaps are made raw, off the VM's file server, which serves every other file call
      # of the VM one at a time (RV-7's review): through it the loop kept a write or a
      # rename queued there at every moment, so that every other call waited behind one,
      # and under the busy loops beside a full suite this test's 300 loads, and
      # `configuration_test.exs`'s loader's beside it, ran past ExUnit's 60 s, where alone
      # under the loops they took 2 s and 0.5 s.
      swapper =
        spawn_link(fn ->
          Stream.cycle([block, program])
          |> Enum.each(fn text ->
            :ok = :file.write_file(seal <> ".new", text, [:raw])
            :ok = :prim_file.rename(seal <> ".new", seal)
          end)
        end)

      results = for _ <- 1..300, do: Logex.compile_file(main)
      Process.unlink(swapper)
      Process.exit(swapper, :kill)

      for result <- results do
        assert match?({:ok, _}, result) or match?({:error, [%Diagnostic{} | _]}, result)
      end
    end
  end
end
