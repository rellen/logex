# Milestone 2: the one design

Label: consolidate. Written 2026-10-02 against `/home/user/logex` at `47319f7`, which was
not modified. This merges the three revised tracks: S-rev (M2-1, the scheduler), F-rev
(M2-5, user function blocks) and T-rev (M2-2, M2-3, M2-4 and M2-6, the configuration
text, globals and event tasks). The revised documents and patches are `S-rev.md`,
`F-rev.md` and `T-rev.md`, each with its `.patch`, in `scratchpad/m2/`. This pass's own
receipts are in `scratchpad/m2/consolidate-work/`.

**Citations.** `org` is `docs/organisation.md` and `PLAN` is `PLAN.md`, by line at
`47319f7`. "S Q-n", "FS-Q-n" and "T Q-n" are the tracks' question labels. "A-n" and "B-n"
are this document's labels. None of these labels may be cited in `lib/`, `test/` or
`CLAUDE.md`, which the labels test in `test/logex/edit_test.exs` enforces. The
conventional vendor is not named.

**What this pass reproduced** (Elixir 1.20.4 / OTP 28; every run judged by its exit code):

- **F-rev's gate, the two runs it owed.** These ran on a copy of `F-rev-work`
  (`consolidate-work/F-gate.log`). Both exited 0 on all four commands, with `Result: 498
  passed (6 doctests, 492 tests)` each time.
- **F-rev's mutation run, which finished after its document was written.**
  `F-rev-mutation.json` has 88 rows. 87 exit 2, and each of those fails at least one test
  besides the three growth tests that are sensitive to load. One is green: **R87**, "a
  body's rungs are on rising lines, each on one, after the declarations".
  - Reverted alone here, R87 compiled (exit 0), and the suite passed: `mix test` exit 0,
    `Result: 498 passed` (`consolidate-work/F-R87.log`). So no test pins the line check
    in `Logex.Compiler.lowered?/1`. A test is owed (§5).
- **T-rev's gate, once more,** on a copy of `T-rev-work`. All four commands exited 0, with
  `Result: 508 passed (6 doctests, 502 tests)` (`consolidate-work/T-gate.log`).
- **S-rev and F-rev, composed** (`consolidate-work/merge`, branch `consolidate`):
  - `S-rev.patch` applies cleanly at `47319f7`.
  - `F-rev.patch` then applies with `git apply --3way` and gives four conflict hunks in
    three files: `runtime.ex` (the moduledoc and the alias line), `api_contract_test.exs`
    and `end_to_end_test.exs`. Each was resolved as the union of both sides.
  - The full gate exits 0, with `Result: 582 passed (8 doctests, 574 tests)`. That is 430 +
    84 (S's) + 68 (F's): every test of both tracks, none dropped (`SF-test-1.log`; the
    union is `SF-union.patch`).
  - On it, `rf-X-consistency-probe/sf_get.exs` prints `m1.s2.run: {:ok, 1}` and refuses
    `m1.s2.t1`, `m1.s2.inner` and `m1.s2` (`SF-get.log`).
  - T cannot be composed this way. S and T each add their own `lib/logex/configuration.ex`
    (X2). T's checks are ported, not merged (§1, commit 16).

---

## 1. What Milestone 2 builds, in what order, and why

**What it builds.** A configuration runs several program instances as one resource:
- **M2-1:** periodic tasks, globals at located I/O points, and connections, from Elixir
  data;
- **M2-2:** the same written in a configuration file;
- **M2-5:** user function blocks run by `cal`, changeable while the program that holds
  them runs;
- **M2-4:** globals shared through `var_external`;
- **M2-6:** event tasks on `single`;
- **M2-3:** periodic tasks in the text.

Every front end still ends in data that `Logex.Runtime` interprets, and nothing compiles a
user's program to BEAM.

**The order** (A-1, recommended by all three tracks) is:

```
design record → M2-1 → M2-5 → M2-2 → M2-3 → M2-4 → M2-6
```

- **M2-1 first.** It is decision 1's default. With it first, M2-5's decided Done-when
  (PLAN:1345, org:1408) stays as written: M2-5's own test reads `get(rt, "m1.s2.run")`,
  which the S+F union above answers `{:ok, 1}`.
- **M2-5 before M2-2.** T's reader, loader and IR walks are then written against `cal`
  from their first commit. In the other order the F+T seam crashes:
  - T's `writes/1` raises on `cal` (X1);
  - its loader puts an `%FbType{}` into `programs` (X1);
  - a block's `var_external` raises `FunctionClauseError` in `FbType.role/1` (X3);
  - and there are two loaders (X4).
- **B5's one IR walk lands before the first check that reads a program's writes or
  timers** (M2-4's commit 24), and it knows `cal` and reaches block bodies.

**The commits.** Each lands green under the full gate, with its mutation rows in its
message.

- *Built* means the commit exists as a gated commit.
- *Spiked* means the code exists in a track's spike, but not split into commits.
- *Plan* means only the design exists.

| # | Item | Commit | Ports from | State |
|---|---|---|---|---|
| 0 | all | **Design record.** org §7 gains decisions 30 onward, numbered once from this document's answers, before any code cites one. It also orders the overlapping edits: org §4.4, §4.6, §4.9 (S's state table into "One rule for new state"), §6.2, PLAN's Done-whens, README's syntax list, CLAUDE.md's `lib/logex.ex` entry, and the extension (A-6) in PLAN:954, 1314, 1784 and org's 17 other occurrences, with decision 3 annotated rather than rewritten | S-rev §8 c1, F-rev §8 c0, T-rev §8 "before any" | plan |
| 1 | M2-1 | `Logex.Configuration` and the `:configure` stage: the structs, `check/1`, `new!/1`, `location/1`, `initial/1`. It also takes A-7's error mode, A-8's priority bound and B-17's rising lines | S-rev-series `7acab45` | built (466 tests) |
| 2 | M2-1 | The resource with periodic tasks: `start/1`, `cycle/3`, `next_due_in/1`, `overlaps/1` (A-9) and `get/2` | `5df3de5` | built (504); its prose names `restart/2` early and is trimmed at landing |
| 3 | M2-1 | `restart/2` (A-9) | `ea6e537` | built (509); dropped under A-9 (b) or (c) |
| 4 | M2-1 | The contract walk over a configuration | `42c636a` | built (510) |
| 5 | M2-1 | The Done-when end to end, with the README walks | `e897a45` | built (514) |
| 6 | M2-1 | Documents | S-rev §9 | plan |
| 7 | M2-5 | Survey: the `function_block` and `cal` stanzas (header sentence per B-40), `Declarations.kinds/0` and its naming test | F-rev §8 c1 | spiked |
| 8 | M2-5 | The walks learn a signature per instruction (no behaviour change) | F-rev c2 | spiked |
| 9 | M2-5 | Blocks and `cal`. Reserves `cal` everywhere and `function_block` in a block's file. Lands fix F15, a `file` on `%Program{}` (B-30). Its Done-when reads `get(rt, "m1.s2.run")` (X6). It uses one block-type message at every entry point, S's `check/1` included (B-31). Lands in one push with commit 10 | F-rev c3, with S+F union's resolution | spiked (F15, get/2 assert and B-31 not built) |
| 10 | M2-5 | The edit by path (A-2, A-3) | F-rev c4 | spiked |
| 11 | M2-5 | The loader: `compile_file/1` finds blocks beside (A-5) | F-rev c5 | spiked (A-5 (b) not built) |
| 12 | M2-5 | Documents | F-rev c6 | spiked in part |
| 13 | M2-2 | Stanzas `program`, `var_global`, `at` | T-rev c1 | spiked |
| 14 | M2-2 | `compile_file/1` takes only `.ld`, as a gate in front of F's `load/3` (X4) | T-rev c2 | plan for the composition |
| 15 | M2-2 | `Logex.Configuration.Text`: the reader, `entries!/1`, `print/1`. Reserves `program var_global at` (`bool` and `dint` are already reserved) in the configuration file. The naming tests are composed by hand with F's (X20), and the messages that name words are staged (TF-10) | T-rev c3 | spiked |
| 16 | M2-2 | T's checks become rows of S's `check/1`: the file's words and one diagnostic per instance (B-29), then `compile/3` and the seven receipt lines. Every S check is asserted again from source (B-1). The surface pin is rewritten once (X2) | T-rev c4 onto S-rev's `check/1` | plan: **the largest unbuilt port** |
| 17 | M2-2 | The configuration loader through F's `load/3`, one memo per configuration, with a kind check (X1, X4) | T-rev c5 | plan for the composition |
| 18 | M2-2 | The round trip, totality, growth | T-rev c6 | spiked |
| 19 | M2-2 | A location in a `.ld` rung is named as one | T-rev c7 | spiked |
| 20 | M2-2 | Done-when on S's `cycle/3`; documents | T-rev c8 | plan |
| 21-23 | M2-3 | Stanzas `task interval priority with` (priority per A-8), turned on, Done-when, documents (they state A-11) | T-rev c9-c11 | spiked (reader); run on S's scheduler |
| 24 | M2-4 | B5's one IR walk: public "what a program writes" and "which timers it runs", knowing `cal` and reaching block bodies | T-rev c12, FS-Q23 | plan |
| 25 | M2-4 | `var_external`: section, stanza and `.ld` rules, refused in a block's file with a located diagnostic (B-49, X3) | T-rev c13 | spiked but the block-file refusal |
| 26 | M2-4 | Binding checks and the writer warnings W4 and W5, from the walk, into `check/1` | T-rev c14 | spiked as T's `check/3` |
| 27 | M2-4 | One copy of a global at run time (B-48), Done-when, documents | T-rev c15 | **not spiked** |
| 28 | M2-6 | `single`: stanza, line, W6 from the walk, `Task.single` | T-rev c16 | spiked (reader, checks) |
| 29 | M2-6 | Edges at run time (A-10, B-51, B-52), Done-when, documents | T-rev c17 | **not spiked** |

Only commits 1-5 are built as a series (S-rev-series, branch `s-rev`, each commit gated on
its own, each commit's mutation rows red in its own tree). F's and T's series must be
built the same way before landing.

---

## 2. Decisions for the maintainer

### (A) Choices that need the maintainer

These are ranked by consequence. They are returned as structured data, with options,
consequences, a recommendation and why, the items each bears on, and the part-1 questions
each merges. In short:

| Id | Question | Recommend |
|---|---|---|
| A-1 | Milestone order | M2-1, then M2-5, then M2-2 |
| A-2 | What may change in a block type while running | the full nested migration; a member's type change refused |
| A-3 | How long an edit blocks a one-shot inside a block, and what org §4.9 then says | until a scan runs it; org:1015 and org:1160 restated |
| A-4 | What a user block shows outside | inputs and outputs read; its `var`s hidden; nothing written |
| A-5 | How a program gets its blocks from files, and their warnings | `compile_file/1` loads beside, and hands back the blocks' warnings |
| A-6 | The configuration file's extension | `.lxcf` |
| A-7 | A host mistake no text can say, in the configuration validator | `ArgumentError` |
| A-8 | A task's priority bound | 0..65535, IEC Ed 3's UINT |
| A-9 | `restart/2` and `overlaps/1` beyond org §4.6's API | both |
| A-10 | `single` with `interval` | the phase anchored; periods under a high trigger skipped, not counted |
| A-11 | `next_due` when OE-2 changes an interval | `min(next_due, now + new interval)` |

### (B) Routine choices, taken as recommended unless the maintainer objects

- **B-1** The §4.4 checks land with M2-1 on data; M2-2 asserts each again as a whole list
  from source (S Q-1; departure D-1).
- **B-2** After `restart/2`, every task is due at the next cycle (S Q-4).
- **B-3** `next_due_in/1` counts periodic tasks only, not task-less instances (S Q-6).
- **B-4** Tasks, globals and instances share one namespace. A case-only twin is refused,
  and the first in line order keeps the name (S Q-7, T Q-5).
- **B-5** A location is a one-name device, `i` or `q` lowercase, then whole-number fields
  with no leading zero. One address holds one global (S Q-9, T Q-8).
- **B-6** Two device names that differ only in case are refused, as R15 refuses names.
  This is owed in commit 16 and not built (T Q-27 (b)).
- **B-7** An output point takes no initial value (S Q-10, T Q-7).
- **B-8** A configuration with no program instance is refused (S Q-11).
- **B-9** `programs:` is a list to `new!/1` and a map by name in the struct (S Q-12).
- **B-10** `start/1` runs `check/1` again (S Q-13).
- **B-11** `new!/1` takes a keyword list and raises every problem in one `ArgumentError`.
  T's `new!/3` is dropped (S Q-14, S Q-24, T Q-19, T D3).
- **B-12** An element is a struct per kind (S Q-15).
- **B-13** The stage is `:configure`, attributed to M2-1. `diagnostic.ex` is identical in
  both tracks (S Q-16, T Q-3, X15).
- **B-14** `get/2` reads a global, any declared tag of an instance, or a public member.
  It never reads an internal member, an instance whole, a task or the configuration. Its
  depth follows A-4 (S Q-17).
- **B-15** An overlap event comes just before its task's scans (S Q-18).
- **B-16** A configuration must have a name (S Q-19).
- **B-17** Lines are all nil or strictly rising (T's R48, into S's `check/1`). A line on
  an element from Elixir gets S's per-element message, checked before the rising rule
  (S Q-20 parts 1 and 2, T Q-21 parts 1 and 2, X9). The error mode is A-7.
- **B-18** M2-1's and M2-3's Done-whens say "cycled every 10 ms from 0 to 990 ms"
  (S Q-21).
- **B-19** The argument order is `Configuration.compile(name, source, programs)`, as
  org:470 decided (S Q-24, T Q-19).
- **B-20** M2-2 lands a printer with an exact round trip (S Q-25, T's R49).
- **B-21** OE-2 adds the generation counter (S Q-26).
- **B-22** Each text item reserves its own words. The data path does not refuse them
  early, and a message that names a word lands with that word (S Q-27, T D2, TF-10).
- **B-23** Keep the name `Logex.Configuration.Task` (S Q-28).
- **B-24** `warnings` lands empty in M2-1. M2-2 fills it first (W1, W2), then M2-3 (W3),
  M2-4 (W4, W5) and M2-6 (W6). W7 waits for `var_config` (S Q-29, T Q-12, X12, T D1).
- **B-25** CLAUDE.md's "New state" rule extends to `%Logex.Runtime{}`, through
  `Configuration.initial/1` and the runtime moduledoc's one-rule section (S Q-30,
  S-FIT-1).
- **B-26** A refusal's time stays quadratic in bad keys times names, accepted and
  documented. T's error path pays the same, as the `.ld` compiler already does (S Q-31,
  rf-T-correct-9).
- **B-27** There is no per-instance restart inside a resource, and `%Logex.Runtime{}` is
  defined in `Logex.Runtime` (S Q-35).
- **B-28** S's optional commit 0 (an `outputs` field on `%Program{}`) is not taken.
  Revisit it with the runner (S Q-36 (c)).
- **B-29** A message uses the configuration file's words, rule by rule. An unconnected
  var_input gets one diagnostic per instance, listing its members (S Q-37 parts 1 and 2,
  T Q-20 parts 1 and 2, X10).
- **B-30** Fix F15 goes to the first item that meets it, which is M2-5 under A-1 (a). F's
  R68 (the block file in `file`) and T's R51 (the type's file named in the text) are
  stated together (S Q-38, FS-Q29, T Q-24, X18).
- **B-31** One message for a block type given as a program, in F's R8 words, with the
  configuration's prefix where the key and the name differ (S Q-39, FS-Q32, T Q-25, X13).
  On the S+F union, `new!/1` still gives S's interim words. Commit 9 changes them.
- **B-32** The uses of a declaration with an unknown type are excused too, in a separate
  commit after M2-5 (FS-Q3 (b)).
- **B-33** `Scan.tags` is filled by the runtime, and `cal` narrows the scan for its body.
  CLAUDE.md's "same for one call" becomes "same for one routine run" (FS-Q4 (a); D-6).
- **B-34** One `cal` runs an instance (FS-Q11 (a)).
- **B-35** A block's file compiles to `{:ok, %FbType{}}` (FS-Q13).
- **B-36** One version of each block name per compile. Versions that differ only in their
  warnings are one (FS-Q14).
- **B-37** The loader stops at a broken block file (FS-Q15 (a)).
- **B-38** `cal`'s `@instructions` entry is the marker `{:cal, :block}` (FS-Q18; D-11).
- **B-39** A block's name is matched exactly, as a tag's is (FS-Q20).
- **B-40** The header `function_block <name>` is the first rung. Comments and blank lines
  may come before it (FS-Q21 (a); D-9).
- **B-41** Every compile checks each type it is given at full depth. Chains cost O(N²), and
  marks are not trusted (FS-Q28 (a)).
- **B-42** M2-5 lands with one `cal` clause per walk. B5's extraction comes at commit 24
  (FS-Q23, T commit 12).
- **B-43** Members declared from Elixir come first in `cal`'s order, by name (FS-Q24).
- **B-44** New stanzas say "user-defined instruction", not the conventional family's own
  term (FS-Q25).
- **B-45** A held block type is stored once: a member names it as `{:block, name}`, and
  the body's tag table holds it (FS-Q31; D-16).
- **B-46** The configuration file is read by a recursive descent over `Logex.Lexer`'s
  tokens (T Q-2, X11).
- **B-47** A program type's mistake is cited once, at its first instance's `program` line,
  with its `.ld` file named in the text (T Q-6).
- **B-48** G2: one copy of a global. The scheduler merges each `var_external` into the env
  before `call/4` and splits it off after (T Q-10, S §5).
- **B-49** `var_external` is refused in a block's file. This is a deliberate, reversible
  departure from IEC (T Q-18 (a); D-18).
- **B-50** A duplicate or a case twin does not become a placeholder (T Q-26 (a)).
- **B-51** An event task's due time, for the tie-break, is the cycle's `now`. org §4.6
  step 3 makes the task due on the edge seen in this cycle. Owed: the test in T-rev §13
  Q-22 (T Q-22 (a)).
- **B-52** A restart sets an event trigger's last sample to 0, and an edit keeps it. A
  change to `single`, or adding or removing an event task's `interval`, is refused
  (T Q-15, S §5).
- **B-53** Three landed messages change, each pinned by a rewritten test:
  - `put_inputs/3` and `call/4` list the var_inputs once (S D-5);
  - "only an instance of a function block has members" replaces "only a timer has
    members";
  - `Logex.compile/2`'s options message names `types:`.

**For OE-2's design pass, not Milestone 2** (no M2 commit depends on these; commit 0's
state table marks them "OE-2 decides"):

- An instance's type changed by OE-2: a remove plus an add, recommended over refusal,
  since org:868-870 allows both by name (S Q-33).
- A kept global whose `initial` changed: report it as decision 29 reports a tag's. This
  extends decision 29, so it is the maintainer's call then (S Q-34, T Q-28).
- The switch merges each `var_external` by the running program's externals, and splits by
  the candidate's. So the value kept is the one decision 25 keeps (T Q-17).

**Dropped: each answer is forced by a decided rule.**

- **S Q-5** (what the first cycle's elapsed time means). Forced by org:556-557: "anchored
  at start. Every periodic task is due in the first cycle."
- **S Q-32** (a configured plant is not edited until OE-2). Forced by PLAN:1488, which puts
  OE-2 after Milestone 2, and by org:885: "`%Logex.Runtime{}` is opaque, and its
  configuration changes only through the API". The documents say so (§5).
- **FS-Q1.** Subsumed by A-1.
- **FS-Q5** (a chain of rungs). Forced by decision 21: "block … each `ons` the edit adds or
  whose rung changed". A calling rung is on that `ons`'s path, and option (b) is the false
  pulse decision 21 exists to prevent.
- **FS-Q6** (the Resume mechanism). Forced by decisions 8 and 23 with fix F3. The other
  options lose decision 8's catch-up, or reopen org:838-842 inside blocks.
- **FS-Q7** (a block's inputs read from outside). Forced by decision 9 ("reads anywhere")
  and org:328.
- **FS-Q17** (a block member's changed initial). Forced by decision 29, applied by path.
- **FS-Q22** (how exact a given type must be). Forced by decision 28, the full entry check,
  and org:775-779: "the data API refuses anything the text cannot say". Option (d) let the
  runtime raise (rf-F-fit-1).
- **FS-Q10, FS-Q19.** Already kept as decided (PLAN:1351-1352, PLAN:732-734).
- **T Q-4, T Q-13.** Withdrawn: the decided plant and PLAN M2-6 settle them (TF-12).
- **T Q-11** (a global both driven and written through `var_external`). Forced by
  org:431-433: a write "through `var_external` … is a warning".
- **T-rev's closing list.** T1-Q13, T1-Q18, T1-Q20 and T1-Q21 stand as recommended.

---

## 3. Departures from decided rules, merged

Each is accepted by the question named. If that question goes the other way, the departure
goes with it.

| # | Departure | Decided where | Settled by |
|---|---|---|---|
| D-1 | The §4.4 checks land with M2-1, not M2-2, and are pinned from data, not from source | org:1377-1379, PLAN:1317; org:1356-1357 ("from source") | B-1 (M2-2 owes the from-source lists) |
| D-2 | `overlaps/1` and `restart/2` beyond §4.6's API block | org:675-678 | A-9 |
| D-3 | `new!/1` raises every problem at once, where `Tag.new!/4`, which org:474-475 names as the model, raises the first (`lib/logex/declarations.ex:140-141`); a reading, listed in case | org:474-475 | B-11 |
| D-4 | "New state in an instance" extended to `%Logex.Runtime{}` | CLAUDE.md "New state" | B-25 |
| D-5 | Three landed messages change | `runtime_test.exs` (key order past 32), `validation_test.exs:1607,1611,1637,1692`, `api_contract_test.exs:108`, `logex_test.exs:133-138` | B-53 |
| D-6 | The scan is the same for one routine run, not one call | CLAUDE.md `evaluate/3` convention | B-33 |
| D-7 | M2-5's Done-when reads `m1.s2.run` through `get/2` | PLAN:1343-1347, org:1407-1410 | no departure under A-1 (a); a rewording under (b) |
| D-8 | The Resume rule's basis: "a `last` before `now`" becomes "F does not run it, and F last scanned" | org:1004; `lib/logex/edit.ex:84-87, 692-695` | forced (FS-Q6, dropped above); top-level behaviour unchanged |
| D-9 | The block header is the first rung, not the first line | decision 4 (org:1461) | B-40 |
| D-10 | A block's own `var`s are hidden, against "reads anywhere" | decision 9, org §4.3; left open at `fb_type.ex:21-24` | A-4 |
| D-11 | `cal`'s `@instructions` entry is a marker, not a signature | CLAUDE.md "New instructions, step 2" | B-38 |
| D-12 | `Logex.compile/2` gains `types:`, and a block's file compiles to `%FbType{}` | PLAN M1-5; `logex_test.exs:133-138` | B-35, A-5 |
| D-13 | A loader ships with M2-5, ahead of M2-2 | PLAN M2-2's scope | A-5 |
| D-14 | The nested member migration lands in M2-5, though PLAN's M2-5 scope sentence omits it | PLAN:1340-1343 against org:866, PLAN:1491-1493 | A-2 |
| D-15 | "A scan empties the list": a scan keeps the bits inside an instance whose body did not run. Decision 21's "for that one scan" becomes "until a scan runs it" | org:1015; decision 21 | A-3 |
| D-16 | The switch scan's cost is linear in the block list's bytes, quadratic in nesting depth | org:1160 | A-3 |
| D-17 | A member's type may be `{:block, name}` | CLAUDE.md Key Files, `fb_type.ex` | B-45 |
| D-18 | `var_external` is refused in a block's file, though IEC allows it (Ed 2 Table 33 10a/10b; both grammars) | IEC, recorded as org §4.8 records its own | B-49 |
| D-19 | The two-writer warning and W6 ride on `%Configuration{}.warnings`, not M1-5's program `warnings` | org:431-433, org:650 | B-24 |
| D-20 | If A-2 (c): a member's type change is refused, and org:866-867 ("initialise the rest") and org:945-948 are reworded to say so | org:820, org:860 against org:866-867 | A-2 |
| D-21 | If A-8 (b): org §4.6 and decision 11 gain a priority bound | decision 11 (no bound stated) | A-8 |

These are not departures: org §4.4's seven receipt lines are pinned by no test (org:449),
and are reworded (B-29). Research IEC-14 contradicts org:434's reason for decision 7, but
not the decision. T D2 (all words reserved at once) and T D3 (`new!/3`) are artefacts of
the spike, which the landing order removes.

---

## 4. What the refutation round confirmed, and how each was resolved

"Code" means fixed in a spike, with a mutant reverting the fix alone red in the full
suite, unless the row says otherwise. "Doc" means fixed in the track's document. A-n and
B-n are where this design answers it.

| Finding | Track | Resolution |
|---|---|---|
| rf-S-correct-F1 | S | Code: GR-2 reworded "linear in the tasks declared"; GR-2b and GR-5 red; the cost is a risk (§5) |
| rf-S-correct-F2 | S | Code: lists given once (LO-1..3 red), message size linear (4707→19407→79409 bytes). The time is still quadratic: B-26 |
| rf-S-correct-F3 | S | Code: a key or path naming a task, the configuration or an instance whole is told so (IN-1d..g, GT-8 red) |
| S-FIT-1 | S | Code: `Configuration.initial/1` public, and the moduledoc's one-rule section (IR-1, IR-2 red); B-25 |
| S-FIT-2 | S | Doc: the moduledoc says it; forced (S Q-32 dropped) |
| S-FIT-3 | S | Code: the series built, five commits each green, each commit's rows red in its own tree (§1) |
| S-FIT-4 | S | Doc: A-11 now has the `min` option and the keep option's delay |
| S-FIT-5 | S | Doc: superseded by TF-1; A-8 |
| S-FIT-7 | S | Doc: D-1, B-1 |
| S-FIT-8 | S | Code: GT-4b and GT-7 and their hand-edited test removed; owed by M2-5 from source if A-4 lets a block lack an output |
| S-FIT-9 | S | Doc: deferred to OE-2 (S Q-33, Q-34) |
| S-FIT-10 | S | Doc: B-27 |
| S-FIT-11 | S | Doc: B-28 (commit 0 not taken) |
| S-FIT-12 | S | Doc: one design-record commit (§1 commit 0) |
| RF-1 | F | Code: R78 and R79 (both red); A-3 |
| RF-2 | F | Code: R80 red, flat size linear (depth 16: 3,961 words, was 25,755,568); B-45 |
| RF-3 | F | Code: R81 red |
| RF-4 | F | Code: R82 red; B-36 |
| RF-5 | F | Claim corrected, growth test added; A-3 (D-16) |
| RF-6 | F | Not fixed, and now larger (138M reductions for 400 files): B-41, a risk |
| RF-7 | F | Code: R91 red |
| RF-8 | F | Code: R83 and R84 red; "a outer" remains in M1-6's member messages (§5) |
| rf-F-fit-1 | F | Code: `Compiler.lowered?/1`, R85-R90. 5 of 6 red; **R87 green** (reproduced, §5) |
| rf-F-fit-2 | F | Doc: A-2 option (d), D-20 |
| rf-F-fit-3 | F | Doc: FS-Q4's option restored; B-33 |
| rf-F-fit-4 | F | Doc: A-5 (b) |
| rf-F-fit-5 | F | Doc: A-1; the S+F union reproduced here, 582 passed |
| rf-F-fit-6 | F | Code (docs in the spike): "first rung"; B-40 |
| rf-F-fit-7 | F | Doc: kept as decided |
| rf-T-correct-1 | T | Code: improper lists raise H8 (P1 red) |
| rf-T-correct-2 | T | Code: a delimiter line still declares (P2 red) |
| rf-T-correct-3 | T | Code: four keyword places refused; a 3,000-case read(print) property (P3a-d red) |
| rf-T-correct-4 | T | Code: C49 (P4 red) |
| rf-T-correct-5 | T | Code: paths classified first (P5a-g red) |
| rf-T-correct-6 | T | Code: C6b (P6 red) |
| rf-T-correct-7 | T | Code: C45 in the one spelling (P7 red) |
| rf-T-correct-8 | T | Code in part (P8 red); the rest is B-50 |
| rf-T-correct-9 | T | Doc: measured 15.8x for 4x; B-26 |
| rf-T-correct-10 | T | Code in part (P10 red); B-6 |
| TF-1 | T | Doc (stanza and question): A-8 |
| TF-2 | T | Doc: stanza cites Table 33; D-18 |
| TF-3 | T | Doc: A-11 option (c) |
| TF-5 | T | Doc: 17 vendor rows surveyed from primary sources; 3 `unverified` kept |
| TF-6 | T | Doc: the `program` stanza narrowed |
| TF-7 | T | Doc: A-6's costs restated |
| TF-8 | T | Doc: deferred to OE-2 (T Q-17) |
| TF-9 | T | Doc: B-51, with an owed test |
| TF-10 | T | Doc: words and messages staged (§1 commits 15, 22, 28); B-22 |
| TF-11 | T | Code: V4 for a location in a rung (P11 red); the IEC spellings are not hinted (no decided rule asks) |
| TF-12 | T | Doc: T Q-4 and Q-13 withdrawn |
| X1 | F+T | Plan: A-1 order; commits 17 and 24 (a cal-aware walk, a kind check). Not composed in code |
| X2 | S+T | Plan: commit 16 rewrites the surface pin once; A-7, B-29 |
| X3 | F+T | Plan: commit 25 refuses with a located diagnostic. Not built |
| X4 | F+T | Plan: commits 14 and 17 go through F's `load/3`, one memo. Not built |
| X5 | S+F+T | A-1, all three tracks agree |
| X6 | S+F | Commit 9 owns `get(rt, "m1.s2.run")`; reproduced `{:ok, 1}` on the union |
| X7 | S+T | A-11, both tracks agree |
| X9 | S+T | B-17, A-7 |
| X10 | S+T | B-29, A-7 |
| X11 | S+T | B-46 |
| X12 | S+T | B-24 |
| X13 | S+F+T | Code in S (BT-1, BT-2 red) and T (P13 red) with interim words; B-31 |
| X14 | S+F+T | §1 commit 0 numbers the decisions once |
| X15 | S+T | Code: `diagnostic.ex` byte-identical; B-13 |
| X16 | S+F | B-14, A-4: no depth growth test unless A-4 (b) |
| X18 | S+F+T | B-30 |
| X19 | S+F+T | Recorded; the priority row changed with TF-1 (A-8) |
| X20 | F+T | Plan: commit 15 composes `Declarations` and the two naming tests by hand |

**Receipts per track.**

| Track | Gate | Mutation | Status |
|---|---|---|---|
| S-rev | three passes, 514 tests (from 430) | 113 of 113 red | patch applies to a fresh clone |
| F-rev | three passes on the final tree, 498 tests: one by F-rev, two here | 87 of 88 red, R87 green; the WORKERS=1 rerun for load-only reverts was not needed, since none is load-only | — |
| T-rev | three passes plus one here, 508 tests | 127 of 127 red | done-when probe unchanged: 40 entries; the broken source's seven diagnostics on lines 7, 9, 11, 12, 14, 15 and 16 |

---

## 5. Risks

- **No tree runs all three tracks.** S and F compose: 582 tests pass after a
  four-hunk union (see "What this pass reproduced"). T does not compose: S and T each add
  `configuration.ex`. T's M2-2 checks (its R14, R25, R41, R51-R54, R56-R59, R64, R66, W1 and W2, with
  their messages; R44, R45, W4 and W5 follow at commit 26) must be ported into S's `check/1` in commit 16, with the surface pin rewritten once and every S check asserted again from source.
  That is the largest piece no spike has built.
- **The F+T seams are only planned.** X1, X3 and X4 were reproduced as crashes on a hand
  merge, and are fixed in the plan, not in code. T's spike has no `cal`. Commits 14, 17,
  24 and 25 must re-run `rf-X-consistency-probe/ft_probe.exs` on the composed tree.
- **Two run-time pieces are not spiked at all:** M2-4's one copy of a global (commit 27),
  and M2-6's edges and `single` with `interval` (commit 29). Their rules are T-rev §5.1's
  text only, and B-51's ordering test is owed.
- **F's and T's commit series are not built.** Only S's five commits were cut and gated
  one by one. F's commits 9 and 10 must land in one push, since commit 9's edit refuses
  every block change by `!=`.
- **F has unpinned checks.** R87 (rising lines in `lowered?/1`) is green when reverted
  (reproduced). The calls to `shared_bits/2`, `calls/1` and `path/2` inside `lowered?/1`
  have no revert row. CLAUDE.md asks for a test that fails when each is reverted, or the
  check goes.
- **The exact check costs.** `FbType.user?/1` relowers each body: 2,486 reductions for a
  small block, against 244 before. Building a chain one block at a time is O(N²): 680,019
  reductions at 25 files, 138,358,875 at 400. F's suite went from about 9 s to 20 s
  (F-rev §12).
- **Quadratic error paths.** A refusal of n bad keys against n names costs 1.1M to 329M
  reductions from 100 to 1600 (S). T's check error path costs 15.8x for 4x. Both are
  inherited from `Declarations.suggest/4`'s Jaro pass, and only mistakes pay it (B-26).
- **Growth tests in reductions fail under load.** Under a load average of about 40, three
  pre-existing growth tests failed now and then (F), and two configuration growth tests
  measured 5.18x to 5.2x against a 5.1 bound (T). They measure 4.16x to 4.21x when run
  alone. A CI runner that shares cores could see this.
- **Path strings at depth.** Report and block-list names are full paths, so they are
  quadratic in nesting depth (A-3). This is negligible at the conventional family's 16
  levels.
- **`Logex.Edit` roughly doubles.** Its block walk is the independent oracle, and it now
  checks one-shots on every scan. It has no `.pre` oracle independent of the rules: R59 is
  pinned by an example only.
- **A cycle and `next_due_in/1` cost every declared task,** whatever is due. This is linear
  and pinned (GR-2b, GR-5): 531 to 19,431 reductions from 100 to 6,400 tasks. A queue is
  the runner's to add if it is ever wanted.
- **The scheduler walk's model restates the scheduler.** A misreading shared by the model
  and the code would pass. JS1's closed-form oracle and the Done-when's output order are
  independent, but they were run on S-synth, not rerun on S-rev.
- **The lexer's `.` carries every location.** A float literal would split `panel.q.0`. The
  `%` fallback's location lexeme valid only after `at` is the mitigation.
- **The plant test reads `docs/organisation.md`.** An edit to §4.4's example breaks a
  test. This is intended, but it couples a document to the suite.
- **Case-insensitive filesystems** may resolve `Seal.ld` or `Motor.ld` for a
  differently-cased name. This is unverified (tests run on Linux).
- **"a outer".** M1-6's member messages put "a" before a block's name. It shows on the S+F
  union for a block named with a vowel.
- **A configured plant cannot be edited until OE-2.** This is forced (S Q-32 dropped), and
  PLAN M2-1 and README's "Changing a running program" must say so.
- **Every track's document commits are unwritten,** and commit 0 must number decisions
  30 onward with no gap: the labels test refuses a decision §7 does not define.
