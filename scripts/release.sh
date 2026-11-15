#!/usr/bin/env bash
# scripts/release.sh [--dry-run] [--push]: the release step (decision 515 (b);
# CONTRIBUTING.md, "Releasing"), before any publish. It tags the commit checked out as
# `vX.Y.Z`, the version mix.exs gives, once every check passes:
#
#   1. the tree is clean, nothing changed or untracked, so the tag names what was checked;
#   2. the commit is on origin's `main`, fetched now, so a tag never names a commit that
#      only this checkout holds;
#   3. CI has run on the commit, and every run of `.github/workflows/ci.yml` on it has
#      concluded `success`, read through GitHub's CLI, `gh api`, signed in, for the
#      repository gh takes from GH_REPO or this checkout's remotes;
#   4. CHANGELOG.md's newest entry is the release `## X.Y.Z — YYYY-MM-DD`, X.Y.Z mix.exs's
#      version, and every decision docs/organisation.md §7 records is named by an entry,
#      each once (`elixir scripts/changelog.exs --release`);
#   5. the tag is absent, here and on origin;
#   6. the gate is green (scripts/gate.sh, its log `_build/release-gate.log`).
#
# Each check runs whatever another found, and each refusal is a line `refused: ...`; any
# refusal tags nothing and exits 1. With every check passed it makes the annotated tag
# here, and with `--push` pushes it to origin too, in place of pushing it by hand; a run
# made after a plain one is refused, the tag being here, so a plain run's tag is pushed
# with the command it prints. A push that fails leaves the tag here, says so with that
# command, and exits 1. `--dry-run` runs every check, makes no tag and pushes nothing,
# and says what it would tag and whether it would push; it exits as the release would.
# Run from anywhere in the checkout.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
dry=0
push=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --push) push=1 ;;
    *) echo "usage: scripts/release.sh [--dry-run] [--push]" >&2; exit 2 ;;
  esac
done
cd "$root" || exit 1
refused=0
refuse() { echo "refused: $*"; refused=1; }
head=$(git rev-parse HEAD) || exit 1

echo "release: the tree at $head"
dirty=$(git status --porcelain)
[ -z "$dirty" ] || refuse "the tree is not clean, so a tag would not name what was checked: $(echo "$dirty" | head -5 | tr '\n' ';' | sed 's/;$//')"

echo "release: origin's main, fetched now"
git fetch -q origin main 2> /dev/null
rc=$?
case "$rc" in
  0) git merge-base --is-ancestor "$head" FETCH_HEAD || refuse "the commit $head is not on origin's main, $(git rev-parse FETCH_HEAD): push it to main, and read CI's run on it, first" ;;
  *) refuse "origin's main cannot be fetched (git fetch exited $rc)" ;;
esac

echo "release: CI's runs on $head (gh api)"
runs=$(gh api "repos/{owner}/{repo}/actions/runs?head_sha=$head&per_page=100" \
  --jq '.workflow_runs[] | select(.path == ".github/workflows/ci.yml") | "\(.id) \(.status) \(.conclusion)"' 2>&1)
rc=$?
case "$rc" in
  0)
    [ -n "$runs" ] || refuse "CI has no run on $head: push it to main, and wait for its run"
    while read -r id status conclusion; do
      [ "$status $conclusion" = "completed success" ] || refuse "CI's run $id on $head has not passed: $status, $conclusion"
    done <<< "$runs"
    ;;
  *) refuse "CI's runs on $head cannot be read (gh api exited $rc): $(echo "$runs" | head -1)" ;;
esac

echo "release: CHANGELOG.md, docs/organisation.md §7 and mix.exs"
version=$(elixir scripts/changelog.exs --release) || refuse "CHANGELOG.md does not name this release (above)"
tag=""
[ -n "$version" ] && tag="v$version"

if [ -n "$tag" ]; then
  echo "release: the tag $tag, here and on origin"
  git rev-parse -q --verify "refs/tags/$tag" > /dev/null && refuse "the tag $tag is here already, at $(git rev-parse "refs/tags/$tag^{commit}")"
  git ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null 2>&1
  rc=$?
  case "$rc" in
    0) refuse "origin has the tag $tag already" ;;
    2) ;;
    *) refuse "origin's tags cannot be read (git ls-remote exited $rc)" ;;
  esac
fi

echo "release: the gate (scripts/gate.sh)"
bash scripts/gate.sh "$root/_build/release-gate.log" || refuse "the gate is red (its log _build/release-gate.log)"

if [ "$refused" -ne 0 ]; then
  echo "release: refused; nothing tagged, nothing pushed"
  exit 1
fi
if [ "$dry" -eq 1 ]; then
  echo "release: every check passed; a dry run, so nothing tagged and nothing pushed"
  echo "release: would tag $tag at $head, annotated \"logex $version\""
  [ "$push" -eq 1 ] && echo "release: would push $tag to origin" || echo "release: would not push $tag (no --push)"
  exit 0
fi
git tag -a "$tag" -m "logex $version" "$head" || exit 1
echo "release: tagged $tag at $head"
if [ "$push" -eq 1 ]; then
  git push origin "refs/tags/$tag" || {
    echo "release: $tag is here and the push failed; push it with: git push origin refs/tags/$tag"
    exit 1
  }
  echo "release: pushed $tag to origin"
else
  echo "release: $tag not pushed; push it with: git push origin refs/tags/$tag"
fi
