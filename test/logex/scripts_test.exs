defmodule Logex.ScriptsTest do
  @moduledoc """
  `scripts/failed.exs` (decision 359), run as `scripts/gate.sh` runs it, over failures
  manifests written as ExUnit writes them: `{1, %{{module, name} => file}}` after a run
  that ran, and `{1, :all}` after one whose test files failed to compile or load; each
  test's line read from its file. And CI's test step (decision 515 (e)), read from
  `.github/workflows/ci.yml` and run as GitHub runs it, its shell's flags and all, over a
  stand-in `mix` that prints, writes a manifest and exits as a run would; the workflow's
  keys, so that every push and pull request runs every gate and no step is skipped or its
  failure let pass; and `scripts/gate.sh` over the same stand-in.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir
  @root Path.expand("../..", __DIR__)
  # The `elixir` beside the Elixir the suite runs on, or else the one on the path.
  @elixir Enum.find(
            [
              Path.expand(Path.join([:code.lib_dir(:elixir), "..", "..", "bin", "elixir"])),
              System.find_executable("elixir")
            ],
            &File.exists?(to_string(&1))
          )

  defp failed(build, args \\ []) do
    System.cmd(@elixir, ["scripts/failed.exs" | args],
      cd: @root,
      env: [{"MIX_BUILD_PATH", build}],
      stderr_to_stdout: true
    )
  end

  defp manifest(build, term) do
    path = Path.join([build, "lib", "logex", ".mix", ".mix_test_failures"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(term))
  end

  test "it names each failure the manifest holds, in order, a line each", %{tmp_dir: build} do
    manifest(
      build,
      {1,
       %{
         {Logex.TripTest, :"test a trip"} => Path.join(@root, "test/logex/trip_test.exs"),
         {Logex.ClockTest, :"test a clock"} => Path.join(@root, "test/logex/clock_test.exs")
       }}
    )

    assert failed(build) ==
             {"test/logex/clock_test.exs: Logex.ClockTest: test a clock\n" <>
                "test/logex/trip_test.exs: Logex.TripTest: test a trip\n", 0}
  end

  test "it says a suite that did not load failed whole, and does not crash",
       %{tmp_dir: build} do
    manifest(build, {1, :all})

    assert failed(build) ==
             {"suite: no test ran: a test file failed to compile or load, so ExUnit " <>
                "marked the whole suite failed; mix test's output names the file\n", 0}
  end

  test "it prints nothing where there is no manifest or no failure", %{tmp_dir: build} do
    assert failed(build) == {"", 0}
    manifest(build, {1, %{}})
    assert failed(build) == {"", 0}
  end

  # Two names a test call writes literally: with `test `, 255 bytes, which ExUnit keeps
  # whole, and 256, which it cuts.
  @whole String.pad_trailing("a lamp whose name ExUnit keeps whole", 250, ", whole")
  @cut String.pad_trailing("a lamp whose name ExUnit cuts", 251, ", cut")

  # A test file of every shape a test's name takes, each test's line its call's.
  @shapes """
  defmodule Logex.BoxTest do
    use ExUnit.Case
    doctest Logex.Box

    describe "a box counter" do
      test "counts each box once" do
        assert false
      end

      for lane <- [:left, :right] do
        test "the \#{lane} lane " <> "counts too", do: assert(unquote(lane) == :none)
      end
    end

    test "counts each box once" do
      assert false
    end

    test "a box past the counter's limit wraps to the least, " <>
           "#{String.duplicate("and the rung passes no power, ", 9)}which a lamp shows" do
      assert false
    end

    defmodule Lamp do
      use ExUnit.Case

      test "counts each box once", do: assert(false)
    end
  end

  for belt <- [Left, Right] do
    defmodule Module.concat(Logex.BeltTest, belt) do
      use ExUnit.Case

      test "the \#{inspect(belt)} belt runs", do: assert(false)
    end
  end

  defmodule Logex.LampTest do
    use ExUnit.Case

    test "the lamp lights" do
      assert false
    end

    for {name, lamp} <- [{"the lamp dims", 1}] do
      test name, do: assert(unquote(lamp) == 0)
    end

    test "#{@whole}" do
      assert false
    end

    test "#{@cut}" do
      assert false
    end
  end

  defmodule Logex.SignalTest do
    use ExUnit.Case
    doctest Logex.Signal
    doctest Logex.Signal.Lamp

    for colour <- ["red", "green"] do
      test "the \#{colour} lamp blinks", do: assert(false)
      test "the \#{colour} lamp blinks " <> "twice", do: assert(false)
    end

    for n <- [1, 2] do
      test "lamp \#{n} passes", do: assert(false)
      test "the test lamp \#{n} passes", do: assert(false)
    end

    for side <- ["left", "right"] do
      test "the \#{side} belt runs", do: assert(false)
    end
  end

  defmodule Logex.HornTest do
    use ExUnit.Case

    for {name, n} <- [{"the horn sounds loud", 1}] do
      test name, do: assert(unquote(n) == 0)
    end

    for state <- ["sounds", "stops"] do
      test "the horn \#{state}", do: assert(false)
    end
  end
  """

  test "it gives each test's line, read from the test call in its module and describe, " <>
         "where a name the compile makes matches any text and a module it names any module",
       %{tmp_dir: build} do
    file = Path.join(build, "box_test.exs")
    File.write!(file, @shapes)

    long =
      "test a box past the counter's limit wraps to the least, " <>
        String.duplicate("and the rung passes no power, ", 9) <> "which a lamp shows"

    cut =
      String.byte_slice(long, 0, 246) <>
        "... " <>
        (long |> :erlang.md5() |> binary_slice(0, 3) |> Base.encode64())

    manifest(
      build,
      {1,
       %{
         {Logex.BeltTest.Right, :"test the Right belt runs"} => file,
         {Logex.BoxTest, :"doctest Logex.Box.count/2 (3)"} => file,
         {Logex.BoxTest, :"doctest module Logex.Box (1)"} => file,
         {Logex.BoxTest, :"test a box counter counts each box once"} => file,
         {Logex.BoxTest, :"test a box counter the right lane counts too"} => file,
         {Logex.BoxTest, :"test counts each box once"} => file,
         {Logex.BoxTest, String.to_atom(cut)} => file,
         {Logex.BoxTest.Lamp, :"test counts each box once"} => file
       }}
    )

    at = Path.relative_to(file, @root)

    assert failed(build) ==
             {"#{at}:35: Logex.BeltTest.Right: test the Right belt runs\n" <>
                "#{at}:3: Logex.BoxTest: doctest Logex.Box.count/2 (3)\n" <>
                "#{at}:3: Logex.BoxTest: doctest module Logex.Box (1)\n" <>
                "#{at}:6: Logex.BoxTest: test a box counter counts each box once\n" <>
                "#{at}:11: Logex.BoxTest: test a box counter the right lane counts too\n" <>
                "#{at}:19: Logex.BoxTest: #{cut}\n" <>
                "#{at}:15: Logex.BoxTest: test counts each box once\n" <>
                "#{at}:27: Logex.BoxTest.Lamp: test counts each box once\n", 0}
  end

  test "a test no call in its module names, or whose file is gone, is given its file alone",
       %{tmp_dir: build} do
    file = Path.join(build, "box_test.exs")
    File.write!(file, @shapes)
    gone = Path.join(build, "gone_test.exs")

    manifest(
      build,
      {1,
       %{
         {Logex.BoxTest, :"test a box counter counts each box twice"} => file,
         {Logex.BoxTest.Lamp, :"test a box counter counts each box once"} => file,
         {Logex.GoneTest, :"test counts each box once"} => gone
       }}
    )

    assert failed(build) ==
             {"#{Path.relative_to(file, @root)}: Logex.BoxTest: " <>
                "test a box counter counts each box twice\n" <>
                "#{Path.relative_to(file, @root)}: Logex.BoxTest.Lamp: " <>
                "test a box counter counts each box once\n" <>
                "#{Path.relative_to(gone, @root)}: Logex.GoneTest: test counts each box once\n",
              0}
  end

  # ExUnit.Case's own name for a test: cut to 246 bytes and hashed past 255.
  defp exunit_name(name) when byte_size(name) > 255 do
    hash = name |> :erlang.md5() |> binary_slice(0, 3) |> Base.encode64()
    String.byte_slice(name, 0, 246) <> "... " <> hash
  end

  defp exunit_name(name), do: name

  # Where more than one call could name a test, the surest gives its line: one in the
  # test's own module before one in a module the compile names, a name all literal before
  # one the compile makes, each anchored at both ends; where the surest are more than one,
  # the file alone.
  test "the surest call that could name a test gives its line, and the file alone where " <>
         "the surest are more than one",
       %{tmp_dir: build} do
    file = Path.join(build, "box_test.exs")
    File.write!(file, @shapes)
    whole = "test " <> @whole
    cut = exunit_name("test " <> @cut)
    assert {byte_size(whole), byte_size("test " <> @cut), byte_size(cut)} == {255, 256, 254}

    manifest(
      build,
      {1,
       %{
         {Logex.HornTest, :"test the horn sounds"} => file,
         {Logex.LampTest, :"test the lamp dims"} => file,
         {Logex.LampTest, :"test the lamp lights"} => file,
         {Logex.LampTest, String.to_atom(whole)} => file,
         {Logex.LampTest, String.to_atom(cut)} => file,
         {Logex.SignalTest, :"doctest Logex.Signal.Lamp.on/1 (1)"} => file,
         {Logex.SignalTest, :"doctest Logex.Signal.blink/0 (2)"} => file,
         {Logex.SignalTest, :"doctest module Logex.Signal (1)"} => file,
         {Logex.SignalTest, :"test lamp 1 passes"} => file,
         {Logex.SignalTest, :"test the left belt runs"} => file,
         {Logex.SignalTest, :"test the green lamp blinks"} => file,
         {Logex.SignalTest, :"test the red lamp blinks twice"} => file,
         {Logex.SignalTest, :"test the test lamp 2 passes"} => file
       }}
    )

    at = Path.relative_to(file, @root)

    assert failed(build) ==
             {"#{at}: Logex.HornTest: test the horn sounds\n" <>
                "#{at}:54: Logex.LampTest: #{cut}\n" <>
                "#{at}:50: Logex.LampTest: #{whole}\n" <>
                "#{at}:47: Logex.LampTest: test the lamp dims\n" <>
                "#{at}:42: Logex.LampTest: test the lamp lights\n" <>
                "#{at}:62: Logex.SignalTest: doctest Logex.Signal.Lamp.on/1 (1)\n" <>
                "#{at}:61: Logex.SignalTest: doctest Logex.Signal.blink/0 (2)\n" <>
                "#{at}:61: Logex.SignalTest: doctest module Logex.Signal (1)\n" <>
                "#{at}:70: Logex.SignalTest: test lamp 1 passes\n" <>
                "#{at}:65: Logex.SignalTest: test the green lamp blinks\n" <>
                "#{at}:75: Logex.SignalTest: test the left belt runs\n" <>
                "#{at}:66: Logex.SignalTest: test the red lamp blinks twice\n" <>
                "#{at}:71: Logex.SignalTest: test the test lamp 2 passes\n", 0}
  end

  describe "--exit N, after a run made with the manifest deleted before it" do
    test "after a red run it heads the tests that failed with the run's code and exits " <>
           "with it",
         %{tmp_dir: build} do
      file = Path.join(@root, "test/logex/clock_test.exs")
      manifest(build, {1, %{{Logex.ClockTest, :"test a clock"} => file}})

      assert failed(build, ["--exit", "2"]) ==
               {"mix test exited 2; the tests that failed:\n" <>
                  "test/logex/clock_test.exs: Logex.ClockTest: test a clock\n", 2}

      manifest(build, {1, :all})

      assert failed(build, ["--exit", "1"]) ==
               {"mix test exited 1; the tests that failed:\n" <>
                  "suite: no test ran: a test file failed to compile or load, so ExUnit " <>
                  "marked the whole suite failed; mix test's output names the file\n", 1}
    end

    test "after a red run that names no test it says why: no manifest, the suite did not " <>
           "finish; a manifest of no failure, another reason",
         %{tmp_dir: build} do
      assert failed(build, ["--exit", "1"]) ==
               {"mix test exited 1; the tests that failed:\n" <>
                  "none named: ExUnit wrote no failures manifest, so the suite did not " <>
                  "finish: a test halted the VM, or mix test stopped before the suite ran; " <>
                  "the output above names any test that failed before it stopped\n", 1}

      manifest(build, {1, %{}})

      assert failed(build, ["--exit", "1"]) ==
               {"mix test exited 1; the tests that failed:\n" <>
                  "none named: every test that ran passed, and mix test exited 1 for another " <>
                  "reason, above: a warning under --warnings-as-errors, for one\n", 1}
    end

    test "after a run that exited 0 it is silent where the manifest names no failure, and " <>
           "red where there is none or it names one",
         %{tmp_dir: build} do
      assert failed(build, ["--exit", "0"]) ==
               {"mix test exited 0, and ExUnit wrote no failures manifest: the suite did not " <>
                  "finish, a test having halted the VM, so the run is red; the output above " <>
                  "names any test that failed before it stopped\n", 1}

      manifest(build, {1, %{}})
      assert failed(build, ["--exit", "0"]) == {"", 0}
      file = Path.join(@root, "test/logex/clock_test.exs")
      manifest(build, {1, %{{Logex.ClockTest, :"test a clock"} => file}})

      assert failed(build, ["--exit", "0"]) ==
               {"mix test exited 0; the tests that failed:\n" <>
                  "test/logex/clock_test.exs: Logex.ClockTest: test a clock\n", 1}
    end

    test "anything else is refused with its usage", %{tmp_dir: build} do
      usage = {"usage: elixir scripts/failed.exs [--exit N]\n", 2}
      assert failed(build, ["--exit", "two"]) == usage
      assert failed(build, ["--exit", "-1"]) == usage
      assert failed(build, ["--exit"]) == usage
      assert failed(build, ["2"]) == usage
    end
  end

  # CI's test step, as `.github/workflows/ci.yml` writes it: its `shell:` and the lines of
  # its `run:`, a block or one line.
  defp ci_step(name) do
    lines = @root |> Path.join(".github/workflows/ci.yml") |> File.read!() |> String.split("\n")
    [_ | step] = Enum.drop_while(lines, &(String.trim(&1) != "- name: #{name}"))
    step = Enum.take_while(step, &(not String.match?(&1, ~r/^\s*- name: /)))
    shell = Enum.find_value(step, &shell/1)
    {shell, run(Enum.drop_while(step, &(not String.match?(&1, ~r/^\s*run:/))))}
  end

  defp shell(line), do: Regex.run(~r/^\s*shell:\s*(\S+)\s*$/, line, capture: :all_but_first)

  defp run([line | block]) do
    indent = &(byte_size(&1) - byte_size(String.trim_leading(&1)))
    run(String.trim(line), indent.(line), block, indent)
  end

  defp run("run: |", at, block, indent) do
    block
    |> Enum.take_while(&(String.trim(&1) == "" or indent.(&1) > at))
    |> Enum.map_join("\n", &String.slice(&1, (at + 2)..-1//1))
  end

  defp run("run: " <> line, _at, _block, _indent), do: line

  # Runs the step as GitHub runs a `shell: bash` step, `bash --noprofile --norc -eo
  # pipefail`, in `dir`, a `mix` of the test's own first on the path: it notes its
  # arguments and whether a manifest was there as it started, puts `manifest` in place,
  # where given, prints a run's last line and exits with `rc`.
  defp run_step(dir, rc, manifest) do
    {["bash"], script} = ci_step("mix test --warnings-as-errors")
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)
    File.mkdir_p!(Path.join(dir, "scripts"))
    File.cp!(Path.join(@root, "scripts/failed.exs"), Path.join(dir, "scripts/failed.exs"))
    path = "_build/test/lib/logex/.mix/.mix_test_failures"
    File.write!(Path.join(dir, "next"), (manifest && :erlang.term_to_binary(manifest)) || "")

    File.write!(Path.join(bin, "mix"), """
    #!/usr/bin/env bash
    echo "$* $([ -e #{path} ] && echo held || echo none)" > called
    mkdir -p "$(dirname #{path})"
    [ -s next ] && cp next #{path}
    echo "Result: 1/3 passed"
    exit #{rc}
    """)

    File.chmod!(Path.join(bin, "mix"), 0o755)
    File.write!(Path.join(dir, "step.sh"), script)

    {out, code} =
      System.cmd("bash", ["--noprofile", "--norc", "-eo", "pipefail", "step.sh"],
        cd: dir,
        env: [{"PATH", Enum.join([bin, Path.dirname(@elixir), System.get_env("PATH")], ":")}],
        stderr_to_stdout: true
      )

    {out, code, File.read!(Path.join(dir, "called"))}
  end

  describe "CI's test step (decision 515 (e))" do
    test "a red run's log ends with each failed test's file, line and name, the step " <>
           "exiting with the suite's code",
         %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "test"))
      file = Path.join(dir, "test/box_test.exs")
      File.write!(file, @shapes)

      red =
        {1,
         %{
           {Logex.BoxTest, :"test a box counter counts each box once"} => file,
           {Logex.BoxTest.Lamp, :"test counts each box once"} => file
         }}

      assert run_step(dir, 2, red) ==
               {"Result: 1/3 passed\n" <>
                  "mix test exited 2; the tests that failed:\n" <>
                  "test/box_test.exs:6: Logex.BoxTest: test a box counter counts each box once\n" <>
                  "test/box_test.exs:27: Logex.BoxTest.Lamp: test counts each box once\n", 2,
                "test --warnings-as-errors none\n"}
    end

    test "a green run names nothing and exits 0", %{tmp_dir: dir} do
      assert run_step(dir, 0, {1, %{}}) ==
               {"Result: 1/3 passed\n", 0, "test --warnings-as-errors none\n"}
    end

    test "a run that exits 0 and writes no manifest, a suite a test halted, is red, and " <>
           "says so",
         %{tmp_dir: dir} do
      assert run_step(dir, 0, nil) ==
               {"Result: 1/3 passed\n" <>
                  "mix test exited 0, and ExUnit wrote no failures manifest: the suite did " <>
                  "not finish, a test having halted the VM, so the run is red; the output " <>
                  "above names any test that failed before it stopped\n", 1,
                "test --warnings-as-errors none\n"}
    end

    test "a red run in which every test passed, a warning's, says why it names none",
         %{tmp_dir: dir} do
      assert run_step(dir, 1, {1, %{}}) ==
               {"Result: 1/3 passed\nmix test exited 1; the tests that failed:\n" <>
                  "none named: every test that ran passed, and mix test exited 1 for another " <>
                  "reason, above: a warning under --warnings-as-errors, for one\n", 1,
                "test --warnings-as-errors none\n"}
    end

    test "a manifest an earlier run left, a cached _build's, is gone before the suite runs, " <>
           "so a red run that writes none names nothing of it, and says why",
         %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "test"))
      file = Path.join(dir, "test/box_test.exs")
      File.write!(file, @shapes)

      manifest(
        Path.join(dir, "_build/test"),
        {1, %{{Logex.BoxTest, :"test counts each box once"} => file}}
      )

      assert run_step(dir, 1, nil) ==
               {"Result: 1/3 passed\nmix test exited 1; the tests that failed:\n" <>
                  "none named: ExUnit wrote no failures manifest, so the suite did not " <>
                  "finish: a test halted the VM, or mix test stopped before the suite ran; " <>
                  "the output above names any test that failed before it stopped\n", 1,
                "test --warnings-as-errors none\n"}
    end
  end

  # `.github/workflows/ci.yml`'s lines that hold anything, comments and blank lines
  # dropped.
  defp ci_lines do
    @root
    |> Path.join(".github/workflows/ci.yml")
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
  end

  # The keys among `lines` written at `indent`, a list item's first with its `- `; a block's
  # text and a deeper map's keys are deeper, and not read.
  defp keys_at(lines, indent) do
    for line <- lines,
        [_, key] <- [Regex.run(~r/^ {#{indent}}((?:- )?[A-Za-z_-]+):/, line)],
        do: key
  end

  # The lines from the one `heading` to the next at its indentation or less.
  defp under(lines, heading) do
    [line | rest] = Enum.drop_while(lines, &(&1 != heading))
    indent = byte_size(line) - byte_size(String.trim_leading(line))
    Enum.take_while(rest, &(byte_size(&1) - byte_size(String.trim_leading(&1)) > indent))
  end

  # The job's steps, each its keys in order, its first `- key` given as `key`.
  defp steps(lines) do
    lines
    |> under("    steps:")
    |> Enum.chunk_while([], &step/2, &{:cont, Enum.reverse(&1), []})
    |> Enum.reject(&(&1 == []))
    |> Enum.map(&(keys_at(&1, 6) ++ keys_at(&1, 8)))
    |> Enum.map(fn ["- " <> first | keys] -> [first | keys] end)
  end

  defp step("      - " <> _ = line, []), do: {:cont, [line]}
  defp step("      - " <> _ = line, acc), do: {:cont, Enum.reverse(acc), [line]}
  defp step(line, acc), do: {:cont, [line | acc]}

  describe "CI's workflow (decision 515 (e))" do
    test "every push and pull request runs one job of every gate, no step skipped or its " <>
           "failure let pass, the test step no key but its name, shell and run" do
      lines = ci_lines()

      assert {keys_at(lines, 0), under(lines, "on:"), keys_at(lines, 2),
              keys_at(under(lines, "  gate:"), 4), steps(lines)} ==
               {["name", "on", "jobs"], ["  push:", "  pull_request:"],
                ["push", "pull_request", "gate"], ["runs-on", "env", "steps"],
                [
                  ["uses"],
                  ["name", "id", "uses", "with"],
                  ["name", "uses", "with"],
                  ["name", "run"],
                  ["name", "run"],
                  ["name", "run", "env"],
                  ["name", "shell", "run"]
                ]}
    end

    test "the three gates before the suite each run the command CONTRIBUTING.md names, the " <>
           "last under MIX_ENV=test" do
      lines = ci_lines()
      test_build = "MIX_ENV=test mix compile --force --warnings-as-errors"

      assert {ci_step("mix format --check-formatted"),
              ci_step("mix compile --force --warnings-as-errors"), ci_step(test_build),
              lines
              |> Enum.drop_while(&(&1 != "      - name: #{test_build}"))
              |> under("        env:")} ==
               {{nil, "mix format --check-formatted"},
                {nil, "mix compile --force --warnings-as-errors"},
                {nil, "mix compile --force --warnings-as-errors"}, ["          MIX_ENV: test"]}
    end
  end

  # Runs `scripts/gate.sh` in `dir` as a commit's gate runs it, a `mix` of the test's own
  # first on the path: it notes each gate's task and `MIX_ENV`, exits `format_rc` for the
  # format check, 0 for each compile, and for the suite prints a run's last line, puts
  # `manifest` in place, where given, and exits `test_rc`; a manifest an earlier run left
  # is there before the gate runs.
  defp run_gate(dir, format_rc, test_rc, manifest) do
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)
    File.mkdir_p!(Path.join(dir, "scripts"))

    for script <- ["gate.sh", "failed.exs"] do
      File.cp!(Path.join(@root, "scripts/#{script}"), Path.join(dir, "scripts/#{script}"))
    end

    path = "_build/test/lib/logex/.mix/.mix_test_failures"
    File.write!(Path.join(dir, "next"), (manifest && :erlang.term_to_binary(manifest)) || "")
    manifest(Path.join(dir, "_build/test"), {1, %{{Logex.BoxTest, :"test stale"} => "x"}})

    File.write!(Path.join(bin, "mix"), """
    #!/usr/bin/env bash
    echo "$1 ${MIX_ENV:-dev}" >> called
    case "$1" in
      format) exit #{format_rc} ;;
      test)
        mkdir -p "$(dirname #{path})"
        [ -s next ] && cp next #{path}
        echo "Result: 1/3 passed"
        exit #{test_rc} ;;
    esac
    """)

    File.chmod!(Path.join(bin, "mix"), 0o755)

    {out, code} =
      System.cmd("bash", ["scripts/gate.sh", "gate.log"],
        cd: dir,
        env: [{"PATH", Enum.join([bin, Path.dirname(@elixir), System.get_env("PATH")], ":")}],
        stderr_to_stdout: true
      )

    {out, code, File.read!(Path.join(dir, "called"))}
  end

  describe "scripts/gate.sh" do
    @gates "format dev\ncompile dev\ncompile test\ntest dev\n"

    test "a green suite is GATE-OK, every gate run in order", %{tmp_dir: dir} do
      assert run_gate(dir, 0, 0, {1, %{}}) == {"Result: 1/3 passed\nGATE-OK\n", 0, @gates}
    end

    test "a red suite is followed by the tests that failed, each with its line",
         %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "test"))
      file = Path.join(dir, "test/box_test.exs")
      File.write!(file, @shapes)
      red = {1, %{{Logex.BoxTest, :"test counts each box once"} => file}}

      assert run_gate(dir, 0, 2, red) ==
               {"Result: 1/3 passed\nGATE-FAIL rc=2\n" <>
                  "mix test exited 2; the tests that failed:\n" <>
                  "test/box_test.exs:15: Logex.BoxTest: test counts each box once\n", 2, @gates}
    end

    test "a suite that exits 0 and writes no manifest, one a test halted, is GATE-FAIL",
         %{tmp_dir: dir} do
      assert run_gate(dir, 0, 0, nil) ==
               {"Result: 1/3 passed\nGATE-FAIL rc=1\n" <>
                  "mix test exited 0, and ExUnit wrote no failures manifest: the suite did " <>
                  "not finish, a test having halted the VM, so the run is red; the output " <>
                  "above names any test that failed before it stopped\n", 1, @gates}
    end

    test "a gate before the suite that fails stops the rest, and names no test",
         %{tmp_dir: dir} do
      assert run_gate(dir, 1, 0, {1, %{}}) == {"GATE-FAIL rc=1\n", 1, "format dev\n"}
    end
  end
end
