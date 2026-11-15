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
# and then GATE-OK or GATE-FAIL with the exit code, and exits with that code. The suite
# is judged by `elixir scripts/failed.exs --exit`, as CI's test step judges it, ExUnit's
# failures manifest deleted before it runs: a red suite is followed by the tests that
# failed, `file:line: Module: test name`, so that the failure is named even where the log
# is too long to read, or by why none is named; and a suite that exits 0 with no manifest
# written, one a test halted, is red, GATE-FAIL rc=1. Arguments after the log go to
# `mix test`, `--seed 0` for one.
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
    MIX_ENV=test mix compile --force --warnings-as-errors
} > "$log" 2>&1
rc=$?
named=""
if [ "$rc" -eq 0 ]; then
  mix test --warnings-as-errors "$@" >> "$log" 2>&1
  rc=$?
  named=$(elixir scripts/failed.exs --exit "$rc")
  rc=$?
fi
tail -5 "$log"
if [ "$rc" -eq 0 ]; then
  echo GATE-OK
else
  echo "GATE-FAIL rc=$rc"
  [ -z "$named" ] || echo "$named"
fi
exit "$rc"
