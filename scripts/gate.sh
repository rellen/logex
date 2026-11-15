#!/usr/bin/env bash
# scripts/gate.sh [log]: the five gates of CONTRIBUTING.md's "Before you commit", in
# order, each judged by its exit code, the first that fails stopping the rest:
#
#     mix format --check-formatted
#     mix compile --force --warnings-as-errors
#     MIX_ENV=test mix compile --force --warnings-as-errors
#     mix test --warnings-as-errors [args]
#     scripts/dialyzer.sh
#
# It runs from the project's root wherever it is called from, writes everything the
# gates print to the log (`_build/gate.log` unless given), prints the log's last lines
# and then GATE-OK or GATE-FAIL with the exit code, and exits with that code. The suite
# is judged by `elixir scripts/failed.exs --exit`, as CI's test step judges it, ExUnit's
# failures manifest deleted before it runs: a red suite is followed by the tests that
# failed, `file:line: Module: test name`, so that the failure is named even where the log
# is too long to read, or by why none is named; and a suite that exits 0 with no manifest
# written, one a test halted, is red, GATE-FAIL rc=1. Arguments after the log go to
# `mix test`, `--seed 0` for one. The fifth gate is OTP's own Dialyzer over the dev build
# (decision 549), the script CI's step after the suite runs, so that a spec the code
# breaks, or a call whose answer is thrown away, is seen before the commit: it runs once
# the suite is green, and a red one is GATE-FAIL with Dialyzer's code, 2 for a warning,
# followed by a line that names the step and the log, which keeps every warning Dialyzer
# printed.
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
step=""
if [ "$rc" -eq 0 ]; then
  bash scripts/dialyzer.sh >> "$log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] || step="scripts/dialyzer.sh exited $rc, the gate's fifth step: its warnings are in $log"
fi
tail -5 "$log"
if [ "$rc" -eq 0 ]; then
  echo GATE-OK
else
  echo "GATE-FAIL rc=$rc"
  [ -z "$named" ] || echo "$named"
  [ -z "$step" ] || echo "$step"
fi
exit "$rc"
