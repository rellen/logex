# JF1 · Judging track F (M2-5, user function blocks): F1 against F2

Label JF1. Written 2026-10-02 against `/home/user/logex` at `47319f7`, which this pass did not
modify (`git -C /home/user/logex status --short` is empty). The lens: correctness, and fit with
IEC and with precedent. Every claim below about behaviour comes from a command I ran. Its
output is in `scratchpad/m2/JF1-probe/`. Every claim about a decided rule quotes the rule.
`org` is `docs/organisation.md`, and `PLAN` is `PLAN.md`, both at `47319f7`. "F1 spike" and
"F2 spike" mean each patch applied to a fresh copy of `47319f7`.

---

## 0. Verdict

| Design | Score | In one line |
|---|---|---|
| F1 | **7.0** | Correct within its scope, and the better IEC survey. It departs explicitly from org §4.9 by refusing every change to a block type. It leaves the data path open to hand-edited types, and it catches up a timer's whole gap when an edit restores its `cal`. |
| F2 | **7.5** | Delivers what the documents give M2-5: the nested migration, a loader and a validated data path. My walk confirms the migration on its main rules. It has two reproduced defects in the timer rules of a switch, and its naming stanzas are second-hand, with one wrong citation. |

**Winner: F2, as the base.** Org §4.9 gives the nested migration to M2-5 (org:866, quoted in
§6). F2 builds it, and it holds under a seeded walk of 80 seeds × 120 operations on most of
the properties OE-1's contract walk checks. The two defects found are narrow, and each has
a local fix (§9). Graft F1's naming stanzas, its one-message recursion, its checks on tags
declared from Elixir, and its Done-when placement (§8).

If the maintainer instead takes F1-Q2 (a) / F2-Q2 (a), refusing any change to a block type
while running, then F1's FB-38 to FB-41 replace F2-R37 to F2-R45. F2 says these reduce
cleanly to F1's (F2.md:740-742). The rest of F2 stands. Both defects in §6.2 then
disappear, because the code that holds them goes.

---

## 1. What I ran

- **Copies.** Each patch was applied with `git apply --index` to a fresh `cp -a` of
  `/home/user/logex`: `m2/JF1-F1-work` and `m2/JF1-F2-work`. An unpatched copy,
  `m2/JF1-head-work`, served as the baseline for the top-level timer comparison. All three
  copies were deleted at the end, as the brief asks. To re-run a probe, apply the patch to a
  fresh copy again and run `mix run ../JF1-probe/<probe>.exs` from inside it.
- **The gate**, `JF1-probe/gate.sh`, on Elixir 1.20.4 / OTP 28, judged by exit code.
- **Probes**, each run unchanged on both spikes:
  - `p1.exs`: language and runtime. False EN, nesting, recursion, unknown types, `cal` of a
    non-instance, arity and formals, member access, timers and `first`, warnings, the header.
  - `p2.exs`: `Logex.Edit` on programs that hold blocks.
  - `p3.exs`: the Resume rule and its undo, at the top level (also run on HEAD) and nested.
  - `p4.exs`: the data path (`types:`, `Tag.new!/4`, `instructionize/3`).
  - `p5.exs`: `compile_file` with block files on disk.
  - `p6.exs`: warnings and the cost of a `cal`.
  - `p7.exs`: member access inside a body, recursion through a tag from Elixir, 17 levels
    of nesting.
  - `p8.exs`: a plain swap of a dint into a block instance.
- **`walk.exs`**: a seeded random walk over 216 compiled programs. The programs are drawn
  from 9 versions of a block `blk`, 4 versions of a block `wrap` that holds a `blk`, and 7
  programs. Each step is one of scan, restart, accept, test, untest, assemble and cancel.
  The walk checks:
  - that nothing raises;
  - that the writes each report lists rebuild the state exactly (org §4.9, "The writes a
    report lists, applied to the state before its step, give the state after it, exactly"),
    with paths;
  - that the block list equals the `:ons_blocked` entries;
  - that after a switch, every member of the started program is present at every depth;
  - that assemble and cancel prune exactly, at every depth;
  - that a test then an untest, with no scan between, gives back every value neither
    switch started (the OE-1 round trip, fix F11);
  - that on the first scan after a switch, a one-shot inside `x` whose chain of rungs
    changed against the program that last scanned passes no power (decision 21).
- **`soup.exs`**: 6,000 random sources around blocks (`function_block`, `cal`, member paths,
  types, literals), about half of them valid. Each was compiled; each program a compile
  returned was scanned 4 times. Then 400 random edits each ran test, scan, untest, test,
  assemble and scan.
- **`spot.py`**: six of the authors' reverts, re-run with their own text substitutions
  (F1 M20, M22, M33; F2 M1, M10, M11).

---

## 2. Gate and reverts, reproduced

| | format | compile | test compile | `mix test` | tests |
|---|---|---|---|---|---|
| F1 spike | 0 | 0 | 0 | 0 | 478 passed (6 doctests, 472 tests) |
| F2 spike | 0 | 0 | 0 | 0 | 476 passed (6 doctests, 470 tests) |

(`JF1-probe/F1-gate.log`, `F2-gate.log`.) Both match their claims.

The spot reverts reproduce each design's table exactly:

| Revert | Failed tests (claimed) | Failed tests (here) |
|---|---|---|
| F1 M20 | 4 | 4 |
| F1 M22 | 3 | 3 |
| F1 M33 | 2 | 2 |
| F2 M1 | 5 | 5 |
| F2 M10 | 1 | 1 |
| F2 M11 | 2 | 2 |

The soup raised nothing on either spike: 6,000 sources (2,974 compiled), 2,974 programs
scanned, and 400 edits of 5 steps each (`soup-F1.log`, `soup-F2.log`).

---

## 3. What both get right (reproduced, `p1-*.log`, `p6-*.log`, `p7-*.log`, `p8-*.log`)

The two spikes agree on the language and the runtime, and on every point below I checked
both.

- **The Done-when's three seal-ins** run independently in each spike's own test (it passes
  in the gate). My own sequence agrees: `p1` P3 runs two `outer`s, each holding a `seal`. A
  pulse on `g1` latches `a.inner.run` only, `b` stays 0, and `xic a.out ote r` reads it.
  Three levels deep (`m1.o.inner.run`) also works.
- **Decision 12, a false EN.** `xic en cal s1 a b q ote eno`:
  - with `en=0, b=1`, the instance stays `%{"run" => 1, "start" => 1, "stop" => 0}`. Nothing
    is copied in, `q` holds 1, and `eno` is 0;
  - with EN back, `stop` is copied and `q` drops.

  This is IEC Ed 3's EXAMPLE 2/4 (`research.md` IEC-10).
- **ENO is EN.** Anything may follow `cal` on its path, inside a branch leg too (`p6`).
- **Timers inside a frozen block** keep `.en` and `last` and catch up when the block next
  runs (decision 8). With `x.t1` frozen at `acc 10, last 10` from 20 ms to 200 ms, the scan
  at 210 ms gives `acc 100, dn 1` (`p1` P9).
- **`first` is the program instance's.** A block frozen on the first scan fires its `ons`
  the first time it runs, and one run on the first scan does not (`p1` P15). This matches
  the conventional family's documented behaviour (`research.md` CNV-14).
- **Located diagnostics:**
  - direct recursion (`function_block a` with `var x a`);
  - indirect recursion through a type given (`a` holds `b`, which holds an older `a`);
  - an unknown type (`var s1 sael`);
  - `cal` of a bool, a dint, a literal, a member or nothing;
  - `cal t1` on a `ton` (PLAN M2-5: "`cal` on a built-in type should be refused");
  - `ton s1 5000` on a user instance;
  - a second `cal` of one instance;
  - arity and type errors that name the formal, in org §4.3's template.
- **Members from outside:**
  - an output and an input are readable (decision 9's "reads anywhere");
  - a block's own `var`, a nested timer and a nested instance cannot be named;
  - nothing outside writes a member: `ote`, `otl`, `ons`, a `cal` output, `move` into a
    local;
  - a `cal` output into `t1.pre` (a writable dint) is accepted.
- **Positional formals** are the inputs, then the outputs, whatever the declaration order:
  `var_output q; var_input a; var_output n dint; var_input b dint` gives `a, b, q, n`.
- **Warnings.** An instance read but never called gets "`s2` is a seal, but no `cal` runs
  it" (PLAN M2-5: "must say `cal` for a user type"). A var_output driven only by a `cal` is
  not warned of. A `cal` output onto an `ons` storage bit is warned of.
- **Edits** (`p2`):
  - a `cal` no longer raises `KeyError` (HEAD's behaviour, inventory Q5.22);
  - an added instance has its one-shot blocked (`{:ons_blocked, "y.e", 0}`), and `p2` stays
    0 on the switch scan;
  - a changed EN on the calling rung blocks `x.e`;
  - an output only a `cal` drove is `{:held, "q", 1}`;
  - a program bit `e` and a block's bit `e` never collide (E9: the program's `e` is
    blocked, and `x.e`'s real edge passes);
  - a block whose file changed only in a comment or its line numbers is accepted with an
    empty forecast.
- **No BEAM.** Neither spike adds `Code.` to `lib/` or any new `if`, `cond` or `unless`
  (grep against HEAD).
- **Cost.** One scan of three seal-ins through `cal` costs 676 reductions (F1) and 683 (F2),
  against 348 for the same logic written inline: about 110 reductions a `cal` (`p6`).

---

## 4. Where they differ

| Question | F1 | F2 | Reproduced |
|---|---|---|---|
| A change to a block's body or members while running | refused at accept: ``x` is a pulse in the running program and a changed pulse in the candidate`` | allowed; members migrate by path; a change of kind refused as ``x.e` is a bool … and a dint …`` | `p2` E4, E8 |
| A timer inside a block whose `cal` an edit removes, then a later edit restores | catches up the whole gap: `acc` 30 → 100 and `d` 1 at once after 500 ms not run | `{:resumed, "x.t1", 500}`: `acc` 40 | `p2` E6 |
| Loading block files | none: `compile_file` of a program that uses `seal.ld` beside it gives "unknown type `seal`" | `<word>.ld` beside the file, a cycle of files located in the file that closes it | `p5` |
| A hand-edited `%FbType{}` in `types:` or `Tag.new!/4` | accepted (§5.2) | refused by `FbType.user?/1` | `p4` |
| The uses of a recursive declaration | excused: one message | reported again as "`x` is not declared" | `p1` P4 |
| Unknown type message | names the blocks, with a did-you-mean | names the blocks | `p1` P5 |
| `Runtime.instance(block)` | its own message ("…is a function block type, which runs inside a program through `cal`…") | the generic message, which prints the whole type with its body | `p1` P17 |
| Naming stanzas | read from Ed 2 and Ed 3 directly; adds the IL CALC rule and the Ed 2 1a/1b note | second-hand, from "the M2 research notes" | §7 |

---

## 5. F1

### 5.1 Strengths

- **No behavioural defect in its own scope.** The walk found nothing in 76 accepted edits,
  51 tests, 26 untests and 8 round trips:
  - the writes rebuild the state exactly;
  - the block list matches the reports;
  - every member is present after a switch;
  - pruning is exact;
  - no one-shot fired on a changed chain (6 observable cases where the block ran).

  The soup raised nothing. (`walk-F1.log`, `soup-F1.log`.)
- **The best fit with IEC in the survey.** The `cal` stanza:
  - quotes IL's conditional call, *"All assignments in an argument list of a conditional
    function block invocation shall only be performed together with the invocation, if the
    condition is true"* (Ed 2 §3.2.3 p.126; Ed 3 §7.2.4.3 p.198). That is decision 12 in
    IEC's own IL, and new to the repository;
  - records that Ed 2's text swaps Table 53's features 1a and 1b;
  - states the false-EN behaviour, as Ed 3 §6.6.1.5 requires of an implementer
    (`research.md` IEC-9);
  - states that EN and ENO are IEC keywords with no logex word (IEC-17).

  Every row it did not check is marked `unverified`.
- **One mistake, one message.** FB-16 excuses the uses of a recursive declaration.
- **Done-when in `end_to_end_test.exs`.** It runs through `compile_file` on files in a temp
  directory, with diagnostics that name the file. CLAUDE.md's convention puts Done-whens
  there.
- **Recursion through a tag from Elixir raises** `` `y` holds an instance of `a`, the
  function block being compiled `` (`p7`).
- **Departures listed** (F1.md §12), the first-rung reading of decision 4 among them.

### 5.2 Defects, reproduced

1. **The data path takes what the text cannot say.** Decision 15 (org:1496-1499) reads
   "Adopted, with the data API refusing what the text cannot say", and org:779 says "the
   data API refuses anything the text cannot say". In the F1 spike (`p4-F1.log`):
   - `seal` with its `run` member edited to `write: true`, then `xic a ote s1.run` from
     outside: `{:ok, Logex.Program}`;
   - members reversed by hand, so `cal`'s positional formals change: `{:ok, …}`;
   - a `:clock`/`:internal` member added by hand: `{:ok, …}`;
   - `Tag.new!("s1", hand_edited)`: accepted.

   F1 knows this (F1-Q13) and recommends closing it at landing. The spike has the gap.
2. **A timer whose `cal` an edit removes and a later edit restores catches up the whole
   gap.** `p2` E6: `x.t1` is timing at `acc 30, last 30`. An edit removes `cal x`, and 500 ms
   pass. An edit restores it, and the first scan gives `{"d" => 1}`, `acc 100, last 540`.
   Org:838-842 settled this hazard for a `ton`: "a timer whose `ton` an edit removes and a
   later edit restores catches up the whole gap … It must start timing at the edit
   instead. **Settled:** it resumes from the switch." The Resume row reads "A timer T runs
   and F did not … resumes from the switch" (org:1004). Here T runs `x.t1` and F did not.

   F1 asks this as F1-Q10, recommending catch-up, which makes it an explicit question. It is
   missing from F1's own departures list (F1.md §12), which it should be in.
3. **No loader.** `compile_file` of `plant.ld`, with `seal.ld` beside it, gives `line 3:
   unknown type `seal`` (`p5-F1.log`). F1-Q6 defers loading to M2-2. Not a decided-rule
   violation, but the Milestone 2 done sentence ("a configuration file on disk … with a
   function block inside it") then waits on M2-2 for any block on disk.
4. **Refuses every change to a block type, its body included** (`p2` E4). This departs from
   org:869, "Allowed while running: rungs", and from org:866, "the members of a function
   block type, until M2-5 brings the nested migration". F1 states both departures (F1-Q2,
   F1-Q3).
5. **Brief rule, minor.** The `function_block` and `cal` stanzas name the conventional
   family's own term for its user-defined instructions, spelled out (`F1.patch` lines 54 and
   69). HEAD's `docs/naming.md:403,418,433` and `docs/organisation.md:149,168,184` already
   use the same phrase, so this follows repository practice. The brief's naming rule may
   still want it replaced by "user-defined instruction", as F2 writes. This is the
   maintainer's call.

---

## 6. F2

### 6.1 Strengths

- **The nested migration, as org:866 gives it to M2-5, holds on its main rules.** Over 489
  accepted edits, 302 tests, 140 untests, 152 assembles and 52 round trips, the walk
  confirmed the following (`walk-F2.log`):
  - the listed writes rebuild the state exactly, with paths: `:added` (181 nested),
    `:pruned` (138 nested), `:preset` (41 nested), `:resumed` and `:initial_changed`;
  - every member of the started program is present at every depth;
  - assemble prunes exactly at every depth;
  - no one-shot fired on a changed chain (59 observable cases where the block ran).

  The only failures were the two defects in §6.2.
- **The precedent is stated and real.** Beremiz's hot swap pairs "leaves that exist in both
  trees with the same type" (`research.md` MAT-11). CODESYS replaces only code where the
  declaration part is unchanged (CDS-8).
- **The loader** (`p5-F2.log`):
  - a program compiles with `seal.ld` beside it;
  - a cycle of files is cited in the file that closes it: `cb.ld: line 3: `cb` cannot hold
    an instance of `ca` (cb → ca → cb)`;
  - a mistake in a block's file is cited with that file;
  - a program's file named as a type is refused;
  - a header that disagrees with its file name is cited in that file.
- **The data path is validated.** `FbType.user?/1` refuses every hand-edited type in `p4`,
  in `types:` and in `Tag.new!/4`.
- **A seeded compile-and-scan property** (3,000 sources) that reaches every M2-5
  diagnostic. F1 has none.
- **Updates CLAUDE.md's `evaluate/3` convention**, which it departs from, in the same patch.

### 6.2 Defects, reproduced

1. **A test then an untest, with no scan between, resumes a nested timer that the original
   froze by a false EN.** This loses decision 8's catch-up and breaks fix F11's round trip.

   `p3.exs`, case A, compared with HEAD (`p3-F2.log`):
   - the original's block `blk` holds `x.t1`. `xic en cal x g p` runs with `en=1` at 0 and
     10 ms, then `en=0` at 20 and 30 ms, so `x.t1` is frozen at `acc 10, last 10`;
   - the candidate's `blk` has no `t1`. `accept`, then `test`, reports `[]`;
   - an `untest` at once reports `[{:resumed, "x.t1", 20}]` and leaves `last 30`;
   - EN back at 40 ms gives `acc 20`. The same scan with no edit gives `acc 40`.

   Org:1003, the "Resume undone (fix F11)" row, promises: "so a test and an untest with no
   scan between leave the original's timers as they were". Decision 8 (org:1473-1475)
   chose per-timer `last` "because it catches up in the frozen-FB case".

   The cause: F2's `resumed({nil, to}, …)` (F2 spike `lib/logex/edit.ex:1061-1063`) takes
   "F did not run it" from the text of the program the switch stops. At this untest that
   program, the candidate, never scanned. The program that last scanned is the original,
   which runs `x.t1`. Fix F3 already answers this for one-shots by asking which program
   last scanned (org:1021-1031). The walk found the same at seed 65, step 20
   (`walk-trace-65-20-F2.log`), in `w.inner.t1`, which the original froze by an `ons`-gated
   `cal`.
2. **Fix F11's undo is not applied by path to a nested timer that only the other version
   of the block declares.**

   `p3.exs`, case B:
   - the original's `blk` has no `t1` and the candidate's has. Test 1 adds `x.t1`, a scan
     times it, and untest 1 leaves it kept and unused;
   - after 30 ms more on the original, test 2 reports `[{:resumed, "x.t1", 30}]`;
   - an untest at once reports `[]`, and `last` stays at 40 instead of 10.

   The same scenario at the top level gives `[{:resume_undone, "t1", 30}]` on HEAD, on the F1
   spike and on the F2 spike (`p3-head.log`, `p3-F1.log`, `p3-F2.log`).

   The cause: F2's nested plan maps over the started version's members only
   (`planned/4`, `Enum.map_reduce(type.members, …)`, F2 spike `edit.ex:712-718`). The
   top-level rule, by contrast, takes "One timer either program declares"
   (`timers(from, to)`, `edit.ex:511-515`). The walk found the same at seed 27, step 116
   (`walk-trace-27-116-F2.log`).
3. **A recursive block is accepted through a tag declared from Elixir.**
   `Compiler.instructionize(tree_of("function_block a … cal y i q"), [Tag.new!("y", b)], [])`,
   where `b` holds the older `a`, returns `{:ok, %Logex.FbType{}}` (`p7-F2.log`). F1 raises
   `ArgumentError` on the same call. PLAN M2-5 asks for "a recursive type … is a located
   diagnostic", and decision 15 asks the data API to refuse what the text cannot say. The
   impact is low: the type then fails `user?/1`, so it cannot reach a program.
4. **The compiler makes a type that its own validator refuses.** `instructionize/3` on a
   block with a tag declared from Elixir (`var_input a` given as `Tag.new!("a", :bool,
   :var_input)`) returns an `%FbType{}` with members `[q, a]`. Passing it in `types:` raises
   `types must be function block types from Logex.compile/2` (`p4-F2.log`), because
   `user?/1` requires every tag to have a line (F2 spike `fb_type.ex`, `declared?/1`). Org
   §4.9 (org:775-779) says every way of writing one model "ends in the one validator and
   produces the same values". F1 accepts it, with the Elixir tags first.
5. **Decision 4 is read as "the first rung" without saying so.** Decision 4 (org:1461)
   reads "a required first line `function_block <name>`". F2 accepts a header after
   comments and blank lines (`p1` P17, "comment first: :ok"; F2.md:36 and :215). This is
   not in its departures (F2.md:884-911), and no test pins it: `grep` finds no comment
   before a header in F2's `function_block_test.exs`. F1 lists the same reading as
   departure 5 and tests it.
6. **The naming stanzas cite what the repository does not hold.** CLAUDE.md:143-144 says
   "Mark what you could not verify `unverified`; never guess". In F2's `docs/naming.md`:
   - line 598 cites "`docs/organisation.md` §8" for "Its nesting is limited to 16 levels".
     `grep -n "16 levels" docs/organisation.md` finds nothing; the fact is `research.md`
     CNV-16, a scratchpad file;
   - lines 598, 605, 613 and 620 cite "the M2 research notes", which are not in the
     repository, inside a document that is append-only;
   - line 600, the CODESYS row of the `function_block` stanza, has no note and no
     `unverified` mark.
7. **Smaller points:**
   - a recursive declaration's uses cascade: `p1` P4, "line 4: `x` is not declared" after
     the recursion message;
   - the Done-when sits in `function_block_test.exs`, not in `end_to_end_test.exs` (F2
     lists this as owed);
   - `Runtime.instance(block)` prints the whole type with its body in the message;
   - README is not updated (owed).

---

## 7. IEC and precedent, against `research.md`

| Finding | F1 | F2 |
|---|---|---|
| IEC-9: Ed 3 requires the implementer to state false-EN behaviour | stated, Ed 3 §6.6.1.5 cited | stated |
| IEC-10: decision 12 is Ed 3 EXAMPLE 2/4 | cited, plus IL CALC (new) | cited |
| IEC-11: IEC forbids reading an FB's input from outside | inputs readable as decided; asked (F1-Q4) | same; asked (F2-Q5) |
| IEC-12: Ed 3 allows writing an input from outside | none written; asked (F1-Q5) | same (F2-Q6) |
| IEC-16: recursion forbidden (Ed 2) or implementer's (Ed 3) | forbidden at any depth | forbidden, across files too |
| IEC-17: EN and ENO keywords | stanza says logex has no word | stanza says so |
| CNV-14: a one-shot in a disabled block never sees the rung go false | documented in the `cal` stanza | documented |
| CNV-16: 16 levels of nesting | cited from the manual's page | cited, to the wrong source (§6.2 item 6) |
| CNV-17: existing user-defined instructions edited offline only | F1's refusal follows it | F2 departs, toward MAT-11 |
| MAT-7: MatIEC copies in and out on a false EN | cited, read at `3a41303` | cited |
| MAT-11: Beremiz pairs leaves by path and type | the OE-2 path | F2's migration follows it |
| CDS-8: CODESYS matching "by name and type" is unverified | not claimed | not claimed; only "code-only replacement" |

Neither design limits the depth of nesting. Both compile and run 17 levels (`p7`). Nothing
decided asks for a limit.

---

## 8. Ideas to graft onto F2

1. **F1's two naming stanzas, in place of F2's.** They are read from Ed 2 and Ed 3 directly,
   carry the IL CALC rule and the Ed 2 1a/1b note, and mark every unchecked row
   `unverified`. This fixes §6.2 item 6. Decide whether the conventional family's term
   stays (§5.2 item 5).
2. **F1's FB-16:** a recursive declaration's uses are excused. One mistake, one message.
3. **F1's did-you-mean** among the blocks given, in the unknown-type message (FB-12). A
   misspelled block name is now the likeliest unknown type (F1-Q11).
4. **F1's check that a tag from Elixir holds no instance of the block being compiled**
   (its `ArgumentError`). This fixes §6.2 item 3.
5. **F1's handling of tags from Elixir in a block:** members first, in list order. Then
   make `user?/1` accept a tag with no line, or refuse it in `instructionize/3` with a
   pinned message. This fixes §6.2 item 4.
6. **F1's Done-when in `end_to_end_test.exs`**, through `compile_file` on files in a temp
   directory, with diagnostics naming the file. With F2's loader it needs no `types:`.
7. **F1's own message for a `%FbType{}`** given to `Runtime` or `Edit.accept/3`.
8. **F1's test that the header is the first rung**, and F1's departure entry for decision
   4. This fixes §6.2 item 5.
9. **F1's README syntax entry and `cal` row** (owed in F2).
10. **The walk in `JF1-probe/walk.exs`**, as the seed of the edit walk over blocks that
    both designs owe to `api_contract_test.exs`. It runs in about a minute, and its
    round-trip check found §6.2 items 1 and 2.

---

## 9. Defects the synthesis must fix, each with its reproduction

1. **The Resume rule must ask which program last scanned, not only the stopped program's
   text.** Where `switched` is true and the edit's record says the program that last
   scanned is the started one, as fix F3's one-shot rule already does (org:1021-1031), no
   nested timer resumes. Test: `p3.exs` case A, where the untest must report no
   `:resumed` and `x.t1` must reach `acc 40` at 40 ms.
2. **Fix F11 by path for a timer that either version of a block declares.** The nested
   plan must visit the members of both versions, as `timers(from, to)` does at the top
   level, so that an untest gives back the resume its test made. Test: `p3.exs` case B,
   where the untest must report `{:resume_undone, "x.t1", 30}` and `last` must return to
   10.
3. **`instructionize/3` must refuse a block holding itself through a tag from Elixir.**
   Test: `p7.exs`.
4. **What `instructionize/3` makes from tags declared from Elixir must pass `user?/1`, or
   be refused at once.** Test: `p4.exs`.
5. **The first-rung reading of decision 4** gets a test and a departure entry.
6. **Correct the stanza citations.** `docs/naming.md` cites no scratchpad note, cites
   nothing to org §8 that org §8 does not say, and marks every unchecked row `unverified`.
7. **`api_contract_test.exs`'s edit walk reaches blocks** (owed by both designs; F2.md:597,
   F1.md:622). Item 1 and item 2 must each be red under it when reverted.

---

## 10. Receipts (`scratchpad/m2/JF1-probe/`)

- `gate.sh`, `F1-gate.log`, `F2-gate.log`: the gate.
- `p1.exs` to `p8.exs`, with `pN-F1.log` and `pN-F2.log`; `p3-head.log` is the top-level
  baseline on unmodified `47319f7`.
- `walk.exs`:
  - `walk-F1.log`: 0 failures;
  - `walk-F2.log`: 3 round-trip failures, all §6.2 items 1 and 2;
  - `walk-trace-65-20-*.log` and `walk-trace-27-116-*.log`: the traced seeds.

  Run it with `SEEDS=80 STEPS=120`; `TRACE=seed,step` prints one walk.
- `soup.exs`, `soup-F1.log`, `soup-F2.log`.
- `spot.py`: the six re-run reverts.
