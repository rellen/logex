#!/bin/bash
# The gate, judged by exit code. Usage: F-synth-gate.sh <copy>
source /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/toolchain/env.sh
cd "$1" || exit 9
mix format --check-formatted; a=$?; echo "format exit $a"
mix compile --force --warnings-as-errors >/dev/null 2>&1; b=$?; echo "compile exit $b"
MIX_ENV=test mix compile --force --warnings-as-errors >/dev/null 2>&1; c=$?; echo "test compile exit $c"
mix test --warnings-as-errors 2>&1 | tail -n 40 > /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2/F-synth-lasttest.log; d=${PIPESTATUS[0]}
grep -E 'Result:|passed|failure' /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2/F-synth-lasttest.log | tail -3
echo "test exit $d"
[ $a -eq 0 ] && [ $b -eq 0 ] && [ $c -eq 0 ] && [ $d -eq 0 ]
