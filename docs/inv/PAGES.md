# Provisional page list (slugs) for the new documentation

User docs, built with ExDoc, organised by Diataxis.

## Tutorials (learning by doing, one safe path, a result at every step)
- tutorials/first-program — a motor start/stop program: write it, compile it, run scans
- tutorials/timers-and-counters — a delay and a box counter
- tutorials/first-plant — a configuration file, two programs on tasks, a simulated device, the runner
- tutorials/change-a-running-program — an online edit, step by step

## How-to guides (one task each, for a reader who already knows the basics)
- howto/install-and-run
- howto/read-diagnostics
- howto/use-timers
- howto/use-counters
- howto/do-arithmetic
- howto/choose-integer-widths-and-convert
- howto/use-bit-strings
- howto/use-reals
- howto/use-arrays
- howto/use-one-shots-and-pulse-coils
- howto/jump-over-rungs
- howto/write-a-function-block
- howto/keep-values-across-a-restart
- howto/write-a-configuration-file
- howto/build-a-configuration-from-elixir
- howto/share-a-global
- howto/use-an-event-task
- howto/set-watchdogs
- howto/run-on-the-clock
- howto/force-inputs
- howto/keep-values-on-disk
- howto/recover-a-refused-store
- howto/map-io-points
- howto/write-a-device-adapter
- howto/edit-a-running-program
- howto/edit-a-running-plant
- howto/restart-after-a-trip

## Reference (exact rules, complete, dry)
- reference/source-syntax — a program file's text: lines, rungs, branches, names, case, reserved words
- reference/declarations-and-types — sections, qualifiers, elementary types, arrays, instances
- reference/literals — integers, based integers, reals, what fits where
- reference/instructions — every instruction: operands, what it does on a true rung and on a false rung, power out, faults
- reference/conversions — the typed conversions
- reference/function-blocks — a block's file, members, cal, built-in timers and counters
- reference/configuration-file — a .logex file's words and rules
- reference/execution-model — a scan, a cycle, tasks, rounds, order, time
- reference/faults — minor and major faults, what each does
- reference/diagnostics-and-warnings — compile errors and warnings
- reference/online-edit — steps, rules, report kinds
- reference/runner — options, status, events, watchdogs, the trip, restart
- reference/forcing — forces and the forces file
- reference/retained-values-and-store — retain rules, warm/cold restart, the store file format, refusals
- reference/io-adapters — the adapter behaviour, points, the simulated device
- reference/host-contract — which modules a host calls, what is refused and how
- reference/glossary
- reference/cheatsheet — instructions on one page

## Explanation (why, background, trade-offs)
- explanation/what-logex-is
- explanation/safety-and-limits — what logex is not
- explanation/the-dialect-and-iec — why its own dialect; how names were chosen
- explanation/programs-as-data — compiled to data and interpreted, not BEAM code
- explanation/scan-cycle-and-time — power flow, scans, time the host gives
- explanation/tasks-and-scheduling
- explanation/trips-and-watchdogs
- explanation/warm-and-cold-restarts
- explanation/online-edit-model
- explanation/types-and-overflow

## Contributor docs (docs/ in the repository)
- contributor/architecture-overview
- contributor/compile-pipeline
- contributor/runtime-and-evaluator
- contributor/runner-internals
- contributor/store-and-files
- contributor/testing-strategy
- contributor/toolchain — the pinned versions, nix, asdf, CI gates
- contributor/project-status-and-history — what has landed, milestones, the review
- adr/NNNN-title — architecture decision records for the large choices
