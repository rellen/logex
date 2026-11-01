defmodule Logex.ScriptsTest do
  @moduledoc """
  `scripts/failed.exs` (decision 359), run as `scripts/gate.sh` runs it, over failures
  manifests written as ExUnit writes them: `{1, %{{module, name} => file}}` after a run
  that ran, and `{1, :all}` after one whose test files failed to compile or load.
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
end
