defmodule Logex.LoadingTest do
  @moduledoc """
  Decision 480 (RV-18): the loader tests that read many files, run alone. Their raw reads
  (decision 464) take the VM's dirty I/O schedulers, which every raw file call of the VM
  shares, so beside a full suite on a crowded machine they ran past ExUnit's 60 s; here,
  `async: false`, ExUnit runs them only once every async module is done, one module at a
  time, so no other test shares those schedulers with them, and none is given more time.
  Each test's name and assertions are as they were in `configuration_test.exs` and
  `review_lows_test.exs`, under the same `describe`. `logex_test.exs`'s loader tests that
  read many files, `LogexTest.HeldFileServer`'s, are a module of their own, `async: false`,
  already.
  """
  use ExUnit.Case, async: false

  alias Logex.{Configuration, Diagnostic}

  # The tests that run alone, by their names in their files as they were.
  @alone [
    "any text in a configuration file gives a result, compile/3's where it is accepted",
    "loading stays linear in the program types a file names",
    "a6-compile-scale-2: a block's file swapped for a program's during a load is told it is " <>
      "a program"
  ]

  # Decision 480: ExUnit runs a module that is not async only once every async module is
  # done, so these tests share the dirty I/O schedulers with no other test only while no
  # other test file holds them too.
  test "the loader tests of many files run alone, in this module and in no other file" do
    assert %{async?: false} = __MODULE__.__ex_unit__(:config)

    root = Path.expand("../..", __DIR__)
    ours = Path.join(root, "test/logex/loading_test.exs")

    for name <- @alone do
      assert Enum.count(__MODULE__.__ex_unit__().tests, &String.ends_with?("#{&1.name}", name)) ==
               1

      for path <- Path.wildcard(Path.join(root, "test/**/*.exs")) -- [ours],
          do: refute(File.read!(path) =~ ~s(test "#{name}"), "#{path} holds `#{name}`")
    end
  end

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

  # `base/1` with its instance on a periodic task, as a configuration file says it.
  @tasked "task fast interval 10 priority 0\n" <>
            String.replace(@base, "program m seal", "program m seal with fast")

  # The receipt's broken source (`docs/organisation.md` §4.4), one mistake on each of
  # lines 7, 9, 11, 12, 14, 15 and 16 and every other line right: its line 6 declares a
  # task, and line 9's mistake is the task its instance names.
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

  defp compiled(source, programs), do: Configuration.compile("plant", source, programs)

  describe "compile_file/1 (M2-2): a configuration file and its program types, on disk" do
    @describetag :tmp_dir

    # A seal-in block with a warning, held by two program types, `motor` and `pump`.
    @seal_ld """
    function_block seal
    var_input start bool
    var_input stop bool
    var_output run bool
    var spare bool
    ( xic start | xic run ) xio stop ote run
    """

    defp write(dir, file, text) do
      path = Path.join(dir, file)
      File.write!(path, text)
      path
    end

    # A seeded property: the texts `configuration_test.exs`'s totality property draws, each
    # written to a configuration file beside `seal.ld`. compile_file/1 never raises; every diagnostic
    # names a file; and what it accepts is what compile/3 accepts from the same text over
    # the program type it loaded, but for the file.
    test "any text in a configuration file gives a result, compile/3's where it is accepted",
         %{tmp_dir: dir} do
      :rand.seed(:exsss, {2026, 10, 11})
      seal_ld = write(dir, "seal.ld", @seal)
      {:ok, seal} = Logex.compile_file(seal_ld)
      path = Path.join(dir, "plant.logex")

      outcomes =
        for _ <- 1..300 do
          source = edited(Enum.random([@base, @tasked, @broken]), Enum.random(0..4))
          File.write!(path, source)
          drawn(Configuration.compile_file(path), source, path, %{"seal" => seal})
        end

      assert :accepted in outcomes and :refused in outcomes
    end

    # The loader's passes, over n program types that each hold one shared block: the
    # types named, their files, one memo across them, each type's blocks handed back, the
    # citations. Each program is compiled once, so the whole is linear in the types.
    test "loading stays linear in the program types a file names", %{tmp_dir: dir} do
      load = fn n ->
        here = Path.join(dir, "n#{n}")
        File.mkdir_p!(here)
        write(here, "seal.ld", @seal_ld)

        text =
          Enum.map_join(1..n, fn i ->
            write(
              here,
              "t#{i}.ld",
              "var_input a bool\nvar_output b bool\nvar s1 seal\n" <>
                "cal s1 a a b\n"
            )

            "var_global a#{i} bool at panel.i.#{i}\nvar_global b#{i} bool at panel.q.#{i}\n" <>
              "program m#{i} t#{i}\nm#{i}.a a#{i}\nm#{i}.b b#{i}\n"
          end)

        path = write(here, "plant.logex", text)
        growth_reductions(fn -> {:ok, _config} = Configuration.compile_file(path) end)
      end

      # 4.007x to 4.025x over 36 runs of the suite, 24 of them three suites at once; the
      # bound a fifth above the highest.
      ratio = load.(200) / load.(50)
      assert ratio < 4.9, "4x the program types took #{Float.round(ratio, 2)}x the reductions"
    end
  end

  # The least of three counts of a call's reductions, since a busy VM can raise one.
  defp growth_reductions(fun) do
    Enum.min(
      for _ <- 1..3 do
        {:reductions, before} = Process.info(self(), :reductions)
        fun.()
        {:reductions, later} = Process.info(self(), :reductions)
        later - before
      end
    )
  end

  # A configuration as compile/3 gives it, which no file names.
  defp unfiled(config),
    do: %{config | file: nil, warnings: Enum.map(config.warnings, &%{&1 | file: nil})}

  defp drawn({:ok, config}, source, path, programs) do
    assert config.file == path
    assert config.programs in [%{}, programs]
    assert {:ok, unfiled(config)} == compiled(source, config.programs)
    :accepted
  end

  defp drawn({:error, [_ | _] = diagnostics}, _source, _path, _programs) do
    for diagnostic <- diagnostics, do: assert(is_binary(diagnostic.file))
    :refused
  end

  # Words a seeded edit puts into a source: every line's keywords in other cases, a later
  # item's words, names, paths and locations good and bad, numbers in and out of range,
  # the delimiters, and a few that do not lex.
  @vocabulary ~w(var_global VAR_GLOBAL program Program at AT bool Dint task Task interval
                   PRIORITY with With single continuous Continuous watchdog WATCHDOG main
                   retain RETAIN non_retain Non_Retain
                   fast m m2 m.start m.stop m.motor m.sp m.fault m.t1
                   m.t1.pre m.x.y m2.start pb
                   pb2 k sp seal Seal x.y panel.i.0 panel.I.0 panel.q.00 Panel.q.1 panel.q.0
                   drive.q.1.0 0 1 7 2147483647 2147483648 99999999999 -1 -7 -2147483648
                   -2147483649 - \( | \) //) ++
                ["\t", "\r", "\r\n", "%", "é", <<255>>]

  # A source as a list of lines of words, edited `n` times: a word replaced, put in or
  # taken out, a line doubled, dropped or moved, or two lines joined.
  defp edited(source, n) do
    source
    |> String.split("\n")
    |> Enum.map(&String.split(&1, " "))
    |> edit(n)
    |> Enum.map_join("\n", &Enum.join(&1, " "))
  end

  defp edit(lines, 0), do: lines
  defp edit([], n), do: edit([[]], n - 1)

  defp edit(lines, n) do
    i = rnd(length(lines))
    line = Enum.at(lines, i)
    word = Enum.random(@vocabulary)

    lines
    |> edit_line(Enum.random(1..7), i, line, word)
    |> edit(n - 1)
  end

  defp edit_line(lines, 1, i, line, word),
    do: List.replace_at(lines, i, List.replace_at(line, rnd(length(line) + 1), word))

  defp edit_line(lines, 2, i, line, word),
    do: List.replace_at(lines, i, List.insert_at(line, rnd(length(line) + 1), word))

  defp edit_line(lines, 3, i, line, _word),
    do: List.replace_at(lines, i, List.delete_at(line, rnd(length(line) + 1)))

  defp edit_line(lines, 4, i, line, _word), do: List.insert_at(lines, i, line)
  defp edit_line(lines, 5, i, _line, _word), do: List.delete_at(lines, i)

  defp edit_line(lines, 6, i, line, _word),
    do: List.insert_at(List.delete_at(lines, i), rnd(length(lines)), line)

  defp edit_line(lines, 7, i, line, _word),
    do: List.replace_at(List.delete_at(lines, i), i, line ++ Enum.at(lines, i + 1, []))

  defp rnd(n), do: :rand.uniform(n) - 1

  describe "the loader" do
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
      # under the loops they took 2 s and 0.5 s. Since decision 464 the loads read raw too,
      # and since decision 480 the test runs in this module, alone.
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

  defp dir! do
    dir = Path.join(System.tmp_dir!(), "logex-rv2-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end
end
