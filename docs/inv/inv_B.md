# Inventory B: README.md lines 350-480 and 5674-5824

Scope: the project's status and history ("What has landed"), its limits ("What logex is
not"), its toolchain ("Running it"), its list of documents ("Documents") and "License".
Every line of both ranges was read. Line numbers are README.md's as it stood on 2026-11-15.

Conventions used below:

- "README (landing page)" as a destination means the short README that remains. It is not a
  slug in PAGES.md.
- "CHANGELOG" as a destination means the existing `CHANGELOG.md` (its "What no longer
  compiles" and "What changes a running program's outputs" items), not a new page.
- Checks made against the repository (read-only): `mix.exs`, `.tool-versions`, `flake.nix`,
  `shell.nix`, `flake.lock`, `PLAN.md` lines 28-42, `CHANGELOG.md` head, `lib/` (count of
  `@spec`), `test/logex/readme_test.exs` (`@fragments`), `CONTRIBUTING.md` headings. Beyond
  the headings asked for, I also read `CONTRIBUTING.md` lines 74-84, 256-275 and 573-612, to
  say exactly what "Running it" repeats.

Totals: 5 sections, 119 units (35 + 62 + 12 + 9 + 1), 0 example blocks of the kind the
suite runs, 1 plain fenced block.

---

## What has landed (lines 350-479, about 1,710 words; line 480 is blank)

**Reader and purpose.** A maintainer or returning contributor who wants to know which
milestones and review items are done and which wait. A user gets almost nothing from it as
written: it is a change log in prose, ordered newest first, and every feature it names is
described again, properly, in a later README section. It sits as a `###` under
`## Instructions` (line 287), which is the wrong place for it.

**Verdict by bullet (the extra asked for).**

| Bullet or paragraph | Lines | Does a user need any of it? |
|---|---|---|
| Opening paragraph: the review and its items RV-1 to RV-29 | 352-402 | Contributor history, with three user facts buried in it: (1) no release has been made, version `0.1.0`, `CHANGELOG.md` holds only `## Unreleased` (397-398) -> `howto/install-and-run` and README (landing page); (2) the store's format is `logex retain 3` and the stale-store warning names both causes and goes to subscribers (387-389) -> `reference/retained-values-and-store`; (3) there are no typespecs yet (401; `lib/` has 0 `@spec`) -> `reference/host-contract`. Every other outcome it lists (364-370, 376-396) is a rule already stated in a later section; check each is there, then drop the sentence here. |
| Second paragraph: Milestones 2 and 4 | 403-408 | One user fact: the runner adds only two words to the language, a task's `watchdog` and the `continuous` task (407-408) -> `reference/configuration-file`. The rest is contributor history. |
| Bullet 1: Milestone 6, retained values | 409-444 | Contributor history as a list. All its rules are user rules, but each is restated in "Retained values" (2553), "A retained global" (3089) and "The store on disk". Two user items must survive from here: the breaking change, `retain` and `non_retain` now reserved in programs and configuration files (419-425) -> CHANGELOG and `reference/source-syntax`; and "`persistent` is deferred and stays unreserved" (443) -> `explanation/safety-and-limits`. |
| Bullet 2: Milestone 5, data types | 445-470 | Contributor history as a list; a fair one-paragraph summary of the type system for `explanation/what-logex-is`. Two user items must survive: the behaviour change, an integer result past its type's limit now wraps with no power where a `dint` stopped at its limit before (465-467) -> CHANGELOG and `explanation/types-and-overflow`; and every type word and mnemonic reserved in any case, `real`, `int`, `word`, `byte`, `and`, `or`, `not` among them (467-468) -> `reference/source-syntax`. |
| Bullet 3: Milestone 3 | 471-479 | Mostly history, but it holds two limits that appear nowhere else in README (checked by grep): there is no `res` instruction, and there is no master control zone, "for good" (476-479). Both are user facts -> `explanation/safety-and-limits`, `reference/instructions`, `howto/use-counters`, `howto/use-timers`. The naming note (475-476) -> `explanation/the-dialect-and-iec`. |

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 352-354 | Status headline: every milestone decided has landed, retained values last; the whole-codebase review followed Milestone 6 | C | `contributor/project-status-and-history`; one sentence of it for README (landing page) |
| 354-360 | The review in figures: 27 reviewers at commit `d422608`, 203 findings, 13 refuted, 190 survived (12 high, 35 medium, 143 low), about 60 defects; where defects gathered and what held | C | `contributor/project-status-and-history`; the "where defects gathered" clause also `contributor/testing-strategy` |
| 360-362 | Eighteen items RV-1 to RV-7 and RV-9 to RV-19 built the answers, decisions 347-512 | C | `contributor/project-status-and-history` |
| 362-364 | Outcome: every source text compiles or is told why; a rung that writes nothing and jumps nowhere is refused at its line (decision 351) | R (dup) | `reference/diagnostics-and-warnings`, `reference/source-syntax`; drop here |
| 364-365 | Outcomes: a held output holds; a retained `tof` held on at the outage comes to rest | R (dup) | `reference/online-edit`; `reference/retained-values-and-store`; drop here |
| 365-367 | Outcomes: each device's write has its own limit; every file write and read of the runner limited by `write_limit:`; a hung device trips the line however late the runner, the runner's own lateness named as such | R (dup) | `reference/runner`, `explanation/trips-and-watchdogs`; drop here |
| 367-369 | Outcomes: a store cut short is refused; a fresh start that drops anything keeps a numbered copy of the store; two runners of one VM refused one file | R (dup) | `reference/retained-values-and-store`, `howto/recover-a-refused-store`; drop here |
| 369-370 | Outcomes: the runner's long work is cheaper, bounded and named when it trips; the suite's cost pins are bounds measured within the run | C | `contributor/runner-internals`; `contributor/testing-strategy` |
| 370-376 | The close, RV-8: 177 closed, 18 kept (the 13 refuted among them), 8 put as questions; answered 2026-11-12, decisions 513-521; review taken as done (521); follow-on RV-20 to RV-25 | C | `contributor/project-status-and-history` |
| 376-378 | RV-20 landed: refusal of many unknown names costs near its count; a compile runs in a process of its own; every module outside the host contract says so (decisions 514, 520) | C, R | `contributor/compile-pipeline`; `reference/host-contract` (which modules are internal) |
| 378-383 | RV-21 landed, "the host's frictions" (decision 517): stale-store warning on a fresh start; simulator takes and gives the configuration's addresses once a runner has opened it; examples as files under `examples/`; a host's own adapter | R (dup), C | `reference/retained-values-and-store`, `reference/io-adapters`, `howto/write-a-device-adapter`, `howto/install-and-run` (where the examples are); history part `contributor/project-status-and-history` |
| 383-384 | Maintainer answered RV-20's and RV-21's questions 2026-11-13, decisions 522-531 | X | `PLAN.md` |
| 384-387 | RV-22 landed (decision 515 (e), (b)): CI ends a red log with each failed test; a release step tags a version once `CHANGELOG.md` names it; the first version's number and tag are the maintainer's to give | C | `contributor/toolchain` |
| 387-389 | RV-26 landed: a program's text read canonically before the store compares it; stale-store warning names both causes and is sent to subscribers; store written as `logex retain 3` | R (dup) | `reference/retained-values-and-store` |
| 389-393 | Answers 2026-11-14, decisions 532-536; RV-27 landed: keyword case and bit brackets read as logex reads them before the store compares; a version 3 store naming no program refused; one message for an end line under every header that takes none | R (dup), X | `reference/retained-values-and-store`, `howto/recover-a-refused-store`; dates to `PLAN.md` |
| 393-396 | Answers the same day, decisions 537-540; RV-28 landed: a version 3 store naming its resource and no program refused; every refusal of the lines naming a store's program ends with the way to start cold | R (dup), X | `reference/retained-values-and-store`, `howto/recover-a-refused-store` |
| 396-399 | Answers 2026-11-15, decisions 541-545: no release for now; the changelog names every decision at every commit; the refusal told at its resource line | C, H | `contributor/toolchain` (releasing); "no release for now" also `howto/install-and-run` and README (landing page) |
| 399-402 | Waiting: RV-29 (two store refusals reworded), typespecs with Dialyzer, the runner split by concern | C | `contributor/project-status-and-history` (roadmap); "no typespecs yet" also `reference/host-contract` |
| 403-405 | Everything decided that changes the source language has landed; Milestone 2, program organisation, whole | C | `contributor/project-status-and-history` |
| 405-408 | Milestone 4, the wall-clock runner (decisions 108-143, designed in §4.11); its only words in the language are a task's `watchdog` and the `continuous` task | C, R | `contributor/project-status-and-history`; the two-words fact `reference/configuration-file` |
| 409-413 | Milestone 6 headline: decided 2026-10-27 (decisions 266-285, §4.13; answers 286-345), M6-1 to M6-9, closed 2026-11-01 (decision 346) | C | `contributor/project-status-and-history`; candidate `adr/NNNN-retained-values-and-warm-restart` |
| 413-419 | M6-1, M6-2: `retain` / `non_retain` on a program's `var` and `var_output` and a block's three sections; nearest mark on a member's path wins; warm restart rules; the three restart calls | R (dup) | `reference/declarations-and-types`, `reference/retained-values-and-store`, `explanation/warm-and-cold-restarts`, `howto/keep-values-across-a-restart` |
| 419-421 | Breaking: `retain` and `non_retain` reserved in any case, so a tag named either no longer compiles | R | CHANGELOG; `reference/source-syntax` |
| 421-425 | M6-3: `var_global retain`; refused on a located global; retained var_output wired to an output point warned of; both words reserved in a configuration file | R (dup) | `reference/configuration-file`, `reference/diagnostics-and-warnings`; breaking part CHANGELOG |
| 425-432 | M6-4: the image, `retained/2` and `retained/1`, what `instance/2` and `start/2` keep and drop; preset follows the program; a retained trigger's last sample kept (answers of 2026-10-30) | R (dup) | `reference/retained-values-and-store`, `reference/host-contract` |
| 432-437 | M6-5 the store (`retain:`, when written, `start: :cold`); M6-6 its write every `retain_period:` by a writer process, a crash losing at most a period and the write in progress | R (dup) | `reference/retained-values-and-store`, `howto/keep-values-on-disk`, `reference/runner` |
| 437-440 | M6-7: an online edit that adds or removes `retain` reports each path whose retention changes, with its value, and writes nothing | R (dup) | `reference/online-edit` |
| 440-442 | M6-8 contract walks; M6-9 documents; Milestone 6's done sentence as one plant in `end_to_end_test.exs` | C | `contributor/testing-strategy` |
| 443-444 | `persistent` deferred and stays unreserved; pointer to "What logex is not" | E (dup of 5722) | `explanation/safety-and-limits` |
| 445-449 | Milestone 5 headline: decided 2026-10-21 (decisions 144-167, §4.12; answers 168-256), M5-1 to M5-16; open questions answered, decisions 257-265 and 286-289 | C | `contributor/project-status-and-history`; candidate `adr/NNNN-data-types` |
| 449-465 | Feature list of Milestone 5 by item: integer widths, `move` by Figure 11, 56 conversions; arithmetic and comparison at every width; based literals and `_`; bit strings, bitwise instructions, bit access, 76 conversions; bit number in a tag; reals; arrays (literal subscripts, tag subscripts, located, of instances); typed counters; long timers | R (dup), E | drop here; a one-paragraph summary for `explanation/what-logex-is`; the item-to-feature map `contributor/project-status-and-history` |
| 465-467 | Behaviour change: an arithmetic result past its type's limit wraps, with no power, in every integer width, replacing the stop at the limit the dint had | R, E | CHANGELOG (it is the changelog's own worked example, decision 146); `reference/instructions`; `explanation/types-and-overflow` |
| 467-470 | Each type word and mnemonic reserved in any case; what Milestone 5 deferred (TIME, LTIME, strings, structures) points to "What logex is not" | R, E (dup) | `reference/source-syntax`; `explanation/safety-and-limits` |
| 471-476 | Milestone 3 landed (decisions 67-107): counters, the other timers, integer arithmetic, pulse coils, forward jump; IEC names wherever IEC names the operation; `neg`, `osr`, `osf`, `jmp`, `lbl` are rule 2's, from a vendor | C, E | `contributor/project-status-and-history`; `explanation/the-dialect-and-iec` |
| 476-479 | No `res`: a counter resets through its own `r` input, as IEC's does, and so does a retentive timer, `xic greased ote lube.r` (decision 90). No master control zone, for good (decision 83) | R, E | `explanation/safety-and-limits` (both are limits stated nowhere else in README), `reference/instructions`, `howto/use-counters`, `howto/use-timers`; candidate `adr/NNNN-no-res-no-master-control` |

**Examples.** None. No `<!-- file: -->` marker, no `$ mix run` block and no `elixir`
block in lines 350-480. Inline code only: `var retain count dint`, `var non_retain jog bool`
(413-414), `var_global retain total_boxes dint 0` (421), `xic greased ote lube.r` (478),
`var temps real[8]` (458), `weights[slot]` (459), `var lane_t ton[4]` (461-462), `word.3`,
`word.[n]` (454-455), `16#ff`, `2#1010`, `1_000` (452-453), `37.5`, `1.5e3` (456-457).
None is run by the suite from here.

**Rules stated.** (All are restated in later sections unless marked ONLY HERE.)

- 362-363: every source text compiles or is told why.
- 363-364: a rung that writes nothing and jumps nowhere is refused at its line (decision 351); the first half of a rung wrapped onto two lines is such a rung.
- 364: a held output holds (configuration edit).
- 364-365: a retained `tof` held on at the outage comes to rest.
- 365-366: each device's write has a limit of its own.
- 366: every file write and read the runner makes is limited by `write_limit:`.
- 366-367: a hung device trips the line however late the runner; the runner's own lateness is named as such.
- 367-368: a store cut short is refused.
- 368: a fresh start that drops anything keeps a numbered copy of the store.
- 369: two runners of one VM are refused one file.
- 376-377: a refusal of many unknown names costs near its count.
- 377: a compile runs in a process of its own.
- 377-378: every module outside the host contract says so.
- 379-380: a fresh start warns where its store was written by another program than the files' (an edit that never reached them).
- 380-381: the simulator takes and gives the configuration's addresses once a runner has opened it.
- 381-382: the examples are files under `examples/`.
- 384-385: CI ends a red run's log with each failed test's file, line and name.
- 385-387: a release step tags a version once `CHANGELOG.md`, drawn from §7's decisions, names it; the first version's number and tag are the maintainer's to give.
- 387-388: a program's text is read canonically before the store compares it.
- 388-389: the stale store's warning names both causes and is sent to the subscribers too.
- 389: the store is written as `logex retain 3`.
- 391-392: a keyword's case and a bit's brackets in a program's text are read as logex reads them before the store compares it.
- 392: a version 3 store that names no program is refused.
- 392-393: one message for an end line under every header that takes none.
- 394-395: a version 3 store that names its resource and no program is refused.
- 395-396: every refusal of the lines that name a store's program ends with the way to start cold.
- 397-398: no release for now; the changelog names every decision at every commit.
- 398-399: the refusal of a store that names its resource and no program is told at its resource line.
- 407-408: the runner's only words in the language are a task's `watchdog` and the `continuous` task.
- 413-415: `retain` and `non_retain` go on a program's `var` and `var_output` and on a block's three sections.
- 415: the nearest mark on a member's path wins.
- 415-416: a warm restart in the core keeps what is marked and initialises everything else.
- 416-417: a retained timer resumes from its instance's `now`, its last scan's.
- 417-418: nothing edge-driven fires on the first scan after a warm restart.
- 418-419: the calls are `Logex.Runtime.restart/3`, `restart/2`, and a tripped runner's `Logex.Runner.restart(runner, :warm)`, which counts none of the time it stood tripped.
- 419-421: `retain` and `non_retain` are reserved words in any case; a tag named either no longer compiles.
- 421-422: a configuration's `var_global retain total_boxes dint 0` is kept by a warm restart.
- 422: `retain` is refused on a located global.
- 422-423: a retained var_output wired to an output point is warned of.
- 423-425: both words are reserved in a configuration file too: a plant file naming a global, an instance, a task, a program type or a device `retain` or `non_retain` no longer loads.
- 425-427: the image is in the core alone: every retained value of an instance or a resource as plain data by its path, from `Logex.Runtime.retained/2` and `retained/1`.
- 427-429: `instance/2` and `start/2` start a new one from an image, keeping a value only where the program declares its path retained, of exactly its type, and it fits.
- 429-430: the rest is dropped and reported; a program changed since lets its unchanged values through.
- 430-431: a timer's or counter's preset follows the program rather than the image.
- 431-432: a retained trigger's last sample is kept with it.
- 432-434: the store is a file on the host's disk that a runner given `retain:` writes the image into at a trip, a stop and a cold restart.
- 434: a fresh start reads the store, warm unless `start: :cold`.
- 435-437: the store is written every `retain_period:`, a second unless set, by a writer process of the runner's own; a crash loses at most a period and the write in progress.
- 437-439: an online edit that adds or takes away `retain` on a program's tag, member, array or instance reports each path whose retention it changes, with the value it holds, and writes nothing.
- 443: `persistent` is deferred and stays unreserved.
- 449-451: integer widths `sint int lint usint uint udint ulint` beside `dint`; `move` by Figure 11; 56 integer conversions.
- 452: arithmetic and comparison over every width.
- 452-453: based literals `16#ff` and `2#1010`; `_` between digits, `1_000`.
- 453-455: bit strings `byte word dword lword`; `and or xor not shl shr rol ror`; bit access `word.3`; 76 bit-string conversions.
- 455-456: a bit number in a tag, `word.[n]`, with the major fault.
- 456-457: `real` and `lreal`; literals `37.5` and `1.5e3`; `sqrt`; the real conversions, `real_to_int` and `real_trunc_int` among them.
- 458-459: arrays `var temps real[8]`, up to three dimensions, by literal subscripts.
- 459-460: a subscript held in a tag, `weights[slot]`; an index out of range is a major fault.
- 460-462: arrays at I/O points; arrays of timers, counters and blocks, `var lane_t ton[4]`.
- 462-463: IEC's typed counters, `ctu_int` and the rest; `ctu_dint` is another word for `ctu`.
- 463-465: the long timers in nanoseconds, `ton_ltime`, `tof_ltime`, `tp_ltime`, `rto_ltime`.
- 465-467: an arithmetic result past its type's limit wraps, with no power, in every integer width; this replaced the stop at the limit the dint had.
- 467-468: each type word and mnemonic is a reserved word, in any case; `real`, `int`, `word`, `byte`, `and`, `or`, `not` among them.
- 475-476: `neg`, `osr`, `osf`, `jmp` and `lbl` are vendor names (rule 2); every other name is IEC's where IEC names the operation.
- 476-478 ONLY HERE: there is no `res`; a counter resets through its own `r` input; a retentive timer resets the same way, `xic greased ote lube.r` (decision 90).
- 478-479 ONLY HERE: there is no master control zone, for good (decision 83).

**Citations.**

- 354: link `docs/review-2026-11-01.md`. 355: commit `d422608`.
- 360-361: RV-1 to RV-7, RV-9 to RV-19. 361-362: decisions 347-512, link `docs/organisation.md` §7. 364: decision 351.
- 371: `PLAN.md` item RV-8 ("The review after Milestone 6"). 374: the review's "The close".
- 375: 2026-11-12, decisions 513-521; decision 521. 376: RV-20 to RV-25; RV-20. 378: decisions 514 and 520; RV-21. 379: decision 517. 382-383: "A device's adapter", below.
- 383-384: 2026-11-13, decisions 522-531. 384: RV-22, decision 515 (e) and (b). 386: link `CHANGELOG.md`; §7. 387: RV-26.
- 390: 2026-11-14, decisions 532-536; RV-27. 394: decisions 537-540; RV-28. 397: RV-22's and RV-28's questions, 2026-11-15, decisions 541-545. 399: RV-29.
- 403: link `docs/naming.md`. 404: `PLAN.md` §5; Milestone 2; "A function block", "A configuration", below. 405-406: Milestone 4; decisions 108-143; link `docs/organisation.md` §7; §4.11. 408: "Watchdogs and the continuous task", "Running a plant on the clock", below.
- 409-413: Milestone 6; 2026-10-27; decisions 266-285; §4.13; decisions 286-345; M6-1 to M6-9; 2026-11-01; decision 346; `PLAN.md` §3, M6-9; "Retained values", below.
- 413: M6-1, M6-2. 421: M6-3. 425: M6-4. 431-432: the maintainer's answers of 2026-10-30. 432: M6-5. 434-435: "The store on disk", below. 435: M6-6. 437: M6-7. 439-440: "A retained global", below. 440: M6-8, M6-9. 442: `test/logex/end_to_end_test.exs`, "Milestone 6's done sentence in one plant". 444: "What logex is not".
- 445-449: Milestone 5; 2026-10-21; decisions 144-167; §4.12; decisions 168-256; M5-1 to M5-16; decisions 257-265 and 286-289; `PLAN.md` §3, M5-16's review.
- 451: IEC's Figure 11; M5-3; "Integer widths". 452: M5-4. 453: M5-7. 455: M5-8; "Bit strings". 456: M5-9; "A bit number in a tag". 458: M5-10; "Reals". 459: M5-11; "Arrays". 460: M5-12; "A subscript in a tag". 461: M5-13; "A located array". 462: M5-14; "Arrays of instances". 463: M5-5; "A counter". 464-465: M5-6; "Long timers". 466: M5-2 and M5-4; "Arithmetic", "Integer widths". 470: "What logex is not".
- 471-472: Milestone 3; `PLAN.md` §3; decisions 67-107; link `docs/organisation.md` §7. 474-475: "A counter", "Three more timers", "Arithmetic", "Two pulse coils", "A forward jump". 475: rule 2 (of the naming rule). 476: `docs/naming.md`. 478: decision 90. 479: decision 83.
- No "provisional" mark in this range.

**Pictures.**

- A timeline table for `contributor/project-status-and-history`: one row a milestone (1 to 6, then the review and RV-20 to RV-29), with the date decided, the date closed, the decision range and the README sections it produced. It replaces 1,700 words of prose.
- A small bar or table of the review's figures: 203 findings = 13 refuted + 190 survived (12 high, 35 medium, 143 low); close = 177 closed + 18 kept + 8 questions.
- Nothing for users.

**Glossary.**

- milestone: a numbered block of work in `PLAN.md` (Milestone 1 to 6).
- item (`M5-2`, `M6-9`, `RV-22`, `OE-1`): one piece of work in `PLAN.md`; `M<n>-<k>` is item k of milestone n, `RV-<k>` an item of the review, `OE-<k>` an item of the online edit.
- decision (`decision 351`): a numbered entry in `docs/organisation.md` §7.
- the maintainer's answers: decisions recorded when the maintainer settles questions a work item raised.
- the review / the close: the adversarial review of the whole codebase after Milestone 6 (`docs/review-2026-11-01.md`), and its final accounting for every finding (RV-8).
- landed: merged, with tests.
- done sentence: the one-sentence acceptance statement of a milestone, which a test runs.
- the image: every retained value of an instance or a resource, as plain data by its path.
- the store: the file on the host's disk the runner writes the image into.
- warm restart / cold restart: a restart that keeps retained values / one that initialises everything.
- fresh start: starting a runner (as opposed to restarting a tripped one).
- held output: an output point a configuration edit keeps at its value.
- contract walks: seeded random tests over the host contract (`api_contract_test.exs`).
- cost pins: tests that hold a cost under a bound.
- rule 2: the naming rule's second case, a vendor mnemonic where IEC has only a graphical element.
- master control zone: a vendor ladder feature (MCR) that de-energises a block of rungs; logex has none.

**Hard to read.**

1. Lines 354-360: "Twenty-seven reviewers attacked the code at `d422608` by running it, each finding tried and its refutation tried in turn: of 203 findings 13 were refuted and 190 survived, 12 high, 35 medium and 143 low, about 60 defects, gathered where code read again the names the lexer had cut, at features combined late, in the runner's own work against a real-time deadline and in a configuration edit's held outputs, while the evaluator, the front end's round trip, the lone edit and the runner's scheduling held."
2. Lines 360-370: "Eighteen items, RV-1 to RV-7 and RV-9 to RV-19, built the maintainer's answers, decisions 347–512 in `docs/organisation.md` §7: every source text compiles or is told why, and a rung that writes nothing and jumps nowhere, such as the first half of a rung wrapped onto two lines, is refused at its line (decision 351); a held output holds; a retained `tof` held on at the outage comes to rest; each device's write has a limit of its own, every file write and read the runner makes is limited by `write_limit:`, and a hung device trips the line however late the runner, its own lateness named as such; a store cut short is refused, a fresh start that drops anything keeps a numbered copy of the store, and two runners of one VM are refused one file; the runner's own long work is cheaper, bounded and named when it trips; and the suite's cost pins are bounds measured within the run."
3. Lines 425-432: "M6-4: the image, in the core alone, every retained value of an instance or a resource as plain data by its path, `Logex.Runtime.retained/2` and `retained/1`, which `instance/2` and `start/2` start a new one from, keeping a value only where the program declares its path retained, of exactly its type, and it fits, and dropping and reporting the rest, so a program changed since lets its unchanged values through, a timer's or counter's preset following the program rather than the image, and since the maintainer's answers of 2026-10-30 a retained trigger's last sample kept with it."

**Notes for the rewrite.**

- Looks incomplete: the "Waiting" list (399-402) names RV-29, typespecs with Dialyzer (RV-24) and the runner split (RV-25), but not RV-23, the tracing of the "provisional" marks, which `PLAN.md` line 42 says still waits.
- `CONTRIBUTING.md` "Landing work stales the plan" (line 258) names this list as one a landing must bring current. If the section moves, that sentence must follow it.
- No test reads this section's text (searched `test/` for its heading and distinctive phrases).

---

## What logex is not (lines 5674-5770, about 1,370 words)

**Reader and purpose.** Anyone deciding whether logex may be used for a job, and any host
writer who must know what logex will not do for them: safety, timing, outputs on failure,
real I/O, missing language features, and what retained values do and do not survive. Each
claim is a promise about the code, kept true by hand (CLAUDE.md: "Its prose has no test").

**Units.** Every limit is its own unit, numbered L1 to L62, with the exact claim. The
primary destination of all of them is `explanation/safety-and-limits`; the destination
column names the second page each must also reach. I propose one new slug:

- `reference/not-supported` NEW: bullet 8 (L20 to L50) is a dry look-up list ("is X
  supported?"), 31 separate facts with no reasoning. It reads as reference, not
  explanation. Keeping it out of `explanation/safety-and-limits` lets that page explain the
  four things that need explaining: safety, timing, outputs on failure, storage.

| lines | # | exact claim | type | second destination |
|---|---|---|---|---|
| 5676 | L1 | "Not a safety controller. It must not implement a safety function" | E | README (landing page), first screen |
| 5676-5680 | L2 | "an emergency stop, a guard interlock, a light curtain, two-hand control, burner or pressure protection belong in hardwired circuits or a safety-rated controller, designed and validated to the functional-safety standards that apply, and logex makes no claim against any of them" | E | README (landing page) |
| 5680-5682 | L3 | "The e-stop in the examples above is a signal a program reads and records; the e-stop that cuts a machine's power must be wired to work with logex stopped, crashed or never started." | E | `tutorials/first-program` (a one-line caution where the e-stop first appears) |
| 5683-5684 | L4 | "Not hard real-time. It runs on the BEAM, on a general-purpose operating system, with no bound on a round's lateness or jitter" | E | `explanation/scan-cycle-and-time`, `reference/runner` |
| 5684-5686 | L5 | "A watchdog is a backstop that trips the plant when a task runs long, not a guarantee that it never does." | E | `explanation/trips-and-watchdogs`, `howto/set-watchdogs` |
| 5686-5687 | L6 | "An input pulse shorter than the gap between two of its device's reads is missed unless the device reports it" | E, R | `reference/io-adapters`, `reference/execution-model` |
| 5687-5689 | L7 | "a reported pulse is missed too unless it is an event task's trigger or a round runs while it holds: the runner keeps only each input's latest value, so a change that rises and falls between two rounds never reaches logic" | E, R | `reference/execution-model`, `howto/use-an-event-task` |
| 5690 | L8 | "Not certified for any industrial use." | E | README (landing page) |
| 5691-5693 | L9 | "Not a full guarantee of outputs off. A trip, a stop, a crash or a kill of the runner, a stuck runner and a device fault each leave every output that can still be written at 0, written once." | E, R | `reference/runner`, `explanation/trips-and-watchdogs` |
| 5693-5694 | L10 | "A device that hangs is killed, and its outputs are left to what the hardware does on losing its master" | E, R | `reference/io-adapters`, `howto/write-a-device-adapter` |
| 5694-5695 | L11 | "if the VM itself stops, nothing of logex runs to switch anything off" | E | `explanation/trips-and-watchdogs` |
| 5695-5696 | L12 | "What a machine that sleeps does to the clock has not been tried." | E | `reference/runner` (known gaps) |
| 5697-5699 | L13 | "Not a compiler to BEAM. A program compiles to data, `%Logex.Program{}`, which `Logex.Runtime` interprets; nothing puts the Elixir compiler on the path that runs or changes a program." | E | `explanation/programs-as-data` |
| 5700-5701 | L14 | "Not wired to real I/O out of the box. The one adapter logex ships is `Logex.IO.Sim`, a simulated device for tests and examples." | E, R | `reference/io-adapters` |
| 5701-5704 | L15 | "A fieldbus or a card's adapter is the host's, written to the `Logex.IO` behaviour; `line_device.exs`, under `examples/`, shows the shape of one, for a card on a TCP socket the script itself plays, an example to copy and not an adapter logex ships" | E, H | `howto/write-a-device-adapter` |
| 5705-5706 | L16 | "Not IEC 61131-3 text. It is a ladder dialect written as text, with IEC's names where IEC names the operation" | E | `explanation/the-dialect-and-iec` |
| 5706-5707 | L17 | "there is no Structured Text, Function Block Diagram, SFC or Instruction List" | E | `explanation/the-dialect-and-iec` |
| 5707 | L18 | "no graphical editor" | E | `explanation/what-logex-is` |
| 5707-5708 | L19 | "no paste-compatibility with IEC's textual forms" | E | `explanation/the-dialect-and-iec` |
| 5709 | L20 | "One resource a configuration" | R | `reference/not-supported` NEW, `reference/configuration-file` |
| 5709-5710 | L21 | "bool, the eight integer widths, the four bit strings and the two reals only" | R | `reference/not-supported` NEW, `reference/declarations-and-types` |
| 5710-5713 | L22 | "arrays of those, of one to three dimensions counted from 0, named by literal subscripts or ones a tag holds, never an expression, located at a device's consecutive addresses or not" | R | `reference/declarations-and-types`, `howto/use-arrays` |
| 5713 | L23 | "arrays of timers, counters and blocks, each element run by literal subscripts" | R | `reference/declarations-and-types`, `reference/function-blocks` |
| 5713-5714 | L24 | "There is no TIME, LTIME, date or time-of-day type and no `T#` literal" | R | `reference/not-supported` NEW, `reference/literals` |
| 5714-5715 | L25 | "so a preset is a plain integer, milliseconds or a long timer's nanoseconds" | R | `reference/instructions`, `howto/use-timers` |
| 5715-5716 | L26 | "every timer, a long one too, counts whole milliseconds of the clock" | R | `reference/instructions`, `howto/use-timers` |
| 5716 | L27 | "no strings or characters" | R | `reference/not-supported` NEW |
| 5716-5717 | L28 | "no structures, UDTs, enumerations, subranges or references" | R | `reference/not-supported` NEW |
| 5717 | L29 | "no typed literal, `int#5`, and no octal" | R | `reference/not-supported` NEW, `reference/literals` |
| 5717-5718 | L30 | "no IEC array bounds, `ARRAY[1..8]`, nor a whole-array copy or fill" | R | `reference/not-supported` NEW, `howto/use-arrays` |
| 5718-5719 | L31 | "no byte or word partial access, `w.%B1`" | R | `reference/not-supported` NEW, `howto/use-bit-strings` |
| 5719 | L32 | "no `round`, `ceil` or `floor`" | R | `reference/not-supported` NEW, `howto/use-reals` |
| 5719-5720 | L33 | "no conversion to or from a bool, a BCD or a real's bit pattern" | R | `reference/not-supported` NEW, `reference/conversions` |
| 5720 | L34 | "no NaN or infinity in a real" | R | `reference/not-supported` NEW, `howto/use-reals`, `reference/faults` |
| 5720-5721 | L35 | "an online edit changes no tag's type or array's size" | R | `reference/online-edit` |
| 5721 | L36 | "a jump forward only" | R | `reference/instructions`, `howto/jump-over-rungs` |
| 5721-5722 | L37 | "forcing for inputs only, an output never forced" | R | `reference/forcing`, `howto/force-inputs` |
| 5722 | L38 | "no `persistent` values" | R | `reference/not-supported` NEW, `reference/retained-values-and-store` |
| 5722-5723 | L39 | "a cold restart discarding every retained value" | R | `reference/retained-values-and-store`, `explanation/warm-and-cold-restarts` |
| 5723-5724 | L40 | "no `program retain` on a configuration's line" | R | `reference/not-supported` NEW, `reference/configuration-file` |
| 5724-5725 | L41 | "no retained located global, an input point read again and an output point at 0 at every start" | R | `reference/configuration-file`, `reference/retained-values-and-store` |
| 5725-5726 | L42 | "no element of an array retained alone, an array being retained whole" | R | `reference/retained-values-and-store` |
| 5726-5727 | L43 | "no outage counted, a retained timer resuming as if no time had passed" | R, E | `reference/retained-values-and-store`, `explanation/warm-and-cold-restarts` |
| 5727-5729 | L44 | "no first-scan bit, though a program keeps its own, a `var first bool 1` its last rung unlatches, 1 on the first scan after every start, which beside a bit it marks `retain` and latches, `var retain ran bool`, tells a warm start from a cold one" | R, H | `reference/not-supported` NEW; the recipe to `howto/keep-values-across-a-restart` (it needs a worked example, which README does not give here) |
| 5729-5730 | L45 | "no prescan" | R | `reference/not-supported` NEW, `reference/execution-model` |
| 5730 | L46 | "no hot restart" | R | `reference/not-supported` NEW, `explanation/warm-and-cold-restarts` |
| 5730 | L47 | "no warm restart that starts named paths cold" | R | `reference/not-supported` NEW |
| 5730-5731 | L48 | "one store a runner, never one a program instance" | R | `reference/retained-values-and-store` |
| 5731-5733 | L49 | "no checksum or encryption of it beyond its grammar and its count of lines, which tells a store cut short but not a value changed in place, the digests it names its program by being the program's and not its own" | R | `reference/retained-values-and-store` |
| 5734 | L50 | "no retained force, the forces having a file of their own" | R | `reference/forcing` |
| 5735-5737 | L51 | "Not battery-backed memory, and no safety memory. What a program marks `retain` is kept on the host's disk, by a runner given a store, `retain:`, and only there; in the core, `Logex.Runtime.restart/2,3` with `:warm`, it is kept in memory alone." | E, R | `reference/retained-values-and-store`, `howto/keep-values-on-disk` |
| 5737-5741 | L52 | "The store is written at a trip, at `stop/2` and every orderly exit, at a cold restart and a fresh start with `start: :cold` or no store file, and every `retain_period:`, a second unless set, never at a warm fresh start or a warm restart, and no period's write while the runner is tripped." | R | `reference/retained-values-and-store` (a table of when the store is written) |
| 5741-5744 | L53 | "A runner that crashes or is killed writes nothing, so its next fresh start comes back to the last write made: a crash loses what changed since, at most a period and the write in progress while the writes succeed and the writer keeps up, everything since the last good write while they fail, and what an edit stepped while tripped changed." | R, E | `reference/retained-values-and-store`, `explanation/warm-and-cold-restarts` |
| 5745-5747 | L54 | "Each write is synced and renamed over the store, the rename not itself made durable, so on some file systems a power failure just after a write may bring back the write before it" | R, C | `reference/retained-values-and-store`, `contributor/store-and-files` |
| 5747-5751 | L55 | "each write the runner makes at an event, a force's among them, is given the write limit of real time, 5000 ms unless set, so a disk slower than that fails every one of them, and has every period's write reported late, the plant running on with its store behind, and one the disk finishes after the runner gave up on it may still land" | R | `reference/runner`, `reference/retained-values-and-store` |
| 5751-5755 | L56 | "Two runners of one VM are refused one file, and so is a store or forces file that is itself a link, but nothing sees a runner of another VM, or one file reached by a second path through a linked directory: two such runners on one store write over each other's, and a crash then brings one runner back with the other's values." | R | `reference/retained-values-and-store`, `reference/forcing` |
| 5755-5758 | L57 | "A retained value is no safety memory: a burner's lockout, a latch a guard's opening set or a count of trips must not be kept in logex, whose store a person can edit, a cold start discards and a crash may set back." | E | `howto/keep-values-across-a-restart` (caution) |
| 5759-5760 | L58 | "Not a guard against what a warm start switches on. No output is kept: every output point is 0 until the first round after a start writes it." | E, R | `reference/runner`, `explanation/warm-and-cold-restarts` |
| 5760-5763 | L59 | "logic that reads a retained bit, count or timer writes its outputs from it in that first round, so a warm start can switch an output on at once, as `a_warm_trip.exs`'s case-full lamp does above" | E | `explanation/warm-and-cold-restarts`, `howto/restart-after-a-trip` |
| 5763-5764 | L60 | "the configuration warns only of a retained var_output wired straight to an output point (decision 272)" | R | `reference/diagnostics-and-warnings` |
| 5764-5768 | L61 | "A fresh start from a store another program wrote, an edit made online that never reached the files or a deploy of changed files, is warned of in `status/1` and to each subscription that takes `:retain`, and refused nothing: the store's values are laid over the program the start was given, by name and type, and run at once (decisions 517 (c), 527 and 528)." | R, E | `reference/retained-values-and-store`, `reference/runner` |
| 5768-5770 | L62 | "a host's own child spec that restarts a crashed runner restarts it warm wherever it names a store, since a fresh start reads its store warm unless `start: :cold`" | E, H | `howto/run-on-the-clock` (supervision), `explanation/warm-and-cold-restarts` |

Limits that belong in this list but are stated only elsewhere in README (found in range
350-480): no `res` instruction (476-478); no master control zone, "for good" (478-479); no
typespecs yet (401; `lib/` holds 0 `@spec`); no release made (397-398).

**Examples.** None in the range. No `<!-- file: -->` marker, no `$ mix run` block, no
`elixir` block. Two examples are named in prose and must stay reachable from the new page:
`line_device.exs` (line 5702; its `$ mix run` block is at README line 5190) and
`a_warm_trip.exs` (line 5762; its `$ mix run` block is at README line 4396). Inline code
only: `var first bool 1`, `var retain ran bool` (5727-5729), `int#5`, `ARRAY[1..8]`,
`w.%B1`, `T#`.

**Rules stated.** The 62 exact claims in the table above are the rules; each row is one
rule or, where a sentence holds several, the smallest group that still reads. Split
further where a reference page needs it:

- 5691-5693: six causes each leave every output that can still be written at 0, written once: a trip; a stop; a crash of the runner; a kill of the runner; a stuck runner; a device fault.
- 5686-5689: three ways a pulse reaches logic: longer than the gap between the device's reads; reported by the device and an event task's trigger; reported and a round runs while it holds.
- 5689: the runner keeps only each input's latest value.
- 5709-5713: types are bool, 8 integer widths, 4 bit strings, 2 reals; arrays of 1 to 3 dimensions; subscripts count from 0; a subscript is a literal or a tag, never an expression; an array of instances is run by literal subscripts only.
- 5714-5716: a preset is a plain integer; milliseconds for a timer, nanoseconds for a long timer; every timer counts whole milliseconds of the clock, a long one too.
- 5727-5729: the first-scan recipe: `var first bool 1`, unlatched by the program's last rung, is 1 on the first scan after every start; a `var retain ran bool` the program latches tells warm from cold.
- 5731-5733: the store is checked by its grammar and its count of lines only; this detects a store cut short, not a value changed in place; the digests in it are of the program, not of the store.
- 5737-5741: the store is written at: a trip; `stop/2`; every orderly exit; a cold restart; a fresh start with `start: :cold`; a fresh start with no store file; every `retain_period:` (default one second). It is not written at: a warm fresh start; a warm restart; a period while the runner is tripped.
- 5741-5744: loss on a crash: at most a period and the write in progress (writes succeeding, writer keeping up); everything since the last good write (writes failing); and what an edit stepped while tripped changed.
- 5745-5746: each write is synced, then renamed over the store; the rename is not itself made durable.
- 5747-5751: every event write has the write limit, 5000 ms unless set; a disk slower than the limit fails every event write; every period's write is then reported late; the plant runs on; a write the disk finishes after the runner gave up may still land.
- 5751-5755: refused: two runners of one VM on one file; a store or forces file that is itself a link. Not detected: a runner of another VM; one file reached by a second path through a linked directory.
- 5759-5760: no output is kept across a start; every output point is 0 until the first round writes it.
- 5763-5764: the only warning is for a retained var_output wired straight to an output point.
- 5764-5768: a store another program wrote is warned of in `status/1` and to each subscription that takes `:retain`; nothing is refused; values are laid over the program by name and type; the plant runs at once.
- 5768-5770: a fresh start reads its store warm unless `start: :cold`; so a supervisor restart of a crashed runner is a warm start wherever the child spec names a store.

**Citations.**

- 5684: "Running a plant on the clock", above. 5704: "A device's adapter", above. 5706: "The dialect", above. 5722: "Retained values", above. 5747: "The store on disk", above.
- 5702: `line_device.exs` under `examples/`. 5762: `a_warm_trip.exs`.
- 5764: decision 272. 5768: decisions 517 (c), 527 and 528.
- 5737: `Logex.Runtime.restart/2,3`. 5738: `stop/2`. 5766: `status/1`. 5701-5702: `Logex.IO.Sim`, `Logex.IO`.
- No plan items and no "provisional" mark in this range.

**Pictures.**

- A boundary diagram for `explanation/safety-and-limits`: the machine, with the hardwired safety circuit (e-stop, guard) cutting power outside logex, and logex beside it only reading the e-stop as a signal. It makes L1 to L3 plain at a glance.
- A table "what happens to the outputs when ...": rows a trip, a stop, a runner crash, a runner kill, a stuck runner, a device fault, a hung device, the VM stopping; columns "outputs written to 0?" and "who does it". From L9 to L11.
- A timing diagram for the missed pulse (L6, L7): an input signal against time, the device's reads and the runner's rounds as ticks, one pulse between two reads (lost), one reported pulse between two rounds (lost unless an event task's trigger).
- A table "when the store is written" (L52), and a timeline of a crash showing the loss window of one `retain_period:` (L53).
- A two-column table "supported / not supported" for bullet 8 (L20 to L50), grouped: types, literals, arrays, conversions, edit, jump, forcing, retained values.
- A sequence diagram for L59: warm start, retained bit read in the first round, output switched on at once.

**Glossary.**

- safety function: a function whose failure endangers people (emergency stop, guard interlock, light curtain, two-hand control, burner or pressure protection); the text says where it belongs, not what it is.
- safety-rated controller: a controller designed and validated to functional-safety standards.
- hard real-time: a bound on lateness; logex has none.
- round: one pass of the runner on the clock; lateness and jitter are a round's.
- watchdog: a limit on a task's run time that trips the plant.
- trip: the runner stopping the plant and writing outputs to 0.
- the BEAM / the VM: the Erlang virtual machine logex runs on.
- adapter: the host's module, written to the `Logex.IO` behaviour, that talks to a device.
- resource: the one running unit of a configuration.
- located (array, global): bound to a device's I/O points.
- UDT: user-defined type. BCD: binary-coded decimal. `T#`: IEC's time literal prefix.
- partial access: IEC's `w.%B1`, a byte of a word.
- `persistent`: IEC's qualifier for values kept across a cold restart; not in logex.
- prescan, first-scan bit, hot restart: vendor and IEC start-up features logex does not have.
- the store: the file a runner given `retain:` writes retained values into.
- fresh start: starting a runner, as opposed to restarting a tripped one.
- write limit: the real-time limit on each file write, 5000 ms unless set (`write_limit:`).
- safety memory: a stored value a safety function depends on.
- child spec: the host's supervisor entry that starts the runner.

**Hard to read.**

1. Lines 5709-5713: "One resource a configuration; bool, the eight integer widths, the four bit strings and the two reals only, and arrays of those, of one to three dimensions counted from 0, named by literal subscripts or ones a tag holds, never an expression, located at a device's consecutive addresses or not, and arrays of timers, counters and blocks, each element run by literal subscripts."
2. Lines 5722-5734 (one sentence): "Of retained values ("Retained values", above): no `persistent` values, a cold restart discarding every retained value, and no `program retain` on a configuration's line; no retained located global, an input point read again and an output point at 0 at every start; no element of an array retained alone, an array being retained whole; no outage counted, a retained timer resuming as if no time had passed; no first-scan bit, though a program keeps its own, a `var first bool 1` its last rung unlatches, 1 on the first scan after every start, which beside a bit it marks `retain` and latches, `var retain ran bool`, tells a warm start from a cold one; no prescan; no hot restart; no warm restart that starts named paths cold; one store a runner, never one a program instance, and no checksum or encryption of it beyond its grammar and its count of lines, which tells a store cut short but not a value changed in place, the digests it names its program by being the program's and not its own; and no retained force, the forces having a file of their own."
3. Lines 5741-5744: "A runner that crashes or is killed writes nothing, so its next fresh start comes back to the last write made: a crash loses what changed since, at most a period and the write in progress while the writes succeed and the writer keeps up, everything since the last good write while they fail, and what an edit stepped while tripped changed."

**Notes for the rewrite.**

- The bold lead of bullet 8, "Not everything a controller has", hides 31 separate limits in two sentences. Bullet 9 mixes two things: what the store guarantees (reference) and a safety warning (L57).
- Two list items state what logex does, not what it lacks (L22, L23, L25, L26). They read as limits only by contrast; in a "not supported" table they need rewording.
- CLAUDE.md's "The README is checked" convention names this section and says a change that adds "an adapter, output forcing, a backward jump or a type" stales it. That convention must point at the new page once the section moves.
- Lines 5741 and 5751 carry stray mid-sentence line breaks (formatting only).

---

## Running it (lines 5772-5808, about 390 words)

**Reader and purpose.** Two readers share it. A user who wants to build and try logex
needs the pinned versions, how to get them and the three commands. A contributor needs the
CI gates and how the suite checks README's examples. The second half is contributor
material that `CONTRIBUTING.md` already states at greater length.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5774-5776 | The pinned toolchain is Elixir 1.20 on Erlang/OTP 28, in `mix.exs`, `.tool-versions`, `shell.nix`, `flake.nix`; one version, inside both projects' security windows | H, C | `howto/install-and-run`; `contributor/toolchain` |
| 5776-5778 | `.tool-versions` pins the exact patches `28.5.0.6` and `1.20.4-otp-28`, read by mise and asdf; `nix develop` uses `shell.nix`; `mix.exs` is the bound the compiler enforces | H, C | `howto/install-and-run`; `contributor/toolchain` |
| 5778-5780 | History and reason: the floor was `~> 1.15` until September 2026; Elixir 1.15 and OTP 26 left their windows in June and May 2026; the oldest pair still receiving security fixes is Elixir 1.16 on OTP 27 | C / X | `adr/NNNN-pin-elixir-1.20-otp-28`; else drop |
| 5780-5781 | No dependencies to fetch, nothing generated at build time; a bare Erlang/OTP plus Elixir is enough, no `erlang-parsetools` | H | `howto/install-and-run`; README (landing page) |
| 5783-5784 | The message `mix compile` aborts with on an older toolchain | H | `howto/install-and-run` (troubleshooting) |
| 5785-5787 | Install the pinned pair rather than relaxing `mix.exs`: deliberate, the code needs it, a loosened bound gets committed by accident | C | `contributor/toolchain` |
| 5787-5788 | `nix develop` gives the pinned toolchain; the committed `flake.lock` predates the pin, so the first run re-locks it; commit the result | C | `contributor/toolchain`; the stale lock itself is a to-do for `PLAN.md` |
| 5789-5790 | Or `asdf install` (with the `erlang` and `elixir` plugins added) or `mise install`, in the checkout | H, C | `howto/install-and-run`; `contributor/toolchain` |
| 5792-5796 | The three commands: `mix compile`, `mix test`, `mix format` | H, C | `howto/install-and-run`; `contributor/toolchain` |
| 5798-5801 | CI runs the four gates on every push and pull request, on Erlang/OTP 28 and Elixir 1.20.4 (`.github/workflows/ci.yml`) | C (dup) | `contributor/toolchain` |
| 5801-5804 | A red run's log ends with each failed test's file, line and name, or why none is named; a suite cut short by a test that halts the VM is red; `scripts/gate.sh` runs the same four locally and judges the suite the same way | C (dup) | `contributor/toolchain` |
| 5804-5808 | The suite runs every README example from its file under `examples/` and compares the output; each block is held to its file; the one `elixir` block with no output, in "Running a plant on the clock", is a fragment run in the state its prose describes (`readme_test.exs`) | C (dup) | `contributor/testing-strategy` |

**What `CONTRIBUTING.md` already covers.** Its headings (`grep '^#'`):
"Contributing to logex"; "Read this first"; "The one rule"; "Working on the code" with
"The test output will lie to you", "The toolchain", "A fix needs a test that fails when the
fix is reverted", "Beware of a green suite", "New instructions"; "Working on the documents"
with "Anchor on names, not line numbers", "Landing work stales the plan", "Do not restore
vendor names"; "Things that will bite you"; "Before you commit"; "Releasing"; "Scripts".

| "Running it" lines | covered by `CONTRIBUTING.md`? |
|---|---|
| 5774-5776 pinned pair and where it is pinned | Yes: "The toolchain" (line 74). It also names CI as a fifth place. It does not give the security-window reason. |
| 5776-5778 exact patches; mise; `nix develop` uses `shell.nix` | Partly: "The toolchain" gives Elixir 1.20.4 and `nix develop` (or `nix-shell`). Not covered: the OTP patch `28.5.0.6`, and mise. |
| 5778-5780 the old floor and the security windows | No. "The toolchain" says only that receipts from Elixir 1.14 are history (decision 359). |
| 5780-5781 no dependencies, no `erlang-parsetools` | No. |
| 5783-5784 the abort message quoted | Partly: "The toolchain" says `mix` aborts before it runs anything; it does not quote the message. |
| 5785-5787 do not relax `mix.exs` | Yes: "The toolchain" ("install the pinned pair rather than loosen the bound"); also CLAUDE.md, "Never relax `mix.exs`". |
| 5787-5788 `flake.lock` predates the pin | No. Only README says it. |
| 5789-5790 asdf and mise | Partly: "The toolchain" gives asdf with both `asdf plugin add` commands, in more detail than README. mise is not mentioned. |
| 5792-5796 the three commands | Not as written. "Before you commit" (line 573) gives the four stricter gate commands; CLAUDE.md "Commands" gives `mix compile`, `mix test --warnings-as-errors`, `mix format`. |
| 5798-5801 CI's four gates | Yes, fully: "Before you commit". |
| 5801-5804 failed tests named, halted suite red, `scripts/gate.sh` | Yes, fully and at greater length: "Before you commit" and "Scripts" (line 658). |
| 5804-5808 the suite runs README's examples; the fragment | Yes: "Landing work stales the plan" (line 256), in more detail (file markers, derived files, continued scripts, the real-clock figures line). |

So about two thirds of "Running it" (5785-5787, 5798-5808) is a shorter copy of
`CONTRIBUTING.md`. What is only in README: the security-window reason and the old floor,
the OTP patch number, mise, "no dependencies, no `erlang-parsetools`", the quoted abort
message, and the stale `flake.lock`.

**Examples.** None the suite runs. One plain fenced block with no language tag at lines
5792-5796 (`mix compile`, `mix test`, `mix format`); it is not an `elixir` block and no
`$ mix run` follows it, so `readme_test.exs` does not run it. No `<!-- file: -->` marker.
Lines 5804-5808 describe the harness itself and name the one fragment, which lives outside
this range (in "Running a plant on the clock"); `readme_test.exs`'s `@fragments` holds
exactly one entry, so "the one `elixir` block shown with no output" is true today.

**Rules stated.**

- 5774-5775: the toolchain is Elixir 1.20 on Erlang/OTP 28, pinned in `mix.exs`, `.tool-versions`, `shell.nix`, `flake.nix`.
- 5776-5777: `.tool-versions` pins `28.5.0.6` and `1.20.4-otp-28`; mise and asdf both read it.
- 5777-5778: `nix develop` uses `shell.nix`; `mix.exs` is the bound the compiler itself enforces.
- 5780-5781: there are no dependencies to fetch; nothing is generated at build time; a bare Erlang/OTP plus Elixir is enough; `erlang-parsetools` is not needed.
- 5783-5784: on an older toolchain `mix compile` aborts with "you're trying to run :logex on Elixir v1.14.0 but it has declared in its mix.exs file it supports only Elixir ~> 1.20".
- 5785-5787: install the pinned pair; do not relax `mix.exs`.
- 5787-5788: the first `nix develop` re-locks `flake.lock`; commit the result.
- 5789-5790: `asdf install` needs the `erlang` and `elixir` plugins; `mise install`; both in the checkout.
- 5798-5801: the four gates are `mix format --check-formatted`, `mix compile --force --warnings-as-errors`, the same under `MIX_ENV=test`, and `mix test --warnings-as-errors`; CI runs them on every push and pull request on Erlang/OTP 28 and Elixir 1.20.4.
- 5801-5803: a red CI log ends with each failed test's file, line and name, or why none is named; a suite cut short by a test that halts the VM is red.
- 5803-5804: `scripts/gate.sh` runs the same four and judges the suite the same way.
- 5804-5806: the suite runs every README example, each script a `$ mix run` block follows, from its file under `examples/`, and compares what it prints with README; each block shown is held to its file.
- 5806-5808: an `elixir` block shown with no output is a fragment the suite runs in the state its prose describes.

**Citations.**

- 5775: `mix.exs`, `.tool-versions`, `shell.nix`, `flake.nix`. 5788: `flake.lock`.
- 5798: `CONTRIBUTING.md`. 5801: `.github/workflows/ci.yml`. 5803: `scripts/gate.sh`. 5807: "Running a plant on the clock". 5808: `test/logex/readme_test.exs`.
- No decision numbers, plan items or "provisional" marks. (`CONTRIBUTING.md` cites decisions 359 and 515 (e) for the same content.)

**Pictures.**

- A small table for `howto/install-and-run`: three ways to get the toolchain (nix, asdf, mise), the command for each, and the file each reads.
- A flowchart for `contributor/toolchain`: the four gates in order, locally (`scripts/gate.sh`) and in CI, with what a red result prints.
- Nothing else.

**Glossary.**

- toolchain: the Elixir and Erlang/OTP versions the project builds with.
- pin: to fix an exact version in a file.
- security window: the period a release still receives security fixes.
- `.tool-versions`: the version file asdf and mise read.
- flake / `flake.lock`: Nix's project file and its lock of exact inputs; to re-lock is to rewrite the lock.
- gate: one of the four commands that must pass before a commit.
- red / green run: a failing / passing CI run.
- fragment: an `elixir` block in README that is not a whole script.

**Hard to read.**

1. Lines 5798-5804: "CI runs the gates `CONTRIBUTING.md` asks of every commit — `mix format --check-formatted`, `mix compile --force --warnings-as-errors`, the same under `MIX_ENV=test`, and `mix test --warnings-as-errors` — on every push and pull request, on Erlang/OTP 28 and Elixir 1.20.4 (`.github/workflows/ci.yml`), a red run's log ending with each test that failed, its file, line and name, or why none is named, and a suite cut short by a test that halts the VM red; `scripts/gate.sh` runs the same four here, and judges the suite the same way."
2. Lines 5804-5808: "The suite runs every example in this file, each script a `$ mix run` block follows, from its file under `examples/`, and compares what it prints with what is printed here, each block shown here held to its file; the one `elixir` block shown with no output, the call made from another process in "Running a plant on the clock", is a fragment, which it runs in the state its prose describes (`test/logex/readme_test.exs`)."
3. Lines 5778-5780: "The floor was `~> 1.15` until September 2026; Elixir 1.15 and OTP 26 left their windows in June and May 2026, and the oldest pair still receiving security fixes is Elixir 1.16 on OTP 27."

**Notes for the rewrite (claims that look stale or will go stale).**

- 5794 shows plain `mix test`. Every other place (5800, `CONTRIBUTING.md` "Before you commit", CLAUDE.md) requires `mix test --warnings-as-errors`, and `CONTRIBUTING.md` says plain `mix test` exits 0 when the tests warn. The block disagrees with the gate.
- 5776 and 5779-5780 are dated claims ("inside both projects' security windows", "the oldest pair still receiving security fixes is Elixir 1.16 on OTP 27"). They were true when written and will silently stop being true; keep them in an ADR with a date, not in a how-to.
- 5787-5788: the stale `flake.lock` is still stale (its nixpkgs input is dated January 2024, before Elixir 1.20 existed), so the claim is true; but it is a defect note, not documentation.
- 5804 "every example in this file" and 5805-5806 "what is printed here" become false as soon as the examples leave README. `readme_test.exs` reads README by path and by block; moving the examples needs the harness changed in the same commit.
- The section never says how a user adds logex to their own project. There is no release (`mix.exs` version `0.1.0`, `CHANGELOG.md` holds only `## Unreleased`), so `howto/install-and-run` must say: a git or path dependency, as `examples/mix.exs` does.

---

## Documents (lines 5810-5820, about 310 words)

**Reader and purpose.** A contributor looking for the right document. Users need none of
these files except, perhaps, `CHANGELOG.md`. In the new layout this list becomes the
contributor docs' index and a three-line pointer in the README.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5812 | `PLAN.md`: the codebase review and the ordered plan of work | C | `contributor/project-status-and-history`; README (landing page) pointer |
| 5813 | `docs/naming.md`: the IEC and vendor naming survey, one stanza per mnemonic, declaration word, word that heads a file or configuration file's word | C, E | `contributor/architecture-overview` (document map); source for `explanation/the-dialect-and-iec` |
| 5814 | `docs/instruction-sets.md`: what IEC 61131-3 specifies for ladder, clause by clause, and what free software (MatIEC/Beremiz, OpenPLC, LDmicro, ClassicLadder, rusty, IronPLC) implements | C, E | `contributor/architecture-overview` (document map); source for `explanation/the-dialect-and-iec` |
| 5815 | `CONTRIBUTING.md`: how to work on it, when the test output misleads, what a fix owes, what not to "fix", how a release is made | C | `contributor/toolchain`, `contributor/testing-strategy`; README (landing page) pointer |
| 5816 | `CHANGELOG.md`: what each release carries, by the decisions of §7 it names, and what changes for a running program | H, C | README (landing page) pointer; `howto/install-and-run` (upgrading) |
| 5817 | `CLAUDE.md`: commands, conventions and a line for each module and test file, for anyone (or anything) editing the code | C | `contributor/architecture-overview` |
| 5818 | `docs/review-2026-11-01.md`: the adversarial review of the whole codebase after Milestone 6, every finding with its repro, and its close | C | `contributor/project-status-and-history` |
| 5819 | `docs/organisation.md`: program organisation and how a running controller is changed; then a 140-word parenthesis listing which item landed which part | C; the parenthesis X | `contributor/architecture-overview`; source of every `adr/NNNN-title`; the parenthesis duplicates "What has landed", drop it |
| 5820 | `docs/defladder.md`: a study of an Elixir-embedded `defladder` DSL, an executed spike, a recommendation (proposed, not adopted) | C | `adr/NNNN-no-embedded-dsl` (a decision not to adopt), linked from `explanation/programs-as-data` |

A new slug would help: `contributor/document-map` NEW, one table of every document, what
it holds and who reads it. Today that role is split between this list, CLAUDE.md's opening
bullets and `CONTRIBUTING.md`'s "Read this first". If no new page is wanted, the table goes
at the top of `contributor/architecture-overview`.

**Examples.** None.

**Rules stated.** None about behaviour. Statements about the documents:

- 5813: `docs/naming.md` has one stanza per mnemonic, declaration word, word that heads a file, and configuration file's word.
- 5816: `CHANGELOG.md` names the decisions of `docs/organisation.md` §7 that each release carries, and what changes for a running program.
- 5819: `docs/organisation.md` is "decided".
- 5820: `docs/defladder.md` is "proposed, not adopted".

**Citations.**

- Files: `PLAN.md` (5812), `docs/naming.md` (5813, linked), `docs/instruction-sets.md` (5814, linked), `CONTRIBUTING.md` (5815), `CHANGELOG.md` (5816), `docs/organisation.md` §7 (5816, linked), `CLAUDE.md` (5817), `docs/review-2026-11-01.md` (5818, not linked), `docs/organisation.md` (5819, linked), `docs/defladder.md` (5820, linked).
- Plan items and milestones, all on line 5819: M1-5, OE-1, M2-1, M2-5, M2-2, M2-3, M2-4, M2-6, Milestone 2, OE-2, Milestone 4, §4.12, Milestone 5, §4.13, Milestone 6.
- Status marks: "decided" (5819); "proposed, not adopted" (5820). No "provisional".
- Third-party names (5814): MatIEC/Beremiz, OpenPLC, LDmicro, ClassicLadder, rusty, IronPLC.

**Pictures.** A table: document, what it holds, who reads it (user, host writer,
contributor, maintainer), and whether it is current rules, reasons or history. CLAUDE.md
already states that split in words ("The present rules", "The design and the reasons",
"The plan and the history", "The names", "How to work here").

**Glossary.**

- stanza: one entry of `docs/naming.md`, for one word of the language.
- naming survey: the comparison of IEC's and the vendors' names for each operation.
- §7: the numbered list of decisions and fixes in `docs/organisation.md`.
- adversarial review: reviewers trying to break the code by running it.
- spike: a throwaway experiment that is run, not adopted.
- `defladder`: the proposed Elixir-embedded DSL the study examines.

**Hard to read.**

1. Line 5819 (one bullet, about 150 words): "`docs/organisation.md` — program organisation: IEC's configurations, tasks, program instances and I/O mapping, the conventional family's hierarchy mapped onto them, and the logex form for them, and how a running controller is changed (decided; program instances landed with M1-5, the online edit of one with OE-1, configurations with periodic tasks, from Elixir data, with M2-1, function blocks, their online edit included, with M2-5, the configuration file with its periodic tasks with M2-2 and M2-3, globals shared through `var_external` with M2-4, and event tasks with M2-6, which completes Milestone 2, a configured plant's online edit with OE-2, and the wall-clock runner, with its watchdogs, trips, forcing and edits, with Milestone 4, and its data types, §4.12, the integer widths, bit strings, reals and arrays, with Milestone 5, and retained values and a true warm restart, §4.13, with Milestone 6)"
2. Line 5813: "`docs/naming.md` — the IEC and vendor naming survey, one stanza per mnemonic, declaration word, word that heads a file or configuration file's word"

**Notes for the rewrite.**

- The description of `PLAN.md` (5812) is thinner than CLAUDE.md's ("The plan and the history"); `PLAN.md` is over 21,000 lines and is mostly history.
- The list is inconsistent about links: five entries are links, four are not.
- The list omits `examples/` (a project of its own), `scripts/` and `LICENSE`.
- `docs/defladder.md` is not mentioned in CLAUDE.md at all.

---

## License (lines 5822-5824, about 5 words)

**Reader and purpose.** Anyone who wants to use or redistribute logex.

**Units.**

| lines | gist | type | destination |
|---|---|---|---|
| 5822-5824 | "Apache-2.0. See `LICENSE`." | R | README (landing page), kept as is; ExDoc picks the licence up from `mix.exs` (`licenses: ["Apache-2.0"]`, already there) |

**Examples.** None.

**Rules stated.** 5824: the licence is Apache-2.0; the text is in `LICENSE`. (Checked:
`LICENSE` is the Apache License 2.0 text and `mix.exs` declares `Apache-2.0`.)

**Citations.** 5824: `LICENSE`.

**Pictures.** None.

**Glossary.** None.

**Hard to read.** Nothing.

---

## Summary across the range

- Main destinations: `contributor/project-status-and-history` (nearly all of "What has
  landed"), `explanation/safety-and-limits` (all 62 limits), `reference/not-supported` NEW
  (the 31 feature limits of bullet 8), `reference/retained-values-and-store` (the store's
  guarantees in bullets 9 and 10), `contributor/toolchain` and `howto/install-and-run`
  ("Running it"), and a document map for "Documents".
- Content that fits no page in PAGES.md: the look-up list of unsupported features
  (`reference/not-supported` NEW), the document list (`contributor/document-map` NEW or the
  top of `contributor/architecture-overview`), and the README landing page itself (safety
  notice, status, licence, pointers).
- Content repeated elsewhere: every feature rule in "What has landed" (later README
  sections); about two thirds of "Running it" (`CONTRIBUTING.md`); line 5819's parenthesis
  ("What has landed"); lines 443-444 and 468-470 (the limits list).
- Limits stated only in the history section, and so at risk of being lost: no `res`, no
  master control zone, no typespecs, no release.
- Claims that look stale or fragile: plain `mix test` at 5794; the dated security-window
  claims; the stale `flake.lock`; "every example in this file"; the "Waiting" list leaving
  out RV-23.
