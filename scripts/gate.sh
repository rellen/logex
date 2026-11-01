#!/usr/bin/env bash
# scripts/gate.sh [log]: the four gates of CONTRIBUTING.md's "Before you commit", in
# order, each judged by its exit code, the first that fails stopping the rest:
#
#     mix format --check-formatted
#     mix compile --force --warnings-as-errors
#     MIX_ENV=test mix compile --force --warnings-as-errors
#     mix test --warnings-as-errors [args]
#
# It runs from the project's root wherever it is called from, writes everything the
# gates print to the log (`_build/gate.log` unless given), prints the log's last lines
# and then GATE-OK or GATE-FAIL with the exit code, and exits with that code. A failed
# suite is followed by the tests ExUnit's failures manifest names (scripts/failed.exs),
# so that the failure is named even where the log is too long to read. Arguments after
# the log go to `mix test`, `--seed 0` for one.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
log=${1:-$root/_build/gate.log}
shift $(( $# > 0 ? 1 : 0 ))
mkdir -p "$(dirname "$log")"
log=$(cd "$(dirname "$log")" && pwd)/$(basename "$log")
cd "$root" || exit 1
rm -f _build/test/lib/logex/.mix/.mix_test_failures
{
  mix format --check-formatted &&
    mix compile --force --warnings-as-errors &&
    MIX_ENV=test mix compile --force --warnings-as-errors &&
    mix test --warnings-as-errors "$@"
} > "$log" 2>&1
rc=$?
tail -5 "$log"
if [ "$rc" -eq 0 ]; then
  echo GATE-OK
else
  echo "GATE-FAIL rc=$rc"
  elixir scripts/failed.exs
fi
exit "$rc"
