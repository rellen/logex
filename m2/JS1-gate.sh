#!/bin/bash
source /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/toolchain/env.sh
cd "$1"
mix format --check-formatted; echo "FORMAT_EXIT=$?"
mix compile --force --warnings-as-errors >/dev/null 2>&1; echo "COMPILE_EXIT=$?"
MIX_ENV=test mix compile --force --warnings-as-errors >/dev/null 2>&1; echo "TESTCOMPILE_EXIT=$?"
mix test --warnings-as-errors 2>&1 | tail -15; echo "TEST_EXIT=${PIPESTATUS[0]}"
