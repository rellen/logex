# Names the tests ExUnit's failures manifest holds, one a line, `file: Module: test name`,
# so that a failed run says which tests failed (`mix test` prints `Result: 39/40 passed`
# and, under a busy log, the failures can be hard to find). Run from the project's root:
#
#     elixir scripts/failed.exs
#
# It reads the manifest of the test build, `_build/test/lib/logex/.mix/.mix_test_failures`
# (MIX_BUILD_PATH or MIX_BUILD_ROOT, where set, moves it), and prints nothing for a
# manifest that holds no failure. The manifest is ExUnit's own, kept across runs: a test's
# failure stays in it until a run passes that test, so after a run of one file by hand it
# may still name a failure of another file's earlier run. `scripts/gate.sh`,
# `scripts/mutate.sh` and `scripts/load.sh` delete it before each run, so after them it
# names that run's failures alone. A suite whose test files fail to compile or load runs
# no test, and ExUnit marks it failed whole, which is told in one line beginning `suite:`.
# A script, not a test: it uses `case` freely.
build =
  System.get_env("MIX_BUILD_PATH") ||
    Path.join(System.get_env("MIX_BUILD_ROOT", "_build"), "test")

path = Path.join([build, "lib", "logex", ".mix", ".mix_test_failures"])

case File.read(path) do
  {:ok, binary} ->
    case :erlang.binary_to_term(binary) do
      {_version, :all} ->
        IO.puts(
          "suite: no test ran: a test file failed to compile or load, so ExUnit marked " <>
            "the whole suite failed; mix test's output names the file"
        )

      {_version, failures} ->
        for {{module, name}, file} <- Enum.sort(failures) do
          IO.puts("#{Path.relative_to_cwd(file)}: #{inspect(module)}: #{name}")
        end
    end

  {:error, :enoent} ->
    :ok
end
