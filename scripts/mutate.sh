#!/usr/bin/env bash
# scripts/mutate.sh [-t test_file]... [-N] patch...: a mutation table. For each patch in turn
# it applies the patch to the working tree (`git apply`), runs the named test files, if
# any, and then the full suite, each judged by its exit code, restores the tree
# (`git apply -R`, also on an interrupt), and prints a row of a Markdown table:
#
#     | patch | named files | full suite | failed tests |
#
# each suite's cell its exit code and ExUnit's Result line, and the failed tests those
# ExUnit's failures manifest names after the full suite (scripts/failed.exs), one file a
# test with the count of its failures. A mutant that survives, exit code 0 in the full
# suite, is marked SURVIVED. A patch is made with `git diff > x.patch` from an edited
# tree, which is then restored before the run; the tree the patches apply to must hold no
# other change to the files they touch. Each run's log is kept beside the patch,
# `<patch>.named.log` and `<patch>.full.log`. `-N` runs the named files alone, the full
# suite's cell left `-`, for a quick look; a mutant counts only by the full suite.
# Arguments after `--` go to every `mix test`, `--seed 0` for one.
#
# A mutant red only on a real-clock test, or under a loaded machine, is run again alone
# before it counts (CONTRIBUTING.md, "A fix needs a test that fails when the fix is
# reverted").
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
named=()
full=1
while [ $# -gt 0 ]; do
  case "$1" in
    -t) named+=("$2"); shift 2 ;;
    -N) full=0; shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done
patches=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do patches+=("$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"); shift; done
[ $# -gt 0 ] && shift
extra=("$@")
[ ${#patches[@]} -gt 0 ] || { echo "usage: scripts/mutate.sh [-t test_file]... [-N] patch... [-- mix test args]" >&2; exit 2; }
cd "$root" || exit 1
manifest=_build/test/lib/logex/.mix/.mix_test_failures
applied=""
restore() { [ -n "$applied" ] && git apply -R "$applied" && applied=""; }
trap 'restore; exit 130' INT TERM

result() { grep -E '^Result' "$1" | tail -1; }

echo "| patch | named files | full suite | failed tests |"
echo "|---|---|---|---|"
for p in "${patches[@]}"; do
  if ! git apply --check "$p" 2>/dev/null; then
    echo "| $(basename "$p") | does not apply | | |"
    continue
  fi
  git apply "$p" && applied=$p
  cell_named="-"
  rm -f "$manifest"
  if [ ${#named[@]} -gt 0 ]; then
    mix test "${named[@]}" "${extra[@]}" > "$p.named.log" 2>&1
    cell_named="rc=$? $(result "$p.named.log")"
  fi
  cell_full="-"
  if [ "$full" -eq 1 ]; then
    rm -f "$manifest"
    mix test "${extra[@]}" > "$p.full.log" 2>&1
    rc=$?
    cell_full="rc=$rc $(result "$p.full.log")"
    [ "$rc" -eq 0 ] && cell_full="$cell_full SURVIVED"
  fi
  failed=$(elixir scripts/failed.exs | cut -d: -f1 | sort | uniq -c | awk '{printf "%s%s (%s)", sep, $2, $1; sep=", "}')
  restore
  echo "| $(basename "$p") | $cell_named | $cell_full | $failed |"
done
