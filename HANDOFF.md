# Hand-off: paused 2026-11-16 11:10 UTC

The user said "let's drain tasks and take a break". Each page in flight was let finish; then both
workflows were stopped. Nothing runs, and no check-in is scheduled. Start nothing until the user says so.

## Where things stand

- main = 263fc95022ab9e76d99aa4f3f38fe6d068a87c44 (decisions 1-583 recorded; RV-30 landed 565f057).
  GATE-OK 3,266 tests + DIALYZER-OK; CI and Docs green on main and claude/repo-analysis-2piojt.
  Next free decision number: 584.
- DOC-1 step 2 (task #305): 18 of 105 pages written, reviewed, fixed, committed and pushed.
  Skeleton backup/doc2-skel = 08cb82e (105 stubs; the mark is in docs/STUBS.md).

  | track | branch | tip | pages done |
  |---|---|---|---|
  | a1 | backup/doc2-a1 | a35f798 | reference: source-syntax, declarations-and-types, literals, instructions-contacts-and-coils, instructions-timers-and-counters |
  | a2 | backup/doc2-a2 | ba44cc1 | explanation: what-logex-is, safety-and-limits, the-dialect-and-iec, programs-as-data, scan-cycle-and-time |
  | b1 | backup/doc2-b1 | c87c764 | tutorials: timers-and-counters, first-plant, change-a-running-program; howto: install-and-run |
  | b2 | backup/doc2-b2 | c41f180 | howto: map-io-points, write-a-device-adapter, edit-a-running-program, edit-a-running-plant |

  CI and Docs green on a1, a2, b1 tips; on b2's tip Docs green and CI was still running at the pause: check it.
  No track has had its full gate yet (a gate runs after every sixth page); pages passed their own checks and the docs tests.
- Known gap: the reviewer "for what is true" of guides/tutorials/timers-and-counters.md failed (journal
  type "failed"); that page was fixed from the reader's review alone. A resume re-runs that review and its fix.
- Pages whose writers were cut off (nothing committed, working trees clean): explanation/tasks-and-scheduling,
  reference/instructions-arithmetic-and-comparison, howto/read-diagnostics, howto/restart-after-a-trip.
- RV-31 (task #313): script rv/rv31.js, parse-checked, not launched. Args: base = main's sha at launch;
  landed = RV-30 landed 565f057, decisions 575-583 at 263fc95; parallel = what else runs.
- Then: DOC-1's close (doc1c, to write: rv/runs22_26.md says what it must do), step 3, RV-23, RV-25 alone, DOC-2.
- Owed by the user: delete backup/rv7-probe and old backup branches; run nix flake update.

## To carry on, if the scratchpad and /root/.claude/projects are still there

Resume each run with its exact args (cached agents return at once, the four writers above start again):
- lane A: Workflow({scriptPath: docs/doc1b.js, resumeFromRunId: "wf_eeb83001-205", args: <docs/doc1b_args_a.json>})
- lane B: Workflow({scriptPath: docs/doc1b.js, resumeFromRunId: "wf_cbc0d3c4-7df", args: <docs/doc1b_args_b.json>})
Two workflows at a time on this machine (4 cores).

## To carry on, if the container was replaced

- Everything here is on the orphan branch backup/handoff of rellen/logex: fetch it into a new scratchpad.
- The toolchain (Elixir 1.20.4, OTP 28) must be set up again; the scripts read <scratchpad>/toolchain/env.sh.
- Paths in the scripts and args name the old scratchpad: replace them.
- docs/doc1b.js makes a track's clone from backup/doc2-skel: change that line (the "If the clone does not
  exist" sentence of common()) to start from backup/doc2-<track>, and take the pages done out of the args.
  Launch with skeleton: false.
- docs/doc1b_results.json holds every writer's, reviewer's and fixer's report so far (the units of README's
  inventory each page holds: the close's ledger needs them).
