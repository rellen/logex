defmodule Logex.ScriptsTest do
  @moduledoc """
  `scripts/failed.exs` (decision 359), run as `scripts/gate.sh` runs it, over failures
  manifests written as ExUnit writes them: `{1, %{{module, name} => file}}` after a run
  that ran, and `{1, :all}` after one whose test files failed to compile or load; each
  test's line read from its file. And CI's test step (decision 515 (e)), read from
  `.github/workflows/ci.yml` and run as GitHub runs it, its shell's flags and all, over a
  stand-in `mix` that prints, writes a manifest and exits as a run would.
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

  defp failed(build) do
    System.cmd(@elixir, ["scripts/failed.exs"],
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

    test "a manifest an earlier run left, a cached _build's, is gone before the suite runs, " <>
           "so a red run that writes none names nothing of it",
         %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "test"))
      file = Path.join(dir, "test/box_test.exs")
      File.write!(file, @shapes)

      manifest(
        Path.join(dir, "_build/test"),
        {1, %{{Logex.BoxTest, :"test counts each box once"} => file}}
      )

      assert run_step(dir, 1, nil) ==
               {"Result: 1/3 passed\nmix test exited 1; the tests that failed:\n", 1,
                "test --warnings-as-errors none\n"}
    end
  end
end
