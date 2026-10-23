defmodule Logex.ArrayConfigurationTest do
  @moduledoc """
  PLAN M5-11 in a configuration (`docs/organisation.md` §4.12, "Arrays", decisions 151,
  157 and 159): an unlocated array global from a configuration file's line and from
  Elixir, its sizes and initial list judged as a declaration's, printed back exactly; a
  located one refused, which is M5-13's; a `var_external` array bound only to a global
  array of exactly its element type and every dimension's size; a connection naming an
  array var_input or var_output whole, to a global array of its sizes whose elements
  widen, or an element by literal subscripts, `m1.temps[3]`; a cycle copying each in and
  out; `get/2` naming an array whole, given as a host is given one, a list, and an element,
  `m1.temps[3]` or `temps[3]`; a runtime the host built whose array global does not fit
  refused; and an online edit reporting a changed initial list element by element and
  refusing a size changed.
  """
  use ExUnit.Case, async: true

  alias Logex.{Configuration, Runtime}
  alias Logex.Configuration.{Connection, Global, Instance}

  @program """
  var_input w int[3]
  var_input e int[2]
  var_output s dint
  var_output o dint[2,2]
  var_external g real[2,2]
  move w[1] s
  move e[1] o[1,1]
  move w[2] g[1,0]
  """

  @configuration """
  var_global ws int[3] 1 2 3
  var_global g real[2,2]
  var_global s dint
  var_global os dint[2,2]
  var_global x int 7
  program m1 m
  m1.w ws
  m1.s s
  m1.e[0] 4
  m1.e[1] x
  m1.o os
  """

  defp program do
    {:ok, program} = Logex.compile(@program, name: "m")
    program
  end

  defp compiled(text), do: Configuration.compile("c", text, %{"m" => program()})

  defp refused(text) do
    {:error, diagnostics} = compiled(text)
    Enum.map(diagnostics, & &1.message)
  end

  defp started(text \\ @configuration) do
    {:ok, configuration} = compiled(text)
    Runtime.start(configuration)
  end

  defp cycled(runtime, inputs \\ %{}) do
    {runtime, _outputs, events} = Runtime.cycle(runtime, 10, inputs)
    {runtime, events}
  end

  describe "a global array" do
    test "is read from its line, an initial list in the elements' order, and printed back exactly" do
      text = """
      var_global ws int[3] 1 2 3
      var_global gs real[2,2] 0.1 2 3 4
      var_global g real[2,2]
      var_global s dint
      var_global os dint[2,2]
      var_global x int 7
      program m1 m
      m1.w ws
      m1.s s
      m1.e[0] 4
      m1.e[1] x
      m1.o os
      """

      {:ok, configuration} = compiled(text)

      assert [
               %Global{name: "ws", type: {:array, :int, [3]}, initial: [1, 2, 3]},
               %Global{name: "gs", type: {:array, :real, [2, 2]}, initial: [gs0, 2, 3, 4]},
               %Global{name: "g", type: {:array, :real, [2, 2]}, initial: nil} | _
             ] = configuration.globals

      # 0.1 is held as a single's nearest, as a real global's own value is (decision 150).
      <<single::float-32>> = <<0.1::float-32>>
      assert gs0 == single
      assert Configuration.Text.print(configuration) == text

      assert Configuration.compile("c", Configuration.Text.print(configuration), %{
               "m" => program()
             }) == {:ok, configuration}

      # Each element at its type's zero, or its initial list's value, a tuple as a state holds.
      runtime = Runtime.start(configuration)
      assert Runtime.get!(runtime, "ws") == [1, 2, 3]
      assert Runtime.get!(runtime, "gs") == [[gs0, 2.0], [3.0, 4.0]]
      assert Runtime.get!(runtime, "g") == [[0.0, 0.0], [0.0, 0.0]]
      assert Configuration.initial(Enum.at(configuration.globals, 0)) == {1, 2, 3}
      assert Configuration.initial(Enum.at(configuration.globals, 4)) == {{0, 0}, {0, 0}}
    end

    test "meets every rule a declared array meets, at its line, and is not located yet" do
      tail =
        "var_global ws int[3]\nvar_global s dint\nvar_global g real[2,2]\nprogram m1 m\nm1.w ws\nm1.s s\nm1.e[0] 1\nm1.e[1] 2\n"

      assert refused("var_global w int[0]\n" <> tail) == [
               "`w` is declared with a dimension of 0, `[0]`: each dimension of an array holds 1 element or more"
             ]

      assert refused("var_global w int[2,2,2,2]\n" <> tail) == [
               "`w` is declared with 4 dimensions, `[2,2,2,2]`: an array has one to three, as in `int[8]`, `int[4,8]` or `int[2,3,4]`"
             ]

      assert refused("var_global w int[300,300]\n" <> tail) == [
               "`w` would hold 90000 elements, `[300,300]`: an array holds 65536 at most"
             ]

      assert refused("var_global w int[3] 1 2\n" <> tail) == [
               "`w` is an array of 3 ints: its initial list holds 2 values, and an array's holds one for every element, 3, in the elements' order"
             ]

      assert refused("var_global w int[2] 1 70000\n" <> tail) == [
               "`w[1]` is an int: `70000` is outside -32768 to 32767"
             ]

      assert refused("var_global w int[3] at panel.i.0\n" <> tail) == [
               "`w` is an array at `panel.i.0`: an array global is not located yet, so declare it with no `at`, or a global at each point"
             ]

      assert refused("var_global w[2] int\n" <> tail) == [
               "`w[2]` cannot name a global: brackets are kept for an element's subscripts, as in `m1.temps[3]`"
             ]

      for word <- ["ton[2]", "int[n]"] do
        assert refused("var_global w #{word}\n" <> tail) == [
                 "unknown type `#{word}`: a global array's type is `bool`, `sint`, `int`, `dint`, `lint`, `usint`, `uint`, `udint`, `ulint`, `real`, `lreal`, `byte`, `word`, `dword` or `lword` with its sizes, literal numbers, as in `var_global w int[8]`"
               ]
      end
    end

    test "from Elixir, its type and initial list are the host's to give in shape, a line each" do
      message =
        assert_raise ArgumentError, fn ->
          Configuration.new!(
            name: "c",
            programs: [program()],
            globals: [
              %Global{name: "a", type: {:array, :float, [2]}},
              %Global{name: "b", type: {:array, :int, []}},
              %Global{name: "c", type: {:array, :int, [2.0]}},
              %Global{name: "d", type: {:array, :int, [2]}, initial: 5},
              %Global{name: "e", type: {:array, :int, [2]}, initial: [1, 2.5]},
              %Global{name: "f", type: {:array, :real, [2]}, initial: [1, :x]}
            ]
          )
        end

      sizes =
        ", or an array of one of them, as in `{:array, :int, [8]}`, its sizes a list of one integer a dimension"

      every =
        ":bool, :sint, :int, :dint, :lint, :usint, :uint, :udint, :ulint, :real, :lreal, :byte, :word, :dword or :lword"

      for line <- [
            "global `a` has type {:array, :float, [2]}: a global is #{every}#{sizes}",
            "global `b` has type {:array, :int, []}: a global is #{every}#{sizes}",
            "global `c` has type {:array, :int, [2.0]}: a global is #{every}#{sizes}",
            "the initial value of global `d`, an array, must be a list of its elements' values, found 5",
            "the initial value of global `e`, an array of ints, must be a list of its elements' values, each an integer, found [1, 2.5]",
            "the initial value of global `f`, an array of reals, must be a list of its elements' values, each a number, found [1, :x]"
          ] do
        assert message.message =~ line
      end

      # And what a line could say is a diagnostic from Elixir too, in the file's words.
      assert [diagnostic | _] =
               Configuration.check(%Configuration{
                 name: "c",
                 programs: %{},
                 globals: [%Global{name: "w", type: {:array, :int, [3]}, initial: [1]}]
               })

      assert diagnostic.message ==
               "`w` is an array of 3 ints: its initial list holds 1 value, and an array's holds one for every element, 3, in the elements' order"

      assert_raise ArgumentError,
                   "expected an initial list of 3 values for an array of 3 ints, got: [1]",
                   fn ->
                     Configuration.initial(%Global{
                       name: "w",
                       type: {:array, :int, [3]},
                       initial: [1]
                     })
                   end
    end

    test "an entry a line cannot say is refused by entries!/1" do
      for global <- [
            %Global{name: "w", type: {:array, :int, []}},
            %Global{name: "w", type: {:array, :int, [2.0]}},
            %Global{name: "w", type: {:array, :int, [2 | 3]}},
            %Global{name: "w", type: {:array, :int, [2]}, initial: []},
            %Global{name: "w", type: {:array, :int, [2]}, initial: 3},
            %Global{name: "w", type: {:array, :int, [2]}, initial: [1, 2.5]}
          ] do
        assert_raise ArgumentError, ~r/^not an entry a configuration file can say: /, fn ->
          Configuration.Text.entries!([global])
        end
      end

      assert Configuration.Text.entries!([
               %Global{name: "w", type: {:array, :real, [2]}, initial: [1, 0.5]}
             ]) != []
    end
  end

  describe "a var_external array (decision 159)" do
    test "binds to a global array of exactly its element type and every dimension's size" do
      for global <- [
            "var_global g real[2,3]",
            "var_global g real[4]",
            "var_global g lreal[2,2]",
            "var_global g real"
          ] do
        text = String.replace(@configuration, "var_global g real[2,2]", global)
        [message] = refused(text)

        shown =
          %{
            "var_global g real[2,3]" => "an array of 2 by 3 reals",
            "var_global g real[4]" => "an array of 4 reals",
            "var_global g lreal[2,2]" => "an array of 2 by 2 lreals",
            "var_global g real" => "a real"
          }[global]

        assert message ==
                 "`m` declares `var_external g real[2,2]` on its line 5, but `g` is #{shown} (line 2): a var_external is its global, so it is an array of exactly the global's type and sizes, every dimension included"
      end

      assert refused(String.replace(@configuration, "var_global g real[2,2]\n", "")) == [
               "`m` declares `var_external g real[2,2]` on its line 5, but there is no global `g`: declare it, as in `var_global g real[2,2]`"
             ]
    end

    test "is the global itself, written by the scan and read through it" do
      {runtime, _events} = cycled(started())
      assert Runtime.get!(runtime, "g") == [[0.0, 0.0], [3.0, 0.0]]
      assert Runtime.get!(runtime, "m1.g") == [[0.0, 0.0], [3.0, 0.0]]
      assert Runtime.get!(runtime, "m1.g[1,0]") == 3.0
    end
  end

  describe "a connection" do
    test "copies an array whole and each element in and out, every cycle" do
      runtime = started()
      {runtime, [{:ran, :none, "m1", 10}]} = cycled(runtime)

      # `s` is `w[1]`, from `ws`; `o[1,1]` is `e[1]`, from `x`, 7.
      assert Runtime.get!(runtime, "s") == 2
      assert Runtime.get!(runtime, "os") == [[0, 0], [0, 7]]
      assert Runtime.get!(runtime, "m1.e") == [4, 7]
      assert Runtime.get!(runtime, "m1.w") == [1, 2, 3]
    end

    test "widens an array's elements as a value's, and an element as a tag's" do
      {:ok, widen} =
        Logex.compile(
          "var_input w real[2]\nvar_input r real[1]\nvar_output o int[2]\nmove 5 o[1]",
          name: "m"
        )

      text = """
      var_global ws int[2] 3 -4
      var_global os real[2]
      var_global lo lint
      var_global ro real
      var_global k int 9
      program m1 m
      m1.w ws
      m1.o os
      m1.o[1] lo
      m1.o[0] ro
      m1.r[0] k
      """

      {:ok, configuration} = Configuration.compile("c", text, %{"m" => widen})
      {runtime, _outputs, _events} = Runtime.cycle(Runtime.start(configuration), 10, %{})
      # Compared exactly, since `0 == 0.0`: a real holds a float, never an integer.
      assert Runtime.get!(runtime, "m1.w") === [3.0, -4.0]
      assert Runtime.get!(runtime, "m1.r") === [9.0]
      assert Runtime.get!(runtime, "os") === [0.0, 5.0]
      assert Runtime.get!(runtime, "ro") === 0.0
      assert Runtime.get!(runtime, "lo") === 5

      # So the next cycle's check of the globals finds each a real's value.
      {runtime, _outputs, _events} = Runtime.cycle(runtime, 10, %{})
      assert Runtime.get!(runtime, "os") === [0.0, 5.0]

      # And an array of 2 dints does not widen into an array of 2 ints, nor an int array
      # into an sint one, nor an array of 2 into one of 3.
      {:ok, narrow} =
        Logex.compile("var_input w int[2]\nvar_output o int[2]\nvar_input n int[3]", name: "m")

      text = """
      var_global ws dint[2]
      var_global os sint[2]
      var_global three int[2]
      program m1 m
      m1.w ws
      m1.o os
      m1.n three
      """

      {:error, diagnostics} = Configuration.compile("c", text, %{"m" => narrow})

      assert Enum.map(diagnostics, & &1.message) == [
               "`m1.w` is an array of 2 ints, but `ws` is an array of 2 dints (line 1)",
               "`m1.o` is an array of 2 ints, but `os` is an array of 2 sints (line 2)",
               "`m1.n` is an array of 3 ints, but `three` is an array of 2 ints (line 3)"
             ]
    end

    test "names an element by literal subscripts in its dimensions, every refusal at its line" do
      for {line, message} <- [
            {"m1.w 5",
             "`m1.w` is already connected, to `ws` (line 7): a var_input has one source"},
            {"m1.w[0] 5",
             "`m1.w[0]` is already connected, by `m1.w` to `ws` (line 7): a var_input has one source, an array whole or each of its elements"},
            {"m1.e ws",
             "`m1.e` is already connected, by `m1.e[0]` to `4` (line 9): a var_input has one source, an array whole or each of its elements"},
            {"m1.e[1] 3",
             "`m1.e[1]` is already connected, to `x` (line 10): a var_input has one source"},
            {"m1.w[5] 1",
             "`m1.w[5]`'s subscript `5` is outside 0 to 2: `w` is an array of 3 ints"},
            {"m1.w[-1] 1",
             "`m1.w[-1]`'s subscript `-1` is outside 0 to 2: `w` is an array of 3 ints"},
            {"m1.w[a] 1",
             "`m1.w[a]`'s subscript `a` is a tag's name: a connection names an element by literal subscripts, as in `m1.w[0]`"},
            {"m1.w[1,1] 3",
             "`m1.w[1,1]` names an element of `w`, an array of 3 ints, by 2 subscripts, where it takes 1, one a dimension"},
            {"m1.s[1] 1",
             "`m1.s[1]` names an element of `s`, but `s` is a dint on its line 3, no array"},
            {"m1.q[1] 1", "`m` declares no `q`"},
            {"m1.o[0,0] x",
             "`m1.o[0,0]` is a dint, but `x` is an int (line 5): a dint does not widen into an int, and a connection converts nothing: convert it inside the program, with `dint_to_int`"}
          ] do
        assert refused(@configuration <> line <> "\n") == [message], line
      end

      # A subscript is read by its value, as a program's is, so `m1.e[01]` is `m1.e[1]`.
      assert refused(@configuration <> "m1.e[01] 3\n") == [
               "`m1.e[01]` is already connected, to `x` (line 10): a var_input has one source"
             ]
    end

    test "a constant fills an element, never an array whole" do
      text = String.replace(@configuration, "m1.w ws", "m1.w 5")

      assert refused(text) == [
               "`m1.w` is an array of 3 ints, and the constant `5` is one value: connect it to a global array of its sizes, or each element to a constant, as in `m1.w[0] 5`"
             ]
    end

    test "an array var_input is connected whole, or at every element" do
      assert refused(String.replace(@configuration, "m1.e[1] x\n", "")) == [
               "`m1` leaves its var_input `e[1]` unconnected: connect it to a global, a point or a constant, as in `m1.e[1] 0`"
             ]

      assert refused(String.replace(@configuration, "m1.e[0] 4\nm1.e[1] x\n", "")) == [
               "`m1` leaves its var_input `e` unconnected: connect it to a global, a point or a constant, as in `m1.e 0`"
             ]
    end
  end

  describe "an access path" do
    test "names an array whole, as a list, and an element, each refusal its reason" do
      {runtime, _events} = cycled(started())

      assert Runtime.get(runtime, "ws[2]") == {:ok, 3}
      assert Runtime.get(runtime, "os[1,1]") == {:ok, 7}
      assert Runtime.get(runtime, "m1.o[1,1]") == {:ok, 7}
      assert Runtime.get(runtime, "m1.w[0x]") |> elem(0) == :error

      for {path, reason} <- [
            {"ws[3]",
             "`ws[3]`'s subscript `3` is outside 0 to 2: `ws` is a global array of 3 ints"},
            {"ws[n]",
             "`ws[n]`'s subscript `n` is a tag's name: an access path names an element by literal subscripts, as in `ws[0]`"},
            {"os[1]",
             "`os[1]` names an element of `os`, a global array of 2 by 2 dints, by 1 subscript, where it takes 2, one a dimension"},
            {"s[1]", "`s[1]` names an element of `s`, but `s` is a dint global, no array"},
            {"ws[0].x", "`ws[0].x` goes too deep: `ws[0]` is an element, which has no members"},
            {"m1.w[3]",
             "`m1.w[3]`'s subscript `3` is outside 0 to 2: `m1.w` is an array of 3 ints"},
            {"m1.s[0]", "`m1.s[0]` names an element of `m1.s`, but `m1.s` is a dint, no array"},
            {"m1.w[0].x",
             "`m1.w[0].x` goes too deep: `m1.w[0]` is an element, which has no members"},
            {"m1.w.x",
             "`m1.w.x` goes too deep: `m1.w` is an array of 3 ints, which has no members"},
            {"ws.x",
             "`ws.x` goes too deep: `ws` is a global array of 3 ints, which has no members"},
            {"m1[0]",
             "`m1[0]` names an element of `m1`, a program instance: an access path names an element of one of its tags, as in `m1.temps[3]`"},
            {"zz[1]", "`zz` is neither a global nor a program instance"},
            {"m1.zz[1]", "`m1` is a program instance of `m`, which declares no `zz`"}
          ] do
        assert Runtime.get(runtime, path) == {:error, reason}, path
      end
    end
  end

  describe "the host contract" do
    test "a runtime the host built whose global array does not fit is refused at its cycle" do
      runtime = started()

      for {value, found} <- [
            {{1, 2}, "{1, 2}"},
            {{1, 2, 70_000}, "{1, 2, 70000}"},
            {[1, 2, 3], "[1, 2, 3]"}
          ] do
        built = %{runtime | globals: Map.put(runtime.globals, "ws", value)}

        assert_raise ArgumentError,
                     "runtime.globals holds `ws` outside its type: it is an array of 3 ints, and its value must be a tuple of 3 elements of ints, found #{found}",
                     fn -> Runtime.cycle(built, 10, %{}) end
      end

      # A var_external's global array is checked as the instance's state is, at its scan.
      built = %{runtime | globals: Map.put(runtime.globals, "g", {{0.0, 0.0}})}
      assert_raise ArgumentError, ~r/`g`/, fn -> Runtime.cycle(built, 10, %{}) end
    end

    test "a global real array the host built is held to its type's values, a single's" do
      {:ok, reals} =
        Logex.compile("var_input w real[2]\nvar_output s real\nmove w[1] s", name: "m")

      {:ok, configuration} =
        Configuration.compile(
          "c",
          "var_global rs real[2]\nvar_global s real\nprogram m1 m\nm1.w rs\nm1.s s\n",
          %{"m" => reals}
        )

      runtime = Runtime.start(configuration)
      <<single::float-32>> = <<0.1::float-32>>

      {_runtime, _outputs, _events} =
        Runtime.cycle(
          %{runtime | globals: Map.put(runtime.globals, "rs", {single, 0.0})},
          10,
          %{}
        )

      # 0.1 is no single, so no `real` holds it.
      assert_raise ArgumentError,
                   "runtime.globals holds `rs` outside its type: it is an array of 2 reals, and its value must be a tuple of 2 elements of reals, found {0.1, 0.0}",
                   fn ->
                     Runtime.cycle(
                       %{runtime | globals: Map.put(runtime.globals, "rs", {0.1, 0.0})},
                       10,
                       %{}
                     )
                   end
    end

    test "a restart starts each array global again at its initial list" do
      {runtime, _events} = cycled(started())
      assert Runtime.get!(runtime, "g") == [[0.0, 0.0], [3.0, 0.0]]
      restarted = Runtime.restart(runtime, :cold)
      assert Runtime.get!(restarted, "g") == [[0.0, 0.0], [0.0, 0.0]]
      assert Runtime.get!(restarted, "ws") == [1, 2, 3]
    end
  end

  describe "an online edit of the configuration (decision 157)" do
    test "a changed initial list is reported element by element, the running values kept" do
      runtime = started()

      candidate =
        String.replace(@configuration, "var_global ws int[3] 1 2 3", "var_global ws int[3] 1 5 0")

      {:ok, configuration} = compiled(candidate)
      {:ok, edit, _forecast} = Configuration.Edit.accept(runtime, configuration)
      {_edit, runtime, report} = Configuration.Edit.test(edit, runtime)

      assert {:initial_changed, "ws[1]", {2, 5}} in report
      assert {:initial_changed, "ws[2]", {3, 0}} in report
      refute Enum.any?(report, &match?({:initial_changed, "ws[0]", _}, &1))
      assert Runtime.get!(runtime, "ws") == [1, 2, 3]
    end

    test "an added array global is reported as a list, and a size changed only with a restart" do
      runtime = started()
      {:ok, configuration} = compiled(@configuration <> "var_global more int[2,2] 1 2 3 4\n")
      {:ok, edit, _forecast} = Configuration.Edit.accept(runtime, configuration)
      {_edit, runtime, report} = Configuration.Edit.test(edit, runtime)
      assert {:added, "more", [[1, 2], [3, 4]]} in report
      assert Runtime.get!(runtime, "more[1,0]") == 3

      with_more = @configuration <> "var_global more int[2,2] 1 2 3 4\n"
      {:ok, resized} = compiled(String.replace(with_more, "more int[2,2] 1 2 3 4", "more int[4]"))
      assert {:error, [diagnostic]} = Configuration.Edit.accept(started(with_more), resized)

      assert diagnostic.message ==
               "`more` is a global array of 2 by 2 ints in the running configuration and an array of 4 ints in the candidate: a global's type changes only with a restart"
    end
  end

  describe "built from Elixir" do
    test "the same configuration, read and run alike" do
      configuration =
        Configuration.new!(
          name: "c",
          programs: [program()],
          globals: [
            %Global{name: "ws", type: {:array, :int, [3]}, initial: [1, 2, 3]},
            %Global{name: "g", type: {:array, :real, [2, 2]}},
            %Global{name: "s", type: :dint},
            %Global{name: "os", type: {:array, :dint, [2, 2]}},
            %Global{name: "x", type: :int, initial: 7}
          ],
          instances: [%Instance{name: "m1", type: "m"}],
          connections: [
            %Connection{instance: "m1", member: "w", to: "ws"},
            %Connection{instance: "m1", member: "s", to: "s"},
            %Connection{instance: "m1", member: "e[0]", to: 4},
            %Connection{instance: "m1", member: "e[1]", to: "x"},
            %Connection{instance: "m1", member: "o", to: "os"}
          ]
        )

      {runtime, _events} = cycled(Runtime.start(configuration))
      {from_text, _events} = cycled(started())

      for path <- ~w(ws g s os x m1.w m1.e m1.o m1.g) do
        assert Runtime.get!(runtime, path) == Runtime.get!(from_text, path), path
      end
    end
  end
end
