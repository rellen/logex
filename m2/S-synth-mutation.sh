#!/bin/bash
# Runs the S-synth mutation table with three workers and merges their results.
cd /tmp/claude-0/-home-user-logex/f07aea59-53a1-5b8d-b560-6e6d2e330709/scratchpad/m2
rm -rf S-synth-probe/mutcopy-*
python3 S-synth-mutation.py 0 3 > S-synth-probe/mut-0.jsonl 2> S-synth-probe/mut-0.err &
python3 S-synth-mutation.py 1 3 > S-synth-probe/mut-1.jsonl 2> S-synth-probe/mut-1.err &
python3 S-synth-mutation.py 2 3 > S-synth-probe/mut-2.jsonl 2> S-synth-probe/mut-2.err &
wait
cat S-synth-probe/mut-0.jsonl S-synth-probe/mut-1.jsonl S-synth-probe/mut-2.jsonl > S-synth-mutation.jsonl
echo merged
