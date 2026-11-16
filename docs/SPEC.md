# DOC-1: the pages (decisions 546-548)

Sources for every page: the seven inventories of README at `0793a86`, `inv/inv_A.md` to
`inv/inv_G.md` beside this file. Each inventory section lists its units (lines, gist, kind,
destination page), its example blocks, the rules it states, its citations, the pictures that
would help, its glossary words and its hardest sentences. A writer finds a page's material
with `grep -n '<slug>' inv/inv_*.md`, then reads those sections and the README lines they name.

Ranges: A 1-349 (introduction, the dialect, the instruction table). B 350-480 and 5674-5824
(what has landed; what logex is not; running it; documents). C 481-1245 (motor, timers,
counters, arithmetic, integer widths). D 1246-2689 (bit strings, reals, arrays, pulse coils,
jump, function blocks, arrays of instances, retained values). E 2690-3773 (configuration
file, from Elixir data, globals, retained global, the store on disk). F 3774-4732 (event
task, watchdogs, the runner). G 4733-5673 (located array, device adapter, online edits).

Files: user pages are `guides/<kind>/<name>.md`; contributor pages `docs/architecture/`,
`docs/implementation/`, `docs/contributing/`; decision records `docs/adr/NNNN-<name>.md`.
A page may be split in two if it passes its size; say so in the report.

## Tutorials (`guides/tutorials/`) — for a reader new to logex

| File | Job | Examples it carries |
|---|---|---|
| `first-program.md` | Write a motor start/stop program, compile it, run 5 scans, read the outputs. Shows a rung as text and as a drawing. | motor.ld, scan.exs |
| `timers-and-counters.md` | Add an on-delay timer and a box counter to a conveyor; see time given by the host. Timing diagram for each. | delay.*, boxes.* (the first timer and counter examples) |
| `first-plant.md` | Put two programs on tasks in a configuration file, wire a simulated device, run it with the runner on the manual clock. | plant/packing files, on_the_clock.exs |
| `change-a-running-program.md` | Change a running program with an online edit, step by step, and see that state is kept. | edit.exs, motor_v2.ld |

## How-to guides (`guides/howto/`) — one task each

install-and-run; read-diagnostics; use-timers; use-counters; do-arithmetic;
choose-integer-widths-and-convert; use-bit-strings; use-reals; use-arrays;
use-arrays-of-instances; use-one-shots-and-pulse-coils; jump-over-rungs;
write-a-function-block; keep-values-across-a-restart; write-a-configuration-file;
build-a-configuration-from-elixir; share-a-global; use-an-event-task; set-watchdogs;
run-on-the-clock; test-on-the-manual-clock; watch-a-runner; force-inputs;
keep-values-on-disk; recover-a-refused-store; edit-the-store-by-hand; take-back-a-deploy;
map-io-points; write-a-device-adapter; edit-a-running-program; edit-a-running-plant;
restart-after-a-trip; port-a-program (from Logix or IEC 61131-3: what behaves differently).

## Reference (`guides/reference/`) — exact rules

| File | Holds |
|---|---|
| `source-syntax.md` | A program file's text: lines, rungs, branches, names, dots, bits and subscripts, case, reserved words, comments, file kinds |
| `declarations-and-types.md` | Sections, qualifiers, elementary types and their ranges, arrays, instances, initial values, widening |
| `literals.md` | Integers, based integers, reals, what fits which slot |
| `instructions.md` (may split by family: `instructions-*.md`) | Every instruction, the same sub-headings for each: operands, true rung, false rung, power out, faults, diagnostics, example |
| `conversions.md` | The 182 typed conversions and the truncations: tables |
| `function-blocks.md` | Built-in timer and counter types and members; a user block's file; `cal`; arrays of instances |
| `configuration-file.md` | A `.logex` file: every word, its grammar, its rules; the same from Elixir data |
| `execution-model.md` | A scan, power flow, a cycle, tasks, order, time, the first scan |
| `faults.md` | Minor and major faults: each one, its cause, what the scan and the runner do |
| `diagnostics.md` | Compile errors: how they are shaped and located; the families of message |
| `warnings.md` | Every warning, with the "two writes" warnings in one place |
| `online-edit.md` | The steps, what an edit keeps and starts again, the refusals, every report kind |
| `runner.md` | Options, a round, devices, status keys, events, watchdogs, the trip, restart |
| `forcing.md` | Input forcing and the forces file |
| `retained-values-and-store.md` | `retain`, warm and cold restart, the retained image, the store file's format and versions, each refusal and each copy |
| `io-adapters.md` | The adapter behaviour, points, addresses, the simulated device |
| `host-contract.md` | The modules a host calls, what each rejects and how |
| `not-supported.md` | What logex does not have, as a look-up list |
| `glossary.md` | Every technical word, with the IEC and Logix word for the same thing |
| `cheatsheet.cheatmd` | The instruction set on one page |

## Explanation (`guides/explanation/`) — the model and the reasons

what-logex-is; safety-and-limits (what logex is not: every limit kept as strong as it is);
the-dialect-and-iec (why its own dialect, how names were chosen, differences from Logix);
programs-as-data; scan-cycle-and-time; tasks-and-scheduling; trips-and-watchdogs;
warm-and-cold-restarts; online-edit-model; types-and-overflow; timing-and-capacity.

## Contributor pages

| File | Holds |
|---|---|
| `docs/README.md` | A map of every document: what it is for and who reads it |
| `docs/style-guide.md` | The writing rules (from STYLE.md), the glossary's rule, how the checker and the picture scripts work |
| `docs/architecture/overview.md` | The parts and how data moves through them, with diagrams |
| `docs/architecture/compile-pipeline.md` | Lexer, parser, AST, compiler stages, IR, program |
| `docs/architecture/runtime-and-evaluator.md` | Instances, the evaluator, scans, resources and the scheduler |
| `docs/architecture/runner.md` | The runner's processes, a round, devices, writer, paths |
| `docs/architecture/online-edit.md` | Plans, the switch, state across an edit |
| `docs/architecture/store-and-files.md` | The retained image, the store's text, atomic writes, refusals |
| `docs/implementation/testing-strategy.md` | Verify by executing: oracles, walks, mutation tables, cost in reductions, load runs |
| `docs/implementation/adding-an-instruction.md` | The naming survey and the steps |
| `docs/contributing/toolchain.md` | The pinned versions, nix, asdf, the gates, CI |
| `docs/contributing/project-history.md` | What has landed: milestones and the review, moved from README |
| `docs/adr/README.md` + about 20 records | The curated decision records (decision 547) |

## README.md

A first page of at most about 120 lines: what logex is in three sentences, the safety
warning, one small program with its drawing and its output (run by the suite), how to
install and run, a table of where to go next (the four kinds of page, by reader), the
project's status in two lines, licence.
