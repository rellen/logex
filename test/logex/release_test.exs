defmodule Logex.ReleaseTest do
  @moduledoc """
  The release step (decision 515 (b), `CONTRIBUTING.md`'s "Releasing"), checked as the gate
  is, by running it: `scripts/changelog.exs` on CHANGELOG.md as it stands, every decision
  `docs/organisation.md` §7 records named by an entry, each once; on changelogs of every
  shape it refuses; and `scripts/release.sh` in a scratch repository of its own, with a
  mix.exs, a changelog, a §7 of three decisions, a gate that stands in for the suite and
  an origin, a bare repository beside it: with every check passed it tags, pushes only
  when told, and a dry run does neither; and each check taken back in turn refuses, tagging
  and pushing nothing.
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

  # A committer the scratch repository's commits and tags are made by, and the `elixir` the
  # suite runs on first on the path.
  @env [
    {"GIT_AUTHOR_NAME", "logex"},
    {"GIT_AUTHOR_EMAIL", "logex@example.invalid"},
    {"GIT_COMMITTER_NAME", "logex"},
    {"GIT_COMMITTER_EMAIL", "logex@example.invalid"},
    {"GIT_CONFIG_GLOBAL", "/dev/null"},
    {"GIT_CONFIG_NOSYSTEM", "1"}
  ]

  defp env(extra) do
    path = Enum.join([Path.dirname(@elixir), System.get_env("PATH")], ":")
    [{"PATH", path} | @env] ++ extra
  end

  defp changelog(dir, args \\ []) do
    System.cmd(@elixir, [Path.join(@root, "scripts/changelog.exs") | args],
      cd: dir,
      env: env([]),
      stderr_to_stdout: true
    )
  end

  defp git(dir, args) do
    {out, 0} = System.cmd("git", args, cd: dir, env: env([]), stderr_to_stdout: true)
    String.trim(out)
  end

  @mix_exs """
  defmodule Scratch.MixProject do
    use Mix.Project

    def project, do: [app: :logex, version: "0.2.0"]
  end
  """

  @changelog """
  # Changelog

  The head, which names `## 9.9.9 — 2026-01-01` and `Decisions: 7.` in its prose.

  ## 0.2.0 — 2026-11-20

  Decisions: 2–3.

  - What it carries.

  ## 0.1.0 — 2026-10-01

  Decisions: 1.
  """

  @organisation """
  # Program organisation

  ## 6. The road

  1. **Not a decision: §6's list.**

  ## 7. Decisions

  1. **The first.** Taken.
  2. **The second.**
     Taken.
  3. **The third.** Taken.

  ## 8. Sources

  4. **Not a decision: §8's list.**
  """

  # A scratch repository holding the two scripts as committed here, a gate that prints and
  # exits as `GATE_RC` says, mix.exs, CHANGELOG.md and docs/organisation.md, each as given
  # or else as above, all committed, its origin a bare repository beside it.
  defp scratch(dir, files \\ %{}) do
    File.mkdir_p!(dir)
    repo = Path.join(dir, "repo")
    origin = Path.join(dir, "origin.git")
    File.mkdir_p!(Path.join(repo, "scripts"))
    File.mkdir_p!(Path.join(repo, "docs"))
    git(dir, ["init", "-q", "--bare", origin])

    for script <- ["release.sh", "changelog.exs"] do
      File.cp!(Path.join(@root, "scripts/#{script}"), Path.join(repo, "scripts/#{script}"))
    end

    gate = """
    #!/usr/bin/env bash
    rc=${GATE_RC:-0}
    echo "gate: log $1"
    [ "$rc" -eq 0 ] && echo GATE-OK || echo "GATE-FAIL rc=$rc"
    exit "$rc"
    """

    defaults = %{
      "scripts/gate.sh" => gate,
      "mix.exs" => @mix_exs,
      "CHANGELOG.md" => @changelog,
      "docs/organisation.md" => @organisation
    }

    for {path, text} <- Map.merge(defaults, files), do: File.write!(Path.join(repo, path), text)
    git(repo, ["init", "-q", "-b", "main"])
    git(repo, ["add", "-A"])
    git(repo, ["commit", "-q", "-m", "scratch"])
    git(repo, ["remote", "add", "origin", origin])
    {repo, origin}
  end

  defp release(repo, args, extra \\ []) do
    System.cmd("bash", ["scripts/release.sh" | args],
      cd: repo,
      env: env(extra),
      stderr_to_stdout: true
    )
  end

  defp tags(dir), do: git(dir, ["tag", "--list"])

  # What a run that reaches every check prints before its verdict, the gate passed.
  defp checked(repo, gate \\ "GATE-OK") do
    "release: the tree at #{git(repo, ["rev-parse", "HEAD"])}\n" <>
      "release: CHANGELOG.md, docs/organisation.md §7 and mix.exs\n" <>
      "release: the tag v0.2.0, here and on origin\n" <>
      "release: the gate (scripts/gate.sh)\n" <>
      "gate: log #{repo}/_build/release-gate.log\n#{gate}\n"
  end

  describe "scripts/changelog.exs" do
    test "CHANGELOG.md names every decision §7 records, each once, read as its head says" do
      {out, code} = changelog(@root)

      assert {code, out =~ ~r/\Achangelog: every decision of §7, [0-9–, ]+, named once\n\z/u} ==
               {0, true}
    end

    test "it names the decisions of §7 alone, and gives the newest release's version",
         %{tmp_dir: dir} do
      {repo, _} = scratch(dir)
      assert changelog(repo) == {"changelog: every decision of §7, 1–3, named once\n", 0}
      assert changelog(repo, ["--release"]) == {"0.2.0\n", 0}
    end

    test "it refuses every shape a changelog may be wrong in, each a line, and exits 1",
         %{tmp_dir: dir} do
      {repo, _} =
        scratch(dir, %{
          "CHANGELOG.md" => """
          # Changelog

          ## 0.3.0 — 2026-12-01

          Decisions: 3, 3–2, 5, x.

          ## Unreleased

          Decisions: none.

          ## 0.2.0 — 2026-13-01

          The first line, not the decisions.

          ## 0.2.0 — 2026-11-01

          Decisions: 1, 3.

          ## version 0.1.0

          Decisions: 1.
          """
        })

      assert changelog(repo) ==
               {"changelog: line 5: the range `3–2` does not rise\n" <>
                  "changelog: line 5: `x` is neither a decision's number nor a range `N–M`\n" <>
                  "changelog: line 11: `2026-13-01` is no date, in `## 0.2.0 — 2026-13-01`\n" <>
                  "changelog: line 13: the entry's first line is not `Decisions: ` and the " <>
                  "decisions it carries, `1–14, 30.`, or `none.`: \"The first line, not the " <>
                  "decisions.\"\n" <>
                  "changelog: line 19: an entry's heading is `## X.Y.Z — YYYY-MM-DD` or " <>
                  "`## Unreleased`, not `## version 0.1.0`\n" <>
                  "changelog: line 7: `## Unreleased` stands above the newest release, not " <>
                  "below it\n" <>
                  "changelog: version 0.2.0 heads two entries, at lines 11 and 15\n" <>
                  "changelog: decision 1 is named twice, by the entries at lines 17 and 21\n" <>
                  "changelog: decision 3 is named twice, by the entries at lines 5 and 17\n" <>
                  "changelog: decision 2 is recorded in §7 and named by no entry\n" <>
                  "changelog: decision 5 is named by an entry and recorded nowhere in §7\n", 1}
    end

    test "with --release it refuses an Unreleased newest entry and a version not mix.exs's",
         %{tmp_dir: dir} do
      unreleased = String.replace(@changelog, "## 0.2.0 — 2026-11-20", "## Unreleased")
      {repo, _} = scratch(Path.join(dir, "a"), %{"CHANGELOG.md" => unreleased})

      assert changelog(repo, ["--release"]) ==
               {"changelog: line 5: the newest entry is `## Unreleased`; a release names its " <>
                  "version and date, `## X.Y.Z — YYYY-MM-DD`, the version mix.exs's\n", 1}

      assert changelog(repo) == {"changelog: every decision of §7, 1–3, named once\n", 0}

      {repo, _} =
        scratch(Path.join(dir, "b"), %{"mix.exs" => String.replace(@mix_exs, "0.2.0", "0.2.1")})

      assert changelog(repo, ["--release"]) ==
               {"changelog: line 5: the newest entry is 0.2.0, and mix.exs's version is " <>
                  "0.2.1\n", 1}
    end
  end

  describe "scripts/release.sh" do
    test "with every check passed, a dry run tags nothing and pushes nothing, and says what " <>
           "it would",
         %{tmp_dir: dir} do
      {repo, origin} = scratch(dir)
      head = git(repo, ["rev-parse", "HEAD"])

      assert release(repo, ["--dry-run"]) ==
               {checked(repo) <>
                  "release: every check passed; a dry run, so nothing tagged and nothing " <>
                  "pushed\n" <>
                  "release: would tag v0.2.0 at #{head}, annotated \"logex 0.2.0\"\n" <>
                  "release: would not push v0.2.0 (no --push)\n", 0}

      assert {_, 0} = release(repo, ["--dry-run", "--push"])
      assert {tags(repo), tags(origin)} == {"", ""}
    end

    test "with every check passed, it makes the annotated tag here, and pushes it only with " <>
           "--push",
         %{tmp_dir: dir} do
      {repo, origin} = scratch(Path.join(dir, "a"))
      head = git(repo, ["rev-parse", "HEAD"])

      assert release(repo, []) ==
               {checked(repo) <>
                  "release: tagged v0.2.0 at #{head}\n" <>
                  "release: v0.2.0 not pushed; push it with: git push origin " <>
                  "refs/tags/v0.2.0\n", 0}

      assert {tags(repo), tags(origin)} == {"v0.2.0", ""}
      assert git(repo, ["rev-parse", "v0.2.0^{commit}"]) == head

      assert git(repo, ["tag", "-l", "--format=%(objecttype) %(contents:subject)"]) ==
               "tag logex 0.2.0"

      {repo, origin} = scratch(Path.join(dir, "b"))
      assert {out, 0} = release(repo, ["--push"])
      assert out =~ "release: pushed v0.2.0 to origin\n"
      assert {tags(repo), tags(origin)} == {"v0.2.0", "v0.2.0"}
      assert git(origin, ["rev-parse", "v0.2.0^{commit}"]) == git(repo, ["rev-parse", "HEAD"])
    end

    # Each check taken back in turn: the scratch made wrong in one way, the refusal its
    # check gives, and nothing tagged or pushed, a dry run or not.
    test "a tree not clean is refused", %{tmp_dir: dir} do
      {repo, origin} = scratch(dir)
      File.write!(Path.join(repo, "stray.txt"), "")
      File.write!(Path.join(repo, "mix.exs"), @mix_exs <> "\n")

      assert_refused(repo, origin, [], [
        "refused: the tree is not clean, so a tag would not name what was checked:  M mix.exs;?? stray.txt"
      ])
    end

    test "a changelog that does not name the release is refused, its own refusal above",
         %{tmp_dir: dir} do
      {repo, origin} = scratch(dir, %{"mix.exs" => String.replace(@mix_exs, "0.2.0", "0.3.0")})

      assert_refused(repo, origin, [], [
        "changelog: line 5: the newest entry is 0.2.0, and mix.exs's version is 0.3.0",
        "refused: CHANGELOG.md does not name this release (above)"
      ])
    end

    test "a decision §7 records and no entry names is refused", %{tmp_dir: dir} do
      organisation = String.replace(@organisation, "\n## 8.", "4. **The fourth.**\n\n## 8.")
      {repo, origin} = scratch(dir, %{"docs/organisation.md" => organisation})

      assert_refused(repo, origin, [], [
        "changelog: decision 4 is recorded in §7 and named by no entry",
        "refused: CHANGELOG.md does not name this release (above)"
      ])
    end

    test "a tag here already is refused", %{tmp_dir: dir} do
      {repo, origin} = scratch(dir)
      git(repo, ["tag", "v0.2.0"])
      head = git(repo, ["rev-parse", "HEAD"])

      assert_refused(repo, origin, [], [
        "refused: the tag v0.2.0 is here already, at #{head}"
      ])
    end

    test "a tag on origin already is refused, and so is an origin whose tags cannot be read",
         %{tmp_dir: dir} do
      {repo, origin} = scratch(Path.join(dir, "a"))
      git(repo, ["tag", "v0.2.0"])
      git(repo, ["push", "-q", "origin", "refs/tags/v0.2.0"])
      git(repo, ["tag", "-d", "v0.2.0"])
      assert_refused(repo, origin, [], ["refused: origin has the tag v0.2.0 already"])

      {repo, _} = scratch(Path.join(dir, "b"))
      git(repo, ["remote", "set-url", "origin", Path.join(dir, "nowhere.git")])

      assert_refused(repo, nil, [], [
        "refused: origin's tags cannot be read (git ls-remote exited 128)"
      ])
    end

    test "a red gate is refused", %{tmp_dir: dir} do
      {repo, origin} = scratch(dir)

      assert_refused(repo, origin, [{"GATE_RC", "1"}], [
        "GATE-FAIL rc=1",
        "refused: the gate is red (its log _build/release-gate.log)"
      ])
    end
  end

  # A release refused, a dry run or not: each line given is in what it printed, in order,
  # the last line says nothing was tagged or pushed, it exits 1, and no tag was made here
  # or on origin.
  defp assert_refused(repo, origin, extra, lines) do
    before = {tags(repo), origin && tags(origin)}

    for args <- [["--dry-run"], ["--push"]] do
      {out, code} = release(repo, args, extra)
      printed = String.split(out, "\n", trim: true)
      assert {code, List.last(printed)} == {1, "release: refused; nothing tagged, nothing pushed"}
      assert Enum.filter(printed, &(&1 in lines)) == lines, out
      assert {tags(repo), origin && tags(origin)} == before
    end
  end
end
