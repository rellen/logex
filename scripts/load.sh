#!/usr/bin/env bash
# scripts/load.sh [-n runs] [-l loops] [mix test args]: runs `mix test` with the given
# arguments `runs` times (10 unless given) while `loops` busy loops (one a core unless
# given, `nproc`) hold the machine's cores, as CONTRIBUTING.md asks of a new real-clock
# or runner test before it lands, and prints a line a run, its exit code, ExUnit's
# Result line and the tests ExUnit's failures manifest names (scripts/failed.exs), and
# then how many runs failed. The busy loops stop when it ends, or is interrupted. Each
# run's log is kept as `_build/load/<n>.log`.
#
#     scripts/load.sh -n 50 test/logex/runner_test.exs
#     scripts/load.sh -n 6 -l 3 --seed 0
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
runs=10
loops=$(nproc 2>/dev/null || echo 4)
while [ $# -gt 0 ]; do
  case "$1" in
    -n) runs=$2; shift 2 ;;
    -l) loops=$2; shift 2 ;;
    *) break ;;
  esac
done
cd "$root" || exit 1
mkdir -p _build/load
MIX_ENV=test mix compile > /dev/null 2>&1 || { echo "the test build does not compile" >&2; exit 1; }
pids=()
stop() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done; }
trap 'stop' EXIT
trap 'exit 130' INT TERM
for _ in $(seq 1 "$loops"); do ( while :; do :; done ) & pids+=($!); done
manifest=_build/test/lib/logex/.mix/.mix_test_failures
failures=0
for n in $(seq 1 "$runs"); do
  rm -f "$manifest"
  mix test "$@" > "_build/load/$n.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] || failures=$((failures + 1))
  echo "run $n rc=$rc $(grep -E '^Result' "_build/load/$n.log" | tail -1) $(elixir scripts/failed.exs | tr '\n' ' ')"
done
echo "$failures of $runs runs failed, under $loops busy loops"
[ "$failures" -eq 0 ]
