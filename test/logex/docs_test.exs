defmodule Logex.DocsTest do
  @moduledoc """
  The documentation's build (decisions 546 and 548). ExDoc is a dependency of the `docs`
  environment alone: in every other one `mix.exs` gives no dependency, so that `mix
  compile`, `mix format` and `mix test` read no entry, ask for no Hex and fetch nothing,
  which a `mix` started with an empty home, no Hex in it, shows; and `mix.lock` names
  ExDoc and what ExDoc needs, nothing else.
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

  # `mix`, run in the project with a home that holds nothing, no Hex among it, and a build
  # path of the test's own: what it prints and its exit code.
  defp mix(dir, env, args) do
    home = Path.join(dir, "home")
    File.mkdir_p!(home)

    System.cmd(@elixir, [Path.join(Path.dirname(@elixir), "mix") | args],
      cd: @root,
      stderr_to_stdout: true,
      env: [
        {"MIX_ENV", env},
        {"MIX_HOME", home},
        {"HEX_HOME", Path.join(home, "hex")},
        {"MIX_BUILD_PATH", Path.join([dir, "build", env])}
      ]
    )
  end

  describe "ExDoc, a dependency of the docs environment alone" do
    # The trap a trial found: an entry `only: :docs` is still read in every environment,
    # and Mix needs Hex to read it, so that a bare toolchain's `mix compile` stops and
    # asks for Hex. Here Mix reads the project with no Hex to ask, in each environment a
    # gate or a host runs, and is given no entry.
    test "mix.exs gives no dependency in dev, test or prod, read by a mix with no Hex",
         %{tmp_dir: dir} do
      show = [
        "run",
        "--no-compile",
        "--no-start",
        "-e",
        "IO.inspect(Mix.Project.config()[:deps])"
      ]

      for env <- ["dev", "test", "prod"],
          do: assert({env, mix(dir, env, show)} == {env, {"[]\n", 0}})
    end

    test "the suite's own environment has none, and `mix docs` runs in docs" do
      assert Mix.Project.config()[:deps] == []
      assert Mix.Project.get!().cli() == [preferred_envs: [docs: :docs]]
    end

    test "mix.lock, committed, names ExDoc and what ExDoc needs, nothing else" do
      # Mix writes each package's name quoted, which the tokenizer warns of.
      {lock, _} =
        @root
        |> Path.join("mix.lock")
        |> File.read!()
        |> Code.string_to_quoted!(emit_warnings: false)
        |> Code.eval_quoted()

      assert {:hex, :ex_doc, _version, _, _, _, "hexpm", _} = lock[:ex_doc]
      assert Enum.sort(Map.keys(lock)) == Enum.sort(needed([:ex_doc], lock, []))
    end
  end

  # Each package the lock says `names` need, optional ones the lock does not hold left out.
  defp needed([], _lock, seen), do: seen

  defp needed([name | rest], lock, seen),
    do: needed(rest ++ (requires(lock[name]) -- [name | seen]), lock, Enum.uniq([name | seen]))

  defp requires(nil), do: []

  defp requires(entry),
    do: for({name, _requirement, options} <- elem(entry, 5), not options[:optional], do: name)
end
