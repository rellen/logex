# Names the tests ExUnit's failures manifest holds, one a line, `file: Module: test name`,
# so that a failed run says which tests failed (`mix test` prints `Result: 39/40 passed`
# and, under a busy log, the failures can be hard to find). Run from the project's root:
#
#     elixir scripts/failed.exs
#
# It reads the manifest of the test build, `_build/test/lib/logex/.mix/.mix_test_failures`
# (MIX_BUILD_PATH or MIX_BUILD_ROOT, where set, moves it), and prints nothing for a run
# with no failures. A script, not a test: it uses `case` freely.
build =
  System.get_env("MIX_BUILD_PATH") ||
    Path.join(System.get_env("MIX_BUILD_ROOT", "_build"), "test")

path = Path.join([build, "lib", "logex", ".mix", ".mix_test_failures"])

case File.read(path) do
  {:ok, binary} ->
    {_version, failures} = :erlang.binary_to_term(binary)

    for {{module, name}, file} <- Enum.sort(failures) do
      IO.puts("#{Path.relative_to_cwd(file)}: #{inspect(module)}: #{name}")
    end

  {:error, :enoent} ->
    :ok
end
